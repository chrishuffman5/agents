# Azure Synapse Analytics Diagnostics Reference

## Dedicated SQL Pool DMVs

### Query Execution Analysis

#### sys.dm_pdw_exec_requests -- All Requests

```sql
-- 1. Active and recently completed requests
SELECT
    request_id,
    session_id,
    status,
    submit_time,
    start_time,
    end_time,
    total_elapsed_time / 1000.0 AS elapsed_sec,
    command,
    resource_class,
    importance,
    group_name AS workload_group,
    classifier_name,
    result_cache_hit,
    label
FROM sys.dm_pdw_exec_requests
WHERE status IN ('Running', 'Suspended', 'Completed')
    AND submit_time > DATEADD(hour, -4, GETDATE())
ORDER BY submit_time DESC;
```

```sql
-- 2. Long-running active queries (> 5 minutes)
SELECT
    request_id,
    session_id,
    status,
    submit_time,
    total_elapsed_time / 60000.0 AS elapsed_min,
    LEFT(command, 200) AS command_preview,
    resource_class,
    importance,
    group_name AS workload_group
FROM sys.dm_pdw_exec_requests
WHERE status = 'Running'
    AND total_elapsed_time > 300000  -- 5 minutes
ORDER BY total_elapsed_time DESC;
```

```sql
-- 3. Queued requests waiting for resources
SELECT
    request_id,
    session_id,
    status,
    submit_time,
    DATEDIFF(second, submit_time, GETDATE()) AS queued_sec,
    resource_class,
    importance,
    group_name AS workload_group,
    LEFT(command, 200) AS command_preview
FROM sys.dm_pdw_exec_requests
WHERE status = 'Suspended'
ORDER BY submit_time ASC;
```

```sql
-- 4. Query performance summary by resource class (last 24h)
SELECT
    resource_class,
    COUNT(*) AS query_count,
    AVG(total_elapsed_time) / 1000.0 AS avg_elapsed_sec,
    MAX(total_elapsed_time) / 1000.0 AS max_elapsed_sec,
    SUM(CASE WHEN result_cache_hit = 1 THEN 1 ELSE 0 END) AS cache_hits,
    SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) AS failures
FROM sys.dm_pdw_exec_requests
WHERE submit_time > DATEADD(hour, -24, GETDATE())
    AND command NOT LIKE '%dm_pdw%'  -- exclude monitoring queries
GROUP BY resource_class
ORDER BY query_count DESC;
```

```sql
-- 5. Result set cache hit ratio
SELECT
    CASE WHEN result_cache_hit = 1 THEN 'Cache Hit' ELSE 'Cache Miss' END AS cache_status,
    COUNT(*) AS query_count,
    AVG(total_elapsed_time) / 1000.0 AS avg_elapsed_sec
FROM sys.dm_pdw_exec_requests
WHERE status = 'Completed'
    AND submit_time > DATEADD(hour, -24, GETDATE())
    AND resource_class IS NOT NULL
GROUP BY result_cache_hit;
```

```sql
-- 6. Failed queries with error details
SELECT
    r.request_id,
    r.session_id,
    r.submit_time,
    r.total_elapsed_time / 1000.0 AS elapsed_sec,
    r.error_id,
    LEFT(r.command, 300) AS command_preview,
    e.error_id,
    e.severity,
    e.error_state,
    LEFT(e.message, 500) AS error_message
FROM sys.dm_pdw_exec_requests r
LEFT JOIN sys.dm_pdw_errors e ON r.error_id = e.error_id
WHERE r.status = 'Failed'
    AND r.submit_time > DATEADD(hour, -24, GETDATE())
ORDER BY r.submit_time DESC;
```

#### sys.dm_pdw_request_steps -- Query Plan Steps

```sql
-- 7. Execution steps for a specific query
SELECT
    request_id,
    step_index,
    operation_type,
    location_type,
    distribution_type,
    status,
    total_elapsed_time / 1000.0 AS elapsed_sec,
    row_count,
    estimated_rows,
    command
FROM sys.dm_pdw_request_steps
WHERE request_id = 'QID12345'
ORDER BY step_index;
```

```sql
-- 8. Find data movement steps (DMS) in recent queries
SELECT
    r.request_id,
    s.step_index,
    s.operation_type,
    s.distribution_type,
    s.total_elapsed_time / 1000.0 AS elapsed_sec,
    s.row_count,
    LEFT(r.command, 200) AS query
FROM sys.dm_pdw_exec_requests r
JOIN sys.dm_pdw_request_steps s ON r.request_id = s.request_id
WHERE s.operation_type IN ('ShuffleMove', 'BroadcastMove', 'TrimMove', 'PartitionMove')
    AND r.submit_time > DATEADD(hour, -4, GETDATE())
ORDER BY s.total_elapsed_time DESC;
```

```sql
-- 9. Most expensive query steps (by elapsed time)
SELECT TOP 20
    r.request_id,
    s.step_index,
    s.operation_type,
    s.total_elapsed_time / 1000.0 AS elapsed_sec,
    s.row_count,
    LEFT(r.command, 200) AS query
FROM sys.dm_pdw_exec_requests r
JOIN sys.dm_pdw_request_steps s ON r.request_id = s.request_id
WHERE r.status = 'Completed'
    AND r.submit_time > DATEADD(hour, -24, GETDATE())
ORDER BY s.total_elapsed_time DESC;
```

```sql
-- 10. Data movement volume per query
SELECT
    r.request_id,
    SUM(s.row_count) AS total_rows_moved,
    COUNT(*) AS dms_steps,
    SUM(s.total_elapsed_time) / 1000.0 AS total_dms_sec,
    LEFT(r.command, 200) AS query
FROM sys.dm_pdw_exec_requests r
JOIN sys.dm_pdw_request_steps s ON r.request_id = s.request_id
WHERE s.operation_type IN ('ShuffleMove', 'BroadcastMove', 'TrimMove')
    AND r.submit_time > DATEADD(hour, -24, GETDATE())
GROUP BY r.request_id, LEFT(r.command, 200)
HAVING SUM(s.row_count) > 1000000
ORDER BY total_rows_moved DESC;
```

#### sys.dm_pdw_sql_requests -- Per-Distribution SQL

```sql
-- 11. Per-distribution execution for a specific step
SELECT
    request_id,
    step_index,
    pdw_node_id,
    distribution_id,
    status,
    total_elapsed_time / 1000.0 AS elapsed_sec,
    row_count,
    spid
FROM sys.dm_pdw_sql_requests
WHERE request_id = 'QID12345'
    AND step_index = 2
ORDER BY total_elapsed_time DESC;
```

```sql
-- 12. Distribution skew during query execution (find hot distributions)
SELECT
    request_id,
    step_index,
    MIN(total_elapsed_time) / 1000.0 AS min_dist_sec,
    MAX(total_elapsed_time) / 1000.0 AS max_dist_sec,
    AVG(total_elapsed_time) / 1000.0 AS avg_dist_sec,
    MAX(total_elapsed_time) * 1.0 / NULLIF(AVG(total_elapsed_time), 0) AS skew_factor,
    MAX(row_count) AS max_rows,
    MIN(row_count) AS min_rows,
    AVG(row_count) AS avg_rows
FROM sys.dm_pdw_sql_requests
WHERE request_id = 'QID12345'
    AND step_index = 2
GROUP BY request_id, step_index;
```

#### sys.dm_pdw_dms_workers -- DMS Worker Details

