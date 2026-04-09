/******************************************************************************
 * 07-memory-pressure.sql
 * SQL Server 2019 (Compatibility Level 150) — Memory Pressure Diagnostics
 *
 * Enhanced for 2019:
 *   - PVS memory consumption monitoring                                [NEW]
 *     (sys.dm_tran_persistent_version_store_stats)
 *   - Memory grant feedback tracking                                   [NEW]
 *     (row mode + batch mode feedback, visible in plan cache)
 *
 * Safe: read-only, no temp tables, no cursors.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — Memory Clerk Summary (top consumers)
=============================================================================*/
SELECT TOP 30
    mc.type                                 AS clerk_type,
    mc.name                                 AS clerk_name,
    SUM(mc.pages_kb) / 1024                AS allocated_mb,
    SUM(mc.virtual_memory_reserved_kb) / 1024 AS virtual_reserved_mb,
    SUM(mc.virtual_memory_committed_kb) / 1024 AS virtual_committed_mb
FROM sys.dm_os_memory_clerks AS mc
GROUP BY mc.type, mc.name
HAVING SUM(mc.pages_kb) > 0
ORDER BY allocated_mb DESC;

/*=============================================================================
  Section 2 — Buffer Pool Usage by Database
=============================================================================*/
;WITH BufferPool AS (
    SELECT
        database_id,
        COUNT(*)                            AS page_count,
        SUM(CAST(free_space_in_bytes AS BIGINT)) AS total_free_bytes,
        SUM(CASE WHEN is_modified = 1 THEN 1 ELSE 0 END) AS dirty_pages
    FROM sys.dm_os_buffer_descriptors
    GROUP BY database_id
)
SELECT
    ISNULL(DB_NAME(bp.database_id), 'ResourceDB') AS database_name,
    bp.page_count,
    bp.page_count * 8 / 1024               AS buffer_pool_mb,
    bp.dirty_pages,
    bp.dirty_pages * 8 / 1024              AS dirty_pages_mb,
    CAST(100.0 * bp.page_count
         / NULLIF(SUM(bp.page_count) OVER (), 0)
         AS DECIMAL(5,2))                   AS pct_of_buffer_pool,
    CAST(bp.total_free_bytes / 1048576.0
         AS DECIMAL(12,2))                  AS free_space_mb
FROM BufferPool AS bp
ORDER BY bp.page_count DESC;

/*=============================================================================
  Section 3 — Memory Grants (current pending and active)
=============================================================================*/
SELECT
    mg.session_id,
    mg.request_id,
    DB_NAME(st.dbid)                        AS database_name,
    mg.grant_time,
    mg.requested_memory_kb,
    mg.granted_memory_kb,
    mg.required_memory_kb,
    mg.used_memory_kb,
    mg.max_used_memory_kb,
    mg.ideal_memory_kb,
    CASE
        WHEN mg.granted_memory_kb > 0
        THEN CAST(100.0 * mg.used_memory_kb
                   / mg.granted_memory_kb AS DECIMAL(5,2))
        ELSE NULL
    END                                     AS grant_utilization_pct,
    CASE
        WHEN mg.ideal_memory_kb > mg.granted_memory_kb
        THEN 'Under-granted (may spill)'
        WHEN mg.used_memory_kb < mg.granted_memory_kb * 0.25
        THEN 'Over-granted (wasted memory)'
        ELSE 'Appropriately granted'
    END                                     AS grant_assessment,
    mg.is_small,
    mg.timeout_sec,
    mg.resource_semaphore_id,
    mg.wait_order,
    mg.is_next_candidate,
    mg.wait_time_ms,
    mg.dop,
    mg.query_cost,
    st.text                                 AS query_text
FROM sys.dm_exec_query_memory_grants AS mg
CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) AS st
ORDER BY mg.granted_memory_kb DESC;

