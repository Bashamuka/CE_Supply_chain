/*
  Enforce unique stock_dispo by part_number (no aggregation) and rebuild MVs

  - Strictly delete duplicates in stock_dispo (keep latest by id)
  - Enforce uniqueness via unique index
  - Remove aggregated helper view
  - Recreate mv_project_parts_stock_availability to join directly on stock_dispo
  - Recreate mv_project_analytics_complete accordingly
*/

-- 1) Hard-delete duplicates in stock_dispo, keep most recent by id
WITH ranked AS (
  SELECT id, part_number,
         ROW_NUMBER() OVER (PARTITION BY part_number ORDER BY id DESC) AS rn
  FROM stock_dispo
)
DELETE FROM stock_dispo sd
USING ranked r
WHERE sd.id = r.id AND r.rn > 1;

-- 2) Enforce uniqueness on part_number
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = current_schema()
      AND indexname = 'ux_stock_dispo_part_number'
  ) THEN
    EXECUTE 'CREATE UNIQUE INDEX ux_stock_dispo_part_number ON stock_dispo(part_number)';
  END IF;
END$$;

-- 3) Drop aggregated view if it exists (we don't want aggregation)
DROP VIEW IF EXISTS v_stock_dispo_aggregated;

-- 4) Recreate MVs using direct join to stock_dispo (now unique on part_number)
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete;
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_stock_availability;

CREATE MATERIALIZED VIEW mv_project_parts_stock_availability AS
SELECT 
  pm.project_id,
  pmp.part_number,
  (
    COALESCE(sd.qté_gdc, 0)        * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'gdc') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_jdc, 0)        * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'jdc') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_cat_network, 0)* CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'cat_network') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_10, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_10') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_11, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_11') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_12, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_12') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_13, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_13') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_14, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_14') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_19, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_19') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_20, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_20') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_21, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_21') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_22, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_22') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_24, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_24') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_30, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_30') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_40, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_40') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_50, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_50') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_60, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_60') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_70, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_70') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_80, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_80') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_90, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_90') THEN 1 ELSE 0 END
  ) AS quantity_available
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
LEFT JOIN stock_dispo sd ON sd.part_number = pmp.part_number
GROUP BY pm.project_id, pmp.part_number, sd.qté_gdc, sd.qté_jdc, sd.qté_cat_network,
         sd.qté_succ_10, sd.qté_succ_11, sd.qté_succ_12, sd.qté_succ_13, sd.qté_succ_14,
         sd.qté_succ_19, sd.qté_succ_20, sd.qté_succ_21, sd.qté_succ_22, sd.qté_succ_24,
         sd.qté_succ_30, sd.qté_succ_40, sd.qté_succ_50, sd.qté_succ_60, sd.qté_succ_70,
         sd.qté_succ_80, sd.qté_succ_90;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_stock_avail_unique 
  ON mv_project_parts_stock_availability(project_id, part_number);

CREATE MATERIALIZED VIEW mv_project_analytics_complete AS
SELECT 
  pm.project_id,
  pm.id as machine_id,
  pm.name as machine_name,
  pmp.part_number,
  pmp.description,
  pmp.quantity_required,
  COALESCE(stock.quantity_available, 0) as quantity_available,
  COALESCE(used.quantity_used, 0) as quantity_used,
  COALESCE(transit.quantity_in_transit, 0) as quantity_in_transit,
  COALESCE(transit.quantity_invoiced, 0) as quantity_invoiced,
  GREATEST(0, 
    pmp.quantity_required - 
    COALESCE(stock.quantity_available, 0) - 
    COALESCE(used.quantity_used, 0) - 
    COALESCE(transit.quantity_in_transit, 0) - 
    COALESCE(transit.quantity_invoiced, 0)
  ) as quantity_missing
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
LEFT JOIN mv_project_parts_stock_availability stock 
  ON stock.project_id = pm.project_id AND stock.part_number = pmp.part_number
LEFT JOIN mv_project_parts_used_quantities used 
  ON used.machine_id = pmp.machine_id AND used.part_number = pmp.part_number
LEFT JOIN mv_project_parts_transit_invoiced transit 
  ON transit.project_id = pm.project_id AND transit.part_number = pmp.part_number;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_analytics_unique 
  ON mv_project_analytics_complete(project_id, machine_id, part_number);


