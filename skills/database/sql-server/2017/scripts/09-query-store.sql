/******************************************************************************
* Script:   09-query-store.sql
* Purpose:  Comprehensive Query Store diagnostics for SQL Server 2017. Includes
*           configuration review, top queries, plan regressions, forced plans,
*           and the major 2017 addition: WAIT STATS analysis per query.
* Server:   SQL Server 2017 (compatibility level 140)
* Date:     2026-04-06
*
* NEW in 2017 vs 2016:
*   - sys.query_store_wait_stats: per-query wait statistics (the big addition)
*   - WAIT_STATS_CAPTURE_MODE configuration option
*   - Enables correlating waits directly to specific queries and plans
*   - Top wait categories per query, regressed queries by wait changes
*
* Safety:   Read-only. No modifications to server or databases.
******************************************************************************/
SET NOCOUNT ON;

-- ============================================================================
-- Section 1: Query Store Configuration per Database
-- ============================================================================
PRINT '=== Section 1: Query Store Configuration ===';
PRINT '';

SELECT
    DB_NAME(d.database_id)                          AS [Database],
    d.is_query_store_on                             AS [Query Store On],
    qso.actual_state_desc                           AS [Actual State],
    qso.desired_state_desc                          AS [Desired State],
    qso.readonly_reason                             AS [Read-Only Reason],
    qso.current_storage_size_mb                     AS [Current Size MB],
    qso.max_storage_size_mb                         AS [Max Size MB],
    CAST(100.0 * qso.current_storage_size_mb
        / NULLIF(qso.max_storage_size_mb, 0)
        AS DECIMAL(5,2))                            AS [Size Used Pct],
    qso.query_capture_mode_desc                     AS [Capture Mode],
    qso.size_based_cleanup_mode_desc                AS [Cleanup Mode],
    qso.stale_query_threshold_days                  AS [Stale Threshold Days],
    qso.interval_length_minutes                     AS [Stats Interval Min],
    qso.flush_interval_seconds                      AS [Flush Interval Sec],
    qso.max_plans_per_query                         AS [Max Plans per Query],
    -- NEW in 2017
    qso.wait_stats_capture_mode_desc                AS [Wait Stats Capture (2017)],
    -- Health checks
    CASE
        WHEN qso.actual_state_desc = 'READ_ONLY'
        THEN 'WARNING -- Query Store is read-only. Check readonly_reason.'
        WHEN qso.actual_state_desc = 'OFF'
        THEN 'DISABLED -- Enable Query Store for query performance tracking.'
        WHEN qso.current_storage_size_mb * 100
            / NULLIF(qso.max_storage_size_mb, 0) > 80
        THEN 'WARNING -- Query Store > 80% full. May switch to read-only.'
        ELSE 'OK'
    END                                             AS [Health Status]
FROM sys.databases d
CROSS APPLY (
    SELECT *
    FROM sys.database_query_store_options
) qso
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

-- Recommended settings for 2017
PRINT '';
PRINT '--- Recommended Query Store Settings for SQL Server 2017 ---';
PRINT 'OPERATION_MODE         = READ_WRITE';
PRINT 'QUERY_CAPTURE_MODE     = AUTO (skip trivial queries)';
PRINT 'MAX_STORAGE_SIZE_MB    = 1024-2048 (depending on workload)';
PRINT 'INTERVAL_LENGTH_MINUTES = 60 (1 hour; lower for short-term troubleshooting)';
PRINT 'SIZE_BASED_CLEANUP_MODE = AUTO';
PRINT 'MAX_PLANS_PER_QUERY    = 200 (default)';
PRINT 'WAIT_STATS_CAPTURE_MODE = ON   (NEW in 2017 -- highly recommended)';
PRINT 'STALE_QUERY_THRESHOLD_DAYS = 30';
PRINT '';

-- ============================================================================
-- Section 2: Top Queries by Duration (Last 24 Hours)
-- ============================================================================
PRINT '=== Section 2: Top Queries by Duration (Last 24 Hours) ===';
PRINT '';

DECLARE @top_duration_sql NVARCHAR(MAX) = N'';

