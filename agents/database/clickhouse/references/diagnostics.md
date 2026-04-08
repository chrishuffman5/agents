# ClickHouse Diagnostics Reference

## Server Health and Status

### 1. Server Version and Uptime

```sql
SELECT version();
```

```sql
SELECT
    uptime() AS uptime_seconds,
    formatReadableTimeDelta(uptime()) AS uptime_human;
```

### 2. Server-Level Metrics Overview

```sql
SELECT metric, value, description
FROM system.metrics
ORDER BY metric;
```

Key metrics to watch:
| Metric | Healthy Range | Concern |
|---|---|---|
| `Query` | 0-100 | >200 concurrent queries: possible bottleneck |
| `Merge` | 0-20 | >50: merge backlog |
| `PartMutation` | 0-5 | >20: mutation backlog |
| `ReplicatedSend` | 0-5 | >10: replication transfer bottleneck |
| `ReplicatedFetch` | 0-5 | >10: replication falling behind |
| `BackgroundPoolTask` | 0-16 | = pool size: fully saturated |
| `OpenFileForRead` | varies | sudden spike: possible file descriptor issue |
| `MemoryTracking` | <80% RAM | >90% RAM: OOM risk |

### 3. Cumulative Event Counters

```sql
SELECT event, value, description
FROM system.events
ORDER BY value DESC
LIMIT 50;
```

### 4. Asynchronous Metrics (OS-level + Background)

```sql
SELECT metric, value, description
FROM system.asynchronous_metrics
WHERE metric LIKE '%Memory%' OR metric LIKE '%CPU%' OR metric LIKE '%Disk%'
ORDER BY metric;
```

### 5. Memory Usage Breakdown

```sql
SELECT
    metric,
    formatReadableSize(value) AS size
FROM system.asynchronous_metrics
WHERE metric IN (
    'OSMemoryTotal', 'OSMemoryAvailable', 'OSMemoryBuffers', 'OSMemoryCached',
    'MemoryResident', 'MemoryShared', 'MemoryCode'
)
ORDER BY metric;
```

```sql
-- Per-query memory tracking
SELECT metric, formatReadableSize(value) AS value
FROM system.metrics
WHERE metric LIKE '%Memory%';
```

### 6. Current Running Queries

```sql
SELECT
    query_id,
    user,
    elapsed,
    formatReadableSize(memory_usage) AS memory,
    read_rows,
    formatReadableSize(read_bytes) AS read_data,
    query
FROM system.processes
ORDER BY elapsed DESC;
```

### 7. Kill a Running Query

```sql
KILL QUERY WHERE query_id = 'your-query-id';
KILL QUERY WHERE user = 'problematic_user' AND elapsed > 300;
```

### 8. Server Settings Overview

```sql
SELECT name, value, changed, description
FROM system.settings
WHERE changed = 1
ORDER BY name;
```

### 9. Server Configuration Differences from Default

```sql
SELECT name, value, default AS default_value, description
FROM system.server_settings
WHERE value != default
ORDER BY name;
```

### 10. Database and Table Sizes

```sql
SELECT
    database,
    table,
    formatReadableSize(sum(bytes_on_disk)) AS disk_size,
    formatReadableSize(sum(data_compressed_bytes)) AS compressed,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed,
    round(sum(data_uncompressed_bytes) / sum(data_compressed_bytes), 2) AS compression_ratio,
    sum(rows) AS total_rows,
    count() AS part_count
FROM system.parts
WHERE active
GROUP BY database, table
ORDER BY sum(bytes_on_disk) DESC;
```

### 11. Total Disk Usage by Database

```sql
SELECT
    database,
    formatReadableSize(sum(bytes_on_disk)) AS total_size,
    sum(rows) AS total_rows,
    count() AS total_parts
FROM system.parts
WHERE active
GROUP BY database
ORDER BY sum(bytes_on_disk) DESC;
```

## Query Performance Analysis

### 12. Slow Query Log (Top 20 Slowest Queries in Last 24h)

```sql
SELECT
    type,
    query_start_time,
    query_duration_ms,
    formatReadableSize(read_bytes) AS read_data,
    read_rows,
    formatReadableSize(memory_usage) AS peak_memory,
    result_rows,
    query
FROM system.query_log
WHERE type = 'QueryFinish'
  AND event_date >= today() - 1
  AND query_duration_ms > 1000
ORDER BY query_duration_ms DESC
LIMIT 20;
```

### 13. Failed Queries (Errors and Exceptions)

```sql
SELECT
    event_time,
    query_duration_ms,
    exception_code,
    exception,
    query
FROM system.query_log
WHERE type = 'ExceptionWhileProcessing'
  AND event_date >= today() - 1
ORDER BY event_time DESC
LIMIT 20;
```

### 14. Query Throughput Over Time (Queries per Minute)

```sql
SELECT
    toStartOfMinute(event_time) AS minute,
    count() AS queries,
    avg(query_duration_ms) AS avg_ms,
    quantile(0.95)(query_duration_ms) AS p95_ms,
    quantile(0.99)(query_duration_ms) AS p99_ms
FROM system.query_log
WHERE type = 'QueryFinish'
  AND event_date = today()
GROUP BY minute
ORDER BY minute DESC
LIMIT 60;
```

### 15. Most Expensive Queries by Resource Consumption

```sql
SELECT
    normalized_query_hash,
    count() AS executions,
    avg(query_duration_ms) AS avg_ms,
    max(query_duration_ms) AS max_ms,
    formatReadableSize(avg(read_bytes)) AS avg_read,
    formatReadableSize(avg(memory_usage)) AS avg_memory,
    any(query) AS sample_query
FROM system.query_log
WHERE type = 'QueryFinish'
  AND event_date >= today() - 7
GROUP BY normalized_query_hash
ORDER BY avg(query_duration_ms) * count() DESC
LIMIT 20;
```

