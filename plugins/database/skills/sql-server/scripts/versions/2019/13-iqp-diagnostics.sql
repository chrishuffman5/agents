/******************************************************************************
 * 13-iqp-diagnostics.sql
 * SQL Server 2019 (Compatibility Level 150) — Intelligent Query Processing
 *
 * NEW for SQL Server 2019:
 *   This entire script is new. IQP in 2019 introduces:
 *   - Batch mode on rowstore                                           [NEW]
 *   - Scalar UDF inlining                                              [NEW]
 *   - Table variable deferred compilation                              [NEW]
 *   - Row mode memory grant feedback (extends 2017 batch mode feedback)[NEW]
 *   - Approximate query processing (APPROX_COUNT_DISTINCT)             [NEW]
 *
 * Covers:
 *   - IQP feature eligibility per database (compat level check)
 *   - Batch mode on rowstore detection in plan cache
 *   - Scalar UDF inlining candidates vs actually inlined
 *   - Table variable deferred compilation impact
 *   - Memory grant feedback adjustments
 *
 * Safe: read-only, no temp tables, no cursors.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — IQP Feature Eligibility per Database                     [NEW]
  IQP features require compatibility level 150+.
=============================================================================*/
SELECT
    d.database_id,
    d.name                                  AS database_name,
    d.compatibility_level,
    CASE
        WHEN d.compatibility_level >= 150
        THEN 'ELIGIBLE — all IQP features available'
        WHEN d.compatibility_level >= 140
        THEN 'PARTIAL — 2017 IQP only (adaptive joins, batch mode MGF, interleaved exec)'
        ELSE 'NOT ELIGIBLE — compat level too low'
    END                                     AS iqp_eligibility,
    /* Per-feature checks from database scoped configurations */
    (SELECT ISNULL(value, 0)
     FROM sys.database_scoped_configurations
     WHERE name = 'BATCH_MODE_ON_ROWSTORE')
                                            AS batch_mode_on_rowstore_enabled,
    (SELECT ISNULL(value, 0)
     FROM sys.database_scoped_configurations
     WHERE name = 'TSQL_SCALAR_UDF_INLINING')
                                            AS scalar_udf_inlining_enabled,
    (SELECT ISNULL(value, 0)
     FROM sys.database_scoped_configurations
     WHERE name = 'DEFERRED_COMPILATION_TV')
                                            AS deferred_compilation_tv_enabled,
    (SELECT ISNULL(value, 0)
     FROM sys.database_scoped_configurations
     WHERE name = 'BATCH_MODE_MEMORY_GRANT_FEEDBACK')
                                            AS batch_mode_mgf_enabled,
    (SELECT ISNULL(value, 0)
     FROM sys.database_scoped_configurations
     WHERE name = 'ROW_MODE_MEMORY_GRANT_FEEDBACK')
                                            AS row_mode_mgf_enabled,
    (SELECT ISNULL(value, 0)
     FROM sys.database_scoped_configurations
     WHERE name = 'BATCH_MODE_ADAPTIVE_JOINS')
                                            AS adaptive_joins_enabled,
    (SELECT ISNULL(value, 0)
     FROM sys.database_scoped_configurations
     WHERE name = 'INTERLEAVED_EXECUTION_TVF')
                                            AS interleaved_exec_enabled,
    (SELECT ISNULL(value, 0)
     FROM sys.database_scoped_configurations
     WHERE name = 'LIGHTWEIGHT_QUERY_PROFILING')
                                            AS lightweight_profiling_enabled,
    (SELECT ISNULL(value, 0)
     FROM sys.database_scoped_configurations
     WHERE name = 'LAST_QUERY_PLAN_STATS')
                                            AS last_plan_stats_enabled
FROM sys.databases AS d
WHERE d.state = 0
  AND d.database_id > 4
ORDER BY d.compatibility_level DESC, d.name;

