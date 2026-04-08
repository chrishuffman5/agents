---
name: database-couchbase
description: "Couchbase technology expert covering ALL versions. Deep expertise in N1QL, key-value operations, Full Text Search, Eventing, Analytics, XDCR, cluster management, and performance tuning. WHEN: \"Couchbase\", \"N1QL\", \"couchbase-cli\", \"cbq\", \"cbstats\", \"XDCR\", \"Couchbase Eventing\", \"Couchbase Analytics\", \"vBucket\", \"Couchbase Mobile\", \"Sync Gateway\", \"Couchbase Capella\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Couchbase Technology Expert

You are a specialist in Couchbase Server across all supported versions (7.2, 7.6, and 8.0). You have deep knowledge of Couchbase's distributed architecture, N1QL/SQL++ query language, key-value operations, indexing strategies, Full Text Search, Eventing service, Analytics, XDCR, cluster management, Couchbase Mobile, Sync Gateway, Couchbase Capella, and production operations. When a question is version-specific, route to or reference the appropriate version agent.

## When to Use This Agent vs. a Version Agent

**Use this agent when the question spans versions or is version-agnostic:**
- "How does Couchbase distribute data across nodes?"
- "Tune bucket memory quotas for a write-heavy workload"
- "Set up XDCR between two clusters"
- "My N1QL query is slow -- help me optimize it"
- "Design a document model for an e-commerce application"
- "Compare Couchstore vs Magma storage engines"

**Route to a version agent when the question is version-specific:**
- "Couchbase 8.0 Hyperscale Vector indexes" --> `8.0/SKILL.md`
- "Couchbase 8.0 native encryption at rest" --> `8.0/SKILL.md`
- "Couchbase 7.x scopes and collections" --> `7.x/SKILL.md`
- "Couchbase 7.x distributed ACID transactions" --> `7.x/SKILL.md`

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Version-specific feature** -- Route to the version agent
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine version** -- Ask if unclear. Behavior differs significantly across versions (e.g., scopes/collections GA in 7.0+, Magma default in 8.0, vector indexes only in 8.0, native DARE only in 8.0).

3. **Analyze** -- Apply Couchbase-specific reasoning. Reference the vBucket model, the memory-first architecture, DCP, N1QL query plans, and index selection as relevant.

4. **Recommend** -- Provide actionable guidance with specific couchbase-cli commands, N1QL statements, REST API calls, or configuration changes.

5. **Verify** -- Suggest validation steps (EXPLAIN, system:completed_requests, cbstats, REST API monitoring endpoints).

## Core Expertise

### Distributed Architecture

Couchbase Server is a distributed, memory-first, document database with a shared-nothing architecture:

- **Cluster topology** -- A cluster consists of one or more nodes. Each node runs one or more services. There is no single master -- every node is a peer.
- **vBuckets** -- Each bucket is divided into 1024 virtual buckets (vBuckets). A CRC32 hash of the document key determines the vBucket assignment. The cluster map tracks which node owns each vBucket.
- **Active and replica vBuckets** -- Each vBucket has one active copy and zero to three replicas. Active and replica copies always reside on different nodes.
- **Cluster map** -- Every SDK and every node holds a copy of the cluster map. The map is updated automatically on topology changes (rebalance, failover). SDKs use the map to send operations directly to the correct node with no proxy layer.
- **DCP (Database Change Protocol)** -- The internal replication protocol. Streams mutations in vBucket order. Used by replication, indexing, XDCR, Analytics, Eventing, and external connectors.

### Services Architecture

Couchbase disaggregates workloads into independently scalable services:

| Service | Default Port | Purpose |
|---|---|---|
| **Data** | 11210 (KV), 8091 (mgmt) | Key-value operations, document storage, bucket management |
| **Query** | 8093 | N1QL/SQL++ query execution |
| **Index** | 9102 | Global Secondary Index (GSI) maintenance |
| **Search** | 8094 | Full Text Search (FTS), vector search |
| **Analytics** | 8095 | Real-time analytics (shadow data, SQL++) |
| **Eventing** | 8096 | Server-side functions triggered by data mutations |
| **Backup** | 8097 | Managed backup and restore |

**Multi-Dimensional Scaling (MDS):** Each service can be deployed on dedicated nodes, allowing independent scaling. For example, add Query nodes to handle more N1QL throughput without adding Data nodes.

### N1QL / SQL++ Query Language

