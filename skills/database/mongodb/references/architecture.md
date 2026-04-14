# MongoDB Architecture Reference

## WiredTiger Storage Engine

WiredTiger has been the default storage engine since MongoDB 3.2. It provides document-level concurrency control, compression, and checkpoint-based durability.

### Storage Layout

```
dbpath/
├── mongod.lock                   # PID lock file
├── WiredTiger                    # WiredTiger version file
├── WiredTiger.lock               # WiredTiger lock file
├── WiredTiger.turtle             # Bootstrap metadata for WiredTiger.wt
├── WiredTiger.wt                 # WiredTiger metadata table
├── WiredTigerHS.wt               # History store (MVCC versions)
├── _mdb_catalog.wt               # MongoDB metadata catalog
├── sizeStorer.wt                 # Collection size tracking
├── storage.bson                  # Storage engine options
├── collection-0-*.wt             # Collection data files
├── index-1-*.wt                  # Index files (B-tree)
├── journal/
│   ├── WiredTigerLog.0000000001  # Journal files (WAL)
│   └── WiredTigerPreplog.*       # Prepared transaction logs
└── diagnostic.data/              # FTDC (Full-Time Diagnostic Data Capture)
    └── metrics.*                 # Binary metrics files
```

Each collection and each index is stored in a separate WiredTiger table (`.wt` file). This allows independent compression settings and efficient drop operations.

### B-tree Structure

WiredTiger uses a modified B-tree for both collection data and indexes:

- **Internal pages:** Contain keys and pointers to child pages. Sized by `internal_page_max` (default 4KB for collections, 16KB for indexes).
- **Leaf pages:** Contain the actual key-value pairs (documents for collections, key-pointer pairs for indexes). Sized by `leaf_page_max` (default 32KB for collections, 16KB for indexes).
- **Overflow pages:** For values exceeding `leaf_value_max` (default 64MB); large documents get their own overflow pages.
- **Page splits:** When a leaf page exceeds its maximum, it splits. Monotonic inserts use an optimized "fast append" path that avoids unnecessary splits.

### WiredTiger Cache (Internal Cache)

The internal cache is WiredTiger's primary buffer pool. It stores clean and dirty pages in an uncompressed, in-memory format that differs from the on-disk format.

**Sizing:**
```
Default: max(256MB, 50% * (totalRAM - 1GB))
```

Override with:
```yaml
# mongod.conf
storage:
  wiredTiger:
    engineConfig:
      cacheSizeGB: 8
```

**Cache pressure thresholds:**

| Metric | Default Threshold | Behavior |
|---|---|---|
| Total cache usage | 80% | Application threads begin evicting pages |
| Total cache usage | 95% | Aggressive eviction; operations may stall |
| Dirty data in cache | 5% | Background eviction of dirty pages starts |
| Dirty data in cache | 20% | Aggressive dirty eviction; write stalls possible |
| Updates percentage | 10% | Triggers eviction of pages with many updates |

**Eviction process:**
1. Background eviction threads (configurable via `eviction.threads_min` / `eviction.threads_max`) continuously scan for pages to evict
2. When cache pressure exceeds 80%, application threads participate in eviction (causing latency)
3. Eviction prefers clean pages (just discard) over dirty pages (must write first)
4. The history store absorbs old MVCC versions that are evicted from the cache

**Memory layout:**
```
Total server RAM
├── WiredTiger internal cache (cacheSizeGB)
│   ├── Clean pages (uncompressed data/index pages)
│   ├── Dirty pages (modified, not yet checkpointed)
│   └── Internal overhead (hash tables, page tracking)
├── WiredTiger allocations outside cache
│   ├── In-flight I/O buffers
│   ├── Open cursor state
│   └── Session-level allocations
├── MongoDB memory (connections, aggregation pipelines, sort buffers)
│   ├── Per-connection overhead (~1MB each)
│   ├── In-memory sort buffer (100MB limit per sort without allowDiskUse)
│   └── Aggregation pipeline stage memory (100MB limit per stage)
├── Operating system page cache (filesystem cache)
│   └── Compressed WiredTiger pages read from disk
└── OS and other processes
```

**Key insight:** MongoDB uses two layers of caching -- the WiredTiger internal cache (uncompressed) and the OS filesystem cache (compressed). Data read from disk passes through the OS cache first, then gets decompressed into the WiredTiger cache. This means the effective memory for data can be larger than just cacheSizeGB, but you must leave sufficient RAM for the filesystem cache.

