# Apache Cassandra Diagnostics Reference

## Cluster Status Commands

### nodetool status -- Cluster Overview

The most-used diagnostic command. Shows each node's state, load, ownership, and datacenter/rack placement:

```bash
nodetool status
nodetool status my_keyspace   # shows effective ownership for a keyspace
```

**Output columns:**
| Column | Meaning |
|---|---|
| Status | U=Up, D=Down |
| State | N=Normal, L=Leaving, J=Joining, M=Moving |
| Address | IP address of the node |
| Load | Data stored on the node (disk usage) |
| Tokens | Number of token ranges owned |
| Owns | Percentage of data owned (effective with keyspace specified) |
| Host ID | Unique node identifier |
| Rack | Rack assignment |

**Red flags:**
- Any node showing `DN` (Down/Normal) -- investigate immediately
- Uneven `Load` across nodes (> 2x difference) -- check token distribution
- `Owns` significantly unequal -- rebalance tokens or check num_tokens
- `UL` (Up/Leaving) or `UJ` (Up/Joining) -- topology change in progress

### nodetool ring -- Token Ring Details

```bash
nodetool ring
nodetool ring my_keyspace
```

Shows each token range, the owning node, load, and status. Use to verify:
- Token ranges are evenly distributed
- No node owns a disproportionate number of ranges
- Token assignments match expectations after topology changes

### nodetool describecluster -- Cluster Metadata

```bash
nodetool describecluster
```

**Shows:**
- Cluster name
- Snitch in use
- Dynamic snitch configuration
- **Schema versions** -- All nodes should show the same schema version. Multiple schema versions indicate a schema disagreement.

**Concerning output:**
- Multiple schema version UUIDs listed under different nodes -- Schema disagreement. Wait for gossip propagation (1-2 minutes). If persistent, restart the disagreeing node.
- `UNREACHABLE` nodes listed -- Nodes that are known but not responding to gossip

### nodetool gossipinfo -- Gossip State

```bash
nodetool gossipinfo
```

Shows the raw gossip state for every known endpoint. Each entry includes:
- `STATUS`: NORMAL, LEAVING, LEFT, REMOVING, etc.
- `LOAD`: bytes stored
- `SCHEMA`: schema version UUID
- `DC` / `RACK`: datacenter and rack
- `RELEASE_VERSION`: Cassandra version
- `TOKENS`: token ranges
- `HOST_ID`: unique identifier
- `NATIVE_TRANSPORT_ADDRESS`: CQL address
- `NET_VERSION`: inter-node protocol version
- `INTERNAL_ADDRESS_AND_PORT`: (4.0+) internal address

**When to use:**
- Debugging topology issues
- Checking why a node is not visible in `nodetool status`
- Verifying DC/rack assignment
- Checking for version mismatches during rolling upgrades

### nodetool describering -- Keyspace Token Ranges

```bash
nodetool describering my_keyspace
```

Shows all token ranges for a keyspace and which nodes are responsible for each range. Useful for understanding data placement with NetworkTopologyStrategy.

### nodetool getendpoints -- Partition Placement

```bash
nodetool getendpoints my_keyspace my_table 'partition_key_value'
```

Returns the list of nodes that hold replicas for a specific partition key. Essential for:
- Debugging read/write failures for a specific key
- Understanding data placement
- Verifying replication factor

## Node Health Commands

### nodetool info -- Node Information

```bash
nodetool info
```

**Shows:**
- Node ID, gossip active, native transport active, load, generation number
- **Uptime**
- **Heap Memory:** used/total -- watch for high usage (> 75%)
- **Off Heap Memory**
- **Key Cache:** size, capacity, hit rate -- hit rate should be > 85%
- **Row Cache:** size, capacity, hit rate
- **Counter Cache:** size, capacity, hit rate
- **Chunk Cache:** (4.0+) size and hit rate
- **Data Center / Rack**
- **Tokens**
- **Percent Repaired:** (4.0+) percentage of data that has been repaired

**Action thresholds:**
| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Key cache hit rate | > 85% | 70-85% | < 70% |
| Heap memory used | < 75% | 75-85% | > 85% |
| Percent repaired | > 90% | 50-90% | < 50% |

### nodetool version -- Cassandra Version

```bash
nodetool version
```

Returns the Cassandra version. Use during rolling upgrades to verify which version each node is running.

### nodetool statusbinary -- CQL Native Transport

```bash
nodetool statusbinary
```

Returns whether the CQL native transport is running. If `not running`, clients cannot connect via CQL.

```bash
# Re-enable native transport
nodetool enablebinary

# Disable native transport (for maintenance)
nodetool disablebinary
```

### nodetool statusgossip -- Gossip Protocol Status

```bash
nodetool statusgossip
```

Returns whether gossip is enabled. If gossip is disabled, the node cannot communicate with the cluster.

```bash
nodetool enablegossip
nodetool disablegossip    # DANGER: isolates the node from the cluster
```

### nodetool statushandoff -- Hinted Handoff Status

```bash
nodetool statushandoff
```

Returns whether hinted handoff is enabled.

```bash
nodetool enablehandoff
nodetool disablehandoff
```

### nodetool statusbackup -- Incremental Backup Status

```bash
nodetool statusbackup
```

Returns whether incremental backup is enabled.

```bash
nodetool enablebackup
nodetool disablebackup
```

## Performance Diagnostics

### nodetool tpstats -- Thread Pool Statistics

```bash
nodetool tpstats
```

Shows all thread pools and their status. This is the single most important performance diagnostic command.

**Key thread pools:**
| Pool | Purpose | What to Watch |
|---|---|---|
| `ReadStage` | Local read operations | Pending > 0 means read backlog |
| `MutationStage` | Local write operations | Pending > 0 means write backlog |
| `CounterMutationStage` | Counter operations | Pending > 0 means counter write backlog |
| `ReadRepairStage` | Read repair operations | High active count = many inconsistencies |
| `RequestResponseStage` | Coordinator response handling | Pending > 0 means coordinator backlog |
| `GossipStage` | Gossip message processing | Should never have pending tasks |
| `AntiEntropyStage` | Repair operations | Active during repair |
| `CompactionExecutor` | Compaction tasks | Pending = compaction backlog |
| `MemtableFlushWriter` | Memtable flushes | Pending = flush backlog (disk I/O slow) |
| `MemtablePostFlush` | Post-flush tasks | Pending = slow cleanup |
| `HintsDispatcher` | Hint delivery | Active = replaying hints |
| `Native-Transport-Requests` | CQL request processing | Pending = CQL backlog |
| `ViewBuildExecutor` | Materialized view updates | Active = MV building |

