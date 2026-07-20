# Redis Diagnostics Reference

## Server Info

### INFO Command (All Sections)

The `INFO` command is the primary diagnostic tool. It returns key-value pairs organized by section.

```bash
# All sections
redis-cli INFO

# Specific section
redis-cli INFO server
redis-cli INFO clients
redis-cli INFO memory
redis-cli INFO persistence
redis-cli INFO stats
redis-cli INFO replication
redis-cli INFO cpu
redis-cli INFO commandstats
redis-cli INFO latencystats
redis-cli INFO cluster
redis-cli INFO keyspace
redis-cli INFO modules
redis-cli INFO errorstats
```

### INFO server -- Core Instance Details

```bash
redis-cli INFO server
```

| Field | Meaning | Concerning Values |
|---|---|---|
| `redis_version` | Server version | Unsupported versions (check EOL dates) |
| `uptime_in_seconds` | Seconds since start | < 300 (unexpected restart) |
| `uptime_in_days` | Days since start | 0 (just restarted) |
| `hz` | Server event loop frequency | Default 10; may need 100 for latency-sensitive |
| `configured_hz` | Configured hz value | Mismatch with hz means dynamic-hz is active |
| `tcp_port` | Listening port | Verify expected port |
| `executable` | Path to redis-server binary | Verify correct binary |
| `config_file` | Path to loaded config | Empty = started without config file |
| `io_threads_active` | Whether I/O threads are enabled | 0 when I/O threading not in use |
| `process_id` | OS PID | Verify process identity |

### CONFIG GET -- Runtime Configuration

```bash
# Get all configuration parameters
redis-cli CONFIG GET '*'

# Get specific parameters
redis-cli CONFIG GET maxmemory
redis-cli CONFIG GET maxmemory-policy
redis-cli CONFIG GET save
redis-cli CONFIG GET appendonly
redis-cli CONFIG GET maxclients
redis-cli CONFIG GET timeout
redis-cli CONFIG GET hz
redis-cli CONFIG GET slowlog-log-slower-than
redis-cli CONFIG GET repl-backlog-size
redis-cli CONFIG GET cluster-node-timeout

# Pattern matching
redis-cli CONFIG GET '*memory*'
redis-cli CONFIG GET '*timeout*'
redis-cli CONFIG GET '*repl*'
```

### CONFIG SET -- Runtime Reconfiguration

```bash
# Adjust without restart
redis-cli CONFIG SET maxmemory 12gb
redis-cli CONFIG SET maxmemory-policy allkeys-lfu
redis-cli CONFIG SET slowlog-log-slower-than 5000
redis-cli CONFIG SET latency-monitor-threshold 10
redis-cli CONFIG SET hz 100
redis-cli CONFIG SET timeout 300

# Persist runtime changes to config file
redis-cli CONFIG REWRITE
```

### DBSIZE -- Key Count

```bash
redis-cli DBSIZE
# Returns: (integer) 1234567
# Note: In cluster mode, returns count for the connected node only
```

### TIME -- Server Time

```bash
redis-cli TIME
# Returns: Unix timestamp (seconds) and microseconds
# Use to check clock skew between nodes
```

### DEBUG OBJECT -- Internal Object Details

```bash
redis-cli DEBUG OBJECT mykey
# Value at:0x7f1234 refcount:1 encoding:ziplist serializedlength:45 lru:1234567 lru_seconds_idle:100
# WARNING: DEBUG commands may be restricted in production (ACLs, rename-command)
```

**Prefer these safer alternatives:**
```bash
redis-cli OBJECT ENCODING mykey      # encoding type (ziplist, listpack, skiplist, etc.)
redis-cli OBJECT REFCOUNT mykey      # reference count
redis-cli OBJECT IDLETIME mykey      # seconds since last access (LRU policy)
redis-cli OBJECT FREQ mykey          # access frequency counter (LFU policy)
redis-cli OBJECT HELP                # list all OBJECT subcommands
```

## Memory Diagnostics

### INFO memory -- Full Memory Report

```bash
redis-cli INFO memory
```

| Field | Meaning | Concerning Values |
|---|---|---|
| `used_memory` | Total allocated by Redis (bytes) | Approaching maxmemory |
| `used_memory_human` | Human-readable used_memory | -- |
| `used_memory_rss` | Resident set size from OS | Much larger than used_memory = fragmentation |
| `used_memory_peak` | Peak memory usage ever | Indicates historical high water mark |
| `used_memory_peak_perc` | Current as % of peak | Declining = data was deleted/evicted |
| `used_memory_overhead` | Memory for internal structures | High relative to dataset = many small keys |
| `used_memory_dataset` | Approximate data size | used_memory - used_memory_overhead |
| `used_memory_dataset_perc` | Data as % of total usage | Low = overhead dominates; optimize key structure |
| `used_memory_lua` | Lua engine memory | High = large/many scripts cached |
| `used_memory_scripts` | Cached Lua scripts memory | Consider SCRIPT FLUSH if excessive |
| `mem_fragmentation_ratio` | RSS / used_memory | > 1.5 = fragmented; < 1.0 = swapping |
| `mem_fragmentation_bytes` | Absolute fragmentation in bytes | > 100MB warrants investigation |
| `mem_allocator` | Active allocator | jemalloc expected |
| `active_defrag_running` | Whether defrag is active | 1 = currently defragmenting |
| `allocator_frag_ratio` | jemalloc internal fragmentation | > 1.1 = allocator fragmentation |
| `allocator_rss_ratio` | jemalloc RSS overhead | > 1.1 = significant RSS overhead |
| `maxmemory` | Configured limit | 0 = no limit (dangerous in production) |
| `maxmemory_policy` | Eviction policy | Verify it matches workload requirements |

### MEMORY USAGE -- Per-Key Memory

```bash
# Exact memory for a key (including overhead)
redis-cli MEMORY USAGE mykey
# Returns: (integer) 56    (bytes)

# With sampling for large collections
redis-cli MEMORY USAGE myhash SAMPLES 100
# Estimates by sampling 100 elements; 0 = exact (slow for large keys)
```

**Use cases:**
- Identify unexpectedly large keys
- Compare encoding efficiency before/after optimization
- Estimate memory for new key patterns

### MEMORY STATS -- Detailed Breakdown

```bash
redis-cli MEMORY STATS
```

Returns a detailed breakdown including:
- `peak.allocated`: Historical peak
- `total.allocated`: Current total
- `startup.allocated`: Memory used at startup (before data)
- `replication.backlog`: Replication backlog size
- `clients.slaves`: Memory for replica output buffers
- `clients.normal`: Memory for client output/input buffers
- `aof.buffer`: AOF write buffer size
- `dbN.overhead.hashtable.main`: Per-database hash table overhead
- `dbN.overhead.hashtable.expires`: Per-database expires table overhead

### MEMORY DOCTOR -- Automated Diagnosis

```bash
redis-cli MEMORY DOCTOR
# Returns: "Sam, I have no memory problems" (all OK)
# Or: detailed advice about memory issues found
```

Reports issues like:
- High fragmentation ratio
- Peak memory much higher than current
- High allocation overhead
- RSS significantly larger than used memory

### MEMORY MALLOC-STATS -- Allocator Internals

