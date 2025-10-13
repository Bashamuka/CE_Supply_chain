/*
  # Remove UNIQUE constraint from order_number

  1. Changes
    - Remove UNIQUE constraint from order_number column in parts table
    - Keep NOT NULL constraint
  
  2. Notes
    - This allows multiple entries with the same order number
    - The id column remains as the primary key
*/

ALTER TABLE parts 
DROP CONSTRAINT IF EXISTS parts_order_number_key;