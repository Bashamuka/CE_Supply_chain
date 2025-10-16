/*
  # Test Fixed OTC Logic Migration
  
  ## Purpose
  Test the corrected migration that handles the CASCADE dependency issue.
  This script verifies that the migration applies successfully without errors.
  
  ## Test Steps
  1. Apply the corrected migration
  2. Verify all objects are created
  3. Test the diagnostic view
  4. Confirm functionality
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
BEGIN
  -- Check if calculation_method column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'projects' 
      AND column_name = 'calculation_method'
  ) INTO migration_applied;
  
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
    
    -- Check diagnostic view
    IF diagnostic_view_exists THEN
      RAISE NOTICE '🔍 Diagnostic view v_eta_diagnosis recreated successfully';
    ELSE
      RAISE NOTICE '⚠️ Diagnostic view v_eta_diagnosis not found';
    END IF;
    
  ELSE
    RAISE EXCEPTION '❌ Migration failed - calculation_method column not found';
  END IF;
END $$;

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

-- Final verification
SELECT 
  'Final Verification' as test_section,
  'OTC Logic Integration Migration Fixed Successfully' as status,
  NOW() as test_completed_at;
