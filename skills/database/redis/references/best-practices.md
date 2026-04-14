# Redis Best Practices Reference

## redis.conf Tuning

### Memory Configuration

```
# Maximum memory limit -- always set in production
maxmemory 8gb

# Eviction policy -- choose based on workload
maxmemory-policy allkeys-lfu          # best for general caching
# maxmemory-policy volatile-lfu       # if mixing persistent + cache keys
# maxmemory-policy noeviction         # if data loss is unacceptable

# LRU/LFU sampling accuracy (higher = more accurate, more CPU)
maxmemory-samples 10

# Active defragmentation (recommended for long-running instances)
activedefrag yes
active-defrag-ignore-bytes 100mb
active-defrag-threshold-lower 10
active-defrag-threshold-upper 100
active-defrag-cycle-min 1
active-defrag-cycle-max 25
```

**Memory planning formula:**
```
Required memory = dataset_size * 1.5 (fragmentation headroom)
                + fork_overhead (dataset_size * write_rate_during_save)
                + replication_backlog (256mb default)
                + client_output_buffers (depends on client count)
                + lua_scripts_cache
```

**Rule of thumb:** Provision 2x the expected dataset size to account for fragmentation, fork overhead, and growth.

### Network and Connection Configuration

```
# Bind to specific interfaces (never 0.0.0.0 in production without TLS)
bind 10.0.0.1 127.0.0.1

# TCP backlog (increase for high connection rates)
tcp-backlog 511

# Client idle timeout (0 = disabled; set > 0 for connection hygiene)
timeout 300

# TCP keepalive (detect dead connections)
tcp-keepalive 300

# Maximum simultaneous clients
maxclients 10000

# I/O threads (Redis 6.0+; set to cores/2 for high-throughput)
# io-threads 4
# io-threads-do-reads yes
```

### Persistence Configuration

**Recommended: Hybrid AOF+RDB (default in 7.0+):**
```
appendonly yes
appendfsync everysec
aof-use-rdb-preamble yes
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Also keep RDB snapshots as backup
save 3600 1
save 300 100
save 60 10000

# RDB checksum (CPU cost is minimal)
rdbchecksum yes
rdbcompression yes

# Filename and directory
dbfilename dump.rdb
appenddirname appendonlydir
dir /var/lib/redis
```

**For pure caching (no persistence needed):**
```
appendonly no
save ""
```

**For maximum durability:**
```
appendonly yes
appendfsync always        # WARNING: significant performance impact
aof-use-rdb-preamble yes
```

### Performance Tuning

```
# Event loop frequency (higher = faster expiry/eviction, more CPU)
hz 10                     # default; increase to 100 for latency-sensitive workloads
dynamic-hz yes            # auto-adjust based on client activity

# Slow log (microseconds; 10000 = 10ms)
slowlog-log-slower-than 10000
slowlog-max-len 256

# Latency monitoring (milliseconds)
latency-monitor-threshold 10

# Disable Transparent Huge Pages (via OS, not redis.conf)
# echo never > /sys/kernel/mm/transparent_hugepages/enabled

# Lazy freeing (async deletion -- reduces blocking)
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
replica-lazy-flush yes
lazyfree-lazy-user-del yes      # makes DEL behave like UNLINK
lazyfree-lazy-user-flush yes    # makes FLUSHDB/FLUSHALL async
```

### Replication Configuration

```
# On replica:
replicaof <master-ip> <master-port>
masterauth <password>
replica-read-only yes

# Diskless replication (faster for slow-disk setups)
repl-diskless-sync yes
repl-diskless-sync-delay 5
repl-diskless-sync-period 0
repl-diskless-load on-empty-db    # disabled | on-empty-db | swapdb

# Backlog size (larger = more tolerance for disconnections)
repl-backlog-size 256mb
repl-backlog-ttl 3600

# Write quorum (reject writes if too few replicas)
min-replicas-to-write 1
min-replicas-max-lag 10
```

## Persistence Strategy Selection

### Decision Matrix

