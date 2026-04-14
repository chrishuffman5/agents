# TimescaleDB Diagnostics Reference

## Extension and Version Information

### 1. TimescaleDB Version
```sql
SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';
```

### 2. TimescaleDB Detailed Version Info
```sql
SELECT * FROM timescaledb_information.license;
```

### 3. PostgreSQL Version
```sql
SELECT version();
```

### 4. All Installed Extensions
```sql
SELECT extname, extversion FROM pg_extension ORDER BY extname;
```

### 5. TimescaleDB GUC Settings
```sql
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name LIKE 'timescaledb.%'
ORDER BY name;
```

### 6. Verify TimescaleDB Loaded in shared_preload_libraries
```sql
SHOW shared_preload_libraries;
```

## Hypertable Information

### 7. List All Hypertables
```sql
SELECT hypertable_schema, hypertable_name, owner,
       num_dimensions, num_chunks, compression_enabled,
       tablespaces
FROM timescaledb_information.hypertables
ORDER BY hypertable_schema, hypertable_name;
```

### 8. Hypertable Size Summary
```sql
SELECT hypertable_schema, hypertable_name,
       hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass) AS total_size,
       pg_size_pretty(hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)) AS total_pretty
FROM timescaledb_information.hypertables
ORDER BY hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass) DESC;
```

### 9. Detailed Hypertable Size Breakdown
```sql
SELECT *,
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(data_bytes) AS data,
       pg_size_pretty(index_bytes) AS indexes,
       pg_size_pretty(toast_bytes) AS toast
FROM (
    SELECT ht.schema_name AS table_schema,
           ht.table_name,
           hypertable_detailed_size(format('%I.%I', ht.schema_name, ht.table_name)::regclass) AS sizes
    FROM _timescaledb_catalog.hypertable ht
) sub
CROSS JOIN LATERAL (
    SELECT (sizes).total_bytes,
           (sizes).data_bytes,
           (sizes).index_bytes,
           (sizes).toast_bytes
) details
ORDER BY total_bytes DESC;
```

### 10. Hypertable Approximate Row Counts
```sql
SELECT hypertable_schema, hypertable_name,
       hypertable_approximate_row_count(format('%I.%I', hypertable_schema, hypertable_name)::regclass) AS approx_rows
FROM timescaledb_information.hypertables
ORDER BY approx_rows DESC;
```

### 11. Hypertable Dimensions (Time and Space Partitioning)
```sql
SELECT hypertable_schema, hypertable_name,
       dimension_number, column_name, column_type,
       time_interval, integer_interval, num_partitions
FROM timescaledb_information.dimensions
ORDER BY hypertable_schema, hypertable_name, dimension_number;
```

### 12. Hypertable Chunk Interval
```sql
SELECT h.schema_name, h.table_name,
       d.column_name,
       CASE WHEN d.interval_length IS NOT NULL
            THEN make_interval(secs => d.interval_length / 1000000.0)
            ELSE NULL END AS chunk_interval
FROM _timescaledb_catalog.hypertable h
JOIN _timescaledb_catalog.dimension d ON h.id = d.hypertable_id
WHERE d.num_slices IS NULL;  -- time dimensions only
```

### 13. Hypertable Indexes
```sql
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN (
    SELECT hypertable_name::text
    FROM timescaledb_information.hypertables
)
ORDER BY tablename, indexname;
```

## Chunk Management

### 14. List All Chunks for a Hypertable
```sql
SELECT * FROM show_chunks('sensor_data') ORDER BY 1;
```

### 15. List Chunks with Time Ranges
```sql
SELECT chunk_schema, chunk_name, hypertable_schema, hypertable_name,
       range_start, range_end,
       is_compressed
FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data'
ORDER BY range_start DESC;
```

### 16. Chunk Count per Hypertable
```sql
SELECT hypertable_schema, hypertable_name, COUNT(*) AS num_chunks
FROM timescaledb_information.chunks
GROUP BY hypertable_schema, hypertable_name
ORDER BY num_chunks DESC;
```

### 17. Chunk Sizes
```sql
SELECT chunk_schema, chunk_name,
       pg_size_pretty(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass)) AS total_size,
       is_compressed
FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data'
ORDER BY range_start DESC;
```

### 18. Largest Chunks
```sql
SELECT chunk_schema, chunk_name, hypertable_name,
       pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass) AS bytes,
       pg_size_pretty(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass)) AS size
FROM timescaledb_information.chunks
ORDER BY pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass) DESC
LIMIT 20;
```

### 19. Chunks in a Specific Time Range
```sql
SELECT * FROM show_chunks('sensor_data',
    older_than => INTERVAL '7 days');

SELECT * FROM show_chunks('sensor_data',
    newer_than => INTERVAL '30 days',
    older_than => INTERVAL '1 day');
```

### 20. Empty Chunks (No Data)
```sql
SELECT c.chunk_schema, c.chunk_name, c.range_start, c.range_end
FROM timescaledb_information.chunks c
WHERE hypertable_name = 'sensor_data'
  AND NOT EXISTS (
    SELECT 1 FROM pg_stat_user_tables s
    WHERE s.schemaname = c.chunk_schema
      AND s.relname = c.chunk_name
      AND (s.n_live_tup > 0 OR s.n_dead_tup > 0)
  );
```

### 21. Drop Old Chunks (Preview)
```sql
-- Preview which chunks would be dropped
SELECT * FROM show_chunks('sensor_data', older_than => INTERVAL '90 days');

-- Actually drop them
SELECT drop_chunks('sensor_data', older_than => INTERVAL '90 days');
```

### 22. Chunk Statistics from pg_stat_user_tables
```sql
SELECT schemaname, relname,
       n_live_tup, n_dead_tup,
       last_vacuum, last_autovacuum,
       last_analyze, last_autoanalyze,
       seq_scan, seq_tup_read,
       idx_scan, idx_tup_fetch
FROM pg_stat_user_tables
WHERE schemaname = '_timescaledb_internal'
ORDER BY n_live_tup DESC
LIMIT 30;
```