**Dropped messages (CRITICAL):**

Below the thread pools, `tpstats` shows dropped message counts. ANY dropped messages indicate a problem:

| Dropped Type | Meaning | Likely Cause |
|---|---|---|
| `MUTATION` | Writes dropped | Disk I/O too slow, compaction overload, GC pauses |
| `COUNTER_MUTATION` | Counter writes dropped | Same as MUTATION |
| `READ` | Reads dropped | Disk I/O slow, too many SSTables, GC pauses |
| `RANGE_SLICE` | Range scans dropped | Large scans, disk I/O |
| `REQUEST_RESPONSE` | Coordinator responses dropped | Network issues, GC pauses |
| `READ_REPAIR` | Read repairs dropped | High inconsistency volume |
| `PAGED_RANGE` | Paged range scans dropped | Large result sets |
| `HINT` | Hints dropped | Hint storage full or slow |

**Thresholds:**
- Pending > 0 for 1+ minute in any stage: investigate
- Any dropped messages in the last 5 minutes: investigate immediately
- Dropped MUTATION or READ: critical -- data loss or query failure risk

### nodetool proxyhistograms -- Coordinator Latency

```bash
nodetool proxyhistograms
```

Shows latency histograms from the coordinator perspective (includes network hops):
- **Read Latency** -- End-to-end read latency as seen by the coordinator
- **Write Latency** -- End-to-end write latency
- **Range Latency** -- Range scan latency

**Thresholds:**
| Metric | Good | Warning | Critical |
|---|---|---|---|
| Read p99 | < 10ms | 10-100ms | > 100ms |
| Write p99 | < 5ms | 5-50ms | > 50ms |
| Range p99 | < 50ms | 50-500ms | > 500ms |

### nodetool tablehistograms -- Per-Table Latency

```bash
nodetool tablehistograms my_keyspace my_table
```

Shows per-table latency, partition size, and cell count histograms:
- **Read Latency** (microseconds) -- Per-read latency on this node
- **Write Latency** (microseconds) -- Per-write latency
- **SSTables per Read** -- How many SSTables are consulted per read
- **Partition Size** (bytes) -- Distribution of partition sizes
- **Cell Count** -- Distribution of cells per partition

**Concerning values:**
- SSTables per Read > 5: compaction not keeping up or too many SSTables
- Partition Size p99 > 100MB: oversized partitions
- Cell Count p99 > 100,000: overly wide partitions
- Read Latency p99 > 50ms: investigate compaction, bloom filter, and partition sizes

### nodetool clientstats -- Client Connection Statistics

```bash
nodetool clientstats
```

Shows connected client statistics including:
- Number of connected clients
- Client request rates
- Connections by user and client address

```bash
# Enable/disable client stats collection
nodetool enableclientstats
nodetool disableclientstats
```

### nodetool toppartitions -- Hot Partition Detection (4.0+)

```bash
# Sample top partitions for 10 seconds on a specific table
nodetool toppartitions my_keyspace my_table 10000

# Sample with specific number of top entries
nodetool toppartitions my_keyspace my_table 10000 10
```

Shows the most active partitions by read and write frequency. Essential for detecting hot partitions.

**When to use:**
- Investigating uneven load across nodes
- Debugging high latency on specific tables
- Identifying partition keys that need redesign

### nodetool getsstables -- SSTable Files for a Partition

```bash
nodetool getsstables my_keyspace my_table 'partition_key_value'
```

Returns the list of SSTable files that contain data for a specific partition. Useful for:
- Investigating slow reads on a specific partition
- Understanding how data is distributed across SSTables
- Debugging compaction issues for specific data

## Compaction Diagnostics

### nodetool compactionstats -- Active Compactions

```bash
nodetool compactionstats
```

Shows:
- Currently running compaction tasks (type, keyspace, table, progress)
- Pending compaction tasks per table
- Compaction throughput

**Concerning values:**
- Pending compactions > 20: compaction is falling behind
- Pending compactions > 50: critical -- increase `compaction_throughput_mb_per_sec` or add `concurrent_compactors`
- Compaction stuck at a percentage: possible issue with large partitions or disk space

```bash
# Monitor compaction progress continuously
watch -n 5 'nodetool compactionstats'
```

### nodetool compactionhistory -- Past Compactions

```bash
nodetool compactionhistory
```

Shows completed compactions with:
- Keyspace and table
- Start and end time
- Number of input SSTables and bytes
- Number of output SSTables and bytes
- Compaction strategy used

**Useful analysis:**
- If output bytes >> input bytes, something is wrong (should be <= input)
- If compactions take very long (hours), partitions may be too large
- Calculate compaction throughput: output bytes / (end - start time)

### nodetool listsnapshots -- Snapshot Inventory

```bash
nodetool listsnapshots
```

Shows all snapshots with size information. Snapshots consume disk space (they are hard links that prevent SSTable deletion).

**Maintenance:** Old snapshots from failed repairs or maintenance can accumulate:
```bash
# Remove a specific snapshot
nodetool clearsnapshot -t snapshot_name

# Remove ALL snapshots (caution!)
nodetool clearsnapshot
```

### nodetool setcompactionthroughput -- Adjust Compaction Throttle

```bash
# Get current throughput limit
nodetool getcompactionthroughput

# Increase throughput (MB/s) to catch up on compaction backlog
nodetool setcompactionthroughput 128

# Unlimited (for emergency catch-up; will impact foreground operations)
nodetool setcompactionthroughput 0
```

### nodetool stop -- Stop Specific Compaction Types

```bash
# Stop all compaction
nodetool stop COMPACTION

# Stop only cleanup compaction
nodetool stop CLEANUP

# Stop only scrub
nodetool stop SCRUB

# Stop only index build
nodetool stop INDEX_BUILD

# Stop only validation (repair Merkle tree building)
nodetool stop VALIDATION
```

**When to use:** If compaction is overwhelming the node and causing read/write timeouts, stop it temporarily, then increase throughput limits.

### nodetool enableautocompaction / disableautocompaction

