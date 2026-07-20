# Memcached Diagnostics Reference

## Connecting for Diagnostics

### telnet / nc (netcat)

The primary diagnostic interface for Memcached is the text protocol over TCP:

```bash
# Connect with telnet
telnet localhost 11211

# Connect with netcat (preferred for scripting)
echo "stats" | nc localhost 11211

# Connect with netcat, keep session open
nc localhost 11211
# Then type commands interactively

# One-liner to get specific stat
echo "stats" | nc -w 2 localhost 11211 | grep "STAT get_hits"

# Connect to remote host
echo "stats" | nc 10.0.0.1 11211
```

### memcached-tool

The `memcached-tool` script (ships with Memcached source) provides formatted output:

```bash
# Display slab class information (default)
memcached-tool localhost:11211 display

# Dump all stats
memcached-tool localhost:11211 stats

# Dump settings
memcached-tool localhost:11211 settings

# Move slabs (manual rebalance)
memcached-tool localhost:11211 move <src_class> <dst_class>

# Dump keys from a slab class (debugging)
memcached-tool localhost:11211 dump
```

### Binary Protocol Diagnostic Tools

```bash
# memcstat (from libmemcached-tools)
memcstat --servers=localhost:11211

# memccat (get a key value)
memccat --servers=localhost:11211 mykey

# memcexist (check if key exists)
memcexist --servers=localhost:11211 mykey

# memccp (copy values from file to cache)
memccp --servers=localhost:11211 /tmp/myfile --set --expire=3600

# memcflush (flush all data)
memcflush --servers=localhost:11211

# memcrm (delete a key)
memcrm --servers=localhost:11211 mykey

# memcslap (benchmark)
memcslap --servers=localhost:11211 --concurrency=100 --test=get
```

## Core Stats Command

### stats -- General Server Statistics

```bash
echo "stats" | nc localhost 11211
```

| Stat | Meaning | Healthy Values / Notes |
|---|---|---|
| `pid` | Process ID | Verify expected process |
| `uptime` | Seconds since start | Low value = recent restart |
| `time` | Current Unix timestamp | Check clock sync across nodes |
| `version` | Memcached version | Verify expected version (1.6.x) |
| `libevent` | libevent version | -- |
| `pointer_size` | 32 or 64 bit | Should be 64 |
| `rusage_user` | CPU time (user) in seconds | Increasing = active processing |
| `rusage_system` | CPU time (system) in seconds | High = kernel overhead |
| `max_connections` | Max connections setting (-c) | Should match production requirement |
| `curr_connections` | Current open connections | Alert if > 80% of max |
| `total_connections` | Total connections since start | Rate = connection churn |
| `rejected_connections` | Connections rejected (maxconns) | > 0 = connection exhaustion |
| `connection_structures` | Allocated connection structures | -- |
| `reserved_fds` | File descriptors reserved for internal use | Default ~20 |
| `cmd_get` | Total GET commands | Primary read metric |
| `cmd_set` | Total SET commands | Primary write metric |
| `cmd_flush` | Total FLUSH commands | Should be 0 or very rare in production |
| `cmd_touch` | Total TOUCH commands | TTL refresh operations |
| `cmd_meta` | Total meta commands (1.6.x) | Meta protocol usage |
| `get_hits` | Successful GETs (cache hits) | Higher = better |
| `get_misses` | Failed GETs (cache misses) | Lower = better |
| `get_expired` | GETs on expired items | Item expired since last crawl |
| `get_flushed` | GETs on flushed items | Items invalidated by flush_all |
| `delete_hits` | Successful DELETEs | Item existed and was deleted |
| `delete_misses` | DELETE on non-existent key | -- |
| `incr_hits` | Successful INCR | -- |
| `incr_misses` | INCR on non-existent key | Might indicate counter key expired |
| `decr_hits` | Successful DECR | -- |
| `decr_misses` | DECR on non-existent key | -- |
| `cas_hits` | Successful CAS operations | -- |
| `cas_misses` | CAS on non-existent key | -- |
| `cas_badval` | CAS with wrong CAS token | Indicates contention |
| `touch_hits` | Successful TOUCH operations | -- |
| `touch_misses` | TOUCH on non-existent key | -- |
| `auth_cmds` | SASL authentication attempts | -- |
| `auth_errors` | Failed authentication attempts | > 0 = investigate |
| `evictions` | Items evicted (LRU) | Non-zero = memory pressure |
| `reclaimed` | Items reclaimed (expired, reused) | Normal; expired items being recycled |
| `bytes_read` | Total bytes read from network | Network ingress |
| `bytes_written` | Total bytes written to network | Network egress |
| `limit_maxbytes` | Max memory configured (-m) | -- |
| `bytes` | Current bytes used for items | Current memory usage |
| `curr_items` | Current number of items stored | Active cache size |
| `total_items` | Total items stored since start | Cumulative |
| `slab_global_page_pool` | Pages in global free pool | > 0 = free memory available |
| `expired_unfetched` | Expired items never accessed | Cached but never read |
| `evicted_unfetched` | Evicted items never accessed | Stored then evicted before any GET |
| `evicted_active` | Evicted items that were recently active | Indicates insufficient memory for hot data |
| `crawler_reclaimed` | Items reclaimed by LRU crawler | Background expiry reclamation |
| `crawler_items_checked` | Items checked by LRU crawler | Crawler activity level |
| `lrutail_reflocked` | Items at LRU tail with active refcount | Locked items preventing eviction |
| `moves_to_cold` | Items moved from HOT/WARM to COLD | LRU maintainer activity |
| `moves_to_warm` | Items promoted from COLD to WARM | Active items being rescued |
| `moves_within_lru` | Items repositioned within same LRU | Bump activity |
| `direct_reclaims` | Direct reclaims (not via background thread) | Should be low; high = LRU maintainer falling behind |
| `lru_bumps_dropped` | LRU bump operations dropped | Contention; items too hot to bump |
| `listen_disabled_num` | Times accept() was disabled (maxconns reached) | > 0 = connection exhaustion |
| `time_in_listen_disabled_us` | Microseconds with accept() disabled | Duration of connection exhaustion |
| `threads` | Number of worker threads | Matches -t setting |
| `hash_power_level` | Current hash table size (2^N) | Auto-grows |
| `hash_is_expanding` | Whether hash table is expanding | Temporary; should resolve |
| `slab_reassign_running` | Whether slab reassignment is in progress | -- |
| `slabs_moved` | Pages moved between slab classes | Slab rebalancer activity |
| `log_worker_dropped` | Log entries dropped (logger overflow) | > 0 = increase logger buffer |
| `log_worker_written` | Log entries written | -- |

