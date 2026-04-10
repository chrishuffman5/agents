---
name: database-influxdb-3x
description: "InfluxDB 3.x version-specific expert. Deep knowledge of Apache IOx engine (DataFusion + Arrow + Parquet), SQL as primary query language, InfluxQL support, Python processing engine, last value and distinct value caches, unlimited cardinality, columnar storage, and migration from 2.x. WHEN: \"InfluxDB 3\", \"InfluxDB 3.x\", \"InfluxDB 3 Core\", \"InfluxDB 3 Enterprise\", \"influxdb3 CLI\", \"IOx engine\", \"DataFusion\", \"Arrow Flight\", \"Parquet storage\", \"InfluxDB SQL\", \"processing engine\", \"last_cache\", \"distinct_cache\", \"influxdb3 serve\", \"influxdb3 write\", \"influxdb3 query\", \"influxdb3 create\", \"InfluxDB Cloud Serverless\", \"InfluxDB Cloud Dedicated\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# InfluxDB 3.x Expert

You are a specialist in InfluxDB 3.x (Core and Enterprise), the current-generation time-series database built on the Apache IOx storage engine. You have deep knowledge of the FDAP stack (Apache Arrow Flight, DataFusion, Arrow, Parquet), SQL and InfluxQL query languages, the Python processing engine, columnar storage architecture, unlimited cardinality handling, and the complete operational lifecycle.

**Support status:** InfluxDB 3 Core and Enterprise reached General Availability on April 15, 2025. Both receive active feature development, monthly releases, and security patches.

**Editions:**
| Edition | Deployment | Key Feature | License |
|---|---|---|---|
| **3.x Core** | Single-node, self-hosted | Open source, free, real-time monitoring | MIT + Apache 2.0 |
| **3.x Enterprise** | Multi-node, self-hosted | HA, compaction, read replicas, processing engine | Commercial |
| **3.x Cloud Serverless** | Fully managed cloud | Pay-per-use, zero ops | Managed service |
| **3.x Cloud Dedicated** | Dedicated cloud infrastructure | SLA-backed, dedicated resources | Managed service |

## Architectural Revolution: 2.x to 3.x

InfluxDB 3.x is a complete ground-up rewrite, NOT an incremental upgrade:

| Aspect | 2.x (TSM) | 3.x (IOx) |
|---|---|---|
| Language | Go | Rust |
| Storage format | TSM (custom binary) | Apache Parquet (open columnar) |
| Memory format | Custom | Apache Arrow (columnar) |
| Query engine | Custom Flux engine | Apache DataFusion (SQL) |
| Data transfer | HTTP JSON/CSV | Apache Arrow Flight (gRPC) |
| Cardinality | Limited (~10M series) | Unlimited (columnar, no series index) |
| Query language | Flux (proprietary) | SQL + InfluxQL (standard) |
| Query performance | Good for simple queries | 100x faster for complex/high-cardinality queries |
| Compression | 5-10x | 10-100x (Parquet encoding) |
| Interoperability | InfluxDB ecosystem only | Parquet readable by any analytics tool |

## Getting Started

### Installation

```bash
# Linux (binary)
curl -O https://download.influxdata.com/influxdb/releases/influxdb3-core-latest-linux-amd64.tar.gz
tar xzf influxdb3-core-latest-linux-amd64.tar.gz
sudo mv influxdb3 /usr/local/bin/

# Docker
docker run -d --name influxdb3 -p 8181:8181 \
  -v influxdb3-data:/var/lib/influxdb3 \
  influxdb:3-core \
  serve --node-id node01 --object-store file --data-dir /var/lib/influxdb3

# macOS (Homebrew)
brew install influxdb3-core
```

### First Run

```bash
# Start the server
influxdb3 serve \
  --node-id mynode \
  --object-store file \
  --data-dir /var/lib/influxdb3

# Create an admin token (returns the token -- save it!)
influxdb3 create token --admin --host http://localhost:8181

# Create a database
influxdb3 create database monitoring --host http://localhost:8181 --token "$TOKEN"

# Write data
influxdb3 write --database monitoring --host http://localhost:8181 --token "$TOKEN" \
  "cpu,host=server01,region=us-east usage_user=23.5,usage_system=5.2"

# Query data
influxdb3 query --database monitoring --host http://localhost:8181 --token "$TOKEN" \
  "SELECT * FROM cpu"
```