```bash
# Disable auto-compaction for a table (during bulk load)
nodetool disableautocompaction my_keyspace my_table

# Re-enable
nodetool enableautocompaction my_keyspace my_table

# Force compaction (manually trigger)
nodetool compact my_keyspace my_table
```

## Repair Diagnostics

### nodetool repair -- Run Repair

```bash
# Repair all keyspaces (NOT recommended -- too broad)
nodetool repair

# Repair primary ranges only (RECOMMENDED for scheduled repair)
nodetool repair -pr my_keyspace

# Repair specific table
nodetool repair -pr my_keyspace my_table

# Parallel repair (faster but more resource-intensive)
nodetool repair -par my_keyspace

# Sequential repair (one range at a time -- safer)
nodetool repair -seq my_keyspace

# Full repair (ignore incremental status; rebuild all Merkle trees)
nodetool repair --full my_keyspace

# DC-local repair (only repair within local datacenter)
nodetool repair -local my_keyspace

# Subrange repair (specific token range)
nodetool repair -st -9223372036854775808 -et -4611686018427387904 my_keyspace

# Repair only system tables
nodetool repair system

# Paxos-only repair (4.0+; repairs only LWT state)
nodetool repair --paxos-only my_keyspace

# Track repair progress with trace
nodetool repair -pr -trace my_keyspace
```

### nodetool repair_admin -- Repair Session Management (4.0+)

```bash
# List active repair sessions
nodetool repair_admin list

# Cancel a specific repair session
nodetool repair_admin cancel <session_id>
```

### nodetool netstats -- Network and Streaming Status

```bash
nodetool netstats
```

Shows:
- **Active streaming sessions** (repair, bootstrap, decommission)
  - Files sent/received, bytes transferred, progress
- **Read/write command activity**
  - Pending commands (commands waiting for response from remote nodes)
  - Completed commands
  - Dropped commands

**Concerning values:**
- Large number of pending read/write commands: remote nodes are slow or unreachable
- Dropped commands: network issues or remote node overload
- Very slow streaming progress: disk I/O or network bottleneck

### nodetool getstreams -- Detailed Stream Info (4.0+)

```bash
nodetool getstreams
```

Detailed streaming information including:
- Stream plan ID
- Peers involved
- Files and bytes streaming
- Per-table streaming progress

## Memory and Cache Diagnostics

### nodetool gcstats -- Garbage Collection Statistics

```bash
nodetool gcstats
```

Shows GC statistics since the last `nodetool gcstats` call:
- **Interval (ms):** Time since last collection
- **Max GC Elapsed (ms):** Longest GC pause -- THIS IS THE CRITICAL METRIC
- **Total GC Elapsed (ms):** Total time spent in GC
- **Collections:** Number of GC events
- **Reclaimed (MB):** Memory reclaimed

**Thresholds:**
| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Max GC pause | < 200ms | 200-500ms | > 500ms |
| GC frequency | < 10/min | 10-30/min | > 30/min |
| Reclaimed per collection | Varies | Near-zero reclaim | Heap full, cannot reclaim |

**If GC pauses are high:**
1. Check heap sizing (not too large, not too small)
2. Review GC algorithm (G1GC recommended)
3. Look for large partition reads (cause heap pressure)
4. Check memtable memory settings
5. Review off-heap usage (bloom filters, index summaries)

### nodetool tablestats (cfstats) -- Table Statistics

```bash
# All tables
nodetool tablestats

# Specific keyspace
nodetool tablestats my_keyspace

# Specific table
nodetool tablestats my_keyspace.my_table

# Human-readable sizes
nodetool tablestats -H my_keyspace.my_table
```

**Key metrics:**
| Metric | Meaning | Action Threshold |
|---|---|---|
| `SSTable count` | Number of SSTables for this table | > 30 for LCS L0, > 50 for STCS |
| `Space used (live)` | Disk space for live data | Monitor for growth |
| `Space used (total)` | Including snapshots | If >> live, old snapshots accumulating |
| `Number of partitions (estimate)` | Estimated partition count | For capacity planning |
| `Memtable cell count` | Cells in the active memtable | High = large memtable, may need flush |
| `Memtable data size` | Bytes in the active memtable | Approaching flush threshold? |
| `Memtable switch count` | Number of memtable flushes | Frequent flushes = high write volume |
| `Local read count` | Total reads since last restart | Traffic analysis |
| `Local read latency` | Average local read latency (ms) | > 5ms: investigate |
| `Local write count` | Total writes since last restart | Traffic analysis |
| `Local write latency` | Average local write latency (ms) | > 1ms: investigate |
| `Pending flushes` | Memtables waiting to flush | > 0 sustained: disk I/O bottleneck |
| `Bloom filter false positives` | Wasted disk reads | High = increase bloom filter size |
| `Bloom filter false ratio` | FP rate | > bloom_filter_fp_chance: check |
| `Bloom filter space used` | Memory for bloom filters | Part of off-heap budget |
| `Compacted partition minimum bytes` | Smallest partition | Partition size analysis |
| `Compacted partition maximum bytes` | Largest partition | > 100MB: redesign data model |
| `Compacted partition mean bytes` | Average partition size | Target < 10MB |
| `Average live cells per slice (last five minutes)` | Cells read per query | High = wide partitions |
| `Maximum live cells per slice (last five minutes)` | Max cells per query | > 10K: investigate |
| `Average tombstones per slice (last five minutes)` | Tombstones scanned per read | > 100: tombstone problem |
| `Maximum tombstones per slice (last five minutes)` | Max tombstones per read | > 1000: critical |
| `Dropped Mutations` | Writes dropped for this table | Any: investigate immediately |

### nodetool info -- Cache Statistics

```bash
nodetool info
```

Includes cache hit rate information:
- **Key Cache:** Caches partition index positions. Hit rate should be > 85%.
- **Row Cache:** Caches entire rows. Usually disabled (0 by default).
- **Counter Cache:** Caches counter values. Hit rate should be > 50%.
- **Chunk Cache (4.0+):** Caches uncompressed SSTable chunks.

```bash
# Invalidate key cache
nodetool invalidatekeycache

# Invalidate row cache
nodetool invalidaterowcache

# Invalidate counter cache
nodetool invalidatecountercache

# Set key cache capacity at runtime
nodetool setcachecapacity <key_cache_capacity> <row_cache_capacity> <counter_cache_capacity>
```

### nodetool sjk -- JVM Diagnostics (4.0+)

