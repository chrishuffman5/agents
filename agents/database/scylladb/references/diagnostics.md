# ScyllaDB Diagnostics Reference

## Cluster Status Commands

### nodetool status -- Cluster Overview

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
- Uneven `Load` across nodes (> 2x difference) -- check tablet/token distribution
- `Owns` significantly unequal -- indicates data skew
- `UL` (Up/Leaving) or `UJ` (Up/Joining) -- topology change in progress

### nodetool ring -- Token Ring Details

```bash
nodetool ring
nodetool ring my_keyspace
```

Shows each token range, the owning node, load, and status. Primarily useful for vnode-based clusters. With tablets, use the REST API for tablet placement info.

### nodetool describecluster -- Cluster Metadata

```bash
nodetool describecluster
```

**Shows:** Cluster name, snitch, schema versions, Raft group status (2025.1+).

**Concerning output:**
- Multiple schema version UUIDs -- Schema disagreement. With Raft (2025.1+), this should resolve automatically. Legacy clusters: wait for gossip propagation (1-2 minutes) or restart disagreeing node.
- `UNREACHABLE` nodes listed -- Nodes known but not responding to gossip.

### nodetool gossipinfo -- Gossip State

```bash
nodetool gossipinfo
```

Shows raw gossip state for every endpoint: STATUS, LOAD, SCHEMA, DC, RACK, RELEASE_VERSION, TOKENS, HOST_ID.

**When to use:**
- Debugging topology issues
- Checking DC/rack assignment
- Verifying version during rolling upgrades
- Checking why a node is not visible in status

### nodetool describering -- Keyspace Token Ranges

```bash
nodetool describering my_keyspace
```

Returns token ranges and responsible nodes for a keyspace. Less useful with tablets (use REST API instead).

### nodetool getendpoints -- Partition Placement

```bash
nodetool getendpoints my_keyspace my_table 'partition_key_value'
```

Returns nodes holding replicas for a specific partition key.

## Node Health Commands

### nodetool info -- Node Information

```bash
nodetool info
```

**Shows:**
- Node ID, gossip active, native transport active, load
- **Uptime**
- **Memory:** Used/total (no heap/off-heap distinction -- ScyllaDB manages all memory)
- **Key Cache:** Size, capacity, hit rate (should be > 85%)
- **Data Center / Rack**
- **Percent Repaired:** Percentage of data repaired

**Action thresholds:**
| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Key cache hit rate | > 85% | 70-85% | < 70% |
| Memory used | < 85% of total | 85-95% | > 95% |
| Percent repaired | > 90% | 50-90% | < 50% |

### nodetool version -- ScyllaDB Version

```bash
nodetool version
```

Returns the ScyllaDB version (e.g., `2026.1.1-0`). Use during rolling upgrades.

### nodetool statusbinary -- CQL Native Transport

```bash
nodetool statusbinary
```

Returns whether CQL native transport is running.

```bash
# Re-enable native transport if down
nodetool enablebinary

# Disable native transport (drain first in maintenance)
nodetool disablebinary
```

### nodetool statusgossip -- Gossip Status

```bash
nodetool statusgossip
```

Returns whether gossip is active.

### nodetool statusthrift -- Thrift Status (Legacy)

```bash
nodetool statusthrift
```

Returns Thrift transport status (deprecated, usually disabled).

## Performance Diagnostics

### nodetool tablestats -- Per-Table Statistics

```bash
nodetool tablestats                          # all tables
nodetool tablestats my_keyspace              # all tables in keyspace
nodetool tablestats my_keyspace.my_table     # specific table
```

**Key metrics to examine:**
| Metric | Healthy Range | What It Means |
|---|---|---|
| SSTable count | < 20 per shard | High count = compaction falling behind |
| Space used (live) | Varies | Actual data size |
| Space used (total) | < 2x live | High ratio = many tombstones/overwritten data |
| Number of partitions | Varies | Used for partition sizing analysis |
| Maximum partition size | < 100MB | Large partitions cause latency spikes |
| Average tombstones per slice | < 100 | High = excessive deletes |
| Bloom filter false positive ratio | < 0.02 | High = increase bloom_filter_fp_chance |
| Compaction pending | 0 | > 0 = compaction backlog |
| Read latency (ms) | < 5ms (p50) | High = suboptimal data model or compaction |
| Write latency (ms) | < 1ms (p50) | High = disk bottleneck or backpressure |
| Local read count | Varies | Total reads since last restart |
| Local write count | Varies | Total writes since last restart |

### nodetool tablehistograms -- Latency Histograms

```bash
nodetool tablehistograms my_keyspace my_table
```

Shows percentile distributions for read/write latency, partition size, cell count, and SSTable count per read.

**Key histograms:**
- **Read latency:** p50, p75, p95, p99, p999 -- Compare p99 to p50 for tail latency
- **Write latency:** Same percentiles
- **Partition size:** Distribution of partition sizes -- look for outliers
- **Cell count:** Cells per partition -- high values indicate wide partitions
- **SSTables per read:** How many SSTables are consulted per read -- lower is better

