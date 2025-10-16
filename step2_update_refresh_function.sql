-- Étape 2: Mettre à jour la fonction de rafraîchissement
CREATE OR REPLACE FUNCTION refresh_project_analytics_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Rafraîchir les vues avec gestion d'erreurs
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_machine_parts_aggregated;
  EXCEPTION WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_stock_availability;
  EXCEPTION WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities;
  EXCEPTION WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_otc;
  EXCEPTION WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_otc;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_enhanced;
  EXCEPTION WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_transit_invoiced;
  EXCEPTION WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
  END;
  
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_analytics_complete;
  EXCEPTION WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
  END;
END;
$$;

-- Accorder les permissions
GRANT EXECUTE ON FUNCTION refresh_project_analytics_views() TO authenticated;

-- Vérification
SELECT 'Fonction de rafraîchissement mise à jour' as status;
