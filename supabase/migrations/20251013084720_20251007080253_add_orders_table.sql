/*
  # Create orders table

  1. New Tables
    - `orders`
      - `id` (uuid, primary key) - Unique identifier for each order
      - `constructeur` (text) - Constructor/Manufacturer name
      - `date_or` (date) - Order date
      - `num_or` (text) - Order number
      - `part_number` (text) - Part number reference
      - `qte_commandee` (decimal) - Quantity ordered
      - `qte_livree` (decimal) - Quantity delivered
      - `created_at` (timestamptz) - Record creation timestamp
      - `updated_at` (timestamptz) - Record update timestamp

  2. Security
    - Enable RLS on `orders` table
    - Add policy for authenticated users to read all orders
    - Add policy for authenticated users to insert orders
    - Add policy for authenticated users to update orders
    - Add policy for authenticated users to delete orders

  3. Indexes
    - Add index on `num_or` for faster order number lookups
    - Add index on `part_number` for faster part searches
    - Add index on `constructeur` for filtering by manufacturer
*/

CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  constructeur text NOT NULL,
  date_or date NOT NULL,
  num_or text NOT NULL,
  part_number text NOT NULL,
  qte_commandee decimal(10,2) NOT NULL DEFAULT 0,
  qte_livree decimal(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policies for authenticated users
DROP POLICY IF EXISTS "Authenticated users can view all orders" ON orders;
CREATE POLICY "Authenticated users can view all orders"
  ON orders FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert orders" ON orders;
CREATE POLICY "Authenticated users can insert orders"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can update orders" ON orders;
CREATE POLICY "Authenticated users can update orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can delete orders" ON orders;
CREATE POLICY "Authenticated users can delete orders"
  ON orders FOR DELETE
  TO authenticated
  USING (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_orders_num_or ON orders(num_or);
CREATE INDEX IF NOT EXISTS idx_orders_part_number ON orders(part_number);
CREATE INDEX IF NOT EXISTS idx_orders_constructeur ON orders(constructeur);
CREATE INDEX IF NOT EXISTS idx_orders_date_or ON orders(date_or);

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_orders_updated_at ON orders;
CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();