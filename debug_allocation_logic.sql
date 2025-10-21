-- Test 4: Vérifier la logique d'allocation progressive complète
SELECT 
  machine_id,
  project_id,
  machine_name,
  part_number,
  quantity_required,
  quantity_used,
  quantity_available,
  quantity_in_transit,
  quantity_invoiced,
  quantity_missing,
  creation_rank
FROM mv_project_analytics_complete 
WHERE part_number = '4D4508'
ORDER BY creation_rank;