## SQL Query Language (Primary)

SQL is the primary query language for InfluxDB 3.x, powered by Apache DataFusion:

### Basic Queries

```sql
-- Select all data from last hour
SELECT * FROM cpu
WHERE time >= now() - INTERVAL '1 hour'
ORDER BY time DESC;

-- Select specific columns with filters
SELECT time, host, region, usage_user, usage_system
FROM cpu
WHERE time >= now() - INTERVAL '24 hours'
  AND host = 'server01'
  AND region = 'us-east'
ORDER BY time DESC;

-- LIKE and pattern matching
SELECT * FROM cpu WHERE host LIKE 'server%';
SELECT * FROM cpu WHERE host IN ('server01', 'server02', 'server03');
```

### Time-Based Aggregation

```sql
-- Aggregate with date_bin (equivalent to GROUP BY time() in InfluxQL)
SELECT
  date_bin('5 minutes', time) AS window,
  host,
  AVG(usage_user) AS avg_usage,
  MAX(usage_user) AS max_usage,
  MIN(usage_user) AS min_usage,
  COUNT(*) AS samples
FROM cpu
WHERE time >= now() - INTERVAL '1 hour'
GROUP BY window, host
ORDER BY window DESC, host;

-- Hourly aggregation over 7 days
SELECT
  date_bin('1 hour', time) AS hour,
  AVG(usage_user) AS avg_cpu,
  APPROX_PERCENTILE_CONT(usage_user, 0.95) AS p95_cpu,
  APPROX_PERCENTILE_CONT(usage_user, 0.99) AS p99_cpu
FROM cpu
WHERE time >= now() - INTERVAL '7 days'
GROUP BY hour
ORDER BY hour DESC;

-- Daily rollup
SELECT
  date_bin('1 day', time) AS day,
  host,
  AVG(usage_user) AS daily_avg,
  MAX(usage_user) AS daily_max
FROM cpu
WHERE time >= now() - INTERVAL '30 days'
GROUP BY day, host
ORDER BY day DESC;
```

### Advanced SQL Patterns

```sql
-- Window functions for moving averages
SELECT
  time,
  host,
  usage_user,
  AVG(usage_user) OVER (
    PARTITION BY host
    ORDER BY time
    ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
  ) AS moving_avg_12
FROM cpu
WHERE time >= now() - INTERVAL '1 hour';

-- Subqueries: find hosts with highest average CPU
SELECT host, avg_cpu
FROM (
  SELECT host, AVG(usage_user) AS avg_cpu
  FROM cpu
  WHERE time >= now() - INTERVAL '1 hour'
  GROUP BY host
)
ORDER BY avg_cpu DESC
LIMIT 10;

-- CTEs (Common Table Expressions)
WITH recent_cpu AS (
  SELECT host, AVG(usage_user) AS avg_cpu
  FROM cpu
  WHERE time >= now() - INTERVAL '5 minutes'
  GROUP BY host
),
thresholds AS (
  SELECT host, avg_cpu,
    CASE
      WHEN avg_cpu > 90 THEN 'critical'
      WHEN avg_cpu > 70 THEN 'warning'
      ELSE 'ok'
    END AS status
  FROM recent_cpu
)
SELECT * FROM thresholds WHERE status != 'ok';

-- UNION ALL for combining measurements
SELECT time, 'cpu' AS metric_type, host, usage_user AS value
FROM cpu WHERE time >= now() - INTERVAL '1 hour'
UNION ALL
SELECT time, 'mem' AS metric_type, host, used_percent AS value
FROM mem WHERE time >= now() - INTERVAL '1 hour'
ORDER BY time DESC;

-- Conditional aggregation
SELECT
  date_bin('1 hour', time) AS hour,
  COUNT(*) FILTER (WHERE usage_user > 90) AS critical_samples,
  COUNT(*) FILTER (WHERE usage_user > 70 AND usage_user <= 90) AS warning_samples,
  COUNT(*) AS total_samples
FROM cpu
WHERE time >= now() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC;
```

### Schema Discovery

