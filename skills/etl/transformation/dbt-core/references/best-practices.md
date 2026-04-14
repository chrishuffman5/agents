# dbt Core Best Practices

## Project Structure: Staging / Intermediate / Marts

The recommended three-layer architecture moves data from source-conformed to business-conformed:

### Staging Layer

**Purpose**: Create atomic building blocks by cleaning and standardizing raw source data.

**Rules**:
- One staging model per source table (1:1 mapping)
- Only place where `{{ source() }}` is used
- Materialized as **views** (no tables -- avoid wasting storage)
- Only renaming, type casting, basic filtering -- no business logic
- Organized by source system subdirectory

**Naming**: `stg_[source]__[entity].sql` (double underscore separator)

```
models/staging/
  jaffle_shop/
    _jaffle_shop__sources.yml
    _jaffle_shop__models.yml
    stg_jaffle_shop__customers.sql
    stg_jaffle_shop__orders.sql
  stripe/
    _stripe__sources.yml
    _stripe__models.yml
    stg_stripe__payments.sql
```

### Intermediate Layer

**Purpose**: Purpose-built transformation logic that prepares staging models for final entity joins.

**Rules**:
- Materialized as **ephemeral** or **views** (not exposed to end users)
- Contains reusable business logic shared by multiple downstream models
- Breaks complex operations into smaller, testable chunks
- Organized by business function subdirectory

**Naming**: `int_[entity]_[verb].sql`

```
models/intermediate/
  finance/
    _int_finance__models.yml
    int_payments_pivoted_to_orders.sql
  marketing/
    int_customer_orders_joined.sql
```

### Marts Layer

**Purpose**: Final, business-ready entities consumed by end users, BI tools, and downstream systems.

**Rules**:
- Materialized as **tables** or **incremental** models
- Wide, denormalized entities (customers, orders, products)
- Business-friendly names without technical prefixes
- Organized by department or domain

**Naming**: Entity names directly, optionally prefixed with `dim_` (dimensions) or `fct_` (facts).

```
models/marts/
  finance/
    _finance__models.yml
    fct_orders.sql
    payments.sql
  marketing/
    _marketing__models.yml
    dim_customers.sql
```

### YAML Organization

- One YAML properties file per directory: `_[directory_name]__models.yml`
- Source definitions: `_[source_name]__sources.yml`
- Doc blocks: `_[source_name]__docs.md`
- Keep YAML files close to the models they describe

## Naming Conventions

| Layer | Pattern | Example |
|---|---|---|
| Staging | `stg_[source]__[entity]` | `stg_stripe__payments` |
| Base | `base_[source]__[entity]` | `base_jaffle_shop__customers` |
| Intermediate | `int_[entity]_[verb]` | `int_payments_pivoted_to_orders` |
| Marts (fact) | `fct_[entity]` or `[entity]` | `fct_orders` |
| Marts (dimension) | `dim_[entity]` or `[entity]` | `dim_customers` |

**General rules**:
- Underscores, not dots or camelCase
- All names **plural** (customers, orders, payments)
- Double underscores `__` separate source/layer from entity
- Lowercase throughout

## Incremental Model Best Practices

### Strategy Selection

| Scenario | Strategy | Why |
|---|---|---|
| Append-only event stream | `append` | No dedup needed, fastest |
| Small-medium table with unique key | `merge` | Standard upsert |
| Large table (>100M rows) | `delete+insert` | 3.4x faster than merge at scale |
| Date-partitioned data | `insert_overwrite` | Replace entire partitions |
| Large time-series (>1B rows) | `microbatch` | Parallel batches, automatic late-data |

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

### Essential Rules

- Always define `unique_key` for merge/delete+insert to prevent duplicates
- Use `incremental_predicates` to limit merge scan scope on large tables:
  ```sql
  {{ config(
      incremental_predicates=[
          "DBT_INTERNAL_DEST.event_date > dateadd(day, -7, current_date)"
      ]
  ) }}
  ```
- Set `on_schema_change='append_new_columns'` for evolving source schemas
- Use `--full-refresh` for complete rebuilds when needed
- Test incremental logic in both full-refresh and incremental modes

## Testing Strategy

### What to Test

**Always test**:
- Primary keys: `unique` + `not_null` on every model's primary key
- Foreign keys: `relationships` on join columns
- Critical business columns: `not_null` on required fields

**Consider testing**:
- Status/category columns: `accepted_values` for known value sets
- Numeric ranges: custom generic tests for reasonable bounds
- Row counts: ensure models are not empty or unexpectedly large
- Source freshness: freshness checks on all source tables

### Test Configuration

**Severity levels**:
```yaml
columns:
  - name: order_id
    data_tests:
      - unique:
          severity: error
      - not_null:
          severity: warn
          warn_if: ">10"
          error_if: ">100"
```