### 16. Query Log Thread-Level Details

```sql
SELECT
    query_id,
    thread_name,
    thread_id,
    elapsed AS thread_elapsed_sec,
    ProfileEvents.Names AS event_names,
    ProfileEvents.Values AS event_values
FROM system.query_thread_log
WHERE query_id = 'your-query-id'
ORDER BY thread_name;
```

### 17. Query Profile Events (Per-Query I/O and CPU)

```sql
SELECT
    query_id,
    ProfileEvents['ReadCompressedBytes'] AS read_compressed,
    ProfileEvents['CompressedReadBufferBlocks'] AS blocks_read,
    ProfileEvents['SelectedMarks'] AS marks_selected,
    ProfileEvents['SelectedRows'] AS rows_selected,
    ProfileEvents['SelectedParts'] AS parts_selected,
    ProfileEvents['RealTimeMicroseconds'] AS wall_time_us,
    ProfileEvents['UserTimeMicroseconds'] AS cpu_user_us,
    ProfileEvents['SystemTimeMicroseconds'] AS cpu_sys_us,
    ProfileEvents['DiskReadElapsedMicroseconds'] AS disk_read_us,
    ProfileEvents['NetworkSendElapsedMicroseconds'] AS net_send_us
FROM system.query_log
WHERE query_id = 'your-query-id'
  AND type = 'QueryFinish';
```

### 18. Queries Currently Waiting for Locks

```sql
SELECT
    query_id,
    user,
    elapsed,
    query
FROM system.processes
WHERE is_initial_query = 1
  AND elapsed > 5
ORDER BY elapsed DESC;
```

### 19. INSERT Performance Analysis

```sql
SELECT
    event_time,
    query_duration_ms,
    written_rows,
    formatReadableSize(written_bytes) AS written_data,
    query
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query_kind = 'Insert'
  AND event_date = today()
ORDER BY query_duration_ms DESC
LIMIT 20;
```

### 20. Async Insert Monitoring

```sql
SELECT
    query_id,
    database,
    table,
    format,
    bytes,
    rows,
    exception
FROM system.asynchronous_inserts;
```

```sql
-- Async insert flush metrics
SELECT
    database, table,
    count() AS flush_count,
    sum(rows) AS total_rows,
    formatReadableSize(sum(bytes)) AS total_bytes
FROM system.asynchronous_insert_log
WHERE event_date = today()
GROUP BY database, table
ORDER BY total_rows DESC;
```

## EXPLAIN Commands

### 21. EXPLAIN PLAN -- Query Plan

```sql
EXPLAIN PLAN actions = 1
SELECT event_type, count() FROM events WHERE event_date = today() GROUP BY event_type;
```

Output shows the logical plan including actions (expressions, filters, aggregation).

### 22. EXPLAIN PIPELINE -- Execution Pipeline

```sql
EXPLAIN PIPELINE
SELECT event_type, count() FROM events WHERE event_date = today() GROUP BY event_type;
```

Shows physical execution pipeline with parallelism (number of threads per stage).

### 23. EXPLAIN AST -- Abstract Syntax Tree

```sql
EXPLAIN AST
SELECT event_type, count() FROM events WHERE event_date = today() GROUP BY event_type;
```

### 24. EXPLAIN SYNTAX -- Query Rewriting

```sql
EXPLAIN SYNTAX
SELECT event_type, count() FROM events WHERE event_date = today() GROUP BY event_type;
```

Shows how ClickHouse rewrites the query after optimization (alias resolution, predicate pushdown).

### 25. EXPLAIN ESTIMATE -- Estimated Rows and Marks

```sql
EXPLAIN ESTIMATE
SELECT * FROM events WHERE event_type = 'click' AND event_date = today();
```

Shows the estimated number of rows and marks to be read, including partition pruning results.

### 26. EXPLAIN INDEXES -- Index Usage

```sql
EXPLAIN indexes = 1
SELECT * FROM events WHERE trace_id = 'abc123';
```

Shows which indexes are used and how many granules/parts are filtered.

## Parts and Partitions

### 27. Parts Per Table (Active Parts Count)

```sql
SELECT
    database,
    table,
    count() AS active_parts,
    sum(rows) AS total_rows,
    formatReadableSize(sum(bytes_on_disk)) AS disk_size
FROM system.parts
WHERE active
GROUP BY database, table
ORDER BY active_parts DESC;
```

### 28. Detailed Part Information for a Table

```sql
SELECT
    name,
    partition,
    rows,
    formatReadableSize(bytes_on_disk) AS disk_size,
    formatReadableSize(data_compressed_bytes) AS compressed,
    formatReadableSize(data_uncompressed_bytes) AS uncompressed,
    modification_time,
    level,
    data_version,
    primary_key_bytes_in_memory,
    marks_count
FROM system.parts
WHERE database = 'default' AND table = 'events' AND active
ORDER BY modification_time DESC
LIMIT 50;
```

### 29. Partition Summary

```sql
SELECT
    database,
    table,
    partition,
    count() AS parts,
    sum(rows) AS total_rows,
    formatReadableSize(sum(bytes_on_disk)) AS disk_size,
    min(modification_time) AS oldest_part,
    max(modification_time) AS newest_part
FROM system.parts
WHERE active AND database = 'default' AND table = 'events'
GROUP BY database, table, partition
ORDER BY partition;
```

### 30. Parts That Are Too Small (Candidates for Merge)

```sql
SELECT
    database, table, name, partition,
    rows,
    formatReadableSize(bytes_on_disk) AS size,
    level
FROM system.parts
WHERE active AND rows < 10000 AND database = 'default'
ORDER BY database, table, rows ASC
LIMIT 50;
```

