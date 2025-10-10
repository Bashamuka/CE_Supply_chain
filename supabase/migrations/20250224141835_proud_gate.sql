-- Ajout des nouvelles colonnes avec vérification d'existence
DO $$ 
BEGIN
  -- Date CF
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'date_cf'
  ) THEN
    ALTER TABLE parts ADD COLUMN date_cf timestamp with time zone;
  END IF;

  -- Numéro de facture
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'invoice_number'
  ) THEN
    ALTER TABLE parts ADD COLUMN invoice_number text;
  END IF;

  -- Position actuelle
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'actual_position'
  ) THEN
    ALTER TABLE parts ADD COLUMN actual_position text;
  END IF;

  -- Nom de l'opérateur
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'operator_name'
  ) THEN
    ALTER TABLE parts ADD COLUMN operator_name text;
  END IF;

  -- PO Client
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'po_customer'
  ) THEN
    ALTER TABLE parts ADD COLUMN po_customer text;
  END IF;

  -- Commentaires
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'comments'
  ) THEN
    ALTER TABLE parts ADD COLUMN comments text;
  END IF;
END $$;