```bash
redis-cli MEMORY MALLOC-STATS
# Raw jemalloc statistics (verbose; useful for deep analysis)
```

### MEMORY PURGE -- Force Memory Return

```bash
redis-cli MEMORY PURGE
# Forces jemalloc to return unused pages to the OS
# Use when fragmentation is high after a large key deletion
```

### Big Key Scanning

```bash
# Built-in big key scanner (samples every type)
redis-cli --bigkeys
# Output: largest key per type, overall stats
# Runs SCAN internally; safe for production

# Memory-based big key scanner
redis-cli --memkeys
# Like --bigkeys but reports memory usage per key
# Slower: runs MEMORY USAGE on each key

# Combined: big keys with memory stats, sample 100 keys
redis-cli --memkeys --memkeys-samples 100

# Manual big key detection with SCAN + MEMORY USAGE
redis-cli SCAN 0 COUNT 1000 TYPE string
# Then for each key: MEMORY USAGE key
```

## Performance Diagnostics

### SLOWLOG -- Slow Command Log

```bash
# Configure slow log threshold (microseconds; 10000 = 10ms)
redis-cli CONFIG SET slowlog-log-slower-than 10000
redis-cli CONFIG SET slowlog-max-len 256

# View recent slow commands
redis-cli SLOWLOG GET
redis-cli SLOWLOG GET 10          # last 10 entries

# Each entry contains:
# 1) Unique ID
# 2) Unix timestamp
# 3) Execution time (microseconds)
# 4) Command + arguments
# 5) Client IP:port
# 6) Client name (if set)

# Count entries
redis-cli SLOWLOG LEN

# Reset slow log
redis-cli SLOWLOG RESET
```

**Concerning patterns:**
- KEYS, SORT, SMEMBERS on large collections appearing frequently
- DEL on large keys (use UNLINK instead)
- HGETALL, LRANGE 0 -1 on keys with 10K+ elements
- Lua scripts exceeding timeout
- CLUSTER commands during resharding

### LATENCY -- Event Monitoring

```bash
# Enable latency monitoring (milliseconds)
redis-cli CONFIG SET latency-monitor-threshold 10

# View latest latency events per category
redis-cli LATENCY LATEST
# Returns: event-name, timestamp, latest-ms, max-ms

# Latency event categories:
# command             -- slow commands
# fast-command        -- O(1)/O(log N) commands exceeding threshold
# fork                -- fork() latency (BGSAVE, BGREWRITEAOF)
# rdb-unlink-temp-file -- removing temp RDB after BGSAVE
# aof-write           -- AOF fsync latency
# aof-fsync-always    -- fsync latency with appendfsync always
# aof-write-pending-fsync -- write while fsync pending
# aof-rewrite-diff-write -- writing AOF diff during rewrite
# expire-cycle        -- active expiry cycle
# eviction-cycle      -- eviction cycle
# eviction-del        -- lazy deletion during eviction

# History for a specific event
redis-cli LATENCY HISTORY command
# Returns: array of [timestamp, latency-ms] pairs

# ASCII graph for a specific event
redis-cli LATENCY GRAPH command
# Visual representation of latency over time

# Reset all latency data
redis-cli LATENCY RESET
redis-cli LATENCY RESET command    # reset specific event
```

### COMMANDSTATS -- Per-Command Statistics

```bash
redis-cli INFO commandstats
# cmdstat_get:calls=1000000,usec=500000,usec_per_call=0.50,rejected_calls=0,failed_calls=0
# cmdstat_set:calls=500000,usec=300000,usec_per_call=0.60,...
```

**Analyze for:**
- Commands with high `usec_per_call` (slow per execution)
- Commands with high total `usec` (most total time consumed)
- Unexpected command patterns (KEYS in production, excessive SCAN)
- `rejected_calls` > 0 (ACL denials or OOM rejections)
- `failed_calls` > 0 (command errors)

### LATENCYSTATS -- Per-Command Latency Distribution

```bash
redis-cli INFO latencystats
# latency_percentiles_usec_get:p50=1.001,p99=5.023,p99.9=12.543
# latency_percentiles_usec_set:p50=1.503,p99=7.234,p99.9=15.876
```

**Available since Redis 7.0. Shows p50, p99, p99.9 latencies per command.**

### DEBUG SLEEP -- Latency Simulation (Testing Only)

```bash
# WARNING: blocks the server for N seconds. NEVER use in production.
redis-cli DEBUG SLEEP 5
```

## Client Connection Diagnostics

### CLIENT LIST -- All Connected Clients

```bash
redis-cli CLIENT LIST
redis-cli CLIENT LIST TYPE normal     # only regular clients
redis-cli CLIENT LIST TYPE replica    # only replica connections
redis-cli CLIENT LIST TYPE pubsub     # only pub/sub subscribers
redis-cli CLIENT LIST TYPE master     # only master connections (on replica)
redis-cli CLIENT LIST ID 1 2 3        # specific client IDs
```

**Key fields:**
| Field | Meaning | Concerning Values |
|---|---|---|
| `id` | Unique client ID | -- |
| `addr` | Client IP:port | Unexpected IPs |
| `fd` | File descriptor | -- |
| `name` | Client name (CLIENT SETNAME) | Empty = unnamed |
| `db` | Current database | >0 in cluster mode is wrong |
| `sub` | Subscribed channels | High = many pub/sub subscriptions |
| `psub` | Pattern subscriptions | High = many pattern subscriptions |
| `multi` | Commands in MULTI queue | -1 = not in transaction; >0 = in transaction |
| `qbuf` | Input buffer bytes | >1MB = client sending large commands |
| `qbuf-free` | Free input buffer bytes | -- |
| `omem` | Output buffer memory bytes | >1MB = slow consumer or large response |
| `tot-mem` | Total memory for this client | High = investigate |
| `age` | Connection age (seconds) | Very high = leaked connection |
| `idle` | Seconds since last command | High + no timeout = leaked |
| `flags` | Client flags | `S`=replica, `M`=master, `b`=blocked, `x`=MULTI |
| `cmd` | Last command executed | `monitor` or `subscribe` = persistent |
| `resp` | RESP protocol version | 2 or 3 |

### CLIENT INFO -- Current Client

```bash
redis-cli CLIENT INFO
# Returns same fields as CLIENT LIST but for the current connection only
```

### CLIENT GETNAME / SETNAME

```bash
redis-cli CLIENT SETNAME "myapp-worker-1"
redis-cli CLIENT GETNAME
# Naming clients helps identify them in CLIENT LIST
```

### CLIENT NO-EVICT -- Protect Client from Eviction

```bash
redis-cli CLIENT NO-EVICT on
# This client won't be evicted when maxmemory is reached
# Use for critical monitoring/admin connections
```

### CLIENT NO-TOUCH -- Exclude from LRU/LFU

```bash
redis-cli CLIENT NO-TOUCH on
# Commands from this client won't update key access time/frequency
# Useful for monitoring scripts that shouldn't affect eviction
```

### CLIENT KILL -- Terminate Connections

