/******************************************************************************
* Script:   06-blocking.sql
* Purpose:  Blocking analysis including current blocking chains, head blockers,
*           lock details, deadlock history, and long-running transactions.
* Server:   SQL Server 2017 (compatibility level 140)
* Date:     2026-04-06
*
* Safety:   Read-only. No modifications to server or databases.
******************************************************************************/
SET NOCOUNT ON;

-- ============================================================================
-- Section 1: Current Blocking Chains
-- ============================================================================
PRINT '=== Section 1: Current Blocking Chains ===';
PRINT '';

SELECT
    blocked.session_id                              AS [Blocked Session],
    blocked.blocking_session_id                     AS [Blocker Session],
    blocked.wait_type                               AS [Wait Type],
    blocked.wait_time / 1000                        AS [Wait Seconds],
    blocked.wait_resource                           AS [Wait Resource],
    DB_NAME(blocked.database_id)                    AS [Database],
    blocked.command                                 AS [Blocked Command],
    blocked.status                                  AS [Blocked Status],
    blocked.cpu_time                                AS [Blocked CPU Ms],
    blocked.total_elapsed_time / 1000               AS [Blocked Elapsed Sec],
    blocked.open_transaction_count                  AS [Blocked Open Trans],
    blocked_text.text                               AS [Blocked Query Full],
    SUBSTRING(blocked_text.text,
        blocked.statement_start_offset / 2 + 1,
        (CASE WHEN blocked.statement_end_offset = -1
              THEN LEN(CONVERT(NVARCHAR(MAX), blocked_text.text)) * 2
              ELSE blocked.statement_end_offset
         END - blocked.statement_start_offset) / 2 + 1)
                                                    AS [Blocked Current Statement],
    blocker_session.login_name                      AS [Blocker Login],
    blocker_session.host_name                       AS [Blocker Host],
    blocker_session.program_name                    AS [Blocker Application],
    blocker_session.status                          AS [Blocker Status],
    blocker_session.last_request_start_time         AS [Blocker Last Request],
    blocker_text.text                               AS [Blocker Last Query]
FROM sys.dm_exec_requests blocked
JOIN sys.dm_exec_sessions blocker_session
    ON blocked.blocking_session_id = blocker_session.session_id
CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_text
OUTER APPLY sys.dm_exec_sql_text(blocker_session.most_recent_sql_handle) blocker_text
WHERE blocked.blocking_session_id > 0
ORDER BY blocked.wait_time DESC;

-- If no blocking detected
IF NOT EXISTS (SELECT 1 FROM sys.dm_exec_requests WHERE blocking_session_id > 0)
    PRINT 'No blocking detected at this time.';

-- ============================================================================
-- Section 2: Head Blocker Identification (Root of Blocking Chains)
-- ============================================================================
PRINT '';
PRINT '=== Section 2: Head Blockers (Root of Blocking Chains) ===';
PRINT '';

;WITH BlockingChain AS (
    -- Anchor: sessions that are blocking others but are NOT themselves blocked
    SELECT
        er.session_id,
        CAST(0 AS INT) AS blocking_session_id,
        0 AS chain_level,
        CAST(CAST(er.session_id AS VARCHAR(10)) AS VARCHAR(MAX)) AS chain_path
    FROM sys.dm_exec_requests er
    WHERE er.blocking_session_id = 0
      AND er.session_id IN (
          SELECT blocking_session_id
          FROM sys.dm_exec_requests
          WHERE blocking_session_id > 0
      )

    UNION ALL

    -- Recursive: sessions blocked by someone in our chain
    SELECT
        r.session_id,
        r.blocking_session_id,
        bc.chain_level + 1,
        CAST(bc.chain_path + ' -> ' + CAST(r.session_id AS VARCHAR(10)) AS VARCHAR(MAX))
    FROM sys.dm_exec_requests r
    JOIN BlockingChain bc ON r.blocking_session_id = bc.session_id
    WHERE bc.chain_level < 20  -- Safety limit
)
SELECT
    bc.chain_level                                  AS [Chain Depth],
    bc.session_id                                   AS [Session ID],
    bc.blocking_session_id                          AS [Blocked By],
    bc.chain_path                                   AS [Blocking Chain],
    es.login_name                                   AS [Login],
    es.host_name                                    AS [Host],
    es.program_name                                 AS [Application],
    ISNULL(er.wait_type, 'RUNNING/SLEEPING')        AS [Wait Type],
    ISNULL(er.wait_time, 0) / 1000                  AS [Wait Seconds],
    er.command                                      AS [Command],
    DB_NAME(ISNULL(er.database_id, es.database_id)) AS [Database],
    st.text                                         AS [Last/Current Query]
