# Apache Cassandra Best Practices Reference

## Data Modeling Methodology

### Chebotko Diagram Approach

The standard methodology for Cassandra data modeling, developed by Artem Chebotko:

1. **Conceptual Data Model** -- Define entities and relationships (standard ER diagram)
2. **Application Workflow** -- Map every user interaction and query the application needs
3. **Logical Data Model** -- Design one table per application query, specifying:
   - Partition key (K): determines data distribution
   - Clustering columns (C): determines sort order within partition
   - Static columns (S): shared across all rows in a partition
   - Regular columns: per-row data
4. **Physical Data Model** -- Add concrete CQL types, TTLs, compaction settings

### Partition Key Design

**Goals:**
- Even data distribution across nodes (high cardinality)
- Each query satisfied by reading a single partition (or minimal partitions)
- Partition size bounded (< 100MB, ideally < 10MB)

**Patterns:**

| Pattern | Example | When to Use |
|---|---|---|
| Natural key | `user_id` | Unique entity with bounded data |
| Compound key | `(tenant_id, date)` | Multi-tenant time-series |
| Bucket key | `(sensor_id, hour_bucket)` | High-volume time-series with bounded partitions |
| Reverse-lookup key | `(email)` | Lookup table for alternative access pattern |
| Random prefix | `(shard_prefix, entity_id)` | Break up hot partitions (use sparingly) |

**Time-bucketing example:**
```cql
-- Bad: unbounded partition (grows forever)
CREATE TABLE events_bad (
    device_id text,
    event_time timestamp,
    data text,
    PRIMARY KEY (device_id, event_time)
);

-- Good: time-bucketed partition (bounded by day)
CREATE TABLE events_good (
    device_id text,
    day date,
    event_time timestamp,
    data text,
    PRIMARY KEY ((device_id, day), event_time)
) WITH CLUSTERING ORDER BY (event_time DESC);
```

### Partition Sizing Guidelines

| Metric | Target | Warning | Critical |
|---|---|---|---|
| Partition size | < 10MB | 10-100MB | > 100MB |
| Cells per partition | < 100,000 | 100K-1M | > 1M |
| Rows per partition | < 100,000 | 100K-1M | > 1M |

**Monitoring partition sizes:**
```bash
# Check average partition size via tablestats
nodetool tablestats my_keyspace.my_table | grep -E "Average|Maximum|Estimated"

# For detailed SSTable analysis
sstablemetadata /var/lib/cassandra/data/my_keyspace/my_table-<id>/*-Data.db | grep -E "Partition|Estimated"
```

### Denormalization Patterns

In Cassandra, data is denormalized to serve each query from a single table. Common patterns:

**1. Table-per-query:**
```cql
-- Query: Get user by ID
CREATE TABLE users_by_id (
    user_id uuid PRIMARY KEY,
    name text, email text
);

-- Query: Get user by email
CREATE TABLE users_by_email (
    email text PRIMARY KEY,
    user_id uuid, name text
);

-- Maintain both with a BATCH (same logical write, different tables)
BEGIN BATCH
    INSERT INTO users_by_id (user_id, name, email) VALUES (?, ?, ?);
    INSERT INTO users_by_email (email, user_id, name) VALUES (?, ?, ?);
APPLY BATCH;
```

**2. Wide partition for range queries:**
```cql
-- Query: Get all orders for a customer, sorted by date
CREATE TABLE orders_by_customer (
    customer_id uuid,
    order_date timestamp,
    order_id uuid,
    total decimal,
    PRIMARY KEY (customer_id, order_date, order_id)
) WITH CLUSTERING ORDER BY (order_date DESC, order_id ASC);
```

**3. Static columns for partition-level metadata:**
```cql
CREATE TABLE sensor_data (
    sensor_id text,
    day date,
    reading_time timestamp,
    location text STATIC,        -- same for all rows in partition
    sensor_type text STATIC,     -- same for all rows in partition
    value double,
    PRIMARY KEY ((sensor_id, day), reading_time)
);
```

## Cluster Sizing

