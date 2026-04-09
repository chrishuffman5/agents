/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Server Health Dashboard
 *
 * Purpose : Comprehensive server health overview with SQL Server 2022 features.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Instance Overview & Version Info
 *   2. Database Status Summary
 *   3. IQP Feature Status (NEW in 2022: PSP, DOP Feedback, CE Feedback,
 *      Optimized Plan Forcing, Memory Grant Percentile Feedback)
 *   4. Query Store on Secondary Replicas Status (NEW in 2022)
 *   5. Ledger Database Status (NEW in 2022)
 *   6. Contained Availability Group Detection (NEW in 2022)
 *   7. XML Compression Usage (NEW in 2022)
 *   8. Key Server-Level Configuration
 *   9. Resource Utilization Snapshot
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: Instance Overview & Version Info
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    SERVERPROPERTY('ServerName')                    AS server_name,
    SERVERPROPERTY('ProductVersion')                AS product_version,
    SERVERPROPERTY('ProductLevel')                  AS product_level,
    SERVERPROPERTY('ProductUpdateLevel')            AS cumulative_update,
    SERVERPROPERTY('Edition')                       AS edition,
    SERVERPROPERTY('EngineEdition')                 AS engine_edition,
    SERVERPROPERTY('ProductMajorVersion')           AS major_version,
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

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: Database Status Summary
──────────────────────────────────────────────────────────────────────────────*/
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
    d.is_ledger_on                                  AS ledger_enabled,          -- NEW in 2022
    d.is_read_committed_snapshot_on                 AS rcsi_enabled,
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

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: IQP Feature Status — NEW in 2022
  (PSP Optimization, DOP Feedback, CE Feedback, Optimized Plan Forcing,
   Memory Grant Percentile Feedback)
──────────────────────────────────────────────────────────────────────────────*/
;WITH iqp_features AS (
    SELECT
        'Parameter Sensitive Plan (PSP) Optimization' AS feature_name,
        -- PSP requires compat level 160 and Query Store READ_WRITE
        'Database-level (compat 160 + QS READ_WRITE)' AS scope,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM sys.databases
                WHERE compatibility_level >= 160
                  AND is_query_store_on = 1
            ) THEN 'Available (one or more databases)'
            ELSE 'Not available (no compat 160 + QS enabled databases)'
        END AS status
    UNION ALL
    SELECT
        'DOP Feedback' AS feature_name,
        'Database-level (compat 160 + QS READ_WRITE)' AS scope,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM sys.databases
                WHERE compatibility_level >= 160
                  AND is_query_store_on = 1
            ) THEN 'Available'
            ELSE 'Not available'
        END AS status
    UNION ALL
    SELECT
        'CE Feedback' AS feature_name,
        'Database-level (compat 160 + QS READ_WRITE)' AS scope,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM sys.databases
                WHERE compatibility_level >= 160
                  AND is_query_store_on = 1
            ) THEN 'Available'
            ELSE 'Not available'
        END AS status
    UNION ALL
    SELECT
        'Optimized Plan Forcing' AS feature_name,
        'Database-level (compat 160 + QS READ_WRITE)' AS scope,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM sys.databases
                WHERE compatibility_level >= 160
                  AND is_query_store_on = 1
            ) THEN 'Available'
            ELSE 'Not available'
        END AS status
    UNION ALL
    SELECT
        'Memory Grant Percentile Feedback' AS feature_name,
        'Database-level (compat 160 + QS READ_WRITE)' AS scope,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM sys.databases
                WHERE compatibility_level >= 160
                  AND is_query_store_on = 1
            ) THEN 'Available'
            ELSE 'Not available'
        END AS status
)
SELECT
    feature_name,
    scope,
    status
FROM iqp_features;

-- Database-level scoped config related to IQP features
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
    'MEMORY_GRANT_FEEDBACK_PERSISTENCE'
);

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Query Store on Secondary Replicas Status — NEW in 2022
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    d.name                                          AS database_name,
    d.is_query_store_on                             AS query_store_enabled,
    CASE
        WHEN dsc.name = 'QUERY_STORE_FOR_SECONDARY'
         AND dsc.value = 1
        THEN 'Enabled'
        ELSE 'Disabled'
    END                                             AS query_store_on_secondaries  -- NEW in 2022
FROM sys.databases AS d
LEFT JOIN sys.database_scoped_configurations AS dsc
    ON dsc.name = 'QUERY_STORE_FOR_SECONDARY'
WHERE d.database_id > 4  -- exclude system databases
  AND d.state = 0;       -- ONLINE only

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: Ledger Database Status — NEW in 2022
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    d.database_id,
    d.name                                          AS database_name,
    d.is_ledger_on                                  AS ledger_enabled,           -- NEW in 2022
    d.state_desc                                    AS state
FROM sys.databases AS d
WHERE d.is_ledger_on = 1;

/*──────────────────────────────────────────────────────────────────────────────
  Section 6: Contained Availability Group Detection — NEW in 2022
──────────────────────────────────────────────────────────────────────────────*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.group_id,
        ag.name                                     AS ag_name,
        ag.is_contained                             AS is_contained_ag,          -- NEW in 2022
        ag.failure_condition_level,
        ag.health_check_timeout,
        ag.automated_backup_preference_desc         AS backup_preference,
        ag.required_synchronized_secondaries_to_commit AS required_sync_secondaries
    FROM sys.availability_groups AS ag;
END
ELSE
BEGIN
    SELECT 'Always On Availability Groups not enabled on this instance.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 7: XML Compression Usage — NEW in 2022
  XML compression can be applied to XML columns and indexes.
──────────────────────────────────────────────────────────────────────────────*/
-- Report partitions using XML compression (data_compression = 4 for XML)
SELECT
    DB_NAME()                                       AS database_name,
    OBJECT_SCHEMA_NAME(p.object_id)                 AS schema_name,
    OBJECT_NAME(p.object_id)                        AS table_name,
    i.name                                          AS index_name,
    p.partition_number,
    p.data_compression_desc                         AS compression_type,
    p.rows                                          AS row_count
FROM sys.partitions AS p
INNER JOIN sys.indexes AS i
    ON p.object_id = i.object_id
   AND p.index_id  = i.index_id
WHERE p.data_compression_desc = 'XML'               -- NEW in 2022
  AND p.rows > 0
ORDER BY schema_name, table_name, index_name;

/*──────────────────────────────────────────────────────────────────────────────
  Section 8: Key Server-Level Configuration
──────────────────────────────────────────────────────────────────────────────*/
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

/*──────────────────────────────────────────────────────────────────────────────
  Section 9: Resource Utilization Snapshot
──────────────────────────────────────────────────────────────────────────────*/
-- CPU utilization (last 256 minutes from ring buffer)
;WITH cpu_ring AS (
    SELECT
        record.value('(./Record/@id)[1]', 'INT')                                AS record_id,
        record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'INT')   AS system_idle,
        record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'INT') AS sql_cpu,
        DATEADD(ms, -1 * (si.cpu_ticks / (si.cpu_ticks / si.ms_ticks) - rb.timestamp), GETDATE()) AS event_time
    FROM (
        SELECT
            timestamp,
            CONVERT(XML, record) AS record
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