### Compression

WiredTiger compresses data on disk. The CPU cost of decompression is usually far less than the I/O cost of reading uncompressed data.

| Target | Default | Options | Trade-off |
|---|---|---|---|
| Collection data | snappy | none, snappy, zlib, zstd | snappy: fast, ~2x; zlib/zstd: slower, ~3-5x |
| Index prefix | Prefix compression enabled | Enable/disable | Saves ~30% on indexes; minimal CPU cost |
| Journal | snappy | none, snappy, zlib, zstd | snappy is optimal for journal throughput |

Configure per collection:
```javascript
db.createCollection("logs", {
  storageEngine: {
    wiredTiger: {
      configString: "block_compressor=zstd"
    }
  }
})
```

### Journaling (Write-Ahead Log)

The journal provides crash recovery between checkpoints:

1. **Write path:** Client write -> WiredTiger cache (dirty page) -> Journal (WAL record) -> Acknowledge to client
2. **Journal sync:** Every 50ms (configurable via `storage.journal.commitIntervalMs`, range 1-500ms) or on `w: "majority"` commit
3. **Recovery:** On crash, WiredTiger replays journal entries since the last checkpoint to restore a consistent state

The journal uses a group commit model -- multiple concurrent writes are batched into a single journal flush for efficiency.

**Journal files:**
- Stored in `dbpath/journal/`
- Each file is ~100MB
- Files are rotated; old files are deleted after the data is included in a checkpoint
- With `journalCompressor: snappy` (default), journal writes are compressed

### Checkpoints

A checkpoint is a consistent, durable snapshot of all data:

1. WiredTiger creates a new checkpoint every **60 seconds** (default) or when the **journal reaches 2GB**
2. During a checkpoint, all dirty pages are written to their data files on disk
3. The checkpoint metadata records which pages are part of this consistent snapshot
4. After a successful checkpoint, the old journal entries are no longer needed

**Checkpoint I/O pattern:** Checkpoints cause a burst of write I/O every 60 seconds. On systems with slow storage, this can cause latency spikes. Solutions:
- Use faster storage (NVMe)
- Increase `checkpointDelaySecs` (available via wiredTigerEngineRuntimeConfig, but use with caution as it increases recovery time)
- Ensure sufficient I/O headroom

### History Store

The history store (HS, introduced in MongoDB 4.4 as a replacement for the lookaside table) stores old MVCC versions that are evicted from the internal cache:

- When a page has old transaction versions that are still needed by active snapshots but the page needs to be evicted, the old versions are written to the history store
- The history store is a WiredTiger table (`WiredTigerHS.wt`) on disk
- On reads that need old versions, WiredTiger checks the history store
- A large history store indicates long-running transactions or snapshots holding old versions

## Replication Protocol

### Oplog (Operations Log)

The oplog is a capped collection (`local.oplog.rs`) on each replica set member that records all data-modifying operations:

```javascript
// Example oplog entry
{
  ts: Timestamp(1678900000, 1),   // Operation timestamp (seconds, ordinal)
  t: NumberLong(5),                // Election term
  h: NumberLong(0),                // Deprecated (hash)
  v: 2,                            // Oplog version
  op: "i",                         // Operation type: i=insert, u=update, d=delete, c=command, n=noop
  ns: "mydb.users",                // Namespace
  ui: UUID("..."),                 // Collection UUID
  wall: ISODate("2025-03-15..."),  // Wall clock time
  o: {                             // Operation document
    _id: ObjectId("..."),
    name: "Alice",
    email: "alice@example.com"
  }
}
```

**Oplog sizing:**
- Default: 5% of free disk space (minimum 990MB, maximum 50GB on 64-bit systems)
- Override: `replication.oplogSizeMB` in config or `replSetResizeOplog` command at runtime
- **Critical:** The oplog must be large enough to hold enough operations for secondaries to catch up after maintenance, network issues, or initial sync. Size for at least 24-72 hours of writes.

**Oplog operations:**
- Inserts are recorded as `op: "i"` with the full document
- Updates are recorded as `op: "u"` with the update modifier (`$set`, `$inc`, etc.) -- idempotent
- Deletes are recorded as `op: "d"` with the `_id` of the deleted document
- Multi-document transactions are recorded as a single `applyOps` entry

### Replication Mechanism

