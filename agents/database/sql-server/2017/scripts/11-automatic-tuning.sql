/******************************************************************************
* Script:   11-automatic-tuning.sql
* Purpose:  Automatic tuning diagnostics -- entirely NEW for SQL Server 2017.
*           Covers automatic tuning configuration per database, tuning
*           recommendations from sys.dm_db_tuning_recommendations, forced and
*           reverted plan recommendations, recommendation state, reason, and
*           estimated improvement.
* Server:   SQL Server 2017 (compatibility level 140)
* Date:     2026-04-06
*
* NEW in 2017 (this entire script):
*   - sys.dm_db_tuning_recommendations: the core DMV for automatic tuning
*   - sys.database_automatic_tuning_options: per-database AT configuration
*   - FORCE_LAST_GOOD_PLAN: automatic plan regression correction
*   - JSON-based recommendation details (parsed in this script)
*   - Requires Query Store enabled in READ_WRITE mode
*
* Safety:   Read-only. No modifications to server or databases.
******************************************************************************/
SET NOCOUNT ON;

-- ============================================================================
-- Section 1: Automatic Tuning Configuration per Database
-- ============================================================================
PRINT '=== Section 1: Automatic Tuning Configuration per Database ===';
PRINT '';
PRINT 'SQL Server 2017 introduced automatic plan correction (FORCE_LAST_GOOD_PLAN).';
PRINT 'When enabled, SQL Server detects plan regressions and automatically forces';
PRINT 'the last known good plan. Requires Query Store in READ_WRITE mode.';
PRINT '';

DECLARE @at_config_sql NVARCHAR(MAX) = N'';

SELECT @at_config_sql = @at_config_sql +
    N'USE ' + QUOTENAME(name) + N';
    SELECT
        DB_NAME()                                   AS [Database],
        ato.name                                    AS [Tuning Option],
        ato.desired_state_desc                      AS [Desired State],
        ato.actual_state_desc                       AS [Actual State],
        ato.reason_desc                             AS [Reason (if Desired <> Actual)],
        -- Check prerequisites
        CASE
            WHEN ato.actual_state_desc = ''ON''
            THEN ''ACTIVE -- Automatic tuning is active''
            WHEN ato.desired_state_desc = ''ON'' AND ato.actual_state_desc = ''OFF''
            THEN ''BLOCKED -- Desired ON but actual OFF. Check reason: '' + ISNULL(ato.reason_desc, ''Unknown'')
            WHEN ato.desired_state_desc = ''OFF''
            THEN ''DISABLED -- Consider enabling for plan regression protection''
            ELSE ato.actual_state_desc
        END                                         AS [Assessment],
        (SELECT actual_state_desc
         FROM sys.database_query_store_options)      AS [Query Store State]
    FROM sys.database_automatic_tuning_options ato;
    '
FROM sys.databases
WHERE database_id > 4
  AND state = 0;

IF @at_config_sql <> N''
    EXEC sp_executesql @at_config_sql;

-- Summary of which databases have AT enabled
PRINT '';
PRINT '--- Summary: Databases with Automatic Tuning ---';
PRINT '';

DECLARE @at_summary_sql NVARCHAR(MAX) = N'';

