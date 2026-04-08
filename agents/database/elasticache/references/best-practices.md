# Amazon ElastiCache and MemoryDB Best Practices Reference

## Cluster Design and Sizing

### Choosing the Right Service

**Decision tree:**

1. **Do you need durability (data survives full cluster restart)?**
   - Yes --> MemoryDB for Redis/Valkey
   - No --> Continue to step 2

2. **Do you need Redis/Valkey data structures (sorted sets, streams, pub/sub)?**
   - Yes --> ElastiCache for Redis/Valkey (or Serverless)
   - No --> Continue to step 3

3. **Do you need the simplest possible caching layer with multi-threaded performance?**
   - Yes --> ElastiCache for Memcached
   - No --> ElastiCache for Redis/Valkey (more features, wider ecosystem)

4. **Do you want to avoid capacity planning and node management?**
   - Yes --> ElastiCache Serverless
   - No --> ElastiCache provisioned (more control, lower cost at scale)

5. **New deployment or no Redis OSS licensing dependency?**
   - Prefer Valkey engine for new deployments (open-source, actively developed by AWS and community)
   - Use Redis OSS engine if you need specific Redis features not yet in Valkey, or for existing clusters

### Engine Selection: Redis OSS vs. Valkey

**Prefer Valkey when:**
- Starting a new project with no existing Redis dependency
- You want the latest performance optimizations (Valkey 8.0 multi-threaded I/O)
- Open-source licensing is important to your organization
- AWS recommends Valkey as the default choice for new deployments

**Use Redis OSS when:**
- Existing cluster running Redis OSS and migration risk is not justified
- Specific Redis module dependency not yet available in Valkey
- You need a Redis version newer than the corresponding Valkey release

**Migration from Redis OSS to Valkey:**
- In-place engine upgrade is supported for compatible versions (e.g., Redis 7.0/7.1 to Valkey 7.2)
- Test thoroughly in a non-production environment first
- The migration performs a rolling replacement of nodes
- Expect brief failover during the migration (similar to a maintenance window)

### Cluster Mode Decision

**Use Cluster Mode Disabled when:**
- Dataset fits comfortably in a single node (with 25% reserved memory headroom)
- Simpler operational model is preferred
- Application does not use multi-key commands across different keys extensively
- Maximum data size needed is under ~475 GB (75% of cache.r7g.16xlarge)

**Use Cluster Mode Enabled when:**
- Dataset exceeds single-node memory capacity
- Need horizontal write scaling (more write throughput than a single primary can provide)
- Want to distribute data across shards for better fault isolation
- Plan to use Global Datastore (requires cluster mode enabled)
- Using MemoryDB (always uses cluster mode)

### Node Type Selection

**General guidance:**
- **r7g family** -- Default choice for most workloads. Best price/performance ratio for memory-intensive caching.
- **m7g family** -- When you need balanced CPU and memory (e.g., Lua scripting, complex sorted set operations).
- **c7gn family** -- Network-intensive workloads (high connection count, large values, high pub/sub throughput).
- **r7gd family** -- Data tiering workloads where significant cold data can be offloaded to SSD.
- **t4g/t3 family** -- Development, testing, and low-traffic workloads only. CPU credits can be exhausted under sustained load.

**Sizing process:**
1. Estimate dataset size: total data stored in cache at peak
2. Add 25% for Redis overhead (reserved memory): `node_memory = dataset_size / 0.75`
3. Add headroom for growth and spikes: target 60-70% utilization at steady state
4. For cluster mode enabled, divide by number of shards: `per_shard_memory = total_memory / num_shards`
5. Select the smallest node type that satisfies per-shard memory
6. Verify CPU: estimate operations per second and check that the node type provides sufficient CPU
7. Verify network: estimate data transfer rate and check network bandwidth limits

**Example:** 100 GB dataset, cluster mode enabled with 4 shards:
- Per-shard usable memory needed: 100 / 4 = 25 GB
- With 25% reserved: 25 / 0.75 = 33.3 GB
- With 30% headroom: 33.3 / 0.70 = 47.6 GB
- Choose cache.r7g.xlarge (26.32 GB) -- too small. Choose cache.r7g.2xlarge (52.82 GB) -- fits.

