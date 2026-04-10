# dbt Core Best Practices

## Project Structure: Staging / Intermediate / Marts

The recommended three-layer architecture moves data from source-conformed to business-conformed:

### Staging Layer

**Purpose**: Create atomic building blocks by cleaning and standardizing raw source data.

**Rules**:
- One staging model per source table (1:1 mapping)
- Only place where `{{ source() }}` is used
- Materialized as **views** (not tables -- avoid wasting warehouse storage)
- No complex business logic -- only renaming, type casting, basic filtering
- Organized by source system subdirectory

**Naming**: `stg_[source]__[entity].sql` (double underscore separator)

```
models/staging/
├── jaffle_shop/
│   ├── _jaffle_shop__sources.yml
│   ├── _jaffle_shop__models.yml
│   ├── stg_jaffle_shop__customers.sql
│   └── stg_jaffle_shop__orders.sql
├── stripe/
│   ├── _stripe__sources.yml
│   ├── _stripe__models.yml
│   └── stg_stripe__payments.sql
└── base/  (optional: for pre-staging unions/deduplication)
    ├── base_jaffle_shop__customers.sql
    └── base_jaffle_shop__deleted_customers.sql
```

### Intermediate Layer

**Purpose**: Purpose-built transformation logic that prepares staging models for final entity joins. Each model performs a single, clear transformation step.

**Rules**:
- Materialized as **ephemeral** or **views** (not exposed to end users)
- Contains reusable business logic shared by multiple downstream models
- Breaks complex operations into smaller, testable chunks
- Organized by business function subdirectory

**Naming**: `int_[entity]_[verb].sql`

```
models/intermediate/
├── finance/
│   ├── _int_finance__models.yml
│   └── int_payments_pivoted_to_orders.sql
└── marketing/
    └── int_customer_orders_joined.sql
```

### Marts Layer

**Purpose**: Final, business-ready entities consumed by end users, BI tools, and downstream systems.

**Rules**:
- Materialized as **tables** or **incremental** models
- Wide, denormalized entities (customers, orders, products)
- Business-friendly names without technical prefixes
- Organized by department or domain

**Naming**: Use entity names directly, optionally prefixed with `dim_` (dimensions) or `fct_` (facts).

```
models/marts/
├── finance/
│   ├── _finance__models.yml
│   ├── orders.sql       (or fct_orders.sql)
│   └── payments.sql
└── marketing/
    ├── _marketing__models.yml
    └── customers.sql    (or dim_customers.sql)
```

### YAML Organization

- One YAML properties file per directory: `_[directory_name]__models.yml`
- Source definitions: `_[source_name]__sources.yml`
- Doc blocks: `_[source_name]__docs.md`
- Keep YAML files close to the models they describe

---

## Naming Conventions

### Models
| Layer | Pattern | Example |
|-------|---------|---------|
| Staging | `stg_[source]__[entity]` | `stg_stripe__payments` |
| Base | `base_[source]__[entity]` | `base_jaffle_shop__customers` |
| Intermediate | `int_[entity]_[verb]` | `int_payments_pivoted_to_orders` |
| Marts (fact) | `fct_[entity]` or `[entity]` | `fct_orders` |
| Marts (dimension) | `dim_[entity]` or `[entity]` | `dim_customers` |

### General Rules
- Use **underscores**, not dots or camelCase
- All names should be **plural** (customers, orders, payments)
- Double underscores `__` separate source/layer from entity descriptor
- Use lowercase throughout
- Objects named after the entity they represent, prefixed by layer/type

---

## Incremental Model Best Practices

### Strategy Selection

| Scenario | Recommended Strategy |
|----------|---------------------|
| Append-only event stream | `append` |
| Small-medium table with unique key | `merge` |
| Large table (>100M rows) with unique key | `delete+insert` |
| Date-partitioned data | `insert_overwrite` |
| Large time-series (>1B rows) | `microbatch` |

### Golden Rule of Materialization

> Start with views. When they take too long to query, make them tables. When the tables take too long to build, make them incremental.

### Handling Late-Arriving Data

**Lookback window approach**:
```sql
{{ config(materialized='incremental', unique_key='event_id') }}

select *
from {{ ref('stg_events') }}
{% if is_incremental() %}
where event_timestamp > (
    select max(event_timestamp) - interval '2 hours'
    from {{ this }}
)
{% endif %}
```

**Microbatch lookback**: Set `lookback=3` to reprocess 3 prior batches automatically.

### Incremental Model Tips

- Always define `unique_key` for merge/delete+insert strategies to prevent duplicates
- Use `incremental_predicates` to limit merge scan scope on large tables
- Consider `on_schema_change='append_new_columns'` for evolving source schemas
- Use `--full-refresh` flag for complete rebuilds when needed
- Test incremental logic with unit tests in both full-refresh and incremental modes

---

## Testing Strategy

### What to Test

**Always test**:
- Primary keys: `unique` + `not_null` on every model's primary key
- Foreign keys: `relationships` test on join columns
- Critical business columns: `not_null` on required fields

**Consider testing**:
- Status/category columns: `accepted_values` for known value sets
- Numeric ranges: custom tests for reasonable value bounds
- Row counts: ensure models aren't empty or unexpectedly large
- Freshness: source freshness checks on all source tables

### Test Configuration

**Severity levels**:
```yaml
columns:
  - name: order_id
    data_tests:
      - unique:
          severity: error  # Fail the build
      - not_null:
          severity: warn   # Warn but continue
          warn_if: ">10"
          error_if: ">100"
```

**Storing failures**:
```yaml
data_tests:
  - unique:
      config:
        store_failures: true
        schema: test_failures
```

### Custom Generic Tests

