/******************************************************************************
* Script:   04-top-queries-io.sql
* Purpose:  Identify top I/O-consuming queries by logical and physical reads
*           from plan cache, Query Store, and currently executing requests.
* Server:   SQL Server 2017 (compatibility level 140)
* Date:     2026-04-06
*
* NEW in 2017 vs 2016:
*   - Cross-reference with sys.dm_exec_query_statistics_xml for live I/O stats
*   - Query Store wait stats can isolate I/O-related waits per query
*
* Safety:   Read-only. No modifications to server or databases.
******************************************************************************/
SET NOCOUNT ON;

-- ============================================================================
-- Section 1: Top 25 Queries by Total Logical Reads (Plan Cache)
-- ============================================================================
PRINT '=== Section 1: Top 25 Queries by Total Logical Reads (Plan Cache) ===';
PRINT '';

SELECT TOP 25
    qs.total_logical_reads                          AS [Total Logical Reads],
    qs.execution_count                              AS [Executions],
    qs.total_logical_reads / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Logical Reads],
    qs.last_logical_reads                           AS [Last Logical Reads],
    qs.min_logical_reads                            AS [Min Logical Reads],
    qs.max_logical_reads                            AS [Max Logical Reads],
    qs.total_physical_reads                         AS [Total Physical Reads],
    qs.total_physical_reads / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Physical Reads],
    qs.total_logical_writes                         AS [Total Logical Writes],
    qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS [Avg CPU Ms],
    qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS [Avg Elapsed Ms],
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
ORDER BY qs.total_logical_reads DESC;

-- ============================================================================
-- Section 2: Top 25 Queries by Average Logical Reads per Execution
-- ============================================================================
PRINT '';
PRINT '=== Section 2: Top 25 Queries by Avg Logical Reads per Execution ===';
PRINT '';

SELECT TOP 25
    qs.total_logical_reads / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Logical Reads],
    qs.execution_count                              AS [Executions],
    qs.total_logical_reads                          AS [Total Logical Reads],
    qs.total_physical_reads / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Physical Reads],
    qs.total_logical_writes / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Logical Writes],
    qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS [Avg CPU Ms],
    qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS [Avg Elapsed Ms],
    CASE
        WHEN qs.total_logical_reads / NULLIF(qs.execution_count, 0) > 100000
        THEN 'VERY HIGH -- likely table/index scan'
        WHEN qs.total_logical_reads / NULLIF(qs.execution_count, 0) > 10000
        THEN 'HIGH -- review execution plan for missing indexes'
        ELSE 'Moderate'
    END                                             AS [Assessment],
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
ORDER BY qs.total_logical_reads / NULLIF(qs.execution_count, 0) DESC;

-- ============================================================================
-- Section 3: Top 25 Queries by Physical Reads (Causing Disk I/O)
-- ============================================================================
PRINT '';
PRINT '=== Section 3: Top 25 Queries by Physical Reads ===';
PRINT '';

SELECT TOP 25
    qs.total_physical_reads                         AS [Total Physical Reads],
    qs.execution_count                              AS [Executions],
    qs.total_physical_reads / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Physical Reads],
    qs.total_logical_reads / NULLIF(qs.execution_count, 0)
                                                    AS [Avg Logical Reads],
    CASE
        WHEN qs.total_logical_reads > 0
        THEN CAST(100.0 * qs.total_physical_reads
            / qs.total_logical_reads AS DECIMAL(5,2))
        ELSE 0
    END                                             AS [Physical Read Pct],
    qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS [Avg CPU Ms],
    qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS [Avg Elapsed Ms],
    qs.last_execution_time                          AS [Last Executed],
    DB_NAME(qt.dbid)                                AS [Database],
    SUBSTRING(qt.text,
        qs.statement_start_offset / 2 + 1,
        (CASE WHEN qs.statement_end_offset = -1
              THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
              ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2 + 1) AS [Query Text]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
WHERE qs.total_physical_reads > 0
ORDER BY qs.total_physical_reads DESC;

-- ============================================================================
-- Section 4: Currently Executing Queries Sorted by Reads
-- ============================================================================
PRINT '';
PRINT '=== Section 4: Currently Executing Queries (by Reads) ===';
PRINT '';

SELECT
    er.session_id                                   AS [Session ID],
    er.status                                       AS [Status],
    er.command                                      AS [Command],
    er.logical_reads                                AS [Logical Reads],
    er.reads                                        AS [Physical Reads],
    er.writes                                       AS [Writes],
    er.cpu_time                                     AS [CPU Time Ms],
    er.total_elapsed_time                           AS [Elapsed Time Ms],
    er.wait_type                                    AS [Current Wait],
    er.wait_time                                    AS [Wait Time Ms],
    er.blocking_session_id                          AS [Blocked By],
    er.granted_query_memory * 8                     AS [Granted Memory KB],
    DB_NAME(er.database_id)                         AS [Database],
    es.login_name                                   AS [Login],
    es.host_name                                    AS [Host],
    SUBSTRING(st.text,
        er.statement_start_offset / 2 + 1,
        (CASE WHEN er.statement_end_offset = -1
              THEN LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2
              ELSE er.statement_end_offset
         END - er.statement_start_offset) / 2 + 1) AS [Current Statement],
    -- NEW in 2017: Live query stats for I/O analysis
    qsx.query_plan                                  AS [Live Query Plan with I/O Stats]
FROM sys.dm_exec_requests er
JOIN sys.dm_exec_sessions es ON er.session_id = es.session_id
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) st
OUTER APPLY sys.dm_exec_query_statistics_xml(er.session_id) qsx
WHERE er.session_id > 50
  AND er.session_id <> @@SPID
