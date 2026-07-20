# Apache Druid Diagnostics Reference

All commands use the default ports. Adjust hostnames and ports for your deployment. REST API calls use curl; SQL queries can be submitted via `POST /druid/v2/sql` or the web console.

## Cluster Health and Status

### 1. Check Service Health

```bash
# Health check for any Druid process
curl http://broker:8082/status/health
curl http://coordinator:8081/status/health
curl http://overlord:8090/status/health
curl http://historical:8083/status/health
curl http://router:8888/status/health
```

### 2. Get Service Properties

```bash
# Returns runtime properties for the service
curl http://broker:8082/status/properties
curl http://coordinator:8081/status/properties
```

### 3. Check Service Status and Version

```bash
curl http://broker:8082/status
# Returns: {"version":"36.0.0","modules":[...],"memory":{"maxMemory":...}}
```

### 4. List All Servers in the Cluster

```sql
SELECT server, server_type, tier, curr_size, max_size, is_leader
FROM sys.servers
ORDER BY server_type, server;
```

### 5. Check Server Capacity and Usage

```sql
SELECT
  server,
  server_type,
  tier,
  curr_size / 1073741824.0 AS curr_size_gb,
  max_size / 1073741824.0 AS max_size_gb,
  ROUND(CAST(curr_size AS DOUBLE) / max_size * 100, 1) AS usage_pct
FROM sys.servers
WHERE server_type = 'historical'
ORDER BY usage_pct DESC;
```

### 6. Check Available Processors and Memory

```sql
SELECT server, server_type, available_processors, total_memory
FROM sys.servers;
```

## Coordinator Diagnostics

### 7. Coordinator Leader

```bash
curl http://coordinator:8081/druid/coordinator/v1/leader
```

### 8. Overall Load Status

```bash
# Simple: percentage of segments loaded
curl "http://coordinator:8081/druid/coordinator/v1/loadstatus?simple"

# Full: segments remaining to load per datasource
curl "http://coordinator:8081/druid/coordinator/v1/loadstatus?full"

# With cluster view
curl "http://coordinator:8081/druid/coordinator/v1/loadstatus?full&computeUsingClusterView"
```

### 9. Load Queue per Historical

```bash
# Simple: count of segments to load/drop per server
curl "http://coordinator:8081/druid/coordinator/v1/loadqueue?simple"

# Full: details of segments in the load queue
curl "http://coordinator:8081/druid/coordinator/v1/loadqueue"
```

### 10. List All Datasources

```bash
curl http://coordinator:8081/druid/coordinator/v1/datasources
```

### 11. Datasource Details

```bash
curl http://coordinator:8081/druid/coordinator/v1/datasources/events
curl http://coordinator:8081/druid/coordinator/v1/datasources/events?full
```

### 12. Datasource Segment Count and Intervals

```bash
curl http://coordinator:8081/druid/coordinator/v1/datasources/events/intervals
curl "http://coordinator:8081/druid/coordinator/v1/datasources/events/intervals?simple"
```

### 13. Tiers and Segment Distribution

```bash
# List all tiers
curl http://coordinator:8081/druid/coordinator/v1/tiers

# Segments per tier for a datasource
curl http://coordinator:8081/druid/coordinator/v1/datasources/events/tiers
```

### 14. Data Source Rules (Retention/Replication)

```bash
# Get rules for a datasource
curl http://coordinator:8081/druid/coordinator/v1/rules/events

# Get default rules
curl http://coordinator:8081/druid/coordinator/v1/rules/_default

# Set rules for a datasource
curl -X POST -H "Content-Type: application/json" \
  http://coordinator:8081/druid/coordinator/v1/rules/events \
  -d '[{"type":"loadByPeriod","period":"P30D","tieredReplicants":{"_default_tier":2}},
       {"type":"dropForever"}]'
```

### 15. Coordinator Dynamic Configuration

```bash
# Get current dynamic config
curl http://coordinator:8081/druid/coordinator/v1/config

# Set dynamic config (e.g., max segments to move per run)
curl -X POST -H "Content-Type: application/json" \
  http://coordinator:8081/druid/coordinator/v1/config \
  -d '{"maxSegmentsToMove":100,"replicationThrottleLimit":10,"mergeBytesLimit":524288000}'
```

### 16. Compaction Status

```bash
# Get compaction status for all datasources
curl http://coordinator:8081/druid/coordinator/v1/compaction/status

# Get compaction status for a specific datasource
curl http://coordinator:8081/druid/coordinator/v1/compaction/status?dataSource=events

# Get compaction config for a datasource
curl http://coordinator:8081/druid/coordinator/v1/compaction/config/events
```

### 17. Set Auto-Compaction Configuration

