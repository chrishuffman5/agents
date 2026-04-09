/******************************************************************************
 * 05-index-usage.sql
 * SQL Server 2019 (Compatibility Level 150) — Index Usage & Health
 *
 * Enhanced for 2019:
 *   - sys.dm_db_page_info for page-level analysis of hot pages         [NEW]
 *   - Page latch contention analysis using page info                   [NEW]
 *
 * Safe: read-only, no temp tables, no cursors.
 ******************************************************************************/
SET NOCOUNT ON;

/*=============================================================================
  Section 1 — Index Usage Statistics (seeks, scans, lookups, updates)
=============================================================================*/
SELECT
    DB_NAME(ius.database_id)                AS database_name,
    OBJECT_SCHEMA_NAME(i.object_id, ius.database_id) AS schema_name,
    OBJECT_NAME(i.object_id, ius.database_id)        AS table_name,
    i.name                                  AS index_name,
    i.type_desc                             AS index_type,
    ius.user_seeks,
    ius.user_scans,
    ius.user_lookups,
    ius.user_updates,
    ius.user_seeks + ius.user_scans + ius.user_lookups AS total_reads,
    CASE
        WHEN (ius.user_seeks + ius.user_scans + ius.user_lookups) > 0
        THEN CAST(ius.user_updates * 1.0
                   / (ius.user_seeks + ius.user_scans + ius.user_lookups)
                   AS DECIMAL(10,2))
        ELSE NULL
    END                                     AS write_to_read_ratio,
    ius.last_user_seek,
    ius.last_user_scan,
    ius.last_user_lookup,
    ius.last_user_update,
    ius.system_seeks,
    ius.system_scans,
    ius.system_lookups
FROM sys.dm_db_index_usage_stats AS ius
INNER JOIN sys.indexes AS i
    ON ius.object_id = i.object_id
    AND ius.index_id = i.index_id
WHERE ius.database_id = DB_ID()
  AND OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
ORDER BY total_reads DESC;

/*=============================================================================
  Section 2 — Unused Indexes (candidates for removal)
=============================================================================*/
SELECT
    OBJECT_SCHEMA_NAME(i.object_id)         AS schema_name,
    OBJECT_NAME(i.object_id)                AS table_name,
    i.name                                  AS index_name,
    i.type_desc                             AS index_type,
    i.is_unique,
    i.is_primary_key,
    i.is_unique_constraint,
    ISNULL(ius.user_seeks, 0)               AS user_seeks,
    ISNULL(ius.user_scans, 0)               AS user_scans,
    ISNULL(ius.user_lookups, 0)             AS user_lookups,
    ISNULL(ius.user_updates, 0)             AS user_updates,
    ps.row_count                            AS approx_row_count,
    CAST(ps.reserved_page_count * 8.0 / 1024
         AS DECIMAL(12,2))                  AS index_size_mb,
    ISNULL(ius.last_user_seek, '1900-01-01')  AS last_user_seek,
    ISNULL(ius.last_user_scan, '1900-01-01')  AS last_user_scan
FROM sys.indexes AS i
INNER JOIN sys.dm_db_partition_stats AS ps
    ON i.object_id = ps.object_id
    AND i.index_id = ps.index_id
LEFT JOIN sys.dm_db_index_usage_stats AS ius
    ON i.object_id = ius.object_id
    AND i.index_id = ius.index_id
    AND ius.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND i.type_desc <> 'HEAP'
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND i.is_unique = 0
  AND ISNULL(ius.user_seeks, 0) = 0
  AND ISNULL(ius.user_scans, 0) = 0
  AND ISNULL(ius.user_lookups, 0) = 0
ORDER BY ps.reserved_page_count DESC;

/*=============================================================================
  Section 3 — Missing Index Suggestions
=============================================================================*/
SELECT TOP 30
    DB_NAME(mid.database_id)                AS database_name,
    OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id) AS schema_name,
    OBJECT_NAME(mid.object_id, mid.database_id)        AS table_name,
    CAST(migs.avg_total_user_cost
         * migs.avg_user_impact / 100.0
         * (migs.user_seeks + migs.user_scans)
         AS DECIMAL(18,2))                  AS improvement_measure,
    migs.user_seeks,
    migs.user_scans,
    migs.avg_total_user_cost,
    migs.avg_user_impact,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.last_user_seek,
    migs.last_user_scan,
    'CREATE NONCLUSTERED INDEX [IX_'
        + OBJECT_NAME(mid.object_id, mid.database_id)
        + '_' + CAST(NEWID() AS VARCHAR(8))
        + '] ON '
        + mid.statement
        + ' (' + ISNULL(mid.equality_columns, '')
        + CASE
            WHEN mid.equality_columns IS NOT NULL
                 AND mid.inequality_columns IS NOT NULL
            THEN ', '
            ELSE ''
          END
        + ISNULL(mid.inequality_columns, '')
        + ')'
        + CASE
            WHEN mid.included_columns IS NOT NULL
            THEN ' INCLUDE (' + mid.included_columns + ')'
            ELSE ''
          END                               AS create_index_ddl
FROM sys.dm_db_missing_index_groups AS mig
INNER JOIN sys.dm_db_missing_index_group_stats AS migs
    ON mig.index_group_handle = migs.group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid
    ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY improvement_measure DESC;

