---
name: database-redis-7.8
description: "Redis 7.8 version-specific expert. Deep knowledge of new data type enhancements, cluster improvements, enhanced observability features, and performance optimizations. WHEN: \"Redis 7.8\", \"Redis 7.8 features\", \"Redis 7.8 cluster\", \"Redis 7.8 improvements\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Redis 7.8 Expert

You are a specialist in Redis 7.8, released approximately mid-2025. You have deep knowledge of the features introduced in this version, including data type enhancements, cluster improvements, enhanced observability, and performance optimizations.

**Support status:** Supported. EOL May 2027.

## Key Features Introduced in Redis 7.8

### Enhanced Cluster Operations

**Improved slot migration performance:**
- Batch key migration during resharding (multiple keys per MIGRATE call)
- Reduced client blocking during slot transitions
- Better handling of large keys during migration
- Configurable migration pipeline depth for faster resharding

```bash
# Faster resharding with pipeline depth
redis-cli --cluster reshard node1:6379 --cluster-pipeline 20
# Migrates 20 keys per batch instead of 1, significantly faster for large slots

# Improved cluster check with detailed diagnostics
redis-cli --cluster check node1:6379 --cluster-search-multiple-owners
# Detects and reports slots claimed by multiple masters (split-brain indicator)
```

**Cluster topology awareness enhancements:**
```bash
# CLUSTER MYSHARDID -- identify which shard this node belongs to
redis-cli -c CLUSTER MYSHARDID
# Returns: shard identifier for the current node

# Enhanced CLUSTER SHARDS output
redis-cli -c CLUSTER SHARDS
# Now includes: health status, replication lag per replica, slot migration status
```

**Improved failover behavior:**
- Faster replica selection during automatic failover
- Better handling of simultaneous failures (multiple masters down)
- Reduced window for stale reads during failover transitions
- Improved cluster-node-timeout handling for transient network issues

### Observability Improvements

**Enhanced INFO sections:**
```bash
redis-cli INFO latencystats
# Expanded per-command latency percentiles with p50, p95, p99, p99.9
# More command categories tracked
# Histogram-based distribution for more accurate tail latency reporting

redis-cli INFO errorstats
# Detailed error categorization:
# errorstat_ERR: general errors with breakdown
# errorstat_WRONGTYPE: type mismatch errors
# errorstat_MOVED: cluster redirections
# errorstat_ASK: cluster ask redirections
# errorstat_CLUSTERDOWN: cluster unavailable errors
# errorstat_LOADING: server loading errors
```

**LATENCY improvements:**
```bash
# More granular latency event categories
redis-cli LATENCY LATEST
# New events tracked:
# active-defrag-cycle  -- defragmentation latency
# expire-cycle         -- enhanced detail
# cluster-cron         -- cluster maintenance overhead
# aof-stat             -- AOF stat tracking overhead
```

**CLIENT LIST enhancements:**
```bash
redis-cli CLIENT LIST
# New fields:
# lib-name: client library name (e.g., redis-py, jedis)
# lib-ver: client library version
# tot-net-in: total bytes received from this client
# tot-net-out: total bytes sent to this client
# tot-cmds: total commands processed for this client
```

### Data Structure Improvements

**Stream enhancements:**
```bash
# XREAD with consumer group improvements
# Better handling of consumer crashes and message redelivery
# More efficient XAUTOCLAIM for large pending entry lists

# Enhanced XINFO output
redis-cli XINFO STREAM mystream FULL COUNT 10
# Now includes: entries-added, max-deleted-entry-id, recorded-first-entry-id
# Better visibility into stream lifecycle
```

**Sorted set improvements:**
```bash
# ZRANGESTORE performance optimization
ZRANGESTORE dest src 0 100 BYSCORE LIMIT 0 50
# Reduced memory allocation overhead for large range operations

# Better ZRANGEBYSCORE/ZRANGEBYLEX performance
# Optimized skiplist traversal for range queries with LIMIT
```

**Listpack optimization:**
- Increased default listpack thresholds for better memory efficiency
- More efficient listpack resize operations
- Reduced CPU overhead for listpack insertion/deletion

### Performance Improvements

**Memory allocation optimization:**
- Improved jemalloc arena management for multi-threaded I/O scenarios
- Reduced memory fragmentation for workloads with mixed key sizes
- Better copy-on-write behavior during BGSAVE (reduced COW amplification)

**Command processing:**
- Faster SCAN implementation with better cursor distribution
- Optimized MULTI/EXEC transaction processing
- Reduced per-command overhead for pipelined operations
- Improved ACL checking performance for complex rulesets

