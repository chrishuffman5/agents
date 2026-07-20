/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - I/O Performance Diagnostics
 *
 * Purpose : Analyze disk I/O performance across database files.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. File-Level I/O Statistics
 *   2. I/O Latency by File
 *   3. Pending I/O Requests
 *   4. I/O Performance Counters
 *   5. Database File Autogrowth Events
 *   6. Volume-Level Space Summary
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: File-Level I/O Statistics
------------------------------------------------------------------------------*/
SELECT
    DB_NAME(vfs.database_id)                        AS database_name,
    mf.name                                         AS logical_file_name,
    mf.physical_name,
    mf.type_desc                                    AS file_type,
    vfs.num_of_reads,
    vfs.num_of_writes,
    vfs.num_of_bytes_read / 1024 / 1024             AS mb_read,
    vfs.num_of_bytes_written / 1024 / 1024          AS mb_written,
    vfs.io_stall_read_ms,
    vfs.io_stall_write_ms,
    vfs.io_stall                                    AS total_io_stall_ms,
    vfs.size_on_disk_bytes / 1024 / 1024            AS size_on_disk_mb,
    -- Calculated averages
    CASE WHEN vfs.num_of_reads > 0
        THEN CAST(vfs.io_stall_read_ms * 1.0
            / vfs.num_of_reads AS DECIMAL(18,2))
        ELSE 0
    END                                             AS avg_read_latency_ms,
    CASE WHEN vfs.num_of_writes > 0
        THEN CAST(vfs.io_stall_write_ms * 1.0
            / vfs.num_of_writes AS DECIMAL(18,2))
        ELSE 0
    END                                             AS avg_write_latency_ms,
    CASE WHEN (vfs.num_of_reads + vfs.num_of_writes) > 0
        THEN CAST(vfs.io_stall * 1.0
            / (vfs.num_of_reads + vfs.num_of_writes) AS DECIMAL(18,2))
        ELSE 0
    END                                             AS avg_io_latency_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
INNER JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id
   AND vfs.file_id     = mf.file_id
ORDER BY vfs.io_stall DESC;

/*------------------------------------------------------------------------------
  Section 2: I/O Latency by File (color-coded thresholds)
  Latency thresholds: < 10ms = Good, 10-20ms = Warning, > 20ms = Critical
------------------------------------------------------------------------------*/
SELECT
    DB_NAME(vfs.database_id)                        AS database_name,
    mf.name                                         AS logical_file_name,
    mf.type_desc                                    AS file_type,
    -- Read latency
    CASE WHEN vfs.num_of_reads > 0
        THEN CAST(vfs.io_stall_read_ms * 1.0
            / vfs.num_of_reads AS DECIMAL(18,2))
        ELSE 0
    END                                             AS avg_read_latency_ms,
    CASE
        WHEN vfs.num_of_reads = 0 THEN 'N/A'
        WHEN vfs.io_stall_read_ms * 1.0 / vfs.num_of_reads < 10 THEN 'GOOD'
        WHEN vfs.io_stall_read_ms * 1.0 / vfs.num_of_reads < 20 THEN 'WARNING'
        ELSE 'CRITICAL'
    END                                             AS read_latency_status,
    -- Write latency
    CASE WHEN vfs.num_of_writes > 0
        THEN CAST(vfs.io_stall_write_ms * 1.0
            / vfs.num_of_writes AS DECIMAL(18,2))
        ELSE 0
    END                                             AS avg_write_latency_ms,
    CASE
        WHEN vfs.num_of_writes = 0 THEN 'N/A'
        WHEN vfs.io_stall_write_ms * 1.0 / vfs.num_of_writes < 10 THEN 'GOOD'
        WHEN vfs.io_stall_write_ms * 1.0 / vfs.num_of_writes < 20 THEN 'WARNING'
        ELSE 'CRITICAL'
    END                                             AS write_latency_status,
    vfs.num_of_reads + vfs.num_of_writes            AS total_io_operations
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
INNER JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id
   AND vfs.file_id     = mf.file_id
WHERE vfs.num_of_reads + vfs.num_of_writes > 0
ORDER BY avg_io_latency_ms DESC;

