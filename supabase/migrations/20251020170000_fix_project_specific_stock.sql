/*
  # Fix stock availability to be project-specific
  
  Problem: mv_project_parts_stock_availability calculates global stock instead of 
  project-specific available stock after deducting usage from other projects.
  
  Solution: Modify the logic to calculate stock available specifically for each project,
  considering that stock is shared globally but allocation is project-specific.
*/

-- Drop and recreate mv_project_parts_stock_availability with project-specific logic
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_stock_availability CASCADE;

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

-- Recreate indexes
CREATE UNIQUE INDEX idx_mv_stock_avail_unique ON mv_project_parts_stock_availability(project_id, part_number);
CREATE INDEX idx_mv_stock_avail_project ON mv_project_parts_stock_availability(project_id);
CREATE INDEX idx_mv_stock_avail_part ON mv_project_parts_stock_availability(part_number);
