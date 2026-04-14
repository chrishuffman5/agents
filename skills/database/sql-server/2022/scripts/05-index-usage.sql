/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Index Usage Analysis
 *
 * Purpose : Analyze index usage patterns, missing indexes, and XML compression.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Index Usage Statistics (Seeks, Scans, Lookups, Updates)
 *   2. Unused Indexes (Candidates for Removal)
 *   3. Missing Index Recommendations
 *   4. Index Fragmentation (Sampled)
 *   5. Index Operational Stats (Row Lock / Page Lock Contention)
 *   6. Compression Analysis Including XML Compression (NEW in 2022)
 *   7. Duplicate / Overlapping Indexes
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: Index Usage Statistics
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    DB_NAME()                                       AS database_name,
    OBJECT_SCHEMA_NAME(i.object_id)                 AS schema_name,
    OBJECT_NAME(i.object_id)                        AS table_name,
    i.name                                          AS index_name,
    i.type_desc                                     AS index_type,
    i.is_unique,
    i.is_primary_key,
    COALESCE(ius.user_seeks, 0)                     AS user_seeks,
    COALESCE(ius.user_scans, 0)                     AS user_scans,
    COALESCE(ius.user_lookups, 0)                   AS user_lookups,
    COALESCE(ius.user_updates, 0)                   AS user_updates,
    COALESCE(ius.user_seeks, 0)
        + COALESCE(ius.user_scans, 0)
        + COALESCE(ius.user_lookups, 0)             AS total_reads,
    CASE
        WHEN COALESCE(ius.user_updates, 0) > 0
        THEN CAST(
            (COALESCE(ius.user_seeks, 0) + COALESCE(ius.user_scans, 0)
             + COALESCE(ius.user_lookups, 0)) * 1.0
            / ius.user_updates AS DECIMAL(18,2))
        ELSE NULL
    END                                             AS read_to_write_ratio,
    ius.last_user_seek,
    ius.last_user_scan,
    ius.last_user_lookup,
    ius.last_user_update,
    ps.row_count                                    AS approximate_rows,
    ps.reserved_page_count * 8 / 1024               AS index_size_mb
FROM sys.indexes AS i
INNER JOIN sys.objects AS o
    ON i.object_id = o.object_id
LEFT JOIN sys.dm_db_index_usage_stats AS ius
    ON i.object_id = ius.object_id
   AND i.index_id  = ius.index_id
   AND ius.database_id = DB_ID()
LEFT JOIN sys.dm_db_partition_stats AS ps
    ON i.object_id = ps.object_id
   AND i.index_id  = ps.index_id
WHERE o.is_ms_shipped = 0
  AND i.type > 0  -- exclude heaps
ORDER BY total_reads DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: Unused Indexes (Candidates for Removal)
  Indexes with zero seeks/scans/lookups but non-zero updates since restart.
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    OBJECT_SCHEMA_NAME(i.object_id)                 AS schema_name,
    OBJECT_NAME(i.object_id)                        AS table_name,
    i.name                                          AS index_name,
    i.type_desc                                     AS index_type,
    COALESCE(ius.user_updates, 0)                   AS user_updates,
    ps.reserved_page_count * 8 / 1024               AS index_size_mb,
    ps.row_count                                    AS approximate_rows,
    'Consider dropping if not needed for constraints or after further analysis.' AS recommendation
FROM sys.indexes AS i
INNER JOIN sys.objects AS o
    ON i.object_id = o.object_id
LEFT JOIN sys.dm_db_index_usage_stats AS ius
    ON i.object_id = ius.object_id
   AND i.index_id  = ius.index_id
   AND ius.database_id = DB_ID()
LEFT JOIN sys.dm_db_partition_stats AS ps
    ON i.object_id = ps.object_id
   AND i.index_id  = ps.index_id
WHERE o.is_ms_shipped = 0
  AND i.type > 0
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND COALESCE(ius.user_seeks, 0) = 0
  AND COALESCE(ius.user_scans, 0) = 0
  AND COALESCE(ius.user_lookups, 0) = 0
  AND COALESCE(ius.user_updates, 0) > 0
