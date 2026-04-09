/******************************************************************************
* Script:   01-server-health.sql
* Purpose:  Comprehensive server health check for SQL Server 2017 instances.
*           Covers uptime, version, platform, configuration, database status,
*           backup recency, automatic tuning, CLR strict security, and
*           database-scoped configurations.
* Server:   SQL Server 2017 (compatibility level 140)
* Date:     2026-04-06
*
* NEW in 2017 vs 2016:
*   - Automatic tuning status check (FORCE_LAST_GOOD_PLAN)
*   - CLR strict security configuration
*   - Linux vs Windows platform detection
*   - Database-scoped configurations (introduced 2016, expanded 2017)
*   - sys.dm_db_tuning_recommendations
*
* Safety:   Read-only. No modifications to server or databases.
******************************************************************************/
SET NOCOUNT ON;

-- ============================================================================
-- Section 1: Instance Overview
-- ============================================================================
PRINT '=== Section 1: Instance Overview ===';
PRINT '';

SELECT
    SERVERPROPERTY('ServerName')                    AS [Server Name],
    SERVERPROPERTY('MachineName')                   AS [Machine Name],
    SERVERPROPERTY('InstanceName')                  AS [Instance Name],
    SERVERPROPERTY('ProductVersion')                AS [Product Version],
    SERVERPROPERTY('ProductLevel')                  AS [Product Level],
    SERVERPROPERTY('Edition')                       AS [Edition],
    SERVERPROPERTY('ProductUpdateLevel')            AS [Cumulative Update],
    SERVERPROPERTY('ProductUpdateReference')        AS [KB Article],
    @@VERSION                                       AS [Full Version String];

-- ============================================================================
-- Section 2: Platform Detection (NEW in 2017 -- Linux support)
-- ============================================================================
PRINT '';
PRINT '=== Section 2: Platform Detection (NEW in 2017) ===';
PRINT '';

SELECT
    SERVERPROPERTY('EngineEdition')                 AS [Engine Edition],
    CASE CAST(SERVERPROPERTY('EngineEdition') AS INT)
        WHEN 1 THEN 'Personal / Desktop'
        WHEN 2 THEN 'Standard'
        WHEN 3 THEN 'Enterprise'
        WHEN 4 THEN 'Express'
        WHEN 5 THEN 'Azure SQL Database'
        WHEN 6 THEN 'Azure SQL Data Warehouse'
        WHEN 8 THEN 'Azure SQL Managed Instance'
        ELSE 'Unknown (' + CAST(SERVERPROPERTY('EngineEdition') AS VARCHAR(10)) + ')'
    END                                             AS [Engine Edition Description],
    -- NEW in 2017: SQL Server can run on Linux
    CASE
        WHEN @@VERSION LIKE '%Linux%' THEN 'Linux'
        WHEN @@VERSION LIKE '%Windows%' THEN 'Windows'
        ELSE 'Unknown'
    END                                             AS [Host Operating System],
    SERVERPROPERTY('BuildClrVersion')               AS [CLR Version],
    SERVERPROPERTY('Collation')                     AS [Server Collation],
    SERVERPROPERTY('IsIntegratedSecurityOnly')      AS [Windows Auth Only],
    SERVERPROPERTY('IsClustered')                   AS [Is Clustered],
    SERVERPROPERTY('IsHadrEnabled')                 AS [Is AG Enabled],
    SERVERPROPERTY('IsFullTextInstalled')           AS [Full-Text Installed];

-- ============================================================================
-- Section 3: Uptime and Resource Summary
-- ============================================================================
PRINT '';
PRINT '=== Section 3: Uptime and Resource Summary ===';
PRINT '';

