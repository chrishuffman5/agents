/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Index Usage Analysis
 *
 * Purpose : Analyze index usage patterns including traditional, vector (DiskANN),
 *           and JSON indexes with SQL Server 2025 enhancements.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Vector (DiskANN) Index Usage & Health (NEW in 2025)
 *   2. JSON Index Usage (NEW in 2025)
 *   3. Traditional Index Usage Statistics
 *   4. Missing Indexes
 *   5. Unused Indexes (candidates for removal)
 *   6. Duplicate / Overlapping Indexes
 *   7. Index Operational Statistics (hot indexes)
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: Vector (DiskANN) Index Usage & Health -- NEW in 2025
  sys.vector_indexes: catalog view for vector index metadata
  sys.dm_db_vector_indexes: DMV for real-time vector index health
------------------------------------------------------------------------------*/
-- 1a. Vector index catalog listing
SELECT
    OBJECT_SCHEMA_NAME(vi.object_id)                AS schema_name,
    OBJECT_NAME(vi.object_id)                       AS table_name,
    i.name                                          AS index_name,
    vi.vector_index_type,                                                      -- NEW in 2025
    vi.distance_metric,                                                        -- NEW in 2025
    i.is_disabled
FROM sys.vector_indexes AS vi
INNER JOIN sys.indexes AS i
    ON vi.object_id = i.object_id
   AND vi.index_id  = i.index_id
ORDER BY schema_name, table_name;

-- 1b. Vector index health and maintenance status
SELECT
    DB_NAME()                                       AS database_name,
    OBJECT_SCHEMA_NAME(dvi.object_id)               AS schema_name,
    OBJECT_NAME(dvi.object_id)                      AS table_name,
    i.name                                          AS index_name,
    dvi.approximate_staleness_percent,                                         -- NEW in 2025
    CASE
        WHEN dvi.approximate_staleness_percent > 15.0
        THEN 'HIGH - investigate maintenance'
        WHEN dvi.approximate_staleness_percent > 5.0
        THEN 'MODERATE - monitor'
        ELSE 'OK'
    END                                             AS staleness_status,
    dvi.quantized_keys_used_percent,                                           -- NEW in 2025
    dvi.last_background_task_time,
    dvi.last_background_task_succeeded,
    dvi.last_background_task_duration_seconds        AS last_task_duration_sec,
    dvi.last_background_task_processed_inserts       AS last_inserts_processed,
    dvi.last_background_task_processed_deletes       AS last_deletes_processed,
    dvi.last_background_task_error_message           AS last_error
FROM sys.dm_db_vector_indexes AS dvi
INNER JOIN sys.indexes AS i
    ON dvi.object_id = i.object_id
   AND dvi.index_id  = i.index_id
ORDER BY dvi.approximate_staleness_percent DESC;

/*------------------------------------------------------------------------------
  Section 2: JSON Index Usage -- NEW in 2025
  Identifies indexes on tables that contain native JSON columns.
  JSON columns benefit from computed columns + indexes or direct JSON indexing.
------------------------------------------------------------------------------*/
-- 2a. Tables with native JSON columns and their indexes
SELECT
    OBJECT_SCHEMA_NAME(c.object_id)                 AS schema_name,
    OBJECT_NAME(c.object_id)                        AS table_name,
    c.name                                          AS json_column_name,
    i.name                                          AS index_name,
    i.type_desc                                     AS index_type,
    ic.key_ordinal,
    ic.is_included_column,
    ius.user_seeks,
    ius.user_scans,
    ius.user_lookups,
    ius.user_updates,
    ius.last_user_seek,
    ius.last_user_scan
FROM sys.columns AS c
INNER JOIN sys.types AS t
    ON c.system_type_id = t.system_type_id
   AND c.user_type_id   = t.user_type_id
LEFT JOIN sys.index_columns AS ic
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
LEFT JOIN sys.indexes AS i
    ON ic.object_id = i.object_id
   AND ic.index_id  = i.index_id
LEFT JOIN sys.dm_db_index_usage_stats AS ius
    ON i.object_id   = ius.object_id
   AND i.index_id    = ius.index_id
   AND ius.database_id = DB_ID()
WHERE t.name = N'json'                                                         -- NEW in 2025
ORDER BY schema_name, table_name, c.column_id;

/*------------------------------------------------------------------------------
  Section 3: Traditional Index Usage Statistics
  Top indexes by user activity (seeks + scans + lookups).
------------------------------------------------------------------------------*/
SELECT TOP (50)
    OBJECT_SCHEMA_NAME(i.object_id)                 AS schema_name,
    OBJECT_NAME(i.object_id)                        AS table_name,
    i.name                                          AS index_name,
    i.type_desc                                     AS index_type,
    COALESCE(ius.user_seeks, 0)                     AS user_seeks,
    COALESCE(ius.user_scans, 0)                     AS user_scans,
    COALESCE(ius.user_lookups, 0)                   AS user_lookups,
    COALESCE(ius.user_updates, 0)                   AS user_updates,
    COALESCE(ius.user_seeks + ius.user_scans + ius.user_lookups, 0)
                                                    AS total_user_reads,
    CASE
        WHEN COALESCE(ius.user_updates, 0) > 0
         AND COALESCE(ius.user_seeks + ius.user_scans + ius.user_lookups, 0) = 0
        THEN 'Write-only (unused for reads)'
        ELSE 'Active'
    END                                             AS usage_pattern,
    ius.last_user_seek,
    ius.last_user_scan,
    ius.last_user_update,
    p.rows                                          AS row_count