ORDER BY ps.reserved_page_count DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: Missing Index Recommendations
──────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (25)
    DB_NAME(mid.database_id)                        AS database_name,
    OBJECT_NAME(mid.object_id, mid.database_id)     AS table_name,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.unique_compiles                            AS compiles,
    migs.user_seeks,
    migs.user_scans,
    migs.avg_total_user_cost                        AS avg_query_cost,
    migs.avg_user_impact                            AS avg_impact_pct,
    CAST(migs.user_seeks * migs.avg_total_user_cost
        * (migs.avg_user_impact / 100.0) AS DECIMAL(18,2))
                                                    AS improvement_score,
    migs.last_user_seek,
    migs.last_user_scan,
    'CREATE NONCLUSTERED INDEX [IX_'
        + REPLACE(REPLACE(OBJECT_NAME(mid.object_id, mid.database_id), ' ', '_'), '.', '_')
        + '_' + CAST(mid.index_handle AS VARCHAR(10)) + '] ON '
        + mid.statement + ' ('
        + COALESCE(mid.equality_columns, '')
        + CASE
            WHEN mid.equality_columns IS NOT NULL
             AND mid.inequality_columns IS NOT NULL
            THEN ', '
            ELSE ''
          END
        + COALESCE(mid.inequality_columns, '')
        + ')'
        + CASE
            WHEN mid.included_columns IS NOT NULL
            THEN ' INCLUDE (' + mid.included_columns + ')'
            ELSE ''
          END                                       AS create_index_ddl
FROM sys.dm_db_missing_index_group_stats AS migs
INNER JOIN sys.dm_db_missing_index_groups AS mig
    ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid
    ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY improvement_score DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Index Fragmentation (Sampled — top 50 by fragmentation)
  Uses LIMITED mode for minimal overhead.
──────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (50)
    OBJECT_SCHEMA_NAME(ips.object_id)               AS schema_name,
    OBJECT_NAME(ips.object_id)                      AS table_name,
    i.name                                          AS index_name,
    i.type_desc                                     AS index_type,
    ips.partition_number,
    ips.avg_fragmentation_in_percent                AS avg_frag_pct,
    ips.page_count,
    ips.page_count * 8 / 1024                       AS size_mb,
    ips.record_count                                AS approx_rows,
    CASE
        WHEN ips.avg_fragmentation_in_percent < 10  THEN 'OK'
        WHEN ips.avg_fragmentation_in_percent < 30  THEN 'REORGANIZE'
        ELSE 'REBUILD'
    END                                             AS recommendation
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
INNER JOIN sys.indexes AS i
    ON ips.object_id = i.object_id
   AND ips.index_id  = i.index_id
WHERE ips.page_count > 500  -- only indexes > ~4 MB
  AND i.type > 0
  AND ips.alloc_unit_type_desc = 'IN_ROW_DATA'
ORDER BY ips.avg_fragmentation_in_percent DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: Index Operational Stats (Contention Detection)
──────────────────────────────────────────────────────────────────────────────*/
SELECT TOP (25)
    OBJECT_SCHEMA_NAME(ios.object_id)               AS schema_name,
    OBJECT_NAME(ios.object_id)                      AS table_name,
    i.name                                          AS index_name,
    ios.partition_number,
    ios.row_lock_count,
    ios.row_lock_wait_count,
    ios.row_lock_wait_in_ms,
    CAST(ios.row_lock_wait_in_ms * 1.0
        / NULLIF(ios.row_lock_wait_count, 0) AS DECIMAL(18,2))
                                                    AS avg_row_lock_wait_ms,
    ios.page_lock_count,
    ios.page_lock_wait_count,
    ios.page_lock_wait_in_ms,
    CAST(ios.page_lock_wait_in_ms * 1.0
        / NULLIF(ios.page_lock_wait_count, 0) AS DECIMAL(18,2))
                                                    AS avg_page_lock_wait_ms,
    ios.page_latch_wait_count,
    ios.page_latch_wait_in_ms,
    ios.page_io_latch_wait_count,
    ios.page_io_latch_wait_in_ms
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) AS ios
INNER JOIN sys.indexes AS i
    ON ios.object_id = i.object_id
   AND ios.index_id  = i.index_id
WHERE ios.row_lock_wait_count + ios.page_lock_wait_count > 0
ORDER BY ios.row_lock_wait_in_ms + ios.page_lock_wait_in_ms DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 6: Compression Analysis Including XML Compression — NEW in 2022
  Shows all compression types including XML compression (new in SQL 2022).
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    OBJECT_SCHEMA_NAME(p.object_id)                 AS schema_name,
    OBJECT_NAME(p.object_id)                        AS table_name,
    i.name                                          AS index_name,
    i.type_desc                                     AS index_type,
    p.partition_number,
    p.data_compression_desc                         AS compression_type,
    CASE p.data_compression_desc
        WHEN 'NONE'             THEN 'No compression'
        WHEN 'ROW'              THEN 'Row compression'
        WHEN 'PAGE'             THEN 'Page compression'
        WHEN 'COLUMNSTORE'      THEN 'Columnstore compression'
        WHEN 'COLUMNSTORE_ARCHIVE' THEN 'Columnstore archive compression'
        WHEN 'XML'              THEN 'XML compression (NEW in 2022)'            -- NEW in 2022
        ELSE p.data_compression_desc
    END                                             AS compression_description,
    p.rows                                          AS row_count,
    ps.reserved_page_count * 8 / 1024               AS size_mb
