# InfluxDB Diagnostics Reference

100+ CLI and API diagnostic commands organized by category. Commands are grouped by InfluxDB version where applicable.

**Conventions:**
- `$INFLUX_HOST_2X` = InfluxDB 2.x host (default: `http://localhost:8086`)
- `$INFLUX_HOST_3X` = InfluxDB 3.x host (default: `http://localhost:8181`)
- `$INFLUX_TOKEN` = API or admin token
- `$INFLUX_ORG` = Organization name (2.x only)
- `$INFLUX_DB` = Database name (3.x)

---

## Server Health and Info (12 commands)

### 1. Health Check (2.x)
```bash
curl -s "$INFLUX_HOST_2X/health" | jq .
```
**Key fields:** `name`, `message`, `status`, `version`. **Concerning:** `status != "pass"`.

### 2. Health Check (3.x)
```bash
curl -s "$INFLUX_HOST_3X/health"
```
**Expected response:** `OK`. Any other response indicates a problem.

### 3. Readiness Check (2.x)
```bash
curl -s "$INFLUX_HOST_2X/ready" | jq .
```
**Key fields:** `status: "ready"`, `started`, `up`. Confirms the server is accepting requests.

### 4. Ping (2.x)
```bash
curl -s -o /dev/null -w "%{http_code}" "$INFLUX_HOST_2X/ping"
```
**Expected:** HTTP 204. Lightweight liveness check.

### 5. Server Version (2.x)
```bash
influx version
```
Shows CLI version. Server version is in the `/health` response.

### 6. Server Version (3.x)
```bash
influxdb3 --version
```
Shows InfluxDB 3 server/CLI version.

### 7. Server Configuration (2.x)
```bash
influx server-config --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```
Dumps the current runtime configuration including all settings.

### 8. Server Configuration via API (2.x)
```bash
curl -s "$INFLUX_HOST_2X/api/v2/config" \
  -H "Authorization: Token $INFLUX_TOKEN" | jq .
```
Returns the active server configuration as JSON.

### 9. Debug Variables (2.x)
```bash
curl -s "$INFLUX_HOST_2X/debug/vars" | jq .
```
Returns internal Go runtime variables including memory stats, goroutine counts, and database metrics.

### 10. Debug Pprof Index (2.x)
```bash
curl -s "$INFLUX_HOST_2X/debug/pprof/"
```
Lists available Go profiling endpoints: allocs, block, goroutine, heap, mutex, profile, threadcreate, trace.

### 11. Heap Profile (2.x)
```bash
curl -s "$INFLUX_HOST_2X/debug/pprof/heap" > heap.prof
go tool pprof heap.prof
```
Downloads the heap memory profile for analysis with Go pprof tools.

### 12. Goroutine Dump (2.x)
```bash
curl -s "$INFLUX_HOST_2X/debug/pprof/goroutine?debug=2"
```
Dumps all goroutine stacks. Useful for diagnosing deadlocks or resource leaks.

---

## Prometheus Metrics (10 commands)

### 13. Full Metrics Dump (2.x)
```bash
curl -s "$INFLUX_HOST_2X/metrics"
```
Returns all Prometheus-format metrics. Pipe to `grep` for specific metrics.

### 14. Full Metrics Dump (3.x)
```bash
curl -s "$INFLUX_HOST_3X/metrics"
```
Returns all Prometheus-format metrics for InfluxDB 3.x.

### 15. Write Request Rate (2.x)
```bash
curl -s "$INFLUX_HOST_2X/metrics" | grep "influxdb_write_requests_total"
```
**Concerning:** Rate of increase dropping (write saturation) or error counter rising.

### 16. Write Points Total (2.x)
```bash
curl -s "$INFLUX_HOST_2X/metrics" | grep "influxdb_write_points_total"
```
Running total of points written. Track rate of change for throughput monitoring.

### 17. Write Errors (2.x)
```bash
curl -s "$INFLUX_HOST_2X/metrics" | grep "influxdb_write_errors_total"
```
**Concerning:** Any non-zero rate of increase. Check for type conflicts, auth errors, or back-pressure.

### 18. Query Duration (2.x)
```bash
curl -s "$INFLUX_HOST_2X/metrics" | grep "influxdb_query_request_duration_seconds"
```
Histogram of query durations. Check p99 for latency outliers.

### 19. TSM Compaction Metrics (2.x)
```bash
curl -s "$INFLUX_HOST_2X/metrics" | grep "influxdb_tsm_compaction"
```
Shows active compactions, queued compactions, duration, and errors.

