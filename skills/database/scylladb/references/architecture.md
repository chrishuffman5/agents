# ScyllaDB Architecture Reference

## Seastar Framework Internals

ScyllaDB is built from the ground up on the Seastar framework, a C++ library for high-performance server applications. Seastar acts as a "mini operating system in userspace," providing its own task scheduler, I/O scheduler, memory allocator, and network stack.

### Thread-Per-Core Model

Seastar pins exactly one application thread to each CPU core. There is no thread pool, no work stealing, and no shared mutable state between threads:

```
Physical Machine (32 cores, 256GB RAM)
├── Core 0 (Shard 0): 8GB RAM, own memtables, SSTables, cache, I/O queue
├── Core 1 (Shard 1): 8GB RAM, own memtables, SSTables, cache, I/O queue
├── Core 2 (Shard 2): 8GB RAM, own memtables, SSTables, cache, I/O queue
├── ...
└── Core 31 (Shard 31): 8GB RAM, own memtables, SSTables, cache, I/O queue
```

Each shard operates as an independent database instance:
- **Memory:** Allocated from a contiguous region (no malloc/free from global heap). Seastar's memory allocator is per-core.
- **SSTables:** Each shard reads/writes its own SSTables. SSTables are striped across shards at flush time.
- **Cache:** Each shard maintains its own row cache partition. No cross-shard cache invalidation needed.
- **Network:** Each shard has its own set of connections. With DPDK, each shard has its own NIC queue.
- **I/O:** Each shard has its own I/O queue with independent scheduling.

### Cooperative Multitasking (Futures and Promises)

Seastar uses cooperative multitasking with futures and continuations. There is no preemptive scheduling within a shard:

```
Request arrives on Shard 3:
  1. Parse CQL (synchronous, microseconds)
  2. Check memtable (synchronous, microseconds)
  3. Issue disk read (asynchronous -- yields to scheduler)
     --> Scheduler runs other tasks on Shard 3
  4. Disk read completes (continuation fires)
  5. Merge results (synchronous, microseconds)
  6. Send response (asynchronous -- yields)
```

Every I/O operation returns a `future<T>`. The scheduler runs other tasks while waiting for I/O completion. This eliminates blocking, context switching, and thread synchronization overhead.

### Inter-Shard Communication

When a request arrives on one shard but the data lives on another, ScyllaDB uses `submit_to()` for inter-shard messaging:

```
Client --> Shard 5 (coordinator) --> submit_to(Shard 12) --> Shard 12 processes --> response back to Shard 5
```

This is explicit message passing, not shared memory. The overhead is minimal (~1-5 microseconds per hop) but shard-aware drivers eliminate most cross-shard hops by routing directly to the owning shard.

### DPDK (Data Plane Development Kit) -- Optional

ScyllaDB can optionally use DPDK for kernel-bypass networking:
- Bypasses the Linux kernel network stack entirely
- Direct NIC queue per shard (no interrupt coalescing)
- Reduces network latency by 10-50 microseconds
- Requires dedicated NIC and hugepages
- Most deployments use POSIX networking (sufficient for most workloads)

## Memory Management

### Per-Shard Memory Layout

Each shard's memory is divided into:

1. **Row cache** -- LRU cache of recently accessed rows. Largest consumer.
2. **Memtables** -- In-memory write buffer (one per table per shard). Flushed to SSTable when full.
3. **Index cache** -- Partition index entries for fast SSTable lookup.
4. **Bloom filters** -- Probabilistic data structure per SSTable (in-memory).
5. **Compression metadata** -- Offset maps for compressed SSTables.
6. **Internal buffers** -- Network buffers, I/O buffers, scheduling data structures.

**Memory backpressure:**
When a shard's memory pressure increases, ScyllaDB applies backpressure:
1. Evict row cache entries (LRU)
2. Flush memtables to disk (creating SSTables)
3. If still under pressure, reject new writes with `Seastar::memory::allocation_failure`

