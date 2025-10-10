/*
  # Ajout de nouvelles colonnes à la table parts

  1. Nouvelles colonnes
    - `date_cf` (timestamp with time zone) : Date de création de la commande fournisseur
    - `invoice_number` (text) : Numéro de facture
    - `actual_position` (text) : Position actuelle de la pièce
    - `operator_name` (text) : Nom de l'opérateur
    - `po_customer` (text) : Numéro de commande client
    - `comments` (text) : Commentaires généraux

  2. Changements
    - Ajout de 6 nouvelles colonnes à la table parts
    - Toutes les colonnes sont nullables pour maintenir la compatibilité avec les données existantes
*/

-- Ajout des nouvelles colonnes
ALTER TABLE parts
ADD COLUMN IF NOT EXISTS date_cf timestamp with time zone,
ADD COLUMN IF NOT EXISTS invoice_number text,
ADD COLUMN IF NOT EXISTS actual_position text,
ADD COLUMN IF NOT EXISTS operator_name text,
ADD COLUMN IF NOT EXISTS po_customer text,
ADD COLUMN IF NOT EXISTS comments text;