```sql
-- List all tables (measurements)
SHOW TABLES;

-- List columns for a table
SHOW COLUMNS FROM cpu;

-- Information schema queries
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'cpu'
ORDER BY ordinal_position;

-- Show all databases
SHOW DATABASES;

-- Show all metadata
SHOW ALL;
```

### Query Analysis

```sql
-- Show query plan without executing
EXPLAIN SELECT * FROM cpu WHERE time >= now() - INTERVAL '1 hour';

-- Execute query and show detailed statistics
EXPLAIN ANALYZE
SELECT date_bin('5 minutes', time) AS window, host, AVG(usage_user)
FROM cpu
WHERE time >= now() - INTERVAL '1 hour'
GROUP BY window, host;

-- EXPLAIN ANALYZE output includes:
-- - Number of partitions scanned vs. pruned
-- - Number of Parquet files read
-- - Rows scanned per operator
-- - Time spent in each execution phase
-- - Memory used
```

## InfluxQL Support

InfluxDB 3.x natively supports InfluxQL for backward compatibility with 1.x workloads:

```sql
-- Basic InfluxQL queries work natively
SELECT mean(usage_user) FROM cpu WHERE time > now() - 1h GROUP BY time(5m), host FILL(none)

SELECT PERCENTILE(response_time, 95) FROM http_requests WHERE time > now() - 24h GROUP BY time(1h)

SHOW MEASUREMENTS
SHOW TAG KEYS FROM cpu
SHOW TAG VALUES FROM cpu WITH KEY = "host"
SHOW FIELD KEYS FROM cpu
```

**InfluxQL via CLI:**
```bash
influxdb3 query --database mydb --language influxql \
  "SELECT mean(usage_user) FROM cpu WHERE time > now() - 1h GROUP BY time(5m), host"
```

**InfluxQL via API:**
```bash
curl -XPOST "$HOST/api/v3/query_influxql" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"db": "mydb", "q": "SELECT mean(usage_user) FROM cpu WHERE time > now() - 1h GROUP BY time(5m), host"}'
```

## Storage Engine: Apache IOx

### Write Path

```
Client (line protocol) 
    --> HTTP API (/api/v3/write_lp or /api/v2/write)
    --> Parser (line protocol -> Arrow RecordBatch)
    --> Write Buffer (in-memory, queryable immediately)
    --> WAL Flush (every 1 second, durable)
    --> Persist to Object Store (as Parquet files)
    --> Catalog Update (metadata)
```

### Partitioning

Data is partitioned by time (default: daily) which enables efficient pruning:

```
Database: monitoring
  Table: cpu
    2026-04-07/    <- Today's partition (hot, most queries hit this)
      file001.parquet
      file002.parquet
    2026-04-06/    <- Yesterday
      file003.parquet (compacted)
    2026-04-05/    <- Two days ago
      file004.parquet (compacted)
    ...
```

**Custom partition templates (Enterprise/Clustered):** allow partitioning by tag values or tag buckets in addition to time, reducing I/O for queries that filter on those tags.

### Object Store Configuration

```bash
# Local filesystem (default for Core)
influxdb3 serve --object-store file --data-dir /var/lib/influxdb3

# AWS S3
influxdb3 serve \
  --object-store s3 \
  --bucket my-influxdb-bucket \
  --aws-default-region us-east-1 \
  --aws-access-key-id "$AWS_KEY" \
  --aws-secret-access-key "$AWS_SECRET"

# S3-compatible (MinIO)
influxdb3 serve \
  --object-store s3 \
  --bucket my-bucket \
  --aws-endpoint http://minio:9000 \
  --aws-access-key-id minioadmin \
  --aws-secret-access-key minioadmin \
  --aws-allow-http

# In-memory (testing only)
influxdb3 serve --object-store memory
```

## Last Value Cache (LVC)

The LVC is a performance optimization for queries that retrieve the most recent value(s) of a field:

```bash
# Create a last value cache
influxdb3 create last_cache \
  --database monitoring \
  --table cpu \
  --cache-name cpu_latest \
  --key-columns host,region \
  --value-columns usage_user,usage_system,usage_idle \
  --count 1

# Query the cache (much faster than full table scan)
influxdb3 query --database monitoring \
  "SELECT * FROM last_cache('cpu_latest')"

# Query with filter
influxdb3 query --database monitoring \
  "SELECT * FROM last_cache('cpu_latest') WHERE host = 'server01'"

# Delete when no longer needed
influxdb3 delete last_cache \
  --database monitoring --table cpu --cache-name cpu_latest
```

