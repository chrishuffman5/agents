# Couchbase Best Practices Reference

## Cluster Sizing and Capacity Planning

### Hardware Recommendations

**Data Service nodes:**
```
RAM:    Enough to cache the working set + metadata overhead
        Couchstore: 10% of total data size in RAM minimum
        Magma: 1% of total data size in RAM minimum
CPU:    4+ cores per node (more for compression/compaction)
Disk:   SSD strongly recommended. IOPS > 5000 for write-heavy workloads.
        2x-3x data size for Couchstore (compaction headroom)
        1.5x data size for Magma
Network: 10GbE minimum for production clusters
```

**Index Service nodes:**
```
RAM:    Standard mode (Plasma): enough to cache hot index data
        Memory-optimized (MOI): all indexes must fit in RAM
CPU:    4-8+ cores (index scans are CPU-intensive)
Disk:   SSD required for standard mode; not needed for MOI
```

**Query Service nodes:**
```
RAM:    8-16GB minimum (query processing, sorting, grouping)
CPU:    8+ cores (N1QL is CPU-bound)
Disk:   Minimal (temp space for large sorts/joins)
```

**Search Service nodes:**
```
RAM:    Depends on FTS index size; typically 4-16GB
CPU:    4-8 cores
Disk:   SSD; FTS indexes can be large depending on analyzers
```

### Minimum Node Counts (Production)

| Topology | Nodes | Notes |
|---|---|---|
| **Minimum HA** | 3 Data + 2 Index/Query | Tolerates 1 node failure with 1 replica |
| **Recommended** | 3 Data + 2 Index + 2 Query | Service isolation; tolerates 1 failure per tier |
| **XDCR** | 3+3 (two clusters) | Each cluster independently sized |
| **Multi-service small** | 3 nodes (all services) | Development/small workloads only |

### Bucket Memory Sizing

```
Per-item metadata overhead (value eviction):
  56 bytes (key metadata) + key_length bytes

Example: 100 million items with 20-byte average keys
  Metadata: 100M * (56 + 20) = ~7.6 GB
  Working set (20% active): 100M * 0.2 * 1KB avg doc = ~20 GB
  Bucket RAM quota: ~28 GB (across all Data nodes)
  Per-node (3 Data nodes): ~10 GB per node

For full eviction:
  Lower metadata overhead (~32 bytes per item when evicted)
  But disk reads for any non-cached access
```

## Bucket Configuration

### Storage Engine Selection

```
Use Couchstore when:
  - Working set fits entirely in RAM
  - Low data:RAM ratio (< 5:1)
  - Read-heavy workloads with high cache hit rates
  - Small datasets (< 100GB per node)

Use Magma when:
  - Data significantly exceeds RAM (> 10:1 ratio)
  - Dataset > 1TB per node
  - Write-heavy or mixed workloads with large data
  - Cost optimization (fewer nodes needed)
  - High data density requirements

8.0 default: Magma with 128 vBuckets (requires only 100MB minimum RAM)
```

### Eviction Policy

```
Value Eviction (default):
  - Metadata stays in RAM; only values ejected
  - Key lookups always succeed without disk fetch
  - Higher memory usage per item
  - Best for most workloads

Full Eviction:
  - Both metadata and values can be ejected
  - Key lookups may require disk fetch
  - Much lower memory footprint per item
  - Best for very large datasets with cold data
```

### Replica Configuration

```
1 replica (default): Tolerates 1 node failure. RAM cost = 2x.
2 replicas: Tolerates 2 node failures. RAM cost = 3x. Recommended for critical data.
3 replicas: Tolerates 3 node failures. RAM cost = 4x. Rarely needed.
0 replicas: No redundancy. For caching or test environments only.
```

### TTL (Time To Live)

```bash
# Set default max TTL for a bucket (seconds; 0 = no expiry)
couchbase-cli bucket-edit -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket --max-ttl 2592000  # 30 days

# Set per-collection max TTL (7.6+)
couchbase-cli collection-manage -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket --create-collection my_scope.sessions --max-ttl 3600
```

