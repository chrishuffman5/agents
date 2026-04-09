/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Intelligent Query Processing Diagnostics
 *
 * Purpose : MAJOR enhancement for 2022 IQP features. Detailed analysis of
 *           PSP variants, DOP feedback, CE feedback, memory grant percentile
 *           feedback, and optimized plan forcing.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * NEW in 2022 Sections:
 *   1.  IQP Feature Enablement Summary
 *   2.  PSP Plan Variant Analysis (variants per query, parameter ranges)
 *   3.  PSP Variant Performance Comparison
 *   4.  DOP Feedback Adjustments per Query
 *   5.  CE Feedback Corrections
 *   6.  Optimized Plan Forcing Statistics
 *   7.  Memory Grant Percentile vs Row-Based Feedback Comparison
 *   8.  Batch Mode on Rowstore Usage
 *   9.  Adaptive Joins Analysis
 *   10. Scalar UDF Inlining Candidates
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: IQP Feature Enablement Summary
  Shows which 2022-specific IQP features are active.
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    DB_NAME()                                       AS database_name,
    (SELECT compatibility_level FROM sys.databases WHERE database_id = DB_ID())
                                                    AS compatibility_level,
    (SELECT actual_state_desc FROM sys.database_query_store_options)
                                                    AS query_store_state;

-- Database scoped configurations for IQP
SELECT
    name                                            AS feature_config,
    value                                           AS current_value,
    value_for_secondary                             AS secondary_value,
    CASE
        WHEN name = 'PARAMETER_SENSITIVE_PLAN_OPTIMIZATION' AND value = 1
            THEN 'PSP enabled — dispatchers route to variant plans (NEW in 2022)'
        WHEN name = 'DOP_FEEDBACK' AND value = 1
            THEN 'DOP feedback enabled — auto-adjusts parallelism (NEW in 2022)'
        WHEN name = 'CE_FEEDBACK' AND value = 1
            THEN 'CE feedback enabled — adjusts cardinality model (NEW in 2022)'
        WHEN name = 'OPTIMIZED_PLAN_FORCING' AND value = 1
            THEN 'Optimized plan forcing — faster forced plan compilation (NEW in 2022)'
        WHEN name = 'MEMORY_GRANT_FEEDBACK_PERCENTILE' AND value = 1
            THEN 'Memory grant percentile feedback — better grant sizing (NEW in 2022)'
        WHEN name = 'MEMORY_GRANT_FEEDBACK_PERSISTENCE' AND value = 1
            THEN 'Memory grant feedback persistence via Query Store'
        WHEN name = 'BATCH_MODE_ON_ROWSTORE' AND value = 1
            THEN 'Batch mode on rowstore enabled'
        WHEN name = 'BATCH_MODE_ADAPTIVE_JOINS' AND value = 1
            THEN 'Adaptive joins enabled'
        WHEN name = 'TSQL_SCALAR_UDF_INLINING' AND value = 1
            THEN 'Scalar UDF inlining enabled'
        WHEN name = 'EXEC_QUERY_STATS_FOR_SCALAR_FUNCTIONS' AND value = 1
            THEN 'Query stats for scalar functions enabled'
        ELSE ''
    END                                             AS description
