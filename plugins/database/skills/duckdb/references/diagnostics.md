# DuckDB Diagnostics Reference

## System Catalog Queries

### Database Size and Storage

```sql
-- 1. Overall database size
PRAGMA database_size;

-- 2. Detailed database size with WAL info
SELECT * FROM pragma_database_size();

-- 3. Storage info for a specific table (per-column compression details)
PRAGMA storage_info('orders');

-- 4. Storage info as a query (allows filtering)
SELECT * FROM pragma_storage_info('orders')
WHERE column_name = 'amount';

-- 5. Table info (column names, types, nullability)
PRAGMA table_info('orders');

-- 6. Detailed table info with defaults
SELECT * FROM pragma_table_info('orders');

-- 7. Show all tables in current database
SHOW TABLES;

-- 8. Show tables with details
SHOW ALL TABLES;

-- 9. Describe a table
DESCRIBE orders;
-- or
DESCRIBE SELECT * FROM orders;
```

### System Metadata Functions

```sql
-- 10. List all tables with metadata
SELECT * FROM duckdb_tables();

-- 11. List tables in a specific schema
SELECT * FROM duckdb_tables() WHERE schema_name = 'main';

-- 12. List all columns across all tables
SELECT * FROM duckdb_columns();

-- 13. List columns for a specific table
SELECT * FROM duckdb_columns() WHERE table_name = 'orders';

-- 14. List all indexes
SELECT * FROM duckdb_indexes();

-- 15. List all views
SELECT * FROM duckdb_views();

-- 16. List all sequences
SELECT * FROM duckdb_sequences();

-- 17. List all schemas
SELECT * FROM duckdb_schemas();

-- 18. List all databases (including attached)
SELECT * FROM duckdb_databases();

-- 19. List all types (including custom enums)
SELECT * FROM duckdb_types();

-- 20. List all functions (built-in and UDFs)
SELECT * FROM duckdb_functions();

-- 21. Filter functions by name pattern
SELECT DISTINCT function_name, function_type, return_type
FROM duckdb_functions()
WHERE function_name LIKE '%parquet%';

-- 22. List scalar functions
SELECT DISTINCT function_name FROM duckdb_functions()
WHERE function_type = 'scalar'
ORDER BY function_name;

-- 23. List aggregate functions
SELECT DISTINCT function_name FROM duckdb_functions()
WHERE function_type = 'aggregate'
ORDER BY function_name;

-- 24. List table functions
SELECT DISTINCT function_name FROM duckdb_functions()
WHERE function_type = 'table'
ORDER BY function_name;

-- 25. List all macros
SELECT * FROM duckdb_functions() WHERE function_type = 'macro';

-- 26. List all constraints
SELECT * FROM duckdb_constraints();

-- 27. List all temporary objects
SELECT * FROM duckdb_temporary_files();

-- 28. Check DuckDB version
SELECT version();

-- 29. Check platform
PRAGMA platform;
```

### Information Schema (SQL Standard)

```sql
-- 30. List all tables via information_schema
SELECT table_catalog, table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'main';

-- 31. List all columns via information_schema
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'main'
ORDER BY table_name, ordinal_position;

-- 32. List all schemata
SELECT * FROM information_schema.schemata;
```

## Extension Management

```sql
-- 33. List all installed extensions
SELECT * FROM duckdb_extensions();

-- 34. List loaded extensions only
SELECT extension_name, loaded, installed, install_path
FROM duckdb_extensions()
WHERE loaded = true;

-- 35. Install a core extension
INSTALL httpfs;

-- 36. Load an extension
LOAD httpfs;

-- 37. Install and load in one step (auto-loading)
-- Simply use a function that requires the extension; DuckDB will auto-install/load
SELECT * FROM read_parquet('s3://bucket/data.parquet');

-- 38. Install from community repository
INSTALL h3 FROM community;
LOAD h3;

-- 39. Force reinstall an extension
FORCE INSTALL httpfs;

-- 40. Update all extensions
UPDATE EXTENSIONS;

-- 41. Update a specific extension
UPDATE EXTENSIONS (httpfs);

-- 42. Check extension version details
SELECT extension_name, extension_version, install_mode, installed_from
FROM duckdb_extensions()
WHERE installed;

-- 43. Disable auto-install
SET autoinstall_known_extensions = false;

-- 44. Disable auto-load
SET autoload_known_extensions = false;

-- 45. Allow unsigned extensions
SET allow_unsigned_extensions = true;
```

