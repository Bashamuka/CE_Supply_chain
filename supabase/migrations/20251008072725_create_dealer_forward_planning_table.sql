/*
  # Create Dealer Forward Planning Program table

  ## Purpose
  This migration creates the table for the Dealer Forward Planning Program module
  where planners can upload forecasts of parts they need CAT to make available
  in specific regions.

  ## New Tables
  
  1. **dealer_forward_planning**
     - `id` (uuid, primary key) - Unique identifier
     - `part_number` (text, NOT NULL) - Part reference number
     - `model` (text) - Model information
     - `forecast_quantity` (decimal) - Forecasted quantity needed
     - `business_case_notes` (text) - Business case notes/justification
     - `uploaded_by` (uuid, NOT NULL) - User who uploaded this record
     - `upload_date` (timestamptz) - When the record was uploaded
     - `created_at` (timestamptz) - Record creation timestamp
     - `updated_at` (timestamptz) - Last update timestamp

  ## Security
  - Enable RLS on `dealer_forward_planning` table
  - Planners (authenticated users) can:
    - View all records
    - Insert their own records
  - Admins can:
    - View, insert, update, and delete all records

  ## Indexes
  - Index on `part_number` for fast lookups
  - Index on `uploaded_by` for filtering by user
  - Composite index on (`part_number`, `business_case_notes`) for duplicate detection

  ## Important Notes
  - When a duplicate (same part_number + business_case_notes) is uploaded:
    - The system should UPDATE the existing record
    - Add the new forecast_quantity to the existing one
  - This logic will be handled via a stored function for atomic operations
*/

-- Create the dealer_forward_planning table
CREATE TABLE IF NOT EXISTS dealer_forward_planning (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  part_number text NOT NULL,
  model text,
  forecast_quantity decimal(10,2) NOT NULL DEFAULT 0,
  business_case_notes text,
  uploaded_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  upload_date timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE dealer_forward_planning ENABLE ROW LEVEL SECURITY;

-- Policy: All authenticated users can view all records
CREATE POLICY "Authenticated users can view all planning records"
  ON dealer_forward_planning FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Authenticated users can insert records
CREATE POLICY "Authenticated users can insert planning records"
  ON dealer_forward_planning FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = uploaded_by);

-- Policy: Users can update records they uploaded
CREATE POLICY "Users can update their own planning records"
  ON dealer_forward_planning FOR UPDATE
  TO authenticated
  USING (auth.uid() = uploaded_by)
  WITH CHECK (auth.uid() = uploaded_by);

-- Policy: Users can delete records they uploaded
CREATE POLICY "Users can delete their own planning records"
  ON dealer_forward_planning FOR DELETE
  TO authenticated
  USING (auth.uid() = uploaded_by);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_dfp_part_number ON dealer_forward_planning(part_number);
CREATE INDEX IF NOT EXISTS idx_dfp_uploaded_by ON dealer_forward_planning(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_dfp_part_business ON dealer_forward_planning(part_number, business_case_notes);
CREATE INDEX IF NOT EXISTS idx_dfp_upload_date ON dealer_forward_planning(upload_date DESC);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_dfp_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_dealer_forward_planning_updated_at
  BEFORE UPDATE ON dealer_forward_planning
  FOR EACH ROW
  EXECUTE FUNCTION update_dfp_updated_at_column();

-- Create a function to handle upsert logic (merge duplicates)
CREATE OR REPLACE FUNCTION upsert_dealer_forward_planning(
  p_part_number text,
  p_model text,
  p_forecast_quantity decimal,
  p_business_case_notes text,
  p_uploaded_by uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_id uuid;
  v_new_quantity decimal;
  v_result_id uuid;
BEGIN
  -- Check if a record exists with same part_number and business_case_notes
  SELECT id, forecast_quantity INTO v_existing_id, v_new_quantity
  FROM dealer_forward_planning
  WHERE part_number = p_part_number
    AND COALESCE(business_case_notes, '') = COALESCE(p_business_case_notes, '');

  IF v_existing_id IS NOT NULL THEN
    -- Update existing record: add quantities
    UPDATE dealer_forward_planning
    SET 
      forecast_quantity = forecast_quantity + p_forecast_quantity,
      model = COALESCE(p_model, model),
      uploaded_by = p_uploaded_by,
      upload_date = now(),
      updated_at = now()
    WHERE id = v_existing_id;
    
    v_result_id := v_existing_id;
  ELSE
    -- Insert new record
    INSERT INTO dealer_forward_planning (
      part_number,
      model,
      forecast_quantity,
      business_case_notes,
      uploaded_by,
      upload_date
    ) VALUES (
      p_part_number,
      p_model,
      p_forecast_quantity,
      p_business_case_notes,
      p_uploaded_by,
      now()
    )
    RETURNING id INTO v_result_id;
  END IF;

  RETURN v_result_id;
END;
$$;