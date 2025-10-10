/*
  # Clean Stock Dispo Duplicates

  ## Problem
  The stock_dispo table contains duplicate part_numbers and empty part_numbers.
  This causes issues in materialized views that assume one row per part_number.

  ## Solution
  1. Delete rows with empty or NULL part_numbers
  2. For duplicate part_numbers, keep only the most recent row (highest id)
  3. Add unique constraint to prevent future duplicates
  4. Recreate materialized views without aggregation

  ## Changes
  - Clean duplicate and empty part_numbers in stock_dispo
  - Add unique constraint on part_number
  - Simplify mv_project_parts_stock_availability view
*/

-- Step 1: Delete rows with empty or NULL part_numbers
DELETE FROM stock_dispo
WHERE part_number IS NULL OR part_number = '';

-- Step 2: Delete duplicate part_numbers, keeping only the row with highest id (most recent)
DELETE FROM stock_dispo
WHERE id IN (
  SELECT id
  FROM (
    SELECT 
      id,
      ROW_NUMBER() OVER (PARTITION BY part_number ORDER BY id DESC) as rn
    FROM stock_dispo
    WHERE part_number IS NOT NULL AND part_number != ''
  ) sub
  WHERE rn > 1
);

-- Step 3: Add unique constraint to prevent future duplicates
CREATE UNIQUE INDEX IF NOT EXISTS idx_stock_dispo_part_number_unique 
ON stock_dispo(part_number) 
WHERE part_number IS NOT NULL AND part_number != '';

-- Step 4: Recreate materialized views without aggregation
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_stock_availability CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;

-- Recreate stock availability view (simplified - no more aggregation needed)
CREATE MATERIALIZED VIEW mv_project_parts_stock_availability AS
SELECT 
  pm.project_id,
  pmp.part_number,
  COALESCE(
    COALESCE(sd.qté_gdc, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'gdc') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_jdc, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'jdc') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_cat_network, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'cat_network') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_10, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_10') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_11, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_11') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_12, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_12') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_13, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_13') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_14, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_14') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_19, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_19') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_20, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_20') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_21, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_21') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_22, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_22') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_24, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_24') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_30, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_30') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_40, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_40') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_50, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_50') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_60, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_60') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_70, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_70') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_80, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_80') THEN 1 ELSE 0 END +
    COALESCE(sd.qté_succ_90, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_90') THEN 1 ELSE 0 END,
    0
  ) as quantity_available
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
LEFT JOIN stock_dispo sd ON sd.part_number = pmp.part_number
GROUP BY pm.project_id, pmp.part_number, sd.qté_gdc, sd.qté_jdc, sd.qté_cat_network, 
         sd.qté_succ_10, sd.qté_succ_11, sd.qté_succ_12, sd.qté_succ_13, sd.qté_succ_14,
         sd.qté_succ_19, sd.qté_succ_20, sd.qté_succ_21, sd.qté_succ_22, sd.qté_succ_24,
         sd.qté_succ_30, sd.qté_succ_40, sd.qté_succ_50, sd.qté_succ_60, sd.qté_succ_70,
         sd.qté_succ_80, sd.qté_succ_90;

CREATE UNIQUE INDEX idx_mv_stock_avail_unique ON mv_project_parts_stock_availability(project_id, part_number);
CREATE INDEX idx_mv_stock_avail_project ON mv_project_parts_stock_availability(project_id);
CREATE INDEX idx_mv_stock_avail_part ON mv_project_parts_stock_availability(part_number);

-- Recreate analytics complete view
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
