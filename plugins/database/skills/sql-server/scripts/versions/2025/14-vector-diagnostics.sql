/*******************************************************************************
 * SQL Server 2025 (Compatibility Level 170) - Vector Diagnostics
 *
 * Purpose : Comprehensive diagnostics for the native VECTOR data type and
 *           DiskANN vector indexes -- entirely NEW in SQL Server 2025.
 * Version : 2025.1.0
 * Targets : SQL Server 2025+ (build 17.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *
 * Sections:
 *   1. Tables with VECTOR Columns
 *   2. Vector Column Details (dimensions, precision)
 *   3. DiskANN Index Catalog
 *   4. DiskANN Index Health & Staleness
 *   5. Vector Index Maintenance History
 *   6. Vector Search Query Performance (Query Store)
 *   7. Vector Memory Usage
 *   8. Vector Index Size Estimation
 ******************************************************************************/
SET NOCOUNT ON;

/*------------------------------------------------------------------------------
  Section 1: Tables with VECTOR Columns -- NEW in 2025
  Identifies all tables that use the native VECTOR data type.
------------------------------------------------------------------------------*/
SELECT
    OBJECT_SCHEMA_NAME(c.object_id)                 AS schema_name,
    OBJECT_NAME(c.object_id)                        AS table_name,
    c.column_id,
    c.name                                          AS column_name,
    t.name                                          AS data_type,
    c.max_length,
    c.is_nullable,
    p.rows                                          AS table_row_count
FROM sys.columns AS c
INNER JOIN sys.types AS t
    ON c.system_type_id = t.system_type_id
   AND c.user_type_id   = t.user_type_id
INNER JOIN sys.tables AS tbl
    ON c.object_id = tbl.object_id
LEFT JOIN sys.partitions AS p
    ON c.object_id = p.object_id
   AND p.index_id IN (0, 1)
   AND p.partition_number = 1
WHERE t.name = N'vector'
ORDER BY schema_name, table_name, c.column_id;

/*------------------------------------------------------------------------------
  Section 2: Vector Column Details -- NEW in 2025
  Detailed vector column metadata including storage analysis.
------------------------------------------------------------------------------*/
SELECT
    OBJECT_SCHEMA_NAME(c.object_id)                 AS schema_name,
    OBJECT_NAME(c.object_id)                        AS table_name,
    c.name                                          AS vector_column,
    c.max_length                                    AS max_length_bytes,
    -- Vector dimensions can be inferred from max_length:
    --   float32: max_length / 4 dimensions
    --   float16: max_length / 2 dimensions
    c.max_length / 4                                AS estimated_dimensions_f32,
    c.max_length / 2                                AS estimated_dimensions_f16,
    -- Check if column has a vector index
    CASE
        WHEN EXISTS (
            SELECT 1 FROM sys.vector_indexes AS vi
            INNER JOIN sys.index_columns AS ic
                ON vi.object_id = ic.object_id AND vi.index_id = ic.index_id
            WHERE ic.object_id = c.object_id AND ic.column_id = c.column_id
        ) THEN 'Yes'
        ELSE 'No'
    END                                             AS has_vector_index,
    -- Storage estimate
    p.rows                                          AS row_count,
    CAST(p.rows * c.max_length / 1024.0 / 1024.0 AS DECIMAL(18,2))
                                                    AS estimated_vector_data_mb
FROM sys.columns AS c
INNER JOIN sys.types AS t
    ON c.system_type_id = t.system_type_id
   AND c.user_type_id   = t.user_type_id
LEFT JOIN sys.partitions AS p
    ON c.object_id = p.object_id
   AND p.index_id IN (0, 1)
   AND p.partition_number = 1
WHERE t.name = N'vector'
ORDER BY estimated_vector_data_mb DESC;

/*------------------------------------------------------------------------------
  Section 3: DiskANN Index Catalog -- NEW in 2025
  Lists all DiskANN vector indexes from sys.vector_indexes.
------------------------------------------------------------------------------*/
SELECT
    OBJECT_SCHEMA_NAME(vi.object_id)                AS schema_name,
    OBJECT_NAME(vi.object_id)                       AS table_name,
    i.name                                          AS index_name,
    i.index_id,
    vi.vector_index_type,
    vi.distance_metric,
    i.is_disabled,
    i.type_desc                                     AS base_index_type,
    ic.column_id,
    c.name                                          AS indexed_column,
    -- Table size context
    p.rows                                          AS table_row_count
