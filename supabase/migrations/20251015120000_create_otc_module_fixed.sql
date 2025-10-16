/*
  # Create OTC (Order Tracking & Control) Module
  
  ## Module Description
  OTC module for tracking orders with comprehensive order management functionality.
  Similar to Orders Movement Tracking but with specific OTC fields.
  
  ## Table Structure
  - SUCCURSALE: Branch/location identifier
  - OPERATEUR: Operator name
  - DATE CDE: Order date
  - Num CDE: Order number
  - PO CLIENT: Customer purchase order
  - REFERENCE: Part reference
  - DESIGNATION: Part description
  - QTE CDE: Ordered quantity
  - QTE LIVREE: Delivered quantity
  - SOLDE: Balance/remaining quantity
  - DATE BL: Delivery note date
  - NUM BL: Delivery note number
  - STATUS: Order status
  - NUM CLIENT: Customer number
  - NOM CLIENTS: Customer name
*/

-- Create OTC table
CREATE TABLE IF NOT EXISTS otc_orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  succursale TEXT NOT NULL,
  operateur TEXT NOT NULL,
  date_cde DATE NOT NULL,
  num_cde TEXT NOT NULL,
  po_client TEXT,
  reference TEXT NOT NULL,
  designation TEXT NOT NULL,
  qte_cde DECIMAL(10,2) NOT NULL DEFAULT 0,
  qte_livree DECIMAL(10,2) NOT NULL DEFAULT 0,
  solde DECIMAL(10,2) GENERATED ALWAYS AS (qte_cde - qte_livree) STORED,
  date_bl DATE,
  num_bl TEXT,
  status TEXT NOT NULL DEFAULT 'Pending',
  num_client TEXT,
  nom_clients TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_otc_succursale ON otc_orders(succursale);
CREATE INDEX IF NOT EXISTS idx_otc_operateur ON otc_orders(operateur);
CREATE INDEX IF NOT EXISTS idx_otc_date_cde ON otc_orders(date_cde);
CREATE INDEX IF NOT EXISTS idx_otc_num_cde ON otc_orders(num_cde);
CREATE INDEX IF NOT EXISTS idx_otc_po_client ON otc_orders(po_client);
CREATE INDEX IF NOT EXISTS idx_otc_reference ON otc_orders(reference);
CREATE INDEX IF NOT EXISTS idx_otc_status ON otc_orders(status);
CREATE INDEX IF NOT EXISTS idx_otc_num_client ON otc_orders(num_client);
CREATE INDEX IF NOT EXISTS idx_otc_date_bl ON otc_orders(date_bl);
CREATE INDEX IF NOT EXISTS idx_otc_num_bl ON otc_orders(num_bl);

-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_otc_succursale_date ON otc_orders(succursale, date_cde);
CREATE INDEX IF NOT EXISTS idx_otc_status_date ON otc_orders(status, date_cde);
CREATE INDEX IF NOT EXISTS idx_otc_client_status ON otc_orders(num_client, status);

-- Create unique constraint on order number per branch
CREATE UNIQUE INDEX IF NOT EXISTS idx_otc_unique_order ON otc_orders(succursale, num_cde);

-- Enable Row Level Security
ALTER TABLE otc_orders ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Policy for authenticated users to read OTC data
CREATE POLICY "Users can read OTC orders" ON otc_orders
  FOR SELECT USING (auth.role() = 'authenticated');

-- Policy for authenticated users to insert OTC data
CREATE POLICY "Users can insert OTC orders" ON otc_orders
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Policy for authenticated users to update OTC data
CREATE POLICY "Users can update OTC orders" ON otc_orders
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Policy for authenticated users to delete OTC data
CREATE POLICY "Users can delete OTC orders" ON otc_orders
  FOR DELETE USING (auth.role() = 'authenticated');

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_otc_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER trigger_update_otc_updated_at
  BEFORE UPDATE ON otc_orders
  FOR EACH ROW
  EXECUTE FUNCTION update_otc_updated_at();

-- Create function to validate solde calculation
CREATE OR REPLACE FUNCTION validate_otc_solde()
RETURNS TRIGGER AS $$
BEGIN
  -- Ensure solde is not negative
  IF NEW.qte_livree > NEW.qte_cde THEN
    RAISE EXCEPTION 'Delivered quantity (qte_livree) cannot exceed ordered quantity (qte_cde)';
  END IF;
  
  -- Update solde if quantities change
  NEW.solde = NEW.qte_cde - NEW.qte_livree;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to validate solde
CREATE TRIGGER trigger_validate_otc_solde
  BEFORE INSERT OR UPDATE ON otc_orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_otc_solde();