**I/O threading refinements:**
- Better load balancing across I/O threads
- Reduced lock contention in socket buffer management
- Improved throughput for connections with large payloads
- Adaptive I/O thread activation based on load

**Benchmarks (typical improvement over 7.4):**
| Workload | Improvement |
|---|---|
| GET/SET (small keys) | ~5-8% throughput |
| Pipeline (100 commands) | ~10-15% throughput |
| Large key operations (>1MB) | ~15-20% latency reduction |
| SCAN (large keyspace) | ~20% faster |
| Cluster resharding | ~30-50% faster |

### Security Enhancements

**ACL improvements:**
```bash
# More granular key permissions with read/write distinction
ACL SETUSER reader on >pass %R~app:* +get +mget +scan
# %R~pattern: read-only access to matching keys
# %W~pattern: write-only access to matching keys

# Improved ACL LOG detail
redis-cli ACL LOG 10
# Now includes: entry-id for unique identification
# Better context for pub/sub channel denials
# Timestamp precision improved to milliseconds
```

**TLS improvements:**
- TLS 1.3 session resumption optimization
- Reduced handshake latency for reconnections
- Better certificate rotation handling without restart

### Configuration Changes

**New parameters:**
```
# Enhanced active defragmentation controls
active-defrag-max-scan-fields 1000
# Maximum hash/set/zset fields scanned per defrag cycle step

# Improved replication buffer management
repl-min-slaves-max-lag-threshold 5
# More granular replica lag detection

# Stream memory management
stream-node-max-bytes 4096
stream-node-max-entries 100
# Per-node limits for stream radix tree nodes
```

**Modified defaults:**
```
# hz default increased from 10 to adaptive (dynamic-hz yes remains default)
# Better default I/O thread configuration detection
# Improved auto-tuning for latency-monitor-threshold
```

## Version Boundaries

**This version introduced:**
- Enhanced cluster slot migration performance
- CLUSTER MYSHARDID command
- Expanded latency statistics and error statistics
- CLIENT LIST library name/version tracking
- Stream lifecycle observability improvements
- Memory allocation and I/O threading optimizations
- Read/write granularity in ACL key permissions
- TLS 1.3 session resumption optimization

**Not available in this version (added later):**
- Redis 8.0 major release features and breaking changes

**Available from previous versions:**
- Hash field expiration (7.4)
- WAITAOF (7.2)
- CLIENT NO-TOUCH (7.2)
- Sharded pub/sub (7.0)
- Functions API (7.0)
- Multi-part AOF (7.0)

## Migration Guidance

### Migrating from 7.4 to 7.8

**Backward compatible:** No breaking changes. All 7.4 commands and configurations continue to work.

**Recommended steps:**
1. Review current performance baseline: `INFO latencystats`, `SLOWLOG GET 20`
2. Upgrade replicas first, verify replication healthy
3. Failover and upgrade masters one at a time
4. For cluster: rolling upgrade; verify `redis-cli --cluster check` after each node
5. After upgrade: compare performance metrics with baseline

**Post-upgrade recommendations:**
- Review enhanced `INFO errorstats` for previously invisible error patterns
- Enable `CLIENT SETNAME` in application clients to leverage new CLIENT LIST fields
- Test cluster resharding performance improvements
- Consider tuning `active-defrag-max-scan-fields` for large-collection workloads

### Migrating from 7.8 to 8.0

**Important:** Redis 8.0 is a major release with potential breaking changes. Review the 8.0 SKILL.md carefully before upgrading. Key considerations:
- Command behavior changes
- Configuration parameter changes
- Encoding default changes
- Client library version requirements

### Client Library Compatibility

- **redis-py** >= 5.1: full 7.8 support
- **Jedis** >= 5.2: full 7.8 support
- **go-redis** >= 9.5: full 7.8 support
- **node-redis** >= 4.7: full 7.8 support
- **Lettuce** >= 6.4: full 7.8 support
- **StackExchange.Redis** >= 2.8: full 7.8 support

### Performance Tuning After Upgrade

```bash
# Verify I/O threading is optimally configured
redis-cli CONFIG GET io-threads
redis-cli CONFIG GET io-threads-do-reads

# Check new latency stats
redis-cli INFO latencystats

# Verify active defragmentation with new controls
redis-cli CONFIG GET active-defrag-max-scan-fields
redis-cli INFO memory | grep active_defrag

# Test cluster resharding speed improvement
redis-cli --cluster reshard node1:6379 --cluster-pipeline 20
```