### Node Count Formula

```
Total data per node = (Total data size * Replication Factor) / Number of nodes
Target: 1-2TB per node (SSD), 2-5TB per node (NVMe)
```

**Example:** 10TB dataset, RF=3, targeting 1.5TB per node:
- Total replicated data = 10TB * 3 = 30TB
- Nodes needed = 30TB / 1.5TB = 20 nodes

### Scaling Factors

| Factor | Consideration |
|---|---|
| **Throughput** | Each node handles ~5,000-15,000 ops/sec (varies with data model and hardware) |
| **Compaction headroom** | Reserve 50% disk space for compaction (STCS) or 10% (LCS) |
| **Streaming capacity** | Adding/removing nodes requires streaming; plan for topology changes |
| **Fault tolerance** | With RF=3, can tolerate 1 node down per 3 replicas; plan N+2 minimum |

### Hardware Selection

**Production recommendation per node:**

| Component | Minimum | Recommended | Notes |
|---|---|---|---|
| **CPU** | 8 cores | 16-32 cores | Cassandra is CPU-bound during compaction and encryption |
| **RAM** | 16GB | 32-64GB | 8-16GB for JVM heap; rest for OS page cache |
| **Storage** | SSD (500GB) | NVMe SSD (1-4TB) | Spinning disks only for commit log (if separate) |
| **Network** | 1 Gbps | 10 Gbps | Multi-DC replication and repair are network-intensive |
| **Disk count** | 1 | 2+ (JBOD) | Commit log on separate disk; data on JBOD (no RAID) |

**Storage guidelines:**
- JBOD (Just a Bunch of Disks) preferred over RAID -- Cassandra handles replication itself
- Commit log on a dedicated disk (or partition) to avoid contention with data I/O
- XFS filesystem recommended (ext4 acceptable)
- **Avoid:** NFS, EBS gp2 (use gp3/io2), shared storage, RAID arrays

**Cloud instance recommendations:**
| Cloud | Instance Type | Use Case |
|---|---|---|
| AWS | `i3.2xlarge` / `i4i.2xlarge` | Local NVMe, high I/O |
| AWS | `m5d.2xlarge` | Balanced compute + local SSD |
| GCP | `n2-standard-8` + local SSD | Good balance |
| Azure | `L8s_v3` | Local NVMe storage |

## cassandra.yaml Tuning

### Essential Parameters

