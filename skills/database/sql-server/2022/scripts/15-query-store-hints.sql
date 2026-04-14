/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Query Store Hints Analysis
 *
 * Purpose : NEW for 2022. Analyze Query Store hints, their effectiveness,
 *           conflicts with PSP, and orphaned hints.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Query Store Hints Overview
 *   2. All Active Hints with Query Context
 *   3. Hint Effectiveness (Performance Before vs After)
 *   4. Hint Failures & Error Analysis
 *   5. Hints Conflicting with PSP Dispatcher Plans
 *   6. Orphaned Hints (Hints for Dropped/Missing Queries)
 *   7. Hint Coverage Summary
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Prerequisite: Verify Query Store and hints availability
──────────────────────────────────────────────────────────────────────────────*/
IF NOT EXISTS (
    SELECT 1 FROM sys.database_query_store_options
    WHERE actual_state IN (1, 2)
)
BEGIN
    SELECT 'Query Store is not active. Enable Query Store to use Query Store hints.' AS info_message;
END;

IF NOT EXISTS (
    SELECT 1 FROM sys.all_objects WHERE name = 'query_store_hints'
)
BEGIN
    SELECT 'sys.query_store_hints not available. Requires SQL Server 2022+.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: Query Store Hints Overview — NEW in 2022
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_hints')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    -- Summary counts
    SELECT
        COUNT(*)                                    AS total_hints,
        COUNT(DISTINCT query_id)                    AS distinct_queries_with_hints,
        SUM(CASE
            WHEN query_hint_failure_count = 0 THEN 1
            ELSE 0
        END)                                        AS hints_no_failures,
        SUM(CASE
            WHEN query_hint_failure_count > 0 THEN 1
            ELSE 0
        END)                                        AS hints_with_failures,
        SUM(query_hint_failure_count)               AS total_failure_count
    FROM sys.query_store_hints;                                                 -- NEW in 2022
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: All Active Hints with Query Context — NEW in 2022
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_hints')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    SELECT
        qsh.query_hint_id,
        qsh.query_id,
        qsh.query_hint_text                         AS hint_text,               -- NEW in 2022
        qsh.source_desc                             AS hint_source,             -- NEW in 2022
        qsh.comment                                 AS hint_comment,            -- NEW in 2022
        qsh.query_hint_failure_count                AS failure_count,           -- NEW in 2022
        qsh.last_query_hint_failure_reason_desc     AS last_failure_reason,     -- NEW in 2022
        q.query_parameterization_type_desc          AS param_type,
        q.count_compiles,
        q.avg_compile_duration / 1000.0             AS avg_compile_ms,
        q.last_compile_start_time,
        q.last_execution_time,
        LEFT(qt.query_sql_text, 400)                AS sql_text_preview
    FROM sys.query_store_hints AS qsh                                           -- NEW in 2022
    INNER JOIN sys.query_store_query AS q
        ON qsh.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    ORDER BY qsh.query_id;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: Hint Effectiveness — NEW in 2022
  Compare performance metrics for queries that have hints applied.
  Compares the most recent stats interval against earlier intervals.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_hints')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    ;WITH hint_queries AS (
        SELECT DISTINCT query_id
        FROM sys.query_store_hints
    ),
    recent_perf AS (
        SELECT
            p.query_id,
            SUM(rs.count_executions)                AS recent_execs,
            AVG(rs.avg_duration)                    AS recent_avg_duration,
            AVG(rs.avg_cpu_time)                    AS recent_avg_cpu,
            AVG(rs.avg_logical_io_reads)            AS recent_avg_reads,
            AVG(rs.avg_query_max_used_memory)       AS recent_avg_memory
        FROM sys.query_store_runtime_stats AS rs
        INNER JOIN sys.query_store_plan AS p
            ON rs.plan_id = p.plan_id
        INNER JOIN hint_queries AS hq
            ON p.query_id = hq.query_id
        WHERE rs.last_execution_time > DATEADD(HOUR, -6, GETUTCDATE())
        GROUP BY p.query_id
    ),
    historical_perf AS (
        SELECT
            p.query_id,
            SUM(rs.count_executions)                AS hist_execs,
            AVG(rs.avg_duration)                    AS hist_avg_duration,
            AVG(rs.avg_cpu_time)                    AS hist_avg_cpu,
            AVG(rs.avg_logical_io_reads)            AS hist_avg_reads,
            AVG(rs.avg_query_max_used_memory)       AS hist_avg_memory
        FROM sys.query_store_runtime_stats AS rs
        INNER JOIN sys.query_store_plan AS p
            ON rs.plan_id = p.plan_id
        INNER JOIN hint_queries AS hq
            ON p.query_id = hq.query_id
        WHERE rs.last_execution_time BETWEEN DATEADD(DAY, -30, GETUTCDATE())
                                         AND DATEADD(HOUR, -6, GETUTCDATE())
        GROUP BY p.query_id
    )
    SELECT
        rp.query_id,
        qsh.query_hint_text                         AS applied_hint,
        -- Duration comparison
        hp.hist_avg_duration / 1000.0               AS before_avg_duration_ms,
        rp.recent_avg_duration / 1000.0             AS after_avg_duration_ms,
        CASE
            WHEN hp.hist_avg_duration > 0
            THEN CAST((hp.hist_avg_duration - rp.recent_avg_duration) * 100.0
                / hp.hist_avg_duration AS DECIMAL(10,2))
            ELSE NULL
        END                                         AS duration_improvement_pct,
        -- CPU comparison
        hp.hist_avg_cpu / 1000.0                    AS before_avg_cpu_ms,
        rp.recent_avg_cpu / 1000.0                  AS after_avg_cpu_ms,
        CASE
            WHEN hp.hist_avg_cpu > 0
            THEN CAST((hp.hist_avg_cpu - rp.recent_avg_cpu) * 100.0
                / hp.hist_avg_cpu AS DECIMAL(10,2))
            ELSE NULL
        END                                         AS cpu_improvement_pct,
        -- I/O comparison
        hp.hist_avg_reads                           AS before_avg_reads,
        rp.recent_avg_reads                         AS after_avg_reads,
        -- Execution counts
        rp.recent_execs,
        hp.hist_execs,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM recent_perf AS rp
    INNER JOIN historical_perf AS hp
        ON rp.query_id = hp.query_id
    INNER JOIN sys.query_store_hints AS qsh
        ON rp.query_id = qsh.query_id
    INNER JOIN sys.query_store_query AS q
        ON rp.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    ORDER BY
        CASE
            WHEN hp.hist_avg_duration > 0
            THEN (hp.hist_avg_duration - rp.recent_avg_duration) * 100.0
                / hp.hist_avg_duration
            ELSE 0
        END DESC;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Hint Failures & Error Analysis — NEW in 2022
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_hints')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    SELECT
        qsh.query_hint_id,
        qsh.query_id,
        qsh.query_hint_text                         AS hint_text,
        qsh.query_hint_failure_count                AS failure_count,
        qsh.last_query_hint_failure_reason_desc     AS last_failure_reason,
        qsh.source_desc                             AS hint_source,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM sys.query_store_hints AS qsh                                           -- NEW in 2022
    INNER JOIN sys.query_store_query AS q
        ON qsh.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    WHERE qsh.query_hint_failure_count > 0
    ORDER BY qsh.query_hint_failure_count DESC;

    -- Failure reason summary
    SELECT
        last_query_hint_failure_reason_desc          AS failure_reason,
        COUNT(*)                                    AS hint_count,
        SUM(query_hint_failure_count)               AS total_failures
    FROM sys.query_store_hints
    WHERE query_hint_failure_count > 0
    GROUP BY last_query_hint_failure_reason_desc
    ORDER BY total_failures DESC;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: Hints Conflicting with PSP Dispatcher Plans — NEW in 2022
  Identifies hints applied to queries that are also PSP dispatcher queries.
  This combination may cause unexpected behavior.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_hints')