FROM sys.database_scoped_configurations
WHERE name IN (
    'PARAMETER_SENSITIVE_PLAN_OPTIMIZATION',
    'DOP_FEEDBACK',
    'CE_FEEDBACK',
    'OPTIMIZED_PLAN_FORCING',
    'MEMORY_GRANT_FEEDBACK_PERCENTILE',
    'MEMORY_GRANT_FEEDBACK_PERSISTENCE',
    'BATCH_MODE_ON_ROWSTORE',
    'BATCH_MODE_ADAPTIVE_JOINS',
    'TSQL_SCALAR_UDF_INLINING',
    'EXEC_QUERY_STATS_FOR_SCALAR_FUNCTIONS',
    'INTERLEAVED_EXECUTION_TVF',
    'BATCH_MODE_MEMORY_GRANT_FEEDBACK',
    'ROW_MODE_MEMORY_GRANT_FEEDBACK'
)
ORDER BY name;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: PSP Plan Variant Analysis — NEW in 2022
  How many variants exist per query, with dispatcher-to-variant mapping.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_query_variant')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    -- Overview: dispatchers and variant counts
    ;WITH dispatcher_summary AS (
        SELECT
            qv.parent_query_id                      AS dispatcher_query_id,
            COUNT(DISTINCT qv.query_variant_query_id) AS variant_count,
            MIN(rs.first_execution_time)            AS first_variant_exec,
            MAX(rs.last_execution_time)             AS last_variant_exec,
            SUM(rs.count_executions)                AS total_variant_executions
        FROM sys.query_store_query_variant AS qv                                -- NEW in 2022
        INNER JOIN sys.query_store_plan AS p
            ON p.query_id = qv.query_variant_query_id
        LEFT JOIN sys.query_store_runtime_stats AS rs
            ON rs.plan_id = p.plan_id
        GROUP BY qv.parent_query_id
    )
    SELECT
        ds.dispatcher_query_id,
        ds.variant_count,
        ds.total_variant_executions,
        ds.first_variant_exec,
        ds.last_variant_exec,
        LEFT(qt.query_sql_text, 400)                AS dispatcher_sql_text
    FROM dispatcher_summary AS ds
    INNER JOIN sys.query_store_query AS q
        ON ds.dispatcher_query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    ORDER BY ds.variant_count DESC, ds.total_variant_executions DESC;

    -- Variant detail with parameter boundary info
    SELECT TOP (100)
        qv.parent_query_id                          AS dispatcher_query_id,
        qv.query_variant_query_id                   AS variant_query_id,
        vq.query_parameterization_type_desc         AS variant_param_type,
        p.plan_id                                   AS variant_plan_id,
        p.plan_type_desc,                                                       -- 'Variant' for PSP variants
        p.is_forced_plan,
        p.count_compiles,
        p.force_failure_count,
        rs.count_executions,
        rs.avg_duration / 1000.0                    AS avg_duration_ms,
        rs.avg_cpu_time / 1000.0                    AS avg_cpu_ms,
        rs.avg_logical_io_reads,
        rs.avg_physical_io_reads,
        rs.avg_rowcount,
        rs.avg_query_max_used_memory,
        rs.avg_dop                                  AS avg_degree_of_parallelism,
        LEFT(vqt.query_sql_text, 200)               AS variant_sql_preview
    FROM sys.query_store_query_variant AS qv                                    -- NEW in 2022
    INNER JOIN sys.query_store_query AS vq
        ON qv.query_variant_query_id = vq.query_id
    INNER JOIN sys.query_store_query_text AS vqt
        ON vq.query_text_id = vqt.query_text_id
    INNER JOIN sys.query_store_plan AS p
        ON p.query_id = qv.query_variant_query_id
    LEFT JOIN sys.query_store_runtime_stats AS rs
        ON rs.plan_id = p.plan_id
    ORDER BY qv.parent_query_id, rs.avg_duration DESC;
