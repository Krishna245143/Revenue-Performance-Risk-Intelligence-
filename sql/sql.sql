-- Always safe
SET SQL_SAFE_UPDATES = 0;
SET GLOBAL local_infile = 1;
SHOW VARIABLES LIKE 'local_infile';



DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date AS
SELECT DISTINCT
    order_date AS date,
    YEAR(order_date) AS year,
    MONTH(order_date) AS month,
    MONTHNAME(order_date) AS month_name
FROM orders;

DROP TABLE IF EXISTS dim_region;
CREATE TABLE dim_region AS
SELECT DISTINCT region
FROM customers;

DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer AS
SELECT
    customer_id,
    region,
    segment,
    signup_date,
    DATE_FORMAT(signup_date, '%Y-%m-01') AS cohort_month
FROM customers;

DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product AS
SELECT
    product_id,
    category,
    base_price,
    margin_pct
FROM products;


DROP TABLE IF EXISTS fact_revenue_daily;
CREATE TABLE fact_revenue_daily AS
SELECT
    o.order_date AS date,
    o.region,
    o.customer_id,
    o.product_id,
    COUNT(o.order_id) AS orders,
    SUM(o.order_value) AS revenue,
    SUM(o.order_value * p.margin_pct) AS gross_margin,
    AVG(o.discount_pct) AS avg_discount
FROM orders o
JOIN products p
  ON o.product_id = p.product_id
GROUP BY
    o.order_date,
    o.region,
    o.customer_id,
    o.product_id;


DROP TABLE IF EXISTS fact_funnel_daily;

CREATE TABLE fact_funnel_daily AS
SELECT
    event_date AS date,
    region,
    SUM(CASE WHEN event_type = 'visit' THEN count ELSE 0 END) AS visits,
    SUM(CASE WHEN event_type = 'add_to_cart' THEN count ELSE 0 END) AS add_to_cart,
    SUM(CASE WHEN event_type = 'purchase' THEN count ELSE 0 END) AS purchases,
    ROUND(
        SUM(CASE WHEN event_type = 'purchase' THEN count ELSE 0 END) /
        NULLIF(SUM(CASE WHEN event_type = 'visit' THEN count ELSE 0 END), 0),
        4
    ) AS conversion_rate
FROM web_events
GROUP BY event_date, region;

 

DROP TABLE IF EXISTS fact_operations_daily;
CREATE TABLE fact_operations_daily AS
SELECT
    date,
    region,
    sku_availability_pct,
    avg_delivery_days
FROM operations;


DROP TABLE IF EXISTS fact_revenue_daily;
CREATE TABLE fact_revenue_daily AS
SELECT
    o.order_date AS date,
    o.region,
    o.customer_id,
    o.product_id,
    COUNT(o.order_id) AS orders,
    SUM(o.order_value) AS revenue,
    SUM(o.order_value * p.margin_pct) AS gross_margin,
    AVG(o.discount_pct) AS avg_discount
FROM orders o
JOIN products p
  ON o.product_id = p.product_id
GROUP BY
    o.order_date,
    o.region,
    o.customer_id,
    o.product_id;


DROP TABLE IF EXISTS fact_funnel_daily;
CREATE TABLE fact_funnel_daily AS
SELECT
    event_date AS date,
    region,
    SUM(CASE WHEN event_type = 'Visit' THEN count ELSE 0 END) AS visits,
    SUM(CASE WHEN event_type = 'Add To Cart' THEN count ELSE 0 END) AS add_to_cart,
    SUM(CASE WHEN event_type = 'Purchase' THEN count ELSE 0 END) AS purchases,
    ROUND(
        SUM(CASE WHEN event_type = 'Purchase' THEN count ELSE 0 END) /
        NULLIF(SUM(CASE WHEN event_type = 'Visit' THEN count ELSE 0 END), 0),
        4
    ) AS conversion_rate
FROM web_events
GROUP BY event_date, region;


DROP TABLE IF EXISTS fact_operations_daily;
CREATE TABLE fact_operations_daily AS
SELECT
    date,
    region,
    sku_availability_pct,
    avg_delivery_days
FROM operations;


DROP TABLE IF EXISTS fact_revenue_health_monthly;
CREATE TABLE fact_revenue_health_monthly AS
SELECT
    DATE_FORMAT(fr.date, '%Y-%m-01') AS month,
    fr.region,
    SUM(fr.revenue) AS actual_revenue,
    MAX(t.target_revenue) AS target_revenue,
    SUM(fr.revenue) - MAX(t.target_revenue) AS variance,
    ROUND(SUM(fr.revenue) / NULLIF(MAX(t.target_revenue), 0), 2) AS target_achievement_ratio
