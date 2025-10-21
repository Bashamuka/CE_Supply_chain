/*
  # Complete fix for project-specific stock availability
  
  This migration fixes the stock availability issue by:
  1. Dropping both dependent views
  2. Recreating mv_project_parts_stock_availability with project-specific logic
  3. Recreating mv_project_analytics_complete with correct dependencies
*/

-- Step 1: Drop dependent views
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete;
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_stock_availability;

-- Step 2: Recreate mv_project_parts_stock_availability with project-specific logic
CREATE MATERIALIZED VIEW mv_project_parts_stock_availability AS
WITH global_stock AS (
  -- Calculate total global stock per part
  SELECT 
    part_number,
    SUM(COALESCE(qté_gdc, 0)) as total_gdc,
    SUM(COALESCE(qté_jdc, 0)) as total_jdc,
    SUM(COALESCE(qté_cat_network, 0)) as total_cat_network,
    SUM(COALESCE(qté_succ_10, 0)) as total_succ_10,
    SUM(COALESCE(qté_succ_11, 0)) as total_succ_11,
    SUM(COALESCE(qté_succ_12, 0)) as total_succ_12,
    SUM(COALESCE(qté_succ_13, 0)) as total_succ_13,
    SUM(COALESCE(qté_succ_14, 0)) as total_succ_14,
    SUM(COALESCE(qté_succ_19, 0)) as total_succ_19,
    SUM(COALESCE(qté_succ_20, 0)) as total_succ_20,
    SUM(COALESCE(qté_succ_21, 0)) as total_succ_21,
    SUM(COALESCE(qté_succ_22, 0)) as total_succ_22,
    SUM(COALESCE(qté_succ_24, 0)) as total_succ_24,
    SUM(COALESCE(qté_succ_30, 0)) as total_succ_30,
    SUM(COALESCE(qté_succ_40, 0)) as total_succ_40,
    SUM(COALESCE(qté_succ_50, 0)) as total_succ_50,
    SUM(COALESCE(qté_succ_60, 0)) as total_succ_60,
    SUM(COALESCE(qté_succ_70, 0)) as total_succ_70,
    SUM(COALESCE(qté_succ_80, 0)) as total_succ_80,
    SUM(COALESCE(qté_succ_90, 0)) as total_succ_90
  FROM stock_dispo
  GROUP BY part_number
),
project_stock AS (
  -- Calculate stock available for each project based on configured branches
  SELECT 
    pm.project_id,
    pmp.part_number,
    -- Calculate total stock available for this project's configured branches
    COALESCE(
      gs.total_gdc * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'gdc') THEN 1 ELSE 0 END +
      gs.total_jdc * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'jdc') THEN 1 ELSE 0 END +
      gs.total_cat_network * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'cat_network') THEN 1 ELSE 0 END +
      gs.total_succ_10 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_10') THEN 1 ELSE 0 END +
      gs.total_succ_11 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_11') THEN 1 ELSE 0 END +
      gs.total_succ_12 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_12') THEN 1 ELSE 0 END +
      gs.total_succ_13 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_13') THEN 1 ELSE 0 END +
      gs.total_succ_14 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_14') THEN 1 ELSE 0 END +
      gs.total_succ_19 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_19') THEN 1 ELSE 0 END +
      gs.total_succ_20 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_20') THEN 1 ELSE 0 END +
      gs.total_succ_21 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_21') THEN 1 ELSE 0 END +
      gs.total_succ_22 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_22') THEN 1 ELSE 0 END +
      gs.total_succ_24 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_24') THEN 1 ELSE 0 END +
      gs.total_succ_30 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_30') THEN 1 ELSE 0 END +
      gs.total_succ_40 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_40') THEN 1 ELSE 0 END +
      gs.total_succ_50 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_50') THEN 1 ELSE 0 END +
      gs.total_succ_60 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_60') THEN 1 ELSE 0 END +
      gs.total_succ_70 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_70') THEN 1 ELSE 0 END +
      gs.total_succ_80 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_80') THEN 1 ELSE 0 END +
      gs.total_succ_90 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_90') THEN 1 ELSE 0 END,
      0
    ) as quantity_available
  FROM mv_project_machine_parts_aggregated pmp
  JOIN project_machines pm ON pm.id = pmp.machine_id
  LEFT JOIN global_stock gs ON gs.part_number = pmp.part_number
  GROUP BY pm.project_id, pmp.part_number, gs.total_gdc, gs.total_jdc, gs.total_cat_network,
           gs.total_succ_10, gs.total_succ_11, gs.total_succ_12, gs.total_succ_13, gs.total_succ_14,
           gs.total_succ_19, gs.total_succ_20, gs.total_succ_21, gs.total_succ_22, gs.total_succ_24,
           gs.total_succ_30, gs.total_succ_40, gs.total_succ_50, gs.total_succ_60, gs.total_succ_70,
           gs.total_succ_80, gs.total_succ_90
)
SELECT 
  project_id,
  part_number,
  quantity_available
FROM project_stock;

-- Step 3: Recreate indexes for mv_project_parts_stock_availability
CREATE UNIQUE INDEX idx_mv_stock_avail_unique ON mv_project_parts_stock_availability(project_id, part_number);
CREATE INDEX idx_mv_stock_avail_project ON mv_project_parts_stock_availability(project_id);
CREATE INDEX idx_mv_stock_avail_part ON mv_project_parts_stock_availability(part_number);

-- Step 4: Recreate mv_project_analytics_complete (simplified version)
-- This is a basic recreation - you may need to apply the full migration 20251020120000 after this
CREATE MATERIALIZED VIEW mv_project_analytics_complete AS
SELECT 
  pmp.machine_id,
  pm.project_id,
  pm.name as machine_name,
  pmp.part_number,
  pmp.description,
  pmp.quantity_required,
  COALESCE(stock.quantity_available, 0) as quantity_available,
  COALESCE(used.quantity_used, 0) as quantity_used,
  COALESCE(transit.quantity_in_transit, 0) as quantity_in_transit,
  COALESCE(transit.quantity_invoiced, 0) as quantity_invoiced,
  GREATEST(0, pmp.quantity_required - COALESCE(used.quantity_used, 0) - COALESCE(stock.quantity_available, 0) - COALESCE(transit.quantity_in_transit, 0) - COALESCE(transit.quantity_invoiced, 0)) as quantity_missing,
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pm.project_id
      AND p.part_ordered = pmp.part_number
      AND p.status NOT IN ('Griefed', 'Cancelled')
      AND LOWER(COALESCE(p.comments, '')) != 'delivery completed'
      AND p.eta IS NOT NULL
      AND p.eta != ''
  ) as latest_eta
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
LEFT JOIN mv_project_parts_stock_availability stock ON stock.project_id = pm.project_id AND stock.part_number = pmp.part_number
LEFT JOIN mv_project_parts_used_quantities used ON used.machine_id = pmp.machine_id AND used.part_number = pmp.part_number
LEFT JOIN mv_project_parts_transit_invoiced transit ON transit.project_id = pm.project_id AND transit.part_number = pmp.part_number;

-- Step 5: Create indexes for mv_project_analytics_complete
CREATE UNIQUE INDEX idx_mv_analytics_unique ON mv_project_analytics_complete(project_id, machine_id, part_number);
CREATE INDEX idx_mv_analytics_project ON mv_project_analytics_complete(project_id);
CREATE INDEX idx_mv_analytics_machine ON mv_project_analytics_complete(machine_id);