```bash
# Kill by client ID
redis-cli CLIENT KILL ID 12345

# Kill by address
redis-cli CLIENT KILL ADDR 192.168.1.100:6379

# Kill all clients from a specific IP
redis-cli CLIENT KILL LADDR 192.168.1.100

# Kill by user
redis-cli CLIENT KILL USER appuser

# Kill idle clients
redis-cli CLIENT LIST | awk -F'[ =]' '{for(i=1;i<=NF;i++){if($i=="idle")print $(i+1),$0}}' | sort -rn | head
# Then: CLIENT KILL ID <id> for problematic ones
```

### CLIENT PAUSE / UNPAUSE

```bash
# Pause all client commands (useful before failover)
redis-cli CLIENT PAUSE 5000 WRITE    # pause writes for 5 seconds
redis-cli CLIENT PAUSE 5000 ALL      # pause all commands for 5 seconds

# Resume
redis-cli CLIENT UNPAUSE
```

### INFO clients -- Client Summary

```bash
redis-cli INFO clients
```

| Field | Meaning | Concerning Values |
|---|---|---|
| `connected_clients` | Current connections | > 80% of maxclients |
| `cluster_connections` | Cluster bus connections | Unexpected count |
| `maxclients` | Maximum allowed | -- |
| `client_recent_max_input_buffer` | Largest recent input buffer | > 1MB |
| `client_recent_max_output_buffer` | Largest recent output buffer | > 1MB |
| `blocked_clients` | Clients in blocking command | > 0 for extended time |
| `tracking_clients` | Clients using client-side caching | -- |
| `clients_in_timeout_table` | Clients with timeout pending | -- |
| `total_blocking_clients` | Total blocking clients across all reasons | -- |
| `total_blocking_clients_on_nokey` | Blocking clients waiting on non-existing keys | -- |

## Replication Diagnostics

### INFO replication -- Replication Status

```bash
redis-cli INFO replication
```

**On master:**
| Field | Meaning | Concerning Values |
|---|---|---|
| `role` | master or slave | -- |
| `connected_slaves` | Number of connected replicas | Less than expected |
| `master_failover_state` | Failover state | no-failover expected normally |
| `master_replid` | Replication ID | Changes on failover |
| `master_repl_offset` | Current replication offset | -- |
| `repl_backlog_active` | Whether backlog is active | 0 = no replicas connected |
| `repl_backlog_size` | Configured backlog size | Too small = frequent full syncs |
| `repl_backlog_first_byte_offset` | Oldest offset in backlog | -- |
| `slave0:ip,port,state,offset,lag` | Per-replica status | lag > 1 = replication delay |

**On replica:**
| Field | Meaning | Concerning Values |
|---|---|---|
| `role` | slave | -- |
| `master_host` | Master IP | Verify correct master |
| `master_port` | Master port | Verify correct port |
| `master_link_status` | up or down | down = connection lost |
| `master_last_io_seconds_ago` | Seconds since last data received | > 10 = possible network issue |
| `master_sync_in_progress` | Whether full sync is happening | 1 = full sync (performance impact) |
| `slave_read_repl_offset` | Bytes read from master | Compare with master_repl_offset |
| `slave_repl_offset` | Applied replication offset | Difference from master = lag |
| `slave_priority` | Sentinel failover priority | 0 = never promote |
| `master_sync_left_bytes` | Remaining bytes in full sync | -1 = not syncing |

### WAIT -- Synchronous Replication Check

```bash
# Wait for N replicas to acknowledge writes within timeout
redis-cli SET critical-data value
redis-cli WAIT 2 5000
# Returns: number of replicas that acknowledged (integer)
# If returns < 2: fewer replicas caught up within timeout
```

### WAITAOF -- AOF Acknowledgment (Redis 7.2+)

```bash
# Wait for write to be persisted to AOF on N replicas and local
redis-cli SET critical-data value
redis-cli WAITAOF 1 1 5000
# Args: <local-aof-count> <replica-count> <timeout>
# Returns: [local_fsyncs, replica_fsyncs]
```

### Replication Lag Monitoring Script

```bash
#!/bin/bash
# monitor-replication-lag.sh
MASTER_HOST=${1:-localhost}
MASTER_PORT=${2:-6379}

MASTER_OFFSET=$(redis-cli -h $MASTER_HOST -p $MASTER_PORT INFO replication | grep master_repl_offset | cut -d: -f2 | tr -d '\r')

echo "Master offset: $MASTER_OFFSET"

# Get each replica's offset
redis-cli -h $MASTER_HOST -p $MASTER_PORT INFO replication | grep "^slave" | while read line; do
    IP=$(echo $line | sed 's/.*ip=\([^,]*\).*/\1/')
    PORT=$(echo $line | sed 's/.*port=\([^,]*\).*/\1/')
    OFFSET=$(echo $line | sed 's/.*offset=\([^,]*\).*/\1/')
    LAG=$(echo $line | sed 's/.*lag=\([^,]*\).*/\1/' | tr -d '\r')
    DIFF=$((MASTER_OFFSET - OFFSET))
    echo "Replica $IP:$PORT -- offset=$OFFSET, lag=${LAG}s, behind=${DIFF} bytes"
    if [ $DIFF -gt 1048576 ]; then
        echo "  WARNING: replica is > 1MB behind master"
    fi
done
```

## Cluster Diagnostics

### CLUSTER INFO -- Cluster Health

```bash
redis-cli -c CLUSTER INFO
```

| Field | Meaning | Concerning Values |
|---|---|---|
| `cluster_enabled` | Whether cluster mode is on | 0 = not a cluster node |
| `cluster_state` | ok or fail | fail = some slots uncovered |
| `cluster_slots_assigned` | Slots assigned to nodes | < 16384 = uncovered slots |
| `cluster_slots_ok` | Slots in OK state | < 16384 = slots in fail/pfail |
| `cluster_slots_pfail` | Slots in PFAIL state | > 0 = possible node failure |
| `cluster_slots_fail` | Slots in FAIL state | > 0 = confirmed node failure |
| `cluster_known_nodes` | Total known nodes | Verify expected count |
| `cluster_size` | Number of master nodes serving slots | -- |
| `cluster_current_epoch` | Cluster configuration epoch | Increases on failovers |
| `cluster_my_epoch` | This node's config epoch | -- |
| `cluster_stats_messages_sent` | Gossip messages sent | Very high = possible issues |
| `cluster_stats_messages_received` | Gossip messages received | -- |
| `total_cluster_links_buffer_limit_exceeded` | Buffer overflow events | > 0 = cluster bus congestion |

### CLUSTER NODES -- Full Node List

```bash
redis-cli -c CLUSTER NODES
# Format per line:
# <node-id> <ip:port@bus-port> <flags> <master-id|--> <ping-sent> <pong-recv> <config-epoch> <link-state> <slot-range>

# Example:
# abc123 192.168.1.1:6379@16379 master - 0 1234567890 1 connected 0-5460
# def456 192.168.1.2:6379@16379 master - 0 1234567890 2 connected 5461-10922
# ghi789 192.168.1.3:6379@16379 master - 0 1234567890 3 connected 10923-16383
# jkl012 192.168.1.4:6379@16379 slave abc123 0 1234567890 1 connected
```