| Scenario | Recommended Strategy | Rationale |
|---|---|---|
| **Pure cache** (data can be regenerated) | No persistence (`save ""`, `appendonly no`) | Maximum performance, no fork overhead |
| **Cache with warm restart** | RDB only (`save 3600 1 300 100 60 10000`) | Fast restart, some data loss acceptable |
| **Session store** | AOF everysec + RDB | Minimal data loss (~1s), reasonable performance |
| **Primary database** | Hybrid AOF+RDB (default) | Fast restart + durability |
| **Financial/critical data** | AOF always + RDB | Maximum durability, accept performance cost |
| **Message queue (Streams)** | Hybrid AOF+RDB | Durability needed; AOF everysec acceptable |

### Fork Overhead Mitigation

For large datasets (>10GB) where fork causes latency spikes:

1. **Schedule saves during low traffic:** Remove frequent save triggers, keep only hourly
2. **Use replicas for persistence:** Disable persistence on master, enable on replica only
3. **Monitor fork time:** `INFO persistence` -> `latest_fork_usec` (>1 second is concerning)
4. **Overcommit memory:** `vm.overcommit_memory = 1` prevents fork failure when memory is tight
5. **Reduce dataset size:** Use TTLs, compress values, optimize data structures

```bash
# Linux: allow fork to succeed even if memory is "overcommitted"
echo 1 > /proc/sys/vm/overcommit_memory

# Add to /etc/sysctl.conf for persistence
vm.overcommit_memory = 1
```

## Cluster Sizing

### Slot Distribution Rules

- **Minimum:** 3 master nodes (for quorum-based failure detection)
- **Recommended:** 3 masters + 3 replicas (1 replica per master)
- **Production:** 6+ masters for large datasets, 2 replicas per master for HA

**Sizing per node:**
| Factor | Guideline |
|---|---|
| Memory per node | 25-75% of available RAM (leave room for fork, OS, buffers) |
| Keys per node | Keep under 100M keys per node for operational manageability |
| Network | Dedicated NICs for data port and cluster bus port in high-throughput clusters |
| CPU | 1 core per Redis process + cores for I/O threads if enabled |

**Resharding bandwidth:**
- Slot migration moves keys one at a time (MIGRATE command)
- For large slots (>1M keys): migration takes minutes
- Use `--cluster-pipeline` during reshard for bulk migration
- Plan resharding during maintenance windows for production

### When to Scale Out vs. Scale Up

**Scale up (bigger nodes):**
- Dataset fits in available RAM with headroom
- Throughput is below single-instance capacity (~100-300K ops/sec)
- Simplicity preferred over horizontal scaling

**Scale out (more nodes):**
- Dataset exceeds single-node memory (accounting for fork overhead)
- Need throughput beyond single instance
- Write scaling needed (writes go to masters only)
- Fault domain isolation (spread across availability zones)

## Sentinel Deployment

### Topology Requirements

- **Minimum 3 sentinels** for quorum (Byzantine fault tolerance)
- **Odd number** to prevent split votes (3, 5, 7)
- **Distribute across failure domains** (different hosts, racks, or AZs)
- **Never co-locate all sentinels with Redis instances** (correlated failure)

**Recommended layouts:**
```
Layout A (small):
  Host 1: Redis Master + Sentinel 1
  Host 2: Redis Replica + Sentinel 2
  Host 3: Sentinel 3 (standalone)

Layout B (production):
  Host 1: Redis Master
  Host 2: Redis Replica 1
  Host 3: Redis Replica 2
  Host 4: Sentinel 1
  Host 5: Sentinel 2
  Host 6: Sentinel 3
```

### Sentinel Configuration

