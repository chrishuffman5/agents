---
name: database-clickhouse-253lts
description: "ClickHouse 25.3 LTS version-specific expert. Deep knowledge of Variant/Dynamic types GA, JSON type improvements, enhanced parallel replicas, new aggregate functions, Kafka engine improvements, improved lightweight deletes, query profiling enhancements, and resource management. WHEN: \"ClickHouse 25.3\", \"25.3 LTS\", \"ClickHouse 2025\", \"Variant type GA\", \"Dynamic type GA\", \"JSON column ClickHouse\", \"resource groups ClickHouse\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# ClickHouse 25.3 LTS Expert

You are a specialist in ClickHouse 25.3 LTS, released March 2025. This is a Long-Term Support release that builds upon the 24.8 LTS foundation with stabilized semi-structured data types, improved query execution, and enhanced operational tooling.

**Support status:** Supported LTS. Actively maintained with security and bug fixes.

## Major Features in 25.3 LTS

### Variant and Dynamic Types (GA)

The Variant and Dynamic types graduated from experimental to generally available in the 25.x series:

**Variant type -- tagged union:**
```sql
-- No experimental flag needed in 25.3
CREATE TABLE telemetry (
    device_id UInt64,
    timestamp DateTime64(3),
    reading Variant(Float64, String, UInt64, Array(Float64))
) ENGINE = MergeTree()
ORDER BY (device_id, timestamp);

INSERT INTO telemetry VALUES
    (1, now(), 23.5),
    (2, now(), 'error: sensor offline'),
    (3, now(), 42),
    (4, now(), [1.1, 2.2, 3.3]);

-- Query with type filtering
SELECT
    device_id,
    variantType(reading) AS type,
    reading.Float64 AS float_value,
    reading.String AS string_value,
    reading.UInt64 AS uint_value
FROM telemetry;

-- Filter by variant type
SELECT * FROM telemetry WHERE variantType(reading) = 'Float64';
```

**Dynamic type -- fully flexible:**
```sql
CREATE TABLE flexible_events (
    event_id UInt64,
    event_time DateTime,
    payload Dynamic(max_types = 16)
) ENGINE = MergeTree()
ORDER BY (event_time);

INSERT INTO flexible_events VALUES
    (1, now(), '{"action": "click", "x": 100, "y": 200}'),
    (2, now(), 42),
    (3, now(), [1, 2, 3]);

-- Access subcolumns dynamically
SELECT
    event_id,
    dynamicType(payload) AS type,
    payload.:String AS as_string,
    payload.:UInt64 AS as_uint
FROM flexible_events;
```

**Variant/Dynamic storage internals:**
- Each variant discriminator type is stored in a separate column substream
- The type tag is stored as a UInt8 (for Variant) or dictionary-encoded string (for Dynamic)
- Compression is still column-oriented per discriminator type
- `max_types` for Dynamic controls memory usage: types beyond the limit fall back to String serialization

### JSON Type Improvements

The JSON type received significant improvements for semi-structured data handling:

```sql
CREATE TABLE logs (
    timestamp DateTime,
    level LowCardinality(String),
    message String,
    metadata JSON
) ENGINE = MergeTree()
ORDER BY (level, timestamp);

INSERT INTO logs FORMAT JSONEachRow
{"timestamp": "2025-03-15 10:00:00", "level": "error", "message": "Connection failed", "metadata": {"host": "db-01", "port": 5432, "retry_count": 3, "tags": ["critical", "database"]}}

-- Access JSON subcolumns using dot notation
SELECT
    timestamp,
    metadata.host AS host,
    metadata.port AS port,
    metadata.retry_count AS retries,
    metadata.tags AS tags
FROM logs
WHERE metadata.host = 'db-01';

-- JSON paths are automatically detected and stored as typed subcolumns
-- Check detected schema
SELECT
    column,
    type,
    subcolumns.names,
    subcolumns.types
FROM system.parts_columns
WHERE table = 'logs' AND column = 'metadata'
LIMIT 1;
```

**JSON type behavior in 25.3:**
- Automatic subcolumn type inference from inserted data
- Typed subcolumns stored in columnar format (efficient compression)
- Subcolumns for paths seen in >N% of rows are stored as regular typed columns
- Rare paths are stored in a catch-all binary column
- Configurable via `max_dynamic_paths` and `max_dynamic_types`