### 23. Reorder a Chunk by Index
```sql
-- Reorder a chunk's physical layout by a specific index (improves sequential read performance)
SELECT reorder_chunk('_timescaledb_internal._hyper_1_42_chunk',
    index => '_timescaledb_internal._hyper_1_42_chunk_sensor_data_time_idx');
```

### 24. Move a Chunk to a Different Tablespace
```sql
SELECT move_chunk(
    chunk => '_timescaledb_internal._hyper_1_42_chunk',
    destination_tablespace => 'slow_storage',
    index_destination_tablespace => 'slow_storage',
    reorder_index => '_timescaledb_internal._hyper_1_42_chunk_sensor_data_time_idx'
);
```

## Compression Diagnostics

### 25. Compression Settings per Hypertable
```sql
SELECT * FROM timescaledb_information.compression_settings
ORDER BY hypertable_schema, hypertable_name, orderby_column_index, segmentby_column_index;
```

### 26. Compression Status per Chunk
```sql
SELECT chunk_schema, chunk_name,
       compression_status,
       uncompressed_total_bytes,
       compressed_total_bytes,
       pg_size_pretty(uncompressed_total_bytes) AS uncompressed_size,
       pg_size_pretty(compressed_total_bytes) AS compressed_size,
       CASE WHEN uncompressed_total_bytes > 0
            THEN round((1 - compressed_total_bytes::numeric / uncompressed_total_bytes) * 100, 1)
            ELSE 0 END AS compression_ratio_pct
FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data'
  AND compression_status IS NOT NULL
ORDER BY range_start DESC;
```

### 27. Hypertable Compression Statistics
```sql
SELECT hypertable_schema, hypertable_name,
       number_compressed_chunks,
       pg_size_pretty(before_compression_total_bytes) AS before_compression,
       pg_size_pretty(after_compression_total_bytes) AS after_compression,
       CASE WHEN before_compression_total_bytes > 0
            THEN round((1 - after_compression_total_bytes::numeric / before_compression_total_bytes) * 100, 1)
            ELSE 0 END AS compression_ratio_pct
FROM hypertable_compression_stats('sensor_data');
```

### 28. Overall Compression Ratio Across All Hypertables
```sql
SELECT h.hypertable_schema, h.hypertable_name,
       cs.number_compressed_chunks,
       pg_size_pretty(cs.before_compression_total_bytes) AS before,
       pg_size_pretty(cs.after_compression_total_bytes) AS after,
       ROUND((1 - cs.after_compression_total_bytes::numeric /
              NULLIF(cs.before_compression_total_bytes, 0)) * 100, 1) AS ratio_pct
FROM timescaledb_information.hypertables h
CROSS JOIN LATERAL hypertable_compression_stats(
    format('%I.%I', h.hypertable_schema, h.hypertable_name)::regclass
) cs
WHERE h.compression_enabled = true
ORDER BY cs.before_compression_total_bytes DESC;
```

### 29. Chunks Eligible for Compression (Not Yet Compressed)
```sql
SELECT chunk_schema, chunk_name, range_start, range_end,
       pg_size_pretty(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass)) AS size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data'
  AND NOT is_compressed
  AND range_end < NOW() - INTERVAL '7 days'  -- adjust to your compression policy threshold
ORDER BY range_start;
```

### 30. Chunks with Uncompressed Staging Data (Need Recompression)
```sql
SELECT chunk_schema, chunk_name, hypertable_name,
       compression_status
FROM timescaledb_information.chunks
WHERE compression_status = 'Partially compressed'
ORDER BY hypertable_name, range_start;
```

### 31. Manually Compress All Eligible Chunks
```sql
-- Compress all uncompressed chunks older than 7 days
SELECT compress_chunk(i) FROM show_chunks('sensor_data', older_than => INTERVAL '7 days') i
WHERE NOT EXISTS (
    SELECT 1 FROM timescaledb_information.chunks c
    WHERE c.chunk_name = split_part(i::text, '.', 2)
      AND c.is_compressed = true
);
```

### 32. Compression Job Last Run and Status
```sql
SELECT j.job_id, j.hypertable_name, j.proc_name,
       js.last_run_status, js.last_run_started_at, js.last_run_duration,
       js.next_start, js.total_runs, js.total_successes, js.total_failures
FROM timescaledb_information.jobs j
JOIN timescaledb_information.job_stats js ON j.job_id = js.job_id
WHERE j.proc_name LIKE '%compress%'
ORDER BY j.hypertable_name;
```

## Continuous Aggregate Diagnostics

### 33. List All Continuous Aggregates
```sql
SELECT * FROM timescaledb_information.continuous_aggregates
ORDER BY hypertable_schema, hypertable_name;
```

### 34. Continuous Aggregate Details
```sql
SELECT view_schema, view_name, view_owner,
       materialization_hypertable_schema, materialization_hypertable_name,
       view_definition,
       finalized
FROM timescaledb_information.continuous_aggregates
ORDER BY view_name;
```

### 35. Continuous Aggregate Materialization Size
```sql
SELECT ca.view_name,
       ca.materialization_hypertable_schema,
       ca.materialization_hypertable_name,
       pg_size_pretty(hypertable_size(
           format('%I.%I', ca.materialization_hypertable_schema, ca.materialization_hypertable_name)::regclass
       )) AS materialization_size
FROM timescaledb_information.continuous_aggregates ca;
```

### 36. Continuous Aggregate Refresh Policy Status
```sql
SELECT j.job_id, j.hypertable_name, j.proc_name,
       j.config->>'start_offset' AS start_offset,
       j.config->>'end_offset' AS end_offset,
       j.schedule_interval,
       js.last_run_status, js.last_run_started_at, js.last_run_duration,
       js.next_start
FROM timescaledb_information.jobs j
JOIN timescaledb_information.job_stats js ON j.job_id = js.job_id
WHERE j.proc_name = 'policy_refresh_continuous_aggregate'
ORDER BY j.hypertable_name;
```

