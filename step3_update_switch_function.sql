-- Étape 3: Mettre à jour la fonction de basculement
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
  
  -- Rafraîchir les analytics avec gestion d'erreurs
  BEGIN
    PERFORM refresh_project_analytics_views();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Échec du rafraîchissement des vues analytics: %', SQLERRM;
  END;
END;
$$;

-- Accorder les permissions
GRANT EXECUTE ON FUNCTION switch_project_calculation_method(uuid, text) TO authenticated;

-- Vérification
SELECT 'Fonction de basculement mise à jour' as status;