```bash
# GC analysis
nodetool sjk gc

# Thread dump
nodetool sjk ttop

# Heap histogram (top objects)
nodetool sjk hh

# Memory pool usage
nodetool sjk mx -b java.lang:type=Memory -f HeapMemoryUsage
```

## Token Ring and Topology

### nodetool ring -- Full Token Ring

```bash
nodetool ring
nodetool ring my_keyspace
```

Shows every token range, owning node, and load. For clusters with vnodes (16-256 tokens per node), this output can be very large.

### nodetool getendpoints -- Find Partition Replicas

```bash
nodetool getendpoints my_keyspace my_table 'my_partition_key'
```

Returns which nodes hold replicas of a specific partition. Essential for debugging routing and consistency issues.

### nodetool gettraceprobability / settraceprobability

```bash
# Get current tracing probability
nodetool gettraceprobability

# Set tracing probability (0.0-1.0; 0.01 = 1% of queries)
nodetool settraceprobability 0.01
```

Random tracing allows sampling query paths in production without enabling full tracing.

## Schema Diagnostics

### nodetool describecluster -- Schema Agreement

```bash
nodetool describecluster
```

The `Schema versions` section shows which nodes have which schema version. All nodes should agree:

```
Schema versions:
    e84b6a60-24e4-30ad-a07c-dc4bf3a94c94: [10.0.0.1, 10.0.0.2, 10.0.0.3]
```

**Multiple versions = schema disagreement:**
```
Schema versions:
    e84b6a60-24e4-30ad-a07c-dc4bf3a94c94: [10.0.0.1, 10.0.0.2]
    a12b3c4d-5678-90ab-cdef-1234567890ab: [10.0.0.3]
    UNREACHABLE: [10.0.0.4]
```

**Resolution:**
1. Wait 1-2 minutes for gossip propagation
2. If persistent, run `nodetool resetlocalschema` on the disagreeing node (forces schema pull from peers)
3. If still disagreeing, restart the node
4. If UNREACHABLE nodes cause disagreement, fix the connectivity issue first

### cqlsh DESCRIBE Commands

```sql
-- List all keyspaces
DESCRIBE KEYSPACES;

-- Describe a keyspace (shows CREATE KEYSPACE statement)
DESCRIBE KEYSPACE my_keyspace;

-- List all tables in a keyspace
DESCRIBE TABLES;

-- Describe a table (shows CREATE TABLE with all options)
DESCRIBE TABLE my_keyspace.my_table;

-- Describe all materialized views
DESCRIBE MATERIALIZED VIEWS;

-- Describe a specific materialized view
DESCRIBE MATERIALIZED VIEW my_keyspace.my_view;

-- Describe all user-defined types
DESCRIBE TYPES;

-- Describe all user-defined functions
DESCRIBE FUNCTIONS;

-- Describe all user-defined aggregates
DESCRIBE AGGREGATES;

-- Describe the entire cluster schema (for backup)
DESCRIBE FULL SCHEMA;

-- Describe only a specific table with full schema
DESCRIBE TABLE my_keyspace.my_table;
```

### nodetool resetlocalschema -- Force Schema Reload

```bash
nodetool resetlocalschema
```

Drops all local schema information and refetches from a peer. Use when a node has a persistent schema disagreement.

**Warning:** This causes a brief period where the node has no schema. Connections may fail during this window.

## CQL Tracing

### Session-Level Tracing

```sql
-- Enable tracing in cqlsh
TRACING ON;

-- Run a query (trace output follows)
SELECT * FROM my_keyspace.my_table WHERE id = 'abc123';

-- Disable tracing
TRACING OFF;
```

**Trace output shows each step of the read/write path with timestamps:**
- Coordinator receives request
- Preparing statement
- Sending request to replicas
- Bloom filter checks (per SSTable)
- Index lookups
- Data reads
- Merging results
- Returning response

**What to look for:**
- Large time gaps between steps (slow disk I/O or GC pause)
- Many bloom filter hits (too many SSTables)
- "Read N live rows and M tombstone cells" (tombstone problem)
- Slow response from specific replicas (hardware or network issue)

### System Traces Tables

```sql
-- Query recent trace sessions
SELECT * FROM system_traces.sessions
WHERE session_id IN (SELECT session_id FROM system_traces.sessions LIMIT 10);

-- Get all events for a specific trace session
SELECT activity, source, source_elapsed, thread
FROM system_traces.events
WHERE session_id = <trace_session_uuid>
ORDER BY event_id;

-- Find slow traces (sessions with high duration)
SELECT session_id, command, duration, started_at
FROM system_traces.sessions
WHERE duration > 50000  -- microseconds
ALLOW FILTERING;

-- Clean up old traces
TRUNCATE system_traces.sessions;
TRUNCATE system_traces.events;
```

**Trace TTL:** By default, traces are stored with a 24-hour TTL. Adjust with:
```sql
-- In cqlsh
TRACING ON;
CONSISTENCY LOCAL_QUORUM;
-- traces will have default TTL

-- To keep traces longer, insert into system_traces manually
```

## System Table Queries

### system.local -- Node Configuration

```sql
-- Current node info
SELECT cluster_name, data_center, rack, release_version,
       cql_version, native_protocol_version, listen_address, rpc_address,
       schema_version, host_id, tokens
FROM system.local;
```

### system.peers -- Other Nodes

```sql
-- All known peer nodes
SELECT peer, data_center, rack, release_version, schema_version,
       host_id, preferred_ip, rpc_address, tokens
FROM system.peers;

-- (4.0+) system.peers_v2 with additional fields
SELECT peer, peer_port, data_center, rack, release_version,
       schema_version, host_id, native_address, native_port, tokens
FROM system.peers_v2;
```

### system_schema -- Schema Metadata

```sql
-- All keyspaces
SELECT * FROM system_schema.keyspaces;

-- All tables in a keyspace
SELECT * FROM system_schema.tables WHERE keyspace_name = 'my_keyspace';

-- All columns for a table
SELECT * FROM system_schema.columns
WHERE keyspace_name = 'my_keyspace' AND table_name = 'my_table';

-- All indexes
SELECT * FROM system_schema.indexes WHERE keyspace_name = 'my_keyspace';

-- All user-defined types
SELECT * FROM system_schema.types WHERE keyspace_name = 'my_keyspace';

-- All materialized views
SELECT * FROM system_schema.views WHERE keyspace_name = 'my_keyspace';

-- All user-defined functions
SELECT * FROM system_schema.functions WHERE keyspace_name = 'my_keyspace';

-- All user-defined aggregates
SELECT * FROM system_schema.aggregates WHERE keyspace_name = 'my_keyspace';
```

