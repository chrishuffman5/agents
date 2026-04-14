# Snowflake Diagnostics Reference

## Account and Environment Information

### 1. Current Account and Session Info

```sql
SELECT CURRENT_ACCOUNT() AS account,
       CURRENT_REGION() AS region,
       CURRENT_USER() AS user,
       CURRENT_ROLE() AS role,
       CURRENT_WAREHOUSE() AS warehouse,
       CURRENT_DATABASE() AS database,
       CURRENT_SCHEMA() AS schema,
       CURRENT_SESSION() AS session_id;
```

### 2. Account-Level Parameters

```sql
SHOW PARAMETERS IN ACCOUNT;
```

```sql
-- Specific important parameters
SHOW PARAMETERS LIKE 'TIMEZONE' IN ACCOUNT;
SHOW PARAMETERS LIKE 'DATA_RETENTION_TIME_IN_DAYS' IN ACCOUNT;
SHOW PARAMETERS LIKE 'STATEMENT_TIMEOUT%' IN ACCOUNT;
SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN ACCOUNT;
```

### 3. Account Edition and Features

```sql
SELECT SYSTEM$GET_SNOWFLAKE_PLATFORM_INFO();
```

### 4. Current Session Parameters

```sql
SHOW PARAMETERS IN SESSION;
```

```sql
-- Check specific session settings
SELECT CURRENT_TIMESTAMP() AS current_time,
       CURRENT_TRANSACTION() AS current_txn;
```

## Warehouse Diagnostics

### 5. List All Warehouses

```sql
SHOW WAREHOUSES;
```

### 6. Warehouse Configuration Details

```sql
SHOW WAREHOUSES LIKE 'analytics%';
```

```sql
-- Warehouse parameters
SHOW PARAMETERS IN WAREHOUSE analytics_wh;
```

### 7. Warehouse Credit Consumption (Last 7 Days)

```sql
SELECT warehouse_name,
       SUM(credits_used) AS total_credits,
       SUM(credits_used_compute) AS compute_credits,
       SUM(credits_used_cloud_services) AS cloud_services_credits,
       COUNT(*) AS metering_intervals
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits DESC;
```

### 8. Hourly Credit Consumption by Warehouse

```sql
SELECT DATE_TRUNC('hour', start_time) AS hour,
       warehouse_name,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day, -3, CURRENT_TIMESTAMP())
GROUP BY hour, warehouse_name
ORDER BY hour DESC, credits DESC;
```

### 9. Warehouse Utilization (Active vs Idle Time)

```sql
SELECT warehouse_name,
       COUNT(DISTINCT DATE_TRUNC('hour', start_time)) AS active_hours,
       SUM(credits_used) AS total_credits,
       SUM(credits_used) / NULLIF(COUNT(DISTINCT DATE_TRUNC('hour', start_time)), 0) AS credits_per_active_hour
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits DESC;
```

### 10. Warehouse Load (Queries Per Hour)

```sql
SELECT DATE_TRUNC('hour', start_time) AS hour,
       warehouse_name,
       COUNT(*) AS query_count,
       AVG(execution_time) / 1000 AS avg_exec_sec,
       MAX(execution_time) / 1000 AS max_exec_sec,
       SUM(bytes_scanned) / POWER(1024, 3) AS total_gb_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -3, CURRENT_TIMESTAMP())
  AND warehouse_name IS NOT NULL
GROUP BY hour, warehouse_name
ORDER BY hour DESC, query_count DESC;
```

### 11. Warehouse Queue Times

```sql
SELECT warehouse_name,
       COUNT(*) AS queued_queries,
       AVG(queued_overload_time) / 1000 AS avg_queue_sec,
       MAX(queued_overload_time) / 1000 AS max_queue_sec,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY queued_overload_time) / 1000 AS p95_queue_sec
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND queued_overload_time > 0
  AND warehouse_name IS NOT NULL
GROUP BY warehouse_name
ORDER BY avg_queue_sec DESC;
```

### 12. Warehouse Queue Time Trend (Hourly)

```sql
SELECT DATE_TRUNC('hour', start_time) AS hour,
       warehouse_name,
       COUNT(CASE WHEN queued_overload_time > 0 THEN 1 END) AS queued_count,
       AVG(CASE WHEN queued_overload_time > 0 THEN queued_overload_time END) / 1000 AS avg_queue_sec
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -3, CURRENT_TIMESTAMP())
  AND warehouse_name IS NOT NULL
GROUP BY hour, warehouse_name
HAVING queued_count > 0
ORDER BY hour DESC, avg_queue_sec DESC;
```

### 13. Multi-Cluster Warehouse Scaling Events

```sql
SELECT DATE_TRUNC('hour', start_time) AS hour,
       warehouse_name,
       MIN(credits_used) AS min_credits,
       MAX(credits_used) AS max_credits,
       AVG(credits_used) AS avg_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY hour, warehouse_name
ORDER BY hour DESC;
```

### 14. Warehouse Event History

```sql
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_EVENTS_HISTORY
WHERE timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY timestamp DESC
LIMIT 100;
```

## Query Performance Diagnostics

### 15. Slowest Queries (Last 24 Hours)

```sql
SELECT query_id, query_text, user_name, warehouse_name, warehouse_size,
       execution_time / 1000 AS exec_sec,
       compilation_time / 1000 AS compile_sec,
       bytes_scanned / POWER(1024, 3) AS gb_scanned,
       rows_produced,
       partitions_scanned, partitions_total
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -1, CURRENT_TIMESTAMP())
  AND execution_time > 0
ORDER BY execution_time DESC
LIMIT 25;
```

### 16. Queries with High Spilling

```sql
SELECT query_id, SUBSTR(query_text, 1, 200) AS query_preview,
       user_name, warehouse_name, warehouse_size,
       execution_time / 1000 AS exec_sec,
       bytes_spilled_to_local_storage / POWER(1024, 3) AS local_spill_gb,
       bytes_spilled_to_remote_storage / POWER(1024, 3) AS remote_spill_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
ORDER BY (bytes_spilled_to_local_storage + bytes_spilled_to_remote_storage) DESC
LIMIT 25;
```

### 17. Queries with Poor Partition Pruning

```sql
SELECT query_id, SUBSTR(query_text, 1, 200) AS query_preview,
       user_name, warehouse_name,
       partitions_scanned, partitions_total,
       ROUND(partitions_scanned::FLOAT / NULLIF(partitions_total, 0) * 100, 2) AS pct_scanned,
       bytes_scanned / POWER(1024, 3) AS gb_scanned,
       execution_time / 1000 AS exec_sec
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND partitions_total > 100
  AND partitions_scanned::FLOAT / NULLIF(partitions_total, 0) > 0.5
  AND query_type = 'SELECT'
ORDER BY partitions_scanned DESC
LIMIT 50;
```

