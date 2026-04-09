/******************************************************************************
 * 12-adr-pvs-health.sql
 * SQL Server 2019 (Compatibility Level 150) — Accelerated Database Recovery
 *
 * NEW for SQL Server 2019:
 *   This entire script is new. ADR fundamentally changes the recovery
 *   architecture by introducing a Persistent Version Store (PVS) within
 *   each database (instead of tempdb version store).
 *
 * Covers:
 *   - ADR configuration per database                                   [NEW]
 *   - PVS size and growth monitoring                                   [NEW]
 *   - PVS cleanup status and health                                    [NEW]
 *   - Version store space: tempdb vs PVS comparison                    [NEW]
 *   - Aborted transaction tracking                                     [NEW]
 *   - ADR wait type analysis                                           [NEW]
 *   - Recovery performance impact                                      [NEW]
 *
 * Safe: read-only, no temp tables, no cursors.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — ADR Configuration per Database                           [NEW]
=============================================================================*/
SELECT
    d.database_id,
    d.name                                  AS database_name,
    d.state_desc                            AS database_state,
    d.recovery_model_desc                   AS recovery_model,
    d.is_accelerated_database_recovery_on   AS adr_enabled,
    d.compatibility_level,
    CASE
        WHEN d.is_accelerated_database_recovery_on = 1
        THEN 'ADR ON: Instant rollback, fast recovery, PVS in use'
        ELSE 'ADR OFF: Traditional ARIES recovery model'
    END                                     AS adr_description,
    CASE
        WHEN d.is_accelerated_database_recovery_on = 0
             AND d.state = 0
        THEN 'ALTER DATABASE [' + d.name
             + '] SET ACCELERATED_DATABASE_RECOVERY = ON;'
        ELSE NULL
    END                                     AS enable_adr_ddl
FROM sys.databases AS d
WHERE d.database_id > 4   /* Skip system databases */
ORDER BY d.name;

/*=============================================================================
  Section 2 — Persistent Version Store (PVS) Size & Growth             [NEW]
=============================================================================*/
SELECT
    DB_NAME(pvs.database_id)                AS database_name,
    pvs.pvs_page_count,
    (pvs.pvs_page_count * 8)               AS pvs_size_kb,
    (pvs.pvs_page_count * 8) / 1024        AS pvs_size_mb,
    CAST((pvs.pvs_page_count * 8) / 1048576.0
         AS DECIMAL(12,2))                  AS pvs_size_gb,
    pvs.online_index_version_store_size_kb,
    pvs.online_index_version_store_size_kb / 1024
                                            AS online_idx_pvs_mb,
    pvs.current_aborted_transaction_count   AS aborted_txn_count,
    pvs.oldest_active_transaction_tsn       AS oldest_active_tsn,
    pvs.oldest_aborted_transaction_tsn      AS oldest_aborted_tsn,
    /* Size assessments */
    CASE
        WHEN pvs.pvs_page_count * 8 / 1024 > 51200
        THEN 'CRITICAL: PVS > 50 GB — immediate investigation needed'
        WHEN pvs.pvs_page_count * 8 / 1024 > 10240
        THEN 'WARNING: PVS > 10 GB — check for long-running transactions'
        WHEN pvs.pvs_page_count * 8 / 1024 > 1024
        THEN 'MONITOR: PVS > 1 GB — normal for active workloads'
        ELSE 'OK: PVS within normal range'
    END                                     AS pvs_size_assessment,
    /* Compare PVS to database size */
    CAST(pvs.pvs_page_count * 8.0
         / NULLIF((
             SELECT SUM(mf.size) * 8
             FROM sys.master_files AS mf
             WHERE mf.database_id = pvs.database_id
               AND mf.type = 0
         ), 0) * 100 AS DECIMAL(5,2))       AS pvs_pct_of_data_files
FROM sys.dm_tran_persistent_version_store_stats AS pvs
ORDER BY pvs.pvs_page_count DESC;

