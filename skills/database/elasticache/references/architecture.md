# Amazon ElastiCache and MemoryDB Architecture Reference

## ElastiCache for Redis/Valkey Architecture

### Cluster Topology -- Cluster Mode Disabled

A single-shard replication group consisting of one primary node and up to five read replicas:

```
                    +-----------------------+
                    |   Primary Endpoint    |  (writes + reads)
                    |   (DNS CNAME)         |
                    +-----------+-----------+
                                |
                    +-----------v-----------+
                    |     Primary Node      |
                    |   (read/write)        |
                    +-----------+-----------+
                      |         |         |
           +----------+    +----+----+    +-----------+
           |               |         |                |
    +------v------+ +------v------+ +------v------+   ...up to 5
    | Replica 1   | | Replica 2   | | Replica 3   |   replicas
    | (read-only) | | (read-only) | | (read-only) |
    +-------------+ +-------------+ +-------------+
           |              |               |
    +------v--------------v---------------v------+
    |            Reader Endpoint                  |
    |  (DNS CNAME, round-robin across replicas)   |
    +---------------------------------------------+
```

**Replication mechanics:**
- Asynchronous replication from primary to all replicas
- Primary sends a stream of write commands to replicas via the replication backlog buffer (`repl-backlog-size`, default 1 MB in ElastiCache, auto-tuned)
- If a replica disconnects and reconnects, partial resynchronization is attempted using the backlog. If the backlog is insufficient, a full resynchronization (RDB transfer) occurs.
- Full resync: Primary executes BGSAVE, transfers the RDB file to the replica, then replays buffered writes. This causes memory and CPU pressure on the primary.
- Replica lag is typically sub-millisecond within the same AZ, low single-digit milliseconds cross-AZ

**Failover process (Multi-AZ enabled):**
1. ElastiCache detects primary node failure (missed heartbeats)
2. Selects the replica with the least replication lag
3. Promotes selected replica to primary
4. Updates DNS endpoint to point to the new primary
5. Remaining replicas reconfigure to replicate from the new primary
6. ElastiCache launches a replacement node for the failed node (becomes a new replica)
7. Typical failover duration: 15-30 seconds (DNS propagation is the bottleneck)
8. Application connections using the primary endpoint automatically resolve to the new primary after DNS TTL expires

**Failover without Multi-AZ:** ElastiCache replaces the failed primary with a new empty node. Data is lost unless a snapshot exists. Multi-AZ is strongly recommended for production.

### Cluster Topology -- Cluster Mode Enabled

A multi-shard replication group where data is partitioned across 1-500 shards:

```
        +------------------------------------+
        |     Configuration Endpoint         |
        | (returns full cluster topology     |
        |  to cluster-aware clients)         |
        +--+-------------+-------------+-----+
           |             |             |
    +------v------+ +----v------+ +---v-------+
    |  Shard 1    | |  Shard 2  | |  Shard 3  |  ...up to 500
    |  Slots 0-   | |  Slots    | |  Slots    |     shards
    |  5460       | |  5461-    | |  10923-   |
    |             | |  10922    | |  16383    |
    +------+------+ +-----+----+ +-----+-----+
           |              |             |
    +------v------+ +-----v-----+ +----v------+
    | Primary     | | Primary   | | Primary   |
    | + Replicas  | | + Replicas| | + Replicas|
    | (0-5)       | | (0-5)     | | (0-5)     |
    +-------------+ +-----------+ +-----------+
```

**Hash slot assignment:**
- 16,384 hash slots total (slots 0-16383)
- Each key's slot = CRC16(key) mod 16384
- Hash tags override: CRC16 is computed on the substring between first `{` and first `}`. Example: `{user:1000}.profile` and `{user:1000}.sessions` both hash to the slot for `user:1000`.
- Slots are distributed across shards. Default distribution is roughly even.

