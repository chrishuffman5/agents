/******************************************************************************
* Script:   07-memory-pressure.sql
* Purpose:  Memory pressure diagnostics including buffer pool usage, memory
*           grants, memory clerks, NUMA distribution, and PLE analysis.
* Server:   SQL Server 2017 (compatibility level 140)
* Date:     2026-04-06
*
* Safety:   Read-only. No modifications to server or databases.
******************************************************************************/
SET NOCOUNT ON;

-- ============================================================================
-- Section 1: Overall Memory Configuration and Status
-- ============================================================================
PRINT '=== Section 1: Memory Configuration and Status ===';
PRINT '';

SELECT
    si.physical_memory_kb / 1024                    AS [Physical Memory MB],
    si.committed_kb / 1024                          AS [SQL Committed MB],
    si.committed_target_kb / 1024                   AS [SQL Target MB],
    CAST(100.0 * si.committed_kb
        / NULLIF(si.committed_target_kb, 0)
        AS DECIMAL(5,2))                            AS [Committed Pct of Target],
    (SELECT CAST(value_in_use AS INT)
     FROM sys.configurations
     WHERE name = 'max server memory (MB)')         AS [Max Server Memory MB],
    (SELECT CAST(value_in_use AS INT)
     FROM sys.configurations
     WHERE name = 'min server memory (MB)')         AS [Min Server Memory MB]
FROM sys.dm_os_sys_info si;

-- ============================================================================
-- Section 2: OS Memory Status
-- ============================================================================
PRINT '';
PRINT '=== Section 2: OS-Level Memory Status ===';
PRINT '';

SELECT
    total_physical_memory_kb / 1024                 AS [Total Physical MB],
    available_physical_memory_kb / 1024             AS [Available Physical MB],
    total_page_file_kb / 1024                       AS [Total Page File MB],
    available_page_file_kb / 1024                   AS [Available Page File MB],
    system_memory_state_desc                        AS [Memory State],
    CAST(100.0 * available_physical_memory_kb
        / NULLIF(total_physical_memory_kb, 0)
        AS DECIMAL(5,2))                            AS [Available Pct],
    CASE
        WHEN available_physical_memory_kb * 100 / NULLIF(total_physical_memory_kb, 0) < 5
        THEN 'CRITICAL -- Less than 5% available'
        WHEN available_physical_memory_kb * 100 / NULLIF(total_physical_memory_kb, 0) < 10
        THEN 'WARNING -- Less than 10% available'
        ELSE 'OK'
    END                                             AS [Assessment]
FROM sys.dm_os_sys_memory;

-- ============================================================================
-- Section 3: SQL Server Process Memory
-- ============================================================================
PRINT '';
PRINT '=== Section 3: SQL Server Process Memory ===';
PRINT '';

SELECT
    physical_memory_in_use_kb / 1024                AS [Physical Memory In Use MB],
    virtual_address_space_committed_kb / 1024       AS [Virtual Committed MB],
    virtual_address_space_reserved_kb / 1024        AS [Virtual Reserved MB],
    large_page_allocations_kb / 1024                AS [Large Page Alloc MB],
    locked_page_allocations_kb / 1024               AS [Locked Page Alloc MB],
    memory_utilization_percentage                   AS [Memory Utilization Pct],
    process_physical_memory_low                     AS [Process Memory Low],
    process_virtual_memory_low                      AS [Process Virtual Low],
    CASE
        WHEN process_physical_memory_low = 1
        THEN 'WARNING -- SQL Server is under physical memory pressure'
        WHEN process_virtual_memory_low = 1
        THEN 'WARNING -- SQL Server is under virtual memory pressure'
        ELSE 'OK'
    END                                             AS [Assessment]
FROM sys.dm_os_process_memory;

-- ============================================================================
-- Section 4: Page Life Expectancy (PLE) per NUMA Node
-- ============================================================================
PRINT '';
PRINT '=== Section 4: Page Life Expectancy (PLE) ===';
PRINT '';

SELECT
    object_name                                     AS [Object],
    instance_name                                   AS [NUMA Node / Instance],
    cntr_value                                      AS [PLE Seconds],
    CAST(cntr_value / 60.0 AS DECIMAL(10,1))        AS [PLE Minutes],
    CASE
        WHEN cntr_value < 300
        THEN 'CRITICAL -- PLE below 300 seconds indicates severe memory pressure'
        WHEN cntr_value < 600
        THEN 'WARNING -- PLE below 600 seconds indicates moderate memory pressure'
        WHEN cntr_value < 1800
        THEN 'MONITOR -- PLE is acceptable but could be higher'
        ELSE 'GOOD -- Healthy PLE'
    END                                             AS [Assessment]
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page life expectancy'
  AND object_name LIKE '%Buffer%';

