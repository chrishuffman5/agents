# SQL Server Diagnostics Reference

## Diagnostic Workflow

The standard troubleshooting approach for SQL Server performance issues:

```
1. Wait Statistics  -->  What is SQL Server waiting on?
        |
2. Top Resource Queries  -->  Which queries consume the most CPU/IO/memory?
        |
3. Blocking Analysis  -->  Are queries blocked by other sessions?
        |
4. Execution Plan Review  -->  Why is a specific query slow?
        |
5. Configuration Review  -->  Are instance/database settings optimal?
```

Always start with waits. They tell you where the bottleneck is before you dig into individual queries.

## Step 1: Wait Statistics

### Instance-Level Waits

```sql
-- Top waits since instance restart (filtered for background noise)
WITH Waits AS (
    SELECT wait_type, wait_time_ms, signal_wait_time_ms,
           waiting_tasks_count,
           wait_time_ms - signal_wait_time_ms AS resource_wait_ms,
           100.0 * wait_time_ms / SUM(wait_time_ms) OVER() AS pct,
           ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS rn
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN (
        'SLEEP_TASK','BROKER_TO_FLUSH','SQLTRACE_BUFFER_FLUSH',
        'CLR_AUTO_EVENT','CLR_MANUAL_EVENT','LAZYWRITER_SLEEP',
        'CHECKPOINT_QUEUE','WAITFOR','XE_TIMER_EVENT',
        'FT_IFTS_SCHEDULER_IDLE_WAIT','LOGMGR_QUEUE',
        'DIRTY_PAGE_POLL','HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        'SP_SERVER_DIAGNOSTICS_SLEEP','XE_DISPATCHER_WAIT',
        'DISPATCHER_QUEUE_SEMAPHORE','WAIT_FOR_RESULTS',
        'BROKER_EVENTHANDLER','BROKER_RECEIVE_WAITFOR',
        'BROKER_TASK_STOP','BROKER_TRANSMITTER',
        'KSOURCE_WAKEUP','ONDEMAND_TASK_QUEUE',
        'DBMIRROR_EVENTS_QUEUE','DBMIRRORING_CMD',
        'REQUEST_FOR_DEADLOCK_SEARCH','SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        'PREEMPTIVE_OS_AUTHENTICATIONOPS','PREEMPTIVE_OS_GETPROCADDRESS'
    )
    AND waiting_tasks_count > 0
)
SELECT wait_type, resource_wait_ms, signal_wait_time_ms,
       waiting_tasks_count,
       resource_wait_ms / NULLIF(waiting_tasks_count, 0) AS avg_resource_wait_ms,
       CAST(pct AS DECIMAL(5,2)) AS pct,
       CAST(SUM(pct) OVER(ORDER BY rn) AS DECIMAL(5,2)) AS running_pct
FROM Waits
WHERE rn <= 20
ORDER BY rn;
```

### Wait Category Quick Reference

| Wait Category | Key Waits | Root Cause | Next Step |
|---|---|---|---|
| **CPU** | `SOS_SCHEDULER_YIELD`, `CXPACKET`, `CXCONSUMER` | High CPU queries, excessive parallelism | Find top CPU queries |
| **I/O** | `PAGEIOLATCH_SH/EX`, `WRITELOG`, `IO_COMPLETION` | Disk latency, missing indexes, memory pressure | Check I/O latency DMVs |
| **Locking** | `LCK_M_S/X/U/IX`, `LCK_M_SCH_M` | Blocking, long transactions | Blocking chain analysis |
| **Memory** | `RESOURCE_SEMAPHORE`, `CMEMTHREAD` | Memory grant waits, memory pressure | Memory grant analysis |
| **Network** | `ASYNC_NETWORK_IO` | Client not consuming results | Application-side investigation |
| **Tempdb** | `PAGELATCH_UP/EX` on 2:1:n | Tempdb allocation contention | Tempdb file configuration |
| **AG** | `HADR_SYNC_COMMIT`, `PARALLEL_REDO_TRAN_TURN` | AG synchronization latency | AG replica health |

## Step 2: Top Resource-Consuming Queries