```yaml
# Cluster identity
cluster_name: 'production-cluster'     # NEVER change after data is written
num_tokens: 16                         # 4.0+: 16 is optimal; 3.x default was 256
allocate_tokens_for_local_replication_factor: 3  # 4.0+: optimizes token allocation for RF

# Networking
listen_address: <node_ip>             # IP for inter-node communication
rpc_address: <node_ip>               # IP for client (CQL) connections
native_transport_port: 9042           # CQL port
storage_port: 7000                    # Inter-node communication port
ssl_storage_port: 7001                # Inter-node SSL port

# Data directories
data_file_directories:
    - /var/lib/cassandra/data         # JBOD: list multiple mount points
commitlog_directory: /var/lib/cassandra/commitlog  # SEPARATE disk
saved_caches_directory: /var/lib/cassandra/saved_caches
hints_directory: /var/lib/cassandra/hints

# Memtable
memtable_heap_space_in_mb: 2048       # or 1/4 of heap
memtable_offheap_space_in_mb: 2048
memtable_flush_writers: 4             # match number of data disks
memtable_allocation_type: heap_buffers  # or offheap_buffers

# Caches
key_cache_size_in_mb: 100             # or 5% of heap; almost always ON
key_cache_save_period: 14400          # save to disk every 4 hours
row_cache_size_in_mb: 0               # OFF by default; rarely enable
counter_cache_size_in_mb: 50

# Commit log
commitlog_sync: periodic
commitlog_sync_period_in_ms: 10000
commitlog_segment_size_in_mb: 32
commitlog_total_space_in_mb: 8192

# Compaction
concurrent_compactors: 4              # default: min(num_disks, num_cores)
compaction_throughput_mb_per_sec: 64   # throttle to reduce I/O impact; 0 = unlimited
compaction_large_partition_warning_threshold_mb: 100  # warn on oversized partitions

# Tombstones
tombstone_warn_threshold: 1000
tombstone_failure_threshold: 100000
gc_grace_seconds: 864000              # 10 days (set per-table, not globally)

# Timeouts
read_request_timeout_in_ms: 5000
write_request_timeout_in_ms: 2000
counter_write_request_timeout_in_ms: 5000
cas_contention_timeout_in_ms: 1000
range_request_timeout_in_ms: 10000
request_timeout_in_ms: 10000
slow_query_log_timeout_in_ms: 500     # 4.0+

# Hinted handoff
hinted_handoff_enabled: true
max_hint_window_in_ms: 10800000       # 3 hours
hinted_handoff_throttle_in_kb: 1024

# Inter-node
internode_compression: dc             # none, all, dc (compress only inter-DC)
inter_dc_tcp_nodelay: false
streaming_keep_alive_period_in_secs: 300

# Concurrency
concurrent_reads: 32                  # 16 * number_of_drives is a starting point
concurrent_writes: 32
concurrent_counter_writes: 32

# Repair
repair_session_max_tree_depth: 20     # Merkle tree depth; higher = more precise repair
repair_session_space_in_mb: 256       # memory for Merkle tree validation

# Snitch
endpoint_snitch: GossipingPropertyFileSnitch
dynamic_snitch_update_interval_in_ms: 100
dynamic_snitch_reset_interval_in_ms: 600000
dynamic_snitch_badness_threshold: 1.0

# Failure detection
phi_convict_threshold: 8              # increase to 10-12 in cloud environments

# Networking
native_transport_max_threads: 128
native_transport_max_frame_size_in_mb: 256
```

### Performance Tuning Profiles

**Write-heavy workload (logging, IoT, metrics):**
```yaml
memtable_heap_space_in_mb: 4096
commitlog_sync: periodic
commitlog_sync_period_in_ms: 10000
concurrent_writes: 64
compaction_throughput_mb_per_sec: 128
# Use TWCS for time-series or STCS for general writes
```

**Read-heavy workload (user profiles, product catalog):**
```yaml
key_cache_size_in_mb: 200
concurrent_reads: 64
compaction_throughput_mb_per_sec: 96
# Use LCS for consistent read latency
# Consider bloom_filter_fp_chance = 0.001 for frequently-read tables
```

**Mixed workload:**
```yaml
concurrent_reads: 32
concurrent_writes: 32
compaction_throughput_mb_per_sec: 64
# Start with STCS, measure, then switch if needed
```

## JVM Settings

### jvm11-server.options (Cassandra 4.x with Java 11)

```bash
# Heap size (MUST set both to same value to prevent resizing)
-Xms8G
-Xmx8G

# G1GC (recommended for Cassandra 4.x)
-XX:+UseG1GC
-XX:+ParallelRefProcEnabled
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:MaxGCPauseMillis=300
-XX:InitiatingHeapOccupancyPercent=70

# GC logging
-Xlog:gc*,gc+ref=debug,gc+heap=debug,gc+age=trace:file=/var/log/cassandra/gc.log:time,uptime,level,tags:filecount=10,filesize=10M

# Thread stack size
-Xss512k

# Direct memory (for off-heap allocations)
-XX:MaxDirectMemorySize=4G

# JMX (for monitoring)
-Dcom.sun.management.jmxremote.port=7199
-Dcom.sun.management.jmxremote.ssl=false
-Dcom.sun.management.jmxremote.authenticate=false

# Crash handling
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/lib/cassandra/heap_dumps
-XX:OnOutOfMemoryError="kill -9 %p"

# Performance
-XX:+AlwaysPreTouch
-XX:+UseNUMA
-XX:-UseBiasedLocking
-XX:+ResizeTLAB
```

### jvm17-server.options (Cassandra 5.0 with Java 17)

