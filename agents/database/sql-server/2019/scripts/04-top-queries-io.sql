/******************************************************************************
 * 04-top-queries-io.sql
 * SQL Server 2019 (Compatibility Level 150) — Top I/O-Consuming Queries
 *
 * Enhanced for 2019:
 *   - sys.dm_exec_query_plan_stats for last actual execution plan      [NEW]
 *     (lightweight query profiling infrastructure)
 *   - DOP and parallel_worker_count visibility                         [NEW]
 *   - Spill tracking with memory grant feedback context                [NEW]
 *
 * Prerequisites:
 *   ALTER DATABASE SCOPED CONFIGURATION SET LAST_QUERY_PLAN_STATS = ON
 *
 * Safe: read-only, no temp tables, no cursors.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — Top 50 Queries by Total Logical Reads
  Includes last actual plan via lightweight profiling.                  [NEW]
=============================================================================*/
;WITH TopIO AS (
    SELECT TOP 50
        qs.sql_handle,
        qs.plan_handle,
        qs.statement_start_offset,
        qs.statement_end_offset,
        qs.execution_count,
        qs.total_logical_reads,
        qs.total_physical_reads,
        qs.total_logical_writes,
        qs.total_worker_time / 1000         AS total_cpu_ms,
        qs.total_elapsed_time / 1000        AS total_elapsed_ms,
        qs.total_rows,
        qs.total_grant_kb,
        qs.total_used_grant_kb,
        qs.total_ideal_grant_kb,
        qs.total_spills,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_logical_reads / qs.execution_count
            ELSE 0
        END                                 AS avg_logical_reads,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_physical_reads / qs.execution_count
            ELSE 0
        END                                 AS avg_physical_reads,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_logical_writes / qs.execution_count
            ELSE 0
        END                                 AS avg_logical_writes,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_rows / qs.execution_count
            ELSE 0
        END                                 AS avg_rows,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_grant_kb / qs.execution_count
            ELSE 0
        END                                 AS avg_grant_kb,
        CASE
            WHEN qs.execution_count > 0
                 AND qs.total_grant_kb > 0
            THEN CAST(100.0 * qs.total_used_grant_kb
                       / qs.total_grant_kb AS DECIMAL(5,2))
            ELSE NULL
        END                                 AS grant_utilization_pct,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_spills / qs.execution_count
            ELSE 0
        END                                 AS avg_spills,
        qs.min_logical_reads,
        qs.max_logical_reads,
        qs.last_logical_reads,
        qs.creation_time                    AS plan_created,
        qs.last_execution_time
    FROM sys.dm_exec_query_stats AS qs
    ORDER BY qs.total_logical_reads DESC
)
SELECT
    ti.total_logical_reads,
    ti.avg_logical_reads,
    ti.total_physical_reads,
    ti.avg_physical_reads,
    ti.total_logical_writes,
    ti.avg_logical_writes,
    ti.execution_count,
    ti.avg_rows,
    ti.total_cpu_ms,
    ti.total_elapsed_ms,
    ti.avg_grant_kb,
    ti.grant_utilization_pct,
    ti.avg_spills,
    ti.total_spills,
    ti.min_logical_reads,
    ti.max_logical_reads,
    ti.plan_created,
    ti.last_execution_time,
    DB_NAME(st.dbid)                        AS database_name,
    OBJECT_NAME(st.objectid, st.dbid)       AS object_name,
    SUBSTRING(
        st.text,
        (ti.statement_start_offset / 2) + 1,
        (CASE ti.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE ti.statement_end_offset
         END - ti.statement_start_offset) / 2 + 1
    )                                       AS query_text,
    qp.query_plan                           AS estimated_plan,
    -- NEW 2019: Last actual execution plan via lightweight profiling
    lps.last_known_actual_plan              AS last_actual_plan     -- [NEW]
FROM TopIO AS ti
CROSS APPLY sys.dm_exec_sql_text(ti.sql_handle) AS st
OUTER APPLY sys.dm_exec_query_plan(ti.plan_handle) AS qp
OUTER APPLY sys.dm_exec_query_plan_stats(ti.plan_handle) AS lps   -- [NEW]
ORDER BY ti.total_logical_reads DESC;

