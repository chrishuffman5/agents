/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Optimized Locking Diagnostics
 *
 * Purpose : Comprehensive diagnostics for the optimized locking feature
 *           introduced in SQL Server 2025. Covers TID locking, LAQ, ADR
 *           dependency, and lock pattern analysis.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Optimized Locking Components:
 *   - TID (Transaction ID) Locking: Replaces many row/page locks with a
 *     single X lock on the XACT (TID) resource. Locks released early.
 *   - LAQ (Lock After Qualification): Evaluates predicates on latest committed
 *     version without acquiring U locks. Requires RCSI.
 *   - SIL (Skip Index Locks): Skips row/page locks when no RLQ queries exist.
 *
 * Prerequisites: ADR must be enabled. RCSI strongly recommended.
 *   ALTER DATABASE <db> SET ACCELERATED_DATABASE_RECOVERY = ON;
 *   ALTER DATABASE <db> SET READ_COMMITTED_SNAPSHOT ON;
 *   ALTER DATABASE <db> SET OPTIMIZED_LOCKING = ON;
 *
 * Sections:
 *   1. TID Locking Status per Database
 *   2. ADR Dependency Check
 *   3. Optimized Locking Feature Check (DATABASEPROPERTYEX)
 *   4. Current Lock Distribution (XACT vs Traditional)
 *   5. Lock After Qualification (LAQ) Effectiveness
 *   6. Lock Escalation Reduction Metrics
 *   7. Session-Level Lock Analysis
 *   8. XACT Wait Type Analysis
 *   9. LAQ Feedback from Query Store
 *  10. Before/After Comparison Queries
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: TID Locking Status per Database -- NEW in 2025
  Shows which databases have optimized locking enabled and their readiness.
  Optimized locking is disabled by default in SQL Server 2025 (per-database).
------------------------------------------------------------------------------*/
SELECT
    d.database_id,
    d.name                                          AS database_name,
    d.is_accelerated_database_recovery_on           AS adr_enabled,
    d.is_read_committed_snapshot_on                 AS rcsi_enabled,
    d.is_optimized_locking_on                       AS optimized_locking,
    d.compatibility_level,
    -- Locking mode classification
    CASE
        WHEN d.is_optimized_locking_on = 1
         AND d.is_read_committed_snapshot_on = 1
        THEN 'Full: TID + LAQ + SIL'
        WHEN d.is_optimized_locking_on = 1
         AND d.is_read_committed_snapshot_on = 0
        THEN 'Partial: TID only (enable RCSI for LAQ)'
        WHEN d.is_accelerated_database_recovery_on = 1
         AND d.is_optimized_locking_on = 0
        THEN 'Eligible: ADR on, OL off'
        ELSE 'Not eligible: ADR required'
    END                                             AS locking_mode,
    -- Action recommendation
    CASE
        WHEN d.is_optimized_locking_on = 1
         AND d.is_read_committed_snapshot_on = 1
        THEN 'No action needed'
        WHEN d.is_optimized_locking_on = 1
         AND d.is_read_committed_snapshot_on = 0
        THEN 'ALTER DATABASE ' + QUOTENAME(d.name) + ' SET READ_COMMITTED_SNAPSHOT ON'
        WHEN d.is_accelerated_database_recovery_on = 1
         AND d.is_optimized_locking_on = 0
        THEN 'ALTER DATABASE ' + QUOTENAME(d.name) + ' SET OPTIMIZED_LOCKING = ON'
        WHEN d.is_accelerated_database_recovery_on = 0
        THEN 'Enable ADR first, then OL: ALTER DATABASE ' + QUOTENAME(d.name)
             + ' SET ACCELERATED_DATABASE_RECOVERY = ON'
        ELSE 'N/A'
    END                                             AS recommended_action
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.state = 0
ORDER BY d.is_optimized_locking_on DESC, d.name;

