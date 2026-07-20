/******************************************************************************
* Script:   03-top-queries-cpu.sql
* Purpose:  Identify top CPU-consuming queries from plan cache, Query Store,
*           and currently executing requests. Includes live query stats via
*           sys.dm_exec_query_statistics_xml (NEW in 2017).
* Server:   SQL Server 2017 (compatibility level 140)
* Date:     2026-04-06
*
* NEW in 2017 vs 2016:
*   - sys.dm_exec_query_statistics_xml: live per-operator execution stats
*     for currently running queries without needing SET STATISTICS XML ON
*   - Cross-reference running queries with their live execution statistics
*   - Adaptive query processing hints visible in plans (compat 140)
*
* Safety:   Read-only. No modifications to server or databases.
******************************************************************************/
SET NOCOUNT ON;

-- ============================================================================
-- Section 1: Top 25 CPU Queries from Plan Cache (Cumulative)
-- ============================================================================
PRINT '=== Section 1: Top 25 CPU Queries (Plan Cache - Total CPU) ===';
PRINT '';

SELECT TOP 25
    qs.total_worker_time / 1000                     AS [Total CPU Ms],
    qs.execution_count                              AS [Executions],
    qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS [Avg CPU Ms],
    qs.last_worker_time / 1000                      AS [Last CPU Ms],
    qs.min_worker_time / 1000                       AS [Min CPU Ms],
    qs.max_worker_time / 1000                       AS [Max CPU Ms],
    qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS [Avg Elapsed Ms],
    qs.total_logical_reads / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Logical Reads],
    qs.total_logical_writes / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Logical Writes],
    qs.total_grant_kb / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Grant KB],
    qs.creation_time                                AS [Plan Created],
    qs.last_execution_time                          AS [Last Executed],
    DB_NAME(qt.dbid)                                AS [Database],
    OBJECT_NAME(qt.objectid, qt.dbid)               AS [Object Name],
    SUBSTRING(qt.text,
        qs.statement_start_offset / 2 + 1,
        (CASE WHEN qs.statement_end_offset = -1
              THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
              ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2 + 1) AS [Query Text],
    qp.query_plan                                   AS [Execution Plan]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.total_worker_time DESC;

-- ============================================================================
-- Section 2: Top 25 CPU Queries by Average CPU (High Per-Execution Cost)
-- ============================================================================
PRINT '';
PRINT '=== Section 2: Top 25 CPU Queries (Plan Cache - Avg CPU per Execution) ===';
PRINT '';

SELECT TOP 25
    qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS [Avg CPU Ms],
    qs.execution_count                              AS [Executions],
    qs.total_worker_time / 1000                     AS [Total CPU Ms],
    qs.max_worker_time / 1000                       AS [Max CPU Ms],
    qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS [Avg Elapsed Ms],
    qs.total_logical_reads / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Logical Reads],
    qs.total_grant_kb / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Grant KB],
    qs.last_execution_time                          AS [Last Executed],
    DB_NAME(qt.dbid)                                AS [Database],
    OBJECT_NAME(qt.objectid, qt.dbid)               AS [Object Name],
    SUBSTRING(qt.text,
        qs.statement_start_offset / 2 + 1,
        (CASE WHEN qs.statement_end_offset = -1
              THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
              ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2 + 1) AS [Query Text],
    qp.query_plan                                   AS [Execution Plan]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE qs.execution_count >= 5  -- Filter out one-off queries
ORDER BY qs.total_worker_time / NULLIF(qs.execution_count, 0) DESC;

-- ============================================================================
-- Section 3: Currently Executing Queries by CPU
-- ============================================================================
PRINT '';
PRINT '=== Section 3: Currently Executing Queries (by CPU) ===';
PRINT '';

SELECT
    er.session_id                                   AS [Session ID],
    er.status                                       AS [Status],
    er.command                                      AS [Command],
    er.cpu_time                                     AS [CPU Time Ms],
    er.total_elapsed_time                           AS [Elapsed Time Ms],
    er.reads                                        AS [Reads],
    er.writes                                       AS [Writes],
    er.logical_reads                                AS [Logical Reads],
    er.wait_type                                    AS [Current Wait],
    er.wait_time                                    AS [Wait Time Ms],
    er.blocking_session_id                          AS [Blocked By],
    er.percent_complete                             AS [Pct Complete],
    er.granted_query_memory * 8                     AS [Granted Memory KB],
    DB_NAME(er.database_id)                         AS [Database],
    es.login_name                                   AS [Login],
    es.host_name                                    AS [Host],
    es.program_name                                 AS [Application],
    SUBSTRING(st.text,
        er.statement_start_offset / 2 + 1,
        (CASE WHEN er.statement_end_offset = -1
              THEN LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2
              ELSE er.statement_end_offset
         END - er.statement_start_offset) / 2 + 1) AS [Current Statement],
    qp.query_plan                                   AS [Execution Plan]
FROM sys.dm_exec_requests er
JOIN sys.dm_exec_sessions es ON er.session_id = es.session_id
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) st
OUTER APPLY sys.dm_exec_query_plan(er.plan_handle) qp
WHERE er.session_id > 50  -- Exclude system sessions
  AND er.session_id <> @@SPID  -- Exclude this session