```bash
# Heap size
-Xms8G
-Xmx8G

# ZGC (recommended for Cassandra 5.0)
-XX:+UseZGC
-XX:+ZGenerational          # Java 21; omit for Java 17

# Or G1GC (proven, lower memory overhead)
# -XX:+UseG1GC
# -XX:MaxGCPauseMillis=300

# GC logging
-Xlog:gc*:file=/var/log/cassandra/gc.log:time,uptime,level,tags:filecount=10,filesize=10M

# Module access for Cassandra internals (required for Java 17+)
--add-exports java.base/jdk.internal.misc=ALL-UNNAMED
--add-exports java.base/jdk.internal.ref=ALL-UNNAMED
--add-exports java.base/sun.nio.ch=ALL-UNNAMED
--add-exports java.management.rmi/com.sun.jmx.remote.internal.rmi=ALL-UNNAMED
--add-exports java.rmi/sun.rmi.registry=ALL-UNNAMED
--add-exports java.rmi/sun.rmi.server=ALL-UNNAMED
--add-exports java.sql/java.sql=ALL-UNNAMED
--add-opens java.base/java.lang.module=ALL-UNNAMED
--add-opens java.base/jdk.internal.loader=ALL-UNNAMED
--add-opens java.base/jdk.internal.ref=ALL-UNNAMED
--add-opens java.base/jdk.internal.reflect=ALL-UNNAMED
--add-opens java.base/jdk.internal.math=ALL-UNNAMED
--add-opens java.base/jdk.internal.module=ALL-UNNAMED
--add-opens java.base/jdk.internal.util.jar=ALL-UNNAMED
--add-opens jdk.management/com.sun.management.internal=ALL-UNNAMED
```

### Heap Sizing Decision Tree

```
Total RAM <= 8GB:   Heap = 50% of RAM (max 4GB)
Total RAM 8-32GB:   Heap = 8GB (standard)
Total RAM 32-64GB:  Heap = 16GB
Total RAM > 64GB:   Heap = 24-31GB (never exceed 31GB for compressed oops)

Rule: Heap should NEVER exceed 50% of total RAM
Remaining RAM = OS page cache for SSTables (critical for performance)
```

## Compaction Strategy Selection

### Decision Matrix

```
Q: Is this time-series data with TTL?
   YES --> TWCS
   NO  --> Continue

Q: Is the workload primarily reads with frequent updates/overwrites?
   YES --> LCS
   NO  --> Continue

Q: Is the workload primarily writes with infrequent reads?
   YES --> STCS
   NO  --> Continue

Q: Is this Cassandra 5.0+?
   YES --> UCS (configure scaling_parameters based on workload)
   NO  --> STCS (default; evaluate after measuring)
```

### Switching Compaction Strategy

```cql
-- Switch from STCS to LCS
ALTER TABLE my_table WITH compaction = {
    'class': 'LeveledCompactionStrategy',
    'sstable_size_in_mb': 160
};
-- Existing SSTables will be gradually compacted into levels

-- Switch from STCS to TWCS
ALTER TABLE my_table WITH compaction = {
    'class': 'TimeWindowCompactionStrategy',
    'compaction_window_size': 1,
    'compaction_window_unit': 'HOURS'
};
```

**Warning:** Switching compaction strategy triggers background reorganization. Monitor compaction progress with `nodetool compactionstats` and ensure sufficient disk space.

## Repair Scheduling

### Repair Requirements

- Every token range must be repaired within `gc_grace_seconds` (default 10 days)
- Repair should run on every node for its primary ranges (`-pr` flag)
- Do NOT run repair on all nodes simultaneously

### Manual Repair Schedule

```bash
# Run on each node sequentially, repairing only primary ranges
# Node 1:
nodetool repair -pr my_keyspace

# Node 2 (after node 1 completes):
nodetool repair -pr my_keyspace

# ... repeat for all nodes
```

