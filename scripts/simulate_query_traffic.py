"""Simulate query traffic against the Data Engineering production warehouse.

Run on a schedule (see .github/workflows/simulate_query_traffic.yml), this
script fires a burst of harmless SELECTs at every production model so the demo
account always has fresh Snowflake query history to show in warehouse-monitoring
and observability dashboards.

Rather than hardcode the list of tables to query (which silently rots every time
a model is added, removed, renamed, or versioned), we ask dbt itself what is
currently built in production via the dbt Cloud Discovery (metadata) API, then
query exactly those relations at their real database/schema/alias.

Required environment variables (wired up in the workflow):
  SNOWFLAKE_USER                    - Snowflake login for the TRANSFORMER role
  SNOWFLAKE_PRIVATE_KEY_PATH        - path to the PEM private key (key-pair auth)
  SNOWFLAKE_PRIVATE_KEY_PASSPHRASE  - passphrase for that key (optional)
  DBT_SERVICE_TOKEN                 - dbt Cloud service token (Discovery API read)
  DBT_BASE_URL                      - dbt Cloud Admin API base, e.g.
                                      https://tr995.us1.dbt.com/api/v2
"""

import json
import os
import random
import urllib.error
import urllib.request
from urllib.parse import urlparse

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.serialization import (
    Encoding,
    NoEncryption,
    PrivateFormat,
    load_pem_private_key,
)
import snowflake.connector
import yaml

# dbt_project.yml lives one level up from this scripts/ directory. Resolving it
# relative to __file__ (not the cwd) keeps the script runnable from anywhere.
DBT_PROJECT_YML = os.path.join(os.path.dirname(__file__), "..", "dbt_project.yml")

# Materialization types that produce a physical relation we can SELECT from.
# Anything else the Discovery API might report (e.g. "ephemeral", which is
# inlined into downstream models and never built as its own object) is skipped
# so we don't emit queries against relations that don't exist.
QUERYABLE_MATERIALIZATIONS = {"table", "view", "incremental"}

# Discovery API GraphQL query. "%s" is the production environment ID.
# environment.applied is the *state that actually exists in the warehouse* (as
# opposed to .definition, which is what the code declares), so it reflects
# disabled models, versions, and aliases exactly as they were last built.
MODELS_QUERY = """
{
  environment(id: %s) {
    applied {
      models(first: 500) {
        edges {
          node {
            name
            alias
            schema
            database
            materializedType
          }
        }
      }
    }
  }
}
"""


def load_private_key():
    """Load the Snowflake key-pair private key and return it in the DER/PKCS8
    form that snowflake-connector-python expects for JWT (key-pair) auth.

    The workflow writes the key (a GitHub secret) to a temp file and points
    SNOWFLAKE_PRIVATE_KEY_PATH at it; the passphrase is optional."""
    key_path = os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]
    passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "")
    # cryptography wants bytes-or-None for the password, never an empty string.
    passphrase_bytes = passphrase.encode("utf-8") if passphrase else None

    # Read the PEM-encoded (encrypted) key from disk and decrypt it in memory.
    with open(key_path, "rb") as f:
        private_key = load_pem_private_key(f.read(), password=passphrase_bytes, backend=default_backend())

    # Re-serialize as unencrypted DER/PKCS8, the format the connector accepts.
    return private_key.private_bytes(
        encoding=Encoding.DER,
        format=PrivateFormat.PKCS8,
        encryption_algorithm=NoEncryption(),
    )


def discovery_api_url():
    """Derive the Discovery (metadata) API endpoint from the Admin API base URL.

    The two share a host but the metadata service lives on a `.metadata`
    subdomain inserted after the account prefix, so we only need one URL in
    config: DBT_BASE_URL. For example:
        https://tr995.us1.dbt.com/api/v2
        -> host  tr995.us1.dbt.com
        -> split tr995 | us1.dbt.com
        -> https://tr995.metadata.us1.dbt.com/graphql
    """
    prefix, rest = urlparse(os.environ["DBT_BASE_URL"]).hostname.split(".", 1)
    return f"https://{prefix}.metadata.{rest}/graphql"


