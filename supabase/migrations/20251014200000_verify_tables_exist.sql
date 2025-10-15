-- Quick verification that the tables exist
-- Run this after applying the migration

-- Check if tables exist
SELECT 
  'user_module_access' as table_name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_module_access') 
    THEN 'EXISTS' 
    ELSE 'MISSING' 
  END as status;

SELECT 
  'user_project_access' as table_name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_project_access') 
    THEN 'EXISTS' 
    ELSE 'MISSING' 
  END as status;

-- Check table structure
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'user_module_access'
ORDER BY ordinal_position;

-- Check constraints
SELECT 
  conname as constraint_name,
  contype as constraint_type,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'user_module_access'::regclass;

-- Test inserting a record (this will show if RLS is working)
SELECT 
  'RLS Test' as test_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM user_module_access LIMIT 1) 
    THEN 'Can read data' 
    ELSE 'Cannot read data (RLS may be blocking)' 
  END as result;