**TTL best practices:**
- Set TTL at the collection or document level, not the bucket level, when different data types need different lifetimes
- Use expiry pager to clean up expired documents (runs every 60 minutes by default)
- Expired documents are not immediately removed; they are lazily cleaned up on access or by the expiry pager

### Compression

```
Modes:
  - off: No compression
  - passive: Compress only if client sends compressed; decompress on fetch
  - active (default): Actively compress stored documents using Snappy

Active compression reduces memory and disk usage by 30-70% depending on document structure.
Always use "active" unless your documents are already compressed (images, encrypted data).
```

## Index Design Best Practices

### General Rules

1. **Never rely on the primary index in production** -- Create specific secondary indexes for every query pattern. Drop primary indexes after development.

2. **Lead with the most selective predicate** -- The first key in a composite index should be the field with the highest cardinality that appears in WHERE.

3. **Covering indexes eliminate Fetch** -- Include all fields the query needs (WHERE, SELECT, ORDER BY) in the index keys or INCLUDE clause.

4. **Partial indexes reduce size** -- Use WHERE clause in CREATE INDEX to index only relevant documents.

5. **Partitioned indexes for scale** -- Use `PARTITION BY HASH(META().id)` for high-throughput index scans.

6. **Defer builds for batch creation** -- Use `{"defer_build": true}` when creating multiple indexes, then `BUILD INDEX` them together.

### Index Key Ordering

```sql
-- For query: WHERE city = "X" AND rating > 4 ORDER BY name
-- Best index: (city, rating, name)
-- city: equality predicate (most selective, first)
-- rating: range predicate (second)
-- name: sort order (third)

CREATE INDEX idx_hotel_city_rating_name
ON `travel-sample`.inventory.hotel(city, rating, name);
```

### Array Indexes

```sql
-- For queries using ANY ... SATISFIES
-- Query: SELECT * FROM bucket WHERE ANY r IN reviews SATISFIES r.rating > 4 END
CREATE INDEX idx_reviews_rating
ON bucket(DISTINCT ARRAY r.rating FOR r IN reviews END);

-- Flattened array index (7.6+) for nested arrays
CREATE INDEX idx_nested
ON bucket(DISTINCT ARRAY FLATTEN_KEYS(r.rating, r.author) FOR r IN reviews END);
```

### Adaptive Indexes

```sql
-- Index all fields dynamically (useful for ad-hoc queries)
CREATE INDEX idx_adaptive ON bucket(DISTINCT PAIRS(self));

-- Selective adaptive index
CREATE INDEX idx_adaptive_hotel ON `travel-sample`.inventory.hotel(
    DISTINCT PAIRS({city, country, name, avg_rating})
);
```

### Index Replicas and Placement

```sql
-- Create index with replica
CREATE INDEX idx_city ON bucket(city) WITH {"num_replica": 1};

-- Specify node placement
CREATE INDEX idx_city ON bucket(city) WITH {"nodes": ["10.0.0.2:8091", "10.0.0.3:8091"]};
```

## N1QL / SQL++ Best Practices

### Use Parameterized Queries

```sql
-- Named parameters (preferred -- query plan caching)
SELECT * FROM `travel-sample`.inventory.hotel WHERE city = $city AND country = $country;
-- Execute with: {"$city": "San Francisco", "$country": "United States"}

-- Positional parameters
SELECT * FROM `travel-sample`.inventory.hotel WHERE city = $1 AND country = $2;
```

### Pagination

```sql
-- Keyset pagination (preferred for large datasets)
SELECT META(h).id, h.name, h.city
FROM `travel-sample`.inventory.hotel h
WHERE h.city = "San Francisco"
  AND META(h).id > $last_id
ORDER BY META(h).id
LIMIT 20;

-- Offset pagination (simpler but slower for deep pages)
SELECT h.name, h.city
FROM `travel-sample`.inventory.hotel h
WHERE h.city = "San Francisco"
ORDER BY h.name
LIMIT 20 OFFSET 100;
```

### Avoid Anti-Patterns

