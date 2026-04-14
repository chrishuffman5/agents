/*******************************************************************************
 * Script:    01-server-health.sql
 * Purpose:   Server overview and health check for SQL Server 2016
 * Version:   SQL Server 2016 (Compatibility Level 130)
 * Date:      2026-04-06
 *
 * Returns:   Instance version/edition, uptime, CPU/memory configuration,
 *            tempdb configuration, per-database recovery models, backup
 *            recency, and database sizes.
 *
 * Safety:    Read-only. Safe for production execution.
 ******************************************************************************/

SET NOCOUNT ON;

-- ============================================================================
-- SECTION 1: Instance Identity and Uptime
-- ============================================================================

SELECT
    SERVERPROPERTY('ServerName')            AS [Server Name],
    SERVERPROPERTY('ProductVersion')        AS [Product Version],
    SERVERPROPERTY('ProductLevel')          AS [Product Level],       -- SP/CU
    SERVERPROPERTY('Edition')               AS [Edition],
    SERVERPROPERTY('EngineEdition')         AS [Engine Edition],
    SERVERPROPERTY('ProductMajorVersion')   AS [Major Version],
    SERVERPROPERTY('ProductMinorVersion')   AS [Minor Version],
    SERVERPROPERTY('ProductBuild')          AS [Build Number],
    SERVERPROPERTY('Collation')             AS [Server Collation],
    SERVERPROPERTY('IsClustered')           AS [Is Clustered],
    SERVERPROPERTY('IsHadrEnabled')         AS [Is HADR Enabled],
    SERVERPROPERTY('IsFullTextInstalled')   AS [Full-Text Installed],
    si.sqlserver_start_time                 AS [SQL Server Start Time],
    DATEDIFF(DAY, si.sqlserver_start_time, GETDATE()) AS [Uptime Days],
    DATEDIFF(HOUR, si.sqlserver_start_time, GETDATE()) % 24 AS [Uptime Hours],
    @@SPID                                  AS [Current SPID]
FROM sys.dm_os_sys_info AS si;


-- ============================================================================
-- SECTION 2: CPU Configuration
-- ============================================================================

SELECT
    si.cpu_count                            AS [Logical CPUs],
    si.hyperthread_ratio                    AS [Hyperthread Ratio],
    si.cpu_count / si.hyperthread_ratio     AS [Physical CPUs],
    si.scheduler_count                      AS [Scheduler Count],
    si.max_workers_count                    AS [Max Worker Threads],
    (SELECT COUNT(*) FROM sys.dm_os_schedulers WHERE status = 'VISIBLE ONLINE')
                                            AS [Online Schedulers],
    si.affinity_type_desc                   AS [Affinity Type]
FROM sys.dm_os_sys_info AS si;


-- ============================================================================
-- SECTION 3: Memory Configuration
-- ============================================================================

SELECT
    si.physical_memory_kb / 1024            AS [Physical Memory MB],
    si.committed_kb / 1024                  AS [Committed Memory MB],
    si.committed_target_kb / 1024           AS [Target Memory MB],
    si.virtual_memory_kb / 1024             AS [Virtual Memory MB],
    c_min.value_in_use                      AS [Min Server Memory MB],
    c_max.value_in_use                      AS [Max Server Memory MB],
    (SELECT cntr_value / 1024
     FROM sys.dm_os_performance_counters
     WHERE object_name LIKE '%Memory Manager%'
       AND counter_name = 'Total Server Memory (KB)') AS [Total Server Memory MB],
    (SELECT cntr_value / 1024
     FROM sys.dm_os_performance_counters
     WHERE object_name LIKE '%Memory Manager%'
       AND counter_name = 'Target Server Memory (KB)') AS [Target Server Memory (Perf) MB],
    (SELECT cntr_value
     FROM sys.dm_os_performance_counters
     WHERE object_name LIKE '%Buffer Manager%'
       AND counter_name = 'Page life expectancy') AS [Page Life Expectancy Sec]
FROM sys.dm_os_sys_info AS si
CROSS JOIN sys.configurations AS c_min
CROSS JOIN sys.configurations AS c_max
WHERE c_min.name = 'min server memory (MB)'
  AND c_max.name = 'max server memory (MB)';