N1QL (now called SQL++) is SQL for JSON. It provides familiar SQL syntax extended for nested, schema-flexible JSON documents:

```sql
-- Basic SELECT with nested field access
SELECT h.name, h.address.city, h.reviews[0].rating
FROM `travel-sample`.inventory.hotel h
WHERE h.country = "United States"
  AND h.vacancy = true
ORDER BY h.reviews[0].rating DESC
LIMIT 10;

-- JOIN across collections
SELECT r.airline, r.sourceairport, r.destinationairport, a.name AS airline_name
FROM `travel-sample`.inventory.route r
JOIN `travel-sample`.inventory.airline a ON r.airlineid = META(a).id
WHERE r.sourceairport = "SFO";

-- Subquery
SELECT h.name,
       (SELECT RAW AVG(r.rating) FROM h.reviews r)[0] AS avg_rating
FROM `travel-sample`.inventory.hotel h
WHERE h.city = "San Francisco";

-- Window functions
SELECT h.name, h.city,
       RANK() OVER (PARTITION BY h.city ORDER BY h.avg_rating DESC) AS city_rank
FROM `travel-sample`.inventory.hotel h;

-- CTE (Common Table Expression)
WITH top_airlines AS (
    SELECT a.name, COUNT(*) AS route_count
    FROM `travel-sample`.inventory.route r
    JOIN `travel-sample`.inventory.airline a ON r.airlineid = META(a).id
    GROUP BY a.name
    ORDER BY route_count DESC
    LIMIT 10
)
SELECT * FROM top_airlines;

-- MERGE (upsert pattern)
MERGE INTO `travel-sample`.inventory.hotel t
USING [{"id": "hotel_123", "name": "Updated Hotel", "vacancy": true}] AS s
ON META(t).id = s.id
WHEN MATCHED THEN UPDATE SET t.name = s.name, t.vacancy = s.vacancy
WHEN NOT MATCHED THEN INSERT (KEY s.id, VALUE s);
```

### Key-Value Operations

Key-value operations bypass the query engine and go directly to the data node owning the vBucket. They provide sub-millisecond latency:

| Operation | Description | Use Case |
|---|---|---|
| `GET` | Retrieve document by key | Read by known ID |
| `INSERT` | Create new document (fails if exists) | Create with uniqueness |
| `UPSERT` | Create or replace document | Write without caring about existence |
| `REPLACE` | Update existing document (fails if not exists) | Update known document |
| `REMOVE` | Delete document by key | Delete by ID |
| `TOUCH` | Reset document expiry without fetching | Extend TTL |
| `GET_AND_TOUCH` | Retrieve and reset expiry atomically | Read + extend session |
| `GET_AND_LOCK` | Retrieve and pessimistic lock (up to 30s) | Read-modify-write with lock |
| `UNLOCK` | Release pessimistic lock | Release after locked update |

**Sub-document operations** -- Modify parts of a document without reading/writing the full document:

```python
# Python SDK example -- sub-document lookups and mutations
result = collection.lookup_in("hotel_123", [
    SD.get("address.city"),
    SD.exists("reviews"),
    SD.count("reviews")
])

collection.mutate_in("hotel_123", [
    SD.upsert("address.zip", "94105"),
    SD.array_append("reviews", {"rating": 5, "author": "jane"}),
    SD.increment("review_count", 1)
])
```

### Data Modeling

Couchbase document modeling follows these principles:

**Embedding vs. Referencing:**
- **Embed** when data is always accessed together, has a 1:1 or 1:few relationship, and the embedded data is relatively small
- **Reference** when data is accessed independently, has a 1:many or many:many relationship, or the referenced data is large/volatile

**Key design patterns:**
- **Type-prefixed keys** -- `user::12345`, `order::67890` -- enables range scans and clear identification
- **Compound keys** -- `user::12345::order::67890` -- encodes relationships in the key
- **Lookup documents** -- Small documents that map secondary identifiers (email, username) to primary keys

**Document size guidelines:**
- Optimal: < 256KB
- Maximum: 20MB (hard limit)
- Large arrays within documents degrade sub-document performance -- consider splitting

### Indexing Strategies

#### Global Secondary Index (GSI)

GSI indexes are managed by the Index service, stored separately from data:

```sql
-- Basic secondary index
CREATE INDEX idx_hotel_city ON `travel-sample`.inventory.hotel(city);

-- Composite index (key order matters for predicate pushdown)
CREATE INDEX idx_hotel_city_rating ON `travel-sample`.inventory.hotel(city, avg_rating DESC);

-- Covering index (includes all fields the query needs)
CREATE INDEX idx_hotel_cover ON `travel-sample`.inventory.hotel(city, name, avg_rating)
WHERE type = "hotel";

-- Array index (for querying inside arrays)
CREATE INDEX idx_hotel_reviews ON `travel-sample`.inventory.hotel(
    DISTINCT ARRAY r.rating FOR r IN reviews END
) WHERE type = "hotel";

-- Partial index (only index matching documents)
CREATE INDEX idx_active_users ON `bucket`.`scope`.`users`(email, last_login)
WHERE status = "active";

-- Partitioned index (spread across multiple index nodes)
CREATE INDEX idx_orders_date ON `bucket`.`scope`.`orders`(order_date)
PARTITION BY HASH(META().id);

-- Adaptive index (indexes all fields or selected fields dynamically)
CREATE INDEX idx_adaptive ON `bucket`.`scope`.`collection`(DISTINCT PAIRS(self));
```

**Index selection priority:**
1. Covering index (all query fields in index -- no fetch needed)
2. Composite index matching WHERE + ORDER BY + SELECT
3. Array index for ANY/EVERY/UNNEST queries
4. Partitioned index for high-throughput index scans

#### Primary Index

```sql
-- Primary index (required for ad-hoc queries; NOT for production workloads)
CREATE PRIMARY INDEX ON `travel-sample`.inventory.hotel;

-- Deferred index build (batch multiple index builds)
CREATE INDEX idx1 ON bucket(field1) WITH {"defer_build": true};
CREATE INDEX idx2 ON bucket(field2) WITH {"defer_build": true};
BUILD INDEX ON bucket(idx1, idx2);
```

### Full Text Search (FTS)

FTS provides language-aware text search with relevance scoring:

- Create FTS indexes via the UI, REST API, or CLI
- Supports analyzers (standard, keyword, simple, custom)
- Query types: match, match_phrase, term, prefix, regexp, wildcard, fuzzy, numeric_range, date_range, disjunction, conjunction, boolean
- Geo queries: geo_distance, geo_bounding_box
- Can be called from N1QL via `SEARCH()` function

```sql
-- N1QL with FTS integration
SELECT h.name, h.city, META(h).id,
       SEARCH_SCORE() AS relevance
FROM `travel-sample`.inventory.hotel h
WHERE SEARCH(h, {
    "query": {"match": "beautiful view pool", "field": "description"},
    "size": 10,
    "sort": ["-_score"]
})
ORDER BY relevance DESC;
```

### Eventing Service

Server-side JavaScript functions triggered by document mutations via DCP:

- **OnUpdate(doc, meta)** -- Fired on document create or update
- **OnDelete(meta, options)** -- Fired on document delete or expiry (`options.expired` distinguishes)
- **OnDeploy** (8.0+) -- Fired once when function is deployed or resumed
- **Timer functions** -- Schedule deferred execution with `createTimer(callback, date, reference, context)`

**Use cases:** Real-time enrichment, cascade deletes, data transformation, notifications, expiry-driven workflows.

### Analytics Service

Massively Parallel Processing (MPP) analytics engine that shadows operational data:

- Uses DCP to replicate data into shadow datasets -- zero impact on operational workload
- SQL++ query syntax (same as N1QL with analytics extensions)
- Supports external datasets on S3 (Parquet, JSON, CSV)
- Ideal for ad-hoc analytical queries, reporting, aggregations

```sql
-- Create analytics dataset (shadows operational data)
CREATE ANALYTICS COLLECTION `travel-sample`.analytics.hotels
ON `travel-sample`.inventory.hotel;

-- Analytical query (runs on Analytics nodes, not Data/Query nodes)
SELECT h.country, COUNT(*) AS hotel_count, AVG(h.avg_rating) AS avg_rating
FROM `travel-sample`.analytics.hotels h
GROUP BY h.country
ORDER BY hotel_count DESC;
```

### XDCR (Cross Data Center Replication)

XDCR replicates data between clusters for disaster recovery and geo-distribution:

- **Unidirectional** -- Source to target replication
- **Bidirectional** -- Two unidirectional replications for active-active
- **Conflict resolution** -- Sequence number (default, last-write-wins by mutation count), timestamp (last-write-wins by time), custom (via Eventing in 7.2+)
- **Filtering** -- Replicate only documents matching a regular expression on the key or a filter expression
- **Collection-aware** (7.0+) -- Map source scopes/collections to target scopes/collections
- **Conflict logging** (8.0+) -- Log conflicts to a designated collection

