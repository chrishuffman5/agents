# dbt Core Features

## Current Release: dbt Core 1.11

**GA Release**: December 2025
**Latest Patch**: 1.11.8 (April 8, 2026)

### User-Defined Functions (UDFs)

The headline feature of dbt Core 1.11. UDFs are first-class dbt resources that allow defining and registering custom functions in the data warehouse.

- **Location**: Defined in `functions/` directory
- **Reference**: Use `{{ function('function_name') }}` macro
- **Execution**: Built as part of DAG execution during `dbt run`/`dbt build`
- **Support**: Python UDFs, default arguments, rich configuration options
- **Key benefit**: Unlike macros (which exist only at compile time), UDFs persist as warehouse objects, enabling reuse in tools outside dbt (BI tools, ad-hoc queries)

### JSON Schema Validation

YAML config validation warnings are enabled by default for Snowflake, Databricks, BigQuery, and Redshift. Helps teams catch outdated or incorrect configurations earlier in development.

### Environment Variable Naming

Standardized `DBT_ENGINE_` prefix for engine-level configuration variables (e.g., `DBT_STATE`, `DBT_PROJECT_DIR`).

### Behavior Change Flags

- `require_unique_project_resource_names`: Enforces unique resource names across project
- `require_ref_searches_node_package_before_root`: Controls ref() search order in packages

### Adapter-Specific Improvements

| Adapter | Enhancement |
|---------|-------------|
| **BigQuery** | Batched source freshness queries for reduced API overhead |
| **Snowflake** | Iceberg table materialization via Glue catalog, dynamic table clustering, `immutable_where` config |
| **Redshift** | Reduced unnecessary transaction statements by default |
| **Spark** | Enhanced PyHive retry handling with polling intervals and timeouts |

### Minor Enhancements

- `dbt ls` supports nested key output for easier debugging
- Manifest includes `run_started_at` timestamps
- Disabled models automatically disable their unit tests
- New `config.meta_get()` and `config.meta_require()` for custom metadata access

---

## Recent Major Features (1.8 - 1.10)

### Unit Testing (dbt 1.8)

Test model transformation logic with mock inputs. Define expected outputs without hitting the database.

```yaml
unit_tests:
  - name: test_is_valid_email
    model: dim_customers
    given:
      - input: ref('stg_customers')
        rows:
          - {email: user@example.com, domain: example.com}
          - {email: badformat, domain: gmail.com}
      - input: ref('email_domains')
        rows:
          - {tld: example.com}
          - {tld: gmail.com}
    expect:
      rows:
        - {email: user@example.com, is_valid: true}
        - {email: badformat, is_valid: false}
```

Key capabilities:
- **Mock format**: dict (inline YAML), CSV, or fixture files
- **Partial mocking**: Only define columns relevant to the test
- **Override macros/vars**: Test different execution contexts (full refresh vs. incremental)
- **Selective run**: `dbt test --select test_type:unit`
- **Best practice**: Run only in dev/CI, not production (static inputs = no value from prod runs)

### Microbatch Incremental Strategy (dbt 1.9)

Purpose-built for large time-series datasets. Splits processing into independent, atomic time-based batches.

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='event_occurred_at',
    begin='2020-01-01',
    batch_size='day',
    lookback=3
) }}

select * from {{ ref('stg_events') }}
```

Core properties:
- **event_time** (required): Column indicating when the row occurred
- **batch_size** (required): hour, day, month, or year
- **begin** (required): Start date for initial full build
- **lookback** (optional, default 1): Number of prior batches to reprocess for late-arriving data

Key benefits:
- No `is_incremental()` conditional logic needed
- Each batch is independent and idempotent
- Parallel execution across batches
- Selective backfill via `--event-time-start` and `--event-time-end` flags
- Automatic retry of failed batches
- All timestamps assumed UTC

### Saved Queries

Group metrics, dimensions, and filters into reusable query nodes within the semantic layer. Enables consistent, pre-defined analytical queries across tools.

### Semantic Layer Integration

Centralized metric definitions accessible via MetricFlow. Enables consistent metrics across all downstream consumers (BI tools, notebooks, APIs).

---

## dbt Mesh

A governance and multi-project pattern for scaling data teams. Not a single product, but a convergence of features.

### Cross-Project References

Foundation of dbt Mesh. Use two-argument ref:
```sql
select * from {{ ref('upstream_project', 'shared_model') }}
```

Enables independent team deployments while sharing data assets.

### Model Contracts

Explicit data shape expectations enforced at build time:
```yaml
models:
  - name: customers
    config:
      contract:
        enforced: true
    columns:
      - name: customer_id
        data_type: int
      - name: customer_name
        data_type: varchar(100)
```

If the model's output doesn't match the contract, the build fails. Prevents breaking changes in shared models.

### Groups

Organize related DAG nodes by functional area with assigned owners:
```yaml
groups:
  - name: finance
    owner:
      name: Finance Analytics Team
      email: finance-data@company.com

models:
  - name: revenue
    config:
      group: finance
```

### Access Modifiers

Control model visibility across the project/organization:

| Modifier | Scope |
|----------|-------|
| `private` | Only referenceable within the same group |
| `protected` | Referenceable within the same project (default) |
| `public` | Referenceable from any project |

```yaml
models:
  - name: customers
    access: public