**Flags to watch:**
| Flag | Meaning | Action |
|---|---|---|
| `master` | Master node | Expected |
| `slave` | Replica node | Expected |
| `myself` | The node responding | -- |
| `fail?` | PFAIL (probable failure) | Monitor; may recover |
| `fail` | FAIL (confirmed failure) | Investigate immediately |
| `handshake` | Node joining cluster | Temporary during add |
| `noaddr` | No address known | Node configuration issue |
| `noflags` | No flags | Should not appear normally |

### CLUSTER SLOTS -- Slot Mapping

```bash
redis-cli -c CLUSTER SLOTS
# Returns array of slot ranges with master and replica info
# Useful for client slot table initialization
```

### CLUSTER SHARDS -- Shard Information (Redis 7.0+)

```bash
redis-cli -c CLUSTER SHARDS
# Returns detailed shard information including:
# - Slot ranges per shard
# - Master and replica nodes per shard
# - Node health, replication offset, endpoint info
# More structured than CLUSTER NODES for programmatic use
```

### CLUSTER KEYSLOT -- Key-to-Slot Mapping

```bash
redis-cli CLUSTER KEYSLOT mykey
# Returns: (integer) 14687
# Useful for understanding which node owns a key

redis-cli CLUSTER KEYSLOT "{user:1000}:profile"
# Returns: same slot as all {user:1000}:* keys
```

### CLUSTER COUNTKEYSINSLOT -- Keys per Slot

```bash
redis-cli CLUSTER COUNTKEYSINSLOT 14687
# Returns: (integer) 42
# Useful for identifying unbalanced slots during resharding
```

### CLUSTER GETKEYSINSLOT -- List Keys in Slot

```bash
redis-cli CLUSTER GETKEYSINSLOT 14687 100
# Returns up to 100 keys in slot 14687
# Useful for manual slot migration or debugging
```

### redis-cli --cluster Commands

```bash
# Health check (all nodes, slot coverage, replication)
redis-cli --cluster check node1:6379

# Fix common cluster issues
redis-cli --cluster fix node1:6379
redis-cli --cluster fix node1:6379 --cluster-fix-with-unreachable-masters

# Rebalance slots across masters
redis-cli --cluster rebalance node1:6379
redis-cli --cluster rebalance node1:6379 --cluster-use-empty-masters

# Reshard slots to a different node
redis-cli --cluster reshard node1:6379

# Add a node (as master)
redis-cli --cluster add-node new-node:6379 existing-node:6379

# Add a node (as replica of specific master)
redis-cli --cluster add-node new-node:6379 existing-node:6379 --cluster-slave --cluster-master-id <master-node-id>

# Remove a node (must be empty -- no slots)
redis-cli --cluster del-node existing-node:6379 <node-id-to-remove>

# Execute a command on all cluster nodes
redis-cli --cluster call node1:6379 INFO memory
redis-cli --cluster call node1:6379 DBSIZE

# Import data from standalone Redis to cluster
redis-cli --cluster import node1:6379 --cluster-from standalone:6379 --cluster-copy
```

## Sentinel Diagnostics

### SENTINEL MASTERS -- All Monitored Masters

```bash
redis-cli -p 26379 SENTINEL MASTERS
# Returns array of master details: name, ip, port, flags, quorum, num-slaves, num-other-sentinels
```

### SENTINEL MASTER -- Specific Master Details

```bash
redis-cli -p 26379 SENTINEL MASTER mymaster
```

| Field | Meaning | Concerning Values |
|---|---|---|
| `name` | Monitor name | -- |
| `ip` | Master IP | Wrong IP = failed/false failover |
| `port` | Master port | -- |
| `flags` | master, s_down, o_down | s_down or o_down = master is down |
| `num-slaves` | Connected replicas | 0 = no failover candidates |
| `num-other-sentinels` | Other sentinels monitoring this master | < quorum-1 = sentinel failure |
| `quorum` | Votes needed for ODOWN | -- |
| `failover-timeout` | Max failover time (ms) | -- |
| `parallel-syncs` | Concurrent replica reconfigurations | -- |

### SENTINEL REPLICAS -- Replica Status

```bash
redis-cli -p 26379 SENTINEL REPLICAS mymaster
# Returns array of replica details: ip, port, flags, master-link-status, slave-priority
```

**Check for:**
- `flags` containing `s_down` (replica is unreachable)
- `master-link-status` = down (replica lost connection to master)
- `slave-priority` = 0 (replica will never be promoted)

### SENTINEL SENTINELS -- Other Sentinels

```bash
redis-cli -p 26379 SENTINEL SENTINELS mymaster
# Shows all other sentinels monitoring this master
# Check for: expected count, no s_down flags
```

### SENTINEL FAILOVER -- Manual Failover

```bash
redis-cli -p 26379 SENTINEL FAILOVER mymaster
# Triggers manual failover: promotes a replica to master
# Use when: planned maintenance, testing failover, replacing master hardware
```

### SENTINEL RESET -- Reset Sentinel State

```bash
redis-cli -p 26379 SENTINEL RESET mymaster
# Resets state for matching masters: clears failover state, rediscovers replicas/sentinels
# Use when: sentinel has stale state after network issues
```

### SENTINEL CKQUORUM -- Quorum Check

```bash
redis-cli -p 26379 SENTINEL CKQUORUM mymaster
# Returns: OK if quorum is reachable and majority can authorize failover
# Use before maintenance to verify failover capability
```

### SENTINEL GET-MASTER-ADDR-BY-NAME

```bash
redis-cli -p 26379 SENTINEL GET-MASTER-ADDR-BY-NAME mymaster
# Returns: [master-ip, master-port]
# What clients use for master discovery
```

## Persistence Diagnostics

### LASTSAVE -- Last Successful Save Timestamp

```bash
redis-cli LASTSAVE
# Returns: Unix timestamp of last successful RDB save
# Compare with current time; large gap = saves may be failing
```

### BGSAVE -- Trigger Background Save

```bash
redis-cli BGSAVE
# Starts a background RDB save
# Check status: INFO persistence -> rdb_bgsave_in_progress
redis-cli BGSAVE SCHEDULE
# Schedule a save (won't start if one is already in progress)
```

### BGREWRITEAOF -- Trigger AOF Rewrite

```bash
redis-cli BGREWRITEAOF
# Starts background AOF rewrite
# Check status: INFO persistence -> aof_rewrite_in_progress
```

### INFO persistence -- Full Persistence Status

```bash
redis-cli INFO persistence
```

