/*******************************************************************************
 * Script:    03-top-queries-cpu.sql
 * Purpose:   Top 25 queries by total CPU time (worker_time)
 * Version:   SQL Server 2016 (Compatibility Level 130)
 * Date:      2026-04-06
 *
 * Returns:   Most CPU-intensive queries from the plan cache with execution
 *            counts, average metrics, query text snippet, and execution plan.
 *
 * Notes:     sys.dm_exec_query_stats is cleared on plan cache eviction or
 *            restart. Results reflect only cached plans.
 *
 * Safety:    Read-only. Safe for production execution.
 ******************************************************************************/

SET NOCOUNT ON;

-- ============================================================================
-- SECTION 1: Top 25 Queries by Total CPU (Worker Time)
-- ============================================================================

SELECT TOP 25
    ROW_NUMBER() OVER (ORDER BY qs.total_worker_time DESC)  AS [Rank],

    -- Totals
    qs.total_worker_time / 1000                 AS [Total CPU Ms],
    qs.total_elapsed_time / 1000                AS [Total Duration Ms],
    qs.total_logical_reads                      AS [Total Logical Reads],
    qs.total_logical_writes                     AS [Total Logical Writes],
    qs.total_physical_reads                     AS [Total Physical Reads],
    qs.total_rows                               AS [Total Rows],

    -- Execution counts
    qs.execution_count                          AS [Exec Count],

    -- Averages
    CAST(qs.total_worker_time * 1.0
         / NULLIF(qs.execution_count, 0)
         / 1000 AS DECIMAL(18,2))               AS [Avg CPU Ms],
    CAST(qs.total_elapsed_time * 1.0
         / NULLIF(qs.execution_count, 0)
         / 1000 AS DECIMAL(18,2))               AS [Avg Duration Ms],
    CAST(qs.total_logical_reads * 1.0
         / NULLIF(qs.execution_count, 0)
         AS DECIMAL(18,2))                      AS [Avg Logical Reads],
    CAST(qs.total_logical_writes * 1.0
         / NULLIF(qs.execution_count, 0)
         AS DECIMAL(18,2))                      AS [Avg Logical Writes],
    CAST(qs.total_rows * 1.0
         / NULLIF(qs.execution_count, 0)
         AS DECIMAL(18,2))                      AS [Avg Rows],

    -- Min / Max CPU
    qs.min_worker_time / 1000                   AS [Min CPU Ms],
    qs.max_worker_time / 1000                   AS [Max CPU Ms],

    -- Plan and cache metadata
    qs.plan_generation_num                      AS [Plan Gen Num],
    qs.creation_time                            AS [Plan Created],
    qs.last_execution_time                      AS [Last Exec Time],

    -- Query text (first 200 characters for quick identification)
    SUBSTRING(
        st.text,
        (qs.statement_start_offset / 2) + 1,
        CASE
            WHEN qs.statement_end_offset = -1
                THEN 200
            ELSE LEAST(
                (qs.statement_end_offset - qs.statement_start_offset) / 2 + 1,
                200
            )
        END
    )                                           AS [Query Text (200 chars)],

    -- Full query text (for drilling down)
    st.text                                     AS [Full Batch Text],

    -- Database context
    COALESCE(DB_NAME(st.dbid), 'N/A')          AS [Database],

    -- Plan handle for further analysis
    qs.plan_handle                              AS [Plan Handle],
    qs.sql_handle                               AS [SQL Handle],

    -- Execution plan XML (may be NULL for large plans)
    qp.query_plan                               AS [Execution Plan]

FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
ORDER BY qs.total_worker_time DESC;


-- ============================================================================
-- SECTION 2: Top 10 Queries by Average CPU (Minimum 100 Executions)
-- ============================================================================
-- Filters for frequently-run queries with high per-execution cost.

SELECT TOP 10
    ROW_NUMBER() OVER (ORDER BY qs.total_worker_time * 1.0
                       / NULLIF(qs.execution_count, 0) DESC)
                                                AS [Rank],
    CAST(qs.total_worker_time * 1.0
         / NULLIF(qs.execution_count, 0)
         / 1000 AS DECIMAL(18,2))               AS [Avg CPU Ms],
    qs.execution_count                          AS [Exec Count],
    qs.total_worker_time / 1000                 AS [Total CPU Ms],
    CAST(qs.total_logical_reads * 1.0
         / NULLIF(qs.execution_count, 0)
         AS DECIMAL(18,2))                      AS [Avg Logical Reads],
    SUBSTRING(
        st.text,
        (qs.statement_start_offset / 2) + 1,
        CASE
            WHEN qs.statement_end_offset = -1
                THEN 200
            ELSE LEAST(
                (qs.statement_end_offset - qs.statement_start_offset) / 2 + 1,
                200
            )
        END
    )                                           AS [Query Text (200 chars)],
    COALESCE(DB_NAME(st.dbid), 'N/A')          AS [Database],
    qs.plan_handle                              AS [Plan Handle]
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE qs.execution_count >= 100
ORDER BY [Avg CPU Ms] DESC;


-- ============================================================================
-- SECTION 3: CPU-Intensive Queries — Recently Executed (Last Hour)
-- ============================================================================
-- Useful for catching currently-active problematic queries.

SELECT TOP 10
    qs.last_execution_time                      AS [Last Exec Time],
    qs.total_worker_time / 1000                 AS [Total CPU Ms],
    qs.execution_count                          AS [Exec Count],
    CAST(qs.total_worker_time * 1.0
         / NULLIF(qs.execution_count, 0)
         / 1000 AS DECIMAL(18,2))               AS [Avg CPU Ms],
    SUBSTRING(
        st.text,
        (qs.statement_start_offset / 2) + 1,
        CASE
            WHEN qs.statement_end_offset = -1
                THEN 200
            ELSE LEAST(
                (qs.statement_end_offset - qs.statement_start_offset) / 2 + 1,
                200
            )
        END
    )                                           AS [Query Text (200 chars)],
    COALESCE(DB_NAME(st.dbid), 'N/A')          AS [Database],
    qs.plan_handle                              AS [Plan Handle]
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE qs.last_execution_time >= DATEADD(HOUR, -1, GETDATE())
ORDER BY qs.total_worker_time DESC;