### 37. Continuous Aggregate Refresh Lag
```sql
-- How far behind is each continuous aggregate?
SELECT ca.view_name,
       js.last_run_started_at,
       js.last_successful_finish,
       NOW() - js.last_successful_finish AS time_since_last_refresh,
       js.last_run_status
FROM timescaledb_information.continuous_aggregates ca
JOIN timescaledb_information.jobs j
    ON j.hypertable_name = ca.materialization_hypertable_name
JOIN timescaledb_information.job_stats js ON j.job_id = js.job_id
WHERE j.proc_name = 'policy_refresh_continuous_aggregate';
```

### 38. Continuous Aggregate Invalidation Log Size
```sql
SELECT materialization_id, COUNT(*) AS pending_invalidations,
       MIN(lowest_modified_value) AS earliest_invalidation,
       MAX(greatest_modified_value) AS latest_invalidation
FROM _timescaledb_catalog.continuous_aggs_materialization_invalidation_log
GROUP BY materialization_id;
```

### 39. Check if Real-Time Aggregation is Enabled
```sql
SELECT view_name,
       NOT (materialized_only) AS real_time_enabled
FROM timescaledb_information.continuous_aggregates;
```

## Job Scheduler Diagnostics

### 40. All Registered Jobs
```sql
SELECT job_id, application_name, schedule_interval,
       max_runtime, max_retries, retry_period,
       proc_schema, proc_name, owner,
       scheduled, hypertable_schema, hypertable_name,
       config
FROM timescaledb_information.jobs
ORDER BY job_id;
```

### 41. Job Statistics (Success/Failure)
```sql
SELECT js.job_id, j.proc_name, j.hypertable_name,
       js.last_run_status, js.last_run_started_at,
       js.last_run_duration, js.next_start,
       js.total_runs, js.total_successes, js.total_failures,
       js.consecutive_failures
FROM timescaledb_information.job_stats js
JOIN timescaledb_information.jobs j ON js.job_id = j.job_id
ORDER BY js.job_id;
```

### 42. Failed Jobs
```sql
SELECT js.job_id, j.proc_name, j.hypertable_name,
       js.last_run_status, js.total_failures, js.consecutive_failures,
       js.last_run_started_at, js.last_run_duration
FROM timescaledb_information.job_stats js
JOIN timescaledb_information.jobs j ON js.job_id = j.job_id
WHERE js.last_run_status = 'Failed'
   OR js.consecutive_failures > 0
ORDER BY js.consecutive_failures DESC;
```

### 43. Job Error Details
```sql
SELECT job_id, proc_schema, proc_name,
       start_time, finish_time,
       sqlerrcode, err_message
FROM timescaledb_information.job_errors
ORDER BY start_time DESC
LIMIT 50;
```

### 44. Job History (Recent Executions)
```sql
SELECT job_id, proc_schema, proc_name,
       started_at, finished_at,
       (finished_at - started_at) AS duration,
       succeeded, config
FROM timescaledb_information.job_history
ORDER BY finished_at DESC
LIMIT 50;
```

### 45. Long-Running Jobs
```sql
SELECT js.job_id, j.proc_name, j.hypertable_name, j.max_runtime,
       js.last_run_duration,
       CASE WHEN js.last_run_duration > j.max_runtime THEN 'EXCEEDED' ELSE 'OK' END AS runtime_status
FROM timescaledb_information.job_stats js
JOIN timescaledb_information.jobs j ON js.job_id = j.job_id
WHERE js.last_run_duration IS NOT NULL
ORDER BY js.last_run_duration DESC;
```

### 46. Disabled Jobs
```sql
SELECT job_id, proc_name, hypertable_name, schedule_interval, config
FROM timescaledb_information.jobs
WHERE scheduled = false;
```

### 47. Currently Running Background Workers
```sql
SELECT pid, application_name, state, query, backend_start,
       NOW() - query_start AS query_duration
FROM pg_stat_activity
WHERE application_name LIKE 'TimescaleDB%'
   OR application_name LIKE '%timescaledb%'
ORDER BY query_start;
```

## Policies Overview

### 48. All Compression Policies
```sql
SELECT job_id, hypertable_schema, hypertable_name,
       config->>'compress_after' AS compress_after,
       schedule_interval
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_compression'
ORDER BY hypertable_name;
```

### 49. All Retention Policies
```sql
SELECT job_id, hypertable_schema, hypertable_name,
       config->>'drop_after' AS drop_after,
       schedule_interval
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_retention'
ORDER BY hypertable_name;
```

### 50. All Continuous Aggregate Refresh Policies
```sql
SELECT job_id, hypertable_schema, hypertable_name,
       config->>'start_offset' AS start_offset,
       config->>'end_offset' AS end_offset,
       schedule_interval
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_refresh_continuous_aggregate'
ORDER BY hypertable_name;
```

### 51. All Reorder Policies
```sql
SELECT job_id, hypertable_schema, hypertable_name, config, schedule_interval
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_reorder'
ORDER BY hypertable_name;
```

### 52. All Tiering Policies (Tiger Cloud)
```sql
SELECT job_id, hypertable_schema, hypertable_name, config, schedule_interval
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_tiering'
ORDER BY hypertable_name;
```

### 53. Policy Configuration Summary per Hypertable
```sql
SELECT h.hypertable_name,
       c.config->>'compress_after' AS compress_after,
       r.config->>'drop_after' AS retention_after,
       ca.config->>'start_offset' AS cagg_start_offset,
       ca.config->>'end_offset' AS cagg_end_offset
FROM timescaledb_information.hypertables h
LEFT JOIN timescaledb_information.jobs c
    ON c.hypertable_name = h.hypertable_name AND c.proc_name = 'policy_compression'
LEFT JOIN timescaledb_information.jobs r
    ON r.hypertable_name = h.hypertable_name AND r.proc_name = 'policy_retention'
LEFT JOIN timescaledb_information.jobs ca
    ON ca.hypertable_name = h.hypertable_name AND ca.proc_name = 'policy_refresh_continuous_aggregate'
ORDER BY h.hypertable_name;
```