FROM sys.vector_indexes AS vi
INNER JOIN sys.indexes AS i
    ON vi.object_id = i.object_id
   AND vi.index_id  = i.index_id
LEFT JOIN sys.index_columns AS ic
    ON i.object_id = ic.object_id
   AND i.index_id  = ic.index_id
LEFT JOIN sys.columns AS c
    ON ic.object_id = c.object_id
   AND ic.column_id = c.column_id
LEFT JOIN sys.partitions AS p
    ON i.object_id = p.object_id
   AND p.index_id IN (0, 1)
   AND p.partition_number = 1
ORDER BY schema_name, table_name;

/*------------------------------------------------------------------------------
  Section 4: DiskANN Index Health & Staleness -- NEW in 2025
  Uses sys.dm_db_vector_indexes for real-time health metrics.
  approximate_staleness_percent indicates pending DML changes not yet
  incorporated into the DiskANN graph structure.
------------------------------------------------------------------------------*/
SELECT
    DB_NAME()                                       AS database_name,
    OBJECT_SCHEMA_NAME(dvi.object_id)               AS schema_name,
    OBJECT_NAME(dvi.object_id)                      AS table_name,
    i.name                                          AS index_name,
    vi.vector_index_type,
    vi.distance_metric,
    dvi.approximate_staleness_percent,
    dvi.quantized_keys_used_percent,
    -- Health classification
    CASE
        WHEN dvi.last_background_task_succeeded = 0
        THEN 'CRITICAL: Last maintenance task FAILED'
        WHEN dvi.approximate_staleness_percent > 15.0
        THEN 'WARNING: High staleness (>15%) - reduced recall likely'
        WHEN dvi.approximate_staleness_percent > 5.0
        THEN 'MONITOR: Moderate staleness (5-15%)'
        ELSE 'HEALTHY: Staleness < 5%'
    END                                             AS health_status,
    dvi.last_background_task_time,
    dvi.last_background_task_succeeded,
    dvi.last_background_task_duration_seconds,
    dvi.last_background_task_processed_inserts,
    dvi.last_background_task_processed_deletes,
    dvi.last_background_task_error_message
FROM sys.dm_db_vector_indexes AS dvi
INNER JOIN sys.indexes AS i
    ON dvi.object_id = i.object_id
   AND dvi.index_id  = i.index_id
LEFT JOIN sys.vector_indexes AS vi
    ON dvi.object_id = vi.object_id
   AND dvi.index_id  = vi.index_id
ORDER BY dvi.approximate_staleness_percent DESC;

/*------------------------------------------------------------------------------
  Section 5: Vector Index Maintenance History -- NEW in 2025
  Summary of background maintenance task performance.
------------------------------------------------------------------------------*/
SELECT
    OBJECT_NAME(dvi.object_id)                      AS table_name,
    i.name                                          AS index_name,
    dvi.last_background_task_time                   AS last_maintenance,
    dvi.last_background_task_duration_seconds        AS duration_sec,
    dvi.last_background_task_processed_inserts       AS inserts_processed,
    dvi.last_background_task_processed_deletes       AS deletes_processed,
    (dvi.last_background_task_processed_inserts
     + dvi.last_background_task_processed_deletes)   AS total_ops,
    CASE
        WHEN dvi.last_background_task_duration_seconds > 0
        THEN CAST((dvi.last_background_task_processed_inserts
            + dvi.last_background_task_processed_deletes) * 1.0
            / dvi.last_background_task_duration_seconds AS DECIMAL(18,2))
        ELSE NULL
    END                                             AS ops_per_second,
    dvi.last_background_task_succeeded               AS succeeded,
    dvi.last_background_task_error_message           AS error_message
FROM sys.dm_db_vector_indexes AS dvi
INNER JOIN sys.indexes AS i
    ON dvi.object_id = i.object_id
   AND dvi.index_id  = i.index_id
ORDER BY dvi.last_background_task_time DESC;