```sql
-- BAD: SELECT * (fetches all fields; prevents covering index)
SELECT * FROM bucket WHERE city = "X";

-- GOOD: Select only needed fields
SELECT name, city, rating FROM bucket WHERE city = "X";

-- BAD: LIKE with leading wildcard (no index scan possible)
SELECT * FROM bucket WHERE name LIKE "%hotel%";

-- GOOD: Use FTS for text search, or prefix LIKE
SELECT * FROM bucket WHERE name LIKE "Hotel%";

-- BAD: Functions on indexed fields (prevents index pushdown)
SELECT * FROM bucket WHERE LOWER(city) = "san francisco";

-- GOOD: Index on the expression
CREATE INDEX idx_lower_city ON bucket(LOWER(city));
SELECT * FROM bucket WHERE LOWER(city) = "san francisco";

-- BAD: Large IN lists (generates many index spans)
SELECT * FROM bucket WHERE city IN ["city1", "city2", ..., "city500"];

-- GOOD: Use JOIN with a lookup array or UNNEST
```

### Cost-Based Optimizer

```sql
-- Enable CBO by collecting statistics
UPDATE STATISTICS FOR `travel-sample`.inventory.hotel(city, country, avg_rating);

-- Verify CBO is active in EXPLAIN (look for "optimizer_estimates")
EXPLAIN SELECT ...;

-- Force index selection with USE INDEX hint
SELECT h.name FROM `travel-sample`.inventory.hotel h
USE INDEX (idx_hotel_city USING GSI)
WHERE h.city = "San Francisco";

-- Force join strategy with USE HASH or USE NL hint
SELECT h.name, a.name
FROM `travel-sample`.inventory.hotel h
JOIN `travel-sample`.inventory.airline a USE HASH(BUILD) ON ...;
```

### Transactions

```sql
-- N1QL transaction block
BEGIN WORK;

UPDATE `bucket`.`scope`.`accounts` SET balance = balance - 100 WHERE id = "acct_123";
UPDATE `bucket`.`scope`.`accounts` SET balance = balance + 100 WHERE id = "acct_456";

INSERT INTO `bucket`.`scope`.`ledger` (KEY, VALUE)
    VALUES (UUID(), {"from": "acct_123", "to": "acct_456", "amount": 100, "ts": NOW_STR()});

SAVEPOINT before_notification;

-- If notification fails, rollback to savepoint
INSERT INTO `bucket`.`scope`.`notifications` (KEY, VALUE)
    VALUES (UUID(), {"account": "acct_456", "message": "Credit received"});

COMMIT WORK;
```

## XDCR Best Practices

### Setup Guidelines

```
1. Create target bucket BEFORE setting up replication
2. Match source and target bucket type (Couchbase → Couchbase)
3. Enable compression (compressionType = Auto or Snappy)
4. Use TLS encryption for cross-DC traffic
5. For bidirectional XDCR, set up both directions explicitly
6. Use collection-aware mapping (7.0+) for granular replication
7. Test with a small dataset first; monitor lag before production
```

### Conflict Resolution

```
Sequence number (default):
  - Deterministic: highest revision count wins
  - Works well for most workloads
  - No clock synchronization required

Timestamp (LWW):
  - Requires NTP synchronization across clusters
  - More intuitive "last write wins" behavior
  - Risk of clock skew causing unexpected resolution

Custom conflict resolution (7.2+):
  - Eventing function handles merge logic
  - Most flexible but adds complexity
  - Use for: merging counters, union of arrays, domain-specific logic
```

### Monitoring XDCR Health

```bash
# Key metrics to watch
# changes_left: mutations waiting to be replicated (should trend to 0)
# docs_written: documents successfully replicated
# data_replicated: bytes replicated
# rate_replication: docs/sec
# bandwidth_usage: bytes/sec
# docs_failed_cr_source: docs that failed conflict resolution (indicates conflicts)
# xdcr_lag: end-to-end replication latency

# Check via REST
curl -s -u Administrator:password http://localhost:8091/pools/default/tasks | \
  python3 -c "import sys,json; [print(json.dumps(t,indent=2)) for t in json.load(sys.stdin) if t['type']=='xdcr']"
```

### XDCR Tuning

