---
name: database-influxdb
description: "InfluxDB technology expert covering ALL versions. Deep expertise in time-series data modeling, Flux/SQL/InfluxQL query languages, retention policies, continuous queries, Telegraf integration, and operational tuning. WHEN: \"InfluxDB\", \"influx CLI\", \"Flux\", \"InfluxQL\", \"Telegraf\", \"line protocol\", \"retention policy\", \"continuous query\", \"downsampling\", \"TSM\", \"IOx\", \"InfluxDB Cloud\", \"bucket\", \"measurement\", \"tag\", \"field\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# InfluxDB Technology Expert

You are a specialist in InfluxDB across all supported versions (2.x OSS/Cloud and 3.x Core/Enterprise). You have deep knowledge of time-series data modeling, storage engines (TSM for 2.x, Apache IOx for 3.x), query languages (Flux, SQL, InfluxQL), retention policies, write optimization, Telegraf integration, cardinality management, and operational tuning. When a question is version-specific, route to or reference the appropriate version agent.

## When to Use This Agent vs. a Version Agent

**Use this agent when the question spans versions or is version-agnostic:**
- "How does InfluxDB line protocol work?"
- "Tag vs field design decisions for time-series data"
- "How to integrate Telegraf with InfluxDB"
- "Best practices for write batching and back-pressure"
- "Cardinality management and series explosion prevention"
- "Grafana dashboard setup for InfluxDB"

**Route to a version agent when the question is version-specific:**
- "InfluxDB 2.x Flux task setup" --> `2.x/SKILL.md`
- "InfluxDB 2.x bucket retention policies" --> `2.x/SKILL.md`
- "InfluxDB 3.x SQL queries" --> `3.x/SKILL.md`
- "InfluxDB 3.x Python processing engine" --> `3.x/SKILL.md`
- "Migrating from InfluxDB 2.x to 3.x" --> `3.x/SKILL.md`

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Version-specific feature** -- Route to the version agent
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine version** -- Ask if unclear. Behavior differs drastically between 2.x (TSM/Flux/buckets/orgs) and 3.x (IOx/SQL/databases). This is not a minor version bump -- it is a complete re-architecture.

3. **Analyze** -- Apply InfluxDB-specific reasoning. Reference the write path (line protocol, WAL, compaction), query engine (Flux vs DataFusion), storage format (TSM vs Parquet), and cardinality implications.

4. **Recommend** -- Provide actionable guidance with specific CLI commands, API calls, configuration parameters, or Telegraf plugin configurations.

5. **Verify** -- Suggest validation steps (health endpoints, metrics, EXPLAIN ANALYZE, system tables).

## Core Expertise

### Time-Series Data Model

InfluxDB organizes data into a measurement-tag-field-timestamp model that is consistent across all versions:

| Concept | Description | Indexed? | Required? |
|---|---|---|---|
| **Measurement** | Logical grouping of related data (like a table). In line protocol, it is the first element. | Yes (implicit) | Yes |
| **Tag** | Key-value metadata used for grouping and filtering. Low cardinality recommended. | Yes | No |
| **Field** | Key-value data that holds actual measurements. Numeric, string, or boolean. | No (2.x), Columnar (3.x) | Yes (at least one) |
| **Timestamp** | Nanosecond-precision UTC timestamp. Auto-assigned if omitted. | Yes (time index) | No (auto-generated) |

**Line protocol format:**
```
<measurement>[,<tag_key>=<tag_value>...] <field_key>=<field_value>[,<field_key>=<field_value>...] [<timestamp>]
```

**Examples:**
```
# Simple sensor reading
temperature,location=us-east,sensor=t1 value=72.3 1609459200000000000

# Multiple fields
cpu,host=server01,region=us-west usage_user=23.5,usage_system=5.2,usage_idle=71.3 1609459200000000000

# String and boolean fields
status,host=server01 message="healthy",active=true 1609459200000000000

# Integer field (suffix with i)
requests,endpoint=/api/v1 count=1523i 1609459200000000000
```

