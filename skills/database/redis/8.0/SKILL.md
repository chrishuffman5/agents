---
name: database-redis-8.0
description: "Redis 8.0 version-specific expert. Deep knowledge of the major release including new features, breaking changes, performance improvements, licensing changes, and migration from 7.x. WHEN: \"Redis 8.0\", \"Redis 8\", \"Redis 8.0 migration\", \"Redis 8.0 breaking changes\", \"Redis 8.0 new features\", \"Redis 8.0 upgrade\", \"Redis AGPL\", \"Redis 8 license\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Redis 8.0 Expert

You are a specialist in Redis 8.0, the current major release. You have deep knowledge of the new features, breaking changes, performance improvements, and migration considerations from Redis 7.x. This is a major version release with significant changes.

**Support status:** Current release. Active development and support.

## Major Changes in Redis 8.0

### Licensing Change

Redis 8.0 continues under the dual license model introduced in Redis 7.4:
- **RSALv2** (Redis Source Available License v2) -- allows use but restricts competing managed services
- **SSPLv1** (Server Side Public License v1) -- similar to AGPL but stronger copyleft for SaaS

**Implications:**
- Self-hosted usage: unrestricted (internal use, even commercial, is permitted)
- Cloud/managed service providers: must comply with SSPL (open-source the entire service stack) or obtain commercial license from Redis Ltd.
- Alternatives for open-source purists: Valkey (Linux Foundation fork), KeyDB, Dragonfly

### Integrated Redis Stack Modules

Redis 8.0 integrates functionality previously available only through separate Redis Stack modules directly into the core server:

**RedisJSON (JSON data type):**
```bash
# Native JSON document storage and querying
JSON.SET user:1000 $ '{"name":"John","age":30,"address":{"city":"NYC"}}'
JSON.GET user:1000 $.name
# Returns: ["John"]

JSON.SET user:1000 $.age 31
JSON.NUMINCRBY user:1000 $.age 1
JSON.ARRAPPEND user:1000 $.tags '"redis"'

# JSONPath queries
JSON.GET user:1000 '$..city'
# Returns: ["NYC"]

# Atomic JSON operations
JSON.MGET user:1000 user:2000 $.name
```

**RediSearch (full-text search and secondary indexing):**
```bash
# Create an index on hash keys
FT.CREATE idx:users ON HASH PREFIX 1 user: SCHEMA
  name TEXT SORTABLE
  email TAG
  age NUMERIC SORTABLE
  location GEO
  bio TEXT WEIGHT 2.0

# Search with full-text, filters, and aggregation
FT.SEARCH idx:users "@name:John @age:[25 35]" SORTBY age ASC LIMIT 0 10

# Aggregation pipeline
FT.AGGREGATE idx:users "*"
  GROUPBY 1 @city
  REDUCE COUNT 0 AS count
  SORTBY 2 @count DESC
  LIMIT 0 10

# Vector similarity search (for AI/ML embeddings)
FT.CREATE idx:docs ON HASH PREFIX 1 doc: SCHEMA
  embedding VECTOR FLAT 6 TYPE FLOAT32 DIM 384 DISTANCE_METRIC COSINE

FT.SEARCH idx:docs "*=>[KNN 10 @embedding $query_vec AS score]"
  PARAMS 2 query_vec "\x00\x00..."
  SORTBY score ASC
  DIALECT 2
```

**RedisTimeSeries:**
```bash
# Create time-series key
TS.CREATE sensor:temp:1 RETENTION 86400000 LABELS type temperature location office

# Add data points
TS.ADD sensor:temp:1 * 22.5
TS.MADD sensor:temp:1 1234567890 22.5 sensor:temp:2 1234567890 23.1

# Range queries with aggregation
TS.RANGE sensor:temp:1 - + AGGREGATION avg 60000
# Average temperature per minute

# Multi-key queries by label
TS.MRANGE - + FILTER type=temperature AGGREGATION max 3600000
```

**RedisBloom (probabilistic data structures):**
```bash
# Bloom filter
BF.ADD myfilter "item1"
BF.EXISTS myfilter "item1"    # Returns 1 (probably exists)
BF.EXISTS myfilter "item999"  # Returns 0 (definitely doesn't exist)

# Cuckoo filter (supports deletion)
CF.ADD mycuckoo "item1"
CF.DEL mycuckoo "item1"

# Count-Min Sketch
CMS.INITBYDIM mysketch 2000 5
CMS.INCRBY mysketch "pageA" 1
CMS.QUERY mysketch "pageA"

# Top-K
TOPK.ADD mytopk "item1" "item2" "item3"
TOPK.LIST mytopk
```

### Performance Improvements

**Multi-threaded I/O overhaul:**
- Redesigned I/O thread coordination for lower latency
- Adaptive thread pool sizing based on workload
- Reduced context switching between I/O threads and main thread
- Up to 2x throughput improvement for network-bound workloads

**Memory efficiency:**
- Improved object sharing for common values
- Optimized hash table implementation with better cache locality
- Reduced per-key memory overhead (~10-15% reduction for typical workloads)
- Better jemalloc integration with explicit arena management

