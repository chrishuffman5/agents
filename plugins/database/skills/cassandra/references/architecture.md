# Apache Cassandra Architecture Reference

## Write Path Internals

### Overview

Cassandra's write path is optimized for sequential I/O and maximum throughput. Every write follows the same deterministic path through the coordinator, commit log, and memtable before eventually being flushed to SSTables.

### Coordinator Selection

1. Client connects to any node in the cluster (the **contact point**)
2. The client driver determines the **coordinator** for each request based on the load-balancing policy:
   - `TokenAwarePolicy` -- Routes to a node that owns the token range for the partition key (avoids an extra network hop)
   - `DCAwareRoundRobinPolicy` -- Round-robins within the local datacenter
   - `RoundRobinPolicy` -- Round-robins across all nodes (not recommended for production)
3. The coordinator determines the **replica set** using the partitioner (Murmur3Partitioner) and the replication strategy

### Commit Log

The commit log provides durability before data reaches an SSTable:

- **Append-only sequential write** -- Every mutation is appended to the current commit log segment
- **Segment size:** Default 32MB (`commitlog_segment_size_in_mb`)
- **Sync modes:**
  - `periodic` (default) -- Syncs to disk every `commitlog_sync_period_in_ms` (default 10000ms). Data written in the last period may be lost on power failure.
  - `batch` -- Groups mutations and syncs within `commitlog_sync_batch_window_in_ms` (default 2ms). Lower throughput but stronger durability.
  - `group` (4.0+) -- Combines batch semantics with better throughput using group commit
- **Segment lifecycle:**
  1. New segment allocated when the current one is full
  2. Mutations written and synced
  3. When ALL memtables that reference a segment have been flushed, the segment is recycled or deleted
- **Compression:** `commitlog_compression` can be set to LZ4, Snappy, or Deflate to reduce disk I/O

```
# cassandra.yaml commit log settings
commitlog_directory: /var/lib/cassandra/commitlog   # MUST be on a separate disk from data
commitlog_segment_size_in_mb: 32
commitlog_sync: periodic
commitlog_sync_period_in_ms: 10000
commitlog_total_space_in_mb: 8192
```

**Critical:** Place the commit log on a dedicated disk (or SSD) separate from data directories. Commit log writes are sequential and latency-sensitive; mixing with random-access data I/O causes write latency spikes.

### Memtable

The memtable is an in-memory sorted structure (ConcurrentSkipListMap) that buffers writes:

- **One memtable per table per node** (technically per CFS -- ColumnFamilyStore)
- **Sorted by partition key and clustering columns** -- Enables efficient merging during reads and flushes
- **Write operations:**
  - INSERT: Adds a new cell to the memtable
  - UPDATE: Adds a new cell (last-write-wins by timestamp; no read-before-write)
  - DELETE: Adds a tombstone marker
- **Memory allocation:**
  - On-heap or off-heap depending on `memtable_allocation_type` (default: `heap_buffers`, alternatives: `offheap_buffers`, `offheap_objects`)
  - Total memtable space limited by `memtable_heap_space_in_mb` and `memtable_offheap_space_in_mb`
- **Flush triggers:**
  - Memtable size reaches `memtable_cleanup_threshold` (default: 1/(memtable_flush_writers + 1))
  - Commit log space is exhausted (`commitlog_total_space_in_mb`)
  - `nodetool flush` is executed manually
  - Node shutdown (graceful)
  - ColumnFamily (table) is altered or dropped

### Memtable Flush to SSTable

When a memtable is flushed:

1. The memtable is marked as **frozen** (no new writes; a new memtable is created)
2. The sorted data is written sequentially to a new SSTable on disk
3. The flush produces the following SSTable components (see SSTable Format below)
4. After the flush completes, the commit log segments that only referenced this memtable are eligible for recycling

**Flush performance:**
- Controlled by `memtable_flush_writers` (default: 2, or number of data directories)
- Each flush writer is a dedicated thread
- Flushing is I/O-bound; SSD storage significantly reduces flush latency
- Large memtables flush slower but produce fewer SSTables (less compaction pressure)

### Hinted Handoff

When a replica is unreachable during a write:

1. The coordinator stores a **hint** -- a copy of the mutation intended for the down node
2. Hints are stored in the `system.hints` table (3.0+) or `system_hints` directory
3. When the target node comes back online, hints are replayed to it
4. **Hint window:** `max_hint_window_in_ms` (default 3 hours). Hints older than this are discarded.
5. **Hint storage limits:** `max_hints_file_size_in_mb` (default 128MB per hints file)

```yaml
# cassandra.yaml
hinted_handoff_enabled: true
max_hint_window_in_ms: 10800000   # 3 hours
hinted_handoff_throttle_in_kb: 1024
max_hints_delivery_threads: 2
```

**Limitations:**
- Hints are NOT a repair mechanism -- they only cover the hint window
- If a node is down longer than `max_hint_window_in_ms`, data is NOT hinted and repair is required
- Hints consume disk space on the coordinator node
- Hint replay can overwhelm a recovering node (throttled by `hinted_handoff_throttle_in_kb`)
- CL=ANY will succeed if the write is only stored as a hint (no replica actually has the data)

## Read Path Internals

### Overview

Cassandra's read path must merge data from the memtable and potentially multiple SSTables, since each SSTable is an immutable snapshot of the data at flush time. Newer writes (by timestamp) take precedence.

### Coordinator Read Logic

1. **Determine replicas** using partitioner + replication strategy
2. **Select which replicas to query:**
   - Send a **data request** to the replica with the lowest estimated latency (via dynamic snitch)
   - Send **digest requests** to additional replicas to meet the consistency level
   - Digest requests return only a hash of the data, not the full data
3. **Wait for responses** up to `read_request_timeout_in_ms` (default 5000ms)
4. **Compare:** If the digest from all responding replicas matches, return the data response
5. **Read repair:** If digests differ, fetch full data from all replicas, determine the correct (latest timestamp) version, and send repair mutations to out-of-date replicas

### Single-Replica Read Path (Per-Node)

On the replica that performs the actual data read:

```
Query arrives for partition key P, clustering range [C1, C2]
│
├── 1. Check Row Cache (if enabled) ─── HIT ──> Return cached row
│                                        │
│                                       MISS
│                                        │
├── 2. Read from Memtable (current + flushing memtables)
│      └── Merge any matching cells
│
├── 3. For each SSTable (newest to oldest):
│      │
│      ├── 3a. Bloom Filter check
│      │        └── "Definitely not in this SSTable" ──> Skip
│      │        └── "Possibly in this SSTable" ──> Continue
│      │
│      ├── 3b. Partition Index Summary (in-memory)
│      │        └── Sample every Nth partition index entry
│      │        └── Gives approximate disk offset range
│      │
│      ├── 3c. Partition Index (on disk, may be cached in key cache)
│      │        └── Binary search for exact partition position
│      │        └── Returns offset into the Data file
│      │
│      ├── 3d. Compression Offset Map (in-memory)
│      │        └── Maps uncompressed offset to compressed chunk
│      │
│      └── 3e. Read and decompress data chunk from Data file
│              └── Apply clustering column filter [C1, C2]
│              └── Return matching cells
│
├── 4. Merge results from all sources (memtable + SSTables)
│      └── Last-write-wins by cell timestamp
│      └── Tombstones suppress older data
│      └── TTL-expired cells treated as tombstoned
│
└── 5. Return merged result to coordinator
```

### Read Repair

Read repair is a mechanism to fix inconsistencies detected during reads:

**Blocking read repair (deprecated in 4.0+):**
- Triggered when digest mismatch is detected during a read
- Coordinator fetches full data from all replicas, compares, and sends repair mutations
- The read blocks until repairs are sent (increases read latency)
- Controlled by `read_repair_chance` (removed in 4.0)

**Background read repair (4.0+):**
- Digest mismatches still trigger repair, but the repair is performed asynchronously
- The read returns the latest data immediately
- Repairs are sent in the background

**Speculative retry:**
```
# cassandra.yaml or per-table
speculative_retry = '99percentile'   # retry if response takes longer than p99
```
- If the primary replica is slow, the coordinator sends a speculative request to another replica
- Reduces tail latency at the cost of slightly higher load