FROM BlockingChain bc
JOIN sys.dm_exec_sessions es ON bc.session_id = es.session_id
LEFT JOIN sys.dm_exec_requests er ON bc.session_id = er.session_id
OUTER APPLY sys.dm_exec_sql_text(
    ISNULL(er.sql_handle, es.most_recent_sql_handle)) st
ORDER BY bc.chain_level, bc.session_id;

-- ============================================================================
-- Section 3: Lock Details for Blocked Sessions
-- ============================================================================
PRINT '';
PRINT '=== Section 3: Lock Details (Sessions Involved in Blocking) ===';
PRINT '';

;WITH BlockedSessions AS (
    SELECT DISTINCT session_id FROM sys.dm_exec_requests WHERE blocking_session_id > 0
    UNION
    SELECT DISTINCT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id > 0
)
SELECT
    tl.request_session_id                           AS [Session ID],
    DB_NAME(tl.resource_database_id)                AS [Database],
    tl.resource_type                                AS [Resource Type],
    tl.resource_subtype                             AS [Resource Subtype],
    tl.resource_description                         AS [Resource Description],
    tl.resource_associated_entity_id                AS [Entity ID],
    CASE tl.resource_type
        WHEN 'OBJECT'
        THEN OBJECT_NAME(tl.resource_associated_entity_id, tl.resource_database_id)
        ELSE NULL
    END                                             AS [Object Name],
    tl.request_mode                                 AS [Lock Mode],
    tl.request_type                                 AS [Request Type],
    tl.request_status                               AS [Lock Status],
    tl.request_owner_type                           AS [Owner Type]
FROM sys.dm_tran_locks tl
WHERE tl.request_session_id IN (SELECT session_id FROM BlockedSessions)
ORDER BY tl.request_session_id, tl.resource_type;

-- ============================================================================
-- Section 4: Long-Running Open Transactions
-- ============================================================================
PRINT '';
PRINT '=== Section 4: Long-Running Open Transactions ===';
PRINT '';

SELECT
    tat.transaction_id                              AS [Transaction ID],
    tat.name                                        AS [Transaction Name],
    tat.transaction_begin_time                      AS [Begin Time],
    DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE())
                                                    AS [Duration Seconds],
    CASE tat.transaction_type
        WHEN 1 THEN 'Read/Write'
        WHEN 2 THEN 'Read-Only'
        WHEN 3 THEN 'System'
        WHEN 4 THEN 'Distributed'
        ELSE 'Unknown (' + CAST(tat.transaction_type AS VARCHAR(5)) + ')'
    END                                             AS [Transaction Type],
    CASE tat.transaction_state
        WHEN 0 THEN 'Not fully initialized'
        WHEN 1 THEN 'Initialized, not started'
        WHEN 2 THEN 'Active'
        WHEN 3 THEN 'Ended (read-only)'
        WHEN 4 THEN 'Commit initiated (distributed)'
        WHEN 5 THEN 'Prepared, awaiting resolution'
        WHEN 6 THEN 'Committed'
        WHEN 7 THEN 'Rolling back'
        WHEN 8 THEN 'Rolled back'
        ELSE 'Unknown'
    END                                             AS [Transaction State],
    tst.session_id                                  AS [Session ID],
    es.login_name                                   AS [Login],
    es.host_name                                    AS [Host],
    es.program_name                                 AS [Application],
    ISNULL(er.status, es.status)                    AS [Session Status],
    st.text                                         AS [Last/Current Query],
    tdt.database_transaction_log_bytes_used         AS [Log Bytes Used],
    tdt.database_transaction_log_bytes_reserved     AS [Log Bytes Reserved]