### 20. Go Memory Stats (2.x/3.x)
```bash
curl -s "$INFLUX_HOST_2X/metrics" | grep "go_memstats"
```
**Key metrics:** `go_memstats_heap_alloc_bytes`, `go_memstats_heap_inuse_bytes`, `go_memstats_sys_bytes`.

### 21. HTTP API Latency (3.x)
```bash
curl -s "$INFLUX_HOST_3X/metrics" | grep "http_api_request_duration"
```
Shows request duration histogram by endpoint and method.

### 22. WAL Flush Metrics (3.x)
```bash
curl -s "$INFLUX_HOST_3X/metrics" | grep "influxdb3_wal"
```
Shows WAL flush duration, flush count, and any WAL errors.

---

## Database and Bucket Management (14 commands)

### 23. List Buckets (2.x)
```bash
influx bucket list --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN" --org "$INFLUX_ORG"
```
Shows all buckets with ID, name, retention period, shard group duration, organization, and schema type.

### 24. List Buckets via API (2.x)
```bash
curl -s "$INFLUX_HOST_2X/api/v2/buckets" \
  -H "Authorization: Token $INFLUX_TOKEN" | jq '.buckets[] | {name, id, retentionRules}'
```
Returns bucket details as JSON.

### 25. Create Bucket (2.x)
```bash
influx bucket create \
  --name monitoring \
  --org "$INFLUX_ORG" \
  --retention 7d \
  --shard-group-duration 1d \
  --host "$INFLUX_HOST_2X" \
  --token "$INFLUX_TOKEN"
```
Creates a bucket with 7-day retention and 1-day shard groups.

### 26. Update Bucket Retention (2.x)
```bash
influx bucket update \
  --id <bucket-id> \
  --retention 30d \
  --host "$INFLUX_HOST_2X" \
  --token "$INFLUX_TOKEN"
```
Changes retention period for an existing bucket.

### 27. Delete Bucket (2.x)
```bash
influx bucket delete \
  --id <bucket-id> \
  --host "$INFLUX_HOST_2X" \
  --token "$INFLUX_TOKEN"
```
Permanently deletes a bucket and all its data.

### 28. List Databases (3.x)
```bash
influxdb3 show databases --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```
Lists all databases in the InfluxDB 3.x instance.

### 29. Create Database (3.x)
```bash
influxdb3 create database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```
Creates a new database.

### 30. Delete Database (3.x)
```bash
influxdb3 delete database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```
Deletes a database and all its data.

### 31. List Tables (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SHOW TABLES"
```
Lists all tables (measurements) in a database.

### 32. List Tables via SQL (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT * FROM information_schema.tables"
```
Lists all tables using information schema.

### 33. Show Columns (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SHOW COLUMNS FROM cpu"
```
Shows column names, types, and nullability for a table.

### 34. Show Columns via Information Schema (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'cpu'"
```
Detailed column metadata.

### 35. Create Table (3.x)
```bash
influxdb3 create table cpu --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```
Explicitly creates a table (tables are also auto-created on first write).

### 36. Delete Table (3.x)
```bash
influxdb3 delete table cpu --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```
Deletes a table and all its data from the database.

---

## Write Diagnostics (12 commands)

### 37. Write Line Protocol (2.x)
```bash
curl -s -XPOST "$INFLUX_HOST_2X/api/v2/write?org=$INFLUX_ORG&bucket=monitoring&precision=ns" \
  -H "Authorization: Token $INFLUX_TOKEN" \
  -H "Content-Type: text/plain" \
  --data-binary 'cpu,host=server01 usage_user=23.5 1712448000000000000'
```
**Expected:** HTTP 204. Non-204 indicates a write problem.

### 38. Write Line Protocol (3.x via v3 endpoint)
```bash
curl -s -XPOST "$INFLUX_HOST_3X/api/v3/write_lp?db=mydb&precision=ns" \
  -H "Authorization: Bearer $INFLUX_TOKEN" \
  -H "Content-Type: text/plain" \
  --data-binary 'cpu,host=server01 usage_user=23.5 1712448000000000000'
```
**Expected:** HTTP 204. Write using the native v3 endpoint.

### 39. Write Line Protocol (3.x via v2 compat)
```bash
curl -s -XPOST "$INFLUX_HOST_3X/api/v2/write?bucket=mydb&precision=ns" \
  -H "Authorization: Token $INFLUX_TOKEN" \
  -H "Content-Type: text/plain" \
  --data-binary 'cpu,host=server01 usage_user=23.5 1712448000000000000'
```
**Expected:** HTTP 204. Backward-compatible endpoint.

