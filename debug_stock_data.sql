-- Test 1: Vérifier les données de stock pour la pièce 4D4508
SELECT 
  part_number,
  qté_succ_20,
  qté_gdc,
  qté_jdc,
  qté_cat_network
FROM stock_dispo 
WHERE part_number = '4D4508';