**Timing guidance:**
- For a 10-node cluster with gc_grace_seconds = 864000 (10 days):
  - Complete full repair cycle within 10 days
  - Budget: 1 node per day = 10 days (too tight; adjust gc_grace_seconds or node count)
  - Better: gc_grace_seconds = 1209600 (14 days) with 1 node per day = comfortable margin

### Automated Repair Tools

**Cassandra Reaper (recommended):**
- Open-source automated repair scheduler
- Supports incremental and subrange repair
- Web UI for monitoring repair progress
- Automatically schedules repairs to complete within gc_grace_seconds
- Manages repair parallelism and intensity

```bash
# Register a cluster
curl -X POST "http://reaper:8080/cluster" \
    -d "seedHost=cassandra-node1" \
    -d "clusterName=production"

# Schedule a repair
curl -X POST "http://reaper:8080/repair_schedule" \
    -d "clusterName=production" \
    -d "keyspace=my_keyspace" \
    -d "scheduleDaysBetween=7" \
    -d "repairParallelism=DATACENTER_AWARE" \
    -d "intensity=0.5"
```

## Backup Strategies

### Snapshots

Snapshots create hard links to SSTable files (instant, no I/O overhead):

```bash
# Take a snapshot of all keyspaces
nodetool snapshot -t backup_2025_03_15

# Snapshot specific keyspace
nodetool snapshot -t daily_backup my_keyspace

# Snapshot specific table
nodetool snapshot -t table_backup my_keyspace my_table

# List snapshots
nodetool listsnapshots

# Clear a specific snapshot
nodetool clearsnapshot -t backup_2025_03_15

# Clear ALL snapshots (caution!)
nodetool clearsnapshot
```

**Snapshot location:** `<data_dir>/<keyspace>/<table>/snapshots/<snapshot_name>/`

**Backup procedure:**
1. Take a snapshot: `nodetool snapshot -t <tag>`
2. Copy snapshot files to external storage (S3, NFS, tape)
3. Also back up the schema: `cqlsh -e "DESCRIBE KEYSPACE my_keyspace" > schema.cql`
4. Clear the snapshot after backup: `nodetool clearsnapshot -t <tag>`

### Incremental Backup

When enabled, Cassandra hard-links each flushed SSTable to a `backups/` directory:

```yaml
# cassandra.yaml
incremental_backups: true
```

**Incremental backup location:** `<data_dir>/<keyspace>/<table>/backups/`

**Procedure:**
1. Enable incremental backups in cassandra.yaml
2. Periodically move files from `backups/` to external storage
3. Combine with periodic snapshots for full + incremental backup strategy

### Restore Procedure

```bash
# 1. Stop Cassandra
sudo systemctl stop cassandra

# 2. Clear existing data (if full restore)
rm -rf /var/lib/cassandra/data/my_keyspace/my_table-*

# 3. Copy snapshot files to the table directory
cp /backup/snapshot_files/* /var/lib/cassandra/data/my_keyspace/my_table-<table_id>/

# 4. Restore the schema (if needed)
cqlsh -f schema.cql

# 5. Start Cassandra
sudo systemctl start cassandra

# 6. Run repair to ensure consistency
nodetool repair my_keyspace
```

### Medusa (Backup Tool)

Medusa is a purpose-built Cassandra backup tool that supports cloud storage:

```bash
# Full backup to S3
medusa backup --backup-name=full_2025_03_15 --mode=full

# Differential backup
medusa backup --backup-name=diff_2025_03_16 --mode=differential

# Restore
medusa restore-cluster --backup-name=full_2025_03_15 --seed-target=node1

# List backups
medusa list-backups
```

## Monitoring Setup

### Key Metrics to Monitor

**Cluster-level:**

| Metric | Source | Warning Threshold | Critical Threshold |
|---|---|---|---|
| Node status (UN/DN) | `nodetool status` | Any DN node | Multiple DN nodes |
| Schema agreement | `nodetool describecluster` | Any disagreement | Disagreement > 5 min |
| Pending compactions | `nodetool compactionstats` | > 20 | > 50 |
| Dropped messages | `nodetool tpstats` | Any dropped | Sustained drops |

