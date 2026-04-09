/*******************************************************************************
 * Script:    07-memory-pressure.sql
 * Purpose:   Memory analysis — buffer pool, clerks, grants, and pressure
 * Version:   SQL Server 2016 (Compatibility Level 130)
 * Date:      2026-04-06
 *
 * Returns:   Buffer pool usage by database, page life expectancy, top memory
 *            clerks, active/pending memory grants, and process memory state.
 *
 * Safety:    Read-only. Safe for production execution.
 ******************************************************************************/

SET NOCOUNT ON;

-- ============================================================================
-- SECTION 1: Page Life Expectancy (PLE) and Key Memory Counters
-- ============================================================================
-- PLE < 300 is the classic threshold, but scale with buffer pool size:
-- A better rule of thumb is PLE > (buffer pool GB * 300 / 4).

SELECT
    pc.object_name                              AS [Object],
    pc.counter_name                             AS [Counter],
    CASE
        WHEN pc.cntr_type = 65792   THEN pc.cntr_value           -- absolute
        WHEN pc.cntr_type = 272696320 THEN pc.cntr_value         -- per-sec (cumulative)
        ELSE pc.cntr_value
    END                                         AS [Value],
    CASE pc.counter_name
        WHEN 'Page life expectancy'
            THEN CASE
                WHEN pc.cntr_value < 300 THEN 'WARNING: Below 300s threshold'
                ELSE 'OK'
            END
        WHEN 'Memory Grants Pending'
            THEN CASE
                WHEN pc.cntr_value > 0 THEN 'WARNING: Queries waiting for memory'
                ELSE 'OK'
            END
        WHEN 'Lazy writes/sec'
            THEN CASE
                WHEN pc.cntr_value > 20 THEN 'ELEVATED — buffer pool under pressure'
                ELSE 'OK'
            END
        ELSE ''
    END                                         AS [Assessment]
FROM sys.dm_os_performance_counters AS pc
WHERE (pc.object_name LIKE '%Buffer Manager%'
       AND pc.counter_name IN (
           'Page life expectancy',
           'Buffer cache hit ratio',
           'Checkpoint pages/sec',
           'Lazy writes/sec',
           'Page reads/sec',
           'Page writes/sec',
           'Free list stalls/sec',
           'Free pages'
       ))
   OR (pc.object_name LIKE '%Memory Manager%'
       AND pc.counter_name IN (
           'Total Server Memory (KB)',
           'Target Server Memory (KB)',
           'Memory Grants Pending',
           'Memory Grants Outstanding',
           'Database Cache Memory (KB)',
           'Free Memory (KB)',
           'Stolen Server Memory (KB)',
           'Connection Memory (KB)',
           'Lock Memory (KB)',
           'Optimizer Memory (KB)',
           'SQL Cache Memory (KB)'
       ))
ORDER BY pc.object_name, pc.counter_name;


-- ============================================================================
-- SECTION 2: Buffer Pool Usage by Database
-- ============================================================================
-- Shows how much of the buffer pool each database consumes.

SELECT
    CASE
        WHEN database_id = 32767 THEN 'Resource DB'
        ELSE COALESCE(DB_NAME(database_id), 'Unknown')
    END                                         AS [Database],
    COUNT(*) * 8 / 1024                         AS [Buffer Pool MB],
    COUNT(*)                                    AS [Pages in Memory],
    CAST(100.0 * COUNT(*)
         / NULLIF(SUM(COUNT(*)) OVER (), 0)
         AS DECIMAL(6,2))                       AS [Pct of Buffer Pool],
    SUM(CAST(is_modified AS INT))               AS [Dirty Pages],
    SUM(CAST(is_modified AS INT)) * 8 / 1024    AS [Dirty MB]
FROM sys.dm_os_buffer_descriptors
GROUP BY database_id
ORDER BY [Buffer Pool MB] DESC;


-- ============================================================================
-- SECTION 3: Top 20 Memory Clerks
-- ============================================================================
-- Memory clerks track allocations within SQL Server components.

SELECT TOP 20
    type                                        AS [Clerk Type],
    name                                        AS [Clerk Name],
    CAST(pages_kb / 1024.0 AS DECIMAL(18,2))   AS [Allocated MB],
    CAST(virtual_memory_reserved_kb / 1024.0
         AS DECIMAL(18,2))                      AS [VM Reserved MB],
    CAST(virtual_memory_committed_kb / 1024.0
         AS DECIMAL(18,2))                      AS [VM Committed MB],
    CAST(awe_allocated_kb / 1024.0
         AS DECIMAL(18,2))                      AS [AWE Allocated MB]
FROM sys.dm_os_memory_clerks
ORDER BY pages_kb DESC;


-- ============================================================================
-- SECTION 4: Memory Grants — Active and Pending
-- ============================================================================
-- Pending grants mean queries are waiting for memory to execute.
-- Large granted memory with low used memory indicates poor cardinality estimates.

