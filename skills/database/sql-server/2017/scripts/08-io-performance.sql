/******************************************************************************
* Script:   08-io-performance.sql
* Purpose:  I/O performance diagnostics including file-level latency, pending
*           I/O requests, throughput analysis, and tempdb contention checks.
* Server:   SQL Server 2017 (compatibility level 140)
* Date:     2026-04-06
*
* Safety:   Read-only. No modifications to server or databases.
******************************************************************************/
SET NOCOUNT ON;

-- ============================================================================
-- Section 1: I/O Latency per Database File
-- ============================================================================
PRINT '=== Section 1: I/O Latency per Database File ===';
PRINT '';

SELECT
    DB_NAME(vfs.database_id)                        AS [Database],
    mf.name                                         AS [Logical File Name],
    mf.type_desc                                    AS [File Type],
    mf.physical_name                                AS [Physical Path],
    vfs.num_of_reads                                AS [Reads],
    vfs.num_of_writes                               AS [Writes],
    vfs.num_of_bytes_read / 1048576                 AS [MB Read],
    vfs.num_of_bytes_written / 1048576              AS [MB Written],
    -- Read latency
    CASE
        WHEN vfs.num_of_reads = 0 THEN 0
        ELSE CAST(vfs.io_stall_read_ms / vfs.num_of_reads AS DECIMAL(10,2))
    END                                             AS [Avg Read Latency Ms],
    -- Write latency
    CASE
        WHEN vfs.num_of_writes = 0 THEN 0
        ELSE CAST(vfs.io_stall_write_ms / vfs.num_of_writes AS DECIMAL(10,2))
    END                                             AS [Avg Write Latency Ms],
    -- Overall latency
    CASE
        WHEN (vfs.num_of_reads + vfs.num_of_writes) = 0 THEN 0
        ELSE CAST(vfs.io_stall / (vfs.num_of_reads + vfs.num_of_writes) AS DECIMAL(10,2))
    END                                             AS [Avg Overall Latency Ms],
    vfs.io_stall_read_ms                            AS [Total Read Stall Ms],
    vfs.io_stall_write_ms                           AS [Total Write Stall Ms],
    vfs.io_stall                                    AS [Total I/O Stall Ms],
    -- Assessment
    CASE
        WHEN vfs.num_of_reads > 0
         AND vfs.io_stall_read_ms / vfs.num_of_reads > 50
        THEN 'SLOW READS (> 50 ms avg)'
        WHEN vfs.num_of_reads > 0
         AND vfs.io_stall_read_ms / vfs.num_of_reads > 20
        THEN 'MODERATE READ LATENCY (> 20 ms avg)'
        ELSE 'OK'
    END                                             AS [Read Assessment],
    CASE
        WHEN mf.type_desc = 'LOG'
         AND vfs.num_of_writes > 0
         AND vfs.io_stall_write_ms / vfs.num_of_writes > 5
        THEN 'SLOW LOG WRITES (> 5 ms avg) -- critical for OLTP'
        WHEN vfs.num_of_writes > 0
         AND vfs.io_stall_write_ms / vfs.num_of_writes > 20
        THEN 'SLOW DATA WRITES (> 20 ms avg)'
        ELSE 'OK'
    END                                             AS [Write Assessment]
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
JOIN sys.master_files mf
    ON vfs.database_id = mf.database_id
   AND vfs.file_id = mf.file_id
ORDER BY vfs.io_stall DESC;

-- ============================================================================
-- Section 2: I/O Latency Summary by Database
-- ============================================================================
PRINT '';
PRINT '=== Section 2: I/O Latency Summary by Database ===';
PRINT '';

