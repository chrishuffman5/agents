/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Wait Statistics Analysis
 *
 * Purpose : Identify top waits causing performance bottlenecks.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Top Waits by Cumulative Wait Time (Filtered)
 *   2. Wait Category Breakdown
 *   3. Latch Wait Analysis
 *   4. Spinlock Contention
 *   5. Current In-Progress Waits
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: Top Waits by Cumulative Wait Time
  Filters out benign / idle waits that inflate numbers.
──────────────────────────────────────────────────────────────────────────────*/
;WITH filtered_waits AS (
    SELECT
        wait_type,
        waiting_tasks_count,
        wait_time_ms,
        max_wait_time_ms,
        signal_wait_time_ms,
        wait_time_ms - signal_wait_time_ms          AS resource_wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN (
        -- Benign / idle waits to exclude
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
        N'PREEMPTIVE_OS_FLUSHFILEBUFFERS',
        N'PREEMPTIVE_XE_GETTARGETSTATE',
        N'PVS_PREALLOCATE',           N'PWAIT_ALL_COMPONENTS_INITIALIZED',
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
        N'SNI_HTTP_ACCEPT',            N'SOS_WORK_DISPATCHER',
        N'SP_SERVER_DIAGNOSTICS_SLEEP',N'SQLTRACE_BUFFER_FLUSH',
        N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        N'SQLTRACE_WAIT_ENTRIES',      N'VDI_CLIENT_OTHER',
        N'WAIT_FOR_RESULTS',           N'WAITFOR',
        N'WAITFOR_TASKSHUTDOWN',       N'WAIT_XTP_CKPT_CLOSE',
        N'WAIT_XTP_HOST_WAIT',         N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
        N'WAIT_XTP_RECOVERY',          N'XE_BUFFERMGR_ALLPROCESSED_EVENT',
        N'XE_DISPATCHER_JOIN',         N'XE_DISPATCHER_WAIT',
        N'XE_TIMER_EVENT'
    )
    AND waiting_tasks_count > 0
),
total AS (
    SELECT SUM(wait_time_ms) AS total_wait_time_ms
    FROM filtered_waits
)
SELECT TOP (25)
    fw.wait_type,
    fw.waiting_tasks_count                          AS wait_count,
    fw.wait_time_ms                                 AS total_wait_ms,
    CAST(fw.wait_time_ms * 100.0
        / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(5,2))
                                                    AS pct_of_total,
    CAST(fw.wait_time_ms * 1.0
        / NULLIF(fw.waiting_tasks_count, 0) AS DECIMAL(18,2))
                                                    AS avg_wait_ms,
    fw.max_wait_time_ms                             AS max_wait_ms,
    fw.signal_wait_time_ms                          AS signal_wait_ms,
    fw.resource_wait_time_ms                        AS resource_wait_ms,
    CAST(fw.signal_wait_time_ms * 100.0
        / NULLIF(fw.wait_time_ms, 0) AS DECIMAL(5,2))
                                                    AS signal_pct
FROM filtered_waits AS fw
CROSS JOIN total AS t
ORDER BY fw.wait_time_ms DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: Wait Category Breakdown
  Groups waits into human-readable categories for quick triage.
──────────────────────────────────────────────────────────────────────────────*/
;WITH categorized_waits AS (
    SELECT
        CASE
            WHEN wait_type LIKE N'LCK_%'                    THEN 'Lock'
            WHEN wait_type LIKE N'LATCH_%'                  THEN 'Latch'
            WHEN wait_type LIKE N'PAGELATCH_%'              THEN 'Buffer Latch'
            WHEN wait_type LIKE N'PAGEIOLATCH_%'            THEN 'Buffer I/O'
            WHEN wait_type LIKE N'HADR_%'                   THEN 'Availability Group'
            WHEN wait_type LIKE N'PREEMPTIVE_%'             THEN 'Preemptive (External)'
            WHEN wait_type IN (N'ASYNC_NETWORK_IO',
                               N'NET_WAITFOR_PACKET')       THEN 'Network'
            WHEN wait_type LIKE N'CXPACKET'
              OR wait_type LIKE N'CXCONSUMER'
              OR wait_type LIKE N'CXSYNC_PORT'              THEN 'Parallelism'
            WHEN wait_type IN (N'RESOURCE_SEMAPHORE')       THEN 'Memory Grant'
            WHEN wait_type LIKE N'WRITELOG'
              OR wait_type LIKE N'LOGBUFFER'
              OR wait_type LIKE N'LOG%'                     THEN 'Transaction Log'
            WHEN wait_type IN (N'SOS_SCHEDULER_YIELD',
                               N'THREADPOOL')               THEN 'CPU / Scheduler'
            WHEN wait_type LIKE N'IO_COMPLETION'
              OR wait_type LIKE N'ASYNC_IO_COMPLETION'      THEN 'Disk I/O'
            ELSE 'Other'
        END AS wait_category,
        wait_time_ms,
        waiting_tasks_count,
        signal_wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE waiting_tasks_count > 0
)
SELECT
    wait_category,
    SUM(waiting_tasks_count)                        AS total_wait_count,
    SUM(wait_time_ms)                               AS total_wait_ms,
    SUM(signal_wait_time_ms)                        AS total_signal_ms,
    SUM(wait_time_ms) - SUM(signal_wait_time_ms)    AS total_resource_ms
FROM categorized_waits
GROUP BY wait_category
ORDER BY total_wait_ms DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: Latch Wait Analysis
──────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (15)
    wait_type                                       AS latch_wait_type,
    waiting_tasks_count                             AS wait_count,
    wait_time_ms                                    AS total_wait_ms,
    CAST(wait_time_ms * 1.0
        / NULLIF(waiting_tasks_count, 0) AS DECIMAL(18,2))
                                                    AS avg_wait_ms,
    max_wait_time_ms                                AS max_wait_ms
FROM sys.dm_os_wait_stats
WHERE (wait_type LIKE N'LATCH_%' OR wait_type LIKE N'PAGELATCH_%')
  AND waiting_tasks_count > 0
ORDER BY wait_time_ms DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Spinlock Contention
──────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (15)
    name                                            AS spinlock_name,
    collisions,
    spins,
    spins_per_collision,
    sleep_time,
    backoffs
FROM sys.dm_os_spinlock_stats
WHERE collisions > 0
ORDER BY spins DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: Current In-Progress Waits (Active Sessions)
──────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (50)
    owt.session_id,
    owt.exec_context_id,
    owt.wait_type,
    owt.wait_duration_ms,
    owt.blocking_session_id,
    owt.resource_description,
    es.login_name,
    es.host_name,
    es.program_name,
    er.command,
    er.status                                       AS request_status,
    DB_NAME(er.database_id)                         AS database_name
FROM sys.dm_os_waiting_tasks AS owt
INNER JOIN sys.dm_exec_sessions AS es
    ON owt.session_id = es.session_id
LEFT JOIN sys.dm_exec_requests AS er
    ON owt.session_id = er.session_id
WHERE owt.session_id > 50  -- exclude system SPIDs
ORDER BY owt.wait_duration_ms DESC;
