/*
  # Add Machine Order Numbers Table

  ## Overview
  This migration creates a new table to allow multiple OR numbers per machine.
  It replaces the single `order_number` field in `project_machines` with a 
  many-to-many relationship.

  ## Changes

  ### 1. New Table: `project_machine_order_numbers`
  Links machines to multiple OR numbers.
  - `id` (uuid, primary key) - Unique identifier
  - `machine_id` (uuid, foreign key) - Reference to machine
  - `order_number` (text, required) - OR number
  - `created_at` (timestamptz) - Creation timestamp

  ### 2. Migration Strategy
  - Create new table first
  - Migrate existing order_number data from project_machines
  - Remove old order_number column from project_machines

  ## Security
  - RLS enabled with same permissions as project_machines
  - Admins can manage, all users can view

  ## Important Notes
  - Each machine can now have multiple OR numbers
  - Historical data is preserved during migration
  - Cascading deletes ensure data consistency
*/

-- Create new table for machine order numbers
CREATE TABLE IF NOT EXISTS project_machine_order_numbers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_id uuid NOT NULL REFERENCES project_machines(id) ON DELETE CASCADE,
  order_number text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Migrate existing order_number data from project_machines (only if column exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'project_machines' AND column_name = 'order_number'
  ) THEN
    INSERT INTO project_machine_order_numbers (machine_id, order_number)
    SELECT id, order_number
    FROM project_machines
    WHERE order_number IS NOT NULL AND order_number != '';
    
    -- Remove old order_number column
    ALTER TABLE project_machines DROP COLUMN order_number;
  END IF;
END $$;

-- Enable RLS
ALTER TABLE project_machine_order_numbers ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Admins can manage all machine order numbers" ON project_machine_order_numbers;
CREATE POLICY "Admins can manage all machine order numbers"
  ON project_machine_order_numbers FOR ALL
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

DROP POLICY IF EXISTS "Users can view all machine order numbers" ON project_machine_order_numbers;
CREATE POLICY "Users can view all machine order numbers"
  ON project_machine_order_numbers FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
    )
  );

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_machine_order_numbers_machine_id 
  ON project_machine_order_numbers(machine_id);

CREATE INDEX IF NOT EXISTS idx_machine_order_numbers_order_number 
  ON project_machine_order_numbers(order_number);