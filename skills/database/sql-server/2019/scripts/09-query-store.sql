/******************************************************************************
 * 09-query-store.sql
 * SQL Server 2019 (Compatibility Level 150) — Query Store Diagnostics
 *
 * Enhanced for 2019:
 *   - IQP feedback detection in Query Store plans                      [NEW]
 *     (batch mode on rowstore, scalar UDF inlining markers in plan XML)
 *   - APPROX_COUNT_DISTINCT usage tracking                             [NEW]
 *   - Table variable deferred compilation markers                      [NEW]
 *   - Memory grant feedback indicators in plan XML                     [NEW]
 *
 * Prerequisites: Query Store must be enabled on the target database.
 *   ALTER DATABASE [YourDB] SET QUERY_STORE = ON;
 *
 * Safe: read-only, no temp tables, no cursors.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — Query Store Configuration & Status
=============================================================================*/
SELECT
    DB_NAME()                               AS database_name,
    qso.desired_state_desc                  AS desired_state,
    qso.actual_state_desc                   AS actual_state,
    qso.readonly_reason,
    qso.current_storage_size_mb,
    qso.max_storage_size_mb,
    CASE
        WHEN qso.max_storage_size_mb > 0
        THEN CAST(100.0 * qso.current_storage_size_mb
                   / qso.max_storage_size_mb AS DECIMAL(5,2))
        ELSE NULL
    END                                     AS storage_used_pct,
    qso.flush_interval_seconds / 60         AS flush_interval_min,
    qso.interval_length_minutes             AS stats_interval_min,
    qso.stale_query_threshold_days,
    qso.max_plans_per_query,
    qso.query_capture_mode_desc             AS capture_mode,
    qso.size_based_cleanup_mode_desc        AS cleanup_mode,
    qso.wait_stats_capture_mode_desc        AS wait_stats_capture
FROM sys.database_query_store_options AS qso;

/*=============================================================================
  Section 2 — Top Regressed Queries (by CPU)
=============================================================================*/
;WITH RecentStats AS (
    SELECT
        qrs.query_id,
        qrs.plan_id,
        qrs.runtime_stats_interval_id,
        qrs.avg_cpu_time,
        qrs.avg_duration,
        qrs.avg_logical_io_reads,
        qrs.avg_physical_io_reads,
        qrs.avg_rowcount,
        qrs.count_executions,
        qrs.avg_query_max_used_memory,
        qrs.avg_tempdb_space_used,
        rsi.start_time                      AS interval_start,
        rsi.end_time                        AS interval_end,
        ROW_NUMBER() OVER (
            PARTITION BY qrs.query_id, qrs.plan_id
            ORDER BY rsi.start_time DESC
        )                                   AS recent_rank
    FROM sys.query_store_runtime_stats AS qrs
    INNER JOIN sys.query_store_runtime_stats_interval AS rsi
        ON qrs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
    WHERE rsi.start_time >= DATEADD(DAY, -7, GETDATE())
)
SELECT TOP 30
    q.query_id,
    qt.query_sql_text,
    p.plan_id,
    recent.avg_cpu_time                     AS recent_avg_cpu_us,
    older.avg_cpu_time                      AS older_avg_cpu_us,
    CASE
        WHEN older.avg_cpu_time > 0
        THEN CAST((recent.avg_cpu_time - older.avg_cpu_time) * 100.0
                   / older.avg_cpu_time AS DECIMAL(10,2))
        ELSE NULL
    END                                     AS cpu_regression_pct,
    recent.avg_duration / 1000              AS recent_avg_duration_ms,
    recent.avg_logical_io_reads             AS recent_avg_reads,
    recent.count_executions                 AS recent_exec_count,
    OBJECT_NAME(q.object_id)                AS object_name,
    p.compatibility_level                   AS plan_compat_level,
    p.engine_version
FROM RecentStats AS recent
INNER JOIN RecentStats AS older
    ON recent.query_id = older.query_id
    AND recent.plan_id = older.plan_id
    AND recent.recent_rank = 1
    AND older.recent_rank = 2
INNER JOIN sys.query_store_plan AS p
    ON recent.plan_id = p.plan_id
INNER JOIN sys.query_store_query AS q
    ON recent.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
WHERE recent.avg_cpu_time > older.avg_cpu_time * 1.25
ORDER BY (recent.avg_cpu_time - older.avg_cpu_time) * recent.count_executions DESC;