/*=============================================================================
  Section 3 — PVS Cleanup Status & Health                              [NEW]
=============================================================================*/
SELECT
    DB_NAME(pvs.database_id)                AS database_name,
    pvs.aborted_version_cleaner_start_time  AS cleanup_start_time,
    pvs.aborted_version_cleaner_end_time    AS cleanup_end_time,
    CASE
        WHEN pvs.aborted_version_cleaner_end_time IS NULL
             AND pvs.aborted_version_cleaner_start_time IS NOT NULL
        THEN 'IN PROGRESS'
        WHEN pvs.aborted_version_cleaner_end_time IS NOT NULL
        THEN 'COMPLETED'
        ELSE 'NOT STARTED'
    END                                     AS cleanup_status,
    DATEDIFF(
        SECOND,
        pvs.aborted_version_cleaner_start_time,
        ISNULL(pvs.aborted_version_cleaner_end_time, GETDATE())
    )                                       AS cleanup_duration_sec,
    pvs.current_aborted_transaction_count   AS aborted_txn_count,
    pvs.oldest_aborted_transaction_tsn      AS oldest_aborted_tsn,
    CASE
        WHEN pvs.current_aborted_transaction_count > 100
        THEN 'WARNING: High aborted transaction count — cleanup may be lagging'
        WHEN pvs.current_aborted_transaction_count > 10
        THEN 'MONITOR: Multiple aborted transactions pending cleanup'
        ELSE 'OK'
    END                                     AS cleanup_assessment,
    /* Check if cleanup is making progress */
    CASE
        WHEN pvs.aborted_version_cleaner_start_time IS NOT NULL
             AND pvs.aborted_version_cleaner_end_time IS NULL
             AND DATEDIFF(MINUTE, pvs.aborted_version_cleaner_start_time, GETDATE()) > 30
        THEN 'WARNING: Cleanup running > 30 minutes'
        ELSE 'OK'
    END                                     AS cleanup_duration_assessment
FROM sys.dm_tran_persistent_version_store_stats AS pvs;

/*=============================================================================
  Section 4 — Version Store Space: tempdb vs PVS Comparison            [NEW]
  Shows how ADR shifts version store from tempdb to in-database PVS.
=============================================================================*/

/* Tempdb version store usage */
SELECT
    'tempdb'                                AS store_location,
    'Version Store'                         AS store_type,
    SUM(version_store_reserved_page_count) * 8 / 1024
                                            AS size_mb,
    NULL                                    AS database_name
FROM sys.dm_db_file_space_usage
WHERE database_id = 2

UNION ALL

/* PVS per ADR-enabled database */
SELECT
    'In-Database PVS'                       AS store_location,
    'Persistent Version Store (ADR)'        AS store_type,
    (pvs.pvs_page_count * 8) / 1024        AS size_mb,
    DB_NAME(pvs.database_id)                AS database_name
FROM sys.dm_tran_persistent_version_store_stats AS pvs
WHERE pvs.pvs_page_count > 0

ORDER BY size_mb DESC;

/*=============================================================================
  Section 5 — Aborted Transaction Detail                               [NEW]
=============================================================================*/
SELECT
    DB_NAME(pvs.database_id)                AS database_name,
    pvs.current_aborted_transaction_count   AS aborted_count,
    pvs.oldest_aborted_transaction_tsn      AS oldest_aborted_tsn,
    pvs.oldest_active_transaction_tsn       AS oldest_active_tsn,
    pvs.pvs_page_count,
    (pvs.pvs_page_count * 8) / 1024        AS pvs_mb,
    /* Active transactions preventing PVS cleanup */
    CASE
        WHEN pvs.oldest_active_transaction_tsn IS NOT NULL
             AND pvs.oldest_active_transaction_tsn < pvs.oldest_aborted_transaction_tsn
        THEN 'Active transaction blocking PVS cleanup'
        ELSE 'No active transaction blocking cleanup'
    END                                     AS active_txn_impact
FROM sys.dm_tran_persistent_version_store_stats AS pvs
WHERE pvs.current_aborted_transaction_count > 0
ORDER BY pvs.current_aborted_transaction_count DESC;

/* Active transactions that may prevent PVS cleanup */
SELECT
    tat.transaction_id,
    tat.name                                AS transaction_name,
    tat.transaction_begin_time,
    DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE())
                                            AS transaction_age_sec,
    CASE tat.transaction_type
        WHEN 1 THEN 'Read/Write'
        WHEN 2 THEN 'Read-Only'
        WHEN 3 THEN 'System'
        WHEN 4 THEN 'Distributed'
        ELSE CAST(tat.transaction_type AS VARCHAR(10))
    END                                     AS transaction_type,
    CASE tat.transaction_state
        WHEN 0 THEN 'Not initialized'
        WHEN 1 THEN 'Initialized'
        WHEN 2 THEN 'Active'
        WHEN 3 THEN 'Ended (read-only)'
        WHEN 4 THEN 'Commit initiated'
        WHEN 5 THEN 'Prepared'
        WHEN 6 THEN 'Committed'
        WHEN 7 THEN 'Rolling back'
        WHEN 8 THEN 'Rolled back'
        ELSE CAST(tat.transaction_state AS VARCHAR(10))
    END                                     AS transaction_state,
    tst.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    st.text                                 AS last_query_text
FROM sys.dm_tran_active_transactions AS tat
INNER JOIN sys.dm_tran_session_transactions AS tst
    ON tat.transaction_id = tst.transaction_id
INNER JOIN sys.dm_exec_sessions AS s
    ON tst.session_id = s.session_id
LEFT JOIN sys.dm_exec_requests AS r
    ON tst.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