### Computed Metrics from stats

```bash
# Hit ratio calculation
HIT_RATIO = get_hits / (get_hits + get_misses) * 100

# Eviction rate (per second)
EVICTION_RATE = (evictions_now - evictions_prev) / interval_seconds

# Memory utilization
MEMORY_PCT = bytes / limit_maxbytes * 100

# Connection utilization
CONN_PCT = curr_connections / max_connections * 100

# Fill rate (items per second)
FILL_RATE = (total_items_now - total_items_prev) / interval_seconds

# Read/write ratio
RW_RATIO = cmd_get / cmd_set

# Average item size
AVG_ITEM_SIZE = bytes / curr_items

# Wasted cache ratio (items stored but never read before eviction/expiry)
WASTE_RATIO = (evicted_unfetched + expired_unfetched) / total_items * 100
```

## Stats Items -- Per-Slab-Class Item Statistics

```bash
echo "stats items" | nc localhost 11211
```

Output format: `STAT items:<slab_class>:<stat_name> <value>`

| Stat | Meaning | Notes |
|---|---|---|
| `number` | Items in this slab class | Active items |
| `number_hot` | Items in HOT LRU queue | Recently written |
| `number_warm` | Items in WARM LRU queue | Actively accessed |
| `number_cold` | Items in COLD LRU queue | Eviction candidates |
| `number_temp` | Items in TEMP LRU queue | Short-TTL items |
| `age_hot` | Age of oldest HOT item (seconds) | -- |
| `age_warm` | Age of oldest WARM item (seconds) | -- |
| `age` | Age of oldest item in class (seconds) | Low age = high eviction rate |
| `mem_requested` | Actual bytes requested (not chunk size) | Compare with chunk_size * number for waste |
| `evicted` | Items evicted from this class | Non-zero = class under pressure |
| `evicted_nonzero` | Evicted items with remaining TTL | Items evicted before expiry (memory pressure) |
| `evicted_time` | Seconds since last evicted item was stored | Low = items barely survive |
| `evicted_unfetched` | Evicted items never GET'd | Useless caching: stored but never read |
| `outofmemory` | Times new item allocation failed | Should be 0; indicates slab pressure |
| `tailrepairs` | Times LRU tail was repaired | Should be 0; non-zero = internal issue |
| `reclaimed` | Expired items reclaimed for reuse | Normal recycling |
| `expired_unfetched` | Expired items never GET'd | Useless caching |
| `crawler_reclaimed` | Items reclaimed by LRU crawler | Background reclamation |
| `crawler_items_checked` | Items checked by crawler in this class | -- |
| `lrutail_reflocked` | Tail items with active references | Prevents eviction |
| `moves_to_cold` | Items moved to COLD queue | LRU aging |
| `moves_to_warm` | Items promoted to WARM queue | Active items |
| `moves_within_lru` | Items repositioned in same queue | Bumps |
| `direct_reclaims` | Foreground reclaims (blocking) | Should be 0; high = maintainer behind |

**Per-class analysis commands:**
```bash
# Find classes with highest eviction rates
echo "stats items" | nc localhost 11211 | grep "evicted " | sort -t: -k2 -n

# Find classes with items never fetched
echo "stats items" | nc localhost 11211 | grep "evicted_unfetched" | sort -t: -k2 -n

# Find classes with shortest item lifespans
echo "stats items" | nc localhost 11211 | grep "evicted_time" | sort -t: -k2 -n

# Check HOT/WARM/COLD distribution per class
echo "stats items" | nc localhost 11211 | grep -E "number_hot|number_warm|number_cold" | head -30
```

## Stats Slabs -- Per-Slab-Class Memory Statistics

```bash
echo "stats slabs" | nc localhost 11211
```

Output format: `STAT <slab_class>:<stat_name> <value>` plus global stats.

| Stat | Meaning | Notes |
|---|---|---|
| `chunk_size` | Bytes per chunk in this class | Fixed at startup based on growth factor |
| `chunks_per_page` | Chunks per 1 MB page | `page_size / chunk_size` |
| `total_pages` | Pages assigned to this class | Pages are 1 MB each |
| `total_chunks` | Total chunks in this class | `total_pages * chunks_per_page` |
| `used_chunks` | Chunks currently in use | Active items |
| `free_chunks` | Chunks available for new items | Free space in this class |
| `free_chunks_end` | Free chunks at end of last page | Partial page utilization |
| `get_hits` | GET hits in this class | Per-class hit tracking |
| `cmd_set` | SET commands to this class | Per-class write tracking |
| `delete_hits` | DELETE hits in this class | Per-class delete tracking |
| `incr_hits` | INCR hits in this class | -- |
| `decr_hits` | DECR hits in this class | -- |
| `cas_hits` | CAS hits in this class | -- |
| `cas_badval` | CAS failures in this class | Contention per class |
| `touch_hits` | TOUCH hits in this class | -- |
| `mem_requested` | Actual bytes requested | Less than `used_chunks * chunk_size` (waste) |

**Global slab stats:**
| Stat | Meaning |
|---|---|
| `active_slabs` | Number of slab classes with at least one page |
| `total_malloced` | Total bytes allocated for slab pages |

**Slab analysis commands:**
```bash
# Calculate waste per slab class
echo "stats slabs" | nc localhost 11211
# Waste = (used_chunks * chunk_size) - mem_requested

# Find classes with most free chunks (over-provisioned)
echo "stats slabs" | nc localhost 11211 | grep "free_chunks " | sort -t: -k2 -n -r

# Find classes with zero free chunks (fully utilized)
echo "stats slabs" | nc localhost 11211 | grep "free_chunks " | grep " 0$"

# Total memory allocation
echo "stats slabs" | nc localhost 11211 | grep "total_malloced"

# Calculate slab utilization per class
# utilization% = used_chunks / total_chunks * 100
```

## Stats Sizes -- Item Size Distribution

```bash
# Enable size tracking (has performance impact; off by default)
echo "stats sizes_enable" | nc localhost 11211

# Get size distribution
echo "stats sizes" | nc localhost 11211
# Output: STAT <size_bucket> <count>
# Shows how many items fall into each 32-byte size bucket

# Disable size tracking
echo "stats sizes_disable" | nc localhost 11211
```