### 18. Query Execution Breakdown by Type

```sql
SELECT query_type,
       COUNT(*) AS query_count,
       AVG(execution_time) / 1000 AS avg_exec_sec,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time) / 1000 AS p95_exec_sec,
       SUM(bytes_scanned) / POWER(1024, 4) AS total_tb_scanned,
       SUM(credits_used_cloud_services) AS cloud_services_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY query_type
ORDER BY query_count DESC;
```

### 19. Query Operator Stats (Per-Query Deep Dive)

```sql
-- Get detailed operator-level statistics for a specific query
SELECT * FROM TABLE(GET_QUERY_OPERATOR_STATS('01a6b3c7-0000-1234-0000-000500000000'));
```

### 20. EXPLAIN Plan

```sql
EXPLAIN USING JSON
SELECT o.order_id, c.name
FROM orders o JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date > '2026-01-01';
```

```sql
EXPLAIN USING TABULAR
SELECT * FROM orders WHERE region = 'US' AND order_date > '2026-01-01';
```

### 21. Queries Using Result Cache

```sql
SELECT query_id, SUBSTR(query_text, 1, 200) AS query_preview,
       execution_time / 1000 AS exec_sec,
       bytes_scanned,
       percentage_scanned_from_cache
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -1, CURRENT_TIMESTAMP())
  AND bytes_scanned = 0
  AND execution_time < 500  -- near-instant from cache
ORDER BY start_time DESC
LIMIT 50;
```

### 22. Cache Hit Rate Analysis

```sql
SELECT DATE_TRUNC('hour', start_time) AS hour,
       warehouse_name,
       COUNT(*) AS total_queries,
       COUNT(CASE WHEN bytes_scanned = 0 AND execution_time < 500 THEN 1 END) AS cache_hits,
       ROUND(COUNT(CASE WHEN bytes_scanned = 0 AND execution_time < 500 THEN 1 END)::FLOAT /
             NULLIF(COUNT(*), 0) * 100, 2) AS cache_hit_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -3, CURRENT_TIMESTAMP())
  AND warehouse_name IS NOT NULL
GROUP BY hour, warehouse_name
ORDER BY hour DESC;
```

### 23. Compilation Time Analysis

```sql
SELECT query_id, SUBSTR(query_text, 1, 200) AS query_preview,
       compilation_time / 1000 AS compile_sec,
       execution_time / 1000 AS exec_sec,
       ROUND(compilation_time::FLOAT / NULLIF(execution_time + compilation_time, 0) * 100, 2) AS compile_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND compilation_time > 5000  -- >5 seconds compilation
ORDER BY compilation_time DESC
LIMIT 25;
```

### 24. Failed Queries

```sql
SELECT query_id, SUBSTR(query_text, 1, 200) AS query_preview,
       user_name, warehouse_name,
       error_code, error_message,
       start_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND execution_status = 'FAIL'
ORDER BY start_time DESC
LIMIT 50;
```

### 25. Error Code Distribution

```sql
SELECT error_code, error_message, COUNT(*) AS occurrences
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND execution_status = 'FAIL'
GROUP BY error_code, error_message
ORDER BY occurrences DESC
LIMIT 20;
```

### 26. Query Acceleration Eligibility

```sql
SELECT query_id, SUBSTR(query_text, 1, 200) AS query_preview,
       warehouse_name,
       execution_time / 1000 AS exec_sec,
       eligible_query_acceleration_time / 1000 AS eligible_accel_sec,
       ROUND(eligible_query_acceleration_time::FLOAT / NULLIF(execution_time, 0) * 100, 2) AS accel_potential_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND eligible_query_acceleration_time > 0
ORDER BY eligible_query_acceleration_time DESC
LIMIT 25;
```

### 27. Query Acceleration History

```sql
SELECT DATE_TRUNC('day', start_time) AS day,
       warehouse_name,
       SUM(credits_used) AS accel_credits,
       COUNT(*) AS accelerated_queries,
       SUM(num_files_scanned) AS total_files_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ACCELERATION_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, warehouse_name
ORDER BY day DESC, accel_credits DESC;
```

### 28. Queries by User (Top Consumers)

```sql
SELECT user_name,
       COUNT(*) AS query_count,
       SUM(execution_time) / 1000 AS total_exec_sec,
       AVG(execution_time) / 1000 AS avg_exec_sec,
       SUM(bytes_scanned) / POWER(1024, 4) AS total_tb_scanned,
       SUM(credits_used_cloud_services) AS cloud_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY user_name
ORDER BY total_exec_sec DESC;
```

### 29. Most Repeated Queries (Optimization Candidates)

```sql
SELECT SUBSTR(query_text, 1, 200) AS query_pattern,
       query_type,
       COUNT(*) AS execution_count,
       AVG(execution_time) / 1000 AS avg_exec_sec,
       SUM(bytes_scanned) / POWER(1024, 3) AS total_gb_scanned,
       SUM(execution_time) / 1000 AS total_exec_sec
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND execution_status = 'SUCCESS'
  AND query_type = 'SELECT'
GROUP BY query_pattern, query_type
HAVING execution_count > 10
ORDER BY total_exec_sec DESC
LIMIT 25;
```

### 30. Queries Scanning Most Data

```sql
SELECT query_id, SUBSTR(query_text, 1, 200) AS query_preview,
       user_name, warehouse_name,
       bytes_scanned / POWER(1024, 3) AS gb_scanned,
       rows_produced,
       execution_time / 1000 AS exec_sec
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND bytes_scanned > 0
ORDER BY bytes_scanned DESC
LIMIT 25;
```

## Storage Diagnostics

### 31. Account-Level Storage Usage

```sql
SELECT USAGE_DATE,
       STORAGE_BYTES / POWER(1024, 4) AS storage_tb,
       STAGE_BYTES / POWER(1024, 4) AS stage_tb,
       FAILSAFE_BYTES / POWER(1024, 4) AS failsafe_tb
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
WHERE USAGE_DATE > DATEADD(day, -30, CURRENT_DATE())
ORDER BY USAGE_DATE DESC;
```

### 32. Storage Usage Trend

