---
name: database-clickhouse-248lts
description: "ClickHouse 24.8 LTS version-specific expert. Deep knowledge of SharedMergeTree (Cloud), lightweight delete improvements, refreshable materialized views, Variant/Dynamic types (experimental), parallel replicas enhancements, S3Queue table engine, and production-hardened features. WHEN: \"ClickHouse 24.8\", \"24.8 LTS\", \"SharedMergeTree\", \"S3Queue\", \"refreshable materialized view\", \"parallel replicas 24\", \"ClickHouse 2024\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# ClickHouse 24.8 LTS Expert

You are a specialist in ClickHouse 24.8 LTS, released August 2024. This is a Long-Term Support release with maintenance until approximately August 2026. It represents a major stability milestone with significant features that matured from the 24.1-24.7 rapid releases.

**Support status:** Supported LTS. Receiving security fixes and critical bug fixes until August 2026.

## Major Features in 24.8 LTS

### SharedMergeTree (ClickHouse Cloud)

SharedMergeTree is the cloud-native storage engine available exclusively in ClickHouse Cloud. It replaces ReplicatedMergeTree for Cloud deployments by decoupling storage from compute:

**Key characteristics:**
- Data is stored in object storage (S3/GCS) with a local SSD cache
- Metadata is stored in ClickHouse Keeper (managed)
- Any node can read any data (no fixed shard assignment)
- Horizontal and vertical auto-scaling without data rebalancing
- Zero-copy replication (replicas share the same object storage data)

```sql
-- In ClickHouse Cloud, tables automatically use SharedMergeTree
CREATE TABLE events (
    event_time DateTime,
    user_id UInt64,
    event_type LowCardinality(String)
) ENGINE = SharedMergeTree('/clickhouse/tables/{uuid}', '{server}')
ORDER BY (event_type, user_id, event_time);
```

**SharedMergeTree vs. ReplicatedMergeTree:**
| Feature | SharedMergeTree | ReplicatedMergeTree |
|---|---|---|
| Storage | Object storage (shared) | Local disk per replica |
| Replication | Zero-copy (metadata only) | Full data copy per replica |
| Scaling | Add/remove nodes instantly | Requires data redistribution |
| Write availability | Any node can write | Any replica can write |
| Read locality | SSD cache + object storage | Local disk |

### Lightweight Deletes (Mature)

Lightweight deletes (`DELETE FROM`) matured significantly in the 24.x series:

```sql
-- Lightweight delete: marks rows as deleted without rewriting parts
DELETE FROM events WHERE user_id = 0 AND event_date < '2024-01-01';

-- Check delete progress
SELECT table, command, parts_to_do, is_done
FROM system.mutations
WHERE command LIKE 'DELETE%' AND NOT is_done;
```

**24.8 improvements:**
- `DELETE FROM` is now the recommended approach over `ALTER TABLE ... DELETE`
- Deletion masks are stored efficiently in part metadata
- Read filtering of deleted rows adds minimal overhead (<5% typically)
- Deleted rows are physically removed during natural background merges
- `OPTIMIZE TABLE FINAL` can force physical cleanup if needed

### Refreshable Materialized Views

24.8 stabilized refreshable materialized views -- materialized views that are periodically refreshed on a schedule (as opposed to standard MVs that trigger on each INSERT):

```sql
CREATE MATERIALIZED VIEW daily_summary
REFRESH EVERY 1 HOUR
ENGINE = MergeTree()
ORDER BY (event_date, event_type)
AS
SELECT
    toDate(event_time) AS event_date,
    event_type,
    count() AS total_events,
    uniqExact(user_id) AS unique_users,
    avg(duration_ms) AS avg_duration
FROM events
WHERE event_time >= now() - INTERVAL 2 DAY
GROUP BY event_date, event_type;
```

**Refresh modes:**
- `REFRESH EVERY interval` -- Periodic refresh at fixed intervals
- `REFRESH AFTER interval` -- Refresh after the specified duration since last refresh completion
- `REFRESH EVERY interval OFFSET offset` -- Periodic with offset (e.g., every hour at minute 5)

**Monitoring refreshable MVs:**
```sql
SELECT
    database,
    view,
    status,
    last_refresh_time,
    last_refresh_duration_ms,
    next_refresh_time,
    last_refresh_result,
    exception
FROM system.view_refreshes;
```

### Variant and Dynamic Types (Experimental)

24.8 introduced experimental support for semi-structured data types:

```sql
SET allow_experimental_variant_type = 1;

-- Variant: tagged union type
CREATE TABLE mixed_data (
    id UInt64,
    value Variant(UInt64, String, Array(UInt64))
) ENGINE = MergeTree() ORDER BY id;

INSERT INTO mixed_data VALUES (1, 42), (2, 'hello'), (3, [1, 2, 3]);

SELECT id, variantType(value) AS type, value FROM mixed_data;
```