## Configuration and Settings

```sql
-- 46. Show all current settings
SELECT * FROM duckdb_settings();

-- 47. Show a specific setting
SELECT current_setting('memory_limit');
SELECT current_setting('threads');
SELECT current_setting('temp_directory');

-- 48. Show settings matching a pattern
SELECT name, value, description
FROM duckdb_settings()
WHERE name LIKE '%memory%';

-- 49. Memory configuration
SET memory_limit = '8GB';
SET temp_directory = '/tmp/duckdb_temp';

-- 50. Thread configuration
SET threads = 8;

-- 51. Enable/disable progress bar
SET enable_progress_bar = true;
SET enable_progress_bar_print = true;

-- 52. Checkpoint configuration
SET wal_autocheckpoint = '256MB';
SET checkpoint_threshold = '256MB';

-- 53. Preservation of insertion order (disable for perf)
SET preserve_insertion_order = false;

-- 54. Enable object cache (caches Parquet metadata)
SET enable_object_cache = true;

-- 55. Configure default null ordering
SET default_null_order = 'nulls_last';

-- 56. Set default collation
SET default_collation = 'nocase';

-- 57. Configure external access (file system, network)
SET enable_external_access = true;
SET enable_fsst_vectors = true;

-- 58. Reset a setting to default
RESET memory_limit;
RESET threads;

-- 59. Reset all settings
RESET ALL;
```

## Query Profiling and EXPLAIN

```sql
-- 60. Logical query plan
EXPLAIN SELECT region, sum(amount) FROM orders GROUP BY region;

-- 61. Physical query plan with actual execution stats
EXPLAIN ANALYZE SELECT region, sum(amount) FROM orders GROUP BY region;

-- 62. Enable profiling to file (JSON format)
PRAGMA enable_profiling = 'json';
PRAGMA profiling_output = '/tmp/query_profile.json';
SELECT region, sum(amount) FROM orders GROUP BY region;
PRAGMA disable_profiling;

-- 63. Enable profiling (query tree format)
PRAGMA enable_profiling = 'query_tree';
SELECT region, sum(amount) FROM orders GROUP BY region;
PRAGMA disable_profiling;

-- 64. Enable profiling (query tree with actual time)
PRAGMA enable_profiling = 'query_tree_optimizer';

-- 65. Profile a specific query with detailed timing
PRAGMA enable_profiling;
PRAGMA profiling_mode = 'detailed';
SELECT * FROM orders WHERE amount > 100 ORDER BY order_date DESC LIMIT 1000;
PRAGMA disable_profiling;

-- 66. Custom profiling output location
PRAGMA profiling_output = '/tmp/duckdb_profile.json';

-- 67. Show optimizer settings
SELECT name, value FROM duckdb_settings() WHERE name LIKE '%optimizer%';
```

## Memory Diagnostics

```sql
-- 68. Current memory usage
PRAGMA database_size;

-- 69. Memory limit check
SELECT current_setting('memory_limit') AS memory_limit;

-- 70. Temp directory check (where spill files go)
SELECT current_setting('temp_directory') AS temp_directory;

-- 71. List temporary files (active spill files)
SELECT * FROM duckdb_temporary_files();

-- 72. Check if queries are spilling to disk
-- Run your query, then check:
SELECT * FROM duckdb_temporary_files();
-- If rows appear, the query is spilling to disk

-- 73. Estimate table memory footprint
SELECT
    table_name,
    estimated_size,
    column_count,
    index_count
FROM duckdb_tables();

-- 74. Per-column storage breakdown
SELECT
    column_name,
    column_id,
    segment_type,
    compression,
    count,
    stats
FROM pragma_storage_info('orders');

-- 75. Aggregate storage by compression type
SELECT
    compression,
    count(*) AS segment_count,
    sum(count) AS total_rows
FROM pragma_storage_info('orders')
GROUP BY compression;
```

