/*
  # Fix Trigger Return Statements

  1. Changes
    - Fix all trigger functions to return NULL instead of NEW
    - STATEMENT-level triggers must return NULL, not NEW
    - This resolves the Security Audit error

  2. Notes
    - Affects all refresh trigger functions
    - No data changes, only function definitions
*/

-- Function to refresh views after parts table changes
CREATE OR REPLACE FUNCTION refresh_views_on_parts_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Refresh all materialized views in the correct order
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_machine_parts_aggregated;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_stock_availability;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_transit_invoiced;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_analytics_complete;
  RETURN NULL;
EXCEPTION
  WHEN OTHERS THEN
    -- If concurrent refresh fails, try regular refresh
    REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
    REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
    REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
    REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
    RETURN NULL;
END;
$$;

-- Function to refresh views after stock_dispo table changes
CREATE OR REPLACE FUNCTION refresh_views_on_stock_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_stock_availability;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_analytics_complete;
  RETURN NULL;
EXCEPTION
  WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
    REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
    RETURN NULL;
END;
$$;

-- Function to refresh views after project_machine_parts table changes
CREATE OR REPLACE FUNCTION refresh_views_on_machine_parts_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_machine_parts_aggregated;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_analytics_complete;
  RETURN NULL;
EXCEPTION
  WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
    REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
    RETURN NULL;
END;
$$;
