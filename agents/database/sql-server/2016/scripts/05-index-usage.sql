/*******************************************************************************
 * Script:    05-index-usage.sql
 * Purpose:   Index analysis — unused, missing, and overlapping indexes
 * Version:   SQL Server 2016 (Compatibility Level 130)
 * Date:      2026-04-06
 *
 * Returns:   Unused indexes costing write overhead, missing indexes with
 *            estimated improvement and generated CREATE statements, and
 *            duplicate/overlapping index detection.
 *
 * Notes:     Usage stats reset on restart. Run against individual databases
 *            by changing context, or rely on the cross-database approach below.
 *            Missing index DMVs accumulate since last restart — validate
 *            recommendations against actual workload before creating.
 *
 * Safety:    Read-only. Safe for production execution.
 ******************************************************************************/

SET NOCOUNT ON;

-- ============================================================================
-- SECTION 1: Unused Indexes (Seeks=0, Scans=0, Lookups=0 but Updates > 0)
-- ============================================================================
-- These indexes are maintained on every write but never read. They are
-- candidates for removal, which will improve write performance.
-- Excludes primary keys, unique constraints, and system databases.

SELECT
    DB_NAME(ius.database_id)                    AS [Database],
    OBJECT_SCHEMA_NAME(i.object_id, ius.database_id)
                                                AS [Schema],
    OBJECT_NAME(i.object_id, ius.database_id)   AS [Table],
    i.name                                      AS [Index Name],
    i.type_desc                                 AS [Index Type],
    ius.user_seeks                               AS [User Seeks],
    ius.user_scans                               AS [User Scans],
    ius.user_lookups                             AS [User Lookups],
    ius.user_updates                             AS [User Updates],
    ius.last_user_update                         AS [Last Updated],
    ps.row_count                                AS [Row Count],
    CAST(ps.reserved_page_count * 8.0 / 1024
         AS DECIMAL(18,2))                      AS [Index Size MB],
    i.is_primary_key                            AS [Is PK],
    i.is_unique_constraint                      AS [Is Unique],
    i.is_unique                                 AS [Is Unique Index],
    'DROP INDEX [' + i.name + '] ON ['
        + OBJECT_SCHEMA_NAME(i.object_id, ius.database_id) + '].['
        + OBJECT_NAME(i.object_id, ius.database_id) + '];'
                                                AS [Drop Statement]
FROM sys.dm_db_index_usage_stats AS ius
INNER JOIN sys.indexes AS i
    ON i.object_id = ius.object_id
   AND i.index_id  = ius.index_id
LEFT JOIN sys.dm_db_partition_stats AS ps
    ON ps.object_id  = i.object_id
   AND ps.index_id   = i.index_id
WHERE ius.database_id = DB_ID()                  -- current database
  AND OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND i.type_desc IN ('NONCLUSTERED')            -- only nonclustered
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND i.is_unique = 0
  AND ius.user_seeks   = 0
  AND ius.user_scans   = 0
  AND ius.user_lookups = 0
  AND ius.user_updates > 0
ORDER BY ius.user_updates DESC;


-- ============================================================================
-- SECTION 2: Missing Indexes — Top 50 by Estimated Improvement
-- ============================================================================
-- The optimizer records column groups it wished existed during compilation.
-- avg_user_impact is the estimated percentage cost reduction.

SELECT TOP 50
    ROW_NUMBER() OVER (ORDER BY
        gs.avg_total_user_cost * gs.avg_user_impact * (gs.user_seeks + gs.user_scans)
        DESC)                                   AS [Rank],

    DB_NAME(mid.database_id)                    AS [Database],
    mid.statement                               AS [Table],
    gs.user_seeks                               AS [User Seeks],
    gs.user_scans                               AS [User Scans],
    gs.last_user_seek                           AS [Last Seek],
    gs.last_user_scan                           AS [Last Scan],

    CAST(gs.avg_total_user_cost AS DECIMAL(18,2))
                                                AS [Avg Query Cost],
    CAST(gs.avg_user_impact AS DECIMAL(6,2))    AS [Avg Impact Pct],

    -- Composite improvement score: higher = more beneficial
    CAST(gs.avg_total_user_cost * gs.avg_user_impact
         * (gs.user_seeks + gs.user_scans) AS DECIMAL(18,2))
                                                AS [Improvement Score],

    COALESCE(mid.equality_columns, '')          AS [Equality Columns],
    COALESCE(mid.inequality_columns, '')        AS [Inequality Columns],
    COALESCE(mid.included_columns, '')          AS [Include Columns],

    -- Generate CREATE INDEX statement
    'CREATE NONCLUSTERED INDEX [IX_'
        + REPLACE(REPLACE(REPLACE(
            COALESCE(mid.equality_columns, mid.inequality_columns),
            ', ', '_'), '[', ''), ']', '')
        + '] ON ' + mid.statement
        + ' (' + COALESCE(mid.equality_columns, '')
        + CASE
            WHEN mid.equality_columns IS NOT NULL
             AND mid.inequality_columns IS NOT NULL
                THEN ', ' + mid.inequality_columns
            WHEN mid.inequality_columns IS NOT NULL
                THEN mid.inequality_columns
            ELSE ''
          END
        + ')'
        + CASE
            WHEN mid.included_columns IS NOT NULL
                THEN ' INCLUDE (' + mid.included_columns + ')'
            ELSE ''
          END
        + ';'                                   AS [Create Statement]

