-- Script pour créer un trigger automatique de rafraîchissement des analytics
-- Ce script s'assure que les analytics sont mis à jour automatiquement quand une nouvelle machine est ajoutée

DO $$
BEGIN
    RAISE NOTICE '=== CRÉATION DU TRIGGER AUTOMATIQUE POUR LES ANALYTICS ===';
    
    -- Créer une fonction pour rafraîchir les vues analytics
    CREATE OR REPLACE FUNCTION refresh_analytics_on_machine_change()
    RETURNS TRIGGER AS $$
    BEGIN
        RAISE NOTICE 'Trigger activé: Rafraîchissement des analytics...';
        
        -- Rafraîchir les vues matérialisées dans l'ordre de dépendance
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
        
        RAISE NOTICE '✅ Rafraîchissement des analytics terminé';
        
        RETURN COALESCE(NEW, OLD);
    END;
    $$ LANGUAGE plpgsql;
    
    -- Supprimer les anciens triggers s'ils existent
    DROP TRIGGER IF EXISTS trigger_refresh_analytics_on_machine_change ON project_machines;
    DROP TRIGGER IF EXISTS trigger_refresh_analytics_on_machine_parts_change ON project_machine_parts;
    
    -- Créer le trigger sur project_machines
    CREATE TRIGGER trigger_refresh_analytics_on_machine_change
    AFTER INSERT OR UPDATE OR DELETE ON project_machines
    FOR EACH STATEMENT
    EXECUTE FUNCTION refresh_analytics_on_machine_change();
    
    RAISE NOTICE '✅ Trigger créé sur project_machines';
    
    -- Créer le trigger sur project_machine_parts
    CREATE TRIGGER trigger_refresh_analytics_on_machine_parts_change
    AFTER INSERT OR UPDATE OR DELETE ON project_machine_parts
    FOR EACH STATEMENT
    EXECUTE FUNCTION refresh_analytics_on_machine_change();
    
    RAISE NOTICE '✅ Trigger créé sur project_machine_parts';
    
    RAISE NOTICE '=== TRIGGERS AUTOMATIQUES CRÉÉS ===';
    RAISE NOTICE 'Les analytics seront maintenant automatiquement rafraîchis quand:';
    RAISE NOTICE '- Une nouvelle machine est ajoutée';
    RAISE NOTICE '- Une machine est modifiée ou supprimée';
    RAISE NOTICE '- Des pièces sont ajoutées/modifiées/supprimées';
    
END $$;