### Using DMVs (Plan Cache)

```sql
-- Top 20 queries by total CPU
SELECT TOP 20
    qs.total_worker_time / 1000 AS total_cpu_ms,
    qs.execution_count,
    qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_cpu_ms,
    qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_logical_reads,
    SUBSTRING(qt.text, qs.statement_start_offset/2 + 1,
        (CASE WHEN qs.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
              ELSE qs.statement_end_offset END - qs.statement_start_offset) / 2 + 1) AS query_text,
    qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.total_worker_time DESC;
```

### Using Query Store (2016+)

Query Store provides historical query performance data that persists across restarts.

```sql
-- Top queries by average duration in the last hour
SELECT TOP 20
    q.query_id,
    qt.query_sql_text,
    rs.avg_duration / 1000.0 AS avg_duration_ms,
    rs.avg_cpu_time / 1000.0 AS avg_cpu_ms,
    rs.avg_logical_io_reads,
    rs.count_executions,
    p.plan_id, p.query_plan
FROM sys.query_store_runtime_stats rs
JOIN sys.query_store_plan p ON rs.plan_id = p.plan_id
JOIN sys.query_store_query q ON p.query_id = q.query_id
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_runtime_stats_interval rsi ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE rsi.start_time >= DATEADD(HOUR, -1, GETUTCDATE())
ORDER BY rs.avg_duration DESC;

-- Regressed queries (plan changes causing performance degradation)
SELECT q.query_id, qt.query_sql_text,
       old_rs.avg_duration AS old_avg_duration,
       new_rs.avg_duration AS new_avg_duration,
       (new_rs.avg_duration - old_rs.avg_duration) * 100.0 / NULLIF(old_rs.avg_duration, 0) AS pct_regression
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan old_p ON q.query_id = old_p.query_id
JOIN sys.query_store_plan new_p ON q.query_id = new_p.query_id AND new_p.plan_id > old_p.plan_id
JOIN sys.query_store_runtime_stats old_rs ON old_p.plan_id = old_rs.plan_id
JOIN sys.query_store_runtime_stats new_rs ON new_p.plan_id = new_rs.plan_id
WHERE new_rs.avg_duration > old_rs.avg_duration * 2
ORDER BY (new_rs.avg_duration - old_rs.avg_duration) DESC;
```

## Step 3: Blocking Analysis

### Current Blocking

```sql
-- Active blocking chains
SELECT
    blocked.session_id AS blocked_session,
    blocked.blocking_session_id AS blocker_session,
    blocked.wait_type, blocked.wait_time / 1000 AS wait_seconds,
    blocked.wait_resource,
    DB_NAME(blocked.database_id) AS database_name,
    blocked_text.text AS blocked_query,
    blocker_text.text AS blocker_query,
    blocker.login_name AS blocker_login,
    blocker.program_name AS blocker_program
FROM sys.dm_exec_requests blocked
JOIN sys.dm_exec_sessions blocker ON blocked.blocking_session_id = blocker.session_id
CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_text
OUTER APPLY sys.dm_exec_sql_text(blocker.most_recent_sql_handle) blocker_text
WHERE blocked.blocking_session_id > 0
ORDER BY blocked.wait_time DESC;
```

### Head Blocker Analysis

```sql
-- Find the root of blocking chains (head blockers)
;WITH BlockingChain AS (
    SELECT session_id, blocking_session_id, 0 AS level
    FROM sys.dm_exec_requests WHERE blocking_session_id = 0 AND session_id IN (
        SELECT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id > 0
    )
    UNION ALL
    SELECT r.session_id, r.blocking_session_id, bc.level + 1
    FROM sys.dm_exec_requests r
    JOIN BlockingChain bc ON r.blocking_session_id = bc.session_id
)
SELECT * FROM BlockingChain ORDER BY level, session_id;
```

### Deadlock Investigation

Deadlock information is captured by:
1. **System health session** (Extended Events, always on):
```sql
SELECT XEvent.query('(event/data/value/deadlock)[1]') AS deadlock_graph
FROM (
    SELECT CAST(target_data AS XML) AS TargetData
    FROM sys.dm_xe_session_targets st
    JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
    WHERE s.name = 'system_health'
      AND st.target_name = 'ring_buffer'
) AS Data
CROSS APPLY TargetData.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData(XEvent);
```

