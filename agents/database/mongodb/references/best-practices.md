# MongoDB Best Practices Reference

## Production Deployment Checklist

### Hardware and OS

```
# System settings (Linux)

# Disable Transparent Huge Pages (THP) -- causes latency spikes with WiredTiger
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# Set readahead to 8-32 sectors for WiredTiger (default 256 is too high)
blockdev --setrahead 32 /dev/sda

# Increase file descriptor limits
# /etc/security/limits.conf
mongod soft nofile 64000
mongod hard nofile 64000
mongod soft nproc 64000
mongod hard nproc 64000

# Disable NUMA zone reclaim (causes memory allocation latency)
echo 0 > /proc/sys/vm/zone_reclaim_mode
# Or start mongod with: numactl --interleave=all mongod ...

# Use XFS filesystem (recommended over ext4 for WiredTiger)
# XFS has better performance for WiredTiger's write patterns

# Set swappiness low (avoid swapping WiredTiger cache)
echo 1 > /proc/sys/vm/swappiness

# Keep-alive settings for replica set and sharded cluster communication
echo 300 > /proc/sys/net/ipv4/tcp_keepalive_time
```

### Storage

**Requirements:**
- Use SSDs (NVMe preferred) for WiredTiger data files. Spinning disks cause checkpoint I/O bottlenecks.
- Separate disks for data, journal, and log if possible (reduces I/O contention)
- Use XFS filesystem. ext4 is acceptable but XFS has better allocation patterns for MongoDB.
- Provision IOPS: plan for peak checkpoint bursts (every 60 seconds), not just average write rate
- RAID 10 for self-managed deployments (RAID 5/6 write penalty is too high for MongoDB's checkpoint pattern)

**Disk layout example:**
```yaml
# mongod.conf
storage:
  dbPath: /data/db          # SSD or NVMe -- primary data files
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      journalCompressor: snappy
      cacheSizeGB: 8        # Set explicitly; don't rely on default
    collectionConfig:
      blockCompressor: zstd  # Best compression/speed ratio (4.2+)
systemLog:
  path: /var/log/mongodb/mongod.log   # Separate disk or lower-tier storage
  logAppend: true
  logRotate: reopen         # Use logRotate with SIGUSR1
```

### Memory Sizing

**Rule of thumb for WiredTiger cache:**
```
cacheSizeGB = min(totalRAM * 0.5, totalRAM - 4GB)
```

Reserve at least:
- 1-2GB for OS and mongod overhead
- ~1MB per connection (connections * 1MB)
- Remaining RAM for OS filesystem cache (compressed WiredTiger pages)

**Example (64GB server, 500 max connections):**
```
WiredTiger cache: 28GB
Connection overhead: ~500MB
OS and mongod: 2GB
Filesystem cache: ~33.5GB (caches compressed pages, boosting effective memory)
```

**Working set guidance:**
- If the working set (frequently accessed data + indexes) fits in the WiredTiger cache, reads are served from memory
- If the working set exceeds the cache, WiredTiger evicts pages and reads from disk (via OS cache)
- Monitor `wiredTiger.cache.bytes currently in the cache` vs. `wiredTiger.cache.maximum bytes configured`
- Monitor `wiredTiger.cache.pages evicted by application threads` -- non-zero indicates cache pressure

## Replica Set Configuration

### Sizing Guidelines

| Deployment | Members | Notes |
|---|---|---|
| Minimum production | 3 data-bearing | Survives loss of 1 member |
| Standard HA | 3 data-bearing + 1 hidden (backup/analytics) | Dedicated member for backups or read workloads |
| Cross-datacenter | 3 data-bearing (2 in primary DC, 1 in DR DC) | DR member with `priority: 0` to prevent it from becoming primary |
| Multi-region | 5 data-bearing (2+2+1) | Survives loss of entire datacenter; higher write latency for `w: "majority"` |
| Read-heavy | 3+ data-bearing + read-only secondaries | Use read preference `secondaryPreferred` |

**Never use an even number of voting members.** Arbiters are acceptable only to break a tie with 2 data-bearing members (PSA topology). The PSA topology has significant drawbacks:
- With the arbiter, you have only one copy of the data when a data-bearing member is down
- `w: "majority"` with 3 voting members requires 2 acknowledgments; if one data member is down, the remaining data member IS the majority, but you have no redundancy
- Prefer 3 data-bearing members over PSA

### Replica Set Configuration Template

```javascript
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo1:27017", priority: 2 },      // Preferred primary
    { _id: 1, host: "mongo2:27017", priority: 1 },      // Standard secondary
    { _id: 2, host: "mongo3:27017", priority: 1 },      // Standard secondary
    { _id: 3, host: "mongo4:27017", priority: 0, hidden: true, tags: { role: "backup" } }  // Backup member
  ],
  settings: {
    chainingAllowed: true,         // Secondaries can replicate from other secondaries
    heartbeatTimeoutSecs: 10,      // Heartbeat failure detection
    electionTimeoutMillis: 10000,  // Time before starting election
    getLastErrorModes: {           // Custom write concerns
      twoDataCenters: { dc: 2 }   // Write must reach 2 data centers
    }
  }
})
```

### Read Preference Guidance

| Read Preference | Use When | Risk |
|---|---|---|
| `primary` | Strong consistency required (default) | Single point of failure for reads |
| `primaryPreferred` | Tolerate stale reads during failover | Brief stale reads during election |
| `secondary` | Offload reads from primary, stale data acceptable | Reads may be seconds behind primary |
| `secondaryPreferred` | Prefer secondary for reads, fall back to primary | Stale reads unless primary is the only member |
| `nearest` | Minimize read latency (multi-region) | May read from any member regardless of staleness |

**Important:** Reading from secondaries does NOT increase total read throughput if the application requires consistent reads. It only helps for workloads that tolerate eventual consistency.

## Shard Key Selection

### Decision Framework

```
Step 1: Identify your most common query patterns
  → What fields appear in WHERE clauses / find() filters?

Step 2: Check cardinality
  → Does the candidate field have many distinct values?
  → Boolean/enum fields: NO (low cardinality = jumbo chunks)
  → UUID/ObjectId/email: YES

Step 3: Check write distribution
  → Will writes spread evenly across shard key values?
  → Monotonically increasing (timestamp, auto-increment): NO → hot shard
  → Hash of high-cardinality field: YES

Step 4: Check query isolation
  → Can most queries include the shard key? (targeted vs. scatter-gather)
  → If shard key is rarely in queries: poor choice

Step 5: Decide on hashed vs. ranged
  → Hashed: even distribution, but scatter-gather for range queries
  → Ranged: targeted range queries, but risk of hot spots
  → Compound: combine a distributed field with a query field
```

### Shard Key Examples by Workload

**Multi-tenant SaaS application:**
```javascript
// Shard key: { tenant_id: 1, _id: 1 }
// Why: All queries include tenant_id (targeted); _id adds cardinality
sh.shardCollection("saas.events", { tenant_id: 1, _id: 1 })
```

**IoT time-series telemetry:**
```javascript
// Shard key: { device_id: "hashed" }
// Why: Distributes writes across shards; queries by device_id are targeted
sh.shardCollection("iot.readings", { device_id: "hashed" })

// Alternative if range queries on time are needed:
// { device_id: 1, timestamp: 1 } -- but beware of hot chunks for active devices
```

**E-commerce orders:**
```javascript
// Shard key: { customer_id: "hashed" }
// Why: Even write distribution; customer lookups are targeted
sh.shardCollection("ecommerce.orders", { customer_id: "hashed" })
```

**Log analytics:**
```javascript
// Shard key: { app_name: 1, timestamp: 1 }
// Why: Queries always filter by app; timestamp enables range queries within an app
sh.shardCollection("logs.entries", { app_name: 1, timestamp: 1 })
```

### Shard Key Anti-Patterns

| Anti-Pattern | Problem | Better Alternative |
|---|---|---|
| `{ _id: 1 }` (ObjectId, ranged) | Monotonic; all inserts go to one shard | `{ _id: "hashed" }` |
| `{ created_at: 1 }` | Monotonic timestamp; hot shard | `{ user_id: 1, created_at: 1 }` or hashed |
| `{ status: 1 }` | Low cardinality; jumbo chunks | Combine with high-cardinality field |
| `{ country: 1 }` | Skewed distribution (90% of data in 5 countries) | `{ country: 1, _id: 1 }` or hashed |

## Security Hardening

### Authentication Configuration

```yaml
# mongod.conf
security:
  authorization: enabled          # Enforce RBAC
  keyFile: /etc/mongodb/keyfile   # Internal auth for replica set members
  # OR for x.509 member auth:
  # clusterAuthMode: x509

net:
  tls:
    mode: requireTLS              # Enforce TLS for all connections
    certificateKeyFile: /etc/ssl/mongodb.pem
    CAFile: /etc/ssl/ca.pem
    allowConnectionsWithoutCertificates: false  # Require client certs
```

### Minimal Privilege Setup

```javascript
// 1. Create the admin user first (before enabling auth)
use admin
db.createUser({
  user: "admin",
  pwd: passwordPrompt(),
  roles: [{ role: "userAdminAnyDatabase", db: "admin" }]
})

// 2. Create application user with minimal privileges
use myapp
db.createUser({
  user: "app_service",
  pwd: passwordPrompt(),
  roles: [{ role: "readWrite", db: "myapp" }]
})

// 3. Create monitoring user
use admin
db.createUser({
  user: "monitor",
  pwd: passwordPrompt(),
  roles: [
    { role: "clusterMonitor", db: "admin" },
    { role: "read", db: "local" }  // For oplog access
  ]
})

// 4. Create backup user
use admin
db.createUser({
  user: "backup_agent",
  pwd: passwordPrompt(),
  roles: [
    { role: "backup", db: "admin" },
    { role: "restore", db: "admin" }
  ]
})
```

### Network Hardening

```yaml
# mongod.conf
net:
  port: 27017
  bindIp: 10.0.1.5               # Bind only to private IP (NOT 0.0.0.0)
  maxIncomingConnections: 5000    # Limit connection count

  tls:
    mode: requireTLS
    certificateKeyFile: /etc/ssl/mongodb.pem
    CAFile: /etc/ssl/ca.pem
```

Additional network security:
- Use firewall rules to restrict port 27017 to application servers and replica set members only
- Use VPN or VPC peering for cross-datacenter replication
- Never expose MongoDB to the public internet
- Disable HTTP interface and REST API (deprecated and removed in 3.6+)
- Use SCRAM-SHA-256 (not SCRAM-SHA-1) for authentication

### Auditing (Enterprise)

```yaml
# mongod.conf (Enterprise only)
auditLog:
  destination: file
  format: JSON
  path: /var/log/mongodb/audit.json
  filter: '{ atype: { $in: ["authenticate", "createUser", "dropUser", "createRole", "dropRole", "createDatabase", "dropDatabase", "createCollection", "dropCollection"] } }'
```

### JSON Schema Validation

Enforce document structure at the database level:

```javascript
db.createCollection("users", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["email", "name", "created_at"],
      properties: {
        email: {
          bsonType: "string",
          pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
          description: "Must be a valid email address"
        },
        name: {
          bsonType: "string",
          minLength: 1,
          maxLength: 200
        },
        age: {
          bsonType: "int",
          minimum: 0,
          maximum: 150
        },
        created_at: {
          bsonType: "date"
        },
        roles: {
          bsonType: "array",
          items: { bsonType: "string", enum: ["admin", "editor", "viewer"] }
        }
      },
      additionalProperties: false
    }
  },
  validationLevel: "strict",       // "strict" or "moderate" (moderate skips existing invalid docs)
  validationAction: "error"        // "error" or "warn" (warn logs but allows)
})
```

## Backup Strategies

### mongodump / mongorestore

Best for: Small-medium databases (< 100GB), selective collection backup/restore.

```bash
# Full backup with oplog for point-in-time consistency
mongodump --uri="mongodb://backup:pass@rs0-primary:27017/admin?replicaSet=rs0" \
  --oplog --gzip --out /backup/$(date +%Y%m%d_%H%M%S)

# Backup specific database
mongodump --db myapp --gzip --archive=/backup/myapp_$(date +%Y%m%d).gz

# Backup specific collection
mongodump --db myapp --collection orders \
  --query='{ "created_at": { "$gte": { "$date": "2025-01-01T00:00:00Z" } } }' \
  --gzip --out /backup/orders_partial

# Restore with oplog replay (point-in-time)
mongorestore --uri="mongodb://admin:pass@rs0-primary:27017/admin?replicaSet=rs0" \
  --oplogReplay --gzip /backup/20250315_120000

# Restore specific collection
mongorestore --db myapp --collection orders \
  --gzip /backup/20250315_120000/myapp/orders.bson.gz

# Restore with drop (replace existing)
mongorestore --drop --gzip /backup/20250315_120000
```

**Limitations:**
- Slow for large databases (not parallelized within a collection)
- Not a consistent snapshot unless `--oplog` is used
- `--oplog` requires access to the oplog (replica set member)
- Does not back up indexes separately (they are rebuilt during restore)

### Filesystem Snapshots

Best for: Large databases where mongodump is too slow.

```bash
# Step 1: Ensure journaling is enabled (default since 2.6)
# Step 2: Lock the database to ensure consistency
mongosh --eval 'db.fsyncLock()'

# Step 3: Take filesystem snapshot (LVM, EBS, ZFS, etc.)
lvcreate --size 100G --snapshot --name mongosnapshot /dev/vg0/mongodata

# Step 4: Unlock the database
mongosh --eval 'db.fsyncUnlock()'

# Step 5: Mount snapshot and copy
mkdir /mnt/mongosnapshot
mount /dev/vg0/mongosnapshot /mnt/mongosnapshot
rsync -a /mnt/mongosnapshot/ /backup/snapshot_$(date +%Y%m%d)/
umount /mnt/mongosnapshot
lvremove /dev/vg0/mongosnapshot
```

**For replica sets without locking:** Take the snapshot on a secondary that has been stepped down or isolated. This avoids locking the primary.

**For sharded clusters:** Use `db.fsyncLock()` on every shard and the config server, take snapshots, then unlock. Alternatively, stop the balancer first (`sh.stopBalancer()`) and take consistent snapshots while no migrations are in progress.

### Atlas Continuous Backup

Atlas provides fully managed backups:
- Continuous backups with oplog capture
- Point-in-time restore with 1-second granularity
- Configurable retention (days, weeks, months)
- Cross-region snapshot copy
- Queryable backup (Atlas only) -- query backup snapshots without restoring

```bash
# Atlas CLI: list backup snapshots
atlas backups snapshots list --clusterName myCluster --projectId <projectId>

# Restore from snapshot
atlas backups restores start --clusterName myCluster \
  --snapshotId <snapshotId> --targetClusterName myCluster-restored
```

## Monitoring Setup

### Key Metrics to Monitor

**Category: Throughput**

| Metric | Source | Warning Threshold | Critical Threshold |
|---|---|---|---|
| Operations/sec (insert, query, update, delete, getmore, command) | `db.serverStatus().opcounters` | Sudden drop > 50% | Drop to 0 |
| Connections current | `db.serverStatus().connections.current` | > 80% of maxIncomingConnections | > 95% |
| Connections available | `db.serverStatus().connections.available` | < 20% of max | < 5% |

**Category: Latency**

| Metric | Source | Warning | Critical |
|---|---|---|---|
| Read latency (average) | `db.serverStatus().opLatencies.reads` | > 10ms | > 50ms |
| Write latency (average) | `db.serverStatus().opLatencies.writes` | > 10ms | > 50ms |
| Command latency | `db.serverStatus().opLatencies.commands` | > 50ms | > 200ms |
| Network bytes in/out | `db.serverStatus().network` | Sustained near NIC capacity | Saturated |

**Category: Replication**

| Metric | Source | Warning | Critical |
|---|---|---|---|
| Replication lag (seconds) | `rs.printSecondaryReplicationInfo()` | > 10s | > 60s |
| Oplog window (hours) | `rs.printReplicationInfo()` | < 24h | < 8h |
| Member state | `rs.status()` | RECOVERING, STARTUP2 | DOWN, REMOVED |

**Category: Storage**

| Metric | Source | Warning | Critical |
|---|---|---|---|
| Disk space used % | OS metrics | > 75% | > 90% |
| WiredTiger cache usage % | `db.serverStatus().wiredTiger.cache` | > 80% | > 95% |
| WiredTiger dirty cache % | `wiredTiger.cache.tracked dirty bytes in the cache` / `maximum bytes configured` | > 10% | > 20% |
| Page evictions by app threads | `wiredTiger.cache.pages evicted by application threads` | > 0 sustained | > 100/s |

**Category: Cursors and Operations**

| Metric | Source | Warning | Critical |
|---|---|---|---|
| Open cursors | `db.serverStatus().metrics.cursor.open.total` | > 1000 | > 10000 |
| Cursors timed out | `db.serverStatus().metrics.cursor.timedOut` | Increasing | Rapidly increasing |
| Active operations | `db.currentOp({ active: true }).inprog.length` | > 100 | > 500 |

### Prometheus / Grafana Integration

Use `mongodb_exporter` for Prometheus metrics:

```yaml
# docker-compose.yml snippet for mongodb_exporter
mongodb-exporter:
  image: percona/mongodb_exporter:0.40
  environment:
    MONGODB_URI: "mongodb://monitor:password@mongo1:27017/admin?replicaSet=rs0"
  ports:
    - "9216:9216"
  command:
    - "--collect-all"
    - "--compatible-mode"
```

Key Prometheus metrics to alert on:
```yaml
# prometheus/alerts.yml
groups:
  - name: mongodb
    rules:
      - alert: MongoDBReplicationLag
        expr: mongodb_rs_members_optimeDate{member_state="SECONDARY"} - on() group_left mongodb_rs_members_optimeDate{member_state="PRIMARY"} > 30
        for: 5m
        labels:
          severity: warning

      - alert: MongoDBConnectionsHigh
        expr: mongodb_ss_connections{conn_type="current"} / mongodb_ss_connections{conn_type="available"} > 0.8
        for: 5m
        labels:
          severity: warning

      - alert: MongoDBWiredTigerCachePressure
        expr: mongodb_ss_wt_cache_bytes_currently_in_the_cache / mongodb_ss_wt_cache_maximum_bytes_configured > 0.95
        for: 5m
        labels:
          severity: critical
```

## Capacity Planning

### Sizing Calculator

```
Data size estimation:
  Average document size (bytes) * Document count = Raw data size
  Raw data size / compression_ratio (~2-3x for snappy, ~3-5x for zstd) = On-disk data size
  On-disk data size * index_overhead_factor (~0.2-0.5x of data size) = Total disk requirement
  Add 30% headroom for growth

Memory estimation:
  Working set = frequently accessed data + all indexes
  WiredTiger cache should hold >= working set
  Total RAM = WiredTiger cache + OS cache + connection overhead + OS overhead

  Rules:
  - 50% of RAM for WiredTiger cache (default)
  - If working set < 50% RAM: comfortable
  - If working set > 80% RAM: add RAM or shard to distribute
```

### When to Shard

Consider sharding when:
1. **Storage:** Single server cannot hold all data (approaching disk capacity)
2. **Write throughput:** Single replica set primary cannot handle write volume
3. **Read throughput:** Read demand exceeds what a replica set can serve (even with secondary reads)
4. **Working set:** Working set exceeds available RAM across the replica set

**Do NOT shard prematurely.** A single replica set is simpler to operate and performs well up to:
- ~1TB data (depending on working set)
- ~50,000 ops/sec (depending on document size and complexity)
- Start with a replica set and only shard when you hit a concrete bottleneck

## Schema Migration Strategies

### Adding Fields

```javascript
// Lazy migration: add default value in application code
// New documents get the field; old documents are updated on next write

// Bulk migration: update all documents
db.users.updateMany(
  { new_field: { $exists: false } },
  { $set: { new_field: "default_value" } }
)
// Run in batches to avoid lock contention:
let batch = [];
db.users.find({ new_field: { $exists: false } }).limit(1000).forEach(doc => {
  batch.push({ updateOne: { filter: { _id: doc._id }, update: { $set: { new_field: "default_value" } } } });
  if (batch.length >= 500) {
    db.users.bulkWrite(batch);
    batch = [];
  }
});
if (batch.length > 0) db.users.bulkWrite(batch);
```

### Removing Fields

```javascript
// Batch unset
db.users.updateMany(
  { deprecated_field: { $exists: true } },
  { $unset: { deprecated_field: "" } }
)
```

### Renaming Fields

```javascript
// Atomic rename
db.users.updateMany(
  { old_name: { $exists: true } },
  { $rename: { "old_name": "new_name" } }
)
```

### Restructuring Documents

```javascript
// Move embedded data to a new collection (one-time migration)
db.orders.find().forEach(order => {
  order.items.forEach(item => {
    db.order_items.insertOne({
      order_id: order._id,
      ...item
    });
  });
  db.orders.updateOne(
    { _id: order._id },
    { $unset: { items: "" }, $set: { migrated: true } }
  );
});
```

### Zero-Downtime Migration Pattern

1. **Dual-write:** Application writes to both old and new schemas
2. **Backfill:** Migrate existing documents in batches
3. **Verify:** Confirm all documents are migrated
4. **Switch reads:** Application reads from new schema
5. **Remove dual-write:** Application writes only to new schema
6. **Clean up:** Remove old fields/collections

## Index Management

### Index Build Best Practices

```javascript
// Background index builds (default since 4.2; all builds are "background")
db.orders.createIndex(
  { customer_id: 1, order_date: -1 },
  { name: "idx_customer_date", background: true }  // background is default in 4.2+
)

// Partial index (index only active orders)
db.orders.createIndex(
  { customer_id: 1 },
  { partialFilterExpression: { status: "active" }, name: "idx_active_customers" }
)

// TTL index (auto-delete documents after 30 days)
db.sessions.createIndex(
  { created_at: 1 },
  { expireAfterSeconds: 2592000, name: "idx_session_ttl" }
)

// Hidden index (test removal impact before dropping)
db.orders.hideIndex("idx_rarely_used")
// Monitor for performance regression, then:
db.orders.dropIndex("idx_rarely_used")
// Or unhide if queries regressed:
db.orders.unhideIndex("idx_rarely_used")
```

### Index Maintenance

```javascript
// Find unused indexes (check over a full business cycle)
db.orders.aggregate([{ $indexStats: {} }]).forEach(idx => {
  if (idx.accesses.ops === 0) {
    print(`Unused index: ${idx.name} on ${idx.host}`)
  }
})

// Find duplicate/redundant indexes
// A compound index { a: 1, b: 1 } makes { a: 1 } redundant
db.orders.getIndexes().forEach(idx => {
  print(`${idx.name}: ${JSON.stringify(idx.key)}`)
})

// Rebuild indexes (rarely needed; use only after significant document deletions)
db.orders.reIndex()  // Takes exclusive lock; prefer rolling rebuild on replica set
```

## Connection String Best Practices

### Replica Set Connection String

```
mongodb://user:password@host1:27017,host2:27017,host3:27017/mydb?replicaSet=rs0&w=majority&readPreference=primaryPreferred&retryWrites=true&retryReads=true&maxPoolSize=100&minPoolSize=10&maxIdleTimeMS=30000&connectTimeoutMS=10000&serverSelectionTimeoutMS=15000&compressors=snappy,zstd
```

### Sharded Cluster Connection String

```
mongodb://user:password@mongos1:27017,mongos2:27017/mydb?w=majority&readPreference=primaryPreferred&retryWrites=true&retryReads=true&maxPoolSize=100
```

### Key Connection Options

| Option | Default | Recommendation | Why |
|---|---|---|---|
| `w` | 1 | `"majority"` | Durable writes; prevents data loss on primary failure |
| `readPreference` | `primary` | `primaryPreferred` or `secondaryPreferred` | Read availability during failover |
| `retryWrites` | true | true | Automatic retry on transient errors |
| `retryReads` | true | true | Automatic retry on transient errors |
| `maxPoolSize` | 100 | 50-200 | Adjust based on application concurrency |
| `minPoolSize` | 0 | 5-20 | Keep warm connections to avoid latency on first request |
| `maxIdleTimeMS` | 0 (infinite) | 30000-60000 | Close idle connections behind load balancers |
| `compressors` | none | `snappy,zstd` | Reduce network bandwidth (especially cross-datacenter) |
| `connectTimeoutMS` | 10000 | 10000 | Time to establish TCP connection |
| `serverSelectionTimeoutMS` | 30000 | 15000 | Time to select a suitable server |
| `socketTimeoutMS` | 0 (infinite) | 0 | Let the server handle timeouts, not the driver |
| `heartbeatFrequencyMS` | 10000 | 10000 | How often the driver checks server status |

## Log Management

### Structured Logging (4.4+)

MongoDB 4.4+ outputs logs in JSON format by default:

```yaml
# mongod.conf
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
  logRotate: reopen              # Use external logrotate with SIGUSR1

# Component-specific log verbosity
setParameter:
  logComponentVerbosity: '{
    "accessControl": { "verbosity": 1 },
    "command": { "verbosity": 0 },
    "storage": { "verbosity": 0 },
    "replication": { "verbosity": 1 },
    "query": { "verbosity": 0 },
    "write": { "verbosity": 0 }
  }'
```

### Log Rotation

```bash
# Using logrotate (Linux)
# /etc/logrotate.d/mongodb
/var/log/mongodb/mongod.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    missingok
    postrotate
        /bin/kill -SIGUSR1 $(cat /var/run/mongodb/mongod.pid)
    endscript
}

# Manual rotation via mongosh
db.adminCommand({ logRotate: 1 })
```
