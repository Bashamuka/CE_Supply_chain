/*
  # Ajout de colonnes de suivi pour la table parts

  1. Nouvelles Colonnes
    - `date_cf` (timestamp with time zone) - Date du CF
    - `invoice_number` (text) - Numéro de facture
    - `actual_position` (text) - Position actuelle
    - `operator_name` (text) - Nom de l'opérateur
    - `po_customer` (text) - PO client
    - `comments` (text) - Commentaires

  2. Notes
    - Toutes les colonnes sont nullables pour permettre une migration en douceur
    - Les colonnes sont ajoutées sans impact sur les données existantes
*/

-- Ajout des nouvelles colonnes
ALTER TABLE parts
ADD COLUMN IF NOT EXISTS date_cf timestamp with time zone,
ADD COLUMN IF NOT EXISTS invoice_number text,
ADD COLUMN IF NOT EXISTS actual_position text,
ADD COLUMN IF NOT EXISTS operator_name text,
ADD COLUMN IF NOT EXISTS po_customer text,
ADD COLUMN IF NOT EXISTS comments text;