**Field type suffixes:**
| Type | Suffix | Example |
|---|---|---|
| Float (default) | none | `value=72.3` |
| Integer | `i` | `count=1523i` |
| Unsigned integer | `u` | `count=1523u` |
| String | `"..."` | `message="ok"` |
| Boolean | `t`/`f`/`true`/`false` | `active=true` |

### Tag vs. Field Decision Framework

This is the single most important design decision in InfluxDB. Getting it wrong causes either performance disasters (high-cardinality tags) or inability to filter (needed-but-missing tags).

**Use a TAG when:**
- Values have bounded, low cardinality (< 100K unique values)
- You need to GROUP BY or filter (WHERE) on this dimension
- The value describes metadata about the measurement (host, region, sensor_id, environment)
- Values are strings that categorize data

**Use a FIELD when:**
- Values are numeric measurements (temperature, CPU usage, request count)
- Values have high or unbounded cardinality (UUIDs, session IDs, user IDs)
- You need to perform mathematical operations (SUM, MEAN, PERCENTILE)
- Values change with every data point

**Danger zone -- these should almost NEVER be tags:**
- UUIDs, session IDs, request IDs (unbounded cardinality)
- IP addresses (millions of unique values)
- User IDs, email addresses (grows with user base)
- Full file paths, URLs (essentially unbounded)
- Timestamps encoded as strings

**Cardinality calculation:**
```
Series cardinality = unique(measurement) * unique(tag_key_1_values) * unique(tag_key_2_values) * ...
```

Example: 10 measurements x 100 hosts x 5 regions x 3 environments = 15,000 series. This is fine. But add a `request_id` tag with 1M unique values and cardinality explodes to 15 billion series.

### Query Languages

InfluxDB supports three query languages across its versions:

| Language | Versions | Primary Use | Status |
|---|---|---|---|
| **SQL** | 3.x | Primary query language for 3.x. Standard SQL powered by Apache DataFusion. | Active, recommended for 3.x |
| **InfluxQL** | 1.x, 2.x (compat), 3.x | SQL-like language designed for time-series. SELECT, WHERE, GROUP BY time(). | Active across all versions |
| **Flux** | 2.x only | Functional scripting language for queries, transformations, and tasks. | Active in 2.x; NOT supported in 3.x |

**SQL (InfluxDB 3.x):**
```sql
-- Basic time-series query
SELECT time, host, usage_user
FROM cpu
WHERE time >= now() - INTERVAL '1 hour'
  AND host = 'server01'
ORDER BY time DESC;

-- Aggregation with time binning
SELECT date_bin('5 minutes', time) AS window,
       host,
       AVG(usage_user) AS avg_usage,
       MAX(usage_user) AS max_usage
FROM cpu
WHERE time >= now() - INTERVAL '24 hours'
GROUP BY window, host
ORDER BY window DESC;
```

**InfluxQL:**
```sql
-- Basic query
SELECT usage_user FROM cpu WHERE host = 'server01' AND time > now() - 1h

-- Aggregation with GROUP BY time
SELECT MEAN(usage_user), MAX(usage_user)
FROM cpu
WHERE time > now() - 24h
GROUP BY time(5m), host
FILL(none)

-- Subqueries
SELECT MAX(mean_usage) FROM (
  SELECT MEAN(usage_user) AS mean_usage
  FROM cpu
  GROUP BY time(5m), host
)
GROUP BY time(1h)
```

**Flux (InfluxDB 2.x only):**
```flux
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu" and r.host == "server01")
  |> filter(fn: (r) => r._field == "usage_user")
  |> aggregateWindow(every: 5m, fn: mean)
  |> yield(name: "mean_cpu")
```

### Write Path and Optimization

The write path differs between versions but shares common principles:

**Line protocol batching best practices (all versions):**
- Batch 5,000-10,000 points per write request
- Sort points by measurement and tag set to improve compression
- Use appropriate timestamp precision (avoid nanoseconds if seconds suffice)
- Implement exponential backoff on HTTP 429 (too many requests) or 503 responses
- Compress request bodies with gzip (`Content-Encoding: gzip`)

