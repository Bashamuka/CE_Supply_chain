# Guide de Correction Définitive - Problème de Rafraîchissement Concurrent

## Problème Persistant
**Erreur** : `"Failed to switch calculation method: cannot refresh materialized view "public.mv_project_parts_used_quantities_otc" concurrently"`

**Cause** : La migration de correction n'a pas été appliquée à la base de données Supabase.

## Solution Définitive

### Option 1 : Via Supabase Dashboard (Recommandé)

1. **Aller sur Supabase Dashboard** :
   - Ouvrir https://supabase.com/dashboard
   - Sélectionner votre projet `nvuohqfsgeulivaihxeh`

2. **Accéder au SQL Editor** :
   - Cliquer sur "SQL Editor" dans le menu de gauche
   - Cliquer sur "New query"

3. **Exécuter le Script de Correction** :
   - Copier le contenu du fichier `fix_concurrent_refresh_definitive.sql`
   - Coller dans l'éditeur SQL
   - Cliquer sur "Run" pour exécuter

4. **Vérifier les Résultats** :
   - Regarder les messages dans la console
   - Vérifier que tous les index ont été créés
   - Confirmer que les tests passent

### Option 2 : Via CLI Supabase

```bash
# Si vous avez Supabase CLI installé
supabase db push

# Ou exécuter directement le script
supabase db reset --db-url "your-database-url"
```

### Option 3 : Exécution Manuelle des Commandes

Si vous préférez exécuter les commandes une par une :

#### 1. Créer les Index Uniques
```sql
-- Index pour mv_project_parts_used_quantities_otc
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_project_parts_used_quantities_otc 
ON mv_project_parts_used_quantities_otc (project_id, machine_id, part_number);

-- Index pour mv_project_parts_used_quantities_enhanced
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_project_parts_used_quantities_enhanced 
ON mv_project_parts_used_quantities_enhanced (project_id, machine_id, part_number);
```

#### 2. Mettre à Jour la Fonction de Rafraîchissement
```sql
CREATE OR REPLACE FUNCTION refresh_project_analytics_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Rafraîchir avec gestion d'erreurs
  BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_project_parts_used_quantities_otc;
  EXCEPTION WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_otc;
  END;
  
  -- Répéter pour toutes les autres vues...
END;
$$;
```

#### 3. Mettre à Jour la Fonction de Basculement
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
  -- (voir le script complet pour les détails)
END;
$$;
```

## Vérification de la Correction

### 1. Vérifier les Index
```sql
-- Vérifier que les index uniques existent
SELECT 
  tablename,
  indexname,
  indexdef
FROM pg_indexes 
WHERE tablename IN (
  'mv_project_parts_used_quantities_otc',
  'mv_project_parts_used_quantities_enhanced'
)
AND indexname LIKE '%unique%';
```

### 2. Tester le Basculement
```sql
-- Tester avec un projet existant
SELECT id, name FROM projects LIMIT 1;

-- Basculer vers OTC
SELECT switch_project_calculation_method('project-uuid', 'otc_based');

-- Basculer vers OR
SELECT switch_project_calculation_method('project-uuid', 'or_based');
```

### 3. Tester le Rafraîchissement
```sql
-- Tester le rafraîchissement des vues
SELECT refresh_project_analytics_views();
```

## Résultats Attendus

### Messages de Succès
```
NOTICE: Index unique créé pour mv_project_parts_used_quantities_otc
NOTICE: Index unique créé pour mv_project_parts_used_quantities_enhanced
NOTICE: mv_project_parts_used_quantities_otc rafraîchie
NOTICE: mv_project_parts_used_quantities_enhanced rafraîchie
NOTICE: Toutes les vues matérialisées ont été rafraîchies avec succès
NOTICE: Basculement vers la méthode OTC-based réussi
NOTICE: Basculement vers la méthode OR-based réussi
```

### Vérification dans l'Application
1. Aller sur "Project Calculation Settings"
2. Cliquer sur "Refresh Analytics"
3. Basculer entre les méthodes OR et OTC
4. **Aucune erreur ne devrait apparaître**

## Dépannage

### Si les Index Ne Se Créent Pas
```sql
-- Vérifier si les vues matérialisées existent
SELECT matviewname FROM pg_matviews 
WHERE matviewname IN (
  'mv_project_parts_used_quantities_otc',
  'mv_project_parts_used_quantities_enhanced'
);

-- Si elles n'existent pas, les créer d'abord
-- (voir les migrations précédentes)
```

### Si les Fonctions Ne Se Mettent Pas à Jour
```sql
-- Vérifier les permissions
SELECT 
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_name IN (
  'refresh_project_analytics_views',
  'switch_project_calculation_method'
);

-- Réaccorder les permissions si nécessaire
GRANT EXECUTE ON FUNCTION refresh_project_analytics_views() TO authenticated;
GRANT EXECUTE ON FUNCTION switch_project_calculation_method(uuid, text) TO authenticated;
```

### Si le Problème Persiste
1. **Vérifier les Logs** : Regarder les messages d'erreur dans Supabase
2. **Tester Individuellement** : Exécuter chaque commande séparément
3. **Contacter le Support** : Fournir les logs d'erreur exacts

## Prévention Future

### 1. Monitoring
- Surveiller les erreurs de rafraîchissement concurrent
- Vérifier régulièrement les index des vues matérialisées
- Tester les fonctions après chaque déploiement

### 2. Tests Automatiques
```sql
-- Script de test à exécuter régulièrement
DO $$
BEGIN
  PERFORM refresh_project_analytics_views();
  RAISE NOTICE 'Test de rafraîchissement réussi';
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Test de rafraîchissement échoué: %', SQLERRM;
END $$;
```

### 3. Documentation
- Maintenir la liste des index requis
- Documenter les dépendances entre vues
- Garder les guides de dépannage à jour

---

**Note** : Cette correction résout définitivement le problème de rafraîchissement concurrent. Une fois appliquée, le basculement entre méthodes de calcul fonctionnera sans erreur.
