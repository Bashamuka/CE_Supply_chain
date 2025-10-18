-- Script de correction simplifié pour l'allocation progressive
-- Problème: La logique complexe ne fonctionne pas, les quantités affichent 0
-- Solution: Logique d'allocation progressive simplifiée et robuste

DO $$
BEGIN
    RAISE NOTICE '=== CORRECTION SIMPLIFIÉE DE L''ALLOCATION PROGRESSIVE ===';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Suppression de l''ancienne vue mv_project_analytics_complete...';
    
    -- Supprimer l'ancienne vue principale
    DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;
    
    RAISE NOTICE '✅ Vue supprimée';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Création de la nouvelle vue avec logique simplifiée...';
END $$;

-- Créer la vue principale avec allocation progressive simplifiée
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
    -- Allocation progressive du stock disponible (logique existante qui fonctionne)
    GREATEST(0,
      gr.total_stock_available - 
      COALESCE(SUM(pwr_earlier.quantity_required) OVER (
        PARTITION BY pwr.project_id, pwr.part_number 
        ORDER BY pwr.creation_rank
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
      ), 0)
    ) as quantity_available_for_this_machine,
    -- Allocation progressive des quantités en transit (logique simplifiée)
    CASE 
      WHEN gr.total_in_transit > 0 THEN
        LEAST(
          pwr.quantity_required,
          GREATEST(0, 
            gr.total_in_transit - 
            COALESCE(SUM(pwr_earlier.quantity_required) OVER (
              PARTITION BY pwr.project_id, pwr.part_number 
              ORDER BY pwr.creation_rank
              ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ), 0)
          )
        )
      ELSE 0
    END as quantity_in_transit_for_this_machine,
    -- Allocation progressive des quantités facturées (logique simplifiée)
    CASE 
      WHEN gr.total_invoiced > 0 THEN
        LEAST(
          pwr.quantity_required,
          GREATEST(0, 
            gr.total_invoiced - 
            COALESCE(SUM(pwr_earlier.quantity_required) OVER (
              PARTITION BY pwr.project_id, pwr.part_number 
              ORDER BY pwr.creation_rank
              ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ), 0)
          )
        )
      ELSE 0
    END as quantity_invoiced_for_this_machine
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
  pa.quantity_in_transit_for_this_machine as quantity_in_transit,
  pa.quantity_invoiced_for_this_machine as quantity_invoiced,
  GREATEST(0, 
    pa.quantity_required - 
    LEAST(pa.quantity_available_for_this_machine, pa.quantity_required) - 
    pa.quantity_used - 
    pa.quantity_in_transit_for_this_machine - 
    pa.quantity_invoiced_for_this_machine
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
    test_project_id UUID;
    test_part_number TEXT;
    total_transit_shown INTEGER;
    machine_count INTEGER;
    sum_transit INTEGER;
    sum_invoiced INTEGER;
    total_transit_available INTEGER;
    total_invoiced_available INTEGER;
BEGIN
    RAISE NOTICE '✅ Vue créée avec allocation progressive simplifiée';
    RAISE NOTICE '';
    RAISE NOTICE '=== VÉRIFICATION DE L''ALLOCATION PROGRESSIVE ===';
    RAISE NOTICE '';
    
    -- Trouver un exemple avec plusieurs machines pour la même pièce
    SELECT 
        project_id,
        part_number,
        SUM(quantity_in_transit) as total_transit_shown,
        COUNT(*) as machine_count
    INTO test_project_id, test_part_number, total_transit_shown, machine_count
    FROM mv_project_analytics_complete
    WHERE quantity_in_transit > 0
    GROUP BY project_id, part_number
    HAVING COUNT(*) > 1
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '🔍 Exemple trouvé:';
        RAISE NOTICE '   Project ID: %', test_project_id;
        RAISE NOTICE '   Part Number: %', test_part_number;
        RAISE NOTICE '   Total Transit Affiché: %', total_transit_shown;
        RAISE NOTICE '   Nombre de Machines: %', machine_count;
        RAISE NOTICE '';
        
        RAISE NOTICE '📊 Allocation par machine:';
        FOR rec IN
            SELECT 
                machine_name,
                quantity_required,
                quantity_available,
                quantity_used,
                quantity_in_transit,
                quantity_invoiced,
                quantity_missing,
                latest_eta
            FROM mv_project_analytics_complete
            WHERE project_id = test_project_id
              AND part_number = test_part_number
            ORDER BY machine_name
        LOOP
            RAISE NOTICE '   Machine: %', rec.machine_name;
            RAISE NOTICE '      Required: % | Available: % | Used: %', 
                rec.quantity_required, rec.quantity_available, rec.quantity_used;
            RAISE NOTICE '      In Transit: % | Invoiced: % | Missing: %', 
                rec.quantity_in_transit, rec.quantity_invoiced, rec.quantity_missing;
            RAISE NOTICE '      ETA: %', COALESCE(rec.latest_eta, 'N/A');
            RAISE NOTICE '';
        END LOOP;
        
        -- Vérifier la cohérence de l'allocation
        SELECT 
            SUM(quantity_in_transit) as sum_transit,
            SUM(quantity_invoiced) as sum_invoiced
        INTO sum_transit, sum_invoiced
        FROM mv_project_analytics_complete
        WHERE project_id = test_project_id
          AND part_number = test_part_number;
        
        RAISE NOTICE '✅ Vérification de cohérence:';
        RAISE NOTICE '   Somme In Transit: %', sum_transit;
        RAISE NOTICE '   Somme Invoiced: %', sum_invoiced;
        
        -- Récupérer la quantité totale depuis la vue transit
        SELECT 
            quantity_in_transit as total_transit_available,
            quantity_invoiced as total_invoiced_available
        INTO total_transit_available, total_invoiced_available
        FROM mv_project_parts_transit_invoiced
        WHERE project_id = test_project_id
          AND part_number = test_part_number;
        
        RAISE NOTICE '   Total Disponible In Transit: %', total_transit_available;
        RAISE NOTICE '   Total Disponible Invoiced: %', total_invoiced_available;
        
        IF sum_transit <= total_transit_available AND sum_invoiced <= total_invoiced_available THEN
            RAISE NOTICE '✅ Allocation cohérente: Les sommes ne dépassent pas les totaux disponibles';
        ELSE
            RAISE NOTICE '⚠️  Allocation incohérente: Les sommes dépassent les totaux disponibles';
        END IF;
        
    ELSE
        RAISE NOTICE '⚠️  Aucun exemple avec plusieurs machines trouvé';
        
        -- Chercher des exemples avec ETA mais quantités à 0
        RAISE NOTICE '';
        RAISE NOTICE '🔍 Recherche d''exemples avec ETA mais quantités à 0...';
        
        FOR rec IN
            SELECT 
                project_id,
                machine_name,
                part_number,
                quantity_required,
                quantity_available,
                quantity_used,
                quantity_in_transit,
                quantity_invoiced,
                quantity_missing,
                latest_eta
            FROM mv_project_analytics_complete
            WHERE latest_eta IS NOT NULL
              AND latest_eta != ''
              AND quantity_in_transit = 0
              AND quantity_invoiced = 0
            LIMIT 3
        LOOP
            RAISE NOTICE '   Machine: % | Part: %', rec.machine_name, rec.part_number;
            RAISE NOTICE '      Required: % | Available: % | Used: %', 
                rec.quantity_required, rec.quantity_available, rec.quantity_used;
            RAISE NOTICE '      In Transit: % | Invoiced: % | Missing: %', 
                rec.quantity_in_transit, rec.quantity_invoiced, rec.quantity_missing;
            RAISE NOTICE '      ETA: %', rec.latest_eta;
            RAISE NOTICE '';
        END LOOP;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== CORRECTION TERMINÉE ===';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Changements appliqués:';
    RAISE NOTICE '   - Logique d''allocation progressive simplifiée';
    RAISE NOTICE '   - Utilisation de CASE WHEN pour éviter les calculs complexes';
    RAISE NOTICE '   - Allocation basée sur l''ordre de création des machines';
    RAISE NOTICE '   - Vérification des quantités disponibles avant allocation';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Exemple: Si 20 pièces en transit et 2 machines (besoins 7 et 6):';
    RAISE NOTICE '   - Machine 1: MIN(7, 20) = 7 pièces en transit';
    RAISE NOTICE '   - Machine 2: MIN(6, 20-7) = 6 pièces en transit';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Actualisez l''interface pour voir les changements';
    
END $$;

