/*******************************************************************************
 * Script:    02-wait-stats.sql
 * Purpose:   Wait statistics analysis for SQL Server 2016
 * Version:   SQL Server 2016 (Compatibility Level 130)
 * Date:      2026-04-06
 *
 * Returns:   Top 25 waits by total wait time with noise filtered out,
 *            percentage of total waits, signal vs resource breakdown,
 *            and a human-readable category mapping.
 *
 * Notes:     Waits accumulate since last restart or DBCC SQLPERF('waitstats', CLEAR).
 *            Compare snapshots over time for meaningful trending.
 *
 * Safety:    Read-only. Safe for production execution.
 ******************************************************************************/

SET NOCOUNT ON;

-- ============================================================================
-- SECTION 1: Top 25 Waits — Filtered and Categorised
-- ============================================================================
-- Background / benign waits are excluded so that only actionable waits appear.

WITH WaitsFiltered AS (
    SELECT
        wait_type,
        waiting_tasks_count,
        wait_time_ms,
        max_wait_time_ms,
        signal_wait_time_ms,
        wait_time_ms - signal_wait_time_ms  AS resource_wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN (
        -- Exclude idle / background waits that add noise
        N'BROKER_EVENTHANDLER',        N'BROKER_RECEIVE_WAITFOR',
        N'BROKER_TASK_STOP',           N'BROKER_TO_FLUSH',
        N'BROKER_TRANSMITTER',         N'CHECKPOINT_QUEUE',
        N'CHKPT',                      N'CLR_AUTO_EVENT',
        N'CLR_MANUAL_EVENT',           N'CLR_SEMAPHORE',
        N'DBMIRROR_DBM_EVENT',         N'DBMIRROR_EVENTS_QUEUE',
        N'DBMIRROR_WORKER_QUEUE',      N'DBMIRRORING_CMD',
        N'DIRTY_PAGE_POLL',            N'DISPATCHER_QUEUE_SEMAPHORE',
        N'EXECSYNC',                   N'FSAGENT',
        N'FT_IFTS_SCHEDULER_IDLE_WAIT',N'FT_IFTSHC_MUTEX',
        N'HADR_CLUSAPI_CALL',          N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        N'HADR_LOGCAPTURE_WAIT',       N'HADR_NOTIFICATION_DEQUEUE',
        N'HADR_TIMER_TASK',            N'HADR_WORK_QUEUE',
        N'KSOURCE_WAKEUP',            N'LAZYWRITER_SLEEP',
        N'LOGMGR_QUEUE',              N'MEMORY_ALLOCATION_EXT',
        N'ONDEMAND_TASK_QUEUE',        N'PARALLEL_REDO_DRAIN_WORKER',
        N'PARALLEL_REDO_LOG_CACHE',    N'PARALLEL_REDO_TRAN_LIST',
        N'PARALLEL_REDO_WORKER_SYNC',  N'PARALLEL_REDO_WORKER_WAIT_WORK',
        N'PREEMPTIVE_XE_GETTARGETSTATE',
        N'PWAIT_ALL_COMPONENTS_INITIALIZED',
        N'PWAIT_DIRECTLOGCONSUMER_GETNEXT',
        N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
        N'QDS_ASYNC_QUEUE',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
        N'QDS_SHUTDOWN_QUEUE',
        N'REDO_THREAD_PENDING_WORK',   N'REQUEST_FOR_DEADLOCK_SEARCH',
        N'RESOURCE_QUEUE',             N'SERVER_IDLE_CHECK',
        N'SLEEP_BPOOL_FLUSH',          N'SLEEP_DBSTARTUP',
        N'SLEEP_DCOMSTARTUP',          N'SLEEP_MASTERDBREADY',
        N'SLEEP_MASTERMDREADY',        N'SLEEP_MASTERUPGRADED',
        N'SLEEP_MSDBSTARTUP',          N'SLEEP_SYSTEMTASK',
        N'SLEEP_TASK',                 N'SLEEP_TEMPDBSTARTUP',
        N'SNI_HTTP_ACCEPT',            N'SP_SERVER_DIAGNOSTICS_SLEEP',
        N'SQLTRACE_BUFFER_FLUSH',      N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        N'SQLTRACE_WAIT_ENTRIES',      N'WAIT_FOR_RESULTS',
        N'WAITFOR',                    N'WAITFOR_TASKSHUTDOWN',
        N'WAIT_XTP_CKPT_CLOSE',       N'WAIT_XTP_HOST_WAIT',
        N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
        N'WAIT_XTP_RECOVERY',          N'XE_BUFFERMGR_ALLPROCESSED_EVENT',
        N'XE_DISPATCHER_JOIN',         N'XE_DISPATCHER_WAIT',
        N'XE_LIVE_TARGET_TVF',         N'XE_TIMER_EVENT'
    )
    AND waiting_tasks_count > 0
),
WaitsWithTotal AS (
    SELECT
        *,
        SUM(wait_time_ms) OVER () AS total_wait_time_ms
    FROM WaitsFiltered
),
WaitsCategorised AS (
    SELECT
        wait_type,
        waiting_tasks_count                             AS [Wait Count],
        CAST(wait_time_ms / 1000.0 AS DECIMAL(18,2))   AS [Wait Time Sec],
        CAST(resource_wait_time_ms / 1000.0 AS DECIMAL(18,2))
                                                        AS [Resource Wait Sec],
        CAST(signal_wait_time_ms / 1000.0 AS DECIMAL(18,2))
                                                        AS [Signal Wait Sec],
        CAST(100.0 * wait_time_ms / NULLIF(total_wait_time_ms, 0)
             AS DECIMAL(6,2))                           AS [Pct of Total],
        CAST(100.0 * signal_wait_time_ms / NULLIF(wait_time_ms, 0)
             AS DECIMAL(6,2))                           AS [Signal Pct],
        CASE WHEN waiting_tasks_count > 0
             THEN CAST(wait_time_ms * 1.0 / waiting_tasks_count AS DECIMAL(18,2))
             ELSE 0 END                                 AS [Avg Wait Ms],
        max_wait_time_ms                                AS [Max Wait Ms],

        -- Category mapping
        CASE
            -- CPU / Scheduler
            WHEN wait_type IN (N'SOS_SCHEDULER_YIELD', N'THREADPOOL',
                               N'SOS_WORKER_MIGRATION')
                THEN 'CPU'
            WHEN wait_type LIKE N'CXPACKET%'
              OR wait_type LIKE N'CXCONSUMER%'
                THEN 'Parallelism'

            -- I/O
            WHEN wait_type IN (N'PAGEIOLATCH_SH', N'PAGEIOLATCH_EX',
                               N'PAGEIOLATCH_UP', N'PAGEIOLATCH_DT',
                               N'PAGEIOLATCH_NL', N'PAGEIOLATCH_KP',
                               N'IO_COMPLETION', N'ASYNC_IO_COMPLETION',
                               N'WRITE_COMPLETION', N'WRITELOG',
                               N'LOGBUFFER')
                THEN 'IO'

            -- Locking
            WHEN wait_type IN (N'LCK_M_S', N'LCK_M_X', N'LCK_M_U',
                               N'LCK_M_IS', N'LCK_M_IX', N'LCK_M_SIX',
                               N'LCK_M_SCH_S', N'LCK_M_SCH_M',
                               N'LCK_M_BU', N'LCK_M_RS_S', N'LCK_M_RS_U',
                               N'LCK_M_RIn_NL', N'LCK_M_RIn_S',
                               N'LCK_M_RIn_U', N'LCK_M_RIn_X',
                               N'LCK_M_RX_S', N'LCK_M_RX_U', N'LCK_M_RX_X')
                THEN 'Lock'

            -- Latch (non-IO)
            WHEN wait_type LIKE N'PAGELATCH_%'
                THEN 'Latch (Buffer)'
            WHEN wait_type LIKE N'LATCH_%'
                THEN 'Latch (Non-Buffer)'

            -- Memory
            WHEN wait_type IN (N'RESOURCE_SEMAPHORE', N'CMEMTHREAD',
                               N'RESOURCE_SEMAPHORE_QUERY_COMPILE',
                               N'SOS_VIRTUALMEMORY_LOW',
                               N'RESOURCE_SEMAPHORE_SMALL_QUERY')
                THEN 'Memory'

            -- Network
            WHEN wait_type IN (N'ASYNC_NETWORK_IO', N'NET_WAITFOR_PACKET')
                THEN 'Network'

            -- Transaction Log
            WHEN wait_type IN (N'WRITELOG', N'LOGBUFFER',
                               N'LOG_RATE_GOVERNOR')
                THEN 'Transaction Log'

            -- Backup / Restore
            WHEN wait_type LIKE N'BACKUP%'
                THEN 'Backup'

            -- Always On / HADR
            WHEN wait_type LIKE N'HADR_%'
                THEN 'Always On (HADR)'

            -- Preemptive (OS calls)
            WHEN wait_type LIKE N'PREEMPTIVE_%'
                THEN 'Preemptive (OS)'

            ELSE 'Other'
        END                                             AS [Wait Category]
    FROM WaitsWithTotal
)
SELECT TOP 25
    ROW_NUMBER() OVER (ORDER BY [Wait Time Sec] DESC)  AS [Rank],
    wait_type                               AS [Wait Type],
    [Wait Category],
    [Wait Count],
    [Wait Time Sec],
    [Resource Wait Sec],
    [Signal Wait Sec],
    [Pct of Total],
    [Signal Pct],
    [Avg Wait Ms],
    [Max Wait Ms]
