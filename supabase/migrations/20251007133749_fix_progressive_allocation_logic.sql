/*
  # Fix progressive allocation logic

  ## Problem Found
  The previous implementation had issues with:
  1. Using machine_rank per project instead of globally
  2. Not properly handling aggregated parts from mv_project_machine_parts_aggregated
  3. Complex allocation logic that didn't properly distribute resources

  ## New Approach
  Simpler, clearer progressive allocation:
  1. Use aggregated parts (deduped within each machine)
  2. Sort machines by creation date within their project
  3. For each part in each machine, calculate remaining resources after previous machines
  4. Allocate in order: Stock → Transit → Invoiced → Mark as Missing
*/

DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;

CREATE MATERIALIZED VIEW mv_project_analytics_complete AS
WITH machine_chronology AS (
  -- Rank machines within their project by creation order
  SELECT 
    pm.id as machine_id,
    pm.project_id,
    pm.name as machine_name,
    pm.created_at,
    ROW_NUMBER() OVER (PARTITION BY pm.project_id ORDER BY pm.created_at, pm.id) as creation_rank
  FROM project_machines pm
),
parts_with_requirements AS (
  -- All parts per machine with their requirements
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
  -- Total resources available per part per project (before any allocation)
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
  -- Join requirements with global resources
  SELECT 
    pwr.*,
    gr.total_stock_available,
    gr.total_in_transit,
    gr.total_invoiced,
    COALESCE(used.quantity_used, 0) as quantity_used,
    -- Calculate what previous machines already consumed
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
  -- Calculate allocation for each machine progressively
  SELECT 
    machine_id,
    project_id,
    machine_name,
    part_number,
    description,
    quantity_required,
    quantity_used,
    creation_rank,
    -- Stock remaining after previous machines
    GREATEST(0, total_stock_available - consumed_by_previous_machines) as stock_remaining,
    total_in_transit,
    total_invoiced,
    consumed_by_previous_machines,
    -- Step 1: Allocate from remaining stock
    LEAST(
      quantity_required,
      GREATEST(0, total_stock_available - consumed_by_previous_machines)
    ) as qty_from_stock
  FROM machines_with_resources
),
allocation_step2 AS (
  -- Step 2: Allocate from transit for what stock couldn't cover
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
  -- Step 3: Allocate from invoiced for what's still needed
  SELECT 
    *,
    GREATEST(0, still_needed_after_stock - qty_from_transit) as still_needed_after_transit,
    LEAST(
      GREATEST(0, still_needed_after_stock - qty_from_transit),
      total_invoiced
    ) as qty_from_invoiced
  FROM allocation_step2
)
-- Final result
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
  GREATEST(0, quantity_required - qty_from_stock - quantity_used - qty_from_transit - qty_from_invoiced) as quantity_missing
FROM allocation_step3;

-- Recreate indexes
CREATE UNIQUE INDEX idx_mv_analytics_unique 
  ON mv_project_analytics_complete(project_id, machine_id, part_number);
CREATE INDEX idx_mv_analytics_project ON mv_project_analytics_complete(project_id);
CREATE INDEX idx_mv_analytics_machine ON mv_project_analytics_complete(machine_id);
CREATE INDEX idx_mv_analytics_part ON mv_project_analytics_complete(part_number);