**Online resharding:**
- Add a new shard: ElastiCache creates new nodes, then migrates a subset of slots from existing shards
- Remove a shard: ElastiCache migrates all slots from the target shard to other shards, then removes the nodes
- During migration, keys in the migrating slot are temporarily locked (MIGRATING/IMPORTING state). Clients may receive ASK or MOVED redirections.
- Cluster-aware clients handle redirections automatically. Non-cluster-aware clients will fail during migration.
- Resharding time depends on data volume, number of keys, and network throughput. Expect minutes to hours for large datasets.

**Online vertical scaling:**
- Scale up/down by changing the node type. ElastiCache performs a rolling replacement:
  1. Creates replacement nodes with the new type
  2. Syncs data to replacement nodes
  3. Promotes replacement nodes and retires old nodes
  4. DNS endpoints update automatically
- Minimal downtime per shard (~seconds during the switchover). The entire operation may take minutes to hours depending on cluster size.

### ElastiCache for Memcached Architecture

A flat cluster of independent cache nodes with no replication:

```
    +----------------------------------+
    |     Configuration Endpoint       |
    |  (auto-discovery of all nodes)   |
    +--+--------+--------+--------+---+
       |        |        |        |
    +--v--+  +--v--+  +--v--+  +--v--+
    |Node1|  |Node2|  |Node3|  |Node4|  ...up to 40 nodes
    +-----+  +-----+  +-----+  +-----+
```

**Slab allocator architecture:**
- Memcached pre-allocates memory into slab classes of increasing chunk sizes
- Slab growth factor (default 1.25) determines chunk size progression: 96B, 120B, 152B, 192B, ...
- Each item is stored in the smallest slab class that can hold it
- Slab calcification: If the workload changes (e.g., smaller items replace larger items), memory can become trapped in large slab classes. Use `slab_reassign` and `slab_automove` parameters to mitigate.
- No cross-node communication. Each node is an independent cache.
- Consistent hashing on the client side distributes keys across nodes

**Multi-threaded architecture:**
- Memcached uses multiple worker threads (default: number of vCPUs)
- One listener thread accepts connections, dispatches to workers
- Each worker thread has its own event loop (libevent)
- Thread contention can occur on the global lock for slab allocation and LRU operations
- For high-throughput workloads, Memcached can utilize all CPU cores on a node (unlike single-threaded Redis)

### ElastiCache Serverless Architecture

Serverless caching removes node management entirely:

**Under the hood:**
- AWS manages a fleet of cache nodes behind a single endpoint
- Data is automatically partitioned and replicated across multiple AZs
- Compute scales based on request rate (measured in ElastiCache Processing Units -- ECPUs)
- Memory scales based on data stored (measured in GB)
- No node type selection, parameter group tuning (limited), or manual scaling operations

**Request routing:**
- Single endpoint that behaves like a cluster mode enabled endpoint
- AWS proxy layer routes commands to the appropriate backend shard
- Supports both cluster-mode and non-cluster-mode client libraries (the proxy translates)

**Scaling behavior:**
- **Scale up:** Automatic within seconds to minutes when demand increases
- **Scale down:** Automatic when demand decreases. More conservative to avoid thrashing.
- **Maximum:** 5 TB data, 30,000 ECPUs/second sustained
- **Minimum:** Billed for at least 1 GB of data storage when a cache exists

**Limitations:**
- Cannot customize most parameter group settings
- Cannot access individual node metrics (only aggregate cache metrics)
- Cannot use data tiering
- Higher per-unit cost than provisioned at steady-state high utilization

### MemoryDB Architecture

MemoryDB combines the Redis/Valkey in-memory data model with a durable Multi-AZ transaction log:

```
    +------------------+     +------------------+
    | Application      |     | Application      |
    +--------+---------+     +--------+---------+
             |                        |
    +--------v------------------------v--------+
    |         MemoryDB Cluster Endpoint        |
    +-----+-------------+-------------+--------+
          |             |             |
    +-----v-----+ +----v------+ +---v-------+
    |  Shard 1  | |  Shard 2  | |  Shard 3  |
    |  Primary  | |  Primary  | |  Primary  |
    |  +Replicas| |  +Replicas| |  +Replicas|
    +-----+-----+ +-----+----+ +-----+-----+
          |              |             |
    +-----v--------------v-------------v-----+
    |       Multi-AZ Transaction Log         |
    |  (durable, replicated across AZs)      |
    +-----------------------------------------+
```

**Write path:**
1. Client sends a write command to the primary node
2. Primary applies the command to its in-memory data structures
3. Primary writes the command to the Multi-AZ transaction log
4. Transaction log replicates the entry across multiple AZs
5. Once the transaction log confirms durable storage, the primary acknowledges the write to the client
6. Primary asynchronously replicates the write to read replicas (same as ElastiCache)

**Read path:**
- **Primary reads:** Strongly consistent. Always sees the latest committed data.
- **Replica reads:** Eventually consistent. Replica may be slightly behind the primary.

**Recovery process:**
- On node failure, MemoryDB restores data from the transaction log + latest snapshot
- Recovery time depends on the amount of data to replay from the transaction log since the last snapshot
- During recovery, the shard is unavailable for writes (replicas may serve stale reads)

**Durability guarantees:**
- Every acknowledged write is durably stored in the transaction log across multiple AZs
- Data survives: node failures, process crashes, full cluster restart, AZ failure
- Data does NOT survive: intentional cluster deletion, region-wide failure (no cross-region replication for MemoryDB)

**Performance characteristics compared to ElastiCache:**
- Read latency: Equivalent to ElastiCache (sub-millisecond to low single-digit ms)
- Write latency: Slightly higher than ElastiCache (~5-10ms vs. sub-ms) due to transaction log commit
- Throughput: Comparable to ElastiCache for reads. Write throughput may be slightly lower due to log commit serialization.

### Global Datastore Architecture

Cross-region replication for ElastiCache Redis/Valkey cluster mode enabled:

```
    Region: us-east-1 (Primary)          Region: eu-west-1 (Secondary)
    +---------------------------+        +---------------------------+
    |  Primary Replication      |        |  Secondary Replication    |
    |  Group                    |  --->  |  Group (read-only)        |
    |                           |  async |                           |
    |  Shard 1: Primary+Replica |        |  Shard 1: Primary+Replica |
    |  Shard 2: Primary+Replica |        |  Shard 2: Primary+Replica |
    |  Shard 3: Primary+Replica |        |  Shard 3: Primary+Replica |
    +---------------------------+        +---------------------------+
                                                     |
                                         Region: ap-southeast-1
                                         (Optional 2nd Secondary)
                                         +---------------------------+
                                         |  Secondary Replication    |
                                         |  Group (read-only)        |
                                         +---------------------------+
```

**Replication mechanics:**
- Asynchronous cross-region replication from primary region to secondary regions
- Each shard in the primary replicates independently to the corresponding shard in secondary regions
- Uses a dedicated replication channel separate from intra-cluster replication
- Typical replication lag: sub-second to low seconds under normal conditions
- Lag increases with: high write throughput, large value sizes, cross-region network issues

**Failover (manual):**
1. Operator triggers `failover-global-replication-group` targeting a secondary region
2. The secondary region is promoted to primary (becomes writable)
3. The old primary region is demoted to secondary (becomes read-only)
4. Applications must be updated to write to the new primary region endpoint
5. Failover duration: minutes (includes DNS propagation, topology reconfiguration)

**Limitations:**
- Manual failover only (no automatic cross-region failover)
- Requires cluster mode enabled
- Supported on Redis 6.2+ and Valkey
- Maximum 2 secondary regions
- Some commands are blocked on secondary regions (e.g., write commands, FLUSHALL)
- Active-active (multi-writer) is not supported. Only one region is writable at a time.

### Data Tiering Architecture (r7gd Nodes)