```bash
curl -X POST -H "Content-Type: application/json" \
  http://coordinator:8081/druid/coordinator/v1/compaction/config \
  -d '{
    "dataSource": "events",
    "maxRowsPerSegment": 5000000,
    "skipOffsetFromLatest": "PT1H",
    "tuningConfig": {
      "type": "index_parallel",
      "partitionsSpec": {"type": "hashed"}
    },
    "engine": "msq"
  }'
```

### 18. Coordinator Cluster View

```bash
curl http://coordinator:8081/druid/coordinator/v1/servers
curl "http://coordinator:8081/druid/coordinator/v1/servers?full"
```

### 19. Audit History

```bash
# Recent audit events (rule changes, config changes)
curl "http://coordinator:8081/druid/coordinator/v1/config/history?count=25"
curl "http://coordinator:8081/druid/coordinator/v1/rules/events/history?count=10"
```

## Overlord / Task Diagnostics

### 20. Overlord Leader

```bash
curl http://overlord:8090/druid/indexer/v1/leader
```

### 21. List Running Tasks

```bash
curl http://overlord:8090/druid/indexer/v1/runningTasks
```

### 22. List Pending Tasks

```bash
curl http://overlord:8090/druid/indexer/v1/pendingTasks
```

### 23. List Waiting Tasks

```bash
curl http://overlord:8090/druid/indexer/v1/waitingTasks
```

### 24. List Complete Tasks

```bash
curl http://overlord:8090/druid/indexer/v1/completeTasks
```

### 25. Get Task Status by ID

```bash
curl http://overlord:8090/druid/indexer/v1/task/<taskId>/status
```

### 26. Get Task Log

```bash
curl http://overlord:8090/druid/indexer/v1/task/<taskId>/log
```

### 27. Get Task Report

```bash
curl http://overlord:8090/druid/indexer/v1/task/<taskId>/reports
```

### 28. Shutdown a Specific Task

```bash
curl -X POST http://overlord:8090/druid/indexer/v1/task/<taskId>/shutdown
```

### 29. Shutdown All Tasks for a Datasource

```bash
curl -X POST http://overlord:8090/druid/indexer/v1/datasources/events/shutdownAllTasks
```

### 30. Task Summary via System Table

```sql
SELECT
  task_id,
  type,
  datasource,
  status,
  runner_status,
  created_time,
  duration,
  error_msg
FROM sys.tasks
ORDER BY created_time DESC
LIMIT 50;
```

### 31. Task Failures Analysis

```sql
SELECT
  datasource,
  type,
  status,
  COUNT(*) AS task_count,
  COUNT(*) FILTER(WHERE status = 'FAILED') AS failed
FROM sys.tasks
WHERE created_time >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
GROUP BY 1, 2, 3
ORDER BY failed DESC;
```

### 32. Worker (MiddleManager) Status

```bash
curl http://overlord:8090/druid/indexer/v1/workers
```

### 33. Worker Capacity and Running Tasks

```bash
curl http://overlord:8090/druid/indexer/v1/workers?full
```

## Supervisor Diagnostics

### 34. List All Supervisors

```bash
curl http://overlord:8090/druid/indexer/v1/supervisor
```

### 35. List Supervisors with State

```bash
curl "http://overlord:8090/druid/indexer/v1/supervisor?state=true"
```

### 36. Get Supervisor Status

```bash
curl http://overlord:8090/druid/indexer/v1/supervisor/events-kafka/status
```

### 37. Get Supervisor Spec

```bash
curl http://overlord:8090/druid/indexer/v1/supervisor/events-kafka
```

### 38. Get Supervisor Stats (Ingestion Metrics)

```bash
# Lag, offsets, throughput per task
curl http://overlord:8090/druid/indexer/v1/supervisor/events-kafka/stats
```

### 39. Get Supervisor Audit History

```bash
curl http://overlord:8090/druid/indexer/v1/supervisor/events-kafka/history
```

### 40. Suspend a Supervisor

```bash
curl -X POST http://overlord:8090/druid/indexer/v1/supervisor/events-kafka/suspend
```

### 41. Resume a Supervisor

```bash
curl -X POST http://overlord:8090/druid/indexer/v1/supervisor/events-kafka/resume
```

### 42. Reset Supervisor Offsets

```bash
curl -X POST http://overlord:8090/druid/indexer/v1/supervisor/events-kafka/reset
```

### 43. Terminate a Supervisor

```bash
curl -X POST http://overlord:8090/druid/indexer/v1/supervisor/events-kafka/terminate
```

### 44. Supervisor Status via System Table

```sql
SELECT
  supervisor_id,
  state,
  detailed_state,
  healthy,
  type,
  source,
  suspended
FROM sys.supervisors;
```

### 45. Check Supervisor Lag (Kafka)

```bash
# Check ingestion lag from the stats endpoint
curl -s http://overlord:8090/druid/indexer/v1/supervisor/events-kafka/stats | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for taskGroup, stats in data.items():
    for stat in stats:
        if 'lag' in stat:
            print(f'{taskGroup}: lag={stat.get(\"lag\", \"N/A\")}')"
```

