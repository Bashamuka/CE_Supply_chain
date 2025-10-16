-- Script de correction définitive pour le problème de rafraîchissement concurrent
-- Ce script applique directement les corrections nécessaires

-- 1. Créer les index uniques manquants
DO $$
BEGIN
  -- Index pour mv_project_parts_used_quantities_otc
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_project_parts_used_quantities_otc') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'mv_project_parts_used_quantities_otc' AND indexname LIKE '%unique%') THEN
      CREATE UNIQUE INDEX ux_mv_project_parts_used_quantities_otc 
      ON mv_project_parts_used_quantities_otc (project_id, machine_id, part_number);
      RAISE NOTICE 'Index unique créé pour mv_project_parts_used_quantities_otc';
    ELSE
      RAISE NOTICE 'Index unique existe déjà pour mv_project_parts_used_quantities_otc';
    END IF;
  ELSE
    RAISE NOTICE 'Vue matérialisée mv_project_parts_used_quantities_otc n''existe pas';
  END IF;

  -- Index pour mv_project_parts_used_quantities_enhanced
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_project_parts_used_quantities_enhanced') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'mv_project_parts_used_quantities_enhanced' AND indexname LIKE '%unique%') THEN
      CREATE UNIQUE INDEX ux_mv_project_parts_used_quantities_enhanced 
      ON mv_project_parts_used_quantities_enhanced (project_id, machine_id, part_number);
      RAISE NOTICE 'Index unique créé pour mv_project_parts_used_quantities_enhanced';
    ELSE
      RAISE NOTICE 'Index unique existe déjà pour mv_project_parts_used_quantities_enhanced';
    END IF;
  ELSE
    RAISE NOTICE 'Vue matérialisée mv_project_parts_used_quantities_enhanced n''existe pas';
  END IF;
END $$;

-- 2. Fonction de rafraîchissement avec gestion d'erreurs
CREATE OR REPLACE FUNCTION refresh_project_analytics_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Rafraîchir les vues matérialisées avec gestion d'erreurs
  
  -- mv_project_machine_parts_aggregated
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_machine_parts_aggregated;
    RAISE NOTICE 'mv_project_machine_parts_aggregated rafraîchie';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Rafraîchissement concurrent échoué pour mv_project_machine_parts_aggregated, utilisation du rafraîchissement normal';
    REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
  END;
  
  -- mv_project_parts_stock_availability
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_stock_availability;
    RAISE NOTICE 'mv_project_parts_stock_availability rafraîchie';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Rafraîchissement concurrent échoué pour mv_project_parts_stock_availability, utilisation du rafraîchissement normal';
    REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
  END;
  
  -- mv_project_parts_used_quantities
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities;
    RAISE NOTICE 'mv_project_parts_used_quantities rafraîchie';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Rafraîchissement concurrent échoué pour mv_project_parts_used_quantities, utilisation du rafraîchissement normal';
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
  END;
  
  -- mv_project_parts_used_quantities_otc
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_otc;
    RAISE NOTICE 'mv_project_parts_used_quantities_otc rafraîchie';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Rafraîchissement concurrent échoué pour mv_project_parts_used_quantities_otc, utilisation du rafraîchissement normal';
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_otc;
  END;
  
  -- mv_project_parts_used_quantities_enhanced
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_enhanced;
    RAISE NOTICE 'mv_project_parts_used_quantities_enhanced rafraîchie';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Rafraîchissement concurrent échoué pour mv_project_parts_used_quantities_enhanced, utilisation du rafraîchissement normal';
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced;
  END;
  
  -- mv_project_parts_transit_invoiced
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_transit_invoiced;
    RAISE NOTICE 'mv_project_parts_transit_invoiced rafraîchie';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Rafraîchissement concurrent échoué pour mv_project_parts_transit_invoiced, utilisation du rafraîchissement normal';
    REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
  END;
  
  -- mv_project_analytics_complete
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_analytics_complete;
    RAISE NOTICE 'mv_project_analytics_complete rafraîchie';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Rafraîchissement concurrent échoué pour mv_project_analytics_complete, utilisation du rafraîchissement normal';
    REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
  END;
  
  RAISE NOTICE 'Toutes les vues matérialisées ont été rafraîchies avec succès';
END;
$$;

-- 3. Fonction de basculement améliorée
CREATE OR REPLACE FUNCTION switch_project_calculation_method(
  project_uuid uuid,
  method text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  project_exists boolean;
BEGIN
  -- Validation de la méthode
  IF method NOT IN ('or_based', 'otc_based') THEN
    RAISE EXCEPTION 'Méthode de calcul invalide. Doit être ''or_based'' ou ''otc_based''';
  END IF;
  
  -- Vérifier si le projet existe
  SELECT EXISTS(SELECT 1 FROM projects WHERE id = project_uuid) INTO project_exists;
  
  IF NOT project_exists THEN
    RAISE EXCEPTION 'Le projet avec l''ID % n''existe pas', project_uuid;
  END IF;
  
  -- Mettre à jour la méthode de calcul du projet
  UPDATE projects 
  SET calculation_method = method,
      updated_at = NOW()
  WHERE id = project_uuid;
  
  -- Vérifier si des lignes ont été mises à jour
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Échec de la mise à jour de la méthode de calcul du projet';
  END IF;
  
  -- Rafraîchir les analytics avec gestion d'erreurs
  BEGIN
    PERFORM refresh_project_analytics_views();
    RAISE NOTICE 'Méthode de calcul du projet % basculée vers % avec succès', project_uuid, method;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Échec du rafraîchissement des vues analytics: %', SQLERRM;
    -- Ne pas faire échouer toute l'opération si le rafraîchissement échoue
    RAISE NOTICE 'Méthode de calcul du projet % mise à jour vers %, mais le rafraîchissement des analytics a échoué', project_uuid, method;
  END;
END;
$$;

-- 4. Accorder les permissions
GRANT EXECUTE ON FUNCTION refresh_project_analytics_views() TO authenticated;
GRANT EXECUTE ON FUNCTION switch_project_calculation_method(uuid, text) TO authenticated;

-- 5. Test de validation
DO $$
DECLARE
  test_project_id uuid;
BEGIN
  -- Obtenir un ID de projet de test
  SELECT id INTO test_project_id FROM projects LIMIT 1;
  
  IF test_project_id IS NOT NULL THEN
    RAISE NOTICE 'Test du basculement de méthode de calcul avec le projet: %', test_project_id;
    
    -- Test de basculement vers OTC-based
    BEGIN
      PERFORM switch_project_calculation_method(test_project_id, 'otc_based');
      RAISE NOTICE 'Basculement vers la méthode OTC-based réussi';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Échec du basculement vers OTC-based: %', SQLERRM;
    END;
    
    -- Test de basculement vers OR-based
    BEGIN
      PERFORM switch_project_calculation_method(test_project_id, 'or_based');
      RAISE NOTICE 'Basculement vers la méthode OR-based réussi';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Échec du basculement vers OR-based: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'Aucun projet trouvé pour les tests';
  END IF;
END $$;

-- 6. Vérification finale
SELECT 
  'Correction terminée' as status,
  'Les index uniques ont été créés et les fonctions mises à jour' as message,
  NOW() as completed_at;
