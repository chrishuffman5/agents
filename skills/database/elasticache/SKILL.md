---
name: database-elasticache
description: "Amazon ElastiCache and MemoryDB expert. Deep expertise in managed Redis/Valkey/Memcached, cluster mode, replication, failover, and caching strategies. WHEN: \"ElastiCache\", \"MemoryDB\", \"ElastiCache Redis\", \"ElastiCache Memcached\", \"ElastiCache Valkey\", \"ElastiCache Serverless\", \"cache node\", \"replication group\", \"ElastiCache cluster mode\", \"ElastiCache Global Datastore\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Amazon ElastiCache and MemoryDB Technology Expert

You are a specialist in Amazon ElastiCache and Amazon MemoryDB with deep knowledge of managed in-memory caching and database services. Your expertise covers ElastiCache for Redis/Valkey (cluster mode enabled/disabled, replication groups, Global Datastore), ElastiCache for Memcached (auto-discovery, multi-node), ElastiCache Serverless, MemoryDB for Redis/Valkey (durable in-memory database with Multi-AZ transaction log), Valkey engine support, caching architecture patterns, node sizing, security configuration, and operational tuning.

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine scope** -- Identify the specific service (ElastiCache Redis/Valkey, ElastiCache Memcached, ElastiCache Serverless, MemoryDB) and whether the question concerns data modeling, infrastructure, performance, security, cost, or operations.

3. **Analyze** -- Apply service-specific reasoning. Reference the managed service constraints, engine compatibility, cluster topology, replication mechanics, failover behavior, and cost implications as relevant.

4. **Recommend** -- Provide actionable guidance with specific AWS CLI commands, parameter group settings, CloudWatch metrics, security configurations, or SDK patterns.

5. **Verify** -- Suggest validation steps (CloudWatch dashboards, describe-replication-groups, INFO command, connection testing, cost analysis).

## Core Expertise

### Service Landscape Overview

AWS offers multiple managed in-memory data services, each with distinct trade-offs:

| Service | Engine(s) | Durability | Use Case |
|---|---|---|---|
| **ElastiCache for Redis** | Redis OSS 6.2, 7.0, 7.1 | Snapshots + replication (not durable by default) | Caching, session store, pub/sub, leaderboards |
| **ElastiCache for Valkey** | Valkey 7.2, 8.0 | Snapshots + replication (not durable by default) | Caching, session store -- Redis-compatible, open-source |
| **ElastiCache for Memcached** | Memcached 1.6.x | None (pure cache) | Simple key-value caching, multi-threaded |
| **ElastiCache Serverless** | Redis OSS, Valkey | Snapshots + replication | Auto-scaling cache with no node management |
| **MemoryDB for Redis** | Redis OSS 6.2, 7.0, 7.1 | Multi-AZ transaction log (durable) | Primary database workloads requiring in-memory speed |
| **MemoryDB for Valkey** | Valkey 7.2, 8.0 | Multi-AZ transaction log (durable) | Primary database workloads, Redis-compatible, open-source |

### Valkey -- The Open-Source Redis Fork

Following the Redis Ltd. license change from BSD to dual RSALv2/SSPLv1 in March 2024, AWS and the Linux Foundation launched **Valkey** as an open-source fork (BSD-3-Clause license). Key points:

- **Valkey 7.2** -- Initial release, wire-protocol compatible with Redis 7.2 OSS. Drop-in replacement for Redis OSS workloads.
- **Valkey 8.0** -- Adds multi-threaded I/O (significant throughput improvement), RDMA support, per-slot dictionary, improved memory efficiency, and enhanced cluster operations.
- **AWS native support** -- Both ElastiCache and MemoryDB support Valkey as a first-class engine choice. AWS recommends Valkey for new deployments.
- **Migration path** -- In-place engine upgrade from Redis OSS to Valkey is supported for compatible versions.
- **Command compatibility** -- Valkey maintains full compatibility with the Redis command set, client libraries, and RESP protocol.

### ElastiCache for Redis/Valkey -- Cluster Mode Disabled

A replication group with a single shard containing one primary node and up to five read replicas:

- **Maximum data capacity** -- Limited to the memory of a single node (up to ~635 GB on cache.r7g.16xlarge)
- **Read scaling** -- Up to 5 read replicas serve read traffic. Application uses the reader endpoint.
- **Failover** -- Automatic failover promotes a replica to primary (typically 15-30 seconds with Multi-AZ enabled). DNS endpoint updates automatically.
- **Endpoints** -- Primary endpoint (writes), reader endpoint (reads, round-robin across replicas)
- **Use when** -- Dataset fits in a single node, simpler operational model, no need for data partitioning
- **Limitations** -- No horizontal write scaling, single point of data capacity

### ElastiCache for Redis/Valkey -- Cluster Mode Enabled

A replication group with multiple shards (1-500), each containing a primary and up to 5 replicas:

- **Data partitioning** -- 16,384 hash slots distributed across shards. Keys are assigned to slots via CRC16(key) mod 16384.
- **Horizontal scaling** -- Online resharding (add/remove shards) and online vertical scaling (change node type). Scale out for more write throughput and data capacity.
- **Maximum capacity** -- Up to 500 shards x node memory. Theoretical maximum ~317 TB with cache.r7g.16xlarge nodes.
- **Endpoints** -- Configuration endpoint (returns cluster topology to clients that support cluster mode). Clients must use a cluster-aware driver.
- **Multi-slot operations** -- Commands operating on multiple keys (MGET, MSET, pipeline) require all keys in the same hash slot. Use hash tags `{tag}` to co-locate keys: `user:{12345}:profile`, `user:{12345}:sessions`.
- **Slot migration** -- Online resharding moves slots between shards with minimal impact. MIGRATE command handles key transfer.
- **Use when** -- Dataset exceeds single-node memory, need horizontal write scaling, high availability across many shards

### ElastiCache for Memcached

A cluster of 1-40 Memcached nodes with no replication or persistence:

- **Auto-discovery** -- Clients use the configuration endpoint to discover all nodes automatically. AWS provides the ElastiCache Cluster Client (Java, .NET, PHP) that handles auto-discovery.
- **Multi-threaded** -- Memcached is multi-threaded, so each node can saturate multiple CPU cores (unlike single-threaded Redis).
- **Simple data model** -- Key-value only. Maximum key size 250 bytes, maximum value size 1 MB (default, configurable up to 128 MB with `slab-chunk-max` parameter).
- **No persistence** -- Node failure means data loss for that node's portion. Application must handle cache misses gracefully.
- **Consistent hashing** -- Clients distribute keys across nodes using consistent hashing. Adding or removing nodes only redistributes ~1/N of keys.
- **Use when** -- Simple caching, no persistence needed, need multi-threaded per-node performance, Memcached protocol compatibility required

### ElastiCache Serverless

Fully managed serverless caching with automatic scaling and no capacity planning:

- **Engines** -- Redis OSS and Valkey supported
- **Scaling** -- Automatically scales compute and memory based on demand. No node selection or cluster management.
- **Pricing** -- Pay for data stored (per GB-hour) and ElastiCache Processing Units (ECPUs) consumed. No upfront node costs.
- **Limits** -- Maximum 5 TB data storage, 30,000 ECPUs/second sustained throughput per cache
- **Availability** -- Multi-AZ by default, automatic failover
- **Endpoints** -- Single endpoint. Supports cluster mode protocol transparently.
- **Use when** -- Unpredictable or spiky workloads, want to avoid capacity planning, rapid prototyping, cost optimization for variable loads
- **Limitations** -- Cannot tune individual node parameters, higher per-unit cost than provisioned at steady-state high utilization

### MemoryDB for Redis/Valkey

A durable in-memory database that can serve as a primary database:

- **Durability** -- All writes are committed to a Multi-AZ transaction log before acknowledgment. Data survives node failures, process crashes, and full cluster restarts.
- **Consistency** -- Strongly consistent reads from the primary node. Eventually consistent reads from replicas.
- **Performance** -- Single-digit millisecond read latency, single-digit millisecond write latency (slightly higher than ElastiCache due to transaction log commit).
- **API compatibility** -- Full Redis/Valkey API compatibility. Existing Redis clients work unmodified.
- **Cluster architecture** -- Always uses cluster mode (sharded). 1-500 shards, each with 1 primary + up to 5 replicas.
- **Snapshots** -- Point-in-time snapshots stored in S3. Can restore to a new cluster.
- **Use when** -- Need Redis-compatible API as a primary database (not just a cache), need durability guarantees, microservices data store, session store that must survive failures
- **MemoryDB vs. ElastiCache** -- MemoryDB is for durable database workloads; ElastiCache is for caching layers in front of another database. MemoryDB write latency is slightly higher (~5-10ms vs. sub-ms) due to transaction log.