Data tiering extends effective memory by using local NVMe SSD for less-frequently-accessed data:

```
    +-------------------------------------------+
    |              Redis/Valkey Engine           |
    |                                           |
    |  +------------------+  +----------------+ |
    |  |   DRAM (Hot)     |  |  NVMe SSD      | |
    |  |   - Frequently   |  |  (Warm/Cold)   | |
    |  |     accessed keys|  |  - Infrequently | |
    |  |   - All key      |  |    accessed     | |
    |  |     metadata     |  |    values       | |
    |  +------------------+  +----------------+ |
    +-------------------------------------------+
```

**Tiering mechanics:**
- All key metadata (key names, expiry, type info) always stays in DRAM
- Values are tiered to SSD based on access frequency (LRU tracking)
- When a tiered-out value is accessed, it is promoted back to DRAM
- Background process continuously evaluates access patterns and moves cold values to SSD
- Access latency for SSD-tiered values is higher (~100-250 microseconds) compared to DRAM (~1-10 microseconds), but still fast

**Configuration:**
- Enabled automatically when using r7gd node types
- No application code changes required
- Works with cluster mode enabled or disabled
- Supported for Redis 7.0+ and Valkey engines

**Capacity planning:**
- DRAM holds hot data + all key metadata (~70 bytes per key overhead)
- SSD provides additional capacity for cold values
- Example: cache.r7gd.4xlarge has ~52 GB DRAM + ~190 GB SSD
- Monitor `DatabaseMemoryUsagePercentage` for DRAM utilization
- Monitor data tiering metrics to understand the ratio of hot vs. cold data

### Network Architecture

**VPC deployment:**
- ElastiCache and MemoryDB clusters must be deployed within a VPC
- Subnet groups define which subnets (and therefore which AZs) nodes can be placed in
- For Multi-AZ, the subnet group must span at least 2 AZs
- Each node gets a private IP address within its subnet. No public IP addressing.
- ENIs (Elastic Network Interfaces) are attached to cache nodes. Security groups are applied to these ENIs.

**Endpoint resolution:**
- ElastiCache provides DNS endpoints (CNAMEs) that resolve to node IP addresses
- Primary endpoint: resolves to the current primary node IP
- Reader endpoint: resolves round-robin across all replica IPs
- Configuration endpoint (cluster mode): resolves to a node that can return the full slot map
- DNS TTL is typically 5-15 seconds. Applications should respect DNS TTL and not cache DNS indefinitely.

**Cross-AZ data transfer:**
- Replication traffic between primary and replicas in different AZs incurs cross-AZ data transfer costs
- Client-to-node traffic across AZs also incurs cross-AZ costs
- For cost optimization, place the primary in the same AZ as the majority of write traffic
- Use reader endpoint for reads, which may route to a same-AZ replica

**VPC peering and Transit Gateway:**
- Clusters can be accessed from peered VPCs or via Transit Gateway
- Ensure route tables, security groups, and NACLs allow traffic
- Cross-region VPC peering can access clusters but with added latency

### Connection Architecture

**Redis/Valkey connection model:**
- Single-threaded event loop handles all client connections via multiplexed I/O (epoll/kqueue)
- Each connection is a TCP socket. Default max connections: 65,000 per node.
- Connection overhead: ~1 KB per idle connection (kernel TCP buffers)
- Active connections with large buffers can consume more (client-output-buffer-limit)
- Connection establishment: TCP handshake + optional TLS handshake + optional AUTH + optional SELECT (database)

**Valkey 8.0 multi-threaded I/O:**
- Read and write I/O operations are offloaded to I/O threads
- Command execution remains single-threaded (atomicity preserved)
- Significant throughput improvement for I/O-bound workloads
- Automatically enabled in ElastiCache/MemoryDB for Valkey 8.0

