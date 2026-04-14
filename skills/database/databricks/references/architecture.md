# Databricks Architecture Reference

## Platform Architecture Overview

Databricks runs a two-plane architecture across all three major cloud providers (AWS, Azure, GCP):

### Control Plane (Managed by Databricks)

The control plane is hosted in Databricks' own cloud account and manages:

- **Workspace UI and API endpoints:** The web application, REST APIs, and Databricks CLI communicate with the control plane
- **Job scheduler and orchestrator:** Manages Workflows job scheduling, task dependencies, and retry logic
- **Cluster manager:** Provisions and deprovisions cloud VMs in the customer's cloud account via cloud provider APIs
- **Unity Catalog metadata store:** Stores all catalog, schema, table, view, function, model, and volume metadata centrally
- **Notebook service:** Stores and executes notebook code; manages revision history and collaboration
- **Authentication and authorization:** Manages users, groups, service principals, PATs, OAuth tokens, and SCIM integration
- **Secrets manager:** Encrypts and stores secrets scoped to workspaces or service principals

### Data Plane (Customer's Cloud Account)

The data plane runs in the customer's own cloud subscription/account:

- **Compute resources:** VMs (EC2/Azure VMs/GCE) running Spark clusters, SQL warehouses, or serverless containers
- **Cloud object storage:** S3 buckets, ADLS Gen2 containers, or GCS buckets holding all data files (Delta tables, raw data, checkpoints)
- **Network infrastructure:** VPCs/VNets configured by the customer with optional private endpoints, NSGs, and firewall rules
- **DBFS (Databricks File System):** A FUSE-mounted abstraction over cloud storage; legacy -- Unity Catalog volumes are the recommended replacement

**Serverless data plane (managed by Databricks):** For serverless compute (SQL warehouses, serverless jobs, model serving), Databricks manages the data plane infrastructure in its own account. Data is accessed via secure network connectivity to the customer's storage.

### Network Security

- **Classic deployment:** Databricks creates and manages a VPC/VNet in the customer's account for compute. The control plane communicates with the data plane over a secure channel.
- **Customer-managed VPC/VNet:** Customer provides a pre-configured VPC/VNet; Databricks deploys compute into specific subnets. Enables private link, no public IPs, custom DNS, and peering with corporate networks.
- **Private Link (AWS) / Private Endpoints (Azure):** Secure the control plane <-> data plane communication over private network paths, eliminating public internet traffic.
- **IP access lists:** Restrict which IP ranges can access the workspace UI and API.

## Delta Lake Internals

### Transaction Log (_delta_log/)

The Delta transaction log is the single source of truth for the state of a Delta table. It lives in the `_delta_log/` subdirectory of the table's root directory in object storage.

**Log structure:**
```
table_root/
  _delta_log/
    00000000000000000000.json    # First commit
    00000000000000000001.json    # Second commit
    ...
    00000000000000000010.checkpoint.parquet  # Checkpoint at version 10
    00000000000000000020.checkpoint.parquet  # Checkpoint at version 20
    _last_checkpoint                         # Points to latest checkpoint
  part-00000-{uuid}.snappy.parquet          # Data files
  part-00001-{uuid}.snappy.parquet
  ...
```

**Commit files (.json):** Each commit is an atomic JSON file containing one or more actions:
- `add`: A new data file is added to the table
- `remove`: A data file is logically removed (physical removal deferred to VACUUM)
- `metaData`: Table schema, partition columns, configuration changes
- `protocol`: Minimum reader/writer protocol version required
- `txn`: Application-level transaction identifier (for idempotent writes from streaming)
- `commitInfo`: Audit information (timestamp, operation, user, notebook, cluster)
- `domainMetadata`: Domain-specific metadata extensions (used by Liquid Clustering, UniForm, etc.)

**Checkpoint files (.checkpoint.parquet):** Every 10 commits (configurable), a checkpoint file is written that contains the aggregate state of the table (all active `add` actions, current metadata, current protocol). This enables fast state reconstruction without replaying the entire log.

**Log replay algorithm:**
1. Read `_last_checkpoint` to find the latest checkpoint version
2. Read the checkpoint Parquet file to get the base table state
3. Read all JSON commit files after the checkpoint
4. Apply each commit's actions sequentially to build the current state
5. The resulting set of `add` actions (minus any `remove` actions) is the current set of active data files

