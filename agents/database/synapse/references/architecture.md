# Azure Synapse Analytics Architecture Reference

## Platform Architecture Overview

Azure Synapse Analytics is a unified analytics service comprising multiple compute engines sharing a common workspace, metadata store, security model, and monitoring infrastructure. The workspace is the top-level Azure resource that contains all analytics components.

### Workspace Components

```
Synapse Workspace
├── Dedicated SQL pools (MPP data warehouse)
├── Serverless SQL pool (built-in, always available)
├── Apache Spark pools (big data compute)
├── Data Explorer pools (Kusto/ADX engine)
├── Synapse Pipelines (data integration/orchestration)
├── Synapse Link (HTAP connectors)
├── Managed VNet (network isolation)
├── Linked services (connection definitions)
├── Managed Identity (workspace-level identity)
└── Synapse Studio (unified web IDE)
```

### Shared Metadata

A critical architectural feature: Spark pools and serverless SQL pools share a Hive-compatible metastore. When a Spark pool creates a database, table, or Delta Lake table, it is immediately visible to the serverless SQL pool as an external table. This enables polyglot analytics -- data engineers use Spark for ETL, and analysts query the same data via T-SQL in the serverless pool.

Shared metadata rules:
- Spark databases map to serverless SQL pool databases
- Spark Parquet tables map to external tables in serverless SQL pool
- Spark Delta Lake tables are queryable via serverless SQL pool with full Delta semantics
- Spark CSV tables are NOT shared (only Parquet and Delta)
- Dedicated SQL pools do NOT participate in shared metadata -- they maintain their own catalog

## Dedicated SQL Pool Architecture

### MPP Engine Internals

The dedicated SQL pool uses a massively parallel processing (MPP) architecture directly descended from the PDW (Parallel Data Warehouse / Analytics Platform System) engine:

```
Client Connection
       │
       ▼
┌──────────────┐
│ Control Node │  (query parsing, optimization, coordination)
└──────┬───────┘
       │  Distributed Query Plan
       ▼
┌──────────────────────────────────────────────────────┐
│              Data Movement Service (DMS)              │
│  (ShuffleMove, BroadcastMove, TrimMove, PartitionMove)│
└──────────────────────────────────────────────────────┘
       │
       ▼
┌─────────┐  ┌─────────┐  ┌─────────┐     ┌─────────┐
│ Compute │  │ Compute │  │ Compute │ ... │ Compute │
│ Node 1  │  │ Node 2  │  │ Node 3  │     │ Node N  │
│ (dist   │  │ (dist   │  │ (dist   │     │ (dist   │
│  1..k)  │  │  k+1..) │  │   ...)  │     │  ..60)  │
└─────────┘  └─────────┘  └─────────┘     └─────────┘
```

**Control node:**
- Receives all client connections (TDS protocol, port 1433)
- Runs the SQL optimizer to produce a distributed query plan (DSQL)
- Coordinates query execution across compute nodes
- Aggregates partial results from compute nodes into the final result set
- Houses the metadata catalog (sys tables, DMVs)
- Does NOT store user data

**Compute nodes:**
- Store and process user data in columnstore format
- Each compute node runs a SQL Server instance (PDW edition)
- Number of compute nodes is determined by DWU level (1 at DW100c, 60 at DW30000c)
- Each compute node manages a subset of the 60 distributions

**Distributions:**
- The fundamental unit of data storage and query parallelism
- Always exactly 60 distributions, regardless of DWU level
- Each distribution is an independent SQL Server database with its own columnstore segments, statistics, and query processing
- At lower DWU levels, multiple distributions share one compute node (e.g., DW100c = 60 distributions on 1 node)
- At DW30000c, each distribution has its own compute node

### Data Movement Service (DMS)

DMS is the internal component that moves data between distributions during query execution. It is the primary bottleneck in most slow queries.

**DMS operation types:**

| Operation | Description | Cause | Cost |
|---|---|---|---|
| **ShuffleMove** | Redistributes data by a hash key across all 60 distributions | JOIN or GROUP BY on a column different from the distribution key | High -- moves data proportional to table size |
| **BroadcastMove** | Copies entire table to all compute nodes | Small table joined to a hash-distributed table (when not replicated) | Moderate -- proportional to broadcast table size x node count |
| **TrimMove** | Sends data to a single distribution | INSERT...SELECT into a hash-distributed table, certain aggregations | Moderate |
| **PartitionMove** | Moves data between partitions on different nodes | Partition switching operations | Low -- typically metadata only |
| **ReturnOperation** | Returns result to control node | Every query (final step) | Low -- proportional to result set size |