**Output example:**
```
STAT 96 12345       # 12,345 items in the 64-96 byte range
STAT 128 8901       # 8,901 items in the 97-128 byte range
STAT 192 4567       # 4,567 items in the 129-192 byte range
...
END
```

**Use case:** Determine optimal growth factor (`-f`) by analyzing the actual distribution of item sizes. If items cluster around specific sizes, a smaller growth factor reduces waste.

**WARNING:** `stats sizes` was historically a blocking operation that locked the cache. In Memcached 1.6.x, it uses a separate tracking mechanism that must be explicitly enabled with `stats sizes_enable`. Still, enabling it adds overhead per SET operation.

## Stats Cachedump -- Dump Keys from a Slab Class

```bash
# Dump up to <limit> keys from slab class <class_id>
echo "stats cachedump <class_id> <limit>" | nc localhost 11211

# Example: dump 100 keys from slab class 5
echo "stats cachedump 5 100" | nc localhost 11211
# Output:
# ITEM key1 [120 b; 1700000000 s]
# ITEM key2 [115 b; 1700000100 s]
# ...
# END
```

**Output format:** `ITEM <key> [<size> b; <exptime> s]`
- `size`: item size in bytes
- `exptime`: Unix timestamp of expiration (0 = never)

**Limitations:**
- Only returns keys from the specified slab class
- Limited to `CRAWLER_MAX_KEYS` per call (default ~200)
- Does not return values, only keys and metadata
- Intended for debugging, not production use
- Use `lru_crawler metadump` for more comprehensive key inspection

## Stats Settings -- Server Configuration

```bash
echo "stats settings" | nc localhost 11211
```

| Setting | Meaning | Default |
|---|---|---|
| `maxbytes` | Max memory in bytes | 67108864 (64 MB) |
| `maxconns` | Max connections | 1024 |
| `tcpport` | TCP port | 11211 |
| `udpport` | UDP port | 0 (disabled by default in 1.6.x) |
| `inter` | Listen interface | 0.0.0.0 (or as configured) |
| `verbosity` | Log verbosity level | 0 |
| `oldest` | Age of oldest item (seconds) | -- |
| `evictions` | Whether evictions are enabled | on |
| `domain_socket` | Unix socket path | (empty if not used) |
| `umask` | Unix socket permissions mask | 700 |
| `growth_factor` | Slab growth factor | 1.25 |
| `chunk_size` | Minimum chunk size | 48 |
| `num_threads` | Worker threads | 4 |
| `num_threads_per_udp` | UDP threads | 0 |
| `stat_key_prefix` | Prefix for stats detail | : |
| `detail_enabled` | Whether per-prefix stats are active | no |
| `reqs_per_event` | Max requests per event loop | 20 |
| `cas_enabled` | CAS support | yes |
| `tcp_backlog` | TCP listen backlog | 1024 |
| `binding_protocol` | Protocol (auto/ascii/binary) | auto |
| `auth_enabled_sasl` | SASL enabled | no (or yes if -S) |
| `item_size_max` | Max item size in bytes | 1048576 (1 MB) |
| `maxconns_fast` | Fast maxconns rejection | yes |
| `hashpower_init` | Initial hash power | 0 (auto) |
| `slab_reassign` | Slab reassignment enabled | yes (with modern) |
| `slab_automove` | Slab automove mode | 1 (conservative) |
| `slab_automove_ratio` | Automove trigger ratio | 0.80 |
| `slab_automove_window` | Automove sample window | 30 |
| `slab_chunk_max` | Max bytes per slab page | 524288 |
| `lru_maintainer_thread` | LRU maintainer enabled | yes |
| `lru_crawler` | LRU crawler enabled | yes |
| `lru_segmented` | Segmented LRU enabled | yes |
| `hot_lru_pct` | % of slab memory for HOT queue | 20 |
| `warm_lru_pct` | % of slab memory for WARM queue | 40 |
| `hot_max_factor` | Max HOT/WARM ratio | 0.20 |
| `warm_max_factor` | Max WARM/COLD ratio | 2.00 |
| `temp_lru` | Temporary LRU enabled | yes |
| `temporary_ttl` | Max TTL for TEMP queue | 61 |
| `idle_timeout` | Idle connection timeout | 0 (disabled) |
| `watcher_logbuf_size` | Logger buffer size | 262144 |
| `worker_logbuf_size` | Per-worker logger buffer | 65536 |
| `track_sizes` | Size tracking enabled | no |
| `inline_ascii_response` | Inline ASCII optimization | yes |
| `ext_path` | Extstore path | (empty if not used) |
| `ext_item_size` | Extstore min item size | 0 |
| `ext_item_age` | Extstore min item age | 0 |
| `ext_low_ttl` | Extstore low-TTL threshold | 0 |
| `ext_wbuf_size` | Extstore write buffer | 4194304 |

## Stats Conns -- Per-Connection Details

```bash
echo "stats conns" | nc localhost 11211
```

Output format: `STAT <fd>:<stat_name> <value>`

| Stat | Meaning |
|---|---|
| `addr` | Client address (IP:port) or Unix socket |
| `state` | Connection state (conn_listening, conn_new_cmd, conn_read, conn_write, etc.) |
| `secs_since_last_cmd` | Seconds since last command on this connection |

**Use cases:**
```bash
# Find idle connections (idle > 300 seconds)
echo "stats conns" | nc localhost 11211 | grep "secs_since_last_cmd" | awk -F'[ :]' '{if ($NF > 300) print}'

# Count connections by client IP
echo "stats conns" | nc localhost 11211 | grep ":addr " | awk '{print $3}' | cut -d: -f1 | sort | uniq -c | sort -rn

# Count connections in each state
echo "stats conns" | nc localhost 11211 | grep ":state " | awk '{print $3}' | sort | uniq -c | sort -rn
```

## Stats Detail -- Per-Prefix Statistics

```bash
# Enable per-prefix statistics
echo "stats detail on" | nc localhost 11211

# Dump per-prefix statistics
echo "stats detail dump" | nc localhost 11211
# Output: PREFIX <prefix> get <N> hit <N> set <N> del <N>

# Disable per-prefix statistics
echo "stats detail off" | nc localhost 11211
```

**Output example:**
```
PREFIX user get 150000 hit 120000 set 30000 del 5000
PREFIX session get 80000 hit 75000 set 20000 del 10000
PREFIX product get 50000 hit 40000 set 15000 del 2000
END
```

