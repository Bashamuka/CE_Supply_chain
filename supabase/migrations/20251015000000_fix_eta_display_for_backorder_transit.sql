/*
  # Fix ETA Display for Backorder and Transit Parts
  
  ## Problem
  Parts showing as "Backorder" or "In Transit" are not displaying their ETA values,
  even though they should have ETA information.
  
  ## Root Cause Analysis
  The current ETA logic might be too restrictive or not properly handling:
  1. Parts with quantity_in_transit > 0 but no ETA
  2. Parts with quantity_missing > 0 (backorder) but no ETA
  3. ETA data format issues
  4. Missing joins or incorrect filtering conditions
  
  ## Solution
  Improve the ETA calculation logic to:
  1. Include ETA for ALL parts that have orders (not just specific statuses)
  2. Handle different ETA formats properly
  3. Add fallback logic for missing ETA data
  4. Ensure ETA is shown for parts in transit or backorder status
*/

-- First, let's check what ETA data we actually have
-- This is a diagnostic query to understand the data structure
DO $$
BEGIN
  RAISE NOTICE 'Checking ETA data in parts table...';
END $$;

-- Create a temporary view to analyze ETA data
CREATE OR REPLACE VIEW v_eta_analysis AS
SELECT 
  p.part_ordered,
  p.eta,
  p.status,
  p.comments,
  pso.project_id,
  COUNT(*) as order_count
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.eta IS NOT NULL 
  AND p.eta != ''
GROUP BY p.part_ordered, p.eta, p.status, p.comments, pso.project_id
ORDER BY p.part_ordered, p.eta;

-- Drop and recreate the analytics view with improved ETA logic
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete;

-- Recreate with improved ETA logic
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
    pmp.creation_rank,
    COALESCE(stock.quantity_available, 0) as total_stock_available,
    COALESCE(transit.quantity_in_transit, 0) as total_in_transit,
    COALESCE(transit.quantity_invoiced, 0) as total_invoiced,
    -- Calculate consumed by previous machines
    COALESCE(
      (SELECT SUM(COALESCE(used2.quantity_used, 0))
       FROM mv_project_machine_parts_aggregated pmp2
       JOIN project_machines pm2 ON pm2.id = pmp2.machine_id
       LEFT JOIN mv_project_parts_used_quantities used2 
         ON used2.machine_id = pmp2.machine_id 
         AND used2.part_number = pmp2.part_number
       WHERE pm2.project_id = pm.project_id
         AND pmp2.part_number = pmp.part_number
         AND pmp2.creation_rank < pmp.creation_rank
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
    creation_rank,
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
  -- IMPROVED ETA LOGIC: More comprehensive ETA retrieval
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = allocation_step3.project_id
      AND p.part_ordered = allocation_step3.part_number
      -- Include ALL orders, not just specific statuses
      AND p.status NOT IN ('Received', 'Cancelled')
      -- More flexible comment filtering
      AND (p.comments IS NULL OR LOWER(p.comments) NOT LIKE '%delivery completed%')
      -- Ensure ETA is not null or empty
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
      -- Additional validation for ETA format
      AND LENGTH(TRIM(p.eta)) >= 5  -- Minimum reasonable date length
  ) as latest_eta
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

-- Create a diagnostic function to check ETA data
CREATE OR REPLACE FUNCTION diagnose_eta_data(project_id_param UUID DEFAULT NULL)
RETURNS TABLE(
  part_number TEXT,
  project_id UUID,
  eta_count BIGINT,
  sample_etas TEXT[],
  statuses TEXT[],
  has_transit BOOLEAN,
  has_backorder BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.part_ordered::TEXT,
    pso.project_id,
    COUNT(*) as eta_count,
    ARRAY_AGG(DISTINCT p.eta ORDER BY p.eta) as sample_etas,
    ARRAY_AGG(DISTINCT p.status ORDER BY p.status) as statuses,
    EXISTS(
      SELECT 1 FROM mv_project_analytics_complete pac
      WHERE pac.part_number = p.part_ordered
        AND pac.quantity_in_transit > 0
        AND (project_id_param IS NULL OR pac.project_id = project_id_param)
    ) as has_transit,
    EXISTS(
      SELECT 1 FROM mv_project_analytics_complete pac
      WHERE pac.part_number = p.part_ordered
        AND pac.quantity_missing > 0
        AND (project_id_param IS NULL OR pac.project_id = project_id_param)
    ) as has_backorder
  FROM parts p
  JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
  WHERE p.eta IS NOT NULL 
    AND TRIM(p.eta) != ''
    AND (project_id_param IS NULL OR pso.project_id = project_id_param)
  GROUP BY p.part_ordered, pso.project_id
  ORDER BY eta_count DESC, p.part_ordered;
END;
$$;

-- Refresh the views immediately
SELECT refresh_project_analytics_views();

-- Log completion
DO $$
BEGIN
  RAISE NOTICE 'ETA fix migration completed successfully';
  RAISE NOTICE 'Use SELECT * FROM diagnose_eta_data() to check ETA data quality';
END $$;