2. **Trace flag 1222** -- Detailed deadlock information in the error log.

## Key DMVs by Category

### Execution and Performance

| DMV | Purpose |
|---|---|
| `sys.dm_exec_query_stats` | Aggregated query performance statistics |
| `sys.dm_exec_requests` | Currently executing requests |
| `sys.dm_exec_sessions` | Active sessions |
| `sys.dm_exec_cached_plans` | Plan cache contents |
| `sys.dm_exec_query_plan(handle)` | XML execution plan for a plan handle |
| `sys.dm_exec_sql_text(handle)` | SQL text for a SQL handle |
| `sys.dm_exec_procedure_stats` | Stored procedure performance stats |
| `sys.dm_exec_trigger_stats` | Trigger performance stats |

### I/O

| DMV | Purpose |
|---|---|
| `sys.dm_io_virtual_file_stats(db,file)` | File-level I/O statistics |
| `sys.dm_os_buffer_descriptors` | Buffer pool page contents |
| `sys.dm_db_index_physical_stats` | Index fragmentation |
| `sys.dm_db_index_operational_stats` | Index operational counters (row locks, page splits) |

```sql
-- I/O latency per database file
SELECT DB_NAME(vfs.database_id) AS db_name,
       mf.name AS file_name, mf.type_desc,
       vfs.num_of_reads, vfs.num_of_writes,
       vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads, 0) AS avg_read_ms,
       vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) AS avg_write_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
JOIN sys.master_files mf ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER BY vfs.io_stall DESC;
```

### Memory

| DMV | Purpose |
|---|---|
| `sys.dm_os_memory_clerks` | Memory allocation by component |
| `sys.dm_os_sys_memory` | OS-level memory information |
| `sys.dm_os_process_memory` | SQL Server process memory |
| `sys.dm_exec_query_memory_grants` | Current memory grants |
| `sys.dm_os_performance_counters` | Performance counter values |

```sql
-- Memory grants currently pending or executing
SELECT session_id, request_id, scheduler_id,
       requested_memory_kb / 1024 AS requested_mb,
       granted_memory_kb / 1024 AS granted_mb,
       required_memory_kb / 1024 AS required_mb,
       used_memory_kb / 1024 AS used_mb,
       max_used_memory_kb / 1024 AS max_used_mb,
       query_cost, is_small, ideal_memory_kb / 1024 AS ideal_mb
FROM sys.dm_exec_query_memory_grants
ORDER BY requested_memory_kb DESC;
```

### Index Usage

| DMV | Purpose |
|---|---|
| `sys.dm_db_index_usage_stats` | How indexes are used (seeks, scans, lookups, updates) |
| `sys.dm_db_missing_index_details` | Missing index suggestions |
| `sys.dm_db_missing_index_group_stats` | Impact estimate for missing indexes |

```sql
-- Missing index suggestions with estimated improvement
SELECT
    d.statement AS table_name,
    d.equality_columns, d.inequality_columns, d.included_columns,
    gs.avg_user_impact, gs.user_seeks, gs.user_scans,
    gs.avg_total_user_cost * gs.avg_user_impact * (gs.user_seeks + gs.user_scans) AS improvement_measure
FROM sys.dm_db_missing_index_details d
JOIN sys.dm_db_missing_index_groups g ON d.index_handle = g.index_handle
JOIN sys.dm_db_missing_index_group_stats gs ON g.index_group_handle = gs.group_handle
ORDER BY improvement_measure DESC;
```

### Always On AG

| DMV | Purpose |
|---|---|
| `sys.dm_hadr_database_replica_states` | Replica synchronization state |
| `sys.dm_hadr_availability_replica_states` | Replica health |
| `sys.dm_hadr_cluster_members` | Cluster node status |
| `sys.dm_hadr_auto_page_repair` | Auto page repair history |

