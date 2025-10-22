/*
  # Algorithme d'allocation progressive affiné - Version finale
  
  ## Spécifications
  1. Ordre d'allocation : Used → Available → Invoiced → Backorders
     - Used : Déjà consommé (priorité absolue)
     - Available : Stock disponible
     - Invoiced : Facturées non réceptionnées (In Transit dans l'UI)
     - Backorders : Commandées non facturées (Backorders dans l'UI)
  
  2. Ordre chronologique : Machines triées par created_at, puis id
  3. Ressources partagées uniquement au sein d'un même projet
  4. Si quantity_used >= quantity_required, le besoin restant = 0
  5. Doublons dans stock_dispo : Suppression sans addition
  
  ## Logique progressive
  Pour chaque machine dans l'ordre chronologique :
  - Étape 0 : Calculer remaining_need = MAX(0, quantity_required - quantity_used)
  - Étape 1 : Allouer depuis Available (stock restant après machines précédentes)
  - Étape 2 : Allouer depuis Invoiced (facturées, restant après machines précédentes)
  - Étape 3 : Allouer depuis Backorders (commandées non facturées, restant après machines précédentes)
  - Étape 4 : Calculer quantity_missing pour le reste non satisfait
*/

-- ============================================================================
-- ÉTAPE 1 : SUPPRESSION DE TOUTES LES VUES EXISTANTES
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS mv_project_analytics_complete CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_latest_eta CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_transit_invoiced CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_used_quantities_enhanced CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_used_quantities_otc CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_used_quantities CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_project_parts_stock_availability CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_project_machine_parts_aggregated CASCADE;

-- ============================================================================
-- ÉTAPE 2 : RECRÉER mv_project_machine_parts_aggregated
-- ============================================================================

CREATE MATERIALIZED VIEW mv_project_machine_parts_aggregated AS
SELECT 
  pmp.machine_id,
  pmp.part_number,
  MAX(pmp.description) as description,
  SUM(pmp.quantity_required) as quantity_required
FROM project_machine_parts pmp
GROUP BY pmp.machine_id, pmp.part_number;

CREATE UNIQUE INDEX idx_mv_parts_agg_unique ON mv_project_machine_parts_aggregated(machine_id, part_number);
CREATE INDEX idx_mv_parts_agg_machine ON mv_project_machine_parts_aggregated(machine_id);
CREATE INDEX idx_mv_parts_agg_part ON mv_project_machine_parts_aggregated(part_number);

-- ============================================================================
-- ÉTAPE 3 : RECRÉER mv_project_parts_used_quantities (OR-based)
-- ============================================================================

CREATE MATERIALIZED VIEW mv_project_parts_used_quantities AS
SELECT 
  pmp.machine_id,
  pmp.part_number,
  COALESCE(SUM(o.qte_livree), 0) as quantity_used
FROM mv_project_machine_parts_aggregated pmp
LEFT JOIN project_machine_order_numbers pmon ON pmon.machine_id = pmp.machine_id
LEFT JOIN orders o ON o.num_or = pmon.order_number 
  AND o.part_number = pmp.part_number
  AND o.qte_livree > 0
GROUP BY pmp.machine_id, pmp.part_number;

CREATE UNIQUE INDEX idx_mv_used_unique ON mv_project_parts_used_quantities(machine_id, part_number);
CREATE INDEX idx_mv_used_machine ON mv_project_parts_used_quantities(machine_id);
CREATE INDEX idx_mv_used_part ON mv_project_parts_used_quantities(part_number);

-- ============================================================================
-- ÉTAPE 4 : RECRÉER mv_project_parts_used_quantities_otc (OTC-based)
-- ============================================================================

CREATE MATERIALIZED VIEW mv_project_parts_used_quantities_otc AS
SELECT 
  pm.project_id,
  pmp.machine_id,
  pmp.part_number,
  COALESCE(
    (SELECT SUM(otc.qte_livree)
     FROM otc_orders otc
     WHERE otc.num_bl IS NOT NULL 
       AND otc.num_bl != ''
       AND otc.reference = pmp.part_number
       AND EXISTS (
         SELECT 1 FROM project_supplier_orders pso
         WHERE pso.project_id = pm.project_id
           AND pso.supplier_order IN (
             SELECT DISTINCT supplier_order 
             FROM parts 
             WHERE part_ordered = pmp.part_number
           )
       )
    ), 0
  ) as quantity_used_otc
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id;

CREATE UNIQUE INDEX idx_mv_used_otc_unique ON mv_project_parts_used_quantities_otc(machine_id, part_number);
CREATE INDEX idx_mv_used_otc_project ON mv_project_parts_used_quantities_otc(project_id);
CREATE INDEX idx_mv_used_otc_machine ON mv_project_parts_used_quantities_otc(machine_id);
CREATE INDEX idx_mv_used_otc_part ON mv_project_parts_used_quantities_otc(part_number);

