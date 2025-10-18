-- Script de diagnostic pour identifier le problème des quantités en transit et backorder affichant 0
-- Même quand un LatestETA est présent

DO $$
DECLARE
    test_project_id UUID;
    test_part_number TEXT;
    rec RECORD;
BEGIN
    RAISE NOTICE '=== DIAGNOSTIC DES QUANTITÉS EN TRANSIT ET BACKORDER ===';
    RAISE NOTICE '';
    
    -- Sélectionner un projet avec un LatestETA mais des quantités à 0
    SELECT 
        project_id,
        part_number,
        latest_eta,
        quantity_in_transit,
        quantity_invoiced
    INTO test_project_id, test_part_number, rec
    FROM mv_project_analytics_complete
    WHERE latest_eta IS NOT NULL
      AND latest_eta != ''
      AND quantity_in_transit = 0
      AND quantity_invoiced = 0
    LIMIT 1;
    
    IF test_project_id IS NULL THEN
        RAISE NOTICE '✅ Aucun problème détecté: Toutes les pièces avec ETA ont des quantités correctes';
        RETURN;
    END IF;
    
    RAISE NOTICE '🔍 Problème détecté pour:';
    RAISE NOTICE '   Project ID: %', test_project_id;
    RAISE NOTICE '   Part Number: %', test_part_number;
    RAISE NOTICE '   Latest ETA: %', rec.latest_eta;
    RAISE NOTICE '   Qty In Transit: % (devrait être > 0)', rec.quantity_in_transit;
    RAISE NOTICE '   Qty Invoiced: %', rec.quantity_invoiced;
    RAISE NOTICE '';
    
    -- Vérifier les données sources dans la table parts
    RAISE NOTICE '📊 Données sources dans la table parts:';
    FOR rec IN
        SELECT 
            p.id,
            p.part_ordered,
            p.supplier_order,
            p.status,
            p.comments,
            p.quantity_requested,
            p.qty_received_irium,
            p.invoice_quantity,
            p.eta,
            CASE 
                WHEN p.status NOT IN ('Received', 'Cancelled') 
                    AND LOWER(COALESCE(p.comments, '')) != 'delivery completed'
                THEN TRUE
                ELSE FALSE
            END as passes_filter,
            GREATEST(0, COALESCE(p.quantity_requested, 0) - COALESCE(p.qty_received_irium, 0) - COALESCE(p.invoice_quantity, 0)) as calc_in_transit,
            GREATEST(0, COALESCE(p.invoice_quantity, 0) - COALESCE(p.qty_received_irium, 0)) as calc_invoiced
        FROM project_supplier_orders pso
        JOIN parts p ON p.supplier_order = pso.supplier_order
        WHERE pso.project_id = test_project_id
          AND p.part_ordered = test_part_number
        ORDER BY p.eta DESC NULLS LAST
        LIMIT 5
    LOOP
        RAISE NOTICE '';
        RAISE NOTICE '   Part ID: %', rec.id;
        RAISE NOTICE '   Supplier Order: %', rec.supplier_order;
        RAISE NOTICE '   Status: %', rec.status;
        RAISE NOTICE '   Comments: %', COALESCE(rec.comments, 'NULL');
        RAISE NOTICE '   Qty Requested: %', COALESCE(rec.quantity_requested, 0);
        RAISE NOTICE '   Qty Received: %', COALESCE(rec.qty_received_irium, 0);
        RAISE NOTICE '   Qty Invoiced: %', COALESCE(rec.invoice_quantity, 0);
        RAISE NOTICE '   ETA: %', COALESCE(rec.eta, 'NULL');
        RAISE NOTICE '   ✓ Passes Filter: %', rec.passes_filter;
        RAISE NOTICE '   ➜ Calculated In Transit: %', rec.calc_in_transit;
        RAISE NOTICE '   ➜ Calculated Invoiced: %', rec.calc_invoiced;
    END LOOP;
    RAISE NOTICE '';
    
    -- Vérifier la vue matérialisée mv_project_parts_transit_invoiced
    RAISE NOTICE '📊 Données dans mv_project_parts_transit_invoiced:';
    SELECT 
        quantity_in_transit,
        quantity_invoiced
    INTO rec
    FROM mv_project_parts_transit_invoiced
    WHERE project_id = test_project_id
      AND part_number = test_part_number;
    
    IF FOUND THEN
        RAISE NOTICE '   Qty In Transit: %', rec.quantity_in_transit;
        RAISE NOTICE '   Qty Invoiced: %', rec.quantity_invoiced;
    ELSE
        RAISE NOTICE '   ⚠️  Aucune entrée trouvée dans mv_project_parts_transit_invoiced';
    END IF;
    RAISE NOTICE '';
    
    -- Analyser tous les status possibles pour ce projet
    RAISE NOTICE '📊 Distribution des statuts pour ce projet:';
    FOR rec IN
        SELECT 
            p.status,
            LOWER(COALESCE(p.comments, '')) as comments_lower,
            COUNT(*) as count,
            SUM(COALESCE(p.quantity_requested, 0)) as total_requested,
            SUM(COALESCE(p.qty_received_irium, 0)) as total_received,
            SUM(COALESCE(p.invoice_quantity, 0)) as total_invoiced
        FROM project_supplier_orders pso
        JOIN parts p ON p.supplier_order = pso.supplier_order
        WHERE pso.project_id = test_project_id
          AND p.part_ordered = test_part_number
        GROUP BY p.status, LOWER(COALESCE(p.comments, ''))
        ORDER BY count DESC
    LOOP
        RAISE NOTICE '   Status: "%" | Comments: "%" | Count: % | Requested: % | Received: % | Invoiced: %', 
            COALESCE(rec.status, 'NULL'),
            COALESCE(rec.comments_lower, 'NULL'),
            rec.count,
            rec.total_requested,
            rec.total_received,
            rec.total_invoiced;
    END LOOP;
    RAISE NOTICE '';
    
    RAISE NOTICE '=== ANALYSE TERMINÉE ===';
    RAISE NOTICE '';
    RAISE NOTICE '💡 RECOMMANDATIONS:';
    RAISE NOTICE '   1. Vérifier si le problème vient du filtre status NOT IN (''Received'', ''Cancelled'')';
    RAISE NOTICE '   2. Vérifier si le problème vient du filtre comments != ''delivery completed''';
    RAISE NOTICE '   3. Vérifier si les colonnes quantity_requested, qty_received_irium, invoice_quantity sont remplies';
    RAISE NOTICE '   4. Considérer d''assouplir les conditions de filtrage';
    
END $$;