## Broker / Query Diagnostics

### 46. Broker Datasource List

```bash
curl http://broker:8082/druid/v2/datasources
```

### 47. Datasource Schema (Dimensions and Metrics)

```bash
curl http://broker:8082/druid/v2/datasources/events
```

### 48. Submit a Native JSON Query

```bash
curl -X POST -H "Content-Type: application/json" \
  http://broker:8082/druid/v2 \
  -d '{
    "queryType": "timeseries",
    "dataSource": "events",
    "intervals": ["2026-04-01/2026-04-08"],
    "granularity": "day",
    "aggregations": [{"type": "count", "name": "events"}]
  }'
```

### 49. Submit a SQL Query

```bash
curl -X POST -H "Content-Type: application/json" \
  http://broker:8082/druid/v2/sql \
  -d '{"query": "SELECT COUNT(*) AS cnt FROM events WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '\''24'\'' HOUR"}'
```

### 50. SQL Query with Context Parameters

```bash
curl -X POST -H "Content-Type: application/json" \
  http://broker:8082/druid/v2/sql \
  -d '{
    "query": "SELECT event_type, COUNT(*) FROM events GROUP BY 1 ORDER BY 2 DESC LIMIT 10",
    "context": {
      "timeout": 30000,
      "maxQueuedBytes": 10485760,
      "sqlQueryId": "my-debug-query-001"
    }
  }'
```

### 51. EXPLAIN PLAN for SQL

```sql
EXPLAIN PLAN FOR
SELECT event_type, COUNT(*) AS cnt
FROM events
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '7' DAY
GROUP BY 1
ORDER BY cnt DESC
LIMIT 100;
```

### 52. Cancel a Running Query

```bash
curl -X DELETE http://broker:8082/druid/v2/<queryId>
```

### 53. Broker Cache Statistics

```bash
curl http://broker:8082/druid/v2/datasources/events?interval=2026-04-07/2026-04-08
```

### 54. Query Metrics via System Tables

```sql
-- Not directly available as a system table; use Druid metrics emission to Prometheus/Graphite
-- Or check via the metrics endpoint
```

## Segment Diagnostics

### 55. Total Segments per Datasource

```sql
SELECT
  datasource,
  COUNT(*) AS total_segments,
  SUM(CASE WHEN is_published = 1 THEN 1 ELSE 0 END) AS published,
  SUM(CASE WHEN is_available = 1 THEN 1 ELSE 0 END) AS available,
  SUM(CASE WHEN is_realtime = 1 THEN 1 ELSE 0 END) AS realtime,
  SUM(CASE WHEN is_overshadowed = 1 THEN 1 ELSE 0 END) AS overshadowed
FROM sys.segments
GROUP BY 1
ORDER BY total_segments DESC;
```

### 56. Unavailable Segments

```sql
SELECT datasource, segment_id, start, "end", size, num_rows
FROM sys.segments
WHERE is_published = 1
  AND is_available = 0
  AND is_overshadowed = 0
ORDER BY datasource, start;
```

### 57. Segment Size Distribution

```sql
SELECT
  datasource,
  COUNT(*) AS segments,
  ROUND(AVG(num_rows), 0) AS avg_rows,
  MIN(num_rows) AS min_rows,
  MAX(num_rows) AS max_rows,
  ROUND(AVG(size) / 1048576.0, 1) AS avg_size_mb,
  ROUND(SUM(size) / 1073741824.0, 2) AS total_size_gb
FROM sys.segments
WHERE is_published = 1 AND is_overshadowed = 0
GROUP BY 1
ORDER BY total_size_gb DESC;
```

### 58. Segments Below Optimal Size (Compaction Candidates)

```sql
SELECT
  datasource,
  COUNT(*) AS small_segments,
  ROUND(AVG(num_rows), 0) AS avg_rows,
  ROUND(AVG(size) / 1048576.0, 1) AS avg_size_mb
FROM sys.segments
WHERE is_published = 1
  AND is_overshadowed = 0
  AND num_rows < 1000000
GROUP BY 1
HAVING COUNT(*) > 10
ORDER BY small_segments DESC;
```

### 59. Segments by Time Interval

```sql
SELECT
  datasource,
  start,
  "end",
  COUNT(*) AS shards,
  SUM(num_rows) AS total_rows,
  ROUND(SUM(size) / 1048576.0, 1) AS total_size_mb
FROM sys.segments
WHERE datasource = 'events'
  AND is_published = 1
  AND is_overshadowed = 0
GROUP BY 1, 2, 3
ORDER BY start DESC
LIMIT 50;
```

### 60. Segment Details for a Specific Interval

```sql
SELECT
  segment_id,
  num_rows,
  ROUND(size / 1048576.0, 1) AS size_mb,
  num_replicas,
  is_available,
  is_realtime,
  is_overshadowed
FROM sys.segments
WHERE datasource = 'events'
  AND start >= '2026-04-07'
  AND "end" <= '2026-04-08'
ORDER BY segment_id;
```

