-- Script robuste pour corriger le problème des analytics à 0% pour les nouvelles machines
-- Version corrigée avec les bons types de données et système de rafraîchissement amélioré

DO $$
DECLARE
    project_id_var UUID;
    machine_count INTEGER;
    analytics_count INTEGER;
    rec RECORD;
    view_refresh_count INTEGER := 0;
    total_refresh_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=== CORRECTION ROBUSTE DES ANALYTICS POUR NOUVELLES MACHINES ===';
    
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
    
    -- Système de rafraîchissement robuste des vues matérialisées
    RAISE NOTICE '🔄 RAFRAÎCHISSEMENT ROBUSTE DES VUES MATÉRIALISÉES...';
    
    -- Liste des vues à rafraîchir dans l'ordre de dépendance
    DECLARE
        views_to_refresh TEXT[] := ARRAY[
            'mv_project_machine_parts_aggregated',
            'mv_project_parts_stock_availability',
            'mv_project_parts_used_quantities_enhanced',
            'mv_project_parts_transit_invoiced',
            'mv_project_analytics_complete'
        ];
        view_name TEXT;
    BEGIN
        FOREACH view_name IN ARRAY views_to_refresh
        LOOP
            BEGIN
                RAISE NOTICE '🔄 Rafraîchissement de %...', view_name;
                EXECUTE format('REFRESH MATERIALIZED VIEW %I', view_name);
                view_refresh_count := view_refresh_count + 1;
                RAISE NOTICE '✅ % rafraîchi avec succès', view_name;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE '❌ Erreur rafraîchissement %: %', view_name, SQLERRM;
            END;
        END LOOP;
        
        total_refresh_count := view_refresh_count;
        RAISE NOTICE '📊 Total des vues rafraîchies: %/%', view_refresh_count, array_length(views_to_refresh, 1);
    END;
    
    -- Vérifier les données dans la vue analytics après rafraîchissement
    SELECT COUNT(*) INTO analytics_count
    FROM mv_project_analytics_complete
    WHERE project_id = project_id_var;
    
    RAISE NOTICE '📊 Nombre d''enregistrements analytics après rafraîchissement: %', analytics_count;
    
    -- Afficher les analytics par machine avec vérification des données
    RAISE NOTICE '📈 Analytics par machine:';
    FOR rec IN 
        SELECT 
            machine_name,
            COUNT(*) as parts_count,
            AVG(quantity_available) as avg_available,
            AVG(quantity_used) as avg_used,
            AVG(quantity_in_transit) as avg_transit,
            AVG(quantity_invoiced) as avg_invoiced,
            AVG(quantity_missing) as avg_missing,
            SUM(quantity_required) as total_required
        FROM mv_project_analytics_complete
        WHERE project_id = project_id_var
        GROUP BY machine_id, machine_name
        ORDER BY machine_name
    LOOP
        RAISE NOTICE '  - %: % pièces, % unités requises', rec.machine_name, rec.parts_count, rec.total_required;
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
    
    -- Diagnostic des problèmes potentiels
    RAISE NOTICE '🔍 DIAGNOSTIC DES PROBLÈMES POTENTIELS:';
    
    -- Vérifier si les données de stock existent
    DECLARE
        stock_count INTEGER;
        orders_count INTEGER;
        parts_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO stock_count
        FROM mv_project_parts_stock_availability
        WHERE project_id = project_id_var;
        
        SELECT COUNT(*) INTO orders_count
        FROM project_supplier_orders
        WHERE project_id = project_id_var;
        
        SELECT COUNT(*) INTO parts_count
        FROM project_machine_parts pmp
        JOIN project_machines pm ON pm.id = pmp.machine_id
        WHERE pm.project_id = project_id_var;
        
        RAISE NOTICE '📊 Données disponibles:';
        RAISE NOTICE '  - Enregistrements de stock: %', stock_count;
        RAISE NOTICE '  - Commandes fournisseur: %', orders_count;
        RAISE NOTICE '  - Pièces de machines: %', parts_count;
        
        IF stock_count = 0 THEN
            RAISE NOTICE '⚠️  ATTENTION: Aucune donnée de stock trouvée';
            RAISE NOTICE '   Cela peut expliquer pourquoi les quantités sont à 0';
        END IF;
        
        IF orders_count = 0 THEN
            RAISE NOTICE '⚠️  ATTENTION: Aucune commande fournisseur trouvée';
            RAISE NOTICE '   Les quantités utilisées et en transit seront à 0';
        END IF;
        
        IF parts_count = 0 THEN
            RAISE NOTICE '❌ ERREUR: Aucune pièce trouvée pour les machines';
            RAISE NOTICE '   Veuillez ajouter des pièces aux machines';
        END IF;
    END;
    
    RAISE NOTICE '=== CORRECTION TERMINÉE ===';
    RAISE NOTICE '✅ Vues rafraîchies: %', total_refresh_count;
    RAISE NOTICE '📊 Enregistrements analytics: %', analytics_count;
    RAISE NOTICE 'Veuillez maintenant rafraîchir la page Project Analytics dans l''application';
    
END $$;
