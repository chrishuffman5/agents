/******************************************************************************
* Script:   02-wait-stats.sql
* Purpose:  Wait statistics analysis for SQL Server 2017. Shows instance-level
*           waits and NEW Query Store wait stats (sys.query_store_wait_stats)
*           side by side for comprehensive wait diagnostics.
* Server:   SQL Server 2017 (compatibility level 140)
* Date:     2026-04-06
*
* NEW in 2017 vs 2016:
*   - sys.query_store_wait_stats: per-query wait stats captured by Query Store
*   - WAIT_STATS_CAPTURE_MODE option in Query Store
*   - Enables correlating waits to specific queries, not just instance-wide
*
* Safety:   Read-only. No modifications to server or databases.
******************************************************************************/
SET NOCOUNT ON;

-- ============================================================================
-- Section 1: Instance-Level Wait Statistics (Top Waits)
-- ============================================================================
PRINT '=== Section 1: Instance-Level Wait Statistics (Top 25) ===';
PRINT '';

WITH FilteredWaits AS (
    SELECT
        wait_type,
        wait_time_ms,
        signal_wait_time_ms,
        wait_time_ms - signal_wait_time_ms          AS resource_wait_ms,
        waiting_tasks_count,
        100.0 * wait_time_ms
            / NULLIF(SUM(wait_time_ms) OVER (), 0)  AS pct,
        ROW_NUMBER() OVER (ORDER BY wait_time_ms DESC) AS rn
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN (
        -- Filter out benign / background waits
        'SLEEP_TASK', 'BROKER_TO_FLUSH', 'SQLTRACE_BUFFER_FLUSH',
        'CLR_AUTO_EVENT', 'CLR_MANUAL_EVENT', 'LAZYWRITER_SLEEP',
        'CHECKPOINT_QUEUE', 'WAITFOR', 'XE_TIMER_EVENT',
        'FT_IFTS_SCHEDULER_IDLE_WAIT', 'LOGMGR_QUEUE',
        'DIRTY_PAGE_POLL', 'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        'SP_SERVER_DIAGNOSTICS_SLEEP', 'XE_DISPATCHER_WAIT',
        'DISPATCHER_QUEUE_SEMAPHORE', 'WAIT_FOR_RESULTS',
        'BROKER_EVENTHANDLER', 'BROKER_RECEIVE_WAITFOR',
        'BROKER_TASK_STOP', 'BROKER_TRANSMITTER',
        'KSOURCE_WAKEUP', 'ONDEMAND_TASK_QUEUE',
        'DBMIRROR_EVENTS_QUEUE', 'DBMIRRORING_CMD',
        'REQUEST_FOR_DEADLOCK_SEARCH',
        'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        'PREEMPTIVE_OS_AUTHENTICATIONOPS',
        'PREEMPTIVE_OS_GETPROCADDRESS',
        'PREEMPTIVE_XE_CALLBACKEXECUTE',
        'PREEMPTIVE_XE_DISPATCHER',
        'PREEMPTIVE_XE_GETTARGETSTATE',
        'PREEMPTIVE_XE_SESSIONCOMMIT',
        'PREEMPTIVE_XE_TARGETINIT',
        'PREEMPTIVE_XE_TARGETFINALIZE',
        'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
        'QDS_ASYNC_QUEUE',
        'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
        'QDS_SHUTDOWN_QUEUE',
        'SLEEP_DBSTARTUP', 'SLEEP_DCOMSTARTUP',
        'SLEEP_MASTERDBREADY', 'SLEEP_MASTERMDREADY',
        'SLEEP_MASTERUPGRADED', 'SLEEP_MSDBSTARTUP',
        'SLEEP_SYSTEMTASK', 'SLEEP_TEMPDBSTARTUP',
        'SNI_HTTP_ACCEPT', 'WAIT_XTP_CKPT_CLOSE',
        'WAIT_XTP_HOST_WAIT', 'WAITFOR_TASKSHUTDOWN',
        'XE_LIVE_TARGET_TVF'
    )
    AND waiting_tasks_count > 0
)
SELECT
    wait_type                                       AS [Wait Type],
    waiting_tasks_count                             AS [Wait Count],
    CAST(resource_wait_ms / 1000.0 AS DECIMAL(18,2)) AS [Resource Wait Sec],
    CAST(signal_wait_time_ms / 1000.0 AS DECIMAL(18,2)) AS [Signal Wait Sec],
    CAST(wait_time_ms / 1000.0 AS DECIMAL(18,2))   AS [Total Wait Sec],
    CAST(resource_wait_ms / NULLIF(waiting_tasks_count, 0)
        AS DECIMAL(18,2))                           AS [Avg Resource Wait Ms],
    CAST(signal_wait_time_ms / NULLIF(waiting_tasks_count, 0)
        AS DECIMAL(18,2))                           AS [Avg Signal Wait Ms],
    CAST(pct AS DECIMAL(5,2))                       AS [Pct of Total],
    CAST(SUM(pct) OVER (ORDER BY rn) AS DECIMAL(5,2)) AS [Running Pct],
    -- Guidance for common waits
    CASE
        WHEN wait_type LIKE 'PAGEIOLATCH%'
            THEN 'I/O bottleneck -- check disk latency and buffer pool pressure'
        WHEN wait_type LIKE 'LCK_M_%'
            THEN 'Lock contention -- run blocking analysis (06-blocking.sql)'
        WHEN wait_type = 'CXPACKET'
            THEN 'Parallelism waits -- review MAXDOP and CTFP settings'
        WHEN wait_type = 'CXCONSUMER'
            THEN 'Parallel consumer wait -- usually benign if CXPACKET is also present'
        WHEN wait_type = 'SOS_SCHEDULER_YIELD'
            THEN 'CPU pressure -- find top CPU queries (03-top-queries-cpu.sql)'
        WHEN wait_type = 'RESOURCE_SEMAPHORE'
            THEN 'Memory grant waits -- queries waiting for memory to execute'
        WHEN wait_type = 'WRITELOG'
            THEN 'Transaction log write latency -- check log disk performance'
        WHEN wait_type = 'ASYNC_NETWORK_IO'
            THEN 'Network / client not consuming results fast enough'
        WHEN wait_type LIKE 'HADR%'
            THEN 'Always On AG related -- check AG health (10-ag-health.sql)'
        WHEN wait_type LIKE 'PAGELATCH_%'
            THEN 'In-memory page contention -- may indicate tempdb contention'
        ELSE ''
    END                                             AS [Guidance]
