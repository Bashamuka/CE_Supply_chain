/*
  # Fix progressive allocation for Transit/Invoiced

  Problem: qty_from_transit was based on total_in_transit for every machine,
  not on the remaining quantity after earlier machines. This caused under/over
  allocation in some machines (e.g. part 1559646 case).

  Approach: compute running needs and allocate progressively using window sums:
  - Step 1 (Stock): allocate from remaining stock after previous machines' requirements
  - Step 2 (Transit): for each row, remaining transit = total_in_transit - cumulative_need_after_stock_before
                      qty_from_transit = min(need_after_stock_current, max(0, remaining transit))
  - Step 3 (Invoiced): remaining invoiced = total_invoiced - max(0, cumulative_need_after_stock_before - total_in_transit)
                        qty_from_invoiced = min(need_after_transit_current, max(0, remaining invoiced))
*/

DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;

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
base AS (
  SELECT
    pwr.*,
    gr.total_stock_available,
    gr.total_in_transit,
    gr.total_invoiced,
    COALESCE(used.quantity_used, 0) as quantity_used
  FROM parts_with_requirements pwr
  LEFT JOIN global_resources gr
    ON gr.project_id = pwr.project_id AND gr.part_number = pwr.part_number
  LEFT JOIN mv_project_parts_used_quantities used
    ON used.machine_id = pwr.machine_id AND used.part_number = pwr.part_number
),
stock_step AS (
  SELECT
    *,
    -- Need before any allocation considers what's already Used
    GREATEST(0, quantity_required - quantity_used) as need_before_any,
    -- Remaining stock before this machine based on cumulative needs (after Used) of previous machines
    LEAST(
      GREATEST(0, quantity_required - quantity_used),
      GREATEST(
        0,
        total_stock_available - (
          SUM(GREATEST(0, quantity_required - quantity_used)) OVER (
            PARTITION BY project_id, part_number
            ORDER BY creation_rank
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
          )
        )
      )
    ) as qty_from_stock,
    NULL::numeric as placeholder
  FROM base
),
stock_need AS (
  SELECT
    *,
    GREATEST(0, GREATEST(0, quantity_required - quantity_used) - qty_from_stock) as need_after_stock,
    -- Cumulative needs after stock for previous machines
    SUM(GREATEST(0, GREATEST(0, quantity_required - quantity_used) - qty_from_stock)) OVER (
      PARTITION BY project_id, part_number
      ORDER BY creation_rank
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) as cum_need_after_stock_before
  FROM stock_step
),
transit_step AS (
  SELECT
    *,
    -- Remaining transit after previous machines tried to cover their needs from transit
    GREATEST(0, total_in_transit - COALESCE(cum_need_after_stock_before, 0)) as remaining_transit,
    LEAST(need_after_stock, GREATEST(0, total_in_transit - COALESCE(cum_need_after_stock_before, 0))) as qty_from_transit,
    GREATEST(0, need_after_stock - LEAST(need_after_stock, GREATEST(0, total_in_transit - COALESCE(cum_need_after_stock_before, 0)))) as need_after_transit
  FROM stock_need
),
invoiced_step AS (
  SELECT
    *,
    -- Transit consumed by all previous machines equals min(total_in_transit, cum_need_after_stock_before)
    GREATEST(0, total_invoiced - GREATEST(0, COALESCE(cum_need_after_stock_before, 0) - total_in_transit)) as remaining_invoiced,
    LEAST(
      need_after_transit,
      GREATEST(0, total_invoiced - GREATEST(0, COALESCE(cum_need_after_stock_before, 0) - total_in_transit))
    ) as qty_from_invoiced
  FROM transit_step
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
  GREATEST(0, quantity_required - quantity_used - qty_from_stock - qty_from_transit - qty_from_invoiced) as quantity_missing,
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = invoiced_step.project_id
      AND p.part_ordered = invoiced_step.part_number
      AND p.status NOT IN ('Griefed', 'Cancelled')
      AND LOWER(COALESCE(p.comments, '')) != 'delivery completed'
      AND p.eta IS NOT NULL
      AND p.eta != ''
  ) as latest_eta
FROM invoiced_step;

-- Keep indexes for performance
CREATE UNIQUE INDEX idx_mv_analytics_unique ON mv_project_analytics_complete(project_id, machine_id, part_number);
CREATE INDEX idx_mv_analytics_project ON mv_project_analytics_complete(project_id);
CREATE INDEX idx_mv_analytics_machine ON mv_project_analytics_complete(machine_id);
CREATE INDEX idx_mv_analytics_part ON mv_project_analytics_complete(part_number);