/*=============================================================================
  Section 2 — Batch Mode on Rowstore Detection                         [NEW]
  Finds cached plans using batch mode operators on rowstore tables.
  Prior to 2019, batch mode required a columnstore index.
=============================================================================*/
;WITH BatchModeOnRowstore AS (
    SELECT
        qs.plan_handle,
        qs.sql_handle,
        qs.statement_start_offset,
        qs.statement_end_offset,
        qs.execution_count,
        qs.total_worker_time / 1000         AS total_cpu_ms,
        qs.total_elapsed_time / 1000        AS total_elapsed_ms,
        qs.total_logical_reads,
        qs.total_rows,
        qs.last_execution_time,
        qp.query_plan
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
    WHERE qp.query_plan IS NOT NULL
      /* Look for batch mode execution on non-columnstore operators */
      AND qp.query_plan.exist(
          '//RelOp[@EstimatedExecutionMode="Batch"]'
      ) = 1
)
SELECT
    bmr.execution_count,
    bmr.total_cpu_ms,
    bmr.total_elapsed_ms,
    bmr.total_logical_reads,
    bmr.total_rows,
    bmr.last_execution_time,
    DB_NAME(st.dbid)                        AS database_name,
    OBJECT_NAME(st.objectid, st.dbid)       AS object_name,
    SUBSTRING(
        st.text,
        (bmr.statement_start_offset / 2) + 1,
        (CASE bmr.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE bmr.statement_end_offset
         END - bmr.statement_start_offset) / 2 + 1
    )                                       AS query_text,
    /* Count batch mode operators in the plan */
    bmr.query_plan.value(
        'count(//RelOp[@EstimatedExecutionMode="Batch"])',
        'int'
    )                                       AS batch_mode_operator_count,
    bmr.query_plan.value(
        'count(//RelOp[@EstimatedExecutionMode="Row"])',
        'int'
    )                                       AS row_mode_operator_count,
    'Batch mode on rowstore (NEW 2019)'     AS iqp_feature
FROM BatchModeOnRowstore AS bmr
CROSS APPLY sys.dm_exec_sql_text(bmr.sql_handle) AS st
ORDER BY bmr.total_cpu_ms DESC;

/*=============================================================================
  Section 3 — Scalar UDF Inlining Analysis                             [NEW]
  Identifies scalar UDFs and whether they are eligible for inlining.
=============================================================================*/

/* 3a. Scalar UDFs and their inlining eligibility */
SELECT
    OBJECT_SCHEMA_NAME(o.object_id)         AS schema_name,
    o.name                                  AS function_name,
    o.type_desc,
    o.create_date,
    o.modify_date,
    OBJECTPROPERTYEX(o.object_id, 'IsInlineable') AS is_inlineable,
    CASE
        WHEN OBJECTPROPERTYEX(o.object_id, 'IsInlineable') = 1
        THEN 'Eligible for inlining (NEW 2019)'
        ELSE 'Not eligible — check function body for blockers'
    END                                     AS inlining_assessment,
    sm.definition                           AS function_definition
FROM sys.objects AS o
INNER JOIN sys.sql_modules AS sm
    ON o.object_id = sm.object_id
WHERE o.type = 'FN'   /* Scalar function */
ORDER BY OBJECTPROPERTYEX(o.object_id, 'IsInlineable') DESC, o.name;

/* 3b. Queries referencing scalar UDFs in plan cache */
;WITH UDFQueries AS (
    SELECT
        qs.plan_handle,
        qs.sql_handle,
        qs.statement_start_offset,
        qs.statement_end_offset,
        qs.execution_count,
        qs.total_worker_time / 1000         AS total_cpu_ms,
        qs.total_elapsed_time / 1000        AS total_elapsed_ms,
        qs.last_execution_time,
        qp.query_plan
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
    WHERE qp.query_plan IS NOT NULL
      AND qp.query_plan.exist(
          '//UserDefinedFunction'
      ) = 1
)
SELECT
    uq.execution_count,
    uq.total_cpu_ms,
    uq.total_elapsed_ms,
    uq.last_execution_time,
    DB_NAME(st.dbid)                        AS database_name,
    SUBSTRING(
        st.text,
        (uq.statement_start_offset / 2) + 1,
        (CASE uq.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE uq.statement_end_offset
         END - uq.statement_start_offset) / 2 + 1
    )                                       AS query_text,
    /* Check if UDF was inlined */
    CASE
        WHEN uq.query_plan.exist(
            '//UserDefinedFunction[@IsInlineable="true"]'
        ) = 1
        THEN 'INLINED (NEW 2019)'
        ELSE 'Not inlined — review UDF for inlining blockers'
    END                                     AS inlining_status