```sql
SELECT USAGE_DATE,
       (STORAGE_BYTES + STAGE_BYTES + FAILSAFE_BYTES) / POWER(1024, 4) AS total_tb,
       STORAGE_BYTES / POWER(1024, 4) AS active_tb,
       STAGE_BYTES / POWER(1024, 4) AS stage_tb,
       FAILSAFE_BYTES / POWER(1024, 4) AS failsafe_tb
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
WHERE USAGE_DATE > DATEADD(day, -90, CURRENT_DATE())
ORDER BY USAGE_DATE DESC;
```

### 33. Table Storage Metrics (Top Tables by Size)

```sql
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME,
       ACTIVE_BYTES / POWER(1024, 3) AS active_gb,
       TIME_TRAVEL_BYTES / POWER(1024, 3) AS time_travel_gb,
       FAILSAFE_BYTES / POWER(1024, 3) AS failsafe_gb,
       (ACTIVE_BYTES + TIME_TRAVEL_BYTES + FAILSAFE_BYTES) / POWER(1024, 3) AS total_gb,
       CLONE_BYTES / POWER(1024, 3) AS clone_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE ACTIVE_BYTES > 0
ORDER BY total_gb DESC
LIMIT 50;
```

### 34. Tables with High Time Travel Storage (Churn Indicator)

```sql
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME,
       ACTIVE_BYTES / POWER(1024, 3) AS active_gb,
       TIME_TRAVEL_BYTES / POWER(1024, 3) AS time_travel_gb,
       FAILSAFE_BYTES / POWER(1024, 3) AS failsafe_gb,
       ROUND(TIME_TRAVEL_BYTES::FLOAT / NULLIF(ACTIVE_BYTES, 0), 2) AS tt_ratio
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE ACTIVE_BYTES > 1073741824  -- >1GB
  AND TIME_TRAVEL_BYTES > ACTIVE_BYTES  -- TT > active data
ORDER BY TIME_TRAVEL_BYTES DESC
LIMIT 25;
```

### 35. Database Storage Breakdown

```sql
SELECT TABLE_CATALOG AS database_name,
       SUM(ACTIVE_BYTES) / POWER(1024, 4) AS active_tb,
       SUM(TIME_TRAVEL_BYTES) / POWER(1024, 4) AS time_travel_tb,
       SUM(FAILSAFE_BYTES) / POWER(1024, 4) AS failsafe_tb,
       SUM(ACTIVE_BYTES + TIME_TRAVEL_BYTES + FAILSAFE_BYTES) / POWER(1024, 4) AS total_tb
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
GROUP BY database_name
ORDER BY total_tb DESC;
```

### 36. Stage Storage Usage

```sql
SELECT DATE_TRUNC('day', USAGE_DATE) AS day,
       AVERAGE_STAGE_BYTES / POWER(1024, 3) AS stage_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
WHERE USAGE_DATE > DATEADD(day, -30, CURRENT_DATE())
ORDER BY day DESC;
```

### 37. List Files in a Stage

```sql
LIST @my_stage;
```

```sql
-- With pattern matching
LIST @my_stage PATTERN = '.*[.]parquet';
```

### 38. Stage Directory Table

```sql
SELECT RELATIVE_PATH, SIZE, LAST_MODIFIED, MD5
FROM DIRECTORY(@my_stage)
ORDER BY LAST_MODIFIED DESC;
```

### 39. Table Row Counts and Sizes (INFORMATION_SCHEMA)

```sql
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME,
       ROW_COUNT, BYTES,
       BYTES / POWER(1024, 3) AS size_gb,
       CREATED, LAST_ALTERED
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA != 'INFORMATION_SCHEMA'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY BYTES DESC NULLS LAST
LIMIT 50;
```

### 40. Table Metadata from SHOW

```sql
SHOW TABLES IN DATABASE my_database;
```

```sql
SHOW TABLES LIKE '%order%' IN SCHEMA my_database.public;
```

## Clustering Diagnostics

### 41. Clustering Information for a Table

```sql
SELECT SYSTEM$CLUSTERING_INFORMATION('orders', '(order_date, region)');
```

Output includes:
- `cluster_by_keys`: Clustering key expression
- `total_partition_count`: Total micro-partitions
- `total_constant_partition_count`: Partitions where all rows have the same clustering key value (perfectly clustered)
- `average_overlaps`: Average number of overlapping partitions per clustering key range
- `average_depth`: Average number of partitions a single value spans (1.0 = perfect)
- `partition_depth_histogram`: Distribution of partition depths

### 42. Clustering Depth Check (Multiple Tables)

```sql
-- Run for each table of interest
SELECT 'orders' AS table_name, SYSTEM$CLUSTERING_INFORMATION('orders', '(order_date)') AS info
UNION ALL
SELECT 'events', SYSTEM$CLUSTERING_INFORMATION('events', '(TO_DATE(event_timestamp))');
```

### 43. Automatic Clustering History

```sql
SELECT DATE_TRUNC('day', start_time) AS day,
       table_name,
       SUM(credits_used) AS credits,
       SUM(num_bytes_reclustered) / POWER(1024, 3) AS gb_reclustered,
       SUM(num_rows_reclustered) AS rows_reclustered
FROM SNOWFLAKE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, table_name
ORDER BY credits DESC;
```

### 44. Clustering Cost by Table (Top Consumers)

```sql
SELECT table_name,
       SUM(credits_used) AS total_credits,
       SUM(num_bytes_reclustered) / POWER(1024, 3) AS total_gb_reclustered,
       COUNT(*) AS reclustering_events
FROM SNOWFLAKE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY table_name
ORDER BY total_credits DESC
LIMIT 20;
```

## Data Loading Diagnostics

### 45. COPY History (Last 24 Hours)

```sql
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'target_table',
    START_TIME => DATEADD(hours, -24, CURRENT_TIMESTAMP())
))
ORDER BY last_load_time DESC;
```

### 46. COPY History from ACCOUNT_USAGE (Last 30 Days)

```sql
SELECT TABLE_CATALOG_NAME, TABLE_SCHEMA_NAME, TABLE_NAME,
       FILE_NAME, STATUS, ROW_COUNT, ROW_PARSED, FILE_SIZE,
       ERROR_COUNT, FIRST_ERROR_MESSAGE, FIRST_ERROR_LINE_NUMBER
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE last_load_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
ORDER BY last_load_time DESC
LIMIT 50;
```

### 47. Failed Data Loads

```sql
SELECT TABLE_NAME, FILE_NAME, STATUS,
       ERROR_COUNT, FIRST_ERROR_MESSAGE,
       FIRST_ERROR_LINE_NUMBER, FIRST_ERROR_CHARACTER_POS,
       FIRST_ERROR_COLUMN_NAME,
       last_load_time
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE STATUS = 'LOAD_FAILED'
  AND last_load_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY last_load_time DESC
LIMIT 50;
```