## File Scanning and Format Diagnostics

### Parquet File Inspection

```sql
-- 76. Read Parquet file metadata (schema, row groups, size)
SELECT * FROM parquet_metadata('data.parquet');

-- 77. Read Parquet file schema only
SELECT * FROM parquet_schema('data.parquet');

-- 78. Read Parquet with detailed options
SELECT * FROM read_parquet('data.parquet',
    binary_as_string = true,
    filename = true,
    file_row_number = true,
    hive_partitioning = true
);

-- 79. Count rows without full scan (uses Parquet metadata)
SELECT count(*) FROM read_parquet('data.parquet');

-- 80. Inspect Parquet row group statistics
SELECT * FROM parquet_metadata('data.parquet')
WHERE path_in_schema = 'amount';

-- 81. Read specific columns from Parquet (projection pushdown)
SELECT id, amount FROM read_parquet('data.parquet');

-- 82. Parquet with glob patterns
SELECT * FROM read_parquet('data/year=*/month=*/*.parquet', hive_partitioning = true);

-- 83. Parquet with union by name (heterogeneous schemas)
SELECT * FROM read_parquet('data/*.parquet', union_by_name = true);

-- 84. Parquet key-value metadata
SELECT * FROM parquet_kv_metadata('data.parquet');
```

### CSV File Inspection

```sql
-- 85. Auto-detect CSV format
SELECT * FROM read_csv('data.csv');

-- 86. CSV with explicit options
SELECT * FROM read_csv('data.csv',
    header = true,
    delim = '|',
    quote = '"',
    escape = '\\',
    dateformat = '%Y-%m-%d',
    timestampformat = '%Y-%m-%d %H:%M:%S',
    sample_size = 20000,
    all_varchar = false,
    auto_detect = true,
    null_padding = true,
    ignore_errors = true,
    max_line_size = 1048576
);

-- 87. CSV sniffing (inspect auto-detected parameters)
SELECT * FROM sniff_csv('data.csv');

-- 88. Read CSV with explicit column types
SELECT * FROM read_csv('data.csv',
    columns = {'id': 'INTEGER', 'name': 'VARCHAR', 'amount': 'DOUBLE'}
);

-- 89. CSV with filename column
SELECT *, filename FROM read_csv('data/*.csv', filename = true);

-- 90. CSV with custom null string
SELECT * FROM read_csv('data.csv', nullstr = 'NA');
```

### JSON File Inspection

```sql
-- 91. Read JSON with auto-detection
SELECT * FROM read_json_auto('data.json');

-- 92. Read newline-delimited JSON (NDJSON)
SELECT * FROM read_json_auto('data.ndjson', format = 'newline_delimited');

-- 93. Read JSON with explicit schema
SELECT * FROM read_json('data.json',
    columns = {'id': 'INTEGER', 'name': 'VARCHAR', 'tags': 'VARCHAR[]'},
    format = 'array'
);

-- 94. Read JSON from HTTP endpoint
SELECT * FROM read_json_auto('https://api.example.com/data.json');

-- 95. Flatten nested JSON
SELECT id, name, unnest(tags) AS tag
FROM read_json_auto('data.json');
```

### Remote File Access

```sql
-- 96. S3 configuration
SET s3_region = 'us-east-1';
SET s3_access_key_id = 'YOUR_KEY';
SET s3_secret_access_key = 'YOUR_SECRET';
-- Or use a profile
SET s3_url_style = 'path';

-- 97. S3 file listing
SELECT * FROM glob('s3://bucket/path/*');

-- 98. GCS configuration
SET s3_endpoint = 'storage.googleapis.com';
SET s3_access_key_id = 'YOUR_GCS_KEY';

-- 99. Azure configuration (requires azure extension)
SET azure_storage_connection_string = 'DefaultEndpointsProtocol=https;...';
-- Or
SET azure_account_name = 'myaccount';
SET azure_account_key = 'mykey';

-- 100. Read from Azure blob storage
SELECT * FROM read_parquet('azure://container/path/data.parquet');

-- 101. HTTPS file access
SELECT * FROM read_parquet('https://example.com/data.parquet');
```