### Replica Strategy

**Number of replicas per shard:**
- **0 replicas** -- Development only. No failover capability, no read scaling.
- **1 replica** -- Minimum for production. Enables Multi-AZ failover.
- **2 replicas** -- Recommended for production. Survives one replica failure while still having failover capability.
- **3-5 replicas** -- High read throughput workloads. Distribute read traffic across more replicas.

**Replica placement:**
- Spread replicas across different Availability Zones for fault tolerance
- Place at least one replica in a different AZ from the primary
- For latency-sensitive reads, place a replica in the same AZ as the majority of read traffic

## Security Best Practices

### Network Configuration

**VPC and subnet design:**
```bash
# Create a subnet group spanning multiple AZs
aws elasticache create-cache-subnet-group \
  --cache-subnet-group-name my-cache-subnets \
  --cache-subnet-group-description "Private subnets for ElastiCache" \
  --subnet-ids subnet-abc123 subnet-def456 subnet-ghi789
```

- Deploy in private subnets only (no internet gateway route)
- Use separate subnets for cache nodes if your VPC design allows (isolation)
- Minimum 2 AZs for Multi-AZ deployments, 3 AZs recommended

**Security group rules:**
```
Inbound:
  - Protocol: TCP, Port: 6379 (Redis/Valkey) or 11211 (Memcached)
  - Source: Application security group (SG-APP)
  - Do NOT open to 0.0.0.0/0 or the entire VPC CIDR

Outbound:
  - Default: Allow all (for cluster-internal communication)
```

- Use security group references (SG-to-SG) instead of CIDR ranges when possible
- Separate security groups for different cache clusters (blast radius reduction)
- Audit security group rules regularly with AWS Config rules

### Encryption

**Enable both TLS and at-rest encryption for all production clusters:**
```bash
# Create a Redis/Valkey cluster with encryption
aws elasticache create-replication-group \
  --replication-group-id my-cache \
  --replication-group-description "Production cache" \
  --engine valkey \
  --engine-version 8.0 \
  --cache-node-type cache.r7g.large \
  --num-cache-clusters 3 \
  --multi-az-enabled \
  --automatic-failover-enabled \
  --transit-encryption-enabled \
  --at-rest-encryption-enabled \
  --kms-key-id arn:aws:kms:us-east-1:123456789012:key/my-key \
  --cache-subnet-group-name my-cache-subnets \
  --security-group-ids sg-abc123
```

**TLS considerations:**
- Plan for ~25% CPU overhead from TLS. Factor this into node sizing.
- Use the latest TLS 1.3 where supported for better performance.
- Test TLS connection from your application framework before production deployment.
- Client connection string must use `rediss://` (with double 's') or `--tls` flag.

### Authentication

**IAM authentication (preferred for Redis 7.0+, Valkey):**
```bash
# Create an ElastiCache user with IAM authentication
aws elasticache create-user \
  --user-id iam-user-01 \
  --user-name iam-user-01 \
  --engine redis \
  --authentication-mode Type=iam \
  --access-string "on ~app:* +@all"

# Create a user group and associate with the cluster
aws elasticache create-user-group \
  --user-group-id my-user-group \
  --engine redis \
  --user-ids default iam-user-01

aws elasticache modify-replication-group \
  --replication-group-id my-cache \
  --user-group-ids-to-add my-user-group
```

**Benefits of IAM auth:**
- No static passwords to manage or rotate
- Integrates with IAM roles for EC2, ECS, Lambda
- Short-lived tokens (15 minutes) limit credential exposure
- Audit trail through CloudTrail

**ACL-based authentication (Redis 6.0+, Valkey, MemoryDB):**
```bash
# Create a user with password
aws elasticache create-user \
  --user-id app-user \
  --user-name appuser \
  --engine redis \
  --passwords "StrongPassword123!" \
  --access-string "on ~app:* +@read +@write +@connection -@admin"

# For MemoryDB
aws memorydb create-user \
  --user-name appuser \
  --authentication-mode Type=password,Passwords="StrongPassword123!" \
  --access-string "on ~app:* +@read +@write +@connection -@admin"
```

