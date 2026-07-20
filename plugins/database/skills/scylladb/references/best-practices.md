# ScyllaDB Best Practices Reference

## Hardware Selection

### Bare Metal (Recommended for Best Performance)

ScyllaDB performs best on bare metal where it can fully control CPU affinity, NIC queues, and I/O scheduling:

| Component | Minimum | Recommended | Notes |
|---|---|---|---|
| CPU | 8 cores | 16-32+ cores | More cores = more shards = linear scaling |
| RAM | 16 GB | 64-256 GB | ScyllaDB uses all available RAM for cache |
| Storage | NVMe SSD | NVMe SSD (multiple) | Avoid SATA SSD, never use HDD |
| Network | 10 Gbps | 25 Gbps+ | High throughput needed for streaming/repair |
| Disk per shard | 250 GB | 500 GB-1 TB | Target 50-70% utilization for compaction headroom |

**Storage rules:**
- NVMe is strongly preferred -- direct I/O with userspace scheduling works best with NVMe
- Use XFS filesystem (default, tested extensively)
- No JBOD -- ScyllaDB uses RAID-0 across drives (or assigns drives to shards)
- Reserve 30-50% disk space for compaction temporary files
- Separate commitlog directory is optional but recommended for write-heavy workloads

### Cloud Instance Selection

**AWS:**
| Instance | vCPU | RAM | Storage | Use Case |
|---|---|---|---|---|
| i3.xlarge | 4 | 30 GB | 1x 950 GB NVMe | Development, small production |
| i3.2xlarge | 8 | 61 GB | 1x 1.9 TB NVMe | Medium production |
| i3.4xlarge | 16 | 122 GB | 2x 1.9 TB NVMe | Large production |
| i3.8xlarge | 32 | 244 GB | 4x 1.9 TB NVMe | Heavy production |
| i3.16xlarge | 64 | 488 GB | 8x 1.9 TB NVMe | Maximum throughput |
| i4i.xlarge-16xlarge | 4-64 | 32-512 GB | NVMe | Latest gen, better price/perf |
| im4gn (Graviton) | 4-16 | 32-128 GB | NVMe | ARM-based, good price/perf |

**GCP:**
- n2-highmem series with local SSD
- c3d series for compute-heavy workloads

**Azure:**
- Lsv3 / Lasv3 series (local NVMe)

### Instance Sizing Formula

```
Shards per node = vCPU count (e.g., 16 vCPUs = 16 shards)
RAM per shard = Total RAM / vCPU count (e.g., 122 GB / 16 = ~7.6 GB per shard)
Disk per shard = Total disk / vCPU count
```

**Rule of thumb:** Each shard handles ~12.5K-50K operations per second depending on data size, consistency level, and whether reads hit cache or disk.

## Cluster Sizing

### Capacity Planning Formula

```
Required nodes = max(
    ceil(Total data / (Usable disk per node * 0.6)),    -- disk capacity
    ceil(Peak ops/sec / (Ops per node)),                  -- throughput
    3                                                      -- minimum for RF=3
)

Where:
- Usable disk per node = Total disk * 0.6 (reserve 40% for compaction)
- Ops per node = depends on workload (benchmark with cassandra-stress or scylla-bench)
- 0.6 = compaction headroom factor
```

**Example:**
- 2 TB raw data, RF=3, 6 TB total replicated
- i3.4xlarge: 3.8 TB usable disk, 60% = 2.28 TB usable
- Disk: ceil(6 TB / 2.28 TB) = 3 nodes minimum
- Throughput: 200K reads/s target, each i3.4xlarge handles ~80K reads/s = 3 nodes
- Result: 3 nodes (matches RF=3 minimum)

### Cluster Topology Guidelines

- **Minimum 3 nodes** for RF=3 (standard production)
- **Multi-DC:** 3+ nodes per datacenter, RF=3 per DC
- **Multi-rack:** Distribute nodes across 3+ racks per DC
- **Odd numbers preferred** when using quorum (simplifies math)
- **Separate seed nodes** -- designate 2-3 seeds per DC, never all nodes

### When to Scale