ORDER BY er.cpu_time DESC;

-- ============================================================================
-- Section 4: Live Query Statistics XML (NEW in 2017)
-- sys.dm_exec_query_statistics_xml returns live per-operator execution
-- statistics for currently running queries. This is the DMV backing the
-- "Live Query Statistics" feature in SSMS, now accessible via T-SQL.
-- ============================================================================
PRINT '';
PRINT '=== Section 4: Live Query Statistics XML (NEW in 2017) ===';
PRINT '';
PRINT 'NOTE: sys.dm_exec_query_statistics_xml provides real-time per-operator';
PRINT 'stats for running queries. Requires SET STATISTICS XML ON or the';
PRINT 'lightweight profiling infrastructure (on by default in 2017 CU3+).';
PRINT '';

SELECT
    er.session_id                                   AS [Session ID],
    er.status                                       AS [Status],
    er.cpu_time                                     AS [CPU Time Ms],
    er.total_elapsed_time                           AS [Elapsed Time Ms],
    er.logical_reads                                AS [Logical Reads],
    DB_NAME(er.database_id)                         AS [Database],
    SUBSTRING(st.text,
        er.statement_start_offset / 2 + 1,
        (CASE WHEN er.statement_end_offset = -1
              THEN LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2
              ELSE er.statement_end_offset
         END - er.statement_start_offset) / 2 + 1) AS [Current Statement],
    -- NEW in 2017: Live query statistics XML
    qsx.query_plan                                  AS [Live Query Plan with Stats]
FROM sys.dm_exec_requests er
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) st
OUTER APPLY sys.dm_exec_query_statistics_xml(er.session_id) qsx
WHERE er.session_id > 50
  AND er.session_id <> @@SPID
  AND er.status = 'running'
ORDER BY er.cpu_time DESC;

-- ============================================================================
-- Section 5: Top CPU Queries from Query Store (Last 24 Hours)
-- ============================================================================
PRINT '';
PRINT '=== Section 5: Top CPU Queries from Query Store (Last 24 Hours) ===';
PRINT '';

DECLARE @qs_cpu_sql NVARCHAR(MAX) = N'';

