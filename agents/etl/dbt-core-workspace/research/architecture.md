# dbt Core Architecture

## Overview

dbt (data build tool) is a command-line tool that enables data teams to transform data in their warehouse by writing SQL select statements. dbt handles turning these select statements into tables and views, managing dependencies, and running tests. It follows a "T" in ELT pattern -- data is already loaded into the warehouse, and dbt handles the transformation layer.

## Project Structure

Every dbt project requires a `dbt_project.yml` file at its root. The standard directory layout:

```
my_project/
├── dbt_project.yml          # Required: project configuration
├── packages.yml             # Package dependencies
├── profiles.yml             # Connection profiles (typically ~/.dbt/)
├── models/                  # SQL transformation models
│   ├── staging/             # Source-conformed cleaning
│   ├── intermediate/        # Business logic transforms
│   └── marts/               # Business-ready output
├── seeds/                   # CSV files for static reference data
├── snapshots/               # SCD Type 2 change tracking
├── tests/                   # Singular data tests
├── macros/                  # Reusable Jinja SQL functions
├── analyses/                # Ad-hoc analytical queries (not materialized)
├── docs/                    # Documentation blocks
├── target/                  # Compiled output (gitignored)
│   ├── compiled/            # Compiled select statements
│   └── run/                 # Full DDL/DML executed
├── logs/                    # Log files
└── dbt_packages/            # Installed packages (gitignored)
```

## Key Configuration Files

### dbt_project.yml

The central project configuration file. Key properties:

| Property | Purpose |
|----------|---------|
| `name` | Project name (letters, digits, underscores) |
| `version` | Project version |
| `config-version: 2` | Config format version |
| `profile` | Links to connection profile in profiles.yml |
| `model-paths` | Where models live (default: `['models']`) |
| `seed-paths` | Where seeds live (default: `['seeds']`) |
| `test-paths` | Where singular tests live (default: `['tests']`) |
| `macro-paths` | Where macros live (default: `['macros']`) |
| `snapshot-paths` | Where snapshots live (default: `['snapshots']`) |
| `analysis-paths` | Where analyses live (default: `['analyses']`) |
| `docs-paths` | Where doc blocks live (default: `['docs']`) |
| `vars` | Project-level variables |

Example:
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
    marts:
      +materialized: table
```

### profiles.yml

Contains database connection credentials. Typically stored at `~/.dbt/profiles.yml` (outside the project for security). Maps profile names to target environments (dev, prod, ci).

```yaml
jaffle_shop:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: dev_user
      password: "{{ env_var('DBT_PASSWORD') }}"
      port: 5432
      dbname: analytics
      schema: dev_jsmith
      threads: 4
    prod:
      type: postgres
      host: prod-db.example.com
      user: prod_user
      password: "{{ env_var('DBT_PROD_PASSWORD') }}"
      port: 5432
      dbname: analytics
      schema: analytics
      threads: 8
```

## Core Resource Types

### Models

SQL files in `models/` that define transformations. Each `.sql` file becomes a table or view in the warehouse. Models use `select` statements -- dbt wraps them in DDL (CREATE TABLE/VIEW).

```sql
-- models/marts/customers.sql
{{ config(materialized='table') }}

select
    c.customer_id,
    c.first_name,
    c.last_name,
    count(o.order_id) as order_count
from {{ ref('stg_customers') }} c
left join {{ ref('stg_orders') }} o on c.customer_id = o.customer_id
group by 1, 2, 3
```

### Sources

Declarations of raw data tables loaded by upstream EL tools. Defined in YAML, referenced via `{{ source('source_name', 'table_name') }}`.

```yaml
# models/staging/_sources.yml
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
        columns:
          - name: id
            data_tests:
              - unique
              - not_null
      - name: customers
```

### Seeds

CSV files containing static reference data (country codes, lookup tables, mappings). Loaded via `dbt seed`. Best for files under 1MB that change infrequently. Version-controlled in the repo.

```csv
# seeds/country_codes.csv
country_code,country_name,region
US,United States,North America
GB,United Kingdom,Europe
DE,Germany,Europe
```

### Snapshots

Capture point-in-time state of mutable source tables, implementing SCD Type 2. Two detection strategies:

**Timestamp strategy** (recommended): Uses an `updated_at` column.
**Check strategy**: Compares specific column values.

Metadata columns added: `dbt_valid_from`, `dbt_valid_to`, `dbt_scd_id`, `dbt_updated_at`.

```sql
-- snapshots/orders_snapshot.sql
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