- **CPU per shard > 80%** sustained -- add nodes
- **Disk > 70% full** -- add nodes or increase storage
- **Compaction falling behind** -- add nodes (more shards for parallel compaction)
- **p99 latency consistently above SLA** -- investigate before scaling (may be data model issue)

## scylla.yaml Configuration Guide

### Essential Parameters

```yaml
# Cluster identity
cluster_name: 'production_cluster'
num_tokens: 256

# Network
listen_address: 10.0.1.1           # IP for inter-node communication
rpc_address: 10.0.1.1              # IP for CQL client connections
broadcast_address: 10.0.1.1        # IP other nodes use to reach this node (if NAT)
broadcast_rpc_address: 10.0.1.1    # IP clients use to reach this node (if NAT)

# Seeds
seed_provider:
  - class_name: org.apache.cassandra.locator.SimpleSeedProvider
    parameters:
      - seeds: "10.0.1.1,10.0.1.2,10.0.1.3"

# Snitch
endpoint_snitch: GossipingPropertyFileSnitch

# Ports
native_transport_port: 9042         # CQL port
storage_port: 7000                   # Inter-node port
ssl_storage_port: 7001               # Inter-node encrypted port
api_port: 10000                      # REST API port
prometheus_port: 9180                # Prometheus metrics port

# Storage
data_file_directories:
  - /var/lib/scylla/data
commitlog_directory: /var/lib/scylla/commitlog

# Performance (usually auto-tuned, override only if needed)
developer_mode: false               # NEVER true in production
```

### Tablets Configuration (2025.1+)

```yaml
# Enable tablets for new keyspaces (default in 2025.1+)
tablets_mode_for_new_keyspaces: enabled

# Experimental features (enable with caution)
# experimental_features:
#   - tablets   # If not yet default in your version
```

### Commitlog Configuration

```yaml
commitlog_sync: periodic             # periodic (default) or batch
commitlog_sync_period_in_ms: 10000   # sync interval for periodic mode
commitlog_segment_size_in_mb: 64     # segment size
commitlog_total_space_in_mb: -1      # auto-calculated
```

**Guidance:**
- `periodic` (default) -- Best throughput. Risk: up to 10 seconds of data loss on crash.
- `batch` -- Syncs after every write batch. Use for financial/transactional data. 10-50% throughput reduction.

### Compaction Configuration

```yaml
# Throughput limit (MB/s per shard, 0 = unlimited)
compaction_throughput_mb_per_sec: 0

# Large data warnings
compaction_large_partition_warning_threshold_mb: 100
compaction_large_row_warning_threshold_mb: 10
compaction_large_cell_warning_threshold_mb: 1

# Concurrent compaction and flush operations
# Auto-tuned based on I/O capacity -- rarely need override
```

### Hinted Handoff Configuration

```yaml
hinted_handoff_enabled: true
max_hint_window_in_ms: 10800000      # 3 hours (default)
hints_flush_period_in_ms: 10000      # 10 seconds
max_hints_delivery_threads: 2
```

### Tombstone Configuration

```yaml
tombstone_warn_threshold: 1000       # warn when scanning > 1000 tombstones
tombstone_failure_threshold: 100000  # fail query when scanning > 100000 tombstones
```

### Authentication and Authorization

```yaml
authenticator: PasswordAuthenticator   # or AllowAllAuthenticator
authorizer: CassandraAuthorizer        # or AllowAllAuthorizer
```

### Client Encryption

```yaml
client_encryption_options:
    enabled: true
    certificate: /etc/scylla/db.crt
    keyfile: /etc/scylla/db.key
    truststore: /etc/scylla/ca.crt
    require_client_auth: false          # true for mTLS
```

### Inter-Node Encryption

```yaml
server_encryption_options:
    internode_encryption: all            # none, dc, rack, all
    certificate: /etc/scylla/db.crt
    keyfile: /etc/scylla/db.key
    truststore: /etc/scylla/ca.crt
```

### Alternator Configuration

```yaml
alternator_port: 8000
alternator_https_port: 8043
alternator_address: 0.0.0.0
alternator_write_isolation: always_use_lwt   # or forbid, only_rmw_uses_lwt
alternator_enforce_authorization: false       # true for Alternator RBAC
```

### Failure Detection