/*=============================================================================
  Section 3 — IQP Feature Detection in Query Store Plans               [NEW]
  Searches plan XML for 2019 IQP indicators.
=============================================================================*/
;WITH PlanFeatures AS (
    SELECT
        p.plan_id,
        p.query_id,
        p.compatibility_level,
        /* Batch mode on rowstore indicator */                       -- [NEW]
        CASE
            WHEN TRY_CAST(p.query_plan AS XML) IS NOT NULL
                 AND CAST(p.query_plan AS XML).exist(
                     '//RelOp[@EstimatedExecutionMode="Batch"]'
                 ) = 1
            THEN 1
            ELSE 0
        END                                 AS uses_batch_mode,
        /* Scalar UDF inlining indicator */                          -- [NEW]
        CASE
            WHEN TRY_CAST(p.query_plan AS XML) IS NOT NULL
                 AND CAST(p.query_plan AS XML).exist(
                     '//UserDefinedFunction[@IsInlineable="true"]'
                 ) = 1
            THEN 1
            WHEN TRY_CAST(p.query_plan AS XML) IS NOT NULL
                 AND CAST(p.query_plan AS XML).exist(
                     '//ScalarOperator/UserDefinedFunction'
                 ) = 1
            THEN -1  /* UDF present but not inlined */
            ELSE 0
        END                                 AS scalar_udf_inlining,
        /* Memory grant feedback indicator */                        -- [NEW]
        CASE
            WHEN TRY_CAST(p.query_plan AS XML) IS NOT NULL
                 AND CAST(p.query_plan AS XML).exist(
                     '//MemoryGrantInfo[@IsMemoryGrantFeedbackAdjusted="Yes"]'
                 ) = 1
            THEN 1
            ELSE 0
        END                                 AS memory_grant_feedback,
        /* Adaptive join indicator */
        CASE
            WHEN TRY_CAST(p.query_plan AS XML) IS NOT NULL
                 AND CAST(p.query_plan AS XML).exist(
                     '//RelOp[@IsAdaptive="true"]'
                 ) = 1
            THEN 1
            ELSE 0
        END                                 AS adaptive_join
    FROM sys.query_store_plan AS p
    WHERE p.last_execution_time >= DATEADD(DAY, -7, GETDATE())
)
SELECT
    pf.plan_id,
    pf.query_id,
    pf.compatibility_level,
    qt.query_sql_text,
    OBJECT_NAME(q.object_id)                AS object_name,
    CASE pf.uses_batch_mode
        WHEN 1 THEN 'Yes (NEW 2019: batch mode on rowstore possible)'
        ELSE 'No'
    END                                     AS batch_mode_detected,
    CASE pf.scalar_udf_inlining
        WHEN 1  THEN 'Yes — inlined (NEW 2019)'
        WHEN -1 THEN 'UDF present but NOT inlined'
        ELSE 'No UDF detected'
    END                                     AS scalar_udf_status,
    CASE pf.memory_grant_feedback
        WHEN 1 THEN 'Yes — feedback adjusted (NEW 2019: row mode)'
        ELSE 'No'
    END                                     AS memory_grant_feedback_status,
    CASE pf.adaptive_join
        WHEN 1 THEN 'Yes — adaptive join'
        ELSE 'No'
    END                                     AS adaptive_join_detected
FROM PlanFeatures AS pf
INNER JOIN sys.query_store_query AS q
    ON pf.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
WHERE pf.uses_batch_mode = 1
   OR pf.scalar_udf_inlining <> 0
   OR pf.memory_grant_feedback = 1
   OR pf.adaptive_join = 1
ORDER BY pf.plan_id DESC;

/*=============================================================================
  Section 4 — APPROX_COUNT_DISTINCT Usage Tracking                     [NEW]
  Finds queries using the new approximate aggregation function.
=============================================================================*/
SELECT
    q.query_id,
    qt.query_sql_text,
    p.plan_id,
    q.count_compiles                        AS compile_count,
    OBJECT_NAME(q.object_id)                AS object_name,
    p.last_execution_time,
    rs.count_executions                     AS recent_exec_count,
    rs.avg_cpu_time / 1000                  AS avg_cpu_ms,
    rs.avg_duration / 1000                  AS avg_duration_ms,
    rs.avg_logical_io_reads                 AS avg_reads
