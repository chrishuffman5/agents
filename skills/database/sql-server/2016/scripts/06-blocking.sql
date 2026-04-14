/*******************************************************************************
 * Script:    06-blocking.sql
 * Purpose:   Current blocking chains and deadlock detection
 * Version:   SQL Server 2016 (Compatibility Level 130)
 * Date:      2026-04-06
 *
 * Returns:   Active blocking chains with head blockers, blocked sessions,
 *            wait types, wait duration, and query text for both sides.
 *            Also extracts recent deadlock graphs from the system_health
 *            extended events session.
 *
 * Safety:    Read-only. Safe for production execution.
 ******************************************************************************/

SET NOCOUNT ON;

-- ============================================================================
-- SECTION 1: Currently Blocked Sessions
-- ============================================================================
-- Shows every session that is currently waiting on another session.

SELECT
    r.session_id                                AS [Blocked SPID],
    r.blocking_session_id                       AS [Blocking SPID],
    r.wait_type                                 AS [Wait Type],
    r.wait_time / 1000                          AS [Wait Time Sec],
    r.wait_resource                             AS [Wait Resource],
    r.status                                    AS [Request Status],
    r.command                                   AS [Command],
    DB_NAME(r.database_id)                      AS [Database],

    -- Blocked session info
    s.login_name                                AS [Blocked Login],
    s.host_name                                 AS [Blocked Host],
    s.program_name                              AS [Blocked Program],

    -- Blocked query text
    SUBSTRING(
        st_blocked.text,
        (r.statement_start_offset / 2) + 1,
        CASE
            WHEN r.statement_end_offset = -1
                THEN LEN(st_blocked.text)
            ELSE (r.statement_end_offset - r.statement_start_offset) / 2 + 1
        END
    )                                           AS [Blocked Query],

    -- Blocking session query text (if available)
    COALESCE(st_blocker.text, 'N/A — session idle or not available')
                                                AS [Blocking Query],

    -- Blocker session details
    bs.login_name                               AS [Blocker Login],
    bs.host_name                                AS [Blocker Host],
    bs.program_name                             AS [Blocker Program],
    bs.status                                   AS [Blocker Status],
    COALESCE(bs.last_request_start_time, bs.login_time)
                                                AS [Blocker Last Request],

    -- Transaction info
    r.open_transaction_count                    AS [Blocked Open Tran],
    r.transaction_isolation_level               AS [Isolation Level],
    CASE r.transaction_isolation_level
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'Read Uncommitted'
        WHEN 2 THEN 'Read Committed'
        WHEN 3 THEN 'Repeatable Read'
        WHEN 4 THEN 'Serializable'
        WHEN 5 THEN 'Snapshot'
        ELSE 'Unknown'
    END                                         AS [Isolation Level Desc]

FROM sys.dm_exec_requests AS r
INNER JOIN sys.dm_exec_sessions AS s
    ON s.session_id = r.session_id
LEFT JOIN sys.dm_exec_sessions AS bs
    ON bs.session_id = r.blocking_session_id
-- Blocked query text
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st_blocked
-- Blocking query text (may not have an active request)
OUTER APPLY sys.dm_exec_sql_text(
    (SELECT TOP 1 r2.sql_handle
     FROM sys.dm_exec_requests AS r2
     WHERE r2.session_id = r.blocking_session_id)
) AS st_blocker
WHERE r.blocking_session_id > 0
ORDER BY r.wait_time DESC;


-- ============================================================================
-- SECTION 2: Head Blockers (Root of Blocking Chains)
-- ============================================================================
-- A head blocker is a session that blocks others but is not itself blocked.

;WITH BlockingTree AS (
    SELECT
        r.blocking_session_id   AS head_blocker,
        r.session_id            AS blocked_session,
        r.wait_time,
        r.wait_type,
        1                       AS chain_depth
    FROM sys.dm_exec_requests AS r
    WHERE r.blocking_session_id > 0
      AND r.blocking_session_id NOT IN (
          SELECT r2.session_id
          FROM sys.dm_exec_requests AS r2
          WHERE r2.blocking_session_id > 0
      )
)
SELECT
    bt.head_blocker                             AS [Head Blocker SPID],
    COUNT(DISTINCT bt.blocked_session)          AS [Sessions Blocked],
    MAX(bt.wait_time) / 1000                    AS [Max Wait Time Sec],
    s.login_name                                AS [Blocker Login],
    s.host_name                                 AS [Blocker Host],
    s.program_name                              AS [Blocker Program],
    s.status                                    AS [Blocker Status],
    COALESCE(
        (SELECT TOP 1 st.text
         FROM sys.dm_exec_connections AS c
         CROSS APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) AS st
         WHERE c.session_id = bt.head_blocker),
        'N/A')                                  AS [Blocker Last Query],
    -- Check if the head blocker has an open transaction
    (SELECT COUNT(*)
     FROM sys.dm_tran_active_transactions AS at2
     INNER JOIN sys.dm_tran_session_transactions AS st2
         ON st2.transaction_id = at2.transaction_id
     WHERE st2.session_id = bt.head_blocker)    AS [Open Transactions]
