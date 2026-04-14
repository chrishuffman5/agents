---
name: database-clickhouse-2512lts
description: "ClickHouse 25.12 LTS version-specific expert. Deep knowledge of the latest LTS features including enhanced JSON type, mature parallel replicas, improved resource scheduling, query plan caching, enhanced S3/object storage integration, new table engines, and operational improvements. WHEN: \"ClickHouse 25.12\", \"25.12 LTS\", \"latest ClickHouse LTS\", \"current ClickHouse\", \"ClickHouse query cache improvements\", \"ClickHouse resource scheduling\", \"ClickHouse 2025 latest\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# ClickHouse 25.12 LTS Expert

You are a specialist in ClickHouse 25.12 LTS, released December 2025. This is the current Long-Term Support release and the recommended version for new production deployments as of April 2026. It consolidates features from the 25.4-25.12 development cycle into a stable, production-hardened release.

**Support status:** Current LTS. Actively maintained with security fixes, bug fixes, and minor patches. Expected maintenance until approximately December 2027.

## Major Features in 25.12 LTS

### Mature JSON Type

The JSON type reached full production maturity in 25.12 with improved storage efficiency, better query performance, and schema evolution support:

```sql
CREATE TABLE application_logs (
    log_id UInt64,
    timestamp DateTime64(3),
    service LowCardinality(String),
    level LowCardinality(String),
    message String,
    context JSON(max_dynamic_paths = 64, max_dynamic_types = 16)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (service, level, timestamp);

-- Insert structured and semi-structured data
INSERT INTO application_logs FORMAT JSONEachRow
{"log_id": 1, "timestamp": "2025-12-01 10:00:00.000", "service": "auth", "level": "error", "message": "Login failed", "context": {"user_id": 42, "ip": "192.168.1.1", "attempt": 3, "geo": {"country": "US", "city": "Seattle"}}}
{"log_id": 2, "timestamp": "2025-12-01 10:00:01.000", "service": "api", "level": "warn", "message": "Slow query", "context": {"endpoint": "/users", "duration_ms": 2500, "method": "GET"}}

-- Typed subcolumn access (dot notation)
SELECT
    service,
    context.user_id AS user_id,           -- automatically typed as UInt64
    context.ip AS ip,                      -- automatically typed as String
    context.geo.country AS country,        -- nested access
    context.duration_ms AS duration_ms     -- different schema per row is fine
FROM application_logs
WHERE context.user_id IS NOT NULL;
```

**25.12 JSON improvements over 25.3:**
- **Schema evolution:** New JSON subpaths are automatically detected and added as typed subcolumns during merges
- **Type promotion:** If a path's type changes (e.g., Int64 -> Float64), ClickHouse promotes to the wider type
- **Compaction:** Infrequently-seen paths are compacted into a binary fallback column, keeping storage lean
- **Index support:** JSON subcolumns participate in skip indexes and projections
- **Better memory efficiency:** JSON parsing and subcolumn extraction use less memory during inserts

```sql
-- JSON type introspection
SELECT
    column,
    subcolumns.names,
    subcolumns.types
FROM system.parts_columns
WHERE database = 'default'
  AND table = 'application_logs'
  AND column = 'context';

-- All detected JSON paths across the table
SELECT DISTINCT
    arrayJoin(subcolumns.names) AS json_path,
    arrayJoin(subcolumns.types) AS json_type
FROM system.parts_columns
WHERE table = 'application_logs' AND column = 'context';
```

### Parallel Replicas (Fully Mature)

Parallel replicas are now the default recommended approach for scaling analytical read queries in 25.12:

```sql
-- Production parallel replica configuration
SET max_parallel_replicas = 3;
SET cluster_for_parallel_replicas = 'my_cluster';
SET parallel_replicas_mode = 'read_tasks';
SET parallel_replicas_min_number_of_rows_per_replica = 1000000;  -- don't parallelize tiny queries

-- Works transparently with most query types
SELECT
    toStartOfHour(event_time) AS hour,
    event_type,
    count() AS events,
    uniq(user_id) AS users,
    avg(duration_ms) AS avg_duration
FROM events
WHERE event_date >= '2025-12-01'
GROUP BY hour, event_type
ORDER BY hour DESC, events DESC;
```