-- ============================================================================
-- Section 5: Buffer Pool Usage by Database
-- ============================================================================
PRINT '';
PRINT '=== Section 5: Buffer Pool Usage by Database ===';
PRINT '';

;WITH BufferPoolByDB AS (
    SELECT
        database_id,
        COUNT(*) AS page_count,
        SUM(CAST(free_space_in_bytes AS BIGINT)) AS free_space_bytes,
        SUM(CASE WHEN is_modified = 1 THEN 1 ELSE 0 END) AS dirty_pages
    FROM sys.dm_os_buffer_descriptors
    GROUP BY database_id
)
SELECT
    CASE
        WHEN bp.database_id = 32767 THEN 'Resource DB'
        ELSE ISNULL(DB_NAME(bp.database_id),
             'DB ID: ' + CAST(bp.database_id AS VARCHAR(10)))
    END                                             AS [Database],
    bp.page_count                                   AS [Pages in Buffer],
    CAST(bp.page_count * 8.0 / 1024
        AS DECIMAL(12,2))                           AS [Buffer Size MB],
    CAST(100.0 * bp.page_count
        / NULLIF(SUM(bp.page_count) OVER (), 0)
        AS DECIMAL(5,2))                            AS [Pct of Buffer Pool],
    bp.dirty_pages                                  AS [Dirty Pages],
    CAST(bp.dirty_pages * 8.0 / 1024
        AS DECIMAL(12,2))                           AS [Dirty Pages MB],
    CAST(bp.free_space_bytes / 1048576.0
        AS DECIMAL(12,2))                           AS [Free Space in Pages MB]
FROM BufferPoolByDB bp
ORDER BY bp.page_count DESC;

-- ============================================================================
-- Section 6: Memory Clerks (Top Consumers)
-- ============================================================================
PRINT '';
PRINT '=== Section 6: Top Memory Clerks ===';
PRINT '';

SELECT TOP 20
    type                                            AS [Memory Clerk],
    name                                            AS [Clerk Name],
    CAST(pages_kb / 1024.0 AS DECIMAL(12,2))        AS [Allocated MB],
    CAST(virtual_memory_reserved_kb / 1024.0
        AS DECIMAL(12,2))                           AS [Virtual Reserved MB],
    CAST(virtual_memory_committed_kb / 1024.0
        AS DECIMAL(12,2))                           AS [Virtual Committed MB],
    CAST(awe_allocated_kb / 1024.0
        AS DECIMAL(12,2))                           AS [AWE Allocated MB]
FROM sys.dm_os_memory_clerks
WHERE pages_kb > 0
ORDER BY pages_kb DESC;

-- ============================================================================
-- Section 7: Memory Grants (Currently Pending and Executing)
-- ============================================================================
PRINT '';
PRINT '=== Section 7: Memory Grants ===';
PRINT '';

SELECT
    mg.session_id                                   AS [Session ID],
    mg.request_id                                   AS [Request ID],
    mg.requested_memory_kb / 1024                   AS [Requested MB],
    mg.granted_memory_kb / 1024                     AS [Granted MB],
    mg.required_memory_kb / 1024                    AS [Required MB],
    mg.used_memory_kb / 1024                        AS [Used MB],
    mg.max_used_memory_kb / 1024                    AS [Max Used MB],
    mg.ideal_memory_kb / 1024                       AS [Ideal MB],
    CASE
        WHEN mg.grant_time IS NULL
        THEN 'PENDING -- Waiting for memory grant'
        ELSE 'GRANTED'
    END                                             AS [Grant Status],
    mg.queue_id                                     AS [Queue ID],
    mg.wait_order                                   AS [Wait Order],
    mg.wait_time_ms                                 AS [Wait Time Ms],
    mg.is_small                                     AS [Is Small Grant],
    mg.query_cost                                   AS [Query Cost],
    mg.dop                                          AS [DOP],
    CASE
        WHEN mg.granted_memory_kb > 0
         AND mg.max_used_memory_kb * 1.0 / mg.granted_memory_kb < 0.1
        THEN 'OVER-GRANTED -- Wasting memory'
        WHEN mg.granted_memory_kb > 0
         AND mg.max_used_memory_kb * 1.0 / mg.granted_memory_kb > 0.9
        THEN 'TIGHT -- Near full utilization, possible spill'
        ELSE 'Normal'
    END                                             AS [Grant Assessment],
    st.text                                         AS [Query Text]
FROM sys.dm_exec_query_memory_grants mg
OUTER APPLY sys.dm_exec_sql_text(mg.sql_handle) st
ORDER BY
    CASE WHEN mg.grant_time IS NULL THEN 0 ELSE 1 END,  -- Pending first
    mg.requested_memory_kb DESC;

