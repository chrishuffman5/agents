# Azure Cosmos DB Architecture Reference

## Storage Engine: Atom-Record-Sequence (ARS)

All Cosmos DB APIs are built on the same underlying storage engine. Data is internally stored in an atom-record-sequence (ARS) format, which is a highly optimized columnar representation:

- **Atoms:** Primitive types (strings, numbers, booleans, nulls)
- **Records:** Ordered sequences of atoms (analogous to rows/documents)
- **Sequences:** Ordered sets of records or atoms

The ARS format enables Cosmos DB to project different data models (documents, graphs, column families, key-value pairs) from the same physical storage. Each API provides a domain-specific type system and query language that maps to ARS operations.

## Partition Architecture

### Logical Partitions

A logical partition is defined by the value of the partition key. All items with the same partition key value belong to the same logical partition:

- Maximum size: 20 GB per logical partition
- All items in a logical partition are stored together on the same physical partition
- Transactions (stored procedures, transactional batch) are scoped to a single logical partition
- A logical partition is the unit of consistency -- all five consistency levels are guaranteed within a logical partition

### Physical Partitions

A physical partition is the underlying unit of storage and compute:

- Each physical partition is a replica set of 4 replicas (1 leader + 3 followers)
- Maximum throughput per physical partition: ~10,000 RU/s
- Maximum storage per physical partition: 50 GB
- Physical partitions are entirely managed by the platform -- users cannot see or address them directly
- Each physical partition hosts one or more logical partitions
- Physical partition count = MAX(storage_GB / 50, provisioned_RU / 10000), rounded up

### Partition Splits

When a physical partition reaches its throughput or storage limit, Cosmos DB splits it:

- **Storage-based split:** Triggered when a physical partition approaches 50 GB. The partition is split into two, and logical partitions are redistributed.
- **Throughput-based split:** Triggered when provisioned RU/s exceeds what the current partition count can serve. Adding throughput causes new physical partitions to be created.

Split behavior:
- Splits are transparent to the application -- no downtime
- During a split, a brief increase in latency and 429 errors may occur
- After a split, throughput is redistributed evenly across the new partition set
- Splits are irreversible -- partitions do not merge automatically

### Partition Merges

Partition merge reduces the number of physical partitions when throughput is scaled down significantly. This reclaims compute resources and can lower costs:

- Merges are triggered when throughput is reduced to a level that can be served by fewer physical partitions
- Merges are automatic and transparent
- During a merge, brief latency increases may occur
- Merges allow you to scale down without permanent cost of split partitions

### Hierarchical Partition Keys

Hierarchical partition keys (subpartitioning) allow you to define up to three levels of partition key:

```
/tenantId/userId/sessionId
```

- The first level determines the physical partition assignment
- Sub-levels allow finer-grained distribution within a physical partition
- A logical partition is still defined by the full key path (all three levels combined)
- Enables efficient queries at any level of the hierarchy
- Particularly useful for multi-tenant scenarios where a single tenant might exceed the 20 GB logical partition limit

## Replication Protocol

### Multi-Paxos Consensus

Each physical partition is a replica set running a variant of the Multi-Paxos consensus protocol:

- **4 replicas per partition:** 1 leader (also called the write replica) + 3 followers
- The leader handles all write operations and coordinates replication
- Writes are acknowledged after a quorum of replicas (the leader + 1 follower) confirm the write to their persistent log
- This gives a write quorum of 2 out of 4, providing single-node fault tolerance for writes

### Write Path

1. Client sends a write request to the gateway (or directly to the partition in Direct mode)
2. The gateway routes the request to the leader replica of the target physical partition
3. The leader appends the write to its write-ahead log (WAL) and replicates to followers
4. The leader waits for a quorum acknowledgment (itself + at least 1 follower)
5. The leader applies the write to the index and storage engine
6. Acknowledgment is returned to the client

### Read Path

The read path varies by consistency level:

- **Strong:** Read from the leader or require a quorum read. The leader confirms it still holds the leadership lease before responding.
- **Bounded Staleness:** Read from any replica that is within the staleness window. In multi-region, reads go to local region only if within bounds; otherwise forwarded to write region.
- **Session:** Read from any replica that has replicated up to the session token provided by the client. The session token is a vector clock tracking per-partition progress.
- **Consistent Prefix:** Read from any replica. Guaranteed that writes are seen in order, but no staleness bound.
- **Eventual:** Read from any replica. Lowest latency, no ordering guarantee.

### Session Tokens

Session tokens are critical for Session consistency (the default):

- Each response includes an `x-ms-session-token` header
- The token is a compound value: `{partitionKeyRangeId}:{globalLSN}`
- The client SDK automatically tracks session tokens per partition key range
- When a request includes a session token, the target replica ensures it has replicated at least up to that LSN before responding
- If you pass requests across different client instances, you must manually propagate session tokens

## Clock Synchronization

Cosmos DB uses TrueTime-style hybrid logical clocks (HLC) for ordering events:

