/*
  # Apply OTC Logic Integration Migration
  
  ## Purpose
  Apply the migration that adds OTC logic to Project Management module.
  This script executes the migration and provides verification steps.
  
  ## Steps
  1. Apply the migration
  2. Verify the changes
  3. Test both calculation methods
  4. Provide usage instructions
*/

-- Apply the migration
\i supabase/migrations/20251015130000_add_otc_logic_to_project_management.sql

-- Verify migration was applied successfully
DO $$
DECLARE
  migration_applied BOOLEAN := FALSE;
  projects_count INTEGER;
  views_count INTEGER;
BEGIN
  -- Check if calculation_method column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'projects' 
      AND column_name = 'calculation_method'
  ) INTO migration_applied;
  
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
    
  ELSE
    RAISE EXCEPTION '❌ Migration failed - calculation_method column not found';
  END IF;
END $$;

-- Show current project calculation methods
SELECT 
  'Current Project Calculation Methods' as info,
  p.name as project_name,
  p.calculation_method,
  CASE 
    WHEN p.calculation_method = 'or_based' THEN 'Uses Operational Requests (ORs)'
    WHEN p.calculation_method = 'otc_based' THEN 'Uses Delivery Notes (BLs) from OTC'
    ELSE 'Unknown method'
  END as description
FROM projects p
ORDER BY p.name;

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

-- Show usage instructions
SELECT 
  'Usage Instructions' as section,
  'How to use the new OTC logic:' as instruction
UNION ALL
SELECT 
  '1. Switch Project Method',
  'Use: SELECT switch_project_calculation_method(project_id, ''otc_based'');'
UNION ALL
SELECT 
  '2. Check Project Methods',
  'Use: SELECT * FROM v_project_calculation_methods;'
UNION ALL
SELECT 
  '3. Refresh Analytics',
  'Use: SELECT refresh_project_analytics_views();'
UNION ALL
SELECT 
  '4. View Enhanced Analytics',
  'Use: SELECT * FROM mv_project_analytics_complete WHERE project_id = ''your_project_id'';';

-- Final status
SELECT 
  'Migration Status' as status,
  'OTC Logic Integration Applied Successfully' as message,
  NOW() as completed_at;
