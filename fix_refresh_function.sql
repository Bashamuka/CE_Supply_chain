-- Script pour corriger la fonction refresh_project_analytics_views
-- Ce script vérifie l'existence de la fonction et la crée si nécessaire

DO $$
BEGIN
    -- Vérifier si la fonction existe
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'refresh_project_analytics_views'
    ) THEN
        RAISE NOTICE 'Fonction refresh_project_analytics_views non trouvée. Création...';
        
        -- Créer la fonction refresh_project_analytics_views
        CREATE OR REPLACE FUNCTION refresh_project_analytics_views()
        RETURNS void
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $$
        BEGIN
            -- Rafraîchir toutes les vues matérialisées dans l'ordre de dépendance
            -- Utiliser CONCURRENTLY quand possible, sinon utiliser le rafraîchissement normal
            
            BEGIN
                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_machine_parts_aggregated;
                RAISE NOTICE 'Rafraîchi mv_project_machine_parts_aggregated';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Échec du rafraîchissement concurrent de mv_project_machine_parts_aggregated, tentative de rafraîchissement normal: %', SQLERRM;
                REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
            END;
            
            BEGIN
                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_stock_availability;
                RAISE NOTICE 'Rafraîchi mv_project_parts_stock_availability';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Échec du rafraîchissement concurrent de mv_project_parts_stock_availability, tentative de rafraîchissement normal: %', SQLERRM;
                REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
            END;
            
            BEGIN
                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities;
                RAISE NOTICE 'Rafraîchi mv_project_parts_used_quantities';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Échec du rafraîchissement concurrent de mv_project_parts_used_quantities, tentative de rafraîchissement normal: %', SQLERRM;
                REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
            END;
            
            BEGIN
                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_otc;
                RAISE NOTICE 'Rafraîchi mv_project_parts_used_quantities_otc';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Échec du rafraîchissement concurrent de mv_project_parts_used_quantities_otc, tentative de rafraîchissement normal: %', SQLERRM;
                REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_otc;
            END;
            
            BEGIN
                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_enhanced;
                RAISE NOTICE 'Rafraîchi mv_project_parts_used_quantities_enhanced';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Échec du rafraîchissement concurrent de mv_project_parts_used_quantities_enhanced, tentative de rafraîchissement normal: %', SQLERRM;
                REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced;
            END;
            
            BEGIN
                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_transit_invoiced;
                RAISE NOTICE 'Rafraîchi mv_project_parts_transit_invoiced';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Échec du rafraîchissement concurrent de mv_project_parts_transit_invoiced, tentative de rafraîchissement normal: %', SQLERRM;
                REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
            END;
            
            BEGIN
                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_analytics_complete;
                RAISE NOTICE 'Rafraîchi mv_project_analytics_complete';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Échec du rafraîchissement concurrent de mv_project_analytics_complete, tentative de rafraîchissement normal: %', SQLERRM;
                REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
            END;
            
            RAISE NOTICE 'Toutes les vues d''analyse de projet ont été rafraîchies avec succès';
        END;
        $$;
        
        RAISE NOTICE 'Fonction refresh_project_analytics_views créée avec succès';
    ELSE
        RAISE NOTICE 'Fonction refresh_project_analytics_views existe déjà';
    END IF;
END $$;

-- Test de la fonction
DO $$
BEGIN
    RAISE NOTICE 'Test de la fonction refresh_project_analytics_views...';
    PERFORM refresh_project_analytics_views();
    RAISE NOTICE 'Test réussi !';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Erreur lors du test: %', SQLERRM;
END $$;