**Use cases:**
- Identify which key prefix (namespace) has the highest traffic
- Calculate per-prefix hit ratios
- Find prefixes with high miss rates (inefficient caching)
- The prefix delimiter is configurable: `-o stat_key_prefix=:`

**Per-prefix hit ratio:**
```bash
# Parse stats detail dump for per-prefix hit ratios
echo "stats detail dump" | nc localhost 11211 | awk '{
  prefix=$2; gets=$4; hits=$6;
  if (gets > 0) ratio=hits/gets*100; else ratio=0;
  printf "%-30s gets=%-10s hits=%-10s ratio=%.1f%%\n", prefix, gets, hits, ratio
}'
```

## LRU Crawler Commands

### Crawler Control

```bash
# Enable the LRU crawler
echo "lru_crawler enable" | nc localhost 11211

# Disable the LRU crawler
echo "lru_crawler disable" | nc localhost 11211

# Crawl a specific slab class (reclaim expired items)
echo "lru_crawler crawl 1" | nc localhost 11211
echo "lru_crawler crawl 1,2,3,4,5" | nc localhost 11211
echo "lru_crawler crawl all" | nc localhost 11211

# Set crawler sleep interval (microseconds between items)
echo "lru_crawler sleep 100" | nc localhost 11211

# Set max items to crawl per run
echo "lru_crawler tocrawl 0" | nc localhost 11211   # 0 = no limit
```

### Metadump -- Comprehensive Key Inspection

```bash
# Dump all key metadata (key, size, exptime, last access, slab class)
echo "lru_crawler metadump all" | nc localhost 11211

# Dump metadata for specific slab class
echo "lru_crawler metadump 5" | nc localhost 11211

# Dump with specific parameters
echo "lru_crawler metadump hash" | nc localhost 11211   # dump by hash table order
```

**Output format:**
```
key=mykey exp=1700000000 la=1699999500 cas=12345 fetch=yes cls=5 size=240
key=other exp=-1 la=1699998000 cas=12346 fetch=no cls=3 size=152
```

| Field | Meaning |
|---|---|
| `key` | Item key |
| `exp` | Expiration timestamp (-1 = no expiry) |
| `la` | Last access timestamp |
| `cas` | CAS token |
| `fetch` | Whether item was ever fetched (yes/no) |
| `cls` | Slab class ID |
| `size` | Chunk size (not item size) |

**Analysis examples:**
```bash
# Count items per slab class
echo "lru_crawler metadump all" | nc localhost 11211 | grep -oP 'cls=\d+' | sort | uniq -c | sort -rn

# Find items that were never fetched (wasted cache)
echo "lru_crawler metadump all" | nc localhost 11211 | grep "fetch=no" | wc -l

# Find items expiring in the next hour
NOW=$(date +%s)
HOUR_LATER=$((NOW + 3600))
echo "lru_crawler metadump all" | nc localhost 11211 | awk -v now="$NOW" -v later="$HOUR_LATER" '
  /exp=[0-9]/ { match($0, /exp=([0-9]+)/, a); if (a[1] > now && a[1] < later) print }'

# Find items with no expiration
echo "lru_crawler metadump all" | nc localhost 11211 | grep "exp=-1" | wc -l

# Key prefix distribution
echo "lru_crawler metadump all" | nc localhost 11211 | grep -oP 'key=\S+' | cut -d: -f1 | sed 's/key=//' | sort | uniq -c | sort -rn | head -20
```

## Memory Analysis Commands

### Calculating Memory Waste

```bash
# Step 1: Get per-class memory stats
echo "stats slabs" | nc localhost 11211

# Step 2: For each class, calculate:
# allocated = total_chunks * chunk_size
# requested = mem_requested
# waste = allocated - requested
# waste_pct = waste / allocated * 100

# One-liner to calculate waste per class:
echo "stats slabs" | nc localhost 11211 | paste - - - - - - - - - - - - - - - - | awk '
{
  for (i=1; i<=NF; i++) {
    split($i, a, " ");
    if (a[2] ~ /chunk_size/) chunk=a[3];
    if (a[2] ~ /used_chunks/) used=a[3];
    if (a[2] ~ /mem_requested/) req=a[3];
  }
  if (used > 0 && chunk > 0) {
    alloc = used * chunk;
    waste = alloc - req;
    pct = (waste / alloc) * 100;
    printf "Allocated: %10d  Requested: %10d  Waste: %10d (%.1f%%)\n", alloc, req, waste, pct;
  }
}'
```

### Memory Utilization Summary

```bash
# Quick memory overview
echo "stats" | nc localhost 11211 | grep -E "bytes |limit_maxbytes|curr_items|total_items|evictions"

# Detailed: memory by slab class
echo "stats slabs" | nc localhost 11211 | grep -E "total_pages|chunk_size|used_chunks|free_chunks|mem_requested"

# Free memory remaining
# free_memory = limit_maxbytes - bytes - connection_overhead
```

### Slab Utilization Report

```bash
#!/bin/bash
# slab-report.sh -- Slab utilization report

HOST="${1:-localhost}"
PORT="${2:-11211}"

echo "=== Slab Utilization Report ==="
echo "stats slabs" | nc -w 2 "$HOST" "$PORT" | awk '
/^STAT [0-9]+:chunk_size/ { split($2, a, ":"); cls=a[1]; chunk[cls]=$3 }
/^STAT [0-9]+:total_pages/ { split($2, a, ":"); cls=a[1]; pages[cls]=$3 }
/^STAT [0-9]+:total_chunks/ { split($2, a, ":"); cls=a[1]; total[cls]=$3 }
/^STAT [0-9]+:used_chunks/ { split($2, a, ":"); cls=a[1]; used[cls]=$3 }
/^STAT [0-9]+:free_chunks/ { split($2, a, ":"); cls=a[1]; free[cls]=$3 }
/^STAT [0-9]+:mem_requested/ { split($2, a, ":"); cls=a[1]; req[cls]=$3 }
END {
  printf "%-5s %-10s %-8s %-10s %-10s %-10s %-8s %-12s\n",
    "Class", "ChunkSize", "Pages", "TotalChk", "UsedChk", "FreeChk", "Util%", "MemRequested"
  for (cls in chunk) {
    if (total[cls] > 0) util = used[cls]/total[cls]*100; else util = 0
    printf "%-5s %-10s %-8s %-10s %-10s %-10s %-8.1f %-12s\n",
      cls, chunk[cls], pages[cls], total[cls], used[cls], free[cls], util, req[cls]
  }
}'
```

