-- SCRIPT COMPLET POUR CORRIGER LES PERMISSIONS ADMINISTRATEUR
-- Exécuter ce script directement dans Supabase SQL Editor

-- ==============================================
-- 1. CRÉATION DES TABLES
-- ==============================================

-- Créer la table user_module_access
CREATE TABLE IF NOT EXISTS user_module_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  module_name text NOT NULL CHECK (
    module_name IN (
      'global_dashboard',
      'eta_tracking',
      'stock_availability',
      'parts_equivalence',
      'orders',
      'projects',
      'dealer_forward_planning'
    )
  ),
  has_access boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, module_name)
);

-- Créer la table user_project_access
CREATE TABLE IF NOT EXISTS user_project_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, project_id)
);

-- ==============================================
-- 2. ACTIVATION DE RLS (ROW LEVEL SECURITY)
-- ==============================================

ALTER TABLE user_module_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_project_access ENABLE ROW LEVEL SECURITY;

-- ==============================================
-- 3. SUPPRESSION DES ANCIENNES POLITIQUES (SI ELLES EXISTENT)
-- ==============================================

-- Supprimer les anciennes politiques pour user_module_access
DROP POLICY IF EXISTS "Users can view their own module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can view all module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can insert module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can update module access" ON user_module_access;
DROP POLICY IF EXISTS "Admins can delete module access" ON user_module_access;

-- Supprimer les anciennes politiques pour user_project_access
DROP POLICY IF EXISTS "Users can view their own project access" ON user_project_access;
DROP POLICY IF EXISTS "Admins can view all project access" ON user_project_access;
DROP POLICY IF EXISTS "Admins can insert project access" ON user_project_access;
DROP POLICY IF EXISTS "Admins can delete project access" ON user_project_access;

-- ==============================================
-- 4. CRÉATION DES NOUVELLES POLITIQUES RLS
-- ==============================================

-- Politiques pour user_module_access
CREATE POLICY "Users can view their own module access"
  ON user_module_access FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all module access"
  ON user_module_access FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can insert module access"
  ON user_module_access FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can update module access"
  ON user_module_access FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can delete module access"
  ON user_module_access FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Politiques pour user_project_access
CREATE POLICY "Users can view their own project access"
  ON user_project_access FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all project access"
  ON user_project_access FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can insert project access"
  ON user_project_access FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can delete project access"
  ON user_project_access FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ==============================================
-- 5. CRÉATION DES INDEX POUR LA PERFORMANCE
-- ==============================================

CREATE INDEX IF NOT EXISTS idx_user_module_access_user_id ON user_module_access(user_id);
CREATE INDEX IF NOT EXISTS idx_user_module_access_module ON user_module_access(module_name);
CREATE INDEX IF NOT EXISTS idx_user_project_access_user_id ON user_project_access(user_id);
CREATE INDEX IF NOT EXISTS idx_user_project_access_project_id ON user_project_access(project_id);

-- ==============================================
-- 6. CRÉATION DES FONCTIONS HELPER
-- ==============================================

-- Fonction pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION update_user_module_access_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour updated_at
DROP TRIGGER IF EXISTS update_user_module_access_updated_at_trigger ON user_module_access;
CREATE TRIGGER update_user_module_access_updated_at_trigger
  BEFORE UPDATE ON user_module_access
  FOR EACH ROW
  EXECUTE FUNCTION update_user_module_access_updated_at();

-- Fonction pour vérifier l'accès aux modules
CREATE OR REPLACE FUNCTION check_user_module_access(
  p_user_id uuid,
  p_module_name text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin boolean;
  v_has_access boolean;
BEGIN
  -- Vérifier si l'utilisateur est admin
  SELECT (role = 'admin') INTO v_is_admin
  FROM profiles
  WHERE id = p_user_id;
  
  -- Les admins ont accès à tous les modules
  IF v_is_admin THEN
    RETURN true;
  END IF;
  
  -- Vérifier l'accès au module
  SELECT has_access INTO v_has_access
  FROM user_module_access
  WHERE user_id = p_user_id
    AND module_name = p_module_name;
  
  RETURN COALESCE(v_has_access, false);
END;
$$;

-- Fonction pour vérifier l'accès aux projets
CREATE OR REPLACE FUNCTION check_user_project_access(
  p_user_id uuid,
  p_project_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin boolean;
  v_has_access boolean;
BEGIN
  -- Vérifier si l'utilisateur est admin
  SELECT (role = 'admin') INTO v_is_admin
  FROM profiles
  WHERE id = p_user_id;
  
  -- Les admins ont accès à tous les projets
  IF v_is_admin THEN
    RETURN true;
  END IF;
  
  -- Vérifier l'accès au projet
  SELECT EXISTS(
    SELECT 1
    FROM user_project_access
    WHERE user_id = p_user_id
      AND project_id = p_project_id
  ) INTO v_has_access;
  
  RETURN v_has_access;
END;
$$;

-- ==============================================
-- 7. TEST DE LA CONFIGURATION
-- ==============================================

DO $$
DECLARE
  admin_user_id uuid;
  test_user_id uuid;
BEGIN
  -- Trouver un utilisateur admin
  SELECT id INTO admin_user_id 
  FROM profiles 
  WHERE role = 'admin' 
  LIMIT 1;
  
  -- Trouver n'importe quel utilisateur pour le test
  SELECT id INTO test_user_id 
  FROM profiles 
  LIMIT 1;
  
  IF admin_user_id IS NOT NULL AND test_user_id IS NOT NULL THEN
    -- Test d'insertion d'accès module
    BEGIN
      INSERT INTO user_module_access (user_id, module_name, has_access)
      VALUES (test_user_id, 'global_dashboard', true)
      ON CONFLICT (user_id, module_name) DO UPDATE SET has_access = true;
      
      RAISE NOTICE '✅ SUCCÈS: Table créée et test d''insertion réussi';
      
      -- Nettoyer les données de test
      DELETE FROM user_module_access 
      WHERE user_id = test_user_id AND module_name = 'global_dashboard';
      
      RAISE NOTICE '✅ SUCCÈS: Configuration complète et fonctionnelle';
      
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '❌ ÉCHEC: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE '⚠️  ATTENTION: Aucun utilisateur trouvé pour le test, mais les tables ont été créées';
  END IF;
END;
$$;

-- ==============================================
-- 8. VÉRIFICATION FINALE
-- ==============================================

-- Vérifier que les tables existent
SELECT 
  'user_module_access' as table_name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_module_access') 
    THEN '✅ EXISTE' 
    ELSE '❌ MANQUANTE' 
  END as status;

SELECT 
  'user_project_access' as table_name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_project_access') 
    THEN '✅ EXISTE' 
    ELSE '❌ MANQUANTE' 
  END as status;

-- Vérifier les politiques RLS
SELECT 
  tablename,
  policyname,
  cmd as operation
FROM pg_policies 
WHERE tablename IN ('user_module_access', 'user_project_access')
ORDER BY tablename, policyname;

-- Vérifier les fonctions
SELECT 
  routine_name as function_name,
  routine_type
FROM information_schema.routines 
WHERE routine_name IN ('check_user_module_access', 'check_user_project_access')
ORDER BY routine_name;

RAISE NOTICE '🎉 SCRIPT TERMINÉ - Vérifiez les résultats ci-dessus';
