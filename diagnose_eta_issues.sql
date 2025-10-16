-- Script de diagnostic et correction des ETA manquantes
-- Ce script identifie et corrige les problèmes d'ETA pour les pièces en Backorder ou En transit

-- 1. Diagnostic des ETA manquantes
SELECT 
  'DIAGNOSTIC: ETA Missing for Parts in Transit/Backorder' as analysis_type,
  pac.part_number,
  pac.description,
  pac.quantity_in_transit,
  pac.quantity_missing,
  pac.latest_eta,
  CASE 
    WHEN pac.quantity_in_transit > 0 AND pac.latest_eta IS NULL THEN 'MISSING ETA FOR TRANSIT'
    WHEN pac.quantity_missing > 0 AND pac.latest_eta IS NULL THEN 'MISSING ETA FOR BACKORDER'
    ELSE 'OK'
  END as issue_type
FROM mv_project_analytics_complete pac
WHERE (pac.quantity_in_transit > 0 OR pac.quantity_missing > 0)
  AND (pac.latest_eta IS NULL OR pac.latest_eta = '')
ORDER BY pac.project_id, pac.part_number;

-- 2. Vérifier les données ETA disponibles dans la table parts
SELECT 
  'AVAILABLE ETA DATA' as analysis_type,
  p.part_ordered,
  p.eta,
  p.status,
  p.comments,
  pso.project_id,
  COUNT(*) as order_count
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.eta IS NOT NULL 
  AND TRIM(p.eta) != ''
  AND p.status NOT IN ('Received', 'Cancelled')
GROUP BY p.part_ordered, p.eta, p.status, p.comments, pso.project_id
ORDER BY p.part_ordered, p.eta;

-- 3. Identifier les pièces problématiques spécifiques
WITH problematic_parts AS (
  SELECT DISTINCT
    pac.part_number,
    pac.project_id
  FROM mv_project_analytics_complete pac
  WHERE (pac.quantity_in_transit > 0 OR pac.quantity_missing > 0)
    AND (pac.latest_eta IS NULL OR pac.latest_eta = '')
)
SELECT 
  'PROBLEMATIC PARTS DETAILS' as analysis_type,
  pp.part_number,
  pp.project_id,
  p.eta,
  p.status,
  p.comments,
  pso.supplier_order,
  pso.order_date
FROM problematic_parts pp
LEFT JOIN project_supplier_orders pso ON pso.project_id = pp.project_id
LEFT JOIN parts p ON p.supplier_order = pso.supplier_order 
  AND p.part_ordered = pp.part_number
WHERE p.eta IS NOT NULL 
  AND TRIM(p.eta) != ''
ORDER BY pp.part_number, pp.project_id;

-- 4. Forcer le rafraîchissement des vues matérialisées
SELECT refresh_project_analytics_views();

-- 5. Vérification post-correction
SELECT 
  'POST-CORRECTION VERIFICATION' as analysis_type,
  COUNT(*) as total_parts_with_transit_or_backorder,
  COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) as parts_with_eta,
  COUNT(CASE WHEN latest_eta IS NULL OR latest_eta = '' THEN 1 END) as parts_missing_eta,
  ROUND(
    COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) * 100.0 / 
    COUNT(*), 2
  ) as eta_coverage_percentage
FROM mv_project_analytics_complete
WHERE quantity_in_transit > 0 OR quantity_missing > 0;
