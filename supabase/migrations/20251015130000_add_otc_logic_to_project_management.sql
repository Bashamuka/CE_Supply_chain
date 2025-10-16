/*
  # Add OTC Logic to Project Management Module
  
  ## Purpose
  Add support for two calculation methods for the "Used" percentage in Project Management:
  1. OR-based calculation (current logic) - Uses operational requests (ORs)
  2. OTC-based calculation (new logic) - Uses delivery notes (BLs) from OTC module
  
  ## Changes
  1. Add calculation_method field to projects table
  2. Create OTC-based used quantities view
  3. Modify main analytics view to support both methods
  4. Update refresh function
  
  ## Business Logic
  - Projects can choose between 'or_based' or 'otc_based' calculation
  - OR-based: Uses existing logic with orders table (qte_livree from ORs)
  - OTC-based: Uses OTC module data (qte_livree from BLs linked to project)
  - OTC calculation is cumulative at project level, not per machine
  - No duplication of delivered quantities across machines in same project
*/

-- 1. Add calculation method field to projects table
ALTER TABLE projects 
ADD COLUMN IF NOT EXISTS calculation_method text DEFAULT 'or_based' 
CHECK (calculation_method IN ('or_based', 'otc_based'));

-- Add comment for documentation
COMMENT ON COLUMN projects.calculation_method IS 'Method for calculating used quantities: or_based (operational requests) or otc_based (delivery notes from OTC)';

-- 2. Create OTC-based used quantities view
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_project_parts_used_quantities_otc AS
SELECT 
  pm.project_id,
  pmp.machine_id,
  pmp.part_number,
  -- Calculate used quantity based on OTC data
  -- Sum qte_livree from OTC orders where num_bl is linked to project
  COALESCE(
    (SELECT SUM(otc.qte_livree)
     FROM otc_orders otc
     WHERE otc.num_bl IS NOT NULL 
       AND otc.num_bl != ''
       AND otc.reference = pmp.part_number
       -- Link BL to project through project_supplier_orders or project_machine_order_numbers
       AND EXISTS (
         SELECT 1 FROM project_supplier_orders pso
         WHERE pso.project_id = pm.project_id
           AND pso.supplier_order IN (
             SELECT DISTINCT supplier_order 
             FROM parts 
             WHERE part_ordered = pmp.part_number
           )
       )
    ), 0
  ) as quantity_used_otc
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_mv_used_otc_project ON mv_project_parts_used_quantities_otc(project_id);
CREATE INDEX IF NOT EXISTS idx_mv_used_otc_machine ON mv_project_parts_used_quantities_otc(machine_id);
CREATE INDEX IF NOT EXISTS idx_mv_used_otc_part ON mv_project_parts_used_quantities_otc(part_number);

-- 3. Create enhanced used quantities view that supports both methods
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_project_parts_used_quantities_enhanced AS
SELECT 
  pm.project_id,
  pmp.machine_id,
  pmp.part_number,
  -- Use OR-based calculation for projects with calculation_method = 'or_based'
  CASE 
    WHEN p.calculation_method = 'or_based' THEN
      COALESCE(used_or.quantity_used, 0)
    WHEN p.calculation_method = 'otc_based' THEN
      -- For OTC-based, use cumulative calculation at project level
      COALESCE(
        (SELECT SUM(otc.qte_livree)
         FROM otc_orders otc
         WHERE otc.num_bl IS NOT NULL 
           AND otc.num_bl != ''
           AND otc.reference = pmp.part_number
           AND EXISTS (
             SELECT 1 FROM project_supplier_orders pso
             WHERE pso.project_id = pm.project_id
               AND pso.supplier_order IN (
                 SELECT DISTINCT supplier_order 
                 FROM parts 
                 WHERE part_ordered = pmp.part_number
               )
           )
        ), 0
      )
    ELSE COALESCE(used_or.quantity_used, 0)
  END as quantity_used
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
JOIN projects p ON p.id = pm.project_id
LEFT JOIN mv_project_parts_used_quantities used_or 
  ON used_or.machine_id = pmp.machine_id AND used_or.part_number = pmp.part_number;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_mv_used_enhanced_project ON mv_project_parts_used_quantities_enhanced(project_id);
CREATE INDEX IF NOT EXISTS idx_mv_used_enhanced_machine ON mv_project_parts_used_quantities_enhanced(machine_id);
CREATE INDEX IF NOT EXISTS idx_mv_used_enhanced_part ON mv_project_parts_used_quantities_enhanced(part_number);

-- 4. Update the main analytics view to use the enhanced used quantities
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;

CREATE MATERIALIZED VIEW mv_project_analytics_complete AS
SELECT 
  pm.project_id,
  pm.id as machine_id,
  pm.name as machine_name,
  pmp.part_number,
  pmp.description,
  pmp.quantity_required,
  COALESCE(stock.quantity_available, 0) as quantity_available,
  COALESCE(used_enhanced.quantity_used, 0) as quantity_used,
  COALESCE(transit.quantity_in_transit, 0) as quantity_in_transit,
  COALESCE(transit.quantity_invoiced, 0) as quantity_invoiced,
  GREATEST(0, 
    pmp.quantity_required - 
    COALESCE(stock.quantity_available, 0) - 
    COALESCE(used_enhanced.quantity_used, 0) - 
    COALESCE(transit.quantity_in_transit, 0) - 
    COALESCE(transit.quantity_invoiced, 0)
  ) as quantity_missing,
  -- ETA calculation (unchanged)
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pm.project_id
      AND p.part_ordered = pmp.part_number
      AND p.status NOT IN ('Received', 'Cancelled')
      AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
      AND LENGTH(TRIM(p.eta)) >= 5
  ) as latest_eta
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
LEFT JOIN mv_project_parts_stock_availability stock 
  ON stock.project_id = pm.project_id AND stock.part_number = pmp.part_number