### 61. Overshadowed Segments

```sql
SELECT datasource, COUNT(*) AS overshadowed_segments,
  ROUND(SUM(size) / 1073741824.0, 2) AS overshadowed_gb
FROM sys.segments
WHERE is_overshadowed = 1
GROUP BY 1
ORDER BY overshadowed_gb DESC;
```

### 62. Segment Replication Status

```sql
SELECT
  datasource,
  num_replicas,
  COUNT(*) AS segment_count
FROM sys.segments
WHERE is_published = 1 AND is_overshadowed = 0
GROUP BY 1, 2
ORDER BY 1, 2;
```

### 63. Server-Segment Mapping

```sql
SELECT
  server,
  segment_id,
  datasource,
  num_rows,
  size
FROM sys.server_segments
WHERE datasource = 'events'
ORDER BY server, segment_id
LIMIT 100;
```

### 64. Segment Metadata via REST API

```bash
# List segments for a datasource
curl "http://coordinator:8081/druid/coordinator/v1/datasources/events/segments"

# Specific segment metadata
curl "http://coordinator:8081/druid/coordinator/v1/datasources/events/segments/<segmentId>"
```

### 65. Mark Segment as Unused

```bash
curl -X POST -H "Content-Type: application/json" \
  http://coordinator:8081/druid/coordinator/v1/datasources/events/markUnused \
  -d '{"segmentIds": ["events_2026-04-07T00:00:00.000Z_2026-04-07T01:00:00.000Z_..."]}'
```

### 66. Mark Segment as Used (Re-enable)

```bash
curl -X POST -H "Content-Type: application/json" \
  http://coordinator:8081/druid/coordinator/v1/datasources/events/markUsed \
  -d '{"segmentIds": ["events_2026-04-07T00:00:00.000Z_..."]}'
```

### 67. Segment Schema from Native Query

```bash
curl -X POST -H "Content-Type: application/json" \
  http://broker:8082/druid/v2 \
  -d '{
    "queryType": "segmentMetadata",
    "dataSource": "events",
    "intervals": ["2026-04-01/2026-04-08"],
    "merge": true,
    "analysisTypes": ["cardinality", "minmax", "size", "interval", "aggregators"]
  }'
```

## Ingestion Monitoring

### 68. Active Ingestion Tasks

```sql
SELECT
  task_id, type, datasource, status, runner_status,
  created_time, duration, location
FROM sys.tasks
WHERE status = 'RUNNING'
ORDER BY created_time;
```

### 69. Recently Failed Tasks

```sql
SELECT
  task_id, type, datasource, status,
  created_time, duration, error_msg
FROM sys.tasks
WHERE status = 'FAILED'
  AND created_time >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
ORDER BY created_time DESC;
```

### 70. Ingestion Task Duration Analysis

```sql
SELECT
  datasource,
  type,
  COUNT(*) AS tasks,
  AVG(duration) / 1000 AS avg_duration_sec,
  MAX(duration) / 1000 AS max_duration_sec
FROM sys.tasks
WHERE status = 'SUCCESS'
  AND created_time >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
GROUP BY 1, 2
ORDER BY avg_duration_sec DESC;
```

### 71. Kafka Consumer Group Lag (External)

```bash
# Check lag using Kafka CLI tools
kafka-consumer-groups.sh --bootstrap-server kafka:9092 \
  --describe --group druid-events-kafka-<supervisorId>
```

### 72. Submit a Kafka Supervisor

```bash
curl -X POST -H "Content-Type: application/json" \
  http://overlord:8090/druid/indexer/v1/supervisor \
  -d @kafka-supervisor-spec.json
```

### 73. Check Task Slot Utilization

```bash
# Check how many task slots are in use
curl http://overlord:8090/druid/indexer/v1/workers | \
  python3 -c "
import json, sys
workers = json.load(sys.stdin)
for w in workers:
    print(f\"{w['worker']['host']}: capacity={w['worker']['capacity']}, running={w['currCapacityUsed']}\")"
```

## Query Performance Diagnostics

### 74. Query Execution Timeline

```sql
-- Use EXPLAIN PLAN to see query translation
EXPLAIN PLAN FOR
SELECT country, COUNT(*) FROM events
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '7' DAY
GROUP BY 1 ORDER BY 2 DESC LIMIT 10;
```

### 75. Check Query Type Selection

```bash
# Submit SQL with header to get native query
curl -X POST -H "Content-Type: application/json" \
  http://broker:8082/druid/v2/sql \
  -d '{
    "query": "EXPLAIN PLAN FOR SELECT country, COUNT(*) FROM events WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '\''7'\'' DAY GROUP BY 1 ORDER BY 2 DESC LIMIT 10",
    "context": {"useNativeQueryExplain": true}
  }'
```

### 76. Query with Request Headers for Debugging

