import os
import random

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.serialization import (
    Encoding,
    NoEncryption,
    PrivateFormat,
    load_pem_private_key,
)
import snowflake.connector

MODELS = [
    "stg_orders",
    "stg_customers",
    "stg_line_items",
    "stg_nations",
    "stg_parts",
    "stg_part_suppliers",
    "stg_regions",
    "stg_suppliers",
    "int_customer_flags",
    "int_customer_tier",
    "int_order_items",
    "int_part_suppliers",
    "fct_order_items",
    "fct_orders",
    "fct_agg_customer_orders",
    "fct_agg_monthly_gross_revenue",
    "fct_agg_returned_orders_by_month",
    "fct_agg_supplier_orders",
    "dim_customers_v1",
    "dim_customers_v2",
    "dim_parts",
    "dim_suppliers",
]

DATABASE = "DATA_ENGINEERING"
SCHEMA = "PRODUCTION"


def load_private_key():
    key_path = os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]
    passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "")
    passphrase_bytes = passphrase.encode("utf-8") if passphrase else None

    with open(key_path, "rb") as f:
        private_key = load_pem_private_key(f.read(), password=passphrase_bytes, backend=default_backend())

    return private_key.private_bytes(
        encoding=Encoding.DER,
        format=PrivateFormat.PKCS8,
        encryption_algorithm=NoEncryption(),
    )


def main():
    private_key_der = load_private_key()

    conn = snowflake.connector.connect(
        user=os.environ["SNOWFLAKE_USER"],
        account="CMVGRNF-SA_DEMO_2",
        warehouse="TRANSFORMING_V2",
        role="TRANSFORMER",
        database=DATABASE,
        schema=SCHEMA,
        private_key=private_key_der,
    )

    cur = conn.cursor()

    cur.execute("ALTER SESSION SET USE_CACHED_RESULT = FALSE")
    cur.execute("ALTER SESSION SET QUERY_TAG = 'dbt_demo_simulate_query_traffic'")

    query_count = 0
    for model in MODELS:
        hits = random.randint(10, 20)
        for _ in range(hits):
            offset = random.randint(0, 1000)
            cur.execute(
                f'SELECT * FROM "{DATABASE}"."{SCHEMA}".{model} ORDER BY 1 LIMIT 10 OFFSET {offset}'
            )
            query_count += 1

    cur.close()
    conn.close()

    print(f"Simulated query traffic complete. Executed {query_count} SELECTs.")


if __name__ == "__main__":
    main()