### 40. Write with CLI (2.x)
```bash
influx write \
  --bucket monitoring \
  --org "$INFLUX_ORG" \
  --host "$INFLUX_HOST_2X" \
  --token "$INFLUX_TOKEN" \
  --precision ns \
  "cpu,host=server01 usage_user=23.5"
```

### 41. Write with CLI (3.x)
```bash
influxdb3 write \
  --database mydb \
  --host "$INFLUX_HOST_3X" \
  --token "$INFLUX_TOKEN" \
  --precision ns \
  "cpu,host=server01 usage_user=23.5"
```

### 42. Write from File (2.x)
```bash
influx write \
  --bucket monitoring \
  --org "$INFLUX_ORG" \
  --host "$INFLUX_HOST_2X" \
  --token "$INFLUX_TOKEN" \
  --file /path/to/data.lp
```

### 43. Write from File (3.x)
```bash
influxdb3 write \
  --database mydb \
  --host "$INFLUX_HOST_3X" \
  --token "$INFLUX_TOKEN" \
  --file /path/to/data.lp
```

### 44. Write with Gzip Compression (2.x)
```bash
gzip -c data.lp | curl -s -XPOST "$INFLUX_HOST_2X/api/v2/write?org=$INFLUX_ORG&bucket=monitoring" \
  -H "Authorization: Token $INFLUX_TOKEN" \
  -H "Content-Encoding: gzip" \
  -H "Content-Type: text/plain" \
  --data-binary @-
```

### 45. Write with Gzip Compression (3.x)
```bash
gzip -c data.lp | curl -s -XPOST "$INFLUX_HOST_3X/api/v3/write_lp?db=mydb" \
  -H "Authorization: Bearer $INFLUX_TOKEN" \
  -H "Content-Encoding: gzip" \
  -H "Content-Type: text/plain" \
  --data-binary @-
```

### 46. Test Write Parse (Dry Run with Verbose)
```bash
curl -v -XPOST "$INFLUX_HOST_2X/api/v2/write?org=$INFLUX_ORG&bucket=monitoring" \
  -H "Authorization: Token $INFLUX_TOKEN" \
  -H "Content-Type: text/plain" \
  --data-binary 'test,tag=value field=1.0'
```
Use `-v` to see full HTTP exchange including error details.

### 47. Check Write Precision Formats
```bash
# Nanosecond (default)
curl -XPOST "$INFLUX_HOST_3X/api/v3/write_lp?db=mydb&precision=ns" ...

# Microsecond
curl -XPOST "$INFLUX_HOST_3X/api/v3/write_lp?db=mydb&precision=us" ...

# Millisecond
curl -XPOST "$INFLUX_HOST_3X/api/v3/write_lp?db=mydb&precision=ms" ...

# Second
curl -XPOST "$INFLUX_HOST_3X/api/v3/write_lp?db=mydb&precision=s" ...
```

### 48. Validate Line Protocol Syntax
```bash
# Check for common line protocol errors:
# 1. Missing field (measurement with only tags)
#    BAD:  cpu,host=server01 1712448000000000000
#    GOOD: cpu,host=server01 value=1.0 1712448000000000000

# 2. Space in wrong place
#    BAD:  cpu, host=server01 value=1.0
#    GOOD: cpu,host=server01 value=1.0

# 3. Type mismatch (sending string to float field)
#    BAD:  cpu,host=server01 value="text" (if value was previously float)
```

---

## Query Diagnostics (14 commands)

### 49. Execute Flux Query (2.x)
```bash
influx query \
  --org "$INFLUX_ORG" \
  --host "$INFLUX_HOST_2X" \
  --token "$INFLUX_TOKEN" \
  'from(bucket: "monitoring") |> range(start: -1h) |> filter(fn: (r) => r._measurement == "cpu") |> limit(n: 10)'
```

### 50. Execute Flux Query via API (2.x)
```bash
curl -s -XPOST "$INFLUX_HOST_2X/api/v2/query?org=$INFLUX_ORG" \
  -H "Authorization: Token $INFLUX_TOKEN" \
  -H "Content-Type: application/vnd.flux" \
  -H "Accept: application/csv" \
  --data 'from(bucket: "monitoring") |> range(start: -1h) |> limit(n: 5)'
```