```yaml
phi_convict_threshold: 8               # increase to 10-12 for cross-DC
```

### Streaming

```yaml
stream_throughput_outbound_megabits_per_sec: 400
```

### Miscellaneous

```yaml
# Enable audit log (2025.1+)
audit: table                           # none, table, syslog
audit_categories: AUTH,DDL,DML,DCL

# Enable CDC (Change Data Capture)
# Enabled per-table via CQL:
# ALTER TABLE my_table WITH cdc = {'enabled': true};
```

## Data Modeling Best Practices

### Partition Key Design

**Rules:**
1. **High cardinality** -- Ensure millions+ of unique partition key values
2. **Even distribution** -- Avoid keys that create hotspots (e.g., status, region)
3. **Bounded size** -- Partition should not grow indefinitely. Target < 100MB, < 100K rows.
4. **Query-driven** -- The partition key must satisfy the WHERE clause of your primary query

**Good patterns:**
```cql
-- Time-bucketed: user + day ensures bounded partitions
PRIMARY KEY ((user_id, day), event_time)

-- Composite: tenant + shard provides distribution + isolation
PRIMARY KEY ((tenant_id, shard_id), created_at)

-- UUID: guaranteed high cardinality
PRIMARY KEY (order_id)
```

**Bad patterns:**
```cql
-- Low cardinality: creates hot partitions
PRIMARY KEY (country)

-- Unbounded: grows forever
PRIMARY KEY (user_id)  -- with millions of events per user

-- Sequential: creates a hot node
PRIMARY KEY (auto_increment_id)
```

### Clustering Column Design

- Define sort order for range queries within a partition
- Use `CLUSTERING ORDER BY (col DESC)` for "latest first" access
- Multi-column clustering allows hierarchical sorting
- Clustering columns are part of the primary key but not the partition key

### Denormalization Patterns

**Write-time join (recommended):**
```cql
-- Base table: orders by customer
CREATE TABLE orders_by_customer (
    customer_id uuid,
    order_date date,
    order_id uuid,
    total decimal,
    PRIMARY KEY ((customer_id), order_date, order_id)
) WITH CLUSTERING ORDER BY (order_date DESC, order_id ASC);

-- Denormalized table: orders by status for dashboard
CREATE TABLE orders_by_status (
    status text,
    day date,
    order_id uuid,
    customer_id uuid,
    total decimal,
    PRIMARY KEY ((status, day), order_id)
);

-- Application writes to BOTH tables in a batch (same partition optimization where possible)
```

### Collections Usage

```cql
-- Sets: for tags, categories (unordered, unique)
tags set<text>

-- Lists: for ordered sequences (careful: updates are expensive)
history list<text>

-- Maps: for key-value metadata
properties map<text, text>

-- Frozen collections: stored as a blob, compared atomically
frozen<map<text, text>>
```

**Guidance:**
- Collections should be small (< 64KB unfrozen, < 256KB frozen)
- Do not use collections as a substitute for clustering columns
- Frozen collections cannot be partially updated

### Anti-Patterns to Avoid

1. **ALLOW FILTERING in production** -- Forces full cluster scan. Design a table for the query instead.
2. **Lightweight transactions for every write** -- LWTs are 4x latency. Use only for uniqueness constraints.
3. **Wide partitions without bucketing** -- Every time-series table needs time-bucketing.
4. **SELECT * with no LIMIT** -- Always specify LIMIT or use paging.
5. **Scatter-gather queries** -- Queries without the full partition key hit all nodes.
6. **Materialized views for critical paths** -- Use client-side denormalization instead.
7. **IN clause with many values** -- `IN (val1, val2, ..., val100)` on partition key creates 100 parallel queries. Use async individual queries instead.
8. **Batch for performance** -- Batches are for atomicity, not throughput. Use async parallel writes.

## Compaction Strategy Selection Guide

### Decision Tree

```
Is the data time-series with TTL?
  YES --> TWCS (Time Window Compaction Strategy)
  NO  --> Continue

Is the workload read-heavy with frequent updates to the same rows?
  YES --> LCS (Leveled Compaction Strategy)
  NO  --> Continue

Is the workload write-heavy or mixed?
  YES --> ICS (Incremental Compaction Strategy)
  NO  --> ICS (default choice for ScyllaDB)
```

