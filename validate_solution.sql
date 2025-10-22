-- Test de validation - Vérifier que la solution fonctionne
-- Exécuter ce script après avoir appliqué la migration 20251020150000_fix_stock_availability_definitive.sql

-- Test 1: Vérifier que mv_project_parts_stock_availability retourne maintenant 3 pour 4D4508
SELECT 
  'Test 1: Stock Availability' as test_name,
  project_id,
  part_number,
  quantity_available,
  CASE 
    WHEN quantity_available = 3 THEN '✅ SUCCESS' 
    ELSE '❌ FAILED' 
  END as result
FROM mv_project_parts_stock_availability 
WHERE part_number = '4D4508';

-- Test 2: Vérifier que mv_project_analytics_complete retourne maintenant les bonnes valeurs
SELECT 
  'Test 2: Analytics Complete' as test_name,
  machine_name,
  part_number,
  quantity_required,
  quantity_available,
  quantity_in_transit,
  quantity_invoiced,
  CASE 
    WHEN quantity_available = 3 AND quantity_in_transit = 5 AND quantity_invoiced = 0 THEN '✅ SUCCESS' 
    ELSE '❌ FAILED' 
  END as result
FROM mv_project_analytics_complete 
WHERE part_number = '4D4508' AND machine_name = 'D10T2REB';

-- Test 3: Vérifier qu'il n'y a pas de doublons dans stock_dispo pour 4D4508
SELECT 
  'Test 3: No Duplicates' as test_name,
  part_number,
  COUNT(*) as row_count,
  SUM(qté_succ_20) as total_succ_20,
  CASE 
    WHEN COUNT(*) = 1 AND SUM(qté_succ_20) = 3 THEN '✅ SUCCESS' 
    ELSE '❌ FAILED - Check for duplicates' 
  END as result
FROM stock_dispo 
WHERE part_number = '4D4508'
GROUP BY part_number;

