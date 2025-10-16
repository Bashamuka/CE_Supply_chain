/*
  # Test Direct ETA Logic - Debug Version
  
  ## Problem Analysis
  Despite simplified logic without exclusions, ETAs are still not displaying.
  Need to debug the actual data flow and view refresh process.
  
  ## Solution
  Create a simplified test version to isolate the ETA logic issue.
*/

-- Drop and recreate with debug logging
DROP VIEW IF EXISTS v_eta_diagnosis CASCADE;
DROP FUNCTION IF EXISTS verify_simple_eta_logic CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;

-- Create a simple test function to debug ETA logic
CREATE OR REPLACE FUNCTION debug_eta_logic(part_number_param TEXT, project_id_param UUID)
RETURNS TABLE(
  test_step TEXT,
  part_number TEXT,
  project_id UUID,
  eta_value TEXT,
  record_count BIGINT,
  details TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Step 1: Check raw data in parts table
  RETURN QUERY
  SELECT 
    'STEP_1_RAW_PARTS'::TEXT as test_step,
    p.part_ordered::TEXT as part_number,
    pso.project_id,
    p.eta::TEXT as eta_value,
    COUNT(*)::BIGINT as record_count,
    ('Status: ' || COALESCE(p.status, 'NULL') || ', Comments: ' || COALESCE(p.comments, 'NULL'))::TEXT as details
  FROM parts p
  JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
  WHERE p.part_ordered = part_number_param
    AND pso.project_id = project_id_param
  GROUP BY p.part_ordered, pso.project_id, p.eta, p.status, p.comments
  ORDER BY p.eta DESC;
  
  -- Step 2: Check filtered data (basic validation only)
  RETURN QUERY
  SELECT 
    'STEP_2_FILTERED_PARTS'::TEXT as test_step,
    p.part_ordered::TEXT as part_number,
    pso.project_id,
    p.eta::TEXT as eta_value,
    COUNT(*)::BIGINT as record_count,
    ('Valid ETA: ' || CASE WHEN p.eta IS NOT NULL AND TRIM(p.eta) != '' AND LENGTH(TRIM(p.eta)) >= 5 THEN 'YES' ELSE 'NO' END)::TEXT as details
  FROM parts p
  JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
  WHERE p.part_ordered = part_number_param
    AND pso.project_id = project_id_param
    AND p.eta IS NOT NULL
    AND TRIM(p.eta) != ''
    AND LENGTH(TRIM(p.eta)) >= 5
  GROUP BY p.part_ordered, pso.project_id, p.eta
  ORDER BY p.eta DESC;
  
  -- Step 3: Check MAX(eta) calculation
  RETURN QUERY
  SELECT 
    'STEP_3_MAX_ETA'::TEXT as test_step,
    part_number_param::TEXT as part_number,
    project_id_param as project_id,
    MAX(p.eta)::TEXT as eta_value,
    COUNT(*)::BIGINT as record_count,
    ('MAX ETA calculated from ' || COUNT(*) || ' valid records')::TEXT as details
  FROM parts p
  JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
  WHERE p.part_ordered = part_number_param
    AND pso.project_id = project_id_param
    AND p.eta IS NOT NULL
    AND TRIM(p.eta) != ''
    AND LENGTH(TRIM(p.eta)) >= 5;
END;
$$;

-- Recreate materialized view with debug logging
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
  
  -- SIMPLIFIED ETA LOGIC WITH DEBUG INFO
  CASE 
    WHEN (qty_from_transit > 0 OR GREATEST(0, quantity_required - qty_from_stock - quantity_used - qty_from_transit - qty_from_invoiced) > 0) THEN
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

-- Test the debug function for part 1357935
DO $$
DECLARE
  test_project_id UUID;
BEGIN
  -- Get a project ID that has part 1357935
  SELECT DISTINCT pac.project_id INTO test_project_id
  FROM mv_project_analytics_complete pac
  WHERE pac.part_number = '1357935'
  LIMIT 1;
  
  IF test_project_id IS NOT NULL THEN
    RAISE NOTICE 'Testing ETA logic for part 1357935 in project %', test_project_id;
    RAISE NOTICE 'Debug results:';
    -- This will show debug results in the logs
    PERFORM * FROM debug_eta_logic('1357935', test_project_id);
  ELSE
    RAISE NOTICE 'No project found with part 1357935';
  END IF;
END $$;

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
  
  RAISE NOTICE 'Debug version applied successfully';
  RAISE NOTICE 'Parts missing ETA: % out of % total', missing_eta_count, total_transit_backorder;
  RAISE NOTICE 'ETA coverage: % percent', coverage_percentage;
  RAISE NOTICE 'Use SELECT * FROM debug_eta_logic(''1357935'', project_id) to debug specific parts';
  RAISE NOTICE 'Use SELECT * FROM v_eta_diagnosis to see detailed diagnosis';
END $$;