### TWCS Configuration

```cql
ALTER TABLE my_ks.timeseries WITH compaction = {
    'class': 'TimeWindowCompactionStrategy',
    'compaction_window_size': 1,
    'compaction_window_unit': 'HOURS',     -- MINUTES, HOURS, DAYS
    'timestamp_resolution': 'MICROSECONDS'
};
```

**TWCS rules:**
- Set `default_time_to_live` on the table
- All data in a table must have the same TTL (or close to it)
- Never update data across time windows
- Never delete individual rows (let TTL handle it)
- Window size should match TTL granularity

### ICS Configuration

```cql
ALTER TABLE my_ks.general WITH compaction = {
    'class': 'IncrementalCompactionStrategy',
    'sstable_size_in_mb': 1024,        -- fragment size (default 1GB)
    'bucket_high': 1.5,
    'bucket_low': 0.5,
    'min_threshold': 4                  -- min SSTables to trigger compaction
};
```

### LCS Configuration

```cql
ALTER TABLE my_ks.read_heavy WITH compaction = {
    'class': 'LeveledCompactionStrategy',
    'sstable_size_in_mb': 160          -- size per SSTable per level
};
```

### Monitoring Compaction Health

Key metrics to track:
- **Pending compaction tasks:** `scylla_compaction_manager_pending_tasks` (should be 0-2 during normal operation)
- **SSTable count per table:** `nodetool tablestats` (lower is better)
- **Write amplification:** compare bytes written to disk vs bytes written by application
- **Read amplification:** SSTables consulted per read (from tablehistograms)
- **Compaction throughput:** `scylla_compaction_manager_bytes_compacted`

## Repair Best Practices

### Repair Strategy

**Use ScyllaDB Manager for all repairs.** Manual `nodetool repair` is only for emergency use.

```bash
# Set up recurring repair (recommended: once per gc_grace_seconds window)
sctool repair -c my-cluster --interval 7d

# For large clusters, repair specific keyspaces on staggered schedules
sctool repair -c my-cluster -K users --interval 5d
sctool repair -c my-cluster -K events --interval 7d
```

### Repair Scheduling Rules

1. **Repair must complete within gc_grace_seconds** (default 10 days). If repair takes longer, reduce gc_grace_seconds or increase repair parallelism.
2. **Do not run repair on all nodes simultaneously** -- stagger across nodes.
3. **Monitor repair I/O impact** -- use sctool repair intensity settings.
4. **After node recovery from extended downtime** (> hint window), run immediate repair.
5. **After topology changes** (add/remove node), run repair on affected ranges.

### gc_grace_seconds Tuning

```cql
-- Default: 864000 (10 days)
-- Reduce if repair completes faster
ALTER TABLE my_ks.my_table WITH gc_grace_seconds = 432000;  -- 5 days

-- NEVER set to 0 unless RF=1 (single replica)
-- Ensure repair interval < gc_grace_seconds
```

## Backup Best Practices

### ScyllaDB Manager Backups

```bash
# Full backup to S3 (daily, 7-day retention)
sctool backup -c my-cluster \
    --location s3:my-scylla-backups \
    --interval 24h \
    --retention 7 \
    --rate-limit dc1:100   # rate limit per DC in MB/s

# Backup specific keyspaces
sctool backup -c my-cluster \
    -K my_keyspace \
    --location s3:my-scylla-backups \
    --interval 12h \
    --retention 14
```

### Backup Locations

ScyllaDB Manager supports:
- **S3** -- `s3:bucket-name` (with IAM credentials or instance profile)
- **GCS** -- `gcs:bucket-name` (2026.1+ native support)
- **Azure Blob** -- `azure:container-name`
- **Local/NFS** -- `/path/to/backup/dir`

### Snapshot-Based Backups (Manual)

```bash
# Take a snapshot
nodetool snapshot -t daily_backup my_keyspace

# List snapshots
nodetool listsnapshots

# Copy snapshot files to external storage
# Snapshots are in: /var/lib/scylla/data/my_keyspace/my_table-<uuid>/snapshots/daily_backup/

# Clean up after copying
nodetool clearsnapshot -t daily_backup
```