/*------------------------------------------------------------------------------
  Section 2: ADR Dependency Check -- NEW in 2025
  ADR must be enabled before optimized locking can be turned on.
  To disable ADR, you must disable optimized locking first.
------------------------------------------------------------------------------*/
SELECT
    d.name                                          AS database_name,
    d.is_accelerated_database_recovery_on           AS adr_enabled,
    d.is_optimized_locking_on                       AS ol_enabled,
    CASE
        WHEN d.is_optimized_locking_on = 1
         AND d.is_accelerated_database_recovery_on = 0
        THEN 'ERROR: OL on without ADR (should not occur)'
        WHEN d.is_accelerated_database_recovery_on = 0
        THEN 'ADR OFF: Cannot enable optimized locking'
        WHEN d.is_accelerated_database_recovery_on = 1
         AND d.is_optimized_locking_on = 0
        THEN 'ADR ON: Ready to enable optimized locking'
        ELSE 'ADR ON + OL ON: Configured correctly'
    END                                             AS dependency_status,
    -- PVS health (ADR generates PVS data; more important now with OL)
    pvss.persistent_version_store_size_kb / 1024    AS pvs_size_mb
FROM sys.databases AS d
LEFT JOIN sys.dm_tran_persistent_version_store_stats AS pvss
    ON d.database_id = pvss.database_id
WHERE d.database_id > 4
  AND d.state = 0
ORDER BY d.name;

/*------------------------------------------------------------------------------
  Section 3: Optimized Locking Feature Check -- NEW in 2025
  Uses DATABASEPROPERTYEX to verify optimized locking per database.
  Result: 1 = enabled, 0 = disabled, NULL = not available.
------------------------------------------------------------------------------*/
SELECT
    d.name                                          AS database_name,
    DATABASEPROPERTYEX(d.name, 'IsOptimizedLockingOn')
                                                    AS is_optimized_locking_on
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.state = 0
ORDER BY d.name;

/*------------------------------------------------------------------------------
  Section 4: Current Lock Distribution (XACT vs Traditional) -- NEW in 2025
  When optimized locking is active, you should see XACT resource types
  instead of many KEY/RID/PAGE locks held until end of transaction.
  A single X lock on XACT replaces potentially thousands of row locks.
------------------------------------------------------------------------------*/
-- 4a. Lock resource type summary
SELECT
    resource_type,
    request_mode,
    request_status,
    COUNT(*)                                        AS lock_count,
    CASE
        WHEN resource_type = 'XACT'
        THEN 'Optimized Locking (TID)'
        WHEN resource_type IN ('KEY', 'RID')
        THEN 'Row-level (traditional or in-flight)'
        WHEN resource_type = 'PAGE'
        THEN 'Page-level (traditional)'
        WHEN resource_type = 'OBJECT'
        THEN 'Object-level'
        WHEN resource_type = 'DATABASE'
        THEN 'Database-level'
        ELSE 'Other (' + resource_type + ')'
    END                                             AS lock_category
FROM sys.dm_tran_locks
GROUP BY resource_type, request_mode, request_status
ORDER BY lock_count DESC;

-- 4b. Per-database lock type ratio
SELECT
    DB_NAME(resource_database_id)                   AS database_name,
    SUM(CASE WHEN resource_type = 'XACT' THEN 1 ELSE 0 END)
                                                    AS xact_locks,
    SUM(CASE WHEN resource_type IN ('KEY', 'RID') THEN 1 ELSE 0 END)
                                                    AS row_locks,
    SUM(CASE WHEN resource_type = 'PAGE' THEN 1 ELSE 0 END)
                                                    AS page_locks,
    SUM(CASE WHEN resource_type = 'OBJECT' THEN 1 ELSE 0 END)
                                                    AS object_locks,
    COUNT(*)                                        AS total_locks,
    CASE
        WHEN SUM(CASE WHEN resource_type = 'XACT' THEN 1 ELSE 0 END) > 0
         AND SUM(CASE WHEN resource_type IN ('KEY', 'RID', 'PAGE') THEN 1 ELSE 0 END) = 0
        THEN 'OPTIMIZED: Only XACT locks held'
        WHEN SUM(CASE WHEN resource_type = 'XACT' THEN 1 ELSE 0 END) > 0
        THEN 'MIXED: XACT + some traditional (in-flight or hints)'
        WHEN SUM(CASE WHEN resource_type IN ('KEY', 'RID', 'PAGE') THEN 1 ELSE 0 END) > 0
        THEN 'TRADITIONAL: No XACT locks (OL may be off)'
        ELSE 'IDLE: No user locks'
    END                                             AS locking_pattern