SELECT
    si.sqlserver_start_time                         AS [SQL Server Start Time],
    DATEDIFF(DAY, si.sqlserver_start_time, GETDATE()) AS [Uptime Days],
    DATEDIFF(HOUR, si.sqlserver_start_time, GETDATE()) AS [Uptime Hours],
    si.cpu_count                                    AS [Logical CPUs],
    si.hyperthread_ratio                            AS [Hyperthread Ratio],
    si.cpu_count / si.hyperthread_ratio             AS [Physical Cores],
    si.physical_memory_kb / 1024                    AS [Physical Memory MB],
    si.committed_kb / 1024                          AS [Committed Memory MB],
    si.committed_target_kb / 1024                   AS [Target Memory MB],
    si.max_workers_count                            AS [Max Worker Threads],
    si.scheduler_count                              AS [Scheduler Count]
FROM sys.dm_os_sys_info si;

-- ============================================================================
-- Section 4: Key Instance Configuration
-- ============================================================================
PRINT '';
PRINT '=== Section 4: Key Instance Configuration ===';
PRINT '';

SELECT
    name                                            AS [Configuration Name],
    CAST(value AS INT)                              AS [Configured Value],
    CAST(value_in_use AS INT)                       AS [Running Value],
    CASE
        WHEN CAST(value AS INT) <> CAST(value_in_use AS INT)
        THEN 'RESTART REQUIRED'
        ELSE 'OK'
    END                                             AS [Status],
    description                                     AS [Description]
FROM sys.configurations
WHERE name IN (
    'max degree of parallelism',
    'cost threshold for parallelism',
    'max server memory (MB)',
    'min server memory (MB)',
    'optimize for ad hoc workloads',
    'clr strict security',          -- NEW in 2017
    'clr enabled',
    'remote admin connections',
    'backup compression default',
    'max worker threads',
    'query store capture mode',
    'default trace enabled',
    'xp_cmdshell',
    'Ole Automation Procedures',
    'contained database authentication'
)
ORDER BY name;

-- ============================================================================
-- Section 5: CLR Strict Security Status (NEW in 2017)
-- ============================================================================
PRINT '';
PRINT '=== Section 5: CLR Strict Security (NEW in 2017) ===';
PRINT '';

-- CLR strict security is a breaking change in 2017: unsigned UNSAFE assemblies
-- are blocked by default even with TRUSTWORTHY ON.
SELECT
    name                                            AS [Setting],
    CAST(value_in_use AS INT)                       AS [Current Value],
    CASE CAST(value_in_use AS INT)
        WHEN 1 THEN 'ENABLED (default, recommended) -- UNSAFE assemblies must be signed'
        WHEN 0 THEN 'DISABLED (legacy mode) -- NOT recommended for production'
    END                                             AS [Status],
    'CLR strict security requires UNSAFE assemblies to be signed with a certificate or asymmetric key that has a corresponding login with UNSAFE ASSEMBLY permission.'
                                                    AS [Note]
FROM sys.configurations
WHERE name = 'clr strict security';

-- Check for trusted assemblies (workaround for unsigned assemblies in 2017)
SELECT
    CONVERT(NVARCHAR(128), ta.description)          AS [Assembly Description],
    ta.hash                                         AS [Assembly Hash]
FROM sys.trusted_assemblies ta;

-- ============================================================================
-- Section 6: Database Status Overview
-- ============================================================================
PRINT '';
PRINT '=== Section 6: Database Status Overview ===';
PRINT '';

SELECT
    d.database_id                                   AS [DB ID],
    d.name                                          AS [Database Name],
    d.state_desc                                    AS [State],
    d.recovery_model_desc                           AS [Recovery Model],
    d.compatibility_level                           AS [Compat Level],
    CASE
        WHEN d.compatibility_level < 140
        THEN 'Below 2017 -- missing adaptive QP, graph, etc.'
        WHEN d.compatibility_level = 140
        THEN 'SQL Server 2017'
        ELSE 'Above 2017'
    END                                             AS [Compat Level Note],
    d.page_verify_option_desc                       AS [Page Verify],
    d.is_auto_shrink_on                             AS [Auto Shrink],
    d.is_auto_close_on                              AS [Auto Close],
    d.is_query_store_on                             AS [Query Store On],
    d.is_auto_create_stats_on                       AS [Auto Create Stats],
    d.is_auto_update_stats_on                       AS [Auto Update Stats],
    d.is_auto_update_stats_async_on                 AS [Async Stats Update],
    d.log_reuse_wait_desc                           AS [Log Reuse Wait],
    CAST(DATABASEPROPERTYEX(d.name, 'IsAutoShrink') AS INT) AS [AutoShrink Check]