There is no OOM killer equivalent -- ScyllaDB manages all memory within its allocation.

### LSA (Log-Structured Allocator)

ScyllaDB uses LSA for memtable and cache memory allocation:
- Memory is organized into segments (default 4MB)
- Segments can be compacted (defragmented) without stopping the shard
- Enables efficient memory reclamation without GC pauses
- Allocation and deallocation are O(1)

## Write Path

ScyllaDB's write path is similar to Cassandra's but executes within the shard-per-core model:

### Step-by-Step Write Flow

1. **Client sends write** to a ScyllaDB node (coordinator).
2. **Coordinator shard** receives the request. If using a shard-aware driver, the request lands on the correct shard; otherwise, it is forwarded to the owning shard via `submit_to()`.
3. **Coordinator determines replicas** using the partitioner (Murmur3) and replication strategy.
4. **Write is sent to replica nodes** in parallel (async futures).
5. **On each replica node, the owning shard:**
   a. Writes to the **commitlog** (sequential append, O_DIRECT). The commitlog is shared across shards but writes are batched per-shard for efficiency.
   b. Writes to the shard's **memtable** (in-memory sorted structure using LSA).
   c. Optionally updates the **row cache** (if the row is cached).
   d. Acknowledges to the coordinator.
6. **Coordinator waits** for the required number of acknowledgments (per consistency level), then responds to the client.
7. **Memtable flush:** When the shard's memtable reaches its size threshold, it is flushed to an immutable SSTable on disk. This SSTable belongs to that shard.
8. **Compaction** runs per-shard in the background, merging SSTables.

### Commitlog

- One commitlog per node (shared across shards), but writes are batched per-shard
- Sequential append with O_DIRECT (bypasses page cache)
- Sync modes:
  - `periodic` (default) -- Syncs every `commitlog_sync_period_in_ms` (default 10000ms)
  - `batch` -- Syncs after every write batch (lower throughput, stronger durability)
- Commitlog segments are recycled after the corresponding memtable is flushed

```yaml
# scylla.yaml commitlog configuration
commitlog_sync: periodic
commitlog_sync_period_in_ms: 10000
commitlog_segment_size_in_mb: 64
commitlog_total_space_in_mb: -1   # auto-calculated
```

### Memtable

- One memtable per table per shard (not shared)
- Implemented as a B+ tree (sorted by clustering key within partition)
- Uses LSA (Log-Structured Allocator) for memory management
- Flushed when:
  - Memtable size reaches threshold
  - Total commitlog space is exhausted
  - Manual flush via `nodetool flush`
  - Node shutdown

## Read Path

### Step-by-Step Read Flow

1. **Client sends read** to coordinator node.
2. **Coordinator shard** determines replicas and selects the fastest replica (using dynamic snitch latency scores).
3. **Coordinator sends:**
   - A full data request to the closest/fastest replica
   - Digest requests to other replicas (enough to satisfy consistency level)