## Execution Model

### DAG Resolution

dbt builds a Directed Acyclic Graph (DAG) from model dependencies. Dependencies are declared through `ref()` and `source()` functions. dbt parses all project files, resolves the dependency graph, and executes models in topological order.

### The ref() Function

The core dependency mechanism. `{{ ref('model_name') }}` does two things:
1. Resolves the correct database/schema/table reference
2. Registers a dependency edge in the DAG

Cross-project refs use two arguments: `{{ ref('project_name', 'model_name') }}`.

### The source() Function

`{{ source('source_name', 'table_name') }}` references raw data tables. Creates a dependency from models to sources, enabling lineage tracking and freshness monitoring.

### Execution Commands

| Command | Purpose |
|---------|---------|
| `dbt run` | Build models (tables/views) |
| `dbt test` | Run data tests |
| `dbt build` | Run + test + snapshot + seed (unified) |
| `dbt seed` | Load CSV seeds |
| `dbt snapshot` | Execute snapshots |
| `dbt compile` | Compile SQL without executing |
| `dbt debug` | Test connection and configuration |
| `dbt docs generate` | Generate documentation artifacts |
| `dbt docs serve` | Serve documentation site locally |
| `dbt source freshness` | Check source data freshness |
| `dbt ls` / `dbt list` | List project resources |
| `dbt show` | Preview query results |
| `dbt deps` | Install package dependencies |
| `dbt clean` | Remove target/ and dbt_packages/ |

## Materializations

Five built-in types determine how models persist in the warehouse:

### View (Default)
- Creates a database view (`CREATE VIEW AS`)
- No extra storage; always reflects latest data
- Slow for complex stacked transformations
- Best for: staging models, lightweight transforms

### Table
- Creates a physical table (`CREATE TABLE AS`)
- Fast query performance; slow rebuild
- Data only refreshed on `dbt run`
- Best for: BI-facing models, frequently queried transforms

### Incremental
- Processes only new/changed data on subsequent runs
- Dramatically reduces build time for large datasets
- Requires `is_incremental()` conditional logic (except microbatch)
- Best for: large event tables, time-series data

### Ephemeral
- No database object created; SQL inlined as CTE into downstream models
- Cannot be queried directly or referenced in operations
- Best for: lightweight intermediate logic used by 1-2 downstream models

### Materialized View
- Database-native materialized view with optional auto-refresh
- Combines table performance with view freshness
- Not supported on all platforms (Snowflake uses Dynamic Tables instead)
- Best for: when the database should manage refresh logic

## Jinja Templating

dbt uses Jinja2 as its templating engine, turning SQL into a programming environment.

### Syntax
- `{{ expression }}` -- Output/evaluate (ref, source, var, config)
- `{% statement %}` -- Control flow (if/for/set/macro)
- `{# comment #}` -- Comments (excluded from compiled SQL)

### Key Jinja Functions
- `{{ ref('model') }}` -- Model reference
- `{{ source('src', 'table') }}` -- Source reference
- `{{ config(...) }}` -- Model configuration
- `{{ var('variable_name') }}` -- Project variables
- `{{ env_var('ENV_VAR') }}` -- Environment variables
- `{{ this }}` -- Current model relation
- `{{ target }}` -- Active connection target info
- `{{ adapter }}` -- Database adapter wrapper
- `{{ is_incremental() }}` -- Incremental mode check
- `{{ log('message', info=True) }}` -- Debug logging

### Macros
Reusable code blocks defined in `macros/` directory:

```sql
{% macro cents_to_dollars(column_name, scale=2) %}
    ({{ column_name }} / 100)::numeric(16, {{ scale }})
{% endmacro %}

-- Usage: {{ cents_to_dollars('amount') }}
```