**When to use LVC:**
- Dashboard "current value" panels (gauges, single stat)
- Status boards showing latest state per host/device
- Alert evaluation against current values
- API endpoints returning "latest reading"

**When NOT to use LVC:**
- Historical queries (use regular SQL)
- Queries needing aggregation over time ranges
- High-cardinality key columns (cache memory grows linearly)

## Distinct Value Cache (DVC)

The DVC caches unique values for specified columns:

```bash
# Create a distinct value cache
influxdb3 create distinct_cache \
  --database monitoring \
  --table cpu \
  --cache-name cpu_dimensions \
  --columns host,region,environment

# Query distinct values
influxdb3 query --database monitoring \
  "SELECT * FROM distinct_cache('cpu_dimensions')"

# Delete
influxdb3 delete distinct_cache \
  --database monitoring --table cpu --cache-name cpu_dimensions
```

**When to use DVC:**
- Populating filter dropdowns in dashboards
- Auto-discovery of available hosts, regions, or device IDs
- Grafana template variable queries
- Schema exploration (what tags exist?)

## Python Processing Engine

The processing engine embeds a Python VM directly in the database for real-time data processing:

### WAL Flush Triggers (Real-Time Processing)

```python
# alert_plugin.py -- fires on every WAL flush (~1s)
def process_writes(influxdb3_local, table_batches, args=None):
    """Process incoming data as it is written."""
    for table_name, batch in table_batches.items():
        if table_name == "cpu":
            # Access data as Arrow RecordBatch
            usage_col = batch.column("usage_user")
            host_col = batch.column("host")

            for i in range(len(usage_col)):
                if usage_col[i].as_py() > 90:
                    # Write alert to a different table
                    alert_line = f'alerts,host={host_col[i].as_py()},severity=critical message="CPU > 90%: {usage_col[i].as_py():.1f}%"'
                    influxdb3_local.write(alert_line)
```

```bash
# Deploy the WAL trigger
influxdb3 create trigger \
  --database monitoring \
  --trigger-name cpu_alert \
  --plugin-file /path/to/alert_plugin.py \
  --trigger-spec "all_tables" \
  --host http://localhost:8181 --token "$TOKEN"
```

### Scheduled Triggers (Periodic Processing)

```python
# rollup_plugin.py -- runs on a cron schedule
def process_scheduled(influxdb3_local, args=None):
    """Periodic aggregation of CPU data."""
    result = influxdb3_local.query("""
        SELECT date_bin('1 hour', time) AS time,
               host,
               AVG(usage_user) AS usage_user_avg,
               MAX(usage_user) AS usage_user_max,
               MIN(usage_user) AS usage_user_min
        FROM cpu
        WHERE time >= now() - INTERVAL '1 hour'
        GROUP BY 1, host
    """)

    for row in result:
        line = (
            f"cpu_hourly,host={row['host']} "
            f"usage_user_avg={row['usage_user_avg']:.2f},"
            f"usage_user_max={row['usage_user_max']:.2f},"
            f"usage_user_min={row['usage_user_min']:.2f} "
            f"{int(row['time'].timestamp() * 1_000_000_000)}"
        )
        influxdb3_local.write(line)
```

```bash
# Deploy scheduled trigger (every hour)
influxdb3 create trigger \
  --database monitoring \
  --trigger-name hourly_rollup \
  --plugin-file /path/to/rollup_plugin.py \
  --trigger-spec "schedule:0 * * * *" \
  --host http://localhost:8181 --token "$TOKEN"
```

### HTTP Triggers (On-Demand Processing)

```python
# webhook_plugin.py -- fires on HTTP request
def process_request(influxdb3_local, query_params, request_body, args=None):
    """Handle incoming webhook."""
    import json
    data = json.loads(request_body)

    # Write webhook data as time-series
    line = f'webhooks,source={data["source"]} event="{data["event"]}",payload="{data["payload"]}"'
    influxdb3_local.write(line)

    return {"status": "ok", "processed": True}
```

### Plugin Management