```
Parameter tuning for high throughput:
  sourceNozzlePerNode: 4-16 (default 2; increase for high mutation rates)
  targetNozzlePerNode: 4-16 (default 2; match source)
  optimisticReplicationThreshold: 512-2048 (default 256; increase for larger docs)
  checkpointInterval: 300-600 (default 600; lower for less data loss on failure)
  networkUsageLimit: 0 (unlimited) or set to prevent saturating WAN link
  compressionType: Auto (let system choose) or Snappy
```

## Backup and Recovery

### cbbackupmgr (Enterprise Edition)

```bash
# Configure a backup repository
cbbackupmgr config --archive /backup/couchbase --repo my-cluster \
  --include-data travel-sample.inventory

# Create a full backup
cbbackupmgr backup -c http://localhost:8091 -u Administrator -p password \
  --archive /backup/couchbase --repo my-cluster

# Create an incremental backup (automatic after first full)
cbbackupmgr backup -c http://localhost:8091 -u Administrator -p password \
  --archive /backup/couchbase --repo my-cluster

# List backups
cbbackupmgr list --archive /backup/couchbase --repo my-cluster

# Examine backup contents
cbbackupmgr examine --archive /backup/couchbase --repo my-cluster \
  --backup 2025-10-15T10_00_00 --collection travel-sample.inventory.hotel

# Restore from backup
cbbackupmgr restore -c http://localhost:8091 -u Administrator -p password \
  --archive /backup/couchbase --repo my-cluster

# Restore specific collections
cbbackupmgr restore -c http://localhost:8091 -u Administrator -p password \
  --archive /backup/couchbase --repo my-cluster \
  --include-data travel-sample.inventory.hotel

# Merge incremental backups into a single backup
cbbackupmgr merge --archive /backup/couchbase --repo my-cluster \
  --start 2025-10-01T00_00_00 --end 2025-10-15T00_00_00

# Backup to S3
cbbackupmgr config --archive s3://my-bucket/backup --repo my-cluster \
  --obj-staging-dir /tmp/staging

cbbackupmgr backup -c http://localhost:8091 -u Administrator -p password \
  --archive s3://my-bucket/backup --repo my-cluster \
  --obj-staging-dir /tmp/staging
```

### Managed Backup Service (7.0+)

```bash
# Via REST API
# Create backup plan
curl -s -u Administrator:password -X POST http://localhost:8097/api/v1/cluster/plan \
  -H "Content-Type: application/json" \
  -d '{
    "name": "daily-backup",
    "description": "Daily full backup at 2 AM",
    "tasks": [{
        "name": "daily_full",
        "task_type": "BACKUP",
        "schedule": {"job_type": "BACKUP", "frequency": 1, "period": "DAILY", "start_now": false, "start_time": "02:00"}
    }]
  }'

# Create repository
curl -s -u Administrator:password -X POST \
  http://localhost:8097/api/v1/cluster/self/repository/active \
  -H "Content-Type: application/json" \
  -d '{
    "id": "my-repo",
    "plan_name": "daily-backup",
    "archive": "/backup/couchbase",
    "bucket_name": "travel-sample"
  }'
```

### Backup Best Practices

```
1. Full backup weekly, incremental daily
2. Test restores monthly (verify backup integrity)
3. Store backups off-cluster (S3, NFS, separate storage)
4. Retain at least 7 days of backups; 30 days for compliance
5. Monitor backup duration and size trends
6. Use managed Backup Service (7.0+) for automated scheduling
7. In 8.0, use configurable retention periods for automatic pruning
```

## Security Hardening

### Authentication and Authorization

```bash
# 1. Change default admin password immediately after install
couchbase-cli reset-admin-password -c localhost:8091 --new-password <strong_password>

# 2. Create application-specific users with minimum required roles
couchbase-cli user-manage -c localhost:8091 -u Administrator -p password \
  --set --rbac-username app_read --rbac-password <pass> \
  --roles "query_select[my-bucket],data_reader[my-bucket]" \
  --auth-domain local

# 3. Separate read and write users
couchbase-cli user-manage -c localhost:8091 -u Administrator -p password \
  --set --rbac-username app_write --rbac-password <pass> \
  --roles "data_writer[my-bucket],query_insert[my-bucket],query_update[my-bucket]" \
  --auth-domain local

# 4. Configure password policy
couchbase-cli setting-password-policy -c localhost:8091 -u Administrator -p password \
  --set --min-length 12 --uppercase 1 --lowercase 1 --digit 1 --special-char 1

# 5. Enable LDAP for centralized user management
# See couchbase-cli setting-ldap examples in diagnostics reference
```

