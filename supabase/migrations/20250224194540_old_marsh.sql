/*
  # Réinitialisation de la séquence d'auto-incrément

  1. Changements
    - Réinitialisation de la séquence d'auto-incrément de la table parts
    - Assure que les nouveaux IDs commencent à 1
    - Gestion sûre et idempotente de la séquence

  2. Notes
    - Cette migration est sûre et peut être exécutée plusieurs fois
    - Ne cause pas de perte de données
    - S'exécute avant l'import de nouvelles données
*/

DO $$ 
BEGIN
  -- Réinitialiser la séquence à 1
  ALTER SEQUENCE parts_id_seq RESTART WITH 1;
  
  -- S'assurer que la séquence est correctement liée à la colonne id
  ALTER TABLE parts ALTER COLUMN id SET DEFAULT nextval('parts_id_seq');
  
  -- Mettre à jour la séquence pour qu'elle suive la plus grande valeur existante
  PERFORM setval('parts_id_seq', COALESCE((SELECT MAX(id) FROM parts), 0) + 1, false);
END $$;