### 31. Parts by Level (Merge History)

```sql
SELECT
    database, table, level,
    count() AS parts_at_level,
    formatReadableSize(sum(bytes_on_disk)) AS total_size,
    sum(rows) AS total_rows
FROM system.parts
WHERE active
GROUP BY database, table, level
ORDER BY database, table, level;
```

### 32. Detached Parts

```sql
SELECT
    database, table, partition_id, name, reason
FROM system.detached_parts
ORDER BY database, table;
```

### 33. Part Log (Part Create/Remove/Merge History)

```sql
SELECT
    event_type,
    event_time,
    database,
    table,
    part_name,
    rows,
    formatReadableSize(size_in_bytes) AS size,
    duration_ms,
    merge_reason
FROM system.part_log
WHERE event_date = today()
ORDER BY event_time DESC
LIMIT 50;
```

### 34. Column-Level Compression Analysis

```sql
SELECT
    database,
    table,
    column,
    type,
    formatReadableSize(sum(column_data_compressed_bytes)) AS compressed,
    formatReadableSize(sum(column_data_uncompressed_bytes)) AS uncompressed,
    round(sum(column_data_uncompressed_bytes) / sum(column_data_compressed_bytes), 2) AS ratio
FROM system.parts_columns
WHERE active AND database = 'default' AND table = 'events'
GROUP BY database, table, column, type
ORDER BY sum(column_data_uncompressed_bytes) DESC;
```

## Merges and Mutations

### 35. Currently Running Merges

```sql
SELECT
    database,
    table,
    elapsed,
    progress,
    num_parts,
    result_part_name,
    formatReadableSize(total_size_bytes_compressed) AS total_size,
    formatReadableSize(bytes_read_uncompressed) AS bytes_read,
    formatReadableSize(bytes_written_uncompressed) AS bytes_written,
    rows_read,
    rows_written,
    columns_written,
    memory_usage
FROM system.merges
ORDER BY elapsed DESC;
```

### 36. Merge History from Part Log

```sql
SELECT
    event_time,
    database,
    table,
    part_name,
    rows,
    formatReadableSize(size_in_bytes) AS size,
    duration_ms,
    merge_reason,
    merge_algorithm
FROM system.part_log
WHERE event_type = 'MergeParts'
  AND event_date = today()
ORDER BY duration_ms DESC
LIMIT 20;
```

### 37. Active Mutations

```sql
SELECT
    database,
    table,
    mutation_id,
    command,
    create_time,
    parts_to_do,
    is_done,
    latest_failed_part,
    latest_fail_reason,
    latest_fail_time
FROM system.mutations
WHERE NOT is_done
ORDER BY create_time;
```

### 38. Completed Mutations History

```sql
SELECT
    database,
    table,
    mutation_id,
    command,
    create_time,
    parts_to_do,
    is_done
FROM system.mutations
WHERE is_done
ORDER BY create_time DESC
LIMIT 20;
```

### 39. Stuck Mutations (Failed Parts)

```sql
SELECT
    database,
    table,
    mutation_id,
    command,
    create_time,
    latest_failed_part,
    latest_fail_reason,
    latest_fail_time
FROM system.mutations
WHERE NOT is_done
  AND latest_fail_time > '1970-01-01'
ORDER BY latest_fail_time DESC;
```

### 40. Kill a Stuck Mutation

```sql
-- Identify the mutation first
SELECT mutation_id, command FROM system.mutations WHERE database = 'default' AND table = 'events' AND NOT is_done;

-- Kill it
KILL MUTATION WHERE database = 'default' AND table = 'events' AND mutation_id = 'mutation_0000000042.txt';
```

## Replication Monitoring

### 41. Replica Status Overview

```sql
SELECT
    database,
    table,
    replica_name,
    replica_path,
    is_leader,
    is_readonly,
    is_session_expired,
    absolute_delay,
    queue_size,
    inserts_in_queue,
    merges_in_queue,
    parts_to_check,
    total_replicas,
    active_replicas,
    last_queue_update,
    zookeeper_exception
FROM system.replicas
ORDER BY absolute_delay DESC;
```

### 42. Replicas with Significant Lag

```sql
SELECT
    database,
    table,
    replica_name,
    absolute_delay,
    queue_size,
    inserts_in_queue,
    merges_in_queue
FROM system.replicas
WHERE absolute_delay > 60 OR queue_size > 100
ORDER BY absolute_delay DESC;
```

### 43. Replication Queue (Pending Tasks)

```sql
SELECT
    database,
    table,
    replica_name,
    type,
    source_replica,
    new_part_name,
    create_time,
    is_currently_executing,
    num_tries,
    last_exception,
    last_attempt_time
FROM system.replication_queue
WHERE NOT is_done
ORDER BY create_time
LIMIT 50;
```

### 44. Replication Queue Errors

```sql
SELECT
    database,
    table,
    type,
    new_part_name,
    num_tries,
    last_exception,
    last_attempt_time,
    postpone_reason
FROM system.replication_queue
WHERE num_tries > 3 AND last_exception != ''
ORDER BY num_tries DESC;
```

### 45. Replica Session Status with Keeper

```sql
SELECT
    database,
    table,
    replica_name,
    is_session_expired,
    zookeeper_exception,
    zookeeper_path
FROM system.replicas
WHERE is_session_expired = 1 OR zookeeper_exception != '';
```

### 46. Replicated Fetches in Progress

```sql
SELECT
    database,
    table,
    elapsed,
    progress,
    result_part_name,
    source_replica_hostname,
    source_replica_port,
    formatReadableSize(total_size_bytes_compressed) AS total_size,
    formatReadableSize(bytes_read_compressed) AS bytes_read
FROM system.replicated_fetches
ORDER BY elapsed DESC;
```

