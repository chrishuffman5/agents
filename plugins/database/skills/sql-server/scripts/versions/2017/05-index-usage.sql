/******************************************************************************
* Script:   05-index-usage.sql
* Purpose:  Index usage analysis including usage stats, missing indexes,
*           duplicate indexes, unused indexes, and resumable index operations
*           (NEW in 2017).
* Server:   SQL Server 2017 (compatibility level 140)
* Date:     2026-04-06
*
* NEW in 2017 vs 2016:
*   - sys.index_resumable_operations: track resumable online index rebuilds
*   - Resumable online index REBUILD (not CREATE -- that's 2019)
*   - Monitor paused/running resumable operations and their progress
*
* Safety:   Read-only. No modifications to server or databases.
******************************************************************************/
SET NOCOUNT ON;

-- ============================================================================
-- Section 1: Index Usage Statistics (Seeks, Scans, Lookups, Updates)
-- ============================================================================
PRINT '=== Section 1: Index Usage Statistics ===';
PRINT '';
PRINT 'NOTE: Stats reset on instance restart. Check uptime in 01-server-health.sql.';
PRINT '';

SELECT TOP 50
    DB_NAME(ius.database_id)                        AS [Database],
    OBJECT_SCHEMA_NAME(i.object_id, ius.database_id)
        + '.' + OBJECT_NAME(i.object_id, ius.database_id)
                                                    AS [Table],
    i.name                                          AS [Index Name],
    i.type_desc                                     AS [Index Type],
    ius.user_seeks                                  AS [User Seeks],
    ius.user_scans                                  AS [User Scans],
    ius.user_lookups                                AS [User Lookups],
    ius.user_updates                                AS [User Updates],
    ius.user_seeks + ius.user_scans + ius.user_lookups
                                                    AS [Total Reads],
    CASE
        WHEN ius.user_updates > 0
         AND (ius.user_seeks + ius.user_scans + ius.user_lookups) = 0
        THEN 'UNUSED -- Index has updates but no reads'
        WHEN ius.user_updates > (ius.user_seeks + ius.user_scans + ius.user_lookups) * 10
        THEN 'WRITE-HEAVY -- Updates far exceed reads'
        ELSE 'Active'
    END                                             AS [Usage Assessment],
    ius.last_user_seek                              AS [Last Seek],
    ius.last_user_scan                              AS [Last Scan],
    ius.last_user_lookup                            AS [Last Lookup],
    ius.last_user_update                            AS [Last Update]
FROM sys.dm_db_index_usage_stats ius
JOIN sys.indexes i
    ON ius.object_id = i.object_id
   AND ius.index_id = i.index_id
WHERE ius.database_id = DB_ID()
  AND OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
ORDER BY ius.user_seeks + ius.user_scans + ius.user_lookups DESC;

-- ============================================================================
-- Section 2: Unused Indexes (Candidates for Removal)
-- ============================================================================
PRINT '';
PRINT '=== Section 2: Unused Indexes (Zero Reads Since Restart) ===';
PRINT '';

SELECT
    OBJECT_SCHEMA_NAME(i.object_id) + '.'
        + OBJECT_NAME(i.object_id)                  AS [Table],
    i.name                                          AS [Index Name],
    i.type_desc                                     AS [Index Type],
    i.is_unique                                     AS [Is Unique],
    i.is_primary_key                                AS [Is Primary Key],
    ISNULL(ius.user_seeks, 0)                       AS [User Seeks],
    ISNULL(ius.user_scans, 0)                       AS [User Scans],
    ISNULL(ius.user_lookups, 0)                     AS [User Lookups],
    ISNULL(ius.user_updates, 0)                     AS [User Updates],
    ps.row_count                                    AS [Row Count],
    CAST(ps.reserved_page_count * 8.0 / 1024
        AS DECIMAL(12,2))                           AS [Size MB],
    CASE
        WHEN i.is_primary_key = 1 OR i.is_unique_constraint = 1
        THEN 'KEEP -- Enforces constraint'
        WHEN i.is_unique = 1
        THEN 'REVIEW -- Unique index, may enforce business rule'
        ELSE 'CANDIDATE FOR REMOVAL'
    END                                             AS [Recommendation]
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats ius
    ON i.object_id = ius.object_id
   AND i.index_id = ius.index_id
   AND ius.database_id = DB_ID()
JOIN sys.dm_db_partition_stats ps
    ON i.object_id = ps.object_id
   AND i.index_id = ps.index_id
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND i.index_id > 0  -- Exclude heaps
  AND i.is_hypothetical = 0
  AND i.is_disabled = 0
  AND ISNULL(ius.user_seeks, 0) = 0
  AND ISNULL(ius.user_scans, 0) = 0
  AND ISNULL(ius.user_lookups, 0) = 0
ORDER BY ps.reserved_page_count DESC;

-- ============================================================================
-- Section 3: Missing Index Suggestions
-- ============================================================================
PRINT '';
PRINT '=== Section 3: Missing Index Suggestions (Top 25 by Impact) ===';
PRINT '';

