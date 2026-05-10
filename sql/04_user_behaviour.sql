-- ============================================
-- UPI Transaction Pulse: User Behaviour
-- ============================================

-- Query 12: Monthly active users (MAU) trend
-- Business question: Is the platform growing?
-- ============================================
SELECT
    td.year,
    td.month,
    COUNT(DISTINCT t.sender_id)                            AS monthly_active_users,
    COUNT(t.transaction_id)                                AS total_txns,
    ROUND(SUM(t.amount), 2)                                AS total_volume
FROM transactions t
JOIN time_dim td ON t.time_id = td.time_id
WHERE t.status = 'SUCCESS'
GROUP BY td.year, td.month
ORDER BY td.year, td.month;


-- Query 13: RFM user segmentation
-- Business question: Who are our most valuable users?
-- ============================================
WITH rfm AS (
    SELECT
        t.sender_id,
        MAX(td.txn_timestamp)                              AS last_txn_date,
        COUNT(t.transaction_id)                            AS frequency,
        ROUND(SUM(t.amount), 2)                            AS monetary
    FROM transactions t
    JOIN time_dim td ON t.time_id = td.time_id
    WHERE t.status = 'SUCCESS'
    GROUP BY t.sender_id
),
rfm_scored AS (
    SELECT
        sender_id,
        frequency,
        monetary,
        NTILE(4) OVER (ORDER BY last_txn_date DESC)        AS recency_score,
        NTILE(4) OVER (ORDER BY frequency DESC)            AS frequency_score,
        NTILE(4) OVER (ORDER BY monetary DESC)             AS monetary_score
    FROM rfm
)
SELECT
    sender_id,
    recency_score,
    frequency_score,
    monetary_score,
    (recency_score + frequency_score + monetary_score)     AS rfm_total,
    CASE
        WHEN (recency_score + frequency_score + monetary_score) >= 10 THEN 'Champion'
        WHEN (recency_score + frequency_score + monetary_score) >= 7  THEN 'Loyal'
        WHEN (recency_score + frequency_score + monetary_score) >= 5  THEN 'Potential'
        ELSE 'At Risk'
    END                                                    AS user_segment
FROM rfm_scored
ORDER BY rfm_total DESC;


-- Query 14: Device preference by age group
-- Business question: How do different age groups transact?
-- ============================================
SELECT
    u.age_group,
    t.device_type,
    COUNT(*)                                               AS txn_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER
          (PARTITION BY u.age_group), 2)                   AS pct_within_age_group
FROM transactions t
JOIN users u ON t.sender_id = u.user_id
GROUP BY u.age_group, t.device_type
ORDER BY u.age_group, txn_count DESC;


-- Query 15: Peak transaction hours per user segment
-- Business question: When do high-value users transact most?
-- ============================================
WITH user_segments AS (
    SELECT
        sender_id,
        CASE
            WHEN SUM(amount) > 500000 THEN 'High Value'
            WHEN SUM(amount) > 100000 THEN 'Mid Value'
            ELSE 'Low Value'
        END AS segment
    FROM transactions
    WHERE status = 'SUCCESS'
    GROUP BY sender_id
)
SELECT
    us.segment,
    td.hour,
    COUNT(*)                                               AS txn_count,
    ROUND(AVG(t.amount), 2)                                AS avg_amount
FROM transactions t
JOIN time_dim td     ON t.time_id   = td.time_id
JOIN user_segments us ON t.sender_id = us.sender_id
WHERE t.status = 'SUCCESS'
GROUP BY us.segment, td.hour
ORDER BY us.segment, txn_count DESC;


-- Query 16: Bank-wise success rate
-- Business question: Which banks have reliability issues?
-- ============================================
SELECT
    u.bank,
    COUNT(*)                                               AS total_txns,
    SUM(CASE WHEN t.status = 'SUCCESS' THEN 1 ELSE 0 END) AS success_txns,
    SUM(CASE WHEN t.status = 'FAILED'  THEN 1 ELSE 0 END) AS failed_txns,
    ROUND(SUM(CASE WHEN t.status = 'SUCCESS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS success_rate_pct,
    ROUND(AVG(t.amount), 2)                                AS avg_txn_amount
FROM transactions t
JOIN users u ON t.sender_id = u.user_id
GROUP BY u.bank
ORDER BY success_rate_pct DESC;


-- Query 17: Failure reason breakdown
-- Business question: Why are transactions failing?
-- ============================================
SELECT
    failure_reason,
    COUNT(*)                                               AS failure_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)    AS pct_of_all_failures,
    ROUND(AVG(amount), 2)                                  AS avg_failed_amount
FROM transactions
WHERE status = 'FAILED'
GROUP BY failure_reason
ORDER BY failure_count DESC;