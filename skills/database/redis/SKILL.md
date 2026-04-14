---
name: database-redis
description: "Redis technology expert covering ALL versions. Deep expertise in data structures, clustering, sentinel, persistence, pub/sub, streams, Lua scripting, and operational tuning. WHEN: \"Redis\", \"redis-cli\", \"redis-server\", \"Redis Cluster\", \"Redis Sentinel\", \"Redis Streams\", \"pub/sub\", \"RDB\", \"AOF\", \"RESP protocol\", \"redis.conf\", \"Lua scripting Redis\", \"Redis memory\", \"key eviction\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Redis Technology Expert

You are a specialist in Redis across all supported versions (7.2 through 8.0). You have deep knowledge of Redis internals, data structures, clustering, high availability, persistence, performance tuning, and the full command surface. When a question is version-specific, route to or reference the appropriate version agent.

## When to Use This Agent vs. a Version Agent

**Use this agent when the question spans versions or is version-agnostic:**
- "How does Redis Cluster handle resharding?"
- "Tune maxmemory and eviction policies for a caching workload"
- "Set up Redis Sentinel for high availability"
- "Compare Sorted Sets vs Streams for time-series data"
- "Best practices for redis.conf tuning"

**Route to a version agent when the question is version-specific:**
- "Redis 8.0 breaking changes and new features" --> `8.0/SKILL.md`
- "Redis 7.8 new data types" --> `7.8/SKILL.md`
- "Redis 7.4 hash field expiration" --> `7.4/SKILL.md`
- "Redis 7.2 client-side caching improvements" --> `7.2/SKILL.md`

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Version-specific feature** -- Route to the version agent
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine version** -- Ask if unclear. Behavior differs significantly across versions (e.g., hash field TTL exists only in 7.4+, sharded pub/sub in 7.0+).

3. **Analyze** -- Apply Redis-specific reasoning. Reference the single-threaded model, memory implications, cluster topology, and persistence trade-offs as relevant.

4. **Recommend** -- Provide actionable guidance with specific redis.conf parameters, CLI commands, or Lua scripts.

5. **Verify** -- Suggest validation steps (INFO sections, SLOWLOG, LATENCY, MEMORY DOCTOR).

## Core Expertise

### Data Structures

Redis is a data structure server. Each key maps to a typed value with specific operations:

| Structure | Commands | Internal Encodings | Use Cases |
|---|---|---|---|
| **String** | GET, SET, INCR, APPEND, GETRANGE | int, embstr, raw | Caching, counters, rate limiting, distributed locks |
| **List** | LPUSH, RPUSH, LPOP, RPOP, LRANGE, LPOS | listpack (<=128 entries), quicklist | Queues, activity feeds, bounded logs |
| **Set** | SADD, SREM, SMEMBERS, SINTER, SUNION, SDIFF | listpack (<=128 int entries), intset, hashtable | Tags, unique visitors, set operations |
| **Sorted Set** | ZADD, ZRANGE, ZRANGEBYSCORE, ZRANK, ZINCRBY | listpack (<=128 entries), skiplist+hashtable | Leaderboards, rate limiters, priority queues, time-series |
| **Hash** | HSET, HGET, HMGET, HINCRBY, HGETALL | listpack (<=128 fields), hashtable | Objects, user profiles, configuration |
| **Stream** | XADD, XREAD, XREADGROUP, XACK, XPENDING | Radix tree + listpacks | Event sourcing, message queues, audit logs |
| **Bitmap** | SETBIT, GETBIT, BITCOUNT, BITOP, BITPOS | String (bit-addressable) | Feature flags, daily active users, bloom-filter-like |
| **HyperLogLog** | PFADD, PFCOUNT, PFMERGE | Sparse or dense encoding | Cardinality estimation (unique counts) |
| **Geospatial** | GEOADD, GEODIST, GEOSEARCH, GEORADIUS | Sorted Set (geohash as score) | Proximity search, store locators |

**Encoding thresholds** (configurable via redis.conf):
```
list-max-listpack-size 128        # entries before converting to quicklist nodes
set-max-listpack-entries 128      # entries before converting to hashtable
set-max-intset-entries 512        # integer entries before converting set to hashtable
zset-max-listpack-entries 128     # entries before converting to skiplist
hash-max-listpack-entries 128     # fields before converting to hashtable
hash-max-listpack-value 64        # max field/value bytes in listpack encoding
```

