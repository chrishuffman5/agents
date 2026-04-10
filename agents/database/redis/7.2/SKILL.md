---
name: database-redis-7.2
description: "Redis 7.2 version-specific expert. Deep knowledge of client-side caching improvements, WAITAOF command, sharded pub/sub enhancements, stream consumer group improvements, and new command additions. WHEN: \"Redis 7.2\", \"WAITAOF\", \"client-side caching 7.2\", \"Redis 7.2 features\", \"CLIENT NO-TOUCH\", \"LMPOP\", \"ZMPOP\", \"SINTERCARD\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Redis 7.2 Expert

You are a specialist in Redis 7.2, released August 2023. You have deep knowledge of the features introduced in this version, particularly client-side caching improvements, WAITAOF for AOF durability guarantees, and sharded pub/sub enhancements.

**Support status:** End of Life February 2026. Users should plan migration to 7.4 or later.

## Key Features Introduced in Redis 7.2

### WAITAOF -- AOF Durability Acknowledgment

Redis 7.2 introduces WAITAOF, enabling clients to wait for writes to be persisted to the AOF on the local server and/or replicas:

```bash
# Write a critical key
SET transaction:12345 '{"amount":500,"status":"pending"}'

# Wait for AOF persistence: local + 1 replica
WAITAOF 1 1 5000
# Args: <num-local> <num-replicas> <timeout-ms>
# Returns: [local_fsyncs, replica_fsyncs]
# local_fsyncs: number of local AOF fsyncs completed (0 or 1)
# replica_fsyncs: number of replicas that confirmed AOF fsync

# Wait for local AOF only (no replica requirement)
WAITAOF 1 0 5000

# Wait for replica AOF only (local doesn't need to fsync)
WAITAOF 0 2 5000
```

**How WAITAOF differs from WAIT:**
| Command | What It Guarantees | Data Loss Window |
|---|---|---|
| `WAIT N timeout` | N replicas received the write in memory | Replica crash = data loss |
| `WAITAOF 1 0 timeout` | Local AOF fsynced | Local crash safe |
| `WAITAOF 1 N timeout` | Local AOF + N replica AOFs fsynced | Survives any single failure |

**Use cases:**
- Financial transactions requiring durability before acknowledging to the client
- Critical writes where "at least one copy on disk" is required
- Replacing synchronous replication with AOF-level guarantees

**Requirements:**
- AOF must be enabled (`appendonly yes`) on local server and/or target replicas
- `appendfsync` should be `everysec` or `always` on replicas for meaningful guarantees
- Timeout of 0 means wait indefinitely (use with caution)

### Client-Side Caching Improvements

Redis 7.2 enhances the client-side caching protocol introduced in Redis 6.0:

**CLIENT NO-TOUCH command:**
```bash
# Prevent this client's commands from affecting LRU/LFU tracking
CLIENT NO-TOUCH on

# Now GET/SET operations won't update key access time/frequency
GET mykey    # key's idle time and frequency are NOT updated
SET mykey newvalue    # still doesn't affect tracking

# Useful for monitoring/admin clients that shouldn't influence eviction
CLIENT NO-TOUCH off   # re-enable normal tracking
```

**Improved invalidation messages:**
- More efficient invalidation for tracked keys in RESP3 mode
- Better handling of multi-key operations in client tracking
- Reduced overhead for broadcasting mode (`CLIENT TRACKING on BCAST`)

**Client tracking modes:**
```bash
# Default mode: track specific keys accessed by this client
CLIENT TRACKING on REDIRECT 0
# Server sends invalidation when tracked keys change

# Broadcasting mode: receive invalidations for key prefix patterns
CLIENT TRACKING on BCAST PREFIX user: PREFIX session:
# Receives invalidation for ANY key matching the prefixes

# Opt-in mode: client explicitly selects keys to track
CLIENT TRACKING on OPTIN
CLIENT CACHING yes    # next read command's key will be tracked
GET user:1000:profile # this key is now tracked
```

### Sharded Pub/Sub Enhancements

Building on the sharded pub/sub introduced in Redis 7.0, version 7.2 improves:

```bash
# Sharded pub/sub: channels are assigned to hash slots (like regular keys)
SSUBSCRIBE {user:1000}:events    # subscribes on the node owning this slot
SPUBLISH {user:1000}:events '{"action":"login"}'

# Benefits over classic pub/sub in cluster:
# - Messages route through the correct node (not broadcast to all)
# - Scales with cluster size
# - Uses hash tags for co-location with data
```

**7.2 improvements:**
- Better cluster redirection for sharded pub/sub channels
- Improved memory efficiency for sharded channel tracking
- Fixes for edge cases during slot migration with active subscriptions

### New and Enhanced Commands

**LMPOP / ZMPOP (moved from experimental to stable):**
```bash
# LMPOP: pop from first non-empty list
LMPOP 3 list1 list2 list3 LEFT COUNT 5
# Pops up to 5 elements from the LEFT of the first non-empty list

LMPOP 2 queue:high queue:low LEFT COUNT 1
# Priority queue: try high-priority first, then low-priority

# ZMPOP: pop from first non-empty sorted set
ZMPOP 2 scores:daily scores:weekly MIN COUNT 3
# Pops 3 lowest-scored members from first non-empty sorted set
```

**SINTERCARD -- Cardinality of Set Intersection:**
```bash
SINTERCARD 2 set1 set2
# Returns count of elements in intersection (without materializing the set)

SINTERCARD 3 users:premium users:active users:email_opted_in LIMIT 1000
# LIMIT: stop counting at 1000 (optimization for "is intersection > N?" checks)
```

**LPOS improvements:**
```bash
# Find position of element in list (enhanced from 6.0.6)
LPOS mylist "target-value"           # first occurrence
LPOS mylist "target-value" RANK -1   # last occurrence
LPOS mylist "target-value" COUNT 0   # all occurrences
LPOS mylist "target-value" MAXLEN 100 # scan only first 100 elements
```

### Performance Improvements in 7.2

- **Faster SCAN implementation** -- Reduced overhead for large keyspaces
- **Optimized listpack encoding** -- Better memory efficiency for small collections
- **Improved cluster bus protocol** -- Reduced gossip overhead in large clusters
- **Better jemalloc tuning** -- Reduced memory fragmentation for common workloads
- **Async deletion improvements** -- UNLINK and lazy-free more efficient

### Configuration Changes

**New configuration parameters:**
```
# Close connections with pending output that can't be written
close-on-oom yes

# Improved lfu-decay-time handling
lfu-decay-time 1

# Better handling of replica-lazy-flush
replica-lazy-flush yes
```

## Version Boundaries

**This version introduced:**
- WAITAOF command
- CLIENT NO-TOUCH command
- Stable LMPOP and ZMPOP
- SINTERCARD with LIMIT option
- Improved client-side caching internals
- Enhanced sharded pub/sub in cluster mode

**Not available in this version (added later):**
- Hash field expiration (7.4+)
- Per-field TTL on hashes (7.4+)
- Various cluster improvements from 7.4+

**Removed/deprecated in this version:**
- Legacy `slave` terminology further replaced with `replica` in configs and commands
- Deprecated CLUSTER SLOTS in favor of CLUSTER SHARDS

## Migration Guidance

### Migrating from 7.0 to 7.2

**Backward compatible:** 7.2 is a minor release; no breaking changes from 7.0.

**Recommended steps:**
1. Review `LATENCY LATEST` and `SLOWLOG` for baseline performance metrics
2. Upgrade replicas first, then failover and upgrade the master
3. For cluster: rolling upgrade node by node (upgrade replicas, failover, upgrade old masters)
4. After upgrade: test WAITAOF if AOF durability is important to your workload
5. Consider enabling `CLIENT NO-TOUCH` for monitoring connections

### Migrating from 7.2 to 7.4

**Key considerations:**
- 7.4 adds hash field expiration -- no code changes required unless you want to use it
- Review 7.4 SKILL.md for new cluster commands
- Test with `redis-cli --cluster check` before and after upgrade

### Client Library Compatibility

- **redis-py** >= 5.0: full 7.2 support including WAITAOF
- **Jedis** >= 5.0: full 7.2 support
- **go-redis** >= 9.2: full 7.2 support
- **node-redis** >= 4.6: full 7.2 support
- **Lettuce** >= 6.3: full 7.2 support