SELECT @at_summary_sql = @at_summary_sql +
    N'USE ' + QUOTENAME(name) + N';
    SELECT
        DB_NAME()                                   AS [Database],
        (SELECT is_query_store_on
         FROM sys.databases WHERE database_id = DB_ID())
                                                    AS [Query Store On],
        (SELECT actual_state_desc
         FROM sys.database_query_store_options)      AS [QS State],
        (SELECT actual_state_desc
         FROM sys.database_automatic_tuning_options
         WHERE name = ''FORCE_LAST_GOOD_PLAN'')     AS [Auto Tuning State],
        CASE
            WHEN (SELECT actual_state_desc
                  FROM sys.database_automatic_tuning_options
                  WHERE name = ''FORCE_LAST_GOOD_PLAN'') = ''ON''
             AND (SELECT actual_state_desc
                  FROM sys.database_query_store_options) = ''READ_WRITE''
            THEN ''FULLY OPERATIONAL''
            WHEN (SELECT is_query_store_on
                  FROM sys.databases WHERE database_id = DB_ID()) = 0
            THEN ''PREREQUISITE MISSING: Enable Query Store first''
            WHEN (SELECT actual_state_desc
                  FROM sys.database_query_store_options) = ''READ_ONLY''
            THEN ''PREREQUISITE MISSING: Query Store is read-only''
            ELSE ''NOT ENABLED -- Enable with: ALTER DATABASE ['' + DB_NAME() + ''] SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON)''
        END                                         AS [Overall Status];
    '
FROM sys.databases
WHERE database_id > 4
  AND state = 0;

EXEC sp_executesql @at_summary_sql;

-- ============================================================================
-- Section 2: Tuning Recommendations (sys.dm_db_tuning_recommendations)
-- This is the core DMV. It returns JSON-formatted recommendation details.
-- ============================================================================
PRINT '';
PRINT '=== Section 2: Tuning Recommendations ===';
PRINT '';
PRINT 'sys.dm_db_tuning_recommendations returns plan regression recommendations';
PRINT 'with details about the regressed query, the old plan, the new plan,';
PRINT 'and the estimated improvement from forcing the old plan.';
PRINT '';

DECLARE @at_reco_sql NVARCHAR(MAX) = N'';

SELECT @at_reco_sql = @at_reco_sql +
    N'USE ' + QUOTENAME(name) + N';
    IF EXISTS (SELECT 1 FROM sys.dm_db_tuning_recommendations)
    BEGIN
        PRINT ''--- Database: ' + name + N' ---'';

        SELECT
            DB_NAME()                               AS [Database],
            tr.name                                 AS [Recommendation Name],
            tr.type                                 AS [Recommendation Type],
            tr.reason                               AS [Reason],
            tr.valid_since                          AS [Valid Since],
            tr.state                                AS [Current State],
            -- Parse JSON details for human-readable output
            JSON_VALUE(tr.state, ''$.currentValue'')
                                                    AS [State Value],
            JSON_VALUE(tr.state, ''$.reason'')
                                                    AS [State Reason],
            tr.score                                AS [Estimated Improvement Score],
            -- Extract implementation details from JSON
            JSON_VALUE(tr.details, ''$.implementationDetails.script'')
                                                    AS [Recommended Action Script],
            -- Extract revert details
            JSON_VALUE(tr.details, ''$.undoActionDetails.script'')
                                                    AS [Revert Script],
            -- Query and plan details
            JSON_VALUE(tr.details, ''$.queryId'')
                                                    AS [Query ID],
            JSON_VALUE(tr.details, ''$.regressedPlanId'')
                                                    AS [Regressed Plan ID],
            JSON_VALUE(tr.details, ''$.recommendedPlanId'')
                                                    AS [Recommended Plan ID],
            -- Performance comparison
            JSON_VALUE(tr.details, ''$.regressedPlanExecutionCount'')
                                                    AS [Regressed Plan Executions],
            JSON_VALUE(tr.details, ''$.recommendedPlanExecutionCount'')
                                                    AS [Recommended Plan Executions],
            JSON_VALUE(tr.details, ''$.regressedPlanCpuTimeAverage'')
                                                    AS [Regressed Plan Avg CPU],
            JSON_VALUE(tr.details, ''$.recommendedPlanCpuTimeAverage'')
                                                    AS [Recommended Plan Avg CPU]
        FROM sys.dm_db_tuning_recommendations tr
        ORDER BY tr.score DESC;
    END
    ELSE
    BEGIN
        PRINT ''--- Database: ' + name + N' ---'';
        PRINT ''No tuning recommendations found.'';
    END
    '
