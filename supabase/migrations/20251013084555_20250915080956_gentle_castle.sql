/*
  # Create stock_dispo table

  1. New Tables
    - `stock_dispo`
      - `id` (bigint, primary key, auto-increment)
      - `part_number` (text, required)
      - `description` (text)
      - `qté_GDC` (real) - Quantity at GDC
      - `qté_JDC` (real) - Quantity at JDC
      - `qté_CAT_Network` (real) - Quantity in CAT Network
      - `qté_SUCC_10` through `qté_SUCC_90` (real) - Quantities at various branches

  2. Security
    - Enable RLS on `stock_dispo` table
    - Add policies for authenticated users to read data
    - Add policies for admin users to insert/update data
*/

CREATE TABLE IF NOT EXISTS stock_dispo (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  part_number text NOT NULL,
  description text,
  qté_GDC real DEFAULT 0,
  qté_JDC real DEFAULT 0,
  qté_CAT_Network real DEFAULT 0,
  qté_SUCC_10 real DEFAULT 0,
  qté_SUCC_20 real DEFAULT 0,
  qté_SUCC_11 real DEFAULT 0,
  qté_SUCC_12 real DEFAULT 0,
  qté_SUCC_13 real DEFAULT 0,
  qté_SUCC_14 real DEFAULT 0,
  qté_SUCC_19 real DEFAULT 0,
  qté_SUCC_21 real DEFAULT 0,
  qté_SUCC_22 real DEFAULT 0,
  qté_SUCC_24 real DEFAULT 0,
  qté_SUCC_30 real DEFAULT 0,
  qté_SUCC_40 real DEFAULT 0,
  qté_SUCC_50 real DEFAULT 0,
  qté_SUCC_60 real DEFAULT 0,
  qté_SUCC_70 real DEFAULT 0,
  qté_SUCC_80 real DEFAULT 0,
  qté_SUCC_90 real DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE stock_dispo ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow read access to authenticated users" ON stock_dispo;
CREATE POLICY "Allow read access to authenticated users"
  ON stock_dispo
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow insert access to admin users" ON stock_dispo;
CREATE POLICY "Allow insert access to admin users"
  ON stock_dispo
  FOR INSERT
  TO authenticated
  WITH CHECK (is_admin(auth.uid()));

DROP POLICY IF EXISTS "Allow update access to admin users" ON stock_dispo;
CREATE POLICY "Allow update access to admin users"
  ON stock_dispo
  FOR UPDATE
  TO authenticated
  USING (is_admin(auth.uid()))
  WITH CHECK (is_admin(auth.uid()));

DROP POLICY IF EXISTS "Allow delete access to admin users" ON stock_dispo;
CREATE POLICY "Allow delete access to admin users"
  ON stock_dispo
  FOR DELETE
  TO authenticated
  USING (is_admin(auth.uid()));

CREATE INDEX IF NOT EXISTS idx_stock_dispo_part_number ON stock_dispo(part_number);
CREATE INDEX IF NOT EXISTS idx_stock_dispo_description ON stock_dispo(description);