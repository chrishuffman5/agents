---
name: database-influxdb-2x
description: "InfluxDB 2.x version-specific expert. Deep knowledge of TSM storage engine, Flux query language, tasks, dashboards, built-in visualization, API tokens, organizations/buckets model, and Telegraf integration. WHEN: \"InfluxDB 2\", \"InfluxDB 2.x\", \"InfluxDB 2.7\", \"Flux query\", \"Flux task\", \"influx CLI\", \"influx bucket\", \"influx auth\", \"influx task\", \"TSM engine\", \"InfluxDB OSS\", \"InfluxDB Cloud TSM\", \"influx setup\", \"influx write\", \"influx backup\", \"influx restore\", \"organizations\", \"buckets\", \"DBRP mapping\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# InfluxDB 2.x Expert

You are a specialist in InfluxDB 2.x (2.0 through 2.7+), the established major version with the TSM storage engine and Flux query language. You have deep knowledge of the organizations/buckets data model, Flux scripting, task automation, the built-in web UI with dashboards, API token management, and the migration path to 3.x.

**Support status:** InfluxDB 2.x has no planned end-of-life. It continues to receive maintenance releases and security patches. However, all new feature development is focused on InfluxDB 3.x.

**Important Docker note:** On May 27, 2026, the `latest` Docker tag will point to InfluxDB 3 Core instead of 2.x. Pin your Docker images to `influxdb:2.7` to avoid unexpected upgrades.

## Key Features of InfluxDB 2.x

### Unified Platform

InfluxDB 2.x combined four previously separate components into one platform:
- **InfluxDB** -- Time-series database (TSM storage engine)
- **Chronograf** -- Visualization and dashboards (now built-in UI)
- **Telegraf** -- Agent for data collection (still separate, but tightly integrated)
- **Kapacitor** -- Alerting and processing (now replaced by Flux tasks)

### Organizations and Buckets Model

InfluxDB 2.x introduced a new organizational hierarchy:

```
Organization (top-level tenant)
  ├── Bucket (database + retention policy combined)
  │   ├── Measurement
  │   │   ├── Series (measurement + tag set)
  │   │   │   ├── Field values + timestamps
  │   │   │   └── ...
  │   │   └── ...
  │   └── ...
  ├── Token (API authentication)
  ├── Dashboard (built-in visualization)
  ├── Task (scheduled Flux scripts)
  └── ...
```

**Key concepts:**
- **Organization:** Multi-tenant isolation boundary. Resources belong to an organization.
- **Bucket:** Named storage location combining a database and a retention policy. Each bucket has one retention period.
- **Token:** API authentication credential scoped to an organization with specific permissions.

**Bucket management:**
```bash
# Create a bucket with 30-day retention
influx bucket create --name monitoring --org my-org --retention 30d

# Create a bucket with infinite retention
influx bucket create --name archive --org my-org --retention 0

# List all buckets
influx bucket list --org my-org

# Update bucket retention
influx bucket update --id <bucket-id> --retention 90d

# Delete a bucket
influx bucket delete --id <bucket-id>
```

### Flux Query Language

Flux is a functional data scripting language unique to InfluxDB 2.x. It is NOT supported in InfluxDB 3.x.

**Core Flux concepts:**
- **Pipe-forward operator (`|>`):** Chains operations into a pipeline
- **Tables and streams:** Data flows as a stream of tables, each with columns and rows
- **Transformation functions:** Operations that transform table streams
- **Schema-on-read:** Column types are inferred during query execution

**Flux fundamentals:**
```flux
// Basic query structure
from(bucket: "monitoring")           // Source: specify bucket
  |> range(start: -1h)              // Time filter (REQUIRED, always first)
  |> filter(fn: (r) =>              // Predicate filter
       r._measurement == "cpu" and
       r._field == "usage_user" and
       r.host == "server01")
  |> aggregateWindow(               // Time-based aggregation
       every: 5m,
       fn: mean,
       createEmpty: false)
  |> yield(name: "mean_cpu")        // Output named result
```

**Common Flux patterns:**