FROM sys.databases d
ORDER BY d.database_id;

-- ============================================================================
-- Section 7: Automatic Tuning Status per Database (NEW in 2017)
-- ============================================================================
PRINT '';
PRINT '=== Section 7: Automatic Tuning Status (NEW in 2017) ===';
PRINT '';

-- Automatic tuning (FORCE_LAST_GOOD_PLAN) requires Query Store to be enabled
-- and in READ_WRITE mode.
SELECT
    d.name                                          AS [Database Name],
    d.is_query_store_on                             AS [Query Store Enabled],
    ato.desired_state_desc                          AS [Desired Tuning State],
    ato.actual_state_desc                           AS [Actual Tuning State],
    ato.reason_desc                                 AS [Reason if Different]
FROM sys.databases d
CROSS APPLY (
    SELECT
        desired_state_desc,
        actual_state_desc,
        reason_desc
    FROM sys.dm_db_tuning_recommendations
    WHERE name = 'FORCE_LAST_GOOD_PLAN'
    -- This DMV is database-scoped; we query the current DB context
) ato
WHERE d.database_id > 4;

-- Alternative: check sys.database_automatic_tuning_options for each database
-- (This is the reliable catalog view approach)
PRINT '';
PRINT '--- Automatic Tuning Options per User Database ---';
PRINT '';

DECLARE @db_at_sql NVARCHAR(MAX) = N'';
SELECT @db_at_sql = @db_at_sql +
    N'USE ' + QUOTENAME(name) + N';
    SELECT
        DB_NAME()                                   AS [Database Name],
        name                                        AS [Tuning Option],
        desired_state_desc                          AS [Desired State],
        actual_state_desc                           AS [Actual State],
        reason_desc                                 AS [Reason]
    FROM sys.database_automatic_tuning_options;
    '
FROM sys.databases
WHERE database_id > 4
  AND state = 0;  -- ONLINE only

EXEC sp_executesql @db_at_sql;

-- ============================================================================
-- Section 8: Database-Scoped Configurations (introduced 2016, expanded 2017)
-- ============================================================================
PRINT '';
PRINT '=== Section 8: Database-Scoped Configurations ===';
PRINT '';

-- Database-scoped configs allow per-database optimizer/engine settings
-- without instance-level trace flags. Some new options in 2017.
DECLARE @db_dsc_sql NVARCHAR(MAX) = N'';
SELECT @db_dsc_sql = @db_dsc_sql +
    N'USE ' + QUOTENAME(name) + N';
    SELECT
        DB_NAME()                                   AS [Database Name],
        dsc.name                                    AS [Configuration],
        dsc.value                                   AS [Value (Primary)],
        dsc.value_for_secondary                     AS [Value (Secondary)]
    FROM sys.database_scoped_configurations dsc
    WHERE dsc.value <> 0
       OR dsc.value_for_secondary IS NOT NULL;
    '
FROM sys.databases
WHERE database_id > 4
  AND state = 0;

EXEC sp_executesql @db_dsc_sql;

-- ============================================================================
-- Section 9: Backup Status
-- ============================================================================
PRINT '';
PRINT '=== Section 9: Last Backup Times ===';
PRINT '';

