/******************************************************************************
 * 02-wait-stats.sql
 * SQL Server 2019 (Compatibility Level 150) — Wait Statistics Analysis
 *
 * Enhanced for 2019:
 *   - PERSISTENT_VERSION_STORE wait type category for ADR monitoring   [NEW]
 *   - Additional ADR-related wait types                                [NEW]
 *
 * Safe: read-only, no temp tables, no cursors.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — Top Waits by Total Wait Time (excluding benign waits)
  Includes PERSISTENT_VERSION_STORE category for ADR monitoring.        [NEW]
=============================================================================*/
;WITH WaitStats AS (
    SELECT
        ws.wait_type,
        ws.waiting_tasks_count,
        ws.wait_time_ms,
        ws.max_wait_time_ms,
        ws.signal_wait_time_ms,
        ws.wait_time_ms - ws.signal_wait_time_ms AS resource_wait_time_ms,
        CASE
            -- NEW 2019: ADR / Persistent Version Store waits
            WHEN ws.wait_type LIKE 'PVS_%'
                THEN 'Persistent Version Store (ADR)'
            WHEN ws.wait_type LIKE 'VERSIONED_%'
                THEN 'Persistent Version Store (ADR)'

            -- CPU / Scheduler
            WHEN ws.wait_type LIKE 'SOS_SCHEDULER_YIELD'
                THEN 'CPU'
            WHEN ws.wait_type LIKE 'CXPACKET'
                THEN 'Parallelism'
            WHEN ws.wait_type LIKE 'CXCONSUMER'
                THEN 'Parallelism'
            WHEN ws.wait_type LIKE 'CXSYNC_PORT'
                THEN 'Parallelism'
            WHEN ws.wait_type LIKE 'CXSYNC_CONSUMER'
                THEN 'Parallelism'

            -- I/O
            WHEN ws.wait_type LIKE 'PAGEIOLATCH_%'
                THEN 'Buffer I/O'
            WHEN ws.wait_type LIKE 'WRITELOG'
                THEN 'Transaction Log I/O'
            WHEN ws.wait_type LIKE 'IO_COMPLETION'
                THEN 'Disk I/O'
            WHEN ws.wait_type LIKE 'ASYNC_IO_COMPLETION'
                THEN 'Disk I/O'

            -- Locks
            WHEN ws.wait_type LIKE 'LCK_%'
                THEN 'Lock'

            -- Latch
            WHEN ws.wait_type LIKE 'PAGELATCH_%'
                THEN 'Buffer Latch'
            WHEN ws.wait_type LIKE 'LATCH_%'
                THEN 'Non-Buffer Latch'

            -- Memory
            WHEN ws.wait_type IN ('RESOURCE_SEMAPHORE', 'RESOURCE_SEMAPHORE_QUERY_COMPILE')
                THEN 'Memory Grant'
            WHEN ws.wait_type LIKE 'CMEMTHREAD'
                THEN 'Memory'

            -- Network
            WHEN ws.wait_type LIKE 'ASYNC_NETWORK_IO'
                THEN 'Network / Client'

            -- Availability Groups
            WHEN ws.wait_type LIKE 'HADR_%'
                THEN 'Availability Groups'

            -- Backup
            WHEN ws.wait_type LIKE 'BACKUPIO'
                THEN 'Backup I/O'

            ELSE 'Other'
        END                                 AS wait_category
    FROM sys.dm_os_wait_stats AS ws
    WHERE ws.wait_type NOT IN (
        /* Filter out benign / background waits */
        'CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE',
        'SLEEP_TASK', 'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH',
        'WAITFOR', 'LOGMGR_QUEUE', 'CHECKPOINT_QUEUE',
        'REQUEST_FOR_DEADLOCK_SEARCH', 'XE_TIMER_EVENT',
        'BROKER_TO_FLUSH', 'BROKER_TASK_STOP', 'CLR_MANUAL_EVENT',
        'CLR_AUTO_EVENT', 'DISPATCHER_QUEUE_SEMAPHORE',
        'FT_IFTS_SCHEDULER_IDLE_WAIT', 'XE_DISPATCHER_WAIT',
        'XE_DISPATCHER_JOIN', 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        'ONDEMAND_TASK_QUEUE', 'BROKER_EVENTHANDLER',
        'SLEEP_BPOOL_FLUSH', 'SLEEP_DBSTARTUP',
        'DIRTY_PAGE_POLL', 'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        'SP_SERVER_DIAGNOSTICS_SLEEP', 'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
        'QDS_ASYNC_QUEUE', 'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
        'WAIT_XTP_CKPT_CLOSE', 'REDO_THREAD_PENDING_WORK',
        'PARALLEL_REDO_DRAIN_WORKER', 'PARALLEL_REDO_LOG_CACHE',
        'PARALLEL_REDO_TRAN_LIST', 'PARALLEL_REDO_WORKER_SYNC',
        'PARALLEL_REDO_WORKER_WAIT_WORK'
    )
    AND ws.waiting_tasks_count > 0
),
RankedWaits AS (
    SELECT
        w.wait_type,
        w.wait_category,
        w.waiting_tasks_count,
        w.wait_time_ms,
        w.resource_wait_time_ms,
        w.signal_wait_time_ms,
        w.max_wait_time_ms,
        CAST(100.0 * w.wait_time_ms
             / NULLIF(SUM(w.wait_time_ms) OVER (), 0)
             AS DECIMAL(5,2))               AS pct_of_total_waits,
        ROW_NUMBER() OVER (
            ORDER BY w.wait_time_ms DESC
        )                                   AS wait_rank
    FROM WaitStats AS w
)
SELECT
    rw.wait_rank,
    rw.wait_type,
    rw.wait_category,
    rw.waiting_tasks_count                  AS task_count,
    rw.wait_time_ms                         AS total_wait_ms,
    rw.resource_wait_time_ms                AS resource_wait_ms,
    rw.signal_wait_time_ms                  AS signal_wait_ms,
    rw.max_wait_time_ms                     AS max_single_wait_ms,
    CASE
        WHEN rw.waiting_tasks_count > 0
        THEN CAST(rw.wait_time_ms * 1.0
                   / rw.waiting_tasks_count AS DECIMAL(18,2))
        ELSE 0
    END                                     AS avg_wait_ms,
    rw.pct_of_total_waits
