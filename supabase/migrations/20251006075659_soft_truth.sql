/*
  # Create reporting views for optimized dashboard performance

  1. New Views
    - `reporting_order_status_summary` - Aggregated order status counts
    - `reporting_stock_location_summary` - Stock quantities by location
    - `reporting_monthly_trends` - Monthly order and completion trends
    - `reporting_top_customers` - Top 5 customers by order volume
    - `reporting_at_risk_parts` - Parts with insufficient stock
    - `reporting_general_stats` - General statistics for dashboard cards

  2. Performance Benefits
    - Pre-calculated aggregations reduce client-side processing
    - Smaller data transfers improve load times
    - Database-level calculations are more efficient
*/

-- 1. Vue pour la distribution des statuts des commandes
CREATE OR REPLACE VIEW public.reporting_order_status_summary AS
SELECT
    COALESCE(status, 'Pending') AS name,
    COUNT(*) AS value
FROM
    public.parts
GROUP BY
    COALESCE(status, 'Pending');

-- 2. Vue pour le stock par emplacement
CREATE OR REPLACE VIEW public.reporting_stock_location_summary AS
SELECT 'GDC' AS location, SUM(COALESCE(qté_gdc, 0)) AS quantity FROM public.stock_dispo
UNION ALL
SELECT 'JDC' AS location, SUM(COALESCE(qté_jdc, 0)) AS quantity FROM public.stock_dispo
UNION ALL
SELECT 'CAT Network' AS location, SUM(COALESCE(qté_cat_network, 0)) AS quantity FROM public.stock_dispo
UNION ALL
SELECT 'SUCC 10-14' AS location, 
    SUM(COALESCE(qté_succ_10,0) + COALESCE(qté_succ_11,0) + COALESCE(qté_succ_12,0) + COALESCE(qté_succ_13,0) + COALESCE(qté_succ_14,0)) AS quantity 
FROM public.stock_dispo
UNION ALL
SELECT 'SUCC 19-24' AS location, 
    SUM(COALESCE(qté_succ_19,0) + COALESCE(qté_succ_21,0) + COALESCE(qté_succ_22,0) + COALESCE(qté_succ_24,0)) AS quantity 
FROM public.stock_dispo
UNION ALL
SELECT 'SUCC 30-90' AS location, 
    SUM(COALESCE(qté_succ_30,0) + COALESCE(qté_succ_40,0) + COALESCE(qté_succ_50,0) + COALESCE(qté_succ_60,0) + COALESCE(qté_succ_70,0) + COALESCE(qté_succ_80,0) + COALESCE(qté_succ_90,0)) AS quantity 
FROM public.stock_dispo;

-- 3. Vue pour les tendances mensuelles
CREATE OR REPLACE VIEW public.reporting_monthly_trends AS
WITH parsed_dates AS (
    SELECT 
        date_cf,
        comments,
        CASE 
            WHEN date_cf ~ '^\d{2}/\d{2}/\d{4}$' THEN
                TO_DATE(date_cf, 'DD/MM/YYYY')
            ELSE NULL
        END AS parsed_date
    FROM public.parts
    WHERE date_cf IS NOT NULL AND date_cf != ''
),
monthly_data AS (
    SELECT
        TO_CHAR(parsed_date, 'YYYY-MM') AS month_key,
        TO_CHAR(parsed_date, 'Mon YY') AS month,
        COUNT(*) AS orders,
        COUNT(CASE WHEN LOWER(COALESCE(comments, '')) LIKE '%delivery completed%' THEN 1 END) AS completed
    FROM parsed_dates
    WHERE parsed_date IS NOT NULL
    GROUP BY parsed_date, TO_CHAR(parsed_date, 'YYYY-MM'), TO_CHAR(parsed_date, 'Mon YY')
)
SELECT 
    month,
    SUM(orders) AS orders,
    SUM(completed) AS completed
FROM monthly_data
GROUP BY month_key, month
ORDER BY month_key DESC
LIMIT 6;

-- 4. Vue pour les 5 meilleurs clients
CREATE OR REPLACE VIEW public.reporting_top_customers AS
SELECT
    INITCAP(TRIM(customer_name)) AS customer_name,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN LOWER(COALESCE(comments, '')) LIKE '%delivery completed%' THEN 1 END) AS completed_orders,
    ROUND(
        (COUNT(CASE WHEN LOWER(COALESCE(comments, '')) LIKE '%delivery completed%' THEN 1 END)::DECIMAL / COUNT(*)) * 100, 
        1
    ) AS completion_rate
FROM
    public.parts
WHERE
    customer_name IS NOT NULL 
    AND TRIM(customer_name) != ''
    AND LENGTH(TRIM(customer_name)) > 0
GROUP BY
    TRIM(customer_name)
HAVING COUNT(*) > 0
ORDER BY
    total_orders DESC
LIMIT 5;

