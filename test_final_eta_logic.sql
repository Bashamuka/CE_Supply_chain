-- Script de test final pour la logique ETA
-- Test simple et robuste sans erreurs

-- 1. Test basique de la vue
SELECT 
  'BASIC TEST: View Creation' as test_type,
  COUNT(*) as total_records,
  COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) as records_with_eta
FROM mv_project_analytics_complete;

-- 2. Test des pièces en transit/backorder
SELECT 
  'TRANSIT/BACKORDER TEST' as test_type,
  part_number,
  project_id,
  quantity_in_transit,
  quantity_missing,
  latest_eta,
  CASE 
    WHEN quantity_in_transit > 0 AND quantity_missing > 0 THEN 'BOTH'
    WHEN quantity_in_transit > 0 THEN 'TRANSIT_ONLY'
    WHEN quantity_missing > 0 THEN 'BACKORDER_ONLY'
    ELSE 'NONE'
  END as status
FROM mv_project_analytics_complete
WHERE quantity_in_transit > 0 OR quantity_missing > 0
ORDER BY project_id, part_number
LIMIT 10;

-- 3. Test de la fonction de vérification
SELECT * FROM verify_final_eta_logic() LIMIT 5;

-- 4. Statistiques finales
SELECT 
  'FINAL STATISTICS' as test_type,
  COUNT(*) as total_parts,
  COUNT(CASE WHEN quantity_in_transit > 0 OR quantity_missing > 0 THEN 1 END) as parts_needing_eta,
  COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) as parts_with_eta,
  ROUND(
    COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) * 100.0 / 
    NULLIF(COUNT(CASE WHEN quantity_in_transit > 0 OR quantity_missing > 0 THEN 1 END), 0), 2
  ) as eta_coverage_percentage
FROM mv_project_analytics_complete;
