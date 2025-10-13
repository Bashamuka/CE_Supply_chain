/*
  # Add Triggers to All Tables Affecting Analytics

  1. Changes
    - Add triggers on project_machine_order_numbers (when ORs are added/deleted)
    - Add triggers on project_machines (when machines are added/deleted)
    - Add triggers on orders table (when order data changes)
    - Ensure all data changes refresh the analytics views

  2. Notes
    - These triggers ensure real-time analytics updates
    - Covers all user actions that affect project analytics
*/

-- Create trigger on project_machine_order_numbers
DROP TRIGGER IF EXISTS trigger_refresh_views_on_order_numbers_update ON project_machine_order_numbers;

CREATE TRIGGER trigger_refresh_views_on_order_numbers_update
AFTER INSERT OR UPDATE OR DELETE ON project_machine_order_numbers
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_views_on_machine_parts_change();

-- Create trigger on project_machines
DROP TRIGGER IF EXISTS trigger_refresh_views_on_machines_update ON project_machines;

CREATE TRIGGER trigger_refresh_views_on_machines_update
AFTER INSERT OR UPDATE OR DELETE ON project_machines
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_views_on_machine_parts_change();

-- Create trigger on orders (if it affects analytics)
DROP TRIGGER IF EXISTS trigger_refresh_views_on_orders_update ON orders;

CREATE TRIGGER trigger_refresh_views_on_orders_update
AFTER INSERT OR UPDATE OR DELETE ON orders
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_views_on_parts_change();
