# Paradigm: Key-Value Stores

When and why to choose a key-value database. Covers Redis, DynamoDB, Memcached, etcd, and Aerospike.

## What Defines a Key-Value Store

The simplest database model: a key maps to a value. The database treats the value as an opaque blob -- it has no knowledge of the value's internal structure (with notable exceptions like Redis, which supports typed data structures).

Operations are typically limited to:
- `GET key` -- Retrieve value by exact key
- `SET key value` -- Store or overwrite a value
- `DELETE key` -- Remove a key-value pair
- `EXISTS key` -- Check if a key exists

This simplicity enables extreme performance: O(1) lookups, sub-millisecond latency, and straightforward horizontal scaling via consistent hashing.

## Choose Key-Value Stores When

- **Access patterns are simple and key-based.** The application always knows the key. Session stores (session ID -> session data), user preferences (user ID -> settings), feature flags (flag name -> config).
- **Sub-millisecond latency is required.** Redis serves ~100K-500K operations/sec per core. Memcached achieves similar throughput. No query parser, no optimizer, no planner -- just hash lookup.
- **Caching is the primary use case.** Cache database query results, API responses, computed aggregations. TTL-based expiration (`EXPIRE key 3600`) handles invalidation.
- **Rate limiting, counters, and leaderboards.** Redis `INCR`/`DECR` are atomic. Sorted sets (`ZADD`/`ZRANGEBYSCORE`) implement leaderboards in O(log n).
- **Distributed locking.** Redis `SET key value NX EX 30` implements a distributed lock (Redlock algorithm for multi-node). etcd uses lease-based locks with consensus guarantees.
- **Configuration and service discovery.** etcd and Consul store cluster configuration with strong consistency and watch-based change notification.

## Avoid Key-Value Stores When

- **Queries involve multiple keys or relationships.** "Find all users in region X with status Y" requires a full scan or a secondary index that key-value stores don't natively support.
- **Transactions span multiple keys.** Redis MULTI/EXEC provides atomicity but not isolation. DynamoDB TransactWriteItems supports up to 100 items but with significant latency overhead.
- **Data exceeds available memory (Redis/Memcached).** Redis stores everything in RAM. Data that doesn't fit requires Redis on Flash, clustering with more nodes, or a different technology.
- **Complex data transformations are needed.** Aggregations, JOINs, filtering on value attributes. Key-value stores offload this to the application layer.
- **Audit trails or change history are required.** Key-value stores overwrite in place. Some support streams (Redis Streams, DynamoDB Streams) but these are append-only logs, not point-in-time snapshots.

## Technology Comparison

| Feature | Redis | DynamoDB | Memcached | etcd | Aerospike |
|---|---|---|---|---|---|
| **Data Model** | Typed structures (strings, hashes, lists, sets, sorted sets, streams) | Key-value + document (attribute maps) | Simple key-value (string blobs) | Key-value (string keys, byte values) | Key-value with bins (typed columns) |
| **Persistence** | RDB snapshots + AOF log | Fully managed (durable) | None (pure cache) | WAL + snapshots (Raft) | Hybrid memory + SSD |
| **Clustering** | Redis Cluster (hash slots) | Fully managed (auto-partitioned) | Client-side consistent hashing | Raft consensus (3+ nodes) | Smart Client, auto-rebalancing |
| **Max Value Size** | 512 MB | 400 KB | 1 MB (default, configurable) | 1.5 MB | 8 MB (default) |
| **Consistency** | Eventual (async replication) | Tunable (eventually/strongly consistent reads) | None (cache) | Strong (linearizable) | Strong (per-record) or relaxed |
| **Latency** | <1 ms (single node) | <10 ms (single-digit ms) | <1 ms | <10 ms | <1 ms (memory), <2 ms (SSD) |
| **Best For** | Caching, real-time, pub/sub, data structures | Serverless, predictable scale, AWS-native | Pure caching (simpler than Redis) | Config store, service discovery, distributed locks | High-throughput at scale, hybrid storage |

## Redis: The Swiss Army Knife

Redis is far more than a simple key-value store. Its typed data structures make it a data structure server.

### Core Data Structures

