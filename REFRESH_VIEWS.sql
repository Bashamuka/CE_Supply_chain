-- ====================================================================
-- INSTRUCTION POUR CORRIGER LE PROBLÈME DES "0 parts"
-- ====================================================================
--
-- Le problème: Les vues matérialisées n'ont pas été rafraîchies après
-- l'ajout de vos projets, machines et pièces.
--
-- Solution: Exécutez ces commandes dans l'éditeur SQL de Supabase
-- ====================================================================

-- Étape 1: Rafraîchir toutes les vues matérialisées dans le bon ordre
-- (en respectant les dépendances entre les vues)

REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
REFRESH MATERIALIZED VIEW mv_project_analytics_complete;

-- Étape 2: Vérifier que les données sont maintenant présentes
-- Cette requête devrait maintenant montrer vos pièces avec les bonnes quantités

SELECT
  machine_name,
  part_number,
  description,
  quantity_required,
  quantity_available,
  quantity_used,
  quantity_in_transit,
  quantity_invoiced,
  quantity_missing
FROM mv_project_analytics_complete
ORDER BY machine_name, part_number;

-- ====================================================================
-- NOTES IMPORTANTES
-- ====================================================================
--
-- 1. Après avoir exécuté ces commandes, retournez dans l'application
--    et cliquez à nouveau sur "Refresh Data" dans le projet.
--
-- 2. Les nombres de pièces devraient maintenant s'afficher correctement.
--
-- 3. À l'avenir, le bouton "Refresh Data" devrait fonctionner
--    automatiquement grâce à la fonction refresh_project_analytics_views().
--
-- ====================================================================
