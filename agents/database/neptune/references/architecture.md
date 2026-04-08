# Amazon Neptune Architecture Reference

## Storage Architecture

### Storage Engine

Neptune uses a purpose-built, distributed, fault-tolerant storage engine shared with Amazon Aurora:

- **Log-structured storage:** Writes are appended to a distributed write-ahead log. The storage layer applies log records to data pages asynchronously.
- **6-way replication:** Every write is replicated to 6 copies across 3 Availability Zones (2 copies per AZ).
- **Quorum writes:** 4 of 6 copies must acknowledge a write before it is considered durable.
- **Quorum reads:** 3 of 6 copies are read for strongly consistent operations (the system uses the highest LSN).
- **10 GB segments:** Storage is divided into 10 GB segments called "protection groups." Each protection group is independently replicated.
- **Auto-scaling:** Storage grows automatically in 10 GB increments up to 128 TB. No pre-provisioning required.
- **Automatic repair:** If a storage node fails, Neptune automatically replaces it and re-replicates data from the remaining 5 copies. Repair is handled at the segment level, meaning only the affected 10 GB segments need re-replication (typically completes in minutes).

### Storage Separation from Compute

Neptune separates compute (query processing) from storage:

- **Shared storage volume:** The writer instance and all read replicas share the same underlying storage volume.
- **No data shipping between replicas:** Read replicas do not receive data from the writer. They read directly from the shared storage layer.
- **Log shipping for cache invalidation:** The writer ships redo log records to read replicas to invalidate stale pages in their buffer caches. This is much faster than shipping full data pages.
- **Replica lag:** Typically under 100 ms. Read replicas apply redo log records to their buffer caches, not to storage.

### Write Path

1. Client sends a write query (Gremlin addV, openCypher CREATE, SPARQL INSERT DATA) to the writer endpoint.
2. The query engine parses and optimizes the query, generating a set of mutations.
3. Mutations are translated into redo log records.
4. Redo log records are sent to the storage layer (6 copies across 3 AZs).
5. Storage layer acknowledges the write when 4 of 6 copies confirm (quorum write).
6. The query engine returns success to the client.
7. Storage nodes asynchronously apply the redo log records to data pages.
8. Redo log records are shipped to read replicas for cache invalidation.

### Read Path

1. Client sends a read query to the reader endpoint (or writer endpoint).
2. The query engine checks the buffer cache for relevant pages.
3. On a cache miss, the storage layer is queried. It applies any outstanding redo log records to the requested page before returning it (ensuring read-after-write consistency on the writer instance).
4. The query engine processes the page, performs any additional index lookups, and returns results.

## Compute Architecture

### Instance Types

Neptune offers several instance families optimized for different workloads:

| Family | Characteristics | Use Case |
|---|---|---|
| **db.r5** | Memory-optimized, Intel Xeon | General-purpose graph workloads |
| **db.r6g** | Memory-optimized, Graviton2 (ARM) | ~20% better price-performance over r5 |
| **db.r6i** | Memory-optimized, 3rd gen Intel Xeon | High memory bandwidth workloads |
| **db.x2g** | Extra-large memory, Graviton2 | Very large graphs that benefit from maximum buffer cache |
| **db.x2iedn** | Extreme memory (up to 4 TB RAM) | Largest possible in-memory graph caching |
| **db.serverless** | Auto-scaling NCU-based | Variable workloads, dev/test |
| **db.t3/t4g** | Burstable | Development, testing (not for production) |

### Buffer Pool (Buffer Cache)

The buffer pool is the primary in-memory cache on each Neptune instance:

- Caches frequently accessed graph data pages and index pages
- Size is approximately 75% of the instance's total memory
- Uses LRU eviction when the cache is full
- **Warm cache** delivers significantly better query latency than cold cache
- After failover or restart, the cache is cold and must be rebuilt through queries
- **Buffer cache hit ratio** available as a CloudWatch metric (`BufferCacheHitRatio`) -- target > 99%
- For large graphs, use larger instances (x2g, x2iedn) to maximize the buffer cache

### Query Processing

**Gremlin query engine:**
- Bytecode-based execution (TinkerPop bytecode format)
- String-based Gremlin (Groovy script) also supported but bytecode is preferred for security and performance
- Query optimizer converts traversals into internal execution plans
- Supports `explain` (static plan) and `profile` (executed plan with runtime stats)

**openCypher query engine:**
- Neptune's native openCypher implementation (not a Gremlin translation layer)
- Query planner generates optimized execution plans
- Supports `EXPLAIN` for query plan inspection
- Pattern matching compiled into efficient index lookups and traversal operations

**SPARQL query engine:**
- W3C SPARQL 1.1 compliant
- Triple pattern matching with join ordering optimization
- Supports `explain` via query parameter for plan inspection
- BGP (Basic Graph Pattern) optimizer chooses join order based on cardinality estimates

