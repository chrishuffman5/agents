/******************************************************************************
 * 01-server-health.sql
 * SQL Server 2019 (Compatibility Level 150) — Server Health Dashboard
 *
 * Enhanced for 2019:
 *   - Accelerated Database Recovery (ADR) status per database         [NEW]
 *   - Persistent Version Store (PVS) size monitoring                  [NEW]
 *   - Intelligent Query Processing (IQP) feature status               [NEW]
 *     (batch mode on rowstore, scalar UDF inlining,
 *      table variable deferred compilation)
 *   - Database-scoped configurations for 2019 features                [NEW]
 *
 * Safe: read-only, no temp tables, no cursors.
 * Tested against: SQL Server 2019 CU18+
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — Instance Overview
=============================================================================*/
SELECT
    SERVERPROPERTY('ServerName')            AS server_name,
    SERVERPROPERTY('ProductVersion')        AS product_version,
    SERVERPROPERTY('ProductLevel')          AS product_level,
    SERVERPROPERTY('Edition')               AS edition,
    SERVERPROPERTY('ProductMajorVersion')   AS major_version,
    SERVERPROPERTY('ProductMinorVersion')   AS minor_version,
    SERVERPROPERTY('ProductBuild')          AS build_number,
    SERVERPROPERTY('ProductUpdateLevel')    AS cumulative_update,
    SERVERPROPERTY('MachineName')           AS machine_name,
    SERVERPROPERTY('IsClustered')           AS is_clustered,
    SERVERPROPERTY('IsHadrEnabled')         AS is_hadr_enabled,
    SERVERPROPERTY('FilestreamShareName')   AS filestream_share,
    SERVERPROPERTY('Collation')             AS server_collation,
    si.cpu_count                            AS logical_cpu_count,
    si.hyperthread_ratio,
    si.physical_memory_kb / 1024            AS physical_memory_mb,
    si.committed_kb / 1024                  AS committed_memory_mb,
    si.committed_target_kb / 1024           AS target_memory_mb,
    si.sqlserver_start_time,
    DATEDIFF(DAY, si.sqlserver_start_time, GETDATE()) AS uptime_days
FROM sys.dm_os_sys_info AS si;

/*=============================================================================
  Section 2 — Database Inventory with Compatibility Level & ADR Status  [NEW]
=============================================================================*/
SELECT
    d.database_id,
    d.name                                  AS database_name,
    d.state_desc                            AS state,
    d.recovery_model_desc                   AS recovery_model,
    d.compatibility_level,
    CASE
        WHEN d.compatibility_level >= 150
        THEN 'Eligible'
        ELSE 'Requires compat 150+'
    END                                     AS iqp_eligibility,
    d.is_accelerated_database_recovery_on   AS adr_enabled,          -- NEW 2019
    d.page_verify_option_desc               AS page_verify,
    d.is_auto_shrink_on                     AS auto_shrink_on,
    d.is_auto_create_stats_on              AS auto_create_stats,
    d.is_auto_update_stats_on              AS auto_update_stats,
    d.is_query_store_on                    AS query_store_on,
    d.collation_name,
    CASE
        WHEN d.collation_name LIKE '%UTF8%'
        THEN 'Yes'
        ELSE 'No'
    END                                     AS utf8_collation          -- NEW 2019
FROM sys.databases AS d
ORDER BY d.database_id;

/*=============================================================================
  Section 3 — Persistent Version Store (PVS) Size Monitoring           [NEW]
  Requires ADR to be enabled on at least one database.
=============================================================================*/
SELECT
    DB_NAME(pvs.database_id)                AS database_name,
    pvs.pvs_page_count,
    (pvs.pvs_page_count * 8) / 1024        AS pvs_size_mb,
    pvs.online_index_version_store_size_kb / 1024 AS online_idx_pvs_mb,
    pvs.current_aborted_transaction_count   AS aborted_txn_count,
    pvs.aborted_version_cleaner_start_time  AS last_cleanup_start,
    pvs.aborted_version_cleaner_end_time    AS last_cleanup_end,
    DATEDIFF(
        SECOND,
        pvs.aborted_version_cleaner_start_time,
        ISNULL(pvs.aborted_version_cleaner_end_time, GETDATE())
    )                                       AS cleanup_duration_sec
FROM sys.dm_tran_persistent_version_store_stats AS pvs;

