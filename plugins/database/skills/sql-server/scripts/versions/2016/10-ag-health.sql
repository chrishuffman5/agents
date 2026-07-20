/*******************************************************************************
 * Script:    10-ag-health.sql
 * Purpose:   Always On Availability Group monitoring
 * Version:   SQL Server 2016 (Compatibility Level 130)
 * Date:      2026-04-06
 *
 * Returns:   AG configuration, replica states, synchronisation health,
 *            log send/redo queues, estimated recovery time, and database
 *            replica states.
 *
 * Notes:     These DMVs only return data on instances that host AG replicas.
 *            The script first checks whether AGs are configured before
 *            running the detail queries.
 *
 * Safety:    Read-only. Safe for production execution.
 ******************************************************************************/

SET NOCOUNT ON;

-- ============================================================================
-- SECTION 0: Check Whether Always On Is Enabled and AGs Exist
-- ============================================================================

DECLARE @HadrEnabled SQL_VARIANT = SERVERPROPERTY('IsHadrEnabled');
DECLARE @AGCount INT = 0;

IF @HadrEnabled = 1
BEGIN
    SELECT @AGCount = COUNT(*) FROM sys.availability_groups;
END;

SELECT
    CAST(@HadrEnabled AS INT)                   AS [HADR Enabled],
    @AGCount                                    AS [Availability Group Count],
    CASE
        WHEN @HadrEnabled <> 1
            THEN 'Always On is NOT enabled on this instance. Remaining sections will return no data.'
        WHEN @AGCount = 0
            THEN 'Always On is enabled but no Availability Groups are configured.'
        ELSE 'Always On is enabled with ' + CAST(@AGCount AS VARCHAR(10)) + ' AG(s) configured.'
    END                                         AS [Status];


-- ============================================================================
-- SECTION 1: Availability Group Overview
-- ============================================================================

SELECT
    ag.name                                     AS [AG Name],
    ag.group_id                                 AS [AG Group ID],
    ags.primary_replica                         AS [Primary Replica],
    ags.primary_recovery_health_desc            AS [Primary Recovery Health],
    ags.secondary_recovery_health_desc          AS [Secondary Recovery Health],
    ags.synchronization_health_desc             AS [AG Sync Health],
    ag.automated_backup_preference_desc         AS [Backup Preference],
    ag.failure_condition_level                  AS [Failure Condition Level],
    ag.health_check_timeout                     AS [Health Check Timeout Ms],
    CASE ag.automated_backup_preference
        WHEN 0 THEN 'Primary'
        WHEN 1 THEN 'Secondary Only'
        WHEN 2 THEN 'Prefer Secondary'
        WHEN 3 THEN 'Any Replica'
    END                                         AS [Backup Preference Desc]
FROM sys.availability_groups AS ag
LEFT JOIN sys.dm_hadr_availability_group_states AS ags
    ON ags.group_id = ag.group_id;


-- ============================================================================
-- SECTION 2: Replica States
-- ============================================================================
-- Shows each replica's role, sync mode, health, and connectivity.

SELECT
    ag.name                                     AS [AG Name],
    ar.replica_server_name                      AS [Replica Server],
    ars.role_desc                                AS [Current Role],
    ar.availability_mode_desc                   AS [Availability Mode],
    ar.failover_mode_desc                       AS [Failover Mode],
    ars.connected_state_desc                    AS [Connected State],
    ars.synchronization_health_desc             AS [Sync Health],
    ars.operational_state_desc                  AS [Operational State],
    ars.recovery_health_desc                    AS [Recovery Health],
    ars.last_connect_error_number               AS [Last Connect Error],
    ars.last_connect_error_description          AS [Last Connect Error Desc],
    ars.last_connect_error_timestamp            AS [Last Connect Error Time],
    ar.endpoint_url                             AS [Endpoint URL],
    ar.session_timeout                          AS [Session Timeout Sec],
    ar.primary_role_allow_connections_desc      AS [Primary Connections],
    ar.secondary_role_allow_connections_desc    AS [Secondary Connections],
    ar.backup_priority                          AS [Backup Priority],
    ar.read_only_routing_url                    AS [Read-Only Routing URL]
FROM sys.availability_replicas AS ar
INNER JOIN sys.availability_groups AS ag
    ON ag.group_id = ar.group_id
LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
    ON ars.replica_id = ar.replica_id
ORDER BY ag.name, ars.role_desc DESC, ar.replica_server_name;


-- ============================================================================
-- SECTION 3: Database Replica States — Sync Detail
-- ============================================================================
-- Per-database synchronisation status with queue sizes and rates.