FROM BlockingTree AS bt
INNER JOIN sys.dm_exec_sessions AS s
    ON s.session_id = bt.head_blocker
GROUP BY bt.head_blocker, s.login_name, s.host_name,
         s.program_name, s.status
ORDER BY [Sessions Blocked] DESC;


-- ============================================================================
-- SECTION 3: Detailed Waiting Tasks
-- ============================================================================
-- Lower-level view of all current waits with resource details.

SELECT
    wt.session_id                               AS [Waiting SPID],
    wt.wait_type                                AS [Wait Type],
    wt.wait_duration_ms / 1000                  AS [Wait Duration Sec],
    wt.blocking_session_id                      AS [Blocking SPID],
    wt.resource_description                     AS [Resource],
    s.login_name                                AS [Login],
    s.host_name                                 AS [Host],
    DB_NAME(r.database_id)                      AS [Database],
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        CASE
            WHEN r.statement_end_offset = -1
                THEN 200
            ELSE LEAST(
                (r.statement_end_offset - r.statement_start_offset) / 2 + 1,
                200
            )
        END
    )                                           AS [Query Text (200 chars)]
FROM sys.dm_os_waiting_tasks AS wt
INNER JOIN sys.dm_exec_sessions AS s
    ON s.session_id = wt.session_id
LEFT JOIN sys.dm_exec_requests AS r
    ON r.session_id = wt.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
WHERE wt.session_id > 50             -- skip system sessions
  AND wt.blocking_session_id IS NOT NULL
  AND wt.blocking_session_id > 0
ORDER BY wt.wait_duration_ms DESC;


-- ============================================================================
-- SECTION 4: Deadlock Detection — Recent Deadlocks from system_health XE
-- ============================================================================
-- Extracts deadlock XML graphs from the system_health extended events session.
-- These can be opened in SSMS as .xdl files for visual analysis.

;WITH DeadlockEvents AS (
    SELECT
        xed.value('@timestamp', 'DATETIME2')    AS deadlock_time,
        xed.query('.')                          AS deadlock_graph
    FROM (
        SELECT CAST(target_data AS XML) AS target_xml
        FROM sys.dm_xe_session_targets AS st
        INNER JOIN sys.dm_xe_sessions AS s
            ON s.address = st.event_session_address
        WHERE s.name = 'system_health'
          AND st.target_name = 'ring_buffer'
    ) AS data
    CROSS APPLY target_xml.nodes('//RingBufferTarget/event[@name="xml_deadlock_report"]') AS xevents(xed)
)
SELECT TOP 10
    deadlock_time                               AS [Deadlock Time],
    deadlock_graph                              AS [Deadlock Graph XML]
FROM DeadlockEvents
ORDER BY deadlock_time DESC;


-- ============================================================================
-- SECTION 5: Long-Running Open Transactions
-- ============================================================================
-- Open transactions that are not associated with an active request may
-- hold locks and cause blocking.

SELECT
    st.session_id                               AS [SPID],
    at.transaction_id                           AS [Transaction ID],
    at.name                                     AS [Transaction Name],
    at.transaction_begin_time                   AS [Begin Time],
    DATEDIFF(SECOND, at.transaction_begin_time, GETDATE())
                                                AS [Duration Sec],
    CASE at.transaction_type
        WHEN 1 THEN 'Read/Write'
        WHEN 2 THEN 'Read-Only'
        WHEN 3 THEN 'System'
        WHEN 4 THEN 'Distributed'
        ELSE 'Unknown'
    END                                         AS [Transaction Type],
    CASE at.transaction_state
        WHEN 0 THEN 'Not initialized'
        WHEN 1 THEN 'Not started'
        WHEN 2 THEN 'Active'
        WHEN 3 THEN 'Ended (read-only)'
        WHEN 4 THEN 'Commit initiated'
        WHEN 5 THEN 'Prepared'
        WHEN 6 THEN 'Committed'
        WHEN 7 THEN 'Rolling back'
        WHEN 8 THEN 'Rolled back'
        ELSE 'Unknown'
    END                                         AS [Transaction State],
    s.login_name                                AS [Login],
    s.host_name                                 AS [Host],
    s.program_name                              AS [Program],
    s.status                                    AS [Session Status],
    COALESCE(
        (SELECT TOP 1 st2.text
         FROM sys.dm_exec_connections AS c
         CROSS APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) AS st2
         WHERE c.session_id = st.session_id),
        'N/A')                                  AS [Last Query]
FROM sys.dm_tran_active_transactions AS at
INNER JOIN sys.dm_tran_session_transactions AS st
    ON st.transaction_id = at.transaction_id
INNER JOIN sys.dm_exec_sessions AS s
    ON s.session_id = st.session_id
WHERE at.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE())
  AND s.session_id > 50
ORDER BY at.transaction_begin_time ASC;