### Enhanced Parallel Replicas

Parallel replicas moved beyond experimental in 25.3 with broader query coverage:

```sql
-- Production-ready parallel replica settings
SET parallel_replicas_mode = 'read_tasks';        -- or 'custom_key'
SET max_parallel_replicas = 3;
SET cluster_for_parallel_replicas = 'my_cluster';

-- Supported query types now include:
-- - Simple aggregations (GROUP BY)
-- - JOINs (with some restrictions)
-- - Subqueries
-- - Window functions
-- - FINAL queries on ReplacingMergeTree
```

**Custom key mode for co-located JOINs:**
```sql
SET parallel_replicas_mode = 'custom_key';
SET parallel_replicas_custom_key = 'sipHash64(user_id)';

-- Each replica processes a range of user_ids
-- JOINs on user_id are local to each replica (no network shuffle)
SELECT e.*, u.name
FROM events e JOIN users u ON e.user_id = u.user_id;
```

### New Aggregate Functions

25.3 added several new aggregate functions:

```sql
-- Exponentially weighted moving average
SELECT exponentialMovingAverage(0.5)(value, timestamp) FROM metrics;

-- Kolmogorov-Smirnov test
SELECT kolmogorovSmirnovTest(value, group_flag) FROM samples;

-- Improved quantile functions
SELECT quantileGK(0.95, 1000)(response_time) FROM requests;  -- Greenwald-Khanna with accuracy

-- Array aggregation improvements
SELECT groupArraySorted(10)(value) FROM events;  -- Top-10 values sorted
SELECT groupArrayLast(100)(message) FROM logs;    -- Last 100 messages
```

### Resource Management (Workload Scheduling)

25.3 improved workload scheduling for multi-tenant environments:

```sql
-- Create resource groups
CREATE RESOURCE POOL dashboard_pool
SETTINGS max_threads = 8, max_memory_usage = 5000000000;

CREATE RESOURCE POOL etl_pool
SETTINGS max_threads = 4, max_memory_usage = 20000000000;

-- Assign users to pools
ALTER USER dashboard_user SETTINGS workload = 'dashboard_pool';
ALTER USER etl_service SETTINGS workload = 'etl_pool';
```

**Workload classification:**
- Queries can be classified into workloads based on user, query type, or query settings
- Each workload has configurable CPU, memory, and I/O limits
- Priority-based scheduling ensures interactive queries are not starved by batch ETL

### Improved Lightweight Deletes

Lightweight deletes received further optimization in 25.3:

```sql
-- Delete with improved performance
DELETE FROM events WHERE user_id IN (SELECT user_id FROM gdpr_requests);

-- Row-level delete masks are now more efficiently stored
-- Background cleanup of deleted rows during merges is faster
-- FINAL no longer required to exclude lightweight-deleted rows (they are always filtered)
```

**Performance characteristics in 25.3:**
- DELETE execution: near-instant (writes a deletion mask only)
- Read overhead: <2% for selective deletes, <5% for bulk deletes
- Physical cleanup: happens naturally during merges, no explicit action needed
- Compaction: deleted rows reduce part size after merge

### Query Profiling Enhancements

New profiling capabilities for deep query analysis:

```sql
-- Processor-level profiling
SET log_processors_profiles = 1;

SELECT event_type, count() FROM events GROUP BY event_type
SETTINGS query_id = 'profile-test-001';

-- View processor-level profile
SELECT
    query_id,
    name AS processor_name,
    elapsed_us,
    input_wait_elapsed_us,
    output_wait_elapsed_us,
    input_rows,
    input_bytes,
    output_rows,
    output_bytes
FROM system.processors_profile_log
WHERE query_id = 'profile-test-001'
ORDER BY elapsed_us DESC;
```

### S3-Compatible Object Storage Improvements

Enhanced support for S3 as both a data source and storage backend:

```sql
-- Table function with glob patterns and schema inference
SELECT * FROM s3('https://bucket.s3.amazonaws.com/data/year=2025/month=03/*.parquet')
WHERE event_type = 'purchase';

-- Hive-partitioned S3 data (automatically detects year/month from path)
SELECT * FROM s3('https://bucket.s3.amazonaws.com/data/**/*.parquet', SETTINGS hive_partitioning = 1)
WHERE year = 2025 AND month = 3;

-- Iceberg table format support
CREATE TABLE iceberg_events
ENGINE = Iceberg('https://bucket.s3.amazonaws.com/warehouse/events/', 'key', 'secret');

-- Delta Lake format support
CREATE TABLE delta_events
ENGINE = DeltaLake('https://bucket.s3.amazonaws.com/delta/events/', 'key', 'secret');
```

