/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Query Store Comprehensive Analysis
 *
 * Purpose : Full Query Store diagnostics with 2022 enhancements.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * MAJOR ENHANCEMENTS for 2022:
 *   - PSP Optimization Analysis (dispatcher + variant plans)
 *   - Plan Feedback Tracking (CE, DOP, Memory Grant Percentile)
 *   - Query Store Hints (sys.query_store_hints)
 *   - Optimized Plan Forcing
 *   - Query Store on Secondary Replica Status
 *
 * Sections:
 *   1.  Query Store Configuration & Status
 *   2.  Query Store on Secondary Replica Status (NEW in 2022)
 *   3.  Query Store Space Usage
 *   4.  Regressed Queries (Plan Regression Detection)
 *   5.  PSP Optimization Analysis (NEW in 2022)
 *   6.  Plan Feedback Tracking (NEW in 2022)
 *   7.  Query Store Hints (NEW in 2022)
 *   8.  Optimized Plan Forcing (NEW in 2022)
 *   9.  Forced Plans & Effectiveness
 *   10. Top Queries by Variability (Plan Choice Instability)
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: Query Store Configuration & Status
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    actual_state_desc                               AS qs_state,
    desired_state_desc                              AS qs_desired_state,
    readonly_reason,
    current_storage_size_mb,
    max_storage_size_mb,
    CAST(current_storage_size_mb * 100.0
        / NULLIF(max_storage_size_mb, 0) AS DECIMAL(5,2))
                                                    AS storage_used_pct,
    flush_interval_seconds / 60                     AS flush_interval_min,
    interval_length_minutes                         AS stats_aggregation_interval_min,
    stale_query_threshold_days,
    max_plans_per_query,
    query_capture_mode_desc                         AS capture_mode,
    size_based_cleanup_mode_desc                    AS cleanup_mode,
    wait_stats_capture_mode_desc                    AS wait_stats_capture
FROM sys.database_query_store_options;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: Query Store on Secondary Replica Status — NEW in 2022
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    name                                            AS config_name,
    value                                           AS config_value,
    value_for_secondary                             AS value_for_secondary
FROM sys.database_scoped_configurations
WHERE name = 'QUERY_STORE_FOR_SECONDARY';                                       -- NEW in 2022

-- Check if this is a secondary replica
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        DB_NAME()                                   AS database_name,
        drs.is_primary_replica,
        drs.is_local,
        CASE
            WHEN drs.is_primary_replica = 0 THEN 'Secondary Replica'
            WHEN drs.is_primary_replica = 1 THEN 'Primary Replica'
            ELSE 'Unknown'
        END                                         AS replica_role,
        'Query Store on secondaries captures queries executed against this replica.' AS note  -- NEW in 2022
    FROM sys.dm_hadr_database_replica_states AS drs
    WHERE drs.database_id = DB_ID()
      AND drs.is_local = 1;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: Query Store Space Usage
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    (SELECT COUNT(*) FROM sys.query_store_query)        AS total_queries,
    (SELECT COUNT(*) FROM sys.query_store_plan)         AS total_plans,
    (SELECT COUNT(*) FROM sys.query_store_query_text)   AS total_query_texts,
    (SELECT COUNT(*) FROM sys.query_store_runtime_stats) AS total_runtime_stats_rows,
    (SELECT current_storage_size_mb FROM sys.database_query_store_options)
                                                        AS current_size_mb,
    (SELECT max_storage_size_mb FROM sys.database_query_store_options)
                                                        AS max_size_mb;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Regressed Queries (Plan Regression Detection)
  Queries whose recent performance is significantly worse than historical.
