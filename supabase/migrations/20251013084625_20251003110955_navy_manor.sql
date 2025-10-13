/*
  # Ajout de nouvelles colonnes à la table parts

  1. Nouvelles colonnes
    - `order_type` (text) - Type d'ordre
    - `cat_ticket_id` (text) - Id Ticket chez CAT
    - `ticket_status` (text) - Statut du Ticket
    - `ship_by_date` (text) - Ship by Date au format DD/MM/YYYY
    - `customer_name` (text) - Customer Name

  2. Validation
    - Ajout de contrainte de validation pour ship_by_date (format français DD/MM/YYYY)
    - Mise à jour du trigger de validation des dates
*/

-- Ajouter les nouvelles colonnes à la table parts
DO $$
BEGIN
  -- Type d'ordre
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'parts' AND column_name = 'order_type'
  ) THEN
    ALTER TABLE parts ADD COLUMN order_type text;
  END IF;

  -- Id Ticket chez CAT
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'parts' AND column_name = 'cat_ticket_id'
  ) THEN
    ALTER TABLE parts ADD COLUMN cat_ticket_id text;
  END IF;

  -- Statut du Ticket
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'parts' AND column_name = 'ticket_status'
  ) THEN
    ALTER TABLE parts ADD COLUMN ticket_status text;
  END IF;

  -- Ship by Date
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'parts' AND column_name = 'ship_by_date'
  ) THEN
    ALTER TABLE parts ADD COLUMN ship_by_date text;
  END IF;

  -- Customer Name
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'parts' AND column_name = 'customer_name'
  ) THEN
    ALTER TABLE parts ADD COLUMN customer_name text;
  END IF;
END $$;

-- Ajouter une contrainte de validation pour ship_by_date (format français DD/MM/YYYY)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'ship_by_date_format_check'
  ) THEN
    ALTER TABLE parts ADD CONSTRAINT ship_by_date_format_check 
    CHECK ((ship_by_date IS NULL) OR is_valid_french_date(ship_by_date));
  END IF;
END $$;