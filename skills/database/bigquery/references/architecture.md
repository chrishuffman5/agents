# BigQuery Architecture Deep Dive

## System Architecture Overview

BigQuery is a disaggregated architecture where compute and storage are fully separated and scale independently. This design is fundamentally different from traditional MPP databases where compute and storage are co-located on the same nodes.

```
                    +-------------------+
                    |   BigQuery API    |
                    |  (REST / gRPC)    |
                    +--------+----------+
                             |
                    +--------v----------+
                    |   Query Engine    |
                    |    (Dremel)       |
                    +--------+----------+
                             |
              +--------------+--------------+
              |              |              |
        +-----v----+  +-----v----+  +------v---+
        |  Root    |  | Shuffle  |  | Metadata |
        |  Server  |  |  Tier    |  |  Service |
        +-----+----+  +----------+  +----------+
              |
     +--------+--------+
     |        |         |
  +--v--+  +--v--+  +--v--+
  |Mixer|  |Mixer|  |Mixer|   (Intermediate aggregation)
  +--+--+  +--+--+  +--+--+
     |        |         |
  +--v--+  +--v--+  +--v--+
  |Slots|  |Slots|  |Slots|   (Leaf-level execution)
  +--+--+  +--+--+  +--+--+
     |        |         |
+----v--------v---------v----+
|      Colossus (Storage)    |
|   Capacitor columnar format|
+----------------------------+
```

## Dremel Execution Engine

### Query Processing Pipeline