```
# sentinel.conf
port 26379
sentinel monitor mymaster 10.0.0.1 6379 2    # quorum = 2 (majority of 3)

# How long before declaring SDOWN (subjective down)
sentinel down-after-milliseconds mymaster 5000    # 5 seconds

# Failover timeout (total time for failover process)
sentinel failover-timeout mymaster 60000          # 60 seconds

# How many replicas sync simultaneously during failover (lower = less impact)
sentinel parallel-syncs mymaster 1

# Authentication
sentinel auth-pass mymaster <master-password>
sentinel auth-user mymaster <acl-username>          # Redis 6.2+

# Notification script (called on failover)
sentinel notification-script mymaster /opt/redis/notify.sh

# Reconfiguration script (called when topology changes)
sentinel client-reconfig-script mymaster /opt/redis/reconfig.sh

# Deny unsafe commands on sentinel
sentinel deny-scripts-reconfig yes
```

### Sentinel vs. Cluster

| Factor | Sentinel | Cluster |
|---|---|---|
| **Sharding** | No (single dataset) | Yes (16,384 hash slots) |
| **Max data size** | Single node RAM | Sum of all master nodes' RAM |
| **Write scaling** | No (single master) | Yes (writes distributed across masters) |
| **Client complexity** | Moderate (sentinel-aware clients) | Higher (cluster-aware clients with redirection) |
| **Multi-key operations** | Full support | Limited to same hash slot |
| **Operational complexity** | Lower | Higher |
| **Best for** | HA for <100GB datasets | Scaling beyond single node capacity |

## Security Hardening

### Authentication and Authorization

```bash
# Require password (legacy, pre-ACL)
requirepass <strong-random-password>

# ACL-based (Redis 6.0+, recommended)
# Default user with full access:
ACL SETUSER default on >strongpassword ~* &* +@all

# Read-only application user:
ACL SETUSER app-reader on >readerpass ~app:* +@read +@connection +ping +info

# Write application user:
ACL SETUSER app-writer on >writerpass ~app:* +@write +@read +@connection +ping

# Admin user (restricted dangerous commands):
ACL SETUSER admin on >adminpass ~* &* +@all -@dangerous

# Persist ACL configuration:
ACL SAVE    # writes to ACL file
# Or define in redis.conf:
# aclfile /etc/redis/users.acl
```

### Network Security

```
# Bind to specific interfaces only
bind 10.0.0.1 127.0.0.1 ::1

# Disable protected mode only if you have proper firewall rules AND authentication
protected-mode yes

# TLS encryption (Redis 6.0+)
tls-port 6380
port 0                                    # disable non-TLS port
tls-cert-file /etc/redis/tls/redis.crt
tls-key-file /etc/redis/tls/redis.key
tls-ca-cert-file /etc/redis/tls/ca.crt
tls-auth-clients optional                # or 'yes' for mutual TLS
tls-replication yes                      # encrypt replication traffic
tls-cluster yes                          # encrypt cluster bus traffic

# Rename dangerous commands (legacy approach; prefer ACLs)
# rename-command FLUSHALL ""
# rename-command FLUSHDB ""
# rename-command CONFIG ""
# rename-command DEBUG ""
```

### OS-Level Hardening

```bash
# Run Redis as dedicated non-root user
useradd -r -s /bin/false redis
chown -R redis:redis /var/lib/redis /var/log/redis /etc/redis

# Limit open files
echo "redis soft nofile 65535" >> /etc/security/limits.conf
echo "redis hard nofile 65535" >> /etc/security/limits.conf

# Disable THP
echo never > /sys/kernel/mm/transparent_hugepages/enabled

# Set overcommit
echo 1 > /proc/sys/vm/overcommit_memory

# Network tuning
echo 511 > /proc/sys/net/core/somaxconn
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
```

## Key Naming Conventions

### Recommended Patterns

```
# Use colons as namespace separators
user:1000:profile
user:1000:sessions
order:2024-01:invoice:5678
cache:api:v2:users:list

# Use hash tags for cluster co-location
{user:1000}:profile
{user:1000}:sessions
{user:1000}:preferences

# Use prefixes for environment/purpose separation
prod:cache:user:1000
staging:cache:user:1000
```

### Naming Anti-Patterns

