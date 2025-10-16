-- Script optimisé pour corriger le problème de rafraîchissement concurrent
-- Version simplifiée pour éviter les timeouts

-- Étape 1: Créer les index uniques manquants
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_project_parts_used_quantities_otc 
ON mv_project_parts_used_quantities_otc (project_id, machine_id, part_number);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_project_parts_used_quantities_enhanced 
ON mv_project_parts_used_quantities_enhanced (project_id, machine_id, part_number);

-- Vérification
SELECT 'Index uniques créés avec succès' as status;