```sql
-- 13. DMS worker details for a specific step
SELECT
    request_id,
    step_index,
    dms_step_index,
    pdw_node_id,
    distribution_id,
    type,
    status,
    bytes_processed,
    rows_processed,
    total_elapsed_time / 1000.0 AS elapsed_sec
FROM sys.dm_pdw_dms_workers
WHERE request_id = 'QID12345'
    AND step_index = 2
ORDER BY bytes_processed DESC;
```

```sql
-- 14. Top DMS operations by bytes moved (last 24h)
SELECT TOP 20
    w.request_id,
    w.step_index,
    s.operation_type,
    SUM(w.bytes_processed) / 1048576.0 AS total_mb_moved,
    SUM(w.rows_processed) AS total_rows,
    MAX(w.total_elapsed_time) / 1000.0 AS max_worker_sec
FROM sys.dm_pdw_dms_workers w
JOIN sys.dm_pdw_request_steps s ON w.request_id = s.request_id AND w.step_index = s.step_index
JOIN sys.dm_pdw_exec_requests r ON w.request_id = r.request_id
WHERE r.submit_time > DATEADD(hour, -24, GETDATE())
GROUP BY w.request_id, w.step_index, s.operation_type
ORDER BY total_mb_moved DESC;
```

### Wait Statistics

#### sys.dm_pdw_waits -- Query Waits

```sql
-- 15. Active waits
SELECT
    request_id,
    session_id,
    type,
    state,
    object_type,
    object_name,
    DATEDIFF(second, request_time, GETDATE()) AS wait_sec
FROM sys.dm_pdw_waits
WHERE state = 'Granted' OR state = 'Queued'
ORDER BY request_time ASC;
```

```sql
-- 16. Concurrency waits (queries waiting for slots)
SELECT
    w.request_id,
    w.session_id,
    w.type,
    w.state,
    DATEDIFF(second, w.request_time, GETDATE()) AS wait_sec,
    r.resource_class,
    r.importance,
    LEFT(r.command, 200) AS command_preview
FROM sys.dm_pdw_waits w
JOIN sys.dm_pdw_exec_requests r ON w.request_id = r.request_id
WHERE w.type = 'Concurrency'
    AND w.state = 'Queued'
ORDER BY wait_sec DESC;
```

```sql
-- 17. Lock waits
SELECT
    w.request_id,
    w.session_id,
    w.type,
    w.object_type,
    w.object_name,
    DATEDIFF(second, w.request_time, GETDATE()) AS wait_sec,
    LEFT(r.command, 200) AS command_preview
FROM sys.dm_pdw_waits w
JOIN sys.dm_pdw_exec_requests r ON w.request_id = r.request_id
WHERE w.type LIKE '%Lock%'
ORDER BY wait_sec DESC;
```

### Node and Distribution Analysis

#### sys.dm_pdw_nodes -- Compute Nodes

```sql
-- 18. List all nodes
SELECT
    pdw_node_id,
    type,
    name,
    address,
    is_passive
FROM sys.dm_pdw_nodes
ORDER BY pdw_node_id;
```

#### sys.dm_pdw_node_status -- Node Health

```sql
-- 19. Node status and resource utilization
SELECT
    pdw_node_id,
    node_id,
    process_id,
    process_name,
    allocated_memory,
    available_memory,
    process_cpu_usage,
    total_cpu_usage,
    active_requests
FROM sys.dm_pdw_node_status
ORDER BY pdw_node_id;
```

```sql
-- 20. Nodes with high CPU or memory pressure
SELECT
    pdw_node_id,
    total_cpu_usage,
    active_requests,
    allocated_memory,
    available_memory,
    CAST(available_memory * 100.0 / NULLIF(allocated_memory, 0) AS DECIMAL(5,2)) AS memory_free_pct
FROM sys.dm_pdw_node_status
WHERE total_cpu_usage > 80
    OR (available_memory * 100.0 / NULLIF(allocated_memory, 0)) < 20
ORDER BY total_cpu_usage DESC;
```

### Distribution Analysis and Data Skew

```sql
-- 21. Table space usage across distributions
DBCC PDW_SHOWSPACEUSED('dbo.fact_sales');
```

```sql
-- 22. Data skew analysis for all hash-distributed tables
SELECT
    t.name AS table_name,
    d.distribution_id,
    d.row_count,
    d.reserved_space_MB
FROM (
    SELECT
        object_id,
        distribution_id,
        SUM(row_count) AS row_count,
        SUM(reserved_page_count) * 8.0 / 1024 AS reserved_space_MB
    FROM sys.dm_pdw_nodes_db_partition_stats
    WHERE index_id <= 1
    GROUP BY object_id, distribution_id
) d
JOIN sys.tables t ON d.object_id = t.object_id
ORDER BY t.name, d.distribution_id;
```

```sql
-- 23. Skew factor for all tables (MAX/AVG rows)
SELECT
    t.name AS table_name,
    i.distribution_policy_desc,
    MAX(ps.row_count) AS max_dist_rows,
    MIN(ps.row_count) AS min_dist_rows,
    AVG(ps.row_count) AS avg_dist_rows,
    SUM(ps.row_count) AS total_rows,
    CASE
        WHEN AVG(ps.row_count) = 0 THEN 0
        ELSE CAST(MAX(ps.row_count) * 1.0 / AVG(ps.row_count) AS DECIMAL(10,2))
    END AS skew_factor
FROM (
    SELECT
        object_id,
        distribution_id,
        SUM(row_count) AS row_count
    FROM sys.dm_pdw_nodes_db_partition_stats
    WHERE index_id <= 1
    GROUP BY object_id, distribution_id
) ps
JOIN sys.tables t ON ps.object_id = t.object_id
JOIN sys.pdw_table_distribution_properties i ON t.object_id = i.object_id
GROUP BY t.name, i.distribution_policy_desc
HAVING SUM(ps.row_count) > 0
ORDER BY skew_factor DESC;
```

```sql
-- 24. Top skewed tables (skew factor > 1.1)
SELECT
    t.name AS table_name,
    MAX(ps.row_count) AS max_rows,
    MIN(ps.row_count) AS min_rows,
    CAST(MAX(ps.row_count) * 1.0 / NULLIF(AVG(ps.row_count), 0) AS DECIMAL(10,4)) AS skew_factor,
    SUM(ps.row_count) AS total_rows
FROM (
    SELECT object_id, distribution_id, SUM(row_count) AS row_count
    FROM sys.dm_pdw_nodes_db_partition_stats
    WHERE index_id <= 1
    GROUP BY object_id, distribution_id
) ps
JOIN sys.tables t ON ps.object_id = t.object_id
GROUP BY t.name
HAVING CAST(MAX(ps.row_count) * 1.0 / NULLIF(AVG(ps.row_count), 0) AS DECIMAL(10,4)) > 1.10
    AND SUM(ps.row_count) > 100000
ORDER BY skew_factor DESC;
```

```sql
-- 25. Distribution column identification
SELECT
    t.name AS table_name,
    c.name AS distribution_column,
    ty.name AS data_type,
    dp.distribution_policy_desc
FROM sys.tables t
JOIN sys.pdw_table_distribution_properties dp ON t.object_id = dp.object_id
LEFT JOIN sys.pdw_column_distribution_properties cdp ON t.object_id = cdp.object_id AND cdp.distribution_ordinal = 1
LEFT JOIN sys.columns c ON t.object_id = c.object_id AND cdp.column_id = c.column_id
LEFT JOIN sys.types ty ON c.user_type_id = ty.user_type_id
ORDER BY t.name;
```

### Storage and Table Sizing