/*=============================================================================
  Section 4 — Index Physical Stats (fragmentation)
  Run selectively — can be expensive on large databases.
=============================================================================*/
SELECT
    DB_NAME(ips.database_id)                AS database_name,
    OBJECT_SCHEMA_NAME(ips.object_id, ips.database_id) AS schema_name,
    OBJECT_NAME(ips.object_id, ips.database_id)        AS table_name,
    i.name                                  AS index_name,
    i.type_desc                             AS index_type,
    ips.partition_number,
    ips.index_depth,
    ips.index_level,
    ips.avg_fragmentation_in_percent        AS fragmentation_pct,
    ips.fragment_count,
    ips.avg_fragment_size_in_pages          AS avg_fragment_pages,
    ips.page_count,
    ips.avg_page_space_used_in_percent      AS avg_page_density_pct,
    ips.record_count,
    CASE
        WHEN ips.avg_fragmentation_in_percent > 30
             AND ips.page_count > 1000
        THEN 'REBUILD recommended'
        WHEN ips.avg_fragmentation_in_percent BETWEEN 10 AND 30
             AND ips.page_count > 1000
        THEN 'REORGANIZE recommended'
        ELSE 'OK'
    END                                     AS action_recommended
FROM sys.dm_db_index_physical_stats(
    DB_ID(), NULL, NULL, NULL, 'LIMITED'
) AS ips
INNER JOIN sys.indexes AS i
    ON ips.object_id = i.object_id
    AND ips.index_id = i.index_id
WHERE ips.page_count > 100
  AND ips.index_id > 0
  AND ips.alloc_unit_type_desc = 'IN_ROW_DATA'
ORDER BY ips.avg_fragmentation_in_percent DESC;

/*=============================================================================
  Section 5 — Hot Page Analysis with sys.dm_db_page_info               [NEW]
  Identifies pages experiencing latch contention and provides details.
  Uses PAGELATCH waits from current requests to find hot pages.
=============================================================================*/
;WITH LatchWaiters AS (
    SELECT
        r.session_id,
        r.wait_type,
        r.wait_time                         AS wait_time_ms,
        r.wait_resource,
        /* Parse wait_resource format: database_id:file_id:page_id */
        TRY_CAST(
            PARSENAME(REPLACE(r.wait_resource, ':', '.'), 3)
            AS INT
        )                                   AS page_database_id,
        TRY_CAST(
            PARSENAME(REPLACE(r.wait_resource, ':', '.'), 2)
            AS INT
        )                                   AS page_file_id,
        TRY_CAST(
            PARSENAME(REPLACE(r.wait_resource, ':', '.'), 1)
            AS BIGINT
        )                                   AS page_id
    FROM sys.dm_exec_requests AS r
    WHERE r.wait_type LIKE 'PAGELATCH_%'
      AND r.wait_resource <> ''
)
SELECT
    lw.session_id,
    lw.wait_type,
    lw.wait_time_ms,
    lw.wait_resource,
    DB_NAME(lw.page_database_id)            AS database_name,
    -- NEW 2019: Use sys.dm_db_page_info for page-level details
    pi.object_id,
    OBJECT_NAME(pi.object_id, lw.page_database_id) AS object_name,
    pi.index_id,
    pi.partition_id,
    pi.page_type_desc                       AS page_type,            -- [NEW]
    pi.allocated_page_iam_file_id,
    pi.is_mixed_page_allocation,
    pi.page_level,
    pi.is_page_compressed,
    pi.has_ghost_records
FROM LatchWaiters AS lw
OUTER APPLY sys.dm_db_page_info(                                     -- [NEW]
    lw.page_database_id,
    lw.page_file_id,
    lw.page_id,
    'DETAILED'
) AS pi
WHERE lw.page_database_id IS NOT NULL;

/*=============================================================================
  Section 6 — Index Operational Stats (latch and lock contention)
=============================================================================*/
SELECT TOP 30
    OBJECT_SCHEMA_NAME(ios.object_id)       AS schema_name,
    OBJECT_NAME(ios.object_id)              AS table_name,
    i.name                                  AS index_name,
    i.type_desc                             AS index_type,
    ios.partition_number,
    ios.leaf_insert_count,
    ios.leaf_update_count,
    ios.leaf_delete_count,
    ios.range_scan_count,
    ios.singleton_lookup_count,
    ios.page_latch_wait_count               AS page_latch_waits,
    ios.page_latch_wait_in_ms               AS page_latch_wait_ms,
    ios.page_io_latch_wait_count            AS page_io_latch_waits,
    ios.page_io_latch_wait_in_ms            AS page_io_latch_wait_ms,
    ios.row_lock_count,
    ios.row_lock_wait_count,
    ios.row_lock_wait_in_ms                 AS row_lock_wait_ms,
    ios.page_lock_count,
    ios.page_lock_wait_count,
    ios.page_lock_wait_in_ms                AS page_lock_wait_ms
FROM sys.dm_db_index_operational_stats(
    DB_ID(), NULL, NULL, NULL
) AS ios
INNER JOIN sys.indexes AS i
    ON ios.object_id = i.object_id
    AND ios.index_id = i.index_id
WHERE OBJECTPROPERTY(ios.object_id, 'IsUserTable') = 1
  AND (ios.page_latch_wait_count > 0
       OR ios.row_lock_wait_count > 0
       OR ios.page_lock_wait_count > 0)
ORDER BY (ios.page_latch_wait_in_ms
          + ios.row_lock_wait_in_ms
          + ios.page_lock_wait_in_ms) DESC;