FROM UDFQueries AS uq
CROSS APPLY sys.dm_exec_sql_text(uq.sql_handle) AS st
ORDER BY uq.total_cpu_ms DESC;

/*=============================================================================
  Section 4 — Table Variable Deferred Compilation Impact               [NEW]
  In 2019, table variable cardinality estimation is deferred to first
  execution (instead of assuming 1 row at compile time).
=============================================================================*/

/* 4a. Identify queries using table variables in plan cache */
;WITH TableVarQueries AS (
    SELECT
        qs.plan_handle,
        qs.sql_handle,
        qs.statement_start_offset,
        qs.statement_end_offset,
        qs.execution_count,
        qs.total_worker_time / 1000         AS total_cpu_ms,
        qs.total_elapsed_time / 1000        AS total_elapsed_ms,
        qs.total_logical_reads,
        qs.total_rows,
        qs.total_spills,
        qs.last_execution_time
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
    WHERE st.text LIKE '%@%'                /* Quick filter for table vars */
      AND (st.text LIKE '%DECLARE%TABLE%'
           OR st.text LIKE '%table type%')
)
SELECT TOP 30
    tvq.execution_count,
    tvq.total_cpu_ms,
    tvq.total_elapsed_ms,
    tvq.total_logical_reads,
    tvq.total_rows,
    tvq.total_spills,
    tvq.last_execution_time,
    DB_NAME(st.dbid)                        AS database_name,
    SUBSTRING(
        st.text,
        (tvq.statement_start_offset / 2) + 1,
        (CASE tvq.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE tvq.statement_end_offset
         END - tvq.statement_start_offset) / 2 + 1
    )                                       AS query_text,
    CASE
        WHEN tvq.total_spills > 0
        THEN 'Table var queries with spills — deferred compilation may help'
        ELSE 'No spills detected'
    END                                     AS deferred_compilation_note,
    'Table variable deferred compilation (NEW 2019)' AS iqp_feature
FROM TableVarQueries AS tvq
CROSS APPLY sys.dm_exec_sql_text(tvq.sql_handle) AS st
ORDER BY tvq.total_cpu_ms DESC;

/* 4b. Check deferred compilation config status */
SELECT
    DB_NAME()                               AS database_name,
    dsc.name                                AS config_name,
    dsc.value                               AS current_value,
    CASE dsc.value
        WHEN 1 THEN 'ON — table variables get actual cardinality at first exec'
        WHEN 0 THEN 'OFF — table variables estimated as 1 row (legacy behavior)'
        ELSE 'Unknown'
    END                                     AS status_description
FROM sys.database_scoped_configurations AS dsc
WHERE dsc.name = 'DEFERRED_COMPILATION_TV';

