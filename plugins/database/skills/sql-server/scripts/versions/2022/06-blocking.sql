/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Blocking & Deadlock Analysis
 *
 * Purpose : Detect current blocking chains and analyze deadlock history.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Current Blocking Chains
 *   2. Blocking Chain Hierarchy (Recursive CTE)
 *   3. Lock Details for Blocked Sessions
 *   4. Head Blockers with Resource Consumption
 *   5. Recent Deadlock Summary (Extended Events / System Health)
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: Current Blocking Chains
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    er.session_id                                   AS blocked_session_id,
    er.blocking_session_id,
    er.wait_type,
    er.wait_time                                    AS wait_time_ms,
    er.wait_resource,
    DB_NAME(er.database_id)                         AS database_name,
    er.status                                       AS request_status,
    er.command,
    er.cpu_time                                     AS cpu_time_ms,
    er.total_elapsed_time                           AS elapsed_ms,
    er.logical_reads,
    er.reads                                        AS physical_reads,
    er.writes,
    SUBSTRING(qt.text,
        (er.statement_start_offset / 2) + 1,
        (CASE er.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE er.statement_end_offset
         END - er.statement_start_offset) / 2 + 1
    )                                               AS blocked_query,
    es.login_name                                   AS blocked_login,
    es.host_name                                    AS blocked_host,
    es.program_name                                 AS blocked_program,
    -- Blocker info
    bs.login_name                                   AS blocker_login,
    bs.host_name                                    AS blocker_host,
    bs.program_name                                 AS blocker_program,
    bs.status                                       AS blocker_session_status,
    bs.last_request_start_time                      AS blocker_last_request_start,
    COALESCE(
        (SELECT SUBSTRING(bqt.text, 1, 500)
         FROM sys.dm_exec_connections AS bc
         CROSS APPLY sys.dm_exec_sql_text(bc.most_recent_sql_handle) AS bqt
         WHERE bc.session_id = er.blocking_session_id),
        '-- Could not retrieve blocker query'
    )                                               AS blocker_query
FROM sys.dm_exec_requests AS er
INNER JOIN sys.dm_exec_sessions AS es
    ON er.session_id = es.session_id
LEFT JOIN sys.dm_exec_sessions AS bs
    ON er.blocking_session_id = bs.session_id
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) AS qt
WHERE er.blocking_session_id > 0
ORDER BY er.wait_time DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: Blocking Chain Hierarchy (Recursive CTE)
  Traces the full chain from head blocker to leaf victims.
──────────────────────────────────────────────────────────────────────────────*/
;WITH blocking_tree AS (
    -- Head blockers: sessions that block others but are not blocked themselves
    SELECT
        er.session_id,
        er.blocking_session_id,
        er.wait_type,
        er.wait_time,
        er.wait_resource,
        DB_NAME(er.database_id)                     AS database_name,
        0                                           AS chain_level,
        CAST(er.session_id AS VARCHAR(MAX))         AS blocking_chain
    FROM sys.dm_exec_requests AS er
    WHERE er.blocking_session_id = 0
      AND er.session_id IN (
          SELECT DISTINCT blocking_session_id
          FROM sys.dm_exec_requests
          WHERE blocking_session_id > 0
      )

    UNION ALL

    -- Blocked sessions
    SELECT
        er.session_id,
        er.blocking_session_id,
        er.wait_type,
        er.wait_time,
        er.wait_resource,
        DB_NAME(er.database_id),
        bt.chain_level + 1,
        bt.blocking_chain + ' -> ' + CAST(er.session_id AS VARCHAR(MAX))
    FROM sys.dm_exec_requests AS er
    INNER JOIN blocking_tree AS bt
        ON er.blocking_session_id = bt.session_id
    WHERE bt.chain_level < 20  -- safety limit
)
SELECT
    chain_level,
    session_id,
    blocking_session_id,
    wait_type,
    wait_time                                       AS wait_time_ms,
    wait_resource,
    database_name,
    blocking_chain
FROM blocking_tree
ORDER BY blocking_chain, chain_level;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: Lock Details for Blocked Sessions
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    tl.request_session_id                           AS session_id,
    tl.resource_type,
    tl.resource_subtype,
    DB_NAME(tl.resource_database_id)                AS database_name,
    tl.resource_associated_entity_id,
    tl.request_mode                                 AS lock_mode,
    tl.request_type,
    tl.request_status                               AS lock_status,
    CASE tl.resource_type
        WHEN 'OBJECT'
        THEN OBJECT_NAME(tl.resource_associated_entity_id, tl.resource_database_id)
        ELSE NULL
    END                                             AS locked_object_name,
    tl.resource_description
FROM sys.dm_tran_locks AS tl
WHERE tl.request_session_id IN (
    SELECT session_id FROM sys.dm_exec_requests WHERE blocking_session_id > 0
    UNION
    SELECT DISTINCT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id > 0
)
ORDER BY tl.request_session_id, tl.resource_type;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Head Blockers with Resource Consumption
  Identifies the root cause sessions blocking the most others.
──────────────────────────────────────────────────────────────────────────────*/
;WITH head_blockers AS (
    SELECT DISTINCT
        er.blocking_session_id AS head_blocker_session_id
    FROM sys.dm_exec_requests AS er
    WHERE er.blocking_session_id > 0
      AND er.blocking_session_id NOT IN (
          SELECT session_id
          FROM sys.dm_exec_requests
          WHERE blocking_session_id > 0
      )
)
SELECT
    hb.head_blocker_session_id,
    es.login_name,
    es.host_name,
    es.program_name,
    es.status                                       AS session_status,
    es.cpu_time                                     AS session_cpu_ms,
    es.memory_usage * 8                             AS session_memory_kb,
    es.reads                                        AS session_reads,
    es.writes                                       AS session_writes,
    es.last_request_start_time,
    es.last_request_end_time,
    (SELECT COUNT(*)
     FROM sys.dm_exec_requests
     WHERE blocking_session_id = hb.head_blocker_session_id)
                                                    AS directly_blocked_count,
    ec.most_recent_session_id,
    SUBSTRING(qt.text, 1, 500)                      AS last_query_text
FROM head_blockers AS hb
INNER JOIN sys.dm_exec_sessions AS es
    ON hb.head_blocker_session_id = es.session_id
LEFT JOIN sys.dm_exec_connections AS ec
    ON hb.head_blocker_session_id = ec.session_id
OUTER APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) AS qt
ORDER BY directly_blocked_count DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: Recent Deadlock Summary (from System Health Extended Event)
  Parses the system_health session for deadlock graphs.
──────────────────────────────────────────────────────────────────────────────*/
;WITH deadlock_events AS (
    SELECT
        xed.value('@timestamp', 'DATETIME2')        AS deadlock_time,
        xed.query('.')                               AS deadlock_graph
    FROM (
        SELECT CAST(target_data AS XML) AS target_xml
        FROM sys.dm_xe_session_targets AS st
        INNER JOIN sys.dm_xe_sessions AS s
            ON st.event_session_address = s.address
        WHERE s.name = N'system_health'
          AND st.target_name = N'ring_buffer'
    ) AS raw
    CROSS APPLY target_xml.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS n(xed)
)
SELECT TOP (10)
    deadlock_time,
    deadlock_graph                                  AS deadlock_xml
FROM deadlock_events
ORDER BY deadlock_time DESC;
