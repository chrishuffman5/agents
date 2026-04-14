/******************************************************************************
 * 08-io-performance.sql
 * SQL Server 2019 (Compatibility Level 150) — I/O Performance Diagnostics
 *
 * Enhanced for 2019:
 *   - sys.dm_db_log_stats for transaction log analytics                [NEW]
 *   - PVS I/O impact monitoring                                       [NEW]
 *
 * Safe: read-only, no temp tables, no cursors.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — Virtual File Stats (I/O latency per file)
=============================================================================*/
;WITH FileStats AS (
    SELECT
        vfs.database_id,
        vfs.file_id,
        DB_NAME(vfs.database_id)            AS database_name,
        mf.name                             AS logical_file_name,
        mf.physical_name,
        mf.type_desc                        AS file_type,
        vfs.num_of_reads,
        vfs.num_of_writes,
        vfs.num_of_bytes_read,
        vfs.num_of_bytes_written,
        vfs.io_stall_read_ms,
        vfs.io_stall_write_ms,
        vfs.io_stall                        AS io_stall_total_ms,
        vfs.size_on_disk_bytes,
        CASE
            WHEN vfs.num_of_reads > 0
            THEN CAST(vfs.io_stall_read_ms * 1.0
                       / vfs.num_of_reads AS DECIMAL(10,2))
            ELSE 0
        END                                 AS avg_read_latency_ms,
        CASE
            WHEN vfs.num_of_writes > 0
            THEN CAST(vfs.io_stall_write_ms * 1.0
                       / vfs.num_of_writes AS DECIMAL(10,2))
            ELSE 0
        END                                 AS avg_write_latency_ms,
        CASE
            WHEN (vfs.num_of_reads + vfs.num_of_writes) > 0
            THEN CAST(vfs.io_stall * 1.0
                       / (vfs.num_of_reads + vfs.num_of_writes)
                       AS DECIMAL(10,2))
            ELSE 0
        END                                 AS avg_io_latency_ms
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    INNER JOIN sys.master_files AS mf
        ON vfs.database_id = mf.database_id
        AND vfs.file_id = mf.file_id
)
SELECT
    fs.database_name,
    fs.logical_file_name,
    fs.file_type,
    fs.physical_name,
    fs.num_of_reads,
    fs.num_of_writes,
    fs.num_of_bytes_read / 1048576          AS read_mb,
    fs.num_of_bytes_written / 1048576       AS written_mb,
    fs.avg_read_latency_ms,
    fs.avg_write_latency_ms,
    fs.avg_io_latency_ms,
    fs.io_stall_read_ms,
    fs.io_stall_write_ms,
    fs.io_stall_total_ms,
    fs.size_on_disk_bytes / 1048576         AS file_size_mb,
    CASE
        WHEN fs.avg_read_latency_ms > 50
        THEN 'HIGH read latency (> 50 ms)'
        WHEN fs.avg_read_latency_ms > 20
        THEN 'Elevated read latency (> 20 ms)'
        ELSE 'OK'
    END                                     AS read_latency_assessment,
    CASE
        WHEN fs.file_type = 'LOG' AND fs.avg_write_latency_ms > 5
        THEN 'HIGH log write latency (> 5 ms)'
        WHEN fs.file_type = 'ROWS' AND fs.avg_write_latency_ms > 20
        THEN 'Elevated data write latency (> 20 ms)'
        ELSE 'OK'
    END                                     AS write_latency_assessment
FROM FileStats AS fs
ORDER BY fs.io_stall_total_ms DESC;

/*=============================================================================
  Section 2 — Transaction Log Analytics (sys.dm_db_log_stats)          [NEW]
  Provides detailed log file metrics per database.
=============================================================================*/
SELECT
    DB_NAME(ls.database_id)                 AS database_name,
    ls.recovery_model,
    ls.log_min_lsn                          AS log_min_lsn,
    ls.log_end_lsn                          AS log_end_lsn,
    ls.current_vlf_sequence_number          AS current_vlf_seq,
    ls.current_vlf_size_mb,
    ls.total_vlf_count,
    ls.total_log_size_mb,
    ls.active_log_size_mb,
    ls.log_truncation_holdup_reason,
    ls.log_backup_time                      AS last_log_backup_time,
    ls.log_since_last_log_backup_mb         AS log_since_backup_mb,
    ls.log_since_last_checkpoint_mb         AS log_since_checkpoint_mb,
    ls.log_recovery_size_mb,
    CASE
        WHEN ls.total_vlf_count > 1000
        THEN 'HIGH VLF count (' + CAST(ls.total_vlf_count AS VARCHAR(10))
             + ') — consider shrink + regrow'
        WHEN ls.total_vlf_count > 200
        THEN 'Elevated VLF count — monitor'
        ELSE 'OK'
    END                                     AS vlf_assessment,
    CASE
        WHEN ls.log_truncation_holdup_reason <> 'NOTHING'
        THEN 'Log cannot truncate: ' + ls.log_truncation_holdup_reason
        ELSE 'No truncation holdup'
    END                                     AS truncation_assessment