## SSTable Format

Each SSTable on disk consists of multiple component files:

### Component Files

| File Extension | Name | Description |
|---|---|---|
| `-Data.db` | Data | The actual row data, sorted by partition key and clustering columns |
| `-Index.db` | Partition Index | Maps partition keys to positions in the Data file |
| `-Summary.db` | Summary | In-memory sampling of the partition index (every Nth entry) |
| `-Filter.db` | Bloom Filter | Probabilistic data structure for quick "not in this SSTable" checks |
| `-CompressionInfo.db` | Compression Info | Maps uncompressed offsets to compressed chunk positions |
| `-Statistics.db` | Statistics | SSTable metadata: min/max timestamps, tombstone counts, partition sizes |
| `-TOC.txt` | Table of Contents | Lists all component files for this SSTable |
| `-Digest.crc32` | Digest | CRC32 checksum for data integrity validation |
| `-CRC.db` | CRC | Per-chunk CRC for data integrity |

### SSTable Naming

Format: `<version>-<generation>-<format>-<component>`

Example: `nb-1-big-Data.db`
- `nb` = SSTable format version (Cassandra 3.0+ format)
- `1` = generation number (incremented for each new SSTable)
- `big` = format identifier
- `Data.db` = component

### Bloom Filters

Bloom filters provide a probabilistic answer to "is partition key P in this SSTable?":

- **False positives possible:** The filter may say "yes" when the key is not present (triggers a wasted disk read)
- **False negatives impossible:** If the filter says "no," the key is definitely not present (safe to skip)
- **Tuning:** `bloom_filter_fp_chance` per table (default 0.01 = 1% false positive rate)
  - Lower values = larger bloom filter = more memory but fewer wasted disk reads
  - Higher values = smaller bloom filter = less memory but more wasted disk reads
  - For tables rarely read, increase to 0.1 to save memory
  - For tables frequently read, decrease to 0.001

```cql
ALTER TABLE my_table WITH bloom_filter_fp_chance = 0.001;
```

**Memory usage:** Approximately 10 bits per partition key at 1% FP rate. For 100M partitions: ~120MB per SSTable.

### Partition Index Summary

The partition index summary is an in-memory sampling of the full partition index:

- Stores every `min_index_interval`th (default 128) entry from the partition index
- Provides the approximate position in the partition index file
- A binary search on the summary narrows down the disk seek to a small range
- `max_index_interval` (default 2048) -- Cassandra may dynamically increase the sampling interval under memory pressure

```cql
ALTER TABLE my_table WITH min_index_interval = 64
                     AND max_index_interval = 1024;
```

### Compression

SSTable data is compressed in chunks:

- Default chunk size: 16KB (tunable via `chunk_length_in_kb`)
- Default compressor: LZ4Compressor (alternatives: SnappyCompressor, DeflateCompressor, ZstdCompressor in 4.0+)
- Compression is per-chunk, allowing random access (decompress only the needed chunk)
- The compression offset map (in memory) maps uncompressed offsets to compressed chunk locations

```cql
ALTER TABLE my_table WITH compression = {
    'class': 'LZ4Compressor',
    'chunk_length_in_kb': 16
};

-- Disable compression (for SSDs with hardware compression)
ALTER TABLE my_table WITH compression = {'enabled': false};
```

**Trade-offs:**
- Larger chunks = better compression ratio but more data read per point query
- Smaller chunks = worse compression ratio but more efficient point queries
- LZ4 is fastest; Zstd has best ratio; Deflate is a middle ground

## Compaction Internals

### Overview

Compaction is the background process that merges SSTables to:
1. Consolidate data (merge multiple versions of the same row)
2. Purge tombstones (after gc_grace_seconds has elapsed)
3. Reduce the number of SSTables (improving read performance)
4. Reclaim disk space

### Size-Tiered Compaction Strategy (STCS)

STCS groups SSTables of similar size into **buckets** and compacts each bucket when it reaches `min_threshold` (default 4):

```
Tier 0: [10MB] [10MB] [10MB] [10MB]  --> compact into ~40MB SSTable
Tier 1: [40MB] [40MB] [40MB] [40MB]  --> compact into ~160MB SSTable
Tier 2: [160MB] [160MB] [160MB] [160MB] --> compact into ~640MB SSTable
```