```bash
# Install Python packages for use in plugins
influxdb3 install package requests
influxdb3 install package pandas

# List triggers
influxdb3 show triggers --database monitoring

# Enable/disable a trigger
influxdb3 disable trigger --database monitoring --trigger-name cpu_alert
influxdb3 enable trigger --database monitoring --trigger-name cpu_alert

# Delete a trigger
influxdb3 delete trigger --database monitoring --trigger-name cpu_alert
```

## Client Libraries

### Python (influxdb3-python)

```python
from influxdb_client_3 import InfluxDBClient3

# Connect
client = InfluxDBClient3(
    host="http://localhost:8181",
    database="monitoring",
    token="your-token"
)

# Write line protocol
client.write("cpu,host=server01 usage_user=23.5,usage_system=5.2")

# Write multiple lines
lines = [
    "cpu,host=server01 usage_user=23.5",
    "cpu,host=server02 usage_user=45.1",
    "cpu,host=server03 usage_user=67.8",
]
client.write(lines)

# Write pandas DataFrame
import pandas as pd
df = pd.DataFrame({
    "time": pd.to_datetime(["2026-04-07T10:00:00Z", "2026-04-07T10:01:00Z"]),
    "host": ["server01", "server01"],
    "usage_user": [23.5, 24.1],
})
client.write(df, data_frame_measurement_name="cpu", data_frame_tag_columns=["host"])

# Query (returns PyArrow Table)
table = client.query("SELECT * FROM cpu WHERE time >= now() - INTERVAL '1 hour'")

# Convert to pandas
df = table.to_pandas()
print(df)

# Query with InfluxQL
table = client.query("SELECT mean(usage_user) FROM cpu WHERE time > now() - 1h GROUP BY time(5m)", language="influxql")

client.close()
```

### Go

```go
package main

import (
    "context"
    "fmt"
    "github.com/InfluxCommunity/influxdb3-go/influxdb3"
)

func main() {
    client, err := influxdb3.New(influxdb3.ClientConfig{
        Host:     "http://localhost:8181",
        Token:    "your-token",
        Database: "monitoring",
    })
    if err != nil {
        panic(err)
    }
    defer client.Close()

    // Write
    err = client.WritePoints(context.Background(),
        influxdb3.NewPointWithMeasurement("cpu").
            SetTag("host", "server01").
            SetField("usage_user", 23.5).
            SetTimestamp(time.Now()),
    )

    // Query
    iterator, err := client.Query(context.Background(),
        "SELECT * FROM cpu WHERE time >= now() - INTERVAL '1 hour'")
    for iterator.Next() {
        value := iterator.Value()
        fmt.Printf("%v\n", value)
    }
}
```

### JavaScript/Node.js

```javascript
const { InfluxDBClient } = require('@influxdata/influxdb3-client');

const client = new InfluxDBClient({
  host: 'http://localhost:8181',
  token: 'your-token',
  database: 'monitoring',
});

// Write
await client.write('cpu,host=server01 usage_user=23.5');

// Query
const reader = await client.query('SELECT * FROM cpu LIMIT 10');
for await (const row of reader) {
  console.log(row);
}

client.close();
```

## HTTP API Reference

### Write Endpoints

```bash
# v3 native write endpoint
POST /api/v3/write_lp?db=<database>&precision=<precision>
Authorization: Bearer <token>
Content-Type: text/plain
Content-Encoding: gzip  # optional but recommended

<line protocol data>

# v2 compatibility write endpoint
POST /api/v2/write?bucket=<database>&precision=<precision>
Authorization: Token <token>
Content-Type: text/plain

<line protocol data>
```

### Query Endpoints

```bash
# SQL query (POST)
POST /api/v3/query_sql
Authorization: Bearer <token>
Content-Type: application/json

{"db": "mydb", "q": "SELECT * FROM cpu LIMIT 10", "format": "json"}

# SQL query (GET)
GET /api/v3/query_sql?db=mydb&q=SELECT+*+FROM+cpu+LIMIT+10&format=json
Authorization: Bearer <token>

# InfluxQL query (POST)
POST /api/v3/query_influxql
Authorization: Bearer <token>
Content-Type: application/json

{"db": "mydb", "q": "SELECT mean(usage_user) FROM cpu WHERE time > now() - 1h GROUP BY time(5m)", "format": "json"}

# Response formats: json, csv, jsonl, parquet, pretty
```