### Restore Procedures

```bash
# Restore from ScyllaDB Manager backup
sctool restore -c my-cluster \
    --location s3:my-scylla-backups \
    --snapshot-tag sm_<date>_<time> \
    --restore-schema       # also restore schema (optional)

# Restore specific keyspace
sctool restore -c my-cluster \
    --location s3:my-scylla-backups \
    --snapshot-tag sm_<date>_<time> \
    -K my_keyspace
```

## Monitoring Setup

### ScyllaDB Monitoring Stack Installation

```bash
# Prerequisites: Docker or Podman

# Clone monitoring stack
git clone https://github.com/scylladb/scylla-monitoring.git
cd scylla-monitoring

# Configure targets
cat > prometheus/scylla_servers.yml << 'EOF'
- targets:
  - 10.0.1.1:9180
  - 10.0.1.2:9180
  - 10.0.1.3:9180
  labels:
    cluster: production
    dc: dc1
EOF

# Configure manager monitoring (if using manager)
cat > prometheus/scylla_manager_servers.yml << 'EOF'
- targets:
  - 10.0.2.1:5090
  labels:
    cluster: production
EOF

# Start all components
./start-all.sh -d /var/lib/scylla-monitoring

# Access Grafana: http://<monitoring-host>:3000
```

### Critical Alerts to Configure

| Alert | Condition | Severity |
|---|---|---|
| Node down | `up == 0` for > 2 min | Critical |
| Compaction backlog | `scylla_compaction_manager_pending_tasks > 50` for > 10 min | Warning |
| Disk space | Disk usage > 70% | Warning |
| Disk space | Disk usage > 85% | Critical |
| Read latency p99 | > 50ms sustained | Warning |
| Write latency p99 | > 20ms sustained | Warning |
| Timeouts | `rate(scylla_storage_proxy_coordinator_read_timeouts[5m]) > 0` | Warning |
| Unavailables | `rate(scylla_storage_proxy_coordinator_read_unavailables[5m]) > 0` | Critical |
| Cache hit rate | < 70% | Warning |
| Hints pending | `scylla_node_hints_pending > 1000` | Warning |
| Large partitions | `scylla_compaction_manager_large_partition_warnings > 0` | Warning |
| Dropped messages | `rate(scylla_transport_requests_shed[5m]) > 0` | Critical |
| Schema disagreement | Multiple schema versions for > 5 min | Warning |

### Key Dashboards to Monitor Daily

1. **Cluster Overview** -- Quick health check, throughput, latency, errors
2. **Per-Server Metrics** -- CPU, memory, disk I/O per node (catch imbalanced nodes)
3. **Compaction** -- Pending tasks, throughput, SSTables per table
4. **CQL** -- Statement latency distribution, error rates
5. **Advisor** -- Automated recommendations (reviews metrics and suggests improvements)

## Security Hardening

### Authentication Setup

```yaml
# scylla.yaml
authenticator: PasswordAuthenticator
```

```cql
-- Change default superuser password IMMEDIATELY
ALTER ROLE cassandra WITH PASSWORD = 'very-strong-random-password';

-- Create application roles
CREATE ROLE app_readonly WITH PASSWORD = 'pass1' AND LOGIN = true;
CREATE ROLE app_readwrite WITH PASSWORD = 'pass2' AND LOGIN = true;
CREATE ROLE admin WITH PASSWORD = 'pass3' AND LOGIN = true AND SUPERUSER = true;
```

### Authorization Setup

```yaml
# scylla.yaml
authorizer: CassandraAuthorizer
```

```cql
-- Principle of least privilege
GRANT SELECT ON KEYSPACE my_ks TO app_readonly;
GRANT SELECT, MODIFY ON KEYSPACE my_ks TO app_readwrite;
GRANT ALL PERMISSIONS ON ALL KEYSPACES TO admin;

-- Revoke default permissions
REVOKE ALL ON ALL KEYSPACES FROM cassandra;
```

### Encryption Checklist

