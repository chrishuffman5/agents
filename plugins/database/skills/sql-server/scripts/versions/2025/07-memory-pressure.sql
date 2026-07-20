/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Memory Pressure Diagnostics
 *
 * Purpose : Identify memory pressure, buffer pool usage, and memory grants.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Server Memory Overview
 *   2. Memory Clerk Breakdown
 *   3. Buffer Pool Usage by Database
 *   4. Memory Grant Pending & Active
 *   5. Plan Cache Pressure
 *   6. Memory Broker Notifications
 *   7. NUMA Node Memory Distribution
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: Server Memory Overview
------------------------------------------------------------------------------*/
SELECT
    si.physical_memory_kb / 1024                    AS physical_memory_mb,
    si.committed_kb / 1024                          AS committed_memory_mb,
    si.committed_target_kb / 1024                   AS target_memory_mb,
    si.visible_target_kb / 1024                     AS visible_target_mb,
    CAST(si.committed_kb * 100.0
        / NULLIF(si.committed_target_kb, 0) AS DECIMAL(5,2))
                                                    AS memory_utilization_pct,
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Total Server Memory (KB)'
       AND object_name LIKE '%Memory Manager%') / 1024
                                                    AS total_server_memory_mb,
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Target Server Memory (KB)'
       AND object_name LIKE '%Memory Manager%') / 1024
                                                    AS target_server_memory_mb,
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Memory Grants Pending'
       AND object_name LIKE '%Memory Manager%')
                                                    AS memory_grants_pending,
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Memory Grants Outstanding'
       AND object_name LIKE '%Memory Manager%')
                                                    AS memory_grants_outstanding
FROM sys.dm_os_sys_info AS si;

-- Process memory
SELECT
    physical_memory_in_use_kb / 1024                AS physical_memory_in_use_mb,
    locked_page_allocations_kb / 1024               AS locked_pages_mb,
    large_page_allocations_kb / 1024                AS large_pages_mb,
    total_virtual_address_space_kb / 1024           AS total_vas_mb,
    virtual_address_space_reserved_kb / 1024        AS vas_reserved_mb,
    virtual_address_space_committed_kb / 1024       AS vas_committed_mb,
    virtual_address_space_available_kb / 1024       AS vas_available_mb,
    page_fault_count,
    memory_utilization_percentage                   AS memory_util_pct,
    process_physical_memory_low                     AS physical_memory_low,
    process_virtual_memory_low                      AS virtual_memory_low
FROM sys.dm_os_process_memory;

/*------------------------------------------------------------------------------
  Section 2: Memory Clerk Breakdown
  Top 20 memory clerks by allocated size.
------------------------------------------------------------------------------*/
SELECT TOP (20)
    type                                            AS clerk_type,
    name                                            AS clerk_name,
    pages_kb / 1024                                 AS allocated_mb,
    virtual_memory_reserved_kb / 1024               AS virtual_reserved_mb,
    virtual_memory_committed_kb / 1024              AS virtual_committed_mb,
    awe_allocated_kb / 1024                         AS awe_allocated_mb,
    CAST(pages_kb * 100.0 /
        NULLIF((SELECT SUM(pages_kb) FROM sys.dm_os_memory_clerks), 0)
        AS DECIMAL(5,2))                            AS pct_of_total
FROM sys.dm_os_memory_clerks
ORDER BY pages_kb DESC;

/*------------------------------------------------------------------------------
  Section 3: Buffer Pool Usage by Database
------------------------------------------------------------------------------*/
;WITH bp AS (
    SELECT
        database_id,
        COUNT(*) * 8 / 1024                         AS buffer_mb,
        SUM(CAST(is_modified AS INT)) * 8 / 1024    AS dirty_mb,
        COUNT(*)                                    AS page_count,
        SUM(CAST(is_modified AS INT))               AS dirty_page_count
    FROM sys.dm_os_buffer_descriptors
    GROUP BY database_id
)
SELECT
    DB_NAME(bp.database_id)                         AS database_name,
    bp.buffer_mb,
    bp.dirty_mb,
    bp.page_count,
    bp.dirty_page_count,
    CAST(bp.buffer_mb * 100.0 /
        NULLIF(SUM(bp.buffer_mb) OVER (), 0) AS DECIMAL(5,2))
                                                    AS pct_of_buffer_pool