FROM FilteredWaits
WHERE rn <= 25
ORDER BY rn;

-- ============================================================================
-- Section 2: Wait Category Summary
-- ============================================================================
PRINT '';
PRINT '=== Section 2: Wait Category Summary ===';
PRINT '';

WITH CategorizedWaits AS (
    SELECT
        CASE
            WHEN wait_type LIKE 'LCK_M_%'              THEN 'Locking'
            WHEN wait_type LIKE 'PAGEIOLATCH_%'         THEN 'Buffer I/O'
            WHEN wait_type LIKE 'PAGELATCH_%'           THEN 'Buffer Latch'
            WHEN wait_type LIKE 'LATCH_%'               THEN 'Non-Buffer Latch'
            WHEN wait_type LIKE 'IO_COMPLETION%'        THEN 'Other I/O'
            WHEN wait_type = 'WRITELOG'                 THEN 'Log Write'
            WHEN wait_type LIKE 'ASYNC_NETWORK%'        THEN 'Network'
            WHEN wait_type LIKE 'CXPACKET'              THEN 'Parallelism'
            WHEN wait_type LIKE 'CXCONSUMER'            THEN 'Parallelism'
            WHEN wait_type = 'SOS_SCHEDULER_YIELD'      THEN 'CPU'
            WHEN wait_type = 'RESOURCE_SEMAPHORE'       THEN 'Memory Grant'
            WHEN wait_type LIKE 'HADR_%'                THEN 'Availability Group'
            WHEN wait_type LIKE 'PREEMPTIVE_%'          THEN 'Preemptive (External)'
            WHEN wait_type LIKE 'THREADPOOL%'           THEN 'Worker Thread'
            WHEN wait_type LIKE 'CMEMTHREAD%'           THEN 'Memory'
            ELSE 'Other'
        END AS wait_category,
        wait_time_ms,
        signal_wait_time_ms,
        waiting_tasks_count
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN (
        'SLEEP_TASK', 'BROKER_TO_FLUSH', 'SQLTRACE_BUFFER_FLUSH',
        'CLR_AUTO_EVENT', 'CLR_MANUAL_EVENT', 'LAZYWRITER_SLEEP',
        'CHECKPOINT_QUEUE', 'WAITFOR', 'XE_TIMER_EVENT',
        'FT_IFTS_SCHEDULER_IDLE_WAIT', 'LOGMGR_QUEUE',
        'DIRTY_PAGE_POLL', 'SP_SERVER_DIAGNOSTICS_SLEEP',
        'XE_DISPATCHER_WAIT', 'DISPATCHER_QUEUE_SEMAPHORE',
        'REQUEST_FOR_DEADLOCK_SEARCH',
        'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', 'QDS_ASYNC_QUEUE',
        'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
        'QDS_SHUTDOWN_QUEUE', 'WAIT_FOR_RESULTS'
    )
    AND waiting_tasks_count > 0
)
SELECT
    wait_category                                   AS [Wait Category],
    SUM(waiting_tasks_count)                        AS [Total Wait Count],
    CAST(SUM(wait_time_ms) / 1000.0 AS DECIMAL(18,2)) AS [Total Wait Sec],
    CAST(SUM(wait_time_ms - signal_wait_time_ms) / 1000.0
        AS DECIMAL(18,2))                           AS [Resource Wait Sec],
    CAST(SUM(signal_wait_time_ms) / 1000.0
        AS DECIMAL(18,2))                           AS [Signal Wait Sec],
    CAST(100.0 * SUM(signal_wait_time_ms)
        / NULLIF(SUM(wait_time_ms), 0) AS DECIMAL(5,2)) AS [Signal Pct],
    CAST(100.0 * SUM(wait_time_ms)
        / NULLIF(SUM(SUM(wait_time_ms)) OVER (), 0)
        AS DECIMAL(5,2))                            AS [Pct of Total]
