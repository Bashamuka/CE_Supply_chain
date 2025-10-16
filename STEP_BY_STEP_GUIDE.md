# Guide d'Application Étape par Étape - Correction du Timeout SQL

## Problème Identifié
**Erreur** : "SQL query ran into an upstream timeout"
**Cause** : Le script SQL complet est trop volumineux et complexe pour Supabase

## Solution Optimisée
**Approche** : Exécuter les corrections en 4 étapes séparées pour éviter les timeouts.

## Instructions d'Application

### Étape 1 : Créer les Index Uniques
**Fichier** : `step1_create_indexes.sql`

1. Aller sur Supabase Dashboard → SQL Editor
2. Copier le contenu de `step1_create_indexes.sql`
3. Coller dans l'éditeur SQL
4. Cliquer sur "Run"
5. Vérifier le message : "Index uniques créés avec succès"

**Contenu** :
```sql
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_project_parts_used_quantities_otc 
ON mv_project_parts_used_quantities_otc (project_id, machine_id, part_number);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_project_parts_used_quantities_enhanced 
ON mv_project_parts_used_quantities_enhanced (project_id, machine_id, part_number);
```

### Étape 2 : Mettre à Jour la Fonction de Rafraîchissement
**Fichier** : `step2_update_refresh_function.sql`

1. Dans le même SQL Editor
2. Copier le contenu de `step2_update_refresh_function.sql`
3. Coller dans l'éditeur SQL
4. Cliquer sur "Run"
5. Vérifier le message : "Fonction de rafraîchissement mise à jour"

**Contenu** :
```sql
CREATE OR REPLACE FUNCTION refresh_project_analytics_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Rafraîchir les vues avec gestion d'erreurs
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_otc;
  EXCEPTION WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_otc;
  END;
  -- ... autres vues
END;
$$;
```

### Étape 3 : Mettre à Jour la Fonction de Basculement
**Fichier** : `step3_update_switch_function.sql`

1. Dans le même SQL Editor
2. Copier le contenu de `step3_update_switch_function.sql`
3. Coller dans l'éditeur SQL
4. Cliquer sur "Run"
5. Vérifier le message : "Fonction de basculement mise à jour"

**Contenu** :
```sql
CREATE OR REPLACE FUNCTION switch_project_calculation_method(
  project_uuid uuid,
  method text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validation et mise à jour avec gestion d'erreurs
  -- ...
END;
$$;
```

### Étape 4 : Tests de Validation
**Fichier** : `step4_test_validation.sql`

1. Dans le même SQL Editor
2. Copier le contenu de `step4_test_validation.sql`
3. Coller dans l'éditeur SQL
4. Cliquer sur "Run"
5. Vérifier les messages de succès

**Contenu** :
```sql
-- Tester le rafraîchissement
SELECT refresh_project_analytics_views();

-- Tester le basculement
DO $$
DECLARE
  test_project_id uuid;
BEGIN
  SELECT id INTO test_project_id FROM projects LIMIT 1;
  -- Tests de basculement...
END $$;
```

## Vérification de la Correction

### 1. Vérifier les Index
```sql
SELECT 
  tablename,
  indexname
FROM pg_indexes 
WHERE tablename IN (
  'mv_project_parts_used_quantities_otc',
  'mv_project_parts_used_quantities_enhanced'
)
AND indexname LIKE '%unique%';
```

### 2. Tester dans l'Application
1. Aller sur "Project Calculation Settings"
2. Cliquer sur "Refresh Analytics"
3. Basculer entre les méthodes OR et OTC
4. **Aucune erreur ne devrait apparaître**

## Dépannage

### Si une Étape Échoue
1. **Vérifier les Messages d'Erreur** dans la console Supabase
2. **Réexécuter l'Étape** individuellement
3. **Vérifier les Permissions** si nécessaire

### Si les Index Ne Se Créent Pas
```sql
-- Vérifier si les vues existent
SELECT matviewname FROM pg_matviews 
WHERE matviewname IN (
  'mv_project_parts_used_quantities_otc',
  'mv_project_parts_used_quantities_enhanced'
);
```

### Si les Fonctions Ne Se Mettent Pas à Jour
```sql
-- Vérifier les permissions
GRANT EXECUTE ON FUNCTION refresh_project_analytics_views() TO authenticated;
GRANT EXECUTE ON FUNCTION switch_project_calculation_method(uuid, text) TO authenticated;
```

## Avantages de Cette Approche

### 1. Évite les Timeouts
- Scripts plus petits et plus rapides
- Exécution étape par étape
- Moins de charge sur Supabase

### 2. Meilleur Contrôle
- Vérification à chaque étape
- Possibilité de corriger les erreurs individuelles
- Progression visible

### 3. Plus Robuste
- Gestion d'erreurs à chaque niveau
- Fallback automatique
- Tests de validation

## Résultats Attendus

### Messages de Succès
```
Index uniques créés avec succès
Fonction de rafraîchissement mise à jour
Fonction de basculement mise à jour
Test OTC-based réussi
Test OR-based réussi
Tests de validation terminés
```

### Dans l'Application
- ✅ Rafraîchissement des analytics sans erreur
- ✅ Basculement OR ↔ OTC sans problème
- ✅ Aucun message d'erreur "concurrent refresh"

---

**Note** : Cette approche étape par étape résout définitivement le problème de timeout et permet une application sûre des corrections.