SELECT TOP 25
    CAST(gs.avg_total_user_cost * gs.avg_user_impact
        * (gs.user_seeks + gs.user_scans) AS DECIMAL(18,2))
                                                    AS [Improvement Measure],
    gs.avg_user_impact                              AS [Avg Impact Pct],
    gs.user_seeks                                   AS [User Seeks],
    gs.user_scans                                   AS [User Scans],
    gs.avg_total_user_cost                          AS [Avg Query Cost],
    gs.last_user_seek                               AS [Last Seek],
    d.statement                                     AS [Table],
    d.equality_columns                              AS [Equality Columns],
    d.inequality_columns                            AS [Inequality Columns],
    d.included_columns                              AS [Include Columns],
    'CREATE NONCLUSTERED INDEX [IX_'
        + REPLACE(REPLACE(REPLACE(
            PARSENAME(d.statement, 1), '[', ''), ']', ''), '.', '_')
        + '_' + CAST(d.index_handle AS VARCHAR(10))
        + '] ON ' + d.statement
        + ' (' + ISNULL(d.equality_columns, '')
        + CASE
            WHEN d.equality_columns IS NOT NULL
             AND d.inequality_columns IS NOT NULL THEN ', '
            ELSE ''
          END
        + ISNULL(d.inequality_columns, '') + ')'
        + CASE
            WHEN d.included_columns IS NOT NULL
            THEN ' INCLUDE (' + d.included_columns + ')'
            ELSE ''
          END                                       AS [Create Index Statement]
FROM sys.dm_db_missing_index_details d
JOIN sys.dm_db_missing_index_groups g
    ON d.index_handle = g.index_handle
JOIN sys.dm_db_missing_index_group_stats gs
    ON g.index_group_handle = gs.group_handle
WHERE d.database_id = DB_ID()
ORDER BY gs.avg_total_user_cost * gs.avg_user_impact
    * (gs.user_seeks + gs.user_scans) DESC;

-- ============================================================================
-- Section 4: Duplicate / Overlapping Indexes
-- ============================================================================
PRINT '';
PRINT '=== Section 4: Potential Duplicate Indexes ===';
PRINT '';

;WITH IndexColumns AS (
    SELECT
        i.object_id,
        i.index_id,
        i.name AS index_name,
        i.type_desc,
        i.is_unique,
        (
            SELECT CAST(ic.column_id AS VARCHAR(10)) + ','
            FROM sys.index_columns ic
            WHERE ic.object_id = i.object_id
              AND ic.index_id = i.index_id
              AND ic.is_included_column = 0
            ORDER BY ic.key_ordinal
            FOR XML PATH('')
        ) AS key_columns,
        (
            SELECT CAST(ic.column_id AS VARCHAR(10)) + ','
            FROM sys.index_columns ic
            WHERE ic.object_id = i.object_id
              AND ic.index_id = i.index_id
              AND ic.is_included_column = 1
            ORDER BY ic.column_id
            FOR XML PATH('')
        ) AS include_columns
    FROM sys.indexes i
    WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
      AND i.index_id > 0
      AND i.is_hypothetical = 0
)
SELECT
    OBJECT_SCHEMA_NAME(a.object_id) + '.'
        + OBJECT_NAME(a.object_id)                  AS [Table],
    a.index_name                                    AS [Index A],
    a.type_desc                                     AS [Type A],
    b.index_name                                    AS [Index B],
    b.type_desc                                     AS [Type B],
    'Same key columns -- review for consolidation'  AS [Note]
FROM IndexColumns a
JOIN IndexColumns b
    ON a.object_id = b.object_id
   AND a.index_id < b.index_id
   AND a.key_columns = b.key_columns
ORDER BY OBJECT_NAME(a.object_id), a.index_name;

-- ============================================================================
-- Section 5: Index Fragmentation (Sampled -- Large Tables)
-- ============================================================================
PRINT '';
PRINT '=== Section 5: Index Fragmentation (Tables > 1000 pages) ===';
PRINT '';
PRINT 'NOTE: Uses LIMITED mode to minimize performance impact.';
PRINT '';

SELECT
    OBJECT_SCHEMA_NAME(ips.object_id) + '.'
        + OBJECT_NAME(ips.object_id)                AS [Table],
    i.name                                          AS [Index Name],
    i.type_desc                                     AS [Index Type],
    ips.partition_number                             AS [Partition],
    ips.index_depth                                 AS [Depth],
    ips.index_level                                 AS [Level],
    CAST(ips.avg_fragmentation_in_percent
        AS DECIMAL(5,2))                            AS [Fragmentation Pct],
    ips.page_count                                  AS [Page Count],
    CAST(ips.page_count * 8.0 / 1024
        AS DECIMAL(12,2))                           AS [Size MB],
    ips.fragment_count                              AS [Fragment Count],
    CASE
        WHEN ips.avg_fragmentation_in_percent < 5   THEN 'OK'
        WHEN ips.avg_fragmentation_in_percent < 30  THEN 'REORGANIZE'
        ELSE 'REBUILD (consider RESUMABLE in 2017)'
    END                                             AS [Recommendation]
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i
    ON ips.object_id = i.object_id
   AND ips.index_id = i.index_id