-- Create view for OTC analytics
CREATE OR REPLACE VIEW v_otc_analytics AS
SELECT 
  succursale,
  COUNT(*) as total_orders,
  COUNT(CASE WHEN status = 'Delivered' THEN 1 END) as delivered_orders,
  COUNT(CASE WHEN status = 'Pending' THEN 1 END) as pending_orders,
  COUNT(CASE WHEN status = 'In Progress' THEN 1 END) as in_progress_orders,
  COUNT(CASE WHEN status = 'Cancelled' THEN 1 END) as cancelled_orders,
  SUM(qte_cde) as total_ordered_quantity,
  SUM(qte_livree) as total_delivered_quantity,
  SUM(solde) as total_balance,
  ROUND(
    CASE 
      WHEN SUM(qte_cde) > 0 THEN (SUM(qte_livree) * 100.0 / SUM(qte_cde))
      ELSE 0
    END, 2
  ) as delivery_percentage,
  MIN(date_cde) as earliest_order_date,
  MAX(date_cde) as latest_order_date
FROM otc_orders
GROUP BY succursale;

-- Create view for customer analytics
CREATE OR REPLACE VIEW v_otc_customer_analytics AS
SELECT 
  num_client,
  nom_clients,
  COUNT(*) as total_orders,
  COUNT(CASE WHEN status = 'Delivered' THEN 1 END) as delivered_orders,
  SUM(qte_cde) as total_ordered_quantity,
  SUM(qte_livree) as total_delivered_quantity,
  SUM(solde) as total_balance,
  ROUND(
    CASE 
      WHEN SUM(qte_cde) > 0 THEN (SUM(qte_livree) * 100.0 / SUM(qte_cde))
      ELSE 0
    END, 2
  ) as delivery_percentage,
  MIN(date_cde) as first_order_date,
  MAX(date_cde) as last_order_date
FROM otc_orders
WHERE num_client IS NOT NULL
GROUP BY num_client, nom_clients;

-- Create view for status tracking
CREATE OR REPLACE VIEW v_otc_status_tracking AS
SELECT 
  status,
  COUNT(*) as order_count,
  SUM(qte_cde) as total_ordered_quantity,
  SUM(qte_livree) as total_delivered_quantity,
  SUM(solde) as total_balance,
  AVG(qte_cde) as avg_order_quantity,
  MIN(date_cde) as earliest_order_date,
  MAX(date_cde) as latest_order_date
FROM otc_orders
GROUP BY status;

-- Insert sample data for testing
INSERT INTO otc_orders (
  succursale, operateur, date_cde, num_cde, po_client, reference, 
  designation, qte_cde, qte_livree, date_bl, num_bl, status, 
  num_client, nom_clients
) VALUES 
(
  'GDC', 'Jean Dupont', '2025-01-15', 'OTC-001', 'PO-2025-001', '1357935',
  'SEAL-O-RING', 20, 15, '2025-01-20', 'BL-001', 'Delivered',
  'CLI-001', 'Congo Equipment Kinshasa'
),
(
  'JDC', 'Marie Martin', '2025-01-16', 'OTC-002', 'PO-2025-002', '3518955',
  'SEAL-O-RING', 10, 0, NULL, NULL, 'Pending',
  'CLI-002', 'Mining Corp Lubumbashi'
),
(
  'GDC', 'Pierre Durand', '2025-01-17', 'OTC-003', 'PO-2025-003', '4512763',
  'SEAL-FLAT FA', 5, 5, '2025-01-18', 'BL-002', 'Delivered',
  'CLI-003', 'Construction Ltd'
),
(
  'JDC', 'Sophie Leroy', '2025-01-18', 'OTC-004', 'PO-2025-004', '5W1705',
  'WASHER-SEAL', 8, 3, '2025-01-19', 'BL-003', 'In Progress',
  'CLI-004', 'Industrial Solutions'
),
(
  'GDC', 'Marc Petit', '2025-01-19', 'OTC-005', 'PO-2025-005', '4512764',
  'SEAL-FLAT FA', 12, 0, NULL, NULL, 'Pending',
  'CLI-005', 'Equipment Services'
);

-- Create function to refresh OTC analytics
CREATE OR REPLACE FUNCTION refresh_otc_analytics()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Note: We're using regular views, not materialized views, so no refresh needed
  -- The views will automatically reflect current data
  
  RAISE NOTICE 'OTC analytics refreshed successfully';
END;
$$;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON otc_orders TO authenticated;
GRANT SELECT ON v_otc_analytics TO authenticated;
GRANT SELECT ON v_otc_customer_analytics TO authenticated;
GRANT SELECT ON v_otc_status_tracking TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_otc_analytics() TO authenticated;

-- Final verification
DO $$
DECLARE
  table_count INTEGER;
  sample_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO table_count FROM information_schema.tables WHERE table_name = 'otc_orders';
  SELECT COUNT(*) INTO sample_count FROM otc_orders;
  
  RAISE NOTICE 'OTC module created successfully';
  RAISE NOTICE 'Table exists: %', CASE WHEN table_count > 0 THEN 'YES' ELSE 'NO' END;
  RAISE NOTICE 'Sample records inserted: %', sample_count;
  RAISE NOTICE 'Use SELECT * FROM otc_orders to view sample data';
  RAISE NOTICE 'Use SELECT * FROM v_otc_analytics to view analytics';
END $$;