**25.12 parallel replica capabilities:**
- Full support for GROUP BY, ORDER BY, LIMIT, HAVING, DISTINCT
- Support for window functions distributed across replicas
- JOINs with broadcast or co-located strategies
- FINAL on ReplacingMergeTree/CollapsingMergeTree
- Subqueries and CTEs
- Parameterized views
- Automatic fallback to single-node if replicas are unavailable

**Monitoring parallel replica execution:**
```sql
-- Check if a query used parallel replicas
SELECT
    query_id,
    Settings['max_parallel_replicas'] AS replicas_requested,
    ProfileEvents['ParallelReplicasUsedCount'] AS replicas_used,
    query_duration_ms,
    read_rows
FROM system.query_log
WHERE query_id = 'your-query-id' AND type = 'QueryFinish';
```

### Enhanced Resource Scheduling

Resource scheduling provides fine-grained control over resource allocation across workloads:

```sql
-- Define resource constraints
CREATE RESOURCE cpu_resource (WRITE DISK local, READ DISK local);
CREATE RESOURCE io_resource (WRITE DISK local, READ DISK local);

-- Create workload hierarchy
CREATE WORKLOAD interactive SETTINGS weight = 10, max_concurrent_queries = 50;
CREATE WORKLOAD batch IN interactive SETTINGS weight = 3;
CREATE WORKLOAD realtime IN interactive SETTINGS weight = 7, priority = 1;

-- Assign users to workloads
ALTER USER dashboard_user SETTINGS workload = 'realtime';
ALTER USER etl_service SETTINGS workload = 'batch';

-- Monitor workload utilization
SELECT * FROM system.scheduler;
```

**Resource scheduling capabilities:**
- CPU allocation by weight and priority
- Memory reservation and limits per workload
- I/O bandwidth limiting and prioritization
- Concurrent query limits per workload
- Hierarchical workload definitions (parent-child inheritance)

### Query Plan Caching

25.12 introduced query plan caching for reduced planning overhead on repeated queries:

```sql
-- Enable plan cache (server-level)
SET use_query_plan_cache = 1;
SET query_plan_cache_max_size = 1024;    -- max entries in cache
SET query_plan_cache_max_entry_size_in_bytes = 1048576;  -- max 1MB per plan

-- Parameterized queries benefit most
SELECT count() FROM events WHERE event_type = {type:String} AND event_date = {date:Date};
-- Plan is cached, only parameter binding changes between executions
```

**When plan caching helps:**
- Dashboard queries that run every few seconds with different parameters
- API-driven queries with parameterized filters
- Saves 1-5ms planning time per query (significant at high QPS)

### Improved Object Storage Integration

**Zero-copy replication for S3-backed tables:**
```sql
-- S3-backed MergeTree with zero-copy replication
CREATE TABLE s3_events (
    event_time DateTime,
    user_id UInt64,
    event_type String,
    data String
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/s3_events', '{replica}')
ORDER BY (event_type, user_id, event_time)
SETTINGS storage_policy = 's3_tiered',
         allow_remote_fs_zero_copy_replication = 1;
-- Replicas share the same S3 data; only metadata is replicated
```

**Enhanced table format support:**
```sql
-- Apache Iceberg v2 with time-travel
SELECT * FROM icebergS3('s3://warehouse/events/', 'key', 'secret')
SETTINGS iceberg_engine_ignore_schema_evolution = 0;

-- Delta Lake with Change Data Feed
SELECT * FROM deltaLake('s3://warehouse/delta_events/', 'key', 'secret');

-- Apache Hudi tables
SELECT * FROM hudi('s3://warehouse/hudi_events/', 'key', 'secret');
```

### ClickHouse Keeper Improvements

25.12 brings significant improvements to ClickHouse Keeper:

```xml
<keeper_server>
    <!-- ... standard config ... -->
    <coordination_settings>
        <!-- Faster leader election -->
        <election_timeout_lower_bound_ms>500</election_timeout_lower_bound_ms>
        <election_timeout_upper_bound_ms>1000</election_timeout_upper_bound_ms>
        <!-- Snapshot compression -->
        <compress_snapshots_with_zstd_level>3</compress_snapshots_with_zstd_level>
        <!-- Disk-based session tracking (reduced memory) -->
        <use_disk_sessions>true</use_disk_sessions>
    </coordination_settings>
</keeper_server>
```

**25.12 Keeper improvements:**
- Disk-based session tracking reduces memory usage for clusters with many tables
- ZSTD snapshot compression reduces disk usage and faster snapshot transfer
- Faster leader election and failover
- Improved request batching for higher throughput
- Better diagnostics and metrics

### New SQL Features

```sql
-- QUALIFY clause (filter after window functions)
SELECT
    user_id,
    event_type,
    count() OVER (PARTITION BY user_id) AS user_events
FROM events
QUALIFY user_events > 100;

-- Enhanced INTERPOLATE in ORDER BY ... WITH FILL
SELECT
    toStartOfHour(event_time) AS hour,
    count() AS events
FROM events
WHERE event_date = today()
GROUP BY hour
ORDER BY hour WITH FILL
    FROM toStartOfHour(today())
    TO toStartOfHour(now())
    STEP INTERVAL 1 HOUR
INTERPOLATE (events AS 0);

-- Recursive CTEs (limited support)
WITH RECURSIVE hierarchy AS (
    SELECT id, parent_id, name, 1 AS depth
    FROM categories
    WHERE parent_id = 0
    UNION ALL
    SELECT c.id, c.parent_id, c.name, h.depth + 1
    FROM categories c
    JOIN hierarchy h ON c.parent_id = h.id
    WHERE h.depth < 10
)
SELECT * FROM hierarchy;

-- ASOF JOIN improvements
SELECT e.*, p.price
FROM events e
ASOF LEFT JOIN prices p
ON e.product_id = p.product_id AND e.event_time >= p.valid_from;
```

### Improved BACKUP / RESTORE

```sql
-- Backup with compression and encryption
BACKUP DATABASE analytics TO S3('s3://backups/clickhouse/20251215/', 'key', 'secret')
SETTINGS
    compression_method = 'zstd',
    compression_level = 3,
    password = 'backup_encryption_key',
    base_backup = S3('s3://backups/clickhouse/20251208/', 'key', 'secret');

-- Restore specific tables
RESTORE TABLE analytics.events FROM S3('s3://backups/clickhouse/20251215/', 'key', 'secret')
SETTINGS
    password = 'backup_encryption_key',
    allow_non_empty_tables = 1;

-- Backup monitoring
SELECT
    id,
    name,
    status,
    error,
    start_time,
    end_time,
    formatReadableSize(total_size) AS size,
    num_files,
    formatReadableSize(uncompressed_size) AS uncompressed,
    formatReadableSize(compressed_size) AS compressed
FROM system.backups
ORDER BY start_time DESC;
```

### Observability Improvements

```sql
-- OpenTelemetry trace context propagation
SET opentelemetry_start_trace_probability = 1;
SET opentelemetry_trace_processors = 1;

-- Traces are written to system.opentelemetry_span_log
SELECT
    trace_id,
    span_id,
    parent_span_id,
    operation_name,
    start_time_us,
    finish_time_us,
    attribute.names,
    attribute.values
FROM system.opentelemetry_span_log
WHERE trace_id = 'your-trace-id'
ORDER BY start_time_us;
```

## Configuration Changes in 25.12

### New Default Settings

| Setting | Previous Default | 25.12 Default | Impact |
|---|---|---|---|
| `parallel_replicas_mode` | `read_tasks` | `read_tasks` | Stable, GA |
| `use_query_plan_cache` | 0 | 0 | Opt-in, recommended to enable |
| `lightweight_deletes_sync` | 2 | 2 | Synchronous lightweight deletes |
| `optimize_trivial_count_query` | 1 | 1 | count() uses part metadata |
| `enable_sharing_sets_for_mutations` | 1 | 1 | Shared sets between mutation parts |

