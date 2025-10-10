/*
  # Mise à jour de la structure de la table parts

  1. Changements
    - Suppression des anciennes colonnes
    - Ajout des nouvelles colonnes avec les types appropriés
    - Modification de la clé primaire en BIGSERIAL

  2. Structure
    - id (BIGSERIAL PRIMARY KEY)
    - order_number (text NOT NULL)
    - supplier_order (text)
    - part_ordered (text)
    - part_delivered (text)
    - description (text)
    - quantity_requested (integer)
    - invoice_quantity (integer)
    - qty_received_irium (integer)
    - status (text)
    - cd_lta (text)
    - eta (timestamp with time zone)
*/

-- Suppression des anciennes colonnes
ALTER TABLE parts
DROP COLUMN IF EXISTS client_number,
DROP COLUMN IF EXISTS client_name,
DROP COLUMN IF EXISTS po_reference,
DROP COLUMN IF EXISTS branch,
DROP COLUMN IF EXISTS cf_number,
DROP COLUMN IF EXISTS order_reference,
DROP COLUMN IF EXISTS equivalents,
DROP COLUMN IF EXISTS backorder,
DROP COLUMN IF EXISTS billing,
DROP COLUMN IF EXISTS delivery,
DROP COLUMN IF EXISTS available_stock,
DROP COLUMN IF EXISTS dealer_net_usd,
DROP COLUMN IF EXISTS order_date,
DROP COLUMN IF EXISTS billing_date,
DROP COLUMN IF EXISTS update_date,
DROP COLUMN IF EXISTS carrier,
DROP COLUMN IF EXISTS current_position,
DROP COLUMN IF EXISTS eta_ce,
DROP COLUMN IF EXISTS reception_date,
DROP COLUMN IF EXISTS receptionist,
DROP COLUMN IF EXISTS cat_ticket_id,
DROP COLUMN IF EXISTS ticket_status,
DROP COLUMN IF EXISTS cat_line_status,
DROP COLUMN IF EXISTS flag,
DROP COLUMN IF EXISTS ship_by_date,
DROP COLUMN IF EXISTS store_comments,
DROP COLUMN IF EXISTS search_vector,
DROP COLUMN IF EXISTS created_at,
DROP COLUMN IF EXISTS updated_at;

-- Modification de la clé primaire
ALTER TABLE parts
DROP CONSTRAINT IF EXISTS parts_pkey;

-- Suppression de l'ancienne colonne id si elle existe
ALTER TABLE parts
DROP COLUMN IF EXISTS id;

-- Ajout de la nouvelle colonne id avec BIGSERIAL
ALTER TABLE parts
ADD COLUMN id BIGSERIAL PRIMARY KEY;

-- Ajout/Modification des colonnes selon la nouvelle structure
ALTER TABLE parts
ADD COLUMN IF NOT EXISTS supplier_order text,
ADD COLUMN IF NOT EXISTS part_ordered text,
ADD COLUMN IF NOT EXISTS part_delivered text,
ADD COLUMN IF NOT EXISTS quantity_requested integer,
ADD COLUMN IF NOT EXISTS invoice_quantity integer,
ADD COLUMN IF NOT EXISTS qty_received_irium integer,
ADD COLUMN IF NOT EXISTS status text,
ADD COLUMN IF NOT EXISTS cd_lta text,
ADD COLUMN IF NOT EXISTS eta timestamp with time zone;