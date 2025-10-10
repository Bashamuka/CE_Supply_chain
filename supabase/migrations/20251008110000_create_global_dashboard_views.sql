/*
  # Create Global Dashboard Materialized Views

  1. New Materialized Views
    - `global_eta_tracking_stats` - Aggregated statistics for ETA tracking
    - `global_stock_stats` - Aggregated statistics for stock availability
    - `global_orders_stats` - Aggregated statistics for orders movement
    - `global_projects_stats` - Aggregated statistics for projects
    - `global_dealer_planning_stats` - Aggregated statistics for dealer forward planning

  2. Purpose
    - Optimize performance of Global Dashboard by pre-computing statistics
    - Reduce query latency from multiple seconds to milliseconds
    - Provide real-time overview without heavy computation

  3. Refresh Strategy
    - Views are refreshed automatically via triggers on data changes
    - Manual refresh function also available for scheduled updates
*/

-- Drop existing views if they exist
DROP MATERIALIZED VIEW IF EXISTS global_eta_tracking_stats CASCADE;
DROP MATERIALIZED VIEW IF EXISTS global_stock_stats CASCADE;
DROP MATERIALIZED VIEW IF EXISTS global_orders_stats CASCADE;
DROP MATERIALIZED VIEW IF EXISTS global_projects_stats CASCADE;
DROP MATERIALIZED VIEW IF EXISTS global_dealer_planning_stats CASCADE;

-- Create materialized view for ETA tracking statistics
CREATE MATERIALIZED VIEW global_eta_tracking_stats AS
SELECT
  COUNT(*) as total_parts,
  COUNT(*) FILTER (WHERE status NOT IN ('Delivered', 'Closed')) as pending_orders,
  COUNT(*) FILTER (WHERE status IN ('Delivered', 'Closed')) as delivered_parts,
  COUNT(*) FILTER (
    WHERE status NOT IN ('Delivered', 'Closed')
    AND eta IS NOT NULL
    AND eta != ''
    AND LENGTH(eta) = 10
    AND TO_DATE(eta, 'DD/MM/YYYY') < CURRENT_DATE
  ) as delayed_etas
FROM parts;

-- Create index for faster refresh
CREATE UNIQUE INDEX idx_global_eta_tracking_stats_unique ON global_eta_tracking_stats ((1));

-- Create materialized view for stock availability statistics
CREATE MATERIALIZED VIEW global_stock_stats AS
SELECT
  COUNT(*) as total_part_numbers,
  COALESCE(SUM(
    COALESCE(qté_gdc, 0) + COALESCE(qté_jdc, 0) + COALESCE(qté_cat_network, 0) +
    COALESCE(qté_succ_10, 0) + COALESCE(qté_succ_20, 0) + COALESCE(qté_succ_11, 0) +
    COALESCE(qté_succ_12, 0) + COALESCE(qté_succ_13, 0) + COALESCE(qté_succ_14, 0) +
    COALESCE(qté_succ_19, 0) + COALESCE(qté_succ_21, 0) + COALESCE(qté_succ_22, 0) +
    COALESCE(qté_succ_24, 0) + COALESCE(qté_succ_30, 0) + COALESCE(qté_succ_40, 0) +
    COALESCE(qté_succ_50, 0) + COALESCE(qté_succ_60, 0) + COALESCE(qté_succ_70, 0) +
    COALESCE(qté_succ_80, 0) + COALESCE(qté_succ_90, 0)
  ), 0) as total_quantity,
  COUNT(*) FILTER (
    WHERE (
      COALESCE(qté_gdc, 0) + COALESCE(qté_jdc, 0) + COALESCE(qté_cat_network, 0) +
      COALESCE(qté_succ_10, 0) + COALESCE(qté_succ_20, 0) + COALESCE(qté_succ_11, 0) +
      COALESCE(qté_succ_12, 0) + COALESCE(qté_succ_13, 0) + COALESCE(qté_succ_14, 0) +
      COALESCE(qté_succ_19, 0) + COALESCE(qté_succ_21, 0) + COALESCE(qté_succ_22, 0) +
      COALESCE(qté_succ_24, 0) + COALESCE(qté_succ_30, 0) + COALESCE(qté_succ_40, 0) +
      COALESCE(qté_succ_50, 0) + COALESCE(qté_succ_60, 0) + COALESCE(qté_succ_70, 0) +
      COALESCE(qté_succ_80, 0) + COALESCE(qté_succ_90, 0)
    ) > 0 AND (
      COALESCE(qté_gdc, 0) + COALESCE(qté_jdc, 0) + COALESCE(qté_cat_network, 0) +
      COALESCE(qté_succ_10, 0) + COALESCE(qté_succ_20, 0) + COALESCE(qté_succ_11, 0) +
      COALESCE(qté_succ_12, 0) + COALESCE(qté_succ_13, 0) + COALESCE(qté_succ_14, 0) +
      COALESCE(qté_succ_19, 0) + COALESCE(qté_succ_21, 0) + COALESCE(qté_succ_22, 0) +
      COALESCE(qté_succ_24, 0) + COALESCE(qté_succ_30, 0) + COALESCE(qté_succ_40, 0) +
      COALESCE(qté_succ_50, 0) + COALESCE(qté_succ_60, 0) + COALESCE(qté_succ_70, 0) +
      COALESCE(qté_succ_80, 0) + COALESCE(qté_succ_90, 0)
    ) <= 5
  ) as low_stock,
  COUNT(*) FILTER (
    WHERE (
      COALESCE(qté_gdc, 0) + COALESCE(qté_jdc, 0) + COALESCE(qté_cat_network, 0) +
      COALESCE(qté_succ_10, 0) + COALESCE(qté_succ_20, 0) + COALESCE(qté_succ_11, 0) +
      COALESCE(qté_succ_12, 0) + COALESCE(qté_succ_13, 0) + COALESCE(qté_succ_14, 0) +
      COALESCE(qté_succ_19, 0) + COALESCE(qté_succ_21, 0) + COALESCE(qté_succ_22, 0) +
      COALESCE(qté_succ_24, 0) + COALESCE(qté_succ_30, 0) + COALESCE(qté_succ_40, 0) +
      COALESCE(qté_succ_50, 0) + COALESCE(qté_succ_60, 0) + COALESCE(qté_succ_70, 0) +
      COALESCE(qté_succ_80, 0) + COALESCE(qté_succ_90, 0)
    ) = 0
  ) as out_of_stock
