/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Intelligent Query Processing
 *
 * Purpose : Diagnostics for all IQP features including 2025 additions.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. IQP Feature Configuration Summary
 *   2. Memory Grant Feedback Analysis
 *   3. DOP Feedback Analysis (enhanced in 2025: default ON)
 *   4. CE Feedback Analysis (enhanced in 2025: expressions)
 *   5. Parameter Sensitive Plan (PSP) Optimization
 *   6. Optional Parameter Plan Optimization (OPPO) -- NEW in 2025
 *   7. LAQ Feedback (Optimized Locking) -- NEW in 2025
 *   8. Batch Mode on Rowstore
 *   9. Adaptive Joins
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: IQP Feature Configuration Summary
  Database-scoped configurations that control IQP features.
------------------------------------------------------------------------------*/
SELECT
    d.name                                          AS database_name,
    d.compatibility_level,
    CASE WHEN d.compatibility_level >= 170
        THEN 'SQL Server 2025 (full IQP)'
        WHEN d.compatibility_level >= 160
        THEN 'SQL Server 2022 (most IQP features)'
        WHEN d.compatibility_level >= 150
        THEN 'SQL Server 2019 (partial IQP)'
        ELSE 'Pre-IQP compatibility level'
    END                                             AS iqp_tier
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.state = 0
ORDER BY d.compatibility_level DESC, d.name;

-- Database-scoped configuration for IQP
SELECT
    name                                            AS config_name,
    value                                           AS config_value,
    value_for_secondary
FROM sys.database_scoped_configurations
WHERE name IN (
    'BATCH_MODE_ADAPTIVE_JOINS',
    'BATCH_MODE_MEMORY_GRANT_FEEDBACK',
    'BATCH_MODE_ON_ROWSTORE',
    'CE_FEEDBACK',
    'DOP_FEEDBACK',
    'EXEC_QUERY_STATS_FOR_SCALAR_FUNCTIONS',
    'INTERLEAVED_EXECUTION_TVF',
    'MEMORY_GRANT_FEEDBACK_PERCENTILE',
    'MEMORY_GRANT_FEEDBACK_PERSISTENCE',
    'OPTIMIZED_PLAN_FORCING',
    'PARAMETER_SENSITIVE_PLAN_OPTIMIZATION',
    'TSQL_SCALAR_UDF_INLINING',
    'PREVIEW_FEATURES'                                                         -- NEW in 2025
)
ORDER BY name;

/*------------------------------------------------------------------------------
  Section 2: Memory Grant Feedback Analysis
  Plans with memory grant feedback (feature_id = 1).
------------------------------------------------------------------------------*/
SELECT
    pf.plan_id,
    qsp.query_id,
    pf.feature_desc,
    pf.feedback_data,
    pf.state_desc                                   AS feedback_state,
    qsrs.avg_query_max_used_memory * 8              AS avg_max_memory_kb,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.count_executions,
    qsqt.query_sql_text
FROM sys.query_store_plan_feedback AS pf
INNER JOIN sys.query_store_plan AS qsp
    ON pf.plan_id = qsp.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
LEFT JOIN sys.query_store_runtime_stats AS qsrs
    ON qsp.plan_id = qsrs.plan_id
WHERE pf.feature_id = 1                             -- Memory Grant Feedback
ORDER BY pf.plan_id;

/*------------------------------------------------------------------------------
  Section 3: DOP Feedback Analysis
  Plans with DOP feedback (feature_id = 3).
  NEW in 2025: DOP Feedback is enabled by default.
------------------------------------------------------------------------------*/
SELECT
    pf.plan_id,
    qsp.query_id,
    pf.feature_desc,
    pf.feedback_data,
    pf.state_desc                                   AS feedback_state,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.avg_cpu_time / 1000                        AS avg_cpu_ms,
    qsrs.count_executions,
    qsqt.query_sql_text
FROM sys.query_store_plan_feedback AS pf
INNER JOIN sys.query_store_plan AS qsp
    ON pf.plan_id = qsp.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
LEFT JOIN sys.query_store_runtime_stats AS qsrs
    ON qsp.plan_id = qsrs.plan_id
WHERE pf.feature_id = 3                             -- DOP Feedback
ORDER BY pf.plan_id;

/*------------------------------------------------------------------------------
  Section 4: CE Feedback Analysis
  Plans with cardinality estimation feedback (feature_id = 2).
  NEW in 2025: CE Feedback for Expressions (calculated columns, conversions).
------------------------------------------------------------------------------*/
SELECT
    pf.plan_id,
    qsp.query_id,
    pf.feature_desc,
    pf.feedback_data,
    pf.state_desc                                   AS feedback_state,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.avg_logical_io_reads                       AS avg_logical_reads,
    qsrs.count_executions,
    qsqt.query_sql_text
FROM sys.query_store_plan_feedback AS pf
INNER JOIN sys.query_store_plan AS qsp
    ON pf.plan_id = qsp.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
LEFT JOIN sys.query_store_runtime_stats AS qsrs
    ON qsp.plan_id = qsrs.plan_id
WHERE pf.feature_id = 2                             -- CE Feedback
ORDER BY pf.plan_id;