### 51. Execute SQL Query (3.x)
```bash
influxdb3 query \
  --database mydb \
  --host "$INFLUX_HOST_3X" \
  --token "$INFLUX_TOKEN" \
  "SELECT * FROM cpu WHERE time >= now() - INTERVAL '1 hour' LIMIT 10"
```

### 52. Execute SQL Query via API (3.x)
```bash
curl -s -XPOST "$INFLUX_HOST_3X/api/v3/query_sql" \
  -H "Authorization: Bearer $INFLUX_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"db": "mydb", "q": "SELECT * FROM cpu LIMIT 10", "format": "json"}'
```

### 53. Execute InfluxQL Query (3.x)
```bash
influxdb3 query \
  --database mydb \
  --host "$INFLUX_HOST_3X" \
  --token "$INFLUX_TOKEN" \
  --language influxql \
  "SELECT * FROM cpu WHERE time > now() - 1h LIMIT 10"
```

### 54. Execute InfluxQL Query via API (3.x)
```bash
curl -s -XPOST "$INFLUX_HOST_3X/api/v3/query_influxql" \
  -H "Authorization: Bearer $INFLUX_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"db": "mydb", "q": "SELECT * FROM cpu WHERE time > now() - 1h LIMIT 10", "format": "json"}'
```

### 55. EXPLAIN Query Plan (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "EXPLAIN SELECT * FROM cpu WHERE time >= now() - INTERVAL '1 hour'"
```
Shows the logical and physical query plan without executing.

### 56. EXPLAIN ANALYZE Query (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "EXPLAIN ANALYZE SELECT * FROM cpu WHERE time >= now() - INTERVAL '1 hour'"
```
Executes the query and shows detailed execution statistics: rows scanned, time per operator, partition pruning.

### 57. Query with CSV Output (3.x)
```bash
curl -s -XPOST "$INFLUX_HOST_3X/api/v3/query_sql" \
  -H "Authorization: Bearer $INFLUX_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"db": "mydb", "q": "SELECT * FROM cpu LIMIT 10", "format": "csv"}'
```

### 58. Query with JSON Lines Output (3.x)
```bash
curl -s -XPOST "$INFLUX_HOST_3X/api/v3/query_sql" \
  -H "Authorization: Bearer $INFLUX_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"db": "mydb", "q": "SELECT * FROM cpu LIMIT 10", "format": "jsonl"}'
```

### 59. Query with Parquet Output (3.x)
```bash
curl -s -XPOST "$INFLUX_HOST_3X/api/v3/query_sql" \
  -H "Authorization: Bearer $INFLUX_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"db": "mydb", "q": "SELECT * FROM cpu LIMIT 10", "format": "parquet"}' \
  -o result.parquet
```

### 60. Count Records in a Table (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT COUNT(*) FROM cpu"
```

### 61. Show Tag Values (InfluxQL -- 3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  --language influxql \
  "SHOW TAG VALUES FROM cpu WITH KEY = \"host\""
```

### 62. Show Measurements (InfluxQL -- 3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  --language influxql \
  "SHOW MEASUREMENTS"
```

---

## Cardinality Diagnostics (10 commands)

### 63. Show Series Cardinality (2.x via InfluxQL)
```bash
curl -s -G "$INFLUX_HOST_2X/query" \
  --data-urlencode "db=monitoring" \
  --data-urlencode "q=SHOW SERIES CARDINALITY" \
  -H "Authorization: Token $INFLUX_TOKEN"
```
Returns total number of unique series across all measurements.

### 64. Show Series Cardinality per Measurement (2.x)
```bash
curl -s -G "$INFLUX_HOST_2X/query" \
  --data-urlencode "db=monitoring" \
  --data-urlencode "q=SHOW SERIES CARDINALITY FROM cpu" \
  -H "Authorization: Token $INFLUX_TOKEN"
```

### 65. Show Tag Values Cardinality (2.x)
```bash
curl -s -G "$INFLUX_HOST_2X/query" \
  --data-urlencode "db=monitoring" \
  --data-urlencode "q=SHOW TAG VALUES CARDINALITY WITH KEY = \"host\"" \
  -H "Authorization: Token $INFLUX_TOKEN"
```
Shows the number of unique values for a specific tag key.

### 66. Show Measurement Cardinality (2.x)
```bash
curl -s -G "$INFLUX_HOST_2X/query" \
  --data-urlencode "db=monitoring" \
  --data-urlencode "q=SHOW MEASUREMENT CARDINALITY" \
  -H "Authorization: Token $INFLUX_TOKEN"