```sql
-- 26. Table sizes with distribution and index info
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    dp.distribution_policy_desc AS distribution,
    i.type_desc AS index_type,
    SUM(ps.row_count) / 60 AS approx_rows,  -- divide by 60 (counts per distribution)
    SUM(ps.reserved_page_count) * 8 / 1024 AS reserved_mb,
    SUM(ps.used_page_count) * 8 / 1024 AS used_mb
FROM sys.dm_pdw_nodes_db_partition_stats ps
JOIN sys.tables t ON ps.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.pdw_table_distribution_properties dp ON t.object_id = dp.object_id
JOIN sys.indexes i ON t.object_id = i.object_id AND ps.index_id = i.index_id
WHERE ps.index_id <= 1
GROUP BY s.name, t.name, dp.distribution_policy_desc, i.type_desc
ORDER BY reserved_mb DESC;
```

```sql
-- 27. Database total size
SELECT
    SUM(reserved_page_count) * 8.0 / 1024 / 1024 AS total_reserved_gb,
    SUM(used_page_count) * 8.0 / 1024 / 1024 AS total_used_gb,
    COUNT(DISTINCT object_id) AS table_count
FROM sys.dm_pdw_nodes_db_partition_stats
WHERE index_id <= 1;
```

```sql
-- 28. Partition row counts per table
SELECT
    t.name AS table_name,
    p.partition_number,
    SUM(ps.row_count) / 60 AS approx_rows,
    SUM(ps.reserved_page_count) * 8 / 1024 AS reserved_mb
FROM sys.dm_pdw_nodes_db_partition_stats ps
JOIN sys.tables t ON ps.object_id = t.object_id
JOIN sys.partitions p ON t.object_id = p.object_id AND ps.partition_number = p.partition_number AND p.index_id <= 1
WHERE ps.index_id <= 1
GROUP BY t.name, p.partition_number
ORDER BY t.name, p.partition_number;
```

```sql
-- 29. Replicated table cache state
SELECT
    t.name AS table_name,
    cs.state AS cache_state,
    cs.is_data_movement_trigger_percentage_met
FROM sys.tables t
JOIN sys.pdw_replicated_table_cache_state cs ON t.object_id = cs.object_id
JOIN sys.pdw_table_distribution_properties dp ON t.object_id = dp.object_id
WHERE dp.distribution_policy_desc = 'REPLICATE'
ORDER BY t.name;
```

### Columnstore Health

```sql
-- 30. Columnstore row group quality
SELECT
    t.name AS table_name,
    rg.state_desc,
    COUNT(*) AS row_group_count,
    SUM(rg.total_rows) AS total_rows,
    AVG(rg.total_rows) AS avg_rows_per_group,
    SUM(CASE WHEN rg.total_rows < 100000 THEN 1 ELSE 0 END) AS small_row_groups,
    SUM(rg.deleted_rows) AS total_deleted_rows
FROM sys.dm_pdw_nodes_column_store_row_groups rg
JOIN sys.tables t ON rg.object_id = t.object_id
GROUP BY t.name, rg.state_desc
ORDER BY t.name, rg.state_desc;
```

```sql
-- 31. Tables with poor columnstore quality (many small row groups)
SELECT
    t.name AS table_name,
    COUNT(*) AS total_row_groups,
    SUM(CASE WHEN rg.total_rows < 100000 THEN 1 ELSE 0 END) AS small_groups,
    SUM(CASE WHEN rg.state_desc = 'OPEN' THEN 1 ELSE 0 END) AS open_groups,
    SUM(rg.deleted_rows) AS deleted_rows,
    CAST(SUM(CASE WHEN rg.total_rows < 100000 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS pct_small_groups
FROM sys.dm_pdw_nodes_column_store_row_groups rg
JOIN sys.tables t ON rg.object_id = t.object_id
WHERE rg.state_desc = 'COMPRESSED'
GROUP BY t.name
HAVING SUM(CASE WHEN rg.total_rows < 100000 THEN 1 ELSE 0 END) > 0
ORDER BY pct_small_groups DESC;
```

```sql
-- 32. Columnstore segment elimination effectiveness
SELECT
    t.name AS table_name,
    c.name AS column_name,
    seg.segment_id,
    seg.min_data_id,
    seg.max_data_id,
    seg.row_count,
    seg.on_disk_size / 1024 AS size_kb
FROM sys.dm_pdw_nodes_column_store_segments seg
JOIN sys.tables t ON seg.hobt_id = t.object_id
JOIN sys.columns c ON t.object_id = c.object_id AND seg.column_id = c.column_id
WHERE t.name = 'fact_sales'
    AND c.name = 'sale_date'
ORDER BY seg.segment_id;
```

### Materialized View Diagnostics

```sql
-- 33. Materialized view overhead
DBCC PDW_SHOWMATERIALIZEDVIEWOVERHEAD('dbo.mv_sales_daily');
```

```sql
-- 34. List all materialized views with metadata
SELECT
    s.name AS schema_name,
    o.name AS mv_name,
    o.create_date,
    o.modify_date
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.type = 'V'
    AND o.is_ms_shipped = 0
    AND EXISTS (
        SELECT 1 FROM sys.indexes i
        WHERE i.object_id = o.object_id AND i.type = 5  -- clustered columnstore
    );
```

```sql
-- 35. Check if queries are using materialized views (in query plan)
EXPLAIN
SELECT product_id, SUM(amount) AS total
FROM dbo.fact_sales
GROUP BY product_id;
-- Look for 'MaterializedViewRewrite' in the XML plan output
```

### Workload Management Diagnostics

```sql
-- 36. Workload group configuration
SELECT
    group_id,
    name,
    importance,
    min_percentage_resource,
    max_percentage_resource,
    request_min_resource_grant_percent,
    request_max_resource_grant_percent,
    cap_percentage_resource,
    query_execution_timeout_sec,
    effective_min_percentage_resource,
    effective_max_percentage_resource,
    effective_cap_percentage_resource
FROM sys.workload_management_workload_groups;
```

```sql
-- 37. Workload classifiers
SELECT
    c.classifier_id,
    c.name AS classifier_name,
    c.group_name AS workload_group,
    c.importance,
    c.member_name,
    c.label,
    c.context,
    c.start_time,
    c.end_time
FROM sys.workload_management_workload_classifiers c
ORDER BY c.group_name, c.name;
```

```sql
-- 38. Queries per workload group (last 24h)
SELECT
    group_name AS workload_group,
    classifier_name,
    importance,
    COUNT(*) AS query_count,
    AVG(total_elapsed_time) / 1000.0 AS avg_elapsed_sec,
    SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) AS failures,
    AVG(DATEDIFF(second, submit_time, start_time)) AS avg_queue_sec
FROM sys.dm_pdw_exec_requests
WHERE submit_time > DATEADD(hour, -24, GETDATE())
    AND group_name IS NOT NULL
GROUP BY group_name, classifier_name, importance
ORDER BY query_count DESC;
```

```sql
-- 39. Resource class usage breakdown
SELECT
    resource_class,
    COUNT(*) AS query_count,
    AVG(total_elapsed_time) / 1000.0 AS avg_elapsed_sec,
    MAX(total_elapsed_time) / 1000.0 AS max_elapsed_sec,
    SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) AS failed
FROM sys.dm_pdw_exec_requests
WHERE submit_time > DATEADD(hour, -24, GETDATE())
    AND resource_class IS NOT NULL
GROUP BY resource_class
ORDER BY query_count DESC;
```

### Session and Connection Info

```sql
-- 40. Active sessions
SELECT
    session_id,
    login_name,
    status,
    login_time,
    app_name,
    client_id
FROM sys.dm_pdw_exec_sessions
WHERE status = 'Active'
    AND session_id <> SESSION_ID()
ORDER BY login_time DESC;
```

