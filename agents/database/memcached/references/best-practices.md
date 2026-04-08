# Memcached Best Practices Reference

## Startup Configuration

### Essential Flags

```bash
# Production-ready Memcached startup
memcached \
  -d                          # Daemonize
  -u memcached                # Run as non-root user
  -m 4096                     # Memory limit in MB
  -c 10000                    # Max simultaneous connections
  -t 8                        # Worker threads (match CPU cores)
  -p 11211                    # TCP port (default 11211)
  -l 10.0.0.1                 # Listen address (bind to specific interface)
  -P /var/run/memcached.pid   # PID file
  -o slab_reassign,slab_automove=1,lru_maintainer,lru_crawler \
  -o modern                   # Enable all modern defaults (1.6.x)
  -v                          # Verbose logging (use -vv or -vvv for debugging only)
```

### Memory Sizing

**Formula for sizing:**
```
Required memory = working_set_size * (1 + overhead_factor)

Where:
  working_set_size = number_of_items * average_item_total_size
  average_item_total_size = key_length + value_length + 56 bytes overhead
  overhead_factor = 0.15 to 0.30 (slab waste + connection buffers + hash table)
```

**Rules of thumb:**
| Working Set | Recommended `-m` | Rationale |
|---|---|---|
| 1 GB of data | 1.5 GB | 50% overhead for slab waste and metadata |
| 5 GB of data | 7 GB | More diverse item sizes = more slab classes |
| 20 GB of data | 25 GB | Larger datasets tend to have better slab utilization |

**Connection buffer overhead:**
```
connection_memory = max_connections * 4KB (read + write buffers)
At -c 10000: ~40 MB for connection buffers alone
At -c 100000: ~400 MB
```

Subtract connection buffer overhead from `-m` when planning usable cache capacity.

### Thread Count

```bash
# Match to available CPU cores
-t $(nproc)        # All cores
-t $(($(nproc)/2)) # Half cores (if co-located with other services)
```

**Guidelines:**
- 1-4 cores: `-t 4` (default, sufficient for most workloads)
- 8 cores: `-t 8` (for >100K ops/sec)
- 16+ cores: `-t 16` (for >500K ops/sec)
- Beyond 16 threads: diminishing returns due to lock contention
- Monitor with `stats` -> `threads` and per-thread stats via `stats conns`

### Growth Factor Tuning

```bash
# Default (good for mixed workloads)
-f 1.25

# Low-waste (when item sizes are known and clustered)
-f 1.05

# When all items are roughly the same size, use exact chunk sizing:
-f 1.01 -n <exact_item_size_minus_overhead>
```

**Choosing a growth factor:**
1. Profile your item size distribution: `stats sizes_enable` then `stats sizes`
2. If sizes cluster around a few values: lower factor (1.05-1.10)
3. If sizes are uniformly distributed: default 1.25 is fine
4. If you only store one size: minimize waste with precise `-n` and `-f 1.01`

### Maximum Item Size

```bash
# Default: 1 MB
-I 1m

# Increase for larger objects (max 128 MB, but not recommended)
-I 10m

# Considerations for large items:
# - Each large item consumes an entire page (1 MB) or more
# - Fewer items fit in cache
# - Network transfer time increases
# - Better to compress values or split into chunks
```

### Modern Defaults (`-o modern`)

In Memcached 1.6.x, the `-o modern` flag enables a set of recommended defaults:
- `slab_reassign` -- Enable slab page rebalancing
- `slab_automove=1` -- Conservative automatic rebalancing
- `lru_maintainer` -- Background LRU management thread
- `lru_crawler` -- Background expired-item reclamation
- `hash_algorithm=murmur3` -- Modern hash function
- `maxconns_fast=1` -- Immediately reject connections beyond limit (no queuing)
- `tail_repair_time=1` -- Repair LRU tail corruption after 1 second

**Always use `-o modern` in production.** It enables critical stability and performance features.