FROM sys.dm_tran_locks
WHERE resource_database_id > 4
GROUP BY resource_database_id
ORDER BY total_locks DESC;

/*------------------------------------------------------------------------------
  Section 5: Lock After Qualification (LAQ) Effectiveness -- NEW in 2025
  LAQ avoids acquiring U locks before row qualification. It evaluates
  predicates on latest committed versions without locks.
  LAQ is in effect only when RCSI is enabled.
  Monitor with lock_after_qual_stmt_abort extended event.
------------------------------------------------------------------------------*/
-- 5a. RCSI status (required for LAQ)
SELECT
    d.name                                          AS database_name,
    d.is_optimized_locking_on,
    d.is_read_committed_snapshot_on                 AS rcsi_for_laq,
    CASE
        WHEN d.is_optimized_locking_on = 1
         AND d.is_read_committed_snapshot_on = 1
        THEN 'LAQ ACTIVE'
        WHEN d.is_optimized_locking_on = 1
         AND d.is_read_committed_snapshot_on = 0
        THEN 'LAQ INACTIVE (RCSI required)'
        ELSE 'N/A (OL not enabled)'
    END                                             AS laq_status
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.state = 0;

-- 5b. LAQ feedback from Query Store (feature_id = 4)
-- When LAQ is disabled for a plan due to excessive reprocessing overhead,
-- feedback is recorded with feature_desc = 'LAQ Feedback'.
SELECT
    pf.plan_id,
    qsp.query_id,
    pf.feature_desc,
    pf.feedback_data,
    pf.state_desc,
    qsqt.query_sql_text,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.count_executions
FROM sys.query_store_plan_feedback AS pf
INNER JOIN sys.query_store_plan AS qsp
    ON pf.plan_id = qsp.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
LEFT JOIN sys.query_store_runtime_stats AS qsrs
    ON qsp.plan_id = qsrs.plan_id
WHERE pf.feature_id = 4                             -- LAQ Feedback
ORDER BY pf.plan_id;

/*------------------------------------------------------------------------------
  Section 6: Lock Escalation Reduction Metrics -- NEW in 2025
  Optimized locking dramatically reduces lock escalation because locks are
  released early rather than held until end of transaction.
  Compare lock escalation counters.
------------------------------------------------------------------------------*/
SELECT
    OBJECT_SCHEMA_NAME(ios.object_id)               AS schema_name,
    OBJECT_NAME(ios.object_id)                      AS table_name,
    i.name                                          AS index_name,
    ios.row_lock_count,
    ios.row_lock_wait_count,
    ios.row_lock_wait_in_ms,
    ios.page_lock_count,
    ios.page_lock_wait_count,
    ios.page_lock_wait_in_ms,
    ios.index_lock_promotion_attempt_count           AS lock_escalation_attempts,
    ios.index_lock_promotion_count                   AS lock_escalations,
    CASE
        WHEN ios.index_lock_promotion_attempt_count > 0
        THEN CAST(ios.index_lock_promotion_count * 100.0
            / ios.index_lock_promotion_attempt_count AS DECIMAL(5,2))
        ELSE 0
    END                                             AS escalation_success_pct,
    -- With optimized locking, these should be low/zero
    CASE
        WHEN ios.index_lock_promotion_count = 0
        THEN 'NO ESCALATIONS (expected with OL)'
        WHEN ios.index_lock_promotion_count < 10
        THEN 'MINIMAL escalations'
        ELSE 'ESCALATIONS OCCURRING - investigate'
    END                                             AS escalation_status
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) AS ios
INNER JOIN sys.indexes AS i
    ON ios.object_id = i.object_id
   AND ios.index_id  = i.index_id
WHERE OBJECTPROPERTY(ios.object_id, 'IsUserTable') = 1
  AND (ios.row_lock_count > 0 OR ios.page_lock_count > 0)