```

### 67. Estimate Series Count via Flux (2.x)
```bash
influx query --org "$INFLUX_ORG" --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN" \
  'import "influxdata/influxdb"
   influxdb.cardinality(bucket: "monitoring", start: -30d)'
```

### 68. List All Tag Keys (2.x)
```bash
curl -s -G "$INFLUX_HOST_2X/query" \
  --data-urlencode "db=monitoring" \
  --data-urlencode "q=SHOW TAG KEYS FROM cpu" \
  -H "Authorization: Token $INFLUX_TOKEN"
```

### 69. List All Tag Values for a Key (2.x)
```bash
curl -s -G "$INFLUX_HOST_2X/query" \
  --data-urlencode "db=monitoring" \
  --data-urlencode "q=SHOW TAG VALUES FROM cpu WITH KEY = \"host\"" \
  -H "Authorization: Token $INFLUX_TOKEN"
```

### 70. Count Distinct Tag Values (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT COUNT(DISTINCT host) AS unique_hosts FROM cpu"
```

### 71. List All Distinct Tag Values (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT DISTINCT host FROM cpu ORDER BY host"
```

### 72. Cardinality Estimation via Aggregation (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT COUNT(DISTINCT host) AS hosts,
          COUNT(DISTINCT region) AS regions,
          COUNT(DISTINCT environment) AS environments,
          COUNT(DISTINCT host) * COUNT(DISTINCT region) * COUNT(DISTINCT environment) AS estimated_series
   FROM cpu"
```

---

## Task and Processing Engine Diagnostics (10 commands)

### 73. List Tasks (2.x)
```bash
influx task list --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN" --org "$INFLUX_ORG"
```
Shows all tasks with ID, name, status (active/inactive), every/cron, and organization.

### 74. Show Task Runs (2.x)
```bash
influx task run list --task-id <task-id> \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```
Shows recent runs for a task with status (success/failed), start time, and duration.

### 75. Show Task Run Logs (2.x)
```bash
influx task log list --task-id <task-id> --run-id <run-id> \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```
Shows detailed logs for a specific task run.

### 76. Retry Failed Task Run (2.x)
```bash
influx task run retry --task-id <task-id> --run-id <run-id> \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 77. List Triggers (3.x)
```bash
influxdb3 show triggers --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```
Shows all processing engine triggers in a database.

### 78. Create WAL Trigger (3.x)
```bash
influxdb3 create trigger \
  --database mydb \
  --trigger-name my_transform \
  --plugin-file /path/to/plugin.py \
  --trigger-spec "all_tables" \
  --host "$INFLUX_HOST_3X" \
  --token "$INFLUX_TOKEN"
```

### 79. Create Scheduled Trigger (3.x)
```bash
influxdb3 create trigger \
  --database mydb \
  --trigger-name hourly_rollup \
  --plugin-file /path/to/rollup.py \
  --trigger-spec "schedule:*/60 * * * * *" \
  --host "$INFLUX_HOST_3X" \
  --token "$INFLUX_TOKEN"
```

### 80. Enable/Disable Trigger (3.x)
```bash
# Disable
influxdb3 disable trigger --database mydb --trigger-name my_transform \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"

# Enable
influxdb3 enable trigger --database mydb --trigger-name my_transform \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

### 81. Delete Trigger (3.x)
```bash
influxdb3 delete trigger --database mydb --trigger-name my_transform \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

### 82. Install Python Package for Processing Engine (3.x)
```bash
influxdb3 install package requests \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

---

## Cache Diagnostics (8 commands)

### 83. Create Last Value Cache (3.x)
```bash
influxdb3 create last_cache \
  --database mydb \
  --table cpu \
  --cache-name cpu_latest \
  --key-columns host,region \
  --value-columns usage_user,usage_system \
  --count 1 \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

### 84. Query Last Value Cache (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT * FROM last_cache('cpu_latest')"
```

### 85. Delete Last Value Cache (3.x)
```bash
influxdb3 delete last_cache \
  --database mydb \
  --table cpu \
  --cache-name cpu_latest \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

### 86. Create Distinct Value Cache (3.x)
```bash
influxdb3 create distinct_cache \
  --database mydb \
  --table cpu \
  --cache-name cpu_hosts \
  --columns host,region \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

### 87. Query Distinct Value Cache (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT * FROM distinct_cache('cpu_hosts')"
```

### 88. Delete Distinct Value Cache (3.x)
```bash
influxdb3 delete distinct_cache \
  --database mydb \
  --table cpu \
  --cache-name cpu_hosts \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

