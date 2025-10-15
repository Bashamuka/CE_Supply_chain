-- Comprehensive fix for admin permissions system
-- This migration addresses all potential issues with module access

-- 1. First, let's check if the table exists and has the right structure
DO $$
BEGIN
    -- Check if user_module_access table exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_module_access') THEN
        RAISE EXCEPTION 'Table user_module_access does not exist';
    END IF;
    
    -- Check if profiles table exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
        RAISE EXCEPTION 'Table profiles does not exist';
    END IF;
    
    RAISE NOTICE 'All required tables exist';
END $$;

-- 2. Drop and recreate the constraint to include global_dashboard
ALTER TABLE user_module_access DROP CONSTRAINT IF EXISTS user_module_access_module_name_check;

ALTER TABLE user_module_access ADD CONSTRAINT user_module_access_module_name_check 
CHECK (
  module_name IN (
    'global_dashboard',
    'eta_tracking',
    'stock_availability',
    'parts_equivalence',
    'orders',
    'projects',
    'dealer_forward_planning'
  )
);

-- 3. Drop all existing policies and recreate them properly
DROP POLICY IF EXISTS "Users can view their own module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can view all module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can insert module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can update module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can delete module access" ON user_module_access;

-- 4. Recreate all policies with proper syntax
CREATE POLICY "Users can view their own module access"
  ON user_module_access FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all module access"
  ON user_module_access FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can insert module access"
  ON user_module_access FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can update module access"
  ON user_module_access FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can delete module access"
  ON user_module_access FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- 5. Create a test function to verify everything works
CREATE OR REPLACE FUNCTION test_admin_permissions()
RETURNS TABLE(
  test_name text,
  result text,
  details text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  admin_user_id uuid;
  test_user_id uuid;
BEGIN
  -- Find an admin user
  SELECT id INTO admin_user_id 
  FROM profiles 
  WHERE role = 'admin' 
  LIMIT 1;
  
  -- Find any user for testing
  SELECT id INTO test_user_id 
  FROM profiles 
  LIMIT 1;
  
  -- Test 1: Check if we can insert module access
  BEGIN
    INSERT INTO user_module_access (user_id, module_name, has_access)
    VALUES (test_user_id, 'global_dashboard', true)
    ON CONFLICT (user_id, module_name) DO UPDATE SET has_access = true;
    
    RETURN QUERY SELECT 
      'Module Access Insert'::text,
      'PASS'::text,
      'Successfully inserted global_dashboard access'::text;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Module Access Insert'::text,
      'FAIL'::text,
      SQLERRM::text;
  END;
  
  -- Test 2: Check if we can update module access
  BEGIN
    UPDATE user_module_access 
    SET has_access = false 
    WHERE user_id = test_user_id AND module_name = 'global_dashboard';
    
    RETURN QUERY SELECT 
      'Module Access Update'::text,
      'PASS'::text,
      'Successfully updated global_dashboard access'::text;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Module Access Update'::text,
      'FAIL'::text,
      SQLERRM::text;
  END;
  
  -- Test 3: Check if we can delete module access
  BEGIN
    DELETE FROM user_module_access 
    WHERE user_id = test_user_id AND module_name = 'global_dashboard';
    
    RETURN QUERY SELECT 
      'Module Access Delete'::text,
      'PASS'::text,
      'Successfully deleted global_dashboard access'::text;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Module Access Delete'::text,
      'FAIL'::text,
      SQLERRM::text;
  END;
  
  RETURN;
END;
$$;

-- 6. Run the test
SELECT * FROM test_admin_permissions();

-- 7. Clean up the test function
DROP FUNCTION test_admin_permissions();
