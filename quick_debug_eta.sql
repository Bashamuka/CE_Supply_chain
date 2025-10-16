-- Script de test rapide pour vérifier les vues matérialisées
-- et identifier le problème d'affichage des ETA

-- 1. Vérifier l'état des vues matérialisées
SELECT 
  'MATERIALIZED VIEWS STATUS' as check_type,
  matviewname,
  ispopulated,
  hasindexes
FROM pg_matviews 
WHERE matviewname LIKE 'mv_project%'
ORDER BY matviewname;

-- 2. Compter les enregistrements dans chaque vue
SELECT 'mv_project_machine_parts_aggregated' as view_name, COUNT(*) as record_count
FROM mv_project_machine_parts_aggregated
UNION ALL
SELECT 'mv_project_parts_stock_availability' as view_name, COUNT(*) as record_count
FROM mv_project_parts_stock_availability
UNION ALL
SELECT 'mv_project_parts_used_quantities' as view_name, COUNT(*) as record_count
FROM mv_project_parts_used_quantities
UNION ALL
SELECT 'mv_project_parts_transit_invoiced' as view_name, COUNT(*) as record_count
FROM mv_project_parts_transit_invoiced
UNION ALL
SELECT 'mv_project_analytics_complete' as view_name, COUNT(*) as record_count
FROM mv_project_analytics_complete;

-- 3. Vérifier spécifiquement la pièce 1357935 dans chaque vue
SELECT 'mv_project_machine_parts_aggregated' as view_name, COUNT(*) as record_count
FROM mv_project_machine_parts_aggregated
WHERE part_number = '1357935'
UNION ALL
SELECT 'mv_project_parts_stock_availability' as view_name, COUNT(*) as record_count
FROM mv_project_parts_stock_availability
WHERE part_number = '1357935'
UNION ALL
SELECT 'mv_project_parts_used_quantities' as view_name, COUNT(*) as record_count
FROM mv_project_parts_used_quantities
WHERE part_number = '1357935'
UNION ALL
SELECT 'mv_project_parts_transit_invoiced' as view_name, COUNT(*) as record_count
FROM mv_project_parts_transit_invoiced
WHERE part_number = '1357935'
UNION ALL
SELECT 'mv_project_analytics_complete' as view_name, COUNT(*) as record_count
FROM mv_project_analytics_complete
WHERE part_number = '1357935';

-- 4. Test direct de la requête ETA sur les données brutes
SELECT 
  'DIRECT ETA TEST' as test_type,
  p.part_ordered,
  pso.project_id,
  p.eta,
  p.status,
  CASE 
    WHEN p.eta IS NULL THEN 'NULL'
    WHEN TRIM(p.eta) = '' THEN 'EMPTY'
    WHEN LENGTH(TRIM(p.eta)) < 5 THEN 'TOO_SHORT'
    ELSE 'VALID'
  END as eta_validation
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
ORDER BY p.eta DESC;

-- 5. Test de la requête MAX(eta) exacte
SELECT 
  'MAX ETA TEST' as test_type,
  p.part_ordered,
  pso.project_id,
  MAX(p.eta) as max_eta,
  COUNT(*) as total_records,
  COUNT(CASE WHEN p.eta IS NOT NULL AND TRIM(p.eta) != '' AND LENGTH(TRIM(p.eta)) >= 5 THEN 1 END) as valid_eta_records
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
GROUP BY p.part_ordered, pso.project_id;

-- 6. Vérifier les données dans mv_project_analytics_complete pour 1357935
SELECT 
  'ANALYTICS VIEW CHECK' as test_type,
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

-- 7. Forcer le refresh et vérifier à nouveau
SELECT refresh_project_analytics_views();

-- 8. Vérifier après refresh
SELECT 
  'AFTER REFRESH CHECK' as test_type,
  part_number,
  project_id,
  quantity_in_transit,
  quantity_missing,
  latest_eta
FROM mv_project_analytics_complete
WHERE part_number = '1357935';
