/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - ADR & PVS Health
 *
 * Purpose : Monitor Accelerated Database Recovery and Persistent Version Store.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. ADR Enablement Status by Database
 *   2. PVS Size & Growth Tracking
 *   3. PVS Cleanup Statistics
 *   4. Active Version Store Transactions
 *   5. sLog Health (Persistent In-Memory Log)
 *   6. ADR-Related Wait Stats
 *   7. Recovery Performance Counters
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: ADR Enablement Status by Database
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    d.database_id,
    d.name                                          AS database_name,
    d.is_accelerated_database_recovery_on           AS adr_enabled,
    d.state_desc                                    AS database_state,
    d.recovery_model_desc                           AS recovery_model,
    d.compatibility_level
FROM sys.databases AS d
ORDER BY d.is_accelerated_database_recovery_on DESC, d.name;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: PVS Size & Growth Tracking
──────────────────────────────────────────────────────────────────────────────*/
-- PVS space consumed per database
SELECT
    DB_NAME(pvss.database_id)                       AS database_name,
    pvss.persistent_version_store_size_kb / 1024    AS pvs_size_mb,
    pvss.online_index_version_store_size_kb / 1024  AS online_index_pvs_mb,
    pvss.current_aborted_transaction_count          AS aborted_txn_count,
    pvss.aborted_version_cleaner_start_time         AS cleaner_start_time,
    pvss.aborted_version_cleaner_end_time           AS cleaner_end_time
FROM sys.dm_tran_persistent_version_store_stats AS pvss;

-- PVS file space usage (if ADR is on filegroup-based PVS)
SELECT
    DB_NAME()                                       AS database_name,
    fg.name                                         AS filegroup_name,
    df.name                                         AS file_name,
    df.physical_name,
    df.size * 8 / 1024                              AS file_size_mb,
    FILEPROPERTY(df.name, 'SpaceUsed') * 8 / 1024  AS used_mb,
    (df.size - FILEPROPERTY(df.name, 'SpaceUsed')) * 8 / 1024
                                                    AS free_mb,
    df.growth,
    df.is_percent_growth
FROM sys.database_files AS df
INNER JOIN sys.filegroups AS fg
    ON df.data_space_id = fg.data_space_id
WHERE fg.name LIKE '%VersionStore%'
   OR fg.name LIKE '%PVS%';

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: PVS Cleanup Statistics
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    DB_NAME(database_id)                            AS database_name,
    persistent_version_store_size_kb / 1024         AS pvs_size_mb,
    online_index_version_store_size_kb / 1024       AS online_index_pvs_mb,
    current_aborted_transaction_count               AS aborted_txn_count,
    aborted_version_cleaner_start_time,
    aborted_version_cleaner_end_time,
    DATEDIFF(SECOND,
        aborted_version_cleaner_start_time,
        COALESCE(aborted_version_cleaner_end_time, GETDATE()))
                                                    AS cleaner_duration_sec,
    oldest_aborted_transaction_id,
    oldest_active_transaction_id
FROM sys.dm_tran_persistent_version_store_stats;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Active Version Store Transactions
  Transactions that may block PVS cleanup.
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    dt.transaction_id,
    dt.name                                         AS transaction_name,
    dt.transaction_begin_time,
    DATEDIFF(SECOND, dt.transaction_begin_time, GETDATE())
                                                    AS duration_sec,
    CASE dt.transaction_type
        WHEN 1 THEN 'Read/Write'
        WHEN 2 THEN 'Read-Only'
        WHEN 3 THEN 'System'
        WHEN 4 THEN 'Distributed'
        ELSE CAST(dt.transaction_type AS VARCHAR(10))
    END                                             AS transaction_type,
    CASE dt.transaction_state
        WHEN 0 THEN 'Not yet initialized'
        WHEN 1 THEN 'Initialized, not started'
        WHEN 2 THEN 'Active'
        WHEN 3 THEN 'Ended (read-only)'
        WHEN 4 THEN 'Commit initiated'
        WHEN 5 THEN 'Prepared, waiting resolution'
        WHEN 6 THEN 'Committed'
        WHEN 7 THEN 'Rolling back'
        WHEN 8 THEN 'Rolled back'
        ELSE CAST(dt.transaction_state AS VARCHAR(10))
    END                                             AS transaction_state,
    es.session_id,
    es.login_name,
    es.host_name,
    es.program_name,
    SUBSTRING(qt.text, 1, 300)                      AS last_query_text
FROM sys.dm_tran_active_transactions AS dt
INNER JOIN sys.dm_tran_session_transactions AS st
    ON dt.transaction_id = st.transaction_id
INNER JOIN sys.dm_exec_sessions AS es
    ON st.session_id = es.session_id
LEFT JOIN sys.dm_exec_connections AS ec
    ON es.session_id = ec.session_id
OUTER APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) AS qt
WHERE dt.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE())  -- 5+ min old
ORDER BY dt.transaction_begin_time ASC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: sLog Health (Persistent In-Memory Log for ADR)
──────────────────────────────────────────────────────────────────────────────*/
-- Version store space usage in tempdb (traditional) vs PVS
SELECT
    'tempdb version store'                          AS version_store_type,
    SUM(version_store_reserved_page_count) * 8 / 1024
                                                    AS reserved_mb
FROM sys.dm_db_file_space_usage
WHERE database_id = 2
UNION ALL
SELECT
    'PVS (ADR)'                                     AS version_store_type,
    SUM(persistent_version_store_size_kb) / 1024    AS reserved_mb
FROM sys.dm_tran_persistent_version_store_stats;

/*──────────────────────────────────────────────────────────────────────────────
  Section 6: ADR-Related Wait Stats
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    wait_type,
    waiting_tasks_count                             AS wait_count,
    wait_time_ms                                    AS total_wait_ms,
    CAST(wait_time_ms * 1.0
        / NULLIF(waiting_tasks_count, 0) AS DECIMAL(18,2))
                                                    AS avg_wait_ms,
    max_wait_time_ms                                AS max_wait_ms,
    signal_wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE '%PVS%'
   OR wait_type LIKE '%ADR%'
   OR wait_type LIKE '%VERSION%'
   OR wait_type IN (
       'PVS_PREALLOCATE',
       'PWAIT_PVS_WORKER'
   )
AND waiting_tasks_count > 0
ORDER BY wait_time_ms DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 7: Recovery Performance Counters
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    RTRIM(object_name)                              AS counter_object,
    RTRIM(counter_name)                             AS counter_name,
    RTRIM(instance_name)                            AS instance_name,
    cntr_value                                      AS counter_value
FROM sys.dm_os_performance_counters
WHERE object_name LIKE '%Recovery%'
   OR counter_name LIKE '%Version%'
   OR counter_name LIKE '%PVS%'
   OR counter_name LIKE '%Accelerated%'
ORDER BY object_name, counter_name;
