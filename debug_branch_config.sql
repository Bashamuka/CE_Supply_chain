-- Test 2: Vérifier la configuration des branches pour le projet KCC
SELECT 
  pb.project_id,
  pb.branch_code,
  p.name as project_name
FROM project_branches pb
JOIN projects p ON p.id = pb.project_id
WHERE p.name LIKE '%KCC%'
ORDER BY pb.branch_code;

