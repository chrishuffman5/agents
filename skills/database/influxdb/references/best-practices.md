# InfluxDB Best Practices Reference

## Schema Design

### Measurement Naming

- Use lowercase with underscores: `cpu_usage`, `http_requests`, `sensor_temperature`
- Be descriptive but concise: avoid abbreviations that are not universally understood
- Use singular nouns: `cpu` not `cpus`, `disk` not `disks`
- Avoid dots, spaces, or special characters (they cause escaping issues in queries)
- Do not encode metadata in measurement names (use tags instead):
  - Bad: `cpu.server01.us-east` (encodes host and region in measurement name)
  - Good: `cpu` measurement with `host=server01` and `region=us-east` tags

### Tag Design

**Principle: tags are for metadata with bounded cardinality that you filter or group by.**

- Use lowercase with underscores: `host`, `region`, `sensor_id`, `environment`
- Keep cardinality bounded: ideal < 10K unique values, manageable < 100K, dangerous > 1M
- Do not use tags for values that change frequently (that is what fields are for)
- Order tags alphabetically in line protocol for consistent series keys and better compression
- Common tag patterns:
  - Infrastructure: `host`, `region`, `datacenter`, `environment`, `cluster`, `rack`
  - Application: `service`, `endpoint`, `method`, `status_code`, `version`
  - IoT: `device_id`, `sensor_type`, `location`, `firmware_version`

**Cardinality danger signs:**
| Scenario | Cardinality | Impact |
|---|---|---|
| `host` tag with 100 servers | 100 | No problem |
| `container_id` tag in Kubernetes | 10K+ and growing | Moderate risk |
| `request_id` tag | Millions/day | Series explosion -- will crash 2.x |
| `user_id` tag with 1M users | 1M+ | High risk in 2.x, manageable in 3.x |
| `ip_address` tag | Unbounded | Extreme risk |

### Field Design

- Use fields for numeric values you will aggregate (SUM, MEAN, MAX, PERCENTILE)
- Include units in field names for clarity: `temperature_celsius`, `response_time_ms`, `memory_bytes`
- Choose the correct type and be consistent:
  - Floats: `value=72.3` (default, no suffix)
  - Integers: `count=1523i` (append `i`)
  - Strings: `message="healthy"` (double-quoted)
  - Booleans: `active=true`
- Once a field type is set for a series, it cannot be changed (type conflict errors)
- Avoid storing the same value as both a tag and a field

### Schema Anti-Patterns

**Anti-pattern 1: Encoding data in measurement names**
```
# BAD: One measurement per host
cpu_server01 value=72.3
cpu_server02 value=68.1

# GOOD: Single measurement with host tag
cpu,host=server01 value=72.3
cpu,host=server02 value=68.1
```

**Anti-pattern 2: Encoding data in field names**
```
# BAD: Field name includes variable data
sensor value_building_a=22.5,value_building_b=23.1

# GOOD: Use tags to distinguish
sensor,building=a value=22.5
sensor,building=b value=23.1
```

**Anti-pattern 3: Using timestamps as tags**
```
# BAD: Date as a tag (creates infinite cardinality)
events,date=2026-04-07 count=15i

# GOOD: Use the timestamp field
events count=15i 1712448000000000000
```

**Anti-pattern 4: Too many fields per measurement**
```
# BAD: 500 fields in one measurement (slow queries, schema complexity)
system cpu_user=23.5,cpu_system=5.2,...,disk_sda_read=1234,...

# GOOD: Separate measurements by domain
cpu,host=server01 usage_user=23.5,usage_system=5.2
disk,host=server01,device=sda read_bytes=1234i,write_bytes=5678i
```

---

## Write Optimization

### Batching

The single most impactful write optimization is proper batching:

| Batch Size | Performance | Notes |
|---|---|---|
| 1 point per request | Very poor | HTTP overhead dominates; never do this |
| 100 points | Poor | Still too many HTTP round trips |
| 1,000 points | Acceptable | Minimum for production |
| 5,000-10,000 points | Optimal | Best throughput/latency balance |
| 50,000+ points | Diminishing returns | Risk of timeout; larger memory footprint |

