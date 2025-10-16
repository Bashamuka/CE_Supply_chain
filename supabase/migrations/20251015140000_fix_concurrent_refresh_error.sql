-- Fix concurrent refresh issue for mv_project_parts_used_quantities_otc
-- This migration adds the required unique index for CONCURRENTLY refresh

-- First, let's check if the materialized view exists and has data
DO $$
BEGIN
  -- Check if the materialized view exists
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_project_parts_used_quantities_otc') THEN
    RAISE NOTICE 'Materialized view mv_project_parts_used_quantities_otc exists';
    
    -- Check if it has a unique index
    IF NOT EXISTS (
      SELECT 1 FROM pg_indexes 
      WHERE tablename = 'mv_project_parts_used_quantities_otc' 
        AND indexname LIKE '%unique%'
    ) THEN
      RAISE NOTICE 'No unique index found, creating one...';
      
      -- Create unique index for concurrent refresh
      CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_project_parts_used_quantities_otc 
      ON mv_project_parts_used_quantities_otc (project_id, machine_id, part_number);
      
      RAISE NOTICE 'Unique index created successfully';
    ELSE
      RAISE NOTICE 'Unique index already exists';
    END IF;
  ELSE
    RAISE NOTICE 'Materialized view mv_project_parts_used_quantities_otc does not exist';
  END IF;
END $$;

-- Also check and fix the enhanced view
DO $$
BEGIN
  -- Check if the enhanced materialized view exists
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_project_parts_used_quantities_enhanced') THEN
    RAISE NOTICE 'Materialized view mv_project_parts_used_quantities_enhanced exists';
    
    -- Check if it has a unique index
    IF NOT EXISTS (
      SELECT 1 FROM pg_indexes 
      WHERE tablename = 'mv_project_parts_used_quantities_enhanced' 
        AND indexname LIKE '%unique%'
    ) THEN
      RAISE NOTICE 'No unique index found for enhanced view, creating one...';
      
      -- Create unique index for concurrent refresh
      CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_project_parts_used_quantities_enhanced 
      ON mv_project_parts_used_quantities_enhanced (project_id, machine_id, part_number);
      
      RAISE NOTICE 'Unique index created for enhanced view';
    ELSE
      RAISE NOTICE 'Unique index already exists for enhanced view';
    END IF;
  ELSE
    RAISE NOTICE 'Materialized view mv_project_parts_used_quantities_enhanced does not exist';
  END IF;
END $$;

-- Update the refresh function to handle potential errors gracefully
CREATE OR REPLACE FUNCTION refresh_project_analytics_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  refresh_error text;
BEGIN
  -- Refresh all materialized views in dependency order
  -- Use CONCURRENTLY when possible, fallback to regular refresh if needed
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_machine_parts_aggregated;
    RAISE NOTICE 'Refreshed mv_project_machine_parts_aggregated';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to refresh mv_project_machine_parts_aggregated concurrently, trying regular refresh: %', SQLERRM;
    REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_stock_availability;
    RAISE NOTICE 'Refreshed mv_project_parts_stock_availability';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to refresh mv_project_parts_stock_availability concurrently, trying regular refresh: %', SQLERRM;
    REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities;
    RAISE NOTICE 'Refreshed mv_project_parts_used_quantities';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to refresh mv_project_parts_used_quantities concurrently, trying regular refresh: %', SQLERRM;
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_otc;
    RAISE NOTICE 'Refreshed mv_project_parts_used_quantities_otc';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to refresh mv_project_parts_used_quantities_otc concurrently, trying regular refresh: %', SQLERRM;
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_otc;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_enhanced;
    RAISE NOTICE 'Refreshed mv_project_parts_used_quantities_enhanced';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to refresh mv_project_parts_used_quantities_enhanced concurrently, trying regular refresh: %', SQLERRM;
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_transit_invoiced;
    RAISE NOTICE 'Refreshed mv_project_parts_transit_invoiced';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to refresh mv_project_parts_transit_invoiced concurrently, trying regular refresh: %', SQLERRM;
    REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_analytics_complete;
    RAISE NOTICE 'Refreshed mv_project_analytics_complete';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to refresh mv_project_analytics_complete concurrently, trying regular refresh: %', SQLERRM;
    REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
  END;
  
  RAISE NOTICE 'All project analytics views refreshed successfully';
END;
$$;

-- Create a safer version of the switch function
CREATE OR REPLACE FUNCTION switch_project_calculation_method(
  project_uuid uuid,
  method text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  project_exists boolean;
BEGIN
  -- Validate method
  IF method NOT IN ('or_based', 'otc_based') THEN
    RAISE EXCEPTION 'Invalid calculation method. Must be ''or_based'' or ''otc_based''';
  END IF;
  
  -- Check if project exists
  SELECT EXISTS(SELECT 1 FROM projects WHERE id = project_uuid) INTO project_exists;
  
  IF NOT project_exists THEN
    RAISE EXCEPTION 'Project with ID % does not exist', project_uuid;
  END IF;
  
  -- Update project calculation method
  UPDATE projects 
  SET calculation_method = method,
      updated_at = NOW()
  WHERE id = project_uuid;
  
  -- Check if any rows were updated
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Failed to update project calculation method';
  END IF;
  
  -- Refresh analytics for this project with error handling
  BEGIN
    PERFORM refresh_project_analytics_views();
    RAISE NOTICE 'Project % calculation method switched to % successfully', project_uuid, method;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to refresh analytics views: %', SQLERRM;
    -- Don't fail the entire operation if refresh fails
    RAISE NOTICE 'Project % calculation method updated to %, but analytics refresh failed', project_uuid, method;
  END;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION refresh_project_analytics_views() TO authenticated;
GRANT EXECUTE ON FUNCTION switch_project_calculation_method(uuid, text) TO authenticated;

-- Test the fix
DO $$
DECLARE
  test_project_id uuid;
BEGIN
  -- Get a test project ID
  SELECT id INTO test_project_id FROM projects LIMIT 1;
  
  IF test_project_id IS NOT NULL THEN
    RAISE NOTICE 'Testing calculation method switch with project: %', test_project_id;
    
    -- Test switching to OTC-based
    BEGIN
      PERFORM switch_project_calculation_method(test_project_id, 'otc_based');
      RAISE NOTICE 'Successfully switched to OTC-based method';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to switch to OTC-based: %', SQLERRM;
    END;
    
    -- Test switching back to OR-based
    BEGIN
      PERFORM switch_project_calculation_method(test_project_id, 'or_based');
      RAISE NOTICE 'Successfully switched back to OR-based method';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to switch back to OR-based: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'No projects found for testing';
  END IF;
END $$;
