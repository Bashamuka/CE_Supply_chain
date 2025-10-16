-- Script de diagnostic complet pour identifier pourquoi les ETA ne s'affichent pas
-- Malgré la logique simplifiée sans exclusions

-- 1. Vérifier si les vues matérialisées existent et sont à jour
SELECT 
  'MATERIALIZED VIEWS STATUS' as test_type,
  schemaname,
  matviewname,
  matviewowner,
  hasindexes,
  ispopulated
FROM pg_matviews 
WHERE matviewname LIKE 'mv_project%'
ORDER BY matviewname;

-- 2. Vérifier les données de base pour la pièce 1357935
SELECT 
  'RAW DATA FOR 1357935' as test_type,
  p.part_ordered,
  p.eta,
  p.status,
  p.comments,
  pso.project_id,
  pso.supplier_order
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
ORDER BY p.eta DESC;

-- 3. Vérifier les données dans project_supplier_orders pour cette pièce
SELECT 
  'PROJECT SUPPLIER ORDERS FOR 1357935' as test_type,
  pso.project_id,
  pso.supplier_order,
  COUNT(*) as parts_count
FROM project_supplier_orders pso
JOIN parts p ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
GROUP BY pso.project_id, pso.supplier_order;

-- 4. Tester la requête ETA directement
SELECT 
  'DIRECT ETA QUERY TEST' as test_type,
  p.part_ordered,
  MAX(p.eta) as max_eta,
  COUNT(*) as total_records,
  COUNT(CASE WHEN p.eta IS NOT NULL AND TRIM(p.eta) != '' THEN 1 END) as valid_eta_count
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
GROUP BY p.part_ordered;

-- 5. Vérifier les données dans mv_project_analytics_complete
SELECT 
  'ANALYTICS VIEW DATA' as test_type,
  part_number,
  project_id,
  quantity_in_transit,
  quantity_missing,
  latest_eta
FROM mv_project_analytics_complete
WHERE part_number = '1357935';

-- 6. Vérifier si les vues matérialisées sont synchronisées
SELECT 
  'VIEW REFRESH STATUS' as test_type,
  'mv_project_machine_parts_aggregated' as view_name,
  COUNT(*) as record_count
FROM mv_project_machine_parts_aggregated
WHERE part_number = '1357935'

UNION ALL

SELECT 
  'VIEW REFRESH STATUS' as test_type,
  'mv_project_parts_stock_availability' as view_name,
  COUNT(*) as record_count
FROM mv_project_parts_stock_availability
WHERE part_number = '1357935'

UNION ALL

SELECT 
  'VIEW REFRESH STATUS' as test_type,
  'mv_project_parts_transit_invoiced' as view_name,
  COUNT(*) as record_count
FROM mv_project_parts_transit_invoiced
WHERE part_number = '1357935';

-- 7. Vérifier la logique de calcul des quantités en transit
SELECT 
  'TRANSIT QUANTITY CALCULATION' as test_type,
  pac.part_number,
  pac.project_id,
  pac.quantity_in_transit,
  pac.quantity_missing,
  -- Vérifier les données sources
  (
    SELECT SUM(COALESCE(transit.quantity_in_transit, 0))
    FROM mv_project_parts_transit_invoiced transit
    WHERE transit.project_id = pac.project_id 
      AND transit.part_number = pac.part_number
  ) as transit_source_quantity
FROM mv_project_analytics_complete pac
WHERE pac.part_number = '1357935';

-- 8. Test de la requête ETA avec les vraies données de project
SELECT 
  'ETA QUERY WITH REAL PROJECT DATA' as test_type,
  pac.part_number,
  pac.project_id,
  pac.quantity_in_transit,
  pac.quantity_missing,
  -- Requête ETA exacte comme dans la vue
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
      AND LENGTH(TRIM(p.eta)) >= 5
  ) as calculated_eta
FROM mv_project_analytics_complete pac
WHERE pac.part_number = '1357935';

-- 9. Vérifier les formats de dates ETA
SELECT 
  'ETA DATE FORMATS' as test_type,
  p.part_ordered,
  p.eta,
  LENGTH(TRIM(p.eta)) as eta_length,
  CASE 
    WHEN p.eta IS NULL THEN 'NULL'
    WHEN TRIM(p.eta) = '' THEN 'EMPTY'
    WHEN LENGTH(TRIM(p.eta)) < 5 THEN 'TOO_SHORT'
    ELSE 'VALID'
  END as eta_status
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
ORDER BY p.eta DESC;

-- 10. Forcer le refresh des vues et vérifier
SELECT refresh_project_analytics_views();

-- 11. Vérifier après refresh
SELECT 
  'AFTER REFRESH CHECK' as test_type,
  part_number,
  project_id,
  quantity_in_transit,
  quantity_missing,
  latest_eta
FROM mv_project_analytics_complete
WHERE part_number = '1357935';