**Batching implementation:**
```python
from influxdb_client_3 import InfluxDBClient3
import time

client = InfluxDBClient3(host="http://localhost:8181", database="mydb", token="token")

batch = []
BATCH_SIZE = 5000
FLUSH_INTERVAL = 1.0  # seconds
last_flush = time.time()

def add_point(line):
    batch.append(line)
    if len(batch) >= BATCH_SIZE or (time.time() - last_flush) >= FLUSH_INTERVAL:
        flush()

def flush():
    global last_flush
    if batch:
        client.write(batch)
        batch.clear()
        last_flush = time.time()
```

### Line Protocol Optimization

- **Sort by tag set:** Group points with the same measurement and tags together for compression
- **Use appropriate precision:** Do not send nanosecond timestamps for data collected every 10 seconds
- **Omit default timestamps:** If server time is acceptable, omit the timestamp field
- **Compress request bodies:** Use `Content-Encoding: gzip` for large batches (50%+ size reduction)
- **Avoid string fields when possible:** Strings compress poorly compared to numeric types

### Back-Pressure and Error Handling

```python
import time
import requests

def write_with_retry(url, data, headers, max_retries=5):
    """Write with exponential backoff for transient errors."""
    for attempt in range(max_retries):
        try:
            resp = requests.post(url, data=data, headers=headers, timeout=30)
            if resp.status_code == 204:
                return True  # Success
            elif resp.status_code == 429:
                # Rate limited -- back off
                retry_after = int(resp.headers.get("Retry-After", 2 ** attempt))
                time.sleep(min(retry_after, 60))
            elif resp.status_code == 503:
                # Server overloaded (cache full in 2.x, or temporary unavailability)
                time.sleep(min(2 ** attempt, 60))
            elif resp.status_code == 400:
                # Bad request -- do not retry (line protocol parse error)
                raise ValueError(f"Line protocol error: {resp.text}")
            elif resp.status_code == 401:
                raise PermissionError("Authentication failed")
            elif resp.status_code == 404:
                raise ValueError("Bucket/database not found")
            else:
                resp.raise_for_status()
        except requests.exceptions.ConnectionError:
            time.sleep(min(2 ** attempt, 60))
    raise RuntimeError(f"Write failed after {max_retries} retries")
```

### Write Throughput Tuning

**InfluxDB 2.x server-side tuning:**
```toml
# influxdb.conf or environment variables
[data]
  cache-max-memory-size = "1g"            # Increase for high write throughput
  cache-snapshot-memory-size = "25m"      # Trigger snapshots at 25MB
  cache-snapshot-write-cold-duration = "10m"
  compact-throughput = "48m"              # Compaction rate limit
  max-concurrent-compactions = 0          # 0 = auto (GOMAXPROCS/2)
  wal-fsync-delay = "0s"                  # 0 = fsync every write (safest)
                                          # Set to 100ms-1s for higher throughput
```

**InfluxDB 3.x server-side tuning:**
```bash
influxdb3 serve \
  --object-store file \
  --data-dir /var/lib/influxdb3 \
  --wal-flush-interval 1s \
  --memory-pool-size 70% \
  --log-filter info
```

---

## Query Optimization

### InfluxDB 2.x (Flux) Query Best Practices

1. **Always specify time range first** -- This is the most important filter:
```flux
from(bucket: "monitoring")
  |> range(start: -1h)     // ALWAYS first -- limits data scan
  |> filter(fn: (r) => r._measurement == "cpu")
  |> filter(fn: (r) => r.host == "server01")
```

2. **Filter early, transform late:**
```flux
// GOOD: Filter before aggregation
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu")
  |> filter(fn: (r) => r._field == "usage_user")
  |> aggregateWindow(every: 5m, fn: mean)

// BAD: Aggregating everything then filtering
from(bucket: "monitoring")
  |> range(start: -1h)
  |> aggregateWindow(every: 5m, fn: mean)
  |> filter(fn: (r) => r._measurement == "cpu")
```

3. **Avoid `pivot()` on large datasets** -- It creates wide tables that consume significant memory.

4. **Use `limit()` for exploratory queries:**
```flux
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu")
  |> limit(n: 100)
```

5. **Use `drop()` to remove unnecessary columns:**
```flux
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu")
  |> drop(columns: ["_start", "_stop", "_measurement"])
```

### InfluxDB 3.x (SQL) Query Best Practices

1. **Always include time predicates:**
```sql
-- GOOD: Time predicate enables partition pruning
SELECT * FROM cpu WHERE time >= now() - INTERVAL '1 hour';

-- BAD: Full table scan across all partitions
SELECT * FROM cpu;
```

