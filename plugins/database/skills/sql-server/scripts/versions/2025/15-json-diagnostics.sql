/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - JSON Diagnostics
 *
 * Purpose : Comprehensive diagnostics for the native JSON data type,
 *           JSON indexes, and JSON function usage -- NEW in SQL Server 2025.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Tables Using Native JSON Data Type
 *   2. JSON Column Storage Analysis
 *   3. JSON Index Usage and Effectiveness
 *   4. JSON vs NVARCHAR Storage Comparison
 *   5. JSON Function Usage in Query Store
 *   6. Computed Columns on JSON (index support pattern)
 *   7. JSON Schema Validation Patterns
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: Tables Using Native JSON Data Type -- NEW in 2025
  The native JSON type stores data in binary format for faster access.
  Supports up to 2 GB, optimized modify() method, and direct indexing.
------------------------------------------------------------------------------*/
SELECT
    OBJECT_SCHEMA_NAME(c.object_id)                 AS schema_name,
    OBJECT_NAME(c.object_id)                        AS table_name,
    c.column_id,
    c.name                                          AS column_name,
    t.name                                          AS data_type,
    c.max_length,
    c.is_nullable,
    p.rows                                          AS table_row_count,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM sys.index_columns AS ic
            WHERE ic.object_id = c.object_id
              AND ic.column_id = c.column_id
        ) THEN 'Yes'
        ELSE 'No'
    END                                             AS is_indexed
FROM sys.columns AS c
INNER JOIN sys.types AS t
    ON c.system_type_id = t.system_type_id
   AND c.user_type_id   = t.user_type_id
LEFT JOIN sys.partitions AS p
    ON c.object_id = p.object_id
   AND p.index_id IN (0, 1)
   AND p.partition_number = 1
WHERE t.name = N'json'
ORDER BY schema_name, table_name, c.column_id;

/*------------------------------------------------------------------------------
  Section 2: JSON Column Storage Analysis -- NEW in 2025
  Estimates storage consumption for native JSON columns.
------------------------------------------------------------------------------*/
SELECT
    OBJECT_SCHEMA_NAME(c.object_id)                 AS schema_name,
    OBJECT_NAME(c.object_id)                        AS table_name,
    c.name                                          AS json_column,
    p.rows                                          AS row_count,
    ps.reserved_page_count * 8 / 1024               AS table_reserved_mb,
    ps.used_page_count * 8 / 1024                   AS table_used_mb,
    ps.lob_reserved_page_count * 8 / 1024           AS lob_reserved_mb,
    ps.in_row_data_page_count * 8 / 1024            AS in_row_data_mb,
    -- JSON data larger than ~8000 bytes is stored as LOB
    CASE
        WHEN ps.lob_reserved_page_count > 0
        THEN 'Mixed (in-row + LOB)'
        ELSE 'In-row only'
    END                                             AS storage_mode
FROM sys.columns AS c
INNER JOIN sys.types AS t
    ON c.system_type_id = t.system_type_id
   AND c.user_type_id   = t.user_type_id
LEFT JOIN sys.partitions AS p
    ON c.object_id = p.object_id
   AND p.index_id IN (0, 1)
   AND p.partition_number = 1
LEFT JOIN sys.dm_db_partition_stats AS ps
    ON c.object_id = ps.object_id
   AND ps.index_id IN (0, 1)
WHERE t.name = N'json'
ORDER BY table_reserved_mb DESC;

/*------------------------------------------------------------------------------
  Section 3: JSON Index Usage and Effectiveness -- NEW in 2025
  Indexes that include JSON columns or computed columns derived from JSON.
------------------------------------------------------------------------------*/
-- 3a. Direct indexes on JSON columns
SELECT
    OBJECT_SCHEMA_NAME(i.object_id)                 AS schema_name,
    OBJECT_NAME(i.object_id)                        AS table_name,
    i.name                                          AS index_name,
    i.type_desc                                     AS index_type,
    c.name                                          AS column_name,
    tp.name                                         AS column_type,
    ic.key_ordinal,
    ic.is_included_column,
    ius.user_seeks,
    ius.user_scans,
    ius.user_lookups,
    ius.user_updates,
    ius.last_user_seek,
    CASE
        WHEN COALESCE(ius.user_seeks, 0) = 0
         AND COALESCE(ius.user_scans, 0) = 0
        THEN 'UNUSED - consider removing'
        WHEN COALESCE(ius.user_seeks, 0) > COALESCE(ius.user_updates, 0) * 0.1
        THEN 'EFFECTIVE - reads justify writes'
        ELSE 'LOW USAGE - monitor'
    END                                             AS effectiveness
