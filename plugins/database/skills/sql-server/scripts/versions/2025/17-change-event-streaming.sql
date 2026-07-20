/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Change Event Streaming (CES)
 *
 * Purpose : Monitor Change Event Streaming configuration, health, latency,
 *           and errors -- entirely NEW in SQL Server 2025.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * CES streams data changes to Azure Event Hubs in near real-time via AMQP
 * or Apache Kafka protocol. Requires FULL recovery model.
 *
 * Key stored procedures (configuration):
 *   sys.sp_enable_event_stream          - Enable CES on database
 *   sys.sp_create_event_stream_group    - Create stream group
 *   sys.sp_add_object_to_event_stream_group - Add table to group
 *   sys.sp_disable_event_stream         - Disable CES
 *   sys.sp_drop_event_stream_group      - Drop stream group
 *   sys.sp_remove_object_from_event_stream_group - Remove table
 *
 * Key DMVs (monitoring):
 *   sys.dm_change_feed_log_scan_sessions - Log scan activity
 *   sys.dm_change_feed_errors            - Delivery errors
 *   sp_help_change_feed_settings         - Current CES settings
 *   sp_help_change_feed                  - Current configuration
 *   sp_help_change_feed_table_groups     - Stream group metadata
 *   sp_help_change_feed_table            - Table metadata
 *
 * Sections:
 *   1. CES-Enabled Databases
 *   2. CES Configuration Overview
 *   3. Stream Group Metadata
 *   4. Streamed Tables
 *   5. Log Scan Session Activity
 *   6. CES Delivery Errors
 *   7. Transaction Log Impact
 *   8. CES Health Dashboard
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: CES-Enabled Databases -- NEW in 2025
  sys.databases.is_event_stream_enabled indicates CES status.
  CES requires FULL recovery model.
------------------------------------------------------------------------------*/
SELECT
    d.database_id,
    d.name                                          AS database_name,
    d.is_event_stream_enabled,                                                 -- NEW in 2025
    d.recovery_model_desc                           AS recovery_model,
    d.state_desc                                    AS state,
    CASE
        WHEN d.is_event_stream_enabled = 1
         AND d.recovery_model_desc = 'FULL'
        THEN 'OK: CES active with FULL recovery'
        WHEN d.is_event_stream_enabled = 1
         AND d.recovery_model_desc <> 'FULL'
        THEN 'WARNING: CES requires FULL recovery model'
        WHEN d.is_event_stream_enabled = 0
         AND d.recovery_model_desc = 'FULL'
        THEN 'ELIGIBLE: FULL recovery, CES not enabled'
        ELSE 'NOT ELIGIBLE: Requires FULL recovery model'
    END                                             AS ces_status,
    -- Check for incompatible features
    CASE
        WHEN d.is_event_stream_enabled = 1
        THEN 'Active'
        ELSE 'Inactive'
    END                                             AS streaming_state
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.state = 0
ORDER BY d.is_event_stream_enabled DESC, d.name;

/*------------------------------------------------------------------------------
  Section 2: CES Configuration Overview -- NEW in 2025
  Uses sp_help_change_feed_settings to retrieve current CES settings.
  This procedure returns status and configuration details.
  Run in the context of a CES-enabled database.
------------------------------------------------------------------------------*/
-- Note: This proc returns results only when CES is enabled on the current DB
EXEC sp_help_change_feed_settings;

/*------------------------------------------------------------------------------
  Section 3: Stream Group Metadata -- NEW in 2025
  Uses sp_help_change_feed_table_groups to list configured stream groups.
  Each stream group defines a destination, credentials, and partitioning.
------------------------------------------------------------------------------*/
EXEC sp_help_change_feed_table_groups;

/*------------------------------------------------------------------------------
  Section 4: Streamed Tables -- NEW in 2025
  Identifies tables configured for CES.
  sys.tables.is_replicated = 1 indicates a table is streamed by CES.
  sp_help_change_feed_table provides detailed metadata.
------------------------------------------------------------------------------*/
-- 4a. Tables with CES streaming
SELECT
    OBJECT_SCHEMA_NAME(t.object_id)                 AS schema_name,
    t.name                                          AS table_name,
    t.is_replicated                                 AS is_streamed,
    t.type_desc,
    p.rows                                          AS row_count
FROM sys.tables AS t
LEFT JOIN sys.partitions AS p
    ON t.object_id = p.object_id
   AND p.index_id IN (0, 1)
   AND p.partition_number = 1
WHERE t.is_replicated = 1
ORDER BY schema_name, t.name;

