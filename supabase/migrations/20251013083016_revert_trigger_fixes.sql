/*
  # Revert Trigger Return Statement Fixes

  1. Changes
    - Restore trigger functions to return NEW instead of NULL
    - Reverting migration 20251013082556

  2. Notes
    - This restores the previous state before the fix
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
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- If concurrent refresh fails, try regular refresh
    REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
    REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
    REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
    REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
    RETURN NEW;
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
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
    REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
    RETURN NEW;
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
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
    REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
    RETURN NEW;
END;
$$;
