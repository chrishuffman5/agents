# Paradigm: SQL-Native Analytics

When and why to choose SQL-first analytics tools. Covers DuckDB, Apache Superset, and Metabase.

## What Defines SQL-Native Analytics

SQL-native analytics tools put SQL at the center of the workflow. Users write or generate SQL queries against databases, warehouses, or files, and the tool handles visualization, sharing, and basic governance. There is no proprietary semantic layer or modeling language -- the SQL query IS the analysis.

Key characteristics:
- **SQL-first** -- The primary interface is a SQL editor or a point-and-click abstraction that generates SQL
- **Lightweight deployment** -- Minimal infrastructure compared to enterprise BI (often a single container or embedded library)
- **Open-source** -- Apache 2.0, AGPL, or MIT licensing; no per-user fees for core functionality
- **Database-agnostic** -- Connect to any database via JDBC/ODBC or native drivers
- **Data-team oriented** -- Designed for analysts and engineers who are comfortable with SQL, not business users who need drag-and-drop

## Choose SQL-Native Analytics When

- **The team writes SQL fluently** -- Data engineers, analytics engineers, and data analysts who think in SQL. The tool should accelerate their workflow, not replace it with a proprietary abstraction.
- **Budget constrains licensing** -- Zero per-user licensing cost for open-source tools. The cost is operational (hosting, maintenance, upgrades) rather than per-seat.
- **The use case is ad-hoc exploration** -- "Let me query this and see what's there" before building a formal dashboard. SQL Lab (Superset) and Questions (Metabase) excel at rapid exploration.
- **Embedding is a product requirement** -- Metabase and Superset both offer embedding APIs for white-label analytics inside SaaS products, at a fraction of Power BI Embedded or Tableau Embedded cost.
- **The data stack is modern and SQL-based** -- dbt + Snowflake/BigQuery/Redshift + a SQL-native BI tool is a cohesive, SQL-everywhere architecture.

## Avoid SQL-Native Analytics When

- **Business users need self-service** -- Non-technical users cannot write SQL. Enterprise BI tools with drag-and-drop interfaces (Power BI, Tableau) serve this audience better.
- **Governed metrics are a hard requirement** -- SQL-native tools lack built-in semantic layers. Each query defines its own metric logic. Use dbt metrics + SQL-native tool as a workaround, or choose a tool with a native semantic layer (Looker, Power BI).
- **Enterprise security integration is needed** -- SAML SSO, Active Directory group-based permissions, and row-level security are either absent or limited in open-source editions. Commercial editions (Metabase Enterprise, Superset + Preset.io) close some gaps.
- **Thousands of concurrent dashboard viewers** -- SQL-native tools query the database on every dashboard load (limited caching). Enterprise BI tools with in-memory models handle concurrent reads more efficiently.

## Technology Comparison Within This Paradigm

| Feature | DuckDB | Apache Superset | Metabase |
|---|---|---|---|
| **Category** | Embedded query engine | Full BI platform (dashboards + SQL Lab) | Simple BI platform (questions + dashboards) |
| **Query interface** | CLI, Python, R, JDBC, ODBC | SQL Lab (browser-based SQL editor) | Question builder (point-and-click) + SQL mode |
| **Visualization** | None built-in (use with Jupyter, Observable, BI tools) | 40+ chart types, dashboard builder | 15+ chart types, dashboard builder |
| **Data sources** | Parquet, CSV, JSON, SQLite, PostgreSQL, MySQL, S3 | Any JDBC/ODBC database, 30+ connectors | Any JDBC/ODBC database, 20+ connectors |
| **Semantic layer** | None (raw SQL) | None (SQL defines metrics) | Models (lightweight -- saved questions as building blocks) |
| **Caching** | Query result caching in-process | Configurable cache (Redis-backed) | Query result caching (internal or Redis) |
| **Embedding** | N/A (library, not a server) | Embedded dashboards (commercial via Preset.io) | iFrame + signed embedding (AGPL or commercial) |
| **Authentication** | N/A | OIDC, LDAP, OAuth, database auth | LDAP, Google/SAML SSO, JWT (commercial) |
| **Deployment** | pip install / library import (zero infrastructure) | Docker, Kubernetes, Helm chart, Preset.io (managed) | Docker, JAR file, Metabase Cloud (managed) |
| **Licensing** | MIT | Apache 2.0 | AGPL / Commercial (Metabase Enterprise) |
| **Best for** | Local analytics, Parquet/CSV analysis, data science pipelines | Technical teams needing full-featured open-source BI | Small teams wanting simple BI with minimal setup |

## Common Patterns