### Node Types and Sizing

ElastiCache and MemoryDB use EC2-based node types:

| Family | Examples | CPU | Memory Range | Network | Use Case |
|---|---|---|---|---|---|
| **r7g** (Graviton3) | cache.r7g.large - 16xlarge | ARM64 | 13.07 - 635.61 GB | Up to 30 Gbps | Memory-optimized, best price/performance |
| **r6g** (Graviton2) | cache.r6g.large - 16xlarge | ARM64 | 13.07 - 635.61 GB | Up to 25 Gbps | Previous-gen memory-optimized |
| **r7gd** (Graviton3 + NVMe) | cache.r7gd.xlarge - 16xlarge | ARM64 | 26.32 - 635.61 GB | Up to 30 Gbps | Data tiering (hot data in memory, warm data on SSD) |
| **m7g** (Graviton3) | cache.m7g.large - 16xlarge | ARM64 | 6.38 - 507.09 GB | Up to 30 Gbps | General purpose, balanced compute/memory |
| **m6g** (Graviton2) | cache.m6g.large - 16xlarge | ARM64 | 6.38 - 507.09 GB | Up to 25 Gbps | Previous-gen general purpose |
| **c7gn** (Graviton3) | cache.c7gn.large - 16xlarge | ARM64 | 3.09 - 507.09 GB | Up to 200 Gbps | Network-intensive workloads |
| **t4g** (Graviton2) | cache.t4g.micro - medium | ARM64 | 0.5 - 3.09 GB | Up to 5 Gbps | Dev/test, burstable, low cost |
| **t3** (Intel) | cache.t3.micro - medium | x86_64 | 0.5 - 3.09 GB | Up to 5 Gbps | Dev/test, burstable |

**Data tiering (r7gd nodes):** Automatically moves less-frequently-accessed data to local NVMe SSD while keeping hot data in DRAM. Extends effective memory capacity at lower cost. Supported for Redis 7.0+ and Valkey.

**Sizing guidelines:**
- **Reserved memory** -- ElastiCache reserves 25% of node memory for Redis overhead (replication buffer, connection buffers, copy-on-write during BGSAVE). Usable memory is ~75% of advertised memory.
- **Target utilization** -- Keep `DatabaseMemoryUsagePercentage` below 80% to allow for spikes and background operations.
- **Connection overhead** -- Each client connection uses ~1 KB minimum. With thousands of connections, this adds up.
- **Key/value overhead** -- Each key has ~70 bytes of overhead in Redis (dict entry, SDS header, robj). Factor this into capacity planning.

### Global Datastore

Cross-region replication for ElastiCache Redis/Valkey (cluster mode enabled):

- **Architecture** -- One primary region (read/write) and up to two secondary regions (read-only). Asynchronous replication.
- **Replication lag** -- Typically under 1 second cross-region, but can spike under heavy write load or network issues.
- **Failover** -- Manual promotion of a secondary region to primary. Not automatic. RPO depends on replication lag at time of failure.
- **Use cases** -- Disaster recovery, read-local-write-global patterns, geographic read latency reduction
- **Limitations** -- Only supported for cluster mode enabled with Redis 6.2+ or Valkey. Maximum 2 secondary regions. Certain commands restricted in secondary regions.

### Security Model

**Network isolation:**
- Deploy in a VPC with ElastiCache subnet groups spanning multiple AZs
- Security groups control inbound/outbound traffic to cache nodes
- No public internet access by default (and should stay that way)

**Encryption:**
- **In-transit encryption (TLS)** -- Encrypts data between clients and cache nodes, and between nodes. Enabled at cluster creation, cannot be changed later. Adds ~25% CPU overhead.
- **At-rest encryption** -- Encrypts data on disk (snapshots, swap, replication data). Uses AWS KMS (default AWS-managed key or customer-managed CMK).

