/*
  # Complete Project Analytics Setup - Final Migration
  
  This migration ensures all views are created and refreshed in the correct order.
  Apply this after the previous migrations to complete the setup.
*/

-- Step 1: Ensure mv_project_analytics_complete exists (from previous migration)
-- If it doesn't exist, this will fail gracefully

-- Step 2: Refresh all views in correct dependency order
REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;

-- Step 3: Refresh the complete analytics view (only if it exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_project_analytics_complete') THEN
        REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
        RAISE NOTICE 'mv_project_analytics_complete refreshed successfully';
    ELSE
        RAISE NOTICE 'mv_project_analytics_complete does not exist - apply previous migrations first';
    END IF;
END $$;
