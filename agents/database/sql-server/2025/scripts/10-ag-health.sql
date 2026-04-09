/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Availability Group Health
 *
 * Purpose : Comprehensive Always On AG health and performance analysis.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Availability Group Overview
 *   2. Replica Status
 *   3. Database Replica States
 *   4. AG Listener Configuration
 *   5. Synchronization Performance
 *   6. Failover Readiness
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: Availability Group Overview
  Includes is_contained (from 2022), plus any 2025 additions.
------------------------------------------------------------------------------*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.group_id,
        ag.name                                     AS ag_name,
        ag.is_contained                             AS is_contained_ag,
        ag.failure_condition_level,
        ag.health_check_timeout,
        ag.automated_backup_preference_desc         AS backup_preference,
        ag.required_synchronized_secondaries_to_commit
                                                    AS required_sync_secondaries,
        ag.cluster_type_desc                        AS cluster_type,
        ag.sequence_number,
        ags.primary_replica,
        ags.primary_recovery_health_desc            AS primary_health,
        ags.secondary_recovery_health_desc          AS secondary_health,
        ags.synchronization_health_desc             AS sync_health
    FROM sys.availability_groups AS ag
    LEFT JOIN sys.dm_hadr_availability_group_states AS ags
        ON ag.group_id = ags.group_id;
END
ELSE
BEGIN
    SELECT 'Always On Availability Groups not enabled on this instance.' AS info_message;
END;