## Performance Diagnostics

### 54. EXPLAIN ANALYZE with Chunk Exclusion
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT time_bucket('1 hour', time) AS bucket, AVG(temperature)
FROM sensor_data
WHERE time > NOW() - INTERVAL '1 day'
GROUP BY bucket
ORDER BY bucket;
-- Look for "Chunks excluded: N" in the output
```

### 55. Check Chunk Exclusion is Working
```sql
-- Should see fewer chunks scanned than total chunks
EXPLAIN (ANALYZE, VERBOSE)
SELECT * FROM sensor_data
WHERE time > NOW() - INTERVAL '1 hour';
```

### 56. Query Plan for Compressed Data
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM sensor_data
WHERE time > NOW() - INTERVAL '30 days'
  AND sensor_id = 42;
-- Look for: Custom Scan (DecompressChunk) or ColumnarIndexScan
```

### 57. Slow Queries from pg_stat_statements
```sql
SELECT queryid, query,
       calls, mean_exec_time, total_exec_time,
       rows, shared_blks_hit, shared_blks_read
FROM pg_stat_statements
WHERE query LIKE '%sensor_data%'
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### 58. Top Queries by Total Time
```sql
SELECT queryid, LEFT(query, 100) AS query_preview,
       calls, total_exec_time::numeric(20,2) AS total_ms,
       mean_exec_time::numeric(20,2) AS mean_ms,
       rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

### 59. Sequential Scans on Hypertable Chunks (Index Missing?)
```sql
SELECT schemaname, relname, seq_scan, seq_tup_read,
       idx_scan, idx_tup_fetch,
       CASE WHEN seq_scan > 0 THEN seq_tup_read / seq_scan ELSE 0 END AS avg_seq_rows
FROM pg_stat_user_tables
WHERE schemaname = '_timescaledb_internal'
  AND seq_scan > 100
ORDER BY seq_tup_read DESC
LIMIT 20;
```

### 60. Index Usage on Chunks
```sql
SELECT schemaname, relname, indexrelname,
       idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = '_timescaledb_internal'
ORDER BY idx_scan DESC
LIMIT 30;
```

### 61. Unused Indexes on Chunks
```sql
SELECT schemaname, relname, indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = '_timescaledb_internal'
  AND idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;
```

### 62. Cache Hit Ratio (Buffer Cache)
```sql
SELECT
    sum(blks_hit) AS cache_hits,
    sum(blks_read) AS disk_reads,
    ROUND(sum(blks_hit)::numeric / NULLIF(sum(blks_hit) + sum(blks_read), 0) * 100, 2) AS hit_ratio_pct
FROM pg_stat_database
WHERE datname = current_database();
```

### 63. Cache Hit Ratio per Hypertable Chunk
```sql
SELECT schemaname, relname,
       heap_blks_hit, heap_blks_read,
       ROUND(heap_blks_hit::numeric / NULLIF(heap_blks_hit + heap_blks_read, 0) * 100, 2) AS hit_ratio_pct
FROM pg_statio_user_tables
WHERE schemaname = '_timescaledb_internal'
ORDER BY heap_blks_read DESC
LIMIT 20;
```

### 64. Table Bloat on Uncompressed Chunks
```sql
SELECT schemaname, relname,
       n_live_tup, n_dead_tup,
       ROUND(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) AS dead_pct,
       last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname = '_timescaledb_internal'
  AND n_dead_tup > 10000
ORDER BY n_dead_tup DESC
LIMIT 20;
```

## Connection and Activity Monitoring

### 65. Active Connections
```sql
SELECT datname, usename, application_name, client_addr,
       state, query, backend_start,
       NOW() - query_start AS query_duration
FROM pg_stat_activity
WHERE datname = current_database()
ORDER BY query_start;
```

### 66. TimescaleDB Background Workers
```sql
SELECT pid, application_name, state, query,
       backend_start, NOW() - query_start AS duration
FROM pg_stat_activity
WHERE application_name LIKE '%timescaledb%'
   OR application_name LIKE 'TimescaleDB%';
```

### 67. Blocked Queries (Lock Contention)
```sql
SELECT blocked.pid AS blocked_pid,
       blocked.query AS blocked_query,
       blocking.pid AS blocking_pid,
       blocking.query AS blocking_query,
       NOW() - blocked.query_start AS blocked_duration
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid AND NOT bl.granted
JOIN pg_locks gl ON gl.locktype = bl.locktype
    AND gl.database IS NOT DISTINCT FROM bl.database
    AND gl.relation IS NOT DISTINCT FROM bl.relation
    AND gl.page IS NOT DISTINCT FROM bl.page
    AND gl.tuple IS NOT DISTINCT FROM bl.tuple
    AND gl.virtualxid IS NOT DISTINCT FROM bl.virtualxid
    AND gl.transactionid IS NOT DISTINCT FROM bl.transactionid
    AND gl.classid IS NOT DISTINCT FROM bl.classid
    AND gl.objid IS NOT DISTINCT FROM bl.objid
    AND gl.objsubid IS NOT DISTINCT FROM bl.objsubid
    AND gl.pid != bl.pid AND gl.granted
JOIN pg_stat_activity blocking ON blocking.pid = gl.pid;
```

### 68. Locks on Hypertable Chunks
```sql
SELECT l.pid, l.locktype, l.mode, l.granted,
       c.relname, a.query, a.state,
       NOW() - a.query_start AS duration
FROM pg_locks l
JOIN pg_class c ON l.relation = c.oid
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = '_timescaledb_internal')
ORDER BY a.query_start;
```

### 69. Long-Running Queries on Hypertables
```sql
SELECT pid, usename, query, state,
       NOW() - query_start AS duration,
       wait_event_type, wait_event
FROM pg_stat_activity
WHERE state = 'active'
  AND (query LIKE '%sensor_data%' OR query LIKE '%_hyper_%')
  AND NOW() - query_start > INTERVAL '30 seconds'
ORDER BY duration DESC;
```