WHERE ips.page_count > 1000
  AND ips.index_id > 0
  AND ips.alloc_unit_type_desc = 'IN_ROW_DATA'
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- ============================================================================
-- Section 6: Index Operational Stats (Row Locks, Page Splits)
-- ============================================================================
PRINT '';
PRINT '=== Section 6: Index Operational Stats (Contention Indicators) ===';
PRINT '';

SELECT TOP 25
    OBJECT_SCHEMA_NAME(ios.object_id) + '.'
        + OBJECT_NAME(ios.object_id)                AS [Table],
    i.name                                          AS [Index Name],
    ios.leaf_insert_count                           AS [Leaf Inserts],
    ios.leaf_update_count                           AS [Leaf Updates],
    ios.leaf_delete_count                           AS [Leaf Deletes],
    ios.leaf_allocation_count                       AS [Page Splits],
    ios.row_lock_count                              AS [Row Locks],
    ios.row_lock_wait_count                         AS [Row Lock Waits],
    ios.row_lock_wait_in_ms                         AS [Row Lock Wait Ms],
    ios.page_lock_count                             AS [Page Locks],
    ios.page_lock_wait_count                        AS [Page Lock Waits],
    ios.page_lock_wait_in_ms                        AS [Page Lock Wait Ms],
    ios.page_latch_wait_count                       AS [Page Latch Waits],
    ios.page_latch_wait_in_ms                       AS [Page Latch Wait Ms]
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) ios
JOIN sys.indexes i
    ON ios.object_id = i.object_id
   AND ios.index_id = i.index_id
WHERE OBJECTPROPERTY(ios.object_id, 'IsUserTable') = 1
ORDER BY ios.row_lock_wait_count + ios.page_lock_wait_count DESC;

-- ============================================================================
-- Section 7: Resumable Index Operations (NEW in 2017)
-- sys.index_resumable_operations tracks resumable online index rebuilds.
-- In 2017, only REBUILD is resumable; CREATE INDEX is not (added in 2019).
-- ============================================================================
PRINT '';
PRINT '=== Section 7: Resumable Index Operations (NEW in 2017) ===';
PRINT '';

SELECT
    DB_NAME(iro.database_id)                        AS [Database],
    OBJECT_SCHEMA_NAME(iro.object_id, iro.database_id)
        + '.' + OBJECT_NAME(iro.object_id, iro.database_id)
                                                    AS [Table],
    iro.name                                        AS [Index Name],
    iro.sql_text                                    AS [SQL Statement],
    iro.state_desc                                  AS [State],
    CAST(iro.percent_complete AS DECIMAL(5,2))      AS [Percent Complete],
    iro.start_time                                  AS [Start Time],
    iro.last_pause_time                             AS [Last Pause Time],
    iro.total_execution_time                        AS [Total Execution Time Min],
    iro.page_count                                  AS [Pages Processed],
    CASE iro.state_desc
        WHEN 'PAUSED'
        THEN 'Use ALTER INDEX ... RESUME to continue'
        WHEN 'RUNNING'
        THEN 'Currently in progress'
        ELSE iro.state_desc
    END                                             AS [Action Required]
FROM sys.index_resumable_operations iro;

-- If no resumable operations found, note this
IF @@ROWCOUNT = 0
    PRINT 'No resumable index operations currently active or paused.';

-- ============================================================================
-- Section 8: Graph Table Indexes (NEW in 2017)
-- SQL Server 2017 introduced graph tables (NODE/EDGE). Check for their indexes.
-- ============================================================================
PRINT '';
PRINT '=== Section 8: Graph Table Indexes (NEW in 2017) ===';
PRINT '';

SELECT
    OBJECT_SCHEMA_NAME(t.object_id) + '.'
        + t.name                                    AS [Table],
    CASE
        WHEN t.is_node = 1 THEN 'NODE'
        WHEN t.is_edge = 1 THEN 'EDGE'
    END                                             AS [Graph Type],
    i.name                                          AS [Index Name],
    i.type_desc                                     AS [Index Type],
    i.is_unique                                     AS [Is Unique],
    i.is_primary_key                                AS [Is PK],
    ISNULL(ius.user_seeks, 0)                       AS [User Seeks],
    ISNULL(ius.user_scans, 0)                       AS [User Scans],
    ISNULL(ius.user_updates, 0)                     AS [User Updates]
FROM sys.tables t
JOIN sys.indexes i ON t.object_id = i.object_id
LEFT JOIN sys.dm_db_index_usage_stats ius
    ON i.object_id = ius.object_id
   AND i.index_id = ius.index_id
   AND ius.database_id = DB_ID()
WHERE (t.is_node = 1 OR t.is_edge = 1)
  AND i.index_id > 0
ORDER BY t.name, i.index_id;

-- If no graph tables found, note this
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE is_node = 1 OR is_edge = 1)
    PRINT 'No graph tables (NODE/EDGE) found in the current database.';

PRINT '';
PRINT '=== Index Usage Analysis Complete ===';
