-- Script de test pour vérifier le système de rafraîchissement robuste
-- Ce script teste la fonction RPC et vérifie les données

DO $$
DECLARE
    project_id_var UUID;
    test_result JSON;
    analytics_count INTEGER;
    rec RECORD;
BEGIN
    RAISE NOTICE '=== TEST DU SYSTÈME DE RAFRAÎCHISSEMENT ROBUSTE ===';
    
    -- Identifier le projet CAPEX MUMI PROJECT
    SELECT id INTO project_id_var 
    FROM projects 
    WHERE name ILIKE '%CAPEX MUMI PROJECT%' 
    LIMIT 1;
    
    IF project_id_var IS NULL THEN
        RAISE NOTICE '❌ Projet CAPEX MUMI PROJECT non trouvé';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Projet trouvé: %', project_id_var;
    
    -- Tester la fonction RPC robuste
    RAISE NOTICE '🔄 Test de la fonction RPC robuste...';
    
    BEGIN
        SELECT refresh_project_analytics_views_robust(project_id_var) INTO test_result;
        
        RAISE NOTICE '📊 Résultat de la fonction RPC:';
        RAISE NOTICE '  Success: %', test_result->>'success';
        RAISE NOTICE '  Views refreshed: %', test_result->>'views_refreshed';
        RAISE NOTICE '  Total views: %', test_result->>'total_views';
        RAISE NOTICE '  Analytics records: %', test_result->>'analytics_records';
        
        IF (test_result->>'success')::boolean THEN
            RAISE NOTICE '✅ Fonction RPC exécutée avec succès';
        ELSE
            RAISE NOTICE '❌ Erreur dans la fonction RPC: %', test_result->>'error';
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Erreur lors de l''exécution de la fonction RPC: %', SQLERRM;
    END;
    
    -- Vérifier les données analytics après rafraîchissement
    SELECT COUNT(*) INTO analytics_count
    FROM mv_project_analytics_complete
    WHERE project_id = project_id_var;
    
    RAISE NOTICE '📊 Nombre d''enregistrements analytics: %', analytics_count;
    
    -- Afficher les analytics par machine
    RAISE NOTICE '📈 Analytics par machine après rafraîchissement:';
    FOR rec IN 
        SELECT 
            machine_name,
            COUNT(*) as parts_count,
            SUM(quantity_required) as total_required,
            SUM(quantity_available) as total_available,
            SUM(quantity_used) as total_used,
            SUM(quantity_in_transit) as total_transit,
            SUM(quantity_invoiced) as total_invoiced,
            SUM(quantity_missing) as total_missing
        FROM mv_project_analytics_complete
        WHERE project_id = project_id_var
        GROUP BY machine_id, machine_name
        ORDER BY machine_name
    LOOP
        RAISE NOTICE '  - %: % pièces', rec.machine_name, rec.parts_count;
        RAISE NOTICE '    Requis: %, Disponible: %, Utilisé: %, Transit: %, Facturé: %, Manquant: %',
            rec.total_required, rec.total_available, rec.total_used, 
            rec.total_transit, rec.total_invoiced, rec.total_missing;
        
        -- Vérifier si les quantités sont toutes à 0
        IF rec.total_available = 0 AND rec.total_used = 0 AND rec.total_transit = 0 
           AND rec.total_invoiced = 0 AND rec.total_missing = rec.total_required THEN
            RAISE NOTICE '    ⚠️  ATTENTION: Toutes les quantités sont à 0 ou égales aux quantités requises';
            RAISE NOTICE '    Cela peut indiquer un problème avec les données de base';
        ELSE
            RAISE NOTICE '    ✅ Quantités variées détectées - Analytics fonctionnels';
        END IF;
    END LOOP;
    
    -- Vérifier spécifiquement EX08 CAPEX
    RAISE NOTICE '🔍 Vérification spécifique de EX08 CAPEX:';
    FOR rec IN 
        SELECT 
            part_number,
            quantity_required,
            quantity_available,
            quantity_used,
            quantity_in_transit,
            quantity_invoiced,
            quantity_missing
        FROM mv_project_analytics_complete
        WHERE project_id = project_id_var 
        AND machine_name ILIKE '%EX08 CAPEX%'
        ORDER BY part_number
        LIMIT 3
    LOOP
        RAISE NOTICE '  Pièce %: Requis=%, Disponible=%, Utilisé=%, Transit=%, Facturé=%, Manquant=%',
            rec.part_number, rec.quantity_required, rec.quantity_available, 
            rec.quantity_used, rec.quantity_in_transit, rec.quantity_invoiced, rec.quantity_missing;
    END LOOP;
    
    -- Diagnostic final
    RAISE NOTICE '🔍 DIAGNOSTIC FINAL:';
    
    DECLARE
        zero_quantities_count INTEGER;
        total_parts_count INTEGER;
    BEGIN
        SELECT 
            COUNT(*) FILTER (WHERE quantity_available = 0 AND quantity_used = 0 AND quantity_in_transit = 0),
            COUNT(*)
        INTO zero_quantities_count, total_parts_count
        FROM mv_project_analytics_complete
        WHERE project_id = project_id_var;
        
        RAISE NOTICE '📊 Pièces avec quantités à 0: %/%', zero_quantities_count, total_parts_count;
        
        IF zero_quantities_count = total_parts_count THEN
            RAISE NOTICE '❌ PROBLÈME: Toutes les pièces ont des quantités à 0';
            RAISE NOTICE '   Causes possibles:';
            RAISE NOTICE '   1. Aucune donnée de stock dans la base';
            RAISE NOTICE '   2. Aucune commande fournisseur liée au projet';
            RAISE NOTICE '   3. Problème avec les vues matérialisées';
            RAISE NOTICE '   4. Problème de mapping des données';
        ELSIF zero_quantities_count > total_parts_count * 0.8 THEN
            RAISE NOTICE '⚠️  ATTENTION: Plus de 80%% des pièces ont des quantités à 0';
            RAISE NOTICE '   Vérifiez les données de base et les commandes fournisseur';
        ELSE
            RAISE NOTICE '✅ La plupart des pièces ont des quantités non nulles';
            RAISE NOTICE '   Le système d''analytics fonctionne correctement';
        END IF;
    END;
    
    RAISE NOTICE '=== TEST TERMINÉ ===';
    
END $$;
