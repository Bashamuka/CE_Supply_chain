-- Complete fix for admin permissions system
-- This migration addresses all identified issues

-- 1. First, let's ensure the tables exist with correct structure
DO $$
BEGIN
    -- Check if user_module_access table exists and has correct structure
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_module_access') THEN
        CREATE TABLE user_module_access (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
            module_name text NOT NULL,
            has_access boolean NOT NULL DEFAULT false,
            created_at timestamptz DEFAULT now(),
            updated_at timestamptz DEFAULT now(),
            UNIQUE(user_id, module_name)
        );
        RAISE NOTICE 'Created user_module_access table';
    ELSE
        RAISE NOTICE 'user_module_access table already exists';
    END IF;

    -- Check if user_project_access table exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_project_access') THEN
        CREATE TABLE user_project_access (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
            project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            created_at timestamptz DEFAULT now(),
            UNIQUE(user_id, project_id)
        );
        RAISE NOTICE 'Created user_project_access table';
    ELSE
        RAISE NOTICE 'user_project_access table already exists';
    END IF;
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

-- 3. Enable RLS if not already enabled
ALTER TABLE user_module_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_project_access ENABLE ROW LEVEL SECURITY;

-- 4. Drop all existing policies and recreate them properly
DROP POLICY IF EXISTS "Users can view their own module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can view all module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can insert module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can update module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can delete module access" ON user_module_access;

DROP POLICY IF EXISTS "Users can view their own project access" ON user_project_access;
DROP POLICY IF EXISTS "Admins can view all project access" ON user_project_access;
DROP POLICY IF EXISTS "Admins can insert project access" ON user_project_access;
DROP POLICY IF EXISTS "Admins can delete project access" ON user_project_access;

-- 5. Recreate all policies with proper syntax
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

-- Project access policies
CREATE POLICY "Users can view their own project access"
  ON user_project_access FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all project access"
  ON user_project_access FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can insert project access"
  ON user_project_access FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can delete project access"
  ON user_project_access FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- 6. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_module_access_user_id ON user_module_access(user_id);
CREATE INDEX IF NOT EXISTS idx_user_module_access_module ON user_module_access(module_name);
CREATE INDEX IF NOT EXISTS idx_user_project_access_user_id ON user_project_access(user_id);
CREATE INDEX IF NOT EXISTS idx_user_project_access_project_id ON user_project_access(project_id);

-- 7. Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_module_access_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS update_user_module_access_updated_at_trigger ON user_module_access;
CREATE TRIGGER update_user_module_access_updated_at_trigger
  BEFORE UPDATE ON user_module_access
  FOR EACH ROW
  EXECUTE FUNCTION update_user_module_access_updated_at();

-- 8. Create helper function to check module access
CREATE OR REPLACE FUNCTION check_user_module_access(
  p_user_id uuid,
  p_module_name text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin boolean;
  v_has_access boolean;
BEGIN
  -- Check if user is admin
  SELECT (role = 'admin') INTO v_is_admin
  FROM profiles
  WHERE id = p_user_id;
  
  -- Admins have access to all modules
  IF v_is_admin THEN
    RETURN true;
  END IF;
  
  -- Check module access
  SELECT has_access INTO v_has_access
  FROM user_module_access
  WHERE user_id = p_user_id
    AND module_name = p_module_name;
  
  RETURN COALESCE(v_has_access, false);
END;
$$;

-- 9. Create helper function to check project access
CREATE OR REPLACE FUNCTION check_user_project_access(
  p_user_id uuid,
  p_project_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin boolean;
  v_has_access boolean;
BEGIN
  -- Check if user is admin
  SELECT (role = 'admin') INTO v_is_admin
  FROM profiles
  WHERE id = p_user_id;
  
  -- Admins have access to all projects
  IF v_is_admin THEN
    RETURN true;
  END IF;
  
  -- Check project access
  SELECT EXISTS(
    SELECT 1
    FROM user_project_access
    WHERE user_id = p_user_id
      AND project_id = p_project_id
  ) INTO v_has_access;
  
  RETURN v_has_access;
END;
$$;

-- 10. Test the setup
DO $$
DECLARE
  admin_user_id uuid;
  test_user_id uuid;
  test_result boolean;
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
  
  IF admin_user_id IS NOT NULL AND test_user_id IS NOT NULL THEN
    -- Test inserting module access
    BEGIN
      INSERT INTO user_module_access (user_id, module_name, has_access)
      VALUES (test_user_id, 'global_dashboard', true)
      ON CONFLICT (user_id, module_name) DO UPDATE SET has_access = true;
      
      RAISE NOTICE '✅ Module access insert test PASSED';
      
      -- Test updating module access
      UPDATE user_module_access 
      SET has_access = false 
      WHERE user_id = test_user_id AND module_name = 'global_dashboard';
      
      RAISE NOTICE '✅ Module access update test PASSED';
      
      -- Test deleting module access
      DELETE FROM user_module_access 
      WHERE user_id = test_user_id AND module_name = 'global_dashboard';
      
      RAISE NOTICE '✅ Module access delete test PASSED';
      
      -- Test the helper function
      SELECT check_user_module_access(test_user_id, 'global_dashboard') INTO test_result;
      RAISE NOTICE '✅ Helper function test PASSED, result: %', test_result;
      
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '❌ Test FAILED: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE '⚠️  No users found for testing';
  END IF;
END;
$$;