### 89. Show All Last Value Caches (3.x)
```bash
influxdb3 show system table --database mydb \
  --table last_caches \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

### 90. Show All Distinct Value Caches (3.x)
```bash
influxdb3 show system table --database mydb \
  --table distinct_caches \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

---

## Telegraf Diagnostics (10 commands)

### 91. Test Telegraf Configuration
```bash
telegraf --config /etc/telegraf/telegraf.conf --test
```
Runs all input plugins once and prints the output without writing to outputs. Essential for validating configuration.

### 92. Test Single Input Plugin
```bash
telegraf --config /etc/telegraf/telegraf.conf --input-filter cpu --test
```
Tests only the CPU input plugin.

### 93. Test with Debug Output
```bash
telegraf --config /etc/telegraf/telegraf.conf --test --debug
```
Enables debug logging during the test run.

### 94. Validate Configuration File
```bash
telegraf --config /etc/telegraf/telegraf.conf --test --once 2>&1 | head -20
```
Validates the configuration and runs one collection cycle. Configuration errors appear immediately.

### 95. Run Telegraf Once (Single Collection)
```bash
telegraf --config /etc/telegraf/telegraf.conf --once
```
Runs one full collection cycle (input -> process -> aggregate -> output) then exits.

### 96. List Available Input Plugins
```bash
telegraf --input-list
```
Lists all compiled-in input plugins.

### 97. List Available Output Plugins
```bash
telegraf --output-list
```
Lists all compiled-in output plugins.

### 98. Generate Sample Config for Specific Plugins
```bash
telegraf --input-filter cpu:mem:disk --output-filter influxdb_v2 config > telegraf_sample.conf
```
Generates a config file with only the specified plugins.

### 99. Check Telegraf Version and Build Info
```bash
telegraf version
```

### 100. Run with Specific Input Filter
```bash
telegraf --config /etc/telegraf/telegraf.conf --input-filter cpu:mem --output-filter influxdb_v2
```
Runs Telegraf with only the specified input and output plugins active.

---

## Authentication and Token Management (10 commands)

### 101. List Authorizations (2.x)
```bash
influx auth list --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```
Shows all tokens with ID, description, user, status, and permissions.

### 102. Create All-Access Token (2.x)
```bash
influx auth create \
  --org "$INFLUX_ORG" \
  --all-access \
  --description "Admin token" \
  --host "$INFLUX_HOST_2X" \
  --token "$INFLUX_TOKEN"
```

### 103. Create Read-Only Token for a Bucket (2.x)
```bash
influx auth create \
  --org "$INFLUX_ORG" \
  --read-bucket <bucket-id> \
  --description "Grafana read-only" \
  --host "$INFLUX_HOST_2X" \
  --token "$INFLUX_TOKEN"
```

### 104. Create Write-Only Token for a Bucket (2.x)
```bash
influx auth create \
  --org "$INFLUX_ORG" \
  --write-bucket <bucket-id> \
  --description "Telegraf writer" \
  --host "$INFLUX_HOST_2X" \
  --token "$INFLUX_TOKEN"
```

### 105. Deactivate a Token (2.x)
```bash
influx auth inactive --id <token-id> \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 106. Delete a Token (2.x)
```bash
influx auth delete --id <token-id> \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 107. Create Admin Token (3.x)
```bash
influxdb3 create token --admin \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

### 108. Create Database-Scoped Token (3.x)
```bash
influxdb3 create token \
  --read-db mydb \
  --write-db mydb \
  --description "Application token" \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

### 109. Create Read-Only Token (3.x)
```bash
influxdb3 create token \
  --read-db mydb \
  --description "Dashboard read-only" \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

### 110. Delete Token (3.x)
```bash
influxdb3 delete token <token-id> \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

---

## Organization and User Management (6 commands)

### 111. List Organizations (2.x)
```bash
influx org list --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 112. List Organization Members (2.x)
```bash
influx org members list --name "$INFLUX_ORG" \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 113. Create Organization (2.x)
```bash
influx org create --name new-org \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 114. List Users (2.x)
```bash
influx user list --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 115. Create User (2.x)
```bash
influx user create --name newuser --org "$INFLUX_ORG" \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 116. Update User Password (2.x)
```bash
influx user password --name newuser \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

---

## System Tables and Information Schema (8 commands)