ORDER BY ios.index_lock_promotion_count DESC;

/*------------------------------------------------------------------------------
  Section 7: Session-Level Lock Analysis -- NEW in 2025
  Shows per-session lock holdings. With optimized locking, each session should
  hold very few locks (mostly one XACT lock per active modifying transaction).
------------------------------------------------------------------------------*/
SELECT
    tl.request_session_id                           AS session_id,
    DB_NAME(tl.resource_database_id)                AS database_name,
    es.login_name,
    es.program_name,
    SUM(CASE WHEN tl.resource_type = 'XACT' THEN 1 ELSE 0 END)
                                                    AS xact_locks,
    SUM(CASE WHEN tl.resource_type IN ('KEY', 'RID') THEN 1 ELSE 0 END)
                                                    AS row_locks,
    SUM(CASE WHEN tl.resource_type = 'PAGE' THEN 1 ELSE 0 END)
                                                    AS page_locks,
    SUM(CASE WHEN tl.resource_type NOT IN ('XACT', 'KEY', 'RID', 'PAGE', 'DATABASE') THEN 1 ELSE 0 END)
                                                    AS other_locks,
    COUNT(*)                                        AS total_locks,
    CASE
        WHEN COUNT(*) <= 5
        THEN 'LOW (expected with OL)'
        WHEN COUNT(*) <= 50
        THEN 'MODERATE'
        ELSE 'HIGH - may indicate lock hints or OL not effective'
    END                                             AS lock_volume
FROM sys.dm_tran_locks AS tl
INNER JOIN sys.dm_exec_sessions AS es
    ON tl.request_session_id = es.session_id
WHERE es.is_user_process = 1
  AND tl.resource_database_id > 4
GROUP BY tl.request_session_id, tl.resource_database_id,
         es.login_name, es.program_name
ORDER BY total_locks DESC;

/*------------------------------------------------------------------------------
  Section 8: XACT Wait Type Analysis -- NEW in 2025
  New wait types specific to optimized locking (TID waits):
    LCK_M_S_XACT_READ   - S lock on XACT with intent to read
    LCK_M_S_XACT_MODIFY - S lock on XACT with intent to modify
    LCK_M_S_XACT        - S lock on XACT (intent not inferred)
  These replace traditional LCK_M_X / LCK_M_U row/page waits.
------------------------------------------------------------------------------*/
SELECT
    wait_type,
    waiting_tasks_count                             AS wait_count,
    wait_time_ms                                    AS total_wait_ms,
    CAST(wait_time_ms * 1.0
        / NULLIF(waiting_tasks_count, 0) AS DECIMAL(18,2))
                                                    AS avg_wait_ms,
    max_wait_time_ms                                AS max_wait_ms,
    signal_wait_time_ms                             AS signal_wait_ms,
    wait_time_ms - signal_wait_time_ms              AS resource_wait_ms,
    CASE
        WHEN wait_type = 'LCK_M_S_XACT_READ'
        THEN 'TID wait: another txn holds X on row being read'
        WHEN wait_type = 'LCK_M_S_XACT_MODIFY'
        THEN 'TID wait: another txn holds X on row being modified'
        WHEN wait_type = 'LCK_M_S_XACT'
        THEN 'TID wait: intent not determined'
        ELSE wait_type
    END                                             AS wait_description
FROM sys.dm_os_wait_stats
WHERE wait_type IN (
    N'LCK_M_S_XACT',
    N'LCK_M_S_XACT_READ',
    N'LCK_M_S_XACT_MODIFY'
)
ORDER BY wait_time_ms DESC;

-- Compare XACT waits to traditional lock waits
SELECT
    CASE
        WHEN wait_type LIKE N'LCK_M_S_XACT%'
        THEN 'Optimized (XACT/TID)'
        ELSE 'Traditional (row/page)'
    END                                             AS lock_wait_category,
    SUM(waiting_tasks_count)                        AS total_wait_count,
    SUM(wait_time_ms)                               AS total_wait_ms,
    CAST(SUM(wait_time_ms) * 1.0
        / NULLIF(SUM(waiting_tasks_count), 0) AS DECIMAL(18,2))
                                                    AS avg_wait_ms
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE N'LCK_M_%'
  AND waiting_tasks_count > 0