### Index Structure

Neptune maintains multiple indexes for efficient graph queries:

**Property graph indexes (Gremlin / openCypher):**

Neptune automatically maintains three primary indexes for property graph data:

1. **SPOG index** (Subject-Predicate-Object-Graph) -- Primary lookup by vertex/edge ID and property
2. **POGS index** (Predicate-Object-Graph-Subject) -- Lookup by property value (e.g., `has('name', 'Alice')`)
3. **GPSO index** (Graph-Predicate-Subject-Object) -- Supports graph-scoped queries

These indexes are maintained automatically. You do not create or manage indexes manually in Neptune (unlike Neo4j or relational databases). Every property is automatically indexed.

**Additional property graph lookup patterns:**
- Vertex by ID: Direct SPOG index lookup -- O(1)
- Edge by ID: Direct SPOG index lookup -- O(1)
- Vertices by label: POGS index on the `label` predicate -- efficient
- Vertices by property value: POGS index on the property name -- efficient
- Edges out of a vertex: SPOG index scan for the vertex ID with edge predicates
- Edges into a vertex: Requires OSGP index access pattern (reverse lookup)

**RDF indexes (SPARQL):**

Neptune maintains three statement indexes for RDF triples:

1. **SPOG** -- Subject, Predicate, Object, Graph
2. **POGS** -- Predicate, Object, Graph, Subject
3. **GPSO** -- Graph, Predicate, Subject, Object

These cover the most common SPARQL access patterns. An optional fourth index (OSGP) can be enabled for queries that look up triples by object value:

- Enable via parameter group: `neptune_enable_osgp_index = 1` (disabled by default to save storage)
- Required for efficient reverse lookups: `SELECT ?s WHERE { ?s ?p <specific-object> }`
- Increases storage by approximately 20-25%

### Transaction Model

**Isolation level:** Read-committed (for reads), serializable (for writes within a transaction).

**Writer instance:**
- Single writer instance handles all mutations
- Transactions are ACID compliant
- Writes are serialized through a single-threaded write pipeline for conflict resolution
- Read queries on the writer instance see the latest committed data

**Read replicas:**
- Eventually consistent with the writer (typically < 100 ms lag)
- Read queries see a consistent snapshot as of the time the query starts
- No stale-read anomalies within a single query (snapshot isolation for reads)

**Gremlin transactions:**
- Auto-commit by default (each query is its own transaction)
- Explicit transactions via WebSocket sessions: `g.tx().commit()` / `g.tx().rollback()`
- Multiple statements within a session share the same transaction context

**openCypher transactions:**
- Each HTTP request is an auto-commit transaction
- Bolt protocol supports explicit transactions (`BEGIN`, `COMMIT`, `ROLLBACK`)

**SPARQL transactions:**
- Each HTTP request is auto-committed
- Multiple SPARQL UPDATE statements in a single request execute in a single transaction

### Cluster Topology

**Writer instance:**
- Handles all write operations
- Also serves read queries (but directing reads to replicas is recommended)
- Automatic failover: if the writer fails, a read replica is promoted (typically 30-120 seconds)

**Read replicas (up to 15):**
- Handle read queries
- Share the same storage volume as the writer
- Each replica can be a different instance size
- **Failover priority:** Each replica has a promotion priority tier (0-15). On writer failure, the replica with the lowest tier number (highest priority) is promoted. Within the same tier, the largest instance is preferred.

**Endpoints:**
- **Cluster endpoint:** Points to the current writer instance. Use for writes.
- **Reader endpoint:** Load-balances across available read replicas. Use for reads.
- **Instance endpoints:** Direct connection to a specific instance. Use for pinning specific queries to specific replicas.

### Neptune Analytics Architecture

Neptune Analytics is architecturally distinct from Neptune Database:

- **Serverless compute:** No instances to manage. You specify a memory size (in GB).
- **In-memory graph:** The entire graph is loaded into memory for fast analytical processing.
- **Provisioned graph memory:** You choose the memory size when creating a graph. The graph must fit in memory.
- **Data loading:** Load from Neptune Database snapshots, S3 (CSV, Parquet), or via openCypher queries.
- **Query engine:** Optimized for analytical workloads (full graph scans, algorithm execution, vector search).
- **Algorithm library:** Built-in graph algorithms executed as openCypher procedure calls (CALL neptune.algo.*).
- **Vector search:** Store and query vector embeddings alongside graph data. Supports KNN queries.
- **No SPARQL support:** Neptune Analytics only supports openCypher (not Gremlin or SPARQL).
- **No write transactions:** Neptune Analytics graphs are primarily read-optimized. You can add/modify data via openCypher mutations, but the engine is optimized for analytical reads.

