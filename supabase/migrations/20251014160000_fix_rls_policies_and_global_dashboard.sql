-- Fix RLS policies and add missing global_dashboard module
-- This migration fixes the incomplete UPDATE policy and adds global_dashboard to the constraint

-- First, drop the existing constraint
ALTER TABLE user_module_access DROP CONSTRAINT IF EXISTS user_module_access_module_name_check;

-- Add the new constraint with all modules including global_dashboard
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

-- Drop the incomplete UPDATE policy
DROP POLICY IF EXISTS "Admins can update module access" ON user_module_access;

-- Recreate the UPDATE policy with correct syntax
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