```sql
SET allow_experimental_dynamic_type = 1;

-- Dynamic: fully flexible type (like JSON but typed)
CREATE TABLE flexible_data (
    id UInt64,
    payload Dynamic
) ENGINE = MergeTree() ORDER BY id;
```

**Note:** These types were experimental in 24.8 and matured in 25.x releases. For production use, prefer the JSON type or Map(String, String) in 24.8.

### Parallel Replicas Enhancements

Parallel replicas allow a single query to use multiple replicas for parallel execution, effectively scaling read throughput:

```sql
SET allow_experimental_parallel_reading_from_replicas = 2;
SET max_parallel_replicas = 3;
SET parallel_replicas_for_non_replicated_merge_tree = 1;

-- This query will be split across 3 replicas
SELECT event_type, count() FROM events GROUP BY event_type;
```

**24.8 improvements:**
- Better work distribution algorithm (less skew between replicas)
- Support for non-replicated MergeTree tables (splits by marks/ranges)
- Reduced coordination overhead
- Better support for queries with FINAL

### S3Queue Table Engine

S3Queue provides streaming ingestion from S3 (similar to Kafka but for object storage):

```sql
CREATE TABLE s3_queue (
    event_time DateTime,
    user_id UInt64,
    event_type String,
    data String
) ENGINE = S3Queue('https://bucket.s3.amazonaws.com/incoming/*.json', 'JSONEachRow')
SETTINGS
    mode = 'ordered',
    s3queue_polling_min_timeout_ms = 1000,
    s3queue_polling_max_timeout_ms = 10000,
    s3queue_processing_threads_num = 4;

-- Attach a materialized view to process the queue into a MergeTree table
CREATE MATERIALIZED VIEW s3_processor TO events AS
SELECT * FROM s3_queue;
```

### Query Cache

The query cache stores query results and returns them for identical subsequent queries:

```sql
SET use_query_cache = 1;
SET query_cache_ttl = 60;                -- cache results for 60 seconds
SET query_cache_min_query_runs = 2;      -- cache only after 2 executions

SELECT event_type, count() FROM events GROUP BY event_type
SETTINGS use_query_cache = 1;

-- Monitor cache
SELECT * FROM system.query_cache;
```

### Named Collections

Named collections store connection parameters for external integrations:

```sql
CREATE NAMED COLLECTION my_postgres AS
    host = 'postgres.example.com',
    port = 5432,
    user = 'reader',
    password = 'secret',
    database = 'analytics';

-- Use in queries
SELECT * FROM postgresql(my_postgres, table = 'users');

-- Use in table functions
CREATE TABLE pg_users AS postgresql(my_postgres, table = 'users');
```

## Configuration Changes in 24.8

### New Default Settings

| Setting | Old Default | 24.8 Default | Impact |
|---|---|---|---|
| `async_insert_use_adaptive_busy_timeout` | 0 | 1 | Better async insert batching |
| `allow_suspicious_low_cardinality_types` | 1 | 0 | Prevents LC on unsuitable types |
| `enable_named_columns_in_function_tuple` | 0 | 1 | Named tuple elements by default |

### Deprecated Features in 24.8

- `MergeTree` engine settings `min_rows_for_wide_part` and `min_bytes_for_wide_part` -- Prefer `min_rows_for_compact_part` and `min_bytes_for_compact_part`
- `system.graphite_retentions` table -- Use `system.graphite_retention_rules`
- Old JOIN syntax with commas (implicit cross join) -- Use explicit JOIN

## Migration Notes

### Upgrading to 24.8 LTS

**From 23.8 LTS:**
- Review breaking changes in 24.1 through 24.8 changelogs
- Test all materialized views (some internal representation changes)
- `allow_suspicious_low_cardinality_types` is now 0 by default -- existing LowCardinality(Nullable(...)) may cause warnings
- Parallel replicas are now more stable but may change query plans

**Compatibility settings:**
```sql
-- If you hit issues, these settings restore older behavior
SET compatibility = '23.8';
```

## Version-Specific Diagnostics

```sql
-- Check 24.8-specific system tables
SELECT * FROM system.view_refreshes;               -- Refreshable MV status
SELECT * FROM system.query_cache;                   -- Query cache contents
SELECT * FROM system.s3queue_log ORDER BY event_time DESC LIMIT 20;  -- S3Queue processing
SELECT * FROM system.named_collections;             -- Named collection configs

-- Check experimental features enabled
SELECT name, value FROM system.settings
WHERE name LIKE '%experimental%' AND changed;
```
