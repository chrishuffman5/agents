# dbt Core Architecture Deep Dive

## Execution Model

dbt Core is a command-line tool that transforms SQL SELECT statements into tables and views in the data warehouse. It follows the "T" in ELT -- data is already loaded into the warehouse, and dbt handles transformation.

### Compilation Pipeline

```
Source Files (.sql + .yml)
    |
    v
Parser (reads all project files, builds resource graph)
    |
    v
Jinja Compiler (resolves {{ ref() }}, {{ source() }}, {{ config() }}, macros)
    |
    v
Resolved DAG (topological sort of model dependencies)
    |
    v
DDL/DML Generator (wraps SELECT in CREATE TABLE AS / INSERT / MERGE)
    |
    v
Adapter (translates to platform-specific SQL dialect)
    |
    v
Warehouse Execution (parallel across threads)
```

**Parser**: Reads all `.sql` and `.yml` files in the project. Identifies models, tests, sources, macros, seeds, snapshots, and their properties. Produces an unresolved dependency graph.

**Jinja Compiler**: Resolves all Jinja2 expressions. `ref('model_name')` resolves to `database.schema.table` and registers a dependency edge. `source('src', 'table')` resolves to the raw table and registers a source dependency.

**DAG Resolution**: Orders models by dependencies (topological sort). Models with no upstream dependencies run first. Models with satisfied dependencies run next, up to the configured thread count.

**DDL/DML Generator**: Wraps compiled SELECT in the appropriate DDL based on materialization type. Views get `CREATE VIEW AS`. Tables get `CREATE TABLE AS`. Incrementals get `INSERT`/`MERGE`/`DELETE+INSERT` depending on strategy.

**Adapter**: Translates generic dbt operations into platform-specific SQL. Each adapter handles dialect differences (data types, DDL syntax, transaction semantics).

### Thread Parallelism

dbt executes models in parallel up to the configured thread count (default 1, recommended 4-8):

```yaml
# profiles.yml
my_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      threads: 8  # Up to 8 concurrent model builds
```

Independent models (no shared dependencies) run simultaneously. The DAG determines execution order. More threads = faster builds, but more concurrent warehouse load.

## Key Configuration Files

### dbt_project.yml

Central project configuration:

```yaml
name: 'jaffle_shop'
version: '1.0.0'
config-version: 2
profile: 'jaffle_shop'

model-paths: ["models"]
seed-paths: ["seeds"]
test-paths: ["tests"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

models:
  jaffle_shop:
    staging:
      +materialized: view
      +schema: staging
    intermediate:
      +materialized: ephemeral
    marts:
      +materialized: table
      +persist_docs:
        relation: true
        columns: true
```

### profiles.yml

Database connection credentials, typically at `~/.dbt/profiles.yml` (outside project for security):

```yaml
jaffle_shop:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: xy12345.us-east-1
      user: "{{ env_var('DBT_USER') }}"
      password: "{{ env_var('DBT_PASSWORD') }}"
      role: transformer
      database: analytics
      warehouse: transforming
      schema: dev_jsmith
      threads: 4
    prod:
      type: snowflake
      account: xy12345.us-east-1
      user: "{{ env_var('DBT_PROD_USER') }}"
      password: "{{ env_var('DBT_PROD_PASSWORD') }}"
      role: transformer
      database: analytics
      warehouse: transforming
      schema: analytics
      threads: 8
```

## Core Resource Types

### Models

SQL files in `models/` that define transformations. Each `.sql` file becomes a table or view:

```sql
-- models/marts/customers.sql
{{ config(materialized='table') }}

select
    c.customer_id,
    c.first_name,
    c.last_name,
    count(o.order_id) as order_count,
    sum(o.amount) as lifetime_value
from {{ ref('stg_customers') }} c
left join {{ ref('stg_orders') }} o on c.customer_id = o.customer_id
group by 1, 2, 3
```

### Sources

Declarations of raw tables loaded by upstream EL tools:

```yaml
sources:
  - name: jaffle_shop
    database: raw
    schema: jaffle_shop
    freshness:
      warn_after: {count: 12, period: hour}
      error_after: {count: 24, period: hour}
    loaded_at_field: _etl_loaded_at
    tables:
      - name: orders
      - name: customers
```

### Seeds

CSV files for static reference data (country codes, mappings). Best for files under 1MB:

```bash
dbt seed  # Loads all CSVs in seeds/ to the warehouse
```

### Snapshots

SCD Type 2 change tracking for mutable source tables:

```sql
{% snapshot orders_snapshot %}
{{ config(
    target_schema='snapshots',
    unique_key='id',
    strategy='timestamp',
    updated_at='updated_at',
) }}
select * from {{ source('jaffle_shop', 'orders') }}
{% endsnapshot %}
```

Adds metadata columns: `dbt_valid_from`, `dbt_valid_to`, `dbt_scd_id`, `dbt_updated_at`.

### User-Defined Functions (1.11+)

First-class dbt resources for warehouse-persisted functions:

- Defined in `functions/` directory
- Referenced via `{{ function('function_name') }}`
- Built as part of DAG during `dbt run`/`dbt build`
- Persist in the warehouse, reusable outside dbt (BI tools, ad-hoc queries)

## Materializations

### View (Default)

Creates a database view. No storage cost. Always reflects latest data. Slow for complex stacked transformations because the warehouse re-executes the full query chain on each read.