AND EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_query_variant')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    SELECT
        qsh.query_hint_id,
        qsh.query_id,
        qsh.query_hint_text                         AS applied_hint,
        p.plan_type_desc,                           -- 'Dispatcher' indicates PSP
        COUNT(DISTINCT qv.query_variant_query_id)   AS variant_count,
        qsh.query_hint_failure_count                AS hint_failures,
        CASE
            WHEN p.plan_type_desc = 'Dispatcher'
            THEN 'WARNING: Hint applied to PSP dispatcher query — hint may not propagate to all variants'
            ELSE 'OK'
        END                                         AS conflict_assessment,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM sys.query_store_hints AS qsh                                           -- NEW in 2022
    INNER JOIN sys.query_store_query AS q
        ON qsh.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    INNER JOIN sys.query_store_plan AS p
        ON p.query_id = qsh.query_id
    LEFT JOIN sys.query_store_query_variant AS qv                               -- NEW in 2022
        ON qv.parent_query_id = qsh.query_id
    WHERE p.plan_type_desc = 'Dispatcher'                                       -- PSP dispatcher plan
    GROUP BY
        qsh.query_hint_id,
        qsh.query_id,
        qsh.query_hint_text,
        p.plan_type_desc,
        qsh.query_hint_failure_count,
        qt.query_sql_text
    ORDER BY variant_count DESC;

    -- Also check hints on variant queries
    SELECT
        qsh.query_hint_id,
        qsh.query_id                                AS variant_query_id,
        qv.parent_query_id                          AS dispatcher_query_id,
        qsh.query_hint_text                         AS hint_on_variant,
        'Hint applied directly to PSP variant query' AS note,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM sys.query_store_hints AS qsh
    INNER JOIN sys.query_store_query_variant AS qv
        ON qsh.query_id = qv.query_variant_query_id
    INNER JOIN sys.query_store_query AS q
        ON qsh.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    ORDER BY qv.parent_query_id;