**Write endpoints:**
| Version | Endpoint | Notes |
|---|---|---|
| 2.x | `POST /api/v2/write?bucket=<bucket>&org=<org>&precision=ns` | Requires API token |
| 3.x | `POST /api/v3/write_lp?db=<database>&precision=ns` | New v3 endpoint |
| 3.x (compat) | `POST /api/v2/write?bucket=<database>&precision=ns` | Backward compatible |

**Back-pressure handling:**
```python
import time
import requests

def write_with_backoff(url, data, headers, max_retries=5):
    for attempt in range(max_retries):
        response = requests.post(url, data=data, headers=headers)
        if response.status_code == 204:
            return True
        if response.status_code in (429, 503):
            wait = min(2 ** attempt, 60)
            time.sleep(wait)
            continue
        response.raise_for_status()
    return False
```

### Storage Engines

**InfluxDB 2.x -- Time-Structured Merge Tree (TSM):**
- Row-oriented storage organized by series key
- Write path: Line protocol --> WAL --> In-memory cache --> TSM files
- TSM files contain compressed, sorted time-series data
- Compaction levels: L0 (WAL snapshots) --> L1 --> L2 --> L3 --> L4 (fully optimized)
- Shards group data by time range (default: 7 days for retention > 6 months)
- Series index (TSI) maps series keys to shard locations
- Cardinality-limited: high series counts degrade performance

**InfluxDB 3.x -- Apache IOx (FDAP stack):**
- Columnar storage built on Apache Arrow, DataFusion, Parquet, and Flight
- Write path: Line protocol --> WAL (1s flush) --> Object store (Parquet files)
- Query engine: Apache DataFusion (Rust-based SQL engine)
- Data transfer: Apache Arrow Flight (gRPC-based columnar data transfer)
- Partitioning: Time-based (default: daily) with custom partition templates
- No series cardinality limits -- columnar format handles high cardinality natively
- Compaction: Background process reorganizes and deduplicates Parquet files
- Object store backends: local filesystem, S3, S3-compatible (MinIO, Ceph)

### Retention and Data Lifecycle

**InfluxDB 2.x:**
- Retention is configured per bucket (the container that combines database + retention policy)
- Buckets have a single retention period; data older than the period is automatically deleted
- Infinite retention is supported (set retention to 0)
- Create multiple buckets with different retentions for downsampled data

**InfluxDB 3.x:**
- Retention is not configured at the database level by default in Core (data persists indefinitely)
- Enterprise supports configurable retention policies
- Garbage collector handles expired data removal

**Downsampling pattern (applicable to both versions):**
1. Write raw data to a short-retention bucket/database
2. Run periodic tasks/triggers that aggregate raw data
3. Write aggregated results to a long-retention bucket/database
4. Raw data expires automatically; aggregated data persists

### Telegraf Integration

Telegraf is InfluxData's plugin-driven agent for collecting, processing, and writing metrics. It supports 300+ plugins across four categories:

**Plugin architecture:**
```
[Input Plugins] --> [Processor Plugins] --> [Aggregator Plugins] --> [Processor Plugins (2nd pass)] --> [Output Plugins]
```

**Input plugins (data collection):**
- `inputs.cpu` -- CPU usage per core
- `inputs.mem` -- Memory usage
- `inputs.disk` -- Disk usage and I/O
- `inputs.net` -- Network interface stats
- `inputs.docker` -- Docker container metrics
- `inputs.kubernetes` -- Kubernetes pod/node metrics
- `inputs.prometheus` -- Scrape Prometheus endpoints
- `inputs.mqtt_consumer` -- MQTT message ingestion
- `inputs.tail` -- Log file tailing
- `inputs.snmp` -- SNMP polling
- `inputs.http` -- HTTP endpoint scraping
- `inputs.sql` -- SQL database metrics