FROM sys.indexes AS i
INNER JOIN sys.partitions AS p
    ON i.object_id = p.object_id
   AND i.index_id  = p.index_id
LEFT JOIN sys.dm_db_index_usage_stats AS ius
    ON i.object_id   = ius.object_id
   AND i.index_id    = ius.index_id
   AND ius.database_id = DB_ID()
WHERE i.type > 0                                    -- exclude heaps
  AND OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND p.partition_number = 1
ORDER BY total_user_reads DESC;

/*------------------------------------------------------------------------------
  Section 4: Missing Indexes
  Top 25 missing indexes by improvement measure.
------------------------------------------------------------------------------*/
SELECT TOP (25)
    DB_NAME(mid.database_id)                        AS database_name,
    mid.statement                                   AS table_name,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.unique_compiles,
    migs.user_seeks,
    migs.user_scans,
    migs.avg_total_user_cost                        AS avg_query_cost,
    migs.avg_user_impact                            AS avg_improvement_pct,
    CAST(migs.user_seeks * migs.avg_total_user_cost
        * (migs.avg_user_impact / 100.0) AS DECIMAL(18,2))
                                                    AS improvement_measure,
    migs.last_user_seek,
    migs.last_user_scan
FROM sys.dm_db_missing_index_group_stats AS migs
INNER JOIN sys.dm_db_missing_index_groups AS mig
    ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid
    ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY improvement_measure DESC;

/*------------------------------------------------------------------------------
  Section 5: Unused Indexes (candidates for removal)
  Indexes with zero reads since last service restart.
------------------------------------------------------------------------------*/
SELECT
    OBJECT_SCHEMA_NAME(i.object_id)                 AS schema_name,
    OBJECT_NAME(i.object_id)                        AS table_name,
    i.name                                          AS index_name,
    i.type_desc                                     AS index_type,
    COALESCE(ius.user_updates, 0)                   AS user_updates,
    p.rows                                          AS row_count,
    CAST((ps.reserved_page_count * 8.0) / 1024 AS DECIMAL(18,2))
                                                    AS index_size_mb,
    ius.last_user_update
FROM sys.indexes AS i
INNER JOIN sys.partitions AS p
    ON i.object_id = p.object_id
   AND i.index_id  = p.index_id
LEFT JOIN sys.dm_db_index_usage_stats AS ius
    ON i.object_id   = ius.object_id
   AND i.index_id    = ius.index_id
   AND ius.database_id = DB_ID()
LEFT JOIN sys.dm_db_partition_stats AS ps
    ON i.object_id = ps.object_id
   AND i.index_id  = ps.index_id
WHERE i.type IN (2, 6)                              -- nonclustered, nonclustered columnstore
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND p.partition_number = 1
  AND COALESCE(ius.user_seeks, 0) = 0
  AND COALESCE(ius.user_scans, 0) = 0
  AND COALESCE(ius.user_lookups, 0) = 0
ORDER BY index_size_mb DESC;

/*------------------------------------------------------------------------------
  Section 6: Duplicate / Overlapping Indexes
  Identifies indexes with identical leading key columns.
------------------------------------------------------------------------------*/
;WITH index_cols AS (
    SELECT
        ic.object_id,
        ic.index_id,
        STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS key_columns
    FROM sys.index_columns AS ic
    INNER JOIN sys.columns AS c
        ON ic.object_id = c.object_id
       AND ic.column_id = c.column_id
    WHERE ic.is_included_column = 0
    GROUP BY ic.object_id, ic.index_id
)
SELECT
    OBJECT_SCHEMA_NAME(a.object_id)                 AS schema_name,
    OBJECT_NAME(a.object_id)                        AS table_name,
    ia.name                                         AS index_a,
    ib.name                                         AS index_b,
    a.key_columns
FROM index_cols AS a
INNER JOIN index_cols AS b
    ON a.object_id   = b.object_id
   AND a.index_id    < b.index_id
   AND a.key_columns = b.key_columns
INNER JOIN sys.indexes AS ia
    ON a.object_id = ia.object_id AND a.index_id = ia.index_id
INNER JOIN sys.indexes AS ib
    ON b.object_id = ib.object_id AND b.index_id = ib.index_id
WHERE OBJECTPROPERTY(a.object_id, 'IsUserTable') = 1
ORDER BY schema_name, table_name;

/*------------------------------------------------------------------------------
  Section 7: Index Operational Statistics (hot indexes)
  High lock waits, page splits, etc.
------------------------------------------------------------------------------*/
SELECT TOP (25)
    OBJECT_SCHEMA_NAME(ios.object_id)               AS schema_name,
    OBJECT_NAME(ios.object_id)                      AS table_name,
    i.name                                          AS index_name,
    i.type_desc,
    ios.leaf_insert_count,
    ios.leaf_update_count,
    ios.leaf_delete_count,
    ios.leaf_page_merge_count,
    ios.range_scan_count,
    ios.singleton_lookup_count,
    ios.page_latch_wait_count,
    ios.page_latch_wait_in_ms,
    ios.page_io_latch_wait_count,
    ios.page_io_latch_wait_in_ms,
    ios.row_lock_count,
    ios.row_lock_wait_count,
    ios.row_lock_wait_in_ms,
    ios.page_lock_count,
    ios.page_lock_wait_count,
    ios.page_lock_wait_in_ms
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) AS ios
INNER JOIN sys.indexes AS i
    ON ios.object_id = i.object_id
   AND ios.index_id  = i.index_id
WHERE OBJECTPROPERTY(ios.object_id, 'IsUserTable') = 1
ORDER BY (ios.row_lock_wait_count + ios.page_lock_wait_count) DESC;