| Field | Meaning | Concerning Values |
|---|---|---|
| `loading` | Whether server is loading data | 1 = startup in progress |
| `async_loading` | Async loading in progress | 1 = loading data without blocking |
| `rdb_changes_since_last_save` | Unsaved changes | Very high = data at risk |
| `rdb_bgsave_in_progress` | RDB save running | -- |
| `rdb_last_save_time` | Last save timestamp | Old timestamp = saves failing |
| `rdb_last_bgsave_status` | Last save result | Not "ok" = save failure |
| `rdb_last_bgsave_time_sec` | Duration of last save | Increasing = dataset growing |
| `rdb_current_bgsave_time_sec` | Current save elapsed time | Long = large dataset |
| `rdb_saves` | Total successful saves | -- |
| `rdb_last_cow_size` | Copy-on-write bytes during last save | Large = high write rate during save |
| `aof_enabled` | Whether AOF is enabled | -- |
| `aof_rewrite_in_progress` | AOF rewrite running | -- |
| `aof_rewrite_scheduled` | AOF rewrite scheduled | 1 = waiting for RDB to finish |
| `aof_last_rewrite_time_sec` | Duration of last rewrite | Increasing = dataset growing |
| `aof_current_rewrite_time_sec` | Current rewrite elapsed time | -- |
| `aof_last_bgrewrite_status` | Last rewrite result | Not "ok" = rewrite failure |
| `aof_last_write_status` | Last AOF write result | Not "ok" = disk issue |
| `aof_last_cow_size` | COW bytes during last rewrite | Large = high write rate |
| `aof_current_size` | Current AOF file size | Compare with dataset to assess bloat |
| `aof_base_size` | AOF size after last rewrite | Current/base ratio > 2 triggers rewrite |
| `aof_buffer_length` | AOF buffer size | Large = slow disk |
| `aof_pending_bio_fsync` | Pending background fsyncs | > 0 = disk can't keep up |
| `latest_fork_usec` | Last fork() duration (microseconds) | > 1,000,000 = 1 second (very slow) |
| `module_fork_in_progress` | Module background operation | -- |
| `module_fork_last_cow_size` | Module COW bytes | -- |

## Key Analysis

### SCAN -- Safe Key Iteration

```bash
# Basic scan (returns cursor + keys)
redis-cli SCAN 0 COUNT 1000
# Continue with returned cursor until cursor = 0

# Pattern matching
redis-cli SCAN 0 MATCH "user:*" COUNT 1000
redis-cli SCAN 0 MATCH "cache:*:session" COUNT 1000

# Type filtering
redis-cli SCAN 0 TYPE string COUNT 1000
redis-cli SCAN 0 TYPE hash COUNT 1000
redis-cli SCAN 0 TYPE zset COUNT 1000
redis-cli SCAN 0 TYPE stream COUNT 1000

# Collection-level scan variants
redis-cli HSCAN myhash 0 MATCH "field*" COUNT 100
redis-cli SSCAN myset 0 MATCH "member*" COUNT 100
redis-cli ZSCAN myzset 0 MATCH "member*" COUNT 100
```

### TYPE -- Key Type

```bash
redis-cli TYPE mykey
# Returns: string, list, set, zset, hash, stream, none
```

### TTL / PTTL -- Time to Live

```bash
redis-cli TTL mykey       # seconds remaining (-1 = no expiry, -2 = key doesn't exist)
redis-cli PTTL mykey      # milliseconds remaining
```

### OBJECT Subcommands

```bash
redis-cli OBJECT ENCODING mykey
# Returns: raw, int, embstr, listpack, quicklist, skiplist, intset, hashtable, stream, etc.
# Use to verify encoding optimization (e.g., confirm listpack for small hashes)

redis-cli OBJECT REFCOUNT mykey
# Returns: reference count (usually 1; shared objects for small integers)

redis-cli OBJECT IDLETIME mykey
# Returns: seconds since last access
# Requires maxmemory-policy with LRU; resolution = 10 seconds
# Use to find stale keys

redis-cli OBJECT FREQ mykey
# Returns: logarithmic access frequency (0-255)
# Requires maxmemory-policy with LFU
# Higher = more frequently accessed

redis-cli OBJECT HELP
# Lists all OBJECT subcommands
```

### redis-cli Key Analysis Tools

```bash
# Scan for biggest keys by type (production-safe)
redis-cli --bigkeys
# Sample output:
# Biggest string found 'session:abc' has 15234 bytes
# Biggest hash found 'user:1000' has 234 fields
# Biggest list found 'queue:jobs' has 125000 items

# Memory-aware key scanning
redis-cli --memkeys
# Reports MEMORY USAGE for each key found during scan

# Hot key detection (requires LFU eviction policy)
redis-cli --hotkeys
# Reports most frequently accessed keys
```

### Key Pattern Analysis Script

```bash
#!/bin/bash
# analyze-key-patterns.sh -- summarize key namespace distribution
REDIS_CLI="redis-cli -h ${1:-localhost} -p ${2:-6379}"

echo "=== Key Pattern Analysis ==="
echo "Total keys: $($REDIS_CLI DBSIZE | awk '{print $2}')"

# Sample 10000 keys and extract patterns
$REDIS_CLI --scan --count 10000 | head -10000 | \
  sed 's/:[0-9]*/:N/g' | \
  sed 's/:[a-f0-9]\{8,\}/:HEX/g' | \
  sort | uniq -c | sort -rn | head -20

echo ""
echo "=== Type Distribution ==="
for type in string hash list set zset stream; do
    count=$($REDIS_CLI --scan --count 10000 | head -1000 | while read key; do
        $REDIS_CLI TYPE "$key"
    done | grep -c "^$type$")
    echo "$type: $count / 1000 sampled"
done
```

## Pub/Sub Diagnostics

### PUBSUB CHANNELS -- Active Channels

```bash
redis-cli PUBSUB CHANNELS
# Lists all channels with at least one subscriber

redis-cli PUBSUB CHANNELS 'notification*'
# Pattern match active channels
```

### PUBSUB NUMSUB -- Subscriber Counts

```bash
redis-cli PUBSUB NUMSUB channel1 channel2 channel3
# Returns: channel name + subscriber count pairs
```

### PUBSUB NUMPAT -- Pattern Subscription Count

```bash
redis-cli PUBSUB NUMPAT
# Returns: total number of pattern subscriptions across all clients
```

### PUBSUB SHARDCHANNELS -- Sharded Pub/Sub Channels (Redis 7.0+)

```bash
redis-cli PUBSUB SHARDCHANNELS
redis-cli PUBSUB SHARDCHANNELS 'shard:*'
# Lists active sharded pub/sub channels
```

### PUBSUB SHARDNUMSUB -- Sharded Channel Subscriber Counts (Redis 7.0+)

```bash
redis-cli PUBSUB SHARDNUMSUB channel1 channel2
# Subscriber counts for sharded channels
```

## Stream Diagnostics

### XINFO STREAM -- Stream Metadata

```bash
redis-cli XINFO STREAM mystream
# Returns: length, radix-tree-keys, radix-tree-nodes, last-generated-id, groups, first-entry, last-entry

redis-cli XINFO STREAM mystream FULL
# Returns: all of the above plus detailed consumer group info
# COUNT parameter limits entries shown
redis-cli XINFO STREAM mystream FULL COUNT 10
```

| Field | Meaning | Concerning Values |
|---|---|---|
| `length` | Number of entries | Very large = consider XTRIM |
| `radix-tree-keys` | Radix tree node count | Correlates with memory usage |
| `groups` | Number of consumer groups | -- |
| `first-entry` | Oldest entry in stream | Very old = data not being consumed or trimmed |
| `last-entry` | Newest entry | -- |
| `max-deleted-entry-id` | Highest deleted entry ID | -- |
| `entries-added` | Total entries ever added | Compare with length for deletion rate |

### XINFO GROUPS -- Consumer Group Details

```bash
redis-cli XINFO GROUPS mystream
```