/*=============================================================================
  Section 4 — Resource Semaphore (memory grant queue pressure)
=============================================================================*/
SELECT
    rs.resource_semaphore_id,
    rs.target_memory_kb / 1024              AS target_memory_mb,
    rs.max_target_memory_kb / 1024          AS max_target_memory_mb,
    rs.total_memory_kb / 1024               AS total_memory_mb,
    rs.available_memory_kb / 1024           AS available_memory_mb,
    rs.granted_memory_kb / 1024             AS granted_memory_mb,
    rs.used_memory_kb / 1024                AS used_memory_mb,
    rs.grantee_count                        AS active_grants,
    rs.waiter_count                         AS waiting_requests,
    rs.timeout_error_count                  AS timeout_errors,
    rs.forced_grant_count                   AS forced_grants,
    CASE
        WHEN rs.waiter_count > 0
        THEN 'PRESSURE: ' + CAST(rs.waiter_count AS VARCHAR(10))
             + ' queries waiting for memory grants'
        ELSE 'No memory grant pressure'
    END                                     AS pressure_assessment
FROM sys.dm_exec_query_resource_semaphores AS rs;

/*=============================================================================
  Section 5 — Persistent Version Store (PVS) Memory Consumption        [NEW]
  ADR uses in-database PVS instead of tempdb version store.
=============================================================================*/
SELECT
    DB_NAME(pvs.database_id)                AS database_name,
    pvs.pvs_page_count,
    (pvs.pvs_page_count * 8)               AS pvs_size_kb,
    (pvs.pvs_page_count * 8) / 1024        AS pvs_size_mb,
    pvs.online_index_version_store_size_kb / 1024
                                            AS online_idx_pvs_mb,
    pvs.current_aborted_transaction_count   AS aborted_txn_count,
    pvs.aborted_version_cleaner_start_time  AS cleanup_start,
    pvs.aborted_version_cleaner_end_time    AS cleanup_end,
    CASE
        WHEN pvs.pvs_page_count * 8 / 1024 > 10240
        THEN 'WARNING: PVS > 10 GB — investigate long-running transactions'
        WHEN pvs.pvs_page_count * 8 / 1024 > 1024
        THEN 'MONITOR: PVS > 1 GB — check for version store growth'
        ELSE 'OK'
    END                                     AS pvs_health_assessment,
    d.is_accelerated_database_recovery_on   AS adr_enabled
FROM sys.dm_tran_persistent_version_store_stats AS pvs
INNER JOIN sys.databases AS d
    ON pvs.database_id = d.database_id
ORDER BY pvs.pvs_page_count DESC;

/*=============================================================================
  Section 6 — Tempdb Version Store vs PVS Comparison                   [NEW]
  With ADR, version store moves from tempdb to in-database PVS.
=============================================================================*/
/* Tempdb version store usage */
SELECT
    'tempdb' AS version_store_location,
    SUM(version_store_reserved_page_count) * 8 / 1024
                                            AS version_store_mb,
    SUM(user_object_reserved_page_count) * 8 / 1024
                                            AS user_object_mb,
    SUM(internal_object_reserved_page_count) * 8 / 1024
                                            AS internal_object_mb
FROM sys.dm_db_file_space_usage
WHERE database_id = 2;

/* PVS per database (replaces tempdb version store for ADR databases) */
SELECT
    DB_NAME(pvs.database_id)                AS database_name,
    'In-Database PVS (ADR)'                 AS version_store_location,
    (pvs.pvs_page_count * 8) / 1024        AS pvs_size_mb,
    pvs.current_aborted_transaction_count   AS aborted_txn_count
FROM sys.dm_tran_persistent_version_store_stats AS pvs
WHERE pvs.pvs_page_count > 0;

