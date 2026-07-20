/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Query Store Diagnostics
 *
 * Purpose : Analyze Query Store health, regressed queries, forced plans,
 *           and 2025-specific plan feedback.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Query Store Configuration
 *   2. Query Store Space Usage
 *   3. Top Regressed Queries
 *   4. Forced Plans
 *   5. Plan Feedback (NEW in 2025: LAQ Feedback, enhanced CE/DOP feedback)
 *   6. Queries with Multiple Plans (plan instability)
 *   7. Query Store Wait Statistics
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: Query Store Configuration
------------------------------------------------------------------------------*/
SELECT
    DB_NAME()                                       AS database_name,
    actual_state_desc                               AS qs_state,
    desired_state_desc                              AS qs_desired_state,
    readonly_reason,
    current_storage_size_mb,
    max_storage_size_mb,
    CAST(current_storage_size_mb * 100.0
        / NULLIF(max_storage_size_mb, 0) AS DECIMAL(5,2))
                                                    AS storage_pct_used,
    flush_interval_seconds,
    interval_length_minutes                         AS stats_interval_minutes,
    stale_query_threshold_days,
    max_plans_per_query,
    query_capture_mode_desc                         AS capture_mode,
    size_based_cleanup_mode_desc                    AS cleanup_mode,
    wait_stats_capture_mode_desc                    AS wait_stats_capture
FROM sys.database_query_store_options;

/*------------------------------------------------------------------------------
  Section 2: Query Store Space Usage
------------------------------------------------------------------------------*/
SELECT
    COUNT(DISTINCT qsp.query_id)                    AS total_queries,
    COUNT(DISTINCT qsp.plan_id)                     AS total_plans,
    COUNT(*)                                        AS total_runtime_stats,
    SUM(CASE WHEN qsp.is_forced_plan = 1 THEN 1 ELSE 0 END)
                                                    AS forced_plan_count,
    (SELECT current_storage_size_mb
     FROM sys.database_query_store_options)          AS current_size_mb,
    (SELECT max_storage_size_mb
     FROM sys.database_query_store_options)          AS max_size_mb
FROM sys.query_store_plan AS qsp
LEFT JOIN sys.query_store_runtime_stats AS qsrs
    ON qsp.plan_id = qsrs.plan_id;

/*------------------------------------------------------------------------------
  Section 3: Top Regressed Queries
  Queries where recent performance is worse than historical average.
------------------------------------------------------------------------------*/
;WITH query_perf AS (
    SELECT
        qsp.query_id,
        qsp.plan_id,
        qsrs.avg_duration / 1000                    AS avg_duration_ms,
        qsrs.avg_cpu_time / 1000                    AS avg_cpu_ms,
        qsrs.avg_logical_io_reads                   AS avg_logical_reads,
        qsrs.count_executions                       AS exec_count,
        qsrs.first_execution_time,
        qsrs.last_execution_time,
        ROW_NUMBER() OVER (
            PARTITION BY qsp.query_id
            ORDER BY qsrs.last_execution_time DESC
        )                                           AS rn
    FROM sys.query_store_plan AS qsp
    INNER JOIN sys.query_store_runtime_stats AS qsrs
        ON qsp.plan_id = qsrs.plan_id
    WHERE qsrs.count_executions > 1
),
historical AS (
    SELECT
        query_id,
        AVG(avg_duration_ms)                        AS hist_avg_duration_ms,
        AVG(avg_cpu_ms)                             AS hist_avg_cpu_ms
    FROM query_perf
    WHERE rn > 1
    GROUP BY query_id
)
SELECT TOP (25)
    r.query_id,
    r.plan_id,
    r.avg_duration_ms                               AS recent_avg_duration_ms,
    h.hist_avg_duration_ms,
    CAST((r.avg_duration_ms - h.hist_avg_duration_ms) * 100.0
        / NULLIF(h.hist_avg_duration_ms, 0) AS DECIMAL(10,2))
                                                    AS duration_regression_pct,
    r.avg_cpu_ms                                    AS recent_avg_cpu_ms,
    h.hist_avg_cpu_ms,
    r.exec_count                                    AS recent_exec_count,
    r.last_execution_time,
    qsqt.query_sql_text
FROM query_perf AS r
INNER JOIN historical AS h
    ON r.query_id = h.query_id
INNER JOIN sys.query_store_query AS qsq
    ON r.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