FROM stock_dispo;

-- Create index for faster refresh
CREATE UNIQUE INDEX idx_global_stock_stats_unique ON global_stock_stats ((1));

-- Create materialized view for orders statistics
CREATE MATERIALIZED VIEW global_orders_stats AS
SELECT
  COUNT(*) as total_orders,
  COUNT(DISTINCT constructeur) as active_constructors,
  COALESCE(SUM(qte_commandee), 0) as total_ordered,
  COALESCE(SUM(qte_livree), 0) as total_delivered,
  CASE
    WHEN COALESCE(SUM(qte_commandee), 0) > 0
    THEN (COALESCE(SUM(qte_livree), 0)::numeric / COALESCE(SUM(qte_commandee), 1)::numeric * 100)
    ELSE 0
  END as delivery_rate
FROM orders;

-- Create index for faster refresh
CREATE UNIQUE INDEX idx_global_orders_stats_unique ON global_orders_stats ((1));

-- Create materialized view for projects statistics
CREATE MATERIALIZED VIEW global_projects_stats AS
SELECT
  (SELECT COUNT(*) FROM projects) as total_projects,
  (SELECT COUNT(*) FROM projects WHERE status = 'active') as active_projects,
  (SELECT COUNT(*) FROM project_machines) as total_machines
FROM (SELECT 1) as dummy;

-- Create index for faster refresh
CREATE UNIQUE INDEX idx_global_projects_stats_unique ON global_projects_stats ((1));

-- Create materialized view for dealer forward planning statistics
CREATE MATERIALIZED VIEW global_dealer_planning_stats AS
SELECT
  COALESCE(SUM(forecast_quantity), 0) as total_forecast,
  COUNT(DISTINCT part_number) as unique_parts
FROM dealer_forward_planning;

-- Create index for faster refresh
CREATE UNIQUE INDEX idx_global_dealer_planning_stats_unique ON global_dealer_planning_stats ((1));

-- Create function to refresh all global dashboard views
CREATE OR REPLACE FUNCTION refresh_global_dashboard_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY global_eta_tracking_stats;
  REFRESH MATERIALIZED VIEW CONCURRENTLY global_stock_stats;
  REFRESH MATERIALIZED VIEW CONCURRENTLY global_orders_stats;
  REFRESH MATERIALIZED VIEW CONCURRENTLY global_projects_stats;
  REFRESH MATERIALIZED VIEW CONCURRENTLY global_dealer_planning_stats;
END;
$$;

-- Grant permissions
GRANT SELECT ON global_eta_tracking_stats TO authenticated;
GRANT SELECT ON global_stock_stats TO authenticated;
GRANT SELECT ON global_orders_stats TO authenticated;
GRANT SELECT ON global_projects_stats TO authenticated;
GRANT SELECT ON global_dealer_planning_stats TO authenticated;

-- Create trigger functions to auto-refresh views on data changes
CREATE OR REPLACE FUNCTION trigger_refresh_eta_tracking_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY global_eta_tracking_stats;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trigger_refresh_stock_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY global_stock_stats;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trigger_refresh_orders_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY global_orders_stats;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trigger_refresh_projects_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY global_projects_stats;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trigger_refresh_dealer_planning_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY global_dealer_planning_stats;
  RETURN NULL;
END;
$$;

-- Create triggers for automatic refresh (after statement to batch updates)
DROP TRIGGER IF EXISTS trigger_parts_stats_refresh ON parts;
CREATE TRIGGER trigger_parts_stats_refresh
  AFTER INSERT OR UPDATE OR DELETE ON parts
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_refresh_eta_tracking_stats();

DROP TRIGGER IF EXISTS trigger_stock_stats_refresh ON stock_dispo;
CREATE TRIGGER trigger_stock_stats_refresh
  AFTER INSERT OR UPDATE OR DELETE ON stock_dispo
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_refresh_stock_stats();

DROP TRIGGER IF EXISTS trigger_orders_stats_refresh ON orders;
CREATE TRIGGER trigger_orders_stats_refresh
  AFTER INSERT OR UPDATE OR DELETE ON orders
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_refresh_orders_stats();

DROP TRIGGER IF EXISTS trigger_projects_stats_refresh ON projects;
CREATE TRIGGER trigger_projects_stats_refresh
  AFTER INSERT OR UPDATE OR DELETE ON projects
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_refresh_projects_stats();

DROP TRIGGER IF EXISTS trigger_machines_stats_refresh ON project_machines;
CREATE TRIGGER trigger_machines_stats_refresh
  AFTER INSERT OR UPDATE OR DELETE ON project_machines
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_refresh_projects_stats();

DROP TRIGGER IF EXISTS trigger_dealer_planning_stats_refresh ON dealer_forward_planning;
CREATE TRIGGER trigger_dealer_planning_stats_refresh
  AFTER INSERT OR UPDATE OR DELETE ON dealer_forward_planning
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_refresh_dealer_planning_stats();

-- Initial refresh of all views
SELECT refresh_global_dashboard_stats();