-- 5. Vue pour les pièces à risque
CREATE OR REPLACE VIEW public.reporting_at_risk_parts AS
WITH stock_totals AS (
    SELECT 
        LOWER(TRIM(part_number)) AS part_key,
        COALESCE(qté_gdc, 0) + COALESCE(qté_jdc, 0) + COALESCE(qté_cat_network, 0) AS cat_stock,
        COALESCE(qté_succ_10, 0) + COALESCE(qté_succ_20, 0) + COALESCE(qté_succ_11, 0) + 
        COALESCE(qté_succ_12, 0) + COALESCE(qté_succ_13, 0) + COALESCE(qté_succ_14, 0) + 
        COALESCE(qté_succ_19, 0) + COALESCE(qté_succ_21, 0) + COALESCE(qté_succ_22, 0) + 
        COALESCE(qté_succ_24, 0) + COALESCE(qté_succ_30, 0) + COALESCE(qté_succ_40, 0) + 
        COALESCE(qté_succ_50, 0) + COALESCE(qté_succ_60, 0) + COALESCE(qté_succ_70, 0) + 
        COALESCE(qté_succ_80, 0) + COALESCE(qté_succ_90, 0) AS internal_stock
    FROM public.stock_dispo
    WHERE part_number IS NOT NULL AND TRIM(part_number) != ''
),
active_parts AS (
    SELECT 
        order_number,
        part_ordered,
        COALESCE(quantity_requested, 0) AS quantity_requested,
        customer_name,
        status,
        LOWER(TRIM(part_ordered)) AS part_key
    FROM public.parts
    WHERE 
        part_ordered IS NOT NULL 
        AND TRIM(part_ordered) != ''
        AND COALESCE(quantity_requested, 0) > 0
        AND NOT (LOWER(COALESCE(comments, '')) LIKE '%delivery completed%')
)
SELECT
    ap.order_number,
    ap.part_ordered,
    ap.quantity_requested,
    ap.customer_name,
    ap.status,
    COALESCE(st.cat_stock, 0) AS cat_stock,
    COALESCE(st.internal_stock, 0) AS internal_stock,
    COALESCE(st.cat_stock, 0) + COALESCE(st.internal_stock, 0) AS total_stock,
    CASE
        WHEN COALESCE(st.cat_stock, 0) + COALESCE(st.internal_stock, 0) = 0 THEN 'High'
        WHEN COALESCE(st.cat_stock, 0) + COALESCE(st.internal_stock, 0) < ap.quantity_requested THEN 'Medium'
        ELSE 'Low'
    END AS risk_level
FROM active_parts ap
LEFT JOIN stock_totals st ON ap.part_key = st.part_key
WHERE 
    COALESCE(st.cat_stock, 0) + COALESCE(st.internal_stock, 0) = 0
    OR COALESCE(st.cat_stock, 0) + COALESCE(st.internal_stock, 0) < ap.quantity_requested
ORDER BY
    CASE 
        WHEN COALESCE(st.cat_stock, 0) + COALESCE(st.internal_stock, 0) = 0 THEN 1
        WHEN COALESCE(st.cat_stock, 0) + COALESCE(st.internal_stock, 0) < ap.quantity_requested THEN 2
        ELSE 3
    END,
    ap.quantity_requested DESC;

-- 6. Vue pour les statistiques générales
CREATE OR REPLACE VIEW public.reporting_general_stats AS
WITH stock_stats AS (
    SELECT 
        COUNT(*) AS total_stock_items,
        COUNT(CASE 
            WHEN (COALESCE(qté_gdc, 0) + COALESCE(qté_jdc, 0) + COALESCE(qté_cat_network, 0) +
                  COALESCE(qté_succ_10, 0) + COALESCE(qté_succ_20, 0) + COALESCE(qté_succ_11, 0) + 
                  COALESCE(qté_succ_12, 0) + COALESCE(qté_succ_13, 0) + COALESCE(qté_succ_14, 0) + 
                  COALESCE(qté_succ_19, 0) + COALESCE(qté_succ_21, 0) + COALESCE(qté_succ_22, 0) + 
                  COALESCE(qté_succ_24, 0) + COALESCE(qté_succ_30, 0) + COALESCE(qté_succ_40, 0) + 
                  COALESCE(qté_succ_50, 0) + COALESCE(qté_succ_60, 0) + COALESCE(qté_succ_70, 0) + 
                  COALESCE(qté_succ_80, 0) + COALESCE(qté_succ_90, 0)) < 5 
            THEN 1 
        END) AS low_stock_items
    FROM public.stock_dispo
),
parts_stats AS (
    SELECT 
        COUNT(*) AS total_orders
    FROM public.parts
),
risk_stats AS (
    SELECT 
        COUNT(CASE WHEN risk_level = 'High' THEN 1 END) AS high_risk_parts
    FROM public.reporting_at_risk_parts
)
SELECT 
    ps.total_orders,
    ss.total_stock_items,
    ss.low_stock_items,
    rs.high_risk_parts
FROM parts_stats ps, stock_stats ss, risk_stats rs;