### nodetool tpstats -- Thread Pool Statistics

```bash
nodetool tpstats
```

Shows per-shard task pool stats. In ScyllaDB, this shows scheduling group activity:

**Key pools to monitor:**
| Pool | What to Watch |
|---|---|
| ReadStage | Active/pending reads -- high pending = read saturation |
| MutationStage | Active/pending writes -- high pending = write saturation |
| CompactionExecutor | Active compaction tasks |
| MemtableFlushWriter | Active memtable flushes |
| GossipStage | Should be near zero pending |

**Red flag:** Non-zero `Blocked` count in any pool indicates backpressure.

### nodetool proxyhistograms -- Coordinator Latency

```bash
nodetool proxyhistograms
```

Shows latency histograms for reads, writes, and range requests as seen by the coordinator node.

### nodetool toppartitions -- Hot Partition Detection

```bash
# Monitor top 10 partitions by read/write count for 10 seconds
nodetool toppartitions my_keyspace my_table 10000
nodetool toppartitions my_keyspace my_table 10000 -s 10   # top 10 partitions
```

**When to use:** Suspected hot partition. Look for one partition dominating the read or write count.

### nodetool cfstats (alias for tablestats)

```bash
nodetool cfstats my_keyspace.my_table
```

Identical to `tablestats`. `cfstats` is the legacy name (column family stats).

## Compaction Diagnostics

### nodetool compactionstats -- Active Compactions

```bash
nodetool compactionstats
```

Shows currently running compactions: compaction type, keyspace, table, bytes compacted, total bytes, progress percentage.

**Red flags:**
- Many concurrent compactions -- CPU/disk contention
- Compactions stuck at low progress -- possible large partition or I/O bottleneck
- High `pending tasks` -- compaction falling behind writes

### nodetool compactionhistory -- Recent Compactions

```bash
nodetool compactionhistory
```

Shows completed compactions with start/end time, input/output SSTable count, and bytes.

### nodetool getcompactionthroughput -- Current Throughput Limit

```bash
nodetool getcompactionthroughput
```

Returns current compaction throughput limit in MB/s (0 = unlimited).

### nodetool setcompactionthroughput -- Adjust Throughput

```bash
nodetool setcompactionthroughput 100   # set to 100 MB/s
nodetool setcompactionthroughput 0     # unlimited
```

### nodetool compact -- Force Compaction

```bash
nodetool compact                             # all tables
nodetool compact my_keyspace                 # all tables in keyspace
nodetool compact my_keyspace my_table        # specific table
```

**Warning:** Manual compaction temporarily doubles disk usage for STCS. Use ICS to avoid this.

### nodetool stop -- Stop Compaction

```bash
nodetool stop COMPACTION
```

Stops running compaction. Use when compaction is causing excessive I/O during peak hours.

## Repair Diagnostics

### nodetool repair -- Manual Repair

```bash
# Full repair of a keyspace
nodetool repair my_keyspace

# Repair a specific table
nodetool repair my_keyspace my_table

# Repair with parallelism
nodetool repair my_keyspace --parallel

# Repair specific token range
nodetool repair my_keyspace -st <start_token> -et <end_token>

# Primary range repair only (recommended for regular maintenance)
nodetool repair my_keyspace --partitioner-range
```

**Recommended:** Use `sctool repair` (ScyllaDB Manager) instead of manual nodetool repair.

### nodetool repair_admin -- Repair Status (ScyllaDB-specific)

```bash
nodetool repair_admin list             # list all repair operations
nodetool repair_admin show <repair-id> # show specific repair details
```

## Streaming Diagnostics

### nodetool netstats -- Network Statistics

```bash
nodetool netstats
```

Shows active streaming sessions (bootstrap, repair, decommission), pending commands, and completed streams.

### nodetool getstreamthroughput -- Stream Throughput

```bash
nodetool getstreamthroughput
```

### nodetool setstreamthroughput -- Adjust Stream Throughput

```bash
nodetool setstreamthroughput 400   # 400 Mbps
```

## Memory and Cache Diagnostics

### nodetool getcachecapacity -- Cache Sizes

```bash
# ScyllaDB manages cache automatically, but you can check:
nodetool info   # shows cache sizes and hit rates
```

### nodetool invalidatekeycache -- Clear Key Cache

```bash
nodetool invalidatekeycache
```

### nodetool invalidaterowcache -- Clear Row Cache

```bash
nodetool invalidaterowcache
```

## Snapshot and Backup Diagnostics

### nodetool snapshot -- Take Snapshot

```bash
# Snapshot all keyspaces
nodetool snapshot -t my_snapshot

# Snapshot specific keyspace
nodetool snapshot -t my_snapshot my_keyspace

# Snapshot specific table
nodetool snapshot -t my_snapshot --table my_table my_keyspace
```