```bash
curl -X POST -H "Content-Type: application/json" \
  -H "X-Druid-Query-Id: debug-query-001" \
  http://broker:8082/druid/v2/sql \
  -d '{"query": "SELECT COUNT(*) FROM events"}'
# Response headers include: X-Druid-Query-Id, X-Druid-Response-Context
```

### 77. Check Segments Scanned per Query

```bash
# Response context includes segmentsScanned, segmentsPruned info
curl -X POST -H "Content-Type: application/json" \
  http://broker:8082/druid/v2/sql \
  -d '{
    "query": "SELECT COUNT(*) FROM events WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '\''1'\'' HOUR",
    "header": true,
    "context": {"enableQueryMetrics": true}
  }'
```

### 78. Time Boundary Check (Oldest/Newest Data)

```bash
curl -X POST -H "Content-Type: application/json" \
  http://broker:8082/druid/v2 \
  -d '{
    "queryType": "timeBoundary",
    "dataSource": "events"
  }'
```

### 79. Data Source Metadata (Latest Ingested Timestamp)

```bash
curl -X POST -H "Content-Type: application/json" \
  http://broker:8082/druid/v2 \
  -d '{
    "queryType": "dataSourceMetadata",
    "dataSource": "events"
  }'
```

### 80. Query Timeout Configuration Check

```bash
# Check configured timeout
curl -s http://broker:8082/status/properties | \
  python3 -c "
import json, sys
props = json.load(sys.stdin)
for k, v in props.items():
    if 'timeout' in k.lower():
        print(f'{k}: {v}')"
```

## Metrics and Performance

### 81. Druid Metrics Emission Configuration

```properties
# common.runtime.properties
druid.emitter=http
druid.emitter.http.recipientBaseUrl=http://metrics-collector:8080/

# Or emit to logging
druid.emitter=logging
druid.emitter.logging.logLevel=info

# Or emit to Prometheus
druid.emitter=prometheus
druid.emitter.prometheus.port=9090
```

### 82. Key Metrics to Monitor

```
# Query metrics (emitted by Broker)
query/time                    # Query execution time (ms)
query/bytes                   # Query response size (bytes)
query/count                   # Query count
query/failed/count            # Failed query count
query/interrupted/count       # Interrupted query count
query/cache/total/numEntries  # Cache entry count
query/cache/total/hitRate     # Cache hit rate

# Ingestion metrics (emitted by MiddleManager/Peon)
ingest/events/processed       # Events ingested
ingest/events/unparseable     # Failed to parse events
ingest/events/thrownAway      # Events outside time window
ingest/rows/output            # Rows written to segments
ingest/persists/count         # Persist count
ingest/persists/time          # Persist time (ms)
ingest/merge/time             # Merge time (ms)
ingest/handoff/count          # Segment handoff count

# Coordination metrics (emitted by Coordinator)
segment/count                 # Total segment count
segment/unavailable/count     # Unavailable segments
segment/overShadowed/count    # Overshadowed segments
segment/loadQueue/count       # Segments in load queue
segment/dropQueue/count       # Segments in drop queue

# Historical metrics
segment/scan/pending          # Pending segment scans
segment/used                  # Segments loaded (bytes)
segment/max                   # Max capacity (bytes)
query/segmentAndCache/time    # Segment + cache query time
```

### 83. JVM Metrics Check

```bash
# Check JVM status via status endpoint
curl http://historical:8083/status | python3 -c "
import json, sys
data = json.load(sys.stdin)
mem = data.get('memory', {})
print(f\"Max Memory: {mem.get('maxMemory', 0) / 1073741824:.1f} GB\")
print(f\"Total Memory: {mem.get('totalMemory', 0) / 1073741824:.1f} GB\")
print(f\"Free Memory: {mem.get('freeMemory', 0) / 1073741824:.1f} GB\")
print(f\"Used: {(mem.get('totalMemory', 0) - mem.get('freeMemory', 0)) / 1073741824:.1f} GB\")"
```

### 84. Check Loaded Extensions

```bash
curl -s http://broker:8082/status | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f\"Version: {data['version']}\")
for m in data.get('modules', []):
    print(f\"  - {m['name']} ({m.get('artifact', 'core')})\")"
```

## Lookup Diagnostics

### 85. List All Lookups

```bash
curl http://coordinator:8081/druid/coordinator/v1/lookups/config
```

### 86. Get Lookup Config for a Tier

```bash
curl http://coordinator:8081/druid/coordinator/v1/lookups/config/__default
```

### 87. Get Specific Lookup Configuration

```bash
curl http://coordinator:8081/druid/coordinator/v1/lookups/config/__default/country_names
```

### 88. Update a Lookup

```bash
curl -X POST -H "Content-Type: application/json" \
  http://coordinator:8081/druid/coordinator/v1/lookups/config/__default/country_names \
  -d '{
    "version": "2026-04-07-v2",
    "lookupExtractorFactory": {
      "type": "map",
      "map": {"US": "United States", "UK": "United Kingdom"}
    }
  }'
```

