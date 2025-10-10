/*
  # Fix materialized views refresh issue

  ## Changes
  - Add unique indexes to all materialized views to enable CONCURRENTLY refresh
  - These indexes are required for the refresh_project_analytics_views() function

  ## Technical Details
  Without unique indexes, PostgreSQL cannot perform REFRESH MATERIALIZED VIEW CONCURRENTLY,
  which allows queries to continue while the view is being refreshed.
*/

-- Add unique index to mv_project_machine_parts_aggregated
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_parts_agg_unique 
  ON mv_project_machine_parts_aggregated(machine_id, part_number);

-- Add unique index to mv_project_parts_stock_availability
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_stock_avail_unique 
  ON mv_project_parts_stock_availability(project_id, part_number);

-- Add unique index to mv_project_parts_used_quantities
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_used_unique 
  ON mv_project_parts_used_quantities(project_id, machine_id, part_number);

-- Add unique index to mv_project_parts_transit_invoiced
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_transit_unique 
  ON mv_project_parts_transit_invoiced(project_id, part_number);

-- Add unique index to mv_project_analytics_complete
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_analytics_unique 
  ON mv_project_analytics_complete(project_id, machine_id, part_number);