/*------------------------------------------------------------------------------
  Section 2: Replica Status
------------------------------------------------------------------------------*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS ag_name,
        ar.replica_server_name,
        ar.availability_mode_desc                   AS availability_mode,
        ar.failover_mode_desc                       AS failover_mode,
        ar.seeding_mode_desc                        AS seeding_mode,
        ars.role_desc                               AS current_role,
        ars.operational_state_desc                  AS operational_state,
        ars.connected_state_desc                    AS connected_state,
        ars.recovery_health_desc                    AS recovery_health,
        ars.synchronization_health_desc             AS sync_health,
        ars.last_connect_error_number,
        ars.last_connect_error_description,
        ars.last_connect_error_timestamp,
        ar.endpoint_url,
        ar.session_timeout,
        ar.primary_role_allow_connections_desc       AS primary_connections,
        ar.secondary_role_allow_connections_desc     AS secondary_connections,
        ar.backup_priority,
        ar.read_only_routing_url
    FROM sys.availability_replicas AS ar
    INNER JOIN sys.availability_groups AS ag
        ON ar.group_id = ag.group_id
    LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
        ON ar.replica_id = ars.replica_id
    ORDER BY ag.name, ar.replica_server_name;
END;

/*------------------------------------------------------------------------------
  Section 3: Database Replica States
  Shows synchronization status for each database on each replica.
------------------------------------------------------------------------------*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS ag_name,
        ar.replica_server_name,
        DB_NAME(drs.database_id)                    AS database_name,
        drs.synchronization_state_desc              AS sync_state,
        drs.synchronization_health_desc             AS sync_health,
        drs.is_suspended,
        drs.suspend_reason_desc,
        drs.log_send_queue_size                     AS log_send_queue_kb,
        drs.log_send_rate                           AS log_send_rate_kb_sec,
        drs.redo_queue_size                         AS redo_queue_kb,
        drs.redo_rate                               AS redo_rate_kb_sec,
        CASE
            WHEN drs.redo_rate > 0
            THEN CAST(drs.redo_queue_size * 1.0
                / drs.redo_rate AS DECIMAL(18,2))
            ELSE NULL
        END                                         AS estimated_redo_seconds,
        drs.last_sent_time,
        drs.last_received_time,
        drs.last_hardened_time,
        drs.last_redone_time,
        drs.last_commit_time,
        drs.is_primary_replica
    FROM sys.dm_hadr_database_replica_states AS drs
    INNER JOIN sys.availability_replicas AS ar
        ON drs.replica_id = ar.replica_id
    INNER JOIN sys.availability_groups AS ag
        ON ar.group_id = ag.group_id
    ORDER BY ag.name, ar.replica_server_name, DB_NAME(drs.database_id);
END;

/*------------------------------------------------------------------------------
  Section 4: AG Listener Configuration
------------------------------------------------------------------------------*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS ag_name,
        agl.dns_name                                AS listener_name,
        agl.port                                    AS listener_port,
        agl.is_conformant,
        agl.ip_configuration_string_from_cluster    AS cluster_ip_config,
        lip.ip_address,
        lip.ip_subnet_mask,
        lip.is_dhcp,
        lip.state_desc                              AS ip_state
    FROM sys.availability_group_listeners AS agl
    INNER JOIN sys.availability_groups AS ag
        ON agl.group_id = ag.group_id
    LEFT JOIN sys.availability_group_listener_ip_addresses AS lip
        ON agl.listener_id = lip.listener_id
    ORDER BY ag.name, agl.dns_name;
END;

/*------------------------------------------------------------------------------
  Section 5: Synchronization Performance
  Monitors transport and apply throughput.
------------------------------------------------------------------------------*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS ag_name,
        ar.replica_server_name,
        DB_NAME(drs.database_id)                    AS database_name,
        drs.log_send_queue_size                     AS send_queue_kb,
        drs.log_send_rate                           AS send_rate_kb_sec,
        drs.redo_queue_size                         AS redo_queue_kb,
        drs.redo_rate                               AS redo_rate_kb_sec,
        CASE
            WHEN drs.log_send_rate > 0
            THEN CAST(drs.log_send_queue_size * 1.0
                / drs.log_send_rate AS DECIMAL(18,2))
            ELSE NULL
        END                                         AS estimated_send_lag_sec,
        CASE
            WHEN drs.redo_rate > 0
            THEN CAST(drs.redo_queue_size * 1.0
                / drs.redo_rate AS DECIMAL(18,2))
            ELSE NULL
        END                                         AS estimated_redo_lag_sec,
        DATEDIFF(SECOND, drs.last_commit_time, GETDATE())
                                                    AS seconds_since_last_commit,
        CASE
            WHEN drs.log_send_queue_size > 100000
              OR drs.redo_queue_size > 100000
            THEN 'WARNING: Large queue'
            ELSE 'OK'
        END                                         AS queue_status
    FROM sys.dm_hadr_database_replica_states AS drs
    INNER JOIN sys.availability_replicas AS ar
        ON drs.replica_id = ar.replica_id
    INNER JOIN sys.availability_groups AS ag
        ON ar.group_id = ag.group_id
    WHERE drs.is_primary_replica = 0
    ORDER BY ag.name, drs.log_send_queue_size DESC;
END;

/*------------------------------------------------------------------------------
  Section 6: Failover Readiness
  Checks whether secondary replicas are ready for failover.
------------------------------------------------------------------------------*/
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT
        ag.name                                     AS ag_name,
        ar.replica_server_name,
        ar.failover_mode_desc,
        ars.role_desc                               AS current_role,
        ars.synchronization_health_desc             AS sync_health,
        CASE
            WHEN ar.failover_mode_desc = 'AUTOMATIC'
             AND ars.synchronization_health_desc = 'HEALTHY'
            THEN 'READY for automatic failover'
            WHEN ar.failover_mode_desc = 'MANUAL'
             AND ars.synchronization_health_desc = 'HEALTHY'
            THEN 'READY for manual failover'
            ELSE 'NOT READY'
        END                                         AS failover_readiness,
        (SELECT COUNT(*)
         FROM sys.dm_hadr_database_replica_states AS drs2
         WHERE drs2.replica_id = ar.replica_id
           AND drs2.synchronization_state_desc <> 'SYNCHRONIZED')
                                                    AS unsynchronized_dbs
    FROM sys.availability_replicas AS ar
    INNER JOIN sys.availability_groups AS ag
        ON ar.group_id = ag.group_id
    LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
        ON ar.replica_id = ars.replica_id
    ORDER BY ag.name, ar.replica_server_name;
END;