### 48. Data Loading Volume Trend

```sql
SELECT DATE_TRUNC('day', last_load_time) AS day,
       TABLE_NAME,
       COUNT(*) AS file_count,
       SUM(ROW_COUNT) AS total_rows,
       SUM(FILE_SIZE) / POWER(1024, 3) AS total_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE last_load_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
  AND STATUS = 'LOADED'
GROUP BY day, TABLE_NAME
ORDER BY day DESC, total_gb DESC;
```

### 49. Validate File Before Loading

```sql
-- Return first 10 rows (preview)
COPY INTO target_table FROM @my_stage
  VALIDATION_MODE = 'RETURN_10_ROWS';

-- Return all errors without loading
COPY INTO target_table FROM @my_stage
  VALIDATION_MODE = 'RETURN_ALL_ERRORS';

-- Return errors only
COPY INTO target_table FROM @my_stage
  VALIDATION_MODE = 'RETURN_ERRORS';
```

## Snowpipe Diagnostics

### 50. Pipe Status

```sql
SELECT SYSTEM$PIPE_STATUS('my_pipe');
-- Returns JSON: executionState, pendingFileCount, lastIngestedTimestamp,
--               lastIngestedFilePath, notificationChannelName, numOutstandingMessagesOnChannel
```

### 51. List All Pipes

```sql
SHOW PIPES;
```

```sql
SHOW PIPES LIKE '%events%' IN DATABASE my_database;
```

### 52. Pipe Copy History

```sql
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'target_table',
    START_TIME => DATEADD(hours, -24, CURRENT_TIMESTAMP())
))
WHERE pipe_catalog_name IS NOT NULL
ORDER BY last_load_time DESC;
```

### 53. Snowpipe Credit Usage

```sql
SELECT DATE_TRUNC('day', start_time) AS day,
       pipe_name,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, pipe_name
ORDER BY day DESC, credits DESC;
```

### 54. Pipe Error Notifications

```sql
SELECT pipe_name, error_message, file_name
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'target_table',
    START_TIME => DATEADD(hours, -24, CURRENT_TIMESTAMP())
))
WHERE STATUS = 'LOAD_FAILED'
ORDER BY last_load_time DESC;
```

### 55. Refresh Pipe (Re-read Notifications)

```sql
-- Force Snowpipe to re-read event notifications for a specific path
ALTER PIPE my_pipe REFRESH PREFIX = 'data/2026/04/';
```

## Stream and Task Diagnostics

### 56. Stream Status

```sql
SELECT SYSTEM$STREAM_HAS_DATA('my_stream');
```

### 57. List All Streams

```sql
SHOW STREAMS;
```

```sql
SHOW STREAMS IN DATABASE my_database;
```

### 58. Stream Details and Offset

```sql
SELECT * FROM INFORMATION_SCHEMA.STREAMS
WHERE STREAM_SCHEMA = 'PUBLIC';
```

### 59. Preview Stream Contents

```sql
SELECT METADATA$ACTION, METADATA$ISUPDATE, METADATA$ROW_ID, *
FROM my_stream
LIMIT 100;
```

### 60. Stream Staleness Check

```sql
-- Check if the stream's offset is still within Time Travel retention
-- A stale stream cannot be consumed and must be recreated
SHOW STREAMS LIKE 'my_stream';
-- Check STALE column: TRUE means the stream's offset has fallen behind Time Travel
```

### 61. Task History (Last 24 Hours)

```sql
SELECT name, database_name, schema_name, state, query_text,
       scheduled_time, completed_time,
       DATEDIFF(second, scheduled_time, completed_time) AS duration_sec,
       error_code, error_message
FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
WHERE scheduled_time > DATEADD(day, -1, CURRENT_TIMESTAMP())
ORDER BY scheduled_time DESC
LIMIT 100;
```

### 62. Failed Tasks

```sql
SELECT name, database_name, schema_name,
       scheduled_time, error_code, error_message,
       SUBSTR(query_text, 1, 200) AS query_preview
FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
WHERE state = 'FAILED'
  AND scheduled_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY scheduled_time DESC
LIMIT 50;
```

### 63. Task Execution Duration Trend

```sql
SELECT name,
       DATE_TRUNC('day', scheduled_time) AS day,
       COUNT(*) AS executions,
       AVG(DATEDIFF(second, scheduled_time, completed_time)) AS avg_duration_sec,
       MAX(DATEDIFF(second, scheduled_time, completed_time)) AS max_duration_sec,
       COUNT(CASE WHEN state = 'FAILED' THEN 1 END) AS failures
FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
WHERE scheduled_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY name, day
ORDER BY day DESC, avg_duration_sec DESC;
```

### 64. List All Tasks and Their State

```sql
SHOW TASKS;
```

```sql
SHOW TASKS IN DATABASE my_database;
```

### 65. Task Dependencies (DAG)

```sql
SELECT name, database_name, schema_name, schedule, predecessors, state
FROM INFORMATION_SCHEMA.TASKS
WHERE TASK_SCHEMA = 'PUBLIC'
ORDER BY name;
```

### 66. Serverless Task Credit Usage

```sql
SELECT DATE_TRUNC('day', start_time) AS day,
       task_name,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, task_name
ORDER BY day DESC, credits DESC;
```

## Security Diagnostics

### 67. Login History (Last 7 Days)

```sql
SELECT event_timestamp, user_name, client_ip,
       reported_client_type, reported_client_version,
       first_authentication_factor, second_authentication_factor,
       is_success, error_code, error_message
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY event_timestamp DESC
LIMIT 100;
```

### 68. Failed Login Attempts

```sql
SELECT user_name, client_ip, reported_client_type,
       error_code, error_message,
       COUNT(*) AS failure_count,
       MIN(event_timestamp) AS first_failure,
       MAX(event_timestamp) AS last_failure
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE is_success = 'NO'
  AND event_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY user_name, client_ip, reported_client_type, error_code, error_message
ORDER BY failure_count DESC;
```

### 69. Brute Force Detection (Many Failures from Single IP)

```sql
SELECT client_ip, COUNT(*) AS failure_count,
       COUNT(DISTINCT user_name) AS distinct_users_targeted,
       MIN(event_timestamp) AS first_attempt,
       MAX(event_timestamp) AS last_attempt
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE is_success = 'NO'
  AND event_timestamp > DATEADD(day, -1, CURRENT_TIMESTAMP())
GROUP BY client_ip
HAVING failure_count > 10
ORDER BY failure_count DESC;
```

