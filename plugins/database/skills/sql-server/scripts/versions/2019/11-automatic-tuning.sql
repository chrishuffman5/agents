/******************************************************************************
 * 11-automatic-tuning.sql
 * SQL Server 2019 (Compatibility Level 150) — Automatic Tuning Diagnostics
 *
 * Covers:
 *   - Automatic tuning configuration per database
 *   - Plan regression corrections (force/unforce history)
 *   - Active tuning recommendations
 *   - Automatic plan correction impact analysis
 *
 * Safe: read-only, no temp tables, no cursors.
 * Prerequisites: Query Store must be enabled.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — Automatic Tuning Configuration
=============================================================================*/
SELECT
    DB_NAME()                               AS database_name,
    ato.name                                AS option_name,
    ato.desired_state_desc                  AS desired_state,
    ato.actual_state_desc                   AS actual_state,
    ato.reason_desc                         AS reason
FROM sys.database_automatic_tuning_options AS ato;

/*=============================================================================
  Section 2 — Active Tuning Recommendations
=============================================================================*/
SELECT
    tr.name                                 AS recommendation_name,
    tr.type                                 AS recommendation_type,
    tr.reason                               AS recommendation_reason,
    tr.valid_since,
    tr.last_refresh,
    tr.state,
    JSON_VALUE(tr.state, '$.currentValue')  AS current_state,
    JSON_VALUE(tr.state, '$.reason')        AS state_reason,
    JSON_VALUE(tr.details, '$.implementationDetails.script')
                                            AS implementation_script,
    tr.is_revertable_action,
    tr.is_executable_action,
    JSON_VALUE(tr.score, '$.currentValue')  AS improvement_score,
    tr.execute_action_start_time,
    tr.execute_action_duration,
    tr.execute_action_initiated_by,
    tr.execute_action_initiated_time,
    tr.revert_action_start_time,
    tr.revert_action_duration,
    tr.revert_action_initiated_by,
    tr.revert_action_initiated_time,
    tr.details                              AS full_details_json
FROM sys.dm_db_tuning_recommendations AS tr
ORDER BY tr.valid_since DESC;

/*=============================================================================
  Section 3 — Plan Regression Analysis
  Identifies queries where automatic tuning forced a better plan.
=============================================================================*/
;WITH ForcedPlans AS (
    SELECT
        p.query_id,
        p.plan_id,
        p.is_forced_plan,
        p.force_failure_count,
        p.last_force_failure_reason_desc    AS force_failure_reason,
        p.last_execution_time,
        p.compatibility_level
    FROM sys.query_store_plan AS p
    WHERE p.is_forced_plan = 1
)
SELECT
    fp.query_id,
    fp.plan_id,
    qt.query_sql_text,
    OBJECT_NAME(q.object_id)                AS object_name,
    fp.force_failure_count,
    fp.force_failure_reason,
    fp.last_execution_time,
    fp.compatibility_level,
    rs.count_executions                     AS exec_count_since_forced,
    rs.avg_cpu_time / 1000                  AS avg_cpu_ms,
    rs.avg_duration / 1000                  AS avg_duration_ms,
    rs.avg_logical_io_reads                 AS avg_reads
FROM ForcedPlans AS fp
INNER JOIN sys.query_store_query AS q
    ON fp.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
LEFT JOIN (
    SELECT
        plan_id,
        SUM(count_executions)               AS count_executions,
        AVG(avg_cpu_time)                   AS avg_cpu_time,
        AVG(avg_duration)                   AS avg_duration,
        AVG(avg_logical_io_reads)           AS avg_logical_io_reads
    FROM sys.query_store_runtime_stats
    GROUP BY plan_id
) AS rs
    ON fp.plan_id = rs.plan_id
ORDER BY rs.count_executions DESC;

/*=============================================================================
  Section 4 — Queries with Multiple Plans (regression candidates)
=============================================================================*/
;WITH MultiPlanQueries AS (
    SELECT
        q.query_id,
        COUNT(DISTINCT p.plan_id)           AS plan_count,
        MAX(p.last_execution_time)          AS last_execution
    FROM sys.query_store_query AS q
    INNER JOIN sys.query_store_plan AS p
        ON q.query_id = p.query_id
    GROUP BY q.query_id
    HAVING COUNT(DISTINCT p.plan_id) > 1
)
SELECT TOP 30
    mpq.query_id,
    mpq.plan_count,
    mpq.last_execution,
    qt.query_sql_text,
    OBJECT_NAME(q.object_id)                AS object_name,
    q.count_compiles                        AS compile_count,
    CASE
        WHEN mpq.plan_count > 5
        THEN 'HIGH plan instability'
        WHEN mpq.plan_count > 2
        THEN 'Moderate plan instability'
        ELSE 'Multiple plans detected'
    END                                     AS stability_assessment
FROM MultiPlanQueries AS mpq
INNER JOIN sys.query_store_query AS q
    ON mpq.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
ORDER BY mpq.plan_count DESC;

/*=============================================================================
  Section 5 — Automatic Tuning Impact Summary
=============================================================================*/
SELECT
    JSON_VALUE(tr.state, '$.currentValue')  AS recommendation_state,
    COUNT(*)                                AS recommendation_count,
    AVG(CAST(JSON_VALUE(tr.score, '$.currentValue') AS FLOAT))
                                            AS avg_improvement_score
FROM sys.dm_db_tuning_recommendations AS tr
GROUP BY JSON_VALUE(tr.state, '$.currentValue');
