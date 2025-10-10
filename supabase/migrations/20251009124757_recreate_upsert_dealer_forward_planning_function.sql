/*
  # Recreate upsert_dealer_forward_planning function

  ## Purpose
  This migration recreates the upsert_dealer_forward_planning function that handles
  the merge logic for the Dealer Forward Planning Program.

  ## Changes
  - Drops and recreates the upsert_dealer_forward_planning function
  - This function handles duplicate detection and quantity aggregation

  ## Important Notes
  - When a duplicate (same part_number + business_case_notes) is uploaded:
    - The system UPDATEs the existing record
    - Adds the new forecast_quantity to the existing one
*/

-- Drop the function if it exists
DROP FUNCTION IF EXISTS upsert_dealer_forward_planning(text, text, decimal, text, uuid);

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