```sql
-- AG replica sync status
SELECT
    ag.name AS ag_name,
    ar.replica_server_name,
    drs.database_name,
    drs.synchronization_state_desc,
    drs.synchronization_health_desc,
    drs.log_send_queue_size,
    drs.redo_queue_size,
    drs.last_hardened_lsn,
    drs.last_commit_time
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_replicas ar ON drs.replica_id = ar.replica_id
JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
ORDER BY ag.name, ar.replica_server_name, drs.database_name;
```

## Query Store Reference

### Enabling and Configuring

```sql
ALTER DATABASE [MyDB] SET QUERY_STORE = ON (
    OPERATION_MODE = READ_WRITE,
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES = 60,
    MAX_STORAGE_SIZE_MB = 1024,
    QUERY_CAPTURE_MODE = AUTO,       -- Ignores trivial queries
    SIZE_BASED_CLEANUP_MODE = AUTO,
    MAX_PLANS_PER_QUERY = 200,
    WAIT_STATS_CAPTURE_MODE = ON     -- 2017+
);
```

### Key Query Store Views

| View | Purpose |
|---|---|
| `sys.query_store_query` | Query metadata (query_id, context settings) |
| `sys.query_store_query_text` | Query text |
| `sys.query_store_plan` | Execution plans per query |
| `sys.query_store_runtime_stats` | Runtime performance stats per plan |
| `sys.query_store_runtime_stats_interval` | Time intervals for stats aggregation |
| `sys.query_store_wait_stats` | Wait statistics per plan (2017+) |

### Forcing and Unforcing Plans

```sql
-- Force a specific plan for a query
EXEC sp_query_store_force_plan @query_id = 42, @plan_id = 7;

-- Unforce
EXEC sp_query_store_unforce_plan @query_id = 42, @plan_id = 7;
```

### Query Store Hints (2022+)

```sql
-- Apply a hint without modifying query text
EXEC sp_query_store_set_hints @query_id = 42,
    @query_hints = N'OPTION (MAXDOP 4, RECOMPILE)';
```

## Extended Events

Extended Events (XEvents) is the lightweight, scalable event infrastructure. It replaces SQL Trace/Profiler.

### Common Sessions

```sql
-- Track long-running queries (> 5 seconds)
CREATE EVENT SESSION [LongQueries] ON SERVER
ADD EVENT sqlserver.sql_statement_completed (
    ACTION (sqlserver.sql_text, sqlserver.session_id,
            sqlserver.database_name, sqlserver.username)
    WHERE duration > 5000000  -- microseconds
)
ADD TARGET package0.event_file (SET filename = N'LongQueries.xel', max_file_size = 100)
WITH (MAX_MEMORY = 4096 KB, STARTUP_STATE = ON);

-- Track deadlocks (system_health already does this, but dedicated session is cleaner)
CREATE EVENT SESSION [Deadlocks] ON SERVER
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.event_file (SET filename = N'Deadlocks.xel', max_file_size = 50)
WITH (STARTUP_STATE = ON);
```

### Reading XEvent Files

```sql
SELECT event_data = CAST(event_data AS XML)
FROM sys.fn_xe_file_target_read_file('LongQueries*.xel', NULL, NULL, NULL);
```

## Health Check Queries

### Quick Instance Health

```sql
-- 1. SQL Server uptime
SELECT sqlserver_start_time, DATEDIFF(DAY, sqlserver_start_time, GETDATE()) AS uptime_days
FROM sys.dm_os_sys_info;

-- 2. Database status
SELECT name, state_desc, recovery_model_desc, compatibility_level
FROM sys.databases ORDER BY name;

-- 3. Last backup times
SELECT d.name, MAX(CASE WHEN b.type = 'D' THEN b.backup_finish_date END) AS last_full,
       MAX(CASE WHEN b.type = 'I' THEN b.backup_finish_date END) AS last_diff,
       MAX(CASE WHEN b.type = 'L' THEN b.backup_finish_date END) AS last_log
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b ON d.name = b.database_name
WHERE d.database_id > 4
GROUP BY d.name ORDER BY d.name;

-- 4. Error log recent errors
EXEC sp_readerrorlog 0, 1, 'Error';
```