## Write Performance

### 70. INSERT Rate Estimation (via pg_stat)
```sql
SELECT relname,
       n_tup_ins AS total_inserts,
       n_tup_upd AS total_updates,
       n_tup_del AS total_deletes
FROM pg_stat_user_tables
WHERE relname IN (
    SELECT hypertable_name::text FROM timescaledb_information.hypertables
)
ORDER BY n_tup_ins DESC;
```

### 71. WAL Generation Rate
```sql
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) AS total_wal_generated;

-- WAL generation over time (run twice with interval)
SELECT pg_current_wal_lsn() AS current_lsn;
```

### 72. Checkpoint Activity
```sql
SELECT checkpoints_timed, checkpoints_req,
       checkpoint_write_time, checkpoint_sync_time,
       buffers_checkpoint, buffers_clean, buffers_backend,
       maxwritten_clean, buffers_alloc
FROM pg_stat_bgwriter;
```

### 73. Autovacuum Activity on Chunks
```sql
SELECT schemaname, relname,
       last_autovacuum, last_autoanalyze,
       autovacuum_count, autoanalyze_count,
       n_dead_tup
FROM pg_stat_user_tables
WHERE schemaname = '_timescaledb_internal'
  AND (autovacuum_count > 0 OR autoanalyze_count > 0)
ORDER BY last_autovacuum DESC NULLS LAST
LIMIT 30;
```

## Disk and Storage

### 74. Total Database Size
```sql
SELECT pg_size_pretty(pg_database_size(current_database())) AS database_size;
```

### 75. Size Breakdown: Hypertables vs. Regular Tables
```sql
SELECT 'Hypertables' AS type,
       pg_size_pretty(SUM(hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass))) AS total
FROM timescaledb_information.hypertables
UNION ALL
SELECT 'Regular tables',
       pg_size_pretty(SUM(pg_total_relation_size(c.oid)))
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('_timescaledb_internal', '_timescaledb_catalog',
                         '_timescaledb_config', '_timescaledb_cache',
                         'pg_catalog', 'information_schema');
```

### 76. Compressed vs. Uncompressed Storage per Hypertable
```sql
SELECT hypertable_name,
       COUNT(*) FILTER (WHERE is_compressed) AS compressed_chunks,
       COUNT(*) FILTER (WHERE NOT is_compressed) AS uncompressed_chunks,
       pg_size_pretty(SUM(CASE WHEN is_compressed
           THEN pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass)
           ELSE 0 END)) AS compressed_size,
       pg_size_pretty(SUM(CASE WHEN NOT is_compressed
           THEN pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass)
           ELSE 0 END)) AS uncompressed_size
FROM timescaledb_information.chunks
GROUP BY hypertable_name
ORDER BY hypertable_name;
```

### 77. Tablespace Usage
```sql
SELECT spcname, pg_size_pretty(pg_tablespace_size(spcname)) AS size
FROM pg_tablespace
ORDER BY pg_tablespace_size(spcname) DESC;
```

### 78. Temporary File Usage
```sql
SELECT datname, temp_files, pg_size_pretty(temp_bytes) AS temp_size
FROM pg_stat_database
WHERE datname = current_database();
```

## Replication and HA

### 79. Replication Status (Primary)
```sql
SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_lag_bytes,
       pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS replay_lag
FROM pg_stat_replication;
```

### 80. Replication Slots
```sql
SELECT slot_name, plugin, slot_type, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots;
```

### 81. Recovery Status (Standby)
```sql
SELECT pg_is_in_recovery() AS is_standby,
       pg_last_wal_receive_lsn() AS last_received,
       pg_last_wal_replay_lsn() AS last_replayed,
       pg_last_xact_replay_timestamp() AS last_replay_time,
       NOW() - pg_last_xact_replay_timestamp() AS replay_delay;
```

## Health Check Queries

### 82. Comprehensive TimescaleDB Health Check
```sql
SELECT 'Extension Version' AS check, extversion AS value
FROM pg_extension WHERE extname = 'timescaledb'
UNION ALL
SELECT 'Hypertable Count', COUNT(*)::text
FROM timescaledb_information.hypertables
UNION ALL
SELECT 'Total Chunks', COUNT(*)::text
FROM timescaledb_information.chunks
UNION ALL
SELECT 'Compressed Chunks', COUNT(*)::text
FROM timescaledb_information.chunks WHERE is_compressed
UNION ALL
SELECT 'Continuous Aggregates', COUNT(*)::text
FROM timescaledb_information.continuous_aggregates
UNION ALL
SELECT 'Active Jobs', COUNT(*)::text
FROM timescaledb_information.jobs WHERE scheduled = true
UNION ALL
SELECT 'Failed Jobs (recent)', COUNT(*)::text
FROM timescaledb_information.job_stats WHERE last_run_status = 'Failed'
UNION ALL
SELECT 'Database Size', pg_size_pretty(pg_database_size(current_database()));
```

### 83. Job Health Summary
```sql
SELECT
    COUNT(*) AS total_jobs,
    COUNT(*) FILTER (WHERE js.last_run_status = 'Success') AS succeeded,
    COUNT(*) FILTER (WHERE js.last_run_status = 'Failed') AS failed,
    COUNT(*) FILTER (WHERE js.consecutive_failures > 0) AS currently_failing,
    COUNT(*) FILTER (WHERE js.consecutive_failures > 5) AS critically_failing
FROM timescaledb_information.job_stats js;
```

### 84. Data Freshness Check
```sql
-- How recent is the latest data in each hypertable?
SELECT h.hypertable_name,
       MAX(c.range_end) AS latest_chunk_end,
       NOW() - MAX(c.range_end) AS data_age
FROM timescaledb_information.hypertables h
JOIN timescaledb_information.chunks c
    ON c.hypertable_name = h.hypertable_name
GROUP BY h.hypertable_name
ORDER BY data_age;
```

