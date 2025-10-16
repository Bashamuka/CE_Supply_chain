-- Script de test pour vérifier que la pièce 1357935 trouve ses ETA
-- Basé sur les données de la capture d'écran

-- 1. Test spécifique pour la pièce 1357935 avec les statuts 'Shipped' et 'FutureDated'
SELECT 
  'SPECIFIC TEST FOR 1357935' as test_type,
  p.part_ordered,
  p.eta,
  p.status,
  p.comments,
  pso.project_id,
  CASE 
    WHEN p.status IN ('Shipped', 'FutureDated', 'In Progress', 'Pending', 'Ordered', 'Confirmed') THEN 'INCLUDED'
    WHEN p.status IN ('Received', 'Cancelled', 'Delivered') THEN 'EXCLUDED'
    ELSE 'OTHER'
  END as inclusion_status
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
ORDER BY pso.project_id, p.eta DESC;

-- 2. Vérifier les ETA disponibles pour cette pièce selon la nouvelle logique
SELECT 
  'ETA ANALYSIS FOR 1357935' as test_type,
  pac.part_number,
  pac.project_id,
  pac.latest_eta as current_eta,
  pac.quantity_in_transit,
  pac.quantity_missing,
  -- ETA count with 'Shipped' and 'FutureDated' statuses
  (
    SELECT COUNT(*)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.status IN ('Shipped', 'FutureDated', 'In Progress', 'Pending', 'Ordered', 'Confirmed')
      AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
  ) as eta_count_in_progress,
  -- All available ETAs for this part
  (
    SELECT ARRAY_AGG(DISTINCT p.eta ORDER BY p.eta DESC)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.status IN ('Shipped', 'FutureDated', 'In Progress', 'Pending', 'Ordered', 'Confirmed')
      AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
  ) as available_etas
FROM mv_project_analytics_complete pac
WHERE pac.part_number = '1357935'
ORDER BY pac.project_id;

-- 3. Vérifier que la logique MAX(eta) fonctionne correctement
SELECT 
  'MAX ETA VERIFICATION FOR 1357935' as test_type,
  pac.part_number,
  pac.project_id,
  pac.latest_eta as displayed_eta,
  -- Calculate MAX(eta) manually
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.status IN ('Shipped', 'FutureDated', 'In Progress', 'Pending', 'Ordered', 'Confirmed')
      AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
  ) as calculated_max_eta,
  -- Verification
  CASE 
    WHEN pac.latest_eta = (
      SELECT MAX(p.eta)
      FROM project_supplier_orders pso
      JOIN parts p ON p.supplier_order = pso.supplier_order
      WHERE pso.project_id = pac.project_id
        AND p.part_ordered = pac.part_number
        AND p.status IN ('Shipped', 'FutureDated', 'In Progress', 'Pending', 'Ordered', 'Confirmed')
        AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
        AND p.eta IS NOT NULL
        AND TRIM(p.eta) != ''
    ) THEN 'CORRECT'
    ELSE 'ERROR'
  END as verification_result
FROM mv_project_analytics_complete pac
WHERE pac.part_number = '1357935'
ORDER BY pac.project_id;

-- 4. Test général de la nouvelle logique
SELECT 
  'GENERAL TEST: Status-Based Logic' as test_type,
  COUNT(*) as total_parts_needing_eta,
  COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) as parts_with_eta,
  COUNT(CASE WHEN latest_eta IS NULL OR latest_eta = '' THEN 1 END) as parts_missing_eta,
  ROUND(
    COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) * 100.0 / 
    COUNT(*), 2
  ) as eta_coverage_percentage
FROM mv_project_analytics_complete
WHERE quantity_in_transit > 0 OR quantity_missing > 0;

-- 5. Utiliser la fonction de vérification
SELECT * FROM verify_status_based_eta_logic() WHERE part_number = '1357935';

-- 6. Utiliser la vue de diagnostic
SELECT * FROM v_eta_diagnosis WHERE part_number = '1357935';

-- 7. Vérifier les statuts disponibles dans la base
SELECT 
  'AVAILABLE STATUSES IN DATABASE' as test_type,
  p.status,
  COUNT(*) as count,
  COUNT(CASE WHEN p.eta IS NOT NULL AND TRIM(p.eta) != '' THEN 1 END) as with_eta
FROM parts p
GROUP BY p.status
ORDER BY count DESC;