**ACL design patterns:**
- Separate users per application or microservice
- Use key pattern restrictions (`~app:*`) to isolate applications sharing a cluster
- Deny admin commands (`-@admin`, `-@dangerous`) for application users
- Keep a separate admin user for operational tasks
- Rotate passwords by adding a new password, updating clients, then removing the old password (dual-password support)

## Performance Optimization

### Connection Management

**Connection pooling:**
- Every application instance should use a connection pool
- Recommended pool size: 5-20 connections per application instance
- Calculate total connections: `app_instances * pool_size < maxclients (65,000 default)`
- Use `PING` for connection health checks on checkout
- Set idle timeout to reclaim unused connections

**Avoid connection storms:**
- During application deployments or restarts, all instances may establish connections simultaneously
- Use exponential backoff with jitter for connection retries
- Stagger application instance restarts (rolling deployment)
- Pre-warm connection pools during startup (establish connections before serving traffic)

**Example connection pool configuration (Python, redis-py):**
```python
import redis

pool = redis.ConnectionPool(
    host='my-cache.abc123.ng.0001.use1.cache.amazonaws.com',
    port=6379,
    max_connections=20,
    socket_timeout=5,
    socket_connect_timeout=5,
    retry_on_timeout=True,
    health_check_interval=30,
    ssl=True,  # for TLS-enabled clusters
)
r = redis.Redis(connection_pool=pool)
```

### Key Design

**Key naming conventions:**
- Use a consistent prefix scheme: `{service}:{entity}:{id}:{attribute}`
- Example: `user:1000:profile`, `order:5678:items`, `session:abc123`
- Keep keys short but descriptive (each key byte costs memory)
- Use colons as separators (convention, not requirement)

**Hash tags for cluster mode:**
- Co-locate related keys on the same shard: `{user:1000}:profile`, `{user:1000}:sessions`
- The hash tag `{user:1000}` determines the slot
- Required for multi-key operations (MGET, MSET, Lua scripts with multiple keys, transactions)
- Caution: Over-use of hash tags can create hot shards if one tag maps to a disproportionate amount of data

**Value optimization:**
- Keep values small (under 10 KB for best performance)
- Compress large values (gzip, LZ4, Snappy) before storing
- Use Redis hashes for objects instead of serialized JSON strings (more memory-efficient for small objects due to listpack encoding)
- Avoid storing values > 100 KB (causes latency spikes, blocks event loop)
- For large objects, store in S3 and cache the S3 URL or a summary

### Command Optimization

**Avoid O(N) commands on large datasets:**
- `KEYS *` -- Never use in production. Use `SCAN` with COUNT parameter instead.
- `SMEMBERS` on large sets -- Use `SSCAN`
- `HGETALL` on large hashes -- Use `HSCAN` or `HMGET` for specific fields
- `LRANGE 0 -1` on large lists -- Paginate with LRANGE and offsets
- `SORT` on large collections -- Pre-compute sorted results

**Use pipelining:**
- Batch multiple commands in a single round trip
- Reduces network latency overhead from N round trips to 1
- Ideal for bulk reads/writes where commands are independent
- In cluster mode, pipeline commands must target the same slot (use hash tags)

**Use Lua scripts for atomicity:**
- When you need to read-modify-write atomically, use EVAL/EVALSHA
- Scripts execute atomically (no other commands interleave)
- Keep scripts short (< 5ms execution) to avoid blocking
- Cache scripts with SCRIPT LOAD + EVALSHA to avoid re-transmitting script text

### Caching Strategy Implementation

**Lazy loading with stampede protection:**
```python
import redis
import json
import time
import random

r = redis.Redis(host='cache-endpoint', port=6379, ssl=True)

def get_with_cache(key, ttl_seconds, fetch_fn):
    cached = r.get(key)
    if cached:
        return json.loads(cached)
    
    # Stampede protection with SETNX lock
    lock_key = f"lock:{key}"
    if r.set(lock_key, "1", nx=True, ex=30):  # 30s lock timeout
        try:
            data = fetch_fn()
            # Add jitter to TTL to prevent synchronized expiration
            jittered_ttl = ttl_seconds + random.randint(0, int(ttl_seconds * 0.1))
            r.set(key, json.dumps(data), ex=jittered_ttl)
            return data
        finally:
            r.delete(lock_key)
    else:
        # Another process is refreshing; wait briefly and retry
        time.sleep(0.1)
        cached = r.get(key)
        if cached:
            return json.loads(cached)
        return fetch_fn()  # Fallback: fetch directly
```

