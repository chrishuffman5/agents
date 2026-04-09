/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Server Health Dashboard
 *
 * Purpose : Comprehensive server health overview with SQL Server 2025 features.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1.  Instance Overview & Version Info
 *   2.  Database Status Summary (enhanced for 2025)
 *   3.  Optimized Locking Configuration (NEW in 2025)
 *   4.  Vector Data Type & DiskANN Index Status (NEW in 2025)
 *   5.  Native JSON Data Type Usage (NEW in 2025)
 *   6.  TLS 1.3 & Connection Encryption Verification (NEW in 2025)
 *   7.  Edition Limits Check (NEW in 2025 - Standard 256 GB / 32 cores)
 *   8.  Change Event Streaming Configuration (NEW in 2025)
 *   9.  IQP Feature Status (enhanced for 2025: OPPO, DOP default-on)
 *  10.  Key Server-Level Configuration
 *  11.  Resource Utilization Snapshot
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: Instance Overview & Version Info
------------------------------------------------------------------------------*/
SELECT
    SERVERPROPERTY('ServerName')                    AS server_name,
    SERVERPROPERTY('ProductVersion')                AS product_version,
    SERVERPROPERTY('ProductLevel')                  AS product_level,
    SERVERPROPERTY('ProductUpdateLevel')            AS cumulative_update,
    SERVERPROPERTY('Edition')                       AS edition,
    SERVERPROPERTY('EngineEdition')                 AS engine_edition,
    SERVERPROPERTY('ProductMajorVersion')           AS major_version,   -- 17 for SQL 2025
    SERVERPROPERTY('ProductMinorVersion')           AS minor_version,
    SERVERPROPERTY('ProductBuild')                  AS build_number,
    SERVERPROPERTY('MachineName')                   AS machine_name,
    SERVERPROPERTY('IsClustered')                   AS is_clustered,
    SERVERPROPERTY('IsHadrEnabled')                 AS is_hadr_enabled,
    SERVERPROPERTY('HadrManagerStatus')             AS hadr_manager_status,
    SERVERPROPERTY('IsIntegratedSecurityOnly')      AS windows_auth_only,
    si.cpu_count                                    AS logical_cpu_count,
    si.hyperthread_ratio                            AS hyperthread_ratio,
    si.physical_memory_kb / 1024                    AS physical_memory_mb,
    si.committed_kb / 1024                          AS committed_memory_mb,
    si.committed_target_kb / 1024                   AS target_memory_mb,
    si.sqlserver_start_time                         AS instance_start_time,
    DATEDIFF(HOUR, si.sqlserver_start_time, GETDATE()) AS uptime_hours
FROM sys.dm_os_sys_info AS si;

/*------------------------------------------------------------------------------
  Section 2: Database Status Summary -- Enhanced for 2025
  NEW columns: is_optimized_locking_on, is_event_stream_enabled
------------------------------------------------------------------------------*/
SELECT
    d.database_id,
    d.name                                          AS database_name,
    d.state_desc                                    AS state,
    d.recovery_model_desc                           AS recovery_model,
    d.compatibility_level,
    d.page_verify_option_desc                       AS page_verify,
    d.is_auto_close_on                              AS auto_close,
    d.is_auto_shrink_on                             AS auto_shrink,
    d.is_query_store_on                             AS query_store_enabled,
    d.is_accelerated_database_recovery_on           AS adr_enabled,
    d.is_read_committed_snapshot_on                 AS rcsi_enabled,
    d.is_optimized_locking_on                       AS optimized_locking,      -- NEW in 2025
    d.is_event_stream_enabled                       AS event_stream_enabled,   -- NEW in 2025 (CES)
    d.is_ledger_on                                  AS ledger_enabled,
    d.snapshot_isolation_state_desc                  AS snapshot_isolation,
    d.delayed_durability_desc                       AS delayed_durability,
    COALESCE(
        (SELECT SUM(mf.size) * 8.0 / 1024
         FROM sys.master_files AS mf
         WHERE mf.database_id = d.database_id AND mf.type = 0), 0
    )                                               AS data_size_mb,
    COALESCE(
        (SELECT SUM(mf.size) * 8.0 / 1024
         FROM sys.master_files AS mf
         WHERE mf.database_id = d.database_id AND mf.type = 1), 0
    )                                               AS log_size_mb
