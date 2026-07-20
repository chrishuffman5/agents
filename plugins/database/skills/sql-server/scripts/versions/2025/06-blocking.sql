/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Blocking Analysis
 *
 * Purpose : Identify and analyze blocking chains with optimized locking
 *           impact analysis (NEW in 2025).
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Current Blocking Chains
 *   2. Optimized Locking Impact Analysis (NEW in 2025)
 *   3. Lock Details (TID vs Traditional Locks)
 *   4. Head Blockers
 *   5. Blocking Duration Analysis
 *   6. Deadlock Summary (from system_health XEvent)
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: Current Blocking Chains
  Shows blocker -> blocked relationships with wait type classification.
------------------------------------------------------------------------------*/
;WITH blocking_tree AS (
    SELECT
        er.session_id,
        er.blocking_session_id,
        er.wait_type,
        er.wait_time                                AS wait_time_ms,
        er.wait_resource,
        er.status,
        er.command,
        DB_NAME(er.database_id)                     AS database_name,
        er.cpu_time,
        er.logical_reads,
        er.row_count,
        es.login_name,
        es.host_name,
        es.program_name,
        SUBSTRING(st.text,
            (er.statement_start_offset / 2) + 1,
            (CASE er.statement_end_offset
                WHEN -1 THEN DATALENGTH(st.text)
                ELSE er.statement_end_offset
             END - er.statement_start_offset) / 2 + 1)
                                                    AS current_statement,
        -- NEW in 2025: classify lock type
        CASE
            WHEN er.wait_type LIKE N'LCK_M_S_XACT%'
            THEN 'Optimized Locking (TID)'
            WHEN er.wait_type LIKE N'LCK_M_%'
            THEN 'Traditional Lock'
            ELSE COALESCE(er.wait_type, 'N/A')
        END                                         AS lock_mechanism
    FROM sys.dm_exec_requests AS er
    INNER JOIN sys.dm_exec_sessions AS es
        ON er.session_id = es.session_id
    CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) AS st
    WHERE er.blocking_session_id > 0
)
SELECT
    bt.blocking_session_id                          AS blocker_spid,
    bt.session_id                                   AS blocked_spid,
    bt.wait_type,
    bt.wait_time_ms,
    bt.wait_resource,
    bt.lock_mechanism,                                                         -- NEW in 2025
    bt.database_name,
    bt.status,
    bt.command,
    bt.login_name,
    bt.host_name,
    bt.program_name,
    bt.current_statement,
    -- Blocker's statement
    (SELECT SUBSTRING(st2.text, 1, 200)
     FROM sys.dm_exec_requests AS er2
     CROSS APPLY sys.dm_exec_sql_text(er2.sql_handle) AS st2
     WHERE er2.session_id = bt.blocking_session_id)  AS blocker_statement
FROM blocking_tree AS bt
ORDER BY bt.wait_time_ms DESC;

/*------------------------------------------------------------------------------
  Section 2: Optimized Locking Impact Analysis -- NEW in 2025
  Compare TID (XACT) locking vs traditional locking patterns.
  When optimized locking is enabled, you should see mostly XACT resource types
  instead of KEY/RID/PAGE locks held until end of transaction.
------------------------------------------------------------------------------*/
-- 2a. Per-database optimized locking configuration
SELECT
    d.name                                          AS database_name,
    d.is_accelerated_database_recovery_on           AS adr_enabled,
    d.is_read_committed_snapshot_on                 AS rcsi_enabled,
    d.is_optimized_locking_on                       AS optimized_locking,
    CASE
        WHEN d.is_optimized_locking_on = 1
         AND d.is_read_committed_snapshot_on = 1
        THEN 'Full benefit (TID + LAQ)'
        WHEN d.is_optimized_locking_on = 1
        THEN 'Partial (TID only, enable RCSI for LAQ)'
        ELSE 'Traditional locking'
    END                                             AS locking_mode
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.state = 0
ORDER BY d.name;

-- 2b. Current lock distribution: XACT (TID) vs traditional resource types
SELECT
    resource_type,
    request_mode,
    COUNT(*)                                        AS lock_count,
    CASE
        WHEN resource_type = 'XACT'
        THEN 'Optimized Locking (TID)'
        WHEN resource_type IN ('KEY', 'RID', 'PAGE')
        THEN 'Traditional (row/page)'
        ELSE 'Other'
    END                                             AS lock_category,
    COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (), 0)
                                                    AS pct_of_total
FROM sys.dm_tran_locks
WHERE resource_database_id > 4
GROUP BY resource_type, request_mode
ORDER BY lock_count DESC;

-- 2c. Session-level lock summary showing TID locking efficiency
SELECT
    tl.request_session_id                           AS session_id,
    DB_NAME(tl.resource_database_id)                AS database_name,
    SUM(CASE WHEN tl.resource_type = 'XACT' THEN 1 ELSE 0 END)
                                                    AS xact_tid_locks,
    SUM(CASE WHEN tl.resource_type IN ('KEY', 'RID') THEN 1 ELSE 0 END)
                                                    AS row_key_locks,
    SUM(CASE WHEN tl.resource_type = 'PAGE' THEN 1 ELSE 0 END)
                                                    AS page_locks,
    SUM(CASE WHEN tl.resource_type = 'OBJECT' THEN 1 ELSE 0 END)
                                                    AS object_locks,
    COUNT(*)                                        AS total_locks,
    es.login_name,
    es.program_name
