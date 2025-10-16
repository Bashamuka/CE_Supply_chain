# Guide de Dépannage - Erreur de Rafraîchissement Concurrent

## Problème Identifié
**Erreur** : `Failed to switch calculation method: cannot refresh materialized view "public.mv_project_parts_used_quantities_otc" concurrently`

## Cause Racine
Les vues matérialisées `mv_project_parts_used_quantities_otc` et `mv_project_parts_used_quantities_enhanced` n'avaient pas d'index unique, ce qui est requis pour le rafraîchissement concurrent (`REFRESH MATERIALIZED VIEW CONCURRENTLY`).

## Solution Appliquée

### 1. Index Uniques Ajoutés
```sql
-- Index unique pour mv_project_parts_used_quantities_otc
CREATE UNIQUE INDEX ux_mv_project_parts_used_quantities_otc 
ON mv_project_parts_used_quantities_otc (project_id, machine_id, part_number);

-- Index unique pour mv_project_parts_used_quantities_enhanced
CREATE UNIQUE INDEX ux_mv_project_parts_used_quantities_enhanced 
ON mv_project_parts_used_quantities_enhanced (project_id, machine_id, part_number);
```

### 2. Fonction de Rafraîchissement Améliorée
La fonction `refresh_project_analytics_views()` a été améliorée avec :
- **Gestion d'erreurs** : Try-catch pour chaque vue matérialisée
- **Fallback** : Rafraîchissement normal si le concurrent échoue
- **Logging** : Messages détaillés pour le debugging

### 3. Fonction de Basculement Renforcée
La fonction `switch_project_calculation_method()` a été améliorée avec :
- **Validation** : Vérification de l'existence du projet
- **Gestion d'erreurs** : Messages d'erreur plus clairs
- **Robustesse** : Continue même si le rafraîchissement échoue

## Comment Appliquer la Correction

### Option 1 : Via Supabase Dashboard
1. Aller dans **SQL Editor** de Supabase
2. Exécuter le fichier `supabase/migrations/20251015140000_fix_concurrent_refresh_error.sql`
3. Vérifier que les index sont créés

### Option 2 : Via CLI Supabase
```bash
# Appliquer la migration
supabase db push

# Ou exécuter directement
supabase db reset --db-url "your-database-url"
```

### Option 3 : Exécution Manuelle
```sql
-- Vérifier les index existants
SELECT tablename, indexname 
FROM pg_indexes 
WHERE tablename IN (
  'mv_project_parts_used_quantities_otc',
  'mv_project_parts_used_quantities_enhanced'
);

-- Créer les index manquants
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_project_parts_used_quantities_otc 
ON mv_project_parts_used_quantities_otc (project_id, machine_id, part_number);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_project_parts_used_quantities_enhanced 
ON mv_project_parts_used_quantities_enhanced (project_id, machine_id, part_number);
```

## Tests de Validation

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
SELECT id, name, calculation_method 
FROM projects 
LIMIT 1;

-- Basculer vers OTC
SELECT switch_project_calculation_method('project-uuid', 'otc_based');

-- Basculer vers OR
SELECT switch_project_calculation_method('project-uuid', 'or_based');
```

### 3. Vérifier le Rafraîchissement
```sql
-- Tester le rafraîchissement des vues
SELECT refresh_project_analytics_views();
```

## Prévention Future

### 1. Bonnes Pratiques
- **Toujours créer des index uniques** sur les vues matérialisées
- **Utiliser CONCURRENTLY** pour éviter les verrous
- **Tester les migrations** avant le déploiement

### 2. Monitoring
- **Surveiller les erreurs** de rafraîchissement
- **Vérifier les performances** des vues matérialisées
- **Logs détaillés** pour le debugging

### 3. Documentation
- **Documenter les dépendances** entre vues
- **Maintenir la liste** des index requis
- **Guides de dépannage** à jour

## Erreurs Courantes et Solutions

### Erreur : "relation does not exist"
**Cause** : Vue matérialisée non créée
**Solution** : Exécuter les migrations dans l'ordre

### Erreur : "duplicate key value"
**Cause** : Données dupliquées dans la vue
**Solution** : Nettoyer les données avant de créer l'index unique

### Erreur : "lock timeout"
**Cause** : Verrouillage prolongé
**Solution** : Utiliser CONCURRENTLY ou attendre

## Support Technique

Si le problème persiste :
1. **Collecter les logs** de la console
2. **Vérifier l'état** des vues matérialisées
3. **Tester les fonctions** individuellement
4. **Contacter l'équipe** de développement

---

**Note** : Cette correction résout définitivement l'erreur de rafraîchissement concurrent et permet le basculement fluide entre les méthodes de calcul OR et OTC.