FROM sys.databases AS d
ORDER BY d.database_id;

/*------------------------------------------------------------------------------
  Section 3: Optimized Locking Configuration -- NEW in 2025
  Optimized locking requires ADR. RCSI strongly recommended for LAQ.
  ALTER DATABASE <db> SET OPTIMIZED_LOCKING = ON
------------------------------------------------------------------------------*/
SELECT
    d.database_id,
    d.name                                          AS database_name,
    d.is_accelerated_database_recovery_on           AS adr_enabled,
    d.is_read_committed_snapshot_on                 AS rcsi_enabled,
    d.is_optimized_locking_on                       AS optimized_locking,      -- NEW in 2025
    CASE
        WHEN d.is_optimized_locking_on = 1 THEN 'Active'
        WHEN d.is_accelerated_database_recovery_on = 1
         AND d.is_optimized_locking_on = 0 THEN 'Ready (ADR on, OL off)'
        WHEN d.is_accelerated_database_recovery_on = 0 THEN 'Not Ready (ADR required)'
        ELSE 'Unknown'
    END                                             AS optimized_locking_readiness,
    CASE
        WHEN d.is_optimized_locking_on = 1
         AND d.is_read_committed_snapshot_on = 1 THEN 'Full (TID + LAQ)'
        WHEN d.is_optimized_locking_on = 1
         AND d.is_read_committed_snapshot_on = 0 THEN 'Partial (TID only, no LAQ)'
        ELSE 'N/A'
    END                                             AS locking_mode
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.state = 0
ORDER BY d.name;

/*------------------------------------------------------------------------------
  Section 4: Vector Data Type & DiskANN Index Status -- NEW in 2025
  Lists databases/tables with VECTOR columns and DiskANN vector indexes.
  Uses sys.vector_indexes catalog view and sys.dm_db_vector_indexes DMV.
------------------------------------------------------------------------------*/
-- 4a. Vector indexes in the current database (sys.vector_indexes)
SELECT
    OBJECT_SCHEMA_NAME(vi.object_id)                AS schema_name,
    OBJECT_NAME(vi.object_id)                       AS table_name,
    i.name                                          AS index_name,
    vi.vector_index_type,                                                      -- NEW in 2025
    vi.distance_metric                                                         -- NEW in 2025
FROM sys.vector_indexes AS vi
INNER JOIN sys.indexes AS i
    ON vi.object_id = i.object_id
   AND vi.index_id  = i.index_id;

-- 4b. Vector index health (sys.dm_db_vector_indexes)
SELECT
    DB_NAME()                                       AS database_name,
    OBJECT_NAME(dvi.object_id)                      AS table_name,
    dvi.index_id,
    dvi.approximate_staleness_percent,                                         -- NEW in 2025
    dvi.quantized_keys_used_percent,                                           -- NEW in 2025
    dvi.last_background_task_time,
    dvi.last_background_task_succeeded,
    dvi.last_background_task_duration_seconds,
    dvi.last_background_task_processed_inserts,
    dvi.last_background_task_processed_deletes,
    dvi.last_background_task_error_message
FROM sys.dm_db_vector_indexes AS dvi;

/*------------------------------------------------------------------------------
  Section 5: Native JSON Data Type Usage -- NEW in 2025
  Identifies columns using the native JSON data type (binary storage, up to 2GB).
------------------------------------------------------------------------------*/
SELECT
    OBJECT_SCHEMA_NAME(c.object_id)                 AS schema_name,
    OBJECT_NAME(c.object_id)                        AS table_name,
    c.name                                          AS column_name,
    t.name                                          AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.columns AS c
INNER JOIN sys.types AS t
    ON c.system_type_id = t.system_type_id
   AND c.user_type_id   = t.user_type_id
WHERE t.name = N'json'                                                         -- NEW in 2025
ORDER BY schema_name, table_name, c.column_id;

/*------------------------------------------------------------------------------
  Section 6: TLS 1.3 & Connection Encryption Verification -- NEW in 2025
  SQL Server 2025 defaults to TLS 1.3 and Encrypt=True.
------------------------------------------------------------------------------*/
SELECT
    c.session_id,
    c.encrypt_option                                AS encryption_status,
    c.protocol_type,
    c.protocol_version,
    c.net_transport,
    c.auth_scheme,
    c.client_net_address,
    s.login_name,
    s.host_name,
    s.program_name