### 89. Delete a Lookup

```bash
curl -X DELETE http://coordinator:8081/druid/coordinator/v1/lookups/config/__default/country_names
```

### 90. Check Lookup Status on All Nodes

```bash
curl http://coordinator:8081/druid/coordinator/v1/lookups/nodeStatus
```

### 91. Introspect a Lookup (Check Loaded Data)

```bash
curl http://broker:8082/druid/v1/lookups/introspect/country_names
curl http://broker:8082/druid/v1/lookups/introspect/country_names/keys
curl http://broker:8082/druid/v1/lookups/introspect/country_names/values
```

## Information Schema Queries

### 92. List All Datasources

```sql
SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_SCHEMA, TABLE_NAME;
```

### 93. Column Details for a Datasource

```sql
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'druid' AND TABLE_NAME = 'events'
ORDER BY ORDINAL_POSITION;
```

### 94. Datasource Row Count Estimates

```sql
SELECT TABLE_NAME, TABLE_ROWS
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'druid'
ORDER BY TABLE_ROWS DESC;
```

## Deep Storage and Metadata

### 95. Kill Unused Segments (Permanently Delete from Deep Storage)

```bash
curl -X POST -H "Content-Type: application/json" \
  http://overlord:8090/druid/indexer/v1/task \
  -d '{
    "type": "kill",
    "dataSource": "events",
    "interval": "2026-01-01/2026-02-01"
  }'
```

### 96. Check Metadata Store Connectivity

```bash
# Verify Coordinator can reach metadata store by checking Coordinator logs
# or confirm via status endpoint
curl http://coordinator:8081/status/health
```

### 97. Mark All Segments Unused for a Datasource (Delete Datasource)

```bash
curl -X DELETE http://coordinator:8081/druid/coordinator/v1/datasources/events
```

### 98. Re-enable a Disabled Datasource

```bash
curl -X POST http://coordinator:8081/druid/coordinator/v1/datasources/events
```

### 99. Mark Segments Unused by Interval

```bash
curl -X POST -H "Content-Type: application/json" \
  http://coordinator:8081/druid/coordinator/v1/datasources/events/markUnused \
  -d '{"interval": "2026-01-01/2026-02-01"}'
```

## MSQ and Dart Diagnostics

### 100. Check MSQ Task Status

```bash
curl http://overlord:8090/druid/indexer/v1/task/<msqTaskId>/status
```

### 101. MSQ Task Report (Stages, Counters)

```bash
curl http://overlord:8090/druid/indexer/v1/task/<msqTaskId>/reports
```

### 102. List MSQ Queries via SQL

```bash
curl -X POST -H "Content-Type: application/json" \
  http://broker:8082/druid/v2/sql \
  -d '{
    "query": "SELECT task_id, type, datasource, status, created_time, duration FROM sys.tasks WHERE type = '\''query_controller'\'' ORDER BY created_time DESC LIMIT 20"
  }'
```

### 103. Cancel an MSQ Task

```bash
curl -X POST http://overlord:8090/druid/indexer/v1/task/<msqTaskId>/shutdown
```

### 104. Dart Query Reports (36+)

```bash
# Fetch reports for a Dart query
curl http://broker:8082/druid/v2/sql/queries/<sqlQueryId>/reports
```

### 105. Dart Query Listing

```bash
# List running Dart queries
curl http://broker:8082/druid/v2/sql/queries
```

## Cluster Maintenance

### 106. Enable/Disable Balance Coordinator

```bash
# Disable segment balancing (during maintenance)
curl -X POST -H "Content-Type: application/json" \
  http://coordinator:8081/druid/coordinator/v1/config \
  -d '{"maxSegmentsToMove": 0}'

# Re-enable
curl -X POST -H "Content-Type: application/json" \
  http://coordinator:8081/druid/coordinator/v1/config \
  -d '{"maxSegmentsToMove": 100}'
```

### 107. Force Compaction Run

```bash
# Submit manual compaction task
curl -X POST -H "Content-Type: application/json" \
  http://overlord:8090/druid/indexer/v1/task \
  -d '{
    "type": "compact",
    "dataSource": "events",
    "interval": "2026-04-01/2026-04-07",
    "tuningConfig": {
      "type": "index_parallel",
      "maxRowsPerSegment": 5000000,
      "partitionsSpec": {"type": "hashed"}
    }
  }'
```

### 108. Clean Up Cluster

```bash
# Remove metadata for supervisors that are terminated
curl -X POST http://overlord:8090/druid/indexer/v1/supervisor/terminateAll

# Force coordinator to run immediately
# (No direct API; restart Coordinator or wait for period)
```

### 109. Check ZooKeeper Connection