### 117. List System Tables (3.x)
```bash
influxdb3 show system table-list --database mydb \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```
Lists all available system tables (parquet_files, last_caches, distinct_caches, etc.).

### 118. Query Parquet Files System Table (3.x)
```bash
influxdb3 show system table --database mydb --table parquet_files \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```
Shows all Parquet files: path, size, row count, min/max time, partition.

### 119. Query Information Schema Tables (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT table_catalog, table_schema, table_name, table_type
   FROM information_schema.tables"
```

### 120. Query Information Schema Columns (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT table_name, column_name, data_type, is_nullable
   FROM information_schema.columns
   ORDER BY table_name, ordinal_position"
```

### 121. Show All Databases via System (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SHOW DATABASES"
```

### 122. Show All Tables with Row Counts (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"
# Then for each table:
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT COUNT(*) FROM cpu"
```

### 123. Query WAL System Table (3.x)
```bash
influxdb3 show system table --database mydb --table wal_files \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

### 124. Show All System Metadata (3.x)
```bash
influxdb3 show system table --database mydb --table queries \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN"
```

---

## Backup and Restore (8 commands)

### 125. Full Backup (2.x)
```bash
influx backup /path/to/backup/ \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```
Backs up all buckets, organizations, dashboards, tasks, and metadata.

### 126. Backup Specific Bucket (2.x)
```bash
influx backup /path/to/backup/ \
  --bucket monitoring \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 127. Restore Full Backup (2.x)
```bash
influx restore /path/to/backup/ \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 128. Restore Specific Bucket (2.x)
```bash
influx restore /path/to/backup/ \
  --bucket monitoring \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 129. Restore to New Bucket (2.x)
```bash
influx restore /path/to/backup/ \
  --bucket monitoring \
  --new-bucket monitoring-restored \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN"
```

### 130. Backup InfluxDB 3.x Data Directory
```bash
# For local file object store -- stop writes or accept brief inconsistency
rsync -av --progress /var/lib/influxdb3/ /backup/influxdb3-$(date +%Y%m%d)/
```

### 131. Backup InfluxDB 3.x Catalog
```bash
# The catalog file is critical for metadata recovery
cp /var/lib/influxdb3/catalog.sqlite /backup/catalog-$(date +%Y%m%d).sqlite
```

### 132. Export Data as Line Protocol (2.x)
```bash
influx query --org "$INFLUX_ORG" --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN" \
  --raw \
  'from(bucket: "monitoring")
   |> range(start: -24h)
   |> filter(fn: (r) => r._measurement == "cpu")' > cpu_export.csv
```

---

## Storage Diagnostics (8 commands)

### 133. Inspect TSM Files (2.x)
```bash
influx inspect report-tsm --data-path /var/lib/influxdb/engine/data
```
Reports on TSM file sizes, block counts, compression ratios, and series counts.

### 134. Dump TSM File Contents (2.x)
```bash
influx inspect dump-tsm --file-path /var/lib/influxdb/engine/data/<bucket>/<shard>/000000001-000000001.tsm
```
Shows the contents of a specific TSM file.

### 135. Check Shard Disk Usage (2.x)
```bash
du -sh /var/lib/influxdb/engine/data/*/*/
```
Shows disk usage per shard. Large shards may indicate cardinality issues or missing compaction.

### 136. Check WAL Disk Usage (2.x)
```bash
du -sh /var/lib/influxdb/engine/wal/*/*/
```
Shows WAL disk usage per shard. Growing WAL indicates writes outpacing snapshots.

### 137. Check Object Store Size (3.x -- local file)
```bash
du -sh /var/lib/influxdb3/
```

### 138. Count Parquet Files (3.x -- local file)
```bash
find /var/lib/influxdb3/ -name "*.parquet" | wc -l
```

### 139. Inspect Parquet File (3.x)
```bash
# Using Apache Parquet CLI tools (parquet-cli) or DuckDB
duckdb -c "SELECT * FROM parquet_metadata('/var/lib/influxdb3/path/to/file.parquet')"
duckdb -c "SELECT * FROM parquet_schema('/var/lib/influxdb3/path/to/file.parquet')"
```

### 140. Check Parquet File Sizes via System Table (3.x)
```bash
influxdb3 query --database mydb --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT table_name, COUNT(*) as file_count
   FROM system.parquet_files
   GROUP BY table_name"
```

---

## InfluxDB 2.x CLI Quick Reference (6 commands)

