/*
  # Add full-text search capabilities to parts table

  1. Changes
    - Add tsvector column for search_vector
    - Create function for generating search vectors
    - Add trigger to maintain search vectors
    - Create GIN index for efficient searching

  2. Functions
    - parts_search_vector(): Generates search vector from part fields
    - parts_search_vector_trigger(): Trigger function to update search vector
*/

-- Create parts table if it doesn't exist (idempotent)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'parts'
  ) THEN
    CREATE TABLE parts (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      client_number text,
      client_name text,
      po_reference text,
      order_number text UNIQUE NOT NULL,
      branch text,
      cf_number text,
      order_reference text,
      equivalents text,
      description text,
      quantity_ordered integer,
      backorder integer,
      billing text,
      delivery text,
      available_stock integer,
      dealer_net_usd numeric(10,2),
      order_date timestamp with time zone,
      billing_date timestamp with time zone,
      update_date timestamp with time zone,
      carrier text,
      current_position text,
      eta_ce timestamp with time zone,
      reception_date timestamp with time zone,
      receptionist text,
      cat_ticket_id text,
      ticket_status text,
      cat_line_status text,
      flag text,
      cd_lta text,
      ship_by_date timestamp with time zone,
      store_comments text,
      created_at timestamp with time zone DEFAULT now(),
      updated_at timestamp with time zone DEFAULT now()
    );
  END IF;
END $$;

-- Add tsvector column for full-text search if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'parts' 
    AND column_name = 'search_vector'
  ) THEN
    ALTER TABLE parts ADD COLUMN search_vector tsvector;
  END IF;
END $$;

-- Create function to generate search vector
CREATE OR REPLACE FUNCTION parts_search_vector(
  description text,
  client_name text,
  order_number text,
  po_reference text,
  cf_number text,
  cat_ticket_id text
) RETURNS tsvector AS $$
BEGIN
  RETURN (
    setweight(to_tsvector('french', COALESCE(description, '')), 'A') ||
    setweight(to_tsvector('french', COALESCE(client_name, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(order_number, '')), 'A') ||
    setweight(to_tsvector('simple', COALESCE(po_reference, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(cf_number, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(cat_ticket_id, '')), 'B')
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create trigger to keep search_vector up to date
CREATE OR REPLACE FUNCTION parts_search_vector_trigger() RETURNS trigger AS $$
BEGIN
  NEW.search_vector := parts_search_vector(
    NEW.description,
    NEW.client_name,
    NEW.order_number,
    NEW.po_reference,
    NEW.cf_number,
    NEW.cat_ticket_id
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if it exists to avoid conflicts
DROP TRIGGER IF EXISTS parts_vector_update ON parts;

-- Create trigger
CREATE TRIGGER parts_vector_update
  BEFORE INSERT OR UPDATE ON parts
  FOR EACH ROW
  EXECUTE FUNCTION parts_search_vector_trigger();

-- Create GIN index if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' 
    AND tablename = 'parts' 
    AND indexname = 'parts_search_idx'
  ) THEN
    CREATE INDEX parts_search_idx ON parts USING GIN (search_vector);
  END IF;
END $$;

-- Update existing rows
UPDATE parts SET search_vector = parts_search_vector(
  description,
  client_name,
  order_number,
  po_reference,
  cf_number,
  cat_ticket_id
);