-- RafraÃ®chir toutes les vues matÃ©rialisÃ©es dans le bon ordre
-- ExÃ©cutez ce script APRÃˆS avoir appliquÃ© la migration

-- Ã‰tape 1 : RafraÃ®chir les vues de base
REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_otc;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced;
REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;

-- Ã‰tape 2 : RafraÃ®chir la vue finale
REFRESH MATERIALIZED VIEW mv_project_analytics_complete;

-- VÃ©rification : Compter les lignes dans chaque vue
SELECT 
  'mv_project_machine_parts_aggregated' as view_name,
  COUNT(*) as row_count
FROM mv_project_machine_parts_aggregated
UNION ALL
SELECT 
  'mv_project_parts_used_quantities',
  COUNT(*)
FROM mv_project_parts_used_quantities
UNION ALL
SELECT 
  'mv_project_parts_used_quantities_otc',
  COUNT(*)
FROM mv_project_parts_used_quantities_otc
UNION ALL
SELECT 
  'mv_project_parts_used_quantities_enhanced',
  COUNT(*)
FROM mv_project_parts_used_quantities_enhanced
UNION ALL
SELECT 
  'mv_project_parts_transit_invoiced',
  COUNT(*)
FROM mv_project_parts_transit_invoiced
UNION ALL
SELECT 
  'mv_project_parts_stock_availability',
  COUNT(*)
FROM mv_project_parts_stock_availability
UNION ALL
SELECT 
  'mv_project_analytics_complete',
  COUNT(*)
FROM mv_project_analytics_complete;