**Parameters:**
```cql
ALTER TABLE my_table WITH compaction = {
    'class': 'SizeTieredCompactionStrategy',
    'min_threshold': 4,             -- min SSTables to trigger compaction
    'max_threshold': 32,            -- max SSTables in a single compaction
    'min_sstable_size': 50,         -- min size (MB) for bucketing
    'bucket_high': 1.5,             -- upper bound for same-size bucket
    'bucket_low': 0.5               -- lower bound for same-size bucket
};
```

**Characteristics:**
- Write amplification: ~O(log N) -- each datum rewritten each time its tier compacts
- Space amplification: Up to 2x temporarily during compaction (input + output SSTables coexist)
- Read amplification: Higher -- many SSTables may overlap in key range
- Temporary disk requirement: Need ~50% free space for compaction to proceed

### Leveled Compaction Strategy (LCS)

LCS organizes SSTables into levels with guaranteed non-overlapping key ranges (except L0):

```
L0: [memtable flushes -- may overlap]
    ↓ compact into L1
L1: [160MB] [160MB] [160MB] ... (max 10 SSTables, non-overlapping, ~1.6GB total)
    ↓ compact into L2
L2: [160MB] [160MB] [160MB] ... (max 100 SSTables, non-overlapping, ~16GB total)
    ↓ compact into L3
L3: [160MB] [160MB] [160MB] ... (max 1000 SSTables, ~160GB total)
```

**Parameters:**
```cql
ALTER TABLE my_table WITH compaction = {
    'class': 'LeveledCompactionStrategy',
    'sstable_size_in_mb': 160,     -- target SSTable size
    'fanout_size': 10              -- multiplier between levels (4.0+)
};
```

**Characteristics:**
- Read amplification: Low -- at most one SSTable per level contains any given key
- Write amplification: High -- ~10x (each datum rewritten when promoted to the next level)
- Space amplification: Low -- ~10% overhead
- Compaction always produces SSTables of `sstable_size_in_mb`
- Best for read-heavy workloads with frequent updates/overwrites

### Time-Window Compaction Strategy (TWCS)

TWCS groups SSTables by the time window in which their data was written:

```
Window 1 (Mon):  [SST1] [SST2] [SST3]  --> STCS within window --> [SST_Mon]
Window 2 (Tue):  [SST4] [SST5]          --> STCS within window --> [SST_Tue]
Window 3 (Wed):  [SST6] [SST7] [SST8]  --> (current window, compacting via STCS)
```

**Parameters:**
```cql
ALTER TABLE my_table WITH compaction = {
    'class': 'TimeWindowCompactionStrategy',
    'compaction_window_size': 1,
    'compaction_window_unit': 'DAYS',   -- MINUTES, HOURS, DAYS
    'timestamp_resolution': 'MICROSECONDS',
    'max_sstable_age_days': 365,        -- don't compact SSTables older than this
    'unsafe_aggressive_sstable_expiration': false  -- true = drop SSTables when all data has TTL-expired
};
```

**Characteristics:**
- Write amplification: Lowest -- data is only compacted within its time window
- Once a window closes, its SSTables are compacted once and never touched again
- SSTables whose entire contents have expired can be dropped wholesale (with aggressive expiration enabled)
- **Critical restriction:** Out-of-order writes (data with timestamps in old windows arriving late) create SSTables that span windows, which are never compacted, leading to read amplification. Ensure writes arrive in roughly chronological order.

## Gossip Protocol

### Overview

Gossip is Cassandra's peer-to-peer protocol for disseminating cluster state. Every node gossips with 1-3 other nodes every second.

### Gossip Round

1. Node A selects a random live node B (and possibly a random unreachable node C and a random seed node)
2. A sends a `GossipDigestSyn` message containing digests (node ID + generation + version) for all known endpoints
3. B compares the digests with its own state:
   - If B has newer information, it includes that in its response
   - If A has newer information, B requests it
4. B responds with a `GossipDigestAck` containing newer state and requests for states it needs
5. A processes the response and sends a `GossipDigestAck2` with any requested states

