/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - I/O Performance Analysis
 *
 * Purpose : Identify I/O bottlenecks at file, volume, and query levels.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. File-Level I/O Statistics
 *   2. Volume-Level I/O Statistics
 *   3. I/O Stall Analysis by Database
 *   4. Pending I/O Requests
 *   5. I/O Performance Counters
 *   6. tempdb I/O Contention
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: File-Level I/O Statistics
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    DB_NAME(vfs.database_id)                        AS database_name,
    mf.name                                         AS logical_file_name,
    mf.physical_name,
    mf.type_desc                                    AS file_type,
    mf.size * 8 / 1024                              AS file_size_mb,
    CAST(mf.growth AS BIGINT) * CASE
        WHEN mf.is_percent_growth = 1 THEN 0
        ELSE 8
    END / 1024                                      AS growth_increment_mb,
    mf.is_percent_growth,
    -- Read metrics
    vfs.num_of_reads                                AS total_reads,
    vfs.num_of_bytes_read / 1048576                 AS total_read_mb,
    vfs.io_stall_read_ms                            AS read_stall_ms,
    CAST(vfs.io_stall_read_ms * 1.0
        / NULLIF(vfs.num_of_reads, 0) AS DECIMAL(18,2))
                                                    AS avg_read_latency_ms,
    -- Write metrics
    vfs.num_of_writes                               AS total_writes,
    vfs.num_of_bytes_written / 1048576              AS total_write_mb,
    vfs.io_stall_write_ms                           AS write_stall_ms,
    CAST(vfs.io_stall_write_ms * 1.0
        / NULLIF(vfs.num_of_writes, 0) AS DECIMAL(18,2))
                                                    AS avg_write_latency_ms,
    -- Combined metrics
    vfs.io_stall                                    AS total_stall_ms,
    CAST(vfs.io_stall * 1.0
        / NULLIF(vfs.num_of_reads + vfs.num_of_writes, 0) AS DECIMAL(18,2))
                                                    AS avg_total_latency_ms,
    -- Latency health indicator
    CASE
        WHEN CAST(vfs.io_stall * 1.0
            / NULLIF(vfs.num_of_reads + vfs.num_of_writes, 0) AS DECIMAL(18,2)) < 5
        THEN 'Excellent'
        WHEN CAST(vfs.io_stall * 1.0
            / NULLIF(vfs.num_of_reads + vfs.num_of_writes, 0) AS DECIMAL(18,2)) < 10
        THEN 'Good'
        WHEN CAST(vfs.io_stall * 1.0
            / NULLIF(vfs.num_of_reads + vfs.num_of_writes, 0) AS DECIMAL(18,2)) < 20
        THEN 'Fair'
        WHEN CAST(vfs.io_stall * 1.0
            / NULLIF(vfs.num_of_reads + vfs.num_of_writes, 0) AS DECIMAL(18,2)) < 50
        THEN 'Poor'
        ELSE 'Critical'
    END                                             AS latency_assessment,
    vfs.sample_ms                                   AS sample_duration_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
INNER JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id
   AND vfs.file_id     = mf.file_id
ORDER BY vfs.io_stall DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: Volume-Level I/O Statistics
──────────────────────────────────────────────────────────────────────────────*/
SELECT DISTINCT
    vs.volume_mount_point,
    vs.logical_volume_name,
    vs.file_system_type,
    vs.total_bytes / 1073741824                     AS total_gb,
    vs.available_bytes / 1073741824                 AS available_gb,
    CAST((vs.total_bytes - vs.available_bytes) * 100.0
        / NULLIF(vs.total_bytes, 0) AS DECIMAL(5,2))
                                                    AS used_pct,
    vs.supports_compression,
    vs.supports_alternate_streams,
    vs.supports_sparse_files
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: I/O Stall Analysis by Database
  Aggregated view for quick identification of I/O-heavy databases.
