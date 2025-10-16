-- Étape 4: Test de validation
-- Tester le rafraîchissement des vues
SELECT refresh_project_analytics_views();

-- Tester le basculement avec un projet existant
DO $$
DECLARE
  test_project_id uuid;
BEGIN
  -- Obtenir un ID de projet de test
  SELECT id INTO test_project_id FROM projects LIMIT 1;
  
  IF test_project_id IS NOT NULL THEN
    -- Test de basculement vers OTC-based
    BEGIN
      PERFORM switch_project_calculation_method(test_project_id, 'otc_based');
      RAISE NOTICE 'Test OTC-based réussi';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Test OTC-based échoué: %', SQLERRM;
    END;
    
    -- Test de basculement vers OR-based
    BEGIN
      PERFORM switch_project_calculation_method(test_project_id, 'or_based');
      RAISE NOTICE 'Test OR-based réussi';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Test OR-based échoué: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'Aucun projet trouvé pour les tests';
  END IF;
END $$;

-- Vérification finale
SELECT 'Tests de validation terminés' as status;
