/******************************************************************************
 * 06-blocking.sql
 * SQL Server 2019 (Compatibility Level 150) — Blocking & Deadlock Analysis
 *
 * Enhanced for 2019:
 *   - sys.dm_exec_requests.dop for blocked parallel queries            [NEW]
 *   - sys.dm_exec_requests.parallel_worker_count                       [NEW]
 *   - ADR impact on blocking (faster recovery = shorter blocks)        [NEW]
 *
 * Safe: read-only, no temp tables, no cursors.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — Current Blocking Chains
  Enhanced with DOP and parallel_worker_count.                          [NEW]
=============================================================================*/
;WITH BlockingChain AS (
    SELECT
        r.session_id                        AS blocked_session_id,
        r.blocking_session_id               AS blocking_session_id,
        r.wait_type,
        r.wait_time                         AS wait_time_ms,
        r.wait_resource,
        r.status                            AS request_status,
        r.command,
        r.cpu_time                          AS cpu_time_ms,
        r.total_elapsed_time                AS elapsed_time_ms,
        r.reads,
        r.writes,
        r.logical_reads,
        r.row_count,
        r.granted_query_memory * 8          AS granted_memory_kb,
        r.dop,                                                      -- [NEW 2019]
        r.parallel_worker_count,                                    -- [NEW 2019]
        r.transaction_isolation_level,
        CASE r.transaction_isolation_level
            WHEN 0 THEN 'Unspecified'
            WHEN 1 THEN 'Read Uncommitted'
            WHEN 2 THEN 'Read Committed'
            WHEN 3 THEN 'Repeatable Read'
            WHEN 4 THEN 'Serializable'
            WHEN 5 THEN 'Snapshot'
            ELSE CAST(r.transaction_isolation_level AS VARCHAR(10))
        END                                 AS isolation_level_desc,
        DB_NAME(r.database_id)              AS database_name,
        r.sql_handle,
        r.plan_handle,
        r.statement_start_offset,
        r.statement_end_offset
    FROM sys.dm_exec_requests AS r
    WHERE r.blocking_session_id > 0
)
SELECT
    bc.blocked_session_id,
    bc.blocking_session_id,
    bc.wait_type,
    bc.wait_time_ms,
    bc.wait_resource,
    bc.request_status,
    bc.command,
    bc.cpu_time_ms,
    bc.elapsed_time_ms,
    bc.logical_reads,
    bc.granted_memory_kb,
    bc.dop,                                                         -- [NEW]
    bc.parallel_worker_count,                                       -- [NEW]
    bc.isolation_level_desc,
    bc.database_name,
    /* Blocked query text */
    SUBSTRING(
        blocked_st.text,
        (bc.statement_start_offset / 2) + 1,
        (CASE bc.statement_end_offset
            WHEN -1 THEN DATALENGTH(blocked_st.text)
            ELSE bc.statement_end_offset
         END - bc.statement_start_offset) / 2 + 1
    )                                       AS blocked_query_text,
    /* Blocking query text */
    blocker_st.text                         AS blocking_query_text,
    /* Blocker session details */
    bs.login_name                           AS blocker_login,
    bs.host_name                            AS blocker_host,
    bs.program_name                         AS blocker_program,
    bs.status                               AS blocker_status,
    bs.last_request_start_time              AS blocker_last_request_start,
    /* Blocking request DOP if still active */
    br.dop                                  AS blocker_dop,          -- [NEW]
    br.parallel_worker_count                AS blocker_parallel_workers, -- [NEW]
    br.command                              AS blocker_command,
    br.wait_type                            AS blocker_wait_type,
    br.wait_time                            AS blocker_wait_time_ms
FROM BlockingChain AS bc
CROSS APPLY sys.dm_exec_sql_text(bc.sql_handle) AS blocked_st
LEFT JOIN sys.dm_exec_sessions AS bs
    ON bc.blocking_session_id = bs.session_id
LEFT JOIN sys.dm_exec_requests AS br
    ON bc.blocking_session_id = br.session_id
OUTER APPLY sys.dm_exec_sql_text(br.sql_handle) AS blocker_st
ORDER BY bc.wait_time_ms DESC;

