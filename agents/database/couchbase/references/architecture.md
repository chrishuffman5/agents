# Couchbase Architecture Reference

## Cluster Topology

Couchbase Server uses a shared-nothing, peer-to-peer architecture. There is no single master node. Every node in a cluster is functionally identical and can serve any client request.

### Node Roles

Each node runs one or more services. In production, Multi-Dimensional Scaling (MDS) dedicates nodes to specific services:

```
Cluster (example: 9 nodes)
├── Data nodes (3) -- KV storage, vBucket management
├── Query nodes (2) -- N1QL/SQL++ execution
├── Index nodes (2) -- GSI storage and scans
├── Search nodes (1) -- FTS and vector index
└── Analytics node (1) -- Shadow datasets, analytical queries
```

A single node can run all services (development mode), but production deployments should separate Data from Index and Query for isolation and independent scaling.

### Cluster Manager

The Cluster Manager runs on every node and handles:
- Node health monitoring via heartbeat
- Automatic failover detection (configurable timeout, default 120 seconds)
- Rebalance orchestration (vBucket migration)
- Configuration propagation across the cluster
- REST API (port 8091) for management operations

The Cluster Manager uses a consensus protocol to elect an orchestrator node that coordinates rebalance and failover. If the orchestrator fails, a new one is elected automatically.

## vBucket Architecture

### vBucket Mapping

Every bucket is divided into 1024 virtual buckets (vBuckets) in standard configuration, or 128 vBuckets for low-memory Magma buckets in 8.0. The document-to-vBucket mapping is deterministic:

```
vBucket_id = CRC32(document_key) mod num_vBuckets
```

The cluster map contains a vBucket map: an array of 1024 entries where each entry lists the node holding the active copy and the nodes holding replicas:

```json
{
  "vBucketMap": [
    [0, 1, 2],    // vBucket 0: active on node 0, replicas on nodes 1, 2
    [1, 2, 0],    // vBucket 1: active on node 1, replicas on nodes 2, 0
    [2, 0, 1],    // vBucket 2: active on node 2, replicas on nodes 0, 1
    ...
  ]
}
```

### Smart Client Architecture

SDKs are "smart clients" that maintain a local copy of the cluster map:

1. On bootstrap, SDK fetches the cluster map from any node
2. For each operation, SDK hashes the key to determine the vBucket
3. SDK looks up the active node in the vBucket map
4. SDK sends the operation directly to the correct node (no routing proxy)
5. If the cluster topology changes (rebalance, failover), the SDK receives a "not my vBucket" (NMV) error and refreshes the cluster map

This architecture provides single-hop access to any document, resulting in consistent sub-millisecond latency.

### vBucket States

| State | Description |
|---|---|
| **Active** | Serves reads and writes. One active per vBucket. |
| **Replica** | Receives DCP stream from active. Can be promoted to active on failover. |
| **Pending** | Transitional state during rebalance. |
| **Dead** | Marked for cleanup after rebalance completes. |

## Data Service Internals

### Memory Architecture (Per Bucket, Per Node)

```
Bucket Memory (per node)
├── Metadata overhead
│   ├── Key + metadata per item (~56-72 bytes per item for value eviction)
│   └── Hash table structure
├── Managed Cache
│   ├── Active items (document values in RAM)
│   └── Replica items (document values in RAM)
├── Checkpoint metadata (DCP cursors)
└── Replication buffers
```

### Write Path

1. **Client sends mutation** (SET/INSERT/REPLACE/DELETE) to the active vBucket node
2. **Managed cache update** -- Document is written to the hash table in RAM
3. **Replication queue** -- Mutation is placed on the DCP replication queue
4. **Disk queue** -- Mutation is placed on the disk persistence queue
5. **Acknowledgment** -- Client receives success once the configured durability level is met:
   - `none` -- ACK after RAM write (fastest, risk of data loss)
   - `majority` -- ACK after replication to majority of replicas
   - `majorityAndPersistActive` -- ACK after replication to majority AND persistence on active
   - `persistToMajority` -- ACK after persistence on active AND majority of replicas