**Write-through pattern:**
```python
def write_through(key, data, ttl_seconds):
    # Write to database first
    database.save(data)
    # Then update cache
    r.set(key, json.dumps(data), ex=ttl_seconds)

def read(key, ttl_seconds, fetch_fn):
    cached = r.get(key)
    if cached:
        return json.loads(cached)
    # Cache miss: fetch from DB and populate cache
    data = fetch_fn()
    r.set(key, json.dumps(data), ex=ttl_seconds)
    return data
```

**TTL strategy matrix:**

| Data Type | TTL | Rationale |
|---|---|---|
| User sessions | 30 minutes | Security: limit session lifetime |
| API rate limit counters | 1-60 seconds | Must match the rate limit window |
| Database query results | 5-60 minutes | Balance freshness vs. DB load |
| Product catalog | 1-4 hours | Catalog changes are infrequent |
| Static configuration | 24 hours | Rarely changes, long cache life |
| Real-time leaderboard | No TTL (ZADD updates in place) | Continuously updated |
| Computed aggregations | 1-15 minutes | Depends on acceptable staleness |

### Eviction Policy Selection

| Policy | Behavior | Use Case |
|---|---|---|
| `allkeys-lru` | Evict least recently used key from all keys | General caching (recommended default) |
| `allkeys-lfu` | Evict least frequently used key from all keys | Caching with frequency-biased retention |
| `volatile-lru` | Evict LRU key from keys with TTL set | Mix of cached data (with TTL) and persistent data (no TTL) |
| `volatile-lfu` | Evict LFU key from keys with TTL set | Same as above, frequency-biased |
| `volatile-ttl` | Evict key with shortest TTL | Prefer to evict soon-to-expire keys |
| `noeviction` | Return error on write when memory full | When data loss is unacceptable (use with MemoryDB or careful sizing) |

**Recommendation:** Use `allkeys-lru` for pure caching workloads. Use `volatile-lru` if the cluster holds a mix of cached data (with TTL) and data that should not be evicted (no TTL). Use `allkeys-lfu` for workloads with skewed access patterns where frequently accessed keys should persist.

## Operational Best Practices

### Maintenance Windows

- Schedule maintenance windows during lowest-traffic periods
- ElastiCache applies engine patches and OS updates during the maintenance window
- Expect brief failovers during patching (one node at a time for replication groups)
- Monitor `ReplicationLag` after maintenance to ensure replicas catch up
- Test patches in non-production environments first

### Monitoring and Alerting

**Essential CloudWatch alarms:**

```bash
# High memory usage alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "ElastiCache-HighMemory-my-cache" \
  --metric-name DatabaseMemoryUsagePercentage \
  --namespace AWS/ElastiCache \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 3 \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:ops-alerts

# Evictions alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "ElastiCache-Evictions-my-cache" \
  --metric-name Evictions \
  --namespace AWS/ElastiCache \
  --statistic Sum \
  --period 300 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:ops-alerts

# High CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "ElastiCache-HighCPU-my-cache" \
  --metric-name EngineCPUUtilization \
  --namespace AWS/ElastiCache \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 3 \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:ops-alerts

# Replication lag alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "ElastiCache-ReplicationLag-my-cache" \
  --metric-name ReplicationLag \
  --namespace AWS/ElastiCache \
  --statistic Maximum \
  --period 60 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 5 \
  --dimensions Name=CacheClusterId,Value=my-cache-002 \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:ops-alerts
```

**CloudWatch dashboard widgets (recommended):**
- EngineCPUUtilization per node (line chart)
- DatabaseMemoryUsagePercentage per node (line chart with 80% threshold line)
- CacheHitRate (line chart, target > 80%)
- Evictions (sum, bar chart)
- CurrConnections (line chart)
- NetworkBytesIn + NetworkBytesOut (stacked area chart)
- ReplicationLag per replica (line chart)
- GetTypeCmds + SetTypeCmds (operations per second, line chart)

### Backup Strategy