/*------------------------------------------------------------------------------
  Section 5: Log Scan Session Activity -- NEW in 2025
  sys.dm_change_feed_log_scan_sessions tracks log reader activity.
  Monitors how CES reads the transaction log to capture changes.
------------------------------------------------------------------------------*/
SELECT
    session_id,
    start_time,
    end_time,
    DATEDIFF(SECOND, start_time, COALESCE(end_time, GETDATE()))
                                                    AS duration_seconds,
    scan_phase,
    error_count,
    scan_count,
    command_count,
    latency,
    empty_scan_count,
    log_record_count,
    schema_change_count,
    CASE
        WHEN error_count > 0
        THEN 'WARNING: Errors detected in log scan'
        WHEN end_time IS NULL
        THEN 'RUNNING: Active log scan session'
        ELSE 'COMPLETED'
    END                                             AS session_status
FROM sys.dm_change_feed_log_scan_sessions
ORDER BY start_time DESC;

/*------------------------------------------------------------------------------
  Section 6: CES Delivery Errors -- NEW in 2025
  sys.dm_change_feed_errors captures errors during event delivery.
  Persistent errors prevent log truncation and cause log growth.
------------------------------------------------------------------------------*/
SELECT
    session_id,
    source_task,
    error_number,
    error_severity,
    error_state,
    error_message,
    entry_time,
    CASE
        WHEN error_severity >= 16
        THEN 'CRITICAL: High severity error'
        WHEN error_severity >= 11
        THEN 'WARNING: Moderate severity'
        ELSE 'INFO: Low severity'
    END                                             AS severity_level
FROM sys.dm_change_feed_errors
ORDER BY entry_time DESC;

/*------------------------------------------------------------------------------
  Section 7: Transaction Log Impact -- NEW in 2025
  CES prevents log truncation while changes are pending delivery.
  Monitor log size and log_reuse_wait to detect CES-related growth.
------------------------------------------------------------------------------*/
SELECT
    d.name                                          AS database_name,
    d.is_event_stream_enabled,
    d.log_reuse_wait_desc                           AS log_reuse_wait,
    -- Log file sizes
    ls.total_log_size_mb,
    ls.used_log_space_mb,
    ls.used_log_space_pct,
    CASE
        WHEN d.is_event_stream_enabled = 1
         AND d.log_reuse_wait_desc IN ('REPLICATION', 'CHANGE_EVENT_STREAMING')
        THEN 'WARNING: CES preventing log truncation'
        WHEN d.is_event_stream_enabled = 1
         AND ls.used_log_space_pct > 80
        THEN 'WARNING: Log > 80% used with CES active'
        ELSE 'OK'
    END                                             AS log_status
FROM sys.databases AS d
CROSS APPLY (
    SELECT
        CAST(SUM(mf.size) * 8.0 / 1024 AS DECIMAL(18,2)) AS total_log_size_mb,
        CAST(FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0 / 1024 AS DECIMAL(18,2))
                                                    AS used_log_space_mb,
        CAST(FILEPROPERTY(mf.name, 'SpaceUsed') * 100.0
            / NULLIF(SUM(mf.size), 0) AS DECIMAL(5,2))
                                                    AS used_log_space_pct
    FROM sys.master_files AS mf
    WHERE mf.database_id = d.database_id
      AND mf.type = 1
    GROUP BY mf.name
) AS ls
WHERE d.database_id > 4
  AND d.state = 0
  AND d.is_event_stream_enabled = 1
ORDER BY ls.used_log_space_pct DESC;

/*------------------------------------------------------------------------------
  Section 8: CES Health Dashboard -- NEW in 2025
  Consolidated health view combining all CES monitoring data.
------------------------------------------------------------------------------*/
SELECT
    'CES Health Summary'                            AS report_section,
    GETDATE()                                       AS report_time;

-- Count of CES-enabled databases
SELECT
    COUNT(CASE WHEN is_event_stream_enabled = 1 THEN 1 END)
                                                    AS ces_enabled_databases,
    COUNT(CASE WHEN is_event_stream_enabled = 0 THEN 1 END)
                                                    AS ces_disabled_databases
FROM sys.databases
WHERE database_id > 4 AND state = 0;

-- Recent error summary
SELECT
    COUNT(*)                                        AS total_errors,
    MAX(entry_time)                                 AS last_error_time,
    COUNT(CASE WHEN error_severity >= 16 THEN 1 END)
                                                    AS critical_errors,
    COUNT(CASE WHEN DATEDIFF(HOUR, entry_time, GETDATE()) <= 1 THEN 1 END)
                                                    AS errors_last_hour,
    COUNT(CASE WHEN DATEDIFF(HOUR, entry_time, GETDATE()) <= 24 THEN 1 END)
                                                    AS errors_last_24h
FROM sys.dm_change_feed_errors;

-- Latest log scan session performance
SELECT TOP (5)
    session_id,
    start_time,
    end_time,
    scan_count,
    command_count,
    log_record_count,
    error_count,
    latency
FROM sys.dm_change_feed_log_scan_sessions
ORDER BY start_time DESC;