### system.size_estimates -- Partition Estimates

```sql
-- Estimated data size per token range
SELECT keyspace_name, table_name, range_start, range_end,
       mean_partition_size, partitions_count
FROM system.size_estimates
WHERE keyspace_name = 'my_keyspace' AND table_name = 'my_table';

-- Total estimated partitions for a table
SELECT SUM(partitions_count) AS total_partitions
FROM system.size_estimates
WHERE keyspace_name = 'my_keyspace' AND table_name = 'my_table';
```

### system.sstable_activity -- SSTable Activity (4.0+)

```sql
SELECT * FROM system.sstable_activity;
```

Shows read/write activity per SSTable, useful for identifying hot SSTables.

### system.batches -- Pending Batches

```sql
SELECT * FROM system.batches;
```

Shows pending batch log entries (for cross-partition batches). Entries here indicate unfinished batches.

### system.paxos -- LWT State

```sql
-- Check Paxos state for a specific partition
SELECT * FROM system.paxos
WHERE row_key = 0x<partition_key_hex> AND cf_id = <table_uuid>;

-- Paxos table size (should not grow excessively)
SELECT COUNT(*) FROM system.paxos;  -- May timeout if large
```

### system.prepared_statements -- Prepared Statements

```sql
SELECT * FROM system.prepared_statements;
```

Shows all prepared statements cached on this node.

### system.built_views -- Materialized View Build Status

```sql
SELECT * FROM system.built_views;
```

Shows the build status of materialized views. Incomplete entries indicate views that are still building.

## SSTable Tools

### sstablemetadata -- SSTable Metadata

```bash
sstablemetadata /var/lib/cassandra/data/my_keyspace/my_table-<id>/<sstable>-Data.db
```

Shows detailed SSTable metadata:
- Min/max timestamps
- Min/max partition keys
- SSTable level (for LCS)
- Compression ratio
- **Estimated partition count**
- **Estimated tombstone drop times** -- When tombstones become eligible for purging
- Estimated droppable tombstones
- Bloom filter FP chance
- Total rows and cells

**When to use:**
- Investigating why tombstones are not being purged
- Understanding partition size distribution
- Checking compression effectiveness
- Debugging compaction issues

### sstabledump -- SSTable Content Dump

```bash
# Dump entire SSTable as JSON
sstabledump /var/lib/cassandra/data/my_keyspace/my_table-<id>/<sstable>-Data.db

# Dump specific partition
sstabledump -k 'partition_key_value' /path/to/<sstable>-Data.db

# Dump with full column details
sstabledump -d /path/to/<sstable>-Data.db
```

**When to use:**
- Investigating data corruption
- Understanding what data is stored in a specific SSTable
- Debugging tombstone issues (see deletion markers in output)
- Forensic analysis of specific partitions

**Warning:** sstabledump reads the entire SSTable from disk. Do not run on large SSTables in production during peak hours.

### sstableutil -- List SSTable Components

```bash
sstableutil my_keyspace my_table
```

Lists all SSTable component files for a table with their types:
- Data, Index, Filter, CompressionInfo, Statistics, Summary, TOC, Digest, CRC

### sstableexpiredblockers -- Tombstone Expiry Blockers

```bash
sstableexpiredblockers my_keyspace my_table
```

Shows which SSTables are preventing tombstones from being purged. An SSTable with data older than gc_grace_seconds that overlaps with an SSTable containing tombstones blocks tombstone purging.

**When to use:**
- Disk space not being reclaimed despite TTL expiration
- Tombstone warnings in logs
- Compaction not reducing SSTable count

### sstablelevelreset -- Reset LCS Levels

```bash
sstablelevelreset my_keyspace my_table
```

Resets all SSTables to level 0 in LCS. Useful after importing SSTables or switching compaction strategies.

### sstableofflinerelevel -- Offline LCS Re-leveling

```bash
sstableofflinerelevel my_keyspace my_table
```

Re-assigns SSTable levels for LCS without running compaction. Must be run offline (node stopped).

### sstablerepairedset -- Mark SSTables as Repaired/Unrepaired

```bash
# Mark SSTables as repaired
sstablerepairedset --really-set --is-repaired /path/to/<sstable>-Data.db

# Mark SSTables as unrepaired
sstablerepairedset --really-set --is-unrepaired /path/to/<sstable>-Data.db
```

### sstablescrub -- Offline SSTable Scrub

```bash
# Scrub corrupted SSTables (node must be stopped)
sstablescrub my_keyspace my_table
```

### sstableverify -- Verify SSTable Integrity

```bash
sstableverify my_keyspace my_table
```

Checks SSTable checksums and data integrity without modifying the files.

## Log Analysis

### nodetool getlogginglevel -- View Logging Levels

```bash
nodetool getlogginglevel
```

Shows logging level for all loggers.

### nodetool setlogginglevel -- Change Logging Level at Runtime

```bash
# Enable debug logging for compaction
nodetool setlogginglevel org.apache.cassandra.db.compaction DEBUG

# Enable debug logging for gossip
nodetool setlogginglevel org.apache.cassandra.gms DEBUG

# Enable debug logging for streaming
nodetool setlogginglevel org.apache.cassandra.streaming DEBUG

# Enable debug logging for repair
nodetool setlogginglevel org.apache.cassandra.repair DEBUG

# Enable debug logging for read/write paths
nodetool setlogginglevel org.apache.cassandra.db DEBUG

# Enable debug logging for CQL
nodetool setlogginglevel org.apache.cassandra.cql3 DEBUG

# Enable debug logging for authentication
nodetool setlogginglevel org.apache.cassandra.auth DEBUG

# Enable debug logging for hints
nodetool setlogginglevel org.apache.cassandra.hints DEBUG

# Reset all loggers to default
nodetool setlogginglevel root INFO
```

### Key Log Patterns

**Compaction messages:**
```
# Normal compaction completed
INFO  [CompactionExecutor:N] Compacted (SizeTiered) N sstables to [...] to level=0. N bytes to N (~N% of original)

# Compaction too many SSTables warning
WARN  Compacting large partition my_keyspace/my_table:my_key (N bytes)

# Compaction falling behind
WARN  Compaction rate N is not keeping up with write rate N
```