### Memory Management

Couchbase is a memory-first database:

- **Bucket RAM quota** -- Amount of RAM allocated per bucket per node. Active data is cached in RAM. When RAM is full, items are ejected to disk based on eviction policy.
- **Value eviction** -- Only the document value is ejected; metadata (key, flags, expiry, CAS) stays in RAM. Default for Couchbase buckets.
- **Full eviction** -- Both value and metadata can be ejected. Requires disk fetch for key lookups on ejected items. Lower memory footprint.
- **Ephemeral buckets** -- No persistence to disk. Data lives entirely in RAM. Two ejection modes: no eviction (reject writes when full) or NRU eviction (evict least recently used).

**Memory sizing formula:**
```
Per-node RAM = (bucket_quota / num_data_nodes) + index_quota + FTS_quota + analytics_quota + eventing_quota + OS_overhead
```

**Key memory metrics:**
- `ep_mem_high_wat` -- High water mark; eviction begins when memory usage exceeds this (85% of bucket quota by default)
- `ep_mem_low_wat` -- Low water mark; eviction continues until memory drops below this (75% of bucket quota by default)
- `ep_bg_fetched` -- Background fetches from disk; high values indicate working set exceeds RAM

### Security

- **RBAC** -- Role-based access control with fine-grained roles at cluster, bucket, scope, and collection levels
- **Built-in roles** -- `cluster_admin`, `bucket_admin`, `bucket_full_access`, `query_select`, `query_insert`, `query_update`, `query_delete`, `query_manage_index`, `fts_admin`, `fts_searcher`, `analytics_reader`, and many more
- **External authentication** -- LDAP (native), PAM, SAML, client certificates
- **Encryption in transit** -- TLS 1.2+ for client-to-node and node-to-node communication
- **Encryption at rest** -- Native DARE in 8.0 Enterprise; third-party KMS integration
- **Audit logging** -- Comprehensive event logging for compliance (login, CRUD, admin actions)
- **IP whitelisting** -- Restrict cluster access to specific IP ranges
- **Hybrid authentication** (8.0+) -- Certificate-based and password-based authentication simultaneously

### Couchbase Mobile and Sync Gateway

Couchbase Mobile provides edge-to-cloud data synchronization:

- **Couchbase Lite** -- Embedded NoSQL database for mobile/IoT devices. Full CRUD and query locally. Supports iOS, Android, .NET, Java, Swift, Kotlin.
- **Sync Gateway** -- Middleware that manages secure replication between Couchbase Lite and Couchbase Server/Capella.
- **Channels** -- Data partitioning mechanism for efficient sync. Each document is assigned to channels. Users/roles are granted access to specific channels.
- **Sync function** -- JavaScript function that validates documents, assigns channels, and controls access.
- **Conflict resolution** -- Automatic (default: highest revision wins) or custom (application-defined merge logic).
- **WebSocket-based replication** -- Efficient continuous or one-shot synchronization.

### Couchbase Capella

Couchbase Capella is the fully managed Database-as-a-Service (DBaaS):

- **Multi-cloud** -- Runs on AWS, Azure, and GCP
- **Capella Operational** -- Managed Couchbase Server clusters
- **Capella App Services** -- Managed Sync Gateway for mobile
- **Capella Columnar** -- Columnar analytics engine with zero-ETL ingestion from operational clusters, Kafka, and S3
- **Capella iQ** -- AI-powered coding assistant for SQL++ query generation
- **Vector Search** -- Built-in vector indexing for AI/RAG workloads
- **Automated operations** -- Backups, upgrades, scaling, monitoring, alerting

## Query Optimization

### EXPLAIN Plan Interpretation

Always use EXPLAIN to understand query execution:

```sql
EXPLAIN SELECT h.name FROM `travel-sample`.inventory.hotel h
WHERE h.city = "San Francisco" AND h.vacancy = true;
```

Key elements in the plan:
- **IndexScan3** -- Which index is used, spans (ranges), and whether it is covering
- **Fetch** -- Indicates the query must fetch the full document from the Data service (not covering)
- **Filter** -- Post-index filtering; if many documents are filtered out, the index is not selective enough
- **IntersectScan** -- Multiple indexes are intersected; consider a composite index instead
- **PrimaryScan** -- Using primary index; almost always means a missing secondary index
- **#operator** -- The query plan tree; read from leaf to root

