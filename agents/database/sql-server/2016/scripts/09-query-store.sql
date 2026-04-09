/*******************************************************************************
 * Script:    09-query-store.sql
 * Purpose:   Query Store diagnostics — NEW in SQL Server 2016
 * Version:   SQL Server 2016 (Compatibility Level 130)
 * Date:      2026-04-06
 *
 * Returns:   Query Store configuration, top regressed queries, forced plans,
 *            plan count per query, queries with highest variation, and
 *            resource consumption summaries.
 *
 * IMPORTANT: Query Store was introduced in SQL Server 2016. This is the first
 *            version — wait stats in Query Store are NOT available until 2017.
 *            Run this script in the context of the database you want to analyse.
 *
 * Recommended 2016 Query Store Settings:
 *   ALTER DATABASE [YourDB] SET QUERY_STORE = ON (
 *       OPERATION_MODE = READ_WRITE,
 *       CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
 *       DATA_FLUSH_INTERVAL_SECONDS = 900,
 *       INTERVAL_LENGTH_MINUTES = 60,
 *       MAX_STORAGE_SIZE_MB = 1024,
 *       QUERY_CAPTURE_MODE = AUTO,           -- avoid ALL on busy systems
 *       SIZE_BASED_CLEANUP_MODE = AUTO
 *   );
 *
 * Safety:    Read-only. Safe for production execution.
 ******************************************************************************/

SET NOCOUNT ON;

-- ============================================================================
-- SECTION 1: Query Store Configuration Check
-- ============================================================================
-- Verify Query Store is enabled and review its settings.

SELECT
    d.name                                      AS [Database],
    d.is_query_store_on                         AS [Query Store Enabled],
    qso.desired_state_desc                      AS [Desired State],
    qso.actual_state_desc                       AS [Actual State],
    CASE
        WHEN qso.actual_state_desc = 'READ_ONLY'
         AND qso.desired_state_desc = 'READ_WRITE'
            THEN 'WARNING: Query Store fell to READ_ONLY (space full?)'
        WHEN qso.actual_state_desc = 'OFF'
            THEN 'Query Store is OFF for this database'
        WHEN qso.actual_state_desc = 'ERROR'
            THEN 'ERROR state — check for corruption'
        ELSE 'OK'
    END                                         AS [Health],
    qso.current_storage_size_mb                 AS [Current Size MB],
    qso.max_storage_size_mb                     AS [Max Size MB],
    CAST(100.0 * qso.current_storage_size_mb
         / NULLIF(qso.max_storage_size_mb, 0)
         AS DECIMAL(6,2))                       AS [Storage Used Pct],
    qso.stale_query_threshold_days              AS [Stale Threshold Days],
    qso.flush_interval_seconds                  AS [Flush Interval Sec],
    qso.interval_length_minutes                 AS [Interval Length Min],
    qso.size_based_cleanup_mode_desc            AS [Size Cleanup Mode],
    qso.query_capture_mode_desc                 AS [Capture Mode],
    qso.max_plans_per_query                     AS [Max Plans Per Query]
FROM sys.databases AS d
CROSS APPLY (
    SELECT *
    FROM sys.database_query_store_options
) AS qso
WHERE d.database_id = DB_ID();


-- ============================================================================
-- SECTION 2: Top 25 Queries by Total CPU (from Query Store)
-- ============================================================================
-- Uses runtime stats intervals for a workload-representative view.

SELECT TOP 25
    q.query_id                                  AS [Query ID],
    qt.query_sql_text                           AS [Query Text],
    COALESCE(OBJECT_NAME(q.object_id), 'Ad Hoc')
                                                AS [Object Name],
    SUM(rs.count_executions)                    AS [Total Executions],
    SUM(rs.avg_cpu_time * rs.count_executions)  AS [Total CPU (us)],
    CAST(SUM(rs.avg_cpu_time * rs.count_executions)
         / NULLIF(SUM(rs.count_executions), 0)
         AS DECIMAL(18,2))                      AS [Avg CPU (us)],
    CAST(SUM(rs.avg_duration * rs.count_executions)
         / NULLIF(SUM(rs.count_executions), 0)
         AS DECIMAL(18,2))                      AS [Avg Duration (us)],
    CAST(SUM(rs.avg_logical_io_reads * rs.count_executions)
         / NULLIF(SUM(rs.count_executions), 0)
         AS DECIMAL(18,2))                      AS [Avg Logical Reads],
    CAST(SUM(rs.avg_physical_io_reads * rs.count_executions)
         / NULLIF(SUM(rs.count_executions), 0)
         AS DECIMAL(18,2))                      AS [Avg Physical Reads],
    CAST(SUM(rs.avg_rowcount * rs.count_executions)
         / NULLIF(SUM(rs.count_executions), 0)
         AS DECIMAL(18,2))                      AS [Avg Row Count],
    COUNT(DISTINCT p.plan_id)                   AS [Plan Count],
    MAX(rs.last_execution_time)                 AS [Last Execution]
FROM sys.query_store_query AS q
INNER JOIN sys.query_store_query_text AS qt
    ON qt.query_text_id = q.query_text_id
