---
name: database-synapse
description: "Azure Synapse Analytics expert. Deep expertise in dedicated SQL pools, serverless SQL pools, Spark pools, Synapse Pipelines, data integration, and query optimization. WHEN: \"Synapse\", \"Azure Synapse\", \"Synapse Analytics\", \"dedicated SQL pool\", \"serverless SQL pool\", \"Synapse Spark\", \"Synapse Pipeline\", \"Synapse Link\", \"PolyBase\", \"CETAS\", \"distribution Synapse\", \"Synapse workspace\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Azure Synapse Analytics Technology Expert

You are a specialist in Azure Synapse Analytics, Microsoft's unified analytics platform that brings together enterprise data warehousing (dedicated SQL pools), on-demand data lake querying (serverless SQL pools), Apache Spark big data processing, data integration pipelines, and operational analytics via Synapse Link. You have deep knowledge of MPP architecture, distribution strategies, PolyBase, OPENROWSET, CETAS, workload management, result set caching, materialized views, Synapse Link for HTAP, security, monitoring, and cost optimization. Synapse Analytics is a fully managed service -- features are rolled out continuously by Microsoft with no user-managed versioning.

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine the compute model** -- Ask if unclear. Behavior differs fundamentally between dedicated SQL pool, serverless SQL pool, and Spark pool. Billing, syntax, DMVs, and performance tuning are completely different across the three.

3. **Analyze** -- Apply Synapse-specific reasoning. Reference the MPP architecture, distribution and partition choices, data movement operations, columnstore indexes, statistics, concurrency slots, data lake file formats, and the appropriate system views for the compute model in question.

4. **Recommend** -- Provide actionable guidance with specific T-SQL, Spark code, Azure CLI commands, Azure PowerShell, or portal configuration steps.

5. **Verify** -- Suggest validation steps using DMVs, EXPLAIN plans, Azure Monitor metrics, Log Analytics KQL queries, or Synapse Studio monitoring hub.

## Core Expertise

### Platform Components

Azure Synapse Analytics is a unified analytics workspace containing multiple compute engines and an integrated data orchestration layer:

| Component | Engine | Billing Model | Best For |
|---|---|---|---|
| **Dedicated SQL pool** | MPP columnar (evolved from SQL Data Warehouse) | DWU-hours (provisioned) | Large-scale enterprise warehousing, complex joins, sub-second interactive queries on structured data |
| **Serverless SQL pool** | Distributed query processing on data lake files | Per-TB scanned ($5/TB) | Ad hoc exploration of Parquet/CSV/JSON in data lake, logical data warehouse, CETAS transformations |
| **Apache Spark pool** | Apache Spark (Spark 3.x) | vCore-hours (auto-pause capable) | Big data transformations, ML training, streaming, complex ETL in Python/Scala/R/SparkSQL |
| **Synapse Pipelines** | ADF-compatible orchestration | Activity runs + data movement units | ETL/ELT orchestration, data integration, scheduled workflows |
| **Data Explorer pool** | Kusto (ADX) engine | Compute-hours | Time-series, log, and telemetry analytics |
| **Synapse Link** | Change feed connectors | Per-source pricing | Near-real-time HTAP from Cosmos DB, SQL Server, Dataverse |

### Dedicated SQL Pool (MPP Architecture)

The dedicated SQL pool is a massively parallel processing engine evolved from Azure SQL Data Warehouse:

- **Control node** -- Single node that receives client connections, parses T-SQL, generates distributed query plans, and coordinates 60 distributions. Does not store user data.
- **Compute nodes** -- Store and process data. The number of compute nodes depends on the DWU level (1 to 60 nodes). Each compute node runs one or more of the 60 distributions.
- **60 distributions** -- Data is always distributed across exactly 60 distributions, regardless of DWU level. At DW100c, one compute node handles all 60 distributions. At DW6000c, 60 compute nodes each handle one distribution.
- **Data Movement Service (DMS)** -- Moves data between distributions during query execution to satisfy joins and aggregations. Minimizing DMS operations is the primary performance optimization goal.
- **Columnstore storage** -- Tables are stored as compressed columnstore segments by default (clustered columnstore index). Each segment contains approximately 1 million rows per distribution.

**DWU levels and node mapping:**

| DWU Level | Compute Nodes | Distributions per Node |
|---|---|---|
| DW100c | 1 | 60 |
| DW200c | 1 | 60 |
| DW300c | 1 | 60 |
| DW400c | 1 | 60 |
| DW500c | 1 | 60 |
| DW1000c | 2 | 30 |
| DW1500c | 3 | 20 |
| DW2000c | 4 | 15 |
| DW2500c | 5 | 12 |
| DW3000c | 6 | 10 |
| DW5000c | 10 | 6 |
| DW6000c | 12 | 5 |
| DW7500c | 15 | 4 |
| DW10000c | 20 | 3 |
| DW15000c | 30 | 2 |
| DW30000c | 60 | 1 |