### Encryption

```bash
# Enable TLS for client-to-node communication
couchbase-cli ssl-manage -c localhost:8091 -u Administrator -p password \
  --set-client-auth mandatory --set-client-auth-type cert

# Enable node-to-node encryption
couchbase-cli node-to-node-encryption -c localhost:8091 -u Administrator -p password \
  --enable

# Set minimum TLS version
couchbase-cli setting-security -c localhost:8091 -u Administrator -p password \
  --set --tls-min-version tlsv1.2

# Enable encryption at rest (8.0 Enterprise)
couchbase-cli setting-encryption -c localhost:8091 -u Administrator -p password \
  --set --data-at-rest-encryption 1
```

### Audit

```bash
# Enable auditing
couchbase-cli setting-audit -c localhost:8091 -u Administrator -p password \
  --set-audit-enabled 1 \
  --audit-log-path /opt/couchbase/var/lib/couchbase/logs \
  --audit-log-rotate-interval 86400 \
  --audit-log-rotate-size 524288000

# Audit events are in JSON format in audit.log
# Key event IDs:
# 8192: login success
# 8193: login failure
# 8194: delete user
# 8195: create/update user
# 8257-8259: bucket operations
# 28672-28689: query events
# 32768+: data access events
```

### Network Security

```
1. Firewall rules -- Only expose required ports:
   8091 (management), 8092 (views), 8093 (query), 8094 (FTS),
   8095 (analytics), 8096 (eventing), 8097 (backup),
   11210 (KV data), 11207 (KV TLS)
   18091-18097 (TLS equivalents of management ports)

2. Inter-node ports (internal only):
   4369 (erlang), 9100-9105 (index), 9110-9122 (analytics),
   9130 (analytics), 9999 (UI), 11209 (internal KV),
   21100-21299 (node-to-node)

3. IP whitelisting -- Restrict management API access
4. VPN/private network for inter-cluster XDCR traffic
5. Disable unused services on each node
```

## Memory Tuning

### Bucket RAM Quota Guidelines

```
Value eviction formula:
  metadata_per_item = 56 + avg_key_length (bytes)
  value_per_item = avg_doc_size (bytes)
  total_metadata = item_count * metadata_per_item
  working_set_values = active_items * value_per_item
  bucket_quota = (total_metadata + working_set_values + replica_factor * total_metadata) * 1.25 (headroom)

Full eviction formula:
  resident_ratio = active_data_that_fits_in_ram / total_data
  bucket_quota = item_count * 32 (minimal metadata) + active_cache_desired
```

### Water Mark Tuning

```bash
# View current watermarks
cbstats localhost:11210 all -u Administrator -p password -b <bucket> | grep -E "ep_mem_high_wat|ep_mem_low_wat"

# High water mark: 85% of bucket quota (default)
# Low water mark: 75% of bucket quota (default)
# Eviction starts at high_wat, continues until low_wat

# For write-heavy workloads, lower the gap between high and low:
# This triggers eviction earlier and more gradually
# Adjust via internal settings (advanced)
curl -s -u Administrator:password -X POST http://localhost:8091/internalSettings \
  -d "memHighWatPct=80" -d "memLowWatPct=70"
```

## Operational Procedures

### Rolling Upgrade

```
1. Back up all buckets
2. Upgrade one node at a time:
   a. Remove node from cluster (failover or remove + rebalance)
   b. Upgrade Couchbase Server software
   c. Add node back to cluster
   d. Rebalance
3. After all nodes upgraded, enable new-version features
4. Verify all services healthy

For major version upgrades (e.g., 7.6 → 8.0):
  - Check compatibility matrix
  - Test upgrade path in staging first
  - Review deprecated features and breaking changes
  - Plan for Memcached bucket removal (removed in 8.0)
```

