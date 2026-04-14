/*******************************************************************************
 * Script:    08-io-performance.sql
 * Purpose:   I/O performance analysis per database file with latency flags
 * Version:   SQL Server 2016 (Compatibility Level 130)
 * Date:      2026-04-06
 *
 * Returns:   Per-file read/write latency, throughput, stall analysis, and
 *            tempdb-specific I/O diagnostics. Files with latency > 20ms are
 *            flagged for investigation.
 *
 * Notes:     Cumulative since last restart. Compare two snapshots for
 *            interval-based analysis.
 *
 * Safety:    Read-only. Safe for production execution.
 ******************************************************************************/

SET NOCOUNT ON;

-- ============================================================================
-- SECTION 1: I/O Latency per Database File
-- ============================================================================
-- Avg latency = total stall time / total I/O operations.
-- Thresholds: Data < 20ms, Log < 5ms for OLTP; relaxed for DW/reporting.

;WITH FileIO AS (
    SELECT
        vfs.database_id,
        vfs.file_id,
        DB_NAME(vfs.database_id)                AS db_name,
        mf.name                                 AS logical_name,
        mf.physical_name,
        mf.type_desc                            AS file_type,
        mf.size * 8 / 1024                      AS file_size_mb,

        -- Read metrics
        vfs.num_of_reads,
        vfs.num_of_bytes_read / 1048576         AS read_mb,
        vfs.io_stall_read_ms,

        -- Write metrics
        vfs.num_of_writes,
        vfs.num_of_bytes_written / 1048576      AS write_mb,
        vfs.io_stall_write_ms,

        -- Combined
        vfs.num_of_reads + vfs.num_of_writes    AS total_io,
        vfs.io_stall                            AS total_stall_ms,
        vfs.size_on_disk_bytes / 1048576        AS size_on_disk_mb

    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    INNER JOIN sys.master_files AS mf
        ON mf.database_id = vfs.database_id
       AND mf.file_id     = vfs.file_id
)
SELECT
    db_name                                     AS [Database],
    logical_name                                AS [Logical Name],
    physical_name                               AS [Physical Path],
    file_type                                   AS [File Type],
    file_size_mb                                AS [File Size MB],

    -- Read latency
    num_of_reads                                AS [Reads],
    read_mb                                     AS [Read MB],
    CASE
        WHEN num_of_reads = 0 THEN 0
        ELSE CAST(io_stall_read_ms * 1.0
                  / num_of_reads AS DECIMAL(10,2))
    END                                         AS [Avg Read Latency Ms],

    -- Write latency
    num_of_writes                               AS [Writes],
    write_mb                                    AS [Write MB],
    CASE
        WHEN num_of_writes = 0 THEN 0
        ELSE CAST(io_stall_write_ms * 1.0
                  / num_of_writes AS DECIMAL(10,2))
    END                                         AS [Avg Write Latency Ms],

    -- Overall latency
    total_io                                    AS [Total IO],
    CASE
        WHEN total_io = 0 THEN 0
        ELSE CAST(total_stall_ms * 1.0
                  / total_io AS DECIMAL(10,2))
    END                                         AS [Avg Latency Ms],

    -- Stall breakdown
    io_stall_read_ms / 1000                     AS [Read Stall Sec],
    io_stall_write_ms / 1000                    AS [Write Stall Sec],
    total_stall_ms / 1000                       AS [Total Stall Sec],

    -- Stall percentage
    CAST(CASE
        WHEN total_stall_ms > 0
            THEN 100.0 * io_stall_read_ms / total_stall_ms
        ELSE 0
    END AS DECIMAL(6,2))                        AS [Read Stall Pct],

    -- Latency flag
    CASE
        WHEN file_type = 'ROWS' AND total_io > 0
             AND total_stall_ms * 1.0 / total_io > 20
            THEN '*** HIGH LATENCY (>20ms) ***'
        WHEN file_type = 'LOG' AND total_io > 0
             AND total_stall_ms * 1.0 / total_io > 5
            THEN '*** HIGH LOG LATENCY (>5ms) ***'
        ELSE 'OK'
    END                                         AS [Latency Alert]

FROM FileIO
ORDER BY
    -- Show worst performers first
    CASE WHEN total_io > 0
         THEN total_stall_ms * 1.0 / total_io
         ELSE 0
    END DESC;


-- ============================================================================
-- SECTION 2: Database-Level I/O Summary
-- ============================================================================
-- Aggregate I/O per database for a quick comparison.