INNER JOIN sys.query_store_plan AS p
    ON p.query_id = q.query_id
INNER JOIN sys.query_store_runtime_stats AS rs
    ON rs.plan_id = p.plan_id
GROUP BY q.query_id, qt.query_sql_text, q.object_id
ORDER BY [Total CPU (us)] DESC;


-- ============================================================================
-- SECTION 3: Top Regressed Queries (CPU)
-- ============================================================================
-- Compares recent performance to historical baseline.
-- "Regressed" = recent avg CPU is significantly higher than historical avg.

;WITH QueryPerf AS (
    SELECT
        q.query_id,
        qt.query_sql_text,
        COALESCE(OBJECT_NAME(q.object_id), 'Ad Hoc') AS object_name,
        p.plan_id,
        rs.avg_cpu_time,
        rs.count_executions,
        rsi.start_time,
        rsi.end_time
    FROM sys.query_store_query AS q
    INNER JOIN sys.query_store_query_text AS qt
        ON qt.query_text_id = q.query_text_id
    INNER JOIN sys.query_store_plan AS p
        ON p.query_id = q.query_id
    INNER JOIN sys.query_store_runtime_stats AS rs
        ON rs.plan_id = p.plan_id
    INNER JOIN sys.query_store_runtime_stats_interval AS rsi
        ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
),
RecentPerf AS (
    SELECT
        query_id,
        query_sql_text,
        object_name,
        SUM(avg_cpu_time * count_executions)
            / NULLIF(SUM(count_executions), 0)  AS recent_avg_cpu,
        SUM(count_executions)                   AS recent_execs
    FROM QueryPerf
    WHERE start_time >= DATEADD(HOUR, -2, GETDATE())
    GROUP BY query_id, query_sql_text, object_name
    HAVING SUM(count_executions) > 10
),
HistoricalPerf AS (
    SELECT
        query_id,
        SUM(avg_cpu_time * count_executions)
            / NULLIF(SUM(count_executions), 0)  AS historical_avg_cpu,
        SUM(count_executions)                   AS historical_execs
    FROM QueryPerf
    WHERE start_time < DATEADD(HOUR, -2, GETDATE())
      AND start_time >= DATEADD(DAY, -7, GETDATE())
    GROUP BY query_id
    HAVING SUM(count_executions) > 50
)
SELECT TOP 20
    rp.query_id                                 AS [Query ID],
    rp.object_name                              AS [Object],
    rp.query_sql_text                           AS [Query Text],
    rp.recent_execs                             AS [Recent Execs],
    CAST(rp.recent_avg_cpu AS DECIMAL(18,2))    AS [Recent Avg CPU (us)],
    hp.historical_execs                         AS [Historical Execs],
    CAST(hp.historical_avg_cpu AS DECIMAL(18,2))AS [Historical Avg CPU (us)],
    CAST(rp.recent_avg_cpu / NULLIF(hp.historical_avg_cpu, 0)
         AS DECIMAL(8,2))                       AS [Regression Factor],
    CAST(rp.recent_avg_cpu - hp.historical_avg_cpu
         AS DECIMAL(18,2))                      AS [CPU Increase (us)]
FROM RecentPerf AS rp
INNER JOIN HistoricalPerf AS hp
    ON hp.query_id = rp.query_id
WHERE rp.recent_avg_cpu > hp.historical_avg_cpu * 1.5   -- 50%+ regression
ORDER BY [Regression Factor] DESC;


-- ============================================================================
-- SECTION 4: Forced Plans
-- ============================================================================
-- Lists queries where a specific plan has been forced. Check that forcing
-- is still beneficial and that plans haven't become invalid.

SELECT
    q.query_id                                  AS [Query ID],
    p.plan_id                                   AS [Plan ID],
    p.is_forced_plan                            AS [Is Forced],
    p.force_failure_count                       AS [Force Failures],
    p.last_force_failure_reason_desc            AS [Last Failure Reason],
    qt.query_sql_text                           AS [Query Text],
    COALESCE(OBJECT_NAME(q.object_id), 'Ad Hoc')
                                                AS [Object Name],
    p.last_compile_start_time                   AS [Last Compile],
    p.last_execution_time                       AS [Last Execution],
    p.count_compiles                            AS [Compile Count],
    p.query_plan                                AS [Plan XML],
    CASE
        WHEN p.force_failure_count > 0
            THEN 'WARNING: Plan forcing has failed ' +
                 CAST(p.force_failure_count AS VARCHAR(10)) + ' time(s)'
        WHEN p.last_execution_time < DATEADD(DAY, -7, GETDATE())
            THEN 'NOTE: Forced plan not executed in 7+ days'
        ELSE 'OK'
    END                                         AS [Status]
FROM sys.query_store_plan AS p
INNER JOIN sys.query_store_query AS q
    ON q.query_id = p.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON qt.query_text_id = q.query_text_id
WHERE p.is_forced_plan = 1
ORDER BY p.force_failure_count DESC, q.query_id;


-- ============================================================================
-- SECTION 5: Queries with Multiple Plans (Plan Instability)
-- ============================================================================
-- Queries that compile to many different plans may suffer from parameter
-- sniffing or cardinality estimation issues.