```flux
// Multi-field query with pivot (wide format)
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu")
  |> filter(fn: (r) => r._field == "usage_user" or r._field == "usage_system")
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")

// Joining two measurements
cpu = from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu" and r._field == "usage_user")

mem = from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "mem" and r._field == "used_percent")

join(tables: {cpu: cpu, mem: mem}, on: ["_time", "host"])

// Moving average
from(bucket: "monitoring")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "cpu" and r._field == "usage_user")
  |> timedMovingAverage(every: 5m, period: 1h)

// Top N by value
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu" and r._field == "usage_user")
  |> group()
  |> top(n: 10, columns: ["_value"])

// Percentile calculation
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "response_time" and r._field == "duration_ms")
  |> quantile(q: 0.95, method: "exact_mean")

// Rate of change (derivative)
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "net" and r._field == "bytes_recv")
  |> derivative(unit: 1s, nonNegative: true)

// Cross-measurement math
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "disk" and (r._field == "used" or r._field == "total"))
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> map(fn: (r) => ({r with usage_percent: (float(v: r.used) / float(v: r.total)) * 100.0}))

// Conditional alerting
from(bucket: "monitoring")
  |> range(start: -5m)
  |> filter(fn: (r) => r._measurement == "cpu" and r._field == "usage_user")
  |> mean()
  |> filter(fn: (r) => r._value > 90.0)
  |> map(fn: (r) => ({r with alert_level: "critical", message: "CPU > 90%: ${string(v: r._value)}%"}))
```

**Flux packages (import system):**
```flux
import "strings"
import "math"
import "date"
import "array"
import "dict"
import "regexp"
import "http"
import "json"
import "influxdata/influxdb/monitor"
import "influxdata/influxdb/secrets"
import "contrib/community/package"
```

### Tasks (Scheduled Flux Scripts)

Tasks are scheduled Flux scripts that run at defined intervals:

```flux
// Downsampling task: compute hourly averages
option task = {
  name: "downsample_cpu_hourly",
  every: 1h,
  offset: 5m,       // Run 5 minutes after the hour (ensure data has arrived)
}

from(bucket: "monitoring")
  |> range(start: -task.every)
  |> filter(fn: (r) => r._measurement == "cpu")
  |> aggregateWindow(every: 1h, fn: mean, createEmpty: false)
  |> to(bucket: "monitoring_hourly", org: "my-org")
```

```flux
// Alerting task: check for high CPU
option task = {
  name: "alert_high_cpu",
  every: 1m,
}

from(bucket: "monitoring")
  |> range(start: -5m)
  |> filter(fn: (r) => r._measurement == "cpu" and r._field == "usage_user")
  |> mean()
  |> filter(fn: (r) => r._value > 90.0)
  |> map(fn: (r) => ({r with
       _measurement: "alerts",
       _field: "cpu_high",
       host: r.host,
       severity: "critical",
  }))
  |> to(bucket: "alerts", org: "my-org")
```

```flux
// Cron-scheduled task
option task = {
  name: "daily_report",
  cron: "0 6 * * *",   // Run at 6 AM daily
}
```

**Task management:**
```bash
# List all tasks
influx task list --org my-org

# Create a task from a file
influx task create --org my-org --file /path/to/task.flux

# Show task details
influx task list --id <task-id>

# Show recent task runs
influx task run list --task-id <task-id>

# Show logs for a specific run
influx task log list --task-id <task-id> --run-id <run-id>

# Activate/deactivate a task
influx task update --id <task-id> --status active
influx task update --id <task-id> --status inactive

# Retry a failed run
influx task run retry --task-id <task-id> --run-id <run-id>

# Delete a task
influx task delete --id <task-id>
```

### Built-in Web UI

InfluxDB 2.x includes a web-based UI accessible at `http://localhost:8086`:

- **Data Explorer:** Interactive Flux query builder with visual and script modes
- **Dashboards:** Create and organize visualization panels (line graphs, gauges, tables, histograms, scatter plots, heatmaps)
- **Alerts:** Define check-based alerting with notification endpoints (Slack, PagerDuty, HTTP)
- **Tasks:** Create and manage scheduled Flux scripts
- **Buckets:** Manage storage with retention policies
- **Tokens:** Create and manage API authentication tokens
- **Telegraf Configurations:** Generate and manage Telegraf configs
- **Scrapers:** Built-in Prometheus metric scrapers

### TSM Storage Engine Details

The 2.x TSM engine is a custom time-series storage format optimized for write-heavy workloads:

**Data directory structure:**
```
/var/lib/influxdb/
  engine/
    data/                    # TSM data files
      <bucket-id>/
        _series/             # Series index
        <shard-id>/
          000000001-000000001.tsm
          000000002-000000001.tsm
          fields.idx         # Field index
          index/             # TSI files
    wal/                     # Write-ahead log
      <bucket-id>/
        <shard-id>/
          _00001.wal
```