## Cluster and Distributed Query Monitoring

### 47. Cluster Topology

```sql
SELECT
    cluster,
    shard_num,
    shard_weight,
    replica_num,
    host_name,
    host_address,
    port,
    is_local,
    errors_count,
    slowdowns_count,
    estimated_recovery_time
FROM system.clusters
ORDER BY cluster, shard_num, replica_num;
```

### 48. Distributed DDL Queue

```sql
SELECT
    entry,
    host_name,
    host_address,
    status,
    exception_code,
    exception_text,
    query,
    initiator
FROM system.distributed_ddl_queue
ORDER BY entry DESC
LIMIT 20;
```

### 49. Failed Distributed DDL Operations

```sql
SELECT
    entry,
    host_name,
    status,
    exception_code,
    exception_text,
    query
FROM system.distributed_ddl_queue
WHERE status = 'Exception' OR exception_code != 0
ORDER BY entry DESC;
```

### 50. Distributed Table Send Status

```sql
SELECT
    database,
    table,
    formatReadableSize(bytes_to_send) AS bytes_pending,
    rows_to_send,
    files_to_send
FROM system.distribution_queue
WHERE bytes_to_send > 0
ORDER BY bytes_to_send DESC;
```

## ZooKeeper / ClickHouse Keeper Monitoring

### 51. Keeper Connection Status

```sql
SELECT * FROM system.zookeeper_connection;
```

### 52. Browse Keeper Paths

```sql
SELECT name, path, value, numChildren
FROM system.zookeeper
WHERE path = '/clickhouse';
```

### 53. Replicated Table Paths in Keeper

```sql
SELECT name, path, numChildren
FROM system.zookeeper
WHERE path = '/clickhouse/tables'
ORDER BY name;
```

### 54. Keeper Session Metrics

```sql
SELECT metric, value
FROM system.asynchronous_metrics
WHERE metric LIKE '%Keeper%' OR metric LIKE '%ZooKeeper%';
```

### 55. Check Keeper Leader

```sql
-- Via four-letter command (if enabled)
-- echo mntr | nc keeper-host 9181
SELECT * FROM system.zookeeper WHERE path = '/clickhouse/task_queue';
```

## Disk and Storage Monitoring

### 56. Disk Usage

```sql
SELECT
    name,
    path,
    formatReadableSize(free_space) AS free,
    formatReadableSize(total_space) AS total,
    round(100 * (1 - free_space / total_space), 1) AS used_pct
FROM system.disks;
```

### 57. Storage Policies

```sql
SELECT
    policy_name,
    volume_name,
    volume_priority,
    disks,
    formatReadableSize(max_data_part_size) AS max_part_size,
    move_factor
FROM system.storage_policies;
```

### 58. Parts Distribution Across Disks

```sql
SELECT
    disk_name,
    database,
    table,
    count() AS parts,
    formatReadableSize(sum(bytes_on_disk)) AS total_size
FROM system.parts
WHERE active
GROUP BY disk_name, database, table
ORDER BY sum(bytes_on_disk) DESC;
```

### 59. Disk I/O Metrics

```sql
SELECT
    metric,
    value
FROM system.events
WHERE event LIKE '%Disk%' OR event LIKE '%Read%' OR event LIKE '%Write%'
ORDER BY value DESC
LIMIT 30;
```

## Table Structure and Schema

### 60. List All Tables with Engines

```sql
SELECT
    database,
    name AS table,
    engine,
    total_rows,
    formatReadableSize(total_bytes) AS total_bytes,
    partition_key,
    sorting_key,
    primary_key
FROM system.tables
WHERE database NOT IN ('system', 'INFORMATION_SCHEMA', 'information_schema')
ORDER BY total_bytes DESC NULLS LAST;
```

### 61. Table DDL (SHOW CREATE TABLE)

```sql
SHOW CREATE TABLE default.events;
```

### 62. Column Details for a Table

```sql
SELECT
    name,
    type,
    default_kind,
    default_expression,
    compression_codec,
    is_in_partition_key,
    is_in_sorting_key,
    is_in_primary_key
FROM system.columns
WHERE database = 'default' AND table = 'events'
ORDER BY position;
```

### 63. Table Engine Parameters

```sql
SELECT
    database,
    name,
    engine,
    engine_full,
    partition_key,
    sorting_key,
    primary_key,
    sampling_key
FROM system.tables
WHERE database = 'default' AND name = 'events';
```

### 64. Materialized Views and Their Targets

```sql
SELECT
    database,
    name,
    engine,
    as_select
FROM system.tables
WHERE engine = 'MaterializedView'
ORDER BY database, name;
```

### 65. Dictionaries Status

```sql
SELECT
    database,
    name,
    status,
    origin,
    type,
    key.names AS key_columns,
    key.types AS key_types,
    attribute.names AS attr_names,
    attribute.types AS attr_types,
    bytes_allocated,
    element_count,
    load_factor,
    loading_start_time,
    last_successful_update_time,
    loading_duration,
    last_exception
FROM system.dictionaries;
```

### 66. Skip Indexes Defined on Tables

```sql
SELECT
    database,
    table,
    name AS index_name,
    type AS index_type,
    expr AS index_expression,
    granularity
FROM system.data_skipping_indices
WHERE database = 'default'
ORDER BY table, name;
```

### 67. Projections Defined on Tables

```sql
SELECT
    database,
    table,
    name AS projection_name,
    type
FROM system.projections
WHERE database = 'default'
ORDER BY table, name;
```

## Memory and Cache Diagnostics