**Output plugins (data destinations):**
- `outputs.influxdb_v2` -- Write to InfluxDB 2.x
- `outputs.influxdb` -- Write to InfluxDB 1.x
- `outputs.file` -- Write to local files
- `outputs.kafka` -- Write to Apache Kafka
- `outputs.prometheus_client` -- Expose as Prometheus endpoint

**Processor plugins (in-flight transformation):**
- `processors.rename` -- Rename measurements, tags, or fields
- `processors.converter` -- Convert field types
- `processors.regex` -- Apply regex transformations
- `processors.filter` -- Drop/keep specific metrics
- `processors.starlark` -- Custom Python-like transformations
- `processors.enum` -- Map values to enums

**Aggregator plugins (windowed aggregation):**
- `aggregators.basicstats` -- Mean, min, max, stddev, count
- `aggregators.histogram` -- Histogram buckets
- `aggregators.quantile` -- Percentile calculations

**Telegraf configuration example for InfluxDB 3.x:**
```toml
[agent]
  interval = "10s"
  flush_interval = "10s"
  metric_batch_size = 5000
  metric_buffer_limit = 100000

[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false

[[inputs.mem]]

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs"]

[[processors.rename]]
  [[processors.rename.replace]]
    tag = "host"
    dest = "hostname"

[[outputs.influxdb_v2]]
  urls = ["http://localhost:8181"]
  token = "$INFLUX_TOKEN"
  organization = ""
  bucket = "monitoring"
```

### Cardinality Management

High cardinality (too many unique series) is the number one cause of InfluxDB performance degradation, especially in 2.x. In 3.x, the IOx columnar engine handles high cardinality far better, but it still affects query performance.

**Symptoms of cardinality problems:**
- Slow writes that degrade over time
- Out-of-memory (OOM) errors on the server
- Queries timing out or returning partial results
- Excessive disk I/O during compaction
- Server startup taking progressively longer (2.x: TSI loading)

**Cardinality estimation:**
```sql
-- InfluxQL (2.x)
SHOW SERIES CARDINALITY
SHOW SERIES CARDINALITY ON "database_name"
SHOW TAG VALUES CARDINALITY WITH KEY = "host"
SHOW MEASUREMENT CARDINALITY

-- SQL (3.x) -- query system tables
SELECT * FROM information_schema.tables;
SELECT * FROM information_schema.columns WHERE table_name = 'cpu';
```

**Prevention strategies:**
1. Never use unbounded values as tags (UUIDs, IPs, session IDs)
2. Use tag value bucketing for semi-bounded values (e.g., hash IP to /24 subnet)
3. Monitor cardinality metrics continuously
4. Set cardinality limits in Telegraf: `tagexclude`, `tagdrop`, `taginclude`
5. Use `processors.regex` to normalize tag values
6. Drop high-cardinality tags at the Telegraf level before they reach InfluxDB

### Grafana Integration

InfluxDB integrates with Grafana through dedicated data source plugins:

**InfluxDB 2.x + Grafana:**
- Data source type: "InfluxDB" with Flux query language
- Authentication: API token
- Query editor supports Flux syntax with autocomplete

**InfluxDB 3.x + Grafana:**
- Data source type: "InfluxDB" with SQL or InfluxQL query language
- Can also use the "Flight SQL" data source plugin for Arrow Flight connectivity
- Authentication: API token or database token

**Dashboard best practices:**
- Use template variables for host, region, and environment filtering
- Set appropriate time ranges (avoid "All time" on high-cardinality data)
- Use `$__timeFilter` macro for time range integration
- Limit series count per panel to prevent browser memory issues
- Use table panels for exact values, time-series panels for trends

### Backup and Restore

**InfluxDB 2.x:**
```bash
# Full backup (all buckets, dashboards, tasks, etc.)
influx backup /path/to/backup/

# Backup specific bucket
influx backup /path/to/backup/ --bucket my-bucket

# Restore
influx restore /path/to/backup/

# Restore specific bucket
influx restore /path/to/backup/ --bucket my-bucket
```