**Minimizing DMS:**
1. Hash-distribute large fact tables on their primary join key
2. Replicate small dimension tables (< 2 GB)
3. Co-locate joined fact tables on the same distribution key
4. Use compatible distribution keys in materialized views
5. Avoid GROUP BY / ORDER BY on non-distribution key columns on large datasets when possible

### Columnstore Storage

Dedicated SQL pools store data in clustered columnstore indexes (CCI) by default:

- **Row groups** -- Data is organized into row groups of approximately 1,048,576 rows each. The quality of row groups directly impacts query performance and compression.
- **Column segments** -- Within each row group, each column is compressed independently into a segment. Segments are the unit of I/O.
- **Segment elimination** -- The query engine maintains min/max values for each segment. Predicates that fall outside a segment's range cause the entire segment to be skipped.
- **Deltastore** -- New rows or trickle inserts go into an in-memory deltastore (a B-tree rowstore). When the deltastore accumulates ~1 million rows, the tuple mover compresses it into a new columnstore row group.
- **Tuple mover** -- Background process that compresses deltastore row groups into compressed columnstore segments. Runs automatically but can be triggered with `ALTER INDEX ... REORGANIZE`.

**Row group quality matters:**
- Ideal: Every row group has close to 1,048,576 rows
- Poor: Many row groups with far fewer rows (e.g., 10,000 rows) -- caused by small batch inserts, partition switching of small datasets, or excessive delete operations
- Diagnosis: `sys.dm_pdw_nodes_column_store_row_groups` shows row group state and row counts
- Fix: `ALTER INDEX ALL ON table REBUILD` to recompress with optimal row groups

### Partition Architecture

Table partitioning in dedicated SQL pool operates within each distribution:

```
Table: fact_sales (HASH distributed on customer_id)
├── Distribution 1
│   ├── Partition 2024-01
│   ├── Partition 2024-02
│   └── ... (one partition per range per distribution)
├── Distribution 2
│   ├── Partition 2024-01
│   ├── Partition 2024-02
│   └── ...
└── ... (60 distributions total, each with all partitions)
```

- Total physical partitions = 60 distributions x N partitions
- Each physical partition should have at least 1 million rows for healthy columnstore segments
- Over-partitioning (e.g., daily partitions on a small table) degrades columnstore quality
- Rule of thumb: Each partition in each distribution should have >= 1 million rows => at least 60 million rows per partition range

**Partition switching:**
- Near-instantaneous metadata operation for loading and archiving
- Load data into a staging table, then `ALTER TABLE ... SWITCH PARTITION` to the fact table
- Source and destination must be identically distributed, partitioned, and have the same columnstore index
- Partition switching is the recommended pattern for large incremental loads

### Statistics Engine

The query optimizer relies on statistics to estimate cardinalities and choose optimal plans:

- **Auto-create statistics** -- Enabled by default (`AUTO_CREATE_STATISTICS ON`). The optimizer creates single-column statistics on first encounter.
- **Manual statistics** -- Multi-column statistics must be created manually. Critical for join columns and compound predicates.
- **Statistics update** -- NOT automatic in dedicated pools. Statistics must be updated manually or via a post-load script. Stale statistics are a leading cause of poor query plans.
- **FULLSCAN vs SAMPLE** -- `WITH FULLSCAN` reads all rows (best accuracy, slowest). Sample-based is faster for very large tables.
- **Histogram** -- Each statistic has a histogram with up to 200 steps. Limited granularity can affect estimates on high-cardinality columns.

```sql
-- Create multi-column statistics
CREATE STATISTICS stat_customer_region
ON dbo.fact_sales (customer_id, region_id)
WITH FULLSCAN;

-- Update all statistics in the database after a load
EXEC sp_updatestats;

-- Update statistics on a specific table
UPDATE STATISTICS dbo.fact_sales;
```

## Serverless SQL Pool Architecture

### Distributed Query Processing

The serverless SQL pool processes queries directly against files in Azure Data Lake Storage Gen2:

```
Client Connection
       │
       ▼
┌─────────────────┐
│   Front-end     │  (T-SQL parsing, optimization)
│   Service       │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│   Distributed Query Processing (DQP)    │
│   Multiple reader nodes in parallel     │
│   ┌──────┐ ┌──────┐ ┌──────┐          │
│   │Reader│ │Reader│ │Reader│ ...       │
│   │Node 1│ │Node 2│ │Node 3│          │
│   └──────┘ └──────┘ └──────┘          │
│       │        │        │              │
│       ▼        ▼        ▼              │
│  ┌─────────────────────────────────┐   │
│  │     ADLS Gen2 (data lake)       │   │
│  │  Parquet / Delta / CSV / JSON   │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Query execution model:**
1. Client submits T-SQL with OPENROWSET or referencing external tables
2. Front-end service parses the query, resolves file paths (potentially using wildcards/partitioned paths)
3. DQP determines optimal parallelism based on file count, file sizes, and available resources
4. Reader nodes fetch file metadata (Parquet footer, row group info) from ADLS Gen2
5. Predicate pushdown and column pruning are applied at the storage read level
6. Partial results are aggregated and returned to the client

**Key optimizations:**
- **Column pruning** -- Only requested columns are read from Parquet/Delta files
- **Row group elimination** -- Parquet statistics (min/max) skip irrelevant row groups
- **Partition elimination** -- Filepath-based partitioning (e.g., `/year=2024/month=01/`) is used for pruning via `filepath()` function
- **File elimination** -- Delta Lake transaction log metadata enables file-level skipping

### File Format Performance Hierarchy

| Format | Column Pruning | Predicate Pushdown | Partition Pruning | Relative Cost | Recommendation |
|---|---|---|---|---|---|
| **Parquet** | Yes | Yes (row group stats) | Yes (path-based) | Lowest | Default choice for analytics |
| **Delta Lake** | Yes | Yes (file-level stats + row group) | Yes (Delta partition) | Lowest | Best for mutable/versioned datasets |
| **JSON** | Partial (schema inference) | No | Yes (path-based) | High | Use only when necessary; consider converting |
| **CSV** | No (full row scan) | No | Yes (path-based) | Highest | Avoid for analytics; convert to Parquet |

### Cost Model

Serverless SQL pool charges $5 per TB of data processed:

- Data processed = bytes read from storage after column pruning and row group elimination
- Minimum charge per query: 10 MB
- Parquet with column projection can reduce cost by 10-100x compared to CSV
- Delta Lake statistics can further reduce cost through file-level skipping
- Cost controls: `sp_set_data_processed_limit` to set daily/weekly/monthly caps

## Spark Pool Architecture

### Cluster Model

Each Spark pool is an auto-managed Spark cluster:

- **Driver node** -- Coordinates Spark jobs, maintains SparkContext
- **Executor nodes** -- Run tasks in parallel, cache data
- **Node sizes** -- Small (4 vCores, 32 GB), Medium (8 vCores, 64 GB), Large (16 vCores, 128 GB), XLarge (32 vCores, 256 GB), XXLarge (64 vCores, 512 GB)
- **Auto-scale** -- Scales between configured min and max nodes based on workload
- **Auto-pause** -- Shuts down the cluster after configurable idle period (5-60 minutes)
- **Dynamic resource allocation** -- Spark can dynamically adjust executor count within the auto-scale range

### Runtime Versions

Synapse Spark supports multiple Apache Spark runtimes:

| Runtime | Spark Version | Scala | Python | Java | Delta Lake | Status |
|---|---|---|---|---|---|---|
| Apache Spark 3.4 | 3.4.x | 2.12 | 3.10 | 1.8/11 | 2.4 | GA |
| Apache Spark 3.5 | 3.5.x | 2.12 | 3.11 | 1.8/11 | 3.x | GA |

### Storage Integration

- Primary storage is always ADLS Gen2 (linked to the workspace)
- Spark uses ABFS driver (`abfss://container@account.dfs.core.windows.net/path`)
- Delta Lake is the recommended table format for Spark workloads
- Spark tables registered in the shared metastore are accessible from serverless SQL pool

## Synapse Link Architecture

### Cosmos DB Analytical Store

Synapse Link for Cosmos DB enables near-real-time analytics without impacting transactional workloads:

```
┌──────────────────────┐     Auto-sync      ┌──────────────────────┐
│  Cosmos DB Account   │  (~2 min latency)  │  Analytical Store     │
│  (Transactional/     │ ──────────────────► │  (Column-oriented)    │
│   Row-oriented)      │                     │  - Auto-compacted     │
│                      │                     │  - Full fidelity      │
└──────────────────────┘                     │  - Schema inference   │
                                             └──────────┬───────────┘
                                                        │
                                          ┌─────────────┼─────────────┐
                                          ▼             ▼             ▼
                                   ┌───────────┐ ┌───────────┐ ┌───────────┐
                                   │ Serverless│ │  Spark    │ │ Dedicated │
                                   │ SQL Pool  │ │  Pool     │ │ SQL Pool  │
                                   └───────────┘ └───────────┘ └───────────┘
```