;WITH FileStats AS (
    SELECT
        vfs.database_id,
        mf.type_desc,
        SUM(vfs.num_of_reads)                       AS total_reads,
        SUM(vfs.num_of_writes)                      AS total_writes,
        SUM(vfs.num_of_bytes_read)                  AS total_bytes_read,
        SUM(vfs.num_of_bytes_written)               AS total_bytes_written,
        SUM(vfs.io_stall_read_ms)                   AS total_read_stall,
        SUM(vfs.io_stall_write_ms)                  AS total_write_stall,
        SUM(vfs.io_stall)                           AS total_stall
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
    JOIN sys.master_files mf
        ON vfs.database_id = mf.database_id
       AND vfs.file_id = mf.file_id
    GROUP BY vfs.database_id, mf.type_desc
)
SELECT
    DB_NAME(database_id)                            AS [Database],
    type_desc                                       AS [File Type],
    total_reads                                     AS [Total Reads],
    total_writes                                    AS [Total Writes],
    total_bytes_read / 1048576                      AS [Total Read MB],
    total_bytes_written / 1048576                   AS [Total Write MB],
    CASE WHEN total_reads = 0 THEN 0
         ELSE CAST(total_read_stall / total_reads AS DECIMAL(10,2))
    END                                             AS [Avg Read Latency Ms],
    CASE WHEN total_writes = 0 THEN 0
         ELSE CAST(total_write_stall / total_writes AS DECIMAL(10,2))
    END                                             AS [Avg Write Latency Ms]
FROM FileStats
ORDER BY total_stall DESC;

-- ============================================================================
-- Section 3: Pending I/O Requests
-- ============================================================================
PRINT '';
PRINT '=== Section 3: Pending I/O Requests ===';
PRINT '';

SELECT
    io.io_type                                      AS [I/O Type],
    io.io_pending_ms_ticks                          AS [Pending Ms],
    DB_NAME(vfs.database_id)                        AS [Database],
    mf.name                                         AS [File Name],
    mf.physical_name                                AS [Physical Path],
    mf.type_desc                                    AS [File Type],
    io.io_handle                                    AS [I/O Handle],
    io.scheduler_address                            AS [Scheduler]
FROM sys.dm_io_pending_io_requests io
JOIN sys.dm_io_virtual_file_stats(NULL, NULL) vfs
    ON io.io_handle = vfs.file_handle
JOIN sys.master_files mf
    ON vfs.database_id = mf.database_id
   AND vfs.file_id = mf.file_id
ORDER BY io.io_pending_ms_ticks DESC;

-- If no pending I/O, note this
IF NOT EXISTS (SELECT 1 FROM sys.dm_io_pending_io_requests)
    PRINT 'No pending I/O requests at this time.';

-- ============================================================================
-- Section 4: I/O-Related Wait Statistics
-- ============================================================================
PRINT '';
PRINT '=== Section 4: I/O-Related Wait Statistics ===';
PRINT '';

SELECT
    wait_type                                       AS [Wait Type],
    waiting_tasks_count                             AS [Wait Count],
    CAST(wait_time_ms / 1000.0 AS DECIMAL(18,2))   AS [Total Wait Sec],
    CAST((wait_time_ms - signal_wait_time_ms) / 1000.0
        AS DECIMAL(18,2))                           AS [Resource Wait Sec],
    CAST((wait_time_ms - signal_wait_time_ms)
        / NULLIF(waiting_tasks_count, 0)
        AS DECIMAL(18,2))                           AS [Avg Resource Wait Ms],
    CASE wait_type
        WHEN 'PAGEIOLATCH_SH'
            THEN 'Data page read from disk (shared latch)'
        WHEN 'PAGEIOLATCH_EX'
            THEN 'Data page read from disk (exclusive latch)'
        WHEN 'PAGEIOLATCH_UP'
            THEN 'Data page read from disk (update latch)'
        WHEN 'WRITELOG'
            THEN 'Transaction log write -- critical for OLTP throughput'
        WHEN 'IO_COMPLETION'
            THEN 'Non-data page I/O (sort, hash, bitmap, etc.)'
        WHEN 'ASYNC_IO_COMPLETION'
            THEN 'Asynchronous I/O operation'
        WHEN 'BACKUPIO'
            THEN 'Backup I/O operation'
        WHEN 'LOGBUFFER'
            THEN 'Waiting for log buffer space -- log write bottleneck'
        ELSE ''
    END                                             AS [Description]