### nodetool listsnapshots -- List Snapshots

```bash
nodetool listsnapshots
```

### nodetool clearsnapshot -- Remove Snapshot

```bash
nodetool clearsnapshot -t my_snapshot
nodetool clearsnapshot --all   # remove all snapshots
```

## Token and Partition Diagnostics

### nodetool getendpoints -- Partition Replica Location

```bash
nodetool getendpoints my_keyspace my_table 'my_partition_key'
```

### nodetool getsstables -- SSTables for a Partition

```bash
nodetool getsstables my_keyspace my_table 'my_partition_key'
```

Returns the SSTable file paths containing data for the specified partition.

## Miscellaneous nodetool Commands

### nodetool flush -- Flush Memtables

```bash
nodetool flush                          # all tables
nodetool flush my_keyspace              # all tables in keyspace
nodetool flush my_keyspace my_table     # specific table
```

Forces memtable flush to SSTables. Use before snapshots or before stopping a node.

### nodetool drain -- Prepare for Shutdown

```bash
nodetool drain
```

Flushes all memtables, stops accepting new connections, and prepares the node for shutdown.

### nodetool decommission -- Remove Node

```bash
nodetool decommission
```

Safely removes the node from the cluster by streaming its data to other nodes.

### nodetool removenode -- Remove Dead Node

```bash
nodetool removenode <host-id>
```

Removes a node that is permanently down. Must be run from a live node.

### nodetool disableautocompaction / enableautocompaction

```bash
nodetool disableautocompaction my_keyspace my_table
nodetool enableautocompaction my_keyspace my_table
```

### nodetool setlogginglevel -- Runtime Log Level

```bash
nodetool setlogginglevel scylla DEBUG
nodetool setlogginglevel scylla.compaction DEBUG
```

### nodetool getlogginglevel

```bash
nodetool getlogginglevel
```

### nodetool settraceprobability -- CQL Tracing

```bash
nodetool settraceprobability 0.01   # trace 1% of queries
nodetool settraceprobability 0      # disable tracing
```

### nodetool gettraceprobability

```bash
nodetool gettraceprobability
```

---

## ScyllaDB REST API Diagnostics

ScyllaDB exposes a comprehensive REST API (default port 10000) that is a superset of nodetool commands. The REST API provides much more detail than nodetool.

### Accessing the REST API

```bash
# Direct curl
curl -s http://localhost:10000/<endpoint>

# Using scylla-api-client (Python CLI)
scylla-api-client <module> <operation>

# Swagger UI (when enabled)
# http://localhost:10000/ui/
```

### System Module

```bash
# Get ScyllaDB version
curl -s http://localhost:10000/system/version

# Get uptime
curl -s http://localhost:10000/system/uptime_ms

# Get all system configuration
curl -s http://localhost:10000/system/config

# Check if native transport is running
curl -s http://localhost:10000/system/native_transport

# Check if gossip is running
curl -s http://localhost:10000/system/is_gossip_running
```

### Storage Service Module

```bash
# Cluster name
curl -s http://localhost:10000/storage_service/cluster_name

# All live nodes
curl -s http://localhost:10000/storage_service/host_id

# Node tokens
curl -s http://localhost:10000/storage_service/tokens/<endpoint>

# Keyspace list
curl -s http://localhost:10000/storage_service/keyspaces

# Natural endpoints for a key
curl -s "http://localhost:10000/storage_service/natural_endpoints/my_ks?cf=my_table&key=abc"

# Data file locations
curl -s http://localhost:10000/storage_service/data_file_locations

# Commitlog location
curl -s http://localhost:10000/storage_service/commitlog

# Snapshot details
curl -s http://localhost:10000/storage_service/snapshots

# Ownership
curl -s http://localhost:10000/storage_service/ownership

# Effective ownership per keyspace
curl -s "http://localhost:10000/storage_service/ownership/my_ks"

# Schema version
curl -s http://localhost:10000/storage_service/schema_version

# Operation mode (NORMAL, JOINING, LEAVING, etc.)
curl -s http://localhost:10000/storage_service/operation_mode

# Is the node initialized?
curl -s http://localhost:10000/storage_service/is_initialized

# Get all gossip info as JSON
curl -s http://localhost:10000/storage_service/gossiper/endpoint/live

# Get unreachable nodes
curl -s http://localhost:10000/storage_service/gossiper/endpoint/down

# Compaction throughput
curl -s http://localhost:10000/storage_service/compaction_throughput

# Stream throughput
curl -s http://localhost:10000/storage_service/stream_throughput

# Force keyspace compaction
curl -s -X POST "http://localhost:10000/storage_service/keyspace_compaction/my_ks"

# Force keyspace flush
curl -s -X POST "http://localhost:10000/storage_service/keyspace_flush/my_ks"

# Decommission
curl -s -X POST http://localhost:10000/storage_service/decommission

# Remove node
curl -s -X POST "http://localhost:10000/storage_service/remove_node?host_id=<uuid>"
```

