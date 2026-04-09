/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - ADR & PVS Health Diagnostics
 *
 * Purpose : Monitor Accelerated Database Recovery and Persistent Version Store.
 *           ADR is now more critical in 2025: optimized locking requires ADR.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. ADR Configuration per Database
 *   2. Optimized Locking Readiness Check (NEW in 2025)
 *   3. PVS Size and Growth
 *   4. PVS Cleanup Status
 *   5. Version Store Transactions
 *   6. ADR Recovery Performance Indicators
 *   7. PVS File Usage
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: ADR Configuration per Database
  ADR is required for optimized locking in SQL Server 2025.
------------------------------------------------------------------------------*/
SELECT
    d.database_id,
    d.name                                          AS database_name,
    d.state_desc                                    AS state,
    d.recovery_model_desc                           AS recovery_model,
    d.is_accelerated_database_recovery_on           AS adr_enabled,
    d.is_read_committed_snapshot_on                 AS rcsi_enabled,
    d.is_optimized_locking_on                       AS optimized_locking,      -- NEW in 2025
    CASE
        WHEN d.is_accelerated_database_recovery_on = 0
        THEN 'ADR OFF - Optimized Locking unavailable'
        WHEN d.is_accelerated_database_recovery_on = 1
         AND d.is_optimized_locking_on = 0
        THEN 'ADR ON - Optimized Locking not enabled (eligible)'
        WHEN d.is_optimized_locking_on = 1
         AND d.is_read_committed_snapshot_on = 0
        THEN 'ADR ON + OL ON - Enable RCSI for full LAQ benefit'
        WHEN d.is_optimized_locking_on = 1
         AND d.is_read_committed_snapshot_on = 1
        THEN 'ADR ON + OL ON + RCSI ON - Full optimized locking'
        ELSE 'Unknown'
    END                                             AS readiness_status
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.state = 0
ORDER BY d.name;

/*------------------------------------------------------------------------------
  Section 2: Optimized Locking Readiness Check -- NEW in 2025
  Summary of how many databases can benefit from optimized locking.
------------------------------------------------------------------------------*/
SELECT
    COUNT(*)                                        AS total_user_databases,
    SUM(CASE WHEN d.is_accelerated_database_recovery_on = 1 THEN 1 ELSE 0 END)
                                                    AS adr_enabled_count,
    SUM(CASE WHEN d.is_optimized_locking_on = 1 THEN 1 ELSE 0 END)
                                                    AS optimized_locking_count, -- NEW in 2025
    SUM(CASE WHEN d.is_optimized_locking_on = 1
              AND d.is_read_committed_snapshot_on = 1 THEN 1 ELSE 0 END)
                                                    AS full_ol_count,
    SUM(CASE WHEN d.is_accelerated_database_recovery_on = 1
              AND d.is_optimized_locking_on = 0 THEN 1 ELSE 0 END)
                                                    AS ol_eligible_not_enabled,
    SUM(CASE WHEN d.is_accelerated_database_recovery_on = 0 THEN 1 ELSE 0 END)
                                                    AS adr_off_not_eligible
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.state = 0;

/*------------------------------------------------------------------------------
  Section 3: PVS Size and Growth
  Persistent Version Store size for each ADR-enabled database.
------------------------------------------------------------------------------*/
SELECT
    DB_NAME(pvss.database_id)                       AS database_name,
    pvss.persistent_version_store_size_kb / 1024    AS pvs_size_mb,
    pvss.online_index_version_store_size_kb / 1024  AS online_index_vs_mb,
    pvss.current_aborted_transaction_count          AS aborted_txn_count,
    pvss.aborted_version_cleaner_start_time,
    pvss.aborted_version_cleaner_end_time,
    CASE
        WHEN pvss.persistent_version_store_size_kb > 1048576
        THEN 'WARNING: PVS > 1 GB'
        WHEN pvss.persistent_version_store_size_kb > 524288
        THEN 'MONITOR: PVS > 512 MB'
        ELSE 'OK'
    END                                             AS pvs_status
FROM sys.dm_tran_persistent_version_store_stats AS pvss
ORDER BY pvss.persistent_version_store_size_kb DESC;

