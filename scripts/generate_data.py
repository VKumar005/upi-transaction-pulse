# ============================================
# UPI Transaction Pulse: Data Generator
# Generates realistic UPI transaction data
# ============================================

import pandas as pd
import numpy as np
from faker import Faker
import random
import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from datetime import datetime, timedelta

load_dotenv()
fake = Faker('en_IN')
random.seed(42)
np.random.seed(42)

# ============================================
# CONFIG
# ============================================
NUM_USERS       = 5000
NUM_MERCHANTS   = 500
NUM_TRANSACTIONS = 500000

# ============================================
# REFERENCE DATA
# ============================================
STATES = [
    ("Maharashtra", "West", "Tier1"),
    ("Karnataka", "South", "Tier1"),
    ("Tamil Nadu", "South", "Tier1"),
    ("Delhi", "North", "Tier1"),
    ("Telangana", "South", "Tier1"),
    ("Gujarat", "West", "Tier1"),
    ("West Bengal", "East", "Tier2"),
    ("Rajasthan", "North", "Tier2"),
    ("Uttar Pradesh", "North", "Tier2"),
    ("Madhya Pradesh", "Central", "Tier2"),
    ("Punjab", "North", "Tier2"),
    ("Haryana", "North", "Tier2"),
    ("Kerala", "South", "Tier2"),
    ("Andhra Pradesh", "South", "Tier2"),
    ("Odisha", "East", "Tier3"),
    ("Bihar", "East", "Tier3"),
    ("Jharkhand", "East", "Tier3"),
    ("Chhattisgarh", "Central", "Tier3"),
    ("Assam", "East", "Tier3"),
    ("Himachal Pradesh", "North", "Tier3"),
]

MERCHANT_CATEGORIES = [
    "Food & Dining", "Retail & Shopping", "Travel & Transport",
    "Entertainment", "Healthcare", "Education",
    "Utilities & Bills", "Groceries", "Electronics", "Fashion"
]

BANKS = [
    "SBI", "HDFC Bank", "ICICI Bank", "Axis Bank",
    "Kotak Mahindra", "Punjab National Bank", "Bank of Baroda",
    "Canara Bank", "Union Bank", "Yes Bank"
]

AGE_GROUPS  = ["18-25", "26-35", "36-50", "50+"]
GENDERS     = ["Male", "Female", "Other"]
DEVICES     = ["Mobile", "Web", "POS"]
STATUSES    = ["SUCCESS", "FAILED", "PENDING"]
FAIL_REASONS = [
    "Insufficient funds", "Bank server down",
    "Wrong UPI PIN", "Daily limit exceeded",
    "Beneficiary account blocked", "Network timeout"
]

# Festival dates in 2023-2024
FESTIVAL_DATES = {
    datetime(2023, 10, 24),  # Dussehra
    datetime(2023, 11, 12),  # Diwali
    datetime(2023, 11, 13),  # Diwali
    datetime(2024, 1, 14),   # Pongal/Makar Sankranti
    datetime(2024, 3, 25),   # Holi
    datetime(2024, 4, 14),   # Tamil New Year
    datetime(2024, 10, 2),   # Gandhi Jayanti
    datetime(2024, 10, 12),  # Dussehra
    datetime(2024, 11, 1),   # Diwali
}

# ============================================
# GENERATORS
# ============================================

def generate_states():
    rows = []
    for i, (name, region, tier) in enumerate(STATES, start=1):
        rows.append({
            "state_id":   i,
            "state_name": name,
            "region":     region,
            "tier":       tier
        })
    return pd.DataFrame(rows)


def generate_merchants(states_df):
    rows = []
    for i in range(1, NUM_MERCHANTS + 1):
        state = states_df.sample(1).iloc[0]
        rows.append({
            "merchant_id":   i,
            "merchant_name": fake.company(),
            "category":      random.choice(MERCHANT_CATEGORIES),
            "city":          fake.city(),
            "state_id":      int(state["state_id"])
        })
    return pd.DataFrame(rows)


def generate_users(states_df):
    rows = []
    for i in range(1, NUM_USERS + 1):
        state = states_df.sample(1).iloc[0]
        rows.append({
            "user_id":   i,
            "age_group": random.choice(AGE_GROUPS),
            "gender":    random.choices(GENDERS, weights=[50, 45, 5])[0],
            "state_id":  int(state["state_id"]),
            "bank":      random.choice(BANKS)
        })
    return pd.DataFrame(rows)