### Column Family (Table) Module

```bash
# List all tables (column families)
curl -s http://localhost:10000/column_family/

# SSTable count for a table
curl -s "http://localhost:10000/column_family/sstables/by_key/my_ks:my_table"

# Table metrics
curl -s "http://localhost:10000/column_family/metrics/read_latency/my_ks:my_table"
curl -s "http://localhost:10000/column_family/metrics/write_latency/my_ks:my_table"
curl -s "http://localhost:10000/column_family/metrics/live_disk_space_used/my_ks:my_table"
curl -s "http://localhost:10000/column_family/metrics/total_disk_space_used/my_ks:my_table"
curl -s "http://localhost:10000/column_family/metrics/live_ss_table_count/my_ks:my_table"
curl -s "http://localhost:10000/column_family/metrics/pending_compactions/my_ks:my_table"
curl -s "http://localhost:10000/column_family/metrics/bloom_filter_false_ratio/my_ks:my_table"
curl -s "http://localhost:10000/column_family/metrics/memtable_switch_count/my_ks:my_table"
curl -s "http://localhost:10000/column_family/metrics/memtable_live_data_size/my_ks:my_table"

# Compaction strategy for a table
curl -s "http://localhost:10000/column_family/compaction_strategy/my_ks:my_table"

# Compression ratio
curl -s "http://localhost:10000/column_family/compression_ratio/my_ks:my_table"

# Tombstone metrics
curl -s "http://localhost:10000/column_family/metrics/tombstone_scanned_histogram/my_ks:my_table"

# Max partition size
curl -s "http://localhost:10000/column_family/metrics/max_partition_size/my_ks:my_table"

# Mean partition size
curl -s "http://localhost:10000/column_family/metrics/mean_partition_size/my_ks:my_table"
```

### Compaction Manager Module

```bash
# Active compactions
curl -s http://localhost:10000/compaction_manager/compactions

# Pending compaction tasks
curl -s http://localhost:10000/compaction_manager/pending_tasks

# Compaction metrics
curl -s http://localhost:10000/compaction_manager/metrics/completed_tasks
curl -s http://localhost:10000/compaction_manager/metrics/total_compactions_completed
curl -s http://localhost:10000/compaction_manager/metrics/bytes_compacted

# Stop compaction
curl -s -X POST "http://localhost:10000/compaction_manager/stop_compaction?type=COMPACTION"
```

### Cache Service Module

```bash
# Row cache hit rate
curl -s http://localhost:10000/cache_service/metrics/row/hit_rate

# Row cache size
curl -s http://localhost:10000/cache_service/row_cache_size

# Key cache hit rate
curl -s http://localhost:10000/cache_service/metrics/key/hit_rate

# Invalidate caches
curl -s -X POST http://localhost:10000/cache_service/invalidate_key_cache
curl -s -X POST http://localhost:10000/cache_service/invalidate_row_cache
```

### Gossiper Module

```bash
# All known endpoints
curl -s http://localhost:10000/gossiper/endpoint/live
curl -s http://localhost:10000/gossiper/endpoint/down

# Gossip info for specific endpoint
curl -s "http://localhost:10000/gossiper/endpoint/info/<ip>"

# Generation number
curl -s "http://localhost:10000/gossiper/generation_number/<ip>"

# Heartbeat version
curl -s "http://localhost:10000/gossiper/heartbeat_version/<ip>"
```

### Failure Detector Module

```bash
# Phi values for all endpoints
curl -s http://localhost:10000/failure_detector/phi

# Simple alive/dead check
curl -s http://localhost:10000/failure_detector/simple_states

# Phi threshold
curl -s http://localhost:10000/failure_detector/phi_convict_threshold
```

### Messaging Service Module

```bash
# Pending messages per verb
curl -s http://localhost:10000/messaging_service/messages/pending

# Completed messages
curl -s http://localhost:10000/messaging_service/messages/sent

# Dropped messages (critical -- indicates overload)
curl -s http://localhost:10000/messaging_service/messages/dropped

# Version for a specific endpoint
curl -s "http://localhost:10000/messaging_service/version/<ip>"
```

### Stream Manager Module

```bash
# Active streams
curl -s http://localhost:10000/stream_manager/

# Current streams
curl -s http://localhost:10000/stream_manager/streams
```

### Hinted Handoff Module

```bash
# Pending hints
curl -s http://localhost:10000/hinted_handoff/hints

# Hints for specific endpoint
curl -s "http://localhost:10000/hinted_handoff/hints/<ip>"
```

### Commitlog Module

```bash
# Commitlog total size
curl -s http://localhost:10000/commitlog/metrics/total_commit_log_size

# Pending tasks
curl -s http://localhost:10000/commitlog/metrics/pending_tasks

# Completed tasks
curl -s http://localhost:10000/commitlog/metrics/completed_tasks
```