## Performance Diagnostics

### Query Performance Analysis

```sql
-- 102. Time a query
.timer on
SELECT region, sum(amount) FROM orders GROUP BY region;
.timer off

-- 103. Explain analyze with per-operator timing
EXPLAIN ANALYZE
SELECT o.region, c.name, sum(o.amount)
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.order_date > '2025-01-01'
GROUP BY o.region, c.name
ORDER BY sum(o.amount) DESC
LIMIT 10;

-- 104. Compare sequential scan vs filtered scan
EXPLAIN ANALYZE SELECT * FROM orders WHERE region = 'US';
EXPLAIN ANALYZE SELECT * FROM orders WHERE order_id = 12345;

-- 105. Check if zonemaps are being used (look for "Filter" vs "Seq Scan" in EXPLAIN)
EXPLAIN SELECT * FROM orders WHERE order_date BETWEEN '2025-01-01' AND '2025-01-31';

-- 106. Force a checkpoint to update statistics
CHECKPOINT;

-- 107. Check table row count (fast -- uses metadata)
SELECT count(*) FROM orders;

-- 108. Check table estimated size
SELECT estimated_size FROM duckdb_tables() WHERE table_name = 'orders';
```

### Join Performance

```sql
-- 109. Examine join strategy
EXPLAIN ANALYZE
SELECT * FROM orders o
JOIN customers c ON o.customer_id = c.id;
-- Look for: HASH_JOIN, MERGE_JOIN, NESTED_LOOP_JOIN, or INDEX_JOIN

-- 110. Force a specific join order (hint)
-- DuckDB generally picks optimal join order, but you can influence with subqueries:
SELECT * FROM (SELECT * FROM small_table) s
JOIN large_table l ON s.id = l.id;

-- 111. Check if hash join is spilling
-- After running the query, check for temporary files:
SELECT * FROM duckdb_temporary_files();
```

### Aggregation Performance

```sql
-- 112. Check aggregation strategy
EXPLAIN ANALYZE
SELECT region, product, sum(amount), count(*)
FROM orders
GROUP BY region, product;
-- Look for: HASH_GROUP_BY vs PERFECT_HASH_GROUP_BY

-- 113. Ordered aggregation (for pre-sorted data)
EXPLAIN ANALYZE
SELECT date_trunc('month', order_date), sum(amount)
FROM orders
GROUP BY 1
ORDER BY 1;
```

### Scan Performance

```sql
-- 114. Compare full scan vs. partial scan (projection pushdown)
EXPLAIN ANALYZE SELECT * FROM orders;
EXPLAIN ANALYZE SELECT id, amount FROM orders;  -- should be faster (fewer columns)

-- 115. Parquet predicate pushdown verification
EXPLAIN ANALYZE
SELECT * FROM read_parquet('orders.parquet')
WHERE order_date > '2025-01-01';
-- Look for: PARQUET_SCAN with filter pushdown info

-- 116. CSV vs Parquet scan comparison
EXPLAIN ANALYZE SELECT sum(amount) FROM read_csv('orders.csv');
EXPLAIN ANALYZE SELECT sum(amount) FROM read_parquet('orders.parquet');
```

## CLI Commands

```sql
-- 117. List available dot commands
.help

-- 118. Show current database
.databases

-- 119. Show tables
.tables

-- 120. Timer toggle
.timer on

-- 121. Output format
.mode markdown
.mode csv
.mode json
.mode line
.mode column
.mode box
.mode table
.mode latex
.mode trash   -- discard output (useful for benchmarking)

-- 122. Headers on/off
.headers on

-- 123. Output to file
.output results.csv
SELECT * FROM orders;
.output   -- reset to stdout

-- 124. Read and execute SQL from file
.read my_script.sql

-- 125. Import CSV into table
.import data.csv orders

-- 126. Show column widths
.width 10 20 15

-- 127. Separator for CSV mode
.separator ","

-- 128. Echo commands
.echo on

-- 129. Null display
.nullvalue NULL

-- 130. Open a different database
.open my_database.duckdb

-- 131. System command
.system ls -la

-- 132. Shell command
.shell echo "hello"

-- 133. Quit
.quit
-- or
.exit
```

