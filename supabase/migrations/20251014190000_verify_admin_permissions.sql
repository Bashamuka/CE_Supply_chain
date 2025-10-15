-- Verification script for admin permissions system
-- Run this to check if everything is properly configured

-- 1. Check table structure
SELECT 
  'user_module_access' as table_name,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'user_module_access'
ORDER BY ordinal_position;

-- 2. Check constraints
SELECT 
  conname as constraint_name,
  contype as constraint_type,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'user_module_access'::regclass;

-- 3. Check RLS status
SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename IN ('user_module_access', 'user_project_access');

-- 4. Check policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename IN ('user_module_access', 'user_project_access')
ORDER BY tablename, policyname;

-- 5. Check functions
SELECT 
  routine_name,
  routine_type,
  data_type as return_type
FROM information_schema.routines 
WHERE routine_name IN ('check_user_module_access', 'check_user_project_access')
ORDER BY routine_name;

-- 6. Test data access (this will show if RLS is working)
SELECT 
  'Current user can see' as test_type,
  COUNT(*) as record_count
FROM user_module_access;

-- 7. Check if we have any module access records
SELECT 
  'Module access records' as info,
  COUNT(*) as total_records,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(DISTINCT module_name) as unique_modules
FROM user_module_access;

-- 8. List all modules in the system
SELECT DISTINCT module_name 
FROM user_module_access 
ORDER BY module_name;