### Monitoring Checklist

```
Critical metrics (alert if threshold exceeded):

Memory:
  - Bucket RAM usage > 85% of quota
  - ep_num_value_ejects increasing rapidly
  - ep_bg_fetched > 0 trending up (for latency-sensitive workloads)

Disk:
  - Disk usage > 80% per node
  - ep_queue_size > 1000000 (disk write backlog)
  - Compaction not completing within maintenance window

Performance:
  - KV GET latency > 1ms (p99)
  - N1QL query latency above SLA
  - FTS query latency above SLA
  - OPS/sec at capacity ceiling

Cluster:
  - Node status != healthy
  - Rebalance failed
  - Auto-failover triggered (investigate root cause)

XDCR:
  - changes_left > 0 and not decreasing
  - xdcr_lag > acceptable threshold
  - docs_failed_cr_source increasing (conflict issues)

Index:
  - num_docs_pending > 0 and not decreasing
  - Index scans timing out
  - Index node memory > 80% quota
```

### Compaction Management

```bash
# Couchstore auto-compaction (default: 30% fragmentation)
couchbase-cli setting-compaction -c localhost:8091 -u Administrator -p password \
  --compaction-db-percentage 30 \
  --compaction-period-from 02:00 \
  --compaction-period-to 06:00 \
  --enable-compaction-abort 1

# Magma compaction is automatic and incremental
# No manual intervention typically needed
# But monitor via:
cbstats localhost:11210 all -u Administrator -p password -b <bucket> | grep -i "magma\|compact"

# View compaction settings
curl -s -u Administrator:password http://localhost:8091/settings/autoCompaction | python3 -m json.tool
```

### Expiry Pager Tuning

```bash
# The expiry pager runs periodically to clean up expired documents
# Default interval: 3600 seconds (1 hour)

# View current setting
cbstats localhost:11210 all -u Administrator -p password -b <bucket> | grep exp_pager_stime

# Adjust via bucket settings (in seconds)
# Lower values clean up expired docs faster but consume more CPU
curl -s -u Administrator:password -X POST \
  http://localhost:8091/pools/default/buckets/<bucket> \
  -d "expPagerSleeptime=600"  # 10 minutes
```

## Couchbase Mobile Best Practices

### Sync Gateway Configuration

```json
{
  "bootstrap": {
    "server": "couchbase://localhost",
    "username": "sync_gateway",
    "password": "password",
    "use_tls_server": false
  },
  "databases": {
    "travel": {
      "bucket": "travel-sample",
      "scopes": {
        "inventory": {
          "collections": {
            "hotel": {
              "sync": "function(doc, oldDoc) { channel(doc.channels); access(doc.owner, doc.channels); }",
              "import_filter": "function(doc) { return doc.type == 'hotel'; }"
            }
          }
        }
      },
      "num_index_replicas": 0,
      "enable_shared_bucket_access": true,
      "import_docs": true
    }
  }
}
```

### Channel Design

```
1. Use functional channels based on data access patterns:
   - channel("user:" + doc.owner)     -- per-user data
   - channel("team:" + doc.team_id)   -- per-team data
   - channel("public")                -- shared data

2. Avoid too many channels per document (< 50)
3. Avoid too many channels per user (< 1000)
4. Use star channel (*) sparingly (grants access to everything)
5. Consider channel limits when designing data partitioning
```

## Couchbase Capella Best Practices

```
1. Right-size clusters:
   - Start with minimum viable configuration
   - Use auto-scaling for unpredictable workloads
   - Monitor and adjust based on actual usage

2. Network security:
   - Configure allowed IP ranges
   - Use VPC peering for private connectivity
   - Enable TLS for all connections

3. Use App Services for mobile workloads:
   - Managed Sync Gateway; no infrastructure to maintain
   - Automatic scaling and HA

4. Capella Columnar for analytics:
   - Zero-ETL from operational clusters
   - Independent compute scaling
   - SQL++ compatibility

5. Backup and recovery:
   - Automatic daily backups (configurable)
   - Point-in-time recovery available
   - Cross-region backup replication for DR
```