### Error Injection Module (Testing Only)

```bash
# Enable error injection (developer mode only)
curl -s -X POST "http://localhost:10000/v2/error_injection/injection/<name>?one_shot=true"

# Disable error injection
curl -s -X DELETE "http://localhost:10000/v2/error_injection/injection/<name>"

# List enabled injections
curl -s http://localhost:10000/v2/error_injection/injection
```

### Task Manager Module (2025.1+)

```bash
# List running tasks (topology operations, etc.)
curl -s http://localhost:10000/task_manager/list_modules

# List tasks in a module
curl -s "http://localhost:10000/task_manager/list_module_tasks/<module>"

# Get task status
curl -s "http://localhost:10000/task_manager/task_status/<task_id>"
```

---

## CQL System Table Queries

### Cluster Topology

```cql
-- All known peers (other nodes in the cluster)
SELECT peer, data_center, rack, host_id, release_version, schema_version, tokens
FROM system.peers;

-- Local node info
SELECT cluster_name, data_center, rack, host_id, release_version,
       schema_version, listen_address, rpc_address
FROM system.local;

-- Check for schema disagreements
SELECT schema_version, COUNT(*) as node_count
FROM system.peers
GROUP BY schema_version;
-- Should show only ONE schema version
```

### Keyspace and Table Metadata

```cql
-- List all keyspaces with replication
SELECT keyspace_name, replication
FROM system_schema.keyspaces;

-- List all tables in a keyspace
SELECT table_name, compaction
FROM system_schema.tables
WHERE keyspace_name = 'my_ks';

-- Table schema details
SELECT column_name, type, kind
FROM system_schema.columns
WHERE keyspace_name = 'my_ks' AND table_name = 'my_table';

-- Indexes on a table
SELECT index_name, options
FROM system_schema.indexes
WHERE keyspace_name = 'my_ks' AND table_name = 'my_table';

-- Materialized views
SELECT view_name, base_table_name
FROM system_schema.views
WHERE keyspace_name = 'my_ks';

-- User-defined types
SELECT type_name, field_names, field_types
FROM system_schema.types
WHERE keyspace_name = 'my_ks';
```

### Performance Analysis via System Tables

```cql
-- SSTable size per table per node (approximation via tablestats)
-- Use nodetool tablestats for this; no direct CQL equivalent

-- Compaction history (ScyllaDB-specific system table)
SELECT * FROM system.compaction_history LIMIT 20;

-- Large partitions detected by compaction (ScyllaDB-specific)
SELECT * FROM system.large_partitions LIMIT 20;

-- Large rows
SELECT * FROM system.large_rows LIMIT 20;

-- Large cells
SELECT * FROM system.large_cells LIMIT 20;
```

### CQL Tracing

```cql
-- Enable tracing for a session
TRACING ON;

-- Run a query (trace output shown inline in cqlsh)
SELECT * FROM my_ks.my_table WHERE pk = 'abc';

-- Disable tracing
TRACING OFF;

-- Query trace data directly
SELECT * FROM system_traces.sessions LIMIT 10;

SELECT * FROM system_traces.events
WHERE session_id = <trace-session-uuid>;
```

**Trace analysis checklist:**
- Look for "Read X live rows and Y tombstone cells" -- high tombstone count is bad
- Check which SSTables were consulted -- high count means compaction is behind
- Look for "Sending... to /x.x.x.x" -- indicates cross-node communication
- Check total duration -- compare with client-observed latency to measure driver overhead

### Authentication and Authorization

```cql
-- List all roles
SELECT role, login, is_superuser FROM system_auth.roles;

-- List permissions
SELECT * FROM system_auth.role_permissions;

-- Service levels (2025.1+)
SELECT * FROM system_distributed.service_levels;
```

### Raft Status (2025.1+)

```cql
-- Raft group 0 (topology) status
SELECT * FROM system.raft;

-- Topology state
SELECT * FROM system.topology;

-- Token metadata (tablets)
SELECT * FROM system.token_metadata;
```

---

## ScyllaDB Manager (sctool) Diagnostics

### Cluster Status

```bash
# Overall status of all managed clusters
sctool status

# Status for a specific cluster
sctool status -c my-cluster

# List all managed clusters
sctool cluster list

# Cluster details
sctool cluster show -c my-cluster
```

### Task Management

```bash
# List all tasks
sctool task list -c my-cluster

# List tasks of a specific type
sctool task list -c my-cluster --type repair
sctool task list -c my-cluster --type backup

# Show task progress
sctool task progress -c my-cluster <task-id>

# Show task history
sctool task history -c my-cluster <task-id>

# Stop a running task
sctool task stop -c my-cluster <task-id>

# Start a stopped task
sctool task start -c my-cluster <task-id>

# Delete a task
sctool task delete -c my-cluster <task-id>
```

### Repair Diagnostics

