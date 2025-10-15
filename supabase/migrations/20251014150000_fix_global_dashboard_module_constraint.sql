-- Fix missing global_dashboard module in user_module_access constraint
-- This migration adds the missing 'global_dashboard' module to the CHECK constraint

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