4. **On the replica, the owning shard:**
   a. Checks the **row cache** -- if present and complete, return immediately.
   b. Checks the **memtable** -- merge any in-memory data.
   c. For each SSTable (newest to oldest):
      - Check the **bloom filter** -- skip SSTable if definitely not present
      - Check the **partition index** (in-memory summary + on-disk index)
      - Read the data block (O_DIRECT, from shard's I/O queue)
      - Decompress if needed
   d. **Merge** results from cache, memtable, and SSTables (last-write-wins by timestamp)
   e. **Populate row cache** with the result (if cacheable)
5. **Coordinator compares** full response with digest responses.
6. If digests match, return result. If not, trigger **read repair**.

### Row Cache

- Per-shard LRU cache
- Stores complete rows (not blocks, not pages)
- Populated on read (read-through cache)
- Invalidated on write (write-through for cached rows)
- Size managed automatically by ScyllaDB's memory management
- Unlike Cassandra's row cache (often disabled), ScyllaDB's is highly effective due to per-shard isolation

### Bloom Filters

- One bloom filter per SSTable (loaded in memory)
- False-positive rate configurable via `bloom_filter_fp_chance` (default 0.01 = 1%)
- Lower false-positive rate = more memory per SSTable
- A negative bloom filter result means the key is definitely not in that SSTable (skip)
- A positive result means the key might be there (must check)

### Reverse Queries and Clustering Order

ScyllaDB efficiently supports reverse iteration on clustering columns:
- `CLUSTERING ORDER BY (col DESC)` stores data in descending order on disk
- Range queries respect the clustering order
- Reversing at query time (`ORDER BY col ASC` on a DESC table) is supported but less efficient

## SSTable Format

ScyllaDB uses the same SSTable format as Cassandra (mc/md format) with per-shard storage:

### SSTable Components
- **Data.db** -- The actual row data, sorted by partition key then clustering key
- **Index.db** -- Partition index (maps partition key to position in Data.db)
- **Summary.db** -- In-memory sampling of Index.db (every Nth entry)
- **Filter.db** -- Bloom filter
- **Statistics.db** -- SSTable metadata (min/max timestamp, row count, partition count, etc.)
- **CompressionInfo.db** -- Compression offset map
- **TOC.txt** -- Table of contents listing all components
- **Scylla/scylla.db** -- ScyllaDB-specific metadata (shard assignment, etc.)

### Per-Shard SSTable Assignment

Each SSTable is owned by a single shard. When a memtable is flushed:
1. The shard writes its own SSTable to disk
2. The SSTable's filename encodes the shard ID
3. During compaction, a shard only touches its own SSTables
4. This eliminates cross-shard coordination during flush and compaction

### Compression

```yaml
# Default compression (per table, in CQL)
compression = {'sstable_compression': 'LZ4Compressor',
               'chunk_length_in_kb': 4}

# Options: LZ4Compressor (default, fastest), SnappyCompressor, DeflateCompressor, ZstdCompressor
# Zstd available in newer versions -- better ratio than LZ4, slightly more CPU
```

## Tablets Architecture

### Overview

Tablets (introduced in 6.0, default in 2025.1+) replace vnodes as the data distribution mechanism:

- A **tablet** is a contiguous range of the token space for a specific table
- Each tablet has a fixed replication factor and a set of replica nodes/shards
- Tablets are the unit of:
  - **Replication** -- each tablet is replicated independently
  - **Migration** -- individual tablets move between nodes for load balancing
  - **Split/merge** -- tablets split when they grow, merge when they shrink

### Tablet Lifecycle

```
Table Created
  └── Initial tablet count determined (based on cluster size and table settings)
       └── Each tablet assigned to nodes/shards
            ├── Tablet grows --> tablet splits into two tablets
            ├── Tablet shrinks --> tablet merges with neighbor
            ├── Node added --> some tablets migrate to new node
            └── Node removed --> tablets migrate off departing node
```

### Tablet vs Vnode Architecture

```
Vnodes:
  Node A: tokens [0, 100), [500, 600), [900, 950)
  Node B: tokens [100, 250), [600, 750)
  Node C: tokens [250, 500), [750, 900), [950, 1000)
  --> All tables share the same token ranges per node

Tablets:
  Table "users":
    Tablet 1 [0, 500): Replicas on Node A Shard 3, Node B Shard 7, Node C Shard 1
    Tablet 2 [500, 1000): Replicas on Node B Shard 2, Node C Shard 5, Node A Shard 9
  Table "events":
    Tablet 1 [0, 333): Replicas on Node C Shard 4, Node A Shard 1, Node B Shard 8
    Tablet 2 [333, 666): Replicas on Node A Shard 6, Node B Shard 3, Node C Shard 2
    Tablet 3 [666, 1000): Replicas on Node B Shard 1, Node C Shard 7, Node A Shard 4
  --> Each table has independent tablet placement
```

### Tablet Migration (Streaming)

When a tablet needs to move (e.g., during scale-out):
1. **File-based streaming** (2025.1+) -- Entire SSTables are streamed directly to the target shard without deserialization/reserialization
2. The source tablet continues serving reads during migration
3. Writes are forwarded to the new location once migration begins
4. Migration completes when all SSTables are transferred and in-flight writes are drained
5. Tablet ownership atomically switches to the new shard

This is dramatically faster than vnode-based streaming, which requires rewriting all data for affected token ranges.

### Tablet Configuration

```yaml
# scylla.yaml
tablets_mode_for_new_keyspaces: enabled   # enabled (default in 2025.1+), disabled
```

```cql
-- Create keyspace with tablets explicitly
CREATE KEYSPACE my_ks WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'dc1': 3
} AND tablets = {'enabled': true, 'initial': 128};

-- initial = starting number of tablets (auto-adjusted via split/merge)
```

## Raft Consensus and Strongly Consistent Topology

### Raft Groups in ScyllaDB

Starting with 2025.1, ScyllaDB uses Raft consensus for metadata operations:

1. **Schema Raft group** -- All schema changes (CREATE TABLE, ALTER, DROP) go through Raft consensus. No more schema disagreements via gossip.
2. **Topology Raft group** -- Node join, decommission, removenode are sequenced through Raft. Eliminates split-brain during topology changes.
3. **Auth Raft group** -- RBAC operations (CREATE ROLE, GRANT) are strongly consistent. No need to repair system_auth.
4. **Service Level Raft group** -- Workload prioritization settings are consistent across nodes.

### Topology Operations Under Raft

```
Before Raft (legacy gossip-based):
  Node A starts decommission
  Node B starts decommission simultaneously
  --> Race condition, potential data loss

After Raft (2025.1+):
  Node A requests decommission via Raft
  Raft leader serializes the operation
  Node B's decommission request queued
  --> Operations execute sequentially, safely
```

## Gossip Protocol

ScyllaDB uses the same gossip protocol as Cassandra for peer discovery and failure detection:

- **Gossip round:** Every 1 second, each node sends gossip to 1-3 peers
- **State exchanged:** Node status, load, schema version (legacy), tokens, DC/rack
- **Phi accrual failure detector:** Adaptive failure detection that adjusts sensitivity based on observed latency distribution
  - `phi_convict_threshold` in scylla.yaml (default 8, increase to 12 for cross-DC)
- **Seed nodes:** Initial contact points for gossip. Seeds do not have special runtime behavior after bootstrap.

**Note:** With Raft-based topology (2025.1+), gossip is still used for failure detection and health monitoring, but topology changes are no longer gossip-based.

## Hinted Handoff

When a write's target replica is unavailable:
1. The coordinator stores a **hint** (the write mutation + target node info)
2. Hints are stored per-shard in the coordinator's hints directory
3. When the target node comes back, hints are replayed in order
4. Hints expire after `max_hint_window_in_ms` (default 3 hours)

```yaml
# scylla.yaml
hinted_handoff_enabled: true
max_hint_window_in_ms: 10800000  # 3 hours
```

**Difference from Cassandra:** In ScyllaDB, hints are stored per-shard and replayed per-shard, which means hint replay does not create cross-shard contention.

## Repair

Repair ensures all replicas agree on the data. ScyllaDB supports row-level repair:

### Repair Types

- **Full repair** -- Compares all data across replicas. Most thorough but heaviest.
- **Incremental repair** -- Only repairs data written since the last repair. Lighter but requires tracking.
- **Row-level repair** -- ScyllaDB repairs at row granularity (not token-range-level). More efficient than Cassandra's legacy repair.

### Repair Mechanism

1. Build a **Merkle tree** (hash tree) of partition data per token range
2. Exchange Merkle trees between replicas
3. Identify differing branches (disagreeing data)
4. Stream only the disagreeing rows between replicas

### ScyllaDB Manager Repair

ScyllaDB Manager is the recommended way to run repairs:
- Schedules repairs across the cluster
- Throttles repair to avoid impacting production traffic
- Tracks repair progress per token range
- Resumes from where it left off if interrupted
- Parallel repair with configurable concurrency

## I/O Scheduler

### Per-Shard I/O Queues

Each shard has independent I/O queues with priority-based scheduling:

```
Shard N I/O Scheduler:
  ├── Interactive reads (highest priority)
  ├── Interactive writes
  ├── Compaction reads/writes (medium priority)
  ├── Streaming reads/writes (lower priority)
  └── Maintenance I/O (lowest priority)
```

### I/O Calibration

`scylla_io_setup` (or `iotune`) runs at installation to measure disk performance:
- Measures sequential read/write throughput
- Measures random read IOPS
- Stores results in `/etc/scylla.d/io_properties.yaml` or `/etc/scylla.d/io.conf`
- ScyllaDB uses these measurements to set I/O queue depths and throttling

```yaml
# Example /etc/scylla.d/io_properties.yaml
disks:
  - mountpoint: /var/lib/scylla
    read_iops: 300000
    read_bandwidth: 2000000000    # 2 GB/s
    write_iops: 200000
    write_bandwidth: 1500000000   # 1.5 GB/s
```

### I/O Priority Classes

| Priority Class | Purpose | Default Share |
|---|---|---|
| `interactive` | CQL reads/writes | Highest |
| `compaction` | Compaction I/O | Medium |
| `streaming` | Repair/bootstrap streaming | Lower |
| `maintenance` | Hints, materialized views | Lowest |

## Scheduling Groups

Scheduling groups partition CPU time across workload types within each shard:

### Built-in Scheduling Groups

| Group | Purpose | Default Behavior |
|---|---|---|
| `main` | CQL statement processing | Highest CPU priority |
| `compaction` | Compaction CPU work | Limited to prevent starving reads |
| `streaming` | Streaming (repair, bootstrap) | Lower than compaction |
| `gossip` | Gossip protocol handling | Guaranteed minimum |
| `memtable_to_cache` | Flushing memtable to cache | Background |
| `mem_compaction` | Memory compaction (LSA) | Background |

### Workload Prioritization (Service Levels)

Service levels extend scheduling groups by allowing per-user/per-role CPU prioritization:

```
Service Level "gold" (interactive workload):
  └── Gets higher CPU shares in the statement scheduling group
  └── Timeout: 5s
  └── Workload type: interactive

Service Level "silver" (batch workload):
  └── Gets lower CPU shares
  └── Timeout: 30s
  └── Workload type: batch
```

When both "gold" and "silver" workloads compete for CPU on the same shard, "gold" gets proportionally more time.

## Failure Detection

### Phi Accrual Failure Detector

ScyllaDB uses the phi accrual failure detector (same as Cassandra):
- Maintains a sliding window of inter-arrival times for gossip heartbeats
- Computes a "phi" value representing the suspicion level
- When phi exceeds `phi_convict_threshold` (default 8), the node is marked DOWN
- Adaptive -- adjusts to actual network conditions

```yaml
# scylla.yaml
phi_convict_threshold: 8   # default; increase to 10-12 for cross-DC or high-latency networks
```

### Node State Transitions

```
UN (Up/Normal)
  ├── --> DN (Down/Normal) -- failure detected
  ├── --> UL (Up/Leaving) -- decommission started
  └── --> UJ (Up/Joining) -- bootstrap in progress (other nodes see this)

DN (Down/Normal)
  ├── --> UN -- node recovers
  └── --> Removed -- via nodetool removenode
```

## Multi-Datacenter Architecture

### Replication Configuration

```cql
CREATE KEYSPACE global_ks WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'us-east': 3,
    'eu-west': 3
};
```

### Cross-DC Communication

- Writes at `LOCAL_QUORUM` are acknowledged locally; remote DC replicas are written asynchronously
- Writes at `EACH_QUORUM` wait for quorum in every DC (higher latency)
- Gossip runs across DCs for failure detection
- Repair should be run per-DC via ScyllaDB Manager

### Snitch Configuration

```yaml
# scylla.yaml
endpoint_snitch: GossipingPropertyFileSnitch
```

```properties
# cassandra-rackdc.properties
dc=us-east
rack=rack1
prefer_local=true
```

Snitch types:
- `GossipingPropertyFileSnitch` -- Production standard. DC/rack from properties file, propagated via gossip.
- `Ec2Snitch` / `Ec2MultiRegionSnitch` -- AWS-aware. Derives DC from AWS region, rack from availability zone.
- `GoogleCloudSnitch` -- GCP-aware.
- `SimpleSnitch` -- Single-DC only. Not for production multi-DC.

## Streaming Protocol

Streaming is used for:
- **Bootstrap** -- New node joining the cluster
- **Decommission** -- Node leaving the cluster
- **Repair** -- Synchronizing replicas
- **Tablet migration** -- Moving tablets between nodes (2025.1+)

### File-Based Streaming (2025.1+)

For tablet migration, ScyllaDB uses file-based streaming:
- Entire SSTable files are transferred directly
- No deserialization/reserialization overhead
- Dramatically faster than mutation-based streaming
- Reduces CPU load during topology changes

### Streaming Throttling

```yaml
# scylla.yaml
stream_throughput_outbound_megabits_per_sec: 400   # default: 400 Mbps
```

## Cache Architecture

### Row Cache

- **Per-shard** -- Each shard has its own independent cache
- **Read-through** -- Cache populated on read miss
- **Write-through** -- Writes update cache if the row is cached
- **LRU eviction** -- Least recently used rows evicted under memory pressure
- **Partition-aware** -- Can cache partial partitions (individual rows within a partition)

### Cache vs Cassandra

| Aspect | Cassandra Row Cache | ScyllaDB Row Cache |
|---|---|---|
| Recommended | Usually disabled | Enabled by default |
| Isolation | Shared across threads | Per-shard, no contention |
| Eviction | Off-heap, GC interaction | No GC, LSA-managed |
| Effectiveness | Often counterproductive | Highly effective |
| Memory management | Fixed size, manual tuning | Dynamic, auto-managed |

### Cache-Related Metrics

```
# Prometheus metrics
scylla_cache_row_hits          -- Row cache hits
scylla_cache_row_misses        -- Row cache misses
scylla_cache_row_insertions    -- New rows inserted into cache
scylla_cache_row_evictions     -- Rows evicted from cache
scylla_cache_bytes_used        -- Current cache memory usage
scylla_cache_bytes_total       -- Total cache memory available
```

## Materialized Views

ScyllaDB supports Cassandra-compatible materialized views with caveats:

- **View updates are synchronous** within the coordinator shard
- **Base-to-view consistency** is eventual (same as Cassandra)
- **Known issues:** View updates can lag behind base table, repair of views is complex
- **Recommendation:** Use client-side denormalization with batch writes for critical paths. Use MVs for non-critical read optimization where eventual consistency is acceptable.
- **PRUNE MATERIALIZED VIEW** (ScyllaDB-specific) -- Removes orphan rows from a materialized view that no longer have corresponding base table rows.

## Heat-Weighted Load Balancing

ScyllaDB's load balancer (used by shard-aware drivers) considers:
1. **Token ownership** -- Route to the replica that owns the partition
2. **Shard ownership** -- Route to the specific shard on that replica
3. **Load** -- Prefer less-loaded nodes when multiple replicas are available
4. **Latency** -- Dynamic snitch considers recent response times

This three-level routing (node -> shard -> least loaded) minimizes latency and maximizes throughput.