### Clustering Architecture

Redis Cluster provides horizontal scaling with automatic data sharding:

- **16,384 hash slots** distributed across master nodes
- Key assignment: `HASH_SLOT = CRC16(key) mod 16384`
- **Hash tags**: `{user:1000}.profile` and `{user:1000}.session` map to the same slot, enabling multi-key operations
- Minimum 3 master nodes recommended (for majority quorum)
- Each master can have 0+ replicas for failover

**Cluster topology:**
```
Master A [slots 0-5460]     --> Replica A1
Master B [slots 5461-10922] --> Replica B1
Master C [slots 10923-16383]--> Replica C1
```

**MOVED and ASK redirections:**
- `MOVED 3999 127.0.0.1:6381` -- slot permanently moved; update slot mapping
- `ASK 3999 127.0.0.1:6381` -- slot migrating; send next command to target with ASKING prefix

**Key cluster operations:**
```bash
# Create a cluster
redis-cli --cluster create node1:6379 node2:6379 node3:6379 \
  node4:6379 node5:6379 node6:6379 --cluster-replicas 1

# Add a node
redis-cli --cluster add-node new-node:6379 existing-node:6379

# Reshard slots
redis-cli --cluster reshard existing-node:6379

# Check cluster health
redis-cli --cluster check node1:6379

# Fix cluster inconsistencies
redis-cli --cluster fix node1:6379
```

**Cluster limitations:**
- Multi-key operations require all keys in the same hash slot
- SELECT (multiple databases) not supported -- always database 0
- Lua scripts must access keys in the same hash slot
- KEYS, SCAN are node-local (use each node or redis-cli --cluster call)

### Sentinel for High Availability

Redis Sentinel provides HA for non-clustered Redis deployments:

- **Monitoring** -- Continuously checks if masters and replicas are reachable
- **Notification** -- Alerts via pub/sub or scripts when instances fail
- **Automatic failover** -- Promotes a replica to master when the master is down
- **Configuration provider** -- Clients discover the current master via Sentinel

**Sentinel deployment (minimum 3 sentinels for quorum):**
```
sentinel.conf:
  sentinel monitor mymaster 10.0.0.1 6379 2    # quorum of 2
  sentinel down-after-milliseconds mymaster 5000
  sentinel failover-timeout mymaster 60000
  sentinel parallel-syncs mymaster 1
```

**Failover sequence:**
1. Sentinel detects master as subjectively down (SDOWN) after `down-after-milliseconds`
2. Sentinel asks other sentinels to confirm -- if quorum agrees, master is objectively down (ODOWN)
3. A sentinel is elected leader via Raft-like election
4. Leader selects the best replica (replication offset, priority, runid)
5. Replica is promoted via REPLICAOF NO ONE
6. Other replicas are reconfigured to replicate from the new master
7. Old master is reconfigured as replica when it comes back

**Client integration:**
```python
# Python example with redis-py
from redis.sentinel import Sentinel
sentinel = Sentinel([('sentinel1', 26379), ('sentinel2', 26379), ('sentinel3', 26379)])
master = sentinel.master_for('mymaster', socket_timeout=0.5)
replica = sentinel.slave_for('mymaster', socket_timeout=0.5)
master.set('key', 'value')
value = replica.get('key')
```

### Persistence

Redis provides three persistence strategies:

**RDB (Redis Database) snapshots:**
- Point-in-time snapshots at configured intervals
- Fork-based: parent continues serving; child writes dump.rdb
- Compact binary format, fast to load on restart
- Data loss window = time since last snapshot
```
save 3600 1        # snapshot if >= 1 key changed in 3600 seconds
save 300 100       # snapshot if >= 100 keys changed in 300 seconds
save 60 10000      # snapshot if >= 10000 keys changed in 60 seconds
```

**AOF (Append-Only File):**
- Logs every write command in RESP format
- Three fsync policies: `always` (safest, slowest), `everysec` (default, ~1s data loss), `no` (OS decides)
- AOF rewrite compacts the file by regenerating the minimal command set
```
appendonly yes
appendfsync everysec
auto-aof-rewrite-percentage 100    # rewrite when AOF is 2x baseline
auto-aof-rewrite-min-size 64mb     # minimum AOF size before rewrite
```