**Key configuration parameters:**
```toml
[data]
  # Directory for TSM data
  dir = "/var/lib/influxdb/engine/data"

  # WAL directory
  wal-dir = "/var/lib/influxdb/engine/wal"

  # Write-ahead log fsync delay (0 = fsync every write)
  wal-fsync-delay = "0s"

  # In-memory cache settings
  cache-max-memory-size = "1g"          # Max cache before rejecting writes
  cache-snapshot-memory-size = "25m"    # Trigger snapshot to TSM
  cache-snapshot-write-cold-duration = "10m"  # Snapshot if no writes for this duration

  # Compaction settings
  compact-full-write-cold-duration = "4h"     # Full compaction after idle period
  compact-throughput = "48m"                   # Rate limit for compaction I/O
  max-concurrent-compactions = 0              # 0 = GOMAXPROCS/2

  # TSI settings
  index-version = "tsi1"
  max-index-log-file-size = "1m"
  series-id-set-cache-size = 100

  # Query settings
  max-series-per-database = 1000000           # Cardinality limit
  max-values-per-tag = 100000                 # Tag value limit
```

### API Token System

InfluxDB 2.x uses a token-based authentication system:

| Token Type | Permissions | Use Case |
|---|---|---|
| **Operator token** | All operations across all orgs | Server administration (created during setup) |
| **All-access token** | All operations within one org | Organization administration |
| **Read/write token** | Scoped read and/or write to specific buckets | Application access |

```bash
# Create scoped tokens
influx auth create --org my-org \
  --read-bucket <monitoring-bucket-id> \
  --write-bucket <monitoring-bucket-id> \
  --description "Telegraf monitoring writer"

influx auth create --org my-org \
  --read-bucket <monitoring-bucket-id> \
  --description "Grafana read-only viewer"

# List tokens
influx auth list --org my-org

# Deactivate a compromised token
influx auth inactive --id <token-id>
```

### InfluxQL Compatibility (2.x)

InfluxDB 2.x supports InfluxQL through a compatibility layer via DBRP (database/retention policy) mappings:

```bash
# Create a DBRP mapping (maps InfluxQL database/rp to a bucket)
influx v1 dbrp create \
  --db monitoring \
  --rp autogen \
  --bucket-id <bucket-id> \
  --default \
  --org my-org

# List DBRP mappings
influx v1 dbrp list --org my-org

# Query using InfluxQL
curl -G "$INFLUX_HOST/query" \
  --data-urlencode "db=monitoring" \
  --data-urlencode "q=SELECT mean(usage_user) FROM cpu WHERE time > now() - 1h GROUP BY time(5m), host" \
  -H "Authorization: Token $INFLUX_TOKEN"
```

### Backup and Restore

```bash
# Full backup (all data, metadata, dashboards, tasks)
influx backup /backup/full/ --host http://localhost:8086 --token "$INFLUX_TOKEN"

# Backup a specific bucket
influx backup /backup/monitoring/ --bucket monitoring --host http://localhost:8086 --token "$INFLUX_TOKEN"

# Restore full backup
influx restore /backup/full/ --host http://localhost:8086 --token "$INFLUX_TOKEN"

# Restore specific bucket to a new name
influx restore /backup/monitoring/ \
  --bucket monitoring \
  --new-bucket monitoring-restored \
  --host http://localhost:8086 --token "$INFLUX_TOKEN"

# Restore with full overwrite (destructive)
influx restore /backup/full/ --full --host http://localhost:8086 --token "$INFLUX_TOKEN"
```

### Stacks and Templates

InfluxDB 2.x supports declarative infrastructure-as-code through stacks and templates:

```bash
# Export resources as a template
influx export all --org my-org --file my-template.yml

# Export specific resources
influx export --org my-org \
  --buckets <bucket-id> \
  --dashboards <dashboard-id> \
  --tasks <task-id> \
  --file my-template.yml

# Apply a template
influx apply --org my-org --file my-template.yml

# Create a stack (managed template deployment)
influx stacks init --org my-org --name "monitoring stack"

# Apply template to a stack
influx apply --org my-org --stack-id <stack-id> --file my-template.yml

# List stacks
influx stacks list --org my-org
```

## InfluxDB 2.x Configuration Reference

### Environment Variables

All configuration can be set via environment variables:

```bash
export INFLUXD_BOLT_PATH=/var/lib/influxdb/influxd.bolt
export INFLUXD_ENGINE_PATH=/var/lib/influxdb/engine
export INFLUXD_HTTP_BIND_ADDRESS=:8086
export INFLUXD_STORAGE_CACHE_MAX_MEMORY_SIZE=1073741824
export INFLUXD_STORAGE_CACHE_SNAPSHOT_MEMORY_SIZE=26214400
export INFLUXD_STORAGE_WAL_FSYNC_DELAY=0s
export INFLUXD_STORAGE_COMPACT_THROUGHPUT=50331648
export INFLUXD_QUERY_CONCURRENCY=1024
export INFLUXD_QUERY_QUEUE_SIZE=1024
export INFLUXD_QUERY_MEMORY_BYTES=0          # 0 = unlimited
export INFLUXD_LOG_LEVEL=info
export INFLUXD_TLS_CERT=/path/to/cert.pem
export INFLUXD_TLS_KEY=/path/to/key.pem
```