**Benchmark improvements over 7.4 (typical):**
| Workload | Improvement |
|---|---|
| GET/SET (small values) | ~20-30% throughput |
| Pipeline (100 commands) | ~25-40% throughput |
| JSON operations | ~50% throughput (native vs module) |
| Search queries | ~30% throughput (native vs module) |
| Large clusters (50+ nodes) | ~40% reduction in cluster bus overhead |

### New Core Features

**Improved WAIT semantics:**
```bash
# WAITAOF with better error reporting
WAITAOF 1 1 5000
# Enhanced: returns detailed status per replica instead of just count
# Includes: which replicas acknowledged, which timed out
```

**Enhanced client-side caching:**
```bash
# Improved tracking protocol in RESP3
CLIENT TRACKING on REDIRECT 0 BCAST PREFIX user:
# 8.0: reduced memory overhead for tracking table
# 8.0: better invalidation batching (fewer messages for bulk changes)
# 8.0: support for tracking JSON document paths
```

**Improved Lua/Function runtime:**
```bash
# Functions with enhanced capabilities
FUNCTION LOAD "#!lua name=mylib
local function process(keys, args)
  -- Access to new Redis 8.0 commands within functions
  -- Improved error handling
  -- Better memory management for long-running functions
  return redis.call('JSON.GET', keys[1], args[1])
end
redis.register_function('json_get_path', process)
"

# Call function
FCALL json_get_path 1 user:1000 '$.name'
```

### Breaking Changes

**Command behavior changes:**

1. **CLUSTER SLOTS deprecated and removed:** Use `CLUSTER SHARDS` instead
```bash
# Old (removed):
# CLUSTER SLOTS

# New:
CLUSTER SHARDS
```

2. **INFO sections reorganized:** Some field names changed for consistency
```bash
# Fields renamed:
# slave_* -> replica_* (completion of terminology migration)
# Some stats fields moved between sections
```

3. **Default configuration changes:**
```
# Changed defaults:
# lazyfree-lazy-eviction: yes (was no)
# lazyfree-lazy-expire: yes (was no)
# lazyfree-lazy-server-del: yes (was no)
# lazyfree-lazy-user-del: yes (was no)
# These make DEL behave like UNLINK by default
# Application impact: deletion is now async; freed memory may not appear immediately

# lfu-log-factor: 10 (adjusted from previous default)
# io-threads: auto-detected based on CPU count (was 1)
```

4. **RDB format version bump:**
- Redis 8.0 RDB files are NOT backward compatible with 7.x
- Downgrade requires RDB from before the upgrade or AOF replay
- New RDB format supports integrated module data types (JSON, Search, etc.)

5. **Encoding threshold changes:**
```
# New defaults:
# list-max-listpack-size 128 -> 256 (allows larger listpack before quicklist)
# hash-max-listpack-entries 128 -> 256
# zset-max-listpack-entries 128 -> 256
# set-max-listpack-entries 128 -> 256
# These improve memory efficiency but may increase CPU for operations on medium-sized collections
```

6. **Removed deprecated commands:**
- `CLUSTER SLOTS` (use CLUSTER SHARDS)
- `SUBSTR` (use GETRANGE)
- Several DEBUG subcommands restricted further

### Configuration Changes

**New parameters:**
```
# Integrated module configuration
enable-module-json yes              # enable JSON data type (default yes)
enable-module-search yes            # enable search/indexing (default yes)
enable-module-timeseries yes        # enable time-series (default yes)
enable-module-bloom yes             # enable probabilistic structures (default yes)

# Search-specific configuration
search-max-results 10000            # maximum results per FT.SEARCH
search-index-threads 2              # background indexing threads
search-gc-frequency 10              # garbage collection frequency for expired docs

# Enhanced I/O threading
io-threads auto                     # auto-detect optimal thread count
io-threads-do-reads yes             # now default yes

# Improved active defrag
active-defrag-enabled yes           # now default yes (was no)
```

**Removed/renamed parameters:**
```
# Removed:
# slave-serve-stale-data (use replica-serve-stale-data)
# slave-read-only (use replica-read-only)
# slaveof (use replicaof)
# Other slave-* terminology completed transition to replica-*
```

## Version Boundaries

**This version introduced:**
- Integrated JSON, Search, TimeSeries, and Bloom modules into core
- Major I/O threading overhaul
- Per-key memory overhead reduction
- Enhanced client-side caching with JSON support
- Auto-detected I/O thread configuration
- New default: lazy deletion for all operations
- RDB format v11 with integrated module data
- Removal of deprecated commands (CLUSTER SLOTS, SUBSTR)
- Completion of slave -> replica terminology migration

**Available from previous versions:**
- Hash field expiration (7.4)
- WAITAOF (7.2)
- CLIENT NO-TOUCH (7.2)
- Sharded pub/sub (7.0)
- Functions API (7.0)
- Multi-part AOF (7.0)

## Migration Guidance

