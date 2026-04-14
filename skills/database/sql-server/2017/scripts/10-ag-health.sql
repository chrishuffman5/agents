/******************************************************************************
* Script:   10-ag-health.sql
* Purpose:  Always On Availability Group health diagnostics including replica
*           status, synchronization state, latency, failover readiness, and
*           automatic seeding status (NEW in 2017 enhancement).
* Server:   SQL Server 2017 (compatibility level 140)
* Date:     2026-04-06
*
* NEW in 2017 vs 2016:
*   - Automatic seeding was introduced in 2016 but enhanced in 2017
*   - Monitoring automatic seeding status and progress
*   - SQL Server on Linux can participate in AG clusters
*
* Safety:   Read-only. No modifications to server or databases.
* Note:     This script requires Always On AGs to be enabled. Sections will
*           return empty results or be skipped if AGs are not configured.
******************************************************************************/
SET NOCOUNT ON;

-- ============================================================================
-- Section 1: Availability Group Overview
-- ============================================================================
PRINT '=== Section 1: Availability Group Overview ===';
PRINT '';

IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS [AG Name],
        ag.group_id                                 AS [AG Group ID],
        ag.automated_backup_preference_desc         AS [Backup Preference],
        ag.failure_condition_level                  AS [Failure Condition Level],
        ag.health_check_timeout                     AS [Health Check Timeout Ms],
        -- NEW/Enhanced in 2017: Cluster type can be WSFC, EXTERNAL (Linux), or NONE
        ag.cluster_type_desc                        AS [Cluster Type],
        ag.required_synchronized_secondaries_to_commit
                                                    AS [Required Sync Secondaries],
        ag.is_distributed                           AS [Is Distributed AG],
        agstates.primary_replica                    AS [Primary Replica],
        agstates.synchronization_health_desc        AS [Overall Sync Health]
    FROM sys.availability_groups ag
    LEFT JOIN sys.dm_hadr_availability_group_states agstates
        ON ag.group_id = agstates.group_id
    ORDER BY ag.name;
END
ELSE
BEGIN
    PRINT 'Always On Availability Groups are not enabled on this instance.';
    PRINT 'Enable via: ALTER SERVER CONFIGURATION SET HADR CLUSTER CONTEXT = LOCAL;';
END;

-- ============================================================================
-- Section 2: Replica Status and Configuration
-- ============================================================================
PRINT '';
PRINT '=== Section 2: Replica Status and Configuration ===';
PRINT '';

IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS [AG Name],
        ar.replica_server_name                      AS [Replica Server],
        ar.availability_mode_desc                   AS [Availability Mode],
        ar.failover_mode_desc                       AS [Failover Mode],
        ars.role_desc                               AS [Current Role],
        ars.connected_state_desc                    AS [Connected State],
        ars.operational_state_desc                  AS [Operational State],
        ars.recovery_health_desc                    AS [Recovery Health],
        ars.synchronization_health_desc             AS [Sync Health],
        ar.endpoint_url                             AS [Endpoint URL],
        ar.session_timeout                          AS [Session Timeout Sec],
        ar.primary_role_allow_connections_desc      AS [Primary Connections],
        ar.secondary_role_allow_connections_desc    AS [Secondary Connections],
        ar.backup_priority                          AS [Backup Priority],
        ar.read_only_routing_url                    AS [Read-Only Routing URL],
        -- Seeding mode (introduced 2016, important for 2017 monitoring)
        ar.seeding_mode_desc                        AS [Seeding Mode]
    FROM sys.availability_replicas ar
    JOIN sys.availability_groups ag
        ON ar.group_id = ag.group_id
    LEFT JOIN sys.dm_hadr_availability_replica_states ars
        ON ar.replica_id = ars.replica_id
    ORDER BY ag.name, ar.replica_server_name;
END;

-- ============================================================================
-- Section 3: Database Replica Synchronization
-- ============================================================================
PRINT '';
PRINT '=== Section 3: Database Replica Synchronization ===';
PRINT '';

IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS [AG Name],
        ar.replica_server_name                      AS [Replica Server],
        drs.database_name                           AS [Database],
        drs.synchronization_state_desc              AS [Sync State],
        drs.synchronization_health_desc             AS [Sync Health],
        drs.is_suspended                            AS [Is Suspended],
        drs.suspend_reason_desc                     AS [Suspend Reason],
        drs.log_send_queue_size                     AS [Log Send Queue KB],
        drs.log_send_rate                           AS [Log Send Rate KB/s],
        drs.redo_queue_size                         AS [Redo Queue KB],
        drs.redo_rate                               AS [Redo Rate KB/s],
        -- Estimated catch-up time
        CASE
            WHEN drs.redo_rate > 0
            THEN CAST(drs.redo_queue_size / drs.redo_rate AS DECIMAL(10,2))
            ELSE NULL
        END                                         AS [Est Redo Catchup Sec],
        CASE
            WHEN drs.log_send_rate > 0
            THEN CAST(drs.log_send_queue_size / drs.log_send_rate AS DECIMAL(10,2))
            ELSE NULL
        END                                         AS [Est Send Catchup Sec],
        drs.last_hardened_lsn                       AS [Last Hardened LSN],
        drs.last_hardened_time                      AS [Last Hardened Time],
        drs.last_redone_lsn                         AS [Last Redone LSN],
        drs.last_redone_time                        AS [Last Redone Time],
        drs.last_commit_lsn                         AS [Last Commit LSN],
        drs.last_commit_time                        AS [Last Commit Time],
        drs.is_primary_replica                      AS [Is Primary],
        -- Assessment
        CASE
            WHEN drs.synchronization_health_desc = 'NOT_HEALTHY'
            THEN 'CRITICAL -- Database replica is not healthy'
            WHEN drs.is_suspended = 1
            THEN 'WARNING -- Data movement is suspended'
            WHEN drs.log_send_queue_size > 102400
            THEN 'WARNING -- Log send queue > 100 MB'
            WHEN drs.redo_queue_size > 102400
            THEN 'WARNING -- Redo queue > 100 MB'
            ELSE 'OK'
        END                                         AS [Assessment]
    FROM sys.dm_hadr_database_replica_states drs
    JOIN sys.availability_replicas ar
        ON drs.replica_id = ar.replica_id
    JOIN sys.availability_groups ag
        ON ar.group_id = ag.group_id
    ORDER BY ag.name, ar.replica_server_name, drs.database_name;
END;

-- ============================================================================
-- Section 4: Automatic Seeding Status (NEW/Enhanced in 2017)
-- ============================================================================
PRINT '';
PRINT '=== Section 4: Automatic Seeding Status ===';
PRINT '';

IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    -- Current automatic seeding operations
    PRINT '--- Active Seeding Operations ---';
    SELECT
        ag.name                                     AS [AG Name],
        ar.replica_server_name                      AS [Target Replica],
        asd.database_name                           AS [Database],
        asd.start_time                              AS [Seed Start Time],
        asd.completion_time                         AS [Completion Time],
        asd.current_state                           AS [Current State],
        asd.performed_seeding                       AS [Seeding Performed],
        asd.failure_state_desc                      AS [Failure State],
        asd.error_code                              AS [Error Code],
        CASE
            WHEN asd.current_state = 'COMPLETED'
            THEN 'Seeding completed successfully'
            WHEN asd.current_state = 'SEEDING'
            THEN 'Seeding in progress'
            WHEN asd.failure_state_desc IS NOT NULL
            THEN 'FAILED -- Check error_code for details'
            ELSE asd.current_state
        END                                         AS [Status]
    FROM sys.dm_hadr_automatic_seeding asd
    JOIN sys.availability_replicas ar
        ON asd.remote_machine_name = ar.replica_server_name
    JOIN sys.availability_groups ag
        ON ar.group_id = ag.group_id
    ORDER BY asd.start_time DESC;

    -- Seeding stats summary
    PRINT '';
    PRINT '--- Seeding Statistics ---';
    SELECT
        ag.name                                     AS [AG Name],
        ar.replica_server_name                      AS [Replica],
        ar.seeding_mode_desc                        AS [Seeding Mode],
        hss.number_of_attempts                      AS [Seeding Attempts],
        hss.number_of_success                       AS [Successful Seeds],
        CASE
            WHEN hss.number_of_attempts > 0
             AND hss.number_of_success < hss.number_of_attempts
            THEN 'WARNING -- Not all seeding attempts succeeded'
            ELSE 'OK'
        END                                         AS [Assessment]
    FROM sys.availability_replicas ar
    JOIN sys.availability_groups ag
        ON ar.group_id = ag.group_id
    LEFT JOIN sys.dm_hadr_physical_seeding_stats hss
        ON ar.replica_id = hss.remote_machine_name
    WHERE ar.seeding_mode_desc = 'AUTOMATIC'
    ORDER BY ag.name, ar.replica_server_name;
END;

-- ============================================================================
-- Section 5: AG Listener Status
-- ============================================================================
PRINT '';
PRINT '=== Section 5: Availability Group Listeners ===';
PRINT '';

IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS [AG Name],
        agl.dns_name                                AS [Listener DNS Name],
        agl.port                                    AS [Listener Port],
        agl.ip_configuration_string_from_cluster    AS [IP Configuration],
        aglip.ip_address                            AS [IP Address],
        aglip.ip_subnet_mask                        AS [Subnet Mask],
        aglip.state_desc                            AS [IP State]
    FROM sys.availability_group_listeners agl
    JOIN sys.availability_groups ag
        ON agl.group_id = ag.group_id
    LEFT JOIN sys.availability_group_listener_ip_addresses aglip
        ON agl.listener_id = aglip.listener_id
    ORDER BY ag.name;
END;

-- ============================================================================
-- Section 6: AG Performance Counters
-- ============================================================================
PRINT '';
PRINT '=== Section 6: AG Performance Counters ===';
PRINT '';

IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        object_name                                 AS [Object],
        counter_name                                AS [Counter],
        instance_name                               AS [Instance],
        cntr_value                                  AS [Value]
    FROM sys.dm_os_performance_counters
    WHERE object_name LIKE '%Availability Replica%'
       OR object_name LIKE '%Database Replica%'
    ORDER BY object_name, counter_name, instance_name;
END;

-- ============================================================================
-- Section 7: Cluster Node Status
-- ============================================================================
PRINT '';
PRINT '=== Section 7: Cluster Node Status ===';
PRINT '';

IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        member_name                                 AS [Node Name],
        member_type_desc                            AS [Member Type],
        member_state_desc                           AS [State],
        number_of_quorum_votes                      AS [Quorum Votes]
    FROM sys.dm_hadr_cluster_members
    ORDER BY member_name;

    SELECT
        cluster_name                                AS [Cluster Name],
        quorum_type_desc                            AS [Quorum Type],
        quorum_state_desc                           AS [Quorum State]
    FROM sys.dm_hadr_cluster;
END;

-- ============================================================================
-- Section 8: Automatic Page Repair History
-- ============================================================================
PRINT '';
PRINT '=== Section 8: Automatic Page Repair History ===';
PRINT '';

IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        DB_NAME(database_id)                        AS [Database],
        file_id                                     AS [File ID],
        page_id                                     AS [Page ID],
        error_type                                  AS [Error Type],
        page_status                                 AS [Page Status],
        modification_time                           AS [Repair Time]
    FROM sys.dm_hadr_auto_page_repair
    ORDER BY modification_time DESC;

    IF @@ROWCOUNT = 0
        PRINT 'No automatic page repairs recorded.';
END;

-- ============================================================================
-- Section 9: Failover Readiness Assessment
-- ============================================================================
PRINT '';
PRINT '=== Section 9: Failover Readiness Assessment ===';
PRINT '';

IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS [AG Name],
        ar.replica_server_name                      AS [Replica],
        ar.failover_mode_desc                       AS [Failover Mode],
        ars.role_desc                               AS [Current Role],
        ars.synchronization_health_desc             AS [Sync Health],
        CASE
            WHEN ars.role_desc = 'SECONDARY'
             AND ar.failover_mode_desc = 'AUTOMATIC'
             AND ars.synchronization_health_desc = 'HEALTHY'
            THEN 'READY for automatic failover'
            WHEN ars.role_desc = 'SECONDARY'
             AND ars.synchronization_health_desc = 'HEALTHY'
            THEN 'READY for manual failover'
            WHEN ars.role_desc = 'SECONDARY'
             AND ars.synchronization_health_desc <> 'HEALTHY'
            THEN 'NOT READY -- synchronization not healthy'
            WHEN ars.role_desc = 'PRIMARY'
            THEN 'Current primary'
            ELSE 'Unknown'
        END                                         AS [Failover Readiness],
        -- Check all databases are synchronized
        (SELECT COUNT(*)
         FROM sys.dm_hadr_database_replica_states drs2
         WHERE drs2.replica_id = ar.replica_id
           AND drs2.synchronization_state_desc <> 'SYNCHRONIZED'
           AND drs2.synchronization_state_desc <> 'SYNCHRONIZING')
                                                    AS [Non-Synced DB Count]
    FROM sys.availability_replicas ar
    JOIN sys.availability_groups ag
        ON ar.group_id = ag.group_id
    LEFT JOIN sys.dm_hadr_availability_replica_states ars
        ON ar.replica_id = ars.replica_id
    ORDER BY ag.name, ars.role_desc;
END;

PRINT '';
PRINT '=== AG Health Analysis Complete ===';