FROM CategorizedWaits
GROUP BY wait_category
ORDER BY SUM(wait_time_ms) DESC;

-- ============================================================================
-- Section 3: Currently Waiting Tasks
-- ============================================================================
PRINT '';
PRINT '=== Section 3: Currently Waiting Tasks ===';
PRINT '';

SELECT
    wt.session_id                                   AS [Session ID],
    wt.wait_type                                    AS [Wait Type],
    wt.wait_duration_ms                             AS [Wait Duration Ms],
    wt.resource_description                         AS [Resource],
    wt.blocking_session_id                          AS [Blocking Session],
    er.command                                      AS [Command],
    er.status                                       AS [Status],
    DB_NAME(er.database_id)                         AS [Database],
    SUBSTRING(st.text, er.statement_start_offset / 2 + 1,
        (CASE WHEN er.statement_end_offset = -1
              THEN LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2
              ELSE er.statement_end_offset
         END - er.statement_start_offset) / 2 + 1) AS [Current Statement]
FROM sys.dm_os_waiting_tasks wt
LEFT JOIN sys.dm_exec_requests er ON wt.session_id = er.session_id
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) st
WHERE wt.session_id > 50  -- Exclude system sessions
ORDER BY wt.wait_duration_ms DESC;

-- ============================================================================
-- Section 4: Signal Wait Ratio (CPU Pressure Indicator)
-- ============================================================================
PRINT '';
PRINT '=== Section 4: Signal Wait Ratio (CPU Pressure) ===';
PRINT '';

SELECT
    CAST(SUM(signal_wait_time_ms) AS DECIMAL(18,2))  AS [Total Signal Waits Ms],
    CAST(SUM(wait_time_ms) AS DECIMAL(18,2))          AS [Total Waits Ms],
    CAST(100.0 * SUM(signal_wait_time_ms)
        / NULLIF(SUM(wait_time_ms), 0) AS DECIMAL(5,2)) AS [Signal Wait Pct],
    CASE
        WHEN 100.0 * SUM(signal_wait_time_ms)
            / NULLIF(SUM(wait_time_ms), 0) > 25
        THEN 'HIGH -- Significant CPU pressure detected'
        WHEN 100.0 * SUM(signal_wait_time_ms)
            / NULLIF(SUM(wait_time_ms), 0) > 15
        THEN 'MODERATE -- Some CPU pressure'
        ELSE 'NORMAL -- CPU is not the primary bottleneck'
    END                                             AS [Assessment]
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    'SLEEP_TASK', 'WAITFOR', 'CLR_AUTO_EVENT',
    'CLR_MANUAL_EVENT', 'LAZYWRITER_SLEEP',
    'CHECKPOINT_QUEUE', 'XE_TIMER_EVENT',
    'SP_SERVER_DIAGNOSTICS_SLEEP', 'DISPATCHER_QUEUE_SEMAPHORE',
    'REQUEST_FOR_DEADLOCK_SEARCH'
)
AND waiting_tasks_count > 0;