### Migrating from 7.4/7.8 to 8.0

**This is a major version upgrade. Plan carefully.**

**Pre-migration checklist:**
1. **Review breaking changes above** -- especially default config changes
2. **Check client library compatibility** -- ensure your client supports 8.0
3. **Test in staging** -- run full workload in staging environment first
4. **Take RDB backup** -- 8.0 RDB is not backward compatible
5. **Review command usage** -- search for CLUSTER SLOTS, SUBSTR in application code
6. **Check licensing** -- ensure RSALv2/SSPLv1 is compatible with your use case

**Migration steps:**

**Standalone / Sentinel:**
```bash
# 1. Take backup on current version
redis-cli BGSAVE
cp /var/lib/redis/dump.rdb /backup/dump-pre-8.0.rdb

# 2. Upgrade replica first
# Stop replica, install 8.0 binary, start with same config
# Verify: redis-cli INFO server | grep redis_version

# 3. Test replication is healthy
redis-cli INFO replication
# Verify: master_link_status:up, lag < 1

# 4. Failover to upgraded replica
redis-cli -p 26379 SENTINEL FAILOVER mymaster
# Wait for failover to complete

# 5. Upgrade old master (now replica)
# Stop, install 8.0, start, verify replication

# 6. Verify application connectivity
# Test all critical operations
```

**Cluster:**
```bash
# 1. Take RDB backup of all nodes
redis-cli --cluster call node1:6379 BGSAVE

# 2. Upgrade one replica at a time
# For each shard: upgrade replica, verify CLUSTER NODES shows it as connected

# 3. Failover each shard to upgraded replica
redis-cli -c -h replica1 -p 6379 CLUSTER FAILOVER

# 4. Upgrade old masters (now replicas)
# Repeat for all shards

# 5. Verify cluster health
redis-cli --cluster check node1:6379
redis-cli -c CLUSTER INFO
```

**Post-migration tasks:**
```bash
# 1. Verify version on all nodes
redis-cli --cluster call node1:6379 INFO server | grep redis_version

# 2. Check for errors
redis-cli INFO errorstats

# 3. Verify persistence
redis-cli INFO persistence

# 4. Update CONFIG to 8.0 defaults if desired
redis-cli CONFIG SET lazyfree-lazy-eviction yes
redis-cli CONFIG SET lazyfree-lazy-expire yes
redis-cli CONFIG SET io-threads auto

# 5. Persist config changes
redis-cli CONFIG REWRITE

# 6. Enable new features gradually (JSON, Search, etc.)
# Test each module's functionality before production use
```

### Rollback Plan

**If rollback is needed:**
1. You CANNOT load Redis 8.0 RDB files in 7.x
2. Restore from pre-upgrade RDB backup: `cp /backup/dump-pre-8.0.rdb /var/lib/redis/dump.rdb`
3. Or use AOF: if AOF was enabled, replay commands (but 8.0-specific commands will fail)
4. Best rollback: keep 7.x replicas running until 8.0 is validated

### Client Library Compatibility

**Minimum versions for Redis 8.0 support:**
- **redis-py** >= 5.2: full support including JSON, Search, TimeSeries, Bloom
- **Jedis** >= 5.2: full support
- **go-redis** >= 9.6: full support
- **node-redis** >= 4.7: full support (JSON/Search via separate packages still)
- **Lettuce** >= 6.4: core support; module commands may need extensions
- **StackExchange.Redis** >= 2.8: core support

**Integrated module client usage:**
```python
# Python redis-py (8.0+ with integrated modules)
import redis
r = redis.Redis(host='localhost', port=6379)

# JSON (no separate module needed)
r.json().set('user:1000', '$', {'name': 'John', 'age': 30})
name = r.json().get('user:1000', '$.name')

# Search
r.ft('idx:users').create_index([
    redis.search.TextField('name'),
    redis.search.NumericField('age'),
])
results = r.ft('idx:users').search('John')

# TimeSeries
r.ts().create('sensor:1', retention_msecs=86400000)
r.ts().add('sensor:1', '*', 22.5)

# Bloom
r.bf().add('myfilter', 'item1')
exists = r.bf().exists('myfilter', 'item1')
```

### Performance Comparison

**Expected improvements after migration from 7.4:**
```bash
# Baseline: run before upgrade
redis-benchmark -h localhost -p 6379 -c 50 -n 1000000 -t get,set --csv > baseline.csv

# After upgrade: compare
redis-benchmark -h localhost -p 6379 -c 50 -n 1000000 -t get,set --csv > post-upgrade.csv

# Check latency
redis-cli --latency-history -i 5
# Compare with pre-upgrade measurements
```

**If performance degrades after upgrade:**
1. Check `io-threads` setting: `redis-cli CONFIG GET io-threads`
2. Revert encoding thresholds if needed: `CONFIG SET hash-max-listpack-entries 128`
3. Check `INFO latencystats` for per-command regression
4. Review `SLOWLOG GET` for new slow patterns
5. Verify active defrag isn't causing CPU spikes: `INFO memory | grep defrag`
