/*
  # Create Projects Management Tables

  ## Overview
  This migration creates the database structure for the comprehensive project management module.
  It enables admins to create projects, manage machines, track parts, and analyze availability
  across multiple data sources (stock, orders, supplier commands).

  ## New Tables

  ### 1. `projects`
  Main project table storing high-level project information.
  - `id` (uuid, primary key) - Unique project identifier
  - `name` (text, required) - Project name (e.g., "Projet PCR MUMI")
  - `description` (text) - Detailed project description
  - `status` (text) - Project status: 'active', 'completed', 'on_hold'
  - `start_date` (date) - Planned project start date
  - `end_date` (date) - Planned project completion date
  - `created_by` (uuid, foreign key) - Admin who created the project
  - `created_at` (timestamptz) - Creation timestamp
  - `updated_at` (timestamptz) - Last update timestamp

  ### 2. `project_machines`
  Machines associated with each project.
  - `id` (uuid, primary key) - Unique machine identifier
  - `project_id` (uuid, foreign key) - Reference to parent project
  - `name` (text, required) - Machine name (e.g., "Machine 1", "Machine 2")
  - `description` (text) - Machine description
  - `start_date` (date) - Planned execution start date
  - `end_date` (date) - Planned execution end date
  - `order_number` (text) - Associated OR number for tracking
  - `created_at` (timestamptz) - Creation timestamp
  - `updated_at` (timestamptz) - Last update timestamp

  ### 3. `project_machine_parts`
  Parts required for each machine with quantities.
  - `id` (uuid, primary key) - Unique identifier
  - `machine_id` (uuid, foreign key) - Reference to machine
  - `part_number` (text, required) - Part reference number
  - `description` (text) - Part description
  - `quantity_required` (numeric) - Quantity needed for this machine
  - `created_at` (timestamptz) - Creation timestamp
  - `updated_at` (timestamptz) - Last update timestamp

  ### 4. `project_supplier_orders`
  Supplier orders associated with the project for transit tracking.
  - `id` (uuid, primary key) - Unique identifier
  - `project_id` (uuid, foreign key) - Reference to project
  - `supplier_order` (text, required) - Supplier order number
  - `description` (text) - Order description
  - `created_at` (timestamptz) - Creation timestamp
  - `updated_at` (timestamptz) - Last update timestamp

  ### 5. `project_branches`
  Branches (succursales) to check for stock availability.
  - `id` (uuid, primary key) - Unique identifier
  - `project_id` (uuid, foreign key) - Reference to project
  - `branch_code` (text, required) - Branch code (e.g., 'gdc', 'jdc', 'succ_10')
  - `created_at` (timestamptz) - Creation timestamp

  ## Security
  - All tables have RLS enabled
  - Admins can create, read, update, and delete all records
  - Employees and consultants can only read records
  - Each policy checks authentication and role-based permissions

  ## Important Notes
  1. Progressive data entry: All non-required fields allow NULL values
  2. Flexible associations: Machines can be added without all details
  3. Date format: Uses PostgreSQL date type for consistency
  4. Cascading deletes: Deleting a project removes all associated records
*/

-- Create projects table
CREATE TABLE IF NOT EXISTS projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  status text DEFAULT 'active',
  start_date date,
  end_date date,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_status CHECK (status IN ('active', 'completed', 'on_hold'))
);

-- Create project_machines table
CREATE TABLE IF NOT EXISTS project_machines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  start_date date,
  end_date date,
  order_number text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create project_machine_parts table
CREATE TABLE IF NOT EXISTS project_machine_parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_id uuid NOT NULL REFERENCES project_machines(id) ON DELETE CASCADE,
  part_number text NOT NULL,
  description text,
  quantity_required numeric DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create project_supplier_orders table
CREATE TABLE IF NOT EXISTS project_supplier_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  supplier_order text NOT NULL,
  description text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create project_branches table
CREATE TABLE IF NOT EXISTS project_branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  branch_code text NOT NULL,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT valid_branch_code CHECK (
    branch_code IN (
      'gdc', 'jdc', 'cat_network',
      'succ_10', 'succ_20', 'succ_11', 'succ_12', 'succ_13', 'succ_14',
      'succ_19', 'succ_21', 'succ_22', 'succ_24', 'succ_30', 'succ_40',
      'succ_50', 'succ_60', 'succ_70', 'succ_80', 'succ_90'
    )
  )
);

-- Enable RLS on all tables
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_machines ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_machine_parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_supplier_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_branches ENABLE ROW LEVEL SECURITY;

-- RLS Policies for projects table
CREATE POLICY "Admins can manage all projects"
  ON projects FOR ALL
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

CREATE POLICY "Users can view all projects"
  ON projects FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
    )
  );

-- RLS Policies for project_machines table
CREATE POLICY "Admins can manage all project machines"
  ON project_machines FOR ALL
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

CREATE POLICY "Users can view all project machines"
  ON project_machines FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
    )
  );

-- RLS Policies for project_machine_parts table
CREATE POLICY "Admins can manage all machine parts"
  ON project_machine_parts FOR ALL
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

CREATE POLICY "Users can view all machine parts"
  ON project_machine_parts FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
    )
  );

-- RLS Policies for project_supplier_orders table
CREATE POLICY "Admins can manage all supplier orders"
  ON project_supplier_orders FOR ALL
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

CREATE POLICY "Users can view all supplier orders"
  ON project_supplier_orders FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
    )
  );

-- RLS Policies for project_branches table
CREATE POLICY "Admins can manage all project branches"
  ON project_branches FOR ALL
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

CREATE POLICY "Users can view all project branches"
  ON project_branches FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
    )
  );

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_project_machines_project_id ON project_machines(project_id);
CREATE INDEX IF NOT EXISTS idx_project_machine_parts_machine_id ON project_machine_parts(machine_id);
CREATE INDEX IF NOT EXISTS idx_project_machine_parts_part_number ON project_machine_parts(part_number);
CREATE INDEX IF NOT EXISTS idx_project_supplier_orders_project_id ON project_supplier_orders(project_id);
CREATE INDEX IF NOT EXISTS idx_project_supplier_orders_supplier_order ON project_supplier_orders(supplier_order);
CREATE INDEX IF NOT EXISTS idx_project_branches_project_id ON project_branches(project_id);

-- Create updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_project_machines_updated_at
  BEFORE UPDATE ON project_machines
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_project_machine_parts_updated_at
  BEFORE UPDATE ON project_machine_parts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();