-- ============================================================================
-- SECTION 4: TempDB Configuration
-- ============================================================================
-- SQL Server 2016 introduced improved tempdb setup during install.

SELECT
    f.file_id                               AS [File ID],
    f.name                                  AS [Logical Name],
    f.physical_name                         AS [Physical Path],
    f.type_desc                             AS [File Type],
    f.size * 8 / 1024                       AS [Size MB],
    CASE f.max_size
        WHEN -1 THEN 'Unlimited'
        WHEN  0 THEN 'No Growth'
        ELSE CAST(f.max_size * 8 / 1024 AS VARCHAR(20)) + ' MB'
    END                                     AS [Max Size],
    CASE f.is_percent_growth
        WHEN 1 THEN CAST(f.growth AS VARCHAR(10)) + '%'
        ELSE CAST(f.growth * 8 / 1024 AS VARCHAR(10)) + ' MB'
    END                                     AS [Growth Setting]
FROM tempdb.sys.database_files AS f
ORDER BY f.type, f.file_id;


-- ============================================================================
-- SECTION 5: Database Inventory — Recovery Model, State, Size
-- ============================================================================

SELECT
    d.database_id                           AS [DB ID],
    d.name                                  AS [Database Name],
    d.state_desc                            AS [State],
    d.recovery_model_desc                   AS [Recovery Model],
    d.compatibility_level                   AS [Compat Level],
    d.page_verify_option_desc               AS [Page Verify],
    d.is_auto_shrink_on                     AS [Auto Shrink],
    d.is_auto_close_on                      AS [Auto Close],
    d.is_query_store_on                     AS [Query Store On],
    COALESCE(
        (SELECT SUM(mf.size) * 8 / 1024
         FROM sys.master_files AS mf
         WHERE mf.database_id = d.database_id
           AND mf.type = 0), 0)            AS [Data Size MB],
    COALESCE(
        (SELECT SUM(mf.size) * 8 / 1024
         FROM sys.master_files AS mf
         WHERE mf.database_id = d.database_id
           AND mf.type = 1), 0)            AS [Log Size MB],
    d.log_reuse_wait_desc                   AS [Log Reuse Wait]
FROM sys.databases AS d
ORDER BY d.name;


-- ============================================================================
-- SECTION 6: Last Backup Times per Database
-- ============================================================================
-- Shows the most recent FULL, DIFFERENTIAL, and LOG backups for each database.

SELECT
    d.name                                  AS [Database Name],
    d.recovery_model_desc                   AS [Recovery Model],
    fb.last_full_backup                     AS [Last Full Backup],
    DATEDIFF(HOUR, fb.last_full_backup, GETDATE())
                                            AS [Hours Since Full],
    db.last_diff_backup                     AS [Last Diff Backup],
    DATEDIFF(HOUR, db.last_diff_backup, GETDATE())
                                            AS [Hours Since Diff],
    lb.last_log_backup                      AS [Last Log Backup],
    CASE
        WHEN d.recovery_model_desc = 'SIMPLE' THEN 'N/A (Simple)'
        WHEN lb.last_log_backup IS NULL      THEN '*** NEVER ***'
        ELSE CAST(DATEDIFF(MINUTE, lb.last_log_backup, GETDATE()) AS VARCHAR(20)) + ' min'
    END                                     AS [Since Log Backup]
FROM sys.databases AS d
LEFT JOIN (
    SELECT database_name, MAX(backup_finish_date) AS last_full_backup
    FROM msdb.dbo.backupset WHERE type = 'D' GROUP BY database_name
) AS fb ON fb.database_name = d.name
LEFT JOIN (
    SELECT database_name, MAX(backup_finish_date) AS last_diff_backup
    FROM msdb.dbo.backupset WHERE type = 'I' GROUP BY database_name
) AS db ON db.database_name = d.name
LEFT JOIN (
    SELECT database_name, MAX(backup_finish_date) AS last_log_backup
    FROM msdb.dbo.backupset WHERE type = 'L' GROUP BY database_name
) AS lb ON lb.database_name = d.name
WHERE d.database_id > 4          -- exclude system databases
  AND d.state = 0                -- online only
ORDER BY
    ISNULL(fb.last_full_backup, '19000101') ASC;   -- worst first