/*=============================================================================
  Section 4 — Intelligent Query Processing (IQP) Feature Status        [NEW]
  These database-scoped configs control 2019 IQP features.
=============================================================================*/
SELECT
    DB_NAME(dsc.database_id)                AS database_name,
    dsc.name                                AS config_name,
    dsc.value                               AS current_value,
    dsc.value_for_secondary                 AS secondary_value,
    CASE dsc.name
        WHEN 'BATCH_MODE_ON_ROWSTORE'
            THEN 'Batch mode on rowstore (NEW 2019)'
        WHEN 'TSQL_SCALAR_UDF_INLINING'
            THEN 'Scalar UDF inlining (NEW 2019)'
        WHEN 'DEFERRED_COMPILATION_TV'
            THEN 'Table variable deferred compilation (NEW 2019)'
        WHEN 'BATCH_MODE_MEMORY_GRANT_FEEDBACK'
            THEN 'Batch mode memory grant feedback'
        WHEN 'ROW_MODE_MEMORY_GRANT_FEEDBACK'
            THEN 'Row mode memory grant feedback (NEW 2019)'
        WHEN 'BATCH_MODE_ADAPTIVE_JOINS'
            THEN 'Batch mode adaptive joins'
        WHEN 'INTERLEAVED_EXECUTION_TVF'
            THEN 'Interleaved execution for MSTVFs'
        WHEN 'LIGHTWEIGHT_QUERY_PROFILING'
            THEN 'Lightweight query profiling (NEW 2019)'
        ELSE dsc.name
    END                                     AS feature_description
FROM sys.database_scoped_configurations AS dsc
WHERE dsc.name IN (
    'BATCH_MODE_ON_ROWSTORE',
    'TSQL_SCALAR_UDF_INLINING',
    'DEFERRED_COMPILATION_TV',
    'BATCH_MODE_MEMORY_GRANT_FEEDBACK',
    'ROW_MODE_MEMORY_GRANT_FEEDBACK',
    'BATCH_MODE_ADAPTIVE_JOINS',
    'INTERLEAVED_EXECUTION_TVF',
    'LIGHTWEIGHT_QUERY_PROFILING',
    'LAST_QUERY_PLAN_STATS'
)
ORDER BY dsc.database_id, dsc.name;

/*=============================================================================
  Section 5 — All Database-Scoped Configurations (2019 additions)      [NEW]
=============================================================================*/
SELECT
    DB_NAME(dsc.database_id)                AS database_name,
    dsc.name                                AS config_name,
    dsc.value                               AS current_value,
    dsc.value_for_secondary                 AS value_for_secondary
FROM sys.database_scoped_configurations AS dsc
ORDER BY dsc.database_id, dsc.name;

/*=============================================================================
  Section 6 — Server-Level Configuration Checks
=============================================================================*/
SELECT
    c.name                                  AS config_name,
    c.value                                 AS configured_value,
    c.value_in_use                          AS running_value,
    c.minimum                               AS min_allowed,
    c.maximum                               AS max_allowed,
    c.is_dynamic,
    c.is_advanced
FROM sys.configurations AS c
WHERE c.name IN (
    'max degree of parallelism',
    'cost threshold for parallelism',
    'max server memory (MB)',
    'min server memory (MB)',
    'optimize for ad hoc workloads',
    'remote admin connections',
    'backup compression default',
    'clr enabled',
    'lightweight pooling',
    'priority boost',
    'max worker threads',
    'default trace enabled',
    'allow updates',
    'xp_cmdshell'
)
ORDER BY c.name;

/*=============================================================================
  Section 7 — Tempdb Configuration
=============================================================================*/
SELECT
    mf.file_id,
    mf.name                                 AS logical_name,
    mf.physical_name,
    mf.type_desc,
    mf.size * 8 / 1024                     AS size_mb,
    CASE mf.max_size
        WHEN -1 THEN 'Unlimited'
        WHEN 0  THEN 'No Growth'
        ELSE CAST(mf.max_size * 8 / 1024 AS VARCHAR(20)) + ' MB'
    END                                     AS max_size,
    CASE mf.is_percent_growth
        WHEN 1 THEN CAST(mf.growth AS VARCHAR(10)) + '%'
        ELSE CAST(mf.growth * 8 / 1024 AS VARCHAR(10)) + ' MB'
    END                                     AS growth_increment
FROM sys.master_files AS mf
WHERE mf.database_id = 2
ORDER BY mf.type, mf.file_id;

/*=============================================================================
  Section 8 — Error Log Summary (recent)
=============================================================================*/
SELECT TOP 25
    el.LogDate                              AS log_date,
    el.ProcessInfo                          AS process_info,
    el.Text                                 AS message
FROM (
    SELECT LogDate, ProcessInfo, [Text]
    FROM sys.dm_exec_errorlog
    WHERE LogDate >= DATEADD(HOUR, -24, GETDATE())
) AS el
ORDER BY el.LogDate DESC;
