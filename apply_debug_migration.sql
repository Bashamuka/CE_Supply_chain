-- Script pour appliquer la migration de debug si les ETA ne s'affichent toujours pas
-- Ce script applique la logique ETA simplifiée avec debug

-- 1. Appliquer la migration de debug
-- (Copier le contenu de supabase/migrations/20251015090000_debug_eta_logic.sql ici)

-- 2. Après application, tester la fonction de debug
-- Trouver un project_id qui contient la pièce 1357935
SELECT DISTINCT project_id 
FROM mv_project_analytics_complete 
WHERE part_number = '1357935'
LIMIT 1;

-- 3. Utiliser la fonction de debug (remplacer 'PROJECT_ID_HERE' par l'ID trouvé)
-- SELECT * FROM debug_eta_logic('1357935', 'PROJECT_ID_HERE');

-- 4. Vérifier la vue de diagnostic
SELECT * FROM v_eta_diagnosis WHERE part_number = '1357935';

-- 5. Vérifier les résultats finaux
SELECT 
  part_number,
  project_id,
  quantity_in_transit,
  quantity_missing,
  latest_eta
FROM mv_project_analytics_complete
WHERE part_number = '1357935';