### 70. Access History (Column-Level Tracking)

```sql
SELECT user_name, query_id, query_start_time,
       direct_objects_accessed, base_objects_accessed,
       objects_modified
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE query_start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY query_start_time DESC
LIMIT 50;
```

### 71. Users with ACCOUNTADMIN Role (Security Audit)

```sql
SELECT grantee_name, role, granted_by, created_on
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE role = 'ACCOUNTADMIN'
  AND deleted_on IS NULL
ORDER BY created_on DESC;
```

### 72. Role Grants Hierarchy

```sql
SHOW GRANTS OF ROLE analyst_role;
```

```sql
SHOW GRANTS TO ROLE analyst_role;
```

```sql
-- All role grants in the account
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE deleted_on IS NULL
  AND granted_on = 'ROLE'
ORDER BY role, name;
```

### 73. Network Policies

```sql
SHOW NETWORK POLICIES;
```

```sql
-- Check which policies are active
SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN ACCOUNT;
SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN USER my_user;
```

### 74. Masking Policy References

```sql
SELECT * FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
    POLICY_NAME => 'pii_mask'
));
```

```sql
-- All masking policy references
SELECT policy_name, policy_kind, ref_database_name, ref_schema_name,
       ref_entity_name, ref_column_name
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
WHERE policy_kind = 'MASKING_POLICY'
  AND deleted IS NULL;
```

### 75. Row Access Policy References

```sql
SELECT policy_name, policy_kind, ref_database_name, ref_schema_name,
       ref_entity_name, ref_column_name
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
WHERE policy_kind = 'ROW_ACCESS_POLICY'
  AND deleted IS NULL;
```

### 76. User List and Configuration

```sql
SHOW USERS;
```

```sql
-- Detailed user info from ACCOUNT_USAGE
SELECT name, login_name, display_name, email,
       default_warehouse, default_namespace, default_role,
       created_on, last_success_login, disabled, locked,
       has_rsa_public_key, ext_authn_duo, ext_authn_uid
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE deleted_on IS NULL
ORDER BY last_success_login DESC NULLS LAST;
```

### 77. Grants on a Specific Object

```sql
SHOW GRANTS ON TABLE my_database.public.orders;
```

```sql
SHOW GRANTS ON DATABASE analytics;
```

```sql
SHOW GRANTS ON WAREHOUSE analytics_wh;
```

## Dynamic Table Diagnostics

### 78. Dynamic Table Refresh History

```sql
SELECT name, schema_name, database_name,
       refresh_start_time, refresh_end_time,
       DATEDIFF(second, refresh_start_time, refresh_end_time) AS duration_sec,
       refresh_action, statistics
FROM SNOWFLAKE.ACCOUNT_USAGE.DYNAMIC_TABLE_REFRESH_HISTORY
WHERE refresh_start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY refresh_start_time DESC
LIMIT 50;
```

### 79. Dynamic Table Lag Status

```sql
SHOW DYNAMIC TABLES;
```

```sql
-- Check refresh lag against target
SHOW DYNAMIC TABLES LIKE '%customer%' IN DATABASE analytics;
```

### 80. Dynamic Table Graph Dependencies

```sql
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.DYNAMIC_TABLE_GRAPH_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;
```

## Materialized View Diagnostics

### 81. Materialized View Refresh History

```sql
SELECT DATE_TRUNC('day', start_time) AS day,
       table_name,
       SUM(credits_used) AS credits,
       SUM(num_bytes_reclustered) / POWER(1024, 3) AS gb_refreshed,
       COUNT(*) AS refresh_count
FROM SNOWFLAKE.ACCOUNT_USAGE.MATERIALIZED_VIEW_REFRESH_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, table_name
ORDER BY credits DESC;
```

### 82. List Materialized Views

```sql
SHOW MATERIALIZED VIEWS IN DATABASE analytics;
```

## Time Travel Diagnostics

### 83. Time Travel Usage by Table

```sql
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME,
       ACTIVE_BYTES / POWER(1024, 3) AS active_gb,
       TIME_TRAVEL_BYTES / POWER(1024, 3) AS time_travel_gb,
       FAILSAFE_BYTES / POWER(1024, 3) AS failsafe_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE TIME_TRAVEL_BYTES > 0
ORDER BY TIME_TRAVEL_BYTES DESC
LIMIT 25;
```

### 84. Time Travel Retention Settings

```sql
SHOW PARAMETERS LIKE 'DATA_RETENTION_TIME_IN_DAYS' IN TABLE my_table;
```

```sql
SHOW PARAMETERS LIKE 'DATA_RETENTION_TIME_IN_DAYS' IN DATABASE my_database;
```

### 85. Query Data at a Historical Point

```sql
-- By timestamp
SELECT COUNT(*) FROM orders AT(TIMESTAMP => '2026-04-06 10:00:00'::TIMESTAMP_LTZ);

-- By time offset (seconds)
SELECT COUNT(*) FROM orders AT(OFFSET => -3600);

-- By statement ID
SELECT COUNT(*) FROM orders BEFORE(STATEMENT => '01a6b3c7-0000-1234-0000-000500000000');
```

### 86. Identify Dropped Objects (Recoverable)

```sql
-- Dropped tables
SHOW TABLES HISTORY IN DATABASE my_database;

-- Dropped schemas
SHOW SCHEMAS HISTORY IN DATABASE my_database;

-- Dropped databases
SHOW DATABASES HISTORY;
```

## Cost Analysis Queries

### 87. Total Cost Breakdown (Last 30 Days)

```sql
-- Warehouse credits
SELECT 'Warehouse Compute' AS cost_category,
       SUM(credits_used) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())

UNION ALL

-- Automatic clustering credits
SELECT 'Automatic Clustering',
       SUM(credits_used)
FROM SNOWFLAKE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())

UNION ALL

-- Materialized view maintenance credits
SELECT 'Materialized View Maintenance',
       SUM(credits_used)
FROM SNOWFLAKE.ACCOUNT_USAGE.MATERIALIZED_VIEW_REFRESH_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())

UNION ALL

-- Search optimization credits
SELECT 'Search Optimization',
       SUM(credits_used)
FROM SNOWFLAKE.ACCOUNT_USAGE.SEARCH_OPTIMIZATION_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())

UNION ALL

-- Snowpipe credits
SELECT 'Snowpipe',
       SUM(credits_used)
FROM SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())

UNION ALL

-- Replication credits
SELECT 'Replication',
       SUM(credits_used)
FROM SNOWFLAKE.ACCOUNT_USAGE.REPLICATION_USAGE_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())

UNION ALL

-- Serverless task credits
SELECT 'Serverless Tasks',
       SUM(credits_used)
FROM SNOWFLAKE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())

ORDER BY total_credits DESC;
```