WHERE tat.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE())
ORDER BY tat.transaction_begin_time ASC;

/*=============================================================================
  Section 6 — ADR-Related Wait Types                                   [NEW]
=============================================================================*/
SELECT
    ws.wait_type,
    ws.waiting_tasks_count                  AS task_count,
    ws.wait_time_ms                         AS total_wait_ms,
    ws.wait_time_ms - ws.signal_wait_time_ms AS resource_wait_ms,
    ws.signal_wait_time_ms,
    ws.max_wait_time_ms,
    CASE
        WHEN ws.waiting_tasks_count > 0
        THEN CAST(ws.wait_time_ms * 1.0
                   / ws.waiting_tasks_count AS DECIMAL(18,2))
        ELSE 0
    END                                     AS avg_wait_ms,
    CASE
        WHEN ws.wait_type LIKE 'PVS_%'
        THEN 'PVS internal operation'
        WHEN ws.wait_type LIKE 'VERSIONED_%'
        THEN 'Version store access'
        WHEN ws.wait_type LIKE 'ADR_%'
        THEN 'ADR core operation'
        ELSE 'Related wait'
    END                                     AS wait_description
FROM sys.dm_os_wait_stats AS ws
WHERE (
    ws.wait_type LIKE 'PVS_%'
    OR ws.wait_type LIKE 'VERSIONED_%'
    OR ws.wait_type LIKE 'ADR_%'
    OR ws.wait_type IN (
        'PERSISTENT_VERSION_STORE',
        'VERSION_STORE_CLEANUP'
    )
)
AND ws.waiting_tasks_count > 0
ORDER BY ws.wait_time_ms DESC;

/*=============================================================================
  Section 7 — ADR Recovery Performance Impact                          [NEW]
  Compares recovery characteristics for ADR vs non-ADR databases.
=============================================================================*/
SELECT
    d.name                                  AS database_name,
    d.is_accelerated_database_recovery_on   AS adr_enabled,
    d.recovery_model_desc                   AS recovery_model,
    d.log_reuse_wait_desc                   AS log_reuse_wait,
    mf_log.size * 8 / 1024                 AS log_size_mb,
    pvs.pvs_page_count,
    ISNULL((pvs.pvs_page_count * 8) / 1024, 0)
                                            AS pvs_mb,
    CASE
        WHEN d.is_accelerated_database_recovery_on = 1
        THEN 'Instant rollback, constant-time recovery regardless of txn size'
        ELSE 'Recovery time proportional to longest active transaction'
    END                                     AS recovery_characteristic,
    CASE
        WHEN d.is_accelerated_database_recovery_on = 1
             AND d.log_reuse_wait_desc = 'ACTIVE_TRANSACTION'
        THEN 'Note: ADR does not eliminate ACTIVE_TRANSACTION log reuse wait'
        WHEN d.is_accelerated_database_recovery_on = 1
             AND d.log_reuse_wait_desc <> 'NOTHING'
        THEN 'Log reuse wait: ' + d.log_reuse_wait_desc
        ELSE 'OK'
    END                                     AS log_reuse_note
FROM sys.databases AS d
LEFT JOIN sys.master_files AS mf_log
    ON d.database_id = mf_log.database_id
    AND mf_log.type_desc = 'LOG'
LEFT JOIN sys.dm_tran_persistent_version_store_stats AS pvs
    ON d.database_id = pvs.database_id
WHERE d.state = 0
  AND d.database_id > 4
ORDER BY d.name;

/*=============================================================================
  Section 8 — PVS Space Reclamation Trigger                            [NEW]
  Generates the command to manually trigger PVS cleanup if needed.
  NOTE: This section only generates the DDL; it does NOT execute it.
=============================================================================*/
SELECT
    DB_NAME(pvs.database_id)                AS database_name,
    (pvs.pvs_page_count * 8) / 1024        AS pvs_mb,
    pvs.current_aborted_transaction_count   AS aborted_count,
    CASE
        WHEN pvs.pvs_page_count * 8 / 1024 > 5120
             OR pvs.current_aborted_transaction_count > 50
        THEN 'EXEC sys.sp_persistent_version_cleanup @dbname = N'''
             + DB_NAME(pvs.database_id) + ''';'
        ELSE 'No cleanup needed at this time'
    END                                     AS cleanup_command,
    CASE
        WHEN pvs.pvs_page_count * 8 / 1024 > 5120
        THEN 'PVS exceeds 5 GB threshold'
        WHEN pvs.current_aborted_transaction_count > 50
        THEN 'High aborted transaction count'
        ELSE 'Within normal parameters'
    END                                     AS cleanup_reason
FROM sys.dm_tran_persistent_version_store_stats AS pvs
ORDER BY pvs.pvs_page_count DESC;
