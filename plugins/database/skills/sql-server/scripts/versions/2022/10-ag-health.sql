/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Availability Group Health
 *
 * Purpose : Monitor AG health, replication status, and 2022 enhancements.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x) with Always On enabled.
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. AG Cluster & Configuration (with Contained AG — NEW in 2022)
 *   2. Replica State & Health
 *   3. Database Replica State (Sync, Redo, Send Lag)
 *   4. AG Listener Details
 *   5. Automatic Seeding Progress
 *   6. Query Store on Secondaries Status (NEW in 2022)
 *   7. AG Performance Counters
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Prerequisite: Check if Always On is enabled
──────────────────────────────────────────────────────────────────────────────*/
IF SERVERPROPERTY('IsHadrEnabled') <> 1
BEGIN
    SELECT 'Always On Availability Groups are not enabled on this instance.' AS info_message;
    -- Remaining sections will be skipped via IF blocks
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: AG Cluster & Configuration (with Contained AG)
──────────────────────────────────────────────────────────────────────────────*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    -- AG configuration
    SELECT
        ag.group_id,
        ag.name                                     AS ag_name,
        ag.is_contained,                                                        -- NEW in 2022: Contained AG
        CASE ag.is_contained
            WHEN 1 THEN 'Yes - AG has its own master/msdb/tempdb'
            WHEN 0 THEN 'No - Traditional AG'
            ELSE 'Unknown'
        END                                         AS contained_ag_description, -- NEW in 2022
        ag.failure_condition_level,
        ag.health_check_timeout,
        ag.automated_backup_preference_desc         AS backup_preference,
        ag.required_synchronized_secondaries_to_commit AS required_sync_secondaries,
        ag.cluster_type_desc                        AS cluster_type,
        ag.is_distributed                           AS is_distributed_ag,
        ag.sequence_number,
        agc.replica_id                              AS config_replica_id
    FROM sys.availability_groups AS ag
    LEFT JOIN sys.availability_group_listeners AS agl
        ON ag.group_id = agl.group_id
    LEFT JOIN sys.availability_group_listener_ip_addresses AS agc
        ON agl.listener_id = agc.listener_id;

    -- Cluster node information
    SELECT
        member_name                                 AS node_name,
        member_type_desc                            AS member_type,
        member_state_desc                           AS member_state,
        number_of_quorum_votes                      AS quorum_votes
    FROM sys.dm_hadr_cluster_members;

    -- Cluster properties
    SELECT
        cluster_name,
        quorum_type_desc                            AS quorum_type,
        quorum_state_desc                           AS quorum_state
    FROM sys.dm_hadr_cluster;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: Replica State & Health
──────────────────────────────────────────────────────────────────────────────*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS ag_name,
        ar.replica_server_name,
        ars.role_desc                               AS current_role,
        ar.availability_mode_desc                   AS availability_mode,
        ar.failover_mode_desc                       AS failover_mode,
        ars.operational_state_desc                  AS operational_state,
        ars.connected_state_desc                    AS connected_state,
        ars.recovery_health_desc                    AS recovery_health,
        ars.synchronization_health_desc             AS sync_health,
        ars.last_connect_error_number,
        ars.last_connect_error_description,
        ars.last_connect_error_timestamp,
        ar.endpoint_url,
        ar.session_timeout,
        ar.primary_role_allow_connections_desc      AS primary_connections,
        ar.secondary_role_allow_connections_desc    AS secondary_connections,
        ar.seeding_mode_desc                        AS seeding_mode,
        ar.backup_priority
    FROM sys.availability_replicas AS ar
    INNER JOIN sys.availability_groups AS ag
        ON ar.group_id = ag.group_id
    LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
        ON ar.replica_id = ars.replica_id
    ORDER BY ag.name, ar.replica_server_name;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: Database Replica State (Sync, Redo, Send Lag)