FROM bp
ORDER BY bp.buffer_mb DESC;

/*------------------------------------------------------------------------------
  Section 4: Memory Grant Pending & Active
  Sessions waiting for or holding memory grants.
------------------------------------------------------------------------------*/
SELECT
    mg.session_id,
    mg.request_id,
    mg.grant_time,
    mg.requested_memory_kb / 1024                   AS requested_mb,
    mg.granted_memory_kb / 1024                     AS granted_mb,
    mg.required_memory_kb / 1024                    AS required_mb,
    mg.used_memory_kb / 1024                        AS used_mb,
    mg.max_used_memory_kb / 1024                    AS max_used_mb,
    mg.ideal_memory_kb / 1024                       AS ideal_mb,
    mg.is_small,
    mg.timeout_sec,
    mg.wait_order,
    mg.wait_time_ms,
    mg.dop,
    DB_NAME(er.database_id)                         AS database_name,
    es.login_name,
    es.program_name,
    SUBSTRING(st.text, 1, 300)                      AS query_text
FROM sys.dm_exec_query_memory_grants AS mg
INNER JOIN sys.dm_exec_sessions AS es
    ON mg.session_id = es.session_id
LEFT JOIN sys.dm_exec_requests AS er
    ON mg.session_id = er.session_id
   AND mg.request_id = er.request_id
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) AS st
ORDER BY mg.granted_memory_kb DESC;

/*------------------------------------------------------------------------------
  Section 5: Plan Cache Pressure
  Cache object counts and memory usage by type.
------------------------------------------------------------------------------*/
SELECT
    objtype                                         AS cache_type,
    COUNT(*)                                        AS plan_count,
    SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 AS total_mb,
    AVG(CAST(size_in_bytes AS BIGINT)) / 1024       AS avg_kb,
    SUM(usecounts)                                  AS total_use_count,
    AVG(usecounts)                                  AS avg_use_count,
    SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS single_use_count
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY total_mb DESC;

/*------------------------------------------------------------------------------
  Section 6: Memory Broker Notifications
  Recent memory pressure events from the ring buffer.
------------------------------------------------------------------------------*/
SELECT TOP (20)
    DATEADD(ms, -1 * (si.cpu_ticks / (si.cpu_ticks / si.ms_ticks) - rb.timestamp), GETDATE())
                                                    AS notification_time,
    record.value('(./Record/ResourceMonitor/Notification)[1]', 'VARCHAR(100)')
                                                    AS notification_type,
    record.value('(./Record/ResourceMonitor/IndicatorsProcess)[1]', 'INT')
                                                    AS process_indicator,
    record.value('(./Record/ResourceMonitor/IndicatorsSystem)[1]', 'INT')
                                                    AS system_indicator
FROM (
    SELECT timestamp, CONVERT(XML, record) AS record
    FROM sys.dm_os_ring_buffers
    WHERE ring_buffer_type = N'RING_BUFFER_RESOURCE_MONITOR'
) AS rb
CROSS JOIN sys.dm_os_sys_info AS si
ORDER BY notification_time DESC;

/*------------------------------------------------------------------------------
  Section 7: NUMA Node Memory Distribution
------------------------------------------------------------------------------*/
SELECT
    node_id,
    node_state_desc,
    memory_node_id,
    processor_group,
    online_scheduler_count,
    active_worker_count,
    avg_load_balance,
    idle_scheduler_count
FROM sys.dm_os_nodes
WHERE node_state_desc <> N'ONLINE DAC'
ORDER BY node_id;