| Field | Meaning | Concerning Values |
|---|---|---|
| `name` | Group name | -- |
| `consumers` | Active consumer count | 0 = no consumers processing |
| `pending` | Unacknowledged messages (PEL size) | Growing = consumers not acknowledging |
| `last-delivered-id` | Last message delivered to group | Compare with stream last entry |
| `entries-read` | Total entries read by group | -- |
| `lag` | Entries behind stream head | > 0 = consumer group is behind |

### XINFO CONSUMERS -- Per-Consumer Details

```bash
redis-cli XINFO CONSUMERS mystream mygroup
```

| Field | Meaning | Concerning Values |
|---|---|---|
| `name` | Consumer name | -- |
| `pending` | Unacknowledged messages for this consumer | Growing = consumer stuck or slow |
| `idle` | Milliseconds since last interaction | Very high = consumer may be dead |
| `inactive` | Milliseconds since last successful read | -- |

### XPENDING -- Pending Entry List Analysis

```bash
# Summary: total pending, min ID, max ID, per-consumer count
redis-cli XPENDING mystream mygroup

# Detailed pending entries
redis-cli XPENDING mystream mygroup - + 100
# Returns: [entry-id, consumer, idle-time-ms, delivery-count]

# Filter by consumer
redis-cli XPENDING mystream mygroup - + 100 consumer1

# Filter by minimum idle time (Redis 6.2+)
redis-cli XPENDING mystream mygroup IDLE 60000 - + 100
# Only entries idle > 60 seconds (stuck messages)
```

**Concerning patterns:**
- `delivery-count` > 3: message failing repeatedly (consider dead-letter handling)
- `idle-time` > 300000 (5 min): consumer may be dead; use XAUTOCLAIM
- Total pending growing: consumers can't keep up with producers

### XLEN -- Stream Length

```bash
redis-cli XLEN mystream
# Returns: number of entries in stream
```

### XTRIM -- Trim Stream

```bash
# Trim to exact max length
redis-cli XTRIM mystream MAXLEN 1000000

# Trim to approximate max length (more efficient)
redis-cli XTRIM mystream MAXLEN ~ 1000000

# Trim by minimum ID (remove all entries older than ID)
redis-cli XTRIM mystream MINID 1234567890-0
redis-cli XTRIM mystream MINID ~ 1234567890-0
```

### XAUTOCLAIM -- Reclaim Stuck Messages

```bash
redis-cli XAUTOCLAIM mystream mygroup consumer2 60000 0-0
# Args: stream, group, new-consumer, min-idle-ms, start-id
# Transfers messages idle > 60s from any consumer to consumer2
# Returns: [next-cursor, claimed-entries, deleted-entries]
```

## ACL Diagnostics

### ACL LIST -- All User Definitions

```bash
redis-cli ACL LIST
# Returns: full ACL definition for each user
# Example: "user default on nopass ~* &* +@all"
# Example: "user app on >password ~app:* +@read +@write -@dangerous"
```

### ACL WHOAMI -- Current User

```bash
redis-cli ACL WHOAMI
# Returns: current authenticated username
```

### ACL LOG -- Security Event Log

```bash
redis-cli ACL LOG
# Returns: recent auth failures and command denials
# Each entry: count, reason, context, object, username, age-seconds, client-info

redis-cli ACL LOG 10     # last 10 entries
redis-cli ACL LOG RESET  # clear the log

# Reasons:
# auth      -- authentication failure
# command   -- command not allowed
# key       -- key pattern not allowed
# channel   -- pub/sub channel not allowed
```

### ACL CAT -- Command Categories

```bash
redis-cli ACL CAT
# Lists all command categories: read, write, set, sortedset, list, hash, string,
# bitmap, hyperloglog, geo, stream, pubsub, admin, fast, slow, blocking,
# dangerous, connection, transaction, scripting, keyspace, server

redis-cli ACL CAT dangerous
# Lists commands in the 'dangerous' category: FLUSHALL, FLUSHDB, DEBUG, KEYS, etc.
```

### ACL GETUSER -- Specific User Details

```bash
redis-cli ACL GETUSER appuser
# Returns: flags, passwords, commands, keys, channels
```

### ACL DELUSER -- Remove User

```bash
redis-cli ACL DELUSER olduser
# Removes user and disconnects all their active connections
```

### ACL SAVE / LOAD

```bash
redis-cli ACL SAVE    # persist ACL config to file
redis-cli ACL LOAD    # reload ACL config from file
```

## Module Diagnostics

### MODULE LIST -- Loaded Modules

```bash
redis-cli MODULE LIST
# Returns: name, version, path for each loaded module
# Common modules: RedisJSON, RediSearch, RedisTimeSeries, RedisBloom, RedisGraph
```

### MODULE LOADEX -- Load Module with Arguments

```bash
redis-cli MODULE LOADEX /path/to/module.so ARGS arg1 arg2 CONFIG name value
# Loads a module with configuration parameters
```

### MODULE UNLOAD

```bash
redis-cli MODULE UNLOAD modulename
# Unloads a module (if it supports unloading)
```

## Benchmark and Latency Tools

### redis-benchmark -- Performance Testing

```bash
# Default benchmark (50 clients, 100K requests)
redis-benchmark

# Specific test parameters
redis-benchmark -h localhost -p 6379 -c 100 -n 1000000 -d 256 -t get,set
# -c 100: 100 concurrent clients
# -n 1000000: 1 million requests
# -d 256: 256 byte payload
# -t get,set: only test GET and SET

# Pipeline benchmark
redis-benchmark -c 50 -n 1000000 -P 16 -t set
# -P 16: pipeline 16 commands per request

# Cluster mode
redis-benchmark --cluster -h node1 -p 6379 -c 100 -n 1000000

# Specific command benchmark
redis-benchmark -c 50 -n 100000 -r 1000000 ZADD myzset __rand_int__ member:__rand_int__

# CSV output for graphing
redis-benchmark -c 50 -n 100000 --csv -t get,set
```

### redis-cli --latency -- Live Latency Measurement

```bash
# Continuous latency measurement
redis-cli --latency
# Output: min: 0, max: 3, avg: 0.52 (1000 samples)

# Latency with history (shows changes over time)
redis-cli --latency-history
# Output: new measurement every 15 seconds

# Custom interval
redis-cli --latency-history -i 5
# Every 5 seconds

# Latency distribution
redis-cli --latency-dist
# Visual distribution chart
```

### redis-cli --stat -- Live Statistics

```bash
redis-cli --stat
# Continuous output:
# ------- data ------ --------------------- load -------------------- - child -
# keys       mem      clients blocked requests    connections
# 1234567    8.50G    150     0       123456789 (+1234)  567890
# Refreshes every second; shows key count, memory, clients, request rate
```

### redis-cli --pipe -- Bulk Import

```bash
# Pipe Redis protocol from file
cat commands.txt | redis-cli --pipe
# Input format: raw RESP protocol
# Output: All data transferred. Waiting for the last reply...
# errors: 0, replies: 1000000

# Generate RESP protocol for bulk import
echo -ne '*3\r\n$3\r\nSET\r\n$5\r\nmykey\r\n$7\r\nmyvalue\r\n' | redis-cli --pipe
```

### redis-cli --rdb -- Download RDB Snapshot

```bash
redis-cli --rdb dump.rdb
# Downloads a full RDB snapshot from the server
# Useful for backup or analysis on another machine
```

