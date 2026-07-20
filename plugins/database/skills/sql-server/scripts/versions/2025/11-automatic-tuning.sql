/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Automatic Tuning Diagnostics
 *
 * Purpose : Monitor automatic tuning activity including plan regression
 *           correction and index management recommendations.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Automatic Tuning Configuration
 *   2. Active Tuning Recommendations
 *   3. Plan Regression Corrections (auto plan forcing)
 *   4. Recommendation History
 *   5. Index Recommendations from DMVs
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: Automatic Tuning Configuration
------------------------------------------------------------------------------*/
SELECT
    name                                            AS option_name,
    desired_state_desc                              AS desired_state,
    actual_state_desc                               AS actual_state,
    reason_desc                                     AS reason
FROM sys.database_automatic_tuning_options;

/*------------------------------------------------------------------------------
  Section 2: Active Tuning Recommendations
  sys.dm_db_tuning_recommendations contains AI-driven suggestions.
------------------------------------------------------------------------------*/
SELECT
    name                                            AS recommendation_name,
    type                                            AS recommendation_type,
    reason,
    valid_since,
    last_refresh,
    state,
    is_executable_action,
    is_revertable_action,
    score,
    CAST(details AS NVARCHAR(MAX))                  AS recommendation_details
FROM sys.dm_db_tuning_recommendations
ORDER BY score DESC;

/*------------------------------------------------------------------------------
  Section 3: Plan Regression Corrections
  Forced plans applied by automatic tuning to correct regressions.
------------------------------------------------------------------------------*/
SELECT
    qsp.plan_id,
    qsp.query_id,
    qsp.is_forced_plan,
    qsp.plan_forcing_type_desc                      AS forcing_type,
    qsp.force_failure_count,
    qsp.last_force_failure_reason_desc              AS last_failure_reason,
    qsqt.query_sql_text,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.avg_cpu_time / 1000                        AS avg_cpu_ms,
    qsrs.count_executions,
    qsrs.last_execution_time,
    -- NEW in 2025: Plan feedback for forced plans
    pf.feature_desc                                 AS feedback_type,
    pf.feedback_data
FROM sys.query_store_plan AS qsp
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
LEFT JOIN sys.query_store_runtime_stats AS qsrs
    ON qsp.plan_id = qsrs.plan_id
LEFT JOIN sys.query_store_plan_feedback AS pf                                  -- NEW in 2025
    ON qsp.plan_id = pf.plan_id
WHERE qsp.plan_forcing_type_desc = 'AUTO'
ORDER BY qsp.force_failure_count DESC;

/*------------------------------------------------------------------------------
  Section 4: Recommendation History
  Parse JSON details from tuning recommendations for analysis.
------------------------------------------------------------------------------*/
;WITH parsed AS (
    SELECT
        name,
        type,
        reason,
        score,
        state,
        valid_since,
        last_refresh,
        JSON_VALUE(CAST(details AS NVARCHAR(MAX)), '$.implementationDetails.script')
                                                    AS implementation_script,
        JSON_VALUE(CAST(details AS NVARCHAR(MAX)), '$.currentValue')
                                                    AS current_value,
        JSON_VALUE(CAST(details AS NVARCHAR(MAX)), '$.recommendedValue')
                                                    AS recommended_value
    FROM sys.dm_db_tuning_recommendations
)
SELECT
    name,
    type,
    reason,
    score,
    state,
    valid_since,
    last_refresh,
    current_value,
    recommended_value,
    implementation_script
FROM parsed
ORDER BY score DESC;

/*------------------------------------------------------------------------------
  Section 5: Index Recommendations from DMVs
  Missing index recommendations ranked by improvement measure.
------------------------------------------------------------------------------*/
SELECT TOP (25)
    DB_NAME(mid.database_id)                        AS database_name,
    mid.statement                                   AS table_name,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.unique_compiles,
    migs.user_seeks,
    migs.user_scans,
    migs.avg_total_user_cost,
    migs.avg_user_impact,
    CAST(migs.user_seeks * migs.avg_total_user_cost
        * (migs.avg_user_impact / 100.0) AS DECIMAL(18,2))
                                                    AS improvement_measure,
    'CREATE NONCLUSTERED INDEX [IX_auto_' +
        REPLACE(REPLACE(REPLACE(mid.statement, '[', ''), ']', ''), '.', '_') +
        '] ON ' + mid.statement +
        ' (' + COALESCE(mid.equality_columns, '') +
        CASE
            WHEN mid.equality_columns IS NOT NULL
             AND mid.inequality_columns IS NOT NULL
            THEN ', '
            ELSE ''
        END +
        COALESCE(mid.inequality_columns, '') + ')' +
        CASE
            WHEN mid.included_columns IS NOT NULL
            THEN ' INCLUDE (' + mid.included_columns + ')'
            ELSE ''
        END                                         AS create_index_statement
FROM sys.dm_db_missing_index_group_stats AS migs
INNER JOIN sys.dm_db_missing_index_groups AS mig
    ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid
    ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY improvement_measure DESC;