### 68. Mark Cache Hit Rate

```sql
SELECT
    metric,
    value
FROM system.events
WHERE event IN ('MarkCacheHits', 'MarkCacheMisses');
```

```sql
-- Calculate hit rate
SELECT
    sumIf(value, event = 'MarkCacheHits') AS hits,
    sumIf(value, event = 'MarkCacheMisses') AS misses,
    round(100 * hits / (hits + misses), 2) AS hit_rate_pct
FROM system.events
WHERE event IN ('MarkCacheHits', 'MarkCacheMisses');
```

### 69. Uncompressed Cache Hit Rate

```sql
SELECT
    sumIf(value, event = 'UncompressedCacheHits') AS hits,
    sumIf(value, event = 'UncompressedCacheMisses') AS misses,
    if(hits + misses > 0, round(100 * hits / (hits + misses), 2), 0) AS hit_rate_pct
FROM system.events
WHERE event IN ('UncompressedCacheHits', 'UncompressedCacheMisses');
```

### 70. Memory Allocator Stats

```sql
SELECT
    metric,
    formatReadableSize(value) AS size
FROM system.asynchronous_metrics
WHERE metric LIKE '%Memory%' OR metric LIKE '%Malloc%'
ORDER BY value DESC;
```

### 71. Per-User Memory Usage

```sql
SELECT
    user,
    count() AS active_queries,
    formatReadableSize(sum(memory_usage)) AS total_memory
FROM system.processes
GROUP BY user
ORDER BY sum(memory_usage) DESC;
```

### 72. Memory-Intensive Queries in History

```sql
SELECT
    user,
    query_id,
    formatReadableSize(memory_usage) AS peak_memory,
    query_duration_ms,
    query
FROM system.query_log
WHERE type = 'QueryFinish'
  AND event_date = today()
ORDER BY memory_usage DESC
LIMIT 20;
```

## Network and Connections

### 73. Active Connections by User

```sql
SELECT
    user,
    client_hostname,
    count() AS connections
FROM system.processes
GROUP BY user, client_hostname
ORDER BY connections DESC;
```

### 74. Network Transfer Metrics

```sql
SELECT
    event,
    value
FROM system.events
WHERE event LIKE '%Network%' OR event LIKE '%Send%' OR event LIKE '%Receive%'
ORDER BY value DESC
LIMIT 20;
```

### 75. Interserver Communication Metrics

```sql
SELECT
    metric,
    value
FROM system.metrics
WHERE metric LIKE '%Interserver%' OR metric LIKE '%Replicat%'
ORDER BY metric;
```

## Background Tasks and Pools

### 76. Background Pool Usage

```sql
SELECT
    metric,
    value
FROM system.metrics
WHERE metric LIKE '%Background%' OR metric LIKE '%Pool%'
ORDER BY metric;
```

### 77. Background Merge/Mutation Slots

```sql
SELECT
    metric, value
FROM system.metrics
WHERE metric IN (
    'BackgroundMergesAndMutationsPoolTask',
    'BackgroundMovePoolTask',
    'BackgroundSchedulePoolTask',
    'BackgroundBufferFlushSchedulePoolTask',
    'BackgroundDistributedSchedulePoolTask',
    'BackgroundMessageBrokerSchedulePoolTask'
);
```

### 78. Background Task Errors

```sql
SELECT
    event,
    value
FROM system.events
WHERE event LIKE '%BackgroundPool%Error%' OR event LIKE '%FailedMerge%'
ORDER BY value DESC;
```

## Error and Log Diagnostics

### 79. Recent Text Log Errors

```sql
SELECT
    event_time,
    level,
    logger_name,
    message
FROM system.text_log
WHERE level IN ('Error', 'Fatal')
  AND event_date = today()
ORDER BY event_time DESC
LIMIT 50;
```

### 80. Warning Messages

```sql
SELECT
    event_time,
    logger_name,
    message
FROM system.text_log
WHERE level = 'Warning'
  AND event_date = today()
ORDER BY event_time DESC
LIMIT 30;
```

### 81. Error Stack Traces

```sql
SELECT
    event_time,
    logger_name,
    message,
    source_file,
    source_line
FROM system.text_log
WHERE level IN ('Error', 'Fatal')
  AND event_date = today()
  AND message LIKE '%Stack trace%'
ORDER BY event_time DESC
LIMIT 10;
```

### 82. Most Frequent Error Messages

```sql
SELECT
    count() AS occurrences,
    substring(message, 1, 200) AS message_prefix
FROM system.text_log
WHERE level = 'Error'
  AND event_date >= today() - 1
GROUP BY message_prefix
ORDER BY occurrences DESC
LIMIT 20;
```

### 83. Server Exception History

```sql
SELECT
    exception_code,
    count() AS occurrences,
    any(exception) AS sample_exception,
    min(event_time) AS first_seen,
    max(event_time) AS last_seen
FROM system.query_log
WHERE exception_code != 0
  AND event_date >= today() - 1
GROUP BY exception_code
ORDER BY occurrences DESC;
```

## Access Control and Users

### 84. Current User Grants

```sql
SHOW GRANTS FOR CURRENT_USER;
```

### 85. All Users and Their Settings

```sql
SELECT
    name,
    storage,
    auth_type,
    host_ip,
    host_names,
    default_database,
    default_roles_all,
    grantees_any
FROM system.users
ORDER BY name;
```

### 86. Active Quotas

```sql
SELECT
    quota_name,
    quota_key,
    duration,
    queries,
    max_queries,
    result_rows,
    max_result_rows,
    errors,
    max_errors
FROM system.quota_usage
WHERE max_queries > 0 OR max_result_rows > 0;
```

### 87. Row Policies