FROM sys.dm_exec_connections AS c
INNER JOIN sys.dm_exec_sessions AS s
    ON c.session_id = s.session_id
WHERE s.is_user_process = 1
ORDER BY c.encrypt_option, c.protocol_version;

/*------------------------------------------------------------------------------
  Section 7: Edition Limits Check -- NEW in 2025
  Standard Edition raised to 256 GB memory / 32 cores (up from 128 GB / 24).
------------------------------------------------------------------------------*/
SELECT
    SERVERPROPERTY('Edition')                       AS edition,
    si.cpu_count                                    AS logical_cpus,
    si.physical_memory_kb / 1024 / 1024             AS physical_memory_gb,
    CAST(sc.value_in_use AS INT)                    AS max_server_memory_mb,
    CASE
        WHEN CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Standard%'
        THEN CASE
                WHEN si.cpu_count > 32
                THEN 'WARNING: Standard Edition limited to 32 cores (2025 limit)'
                ELSE 'OK: Within 32-core Standard Edition limit'
             END
        ELSE 'Enterprise/Developer: No core limit'
    END                                             AS cpu_limit_status,        -- NEW in 2025
    CASE
        WHEN CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Standard%'
        THEN CASE
                WHEN CAST(sc.value_in_use AS BIGINT) > 262144
                THEN 'WARNING: Standard Edition limited to 256 GB (2025 limit)'
                ELSE 'OK: Within 256 GB Standard Edition limit'
             END
        ELSE 'Enterprise/Developer: No memory limit'
    END                                             AS memory_limit_status      -- NEW in 2025
FROM sys.dm_os_sys_info AS si
CROSS JOIN sys.configurations AS sc
WHERE sc.name = 'max server memory (MB)';

/*------------------------------------------------------------------------------
  Section 8: Change Event Streaming Configuration -- NEW in 2025
  CES streams data changes to Azure Event Hubs in near real-time.
------------------------------------------------------------------------------*/
-- 8a. Databases with CES enabled
SELECT
    d.database_id,
    d.name                                          AS database_name,
    d.is_event_stream_enabled,                                                 -- NEW in 2025
    d.recovery_model_desc                           AS recovery_model,
    CASE
        WHEN d.recovery_model_desc <> 'FULL'
         AND d.is_event_stream_enabled = 1
        THEN 'WARNING: CES requires FULL recovery model'
        ELSE 'OK'
    END                                             AS ces_recovery_check
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.state = 0
ORDER BY d.is_event_stream_enabled DESC, d.name;

/*------------------------------------------------------------------------------
  Section 9: IQP Feature Status -- Enhanced for 2025
  NEW in 2025: DOP Feedback on by default, OPPO (Optional Parameter Plan
  Optimization), CE Feedback for Expressions.
------------------------------------------------------------------------------*/
;WITH iqp_features AS (
    SELECT
        'Parameter Sensitive Plan (PSP) Optimization' AS feature_name,
        'Database-level (compat 160+ / QS READ_WRITE)' AS scope,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM sys.databases
                WHERE compatibility_level >= 160 AND is_query_store_on = 1
            ) THEN 'Available'
            ELSE 'Not available'
        END AS status
    UNION ALL
    SELECT
        'DOP Feedback (default ON in 2025)',                                   -- NEW in 2025
        'Database-level (compat 160+ / QS READ_WRITE)',
        CASE
            WHEN EXISTS (
                SELECT 1 FROM sys.databases
                WHERE compatibility_level >= 160 AND is_query_store_on = 1
            ) THEN 'Available (enabled by default in 2025)'
            ELSE 'Not available'
        END
    UNION ALL
    SELECT
        'CE Feedback (incl. Expressions in 2025)',                             -- NEW in 2025
        'Database-level (compat 160+ / QS READ_WRITE)',
        CASE
            WHEN EXISTS (
                SELECT 1 FROM sys.databases
                WHERE compatibility_level >= 160 AND is_query_store_on = 1
            ) THEN 'Available'
            ELSE 'Not available'
        END
    UNION ALL
    SELECT
        'Optional Parameter Plan Optimization (OPPO)',                         -- NEW in 2025
        'Database-level (compat 170 / QS READ_WRITE)',
        CASE
            WHEN EXISTS (
                SELECT 1 FROM sys.databases
                WHERE compatibility_level >= 170 AND is_query_store_on = 1
            ) THEN 'Available'
            ELSE 'Not available (requires compat 170)'
        END
    UNION ALL
    SELECT
        'Optimized Plan Forcing',
        'Database-level (compat 160+ / QS READ_WRITE)',
        CASE
            WHEN EXISTS (
                SELECT 1 FROM sys.databases
                WHERE compatibility_level >= 160 AND is_query_store_on = 1
            ) THEN 'Available'
            ELSE 'Not available'
        END
    UNION ALL
    SELECT
        'LAQ Feedback (Query Store)',                                          -- NEW in 2025
        'Database-level (compat 170 / QS + OL enabled)',
        CASE
            WHEN EXISTS (
                SELECT 1 FROM sys.databases
                WHERE compatibility_level >= 170
                  AND is_query_store_on = 1
                  AND is_optimized_locking_on = 1
            ) THEN 'Available'
            ELSE 'Not available (requires compat 170 + OL)'
        END
)
SELECT feature_name, scope, status
FROM iqp_features;

