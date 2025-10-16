-- Script de diagnostic spécifique pour la pièce 1357935 (SEAL-O-RING)
-- Ce script va identifier pourquoi cette pièce n'a pas d'ETA

-- 1. Diagnostic spécifique pour la pièce 1357935
SELECT 
  'SPECIFIC PART DIAGNOSIS: 1357935' as test_type,
  pac.part_number,
  pac.project_id,
  pac.quantity_in_transit,
  pac.quantity_missing,
  pac.latest_eta as current_eta,
  pac.description
FROM mv_project_analytics_complete pac
WHERE pac.part_number = '1357935'
ORDER BY pac.project_id;

-- 2. Vérifier toutes les données ETA disponibles pour cette pièce
SELECT 
  'ETA DATA FOR 1357935' as test_type,
  p.part_ordered,
  p.eta,
  p.status,
  p.comments,
  pso.project_id,
  pso.supplier_order,
  pso.order_date
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
  AND p.eta IS NOT NULL
  AND TRIM(p.eta) != ''
ORDER BY pso.project_id, p.eta DESC;

-- 3. Vérifier avec correspondance insensible à la casse
SELECT 
  'CASE INSENSITIVE MATCH FOR 1357935' as test_type,
  p.part_ordered,
  p.eta,
  p.status,
  pso.project_id
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE UPPER(TRIM(p.part_ordered)) = UPPER(TRIM('1357935'))
  AND p.eta IS NOT NULL
  AND TRIM(p.eta) != ''
ORDER BY pso.project_id, p.eta DESC;

-- 4. Vérifier toutes les commandes pour cette pièce (même sans ETA)
SELECT 
  'ALL ORDERS FOR 1357935' as test_type,
  p.part_ordered,
  p.eta,
  p.status,
  p.comments,
  pso.project_id,
  pso.supplier_order
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
ORDER BY pso.project_id, p.status;

-- 5. Utiliser la vue de diagnostic
SELECT * FROM v_eta_diagnosis WHERE part_number = '1357935';

-- 6. Test général de la logique améliorée
SELECT 
  'GENERAL TEST: Enhanced ETA Logic' as test_type,
  COUNT(*) as total_parts_needing_eta,
  COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) as parts_with_eta,
  COUNT(CASE WHEN latest_eta IS NULL OR latest_eta = '' THEN 1 END) as parts_missing_eta,
  ROUND(
    COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) * 100.0 / 
    COUNT(*), 2
  ) as eta_coverage_percentage
FROM mv_project_analytics_complete
WHERE quantity_in_transit > 0 OR quantity_missing > 0;

-- 7. Exemples de pièces avec ETA trouvée
SELECT 
  'EXAMPLES: Parts with ETA Found' as test_type,
  part_number,
  project_id,
  quantity_in_transit,
  quantity_missing,
  latest_eta
FROM mv_project_analytics_complete
WHERE (quantity_in_transit > 0 OR quantity_missing > 0)
  AND latest_eta IS NOT NULL
  AND latest_eta != ''
ORDER BY project_id, part_number
LIMIT 10;

-- 8. Exemples de pièces sans ETA (pour comparaison)
SELECT 
  'EXAMPLES: Parts Missing ETA' as test_type,
  part_number,
  project_id,
  quantity_in_transit,
  quantity_missing,
  latest_eta
FROM mv_project_analytics_complete
WHERE (quantity_in_transit > 0 OR quantity_missing > 0)
  AND (latest_eta IS NULL OR latest_eta = '')
ORDER BY project_id, part_number
LIMIT 10;