FROM WaitsCategorised
ORDER BY [Wait Time Sec] DESC;


-- ============================================================================
-- SECTION 2: Wait Category Summary
-- ============================================================================
-- Aggregates waits into categories for a high-level view of where time is spent.

;WITH WaitsFiltered AS (
    SELECT
        wait_type,
        wait_time_ms,
        signal_wait_time_ms,
        wait_time_ms - signal_wait_time_ms AS resource_wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN (
        N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR',
        N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH', N'BROKER_TRANSMITTER',
        N'CHECKPOINT_QUEUE', N'CHKPT', N'CLR_AUTO_EVENT',
        N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',
        N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
        N'FSAGENT', N'FT_IFTS_SCHEDULER_IDLE_WAIT',
        N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        N'HADR_LOGCAPTURE_WAIT', N'HADR_NOTIFICATION_DEQUEUE',
        N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
        N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE',
        N'ONDEMAND_TASK_QUEUE', N'REQUEST_FOR_DEADLOCK_SEARCH',
        N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK',
        N'SLEEP_BPOOL_FLUSH', N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP',
        N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
        N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP',
        N'SLEEP_SYSTEMTASK', N'SLEEP_TASK', N'SLEEP_TEMPDBSTARTUP',
        N'SNI_HTTP_ACCEPT', N'SP_SERVER_DIAGNOSTICS_SLEEP',
        N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        N'SQLTRACE_WAIT_ENTRIES', N'WAIT_FOR_RESULTS',
        N'WAITFOR', N'WAITFOR_TASKSHUTDOWN',
        N'XE_BUFFERMGR_ALLPROCESSED_EVENT', N'XE_DISPATCHER_JOIN',
        N'XE_DISPATCHER_WAIT', N'XE_LIVE_TARGET_TVF', N'XE_TIMER_EVENT',
        N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', N'QDS_ASYNC_QUEUE',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
        N'QDS_SHUTDOWN_QUEUE'
    )
    AND waiting_tasks_count > 0
),
Categorised AS (
    SELECT
        CASE
            WHEN wait_type IN (N'SOS_SCHEDULER_YIELD', N'THREADPOOL') THEN 'CPU'
            WHEN wait_type LIKE N'CXPACKET%' OR wait_type LIKE N'CXCONSUMER%' THEN 'Parallelism'
            WHEN wait_type LIKE N'PAGEIOLATCH_%' OR wait_type IN (N'IO_COMPLETION',
                 N'ASYNC_IO_COMPLETION', N'WRITE_COMPLETION') THEN 'IO'
            WHEN wait_type IN (N'WRITELOG', N'LOGBUFFER') THEN 'Transaction Log'
            WHEN wait_type LIKE N'LCK_M_%' THEN 'Lock'
            WHEN wait_type LIKE N'PAGELATCH_%' THEN 'Latch (Buffer)'
            WHEN wait_type LIKE N'LATCH_%' THEN 'Latch (Non-Buffer)'
            WHEN wait_type IN (N'RESOURCE_SEMAPHORE', N'CMEMTHREAD',
                 N'RESOURCE_SEMAPHORE_QUERY_COMPILE') THEN 'Memory'
            WHEN wait_type IN (N'ASYNC_NETWORK_IO', N'NET_WAITFOR_PACKET') THEN 'Network'
            WHEN wait_type LIKE N'HADR_%' THEN 'Always On (HADR)'
            WHEN wait_type LIKE N'PREEMPTIVE_%' THEN 'Preemptive (OS)'
            WHEN wait_type LIKE N'BACKUP%' THEN 'Backup'
            ELSE 'Other'
        END AS wait_category,
        wait_time_ms,
        signal_wait_time_ms,
        resource_wait_time_ms
    FROM WaitsFiltered
)
SELECT
    wait_category                                       AS [Wait Category],
    SUM(wait_time_ms) / 1000                            AS [Total Wait Sec],
    SUM(resource_wait_time_ms) / 1000                   AS [Resource Wait Sec],
    SUM(signal_wait_time_ms) / 1000                     AS [Signal Wait Sec],
    CAST(100.0 * SUM(wait_time_ms)
         / NULLIF(SUM(SUM(wait_time_ms)) OVER (), 0)
         AS DECIMAL(6,2))                               AS [Pct of Total]