## Hit Ratio Analysis

### Overall Hit Ratio

```bash
# Get cumulative hit ratio
echo "stats" | nc localhost 11211 | awk '
/get_hits/ { hits=$3 }
/get_misses/ { misses=$3 }
END {
  total = hits + misses
  if (total > 0) ratio = hits / total * 100
  printf "Hits: %s  Misses: %s  Total: %s  Hit Ratio: %.2f%%\n", hits, misses, total, ratio
}'
```

### Interval Hit Ratio (Rolling Window)

```bash
#!/bin/bash
# hit-ratio-monitor.sh -- Monitor hit ratio every N seconds

HOST="${1:-localhost}"
PORT="${2:-11211}"
INTERVAL="${3:-5}"

PREV_HITS=0
PREV_MISSES=0

while true; do
    STATS=$(echo "stats" | nc -w 2 "$HOST" "$PORT")
    HITS=$(echo "$STATS" | grep "STAT get_hits" | awk '{print $3}' | tr -d '\r')
    MISSES=$(echo "$STATS" | grep "STAT get_misses" | awk '{print $3}' | tr -d '\r')
    
    if [ "$PREV_HITS" -gt 0 ]; then
        DELTA_HITS=$((HITS - PREV_HITS))
        DELTA_MISSES=$((MISSES - PREV_MISSES))
        DELTA_TOTAL=$((DELTA_HITS + DELTA_MISSES))
        if [ "$DELTA_TOTAL" -gt 0 ]; then
            RATIO=$(echo "scale=2; $DELTA_HITS * 100 / $DELTA_TOTAL" | bc)
            OPS=$((DELTA_TOTAL / INTERVAL))
            echo "$(date '+%H:%M:%S') Hit ratio: ${RATIO}%  Ops/sec: $OPS  (hits=$DELTA_HITS misses=$DELTA_MISSES)"
        fi
    fi
    
    PREV_HITS=$HITS
    PREV_MISSES=$MISSES
    sleep "$INTERVAL"
done
```

### Per-Prefix Hit Ratio

```bash
# Enable detail tracking
echo "stats detail on" | nc localhost 11211

# Wait for data to accumulate, then dump
echo "stats detail dump" | nc localhost 11211 | awk '{
  if ($1 == "PREFIX") {
    prefix=$2; gets=$4; hits=$6;
    if (gets > 0) ratio=hits/gets*100; else ratio=0;
    printf "%-30s gets=%-10s hits=%-10s ratio=%6.2f%%\n", prefix, gets, hits, ratio
  }
}' | sort -t= -k4 -n
```

## Eviction Analysis

### Eviction Rate Over Time

```bash
#!/bin/bash
# eviction-monitor.sh -- Monitor eviction rate

HOST="${1:-localhost}"
PORT="${2:-11211}"
INTERVAL="${3:-5}"

PREV=0
while true; do
    EVICTIONS=$(echo "stats" | nc -w 2 "$HOST" "$PORT" | grep "STAT evictions" | awk '{print $3}' | tr -d '\r')
    if [ "$PREV" -gt 0 ]; then
        DELTA=$((EVICTIONS - PREV))
        RATE=$((DELTA / INTERVAL))
        echo "$(date '+%H:%M:%S') Evictions: $DELTA in ${INTERVAL}s (${RATE}/sec)  Total: $EVICTIONS"
    fi
    PREV=$EVICTIONS
    sleep "$INTERVAL"
done
```

### Per-Class Eviction Analysis

```bash
# Which slab classes are evicting?
echo "stats items" | nc localhost 11211 | grep ":evicted " | awk -F'[: ]' '{
  cls=$3; evicted=$4;
  if (evicted > 0) printf "Class %s: %s evictions\n", cls, evicted
}' | sort -t: -k2 -n -r

# Are items being evicted before being read?
echo "stats items" | nc localhost 11211 | grep "evicted_unfetched" | awk -F'[: ]' '{
  cls=$3; unfetched=$4;
  if (unfetched > 0) printf "Class %s: %s evicted-unfetched (wasted)\n", cls, unfetched
}'

# How old are evicted items?
echo "stats items" | nc localhost 11211 | grep "evicted_time" | awk -F'[: ]' '{
  cls=$3; age=$4;
  if (age > 0) printf "Class %s: evicted items were %s seconds old\n", cls, age
}'

# Items evicted with remaining TTL (forced out)
echo "stats items" | nc localhost 11211 | grep "evicted_nonzero" | awk -F'[: ]' '{
  cls=$3; count=$4;
  if (count > 0) printf "Class %s: %s items evicted with remaining TTL\n", cls, count
}'
```

## Connection Diagnostics

### Connection Summary

```bash
# Current connections vs max
echo "stats" | nc localhost 11211 | grep -E "curr_connections|max_connections|total_connections|rejected_connections|listen_disabled"

# Connection churn rate
# (total_connections_now - total_connections_prev) / interval = new connections per second
```

### Connection Analysis Script

```bash
#!/bin/bash
# conn-analysis.sh -- Analyze current connections

HOST="${1:-localhost}"
PORT="${2:-11211}"

echo "=== Connection Analysis ==="

CONNS=$(echo "stats conns" | nc -w 2 "$HOST" "$PORT")

echo "$CONNS" | grep ":addr " | awk '{print $3}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20 > /tmp/mc_conn_ips

echo "Top 20 client IPs by connection count:"
cat /tmp/mc_conn_ips

echo ""
echo "Connection state distribution:"
echo "$CONNS" | grep ":state " | awk '{print $3}' | sort | uniq -c | sort -rn

echo ""
echo "Idle connections (> 300s):"
echo "$CONNS" | grep "secs_since_last_cmd" | awk '{
  split($2, a, ":");
  fd=a[1];
  idle=$3;
  if (idle > 300) printf "  fd=%s idle=%ss\n", fd, idle
}'

rm -f /tmp/mc_conn_ips
```

## Slab Management Commands

### Manual Slab Reassignment

