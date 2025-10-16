-- Script de test pour le module OTC
-- Vérifie que toutes les fonctionnalités fonctionnent correctement

-- 1. Vérifier que la table OTC existe et a la bonne structure
SELECT 
  'TABLE STRUCTURE CHECK' as test_type,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'otc_orders' 
ORDER BY ordinal_position;

-- 2. Vérifier les données d'exemple
SELECT 
  'SAMPLE DATA CHECK' as test_type,
  COUNT(*) as total_records,
  COUNT(DISTINCT succursale) as unique_branches,
  COUNT(DISTINCT status) as unique_statuses,
  COUNT(DISTINCT num_client) as unique_customers
FROM otc_orders;

-- 3. Vérifier les contraintes et index
SELECT 
  'INDEXES CHECK' as test_type,
  indexname,
  indexdef
FROM pg_indexes 
WHERE tablename = 'otc_orders'
ORDER BY indexname;

-- 4. Tester les vues analytiques
SELECT 
  'ANALYTICS VIEWS CHECK' as test_type,
  'v_otc_analytics' as view_name,
  COUNT(*) as record_count
FROM v_otc_analytics

UNION ALL

SELECT 
  'ANALYTICS VIEWS CHECK' as test_type,
  'v_otc_customer_analytics' as view_name,
  COUNT(*) as record_count
FROM v_otc_customer_analytics

UNION ALL

SELECT 
  'ANALYTICS VIEWS CHECK' as test_type,
  'v_otc_status_tracking' as view_name,
  COUNT(*) as record_count
FROM v_otc_status_tracking;

-- 5. Tester les politiques RLS
SELECT 
  'RLS POLICIES CHECK' as test_type,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'otc_orders';

-- 6. Tester les fonctions
SELECT 
  'FUNCTIONS CHECK' as test_type,
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines 
WHERE routine_name LIKE '%otc%'
ORDER BY routine_name;

-- 7. Tester les triggers
SELECT 
  'TRIGGERS CHECK' as test_type,
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'otc_orders';

-- 8. Vérifier les données de test
SELECT 
  'SAMPLE DATA DETAILS' as test_type,
  succursale,
  num_cde,
  reference,
  designation,
  qte_cde,
  qte_livree,
  solde,
  status,
  nom_clients
FROM otc_orders
ORDER BY succursale, num_cde;

-- 9. Tester les calculs automatiques (solde)
SELECT 
  'AUTO CALCULATION TEST' as test_type,
  num_cde,
  qte_cde,
  qte_livree,
  solde,
  CASE 
    WHEN solde = (qte_cde - qte_livree) THEN 'CORRECT'
    ELSE 'ERROR'
  END as calculation_status
FROM otc_orders;

-- 10. Tester les analytics par succursale
SELECT 
  'BRANCH ANALYTICS TEST' as test_type,
  succursale,
  total_orders,
  delivered_orders,
  pending_orders,
  delivery_percentage
FROM v_otc_analytics
ORDER BY succursale;

-- 11. Tester les analytics par client
SELECT 
  'CUSTOMER ANALYTICS TEST' as test_type,
  num_client,
  nom_clients,
  total_orders,
  total_ordered_quantity,
  total_delivered_quantity,
  delivery_percentage
FROM v_otc_customer_analytics
ORDER BY total_orders DESC;

-- 12. Tester les analytics par statut
SELECT 
  'STATUS ANALYTICS TEST' as test_type,
  status,
  order_count,
  total_ordered_quantity,
  total_delivered_quantity,
  total_balance
FROM v_otc_status_tracking
ORDER BY order_count DESC;

-- 13. Tester les permissions
SELECT 
  'PERMISSIONS CHECK' as test_type,
  grantee,
  privilege_type,
  is_grantable
FROM information_schema.table_privileges 
WHERE table_name = 'otc_orders'
ORDER BY grantee, privilege_type;

-- 14. Test de performance - requêtes complexes
EXPLAIN (ANALYZE, BUFFERS) 
SELECT 
  o.succursale,
  o.status,
  COUNT(*) as order_count,
  SUM(o.qte_cde) as total_ordered,
  SUM(o.qte_livree) as total_delivered,
  SUM(o.solde) as total_balance
FROM otc_orders o
WHERE o.date_cde >= '2025-01-01'
GROUP BY o.succursale, o.status
ORDER BY o.succursale, order_count DESC;

-- 15. Test de la fonction de refresh
SELECT refresh_otc_analytics();

-- 16. Vérification finale
DO $$
DECLARE
  table_exists BOOLEAN;
  sample_count INTEGER;
  view_count INTEGER;
BEGIN
  -- Vérifier que la table existe
  SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_name = 'otc_orders'
  ) INTO table_exists;
  
  -- Compter les enregistrements d'exemple
  SELECT COUNT(*) INTO sample_count FROM otc_orders;
  
  -- Compter les vues analytiques
  SELECT COUNT(*) INTO view_count 
  FROM information_schema.views 
  WHERE table_name LIKE 'v_otc_%';
  
  RAISE NOTICE '=== OTC MODULE TEST RESULTS ===';
  RAISE NOTICE 'Table exists: %', CASE WHEN table_exists THEN 'YES' ELSE 'NO' END;
  RAISE NOTICE 'Sample records: %', sample_count;
  RAISE NOTICE 'Analytics views: %', view_count;
  
  IF table_exists AND sample_count > 0 AND view_count >= 3 THEN
    RAISE NOTICE '✅ OTC Module: ALL TESTS PASSED';
  ELSE
    RAISE NOTICE '❌ OTC Module: SOME TESTS FAILED';
  END IF;
  
  RAISE NOTICE '=== END OF TESTS ===';
END $$;
