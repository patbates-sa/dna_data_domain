---
name: dbt-hub-spoke-mesh
description: Implement, migrate, review, or deploy dbt models in the enterprise Hub-and-Spoke Mesh architecture. Use for Silver domain hubs, Gold product spokes, cross-project refs, model access, contracts, versions, incremental patterns, orchestration, migration placement, or promotion gates.
---

# dbt Hub-and-Spoke Mesh

Apply this skill when designing or changing models in the enterprise domain/product Mesh. Treat Silver as the reusable domain interface and Gold as the consumer-specific product layer.

## Operating model

Use these project boundaries:

- Domain project: `dna_data_domain` owns reusable facts, dimensions, and domain-standard entities.
- Products project: `dna_data_products` owns consumer-specific transformations and final marts.
- Mesh boundary: the Silver mart layer.
- Cross-project consumption: reference only published Silver marts with explicit version-pinned `ref()` calls.

Use this target flow:

```text
Sources → Bronze (optional thin wrappers) → Silver stage → Silver int → Silver mart (public) → Gold stage → Gold int → Gold mart
```

Enforce this access model:

| Layer | Access | Purpose |
|---|---|---|
| Bronze | protected | Thin source wrappers |
| Silver stage / int | protected | Domain preparation and business logic |
| Silver mart | public | Published reusable Mesh interfaces |
| Gold stage / int | protected | Consumer-specific composition |
| Gold mart | public | Contracted consumer outputs |
```

## Decide Silver versus Gold placement

Place logic in Silver when it is reusable across products, defines a stable domain grain, creates a conformed dimension, performs identity resolution or temporal joining that establishes domain truth, or should evolve through a versioned contract.

Place logic in Gold when it serves one report, dashboard, or consumer; maps a legacy schema; performs consumer-specific joins or rollups; defines the final product contract; or contains consumer-facing incremental behavior and tests.

Do not place consumer-specific filters, renames, or presentation logic in Silver public marts.

## Enforce model layering

- Keep Bronze as optional, thin source wrappers.
- Use `models/bronze/<sourcename>/` for Bronze models.
- Use `models/silver/<domain>/stage/`, `int/`, and `mart/` for Domain models.
- Use `models/<product>/stage/`, `int/`, and `mart/` for Products models.
- Allow Gold stage to read Silver public marts.
- Do not allow Gold models to read Silver internals directly.
- Require every Gold flow to follow `stage → int → mart`.
- Do not use `source()` in Gold; consume published Silver interfaces.

## Use schemas and naming consistently

Use these schema conventions unless an approved exception exists:

- `<sourcename>_stage`: Domain Bronze views.
- `stage`: Domain Silver stage and int models.
- `stage`: Products Gold stage and int models.
- `<domain_schema>`: Domain Silver marts.
- `<consumer_schema>`: Products Gold marts.

Use `stg_*`, `int_*`, and business-meaningful mart names. Avoid flow-specific dataset patterns without approval. Never use `SELECT *` in Silver stage; select explicit columns to prevent schema drift.

## Configure Mesh interfaces

For every public Silver mart:

- Set model access to `public`.
- Assign a formal group and owner.
- Define a typed model contract.
- Add key tests in YAML.
- Add a model version when a breaking change requires an upgrade path.

For every Products consumer:

- Configure `packages.yml` and `dependencies.yml` as required by the project pattern.
- Disable producer models that are not owned or built by the consumer project.
- Use explicit version-pinned cross-project references:

```sql
{{ ref('dna_data_domain', 'model_name', version=1) }}
```

Remember that a cross-project `ref()` resolves a dependency; it does not trigger the upstream project to run.

## Choose materialization patterns

Use one approved pattern:

- Pattern A — Daily snapshot: use for simple date-grain flows with moderate complexity; Silver public marts may be incremental and Gold marts are incremental.
- Pattern B — Complex ETL replacement: use for identity-heavy, temporal, or memory-sensitive flows; use window-scoped Silver fact marts and retain full incremental history in Gold.

Do not make both Silver hub facts and Gold marts incremental unless specifically approved; duplicate merge and delete logic increases risk.

For incremental models:

- Set `on_schema_change = 'append_new_columns'` unless an approved exception exists.
- Wrap mutating pre-hooks in `is_incremental()`.
- Preserve the same business-date window across producer and consumer.
- Use the reusable load-window, batch-date, and incremental-delete macros where available.

## Run and orchestrate the projects

Enforce this execution order:

```text
Bronze refresh → Domain Silver run → Domain test → Products Gold run → Products test
```

Run Domain and Products as separate dbt Cloud jobs and normally as separate Airflow DAGs. Offset the consumer schedule until the producer completes. Ensure Bronze refresh completes before the Domain Silver run when applicable.

Use the standard task order:

```text
start → run → test → end
```

Prefer one DAG per project or per flow within that project, with clear ownership.

## Migrate and promote safely

Follow this migration sequence:

1. Inventory and scope the legacy flow.
2. Classify each transformation as Silver domain truth or Gold consumer logic.
3. Build Silver models and publish public marts.
4. Build Gold models using Mesh dependencies.
5. Add readiness gates, freshness checks, and tests.
6. Reconcile outputs against the legacy flow.
7. Deploy producer and consumer jobs.
8. Cut over in phases with a documented rollback plan.

Require these promotion gates:

- Consistent schemas across layers.
- Approved materialization pattern.
- Matching producer and consumer load windows.
- Contracts enforced on every public mart.
- Version-pinned cross-project refs.
- Strict Gold `stage → int → mart` structure.
- Passing builds and tests in both projects.
- Approved legacy reconciliation.
- Documented rollback plan.

## Review anti-patterns

Flag these patterns and propose the compliant alternative:

- Gold int reads Silver int directly → consume a published Silver mart through Gold stage.
- Legacy renames in Silver facts → move consumer presentation logic to Gold.
- Consumer-specific filters in Silver public marts → keep domain interfaces reusable.
- `source()` in Gold → use published Silver cross-project refs.
- Unversioned cross-project refs → pin the model version explicitly.
- Gold model skips stage or int → restore `stage → int → mart`.
- Both hub facts and Gold marts are incremental without approval → choose one controlled incremental boundary.
- Consumer job starts before producer completion → offset orchestration and validate freshness.

## Response workflow

When asked to create or modify a Mesh model:

1. Identify the owning project, domain/product layer, model grain, and intended consumers.
2. Decide Silver versus Gold placement using the placement rules.
3. Validate folder, schema, naming, access, contract, and version requirements.
4. Confirm cross-project refs and project dependencies.
5. Confirm materialization and load-window behavior.
6. Confirm job/DAG order, tests, freshness, reconciliation, and rollback gates.
7. Call out any anti-pattern or unverified assumption before proposing code.