-- ============================================================================
-- ÉTAPE 5 : RECRÉER mv_project_parts_used_quantities_enhanced (Hybrid)
-- ============================================================================

CREATE MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced AS
SELECT 
  pm.project_id,
  pmp.machine_id,
  pmp.part_number,
  CASE 
    WHEN COALESCE(p.calculation_method, 'or_based') = 'or_based' THEN
      COALESCE(used_or.quantity_used, 0)
    WHEN p.calculation_method = 'otc_based' THEN
      COALESCE(used_otc.quantity_used_otc, 0)
    ELSE COALESCE(used_or.quantity_used, 0)
  END as quantity_used
FROM mv_project_machine_parts_aggregated pmp
JOIN project_machines pm ON pm.id = pmp.machine_id
LEFT JOIN projects p ON p.id = pm.project_id
LEFT JOIN mv_project_parts_used_quantities used_or 
  ON used_or.machine_id = pmp.machine_id AND used_or.part_number = pmp.part_number
LEFT JOIN mv_project_parts_used_quantities_otc used_otc
  ON used_otc.machine_id = pmp.machine_id AND used_otc.part_number = pmp.part_number;

CREATE UNIQUE INDEX idx_mv_used_enhanced_unique ON mv_project_parts_used_quantities_enhanced(machine_id, part_number);
CREATE INDEX idx_mv_used_enhanced_project ON mv_project_parts_used_quantities_enhanced(project_id);
CREATE INDEX idx_mv_used_enhanced_machine ON mv_project_parts_used_quantities_enhanced(machine_id);
CREATE INDEX idx_mv_used_enhanced_part ON mv_project_parts_used_quantities_enhanced(part_number);

-- ============================================================================
-- ÉTAPE 6 : RECRÉER mv_project_parts_transit_invoiced
-- ============================================================================

CREATE MATERIALIZED VIEW mv_project_parts_transit_invoiced AS
SELECT
  pm.project_id,
  p.part_ordered as part_number,
  -- Backorders = commandées mais non facturées (quantity_in_transit dans l'UI)
  COALESCE(SUM(
    CASE 
      WHEN p.invoice_number IS NULL OR p.invoice_number = '' THEN p.quantity_requested
      ELSE 0
    END
  ), 0) as quantity_in_transit,
  -- In Transit = facturées mais non réceptionnées (quantity_invoiced dans l'UI)
  COALESCE(SUM(
    CASE 
      WHEN p.invoice_number IS NOT NULL AND p.invoice_number != '' THEN p.quantity_requested
      ELSE 0
    END
  ), 0) as quantity_invoiced
FROM project_supplier_orders pso
JOIN parts p ON p.supplier_order = pso.supplier_order
JOIN project_machines pm ON pm.project_id = pso.project_id
WHERE p.status NOT IN ('Griefed', 'Cancelled')
  AND LOWER(COALESCE(p.comments, '')) != 'delivery completed'
GROUP BY pm.project_id, p.part_ordered;

CREATE UNIQUE INDEX idx_mv_transit_unique ON mv_project_parts_transit_invoiced(project_id, part_number);
CREATE INDEX idx_mv_transit_project ON mv_project_parts_transit_invoiced(project_id);
CREATE INDEX idx_mv_transit_part ON mv_project_parts_transit_invoiced(part_number);

-- ============================================================================
-- ÉTAPE 7 : RECRÉER mv_project_parts_stock_availability (avec dédoublonnage)
-- ============================================================================

CREATE MATERIALIZED VIEW mv_project_parts_stock_availability AS
WITH global_stock AS (
  -- Dédoublonner stock_dispo : garder uniquement la première ligne par part_number
  SELECT 
    part_number,
    qté_gdc as total_gdc,
    qté_jdc as total_jdc,
    qté_cat_network as total_cat_network,
    qté_succ_10 as total_succ_10,
    qté_succ_11 as total_succ_11,
    qté_succ_12 as total_succ_12,
    qté_succ_13 as total_succ_13,
    qté_succ_14 as total_succ_14,
    qté_succ_19 as total_succ_19,
    qté_succ_20 as total_succ_20,
    qté_succ_21 as total_succ_21,
    qté_succ_22 as total_succ_22,
    qté_succ_24 as total_succ_24,
    qté_succ_30 as total_succ_30,
    qté_succ_40 as total_succ_40,
    qté_succ_50 as total_succ_50,
    qté_succ_60 as total_succ_60,
    qté_succ_70 as total_succ_70,
    qté_succ_80 as total_succ_80,
    qté_succ_90 as total_succ_90
  FROM (
    SELECT 
      *,
      ROW_NUMBER() OVER (PARTITION BY part_number ORDER BY part_number) as rn
    FROM stock_dispo
  ) deduped
  WHERE rn = 1
),
project_stock AS (
  -- Stock disponible par projet selon les branches configurées
  SELECT 
    pm.project_id,
    pmp.part_number,
    COALESCE(
      COALESCE(gs.total_gdc, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'gdc') THEN 1 ELSE 0 END +
      COALESCE(gs.total_jdc, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'jdc') THEN 1 ELSE 0 END +
      COALESCE(gs.total_cat_network, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'cat_network') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_10, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_10') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_11, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_11') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_12, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_12') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_13, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_13') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_14, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_14') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_19, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_19') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_20, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_20') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_21, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_21') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_22, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_22') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_24, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_24') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_30, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_30') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_40, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_40') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_50, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_50') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_60, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_60') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_70, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_70') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_80, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_80') THEN 1 ELSE 0 END +
      COALESCE(gs.total_succ_90, 0) * CASE WHEN EXISTS(SELECT 1 FROM project_branches WHERE project_id = pm.project_id AND branch_code = 'succ_90') THEN 1 ELSE 0 END,
      0
    ) as quantity_available
  FROM mv_project_machine_parts_aggregated pmp
  JOIN project_machines pm ON pm.id = pmp.machine_id
  LEFT JOIN global_stock gs ON gs.part_number = pmp.part_number
  GROUP BY pm.project_id, pmp.part_number, gs.total_gdc, gs.total_jdc, gs.total_cat_network,
           gs.total_succ_10, gs.total_succ_11, gs.total_succ_12, gs.total_succ_13, gs.total_succ_14,
           gs.total_succ_19, gs.total_succ_20, gs.total_succ_21, gs.total_succ_22, gs.total_succ_24,
           gs.total_succ_30, gs.total_succ_40, gs.total_succ_50, gs.total_succ_60, gs.total_succ_70,
           gs.total_succ_80, gs.total_succ_90
)
SELECT 
  project_id,
  part_number,
  quantity_available