**Tombstone warnings:**
```
# Read scanned too many tombstones
WARN  Read N live rows and N tombstone cells for query SELECT ... (see tombstone_warn_threshold)

# Tombstone failure
ERROR Read N live rows and N tombstone cells for query SELECT ... (see tombstone_failure_threshold)
```

**Timeout messages:**
```
# Read timeout
ERROR Read timeout: N received, N required
WARN  Read from /10.0.0.2 timed out
INFO  Operation timed out - received only N responses.

# Write timeout
ERROR Write timeout: N received, N required
WARN  Write to /10.0.0.3 timed out
```

**GC pause warnings:**
```
# GC pause exceeded threshold
WARN  GC for ParNew: N ms for N collections, N used; max is N

# Severe GC pause
WARN  GC Paused for N ms - this is very likely a problem
INFO  GC for G1 Young Generation: N ms for N collections
```

**Gossip/topology messages:**
```
# Node down detected
INFO  InetAddress /10.0.0.4 is now DOWN
WARN  Node /10.0.0.4 has been detected as DOWN

# Node up detected
INFO  InetAddress /10.0.0.4 is now UP

# Schema disagreement
WARN  Schema version mismatch between nodes
```

**Hint messages:**
```
# Hints being stored (node is down)
INFO  Created a new hints file: /var/lib/cassandra/hints/...
WARN  Storing hints for endpoint /10.0.0.4

# Hints replay
INFO  Finished hinted handoff of N bytes to /10.0.0.4
```

**Disk messages:**
```
# Disk space warning
WARN  Not enough disk space for compaction. Estimated N bytes required

# Commit log full
WARN  Out of space in commitlog directory
ERROR Commit log allocator ran out of space
```

## JMX Metrics Reference

### Key JMX Beans

Access via `nodetool sjk mx` (4.0+) or a JMX client (JConsole, VisualVM, jmxterm):

```bash
# Or directly via JMX on port 7199

# Read latency (per table)
org.apache.cassandra.metrics:type=Table,keyspace=my_keyspace,scope=my_table,name=ReadLatency

# Write latency (per table)
org.apache.cassandra.metrics:type=Table,keyspace=my_keyspace,scope=my_table,name=WriteLatency

# Coordinator read latency (all tables)
org.apache.cassandra.metrics:type=ClientRequest,scope=Read,name=Latency

# Coordinator write latency (all tables)
org.apache.cassandra.metrics:type=ClientRequest,scope=Write,name=Latency

# Read/write timeouts
org.apache.cassandra.metrics:type=ClientRequest,scope=Read,name=Timeouts
org.apache.cassandra.metrics:type=ClientRequest,scope=Write,name=Timeouts

# Read/write unavailables (not enough replicas)
org.apache.cassandra.metrics:type=ClientRequest,scope=Read,name=Unavailables
org.apache.cassandra.metrics:type=ClientRequest,scope=Write,name=Unavailables

# Pending compaction tasks
org.apache.cassandra.metrics:type=Compaction,name=PendingTasks

# Total compaction bytes compacted
org.apache.cassandra.metrics:type=Compaction,name=BytesCompacted

# Live SSTable count (per table)
org.apache.cassandra.metrics:type=Table,keyspace=my_keyspace,scope=my_table,name=LiveSSTableCount

# Pending flushes
org.apache.cassandra.metrics:type=Table,keyspace=my_keyspace,scope=my_table,name=PendingFlushes

# Bloom filter false positive rate (per table)
org.apache.cassandra.metrics:type=Table,keyspace=my_keyspace,scope=my_table,name=BloomFilterFalseRatio

# Tombstone scanned per read (per table)
org.apache.cassandra.metrics:type=Table,keyspace=my_keyspace,scope=my_table,name=TombstoneScannedHistogram

# SSTables per read (per table)
org.apache.cassandra.metrics:type=Table,keyspace=my_keyspace,scope=my_table,name=SSTablesPerReadHistogram

# Key cache hit rate
org.apache.cassandra.metrics:type=Cache,scope=KeyCache,name=HitRate

# Thread pool metrics
org.apache.cassandra.metrics:type=ThreadPools,path=request,scope=ReadStage,name=PendingTasks
org.apache.cassandra.metrics:type=ThreadPools,path=request,scope=MutationStage,name=PendingTasks
org.apache.cassandra.metrics:type=ThreadPools,path=internal,scope=CompactionExecutor,name=PendingTasks

# Dropped messages
org.apache.cassandra.metrics:type=DroppedMessage,scope=MUTATION,name=Dropped
org.apache.cassandra.metrics:type=DroppedMessage,scope=READ,name=Dropped

# Storage load
org.apache.cassandra.metrics:type=Storage,name=Load

# Hints in progress
org.apache.cassandra.metrics:type=Storage,name=TotalHintsInProgress
org.apache.cassandra.metrics:type=Storage,name=TotalHints

# Client connections
org.apache.cassandra.metrics:type=Client,name=connectedNativeClients
```

## Troubleshooting Playbooks

### Playbook: Tombstone Storm

**Symptoms:**
- Slow reads, read timeouts
- Log warnings: "Read N live rows and N tombstone cells"
- `tablestats` shows high "Average tombstones per slice"

**Diagnosis:**
```bash
# 1. Identify affected table
nodetool tablestats -H my_keyspace | grep -A 5 "tombstone"

# 2. Check tombstone counts per SSTable
sstablemetadata /var/lib/cassandra/data/my_keyspace/my_table-<id>/*-Data.db | grep -E "tombstone|droppable"

# 3. Check what is blocking tombstone compaction
sstableexpiredblockers my_keyspace my_table

# 4. Trace a slow query
TRACING ON;
SELECT * FROM my_keyspace.my_table WHERE ...;

# 5. Check gc_grace_seconds
SELECT * FROM system_schema.tables WHERE keyspace_name = 'my_keyspace' AND table_name = 'my_table';
```

**Resolution:**
1. Run repair to ensure all replicas have tombstones: `nodetool repair -pr my_keyspace my_table`
2. Force compaction to purge tombstones: `nodetool compact my_keyspace my_table`
3. Consider reducing `gc_grace_seconds` (but keep above repair interval)
4. Redesign data model to avoid deletes (use TWCS with TTL instead)
5. If emergency: temporarily increase `tombstone_failure_threshold`

