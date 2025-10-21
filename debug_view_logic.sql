-- Test 3: Vérifier la logique de mv_project_parts_stock_availability étape par étape
WITH test_data AS (
  SELECT 
    pm.project_id,
    pmp.part_number,
    -- Test de la condition EXISTS pour succ_20
    CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_20') THEN 1 ELSE 0 END as branch_exists,
    -- Test de la valeur stock
    COALESCE(sd.qté_succ_20, 0) as stock_value,
    -- Test du calcul complet
    COALESCE(sd.qté_succ_20, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_20') THEN 1 ELSE 0 END as calculated_value
  FROM mv_project_machine_parts_aggregated pmp
  JOIN project_machines pm ON pm.id = pmp.machine_id
  LEFT JOIN stock_dispo sd ON sd.part_number = pmp.part_number
  WHERE pmp.part_number = '4D4508'
)
SELECT 
  project_id,
  part_number,
  branch_exists,
  stock_value,
  calculated_value,
  -- Test de la vue actuelle
  (SELECT quantity_available FROM mv_project_parts_stock_availability WHERE project_id = test_data.project_id AND part_number = test_data.part_number) as view_result
FROM test_data;