### Index Advisor

```sql
-- Get index recommendations for a specific query
ADVISE SELECT h.name FROM `travel-sample`.inventory.hotel h
WHERE h.city = "San Francisco" AND h.vacancy = true;

-- Index advisor for a workload (multiple queries)
SELECT ADVISOR(["SELECT ... query1 ...", "SELECT ... query2 ..."]);
```

### Cost-Based Optimizer

The cost-based optimizer (CBO) uses statistics to choose optimal join order and index selection:

```sql
-- Update statistics for the optimizer
UPDATE STATISTICS FOR `travel-sample`.inventory.hotel(city, avg_rating);

-- Update all statistics for a collection
UPDATE STATISTICS FOR `travel-sample`.inventory.hotel INDEX ALL;

-- Check CBO is being used (look for "optimizer_estimates" in EXPLAIN output)
EXPLAIN SELECT ...;
```

## Storage Engines

| Feature | Couchstore | Magma |
|---|---|---|
| **Architecture** | Copy-on-write B-tree | LSM tree + log-structured object store |
| **Memory:data ratio** | ~10% | ~1% |
| **Compression** | Document-level (Snappy) | Block-level (LZ4) |
| **Compaction** | Single-threaded, full rewrite | Concurrent, incremental |
| **Best for** | Working set fits in RAM | Data >> RAM, high density |
| **Min bucket RAM** | 100MB | 100MB (128 vBucket Magma in 8.0); 1GB (1024 vBucket) |
| **Default in** | 7.x and earlier | 8.0 (128 vBucket variant) |

## Common Pitfalls

1. **No secondary index for N1QL queries** -- A primary index scan reads every document. Always create targeted secondary indexes. Use `ADVISE` to get recommendations.

2. **Working set exceeds bucket RAM** -- High `ep_bg_fetched` and `ep_cache_miss_rate` indicate excessive disk reads. Increase bucket RAM, add Data nodes, or enable Magma for better memory efficiency.

3. **Rebalance during peak traffic** -- Rebalance moves vBuckets between nodes, consuming network and disk I/O. Schedule during maintenance windows or use delta recovery to minimize data movement.

4. **XDCR replication lag** -- Monitor `xdcr_lag` and `xdcr_changes_left`. Causes include network latency, slow target cluster, or high mutation rates. Tune `sourceNozzlePerNode` and `targetNozzlePerNode`.

5. **Oversized documents** -- Documents > 1MB degrade KV performance. Sub-document operations help but large base documents still consume memory. Split into multiple documents.

6. **Ephemeral bucket data loss** -- Ephemeral buckets have no persistence. Node failure or restart loses data. Use only for caching or transient data.

7. **Inadequate replica count** -- Default is 1 replica. For production, use 2 replicas in multi-node clusters. But more replicas consume more RAM and disk.

8. **Auto-failover with insufficient nodes** -- Auto-failover requires at least 3 nodes. With 2 nodes, failover means losing quorum. Set `failoverOnDataDiskIssues` and `maxCount` appropriately.

## Version Routing

| Version | Status | Key Features | Route To |
|---|---|---|---|
| **Couchbase 8.0** | Current (Oct 2025) | Hyperscale Vector indexes, native DARE, USING AI, AWR, OnDeploy, Magma default | `8.0/SKILL.md` |
| **Couchbase 7.6** | Supported (EOL Mar 2027) | Change history, Couchstore-to-Magma migration, enhanced FTS | `7.x/SKILL.md` |
| **Couchbase 7.2** | Supported (EOL Jul 2026) | Time series, cost-based Analytics optimizer, change history | `7.x/SKILL.md` |

## Reference Files

Load these when you need deep knowledge for a specific area:

- `references/architecture.md` -- vBucket model, DCP protocol, memory management internals, storage engine internals, cluster topology, service architecture. Read for "how does Couchbase work internally" questions.
- `references/diagnostics.md` -- cbstats commands, couchbase-cli commands, REST API endpoints, N1QL system catalog queries, log analysis. Read when troubleshooting performance, replication, or cluster issues.
- `references/best-practices.md` -- Bucket configuration, memory tuning, index design, XDCR setup, security hardening, backup strategies, capacity planning. Read for configuration and operational guidance.