FROM sys.indexes AS i
INNER JOIN sys.index_columns AS ic
    ON i.object_id = ic.object_id
   AND i.index_id  = ic.index_id
INNER JOIN sys.columns AS c
    ON ic.object_id = c.object_id
   AND ic.column_id = c.column_id
INNER JOIN sys.types AS tp
    ON c.system_type_id = tp.system_type_id
   AND c.user_type_id   = tp.user_type_id
LEFT JOIN sys.dm_db_index_usage_stats AS ius
    ON i.object_id = ius.object_id
   AND i.index_id  = ius.index_id
   AND ius.database_id = DB_ID()
WHERE tp.name = N'json'
ORDER BY schema_name, table_name;

-- 3b. Computed columns derived from JSON (common indexing pattern)
SELECT
    OBJECT_SCHEMA_NAME(cc.object_id)                AS schema_name,
    OBJECT_NAME(cc.object_id)                       AS table_name,
    cc.name                                         AS computed_column,
    cc.definition                                   AS expression,
    cc.is_persisted,
    CASE
        WHEN cc.definition LIKE '%JSON_VALUE%'
          OR cc.definition LIKE '%JSON_QUERY%'
        THEN 'JSON extraction'
        ELSE 'Other'
    END                                             AS pattern,
    -- Check if the computed column is indexed
    CASE
        WHEN EXISTS (
            SELECT 1 FROM sys.index_columns AS ic
            WHERE ic.object_id = cc.object_id
              AND ic.column_id = cc.column_id
        ) THEN 'Indexed'
        ELSE 'Not indexed'
    END                                             AS index_status
FROM sys.computed_columns AS cc
WHERE cc.definition LIKE '%JSON_%'
   OR cc.definition LIKE '%OPENJSON%'
   OR cc.definition LIKE '%ISJSON%'
ORDER BY schema_name, table_name, cc.column_id;

/*------------------------------------------------------------------------------
  Section 4: JSON vs NVARCHAR Storage Comparison -- NEW in 2025
  Identifies tables that still store JSON in NVARCHAR columns rather than
  using the native JSON type. These are candidates for migration.
------------------------------------------------------------------------------*/
-- Tables with NVARCHAR columns that have ISJSON constraints or CHECK patterns
SELECT
    OBJECT_SCHEMA_NAME(c.object_id)                 AS schema_name,
    OBJECT_NAME(c.object_id)                        AS table_name,
    c.name                                          AS column_name,
    tp.name                                         AS current_type,
    c.max_length,
    'Consider migrating to native JSON type'        AS recommendation,
    p.rows                                          AS row_count
FROM sys.columns AS c
INNER JOIN sys.types AS tp
    ON c.system_type_id = tp.system_type_id
   AND c.user_type_id   = tp.user_type_id
LEFT JOIN sys.partitions AS p
    ON c.object_id = p.object_id
   AND p.index_id IN (0, 1)
   AND p.partition_number = 1
WHERE tp.name IN (N'nvarchar', N'varchar')
  AND OBJECTPROPERTY(c.object_id, 'IsUserTable') = 1
  AND (
      -- Column has a CHECK constraint with ISJSON
      EXISTS (
          SELECT 1 FROM sys.check_constraints AS ck
          WHERE ck.parent_object_id = c.object_id
            AND ck.definition LIKE '%ISJSON%' + c.name + '%'
      )
      -- Or column name suggests JSON content
      OR c.name LIKE '%json%'
      OR c.name LIKE '%_doc'
      OR c.name LIKE '%_document'
      OR c.name LIKE '%payload'
  )
ORDER BY schema_name, table_name;