──────────────────────────────────────────────────────────────────────────────*/
;WITH recent_stats AS (
    SELECT
        p.query_id,
        p.plan_id,
        SUM(rs.count_executions)                    AS recent_exec_count,
        AVG(rs.avg_duration)                        AS recent_avg_duration,
        AVG(rs.avg_cpu_time)                        AS recent_avg_cpu,
        AVG(rs.avg_logical_io_reads)                AS recent_avg_reads
    FROM sys.query_store_runtime_stats AS rs
    INNER JOIN sys.query_store_plan AS p
        ON rs.plan_id = p.plan_id
    WHERE rs.last_execution_time > DATEADD(HOUR, -4, GETUTCDATE())
    GROUP BY p.query_id, p.plan_id
),
historical_stats AS (
    SELECT
        p.query_id,
        p.plan_id,
        SUM(rs.count_executions)                    AS hist_exec_count,
        AVG(rs.avg_duration)                        AS hist_avg_duration,
        AVG(rs.avg_cpu_time)                        AS hist_avg_cpu,
        AVG(rs.avg_logical_io_reads)                AS hist_avg_reads
    FROM sys.query_store_runtime_stats AS rs
    INNER JOIN sys.query_store_plan AS p
        ON rs.plan_id = p.plan_id
    WHERE rs.last_execution_time BETWEEN DATEADD(DAY, -7, GETUTCDATE())
                                     AND DATEADD(HOUR, -4, GETUTCDATE())
    GROUP BY p.query_id, p.plan_id
)
SELECT TOP (25)
    r.query_id,
    r.plan_id,
    qt.query_sql_text,
    h.hist_avg_duration / 1000.0                    AS hist_avg_duration_ms,
    r.recent_avg_duration / 1000.0                  AS recent_avg_duration_ms,
    CAST(r.recent_avg_duration * 1.0
        / NULLIF(h.hist_avg_duration, 0) AS DECIMAL(10,2))
                                                    AS duration_regression_factor,
    h.hist_avg_cpu / 1000.0                         AS hist_avg_cpu_ms,
    r.recent_avg_cpu / 1000.0                       AS recent_avg_cpu_ms,
    r.recent_exec_count,
    h.hist_exec_count
FROM recent_stats AS r
INNER JOIN historical_stats AS h
    ON r.query_id = h.query_id
   AND r.plan_id  = h.plan_id
INNER JOIN sys.query_store_query AS q
    ON r.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
WHERE h.hist_avg_duration > 0
  AND r.recent_avg_duration > h.hist_avg_duration * 2  -- 2x regression threshold
  AND r.recent_exec_count >= 5                          -- minimum executions
ORDER BY (r.recent_avg_duration - h.hist_avg_duration) * r.recent_exec_count DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: PSP Optimization Analysis — NEW in 2022
  Parameter Sensitive Plan optimization creates dispatcher plans that route
  to variant plans based on parameter cardinality ranges.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (
    SELECT 1 FROM sys.all_objects WHERE name = 'query_store_query_variant'
)
BEGIN
    -- 5a. Dispatcher plan summary
    SELECT
        p.query_id                                  AS dispatcher_query_id,
        p.plan_id                                   AS dispatcher_plan_id,
        p.plan_type_desc,                                                       -- NEW in 2022
        COUNT(DISTINCT qv.query_variant_query_id)   AS variant_count,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM sys.query_store_plan AS p
    INNER JOIN sys.query_store_query AS q
        ON p.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    LEFT JOIN sys.query_store_query_variant AS qv                               -- NEW in 2022
        ON qv.parent_query_id = q.query_id
    WHERE p.plan_type_desc = 'Dispatcher'                                       -- NEW in 2022
    GROUP BY p.query_id, p.plan_id, p.plan_type_desc, qt.query_sql_text
    ORDER BY variant_count DESC;

    -- 5b. Variant plan performance comparison
    ;WITH variant_perf AS (
        SELECT
            qv.parent_query_id,
            qv.query_variant_query_id,
            p.plan_id,
            p.plan_type_desc,
            rs.count_executions,
            rs.avg_duration / 1000.0                AS avg_duration_ms,
            rs.avg_cpu_time / 1000.0                AS avg_cpu_ms,
            rs.avg_logical_io_reads,
            rs.avg_physical_io_reads,
            rs.avg_rowcount,
            rs.avg_query_max_used_memory,
            rs.first_execution_time,
            rs.last_execution_time
        FROM sys.query_store_query_variant AS qv                                -- NEW in 2022
        INNER JOIN sys.query_store_plan AS p
            ON p.query_id = qv.query_variant_query_id
        INNER JOIN sys.query_store_runtime_stats AS rs
            ON rs.plan_id = p.plan_id
        WHERE rs.last_execution_time > DATEADD(HOUR, -24, GETUTCDATE())
    )
    SELECT TOP (50)
        vp.parent_query_id                          AS dispatcher_query_id,
        vp.query_variant_query_id                   AS variant_query_id,
        vp.plan_id                                  AS variant_plan_id,
        vp.plan_type_desc,
        vp.count_executions,
        vp.avg_duration_ms,
        vp.avg_cpu_ms,
        vp.avg_logical_io_reads,
        vp.avg_physical_io_reads,
        vp.avg_rowcount,
        vp.avg_query_max_used_memory,
        LEFT(qt.query_sql_text, 200)                AS sql_text_preview
    FROM variant_perf AS vp
    INNER JOIN sys.query_store_query AS q
        ON vp.query_variant_query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    ORDER BY vp.parent_query_id, vp.avg_duration_ms;