**ElastiCache backup configuration:**
```bash
# Enable automatic backups with 7-day retention
aws elasticache modify-replication-group \
  --replication-group-id my-cache \
  --snapshotting-cluster-id my-cache-002 \
  --snapshot-retention-limit 7 \
  --snapshot-window 03:00-04:00

# Create a manual snapshot
aws elasticache create-snapshot \
  --replication-group-id my-cache \
  --snapshot-name my-cache-pre-upgrade-2026-04-07

# Copy snapshot to another region
aws elasticache copy-snapshot \
  --source-snapshot-name my-cache-pre-upgrade-2026-04-07 \
  --target-snapshot-name my-cache-dr-copy \
  --target-bucket my-s3-bucket-us-west-2 \
  --region us-west-2
```

**Best practices:**
- Always take a manual snapshot before any major change (scaling, engine upgrade, parameter change)
- Set automatic backup retention to 7+ days for production
- Schedule backups during low-traffic periods (BGSAVE causes memory and CPU spikes)
- Use a replica for backup source (`--snapshotting-cluster-id` pointing to a replica) to avoid impacting the primary
- Periodically test restore by creating a cluster from a snapshot
- Copy critical snapshots to a different region for disaster recovery

### Scaling Operations

**Vertical scaling (change node type):**
```bash
# Scale up a replication group
aws elasticache modify-replication-group \
  --replication-group-id my-cache \
  --cache-node-type cache.r7g.2xlarge \
  --apply-immediately
```
- Creates new nodes, syncs data, switches over. Minimal downtime per node.
- Cannot scale down if the new node type does not have enough memory for the current dataset.
- Test in non-production first. Verify memory fits.

**Horizontal scaling (add/remove shards):**
```bash
# Scale out: add shards (cluster mode enabled)
aws elasticache modify-replication-group-shard-configuration \
  --replication-group-id my-cache \
  --node-group-count 6 \
  --apply-immediately

# Scale out with specific slot distribution
aws elasticache modify-replication-group-shard-configuration \
  --replication-group-id my-cache \
  --node-group-count 6 \
  --resharding-configuration \
    "NodeGroupId=0001,PreferredAvailabilityZones=us-east-1a,us-east-1b" \
    "NodeGroupId=0002,PreferredAvailabilityZones=us-east-1b,us-east-1c" \
  --apply-immediately

# Scale in: remove shards
aws elasticache modify-replication-group-shard-configuration \
  --replication-group-id my-cache \
  --node-group-count 2 \
  --node-groups-to-remove 0003 0004 \
  --apply-immediately
```

**Scaling checklist:**
1. Take a snapshot before scaling
2. Verify the target configuration has sufficient memory for the dataset
3. Scale during low-traffic periods when possible
4. Monitor `EngineCPUUtilization`, `DatabaseMemoryUsagePercentage`, and `ReplicationLag` during and after scaling
5. Verify application connectivity after scaling completes
6. Resharding can take minutes to hours depending on data volume

### Parameter Group Management

**Creating and applying custom parameter groups:**
```bash
# Create a custom parameter group
aws elasticache create-cache-parameter-group \
  --cache-parameter-group-name my-valkey-params \
  --cache-parameter-group-family valkey8.0 \
  --description "Custom Valkey 8.0 parameters for production"

# Modify parameters
aws elasticache modify-cache-parameter-group \
  --cache-parameter-group-name my-valkey-params \
  --parameter-name-values \
    "ParameterName=maxmemory-policy,ParameterValue=allkeys-lru" \
    "ParameterName=timeout,ParameterValue=300" \
    "ParameterName=tcp-keepalive,ParameterValue=300" \
    "ParameterName=maxmemory-samples,ParameterValue=10" \
    "ParameterName=lazyfree-lazy-eviction,ParameterValue=yes" \
    "ParameterName=lazyfree-lazy-expire,ParameterValue=yes" \
    "ParameterName=activedefrag,ParameterValue=yes"

# Apply to a replication group
aws elasticache modify-replication-group \
  --replication-group-id my-cache \
  --cache-parameter-group-name my-valkey-params \
  --apply-immediately
```