/*------------------------------------------------------------------------------
  Section 5: JSON Function Usage in Query Store -- NEW in 2025
  Identifies queries that use JSON functions from the Query Store.
  Helps understand JSON processing workload.
------------------------------------------------------------------------------*/
SELECT TOP (25)
    qsp.plan_id,
    qsp.query_id,
    CASE
        WHEN qsqt.query_sql_text LIKE '%JSON_VALUE%'   THEN 'JSON_VALUE'
        WHEN qsqt.query_sql_text LIKE '%JSON_QUERY%'   THEN 'JSON_QUERY'
        WHEN qsqt.query_sql_text LIKE '%JSON_MODIFY%'  THEN 'JSON_MODIFY'
        WHEN qsqt.query_sql_text LIKE '%OPENJSON%'     THEN 'OPENJSON'
        WHEN qsqt.query_sql_text LIKE '%FOR JSON%'     THEN 'FOR JSON'
        WHEN qsqt.query_sql_text LIKE '%ISJSON%'       THEN 'ISJSON'
        WHEN qsqt.query_sql_text LIKE '%.modify(%'     THEN 'json.modify() method'
        ELSE 'Multiple/Other'
    END                                             AS json_function_used,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.avg_cpu_time / 1000                        AS avg_cpu_ms,
    qsrs.avg_logical_io_reads                       AS avg_logical_reads,
    qsrs.count_executions                           AS exec_count,
    qsrs.last_execution_time,
    qsqt.query_sql_text
FROM sys.query_store_runtime_stats AS qsrs
INNER JOIN sys.query_store_plan AS qsp
    ON qsrs.plan_id = qsp.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
WHERE qsqt.query_sql_text LIKE '%JSON_VALUE%'
   OR qsqt.query_sql_text LIKE '%JSON_QUERY%'
   OR qsqt.query_sql_text LIKE '%JSON_MODIFY%'
   OR qsqt.query_sql_text LIKE '%OPENJSON%'
   OR qsqt.query_sql_text LIKE '%FOR JSON%'
   OR qsqt.query_sql_text LIKE '%ISJSON%'
   OR qsqt.query_sql_text LIKE '%.modify(%'
ORDER BY qsrs.avg_duration DESC;

/*------------------------------------------------------------------------------
  Section 6: Computed Columns on JSON (index support pattern)
  Best practice: create persisted computed columns from JSON_VALUE, then index.
------------------------------------------------------------------------------*/
SELECT
    OBJECT_SCHEMA_NAME(cc.object_id)                AS schema_name,
    OBJECT_NAME(cc.object_id)                       AS table_name,
    cc.name                                         AS computed_column,
    cc.definition,
    cc.is_persisted,
    CASE
        WHEN cc.is_persisted = 0
        THEN 'WARNING: Not persisted - cannot be indexed efficiently'
        ELSE 'OK: Persisted'
    END                                             AS persistence_status,
    -- Index info
    COALESCE(i.name, 'NOT INDEXED')                 AS index_name,
    i.type_desc                                     AS index_type
FROM sys.computed_columns AS cc
LEFT JOIN sys.index_columns AS ic
    ON cc.object_id = ic.object_id
   AND cc.column_id = ic.column_id
LEFT JOIN sys.indexes AS i
    ON ic.object_id = i.object_id
   AND ic.index_id  = i.index_id
WHERE cc.definition LIKE '%JSON_VALUE%'
   OR cc.definition LIKE '%JSON_QUERY%'
ORDER BY schema_name, table_name;

/*------------------------------------------------------------------------------
  Section 7: JSON Schema Validation Patterns -- NEW in 2025
  Identifies CHECK constraints using ISJSON for schema validation.
  With the native JSON type, ISJSON validation is implicit.
------------------------------------------------------------------------------*/
SELECT
    OBJECT_SCHEMA_NAME(ck.parent_object_id)         AS schema_name,
    OBJECT_NAME(ck.parent_object_id)                AS table_name,
    ck.name                                         AS constraint_name,
    ck.definition                                   AS constraint_definition,
    ck.is_disabled,
    ck.is_not_trusted,
    CASE
        WHEN ck.definition LIKE '%ISJSON%'
        THEN 'JSON validation constraint'
        ELSE 'Other'
    END                                             AS constraint_type,
    -- Check if the table has native JSON columns (constraint may be redundant)
    CASE
        WHEN EXISTS (
            SELECT 1 FROM sys.columns AS c
            INNER JOIN sys.types AS t
                ON c.system_type_id = t.system_type_id
               AND c.user_type_id   = t.user_type_id
            WHERE c.object_id = ck.parent_object_id
              AND t.name = N'json'
        )
        THEN 'REDUNDANT: Table has native JSON columns (implicit validation)'
        ELSE 'ACTIVE: Validates NVARCHAR JSON content'
    END                                             AS relevance
FROM sys.check_constraints AS ck
WHERE ck.definition LIKE '%ISJSON%'
ORDER BY schema_name, table_name;