FROM RankedWaits AS rw
WHERE rw.wait_rank <= 50
ORDER BY rw.wait_rank;

/*=============================================================================
  Section 2 — Wait Category Summary
  NEW: Persistent Version Store (ADR) appears as its own category.      [NEW]
=============================================================================*/
;WITH WaitStats AS (
    SELECT
        ws.wait_type,
        ws.waiting_tasks_count,
        ws.wait_time_ms,
        ws.signal_wait_time_ms,
        ws.wait_time_ms - ws.signal_wait_time_ms AS resource_wait_time_ms,
        CASE
            WHEN ws.wait_type LIKE 'PVS_%'
                 OR ws.wait_type LIKE 'VERSIONED_%'
                THEN 'Persistent Version Store (ADR)'
            WHEN ws.wait_type = 'SOS_SCHEDULER_YIELD'
                THEN 'CPU'
            WHEN ws.wait_type IN ('CXPACKET','CXCONSUMER','CXSYNC_PORT','CXSYNC_CONSUMER')
                THEN 'Parallelism'
            WHEN ws.wait_type LIKE 'PAGEIOLATCH_%'
                THEN 'Buffer I/O'
            WHEN ws.wait_type = 'WRITELOG'
                THEN 'Transaction Log I/O'
            WHEN ws.wait_type LIKE 'IO_COMPLETION'
                 OR ws.wait_type = 'ASYNC_IO_COMPLETION'
                THEN 'Disk I/O'
            WHEN ws.wait_type LIKE 'LCK_%'
                THEN 'Lock'
            WHEN ws.wait_type LIKE 'PAGELATCH_%'
                THEN 'Buffer Latch'
            WHEN ws.wait_type LIKE 'LATCH_%'
                THEN 'Non-Buffer Latch'
            WHEN ws.wait_type IN ('RESOURCE_SEMAPHORE','RESOURCE_SEMAPHORE_QUERY_COMPILE')
                THEN 'Memory Grant'
            WHEN ws.wait_type = 'ASYNC_NETWORK_IO'
                THEN 'Network / Client'
            WHEN ws.wait_type LIKE 'HADR_%'
                THEN 'Availability Groups'
            ELSE 'Other'
        END                                 AS wait_category
    FROM sys.dm_os_wait_stats AS ws
    WHERE ws.waiting_tasks_count > 0
      AND ws.wait_type NOT IN (
        'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE',
        'SLEEP_TASK','SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH',
        'WAITFOR','LOGMGR_QUEUE','CHECKPOINT_QUEUE',
        'REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT',
        'BROKER_TO_FLUSH','BROKER_TASK_STOP','CLR_MANUAL_EVENT',
        'CLR_AUTO_EVENT','DISPATCHER_QUEUE_SEMAPHORE',
        'FT_IFTS_SCHEDULER_IDLE_WAIT','XE_DISPATCHER_WAIT',
        'XE_DISPATCHER_JOIN','SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        'ONDEMAND_TASK_QUEUE','BROKER_EVENTHANDLER',
        'SLEEP_BPOOL_FLUSH','SLEEP_DBSTARTUP','DIRTY_PAGE_POLL',
        'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        'SP_SERVER_DIAGNOSTICS_SLEEP',
        'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP','QDS_ASYNC_QUEUE',
        'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
        'WAIT_XTP_CKPT_CLOSE','REDO_THREAD_PENDING_WORK',
        'PARALLEL_REDO_DRAIN_WORKER','PARALLEL_REDO_LOG_CACHE',
        'PARALLEL_REDO_TRAN_LIST','PARALLEL_REDO_WORKER_SYNC',
        'PARALLEL_REDO_WORKER_WAIT_WORK'
      )
)
SELECT
    w.wait_category,
    COUNT(*)                                AS distinct_wait_types,
    SUM(w.waiting_tasks_count)              AS total_task_count,
    SUM(w.wait_time_ms)                     AS total_wait_ms,
    SUM(w.resource_wait_time_ms)            AS total_resource_wait_ms,
    SUM(w.signal_wait_time_ms)              AS total_signal_wait_ms,
    CAST(100.0 * SUM(w.wait_time_ms)
         / NULLIF(SUM(SUM(w.wait_time_ms)) OVER (), 0)
         AS DECIMAL(5,2))                   AS pct_of_total
