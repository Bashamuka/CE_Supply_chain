-- Script de correction pour les quantités en transit et backorder
-- Problème: Les quantités affichent 0 même quand un LatestETA est présent
-- Cause: La logique de calcul dans mv_project_parts_transit_invoiced est trop restrictive

DO $$
BEGIN
    RAISE NOTICE '=== CORRECTION DES QUANTITÉS EN TRANSIT ET BACKORDER ===';
    RAISE NOTICE '';
    
    -- Étape 1: Supprimer l'ancienne vue
    RAISE NOTICE '🔄 Étape 1: Suppression de l''ancienne vue mv_project_parts_transit_invoiced...';
    DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_transit_invoiced CASCADE;
    RAISE NOTICE '✅ Vue supprimée';
    RAISE NOTICE '';
    
    -- Étape 2: Recréer la vue avec une logique améliorée
    RAISE NOTICE '🔄 Étape 2: Création de la nouvelle vue avec logique améliorée...';
END $$;

-- Créer la vue avec une logique de calcul plus robuste
CREATE MATERIALIZED VIEW mv_project_parts_transit_invoiced AS
SELECT 
  pso.project_id,
  p.part_ordered as part_number,
  -- Quantité en transit (Backorder) = Commandé - Reçu - Facturé
  -- On exclut seulement les statuts vraiment terminés
  SUM(
    CASE 
      -- Exclure seulement les pièces vraiment reçues ou annulées
      WHEN LOWER(TRIM(COALESCE(p.status, ''))) IN ('received', 'cancelled')
        OR LOWER(TRIM(COALESCE(p.comments, ''))) = 'delivery completed'
      THEN 0
      -- Sinon, calculer la quantité en transit
      ELSE GREATEST(0, 
        COALESCE(p.quantity_requested, 0) - 
        COALESCE(p.qty_received_irium, 0) - 
        COALESCE(p.invoice_quantity, 0)
      )
    END
  ) as quantity_in_transit,
  -- Quantité facturée mais non reçue = Facturé - Reçu
  SUM(
    CASE 
      -- Exclure seulement les pièces vraiment reçues ou annulées
      WHEN LOWER(TRIM(COALESCE(p.status, ''))) IN ('received', 'cancelled')
        OR LOWER(TRIM(COALESCE(p.comments, ''))) = 'delivery completed'
      THEN 0
      -- Sinon, calculer la quantité facturée en attente de réception
      ELSE GREATEST(0, 
        COALESCE(p.invoice_quantity, 0) - 
        COALESCE(p.qty_received_irium, 0)
      )
    END
  ) as quantity_invoiced
FROM project_supplier_orders pso
JOIN parts p ON p.supplier_order = pso.supplier_order
WHERE p.part_ordered IS NOT NULL
  AND p.part_ordered != ''
GROUP BY pso.project_id, p.part_ordered;

-- Créer les index pour la performance
CREATE UNIQUE INDEX idx_mv_transit_unique ON mv_project_parts_transit_invoiced(project_id, part_number);
CREATE INDEX idx_mv_transit_project ON mv_project_parts_transit_invoiced(project_id);
CREATE INDEX idx_mv_transit_part ON mv_project_parts_transit_invoiced(part_number);

DO $$
BEGIN
    RAISE NOTICE '✅ Vue créée avec succès';
    RAISE NOTICE '';
    
    -- Étape 3: Recréer la vue principale mv_project_analytics_complete
    RAISE NOTICE '🔄 Étape 3: Recréation de mv_project_analytics_complete...';
    DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;
END $$;