/*=============================================================================
  Section 2 — Top 50 Queries by Physical Reads (disk-bound queries)
=============================================================================*/
;WITH TopPhysical AS (
    SELECT TOP 50
        qs.sql_handle,
        qs.plan_handle,
        qs.statement_start_offset,
        qs.statement_end_offset,
        qs.execution_count,
        qs.total_physical_reads,
        qs.total_logical_reads,
        qs.total_elapsed_time / 1000        AS total_elapsed_ms,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_physical_reads / qs.execution_count
            ELSE 0
        END                                 AS avg_physical_reads,
        CASE
            WHEN qs.total_logical_reads > 0
            THEN CAST(100.0 * qs.total_physical_reads
                       / qs.total_logical_reads AS DECIMAL(5,2))
            ELSE 0
        END                                 AS cache_miss_pct,
        qs.last_execution_time
    FROM sys.dm_exec_query_stats AS qs
    WHERE qs.total_physical_reads > 0
    ORDER BY qs.total_physical_reads DESC
)
SELECT
    tp.total_physical_reads,
    tp.avg_physical_reads,
    tp.total_logical_reads,
    tp.cache_miss_pct,
    tp.execution_count,
    tp.total_elapsed_ms,
    tp.last_execution_time,
    DB_NAME(st.dbid)                        AS database_name,
    OBJECT_NAME(st.objectid, st.dbid)       AS object_name,
    SUBSTRING(
        st.text,
        (tp.statement_start_offset / 2) + 1,
        (CASE tp.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE tp.statement_end_offset
         END - tp.statement_start_offset) / 2 + 1
    )                                       AS query_text,
    lps.last_known_actual_plan              AS last_actual_plan     -- [NEW]
FROM TopPhysical AS tp
CROSS APPLY sys.dm_exec_sql_text(tp.sql_handle) AS st
OUTER APPLY sys.dm_exec_query_plan_stats(tp.plan_handle) AS lps   -- [NEW]
ORDER BY tp.total_physical_reads DESC;

/*=============================================================================
  Section 3 — Top Queries by Spills (tempdb pressure from memory grants)
  Useful for identifying memory grant feedback candidates.              [NEW]
=============================================================================*/
;WITH TopSpills AS (
    SELECT TOP 30
        qs.sql_handle,
        qs.plan_handle,
        qs.statement_start_offset,
        qs.statement_end_offset,
        qs.execution_count,
        qs.total_spills,
        qs.total_grant_kb,
        qs.total_used_grant_kb,
        qs.total_ideal_grant_kb,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_spills / qs.execution_count
            ELSE 0
        END                                 AS avg_spills,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_grant_kb / qs.execution_count
            ELSE 0
        END                                 AS avg_grant_kb,
        CASE
            WHEN qs.total_grant_kb > 0
            THEN CAST(100.0 * qs.total_used_grant_kb
                       / qs.total_grant_kb AS DECIMAL(5,2))
            ELSE NULL
        END                                 AS grant_utilization_pct,
        qs.total_logical_reads,
        qs.last_execution_time
    FROM sys.dm_exec_query_stats AS qs
    WHERE qs.total_spills > 0
    ORDER BY qs.total_spills DESC
)
SELECT
    ts.total_spills,
    ts.avg_spills,
    ts.execution_count,
    ts.avg_grant_kb,
    ts.grant_utilization_pct,
    ts.total_logical_reads,
    ts.last_execution_time,
    DB_NAME(st.dbid)                        AS database_name,
    SUBSTRING(
        st.text,
        (ts.statement_start_offset / 2) + 1,
        (CASE ts.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE ts.statement_end_offset
         END - ts.statement_start_offset) / 2 + 1
    )                                       AS query_text,
    lps.last_known_actual_plan              AS last_actual_plan     -- [NEW]
FROM TopSpills AS ts
CROSS APPLY sys.dm_exec_sql_text(ts.sql_handle) AS st
OUTER APPLY sys.dm_exec_query_plan_stats(ts.plan_handle) AS lps   -- [NEW]
ORDER BY ts.total_spills DESC;

/*=============================================================================
  Section 4 — Currently Active I/O-Heavy Requests with Parallelism     [NEW]
=============================================================================*/
SELECT
    r.session_id,
    r.status,
    r.command,
    r.reads                                 AS physical_reads,
    r.logical_reads                         AS logical_reads,
    r.writes,
    r.row_count,
    r.cpu_time                              AS cpu_time_ms,
    r.total_elapsed_time                    AS elapsed_time_ms,
    r.granted_query_memory * 8              AS granted_memory_kb,
    r.dop,                                                          -- [NEW 2019]
    r.parallel_worker_count,                                        -- [NEW 2019]
    r.wait_type                             AS current_wait,
    r.wait_time                             AS current_wait_ms,
    DB_NAME(r.database_id)                  AS database_name,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        (CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset) / 2 + 1
    )                                       AS current_statement
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
WHERE r.session_id > 50
  AND r.session_id <> @@SPID
  AND (r.reads > 0 OR r.logical_reads > 1000)
ORDER BY r.logical_reads DESC;