### Optimistic Concurrency Control

Delta Lake uses optimistic concurrency for writes:

1. A writer reads the current table state (latest version N)
2. The writer computes its changes (new files to add, files to remove)
3. The writer attempts to atomically commit version N+1 by writing a new JSON file
4. **Conflict resolution:** If another writer committed N+1 first, the current writer checks if the two commits conflict:
   - **No conflict:** If the commits touched disjoint sets of files/partitions, the writer rebases to version N+2 and retries
   - **Conflict:** If both writers modified overlapping data, one writer fails with a `ConcurrentModificationException`
5. Cloud object storage atomicity (S3 conditional PutObject, ADLS atomic rename, GCS generations) ensures only one writer succeeds for each version number

**Conflict detection rules:**
| Operation A | Operation B | Conflict? |
|---|---|---|
| Append | Append | No -- different files |
| Append | OPTIMIZE | No -- OPTIMIZE only compacts existing files |
| OPTIMIZE | OPTIMIZE | Yes -- both try to rewrite the same files |
| DELETE (condition P) | DELETE (condition Q) | Only if P and Q overlap files |
| UPDATE | UPDATE | Only if they touch the same files |
| MERGE | MERGE | Only if they affect overlapping rows/files |
| Schema change | Any write | Yes |

### Data-Skipping and File Statistics

Delta Lake maintains per-file statistics to enable data-skipping:

- For each data file, the transaction log stores min/max values for the first 32 columns (configurable via `delta.dataSkippingNumIndexedCols`)
- When a query has predicates on indexed columns, Delta Lake skips files whose min/max ranges do not intersect the predicate
- Data-skipping is most effective when:
  - Data is sorted or clustered by the filtered column (Liquid Clustering, Z-ORDER)
  - Column has high cardinality with natural ordering (timestamps, IDs)
- String columns: statistics only track the first 32 characters by default (`delta.dataSkippingStatsColumns`)

### Deletion Vectors

Deletion vectors represent a lightweight mechanism for marking rows as deleted without rewriting data files:

- A bitmap per data file identifies which row positions are deleted
- Stored in separate small files alongside the data files
- During reads, the engine merges data files with their deletion vectors to filter out deleted rows
- DELETE, UPDATE, and MERGE operations can use deletion vectors instead of copy-on-write
- Dramatically reduces write amplification for targeted deletes/updates on large tables
- Enabled by default on new tables (requires reader/writer protocol v3)
- Merge-on-read strategy: slightly slower reads (must check DV bitmap), but much faster writes

### Liquid Clustering Internals

Liquid Clustering replaces both Hive-style partitioning and Z-ORDER with an adaptive, incremental approach:

**How it works:**
1. Data is organized using space-filling curves (Hilbert curves) based on the specified clustering columns
2. Each file tracks its own clustering "quality" -- how well its data matches the target clustering
3. OPTIMIZE evaluates each file's clustering quality and only rewrites files below a threshold
4. New data ingested may be unclustered; subsequent OPTIMIZE incrementally clusters it
5. No fixed partition boundaries -- clustering adapts to actual data distributions

**Advantages over Hive partitioning:**
- No small-file problem from over-partitioning (e.g., partitioning by date + hour + region creates thousands of tiny partitions)
- Clustering columns can be changed with `ALTER TABLE ... CLUSTER BY` without rewriting all data
- Multi-dimensional clustering is native (Hilbert curves), not hacked via Z-ORDER
- Incremental OPTIMIZE avoids rewriting already-well-clustered files

**Advantages over Z-ORDER:**
- Incremental: only rewrites files that need re-clustering
- Can change clustering columns without full rewrite
- Better suited for tables with continuous data ingestion

### UniForm (Universal Format)

UniForm enables Delta tables to be simultaneously readable as Apache Iceberg or Apache Hudi tables:

**How it works:**
- When enabled, each Delta commit also generates the corresponding Iceberg metadata (metadata JSON, manifest lists, manifest files, Avro-based)
- The underlying Parquet data files are shared -- no data duplication
- External Iceberg clients (Spark, Trino, Presto, Snowflake, BigQuery) read the Iceberg metadata to access the same data
- The Delta transaction log remains the source of truth; Iceberg metadata is a read-only projection