END
ELSE
BEGIN
    SELECT 'PSP analysis requires sys.query_store_query_variant (SQL Server 2022+).' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 6: Plan Feedback Tracking — NEW in 2022
  sys.query_store_plan_feedback tracks CE feedback, DOP feedback,
  and memory grant percentile feedback.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (
    SELECT 1 FROM sys.all_objects WHERE name = 'query_store_plan_feedback'
)
BEGIN
    -- 6a. Feedback summary by type
    SELECT
        pf.feature_desc                             AS feedback_type,           -- NEW in 2022
        pf.state_desc                               AS feedback_state,          -- NEW in 2022
        COUNT(*)                                    AS feedback_count
    FROM sys.query_store_plan_feedback AS pf                                    -- NEW in 2022
    GROUP BY pf.feature_desc, pf.state_desc
    ORDER BY pf.feature_desc, pf.state_desc;

    -- 6b. CE Feedback details
    SELECT TOP (25)
        pf.plan_feedback_id,
        pf.plan_id,
        p.query_id,
        pf.feature_desc,                                                        -- NEW in 2022
        pf.feedback_data,                                                       -- NEW in 2022
        pf.state_desc                               AS feedback_state,
        pf.create_time,
        pf.last_updated_time,
        rs.count_executions                         AS recent_exec_count,
        rs.avg_duration / 1000.0                    AS avg_duration_ms,
        rs.avg_cpu_time / 1000.0                    AS avg_cpu_ms,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM sys.query_store_plan_feedback AS pf                                    -- NEW in 2022
    INNER JOIN sys.query_store_plan AS p
        ON pf.plan_id = p.plan_id
    INNER JOIN sys.query_store_query AS q
        ON p.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    LEFT JOIN sys.query_store_runtime_stats AS rs
        ON rs.plan_id = p.plan_id
    WHERE pf.feature_desc = 'CE'                                                -- NEW in 2022
    ORDER BY pf.last_updated_time DESC;

    -- 6c. DOP Feedback details
    SELECT TOP (25)
        pf.plan_feedback_id,
        pf.plan_id,
        p.query_id,
        pf.feature_desc,
        pf.feedback_data,                           -- Contains adjusted DOP value
        pf.state_desc                               AS feedback_state,
        pf.create_time,
        pf.last_updated_time,
        rs.count_executions                         AS recent_exec_count,
        rs.avg_duration / 1000.0                    AS avg_duration_ms,
        rs.avg_cpu_time / 1000.0                    AS avg_cpu_ms,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM sys.query_store_plan_feedback AS pf                                    -- NEW in 2022
    INNER JOIN sys.query_store_plan AS p
        ON pf.plan_id = p.plan_id
    INNER JOIN sys.query_store_query AS q
        ON p.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    LEFT JOIN sys.query_store_runtime_stats AS rs
        ON rs.plan_id = p.plan_id
    WHERE pf.feature_desc = 'DOP'                                               -- NEW in 2022
    ORDER BY pf.last_updated_time DESC;

    -- 6d. Memory Grant Percentile Feedback details
    SELECT TOP (25)
        pf.plan_feedback_id,
        pf.plan_id,
        p.query_id,
        pf.feature_desc,
        pf.feedback_data,                           -- Contains adjusted memory grant
        pf.state_desc                               AS feedback_state,
        pf.create_time,
        pf.last_updated_time,
        rs.count_executions                         AS recent_exec_count,
        rs.avg_query_max_used_memory                AS avg_max_used_memory,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM sys.query_store_plan_feedback AS pf                                    -- NEW in 2022
    INNER JOIN sys.query_store_plan AS p
        ON pf.plan_id = p.plan_id
    INNER JOIN sys.query_store_query AS q
        ON p.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    LEFT JOIN sys.query_store_runtime_stats AS rs
        ON rs.plan_id = p.plan_id
    WHERE pf.feature_desc = 'MGF_PERCENTILE'                                    -- NEW in 2022
    ORDER BY pf.last_updated_time DESC;
END
ELSE
BEGIN
    SELECT 'Plan feedback tracking requires sys.query_store_plan_feedback (SQL Server 2022+).' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 7: Query Store Hints — NEW in 2022
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (
    SELECT 1 FROM sys.all_objects WHERE name = 'query_store_hints'
)
BEGIN
    SELECT
        qsh.query_hint_id,
        qsh.query_id,
        qsh.query_hint_text                         AS hint_text,               -- NEW in 2022
        qsh.source_desc                             AS hint_source,             -- NEW in 2022
        qsh.last_query_hint_failure_reason_desc     AS last_failure_reason,     -- NEW in 2022
        qsh.query_hint_failure_count                AS failure_count,           -- NEW in 2022
        qsh.comment                                 AS hint_comment,            -- NEW in 2022
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM sys.query_store_hints AS qsh                                           -- NEW in 2022
    INNER JOIN sys.query_store_query AS q
        ON qsh.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    ORDER BY qsh.query_id;