FROM sys.dm_db_log_stats(DB_ID()) AS ls;

/*=============================================================================
  Section 2b — Transaction Log Stats for ALL User Databases            [NEW]
  Requires iteration via CROSS APPLY on database list.
=============================================================================*/
SELECT
    d.name                                  AS database_name,
    d.recovery_model_desc                   AS recovery_model,
    d.log_reuse_wait_desc                   AS log_reuse_wait,
    mf.size * 8 / 1024                     AS log_file_size_mb,
    CAST(FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0 / 1024
         AS DECIMAL(12,2))                  AS log_used_mb,
    CASE
        WHEN mf.size > 0
        THEN CAST(100.0 * FILEPROPERTY(mf.name, 'SpaceUsed')
                   / mf.size AS DECIMAL(5,2))
        ELSE 0
    END                                     AS log_used_pct,
    CASE
        WHEN d.log_reuse_wait_desc <> 'NOTHING'
        THEN 'WARNING: log reuse blocked by ' + d.log_reuse_wait_desc
        ELSE 'OK'
    END                                     AS log_reuse_assessment
FROM sys.databases AS d
INNER JOIN sys.master_files AS mf
    ON d.database_id = mf.database_id
WHERE mf.type_desc = 'LOG'
  AND d.state = 0
ORDER BY log_used_pct DESC;

/*=============================================================================
  Section 3 — Pending I/O Requests
=============================================================================*/
SELECT
    pior.io_type,
    pior.io_pending_ms_ticks                AS pending_ms,
    DB_NAME(vfs.database_id)                AS database_name,
    mf.name                                 AS logical_file_name,
    mf.physical_name,
    mf.type_desc                            AS file_type,
    pior.io_handle,
    pior.scheduler_address
FROM sys.dm_io_pending_io_requests AS pior
INNER JOIN sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    ON pior.io_handle = vfs.io_handle
INNER JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id
    AND vfs.file_id = mf.file_id
ORDER BY pior.io_pending_ms_ticks DESC;

/*=============================================================================
  Section 4 — I/O by Database (aggregated)
=============================================================================*/
;WITH DbIO AS (
    SELECT
        vfs.database_id,
        SUM(vfs.num_of_reads)               AS total_reads,
        SUM(vfs.num_of_writes)              AS total_writes,
        SUM(vfs.num_of_bytes_read)          AS total_bytes_read,
        SUM(vfs.num_of_bytes_written)       AS total_bytes_written,
        SUM(vfs.io_stall_read_ms)           AS total_read_stall_ms,
        SUM(vfs.io_stall_write_ms)          AS total_write_stall_ms,
        SUM(vfs.io_stall)                   AS total_io_stall_ms
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    GROUP BY vfs.database_id
)
SELECT
    DB_NAME(dio.database_id)                AS database_name,
    dio.total_reads,
    dio.total_writes,
    dio.total_bytes_read / 1073741824       AS total_read_gb,
    dio.total_bytes_written / 1073741824    AS total_write_gb,
    dio.total_io_stall_ms,
    CASE
        WHEN dio.total_reads > 0
        THEN CAST(dio.total_read_stall_ms * 1.0
                   / dio.total_reads AS DECIMAL(10,2))
        ELSE 0
    END                                     AS avg_read_latency_ms,
    CASE
        WHEN dio.total_writes > 0
        THEN CAST(dio.total_write_stall_ms * 1.0
                   / dio.total_writes AS DECIMAL(10,2))
        ELSE 0
    END                                     AS avg_write_latency_ms,
    CAST(100.0 * dio.total_io_stall_ms
         / NULLIF(SUM(dio.total_io_stall_ms) OVER (), 0)
         AS DECIMAL(5,2))                   AS pct_of_total_io_stall
FROM DbIO AS dio
ORDER BY dio.total_io_stall_ms DESC;

/*=============================================================================
  Section 5 — PVS I/O Impact Monitoring                                [NEW]
  ADR's PVS creates additional I/O; monitor its footprint.
=============================================================================*/
SELECT
    DB_NAME(pvs.database_id)                AS database_name,
    pvs.pvs_page_count,
    (pvs.pvs_page_count * 8) / 1024        AS pvs_size_mb,
    pvs.online_index_version_store_size_kb / 1024
                                            AS online_idx_pvs_mb,
    pvs.current_aborted_transaction_count   AS aborted_txn_count,
    d.is_accelerated_database_recovery_on   AS adr_enabled,
    CASE
        WHEN d.is_accelerated_database_recovery_on = 1
             AND pvs.pvs_page_count * 8 / 1024 > 5120
        THEN 'WARNING: PVS > 5 GB — may increase I/O overhead'
        WHEN d.is_accelerated_database_recovery_on = 1
        THEN 'ADR active — PVS I/O overhead expected'
        ELSE 'No ADR — no PVS I/O overhead'
    END                                     AS pvs_io_assessment
FROM sys.dm_tran_persistent_version_store_stats AS pvs
INNER JOIN sys.databases AS d
    ON pvs.database_id = d.database_id
ORDER BY pvs.pvs_page_count DESC;
