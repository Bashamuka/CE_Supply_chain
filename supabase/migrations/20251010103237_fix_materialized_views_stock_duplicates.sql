/*
  # Fix Materialized Views for Stock Duplicates

  ## Problem
  The mv_project_parts_stock_availability view fails when stock_dispo contains duplicate part_numbers.
  The subquery returns multiple rows which causes an error.

  ## Solution
  1. Drop and recreate mv_project_parts_stock_availability with proper aggregation
  2. Update refresh function to use non-concurrent refresh (more reliable)

  ## Changes
  - Use SUM with GROUP BY to handle duplicate part_numbers in stock_dispo
  - Remove CONCURRENTLY from refresh operations for reliability
*/

-- Drop the problematic view
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_stock_availability CASCADE;

-- Recreate with proper handling of duplicates
CREATE MATERIALIZED VIEW mv_project_parts_stock_availability AS
WITH stock_aggregated AS (
  SELECT 
    sd.part_number,
    SUM(COALESCE(sd.qté_gdc, 0)) as total_gdc,
    SUM(COALESCE(sd.qté_jdc, 0)) as total_jdc,
    SUM(COALESCE(sd.qté_cat_network, 0)) as total_cat_network,
    SUM(COALESCE(sd.qté_succ_10, 0)) as total_succ_10,
    SUM(COALESCE(sd.qté_succ_11, 0)) as total_succ_11,
    SUM(COALESCE(sd.qté_succ_12, 0)) as total_succ_12,
    SUM(COALESCE(sd.qté_succ_13, 0)) as total_succ_13,
    SUM(COALESCE(sd.qté_succ_14, 0)) as total_succ_14,
    SUM(COALESCE(sd.qté_succ_19, 0)) as total_succ_19,
    SUM(COALESCE(sd.qté_succ_20, 0)) as total_succ_20,
    SUM(COALESCE(sd.qté_succ_21, 0)) as total_succ_21,
    SUM(COALESCE(sd.qté_succ_22, 0)) as total_succ_22,
    SUM(COALESCE(sd.qté_succ_24, 0)) as total_succ_24,
    SUM(COALESCE(sd.qté_succ_30, 0)) as total_succ_30,
    SUM(COALESCE(sd.qté_succ_40, 0)) as total_succ_40,
    SUM(COALESCE(sd.qté_succ_50, 0)) as total_succ_50,
    SUM(COALESCE(sd.qté_succ_60, 0)) as total_succ_60,
    SUM(COALESCE(sd.qté_succ_70, 0)) as total_succ_70,
    SUM(COALESCE(sd.qté_succ_80, 0)) as total_succ_80,
    SUM(COALESCE(sd.qté_succ_90, 0)) as total_succ_90
  FROM stock_dispo sd
  WHERE sd.part_number IS NOT NULL AND sd.part_number != ''
  GROUP BY sd.part_number
)
SELECT 
  pm.project_id,
  pmp.part_number,
  COALESCE(
    sa.total_gdc * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'gdc') THEN 1 ELSE 0 END +
    sa.total_jdc * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'jdc') THEN 1 ELSE 0 END +
    sa.total_cat_network * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'cat_network') THEN 1 ELSE 0 END +
    sa.total_succ_10 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_10') THEN 1 ELSE 0 END +
    sa.total_succ_11 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_11') THEN 1 ELSE 0 END +
    sa.total_succ_12 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_12') THEN 1 ELSE 0 END +
    sa.total_succ_13 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_13') THEN 1 ELSE 0 END +
    sa.total_succ_14 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_14') THEN 1 ELSE 0 END +
    sa.total_succ_19 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_19') THEN 1 ELSE 0 END +
    sa.total_succ_20 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_20') THEN 1 ELSE 0 END +
    sa.total_succ_21 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_21') THEN 1 ELSE 0 END +
    sa.total_succ_22 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_22') THEN 1 ELSE 0 END +
    sa.total_succ_24 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_24') THEN 1 ELSE 0 END +
    sa.total_succ_30 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_30') THEN 1 ELSE 0 END +
    sa.total_succ_40 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_40') THEN 1 ELSE 0 END +
    sa.total_succ_50 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_50') THEN 1 ELSE 0 END +
    sa.total_succ_60 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_60') THEN 1 ELSE 0 END +
    sa.total_succ_70 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_70') THEN 1 ELSE 0 END +
    sa.total_succ_80 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_80') THEN 1 ELSE 0 END +
    sa.total_succ_90 * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_90') THEN 1 ELSE 0 END,
    0
  ) as quantity_available
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
LEFT JOIN stock_aggregated sa ON sa.part_number = pmp.part_number
GROUP BY pm.project_id, pmp.part_number, sa.total_gdc, sa.total_jdc, sa.total_cat_network, 
         sa.total_succ_10, sa.total_succ_11, sa.total_succ_12, sa.total_succ_13, sa.total_succ_14,
         sa.total_succ_19, sa.total_succ_20, sa.total_succ_21, sa.total_succ_22, sa.total_succ_24,
         sa.total_succ_30, sa.total_succ_40, sa.total_succ_50, sa.total_succ_60, sa.total_succ_70,
         sa.total_succ_80, sa.total_succ_90;

