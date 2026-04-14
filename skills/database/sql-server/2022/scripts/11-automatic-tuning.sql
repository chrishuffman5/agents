/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Automatic Tuning Status
 *
 * Purpose : Review automatic tuning recommendations and actions.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Automatic Tuning Configuration
 *   2. Active Tuning Recommendations
 *   3. Recommendation History & Effectiveness
 *   4. Auto Plan Correction Details
 *   5. Tuning Actions Summary
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: Automatic Tuning Configuration
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    name                                            AS tuning_option,
    desired_state_desc                              AS desired_state,
    actual_state_desc                               AS actual_state,
    reason_desc                                     AS reason
FROM sys.database_automatic_tuning_options;

-- Database-level auto tuning setting
SELECT
    DB_NAME()                                       AS database_name,
    DATABASEPROPERTYEX(DB_NAME(), 'IsAutoTuningOn') AS auto_tuning_enabled;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: Active Tuning Recommendations
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    reason                                          AS recommendation_reason,
    score                                           AS impact_score,
    type                                            AS recommendation_type,
    state,
    JSON_VALUE(details, '$.implementationDetails.script')
                                                    AS implementation_script,
    JSON_VALUE(state, '$.currentValue')             AS current_state,
    JSON_VALUE(state, '$.reason')                   AS state_reason,
    is_revertable_action,
    is_executable_action,
    execute_action_start_time,
    execute_action_duration,
    execute_action_initiated_by,
    execute_action_initiated_time,
    revert_action_start_time,
    revert_action_duration,
    revert_action_initiated_by,
    revert_action_initiated_time
FROM sys.dm_db_tuning_recommendations
ORDER BY score DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: Recommendation History & Effectiveness
──────────────────────────────────────────────────────────────────────────────*/
;WITH recommendation_details AS (
    SELECT
        reason,
        score,
        type                                        AS rec_type,
        JSON_VALUE(state, '$.currentValue')         AS current_state,
        JSON_VALUE(state, '$.reason')               AS state_reason,
        -- Parse regression details
        JSON_VALUE(details, '$.planForceDetails.queryId')
                                                    AS query_id,
        JSON_VALUE(details, '$.planForceDetails.regressedPlanId')
                                                    AS regressed_plan_id,
        JSON_VALUE(details, '$.planForceDetails.recommendedPlanId')
                                                    AS recommended_plan_id,
        -- Performance metrics
        JSON_VALUE(details, '$.planForceDetails.regressedPlanExecutionCount')
                                                    AS regressed_exec_count,
        JSON_VALUE(details, '$.planForceDetails.regressedPlanCpuTimeAverage')
                                                    AS regressed_avg_cpu,
        JSON_VALUE(details, '$.planForceDetails.recommendedPlanCpuTimeAverage')
                                                    AS recommended_avg_cpu,
        JSON_VALUE(details, '$.planForceDetails.regressedPlanAbortedCount')
                                                    AS regressed_aborted_count,
        is_revertable_action,
        is_executable_action,
        execute_action_start_time,
        revert_action_start_time
    FROM sys.dm_db_tuning_recommendations
)
SELECT
    query_id,
    reason,
    score                                           AS impact_score,
    rec_type,
    current_state,
    state_reason,
    regressed_plan_id,
    recommended_plan_id,
    regressed_exec_count,
    regressed_avg_cpu,
    recommended_avg_cpu,
    CASE
        WHEN TRY_CAST(regressed_avg_cpu AS FLOAT) > 0
         AND TRY_CAST(recommended_avg_cpu AS FLOAT) > 0
        THEN CAST(
            (TRY_CAST(regressed_avg_cpu AS FLOAT)
             - TRY_CAST(recommended_avg_cpu AS FLOAT))
            * 100.0
            / TRY_CAST(regressed_avg_cpu AS FLOAT)
            AS DECIMAL(10,2))
        ELSE NULL
    END                                             AS estimated_improvement_pct,
    is_revertable_action,
    is_executable_action,
    execute_action_start_time,
    revert_action_start_time
FROM recommendation_details
ORDER BY score DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Auto Plan Correction Details
  Links recommendations back to Query Store for full context.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (
    SELECT 1 FROM sys.database_query_store_options
    WHERE actual_state IN (1, 2)
)
BEGIN
    ;WITH forced_by_auto_tuning AS (
        SELECT
            TRY_CAST(
                JSON_VALUE(details, '$.planForceDetails.queryId') AS BIGINT
            )                                       AS query_id,
            TRY_CAST(
                JSON_VALUE(details, '$.planForceDetails.recommendedPlanId') AS BIGINT
            )                                       AS forced_plan_id,
            reason,
            score,
            JSON_VALUE(state, '$.currentValue')     AS tuning_state,
            execute_action_start_time
        FROM sys.dm_db_tuning_recommendations
        WHERE JSON_VALUE(state, '$.currentValue') = 'Active'
    )
    SELECT
        fat.query_id,
        fat.forced_plan_id,
        fat.reason,
        fat.score,
        fat.tuning_state,
        fat.execute_action_start_time,
        p.force_failure_count,
        p.last_force_failure_reason_desc            AS last_force_failure,
        rs.count_executions                         AS post_force_exec_count,
        rs.avg_duration / 1000.0                    AS post_force_avg_duration_ms,
        rs.avg_cpu_time / 1000.0                    AS post_force_avg_cpu_ms,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM forced_by_auto_tuning AS fat
    LEFT JOIN sys.query_store_plan AS p
        ON fat.forced_plan_id = p.plan_id
    LEFT JOIN sys.query_store_query AS q
        ON fat.query_id = q.query_id
    LEFT JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    LEFT JOIN sys.query_store_runtime_stats AS rs
        ON rs.plan_id = fat.forced_plan_id
    ORDER BY fat.score DESC;
END
ELSE
BEGIN
    SELECT 'Auto plan correction details require Query Store active.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: Tuning Actions Summary
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    JSON_VALUE(state, '$.currentValue')             AS action_state,
    type                                            AS recommendation_type,
    COUNT(*)                                        AS recommendation_count,
    AVG(score)                                      AS avg_score,
    SUM(CASE WHEN is_executable_action = 1 THEN 1 ELSE 0 END) AS executable_count,
    SUM(CASE WHEN is_revertable_action = 1 THEN 1 ELSE 0 END) AS revertable_count
FROM sys.dm_db_tuning_recommendations
GROUP BY JSON_VALUE(state, '$.currentValue'), type
ORDER BY recommendation_count DESC;