SELECT @qs_cpu_sql = @qs_cpu_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        SELECT TOP 25
            DB_NAME()                               AS [Database],
            q.query_id                              AS [Query ID],
            p.plan_id                               AS [Plan ID],
            rs.count_executions                     AS [Executions],
            CAST(rs.avg_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [Avg CPU Ms],
            CAST(rs.last_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [Last CPU Ms],
            CAST(rs.min_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [Min CPU Ms],
            CAST(rs.max_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [Max CPU Ms],
            CAST(rs.avg_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Avg Duration Ms],
            rs.avg_logical_io_reads                 AS [Avg Logical Reads],
            rs.avg_query_max_used_memory             AS [Avg Memory Grant Pages],
            p.is_forced_plan                        AS [Plan Forced],
            p.force_failure_count                   AS [Force Failures],
            q.query_parameterization_type_desc      AS [Parameterization],
            SUBSTRING(qt.query_sql_text, 1, 300)    AS [Query Text (First 300 chars)]
        FROM sys.query_store_runtime_stats rs
        JOIN sys.query_store_runtime_stats_interval rsi
            ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
        JOIN sys.query_store_plan p
            ON rs.plan_id = p.plan_id
        JOIN sys.query_store_query q
            ON p.query_id = q.query_id
        JOIN sys.query_store_query_text qt
            ON q.query_text_id = qt.query_text_id
        WHERE rsi.start_time >= DATEADD(HOUR, -24, GETUTCDATE())
        ORDER BY rs.avg_cpu_time * rs.count_executions DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @qs_cpu_sql <> N''
    EXEC sp_executesql @qs_cpu_sql;
ELSE
    PRINT 'No user databases have Query Store enabled.';

-- ============================================================================
-- Section 6: Top Stored Procedures by CPU
-- ============================================================================
PRINT '';
PRINT '=== Section 6: Top 25 Stored Procedures by CPU ===';
PRINT '';

SELECT TOP 25
    DB_NAME(ps.database_id)                         AS [Database],
    OBJECT_NAME(ps.object_id, ps.database_id)       AS [Procedure Name],
    ps.execution_count                              AS [Executions],
    ps.total_worker_time / 1000                     AS [Total CPU Ms],
    ps.total_worker_time / NULLIF(ps.execution_count, 0) / 1000
                                                    AS [Avg CPU Ms],
    ps.max_worker_time / 1000                       AS [Max CPU Ms],
    ps.total_elapsed_time / NULLIF(ps.execution_count, 0) / 1000
                                                    AS [Avg Elapsed Ms],
    ps.total_logical_reads / NULLIF(ps.execution_count, 0)
                                                    AS [Avg Logical Reads],
    ps.cached_time                                  AS [Plan Cached],
    ps.last_execution_time                          AS [Last Executed]
FROM sys.dm_exec_procedure_stats ps
WHERE ps.database_id > 4
ORDER BY ps.total_worker_time DESC;

-- ============================================================================
-- Section 7: CPU-Intensive Queries with Adaptive QP Indicators (2017)
-- ============================================================================
PRINT '';
PRINT '=== Section 7: Queries Using Adaptive Query Processing (2017 feature) ===';
PRINT '';
PRINT 'NOTE: At compat level 140, batch mode adaptive joins, interleaved execution,';
PRINT 'and batch mode memory grant feedback are active. Look for these operators';
PRINT 'in the execution plans above.';
PRINT '';

-- Identify queries that may benefit from or are using adaptive QP
-- by checking for memory grant feedback adjustments
SELECT
    mg.session_id                                   AS [Session ID],
    mg.requested_memory_kb / 1024                   AS [Requested Memory MB],
    mg.granted_memory_kb / 1024                     AS [Granted Memory MB],
    mg.used_memory_kb / 1024                        AS [Used Memory MB],
    mg.max_used_memory_kb / 1024                    AS [Max Used Memory MB],
    mg.ideal_memory_kb / 1024                       AS [Ideal Memory MB],
    CASE
        WHEN mg.granted_memory_kb > 0
         AND mg.max_used_memory_kb * 1.0 / mg.granted_memory_kb < 0.1
        THEN 'OVER-GRANTED -- Memory grant feedback may reduce this'
        WHEN mg.granted_memory_kb < mg.ideal_memory_kb
        THEN 'UNDER-GRANTED -- Potential spill to tempdb'
        ELSE 'Reasonable'
    END                                             AS [Memory Grant Assessment],
    mg.query_cost                                   AS [Query Cost],
    st.text                                         AS [Query Text]
FROM sys.dm_exec_query_memory_grants mg
CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) st
WHERE mg.session_id > 50
ORDER BY mg.granted_memory_kb DESC;

PRINT '';
PRINT '=== Top CPU Queries Analysis Complete ===';