SELECT
    d.name                                          AS [Database Name],
    d.recovery_model_desc                           AS [Recovery Model],
    MAX(CASE WHEN b.type = 'D'
        THEN b.backup_finish_date END)              AS [Last Full Backup],
    MAX(CASE WHEN b.type = 'I'
        THEN b.backup_finish_date END)              AS [Last Differential],
    MAX(CASE WHEN b.type = 'L'
        THEN b.backup_finish_date END)              AS [Last Log Backup],
    DATEDIFF(HOUR, MAX(CASE WHEN b.type = 'D'
        THEN b.backup_finish_date END), GETDATE())  AS [Hours Since Full],
    CASE
        WHEN MAX(CASE WHEN b.type = 'D'
            THEN b.backup_finish_date END) IS NULL
        THEN 'NEVER BACKED UP'
        WHEN DATEDIFF(DAY, MAX(CASE WHEN b.type = 'D'
            THEN b.backup_finish_date END), GETDATE()) > 7
        THEN 'STALE (> 7 days)'
        ELSE 'OK'
    END                                             AS [Backup Health]
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b ON d.name = b.database_name
WHERE d.database_id > 4
  AND d.state = 0
GROUP BY d.name, d.recovery_model_desc
ORDER BY d.name;

-- ============================================================================
-- Section 10: Database File Sizes and Growth
-- ============================================================================
PRINT '';
PRINT '=== Section 10: Database File Sizes ===';
PRINT '';

SELECT
    DB_NAME(mf.database_id)                         AS [Database Name],
    mf.name                                         AS [Logical File Name],
    mf.type_desc                                    AS [File Type],
    mf.physical_name                                AS [Physical Path],
    CAST(mf.size * 8.0 / 1024 AS DECIMAL(12,2))    AS [Size MB],
    CASE mf.is_percent_growth
        WHEN 1 THEN CAST(mf.growth AS VARCHAR(10)) + '%'
        ELSE CAST(CAST(mf.growth * 8.0 / 1024 AS DECIMAL(12,2)) AS VARCHAR(20)) + ' MB'
    END                                             AS [Growth Setting],
    CASE
        WHEN mf.is_percent_growth = 1
        THEN 'WARNING: Percent growth can cause uneven VLFs'
        WHEN mf.growth = 0
        THEN 'WARNING: Auto-growth disabled'
        WHEN mf.growth * 8 / 1024 > 1024
        THEN 'NOTE: Large growth increment (> 1 GB)'
        ELSE 'OK'
    END                                             AS [Growth Health],
    mf.max_size                                     AS [Max Size Setting]
FROM sys.master_files mf
ORDER BY mf.database_id, mf.type, mf.file_id;

-- ============================================================================
-- Section 11: SQL Server Error Log (Recent Errors)
-- ============================================================================
PRINT '';
PRINT '=== Section 11: Recent Error Log Entries ===';
PRINT '';

-- Pull recent severity errors from the current error log
CREATE TABLE #ErrorLog (
    LogDate     DATETIME,
    ProcessInfo NVARCHAR(50),
    LogText     NVARCHAR(MAX)
);

INSERT INTO #ErrorLog
EXEC sp_readerrorlog 0, 1, N'Error';

SELECT TOP 25
    LogDate                                         AS [Log Date],
    ProcessInfo                                     AS [Process],
    LogText                                         AS [Error Text]
FROM #ErrorLog
ORDER BY LogDate DESC;

DROP TABLE #ErrorLog;

-- ============================================================================
-- Section 12: Suspect Pages
-- ============================================================================
PRINT '';
PRINT '=== Section 12: Suspect Pages ===';
PRINT '';

SELECT
    DB_NAME(sp.database_id)                         AS [Database Name],
    sp.file_id                                      AS [File ID],
    sp.page_id                                      AS [Page ID],
    CASE sp.event_type
        WHEN 1 THEN '823 error'
        WHEN 2 THEN 'Bad checksum'
        WHEN 3 THEN 'Torn page'
        WHEN 4 THEN 'Restored (823)'
        WHEN 5 THEN 'Repaired (DBCC)'
        WHEN 7 THEN 'Deallocated (DBCC)'
    END                                             AS [Event Type],
    sp.error_count                                  AS [Error Count],
    sp.last_update_date                             AS [Last Occurrence]
FROM msdb.dbo.suspect_pages sp
ORDER BY sp.last_update_date DESC;

PRINT '';
PRINT '=== Server Health Check Complete ===';