**Parameter change impact:**
- Some parameters take effect immediately (e.g., `maxmemory-policy`, `timeout`)
- Some parameters require a reboot (e.g., `maxclients`). Use `describe-cache-parameters` with `--source engine-default` to check which parameters are modifiable and whether they require reboot.
- Apply parameter changes in non-production first and validate behavior

### Engine Upgrades

**Upgrade path:**
```bash
# Check available engine versions
aws elasticache describe-cache-engine-versions \
  --engine valkey

# Upgrade engine version
aws elasticache modify-replication-group \
  --replication-group-id my-cache \
  --engine-version 8.0 \
  --apply-immediately
```

**Upgrade best practices:**
1. Review the release notes for breaking changes
2. Test the upgrade in a non-production environment (restore a snapshot, upgrade, validate)
3. Take a snapshot before upgrading production
4. Schedule during a maintenance window or low-traffic period
5. Monitor closely after upgrade (latency, error rates, memory usage)
6. Engine downgrades are NOT supported. If the upgrade causes issues, restore from the pre-upgrade snapshot.

### Global Datastore Operations

**Setting up Global Datastore:**
```bash
# Create primary replication group (must be cluster mode enabled)
aws elasticache create-replication-group \
  --replication-group-id my-global-primary \
  --replication-group-description "Global Datastore primary" \
  --engine valkey \
  --engine-version 7.2 \
  --cache-node-type cache.r7g.xlarge \
  --num-node-groups 3 \
  --replicas-per-node-group 2 \
  --multi-az-enabled \
  --automatic-failover-enabled \
  --transit-encryption-enabled \
  --at-rest-encryption-enabled \
  --cache-subnet-group-name my-subnets

# Create Global Datastore
aws elasticache create-global-replication-group \
  --global-replication-group-id-suffix my-global \
  --primary-replication-group-id my-global-primary

# Add a secondary region
aws elasticache create-replication-group \
  --replication-group-id my-global-secondary \
  --replication-group-description "Global Datastore secondary in eu-west-1" \
  --global-replication-group-id ldgnf-my-global \
  --cache-node-type cache.r7g.xlarge \
  --num-node-groups 3 \
  --replicas-per-node-group 1 \
  --cache-subnet-group-name my-subnets-eu \
  --region eu-west-1
```

**Failover to secondary region:**
```bash
aws elasticache failover-global-replication-group \
  --global-replication-group-id ldgnf-my-global \
  --primary-region eu-west-1 \
  --primary-replication-group-id my-global-secondary
```

## Cost Optimization Strategies

### Reserved Node Planning

```bash
# List available reserved node offerings
aws elasticache describe-reserved-cache-nodes-offerings \
  --cache-node-type cache.r7g.xlarge \
  --offering-type "No Upfront"

# Purchase a reserved node
aws elasticache purchase-reserved-cache-nodes-offering \
  --reserved-cache-nodes-offering-id offering-id-here \
  --cache-node-count 6
```

**Strategy:**
- Purchase reservations for baseline capacity (the minimum number of nodes you always run)
- Use on-demand for burst capacity and development environments
- 1-year No Upfront: ~30% savings (good for uncertain long-term needs)
- 1-year Partial Upfront: ~35-40% savings
- 3-year All Upfront: ~55-60% savings (best for stable, predictable workloads)
- Review and adjust reservations quarterly

### Data Tiering Cost Savings

- r7gd nodes cost ~20% more than equivalent r7g nodes but provide up to 5x total data capacity
- Cost-effective when 20%+ of your data is cold (accessed infrequently)
- Example: cache.r7g.4xlarge (~105 GB, $X/hour) vs. cache.r7gd.4xlarge (~52 GB DRAM + ~190 GB SSD = ~242 GB effective, ~1.2X/hour)
- Monitor data tiering metrics to validate cold data ratio

### Architecture-Level Savings

- **Consolidate small clusters:** If you have multiple small clusters for different applications, consider a larger shared cluster with ACL-based isolation
- **Right-size replicas:** Read replicas do not need to be the same node type as the primary (can use smaller nodes if read traffic is low)
- **Use Serverless for dev/test:** ElastiCache Serverless scales to zero activity cost (only storage cost), ideal for environments that are idle most of the time
- **Compress values:** Reduce memory usage by 50-80% for text-based values (JSON, XML). Use gzip or LZ4 compression in the application layer.
- **Set TTLs on all cached data:** Prevents unbounded memory growth that forces larger node types

