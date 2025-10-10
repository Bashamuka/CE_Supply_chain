/*
  # Restore Progressive Allocation with ETA Support

  ## Problem
  The previous migration (20251007180759) replaced the progressive allocation logic
  with a simple global allocation, breaking the "first machine served first" principle.

  ## Solution
  Restore the progressive allocation algorithm where:
  1. Machines are ranked by creation order (created_at, then id)
  2. Each machine gets allocated resources AFTER previous machines have been served
  3. Stock is allocated progressively: Machine 1 first, then Machine 2 (with remaining stock), etc.
  4. Add ETA field to track latest delivery dates

  ## Example with Progressive Allocation
  Stock available: 100 units of Part X
  - Machine 1 (created first, needs 60): gets 60 from stock
  - Machine 2 (created second, needs 50): gets 40 from stock (100-60 remaining), needs 10 more
  - Machine 3 (created third, needs 30): gets 0 from stock (100-60-40=0 remaining), needs 30 more

  ## Changes
  1. Drop existing view
  2. Recreate with progressive allocation logic
  3. Add latest_eta field with proper filtering
  4. Maintain all indexes
*/

-- Drop existing view
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;

-- Recreate with progressive allocation AND ETA
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
    -- Calculate what previous machines already consumed (PROGRESSIVE ALLOCATION)
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
    -- Stock remaining AFTER previous machines took their share
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
-- Final result with ETA
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
  -- Add latest ETA: take MAX (furthest date) for realistic estimates
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

-- Recreate indexes
CREATE UNIQUE INDEX idx_mv_analytics_unique
  ON mv_project_analytics_complete(project_id, machine_id, part_number);
CREATE INDEX idx_mv_analytics_project ON mv_project_analytics_complete(project_id);
CREATE INDEX idx_mv_analytics_machine ON mv_project_analytics_complete(machine_id);
CREATE INDEX idx_mv_analytics_part ON mv_project_analytics_complete(part_number);