```bash
# Via ZooKeeper CLI
echo ruok | nc zookeeper-host 2181
echo stat | nc zookeeper-host 2181
echo mntr | nc zookeeper-host 2181
```

### 110. Verify Segment Loading After Restart

```bash
# Poll until load queue is empty
while true; do
  queue=$(curl -s "http://coordinator:8081/druid/coordinator/v1/loadqueue?simple")
  echo "$queue"
  echo "$queue" | grep -q '"0"' && echo "All segments loaded" && break
  sleep 10
done
```

## Troubleshooting Queries

### 111. Find Datasources with No Recent Data

```sql
SELECT
  datasource,
  MAX("end") AS latest_interval_end
FROM sys.segments
WHERE is_published = 1 AND is_overshadowed = 0
GROUP BY 1
HAVING MAX("end") < CURRENT_TIMESTAMP - INTERVAL '24' HOUR
ORDER BY latest_interval_end;
```

### 112. Detect Segment Gaps

```sql
-- Check for missing time intervals
SELECT
  s1."end" AS gap_start,
  s2.start AS gap_end
FROM (
  SELECT DISTINCT start, "end"
  FROM sys.segments
  WHERE datasource = 'events' AND is_published = 1 AND is_overshadowed = 0
) s1
CROSS JOIN (
  SELECT DISTINCT start, "end"
  FROM sys.segments
  WHERE datasource = 'events' AND is_published = 1 AND is_overshadowed = 0
) s2
WHERE s1."end" < s2.start
  AND NOT EXISTS (
    SELECT 1 FROM sys.segments s3
    WHERE s3.datasource = 'events'
      AND s3.is_published = 1
      AND s3.is_overshadowed = 0
      AND s3.start <= s1."end"
      AND s3."end" >= s2.start
  )
ORDER BY gap_start
LIMIT 20;
```

### 113. Identify Datasources with Compaction Debt

```sql
SELECT
  datasource,
  COUNT(*) AS total_segments,
  SUM(CASE WHEN num_rows < 1000000 THEN 1 ELSE 0 END) AS undersized,
  ROUND(
    SUM(CASE WHEN num_rows < 1000000 THEN 1.0 ELSE 0.0 END) / COUNT(*) * 100,
    1
  ) AS undersized_pct
FROM sys.segments
WHERE is_published = 1 AND is_overshadowed = 0
GROUP BY 1
HAVING COUNT(*) > 10
ORDER BY undersized_pct DESC;
```

### 114. Check for Duplicate Segments (Same Interval, Multiple Versions)

```sql
SELECT
  datasource,
  start,
  "end",
  COUNT(DISTINCT version) AS versions,
  COUNT(*) AS segments
FROM sys.segments
WHERE is_published = 1
GROUP BY 1, 2, 3
HAVING COUNT(DISTINCT version) > 1
ORDER BY versions DESC
LIMIT 20;
```

### 115. Real-Time vs. Historical Segment Breakdown

```sql
SELECT
  datasource,
  SUM(CASE WHEN is_realtime = 1 THEN 1 ELSE 0 END) AS realtime_segments,
  SUM(CASE WHEN is_realtime = 0 AND is_available = 1 THEN 1 ELSE 0 END) AS historical_segments,
  SUM(CASE WHEN is_available = 0 AND is_published = 1 AND is_overshadowed = 0 THEN 1 ELSE 0 END) AS unavailable_segments
FROM sys.segments
GROUP BY 1
ORDER BY unavailable_segments DESC;
```

### 116. Estimate Query Cost (Segments to Scan)

```sql
-- How many segments would a query touch?
SELECT
  COUNT(*) AS segments_to_scan,
  SUM(num_rows) AS total_rows,
  ROUND(SUM(size) / 1073741824.0, 2) AS total_gb
FROM sys.segments
WHERE datasource = 'events'
  AND is_published = 1
  AND is_overshadowed = 0
  AND is_available = 1
  AND start >= '2026-04-01'
  AND "end" <= '2026-04-08';
```

### 117. Server Segment Distribution (Balance Check)

```sql
SELECT
  server,
  COUNT(*) AS segment_count,
  ROUND(SUM(size) / 1073741824.0, 2) AS total_gb
FROM sys.server_segments
GROUP BY 1
ORDER BY total_gb DESC;
```

### 118. Identify Hot Spots (Servers with Disproportionate Load)

```sql
SELECT
  ss.server,
  s.tier,
  COUNT(*) AS segments,
  ROUND(SUM(ss.size) / 1073741824.0, 2) AS size_gb,
  ROUND(
    SUM(ss.size) * 100.0 /
    (SELECT SUM(size) FROM sys.server_segments),
    1
  ) AS pct_of_total
FROM sys.server_segments ss
JOIN sys.servers s ON ss.server = s.server
GROUP BY 1, 2
ORDER BY size_gb DESC;
```

### 119. Datasource Cardinality Estimation