FROM sys.dm_tran_locks AS tl
INNER JOIN sys.dm_exec_sessions AS es
    ON tl.request_session_id = es.session_id
WHERE tl.resource_database_id > 4
  AND es.is_user_process = 1
GROUP BY tl.request_session_id, tl.resource_database_id,
         es.login_name, es.program_name
HAVING COUNT(*) > 1
ORDER BY total_locks DESC;

/*------------------------------------------------------------------------------
  Section 3: Lock Details (TID vs Traditional)
  Shows current lock grants and waits with resource type classification.
------------------------------------------------------------------------------*/
SELECT TOP (100)
    tl.request_session_id                           AS session_id,
    DB_NAME(tl.resource_database_id)                AS database_name,
    tl.resource_type,
    tl.resource_subtype,
    tl.resource_description,
    tl.resource_associated_entity_id,
    tl.request_mode,
    tl.request_status,
    tl.request_owner_type,
    -- NEW in 2025: identify XACT/TID locks from optimized locking
    CASE
        WHEN tl.resource_type = 'XACT'
        THEN 'TID Lock (Optimized Locking)'
        ELSE tl.resource_type
    END                                             AS lock_description,
    es.login_name,
    es.program_name
FROM sys.dm_tran_locks AS tl
INNER JOIN sys.dm_exec_sessions AS es
    ON tl.request_session_id = es.session_id
WHERE es.is_user_process = 1
  AND tl.resource_database_id > 4
ORDER BY tl.request_status DESC, tl.resource_type;

/*------------------------------------------------------------------------------
  Section 4: Head Blockers
  Identifies sessions at the root of blocking chains.
------------------------------------------------------------------------------*/
;WITH blockers AS (
    SELECT DISTINCT blocking_session_id AS session_id
    FROM sys.dm_exec_requests
    WHERE blocking_session_id > 0
),
blocked AS (
    SELECT DISTINCT session_id
    FROM sys.dm_exec_requests
    WHERE blocking_session_id > 0
)
SELECT
    b.session_id                                    AS head_blocker_spid,
    es.login_name,
    es.host_name,
    es.program_name,
    es.status                                       AS session_status,
    er.command,
    er.wait_type                                    AS blocker_wait_type,
    er.wait_time                                    AS blocker_wait_ms,
    DB_NAME(COALESCE(er.database_id, es.database_id)) AS database_name,
    (SELECT COUNT(*)
     FROM sys.dm_exec_requests AS er2
     WHERE er2.blocking_session_id = b.session_id)   AS blocked_session_count,
    COALESCE(
        SUBSTRING(st.text, 1, 500),
        '(No active request - idle blocker)')        AS blocker_query
FROM blockers AS b
LEFT JOIN blocked AS bl
    ON b.session_id = bl.session_id
INNER JOIN sys.dm_exec_sessions AS es
    ON b.session_id = es.session_id
LEFT JOIN sys.dm_exec_requests AS er
    ON b.session_id = er.session_id
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) AS st
WHERE bl.session_id IS NULL                         -- head of chain only
ORDER BY blocked_session_count DESC;

/*------------------------------------------------------------------------------
  Section 5: Blocking Duration Analysis
  Sessions blocked for more than 5 seconds.
------------------------------------------------------------------------------*/
SELECT
    owt.session_id                                  AS blocked_spid,
    owt.blocking_session_id                         AS blocker_spid,
    owt.wait_type,
    owt.wait_duration_ms,
    owt.wait_duration_ms / 1000                     AS wait_seconds,
    owt.resource_description,
    DB_NAME(er.database_id)                         AS database_name,
    es.login_name,
    es.host_name,
    SUBSTRING(st.text, 1, 300)                      AS blocked_query
FROM sys.dm_os_waiting_tasks AS owt
INNER JOIN sys.dm_exec_sessions AS es
    ON owt.session_id = es.session_id
LEFT JOIN sys.dm_exec_requests AS er
    ON owt.session_id = er.session_id
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) AS st
WHERE owt.blocking_session_id IS NOT NULL
  AND owt.wait_duration_ms > 5000
ORDER BY owt.wait_duration_ms DESC;

/*------------------------------------------------------------------------------
  Section 6: Deadlock Summary (from system_health XEvent)
  Extracts recent deadlock graphs from the default system_health session.
------------------------------------------------------------------------------*/
;WITH deadlock_events AS (
    SELECT
        xed.value('@timestamp', 'DATETIME2')        AS deadlock_time,
        xed.query('.')                               AS deadlock_graph
    FROM (
        SELECT CAST(target_data AS XML) AS target_data
        FROM sys.dm_xe_session_targets AS xst
        INNER JOIN sys.dm_xe_sessions AS xs
            ON xst.event_session_address = xs.address
        WHERE xs.name = N'system_health'
          AND xst.target_name = N'ring_buffer'
    ) AS data
    CROSS APPLY target_data.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS xed(xed)
)
SELECT TOP (10)
    deadlock_time,
    deadlock_graph
FROM deadlock_events
ORDER BY deadlock_time DESC;