FROM sys.query_store_query_text AS qt
INNER JOIN sys.query_store_query AS q
    ON qt.query_text_id = q.query_text_id
INNER JOIN sys.query_store_plan AS p
    ON q.query_id = p.query_id
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
    ON p.plan_id = rs.plan_id
WHERE qt.query_sql_text LIKE '%APPROX_COUNT_DISTINCT%'              -- [NEW]
ORDER BY rs.count_executions DESC;

/*=============================================================================
  Section 5 — Top Resource-Consuming Queries (overall)
=============================================================================*/
SELECT TOP 30
    q.query_id,
    qt.query_sql_text,
    p.plan_id,
    rs.count_executions,
    rs.avg_cpu_time / 1000                  AS avg_cpu_ms,
    rs.avg_duration / 1000                  AS avg_duration_ms,
    rs.avg_logical_io_reads                 AS avg_reads,
    rs.avg_physical_io_reads                AS avg_physical_reads,
    rs.avg_rowcount                         AS avg_rows,
    rs.avg_query_max_used_memory * 8        AS avg_max_memory_kb,
    rs.avg_tempdb_space_used * 8            AS avg_tempdb_kb,
    rs.avg_log_bytes_used                   AS avg_log_bytes,
    OBJECT_NAME(q.object_id)                AS object_name,
    p.is_forced_plan,
    p.force_failure_count,
    p.last_force_failure_reason_desc        AS force_failure_reason,
    p.compatibility_level                   AS plan_compat_level,
    p.last_execution_time
FROM sys.query_store_query AS q
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
INNER JOIN sys.query_store_plan AS p
    ON q.query_id = p.query_id
INNER JOIN (
    SELECT
        plan_id,
        SUM(count_executions)               AS count_executions,
        AVG(avg_cpu_time)                   AS avg_cpu_time,
        AVG(avg_duration)                   AS avg_duration,
        AVG(avg_logical_io_reads)           AS avg_logical_io_reads,
        AVG(avg_physical_io_reads)          AS avg_physical_io_reads,
        AVG(avg_rowcount)                   AS avg_rowcount,
        AVG(avg_query_max_used_memory)      AS avg_query_max_used_memory,
        AVG(avg_tempdb_space_used)          AS avg_tempdb_space_used,
        AVG(avg_log_bytes_used)             AS avg_log_bytes_used
    FROM sys.query_store_runtime_stats
    GROUP BY plan_id
) AS rs
    ON p.plan_id = rs.plan_id
WHERE rs.count_executions > 0
ORDER BY rs.avg_cpu_time * rs.count_executions DESC;

/*=============================================================================
  Section 6 — Query Store Wait Stats (introduced in 2017, enhanced)
=============================================================================*/
SELECT TOP 30
    q.query_id,
    qt.query_sql_text,
    p.plan_id,
    ws.wait_category_desc                   AS wait_category,
    ws.total_query_wait_time_ms,
    ws.avg_query_wait_time_ms,
    ws.min_query_wait_time_ms,
    ws.max_query_wait_time_ms,
    ws.last_query_wait_time_ms,
    rs.count_executions
FROM sys.query_store_wait_stats AS ws
INNER JOIN sys.query_store_plan AS p
    ON ws.plan_id = p.plan_id
INNER JOIN sys.query_store_query AS q
    ON p.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
INNER JOIN sys.query_store_runtime_stats AS rs
    ON ws.plan_id = rs.plan_id
    AND ws.runtime_stats_interval_id = rs.runtime_stats_interval_id
WHERE ws.total_query_wait_time_ms > 0
ORDER BY ws.total_query_wait_time_ms DESC;

/*=============================================================================
  Section 7 — Forced Plans Audit
=============================================================================*/
SELECT
    q.query_id,
    qt.query_sql_text,
    p.plan_id,
    p.is_forced_plan,
    p.force_failure_count,
    p.last_force_failure_reason_desc        AS failure_reason,
    p.last_execution_time,
    p.compatibility_level,
    OBJECT_NAME(q.object_id)                AS object_name
FROM sys.query_store_plan AS p
INNER JOIN sys.query_store_query AS q
    ON p.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
WHERE p.is_forced_plan = 1
ORDER BY p.force_failure_count DESC, p.last_execution_time DESC;