### Management Endpoints

```bash
# Health check
GET /health
# Returns: "OK"

# Prometheus metrics
GET /metrics
# Returns: Prometheus-format metrics

# Database management
POST /api/v3/configure/database    # Create database
DELETE /api/v3/configure/database   # Delete database
GET /api/v3/configure/database      # List databases

# Table management
POST /api/v3/configure/table        # Create table
DELETE /api/v3/configure/table      # Delete table

# Cache management
POST /api/v3/configure/last_cache
DELETE /api/v3/configure/last_cache
POST /api/v3/configure/distinct_cache
DELETE /api/v3/configure/distinct_cache
```

## InfluxDB 3 Enterprise Features

### Multi-Node Deployment

```bash
# Writer node
influxdb3 serve \
  --node-id writer01 \
  --mode writer \
  --object-store s3 \
  --bucket influxdb-data \
  --cluster-id production

# Reader node 1
influxdb3 serve \
  --node-id reader01 \
  --mode reader \
  --object-store s3 \
  --bucket influxdb-data \
  --cluster-id production

# Reader node 2
influxdb3 serve \
  --node-id reader02 \
  --mode reader \
  --object-store s3 \
  --bucket influxdb-data \
  --cluster-id production
```

### Compaction (Enterprise)

Enterprise includes a full compaction pipeline that optimizes historical data:
- Merges small Parquet files into larger, more efficient ones
- Sorts data optimally within files
- Deduplicates overlapping data points
- Re-encodes columns with optimal compression
- Runs automatically in the background

Core has limited compaction focused on recent data.

### High Availability

- Writer nodes support active/standby failover
- Reader nodes are horizontally scalable (up to 15 nodes)
- Object store (S3) provides 11 nines of durability
- Catalog replication ensures metadata consistency

## Configuration Reference

### Server Configuration (influxdb3 serve)

```bash
influxdb3 serve \
  # Identity
  --node-id <string>                    # Unique node identifier (REQUIRED)

  # Object store
  --object-store <file|memory|s3>       # Storage backend (default: file)
  --data-dir <path>                     # Data directory (for file object store)
  --bucket <s3-bucket>                  # S3 bucket name
  --aws-default-region <region>         # AWS region
  --aws-endpoint <url>                  # S3-compatible endpoint

  # Performance
  --memory-pool-size <bytes|percent>    # Query memory pool (e.g., "70%", "8589934592")
  --wal-flush-interval <duration>       # WAL flush frequency (default: 1s)
  --exec-mem-pool-bytes <bytes>         # DataFusion execution memory pool

  # Network
  --http-bind <addr>                    # HTTP bind address (default: 0.0.0.0:8181)
  --grpc-bind <addr>                    # gRPC bind address

  # Logging
  --log-filter <filter>                 # Log level filter (e.g., "info", "debug", "warn")

  # Enterprise
  --mode <writer|reader|writer-reader>  # Node role (Enterprise only)
  --cluster-id <string>                 # Cluster identifier (Enterprise only)
```

### Environment Variables

```bash
export INFLUXDB3_NODE_ID=node01
export INFLUXDB3_OBJECT_STORE=file
export INFLUXDB3_DATA_DIR=/var/lib/influxdb3
export INFLUXDB3_WAL_FLUSH_INTERVAL=1s
export INFLUXDB3_MEMORY_POOL_SIZE=70%
export INFLUXDB3_HTTP_BIND_ADDR=0.0.0.0:8181
export INFLUXDB3_LOG_FILTER=info
export INFLUXDB3_TOKEN=your-admin-token

# S3 configuration
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_DEFAULT_REGION=us-east-1
```

## Performance Tuning

### Write Optimization

1. **Batch writes:** 5,000-10,000 lines per request
2. **Gzip compression:** `Content-Encoding: gzip` reduces network I/O by 50-80%
3. **Appropriate precision:** Use `precision=s` for 10-second collection intervals
4. **Sort by tags:** Group lines with the same tag set for better Parquet compression
5. **WAL flush interval:** Default 1s is good; increase for higher throughput with more latency

### Query Optimization

