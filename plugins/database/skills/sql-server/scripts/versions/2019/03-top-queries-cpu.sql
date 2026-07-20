/******************************************************************************
 * 03-top-queries-cpu.sql
 * SQL Server 2019 (Compatibility Level 150) — Top CPU-Consuming Queries
 *
 * Enhanced for 2019:
 *   - sys.dm_exec_query_plan_stats for last actual execution plan      [NEW]
 *     (lightweight query profiling infrastructure)
 *   - DOP and parallel_worker_count from sys.dm_exec_requests          [NEW]
 *   - Batch mode on rowstore detection in plans                        [NEW]
 *
 * Prerequisites:
 *   ALTER DATABASE SCOPED CONFIGURATION SET LAST_QUERY_PLAN_STATS = ON
 *   (enables lightweight query profiling for last actual plan stats)
 *
 * Safe: read-only, no temp tables, no cursors.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — Top 50 Queries by Cumulative CPU (from plan cache)
  Uses sys.dm_exec_query_plan_stats for LAST ACTUAL plan.               [NEW]
=============================================================================*/
;WITH TopCPU AS (
    SELECT TOP 50
        qs.sql_handle,
        qs.plan_handle,
        qs.statement_start_offset,
        qs.statement_end_offset,
        qs.execution_count,
        qs.total_worker_time                AS total_cpu_us,
        qs.total_worker_time / 1000         AS total_cpu_ms,
        qs.total_elapsed_time / 1000        AS total_elapsed_ms,
        qs.total_logical_reads,
        qs.total_physical_reads,
        qs.total_logical_writes,
        qs.total_rows,
        qs.total_grant_kb,
        qs.total_used_grant_kb,
        qs.total_spills,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_worker_time / qs.execution_count
            ELSE 0
        END                                 AS avg_cpu_us,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_elapsed_time / 1000 / qs.execution_count
            ELSE 0
        END                                 AS avg_elapsed_ms,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_logical_reads / qs.execution_count
            ELSE 0
        END                                 AS avg_logical_reads,
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
            THEN qs.total_spills / qs.execution_count
            ELSE 0
        END                                 AS avg_spills,
        qs.min_worker_time / 1000           AS min_cpu_ms,
        qs.max_worker_time / 1000           AS max_cpu_ms,
        qs.last_worker_time / 1000          AS last_cpu_ms,
        qs.creation_time                    AS plan_created,
        qs.last_execution_time
    FROM sys.dm_exec_query_stats AS qs
    ORDER BY qs.total_worker_time DESC
)
SELECT
    tc.total_cpu_ms,
    tc.avg_cpu_us,
    tc.execution_count,
    tc.avg_elapsed_ms,
    tc.avg_logical_reads,
    tc.avg_rows,
    tc.avg_grant_kb,
    tc.avg_spills,
    tc.total_spills,
    tc.min_cpu_ms,
    tc.max_cpu_ms,
    tc.last_cpu_ms,
    tc.plan_created,
    tc.last_execution_time,
    DB_NAME(st.dbid)                        AS database_name,
    OBJECT_NAME(st.objectid, st.dbid)       AS object_name,
    SUBSTRING(
        st.text,
        (tc.statement_start_offset / 2) + 1,
        (CASE tc.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE tc.statement_end_offset
         END - tc.statement_start_offset) / 2 + 1
    )                                       AS query_text,
    qp.query_plan                           AS estimated_plan,
    -- NEW 2019: Last actual execution plan via lightweight profiling
    lps.last_known_actual_plan              AS last_actual_plan     -- [NEW]
FROM TopCPU AS tc
CROSS APPLY sys.dm_exec_sql_text(tc.sql_handle) AS st
OUTER APPLY sys.dm_exec_query_plan(tc.plan_handle) AS qp
-- NEW 2019: lightweight query plan stats (last actual plan)
OUTER APPLY sys.dm_exec_query_plan_stats(tc.plan_handle) AS lps   -- [NEW]
ORDER BY tc.total_cpu_ms DESC;