**Supported formats:**
- Delta -> Iceberg: Generally available
- Delta -> Hudi: Public preview

**Requirements:**
- Requires Delta reader version 3 and writer version 7
- Deletion vectors must be enabled
- Column mapping must be enabled

## Photon Engine Architecture

Photon is a native vectorized execution engine written in C++ that replaces the Spark JVM query execution layer:

### Execution Model

- **Vectorized processing:** Operates on columnar batches (typically 1024-4096 rows per batch) rather than row-at-a-time. This enables SIMD instructions and cache-efficient processing.
- **Native C++ execution:** Avoids JVM overhead (no garbage collection pauses, no JIT compilation warmup, direct memory management)
- **Whole-stage code generation:** Generates optimized native code for each query's pipeline stages
- **Fallback mechanism:** Operations not supported by Photon (e.g., UDFs, certain complex expressions) automatically fall back to the Spark JVM engine within the same query

### Photon-Optimized Operations

| Operation | Photon Benefit |
|---|---|
| Table scans (Parquet/Delta) | Vectorized Parquet decoding, SIMD filtering |
| Aggregations (SUM, COUNT, AVG, MIN, MAX) | Columnar batch aggregation |
| Hash joins | Native hash table implementation |
| Sort merge joins | Vectorized merge |
| String operations | Native UTF-8 processing, no JVM string overhead |
| Data writing (Delta) | Vectorized Parquet encoding |
| Shuffle | Native serialization, reduced GC |
| Expressions and filters | Compiled native evaluation |

### When Photon Falls Back to Spark

- Python/Scala/Java UDFs (only SQL/built-in functions are Photon-accelerated)
- Complex data types in certain operations (deeply nested structs/arrays)
- Non-Delta/Parquet data sources
- Some window functions with complex frames
- Operations that require custom JVM extensions

## Spark Execution Model

### Job -> Stage -> Task Hierarchy

1. **Job:** Triggered by an action (e.g., `count()`, `collect()`, `write`). One action = one Spark job.
2. **Stage:** A job is divided into stages at shuffle boundaries. Within a stage, all transformations are pipelined (no data movement).
3. **Task:** The unit of parallel execution. One task processes one partition of data. Tasks within a stage run in parallel across executors.

### Memory Management

Spark uses unified memory management per executor:

- **Execution memory:** Used for shuffles, joins, sorts, aggregations. Acquired dynamically.
- **Storage memory:** Used for cached RDDs/DataFrames. Can be evicted if execution needs memory.
- **User memory:** Used by UDFs, custom data structures.
- **Reserved memory:** ~300 MB reserved for Spark internals.

Key configuration:
```
spark.executor.memory        = Total JVM heap per executor (e.g., 16g)
spark.memory.fraction        = 0.6 (fraction of heap for execution + storage)
spark.memory.storageFraction = 0.5 (initial fraction of the 0.6 reserved for storage; execution can borrow)
spark.executor.memoryOverhead = Off-heap memory (containers, PySpark, native libs)
```

### Shuffle Architecture

Shuffles redistribute data across partitions -- they are the most expensive operation in Spark:

- **Map side:** Each task writes shuffle data to local disk, partitioned by the target partition key
- **Reduce side:** Each reduce task fetches its partition from all map tasks via the shuffle service
- **External shuffle service:** A per-node service that serves shuffle data even after executors are deallocated (critical for dynamic allocation and spot instances)

**Shuffle tuning:**
```
spark.sql.shuffle.partitions    = 200 (default, often too low for large datasets)
spark.sql.adaptive.enabled      = true (AQE dynamically coalesces shuffle partitions)
spark.sql.adaptive.coalescePartitions.enabled = true
spark.sql.adaptive.skewJoin.enabled = true (splits skewed partitions)
```

### Adaptive Query Execution (AQE)

AQE re-optimizes the query plan at runtime based on actual data statistics collected during shuffle:

1. **Coalesce shuffle partitions:** Merges small shuffle partitions to reduce task overhead and improve parallelism
2. **Convert sort-merge join to broadcast hash join:** If one side of a join is smaller than expected (after filtering), AQE switches to broadcast join
3. **Optimize skew join:** Detects partitions much larger than the median and splits them into sub-partitions that are joined separately
4. **Dynamic partition pruning:** Prunes partitions at runtime based on join key values from the other side of the join