2. **Use EXPLAIN ANALYZE to understand query plans:**
```sql
EXPLAIN ANALYZE
SELECT date_bin('5 minutes', time) AS window, host, AVG(usage_user)
FROM cpu
WHERE time >= now() - INTERVAL '1 hour'
GROUP BY window, host;
```

3. **Leverage caches for common queries:**
```sql
-- Use Last Value Cache for "current state" queries
SELECT * FROM last_cache('cpu_latest') WHERE host = 'server01';

-- Use Distinct Value Cache for "list all hosts" queries
SELECT * FROM distinct_cache('cpu_hosts');
```

4. **Project only needed columns:**
```sql
-- GOOD: Only reads 3 columns from Parquet
SELECT time, host, usage_user FROM cpu WHERE time >= now() - INTERVAL '1 hour';

-- BAD: Reads all columns
SELECT * FROM cpu WHERE time >= now() - INTERVAL '1 hour';
```

5. **Use appropriate aggregation functions:**
```sql
-- Time-based aggregation using date_bin
SELECT date_bin('5 minutes', time) AS window,
       host,
       AVG(usage_user) AS avg_cpu,
       MAX(usage_user) AS max_cpu,
       COUNT(*) AS sample_count
FROM cpu
WHERE time >= now() - INTERVAL '24 hours'
GROUP BY window, host
ORDER BY window DESC;
```

---

## Cardinality Management

### Monitoring Cardinality

**InfluxDB 2.x:**
```bash
# Check total series cardinality
influx query 'import "influxdata/influxdb"
influxdb.cardinality(bucket: "monitoring", start: -30d)'

# InfluxQL via API
curl -G 'http://localhost:8086/query' \
  --data-urlencode "q=SHOW SERIES CARDINALITY" \
  -H "Authorization: Token $INFLUX_TOKEN"
```

**InfluxDB 3.x:**
```sql
-- Count distinct series (approximate)
SELECT COUNT(DISTINCT host) FROM cpu;

-- Query system tables for table information
SELECT * FROM information_schema.tables;
SELECT * FROM information_schema.columns WHERE table_name = 'cpu';
```

### Cardinality Reduction Strategies

1. **Telegraf-level filtering (prevent high-cardinality data from being written):**
```toml
# Drop specific tags before writing
[[inputs.docker]]
  tagexclude = ["container_id", "container_name"]

# Only keep specific tags
[[inputs.cpu]]
  taginclude = ["host", "cpu"]

# Drop entire measurements
[[processors.filter]]
  namepass = ["cpu", "mem", "disk"]

# Use regex processor to normalize tags
[[processors.regex]]
  [[processors.regex.tags]]
    key = "url"
    pattern = "^(https?://[^/]+)/.*"
    replacement = "${1}"
```

2. **Tag value bucketing (reduce cardinality of semi-bounded tags):**
```toml
# Use Telegraf starlark processor to bucket IPs
[[processors.starlark]]
  source = '''
def apply(metric):
    ip = metric.tags.get("source_ip", "")
    if ip:
        parts = ip.split(".")
        if len(parts) == 4:
            metric.tags["source_subnet"] = parts[0] + "." + parts[1] + "." + parts[2] + ".0/24"
            del metric.tags["source_ip"]
    return metric
'''
```

3. **Design review checklist:**
   - [ ] Every tag has bounded cardinality (< 100K unique values)
   - [ ] No UUIDs, session IDs, or request IDs as tags
   - [ ] No IP addresses as tags (use subnet bucketing or fields)
   - [ ] No user IDs as tags (use fields or bucket by hash)
   - [ ] Measurement names do not encode variable data
   - [ ] Field names do not encode variable data

---

## Retention and Downsampling

### InfluxDB 2.x Retention Strategy

```
Raw data bucket: "monitoring" (retention: 7 days)
        │
        │  Flux task runs every 1 hour
        ▼
Hourly rollup bucket: "monitoring_hourly" (retention: 90 days)
        │
        │  Flux task runs every 1 day
        ▼
Daily rollup bucket: "monitoring_daily" (retention: 3 years)
```

**Downsampling task (Flux):**
```flux
option task = {name: "downsample_cpu_hourly", every: 1h}

from(bucket: "monitoring")
  |> range(start: -task.every)
  |> filter(fn: (r) => r._measurement == "cpu")
  |> aggregateWindow(every: 1h, fn: mean, createEmpty: false)
  |> to(bucket: "monitoring_hourly")
```