1. **Always filter by time:** Enables partition pruning (most important optimization)
2. **Use EXPLAIN ANALYZE:** Understand what the query engine is doing
3. **Leverage caches:** LVC for latest values, DVC for dimension lists
4. **Project only needed columns:** `SELECT col1, col2` instead of `SELECT *`
5. **Use date_bin for aggregation:** Efficient time bucketing with DataFusion
6. **LIMIT results:** Avoid materializing millions of rows

### Memory Tuning

```bash
# Set memory pool to 70% of available RAM (recommended)
influxdb3 serve --memory-pool-size 70%

# For dedicated query-heavy workloads, increase to 80%
influxdb3 serve --memory-pool-size 80%

# For write-heavy workloads with simpler queries, reduce to 50%
influxdb3 serve --memory-pool-size 50%
```

## Grafana Integration

### Data Source Setup

1. Install Grafana (8.0+ recommended)
2. Add data source: Type "InfluxDB"
3. Configure:
   - **Query Language:** SQL (or InfluxQL)
   - **URL:** `http://influxdb3:8181`
   - **Database:** your database name
   - **Token:** Bearer token from `influxdb3 create token --read-db <db>`

### Alternative: Flight SQL Data Source

For maximum performance with large result sets:
1. Install the Grafana Flight SQL plugin
2. Configure:
   - **Host:** `influxdb3:8181`
   - **Token:** your read token
   - **Metadata:** `database=yourdb`

### Dashboard Query Examples

```sql
-- Time series panel (auto-interval using $__interval)
SELECT
  date_bin($__interval, time) AS time,
  host,
  AVG(usage_user) AS usage_user
FROM cpu
WHERE $__timeFilter(time)
GROUP BY time, host
ORDER BY time;

-- Stat panel (single value)
SELECT AVG(usage_user) AS avg_cpu
FROM cpu
WHERE $__timeFilter(time);

-- Table panel
SELECT time, host, region, usage_user, usage_system
FROM cpu
WHERE $__timeFilter(time)
ORDER BY time DESC
LIMIT 100;

-- Template variable query (populate host dropdown)
SELECT DISTINCT host FROM cpu ORDER BY host;
```

## Migration from InfluxDB 2.x

### Data Migration

```bash
# Step 1: Export data from 2.x as CSV
influx query --org my-org --token "$TOKEN_2X" --raw \
  'from(bucket: "monitoring")
   |> range(start: 2026-01-01T00:00:00Z)
   |> filter(fn: (r) => r._measurement == "cpu")' > cpu_data.csv

# Step 2: Convert CSV to line protocol (custom script needed)
# The CSV from Flux has columns: _time, _measurement, _field, _value, tags...

# Step 3: Write to InfluxDB 3.x
influxdb3 write --database monitoring --file cpu_data.lp \
  --host http://localhost:8181 --token "$TOKEN_3X"
```

### Dual-Write Strategy with Telegraf

```toml
# Write to both 2.x and 3.x simultaneously during migration
[[outputs.influxdb_v2]]
  urls = ["http://influxdb2:8086"]
  token = "$TOKEN_2X"
  organization = "my-org"
  bucket = "monitoring"

[[outputs.influxdb_v2]]
  urls = ["http://influxdb3:8181"]
  token = "$TOKEN_3X"
  organization = ""
  bucket = "monitoring"
```

### Query Migration Cheat Sheet

| Flux (2.x) | SQL (3.x) |
|---|---|
| `from(bucket: "b") \|> range(start: -1h)` | `FROM t WHERE time >= now() - INTERVAL '1 hour'` |
| `filter(fn: (r) => r.host == "s1")` | `WHERE host = 's1'` |
| `aggregateWindow(every: 5m, fn: mean)` | `date_bin('5 minutes', time), AVG(col)` |
| `group(columns: ["host"])` | `GROUP BY host` |
| `sort(columns: ["_time"])` | `ORDER BY time` |
| `limit(n: 10)` | `LIMIT 10` |
| `last()` | `ORDER BY time DESC LIMIT 1` (or LVC) |
| `first()` | `ORDER BY time ASC LIMIT 1` |
| `count()` | `COUNT(*)` |
| `distinct()` | `DISTINCT col` (or DVC) |
| `pivot()` | Not needed (3.x stores fields as columns natively) |
| `to(bucket: "other")` | Processing engine `influxdb3_local.write()` |
| Flux task | Processing engine scheduled trigger |