FROM sys.dm_os_wait_stats
WHERE wait_type IN (
    'PAGEIOLATCH_SH', 'PAGEIOLATCH_EX', 'PAGEIOLATCH_UP',
    'PAGEIOLATCH_NL', 'PAGEIOLATCH_DT', 'PAGEIOLATCH_KP',
    'WRITELOG', 'IO_COMPLETION', 'ASYNC_IO_COMPLETION',
    'BACKUPIO', 'LOGBUFFER', 'WRITE_COMPLETION'
)
AND waiting_tasks_count > 0
ORDER BY wait_time_ms DESC;

-- ============================================================================
-- Section 5: Tempdb I/O and Contention
-- ============================================================================
PRINT '';
PRINT '=== Section 5: Tempdb I/O and Contention ===';
PRINT '';

-- Tempdb file layout
SELECT
    mf.name                                         AS [File Name],
    mf.physical_name                                AS [Physical Path],
    mf.type_desc                                    AS [Type],
    CAST(mf.size * 8.0 / 1024 AS DECIMAL(12,2))    AS [Size MB],
    CASE mf.is_percent_growth
        WHEN 1 THEN CAST(mf.growth AS VARCHAR(10)) + '%'
        ELSE CAST(CAST(mf.growth * 8.0 / 1024 AS DECIMAL(12,2)) AS VARCHAR(20)) + ' MB'
    END                                             AS [Growth]
FROM sys.master_files mf
WHERE mf.database_id = 2  -- tempdb
ORDER BY mf.type, mf.file_id;

-- Tempdb data file count check
SELECT
    COUNT(*) AS [Tempdb Data Files],
    (SELECT cpu_count FROM sys.dm_os_sys_info) AS [CPU Count],
    CASE
        WHEN COUNT(*) < CASE
            WHEN (SELECT cpu_count FROM sys.dm_os_sys_info) <= 8
            THEN (SELECT cpu_count FROM sys.dm_os_sys_info)
            ELSE 8
        END
        THEN 'RECOMMENDATION: Add more tempdb data files (rule: 1 per core up to 8)'
        ELSE 'OK -- Sufficient tempdb data files'
    END AS [Assessment]
FROM sys.master_files
WHERE database_id = 2 AND type = 0;

-- Tempdb contention (PAGELATCH waits on allocation pages)
PRINT '';
PRINT '--- Tempdb Allocation Contention ---';
PRINT '';

SELECT
    wait_type                                       AS [Wait Type],
    waiting_tasks_count                             AS [Wait Count],
    CAST(wait_time_ms / 1000.0 AS DECIMAL(18,2))   AS [Total Wait Sec],
    CAST((wait_time_ms - signal_wait_time_ms)
        / NULLIF(waiting_tasks_count, 0)
        AS DECIMAL(18,2))                           AS [Avg Wait Ms],
    'tempdb allocation contention indicator'        AS [Note]
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('PAGELATCH_UP', 'PAGELATCH_EX', 'PAGELATCH_SH')
  AND waiting_tasks_count > 0
ORDER BY wait_time_ms DESC;

-- ============================================================================
-- Section 6: I/O Throughput over Time (Snapshot Comparison)
-- ============================================================================
PRINT '';
PRINT '=== Section 6: Cumulative I/O Statistics per Drive ===';
PRINT '';

