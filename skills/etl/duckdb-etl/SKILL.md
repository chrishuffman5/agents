---
name: duckdb-etl
description: "DuckDB as an in-process data transformation and ETL engine. Covers file ingestion (Parquet/CSV/JSON/Excel), SQL-based transformations, Spark replacement for small-to-medium pipelines, dbt-duckdb integration, data lake querying, and pipeline orchestration patterns. Routes to the primary DuckDB agent for core engine expertise. WHEN: \"DuckDB ETL\", \"DuckDB transformation\", \"DuckDB pipeline\", \"DuckDB ingestion\", \"DuckDB CSV to Parquet\", \"DuckDB data loading\", \"dbt-duckdb\", \"DuckDB Spark replacement\", \"DuckDB data lake\", \"DuckDB file conversion\", \"DuckDB batch processing\", \"DuckDB COPY\", \"DuckDB export\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
  primary-agent: "skills/database/duckdb/SKILL.md"
  type: cross-reference
---

# DuckDB ETL Cross-Reference

You are a thin routing agent that adds ETL-domain context on top of the primary DuckDB agent. For all core DuckDB expertise (SQL dialect, extensions, vectorized execution, Python/R/WASM integration, version-specific features), defer to `skills/database/duckdb/SKILL.md`. This agent focuses on how DuckDB fits into data transformation and pipeline workflows.

> **Primary agent:** `skills/database/duckdb/SKILL.md` -- load this for any question about DuckDB internals, SQL syntax, extensions, configuration, or version-specific features.

## When to Use This Agent

**Use this agent when the question is about DuckDB in an ETL/ELT context:**
- "Use DuckDB to convert CSV files to Parquet"
- "Replace Spark with DuckDB for our transformation pipeline"
- "DuckDB as a dbt adapter for local development"
- "Build a file-based ETL pipeline with DuckDB"
- "Query a data lake with DuckDB instead of Spark/Athena"
- "Orchestrate DuckDB transformations with Airflow"

**Route to the primary DuckDB agent when the question is about DuckDB itself:**
- "DuckDB read_parquet options" --> `skills/database/duckdb/SKILL.md`
- "DuckDB extension ecosystem" --> `skills/database/duckdb/SKILL.md`
- "DuckDB 1.4 MERGE statement" --> `skills/database/duckdb/1.4/SKILL.md`

**Route to the transformation router for tool comparisons:**
- "dbt vs Spark vs DuckDB" --> `skills/etl/transformation/SKILL.md`
- "Which transformation tool for my pipeline?" --> `skills/etl/transformation/SKILL.md`

## DuckDB as a Transformation Engine

### Why DuckDB for ETL

DuckDB fills a gap between manual scripting and distributed compute frameworks. It provides a full analytical SQL engine that runs in-process with zero infrastructure:

- **Spark replacement for small-to-medium data** -- Datasets under ~200 GB do not need a distributed cluster. DuckDB on a single machine processes them faster than Spark (no JVM startup, no shuffle overhead, no cluster management) at zero infrastructure cost.
- **File-native ingestion** -- Read Parquet, CSV, JSON, Excel, and Avro directly with `read_parquet()`, `read_csv()`, `read_json()`, `read_xlsx()`. Glob patterns and Hive partitioning are built in. No schema definition or import step needed.
- **SQL-based transformations** -- Full analytical SQL with CTEs, window functions, PIVOT, UNION BY NAME, and complex type handling. Data engineers who think in SQL can express transformations without learning DataFrame APIs.
- **In-process execution** -- No server to deploy, no ports to open, no credentials to manage. DuckDB runs as a library inside Python, Node.js, or CLI scripts. Ideal for CI/CD pipelines and containerized jobs.
- **Zero-copy integration** -- In Python, DuckDB queries Pandas DataFrames, Polars LazyFrames, and Arrow tables without copying data. This makes it a natural transformation layer in Python-based pipelines.

### Data Ingestion Patterns

DuckDB handles the "E" and "L" of ELT natively (see primary agent for full syntax):

| Source Format | Reader | Key Options |
|---|---|---|
| Parquet | `read_parquet()` | `hive_partitioning`, glob patterns, S3/GCS/Azure via `httpfs` |
| CSV/TSV | `read_csv()` | `header`, `delim`, `columns`, `union_by_name`, `filename` |
| JSON/NDJSON | `read_json()` | `format`, `columns`, auto-detection |
| Excel | `read_xlsx()` | `sheet`, range selection |
| Avro | `read_avro()` | Schema evolution support |
| SQLite | `sqlite_scan()` | Direct federation, no migration needed |
| PostgreSQL | `postgres_scan()` | Live query federation via `postgres_scanner` extension |
| MySQL | `mysql_scan()` | Live query federation via `mysql_scanner` extension |