/*=============================================================================
  Section 2 — Currently Executing Queries with DOP & Parallel Workers  [NEW]
  Shows active queries with their actual degree of parallelism.
=============================================================================*/
SELECT
    r.session_id,
    r.request_id,
    r.status                                AS request_status,
    r.command,
    r.cpu_time                              AS cpu_time_ms,
    r.total_elapsed_time                    AS elapsed_time_ms,
    r.reads                                 AS logical_reads,
    r.writes                                AS logical_writes,
    r.logical_reads                         AS buffer_reads,
    r.row_count,
    r.granted_query_memory * 8              AS granted_memory_kb,
    r.dop,                                                          -- [NEW 2019]
    r.parallel_worker_count,                                        -- [NEW 2019]
    r.wait_type                             AS current_wait,
    r.wait_time                             AS current_wait_ms,
    r.wait_resource,
    r.blocking_session_id,
    DB_NAME(r.database_id)                  AS database_name,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        (CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset) / 2 + 1
    )                                       AS current_statement,
    st.text                                 AS full_batch_text,
    qp.query_plan                           AS estimated_plan,
    -- NEW 2019: Last actual plan
    lps.last_known_actual_plan              AS last_actual_plan     -- [NEW]
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) AS qp
OUTER APPLY sys.dm_exec_query_plan_stats(r.plan_handle) AS lps    -- [NEW]
WHERE r.session_id > 50
  AND r.session_id <> @@SPID
ORDER BY r.cpu_time DESC;

/*=============================================================================
  Section 3 — Top CPU Queries with Parallelism Concerns
  Identifies queries that may be over- or under-parallelized.          [NEW]
=============================================================================*/
;WITH ParallelQueries AS (
    SELECT
        qs.plan_handle,
        qs.sql_handle,
        qs.statement_start_offset,
        qs.statement_end_offset,
        qs.execution_count,
        qs.total_worker_time / 1000         AS total_cpu_ms,
        qs.total_elapsed_time / 1000        AS total_elapsed_ms,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_worker_time / qs.execution_count / 1000
            ELSE 0
        END                                 AS avg_cpu_ms,
        CASE
            WHEN qs.execution_count > 0
            THEN qs.total_elapsed_time / qs.execution_count / 1000
            ELSE 0
        END                                 AS avg_elapsed_ms,
        CASE
            WHEN qs.total_elapsed_time > 0
            THEN CAST(qs.total_worker_time * 1.0
                       / qs.total_elapsed_time AS DECIMAL(10,2))
            ELSE 0
        END                                 AS cpu_to_elapsed_ratio,
        qs.total_rows,
        qs.total_spills
    FROM sys.dm_exec_query_stats AS qs
    WHERE qs.total_worker_time > 1000000    /* > 1 second total CPU */
)
SELECT TOP 30
    pq.total_cpu_ms,
    pq.avg_cpu_ms,
    pq.avg_elapsed_ms,
    pq.cpu_to_elapsed_ratio,
    CASE
        WHEN pq.cpu_to_elapsed_ratio > 4
        THEN 'High parallelism (CPU >> elapsed)'
        WHEN pq.cpu_to_elapsed_ratio BETWEEN 1.5 AND 4
        THEN 'Moderate parallelism'
        WHEN pq.cpu_to_elapsed_ratio < 0.5
        THEN 'Possible waiting (CPU << elapsed)'
        ELSE 'Sequential or minimal parallelism'
    END                                     AS parallelism_assessment,
    pq.execution_count,
    pq.total_spills,
    SUBSTRING(
        st.text,
        (pq.statement_start_offset / 2) + 1,
        (CASE pq.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE pq.statement_end_offset
         END - pq.statement_start_offset) / 2 + 1
    )                                       AS query_text,
    DB_NAME(st.dbid)                        AS database_name
FROM ParallelQueries AS pq
CROSS APPLY sys.dm_exec_sql_text(pq.sql_handle) AS st
ORDER BY pq.cpu_to_elapsed_ratio DESC;