| Anti-Pattern | Problem | Better |
|---|---|---|
| Very long key names (>100 bytes) | Wasted memory (millions of keys = MBs wasted) | Use abbreviations: `u:1000:p` |
| Spaces in key names | Quoting issues in redis-cli, scripts | Use colons or dots |
| Very short/cryptic names | Unmaintainable | Balance readability and memory |
| Sequential numeric keys only | No way to identify purpose | Include type prefix |
| Embedding large data in key name | Key names stored separately from values | Put data in the value |

### Key Cardinality Planning

| Key Count Range | Considerations |
|---|---|
| < 1 million | Single instance handles easily |
| 1-50 million | Monitor memory, consider per-key overhead (~70-100 bytes each) |
| 50-200 million | Plan for significant per-key overhead; cluster may be needed |
| > 200 million | Cluster strongly recommended; optimize key size |

**Per-key overhead (approximate):**
- dictEntry: 24 bytes (key pointer + value pointer + next pointer)
- Key SDS: 9 bytes header + key length + 1 null terminator
- robj: 16 bytes (type + encoding + refcount + ptr)
- Expires dict entry (if TTL set): additional 24 bytes + 8 bytes for timestamp

## TTL Strategies

### Patterns

**Sliding window TTL (cache refresh):**
```bash
# Reset TTL on every access
GET mykey
EXPIRE mykey 3600    # reset to 1 hour on each access
# Or use SET with keepttl: SET mykey newvalue KEEPTTL
```

**Absolute TTL (session expiry):**
```bash
# Set exact expiration time
SET session:abc123 "{...}" EXAT 1735689600    # Unix timestamp
```

**Jittered TTL (prevent thundering herd):**
```python
# Python: add random jitter to base TTL
import random
base_ttl = 3600
jitter = random.randint(0, 600)  # 0-10 minutes jitter
r.setex(f'cache:{key}', base_ttl + jitter, value)
```

**Hierarchical TTL (parent invalidates children):**
```bash
# Set shorter TTL on derived keys
SET user:1000:profile "{...}" EX 3600
SET cache:user:1000:dashboard "{...}" EX 300
# Dashboard cache expires sooner; profile is source of truth
```

### TTL Anti-Patterns

- **Millions of keys expiring at the same second:** Causes CPU spike during active expiry. Add jitter.
- **Very short TTLs (< 1 second) on many keys:** Use PEXPIRE for sub-second, but question whether Redis is the right tool.
- **No TTL on cache keys:** Memory grows unbounded until eviction kicks in. Always set TTLs on cache data.
- **TTL on primary data:** If the key is the only copy, TTL risks silent data loss. Use noeviction policy for primary data.

## Pipeline Usage

### When to Pipeline

| Scenario | Pipeline? | Rationale |
|---|---|---|
| Batch writes (bulk load) | Yes | 10-100x throughput improvement |
| Multiple independent reads | Yes | Reduce round trips |
| Dependent operations (read then write) | No (or MULTI) | Need intermediate results |
| Mixed reads/writes (idempotent) | Yes | Safe if order doesn't matter |
| Cross-slot operations (cluster) | Per-slot pipelines | Group commands by hash slot |

### Pipeline Sizing

```python
# Optimal pipeline size: 100-1000 commands per batch
# Too small: excessive round trips
# Too large: large response buffers, blocking other clients

PIPELINE_SIZE = 500

pipe = r.pipeline(transaction=False)
for i, item in enumerate(items):
    pipe.set(f'item:{item.id}', item.value)
    if (i + 1) % PIPELINE_SIZE == 0:
        pipe.execute()
pipe.execute()  # remaining items
```

### Pipeline with Error Handling

```python
pipe = r.pipeline(transaction=False)
pipe.set('key1', 'val1')
pipe.incr('key2')         # might fail if key2 is not a number
pipe.get('key3')

results = pipe.execute(raise_on_error=False)
for i, result in enumerate(results):
    if isinstance(result, Exception):
        logger.error(f"Command {i} failed: {result}")
```

## Connection Pool Sizing

