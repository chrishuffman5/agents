/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Memory Pressure Analysis
 *
 * Purpose : Detect memory pressure, OOM events, and grant feedback.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Memory Configuration & Current State
 *   2. Memory Clerk Breakdown (Top Consumers)
 *   3. Buffer Pool Usage by Database
 *   4. Memory Grant Pending & Usage
 *   5. Out-of-Memory Events (NEW in 2022 — sys.dm_os_out_of_memory_events)
 *   6. Memory Grant Percentile Feedback Tracking (NEW in 2022)
 *   7. Buffer Pool Parallel Scan Info (NEW in 2022)
 *   8. NUMA Node Memory Distribution
 *   9. Memory Broker Status
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: Memory Configuration & Current State
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    si.physical_memory_kb / 1024                    AS physical_memory_mb,
    si.committed_kb / 1024                          AS committed_memory_mb,
    si.committed_target_kb / 1024                   AS target_memory_mb,
    si.visible_target_kb / 1024                     AS visible_target_mb,
    (SELECT CAST(value_in_use AS BIGINT)
     FROM sys.configurations
     WHERE name = 'max server memory (MB)')         AS max_server_memory_mb,
    (SELECT CAST(value_in_use AS BIGINT)
     FROM sys.configurations
     WHERE name = 'min server memory (MB)')         AS min_server_memory_mb,
    pm.total_physical_memory_kb / 1024              AS os_total_memory_mb,
    pm.available_physical_memory_kb / 1024          AS os_available_memory_mb,
    pm.system_memory_state_desc                     AS os_memory_state
FROM sys.dm_os_sys_info AS si
CROSS JOIN sys.dm_os_sys_memory AS pm;

-- Process memory
SELECT
    physical_memory_in_use_kb / 1024                AS sql_physical_memory_mb,
    large_page_allocations_kb / 1024                AS large_page_mb,
    locked_page_allocations_kb / 1024               AS locked_page_mb,
    virtual_address_space_committed_kb / 1024       AS virtual_committed_mb,
    virtual_address_space_reserved_kb / 1024        AS virtual_reserved_mb,
    memory_utilization_percentage                   AS memory_utilization_pct,
    available_commit_limit_kb / 1024                AS available_commit_limit_mb,
    process_physical_memory_low                     AS is_physical_memory_low,
    process_virtual_memory_low                      AS is_virtual_memory_low
FROM sys.dm_os_process_memory;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: Memory Clerk Breakdown (Top 20 Consumers)
──────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (20)
    type                                            AS clerk_type,
    name                                            AS clerk_name,
    pages_kb / 1024                                 AS allocated_mb,
    virtual_memory_reserved_kb / 1024               AS virtual_reserved_mb,
    virtual_memory_committed_kb / 1024              AS virtual_committed_mb,
    awe_allocated_kb / 1024                         AS awe_allocated_mb
FROM sys.dm_os_memory_clerks
WHERE pages_kb > 0
ORDER BY pages_kb DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: Buffer Pool Usage by Database
──────────────────────────────────────────────────────────────────────────────*/
;WITH buffer_pool AS (
    SELECT
        database_id,
        COUNT(*)                                    AS page_count,
        SUM(CASE WHEN is_modified = 1 THEN 1 ELSE 0 END) AS dirty_pages,
        SUM(CAST(free_space_in_bytes AS BIGINT))    AS free_space_bytes
    FROM sys.dm_os_buffer_descriptors
    GROUP BY database_id
)
SELECT
    COALESCE(DB_NAME(bp.database_id), 'ResourceDB')AS database_name,
    bp.page_count,
    bp.page_count * 8 / 1024                       AS buffer_pool_mb,
    bp.dirty_pages,
    bp.dirty_pages * 8 / 1024                      AS dirty_mb,
    CAST(bp.dirty_pages * 100.0
        / NULLIF(bp.page_count, 0) AS DECIMAL(5,2))
                                                    AS dirty_pct,
    bp.free_space_bytes / 1048576                   AS free_space_mb
FROM buffer_pool AS bp
ORDER BY bp.page_count DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Memory Grant Pending & Usage
──────────────────────────────────────────────────────────────────────────────*/
-- Active memory grants
SELECT
    mg.session_id,
    mg.request_time,
    mg.grant_time,
    mg.requested_memory_kb / 1024                   AS requested_mb,
    mg.granted_memory_kb / 1024                     AS granted_mb,
    mg.used_memory_kb / 1024                        AS used_mb,
    mg.max_used_memory_kb / 1024                    AS max_used_mb,
    mg.required_memory_kb / 1024                    AS required_mb,
    mg.ideal_memory_kb / 1024                       AS ideal_mb,
    mg.dop                                          AS degree_of_parallelism,
    mg.is_small,
    mg.timeout_sec,
    mg.wait_time_ms,
    mg.queue_id,
    DB_NAME(er.database_id)                         AS database_name,
    SUBSTRING(qt.text, 1, 300)                      AS query_text
FROM sys.dm_exec_query_memory_grants AS mg
LEFT JOIN sys.dm_exec_requests AS er
    ON mg.session_id = er.session_id
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) AS qt
ORDER BY mg.granted_memory_kb DESC;

-- Resource semaphore (memory grant pool status)
SELECT
    resource_semaphore_id,
    pool_id,
    target_memory_kb / 1024                         AS target_mb,
    max_target_memory_kb / 1024                     AS max_target_mb,
    total_memory_kb / 1024                          AS total_mb,
    available_memory_kb / 1024                      AS available_mb,
    granted_memory_kb / 1024                        AS granted_mb,
    used_memory_kb / 1024                           AS used_mb,
    grantee_count,
    waiter_count,
    timeout_error_count