### 85. Chunk Explosion Warning
```sql
-- Hypertables with excessive chunk counts
SELECT hypertable_name, COUNT(*) AS chunk_count,
       CASE
           WHEN COUNT(*) > 10000 THEN 'CRITICAL'
           WHEN COUNT(*) > 5000 THEN 'WARNING'
           ELSE 'OK'
       END AS status
FROM timescaledb_information.chunks
GROUP BY hypertable_name
HAVING COUNT(*) > 1000
ORDER BY chunk_count DESC;
```

### 86. Compression Policy Lag
```sql
-- Chunks that should be compressed but aren't
SELECT c.hypertable_name, c.chunk_name, c.range_end,
       NOW() - c.range_end AS age,
       j.config->>'compress_after' AS compress_after
FROM timescaledb_information.chunks c
JOIN timescaledb_information.jobs j
    ON j.hypertable_name = c.hypertable_name AND j.proc_name = 'policy_compression'
WHERE NOT c.is_compressed
  AND c.range_end < NOW() - (j.config->>'compress_after')::interval
ORDER BY c.range_end;
```

### 87. Retention Policy Lag
```sql
-- Chunks that should have been dropped but still exist
SELECT c.hypertable_name, c.chunk_name, c.range_end,
       NOW() - c.range_end AS age,
       j.config->>'drop_after' AS drop_after
FROM timescaledb_information.chunks c
JOIN timescaledb_information.jobs j
    ON j.hypertable_name = c.hypertable_name AND j.proc_name = 'policy_retention'
WHERE c.range_end < NOW() - (j.config->>'drop_after')::interval
ORDER BY c.range_end;
```

## Capacity Planning

### 88. Data Ingestion Rate (Rows per Second)
```sql
-- Compare two snapshots of n_tup_ins separated by a known interval
-- Snapshot 1:
SELECT relname, n_tup_ins FROM pg_stat_user_tables
WHERE relname IN (SELECT hypertable_name::text FROM timescaledb_information.hypertables);
-- Wait N seconds, then Snapshot 2, compute delta / N
```

### 89. Chunk Growth Rate
```sql
SELECT hypertable_name,
       DATE_TRUNC('week', range_start) AS week,
       COUNT(*) AS chunks_created,
       pg_size_pretty(SUM(
           pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass)
       )) AS total_size
FROM timescaledb_information.chunks
GROUP BY hypertable_name, DATE_TRUNC('week', range_start)
ORDER BY hypertable_name, week DESC;
```

### 90. Storage Projection
```sql
-- Average daily data size per hypertable
SELECT hypertable_name,
       pg_size_pretty(
           AVG(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass))
       ) AS avg_chunk_size,
       COUNT(*) AS total_chunks,
       pg_size_pretty(
           AVG(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass))
           * 365
       ) AS projected_yearly_growth
FROM timescaledb_information.chunks
WHERE range_start > NOW() - INTERVAL '30 days'
GROUP BY hypertable_name;
```

### 91. Connection Pool Sizing
```sql
SELECT count(*) AS total_connections,
       count(*) FILTER (WHERE state = 'active') AS active,
       count(*) FILTER (WHERE state = 'idle') AS idle,
       count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_tx,
       count(*) FILTER (WHERE application_name LIKE '%timescaledb%') AS tsdb_workers
FROM pg_stat_activity
WHERE datname = current_database();
```

## Troubleshooting Playbooks

### 92. Playbook: Slow Queries on Recent Data
```sql
-- Step 1: Verify chunk exclusion
EXPLAIN (ANALYZE, BUFFERS) SELECT ... FROM hypertable WHERE time > NOW() - INTERVAL '1 hour';
-- Look for "Chunks excluded" count

-- Step 2: Check if the recent chunk is compressed (shouldn't be for hot data)
SELECT chunk_name, is_compressed FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data'
ORDER BY range_start DESC LIMIT 5;

-- Step 3: Check index usage
SELECT indexrelname, idx_scan, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE relname LIKE '%_hyper_%' AND schemaname = '_timescaledb_internal'
ORDER BY idx_scan DESC LIMIT 10;

-- Step 4: Check buffer cache hit ratio for recent chunks
SELECT relname, heap_blks_hit, heap_blks_read,
       ROUND(heap_blks_hit::numeric / NULLIF(heap_blks_hit + heap_blks_read, 0) * 100, 2) AS hit_pct
FROM pg_statio_user_tables
WHERE schemaname = '_timescaledb_internal'
ORDER BY heap_blks_read DESC LIMIT 10;
```

### 93. Playbook: Compression Failures
```sql
-- Step 1: Check compression job errors
SELECT * FROM timescaledb_information.job_errors
WHERE proc_name LIKE '%compress%'
ORDER BY start_time DESC LIMIT 10;

-- Step 2: Check for locks blocking compression
SELECT l.pid, a.query, l.mode, l.granted
FROM pg_locks l JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.relation IN (
    SELECT format('%I.%I', chunk_schema, chunk_name)::regclass::oid
    FROM timescaledb_information.chunks
    WHERE hypertable_name = 'sensor_data' AND NOT is_compressed
);

-- Step 3: Check for long-running transactions that prevent compression
SELECT pid, query, state, NOW() - xact_start AS tx_duration
FROM pg_stat_activity
WHERE xact_start IS NOT NULL AND state != 'idle'
ORDER BY xact_start;

-- Step 4: Try manual compression with verbose error
SELECT compress_chunk(c) FROM show_chunks('sensor_data', older_than => INTERVAL '7 days') c
WHERE NOT EXISTS (
    SELECT 1 FROM timescaledb_information.chunks ch
    WHERE ch.chunk_name = split_part(c::text, '.', 2) AND ch.is_compressed
)
LIMIT 1;
```