```bash
# Move a page from slab class <src> to slab class <dst>
echo "slabs reassign <src> <dst>" | nc localhost 11211
# Response: OK or BUSY (if reassignment already in progress)

# Example: move a page from class 10 to class 5
echo "slabs reassign 10 5" | nc localhost 11211

# Trigger automove analysis
echo "slabs automove 1" | nc localhost 11211   # enable conservative
echo "slabs automove 2" | nc localhost 11211   # enable aggressive
echo "slabs automove 0" | nc localhost 11211   # disable
```

### Slab Automove Status

```bash
# Check if automove is running
echo "stats" | nc localhost 11211 | grep -E "slab_reassign|slabs_moved"

# Check automove configuration
echo "stats settings" | nc localhost 11211 | grep -E "slab_reassign|slab_automove"
```

## Flush and Invalidation Commands

```bash
# Flush ALL items (expire all items immediately)
echo "flush_all" | nc localhost 11211
# WARNING: this invalidates the entire cache!

# Flush ALL items with a delay (seconds)
echo "flush_all 30" | nc localhost 11211
# Items will be considered expired 30 seconds from now

# Delete a specific key
echo "delete mykey" | nc localhost 11211
# Response: DELETED or NOT_FOUND

# Delete with noreply (fire-and-forget)
echo "delete mykey noreply" | nc localhost 11211
```

## Diagnostic One-Liners

### Quick Health Check

```bash
# 1. Is Memcached responding?
echo "version" | nc -w 2 localhost 11211

# 2. What is the hit ratio?
echo "stats" | nc -w 2 localhost 11211 | awk '/get_hits/{h=$3}/get_misses/{m=$3}END{if(h+m>0)printf "%.1f%%\n",h/(h+m)*100}'

# 3. How much memory is used?
echo "stats" | nc -w 2 localhost 11211 | awk '/^STAT bytes /{u=$3}/limit_maxbytes/{l=$3}END{printf "%.1f%% (%dMB/%dMB)\n",u/l*100,u/1048576,l/1048576}'

# 4. Are we evicting?
echo "stats" | nc -w 2 localhost 11211 | grep "STAT evictions"

# 5. How many items?
echo "stats" | nc -w 2 localhost 11211 | grep "STAT curr_items"

# 6. Connection utilization
echo "stats" | nc -w 2 localhost 11211 | awk '/curr_connections/{c=$3}/max_connections/{m=$3}END{printf "%d/%d (%.1f%%)\n",c,m,c/m*100}'

# 7. Uptime
echo "stats" | nc -w 2 localhost 11211 | awk '/^STAT uptime/{d=int($3/86400);h=int(($3%86400)/3600);printf "%dd %dh\n",d,h}'

# 8. Average item size
echo "stats" | nc -w 2 localhost 11211 | awk '/^STAT bytes /{b=$3}/curr_items/{i=$3}END{if(i>0)printf "%d bytes\n",b/i}'

# 9. Operations per second (snapshot)
echo "stats" | nc -w 2 localhost 11211 | awk '/^STAT cmd_get/{g=$3}/^STAT cmd_set/{s=$3}/^STAT uptime/{u=$3}END{printf "GET: %d/s  SET: %d/s\n",g/u,s/u}'

# 10. Wasted cache percentage (stored but never read)
echo "stats" | nc -w 2 localhost 11211 | awk '/evicted_unfetched/{eu=$3}/expired_unfetched/{xu=$3}/total_items/{t=$3}END{if(t>0)printf "%.1f%% wasted (%d evicted-unfetched, %d expired-unfetched of %d total)\n",(eu+xu)/t*100,eu,xu,t}'
```

### Multi-Server Diagnostics

```bash
# Check version across all servers
for host in mc1 mc2 mc3; do
    echo -n "$host: "
    echo "version" | nc -w 2 "$host" 11211
done

# Check hit ratio across all servers
for host in mc1 mc2 mc3; do
    echo -n "$host: "
    echo "stats" | nc -w 2 "$host" 11211 | awk '/get_hits/{h=$3}/get_misses/{m=$3}END{if(h+m>0)printf "hit ratio: %.1f%%\n",h/(h+m)*100; else print "no traffic"}'
done

# Check evictions across all servers
for host in mc1 mc2 mc3; do
    echo -n "$host: "
    echo "stats" | nc -w 2 "$host" 11211 | grep "STAT evictions"
done

# Check memory utilization across all servers
for host in mc1 mc2 mc3; do
    echo -n "$host: "
    echo "stats" | nc -w 2 "$host" 11211 | awk '/^STAT bytes /{u=$3}/limit_maxbytes/{l=$3}END{printf "%.1f%% used\n",u/l*100}'
done

# Check connection counts across all servers
for host in mc1 mc2 mc3; do
    echo -n "$host: "
    echo "stats" | nc -w 2 "$host" 11211 | awk '/curr_connections/{c=$3}/max_connections/{m=$3}END{printf "%d/%d connections\n",c,m}'
done
```

## Key Operations for Debugging

### GET / SET / DELETE Operations

```bash
# Set a test key
echo -e "set testkey 0 300 11\r\nhello world\r" | nc -w 2 localhost 11211
# Response: STORED

# Get a key
echo "get testkey" | nc -w 2 localhost 11211
# Response: VALUE testkey 0 11\r\nhello world\r\nEND

# Multi-get
echo "get key1 key2 key3" | nc -w 2 localhost 11211

# Delete a key
echo "delete testkey" | nc -w 2 localhost 11211
# Response: DELETED or NOT_FOUND

# Add (only if not exists)
echo -e "add newkey 0 300 5\r\nhello\r" | nc -w 2 localhost 11211
# Response: STORED or NOT_STORED

# Replace (only if exists)
echo -e "replace testkey 0 300 5\r\nworld\r" | nc -w 2 localhost 11211
# Response: STORED or NOT_STORED

# Append (append to existing value)
echo -e "append testkey 0 0 6\r\n world\r" | nc -w 2 localhost 11211

# Prepend (prepend to existing value)
echo -e "prepend testkey 0 0 7\r\nhello \r" | nc -w 2 localhost 11211

# Increment
echo "incr counter 1" | nc -w 2 localhost 11211
# Response: <new_value> or NOT_FOUND

# Decrement
echo "decr counter 1" | nc -w 2 localhost 11211

# Touch (update TTL without fetching value)
echo "touch testkey 3600" | nc -w 2 localhost 11211
# Response: TOUCHED or NOT_FOUND

# CAS (compare-and-swap)
echo "gets testkey" | nc -w 2 localhost 11211
# Response includes CAS token: VALUE testkey 0 11 12345\r\nhello world\r\nEND
echo -e "cas testkey 0 300 5 12345\r\nworld\r" | nc -w 2 localhost 11211
# Response: STORED, EXISTS (CAS mismatch), or NOT_FOUND
```