### Gossip State

Each node's gossip state includes:

| State Key | Description |
|---|---|
| `STATUS` | Node status: NORMAL, LEAVING, LEFT, MOVING, REMOVED |
| `LOAD` | Disk space used (bytes) |
| `SCHEMA` | Schema version UUID |
| `DC` | Datacenter name |
| `RACK` | Rack name |
| `RELEASE_VERSION` | Cassandra version |
| `TOKENS` | Token ranges owned by the node |
| `HOST_ID` | Unique host identifier (UUID) |
| `NET_VERSION` | Messaging protocol version |
| `NATIVE_TRANSPORT_ADDRESS` | CQL native transport address |
| `NATIVE_TRANSPORT_PORT` | CQL native transport port |
| `SSTABLE_VERSIONS` | Supported SSTable format versions |

View gossip state: `nodetool gossipinfo`

### Seed Nodes

Seed nodes are the initial contact points for a new node joining the cluster:

- Defined in `cassandra.yaml` under `seed_provider`
- New nodes contact seed nodes to learn about the cluster topology
- Seeds are NOT special in steady state -- they participate in normal gossip
- **Best practice:** Use 2-3 seed nodes per datacenter. Seeds should be stable, long-running nodes.
- **Warning:** All seed nodes down simultaneously prevents new nodes from joining but does NOT affect existing cluster operation

## Failure Detection (Phi Accrual)

Cassandra uses the **Phi Accrual Failure Detector** to determine if a node is alive or dead:

- Rather than a binary alive/dead determination, the detector calculates a suspicion level (phi value)
- Phi is based on the inter-arrival time of gossip messages from each peer
- When phi exceeds `phi_convict_threshold` (default 8), the node is marked as down
- The detector adapts to network conditions -- a normally fast node that suddenly becomes slow will be detected more quickly than a node with normally high latency

```yaml
# cassandra.yaml
phi_convict_threshold: 8   # increase to 10-12 in cloud/high-latency environments
```

**Phi interpretation:**
| Phi Value | Probability of Being Alive | Action |
|---|---|---|
| 1 | 90% | Normal |
| 2 | 99% | Normal |
| 5 | 99.999% | Suspicious |
| 8 | 99.9999997% | Default convict threshold |
| 12 | Extremely unlikely alive | Recommended for cloud environments |

## Anti-Entropy Repair

### Overview

Repair is Cassandra's mechanism for synchronizing data across replicas. It detects and resolves inconsistencies that accumulate due to node failures, network partitions, dropped mutations, or missed hints.

### Merkle Tree (Hash Tree) Repair

The core repair mechanism uses Merkle trees to efficiently compare data between replicas:

1. **Build Merkle trees:** Each replica builds a hash tree of its data for the requested token range
   - Leaf nodes contain hashes of individual partitions or partition ranges
   - Parent nodes contain hashes of their children
   - The root hash summarizes the entire dataset
2. **Compare trees:** The coordinator compares Merkle trees from different replicas
   - If root hashes match, data is consistent -- no repair needed
   - If root hashes differ, walk down the tree to find the specific ranges that differ
3. **Stream differences:** Only the differing ranges are streamed between replicas

### Full Repair

```bash
# Repair all keyspaces and tables on the current node
nodetool repair

# Repair a specific keyspace
nodetool repair my_keyspace

# Repair a specific table
nodetool repair my_keyspace my_table

# Repair only the primary token ranges owned by this node (-pr)
nodetool repair -pr my_keyspace

# Parallel repair (repairs multiple token ranges simultaneously)
nodetool repair -par my_keyspace

# Sequential repair (one range at a time -- safer but slower)
nodetool repair -seq my_keyspace

# Datacenter-local repair
nodetool repair -local my_keyspace

# Repair within specific token range (subrange repair)
nodetool repair -st <start_token> -et <end_token> my_keyspace
```

**Full repair characteristics:**
- Creates a new Merkle tree for the entire dataset on each replica
- Can be I/O and CPU intensive
- Safe to run at any time
- Must complete within `gc_grace_seconds` to prevent zombie data

### Incremental Repair (4.0+)

