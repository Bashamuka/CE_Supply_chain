/*
  # Fix ETA Condition Logic - Always Calculate ETA
  
  ## Problem Analysis
  The ETA query works perfectly (finds 30/10/2025 for part 1357935), but the CASE WHEN condition
  prevents it from executing because qty_from_transit and quantity_missing are calculated as 0.
  
  ## Solution
  Remove the restrictive condition and always calculate ETA for parts that need it.
*/

-- Drop and recreate with corrected condition logic
DROP VIEW IF EXISTS v_eta_diagnosis CASCADE;
DROP FUNCTION IF EXISTS debug_eta_logic CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;

-- Recreate with corrected ETA logic
CREATE MATERIALIZED VIEW mv_project_analytics_complete AS
WITH machines_with_resources AS (
  SELECT
    pm.id as machine_id,
    pm.project_id,
    pm.name as machine_name,
    pmp.part_number,
    pmp.description,
    pmp.quantity_required,
    COALESCE(used.quantity_used, 0) as quantity_used,
    COALESCE(stock.quantity_available, 0) as total_stock_available,
    COALESCE(transit.quantity_in_transit, 0) as total_in_transit,
    COALESCE(transit.quantity_invoiced, 0) as total_invoiced,
    -- Calculate consumed by previous machines using created_at
    COALESCE(
      (SELECT SUM(COALESCE(used2.quantity_used, 0))
       FROM mv_project_machine_parts_aggregated pmp2
       JOIN project_machines pm2 ON pm2.id = pmp2.machine_id
       LEFT JOIN mv_project_parts_used_quantities used2 
         ON used2.machine_id = pmp2.machine_id 
         AND used2.part_number = pmp2.part_number
       WHERE pm2.project_id = pm.project_id
         AND pmp2.part_number = pmp.part_number
         AND pm2.created_at < pm.created_at
      ), 0
    ) as consumed_by_previous_machines
  FROM mv_project_machine_parts_aggregated pmp
  JOIN project_machines pm ON pm.id = pmp.machine_id
  LEFT JOIN mv_project_parts_stock_availability stock
    ON stock.project_id = pm.project_id AND stock.part_number = pmp.part_number
  LEFT JOIN mv_project_parts_used_quantities used
    ON used.machine_id = pmp.machine_id AND used.part_number = pmp.part_number
  LEFT JOIN mv_project_parts_transit_invoiced transit
    ON transit.project_id = pm.project_id AND transit.part_number = pmp.part_number
),
progressive_allocation AS (
  SELECT
    machine_id,
    project_id,
    machine_name,
    part_number,
    description,
    quantity_required,
    quantity_used,
    GREATEST(0, total_stock_available - consumed_by_previous_machines) as stock_remaining,
    total_in_transit,
    total_invoiced,
    consumed_by_previous_machines,
    LEAST(
      quantity_required,
      GREATEST(0, total_stock_available - consumed_by_previous_machines)
    ) as qty_from_stock
  FROM machines_with_resources
),
allocation_step2 AS (
  SELECT
    *,
    GREATEST(0, quantity_required - qty_from_stock) as still_needed_after_stock,
    LEAST(
      GREATEST(0, quantity_required - qty_from_stock),
      total_in_transit
    ) as qty_from_transit
  FROM progressive_allocation
),
allocation_step3 AS (
  SELECT
    *,
    GREATEST(0, still_needed_after_stock - qty_from_transit) as still_needed_after_transit,
    LEAST(
      GREATEST(0, still_needed_after_stock - qty_from_transit),
      total_invoiced
    ) as qty_from_invoiced
  FROM allocation_step2
)
SELECT
  machine_id,
  project_id,
  machine_name,
  part_number,
  description,
  quantity_required,
  qty_from_stock as quantity_available,
  quantity_used,
  qty_from_transit as quantity_in_transit,
  qty_from_invoiced as quantity_invoiced,
  GREATEST(0, quantity_required - qty_from_stock - quantity_used - qty_from_transit - qty_from_invoiced) as quantity_missing,
  
  -- CORRECTED ETA LOGIC: Always calculate ETA for parts that need it
  -- Check if part has any ETA data in the system
  CASE 
    WHEN EXISTS (
      SELECT 1
      FROM project_supplier_orders pso
      JOIN parts p ON p.supplier_order = pso.supplier_order
      WHERE pso.project_id = allocation_step3.project_id
        AND p.part_ordered = allocation_step3.part_number
        AND p.eta IS NOT NULL
        AND TRIM(p.eta) != ''
        AND LENGTH(TRIM(p.eta)) >= 5
    ) THEN
      -- Calculate MAX(eta) if ETA data exists
      COALESCE(
        -- Strategy 1: Exact match
        (
          SELECT MAX(p.eta)
          FROM project_supplier_orders pso
          JOIN parts p ON p.supplier_order = pso.supplier_order
          WHERE pso.project_id = allocation_step3.project_id
            AND p.part_ordered = allocation_step3.part_number
            AND p.eta IS NOT NULL
            AND TRIM(p.eta) != ''
            AND LENGTH(TRIM(p.eta)) >= 5
        ),
        -- Strategy 2: Case-insensitive match
        (
          SELECT MAX(p.eta)
          FROM project_supplier_orders pso
          JOIN parts p ON p.supplier_order = pso.supplier_order
          WHERE pso.project_id = allocation_step3.project_id
            AND UPPER(TRIM(p.part_ordered)) = UPPER(TRIM(allocation_step3.part_number))
            AND p.eta IS NOT NULL
            AND TRIM(p.eta) != ''
            AND LENGTH(TRIM(p.eta)) >= 5
        )
      )
    ELSE NULL
  END as latest_eta
  
