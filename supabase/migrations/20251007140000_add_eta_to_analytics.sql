/*
  # Add ETA to Project Analytics

  ## Purpose
  Add the latest ETA (Estimated Time of Arrival) for each part to the analytics view.
  When a part appears in multiple orders, we take the furthest (longest) ETA date
  to give a realistic estimate of when the part will be available.

  ## Changes
  1. Drop and recreate mv_project_analytics_complete to include latest_eta
  2. Update the refresh function to handle the new view structure

  ## ETA Logic
  - Select the MAX(eta) for each part across all orders in project supplier orders
  - Only consider orders that are not yet delivered (status NOT IN 'Received', 'Cancelled')
  - Exclude orders with 'delivery completed' comments
  - NULL if no ETA available
*/

-- Drop existing view
DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete;

-- Recreate with ETA field
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
  ) as quantity_missing,
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pm.project_id
      AND p.part_ordered = pmp.part_number
      AND p.status NOT IN ('Received', 'Cancelled')
      AND LOWER(COALESCE(p.comments, '')) != 'delivery completed'
      AND p.eta IS NOT NULL
      AND p.eta != ''
  ) as latest_eta
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
LEFT JOIN mv_project_parts_stock_availability stock
  ON stock.project_id = pm.project_id AND stock.part_number = pmp.part_number
LEFT JOIN mv_project_parts_used_quantities used
  ON used.machine_id = pmp.machine_id AND used.part_number = pmp.part_number
LEFT JOIN mv_project_parts_transit_invoiced transit
  ON transit.project_id = pm.project_id AND transit.part_number = pmp.part_number;

CREATE INDEX IF NOT EXISTS idx_mv_analytics_project ON mv_project_analytics_complete(project_id);
CREATE INDEX IF NOT EXISTS idx_mv_analytics_machine ON mv_project_analytics_complete(machine_id);
CREATE INDEX IF NOT EXISTS idx_mv_analytics_part ON mv_project_analytics_complete(part_number);
