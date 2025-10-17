-- Script simplifié pour corriger le problème des analytics à 0% pour les nouvelles machines
-- Version corrigée sans erreurs de syntaxe PostgreSQL

DO $$
DECLARE
    project_id_var TEXT;
    machine_count INTEGER;
    analytics_count INTEGER;
    rec RECORD;
BEGIN
    RAISE NOTICE '=== CORRECTION DES ANALYTICS POUR NOUVELLES MACHINES ===';
    
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
    
    -- Lister toutes les machines
    RAISE NOTICE '📋 Machines dans le projet:';
    FOR rec IN 
        SELECT name, created_at, id
        FROM project_machines 
        WHERE project_id = project_id_var 
        ORDER BY created_at
    LOOP
        RAISE NOTICE '  - % (ID: %, Créée: %)', rec.name, rec.id, rec.created_at;
    END LOOP;
    
    -- Vérifier les pièces par machine
    RAISE NOTICE '🔧 Pièces par machine:';
    FOR rec IN 
        SELECT 
            pm.name as machine_name,
            COUNT(pmp.id) as parts_count,
            SUM(pmp.quantity_required) as total_required
        FROM project_machines pm
        LEFT JOIN project_machine_parts pmp ON pmp.machine_id = pm.id
        WHERE pm.project_id = project_id_var
        GROUP BY pm.id, pm.name
        ORDER BY pm.created_at
    LOOP
        RAISE NOTICE '  - %: % pièces, % unités requises', 
            rec.machine_name, rec.parts_count, COALESCE(rec.total_required, 0);
    END LOOP;
    
    -- Forcer le rafraîchissement des vues matérialisées
    RAISE NOTICE '🔄 Rafraîchissement des vues matérialisées...';
    
    BEGIN
        REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
        RAISE NOTICE '✅ mv_project_machine_parts_aggregated rafraîchi';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Erreur rafraîchissement mv_project_machine_parts_aggregated: %', SQLERRM;
    END;
    
    BEGIN
        REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
        RAISE NOTICE '✅ mv_project_parts_stock_availability rafraîchi';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Erreur rafraîchissement mv_project_parts_stock_availability: %', SQLERRM;
    END;
    
    BEGIN
        REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced;
        RAISE NOTICE '✅ mv_project_parts_used_quantities_enhanced rafraîchi';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Erreur rafraîchissement mv_project_parts_used_quantities_enhanced: %', SQLERRM;
    END;
    
    BEGIN
        REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
        RAISE NOTICE '✅ mv_project_parts_transit_invoiced rafraîchi';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Erreur rafraîchissement mv_project_parts_transit_invoiced: %', SQLERRM;
    END;
    
    BEGIN
        REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
        RAISE NOTICE '✅ mv_project_analytics_complete rafraîchi';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Erreur rafraîchissement mv_project_analytics_complete: %', SQLERRM;
    END;
    
    -- Vérifier les données dans la vue analytics après rafraîchissement
    SELECT COUNT(*) INTO analytics_count
    FROM mv_project_analytics_complete
    WHERE project_id = project_id_var;
    
    RAISE NOTICE '📊 Nombre d''enregistrements analytics après rafraîchissement: %', analytics_count;
    
    -- Afficher les analytics par machine
    RAISE NOTICE '📈 Analytics par machine:';
    FOR rec IN 
        SELECT 
            machine_name,
            COUNT(*) as parts_count,
            AVG(quantity_available) as avg_available,
            AVG(quantity_used) as avg_used,
            AVG(quantity_in_transit) as avg_transit,
            AVG(quantity_invoiced) as avg_invoiced,
            AVG(quantity_missing) as avg_missing
        FROM mv_project_analytics_complete
        WHERE project_id = project_id_var
        GROUP BY machine_id, machine_name
        ORDER BY machine_name
    LOOP
        RAISE NOTICE '  - %: % pièces', rec.machine_name, rec.parts_count;
        RAISE NOTICE '    Disponible: %, Utilisé: %, Transit: %, Facturé: %, Manquant: %',
            ROUND(rec.avg_available, 2), ROUND(rec.avg_used, 2), 
            ROUND(rec.avg_transit, 2), ROUND(rec.avg_invoiced, 2), ROUND(rec.avg_missing, 2);
    END LOOP;
    
    -- Vérifier spécifiquement la machine EX08 CAPEX
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
        LIMIT 5
    LOOP
        RAISE NOTICE '  Pièce %: Requis=%, Disponible=%, Utilisé=%, Transit=%, Facturé=%, Manquant=%',
            rec.part_number, rec.quantity_required, rec.quantity_available, 
            rec.quantity_used, rec.quantity_in_transit, rec.quantity_invoiced, rec.quantity_missing;
    END LOOP;
    
    RAISE NOTICE '=== CORRECTION TERMINÉE ===';
    RAISE NOTICE 'Veuillez maintenant rafraîchir la page Project Analytics dans l''application';
    
END $$;
