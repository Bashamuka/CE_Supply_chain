/*
  # Fix ETA Logic - Include 'Shipped' and 'FutureDated' Status
  
  ## Problem Analysis
  From the database screenshot, we can see that part 1357935 (SEAL-O-RING) has:
  - Status "Shipped" with ETA: 27/10/2025, 30/10/2025
  - Status "FutureDated" with ETA: 11/02/2026
  
  These statuses should be considered "in progress" and their ETAs should be included.
  The current logic is too restrictive and doesn't include these valid statuses.
  
  ## Solution
  Include specific statuses that represent "in progress" parts:
  - "Shipped" (parts in transit)
  - "FutureDated" (parts scheduled for future delivery)
  - Any other status that indicates the part is not yet delivered
*/

-- Drop and recreate with correct status inclusion
DROP VIEW IF EXISTS v_eta_diagnosis CASCADE;
DROP FUNCTION IF EXISTS verify_comments_based_eta_logic CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;

-- Recreate with correct status inclusion logic
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
  
  -- CORRECTED ETA LOGIC: Include 'Shipped' and 'FutureDated' statuses
  CASE 
    WHEN (qty_from_transit > 0 OR GREATEST(0, quantity_required - qty_from_stock - quantity_used - qty_from_transit - qty_from_invoiced) > 0) THEN
      COALESCE(
        -- Strategy 1: Exact match, include 'Shipped' and 'FutureDated' statuses
        (
          SELECT MAX(p.eta)
          FROM project_supplier_orders pso
          JOIN parts p ON p.supplier_order = pso.supplier_order
          WHERE pso.project_id = allocation_step3.project_id
            AND p.part_ordered = allocation_step3.part_number
            AND p.status IN ('Shipped', 'FutureDated', 'In Progress', 'Pending', 'Ordered', 'Confirmed')
            AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
            AND p.eta IS NOT NULL
            AND TRIM(p.eta) != ''
            AND LENGTH(TRIM(p.eta)) >= 5
        ),
        -- Strategy 2: Case-insensitive match, include 'Shipped' and 'FutureDated' statuses
        (
          SELECT MAX(p.eta)
          FROM project_supplier_orders pso
          JOIN parts p ON p.supplier_order = pso.supplier_order
          WHERE pso.project_id = allocation_step3.project_id
            AND UPPER(TRIM(p.part_ordered)) = UPPER(TRIM(allocation_step3.part_number))
            AND p.status IN ('Shipped', 'FutureDated', 'In Progress', 'Pending', 'Ordered', 'Confirmed')
            AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
            AND p.eta IS NOT NULL
            AND TRIM(p.eta) != ''
            AND LENGTH(TRIM(p.eta)) >= 5
        ),
        -- Strategy 3: Exact match, exclude only 'Received' and 'Cancelled' statuses
        (
          SELECT MAX(p.eta)
          FROM project_supplier_orders pso
          JOIN parts p ON p.supplier_order = pso.supplier_order
          WHERE pso.project_id = allocation_step3.project_id
            AND p.part_ordered = allocation_step3.part_number
            AND p.status NOT IN ('Received', 'Cancelled', 'Delivered')
            AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
            AND p.eta IS NOT NULL
            AND TRIM(p.eta) != ''
            AND LENGTH(TRIM(p.eta)) >= 5
        ),
        -- Strategy 4: Case-insensitive match, exclude only 'Received' and 'Cancelled' statuses
        (
          SELECT MAX(p.eta)
          FROM project_supplier_orders pso
          JOIN parts p ON p.supplier_order = pso.supplier_order
          WHERE pso.project_id = allocation_step3.project_id
            AND UPPER(TRIM(p.part_ordered)) = UPPER(TRIM(allocation_step3.part_number))
            AND p.status NOT IN ('Received', 'Cancelled', 'Delivered')
            AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
            AND p.eta IS NOT NULL
            AND TRIM(p.eta) != ''
            AND LENGTH(TRIM(p.eta)) >= 5
        ),
        -- Strategy 5: Any match (including all statuses if no other option)
        (
          SELECT MAX(p.eta)
          FROM project_supplier_orders pso
          JOIN parts p ON p.supplier_order = pso.supplier_order
          WHERE pso.project_id = allocation_step3.project_id
            AND p.part_ordered = allocation_step3.part_number
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

-- Create diagnostic view with status analysis
CREATE OR REPLACE VIEW v_eta_diagnosis AS
SELECT 
  pac.part_number,
  pac.project_id,
  pac.quantity_in_transit,
  pac.quantity_missing,
  pac.latest_eta as current_eta,
  -- Check for ETA with 'Shipped' and 'FutureDated' statuses
  (
    SELECT COUNT(*)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.status IN ('Shipped', 'FutureDated', 'In Progress', 'Pending', 'Ordered', 'Confirmed')
      AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
  ) as eta_count_in_progress_statuses,
  -- Check for ETA excluding only 'Received', 'Cancelled', 'Delivered'
  (
    SELECT COUNT(*)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.status NOT IN ('Received', 'Cancelled', 'Delivered')
      AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
  ) as eta_count_excluding_delivered,
  -- Get sample statuses for debugging
  (
    SELECT ARRAY_AGG(DISTINCT p.status ORDER BY p.status)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
    LIMIT 5
  ) as sample_statuses,
  -- Get sample ETAs for debugging
  (
    SELECT ARRAY_AGG(DISTINCT p.eta ORDER BY p.eta DESC)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
    LIMIT 5
  ) as sample_etas
FROM mv_project_analytics_complete pac
WHERE (pac.quantity_in_transit > 0 OR pac.quantity_missing > 0)
  AND (pac.latest_eta IS NULL OR pac.latest_eta = '');

-- Create verification function
CREATE OR REPLACE FUNCTION verify_status_based_eta_logic(project_id_param UUID DEFAULT NULL)
RETURNS TABLE(
  part_number TEXT,
  project_id UUID,
  quantity_in_transit INTEGER,
  quantity_missing INTEGER,
  latest_eta TEXT,
  part_status TEXT,
  eta_strategy TEXT,
  eta_count_in_progress BIGINT,
  eta_count_excluding_delivered BIGINT,
  sample_statuses TEXT[]
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
    CASE 
      WHEN pac.latest_eta IS NOT NULL AND pac.latest_eta != '' THEN 'ETA_FOUND'
      ELSE 'ETA_MISSING'
    END as eta_strategy,
    (
      SELECT COUNT(*)
      FROM project_supplier_orders pso
      JOIN parts p ON p.supplier_order = pso.supplier_order
      WHERE pso.project_id = pac.project_id
        AND p.part_ordered = pac.part_number
        AND p.status IN ('Shipped', 'FutureDated', 'In Progress', 'Pending', 'Ordered', 'Confirmed')
        AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
        AND p.eta IS NOT NULL
        AND TRIM(p.eta) != ''
    ) as eta_count_in_progress,
    (
      SELECT COUNT(*)
      FROM project_supplier_orders pso
      JOIN parts p ON p.supplier_order = pso.supplier_order
      WHERE pso.project_id = pac.project_id
        AND p.part_ordered = pac.part_number
        AND p.status NOT IN ('Received', 'Cancelled', 'Delivered')
        AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
        AND p.eta IS NOT NULL
        AND TRIM(p.eta) != ''
    ) as eta_count_excluding_delivered,
    (
      SELECT ARRAY_AGG(DISTINCT p.status ORDER BY p.status)
      FROM project_supplier_orders pso
      JOIN parts p ON p.supplier_order = pso.supplier_order
      WHERE pso.project_id = pac.project_id
        AND p.part_ordered = pac.part_number
      LIMIT 5
    ) as sample_statuses
  FROM mv_project_analytics_complete pac
  WHERE (pac.quantity_in_transit > 0 OR pac.quantity_missing > 0)
    AND (project_id_param IS NULL OR pac.project_id = project_id_param)
  ORDER BY pac.part_number, pac.project_id;
END;
$$;

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
  
  RAISE NOTICE 'Status-based ETA logic applied successfully';
  RAISE NOTICE 'Including Shipped, FutureDated, In Progress, Pending, Ordered, Confirmed statuses';
  RAISE NOTICE 'Parts missing ETA: % out of % total', missing_eta_count, total_transit_backorder;
  RAISE NOTICE 'ETA coverage: % percent', coverage_percentage;
  RAISE NOTICE 'Use SELECT * FROM v_eta_diagnosis to see detailed diagnosis';
  RAISE NOTICE 'Use SELECT * FROM verify_status_based_eta_logic() to verify results';
END $$;