- Each replica maintains an HLC that combines physical time and a logical counter
- Physical time is synchronized across replicas and regions using NTP with tight bounds
- The HLC ensures causal ordering: if event A happens-before event B, HLC(A) < HLC(B)
- The `_ts` property on each document reflects the server-side timestamp of the last modification
- In multi-region writes, the HLC is used for conflict detection and last-writer-wins resolution

## RU Accounting Internals

A Request Unit (RU) is a normalized measure of the resources consumed by a database operation:

### What Contributes to RU Cost

| Factor | Impact |
|---|---|
| **Document size** | Larger documents cost more RUs (read + write) proportional to size |
| **Property count** | More properties to index increases write RU cost |
| **Index updates** | Each indexed property adds ~6 RUs per write for range index maintenance |
| **Query complexity** | JOINs, aggregations, UDFs, subqueries add CPU-based RU cost |
| **Partition fan-out** | Cross-partition queries multiply cost by number of partitions touched |
| **Consistency level** | Strong/Bounded Staleness reads cost 2x due to quorum reads |
| **Result set size** | Returning more data costs more RUs |
| **Index utilization** | Full scans cost far more than index seeks |

### RU Cost Benchmarks

| Operation | Approximate RU Cost |
|---|---|
| Point read (1 KB item, by id + partition key) | 1 RU |
| Point read (1 KB item, Strong consistency) | 2 RU |
| Point write / create (1 KB item) | ~5.3 RU |
| Point write / replace (1 KB item) | ~10.7 RU (reads old + writes new) |
| Delete (1 KB item) | ~5.8 RU |
| Query returning 1 item via index seek | ~2.9 RU |
| Query returning 10 items (1 KB each) | ~6-10 RU (single partition) |
| Cross-partition query (same query, 10 partitions) | ~60-100 RU |
| Stored procedure execution | Varies; base cost + per-operation cost inside procedure |
| Query with ORDER BY (no composite index) | Very high (full scan + in-memory sort) |
| Query with ORDER BY (composite index) | Low (index seek, streaming) |

### RU Budget Distribution

When throughput is provisioned at the container level:
- Total RU/s is divided equally across physical partitions
- If a container has 10,000 RU/s and 5 physical partitions, each partition gets 2,000 RU/s
- A hot partition consuming 3,000 RU/s will be throttled (429 errors) even though the container has 10,000 RU/s total
- This is why even distribution across partitions is critical

## Indexing Engine

### Inverted Index with Bw-Tree

Cosmos DB uses an inverted index backed by a Bw-tree (Buzzword tree, developed at Microsoft Research):

**Inverted index structure:**
- Each unique JSON path in the container gets an entry in the inverted index
- For a path like `/address/city`, the index maps each unique value to a list of document IDs
- This enables efficient equality and range queries on any indexed property

**Bw-tree properties:**
- Lock-free, latch-free B-tree variant designed for modern multi-core hardware
- Uses compare-and-swap (CAS) for atomic updates instead of latches
- Page splits and merges are performed using an indirection table (mapping table)
- Delta records are appended to pages, avoiding in-place updates
- Periodic consolidation compacts delta chains into base pages
- Optimized for SSD storage with log-structured write patterns

### Automatic Indexing

By default, every property in every document is indexed:
- The indexing engine traverses the JSON tree and creates index entries for every path
- New properties that appear in new documents are automatically indexed
- The index is updated synchronously with each write (consistent indexing mode)
- Lazy indexing mode (now deprecated) deferred index updates

### Index Types and Their Storage

| Index Type | Storage Format | Query Support |
|---|---|---|
| **Range** | Bw-tree with sorted values per path | =, <, >, <=, >=, BETWEEN, ORDER BY (single field), string functions |
| **Spatial** | R-tree for geospatial data | ST_DISTANCE, ST_WITHIN, ST_INTERSECTS, ST_ISVALID |
| **Composite** | Concatenated Bw-tree entries for multiple paths | Multi-field ORDER BY, multi-field filters with range predicates |
| **Vector** | Flat (brute-force), quantizedFlat (compressed), diskANN (approximate) | VectorDistance() similarity search |

### Index Transformation

When you modify the indexing policy, Cosmos DB performs an online index transformation:
- The transformation runs in the background using spare RU capacity
- Progress is tracked via the `x-ms-documentdb-collection-index-transformation-progress` response header (0-100%)
- During transformation, queries work correctly -- the old index serves existing paths, and new paths are scanned
- Transformation consumes RUs -- it may cause transient throttling on write-heavy containers

## Change Feed Internals

### How Change Feed Works

The change feed is built on top of the write-ahead log (WAL):

- Every write to a partition is assigned a logical sequence number (LSN)
- The change feed is a projection of the WAL, filtered to show only document-level changes
- Change feed is ordered per logical partition (changes within a partition are in commit order)
- There is no global ordering across partitions
- Change feed does NOT capture TTL-driven deletes in latest-version mode

### Lease Container

