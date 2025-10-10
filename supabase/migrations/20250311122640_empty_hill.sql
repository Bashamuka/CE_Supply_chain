/*
  # Update date formats for ETA and Date CF columns

  1. Changes
    - Modify `eta` and `date_cf` columns to store dates in French format (DD/MM/YYYY)
    - Add validation functions and triggers
    - Convert existing data safely
  
  2. Validation
    - Add check constraints for French date format
    - Create validation functions for date format checking
    - Implement triggers for automatic validation
*/

-- Create function to validate French date format (DD/MM/YYYY)
CREATE OR REPLACE FUNCTION is_valid_french_date(date_str text)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check basic format (DD/MM/YYYY)
  IF date_str !~ '^\d{2}/\d{2}/\d{4}$' THEN
    RETURN FALSE;
  END IF;

  -- Extract day, month, year
  DECLARE
    day int := CAST(SPLIT_PART(date_str, '/', 1) AS INTEGER);
    month int := CAST(SPLIT_PART(date_str, '/', 2) AS INTEGER);
    year int := CAST(SPLIT_PART(date_str, '/', 3) AS INTEGER);
  BEGIN
    -- Validate date components
    IF year < 1900 OR year > 2100 THEN
      RETURN FALSE;
    END IF;
    IF month < 1 OR month > 12 THEN
      RETURN FALSE;
    END IF;
    IF day < 1 OR day > 31 THEN
      RETURN FALSE;
    END IF;
    
    -- Check specific month lengths
    IF (month IN (4, 6, 9, 11) AND day > 30) THEN
      RETURN FALSE;
    END IF;
    
    -- February special cases
    IF month = 2 THEN
      -- Leap year check
      IF (year % 4 = 0 AND (year % 100 != 0 OR year % 400 = 0)) THEN
        IF day > 29 THEN
          RETURN FALSE;
        END IF;
      ELSE
        IF day > 28 THEN
          RETURN FALSE;
        END IF;
      END IF;
    END IF;
    
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN FALSE;
  END;
END;
$$ LANGUAGE plpgsql;

-- Function to convert date to French format
CREATE OR REPLACE FUNCTION to_french_date(date_value DATE)
RETURNS TEXT AS $$
BEGIN
  RETURN TO_CHAR(date_value, 'DD/MM/YYYY');
END;
$$ LANGUAGE plpgsql;

-- Function to parse French date to DATE type
CREATE OR REPLACE FUNCTION from_french_date(date_str TEXT)
RETURNS DATE AS $$
BEGIN
  IF date_str IS NULL OR date_str = '' THEN
    RETURN NULL;
  END IF;
  
  IF NOT is_valid_french_date(date_str) THEN
    RAISE EXCEPTION 'Invalid date format. Expected DD/MM/YYYY';
  END IF;
  
  RETURN TO_DATE(date_str, 'DD/MM/YYYY');
END;
$$ LANGUAGE plpgsql;

-- Safely convert existing dates
DO $$ 
BEGIN
  -- Create temporary columns
  ALTER TABLE parts ADD COLUMN eta_new TEXT;
  ALTER TABLE parts ADD COLUMN date_cf_new TEXT;
  
  -- Convert existing dates to French format
  UPDATE parts 
  SET 
    eta_new = CASE 
      WHEN eta IS NOT NULL THEN to_french_date(eta::DATE)
      ELSE NULL 
    END,
    date_cf_new = CASE 
      WHEN date_cf IS NOT NULL THEN to_french_date(date_cf::DATE)
      ELSE NULL 
    END;
  
  -- Drop old columns and rename new ones
  ALTER TABLE parts DROP COLUMN eta;
  ALTER TABLE parts DROP COLUMN date_cf;
  ALTER TABLE parts RENAME COLUMN eta_new TO eta;
  ALTER TABLE parts RENAME COLUMN date_cf_new TO date_cf;
  
  -- Add constraints for French date format
  ALTER TABLE parts 
    ADD CONSTRAINT eta_format_check 
    CHECK (eta IS NULL OR is_valid_french_date(eta));
  
  ALTER TABLE parts 
    ADD CONSTRAINT date_cf_format_check 
    CHECK (date_cf IS NULL OR is_valid_french_date(date_cf));
END $$;

-- Create triggers to validate date formats on insert/update
CREATE OR REPLACE FUNCTION validate_dates_trigger()
RETURNS TRIGGER AS $$
BEGIN
  -- Validate ETA
  IF NEW.eta IS NOT NULL THEN
    IF NOT is_valid_french_date(NEW.eta) THEN
      RAISE EXCEPTION 'Invalid ETA date format. Expected DD/MM/YYYY';
    END IF;
  END IF;
  
  -- Validate Date CF
  IF NEW.date_cf IS NOT NULL THEN
    IF NOT is_valid_french_date(NEW.date_cf) THEN
      RAISE EXCEPTION 'Invalid Date CF format. Expected DD/MM/YYYY';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_dates
  BEFORE INSERT OR UPDATE ON parts
  FOR EACH ROW
  EXECUTE FUNCTION validate_dates_trigger();

-- Add helpful comments to the columns
COMMENT ON COLUMN parts.eta IS 'Expected arrival date in French format (DD/MM/YYYY)';
COMMENT ON COLUMN parts.date_cf IS 'CF date in French format (DD/MM/YYYY)';