## Data Integrity Checks

```sql
-- 134. Check constraints on a table
SELECT * FROM duckdb_constraints()
WHERE table_name = 'orders';

-- 135. Verify row counts match between source and target
SELECT
    (SELECT count(*) FROM source_table) AS source_count,
    (SELECT count(*) FROM target_table) AS target_count,
    (SELECT count(*) FROM source_table) - (SELECT count(*) FROM target_table) AS diff;

-- 136. Find duplicate rows
SELECT *, count(*) AS cnt
FROM orders
GROUP BY ALL
HAVING cnt > 1;

-- 137. Find NULL values per column
SELECT
    count(*) AS total_rows,
    count(*) - count(id) AS null_id,
    count(*) - count(name) AS null_name,
    count(*) - count(amount) AS null_amount
FROM orders;

-- 138. Column-level statistics
SELECT
    min(amount), max(amount),
    avg(amount), stddev(amount),
    approx_count_distinct(region) AS distinct_regions,
    count(*) FILTER (WHERE amount IS NULL) AS null_count
FROM orders;

-- 139. Data type mismatches during CSV import
SELECT * FROM read_csv('data.csv', ignore_errors = true)
WHERE typeof(amount) != 'DOUBLE';

-- 140. Check for orphaned foreign key references
SELECT o.*
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id
WHERE c.id IS NULL;
```

## Backup and Export Diagnostics

```sql
-- 141. Export entire database to Parquet
EXPORT DATABASE 'backup' (FORMAT PARQUET, COMPRESSION ZSTD);

-- 142. Export database to CSV
EXPORT DATABASE 'backup_csv' (FORMAT CSV, HEADER true);

-- 143. Import database from backup
IMPORT DATABASE 'backup';

-- 144. Copy single table to Parquet
COPY orders TO 'orders_backup.parquet' (FORMAT PARQUET, COMPRESSION ZSTD);

-- 145. Copy with row group size control
COPY orders TO 'orders.parquet' (FORMAT PARQUET, ROW_GROUP_SIZE 100000);

-- 146. Verify export row count
SELECT count(*) FROM read_parquet('orders_backup.parquet');
SELECT count(*) FROM orders;

-- 147. Cross-database copy
ATTACH 'backup.duckdb' AS backup_db;
COPY FROM DATABASE memory TO backup_db;
```

## Troubleshooting Common Issues

### Out of Memory

```sql
-- 148. Check current memory limit
SELECT current_setting('memory_limit');

-- 149. Increase memory limit
SET memory_limit = '16GB';

-- 150. Set temp directory for spilling
SET temp_directory = '/path/with/space/duckdb_temp';

-- 151. Reduce thread count (each thread uses memory)
SET threads = 4;

-- 152. Check for spill files
SELECT * FROM duckdb_temporary_files();

-- 153. Force garbage collection
PRAGMA force_checkpoint;
```

### Slow Queries

```sql
-- 154. Profile the query
EXPLAIN ANALYZE <your_query>;

-- 155. Check if data is sorted (helps zonemaps)
SELECT min(order_date), max(order_date)
FROM pragma_storage_info('orders')
WHERE column_name = 'order_date';

-- 156. Consider creating an ART index for point lookups
CREATE INDEX idx_order_id ON orders(order_id);

-- 157. Check insertion order preservation overhead
SELECT current_setting('preserve_insertion_order');
SET preserve_insertion_order = false;  -- can improve aggregation

-- 158. Analyze query with optimizer disabled (for comparison)
PRAGMA disable_optimizer;
EXPLAIN ANALYZE <your_query>;
PRAGMA enable_optimizer;
```

### Extension Issues