**Storing failures** for investigation:
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

Usage: `data_tests: [positive_value]`

### Unit Testing Best Practices (1.8+)

- Test complex business logic and conditional transformations
- Mock only the columns relevant to the test
- Override macros/vars to test incremental vs full-refresh behavior
- Run unit tests in dev/CI only, not production (`dbt test --select test_type:unit`)

## Performance Optimization

### Materialization Choices

| Layer | Materialization | Rationale |
|---|---|---|
| Staging | view | Always fresh, low storage |
| Intermediate | ephemeral / view | No warehouse clutter |
| Marts | table | Fast BI query performance |
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
- Partition by the column most used in date range filters
- Cluster by columns most used in WHERE and GROUP BY
- Don't partition very small tables (overhead exceeds benefit)
- Limit cluster columns to 3-4 (diminishing returns)

### Query Performance Tips

- Aggregate early: perform aggregations before joining larger tables
- Select only needed columns (avoid `SELECT *`)
- Use `union all` instead of `union` unless dedup is required
- Filter early in CTEs to reduce downstream data volume
- Right-size warehouse (start X-SMALL, scale up as needed)
- Use ephemeral models for shared intermediate logic (avoids repeated CTE compilation)

## CI/CD Best Practices

### Slim CI with state:modified

Only build modified models and their downstream dependencies:

```bash
dbt build --select state:modified+ --defer --state ./prod-artifacts/
```

- `state:modified` -- Only models whose code/config has changed
- `state:modified+` -- Modified models AND their downstream dependents
- `--defer` -- Use production tables for unmodified upstream models
- `--state` -- Path to production manifest.json

### CI Workflow

```
Development (dev target)
  --> PR: Slim CI (ci target, state:modified+, --defer)
       --> Merge: Production Build (prod target)
            --> Scheduled: Full dbt build
```

### dbt build vs dbt run + dbt test

- `dbt build` runs models, tests, snapshots, and seeds in DAG order (tests run immediately after their model)
- `dbt run` + `dbt test` runs all models first, then all tests -- a failing model might trigger downstream builds before tests catch it
- **Prefer `dbt build`** for CI and production

### Additional CI Flags

| Flag | Purpose |
|---|---|
| `--fail-fast` | Stop build on first error (saves compute) |
| `--empty` (1.8+) | Build model DDL with zero rows (schema validation only) |
| `--full-refresh` | Force complete rebuild of incremental models |
| `--warn-error` | Treat warnings as errors in CI |

## Code Style Guide

### SQL Formatting

- **Indentation**: 4 spaces (no tabs)
- **Line length**: 80 characters max
- **Keywords**: lowercase (`select`, `from`, `where`, `join`)
- **Commas**: trailing (at end of line)
- **Aliases**: always use `as` keyword explicitly
- **Joins**: explicit types (`inner join`, `left join`, not `join`)
- **Grouping**: group by column position (`group by 1, 2, 3`)

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
        coalesce(customer_orders.order_count, 0) as order_count,
        coalesce(customer_orders.total_amount, 0) as total_amount
    from customers
    left join customer_orders
        on customers.customer_id = customer_orders.customer_id
)

select * from final
```

### Jinja Best Practices

- Use `{# Jinja comments #}` for notes excluded from compiled output
- Set variables at the top: `{% set payment_methods = [...] %}`
- Use whitespace control (`{%- ... -%}`) for clean compiled SQL
- Prioritize readability over DRY -- some SQL repetition is acceptable
- Check dbt-utils before writing custom macros
- Document macros with descriptions in properties YAML

### Linting and Formatting

- **SQLFluff**: Primary SQL linter with Jinja support, 60+ built-in rules
- **sqlfmt**: Opinionated SQL formatter
- Configure via `.sqlfluff` file in project root
- Integrate into CI for automated style enforcement:
  ```bash
  sqlfluff lint models/ --dialect snowflake
  ```

## Cost Optimization

### Compute

- Right-size warehouse for dbt workloads (X-SMALL for most staging/intermediate)
- Use auto-suspend on warehouse (1-2 minute timeout)
- Separate warehouses for dbt transforms vs ad-hoc queries vs BI
- Schedule builds to align with data arrival (don't refresh hourly if data arrives daily)

### Processing

- Use incremental models for large datasets (process only new/changed data)
- Enable partition pruning by partitioning on date columns used in filters
- Aggregate early, filter early, select only needed columns
- Use `union all` over `union` (avoids expensive dedup sort)

### CI/CD

- Slim CI with `state:modified+` and `--defer` (avoid full DAG builds on PRs)
- Use `--fail-fast` to stop on first error (saves remaining compute)
- Use `--empty` (1.8+) for schema-only validation when data testing is unnecessary