1. **Initial sync:** A new secondary copies all data from a sync source (typically another secondary), then begins tailing the oplog
2. **Steady state:** Secondary continuously fetches oplog entries from the sync source in batches
3. **Batch application:** Oplog entries are applied in parallel (oplog applier threads) when safe to do so
4. **Heartbeats:** Every 2 seconds, members exchange heartbeat messages containing replication state

**Sync source selection (chaining):**
- By default, secondaries can replicate from other secondaries (chaining)
- `settings.chainingAllowed: false` forces all secondaries to replicate from the primary
- Chaining reduces load on the primary but can increase replication lag

### Elections

Elections use the Raft-inspired protocol (since MongoDB 3.6):

1. A member detects the primary is unreachable (no heartbeat for `electionTimeoutMillis`, default 10s)
2. The detecting member increments its election term and requests votes from other members
3. Members vote for the candidate if:
   - The candidate's oplog is at least as up-to-date as the voter's
   - The voter has not already voted in this term
   - The candidate has the highest priority among eligible candidates
4. If the candidate receives votes from a majority of voting members, it becomes primary
5. The new primary begins accepting writes

**Election triggers:**
- Primary step-down (`rs.stepDown()`)
- Primary becomes unreachable (network partition, crash)
- Priority change (`rs.reconfig()`)
- Maintenance (`replSetMaintenance`)

**Election timing:**
- Detection: up to `electionTimeoutMillis` (default 10s)
- Election: typically 1-2 seconds after detection
- Total failover time: 12-15 seconds typical with defaults
- During election, no primary exists and writes fail

### Write Concern and Read Concern Internals

**Write concern `w: "majority"` flow:**
1. Client sends write to primary
2. Primary applies write to its oplog and data
3. Primary waits for secondaries to replicate the oplog entry
4. When a majority of voting members have the entry, primary acknowledges the client
5. The `wtimeout` parameter sets a maximum wait time (default: no timeout)

**Read concern `"majority"` flow:**
1. Each member tracks the "majority commit point" -- the most recent oplog entry replicated to a majority
2. A `readConcern: "majority"` read returns data that is at or before this commit point
3. WiredTiger maintains a snapshot at the majority commit point

**Read concern `"linearizable"` flow:**
1. Reads from the primary only
2. Before returning, the primary confirms it is still the leader by communicating with a majority of members
3. Guarantees the read reflects all majority-committed writes before the read began
4. Expensive due to the extra round-trip; use sparingly

## Sharding Internals

### Chunk Architecture

Data in a sharded collection is divided into chunks. Each chunk represents a contiguous range of shard key values:

```
Collection: mydb.orders (shard key: { customer_id: 1, order_date: 1 })

Chunk 1: { customer_id: MinKey, order_date: MinKey } -> { customer_id: "C500", order_date: MaxKey }  → Shard A
Chunk 2: { customer_id: "C500", order_date: MinKey } -> { customer_id: "C999", order_date: MaxKey }  → Shard B
Chunk 3: { customer_id: "C999", order_date: MinKey } -> { customer_id: MaxKey, order_date: MaxKey }  → Shard C
```

**Chunk properties:**
- Default maximum chunk size: **128MB** (configurable via `chunksize` setting)
- When a chunk exceeds the maximum, the balancer splits it into two
- Split points are chosen at the median shard key value within the chunk
- An "indivisible" (jumbo) chunk cannot be split because all documents share the same shard key value -- this is why high cardinality is critical for shard keys

### Balancer

The balancer runs on the config server primary and moves chunks between shards to achieve even distribution:

**Balancing algorithm:**
1. Calculate the chunk count per shard for each sharded collection
2. If the difference between the shard with the most chunks and the shard with the fewest exceeds the migration threshold (8 chunks for < 20 total, 4 for 20-79, 2 for 80+), initiate migrations
3. Move one chunk at a time from the most-loaded shard to the least-loaded
4. The balancer respects balancer windows, zones, and concurrent migration limits

**Chunk migration process:**
1. Balancer selects a chunk to move (source -> destination)
2. Destination shard requests the data from the source shard
3. Source shard sends documents in batches while continuing to accept writes
4. Destination shard applies the transferred data
5. Source shard forwards any new writes that occurred during transfer (catch-up phase)
6. Config server updates the metadata to point the chunk range to the destination
7. Source shard deletes the orphaned documents (range deletion)

**Migration impact:** During migration, both the source and destination shards experience increased I/O and memory usage. The `moveChunk` commit is atomic on the config server, so the metadata update is instantaneous, but the data transfer can take seconds to minutes for large chunks.

### Config Servers