```bash
# List repair tasks
sctool repair list -c my-cluster

# Show repair progress
sctool task progress -c my-cluster <repair-task-id>

# Check repair intensity
sctool repair show -c my-cluster <repair-task-id>

# Update repair parallelism while running
sctool repair update -c my-cluster <repair-task-id> --parallel 1

# Update repair intensity while running
sctool repair update -c my-cluster <repair-task-id> --intensity 0.5
```

### Backup Diagnostics

```bash
# List backup tasks
sctool backup list -c my-cluster --location s3:my-bucket

# Show backup details
sctool backup list -c my-cluster --location s3:my-bucket --all-clusters

# Validate backup files
sctool backup validate -c my-cluster --location s3:my-bucket

# Show backup progress
sctool task progress -c my-cluster <backup-task-id>
```

### Restore Diagnostics

```bash
# Dry-run restore (shows what would be restored)
sctool restore -c my-cluster --location s3:my-bucket --snapshot-tag <tag> --dry-run

# Show restore progress
sctool task progress -c my-cluster <restore-task-id>
```

### Healthcheck

```bash
# Run a healthcheck
sctool status -c my-cluster

# Check specific endpoints (CQL, Alternator)
# Manager healthcheck pings all nodes on CQL and REST ports
```

---

## Prometheus Metrics Queries

ScyllaDB exports metrics on port 9180 (default). These can be queried directly or via Grafana.

### Throughput Metrics

```promql
# CQL reads per second (cluster-wide)
sum(rate(scylla_cql_reads[5m]))

# CQL writes per second (cluster-wide)
sum(rate(scylla_cql_inserts[5m]))

# CQL reads per second per node
rate(scylla_cql_reads[5m])

# CQL writes per second per node
rate(scylla_cql_inserts[5m])

# Total operations per second per shard
sum by (shard) (rate(scylla_transport_requests_served[5m]))
```

### Latency Metrics

```promql
# CQL read latency p99 (microseconds)
histogram_quantile(0.99, sum(rate(scylla_cql_read_latency_bucket[5m])) by (le))

# CQL write latency p99
histogram_quantile(0.99, sum(rate(scylla_cql_write_latency_bucket[5m])) by (le))

# CQL read latency p50
histogram_quantile(0.50, sum(rate(scylla_cql_read_latency_bucket[5m])) by (le))

# Per-node read latency p99
histogram_quantile(0.99, sum by (le, instance) (rate(scylla_cql_read_latency_bucket[5m])))
```

### Compaction Metrics

```promql
# Pending compactions
scylla_compaction_manager_pending_tasks

# Compaction bytes written per second
rate(scylla_compaction_manager_bytes_compacted[5m])

# Compaction throughput MB/s
rate(scylla_compaction_manager_bytes_compacted[5m]) / 1048576

# Active compactions
scylla_compaction_manager_compactions
```

### Cache Metrics

```promql
# Row cache hit rate
scylla_cache_row_hits / (scylla_cache_row_hits + scylla_cache_row_misses)

# Row cache hit rate per node
sum by (instance) (rate(scylla_cache_row_hits[5m])) /
(sum by (instance) (rate(scylla_cache_row_hits[5m])) + sum by (instance) (rate(scylla_cache_row_misses[5m])))

# Cache memory usage
scylla_cache_bytes_used

# Cache evictions per second
rate(scylla_cache_row_evictions[5m])
```

### Memory Metrics

```promql
# Total memory used per shard
scylla_memory_allocated_memory

# Free memory per shard
scylla_memory_free_memory

# LSA (Log-Structured Allocator) memory usage
scylla_lsa_memory_allocated

# LSA free memory
scylla_lsa_memory_free

# Memtable memory usage
scylla_memtable_memory_usage
```

### I/O Metrics

```promql
# Disk read throughput (bytes/sec)
rate(scylla_io_queue_total_read_bytes[5m])

# Disk write throughput (bytes/sec)
rate(scylla_io_queue_total_write_bytes[5m])

# Disk read IOPS
rate(scylla_io_queue_total_read_ops[5m])

# Disk write IOPS
rate(scylla_io_queue_total_write_ops[5m])

# I/O queue delay (time spent waiting in queue)
rate(scylla_io_queue_delay[5m])
```

### Scheduling Group Metrics

```promql
# CPU usage by scheduling group
rate(scylla_scheduler_runtime_ms[5m])

# CPU time spent in statement processing
rate(scylla_scheduler_runtime_ms{group="statement"}[5m])

# CPU time spent in compaction
rate(scylla_scheduler_runtime_ms{group="compaction"}[5m])

# Task queue length by scheduling group
scylla_scheduler_queue_length
```

### Gossip and Network Metrics