```

### Model Versions

Enable graceful evolution of shared models:
```yaml
models:
  - name: customers
    latest_version: 2
    versions:
      - v: 1
        deprecation_date: 2025-06-01
      - v: 2
```

Reference specific versions: `{{ ref('customers', v=2) }}`

### When to Adopt Mesh

Consider Mesh when experiencing:
- Performance degradation from excessive model volume in one project
- Teams needing decoupled development and deployment workflows
- Increasing security and governance requirements
- Communication challenges impacting data reliability

Incremental adoption is supported -- adopt features one at a time.

---

## MetricFlow and Semantic Layer

### What is MetricFlow?

A SQL query generation engine that powers the dbt Semantic Layer. Enables centralized metric definitions via YAML, ensuring consistent calculations across all consumers.

- Licensed under Apache 2.0
- Integrated with dbt Core 1.6+
- Part of the Open Semantic Interchange (OSI) initiative

### Semantic Models

YAML definitions mapping to dbt models, containing three components:

```yaml
semantic_models:
  - name: orders
    model: ref('fct_orders')
    defaults:
      agg_time_dimension: ordered_at

    entities:
      - name: order_id
        type: primary
      - name: customer_id
        type: foreign

    dimensions:
      - name: ordered_at
        type: time
        type_params:
          time_granularity: day
      - name: order_status
        type: categorical

    measures:
      - name: order_total
        agg: sum
        expr: amount
      - name: order_count
        agg: count
        expr: order_id
```

**Entities**: Join keys defining relationships between semantic models (primary, foreign, unique, natural).
**Dimensions**: Attributes for grouping/filtering (categorical, time).
**Measures**: Aggregatable expressions (sum, count, average, min, max, count_distinct).

### Metrics

Built from measures with additional logic:

```yaml
metrics:
  - name: revenue
    type: simple
    type_params:
      measure: order_total
    filter:
      - "{{ Dimension('order__order_status') }} = 'completed'"

  - name: revenue_growth
    type: derived
    type_params:
      expr: (current_revenue - prior_revenue) / prior_revenue
      metrics:
        - name: revenue
          offset_window: 1 month
          alias: prior_revenue
        - name: revenue
          alias: current_revenue
```

Metric types: simple, derived, cumulative, ratio, conversion.

### Semantic Graph

MetricFlow builds a semantic graph representing relationships between semantic models. The graph determines optimal join paths for any metric + dimension combination, generating efficient SQL.

### Data Requirements

MetricFlow works with any data format (raw to fully denormalized), but normalized data is ideal since MetricFlow handles denormalization efficiently.

---

## Incremental Strategies

Five built-in strategies for incremental materializations:

| Strategy | Mechanism | Best For |
|----------|-----------|----------|
| **append** | Insert only, no dedup | Append-only event logs |
| **merge** | Upsert via MERGE statement | Small-medium tables with unique keys |
| **delete+insert** | Delete matching keys, then insert | Large tables (3.4x faster than merge at 500M rows on Snowflake) |
| **insert_overwrite** | Replace entire partitions | Date-partitioned tables |
| **microbatch** | Time-based batch processing | Large time-series data |

### Adapter Support Matrix

| Strategy | Postgres | Redshift | BigQuery | Snowflake | Databricks | Spark |
|----------|----------|----------|----------|-----------|------------|-------|
| append | Yes | Yes | Yes | Yes | Yes | Yes |
| merge | Yes | Yes | Yes | Yes | Yes | Yes |
| delete+insert | Yes | Yes | Yes | Yes | Yes | Yes |
| insert_overwrite | Yes | Yes | -- | Yes | Yes | Yes |
| microbatch | -- | -- | -- | Yes | Yes | -- |

### Incremental Predicates

Optimize merge performance by limiting table scans:
```sql
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='event_id',
    incremental_predicates=[
        "DBT_INTERNAL_DEST.event_date > dateadd(day, -7, current_date)"
    ]
) }}
```

### Custom Strategies

Define custom strategies by creating a macro named `get_incremental_<STRATEGY>_sql`. Not supported by BigQuery or Spark adapters.

---

## Documentation System

### Description Properties

Add descriptions to any resource via YAML:
```yaml
models:
  - name: customers
    description: "One row per customer with lifetime metrics"
    columns:
      - name: customer_id
        description: "Primary key from the source system"
```

### Doc Blocks

Longer-form markdown documentation in `.md` files:
```jinja
{% docs customer_lifetime_value %}
Calculated as the sum of all completed order amounts for a customer,
minus any refunds issued. Updated on each dbt run.

**Business rules:**
- Only includes orders with status = 'completed'
- Refunds are subtracted at the line-item level
{% enddocs %}
```

Reference: `description: '{{ doc("customer_lifetime_value") }}'`

### Generated Documentation Site

1. `dbt docs generate` -- Creates `manifest.json` and `catalog.json`
2. `dbt docs serve` -- Hosts static site locally
3. Features: searchable model catalog, interactive DAG visualization, column-level lineage, test results

### persist_docs

Push descriptions to the database as table/column comments:
```yaml
models:
  +persist_docs:
    relation: true
    columns: true
```