```sql
SELECT
    name,
    short_name,
    database,
    table,
    select_filter,
    apply_to_all,
    apply_to_list,
    apply_to_except
FROM system.row_policies;
```

## CLI Diagnostic Commands

### 88. clickhouse-client Connection Test

```bash
clickhouse-client --host localhost --port 9000 --user default --password '' --query "SELECT 1"
```

### 89. Server Status via HTTP

```bash
# Health check (returns "Ok.\n")
curl 'http://localhost:8123/ping'

# Query via HTTP
curl 'http://localhost:8123/?query=SELECT%20version()'

# With authentication
curl 'http://localhost:8123/?user=default&password=pass&query=SELECT%201'
```

### 90. clickhouse-local for File Analysis

```bash
# Query a local Parquet file
clickhouse-local --query "SELECT count(), avg(amount) FROM file('data.parquet', Parquet)"

# Query CSV with schema inference
clickhouse-local --query "SELECT * FROM file('data.csv', CSVWithNames) LIMIT 10"

# Multiple file glob
clickhouse-local --query "SELECT count() FROM file('logs/*.json', JSONEachRow)"
```

### 91. System Table Export for Support

```bash
# Export diagnostics bundle
clickhouse-client --query "SELECT * FROM system.metrics FORMAT TSVWithNames" > metrics.tsv
clickhouse-client --query "SELECT * FROM system.events FORMAT TSVWithNames" > events.tsv
clickhouse-client --query "SELECT * FROM system.asynchronous_metrics FORMAT TSVWithNames" > async_metrics.tsv
clickhouse-client --query "SELECT * FROM system.replicas FORMAT TSVWithNames" > replicas.tsv
clickhouse-client --query "SELECT * FROM system.merges FORMAT TSVWithNames" > merges.tsv
```

### 92. clickhouse-benchmark for Load Testing

```bash
# Run 100 iterations of a query with 4 concurrent connections
clickhouse-benchmark --host localhost --port 9000 \
    --iterations 100 --concurrency 4 \
    --query "SELECT count() FROM events WHERE event_date = today()"
```

### 93. clickhouse-compressor for Analyzing Compression

```bash
# Check compression ratio of a column file
clickhouse-compressor --stat < /var/lib/clickhouse/data/default/events/all_1_1_0/data.bin
```

## Prometheus / Grafana Monitoring Queries

### 94. Prometheus Metrics Endpoint

```bash
# ClickHouse exposes Prometheus metrics on port 9363 (or configured port)
curl http://localhost:9363/metrics
```

Config to enable:
```xml
<prometheus>
    <endpoint>/metrics</endpoint>
    <port>9363</port>
    <metrics>true</metrics>
    <events>true</events>
    <asynchronous_metrics>true</asynchronous_metrics>
</prometheus>
```

### 95. Key Grafana Dashboard Queries

```sql
-- Queries per second (for Grafana time series)
SELECT
    toStartOfInterval(event_time, INTERVAL 10 second) AS t,
    count() / 10 AS qps
FROM system.query_log
WHERE type = 'QueryFinish' AND event_date = today()
GROUP BY t
ORDER BY t;

-- Memory usage over time
SELECT
    toStartOfMinute(event_time) AS t,
    max(value) AS memory_bytes
FROM system.asynchronous_metric_log
WHERE metric = 'MemoryResident' AND event_date = today()
GROUP BY t
ORDER BY t;

-- Part count over time
SELECT
    toStartOfHour(event_time) AS t,
    max(value) AS parts
FROM system.asynchronous_metric_log
WHERE metric LIKE '%PartsActive%' AND event_date = today()
GROUP BY t
ORDER BY t;
```

## Troubleshooting Playbooks

### 96. Playbook: "Too Many Parts" Error

**Symptom:** `DB::Exception: Too many parts (600). Merges are processing significantly slower than inserts`

**Step 1 -- Assess the situation:**
```sql
SELECT database, table, count() AS parts, sum(rows) AS rows
FROM system.parts WHERE active
GROUP BY database, table
ORDER BY parts DESC LIMIT 10;
```

**Step 2 -- Check merge backlog:**
```sql
SELECT * FROM system.merges ORDER BY elapsed DESC;
```

**Step 3 -- Check for stuck mutations blocking merges:**
```sql
SELECT * FROM system.mutations WHERE NOT is_done;
```

**Step 4 -- Immediate relief (force merge):**
```sql
OPTIMIZE TABLE default.events FINAL;
```

**Step 5 -- Root cause: insert frequency:**
```sql
SELECT
    toStartOfMinute(event_time) AS minute,
    count() AS inserts,
    avg(written_rows) AS avg_rows_per_insert
FROM system.query_log
WHERE type = 'QueryFinish' AND query_kind = 'Insert'
  AND event_date = today() AND database = 'default' AND tables = ['default.events']
GROUP BY minute
ORDER BY minute DESC LIMIT 30;
```

**Fix:** Batch inserts to >10K rows. Enable async inserts: `SET async_insert = 1`.

### 97. Playbook: OOM Kills

**Symptom:** ClickHouse process killed by OOM killer or query fails with MEMORY_LIMIT_EXCEEDED.

**Step 1 -- Find the memory-hungry queries:**
```sql
SELECT
    query_id,
    user,
    formatReadableSize(memory_usage) AS peak_memory,
    query_duration_ms,
    query
FROM system.query_log
WHERE type IN ('ExceptionWhileProcessing', 'QueryFinish')
  AND event_date = today()
ORDER BY memory_usage DESC
LIMIT 10;
```

**Step 2 -- Check server-level memory:**
```sql
SELECT
    metric,
    formatReadableSize(value) AS value
FROM system.asynchronous_metrics
WHERE metric IN ('OSMemoryTotal', 'OSMemoryAvailable', 'MemoryResident');
```