**Per-node:**

| Metric | Source | Warning Threshold | Critical Threshold |
|---|---|---|---|
| Disk usage | OS / `nodetool info` | > 60% | > 75% |
| Heap usage | JMX / `nodetool info` | > 75% | > 85% |
| GC pause time | GC logs | > 500ms | > 2000ms |
| Read latency (p99) | `nodetool tablehistograms` | > 50ms | > 200ms |
| Write latency (p99) | `nodetool tablehistograms` | > 10ms | > 50ms |
| Pending compactions | `nodetool compactionstats` | > 15 | > 30 |
| SSTable count per table | `nodetool tablestats` | > 30 (LCS L0) | > 50 |
| Tombstones per read | `nodetool tablestats` | > 100 avg | > 1000 avg |

**JMX metrics for Prometheus/Grafana:**

```yaml
# Key JMX beans to export
- org.apache.cassandra.metrics:type=ClientRequest,scope=Read,name=Latency
- org.apache.cassandra.metrics:type=ClientRequest,scope=Write,name=Latency
- org.apache.cassandra.metrics:type=ClientRequest,scope=Read,name=Timeouts
- org.apache.cassandra.metrics:type=ClientRequest,scope=Write,name=Timeouts
- org.apache.cassandra.metrics:type=Compaction,name=PendingTasks
- org.apache.cassandra.metrics:type=Compaction,name=CompletedTasks
- org.apache.cassandra.metrics:type=ThreadPools,path=request,scope=*,name=ActiveTasks
- org.apache.cassandra.metrics:type=ThreadPools,path=request,scope=*,name=PendingTasks
- org.apache.cassandra.metrics:type=Storage,name=Load
- org.apache.cassandra.metrics:type=Storage,name=Exceptions
- org.apache.cassandra.metrics:type=ColumnFamily,name=LiveSSTableCount
- org.apache.cassandra.metrics:type=ColumnFamily,name=TombstoneScannedHistogram
- org.apache.cassandra.metrics:type=ColumnFamily,name=SSTablesPerReadHistogram
```

### Monitoring Tools

| Tool | Type | Integration |
|---|---|---|
| **Prometheus + JMX Exporter** | Metrics collection | Export JMX metrics to Prometheus |
| **Grafana** | Dashboard | Visualize Prometheus metrics |
| **Cassandra Exporter** | Native metrics | Purpose-built Prometheus exporter |
| **DataStax Metrics Collector** | Metrics pipeline | Integrates with multiple backends |
| **Cassandra Reaper** | Repair monitoring | Web UI for repair status |
| **Instaclustr Cassandra Lucene Index** | Monitoring | Full-text search on logs |

### Alerting Rules

```yaml
# Prometheus alerting rules
groups:
  - name: cassandra
    rules:
      - alert: CassandraNodeDown
        expr: cassandra_node_status == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Cassandra node {{ $labels.instance }} is down"

      - alert: CassandraHighReadLatency
        expr: cassandra_client_request_latency_seconds{scope="Read", quantile="0.99"} > 0.2
        for: 5m
        labels:
          severity: warning

      - alert: CassandraCompactionBacklog
        expr: cassandra_compaction_pending_tasks > 30
        for: 10m
        labels:
          severity: warning

      - alert: CassandraDiskUsage
        expr: cassandra_disk_usage_percentage > 75
        for: 5m
        labels:
          severity: critical

      - alert: CassandraDroppedMessages
        expr: rate(cassandra_dropped_messages_total[5m]) > 0
        for: 2m
        labels:
          severity: warning
```

## Security Hardening

### Authentication

```yaml
# cassandra.yaml
authenticator: PasswordAuthenticator
```

```cql
-- After enabling authentication, default superuser is cassandra/cassandra
-- IMMEDIATELY create a new superuser and disable the default:
CREATE ROLE admin WITH PASSWORD = 'StrongP@ssw0rd!' AND LOGIN = true AND SUPERUSER = true;
ALTER ROLE cassandra WITH PASSWORD = 'random_disabled_password' AND SUPERUSER = false;

-- Create application roles
CREATE ROLE app_read WITH PASSWORD = 'read_only_pass' AND LOGIN = true;
CREATE ROLE app_write WITH PASSWORD = 'write_pass' AND LOGIN = true;
```

