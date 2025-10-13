/*
  # Add Prim PSO column to parts table

  1. New Column
    - `prim_pso` (text) - Prim PSO reference field

  2. Changes
    - Add new column to parts table
    - Column is nullable for compatibility with existing data
*/

-- Add the new Prim PSO column
ALTER TABLE parts
ADD COLUMN IF NOT EXISTS prim_pso text;

-- Add comment to the column for documentation
COMMENT ON COLUMN parts.prim_pso IS 'Prim PSO reference field';