**Client output buffer limits (Redis/Valkey):**
- `client-output-buffer-limit normal 0 0 0` -- Normal clients: no limit (dangerous if client reads slowly)
- `client-output-buffer-limit replica 256mb 64mb 60` -- Replica clients: hard limit 256 MB, soft limit 64 MB for 60 seconds
- `client-output-buffer-limit pubsub 32mb 8mb 60` -- Pub/Sub clients: hard limit 32 MB, soft limit 8 MB for 60 seconds
- If a client exceeds the buffer limit, the connection is closed. This can cause cascading failures if many clients reconnect simultaneously (connection storm).

**Connection pooling best practices:**
- Use a connection pool in your application (e.g., redis-py's ConnectionPool, Jedis pool, ioredis with lazyConnect)
- Pool size per application instance: 5-20 connections for most workloads
- Minimum pool size: 1-2 (avoid cold start latency)
- Maximum pool size: Consider total connections across all app instances. 100 app instances x 20 connections = 2,000 connections per node.
- Connection validation: Use `PING` on checkout to detect stale connections
- Idle timeout: Close connections idle for > 5 minutes to free server resources

### Persistence Architecture (ElastiCache Redis/Valkey)

**RDB snapshots (BGSAVE):**
1. Redis/Valkey forks the process using copy-on-write (COW)
2. The child process writes the dataset to a temporary RDB file
3. Once complete, the temporary file replaces the previous RDB file
4. Memory impact: During BGSAVE, modified pages are duplicated (COW). Worst case: 2x memory usage if all pages are modified during the snapshot.
5. ElastiCache reserves 25% of node memory for this overhead (`reserved-memory-percent` parameter, default 25%)

**No AOF in ElastiCache:** ElastiCache does not expose AOF (Append Only File) persistence. The service uses its own internal replication and snapshot mechanisms. MemoryDB uses its transaction log instead of AOF.

**Backup storage:**
- Snapshots are stored in S3 (managed by AWS, not visible in your S3 console)
- Snapshot size is approximately equal to the used memory of the dataset
- Snapshot creation for cluster mode enabled takes a snapshot of each shard in parallel
- Cross-region snapshot copy is supported for disaster recovery

### Security Architecture

**Encryption in transit (TLS):**
- TLS 1.2/1.3 between clients and nodes, and between nodes (replication)
- Must be enabled at cluster creation (cannot be enabled later without creating a new cluster)
- Certificate: AWS provides managed certificates. Clients must trust the Amazon Root CA.
- Performance impact: ~25% CPU overhead for TLS termination. More significant on smaller node types.
- Connection string changes: Use `rediss://` scheme (note the double 's') instead of `redis://`

**Encryption at rest:**
- Uses AES-256 encryption
- Key management: AWS-managed key (default) or customer-managed KMS key (CMK)
- Encrypts: data on disk (snapshots, swap files), replication data in transit to replicas (in addition to TLS)
- No performance impact (hardware-accelerated AES)

**IAM authentication (Redis 7.0+, Valkey):**
- Clients authenticate using a short-lived IAM auth token instead of a static password
- The token is generated by calling the `ElastiCacheServerlessConnectUser` or `ElastiCacheConnectUser` IAM actions
- Token validity: 15 minutes (auto-renewed by supported clients)
- Integrates with IAM roles, policies, and identity federation
- Eliminates the need to manage and rotate static AUTH tokens

**Redis/Valkey ACLs:**
- Define users with specific permissions: allowed/denied commands, allowed/denied key patterns, allowed/denied channels
- Example ACL: `user appuser on >password ~app:* +@read +@write -@admin`
- Default user: `default` with full access (similar to Redis AUTH)
- ACL changes can be applied dynamically without cluster restart
- ElastiCache manages ACLs through the `create-user` and `create-user-group` APIs

**MemoryDB ACLs:**
- Mandatory -- every MemoryDB cluster must have an ACL
- Defined through `aws memorydb create-user` and `aws memorydb create-acl`
- Open access ACL (`open-access`) allows all commands on all keys (not recommended for production)
- ACL syntax is identical to Redis ACL syntax