### 88. Daily Cost Trend

```sql
SELECT DATE_TRUNC('day', start_time) AS day,
       SUM(credits_used) AS warehouse_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day
ORDER BY day DESC;
```

### 89. Cost per Query (Approximate)

```sql
-- Approximate credits per query based on warehouse size and execution time
SELECT query_id, SUBSTR(query_text, 1, 200) AS query_preview,
       user_name, warehouse_name, warehouse_size,
       execution_time / 1000 AS exec_sec,
       CASE warehouse_size
           WHEN 'X-Small' THEN 1
           WHEN 'Small' THEN 2
           WHEN 'Medium' THEN 4
           WHEN 'Large' THEN 8
           WHEN 'X-Large' THEN 16
           WHEN '2X-Large' THEN 32
           WHEN '3X-Large' THEN 64
           WHEN '4X-Large' THEN 128
           ELSE 0
       END * (execution_time / 3600000.0) AS approx_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND warehouse_size IS NOT NULL
ORDER BY approx_credits DESC
LIMIT 50;
```

### 90. Credit Consumption by Role

```sql
SELECT r.value:roleName::STRING AS role_name,
       COUNT(*) AS query_count,
       SUM(qh.execution_time) / 1000 AS total_exec_sec
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh,
LATERAL FLATTEN(input => PARSE_JSON('[{"roleName":"' || qh.role_name || '"}]')) r
WHERE qh.start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
  AND qh.warehouse_name IS NOT NULL
GROUP BY role_name
ORDER BY total_exec_sec DESC;
```

### 91. Cloud Services Credits Analysis

```sql
SELECT DATE_TRUNC('day', start_time) AS day,
       SUM(credits_used_compute) AS compute_credits,
       SUM(credits_used_cloud_services) AS cloud_services_credits,
       ROUND(SUM(credits_used_cloud_services) / NULLIF(SUM(credits_used_compute), 0) * 100, 2) AS cs_pct_of_compute
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day
ORDER BY day DESC;
```

## SHOW Commands Reference

### 92. Database and Schema Discovery

```sql
SHOW DATABASES;
SHOW SCHEMAS IN DATABASE my_database;
SHOW TABLES IN SCHEMA my_database.public;
SHOW VIEWS IN SCHEMA my_database.public;
SHOW COLUMNS IN TABLE my_database.public.orders;
```

### 93. Warehouse Discovery

```sql
SHOW WAREHOUSES;
SHOW PARAMETERS IN WAREHOUSE my_wh;
SHOW RESOURCE MONITORS;
```

### 94. Security Discovery

```sql
SHOW ROLES;
SHOW USERS;
SHOW GRANTS TO USER my_user;
SHOW GRANTS TO ROLE my_role;
SHOW GRANTS ON DATABASE my_database;
SHOW NETWORK POLICIES;
SHOW MASKING POLICIES;
SHOW ROW ACCESS POLICIES;
```

### 95. Integration Discovery

```sql
SHOW INTEGRATIONS;
SHOW STORAGE INTEGRATIONS;
SHOW NOTIFICATION INTEGRATIONS;
SHOW SECURITY INTEGRATIONS;
```

### 96. Object Discovery

```sql
SHOW STAGES IN DATABASE my_database;
SHOW PIPES IN DATABASE my_database;
SHOW STREAMS IN DATABASE my_database;
SHOW TASKS IN DATABASE my_database;
SHOW FILE FORMATS IN DATABASE my_database;
SHOW SEQUENCES IN DATABASE my_database;
SHOW PROCEDURES IN DATABASE my_database;
SHOW USER FUNCTIONS IN DATABASE my_database;
SHOW EXTERNAL FUNCTIONS IN DATABASE my_database;
SHOW SHARES;
SHOW DYNAMIC TABLES IN DATABASE my_database;
SHOW ALERTS IN DATABASE my_database;
```

## SYSTEM$ Functions

### 97. Clustering Information

```sql
SELECT SYSTEM$CLUSTERING_INFORMATION('my_table');
SELECT SYSTEM$CLUSTERING_INFORMATION('my_table', '(col1, col2)');
```

### 98. Pipe Status

```sql
SELECT SYSTEM$PIPE_STATUS('my_pipe');
```

### 99. Stream Has Data

```sql
SELECT SYSTEM$STREAM_HAS_DATA('my_stream');
```

### 100. Warehouse Compute Cluster Status

```sql
SELECT SYSTEM$WAREHOUSE_COMPUTE_CLUSTER_STATUS('my_warehouse');
```

### 101. Cancel a Running Query

```sql
SELECT SYSTEM$CANCEL_QUERY('query-id-here');
```

### 102. Cancel All Queries for a Session

```sql
SELECT SYSTEM$CANCEL_ALL_QUERIES(12345678901234);  -- session_id
```

### 103. Explain Plan as JSON

```sql
SELECT SYSTEM$EXPLAIN_PLAN_JSON('SELECT * FROM orders WHERE region = ''US''');
```

### 104. Last Query ID

```sql
SELECT LAST_QUERY_ID();
SELECT LAST_QUERY_ID(-2);  -- second-to-last query
```

## Replication Diagnostics

### 105. Replication Usage History

```sql
SELECT DATE_TRUNC('day', start_time) AS day,
       database_name,
       SUM(credits_used) AS credits,
       SUM(bytes_transferred) / POWER(1024, 3) AS gb_transferred
FROM SNOWFLAKE.ACCOUNT_USAGE.REPLICATION_USAGE_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, database_name
ORDER BY day DESC;
```

### 106. Database Replication Status

```sql
SHOW REPLICATION DATABASES;
```

```sql
-- Check replication lag
SELECT database_name, snowflake_region, created_on, is_primary,
       replication_allowed_to_accounts
FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASES
WHERE is_primary = FALSE;
```

### 107. Failover Group Status

```sql
SHOW FAILOVER GROUPS;
```

## Data Sharing Diagnostics

### 108. List Shares (Outbound)

```sql
SHOW SHARES;
```

### 109. Listing Usage (Consumer Side)

```sql
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_TRANSFER_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;
```

### 110. Share Access History

```sql
SELECT listing_name, query_date, provider_account,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.DATA_SHARING_USAGE.LISTING_USAGE_HISTORY
WHERE query_date > DATEADD(day, -30, CURRENT_DATE())
GROUP BY listing_name, query_date, provider_account
ORDER BY query_date DESC;
```