FROM sys.databases
WHERE database_id > 4
  AND state = 0;

EXEC sp_executesql @at_reco_sql;

-- ============================================================================
-- Section 3: Detailed Recommendation Analysis with Performance Impact
-- ============================================================================
PRINT '';
PRINT '=== Section 3: Recommendation Details with Performance Impact ===';
PRINT '';

DECLARE @at_detail_sql NVARCHAR(MAX) = N'';

SELECT @at_detail_sql = @at_detail_sql +
    N'USE ' + QUOTENAME(name) + N';
    IF EXISTS (SELECT 1 FROM sys.dm_db_tuning_recommendations)
    BEGIN
        PRINT ''--- Database: ' + name + N' ---'';

        ;WITH RecommendationDetails AS (
            SELECT
                tr.name,
                tr.reason,
                tr.score,
                tr.valid_since,
                JSON_VALUE(tr.state, ''$.currentValue'')    AS state_value,
                JSON_VALUE(tr.state, ''$.reason'')          AS state_reason,
                CAST(JSON_VALUE(tr.details, ''$.queryId'')
                    AS INT)                                  AS query_id,
                CAST(JSON_VALUE(tr.details, ''$.regressedPlanId'')
                    AS INT)                                  AS regressed_plan_id,
                CAST(JSON_VALUE(tr.details, ''$.recommendedPlanId'')
                    AS INT)                                  AS recommended_plan_id,
                CAST(JSON_VALUE(tr.details,
                    ''$.regressedPlanCpuTimeAverage'')
                    AS FLOAT)                                AS regressed_cpu_avg,
                CAST(JSON_VALUE(tr.details,
                    ''$.recommendedPlanCpuTimeAverage'')
                    AS FLOAT)                                AS recommended_cpu_avg,
                CAST(JSON_VALUE(tr.details,
                    ''$.regressedPlanExecutionCount'')
                    AS INT)                                  AS regressed_exec_count,
                CAST(JSON_VALUE(tr.details,
                    ''$.recommendedPlanExecutionCount'')
                    AS INT)                                  AS recommended_exec_count
            FROM sys.dm_db_tuning_recommendations tr
        )
        SELECT
            DB_NAME()                               AS [Database],
            rd.name                                 AS [Recommendation],
            rd.reason                               AS [Reason],
            rd.score                                AS [Score],
            rd.state_value                          AS [State],
            rd.state_reason                         AS [State Reason],
            rd.query_id                             AS [Query ID],
            rd.regressed_plan_id                    AS [Bad Plan ID],
            rd.recommended_plan_id                  AS [Good Plan ID],
            CAST(rd.regressed_cpu_avg / 1000.0
                AS DECIMAL(18,2))                   AS [Bad Plan Avg CPU Ms],
            CAST(rd.recommended_cpu_avg / 1000.0
                AS DECIMAL(18,2))                   AS [Good Plan Avg CPU Ms],
            CASE
                WHEN rd.recommended_cpu_avg > 0
                THEN CAST((rd.regressed_cpu_avg - rd.recommended_cpu_avg)
                    * 100.0 / rd.recommended_cpu_avg
                    AS DECIMAL(10,2))
                ELSE NULL
            END                                     AS [CPU Regression Pct],
            rd.regressed_exec_count                 AS [Bad Plan Execs],
            rd.recommended_exec_count               AS [Good Plan Execs],
            rd.valid_since                          AS [Detected Since],
            CASE rd.state_value
                WHEN ''Active''
                THEN ''Action needed -- plan regression detected''
                WHEN ''Verifying''
                THEN ''Automatic tuning is verifying the fix''
                WHEN ''Success''
                THEN ''Plan forced successfully by automatic tuning''
                WHEN ''Reverted''
                THEN ''Fix was reverted -- forced plan did not help''
                WHEN ''Expired''
                THEN ''Recommendation expired (no longer applicable)''
                ELSE ISNULL(rd.state_value, ''Unknown'')
            END                                     AS [Recommendation Status],
            -- Get the query text if available
            SUBSTRING(qt.query_sql_text, 1, 300)    AS [Query Text]
        FROM RecommendationDetails rd
        LEFT JOIN sys.query_store_query q
            ON rd.query_id = q.query_id
        LEFT JOIN sys.query_store_query_text qt
            ON q.query_text_id = qt.query_text_id
        ORDER BY rd.score DESC;
    END
    '