### 141. Setup Initial Configuration (2.x)
```bash
influx setup \
  --host "$INFLUX_HOST_2X" \
  --username admin \
  --password adminpassword \
  --org my-org \
  --bucket monitoring \
  --retention 7d \
  --force
```
Completes the initial onboarding setup.

### 142. Create CLI Config Profile (2.x)
```bash
influx config create \
  --config-name production \
  --host-url "$INFLUX_HOST_2X" \
  --org "$INFLUX_ORG" \
  --token "$INFLUX_TOKEN" \
  --active
```

### 143. List CLI Configs (2.x)
```bash
influx config list
```

### 144. Switch Active CLI Config (2.x)
```bash
influx config set --name production --active
```

### 145. Delete Data by Time Range (2.x)
```bash
influx delete \
  --bucket monitoring \
  --start 2026-01-01T00:00:00Z \
  --stop 2026-02-01T00:00:00Z \
  --predicate '_measurement="cpu" AND host="server01"' \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN" --org "$INFLUX_ORG"
```

### 146. Check DBRP Mappings (2.x -- for InfluxQL compatibility)
```bash
influx v1 dbrp list \
  --host "$INFLUX_HOST_2X" --token "$INFLUX_TOKEN" --org "$INFLUX_ORG"
```
Shows database/retention-policy to bucket mappings for InfluxQL compatibility.

---

## InfluxDB 3.x Server Management (6 commands)

### 147. Start InfluxDB 3 Core Server
```bash
influxdb3 serve \
  --node-id node01 \
  --object-store file \
  --data-dir /var/lib/influxdb3 \
  --wal-flush-interval 1s \
  --log-filter info
```

### 148. Start with S3 Object Store
```bash
influxdb3 serve \
  --node-id node01 \
  --object-store s3 \
  --bucket influxdb-data \
  --aws-default-region us-east-1 \
  --aws-access-key-id "$AWS_ACCESS_KEY_ID" \
  --aws-secret-access-key "$AWS_SECRET_ACCESS_KEY"
```

### 149. Start with Memory Pool Configuration
```bash
influxdb3 serve \
  --object-store file \
  --data-dir /var/lib/influxdb3 \
  --memory-pool-size 70%
```

### 150. Start Enterprise Writer Node
```bash
influxdb3 serve \
  --node-id writer01 \
  --mode writer \
  --object-store s3 \
  --bucket influxdb-data \
  --cluster-id my-cluster
```

### 151. Start Enterprise Reader Node
```bash
influxdb3 serve \
  --node-id reader01 \
  --mode reader \
  --object-store s3 \
  --bucket influxdb-data \
  --cluster-id my-cluster
```

### 152. Docker Quick Start (3.x Core)
```bash
docker run -d \
  --name influxdb3 \
  -p 8181:8181 \
  -v influxdb3-data:/var/lib/influxdb3 \
  influxdb:3-core \
  serve \
  --node-id docker01 \
  --object-store file \
  --data-dir /var/lib/influxdb3
```

---

## Connectivity and Integration Testing (4 commands)

### 153. Test Python Client (3.x)
```python
from influxdb_client_3 import InfluxDBClient3

client = InfluxDBClient3(
    host="http://localhost:8181",
    database="mydb",
    token="your-token"
)

# Write
client.write("cpu,host=test value=42.0")

# Query
table = client.query("SELECT * FROM cpu LIMIT 5")
print(table.to_pandas())
```

### 154. Test Arrow Flight Connectivity (3.x)
```python
from pyarrow import flight

client = flight.FlightClient("grpc://localhost:8181")
options = flight.FlightCallOptions(headers=[
    (b"authorization", b"Bearer your-token"),
    (b"database", b"mydb"),
])
ticket = flight.Ticket(b'{"database":"mydb","sql_query":"SELECT 1"}')
reader = client.do_get(ticket, options)
print(reader.read_all().to_pandas())
```

### 155. Test Write Throughput
```bash
# Generate and write 100,000 points
python3 -c "
import time
lines = []
now = int(time.time() * 1_000_000_000)
for i in range(100000):
    lines.append(f'bench,host=h{i%100} value={i*1.1} {now + i}')
with open('/tmp/bench.lp', 'w') as f:
    f.write('\n'.join(lines))
"

time influxdb3 write --database mydb \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  --file /tmp/bench.lp
```

### 156. Test Query Latency
```bash
time influxdb3 query --database mydb \
  --host "$INFLUX_HOST_3X" --token "$INFLUX_TOKEN" \
  "SELECT COUNT(*) FROM cpu WHERE time >= now() - INTERVAL '1 hour'"
```