END
ELSE
BEGIN
    SELECT 'PSP hint conflict analysis requires both query_store_hints and query_store_query_variant (SQL Server 2022+).' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 6: Orphaned Hints — NEW in 2022
  Hints for queries that no longer exist in Query Store
  (dropped queries, evicted by cleanup, etc.)
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_hints')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    SELECT
        qsh.query_hint_id,
        qsh.query_id,
        qsh.query_hint_text                         AS hint_text,
        qsh.source_desc                             AS hint_source,
        qsh.comment                                 AS hint_comment,
        qsh.query_hint_failure_count                AS failure_count,
        'ORPHANED — Query ID no longer in Query Store' AS status,
        'EXEC sp_query_store_clear_hints @query_id = '
            + CAST(qsh.query_id AS VARCHAR(20)) + ';'
                                                    AS cleanup_command
    FROM sys.query_store_hints AS qsh                                           -- NEW in 2022
    LEFT JOIN sys.query_store_query AS q
        ON qsh.query_id = q.query_id
    WHERE q.query_id IS NULL;

    -- Also find hints for queries that haven't executed recently
    SELECT
        qsh.query_hint_id,
        qsh.query_id,
        qsh.query_hint_text                         AS hint_text,
        q.last_execution_time,
        DATEDIFF(DAY, q.last_execution_time, GETUTCDATE())
                                                    AS days_since_last_exec,
        'STALE — Query has not executed in 30+ days' AS status,
        LEFT(qt.query_sql_text, 300)                AS sql_text_preview
    FROM sys.query_store_hints AS qsh
    INNER JOIN sys.query_store_query AS q
        ON qsh.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    WHERE q.last_execution_time < DATEADD(DAY, -30, GETUTCDATE())
    ORDER BY q.last_execution_time ASC;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 7: Hint Coverage Summary — NEW in 2022
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'query_store_hints')
AND EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state IN (1,2))
BEGIN
    -- How many of the most resource-intensive queries have hints?
    ;WITH top_queries AS (
        SELECT TOP (100)
            p.query_id,
            SUM(rs.avg_cpu_time * rs.count_executions) AS total_cpu_impact
        FROM sys.query_store_runtime_stats AS rs
        INNER JOIN sys.query_store_plan AS p
            ON rs.plan_id = p.plan_id
        WHERE rs.last_execution_time > DATEADD(DAY, -7, GETUTCDATE())
        GROUP BY p.query_id
        ORDER BY total_cpu_impact DESC
    )
    SELECT
        COUNT(DISTINCT tq.query_id)                 AS top_100_query_count,
        COUNT(DISTINCT qsh.query_id)                AS queries_with_hints,
        CAST(COUNT(DISTINCT qsh.query_id) * 100.0
            / NULLIF(COUNT(DISTINCT tq.query_id), 0) AS DECIMAL(5,2))
                                                    AS hint_coverage_pct,
        SUM(CASE WHEN qsh.query_id IS NOT NULL THEN 1 ELSE 0 END)
                                                    AS hinted_query_count
    FROM top_queries AS tq
    LEFT JOIN sys.query_store_hints AS qsh
        ON tq.query_id = qsh.query_id;

    -- Hint type breakdown (parse common hint patterns)
    SELECT
        CASE
            WHEN query_hint_text LIKE '%RECOMPILE%'         THEN 'RECOMPILE'
            WHEN query_hint_text LIKE '%MAXDOP%'            THEN 'MAXDOP'
            WHEN query_hint_text LIKE '%OPTIMIZE FOR%'      THEN 'OPTIMIZE FOR'
            WHEN query_hint_text LIKE '%FORCE ORDER%'       THEN 'FORCE ORDER'
            WHEN query_hint_text LIKE '%HASH%JOIN%'         THEN 'HASH JOIN'
            WHEN query_hint_text LIKE '%LOOP%JOIN%'         THEN 'LOOP JOIN'
            WHEN query_hint_text LIKE '%MERGE%JOIN%'        THEN 'MERGE JOIN'
            WHEN query_hint_text LIKE '%FORCESEEK%'         THEN 'FORCESEEK'
            WHEN query_hint_text LIKE '%FORCESCAN%'         THEN 'FORCESCAN'
            WHEN query_hint_text LIKE '%USE HINT%'          THEN 'USE HINT'
            WHEN query_hint_text LIKE '%MAX_GRANT_PERCENT%' THEN 'MAX_GRANT_PERCENT'
            WHEN query_hint_text LIKE '%MIN_GRANT_PERCENT%' THEN 'MIN_GRANT_PERCENT'
            ELSE 'Other'
        END                                         AS hint_category,
        COUNT(*)                                    AS hint_count,
        SUM(query_hint_failure_count)               AS total_failures
    FROM sys.query_store_hints
    GROUP BY
        CASE
            WHEN query_hint_text LIKE '%RECOMPILE%'         THEN 'RECOMPILE'
            WHEN query_hint_text LIKE '%MAXDOP%'            THEN 'MAXDOP'
            WHEN query_hint_text LIKE '%OPTIMIZE FOR%'      THEN 'OPTIMIZE FOR'
            WHEN query_hint_text LIKE '%FORCE ORDER%'       THEN 'FORCE ORDER'
            WHEN query_hint_text LIKE '%HASH%JOIN%'         THEN 'HASH JOIN'
            WHEN query_hint_text LIKE '%LOOP%JOIN%'         THEN 'LOOP JOIN'
            WHEN query_hint_text LIKE '%MERGE%JOIN%'        THEN 'MERGE JOIN'
            WHEN query_hint_text LIKE '%FORCESEEK%'         THEN 'FORCESEEK'
            WHEN query_hint_text LIKE '%FORCESCAN%'         THEN 'FORCESCAN'
            WHEN query_hint_text LIKE '%USE HINT%'          THEN 'USE HINT'
            WHEN query_hint_text LIKE '%MAX_GRANT_PERCENT%' THEN 'MAX_GRANT_PERCENT'
            WHEN query_hint_text LIKE '%MIN_GRANT_PERCENT%' THEN 'MIN_GRANT_PERCENT'
            ELSE 'Other'
        END
    ORDER BY hint_count DESC;
END;