### Authorization

```yaml
# cassandra.yaml
authorizer: CassandraAuthorizer
```

```cql
-- Principle of least privilege
GRANT SELECT ON KEYSPACE production TO app_read;
GRANT SELECT, MODIFY ON KEYSPACE production TO app_write;
GRANT ALL PERMISSIONS ON ALL KEYSPACES TO admin;

-- Restrict specific tables
REVOKE MODIFY ON TABLE production.audit_log FROM app_write;

-- View permissions
LIST ALL PERMISSIONS OF app_write;
LIST ALL PERMISSIONS ON KEYSPACE production;
```

### Network Encryption

**Client-to-node (CQL connections):**
```yaml
client_encryption_options:
    enabled: true
    optional: false            # true = allow unencrypted during migration
    keystore: /etc/cassandra/ssl/.keystore
    keystore_password: <password>
    truststore: /etc/cassandra/ssl/.truststore
    truststore_password: <password>
    require_client_auth: false  # true = mutual TLS
    protocol: TLS
    algorithm: SunX509
    store_type: JKS
    cipher_suites:
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
```

**Node-to-node (inter-node communication):**
```yaml
server_encryption_options:
    internode_encryption: all   # none, dc, rack, all
    keystore: /etc/cassandra/ssl/.keystore
    keystore_password: <password>
    truststore: /etc/cassandra/ssl/.truststore
    truststore_password: <password>
    require_client_auth: true  # mutual TLS between nodes
    protocol: TLS
    algorithm: SunX509
    cipher_suites:
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
```

**Generating keystores and truststores:**
```bash
# Generate CA key and certificate
openssl req -new -x509 -keyout ca-key -out ca-cert -days 3650 -subj "/CN=CassandraCA"

# Generate node keystore
keytool -genkeypair -alias node1 -keyalg RSA -keysize 2048 \
    -dname "CN=node1.example.com" -keystore node1.keystore \
    -storepass changeit -keypass changeit -validity 3650

# Export node certificate and sign with CA
keytool -certreq -alias node1 -keystore node1.keystore -file node1.csr -storepass changeit
openssl x509 -req -CA ca-cert -CAkey ca-key -in node1.csr -out node1-signed.cert \
    -days 3650 -CAcreateserial

# Import CA cert and signed node cert into keystore
keytool -importcert -alias ca -keystore node1.keystore -file ca-cert -storepass changeit -noprompt
keytool -importcert -alias node1 -keystore node1.keystore -file node1-signed.cert -storepass changeit

# Create truststore with CA cert
keytool -importcert -alias ca -keystore truststore -file ca-cert -storepass changeit -noprompt
```

### Additional Security Measures

1. **Firewall rules:** Restrict ports 9042 (CQL), 7000/7001 (internode), 7199 (JMX) to authorized IPs only
2. **JMX authentication:** Enable JMX auth in `cassandra-env.sh`:
   ```bash
   JVM_OPTS="$JVM_OPTS -Dcom.sun.management.jmxremote.authenticate=true"
   JVM_OPTS="$JVM_OPTS -Dcom.sun.management.jmxremote.password.file=/etc/cassandra/jmxremote.password"
   ```
3. **Audit logging (4.0+):** See `4.x/SKILL.md` for audit logging configuration
4. **Role-based access control:** Use roles (not users) for permission management
5. **Password complexity:** Enforce strong passwords via custom authenticator or policy

## Multi-Datacenter Deployment

### Architecture

```
DC: us-east-1                          DC: eu-west-1
┌─────────────────────────┐           ┌─────────────────────────┐
│ Rack: rack1              │           │ Rack: rack1              │
│   Node 1 (seed)         │           │   Node 4 (seed)         │
│   Node 2                │    ◄──►   │   Node 5                │
│ Rack: rack2              │  gossip   │ Rack: rack2              │
│   Node 3                │  + data   │   Node 6                │
└─────────────────────────┘           └─────────────────────────┘
```

