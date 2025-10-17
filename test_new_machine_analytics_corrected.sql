-- Script de test simplifié pour vérifier les analytics des nouvelles machines
-- Version corrigée sans erreurs de syntaxe PostgreSQL

DO $$
DECLARE
    project_id_var TEXT;
    machine_count INTEGER;
    analytics_count INTEGER;
    ex08_machine_id TEXT;
    ex08_parts_count INTEGER;
    rec RECORD;
BEGIN
    RAISE NOTICE '=== TEST DES ANALYTICS POUR NOUVELLES MACHINES ===';
    
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
    
    -- Compter les machines dans le projet
    SELECT COUNT(*) INTO machine_count
    FROM project_machines 
    WHERE project_id = project_id_var;
    
    RAISE NOTICE '📊 Nombre de machines dans le projet: %', machine_count;
    
    -- Vérifier spécifiquement la machine EX08 CAPEX
    SELECT id INTO ex08_machine_id
    FROM project_machines 
    WHERE project_id = project_id_var 
    AND name ILIKE '%EX08 CAPEX%'
    LIMIT 1;
    
    IF ex08_machine_id IS NULL THEN
        RAISE NOTICE '❌ Machine EX08 CAPEX non trouvée';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Machine EX08 CAPEX trouvée: %', ex08_machine_id;
    
    -- Compter les pièces de la machine EX08 CAPEX
    SELECT COUNT(*) INTO ex08_parts_count
    FROM project_machine_parts 
    WHERE machine_id = ex08_machine_id;
    
    RAISE NOTICE '🔧 Nombre de pièces pour EX08 CAPEX: %', ex08_parts_count;
    
    IF ex08_parts_count = 0 THEN
        RAISE NOTICE '❌ Aucune pièce trouvée pour EX08 CAPEX';
        RAISE NOTICE 'Veuillez ajouter des pièces à cette machine';
        RETURN;
    END IF;
    
    -- Vérifier les données dans la vue analytics
    SELECT COUNT(*) INTO analytics_count
    FROM mv_project_analytics_complete
    WHERE project_id = project_id_var 
    AND machine_id = ex08_machine_id;
    
    RAISE NOTICE '📊 Nombre d''enregistrements analytics pour EX08 CAPEX: %', analytics_count;
    
    IF analytics_count = 0 THEN
        RAISE NOTICE '❌ Aucune donnée analytics trouvée pour EX08 CAPEX';
        RAISE NOTICE 'Les vues matérialisées doivent être rafraîchies';
        
        -- Rafraîchir les vues
        RAISE NOTICE '🔄 Rafraîchissement des vues...';
        REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
        REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
        REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced;
        REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
        REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
        
        -- Recompter après rafraîchissement
        SELECT COUNT(*) INTO analytics_count
        FROM mv_project_analytics_complete
        WHERE project_id = project_id_var 
        AND machine_id = ex08_machine_id;
        
        RAISE NOTICE '📊 Nombre d''enregistrements analytics après rafraîchissement: %', analytics_count;
    END IF;
    
    -- Afficher les analytics détaillés pour EX08 CAPEX
    RAISE NOTICE '📈 Analytics détaillés pour EX08 CAPEX:';
    FOR rec IN 
        SELECT 
            part_number,
            quantity_required,
            quantity_available,
            quantity_used,
            quantity_in_transit,
            quantity_invoiced,
            quantity_missing,
            latest_eta
        FROM mv_project_analytics_complete
        WHERE project_id = project_id_var 
        AND machine_id = ex08_machine_id
        ORDER BY part_number
        LIMIT 10
    LOOP
        RAISE NOTICE '  Pièce %: Requis=%, Disponible=%, Utilisé=%, Transit=%, Facturé=%, Manquant=%, ETA=%',
            rec.part_number, rec.quantity_required, rec.quantity_available, 
            rec.quantity_used, rec.quantity_in_transit, rec.quantity_invoiced, 
            rec.quantity_missing, COALESCE(rec.latest_eta, 'N/A');
    END LOOP;
    
    -- Calculer les pourcentages moyens pour EX08 CAPEX
    RAISE NOTICE '📊 Pourcentages moyens pour EX08 CAPEX:';
    FOR rec IN 
        SELECT 
            AVG(CASE WHEN quantity_required > 0 THEN (quantity_available / quantity_required) * 100 ELSE 0 END) as avg_availability,
            AVG(CASE WHEN quantity_required > 0 THEN (quantity_used / quantity_required) * 100 ELSE 0 END) as avg_usage,
            AVG(CASE WHEN quantity_required > 0 THEN (quantity_in_transit / quantity_required) * 100 ELSE 0 END) as avg_transit,
            AVG(CASE WHEN quantity_required > 0 THEN (quantity_invoiced / quantity_required) * 100 ELSE 0 END) as avg_invoiced,
            AVG(CASE WHEN quantity_required > 0 THEN (quantity_missing / quantity_required) * 100 ELSE 0 END) as avg_missing
        FROM mv_project_analytics_complete
        WHERE project_id = project_id_var 
        AND machine_id = ex08_machine_id
    LOOP
        RAISE NOTICE '  Disponibilité: %%%', ROUND(rec.avg_availability, 1);
        RAISE NOTICE '  Utilisation: %%%', ROUND(rec.avg_usage, 1);
        RAISE NOTICE '  Transit: %%%', ROUND(rec.avg_transit, 1);
        RAISE NOTICE '  Facturé: %%%', ROUND(rec.avg_invoiced, 1);
        RAISE NOTICE '  Manquant: %%%', ROUND(rec.avg_missing, 1);
    END LOOP;
    
    RAISE NOTICE '=== TEST TERMINÉ ===';
    
END $$;