### Async Insert Improvements

```sql
-- Adaptive busy timeout (enabled by default in 25.3)
-- The server dynamically adjusts flush timing based on insert rate
SET async_insert = 1;
SET async_insert_use_adaptive_busy_timeout = 1;
SET async_insert_busy_timeout_min_ms = 50;      -- minimum flush interval
SET async_insert_busy_timeout_max_ms = 5000;    -- maximum flush interval

-- Deduplication for async inserts
SET async_insert_deduplicate = 1;
-- Each insert block gets a hash; duplicate blocks are rejected
```

## Configuration Changes in 25.3

### New Default Settings

| Setting | Previous Default | 25.3 Default | Impact |
|---|---|---|---|
| `parallel_replicas_mode` | experimental | `read_tasks` | Parallel replicas production-ready |
| `async_insert_use_adaptive_busy_timeout` | 1 | 1 | Adaptive flush timing |
| `input_format_json_try_infer_numbers_from_strings` | 0 | 1 | Better JSON schema inference |
| `optimize_functions_to_subcolumns` | 1 | 1 | Automatic subcolumn optimization |

### New System Tables

```sql
-- Processor-level query profiling
SELECT * FROM system.processors_profile_log;

-- Backup/restore operation log
SELECT * FROM system.backup_log;

-- Blob storage operations log
SELECT * FROM system.blob_storage_log;

-- Session log (connections/disconnections)
SELECT * FROM system.session_log;
```

### Deprecated Features in 25.3

- Old-style dictionaries in `<dictionaries>` config section -- Migrate to `CREATE DICTIONARY` DDL
- `system.graphite_retentions` -- Use `system.graphite_retention_rules`
- `distributed_product_mode = 'local'` -- Use `'global'` for correct distributed JOINs
- Legacy ZooKeeper (Java) -- Migrate to ClickHouse Keeper

## Migration Notes

### Upgrading from 24.8 LTS to 25.3 LTS

**Pre-upgrade checklist:**
1. Back up critical data: `BACKUP DATABASE ... TO ...`
2. Review breaking changes in 25.1, 25.2, 25.3 changelogs
3. Test queries with `SET compatibility = '24.8'` to identify behavior changes
4. Verify ClickHouse Keeper compatibility (Keeper should be upgraded first)

**Key changes affecting queries:**
- JSON type inference is stricter -- some implicit type coercions may change
- Parallel replicas may alter query plans (test dashboard queries)
- `max_memory_usage` default behavior changed for distributed queries

**Compatibility mode:**
```sql
-- If you encounter issues, restore old behavior
SET compatibility = '24.8';
-- Then incrementally test new behavior
```

### Upgrading from 23.x to 25.3

Not recommended as a direct jump. Upgrade path:
1. 23.8 LTS --> 24.8 LTS (test and stabilize)
2. 24.8 LTS --> 25.3 LTS (test and stabilize)

## Version-Specific Diagnostics

```sql
-- 25.3-specific monitoring
SELECT * FROM system.processors_profile_log WHERE query_id = 'xxx';
SELECT * FROM system.backup_log ORDER BY event_time DESC LIMIT 10;
SELECT * FROM system.blob_storage_log ORDER BY event_time DESC LIMIT 10;
SELECT * FROM system.session_log ORDER BY event_time DESC LIMIT 20;

-- Verify parallel replicas are working
EXPLAIN PIPELINE
SELECT count() FROM events
SETTINGS max_parallel_replicas = 3, cluster_for_parallel_replicas = 'my_cluster';

-- Check workload scheduling
SELECT * FROM system.scheduler;

-- JSON subcolumn detection
SELECT
    column,
    subcolumns.names,
    subcolumns.types,
    subcolumns.serializations
FROM system.parts_columns
WHERE table = 'logs' AND column = 'metadata';

-- Variant/Dynamic type usage
SELECT
    database, table, column, type
FROM system.columns
WHERE type LIKE 'Variant%' OR type LIKE 'Dynamic%';
```