### Configuration Checklist

**On every node:**

1. **cassandra.yaml:**
   ```yaml
   endpoint_snitch: GossipingPropertyFileSnitch
   # Seed nodes: at least 2 per DC
   seed_provider:
       - class_name: org.apache.cassandra.locator.SimpleSeedProvider
         parameters:
             - seeds: "node1-ip,node2-ip,node4-ip,node5-ip"
   ```

2. **cassandra-rackdc.properties:**
   ```
   dc=us-east-1
   rack=rack1
   prefer_local=true
   ```

3. **Keyspace creation:**
   ```cql
   CREATE KEYSPACE global_ks WITH replication = {
       'class': 'NetworkTopologyStrategy',
       'us-east-1': 3,
       'eu-west-1': 3
   };
   ```

4. **Application consistency levels:**
   ```
   Reads:  LOCAL_QUORUM  (strong consistency within local DC)
   Writes: LOCAL_QUORUM  (strong consistency within local DC)
   ```

### Multi-DC Consistency Patterns

| Pattern | Read CL | Write CL | Behavior |
|---|---|---|---|
| **Local strong** | LOCAL_QUORUM | LOCAL_QUORUM | Strong in local DC; eventual across DCs |
| **Global strong** | QUORUM | QUORUM | Strong across all DCs; higher latency |
| **Write global, read local** | LOCAL_ONE | EACH_QUORUM | Writes confirmed in all DCs; fast local reads |
| **Eventual everywhere** | LOCAL_ONE | LOCAL_ONE | Fastest; eventually consistent |

### DC Failover

If an entire datacenter goes down:
- `LOCAL_QUORUM` operations in the surviving DC continue working normally
- `QUORUM` operations may fail if not enough replicas are reachable globally
- Hinted handoff accumulates hints for the down DC (within `max_hint_window_in_ms`)
- After the DC recovers, run `nodetool repair` to synchronize missed data beyond the hint window

## Linux OS Tuning

### Recommended sysctl Settings

```bash
# /etc/sysctl.d/99-cassandra.conf

# VM settings
vm.max_map_count = 1048575
vm.swappiness = 1                    # minimize swapping (0 can cause OOM kills)
vm.zone_reclaim_mode = 0             # disable NUMA zone reclaim
vm.dirty_ratio = 80                  # don't flush dirty pages aggressively
vm.dirty_background_ratio = 5

# Network
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.optmem_max = 40960
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65536
net.ipv4.tcp_max_syn_backlog = 65536

# File descriptors
fs.file-max = 1048576
```

### Recommended limits.conf

```bash
# /etc/security/limits.d/cassandra.conf
cassandra - memlock unlimited
cassandra - nofile 1048576
cassandra - nproc 32768
cassandra - as unlimited
```

### Disk Settings

```bash
# Disable swap (or set swappiness to 1)
sudo swapoff -a

# Set I/O scheduler to deadline or noop for SSDs
echo deadline > /sys/block/sda/queue/scheduler   # or 'none' for NVMe
# Or in /etc/udev/rules.d/60-cassandra.rules:
# ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="deadline"

# Disable atime updates
# In /etc/fstab, add 'noatime' to the mount options for data directories:
# /dev/sdb1  /var/lib/cassandra  xfs  defaults,noatime  0  0

# XFS mount options
# mount -o noatime,largeio,inode64 /dev/sdb1 /var/lib/cassandra
```

### NTP/Chrony (Critical)

Cassandra relies on timestamps for conflict resolution (last-write-wins). Clock skew between nodes causes data inconsistencies:

```bash
# Install and configure chrony
sudo apt install chrony
sudo systemctl enable chrony

# /etc/chrony/chrony.conf
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
makestep 1 3
rtcsync

# Verify time sync
chronyc tracking
chronyc sources

# Clock skew should be < 10ms across all Cassandra nodes
```