### 94. Playbook: Continuous Aggregate Falling Behind
```sql
-- Step 1: Check refresh job status
SELECT j.job_id, js.last_run_status, js.last_run_duration,
       js.consecutive_failures, js.total_failures
FROM timescaledb_information.jobs j
JOIN timescaledb_information.job_stats js ON j.job_id = js.job_id
WHERE j.proc_name = 'policy_refresh_continuous_aggregate'
  AND j.hypertable_name LIKE '%sensor%';

-- Step 2: Check invalidation log size
SELECT COUNT(*) AS pending_invalidations
FROM _timescaledb_catalog.continuous_aggs_materialization_invalidation_log;

-- Step 3: Check if refresh window is too wide
SELECT j.config, j.schedule_interval
FROM timescaledb_information.jobs j
WHERE j.proc_name = 'policy_refresh_continuous_aggregate';

-- Step 4: Manual refresh to catch up
CALL refresh_continuous_aggregate('sensor_hourly', '2025-01-01', NOW());

-- Step 5: Consider narrowing the refresh window or increasing frequency
SELECT alter_job(job_id,
    schedule_interval => INTERVAL '15 minutes')
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_refresh_continuous_aggregate'
  AND hypertable_name LIKE '%sensor%';
```

### 95. Playbook: Chunk Explosion
```sql
-- Step 1: Identify the problem
SELECT hypertable_name, COUNT(*) AS chunk_count
FROM timescaledb_information.chunks
GROUP BY hypertable_name
ORDER BY chunk_count DESC;

-- Step 2: Check chunk interval (too small = too many chunks)
SELECT h.hypertable_name, d.column_name,
       d.time_interval
FROM timescaledb_information.hypertables h
JOIN timescaledb_information.dimensions d
    ON d.hypertable_name = h.hypertable_name;

-- Step 3: Check space partitioning (multiplies chunk count)
SELECT hypertable_name, num_partitions
FROM timescaledb_information.dimensions
WHERE num_partitions IS NOT NULL;

-- Step 4: Increase chunk interval for future chunks
SELECT set_chunk_time_interval('sensor_data', INTERVAL '7 days');

-- Step 5: Merge old small chunks via compression (compressed chunks are single files)
-- Or drop old chunks via retention policy
SELECT add_retention_policy('sensor_data', INTERVAL '365 days');
```

### 96. Playbook: High Memory Usage
```sql
-- Step 1: Check shared_buffers utilization
SHOW shared_buffers;
SELECT pg_size_pretty(pg_database_size(current_database())) AS db_size;

-- Step 2: Check for large sorts or hash operations
SELECT pid, query, state,
       NOW() - query_start AS duration
FROM pg_stat_activity
WHERE state = 'active' AND wait_event_type = 'IO'
ORDER BY duration DESC;

-- Step 3: Check temp file usage (indicates work_mem too small)
SELECT datname, temp_files, pg_size_pretty(temp_bytes) AS temp_size
FROM pg_stat_database WHERE datname = current_database();

-- Step 4: Check background worker memory
SHOW timescaledb.max_background_workers;
SHOW work_mem;
SHOW maintenance_work_mem;
```

### 97. Playbook: INSERT Performance Degradation
```sql
-- Step 1: Check for lock contention on chunk creation
SELECT * FROM pg_locks WHERE NOT granted AND locktype = 'relation';

-- Step 2: Check WAL generation rate
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) AS total_wal;

-- Step 3: Check if INSERTs are hitting compressed chunks (slow path)
SELECT chunk_name, is_compressed, compression_status
FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data'
ORDER BY range_start DESC LIMIT 5;

-- Step 4: Check autovacuum interference
SELECT schemaname, relname, n_dead_tup,
       last_autovacuum, autovacuum_count
FROM pg_stat_user_tables
WHERE schemaname = '_timescaledb_internal'
  AND n_dead_tup > 100000
ORDER BY n_dead_tup DESC;

-- Step 5: Check checkpoint frequency (too frequent = write amplification)
SELECT checkpoints_timed, checkpoints_req,
       checkpoint_write_time / 1000 AS write_time_sec,
       buffers_checkpoint
FROM pg_stat_bgwriter;
```

### 98. Playbook: Query Not Using Indexes
```sql
-- Step 1: Run EXPLAIN ANALYZE
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM sensor_data
WHERE time > NOW() - INTERVAL '1 hour' AND sensor_id = 42;

-- Step 2: Check if index exists
SELECT indexname, indexdef FROM pg_indexes
WHERE tablename LIKE '%_hyper_%' AND indexdef LIKE '%sensor_id%'
LIMIT 10;

-- Step 3: Check if statistics are current
SELECT schemaname, relname, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = '_timescaledb_internal'
ORDER BY last_autoanalyze DESC NULLS LAST LIMIT 10;

-- Step 4: Force analyze on recent chunks
ANALYZE sensor_data;

-- Step 5: Check planner cost settings
SHOW random_page_cost;   -- Lower to 1.1 for SSD
SHOW seq_page_cost;
SHOW effective_cache_size;
```

## Advanced Diagnostics

### 99. Internal Catalog: Hypertable Metadata
```sql
SELECT id, schema_name, table_name, associated_schema_name,
       num_dimensions, chunk_sizing_func_schema, chunk_sizing_func_name,
       compression_state
FROM _timescaledb_catalog.hypertable;
```

### 100. Internal Catalog: Dimension Details
```sql
SELECT d.id, h.table_name, d.column_name, d.column_type,
       d.aligned, d.num_slices, d.partitioning_func_schema,
       d.partitioning_func, d.interval_length,
       CASE WHEN d.interval_length IS NOT NULL
            THEN make_interval(secs => d.interval_length / 1000000.0)
       END AS human_interval
FROM _timescaledb_catalog.dimension d
JOIN _timescaledb_catalog.hypertable h ON d.hypertable_id = h.id;
```

### 101. Internal Catalog: Chunk Details
```sql
SELECT c.id, h.table_name AS hypertable, c.schema_name, c.table_name,
       c.compressed_chunk_id, c.dropped, c.status,
       c.osm_chunk  -- object storage manager (tiered chunk)
FROM _timescaledb_catalog.chunk c
JOIN _timescaledb_catalog.hypertable h ON c.hypertable_id = h.id
ORDER BY h.table_name, c.id;
```