```promql
# Cross-shard operations (high = poor shard awareness)
rate(scylla_storage_proxy_coordinator_foreground_reads{op_type="cross-shard"}[5m])

# Timeout errors
rate(scylla_storage_proxy_coordinator_read_timeouts[5m])
rate(scylla_storage_proxy_coordinator_write_timeouts[5m])

# Unavailable errors
rate(scylla_storage_proxy_coordinator_read_unavailables[5m])
rate(scylla_storage_proxy_coordinator_write_unavailables[5m])

# Dropped messages
rate(scylla_transport_requests_shed[5m])
```

### Tombstone and Large Partition Metrics

```promql
# Tombstones scanned per read
scylla_column_family_tombstone_scanned

# Large partition warnings
scylla_compaction_manager_large_partition_warnings
```

### Streaming Metrics

```promql
# Active streams
scylla_streaming_active_streams

# Streaming throughput
rate(scylla_streaming_bytes_sent[5m])
rate(scylla_streaming_bytes_received[5m])
```

### Hints Metrics

```promql
# Pending hints
scylla_node_hints_pending

# Hints written per second
rate(scylla_node_hints_created[5m])

# Hints sent per second (replayed)
rate(scylla_node_hints_sent[5m])
```

### Alternator Metrics (DynamoDB API)

```promql
# Alternator reads per second
rate(scylla_alternator_reads[5m])

# Alternator writes per second
rate(scylla_alternator_writes[5m])

# Alternator operation latency
histogram_quantile(0.99, sum(rate(scylla_alternator_operation_latency_bucket[5m])) by (le))
```

---

## Log Analysis

### Log Locations

```bash
# ScyllaDB log (systemd)
journalctl -u scylla-server --since "1 hour ago"
journalctl -u scylla-server -f   # follow/tail

# ScyllaDB log file (if configured)
tail -f /var/log/scylla/scylla.log

# Manager log
journalctl -u scylla-manager --since "1 hour ago"
```

### Critical Log Patterns

```bash
# Out of memory (per-shard)
journalctl -u scylla-server | grep -i "allocation_failure"

# Large partitions detected
journalctl -u scylla-server | grep -i "large partition"
journalctl -u scylla-server | grep -i "large_data_handler"

# Compaction errors
journalctl -u scylla-server | grep -i "compaction.*error"

# Tombstone warnings
journalctl -u scylla-server | grep -i "tombstone"

# Gossip failures
journalctl -u scylla-server | grep -i "gossip"
journalctl -u scylla-server | grep -i "failure_detector"

# Node down detection
journalctl -u scylla-server | grep -i "marking .* as DOWN"

# Timeout errors
journalctl -u scylla-server | grep -i "timeout"
journalctl -u scylla-server | grep -i "Operation timed out"

# Hint delivery
journalctl -u scylla-server | grep -i "hint"

# Streaming events
journalctl -u scylla-server | grep -i "streaming"

# Raft errors (2025.1+)
journalctl -u scylla-server | grep -i "raft"

# Tablet migration events
journalctl -u scylla-server | grep -i "tablet"
```

---

## Troubleshooting Playbooks

### Playbook: Latency Spike Investigation

**Symptoms:** p99 read latency suddenly increases from <5ms to >50ms.

**Step 1: Check per-shard CPU saturation**
```promql
rate(scylla_scheduler_runtime_ms{group="statement"}[5m])
```
If any shard shows >90% CPU in the statement group, that shard is saturated.

**Step 2: Check compaction backlog**
```bash
nodetool compactionstats
curl -s http://localhost:10000/compaction_manager/pending_tasks
```
High pending compactions = more SSTables per read = higher latency.

**Step 3: Check for large partitions**
```bash
journalctl -u scylla-server | grep "large partition"
```
```cql
SELECT * FROM system.large_partitions LIMIT 10;
```

**Step 4: Check tombstone scans**
```bash
nodetool tablestats my_keyspace.my_table   # look at "Average tombstones per slice"
```

**Step 5: Check cache hit rate**
```promql
scylla_cache_row_hits / (scylla_cache_row_hits + scylla_cache_row_misses)
```
Drop in hit rate = more disk reads.

**Step 6: Check I/O queue delay**
```promql
rate(scylla_io_queue_delay[5m])
```
High delay = disk is the bottleneck.

**Step 7: Check for cross-shard reads**
```promql
rate(scylla_storage_proxy_coordinator_foreground_reads{op_type="cross-shard"}[5m])
```
High cross-shard = driver not shard-aware. Switch to ScyllaDB driver.

### Playbook: Compaction Falling Behind

**Symptoms:** Pending compaction tasks growing, SSTable count per table increasing, read latency rising.

**Step 1: Confirm the problem**
```bash
nodetool compactionstats
nodetool tablestats my_keyspace.my_table   # check SSTable count
```

**Step 2: Check compaction throughput limit**
```bash
nodetool getcompactionthroughput
```
If set to a low value, increase:
```bash
nodetool setcompactionthroughput 0   # unlimited
```

**Step 3: Check compaction strategy**
```bash
curl -s "http://localhost:10000/column_family/compaction_strategy/my_ks:my_table"
```
If using STCS with large tables, consider switching to ICS.