-- Database-scoped configurations for IQP
SELECT
    name                AS config_name,
    value               AS config_value,
    value_for_secondary AS value_for_secondary
FROM sys.database_scoped_configurations
WHERE name IN (
    'PARAMETER_SENSITIVE_PLAN_OPTIMIZATION',
    'DOP_FEEDBACK',
    'CE_FEEDBACK',
    'OPTIMIZED_PLAN_FORCING',
    'EXEC_QUERY_STATS_FOR_SCALAR_FUNCTIONS',
    'MEMORY_GRANT_FEEDBACK_PERCENTILE',
    'MEMORY_GRANT_FEEDBACK_PERSISTENCE',
    'PREVIEW_FEATURES'                                                         -- NEW in 2025
);

/*------------------------------------------------------------------------------
  Section 10: Key Server-Level Configuration
------------------------------------------------------------------------------*/
SELECT
    c.configuration_id,
    c.name                                          AS config_name,
    c.value                                         AS configured_value,
    c.value_in_use                                  AS running_value,
    c.minimum                                       AS min_value,
    c.maximum                                       AS max_value,
    c.is_dynamic,
    c.is_advanced
FROM sys.configurations AS c
WHERE c.name IN (
    'max degree of parallelism',
    'cost threshold for parallelism',
    'max server memory (MB)',
    'min server memory (MB)',
    'optimize for ad hoc workloads',
    'max worker threads',
    'backup compression default',
    'remote admin connections',
    'clr enabled',
    'lightweight pooling',
    'priority boost',
    'tempdb metadata memory-optimized'
)
ORDER BY c.name;

/*------------------------------------------------------------------------------
  Section 11: Resource Utilization Snapshot
------------------------------------------------------------------------------*/
-- CPU utilization (last 256 minutes from ring buffer)
;WITH cpu_ring AS (
    SELECT
        record.value('(./Record/@id)[1]', 'INT')                                           AS record_id,
        record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'INT')  AS system_idle,
        record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'INT') AS sql_cpu,
        DATEADD(ms,
            -1 * (si.cpu_ticks / (si.cpu_ticks / si.ms_ticks) - rb.timestamp),
            GETDATE())                              AS event_time
    FROM (
        SELECT timestamp, CONVERT(XML, record) AS record
        FROM sys.dm_os_ring_buffers
        WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
          AND record LIKE N'%<SystemHealth>%'
    ) AS rb
    CROSS JOIN sys.dm_os_sys_info AS si
)
SELECT TOP (10)
    event_time,
    sql_cpu                                         AS sql_cpu_percent,
    100 - system_idle - sql_cpu                     AS other_cpu_percent,
    system_idle                                     AS idle_cpu_percent
FROM cpu_ring
ORDER BY event_time DESC;

-- Memory clerk summary (top 10 by size)
SELECT TOP (10)
    type                                            AS clerk_type,
    name                                            AS clerk_name,
    pages_kb / 1024                                 AS allocated_mb,
    virtual_memory_reserved_kb / 1024               AS virtual_reserved_mb,
    virtual_memory_committed_kb / 1024              AS virtual_committed_mb
FROM sys.dm_os_memory_clerks
ORDER BY pages_kb DESC;
