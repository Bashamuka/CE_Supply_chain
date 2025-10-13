/*
  # Add RLS policies to parts table

  1. Security
    - Add policies for read/write access
    - Ensure only admins can insert/update records
    - Allow all authenticated users to read records
*/

-- Policies
DROP POLICY IF EXISTS "Allow read access to authenticated users" ON parts;
CREATE POLICY "Allow read access to authenticated users"
  ON parts
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow insert access to admin users" ON parts;
CREATE POLICY "Allow insert access to admin users"
  ON parts
  FOR INSERT
  TO authenticated
  WITH CHECK (is_admin(auth.uid()));

DROP POLICY IF EXISTS "Allow update access to admin users" ON parts;
CREATE POLICY "Allow update access to admin users"
  ON parts
  FOR UPDATE
  TO authenticated
  USING (is_admin(auth.uid()))
  WITH CHECK (is_admin(auth.uid()));