/*=============================================================================
  Section 5 — Memory Grant Feedback Analysis                           [NEW]
  Row mode memory grant feedback is new in 2019 (batch mode was in 2017).
=============================================================================*/
;WITH MemoryGrantAnalysis AS (
    SELECT
        qs.plan_handle,
        qs.sql_handle,
        qs.statement_start_offset,
        qs.statement_end_offset,
        qs.execution_count,
        qs.total_worker_time / 1000         AS total_cpu_ms,
        qs.total_grant_kb,
        qs.total_used_grant_kb,
        qs.total_ideal_grant_kb,
        qs.total_spills,
        qs.min_grant_kb,
        qs.max_grant_kb,
        qs.last_grant_kb,
        qs.min_used_grant_kb,
        qs.max_used_grant_kb,
        qs.last_used_grant_kb,
        qs.min_spills,
        qs.max_spills,
        qs.last_spills,
        qs.last_execution_time,
        /* Detect grant variation (suggests feedback is active) */
        CASE
            WHEN qs.min_grant_kb <> qs.max_grant_kb
                 AND qs.execution_count >= 3
            THEN 1
            ELSE 0
        END                                 AS grant_feedback_likely,
        /* Over-grant ratio */
        CASE
            WHEN qs.total_grant_kb > 0
            THEN CAST(100.0 * qs.total_used_grant_kb
                       / qs.total_grant_kb AS DECIMAL(5,2))
            ELSE NULL
        END                                 AS grant_utilization_pct,
        /* Wasted memory */
        CASE
            WHEN qs.execution_count > 0
                 AND qs.total_grant_kb > qs.total_used_grant_kb
            THEN (qs.total_grant_kb - qs.total_used_grant_kb)
                 / qs.execution_count
            ELSE 0
        END                                 AS avg_wasted_grant_kb
    FROM sys.dm_exec_query_stats AS qs
    WHERE qs.total_grant_kb > 0
      AND qs.execution_count >= 2
)
SELECT TOP 30
    mga.execution_count,
    mga.total_cpu_ms,
    mga.min_grant_kb,
    mga.max_grant_kb,
    mga.last_grant_kb,
    mga.min_used_grant_kb,
    mga.max_used_grant_kb,
    mga.last_used_grant_kb,
    mga.grant_utilization_pct,
    mga.avg_wasted_grant_kb,
    mga.total_spills,
    mga.min_spills,
    mga.max_spills,
    CASE
        WHEN mga.grant_feedback_likely = 1
             AND mga.total_spills > 0
             AND mga.last_spills = 0
        THEN 'FEEDBACK ACTIVE: spills resolved by grant adjustment'
        WHEN mga.grant_feedback_likely = 1
             AND mga.grant_utilization_pct < 50
             AND mga.max_grant_kb > mga.last_grant_kb
        THEN 'FEEDBACK ACTIVE: over-grant being reduced'
        WHEN mga.grant_feedback_likely = 1
        THEN 'FEEDBACK LIKELY: grant sizes varying across executions'
        WHEN mga.total_spills > 0
        THEN 'CANDIDATE: spills present, feedback may help'
        WHEN mga.grant_utilization_pct < 25
        THEN 'CANDIDATE: severe over-grant, feedback may help'
        ELSE 'STABLE: grant appears appropriate'
    END                                     AS feedback_assessment,
    DB_NAME(st.dbid)                        AS database_name,
    SUBSTRING(
        st.text,
        (mga.statement_start_offset / 2) + 1,
        (CASE mga.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE mga.statement_end_offset
         END - mga.statement_start_offset) / 2 + 1
    )                                       AS query_text,
    'Memory grant feedback (row mode NEW 2019)' AS iqp_feature
FROM MemoryGrantAnalysis AS mga
CROSS APPLY sys.dm_exec_sql_text(mga.sql_handle) AS st
WHERE mga.grant_feedback_likely = 1
   OR mga.total_spills > 0
   OR mga.grant_utilization_pct < 25
ORDER BY
    mga.grant_feedback_likely DESC,
    mga.total_spills DESC,
    mga.avg_wasted_grant_kb DESC;