**Hybrid AOF+RDB (Redis 7.0+, default):**
- AOF rewrite produces an RDB preamble + AOF tail
- Combines fast RDB loading with AOF durability
- `aof-use-rdb-preamble yes` (default in 7.0+)
- Multi-part AOF: base file (RDB) + incremental files (AOF commands)

**Persistence comparison:**
| Factor | RDB Only | AOF Only | Hybrid (Recommended) |
|---|---|---|---|
| Data loss window | Minutes (last save interval) | ~1 second (everysec) | ~1 second |
| Startup speed | Fast (binary load) | Slow (command replay) | Fast (RDB preamble) |
| Disk usage | Compact | Larger (commands) | Moderate |
| Fork overhead | On save interval | On rewrite | On rewrite |
| CPU overhead | Low | Moderate (fsync) | Moderate |

### Pub/Sub and Streams

**Classic Pub/Sub:**
- Fire-and-forget: messages lost if no subscriber is connected
- No persistence, no consumer groups, no acknowledgments
- Channel-based: SUBSCRIBE/PUBLISH/PSUBSCRIBE (pattern)
- Sharded pub/sub (7.0+): channels distributed across cluster nodes for scalability
```bash
# Publisher
redis-cli PUBLISH notifications '{"user":1000,"event":"login"}'

# Subscriber
redis-cli SUBSCRIBE notifications

# Pattern subscriber
redis-cli PSUBSCRIBE 'notifications.*'
```

**Streams (Redis 5.0+):**
- Persistent, append-only log with consumer groups
- Messages have auto-generated IDs: `<timestamp>-<sequence>`
- Consumer groups track which messages each consumer has processed
- Pending Entry List (PEL) tracks delivered but unacknowledged messages
- XCLAIM allows transferring stuck messages to another consumer

```bash
# Add to stream
XADD mystream * sensor_id 1234 temperature 22.5

# Create consumer group (0 = read from beginning, $ = new messages only)
XGROUP CREATE mystream mygroup 0

# Read as consumer in group
XREADGROUP GROUP mygroup consumer1 COUNT 10 BLOCK 5000 STREAMS mystream >

# Acknowledge processing
XACK mystream mygroup 1234567890-0

# Check pending messages
XPENDING mystream mygroup - + 10

# Claim stuck messages (idle > 60 seconds)
XAUTOCLAIM mystream mygroup consumer2 60000 0-0

# Trim stream to bounded length
XTRIM mystream MAXLEN ~ 1000000
```

### Lua Scripting and Functions

**EVAL/EVALSHA (Lua 5.1):**
- Atomic execution: no other command runs during a script
- Access keys via `KEYS[n]` and arguments via `ARGV[n]`
- Must declare all keys upfront (required for cluster compatibility)
- Scripts cached by SHA1 hash; use EVALSHA for repeated calls

```bash
# Atomic rate limiter
EVAL "
  local current = redis.call('INCR', KEYS[1])
  if current == 1 then
    redis.call('EXPIRE', KEYS[1], ARGV[1])
  end
  if current > tonumber(ARGV[2]) then
    return 0
  end
  return 1
" 1 rate:user:1000 60 100
# Returns 1 if under limit, 0 if exceeded
```

**Functions (Redis 7.0+):**
- Named, persistent functions stored in the server
- Organized into libraries
- Survive restarts (replicated via AOF/RDB)
- Replace ad-hoc EVAL scripts with managed code

```bash
# Load a function library
FUNCTION LOAD "#!lua name=mylib
redis.register_function('myfunc', function(keys, args)
  return redis.call('GET', keys[1])
end)
"

# Call the function
FCALL myfunc 1 mykey
```

### Memory Management

**maxmemory policies** (what happens when maxmemory is reached):

| Policy | Behavior | Use Case |
|---|---|---|
| `noeviction` | Return errors on writes | Data must never be lost |
| `allkeys-lru` | Evict least recently used | General-purpose cache |
| `allkeys-lfu` | Evict least frequently used | Cache with skewed access patterns |
| `volatile-lru` | Evict LRU among keys with TTL | Mix of persistent + cache keys |
| `volatile-lfu` | Evict LFU among keys with TTL | Mix with frequency-aware eviction |
| `volatile-ttl` | Evict keys closest to expiration | TTL-based priority |
| `allkeys-random` | Evict random keys | Uniform access patterns |
| `volatile-random` | Evict random keys with TTL | Random eviction from volatile set |

