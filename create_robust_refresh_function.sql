-- Fonction RPC robuste pour rafraîchir les vues analytics
-- Cette fonction peut être appelée depuis l'application pour forcer le rafraîchissement

CREATE OR REPLACE FUNCTION refresh_project_analytics_views_robust(project_uuid UUID DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    refresh_count INTEGER := 0;
    total_views INTEGER := 5;
    view_name TEXT;
    project_exists BOOLEAN := FALSE;
    analytics_count INTEGER := 0;
BEGIN
    -- Vérifier si le projet existe (si un UUID est fourni)
    IF project_uuid IS NOT NULL THEN
        SELECT EXISTS(SELECT 1 FROM projects WHERE id = project_uuid) INTO project_exists;
        IF NOT project_exists THEN
            RETURN json_build_object(
                'success', false,
                'error', 'Project not found',
                'project_id', project_uuid
            );
        END IF;
    END IF;
    
    -- Rafraîchir les vues dans l'ordre de dépendance
    BEGIN
        REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
        refresh_count := refresh_count + 1;
        RAISE NOTICE '✅ mv_project_machine_parts_aggregated rafraîchi';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Erreur mv_project_machine_parts_aggregated: %', SQLERRM;
    END;
    
    BEGIN
        REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
        refresh_count := refresh_count + 1;
        RAISE NOTICE '✅ mv_project_parts_stock_availability rafraîchi';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Erreur mv_project_parts_stock_availability: %', SQLERRM;
    END;
    
    BEGIN
        REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced;
        refresh_count := refresh_count + 1;
        RAISE NOTICE '✅ mv_project_parts_used_quantities_enhanced rafraîchi';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Erreur mv_project_parts_used_quantities_enhanced: %', SQLERRM;
    END;
    
    BEGIN
        REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
        refresh_count := refresh_count + 1;
        RAISE NOTICE '✅ mv_project_parts_transit_invoiced rafraîchi';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Erreur mv_project_parts_transit_invoiced: %', SQLERRM;
    END;
    
    BEGIN
        REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
        refresh_count := refresh_count + 1;
        RAISE NOTICE '✅ mv_project_analytics_complete rafraîchi';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Erreur mv_project_analytics_complete: %', SQLERRM;
    END;
    
    -- Compter les enregistrements analytics (si un projet est spécifié)
    IF project_uuid IS NOT NULL THEN
        SELECT COUNT(*) INTO analytics_count
        FROM mv_project_analytics_complete
        WHERE project_id = project_uuid;
    ELSE
        SELECT COUNT(*) INTO analytics_count
        FROM mv_project_analytics_complete;
    END IF;
    
    -- Retourner le résultat
    result := json_build_object(
        'success', true,
        'views_refreshed', refresh_count,
        'total_views', total_views,
        'analytics_records', analytics_count,
        'project_id', project_uuid,
        'timestamp', NOW()
    );
    
    RETURN result;
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM,
        'views_refreshed', refresh_count,
        'total_views', total_views,
        'timestamp', NOW()
    );
END;
$$;