```sql
-- 159. Check if extension is installed and loaded
SELECT extension_name, loaded, installed, install_path
FROM duckdb_extensions()
WHERE extension_name = 'httpfs';

-- 160. Force reinstall
FORCE INSTALL httpfs;
LOAD httpfs;

-- 161. Check extension compatibility
SELECT extension_name, extension_version
FROM duckdb_extensions()
WHERE installed;

-- 162. Update all extensions after DuckDB upgrade
UPDATE EXTENSIONS;
```

### File Access Issues

```sql
-- 163. Test S3 connectivity
INSTALL httpfs; LOAD httpfs;
SET s3_region = 'us-east-1';
SELECT * FROM glob('s3://bucket/path/*');

-- 164. Test HTTP access
SELECT * FROM read_csv('https://example.com/test.csv') LIMIT 5;

-- 165. Check glob pattern results
SELECT * FROM glob('data/*.parquet');

-- 166. List files in a directory
SELECT * FROM glob('/path/to/data/*');
```

### Concurrency Issues

```sql
-- 167. Check if database is locked
-- If you get "Could not set lock on file", another process has the write lock
-- Check for other DuckDB processes accessing the same file

-- 168. Force checkpoint to release WAL
FORCE CHECKPOINT;

-- 169. Open in read-only mode (allows concurrent reads)
-- CLI: duckdb -readonly my_database.duckdb
-- Python: con = duckdb.connect('my_database.duckdb', read_only=True)
```

## Advanced Diagnostics

### Sampling and Approximation

```sql
-- 170. Sample rows (fast approximate analysis)
SELECT * FROM orders USING SAMPLE 1000;
SELECT * FROM orders USING SAMPLE 10%;
SELECT * FROM orders TABLESAMPLE reservoir(1000);

-- 171. Approximate distinct count
SELECT approx_count_distinct(customer_id) FROM orders;

-- 172. Approximate quantiles
SELECT approx_quantile(amount, 0.5) AS median,
       approx_quantile(amount, 0.95) AS p95,
       approx_quantile(amount, 0.99) AS p99
FROM orders;
```

### Metadata about Parquet Files

```sql
-- 173. Parquet file statistics
SELECT path_in_schema, type, num_values,
       stats_min, stats_max, stats_null_count,
       compression, total_compressed_size, total_uncompressed_size
FROM parquet_metadata('data.parquet');

-- 174. Parquet schema tree
SELECT * FROM parquet_schema('data.parquet');

-- 175. Parquet file size vs table size
SELECT
    pg_size_pretty(total_compressed_size) AS parquet_size,
    pg_size_pretty(total_uncompressed_size) AS uncompressed_size,
    round(100.0 * total_compressed_size / total_uncompressed_size, 1) AS compression_pct
FROM (
    SELECT sum(total_compressed_size) AS total_compressed_size,
           sum(total_uncompressed_size) AS total_uncompressed_size
    FROM parquet_metadata('data.parquet')
);
```

### System Resource Monitoring

```sql
-- 176. Check thread count
SELECT current_setting('threads');

-- 177. Check all performance-related settings
SELECT name, value, description FROM duckdb_settings()
WHERE name IN ('threads', 'memory_limit', 'temp_directory',
               'preserve_insertion_order', 'enable_object_cache',
               'wal_autocheckpoint', 'checkpoint_threshold');

-- 178. PRAGMA version details
PRAGMA version;

-- 179. Platform information
PRAGMA platform;

-- 180. List available collations
PRAGMA collations;

-- 181. Database list (including attached)
PRAGMA database_list;

-- 182. Show table storage info summary
SELECT
    column_name,
    compression,
    count(*) AS num_segments,
    sum(count) AS total_values
FROM pragma_storage_info('orders')
GROUP BY column_name, compression
ORDER BY column_name;
```

### Data Quality Profiling

```sql
-- 183. Profile all columns of a table
SUMMARIZE orders;

-- 184. Detailed column statistics
SUMMARIZE SELECT * FROM read_parquet('data.parquet');

-- 185. Custom profiling query
SELECT
    column_name,
    count,
    null_percentage,
    approx_unique,
    min, max, avg
FROM (SUMMARIZE orders);

-- 186. Check value distribution
SELECT region, count(*) AS cnt,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM orders
GROUP BY region
ORDER BY cnt DESC;

-- 187. Detect data skew
SELECT
    ntile, min_val, max_val, count
FROM (
    SELECT ntile(10) OVER (ORDER BY amount) AS ntile,
           min(amount) AS min_val, max(amount) AS max_val, count(*) AS count
    FROM orders
    GROUP BY ntile
)
ORDER BY ntile;
```

