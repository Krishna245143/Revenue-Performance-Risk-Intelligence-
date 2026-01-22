import pandas as pd
from pathlib import Path

# -----------------------------
# CONFIG
# -----------------------------
RAW_DIR = Path("data_raw")
CLEAN_DIR = Path("data_clean")

CLEAN_DIR.mkdir(exist_ok=True)

# -----------------------------
# COMMON CLEANING HELPERS
# -----------------------------
def clean_string_series(s: pd.Series) -> pd.Series:
    return (
        s.astype(str)
         .str.strip()
         .str.replace(r"\s+", " ", regex=True)
         .str.title()
         .replace({"Nan": None, "None": None, "": None})
    )

def parse_date_series(s: pd.Series) -> pd.Series:
    return pd.to_datetime(s, errors="coerce", dayfirst=True)

# -----------------------------
# ORDERS
# -----------------------------
orders = pd.read_csv(RAW_DIR / "orders.csv")

orders["region"] = clean_string_series(orders["region"])
orders["order_date"] = parse_date_series(orders["order_date"])

orders["order_value"] = pd.to_numeric(orders["order_value"], errors="coerce")
orders["discount_pct"] = pd.to_numeric(orders["discount_pct"], errors="coerce")

orders = orders.dropna(subset=["order_date", "region", "order_value"])

orders.to_csv(CLEAN_DIR / "orders_clean.csv", index=False)

# -----------------------------
# CUSTOMERS
# -----------------------------
customers = pd.read_csv(RAW_DIR / "customers.csv")

customers["region"] = clean_string_series(customers["region"])
customers["segment"] = clean_string_series(customers["segment"])
customers["signup_date"] = parse_date_series(customers["signup_date"])

customers = customers.dropna(subset=["customer_id", "region"])

customers.to_csv(CLEAN_DIR / "customers_clean.csv", index=False)

# -----------------------------
# PRODUCTS
# -----------------------------
products = pd.read_csv(RAW_DIR / "products.csv")

products["category"] = clean_string_series(products["category"])
products["base_price"] = pd.to_numeric(products["base_price"], errors="coerce")
products["margin_pct"] = pd.to_numeric(products["margin_pct"], errors="coerce")

products = products.dropna(subset=["product_id", "category"])

products.to_csv(CLEAN_DIR / "products_clean.csv", index=False)

# -----------------------------
# WEB EVENTS
# -----------------------------
web = pd.read_csv(RAW_DIR / "web_events.csv")

web["region"] = clean_string_series(web["region"])
web["event_type"] = clean_string_series(web["event_type"])
web["event_date"] = parse_date_series(web["event_date"])
web["count"] = pd.to_numeric(web["count"], errors="coerce").fillna(0)

web = web.dropna(subset=["event_date", "region"])

web.to_csv(CLEAN_DIR / "web_events_clean.csv", index=False)

# -----------------------------
# OPERATIONS
# -----------------------------
ops = pd.read_csv(RAW_DIR / "operations.csv")

ops["region"] = clean_string_series(ops["region"])
ops["date"] = parse_date_series(ops["date"])
ops["sku_availability_pct"] = pd.to_numeric(
    ops["sku_availability_pct"], errors="coerce"
)
ops["avg_delivery_days"] = pd.to_numeric(
    ops["avg_delivery_days"], errors="coerce"
)

ops = ops.dropna(subset=["date", "region"])

ops.to_csv(CLEAN_DIR / "operations_clean.csv", index=False)

# -----------------------------
# TARGETS (MOST IMPORTANT)
# -----------------------------
targets = pd.read_csv(RAW_DIR / "targets.csv")

targets["region"] = clean_string_series(targets["region"])
targets["month"] = parse_date_series(targets["month"])
targets["target_revenue"] = pd.to_numeric(
    targets["target_revenue"], errors="coerce"
)

targets = targets.dropna(subset=["region", "month", "target_revenue"])

# force month grain to YYYY-MM-01
targets["month"] = targets["month"].dt.to_period("M").dt.to_timestamp()

targets.to_csv(CLEAN_DIR / "targets_clean.csv", index=False)

print("✅ Data cleaning complete. Clean files written to:", CLEAN_DIR)