;WITH PlanCounts AS (
    SELECT
        q.query_id,
        qt.query_sql_text,
        COALESCE(OBJECT_NAME(q.object_id), 'Ad Hoc') AS object_name,
        COUNT(DISTINCT p.plan_id)               AS plan_count,
        MIN(p.last_compile_start_time)          AS first_compile,
        MAX(p.last_compile_start_time)          AS last_compile
    FROM sys.query_store_query AS q
    INNER JOIN sys.query_store_query_text AS qt
        ON qt.query_text_id = q.query_text_id
    INNER JOIN sys.query_store_plan AS p
        ON p.query_id = q.query_id
    GROUP BY q.query_id, qt.query_sql_text, q.object_id
    HAVING COUNT(DISTINCT p.plan_id) > 1
)
SELECT TOP 25
    query_id                                    AS [Query ID],
    object_name                                 AS [Object Name],
    plan_count                                  AS [Plan Count],
    query_sql_text                              AS [Query Text],
    first_compile                               AS [First Compile],
    last_compile                                AS [Last Compile]
FROM PlanCounts
ORDER BY plan_count DESC;


-- ============================================================================
-- SECTION 6: Queries with Highest CPU Variation (Unstable Performance)
-- ============================================================================
-- High standard deviation in CPU time relative to the mean indicates
-- inconsistent execution times — a sign of parameter sniffing.

SELECT TOP 25
    q.query_id                                  AS [Query ID],
    qt.query_sql_text                           AS [Query Text],
    COALESCE(OBJECT_NAME(q.object_id), 'Ad Hoc')
                                                AS [Object Name],
    SUM(rs.count_executions)                    AS [Total Execs],
    CAST(MIN(rs.min_cpu_time) AS DECIMAL(18,2)) AS [Min CPU (us)],
    CAST(MAX(rs.max_cpu_time) AS DECIMAL(18,2)) AS [Max CPU (us)],
    CAST(SUM(rs.avg_cpu_time * rs.count_executions)
         / NULLIF(SUM(rs.count_executions), 0)
         AS DECIMAL(18,2))                      AS [Avg CPU (us)],
    CAST(SUM(rs.stdev_cpu_time * rs.count_executions)
         / NULLIF(SUM(rs.count_executions), 0)
         AS DECIMAL(18,2))                      AS [Weighted StdDev CPU (us)],
    CASE
        WHEN SUM(rs.avg_cpu_time * rs.count_executions)
             / NULLIF(SUM(rs.count_executions), 0) > 0
        THEN CAST(
            (SUM(rs.stdev_cpu_time * rs.count_executions)
             / NULLIF(SUM(rs.count_executions), 0))
            / (SUM(rs.avg_cpu_time * rs.count_executions)
             / NULLIF(SUM(rs.count_executions), 0))
            AS DECIMAL(8,2))
        ELSE 0
    END                                         AS [Coefficient of Variation],
    COUNT(DISTINCT p.plan_id)                   AS [Plan Count]
FROM sys.query_store_query AS q
INNER JOIN sys.query_store_query_text AS qt
    ON qt.query_text_id = q.query_text_id
INNER JOIN sys.query_store_plan AS p
    ON p.query_id = q.query_id
INNER JOIN sys.query_store_runtime_stats AS rs
    ON rs.plan_id = p.plan_id
GROUP BY q.query_id, qt.query_sql_text, q.object_id
HAVING SUM(rs.count_executions) > 10
   AND MAX(rs.max_cpu_time) > MIN(rs.min_cpu_time) * 10  -- 10x range
ORDER BY [Coefficient of Variation] DESC;


-- ============================================================================
-- SECTION 7: Resource Consumption Summary by Interval
-- ============================================================================
-- Aggregate Query Store stats per time interval for trend analysis.

SELECT TOP 48   -- last 48 intervals
    rsi.start_time                              AS [Interval Start],
    rsi.end_time                                AS [Interval End],
    SUM(rs.count_executions)                    AS [Total Executions],
    CAST(SUM(rs.avg_cpu_time * rs.count_executions)
         / 1000000.0 AS DECIMAL(18,2))         AS [Total CPU Sec],
    CAST(SUM(rs.avg_duration * rs.count_executions)
         / 1000000.0 AS DECIMAL(18,2))         AS [Total Duration Sec],
    CAST(SUM(rs.avg_logical_io_reads * rs.count_executions)
         AS DECIMAL(18,0))                      AS [Total Logical Reads],
    CAST(SUM(rs.avg_physical_io_reads * rs.count_executions)
         AS DECIMAL(18,0))                      AS [Total Physical Reads],
    COUNT(DISTINCT rs.plan_id)                  AS [Active Plans],
    SUM(rs.avg_cpu_time * rs.count_executions)
        / NULLIF(SUM(rs.count_executions), 0)  AS [Avg CPU per Exec (us)]
FROM sys.query_store_runtime_stats AS rs
INNER JOIN sys.query_store_runtime_stats_interval AS rsi
    ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
GROUP BY rsi.start_time, rsi.end_time
ORDER BY rsi.start_time DESC;
