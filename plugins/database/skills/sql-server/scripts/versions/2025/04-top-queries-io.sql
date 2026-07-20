/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Top Queries by I/O
 *
 * Purpose : Find the most I/O-intensive queries from the plan cache and
 *           Query Store, with SQL Server 2025 enhancements.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Top 25 Queries by Logical Reads (Plan Cache)
 *   2. Top 25 Queries by Physical Reads (Plan Cache)
 *   3. Top 25 Queries by Writes (Plan Cache)
 *   4. Top 25 Queries by I/O from Query Store
 *   5. Currently Running High-I/O Queries
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: Top 25 Queries by Logical Reads (Plan Cache)
------------------------------------------------------------------------------*/
SELECT TOP (25)
    qs.total_logical_reads                          AS total_logical_reads,
    qs.execution_count,
    qs.total_logical_reads / NULLIF(qs.execution_count, 0)
                                                    AS avg_logical_reads,
    qs.max_logical_reads,
    qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS avg_cpu_ms,
    qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS avg_elapsed_ms,
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
ORDER BY qs.total_logical_reads DESC;

/*------------------------------------------------------------------------------
  Section 2: Top 25 Queries by Physical Reads (Plan Cache)
------------------------------------------------------------------------------*/
SELECT TOP (25)
    qs.total_physical_reads                         AS total_physical_reads,
    qs.execution_count,
    qs.total_physical_reads / NULLIF(qs.execution_count, 0)
                                                    AS avg_physical_reads,
    qs.max_physical_reads,
    qs.total_logical_reads / NULLIF(qs.execution_count, 0)
                                                    AS avg_logical_reads,
    qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS avg_cpu_ms,
    qs.last_execution_time,
    DB_NAME(st.dbid)                                AS database_name,
    SUBSTRING(st.text,
        (qs.statement_start_offset / 2) + 1,
        (CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2 + 1)  AS query_text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE qs.total_physical_reads > 0
ORDER BY qs.total_physical_reads DESC;

/*------------------------------------------------------------------------------
  Section 3: Top 25 Queries by Writes (Plan Cache)
------------------------------------------------------------------------------*/
SELECT TOP (25)
    qs.total_logical_writes                         AS total_writes,
    qs.execution_count,
    qs.total_logical_writes / NULLIF(qs.execution_count, 0)
                                                    AS avg_writes,
    qs.max_logical_writes,
    qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000
                                                    AS avg_cpu_ms,
    qs.last_execution_time,
    DB_NAME(st.dbid)                                AS database_name,
    SUBSTRING(st.text,
        (qs.statement_start_offset / 2) + 1,
        (CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2 + 1)  AS query_text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE qs.total_logical_writes > 0
ORDER BY qs.total_logical_writes DESC;

/*------------------------------------------------------------------------------
  Section 4: Top 25 Queries by I/O from Query Store
  Includes plan feedback data (NEW in 2025).
------------------------------------------------------------------------------*/
SELECT TOP (25)
    qsrs.avg_logical_io_reads                       AS avg_logical_reads,
    qsrs.avg_physical_io_reads                      AS avg_physical_reads,
    qsrs.avg_logical_io_writes                      AS avg_logical_writes,
    qsrs.count_executions                           AS exec_count,
    (qsrs.avg_logical_io_reads + qsrs.avg_physical_io_reads
        + qsrs.avg_logical_io_writes)
        * qsrs.count_executions                     AS total_io_weighted,
    qsrs.avg_cpu_time / 1000                        AS avg_cpu_ms,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsp.plan_id,
    qsp.query_id,
    qsqt.query_sql_text,
    qsp.is_forced_plan,
    qsrs.last_execution_time,
    -- NEW in 2025: Plan feedback
    pf.feature_desc                                 AS plan_feedback_type
FROM sys.query_store_runtime_stats AS qsrs
INNER JOIN sys.query_store_plan AS qsp
    ON qsrs.plan_id = qsp.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
LEFT JOIN sys.query_store_plan_feedback AS pf                                  -- NEW in 2025
    ON qsp.plan_id = pf.plan_id
ORDER BY total_io_weighted DESC;

/*------------------------------------------------------------------------------
  Section 5: Currently Running High-I/O Queries
------------------------------------------------------------------------------*/
SELECT TOP (25)
    er.session_id,
    er.logical_reads,
    er.reads                                        AS physical_reads,
    er.writes,
    er.cpu_time / 1000                              AS cpu_time_ms,
    er.total_elapsed_time / 1000                    AS elapsed_ms,
    er.row_count,
    er.status,
    er.command,
    DB_NAME(er.database_id)                         AS database_name,
    er.blocking_session_id,
    er.wait_type,
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
ORDER BY er.logical_reads DESC;