-- ============================================================================
-- Section 5: Spinlock Statistics (High CPU Scenarios)
-- ============================================================================
PRINT '';
PRINT '=== Section 5: Top Spinlock Waits ===';
PRINT '';

SELECT TOP 15
    name                                            AS [Spinlock Name],
    collisions                                      AS [Collisions],
    spins                                           AS [Spins],
    spins_per_collision                              AS [Spins per Collision],
    sleep_time                                      AS [Sleep Time],
    backoffs                                        AS [Backoffs]
FROM sys.dm_os_spinlock_stats
WHERE collisions > 0
ORDER BY spins DESC;

-- ============================================================================
-- Section 6: Query Store Wait Stats (NEW in 2017)
-- This section queries per-query wait statistics captured by Query Store.
-- Only works on databases with Query Store enabled and
-- WAIT_STATS_CAPTURE_MODE = ON.
-- ============================================================================
PRINT '';
PRINT '=== Section 6: Query Store Wait Stats (NEW in 2017) ===';
PRINT '';
PRINT 'NOTE: This section runs against each user database with Query Store enabled.';
PRINT 'It shows per-query wait statistics -- a major improvement over instance-level waits.';
PRINT '';

-- Build dynamic SQL to query each database with Query Store enabled
DECLARE @qs_wait_sql NVARCHAR(MAX) = N'';

SELECT @qs_wait_sql = @qs_wait_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    -- Top wait categories in Query Store (last 24 hours)
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        SELECT TOP 15
            DB_NAME()                               AS [Database],
            ws.wait_category_desc                   AS [Wait Category],
            SUM(ws.total_query_wait_time_ms)        AS [Total Wait Time Ms],
            SUM(ws.total_query_wait_time_ms)
                / NULLIF(SUM(ws.avg_query_wait_time_ms * 1.0), 0)
                                                    AS [Approx Wait Count],
            AVG(ws.avg_query_wait_time_ms)          AS [Avg Wait Time Ms],
            MAX(ws.max_query_wait_time_ms)          AS [Max Wait Time Ms],
            MIN(ws.min_query_wait_time_ms)          AS [Min Wait Time Ms],
            CAST(100.0 * SUM(ws.total_query_wait_time_ms)
                / NULLIF(SUM(SUM(ws.total_query_wait_time_ms)) OVER (), 0)
                AS DECIMAL(5,2))                    AS [Pct of Total]
        FROM sys.query_store_wait_stats ws
        JOIN sys.query_store_runtime_stats_interval rsi
            ON ws.runtime_stats_interval_id = rsi.runtime_stats_interval_id
        WHERE rsi.start_time >= DATEADD(HOUR, -24, GETUTCDATE())
        GROUP BY ws.wait_category_desc
        ORDER BY SUM(ws.total_query_wait_time_ms) DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @qs_wait_sql <> N''
    EXEC sp_executesql @qs_wait_sql;
ELSE
    PRINT 'No user databases have Query Store enabled.';

-- ============================================================================
-- Section 7: Top Queries by Wait (Query Store) (NEW in 2017)
-- ============================================================================
PRINT '';
PRINT '=== Section 7: Top Queries by Wait Time in Query Store (NEW in 2017) ===';
PRINT '';

DECLARE @qs_top_wait_sql NVARCHAR(MAX) = N'';