FROM sys.dm_exec_query_resource_semaphores;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: Out-of-Memory Events — NEW in 2022
  sys.dm_os_out_of_memory_events tracks OOM occurrences with detail.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (
    SELECT 1 FROM sys.all_objects
    WHERE name = 'dm_os_out_of_memory_events' AND type = 'V'
)
BEGIN
    SELECT
        event_time,
        oom_cause                                   AS oom_cause,
        oom_action                                  AS action_taken,
        pool_id,
        clerk_type,
        clerk_name,
        consumed_memory_kb / 1024                   AS consumed_memory_mb,
        target_memory_kb / 1024                     AS target_memory_mb
    FROM sys.dm_os_out_of_memory_events                                         -- NEW in 2022
    ORDER BY event_time DESC;
END
ELSE
BEGIN
    SELECT 'sys.dm_os_out_of_memory_events not available. Requires SQL Server 2022+.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 6: Memory Grant Percentile Feedback Tracking — NEW in 2022
  Queries sys.query_store_plan_feedback for memory grant percentile feedback.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (
    SELECT 1 FROM sys.database_query_store_options
    WHERE actual_state IN (1, 2)
)
AND EXISTS (
    SELECT 1 FROM sys.all_objects WHERE name = 'query_store_plan_feedback'
)
BEGIN
    SELECT
        pf.plan_feedback_id,
        pf.plan_id,
        p.query_id,
        pf.feature_desc,                                                        -- NEW in 2022
        pf.feedback_data,                                                       -- NEW in 2022
        pf.state_desc                               AS feedback_state,          -- NEW in 2022
        pf.create_time                              AS feedback_created,
        pf.last_updated_time                        AS feedback_last_updated,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview,
        rs.avg_query_max_used_memory                AS avg_max_used_memory,
        rs.avg_rowcount                             AS avg_row_count,
        rs.count_executions                         AS exec_count
    FROM sys.query_store_plan_feedback AS pf                                    -- NEW in 2022
    INNER JOIN sys.query_store_plan AS p
        ON pf.plan_id = p.plan_id
    INNER JOIN sys.query_store_query AS q
        ON p.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    LEFT JOIN sys.query_store_runtime_stats AS rs
        ON rs.plan_id = p.plan_id
    WHERE pf.feature_desc = 'MGF_PERCENTILE'                                    -- NEW in 2022
    ORDER BY pf.last_updated_time DESC;
END
ELSE
BEGIN
    SELECT 'Memory grant percentile feedback requires Query Store active and SQL Server 2022+.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 7: Buffer Pool Parallel Scan Info — NEW in 2022
  SQL Server 2022 can use parallel scan of the buffer pool during
  checkpoint and lazy writer operations.
──────────────────────────────────────────────────────────────────────────────*/
-- Buffer pool size and configuration context
SELECT
    si.committed_kb / 1024                          AS buffer_pool_committed_mb,
    si.committed_target_kb / 1024                   AS buffer_pool_target_mb,
    (SELECT COUNT(*) FROM sys.dm_os_buffer_descriptors)
                                                    AS total_pages_in_pool,
    -- Parallel scan is automatic in 2022 for large buffer pools (> 128 GB)
    -- Check for related wait types that indicate parallel scan activity
    COALESCE(
        (SELECT SUM(waiting_tasks_count)
         FROM sys.dm_os_wait_stats
         WHERE wait_type LIKE '%BUF_POOL%'),
        0
    )                                               AS buffer_pool_scan_waits,
    'Buffer pool parallel scan is automatic in SQL Server 2022 for large pools.' AS note
FROM sys.dm_os_sys_info AS si;

-- Checkpoint and lazy writer related performance counters
SELECT
    object_name                                     AS counter_object,
    counter_name,
    cntr_value                                      AS counter_value,
    cntr_type
FROM sys.dm_os_performance_counters
WHERE counter_name IN (
    'Checkpoint pages/sec',
    'Lazy writes/sec',
    'Free list stalls/sec',
    'Page life expectancy',
    'Buffer cache hit ratio',
    'Buffer cache hit ratio base',
    'Page lookups/sec',
    'Page reads/sec',
    'Page writes/sec',
    'Background writer pages/sec'
)
ORDER BY counter_name;

/*──────────────────────────────────────────────────────────────────────────────
  Section 8: NUMA Node Memory Distribution
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    node_id                                         AS numa_node_id,
    node_state_desc                                 AS node_state,
    memory_node_id,
    processor_group,
    online_scheduler_count                          AS schedulers_online,
    active_worker_count                             AS active_workers,
    avg_load_balance                                AS avg_load_balance,
    idle_scheduler_count                            AS idle_schedulers
FROM sys.dm_os_nodes
WHERE node_state_desc <> 'ONLINE DAC';

-- NUMA memory allocation
SELECT
    memory_node_id                                  AS numa_memory_node,
    pages_kb / 1024                                 AS allocated_mb,
    locked_page_allocations_kb / 1024               AS locked_page_mb,
    foreign_committed_kb / 1024                     AS foreign_committed_mb,
    shared_memory_committed_kb / 1024               AS shared_memory_mb
FROM sys.dm_os_memory_nodes
WHERE memory_node_id < 64;  -- exclude DAC node

/*──────────────────────────────────────────────────────────────────────────────
  Section 9: Memory Broker Status
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    pool_id,
    memory_broker_type                              AS broker_type,
    allocations_kb / 1024                           AS allocations_mb,
    allocations_kb_per_sec / 1024                   AS allocations_mb_per_sec,
    predicted_allocations_kb / 1024                 AS predicted_allocations_mb,
    target_allocations_kb / 1024                    AS target_allocations_mb,
    last_notification                               AS last_notification_type
FROM sys.dm_os_memory_brokers
ORDER BY allocations_kb DESC;
