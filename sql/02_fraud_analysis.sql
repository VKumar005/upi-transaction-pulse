-- ============================================
-- UPI Transaction Pulse: Fraud Analysis
-- ============================================

-- Query 1: Fraud rate by merchant category
-- Business question: Which categories are riskiest?
-- ============================================
WITH category_stats AS (
    SELECT
        m.category,
        COUNT(*)                                            AS total_txns,
        SUM(CASE WHEN t.is_fraud THEN 1 ELSE 0 END)        AS fraud_txns,
        ROUND(AVG(t.amount), 2)                            AS avg_amount
    FROM transactions t
    JOIN merchants m ON t.merchant_id = m.merchant_id
    GROUP BY m.category
)
SELECT
    category,
    total_txns,
    fraud_txns,
    ROUND(fraud_txns * 100.0 / total_txns, 2)             AS fraud_rate_pct,
    avg_amount,
    RANK() OVER (ORDER BY fraud_txns * 100.0 / total_txns DESC) AS risk_rank
FROM category_stats
ORDER BY fraud_rate_pct DESC;


-- Query 2: Fraud by hour of day
-- Business question: When do frauds peak?
-- ============================================
SELECT
    td.hour,
    COUNT(*)                                               AS total_txns,
    SUM(CASE WHEN t.is_fraud THEN 1 ELSE 0 END)           AS fraud_txns,
    ROUND(SUM(CASE WHEN t.is_fraud THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM transactions t
JOIN time_dim td ON t.time_id = td.time_id
GROUP BY td.hour
ORDER BY fraud_rate_pct DESC;


-- Query 3: Repeat fraud senders
-- Business question: Are there repeat offenders?
-- ============================================
SELECT
    sender_id,
    COUNT(*)                                               AS total_txns,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)             AS fraud_count,
    ROUND(SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN is_fraud THEN amount ELSE 0 END), 2) AS total_fraud_amount
FROM transactions
GROUP BY sender_id
HAVING SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) >= 2
ORDER BY fraud_count DESC
LIMIT 20;


-- Query 4: Fraud amount distribution
-- Business question: Are fraud transactions larger than normal?
-- ============================================
SELECT
    is_fraud,
    COUNT(*)                                               AS txn_count,
    ROUND(AVG(amount), 2)                                  AS avg_amount,
    ROUND(MIN(amount), 2)                                  AS min_amount,
    ROUND(MAX(amount), 2)                                  AS max_amount,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP
          (ORDER BY amount)::NUMERIC, 2)                   AS median_amount
FROM transactions
GROUP BY is_fraud;


-- Query 5: State-wise fraud heatmap
-- Business question: Which states have highest fraud exposure?
-- ============================================
SELECT
    s.state_name,
    s.region,
    s.tier,
    COUNT(t.transaction_id)                                AS total_txns,
    SUM(CASE WHEN t.is_fraud THEN 1 ELSE 0 END)           AS fraud_txns,
    ROUND(SUM(CASE WHEN t.is_fraud THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN t.is_fraud THEN t.amount ELSE 0 END), 2) AS fraud_value
FROM transactions t
JOIN merchants m  ON t.merchant_id = m.merchant_id
JOIN states s     ON m.state_id    = s.state_id
GROUP BY s.state_name, s.region, s.tier
ORDER BY fraud_rate_pct DESC;


-- Query 6: Festival day vs normal day fraud
-- Business question: Do frauds spike on festival days?
-- ============================================
SELECT
    td.is_festival_day,
    COUNT(*)                                               AS total_txns,
    SUM(CASE WHEN t.is_fraud THEN 1 ELSE 0 END)           AS fraud_txns,
    ROUND(SUM(CASE WHEN t.is_fraud THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(AVG(t.amount), 2)                                AS avg_txn_amount
FROM transactions t
JOIN time_dim td ON t.time_id = td.time_id
GROUP BY td.is_festival_day;