WHERE r.rn = 1
  AND r.avg_duration_ms > h.hist_avg_duration_ms * 1.5
ORDER BY duration_regression_pct DESC;

/*------------------------------------------------------------------------------
  Section 4: Forced Plans
------------------------------------------------------------------------------*/
SELECT
    qsp.plan_id,
    qsp.query_id,
    qsp.is_forced_plan,
    qsp.force_failure_count,
    qsp.last_force_failure_reason_desc              AS last_failure_reason,
    qsp.plan_forcing_type_desc                      AS forcing_type,
    qsp.count_compiles,
    qsp.last_compile_start_time,
    qsqt.query_sql_text,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.avg_cpu_time / 1000                        AS avg_cpu_ms,
    qsrs.count_executions
FROM sys.query_store_plan AS qsp
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
LEFT JOIN sys.query_store_runtime_stats AS qsrs
    ON qsp.plan_id = qsrs.plan_id
WHERE qsp.is_forced_plan = 1
ORDER BY qsp.force_failure_count DESC;

/*------------------------------------------------------------------------------
  Section 5: Plan Feedback -- NEW in 2025
  sys.query_store_plan_feedback stores feedback from:
    - feature_id 1: Memory Grant Feedback
    - feature_id 2: CE Feedback
    - feature_id 3: DOP Feedback
    - feature_id 4: LAQ Feedback (NEW in 2025)
  LAQ Feedback tracks whether Lock After Qualification was disabled for a plan.
------------------------------------------------------------------------------*/
SELECT
    pf.plan_id,
    qsp.query_id,
    pf.feature_id,
    pf.feature_desc,                                                           -- NEW in 2025: includes 'LAQ Feedback'
    pf.feedback_data,
    pf.state_desc                                   AS feedback_state,
    qsqt.query_sql_text,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.avg_cpu_time / 1000                        AS avg_cpu_ms,
    qsrs.count_executions
FROM sys.query_store_plan_feedback AS pf
INNER JOIN sys.query_store_plan AS qsp
    ON pf.plan_id = qsp.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
LEFT JOIN sys.query_store_runtime_stats AS qsrs
    ON qsp.plan_id = qsrs.plan_id
ORDER BY pf.feature_id, pf.plan_id;

/*------------------------------------------------------------------------------
  Section 6: Queries with Multiple Plans (plan instability)
------------------------------------------------------------------------------*/
;WITH multi_plan AS (
    SELECT
        query_id,
        COUNT(DISTINCT plan_id)                     AS plan_count
    FROM sys.query_store_plan
    GROUP BY query_id
    HAVING COUNT(DISTINCT plan_id) > 1
)
SELECT TOP (25)
    mp.query_id,
    mp.plan_count,
    qsqt.query_sql_text,
    qsq.avg_compile_duration / 1000                 AS avg_compile_ms,
    qsq.last_compile_start_time,
    STRING_AGG(CAST(qsp.plan_id AS VARCHAR(10)), ', ')
                                                    AS plan_ids
FROM multi_plan AS mp
INNER JOIN sys.query_store_query AS qsq
    ON mp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
INNER JOIN sys.query_store_plan AS qsp
    ON mp.query_id = qsp.query_id
GROUP BY mp.query_id, mp.plan_count,
         qsqt.query_sql_text,
         qsq.avg_compile_duration,
         qsq.last_compile_start_time
ORDER BY mp.plan_count DESC;

/*------------------------------------------------------------------------------
  Section 7: Query Store Wait Statistics
  Per-query wait breakdown from Query Store.
------------------------------------------------------------------------------*/
SELECT TOP (25)
    qsws.plan_id,
    qsp.query_id,
    qsws.wait_category_desc,
    qsws.avg_query_wait_time_ms,
    qsws.total_query_wait_time_ms,
    qsqt.query_sql_text,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.count_executions
FROM sys.query_store_wait_stats AS qsws
INNER JOIN sys.query_store_plan AS qsp
    ON qsws.plan_id = qsp.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
LEFT JOIN sys.query_store_runtime_stats AS qsrs
    ON qsws.plan_id = qsrs.plan_id
   AND qsws.runtime_stats_interval_id = qsrs.runtime_stats_interval_id
WHERE qsws.total_query_wait_time_ms > 0
ORDER BY qsws.total_query_wait_time_ms DESC;
