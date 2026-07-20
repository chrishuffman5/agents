/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Top Queries by CPU
 *
 * Purpose : Identify the most CPU-intensive queries with PSP awareness.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Top 25 Queries by Total CPU (Plan Cache)
 *   2. Top 25 Queries by CPU from Query Store
 *   3. PSP Dispatcher Plans & Their Variants (NEW in 2022)
 *   4. Currently Executing CPU-Intensive Queries
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: Top 25 Queries by Total CPU (Plan Cache)
──────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (25)
    qs.total_worker_time / 1000                     AS total_cpu_ms,
    qs.execution_count,
    CAST(qs.total_worker_time * 1.0
        / (NULLIF(qs.execution_count, 0) * 1000) AS DECIMAL(18,2))
                                                    AS avg_cpu_ms,
    qs.max_worker_time / 1000                       AS max_cpu_ms,
    qs.total_elapsed_time / 1000                    AS total_elapsed_ms,
    qs.total_logical_reads                          AS total_logical_reads,
    CAST(qs.total_logical_reads * 1.0
        / NULLIF(qs.execution_count, 0) AS DECIMAL(18,2))
                                                    AS avg_logical_reads,
    qs.total_physical_reads                         AS total_physical_reads,
    qs.total_rows                                   AS total_rows_returned,
    qs.plan_generation_num                          AS plan_recompiles,
    qs.creation_time                                AS plan_created,
    qs.last_execution_time                          AS last_executed,
    DB_NAME(qt.dbid)                                AS database_name,
    OBJECT_NAME(qt.objectid, qt.dbid)               AS object_name,
    SUBSTRING(qt.text,
        (qs.statement_start_offset / 2) + 1,
        (CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2 + 1
    )                                               AS query_text,
    qp.query_plan                                   AS execution_plan
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
ORDER BY qs.total_worker_time DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: Top 25 Queries by CPU from Query Store
  Covers the configured Query Store interval.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (
    SELECT 1 FROM sys.database_query_store_options
    WHERE actual_state = 1 OR actual_state = 2  -- READ_WRITE or READ_ONLY
)
BEGIN
    SELECT TOP (25)
        q.query_id,
        p.plan_id,
        qt.query_sql_text,
        rs.count_executions                         AS exec_count,
        rs.avg_cpu_time / 1000.0                    AS avg_cpu_ms,
        rs.max_cpu_time / 1000.0                    AS max_cpu_ms,
        rs.last_cpu_time / 1000.0                   AS last_cpu_ms,
        rs.avg_duration / 1000.0                    AS avg_duration_ms,
        rs.avg_logical_io_reads                     AS avg_logical_reads,
        rs.avg_physical_io_reads                    AS avg_physical_reads,
        rs.avg_rowcount                             AS avg_row_count,
        p.is_forced_plan                            AS plan_forced,
        p.plan_type_desc,                                                       -- NEW in 2022
        q.query_parameterization_type_desc          AS parameterization,
        p.compatibility_level                       AS plan_compat_level,
        rs.first_execution_time,
        rs.last_execution_time
    FROM sys.query_store_runtime_stats AS rs
    INNER JOIN sys.query_store_plan AS p
        ON rs.plan_id = p.plan_id
    INNER JOIN sys.query_store_query AS q
        ON p.query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    WHERE rs.last_execution_time > DATEADD(HOUR, -24, GETUTCDATE())
    ORDER BY rs.avg_cpu_time * rs.count_executions DESC;
END
ELSE
BEGIN
    SELECT 'Query Store is not active in this database.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: PSP Dispatcher Plans & Their Variants — NEW in 2022
  Parameter Sensitive Plan (PSP) optimization creates a dispatcher plan
  that routes to variant plans based on parameter cardinality ranges.
  Uses sys.query_store_query_variant and plan_type column.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (
    SELECT 1 FROM sys.database_query_store_options
    WHERE actual_state IN (1, 2)
)
AND EXISTS (
    SELECT 1 FROM sys.all_objects WHERE name = 'query_store_query_variant'
)
BEGIN
    -- 3a. Dispatcher plans and how many variants they have
    ;WITH dispatcher_plans AS (
        SELECT
            p.plan_id                               AS dispatcher_plan_id,
            p.query_id                              AS dispatcher_query_id,
            qt.query_sql_text                       AS dispatcher_sql_text,
            p.plan_type_desc                        AS plan_type,               -- NEW in 2022: 'Dispatcher' vs 'Variant'
            COUNT(DISTINCT qv.query_variant_query_id) AS variant_count
        FROM sys.query_store_plan AS p
        INNER JOIN sys.query_store_query AS q
            ON p.query_id = q.query_id
        INNER JOIN sys.query_store_query_text AS qt
            ON q.query_text_id = qt.query_text_id
        LEFT JOIN sys.query_store_query_variant AS qv                           -- NEW in 2022
            ON qv.parent_query_id = q.query_id
        WHERE p.plan_type_desc = 'Dispatcher'                                   -- NEW in 2022
        GROUP BY p.plan_id, p.query_id, qt.query_sql_text, p.plan_type_desc
    )
    SELECT
        dispatcher_plan_id,
        dispatcher_query_id,
        plan_type,
        variant_count,
        LEFT(dispatcher_sql_text, 300)              AS sql_text_preview
    FROM dispatcher_plans
    ORDER BY variant_count DESC;

    -- 3b. Variant-level detail with CPU metrics
    SELECT TOP (50)
        qv.parent_query_id                          AS dispatcher_query_id,     -- NEW in 2022
        qv.query_variant_query_id                   AS variant_query_id,        -- NEW in 2022
        p.plan_id                                   AS variant_plan_id,
        p.plan_type_desc,                                                       -- NEW in 2022
        rs.count_executions                         AS exec_count,
        rs.avg_cpu_time / 1000.0                    AS avg_cpu_ms,
        rs.max_cpu_time / 1000.0                    AS max_cpu_ms,
        rs.avg_duration / 1000.0                    AS avg_duration_ms,
        rs.avg_logical_io_reads                     AS avg_logical_reads,
        rs.avg_rowcount                             AS avg_row_count,
        LEFT(qt.query_sql_text, 200)                AS sql_text_preview
    FROM sys.query_store_query_variant AS qv                                    -- NEW in 2022
    INNER JOIN sys.query_store_query AS q
        ON qv.query_variant_query_id = q.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON q.query_text_id = qt.query_text_id
    INNER JOIN sys.query_store_plan AS p
        ON p.query_id = qv.query_variant_query_id
    INNER JOIN sys.query_store_runtime_stats AS rs
        ON rs.plan_id = p.plan_id
    WHERE rs.last_execution_time > DATEADD(HOUR, -24, GETUTCDATE())
    ORDER BY rs.avg_cpu_time * rs.count_executions DESC;
END
ELSE
BEGIN
    SELECT 'PSP analysis requires Query Store active and SQL Server 2022+.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Currently Executing CPU-Intensive Queries
──────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (25)
    er.session_id,
    er.cpu_time                                     AS cpu_time_ms,
    er.total_elapsed_time                           AS elapsed_ms,
    er.logical_reads,
    er.reads                                        AS physical_reads,
    er.writes,
    er.row_count,
    er.granted_query_memory * 8                     AS granted_memory_kb,
    er.dop                                          AS degree_of_parallelism,
    DB_NAME(er.database_id)                         AS database_name,
    er.status,
    er.command,
    er.wait_type                                    AS current_wait,
    er.wait_time                                    AS current_wait_ms,
    er.blocking_session_id,
    SUBSTRING(qt.text,
        (er.statement_start_offset / 2) + 1,
        (CASE er.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE er.statement_end_offset
         END - er.statement_start_offset) / 2 + 1
    )                                               AS current_statement,
    es.login_name,
    es.host_name,
    es.program_name
FROM sys.dm_exec_requests AS er
INNER JOIN sys.dm_exec_sessions AS es
    ON er.session_id = es.session_id
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) AS qt
WHERE er.session_id > 50
  AND er.status IN (N'running', N'runnable', N'suspended')
ORDER BY er.cpu_time DESC;