def generate_time_dim():
    start = datetime(2023, 1, 1)
    end   = datetime(2024, 12, 31)
    rows  = []
    i     = 1

    current = start
    while current <= end:
        rows.append({
            "time_id":         i,
            "txn_timestamp":   current,
            "hour":            current.hour,
            "day":             current.day,
            "month":           current.month,
            "year":            current.year,
            "day_of_week":     current.strftime("%A"),
            "is_weekend":      current.weekday() >= 5,
            "is_festival_day": current.date() in {d.date() for d in FESTIVAL_DATES}
        })
        current += timedelta(hours=1)
        i += 1

    return pd.DataFrame(rows)


def generate_transactions(users_df, merchants_df, time_df):
    rows = []

    # Weighted status — realistic UPI success rate ~92%
    status_weights = [92, 6, 2]

    # Fraud rate ~2% overall but higher on certain categories
    high_fraud_categories = {"Travel & Transport", "Electronics", "Fashion"}
    merchant_fraud_map = {
        row["merchant_id"]: row["category"] in high_fraud_categories
        for _, row in merchants_df.iterrows()
    }

    print("Generating 500,000 transactions... this takes ~2-3 minutes")

    for i in range(1, NUM_TRANSACTIONS + 1):
        sender    = users_df.sample(1).iloc[0]
        receiver  = users_df.sample(1).iloc[0]
        merchant  = merchants_df.sample(1).iloc[0]
        time_row  = time_df.sample(1).iloc[0]

        status = random.choices(STATUSES, weights=status_weights)[0]

        # Fraud logic: 2% base, 5% for high-risk categories
        fraud_prob = 0.05 if merchant_fraud_map[merchant["merchant_id"]] else 0.02
        is_fraud   = random.random() < fraud_prob if status == "SUCCESS" else False

        failure_reason = None
        if status == "FAILED":
            failure_reason = random.choice(FAIL_REASONS)

        # Amount: varies by category
        category = merchant["category"]
        if category in ("Electronics",):
            amount = round(random.uniform(5000, 80000), 2)
        elif category in ("Travel & Transport",):
            amount = round(random.uniform(200, 15000), 2)
        elif category in ("Utilities & Bills",):
            amount = round(random.uniform(100, 5000), 2)
        elif category in ("Food & Dining", "Groceries"):
            amount = round(random.uniform(50, 2000), 2)
        else:
            amount = round(random.uniform(100, 10000), 2)

        rows.append({
            "transaction_id": f"TXN{i:07d}",
            "sender_id":      int(sender["user_id"]),
            "receiver_id":    int(receiver["user_id"]),
            "merchant_id":    int(merchant["merchant_id"]),
            "time_id":        int(time_row["time_id"]),
            "amount":         amount,
            "status":         status,
            "device_type":    random.choice(DEVICES),
            "is_fraud":       is_fraud,
            "failure_reason": failure_reason
        })

        if i % 50000 == 0:
            print(f"  {i:,} / {NUM_TRANSACTIONS:,} transactions generated...")

    return pd.DataFrame(rows)


# ============================================
# LOAD TO POSTGRESQL
# ============================================

def load_to_db(df, table_name, engine):
    print(f"Loading {len(df):,} rows into '{table_name}'...")
    df.to_sql(table_name, engine, if_exists="append", index=False)
    print(f"  Done: {table_name}")


def main():
    DB_URL = (
        f"postgresql://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}"
        f"@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
    )
    engine = create_engine(DB_URL)

    print("=== UPI Transaction Pulse: Data Generation ===\n")

    print("Step 1/5: Generating states...")
    states_df = generate_states()

    print("Step 2/5: Generating merchants...")
    merchants_df = generate_merchants(states_df)

    print("Step 3/5: Generating users...")
    users_df = generate_users(states_df)

    print("Step 4/5: Generating time dimension...")
    time_df = generate_time_dim()

    print("Step 5/5: Generating 500K transactions...")
    transactions_df = generate_transactions(users_df, merchants_df, time_df)

    print("\n=== Loading into PostgreSQL ===\n")
    load_to_db(states_df,       "states",       engine)
    load_to_db(merchants_df,    "merchants",     engine)
    load_to_db(users_df,        "users",         engine)
    load_to_db(time_df,         "time_dim",      engine)
    load_to_db(transactions_df, "transactions",  engine)

    print("\n=== All done! ===")
    print(f"States:       {len(states_df):,}")
    print(f"Merchants:    {len(merchants_df):,}")
    print(f"Users:        {len(users_df):,}")
    print(f"Time rows:    {len(time_df):,}")
    print(f"Transactions: {len(transactions_df):,}")


if __name__ == "__main__":
    main()