──────────────────────────────────────────────────────────────────────────────*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS ag_name,
        ar.replica_server_name,
        DB_NAME(drs.database_id)                    AS database_name,
        drs.is_local,
        drs.is_primary_replica,
        drs.synchronization_state_desc              AS sync_state,
        drs.synchronization_health_desc             AS sync_health,
        drs.database_state_desc                     AS db_state,
        drs.is_suspended,
        drs.suspend_reason_desc,
        -- Lag metrics
        drs.log_send_queue_size                     AS log_send_queue_kb,
        drs.log_send_rate                           AS log_send_rate_kb_sec,
        drs.redo_queue_size                         AS redo_queue_kb,
        drs.redo_rate                               AS redo_rate_kb_sec,
        -- Estimated lag
        CASE
            WHEN drs.redo_rate > 0
            THEN CAST(drs.redo_queue_size * 1.0 / drs.redo_rate AS DECIMAL(18,2))
            ELSE NULL
        END                                         AS estimated_redo_lag_sec,
        CASE
            WHEN drs.log_send_rate > 0
            THEN CAST(drs.log_send_queue_size * 1.0 / drs.log_send_rate AS DECIMAL(18,2))
            ELSE NULL
        END                                         AS estimated_send_lag_sec,
        drs.last_commit_time,
        drs.last_hardened_time,
        drs.last_redone_time,
        drs.last_sent_time,
        drs.last_received_time,
        drs.end_of_log_lsn,
        drs.last_hardened_lsn,
        drs.last_redone_lsn,
        drs.last_commit_lsn
    FROM sys.dm_hadr_database_replica_states AS drs
    INNER JOIN sys.availability_replicas AS ar
        ON drs.replica_id = ar.replica_id
    INNER JOIN sys.availability_groups AS ag
        ON ar.group_id = ag.group_id
    ORDER BY ag.name, ar.replica_server_name, drs.database_id;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: AG Listener Details
──────────────────────────────────────────────────────────────────────────────*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS ag_name,
        agl.dns_name                                AS listener_dns_name,
        agl.port                                    AS listener_port,
        agl.is_conformant,
        aglip.ip_address,
        aglip.ip_subnet_mask,
        aglip.is_dhcp,
        aglip.state_desc                            AS ip_state
    FROM sys.availability_group_listeners AS agl
    INNER JOIN sys.availability_groups AS ag
        ON agl.group_id = ag.group_id
    LEFT JOIN sys.availability_group_listener_ip_addresses AS aglip
        ON agl.listener_id = aglip.listener_id
    ORDER BY ag.name, agl.dns_name;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: Automatic Seeding Progress
──────────────────────────────────────────────────────────────────────────────*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS ag_name,
        ar.replica_server_name,
        hps.current_state                           AS seeding_state,
        hps.completion_percentage                   AS completion_pct,
        hps.number_of_attempts,
        hps.start_time_utc                          AS seeding_start,
        hps.end_time_utc                            AS seeding_end,
        hps.failure_message,
        hps.performed_seeding,
        hps.is_compression_enabled
    FROM sys.dm_hadr_physical_seeding_stats AS hps
    INNER JOIN sys.availability_replicas AS ar
        ON hps.remote_machine_name = ar.replica_server_name
    INNER JOIN sys.availability_groups AS ag
        ON ar.group_id = ag.group_id
    ORDER BY hps.start_time_utc DESC;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 6: Query Store on Secondaries Status — NEW in 2022
  SQL Server 2022 allows Query Store to capture queries on secondaries.
──────────────────────────────────────────────────────────────────────────────*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    -- Check which databases have QS on secondaries enabled
    SELECT
        d.name                                      AS database_name,
        d.is_query_store_on                         AS query_store_enabled,
        COALESCE(
            (SELECT CAST(value AS INT)
             FROM sys.database_scoped_configurations
             WHERE name = 'QUERY_STORE_FOR_SECONDARY'),
            0
        )                                           AS qs_on_secondaries_enabled,  -- NEW in 2022
        drs.is_primary_replica,
        drs.synchronization_state_desc              AS sync_state,
        CASE
            WHEN drs.is_primary_replica = 0
             AND d.is_query_store_on = 1
            THEN 'Secondary replica with Query Store (NEW in 2022)'
            ELSE 'Standard configuration'
        END                                         AS qs_secondary_note
    FROM sys.databases AS d
    LEFT JOIN sys.dm_hadr_database_replica_states AS drs
        ON d.database_id = drs.database_id
       AND drs.is_local = 1
    WHERE d.database_id > 4
      AND d.state = 0;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 7: AG Performance Counters
──────────────────────────────────────────────────────────────────────────────*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        RTRIM(object_name)                          AS counter_object,
        RTRIM(counter_name)                         AS counter_name,
        RTRIM(instance_name)                        AS ag_or_replica,
        cntr_value                                  AS counter_value
    FROM sys.dm_os_performance_counters
    WHERE object_name LIKE '%Availability Replica%'
       OR object_name LIKE '%Database Replica%'
    ORDER BY object_name, counter_name, instance_name;
END;