──────────────────────────────────────────────────────────────────────────────*/
;WITH db_io AS (
    SELECT
        database_id,
        SUM(num_of_reads)                           AS total_reads,
        SUM(num_of_writes)                          AS total_writes,
        SUM(num_of_bytes_read) / 1048576            AS total_read_mb,
        SUM(num_of_bytes_written) / 1048576         AS total_write_mb,
        SUM(io_stall_read_ms)                       AS total_read_stall_ms,
        SUM(io_stall_write_ms)                      AS total_write_stall_ms,
        SUM(io_stall)                               AS total_stall_ms,
        SUM(num_of_reads) + SUM(num_of_writes)      AS total_io_ops
    FROM sys.dm_io_virtual_file_stats(NULL, NULL)
    GROUP BY database_id
)
SELECT
    COALESCE(DB_NAME(database_id), 'ResourceDB')    AS database_name,
    total_reads,
    total_writes,
    total_io_ops,
    total_read_mb,
    total_write_mb,
    total_read_stall_ms,
    total_write_stall_ms,
    total_stall_ms,
    CAST(total_read_stall_ms * 1.0
        / NULLIF(total_reads, 0) AS DECIMAL(18,2))
                                                    AS avg_read_latency_ms,
    CAST(total_write_stall_ms * 1.0
        / NULLIF(total_writes, 0) AS DECIMAL(18,2))
                                                    AS avg_write_latency_ms,
    CAST(total_stall_ms * 100.0
        / NULLIF(SUM(total_stall_ms) OVER (), 0) AS DECIMAL(5,2))
                                                    AS pct_of_total_stall
FROM db_io
ORDER BY total_stall_ms DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Pending I/O Requests
  Active I/O operations currently waiting for completion.
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    pior.io_type,
    pior.io_pending_ms_ticks                        AS io_pending_ms,
    DB_NAME(vfs.database_id)                        AS database_name,
    mf.name                                         AS logical_file_name,
    mf.physical_name,
    mf.type_desc                                    AS file_type,
    pior.scheduler_address
FROM sys.dm_io_pending_io_requests AS pior
INNER JOIN sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    ON pior.io_handle = vfs.file_handle
INNER JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id
   AND vfs.file_id     = mf.file_id
ORDER BY pior.io_pending_ms_ticks DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: I/O Performance Counters
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    RTRIM(object_name)                              AS counter_object,
    RTRIM(counter_name)                             AS counter_name,
    RTRIM(instance_name)                            AS instance_name,
    cntr_value                                      AS counter_value,
    cntr_type
FROM sys.dm_os_performance_counters
WHERE (
    counter_name IN (
        'Page reads/sec',
        'Page writes/sec',
        'Page lookups/sec',
        'Lazy writes/sec',
        'Checkpoint pages/sec',
        'Readahead pages/sec',
        'Page life expectancy',
        'Free list stalls/sec',
        'Log Bytes Flushed/sec',
        'Log Flush Wait Time',
        'Log Flush Waits/sec',
        'Log Flushes/sec'
    )
)
ORDER BY counter_object, counter_name, instance_name;

/*──────────────────────────────────────────────────────────────────────────────
  Section 6: tempdb I/O Contention
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    mf.name                                         AS logical_file_name,
    mf.physical_name,
    mf.type_desc                                    AS file_type,
    mf.size * 8 / 1024                              AS file_size_mb,
    vfs.num_of_reads                                AS total_reads,
    vfs.num_of_writes                               AS total_writes,
    vfs.io_stall_read_ms                            AS read_stall_ms,
    vfs.io_stall_write_ms                           AS write_stall_ms,
    CAST(vfs.io_stall_read_ms * 1.0
        / NULLIF(vfs.num_of_reads, 0) AS DECIMAL(18,2))
                                                    AS avg_read_latency_ms,
    CAST(vfs.io_stall_write_ms * 1.0
        / NULLIF(vfs.num_of_writes, 0) AS DECIMAL(18,2))
                                                    AS avg_write_latency_ms
FROM sys.dm_io_virtual_file_stats(2, NULL) AS vfs  -- database_id 2 = tempdb
INNER JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id
   AND vfs.file_id     = mf.file_id
ORDER BY mf.type, mf.file_id;

-- tempdb contention waits
SELECT
    wait_type,
    waiting_tasks_count                             AS wait_count,
    wait_time_ms                                    AS total_wait_ms,
    CAST(wait_time_ms * 1.0
        / NULLIF(waiting_tasks_count, 0) AS DECIMAL(18,2))
                                                    AS avg_wait_ms
FROM sys.dm_os_wait_stats
WHERE wait_type IN (
    'PAGELATCH_UP', 'PAGELATCH_EX', 'PAGELATCH_SH',
    'LATCH_EX', 'LATCH_SH', 'LATCH_UP'
)
AND waiting_tasks_count > 0
ORDER BY wait_time_ms DESC;