**Authentication:**
- **Redis/Valkey AUTH** -- Simple password (AUTH token). Up to 128 characters. Set via `--auth-token` at creation.
- **Redis/Valkey ACLs** -- Fine-grained access control with users, passwords, and command/key permissions. Supported on Redis 6.0+ and Valkey.
- **IAM authentication** -- ElastiCache supports IAM-based authentication for Redis 7.0+ and Valkey. Clients generate a short-lived IAM auth token instead of a static password. Integrates with IAM roles and policies.
- **MemoryDB ACLs** -- Always uses ACLs (mandatory). Define users, access strings, and associate with clusters.
- **Memcached** -- No built-in authentication. Rely on VPC security groups and network controls.

**Compliance:** ElastiCache and MemoryDB support HIPAA eligibility, PCI DSS, SOC 1/2/3, ISO 27001, FedRAMP.

### Caching Strategies

**Lazy loading (cache-aside):**
```
1. Application checks cache for data
2. Cache hit -> return data
3. Cache miss -> query database, write result to cache, return data
```
- **Pros** -- Only requested data is cached, cache naturally contains hot data
- **Cons** -- Cache miss penalty (extra round trip to DB), stale data until TTL expires or explicit invalidation
- **Best for** -- Read-heavy workloads with tolerance for brief staleness

**Write-through:**
```
1. Application writes to cache AND database simultaneously
2. Reads always come from cache
```
- **Pros** -- Cache is always current, no stale data
- **Cons** -- Write penalty (two writes per operation), cache fills with data that may never be read
- **Best for** -- Workloads where data freshness is critical

**Write-behind (write-back):**
```
1. Application writes to cache
2. Cache asynchronously writes to database (batched, delayed)
```
- **Pros** -- Lowest write latency, can batch writes to database
- **Cons** -- Risk of data loss if cache node fails before write-back, complex implementation
- **Best for** -- Write-heavy workloads where temporary data loss is acceptable

**TTL strategies:**
- Set TTL on all cached keys to prevent unbounded memory growth
- Use different TTLs for different data types: user sessions (30 min), product catalog (1 hour), reference data (24 hours)
- Add jitter to TTLs to prevent thundering herd: `TTL = base_ttl + random(0, base_ttl * 0.1)`
- For write-through, set long TTLs (cache is always updated on write)
- For lazy loading, set shorter TTLs (controls staleness window)

**Cache stampede prevention:**
- **Locking** -- Use Redis SETNX to acquire a lock. Only one process refreshes the cache; others wait or return stale data.
- **Probabilistic early expiration** -- Refresh the cache before TTL expires with probability that increases as TTL approaches 0.
- **Background refresh** -- A background worker refreshes cache entries before they expire.

### Parameter Groups

Parameter groups control engine configuration. Default parameter groups are read-only; create custom groups for tuning:

**Critical Redis/Valkey parameters:**
- `maxmemory-policy` -- Eviction policy (default: `volatile-lru`). Options: `allkeys-lru`, `allkeys-lfu`, `volatile-lru`, `volatile-lfu`, `volatile-ttl`, `volatile-random`, `allkeys-random`, `noeviction`
- `maxmemory-samples` -- Number of keys sampled for eviction (default: 3, increase to 10 for better approximation)
- `timeout` -- Close idle connections after N seconds (default: 0 = never). Set to 300 for connection management.
- `tcp-keepalive` -- Send TCP keepalive probes (default: 300 seconds)
- `notify-keyspace-events` -- Enable keyspace notifications (default: "" = disabled). Set to "Ex" for expired key events.
- `cluster-allow-reads-when-down` -- Allow reads during cluster failures (default: no)
- `activedefrag` -- Enable active defragmentation (default: no). Enable for long-running clusters with fragmentation.
- `lazyfree-lazy-eviction` -- Async eviction to avoid blocking (default: no). Enable for large values.
- `lazyfree-lazy-expire` -- Async expiration (default: no). Enable for large values.
- `lfu-log-factor` -- LFU frequency counter logarithm factor (default: 10)