FROM sys.partitions AS p
INNER JOIN sys.indexes AS i
    ON p.object_id = i.object_id
   AND p.index_id  = i.index_id
INNER JOIN sys.objects AS o
    ON p.object_id = o.object_id
LEFT JOIN sys.dm_db_partition_stats AS ps
    ON p.object_id = ps.object_id
   AND p.index_id  = ps.index_id
   AND p.partition_number = ps.partition_number
WHERE o.is_ms_shipped = 0
  AND p.data_compression > 0  -- only compressed partitions
ORDER BY
    CASE p.data_compression_desc WHEN 'XML' THEN 0 ELSE 1 END,  -- XML first
    ps.reserved_page_count DESC;

-- Summary of compression usage by type
SELECT
    p.data_compression_desc                         AS compression_type,
    COUNT(DISTINCT p.object_id)                     AS table_count,
    COUNT(*)                                        AS partition_count,
    SUM(p.rows)                                     AS total_rows,
    SUM(ps.reserved_page_count) * 8 / 1024          AS total_size_mb
FROM sys.partitions AS p
INNER JOIN sys.objects AS o
    ON p.object_id = o.object_id
LEFT JOIN sys.dm_db_partition_stats AS ps
    ON p.object_id = ps.object_id
   AND p.index_id  = ps.index_id
   AND p.partition_number = ps.partition_number
WHERE o.is_ms_shipped = 0
GROUP BY p.data_compression_desc
ORDER BY total_size_mb DESC;

/*──────────────────────────────────────────────────────────────────────────────
  Section 7: Duplicate / Overlapping Indexes
──────────────────────────────────────────────────────────────────────────────*/
;WITH index_columns_agg AS (
    SELECT
        ic.object_id,
        ic.index_id,
        STRING_AGG(
            CAST(ic.column_id AS VARCHAR(10))
            + CASE WHEN ic.is_descending_key = 1 THEN 'D' ELSE 'A' END,
            ','
        ) WITHIN GROUP (ORDER BY ic.key_ordinal)    AS key_columns,
        STRING_AGG(
            CASE WHEN ic.is_included_column = 1
                 THEN CAST(ic.column_id AS VARCHAR(10))
                 ELSE NULL
            END, ','
        ) WITHIN GROUP (ORDER BY ic.column_id)      AS include_columns
    FROM sys.index_columns AS ic
    GROUP BY ic.object_id, ic.index_id
)
SELECT
    OBJECT_SCHEMA_NAME(i1.object_id)                AS schema_name,
    OBJECT_NAME(i1.object_id)                       AS table_name,
    i1.name                                         AS index_1,
    i2.name                                         AS index_2,
    ica1.key_columns                                AS index_1_keys,
    ica2.key_columns                                AS index_2_keys,
    COALESCE(ica1.include_columns, '')              AS index_1_includes,
    COALESCE(ica2.include_columns, '')              AS index_2_includes,
    CASE
        WHEN ica1.key_columns = ica2.key_columns
         AND COALESCE(ica1.include_columns, '') = COALESCE(ica2.include_columns, '')
        THEN 'EXACT DUPLICATE'
        ELSE 'OVERLAPPING (same leading keys)'
    END                                             AS overlap_type
FROM sys.indexes AS i1
INNER JOIN index_columns_agg AS ica1
    ON i1.object_id = ica1.object_id
   AND i1.index_id  = ica1.index_id
INNER JOIN sys.indexes AS i2
    ON i1.object_id = i2.object_id
   AND i1.index_id  < i2.index_id  -- avoid self-join duplicates
INNER JOIN index_columns_agg AS ica2
    ON i2.object_id = ica2.object_id
   AND i2.index_id  = ica2.index_id
INNER JOIN sys.objects AS o
    ON i1.object_id = o.object_id
WHERE o.is_ms_shipped = 0
  AND i1.type > 0
  AND i2.type > 0
  AND (
    ica1.key_columns = ica2.key_columns
    OR ica1.key_columns LIKE ica2.key_columns + ',%'
    OR ica2.key_columns LIKE ica1.key_columns + ',%'
  )
ORDER BY schema_name, table_name, i1.name;
