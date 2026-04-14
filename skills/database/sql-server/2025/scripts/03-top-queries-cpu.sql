/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Top Queries by CPU
 *
 * Purpose : Find the most CPU-intensive queries in the plan cache and
 *           Query Store, with SQL Server 2025 enhancements.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Top 25 Queries by CPU from Plan Cache
 *   2. Top 25 Queries by CPU from Query Store
 *   3. Currently Running High-CPU Queries
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: Top 25 Queries by CPU from Plan Cache
------------------------------------------------------------------------------*/
SELECT TOP (25)
    qs.total_worker_time / 1000                     AS total_cpu_ms,
    qs.execution_count,
    qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS avg_cpu_ms,
    qs.max_worker_time / 1000                       AS max_cpu_ms,
    qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS avg_elapsed_ms,
    qs.total_logical_reads / NULLIF(qs.execution_count, 0)
                                                    AS avg_logical_reads,
    qs.total_logical_writes / NULLIF(qs.execution_count, 0)
                                                    AS avg_logical_writes,
    qs.total_rows / NULLIF(qs.execution_count, 0)   AS avg_rows_returned,
    qs.creation_time                                AS plan_created,
    qs.last_execution_time,
    DB_NAME(st.dbid)                                AS database_name,
    OBJECT_NAME(st.objectid, st.dbid)               AS object_name,
    SUBSTRING(st.text,
        (qs.statement_start_offset / 2) + 1,
        (CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2 + 1)  AS query_text,
    qp.query_plan
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
ORDER BY qs.total_worker_time DESC;

/*------------------------------------------------------------------------------
  Section 2: Top 25 Queries by CPU from Query Store
  Includes LAQ Feedback data from sys.query_store_plan_feedback (NEW in 2025).
  feature_id = 4 / feature_desc = 'LAQ Feedback' indicates optimized locking
  feedback is captured for the plan.
------------------------------------------------------------------------------*/
SELECT TOP (25)
    qsrs.avg_cpu_time / 1000                        AS avg_cpu_ms,
    qsrs.count_executions                           AS exec_count,
    qsrs.avg_cpu_time * qsrs.count_executions / 1000
                                                    AS total_cpu_ms,
    qsrs.max_cpu_time / 1000                        AS max_cpu_ms,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.avg_logical_io_reads                       AS avg_logical_reads,
    qsrs.avg_logical_io_writes                      AS avg_logical_writes,
    qsrs.avg_rowcount                               AS avg_rows,
    qsp.plan_id,
    qsp.query_id,
    qsqt.query_sql_text,
    qsp.is_forced_plan,
    qsrs.first_execution_time,
    qsrs.last_execution_time,
    -- NEW in 2025: Check for LAQ Feedback on this plan
    pf.feature_desc                                 AS plan_feedback_type,
    pf.feedback_data                                AS plan_feedback_data
FROM sys.query_store_runtime_stats AS qsrs
INNER JOIN sys.query_store_plan AS qsp
    ON qsrs.plan_id = qsp.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
LEFT JOIN sys.query_store_plan_feedback AS pf                                  -- NEW in 2025
    ON qsp.plan_id = pf.plan_id
ORDER BY total_cpu_ms DESC;

/*------------------------------------------------------------------------------
  Section 3: Currently Running High-CPU Queries
------------------------------------------------------------------------------*/
SELECT TOP (25)
    er.session_id,
    er.cpu_time / 1000                              AS cpu_time_ms,
    er.total_elapsed_time / 1000                    AS elapsed_ms,
    er.logical_reads,
    er.writes,
    er.row_count,
    er.status,
    er.command,
    DB_NAME(er.database_id)                         AS database_name,
    er.blocking_session_id,
    er.wait_type,
    er.wait_time                                    AS wait_time_ms,
    er.wait_resource,
    es.login_name,
    es.host_name,
    es.program_name,
    SUBSTRING(st.text,
        (er.statement_start_offset / 2) + 1,
        (CASE er.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE er.statement_end_offset
         END - er.statement_start_offset) / 2 + 1)  AS current_statement
FROM sys.dm_exec_requests AS er
INNER JOIN sys.dm_exec_sessions AS es
    ON er.session_id = es.session_id
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) AS st
WHERE es.is_user_process = 1
ORDER BY er.cpu_time DESC;