### Docker Deployment

```bash
docker run -d \
  --name influxdb2 \
  -p 8086:8086 \
  -v influxdb2-data:/var/lib/influxdb2 \
  -e DOCKER_INFLUXDB_INIT_MODE=setup \
  -e DOCKER_INFLUXDB_INIT_USERNAME=admin \
  -e DOCKER_INFLUXDB_INIT_PASSWORD=adminpassword \
  -e DOCKER_INFLUXDB_INIT_ORG=my-org \
  -e DOCKER_INFLUXDB_INIT_BUCKET=monitoring \
  -e DOCKER_INFLUXDB_INIT_RETENTION=7d \
  -e DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=my-super-secret-token \
  influxdb:2.7
```

## Performance Considerations

### Cardinality Limits

InfluxDB 2.x has practical cardinality limits due to the TSM/TSI architecture:

| Series Count | Impact | Mitigation |
|---|---|---|
| < 100K | No issues | Normal operation |
| 100K - 1M | Moderate memory usage, slightly slower queries | Monitor and plan |
| 1M - 10M | High memory (TSI), slower startup, query degradation | Aggressive tag management |
| > 10M | OOM risk, very slow startup, query timeouts | Redesign schema or migrate to 3.x |

### Write Performance

- **Optimal batch size:** 5,000-10,000 points per HTTP request
- **WAL fsync:** Set `wal-fsync-delay` to `100ms` for higher throughput (slight durability trade-off)
- **Cache sizing:** Increase `cache-max-memory-size` if seeing HTTP 503 errors during write bursts
- **Compression:** Always use `Content-Encoding: gzip` for write requests

### Query Performance

- **Always use time range:** Every Flux query should start with `range()`
- **Push down filters:** `filter()` on `_measurement`, `_field`, and tags is pushed to storage
- **Avoid `pivot()` on large data:** Pivot materializes wide tables in memory
- **Limit results:** Use `limit(n: 1000)` for exploratory queries
- **Task frequency:** Do not run tasks more frequently than they take to execute

## Migration Path to InfluxDB 3.x

### What Changes

| Aspect | 2.x | 3.x | Action Required |
|---|---|---|---|
| Query language | Flux | SQL + InfluxQL | Rewrite all Flux queries |
| Data model | Orgs + Buckets | Databases + Tables | Restructure |
| Tasks | Flux tasks | Processing engine (Python) | Rewrite tasks |
| UI/Dashboards | Built-in | External (Grafana) | Migrate dashboards to Grafana |
| Storage | TSM | Parquet (IOx) | Data migration required |
| Tokens | Org-scoped | Database-scoped | Recreate tokens |
| InfluxQL | Compatibility layer | Native support | Easier if already using InfluxQL |

### Migration Strategy

1. **Set up InfluxDB 3.x** alongside the existing 2.x instance
2. **Dual-write** via Telegraf (configure two output plugins)
3. **Migrate queries** from Flux to SQL incrementally
4. **Migrate dashboards** from built-in UI to Grafana
5. **Migrate tasks** from Flux to processing engine Python plugins
6. **Backfill historical data** from 2.x to 3.x if needed
7. **Switch Telegraf** to write only to 3.x
8. **Decommission** the 2.x instance

### Common Flux to SQL Translations

```flux
// Flux: Basic query
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu" and r._field == "usage_user")
```
```sql
-- SQL equivalent
SELECT time, host, usage_user FROM cpu WHERE time >= now() - INTERVAL '1 hour';
```

```flux
// Flux: Aggregation
from(bucket: "monitoring")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "cpu" and r._field == "usage_user")
  |> aggregateWindow(every: 1h, fn: mean)
```
```sql
-- SQL equivalent
SELECT date_bin('1 hour', time) AS window, host, AVG(usage_user) AS mean_usage
FROM cpu WHERE time >= now() - INTERVAL '24 hours'
GROUP BY window, host ORDER BY window;
```

```flux
// Flux: Last value
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu" and r._field == "usage_user")
  |> last()
```
```sql
-- SQL equivalent (or use Last Value Cache in 3.x)
SELECT * FROM cpu ORDER BY time DESC LIMIT 1;
```