ORDER BY er.logical_reads DESC;

-- ============================================================================
-- Section 5: Top I/O Queries from Query Store (Last 24 Hours)
-- ============================================================================
PRINT '';
PRINT '=== Section 5: Top I/O Queries from Query Store (Last 24 Hours) ===';
PRINT '';

DECLARE @qs_io_sql NVARCHAR(MAX) = N'';

SELECT @qs_io_sql = @qs_io_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        SELECT TOP 25
            DB_NAME()                               AS [Database],
            q.query_id                              AS [Query ID],
            p.plan_id                               AS [Plan ID],
            rs.count_executions                     AS [Executions],
            rs.avg_logical_io_reads                 AS [Avg Logical Reads],
            rs.last_logical_io_reads                AS [Last Logical Reads],
            rs.min_logical_io_reads                 AS [Min Logical Reads],
            rs.max_logical_io_reads                 AS [Max Logical Reads],
            rs.avg_physical_io_reads                AS [Avg Physical Reads],
            rs.avg_logical_io_writes                AS [Avg Logical Writes],
            CAST(rs.avg_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [Avg CPU Ms],
            CAST(rs.avg_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Avg Duration Ms],
            p.is_forced_plan                        AS [Plan Forced],
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
        ORDER BY rs.avg_logical_io_reads * rs.count_executions DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @qs_io_sql <> N''
    EXEC sp_executesql @qs_io_sql;
ELSE
    PRINT 'No user databases have Query Store enabled.';

-- ============================================================================
-- Section 6: Queries with I/O Waits in Query Store (NEW in 2017)
-- ============================================================================
PRINT '';
PRINT '=== Section 6: Queries with I/O Waits in Query Store (NEW in 2017) ===';
PRINT '';

DECLARE @qs_io_wait_sql NVARCHAR(MAX) = N'';

SELECT @qs_io_wait_sql = @qs_io_wait_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        ;WITH IOWaitQueries AS (
            SELECT
                q.query_id,
                ws.wait_category_desc,
                SUM(ws.total_query_wait_time_ms)    AS total_io_wait_ms,
                AVG(ws.avg_query_wait_time_ms)      AS avg_io_wait_ms,
                MAX(ws.max_query_wait_time_ms)      AS max_io_wait_ms
            FROM sys.query_store_wait_stats ws
            JOIN sys.query_store_runtime_stats_interval rsi
                ON ws.runtime_stats_interval_id = rsi.runtime_stats_interval_id
            JOIN sys.query_store_plan p
                ON ws.plan_id = p.plan_id
            JOIN sys.query_store_query q
                ON p.query_id = q.query_id
            WHERE rsi.start_time >= DATEADD(HOUR, -24, GETUTCDATE())
              AND ws.wait_category_desc IN (
                  ''Buffer IO'', ''Buffer Latch'', ''Log IO'',
                  ''Other Disk IO'', ''Tran Log IO''
              )
            GROUP BY q.query_id, ws.wait_category_desc
        )
        SELECT TOP 20
            DB_NAME()                               AS [Database],
            iow.query_id                            AS [Query ID],
            iow.wait_category_desc                  AS [I/O Wait Category],
            iow.total_io_wait_ms                    AS [Total I/O Wait Ms],
            iow.avg_io_wait_ms                      AS [Avg I/O Wait Ms],
            iow.max_io_wait_ms                      AS [Max I/O Wait Ms],
            SUBSTRING(qt.query_sql_text, 1, 200)    AS [Query Text (First 200 chars)]
        FROM IOWaitQueries iow
        JOIN sys.query_store_query q
            ON iow.query_id = q.query_id
        JOIN sys.query_store_query_text qt
            ON q.query_text_id = qt.query_text_id
        ORDER BY iow.total_io_wait_ms DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @qs_io_wait_sql <> N''
    EXEC sp_executesql @qs_io_wait_sql;
ELSE
    PRINT 'No user databases have Query Store enabled.';

-- ============================================================================
-- Section 7: Top Stored Procedures by Reads
-- ============================================================================
PRINT '';
PRINT '=== Section 7: Top 25 Stored Procedures by Logical Reads ===';
PRINT '';

SELECT TOP 25
    DB_NAME(ps.database_id)                         AS [Database],
    OBJECT_NAME(ps.object_id, ps.database_id)       AS [Procedure Name],
    ps.execution_count                              AS [Executions],
    ps.total_logical_reads                          AS [Total Logical Reads],
    ps.total_logical_reads / NULLIF(ps.execution_count, 0)
                                                    AS [Avg Logical Reads],
    ps.total_physical_reads                         AS [Total Physical Reads],
    ps.total_physical_reads / NULLIF(ps.execution_count, 0)
                                                    AS [Avg Physical Reads],
    ps.total_logical_writes                         AS [Total Logical Writes],
    ps.total_worker_time / NULLIF(ps.execution_count, 0) / 1000
                                                    AS [Avg CPU Ms],
    ps.cached_time                                  AS [Plan Cached],
    ps.last_execution_time                          AS [Last Executed]
FROM sys.dm_exec_procedure_stats ps
WHERE ps.database_id > 4
ORDER BY ps.total_logical_reads DESC;

PRINT '';
PRINT '=== Top I/O Queries Analysis Complete ===';