Define reusable test logic in `tests/generic/` or `macros/`:
```sql
{% test positive_value(model, column_name) %}
select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0
{% endtest %}
```

Usage:
```yaml
columns:
  - name: amount
    data_tests:
      - positive_value
```

### Unit Testing Best Practices

- Test complex business logic and conditional transformations
- Mock only the columns relevant to the test
- Override macros/vars to test incremental vs. full-refresh behavior
- Run unit tests in dev/CI only, not production
- Use `dbt test --select test_type:unit` for targeted runs

---

## Performance Optimization

### Materialization Choices

| Layer | Materialization | Rationale |
|-------|----------------|-----------|
| Staging | view | Always fresh, low storage overhead |
| Intermediate | ephemeral / view | No warehouse clutter |
| Marts | table | Fast query performance for BI |
| Large marts | incremental | Avoid full rebuilds |
| Auto-refresh | materialized_view | Database manages refresh |

### Partitioning and Clustering

**BigQuery**:
```sql
{{ config(
    materialized='table',
    partition_by={
        "field": "order_date",
        "data_type": "date",
        "granularity": "day"
    },
    cluster_by=["customer_id", "product_category"]
) }}
```

**Snowflake**:
```sql
{{ config(
    materialized='table',
    cluster_by=['order_date', 'customer_id']
) }}
```

**Guidelines**:
- Partition by the column most used in date range filters (typically a date/timestamp)
- Cluster by columns most used in WHERE and GROUP BY clauses
- Enforce partition filters on large tables to prevent full scans
- Don't partition very small tables (overhead exceeds benefit)
- Limit cluster columns to 3-4 (diminishing returns beyond that)

### Query Performance Tips

- Aggregate early: perform aggregations on the smallest dataset before joining
- Select only needed columns (avoid `SELECT *` in production models)
- Use `union all` instead of `union` unless deduplication is required
- Filter early in CTEs to reduce data volume for downstream operations
- Right-size warehouse: X-SMALL for light transforms, scale up for batch-heavy loads
- Use ephemeral models for reused intermediate logic (avoids repeated CTE compilation)

---

## CI/CD Best Practices

### Slim CI with state:modified

Only build modified models and their downstream dependencies:

```bash
# Compare against production manifest
dbt build --select state:modified+ --defer --state ./prod-artifacts/
```

- `state:modified` -- Only models whose code/config has changed
- `state:modified+` -- Modified models AND their downstream dependents
- `--defer` -- Use production tables for unmodified upstream models
- `--state` -- Path to production manifest.json for state comparison

### CI Workflow

1. **On pull request**: Run `dbt build --select state:modified+ --defer --state prod-run-artifacts/`
2. **On merge to main**: Run full `dbt build` or `dbt build --select state:modified+`
3. **Scheduled production**: Full `dbt build` on schedule

### dbt build vs. dbt run + dbt test

- `dbt build` runs models, tests, snapshots, and seeds in DAG order (tests run immediately after their model)
- `dbt run` + `dbt test` runs all models first, then all tests -- a failing model might cause downstream builds before tests catch it
- **Prefer `dbt build`** for CI and production deployments

### Additional CI Flags

- `--fail-fast` -- Stop build on first error (saves compute)
- `--empty` (dbt 1.8+) -- Build model DDL with zero rows for schema validation only
- `--full-refresh` -- Force complete rebuild of incremental models
- `--warn-error` -- Treat warnings as errors in CI

### Deployment Workflow Pattern

```
Development (dev target)
  └── PR → Slim CI (ci target, state:modified+)
       └── Merge → Production Build (prod target)
            └── Scheduled: Full dbt build
```

---

## Code Style Guide

### SQL Formatting

- **Indentation**: 4 spaces (no tabs)
- **Line length**: 80 characters max
- **Keywords**: lowercase (`select`, `from`, `where`, `join`)
- **Commas**: trailing (at end of line)
- **Aliases**: always use `as` keyword explicitly
- **Joins**: explicit join types (`inner join`, `left join`, not `join`)
- **Grouping**: group by column position (`group by 1, 2, 3`)
- **Unions**: prefer `union all` over `union`

### CTE Organization

```sql
-- Import CTEs (refs/sources at top)
with

customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

-- Logical CTEs
customer_orders as (
    select
        customer_id,
        count(*) as order_count,
        sum(amount) as total_amount
    from orders
    group by 1
),

-- Final CTE
final as (
    select
        customers.customer_id,
        customers.first_name,
        customers.last_name,
        coalesce(customer_orders.order_count, 0) as order_count,
        coalesce(customer_orders.total_amount, 0) as total_amount
    from customers
    left join customer_orders
        on customers.customer_id = customer_orders.customer_id
)

select * from final
```

### Jinja Best Practices

- Use `{# Jinja comments #}` instead of SQL comments for notes excluded from compiled output
- Set variables at the top of the file: `{% set payment_methods = [...] %}`
- Use whitespace control (`{%- ... -%}`) to keep compiled SQL clean
- Prioritize readability over DRY -- some SQL repetition is acceptable
- Check dbt-utils before writing custom macros
- Document macros with descriptions and argument specs in properties YAML

### DRY Principles

- Extract repeated CTE logic into intermediate models
- Use macros for repeated SQL patterns across multiple models
- Use packages (dbt-utils) for common operations
- Use project-level configs in `dbt_project.yml` instead of per-model `config()` blocks
- Balance DRY with readability -- over-abstraction via macros hurts maintainability

### Linting and Formatting

- **SQLFluff**: Primary SQL linter with Jinja support, built-in rules
- **sqlfmt**: Opinionated SQL formatter
- Configure via `.sqlfluff` file in project root
- Integrate into CI pipeline for automated style enforcement
