# 🎯 Algorithme d'Allocation Progressive Affiné

## 📋 Vue d'ensemble

Cet algorithme gère l'allocation intelligente des pièces entre les machines d'un projet, en respectant un ordre de priorité chronologique et en utilisant différentes sources de disponibilité.

## 🔄 Ordre d'Allocation

L'allocation suit strictement cet ordre de priorité :

1. **Qty Used** (Priorité absolue) - Quantités déjà utilisées/consommées
2. **Qty Available** - Stock disponible en entrepôt
3. **Qty Invoiced** (In Transit dans l'UI) - Pièces facturées mais non réceptionnées
4. **Qty Backorders** (Backorders dans l'UI) - Pièces commandées mais non facturées
5. **Qty Missing** - Quantités manquantes (non satisfaites)

## 📊 Logique Progressive

### Principe de base

Pour chaque machine dans un projet, l'algorithme :
1. Calcule le **besoin restant** après avoir soustrait `Qty Used`
2. Alloue les ressources **dans l'ordre chronologique** de création des machines
3. Les machines créées en premier ont la priorité
4. Chaque machine ne voit que ce qui reste après l'allocation aux machines précédentes

### Exemple concret

**Situation :**
- Stock disponible : 30 pièces
- Machine 1 (créée en premier) : besoin de 15 pièces
- Machine 2 (créée ensuite) : besoin de 20 pièces

**Allocation :**
- Machine 1 reçoit : 15 pièces depuis `Qty Available`
- Machine 2 reçoit : 15 pièces depuis `Qty Available` (30 - 15 = 15 restant)
- Machine 2 manque : 5 pièces → `Qty Missing`

## 🔍 Détails Techniques

### Étape 0 : Calcul du besoin restant

```sql
remaining_need = MAX(0, quantity_required - quantity_used)
```

**Cas particuliers :**
- Si `quantity_used >= quantity_required` → `remaining_need = 0`
- La machine n'a plus besoin d'allocations supplémentaires

### Étape 1 : Allocation depuis Available (Stock)

Pour chaque machine dans l'ordre chronologique :

```sql
qty_from_available = MIN(
  remaining_need,
  MAX(0, total_stock - cumulative_consumption_by_previous_machines)
)
```

**Logique :**
- On calcule ce qui reste du stock après les machines précédentes
- On alloue le minimum entre le besoin et le stock restant

### Étape 2 : Allocation depuis Invoiced (Facturées)

```sql
need_after_available = remaining_need - qty_from_available
qty_from_invoiced = MIN(
  need_after_available,
  MAX(0, total_invoiced - cumulative_consumption_by_previous_machines)
)
```

**Logique :**
- On calcule le besoin après l'allocation du stock
- On alloue depuis les pièces facturées (en transit)

### Étape 3 : Allocation depuis Backorders (Commandées non facturées)

```sql
need_after_invoiced = need_after_available - qty_from_invoiced
qty_from_in_transit = MIN(
  need_after_invoiced,
  MAX(0, total_in_transit - cumulative_consumption_by_previous_machines)
)
```

**Logique :**
- On calcule le besoin après stock et facturées
- On alloue depuis les commandes en attente de facturation

### Étape 4 : Calcul de Missing

```sql
quantity_missing = MAX(0, 
  quantity_required 
  - quantity_used 
  - qty_from_available 
  - qty_from_invoiced 
  - qty_from_in_transit
)
```

## 🎛️ Règles Importantes

### 1. Isolation par projet

- **Chaque projet gère ses propres ressources**
- Les allocations d'un projet ne sont **PAS** affectées par les autres projets
- Garantie : `PARTITION BY project_id, part_number`

### 2. Ordre chronologique

- Les machines sont triées par `created_at`, puis `id`
- Garantie : `ORDER BY created_at, pm.id`

### 3. Dédoublonnage du stock

- Si une pièce apparaît en double dans `stock_dispo`, seule la première ligne est conservée
- Méthode : `ROW_NUMBER() OVER (PARTITION BY part_number ORDER BY part_number)`
- **Pas d'addition des quantités en double** (considéré comme erreur de saisie)

### 4. Gestion des cas limites

- `quantity_used >= quantity_required` → `remaining_need = 0`
- Aucune allocation supplémentaire n'est effectuée

## 📈 Performance

### Optimisations

1. **Vues matérialisées** : Les calculs sont pré-calculés
2. **Window Functions** : Calculs cumulatifs efficaces
3. **Indexes** : Sur `project_id`, `machine_id`, `part_number`

### Refresh

Les vues doivent être rafraîchies après chaque modification des données :

```sql
REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_otc;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced;
REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
REFRESH MATERIALIZED VIEW mv_project_analytics_complete;
```

## 🔧 Maintenance

### Diagnostics

Pour vérifier l'allocation d'une pièce spécifique :

```sql
SELECT 
  machine_name,
  quantity_required,
  quantity_used,
  quantity_available,
  quantity_invoiced,
  quantity_in_transit,
  quantity_missing
FROM mv_project_analytics_complete
WHERE project_id = 'YOUR_PROJECT_ID'
  AND part_number = 'YOUR_PART_NUMBER'
ORDER BY machine_name;
```

### Vérification de l'ordre chronologique

```sql
WITH machine_order AS (
  SELECT 
    pm.name,
    pm.created_at,
    ROW_NUMBER() OVER (ORDER BY pm.created_at, pm.id) as rank
  FROM project_machines pm
  WHERE pm.project_id = 'YOUR_PROJECT_ID'
)
SELECT * FROM machine_order ORDER BY rank;
```

## 📚 Fichiers Associés

- **Migration** : `supabase/migrations/20251022000000_refine_progressive_allocation_final.sql`
- **Script PowerShell** : `apply_refined_progressive_allocation.ps1`
- **Script SQL Refresh** : `refresh_all_views.sql`

## ✅ Points Clés à Retenir

1. ✅ **Used → Available → Invoiced → Backorders** (ordre strict)
2. ✅ **Ordre chronologique** des machines (created_at, id)
3. ✅ **Isolation par projet** (pas d'interférence entre projets)
4. ✅ **Dédoublonnage automatique** du stock
5. ✅ **Gestion des cas limites** (used >= required)
6. ✅ **Performance optimisée** avec vues matérialisées

## 🎯 Objectif Atteint

Cet algorithme garantit une **allocation juste et prévisible** des pièces, en respectant :
- La priorité des machines créées en premier
- L'utilisation optimale des ressources disponibles
- L'isolation complète entre projets
- La performance des requêtes