## Health Check Scripts

### 111. Comprehensive Account Health Check

```sql
-- Run as ACCOUNTADMIN

-- 1. Credit consumption (last 7 days)
SELECT 'CREDIT USAGE (7d)' AS check_name,
       SUM(credits_used)::VARCHAR AS value
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())

UNION ALL

-- 2. Storage size
SELECT 'STORAGE (TB)',
       ROUND(MAX(STORAGE_BYTES + STAGE_BYTES + FAILSAFE_BYTES) / POWER(1024, 4), 3)::VARCHAR
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
WHERE USAGE_DATE > DATEADD(day, -2, CURRENT_DATE())

UNION ALL

-- 3. Failed queries (last 24h)
SELECT 'FAILED QUERIES (24h)',
       COUNT(*)::VARCHAR
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -1, CURRENT_TIMESTAMP())
  AND execution_status = 'FAIL'

UNION ALL

-- 4. Failed logins (last 24h)
SELECT 'FAILED LOGINS (24h)',
       COUNT(*)::VARCHAR
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp > DATEADD(day, -1, CURRENT_TIMESTAMP())
  AND is_success = 'NO'

UNION ALL

-- 5. Queued queries (last 24h)
SELECT 'QUEUED QUERIES (24h)',
       COUNT(*)::VARCHAR
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -1, CURRENT_TIMESTAMP())
  AND queued_overload_time > 5000

UNION ALL

-- 6. Failed tasks (last 24h)
SELECT 'FAILED TASKS (24h)',
       COUNT(*)::VARCHAR
FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
WHERE scheduled_time > DATEADD(day, -1, CURRENT_TIMESTAMP())
  AND state = 'FAILED'

UNION ALL

-- 7. Failed data loads (last 24h)
SELECT 'FAILED LOADS (24h)',
       COUNT(*)::VARCHAR
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE last_load_time > DATEADD(day, -1, CURRENT_TIMESTAMP())
  AND STATUS = 'LOAD_FAILED';
```

### 112. Warehouse Sizing Recommendation

```sql
-- Identify warehouses that are consistently too small (frequent spilling)
SELECT warehouse_name, warehouse_size,
       COUNT(*) AS spilling_queries,
       AVG(bytes_spilled_to_local_storage) / POWER(1024, 3) AS avg_local_spill_gb,
       AVG(bytes_spilled_to_remote_storage) / POWER(1024, 3) AS avg_remote_spill_gb,
       AVG(execution_time) / 1000 AS avg_exec_sec
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
GROUP BY warehouse_name, warehouse_size
HAVING spilling_queries > 10
ORDER BY avg_remote_spill_gb DESC;
```

### 113. Identify Idle Warehouses (Cost Waste)

```sql
-- Warehouses with very low utilization
SELECT wh.warehouse_name,
       wh.credits AS total_credits_7d,
       wh.query_count,
       ROUND(wh.credits / NULLIF(wh.query_count, 0), 4) AS credits_per_query
FROM (
    SELECT warehouse_name,
           SUM(credits_used) AS credits,
           0 AS query_count
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
    GROUP BY warehouse_name
) wh
LEFT JOIN (
    SELECT warehouse_name, COUNT(*) AS qc
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
    GROUP BY warehouse_name
) qh ON wh.warehouse_name = qh.warehouse_name
ORDER BY wh.credits DESC;
```

### 114. Unused Tables (No Queries in 30 Days)

```sql
-- Tables with no SELECT access in 30 days
WITH accessed_tables AS (
    SELECT DISTINCT
        base.value:objectName::STRING AS table_name
    FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY,
    LATERAL FLATTEN(input => base_objects_accessed) base
    WHERE query_start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
)
SELECT t.TABLE_CATALOG, t.TABLE_SCHEMA, t.TABLE_NAME,
       t.ROW_COUNT, t.BYTES / POWER(1024, 3) AS size_gb
FROM INFORMATION_SCHEMA.TABLES t
LEFT JOIN accessed_tables a ON a.table_name ILIKE t.TABLE_CATALOG || '.' || t.TABLE_SCHEMA || '.' || t.TABLE_NAME
WHERE a.table_name IS NULL
  AND t.TABLE_TYPE = 'BASE TABLE'
  AND t.TABLE_SCHEMA != 'INFORMATION_SCHEMA'
  AND t.BYTES > 0
ORDER BY t.BYTES DESC
LIMIT 50;
```

### 115. Auto-Suspend Audit

```sql
-- Find warehouses with suboptimal auto-suspend settings
SELECT "name" AS warehouse_name,
       "size" AS warehouse_size,
       "auto_suspend" AS auto_suspend_seconds,
       "auto_resume" AS auto_resume,
       "min_cluster_count" AS min_clusters,
       "max_cluster_count" AS max_clusters,
       CASE
           WHEN "auto_suspend" IS NULL OR "auto_suspend" = 0 THEN 'WARNING: Never auto-suspends'
           WHEN "auto_suspend" > 600 THEN 'REVIEW: Long auto-suspend (>10min)'
           WHEN "auto_suspend" < 60 THEN 'OK: Aggressive suspend'
           ELSE 'OK'
       END AS recommendation
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))  -- run after SHOW WAREHOUSES
ORDER BY auto_suspend_seconds DESC NULLS FIRST;
```

**Note:** Run `SHOW WAREHOUSES;` first, then run this query against the result.

### 116. Security Audit: Users Without MFA

```sql
SELECT name, login_name, email, created_on, last_success_login,
       ext_authn_duo, has_rsa_public_key
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE deleted_on IS NULL
  AND ext_authn_duo = FALSE
  AND has_rsa_public_key = FALSE
  AND name NOT LIKE 'SVC_%'  -- exclude service accounts
ORDER BY last_success_login DESC NULLS LAST;
```

### 117. Stale Users (No Login in 90 Days)

```sql
SELECT name, login_name, email, created_on, last_success_login,
       default_role, disabled
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE deleted_on IS NULL
  AND disabled = FALSE
  AND (last_success_login IS NULL OR last_success_login < DATEADD(day, -90, CURRENT_TIMESTAMP()))
ORDER BY last_success_login ASC NULLS FIRST;
```

### 118. Excessive Privileges Audit

```sql
-- Users/roles with direct ACCOUNTADMIN
SELECT grantee_name, role, granted_by, created_on
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE role = 'ACCOUNTADMIN' AND deleted_on IS NULL

UNION ALL

SELECT grantee_name, role, granted_by, created_on
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE role = 'ACCOUNTADMIN' AND deleted_on IS NULL;
```

