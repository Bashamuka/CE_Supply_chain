-- Script de correction pour le filtre status dans mv_project_parts_transit_invoiced
-- Problème: Les quantités affichent 0 car la logique exclut 'Received' 
-- Solution: Exclure UNIQUEMENT 'Cancelled' et 'Griefed'

DO $$
BEGIN
    RAISE NOTICE '=== CORRECTION DU FILTRE STATUS ===';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Suppression de l''ancienne vue mv_project_parts_transit_invoiced...';
    
    -- Supprimer l'ancienne vue
    DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_transit_invoiced CASCADE;
    
    RAISE NOTICE '✅ Vue supprimée';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Création de la nouvelle vue avec le filtre corrigé...';
END $$;

-- Créer la vue avec le filtre status corrigé
CREATE MATERIALIZED VIEW mv_project_parts_transit_invoiced AS
SELECT 
  pso.project_id,
  p.part_ordered as part_number,
  -- Quantité en transit (Backorder) = Commandé - Reçu - Facturé
  -- Exclure UNIQUEMENT status 'Cancelled' et 'Griefed'
  SUM(
    CASE 
      WHEN LOWER(TRIM(COALESCE(p.status, ''))) IN ('cancelled', 'griefed')
        OR LOWER(TRIM(COALESCE(p.comments, ''))) = 'delivery completed'
      THEN 0
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
      WHEN LOWER(TRIM(COALESCE(p.status, ''))) IN ('cancelled', 'griefed')
        OR LOWER(TRIM(COALESCE(p.comments, ''))) = 'delivery completed'
      THEN 0
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
    RAISE NOTICE '✅ Vue créée avec le filtre status corrigé';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Recréation de mv_project_analytics_complete...';
    
    -- Supprimer l'ancienne vue principale
    DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;
END $$;

-- Recréer la vue principale avec le calcul ETA corrigé également
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
  -- ETA calculation avec le même filtre: exclure UNIQUEMENT 'Cancelled' et 'Griefed'
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = pa.project_id
      AND p.part_ordered = pa.part_number
      AND LOWER(TRIM(COALESCE(p.status, ''))) NOT IN ('cancelled', 'griefed')
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
    total_with_eta INTEGER;
BEGIN
    RAISE NOTICE '✅ Vue principale créée avec succès';
    RAISE NOTICE '';
    RAISE NOTICE '=== VÉRIFICATION DES RÉSULTATS ===';
    RAISE NOTICE '';
    
    -- Compter les pièces avec ETA
    SELECT COUNT(*)
    INTO total_with_eta
    FROM mv_project_analytics_complete
    WHERE latest_eta IS NOT NULL
      AND latest_eta != '';
    
    RAISE NOTICE '📊 Total de pièces avec ETA: %', total_with_eta;
    
    -- Compter les pièces avec ETA mais quantités à 0
    SELECT COUNT(*)
    INTO test_count
    FROM mv_project_analytics_complete
    WHERE latest_eta IS NOT NULL
      AND latest_eta != ''
      AND quantity_in_transit = 0
      AND quantity_invoiced = 0;
    
    RAISE NOTICE '⚠️  Pièces avec ETA mais qtés à 0: %', test_count;
    
    IF test_count = 0 THEN
        RAISE NOTICE '✅ PARFAIT! Toutes les pièces avec ETA ont des quantités correctes';
    ELSE
        RAISE NOTICE '⚠️  Il reste % pièces avec ETA mais quantités à 0', test_count;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Exemples de pièces avec ETA:';
    
    FOR rec IN
        SELECT 
            project_id,
            machine_name,
            part_number,
            quantity_in_transit,
            quantity_invoiced,
            quantity_missing,
            latest_eta
        FROM mv_project_analytics_complete
        WHERE latest_eta IS NOT NULL
          AND latest_eta != ''
        ORDER BY quantity_in_transit DESC, quantity_invoiced DESC
        LIMIT 5
    LOOP
        RAISE NOTICE '   Machine: % | Part: %', rec.machine_name, rec.part_number;
        RAISE NOTICE '      In Transit: % | Invoiced: % | Missing: % | ETA: %',
            rec.quantity_in_transit,
            rec.quantity_invoiced,
            rec.quantity_missing,
            rec.latest_eta;
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '=== CORRECTION TERMINÉE ===';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Changements appliqués:';
    RAISE NOTICE '   - Filtre status corrigé: exclure UNIQUEMENT ''Cancelled'' et ''Griefed''';
    RAISE NOTICE '   - Inclure tous les autres status: NULL, ''Shipped'', ''In Transit'', ''Received'', etc.';
    RAISE NOTICE '   - Filtre comments: exclure ''delivery completed''';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Prochaine étape: Actualisez l''interface pour voir les changements';
    
END $$;