/*=============================================================================
  Section 2 — Blocking Chain Hierarchy (head blockers)
=============================================================================*/
;WITH BlockerHierarchy AS (
    /* Find head blockers (sessions that block others but are not blocked) */
    SELECT DISTINCT
        r.blocking_session_id               AS head_blocker_session_id
    FROM sys.dm_exec_requests AS r
    WHERE r.blocking_session_id > 0
      AND r.blocking_session_id NOT IN (
          SELECT r2.session_id
          FROM sys.dm_exec_requests AS r2
          WHERE r2.blocking_session_id > 0
      )
),
BlockedCount AS (
    SELECT
        r.blocking_session_id,
        COUNT(*)                            AS blocked_session_count,
        MAX(r.wait_time)                    AS max_wait_time_ms,
        SUM(r.logical_reads)                AS total_blocked_reads,
        MAX(r.dop)                          AS max_blocked_dop      -- [NEW]
    FROM sys.dm_exec_requests AS r
    WHERE r.blocking_session_id > 0
    GROUP BY r.blocking_session_id
)
SELECT
    bh.head_blocker_session_id,
    s.login_name                            AS blocker_login,
    s.host_name                             AS blocker_host,
    s.program_name                          AS blocker_program,
    s.status                                AS blocker_session_status,
    bc.blocked_session_count,
    bc.max_wait_time_ms,
    bc.total_blocked_reads,
    bc.max_blocked_dop                      AS max_blocked_query_dop, -- [NEW]
    DB_NAME(r.database_id)                  AS database_name,
    r.command                               AS blocker_command,
    r.status                                AS blocker_request_status,
    r.dop                                   AS blocker_dop,          -- [NEW]
    r.parallel_worker_count                 AS blocker_workers,      -- [NEW]
    st.text                                 AS blocker_query_text,
    /* Check if head blocker is in an open transaction */
    tat.transaction_id                      AS open_transaction_id,
    tat.name                                AS transaction_name,
    tat.transaction_begin_time,
    DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE())
                                            AS transaction_age_sec,
    tat.transaction_type,
    CASE tat.transaction_type
        WHEN 1 THEN 'Read/Write'
        WHEN 2 THEN 'Read-Only'
        WHEN 3 THEN 'System'
        WHEN 4 THEN 'Distributed'
        ELSE CAST(tat.transaction_type AS VARCHAR(10))
    END                                     AS transaction_type_desc,
    tat.transaction_state,
    CASE tat.transaction_state
        WHEN 0 THEN 'Not fully initialized'
        WHEN 1 THEN 'Initialized, not started'
        WHEN 2 THEN 'Active'
        WHEN 3 THEN 'Ended (read-only)'
        WHEN 4 THEN 'Commit initiated'
        WHEN 5 THEN 'Prepared, awaiting resolution'
        WHEN 6 THEN 'Committed'
        WHEN 7 THEN 'Rolling back'
        WHEN 8 THEN 'Rolled back'
        ELSE CAST(tat.transaction_state AS VARCHAR(10))
    END                                     AS transaction_state_desc
FROM BlockerHierarchy AS bh
INNER JOIN sys.dm_exec_sessions AS s
    ON bh.head_blocker_session_id = s.session_id
LEFT JOIN BlockedCount AS bc
    ON bh.head_blocker_session_id = bc.blocking_session_id
LEFT JOIN sys.dm_exec_requests AS r
    ON bh.head_blocker_session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
LEFT JOIN sys.dm_tran_session_transactions AS tst
    ON bh.head_blocker_session_id = tst.session_id
LEFT JOIN sys.dm_tran_active_transactions AS tat
    ON tst.transaction_id = tat.transaction_id
ORDER BY bc.blocked_session_count DESC;

/*=============================================================================
  Section 3 — Lock Summary by Resource Type
=============================================================================*/
SELECT
    DB_NAME(tl.resource_database_id)        AS database_name,
    tl.resource_type,
    tl.request_mode                         AS lock_mode,
    tl.request_status                       AS lock_status,
    COUNT(*)                                AS lock_count
FROM sys.dm_tran_locks AS tl
WHERE tl.resource_database_id > 0
GROUP BY
    tl.resource_database_id,
    tl.resource_type,
    tl.request_mode,
    tl.request_status
ORDER BY lock_count DESC;

/*=============================================================================
  Section 4 — ADR Impact on Blocking                                   [NEW]
  Shows databases with ADR enabled (faster rollback = shorter blocks).
=============================================================================*/
SELECT
    d.name                                  AS database_name,
    d.is_accelerated_database_recovery_on   AS adr_enabled,
    pvs.pvs_page_count,
    (pvs.pvs_page_count * 8) / 1024        AS pvs_size_mb,
    pvs.current_aborted_transaction_count   AS aborted_txn_count,
    pvs.aborted_version_cleaner_start_time  AS last_cleanup_start,
    CASE
        WHEN d.is_accelerated_database_recovery_on = 1
        THEN 'ADR enabled: instant rollback, reduced blocking duration'
        ELSE 'Standard recovery: rollback time proportional to transaction size'
    END                                     AS recovery_mode_impact
FROM sys.databases AS d
LEFT JOIN sys.dm_tran_persistent_version_store_stats AS pvs
    ON d.database_id = pvs.database_id
WHERE d.state = 0  /* ONLINE */
ORDER BY d.name;

/*=============================================================================
  Section 5 — Recent Deadlock Information (from system_health XE)
=============================================================================*/
;WITH DeadlockEvents AS (
    SELECT
        xed.value('(@timestamp)[1]', 'DATETIME2') AS deadlock_time,
        xed.query('.')                      AS deadlock_graph_xml
    FROM (
        SELECT CAST(target_data AS XML) AS target_xml
        FROM sys.dm_xe_session_targets AS xst
        INNER JOIN sys.dm_xe_sessions AS xs
            ON xst.event_session_address = xs.address
        WHERE xs.name = 'system_health'
          AND xst.target_name = 'ring_buffer'
    ) AS rb
    CROSS APPLY target_xml.nodes(
        'RingBufferTarget/event[@name="xml_deadlock_report"]'
    ) AS xed_table(xed)
)
SELECT TOP 10
    de.deadlock_time,
    de.deadlock_graph_xml
FROM DeadlockEvents AS de
ORDER BY de.deadlock_time DESC;