## Troubleshooting Playbooks

### Playbook: High Eviction Rate

**Symptoms:** `Evictions` CloudWatch metric increasing, `CacheHitRate` dropping, application latency increasing due to more cache misses.

**Investigation:**
1. Check `DatabaseMemoryUsagePercentage` -- if near 100%, the cluster is genuinely out of memory
2. Run `INFO memory` via redis-cli to see `used_memory`, `maxmemory`, `mem_fragmentation_ratio`
3. Check `DBSIZE` for total key count
4. Use `MEMORY USAGE <key>` on suspicious large keys
5. Check `maxmemory-policy` parameter -- ensure it matches your use case

**Resolution:**
1. Immediate: Add shards (cluster mode) or scale up node type
2. Short-term: Review and tighten TTLs, identify and remove unnecessary keys
3. Long-term: Enable data tiering (r7gd nodes), optimize value sizes, review caching strategy

### Playbook: Connection Storms

**Symptoms:** `NewConnections` spikes, `CurrConnections` rising rapidly, `EngineCPUUtilization` spikes, application errors (connection refused/timeout).

**Investigation:**
1. Correlate timing with application deployments or restarts
2. Check `CLIENT LIST` output for connection sources and idle times
3. Verify connection pooling is configured in all application instances
4. Check if `maxclients` limit is being reached

**Resolution:**
1. Implement connection pooling in all application code
2. Use exponential backoff with jitter for reconnection
3. Increase `maxclients` parameter if needed (default 65,000)
4. Stagger application restarts (rolling deployment)
5. Consider ElastiCache-specific: set `timeout` parameter to close idle connections

### Playbook: Failover Issues

**Symptoms:** Failover does not complete, application experiences prolonged outage, split-brain concerns.

**Investigation:**
1. Check `describe-replication-groups` for `Status` and `NodeGroupMembers` status
2. Check `describe-events` for failover-related events
3. Check `ReplicationLag` -- if replica lag was very high before failover, data loss is possible
4. Verify Multi-AZ is enabled (`MultiAZ: enabled`)
5. Check that the subnet group spans multiple AZs with healthy subnets

**Resolution:**
1. Ensure Multi-AZ is enabled for all production replication groups
2. Monitor `ReplicationLag` and alert when it exceeds 1 second
3. Verify at least one healthy replica exists at all times
4. Test failover regularly with `test-failover` API
5. Ensure application uses the primary endpoint (not individual node endpoints) for automatic DNS failover

### Playbook: Replication Lag

**Symptoms:** `ReplicationLag` CloudWatch metric consistently above 1 second, stale reads from replicas, eventual consistency issues.

**Investigation:**
1. Check primary `EngineCPUUtilization` -- primary may be overloaded
2. Check `NetworkBytesOut` on primary -- replication traffic saturating network
3. Check replica `EngineCPUUtilization` -- replica may be overloaded with reads
4. Run `INFO replication` to see `master_repl_offset` and `slave_repl_offset` delta
5. Check for large key operations that block the event loop

**Resolution:**
1. Scale up primary or replica node types for more CPU/network capacity
2. Reduce write throughput if possible (batch writes, reduce write frequency)
3. Add more replicas to distribute read load (reducing per-replica read pressure)
4. Avoid O(N) commands on replicas (`KEYS`, `SORT`, large `SMEMBERS`)
5. If using Lua scripts, optimize for speed (< 5ms execution)

### Playbook: Scaling Operation Failures

**Symptoms:** Resharding stuck, vertical scaling timeout, scaling operation fails.

**Investigation:**
1. Check `describe-replication-groups` for `Status` (should show `modifying`)
2. Check `describe-events` for scaling-related events and errors
3. Verify target node type has sufficient memory for current dataset
4. Check if there are ongoing maintenance operations conflicting with scaling

**Resolution:**
1. Wait -- some scaling operations take hours for large datasets
2. If stuck, contact AWS Support with the replication group ID and operation details
3. For resharding failures: ensure no slot migration is in progress
4. For memory-related failures: the target configuration must have more total memory than the current dataset size
5. Retry during a lower-traffic period