FROM fact_revenue_daily fr
LEFT JOIN fact_targets_monthly t
  ON DATE_FORMAT(fr.date, '%Y-%m-01') = t.month
 AND fr.region = t.region
GROUP BY
    DATE_FORMAT(fr.date, '%Y-%m-01'),
    fr.region;


DROP TABLE IF EXISTS fact_revenue_at_risk;
CREATE TABLE fact_revenue_at_risk AS
SELECT
    fr.region,
    SUM(fr.revenue) AS current_revenue,
    AVG(ff.conversion_rate) AS avg_conversion_rate,
    CASE
        WHEN AVG(ff.conversion_rate) < 0.05 THEN SUM(fr.revenue) * 0.20
        WHEN AVG(ff.conversion_rate) < 0.10 THEN SUM(fr.revenue) * 0.10
        ELSE 0
    END AS revenue_at_risk
FROM fact_revenue_daily fr
LEFT JOIN fact_funnel_daily ff
  ON fr.region = ff.region
GROUP BY fr.region;


DROP TABLE IF EXISTS fact_opportunity_size;
CREATE TABLE fact_opportunity_size AS
SELECT
    r.region,
    r.revenue_at_risk,
    o.sku_availability_pct,
    o.avg_delivery_days,
    CASE
        WHEN o.sku_availability_pct < 85 THEN 'SKU Availability'
        WHEN o.avg_delivery_days > 5 THEN 'Delivery Delay'
        ELSE 'Pricing / Conversion'
    END AS primary_issue
FROM fact_revenue_at_risk r
LEFT JOIN fact_operations_daily o
  ON r.region = o.region;


DROP TABLE IF EXISTS fact_what_if_simulation;
CREATE TABLE fact_what_if_simulation AS
SELECT
    region,
    revenue_at_risk,
    ROUND(revenue_at_risk * 0.75, 2) AS conservative_recovery,
    ROUND(revenue_at_risk * 0.90, 2) AS realistic_recovery,
    ROUND(revenue_at_risk * 0.99, 2) AS aggressive_recovery
FROM fact_revenue_at_risk;

-- 1. Rebuild targets aggregate
DROP TABLE IF EXISTS fact_targets_monthly;
CREATE TABLE fact_targets_monthly AS
SELECT
    month,
    region,
    SUM(target_revenue) AS target_revenue
FROM targets
GROUP BY month, region;

-- 2. Rebuild revenue health (THIS is what KPIs read)
DROP TABLE IF EXISTS fact_revenue_health_monthly;
CREATE TABLE fact_revenue_health_monthly AS
SELECT
    DATE_FORMAT(fr.date, '%Y-%m-01') AS month,
    fr.region,
    SUM(fr.revenue) AS actual_revenue,
    MAX(t.target_revenue) AS target_revenue,
    SUM(fr.revenue) - MAX(t.target_revenue) AS variance,
    ROUND(
        SUM(fr.revenue) / NULLIF(MAX(t.target_revenue), 0),
        2
    ) AS target_achievement_ratio
FROM fact_revenue_daily fr
LEFT JOIN fact_targets_monthly t
  ON DATE_FORMAT(fr.date, '%Y-%m-01') = t.month
 AND fr.region = t.region
GROUP BY
    DATE_FORMAT(fr.date, '%Y-%m-01'),
    fr.region;

-- 3. Rebuild dependent facts
DROP TABLE IF EXISTS fact_revenue_at_risk;
CREATE TABLE fact_revenue_at_risk AS
SELECT
    fr.region,
    SUM(fr.revenue) AS current_revenue,
    AVG(ff.conversion_rate) AS avg_conversion_rate,
    CASE
        WHEN AVG(ff.conversion_rate) < 0.05 THEN SUM(fr.revenue) * 0.20
        WHEN AVG(ff.conversion_rate) < 0.10 THEN SUM(fr.revenue) * 0.10
        ELSE 0
    END AS revenue_at_risk
FROM fact_revenue_daily fr
LEFT JOIN fact_funnel_daily ff
  ON fr.region = ff.region
GROUP BY fr.region;

DROP TABLE IF EXISTS fact_what_if_simulation;
CREATE TABLE fact_what_if_simulation AS
SELECT
    region,
    revenue_at_risk,
    ROUND(revenue_at_risk * 0.75, 2) AS conservative_recovery,
    ROUND(revenue_at_risk * 0.85, 2) AS realistic_recovery,
    ROUND(revenue_at_risk * 0.95, 2) AS aggressive_recovery
FROM fact_revenue_at_risk;