```sql
-- 41. Session query history
SELECT
    s.session_id,
    s.login_name,
    r.request_id,
    r.status,
    r.submit_time,
    r.total_elapsed_time / 1000.0 AS elapsed_sec,
    LEFT(r.command, 200) AS command_preview
FROM sys.dm_pdw_exec_sessions s
JOIN sys.dm_pdw_exec_requests r ON s.session_id = r.session_id
WHERE s.login_name = 'specific_user'
    AND r.submit_time > DATEADD(hour, -4, GETDATE())
ORDER BY r.submit_time DESC;
```

```sql
-- 42. Kill a session
KILL 'SID12345';
```

### Tempdb and Memory

```sql
-- 43. Tempdb space usage per node
SELECT
    pdw_node_id,
    counter_name,
    cntr_value
FROM sys.dm_pdw_nodes_os_performance_counters
WHERE counter_name IN (
    'Temp Tables Creation Rate',
    'Temp Tables For Destruction'
)
ORDER BY pdw_node_id;
```

```sql
-- 44. Memory grants for active queries
SELECT
    r.request_id,
    r.session_id,
    r.resource_class,
    r.total_elapsed_time / 1000.0 AS elapsed_sec,
    LEFT(r.command, 200) AS command
FROM sys.dm_pdw_exec_requests r
WHERE r.status = 'Running'
    AND r.resource_class IN ('xlargerc', 'staticrc80')
ORDER BY r.total_elapsed_time DESC;
```

```sql
-- 45. Database size and space utilization
SELECT
    DB_NAME() AS database_name,
    SUM(size) * 8 / 1024 AS total_size_mb,
    SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8 / 1024 AS used_mb,
    SUM(size - FILEPROPERTY(name, 'SpaceUsed')) * 8 / 1024 AS free_mb
FROM sys.database_files;
```

### Statistics Diagnostics

```sql
-- 46. Statistics last updated date
SELECT
    t.name AS table_name,
    s.name AS stat_name,
    s.auto_created,
    s.user_created,
    STATS_DATE(s.object_id, s.stats_id) AS last_updated,
    sp.rows AS total_rows,
    sp.rows_sampled,
    sp.modification_counter
FROM sys.stats s
JOIN sys.tables t ON s.object_id = t.object_id
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
ORDER BY sp.modification_counter DESC;
```

```sql
-- 47. Tables with stale statistics (> 20% row change)
SELECT
    t.name AS table_name,
    s.name AS stat_name,
    sp.rows AS total_rows,
    sp.modification_counter,
    CAST(sp.modification_counter * 100.0 / NULLIF(sp.rows, 0) AS DECIMAL(10,2)) AS pct_modified,
    STATS_DATE(s.object_id, s.stats_id) AS last_updated
FROM sys.stats s
JOIN sys.tables t ON s.object_id = t.object_id
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE sp.modification_counter * 100.0 / NULLIF(sp.rows, 0) > 20
ORDER BY pct_modified DESC;
```

```sql
-- 48. Tables missing statistics on key columns
SELECT
    t.name AS table_name,
    c.name AS column_name,
    ty.name AS data_type
FROM sys.tables t
JOIN sys.columns c ON t.object_id = c.object_id
JOIN sys.types ty ON c.user_type_id = ty.user_type_id
WHERE NOT EXISTS (
    SELECT 1 FROM sys.stats_columns sc
    JOIN sys.stats s ON sc.object_id = s.object_id AND sc.stats_id = s.stats_id
    WHERE sc.object_id = t.object_id AND sc.column_id = c.column_id
)
AND ty.name IN ('int', 'bigint', 'date', 'datetime', 'datetime2', 'decimal', 'numeric', 'varchar', 'nvarchar')
ORDER BY t.name, c.column_id;
```

### Security Diagnostics

```sql
-- 49. Database principals and roles
SELECT
    dp.principal_id,
    dp.name,
    dp.type_desc,
    dp.authentication_type_desc,
    dp.default_schema_name,
    dp.create_date
FROM sys.database_principals dp
WHERE dp.type IN ('S', 'U', 'E', 'X')
ORDER BY dp.type_desc, dp.name;
```

```sql
-- 50. Role memberships
SELECT
    dp.name AS member_name,
    dp.type_desc AS member_type,
    r.name AS role_name
FROM sys.database_role_members rm
JOIN sys.database_principals dp ON rm.member_principal_id = dp.principal_id
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
ORDER BY r.name, dp.name;
```

```sql
-- 51. Permissions audit
SELECT
    dp.name AS principal_name,
    dp.type_desc AS principal_type,
    perm.permission_name,
    perm.state_desc AS permission_state,
    OBJECT_NAME(perm.major_id) AS object_name,
    perm.class_desc
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
WHERE dp.type IN ('S', 'U', 'E', 'X', 'R')
ORDER BY dp.name, perm.permission_name;
```

```sql
-- 52. Row-level security policies
SELECT
    sp.name AS policy_name,
    sp.is_enabled,
    sp.is_schema_bound,
    o.name AS predicate_function,
    t.name AS protected_table
FROM sys.security_policies sp
JOIN sys.security_predicates pred ON sp.object_id = pred.object_id
JOIN sys.objects o ON pred.predicate_id = o.object_id
JOIN sys.tables t ON pred.target_object_id = t.object_id;
```

```sql
-- 53. Dynamic data masking configuration
SELECT
    t.name AS table_name,
    c.name AS column_name,
    mc.masking_function
FROM sys.masked_columns mc
JOIN sys.columns c ON mc.object_id = c.object_id AND mc.column_id = c.column_id
JOIN sys.tables t ON c.object_id = t.object_id
ORDER BY t.name, c.column_id;
```

### Index Diagnostics

```sql
-- 54. All indexes with type and distribution
SELECT
    t.name AS table_name,
    i.name AS index_name,
    i.type_desc AS index_type,
    dp.distribution_policy_desc,
    STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS key_columns
FROM sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
LEFT JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
LEFT JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
JOIN sys.pdw_table_distribution_properties dp ON t.object_id = dp.object_id
GROUP BY t.name, i.name, i.type_desc, dp.distribution_policy_desc
ORDER BY t.name, i.index_id;
```

```sql
-- 55. Missing index recommendations (from query plans)
SELECT
    t.name AS table_name,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.unique_compiles,
    migs.user_seeks,
    migs.avg_user_impact
FROM sys.dm_pdw_nodes_db_missing_index_details mid
JOIN sys.dm_pdw_nodes_db_missing_index_groups mig ON mid.index_handle = mig.index_handle
JOIN sys.dm_pdw_nodes_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
JOIN sys.tables t ON mid.object_id = t.object_id
ORDER BY migs.avg_user_impact DESC;
```

### Query Plan Analysis

```sql
-- 56. EXPLAIN for distributed query plan
EXPLAIN
SELECT c.name, SUM(s.amount)
FROM dbo.fact_sales s
JOIN dbo.dim_customer c ON s.customer_id = c.customer_id
GROUP BY c.name;
-- Returns XML distributed query plan; look for DMS operations
```

```sql
-- 57. Estimated query plan with distribution info
EXPLAIN WITH_RECOMMENDATIONS
SELECT *
FROM dbo.fact_sales
WHERE sale_date >= '2025-01-01';
```

## Serverless SQL Pool Diagnostics

### Query Monitoring

```sql
-- 58. Active requests in serverless pool
SELECT
    session_id,
    request_id,
    status,
    start_time,
    total_elapsed_time / 1000.0 AS elapsed_sec,
    LEFT(text, 200) AS query_text
FROM sys.dm_exec_requests
CROSS APPLY sys.dm_exec_sql_text(sql_handle)
WHERE status = 'running';
```