Incremental repair only repairs data that has been written since the last repair:

- SSTables are marked as **repaired** or **unrepaired**
- Only unrepaired SSTables are included in the Merkle tree
- Significantly faster than full repair for clusters with regular repair schedules
- In 4.0+, repaired and unrepaired SSTables are stored in separate compaction pools

```bash
# Run incremental repair (default in 4.0+)
nodetool repair my_keyspace

# Force full repair even in 4.0+
nodetool repair --full my_keyspace
```

**Pre-4.0 incremental repair issues:**
- In 3.x, incremental repair had bugs where repaired SSTables could participate in compaction with unrepaired SSTables, causing data inconsistencies
- Recommendation: Use full repair in 3.x; use incremental repair in 4.0+

### Subrange Repair

Divides the token range into smaller segments for more granular control:

```bash
# Repair a specific token subrange
nodetool repair -st -9223372036854775808 -et -4611686018427387904 my_keyspace

# Tools like cassandra-reaper automate subrange repair scheduling
```

**Advantages:**
- Each subrange repair is smaller and completes faster
- If interrupted, only the current subrange needs to be retried
- Reduces peak I/O and memory usage
- Enables better progress tracking

## Paxos for Lightweight Transactions

### Protocol Flow

Cassandra's LWT implementation uses a modified Paxos consensus protocol with four phases:

```
Client                Coordinator           Replica 1       Replica 2       Replica 3
  │                       │                     │               │               │
  │── LWT Write ─────────>│                     │               │               │
  │                       │── PREPARE(ballot) ──>│               │               │
  │                       │── PREPARE(ballot) ──────────────────>│               │
  │                       │── PREPARE(ballot) ──────────────────────────────────>│
  │                       │<── PROMISE ─────────│               │               │
  │                       │<── PROMISE ────────────────────────│               │
  │                       │                     │               │               │
  │                       │   (read current values for IF condition check)      │
  │                       │                     │               │               │
  │                       │── PROPOSE(ballot,value) ──>│        │               │
  │                       │── PROPOSE(ballot,value) ───────────>│               │
  │                       │── PROPOSE(ballot,value) ────────────────────────────>│
  │                       │<── ACCEPT ──────────│               │               │
  │                       │<── ACCEPT ─────────────────────────│               │
  │                       │                     │               │               │
  │                       │── COMMIT ──────────>│               │               │
  │                       │── COMMIT ──────────────────────────>│               │
  │                       │── COMMIT ──────────────────────────────────────────>│
  │<── Result ───────────│                     │               │               │
```

### Paxos Tables

LWT state is stored in system tables:

- `system.paxos` -- Stores the current Paxos state (ballot, proposal, commit) for each partition
- Paxos state must be read before and written after each LWT operation
- This is why LWT has ~4x the latency of a normal write

### Contention and Performance

- **Ballot conflicts:** If two LWT operations target the same partition simultaneously, their ballots conflict and one must retry
- **Paxos table compaction:** The `system.paxos` table can grow very large under heavy LWT usage; ensure it compacts regularly
- **Timeout:** LWT uses `cas_contention_timeout_in_ms` (default 1000ms) for Paxos rounds
- **Paxos repair (4.0+):** `nodetool repair --paxos-only` repairs only the Paxos state, much faster than full repair

## Streaming Protocol

Streaming is the mechanism for transferring SSTable data between nodes during:
- **Bootstrap** (new node joining the cluster)
- **Decommission** (node leaving the cluster)
- **Repair** (transferring differing data ranges)
- **Rebuild** (restoring data from replicas)
- **Node replacement** (replacing a dead node)

### Streaming Flow

1. **Session setup:** Source and target nodes negotiate which token ranges and tables to stream
2. **SSTable selection:** Source selects SSTables that contain data in the requested ranges
3. **Data transfer:** SSTables are streamed in chunks over a dedicated streaming connection
4. **Checksum validation:** Each chunk is validated with a CRC checksum
5. **SSTable reconstruction:** Target node writes received data into new SSTables
6. **Session completion:** Both nodes acknowledge completion

### Streaming Configuration