/*=============================================================================
  Section 7 — Memory Grant Feedback Tracking                           [NEW]
  Identifies queries where memory grant feedback has adjusted grants.
  Row mode memory grant feedback is NEW in 2019.
=============================================================================*/
;WITH GrantFeedbackCandidates AS (
    SELECT
        qs.plan_handle,
        qs.sql_handle,
        qs.statement_start_offset,
        qs.statement_end_offset,
        qs.execution_count,
        qs.total_grant_kb,
        qs.total_used_grant_kb,
        qs.total_ideal_grant_kb,
        qs.total_spills,
        qs.min_grant_kb,
        qs.max_grant_kb,
        qs.last_grant_kb,
        qs.min_used_grant_kb,
        qs.max_used_grant_kb,
        qs.last_used_grant_kb,
        qs.min_ideal_grant_kb,
        qs.max_ideal_grant_kb,
        qs.last_ideal_grant_kb,
        qs.min_spills,
        qs.max_spills,
        qs.last_spills,
        /* Variance in grants suggests feedback may be active */
        CASE
            WHEN qs.min_grant_kb <> qs.max_grant_kb
            THEN 'Grant size varied — feedback may be active'
            ELSE 'Stable grant size'
        END                                 AS feedback_indicator,
        CASE
            WHEN qs.total_spills > 0
                 AND qs.min_grant_kb < qs.max_grant_kb
            THEN 'Feedback adjusting (had spills, grants vary)'
            WHEN qs.total_grant_kb > 0
                 AND CAST(qs.total_used_grant_kb * 1.0
                           / qs.total_grant_kb AS DECIMAL(5,2)) < 0.25
                 AND qs.min_grant_kb < qs.max_grant_kb
            THEN 'Feedback adjusting (over-granted, grants vary)'
            WHEN qs.total_spills > 0
            THEN 'Candidate for feedback (spills but no variation yet)'
            WHEN qs.total_grant_kb > 0
                 AND CAST(qs.total_used_grant_kb * 1.0
                           / qs.total_grant_kb AS DECIMAL(5,2)) < 0.25
            THEN 'Candidate for feedback (over-granted)'
            ELSE 'No feedback signal'
        END                                 AS feedback_assessment
    FROM sys.dm_exec_query_stats AS qs
    WHERE qs.total_grant_kb > 0
      AND qs.execution_count >= 2
)
SELECT TOP 30
    gfc.execution_count,
    gfc.min_grant_kb,
    gfc.max_grant_kb,
    gfc.last_grant_kb,
    gfc.min_used_grant_kb,
    gfc.max_used_grant_kb,
    gfc.last_used_grant_kb,
    gfc.total_spills,
    gfc.min_spills,
    gfc.max_spills,
    gfc.feedback_indicator,
    gfc.feedback_assessment,
    DB_NAME(st.dbid)                        AS database_name,
    SUBSTRING(
        st.text,
        (gfc.statement_start_offset / 2) + 1,
        (CASE gfc.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE gfc.statement_end_offset
         END - gfc.statement_start_offset) / 2 + 1
    )                                       AS query_text
FROM GrantFeedbackCandidates AS gfc
CROSS APPLY sys.dm_exec_sql_text(gfc.sql_handle) AS st
WHERE gfc.feedback_assessment <> 'No feedback signal'
ORDER BY gfc.total_spills DESC, gfc.total_grant_kb DESC;

/*=============================================================================
  Section 8 — Process Memory Summary
=============================================================================*/
SELECT
    physical_memory_in_use_kb / 1024        AS physical_memory_in_use_mb,
    locked_page_allocations_kb / 1024       AS locked_pages_mb,
    large_page_allocations_kb / 1024        AS large_pages_mb,
    total_virtual_address_space_kb / 1024   AS total_vas_mb,
    virtual_address_space_reserved_kb / 1024 AS vas_reserved_mb,
    virtual_address_space_committed_kb / 1024 AS vas_committed_mb,
    virtual_address_space_available_kb / 1024 AS vas_available_mb,
    page_fault_count,
    memory_utilization_percentage           AS memory_util_pct,
    process_physical_memory_low             AS physical_memory_low,
    process_virtual_memory_low              AS virtual_memory_low
FROM sys.dm_os_process_memory;

/*=============================================================================
  Section 9 — System Memory State
=============================================================================*/
SELECT
    total_physical_memory_kb / 1024         AS total_physical_mb,
    available_physical_memory_kb / 1024     AS available_physical_mb,
    total_page_file_kb / 1024               AS total_page_file_mb,
    available_page_file_kb / 1024           AS available_page_file_mb,
    system_cache_kb / 1024                  AS system_cache_mb,
    kernel_paged_pool_kb / 1024             AS kernel_paged_pool_mb,
    kernel_nonpaged_pool_kb / 1024          AS kernel_nonpaged_pool_mb,
    system_high_memory_signal_state         AS high_memory_signal,
    system_low_memory_signal_state          AS low_memory_signal,
    system_memory_state_desc                AS memory_state
FROM sys.dm_os_sys_memory;