### Meta Commands for Debugging (1.6.x)

```bash
# Meta get with all flags
echo "mg testkey t v f c l h k s" | nc -w 2 localhost 11211
# Response: VA <size> t=<ttl> f<flags> c<cas> la=<last_access> h=<hit> k=<key> s=<size>

# Meta get -- check if key exists without fetching value
echo "mg testkey h" | nc -w 2 localhost 11211
# Response: HD h1 (exists) or EN (not found)

# Meta get -- get TTL remaining
echo "mg testkey t" | nc -w 2 localhost 11211
# Response: HD t=3200 (TTL remaining) or EN (not found)

# Meta set with win flag
echo -e "ms testkey 5 T3600 W\r\nhello\r" | nc -w 2 localhost 11211
# Response: HD W (won the set)

# Meta delete with invalidation (stale-while-revalidate)
echo "md testkey T30 I" | nc -w 2 localhost 11211
# Marks item as stale for 30 seconds instead of deleting

# Meta arithmetic
echo "ma counter D+" | nc -w 2 localhost 11211  # increment
echo "ma counter D- J5" | nc -w 2 localhost 11211  # decrement, initial value 5 if not exists

# Meta noop (pipeline separator)
echo "mn" | nc -w 2 localhost 11211
# Response: MN
```

## Extstore Diagnostics (If Enabled)

```bash
# Check extstore stats
echo "stats" | nc localhost 11211 | grep "extstore"

# Key extstore metrics:
# extstore_page_count     - total pages on disk
# extstore_page_evictions - pages evicted from disk
# extstore_page_reclaims  - pages reclaimed
# extstore_objects_read   - objects read from disk
# extstore_objects_written - objects written to disk
# extstore_bytes_read     - bytes read from disk
# extstore_bytes_written  - bytes written to disk
# extstore_bytes_used     - bytes currently stored on disk
# extstore_bytes_fragmented - fragmented bytes on disk
# extstore_io_queue       - pending I/O operations
```

## mcrouter Diagnostics

### mcrouter Stats

```bash
# mcrouter exposes stats on its admin port (default 5000)
echo "stats" | nc localhost 5000

# Key mcrouter metrics:
# cmd_get                  - total GET commands routed
# cmd_set                  - total SET commands routed
# cmd_delete               - total DELETE commands routed
# num_servers              - number of backend servers
# num_servers_up           - backend servers currently healthy
# num_servers_down         - backend servers currently down
# num_clients              - current client connections
# result_error             - commands that resulted in errors
# result_connect_error     - connection errors to backends
# result_tko               - TKO (temporarily knocked out) results
# proxy_reqs_processing    - requests currently in flight
# proxy_reqs_waiting       - requests waiting for a connection
```

### mcrouter Health Endpoints

```bash
# Check if mcrouter is healthy
curl http://localhost:5000/api/version
curl http://localhost:5000/api/route_stats
curl http://localhost:5000/api/server_stats

# mcrouter route debugging
mcrouter --route-prefix="get" --config-dump
```

## Comprehensive Diagnostic Script

```bash
#!/bin/bash
# memcached-full-diagnostic.sh -- Complete Memcached diagnostic report

HOST="${1:-localhost}"
PORT="${2:-11211}"

NC="nc -w 2 $HOST $PORT"

echo "================================================================"
echo "  Memcached Full Diagnostic Report"
echo "  Host: $HOST:$PORT"
echo "  Date: $(date)"
echo "================================================================"

echo ""
echo "--- Version ---"
echo "version" | $NC

echo ""
echo "--- General Stats ---"
STATS=$(echo "stats" | $NC)
echo "$STATS" | grep -E "STAT (uptime|version|curr_connections|max_connections|curr_items|total_items|bytes |limit_maxbytes|evictions|reclaimed|get_hits|get_misses|cmd_get|cmd_set|listen_disabled|rejected_connections|threads|hash_power_level)"

echo ""
echo "--- Computed Metrics ---"
echo "$STATS" | awk '
/get_hits/ { hits=$3 }
/get_misses/ { misses=$3 }
/^STAT bytes / { bytes=$3 }
/limit_maxbytes/ { limit=$3 }
/curr_connections/ { conns=$3 }
/max_connections/ { maxconns=$3 }
/evictions/ { evictions=$3 }
/curr_items/ { items=$3 }
/uptime/ { uptime=$3 }
/cmd_get/ { gets=$3 }
/cmd_set/ { sets=$3 }
END {
  total=hits+misses
  if (total>0) printf "Hit Ratio:        %.2f%%\n", hits/total*100
  if (limit>0) printf "Memory Usage:     %.1f%% (%d MB / %d MB)\n", bytes/limit*100, bytes/1048576, limit/1048576
  if (maxconns>0) printf "Connection Usage: %.1f%% (%d / %d)\n", conns/maxconns*100, conns, maxconns
  if (items>0) printf "Avg Item Size:    %d bytes\n", bytes/items
  if (uptime>0) {
    printf "Ops/sec:          GET=%d SET=%d\n", gets/uptime, sets/uptime
    printf "Evictions/hour:   %.0f\n", evictions/(uptime/3600)
  }
}'

echo ""
echo "--- Slab Utilization ---"
echo "stats slabs" | $NC | awk '
/^STAT [0-9]+:chunk_size/ { split($2, a, ":"); cls=a[1]; chunk[cls]=$3 }
/^STAT [0-9]+:total_pages/ { split($2, a, ":"); cls=a[1]; pages[cls]=$3 }
/^STAT [0-9]+:total_chunks/ { split($2, a, ":"); cls=a[1]; total[cls]=$3 }
/^STAT [0-9]+:used_chunks/ { split($2, a, ":"); cls=a[1]; used[cls]=$3 }
/^STAT [0-9]+:free_chunks/ { split($2, a, ":"); cls=a[1]; free[cls]=$3 }
/^STAT [0-9]+:mem_requested/ { split($2, a, ":"); cls=a[1]; req[cls]=$3 }
END {
  printf "%-5s %-10s %-6s %-8s %-8s %-8s %-6s %-12s\n",
    "Class", "ChunkSize", "Pages", "Total", "Used", "Free", "Util%", "MemReq"
  printf "%-5s %-10s %-6s %-8s %-8s %-8s %-6s %-12s\n",
    "-----", "----------", "------", "--------", "--------", "--------", "------", "------------"
  for (cls in chunk) {
    if (total[cls]>0) util=used[cls]/total[cls]*100; else util=0
    printf "%-5s %-10s %-6s %-8s %-8s %-8s %5.1f%% %-12s\n",
      cls, chunk[cls], pages[cls], total[cls], used[cls], free[cls], util, req[cls]
  }
}'

echo ""
echo "--- Eviction Analysis (per class) ---"
echo "stats items" | $NC | grep -E "evicted |evicted_unfetched|evicted_time|evicted_nonzero" | awk -F'[: ]' '{
  if ($4 > 0) printf "  Class %-3s: %-20s = %s\n", $3, $2, $4
}'

echo ""
echo "--- LRU Queue Distribution (top 10 classes) ---"
echo "stats items" | $NC | grep -E "number_hot|number_warm|number_cold|number_temp" | head -40

echo ""
echo "--- Settings Summary ---"
echo "stats settings" | $NC | grep -E "STAT (maxbytes|maxconns|growth_factor|chunk_size|num_threads|slab_reassign|slab_automove|lru_maintainer|lru_crawler|item_size_max|binding_protocol|cas_enabled|hash_algorithm)"

echo ""
echo "================================================================"
echo "  End of Diagnostic Report"
echo "================================================================"
```