### Neptune ML Architecture

Neptune ML integrates graph neural networks into Neptune queries:

**Training pipeline:**
1. **Data export:** `neptune-export` utility exports graph data from Neptune to S3 in CSV format
2. **Data processing:** SageMaker Processing job converts graph CSVs into DGL (Deep Graph Library) training data
3. **Model training:** SageMaker Training job trains a GNN model
   - Supports R-GCN (Relational Graph Convolutional Network) for heterogeneous graphs
   - Supports GraphSAGE for homogeneous graphs
   - Custom model architectures supported via user-provided training scripts
4. **Model deployment:** Trained model deployed to SageMaker endpoint
5. **Inference integration:** Neptune query engine routes ML predicates to the SageMaker endpoint

**GNN model details:**
- Node features automatically inferred from properties (numerical, categorical, text)
- Text features encoded via word2vec or sentence transformers
- Training uses mini-batch gradient descent with neighbor sampling
- Inductive learning supported (predictions on new nodes without retraining)

### High Availability and Disaster Recovery

**Multi-AZ HA (default):**
- Storage replicated across 3 AZs (6 copies)
- Writer + replicas can span multiple AZs
- Automatic failover to a replica in a different AZ if the writer's AZ fails

**Automated backups:**
- Continuous, incremental backups to S3 (retention: 1-35 days)
- Backup does not impact performance (backed by the storage layer's continuous snapshots)
- Point-in-time restore (PITR) to any second within the retention window

**Manual snapshots:**
- User-initiated, kept until explicitly deleted
- Can be shared across accounts or copied to other regions
- Used for Neptune Analytics data loading

**Cross-region replication:**
- Neptune Global Database: up to 5 secondary regions
- Storage-level replication (not logical replication)
- Typical replication lag: < 1 second
- Promotes a secondary region to writer in under 1 minute during regional failover
- Secondary regions serve low-latency reads locally

### Network Architecture

Neptune clusters are deployed exclusively within a VPC:

- **Subnet group:** Spans at least 2 AZs (recommended 3)
- **Security groups:** Control inbound/outbound traffic to Neptune instances on port 8182
- **No public IP:** Neptune instances do not have public endpoints
- **Access patterns:**
  - EC2 instances in the same VPC (most common)
  - Lambda functions in the VPC (requires NAT gateway for internet access)
  - VPC peering from other VPCs
  - AWS Transit Gateway for multi-VPC architectures
  - AWS PrivateLink (interface VPC endpoints) for cross-account access
  - SSH tunneling or Client VPN for developer access
  - API Gateway + Lambda as a public-facing proxy

### Engine Versioning

Neptune uses engine versions (e.g., 1.2.1.0, 1.3.0.0):

- **Major.Minor versions:** Introduce new features and capabilities
- **Patch versions:** Bug fixes and security patches
- **Auto-minor version upgrade:** Can be enabled for automatic patching during maintenance windows
- **Blue/green deployments:** Supported for major version upgrades with zero downtime
- **Parameter groups:** Configuration parameters grouped by engine version family (neptune1.2, neptune1.3)

### Performance Characteristics

**Latency profiles (typical):**

| Operation | Latency |
|---|---|
| Single vertex lookup by ID | < 5 ms |
| Single-hop traversal (small fan-out) | 5-20 ms |
| 2-3 hop traversal | 20-100 ms |
| Complex traversal (5+ hops) | 100 ms - seconds |
| Bulk load (1M edges) | Minutes |
| Full graph scan (millions of vertices) | Seconds to minutes |
| Neptune Analytics algorithm (PageRank on 1B edges) | Seconds to minutes |

**Throughput:**
- Scales with instance size and number of read replicas
- Writer handles thousands of write operations per second (dependent on instance size and query complexity)
- Each read replica adds proportional read throughput
- Gremlin WebSocket connections maintained via connection pooling (recommended pool size: 8-64 per client)

### Comparison: Neptune Database vs. Neptune Analytics

| Dimension | Neptune Database | Neptune Analytics |
|---|---|---|
| Compute model | Instance-based or serverless (NCU) | Serverless (provisioned memory) |
| Storage | Distributed, auto-scaling to 128 TB | In-memory |
| Query languages | Gremlin, openCypher, SPARQL | openCypher only |
| Algorithms | None built-in (use Gremlin traversals) | PageRank, Louvain, shortest path, etc. |
| Vector search | No | Yes (KNN) |
| Transactions | Full ACID | Limited (read-optimized) |
| Use case | OLTP graph queries | OLAP graph analytics |
| Data loading | Bulk loader, live queries | S3, Neptune snapshots, openCypher |
| Availability | Multi-AZ, 15 replicas, Global Database | Single-region |
| Pricing | Per instance-hour + storage + I/O | Per provisioned-memory-hour |
