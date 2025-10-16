# Guide Étape par Étape - Correction du Problème de Rafraîchissement Concurrent

## Problème
Erreur : `"Failed to switch calculation method: cannot refresh materialized view "public.mv_project_parts_used_quantities_otc" concurrently"`

## Solution Optimisée
Nous avons divisé la correction en 4 étapes pour éviter les timeouts SQL.

## Étapes d'Application

### Étape 1 : Créer les Index Uniques
**Fichier :** `step1_create_indexes.sql`
- Crée les index uniques nécessaires pour le rafraîchissement concurrent
- **Durée :** ~30 secondes
- **Exécuter via :** Supabase Dashboard → SQL Editor

### Étape 2 : Mettre à Jour la Fonction de Refresh
**Fichier :** `step2_update_refresh_function.sql`
- Met à jour `refresh_project_analytics_views()` avec gestion d'erreurs
- **Durée :** ~1 minute
- **Exécuter via :** Supabase Dashboard → SQL Editor

### Étape 3 : Mettre à Jour la Fonction de Basculement
**Fichier :** `step3_update_switch_function.sql`
- Met à jour `switch_project_calculation_method()` avec validation
- **Durée :** ~30 secondes
- **Exécuter via :** Supabase Dashboard → SQL Editor

### Étape 4 : Tests de Validation (Version Simplifiée)
**Fichier :** `step4_test_validation_simple.sql`
- Tests rapides sans opérations coûteuses
- **Durée :** ~10 secondes
- **Exécuter via :** Supabase Dashboard → SQL Editor

### Test Manuel du Refresh (Optionnel)
**Fichier :** `test_refresh_manual.sql`
- Test séparé du refresh des vues
- **À exécuter seulement si nécessaire**
- **Durée :** Variable (peut prendre plusieurs minutes)

## Instructions d'Exécution

### Via Supabase Dashboard
1. Allez sur [supabase.com](https://supabase.com) → Votre projet
2. Cliquez sur **SQL Editor** dans le menu de gauche
3. Exécutez chaque script dans l'ordre :
   - `step1_create_indexes.sql`
   - `step2_update_refresh_function.sql`
   - `step3_update_switch_function.sql`
   - `step4_test_validation_simple.sql`
4. Vérifiez les messages de confirmation

### Via Supabase CLI (Alternative)
```bash
# Si vous avez Supabase CLI installé
supabase db reset --linked
# Puis exécutez les migrations dans l'ordre
```

## Vérification du Succès

### Messages de Confirmation Attendus
- ✅ `Index ux_mv_project_parts_used_quantities_otc créé`
- ✅ `Index ux_mv_project_parts_used_quantities_enhanced créé`
- ✅ `Fonction refresh_project_analytics_views mise à jour`
- ✅ `Fonction switch_project_calculation_method mise à jour`
- ✅ `Tests de validation simplifiés terminés`

### Test dans l'Application
1. Connectez-vous à l'application
2. Allez dans **Project Management**
3. Cliquez sur **Calculation Settings**
4. Essayez de basculer entre les méthodes de calcul
5. L'erreur de rafraîchissement concurrent ne devrait plus apparaître

## Dépannage

### Si une Étape Échoue
1. **Vérifiez les dépendances :** Assurez-vous que les étapes précédentes ont réussi
2. **Relancez l'étape :** Les scripts sont idempotents (peuvent être relancés)
3. **Vérifiez les logs :** Regardez les messages NOTICE et WARNING

### Si le Refresh Manuel Échoue
1. **Vérifiez les index :** Assurez-vous que les index uniques existent
2. **Vérifiez les vues :** Assurez-vous que toutes les vues matérialisées existent
3. **Contactez le support :** Si le problème persiste

## Avantages de cette Approche

### ✅ Évite les Timeouts
- Scripts courts et optimisés
- Pas d'opérations coûteuses dans les tests

### ✅ Gestion d'Erreurs Robuste
- Fallback vers refresh non-concurrent si nécessaire
- Messages informatifs pour le débogage

### ✅ Tests Complets
- Validation de toutes les fonctions
- Vérification des index et dépendances

### ✅ Idempotent
- Peut être relancé sans problème
- Pas d'effets de bord

## Prochaines Étapes

Après avoir appliqué ces corrections :

1. **Testez l'application** : Vérifiez que le basculement fonctionne
2. **Surveillez les performances** : Les refresh concurrents devraient être plus rapides
3. **Documentez les changements** : Notez les améliorations apportées

## Support

Si vous rencontrez des problèmes :
1. Vérifiez ce guide étape par étape
2. Consultez les logs Supabase
3. Contactez l'équipe de développement avec les messages d'erreur exacts