/*------------------------------------------------------------------------------
  Section 4: PVS Cleanup Status
  Tracks the version cleaner progress.
------------------------------------------------------------------------------*/
SELECT
    DB_NAME(database_id)                            AS database_name,
    persistent_version_store_size_kb / 1024         AS pvs_size_mb,
    current_aborted_transaction_count               AS aborted_txns,
    aborted_version_cleaner_start_time              AS cleaner_start,
    aborted_version_cleaner_end_time                AS cleaner_end,
    CASE
        WHEN aborted_version_cleaner_start_time IS NOT NULL
         AND aborted_version_cleaner_end_time IS NULL
        THEN 'Running'
        WHEN aborted_version_cleaner_end_time IS NOT NULL
        THEN 'Completed'
        ELSE 'Not started'
    END                                             AS cleaner_status
FROM sys.dm_tran_persistent_version_store_stats;

/*------------------------------------------------------------------------------
  Section 5: Version Store Transactions
  Active transactions holding version store references.
------------------------------------------------------------------------------*/
SELECT
    tat.transaction_id,
    tat.name                                        AS transaction_name,
    tat.transaction_begin_time,
    DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE())
                                                    AS duration_seconds,
    tat.transaction_type,
    CASE tat.transaction_type
        WHEN 1 THEN 'Read/Write'
        WHEN 2 THEN 'Read-Only'
        WHEN 3 THEN 'System'
        WHEN 4 THEN 'Distributed'
        ELSE 'Other'
    END                                             AS transaction_type_desc,
    tat.transaction_state,
    CASE tat.transaction_state
        WHEN 0 THEN 'Initializing'
        WHEN 1 THEN 'Initialized'
        WHEN 2 THEN 'Active'
        WHEN 3 THEN 'Ended'
        WHEN 4 THEN 'Commit started (distributed)'
        WHEN 5 THEN 'Prepared (distributed)'
        WHEN 6 THEN 'Committed'
        WHEN 7 THEN 'Rolling back'
        WHEN 8 THEN 'Rolled back'
        ELSE 'Unknown'
    END                                             AS state_desc,
    es.session_id,
    es.login_name,
    es.host_name,
    es.program_name
FROM sys.dm_tran_active_transactions AS tat
LEFT JOIN sys.dm_tran_session_transactions AS tst
    ON tat.transaction_id = tst.transaction_id
LEFT JOIN sys.dm_exec_sessions AS es
    ON tst.session_id = es.session_id
WHERE tat.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE())
ORDER BY tat.transaction_begin_time;

/*------------------------------------------------------------------------------
  Section 6: ADR Recovery Performance Indicators
  Recovery-related performance counters.
------------------------------------------------------------------------------*/
SELECT
    object_name,
    counter_name,
    instance_name,
    cntr_value
FROM sys.dm_os_performance_counters
WHERE (counter_name LIKE '%Version%'
       OR counter_name LIKE '%ADR%'
       OR counter_name LIKE '%Persistent Version%'
       OR counter_name LIKE '%Aborted Transaction%')
  AND cntr_value > 0
ORDER BY object_name, counter_name, instance_name;

/*------------------------------------------------------------------------------
  Section 7: PVS File Usage
  File-level space consumption for databases with ADR.
------------------------------------------------------------------------------*/
SELECT
    DB_NAME(mf.database_id)                         AS database_name,
    mf.name                                         AS logical_file_name,
    mf.physical_name,
    mf.type_desc,
    mf.size * 8 / 1024                              AS file_size_mb,
    FILEPROPERTY(mf.name, 'SpaceUsed') * 8 / 1024  AS space_used_mb,
    (mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) * 8 / 1024
                                                    AS free_space_mb,
    mf.growth,
    CASE mf.is_percent_growth
        WHEN 1 THEN CAST(mf.growth AS VARCHAR(10)) + '%'
        ELSE CAST(mf.growth * 8 / 1024 AS VARCHAR(10)) + ' MB'
    END                                             AS growth_setting
FROM sys.master_files AS mf
INNER JOIN sys.databases AS d
    ON mf.database_id = d.database_id
WHERE d.is_accelerated_database_recovery_on = 1
  AND d.database_id > 4
  AND mf.type = 0                                   -- data files
ORDER BY mf.database_id, mf.file_id;
