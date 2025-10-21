/*
  # Fix mv_project_parts_stock_availability - DEFINITIVE SOLUTION
  
  Problem: The subquery in mv_project_parts_stock_availability can return multiple rows
  if stock_dispo contains duplicate part_numbers, causing incorrect calculations.
  
  Solution: Use proper aggregation with SUM to handle duplicates correctly.
*/

-- Drop and recreate the problematic view with proper aggregation
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_stock_availability CASCADE;

CREATE MATERIALIZED VIEW mv_project_parts_stock_availability AS
SELECT 
  pm.project_id,
  pmp.part_number,
  COALESCE(
    (
      SELECT 
        SUM(COALESCE(sd.qté_gdc, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'gdc') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_jdc, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'jdc') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_cat_network, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'cat_network') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_10, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_10') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_11, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_11') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_12, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_12') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_13, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_13') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_14, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_14') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_19, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_19') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_20, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_20') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_21, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_21') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_22, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_22') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_24, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_24') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_30, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_30') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_40, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_40') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_50, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_50') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_60, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_60') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_70, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_70') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_80, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_80') THEN 1 ELSE 0 END +
        SUM(COALESCE(sd.qté_succ_90, 0)) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_90') THEN 1 ELSE 0 END
      FROM stock_dispo sd
      WHERE sd.part_number = pmp.part_number
    ), 0
  ) as quantity_available
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
GROUP BY pm.project_id, pmp.part_number;

-- Recreate indexes
CREATE UNIQUE INDEX idx_mv_stock_avail_unique ON mv_project_parts_stock_availability(project_id, part_number);
CREATE INDEX idx_mv_stock_avail_project ON mv_project_parts_stock_availability(project_id);
CREATE INDEX idx_mv_stock_avail_part ON mv_project_parts_stock_availability(part_number);

-- Note: mv_project_analytics_complete will be created by the previous migration
-- This migration only fixes mv_project_parts_stock_availability
