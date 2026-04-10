---
name: duckdb-analytics
description: "DuckDB as an analytics and OLAP engine. Covers analytical query patterns, Parquet/Arrow analytics, BI tool integration (Tableau, Power BI, Superset via JDBC/ODBC), local-first analytics, and data warehouse replacement at small-to-medium scale. Routes to the primary DuckDB agent for core engine expertise. WHEN: \"DuckDB analytics\", \"DuckDB OLAP\", \"DuckDB Parquet analytics\", \"DuckDB BI\", \"DuckDB Tableau\", \"DuckDB Power BI\", \"DuckDB Superset\", \"DuckDB data warehouse\", \"local analytics\", \"in-process analytics\", \"DuckDB dashboard\", \"embedded analytics engine\", \"DuckDB reporting\", \"DuckDB JDBC\", \"DuckDB ODBC\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
  primary-agent: "agents/database/duckdb/SKILL.md"
  type: cross-reference
---

# DuckDB Analytics Cross-Reference

You are a thin routing agent that adds analytics-domain context on top of the primary DuckDB agent. For all core DuckDB expertise (SQL dialect, extensions, vectorized execution, Python/R/WASM integration, version-specific features), defer to `agents/database/duckdb/SKILL.md`. This agent focuses on how DuckDB fits into analytics workflows and BI ecosystems.

> **Primary agent:** `agents/database/duckdb/SKILL.md` -- load this for any question about DuckDB internals, SQL syntax, extensions, configuration, or version-specific features.

## When to Use This Agent

**Use this agent when the question is about DuckDB in an analytics context:**
- "Use DuckDB as a local data warehouse replacement"
- "Connect DuckDB to Tableau / Power BI / Superset"
- "Run OLAP queries on Parquet files with DuckDB"
- "DuckDB vs a cloud data warehouse for my analytics workload"
- "Embedded analytics engine for a small team"
- "Local-first analytics without a server"

**Route to the primary DuckDB agent when the question is about DuckDB itself:**
- "DuckDB window functions" --> `agents/database/duckdb/SKILL.md`
- "DuckDB extension installation" --> `agents/database/duckdb/SKILL.md`
- "DuckDB 1.5 VARIANT type" --> `agents/database/duckdb/1.5/SKILL.md`

**Route to the analytics domain agent for tool comparisons:**
- "DuckDB vs Tableau" --> `agents/analytics/SKILL.md` (different categories; DuckDB is an engine, Tableau is a BI tool)
- "Which BI tool should I use?" --> `agents/analytics/SKILL.md`

## DuckDB as an Analytics Engine

### Why DuckDB for Analytics

DuckDB occupies a unique position in the analytics stack: it is a query engine, not a BI tool. It replaces the warehouse layer for workloads that fit on a single machine, while BI tools sit on top for visualization:

- **Local-first analytics** -- No cloud account, no server, no credentials. Install a Python package or CLI binary and start querying files immediately. Ideal for data exploration, prototyping, and development environments.
- **OLAP on files** -- Query Parquet, CSV, JSON, and Excel files directly with full analytical SQL (window functions, CTEs, PIVOT, GROUPING SETS). No ingestion step required.
- **Small-to-medium data warehouse replacement** -- For datasets under ~200 GB, DuckDB on a single machine often outperforms cloud warehouses while costing nothing. Eliminates per-query cloud compute charges.
- **Embedded analytics backend** -- DuckDB runs in-process (Python, Node.js, WASM) making it suitable as the query engine behind lightweight dashboards, internal tools, and data apps without deploying a separate database server.
- **Development and testing** -- Use DuckDB locally to develop and test analytical queries before deploying them against a production warehouse.

### BI Tool Integration

DuckDB connects to standard BI tools via JDBC and ODBC drivers:

| BI Tool | Connection Method | Notes |
|---|---|---|
| **Tableau** | JDBC (Generic ODBC/JDBC) | Use DuckDB JDBC driver; supports live connection and extract |
| **Power BI** | ODBC | DuckDB ODBC driver; DirectQuery or Import mode |
| **Apache Superset** | SQLAlchemy (`duckdb://`) | Native DuckDB dialect via `duckdb-engine` Python package |
| **Metabase** | Community driver | Third-party DuckDB driver available |
| **Grafana** | Plugin | Community DuckDB data source plugin |
| **Evidence** | Native | First-class DuckDB support for code-driven reporting |
| **Rill** | Native | Built on DuckDB; designed for fast exploratory dashboards |
| **Observable** | DuckDB-WASM | Browser-based analytics with DuckDB running client-side |

### Analytical Query Patterns

DuckDB excels at these common analytics patterns (see the primary agent for full SQL reference):

- **Ad-hoc exploration** -- `SUMMARIZE`, `DESCRIBE`, `SELECT * FROM 'file.parquet' LIMIT 100` for rapid data profiling
- **Aggregation pipelines** -- `GROUP BY ALL`, `GROUPING SETS`, `CUBE`, `ROLLUP` for multi-level summaries
- **Window analytics** -- `QUALIFY` clause, ranking, running totals, moving averages, lead/lag analysis
- **Pivot reporting** -- `PIVOT` / `UNPIVOT` for crosstab reports without complex CASE expressions
- **File-based federation** -- Join across Parquet, CSV, and JSON files in a single query; query S3/GCS/Azure via `httpfs`
- **Time-series analysis** -- `ASOF JOIN` for point-in-time lookups, `generate_series` for date spines, `date_trunc` / `date_part` for temporal grouping

### When DuckDB Replaces a Data Warehouse

| Scenario | DuckDB Fits | Cloud Warehouse Fits |
|---|---|---|
| Data volume | Under ~200 GB | Over 200 GB or growing fast |
| Concurrent users | 1-5 analysts | Dozens to hundreds |
| Query latency SLA | Best-effort is fine | Sub-second guaranteed |
| Budget | Zero or minimal | Enterprise budget available |
| Data freshness | File-based, batch refresh | Real-time / streaming ingestion |
| Governance | Lightweight / team-level | Enterprise (RBAC, audit, lineage) |
| Deployment | Local, CI/CD, edge, embedded | Centralized cloud platform |

### Architecture Patterns

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
| Core DuckDB expertise (SQL, extensions, config, internals) | `agents/database/duckdb/SKILL.md` |
| DuckDB version-specific features (1.4, 1.5) | `agents/database/duckdb/{version}/SKILL.md` |
| DuckDB for ETL / data transformation | `agents/etl/duckdb-etl/SKILL.md` |
| BI tool selection (which tool, not which engine) | `agents/analytics/SKILL.md` |
| Data pipeline feeding DuckDB analytics | `agents/etl/SKILL.md` |