END
ELSE
BEGIN
    SELECT 'PSP variant analysis requires Query Store active and SQL Server 2022+.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: PSP Variant Performance Comparison — NEW in 2022
  Side-by-side performance of variants for the same dispatcher query.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_query_variant')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    ;WITH variant_stats AS (
        SELECT
            qv.parent_query_id,
            qv.query_variant_query_id,
            SUM(rs.count_executions)                AS total_execs,
            AVG(rs.avg_duration) / 1000.0           AS avg_duration_ms,
            AVG(rs.avg_cpu_time) / 1000.0           AS avg_cpu_ms,
            AVG(rs.avg_logical_io_reads)            AS avg_reads,
            AVG(rs.avg_rowcount)                    AS avg_rows,
            MIN(rs.avg_duration) / 1000.0           AS best_duration_ms,
            MAX(rs.avg_duration) / 1000.0           AS worst_duration_ms
        FROM sys.query_store_query_variant AS qv
        INNER JOIN sys.query_store_plan AS p
            ON p.query_id = qv.query_variant_query_id
        INNER JOIN sys.query_store_runtime_stats AS rs
            ON rs.plan_id = p.plan_id
        GROUP BY qv.parent_query_id, qv.query_variant_query_id
    ),
    dispatcher_agg AS (
        SELECT
            parent_query_id,
            COUNT(*)                                AS variant_count,
            MIN(avg_duration_ms)                    AS fastest_variant_ms,
            MAX(avg_duration_ms)                    AS slowest_variant_ms,
            CASE
                WHEN MIN(avg_duration_ms) > 0
                THEN CAST(MAX(avg_duration_ms) / MIN(avg_duration_ms) AS DECIMAL(10,2))
                ELSE NULL
            END                                     AS perf_spread_factor
        FROM variant_stats
        GROUP BY parent_query_id
        HAVING COUNT(*) > 1
    )
    SELECT TOP (25)
        da.parent_query_id                          AS dispatcher_query_id,
        da.variant_count,
        da.fastest_variant_ms,
        da.slowest_variant_ms,
        da.perf_spread_factor,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM dispatcher_agg AS da
    INNER JOIN sys.query_store_query AS q
        ON da.parent_query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    ORDER BY da.perf_spread_factor DESC;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: DOP Feedback Adjustments per Query — NEW in 2022
  Shows queries where DOP has been adjusted by the DOP feedback feature.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_plan_feedback')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    SELECT
        pf.plan_feedback_id,
        pf.plan_id,
        p.query_id,
        pf.feature_desc,                                                        -- 'DOP' for DOP feedback
        pf.feedback_data,                           -- Contains the adjusted DOP
        pf.state_desc                               AS feedback_state,
        pf.create_time,
        pf.last_updated_time,
        rs.count_executions                         AS exec_count_since_feedback,
        rs.avg_duration / 1000.0                    AS avg_duration_ms,
        rs.avg_cpu_time / 1000.0                    AS avg_cpu_ms,
        rs.avg_dop                                  AS current_avg_dop,
        rs.avg_logical_io_reads                     AS avg_reads,
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
END
ELSE
BEGIN
    SELECT 'DOP feedback analysis requires Query Store active and SQL Server 2022+.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: CE Feedback Corrections — NEW in 2022
  Shows queries where cardinality estimation model has been corrected.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_plan_feedback')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    SELECT
        pf.plan_feedback_id,
        pf.plan_id,
        p.query_id,
        pf.feature_desc,                                                        -- 'CE' for CE feedback
        pf.feedback_data,                           -- Contains CE model adjustment
        pf.state_desc                               AS feedback_state,
        pf.create_time,
        pf.last_updated_time,
        rs.count_executions                         AS exec_count,
        rs.avg_duration / 1000.0                    AS avg_duration_ms,
        rs.avg_cpu_time / 1000.0                    AS avg_cpu_ms,
        rs.avg_logical_io_reads                     AS avg_reads,
        rs.avg_rowcount                             AS avg_rows,
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
    ORDER BY rs.count_executions DESC;
END
ELSE
BEGIN
    SELECT 'CE feedback analysis requires Query Store active and SQL Server 2022+.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 6: Optimized Plan Forcing Statistics — NEW in 2022
  Queries using the optimized plan forcing feature (compile replay script).
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    -- Plans with optimized forcing
    SELECT
        p.plan_id,
        p.query_id,
        p.plan_type_desc,
        p.is_forced_plan,
        p.has_compile_replay_script                 AS optimized_forcing,        -- NEW in 2022
        p.is_optimized_plan_forcing_disabled,                                   -- NEW in 2022
        p.count_compiles,
        p.force_failure_count,
        p.last_force_failure_reason_desc,
        rs.count_executions,
        rs.avg_duration / 1000.0                    AS avg_duration_ms,
        rs.avg_compile_duration / 1000.0            AS avg_compile_ms,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM sys.query_store_plan AS p
    INNER JOIN sys.query_store_query AS q
        ON p.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    LEFT JOIN sys.query_store_runtime_stats AS rs
        ON rs.plan_id = p.plan_id
    WHERE p.is_forced_plan = 1
    ORDER BY
        p.has_compile_replay_script DESC,
        rs.count_executions DESC;

    -- Summary of optimized vs traditional forced plans
    SELECT
        CASE
            WHEN has_compile_replay_script = 1 THEN 'Optimized Forcing (NEW in 2022)'
            ELSE 'Traditional Forcing'
        END                                         AS forcing_type,
        COUNT(*)                                    AS plan_count,
        SUM(force_failure_count)                    AS total_force_failures,
        AVG(count_compiles)                         AS avg_compiles
    FROM sys.query_store_plan
    WHERE is_forced_plan = 1
    GROUP BY has_compile_replay_script;