The change feed processor uses a lease container to coordinate work:
- Each lease corresponds to a physical partition key range
- Lease documents track the continuation token (LSN) per partition
- Multiple consumer instances compete for leases -- at most one instance processes each partition at a time
- If a consumer instance fails, another instance acquires the orphaned leases (after lease expiry)
- Lease acquisition uses optimistic concurrency with ETags

### Change Feed Processor Architecture

```
Container (source)
  ├── Partition 0 → Lease 0 → Consumer Instance A
  ├── Partition 1 → Lease 1 → Consumer Instance A
  ├── Partition 2 → Lease 2 → Consumer Instance B
  └── Partition 3 → Lease 3 → Consumer Instance B

Lease Container
  ├── Lease-0: { owner: "A", continuationToken: "LSN-1234", ... }
  ├── Lease-1: { owner: "A", continuationToken: "LSN-5678", ... }
  ├── Lease-2: { owner: "B", continuationToken: "LSN-9012", ... }
  └── Lease-3: { owner: "B", continuationToken: "LSN-3456", ... }
```

### All Versions and Deletes Mode

- Captures creates, updates (full current and previous images), and deletes (including TTL)
- Requires continuous backup to be enabled on the account
- Retention window matches the continuous backup retention period (7 or 30 days)
- Change items include metadata: `current`, `previous`, and `metadata.operationType` (create/replace/delete)
- Higher storage and RU overhead compared to latest-version mode

## Global Distribution Protocol

### Region Topology

- Each Cosmos DB account has one or more Azure regions
- Each region holds a complete replica of all data
- Within each region, data is replicated across fault domains and update domains for local resilience
- Cross-region replication is asynchronous (except for Strong consistency)

### Multi-Region Write Conflict Resolution

When multi-region writes are enabled:
- Any region can accept writes for any partition
- Conflicts are detected when the same item is modified in multiple regions concurrently
- **Last Writer Wins (LWW):** The write with the highest value on the conflict resolution path wins. Default path is `_ts` (timestamp). The losing write is placed in the conflict feed for inspection.
- **Custom conflict resolution:** A stored procedure is invoked to merge conflicts. If the procedure fails or is not registered, conflicts go to the conflict feed.
- **Conflict feed:** A special feed that contains losing writes from LWW resolution or unresolved conflicts. Applications can read the conflict feed to implement custom remediation.

### Failover Mechanisms

- **Automatic failover (single-region writes):** If the write region goes down, Cosmos DB automatically promotes a read region to be the new write region. Failover priority is user-configurable.
- **Manual failover:** User-initiated region switch for planned maintenance or testing. Zero-data-loss operation.
- **Service-managed failover:** Azure manages failover during prolonged regional outages.

### Multi-Region Consistency

With multiple read regions:
- **Strong consistency** is available only with single-region writes and forces reads to go to the write region (or uses quorum across regions). This adds latency proportional to the distance to the write region.
- **Bounded Staleness** in multi-region guarantees staleness bounds across regions. Reads may be served locally if within bounds.
- **Session, Consistent Prefix, Eventual** all allow local reads from the nearest region with their respective guarantees.

## Integrated Cache

The Cosmos DB integrated cache is an in-memory cache within the dedicated gateway:

- Caches both point reads and query results
- Cache invalidation based on the item's last modification time
- Reduces RU consumption for repeated reads of the same data
- Configurable staleness tolerance (MaxIntegratedCacheStaleness)
- Requires dedicated gateway deployment (separate SKU from standard gateway)
- Session consistency is supported; Strong consistency bypasses the cache

## Serverless Architecture

Serverless capacity mode has distinct internal behavior:

- No pre-provisioned throughput -- RUs are consumed on demand
- Maximum burst throughput: 5,000 RU/s (may vary -- check current limits)
- Single region only (no multi-region replication)
- Maximum storage: 1 TB per account
- Billed per RU consumed + per GB stored
- Partition splits still occur based on storage thresholds
- No SLA for availability (only best-effort)
- No dedicated gateway or integrated cache support
- No multi-region writes, continuous backup uses 7-day retention

## Throughput Provisioning Internals

### Autoscale

Autoscale dynamically adjusts throughput between 10% and 100% of the configured maximum:

- Scaling decisions are made per physical partition independently
- Scale-up is instant (within seconds)
- Scale-down occurs when consumption drops below the threshold for a period
- Billing is per-second at the highest RU/s reached in each second
- Minimum configurable max: 1,000 RU/s (so minimum actual: 100 RU/s)
- Autoscale throughput is distributed evenly across physical partitions, same as provisioned

### Database-Level Throughput (Shared Throughput)

When throughput is provisioned at the database level:
- All containers in the database share the pool of RU/s
- Each container gets a minimum of 100 RU/s (or a proportional minimum based on partition count)
- Containers with dedicated throughput within a shared-throughput database are excluded from the pool
- The system dynamically allocates RU/s to containers based on demand
- Maximum of 25 containers per shared-throughput database (higher with support request)