## Prometheus Exporter Metrics Reference

When using `memcached_exporter`, the following metrics are exposed:

### Server Metrics
```
memcached_up                                        # 1 if connected, 0 if not
memcached_version{version="1.6.x"}                 # Version info label
memcached_uptime_seconds                            # Server uptime
memcached_time_seconds                              # Server Unix time
memcached_pointer_size                              # 32 or 64
```

### Command Metrics
```
memcached_commands_total{command="get",status="hit"}     # GET hits
memcached_commands_total{command="get",status="miss"}    # GET misses
memcached_commands_total{command="set"}                   # SET operations
memcached_commands_total{command="delete",status="hit"}  # DELETE hits
memcached_commands_total{command="delete",status="miss"} # DELETE misses
memcached_commands_total{command="cas",status="hit"}     # CAS hits
memcached_commands_total{command="cas",status="miss"}    # CAS misses
memcached_commands_total{command="cas",status="badval"}  # CAS badval
memcached_commands_total{command="incr",status="hit"}    # INCR hits
memcached_commands_total{command="incr",status="miss"}   # INCR misses
memcached_commands_total{command="decr",status="hit"}    # DECR hits
memcached_commands_total{command="decr",status="miss"}   # DECR misses
memcached_commands_total{command="touch",status="hit"}   # TOUCH hits
memcached_commands_total{command="touch",status="miss"}  # TOUCH misses
memcached_commands_total{command="flush"}                  # FLUSH_ALL
```

### Memory Metrics
```
memcached_current_bytes                              # Current bytes used
memcached_limit_bytes                                # Max memory (limit_maxbytes)
memcached_current_items                              # Current item count
memcached_total_items                                # Total items stored since start
memcached_items_evicted_total                        # Total evictions
memcached_items_evicted_unfetched_total              # Evicted without being read
memcached_items_expired_unfetched_total              # Expired without being read
memcached_items_reclaimed_total                      # Items reclaimed (expired)
memcached_slab_global_page_pool                      # Free pages in global pool
```

### Connection Metrics
```
memcached_current_connections                        # Current connections
memcached_max_connections                            # Max connections setting
memcached_connections_total                          # Total connections since start
memcached_connections_rejected_total                 # Rejected connections
memcached_connections_listener_disabled_total        # Times listener was disabled
```

### Network Metrics
```
memcached_read_bytes_total                           # Total bytes read
memcached_written_bytes_total                        # Total bytes written
```

### Slab Metrics
```
memcached_slab_chunk_size_bytes{slab="N"}            # Chunk size per class
memcached_slab_chunks_per_page{slab="N"}            # Chunks per page per class
memcached_slab_current_pages{slab="N"}               # Pages allocated per class
memcached_slab_current_chunks{slab="N"}              # Total chunks per class
memcached_slab_chunks_used{slab="N"}                 # Used chunks per class
memcached_slab_chunks_free{slab="N"}                 # Free chunks per class
memcached_slab_mem_requested_bytes{slab="N"}         # Requested bytes per class
memcached_slab_commands_total{slab="N",command="get",status="hit"}  # Per-class commands
memcached_slab_current_items{slab="N"}               # Items per class
```

### Item Metrics (per slab class)
```
memcached_slab_items_number{slab="N"}                # Items in this class
memcached_slab_items_age_seconds{slab="N"}           # Age of oldest item
memcached_slab_items_evicted_total{slab="N"}         # Evictions in this class
memcached_slab_items_evicted_unfetched_total{slab="N"} # Unfetched evictions
memcached_slab_items_evicted_time_seconds{slab="N"}  # Age of last evicted item
memcached_slab_items_outofmemory_total{slab="N"}     # OOM in this class
memcached_slab_items_reclaimed_total{slab="N"}       # Reclaimed in this class
memcached_slab_items_crawler_reclaimed_total{slab="N"} # Crawler reclaimed
memcached_slab_items_lrutail_reflocked_total{slab="N"} # Reflocked tail items
memcached_slab_items_moves_to_cold_total{slab="N"}   # Moves to COLD
memcached_slab_items_moves_to_warm_total{slab="N"}   # Moves to WARM
```

### PromQL Alert Examples

```promql
# Hit ratio below 80%
memcached_commands_total{command="get",status="hit"}
/ (memcached_commands_total{command="get",status="hit"} + memcached_commands_total{command="get",status="miss"})
< 0.80

# Memory usage above 90%
memcached_current_bytes / memcached_limit_bytes > 0.90

# Eviction rate above 100/sec
rate(memcached_items_evicted_total[5m]) > 100

# Connection exhaustion (above 90% of max)
memcached_current_connections / memcached_max_connections > 0.90

# Memcached down
memcached_up == 0

# High waste ratio (>20% of items never fetched before eviction/expiry)
(rate(memcached_items_evicted_unfetched_total[1h]) + rate(memcached_items_expired_unfetched_total[1h]))
/ rate(memcached_total_items[1h]) > 0.20
```