1. **Parsing and Analysis:** SQL text is parsed into an abstract syntax tree (AST). ZetaSQL (BigQuery's SQL dialect) performs semantic analysis, type checking, and name resolution against the catalog.

2. **Query Planning:** The planner generates a logical query plan -- a DAG of relational operators (scan, filter, project, join, aggregate, sort, limit). It applies rule-based and cost-based optimizations:
   - Predicate pushdown (push filters as close to the scan as possible)
   - Partition and cluster pruning (eliminate partitions and storage blocks based on filter predicates)
   - Join reordering (arrange join order to minimize intermediate result sizes)
   - Subquery decorrelation (flatten correlated subqueries into joins)
   - Common subexpression elimination
   - Projection pruning (read only referenced columns)

3. **Physical Plan Generation:** The logical plan is translated into a distributed physical execution plan with stages. Each stage is a set of parallel tasks (slots) with a defined input and output schema. Stages communicate via the shuffle tier.

4. **Execution:** The plan is dispatched to the slot pool. Each slot executes its assigned stage fragment, reading from Colossus or from the shuffle tier, and writing outputs to the shuffle tier or to the final result.

5. **Result Assembly:** The root server collects final outputs and streams them to the client.

### Slot Architecture

A slot is a unit of computational capacity:

- Each slot has dedicated CPU, memory, and I/O bandwidth
- Slots are drawn from a shared multi-tenant pool (on-demand) or from reserved capacity (editions/reservations)
- A single query can consume anywhere from 1 to thousands of slots depending on data volume and query complexity
- Slots are allocated dynamically per-stage -- different stages of the same query may use different numbers of slots
- Within a stage, each slot processes a disjoint partition of the data (data-parallel execution)

**Slot scheduling:**
- On-demand: slots are drawn from a large shared pool; Google guarantees a baseline but actual availability depends on cluster load
- Reservations (editions): a dedicated pool of slots is allocated. Queries from assigned projects draw from this pool. Autoscaling can burst beyond baseline up to a configured maximum.
- Slot preemption: lower-priority workloads may have slots preempted by higher-priority workloads within the same reservation

**Slot types (per edition):**
| Edition | Slot Type | Use Case |
|---|---|---|
| Standard | Standard slots | General analytics, ETL |
| Enterprise | Enterprise slots | Governed analytics, BI Engine, security features |
| Enterprise Plus | Enterprise Plus slots | Mission-critical, cross-region replication, advanced security |

### Shuffle Tier

The shuffle tier is a petabit-scale network service that enables data exchange between stages:

- Distributed in-memory shuffle with spill-to-disk for large datasets
- Enables hash-based redistribution for JOINs and GROUP BYs
- Supports broadcast distribution for small-to-large joins (broadcast join)
- Persistent shuffle: intermediate results survive individual slot failures, enabling fault tolerance without restart
- The shuffle tier is the key enabler for BigQuery's ability to process multi-TB JOINs without user-managed temp storage

### Dynamic Query Execution

BigQuery uses dynamic execution techniques to adapt query plans at runtime:

- **Adaptive join selection:** The optimizer may switch between broadcast and hash-partitioned joins based on actual intermediate result sizes
- **Dynamic partition pruning:** Runtime filter propagation prunes partitions discovered during execution
- **Stage fusion:** Adjacent stages may be fused to eliminate unnecessary materialization to the shuffle tier
- **Speculative execution:** Slow-running slots may be re-executed speculatively on other machines

## Colossus Storage System

### Capacitor File Format

Capacitor is BigQuery's proprietary columnar file format:

- Each column is stored as a separate column stripe within a Capacitor file
- Columns are independently compressed using encoding schemes matched to the data type and distribution:
  - Run-length encoding (RLE) for low-cardinality columns
  - Dictionary encoding for medium-cardinality string columns
  - Delta encoding for sorted numeric columns
  - LZ4/Zstandard for general compression
- Each column stripe contains embedded statistics: min, max, null count, distinct count estimates
- Statistics enable storage-level predicate evaluation (block pruning) before data reaches the execution engine
- Nested and repeated fields (STRUCT, ARRAY) are stored using a Dremel encoding scheme (definition levels and repetition levels) that preserves the full nested structure in columnar form

### Storage Layout and Organization

- **Tables** are stored as collections of Capacitor files distributed across Colossus
- **Partitions** are physically separated storage segments -- each partition is a distinct set of Capacitor files
- **Clustering** controls the sort order within Capacitor files -- data is sorted by clustering columns so that blocks contain contiguous ranges of values
- BigQuery periodically performs background optimization: re-clustering data, merging small files, and re-encoding columns based on updated statistics
- **Metadata** (schema, partition information, statistics) is stored in a separate high-performance metadata service

### Storage Tiers

| Tier | Description | Pricing |
|---|---|---|
| Active | Modified in the last 90 days | Standard rate (~$0.02/GB/month) |
| Long-term | Not modified for 90+ days | ~50% discount (~$0.01/GB/month) |
| Time travel | Historical snapshots (2-7 days configurable) | Billed as active storage |
| Fail-safe | 7-day recovery after time travel expires | No additional charge but consumes storage |

### Time Travel and Snapshots

Time travel allows querying a table's state at any point in the past:

```sql
-- Query table as of 1 hour ago
SELECT * FROM project.dataset.my_table
FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);

-- Query table at a specific timestamp
SELECT * FROM project.dataset.my_table
FOR SYSTEM_TIME AS OF '2026-04-06 12:00:00 UTC';

-- Create a snapshot (table clone at a point in time)
CREATE SNAPSHOT TABLE project.dataset.my_table_snapshot
CLONE project.dataset.my_table
FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR);
```

**Table clones vs snapshots:**
- **Table clone:** A lightweight, writeable copy of a table. Initially shares storage with the base table (copy-on-write). Only divergent data consumes additional storage.
- **Table snapshot:** A read-only point-in-time copy. Cannot be modified. Used for backup/audit purposes.

## Reservation and Workload Management

### Reservation Hierarchy

```
Organization
  └── Admin Project (owns reservations)
       ├── Reservation: "analytics" (baseline: 200 slots, max: 500 slots)
       │    ├── Assignment: project-A (JOB_TYPE = QUERY)
       │    └── Assignment: project-B (JOB_TYPE = QUERY)
       ├── Reservation: "etl" (baseline: 100 slots, max: 300 slots)
       │    └── Assignment: project-C (JOB_TYPE = PIPELINE)
       └── Reservation: "ml" (baseline: 50 slots, max: 200 slots)
            └── Assignment: project-D (JOB_TYPE = ML_EXTERNAL)
```

### Capacity Commitments

Capacity commitments are the mechanism for purchasing slot capacity at discounted rates:

| Commitment | Renewal | Discount |
|---|---|---|
| Flex (seconds-level) | Per-second billing, no commitment | No discount (baseline rate) |
| Monthly | Auto-renews monthly, can cancel | Moderate discount |
| Annual (1-year) | 1-year commitment | Significant discount (~20-40%) |
| Three-year | 3-year commitment | Largest discount (~40-60%) |

Commitments are allocated to reservations. A reservation's baseline slots are served from commitments; autoscale slots beyond baseline are billed at the flex rate.

### Autoscaling

Autoscaling allows reservations to dynamically acquire additional slots when demand exceeds the baseline:

- **Baseline slots:** The minimum number of slots always available (can be 0)
- **Max slots (autoscale ceiling):** The maximum slots the reservation can scale to
- Autoscale slots are acquired on a best-effort basis from Google's shared pool
- Billed per-second at the flex rate for the edition tier
- Ideal pattern: set a low baseline for steady-state and allow autoscaling for peaks

### Workload Management

- **Job types:** `QUERY` (interactive SQL), `PIPELINE` (load, export, copy jobs), `ML_EXTERNAL` (BigQuery ML), `BACKGROUND` (materialized view refresh, search index maintenance)
- **Assignments:** Bind a project, folder, or organization to a reservation for a specific job type
- **Idle slot sharing:** If a reservation has unused slots, they can be shared with other reservations in the same admin project (configurable)
- **Concurrency targets:** Configure maximum concurrent query slots per reservation to balance throughput vs per-query performance

## Networking Architecture

### VPC Service Controls

VPC Service Controls create a security perimeter around BigQuery to prevent data exfiltration:

- Define a service perimeter that restricts which projects and APIs can interact
- Prevents copying data from BigQuery to an external project outside the perimeter
- Integrates with Access Context Manager for conditional access based on user identity, device state, and IP

### Private Google Access

- BigQuery can be accessed over private IP using Private Google Access or Private Service Connect
- No public IP exposure -- traffic stays on Google's network
- Configure DNS to resolve BigQuery endpoints to private IP ranges

### Cross-Region Data Movement

- BigQuery datasets are regional (single region) or multi-regional (US, EU)
- Cross-region queries are not directly supported -- data must be in the same region as the compute
- Cross-region dataset copies and BigQuery Data Transfer Service handle replication
- Enterprise Plus edition supports cross-region disaster recovery with automatic failover

## Integration Architecture

### BigQuery Storage Read API

The Storage Read API provides high-throughput, low-latency reads for data export and ETL:

- Parallel streams: client opens multiple read streams, each returning a disjoint subset of rows
- Columnar format: data is returned in Arrow or Avro format, preserving columnar efficiency
- Snapshot isolation: each read session reads from a consistent snapshot
- Used by Spark, Dataflow, Dataproc, and third-party tools for efficient BigQuery reads
- Much faster than `bq extract` for large datasets

### BigQuery Storage Write API

The Storage Write API is the high-performance ingestion path:

- Supports committed (exactly-once), buffered, pending, and default streams
- Protocol Buffers wire format for efficient serialization
- Connection multiplexing: multiple logical streams over a single gRPC connection
- CDC support: upsert and delete operations with primary key tables
- Schema updates: auto-detect schema changes during writes

### BigQuery Connection API

Connections enable BigQuery to access external services:

- **Cloud SQL connection:** Query Cloud SQL (MySQL, PostgreSQL, SQL Server) directly from BigQuery using EXTERNAL_QUERY()
- **Cloud Spanner connection:** Federated queries against Spanner
- **Cloud Storage connection:** BigLake tables and object tables
- **AWS/Azure connections (Omni):** Access S3 or Azure Blob Storage
- **Vertex AI connection:** Remote model inference (Gemini, custom models)

### Data Transfer Service

Automated, scheduled data movement into BigQuery:

- Source connectors: Google Ads, Google Analytics, YouTube, Amazon S3, Azure Blob Storage, Teradata, Amazon Redshift, and many more
- Scheduled queries: run SQL on a cron schedule with parameterized timestamps
- Cross-region dataset copies
- Managed backfill: historical data loading with automatic retry

## Metadata and Catalog Architecture

### INFORMATION_SCHEMA

BigQuery exposes extensive metadata through INFORMATION_SCHEMA views:

- **Dataset-level views:** TABLES, COLUMNS, TABLE_OPTIONS, PARTITIONS, TABLE_STORAGE, ROUTINES, etc.
- **Project-level views:** JOBS, JOBS_TIMELINE, STREAMING_TIMELINE, RESERVATIONS, CAPACITY_COMMITMENTS, ASSIGNMENTS
- **Organization-level views:** Cross-project job and reservation metadata
- INFORMATION_SCHEMA queries are free (do not consume on-demand bytes or slots)

### Data Catalog Integration

BigQuery integrates with Google Cloud Data Catalog for metadata management:

- Automatic registration of BigQuery datasets, tables, and views as Data Catalog entries
- Custom metadata via tags and tag templates
- Policy tags for column-level security and data masking
- Data lineage: track data flow from source through transformations to destination tables
- Business glossary for standardized terminology across the organization

## Security Architecture

### Encryption

- **Default encryption:** All data at rest is encrypted with Google-managed AES-256 keys
- **Customer-managed encryption keys (CMEK):** Use Cloud KMS keys for encryption. Available with Enterprise and Enterprise Plus.
- **Client-side encryption:** Encrypt data before sending to BigQuery (application responsibility)
- **In-transit encryption:** All API communication uses TLS 1.2+

### Identity and Access Management

BigQuery uses Google Cloud IAM for access control:

| Role | Scope | Permissions |
|---|---|---|
| `roles/bigquery.dataViewer` | Dataset or table | Read table data and metadata |
| `roles/bigquery.dataEditor` | Dataset or table | Read/write table data and metadata |
| `roles/bigquery.dataOwner` | Dataset | Full control over dataset and tables |
| `roles/bigquery.jobUser` | Project | Run queries and jobs |
| `roles/bigquery.user` | Project | Run queries, create datasets |
| `roles/bigquery.admin` | Project | Full BigQuery admin |
| `roles/bigquery.resourceViewer` | Project/org | View reservation and capacity metadata |

### Audit Logging

- **Admin Activity logs:** Always on. Records administrative operations (dataset creation, table deletion, IAM changes).
- **Data Access logs:** Configurable. Records data read/write operations (query execution, table data reads). Can generate high volume.
- **System Event logs:** BigQuery system events (automatic re-clustering, materialized view refresh).
- All logs flow to Cloud Logging and can be exported to BigQuery for analysis.

## Performance Architecture

### Query Performance Levers

From highest to lowest impact:

1. **Data model design:** Partitioning, clustering, denormalization, materialized views
2. **Query pattern:** Partition pruning, column selection, filter pushdown, avoiding SELECT *
3. **Slot capacity:** More slots = more parallelism. Relevant for editions/reservations.
4. **BI Engine:** Sub-second for cached, frequently-accessed data
5. **Search indexes:** For text search patterns that would otherwise require full scans
6. **Vector indexes:** For similarity search patterns

### Execution Plan Analysis

The execution plan (available in the BigQuery Console, `bq show -j`, or INFORMATION_SCHEMA.JOBS) reveals:

- **Stages:** Each stage is a parallel execution unit. Stages are connected by shuffle operations.
- **Records read/written:** Per-stage row counts. Large discrepancies between input and output suggest filtering effectiveness.
- **Shuffle bytes:** Data moved between stages. Large shuffle volumes indicate expensive joins or aggregations.
- **Slot time:** Total CPU time consumed by each stage. Identifies the most expensive stages.
- **Wait time vs compute time:** High wait time relative to compute time suggests slot contention or data skew.
- **Spill to disk:** Indicates the query exceeded available memory for a stage. Can significantly degrade performance.

### Data Skew

Data skew is the most common performance problem in BigQuery:

- Occurs when one slot processes disproportionately more data than others (in a JOIN, GROUP BY, or window function)
- Symptoms: one stage takes much longer than others, "slot time" is dominated by a single partition
- Common causes: join on a key with extreme value frequency (e.g., NULL, a single popular ID), GROUP BY on a low-cardinality column
- Solutions:
  - Filter out skewed keys before the join, process them separately
  - Use approximate aggregation functions
  - Add a salt column to distribute skewed keys across multiple partitions
  - Break the query into stages with temp tables
