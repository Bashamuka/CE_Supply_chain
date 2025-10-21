/*
  # Force refresh all project analytics views
  
  This migration ensures all materialized views are refreshed with the latest logic
  and fixes any inconsistencies that may have occurred during development.
*/

-- Refresh all materialized views in correct order
REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