1. **Client-to-node TLS** -- Required for production
2. **Node-to-node TLS** -- Required for multi-DC and sensitive environments
3. **REST API** -- Bind to localhost only (or use TLS)
4. **Prometheus endpoint** -- Bind to localhost or use mTLS
5. **PEM format** -- ScyllaDB uses PEM certificates (not Java keystores)

### Network Security

- **Firewall rules:**
  - Port 9042 (CQL) -- Open to application servers only
  - Port 7000/7001 (inter-node) -- Open between cluster nodes only
  - Port 10000 (REST API) -- Localhost only (or monitoring server)
  - Port 9180 (Prometheus) -- Open to monitoring server only
  - Port 8000/8043 (Alternator) -- Open to application servers only (if used)
- **Bind addresses:** Use specific IPs, not 0.0.0.0, for production
- **VPC/subnet isolation:** Keep ScyllaDB nodes in a private subnet

## Multi-Datacenter Deployment

### Configuration

```cql
CREATE KEYSPACE global_ks WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'us-east': 3,
    'eu-west': 3
};
```

```properties
# cassandra-rackdc.properties (on each node)
dc=us-east
rack=rack1
prefer_local=true
```

### Multi-DC Best Practices

1. **Use LOCAL_QUORUM** for all reads and writes (default recommendation)
2. **3+ nodes per DC** minimum for RF=3
3. **Symmetric RF** across DCs unless one DC is a cold standby
4. **Monitor cross-DC latency** -- network latency between DCs directly impacts EACH_QUORUM performance
5. **Use ScyllaDB Manager** per DC (manager server in each DC)
6. **Separate repair schedules** per DC to avoid cross-DC repair traffic
7. **Test DC failover** regularly by disabling one DC and verifying the other serves traffic

### Client Configuration for Multi-DC

```python
# Python driver example with DC-aware policy
from cassandra.cluster import Cluster
from cassandra.policies import DCAwareRoundRobinPolicy, TokenAwarePolicy

cluster = Cluster(
    contact_points=['10.0.1.1', '10.0.1.2'],
    load_balancing_policy=TokenAwarePolicy(
        DCAwareRoundRobinPolicy(local_dc='us-east')
    )
)
```

For ScyllaDB shard-aware drivers, shard-awareness is layered on top of DC-awareness:
```python
# ScyllaDB Python driver (shard-aware)
from cassandra.cluster import Cluster, ExecutionProfile
from cassandra.policies import DCAwareRoundRobinPolicy, TokenAwarePolicy

profile = ExecutionProfile(
    load_balancing_policy=TokenAwarePolicy(
        DCAwareRoundRobinPolicy(local_dc='us-east'),
        shuffle_replicas=True
    )
)
```

## Cassandra Migration Guide

### Pre-Migration Assessment

| Item | Action |
|---|---|
| CQL compatibility | Test all CQL statements against ScyllaDB |
| Compaction strategy | Plan STCS -> ICS migration |
| JVM settings | Remove all JVM tuning (not applicable) |
| Materialized views | Test thoroughly; consider alternatives |
| SASI indexes | Not supported; use secondary indexes or application-side |
| Custom plugins (compressor, auth) | Check ScyllaDB compatibility |
| Client drivers | Switch to ScyllaDB shard-aware drivers |
| Monitoring | Replace JMX monitoring with Prometheus/Grafana |

### Migration Steps

**Phase 1: Schema Migration**
```bash
# Export schema from Cassandra
cqlsh cassandra-node -e "DESC KEYSPACE my_ks" > schema.cql

# Review and modify:
# - Replace STCS with ICS
# - Remove any SASI indexes
# - Verify all types are supported

# Apply to ScyllaDB
cqlsh scylla-node -f schema.cql
```

**Phase 2: Data Migration**

Option A -- SSTableLoader (recommended for large datasets):
```bash
# On Cassandra: snapshot
nodetool snapshot -t migrate_snap my_keyspace

# Copy SSTables to staging
# Load into ScyllaDB
sstableloader -d <scylla-node> /path/to/snapshots/my_table/
```

Option B -- Spark Migrator (recommended for filtering/transformation):
```bash
# Use ScyllaDB Spark Migrator
# Reads from Cassandra, writes to ScyllaDB
# Supports column mapping, filtering, transformation
```

