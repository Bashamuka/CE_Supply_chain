-- Migration: Create project_bl_numbers table
-- This table stores BL (Bon de Livraison) numbers for each project
-- Used for OTC-based calculation method

-- Create the table
CREATE TABLE IF NOT EXISTS project_bl_numbers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  bl_number VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_project_bl_numbers_project_id ON project_bl_numbers(project_id);
CREATE INDEX IF NOT EXISTS idx_project_bl_numbers_bl_number ON project_bl_numbers(bl_number);

-- Create unique constraint to prevent duplicate BL numbers per project
CREATE UNIQUE INDEX IF NOT EXISTS idx_project_bl_numbers_unique ON project_bl_numbers(project_id, bl_number);

-- Add RLS (Row Level Security) policies
ALTER TABLE project_bl_numbers ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view BL numbers for projects they have access to
CREATE POLICY "Users can view BL numbers for accessible projects" ON project_bl_numbers
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM projects p
      WHERE p.id = project_bl_numbers.project_id
      AND (
        p.created_by = auth.uid()
        OR EXISTS (
          SELECT 1 FROM user_project_access upa
          WHERE upa.project_id = p.id
          AND upa.user_id = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM profiles pr
          WHERE pr.id = auth.uid()
          AND pr.role = 'admin'
        )
      )
    )
  );

-- Policy: Only admins can insert BL numbers
CREATE POLICY "Only admins can insert BL numbers" ON project_bl_numbers
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );

-- Policy: Only admins can update BL numbers
CREATE POLICY "Only admins can update BL numbers" ON project_bl_numbers
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );

-- Policy: Only admins can delete BL numbers
CREATE POLICY "Only admins can delete BL numbers" ON project_bl_numbers
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_project_bl_numbers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_project_bl_numbers_updated_at
  BEFORE UPDATE ON project_bl_numbers
  FOR EACH ROW
  EXECUTE FUNCTION update_project_bl_numbers_updated_at();

-- Add comment to the table
COMMENT ON TABLE project_bl_numbers IS 'Stores BL (Bon de Livraison) numbers for each project, used for OTC-based calculation method';
COMMENT ON COLUMN project_bl_numbers.bl_number IS 'The BL number (Bon de Livraison number)';
COMMENT ON COLUMN project_bl_numbers.description IS 'Optional description for the BL number';