-- Count pending grants
SELECT
    COUNT(*)                                        AS [Total Active Grants],
    SUM(CASE WHEN grant_time IS NULL THEN 1 ELSE 0 END)
                                                    AS [Pending Grants],
    SUM(granted_memory_kb) / 1024                   AS [Total Granted MB],
    SUM(used_memory_kb) / 1024                      AS [Total Used MB],
    SUM(requested_memory_kb) / 1024                 AS [Total Requested MB],
    CASE
        WHEN SUM(CASE WHEN grant_time IS NULL THEN 1 ELSE 0 END) > 0
        THEN 'WARNING -- Queries waiting for memory grants (RESOURCE_SEMAPHORE)'
        ELSE 'OK -- No pending memory grants'
    END                                             AS [Assessment]
FROM sys.dm_exec_query_memory_grants;

-- ============================================================================
-- Section 8: Memory-Related Performance Counters
-- ============================================================================
PRINT '';
PRINT '=== Section 8: Key Memory Performance Counters ===';
PRINT '';

SELECT
    object_name                                     AS [Object],
    counter_name                                    AS [Counter],
    instance_name                                   AS [Instance],
    cntr_value                                      AS [Value],
    CASE counter_name
        WHEN 'Page life expectancy'
            THEN 'Seconds a page stays in buffer pool'
        WHEN 'Buffer cache hit ratio'
            THEN 'Pct of pages found in buffer (should be > 99%)'
        WHEN 'Lazy writes/sec'
            THEN 'Pages written by lazy writer (high = memory pressure)'
        WHEN 'Free list stalls/sec'
            THEN 'Requests that had to wait for a free page (should be 0)'
        WHEN 'Memory Grants Pending'
            THEN 'Queries waiting for memory grant (should be 0)'
        WHEN 'Memory Grants Outstanding'
            THEN 'Queries currently holding memory grants'
        WHEN 'Target Server Memory (KB)'
            THEN 'Amount of memory SQL Server wants'
        WHEN 'Total Server Memory (KB)'
            THEN 'Amount of memory SQL Server is using'
        ELSE ''
    END                                             AS [Description]
FROM sys.dm_os_performance_counters
WHERE counter_name IN (
    'Page life expectancy',
    'Buffer cache hit ratio',
    'Lazy writes/sec',
    'Free list stalls/sec',
    'Memory Grants Pending',
    'Memory Grants Outstanding',
    'Target Server Memory (KB)',
    'Total Server Memory (KB)',
    'Stolen pages',
    'Database pages',
    'Free pages'
)
AND (object_name LIKE '%Buffer Manager%'
     OR object_name LIKE '%Memory Manager%')
ORDER BY object_name, counter_name;

-- ============================================================================
-- Section 9: NUMA Node Memory Distribution
-- ============================================================================
PRINT '';
PRINT '=== Section 9: NUMA Node Memory Distribution ===';
PRINT '';

SELECT
    node_id                                         AS [NUMA Node],
    node_state_desc                                 AS [State],
    memory_node_id                                  AS [Memory Node],
    processor_group                                 AS [Processor Group],
    online_scheduler_count                          AS [Online Schedulers],
    active_worker_count                             AS [Active Workers],
    avg_load_balance_percent                        AS [Avg Load Balance Pct],
    idle_scheduler_count                            AS [Idle Schedulers]
FROM sys.dm_os_nodes
WHERE node_state_desc <> 'ONLINE DAC'
ORDER BY node_id;

-- ============================================================================
-- Section 10: Plan Cache Memory Usage
-- ============================================================================
PRINT '';
PRINT '=== Section 10: Plan Cache Memory Usage ===';
PRINT '';

SELECT
    objtype                                         AS [Cache Object Type],
    COUNT(*)                                        AS [Plan Count],
    SUM(size_in_bytes) / 1048576                    AS [Size MB],
    AVG(usecounts)                                  AS [Avg Use Count],
    SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS [Single-Use Plans],
    CASE
        WHEN SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) * 100
            / NULLIF(COUNT(*), 0) > 50
        THEN 'WARNING -- Many single-use plans. Consider optimize for ad hoc workloads.'
        ELSE 'OK'
    END                                             AS [Assessment]
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY SUM(size_in_bytes) DESC;

-- Total plan cache with single-use plan percentage
SELECT
    COUNT(*) AS [Total Cached Plans],
    SUM(size_in_bytes) / 1048576 AS [Total Plan Cache MB],
    SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS [Single-Use Plans],
    SUM(CASE WHEN usecounts = 1 THEN size_in_bytes ELSE 0 END) / 1048576
        AS [Single-Use Plans MB],
    CAST(100.0 * SUM(CASE WHEN usecounts = 1 THEN size_in_bytes ELSE 0 END)
        / NULLIF(SUM(size_in_bytes), 0) AS DECIMAL(5,2))
        AS [Single-Use Pct by Size]
FROM sys.dm_exec_cached_plans;

PRINT '';
PRINT '=== Memory Pressure Analysis Complete ===';