def production_environment_id():
    """Return the production environment ID to query the Discovery API against.

    We reuse `defer-env-id` from dbt_project.yml: that is dbt's own pointer to
    the environment developers defer to, i.e. production. Reading it here means
    the environment ID lives in exactly one place and never has to be duplicated
    into CI config or kept in sync by hand."""
    with open(DBT_PROJECT_YML) as f:
        return yaml.safe_load(f)["dbt-cloud"]["defer-env-id"]


def fetch_production_models():
    """Ask the dbt Cloud Discovery API which models are actually built in the
    production environment right now, instead of hardcoding a model list that
    drifts every time a model is added, removed, renamed, or disabled.

    Returns a list of node dicts, each carrying the database/schema/alias needed
    to build a fully-qualified SELECT."""
    token = os.environ["DBT_SERVICE_TOKEN"]
    environment_id = production_environment_id()

    # GraphQL requests are POSTs with a JSON {"query": "..."} body.
    payload = json.dumps({"query": MODELS_QUERY % environment_id}).encode("utf-8")
    req = urllib.request.Request(
        discovery_api_url(),
        data=payload,
        headers={
            # Discovery API authenticates with a Bearer service token (note the
            # Admin API, by contrast, expects "Token <...>").
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    # A non-2xx status raises HTTPError; surface the response body so failures
    # (bad token, wrong env, etc.) are debuggable from the CI logs.
    try:
        with urllib.request.urlopen(req) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        raise SystemExit(f"Discovery API request failed: HTTP {e.code} {e.read().decode('utf-8')}")

    # GraphQL returns HTTP 200 even for query-level errors, so check explicitly.
    if "errors" in body:
        raise SystemExit(f"Discovery API returned errors: {body['errors']}")

    # Unwrap the GraphQL edges/node envelope and drop non-queryable materializations.
    edges = body["data"]["environment"]["applied"]["models"]["edges"]
    return [
        edge["node"]
        for edge in edges
        if edge["node"]["materializedType"] in QUERYABLE_MATERIALIZATIONS
    ]


def main():
    # Resolve credentials and the live production model set before opening a
    # connection, so a Discovery API problem fails fast without touching Snowflake.
    private_key_der = load_private_key()
    models = fetch_production_models()

    # Connect with the TRANSFORMER role on the demo warehouse via key-pair auth.
    conn = snowflake.connector.connect(
        user=os.environ["SNOWFLAKE_USER"],
        account="CMVGRNF-SA_DEMO_2",
        warehouse="TRANSFORMING_V2",
        role="TRANSFORMER",
        private_key=private_key_der,
    )

    cur = conn.cursor()

    # Defeat the result cache so every SELECT actually hits the warehouse and
    # shows up as real compute in query history (otherwise repeats are free).
    cur.execute("ALTER SESSION SET USE_CACHED_RESULT = FALSE")
    # Tag the queries so this simulated traffic is easy to find/filter later.
    cur.execute("ALTER SESSION SET QUERY_TAG = 'dbt_demo_simulate_query_traffic'")

    query_count = 0
    for model in models:
        # Hit each model a random number of times so the generated history looks
        # organic rather than uniform across tables.
        hits = random.randint(10, 20)
        for _ in range(hits):
            # A random OFFSET nudges each query to scan differently and further
            # varies the traffic pattern. Fully qualify with the model's own
            # database/schema/alias (from the Discovery API) rather than assuming
            # a single hardcoded location.
            offset = random.randint(0, 1000)
            cur.execute(
                f'SELECT * FROM "{model["database"]}"."{model["schema"]}".{model["alias"]} '
                f"ORDER BY 1 LIMIT 10 OFFSET {offset}"
            )
            query_count += 1

    cur.close()
    conn.close()

    print(f"Simulated query traffic complete. Executed {query_count} SELECTs across {len(models)} models.")


if __name__ == "__main__":
    main()