END
ELSE
BEGIN
    SELECT 'Optimized plan forcing analysis requires Query Store active.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 7: Memory Grant Percentile vs Row-Based Feedback Comparison
  — NEW in 2022
  Compares the two feedback mechanisms for memory grants.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_plan_feedback')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    -- Summary: count of each memory grant feedback type
    SELECT
        pf.feature_desc                             AS feedback_type,
        pf.state_desc                               AS feedback_state,
        COUNT(*)                                    AS plan_count,
        AVG(rs.avg_query_max_used_memory)           AS avg_max_used_memory,
        AVG(rs.avg_duration) / 1000.0               AS avg_duration_ms
    FROM sys.query_store_plan_feedback AS pf                                    -- NEW in 2022
    INNER JOIN sys.query_store_plan AS p
        ON pf.plan_id = p.plan_id
    LEFT JOIN sys.query_store_runtime_stats AS rs
        ON rs.plan_id = p.plan_id
    WHERE pf.feature_desc IN ('MGF_PERCENTILE', 'MGF_ROW')                      -- NEW in 2022
    GROUP BY pf.feature_desc, pf.state_desc
    ORDER BY pf.feature_desc, pf.state_desc;

    -- Detailed: queries with both types of feedback (interesting for comparison)
    ;WITH mgf_queries AS (
        SELECT
            p.query_id,
            pf.feature_desc,
            pf.state_desc,
            pf.feedback_data,
            pf.create_time,
            pf.last_updated_time,
            rs.avg_query_max_used_memory,
            rs.avg_duration / 1000.0                AS avg_duration_ms,
            rs.count_executions
        FROM sys.query_store_plan_feedback AS pf
        INNER JOIN sys.query_store_plan AS p
            ON pf.plan_id = p.plan_id
        LEFT JOIN sys.query_store_runtime_stats AS rs
            ON rs.plan_id = p.plan_id
        WHERE pf.feature_desc IN ('MGF_PERCENTILE', 'MGF_ROW')
    )
    SELECT TOP (50)
        mq.query_id,
        mq.feature_desc                             AS feedback_type,
        mq.state_desc                               AS feedback_state,
        mq.feedback_data,
        mq.avg_query_max_used_memory                AS avg_max_used_memory,
        mq.avg_duration_ms,
        mq.count_executions                         AS exec_count,
        mq.create_time                              AS feedback_created,
        mq.last_updated_time                        AS feedback_updated,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM mgf_queries AS mq
    INNER JOIN sys.query_store_query AS q
        ON mq.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    ORDER BY mq.query_id, mq.feature_desc;
END
ELSE
BEGIN
    SELECT 'Memory grant feedback comparison requires Query Store active and SQL Server 2022+.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 8: Batch Mode on Rowstore Usage
──────────────────────────────────────────────────────────────────────────────*/
-- Queries currently using batch mode on rowstore (from plan cache)
SELECT TOP (25)
    qs.total_worker_time / 1000                     AS total_cpu_ms,
    qs.execution_count,
    qs.total_elapsed_time / 1000                    AS total_elapsed_ms,
    qs.total_logical_reads,
    SUBSTRING(qt.text,
        (qs.statement_start_offset / 2) + 1,
        (CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2 + 1
    )                                               AS query_text,
    qp.query_plan                                   AS plan_xml
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
WHERE qp.query_plan.exist('//RelOp[@EstimatedExecutionMode="Batch"]') = 1
ORDER BY qs.total_worker_time DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 9: Adaptive Joins Analysis (from plan cache)
──────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (25)
    qs.total_worker_time / 1000                     AS total_cpu_ms,
    qs.execution_count,
    qs.total_elapsed_time / 1000                    AS total_elapsed_ms,
    qs.total_logical_reads,
    SUBSTRING(qt.text,
        (qs.statement_start_offset / 2) + 1,
        (CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2 + 1
    )                                               AS query_text,
    qp.query_plan                                   AS plan_xml
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
WHERE qp.query_plan.exist('//RelOp[contains(@PhysicalOp,"Adaptive")]') = 1
ORDER BY qs.total_worker_time DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 10: Scalar UDF Inlining Candidates
  Identifies scalar UDFs that may benefit from inlining (compat 150+).
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    OBJECT_SCHEMA_NAME(o.object_id)                 AS schema_name,
    o.name                                          AS function_name,
    o.type_desc,
    sm.is_inlineable,                               -- 1 = can be inlined
    sm.inline_type,
    sm.uses_native_compilation,
    CASE
        WHEN sm.is_inlineable = 1 THEN 'Eligible for inlining'
        ELSE 'Not eligible — review function body'
    END                                             AS inlining_status,
    LEFT(sm.definition, 300)                        AS function_definition_preview
FROM sys.objects AS o
INNER JOIN sys.sql_modules AS sm
    ON o.object_id = sm.object_id
WHERE o.type IN ('FN')  -- scalar functions
  AND o.is_ms_shipped = 0
ORDER BY sm.is_inlineable DESC, o.name;