### Formula

```
pool_size = max_concurrent_commands + headroom

Where:
  max_concurrent_commands = application_threads * commands_per_request
  headroom = 10-20% for spikes
```

**Example:**
- Web app with 50 worker threads
- Each request makes 3-5 Redis commands (pipelined into 1-2 round trips)
- Pool size: 50 * 1 (pipeline) + 10 (headroom) = 60 connections

### Configuration by Client Library

```python
# Python redis-py
import redis
pool = redis.ConnectionPool(
    host='redis-host',
    port=6379,
    max_connections=100,
    socket_timeout=5,
    socket_connect_timeout=2,
    retry_on_timeout=True,
    health_check_interval=30
)
r = redis.Redis(connection_pool=pool)
```

```java
// Java Jedis
JedisPoolConfig config = new JedisPoolConfig();
config.setMaxTotal(100);
config.setMaxIdle(50);
config.setMinIdle(10);
config.setTestOnBorrow(true);
config.setTestWhileIdle(true);
config.setTimeBetweenEvictionRunsMillis(30000);
JedisPool pool = new JedisPool(config, "redis-host", 6379, 5000, "password");
```

```go
// Go go-redis
rdb := redis.NewClient(&redis.Options{
    Addr:         "redis-host:6379",
    Password:     "password",
    PoolSize:     100,
    MinIdleConns: 10,
    DialTimeout:  5 * time.Second,
    ReadTimeout:  3 * time.Second,
    WriteTimeout: 3 * time.Second,
    PoolTimeout:  4 * time.Second,
})
```

### Connection Pool Anti-Patterns

- **Pool too small:** Threads wait for connections, adding latency
- **Pool too large:** Thousands of connections waste Redis memory and OS file descriptors
- **No health checks:** Stale connections cause errors; enable periodic pings
- **No timeouts:** A stuck connection blocks a thread forever; always set socket_timeout
- **One pool per request:** Creating new pools is expensive; share a single pool

## Monitoring Setup

### Key Metrics to Monitor

**Server health:**
| Metric | Source | Alert Threshold |
|---|---|---|
| `uptime_in_seconds` | INFO server | < 300 (unexpected restart) |
| `connected_clients` | INFO clients | > 80% of maxclients |
| `blocked_clients` | INFO clients | > 0 for extended periods |
| `used_memory` / `maxmemory` | INFO memory | > 85% |
| `mem_fragmentation_ratio` | INFO memory | > 1.5 or < 1.0 |
| `instantaneous_ops_per_sec` | INFO stats | Sudden drops |
| `rejected_connections` | INFO stats | > 0 |
| `evicted_keys` | INFO stats | Unexpected non-zero (caching: normal; primary data: critical) |
| `keyspace_misses` / (`keyspace_hits` + `keyspace_misses`) | INFO stats | > 50% miss rate for caching |

**Persistence:**
| Metric | Source | Alert Threshold |
|---|---|---|
| `rdb_last_bgsave_status` | INFO persistence | Not "ok" |
| `aof_last_bgrewrite_status` | INFO persistence | Not "ok" |
| `rdb_last_bgsave_time_sec` | INFO persistence | Increasing trend |
| `aof_last_write_status` | INFO persistence | Not "ok" |
| `latest_fork_usec` | INFO persistence | > 1,000,000 (1 second) |

**Replication:**
| Metric | Source | Alert Threshold |
|---|---|---|
| `connected_slaves` | INFO replication | Less than expected |
| `master_link_status` | INFO replication (on replica) | Not "up" |
| `master_last_io_seconds_ago` | INFO replication (on replica) | > 10 |
| `master_repl_offset` - `slave_repl_offset` | INFO replication | Lag > 1MB |

### Prometheus/Grafana Integration