### 119. Query Tag Analysis (for Cost Attribution)

```sql
SELECT query_tag,
       COUNT(*) AS query_count,
       SUM(execution_time) / 1000 AS total_exec_sec,
       SUM(bytes_scanned) / POWER(1024, 4) AS total_tb_scanned,
       SUM(credits_used_cloud_services) AS cloud_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
  AND query_tag IS NOT NULL AND query_tag != ''
GROUP BY query_tag
ORDER BY total_exec_sec DESC
LIMIT 25;
```

### 120. External Functions and Integrations Audit

```sql
SHOW EXTERNAL FUNCTIONS;
SHOW API INTEGRATIONS;
SHOW STORAGE INTEGRATIONS;
SHOW NOTIFICATION INTEGRATIONS;
```

### 121. Clone Storage Consumption

```sql
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME,
       CLONE_BYTES / POWER(1024, 3) AS clone_gb,
       ACTIVE_BYTES / POWER(1024, 3) AS active_gb,
       ROUND(CLONE_BYTES::FLOAT / NULLIF(ACTIVE_BYTES, 0) * 100, 2) AS clone_pct_of_active
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE CLONE_BYTES > 0
ORDER BY CLONE_BYTES DESC
LIMIT 25;
```

### 122. Snowpipe Latency Analysis

```sql
SELECT pipe_catalog_name, pipe_schema_name, pipe_name,
       DATE_TRUNC('hour', last_load_time) AS hour,
       COUNT(*) AS files_loaded,
       AVG(DATEDIFF(second, stage_location, last_load_time)) AS avg_latency_sec,
       SUM(row_count) AS total_rows
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE last_load_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND pipe_catalog_name IS NOT NULL
GROUP BY pipe_catalog_name, pipe_schema_name, pipe_name, hour
ORDER BY hour DESC;
```

### 123. Search Optimization Cost Analysis

```sql
SELECT table_name,
       SUM(credits_used) AS total_credits,
       SUM(num_bytes_persisted) / POWER(1024, 3) AS gb_persisted,
       COUNT(*) AS maintenance_events
FROM SNOWFLAKE.ACCOUNT_USAGE.SEARCH_OPTIMIZATION_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY table_name
ORDER BY total_credits DESC
LIMIT 20;
```

### 124. Data Transfer History

```sql
SELECT DATE_TRUNC('day', start_time) AS day,
       source_cloud, source_region,
       target_cloud, target_region,
       transfer_type,
       SUM(bytes_transferred) / POWER(1024, 3) AS gb_transferred
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_TRANSFER_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, source_cloud, source_region, target_cloud, target_region, transfer_type
ORDER BY day DESC, gb_transferred DESC;
```

### 125. Cortex AI/ML Usage

```sql
-- Track Cortex function usage through query history
SELECT SUBSTR(query_text, 1, 200) AS query_preview,
       user_name, warehouse_name,
       execution_time / 1000 AS exec_sec,
       start_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND (query_text ILIKE '%SNOWFLAKE.CORTEX.COMPLETE%'
    OR query_text ILIKE '%SNOWFLAKE.CORTEX.SENTIMENT%'
    OR query_text ILIKE '%SNOWFLAKE.CORTEX.SUMMARIZE%'
    OR query_text ILIKE '%SNOWFLAKE.CORTEX.TRANSLATE%'
    OR query_text ILIKE '%SNOWFLAKE.CORTEX.EMBED_TEXT%')
ORDER BY start_time DESC;
```

### 126. Session Variable and Parameter Check

```sql
-- Check all non-default session parameters
SHOW PARAMETERS IN SESSION;
```

```sql
-- Check specific commonly-tuned parameters
SELECT $1 AS parameter_name, $2 AS value
FROM (VALUES
    ('TIMEZONE', CURRENT_TIMESTAMP()::VARCHAR),
    ('QUERY_TAG', ''),
    ('USE_CACHED_RESULT', 'true')
);
```

### 127. Long-Running Transactions

```sql
SELECT query_id, session_id, user_name,
       start_time,
       DATEDIFF(minute, start_time, CURRENT_TIMESTAMP()) AS running_minutes,
       SUBSTR(query_text, 1, 200) AS query_preview
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE execution_status = 'RUNNING'
  AND DATEDIFF(minute, start_time, CURRENT_TIMESTAMP()) > 30
ORDER BY start_time ASC;
```

### 128. Table DDL Reconstruction

```sql
SELECT GET_DDL('TABLE', 'my_database.public.orders');
```

```sql
-- For views, procedures, functions
SELECT GET_DDL('VIEW', 'my_database.public.my_view');
SELECT GET_DDL('PROCEDURE', 'my_database.public.my_proc(VARCHAR)');
SELECT GET_DDL('FUNCTION', 'my_database.public.my_udf(NUMBER)');
```

### 129. Object Dependencies

```sql
SELECT referencing_database, referencing_schema, referencing_object_name, referencing_object_type,
       referenced_database, referenced_schema, referenced_object_name, referenced_object_type
FROM SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES
WHERE referenced_object_name = 'ORDERS'
ORDER BY referencing_object_name;
```

### 130. Account-Level Metering Summary (All Services)

```sql
SELECT DATE_TRUNC('day', usage_date) AS day,
       service_type,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE usage_date > DATEADD(day, -30, CURRENT_DATE())
GROUP BY day, service_type
ORDER BY day DESC, credits DESC;
```

### 131. Warehouse Metering at Minute Granularity

```sql
-- High-resolution view for recent activity
SELECT start_time, end_time, warehouse_name,
       credits_used, credits_used_compute, credits_used_cloud_services
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(hour, -6, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;
```

### 132. Tag-Based Cost Attribution

```sql
-- If using query tags for cost attribution
SELECT query_tag,
       warehouse_name,
       COUNT(*) AS query_count,
       SUM(execution_time) / 3600000.0 AS total_exec_hours,
       SUM(CASE warehouse_size
           WHEN 'X-Small' THEN 1
           WHEN 'Small' THEN 2
           WHEN 'Medium' THEN 4
           WHEN 'Large' THEN 8
           WHEN 'X-Large' THEN 16
           ELSE 0
       END * (execution_time / 3600000.0)) AS approx_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
  AND query_tag IS NOT NULL AND query_tag != ''
  AND warehouse_size IS NOT NULL
GROUP BY query_tag, warehouse_name
ORDER BY approx_credits DESC
LIMIT 25;
```