SELECT @top_duration_sql = @top_duration_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        SELECT TOP 25
            DB_NAME()                               AS [Database],
            q.query_id                              AS [Query ID],
            p.plan_id                               AS [Plan ID],
            rs.count_executions                     AS [Executions],
            CAST(rs.avg_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Avg Duration Ms],
            CAST(rs.last_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Last Duration Ms],
            CAST(rs.min_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Min Duration Ms],
            CAST(rs.max_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Max Duration Ms],
            CAST(rs.stdev_duration / 1000.0
                AS DECIMAL(18,2))                   AS [StdDev Duration Ms],
            CAST(rs.avg_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [Avg CPU Ms],
            rs.avg_logical_io_reads                 AS [Avg Logical Reads],
            rs.avg_physical_io_reads                AS [Avg Physical Reads],
            rs.avg_query_max_used_memory             AS [Avg Memory Grant Pages],
            p.is_forced_plan                        AS [Plan Forced],
            p.count_compiles                        AS [Compiles],
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
        ORDER BY rs.avg_duration DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @top_duration_sql <> N''
    EXEC sp_executesql @top_duration_sql;
ELSE
    PRINT 'No user databases have Query Store enabled.';

-- ============================================================================
-- Section 3: Regressed Queries (Plan Changes Causing Slowdowns)
-- ============================================================================
PRINT '';
PRINT '=== Section 3: Regressed Queries (Plan Changes) ===';
PRINT '';

DECLARE @regressed_sql NVARCHAR(MAX) = N'';

SELECT @regressed_sql = @regressed_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        ;WITH PlanPerformance AS (
            SELECT
                p.query_id,
                p.plan_id,
                p.last_compile_start_time,
                rs.avg_duration,
                rs.avg_cpu_time,
                rs.avg_logical_io_reads,
                rs.count_executions,
                ROW_NUMBER() OVER (
                    PARTITION BY p.query_id
                    ORDER BY p.last_compile_start_time DESC
                ) AS plan_recency
            FROM sys.query_store_plan p
            JOIN sys.query_store_runtime_stats rs
                ON p.plan_id = rs.plan_id
            JOIN sys.query_store_runtime_stats_interval rsi
                ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
            WHERE rsi.start_time >= DATEADD(DAY, -7, GETUTCDATE())
              AND rs.count_executions >= 2
        )
        SELECT TOP 25
            DB_NAME()                               AS [Database],
            cur.query_id                            AS [Query ID],
            prev.plan_id                            AS [Old Plan ID],
            cur.plan_id                             AS [New Plan ID],
            CAST(prev.avg_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Old Avg Duration Ms],
            CAST(cur.avg_duration / 1000.0
                AS DECIMAL(18,2))                   AS [New Avg Duration Ms],
            CAST((cur.avg_duration - prev.avg_duration) * 100.0
                / NULLIF(prev.avg_duration, 0)
                AS DECIMAL(10,2))                   AS [Duration Regression Pct],
            CAST(prev.avg_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [Old Avg CPU Ms],
            CAST(cur.avg_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [New Avg CPU Ms],
            cur.count_executions                    AS [New Plan Executions],
            SUBSTRING(qt.query_sql_text, 1, 300)    AS [Query Text]
        FROM PlanPerformance cur
        JOIN PlanPerformance prev
            ON cur.query_id = prev.query_id
           AND cur.plan_recency = 1
           AND prev.plan_recency = 2
        JOIN sys.query_store_query q
            ON cur.query_id = q.query_id
        JOIN sys.query_store_query_text qt
            ON q.query_text_id = qt.query_text_id
        WHERE cur.avg_duration > prev.avg_duration * 1.5  -- 50% or more regression
          AND cur.count_executions >= 5
        ORDER BY (cur.avg_duration - prev.avg_duration) DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @regressed_sql <> N''
    EXEC sp_executesql @regressed_sql;
ELSE
    PRINT 'No user databases have Query Store enabled.';

-- ============================================================================
-- Section 4: Query Store Wait Stats Analysis (NEW in 2017 -- Major Feature)
-- ============================================================================
PRINT '';
PRINT '=== Section 4: Query Store Wait Stats (NEW in 2017) ===';
PRINT '';
PRINT 'sys.query_store_wait_stats provides per-query wait statistics.';
PRINT 'This is the biggest Query Store enhancement in SQL Server 2017.';
PRINT '';

-- 4a: Top wait categories across all queries (last 24 hours)
PRINT '--- 4a: Top Wait Categories (Last 24 Hours) ---';
PRINT '';

DECLARE @qs_wait_cat_sql NVARCHAR(MAX) = N'';

SELECT @qs_wait_cat_sql = @qs_wait_cat_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options
               WHERE actual_state = 1 AND wait_stats_capture_mode = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        SELECT
            DB_NAME()                               AS [Database],
            ws.wait_category_desc                   AS [Wait Category],
            COUNT(DISTINCT p.query_id)              AS [Affected Queries],
            SUM(ws.total_query_wait_time_ms)        AS [Total Wait Time Ms],
            AVG(ws.avg_query_wait_time_ms)          AS [Avg Wait Time Ms],
            MAX(ws.max_query_wait_time_ms)          AS [Max Wait Time Ms],
            CAST(100.0 * SUM(ws.total_query_wait_time_ms)
                / NULLIF(SUM(SUM(ws.total_query_wait_time_ms)) OVER (), 0)
                AS DECIMAL(5,2))                    AS [Pct of Total Waits]
        FROM sys.query_store_wait_stats ws
        JOIN sys.query_store_runtime_stats_interval rsi
            ON ws.runtime_stats_interval_id = rsi.runtime_stats_interval_id
        JOIN sys.query_store_plan p
            ON ws.plan_id = p.plan_id
        WHERE rsi.start_time >= DATEADD(HOUR, -24, GETUTCDATE())
        GROUP BY ws.wait_category_desc
        ORDER BY SUM(ws.total_query_wait_time_ms) DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @qs_wait_cat_sql <> N''
    EXEC sp_executesql @qs_wait_cat_sql;
ELSE
    PRINT 'No user databases have Query Store enabled with wait stats capture.';

-- 4b: Top queries by wait time, with their primary wait category
PRINT '';
PRINT '--- 4b: Top Queries by Wait Time with Primary Wait Category ---';
PRINT '';

DECLARE @qs_top_wait_sql NVARCHAR(MAX) = N'';

SELECT @qs_top_wait_sql = @qs_top_wait_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options
               WHERE actual_state = 1 AND wait_stats_capture_mode = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        ;WITH QueryWaits AS (
            SELECT
                p.query_id,
                ws.wait_category_desc,
                SUM(ws.total_query_wait_time_ms)    AS total_wait_ms,
                AVG(ws.avg_query_wait_time_ms)      AS avg_wait_ms,
                ROW_NUMBER() OVER (
                    PARTITION BY p.query_id
                    ORDER BY SUM(ws.total_query_wait_time_ms) DESC
                ) AS wait_rank
            FROM sys.query_store_wait_stats ws
            JOIN sys.query_store_runtime_stats_interval rsi
                ON ws.runtime_stats_interval_id = rsi.runtime_stats_interval_id
            JOIN sys.query_store_plan p
                ON ws.plan_id = p.plan_id
            WHERE rsi.start_time >= DATEADD(HOUR, -24, GETUTCDATE())
            GROUP BY p.query_id, ws.wait_category_desc
        )
        SELECT TOP 25
            DB_NAME()                               AS [Database],
            qw.query_id                             AS [Query ID],
            qw.wait_category_desc                   AS [Top Wait Category],
            qw.total_wait_ms                        AS [Total Wait Ms],
            qw.avg_wait_ms                          AS [Avg Wait Ms],
            rs.count_executions                     AS [Executions],
            CAST(rs.avg_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Avg Duration Ms],
            CAST(rs.avg_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [Avg CPU Ms],
            rs.avg_logical_io_reads                 AS [Avg Logical Reads],
            SUBSTRING(qt.query_sql_text, 1, 250)    AS [Query Text]
        FROM QueryWaits qw
        JOIN sys.query_store_query q
            ON qw.query_id = q.query_id
        JOIN sys.query_store_query_text qt
            ON q.query_text_id = qt.query_text_id
        JOIN sys.query_store_plan p
            ON q.query_id = p.query_id AND p.is_forced_plan = 0
        JOIN sys.query_store_runtime_stats rs
            ON p.plan_id = rs.plan_id
        JOIN sys.query_store_runtime_stats_interval rsi
            ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
        WHERE qw.wait_rank = 1  -- Only show the #1 wait category per query
          AND rsi.start_time >= DATEADD(HOUR, -24, GETUTCDATE())
        ORDER BY qw.total_wait_ms DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @qs_top_wait_sql <> N''
    EXEC sp_executesql @qs_top_wait_sql;

-- 4c: Queries with regressed waits (wait pattern changed)
PRINT '';
PRINT '--- 4c: Queries with Regressed Wait Patterns ---';
PRINT '';

DECLARE @qs_regressed_wait_sql NVARCHAR(MAX) = N'';

SELECT @qs_regressed_wait_sql = @qs_regressed_wait_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options
               WHERE actual_state = 1 AND wait_stats_capture_mode = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        ;WITH RecentWaits AS (
            SELECT
                p.query_id,
                ws.wait_category_desc,
                SUM(ws.total_query_wait_time_ms)    AS total_wait_ms,
                AVG(ws.avg_query_wait_time_ms)      AS avg_wait_ms
            FROM sys.query_store_wait_stats ws
            JOIN sys.query_store_runtime_stats_interval rsi
                ON ws.runtime_stats_interval_id = rsi.runtime_stats_interval_id
            JOIN sys.query_store_plan p
                ON ws.plan_id = p.plan_id
            WHERE rsi.start_time >= DATEADD(HOUR, -24, GETUTCDATE())
            GROUP BY p.query_id, ws.wait_category_desc
        ),
        OlderWaits AS (
            SELECT
                p.query_id,
                ws.wait_category_desc,
                SUM(ws.total_query_wait_time_ms)    AS total_wait_ms,
                AVG(ws.avg_query_wait_time_ms)      AS avg_wait_ms
            FROM sys.query_store_wait_stats ws
            JOIN sys.query_store_runtime_stats_interval rsi
                ON ws.runtime_stats_interval_id = rsi.runtime_stats_interval_id
            JOIN sys.query_store_plan p
                ON ws.plan_id = p.plan_id
            WHERE rsi.start_time >= DATEADD(DAY, -7, GETUTCDATE())
              AND rsi.start_time < DATEADD(HOUR, -24, GETUTCDATE())
            GROUP BY p.query_id, ws.wait_category_desc
        )
        SELECT TOP 20
            DB_NAME()                               AS [Database],
            rw.query_id                             AS [Query ID],
            rw.wait_category_desc                   AS [Wait Category],
            ow.avg_wait_ms                          AS [Older Avg Wait Ms],
            rw.avg_wait_ms                          AS [Recent Avg Wait Ms],
            CAST((rw.avg_wait_ms - ow.avg_wait_ms) * 100.0
                / NULLIF(ow.avg_wait_ms, 0)
                AS DECIMAL(10,2))                   AS [Wait Regression Pct],
            SUBSTRING(qt.query_sql_text, 1, 200)    AS [Query Text]
        FROM RecentWaits rw
        JOIN OlderWaits ow
            ON rw.query_id = ow.query_id
           AND rw.wait_category_desc = ow.wait_category_desc
        JOIN sys.query_store_query q
            ON rw.query_id = q.query_id
        JOIN sys.query_store_query_text qt
            ON q.query_text_id = qt.query_text_id
        WHERE rw.avg_wait_ms > ow.avg_wait_ms * 1.5  -- 50% increase
          AND ow.avg_wait_ms > 10  -- Ignore trivial waits
        ORDER BY (rw.avg_wait_ms - ow.avg_wait_ms) DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @qs_regressed_wait_sql <> N''
    EXEC sp_executesql @qs_regressed_wait_sql;

-- ============================================================================
-- Section 5: Forced Plans Status
-- ============================================================================
PRINT '';
PRINT '=== Section 5: Forced Plans ===';
PRINT '';

DECLARE @forced_sql NVARCHAR(MAX) = N'';

SELECT @forced_sql = @forced_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        SELECT
            DB_NAME()                               AS [Database],
            q.query_id                              AS [Query ID],
            p.plan_id                               AS [Plan ID],
            p.force_failure_count                   AS [Force Failures],
            p.last_force_failure_reason_desc        AS [Last Failure Reason],
            p.last_compile_start_time               AS [Last Compiled],
            rs.count_executions                     AS [Executions],
            CAST(rs.avg_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Avg Duration Ms],
            CAST(rs.avg_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [Avg CPU Ms],
            CASE
                WHEN p.force_failure_count > 0
                THEN 'WARNING -- Plan forcing has failures. Review and unforce if needed.'
                ELSE 'OK'
            END                                     AS [Status],
            SUBSTRING(qt.query_sql_text, 1, 200)    AS [Query Text]
        FROM sys.query_store_plan p
        JOIN sys.query_store_query q
            ON p.query_id = q.query_id
        JOIN sys.query_store_query_text qt
            ON q.query_text_id = qt.query_text_id
        LEFT JOIN sys.query_store_runtime_stats rs
            ON p.plan_id = rs.plan_id
        WHERE p.is_forced_plan = 1
        ORDER BY p.force_failure_count DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @forced_sql <> N''
    EXEC sp_executesql @forced_sql;
ELSE
    PRINT 'No user databases have Query Store enabled.';

-- ============================================================================
-- Section 6: Queries with Multiple Plans (Plan Instability)
-- ============================================================================
PRINT '';
PRINT '=== Section 6: Queries with Multiple Plans (Potential Plan Instability) ===';
PRINT '';

DECLARE @multi_plan_sql NVARCHAR(MAX) = N'';

SELECT @multi_plan_sql = @multi_plan_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        SELECT TOP 20
            DB_NAME()                               AS [Database],
            q.query_id                              AS [Query ID],
            COUNT(DISTINCT p.plan_id)               AS [Plan Count],
            MIN(CAST(rs.avg_duration / 1000.0
                AS DECIMAL(18,2)))                  AS [Best Avg Duration Ms],
            MAX(CAST(rs.avg_duration / 1000.0
                AS DECIMAL(18,2)))                  AS [Worst Avg Duration Ms],
            SUM(rs.count_executions)                AS [Total Executions],
            q.query_parameterization_type_desc      AS [Parameterization],
            SUBSTRING(qt.query_sql_text, 1, 200)    AS [Query Text]
        FROM sys.query_store_plan p
        JOIN sys.query_store_query q
            ON p.query_id = q.query_id
        JOIN sys.query_store_query_text qt
            ON q.query_text_id = qt.query_text_id
        JOIN sys.query_store_runtime_stats rs
            ON p.plan_id = rs.plan_id
        GROUP BY q.query_id, q.query_parameterization_type_desc,
                 qt.query_sql_text
        HAVING COUNT(DISTINCT p.plan_id) > 1
        ORDER BY COUNT(DISTINCT p.plan_id) DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @multi_plan_sql <> N''
    EXEC sp_executesql @multi_plan_sql;

-- ============================================================================
-- Section 7: High-Variation Queries (Inconsistent Performance)
-- ============================================================================
PRINT '';
PRINT '=== Section 7: High-Variation Queries ===';
PRINT '';

DECLARE @variation_sql NVARCHAR(MAX) = N'';

SELECT @variation_sql = @variation_sql +
    N'USE ' + QUOTENAME(d.name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + d.name + N' ---'';

        SELECT TOP 20
            DB_NAME()                               AS [Database],
            q.query_id                              AS [Query ID],
            rs.count_executions                     AS [Executions],
            CAST(rs.avg_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Avg Duration Ms],
            CAST(rs.stdev_duration / 1000.0
                AS DECIMAL(18,2))                   AS [StdDev Duration Ms],
            CAST(rs.min_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Min Duration Ms],
            CAST(rs.max_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Max Duration Ms],
            CASE
                WHEN rs.avg_duration > 0
                THEN CAST(rs.stdev_duration * 100.0
                    / rs.avg_duration AS DECIMAL(10,2))
                ELSE 0
            END                                     AS [Coefficient of Variation Pct],
            SUBSTRING(qt.query_sql_text, 1, 200)    AS [Query Text]
        FROM sys.query_store_runtime_stats rs
        JOIN sys.query_store_runtime_stats_interval rsi
            ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
        JOIN sys.query_store_plan p
            ON rs.plan_id = p.plan_id
        JOIN sys.query_store_query q
            ON p.query_id = q.query_id
        JOIN sys.query_store_query_text qt
            ON q.query_text_id = qt.query_text_id
        WHERE rsi.start_time >= DATEADD(DAY, -1, GETUTCDATE())
          AND rs.count_executions >= 10
          AND rs.stdev_duration > rs.avg_duration  -- CV > 100%
        ORDER BY rs.stdev_duration DESC;
    END
    '
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_query_store_on = 1;

IF @variation_sql <> N''
    EXEC sp_executesql @variation_sql;

PRINT '';
PRINT '=== Query Store Analysis Complete ===';