FROM WaitStats AS w
GROUP BY w.wait_category
ORDER BY total_wait_ms DESC;

/*=============================================================================
  Section 3 — ADR-Specific Wait Types Detail                           [NEW]
  Isolated view of Persistent Version Store waits.
=============================================================================*/
SELECT
    ws.wait_type,
    ws.waiting_tasks_count                  AS task_count,
    ws.wait_time_ms                         AS total_wait_ms,
    ws.wait_time_ms - ws.signal_wait_time_ms AS resource_wait_ms,
    ws.signal_wait_time_ms                  AS signal_wait_ms,
    ws.max_wait_time_ms                     AS max_single_wait_ms,
    CASE
        WHEN ws.waiting_tasks_count > 0
        THEN CAST(ws.wait_time_ms * 1.0
                   / ws.waiting_tasks_count AS DECIMAL(18,2))
        ELSE 0
    END                                     AS avg_wait_ms
FROM sys.dm_os_wait_stats AS ws
WHERE (
    ws.wait_type LIKE 'PVS_%'
    OR ws.wait_type LIKE 'VERSIONED_%'
    OR ws.wait_type LIKE 'ADR_%'
    OR ws.wait_type IN (
        'PERSISTENT_VERSION_STORE',
        'VERSION_STORE_CLEANUP'
    )
)
AND ws.waiting_tasks_count > 0
ORDER BY ws.wait_time_ms DESC;

/*=============================================================================
  Section 4 — Signal Wait Ratio (CPU pressure indicator)
=============================================================================*/
SELECT
    SUM(ws.signal_wait_time_ms)             AS total_signal_wait_ms,
    SUM(ws.wait_time_ms)                    AS total_wait_ms,
    CAST(100.0 * SUM(ws.signal_wait_time_ms)
         / NULLIF(SUM(ws.wait_time_ms), 0)
         AS DECIMAL(5,2))                   AS signal_wait_pct,
    CASE
        WHEN 100.0 * SUM(ws.signal_wait_time_ms)
             / NULLIF(SUM(ws.wait_time_ms), 0) > 25
        THEN 'Possible CPU pressure (signal waits > 25%)'
        ELSE 'Signal waits within normal range'
    END                                     AS assessment
FROM sys.dm_os_wait_stats AS ws
WHERE ws.wait_type NOT IN (
    'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE',
    'SLEEP_TASK','SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH',
    'WAITFOR','LOGMGR_QUEUE','CHECKPOINT_QUEUE',
    'REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT',
    'BROKER_TO_FLUSH','BROKER_TASK_STOP'
);

/*=============================================================================
  Section 5 — Latch Wait Detail
=============================================================================*/
SELECT TOP 25
    ls.latch_class,
    ls.waiting_requests_count               AS wait_count,
    ls.wait_time_ms                         AS total_wait_ms,
    ls.max_wait_time_ms                     AS max_single_wait_ms,
    CASE
        WHEN ls.waiting_requests_count > 0
        THEN CAST(ls.wait_time_ms * 1.0
                   / ls.waiting_requests_count AS DECIMAL(18,2))
        ELSE 0
    END                                     AS avg_wait_ms
FROM sys.dm_os_latch_stats AS ls
WHERE ls.waiting_requests_count > 0
ORDER BY ls.wait_time_ms DESC;
