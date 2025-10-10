/*
  # Add Automatic Materialized View Refresh

  1. Changes
    - Create trigger functions to automatically refresh materialized views when data changes
    - Add triggers on key tables (parts, stock_dispo, project_machines, project_machine_parts, etc.)
    - Ensure analytics are always up-to-date without manual refresh

  2. Security
    - Functions run with SECURITY DEFINER to allow view refresh
    - Only triggered by actual data changes
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

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trigger_refresh_views_on_parts_update ON parts;
DROP TRIGGER IF EXISTS trigger_refresh_views_on_stock_update ON stock_dispo;
DROP TRIGGER IF EXISTS trigger_refresh_views_on_machine_parts_update ON project_machine_parts;

-- Create triggers (AFTER INSERT OR UPDATE OR DELETE, statement level to avoid multiple refreshes)
CREATE TRIGGER trigger_refresh_views_on_parts_update
AFTER INSERT OR UPDATE OR DELETE ON parts
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_views_on_parts_change();

CREATE TRIGGER trigger_refresh_views_on_stock_update
AFTER INSERT OR UPDATE OR DELETE ON stock_dispo
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_views_on_stock_change();

CREATE TRIGGER trigger_refresh_views_on_machine_parts_update
AFTER INSERT OR UPDATE OR DELETE ON project_machine_parts
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_views_on_machine_parts_change();