FROM allocation_step3;

-- Create indexes
CREATE UNIQUE INDEX idx_mv_analytics_unique ON mv_project_analytics_complete(project_id, machine_id, part_number);
CREATE INDEX idx_mv_analytics_project ON mv_project_analytics_complete(project_id);
CREATE INDEX idx_mv_analytics_machine ON mv_project_analytics_complete(machine_id);
CREATE INDEX idx_mv_analytics_part ON mv_project_analytics_complete(part_number);
CREATE INDEX idx_mv_analytics_eta ON mv_project_analytics_complete(latest_eta) WHERE latest_eta IS NOT NULL;

-- Create refresh function
CREATE OR REPLACE FUNCTION refresh_project_analytics_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_machine_parts_aggregated;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_stock_availability;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_transit_invoiced;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_analytics_complete;
  
  RAISE NOTICE 'All project analytics views refreshed successfully';
END;
$$;

-- Create diagnostic view
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

-- Refresh views
SELECT refresh_project_analytics_views();

-- Final verification
DO $$
DECLARE
  missing_eta_count INTEGER;
  total_transit_backorder INTEGER;
  coverage_percentage NUMERIC;
BEGIN
  SELECT 
    COUNT(CASE WHEN latest_eta IS NULL OR latest_eta = '' THEN 1 END),
    COUNT(*)
  INTO missing_eta_count, total_transit_backorder
  FROM mv_project_analytics_complete
  WHERE quantity_in_transit > 0 OR quantity_missing > 0;
  
  coverage_percentage := CASE 
    WHEN total_transit_backorder > 0 THEN ROUND(((total_transit_backorder - missing_eta_count) * 100.0 / total_transit_backorder), 2)
    ELSE 0
  END;
  
  RAISE NOTICE 'Corrected ETA condition logic applied successfully';
  RAISE NOTICE 'ETA calculation now based on data existence, not quantity conditions';
  RAISE NOTICE 'Parts missing ETA: % out of % total', missing_eta_count, total_transit_backorder;
  RAISE NOTICE 'ETA coverage: % percent', coverage_percentage;
  RAISE NOTICE 'Use SELECT * FROM v_eta_diagnosis to see detailed diagnosis';
END $$;