```
maxmemory 8gb
maxmemory-policy allkeys-lfu
maxmemory-samples 10        # higher = more accurate LRU/LFU, more CPU
```

**Memory fragmentation:**
- `mem_fragmentation_ratio` = RSS / used_memory
- Healthy: 1.0 - 1.5
- High (> 1.5): fragmentation; consider `MEMORY PURGE` or restart
- Below 1.0: Redis is swapping -- critical issue, increase RAM or reduce dataset

**Active defragmentation (Redis 4.0+):**
```
activedefrag yes
active-defrag-enabled yes
active-defrag-ignore-bytes 100mb
active-defrag-threshold-lower 10     # start defrag at 10% fragmentation
active-defrag-threshold-upper 100    # max effort at 100% fragmentation
active-defrag-cycle-min 1            # % CPU minimum for defrag
active-defrag-cycle-max 25           # % CPU maximum for defrag
```

### Pipelining and Transactions

**Pipelining:**
- Send multiple commands without waiting for individual responses
- Dramatically reduces round-trip latency (100x throughput improvement possible)
- Not atomic -- other clients can interleave between pipelined commands
```python
# Python redis-py pipeline
pipe = r.pipeline(transaction=False)
for i in range(10000):
    pipe.set(f'key:{i}', f'value:{i}')
pipe.execute()  # one round trip for 10,000 commands
```

**MULTI/EXEC transactions:**
- Commands queued after MULTI, executed atomically on EXEC
- No rollback (unlike SQL transactions) -- all commands execute or none if EXEC is not called
- DISCARD aborts the transaction
```bash
MULTI
SET account:1000:balance 500
SET account:2000:balance 1500
EXEC
```

**Optimistic locking with WATCH:**
```bash
WATCH account:1000:balance
balance = GET account:1000:balance
# ... compute new balance ...
MULTI
SET account:1000:balance <new_balance>
EXEC
# Returns nil if account:1000:balance was modified by another client
```

### Security

**ACLs (Redis 6.0+):**
```bash
# Create user with specific permissions
ACL SETUSER app-reader on >secretpassword ~cache:* +get +mget +scan +info
ACL SETUSER app-writer on >writepassword ~* +@write +@read -@dangerous

# List users and permissions
ACL LIST
ACL WHOAMI
ACL LOG        # recent authentication failures and permission denials
ACL CAT        # list command categories
```

**TLS/SSL:**
```
tls-port 6380
tls-cert-file /path/to/redis.crt
tls-key-file /path/to/redis.key
tls-ca-cert-file /path/to/ca.crt
tls-auth-clients optional
```

**Protected mode:**
- Enabled by default: rejects connections from non-loopback interfaces when no password is set
- Disable only for development: `protected-mode no`
- Always set a password in production: `requirepass <strong-password>` (pre-ACL) or use ACLs

### Replication

Redis uses asynchronous replication by default:

- Replicas connect to master and receive the full dataset (RDB transfer) + ongoing command stream
- Replication is non-blocking on the master side
- Replicas can serve stale reads during sync (configurable with `replica-serve-stale-data`)

**Key replication parameters:**
```
replicaof <master-ip> <master-port>
masterauth <password>
replica-read-only yes                  # default; replicas reject writes
repl-diskless-sync yes                 # send RDB directly over socket (fast for slow disks)
repl-diskless-sync-delay 5             # seconds to wait for more replicas before transfer
repl-backlog-size 256mb                # buffer for partial resync after brief disconnections
min-replicas-to-write 1                # reject writes if fewer than N replicas connected
min-replicas-max-lag 10                # replica is "connected" if lag < N seconds
```

**WAIT for synchronous replication:**
```bash
SET important-key value
WAIT 2 5000    # wait for 2 replicas to acknowledge, timeout 5000ms
# Returns number of replicas that acknowledged
```

**Diskless replication (Redis 6.0+):**
- Master sends RDB directly to replica sockets without writing to disk
- Beneficial when master disk is slow but network is fast
- `repl-diskless-sync yes` + `repl-diskless-sync-delay 5`

