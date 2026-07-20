/******************************************************************************
 * 10-ag-health.sql
 * SQL Server 2019 (Compatibility Level 150) — Availability Group Health
 *
 * Covers:
 *   - AG cluster status & configuration
 *   - Replica synchronization state & health
 *   - Database replica states & synchronization lag
 *   - Log send / redo queue monitoring
 *   - Listener configuration
 *
 * Safe: read-only, no temp tables, no cursors.
 * Note: Requires HADR to be enabled and AG configured.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — Availability Group Cluster Overview
=============================================================================*/
SELECT
    ag.group_id,
    ag.name                                 AS ag_name,
    ag.resource_id,
    ag.resource_group_id,
    ag.failure_condition_level,
    ag.health_check_timeout,
    ag.automated_backup_preference_desc     AS backup_preference,
    ag.dtc_support_desc                     AS dtc_support,
    ag.cluster_type_desc                    AS cluster_type,
    ag.required_synchronized_secondaries_to_commit AS required_sync_secondaries,
    agcs.primary_replica,
    agcs.primary_recovery_health_desc       AS primary_health,
    agcs.secondary_recovery_health_desc     AS secondary_health,
    agcs.synchronization_health_desc        AS sync_health
FROM sys.availability_groups AS ag
LEFT JOIN sys.dm_hadr_availability_group_states AS agcs
    ON ag.group_id = agcs.group_id;

/*=============================================================================
  Section 2 — Replica Status & Configuration
=============================================================================*/
SELECT
    ag.name                                 AS ag_name,
    ar.replica_server_name,
    ars.role_desc                           AS current_role,
    ar.availability_mode_desc               AS availability_mode,
    ar.failover_mode_desc                   AS failover_mode,
    ars.connected_state_desc                AS connected_state,
    ars.operational_state_desc              AS operational_state,
    ars.recovery_health_desc                AS recovery_health,
    ars.synchronization_health_desc         AS sync_health,
    ars.last_connect_error_number,
    ars.last_connect_error_description,
    ars.last_connect_error_timestamp,
    ar.endpoint_url,
    ar.session_timeout,
    ar.primary_role_allow_connections_desc  AS primary_connections,
    ar.secondary_role_allow_connections_desc AS secondary_connections,
    ar.seeding_mode_desc                    AS seeding_mode,
    ar.read_only_routing_url,
    ar.backup_priority
FROM sys.availability_replicas AS ar
INNER JOIN sys.availability_groups AS ag
    ON ar.group_id = ag.group_id
LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
    ON ar.replica_id = ars.replica_id
ORDER BY ag.name, ar.replica_server_name;

/*=============================================================================
  Section 3 — Database Replica States (synchronization detail)
=============================================================================*/
SELECT
    ag.name                                 AS ag_name,
    ar.replica_server_name,
    DB_NAME(drs.database_id)                AS database_name,
    drs.is_local,
    drs.synchronization_state_desc          AS sync_state,
    drs.synchronization_health_desc         AS sync_health,
    drs.is_commit_participant,
    drs.is_suspended,
    drs.suspend_reason_desc,
    drs.last_hardened_lsn,
    drs.last_hardened_time,
    drs.last_redone_lsn,
    drs.last_redone_time,
    drs.log_send_queue_size                 AS log_send_queue_kb,
    drs.log_send_rate                       AS log_send_rate_kb_sec,
    drs.redo_queue_size                     AS redo_queue_kb,
    drs.redo_rate                           AS redo_rate_kb_sec,
    drs.last_sent_lsn,
    drs.last_sent_time,
    drs.last_received_lsn,
    drs.last_received_time,
    drs.last_commit_lsn,
    drs.last_commit_time,
    /* Calculate estimated lag */
    CASE
        WHEN drs.redo_rate > 0
        THEN CAST(drs.redo_queue_size * 1.0
                   / drs.redo_rate AS DECIMAL(10,2))
        ELSE NULL
    END                                     AS estimated_redo_lag_sec,
    CASE
        WHEN drs.log_send_rate > 0
        THEN CAST(drs.log_send_queue_size * 1.0
                   / drs.log_send_rate AS DECIMAL(10,2))
        ELSE NULL
    END                                     AS estimated_send_lag_sec,
    CASE
        WHEN drs.log_send_queue_size > 102400
        THEN 'WARNING: Send queue > 100 MB'
        WHEN drs.redo_queue_size > 102400
        THEN 'WARNING: Redo queue > 100 MB'
        WHEN drs.is_suspended = 1
        THEN 'CRITICAL: Synchronization suspended'
        ELSE 'OK'
    END                                     AS health_assessment
FROM sys.dm_hadr_database_replica_states AS drs
INNER JOIN sys.availability_replicas AS ar
    ON drs.replica_id = ar.replica_id
INNER JOIN sys.availability_groups AS ag
    ON ar.group_id = ag.group_id
ORDER BY ag.name, ar.replica_server_name, DB_NAME(drs.database_id);

/*=============================================================================
  Section 4 — Availability Group Listeners
=============================================================================*/
SELECT
    ag.name                                 AS ag_name,
    agl.dns_name                            AS listener_name,
    agl.port                                AS listener_port,
    agl.ip_configuration_string_from_cluster AS ip_config,
    aglip.ip_address,
    aglip.ip_subnet_mask,
    aglip.is_dhcp,
    aglip.state_desc                        AS ip_state
FROM sys.availability_group_listeners AS agl
INNER JOIN sys.availability_groups AS ag
    ON agl.group_id = ag.group_id
LEFT JOIN sys.availability_group_listener_ip_addresses AS aglip
    ON agl.listener_id = aglip.listener_id;

/*=============================================================================
  Section 5 — AG Performance Counters
=============================================================================*/
SELECT
    pc.object_name,
    pc.instance_name,
    pc.counter_name,
    pc.cntr_value,
    pc.cntr_type
FROM sys.dm_os_performance_counters AS pc
WHERE pc.object_name LIKE '%Availability Replica%'
   OR pc.object_name LIKE '%Database Replica%'
ORDER BY pc.object_name, pc.instance_name, pc.counter_name;

/*=============================================================================
  Section 6 — Cluster Node & Quorum Status
=============================================================================*/
SELECT
    member_name,
    member_type_desc                        AS member_type,
    member_state_desc                       AS member_state,
    number_of_quorum_votes
FROM sys.dm_hadr_cluster_members;

SELECT
    quorum_type_desc                        AS quorum_type,
    quorum_state_desc                       AS quorum_state
FROM sys.dm_hadr_cluster;