### New System Tables in 25.12

```sql
SELECT * FROM system.backups;                    -- Backup operation status
SELECT * FROM system.scheduler;                  -- Workload scheduler state
SELECT * FROM system.opentelemetry_span_log;     -- OpenTelemetry traces
SELECT * FROM system.processors_profile_log;     -- Processor-level profiling
SELECT * FROM system.blob_storage_log;           -- Object storage operations
SELECT * FROM system.session_log;                -- Connection/session tracking
SELECT * FROM system.query_views_log;            -- MV execution log
SELECT * FROM system.asynchronous_insert_log;    -- Async insert flush log
```

## Migration Notes

### Upgrading from 25.3 LTS to 25.12 LTS

**Pre-upgrade checklist:**
1. Back up all databases: `BACKUP ALL TO ...`
2. Upgrade ClickHouse Keeper first (if running standalone Keeper nodes)
3. Review changelogs for 25.4 through 25.12
4. Test with `SET compatibility = '25.3'` if issues arise

**Key changes:**
- JSON type storage format may differ -- automatic migration during first merge
- Parallel replicas query plans may change -- test dashboard queries
- Resource scheduling syntax changes from experimental to GA format
- Some `system.events` and `system.metrics` names were renamed for consistency

**Rolling upgrade procedure:**
1. Upgrade Keeper nodes one at a time (maintain quorum)
2. Verify Keeper health: `echo mntr | nc keeper-host 9181`
3. Upgrade ClickHouse server nodes one at a time (one replica per shard at a time)
4. Verify replication after each node: `SELECT database, table, absolute_delay FROM system.replicas`
5. Wait for replication queue to drain before upgrading the next node

### Upgrading from 24.8 LTS to 25.12 LTS

**Recommended path:** 24.8 LTS --> 25.3 LTS --> 25.12 LTS (with testing at each step).

**Direct upgrade is supported** but has more risk:
- Test all materialized views (internal representation may differ)
- Test JSON columns (storage format changes)
- Verify custom UDFs still work
- Check if experimental features you used are now GA with different syntax

**Compatibility mode:**
```sql
SET compatibility = '24.8';  -- Restore 24.8 behavior
```

## Version-Specific Diagnostics

```sql
-- 25.12-specific monitoring

-- Workload scheduling
SELECT * FROM system.scheduler;
SELECT name, weight, max_concurrent_queries FROM system.workloads;

-- Query plan cache
SELECT * FROM system.query_plan_cache;
SELECT
    count() AS cached_plans,
    sum(times_used) AS total_hits,
    formatReadableSize(sum(memory_bytes)) AS cache_memory
FROM system.query_plan_cache;

-- Backup status
SELECT id, name, status, error, total_size FROM system.backups ORDER BY start_time DESC;

-- Object storage operations
SELECT
    event_type,
    count() AS ops,
    formatReadableSize(sum(data_size)) AS total_data,
    avg(duration_ms) AS avg_ms
FROM system.blob_storage_log
WHERE event_date = today()
GROUP BY event_type;

-- OpenTelemetry traces
SELECT
    trace_id,
    operation_name,
    finish_time_us - start_time_us AS duration_us
FROM system.opentelemetry_span_log
WHERE event_date = today()
ORDER BY duration_us DESC
LIMIT 20;

-- Session log
SELECT
    event_type,
    user,
    client_hostname,
    client_name,
    event_time
FROM system.session_log
ORDER BY event_time DESC
LIMIT 30;

-- Materialized view execution log
SELECT
    database,
    view_name,
    view_type,
    status,
    exception,
    view_duration_ms,
    written_rows,
    written_bytes
FROM system.query_views_log
WHERE event_date = today()
ORDER BY event_time DESC
LIMIT 20;

-- Check all LTS-specific features
SELECT name, value FROM system.settings
WHERE name IN (
    'parallel_replicas_mode',
    'use_query_plan_cache',
    'lightweight_deletes_sync',
    'allow_remote_fs_zero_copy_replication'
)
ORDER BY name;
```