/*------------------------------------------------------------------------------
  Section 6: Vector Search Query Performance (Query Store) -- NEW in 2025
  Identifies queries using VECTOR_SEARCH from the Query Store.
  VECTOR_SEARCH queries contain the VECTOR_SEARCH function in their text.
------------------------------------------------------------------------------*/
SELECT TOP (25)
    qsp.plan_id,
    qsp.query_id,
    qsrs.avg_duration / 1000                        AS avg_duration_ms,
    qsrs.avg_cpu_time / 1000                        AS avg_cpu_ms,
    qsrs.avg_logical_io_reads                       AS avg_logical_reads,
    qsrs.count_executions                           AS exec_count,
    qsrs.avg_rowcount                               AS avg_rows,
    qsrs.last_execution_time,
    qsqt.query_sql_text
FROM sys.query_store_runtime_stats AS qsrs
INNER JOIN sys.query_store_plan AS qsp
    ON qsrs.plan_id = qsp.plan_id
INNER JOIN sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
INNER JOIN sys.query_store_query_text AS qsqt
    ON qsq.query_text_id = qsqt.query_text_id
WHERE qsqt.query_sql_text LIKE N'%VECTOR_SEARCH%'
   OR qsqt.query_sql_text LIKE N'%VECTOR_DISTANCE%'
ORDER BY qsrs.avg_duration DESC;

/*------------------------------------------------------------------------------
  Section 7: Vector Memory Usage -- NEW in 2025
  Memory clerks and buffer pool pages related to vector operations.
------------------------------------------------------------------------------*/
-- Memory clerks that may hold vector data
SELECT
    type                                            AS clerk_type,
    name                                            AS clerk_name,
    pages_kb / 1024                                 AS allocated_mb,
    virtual_memory_committed_kb / 1024              AS committed_mb
FROM sys.dm_os_memory_clerks
WHERE name LIKE '%vector%'
   OR name LIKE '%diskann%'
   OR type LIKE '%VECTOR%'
ORDER BY pages_kb DESC;

-- Buffer pool pages for tables with vector indexes
SELECT
    OBJECT_NAME(p.object_id)                        AS table_name,
    i.name                                          AS index_name,
    i.type_desc,
    COUNT(*)                                        AS buffer_pages,
    COUNT(*) * 8 / 1024                             AS buffer_mb,
    SUM(CAST(bd.is_modified AS INT))                AS dirty_pages
FROM sys.dm_os_buffer_descriptors AS bd
INNER JOIN sys.allocation_units AS au
    ON bd.allocation_unit_id = au.allocation_unit_id
INNER JOIN sys.partitions AS p
    ON au.container_id = p.hobt_id
INNER JOIN sys.indexes AS i
    ON p.object_id = i.object_id
   AND p.index_id  = i.index_id
WHERE bd.database_id = DB_ID()
  AND EXISTS (
      SELECT 1 FROM sys.vector_indexes AS vi
      WHERE vi.object_id = p.object_id
  )
GROUP BY p.object_id, i.name, i.type_desc
ORDER BY buffer_pages DESC;

/*------------------------------------------------------------------------------
  Section 8: Vector Index Size Estimation -- NEW in 2025
  Estimates total storage consumed by vector indexes.
------------------------------------------------------------------------------*/
SELECT
    OBJECT_SCHEMA_NAME(i.object_id)                 AS schema_name,
    OBJECT_NAME(i.object_id)                        AS table_name,
    i.name                                          AS index_name,
    vi.vector_index_type,
    vi.distance_metric,
    ps.row_count,
    ps.reserved_page_count * 8 / 1024               AS reserved_mb,
    ps.used_page_count * 8 / 1024                   AS used_mb,
    ps.in_row_data_page_count * 8 / 1024            AS in_row_data_mb,
    ps.lob_reserved_page_count * 8 / 1024           AS lob_reserved_mb
FROM sys.vector_indexes AS vi
INNER JOIN sys.indexes AS i
    ON vi.object_id = i.object_id
   AND vi.index_id  = i.index_id
LEFT JOIN sys.dm_db_partition_stats AS ps
    ON i.object_id = ps.object_id
   AND i.index_id  = ps.index_id
ORDER BY reserved_mb DESC;