### redis-cli --intrinsic-latency -- System Latency Baseline

```bash
redis-cli --intrinsic-latency 10
# Measures system latency for 10 seconds (no Redis connection)
# Establishes baseline: if system latency is high, Redis can't be low-latency
# Expected: < 1ms for physical hardware, < 5ms for VMs
```

## Automation and Monitoring Scripts

### Comprehensive Health Check

```bash
#!/bin/bash
# redis-full-healthcheck.sh
set -e

HOST=${1:-localhost}
PORT=${2:-6379}
PASS=${3:-}

CLI="redis-cli -h $HOST -p $PORT"
[ -n "$PASS" ] && CLI="$CLI -a $PASS --no-auth-warning"

echo "===== Redis Health Check: $HOST:$PORT ====="
echo "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

# 1. Connectivity
echo "--- Connectivity ---"
PONG=$($CLI PING)
echo "PING: $PONG"
ROLE=$($CLI INFO replication | grep "^role:" | cut -d: -f2 | tr -d '\r')
echo "Role: $ROLE"
VERSION=$($CLI INFO server | grep "^redis_version:" | cut -d: -f2 | tr -d '\r')
echo "Version: $VERSION"
UPTIME=$($CLI INFO server | grep "^uptime_in_days:" | cut -d: -f2 | tr -d '\r')
echo "Uptime: $UPTIME days"
echo ""

# 2. Memory
echo "--- Memory ---"
MEM_USED=$($CLI INFO memory | grep "^used_memory_human:" | cut -d: -f2 | tr -d '\r')
MEM_MAX=$($CLI CONFIG GET maxmemory | tail -1 | tr -d '\r')
MEM_FRAG=$($CLI INFO memory | grep "^mem_fragmentation_ratio:" | cut -d: -f2 | tr -d '\r')
MEM_POLICY=$($CLI CONFIG GET maxmemory-policy | tail -1 | tr -d '\r')
echo "Used: $MEM_USED"
echo "Max: $MEM_MAX"
echo "Fragmentation: $MEM_FRAG"
echo "Policy: $MEM_POLICY"
echo ""

# 3. Clients
echo "--- Clients ---"
CLIENTS=$($CLI INFO clients | grep "^connected_clients:" | cut -d: -f2 | tr -d '\r')
BLOCKED=$($CLI INFO clients | grep "^blocked_clients:" | cut -d: -f2 | tr -d '\r')
MAXCLI=$($CLI CONFIG GET maxclients | tail -1 | tr -d '\r')
echo "Connected: $CLIENTS / $MAXCLI"
echo "Blocked: $BLOCKED"
echo ""

# 4. Performance
echo "--- Performance ---"
OPS=$($CLI INFO stats | grep "^instantaneous_ops_per_sec:" | cut -d: -f2 | tr -d '\r')
HIT=$($CLI INFO stats | grep "^keyspace_hits:" | cut -d: -f2 | tr -d '\r')
MISS=$($CLI INFO stats | grep "^keyspace_misses:" | cut -d: -f2 | tr -d '\r')
EVICT=$($CLI INFO stats | grep "^evicted_keys:" | cut -d: -f2 | tr -d '\r')
REJECTED=$($CLI INFO stats | grep "^rejected_connections:" | cut -d: -f2 | tr -d '\r')
echo "Ops/sec: $OPS"
if [ -n "$HIT" ] && [ -n "$MISS" ] && [ "$((HIT + MISS))" -gt 0 ]; then
    HIT_RATE=$(echo "scale=2; $HIT * 100 / ($HIT + $MISS)" | bc)
    echo "Hit rate: ${HIT_RATE}%"
fi
echo "Evicted keys: $EVICT"
echo "Rejected connections: $REJECTED"
SLOW=$($CLI SLOWLOG LEN | tr -d '\r')
echo "Slow log entries: $SLOW"
echo ""

# 5. Persistence
echo "--- Persistence ---"
RDB_STATUS=$($CLI INFO persistence | grep "^rdb_last_bgsave_status:" | cut -d: -f2 | tr -d '\r')
AOF_ENABLED=$($CLI INFO persistence | grep "^aof_enabled:" | cut -d: -f2 | tr -d '\r')
AOF_STATUS=$($CLI INFO persistence | grep "^aof_last_bgrewrite_status:" | cut -d: -f2 | tr -d '\r')
AOF_WRITE=$($CLI INFO persistence | grep "^aof_last_write_status:" | cut -d: -f2 | tr -d '\r')
FORK=$($CLI INFO persistence | grep "^latest_fork_usec:" | cut -d: -f2 | tr -d '\r')
echo "RDB last save: $RDB_STATUS"
echo "AOF enabled: $AOF_ENABLED"
echo "AOF rewrite status: $AOF_STATUS"
echo "AOF write status: $AOF_WRITE"
echo "Last fork: ${FORK}us"
echo ""

# 6. Replication
echo "--- Replication ---"
if [ "$ROLE" = "master" ]; then
    SLAVES=$($CLI INFO replication | grep "^connected_slaves:" | cut -d: -f2 | tr -d '\r')
    echo "Connected replicas: $SLAVES"
    $CLI INFO replication | grep "^slave[0-9]" | while read line; do
        echo "  $line"
    done
elif [ "$ROLE" = "slave" ]; then
    MHOST=$($CLI INFO replication | grep "^master_host:" | cut -d: -f2 | tr -d '\r')
    MPORT=$($CLI INFO replication | grep "^master_port:" | cut -d: -f2 | tr -d '\r')
    MSTATUS=$($CLI INFO replication | grep "^master_link_status:" | cut -d: -f2 | tr -d '\r')
    MLAG=$($CLI INFO replication | grep "^master_last_io_seconds_ago:" | cut -d: -f2 | tr -d '\r')
    echo "Master: $MHOST:$MPORT"
    echo "Link status: $MSTATUS"
    echo "Last IO: ${MLAG}s ago"
fi
echo ""

# 7. Keyspace
echo "--- Keyspace ---"
$CLI INFO keyspace
echo ""

echo "===== Health Check Complete ====="
```

### Prometheus-Compatible Metrics Script