```yaml
# cassandra.yaml
stream_throughput_outbound_megabits_per_sec: 200   # throttle outbound streaming
inter_dc_stream_throughput_outbound_megabits_per_sec: 0  # 0 = unlimited inter-DC streaming
streaming_connections_per_host: 1                   # number of simultaneous streaming connections per host
```

**Monitor streaming:**
```bash
nodetool netstats        # shows active streams
nodetool getstreams      # (4.0+) detailed stream progress
```

## Snitch Types

The snitch determines the datacenter and rack of each node, which affects:
- Replica placement (NetworkTopologyStrategy uses snitch info)
- Request routing (dynamic snitch routes reads to the fastest replica)
- Local consistency levels (LOCAL_QUORUM, LOCAL_ONE use the coordinator's DC as "local")

### Available Snitches

| Snitch | Configuration | Use Case |
|---|---|---|
| `SimpleSnitch` | None | Single-DC development only |
| `PropertyFileSnitch` | `cassandra-topology.properties` on every node | Small clusters; static topology |
| `GossipingPropertyFileSnitch` | `cassandra-rackdc.properties` on each node | **Production standard**. Each node gossips its DC/rack. |
| `Ec2Snitch` | Auto-detects from EC2 metadata | Single-region AWS deployments |
| `Ec2MultiRegionSnitch` | Auto-detects from EC2 metadata | Multi-region AWS deployments |
| `GoogleCloudSnitch` | Auto-detects from GCE metadata | Google Cloud deployments |
| `CloudstackSnitch` | Auto-detects from Cloudstack metadata | Cloudstack environments |
| `RackInferringSnitch` | Infers from IP address octets | Legacy; not recommended |

### Dynamic Snitch

The dynamic snitch wraps the configured snitch and adds latency-aware routing:

- Tracks read latency to each replica over a sliding window
- Routes data requests to the replica with the lowest latency
- Periodically resets scores to prevent permanent blacklisting of temporarily slow nodes
- Configuration:
  ```yaml
  dynamic_snitch_update_interval_in_ms: 100    # how often to recalculate scores
  dynamic_snitch_reset_interval_in_ms: 600000  # how often to reset all scores (10 min)
  dynamic_snitch_badness_threshold: 1.0        # how much worse a replica must be to avoid it (0-1 scale; 0 = always route to fastest)
  ```

**`cassandra-rackdc.properties` example (GossipingPropertyFileSnitch):**
```
dc=us-east-1
rack=rack1
prefer_local=true
```

## Memory Architecture

### On-Heap vs. Off-Heap

| Component | Location | Sizing |
|---|---|---|
| Memtables | Heap (default) or off-heap | `memtable_heap_space_in_mb`, `memtable_offheap_space_in_mb` |
| Key cache | Off-heap (native memory) | `key_cache_size_in_mb` (default: 100MB or 5% of heap) |
| Row cache | Off-heap | `row_cache_size_in_mb` (default: 0 = disabled) |
| Bloom filters | Off-heap | Proportional to number of partitions |
| Partition index summary | Off-heap | Proportional to number of partitions / `min_index_interval` |
| Compression offset maps | Off-heap | Proportional to data size / chunk_length |
| Chunk cache (4.0+) | Off-heap | `file_cache_size_in_mb` (replaces buffer/chunk cache) |
| Networking buffers | Off-heap | Proportional to concurrent connections |

### Memory Sizing Formula

```
Total process memory = JVM heap
                     + off-heap (bloom filters + index summaries + compression offsets + caches)
                     + JVM overhead (~300-500MB)
                     + OS page cache (remaining RAM)
```

**Rule of thumb for a node with 64GB RAM:**
- JVM heap: 8-16GB (never exceed 31GB due to compressed oops)
- Off-heap: 2-8GB (varies with data volume and table count)
- OS page cache: Remaining 40-54GB (critical for SSTable read performance)

### Chunk Cache (4.0+)

Replaced the buffer pool and file-based caching in 4.0:
- Caches uncompressed SSTable chunks in off-heap memory
- Sized via `file_cache_size_in_mb` (default: min(25% of heap, 512MB))
- Eviction: frequency-based (most recently and frequently accessed chunks kept)
- Reduces disk I/O for repeated reads of the same data