SELECT
    mg.session_id                               AS [SPID],
    mg.request_time                             AS [Request Time],
    mg.grant_time                               AS [Grant Time],
    mg.is_next_candidate                        AS [Next Candidate],
    mg.requested_memory_kb / 1024               AS [Requested MB],
    mg.granted_memory_kb / 1024                 AS [Granted MB],
    mg.used_memory_kb / 1024                    AS [Used MB],
    mg.max_used_memory_kb / 1024                AS [Max Used MB],
    mg.required_memory_kb / 1024                AS [Required MB],
    CAST(CASE
        WHEN mg.granted_memory_kb > 0
            THEN 100.0 * mg.used_memory_kb / mg.granted_memory_kb
        ELSE 0
    END AS DECIMAL(6,2))                        AS [Memory Utilisation Pct],
    mg.dop                                      AS [DOP],
    mg.query_cost                               AS [Query Cost],
    mg.timeout_sec                              AS [Timeout Sec],
    mg.wait_time_ms / 1000                      AS [Wait Time Sec],
    CASE
        WHEN mg.grant_time IS NULL THEN 'PENDING — Waiting for memory'
        WHEN mg.used_memory_kb * 1.0 / NULLIF(mg.granted_memory_kb, 0) < 0.1
            THEN 'OVER-GRANTED — <10% utilised'
        ELSE 'Active'
    END                                         AS [Status],
    SUBSTRING(st.text, 1, 200)                  AS [Query Text (200 chars)],
    DB_NAME(r.database_id)                      AS [Database]
FROM sys.dm_exec_query_memory_grants AS mg
LEFT JOIN sys.dm_exec_requests AS r
    ON r.session_id = mg.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
ORDER BY
    CASE WHEN mg.grant_time IS NULL THEN 0 ELSE 1 END,  -- pending first
    mg.requested_memory_kb DESC;


-- ============================================================================
-- SECTION 5: Process Memory State
-- ============================================================================
-- High-level view of SQL Server's memory consumption from the OS perspective.

SELECT
    physical_memory_in_use_kb / 1024            AS [Physical Memory In Use MB],
    locked_page_allocations_kb / 1024           AS [Locked Pages MB],
    large_page_allocations_kb / 1024            AS [Large Pages MB],
    total_virtual_address_space_kb / 1024       AS [Total VAS MB],
    virtual_address_space_reserved_kb / 1024    AS [VAS Reserved MB],
    virtual_address_space_committed_kb / 1024   AS [VAS Committed MB],
    virtual_address_space_available_kb / 1024   AS [VAS Available MB],
    page_fault_count                            AS [Page Faults],
    memory_utilization_percentage               AS [Memory Utilisation Pct],
    process_physical_memory_low                 AS [Physical Memory Low],
    process_virtual_memory_low                  AS [Virtual Memory Low]
FROM sys.dm_os_process_memory;


-- ============================================================================
-- SECTION 6: System Memory State
-- ============================================================================
-- OS-level memory view — detects external memory pressure.

SELECT
    total_physical_memory_kb / 1024             AS [Total Physical MB],
    available_physical_memory_kb / 1024         AS [Available Physical MB],
    total_page_file_kb / 1024                   AS [Total Page File MB],
    available_page_file_kb / 1024               AS [Available Page File MB],
    system_cache_kb / 1024                      AS [System Cache MB],
    kernel_paged_pool_kb / 1024                 AS [Kernel Paged Pool MB],
    kernel_nonpaged_pool_kb / 1024              AS [Kernel Non-Paged Pool MB],
    system_high_memory_signal_state             AS [High Memory Signal],
    system_low_memory_signal_state              AS [Low Memory Signal],
    CASE
        WHEN system_low_memory_signal_state = 1
            THEN 'WARNING: OS reporting low memory'
        WHEN available_physical_memory_kb * 100.0 / NULLIF(total_physical_memory_kb, 0) < 5
            THEN 'WARNING: Less than 5% physical memory available'
        ELSE 'OK'
    END                                         AS [Assessment]
FROM sys.dm_os_sys_memory;


-- ============================================================================
-- SECTION 7: NUMA Node Memory Distribution
-- ============================================================================
-- Uneven distribution across NUMA nodes can cause performance issues.

SELECT
    node_id                                     AS [NUMA Node],
    node_state_desc                             AS [State],
    memory_node_id                              AS [Memory Node],
    processor_group                             AS [Processor Group],
    online_scheduler_count                      AS [Online Schedulers],
    active_worker_count                         AS [Active Workers],
    avg_load_balance                            AS [Avg Load Balance],
    idle_scheduler_count                        AS [Idle Schedulers]
FROM sys.dm_os_nodes
WHERE node_state_desc <> 'ONLINE DAC'
ORDER BY node_id;