Config servers store the authoritative sharding metadata in the `config` database:

| Collection | Contents |
|---|---|
| `config.shards` | Registered shards and their connection strings |
| `config.databases` | Database-to-primary-shard mapping |
| `config.collections` | Sharded collection metadata (shard key, unique, etc.) |
| `config.chunks` | Chunk ranges and their assigned shard |
| `config.tags` | Zone definitions (shard key range -> zone name) |
| `config.settings` | Cluster settings (chunk size, balancer state) |
| `config.locks` | Distributed locks for balancer and migrations |
| `config.migrations` | Active migration tracking |
| `config.changelog` | History of metadata changes |

Config servers are a 3-member replica set (CSRS -- Config Server Replica Set). Loss of the config server majority makes the cluster unable to process metadata-changing operations (migrations, DDL on sharded collections) but existing reads and writes to already-known routes continue.

### Query Routing (mongos)

The mongos router determines which shard(s) to target for each operation:

**Targeted operations (best performance):**
- Query includes an equality match on the full shard key
- Query includes a prefix of the shard key (leftmost fields of a compound shard key)
- The router sends the query to a single shard

**Scatter-gather operations (slower):**
- Query does not include the shard key
- The router sends the query to ALL shards and merges results
- `$sort` on scatter-gather requires merge-sort on the mongos
- `$limit` is pushed to each shard, then the mongos performs a final limit on merged results

**Broadcast operations (always all shards):**
- `$group` without shard key prefix
- `$lookup` where the "from" collection is sharded (6.0+)
- Aggregation pipelines without an initial `$match` on shard key

## Query Planner Internals

### Plan Generation and Selection

When a query is first executed, the query planner:

1. **Enumerate candidate indexes:** Find all indexes that could be used for the query's filter, sort, and projection
2. **Generate candidate plans:** For each useful index, create a plan that combines index scan + fetch + sort (if needed)
3. **Multi-plan evaluation:** If multiple candidates exist, execute them in parallel for a trial period (up to `maxPlanCacheEntries` documents or 10,000 works)
4. **Score and select:** The plan that produces the most results with the least work wins
5. **Cache the winning plan:** The plan is cached in the plan cache (keyed by query shape) for future executions

**Plan cache:**
```javascript
// View cached plans for a collection
db.orders.getPlanCache().list()

// Clear the plan cache for a collection
db.orders.getPlanCache().clear()

// Clear a specific plan cache entry
db.orders.getPlanCache().clearPlansByQuery(
  { status: "active" },  // query shape
  {},                      // sort
  {}                       // projection
)
```

**Plan cache invalidation triggers:**
- Index creation or deletion on the collection
- `planCacheClear` command
- Server restart
- After a threshold of "works" where the cached plan underperforms expectations

### Query Stages

| Stage | Description | Performance Impact |
|---|---|---|
| `COLLSCAN` | Full collection scan | Bad for large collections; read every document |
| `IXSCAN` | Index scan (B-tree traversal) | Efficient; reads only matching index entries |
| `FETCH` | Retrieve full document from collection using _id from index | Required unless index covers all projected fields |
| `SORT` | In-memory sort | 100MB limit without allowDiskUse; check sort memory usage |
| `SORT_KEY_GENERATOR` | Compute sort keys | Precedes SORT stage |
| `PROJECTION` | Apply projection to remove unnecessary fields | Reduces network transfer |
| `LIMIT` | Limit result count | Combined with SORT for top-N optimization |
| `SKIP` | Skip documents | Can be expensive on large offsets |
| `SHARDING_FILTER` | Filter orphaned documents on shard (migration artifacts) | Adds minor overhead on sharded clusters |
| `IDHACK` | Optimized lookup by _id | Fastest path for point lookups |
| `COUNT_SCAN` | Optimized count using index | No FETCH needed |
| `TEXT` | Full-text search using text index | Special scoring and ranking |
| `GEO_NEAR_2DSPHERE` | Geospatial near query | Progressive distance expansion |
| `AND_HASH` / `AND_SORTED` | Index intersection | Combining multiple index results |
| `OR` | Union of multiple index scans for `$or` queries | Each branch can use a different index |
| `SUBPLAN` | Evaluate `$or` branches independently | Plans each branch separately |

## Locking Model

### Lock Granularity

MongoDB uses a multi-granularity locking system:

| Level | Lock Types | Scope |
|---|---|---|
| Global | Intent Shared (IS), Intent Exclusive (IX), Shared (S), Exclusive (X) | Entire mongod instance |
| Database | IS, IX, S, X | All collections in a database |
| Collection | IS, IX, S, X | Single collection |
| Document | Managed by WiredTiger | Single document |

**WiredTiger document-level concurrency:**
- WiredTiger uses optimistic concurrency control for document-level operations
- Multiple threads can modify different documents in the same collection concurrently
- If two threads modify the same document, one will retry (write conflict)
- Write conflicts are automatically retried by the storage engine (transparent to the application for single-document operations)

### Lock Types

| Lock | Abbreviation | Allows Concurrent |
|---|---|---|
| Intent Shared (IS) | `r` | IS, IX, S (not X) |
| Intent Exclusive (IX) | `w` | IS, IX (not S, X) |
| Shared (S) | `R` | IS, S (not IX, X) |
| Exclusive (X) | `W` | Nothing |

**Common lock patterns:**
- A read acquires IS at global, database, and collection levels; WiredTiger handles document-level
- A write acquires IX at global, database, and collection levels; WiredTiger handles document-level
- `createCollection`, `dropCollection`, `createIndex` acquire X at collection level
- `dropDatabase` acquires X at database level
- `fsync` with lock acquires S at global level

### Lock Yielding

Long-running operations (collection scans, index builds) yield their locks periodically to prevent starvation:
- Read operations yield every 128 documents processed
- Write operations yield at regular intervals
- After yielding, the operation reacquires the lock and resumes
- If the underlying data changed during the yield, the operation adjusts

## Transaction Implementation

### Single-Document Atomicity

MongoDB guarantees atomic read-modify-write on a single document, including all embedded sub-documents and arrays. This is the primary reason to embed related data -- it gives you ACID for free without explicit transactions.

### Multi-Document Transactions (4.0+)

Multi-document ACID transactions span multiple documents, collections, and (in 4.2+) shards:

**Transaction lifecycle:**
```javascript
const session = client.startSession();
session.startTransaction({
  readConcern: { level: "snapshot" },
  writeConcern: { w: "majority" },
  readPreference: { mode: "primary" }
});

try {
  await accounts.updateOne(
    { _id: "A" }, { $inc: { balance: -100 } }, { session }
  );
  await accounts.updateOne(
    { _id: "B" }, { $inc: { balance: 100 } }, { session }
  );
  await session.commitTransaction();
} catch (error) {
  await session.abortTransaction();
  throw error;
} finally {
  session.endSession();
}
```

**Transaction implementation details:**
- Transactions use WiredTiger's snapshot isolation (all reads see a consistent point-in-time view)
- The transaction snapshot is taken at the first read/write operation in the transaction
- Writes in the transaction are buffered in the WiredTiger cache and become visible to other sessions only after commit
- On commit, all writes are atomically applied to the oplog as a single `applyOps` entry
- Default transaction lifetime: 60 seconds (`transactionLifetimeLimitSeconds`)
- Maximum transaction size: limited by oplog entry size (16MB for a single oplog entry; transactions spanning multiple oplog entries use a different format in 4.2+)

**Distributed transactions (sharded, 4.2+):**
- Use a two-phase commit protocol coordinated by a transaction coordinator (one of the shards, typically the shard of the first write)
- Phase 1: Coordinator sends prepare to all participant shards; each shard writes a prepare log entry
- Phase 2: If all participants prepare successfully, coordinator sends commit; otherwise abort
- Adds 1-2 extra network round-trips compared to single-shard transactions

**Transaction performance considerations:**
- Multi-document transactions have higher overhead than single-document operations
- Long-running transactions hold WiredTiger snapshots, preventing history store cleanup (similar to PostgreSQL's long-transaction problem with VACUUM)
- Write conflicts in transactions cause `WriteConflict` errors and automatic retry (for retryable transactions) or application-level retry
- Design for short-lived transactions (seconds, not minutes)
- Avoid transactions that modify thousands of documents (performance degrades; consider batch operations instead)

### Retryable Writes and Reads

**Retryable writes (3.6+):**
- Enabled by default in drivers (`retryWrites: true`)
- If a write fails due to a transient network error or primary election, the driver automatically retries
- The server uses the `lsid` (logical session ID) and `txnNumber` to deduplicate retried writes
- Only applicable to single-document operations and certain multi-document operations (insertMany, updateMany, deleteMany, bulkWrite)

**Retryable reads (4.2+):**
- Enabled by default in drivers (`retryReads: true`)
- Automatically retries once on transient network errors