**Step 4: Check disk space**
```bash
df -h /var/lib/scylla
```
If disk is >80% full, compaction may be throttled or failing due to space.

**Step 5: Check if compaction is CPU-bound**
```promql
rate(scylla_scheduler_runtime_ms{group="compaction"}[5m])
```
If compaction CPU is maxed, reduce write load or add nodes.

**Step 6: Check for large partitions slowing compaction**
```cql
SELECT * FROM system.large_partitions
WHERE keyspace_name = 'my_ks' AND table_name = 'my_table';
```

### Playbook: Large Partition Remediation

**Symptoms:** Compaction warnings about large partitions, latency spikes on specific queries, high per-shard memory pressure.

**Step 1: Identify large partitions**
```cql
SELECT * FROM system.large_partitions ORDER BY compaction_time DESC LIMIT 20;
```

**Step 2: Analyze the partition key**
- Is the partition key low-cardinality? (e.g., country, status)
- Is the partition unbounded? (e.g., all events for a user without time-bucketing)

**Step 3: Check partition size distribution**
```bash
nodetool tablehistograms my_keyspace my_table
```
Look at the "Partition Size" histogram. Large outliers indicate data model issues.

**Step 4: Redesign the data model**
- Add time-bucketing to the partition key
- Split wide partitions into multiple tables
- Reduce clustering column cardinality

**Step 5: Set warning thresholds**
```yaml
# scylla.yaml
compaction_large_partition_warning_threshold_mb: 100
compaction_large_row_warning_threshold_mb: 10
compaction_large_cell_warning_threshold_mb: 1
```

### Playbook: Scheduling Group Contention

**Symptoms:** Interactive read latency increases when batch analytics or compaction is running.

**Step 1: Check scheduling group CPU usage**
```promql
rate(scylla_scheduler_runtime_ms[5m])
```
Identify which group is consuming the most CPU.

**Step 2: Configure workload prioritization**
```cql
-- Create separate service levels
CREATE SERVICE LEVEL interactive_sl WITH timeout = '5s' AND workload_type = 'interactive';
CREATE SERVICE LEVEL batch_sl WITH timeout = '60s' AND workload_type = 'batch';

-- Assign to roles
ATTACH SERVICE LEVEL interactive_sl TO 'app_user';
ATTACH SERVICE LEVEL batch_sl TO 'analytics_user';
```

**Step 3: Verify separation**
```promql
# Should see separate scheduling group metrics for interactive vs batch
rate(scylla_scheduler_runtime_ms{group="sl:interactive_sl"}[5m])
rate(scylla_scheduler_runtime_ms{group="sl:batch_sl"}[5m])
```

### Playbook: Node Failure Recovery

**Step 1: Identify the failed node**
```bash
nodetool status   # look for DN nodes
```

**Step 2: Check if the node is temporarily or permanently down**
- Check system logs, hardware, network connectivity

**Step 3: If temporary (expected to recover):**
- Wait for recovery. Hints will replay automatically.
- If down > `max_hint_window_in_ms` (3 hours default), run repair after recovery.

**Step 4: If permanent (hardware failure, no recovery):**
```bash
# Remove the dead node from a LIVE node
nodetool removenode <host-id-of-dead-node>

# Monitor progress
nodetool status
```

**Step 5: After removal, run repair**
```bash
sctool repair -c my-cluster --interval 0   # immediate one-time repair
```

### Playbook: Rolling Upgrade

**Step 1: Pre-upgrade checks**
```bash
nodetool status                    # all nodes UN
nodetool describecluster           # single schema version
sctool status -c my-cluster        # no running repairs
nodetool compactionstats           # no excessive pending
```

**Step 2: Upgrade one node at a time**
```bash
# On each node:
nodetool drain
sudo systemctl stop scylla-server
# Install new version (package manager)
sudo systemctl start scylla-server

# Verify on the upgraded node:
nodetool version
nodetool status
```

**Step 3: Post-upgrade validation**
```bash
nodetool describecluster           # schema versions should converge
nodetool status                    # all nodes UN
```

### Playbook: Cross-Datacenter Latency Issues

**Step 1: Check local vs remote read/write ratios**
```promql
# Should see mostly local_quorum operations
rate(scylla_storage_proxy_coordinator_foreground_reads{cl="LOCAL_QUORUM"}[5m])
```

**Step 2: Verify client is using LOCAL_QUORUM**
Check application driver configuration. Ensure not using QUORUM (which spans DCs).

**Step 3: Check phi failure detector**
```bash
curl -s http://localhost:10000/failure_detector/phi
```
If phi values for remote DC nodes are high, increase `phi_convict_threshold`:
```yaml
phi_convict_threshold: 12   # up from default 8
```

**Step 4: Check snitch configuration**
```bash
nodetool gossipinfo   # verify DC/rack assignments
```
Ensure `prefer_local: true` in `cassandra-rackdc.properties`.
