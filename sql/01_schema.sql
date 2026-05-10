-- ============================================
-- UPI Transaction Pulse: Star Schema
-- Database: upi_analytics
-- ============================================

-- Drop tables if they exist (safe re-run)
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS merchants CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS states CASCADE;
DROP TABLE IF EXISTS time_dim CASCADE;

-- ============================================
-- Dimension Table 1: states
-- ============================================
CREATE TABLE states (
    state_id      SERIAL PRIMARY KEY,
    state_name    VARCHAR(50) NOT NULL,
    region        VARCHAR(20) NOT NULL,  -- North, South, East, West, Central
    tier          VARCHAR(10) NOT NULL   -- Tier1, Tier2, Tier3
);

-- ============================================
-- Dimension Table 2: merchants
-- ============================================
CREATE TABLE merchants (
    merchant_id       SERIAL PRIMARY KEY,
    merchant_name     VARCHAR(100) NOT NULL,
    category          VARCHAR(50)  NOT NULL,  -- Food, Retail, Travel, etc.
    city              VARCHAR(50)  NOT NULL,
    state_id          INT REFERENCES states(state_id)
);

-- ============================================
-- Dimension Table 3: users
-- ============================================
CREATE TABLE users (
    user_id       SERIAL PRIMARY KEY,
    age_group     VARCHAR(20) NOT NULL,  -- 18-25, 26-35, 36-50, 50+
    gender        VARCHAR(10) NOT NULL,
    state_id      INT REFERENCES states(state_id),
    bank          VARCHAR(50) NOT NULL
);

-- ============================================
-- Dimension Table 4: time_dim
-- ============================================
CREATE TABLE time_dim (
    time_id          SERIAL PRIMARY KEY,
    txn_timestamp    TIMESTAMP   NOT NULL,
    hour             INT         NOT NULL,
    day              INT         NOT NULL,
    month            INT         NOT NULL,
    year             INT         NOT NULL,
    day_of_week      VARCHAR(10) NOT NULL,
    is_weekend       BOOLEAN     NOT NULL,
    is_festival_day  BOOLEAN     NOT NULL
);

-- ============================================
-- Fact Table: transactions
-- ============================================
CREATE TABLE transactions (
    transaction_id    VARCHAR(20)  PRIMARY KEY,
    sender_id         INT REFERENCES users(user_id),
    receiver_id       INT REFERENCES users(user_id),
    merchant_id       INT REFERENCES merchants(merchant_id),
    time_id           INT REFERENCES time_dim(time_id),
    amount            NUMERIC(12, 2) NOT NULL,
    status            VARCHAR(15) NOT NULL,   -- SUCCESS, FAILED, PENDING
    device_type       VARCHAR(15) NOT NULL,   -- Mobile, Web, POS
    is_fraud          BOOLEAN     NOT NULL DEFAULT FALSE,
    failure_reason    VARCHAR(100)            -- NULL if SUCCESS
);

-- ============================================
-- Indexes for query performance
-- ============================================
CREATE INDEX idx_txn_merchant   ON transactions(merchant_id);
CREATE INDEX idx_txn_sender     ON transactions(sender_id);
CREATE INDEX idx_txn_time       ON transactions(time_id);
CREATE INDEX idx_txn_fraud      ON transactions(is_fraud);
CREATE INDEX idx_txn_status     ON transactions(status);