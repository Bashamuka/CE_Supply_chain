/*
  Fix: stock_dispo duplicates and materialized view subquery error

  - Remove duplicate rows in stock_dispo (keep latest by id)
  - Enforce unique part_number to prevent future duplicates
  - Replace single-row subquery in mv_project_parts_stock_availability with
    an aggregated stock join to avoid "more than one row returned" (21000)
  - Recreate dependent mv_project_analytics_complete accordingly
*/

-- 1) Remove duplicates in stock_dispo, keep the most recent row (highest id)
WITH ranked AS (
  SELECT id, part_number,
         ROW_NUMBER() OVER (PARTITION BY part_number ORDER BY id DESC) AS rn
  FROM stock_dispo
)
DELETE FROM stock_dispo sd
USING ranked r
WHERE sd.id = r.id AND r.rn > 1;

-- 2) Enforce uniqueness on part_number going forward
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

-- 3) Create aggregated stock view to collapse potential multi-rows per part_number
CREATE OR REPLACE VIEW v_stock_dispo_aggregated AS
SELECT
  part_number,
  COALESCE(SUM(qté_gdc), 0)     AS qte_gdc,
  COALESCE(SUM(qté_jdc), 0)     AS qte_jdc,
  COALESCE(SUM(qté_cat_network), 0) AS qte_cat_network,
  COALESCE(SUM(qté_succ_10), 0) AS qte_succ_10,
  COALESCE(SUM(qté_succ_11), 0) AS qte_succ_11,
  COALESCE(SUM(qté_succ_12), 0) AS qte_succ_12,
  COALESCE(SUM(qté_succ_13), 0) AS qte_succ_13,
  COALESCE(SUM(qté_succ_14), 0) AS qte_succ_14,
  COALESCE(SUM(qté_succ_19), 0) AS qte_succ_19,
  COALESCE(SUM(qté_succ_20), 0) AS qte_succ_20,
  COALESCE(SUM(qté_succ_21), 0) AS qte_succ_21,
  COALESCE(SUM(qté_succ_22), 0) AS qte_succ_22,
  COALESCE(SUM(qté_succ_24), 0) AS qte_succ_24,
  COALESCE(SUM(qté_succ_30), 0) AS qte_succ_30,
  COALESCE(SUM(qté_succ_40), 0) AS qte_succ_40,
  COALESCE(SUM(qté_succ_50), 0) AS qte_succ_50,
  COALESCE(SUM(qté_succ_60), 0) AS qte_succ_60,
  COALESCE(SUM(qté_succ_70), 0) AS qte_succ_70,
  COALESCE(SUM(qté_succ_80), 0) AS qte_succ_80,
  COALESCE(SUM(qté_succ_90), 0) AS qte_succ_90
FROM stock_dispo
GROUP BY part_number;

-- 4) Recreate materialized views that depend on stock aggregation
-- Drop dependent analytics view first, then stock availability
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete;
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_stock_availability;

-- Recreate mv_project_parts_stock_availability using aggregated stock
CREATE MATERIALIZED VIEW mv_project_parts_stock_availability AS
SELECT 
  pm.project_id,
  pmp.part_number,
  (
    COALESCE(sd.qte_gdc, 0)        * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'gdc') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_jdc, 0)        * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'jdc') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_cat_network, 0)* CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'cat_network') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_10, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_10') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_11, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_11') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_12, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_12') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_13, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_13') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_14, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_14') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_19, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_19') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_20, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_20') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_21, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_21') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_22, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_22') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_24, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_24') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_30, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_30') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_40, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_40') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_50, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_50') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_60, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_60') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_70, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_70') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_80, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_80') THEN 1 ELSE 0 END +
    COALESCE(sd.qte_succ_90, 0)    * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_90') THEN 1 ELSE 0 END
  ) AS quantity_available
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
LEFT JOIN v_stock_dispo_aggregated sd ON sd.part_number = pmp.part_number
GROUP BY pm.project_id, pmp.part_number, sd.qte_gdc, sd.qte_jdc, sd.qte_cat_network,
         sd.qte_succ_10, sd.qte_succ_11, sd.qte_succ_12, sd.qte_succ_13, sd.qte_succ_14,
         sd.qte_succ_19, sd.qte_succ_20, sd.qte_succ_21, sd.qte_succ_22, sd.qte_succ_24,
         sd.qte_succ_30, sd.qte_succ_40, sd.qte_succ_50, sd.qte_succ_60, sd.qte_succ_70,
         sd.qte_succ_80, sd.qte_succ_90;

-- Recreate unique index for concurrent refresh compatibility
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_stock_avail_unique 
  ON mv_project_parts_stock_availability(project_id, part_number);

-- Recreate mv_project_analytics_complete (unchanged logic, now depends on new stock MV)
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