**Using redis_exporter:**
```bash
# Install redis_exporter
wget https://github.com/oliver006/redis_exporter/releases/latest/download/redis_exporter-linux-amd64
chmod +x redis_exporter-linux-amd64

# Run (connects to Redis and exposes metrics on :9121)
./redis_exporter --redis.addr redis://localhost:6379 --redis.password "$REDIS_PASSWORD"

# For cluster:
./redis_exporter --redis.addr redis://node1:6379,redis://node2:6379,redis://node3:6379
```

**Prometheus scrape config:**
```yaml
scrape_configs:
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
    scrape_interval: 15s
```

**Essential Grafana dashboard panels:**
- Memory usage and fragmentation ratio (line chart)
- Operations per second by command type (stacked area)
- Connected clients vs maxclients (gauge)
- Hit rate (line chart, computed from keyspace_hits/misses)
- Replication lag bytes (line chart per replica)
- Slow log entries per minute (bar chart)
- Evicted keys per second (line chart)
- Network I/O bytes in/out (line chart)

### Health Check Script

```bash
#!/bin/bash
# redis-health-check.sh -- quick health assessment

REDIS_CLI="redis-cli -h ${REDIS_HOST:-localhost} -p ${REDIS_PORT:-6379}"
if [ -n "$REDIS_PASSWORD" ]; then
    REDIS_CLI="$REDIS_CLI -a $REDIS_PASSWORD --no-auth-warning"
fi

echo "=== Redis Health Check ==="

# Ping
PONG=$($REDIS_CLI PING 2>/dev/null)
if [ "$PONG" != "PONG" ]; then
    echo "CRITICAL: Redis is not responding"
    exit 2
fi
echo "OK: Redis is responding"

# Memory
USED=$($REDIS_CLI INFO memory | grep "used_memory:" | cut -d: -f2 | tr -d '\r')
MAX=$($REDIS_CLI CONFIG GET maxmemory | tail -1 | tr -d '\r')
FRAG=$($REDIS_CLI INFO memory | grep "mem_fragmentation_ratio:" | cut -d: -f2 | tr -d '\r')
echo "Memory: used=$(echo "scale=2; $USED/1073741824" | bc)GB, max=$(echo "scale=2; $MAX/1073741824" | bc)GB, frag=$FRAG"

# Clients
CLIENTS=$($REDIS_CLI INFO clients | grep "connected_clients:" | cut -d: -f2 | tr -d '\r')
MAXCLI=$($REDIS_CLI CONFIG GET maxclients | tail -1 | tr -d '\r')
echo "Clients: $CLIENTS / $MAXCLI"

# Replication
ROLE=$($REDIS_CLI INFO replication | grep "role:" | cut -d: -f2 | tr -d '\r')
echo "Role: $ROLE"
if [ "$ROLE" = "master" ]; then
    SLAVES=$($REDIS_CLI INFO replication | grep "connected_slaves:" | cut -d: -f2 | tr -d '\r')
    echo "Connected replicas: $SLAVES"
fi

# Persistence
RDB_STATUS=$($REDIS_CLI INFO persistence | grep "rdb_last_bgsave_status:" | cut -d: -f2 | tr -d '\r')
AOF_STATUS=$($REDIS_CLI INFO persistence | grep "aof_last_bgrewrite_status:" | cut -d: -f2 | tr -d '\r')
echo "RDB status: $RDB_STATUS"
echo "AOF rewrite status: $AOF_STATUS"

# Slow log
SLOW_COUNT=$($REDIS_CLI SLOWLOG LEN | tr -d '\r')
echo "Slow log entries: $SLOW_COUNT"

echo "=== End Health Check ==="
```

## Troubleshooting Playbooks

### OOM (Out of Memory)

**Symptoms:** `OOM command not allowed when used memory > 'maxmemory'` errors, Redis killed by OS OOM-killer.

**Immediate actions:**
```bash
# Check memory usage
redis-cli INFO memory

# Find big keys consuming most memory
redis-cli --bigkeys

# Check eviction policy
redis-cli CONFIG GET maxmemory-policy

# Force memory reclaim
redis-cli MEMORY PURGE

# Emergency: increase maxmemory temporarily
redis-cli CONFIG SET maxmemory 12gb
```

