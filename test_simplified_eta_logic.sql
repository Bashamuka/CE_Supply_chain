-- Script de test pour la logique ETA simplifiée
-- Vérifie que l'ETA le plus long est TOUJOURS pris, peu importe le statut de la pièce

-- 1. Test général de la logique simplifiée
SELECT 
  'TEST: Simplified ETA Logic - Always MAX' as test_type,
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

-- 2. Vérification que l'ETA affiché est bien le MAX
SELECT 
  'VERIFICATION: ETA is MAX' as test_type,
  pac.part_number,
  pac.project_id,
  pac.latest_eta as displayed_eta,
  -- Toutes les ETA disponibles pour cette pièce
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
  -- Le MAX calculé manuellement
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
  ) as calculated_max_eta,
  -- Vérification que c'est bien le même
  CASE 
    WHEN pac.latest_eta = (
      SELECT MAX(p.eta)
      FROM project_supplier_orders pso
      JOIN parts p ON p.supplier_order = pso.supplier_order
      WHERE pso.project_id = pac.project_id
        AND p.part_ordered = pac.part_number
        AND p.status NOT IN ('Received', 'Cancelled')
        AND (p.comments IS NULL OR LOWER(p.comments) NOT LIKE '%delivery completed%')
        AND p.eta IS NOT NULL
        AND TRIM(p.eta) != ''
    ) THEN 'CORRECT'
    ELSE 'ERROR'
  END as verification_result
FROM mv_project_analytics_complete pac
WHERE (pac.quantity_in_transit > 0 OR pac.quantity_missing > 0)
  AND pac.latest_eta IS NOT NULL
  AND pac.latest_eta != ''
ORDER BY pac.project_id, pac.part_number;

-- 3. Test spécifique pour les pièces avec plusieurs ETA
SELECT 
  'TEST: Parts with Multiple ETAs' as test_type,
  pac.part_number,
  pac.project_id,
  pac.quantity_in_transit,
  pac.quantity_missing,
  pac.latest_eta,
  -- Compter le nombre d'ETA disponibles
  (
    SELECT COUNT(*)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.status NOT IN ('Received', 'Cancelled')
      AND (p.comments IS NULL OR LOWER(p.comments) NOT LIKE '%delivery completed%')
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
  ) as eta_count,
  -- Toutes les ETA triées par ordre décroissant
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
  ) as all_etas_ordered
FROM mv_project_analytics_complete pac
WHERE (pac.quantity_in_transit > 0 OR pac.quantity_missing > 0)
  AND pac.latest_eta IS NOT NULL
  AND pac.latest_eta != ''
  AND (
    SELECT COUNT(*)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.status NOT IN ('Received', 'Cancelled')
      AND (p.comments IS NULL OR LOWER(p.comments) NOT LIKE '%delivery completed%')
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
  ) > 1  -- Seulement les pièces avec plusieurs ETA
ORDER BY pac.project_id, pac.part_number;

-- 4. Statistiques finales
SELECT 
  'STATISTICS: Final Results' as test_type,
  COUNT(*) as total_parts_in_transit_or_backorder,
  COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) as parts_with_eta,
  COUNT(CASE WHEN latest_eta IS NULL OR latest_eta = '' THEN 1 END) as parts_missing_eta,
  ROUND(
    COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) * 100.0 / 
    COUNT(*), 2
  ) as eta_coverage_percentage,
  -- Breakdown par statut
  COUNT(CASE WHEN quantity_in_transit > 0 AND quantity_missing > 0 THEN 1 END) as parts_in_both,
  COUNT(CASE WHEN quantity_in_transit > 0 AND quantity_missing = 0 THEN 1 END) as parts_transit_only,
  COUNT(CASE WHEN quantity_in_transit = 0 AND quantity_missing > 0 THEN 1 END) as parts_backorder_only
FROM mv_project_analytics_complete
WHERE quantity_in_transit > 0 OR quantity_missing > 0;

-- 5. Utiliser la fonction de vérification
SELECT * FROM verify_simplified_eta_logic();
