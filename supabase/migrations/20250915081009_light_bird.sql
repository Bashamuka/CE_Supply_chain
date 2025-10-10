/*
  # Create parts_equivalence table

  1. New Tables
    - `parts_equivalence`
      - `id` (bigint, primary key, auto-increment)
      - `part_number` (text, required)
      - `description` (text)
      - `equivalence_part` (text, required)
      - `description_eq` (text)

  2. Security
    - Enable RLS on `parts_equivalence` table
    - Add policies for authenticated users to read data
    - Add policies for admin users to insert/update data
*/

CREATE TABLE IF NOT EXISTS parts_equivalence (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  part_number text NOT NULL,
  description text,
  equivalence_part text NOT NULL,
  description_eq text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE parts_equivalence ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read access to authenticated users"
  ON parts_equivalence
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow insert access to admin users"
  ON parts_equivalence
  FOR INSERT
  TO authenticated
  WITH CHECK (is_admin(auth.uid()));

CREATE POLICY "Allow update access to admin users"
  ON parts_equivalence
  FOR UPDATE
  TO authenticated
  USING (is_admin(auth.uid()))
  WITH CHECK (is_admin(auth.uid()));

CREATE POLICY "Allow delete access to admin users"
  ON parts_equivalence
  FOR DELETE
  TO authenticated
  USING (is_admin(auth.uid()));

CREATE INDEX IF NOT EXISTS idx_parts_equivalence_part_number ON parts_equivalence(part_number);
CREATE INDEX IF NOT EXISTS idx_parts_equivalence_equivalence_part ON parts_equivalence(equivalence_part);
CREATE INDEX IF NOT EXISTS idx_parts_equivalence_description ON parts_equivalence(description);