### Table

Creates a physical table via `CREATE TABLE AS SELECT`. Fast query performance. Data only refreshed on `dbt run`. Good for BI-facing models.

### Incremental

Processes only new/changed data on subsequent runs. Five built-in strategies:

| Strategy | Mechanism | Performance | Use Case |
|---|---|---|---|
| `append` | INSERT only | Fastest | Event logs (no dedup) |
| `merge` | MERGE (upsert) | Moderate | Small-medium tables with unique key |
| `delete+insert` | DELETE matching + INSERT | Fast at scale | Large tables (3.4x faster than merge at 500M rows) |
| `insert_overwrite` | Replace partitions | Fast | Date-partitioned tables |
| `microbatch` | Independent time batches | Parallel | Large time-series (1B+ rows) |

### Ephemeral

No database object created. SQL inlined as CTE into downstream models. Cannot be queried directly. Best for lightweight intermediate logic used by 1-2 downstream models.

### Materialized View

Database-native materialized view with optional auto-refresh. Not supported on all platforms. Snowflake uses Dynamic Tables instead.

## Jinja Templating

dbt uses Jinja2 as its templating engine, adding programming capabilities to SQL.

### Syntax

- `{{ expression }}` -- Output/evaluate (ref, source, var, config)
- `{% statement %}` -- Control flow (if, for, set, macro)
- `{# comment #}` -- Comments excluded from compiled SQL

### Key Functions

| Function | Purpose |
|---|---|
| `{{ ref('model') }}` | Model dependency reference |
| `{{ source('src', 'table') }}` | Source table reference |
| `{{ config(...) }}` | Model configuration |
| `{{ var('name') }}` | Project variable |
| `{{ env_var('NAME') }}` | Environment variable |
| `{{ this }}` | Current model relation |
| `{{ target }}` | Active connection target info |
| `{{ is_incremental() }}` | True if incremental and not full-refresh |
| `{{ adapter.dispatch('macro') }}` | Cross-adapter macro dispatch |

### Macros

Reusable code blocks in `macros/`:

```sql
{% macro cents_to_dollars(column_name, scale=2) %}
    ({{ column_name }} / 100)::numeric(16, {{ scale }})
{% endmacro %}

-- Usage in models: {{ cents_to_dollars('amount') }}
```

### Custom Schema/Alias

Override default schema and alias generation:

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if target.name == 'prod' and custom_schema_name -%}
        {{ custom_schema_name }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | default(target.schema, true) }}
    {%- endif -%}
{%- endmacro %}
```

## Adapters

dbt connects to data platforms via adapters that translate operations to platform-specific SQL.

### Officially Maintained

| Adapter | Package | Platform |
|---|---|---|
| PostgreSQL | `dbt-postgres` | PostgreSQL |
| Snowflake | `dbt-snowflake` | Snowflake |
| BigQuery | `dbt-bigquery` | Google BigQuery |
| Redshift | `dbt-redshift` | Amazon Redshift |
| Spark | `dbt-spark` | Apache Spark |
| Databricks | `dbt-databricks` | Databricks |
| Fabric | `dbt-fabric` | Microsoft Fabric |

### Notable Community Adapters

| Adapter | Package | Platform |
|---|---|---|
| DuckDB | `dbt-duckdb` | DuckDB (embedded OLAP) |
| Trino | `dbt-trino` | Trino / Starburst |
| ClickHouse | `dbt-clickhouse` | ClickHouse |

## Testing Framework

Four built-in generic tests: `unique`, `not_null`, `accepted_values`, `relationships`. Defined in YAML properties files. Singular tests are custom SQL in `tests/` that returns failing rows. Unit tests (1.8+) mock inputs in YAML for logic validation without database execution. Tests support severity levels (`error`/`warn`), thresholds (`warn_if`/`error_if`), and failure persistence (`store_failures: true`).

## Documentation System

- **YAML descriptions**: Add to any resource (models, columns, sources)
- **Doc blocks**: Longer-form markdown using `{% docs name %}...{% enddocs %}`
- **Generated site**: `dbt docs generate` + `dbt docs serve` for interactive DAG and catalog
- **persist_docs**: Push descriptions to the database as column/table comments

## dbt Mesh

Multi-project governance pattern: cross-project refs (`{{ ref('project', 'model') }}`), access modifiers (`private`/`protected`/`public`), model contracts (column names, types, constraints enforced at build time), model versions (API-style with deprecation dates), and groups (functional area ownership).

## MetricFlow and Semantic Layer

MetricFlow generates SQL for centralized metric definitions. Define semantic models (entities, dimensions, measures) and metrics (simple, derived, cumulative, ratio, conversion) in YAML. Full Semantic Layer API requires dbt Cloud; Core users get MetricFlow CLI.

## dbt Packages

External projects installed via `packages.yml` and `dbt deps`. Key packages: dbt-utils (surrogate keys, pivot, union, date spine), dbt-expectations (40+ tests), codegen (auto-generation), audit-helper (comparison), dbt-project-evaluator (project linting).

## dbt Artifacts

Generated in `target/` after each run: `manifest.json` (project graph), `run_results.json` (execution results and timing), `catalog.json` (schema metadata from `dbt docs generate`), `sources.json` (freshness results). Used for CI/CD state comparison (`state:modified`), programmatic analysis, and documentation.