### Transformation Patterns

Common ETL transformations expressed in DuckDB SQL:

- **Format conversion** -- `COPY (SELECT * FROM 'input.csv') TO 'output.parquet' (FORMAT PARQUET, COMPRESSION ZSTD)` converts any supported format to Parquet with compression in a single statement.
- **Schema harmonization** -- `UNION ALL BY NAME` merges files with different column sets by matching on column name rather than position. Critical for ingesting data from multiple sources with evolving schemas.
- **Incremental processing** -- Use `read_parquet()` with `filename` column and Hive partition filtering to process only new partitions. Combine with `CREATE OR REPLACE TABLE` for idempotent overwrites.
- **Data quality checks** -- SQL assertions (`SELECT count(*) FROM staging WHERE id IS NULL` with threshold checks) validate data inline. No external framework needed for basic quality gates.
- **Partitioned writes** -- `COPY ... TO 'output/' (FORMAT PARQUET, PARTITION_BY (year, month))` produces Hive-partitioned output ready for downstream consumption by Spark, Athena, or other Parquet-aware tools.
- **Cross-source joins** -- Join a CSV lookup table against a Parquet fact table against a PostgreSQL dimension table in a single query, producing Parquet output.

### dbt-duckdb Integration

The `dbt-duckdb` adapter makes DuckDB a first-class dbt target:

- **Local development** -- Develop and test dbt models against DuckDB locally before deploying to a cloud warehouse (Snowflake, BigQuery, Redshift). Fast iteration without cloud compute costs.
- **CI/CD testing** -- Run `dbt build` against DuckDB in CI pipelines for sub-minute test cycles. DuckDB reads seed files and source fixtures natively.
- **Production for small workloads** -- For datasets under ~50 GB, DuckDB can serve as the production warehouse itself, with dbt managing the transformation layer.
- **External sources plugin** -- The `dbt-duckdb` adapter supports `external` materializations and source plugins that read directly from Parquet/CSV files, S3 paths, or even Pandas DataFrames.

### Pipeline Orchestration Patterns

DuckDB integrates cleanly into orchestration frameworks:

| Orchestrator | Integration Pattern |
|---|---|
| **Airflow** | `PythonOperator` or `BashOperator` running DuckDB CLI/Python scripts. Lightweight -- no cluster provisioning or JDBC connections needed. |
| **Dagster** | DuckDB resource with I/O manager. Native Dagster integration via `dagster-duckdb` package. |
| **Prefect** | Python tasks using `duckdb` package directly. In-process execution fits Prefect's lightweight task model. |
| **Shell scripts** | `duckdb < transform.sql` for cron-scheduled jobs. Zero dependencies beyond the CLI binary. |
| **CI/CD (GitHub Actions, etc.)** | Install DuckDB CLI or Python package, run transformation scripts as pipeline steps. |

### When DuckDB Replaces Spark

| Scenario | DuckDB Fits | Spark Fits |
|---|---|---|
| Data volume | Under ~200 GB | Over 200 GB or multi-TB |
| Compute model | Single machine | Distributed cluster |
| Language | SQL-first | Python/Scala DataFrame API |
| Startup time | Milliseconds | 30-60 seconds (JVM, cluster) |
| Infrastructure | Zero (in-process) | Cluster manager (YARN, K8s, Databricks) |
| Use case | File conversion, SQL transforms, dbt models | ML pipelines, graph processing, streaming |
| Cost | Free | Cluster compute (EMR, Dataproc, Databricks) |
| Team skills | SQL-proficient data engineers | Python/Scala engineers with Spark experience |

## Cross-References

| Scenario | Route To |
|---|---|
| Core DuckDB expertise (SQL, extensions, config, internals) | `skills/database/duckdb/SKILL.md` |
| DuckDB version-specific features (1.4, 1.5) | `skills/database/duckdb/{version}/SKILL.md` |
| DuckDB for analytics / BI integration | `skills/analytics/duckdb-analytics/SKILL.md` |
| Transformation tool comparison (dbt vs Spark vs DuckDB) | `skills/etl/transformation/SKILL.md` |
| ETL architecture and pipeline design | `skills/etl/SKILL.md` |
| dbt Core expertise | `skills/etl/transformation/dbt-core/SKILL.md` |
| Orchestration (Airflow, SSIS) | `skills/etl/orchestration/SKILL.md` |