```sql
-- 59. Recent query performance (serverless)
SELECT TOP 50
    session_id,
    start_time,
    status,
    total_elapsed_time / 1000.0 AS elapsed_sec,
    cpu_time / 1000.0 AS cpu_sec,
    logical_reads,
    LEFT(text, 200) AS query_text
FROM sys.dm_exec_requests
CROSS APPLY sys.dm_exec_sql_text(sql_handle)
ORDER BY start_time DESC;
```

```sql
-- 60. Data processed tracking (cost monitoring)
SELECT *
FROM sys.dm_external_data_processed
ORDER BY start_time DESC;
```

```sql
-- 61. Check data processed limits
SELECT
    type,
    limit_tb,
    current_usage_tb,
    CAST(current_usage_tb * 100.0 / NULLIF(limit_tb, 0) AS DECIMAL(5,2)) AS pct_used
FROM sys.dm_data_processed_limits;
```

### OPENROWSET Performance

```sql
-- 62. Test file accessibility and schema inference
SELECT TOP 10 *
FROM OPENROWSET(
    BULK 'https://datalake.dfs.core.windows.net/container/path/*.parquet',
    FORMAT = 'PARQUET'
) AS r;
```

```sql
-- 63. Check inferred schema for Parquet files
EXEC sp_describe_first_result_set N'
SELECT *
FROM OPENROWSET(
    BULK ''https://datalake.dfs.core.windows.net/container/path/sample.parquet'',
    FORMAT = ''PARQUET''
) AS r';
```

```sql
-- 64. Count files and rows in a data lake path
SELECT
    r.filepath(1) AS partition_value,
    COUNT(*) AS row_count
FROM OPENROWSET(
    BULK 'https://datalake.dfs.core.windows.net/container/path/partition=*/*.parquet',
    FORMAT = 'PARQUET'
) AS r
GROUP BY r.filepath(1)
ORDER BY r.filepath(1);
```

```sql
-- 65. Delta Lake table history (time travel)
SELECT *
FROM OPENROWSET(
    BULK 'https://datalake.dfs.core.windows.net/container/delta_table/',
    FORMAT = 'DELTA'
) AS r
-- Add FOR TIMESTAMP AS OF for time travel
;
```

### External Objects

```sql
-- 66. List external data sources
SELECT
    name,
    type_desc,
    location,
    credential_id
FROM sys.external_data_sources;
```

```sql
-- 67. List external file formats
SELECT
    name,
    format_type,
    serde_method,
    field_terminator,
    string_delimiter,
    first_row
FROM sys.external_file_formats;
```

```sql
-- 68. List external tables
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    eds.name AS data_source,
    eff.name AS file_format,
    t.location
FROM sys.external_tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.external_data_sources eds ON t.data_source_id = eds.data_source_id
LEFT JOIN sys.external_file_formats eff ON t.file_format_id = eff.file_format_id
ORDER BY s.name, t.name;
```

```sql
-- 69. Database-scoped credentials
SELECT
    credential_id,
    name,
    credential_identity,
    create_date,
    modify_date
FROM sys.database_scoped_credentials;
```

## Spark Pool Diagnostics

### Spark Application Monitoring

```python
# 70. Check Spark pool configuration (PySpark)
spark.sparkContext.getConf().getAll()
```

```python
# 71. Spark session info
print(f"App Name: {spark.sparkContext.appName}")
print(f"App ID: {spark.sparkContext.applicationId}")
print(f"Master: {spark.sparkContext.master}")
print(f"Default Parallelism: {spark.sparkContext.defaultParallelism}")
print(f"Spark Version: {spark.version}")
```

```python
# 72. Check executor status
sc = spark.sparkContext
print(f"Executors: {sc._jsc.sc().getExecutorMemoryStatus().size()}")
print(f"Default Parallelism: {sc.defaultParallelism}")
```

```python
# 73. DataFrame explain plan (physical + logical)
df = spark.read.parquet("abfss://container@account.dfs.core.windows.net/path/")
df.explain(mode="extended")
```

```python
# 74. DataFrame statistics
df.describe().show()
df.summary().show()
print(f"Partitions: {df.rdd.getNumPartitions()}")
print(f"Row count: {df.count()}")
```

```python
# 75. Check data skew in Spark DataFrame
from pyspark.sql.functions import spark_partition_id, count

df.groupBy(spark_partition_id().alias("partition_id")) \
    .agg(count("*").alias("row_count")) \
    .orderBy("row_count", ascending=False) \
    .show(20)
```

```python
# 76. Delta Lake table details
from delta.tables import DeltaTable

dt = DeltaTable.forPath(spark, "abfss://container@account.dfs.core.windows.net/delta/table")
dt.detail().show(truncate=False)
dt.history().show(truncate=False)
```

```python
# 77. Check Delta table file sizes and count
from pyspark.sql.functions import col, sum as spark_sum, count as spark_count, avg

delta_path = "abfss://container@account.dfs.core.windows.net/delta/table"
files_df = spark.read.format("delta").load(delta_path).inputFiles()
print(f"Number of files: {len(files_df)}")
```

```sql
-- 78. SparkSQL: Show databases and tables (shared metastore)
SHOW DATABASES;
SHOW TABLES IN my_database;
DESCRIBE EXTENDED my_database.my_table;
```

## Pipeline Monitoring

### Synapse Studio Monitor Hub Queries

```sql
-- 79. Pipeline run history (via serverless SQL pool querying Log Analytics)
-- Requires diagnostic settings forwarding to Log Analytics workspace
-- See KQL section below for direct Log Analytics queries
```

### Pipeline REST API Diagnostics

```bash
# 80. List pipeline runs (last 24 hours)
az synapse pipeline-run query-by-workspace \
  --workspace-name myworkspace \
  --last-updated-after "2025-04-06T00:00:00Z" \
  --last-updated-before "2025-04-07T00:00:00Z" \
  --output table
```

```bash
# 81. Get specific pipeline run details
az synapse pipeline-run show \
  --workspace-name myworkspace \
  --run-id "run-guid-here"
```

```bash
# 82. List activity runs for a pipeline run
az synapse activity-run query-by-pipeline-run \
  --workspace-name myworkspace \
  --pipeline-name mypipeline \
  --run-id "run-guid-here" \
  --last-updated-after "2025-04-06T00:00:00Z" \
  --last-updated-before "2025-04-07T00:00:00Z"
```

```bash
# 83. List trigger runs
az synapse trigger-run query-by-workspace \
  --workspace-name myworkspace \
  --last-updated-after "2025-04-06T00:00:00Z" \
  --last-updated-before "2025-04-07T00:00:00Z" \
  --output table
```

## Azure CLI (az synapse) Commands

### Workspace Management

```bash
# 84. Show workspace details
az synapse workspace show \
  --name myworkspace \
  --resource-group myrg

# 85. List all workspaces in subscription
az synapse workspace list --output table

# 86. Check workspace managed identity
az synapse workspace show \
  --name myworkspace \
  --resource-group myrg \
  --query "identity" --output json

# 87. List workspace managed private endpoints
az synapse managed-private-endpoints list \
  --workspace-name myworkspace

# 88. Check workspace firewall rules
az synapse workspace firewall-rule list \
  --workspace-name myworkspace \
  --resource-group myrg \
  --output table
```

### Dedicated SQL Pool Management

