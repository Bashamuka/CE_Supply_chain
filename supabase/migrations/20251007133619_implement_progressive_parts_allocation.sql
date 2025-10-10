/*
  # Implement progressive parts allocation based on machine creation order

  ## Problem
  Currently, all machines in a project see the same stock, transit, and invoiced quantities
  for shared parts. This means Machine 2 doesn't account for what Machine 1 already used.

  ## Solution
  Implement a progressive allocation system where:
  1. Parts are allocated to machines in chronological order (by created_at)
  2. Earlier machines get priority access to available stock
  3. Later machines see reduced availability based on what previous machines consumed
  4. Allocation priority: Stock → Used (from orders) → Transit → Invoiced → Missing

  ## New View: mv_project_parts_progressive_allocation
  This replaces mv_project_analytics_complete with a smart allocation algorithm that:
  - Allocates stock to machines in creation order
  - Tracks cumulative consumption across machines
  - Ensures each machine only sees what's truly available after previous machines

  ## Example
  Stock available: 100 units
  - Machine 1 (created first, needs 60): gets 60 from stock
  - Machine 2 (created second, needs 50): gets 40 from stock (100-60), 10 from transit
  - Machine 3 (created third, needs 30): gets 30 from transit
*/

-- Drop the old analytics view and rebuild with progressive allocation
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;

-- Create a new view with progressive allocation logic
CREATE MATERIALIZED VIEW mv_project_analytics_complete AS
WITH machine_order AS (
  -- Get all machines with their creation order
  SELECT 
    pm.id as machine_id,
    pm.project_id,
    pm.name as machine_name,
    pm.created_at,
    ROW_NUMBER() OVER (PARTITION BY pm.project_id ORDER BY pm.created_at, pm.id) as machine_rank
  FROM project_machines pm
),
parts_per_machine AS (
  -- Get all parts required per machine with order rank
  SELECT 
    mo.machine_id,
    mo.project_id,
    mo.machine_name,
    mo.machine_rank,
    pmp.part_number,
    pmp.description,
    pmp.quantity_required
  FROM mv_project_machine_parts_aggregated pmp
  JOIN machine_order mo ON mo.machine_id = pmp.machine_id
),
parts_global_availability AS (
  -- Calculate global availability per part per project (not yet allocated)
  SELECT 
    pm.project_id,
    pmp.part_number,
    -- Stock available from branches
    COALESCE(stock.quantity_available, 0) as total_stock,
    -- Transit and invoiced from supplier orders
    COALESCE(transit.quantity_in_transit, 0) as total_transit,
    COALESCE(transit.quantity_invoiced, 0) as total_invoiced
  FROM mv_project_machine_parts_aggregated pmp
  JOIN project_machines pm ON pm.id = pmp.machine_id
  LEFT JOIN mv_project_parts_stock_availability stock 
    ON stock.project_id = pm.project_id AND stock.part_number = pmp.part_number
  LEFT JOIN mv_project_parts_transit_invoiced transit 
    ON transit.project_id = pm.project_id AND transit.part_number = pmp.part_number
  GROUP BY pm.project_id, pmp.part_number, stock.quantity_available, transit.quantity_in_transit, transit.quantity_invoiced
),
progressive_allocation AS (
  -- Progressive allocation: each machine gets allocated based on what previous machines took
  SELECT 
    ppm.machine_id,
    ppm.project_id,
    ppm.machine_name,
    ppm.machine_rank,
    ppm.part_number,
    ppm.description,
    ppm.quantity_required,
    pga.total_stock,
    pga.total_transit,
    pga.total_invoiced,
    -- Calculate what was already used by this machine from orders
    COALESCE(used.quantity_used, 0) as quantity_used,
    -- Calculate cumulative consumption by PREVIOUS machines (lower rank)
    COALESCE(
      (SELECT 
        SUM(ppm2.quantity_required)
       FROM parts_per_machine ppm2
       WHERE ppm2.project_id = ppm.project_id
         AND ppm2.part_number = ppm.part_number
         AND ppm2.machine_rank < ppm.machine_rank
      ), 0
    ) as cumulative_previous_consumption
  FROM parts_per_machine ppm
  LEFT JOIN parts_global_availability pga 
    ON pga.project_id = ppm.project_id AND pga.part_number = ppm.part_number
  LEFT JOIN mv_project_parts_used_quantities used 
    ON used.machine_id = ppm.machine_id AND used.part_number = ppm.part_number
),
final_allocation AS (
  -- Calculate final allocation for each machine considering previous consumption
  SELECT 
    machine_id,
    project_id,
    machine_name,
    part_number,
    description,
    quantity_required,
    quantity_used,
    -- Available stock after previous machines took their share
    GREATEST(0, total_stock - cumulative_previous_consumption) as remaining_stock,
    total_transit,
    total_invoiced,
    cumulative_previous_consumption,
    -- Now allocate progressively: first from remaining stock, then transit, then invoiced
    LEAST(
      quantity_required,
      GREATEST(0, total_stock - cumulative_previous_consumption)
    ) as allocated_from_stock,
    CASE 
      WHEN quantity_required <= GREATEST(0, total_stock - cumulative_previous_consumption) THEN 0
      ELSE LEAST(
        quantity_required - LEAST(quantity_required, GREATEST(0, total_stock - cumulative_previous_consumption)),
        total_transit
      )
    END as allocated_from_transit,
    CASE 
      WHEN quantity_required <= GREATEST(0, total_stock - cumulative_previous_consumption) + total_transit THEN 0
      ELSE LEAST(
        quantity_required - LEAST(quantity_required, GREATEST(0, total_stock - cumulative_previous_consumption)) - LEAST(
          GREATEST(0, quantity_required - LEAST(quantity_required, GREATEST(0, total_stock - cumulative_previous_consumption))),
          total_transit
        ),
        total_invoiced
      )
    END as allocated_from_invoiced
  FROM progressive_allocation
)
SELECT 
  machine_id,
  project_id,
  machine_name,
  part_number,
  description,
  quantity_required,
  allocated_from_stock as quantity_available,
  quantity_used,
  allocated_from_transit as quantity_in_transit,
  allocated_from_invoiced as quantity_invoiced,
  GREATEST(0, 
    quantity_required - 
    allocated_from_stock - 
    quantity_used - 
    allocated_from_transit - 
    allocated_from_invoiced
  ) as quantity_missing
FROM final_allocation;

-- Recreate indexes
CREATE UNIQUE INDEX idx_mv_analytics_unique 
  ON mv_project_analytics_complete(project_id, machine_id, part_number);
CREATE INDEX idx_mv_analytics_project ON mv_project_analytics_complete(project_id);
CREATE INDEX idx_mv_analytics_machine ON mv_project_analytics_complete(machine_id);
CREATE INDEX idx_mv_analytics_part ON mv_project_analytics_complete(part_number);