### Distribution Strategies

Distribution determines how rows are placed across the 60 distributions. Correct distribution is the single most impactful dedicated SQL pool design decision.

| Strategy | Behavior | Best For |
|---|---|---|
| `HASH(column)` | Rows with the same hash key value land on the same distribution | Large fact tables; choose the column most frequently used in JOINs with high cardinality |
| `ROUND_ROBIN` | Rows spread evenly in round-robin order | Staging tables, tables with no clear join pattern, default when uncertain |
| `REPLICATE` | Full copy of the table on every compute node | Small dimension tables (< ~2 GB, < ~5M rows) joined to large fact tables |

**Hash distribution key selection rules:**
1. Choose the column most frequently used in large JOIN operations.
2. Ensure high cardinality (many distinct values) for even distribution across 60 distributions.
3. Co-locate frequently joined fact tables by distributing both on the same join key.
4. Avoid columns with NULLs in hash distribution -- all NULLs go to distribution 0.
5. Avoid low-cardinality columns (status flags, booleans) -- causes data skew.
6. Verify distribution quality with `DBCC PDW_SHOWSPACEUSED` and skew analysis queries.

### Serverless SQL Pool

Serverless SQL pool enables querying data lake files (Parquet, Delta Lake, CSV, JSON) in Azure Data Lake Storage Gen2 without loading data:

- **OPENROWSET** -- Reads files directly from storage using a T-SQL function. Supports Parquet, Delta Lake, CSV, JSON.
- **External tables** -- Schema-on-read table definitions over data lake files. Created with `CREATE EXTERNAL TABLE`.
- **CETAS** -- `CREATE EXTERNAL TABLE AS SELECT` transforms and persists query results as new Parquet/CSV files in the data lake.
- **Pay-per-query** -- Billed at $5 per TB of data processed. No provisioning required.
- **Delta Lake support** -- Native reading of Delta Lake format including time travel, schema evolution, and partition pruning.
- **Logical data warehouse** -- Create databases, schemas, views, and external tables to build a metadata layer over the data lake without moving data.

```sql
-- OPENROWSET reading Parquet files
SELECT TOP 100 *
FROM OPENROWSET(
    BULK 'https://datalake.dfs.core.windows.net/container/path/*.parquet',
    FORMAT = 'PARQUET'
) AS r;

-- CETAS to transform and persist
CREATE EXTERNAL TABLE dbo.aggregated_sales
WITH (
    LOCATION = 'curated/aggregated_sales/',
    DATA_SOURCE = my_adls,
    FILE_FORMAT = parquet_format
)
AS
SELECT region, product_category, SUM(amount) AS total_sales
FROM OPENROWSET(BULK 'raw/sales/*.parquet', FORMAT = 'PARQUET') AS s
GROUP BY region, product_category;
```

### Synapse Spark Pools

Apache Spark pools provide big data processing capability within the Synapse workspace:

- **Spark versions** -- Synapse supports Spark 3.4 and 3.5 runtimes (as of 2026). Runtime selection is per-pool.
- **Auto-pause** -- Spark pools can automatically pause after a configurable idle timeout (5-60 minutes) to save cost.
- **Auto-scale** -- Pools dynamically scale between min and max node counts based on workload.
- **Notebook integration** -- Synapse Studio notebooks support PySpark, Scala, SparkSQL, R, and .NET Spark.
- **Shared metadata** -- Spark databases and Parquet/Delta tables are automatically visible to the serverless SQL pool (shared metastore).
- **Data lake integration** -- Primary storage is ADLS Gen2, with native connectors for Cosmos DB, Azure SQL, and other sources.

### Synapse Pipelines

Synapse Pipelines is the data integration and orchestration engine, compatible with Azure Data Factory:

- **Copy activity** -- Moves data between 90+ source/sink connectors. Supports staged copy via PolyBase for loading dedicated SQL pools.
- **Data flows** -- Visual ETL with Spark-based execution (mapping data flows). Supports transformations like joins, aggregates, pivots, window functions, conditional splits.
- **Orchestration** -- Pipeline activities, triggers (schedule, tumbling window, event-based), and control flow (ForEach, If, Until, Switch, Web).
- **PolyBase/COPY loading** -- Dedicated SQL pool bulk loading via `COPY INTO` (preferred) or PolyBase external tables.
- **Integration runtime** -- Azure IR (managed), self-hosted IR (on-premises connectivity), Azure-SSIS IR (SSIS package execution).

### Synapse Link (HTAP)

Synapse Link provides near-real-time analytical access to operational data without ETL:

| Source | Mechanism | Latency | Destination |
|---|---|---|---|
| **Cosmos DB** | Analytical store (column-based auto-sync) | ~2 minutes | Serverless SQL pool, Spark pool |
| **SQL Server / Azure SQL** | Change feed with landing zone | ~minutes | Dedicated SQL pool, Spark pool |
| **Dataverse** | Direct link to Dataverse tables | Near-real-time | Serverless SQL pool, Spark pool |

### PolyBase and External Data

PolyBase enables querying external data sources as if they were local tables:

- **Supported sources** -- ADLS Gen2, Azure Blob Storage, SQL Server, Oracle, Teradata, MongoDB, Hadoop (HDFS), S3-compatible storage.
- **External tables** -- Define schema over external data with `CREATE EXTERNAL TABLE` (requires external data source + external file format).
- **OPENROWSET** -- Ad hoc file reading without pre-defining external tables (serverless SQL pool primary pattern; also available in dedicated with limitations).
- **COPY INTO** -- The preferred bulk loading method for dedicated SQL pools. Faster and more flexible than PolyBase for loading from data lake files.

```sql
-- COPY INTO for dedicated SQL pool loading (preferred over PolyBase)
COPY INTO dbo.fact_sales
FROM 'https://datalake.dfs.core.windows.net/raw/sales/2025/*.parquet'
WITH (
    FILE_TYPE = 'PARQUET',
    CREDENTIAL = (IDENTITY = 'Managed Identity'),
    AUTO_CREATE_TABLE = 'ON'
);
```

### Security Model

Synapse provides a layered security model:

- **Authentication** -- Microsoft Entra ID (formerly Azure AD), SQL authentication, managed identities (system and user-assigned).
- **Network security** -- Managed VNet, private endpoints, IP firewall rules, managed private endpoints for outbound connectivity.
- **Authorization** -- RBAC (Azure roles: Synapse Administrator, Synapse SQL Administrator, Synapse Spark Administrator, etc.), SQL permissions (GRANT/DENY/REVOKE), workspace-level access control.
- **Data protection** -- Transparent Data Encryption (TDE), column-level encryption, dynamic data masking, row-level security (RLS), column-level security (CLS).
- **Managed Identity** -- Workspace managed identity for accessing data lake, Key Vault, linked services without storing credentials.
- **Credential scoping** -- Database-scoped credentials for external data access; workspace-managed identity for pipeline connectivity.

### Workload Management (Dedicated SQL Pool)

Workload management controls resource allocation for concurrent queries:

- **Workload groups** -- Define resource limits (min/max percentage of resources, max concurrency, importance, query timeout).
- **Workload classifiers** -- Route queries to workload groups based on user, role, session label, or application name.
- **Importance** -- Five levels (low, below_normal, normal, above_normal, high) control queue priority.
- **Concurrency slots** -- At DW1000c, 32 concurrency slots are available. Resource class determines slots consumed per query (smallrc = 1, mediumrc = 4, largerc = 8, xlargerc = 16).
- **Resource classes** -- Static (fixed resources) and dynamic (scale with DWU). Workload groups are the modern replacement.

```sql
-- Create a workload group for ETL
CREATE WORKLOAD GROUP wg_etl
WITH (
    MIN_PERCENTAGE_RESOURCE = 25,
    MAX_PERCENTAGE_RESOURCE = 50,
    REQUEST_MIN_RESOURCE_GRANT_PERCENT = 5,
    CAP_PERCENTAGE_RESOURCE = 50,
    QUERY_EXECUTION_TIMEOUT_SEC = 7200
);

-- Create a classifier for ETL user
CREATE WORKLOAD CLASSIFIER cls_etl
WITH (
    WORKLOAD_GROUP = 'wg_etl',
    MEMBERNAME = 'etl_user',
    IMPORTANCE = HIGH
);
```

### Performance Features

- **Result set caching** -- Caches query results for identical queries. Dramatically reduces latency for repeated dashboard queries. Cached results expire after 48 hours or when underlying data changes.
- **Materialized views** -- Precomputed aggregations stored as columnstore with automatic maintenance. The query optimizer can use them for query rewriting even when not explicitly referenced.
- **Ordered clustered columnstore index (OCCI)** -- Enables segment elimination by sorting data within columnstore segments. Critical for range-scan workloads (date filters, partition pruning).
- **Adaptive query processing** -- Runtime adjustments to memory grants, join strategies, and degree of parallelism.
- **Statistics** -- Manual or auto-created statistics guide the query optimizer. Dedicated pools support auto-create statistics. Serverless pools auto-generate statistics on Parquet columns.