6. **Persistence** -- Background flusher writes to storage engine (Couchstore or Magma)
7. **Replication** -- DCP streams the mutation to replica nodes

### Read Path

1. **Client sends GET** to the active vBucket node
2. **Cache lookup** -- Check managed cache hash table
   - **Cache hit** -- Return document immediately (sub-millisecond)
   - **Cache miss** -- Background fetch from disk (`ep_bg_fetched` increments)
3. **Disk fetch** -- Read from storage engine, load into cache, return to client

For full eviction buckets, even checking if a key exists may require a disk fetch.

### DCP (Database Change Protocol)

DCP is the internal streaming protocol for all data replication and change propagation:

```
Data mutations
    │
    ├──→ DCP → Intra-cluster replication (active → replica)
    ├──→ DCP → XDCR (cluster → remote cluster)
    ├──→ DCP → Index service (GSI index updates)
    ├──→ DCP → Search service (FTS index updates)
    ├──→ DCP → Analytics service (shadow dataset updates)
    ├──→ DCP → Eventing service (function triggers)
    └──→ DCP → External connectors (Kafka, Elasticsearch, Spark)
```

DCP properties:
- **Ordered per vBucket** -- Mutations within a single vBucket are delivered in sequence-number order
- **Resumable** -- Consumers track a checkpoint (sequence number per vBucket). On restart, they resume from the last checkpoint.
- **Backpressure** -- Slow consumers trigger backpressure, preventing memory exhaustion
- **No cross-vBucket ordering** -- Mutations in different vBuckets may arrive in any order

### Sequence Numbers and CAS

- **Sequence number** -- Monotonically increasing per-vBucket counter. Every mutation in a vBucket gets the next sequence number. Used by DCP, XDCR, and failover detection.
- **CAS (Compare-And-Swap)** -- Unique value assigned to each document version. Used for optimistic concurrency control:

```python
# Optimistic locking with CAS
result = collection.get("user::123")
cas = result.cas
# Modify document...
try:
    collection.replace("user::123", updated_doc, ReplaceOptions(cas=cas))
except CasMismatchException:
    # Another writer modified the document; retry
    pass
```

## Storage Engines

### Couchstore

Couchstore uses a Copy-on-Write (CoW) B+ tree:

- **Data file** -- Append-only file containing document bodies and B-tree nodes
- **Compaction** -- Reads the entire data file, writes a new file with only live data, then swaps. Single-threaded, requires temporary 2x disk space.
- **Document compression** -- Snappy compression per document
- **Memory:data ratio** -- Approximately 10% (metadata must fit in RAM)
- **Sequence index** -- B-tree mapping sequence numbers to document locations (for DCP)
- **ID index** -- B-tree mapping document keys to document locations

**Compaction trigger:** Automatic based on fragmentation percentage (default 30%) or scheduled via compaction settings.

### Magma

Magma is a high-data-density storage engine designed for datasets much larger than available RAM:

- **Architecture** -- LSM tree for key index + log-structured object store for document bodies
- **Key index** -- LSM tree stores key-to-seqno mappings. Compacted incrementally and concurrently.
- **Object store** -- Append-only segmented log stores document bodies. Segments are compacted independently.
- **Block compression** -- LZ4 compression at block level (more efficient than per-document)
- **Memory:data ratio** -- Approximately 1% (10x more efficient than Couchstore)
- **Compaction** -- Concurrent, incremental. Key index and object store compact independently. No 2x disk space requirement.
- **Write amplification** -- Lower than Couchstore for large datasets (3.2x less than RocksDB in benchmarks)

**When to choose Magma:**
- Data-to-RAM ratio > 10:1
- Dataset > 1TB per node
- Write-heavy workloads with large datasets
- Cost optimization (fewer nodes needed for same data volume)

**When to stay with Couchstore:**
- Working set fits in RAM
- Read-heavy workloads with high cache hit rate
- Minimal datasets (< 100GB per node)

### Storage File Layout (On Disk)

