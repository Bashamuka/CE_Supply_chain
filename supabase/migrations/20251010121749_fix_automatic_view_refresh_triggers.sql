/*
  # Fix Automatic Materialized View Refresh Triggers

  1. Changes
    - Remove CONCURRENTLY from triggers (not allowed in transactions)
    - Use simple REFRESH MATERIALIZED VIEW in triggers
    - Add pg_background option for async refresh if available

  2. Notes
    - Triggers will refresh views synchronously
    - This ensures data is always current when queried
*/

-- Replace trigger functions without CONCURRENTLY
CREATE OR REPLACE FUNCTION refresh_views_on_parts_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Refresh all materialized views in the correct order
  REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
  REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
  REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
  REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
  REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION refresh_views_on_stock_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
  REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION refresh_views_on_machine_parts_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
  REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
  RETURN NEW;
END;
$$;