### Playbook: Compaction Falling Behind

**Symptoms:**
- Increasing pending compaction tasks (`nodetool compactionstats`)
- Increasing SSTable count (`nodetool tablestats`)
- Degrading read performance
- Disk space growing faster than expected

**Diagnosis:**
```bash
# 1. Check pending compactions
nodetool compactionstats

# 2. Check SSTable counts per table
nodetool tablestats -H my_keyspace | grep -E "SSTable count|Table:"

# 3. Check compaction throughput limit
nodetool getcompactionthroughput

# 4. Check if large partitions are slowing compaction
grep "Compacting large partition" /var/log/cassandra/system.log

# 5. Check disk I/O (system level)
iostat -x 5
```

**Resolution:**
1. Increase compaction throughput: `nodetool setcompactionthroughput 256`
2. Increase concurrent compactors in cassandra.yaml: `concurrent_compactors: 8`
3. If STCS with large SSTables, consider switching to LCS
4. Add more disk capacity or nodes
5. Check for oversized partitions causing slow compaction

### Playbook: Repair Failures

**Symptoms:**
- Repair commands fail with errors
- Log messages about repair failures or timeouts
- `nodetool netstats` shows failed streaming

**Diagnosis:**
```bash
# 1. Check for active repairs
nodetool netstats

# 2. Check thread pools for repair-related pools
nodetool tpstats | grep -E "AntiEntropy|Validation|Repair"

# 3. Check for concurrent repairs (should not overlap)
nodetool repair_admin list  # 4.0+

# 4. Check disk space (repairs need space for Merkle trees and streaming)
df -h /var/lib/cassandra

# 5. Check logs for repair errors
grep -i "repair" /var/log/cassandra/system.log | tail -50
```

**Resolution:**
1. Ensure only one repair runs at a time per node
2. Use `nodetool repair -pr` (primary ranges only) to reduce scope
3. Use subrange repair for smaller chunks: `nodetool repair -st <start> -et <end>`
4. Increase `repair_session_max_tree_depth` if Merkle trees are too large
5. Ensure enough disk space (at least 10% free)
6. Check for and resolve any underlying node health issues first

### Playbook: Gossip Issues

**Symptoms:**
- Nodes showing as DN (Down) despite being running
- Schema disagreements
- Inconsistent `nodetool status` output across nodes
- "Cannot achieve consistency level" errors

**Diagnosis:**
```bash
# 1. Compare status from multiple nodes
nodetool status  # Run on each node and compare

# 2. Check gossip state
nodetool gossipinfo | grep -E "STATUS|SCHEMA|RELEASE_VERSION"

# 3. Check for schema disagreements
nodetool describecluster

# 4. Check if gossip is enabled
nodetool statusgossip

# 5. Check network connectivity between nodes
ping <other_node_ip>
telnet <other_node_ip> 7000  # inter-node port
telnet <other_node_ip> 9042  # CQL port

# 6. Check for firewall rules
iptables -L -n | grep -E "7000|7001|9042"
```

**Resolution:**
1. If gossip is disabled: `nodetool enablegossip`
2. For schema disagreement: `nodetool resetlocalschema` on the disagreeing node
3. For persistent issues: restart the problematic node
4. Check firewall rules between nodes
5. In cloud environments: increase `phi_convict_threshold` to 10-12
6. Verify all nodes have consistent `cassandra.yaml` (especially seed list)

### Playbook: Read/Write Timeouts

**Symptoms:**
- Client receiving ReadTimeoutException or WriteTimeoutException
- Log messages: "Operation timed out"
- Intermittent or sustained timeout errors

**Diagnosis:**
```bash
# 1. Check thread pools for backlog
nodetool tpstats

# 2. Check for dropped messages
nodetool tpstats | grep -v "^$" | grep -v "^Pool" | awk '$4 > 0 || $6 > 0'

# 3. Check GC pauses
nodetool gcstats

# 4. Check coordinator latencies
nodetool proxyhistograms

# 5. Check per-table latencies
nodetool tablehistograms my_keyspace my_table

# 6. Check for compaction backlog
nodetool compactionstats

# 7. Check system I/O
iostat -x 5

# 8. Check for network issues
nodetool netstats
```

**Resolution for read timeouts:**
1. Check SSTables per read -- if high, compaction is behind
2. Check tombstone counts -- if high, see tombstone storm playbook
3. Check partition sizes -- if large, redesign data model
4. Increase `read_request_timeout_in_ms` as temporary measure
5. Check bloom filter effectiveness (`tablestats` false positive ratio)
6. Check if specific nodes are slow (hardware issue)

**Resolution for write timeouts:**
1. Check commit log disk I/O (separate disk recommended)
2. Check for GC pauses (common cause)
3. Check hinted handoff (are many nodes storing hints?)
4. Increase `write_request_timeout_in_ms` as temporary measure
5. Check for oversized batches (break into smaller writes)
6. Check concurrent_writes setting

### Playbook: GC Pauses

**Symptoms:**
- Intermittent latency spikes
- "GC Paused for N ms" warnings in logs
- Dropped messages correlated with GC events
- Node temporarily unresponsive during GC

**Diagnosis:**
```bash
# 1. Check GC statistics
nodetool gcstats

# 2. Analyze GC log
# For G1GC:
grep "GC pause" /var/log/cassandra/gc.log | tail -20

# 3. Check heap usage
nodetool info | grep "Heap Memory"

# 4. Check off-heap usage
nodetool info | grep "Off Heap"

# 5. Check for large partition reads (cause heap pressure)
nodetool tablestats | grep "Compacted partition maximum"

# 6. Check memtable sizes
nodetool tablestats | grep "Memtable"
```

**Resolution:**
1. Verify heap size is appropriate (8-16GB, never > 31GB)
2. Switch to G1GC if still on CMS
3. Look for large partition reads (redesign data model)
4. Move memtables off-heap: `memtable_allocation_type: offheap_buffers`
5. Reduce `memtable_heap_space_in_mb`
6. Consider ZGC (4.1+) for ultra-low pause times
7. Check for unnecessary large SELECT queries (use paging)

### Playbook: Node Won't Start

**Symptoms:**
- Cassandra process exits immediately after start
- system.log shows errors during startup