```bash
# 89. List dedicated SQL pools
az synapse sql pool list \
  --workspace-name myworkspace \
  --resource-group myrg \
  --output table

# 90. Show pool details (DWU level, status)
az synapse sql pool show \
  --name mypool \
  --workspace-name myworkspace \
  --resource-group myrg

# 91. Check pool status
az synapse sql pool show \
  --name mypool \
  --workspace-name myworkspace \
  --resource-group myrg \
  --query "status" --output tsv

# 92. Scale dedicated SQL pool
az synapse sql pool update \
  --name mypool \
  --workspace-name myworkspace \
  --resource-group myrg \
  --performance-level DW1000c

# 93. Pause dedicated SQL pool
az synapse sql pool pause \
  --name mypool \
  --workspace-name myworkspace \
  --resource-group myrg

# 94. Resume dedicated SQL pool
az synapse sql pool resume \
  --name mypool \
  --workspace-name myworkspace \
  --resource-group myrg

# 95. Create a restore point
az synapse sql pool restore-point create \
  --name mypool \
  --workspace-name myworkspace \
  --resource-group myrg \
  --restore-point-label "pre-deploy-2025-04-07"

# 96. List restore points
az synapse sql pool restore-point list \
  --name mypool \
  --workspace-name myworkspace \
  --resource-group myrg \
  --output table

# 97. Set TDE (Transparent Data Encryption)
az synapse sql pool tde set \
  --name mypool \
  --workspace-name myworkspace \
  --resource-group myrg \
  --status Enabled
```

### Spark Pool Management

```bash
# 98. List Spark pools
az synapse spark pool list \
  --workspace-name myworkspace \
  --resource-group myrg \
  --output table

# 99. Show Spark pool details
az synapse spark pool show \
  --name mysparkpool \
  --workspace-name myworkspace \
  --resource-group myrg

# 100. Update Spark pool (auto-scale, auto-pause)
az synapse spark pool update \
  --name mysparkpool \
  --workspace-name myworkspace \
  --resource-group myrg \
  --enable-auto-scale true \
  --min-node-count 3 \
  --max-node-count 10 \
  --enable-auto-pause true \
  --delay 5

# 101. List Spark sessions
az synapse spark session list \
  --workspace-name myworkspace \
  --spark-pool-name mysparkpool \
  --output table

# 102. List Spark batch jobs
az synapse spark job list \
  --workspace-name myworkspace \
  --spark-pool-name mysparkpool \
  --output table

# 103. Cancel a Spark session
az synapse spark session cancel \
  --workspace-name myworkspace \
  --spark-pool-name mysparkpool \
  --livy-id 123 --yes
```

### Pipeline Management

```bash
# 104. List pipelines
az synapse pipeline list \
  --workspace-name myworkspace \
  --output table

# 105. Show pipeline definition
az synapse pipeline show \
  --workspace-name myworkspace \
  --name mypipeline

# 106. Trigger a pipeline run
az synapse pipeline create-run \
  --workspace-name myworkspace \
  --name mypipeline

# 107. List triggers
az synapse trigger list \
  --workspace-name myworkspace \
  --output table

# 108. Start/stop a trigger
az synapse trigger start \
  --workspace-name myworkspace \
  --name mytrigger

az synapse trigger stop \
  --workspace-name myworkspace \
  --name mytrigger

# 109. List linked services
az synapse linked-service list \
  --workspace-name myworkspace \
  --output table

# 110. List integration runtimes
az synapse integration-runtime list \
  --workspace-name myworkspace \
  --resource-group myrg \
  --output table
```

### Security and Access

```bash
# 111. List SQL audit settings
az synapse sql audit-policy show \
  --workspace-name myworkspace \
  --resource-group myrg

# 112. List AD-only auth status
az synapse sql ad-only-auth get \
  --workspace-name myworkspace \
  --resource-group myrg

# 113. Set Azure AD admin
az synapse sql ad-admin create \
  --workspace-name myworkspace \
  --resource-group myrg \
  --display-name "Synapse Admin Group" \
  --object-id "aad-group-object-id"

# 114. List role assignments at workspace level
az synapse role assignment list \
  --workspace-name myworkspace \
  --output table
```

## Azure Monitor and Log Analytics KQL Queries

### Dedicated SQL Pool KQL

```kql
// 115. Query execution duration distribution (last 24h)
SynapseSqlPoolExecRequests
| where TimeGenerated > ago(24h)
| where Status == "Completed"
| summarize
    Count = count(),
    AvgDurationMs = avg(TotalElapsedTimeMs),
    P50 = percentile(TotalElapsedTimeMs, 50),
    P95 = percentile(TotalElapsedTimeMs, 95),
    P99 = percentile(TotalElapsedTimeMs, 99),
    MaxDurationMs = max(TotalElapsedTimeMs)
    by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

```kql
// 116. Top 20 slowest queries (last 24h)
SynapseSqlPoolExecRequests
| where TimeGenerated > ago(24h)
| where Status == "Completed"
| top 20 by TotalElapsedTimeMs desc
| project TimeGenerated, RequestId, TotalElapsedTimeMs, ResourceClass, Command
```

```kql
// 117. Failed queries with error details
SynapseSqlPoolExecRequests
| where TimeGenerated > ago(24h)
| where Status == "Failed"
| project TimeGenerated, RequestId, ErrorId, Command, ResourceClass
| order by TimeGenerated desc
```

```kql
// 118. DMS operation volume over time
SynapseSqlPoolRequestSteps
| where TimeGenerated > ago(24h)
| where OperationType in ("ShuffleMove", "BroadcastMove", "TrimMove")
| summarize
    Count = count(),
    TotalRowsMoved = sum(RowCount),
    AvgDurationMs = avg(TotalElapsedTimeMs)
    by OperationType, bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

```kql
// 119. Concurrency slot usage over time
SynapseSqlPoolExecRequests
| where TimeGenerated > ago(24h)
| where Status == "Running"
| summarize RunningQueries = dcount(RequestId) by bin(TimeGenerated, 5m)
| order by TimeGenerated desc
```

```kql
// 120. DWU utilization trend
SynapseSqlPoolDmsPdwNodeStatus
| where TimeGenerated > ago(7d)
| summarize AvgCPU = avg(CpuUsage), MaxCPU = max(CpuUsage) by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

```kql
// 121. Query queue wait times
SynapseSqlPoolExecRequests
| where TimeGenerated > ago(24h)
| extend QueueTimeMs = datetime_diff('millisecond', StartTime, SubmitTime)
| where QueueTimeMs > 0
| summarize
    AvgQueueMs = avg(QueueTimeMs),
    P95QueueMs = percentile(QueueTimeMs, 95),
    MaxQueueMs = max(QueueTimeMs),
    QueuedCount = count()
    by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

```kql
// 122. Result set cache effectiveness
SynapseSqlPoolExecRequests
| where TimeGenerated > ago(24h)
| where Status == "Completed"
| summarize
    CacheHits = countif(ResultCacheHit == true),
    CacheMisses = countif(ResultCacheHit == false),
    HitRatio = round(100.0 * countif(ResultCacheHit == true) / count(), 2)
    by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

### Serverless SQL Pool KQL

```kql
// 123. Data processed per query (cost tracking)
SynapseBuiltinSqlPoolRequestsEnded
| where TimeGenerated > ago(24h)
| summarize
    TotalDataProcessedMB = sum(DataProcessedMB),
    QueryCount = count(),
    AvgDataMB = avg(DataProcessedMB),
    EstCostUSD = sum(DataProcessedMB) / 1048576.0 * 5.0  -- $5/TB
    by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

```kql
// 124. Top data-consuming queries (serverless)
SynapseBuiltinSqlPoolRequestsEnded
| where TimeGenerated > ago(24h)
| top 20 by DataProcessedMB desc
| project TimeGenerated, DurationMs, DataProcessedMB, Command
```