## Consistent Hashing Setup

### Client-Side Configuration

**Python (pymemcache with consistent hashing):**
```python
from pymemcache.client.hash import HashClient

servers = [
    ('10.0.0.1', 11211),
    ('10.0.0.2', 11211),
    ('10.0.0.3', 11211),
]

client = HashClient(
    servers,
    hasher=None,         # uses built-in ketama-compatible hashing
    use_pooling=True,
    max_pool_size=25,
    connect_timeout=1.0,
    timeout=0.5,
    no_delay=True,
    ignore_exc=False,    # raise exceptions on errors
    dead_timeout=30,     # seconds before retrying a dead server
)
```

**PHP (php-memcached extension):**
```php
$memcached = new Memcached();
$memcached->setOption(Memcached::OPT_DISTRIBUTION, Memcached::DISTRIBUTION_CONSISTENT);
$memcached->setOption(Memcached::OPT_LIBKETAMA_COMPATIBLE, true);
$memcached->setOption(Memcached::OPT_REMOVE_FAILED_SERVERS, true);
$memcached->setOption(Memcached::OPT_RETRY_TIMEOUT, 2);
$memcached->setOption(Memcached::OPT_CONNECT_TIMEOUT, 500);  // ms
$memcached->setOption(Memcached::OPT_RECV_TIMEOUT, 500000);  // us
$memcached->setOption(Memcached::OPT_SEND_TIMEOUT, 500000);  // us
$memcached->addServers([
    ['10.0.0.1', 11211, 1],  // host, port, weight
    ['10.0.0.2', 11211, 1],
    ['10.0.0.3', 11211, 1],
]);
```

**Java (spymemcached):**
```java
ConnectionFactoryBuilder builder = new ConnectionFactoryBuilder()
    .setProtocol(ConnectionFactoryBuilder.Protocol.BINARY)
    .setLocatorType(ConnectionFactoryBuilder.Locator.CONSISTENT)
    .setHashAlg(DefaultHashAlgorithm.KETAMA_HASH)
    .setFailureMode(FailureMode.Redistribute)
    .setOpTimeout(500)       // ms
    .setMaxReconnectDelay(30);

MemcachedClient client = new MemcachedClient(
    builder.build(),
    AddrUtil.getAddresses("10.0.0.1:11211 10.0.0.2:11211 10.0.0.3:11211")
);
```

### Server Weights

When nodes have different memory sizes, use weights to distribute keys proportionally:

```
Server A: 8 GB memory  -> weight 8
Server B: 16 GB memory -> weight 16
Server C: 8 GB memory  -> weight 8

Total: 32 weight units
Server A handles 25% of keys
Server B handles 50% of keys
Server C handles 25% of keys
```

Weights translate to virtual nodes on the hash ring. Higher weight = more virtual nodes = more keys assigned to that server.

### Adding/Removing Servers

**Adding a server to a consistent hashing ring:**
- ~1/N of keys are remapped (N = new total number of servers)
- These keys will experience cache misses
- Mitigate with warm-up: mcrouter's warm-up routing or application-level cache loading

**Removing a server (failure or scale-down):**
- ~1/N of keys (the ones on that server) are lost
- With consistent hashing, these keys redistribute to the nearest neighbor on the ring
- Other keys are unaffected

**Graceful scale-down procedure:**
1. Drain connections to the target node (remove from client configuration or proxy pool)
2. Wait for ongoing requests to complete
3. Keys will miss and be re-cached on the remaining nodes
4. Shut down the node

## Cache Strategy Patterns

### Cache-Aside (Lazy Loading)

The most common pattern for Memcached:

```python
def get_user(user_id):
    key = f"user:{user_id}"
    
    # 1. Check cache
    data = cache.get(key)
    if data is not None:
        return deserialize(data)
    
    # 2. Cache miss: query database
    user = db.query("SELECT * FROM users WHERE id = ?", user_id)
    
    # 3. Populate cache with TTL
    cache.set(key, serialize(user), expire=3600)
    
    return user

def update_user(user_id, updates):
    # 1. Update database
    db.update("UPDATE users SET ... WHERE id = ?", updates, user_id)
    
    # 2. Invalidate cache (NOT update -- avoids stale-write race)
    cache.delete(f"user:{user_id}")
```

**Why delete, not update:** If two processes concurrently update the same key, an update-cache approach can leave stale data (process A sets the cache after process B, but process A's database write was first). Delete-on-write is always safe because the next read will re-populate from the database.

### Write-Through Cache

```python
def update_user(user_id, updates):
    # 1. Update database
    user = db.update_and_return("UPDATE users SET ... WHERE id = ? RETURNING *", 
                                 updates, user_id)
    
    # 2. Update cache atomically with the DB result
    cache.set(f"user:{user_id}", serialize(user), expire=3600)
    
    return user
```

**Trade-offs:**
- Cache is always warm after writes (no cold-read penalty)
- Every write hits both database and cache (higher write latency)
- Race condition: two concurrent writes can leave cache inconsistent with DB
- Mitigation: use CAS for cache updates, or accept brief inconsistency

### Cache Stampede Prevention

**Pattern 1: Locking with ADD**
```python
def get_with_lock(key, compute_fn, ttl=3600, lock_ttl=10):
    value = cache.get(key)
    if value is not None:
        return value
    
    # Try to acquire lock
    lock_key = f"lock:{key}"
    if cache.add(lock_key, "1", expire=lock_ttl):
        try:
            # Won the lock: compute and cache
            value = compute_fn()
            cache.set(key, value, expire=ttl)
            return value
        finally:
            cache.delete(lock_key)
    else:
        # Lost the lock: wait and retry
        time.sleep(0.1)
        return get_with_lock(key, compute_fn, ttl, lock_ttl)
```

**Pattern 2: Probabilistic early recomputation**
```python
def get_with_early_recompute(key, compute_fn, ttl=3600, beta=1.0):
    value, stored_at = cache.get(key)  # store timestamp in value
    if value is not None:
        age = time.time() - stored_at
        remaining_ttl = ttl - age
        # Probabilistic recompute: higher chance as TTL approaches 0
        if remaining_ttl > 0:
            xfetch_threshold = remaining_ttl - beta * math.log(random.random())
            if xfetch_threshold > 0:
                return value
    
    # Recompute
    new_value = compute_fn()
    cache.set(key, (new_value, time.time()), expire=ttl)
    return new_value
```

**Pattern 3: Stale-while-revalidate (meta commands, 1.6.x)**
```
# Client library uses meta commands:
# mg key v t N30    -> GET with vivify: if miss, create empty item with 30s TTL
# ms key <size> T3600 W -> SET with win flag: only one client "wins" the race

# Stale reads served via X flag while winner recaches
```

### TTL Strategies

**Jittered TTLs (prevent thundering herd):**
```python
import random

BASE_TTL = 3600  # 1 hour
JITTER = 600     # +/- 10 minutes

def ttl_with_jitter():
    return BASE_TTL + random.randint(-JITTER, JITTER)

cache.set("popular:key", value, expire=ttl_with_jitter())
```

**Tiered TTLs:**
```
# Source data: long TTL
cache.set("user:42:profile", profile_data, expire=3600)

# Derived/computed data: short TTL
cache.set("dashboard:user:42", dashboard_html, expire=300)

# Session data: moderate TTL with sliding window
cache.set("session:abc123", session_data, expire=1800)
# On each request: cache.touch("session:abc123", expire=1800)
```

**Never use TTL 0 for truly ephemeral data.** TTL 0 means "never expire," which is dangerous in a cache -- the item can only be evicted by LRU pressure or explicit delete.

## mcrouter Configuration

### Basic Pool Routing

```json
{
  "pools": {
    "primary": {
      "servers": [
        "mc1.example.com:11211",
        "mc2.example.com:11211",
        "mc3.example.com:11211"
      ]
    }
  },
  "route": "PoolRoute|primary"
}
```

### Replication (Write to All, Read from One)

```json
{
  "pools": {
    "primary": {
      "servers": [
        "mc1.example.com:11211",
        "mc2.example.com:11211",
        "mc3.example.com:11211"
      ]
    }
  },
  "route": {
    "type": "OperationSelectorRoute",
    "default_policy": "AllSyncRoute|primary",
    "operation_policies": {
      "get": "LatestRoute|primary"
    }
  }
}
```

### Prefix-Based Routing

```json
{
  "pools": {
    "sessions": {
      "servers": ["mc-session1:11211", "mc-session2:11211"]
    },
    "objects": {
      "servers": ["mc-obj1:11211", "mc-obj2:11211", "mc-obj3:11211"]
    }
  },
  "route": {
    "type": "PrefixSelectorRoute",
    "policies": {
      "session:": "PoolRoute|sessions",
      "obj:": "PoolRoute|objects"
    },
    "wildcard": "PoolRoute|objects"
  }
}
```

### Failover Configuration

```json
{
  "pools": {
    "primary": {
      "servers": ["mc1:11211", "mc2:11211", "mc3:11211"]
    },
    "fallback": {
      "servers": ["mc-fallback1:11211", "mc-fallback2:11211"]
    }
  },
  "route": {
    "type": "FailoverRoute",
    "children": [
      "PoolRoute|primary",
      "PoolRoute|fallback"
    ],
    "failover_limit": 2
  }
}
```

### Cold Cache Warm-Up

```json
{
  "pools": {
    "new": {
      "servers": ["mc-new1:11211", "mc-new2:11211"]
    },
    "old": {
      "servers": ["mc-old1:11211", "mc-old2:11211"]
    }
  },
  "route": {
    "type": "WarmUpRoute",
    "cold": "PoolRoute|new",
    "warm": "PoolRoute|old",
    "exptime": 1800
  }
}
```

WarmUpRoute reads from the old pool on cache miss, populates the new pool, and serves the result. After the warm-up period, switch to routing directly to the new pool.

### mcrouter Startup

```bash
mcrouter \
  --port 5000 \
  --config-file=/etc/mcrouter/config.json \
  --num-proxies=4 \
  --fibers-max-pool-size=1024 \
  --server-timeout=500 \
  --reset-inactive-connection-interval=60000 \
  --stats-root=/var/mcrouter/stats \
  --stats-logging-interval=60 \
  --log-path=/var/log/mcrouter/
```

## twemproxy Configuration

### Basic Configuration

```yaml
# /etc/nutcracker/nutcracker.yml
cache_pool:
  listen: 0.0.0.0:11211
  hash: fnv1a_64
  hash_tag: "{}"
  distribution: ketama
  auto_eject_hosts: true
  server_retry_timeout: 2000   # ms before retrying an ejected server
  server_failure_limit: 3      # failures before ejecting
  timeout: 400                 # ms per-server connection timeout
  preconnect: true             # establish connections at startup
  server_connections: 1        # connections per server (pipelining uses 1)
  servers:
    - 10.0.0.1:11211:1         # host:port:weight
    - 10.0.0.2:11211:1
    - 10.0.0.3:11211:1
```

### twemproxy vs mcrouter

| Feature | twemproxy | mcrouter |
|---|---|---|
| **Protocols** | Memcached + Redis | Memcached only |
| **Replication** | No | Yes (AllSyncRoute) |
| **Prefix routing** | No | Yes (PrefixSelectorRoute) |
| **Failover** | Auto-eject + retry | Rich failover policies |
| **Warm-up** | No | Yes (WarmUpRoute) |
| **Connection pooling** | Yes | Yes |
| **Configuration** | YAML (simple) | JSON (complex, flexible) |
| **Complexity** | Low | High |
| **Use case** | Simple, lightweight proxy | Complex routing, large-scale |

## AWS ElastiCache for Memcached

### Cluster Sizing

**Node type selection:**
| Workload | Recommended Node Type | Notes |
|---|---|---|
| Dev/test | cache.t4g.micro/small | Burstable, low cost |
| Small production | cache.m7g.large | 6.38 GB memory, general purpose |
| Medium production | cache.m7g.xlarge | 12.93 GB memory |
| Memory-intensive | cache.r7g.xlarge | 26.32 GB memory, memory-optimized |
| Large-scale | cache.r7g.4xlarge+ | 105+ GB memory |

**Number of nodes:**
```
Minimum: 1 (no redundancy, acceptable for pure caching)
Recommended: 2-3 (distributes load, survives one node failure)
Maximum: 300 nodes per cluster
```

**Usable memory per node:**
```
Usable cache memory = node_memory * 0.85 to 0.90
(10-15% overhead for OS, Memcached process, connection buffers)
```

### Auto Discovery

ElastiCache provides an auto-discovery endpoint that clients use to discover all nodes:

```python
# Python with pymemcache and elasticache-auto-discovery
from pymemcache.client.hash import HashClient
import elasticache_auto_discovery

# Configuration endpoint (not a data endpoint)
config_endpoint = "my-cluster.cfg.use1.cache.amazonaws.com:11211"

# Discover nodes
nodes = elasticache_auto_discovery.discover(config_endpoint)
# Returns: [("10.0.0.1", 11211), ("10.0.0.2", 11211), ("10.0.0.3", 11211)]

client = HashClient(nodes, use_pooling=True, max_pool_size=25)
```

**Auto-discovery protocol:**
```bash
# The configuration endpoint responds to a special command:
echo "config get cluster" | nc my-cluster.cfg.use1.cache.amazonaws.com 11211
# Returns: node list with hostnames and ports
```

### Parameter Groups

Key parameters to configure via ElastiCache parameter groups:

```
chunk_size_growth_factor = 1.25        # Slab growth factor
max_item_size = 1048576                 # Max item size (1 MB default)
maxconns = 65000                        # Max connections per node
binding_protocol = auto                 # auto, ascii, or binary
slab_automove = 1                       # Enable slab rebalancing
lru_maintainer = yes                    # Background LRU management
lru_crawler = yes                       # Expired item reclamation
hash_algorithm = murmur3                # Hash function
```

### CloudWatch Monitoring

Essential CloudWatch metrics for ElastiCache Memcached:

| Metric | Alert Threshold | Action |
|---|---|---|
| `CPUUtilization` | > 90% sustained | Add nodes or scale up node type |
| `SwapUsage` | > 50 MB | Indicates memory pressure, scale up |
| `Evictions` | Sudden spike | Add memory or nodes |
| `CurrConnections` | > 80% of maxconns | Increase maxconns or add nodes |
| `NewConnections` | Sustained spike | Connection pool leak in application |
| `BytesUsedForCacheItems` | > 90% of node memory | Scale up or add nodes |
| `CacheHitRate` | < 80% | Review cache strategy, TTLs, key distribution |
| `CurrItems` | Declining unexpectedly | Check eviction rate |
| `UnusedMemory` | Consistently low | Scale up |

### ElastiCache Scaling Operations

**Vertical scaling (node type change):**
- Requires creating a new cluster with the new node type
- Application must be updated to point to the new cluster
- All cached data is lost (cold cache restart)
- Use mcrouter WarmUpRoute or application-level warm-up

**Horizontal scaling (add/remove nodes):**
- Adding nodes: new node joins, consistent hashing redistributes ~1/N of keys
- Removing nodes: keys on removed node are lost, redistributed to remaining nodes
- Use auto-discovery to avoid manual configuration changes

## Security

### Network Isolation

Memcached has limited built-in security. Network-level controls are essential:

```bash
# Bind to specific interface (not 0.0.0.0)
-l 10.0.0.1

# Disable UDP (prevent amplification attacks)
-U 0

# Firewall rules (iptables example)
iptables -A INPUT -p tcp --dport 11211 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport 11211 -j DROP
```

### SASL Authentication

```bash
# Enable SASL
memcached -S -o sasl_env_file=/etc/memcached/sasl.env

# /etc/memcached/sasl.env contains:
# MEMCACHED_SASL_PWDB=/etc/memcached/sasldb2

# Create SASL user:
saslpasswd2 -a memcached -c username
```

**Limitations:**
- Requires binary protocol (text protocol does not support SASL)
- Only PLAIN mechanism widely supported
- No encryption (passwords sent in cleartext over binary protocol)
- Combine with TLS proxy (stunnel, HAProxy) for encryption

### TLS via Proxy

Since Memcached does not natively support TLS, use a sidecar proxy:

```bash
# stunnel configuration for TLS termination
[memcached]
accept = 0.0.0.0:11212
connect = 127.0.0.1:11211
cert = /etc/stunnel/server.pem
key = /etc/stunnel/server.key
CAfile = /etc/stunnel/ca.pem
verify = 2
```

### VPC Security (AWS)

For ElastiCache:
- Deploy in a private subnet (no public IP)
- Use VPC security groups to restrict access to application subnets only
- No SASL support in ElastiCache Memcached -- VPC isolation is the only access control
- Enable encryption in transit (available in newer ElastiCache versions via TLS)

## Monitoring Setup

### Prometheus Exporter

**memcached_exporter (official Prometheus exporter):**
```bash
# Install and run
memcached_exporter --memcached.address=localhost:11211 --web.listen-address=:9150
```

**Key exported metrics:**
```
memcached_commands_total{command="get",status="hit"}
memcached_commands_total{command="get",status="miss"}
memcached_commands_total{command="set"}
memcached_current_bytes
memcached_limit_bytes
memcached_current_connections
memcached_current_items
memcached_items_evicted_total
memcached_items_reclaimed_total
memcached_slab_current_chunks{slab="1"}
memcached_slab_current_items{slab="1"}
memcached_slab_mem_requested{slab="1"}
memcached_up
```

**Prometheus scrape config:**
```yaml
scrape_configs:
  - job_name: 'memcached'
    static_configs:
      - targets: ['memcached-exporter:9150']
    scrape_interval: 15s
```

### collectd Integration

```
# collectd.conf
LoadPlugin memcached
<Plugin memcached>
  <Instance "production">
    Host "10.0.0.1"
    Port "11211"
  </Instance>
</Plugin>
```

### Grafana Dashboard Panels

Essential panels for a Memcached Grafana dashboard:

1. **Hit ratio** (line chart): `get_hits / (get_hits + get_misses) * 100`
2. **Memory usage** (gauge): `bytes / limit_maxbytes * 100`
3. **Evictions per second** (line chart): rate of `evictions`
4. **Commands per second** (stacked area): rate of `cmd_get`, `cmd_set`, `cmd_delete`, `cmd_touch`
5. **Connections** (line chart): `curr_connections` vs max connections
6. **Items in cache** (line chart): `curr_items`
7. **Bytes read/written** (line chart): `bytes_read`, `bytes_written`
8. **Slab memory distribution** (stacked bar): per-slab-class memory usage
9. **Evictions by slab class** (bar chart): per-class eviction rates
10. **Connection errors** (counter): `listen_disabled_num`, `rejected_connections`

### Health Check Script

```bash
#!/bin/bash
# memcached-health-check.sh

HOST="${MEMCACHED_HOST:-localhost}"
PORT="${MEMCACHED_PORT:-11211}"

echo "=== Memcached Health Check ==="

# Basic connectivity
RESPONSE=$(echo "version" | nc -w 2 "$HOST" "$PORT" 2>/dev/null)
if [ -z "$RESPONSE" ]; then
    echo "CRITICAL: Cannot connect to Memcached at $HOST:$PORT"
    exit 2
fi
echo "OK: $RESPONSE"

# Get stats
STATS=$(echo "stats" | nc -w 2 "$HOST" "$PORT" 2>/dev/null)

# Parse key metrics
HITS=$(echo "$STATS" | grep "STAT get_hits" | awk '{print $3}' | tr -d '\r')
MISSES=$(echo "$STATS" | grep "STAT get_misses" | awk '{print $3}' | tr -d '\r')
EVICTIONS=$(echo "$STATS" | grep "STAT evictions" | awk '{print $3}' | tr -d '\r')
BYTES=$(echo "$STATS" | grep "STAT bytes " | awk '{print $3}' | tr -d '\r')
LIMIT=$(echo "$STATS" | grep "STAT limit_maxbytes" | awk '{print $3}' | tr -d '\r')
CONNS=$(echo "$STATS" | grep "STAT curr_connections" | awk '{print $3}' | tr -d '\r')
ITEMS=$(echo "$STATS" | grep "STAT curr_items" | awk '{print $3}' | tr -d '\r')
UPTIME=$(echo "$STATS" | grep "STAT uptime" | awk '{print $3}' | tr -d '\r')

# Hit ratio
if [ -n "$HITS" ] && [ -n "$MISSES" ]; then
    TOTAL=$((HITS + MISSES))
    if [ "$TOTAL" -gt 0 ]; then
        HIT_RATIO=$(echo "scale=2; $HITS * 100 / $TOTAL" | bc)
        echo "Hit ratio: ${HIT_RATIO}% ($HITS hits, $MISSES misses)"
    fi
fi

# Memory usage
if [ -n "$BYTES" ] && [ -n "$LIMIT" ] && [ "$LIMIT" -gt 0 ]; then
    MEM_PCT=$(echo "scale=2; $BYTES * 100 / $LIMIT" | bc)
    MEM_GB=$(echo "scale=2; $BYTES / 1073741824" | bc)
    LIMIT_GB=$(echo "scale=2; $LIMIT / 1073741824" | bc)
    echo "Memory: ${MEM_GB}GB / ${LIMIT_GB}GB (${MEM_PCT}%)"
fi

echo "Evictions: $EVICTIONS"
echo "Connections: $CONNS"
echo "Items: $ITEMS"
echo "Uptime: ${UPTIME}s"

echo "=== End Health Check ==="
```

## Troubleshooting Playbooks

### High Eviction Rate

**Symptoms:** `evictions` counter climbing steadily, hit ratio declining, database load increasing.

**Diagnostic:**
```bash
# Check overall eviction rate
echo "stats" | nc localhost 11211 | grep evictions

# Check per-slab-class eviction
echo "stats items" | nc localhost 11211 | grep evicted

# Check memory usage
echo "stats" | nc localhost 11211 | grep -E "bytes |limit_maxbytes"

# Check slab utilization
echo "stats slabs" | nc localhost 11211
```

**Remediation:**
1. **Add memory** (`-m`): most direct solution
2. **Add nodes**: distribute data across more servers
3. **Enable slab rebalancing**: `-o slab_reassign,slab_automove=1`
4. **Reduce item sizes**: compress values (gzip, snappy, lz4)
5. **Review TTLs**: shorter TTLs reduce the working set
6. **Check for unnecessary caching**: some data may not benefit from caching

### Slab Imbalance (Calcification)

**Symptoms:** Evictions in some slab classes while others have free chunks, uneven memory distribution.

**Diagnostic:**
```bash
# Compare free chunks across classes
echo "stats slabs" | nc localhost 11211 | grep -E "free_chunks|used_chunks"

# Check eviction rates per class
echo "stats items" | nc localhost 11211 | grep evicted
```

**Remediation:**
1. Enable `slab_reassign` and `slab_automove=1` (if not already)
2. Manual rebalance: `stats slabs` to identify, then `slabs reassign <src> <dst>` via admin interface
3. Restart Memcached (clears all slabs, starts fresh -- acceptable since it is a cache)
4. Tune growth factor (`-f`) to better match item size distribution

### Connection Exhaustion

**Symptoms:** `listen_disabled_num` > 0 in stats, clients receiving connection refused errors, `curr_connections` near `-c` limit.

**Diagnostic:**
```bash
echo "stats" | nc localhost 11211 | grep -E "curr_connections|listen_disabled|total_connections|rejected"
echo "stats conns" | nc localhost 11211  # per-connection details
```

**Remediation:**
1. Increase `-c` (maxconns): requires restart
2. Use a proxy (mcrouter/twemproxy) for connection pooling
3. Fix application connection leaks (connections not being closed/returned to pool)
4. Set connection timeouts in client libraries to reclaim idle connections
5. If using ElastiCache, increase `maxconns` in parameter group

### Cache Stampede

**Symptoms:** Database CPU spikes periodically, correlated with popular key expirations, many simultaneous cache misses for the same key.

**Diagnostic:**
- Application metrics: watch for simultaneous cache misses on the same key
- Database metrics: periodic CPU/connection spikes
- Memcached: sudden drops in `get_hits` followed by many `cmd_set` for the same key

**Remediation:**
1. Implement lock-based recomputation (ADD as mutex)
2. Use stale-while-revalidate with meta commands (1.6.x)
3. Add jitter to TTLs to prevent synchronized expiration
4. Pre-warm cache before TTL expiry (background refresh)

### Low Hit Ratio

**Symptoms:** `get_misses` significantly higher than `get_hits`, database under excessive load.

**Diagnostic:**
```bash
# Calculate hit ratio
echo "stats" | nc localhost 11211 | grep -E "get_hits|get_misses"
# hit_ratio = get_hits / (get_hits + get_misses)

# Check evictions (are items being evicted before they can be hit?)
echo "stats" | nc localhost 11211 | grep evictions

# Check item TTLs vs access patterns
echo "stats items" | nc localhost 11211
```

**Common causes:**
1. **Insufficient memory**: items are evicted before being accessed (add memory/nodes)
2. **TTL too short**: items expire before the next access (increase TTL)
3. **Key mismatch**: application is generating cache keys that do not match on read (debug key generation logic)
4. **Cold cache after restart**: expected, hit ratio improves over time
5. **Working set too large**: more unique keys than cache can hold (increase memory or cache only hot data)
6. **Write-heavy workload**: more SETs than GETs, items are replaced before being read

## OS-Level Tuning

### Linux Kernel Parameters

```bash
# Increase max connections (file descriptors)
echo "memcached soft nofile 65535" >> /etc/security/limits.conf
echo "memcached hard nofile 65535" >> /etc/security/limits.conf

# TCP tuning for high connection counts
echo 65535 > /proc/sys/net/core/somaxconn
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse

# Memory overcommit (not as critical for Memcached since it pre-allocates)
echo 1 > /proc/sys/vm/overcommit_memory

# Disable swap (Memcached should never swap)
swapoff -a
# Or set vm.swappiness = 0
echo 0 > /proc/sys/vm/swappiness

# Disable transparent huge pages (can cause latency spikes)
echo never > /sys/kernel/mm/transparent_hugepages/enabled
echo never > /sys/kernel/mm/transparent_hugepages/defrag
```

### systemd Service File

```ini
[Unit]
Description=Memcached
After=network.target

[Service]
Type=simple
User=memcached
Group=memcached
ExecStart=/usr/bin/memcached -m 4096 -c 10000 -t 8 -l 10.0.0.1 -p 11211 -o modern
LimitNOFILE=65535
LimitCORE=infinity
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```