### Custom Schema/Alias
Override with macros:
- `generate_schema_name(custom_schema_name, node)` -- Custom schema routing
- `generate_alias_name(custom_alias_name, node)` -- Custom table naming

## Adapters

dbt connects to data platforms via adapters. Each adapter translates dbt operations to platform-specific SQL/DDL.

### dbt Labs Maintained (Trusted)
| Adapter | Package | Platform |
|---------|---------|----------|
| PostgreSQL | `dbt-postgres` | PostgreSQL |
| Snowflake | `dbt-snowflake` | Snowflake |
| BigQuery | `dbt-bigquery` | Google BigQuery |
| Redshift | `dbt-redshift` | Amazon Redshift |
| Spark | `dbt-spark` | Apache Spark |
| Databricks | `dbt-databricks` | Databricks (Spark/Delta) |
| Fabric | `dbt-fabric` | Microsoft Fabric |

### Community Maintained
| Adapter | Package | Platform |
|---------|---------|----------|
| DuckDB | `dbt-duckdb` | DuckDB (embedded OLAP) |
| Trino | `dbt-trino` | Trino / Starburst |
| ClickHouse | `dbt-clickhouse` | ClickHouse |
| SQLite | `dbt-sqlite` | SQLite |
| And many more... | | |

## Testing Framework

### Generic Tests (Schema Tests)
Four built-in tests defined in YAML properties files:
- `unique` -- No duplicate values in column
- `not_null` -- No NULL values in column
- `accepted_values` -- Column values within specified list
- `relationships` -- Referential integrity to another model/source

```yaml
models:
  - name: orders
    columns:
      - name: order_id
        data_tests:
          - unique
          - not_null
      - name: status
        data_tests:
          - accepted_values:
              values: ['placed', 'shipped', 'completed', 'returned']
      - name: customer_id
        data_tests:
          - relationships:
              to: ref('customers')
              field: customer_id
```

### Singular Tests
Custom SQL queries in `tests/` that return failing rows:
```sql
-- tests/assert_positive_order_amounts.sql
select order_id, amount
from {{ ref('orders') }}
where amount <= 0
```

### Unit Tests (dbt 1.8+)
Test model logic with mock inputs defined in YAML:
```yaml
unit_tests:
  - name: test_order_total
    model: orders
    given:
      - input: ref('stg_orders')
        rows:
          - {order_id: 1, amount: 100}
          - {order_id: 2, amount: 200}
    expect:
      rows:
        - {order_id: 1, amount: 100}
        - {order_id: 2, amount: 200}
```

## Documentation

### Doc Blocks
Markdown documentation in `.md` files using Jinja:
```jinja
{% docs customer_id %}
The unique identifier for a customer, sourced from the payments system.
This ID is stable across all downstream models.
{% enddocs %}
```

Referenced in YAML: `description: '{{ doc("customer_id") }}'`

### Generated Documentation
- `dbt docs generate` creates `manifest.json` and `catalog.json`
- `dbt docs serve` hosts a static documentation website
- Includes interactive DAG visualization, model lineage, column descriptions
- Custom landing page via `__overview__` doc block

### persist_docs
Pushes descriptions to the database as column/table comments:
```yaml
models:
  +persist_docs:
    relation: true
    columns: true
```

## dbt Packages

External dbt projects installed as dependencies via `packages.yml`:

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]
  - package: calogica/dbt_expectations
    version: [">=0.10.0", "<0.11.0"]
  - package: dbt-labs/codegen
    version: [">=0.12.0", "<0.13.0"]
  - package: dbt-labs/audit_helper
    version: [">=0.12.0", "<0.13.0"]
```

### Key Packages

| Package | Purpose |
|---------|---------|
| **dbt-utils** | Essential utilities: surrogate keys, pivot, union, date spine, generic tests |
| **dbt-expectations** | 40+ data quality tests inspired by Great Expectations |
| **codegen** | Auto-generate base models, YAML schema files, sources |
| **audit-helper** | Compare datasets for migration validation, schema drift detection |
| **dbt-date** | Date/time utilities and fiscal calendar support |
| **dbt-project-evaluator** | Lint project structure against best practices |

Installed via `dbt deps` into `dbt_packages/` directory.