**Diagnosis:**
```bash
# 1. Check system log
tail -100 /var/log/cassandra/system.log

# 2. Check for common startup errors
grep -E "ERROR|FATAL|Exception" /var/log/cassandra/system.log | tail -30

# 3. Check disk space
df -h /var/lib/cassandra
df -h /var/lib/cassandra/commitlog

# 4. Check file permissions
ls -la /var/lib/cassandra/
ls -la /var/lib/cassandra/data/

# 5. Check for corrupt SSTables
grep -i "corrupt" /var/log/cassandra/system.log

# 6. Check JVM settings
cat /etc/cassandra/jvm.options

# 7. Check for port conflicts
netstat -tlnp | grep -E "7000|9042|7199"
```

**Common causes and fixes:**
| Error | Cause | Fix |
|---|---|---|
| `java.lang.OutOfMemoryError` | Heap too small or leak | Increase heap, check for bug |
| `CommitLog replay error` | Corrupt commit log | Move corrupt segments, start, repair |
| `Cannot bind to address` | Port in use | Kill conflicting process |
| `Insufficient disk space` | Disk full | Free space, clear snapshots |
| `SSTable corrupt` | Disk error, bad shutdown | `sstablescrub`, or remove and rebuild |
| `Schema mismatch` | Inconsistent schema files | `nodetool resetlocalschema` (after start) |
| `Unable to find local tokens` | system keyspace corrupt | Rebuild from backup or seed |
| `InvalidSSTableException` | Corrupt SSTable | Remove corrupt SSTable, run repair |

## Additional nodetool Commands

### Maintenance Commands

```bash
# Decommission (remove node from cluster gracefully)
nodetool decommission

# Move to a new token (rarely used with vnodes)
nodetool move <new_token>

# Remove a dead node from the cluster
nodetool removenode <host_id>

# Force remove a dead node (use as last resort)
nodetool removenode force <host_id>

# Rebuild (stream all data from other replicas)
nodetool rebuild <source_datacenter>

# Cleanup (remove data that no longer belongs to this node after topology change)
nodetool cleanup my_keyspace

# Scrub (validate and fix SSTable data)
nodetool scrub my_keyspace my_table

# Scrub with options
nodetool scrub --skip-corrupted my_keyspace my_table  # skip corrupted rows
nodetool scrub --reinsert-overflowed-ttl my_keyspace   # fix TTL overflow

# Refresh (load externally placed SSTables)
nodetool refresh my_keyspace my_table

# Drain (flush all memtables to SSTables, disable gossip and native transport)
nodetool drain
# Use before controlled shutdown to speed up restart

# Assassinate (forcefully remove a node from gossip state)
nodetool assassinate <ip_address>
# DANGER: only use if removenode fails; ensure the node is truly dead

# Import SSTables from a directory
nodetool import my_keyspace my_table /path/to/sstables  # 4.0+

# Reload SSL certificates without restart
nodetool reloadssl  # 4.0+
```

### Information Commands

```bash
# Cluster name
nodetool describecluster | head -5

# Token ownership per node
nodetool ring | head -20

# Data center of this node
nodetool info | grep "Data Center"

# Uptime
nodetool info | grep "Uptime"

# Cross-node latency (inter-node messaging)
nodetool proxyhistograms

# View endpoint to host ID mapping
nodetool status | awk '{print $1, $2, $NF}'

# Get CQL native transport address
cqlsh -e "SELECT listen_address, rpc_address FROM system.local;"

# List all keyspaces with their replication settings
cqlsh -e "SELECT keyspace_name, replication FROM system_schema.keyspaces;"
```

### Flush and Snapshot Commands

```bash
# Flush all memtables to disk
nodetool flush

# Flush specific keyspace
nodetool flush my_keyspace

# Flush specific table
nodetool flush my_keyspace my_table

# Take a snapshot
nodetool snapshot -t my_backup

# Take snapshot of specific keyspace
nodetool snapshot -t my_backup my_keyspace

# Snapshot specific table
nodetool snapshot -t my_backup -cf my_table my_keyspace

# List all snapshots
nodetool listsnapshots

# Remove a snapshot
nodetool clearsnapshot -t my_backup

# Remove all snapshots
nodetool clearsnapshot
```

### Throttling Commands

```bash
# Get/set compaction throughput (MB/s)
nodetool getcompactionthroughput
nodetool setcompactionthroughput 128

# Get/set streaming throughput (Mbps)
nodetool getstreamthroughput
nodetool setstreamthroughput 200

# Get/set inter-DC streaming throughput (Mbps)
nodetool getinterdcstreamthroughput
nodetool setinterdcstreamthroughput 100

# Get/set concurrent compactors (4.0+)
nodetool getconcurrentcompactors
nodetool setconcurrentcompactors 4

# Get/set concurrent view builders (4.0+)
nodetool getconcurrentviewbuilders
nodetool setconcurrentviewbuilders 2
```

## Quick Reference: Command-to-Diagnosis Map

| Symptom | First Commands to Run |
|---|---|
| Cluster overview | `nodetool status`, `nodetool describecluster` |
| Slow reads | `nodetool tablehistograms`, `nodetool tablestats`, `TRACING ON` |
| Slow writes | `nodetool tpstats`, `nodetool proxyhistograms`, `nodetool gcstats` |
| Dropped messages | `nodetool tpstats`, `nodetool gcstats`, `iostat -x 5` |
| High latency | `nodetool proxyhistograms`, `nodetool tablehistograms`, `nodetool tpstats` |
| Compaction issues | `nodetool compactionstats`, `nodetool tablestats`, `nodetool compactionhistory` |
| Tombstone problems | `nodetool tablestats` (tombstones/slice), `sstableexpiredblockers`, `sstablemetadata` |
| Disk space | `nodetool tablestats -H`, `nodetool listsnapshots`, `du -sh /var/lib/cassandra/data/*` |
| Schema disagreement | `nodetool describecluster`, `nodetool gossipinfo` |
| GC issues | `nodetool gcstats`, GC log analysis, `nodetool info` |
| Streaming/repair | `nodetool netstats`, `nodetool repair_admin list` |
| Node down | `nodetool status`, `nodetool gossipinfo`, system.log |
| Hot partitions | `nodetool toppartitions`, `nodetool tablehistograms` |
| Cache performance | `nodetool info` (cache hit rates), `nodetool tablestats` (bloom filter) |
| Client connections | `nodetool clientstats`, `nodetool info` |