- Analytical store is a fully isolated column-oriented store within Cosmos DB
- Auto-sync from transactional store with ~2-minute latency
- No impact on transactional RU consumption
- Schema is auto-inferred (well-defined or full fidelity mode)
- Queryable via `OPENROWSET` in serverless SQL pool or native Spark connector
- Supports Cosmos DB NoSQL and MongoDB APIs

### SQL Server / Azure SQL Link

Synapse Link for SQL captures changes from SQL Server or Azure SQL Database:

- Uses change feed technology to capture inserts, updates, deletes
- Landing zone in ADLS Gen2 stores changes in Parquet format
- Changes are applied to dedicated SQL pool or Spark pool tables
- Supports initial snapshot + incremental sync
- Self-hosted integration runtime required for on-premises SQL Server

## Network Architecture

### Managed VNet

When a Synapse workspace is created with a managed VNet:

- All Spark pools and pipeline integration runtimes run inside the managed VNet
- Outbound connectivity from the managed VNet is controlled via managed private endpoints
- Managed private endpoints create private connections to Azure services (storage, databases, Key Vault)
- No public IP addresses are assigned to Spark or pipeline compute

### Private Endpoints

```
Client (on-prem or VNet)
       │
       │ Private endpoint to Synapse workspace
       ▼
┌──────────────────────┐
│  Synapse Workspace   │
│  (private endpoint   │
│   for SQL, Dev,      │
│   Serverless SQL)    │
└──────────┬───────────┘
           │
           │ Managed private endpoints
           ▼
┌──────────────────────┐
│  ADLS Gen2, Key Vault│
│  Cosmos DB, Azure SQL│
│  (private endpoints) │
└──────────────────────┘
```

Three workspace sub-resources require separate private endpoints:
1. **SQL** -- Dedicated SQL pool connections
2. **SqlOnDemand** -- Serverless SQL pool connections
3. **Dev** -- Synapse Studio, pipeline management, Spark management

### Data Exfiltration Protection

When enabled, managed private endpoints can only connect to approved Microsoft Entra tenants. This prevents data exfiltration to unauthorized storage accounts or services.

## Caching Architecture

### Result Set Caching (Dedicated SQL Pool)

- Cached in local SSD storage on the control node
- Cache key = query text hash + database + schema + user security context
- Maximum cache size: 1 TB per dedicated SQL pool
- Entries expire after 48 hours or when underlying data changes
- Cache is invalidated per-table when DML operations modify the table
- Only the first execution incurs compute cost; subsequent cache hits return in milliseconds
- Disabled by default; enable per database: `ALTER DATABASE mypool SET RESULT_SET_CACHING ON`
- Check cache hit/miss: `sys.dm_pdw_exec_requests.result_cache_hit`

### Materialized View Auto-Refresh

- Materialized views are stored as columnstore segments within the distribution
- When base table data changes, the materialized view is marked stale
- Automatic refresh occurs on next query that benefits from the view (lazy maintenance)
- The optimizer may rewrite queries to use materialized views even if not explicitly referenced
- Monitor staleness: `sys.dm_pdw_exec_requests` shows whether MV was used; `DBCC PDW_SHOWMATERIALIZEDVIEWOVERHEAD` shows overhead

## Resource Governance

### Dedicated SQL Pool Resource Management

Resources are allocated at the DWU level:

| DWU | Memory (GB) | Concurrency Slots | Max Concurrent Queries |
|---|---|---|---|
| DW100c | 60 | 4 | 4 |
| DW200c | 120 | 8 | 8 |
| DW500c | 300 | 20 | 20 |
| DW1000c | 600 | 32 | 32 |
| DW1500c | 900 | 32 | 32 |
| DW2000c | 1200 | 48 | 48 |
| DW3000c | 1800 | 64 | 64 |
| DW6000c | 3600 | 128 | 128 |
| DW30000c | 18000 | 128 | 128 |

Each query consumes concurrency slots based on its resource class or workload group assignment. When all slots are consumed, queries queue.

### Serverless SQL Pool Resource Limits

- No provisioning -- resources are automatically allocated per query
- Maximum data processed per query: 10 TB (soft limit, adjustable via support)
- Maximum concurrent queries: scales automatically
- Maximum result size: limited by output format and client
- Cost control: daily/weekly/monthly data processed limits via `sp_set_data_processed_limit`