FROM sys.dm_db_missing_index_group_stats AS gs
INNER JOIN sys.dm_db_missing_index_groups AS mig
    ON mig.index_group_handle = gs.group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid
    ON mid.index_handle = mig.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY [Improvement Score] DESC;


-- ============================================================================
-- SECTION 3: Duplicate / Overlapping Indexes
-- ============================================================================
-- Detects indexes on the same table where one is a left-based subset of
-- another (e.g., Index A on (ColA) is a subset of Index B on (ColA, ColB)).
-- Only exact duplicates and left-prefix overlaps are detected.

;WITH IndexColumns AS (
    SELECT
        ic.object_id,
        ic.index_id,
        i.name           AS index_name,
        i.type_desc      AS index_type,
        i.is_unique,
        i.is_primary_key,
        -- Build ordered key column list
        STUFF((
            SELECT ', ' + COL_NAME(ic2.object_id, ic2.column_id)
            FROM sys.index_columns AS ic2
            WHERE ic2.object_id = ic.object_id
              AND ic2.index_id  = ic.index_id
              AND ic2.is_included_column = 0
            ORDER BY ic2.key_ordinal
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS key_columns,
        -- Build included column list
        STUFF((
            SELECT ', ' + COL_NAME(ic2.object_id, ic2.column_id)
            FROM sys.index_columns AS ic2
            WHERE ic2.object_id = ic.object_id
              AND ic2.index_id  = ic.index_id
              AND ic2.is_included_column = 1
            ORDER BY ic2.column_id
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS include_columns
    FROM sys.index_columns AS ic
    INNER JOIN sys.indexes AS i
        ON i.object_id = ic.object_id
       AND i.index_id  = ic.index_id
    WHERE OBJECTPROPERTY(ic.object_id, 'IsUserTable') = 1
      AND i.type IN (1, 2)      -- clustered and nonclustered
    GROUP BY ic.object_id, ic.index_id, i.name, i.type_desc,
             i.is_unique, i.is_primary_key
)
SELECT
    OBJECT_SCHEMA_NAME(a.object_id) + '.'
        + OBJECT_NAME(a.object_id)              AS [Table],
    a.index_name                                AS [Index A],
    a.index_type                                AS [Type A],
    a.key_columns                               AS [Key Columns A],
    COALESCE(a.include_columns, '')             AS [Include Columns A],
    b.index_name                                AS [Index B],
    b.index_type                                AS [Type B],
    b.key_columns                               AS [Key Columns B],
    COALESCE(b.include_columns, '')             AS [Include Columns B],
    CASE
        WHEN a.key_columns = b.key_columns
         AND COALESCE(a.include_columns, '') = COALESCE(b.include_columns, '')
            THEN 'EXACT DUPLICATE'
        WHEN a.key_columns = b.key_columns
            THEN 'SAME KEYS, DIFFERENT INCLUDES'
        ELSE 'OVERLAPPING (left-prefix subset)'
    END                                         AS [Overlap Type]
FROM IndexColumns AS a
INNER JOIN IndexColumns AS b
    ON a.object_id = b.object_id
   AND a.index_id  < b.index_id                 -- avoid self-join and duplicates
WHERE
    -- Exact key match (with or without same includes)
    a.key_columns = b.key_columns
    -- OR left-prefix overlap: A's keys start B's keys (or vice versa)
    OR b.key_columns LIKE a.key_columns + ',%'
    OR a.key_columns LIKE b.key_columns + ',%'
ORDER BY [Table], a.index_name;