### 102. Internal Catalog: Dimension Slices (Chunk Boundaries)
```sql
SELECT ds.id, d.column_name, ds.range_start, ds.range_end,
       CASE WHEN d.column_type = 'timestamptz'::regtype
            THEN to_timestamp(ds.range_start / 1000000.0)::text
            ELSE ds.range_start::text END AS range_start_human,
       CASE WHEN d.column_type = 'timestamptz'::regtype
            THEN to_timestamp(ds.range_end / 1000000.0)::text
            ELSE ds.range_end::text END AS range_end_human
FROM _timescaledb_catalog.dimension_slice ds
JOIN _timescaledb_catalog.dimension d ON ds.dimension_id = d.id
ORDER BY d.id, ds.range_start
LIMIT 50;
```

### 103. Internal Catalog: Compression Settings
```sql
SELECT h.table_name, cs.segmentby_column_index, cs.segmentby_column_name,
       cs.orderby_column_index, cs.orderby_column_name, cs.orderby_asc, cs.orderby_nullsfirst
FROM _timescaledb_catalog.compression_settings cs
JOIN _timescaledb_catalog.hypertable h ON cs.relid = format('%I.%I', h.schema_name, h.table_name)::regclass;
```

### 104. Internal Catalog: Background Job Configuration
```sql
SELECT id, application_name, schedule_interval, max_runtime,
       max_retries, retry_period, proc_schema, proc_name,
       hypertable_id, config, scheduled, fixed_schedule
FROM _timescaledb_config.bgw_job
ORDER BY id;
```

### 105. Check for Orphaned Chunks (Catalog Mismatch)
```sql
-- Chunks in catalog but table doesn't exist
SELECT c.schema_name, c.table_name
FROM _timescaledb_catalog.chunk c
WHERE NOT c.dropped
  AND NOT EXISTS (
    SELECT 1 FROM pg_class cl
    JOIN pg_namespace ns ON cl.relnamespace = ns.oid
    WHERE ns.nspname = c.schema_name AND cl.relname = c.table_name
  );
```

### 106. Check for Tables Not in Catalog (Orphaned Tables)
```sql
-- Tables in _timescaledb_internal that are not tracked in catalog
SELECT n.nspname, c.relname
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = '_timescaledb_internal'
  AND c.relkind = 'r'
  AND c.relname LIKE '_hyper_%'
  AND NOT EXISTS (
    SELECT 1 FROM _timescaledb_catalog.chunk ch
    WHERE ch.schema_name = n.nspname AND ch.table_name = c.relname
  );
```

### 107. TimescaleDB Telemetry Status
```sql
SHOW timescaledb.telemetry_level;
-- Values: off, basic, full
```

### 108. Check Chunk Append Settings
```sql
SHOW timescaledb.enable_chunk_append;
SHOW timescaledb.enable_parallel_chunk_append;
SHOW timescaledb.enable_constraint_aware_append;
```

### 109. Check Compression GUC Settings
```sql
SHOW timescaledb.enable_transparent_decompression;
SHOW timescaledb.enable_decompression_sorted_merge;
```

### 110. TimescaleDB License Check
```sql
SHOW timescaledb.license;
-- 'apache' = Apache-2 (open source features only)
-- 'timescale' = Timescale License (all features including compression, caggs, policies)
```

### 111. Estimate Compression Savings Before Enabling
```sql
-- Sample-based compression estimate
SELECT pg_size_pretty(
    pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass)
) AS current_size,
chunk_name
FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data'
  AND NOT is_compressed
ORDER BY range_start DESC
LIMIT 1;
-- Compress the single chunk, measure, then decompress if needed
```

### 112. Monitor Ongoing Compression Progress
```sql
-- While compression is running, check progress
SELECT a.pid, a.query, a.state,
       NOW() - a.query_start AS duration,
       p.phase, p.blocks_total, p.blocks_done,
       ROUND(p.blocks_done::numeric / NULLIF(p.blocks_total, 0) * 100, 1) AS pct_complete
FROM pg_stat_activity a
LEFT JOIN pg_stat_progress_create_index p ON a.pid = p.pid
WHERE a.query LIKE '%compress_chunk%'
   OR a.application_name LIKE '%compress%';
```

### 113. Data Distribution Across Chunks (Skew Detection)
```sql
SELECT chunk_name,
       pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass) AS bytes,
       pg_size_pretty(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass)) AS size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data'
  AND NOT is_compressed
ORDER BY bytes DESC
LIMIT 20;
-- Large variance in chunk sizes may indicate uneven data distribution or
-- variable ingestion rates
```

### 114. Check for Mixed Compression States in a Hypertable
```sql
SELECT hypertable_name,
       COUNT(*) FILTER (WHERE is_compressed) AS compressed,
       COUNT(*) FILTER (WHERE NOT is_compressed) AS uncompressed,
       COUNT(*) FILTER (WHERE compression_status = 'Partially compressed') AS partially_compressed
FROM timescaledb_information.chunks
GROUP BY hypertable_name
ORDER BY hypertable_name;
```

### 115. Verify time_bucket Chunk Exclusion with Prepared Statements
```sql
-- Prepared statements with parameters can still benefit from chunk exclusion
PREPARE bucket_query(timestamptz, timestamptz) AS
SELECT time_bucket('1 hour', time) AS bucket, AVG(temperature)
FROM sensor_data
WHERE time >= $1 AND time < $2
GROUP BY bucket ORDER BY bucket;

EXPLAIN (ANALYZE) EXECUTE bucket_query('2025-03-01', '2025-03-02');
```

### 116. Check for Trigger Issues on Hypertables
```sql
SELECT tgname, tgrelid::regclass, tgenabled, tgtype
FROM pg_trigger
WHERE tgrelid IN (
    SELECT format('%I.%I', hypertable_schema, hypertable_name)::regclass
    FROM timescaledb_information.hypertables
)
AND NOT tgisinternal;
```