### DuckDB: In-Process Analytics Engine

DuckDB is not a BI tool -- it is an embedded columnar query engine. Its role in the analytics stack is as the query layer beneath a visualization tool or notebook.

**Typical usage patterns:**
- Analyst runs DuckDB in a Jupyter notebook to query Parquet files on S3
- Data pipeline uses DuckDB to transform CSVs before loading into a warehouse
- CLI-based ad-hoc exploration: `duckdb -c "SELECT * FROM 'sales_2026.parquet' LIMIT 10"`
- Application embeds DuckDB for in-app analytics without a database server

**Cross-reference:** DuckDB's primary agent lives at `skills/database/duckdb/SKILL.md`. The analytics domain focuses on DuckDB as a query engine for analytical workloads; the database domain covers DuckDB as a database technology (storage, extensions, SQL dialect).

### Superset: Full-Featured Open-Source BI

**Deployment architecture:**
- Web application (Flask + React) backed by a metadata database (PostgreSQL or MySQL)
- Celery workers for async queries and scheduled reports
- Redis for caching and Celery broker
- Connects to analytical databases via SQLAlchemy

**SQL Lab workflow:**
1. Write SQL in SQL Lab (browser-based editor with autocomplete, syntax highlighting)
2. Execute against connected database (BigQuery, Snowflake, PostgreSQL, ClickHouse, etc.)
3. Explore results, save as a dataset
4. Build visualizations from saved datasets
5. Assemble dashboards from visualizations
6. Share dashboards via URL or embedding

**Jinja templating in queries:**
```sql
SELECT *
FROM sales
WHERE sale_date >= '{{ from_dttm }}'
  AND sale_date < '{{ to_dttm }}'
  {% if filter_values('region') %}
  AND region IN ({{ "'" + "','".join(filter_values('region')) + "'" }})
  {% endif %}
```

**Limitations to know:**
- No semantic layer -- every chart defines its own SQL/metric. Conflicting metric definitions across dashboards are common without team discipline.
- Visualization options are good but not as rich as Tableau or Power BI.
- Permissions model is role-based but lacks row-level security in the open-source edition.
- Operational overhead: requires PostgreSQL/MySQL, Redis, Celery, and the web app itself.

### Metabase: Simple BI for Everyone

**Deployment architecture:**
- Single JAR file or Docker container backed by H2 (embedded) or PostgreSQL/MySQL (production)
- No additional services required for basic use (no Redis, no Celery)
- Managed option: Metabase Cloud

**Question-based workflow:**
1. Create a "question" via the visual query builder (no SQL required) or native SQL
2. Questions produce results that can be visualized as charts
3. Group questions into dashboards with filters and interactivity
4. Share dashboards via URL, email subscriptions, or embedding

**Embedding pattern:**
```javascript
// Server-side: generate signed embedding URL
const token = jwt.sign(
  {
    resource: { dashboard: 42 },
    params: { customer_id: currentUser.customerId },
    exp: Math.round(Date.now() / 1000) + (10 * 60) // 10 min expiry
  },
  METABASE_SECRET_KEY
);
const iframeUrl = `${METABASE_SITE_URL}/embed/dashboard/${token}#bordered=true&titled=true`;
```

**Limitations to know:**
- The visual query builder covers 80% of use cases but struggles with complex analytics (window functions, CTEs, multi-step transformations).
- Governance features (audit logs, content verification, granular permissions) require the commercial Enterprise edition.
- Not designed for datasets exceeding the connected database's capabilities -- no in-memory engine or caching layer beyond basic result caching.

### Connecting to Data Warehouses

All SQL-native tools share a common pattern: connect to the warehouse, query it directly, and visualize results. Performance depends entirely on the warehouse.

| Warehouse | Connection Method | Optimization Tips |
|---|---|---|
| Snowflake | SQLAlchemy (Superset), JDBC (Metabase) | Use a dedicated XS/S warehouse for BI queries; set statement timeout; leverage result caching |
| BigQuery | google-cloud-bigquery driver | Set maximum bytes billed per query to prevent cost explosions; use BI Engine for sub-second response |
| Redshift | psycopg2 / JDBC (PostgreSQL wire protocol) | Use Redshift Serverless for intermittent BI workloads; ensure distribution keys align with BI query patterns |
| PostgreSQL | psycopg2 / JDBC | Create materialized views for common dashboard queries; use pg_stat_statements to identify slow BI queries |
| ClickHouse | clickhouse-connect (Superset), JDBC (Metabase) | BI queries map well to ClickHouse's columnar model; use `FINAL` keyword carefully on ReplacingMergeTree |