/*------------------------------------------------------------------------------
  Section 5: Parameter Sensitive Plan (PSP) Optimization
  Queries using PSP with multiple dispatch plans.
  Dispatcher plans have query_plan_hash values linked to variant sub-plans.
------------------------------------------------------------------------------*/
;WITH psp_queries AS (
    SELECT
        qsp.query_id,
        COUNT(DISTINCT qsp.plan_id)                 AS variant_count,
        MIN(qsrs.avg_duration) / 1000               AS min_avg_duration_ms,
        MAX(qsrs.avg_duration) / 1000               AS max_avg_duration_ms,
        SUM(qsrs.count_executions)                  AS total_executions
    FROM sys.query_store_plan AS qsp
    INNER JOIN sys.query_store_runtime_stats AS qsrs
        ON qsp.plan_id = qsrs.plan_id
    INNER JOIN sys.query_store_query AS qsq
        ON qsp.query_id = qsq.query_id
    WHERE qsp.plan_type = 2                          -- Dispatcher plan (PSP)
    GROUP BY qsp.query_id
)
SELECT TOP (25)
    psp.query_id,
    psp.variant_count,
    psp.min_avg_duration_ms,
    psp.max_avg_duration_ms,
    psp.total_executions,
    qsqt.query_sql_text
FROM psp_queries AS psp
INNER JOIN sys.query_store_query AS qsq
    ON psp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
ORDER BY psp.variant_count DESC;

/*------------------------------------------------------------------------------
  Section 6: Optional Parameter Plan Optimization (OPPO) -- NEW in 2025
  OPPO leverages the PSP infrastructure for optional parameters.
  Requires compat level 170.
  Look for plans with multiple variants based on optional parameter patterns.
------------------------------------------------------------------------------*/
-- Identify queries likely using OPPO (stored procs with many plan variants)
SELECT TOP (25)
    qsq.query_id,
    qsq.object_id,
    OBJECT_NAME(qsq.object_id)                     AS object_name,
    COUNT(DISTINCT qsp.plan_id)                     AS plan_variant_count,
    SUM(qsrs.count_executions)                      AS total_executions,
    AVG(qsrs.avg_duration) / 1000                   AS avg_duration_ms,
    MIN(qsrs.avg_duration) / 1000                   AS min_avg_duration_ms,
    MAX(qsrs.avg_duration) / 1000                   AS max_avg_duration_ms,
    qsqt.query_sql_text
FROM sys.query_store_query AS qsq
INNER JOIN sys.query_store_plan AS qsp
    ON qsq.query_id = qsp.query_id
INNER JOIN sys.query_store_runtime_stats AS qsrs
    ON qsp.plan_id = qsrs.plan_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
WHERE qsq.object_id > 0                             -- from stored procedures
GROUP BY qsq.query_id, qsq.object_id, qsqt.query_sql_text
HAVING COUNT(DISTINCT qsp.plan_id) > 2
ORDER BY plan_variant_count DESC;

/*------------------------------------------------------------------------------
  Section 7: LAQ Feedback (Optimized Locking) -- NEW in 2025
  Plans with Lock After Qualification feedback (feature_id = 4).
  LAQ Feedback tracks when LAQ is disabled for a plan due to heuristics.
  Stored in sys.query_store_plan_feedback with feature_desc = 'LAQ Feedback'.
------------------------------------------------------------------------------*/
SELECT
    pf.plan_id,
    qsp.query_id,
    pf.feature_desc,
    pf.feedback_data,
    pf.state_desc                                   AS feedback_state,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.avg_cpu_time / 1000                        AS avg_cpu_ms,
    qsrs.count_executions,
    qsqt.query_sql_text
FROM sys.query_store_plan_feedback AS pf
INNER JOIN sys.query_store_plan AS qsp
    ON pf.plan_id = qsp.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
LEFT JOIN sys.query_store_runtime_stats AS qsrs
    ON qsp.plan_id = qsrs.plan_id
WHERE pf.feature_id = 4                             -- LAQ Feedback (NEW in 2025)
ORDER BY pf.plan_id;

/*------------------------------------------------------------------------------
  Section 8: Batch Mode on Rowstore
  Queries using batch mode processing on traditional rowstore indexes.
------------------------------------------------------------------------------*/
SELECT TOP (25)
    qsp.plan_id,
    qsp.query_id,
    qsp.engine_version,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.avg_cpu_time / 1000                        AS avg_cpu_ms,
    qsrs.count_executions,
    qsqt.query_sql_text
FROM sys.query_store_plan AS qsp
INNER JOIN sys.query_store_runtime_stats AS qsrs
    ON qsp.plan_id = qsrs.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
WHERE qsp.has_batch_mode_operator = 1
ORDER BY qsrs.avg_duration DESC;

/*------------------------------------------------------------------------------
  Section 9: Adaptive Joins
  Queries using adaptive join operators.
------------------------------------------------------------------------------*/
;WITH adaptive AS (
    SELECT
        qsp.plan_id,
        qsp.query_id,
        qsp.query_plan,
        qsrs.avg_duration / 1000                    AS avg_duration_ms,
        qsrs.count_executions,
        qsqt.query_sql_text
    FROM sys.query_store_plan AS qsp
    INNER JOIN sys.query_store_runtime_stats AS qsrs
        ON qsp.plan_id = qsrs.plan_id
    INNER JOIN sys.query_store_query AS qsq
        ON qsp.query_id = qsq.query_id
    INNER JOIN sys.query_store_query_text AS qsqt
        ON qsq.query_text_id = qsqt.query_text_id
    WHERE CAST(qsp.query_plan AS NVARCHAR(MAX)) LIKE '%AdaptiveJoin%'
)
SELECT TOP (25)
    plan_id,
    query_id,
    avg_duration_ms,
    count_executions,
    query_sql_text
FROM adaptive
ORDER BY count_executions DESC;
