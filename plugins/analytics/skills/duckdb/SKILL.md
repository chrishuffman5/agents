---
name: duckdb
description: "DuckDB as an analytics and OLAP engine: analytical query patterns, Parquet/Arrow analytics, BI tool integration (Tableau, Power BI, Superset via JDBC/ODBC), local-first analytics, and data warehouse replacement at small-to-medium scale. Use when connecting DuckDB to a BI tool, running OLAP on files, or evaluating DuckDB as a warehouse replacement. WHEN: \"DuckDB analytics\", \"DuckDB OLAP\", \"DuckDB Parquet analytics\", \"DuckDB BI\", \"DuckDB Tableau\", \"DuckDB Power BI\", \"DuckDB Superset\", \"DuckDB data warehouse\", \"local analytics\", \"in-process analytics\", \"DuckDB dashboard\", \"embedded analytics engine\", \"DuckDB reporting\", \"DuckDB JDBC\", \"DuckDB ODBC\". Do NOT use for core DuckDB engine internals (SQL dialect, extensions, vectorized execution, config) -- that's the `duckdb` skill in the database plugin. Do NOT use for DuckDB in ETL/transformation pipelines (dbt-duckdb, ingestion, CDC) -- that's the `duckdb` skill in the etl plugin."
license: MIT
---

# DuckDB for Analytics

This skill covers how DuckDB fits into analytics workflows and BI ecosystems -- not DuckDB internals. For core DuckDB expertise (SQL dialect, extensions, vectorized execution, Python/R/WASM integration, version-specific features), see the `duckdb` skill in the database plugin.

## When to Use This Skill

**Use this skill for DuckDB in an analytics context:**
- "Use DuckDB as a local data warehouse replacement"
- "Connect DuckDB to Tableau / Power BI / Superset"
- "Run OLAP queries on Parquet files with DuckDB"
- "DuckDB vs a cloud data warehouse for my analytics workload"
- "Embedded analytics engine for a small team"
- "Local-first analytics without a server"

**Route elsewhere when the question is about DuckDB itself:**
- "DuckDB window functions", "DuckDB extension installation", "DuckDB 1.5 VARIANT type" -- the `duckdb` skill in the database plugin
- "DuckDB vs Tableau" or "which BI tool should I use?" -- the `overview` skill in this plugin (different categories; DuckDB is an engine, Tableau is a BI tool)
- DuckDB inside a dbt/Airflow/ingestion pipeline -- the `duckdb` skill in the etl plugin

## Why DuckDB for Analytics

DuckDB occupies a unique position in the analytics stack: it is a query engine, not a BI tool. It replaces the warehouse layer for workloads that fit on a single machine, while BI tools sit on top for visualization.

- **Local-first analytics** -- No cloud account, no server, no credentials. Install a Python package or CLI binary and start querying files immediately. Ideal for data exploration, prototyping, and development environments.
- **OLAP on files** -- Query Parquet, CSV, JSON, and Excel files directly with full analytical SQL (window functions, CTEs, PIVOT, GROUPING SETS). No ingestion step required.
- **Small-to-medium data warehouse replacement** -- For datasets under ~200 GB, DuckDB on a single machine often outperforms cloud warehouses while costing nothing. Eliminates per-query cloud compute charges.
- **Embedded analytics backend** -- DuckDB runs in-process (Python, Node.js, WASM), making it suitable as the query engine behind lightweight dashboards, internal tools, and data apps without deploying a separate database server.
- **Development and testing** -- Use DuckDB locally to develop and test analytical queries before deploying them against a production warehouse.

## BI Tool Integration

DuckDB connects to standard BI tools via JDBC and ODBC drivers:

| BI Tool | Connection Method | Notes |
|---|---|---|
| **Tableau** | JDBC (Generic ODBC/JDBC) | Use the DuckDB JDBC driver; supports live connection and extract |
| **Power BI** | ODBC | DuckDB ODBC driver; DirectQuery or Import mode |
| **Apache Superset** | SQLAlchemy (`duckdb://`) | Native DuckDB dialect via the `duckdb-engine` Python package |
| **Metabase** | Community driver | Third-party DuckDB driver available |
| **Grafana** | Plugin | Community DuckDB data source plugin |
| **Evidence** | Native | First-class DuckDB support for code-driven reporting |
| **Rill** | Native | Built on DuckDB; designed for fast exploratory dashboards |
| **Observable** | DuckDB-WASM | Browser-based analytics with DuckDB running client-side |

## Analytical Query Patterns

DuckDB excels at these common analytics patterns (see the database plugin's `duckdb` skill for full SQL reference):

- **Ad-hoc exploration** -- `SUMMARIZE`, `DESCRIBE`, `SELECT * FROM 'file.parquet' LIMIT 100` for rapid data profiling
- **Aggregation pipelines** -- `GROUP BY ALL`, `GROUPING SETS`, `CUBE`, `ROLLUP` for multi-level summaries
- **Window analytics** -- `QUALIFY` clause, ranking, running totals, moving averages, lead/lag analysis
- **Pivot reporting** -- `PIVOT` / `UNPIVOT` for crosstab reports without complex CASE expressions
- **File-based federation** -- Join across Parquet, CSV, and JSON files in a single query; query S3/GCS/Azure via `httpfs`
- **Time-series analysis** -- `ASOF JOIN` for point-in-time lookups, `generate_series` for date spines, `date_trunc` / `date_part` for temporal grouping

## When DuckDB Replaces a Data Warehouse

| Scenario | DuckDB Fits | Cloud Warehouse Fits |
|---|---|---|
| Data volume | Under ~200 GB | Over 200 GB or growing fast |
| Concurrent users | 1-5 analysts | Dozens to hundreds |
| Query latency SLA | Best-effort is fine | Sub-second guaranteed |
| Budget | Zero or minimal | Enterprise budget available |
| Data freshness | File-based, batch refresh | Real-time / streaming ingestion |
| Governance | Lightweight / team-level | Enterprise (RBAC, audit, lineage) |
| Deployment | Local, CI/CD, edge, embedded | Centralized cloud platform |

## Architecture Patterns

**Pattern 1: File-based analytics lakehouse**
- Store data as Parquet in S3/local disk
- Query with DuckDB (via `httpfs` for remote, direct path for local)
- Visualize with Superset, Evidence, or Rill

**Pattern 2: dbt + DuckDB for local analytics engineering**
- Use dbt Core with the `dbt-duckdb` adapter
- Develop and test models locally against DuckDB
- Optionally promote to a cloud warehouse for production

**Pattern 3: Embedded analytics in applications**
- DuckDB runs in-process (Python/Node.js/WASM)
- Application loads Parquet files or receives Arrow data
- DuckDB executes analytical queries; results rendered in the UI
- No separate database server to deploy or maintain

## Cross-References

| Scenario | Route To |
|---|---|
| Core DuckDB expertise (SQL, extensions, config, internals) | `duckdb` skill, database plugin |
| DuckDB version-specific features | `duckdb` skill references, database plugin |
| DuckDB for ETL / data transformation | `duckdb` skill, etl plugin |
| BI tool selection (which tool, not which engine) | `overview` skill, this plugin |
| Data pipeline feeding DuckDB analytics | etl plugin |