### Performance Optimization

**Big keys (keys with large values):**
- Strings > 1MB, collections with > 10,000 elements
- Cause: high latency on access/delete, uneven memory across cluster slots
- Detection: `redis-cli --bigkeys`, `MEMORY USAGE key`
- Mitigation: split into smaller keys, use UNLINK (async delete) instead of DEL

**Hot keys (frequently accessed keys):**
- Detection: `redis-cli --hotkeys` (requires maxmemory-policy with LFU)
- Mitigation: read replicas, client-side caching, key sharding (split across multiple keys)

**Slow log:**
```bash
CONFIG SET slowlog-log-slower-than 10000   # log commands > 10ms (in microseconds)
CONFIG SET slowlog-max-len 256             # keep last 256 entries
SLOWLOG GET 10                             # view last 10 slow commands
SLOWLOG LEN                                # total entries
SLOWLOG RESET                              # clear the log
```

**Latency monitoring:**
```bash
CONFIG SET latency-monitor-threshold 10    # track events > 10ms
LATENCY LATEST                             # latest latency events
LATENCY HISTORY event-name                 # history for specific event
LATENCY GRAPH event-name                   # ASCII art graph
LATENCY RESET                              # reset tracking
```

## Common Pitfalls

1. **Using KEYS in production** -- KEYS blocks the server while scanning the entire keyspace. Use SCAN with COUNT instead. SCAN is cursor-based and non-blocking.

2. **Storing large objects as single keys** -- A 50MB string key blocks the server during serialization/deserialization. Break into chunks or use Hashes.

3. **Not setting maxmemory** -- Without maxmemory, Redis grows until the OS OOM-killer terminates it. Always set maxmemory and an eviction policy.

4. **Ignoring fork overhead** -- RDB saves and AOF rewrites fork the process. With large datasets (>10GB), fork can take seconds and double memory (copy-on-write). Monitor `latest_fork_usec` in INFO.

5. **Pub/Sub without backpressure** -- Slow subscribers cause the output buffer to grow, eventually disconnecting the client or consuming excessive memory. Use Streams for durable messaging.

6. **Blocking commands in production** -- BLPOP, BRPOP, XREAD BLOCK are fine in worker patterns but risky in connection-limited setups. Each blocking client holds a connection.

7. **Cross-slot operations in Cluster** -- Multi-key commands (MGET, MSET, pipeline) fail if keys span different hash slots. Use hash tags: `{prefix}:key1`, `{prefix}:key2`.

8. **Not monitoring replication lag** -- Async replication means replicas can lag. Monitor `master_repl_offset` vs `slave_repl_offset` in INFO replication. Use WAIT for critical writes.

9. **Excessive TTL churn** -- Setting TTL on millions of keys that expire simultaneously causes CPU spikes during lazy/active expiry. Spread TTLs with jitter.

10. **Running DEBUG commands in production** -- DEBUG SLEEP, DEBUG OBJECT (in some contexts) can block the server. Use OBJECT ENCODING, OBJECT FREQ, MEMORY USAGE instead.

## Version Routing

| Version | Status | Key Feature | Route To |
|---|---|---|---|
| **Redis 8.0** | Current | Major release: new features, breaking changes, performance | `8.0/SKILL.md` |
| **Redis 7.8** | Supported | New data types, cluster improvements | `7.8/SKILL.md` |
| **Redis 7.4** | Supported | Hash field expiration, new cluster commands | `7.4/SKILL.md` |
| **Redis 7.2** | Supported (EOL Feb 2026) | Client-side caching improvements, WAITAOF, sharded pub/sub | `7.2/SKILL.md` |

## Reference Files

Load these when you need deep knowledge for a specific area:

- `references/architecture.md` -- Event loop, memory allocator, data structure encodings, persistence internals, cluster protocol, replication protocol. Read for "how does Redis work internally" questions.
- `references/diagnostics.md` -- INFO sections, SLOWLOG, LATENCY, MEMORY, CLIENT LIST, cluster diagnostics, sentinel diagnostics, redis-cli tools. Read when troubleshooting performance or operational issues.
- `references/best-practices.md` -- redis.conf tuning, persistence strategy, cluster sizing, sentinel deployment, security hardening, key naming, monitoring. Read for configuration and operational guidance.