FROM Categorised
GROUP BY wait_category
ORDER BY [Total Wait Sec] DESC;


-- ============================================================================
-- SECTION 3: Signal Wait Ratio (CPU Pressure Indicator)
-- ============================================================================
-- A signal-to-total ratio above ~15-20% may indicate CPU pressure.

SELECT
    CAST(100.0 * SUM(signal_wait_time_ms)
         / NULLIF(SUM(wait_time_ms), 0) AS DECIMAL(6,2))   AS [Overall Signal Wait Pct],
    CASE
        WHEN 100.0 * SUM(signal_wait_time_ms) / NULLIF(SUM(wait_time_ms), 0) > 20
            THEN 'HIGH — Possible CPU pressure'
        WHEN 100.0 * SUM(signal_wait_time_ms) / NULLIF(SUM(wait_time_ms), 0) > 10
            THEN 'MODERATE — Monitor closely'
        ELSE 'LOW — CPU scheduling looks healthy'
    END                                                     AS [Assessment]
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    N'SLEEP_TASK', N'WAITFOR', N'LAZYWRITER_SLEEP',
    N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP',
    N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT',
    N'DISPATCHER_QUEUE_SEMAPHORE', N'XE_DISPATCHER_WAIT'
)
AND waiting_tasks_count > 0;