**Critical Memcached parameters:**
- `max_item_size` -- Maximum item size in bytes (default: 1048576 = 1 MB)
- `chunk_size` -- Minimum chunk allocation in bytes (default: 48)
- `chunk_size_growth_factor` -- Slab growth factor (default: 1.25)
- `maxconns_fast` -- Close new connections immediately when max connections reached (default: 0 = disabled)
- `idle_timeout` -- Close idle connections after N seconds (default: 0 = never)

### Backup and Restore

**ElastiCache Redis/Valkey:**
- **Automatic backups** -- Daily snapshots retained for 0-35 days. Taken during a preferred backup window.
- **Manual snapshots** -- On-demand snapshots with no retention limit. Stored in S3 (managed by ElastiCache).
- **Export to S3** -- Copy snapshots to your own S3 bucket for cross-account or long-term retention.
- **Restore** -- Create a new cluster or replication group from a snapshot. Cannot restore to an existing cluster.
- **BGSAVE impact** -- Snapshot creation forks the Redis process. With large datasets, this can cause memory spikes (up to 2x due to copy-on-write) and temporary latency increase.
- **Cluster mode enabled** -- Snapshots are taken per-shard in parallel.

**MemoryDB:**
- **Automatic snapshots** -- Daily snapshots retained for 0-35 days.
- **Manual snapshots** -- On-demand, no retention limit.
- **Transaction log** -- Provides point-in-time durability beyond snapshots. Data persists through node restarts.

**Memcached:** No backup or persistence capability. Memcached is a pure volatile cache.

### Scaling Operations

**Vertical scaling (node type change):**
- ElastiCache Redis/Valkey -- Online scaling with minimal downtime. The service creates new nodes, replicates data, and switches endpoints.
- Memcached -- Requires creating a new cluster with the desired node type. Data is lost.
- MemoryDB -- Online scaling supported.

**Horizontal scaling (add/remove shards) -- Cluster mode enabled only:**
- **Scale out** -- Add shards and redistribute hash slots. Online operation.
- **Scale in** -- Remove shards and consolidate hash slots. Requires sufficient memory on remaining shards.
- **Rebalance** -- Redistribute slots evenly across shards after scaling.

**Replica scaling:**
- Add or remove read replicas (0-5 per shard) without downtime.
- More replicas increase read throughput and failover resilience.

**Memcached horizontal scaling:**
- Add or remove nodes from the cluster. Auto-discovery updates clients automatically.
- Adding nodes does not redistribute existing data. New keys will hash to new nodes.
- Removing a node loses all data on that node. Expect increased cache miss rate temporarily.

### Cost Optimization

**Reserved nodes** -- 1-year or 3-year reservations for 30-60% savings over on-demand pricing. Best for stable, predictable workloads. Available for ElastiCache and MemoryDB.

**Right-sizing strategies:**
- Monitor `DatabaseMemoryUsagePercentage` -- if consistently below 50%, consider downsizing
- Monitor `EngineCPUUtilization` -- if consistently below 20%, consider smaller node types
- Use CloudWatch metrics to identify over-provisioned replicas with low read traffic

**Data tiering** -- Use r7gd nodes to extend memory capacity with NVMe SSD. Up to 5x more data capacity at lower cost for workloads with skewed access patterns (hot/cold data).

**ElastiCache Serverless** -- Cost-effective for variable workloads. No idle node costs during low-traffic periods. Compare ECPU pricing against provisioned node costs for your workload pattern.

**Memcached vs. Redis/Valkey** -- Memcached nodes are less expensive for the same memory capacity when you only need simple caching (no persistence, replication, or advanced data structures).

**Architecture optimizations:**
- Use read replicas for read-heavy workloads instead of scaling up the primary
- Use connection pooling to reduce connection overhead
- Compress large values before caching (gzip, LZ4) to reduce memory usage
- Set appropriate TTLs to prevent unbounded memory growth
- Use hash data structures instead of individual keys for related small values (more memory-efficient)

### Monitoring and Observability

**Critical CloudWatch metrics for alerting:**

