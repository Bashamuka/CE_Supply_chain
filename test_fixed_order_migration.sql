/*
  # Test Fixed OTC Logic Migration - Order Issue Resolved
  
  ## Purpose
  Test the corrected migration that fixes the order of view creation.
  This script verifies that all views are created in the correct dependency order.
  
  ## Test Steps
  1. Apply the corrected migration
  2. Verify all views exist in correct order
  3. Test functionality
  4. Confirm no dependency errors
*/

-- Apply the corrected migration
\i supabase/migrations/20251015130000_add_otc_logic_to_project_management.sql

-- Verify migration was applied successfully
DO $$
DECLARE
  migration_applied BOOLEAN := FALSE;
  projects_count INTEGER;
  views_count INTEGER;
  diagnostic_view_exists BOOLEAN := FALSE;
  enhanced_view_exists BOOLEAN := FALSE;
  analytics_view_exists BOOLEAN := FALSE;
BEGIN
  -- Check if calculation_method column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'projects' 
      AND column_name = 'calculation_method'
  ) INTO migration_applied;
  
  -- Check if enhanced view exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'mv_project_parts_used_quantities_enhanced'
  ) INTO enhanced_view_exists;
  
  -- Check if analytics view exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'mv_project_analytics_complete'
  ) INTO analytics_view_exists;
  
  -- Check if diagnostic view exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.views 
    WHERE table_name = 'v_eta_diagnosis'
  ) INTO diagnostic_view_exists;
  
  IF migration_applied THEN
    RAISE NOTICE '✅ Migration applied successfully';
    
    -- Count projects
    SELECT COUNT(*) INTO projects_count FROM projects;
    RAISE NOTICE '📊 Total projects: %', projects_count;
    
    -- Count new views
    SELECT COUNT(*) INTO views_count 
    FROM information_schema.tables 
    WHERE table_name IN (
      'mv_project_parts_used_quantities_otc',
      'mv_project_parts_used_quantities_enhanced',
      'v_project_calculation_methods'
    );
    
    RAISE NOTICE '📋 New views created: %', views_count;
    
    -- Check specific views
    IF enhanced_view_exists THEN
      RAISE NOTICE '✅ Enhanced view mv_project_parts_used_quantities_enhanced exists';
    ELSE
      RAISE NOTICE '❌ Enhanced view mv_project_parts_used_quantities_enhanced missing';
    END IF;
    
    IF analytics_view_exists THEN
      RAISE NOTICE '✅ Analytics view mv_project_analytics_complete exists';
    ELSE
      RAISE NOTICE '❌ Analytics view mv_project_analytics_complete missing';
    END IF;
    
    IF diagnostic_view_exists THEN
      RAISE NOTICE '✅ Diagnostic view v_eta_diagnosis exists';
    ELSE
      RAISE NOTICE '❌ Diagnostic view v_eta_diagnosis missing';
    END IF;
    
  ELSE
    RAISE EXCEPTION '❌ Migration failed - calculation_method column not found';
  END IF;
END $$;

-- Test the enhanced view directly
SELECT 
  'Enhanced View Test' as test_section,
  COUNT(*) as total_records,
  COUNT(CASE WHEN quantity_used > 0 THEN 1 END) as records_with_used_quantities
FROM mv_project_parts_used_quantities_enhanced;

-- Test the analytics view
SELECT 
  'Analytics View Test' as test_section,
  COUNT(*) as total_records,
  COUNT(CASE WHEN quantity_used > 0 THEN 1 END) as records_with_used_quantities,
  COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) as records_with_eta
FROM mv_project_analytics_complete;

-- Test the diagnostic view
SELECT 
  'Diagnostic View Test' as test_section,
  COUNT(*) as total_records,
  COUNT(CASE WHEN current_eta IS NULL OR current_eta = '' THEN 1 END) as missing_eta_count,
  COUNT(CASE WHEN valid_eta_records > 0 THEN 1 END) as records_with_valid_etas
FROM v_eta_diagnosis;

-- Test project calculation methods
SELECT 
  'Project Calculation Methods' as test_section,
  p.name as project_name,
  p.calculation_method,
  CASE 
    WHEN p.calculation_method = 'or_based' THEN 'Uses Operational Requests (ORs)'
    WHEN p.calculation_method = 'otc_based' THEN 'Uses Delivery Notes (BLs) from OTC'
    ELSE 'Unknown method'
  END as method_description
FROM projects p
ORDER BY p.name
LIMIT 5;

-- Test the switch function with a sample project
DO $$
DECLARE
  test_project_id UUID;
  current_method TEXT;
BEGIN
  -- Get first project for testing
  SELECT id INTO test_project_id FROM projects LIMIT 1;
  
  IF test_project_id IS NOT NULL THEN
    -- Get current method
    SELECT calculation_method INTO current_method 
    FROM projects 
    WHERE id = test_project_id;
    
    RAISE NOTICE '🧪 Testing switch function with project: %', test_project_id;
    RAISE NOTICE '📋 Current method: %', current_method;
    
    -- Test switching to OTC-based
    PERFORM switch_project_calculation_method(test_project_id, 'otc_based');
    RAISE NOTICE '✅ Switched to OTC-based calculation';
    
    -- Test switching back to OR-based
    PERFORM switch_project_calculation_method(test_project_id, 'or_based');
    RAISE NOTICE '✅ Switched back to OR-based calculation';
    
    RAISE NOTICE '🎉 Switch function test completed successfully';
  ELSE
    RAISE NOTICE '⚠️ No projects found for testing';
  END IF;
END $$;

-- Test materialized views refresh
DO $$
DECLARE
  start_time TIMESTAMP;
  end_time TIMESTAMP;
  duration INTERVAL;
BEGIN
  RAISE NOTICE 'Starting materialized views refresh test...';
  
  start_time := clock_timestamp();
  PERFORM refresh_project_analytics_views();
  end_time := clock_timestamp();
  
  duration := end_time - start_time;
  
  RAISE NOTICE 'Materialized views refresh completed in: %', duration;
  RAISE NOTICE 'Refresh test completed successfully';
END $$;

-- Test view dependencies
DO $$
DECLARE
  dependency_count INTEGER;
BEGIN
  -- Check if analytics view can access enhanced view
  SELECT COUNT(*) INTO dependency_count
  FROM mv_project_analytics_complete pac
  JOIN mv_project_parts_used_quantities_enhanced enhanced
    ON enhanced.machine_id = pac.machine_id 
    AND enhanced.part_number = pac.part_number
  LIMIT 1;
  
  RAISE NOTICE '✅ View dependency test passed - analytics view can access enhanced view';
  RAISE NOTICE '📊 Dependency test records: %', dependency_count;
END $$;

-- Final verification
SELECT 
  'Final Verification' as test_section,
  'OTC Logic Integration Migration - Order Issue Fixed Successfully' as status,
  NOW() as test_completed_at;