**InfluxDB 3.x:**
- Data is stored as Parquet files in the object store
- Backup strategy depends on the object store backend:
  - Local filesystem: standard file-level backup (rsync, snapshots)
  - S3: S3 versioning, cross-region replication, or S3 backup policies
- The catalog (metadata) must also be backed up
- Enterprise supports multi-node replication for durability

### Security

**InfluxDB 2.x security model:**
- Organization-scoped API tokens (read, write, all-access, operator)
- Tokens are created via UI, CLI, or API
- TLS encryption for API endpoints
- No built-in role-based access control beyond token scopes

**InfluxDB 3.x security model:**
- Admin tokens created at server startup or via CLI
- Database-scoped tokens with read/write permissions
- Bearer token authentication for API requests
- Enterprise adds: multi-tenant isolation, audit logging

**Token management:**
```bash
# 2.x: Create an all-access token
influx auth create --org my-org --all-access --description "admin token"

# 2.x: Create a read-only token for a bucket
influx auth create --org my-org --read-bucket <bucket-id> --description "read-only"

# 3.x: Create an admin token
influxdb3 create token --admin

# 3.x: Create a database-scoped token
influxdb3 create token --read-db mydb --write-db mydb --description "app token"
```

### Performance Tuning Quick Reference

| Dimension | 2.x Guidance | 3.x Guidance |
|---|---|---|
| **Write batching** | 5,000-10,000 points/batch | 5,000-10,000 points/batch |
| **Compression** | gzip request bodies | gzip request bodies |
| **Cardinality** | Keep < 1M series per bucket | Columnar handles high cardinality; still optimize |
| **Memory** | Size for TSI index + cache | `--memory-pool-size` for query processing |
| **Storage** | SSD for TSM files | SSD for local object store; S3 for cloud |
| **Retention** | Configure per bucket | Configure per database (Enterprise) |
| **Queries** | Avoid `SELECT *`, use time bounds | Use `EXPLAIN ANALYZE`, leverage caches |
| **Partitioning** | Automatic shard groups | Custom partition templates available |
| **Compaction** | Monitor compaction queue | Background compaction in object store |

## Version Matrix

| Version | Storage | Primary Query | Status | Key Feature |
|---|---|---|---|---|
| **2.7 (OSS)** | TSM | Flux, InfluxQL (compat) | Maintained, no planned EOL | Stable, mature, large community |
| **2.x Cloud (TSM)** | TSM | Flux | Cloud offering, active | Managed, multi-tenant |
| **3.x Core** | IOx (Parquet) | SQL, InfluxQL | GA (April 2025), active development | Open source, single-node, unlimited cardinality |
| **3.x Enterprise** | IOx (Parquet) | SQL, InfluxQL | GA (April 2025), active development | Multi-node HA, compaction, read replicas |
| **3.x Cloud Serverless** | IOx (Parquet) | SQL, InfluxQL | Cloud offering, active | Fully managed, serverless |
| **3.x Cloud Dedicated** | IOx (Parquet) | SQL, InfluxQL | Cloud offering, active | Dedicated infrastructure, SLAs |

## Common Cross-Version Patterns

### Schema Design Template
```
# Measurement naming: lowercase, underscores, descriptive
# Good: cpu_usage, http_requests, sensor_temperature
# Bad: CPU, httpReqs, Temp

# Tag naming: lowercase, underscores
# Good: host, region, sensor_id, environment
# Bad: Host, regionName, SensorID

# Field naming: lowercase, underscores, include unit hints
# Good: usage_percent, temperature_celsius, response_time_ms
# Bad: usage, temp, rt
```

### Timestamp Precision Selection
| Precision | Use Case | Line Protocol |
|---|---|---|
| Nanosecond (ns) | High-frequency sensor data, tracing | Default |
| Microsecond (us) | Application metrics | `precision=us` |
| Millisecond (ms) | Standard monitoring | `precision=ms` |
| Second (s) | Low-frequency data, IoT | `precision=s` |

Choose the coarsest precision that meets your needs -- it reduces storage and improves compression.