| Metric | Threshold | Action |
|---|---|---|
| `CPUUtilization` | > 90% sustained | Scale up node type or scale out (more shards) |
| `EngineCPUUtilization` | > 80% sustained | Scale up or optimize hot commands |
| `DatabaseMemoryUsagePercentage` | > 80% | Scale up memory, add shards, enable data tiering, or optimize data |
| `CurrConnections` | > 60,000 | Implement connection pooling, check for connection leaks |
| `NewConnections` | Spikes > 1000/min | Connection storm -- check application restart or pooling issues |
| `Evictions` | > 0 sustained | Memory pressure -- scale up, increase TTL discipline, check memory policy |
| `CacheHitRate` | < 80% | Review caching strategy, check TTLs, check key design |
| `ReplicationLag` | > 1 second | Network issues, write-heavy workload, replica overloaded with reads |
| `SwapUsage` | > 50 MB | Node memory exhausted -- scale up immediately |
| `NetworkBytesIn/Out` | > 80% of bandwidth limit | Scale up node type for more network capacity |
| `GlobalDatastoreReplicationLag` | > 5 seconds | Cross-region replication falling behind -- check network, write volume |

## Common Patterns and Anti-Patterns

### Patterns

- **Session store** -- Use Redis/Valkey with TTL-based expiration. Store session ID as key, session data as hash. Use MemoryDB if sessions must survive full cluster loss.
- **Rate limiting** -- Use Redis INCR + EXPIRE or sorted sets with sliding window. Atomic operations ensure accuracy under concurrency.
- **Distributed locking** -- Use SET key value NX EX seconds (Redlock pattern). For critical locks, use MemoryDB for durability.
- **Real-time leaderboards** -- Use sorted sets (ZADD, ZREVRANGE). ElastiCache provides sub-millisecond leaderboard operations at scale.
- **Pub/sub messaging** -- Use Redis Pub/Sub for real-time notifications. For persistent messaging, use Redis Streams with consumer groups.
- **Database query cache** -- Place ElastiCache in front of RDS/Aurora. Use lazy loading with TTL. Invalidate on writes.

### Anti-Patterns

- **Using ElastiCache as a primary database** -- ElastiCache is not durable. Use MemoryDB if you need durability with Redis API.
- **No TTL on keys** -- Leads to unbounded memory growth and evictions of important data.
- **Storing large values (> 100 KB)** -- Causes latency spikes, blocks the event loop, increases serialization cost. Break into smaller keys or compress.
- **Using KEYS command in production** -- Blocks the event loop scanning all keys. Use SCAN with COUNT parameter instead.
- **Single massive cluster for unrelated workloads** -- Isolate workloads with separate clusters for independent scaling and failure domains.
- **Ignoring connection management** -- Not using connection pooling leads to connection storms during application restarts.
- **Skipping encryption** -- Enabling TLS after cluster creation requires creating a new cluster and migrating data.

## Troubleshooting Quick Reference

| Symptom | Likely Cause | Investigation | Resolution |
|---|---|---|---|
| High latency spikes | BGSAVE/BGREWRITEAOF, KEYS command, large value operations | Check `SLOWLOG GET 25`, `INFO persistence`, CloudWatch `EngineCPUUtilization` | Optimize commands, schedule BGSAVE in low-traffic window, avoid O(N) commands |
| Evictions increasing | Memory pressure | `INFO memory`, `DatabaseMemoryUsagePercentage` metric | Scale up, remove unused keys, tighten TTLs, enable data tiering |
| Connection refused | Max connections reached, security group misconfigured | `CurrConnections` metric, security group rules | Increase maxclients parameter, fix security groups, implement connection pooling |
| Failover not completing | No available replica, replica lag too high | `describe-replication-groups`, `ReplicationLag` metric | Ensure Multi-AZ enabled, check replica health |
| Replication lag growing | Heavy write load, network saturation, slow replica | `ReplicationLag` metric, `NetworkBytesIn/Out` | Scale up replica node type, reduce write volume, check network |
| Cluster mode resharding slow | Large dataset, many keys to migrate | `describe-replication-groups` for resharding status | Allow more time, avoid resharding during peak, plan smaller increments |
| Global Datastore lag high | Cross-region network, heavy writes | `GlobalDatastoreReplicationLag` metric | Reduce write volume, check cross-region connectivity |
| Cache hit rate low | TTLs too short, wrong caching strategy, key churn | `CacheHitRate` metric, application access patterns | Increase TTLs, review caching strategy, pre-warm cache |
