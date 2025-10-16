-- Vérification rapide après refresh des vues matérialisées
-- Pour voir si les ETA s'affichent maintenant

-- 1. Vérifier les ETA pour la pièce 1357935
SELECT 
  'ETA CHECK FOR 1357935' as test_type,
  part_number,
  project_id,
  quantity_required,
  quantity_available,
  quantity_used,
  quantity_in_transit,
  quantity_missing,
  latest_eta
FROM mv_project_analytics_complete
WHERE part_number = '1357935';

-- 2. Vérifier toutes les pièces avec des quantités en transit mais sans ETA
SELECT 
  'PARTS IN TRANSIT WITHOUT ETA' as test_type,
  part_number,
  project_id,
  quantity_in_transit,
  quantity_missing,
  latest_eta
FROM mv_project_analytics_complete
WHERE (quantity_in_transit > 0 OR quantity_missing > 0)
  AND (latest_eta IS NULL OR latest_eta = '' OR latest_eta = '-')
ORDER BY quantity_in_transit DESC, quantity_missing DESC;

-- 3. Compter les pièces avec et sans ETA
SELECT 
  'ETA COVERAGE SUMMARY' as test_type,
  COUNT(*) as total_parts_needing_eta,
  COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' AND latest_eta != '-' THEN 1 END) as parts_with_eta,
  COUNT(CASE WHEN latest_eta IS NULL OR latest_eta = '' OR latest_eta = '-' THEN 1 END) as parts_missing_eta,
  ROUND(
    COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' AND latest_eta != '-' THEN 1 END) * 100.0 / 
    COUNT(*), 2
  ) as eta_coverage_percentage
FROM mv_project_analytics_complete
WHERE quantity_in_transit > 0 OR quantity_missing > 0;

-- 4. Test direct de la requête ETA pour 1357935
SELECT 
  'DIRECT ETA TEST FOR 1357935' as test_type,
  p.part_ordered,
  pso.project_id,
  MAX(p.eta) as max_eta,
  COUNT(*) as total_records,
  COUNT(CASE WHEN p.eta IS NOT NULL AND TRIM(p.eta) != '' AND LENGTH(TRIM(p.eta)) >= 5 THEN 1 END) as valid_eta_records
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
GROUP BY p.part_ordered, pso.project_id;

-- 5. Vérifier les données brutes pour 1357935
SELECT 
  'RAW DATA FOR 1357935' as test_type,
  p.part_ordered,
  p.eta,
  p.status,
  p.comments,
  pso.project_id
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
ORDER BY p.eta DESC;