FROM sys.databases
WHERE database_id > 4
  AND state = 0;

EXEC sp_executesql @at_detail_sql;

-- ============================================================================
-- Section 4: Forced Plan History (Automatic vs Manual)
-- ============================================================================
PRINT '';
PRINT '=== Section 4: Forced Plan History ===';
PRINT '';

DECLARE @forced_plans_sql NVARCHAR(MAX) = N'';

SELECT @forced_plans_sql = @forced_plans_sql +
    N'USE ' + QUOTENAME(name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + name + N' ---'';

        SELECT
            DB_NAME()                               AS [Database],
            q.query_id                              AS [Query ID],
            p.plan_id                               AS [Forced Plan ID],
            p.is_forced_plan                        AS [Is Forced],
            p.force_failure_count                   AS [Force Failures],
            p.last_force_failure_reason_desc        AS [Last Failure Reason],
            p.plan_forcing_type_desc                AS [Forcing Type],
            p.last_compile_start_time               AS [Last Compiled],
            -- Performance of the forced plan
            CAST(rs.avg_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Avg Duration Ms],
            CAST(rs.avg_cpu_time / 1000.0
                AS DECIMAL(18,2))                   AS [Avg CPU Ms],
            rs.avg_logical_io_reads                 AS [Avg Logical Reads],
            rs.count_executions                     AS [Executions],
            CASE
                WHEN p.force_failure_count > 0
                THEN ''WARNING -- Forced plan has failures. May need manual review.''
                WHEN p.force_failure_count = 0
                 AND p.is_forced_plan = 1
                THEN ''OK -- Plan is forced and executing successfully''
                ELSE ''Not forced''
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
        ORDER BY p.force_failure_count DESC, rs.avg_duration DESC;

        IF @@ROWCOUNT = 0
            PRINT ''No forced plans found.'';
    END
    '
FROM sys.databases
WHERE database_id > 4
  AND state = 0;

EXEC sp_executesql @forced_plans_sql;

-- ============================================================================
-- Section 5: Recommendation State Summary
-- ============================================================================
PRINT '';
PRINT '=== Section 5: Recommendation State Summary ===';
PRINT '';

DECLARE @state_summary_sql NVARCHAR(MAX) = N'';

SELECT @state_summary_sql = @state_summary_sql +
    N'USE ' + QUOTENAME(name) + N';
    IF EXISTS (SELECT 1 FROM sys.dm_db_tuning_recommendations)
    BEGIN
        PRINT ''--- Database: ' + name + N' ---'';

        SELECT
            DB_NAME()                               AS [Database],
            JSON_VALUE(state, ''$.currentValue'')   AS [Recommendation State],
            COUNT(*)                                AS [Count],
            AVG(score)                              AS [Avg Improvement Score],
            MAX(score)                              AS [Max Improvement Score],
            SUM(CASE
                WHEN JSON_VALUE(state, ''$.currentValue'') = ''Active''
                THEN 1 ELSE 0
            END)                                    AS [Actionable Count]
        FROM sys.dm_db_tuning_recommendations
        GROUP BY JSON_VALUE(state, ''$.currentValue'')
        ORDER BY COUNT(*) DESC;
    END
    '
FROM sys.databases
WHERE database_id > 4
  AND state = 0;

EXEC sp_executesql @state_summary_sql;

-- ============================================================================
-- Section 6: Enabling Automatic Tuning -- Quick Reference
-- ============================================================================
PRINT '';
PRINT '=== Section 6: How to Enable Automatic Tuning (Reference) ===';
PRINT '';
PRINT 'Step 1: Enable Query Store (prerequisite):';
PRINT '  ALTER DATABASE [YourDB] SET QUERY_STORE = ON (';
PRINT '      OPERATION_MODE = READ_WRITE,';
PRINT '      QUERY_CAPTURE_MODE = AUTO,';
PRINT '      WAIT_STATS_CAPTURE_MODE = ON';
PRINT '  );';
PRINT '';
PRINT 'Step 2: Enable automatic tuning:';
PRINT '  ALTER DATABASE [YourDB] SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);';
PRINT '';
PRINT 'Step 3: Monitor with this script and sys.dm_db_tuning_recommendations';
PRINT '';
PRINT 'NOTE: In SQL Server 2017, only FORCE_LAST_GOOD_PLAN is available.';
PRINT '      Azure SQL Database has additional options (CREATE_INDEX, DROP_INDEX).';
PRINT '      These are NOT available in SQL Server 2017 on-premises.';
PRINT '';

-- ============================================================================
-- Section 7: Queries Most Likely to Benefit from Automatic Tuning
-- (Queries with high plan variation that are NOT yet being tuned)
-- ============================================================================
PRINT '=== Section 7: Candidates for Automatic Tuning (Unstable Plans) ===';
PRINT '';

DECLARE @candidates_sql NVARCHAR(MAX) = N'';

SELECT @candidates_sql = @candidates_sql +
    N'USE ' + QUOTENAME(name) + N';
    IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state = 1)
    BEGIN
        PRINT ''--- Database: ' + name + N' ---'';

        ;WITH PlanVariation AS (
            SELECT
                q.query_id,
                COUNT(DISTINCT p.plan_id)           AS plan_count,
                MIN(rs.avg_duration)                AS best_duration,
                MAX(rs.avg_duration)                AS worst_duration,
                SUM(rs.count_executions)            AS total_executions
            FROM sys.query_store_plan p
            JOIN sys.query_store_query q
                ON p.query_id = q.query_id
            JOIN sys.query_store_runtime_stats rs
                ON p.plan_id = rs.plan_id
            JOIN sys.query_store_runtime_stats_interval rsi
                ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
            WHERE rsi.start_time >= DATEADD(DAY, -7, GETUTCDATE())
              AND p.is_forced_plan = 0  -- Not already forced
            GROUP BY q.query_id
            HAVING COUNT(DISTINCT p.plan_id) > 1
               AND MAX(rs.avg_duration) > MIN(rs.avg_duration) * 2  -- 2x variation
        )
        SELECT TOP 20
            DB_NAME()                               AS [Database],
            pv.query_id                             AS [Query ID],
            pv.plan_count                           AS [Number of Plans],
            CAST(pv.best_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Best Plan Duration Ms],
            CAST(pv.worst_duration / 1000.0
                AS DECIMAL(18,2))                   AS [Worst Plan Duration Ms],
            CAST((pv.worst_duration - pv.best_duration) * 100.0
                / NULLIF(pv.best_duration, 0)
                AS DECIMAL(10,2))                   AS [Performance Variation Pct],
            pv.total_executions                     AS [Total Executions],
            SUBSTRING(qt.query_sql_text, 1, 200)    AS [Query Text],
            ''Would benefit from FORCE_LAST_GOOD_PLAN''
                                                    AS [Recommendation]
        FROM PlanVariation pv
        JOIN sys.query_store_query q
            ON pv.query_id = q.query_id
        JOIN sys.query_store_query_text qt
            ON q.query_text_id = qt.query_text_id
        ORDER BY (pv.worst_duration - pv.best_duration) * pv.total_executions DESC;
    END
    '
FROM sys.databases
WHERE database_id > 4
  AND state = 0;

EXEC sp_executesql @candidates_sql;

PRINT '';
PRINT '=== Automatic Tuning Analysis Complete ===';
