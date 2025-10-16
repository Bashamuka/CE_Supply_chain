/*
  # Fix ETA Logic - Remove Non-existent Column Reference
  
  ## Problem
  The migration references pmp.creation_rank which doesn't exist in mv_project_machine_parts_aggregated.
  This causes the error: "column pmp.creation_rank does not exist"
  
  ## Solution
  Remove the creation_rank reference and use machine creation order from project_machines table instead.
  Simplify the logic to focus on the ETA calculation without complex ordering.
*/

-- Drop and recreate with corrected column references
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete;

-- Recreate with corrected logic (no creation_rank reference)
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
    -- Use machine creation order from project_machines table
    pm.created_at as machine_created_at,
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
         AND pm2.created_at < pm.created_at  -- Use created_at instead of creation_rank
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
    machine_created_at,
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
  
  -- SIMPLIFIED ETA LOGIC: Always take the longest ETA if part is in transit OR backorder
  CASE 
    WHEN (qty_from_transit > 0 OR GREATEST(0, quantity_required - qty_from_stock - quantity_used - qty_from_transit - qty_from_invoiced) > 0) THEN
      (
        SELECT MAX(p.eta)
        FROM project_supplier_orders pso
        JOIN parts p ON p.supplier_order = pso.supplier_order
        WHERE pso.project_id = allocation_step3.project_id
          AND p.part_ordered = allocation_step3.part_number
          -- Only consider active orders (not received or cancelled)
          AND p.status NOT IN ('Received', 'Cancelled')
          -- Exclude completed deliveries
          AND (p.comments IS NULL OR LOWER(p.comments) NOT LIKE '%delivery completed%')
          -- Ensure ETA is valid
          AND p.eta IS NOT NULL
          AND TRIM(p.eta) != ''
          AND LENGTH(TRIM(p.eta)) >= 5
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

-- Create a function to refresh all analytics views
CREATE OR REPLACE FUNCTION refresh_project_analytics_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Refresh in dependency order
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_machine_parts_aggregated;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_stock_availability;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_transit_invoiced;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_analytics_complete;
  
  RAISE NOTICE 'All project analytics views refreshed successfully';
END;
$$;

-- Create a verification function to test the corrected ETA logic
CREATE OR REPLACE FUNCTION verify_corrected_eta_logic(project_id_param UUID DEFAULT NULL)
RETURNS TABLE(
  part_number TEXT,
  project_id UUID,
  quantity_in_transit INTEGER,
  quantity_missing INTEGER,
  latest_eta TEXT,
  part_status TEXT,
  eta_count BIGINT,
  all_etas TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pac.part_number::TEXT,
    pac.project_id,
    pac.quantity_in_transit,
    pac.quantity_missing,
    pac.latest_eta::TEXT,
    CASE 
      WHEN pac.quantity_in_transit > 0 AND pac.quantity_missing > 0 THEN 'BOTH_TRANSIT_AND_BACKORDER'
      WHEN pac.quantity_in_transit > 0 THEN 'TRANSIT_ONLY'
      WHEN pac.quantity_missing > 0 THEN 'BACKORDER_ONLY'
      ELSE 'NO_TRANSIT_OR_BACKORDER'
    END as part_status,
    (
      SELECT COUNT(*)
      FROM project_supplier_orders pso
      JOIN parts p ON p.supplier_order = pso.supplier_order
      WHERE pso.project_id = pac.project_id
        AND p.part_ordered = pac.part_number
        AND p.status NOT IN ('Received', 'Cancelled')
        AND (p.comments IS NULL OR LOWER(p.comments) NOT LIKE '%delivery completed%')
        AND p.eta IS NOT NULL
        AND TRIM(p.eta) != ''
    ) as eta_count,
    (
      SELECT ARRAY_AGG(p.eta ORDER BY p.eta DESC)
      FROM project_supplier_orders pso
      JOIN parts p ON p.supplier_order = pso.supplier_order
      WHERE pso.project_id = pac.project_id
        AND p.part_ordered = pac.part_number
        AND p.status NOT IN ('Received', 'Cancelled')
        AND (p.comments IS NULL OR LOWER(p.comments) NOT LIKE '%delivery completed%')
        AND p.eta IS NOT NULL
        AND TRIM(p.eta) != ''
    ) as all_etas
  FROM mv_project_analytics_complete pac
  WHERE (pac.quantity_in_transit > 0 OR pac.quantity_missing > 0)
    AND (project_id_param IS NULL OR pac.project_id = project_id_param)
  ORDER BY pac.part_number, pac.project_id;
END;
$$;

-- Refresh the views immediately
SELECT refresh_project_analytics_views();

-- Log completion with verification
DO $$
DECLARE
  total_parts INTEGER;
  parts_with_eta INTEGER;
  coverage_percentage NUMERIC;
BEGIN
  SELECT 
    COUNT(*),
    COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END)
  INTO total_parts, parts_with_eta
  FROM mv_project_analytics_complete
  WHERE quantity_in_transit > 0 OR quantity_missing > 0;
  
  coverage_percentage := CASE 
    WHEN total_parts > 0 THEN ROUND((parts_with_eta * 100.0 / total_parts), 2)
    ELSE 0
  END;
  
  RAISE NOTICE 'Corrected ETA logic migration completed successfully';
  RAISE NOTICE 'Fixed: Removed non-existent creation_rank column reference';
  RAISE NOTICE 'Logic: Always take MAX(eta) for parts in transit OR backorder';
  RAISE NOTICE 'Total parts in transit/backorder: %', total_parts;
  RAISE NOTICE 'Parts with ETA: %', parts_with_eta;
  RAISE NOTICE 'ETA coverage: %%', coverage_percentage;
  RAISE NOTICE 'Use SELECT * FROM verify_corrected_eta_logic() to verify the logic';
END $$;