```bash
curl -X POST -H "Content-Type: application/json" \
  http://broker:8082/druid/v2 \
  -d '{
    "queryType": "segmentMetadata",
    "dataSource": "events",
    "intervals": ["2026-04-01/2026-04-08"],
    "merge": true,
    "analysisTypes": ["cardinality"]
  }'
```

### 120. Historical Segment Cache Status

```bash
# Check what segments are cached on a specific Historical
curl http://historical:8083/druid/historical/v1/loadstatus
```

### 121. Check for Stuck Supervisors

```sql
SELECT supervisor_id, state, detailed_state, healthy, type
FROM sys.supervisors
WHERE healthy = 0 OR state != 'RUNNING';
```

### 122. View Server Properties

```sql
SELECT server, server_type, property_key, property_value
FROM sys.server_properties
WHERE property_key LIKE '%maxSize%' OR property_key LIKE '%tier%'
ORDER BY server;
```

## Emergency Operations

### 123. Emergency: Disable All Ingestion

```bash
# Suspend all supervisors
for sid in $(curl -s http://overlord:8090/druid/indexer/v1/supervisor | python3 -c "import json,sys; [print(s) for s in json.load(sys.stdin)]"); do
  echo "Suspending $sid"
  curl -X POST http://overlord:8090/druid/indexer/v1/supervisor/$sid/suspend
done
```

### 124. Emergency: Kill All Running Tasks

```bash
for tid in $(curl -s http://overlord:8090/druid/indexer/v1/runningTasks | python3 -c "import json,sys; [print(t['id']) for t in json.load(sys.stdin)]"); do
  echo "Shutting down $tid"
  curl -X POST http://overlord:8090/druid/indexer/v1/task/$tid/shutdown
done
```

### 125. Emergency: Graceful Shutdown of a Service

```bash
curl -X POST http://historical:8083/druid/admin/shutdown
```

### 126. Check Self-Discovery (Internal Communication)

```bash
curl http://broker:8082/druid/broker/v1/loadstatus
# Returns segment timeline information maintained by the Broker
```

### 127. Verify Metadata Store Tables

```sql
-- Connect directly to MySQL/PostgreSQL metadata store
-- Key tables:
SELECT COUNT(*) FROM druid_segments;            -- All segment records
SELECT COUNT(*) FROM druid_segments WHERE used = 1;  -- Active segments
SELECT COUNT(*) FROM druid_tasks;               -- Task history
SELECT COUNT(*) FROM druid_supervisors;         -- Supervisor configs
SELECT COUNT(*) FROM druid_rules;               -- Retention rules
SELECT COUNT(*) FROM druid_config;              -- Dynamic config
SELECT COUNT(*) FROM druid_audit;               -- Audit log
```

### 128. Re-Index Data for a Time Range

```sql
-- Use MSQ REPLACE to re-ingest a time range from the same datasource
REPLACE INTO events
OVERWRITE WHERE __time >= TIMESTAMP '2026-04-01' AND __time < TIMESTAMP '2026-04-02'
SELECT * FROM events
WHERE __time >= TIMESTAMP '2026-04-01' AND __time < TIMESTAMP '2026-04-02'
PARTITIONED BY DAY
CLUSTERED BY event_type;
```

### 129. Check Druid Web Console Accessibility

```bash
# The web console runs on the Router (default port 8888) or Coordinator (8081)
curl -s -o /dev/null -w "%{http_code}" http://router:8888/unified-console.html
```

### 130. Full Cluster Health Summary Script

```bash
#!/bin/bash
COORD="http://coordinator:8081"
OVERLORD="http://overlord:8090"
BROKER="http://broker:8082"

echo "=== Cluster Health ==="
echo "Coordinator: $(curl -s $COORD/status/health)"
echo "Overlord: $(curl -s $OVERLORD/status/health)"
echo "Broker: $(curl -s $BROKER/status/health)"

echo ""
echo "=== Load Status ==="
curl -s "$COORD/druid/coordinator/v1/loadstatus?simple"

echo ""
echo "=== Supervisor Status ==="
curl -s "$OVERLORD/druid/indexer/v1/supervisor?state=true"

echo ""
echo "=== Running Tasks ==="
curl -s "$OVERLORD/druid/indexer/v1/runningTasks" | python3 -c "
import json, sys
tasks = json.load(sys.stdin)
print(f'Running tasks: {len(tasks)}')
for t in tasks[:10]:
    print(f'  {t[\"id\"]}: {t.get(\"type\",\"?\")} on {t.get(\"location\",{}).get(\"host\",\"?\")}')"

echo ""
echo "=== Pending Tasks ==="
pending=$(curl -s "$OVERLORD/druid/indexer/v1/pendingTasks")
echo "Pending tasks: $(echo $pending | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"

echo ""
echo "=== Version ==="
curl -s "$BROKER/status" | python3 -c "import json,sys; print(f'Druid {json.load(sys.stdin)[\"version\"]}')"
```
