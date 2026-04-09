/*******************************************************************************
 * Script:    04-top-queries-io.sql
 * Purpose:   Top 25 queries by total logical reads (I/O pressure)
 * Version:   SQL Server 2016 (Compatibility Level 130)
 * Date:      2026-04-06
 *
 * Returns:   Most I/O-intensive queries from the plan cache with execution
 *            counts, average metrics, query text, and execution plan.
 *
 * Notes:     Logical reads indicate buffer pool pressure. High logical reads
 *            often correlate with missing indexes or table scans.
 *
 * Safety:    Read-only. Safe for production execution.
 ******************************************************************************/

SET NOCOUNT ON;

-- ============================================================================
-- SECTION 1: Top 25 Queries by Total Logical Reads
-- ============================================================================

SELECT TOP 25
    ROW_NUMBER() OVER (ORDER BY qs.total_logical_reads DESC) AS [Rank],

    -- Totals
    qs.total_logical_reads                      AS [Total Logical Reads],
    qs.total_physical_reads                     AS [Total Physical Reads],
    qs.total_logical_writes                     AS [Total Logical Writes],
    qs.total_worker_time / 1000                 AS [Total CPU Ms],
    qs.total_elapsed_time / 1000                AS [Total Duration Ms],
    qs.total_rows                               AS [Total Rows],

    -- Execution counts
    qs.execution_count                          AS [Exec Count],

    -- Averages
    CAST(qs.total_logical_reads * 1.0
         / NULLIF(qs.execution_count, 0)
         AS DECIMAL(18,2))                      AS [Avg Logical Reads],
    CAST(qs.total_physical_reads * 1.0
         / NULLIF(qs.execution_count, 0)
         AS DECIMAL(18,2))                      AS [Avg Physical Reads],
    CAST(qs.total_logical_writes * 1.0
         / NULLIF(qs.execution_count, 0)
         AS DECIMAL(18,2))                      AS [Avg Logical Writes],
    CAST(qs.total_worker_time * 1.0
         / NULLIF(qs.execution_count, 0)
         / 1000 AS DECIMAL(18,2))               AS [Avg CPU Ms],
    CAST(qs.total_elapsed_time * 1.0
         / NULLIF(qs.execution_count, 0)
         / 1000 AS DECIMAL(18,2))               AS [Avg Duration Ms],
    CAST(qs.total_rows * 1.0
         / NULLIF(qs.execution_count, 0)
         AS DECIMAL(18,2))                      AS [Avg Rows],

    -- Min / Max Reads
    qs.min_logical_reads                        AS [Min Logical Reads],
    qs.max_logical_reads                        AS [Max Logical Reads],

    -- Cache / plan metadata
    qs.creation_time                            AS [Plan Created],
    qs.last_execution_time                      AS [Last Exec Time],

    -- Physical-to-logical ratio (high = data not in cache)
    CAST(CASE
        WHEN qs.total_logical_reads > 0
            THEN 100.0 * qs.total_physical_reads / qs.total_logical_reads
        ELSE 0
    END AS DECIMAL(6,2))                        AS [Cache Miss Pct],

    -- Query text (first 200 characters)
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

    st.text                                     AS [Full Batch Text],
    COALESCE(DB_NAME(st.dbid), 'N/A')          AS [Database],
    qs.plan_handle                              AS [Plan Handle],
    qs.sql_handle                               AS [SQL Handle],
    qp.query_plan                               AS [Execution Plan]

FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
ORDER BY qs.total_logical_reads DESC;


-- ============================================================================
-- SECTION 2: Top 10 Queries by Average Logical Reads (Min 100 Executions)
-- ============================================================================
-- Highlights frequently-run queries with high per-execution I/O.

SELECT TOP 10
    ROW_NUMBER() OVER (ORDER BY qs.total_logical_reads * 1.0
                       / NULLIF(qs.execution_count, 0) DESC)
                                                AS [Rank],
    CAST(qs.total_logical_reads * 1.0
         / NULLIF(qs.execution_count, 0)
         AS DECIMAL(18,2))                      AS [Avg Logical Reads],
    qs.execution_count                          AS [Exec Count],
    qs.total_logical_reads                      AS [Total Logical Reads],
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
WHERE qs.execution_count >= 100
ORDER BY [Avg Logical Reads] DESC;


-- ============================================================================
-- SECTION 3: Top 10 Queries by Physical Reads (Disk-Bound)
-- ============================================================================
-- High physical reads indicate data not resident in buffer pool.

SELECT TOP 10
    ROW_NUMBER() OVER (ORDER BY qs.total_physical_reads DESC) AS [Rank],
    qs.total_physical_reads                     AS [Total Physical Reads],
    qs.total_logical_reads                      AS [Total Logical Reads],
    CAST(CASE
        WHEN qs.total_logical_reads > 0
            THEN 100.0 * qs.total_physical_reads / qs.total_logical_reads
        ELSE 0
    END AS DECIMAL(6,2))                        AS [Cache Miss Pct],
    qs.execution_count                          AS [Exec Count],
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
WHERE qs.total_physical_reads > 0
ORDER BY qs.total_physical_reads DESC;
