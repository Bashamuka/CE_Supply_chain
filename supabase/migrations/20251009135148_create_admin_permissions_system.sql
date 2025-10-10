/*
  # Create Admin Permissions System

  ## Purpose
  This migration creates a comprehensive permissions system allowing administrators to:
  - Manage user accounts
  - Assign modules to users
  - Assign specific projects to users

  ## New Tables

  1. **user_module_access**
     - `id` (uuid, primary key)
     - `user_id` (uuid, references profiles) - User receiving access
     - `module_name` (text) - Name of the module
     - `has_access` (boolean) - Whether user has access
     - `created_at`, `updated_at` (timestamptz)

  2. **user_project_access**
     - `id` (uuid, primary key)
     - `user_id` (uuid, references profiles) - User receiving access
     - `project_id` (uuid, references projects) - Project user can access
     - `created_at` (timestamptz)

  ## Module Names
  - 'eta_tracking' - ETA Tracking
  - 'stock_availability' - Stock Availability
  - 'parts_equivalence' - Parts Equivalence
  - 'orders' - Orders Management
  - 'projects' - Projects Management
  - 'dealer_forward_planning' - Dealer Forward Planning

  ## Security
  - Enable RLS on all tables
  - Only admins can manage permissions
  - Users can view their own permissions

  ## Important Notes
  - Admins have access to all modules by default (enforced in application)
  - If a user has no user_module_access record for a module, access is denied
  - For projects module, additional user_project_access check is required
*/

-- Create user_module_access table
CREATE TABLE IF NOT EXISTS user_module_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  module_name text NOT NULL CHECK (
    module_name IN (
      'eta_tracking',
      'stock_availability',
      'parts_equivalence',
      'orders',
      'projects',
      'dealer_forward_planning'
    )
  ),
  has_access boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, module_name)
);

-- Create user_project_access table
CREATE TABLE IF NOT EXISTS user_project_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, project_id)
);

-- Enable RLS
ALTER TABLE user_module_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_project_access ENABLE ROW LEVEL SECURITY;

-- Policies for user_module_access

-- Users can view their own module access
CREATE POLICY "Users can view their own module access"
  ON user_module_access FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Admins can view all module access
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

-- Admins can insert module access
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

-- Admins can update module access
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

-- Admins can delete module access
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

-- Policies for user_project_access

-- Users can view their own project access
CREATE POLICY "Users can view their own project access"
  ON user_project_access FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Admins can view all project access
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

-- Admins can insert project access
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

-- Admins can delete project access
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

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_module_access_user_id ON user_module_access(user_id);
CREATE INDEX IF NOT EXISTS idx_user_module_access_module ON user_module_access(module_name);
CREATE INDEX IF NOT EXISTS idx_user_project_access_user_id ON user_project_access(user_id);
CREATE INDEX IF NOT EXISTS idx_user_project_access_project_id ON user_project_access(project_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_module_access_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER update_user_module_access_updated_at_trigger
  BEFORE UPDATE ON user_module_access
  FOR EACH ROW
  EXECUTE FUNCTION update_user_module_access_updated_at();

-- Create helper function to check module access
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

-- Create helper function to check project access
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