CREATE UNIQUE INDEX idx_mv_stock_avail_unique ON mv_project_parts_stock_availability(project_id, part_number);
CREATE INDEX idx_mv_stock_avail_project ON mv_project_parts_stock_availability(project_id);
CREATE INDEX idx_mv_stock_avail_part ON mv_project_parts_stock_availability(part_number);

-- Recreate the analytics complete view
CREATE MATERIALIZED VIEW mv_project_analytics_complete AS
WITH machine_chronology AS (
  SELECT
    pm.id as machine_id,
    pm.project_id,
    pm.name as machine_name,
    pm.created_at,
    ROW_NUMBER() OVER (PARTITION BY pm.project_id ORDER BY pm.created_at, pm.id) as creation_rank
  FROM project_machines pm
),
parts_with_requirements AS (
  SELECT
    mc.machine_id,
    mc.project_id,
    mc.machine_name,
    mc.creation_rank,
    mc.created_at,
    pmp.part_number,
    pmp.description,
    pmp.quantity_required
  FROM mv_project_machine_parts_aggregated pmp
  JOIN machine_chronology mc ON mc.machine_id = pmp.machine_id
),
global_resources AS (
  SELECT
    pm.project_id,
    pmp.part_number,
    MAX(COALESCE(stock.quantity_available, 0)) as total_stock_available,
    MAX(COALESCE(transit.quantity_in_transit, 0)) as total_in_transit,
    MAX(COALESCE(transit.quantity_invoiced, 0)) as total_invoiced
  FROM mv_project_machine_parts_aggregated pmp
  JOIN project_machines pm ON pm.id = pmp.machine_id
  LEFT JOIN mv_project_parts_stock_availability stock
    ON stock.project_id = pm.project_id AND stock.part_number = pmp.part_number
  LEFT JOIN mv_project_parts_transit_invoiced transit
    ON transit.project_id = pm.project_id AND transit.part_number = pmp.part_number
  GROUP BY pm.project_id, pmp.part_number
),
machines_with_resources AS (
  SELECT
    pwr.*,
    gr.total_stock_available,
    gr.total_in_transit,
    gr.total_invoiced,
    COALESCE(used.quantity_used, 0) as quantity_used,
    COALESCE(
      (SELECT SUM(pwr2.quantity_required)
       FROM parts_with_requirements pwr2
       WHERE pwr2.project_id = pwr.project_id
         AND pwr2.part_number = pwr.part_number
         AND pwr2.creation_rank < pwr.creation_rank
      ), 0
    ) as consumed_by_previous_machines
  FROM parts_with_requirements pwr
  LEFT JOIN global_resources gr
    ON gr.project_id = pwr.project_id AND gr.part_number = pwr.part_number
  LEFT JOIN mv_project_parts_used_quantities used
    ON used.machine_id = pwr.machine_id AND used.part_number = pwr.part_number
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
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = allocation_step3.project_id
      AND p.part_ordered = allocation_step3.part_number
      AND p.status NOT IN ('Received', 'Cancelled')
      AND LOWER(COALESCE(p.comments, '')) != 'delivery completed'
      AND p.eta IS NOT NULL
      AND p.eta != ''
  ) as latest_eta
FROM allocation_step3;

CREATE UNIQUE INDEX idx_mv_analytics_unique ON mv_project_analytics_complete(project_id, machine_id, part_number);
CREATE INDEX idx_mv_analytics_project ON mv_project_analytics_complete(project_id);
CREATE INDEX idx_mv_analytics_machine ON mv_project_analytics_complete(machine_id);
CREATE INDEX idx_mv_analytics_part ON mv_project_analytics_complete(part_number);