Option C -- Dual-write (zero-downtime migration):
1. Set up ScyllaDB cluster alongside Cassandra
2. Update application to write to both clusters
3. Backfill historical data (SSTableLoader or Spark)
4. Validate data consistency
5. Switch reads to ScyllaDB
6. Remove Cassandra writes
7. Decommission Cassandra cluster

**Phase 3: Validation**
```bash
# Compare row counts
cqlsh cassandra-node -e "SELECT COUNT(*) FROM my_ks.my_table;"
cqlsh scylla-node -e "SELECT COUNT(*) FROM my_ks.my_table;"

# Sample data comparison (application-level)
# Compare random partition reads between clusters
```

**Phase 4: Driver Migration**
- Replace Cassandra drivers with ScyllaDB shard-aware drivers
- Update connection configuration
- Test with shard-aware routing enabled
- Verify cross-shard metrics decrease

### Post-Migration Optimization

1. **Run scylla_setup** on all nodes (ensure I/O calibration, IRQ affinity)
2. **Switch STCS to ICS** on all tables
3. **Run repair** to ensure consistency
4. **Tune compaction throughput** (ScyllaDB can handle much higher throughput than Cassandra)
5. **Review and remove** any Cassandra-specific workarounds (thread pool tuning, heap sizing)
6. **Set up ScyllaDB Monitoring Stack** (replaces JMX/DataStax metrics)

## ScyllaDB Cloud Best Practices

### Cluster Configuration

- **Choose the right plan:** Serverless for variable workloads, Dedicated for predictable workloads
- **Region selection:** Place cluster in same region as application for lowest latency
- **Multi-region:** Configure cross-region replication for disaster recovery
- **VPC peering:** Set up private connectivity (avoid public internet)

### Connection Configuration

```python
# ScyllaDB Cloud connection (Python)
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider

auth = PlainTextAuthProvider(username='scylla', password='<cloud-password>')
cluster = Cluster(
    contact_points=['node-0.aws-us-east-1.xxxxx.clusters.scylla.cloud'],
    auth_provider=auth,
    port=9042,
    ssl_context=ssl_context  # TLS required for cloud
)
```

### Cloud Monitoring

- ScyllaDB Cloud includes built-in monitoring (no separate stack needed)
- Alerts configurable through the cloud console
- Metrics exportable to external Prometheus/Grafana

## Performance Benchmarking

### scylla-bench (Recommended)

```bash
# Write benchmark
scylla-bench -workload sequential -mode write \
    -nodes 10.0.1.1,10.0.1.2,10.0.1.3 \
    -concurrency 200 -max-rate 0 \
    -partition-count 10000000 \
    -clustering-row-count 10

# Read benchmark (after write)
scylla-bench -workload uniform -mode read \
    -nodes 10.0.1.1,10.0.1.2,10.0.1.3 \
    -concurrency 200 -max-rate 0 \
    -partition-count 10000000 \
    -duration 10m

# Mixed workload (50% read, 50% write)
scylla-bench -workload uniform -mode mixed \
    -nodes 10.0.1.1,10.0.1.2,10.0.1.3 \
    -concurrency 200 \
    -write-rate 50 \
    -duration 10m
```

### cassandra-stress (Compatible)

```bash
# Write test
cassandra-stress write n=10000000 -rate threads=200 \
    -node 10.0.1.1,10.0.1.2,10.0.1.3

# Read test
cassandra-stress read n=10000000 -rate threads=200 \
    -node 10.0.1.1,10.0.1.2,10.0.1.3

# Mixed test
cassandra-stress mixed ratio\(write=1,read=3\) n=10000000 \
    -rate threads=200 \
    -node 10.0.1.1,10.0.1.2,10.0.1.3
```

### Benchmark Guidelines

1. **Run scylla_setup first** -- Benchmarks are meaningless without proper system tuning
2. **Warm up the cache** -- Run a pre-benchmark read pass
3. **Use realistic data sizes** -- Match your actual partition/row sizes
4. **Test at scale** -- Small benchmarks do not represent production behavior
5. **Monitor during benchmark** -- Use Grafana to identify bottlenecks
6. **Compare like for like** -- Same consistency level, same data size, same concurrency
