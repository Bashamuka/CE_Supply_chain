-- Test manuel du refresh des vues (à exécuter séparément si nécessaire)
-- Ce script peut être exécuté manuellement pour tester le refresh

-- Test du refresh des vues (peut prendre du temps)
DO $$
BEGIN
  RAISE NOTICE 'Début du test de refresh des vues...';
  
  BEGIN
    PERFORM refresh_project_analytics_views();
    RAISE NOTICE '✅ Refresh des vues réussi';
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '❌ Erreur lors du refresh des vues: %', SQLERRM;
  END;
  
  RAISE NOTICE 'Test de refresh terminé';
END $$;