END
ELSE
BEGIN
    SELECT 'Query Store hints require sys.query_store_hints (SQL Server 2022+).' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 8: Optimized Plan Forcing — NEW in 2022
  When a forced plan is optimized, the compilation step stores the optimized
  compilation stub. Check for plans using this feature.
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    p.plan_id,
    p.query_id,
    p.plan_type_desc,                                                           -- NEW in 2022
    p.is_forced_plan,
    p.has_compile_replay_script,                                                -- NEW in 2022: optimized forcing indicator
    p.is_optimized_plan_forcing_disabled,                                       -- NEW in 2022
    rs.count_executions                             AS recent_exec_count,
    rs.avg_duration / 1000.0                        AS avg_duration_ms,
    rs.avg_compile_duration / 1000.0                AS avg_compile_duration_ms,
    LEFT(qt.query_sql_text, 300)                    AS sql_text_preview
FROM sys.query_store_plan AS p
INNER JOIN sys.query_store_query AS q
    ON p.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
LEFT JOIN sys.query_store_runtime_stats AS rs
    ON rs.plan_id = p.plan_id
WHERE p.is_forced_plan = 1
ORDER BY rs.count_executions DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 9: Forced Plans & Effectiveness
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    p.plan_id,
    p.query_id,
    p.plan_type_desc,
    p.force_failure_count,
    p.last_force_failure_reason_desc                AS last_failure_reason,
    p.is_forced_plan,
    p.has_compile_replay_script,                                                -- NEW in 2022
    rs.count_executions                             AS total_exec_count,
    rs.avg_duration / 1000.0                        AS avg_duration_ms,
    rs.avg_cpu_time / 1000.0                        AS avg_cpu_ms,
    rs.avg_logical_io_reads                         AS avg_logical_reads,
    rs.first_execution_time,
    rs.last_execution_time,
    LEFT(qt.query_sql_text, 300)                    AS sql_text_preview
FROM sys.query_store_plan AS p
INNER JOIN sys.query_store_query AS q
    ON p.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
LEFT JOIN sys.query_store_runtime_stats AS rs
    ON rs.plan_id = p.plan_id
WHERE p.is_forced_plan = 1
ORDER BY p.force_failure_count DESC, rs.count_executions DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 10: Top Queries by Variability (Plan Choice Instability)
  Queries with high standard deviation in execution duration.
──────────────────────────────────────────────────────────────────────────────*/
;WITH query_variability AS (
    SELECT
        p.query_id,
        COUNT(DISTINCT p.plan_id)                   AS plan_count,
        SUM(rs.count_executions)                    AS total_exec_count,
        AVG(rs.avg_duration)                        AS overall_avg_duration,
        MIN(rs.avg_duration)                        AS min_avg_duration,
        MAX(rs.avg_duration)                        AS max_avg_duration,
        STDEV(rs.avg_duration)                      AS stdev_duration
    FROM sys.query_store_runtime_stats AS rs
    INNER JOIN sys.query_store_plan AS p
        ON rs.plan_id = p.plan_id
    WHERE rs.last_execution_time > DATEADD(DAY, -7, GETUTCDATE())
    GROUP BY p.query_id
    HAVING COUNT(DISTINCT p.plan_id) > 1
       AND SUM(rs.count_executions) >= 10
)
SELECT TOP (25)
    qv.query_id,
    qv.plan_count,
    qv.total_exec_count,
    qv.overall_avg_duration / 1000.0                AS avg_duration_ms,
    qv.min_avg_duration / 1000.0                    AS min_plan_avg_ms,
    qv.max_avg_duration / 1000.0                    AS max_plan_avg_ms,
    qv.stdev_duration / 1000.0                      AS stdev_duration_ms,
    CAST(qv.stdev_duration * 100.0
        / NULLIF(qv.overall_avg_duration, 0) AS DECIMAL(10,2))
                                                    AS coefficient_of_variation_pct,
    LEFT(qt.query_sql_text, 300)                    AS sql_text_preview
FROM query_variability AS qv
INNER JOIN sys.query_store_query AS q
    ON qv.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
ORDER BY qv.stdev_duration DESC;