;WITH DriveStats AS (
    SELECT
        LEFT(mf.physical_name, 1)                   AS drive_letter,
        SUM(vfs.num_of_reads)                       AS total_reads,
        SUM(vfs.num_of_writes)                      AS total_writes,
        SUM(vfs.num_of_bytes_read) / 1073741824     AS total_gb_read,
        SUM(vfs.num_of_bytes_written) / 1073741824  AS total_gb_written,
        SUM(vfs.io_stall_read_ms)                   AS total_read_stall,
        SUM(vfs.io_stall_write_ms)                  AS total_write_stall
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
    JOIN sys.master_files mf
        ON vfs.database_id = mf.database_id
       AND vfs.file_id = mf.file_id
    GROUP BY LEFT(mf.physical_name, 1)
)
SELECT
    drive_letter + ':\'                             AS [Drive],
    total_reads                                     AS [Total Reads],
    total_writes                                    AS [Total Writes],
    total_gb_read                                   AS [Total GB Read],
    total_gb_written                                AS [Total GB Written],
    CASE WHEN total_reads = 0 THEN 0
         ELSE CAST(total_read_stall / total_reads AS DECIMAL(10,2))
    END                                             AS [Avg Read Latency Ms],
    CASE WHEN total_writes = 0 THEN 0
         ELSE CAST(total_write_stall / total_writes AS DECIMAL(10,2))
    END                                             AS [Avg Write Latency Ms]
FROM DriveStats
ORDER BY drive_letter;

-- ============================================================================
-- Section 7: Transaction Log I/O Performance
-- ============================================================================
PRINT '';
PRINT '=== Section 7: Transaction Log I/O Performance ===';
PRINT '';

SELECT
    DB_NAME(vfs.database_id)                        AS [Database],
    mf.physical_name                                AS [Log File Path],
    vfs.num_of_writes                               AS [Log Writes],
    vfs.num_of_bytes_written / 1048576              AS [Log MB Written],
    CASE WHEN vfs.num_of_writes = 0 THEN 0
         ELSE CAST(vfs.io_stall_write_ms / vfs.num_of_writes AS DECIMAL(10,2))
    END                                             AS [Avg Log Write Latency Ms],
    vfs.io_stall_write_ms                           AS [Total Log Write Stall Ms],
    CASE
        WHEN vfs.num_of_writes > 0
         AND vfs.io_stall_write_ms / vfs.num_of_writes > 5
        THEN 'SLOW -- Log write latency > 5 ms (impacts OLTP commit rate)'
        WHEN vfs.num_of_writes > 0
         AND vfs.io_stall_write_ms / vfs.num_of_writes > 2
        THEN 'MODERATE -- Log write latency > 2 ms'
        ELSE 'GOOD'
    END                                             AS [Assessment],
    d.log_reuse_wait_desc                           AS [Log Reuse Wait]
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
JOIN sys.master_files mf
    ON vfs.database_id = mf.database_id
   AND vfs.file_id = mf.file_id
JOIN sys.databases d
    ON vfs.database_id = d.database_id
WHERE mf.type_desc = 'LOG'
ORDER BY vfs.io_stall_write_ms DESC;

-- ============================================================================
-- Section 8: Volume/Disk Free Space
-- ============================================================================
PRINT '';
PRINT '=== Section 8: Volume Free Space ===';
PRINT '';

SELECT DISTINCT
    vs.volume_mount_point                           AS [Mount Point],
    vs.logical_volume_name                          AS [Volume Name],
    vs.file_system_type                             AS [File System],
    CAST(vs.total_bytes / 1073741824.0
        AS DECIMAL(12,2))                           AS [Total Size GB],
    CAST(vs.available_bytes / 1073741824.0
        AS DECIMAL(12,2))                           AS [Free Space GB],
    CAST(100.0 * vs.available_bytes / NULLIF(vs.total_bytes, 0)
        AS DECIMAL(5,2))                            AS [Free Pct],
    CASE
        WHEN 100.0 * vs.available_bytes / NULLIF(vs.total_bytes, 0) < 5
        THEN 'CRITICAL -- Less than 5% free'
        WHEN 100.0 * vs.available_bytes / NULLIF(vs.total_bytes, 0) < 15
        THEN 'WARNING -- Less than 15% free'
        ELSE 'OK'
    END                                             AS [Assessment]
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
ORDER BY vs.volume_mount_point;

PRINT '';
PRINT '=== I/O Performance Analysis Complete ===';