```kql
// 125. Serverless query failure analysis
SynapseBuiltinSqlPoolRequestsEnded
| where TimeGenerated > ago(24h)
| where Status == "Failed"
| summarize FailureCount = count() by ErrorCode, ErrorMessage = substring(ErrorMessage, 0, 200)
| order by FailureCount desc
```

```kql
// 126. Daily serverless cost estimate
SynapseBuiltinSqlPoolRequestsEnded
| where TimeGenerated > ago(30d)
| summarize
    DailyDataGB = sum(DataProcessedMB) / 1024.0,
    DailyEstCostUSD = sum(DataProcessedMB) / 1048576.0 * 5.0,
    QueryCount = count()
    by bin(TimeGenerated, 1d)
| order by TimeGenerated desc
```

### Spark Pool KQL

```kql
// 127. Spark application execution history
SynapseSparkPoolApplications
| where TimeGenerated > ago(7d)
| project TimeGenerated, ApplicationName, State, DurationMs, SubmitterId, SparkPoolName
| order by TimeGenerated desc
```

```kql
// 128. Spark application failures
SynapseSparkPoolApplications
| where TimeGenerated > ago(7d)
| where State == "Failed"
| project TimeGenerated, ApplicationName, DurationMs, ErrorInfo, SparkPoolName
| order by TimeGenerated desc
```

```kql
// 129. Spark pool utilization trend
SynapseSparkPoolNodes
| where TimeGenerated > ago(7d)
| summarize
    AvgNodes = avg(ActiveNodes),
    MaxNodes = max(ActiveNodes)
    by SparkPoolName, bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

### Pipeline KQL

```kql
// 130. Pipeline run success/failure rates
SynapseIntegrationPipelineRuns
| where TimeGenerated > ago(7d)
| summarize
    TotalRuns = count(),
    Succeeded = countif(Status == "Succeeded"),
    Failed = countif(Status == "Failed"),
    SuccessRate = round(100.0 * countif(Status == "Succeeded") / count(), 2)
    by PipelineName
| order by Failed desc
```

```kql
// 131. Pipeline activity durations
SynapseIntegrationActivityRuns
| where TimeGenerated > ago(7d)
| summarize
    AvgDurationMs = avg(DurationMs),
    MaxDurationMs = max(DurationMs),
    RunCount = count()
    by PipelineName, ActivityName, ActivityType
| order by AvgDurationMs desc
```

```kql
// 132. Pipeline failures with error details
SynapseIntegrationPipelineRuns
| where TimeGenerated > ago(24h)
| where Status == "Failed"
| project TimeGenerated, PipelineName, DurationMs, Error
| order by TimeGenerated desc
```

```kql
// 133. Data movement volumes in pipelines
SynapseIntegrationActivityRuns
| where TimeGenerated > ago(7d)
| where ActivityType == "Copy"
| extend DataReadMB = toreal(DataRead) / 1048576
| extend DataWrittenMB = toreal(DataWritten) / 1048576
| summarize
    TotalReadMB = sum(DataReadMB),
    TotalWrittenMB = sum(DataWrittenMB),
    Runs = count()
    by PipelineName, ActivityName
| order by TotalReadMB desc
```

### Cross-Component KQL

```kql
// 134. Overall workspace health dashboard
union
    (SynapseSqlPoolExecRequests | where TimeGenerated > ago(1h) | summarize DedicatedQueries = count(), DedicatedFailed = countif(Status == "Failed")),
    (SynapseBuiltinSqlPoolRequestsEnded | where TimeGenerated > ago(1h) | summarize ServerlessQueries = count(), ServerlessFailed = countif(Status == "Failed")),
    (SynapseSparkPoolApplications | where TimeGenerated > ago(1h) | summarize SparkApps = count(), SparkFailed = countif(State == "Failed")),
    (SynapseIntegrationPipelineRuns | where TimeGenerated > ago(1h) | summarize PipelineRuns = count(), PipelineFailed = countif(Status == "Failed"))
```

```kql
// 135. Alert: queries queued for > 5 minutes
SynapseSqlPoolExecRequests
| where TimeGenerated > ago(15m)
| where Status == "Suspended"
| extend QueueTimeMin = datetime_diff('minute', now(), SubmitTime)
| where QueueTimeMin > 5
| project RequestId, SubmitTime, QueueTimeMin, ResourceClass, Importance, Command
```

## Azure Monitor Metrics (REST/CLI)

```bash
# 136. Get DWU utilization metrics
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Synapse/workspaces/{ws}/sqlPools/{pool}" \
  --metric "DWUUsedPercent" \
  --interval PT1H \
  --start-time "2025-04-06T00:00:00Z" \
  --end-time "2025-04-07T00:00:00Z" \
  --output table
```

```bash
# 137. Get active queries metric
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Synapse/workspaces/{ws}/sqlPools/{pool}" \
  --metric "ActiveQueries" \
  --interval PT5M \
  --output table
```

```bash
# 138. Get queued queries metric
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Synapse/workspaces/{ws}/sqlPools/{pool}" \
  --metric "QueuedQueries" \
  --interval PT5M \
  --output table
```

```bash
# 139. Get tempdb utilization
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Synapse/workspaces/{ws}/sqlPools/{pool}" \
  --metric "LocalTempDBUsedPercent" \
  --interval PT5M \
  --output table
```

```bash
# 140. Get adaptive cache hit ratio
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Synapse/workspaces/{ws}/sqlPools/{pool}" \
  --metric "AdaptiveCacheHitPercent" \
  --interval PT1H \
  --output table
```

```bash
# 141. Get serverless data processed
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Synapse/workspaces/{ws}" \
  --metric "BuiltinSqlPoolDataProcessedBytes" \
  --interval PT1H \
  --output table
```

```bash
# 142. Get Spark pool active applications
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Synapse/workspaces/{ws}/bigDataPools/{pool}" \
  --metric "BigDataPoolApplicationsActive" \
  --interval PT5M \
  --output table
```

## Cost Analysis

```bash
# 143. Get dedicated SQL pool cost (Azure Cost Management)
az costmanagement query \
  --type ActualCost \
  --scope "subscriptions/{sub}" \
  --timeframe MonthToDate \
  --dataset-filter "{\"dimensions\":{\"name\":\"MeterCategory\",\"operator\":\"In\",\"values\":[\"Azure Synapse Analytics\"]}}" \
  --output table
```

```sql
-- 144. Estimate query cost by data movement (dedicated pool)
SELECT
    r.request_id,
    SUM(s.total_elapsed_time) / 1000.0 AS total_step_time_sec,
    SUM(CASE WHEN s.operation_type LIKE '%Move%' THEN s.total_elapsed_time ELSE 0 END) / 1000.0 AS dms_time_sec,
    SUM(CASE WHEN s.operation_type LIKE '%Move%' THEN s.row_count ELSE 0 END) AS rows_moved,
    LEFT(r.command, 200) AS query
FROM sys.dm_pdw_exec_requests r
JOIN sys.dm_pdw_request_steps s ON r.request_id = s.request_id
WHERE r.submit_time > DATEADD(hour, -24, GETDATE())
    AND r.status = 'Completed'
GROUP BY r.request_id, LEFT(r.command, 200)
ORDER BY dms_time_sec DESC;
```

```sql
-- 145. Serverless SQL pool: estimate monthly cost from recent usage
SELECT
    CAST(SUM(data_processed_mb) AS DECIMAL(18,2)) AS total_mb_last_7d,
    CAST(SUM(data_processed_mb) / 1024.0 AS DECIMAL(18,2)) AS total_gb_last_7d,
    CAST(SUM(data_processed_mb) / 1048576.0 * 5.0 AS DECIMAL(18,2)) AS cost_usd_last_7d,
    CAST(SUM(data_processed_mb) / 1048576.0 * 5.0 * 30.0 / 7.0 AS DECIMAL(18,2)) AS est_monthly_usd