FROM sys.dm_tran_active_transactions tat
JOIN sys.dm_tran_session_transactions tst
    ON tat.transaction_id = tst.transaction_id
JOIN sys.dm_exec_sessions es
    ON tst.session_id = es.session_id
LEFT JOIN sys.dm_exec_requests er
    ON tst.session_id = er.session_id
LEFT JOIN sys.dm_tran_database_transactions tdt
    ON tat.transaction_id = tdt.transaction_id
OUTER APPLY sys.dm_exec_sql_text(
    ISNULL(er.sql_handle, es.most_recent_sql_handle)) st
WHERE tat.transaction_type <> 2  -- Exclude read-only
  AND DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) > 30  -- > 30 seconds
ORDER BY tat.transaction_begin_time;

-- ============================================================================
-- Section 5: Lock Escalation and Lock Memory
-- ============================================================================
PRINT '';
PRINT '=== Section 5: Lock Count and Memory ===';
PRINT '';

SELECT
    resource_type                                   AS [Lock Resource Type],
    request_mode                                    AS [Lock Mode],
    COUNT(*)                                        AS [Lock Count]
FROM sys.dm_tran_locks
GROUP BY resource_type, request_mode
ORDER BY COUNT(*) DESC;

SELECT
    type                                            AS [Memory Clerk],
    CAST(pages_kb / 1024.0 AS DECIMAL(12,2))       AS [Memory MB]
FROM sys.dm_os_memory_clerks
WHERE type = 'OBJECTSTORE_LOCK_MANAGER'
ORDER BY pages_kb DESC;

-- ============================================================================
-- Section 6: Recent Deadlocks from System Health Session
-- ============================================================================
PRINT '';
PRINT '=== Section 6: Recent Deadlocks (from system_health Extended Events) ===';
PRINT '';

;WITH DeadlockEvents AS (
    SELECT
        CAST(target_data AS XML) AS TargetData
    FROM sys.dm_xe_session_targets st
    JOIN sys.dm_xe_sessions s
        ON s.address = st.event_session_address
    WHERE s.name = 'system_health'
      AND st.target_name = 'ring_buffer'
)
SELECT TOP 10
    XEvent.value('(@timestamp)[1]', 'DATETIME2')    AS [Deadlock Time],
    XEvent.query('(data/value/deadlock)[1]')         AS [Deadlock Graph XML]
FROM DeadlockEvents
CROSS APPLY TargetData.nodes(
    'RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData(XEvent)
ORDER BY XEvent.value('(@timestamp)[1]', 'DATETIME2') DESC;

-- ============================================================================
-- Section 7: Lock Waits Summary (from dm_db_index_operational_stats)
-- ============================================================================
PRINT '';
PRINT '=== Section 7: Objects with Highest Lock Waits ===';
PRINT '';

SELECT TOP 20
    DB_NAME()                                       AS [Database],
    OBJECT_SCHEMA_NAME(ios.object_id) + '.'
        + OBJECT_NAME(ios.object_id)                AS [Table],
    i.name                                          AS [Index],
    ios.row_lock_wait_count                         AS [Row Lock Waits],
    ios.row_lock_wait_in_ms                         AS [Row Lock Wait Ms],
    CAST(ios.row_lock_wait_in_ms
        / NULLIF(ios.row_lock_wait_count, 0)
        AS DECIMAL(12,2))                           AS [Avg Row Lock Wait Ms],
    ios.page_lock_wait_count                        AS [Page Lock Waits],
    ios.page_lock_wait_in_ms                        AS [Page Lock Wait Ms],
    ios.index_lock_promotion_attempt_count          AS [Lock Escalation Attempts],
    ios.index_lock_promotion_count                  AS [Lock Escalations]
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) ios
JOIN sys.indexes i
    ON ios.object_id = i.object_id
   AND ios.index_id = i.index_id
WHERE OBJECTPROPERTY(ios.object_id, 'IsUserTable') = 1
  AND (ios.row_lock_wait_count > 0 OR ios.page_lock_wait_count > 0)
ORDER BY ios.row_lock_wait_in_ms + ios.page_lock_wait_in_ms DESC;

PRINT '';
PRINT '=== Blocking Analysis Complete ===';