```
/opt/couchbase/var/lib/couchbase/data/
├── <bucket_name>/
│   ├── <vbucket_id>.couch.<rev>    # Couchstore: data + index file per vBucket
│   └── magma.<shard_id>/           # Magma: shared directory structure
│       ├── wal/                    # Write-ahead log
│       ├── keyIndex/               # LSM tree for key-to-seqno mapping
│       └── seqIndex/               # Sequence index for DCP
```

## Index Service Architecture

### Global Secondary Index (GSI)

GSI indexes are stored on Index service nodes, separate from data:

```
Data node (vBucket active)
    │
    ├──→ DCP stream ──→ Index node 1 (indexes A, B)
    └──→ DCP stream ──→ Index node 2 (indexes C, D)
```

- **Index storage** -- Indexes use a purpose-built storage engine (forestdb in older versions, plasma in 7.x+)
- **Plasma storage** -- LSM-based storage engine optimized for index workloads. Supports both standard and memory-optimized modes.
- **Memory-optimized indexes (MOI)** -- Indexes stored entirely in RAM using a skiplist. Fastest scan performance. No persistence (rebuilt on restart from DCP). Enterprise Edition only.
- **Standard indexes** -- Persisted to disk using Plasma. Can handle indexes larger than available RAM.

### Index Partitioning

Partitioned indexes distribute index data across multiple Index nodes:

```sql
CREATE INDEX idx_orders ON bucket(order_date, customer_id)
PARTITION BY HASH(META().id)
WITH {"num_partition": 8};
```

Benefits:
- Parallel index scans across partitions
- Larger index capacity (distributed across nodes)
- Better write throughput for index maintenance

### Index Replicas

```sql
CREATE INDEX idx_orders ON bucket(order_date) WITH {"num_replica": 1};
```

Index replicas provide:
- High availability (failover to replica if index node fails)
- Load balancing (query service distributes scans across replicas)

## Query Service Architecture

### Query Processing Pipeline

```
SQL++ query string
    │
    ├── 1. Parser ──→ AST (Abstract Syntax Tree)
    ├── 2. Planner/Optimizer ──→ Logical plan → Physical plan
    │       ├── Cost-based optimizer (if statistics available)
    │       └── Rule-based optimizer (fallback)
    ├── 3. Execution ──→ Operators execute the physical plan
    │       ├── IndexScan (requests to Index service)
    │       ├── Fetch (requests to Data service)
    │       ├── Join, Nest, Unnest
    │       ├── Filter, Project, Sort, Limit
    │       └── Group, Aggregate, Window
    └── 4. Results ──→ Streamed back to client
```

### Prepared Statements

Prepared statements cache the parsed and planned query:

```sql
-- Prepare a query
PREPARE hotel_by_city FROM
    SELECT name, city FROM `travel-sample`.inventory.hotel WHERE city = $city;

-- Execute the prepared statement
EXECUTE hotel_by_city USING {"city": "San Francisco"};
```

Benefits: Reduced parse/plan overhead on repeated queries. Auto-reprepare in 8.0 handles index changes automatically.

## Search Service Architecture

### FTS Index Structure

FTS uses an inverted index (based on the Bleve library):

- **Analyzer pipeline** -- Tokenizer → Token filters (lowercase, stop words, stemming) → Index
- **Index partitions** -- FTS indexes are partitioned across Search nodes for scalability
- **Pindex (partition index)** -- Each FTS index partition stored as a Bleve index
- **Index replicas** -- Configurable replica count for HA

### Vector Index Architecture (8.0+)

Three types of vector indexes:
- **Search Vector Index** -- Stored in FTS; supports hybrid text+vector queries
- **Hyperscale Vector Index (HVI)** -- Stored in Index service; optimized for billions of vectors
- **Composite Vector Index** -- Stored in Index service; vector column + scalar columns for filtered search

## Analytics Service Architecture

### Shadow Dataset Model

The Analytics service maintains its own copy of data, decoupled from the operational cluster:

```
Data Service ──→ DCP ──→ Analytics Service
                           ├── Shadow datasets (real-time copy)
                           ├── External datasets (S3, ADLS)
                           └── Standalone datasets (no DCP link)
```

- Zero impact on operational workload (Analytics has its own storage and compute)
- Near-real-time lag (DCP streaming delay, typically milliseconds)
- MPP execution engine for parallel analytical processing

## Eventing Service Architecture

### Function Execution Model

```
DCP mutation stream
    │
    ├──→ Eventing Service (vBucket owner)
    │       ├── OnUpdate handler (JavaScript V8 engine)
    │       ├── OnDelete handler
    │       └── Timer callbacks
    │
    └── Metadata bucket (stores checkpoints, timers, state)
```

- Functions are deployed across all Eventing nodes
- Each function is assigned a set of vBuckets for processing (partitioned like data)
- Mutations are deduplicated per checkpoint interval
- Timer state is persisted in the metadata bucket

## XDCR Architecture

### Replication Pipeline

```
Source cluster                              Target cluster
┌─────────────┐                            ┌─────────────┐
│ Data Service │──DCP──→ XDCR process      │ Data Service │
│ (vBuckets)   │        ├── Checkpoint mgr │ (vBuckets)   │
│              │        ├── Filter engine   │              │
│              │        ├── Conflict resolver│             │
│              │        └── Target nozzle ──→│              │
└─────────────┘                            └─────────────┘
```

- **Source nozzle** -- Reads mutations from DCP
- **Filter** -- Applies key regex or expression filter
- **Conflict resolution** -- For bidirectional XDCR, resolves conflicting mutations
- **Target nozzle** -- Writes mutations to target cluster
- **Checkpoint** -- Tracks replication progress per vBucket; enables resumption after failure

### Conflict Resolution Strategies

| Strategy | Mechanism | When to Use |
|---|---|---|
| **Sequence number** (default) | Highest revision wins (mutation count) | Most workloads; deterministic |
| **Timestamp** (LWW) | Latest timestamp wins | When wall-clock ordering matters |
| **Custom** (7.2+) | Eventing function resolves | Complex merge logic needed |

### XDCR Tuning Parameters

| Parameter | Description | Default |
|---|---|---|
| `sourceNozzlePerNode` | DCP connections per source node | 2 |
| `targetNozzlePerNode` | Connections per target node | 2 |
| `optimisticReplicationThreshold` | Doc size below which metadata check is skipped (bytes) | 256 |
| `checkpointInterval` | Seconds between checkpoint persistence | 600 |
| `statsInterval` | Seconds between stats collection | 1000 |
| `networkUsageLimit` | Bandwidth limit in MB/s (0 = unlimited) | 0 |
| `compressionType` | Compression for XDCR traffic (None, Snappy, Auto) | Auto |

## Cluster Operations

### Rebalance

Rebalance redistributes vBuckets across nodes after adding/removing nodes or changing service assignments:

1. Orchestrator calculates new vBucket map
2. VBuckets are streamed from source to target node
3. Backfill of existing data + DCP stream for ongoing mutations
4. Once a vBucket is fully transferred, ownership is switched atomically
5. Old vBucket copy is cleaned up

**Delta recovery** -- If a node was failed over and has its data intact, delta recovery only transfers the missing mutations instead of the full vBucket contents. Much faster than full recovery.

### Failover Types

| Type | Description | Data Impact |
|---|---|---|
| **Automatic** | Triggered by Cluster Manager when a node is unreachable for the configured timeout | Replicas promoted to active. Up to `maxCount` consecutive auto-failovers. |
| **Graceful** | Administrator-initiated; waits for vBuckets to be synchronized | Zero data loss. Requires healthy replicas. |
| **Hard** | Administrator-initiated; immediate promotion of replicas | Potential loss of mutations not yet replicated. |

### Node Recovery After Failover

| Recovery Type | Description |
|---|---|
| **Full recovery** | Node rejoins as new; all data is streamed from other nodes |
| **Delta recovery** | Only missing mutations are streamed; much faster if node data is intact |