### InfluxDB 3.x Downsampling Strategy

```
Raw database: "monitoring" (recent data in Core)
        │
        │  Processing engine trigger (WAL flush or schedule)
        ▼
Rollup database: "monitoring_rollups"
```

**Downsampling with processing engine (Python plugin):**
```python
# downsample_plugin.py
def process_writes(influxdb3_local, table_batches, args=None):
    for table_name, batch in table_batches.items():
        if table_name == "cpu":
            # Write aggregated data to rollup database
            query = f"""
                SELECT date_bin('1 hour', time) AS time,
                       host,
                       AVG(usage_user) AS usage_user_mean,
                       MAX(usage_user) AS usage_user_max
                FROM {table_name}
                WHERE time >= now() - INTERVAL '1 hour'
                GROUP BY 1, host
            """
            influxdb3_local.query(query)
```

---

## Telegraf Best Practices

### Configuration Architecture

For large deployments, use modular configuration:
```
/etc/telegraf/
  telegraf.conf           # Agent-level settings
  telegraf.d/
    inputs-cpu.conf       # Per-input configs
    inputs-disk.conf
    inputs-docker.conf
    outputs-influxdb.conf # Output config
    processors-rename.conf
```

### Agent-Level Settings

```toml
[agent]
  interval = "10s"                  # Collection interval
  round_interval = true             # Align to interval boundaries
  metric_batch_size = 5000          # Points per output write
  metric_buffer_limit = 100000      # Buffer size before dropping
  collection_jitter = "0s"          # Random jitter to prevent thundering herd
  flush_interval = "10s"            # Output flush interval
  flush_jitter = "5s"               # Random jitter for output flush
  precision = "0s"                  # 0 = nanosecond (default)
  hostname = ""                     # Override OS hostname
  omit_hostname = false
```

### Common Input Plugin Patterns

**System monitoring:**
```toml
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false
  core_tags = false

[[inputs.mem]]

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.diskio]]
  devices = ["sda", "sdb", "nvme0n1"]

[[inputs.net]]
  interfaces = ["eth*", "en*"]

[[inputs.system]]

[[inputs.processes]]
```

**Application monitoring:**
```toml
[[inputs.prometheus]]
  urls = ["http://localhost:9090/metrics"]
  metric_version = 2

[[inputs.http_response]]
  urls = ["https://myapp.example.com/health"]
  response_timeout = "5s"
  method = "GET"
  [inputs.http_response.tags]
    service = "myapp"

[[inputs.statsd]]
  protocol = "udp"
  service_address = ":8125"
  metric_separator = "_"
```

### Output Configuration for InfluxDB

**InfluxDB 2.x output:**
```toml
[[outputs.influxdb_v2]]
  urls = ["http://influxdb:8086"]
  token = "${INFLUX_TOKEN}"
  organization = "my-org"
  bucket = "monitoring"
  timeout = "10s"
  content_encoding = "gzip"
  [outputs.influxdb_v2.tagpass]
    # Only send specific tagged metrics to this output
    environment = ["production"]
```

**InfluxDB 3.x output (using v2 compatibility):**
```toml
[[outputs.influxdb_v2]]
  urls = ["http://influxdb3:8181"]
  token = "${INFLUX_TOKEN}"
  organization = ""
  bucket = "monitoring"
  timeout = "10s"
  content_encoding = "gzip"
```

---

## Operational Best Practices

### Deployment Sizing

**InfluxDB 2.x (single node):**

| Workload | Writes/sec | Series | RAM | CPU | Storage |
|---|---|---|---|---|---|
| Small | < 5K | < 100K | 4-8 GB | 2-4 cores | SSD, 100GB |
| Medium | 5K-50K | 100K-1M | 16-32 GB | 4-8 cores | SSD, 500GB |
| Large | 50K-250K | 1M-10M | 64-128 GB | 8-16 cores | NVMe, 2TB |
| Very large | > 250K | > 10M | 128+ GB | 16+ cores | NVMe RAID, 5TB+ |

**InfluxDB 3.x Core (single node):**

| Workload | Writes/sec | RAM | CPU | Storage |
|---|---|---|---|---|
| Small | < 10K | 4-8 GB | 2-4 cores | SSD or S3 |
| Medium | 10K-100K | 16-32 GB | 4-8 cores | SSD or S3 |
| Large | 100K-500K | 64-128 GB | 8-16 cores | NVMe + S3 |