-- Recréer la vue principale avec la nouvelle logique
CREATE MATERIALIZED VIEW mv_project_analytics_complete AS
WITH machine_chronology AS (
  SELECT
    pm.id as machine_id,
    pm.project_id,
    pm.name as machine_name,
    pm.created_at,
    ROW_NUMBER() OVER (PARTITION BY pm.project_id ORDER BY pm.created_at, pm.id) as creation_rank
  FROM project_machines pm
),
parts_with_requirements AS (
  SELECT
    mc.machine_id,
    mc.project_id,
    mc.machine_name,
    mc.creation_rank,
    mc.created_at,
    pmp.part_number,
    pmp.description,
    pmp.quantity_required
  FROM mv_project_machine_parts_aggregated pmp
  JOIN machine_chronology mc ON mc.machine_id = pmp.machine_id
),
global_resources AS (
  SELECT
    pwr.project_id,
    pwr.part_number,
    COALESCE(stock.quantity_available, 0) as total_stock_available,
    COALESCE(used.quantity_used_project_total, 0) as total_used,
    COALESCE(transit.quantity_in_transit, 0) as total_in_transit,
    COALESCE(transit.quantity_invoiced, 0) as total_invoiced
  FROM (SELECT DISTINCT project_id, part_number FROM parts_with_requirements) pwr
  LEFT JOIN mv_project_parts_stock_availability stock 
    ON stock.project_id = pwr.project_id AND stock.part_number = pwr.part_number
  LEFT JOIN (
    SELECT project_id, part_number, SUM(quantity_used) as quantity_used_project_total
    FROM mv_project_parts_used_quantities_enhanced
    GROUP BY project_id, part_number
  ) used ON used.project_id = pwr.project_id AND used.part_number = pwr.part_number
  LEFT JOIN mv_project_parts_transit_invoiced transit 
    ON transit.project_id = pwr.project_id AND transit.part_number = pwr.part_number
),
progressive_allocation AS (
  SELECT
    pwr.machine_id,
    pwr.project_id,
    pwr.machine_name,
    pwr.creation_rank,
    pwr.part_number,
    pwr.description,
    pwr.quantity_required,
    gr.total_stock_available,
    COALESCE(used_machine.quantity_used, 0) as quantity_used,
    gr.total_in_transit,
    gr.total_invoiced,
    GREATEST(0,
      gr.total_stock_available - 
      COALESCE(SUM(pwr_earlier.quantity_required) OVER (
        PARTITION BY pwr.project_id, pwr.part_number 
        ORDER BY pwr.creation_rank
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
      ), 0)
    ) as quantity_available_for_this_machine
  FROM parts_with_requirements pwr
  LEFT JOIN parts_with_requirements pwr_earlier 
    ON pwr_earlier.project_id = pwr.project_id 
    AND pwr_earlier.part_number = pwr.part_number 
    AND pwr_earlier.creation_rank < pwr.creation_rank
  LEFT JOIN global_resources gr 
    ON gr.project_id = pwr.project_id AND gr.part_number = pwr.part_number
  LEFT JOIN mv_project_parts_used_quantities_enhanced used_machine 
    ON used_machine.machine_id = pwr.machine_id AND used_machine.part_number = pwr.part_number
)
SELECT 
  pa.project_id,
  pa.machine_id,
  pa.machine_name,
  pa.part_number,
  pa.description,
  pa.quantity_required,
  LEAST(pa.quantity_available_for_this_machine, pa.quantity_required) as quantity_available,
  pa.quantity_used,
  pa.total_in_transit as quantity_in_transit,
  pa.total_invoiced as quantity_invoiced,
  GREATEST(0, 
    pa.quantity_required - 
    LEAST(pa.quantity_available_for_this_machine, pa.quantity_required) - 
    pa.quantity_used - 
    pa.total_in_transit - 
    pa.total_invoiced
  ) as quantity_missing,
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pa.project_id
      AND p.part_ordered = pa.part_number
      AND LOWER(TRIM(COALESCE(p.status, ''))) NOT IN ('received', 'cancelled')
      AND LOWER(TRIM(COALESCE(p.comments, ''))) != 'delivery completed'
      AND p.eta IS NOT NULL
      AND TRIM(p.eta) != ''
      AND LENGTH(TRIM(p.eta)) >= 5
  ) as latest_eta
FROM progressive_allocation pa;

-- Créer les index
CREATE INDEX IF NOT EXISTS idx_mv_analytics_project ON mv_project_analytics_complete(project_id);
CREATE INDEX IF NOT EXISTS idx_mv_analytics_machine ON mv_project_analytics_complete(machine_id);
CREATE INDEX IF NOT EXISTS idx_mv_analytics_part ON mv_project_analytics_complete(part_number);

DO $$
DECLARE
    rec RECORD;
    test_count INTEGER;
BEGIN
    RAISE NOTICE '✅ Vue principale créée avec succès';
    RAISE NOTICE '';
    
    -- Étape 4: Vérification
    RAISE NOTICE '🔍 Étape 4: Vérification des résultats...';
    
    -- Compter les pièces avec ETA mais quantités à 0 (AVANT la correction)
    SELECT COUNT(*)
    INTO test_count
    FROM mv_project_analytics_complete
    WHERE latest_eta IS NOT NULL
      AND latest_eta != ''
      AND quantity_in_transit = 0
      AND quantity_invoiced = 0;
    
    RAISE NOTICE '   Pièces avec ETA mais qtés à 0: %', test_count;
    
    -- Afficher quelques exemples de correction
    RAISE NOTICE '';
    RAISE NOTICE '📊 Exemples de pièces avec ETA et leurs quantités:';
    
    FOR rec IN
        SELECT 
            project_id,
            machine_name,
            part_number,
            quantity_in_transit,
            quantity_invoiced,
            latest_eta
        FROM mv_project_analytics_complete
        WHERE latest_eta IS NOT NULL
          AND latest_eta != ''
        ORDER BY quantity_in_transit DESC, quantity_invoiced DESC
        LIMIT 5
    LOOP
        RAISE NOTICE '   Machine: % | Part: % | In Transit: % | Invoiced: % | ETA: %',
            rec.machine_name,
            rec.part_number,
            rec.quantity_in_transit,
            rec.quantity_invoiced,
            rec.latest_eta;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== CORRECTION TERMINÉE AVEC SUCCÈS ===';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Changements apportés:';
    RAISE NOTICE '   1. Logique de filtrage assouplie dans mv_project_parts_transit_invoiced';
    RAISE NOTICE '   2. Utilisation de LOWER(TRIM()) pour comparaison des status/comments';
    RAISE NOTICE '   3. Exclusion seulement des pièces vraiment reçues ou annulées';
    RAISE NOTICE '   4. Calcul plus robuste des quantités en transit et facturées';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Vous pouvez maintenant actualiser l''interface pour voir les changements';
    
END $$;

