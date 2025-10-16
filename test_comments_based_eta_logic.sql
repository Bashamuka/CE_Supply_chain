-- Script de test pour la logique ETA basée sur les commentaires
-- Vérifie que seuls les commentaires 'Delivery completed' sont exclus

-- 1. Test spécifique pour la pièce 1357935 avec focus sur les commentaires
SELECT 
  'COMMENTS ANALYSIS FOR 1357935' as test_type,
  p.part_ordered,
  p.eta,
  p.comments,
  p.status,
  pso.project_id,
  CASE 
    WHEN LOWER(TRIM(p.comments)) = 'delivery completed' THEN 'EXCLUDED'
    ELSE 'INCLUDED'
  END as inclusion_status
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
ORDER BY pso.project_id, p.eta DESC;

-- 2. Vérifier tous les commentaires disponibles pour cette pièce
SELECT 
  'ALL COMMENTS FOR 1357935' as test_type,
  p.comments,
  COUNT(*) as comment_count,
  COUNT(CASE WHEN p.eta IS NOT NULL AND TRIM(p.eta) != '' THEN 1 END) as eta_count
FROM parts p
JOIN project_supplier_orders pso ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered = '1357935'
GROUP BY p.comments
ORDER BY comment_count DESC;

-- 3. Test de la logique d'exclusion basée sur les commentaires
SELECT 
  'COMMENTS-BASED EXCLUSION TEST' as test_type,
  pac.part_number,
  pac.project_id,
  pac.latest_eta,
  -- ETA count excluding 'Delivery completed'
  (
    SELECT COUNT(*)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND (p.comments IS NULL OR LOWER(TRIM(p.comments)) != 'delivery completed')
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
  ) as eta_count_excluding_delivered,
  -- ETA count including ALL parts
  (
    SELECT COUNT(*)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pac.project_id
      AND p.part_ordered = pac.part_number
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
  ) as eta_count_all
FROM mv_project_analytics_complete pac
WHERE pac.part_number = '1357935'
ORDER BY pac.project_id;

-- 4. Vérifier les commentaires 'Delivery completed' dans la base
SELECT 
  'DELIVERY COMPLETED PARTS' as test_type,
  p.part_ordered,
  p.comments,
  p.eta,
  p.status,
  COUNT(*) as occurrence_count
FROM parts p
WHERE LOWER(TRIM(p.comments)) = 'delivery completed'
GROUP BY p.part_ordered, p.comments, p.eta, p.status
ORDER BY occurrence_count DESC
LIMIT 10;

-- 5. Test général de la nouvelle logique
SELECT 
  'GENERAL TEST: Comments-Based Logic' as test_type,
  COUNT(*) as total_parts_needing_eta,
  COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) as parts_with_eta,
  COUNT(CASE WHEN latest_eta IS NULL OR latest_eta = '' THEN 1 END) as parts_missing_eta,
  ROUND(
    COUNT(CASE WHEN latest_eta IS NOT NULL AND latest_eta != '' THEN 1 END) * 100.0 / 
    COUNT(*), 2
  ) as eta_coverage_percentage
FROM mv_project_analytics_complete
WHERE quantity_in_transit > 0 OR quantity_missing > 0;

-- 6. Utiliser la fonction de vérification
SELECT * FROM verify_comments_based_eta_logic() WHERE part_number = '1357935';

-- 7. Utiliser la vue de diagnostic
SELECT * FROM v_eta_diagnosis WHERE part_number = '1357935';