**InfluxDB 3.x Enterprise (multi-node):**

| Role | RAM | CPU | Storage | Count |
|---|---|---|---|---|
| Writer | 16-64 GB | 4-8 cores | SSD (WAL) + S3 | 1-2 (HA) |
| Reader | 16-64 GB | 4-16 cores | Local cache + S3 | 2-15 |
| Compactor | 16-32 GB | 4-8 cores | S3 | 1 |

### Monitoring InfluxDB Itself

**Key metrics to monitor (from /metrics endpoint):**

For 2.x:
- `influxdb_write_requests_total` -- Write request count
- `influxdb_write_points_total` -- Points written
- `influxdb_write_errors_total` -- Write errors
- `influxdb_query_requests_total` -- Query request count
- `influxdb_query_request_duration_seconds` -- Query latency
- `go_memstats_heap_alloc_bytes` -- Heap memory usage
- `go_goroutines` -- Active goroutines
- `influxdb_tsm_compactions_active` -- Active compactions
- `influxdb_tsm_compactions_duration_seconds` -- Compaction duration

For 3.x:
- `http_api_request_duration_seconds` -- API request latency
- `influxdb3_write_lines_total` -- Lines written
- `influxdb3_write_errors_total` -- Write errors
- `influxdb3_wal_flush_duration_seconds` -- WAL flush latency
- `influxdb3_parquet_file_count` -- Parquet files in object store
- `process_resident_memory_bytes` -- Process memory

**Self-monitoring Telegraf config:**
```toml
[[inputs.influxdb]]
  urls = ["http://localhost:8086/debug/vars"]
  timeout = "5s"

[[inputs.prometheus]]
  urls = ["http://localhost:8086/metrics"]
  metric_version = 2
```

### Backup Strategy

**InfluxDB 2.x:**
```bash
# Automated daily backup script
#!/bin/bash
BACKUP_DIR="/backup/influxdb/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Full backup
influx backup "$BACKUP_DIR" --host http://localhost:8086 --token "$INFLUX_TOKEN"

# Verify backup
ls -la "$BACKUP_DIR"

# Rotate: keep last 30 days
find /backup/influxdb -maxdepth 1 -mtime +30 -type d -exec rm -rf {} +
```

**InfluxDB 3.x:**
```bash
# For local file object store
rsync -av /var/lib/influxdb3/ /backup/influxdb3/

# For S3 object store -- use AWS backup mechanisms
aws s3 sync s3://influxdb-data/ s3://influxdb-backup/ --storage-class GLACIER

# Catalog backup (critical -- metadata about all Parquet files)
cp /var/lib/influxdb3/catalog.sqlite /backup/influxdb3/catalog-$(date +%Y%m%d).sqlite
```

### Security Hardening

1. **Network:**
   - Run InfluxDB behind a reverse proxy (nginx, HAProxy) with TLS termination
   - Restrict API access to known IP ranges
   - Use private networking between Telegraf agents and InfluxDB

2. **Authentication:**
   - Never use the initial admin token in production applications
   - Create scoped tokens with minimum required permissions
   - Rotate tokens periodically
   - Store tokens in secrets managers (Vault, AWS Secrets Manager)

3. **Authorization (2.x):**
   - Use read-only tokens for dashboards and monitoring tools
   - Use write-only tokens for Telegraf agents
   - Use separate tokens per application/team

4. **Authorization (3.x):**
   - Create database-scoped tokens: `influxdb3 create token --read-db mydb`
   - Use admin tokens only for management operations
   - Enterprise: leverage multi-tenant isolation

5. **TLS configuration:**
```bash
# 2.x: Enable TLS
influxd --tls-cert /path/to/cert.pem --tls-key /path/to/key.pem

# 3.x: Use reverse proxy for TLS
# nginx example:
# server {
#   listen 443 ssl;
#   ssl_certificate /path/to/cert.pem;
#   ssl_certificate_key /path/to/key.pem;
#   location / {
#     proxy_pass http://localhost:8181;
#   }
# }
```

---

## Migration Best Practices

### Migrating from InfluxDB 2.x to 3.x

This is a major migration -- InfluxDB 3.x is a fundamentally different system:

| Aspect | 2.x | 3.x | Migration Impact |
|---|---|---|---|
| Storage engine | TSM | IOx (Parquet) | Full data export/import required |
| Query language | Flux | SQL + InfluxQL | Rewrite all Flux queries |
| Data organization | Orgs + Buckets | Databases + Tables | Rename/restructure |
| Tasks | Flux tasks | Processing engine (Python) | Rewrite automation |
| Dashboards | Built-in UI | External (Grafana) | Migrate to Grafana |
| Tokens | Org-scoped | Database-scoped | Recreate tokens |

**Migration steps:**
1. Export data from 2.x using `influx query` with CSV output
2. Transform the CSV to line protocol format
3. Create databases and tables in 3.x
4. Import data using `influxdb3 write` or the v2-compat write endpoint
5. Rewrite Flux queries as SQL
6. Recreate tasks as processing engine triggers
7. Update Telegraf outputs to point to 3.x
8. Update Grafana data sources

### Migrating from InfluxDB 1.x to 3.x

- InfluxDB 3.x supports InfluxQL, making query migration easier than from Flux
- Use `influx_inspect export` (1.x tool) to export data as line protocol
- Import line protocol directly into 3.x
- Continuous queries (1.x) must be rewritten as processing engine triggers
- Retention policies map to database-level configuration

---

## Troubleshooting Playbooks

### Playbook: Write Failures (HTTP 503)

**Symptoms:** Writes returning HTTP 503, write latency increasing, client timeouts.

**InfluxDB 2.x diagnosis:**
1. Check cache size: `curl localhost:8086/debug/vars | jq '.memstats.Alloc'`
2. If cache is at max, compaction cannot keep up
3. Check compaction queue: look for `influxdb_tsm_compactions_queued` in /metrics
4. Check disk I/O: `iostat -x 1` -- if disk utilization is 100%, storage is bottleneck
5. Resolution: Increase `cache-max-memory-size`, add faster storage, reduce write rate

**InfluxDB 3.x diagnosis:**
1. Check health: `curl localhost:8181/health`
2. Check WAL flush latency: look for `influxdb3_wal_flush_duration_seconds` in /metrics
3. Check object store connectivity (S3 timeouts, disk full)
4. Check memory: `process_resident_memory_bytes` metric
5. Resolution: Increase memory, check object store connectivity, reduce write rate

### Playbook: Slow Queries

**Symptoms:** Query latency exceeding expectations, query timeouts.

**InfluxDB 2.x:**
1. Verify time range is not too broad (do not query months of raw data)
2. Check if query uses pushdown-eligible predicates (measurement, tag, time)
3. Look for non-pushdown operations (regex on field values, complex Flux transformations)
4. Check cardinality: `SHOW SERIES CARDINALITY` -- if > 1M, this may be the cause
5. Check compaction status: fragmented TSM files slow reads

**InfluxDB 3.x:**
1. Run `EXPLAIN ANALYZE` on the query to see execution plan
2. Check partition pruning: the plan should show skipped partitions
3. Check if the query touches too many Parquet files (compaction may be behind)
4. Verify predicates enable pushdown (time range, tag equality)
5. Use Last Value Cache for "current value" queries
6. Use Distinct Value Cache for "list tags" queries

### Playbook: High Memory Usage

**InfluxDB 2.x:**
1. Check series cardinality: `SHOW SERIES CARDINALITY`
2. Check TSI memory: large cardinality = large in-memory index
3. Check cache size: `influxdb_cache_inuse_bytes` metric
4. Check Go heap: `go_memstats_heap_alloc_bytes` metric
5. Resolution: Reduce cardinality, increase `cache-snapshot-memory-size` to flush earlier

**InfluxDB 3.x:**
1. Check query memory pool: `--memory-pool-size` setting
2. Check process memory: `process_resident_memory_bytes` metric
3. Check for large query results materializing in memory
4. Resolution: Adjust `--memory-pool-size`, add LIMIT to queries, optimize query plans

### Playbook: Disk Space Growing Unexpectedly

**InfluxDB 2.x:**
1. Check shard sizes: look at data directory sizes
2. Check if retention policy is working: `influx bucket list` (verify retention period)
3. Check compaction status: uncompacted shards are larger
4. Check tombstone files: deleted data creates tombstones until compacted
5. Resolution: Wait for compaction, manually trigger with `influxd inspect compact-shards`

**InfluxDB 3.x:**
1. Check Parquet file count and sizes in object store
2. Check garbage collector status: old compacted files may not be cleaned up yet
3. Check retention configuration
4. Resolution: Verify garbage collector is running, check object store lifecycle policies