SELECT @qs_top_wait_sql = @qs_top_wait_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        SELECT TOP 20
            DB_NAME()                               AS [Database],
            q.query_id                              AS [Query ID],
            ws.wait_category_desc                   AS [Top Wait Category],
            SUM(ws.total_query_wait_time_ms)        AS [Total Wait Ms],
            AVG(ws.avg_query_wait_time_ms)          AS [Avg Wait Ms],
            rs.count_executions                     AS [Executions],
            CAST(rs.avg_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Avg Duration Ms],
            CAST(rs.avg_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [Avg CPU Ms],
            SUBSTRING(qt.query_sql_text, 1, 200)    AS [Query Text (First 200 chars)]
        FROM sys.query_store_wait_stats ws
        JOIN sys.query_store_runtime_stats_interval rsi
            ON ws.runtime_stats_interval_id = rsi.runtime_stats_interval_id
        JOIN sys.query_store_runtime_stats rs
            ON ws.runtime_stats_interval_id = rs.runtime_stats_interval_id
           AND ws.plan_id = rs.plan_id
        JOIN sys.query_store_plan p
            ON ws.plan_id = p.plan_id
        JOIN sys.query_store_query q
            ON p.query_id = q.query_id
        JOIN sys.query_store_query_text qt
            ON q.query_text_id = qt.query_text_id
        WHERE rsi.start_time >= DATEADD(HOUR, -24, GETUTCDATE())
        GROUP BY q.query_id, ws.wait_category_desc,
                 rs.count_executions, rs.avg_duration,
                 rs.avg_cpu_time, qt.query_sql_text
        ORDER BY SUM(ws.total_query_wait_time_ms) DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @qs_top_wait_sql <> N''
    EXEC sp_executesql @qs_top_wait_sql;
ELSE
    PRINT 'No user databases have Query Store enabled.';

-- ============================================================================
-- Section 8: Instance Waits vs Query Store Waits Comparison (NEW in 2017)
-- ============================================================================
PRINT '';
PRINT '=== Section 8: Instance Waits vs Query Store Waits Side-by-Side (NEW in 2017) ===';
PRINT '';
PRINT 'Instance-level waits show server-wide accumulation since restart.';
PRINT 'Query Store waits show per-query wait breakdown for recent intervals.';
PRINT 'Comparing both reveals whether top waits are driven by specific queries.';
PRINT '';

-- Instance-level wait categories for comparison
;WITH InstanceWaitCategories AS (
    SELECT
        CASE
            WHEN wait_type LIKE 'LCK_M_%'              THEN 'Lock'
            WHEN wait_type LIKE 'PAGEIOLATCH_%'         THEN 'Buffer IO'
            WHEN wait_type LIKE 'PAGELATCH_%'           THEN 'Buffer Latch'
            WHEN wait_type LIKE 'LATCH_%'               THEN 'Latch'
            WHEN wait_type = 'WRITELOG'                 THEN 'Log IO'
            WHEN wait_type LIKE 'IO_COMPLETION%'        THEN 'Other Disk IO'
            WHEN wait_type LIKE 'ASYNC_NETWORK%'        THEN 'Network IO'
            WHEN wait_type IN ('CXPACKET','CXCONSUMER') THEN 'Parallelism'
            WHEN wait_type = 'SOS_SCHEDULER_YIELD'      THEN 'CPU'
            WHEN wait_type = 'RESOURCE_SEMAPHORE'       THEN 'Memory'
            WHEN wait_type LIKE 'HADR_%'                THEN 'Replication'
            WHEN wait_type LIKE 'PREEMPTIVE_%'          THEN 'Preemptive'
            ELSE 'Other'
        END AS wait_category,
        wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE waiting_tasks_count > 0
      AND wait_type NOT IN (
        'SLEEP_TASK','WAITFOR','CLR_AUTO_EVENT','CLR_MANUAL_EVENT',
        'LAZYWRITER_SLEEP','CHECKPOINT_QUEUE','XE_TIMER_EVENT',
        'SP_SERVER_DIAGNOSTICS_SLEEP','DISPATCHER_QUEUE_SEMAPHORE',
        'REQUEST_FOR_DEADLOCK_SEARCH',
        'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP','QDS_ASYNC_QUEUE',
        'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP'
      )
)
SELECT
    wait_category                                   AS [Wait Category (Instance-Level)],
    CAST(SUM(wait_time_ms) / 1000.0
        AS DECIMAL(18,2))                           AS [Total Wait Sec],
    CAST(100.0 * SUM(wait_time_ms)
        / NULLIF(SUM(SUM(wait_time_ms)) OVER (), 0)
        AS DECIMAL(5,2))                            AS [Pct of Total],
    'Compare with Query Store wait categories above to identify per-query attribution.'
                                                    AS [Note]
FROM InstanceWaitCategories
GROUP BY wait_category
ORDER BY SUM(wait_time_ms) DESC;

PRINT '';
PRINT '=== Wait Statistics Analysis Complete ===';
