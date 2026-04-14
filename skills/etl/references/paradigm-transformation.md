# Paradigm: Data Transformation

When and why to choose transformation tools for data pipelines. This file covers the paradigm itself, not specific engines -- see technology agents for engine-specific guidance.

## Choose In-Warehouse Transformation (dbt) When

- **Transformation logic is primarily SQL.** Aggregations, joins, window functions, CASE expressions, CTEs -- the bread and butter of analytics engineering. SQL is more accessible to analysts than DataFrame code.
- **The warehouse has elastic compute.** Snowflake, BigQuery, Redshift, and Databricks scale compute independently of storage. Running transforms in the warehouse leverages this elasticity.
- **Version control and testing of SQL matter.** dbt brings software engineering practices (Git, CI/CD, unit tests, documentation) to SQL transformations that would otherwise live as unversioned stored procedures.
- **Lineage and documentation are priorities.** dbt auto-generates DAG visualizations, column-level lineage, and data dictionaries from the codebase.

## Choose Distributed Transformation (Spark) When

- **Data exceeds single-warehouse capacity or budget.** Multi-terabyte datasets where warehouse compute costs are prohibitive, or data lives in a data lake (S3/ADLS/GCS) outside a warehouse.
- **Transformations require imperative logic.** Complex parsing, ML feature engineering, graph algorithms, recursive processing, or UDFs that don't express well in SQL.
- **Multi-language support is needed.** Python (PySpark), Scala, Java, or R for teams with diverse skills.
- **Data lakehouse architecture.** Spark reads and writes Delta Lake, Iceberg, or Hudi tables natively, supporting ACID transactions on data lake files.

## Choose In-Process Transformation (DuckDB) When

- **Data fits on a single machine (up to ~100-200 GB).** DuckDB's columnar engine is faster than Pandas and requires no cluster. Ideal for development, testing, and small-to-medium production workloads.
- **File-based ETL.** Transforming Parquet, CSV, or JSON files locally before loading to a warehouse.
- **CI/CD pipeline testing.** Run dbt tests or transformation logic against DuckDB in CI without provisioning a warehouse.
- **Cost sensitivity.** No cluster, no warehouse compute charges. Zero infrastructure.

## Avoid Each When

| Tool | Avoid When |
|---|---|
| **dbt** | Transformations need imperative logic (ML, complex parsing), data is not in a warehouse, or real-time processing is needed |
| **Spark** | Data is under 100 GB (overhead of cluster management isn't justified), team is SQL-only, or warehouse-native transforms are sufficient |
| **DuckDB** | Data exceeds single-machine memory/disk, distributed processing is required, or production SLAs demand fault-tolerant cluster execution |

## Technology Comparison

| Dimension | dbt Core | dbt Cloud | Apache Spark | DuckDB |
|---|---|---|---|---|
| **Language** | SQL + Jinja2 | SQL + Jinja2 + Python models | Python, Scala, Java, SQL | SQL |
| **Execution** | Compiles SQL, warehouse executes | Same as Core, managed runtime | Distributed cluster (YARN, K8s, Standalone) | In-process, single machine |
| **Scale** | Warehouse-limited | Warehouse-limited | Petabyte-scale | Single-machine (~200 GB practical) |
| **Cost** | Free (warehouse compute costs) | Per-seat licensing + warehouse compute | Cluster compute (Databricks, EMR, Dataproc) | Free |
| **Testing** | Built-in (unique, not_null, relationships, custom) | Built-in + CI/CD integration | Manual (pytest, chispa) | Standard SQL assertions |
| **Lineage** | Auto-generated DAG + docs | Enhanced lineage + Explorer UI | Manual (SparkListener, OpenLineage) | None built-in |
| **Best For** | Analytics engineering, warehouse-native ELT | Managed dbt for teams wanting scheduling + IDE | Large-scale ETL, ML pipelines, lakehouse | Local dev, CI testing, small-scale ETL |

## Common Patterns

1. **Medallion architecture (Bronze/Silver/Gold)**: Raw ingestion (bronze), cleaned/conformed (silver), business-level aggregations (gold). Applies to both dbt (staging/intermediate/marts) and Spark (Delta Lake layers).
2. **Incremental processing**: Process only new/changed rows. dbt `incremental` models with `unique_key` for merge. Spark `foreachBatch` or watermark-based streaming.
3. **Modular SQL with dbt ref()**: Each model is a SELECT. Dependencies expressed via `ref()` and `source()`. No procedural glue code.
4. **Pushdown optimization**: Run transformations where the data lives. dbt pushes to the warehouse. Spark pushes predicates to the storage layer (Parquet predicate pushdown, Delta data skipping).

## Anti-Patterns

1. **Spark for small data** -- Spinning up a Spark cluster to process 500 MB of CSV files. DuckDB or dbt handles this faster with zero infrastructure.
2. **dbt for real-time** -- dbt models are batch-oriented. Using dbt with very frequent scheduling (every 1 minute) is fragile and not designed for streaming use cases.
3. **Python in dbt when SQL suffices** -- dbt Cloud Python models add complexity (Snowpark, Spark runtime). Use Python only when SQL genuinely cannot express the logic.
4. **No testing** -- Transformations without assertions. dbt tests are cheap to write. Spark transformations should have pytest suites. Untested transforms silently corrupt data.

## Transformation Architecture Patterns

### Staging > Intermediate > Marts (dbt Convention)

| Layer | Purpose | Naming | Materialization |
|---|---|---|---|
| **Staging** | 1:1 with source tables, light cleaning (rename, cast, deduplicate) | `stg_{source}__{entity}` | View or ephemeral |
| **Intermediate** | Business logic joins, filters, calculations | `int_{entity}__{verb}` | View or ephemeral |
| **Marts** | Business-facing aggregations and metrics | `fct_{entity}`, `dim_{entity}` | Table or incremental |

### Medallion Architecture (Lakehouse Convention)

| Layer | Purpose | Format | Quality |
|---|---|---|---|
| **Bronze** | Raw ingestion, append-only, schema-on-read | Delta/Iceberg/Hudi | No quality guarantees |
| **Silver** | Cleaned, conformed, deduplicated, typed | Delta/Iceberg/Hudi | Schema enforced, nulls handled |
| **Gold** | Business-level aggregations, KPIs, features | Delta/Iceberg/Hudi | Fully validated, SLA-bound |

### Choosing Between Patterns

Both patterns solve the same problem (layered refinement). dbt's staging/intermediate/marts convention is warehouse-native and SQL-driven. The medallion architecture is lakehouse-native and works with Spark, Delta Lake, and Databricks. Many teams use both: medallion for Spark-based ingestion, dbt staging/marts for warehouse-side transformation.

## Performance Optimization Principles

1. **Predicate pushdown** -- Push WHERE clauses as close to the data source as possible. Spark and dbt both benefit from partition pruning and filter pushdown to storage (Parquet, Delta).
2. **Minimize shuffles** -- Spark shuffles (repartition, join, groupBy) are expensive. Broadcast small tables, use bucketing for repeated joins on the same key.
3. **Incremental over full rebuild** -- dbt incremental models and Spark merge-on-read avoid reprocessing unchanged data. The trade-off is complexity: incremental logic must handle late-arriving data and schema changes.
4. **Materialization strategy** -- In dbt, views are free but slow at query time; tables are fast but expensive to rebuild. Use incremental for large fact tables, views for lightweight staging models.