```bash
# Strings: caching, counters, simple values
SET user:42:name "Alice"
GET user:42:name
INCR page:views:2025-03-15    # Atomic counter

# Hashes: objects with multiple fields
HSET user:42 name "Alice" email "alice@example.com" role "admin"
HGET user:42 email
HGETALL user:42

# Lists: queues, recent items
LPUSH notifications:42 '{"type":"order","id":1001}'
RPOP notifications:42                          # Queue (FIFO with LPUSH/RPOP)
LRANGE notifications:42 0 9                    # Last 10 items

# Sets: unique collections, tagging
SADD product:42:tags "electronics" "sale" "featured"
SISMEMBER product:42:tags "sale"               # O(1) membership test
SINTER product:42:tags product:99:tags         # Intersection

# Sorted Sets: leaderboards, time-based data
ZADD leaderboard 9500 "player:1" 8700 "player:2" 9100 "player:3"
ZREVRANGE leaderboard 0 9 WITHSCORES          # Top 10
ZRANGEBYSCORE leaderboard 9000 +inf           # Players above 9000

# Streams: event log / message broker
XADD orders * customer_id 42 amount 89.97
XREAD COUNT 10 STREAMS orders 0               # Read from beginning
XREADGROUP GROUP processors consumer1 COUNT 1 BLOCK 5000 STREAMS orders >
```

### Redis Patterns

**Cache-Aside (Lazy Loading):**
```
1. Application checks Redis: GET product:42
2. Cache miss -> query database
3. Store result: SET product:42 '{...}' EX 3600
4. Next request: cache hit
```

**Write-Through:**
```
1. Application writes to database
2. Application writes to Redis: SET product:42 '{...}'
3. Both are always in sync (at the cost of write latency)
```

**Distributed Locking:**
```bash
# Acquire lock (atomic: set only if not exists, with expiry)
SET lock:order:1001 "owner:server1" NX EX 30

# Release lock (only if we own it -- use Lua script for atomicity)
# EVAL "if redis.call('get',KEYS[1]) == ARGV[1] then return redis.call('del',KEYS[1]) else return 0 end" 1 lock:order:1001 owner:server1
```

### Redis Configuration Essentials

```conf
# Memory management
maxmemory 4gb
maxmemory-policy allkeys-lru     # Evict least recently used keys when full
                                  # Options: volatile-lru, allkeys-lfu, volatile-ttl, noeviction

# Persistence
save 900 1                        # RDB: snapshot every 900s if >= 1 key changed
save 300 10
appendonly yes                    # AOF: log every write
appendfsync everysec              # fsync once per second (compromise: speed vs durability)

# Replication
replicaof 10.0.0.1 6379          # This node replicates from the primary
replica-read-only yes
```

## DynamoDB: Serverless Key-Value at Scale

DynamoDB is key-value + document hybrid with predictable performance at any scale.

### Key Design

```
Partition Key (PK): determines physical partition via hash
Sort Key (SK): enables range queries within a partition

Table: Orders
PK: customer_id    SK: order_date#order_id
                    2025-03-15#1001 -> {items: [...], total: 89.97}
                    2025-03-16#1002 -> {items: [...], total: 45.50}

Query: all orders for customer 42 in March 2025
  PK = "cust_42" AND SK BEGINS_WITH "2025-03"
```

### Access Patterns Drive Design

DynamoDB requires single-table design for complex access patterns:
- Identify all access patterns upfront
- Design PK/SK to support them without scans
- Use Global Secondary Indexes (GSI) for alternative access patterns
- Use `BEGINS_WITH`, `BETWEEN`, `>`, `<` on sort keys for range queries

### Capacity and Cost

- **On-Demand**: Pay per request. Good for unpredictable workloads. ~$1.25 per million writes, ~$0.25 per million reads.
- **Provisioned**: Reserve capacity. Cheaper for steady workloads. Auto-scaling available.
- **Reserved Capacity**: 1-3 year commitment for lowest cost.
- Read Consistency: Eventually consistent reads cost half of strongly consistent reads.

## Common Pitfalls

1. **Using Redis as a primary database without persistence.** If `appendonly` is off and the server crashes, all data since the last RDB snapshot is lost. Enable AOF for any data that matters.
2. **Hot keys in DynamoDB.** A single partition key receiving disproportionate traffic throttles the entire partition. Distribute load with key suffixing (e.g., `partition_key#shard_N`).
3. **Memcached for anything beyond caching.** Memcached has no persistence, no data structures, no pub/sub. If you need any of these, use Redis.
4. **Ignoring Redis memory limits.** Without `maxmemory` and an eviction policy, Redis will use all available RAM and get OOM-killed. Always set `maxmemory` in production.
5. **Treating DynamoDB like an RDBMS.** Scans are expensive and slow. If your access patterns require table scans, DynamoDB is the wrong choice. Design the key schema around your queries, not your data model.
6. **Single-node Redis for production locks.** Redis replication is asynchronous. A failover can grant the same lock to two clients. Use Redlock (multi-node) or a consensus system (etcd, ZooKeeper) for critical locks.