GROUP BY
    CASE
        WHEN wait_type LIKE N'LCK_M_S_XACT%'
        THEN 'Optimized (XACT/TID)'
        ELSE 'Traditional (row/page)'
    END
ORDER BY total_wait_ms DESC;

/*------------------------------------------------------------------------------
  Section 9: LAQ Feedback from Query Store -- NEW in 2025
  LAQ uses heuristics to disable itself when reprocessing overhead is high.
  Feedback is stored in sys.query_store_plan_feedback (feature_id = 4).
  Plans with LAQ disabled may still use TID locking but without the
  predicate-without-lock optimization.
------------------------------------------------------------------------------*/
SELECT
    'LAQ Feedback Summary'                          AS section,
    COUNT(*)                                        AS total_laq_feedback_plans,
    SUM(CASE WHEN pf.state_desc = 'ACTIVE' THEN 1 ELSE 0 END)
                                                    AS active_count,
    SUM(CASE WHEN pf.state_desc = 'PENDING' THEN 1 ELSE 0 END)
                                                    AS pending_count,
    SUM(CASE WHEN pf.state_desc = 'REVERTED' THEN 1 ELSE 0 END)
                                                    AS reverted_count
FROM sys.query_store_plan_feedback AS pf
WHERE pf.feature_id = 4;

/*------------------------------------------------------------------------------
  Section 10: Before/After Comparison Queries -- NEW in 2025
  These queries help compare locking behavior before and after enabling
  optimized locking. Run Section A before enabling OL, Section B after.
  The results of sys.dm_os_wait_stats and dm_db_index_operational_stats
  can be compared to measure improvement.
------------------------------------------------------------------------------*/
-- 10a. Lock wait summary (snapshot for comparison)
SELECT
    'Lock Wait Snapshot'                            AS snapshot_type,
    GETDATE()                                       AS snapshot_time,
    SUM(CASE WHEN wait_type LIKE N'LCK_M_S_XACT%' THEN waiting_tasks_count ELSE 0 END)
                                                    AS xact_wait_count,
    SUM(CASE WHEN wait_type LIKE N'LCK_M_S_XACT%' THEN wait_time_ms ELSE 0 END)
                                                    AS xact_wait_ms,
    SUM(CASE WHEN wait_type LIKE N'LCK_M_%'
              AND wait_type NOT LIKE N'LCK_M_S_XACT%'
             THEN waiting_tasks_count ELSE 0 END)
                                                    AS traditional_lock_wait_count,
    SUM(CASE WHEN wait_type LIKE N'LCK_M_%'
              AND wait_type NOT LIKE N'LCK_M_S_XACT%'
             THEN wait_time_ms ELSE 0 END)
                                                    AS traditional_lock_wait_ms
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE N'LCK_M_%';

-- 10b. Lock escalation summary (snapshot for comparison)
SELECT
    'Lock Escalation Snapshot'                      AS snapshot_type,
    GETDATE()                                       AS snapshot_time,
    SUM(ios.index_lock_promotion_attempt_count)      AS total_escalation_attempts,
    SUM(ios.index_lock_promotion_count)              AS total_escalations,
    SUM(ios.row_lock_wait_count)                    AS total_row_lock_waits,
    SUM(ios.row_lock_wait_in_ms)                    AS total_row_lock_wait_ms,
    SUM(ios.page_lock_wait_count)                   AS total_page_lock_waits,
    SUM(ios.page_lock_wait_in_ms)                   AS total_page_lock_wait_ms
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) AS ios
WHERE OBJECTPROPERTY(ios.object_id, 'IsUserTable') = 1;

-- 10c. Current lock memory usage
SELECT
    type                                            AS clerk_type,
    name                                            AS clerk_name,
    pages_kb / 1024                                 AS allocated_mb
FROM sys.dm_os_memory_clerks
WHERE type = 'MEMORYCLERK_LOCKMANAGER'
   OR name LIKE '%Lock%Manager%';