LEFT JOIN mv_project_parts_used_quantities_enhanced used_enhanced 
  ON used_enhanced.machine_id = pmp.machine_id AND used_enhanced.part_number = pmp.part_number
LEFT JOIN mv_project_parts_transit_invoiced transit 
  ON transit.project_id = pm.project_id AND transit.part_number = pmp.part_number;

-- Recreate indexes
CREATE INDEX IF NOT EXISTS idx_mv_analytics_project ON mv_project_analytics_complete(project_id);
CREATE INDEX IF NOT EXISTS idx_mv_analytics_machine ON mv_project_analytics_complete(machine_id);
CREATE INDEX IF NOT EXISTS idx_mv_analytics_part ON mv_project_analytics_complete(part_number);

-- Recreate the diagnostic view that was dropped by CASCADE
CREATE OR REPLACE VIEW v_eta_diagnosis AS
SELECT 
  pac.part_number,
  pac.project_id,
  pac.quantity_in_transit,
  pac.quantity_missing,
  pac.latest_eta as current_eta,
  -- Debug info
  (
    SELECT COUNT(*)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
  ) as total_parts_records,
  (
    SELECT COUNT(*)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
      AND LENGTH(TRIM(p.eta)) >= 5
  ) as valid_eta_records,
  (
    SELECT ARRAY_AGG(DISTINCT p.eta ORDER BY p.eta DESC)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
    LIMIT 5
  ) as all_valid_etas
FROM mv_project_analytics_complete pac
WHERE (pac.quantity_in_transit > 0 OR pac.quantity_missing > 0)
  AND (pac.latest_eta IS NULL OR pac.latest_eta = '');

-- 5. Update refresh function to include new views
CREATE OR REPLACE FUNCTION refresh_project_analytics_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Refresh all materialized views in dependency order
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_machine_parts_aggregated;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_stock_availability;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_otc;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_enhanced;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_transit_invoiced;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_analytics_complete;
  
  RAISE NOTICE 'All project analytics views refreshed successfully';
END;
$$;

-- 6. Create function to switch project calculation method
CREATE OR REPLACE FUNCTION switch_project_calculation_method(
  project_uuid uuid,
  method text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validate method
  IF method NOT IN ('or_based', 'otc_based') THEN
    RAISE EXCEPTION 'Invalid calculation method. Must be ''or_based'' or ''otc_based''';
  END IF;
  
  -- Update project calculation method
  UPDATE projects 
  SET calculation_method = method,
      updated_at = NOW()
  WHERE id = project_uuid;
  
  -- Refresh analytics for this project
  PERFORM refresh_project_analytics_views();
  
  RAISE NOTICE 'Project % calculation method switched to %', project_uuid, method;
END;
$$;

-- 7. Grant permissions
GRANT EXECUTE ON FUNCTION switch_project_calculation_method(uuid, text) TO authenticated;

-- 8. Insert sample data for testing (optional)
-- Update existing projects to use OR-based method by default
UPDATE projects 
SET calculation_method = 'or_based' 
WHERE calculation_method IS NULL;

-- 9. Create view to show project calculation methods
CREATE OR REPLACE VIEW v_project_calculation_methods AS
SELECT 
  p.id as project_id,
  p.name as project_name,
  p.calculation_method,
  CASE 
    WHEN p.calculation_method = 'or_based' THEN 'Operational Requests (ORs)'
    WHEN p.calculation_method = 'otc_based' THEN 'Delivery Notes (BLs) from OTC'
    ELSE 'Unknown'
  END as calculation_method_description,
  COUNT(pm.id) as machine_count,
  p.created_at,
  p.updated_at
FROM projects p
LEFT JOIN project_machines pm ON pm.project_id = p.id
GROUP BY p.id, p.name, p.calculation_method, p.created_at, p.updated_at
ORDER BY p.name;

-- Grant select permission
GRANT SELECT ON v_project_calculation_methods TO authenticated;

-- Final verification
DO $$
DECLARE
  project_count INTEGER;
  method_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO project_count FROM projects;
  SELECT COUNT(DISTINCT calculation_method) INTO method_count FROM projects;
  
  RAISE NOTICE 'OTC Logic Integration Complete';
  RAISE NOTICE 'Total projects: %', project_count;
  RAISE NOTICE 'Calculation methods in use: %', method_count;
  RAISE NOTICE 'New views created: mv_project_parts_used_quantities_otc, mv_project_parts_used_quantities_enhanced';
  RAISE NOTICE 'Use switch_project_calculation_method(project_id, ''otc_based'') to enable OTC calculation';
END $$;