AQE is enabled by default in Databricks Runtime.

## Unity Catalog Architecture

### Metadata Layer

Unity Catalog stores all metadata in a centralized, Databricks-managed metastore:

- **Account-level:** One metastore per cloud region per Databricks account
- **Metadata stored:** Catalog names, schema names, table definitions (columns, types, constraints), view definitions, function definitions, model metadata, volume paths, permissions (grants), lineage edges, tags, and comments
- **External locations:** Mappings from Unity Catalog objects to cloud storage paths (S3, ADLS, GCS) with associated storage credentials
- **Storage credentials:** References to cloud IAM roles (AWS), service principals (Azure), or service accounts (GCP) that Unity Catalog uses to access cloud storage

### Access Control Model

Unity Catalog uses a hierarchical permission model with inheritance:

```
Metastore (account-level admin)
  └── Catalog (USAGE, CREATE SCHEMA, ALL PRIVILEGES)
        └── Schema (USAGE, CREATE TABLE/VIEW/FUNCTION/MODEL/VOLUME, ALL PRIVILEGES)
              └── Object (SELECT, MODIFY, REFRESH, ALL PRIVILEGES)
```

**Permission resolution:**
- To access a table, a principal needs `USAGE` on the catalog, `USAGE` on the schema, and `SELECT` (or `MODIFY`) on the table
- `USAGE` does not cascade -- it only grants the right to traverse that level. It does not grant read access to objects within.
- `ALL PRIVILEGES` grants all current and future privileges at that level
- Ownership: the creator of an object is its owner. Ownership grants full control and can be transferred.

### Lineage Tracking

Unity Catalog automatically captures column-level lineage:

- When a notebook, job, or SQL query reads from table A and writes to table B, Unity Catalog records the lineage edge: A -> B
- Lineage is captured at the column level (which columns in A flow to which columns in B)
- Lineage is captured for: notebooks, Workflows jobs, DLT pipelines, SQL queries in Databricks SQL
- Lineage data is stored in `system.access.table_lineage` and `system.access.column_lineage`

### System Tables

Unity Catalog provides system tables for observability and governance:

| System Table | Purpose |
|---|---|
| `system.billing.usage` | DBU consumption by workspace, SKU, cluster, user |
| `system.billing.list_prices` | Public list prices for all DBU SKUs |
| `system.access.audit` | Audit log of all actions (workspace, Unity Catalog, account level) |
| `system.access.table_lineage` | Table-level lineage edges |
| `system.access.column_lineage` | Column-level lineage edges |
| `system.compute.clusters` | Cluster metadata (configuration, creator, state transitions) |
| `system.compute.node_types` | Available VM types and their specs |
| `system.compute.warehouse_events` | SQL warehouse scaling events |
| `system.storage.predictive_optimization_operations_history` | Predictive optimization run history |
| `system.lakeflow.job_run_timeline` | Job and task run history and metrics |
| `system.lakeflow.pipeline_event_log` | DLT pipeline events |
| `system.information_schema.*` | Standard SQL information_schema tables |
| `system.query.history` | Query execution history and performance |

## Workflows Architecture

### Job Execution Model

1. **Job definition:** A JSON/YAML configuration specifying tasks, dependencies, compute, schedule, and parameters
2. **Scheduler:** The control plane scheduler triggers runs based on cron expressions, file arrival triggers, or continuous triggers
3. **Task orchestration:** Tasks execute in dependency order (DAG). Parallel tasks run concurrently.
4. **Compute provisioning:** Each task references a compute target:
   - **Job cluster:** Ephemeral cluster created at task start, terminated at task end. Cheapest per-DBU rate.
   - **Shared job cluster:** One cluster shared by multiple tasks in the job. Reduces startup overhead.
   - **Existing all-purpose cluster:** Runs on an already-running interactive cluster. No startup wait. Highest DBU rate.
   - **Serverless:** Databricks-managed infrastructure, sub-second startup.
5. **Task result propagation:** Tasks can pass output values to downstream tasks via task values (`dbutils.jobs.taskValues`)

### Delta Live Tables Pipeline Architecture

DLT pipelines run as managed Spark clusters with additional framework features:

- **Declaration:** Users declare tables and views as Python functions or SQL queries; DLT resolves the DAG
- **Materialized views:** DLT computes and incrementally maintains materialized views. Full refresh on schema change or user request.
- **Streaming tables:** Tables that process data incrementally using Structured Streaming checkpoints
- **Expectations (data quality):** Declarative quality constraints on every record:
  - `expect`: Log violations but keep all records
  - `expect_or_drop`: Drop records that violate the constraint
  - `expect_or_fail`: Fail the pipeline if any record violates
- **Enhanced autoscaling:** DLT's autoscaler is streaming-aware -- it scales based on backlog rather than CPU, avoiding oscillation
- **Maintenance:** DLT automatically runs OPTIMIZE and VACUUM on managed tables

## Structured Streaming Internals

### Micro-Batch vs Continuous Processing

Databricks Structured Streaming uses a micro-batch model by default:

1. Each trigger interval, the engine checks for new data from sources (Kafka, Delta, Auto Loader, files)
2. New data is processed as a micro-batch using Spark SQL execution (full query optimization, Photon, etc.)
3. Output is written atomically to the sink (Delta table, Kafka, etc.)
4. Checkpoint records the source offsets and sink commit state for exactly-once semantics

**Trigger modes:**
| Trigger | Behavior |
|---|---|
| `trigger(processingTime='10 seconds')` | Process new data every 10 seconds |
| `trigger(availableNow=True)` | Process all available data, then stop (ideal for incremental batch) |
| `trigger(once=True)` | Process one micro-batch, then stop (legacy; use availableNow instead) |
| Default (no trigger) | Process as fast as possible (next batch starts immediately after current) |

### Auto Loader (cloudFiles)

Auto Loader incrementally ingests new files from cloud storage:

- Uses file notification (SQS/EventGrid/Pub-Sub) or directory listing to discover new files
- Schema inference and evolution: automatically detects schema from data; evolves schema as new columns appear
- Exactly-once file tracking via RocksDB-based checkpoint state store
- Handles millions of files efficiently through file notification mode

```python
(spark.readStream
  .format("cloudFiles")
  .option("cloudFiles.format", "json")
  .option("cloudFiles.schemaLocation", "/checkpoints/schema/events")
  .option("cloudFiles.inferColumnTypes", "true")
  .load("/data/raw/events/")
  .writeStream
  .option("checkpointLocation", "/checkpoints/events")
  .trigger(availableNow=True)
  .toTable("my_catalog.my_schema.raw_events"))
```

### Checkpointing

Every streaming query maintains a checkpoint directory with:

- **Offsets:** The source offsets for each micro-batch (e.g., Kafka partition offsets, file paths processed)
- **Commits:** Records which micro-batches have been committed to the sink
- **State:** For stateful operations (aggregations, deduplication, windowed joins), the operator state is stored in a state store (RocksDB by default in Databricks)
- **Metadata:** Query ID, run ID, and configuration

**Critical rule:** Never delete or modify checkpoint directories while a query is running. To restart from scratch, delete both the checkpoint and the output table.

## Security Architecture

### Authentication Methods

| Method | Use Case |
|---|---|
| OAuth (U2M) | Interactive user access via browser SSO |
| OAuth (M2M) | Service principals for automation (client_id + client_secret) |
| Personal Access Tokens (PATs) | Legacy; being replaced by OAuth M2M |
| SCIM provisioning | Sync users and groups from IdP (Okta, Azure AD, etc.) |
| Azure Managed Identity | Azure-native workload identity |
| Instance profiles (AWS) | EC2 instance-based access to S3 |

### Encryption

- **At rest:** All data in cloud storage is encrypted using cloud-native encryption (SSE-S3, Azure Storage encryption, GCS default encryption). Customer-managed keys (CMK/CMEK) supported for control plane storage and managed DBFS.
- **In transit:** TLS 1.2+ for all control plane <-> data plane and client communications
- **Double encryption:** Available on Azure with infrastructure encryption layer

### Network Isolation

- **VPC peering / VNet peering:** Connect Databricks VPC to corporate networks
- **Private Link / Private Endpoints:** Remove public internet exposure for both workspace UI and backend connectivity
- **No public IP (NPIP):** Cluster nodes use only private IPs; all egress goes through NAT or private endpoints
- **Unity Catalog network policies:** Restrict which networks can access specific catalogs or shares