**Root cause analysis:**
1. Check `evicted_keys` -- if 0 and policy is noeviction, expected behavior
2. Check `mem_fragmentation_ratio` -- if > 1.5, fragmentation is the issue, not data volume
3. Check for big keys: `redis-cli --bigkeys --memkeys`
4. Check for missing TTLs: `redis-cli --scan --pattern '*' | head -100 | xargs -I{} redis-cli TTL {}`
5. Check client output buffers: `redis-cli CLIENT LIST` (look at `omem` column)

### Replication Lag

**Symptoms:** Stale reads on replicas, `master_last_io_seconds_ago` increasing, replication offset diverging.

**Diagnostic:**
```bash
# On master: check replication info
redis-cli INFO replication
# Look for: slave0:ip=...,offset=<offset>,lag=<lag_seconds>

# On replica: check link status
redis-cli INFO replication
# Look for: master_link_status, master_last_io_seconds_ago, master_sync_in_progress

# Check slow log on master (slow commands block replication stream)
redis-cli SLOWLOG GET 10

# Check if AOF/RDB save is blocking
redis-cli INFO persistence
```

**Remediation:**
1. If replica is doing full sync repeatedly: increase `repl-backlog-size`
2. If master is slow: check for big keys, slow Lua scripts, or KEYS commands
3. If network is the bottleneck: check bandwidth between master and replica
4. If replica disk is slow: enable `repl-diskless-load on-empty-db`

### Cluster Split-Brain

**Symptoms:** Multiple nodes claim to be master for the same slots, data inconsistency.

**Diagnostic:**
```bash
# Check cluster state
redis-cli -c CLUSTER INFO
# cluster_state:ok should be "ok"; "fail" means issues

# Check all node states
redis-cli -c CLUSTER NODES
# Look for conflicting slot assignments

# Check for partition
redis-cli --cluster check <any-node>:6379
```

**Remediation:**
1. Identify which node has the most up-to-date data (highest replication offset)
2. Use `CLUSTER FAILOVER TAKEOVER` on the authoritative node if needed
3. `CLUSTER RESET SOFT` on nodes with stale data, then re-add them
4. Fix the network partition that caused the split

**Prevention:**
- Use `cluster-node-timeout 15000` (15s) -- not too short (false positives) or too long (slow failover)
- Deploy replicas across availability zones
- Use `cluster-require-full-coverage yes` to stop serving if not all slots are covered

### Hot Keys

**Symptoms:** Uneven CPU usage across cluster nodes, single node at capacity while others are idle.

**Diagnostic:**
```bash
# Identify hot keys (requires LFU policy)
redis-cli --hotkeys

# Monitor commands in real-time (caution: performance impact)
redis-cli MONITOR | head -1000    # sample briefly, then Ctrl+C

# Check per-key access frequency
redis-cli OBJECT FREQ key_name
```

**Remediation:**
1. **Client-side caching** (Redis 6.0+): Cache hot keys in application memory
2. **Read replicas:** Route reads to replicas (if reads dominate)
3. **Key sharding:** Split `counter` into `counter:{0}` through `counter:{N}`, sum on read
4. **Local caching with invalidation:** Use RESP3 client tracking for cache invalidation

### Connection Storms

**Symptoms:** `connected_clients` spikes, `rejected_connections` increasing, latency spike.

**Diagnostic:**
```bash
# Check client count
redis-cli INFO clients

# List all clients with details
redis-cli CLIENT LIST

# Check connection rate
redis-cli INFO stats | grep total_connections_received

# Check for connection pool leaks (many connections from same IP)
redis-cli CLIENT LIST | awk '{print $2}' | sort | uniq -c | sort -rn | head
```

**Remediation:**
1. Increase `maxclients` if the server can handle it
2. Set `timeout 300` to close idle connections
3. Fix application connection pool leaks (not closing connections)
4. Use connection pooling (PgBouncer equivalent: use client library pools)
5. Rate-limit new connections at the load balancer level
