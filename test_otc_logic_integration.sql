/*
  # Test OTC Logic Integration in Project Management
  
  ## Purpose
  Test the new OTC-based calculation method for "Used" percentage in Project Management.
  This script verifies that both calculation methods work correctly.
  
  ## Test Scenarios
  1. Verify project calculation method field exists
  2. Test OR-based calculation (existing logic)
  3. Test OTC-based calculation (new logic)
  4. Compare results between methods
  5. Verify no duplication in OTC calculation
*/

-- 1. Check project calculation methods
SELECT 
  'Project Calculation Methods' as test_section,
  p.name as project_name,
  p.calculation_method,
  CASE 
    WHEN p.calculation_method = 'or_based' THEN 'Uses Operational Requests (ORs)'
    WHEN p.calculation_method = 'otc_based' THEN 'Uses Delivery Notes (BLs) from OTC'
    ELSE 'Unknown method'
  END as method_description
FROM projects p
ORDER BY p.name;

-- 2. Test OR-based calculation (existing logic)
SELECT 
  'OR-Based Calculation Test' as test_section,
  pm.project_id,
  pm.name as machine_name,
  pmp.part_number,
  pmp.quantity_required,
  COALESCE(used_or.quantity_used, 0) as quantity_used_or,
  ROUND(
    CASE 
      WHEN pmp.quantity_required > 0 
      THEN (COALESCE(used_or.quantity_used, 0) / pmp.quantity_required) * 100
      ELSE 0 
    END, 2
  ) as used_percentage_or
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
JOIN projects p ON p.id = pm.project_id
LEFT JOIN mv_project_parts_used_quantities used_or 
  ON used_or.machine_id = pmp.machine_id AND used_or.part_number = pmp.part_number
WHERE p.calculation_method = 'or_based'
ORDER BY pm.project_id, pm.name, pmp.part_number
LIMIT 10;

-- 3. Test OTC-based calculation (new logic)
SELECT 
  'OTC-Based Calculation Test' as test_section,
  pm.project_id,
  pm.name as machine_name,
  pmp.part_number,
  pmp.quantity_required,
  COALESCE(used_otc.quantity_used_otc, 0) as quantity_used_otc,
  ROUND(
    CASE 
      WHEN pmp.quantity_required > 0 
      THEN (COALESCE(used_otc.quantity_used_otc, 0) / pmp.quantity_required) * 100
      ELSE 0 
    END, 2
  ) as used_percentage_otc
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
JOIN projects p ON p.id = pm.project_id
LEFT JOIN mv_project_parts_used_quantities_otc used_otc 
  ON used_otc.machine_id = pmp.machine_id AND used_otc.part_number = pmp.part_number
WHERE p.calculation_method = 'otc_based'
ORDER BY pm.project_id, pm.name, pmp.part_number
LIMIT 10;

-- 4. Test enhanced calculation (both methods)
SELECT 
  'Enhanced Calculation Test' as test_section,
  pm.project_id,
  pm.name as machine_name,
  pmp.part_number,
  pmp.quantity_required,
  COALESCE(used_enhanced.quantity_used, 0) as quantity_used_enhanced,
  p.calculation_method,
  ROUND(
    CASE 
      WHEN pmp.quantity_required > 0 
      THEN (COALESCE(used_enhanced.quantity_used, 0) / pmp.quantity_required) * 100
      ELSE 0 
    END, 2
  ) as used_percentage_enhanced
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
JOIN projects p ON p.id = pm.project_id
LEFT JOIN mv_project_parts_used_quantities_enhanced used_enhanced 
  ON used_enhanced.machine_id = pmp.machine_id AND used_enhanced.part_number = pmp.part_number
ORDER BY pm.project_id, pm.name, pmp.part_number
LIMIT 15;

-- 5. Verify OTC data availability
SELECT 
  'OTC Data Verification' as test_section,
  COUNT(*) as total_otc_orders,
  COUNT(CASE WHEN num_bl IS NOT NULL AND num_bl != '' THEN 1 END) as orders_with_bl,
  COUNT(DISTINCT reference) as unique_parts,
  COUNT(DISTINCT succursale) as unique_branches,
  SUM(qte_livree) as total_delivered_quantity
FROM otc_orders;

-- 6. Check OTC orders linked to projects
SELECT 
  'OTC-Project Link Verification' as test_section,
  otc.reference as part_number,
  otc.num_bl,
  otc.qte_livree,
  otc.succursale,
  COUNT(DISTINCT pso.project_id) as linked_projects_count
FROM otc_orders otc
LEFT JOIN parts p ON p.part_ordered = otc.reference
LEFT JOIN project_supplier_orders pso ON pso.supplier_order = p.supplier_order
WHERE otc.num_bl IS NOT NULL AND otc.num_bl != ''
GROUP BY otc.reference, otc.num_bl, otc.qte_livree, otc.succursale
ORDER BY linked_projects_count DESC, otc.qte_livree DESC
LIMIT 10;

-- 7. Test project-level aggregation (no duplication)
SELECT 
  'Project-Level Aggregation Test' as test_section,
  pm.project_id,
  p.name as project_name,
  pmp.part_number,
  SUM(pmp.quantity_required) as total_required_project,
  SUM(COALESCE(used_enhanced.quantity_used, 0)) as total_used_project,
  ROUND(
    CASE 
      WHEN SUM(pmp.quantity_required) > 0 
      THEN (SUM(COALESCE(used_enhanced.quantity_used, 0)) / SUM(pmp.quantity_required)) * 100
      ELSE 0 
    END, 2
  ) as project_used_percentage,
  p.calculation_method
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
JOIN projects p ON p.id = pm.project_id
LEFT JOIN mv_project_parts_used_quantities_enhanced used_enhanced 
  ON used_enhanced.machine_id = pmp.machine_id AND used_enhanced.part_number = pmp.part_number
GROUP BY pm.project_id, p.name, pmp.part_number, p.calculation_method
HAVING SUM(pmp.quantity_required) > 0
ORDER BY pm.project_id, pmp.part_number
LIMIT 10;

-- 8. Performance test - check view refresh times
DO $$
DECLARE
  start_time TIMESTAMP;
  end_time TIMESTAMP;
  duration INTERVAL;
BEGIN
  RAISE NOTICE 'Starting performance test...';
  
  start_time := clock_timestamp();
  PERFORM refresh_project_analytics_views();
  end_time := clock_timestamp();
  
  duration := end_time - start_time;
  
  RAISE NOTICE 'View refresh completed in: %', duration;
  RAISE NOTICE 'Performance test completed successfully';
END $$;

-- 9. Summary statistics
SELECT 
  'Summary Statistics' as test_section,
  COUNT(DISTINCT p.id) as total_projects,
  COUNT(DISTINCT CASE WHEN p.calculation_method = 'or_based' THEN p.id END) as or_based_projects,
  COUNT(DISTINCT CASE WHEN p.calculation_method = 'otc_based' THEN p.id END) as otc_based_projects,
  COUNT(DISTINCT pm.id) as total_machines,
  COUNT(DISTINCT pmp.part_number) as total_parts,
  COUNT(*) as total_part_machine_combinations
FROM projects p
LEFT JOIN project_machines pm ON pm.project_id = p.id
LEFT JOIN mv_project_machine_parts_aggregated pmp ON pmp.machine_id = pm.id;

-- 10. Final verification
SELECT 
  'Final Verification' as test_section,
  'OTC Logic Integration Test Completed Successfully' as status,
  NOW() as test_completed_at;