SELECT
    ag.name                                     AS [AG Name],
    ar.replica_server_name                      AS [Replica],
    DB_NAME(drs.database_id)                    AS [Database],
    drs.synchronization_state_desc              AS [Sync State],
    drs.synchronization_health_desc             AS [Sync Health],
    drs.database_state_desc                     AS [DB State],
    drs.is_suspended                            AS [Is Suspended],
    drs.suspend_reason_desc                     AS [Suspend Reason],

    -- Log send queue: how far behind the secondary is (bytes to send)
    drs.log_send_queue_size                     AS [Log Send Queue KB],
    CASE
        WHEN drs.log_send_queue_size > 500000
            THEN '*** LARGE QUEUE (>500 MB) ***'
        WHEN drs.log_send_queue_size > 100000
            THEN 'ELEVATED (>100 MB)'
        ELSE 'OK'
    END                                         AS [Send Queue Alert],

    -- Log send rate (KB/sec)
    drs.log_send_rate                           AS [Log Send Rate KB/sec],

    -- Redo queue: hardened on secondary but not yet applied
    drs.redo_queue_size                         AS [Redo Queue KB],
    CASE
        WHEN drs.redo_queue_size > 500000
            THEN '*** LARGE REDO QUEUE (>500 MB) ***'
        WHEN drs.redo_queue_size > 100000
            THEN 'ELEVATED (>100 MB)'
        ELSE 'OK'
    END                                         AS [Redo Queue Alert],

    -- Redo rate (KB/sec)
    drs.redo_rate                               AS [Redo Rate KB/sec],

    -- Estimated catch-up time
    CASE
        WHEN drs.redo_rate > 0
            THEN CAST(drs.redo_queue_size * 1.0 / drs.redo_rate AS DECIMAL(18,2))
        ELSE NULL
    END                                         AS [Est Redo Catch-Up Sec],

    -- Last hardened / commit times
    drs.last_hardened_time                      AS [Last Hardened Time],
    drs.last_redone_time                        AS [Last Redone Time],
    drs.last_commit_time                        AS [Last Commit Time],
    drs.last_sent_time                          AS [Last Sent Time],
    drs.last_received_time                      AS [Last Received Time],

    -- Lag from last commit to now
    DATEDIFF(SECOND, drs.last_commit_time, GETDATE())
                                                AS [Commit Lag Sec],

    -- Truncation LSN for diagnostics
    drs.truncation_lsn                          AS [Truncation LSN],
    drs.recovery_lsn                            AS [Recovery LSN]

FROM sys.dm_hadr_database_replica_states AS drs
INNER JOIN sys.availability_replicas AS ar
    ON ar.replica_id = drs.replica_id
INNER JOIN sys.availability_groups AS ag
    ON ag.group_id = ar.group_id
ORDER BY ag.name, DB_NAME(drs.database_id), ar.replica_server_name;


-- ============================================================================
-- SECTION 4: AG Listener Configuration
-- ============================================================================

SELECT
    ag.name                                     AS [AG Name],
    agl.dns_name                                AS [Listener DNS Name],
    agl.port                                    AS [Listener Port],
    agl.ip_configuration_string_from_cluster    AS [IP Config],
    aglip.ip_address                            AS [IP Address],
    aglip.ip_subnet_mask                        AS [Subnet Mask],
    aglip.state_desc                            AS [IP State],
    aglip.is_dhcp                               AS [Is DHCP]
FROM sys.availability_group_listeners AS agl
INNER JOIN sys.availability_groups AS ag
    ON ag.group_id = agl.group_id
LEFT JOIN sys.availability_group_listener_ip_addresses AS aglip
    ON aglip.listener_id = agl.listener_id
ORDER BY ag.name;


-- ============================================================================
-- SECTION 5: Cluster Node Health
-- ============================================================================
-- Shows WSFC node status from SQL Server's perspective.

SELECT
    member_name                                 AS [Node Name],
    member_type_desc                            AS [Member Type],
    member_state_desc                           AS [Member State],
    number_of_quorum_votes                      AS [Quorum Votes]
FROM sys.dm_hadr_cluster_members
ORDER BY member_name;


-- ============================================================================
-- SECTION 6: Cluster Quorum State
-- ============================================================================

SELECT
    cluster_name                                AS [Cluster Name],
    quorum_type_desc                            AS [Quorum Type],
    quorum_state_desc                           AS [Quorum State]
FROM sys.dm_hadr_cluster;


-- ============================================================================
-- SECTION 7: AG Performance Counters
-- ============================================================================
-- Key performance counters for Always On monitoring.

SELECT
    object_name                                 AS [Object],
    counter_name                                AS [Counter],
    instance_name                               AS [Instance],
    cntr_value                                  AS [Value]
FROM sys.dm_os_performance_counters
WHERE object_name LIKE '%Availability Replica%'
   OR object_name LIKE '%Database Replica%'
ORDER BY object_name, counter_name, instance_name;
