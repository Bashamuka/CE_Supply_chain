/*
  # Test Script for Concurrent Refresh Fix
  
  ## Purpose
  Test that the concurrent refresh error is fixed and calculation method switching works.
  
  ## Test Steps
  1. Check if unique indexes exist on materialized views
  2. Test calculation method switching
  3. Verify analytics refresh works
  4. Test error handling
*/

-- Check if unique indexes exist on materialized views
SELECT 
  'Index Check' as test_section,
  tablename as materialized_view,
  indexname as unique_index,
  CASE 
    WHEN indexname LIKE '%unique%' THEN 'EXISTS'
    ELSE 'MISSING'
  END as status
FROM pg_indexes 
WHERE tablename IN (
  'mv_project_parts_used_quantities_otc',
  'mv_project_parts_used_quantities_enhanced'
)
ORDER BY tablename, indexname;

-- Check materialized views status
SELECT 
  'Materialized Views Status' as test_section,
  matviewname as view_name,
  CASE 
    WHEN matviewname IS NOT NULL THEN 'EXISTS'
    ELSE 'MISSING'
  END as status
FROM pg_matviews 
WHERE matviewname IN (
  'mv_project_parts_used_quantities_otc',
  'mv_project_parts_used_quantities_enhanced'
)
ORDER BY matviewname;

-- Test calculation method switching
DO $$
DECLARE
  test_project_id uuid;
  current_method text;
BEGIN
  -- Get a test project ID
  SELECT id INTO test_project_id FROM projects LIMIT 1;
  
  IF test_project_id IS NOT NULL THEN
    -- Get current method
    SELECT calculation_method INTO current_method 
    FROM projects 
    WHERE id = test_project_id;
    
    RAISE NOTICE 'Testing with project: % (current method: %)', test_project_id, current_method;
    
    -- Test switching to OTC-based
    BEGIN
      PERFORM switch_project_calculation_method(test_project_id, 'otc_based');
      RAISE NOTICE 'SUCCESS: Switched to OTC-based method';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'FAILED: Switch to OTC-based - %', SQLERRM;
    END;
    
    -- Test switching back to OR-based
    BEGIN
      PERFORM switch_project_calculation_method(test_project_id, 'or_based');
      RAISE NOTICE 'SUCCESS: Switched back to OR-based method';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'FAILED: Switch back to OR-based - %', SQLERRM;
    END;
    
    -- Test invalid method
    BEGIN
      PERFORM switch_project_calculation_method(test_project_id, 'invalid_method');
      RAISE WARNING 'UNEXPECTED: Invalid method was accepted';
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'SUCCESS: Invalid method properly rejected - %', SQLERRM;
    END;
    
  ELSE
    RAISE NOTICE 'WARNING: No projects found for testing';
  END IF;
END $$;

-- Test analytics refresh function
DO $$
BEGIN
  RAISE NOTICE 'Testing analytics refresh function...';
  
  BEGIN
    PERFORM refresh_project_analytics_views();
    RAISE NOTICE 'SUCCESS: Analytics refresh completed without errors';
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'FAILED: Analytics refresh failed - %', SQLERRM;
  END;
END $$;

-- Final verification
SELECT 
  'Test Complete' as test_section,
  'Concurrent refresh fix has been tested' as status,
  NOW() as test_completed_at;