FROM project_stock;

CREATE UNIQUE INDEX idx_mv_stock_avail_unique ON mv_project_parts_stock_availability(project_id, part_number);
CREATE INDEX idx_mv_stock_avail_project ON mv_project_parts_stock_availability(project_id);
CREATE INDEX idx_mv_stock_avail_part ON mv_project_parts_stock_availability(part_number);

-- ============================================================================
-- ÉTAPE 8 : CRÉER mv_project_analytics_complete avec allocation progressive
-- ============================================================================

CREATE MATERIALIZED VIEW mv_project_analytics_complete AS
WITH machine_chronology AS (
  -- Classer les machines par ordre chronologique (created_at, puis id)
  SELECT 
    pm.id as machine_id,
    pm.project_id,
    pm.name as machine_name,
    pm.created_at,
    ROW_NUMBER() OVER (PARTITION BY pm.project_id ORDER BY pm.created_at, pm.id) as creation_rank
  FROM project_machines pm
),
parts_with_requirements AS (
  -- Associer les pièces aux machines
  SELECT 
    mc.machine_id,
    mc.project_id,
    mc.machine_name,
    mc.creation_rank,
    pmp.part_number,
    pmp.description,
    pmp.quantity_required
  FROM mv_project_machine_parts_aggregated pmp
  JOIN machine_chronology mc ON mc.machine_id = pmp.machine_id
),
global_resources AS (
  -- Calculer les ressources globales par projet et par pièce
  SELECT
    pm.project_id,
    pmp.part_number,
    MAX(COALESCE(stock.quantity_available, 0)) as total_stock_available,
    MAX(COALESCE(transit.quantity_invoiced, 0)) as total_invoiced,      -- Facturées (PRIORITÉ 2)
    MAX(COALESCE(transit.quantity_in_transit, 0)) as total_in_transit   -- Commandées non facturées (PRIORITÉ 3)
  FROM mv_project_machine_parts_aggregated pmp
  JOIN project_machines pm ON pm.id = pmp.machine_id
  LEFT JOIN mv_project_parts_stock_availability stock
    ON stock.project_id = pm.project_id AND stock.part_number = pmp.part_number
  LEFT JOIN mv_project_parts_transit_invoiced transit
    ON transit.project_id = pm.project_id AND transit.part_number = pmp.part_number
  GROUP BY pm.project_id, pmp.part_number
),
base_data AS (
  -- Combiner les données de base avec quantity_used
  SELECT
    pwr.machine_id,
    pwr.project_id,
    pwr.machine_name,
    pwr.creation_rank,
    pwr.part_number,
    pwr.description,
    pwr.quantity_required,
    COALESCE(used.quantity_used, 0) as quantity_used,
    gr.total_stock_available,
    gr.total_invoiced,
    gr.total_in_transit,
    -- ÉTAPE 0 : Calculer le besoin restant après Qty Used
    GREATEST(0, pwr.quantity_required - COALESCE(used.quantity_used, 0)) as remaining_need
  FROM parts_with_requirements pwr
  LEFT JOIN global_resources gr
    ON gr.project_id = pwr.project_id AND gr.part_number = pwr.part_number
  LEFT JOIN mv_project_parts_used_quantities_enhanced used
    ON used.machine_id = pwr.machine_id AND used.part_number = pwr.part_number
),
allocation_step1_available AS (
  -- ÉTAPE 1 : Allocation progressive depuis Available (Stock)
  SELECT
    *,
    COALESCE(
      SUM(remaining_need) OVER (
        PARTITION BY project_id, part_number
        ORDER BY creation_rank
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
      ), 0
    ) as cumulative_consumed_stock,
    LEAST(
      remaining_need,
      GREATEST(0, total_stock_available - COALESCE(
        SUM(remaining_need) OVER (
          PARTITION BY project_id, part_number
          ORDER BY creation_rank
          ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ), 0
      ))
    ) as qty_from_available
  FROM base_data
),
allocation_step2_invoiced AS (
  -- ÉTAPE 2 : Allocation progressive depuis Invoiced (PRIORITÉ 2 - Facturées non réceptionnées)
  SELECT
    *,
    GREATEST(0, remaining_need - qty_from_available) as need_after_available,
    COALESCE(
      SUM(GREATEST(0, remaining_need - qty_from_available)) OVER (
        PARTITION BY project_id, part_number
        ORDER BY creation_rank
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
      ), 0
    ) as cumulative_consumed_invoiced,
    LEAST(
      GREATEST(0, remaining_need - qty_from_available),
      GREATEST(0, total_invoiced - COALESCE(
        SUM(GREATEST(0, remaining_need - qty_from_available)) OVER (
          PARTITION BY project_id, part_number
          ORDER BY creation_rank
          ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ), 0
      ))
    ) as qty_from_invoiced
  FROM allocation_step1_available
),
allocation_step3_in_transit AS (
  -- ÉTAPE 3 : Allocation progressive depuis In Transit (PRIORITÉ 3 - Commandées non facturées)
  SELECT
    *,
    GREATEST(0, need_after_available - qty_from_invoiced) as need_after_invoiced,
    COALESCE(
      SUM(GREATEST(0, need_after_available - qty_from_invoiced)) OVER (
        PARTITION BY project_id, part_number
        ORDER BY creation_rank
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
      ), 0
    ) as cumulative_consumed_in_transit,
    LEAST(
      GREATEST(0, need_after_available - qty_from_invoiced),
      GREATEST(0, total_in_transit - COALESCE(
        SUM(GREATEST(0, need_after_available - qty_from_invoiced)) OVER (
          PARTITION BY project_id, part_number
          ORDER BY creation_rank
          ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ), 0
      ))
    ) as qty_from_in_transit
  FROM allocation_step2_invoiced
)
-- RÉSULTAT FINAL
SELECT
  machine_id,
  project_id,
  machine_name,
  part_number,
  description,
  quantity_required,
  qty_from_available as quantity_available,          -- Stock alloué
  quantity_used,                                      -- Déjà utilisé (priorité absolue)
  qty_from_in_transit as quantity_in_transit,         -- Backorders (commandées non facturées) - UI
  qty_from_invoiced as quantity_invoiced,             -- In Transit (facturées non réceptionnées) - UI
  -- ÉTAPE 4 : Calculer quantity_missing
  GREATEST(0, quantity_required - quantity_used - qty_from_available - qty_from_invoiced - qty_from_in_transit) as quantity_missing,
  -- Latest ETA : date de livraison prévue
  (
    SELECT MAX(p.eta)
    FROM project_supplier_orders pso
    JOIN parts p ON p.supplier_order = pso.supplier_order
    WHERE pso.project_id = allocation_step3_in_transit.project_id
      AND p.part_ordered = allocation_step3_in_transit.part_number
      AND p.status NOT IN ('Griefed', 'Cancelled')
      AND LOWER(COALESCE(p.comments, '')) != 'delivery completed'
      AND p.eta IS NOT NULL
      AND p.eta != ''
  ) as latest_eta
FROM allocation_step3_in_transit;

-- Indexes pour la performance
CREATE UNIQUE INDEX idx_mv_analytics_unique ON mv_project_analytics_complete(project_id, machine_id, part_number);
CREATE INDEX idx_mv_analytics_project ON mv_project_analytics_complete(project_id);
CREATE INDEX idx_mv_analytics_machine ON mv_project_analytics_complete(machine_id);
CREATE INDEX idx_mv_analytics_part ON mv_project_analytics_complete(part_number);