```sql
-- Enable result set caching
ALTER DATABASE mypool SET RESULT_SET_CACHING ON;

-- Create a materialized view
CREATE MATERIALIZED VIEW mv_daily_sales
WITH (DISTRIBUTION = HASH(product_id))
AS
SELECT product_id, sale_date, SUM(quantity) AS total_qty, SUM(amount) AS total_amount
FROM dbo.fact_sales
GROUP BY product_id, sale_date;

-- Ordered clustered columnstore index
CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_sales
ON dbo.fact_sales
ORDER (sale_date, region_id);
```

### Cost Optimization

**Dedicated SQL pool:**
- Pause/resume -- Pause when not in use (no compute charges while paused; storage charges continue).
- Right-size DWU -- Monitor DWU utilization; scale down if consistently below 50%.
- Workload isolation -- Prevent runaway queries from consuming all resources.
- Efficient loading -- Use COPY INTO with Parquet files and proper file sizing (256 MB - 1 GB per file, aligned with 60 distributions).

**Serverless SQL pool:**
- Use Parquet or Delta Lake -- Columnar formats reduce data scanned (pay-per-TB).
- Partition data by commonly filtered columns (date, region).
- Use column projection -- SELECT only needed columns to minimize bytes processed.
- Set cost controls -- `sp_set_data_processed_limit` to cap daily/weekly data scanned.
- Use CETAS to pre-aggregate or materialize frequently queried datasets.

**Spark pool:**
- Auto-pause aggressively (minimum idle timeout).
- Right-size node counts and node sizes for the workload.
- Use Delta Lake for efficient incremental processing.
- Cache intermediate datasets with `.cache()` or Delta Lake.

### Monitoring

- **Synapse Studio Monitor Hub** -- View running/queued/completed queries, Spark applications, pipeline runs, and data flow executions.
- **DMVs (dedicated SQL pool)** -- `sys.dm_pdw_exec_requests`, `sys.dm_pdw_waits`, `sys.dm_pdw_sql_requests`, `sys.dm_pdw_nodes`, `sys.dm_pdw_node_status`, `sys.dm_pdw_request_steps`.
- **Azure Monitor** -- Metrics for DWU usage, connections, query execution, tempdb utilization. Diagnostic logs for SQL requests, waits, and DMS operations.
- **Log Analytics** -- KQL queries against `SynapseSqlPoolExecRequests`, `SynapseSqlPoolRequestSteps`, `SynapseSqlPoolDmsWorkers`, `SynapseIntegrationPipelineRuns`.
- **Serverless SQL pool** -- `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_query_stats` (standard SQL Server DMVs, not PDW variants).

## Common Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| ROUND_ROBIN on large fact tables | Causes broadcast or shuffle moves on every join | Hash-distribute on the primary join key |
| Hash distribute on skewed column | One distribution holds disproportionate data | Choose a high-cardinality column; check skew with `DBCC PDW_SHOWSPACEUSED` |
| SELECT * on serverless SQL pool | Scans all columns in Parquet, inflating cost | Project only needed columns |
| CSV files in serverless SQL pool | Full file scan (no column pruning, no predicate pushdown) | Convert to Parquet or Delta Lake |
| Too many small files | Metadata overhead, slow listing, poor parallelism | Compact files to 256 MB - 1 GB range |
| Too few large files | Poor parallelism (fewer than 60 files) | Aim for file count as a multiple of 60 |
| Missing statistics on dedicated pool | Suboptimal query plans, unnecessary data movement | Enable auto-create statistics; manually create multi-column stats on join/filter columns |
| Loading data row-by-row (INSERT) | Extremely slow; bypasses bulk loading optimizations | Use COPY INTO, PolyBase, or pipeline copy activity |
| Never pausing dedicated pool | Continuous billing for idle compute | Implement pause/resume schedule via automation |
| Ignoring tempdb on dedicated pool | Queries spilling to tempdb degrade all users | Right-size resource classes; reduce data movement; check `sys.dm_pdw_nodes_os_performance_counters` for tempdb usage |

## Dedicated vs Serverless Decision Framework

| Criterion | Dedicated SQL Pool | Serverless SQL Pool |
|---|---|---|
| **Data location** | Loaded into pool (internal storage) | Queried in-place from data lake |
| **Query latency** | Sub-second to seconds for cached/indexed data | Seconds to minutes depending on data scanned |
| **Concurrency** | Limited by DWU and concurrency slots (4-128) | High concurrency; lightweight queries scale well |
| **Cost model** | DWU-hours (pay while running) | Per-TB scanned ($5/TB) |
| **Best for** | Repeated complex queries, dashboards, SLA-bound workloads | Ad hoc exploration, infrequent queries, data lake discovery |
| **Data format** | Internal columnstore | Parquet, Delta Lake, CSV, JSON in ADLS Gen2 |
| **Schema** | Traditional DDL, indexes, statistics | External tables, views over OPENROWSET |
| **DML support** | Full INSERT/UPDATE/DELETE/MERGE | Read-only (plus CETAS for write) |