**Step 3 -- Set memory limits:**
```sql
-- Per-query
SET max_memory_usage = 10000000000;  -- 10GB
-- Per-user
ALTER USER analyst SETTINGS max_memory_usage = 5000000000;
-- Enable spilling to disk
SET max_bytes_before_external_group_by = 5000000000;
SET max_bytes_before_external_sort = 5000000000;
```

### 98. Playbook: Replication Lag

**Symptom:** Replicas falling behind; `absolute_delay` growing.

**Step 1 -- Check lag:**
```sql
SELECT database, table, replica_name, absolute_delay, queue_size,
       inserts_in_queue, merges_in_queue
FROM system.replicas
ORDER BY absolute_delay DESC;
```

**Step 2 -- Check replication queue for errors:**
```sql
SELECT database, table, type, source_replica, new_part_name,
       num_tries, last_exception, postpone_reason
FROM system.replication_queue
WHERE last_exception != '' OR postpone_reason != ''
ORDER BY num_tries DESC LIMIT 20;
```

**Step 3 -- Check Keeper health:**
```sql
SELECT * FROM system.zookeeper_connection;
```

**Step 4 -- Check network and fetches:**
```sql
SELECT * FROM system.replicated_fetches;
```

**Step 5 -- Increase replication throughput:**
```xml
<!-- Increase background schedule pool for replication -->
<background_schedule_pool_size>32</background_schedule_pool_size>
<background_fetches_pool_size>8</background_fetches_pool_size>
```

### 99. Playbook: Slow GROUP BY Queries

**Step 1 -- Profile the query:**
```sql
EXPLAIN PIPELINE
SELECT user_id, count(), avg(amount) FROM events GROUP BY user_id;
```

**Step 2 -- Check memory consumption:**
```sql
SET max_bytes_before_external_group_by = 5000000000;
-- Re-run the query. If it spills, the hash table was too large.
```

**Step 3 -- Optimization options:**
- Add a projection with pre-aggregated data
- Use `LowCardinality(String)` for the GROUP BY key
- Use approximate functions: `uniqHLL12()` instead of `uniqExact()`
- Use SAMPLE clause for approximate results: `SELECT ... FROM events SAMPLE 0.1`
- Create a materialized view for common aggregation patterns

### 100. Playbook: Schema Migration / ALTER Column

**Scenario:** Need to change column type or add a column on a large table.

**Step 1 -- Check current schema:**
```sql
DESCRIBE TABLE default.events;
SHOW CREATE TABLE default.events;
```

**Step 2 -- Add column (instant, no rewrite):**
```sql
ALTER TABLE events ADD COLUMN new_field String DEFAULT '' AFTER existing_field;
```

**Step 3 -- Modify column type (triggers mutation, rewrites all parts):**
```sql
ALTER TABLE events MODIFY COLUMN status Enum8('active' = 1, 'inactive' = 2, 'deleted' = 3);
```

**Step 4 -- Monitor mutation progress:**
```sql
SELECT mutation_id, command, parts_to_do, is_done
FROM system.mutations
WHERE database = 'default' AND table = 'events' AND NOT is_done;
```

### 101. Playbook: Investigating Full Table Scans

**Step 1 -- Check if primary key is being used:**
```sql
EXPLAIN indexes = 1
SELECT * FROM events WHERE user_id = 42;
```

**Step 2 -- Check selected marks vs total marks:**
```sql
SELECT
    query,
    ProfileEvents['SelectedParts'] AS parts,
    ProfileEvents['SelectedMarks'] AS marks,
    ProfileEvents['SelectedRows'] AS rows,
    read_rows,
    read_bytes
FROM system.query_log
WHERE query_id = 'your-query-id' AND type = 'QueryFinish';
```

If `SelectedMarks` is close to total marks, the primary key is not filtering effectively. Consider:
- Reordering the ORDER BY to match query patterns
- Adding a projection with a different sort order
- Adding skip indexes (bloom_filter for high-cardinality equality, set for low-cardinality)

### 102. Playbook: Data Corruption / Checksum Errors

**Step 1 -- Find corrupted parts:**
```sql
SELECT database, table, name, rows, bytes_on_disk
FROM system.parts
WHERE database = 'default' AND table = 'events'
  AND hash_of_all_files != hash_of_uncompressed_files;  -- simplified; use detached_parts
```

```sql
-- Check for detached parts (often indicates corruption)
SELECT * FROM system.detached_parts WHERE reason = 'broken';
```

**Step 2 -- Force re-fetch from a replica:**
```sql
-- Detach the corrupted part
ALTER TABLE events DETACH PART 'all_1_1_0';
-- The replica will re-fetch it from another replica automatically

-- Or explicitly request a fetch
SYSTEM RESTORE REPLICA default.events;
```

**Step 3 -- Verify checksums:**
```bash
clickhouse-client --query "CHECK TABLE default.events"
```

### 103. Playbook: ClickHouse Keeper / ZooKeeper Connection Issues

**Symptoms:** Tables become read-only, inserts fail with "No active session".

**Step 1 -- Check connection:**
```sql
SELECT * FROM system.zookeeper_connection;
```

**Step 2 -- Check replica session status:**
```sql
SELECT database, table, is_session_expired, zookeeper_exception
FROM system.replicas
WHERE is_session_expired = 1 OR zookeeper_exception != '';
```

**Step 3 -- Restart Keeper sessions:**
```sql
SYSTEM RESTART REPLICA default.events;
-- Or restart all replicas:
SYSTEM RESTART REPLICAS;
```

