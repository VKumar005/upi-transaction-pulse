-- ============================================
-- UPI Transaction Pulse: Merchant Analysis
-- ============================================

-- Query 7: Top 10 merchants by revenue
-- Business question: Who are our highest value merchants?
-- ============================================
SELECT
    m.merchant_name,
    m.category,
    m.city,
    COUNT(t.transaction_id)                                AS total_txns,
    ROUND(SUM(t.amount), 2)                                AS total_revenue,
    ROUND(AVG(t.amount), 2)                                AS avg_txn_value
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE t.status = 'SUCCESS'
GROUP BY m.merchant_name, m.category, m.city
ORDER BY total_revenue DESC
LIMIT 10;


-- Query 8: Month-over-month GMV growth by category
-- Business question: Which categories are growing fastest?
-- ============================================
WITH monthly_gmv AS (
    SELECT
        m.category,
        td.year,
        td.month,
        ROUND(SUM(t.amount), 2)                            AS gmv
    FROM transactions t
    JOIN merchants m  ON t.merchant_id = m.merchant_id
    JOIN time_dim td  ON t.time_id     = td.time_id
    WHERE t.status = 'SUCCESS'
    GROUP BY m.category, td.year, td.month
)
SELECT
    category,
    year,
    month,
    gmv,
    LAG(gmv) OVER (PARTITION BY category ORDER BY year, month) AS prev_month_gmv,
    ROUND(
        (gmv - LAG(gmv) OVER (PARTITION BY category ORDER BY year, month))
        * 100.0 /
        NULLIF(LAG(gmv) OVER (PARTITION BY category ORDER BY year, month), 0)
    , 2)                                                   AS mom_growth_pct
FROM monthly_gmv
ORDER BY category, year, month;


-- Query 9: Failed transaction rate by merchant
-- Business question: Which merchants lose most revenue to failures?
-- ============================================
SELECT
    m.merchant_name,
    m.category,
    COUNT(*)                                               AS total_txns,
    SUM(CASE WHEN t.status = 'FAILED' THEN 1 ELSE 0 END)  AS failed_txns,
    ROUND(SUM(CASE WHEN t.status = 'FAILED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS failure_rate_pct,
    ROUND(SUM(CASE WHEN t.status = 'FAILED' THEN t.amount ELSE 0 END), 2) AS lost_revenue
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_name, m.category
ORDER BY lost_revenue DESC
LIMIT 15;


-- Query 10: Average basket size by category and city tier
-- Business question: Do tier1 cities spend more per transaction?
-- ============================================
SELECT
    m.category,
    s.tier,
    COUNT(t.transaction_id)                                AS txn_count,
    ROUND(AVG(t.amount), 2)                                AS avg_basket_size,
    ROUND(MAX(t.amount), 2)                                AS max_txn
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
JOIN states s    ON m.state_id    = s.state_id
WHERE t.status = 'SUCCESS'
GROUP BY m.category, s.tier
ORDER BY m.category, s.tier;


-- Query 11: Weekend vs weekday GMV by category
-- Business question: When should merchants run promotions?
-- ============================================
SELECT
    m.category,
    td.is_weekend,
    COUNT(*)                                               AS total_txns,
    ROUND(SUM(t.amount), 2)                                AS total_gmv,
    ROUND(AVG(t.amount), 2)                                AS avg_amount
FROM transactions t
JOIN merchants m  ON t.merchant_id = m.merchant_id
JOIN time_dim td  ON t.time_id     = td.time_id
WHERE t.status = 'SUCCESS'
GROUP BY m.category, td.is_weekend
ORDER BY m.category, td.is_weekend;