/*------------------------------------------------------------------------------
  Section 3: Pending I/O Requests
  Shows in-flight I/O operations.
------------------------------------------------------------------------------*/
SELECT
    DB_NAME(pio.io_handle_database_id)              AS database_name,
    mf.name                                         AS logical_file_name,
    mf.physical_name,
    mf.type_desc                                    AS file_type,
    pio.io_pending_ms_ticks                         AS pending_ms,
    pio.io_type,
    pio.scheduler_address
FROM sys.dm_io_pending_io_requests AS pio
LEFT JOIN sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    ON pio.io_handle = vfs.file_handle
LEFT JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id
   AND vfs.file_id     = mf.file_id
ORDER BY pio.io_pending_ms_ticks DESC;

/*------------------------------------------------------------------------------
  Section 4: I/O Performance Counters
------------------------------------------------------------------------------*/
SELECT
    object_name,
    counter_name,
    instance_name,
    cntr_value,
    cntr_type
FROM sys.dm_os_performance_counters
WHERE (object_name LIKE '%Buffer Manager%'
       AND counter_name IN (
           'Page reads/sec',
           'Page writes/sec',
           'Lazy writes/sec',
           'Checkpoint pages/sec',
           'Free list stalls/sec',
           'Page life expectancy',
           'Buffer cache hit ratio',
           'Readahead pages/sec'
       ))
   OR (object_name LIKE '%Databases%'
       AND counter_name IN (
           'Log Flushes/sec',
           'Log Flush Wait Time',
           'Log Bytes Flushed/sec'
       )
       AND instance_name NOT IN ('_Total', 'mssqlsystemresource'))
ORDER BY object_name, counter_name, instance_name;

/*------------------------------------------------------------------------------
  Section 5: Database File Autogrowth Events (from default trace)
  Frequent autogrowths indicate undersized files.
------------------------------------------------------------------------------*/
;WITH autogrow AS (
    SELECT
        DB_NAME(dbe.database_id)                    AS database_name,
        dbe.file_name                               AS logical_file_name,
        dbe.event_class,
        CASE dbe.event_class
            WHEN 92 THEN 'Data File Auto Grow'
            WHEN 93 THEN 'Log File Auto Grow'
            ELSE 'Unknown'
        END                                         AS event_type,
        dbe.duration / 1000                         AS duration_ms,
        dbe.start_time,
        dbe.integer_data * 8 / 1024                 AS growth_mb
    FROM (
        SELECT
            database_id,
            [file_name],
            event_class,
            duration,
            start_time,
            integer_data
        FROM sys.fn_trace_gettable(
            (SELECT REVERSE(SUBSTRING(REVERSE(path),
                CHARINDEX(N'\', REVERSE(path)), 260)) + N'log.trc'
             FROM sys.traces WHERE is_default = 1), DEFAULT)
        WHERE event_class IN (92, 93)
    ) AS dbe
)
SELECT TOP (50)
    database_name,
    logical_file_name,
    event_type,
    duration_ms,
    growth_mb,
    start_time
FROM autogrow
ORDER BY start_time DESC;

/*------------------------------------------------------------------------------
  Section 6: Volume-Level Space Summary
------------------------------------------------------------------------------*/
SELECT DISTINCT
    vs.volume_mount_point,
    vs.logical_volume_name,
    vs.file_system_type,
    vs.total_bytes / 1024 / 1024 / 1024             AS total_gb,
    vs.available_bytes / 1024 / 1024 / 1024          AS available_gb,
    CAST((vs.total_bytes - vs.available_bytes) * 100.0
        / NULLIF(vs.total_bytes, 0) AS DECIMAL(5,2))
                                                    AS used_pct,
    CASE
        WHEN vs.available_bytes * 100.0 / NULLIF(vs.total_bytes, 0) < 10
        THEN 'CRITICAL: < 10% free'
        WHEN vs.available_bytes * 100.0 / NULLIF(vs.total_bytes, 0) < 20
        THEN 'WARNING: < 20% free'
        ELSE 'OK'
    END                                             AS space_status
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs
ORDER BY vs.volume_mount_point;