/*=============================================================================
  Section 6 — IQP Feature Usage Summary (plan cache)                   [NEW]
  Provides a high-level count of IQP features detected in cached plans.
=============================================================================*/
;WITH PlanIQP AS (
    SELECT
        qs.plan_handle,
        qp.query_plan,
        /* Batch mode on rowstore */
        CASE
            WHEN qp.query_plan.exist(
                '//RelOp[@EstimatedExecutionMode="Batch"]'
            ) = 1
            THEN 1 ELSE 0
        END                                 AS has_batch_mode,
        /* Scalar UDF */
        CASE
            WHEN qp.query_plan.exist(
                '//UserDefinedFunction[@IsInlineable="true"]'
            ) = 1
            THEN 1 ELSE 0
        END                                 AS has_inlined_udf,
        /* Adaptive join */
        CASE
            WHEN qp.query_plan.exist(
                '//RelOp[@IsAdaptive="true"]'
            ) = 1
            THEN 1 ELSE 0
        END                                 AS has_adaptive_join,
        /* Memory grant feedback */
        CASE
            WHEN qp.query_plan.exist(
                '//MemoryGrantInfo[@IsMemoryGrantFeedbackAdjusted="Yes"]'
            ) = 1
            THEN 1 ELSE 0
        END                                 AS has_mgf_adjusted
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
    WHERE qp.query_plan IS NOT NULL
)
SELECT
    'Batch Mode on Rowstore (NEW 2019)'     AS iqp_feature,
    SUM(has_batch_mode)                     AS plans_using_feature,
    COUNT(*)                                AS total_cached_plans,
    CAST(100.0 * SUM(has_batch_mode)
         / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))
                                            AS usage_pct

FROM PlanIQP

UNION ALL

SELECT
    'Scalar UDF Inlining (NEW 2019)',
    SUM(has_inlined_udf),
    COUNT(*),
    CAST(100.0 * SUM(has_inlined_udf)
         / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))
FROM PlanIQP

UNION ALL

SELECT
    'Adaptive Joins',
    SUM(has_adaptive_join),
    COUNT(*),
    CAST(100.0 * SUM(has_adaptive_join)
         / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))
FROM PlanIQP

UNION ALL

SELECT
    'Memory Grant Feedback Adjusted',
    SUM(has_mgf_adjusted),
    COUNT(*),
    CAST(100.0 * SUM(has_mgf_adjusted)
         / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))
FROM PlanIQP;

/*=============================================================================
  Section 7 — APPROX_COUNT_DISTINCT Detection                         [NEW]
  Finds queries using the approximate count distinct function.
=============================================================================*/
SELECT
    qs.execution_count,
    qs.total_worker_time / 1000             AS total_cpu_ms,
    qs.total_elapsed_time / 1000            AS total_elapsed_ms,
    qs.total_logical_reads,
    qs.total_rows,
    qs.last_execution_time,
    DB_NAME(st.dbid)                        AS database_name,
    SUBSTRING(
        st.text,
        (qs.statement_start_offset / 2) + 1,
        (CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2 + 1
    )                                       AS query_text,
    'APPROX_COUNT_DISTINCT (NEW 2019)'      AS iqp_feature
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE st.text LIKE '%APPROX_COUNT_DISTINCT%'
ORDER BY qs.total_worker_time DESC;

/*=============================================================================
  Section 8 — Recommendations Summary                                  [NEW]
=============================================================================*/
SELECT
    'Review Compatibility Level' AS recommendation,
    'Databases at compat level < 150 miss all 2019 IQP features' AS detail,
    (SELECT COUNT(*)
     FROM sys.databases
     WHERE compatibility_level < 150
       AND database_id > 4
       AND state = 0)                       AS affected_database_count

UNION ALL

SELECT
    'Enable LAST_QUERY_PLAN_STATS',
    'Enables lightweight profiling to capture last actual execution plan',
    (SELECT COUNT(*)
     FROM sys.database_scoped_configurations
     WHERE name = 'LAST_QUERY_PLAN_STATS'
       AND value = 0)

UNION ALL

SELECT
    'Review Scalar UDF Inlining',
    'Scalar UDFs that are not inlineable may benefit from rewrite',
    (SELECT COUNT(*)
     FROM sys.objects
     WHERE type = 'FN'
       AND OBJECTPROPERTYEX(object_id, 'IsInlineable') = 0)

UNION ALL

SELECT
    'Check Batch Mode on Rowstore Config',
    'BATCH_MODE_ON_ROWSTORE should be ON for analytical queries on rowstore',
    (SELECT COUNT(*)
     FROM sys.database_scoped_configurations
     WHERE name = 'BATCH_MODE_ON_ROWSTORE'
       AND value = 0);