FROM sys.dm_external_data_processed
WHERE start_time > DATEADD(day, -7, GETDATE());
```

## Troubleshooting Quick Reference

### Data Skew Detection

```sql
-- 146. Comprehensive skew report
SELECT
    t.name AS table_name,
    dp.distribution_policy_desc,
    SUM(ps.row_count) AS total_rows_all_dist,
    MAX(ps.row_count) AS max_dist_rows,
    MIN(ps.row_count) AS min_dist_rows,
    AVG(ps.row_count) AS avg_dist_rows,
    CASE
        WHEN AVG(ps.row_count) = 0 THEN 0
        ELSE CAST((MAX(ps.row_count) - AVG(ps.row_count)) * 100.0 / AVG(ps.row_count) AS DECIMAL(10,2))
    END AS skew_pct,
    CASE
        WHEN AVG(ps.row_count) = 0 THEN 'EMPTY'
        WHEN (MAX(ps.row_count) * 1.0 / AVG(ps.row_count)) > 1.20 THEN 'HIGH SKEW'
        WHEN (MAX(ps.row_count) * 1.0 / AVG(ps.row_count)) > 1.10 THEN 'MODERATE SKEW'
        ELSE 'OK'
    END AS skew_status
FROM (
    SELECT object_id, distribution_id, SUM(row_count) AS row_count
    FROM sys.dm_pdw_nodes_db_partition_stats
    WHERE index_id <= 1
    GROUP BY object_id, distribution_id
) ps
JOIN sys.tables t ON ps.object_id = t.object_id
JOIN sys.pdw_table_distribution_properties dp ON t.object_id = dp.object_id
WHERE dp.distribution_policy_desc = 'HASH'
GROUP BY t.name, dp.distribution_policy_desc
HAVING SUM(ps.row_count) > 0
ORDER BY skew_pct DESC;
```

### Tempdb Pressure Detection

```sql
-- 147. Check tempdb file usage on each node
SELECT
    pdw_node_id,
    instance_name,
    counter_name,
    cntr_value
FROM sys.dm_pdw_nodes_os_performance_counters
WHERE object_name LIKE '%:Databases%'
    AND instance_name = 'tempdb'
    AND counter_name IN ('Data File(s) Size (KB)', 'Log File(s) Size (KB)', 'Log File(s) Used Size (KB)')
ORDER BY pdw_node_id;
```

```sql
-- 148. Queries consuming most resources (likely tempdb consumers)
SELECT TOP 10
    request_id,
    session_id,
    total_elapsed_time / 1000.0 AS elapsed_sec,
    resource_class,
    LEFT(command, 300) AS command
FROM sys.dm_pdw_exec_requests
WHERE status = 'Running'
ORDER BY total_elapsed_time DESC;
```

### Connection Troubleshooting

```sql
-- 149. Active connections summary
SELECT
    login_name,
    COUNT(*) AS connection_count,
    MAX(login_time) AS last_login
FROM sys.dm_pdw_exec_sessions
WHERE status = 'Active'
GROUP BY login_name
ORDER BY connection_count DESC;
```

```sql
-- 150. Session with blocking waits
SELECT
    w.session_id AS waiting_session,
    w.request_id AS waiting_request,
    w.type AS wait_type,
    w.object_name,
    r.session_id AS blocking_session
FROM sys.dm_pdw_waits w
LEFT JOIN sys.dm_pdw_exec_requests r ON w.object_name = r.request_id
WHERE w.state = 'Queued'
    AND w.type LIKE '%Lock%';
```

### Loading Diagnostics

```sql
-- 151. COPY INTO error tracking
-- Check for rows rejected during COPY INTO loading
SELECT *
FROM sys.dm_pdw_exec_requests
WHERE command LIKE '%COPY INTO%'
    AND status = 'Failed'
    AND submit_time > DATEADD(hour, -24, GETDATE())
ORDER BY submit_time DESC;
```

```sql
-- 152. Monitor active loading operations
SELECT
    r.request_id,
    r.status,
    r.total_elapsed_time / 1000.0 AS elapsed_sec,
    s.operation_type,
    s.row_count,
    LEFT(r.command, 200) AS command
FROM sys.dm_pdw_exec_requests r
JOIN sys.dm_pdw_request_steps s ON r.request_id = s.request_id
WHERE r.command LIKE '%COPY INTO%'
    AND r.status = 'Running'
ORDER BY r.total_elapsed_time DESC;
```

### Synapse Link Diagnostics

```sql
-- 153. Query Cosmos DB via Synapse Link (serverless pool)
SELECT TOP 100 *
FROM OPENROWSET(
    PROVIDER = 'CosmosDB',
    CONNECTION = 'Account=mycosmosaccount;Database=mydb',
    OBJECT = 'mycontainer',
    SERVER_CREDENTIAL = 'my_cosmos_credential'
) AS c;
```

```sql
-- 154. Check Synapse Link feed latency (Cosmos DB analytical store)
-- Monitor via Cosmos DB metrics in Azure Monitor:
-- Metric: "Analytical Store Sync Latency"
-- Target: < 5 minutes
```

### Health Check Script

```sql
-- 155. Comprehensive dedicated SQL pool health check
PRINT '=== Pool Status ===';
SELECT DB_NAME() AS database_name, SERVERPROPERTY('Edition') AS edition;

PRINT '=== Active Queries ===';
SELECT COUNT(*) AS active_queries FROM sys.dm_pdw_exec_requests WHERE status = 'Running';

PRINT '=== Queued Queries ===';
SELECT COUNT(*) AS queued_queries FROM sys.dm_pdw_exec_requests WHERE status = 'Suspended';

PRINT '=== Failed Queries (Last Hour) ===';
SELECT COUNT(*) AS failed_last_hour FROM sys.dm_pdw_exec_requests WHERE status = 'Failed' AND submit_time > DATEADD(hour, -1, GETDATE());

PRINT '=== Top Skewed Tables ===';
SELECT TOP 5
    t.name,
    CAST(MAX(ps.row_count) * 1.0 / NULLIF(AVG(ps.row_count), 0) AS DECIMAL(10,2)) AS skew_factor
FROM (
    SELECT object_id, distribution_id, SUM(row_count) AS row_count
    FROM sys.dm_pdw_nodes_db_partition_stats WHERE index_id <= 1
    GROUP BY object_id, distribution_id
) ps
JOIN sys.tables t ON ps.object_id = t.object_id
GROUP BY t.name
HAVING AVG(ps.row_count) > 0
ORDER BY skew_factor DESC;

PRINT '=== Tables with Stale Stats ===';
SELECT TOP 5
    t.name,
    CAST(sp.modification_counter * 100.0 / NULLIF(sp.rows, 0) AS DECIMAL(10,2)) AS pct_modified
FROM sys.stats s
JOIN sys.tables t ON s.object_id = t.object_id
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE sp.modification_counter * 100.0 / NULLIF(sp.rows, 0) > 20
ORDER BY pct_modified DESC;

PRINT '=== Concurrency Waits ===';
SELECT COUNT(*) AS concurrency_waits FROM sys.dm_pdw_waits WHERE type = 'Concurrency' AND state = 'Queued';

PRINT '=== Node Health ===';
SELECT pdw_node_id, total_cpu_usage, active_requests FROM sys.dm_pdw_node_status;
```
