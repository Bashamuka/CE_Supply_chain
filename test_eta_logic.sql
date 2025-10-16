-- Script de vérification de la logique ETA pour Backorder et Transit
-- Ce script teste que la logique Latest ETA fonctionne correctement

-- 1. Vérification générale de la logique ETA
SELECT 
  'VERIFICATION: ETA Logic for Backorder and Transit' as test_type,
  pac.part_number,
  pac.project_id,
  pac.quantity_in_transit,
  pac.quantity_missing,
  pac.latest_eta,
  CASE 
    WHEN pac.quantity_in_transit > 0 AND pac.quantity_missing > 0 THEN 'BOTH_TRANSIT_AND_BACKORDER'
    WHEN pac.quantity_in_transit > 0 THEN 'TRANSIT_ONLY'
    WHEN pac.quantity_missing > 0 THEN 'BACKORDER_ONLY'
    ELSE 'NO_TRANSIT_OR_BACKORDER'
  END as part_status,
  CASE 
    WHEN pac.latest_eta IS NOT NULL AND pac.latest_eta != '' THEN 'HAS_ETA'
    ELSE 'MISSING_ETA'
  END as eta_status
FROM mv_project_analytics_complete pac
WHERE pac.quantity_in_transit > 0 OR pac.quantity_missing > 0
ORDER BY pac.project_id, pac.part_number;

-- 2. Test spécifique pour les pièces en BOTH Transit et Backorder
SELECT 
  'TEST: Parts in BOTH Transit and Backorder' as test_type,
  pac.part_number,
  pac.project_id,
  pac.quantity_in_transit,
  pac.quantity_missing,
  pac.latest_eta,
  -- Vérifier toutes les ETA disponibles pour cette pièce
  (
    SELECT ARRAY_AGG(p.eta ORDER BY p.eta DESC)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.status NOT IN ('Received', 'Cancelled')
      AND (p.comments IS NULL OR LOWER(p.comments) NOT LIKE '%delivery completed%')
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
  ) as all_available_etas,
  -- Vérifier que latest_eta est bien la plus longue
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.status NOT IN ('Received', 'Cancelled')
      AND (p.comments IS NULL OR LOWER(p.comments) NOT LIKE '%delivery completed%')
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
  ) as max_eta_from_query
FROM mv_project_analytics_complete pac
WHERE pac.quantity_in_transit > 0 AND pac.quantity_missing > 0
ORDER BY pac.project_id, pac.part_number;

-- 3. Statistiques de couverture ETA
SELECT 
  'STATISTICS: ETA Coverage' as test_type,
  COUNT(*) as total_parts_in_transit_or_backorder,
  COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) as parts_with_eta,
  COUNT(CASE WHEN latest_eta IS NULL OR latest_eta = '' THEN 1 END) as parts_missing_eta,
  ROUND(
    COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) * 100.0 / 
    COUNT(*), 2
  ) as eta_coverage_percentage,
  -- Breakdown by status
  COUNT(CASE WHEN quantity_in_transit > 0 AND quantity_missing > 0 THEN 1 END) as parts_in_both,
  COUNT(CASE WHEN quantity_in_transit > 0 AND quantity_missing = 0 THEN 1 END) as parts_transit_only,
  COUNT(CASE WHEN quantity_in_transit = 0 AND quantity_missing > 0 THEN 1 END) as parts_backorder_only
FROM mv_project_analytics_complete
WHERE quantity_in_transit > 0 OR quantity_missing > 0;

-- 4. Test de la fonction de vérification
SELECT * FROM verify_eta_logic();

-- 5. Exemple concret de vérification pour une pièce spécifique
-- (Remplacez 'PART_NUMBER' par un numéro de pièce réel de votre base)
/*
SELECT 
  'EXAMPLE: Specific Part ETA Analysis' as test_type,
  p.part_ordered,
  p.eta,
  p.status,
  p.comments,
  pso.project_id,
  pac.quantity_in_transit,
  pac.quantity_missing,
  pac.latest_eta
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
LEFT JOIN mv_project_analytics_complete pac ON pac.part_number = p.part_ordered 
  AND pac.project_id = pso.project_id
WHERE p.part_ordered = 'PART_NUMBER'  -- Remplacez par un vrai numéro de pièce
  AND p.eta IS NOT NULL 
  AND TRIM(p.eta) != ''
ORDER BY p.eta DESC;
*/