### Useful PRAGMA Commands Summary

```sql
-- 188. PRAGMA database_size          -- database file size
-- 189. PRAGMA storage_info('t')      -- per-column storage details
-- 190. PRAGMA table_info('t')        -- column definitions
-- 191. PRAGMA show_tables            -- list tables
-- 192. PRAGMA show_tables_expanded   -- tables with column details
-- 193. PRAGMA version                -- DuckDB version
-- 194. PRAGMA platform               -- build platform
-- 195. PRAGMA collations             -- available collations
-- 196. PRAGMA database_list          -- attached databases
-- 197. PRAGMA enable_profiling       -- turn on query profiling
-- 198. PRAGMA disable_profiling      -- turn off query profiling
-- 199. PRAGMA enable_progress_bar    -- show progress for long queries
-- 200. PRAGMA disable_progress_bar   -- hide progress bar
```

### Comparing Data Across Sources

```sql
-- 201. Compare two Parquet files
SELECT * FROM read_parquet('v1.parquet')
EXCEPT
SELECT * FROM read_parquet('v2.parquet');

-- 202. Compare tables across databases
ATTACH 'prod.duckdb' AS prod;
ATTACH 'staging.duckdb' AS staging;
SELECT * FROM prod.main.orders
EXCEPT
SELECT * FROM staging.main.orders;

-- 203. Row count comparison across sources
SELECT 'parquet' AS src, count(*) FROM read_parquet('data.parquet')
UNION ALL
SELECT 'csv' AS src, count(*) FROM read_csv('data.csv')
UNION ALL
SELECT 'table' AS src, count(*) FROM orders;

-- 204. Schema comparison between two tables
SELECT a.column_name, a.data_type AS type_a, b.data_type AS type_b
FROM (SELECT * FROM duckdb_columns() WHERE table_name = 'orders_v1') a
FULL OUTER JOIN (SELECT * FROM duckdb_columns() WHERE table_name = 'orders_v2') b
ON a.column_name = b.column_name
WHERE a.data_type IS DISTINCT FROM b.data_type
   OR a.column_name IS NULL
   OR b.column_name IS NULL;
```

## Universal File Format Detection

### read_any Macro for Automatic Format Detection

```sql
-- 205. Define a universal file reader macro that dispatches by extension
CREATE OR REPLACE MACRO read_any(file_name) AS TABLE
  WITH json_case AS (FROM read_json_auto(file_name))
     , csv_case AS (FROM read_csv(file_name))
     , parquet_case AS (FROM read_parquet(file_name))
     , avro_case AS (FROM read_avro(file_name))
     , blob_case AS (FROM read_blob(file_name))
     , spatial_case AS (FROM st_read(file_name))
     , excel_case AS (FROM read_xlsx(file_name))
     , sqlite_case AS (FROM sqlite_scan(file_name,
         (SELECT name FROM sqlite_master(file_name) LIMIT 1)))
  FROM query_table(
    CASE
      WHEN file_name ILIKE '%.json' OR file_name ILIKE '%.jsonl'
        OR file_name ILIKE '%.ndjson' OR file_name ILIKE '%.geojson' THEN 'json_case'
      WHEN file_name ILIKE '%.csv' OR file_name ILIKE '%.tsv'
        OR file_name ILIKE '%.tab' OR file_name ILIKE '%.txt' THEN 'csv_case'
      WHEN file_name ILIKE '%.parquet' OR file_name ILIKE '%.pq' THEN 'parquet_case'
      WHEN file_name ILIKE '%.avro' THEN 'avro_case'
      WHEN file_name ILIKE '%.xlsx' OR file_name ILIKE '%.xls' THEN 'excel_case'
      WHEN file_name ILIKE '%.shp' OR file_name ILIKE '%.gpkg'
        OR file_name ILIKE '%.fgb' OR file_name ILIKE '%.kml' THEN 'spatial_case'
      WHEN file_name ILIKE '%.db' OR file_name ILIKE '%.sqlite'
        OR file_name ILIKE '%.sqlite3' THEN 'sqlite_case'
      ELSE 'blob_case'
    END
  );

-- 206. Inspect an unknown file
DESCRIBE FROM read_any('mystery_file.parquet');
SELECT count(*) AS row_count FROM read_any('mystery_file.parquet');
FROM read_any('mystery_file.parquet') LIMIT 20;

-- 207. Required extensions for read_any:
-- spatial files (.shp, .gpkg, .fgb, .kml): INSTALL spatial; LOAD spatial;
-- Excel files (.xlsx, .xls): excel extension (auto-loaded)
-- SQLite files (.db, .sqlite): INSTALL sqlite_scanner; LOAD sqlite_scanner;
-- Avro files (.avro): built-in (v1.4+)
```