**Step 4 -- Check Keeper health (four-letter commands):**
```bash
echo mntr | nc keeper-host 9181
echo stat | nc keeper-host 9181
echo ruok | nc keeper-host 9181  # Should return "imok"
```

### 104. Health Check Query (for Load Balancers)

```sql
-- Simple health check
SELECT 1;

-- Comprehensive health check
SELECT
    if(uptime() > 0, 'OK', 'FAIL') AS server_up,
    if((SELECT count() FROM system.replicas WHERE is_session_expired) = 0, 'OK', 'FAIL') AS keeper_ok,
    if((SELECT max(absolute_delay) FROM system.replicas) < 300, 'OK', 'LAG') AS replication_ok,
    if((SELECT value FROM system.asynchronous_metrics WHERE metric = 'MaxPartCountForPartition') < 300, 'OK', 'WARN') AS parts_ok;
```

### 105. System Commands Reference

```sql
-- Reload configuration
SYSTEM RELOAD CONFIG;

-- Reload dictionaries
SYSTEM RELOAD DICTIONARIES;
SYSTEM RELOAD DICTIONARY dict_name;

-- Stop/start merges
SYSTEM STOP MERGES;
SYSTEM STOP MERGES default.events;
SYSTEM START MERGES;

-- Stop/start replication fetches
SYSTEM STOP FETCHES default.events;
SYSTEM START FETCHES default.events;

-- Stop/start distributed sends
SYSTEM STOP DISTRIBUTED SENDS default.events_distributed;
SYSTEM START DISTRIBUTED SENDS default.events_distributed;

-- Flush logs
SYSTEM FLUSH LOGS;

-- Drop caches
SYSTEM DROP MARK CACHE;
SYSTEM DROP UNCOMPRESSED CACHE;
SYSTEM DROP DNS CACHE;
SYSTEM DROP COMPILED EXPRESSION CACHE;

-- Sync replica
SYSTEM SYNC REPLICA default.events;

-- Restart replicas
SYSTEM RESTART REPLICA default.events;
SYSTEM RESTART REPLICAS;
```

### 106. Comprehensive Server Health Report

```sql
SELECT
    'Version' AS check, version() AS value
UNION ALL
SELECT 'Uptime', formatReadableTimeDelta(uptime())
UNION ALL
SELECT 'Total Tables', toString(count()) FROM system.tables WHERE database NOT IN ('system', 'INFORMATION_SCHEMA', 'information_schema')
UNION ALL
SELECT 'Total Parts', toString(count()) FROM system.parts WHERE active
UNION ALL
SELECT 'Max Parts in Partition', toString(value) FROM system.asynchronous_metrics WHERE metric = 'MaxPartCountForPartition'
UNION ALL
SELECT 'Active Queries', toString(count()) FROM system.processes
UNION ALL
SELECT 'Active Merges', toString(count()) FROM system.merges
UNION ALL
SELECT 'Pending Mutations', toString(count()) FROM system.mutations WHERE NOT is_done
UNION ALL
SELECT 'Replica Lag (max seconds)', toString(max(absolute_delay)) FROM system.replicas
UNION ALL
SELECT 'Expired Sessions', toString(count()) FROM system.replicas WHERE is_session_expired
UNION ALL
SELECT 'Disk Used', formatReadableSize(sum(bytes_on_disk)) FROM system.parts WHERE active
UNION ALL
SELECT 'Memory Resident', formatReadableSize(value) FROM system.asynchronous_metrics WHERE metric = 'MemoryResident';
```

### 107. Data Ingestion Rate Monitoring

```sql
SELECT
    toStartOfMinute(event_time) AS minute,
    sum(written_rows) AS rows_inserted,
    formatReadableSize(sum(written_bytes)) AS bytes_inserted,
    count() AS insert_queries
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query_kind = 'Insert'
  AND event_date = today()
GROUP BY minute
ORDER BY minute DESC
LIMIT 30;
```

### 108. Compression Effectiveness by Column Type

```sql
SELECT
    type,
    count() AS column_count,
    formatReadableSize(sum(column_data_compressed_bytes)) AS total_compressed,
    formatReadableSize(sum(column_data_uncompressed_bytes)) AS total_uncompressed,
    round(sum(column_data_uncompressed_bytes) / sum(column_data_compressed_bytes), 2) AS avg_ratio
FROM system.parts_columns
WHERE active AND database = 'default'
GROUP BY type
ORDER BY sum(column_data_uncompressed_bytes) DESC;
```

### 109. TTL Status and Upcoming Expirations

```sql
SELECT
    database,
    table,
    partition,
    name,
    rows,
    formatReadableSize(bytes_on_disk) AS size,
    delete_ttl_info_min,
    delete_ttl_info_max,
    move_ttl_info.expression AS move_expressions,
    move_ttl_info.min AS move_min,
    move_ttl_info.max AS move_max
FROM system.parts
WHERE active
  AND delete_ttl_info_min != '1970-01-01 00:00:00'
ORDER BY delete_ttl_info_min ASC
LIMIT 30;
```

### 110. Comparison: Query Plan vs. Actual Execution

```sql
-- Run the query with query_id
SELECT count(), avg(amount)
FROM events
WHERE event_type = 'purchase' AND event_date >= '2026-01-01'
SETTINGS log_queries = 1, query_id = 'perf-test-001';

-- Compare planned vs actual
SELECT
    query_id,
    read_rows,
    read_bytes,
    result_rows,
    result_bytes,
    memory_usage,
    query_duration_ms,
    ProfileEvents['SelectedParts'] AS planned_parts,
    ProfileEvents['SelectedMarks'] AS planned_marks,
    ProfileEvents['SelectedRows'] AS planned_rows
FROM system.query_log
WHERE query_id = 'perf-test-001' AND type = 'QueryFinish';
```