SELECT
    DB_NAME(vfs.database_id)                    AS [Database],
    SUM(vfs.num_of_reads)                       AS [Total Reads],
    SUM(vfs.num_of_writes)                      AS [Total Writes],
    SUM(vfs.num_of_bytes_read) / 1048576        AS [Total Read MB],
    SUM(vfs.num_of_bytes_written) / 1048576     AS [Total Write MB],
    SUM(vfs.io_stall_read_ms) / 1000            AS [Read Stall Sec],
    SUM(vfs.io_stall_write_ms) / 1000           AS [Write Stall Sec],
    SUM(vfs.io_stall) / 1000                    AS [Total Stall Sec],
    CASE
        WHEN SUM(vfs.num_of_reads + vfs.num_of_writes) = 0 THEN 0
        ELSE CAST(SUM(vfs.io_stall) * 1.0
                  / SUM(vfs.num_of_reads + vfs.num_of_writes)
                  AS DECIMAL(10,2))
    END                                         AS [Avg Latency Ms],
    -- Read vs write ratio
    CAST(CASE
        WHEN SUM(vfs.num_of_reads + vfs.num_of_writes) = 0 THEN 0
        ELSE 100.0 * SUM(vfs.num_of_reads)
             / SUM(vfs.num_of_reads + vfs.num_of_writes)
    END AS DECIMAL(6,2))                        AS [Read Pct]
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
GROUP BY vfs.database_id
ORDER BY SUM(vfs.io_stall) DESC;


-- ============================================================================
-- SECTION 3: TempDB-Specific I/O Analysis
-- ============================================================================
-- TempDB contention is common; this shows per-file I/O for tempdb only.

SELECT
    mf.name                                     AS [TempDB File],
    mf.physical_name                            AS [Physical Path],
    mf.type_desc                                AS [File Type],
    mf.size * 8 / 1024                          AS [Size MB],

    vfs.num_of_reads                            AS [Reads],
    vfs.num_of_writes                           AS [Writes],
    vfs.num_of_bytes_read / 1048576             AS [Read MB],
    vfs.num_of_bytes_written / 1048576          AS [Write MB],

    CASE
        WHEN vfs.num_of_reads = 0 THEN 0
        ELSE CAST(vfs.io_stall_read_ms * 1.0
                  / vfs.num_of_reads AS DECIMAL(10,2))
    END                                         AS [Avg Read Latency Ms],

    CASE
        WHEN vfs.num_of_writes = 0 THEN 0
        ELSE CAST(vfs.io_stall_write_ms * 1.0
                  / vfs.num_of_writes AS DECIMAL(10,2))
    END                                         AS [Avg Write Latency Ms],

    vfs.io_stall / 1000                         AS [Total Stall Sec]

FROM sys.dm_io_virtual_file_stats(2, NULL) AS vfs   -- database_id 2 = tempdb
INNER JOIN sys.master_files AS mf
    ON mf.database_id = 2
   AND mf.file_id     = vfs.file_id
ORDER BY mf.type, mf.file_id;


-- ============================================================================
-- SECTION 4: TempDB Contention — Page Latch Waits
-- ============================================================================
-- PAGELATCH waits in tempdb (especially on PFS/GAM/SGAM pages) indicate
-- allocation contention. Adding more tempdb data files often helps.

SELECT
    wt.session_id                               AS [SPID],
    wt.wait_type                                AS [Wait Type],
    wt.wait_duration_ms                         AS [Wait Ms],
    wt.resource_description                     AS [Resource],
    CASE
        WHEN wt.resource_description LIKE '2:%:1' THEN 'PFS Page'
        WHEN wt.resource_description LIKE '2:%:2' THEN 'GAM Page'
        WHEN wt.resource_description LIKE '2:%:3' THEN 'SGAM Page'
        ELSE 'Other tempdb page'
    END                                         AS [Page Type],
    r.command                                   AS [Command],
    DB_NAME(r.database_id)                      AS [Database],
    SUBSTRING(st.text, 1, 200)                  AS [Query Text (200 chars)]
FROM sys.dm_os_waiting_tasks AS wt
INNER JOIN sys.dm_exec_requests AS r
    ON r.session_id = wt.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
WHERE wt.wait_type LIKE 'PAGELATCH_%'
  AND wt.resource_description LIKE '2:%'        -- database_id 2 = tempdb
ORDER BY wt.wait_duration_ms DESC;


-- ============================================================================
-- SECTION 5: Pending I/O Requests
-- ============================================================================
-- Shows I/O operations currently in flight at the OS level.

SELECT
    pio.io_type                                 AS [IO Type],
    pio.io_pending_ms_ticks                     AS [Pending Ms],
    DB_NAME(vfs.database_id)                    AS [Database],
    mf.name                                     AS [File Name],
    mf.physical_name                            AS [Physical Path],
    mf.type_desc                                AS [File Type],
    pio.io_handle                               AS [IO Handle],
    pio.scheduler_address                       AS [Scheduler]
FROM sys.dm_io_pending_io_requests AS pio
INNER JOIN sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    ON vfs.file_handle = pio.io_handle
INNER JOIN sys.master_files AS mf
    ON mf.database_id = vfs.database_id
   AND mf.file_id     = vfs.file_id
ORDER BY pio.io_pending_ms_ticks DESC;