### Additional File Format Diagnostics

```sql
-- 208. Read Avro files
SELECT * FROM read_avro('data.avro') LIMIT 10;
DESCRIBE FROM read_avro('data.avro');

-- 209. Read spatial files (requires spatial extension)
INSTALL spatial; LOAD spatial;
SELECT * FROM st_read('boundaries.gpkg') LIMIT 10;
SELECT * FROM st_read('data.shp') LIMIT 10;
SELECT * FROM st_read('features.geojson') LIMIT 10;

-- 210. Read SQLite databases (requires sqlite_scanner extension)
INSTALL sqlite_scanner; LOAD sqlite_scanner;
-- List all tables in a SQLite database
SELECT name FROM sqlite_master('legacy.db');
-- Query a specific table
SELECT * FROM sqlite_scan('legacy.db', 'users') LIMIT 10;

-- 211. Read Jupyter notebooks as structured data
WITH nb AS (FROM read_json_auto('notebook.ipynb'))
SELECT cell_idx, cell.cell_type,
       array_to_string(cell.source, '') AS source,
       cell.execution_count
FROM nb, UNNEST(cells) WITH ORDINALITY AS t(cell, cell_idx)
ORDER BY cell_idx;
```

## Full-Text Search Diagnostics

### Searching DuckDB Documentation Index

```sql
-- 212. Search a local copy of the DuckDB documentation index
-- (The duckdb-skills plugin caches this at ~/.duckdb/docs/duckdb-docs.duckdb)
INSTALL fts; LOAD fts;

-- Query the docs search index
SELECT chunk_id, page_title, section, breadcrumb, url, version, text,
       fts_main_docs_chunks.match_bm25(chunk_id, 'window functions qualify') AS score
FROM docs_chunks
WHERE score IS NOT NULL
ORDER BY score DESC
LIMIT 8;
```

## SQL Variables and Session State

```sql
-- 213. SQL-level variables (useful for parameterized queries)
SET VARIABLE my_threshold = 100;
SET VARIABLE my_region = 'US';
SELECT * FROM orders
WHERE amount > getvariable('my_threshold')
  AND region = getvariable('my_region');

-- 214. Session state file pattern (used by duckdb-skills plugin)
-- A state.sql file persists ATTACH, USE, LOAD, secrets, and macros across sessions:
--   ATTACH IF NOT EXISTS '/path/to/analytics.duckdb' AS analytics;
--   USE analytics;
--   LOAD httpfs;
-- Restore via: duckdb -init state.sql -c "SHOW TABLES;"
```

## Sandboxed Query Execution

```sql
-- 215. Run queries in a sandboxed environment (restricts file/network access)
-- Useful for executing untrusted SQL or limiting queries to specific files
SET allowed_paths = ['data.parquet', '/path/to/other_file.csv'];
SET enable_external_access = false;
SET allow_persistent_secrets = false;
SET lock_configuration = true;

-- After lock_configuration = true, no further SET commands are allowed
-- The query can only access files listed in allowed_paths
SELECT * FROM 'data.parquet' WHERE amount > 100;
```