```bash
#!/bin/bash
# redis-metrics.sh -- outputs metrics in Prometheus text format
# Run as: while true; do bash redis-metrics.sh > /var/lib/node_exporter/redis.prom; sleep 15; done

HOST=${1:-localhost}
PORT=${2:-6379}
CLI="redis-cli -h $HOST -p $PORT"

# Helper to get INFO field
get_info() {
    $CLI INFO "$1" 2>/dev/null | grep "^$2:" | cut -d: -f2 | tr -d '\r'
}

echo "# HELP redis_up Redis instance is up"
echo "# TYPE redis_up gauge"
PONG=$($CLI PING 2>/dev/null)
if [ "$PONG" = "PONG" ]; then
    echo "redis_up 1"
else
    echo "redis_up 0"
    exit 0
fi

echo "# HELP redis_uptime_seconds Uptime in seconds"
echo "# TYPE redis_uptime_seconds gauge"
echo "redis_uptime_seconds $(get_info server uptime_in_seconds)"

echo "# HELP redis_connected_clients Connected client count"
echo "# TYPE redis_connected_clients gauge"
echo "redis_connected_clients $(get_info clients connected_clients)"

echo "# HELP redis_blocked_clients Blocked client count"
echo "# TYPE redis_blocked_clients gauge"
echo "redis_blocked_clients $(get_info clients blocked_clients)"

echo "# HELP redis_used_memory_bytes Used memory bytes"
echo "# TYPE redis_used_memory_bytes gauge"
echo "redis_used_memory_bytes $(get_info memory used_memory)"

echo "# HELP redis_used_memory_rss_bytes RSS memory bytes"
echo "# TYPE redis_used_memory_rss_bytes gauge"
echo "redis_used_memory_rss_bytes $(get_info memory used_memory_rss)"

echo "# HELP redis_mem_fragmentation_ratio Memory fragmentation ratio"
echo "# TYPE redis_mem_fragmentation_ratio gauge"
echo "redis_mem_fragmentation_ratio $(get_info memory mem_fragmentation_ratio)"

echo "# HELP redis_ops_per_sec Instantaneous operations per second"
echo "# TYPE redis_ops_per_sec gauge"
echo "redis_ops_per_sec $(get_info stats instantaneous_ops_per_sec)"

echo "# HELP redis_keyspace_hits_total Total keyspace hits"
echo "# TYPE redis_keyspace_hits_total counter"
echo "redis_keyspace_hits_total $(get_info stats keyspace_hits)"

echo "# HELP redis_keyspace_misses_total Total keyspace misses"
echo "# TYPE redis_keyspace_misses_total counter"
echo "redis_keyspace_misses_total $(get_info stats keyspace_misses)"

echo "# HELP redis_evicted_keys_total Total evicted keys"
echo "# TYPE redis_evicted_keys_total counter"
echo "redis_evicted_keys_total $(get_info stats evicted_keys)"

echo "# HELP redis_rejected_connections_total Total rejected connections"
echo "# TYPE redis_rejected_connections_total counter"
echo "redis_rejected_connections_total $(get_info stats rejected_connections)"

echo "# HELP redis_latest_fork_usec Latest fork duration microseconds"
echo "# TYPE redis_latest_fork_usec gauge"
echo "redis_latest_fork_usec $(get_info persistence latest_fork_usec)"

echo "# HELP redis_connected_slaves Connected replica count"
echo "# TYPE redis_connected_slaves gauge"
echo "redis_connected_slaves $(get_info replication connected_slaves)"

echo "# HELP redis_slowlog_length Slow log entry count"
echo "# TYPE redis_slowlog_length gauge"
echo "redis_slowlog_length $($CLI SLOWLOG LEN 2>/dev/null | tr -d '\r')"
```

### Cluster Health Monitor

```bash
#!/bin/bash
# redis-cluster-monitor.sh
NODE=${1:-localhost:6379}
HOST=$(echo $NODE | cut -d: -f1)
PORT=$(echo $NODE | cut -d: -f2)
CLI="redis-cli -h $HOST -p $PORT -c"

echo "===== Cluster Health: $NODE ====="

# Cluster state
STATE=$($CLI CLUSTER INFO | grep "^cluster_state:" | cut -d: -f2 | tr -d '\r')
echo "State: $STATE"

SLOTS_OK=$($CLI CLUSTER INFO | grep "^cluster_slots_ok:" | cut -d: -f2 | tr -d '\r')
SLOTS_PFAIL=$($CLI CLUSTER INFO | grep "^cluster_slots_pfail:" | cut -d: -f2 | tr -d '\r')
SLOTS_FAIL=$($CLI CLUSTER INFO | grep "^cluster_slots_fail:" | cut -d: -f2 | tr -d '\r')
KNOWN=$($CLI CLUSTER INFO | grep "^cluster_known_nodes:" | cut -d: -f2 | tr -d '\r')
SIZE=$($CLI CLUSTER INFO | grep "^cluster_size:" | cut -d: -f2 | tr -d '\r')
echo "Slots OK: $SLOTS_OK / 16384"
echo "Slots PFAIL: $SLOTS_PFAIL"
echo "Slots FAIL: $SLOTS_FAIL"
echo "Known nodes: $KNOWN"
echo "Masters: $SIZE"

echo ""
echo "--- Node Status ---"
$CLI CLUSTER NODES | while read line; do
    ID=$(echo $line | awk '{print $1}' | cut -c1-8)
    ADDR=$(echo $line | awk '{print $2}' | cut -d@ -f1)
    FLAGS=$(echo $line | awk '{print $3}')
    SLOTS=$(echo $line | awk '{for(i=9;i<=NF;i++) printf $i" "}')
    echo "$ID $ADDR [$FLAGS] $SLOTS"
done

echo ""
echo "--- Slot Distribution ---"
$CLI CLUSTER NODES | grep "master" | while read line; do
    ADDR=$(echo $line | awk '{print $2}' | cut -d@ -f1)
    SLOTS=$(echo $line | awk '{for(i=9;i<=NF;i++) printf $i" "}')
    # Count total slots
    SLOT_COUNT=0
    for range in $SLOTS; do
        if echo "$range" | grep -q "-"; then
            START=$(echo $range | cut -d- -f1)
            END=$(echo $range | cut -d- -f2)
            SLOT_COUNT=$((SLOT_COUNT + END - START + 1))
        else
            SLOT_COUNT=$((SLOT_COUNT + 1))
        fi
    done
    echo "$ADDR: $SLOT_COUNT slots"
done

echo ""
redis-cli --cluster check $HOST:$PORT 2>/dev/null | tail -20
```

### Daily Diagnostic Report

```bash
#!/bin/bash
# redis-daily-report.sh -- comprehensive daily diagnostic snapshot
HOST=${1:-localhost}
PORT=${2:-6379}
CLI="redis-cli -h $HOST -p $PORT"

echo "===== Redis Daily Report ====="
echo "Host: $HOST:$PORT"
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Top 10 Slow Commands ---"
$CLI SLOWLOG GET 10

echo ""
echo "--- Memory Analysis ---"
$CLI MEMORY DOCTOR

echo ""
echo "--- Big Keys (sampled) ---"
$CLI --bigkeys 2>/dev/null | grep -E "Biggest|^$"

echo ""
echo "--- Keyspace Summary ---"
$CLI INFO keyspace

echo ""
echo "--- Command Statistics (top 10 by total time) ---"
$CLI INFO commandstats | sort -t= -k3 -rn | head -10

echo ""
echo "--- Error Statistics ---"
$CLI INFO errorstats

echo ""
echo "--- Client Summary ---"
echo "Total connections: $($CLI INFO stats | grep total_connections_received | cut -d: -f2 | tr -d '\r')"
echo "Current connections: $($CLI INFO clients | grep connected_clients | cut -d: -f2 | tr -d '\r')"
echo "Max input buffer: $($CLI INFO clients | grep client_recent_max_input_buffer | cut -d: -f2 | tr -d '\r')"
echo "Max output buffer: $($CLI INFO clients | grep client_recent_max_output_buffer | cut -d: -f2 | tr -d '\r')"

echo ""
echo "--- Persistence Summary ---"
$CLI INFO persistence | grep -E "^(rdb_last|aof_last|aof_current_size|aof_enabled|latest_fork)"

echo ""
echo "===== End Daily Report ====="
```
