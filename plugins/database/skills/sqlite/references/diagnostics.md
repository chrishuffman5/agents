# SQLite Diagnostics Reference

## PRAGMA Schema Inspection

```sql
-- 1. List all attached databases
PRAGMA database_list;
-- Returns: seq, name, file

-- 2. Table column info (name, type, notnull, default, pk)
PRAGMA table_info('users');

-- 3. Extended table info (includes hidden/generated columns)
PRAGMA table_xinfo('users');

-- 4. List all tables with type info (table/view/virtual/shadow)
PRAGMA table_list;

-- 5. List indexes on a table
PRAGMA index_list('orders');

-- 6. Columns in a specific index
PRAGMA index_info('idx_orders_customer');

-- 7. Extended index info (includes rowid, sort order)
PRAGMA index_xinfo('idx_orders_customer');

-- 8. Foreign keys defined on a table
PRAGMA foreign_key_list('orders');

-- 9. Check foreign key violations (all tables)
PRAGMA foreign_key_check;

-- 10. Check foreign key violations (specific table)
PRAGMA foreign_key_check('orders');

-- 11. List collation sequences
PRAGMA collation_list;

-- 12. List compile-time options
PRAGMA compile_options;

-- 13. SQLite library version
SELECT sqlite_version();

-- 14. SQLite source ID (full build info)
SELECT sqlite_source_id();
```

## Database Integrity Checks

```sql
-- 15. Full integrity check (verifies B-tree structure, indexes, encoding)
PRAGMA integrity_check;

-- 16. Integrity check with error limit
PRAGMA integrity_check(100);

-- 17. Quick check (skips index cross-verification, faster)
PRAGMA quick_check;

-- 18. Quick check with error limit
PRAGMA quick_check(50);

-- 19. Foreign key integrity check
PRAGMA foreign_key_check;

-- 20. Verify a specific table's foreign keys
PRAGMA foreign_key_check('orders');

-- 21. Cell-level integrity check (most thorough, 3.46.0+)
PRAGMA cell_size_check = ON;
-- Then run integrity_check; it will also verify cell sizes
```

## Database Size and Page Metrics

```sql
-- 22. Total pages in the database
PRAGMA page_count;

-- 23. Page size in bytes
PRAGMA page_size;

-- 24. Free pages on the freelist
PRAGMA freelist_count;

-- 25. Database file size in bytes
SELECT page_count * page_size AS db_size_bytes
FROM pragma_page_count(), pragma_page_size();

-- 26. Free space percentage
SELECT (freelist_count * 100.0 / page_count) AS free_pct
FROM pragma_freelist_count(), pragma_page_count();

-- 27. Auto-vacuum status (0=none, 1=full, 2=incremental)
PRAGMA auto_vacuum;

-- 28. Maximum page count limit
PRAGMA max_page_count;

-- 29. Database encoding (UTF-8, UTF-16le, UTF-16be)
PRAGMA encoding;

-- 30. Schema version (incremented on schema changes)
PRAGMA schema_version;

-- 31. User version (application-defined)
PRAGMA user_version;

-- 32. Application ID
PRAGMA application_id;

-- 33. Data version (changes with any modification, useful for cache invalidation)
PRAGMA data_version;
```

## WAL and Journal Diagnostics

```sql
-- 34. Current journal mode
PRAGMA journal_mode;

-- 35. Set WAL mode
PRAGMA journal_mode = WAL;

-- 36. Auto-checkpoint threshold (pages)
PRAGMA wal_autocheckpoint;

-- 37. Set auto-checkpoint threshold
PRAGMA wal_autocheckpoint = 1000;

-- 38. Passive checkpoint (returns busy, log, checkpointed page counts)
PRAGMA wal_checkpoint;

-- 39. Full checkpoint (waits for readers)
PRAGMA wal_checkpoint(FULL);

-- 40. Restart checkpoint (resets WAL position)
PRAGMA wal_checkpoint(RESTART);

-- 41. Truncate checkpoint (truncates WAL to zero bytes)
PRAGMA wal_checkpoint(TRUNCATE);

-- 42. Check synchronous mode
PRAGMA synchronous;
-- 0=OFF, 1=NORMAL, 2=FULL, 3=EXTRA

-- 43. WAL file size estimate
-- WAL file size = (wal_autocheckpoint * page_size) at maximum between checkpoints
-- Check disk: ls -la database-wal

-- 44. Check locking mode
PRAGMA locking_mode;
-- NORMAL (default) or EXCLUSIVE

-- 45. Set exclusive locking mode (hold locks for entire session)
PRAGMA locking_mode = EXCLUSIVE;
```

## Cache and Memory Configuration

```sql
-- 46. Current page cache size
PRAGMA cache_size;
-- Positive = number of pages; negative = KB

-- 47. Set page cache to 64MB
PRAGMA cache_size = -64000;

-- 48. Memory-mapped I/O size
PRAGMA mmap_size;

-- 49. Set memory-map to 256MB
PRAGMA mmap_size = 268435456;

-- 50. Temp store location (0=default, 1=file, 2=memory)
PRAGMA temp_store;

-- 51. Force temp tables to memory
PRAGMA temp_store = MEMORY;

-- 52. Show cache hit statistics (available via sqlite3_status C API)
-- In CLI, use .stats to see cache hits/misses
```

## Performance Configuration PRAGMAs

```sql
-- 53. Busy timeout in milliseconds
PRAGMA busy_timeout;

-- 54. Set busy timeout to 5 seconds
PRAGMA busy_timeout = 5000;

-- 55. Foreign key enforcement status
PRAGMA foreign_keys;

-- 56. Enable foreign key enforcement
PRAGMA foreign_keys = ON;

-- 57. Recursive trigger status
PRAGMA recursive_triggers;

-- 58. Enable recursive triggers
PRAGMA recursive_triggers = ON;

-- 59. Secure delete mode (overwrite deleted content with zeros)
PRAGMA secure_delete;

-- 60. Case-sensitive LIKE
PRAGMA case_sensitive_like = ON;

-- 61. Automatic indexing (auto-indexes for queries without explicit indexes)
PRAGMA automatic_index;

-- 62. Analysis limit for ANALYZE
PRAGMA analysis_limit;

-- 63. Set analysis limit (rows to sample per index)
PRAGMA analysis_limit = 1000;

-- 64. Run optimize (auto-ANALYZE tables that need it)
PRAGMA optimize;

-- 65. Optimize with a specific mask (0x10002 = analyze tables + check schema)
PRAGMA optimize(0x10002);
```

## EXPLAIN and Query Plan Analysis

```sql
-- 66. High-level query plan
EXPLAIN QUERY PLAN
SELECT o.*, c.name
FROM orders o JOIN customers c ON o.customer_id = c.id
WHERE o.total > 100
ORDER BY o.order_date DESC;

-- 67. VDBE bytecode (low-level)
EXPLAIN
SELECT * FROM users WHERE email = 'alice@example.com';

-- 68. Index usage verification
EXPLAIN QUERY PLAN SELECT * FROM orders WHERE customer_id = 42;
-- Good: SEARCH orders USING INDEX idx_customer (customer_id=?)
-- Bad:  SCAN orders (full table scan)

-- 69. Covering index check
EXPLAIN QUERY PLAN SELECT customer_id, total FROM orders WHERE customer_id = 42;
-- Best: SEARCH orders USING COVERING INDEX idx_cust_total (customer_id=?)

-- 70. JOIN order analysis
EXPLAIN QUERY PLAN
SELECT * FROM a JOIN b ON a.id = b.a_id JOIN c ON b.id = c.b_id;
-- Look for: estimated row counts and join order

-- 71. Subquery materialization check
EXPLAIN QUERY PLAN
SELECT * FROM orders WHERE customer_id IN (SELECT id FROM customers WHERE active = 1);
-- Look for: USING TEMP B-TREE (subquery materialized) or LIST SUBQUERY

-- 72. Automatic index detection
EXPLAIN QUERY PLAN
SELECT * FROM big_table WHERE unindexed_column = 'value';
-- Look for: AUTOMATIC COVERING INDEX
-- Indicates SQLite created a transient index; consider adding a permanent one
```

## sqlite3 CLI Diagnostic Commands

```sql
-- 73. Show all tables
.tables

-- 74. Show all tables matching a pattern
.tables orders%

-- 75. Show schema for all objects
.schema

-- 76. Show schema for a specific table
.schema orders

-- 77. Show schema with indexes
.schema --indent orders

-- 78. Show all indexes
.indexes

-- 79. Show indexes for a specific table
.indexes orders

-- 80. Show database file info
.dbinfo

-- 81. Enable headers in output
.headers on

-- 82. Set output mode
.mode column
-- Options: ascii, box, csv, column, html, insert, json, line, list, markdown, table, tabs, tcl

-- 83. Enable timer (shows execution time)
.timer on
-- Since 3.51.0: precision increased to microseconds

-- 84. Show execution statistics
.stats on
-- Displays: memory used, I/O stats, vm steps, sort operations, autoindex, etc.

-- 85. Enable expert mode (suggests indexes)
.expert on
SELECT * FROM orders WHERE customer_id = 42 AND status = 'shipped';
.expert off
-- Shows: CREATE INDEX suggestions based on query patterns

-- 86. Dump entire database as SQL
.dump

-- 87. Dump a specific table
.dump orders

-- 88. Backup database to a file
.backup main backup.db

-- 89. Restore from backup
.restore main backup.db

-- 90. Import CSV data
.import --csv data.csv orders

-- 91. Import with custom separator
.separator "|"
.import data.psv orders

-- 92. Output to file
.output results.csv
SELECT * FROM orders;
.output stdout

-- 93. Read and execute SQL from a file
.read setup.sql

-- 94. Show current settings
.show

-- 95. Enable column names for dot commands
.headers on
.mode box

-- 96. Show help
.help

-- 97. Recover data from corrupt database
.recover

-- 98. Recover ignoring freelist
.recover --ignore-freelist

-- 99. Imposter table (read-only access to index B-tree as table, 3.51.0+)
.imposter idx_orders_customer orders_by_cust

-- 100. Show database page utilization summary
-- (Requires dbstat virtual table, compile with SQLITE_ENABLE_DBSTAT_VTAB)
.dbinfo
```

## Storage Analysis with dbstat

```sql
-- 101. Enable dbstat virtual table (if compiled with SQLITE_ENABLE_DBSTAT_VTAB)
-- Then query page-level storage:
SELECT
    name,
    count(*) AS pages,
    sum(pgsize) AS total_bytes,
    sum(unused) AS unused_bytes,
    round(100.0 * sum(unused) / sum(pgsize), 1) AS unused_pct
FROM dbstat
GROUP BY name
ORDER BY total_bytes DESC;

-- 102. Page utilization per table
SELECT
    name,
    count(*) AS total_pages,
    sum(CASE WHEN pgsize > 0 THEN 1 ELSE 0 END) AS used_pages,
    round(avg(pgsize), 0) AS avg_page_bytes,
    round(avg(payload), 0) AS avg_payload_bytes,
    round(100.0 * avg(payload) / avg(pgsize), 1) AS fill_pct
FROM dbstat
WHERE name NOT LIKE 'sqlite_%'
GROUP BY name
ORDER BY total_pages DESC;

-- 103. Overflow page analysis (large records causing overflow)
SELECT name, count(*) AS overflow_pages
FROM dbstat
WHERE path LIKE '%overflow%'
GROUP BY name
ORDER BY overflow_pages DESC;

-- 104. Index vs table storage ratio
SELECT
    tbl_name,
    sum(CASE WHEN type = 'table' THEN pgsize ELSE 0 END) AS table_bytes,
    sum(CASE WHEN type = 'index' THEN pgsize ELSE 0 END) AS index_bytes,
    round(100.0 * sum(CASE WHEN type = 'index' THEN pgsize ELSE 0 END) /
                   nullif(sum(pgsize), 0), 1) AS index_pct
FROM (
    SELECT d.name, s.type, d.pgsize
    FROM dbstat d JOIN sqlite_schema s ON d.name = s.name
)
GROUP BY tbl_name
ORDER BY (table_bytes + index_bytes) DESC;

-- 105. Database fragmentation estimate
SELECT
    name,
    count(*) AS pages,
    max(pageno) - min(pageno) + 1 AS page_span,
    round(100.0 * count(*) / (max(pageno) - min(pageno) + 1), 1) AS contiguity_pct
FROM dbstat
GROUP BY name
HAVING count(*) > 1
ORDER BY contiguity_pct ASC;
```

## Index Analysis

```sql
-- 106. All indexes with column details
SELECT
    il.name AS index_name,
    il.origin,  -- 'c' (CREATE INDEX), 'pk' (PRIMARY KEY), or 'u' (UNIQUE)
    il."unique",
    il.partial,
    group_concat(ii.name, ', ') AS columns
FROM pragma_index_list('orders') il
JOIN pragma_index_info(il.name) ii
GROUP BY il.name;

-- 107. Unused indexes (requires sqlite_stat1 from ANALYZE)
SELECT s.name AS index_name, s.tbl_name
FROM sqlite_schema s
LEFT JOIN sqlite_stat1 st ON s.name = st.idx
WHERE s.type = 'index'
  AND st.idx IS NULL;

-- 108. Index selectivity from statistics
SELECT idx, tbl, stat
FROM sqlite_stat1
ORDER BY tbl, idx;
-- stat format: "total_rows est_rows_per_key [est_rows_per_prefix...]"

-- 109. Identify large tables without indexes
SELECT s.name AS table_name
FROM sqlite_schema s
WHERE s.type = 'table'
  AND s.name NOT LIKE 'sqlite_%'
  AND s.name NOT IN (SELECT DISTINCT tbl_name FROM sqlite_schema WHERE type = 'index')
ORDER BY s.name;

-- 110. Index size estimation (via dbstat)
SELECT name, sum(pgsize) AS index_bytes
FROM dbstat
WHERE name IN (SELECT name FROM sqlite_schema WHERE type = 'index')
GROUP BY name
ORDER BY index_bytes DESC;

-- 111. Covering index verification for a query
EXPLAIN QUERY PLAN SELECT col1, col2 FROM t WHERE col1 = ?;
-- Look for "USING COVERING INDEX" in output
```

## Performance Profiling

```sql
-- 112. Enable timer in CLI
.timer on

-- 113. Enable stats in CLI
.stats on
-- Shows after each query:
--   Memory Used, VM Steps, Sort Operations, Autoindex count,
--   Fullscan Steps, Page Cache hits/misses/writes

-- 114. Profile a slow query step-by-step
EXPLAIN QUERY PLAN <your_query>;
-- Then examine: scan types, index usage, sort operations, subquery materialization

-- 115. Measure table scan speed (baseline)
.timer on
SELECT count(*) FROM large_table;
-- Gives raw scan speed for comparison

-- 116. Measure index scan speed
.timer on
SELECT count(*) FROM large_table WHERE indexed_col = 'value';
-- Compare against full scan to validate index benefit

-- 117. Identify full table scans in complex queries
EXPLAIN QUERY PLAN
SELECT * FROM a
JOIN b ON a.id = b.a_id
JOIN c ON b.id = c.b_id
WHERE a.status = 'active';
-- Look for SCAN (without index) on large tables

-- 118. Check if ANALYZE statistics are current
SELECT tbl, idx, stat FROM sqlite_stat1 ORDER BY tbl;
-- If empty or stale, run: ANALYZE;

-- 119. Force re-analyze with sampling limit
PRAGMA analysis_limit = 500;
ANALYZE;

-- 120. Use optimize to selectively re-analyze
PRAGMA optimize;
-- Only analyzes tables whose statistics appear stale
```

## FTS5 Diagnostics

```sql
-- 121. Check FTS5 table structure
SELECT * FROM sqlite_schema WHERE name LIKE '%docs%';
-- FTS5 creates shadow tables: docs_content, docs_data, docs_docsize, docs_config, docs_idx

-- 122. FTS5 configuration
SELECT * FROM docs_config;
-- Shows: tokenizer, content table, prefix settings

-- 123. FTS5 table size
SELECT sum(pgsize) FROM dbstat WHERE name LIKE 'docs%';

-- 124. Rebuild FTS5 index (after external content changes)
INSERT INTO docs(docs) VALUES('rebuild');

-- 125. Optimize FTS5 index (merge segments for faster queries)
INSERT INTO docs(docs) VALUES('optimize');

-- 126. Integrity check for FTS5
INSERT INTO docs(docs) VALUES('integrity-check');

-- 127. FTS5 rank configuration
-- Default rank function is bm25()
SELECT *, rank FROM docs WHERE docs MATCH 'query' ORDER BY rank;

-- 128. FTS5 token statistics
SELECT * FROM docs('token-count');

-- 129. Check FTS5 vocabulary (list indexed terms)
CREATE VIRTUAL TABLE docs_vocab USING fts5vocab(docs, 'row');
SELECT term, doc AS doc_count, cnt AS term_count
FROM docs_vocab
ORDER BY cnt DESC
LIMIT 20;

-- 130. FTS5 vocabulary by column
CREATE VIRTUAL TABLE docs_col_vocab USING fts5vocab(docs, 'col');
SELECT term, col, doc, cnt FROM docs_col_vocab ORDER BY cnt DESC LIMIT 20;
```

## Lock and Busy Handler Diagnostics

```sql
-- 131. Check current busy timeout
PRAGMA busy_timeout;

-- 132. Check locking mode
PRAGMA locking_mode;

-- 133. Test for lock contention (attempt immediate write)
BEGIN IMMEDIATE;
-- If this returns SQLITE_BUSY, another connection holds a write lock
ROLLBACK;

-- 134. Check journal mode (affects locking behavior)
PRAGMA journal_mode;
-- WAL = concurrent readers + single writer
-- DELETE/TRUNCATE/PERSIST = readers block writers

-- 135. Check if database is in WAL recovery
-- Look for -wal and -shm files alongside the database
-- If -wal exists but no connections are open, recovery may be needed:
-- Simply opening the database triggers automatic WAL recovery

-- 136. Monitor WAL size (indicator of checkpoint lag)
-- From OS: ls -la database-wal
-- Large WAL = checkpoints not keeping up or long-running reader preventing checkpoint

-- 137. Force checkpoint to reduce WAL size
PRAGMA wal_checkpoint(TRUNCATE);

-- 138. Check for long-running transactions (application-level)
-- SQLite does not have a pg_stat_activity equivalent
-- Monitor from application code: log transaction start/end times
-- Long-running readers prevent WAL checkpointing

-- 139. Detect deadlock scenarios
-- SQLite returns SQLITE_BUSY (not deadlock) when it detects potential deadlock
-- from lock escalation: SHARED -> RESERVED -> PENDING -> EXCLUSIVE
-- Use BEGIN IMMEDIATE to avoid SHARED->RESERVED escalation deadlocks

-- 140. Test database accessibility
SELECT 1;
-- If this fails with SQLITE_BUSY or SQLITE_LOCKED, another connection holds an exclusive lock
```

## sqlite3_analyzer Tool

```
# 141. Run sqlite3_analyzer on a database (command-line tool)
sqlite3_analyzer database.db

# Output includes:
# - Table and index sizes (pages, bytes, overhead)
# - Page utilization percentage
# - Average payload per entry
# - Average unused bytes per page
# - Maximum and average fanout for B-trees
# - Overflow page count
# - Depth of each B-tree

# 142. Analyze a specific table
sqlite3_analyzer database.db orders

# 143. Output as SQL statements (for scripting)
sqlite3_analyzer --sqloutput database.db > analysis.sql
# Then query: sqlite3 :memory: < analysis.sql
# SELECT * FROM space_used ORDER BY payload DESC;

# 144. Compare database sizes
sqlite3_analyzer database1.db > analysis1.txt
sqlite3_analyzer database2.db > analysis2.txt
diff analysis1.txt analysis2.txt
```

## sqldiff Tool

```
# 145. Compare two databases and output SQL to transform db1 into db2
sqldiff database1.db database2.db

# 146. Compare a specific table only
sqldiff --table orders database1.db database2.db

# 147. Show schema differences only
sqldiff --schema database1.db database2.db

# 148. Output as transaction
sqldiff --transaction database1.db database2.db

# 149. Compare using primary key (instead of rowid)
sqldiff --primarykey database1.db database2.db

# 150. Summary mode (count changes, don't output SQL)
sqldiff --summary database1.db database2.db
```

## sqlite3_rsync Tool

```
# 151. Synchronize a local database to a remote host
sqlite3_rsync local.db user@remote:/path/to/remote.db

# 152. Synchronize from remote to local
sqlite3_rsync user@remote:/path/to/remote.db local.db

# 153. Both origin and replica can be active during sync
# Other applications can read from or write to the origin
# and read from the replica without disrupting the process

# 154. Efficient page-level transfer (only changed pages are sent)
# Similar to rsync, but understands SQLite page structure
```

## Corruption Detection and Recovery

```sql
-- 155. Full integrity check
PRAGMA integrity_check;
-- Returns "ok" or list of errors

-- 156. Quick integrity check
PRAGMA quick_check;

-- 157. Check for freelist corruption
PRAGMA freelist_count;
-- Compare with expected value; sudden changes indicate corruption

-- 158. Check file header
-- From CLI:
.dbinfo
-- Verify: page size, page count, encoding, schema version

-- 159. Recover data from corrupt database (CLI)
-- sqlite3 corrupt.db ".recover" | sqlite3 recovered.db

-- 160. Recover ignoring freelist pages
-- sqlite3 corrupt.db ".recover --ignore-freelist" | sqlite3 recovered.db

-- 161. Manual recovery via dump and reimport
-- sqlite3 corrupt.db ".dump" | sqlite3 recovered.db
-- Note: .dump may fail on severely corrupt databases; .recover is more resilient

-- 162. Verify WAL integrity after crash
-- Simply opening the database triggers automatic WAL replay
-- If WAL is corrupt, delete -wal and -shm files (loses uncommitted transactions)

-- 163. Check for zero-page corruption (pages filled with zeros)
-- Use sqlite3_analyzer to identify pages with zero content

-- 164. Verify all JSONB columns parse correctly
SELECT rowid FROM t WHERE json_valid(jsonb_col) = 0;
```

## Table and Schema Management Diagnostics

```sql
-- 165. List all tables with row counts
SELECT name,
       (SELECT count(*) FROM pragma_table_info(name)) AS columns
FROM sqlite_schema
WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
ORDER BY name;

-- 166. Estimate row counts for all tables (fast, no full scan)
-- If sqlite_stat1 exists:
SELECT tbl AS table_name, stat
FROM sqlite_stat1
WHERE idx IS NULL OR idx = tbl;
-- The first number in stat is the approximate row count

-- 167. Exact row counts (slow for large tables)
SELECT 'orders' AS tbl, count(*) AS rows FROM orders
UNION ALL
SELECT 'customers', count(*) FROM customers
UNION ALL
SELECT 'products', count(*) FROM products;

-- 168. Column data type distribution (type affinity check)
SELECT typeof(col) AS actual_type, count(*) AS cnt
FROM my_table
GROUP BY typeof(col);

-- 169. NULL value analysis
SELECT
    count(*) AS total_rows,
    count(col1) AS col1_non_null,
    count(*) - count(col1) AS col1_null,
    round(100.0 * (count(*) - count(col1)) / count(*), 1) AS col1_null_pct
FROM my_table;

-- 170. Find tables with WITHOUT ROWID
SELECT name, sql FROM sqlite_schema
WHERE type = 'table' AND sql LIKE '%WITHOUT ROWID%';

-- 171. Find STRICT tables
SELECT name, sql FROM sqlite_schema
WHERE type = 'table' AND sql LIKE '%STRICT%';

-- 172. Find virtual tables
SELECT name, sql FROM sqlite_schema
WHERE type = 'table' AND sql LIKE '%VIRTUAL TABLE%';

-- 173. Show all triggers
SELECT name, tbl_name, sql FROM sqlite_schema WHERE type = 'trigger';

-- 174. Show all views
SELECT name, sql FROM sqlite_schema WHERE type = 'view';
```

## Vacuum and Space Reclamation

```sql
-- 175. Full VACUUM (rewrite entire database, reclaim all free space)
VACUUM;
-- WARNING: requires exclusive lock and ~2x disk space temporarily

-- 176. VACUUM INTO a new file (non-destructive, 3.27.0+)
VACUUM INTO 'compacted.db';

-- 177. Check auto-vacuum mode
PRAGMA auto_vacuum;
-- 0 = none, 1 = full, 2 = incremental

-- 178. Set auto-vacuum (must be set on empty database, before creating tables)
PRAGMA auto_vacuum = INCREMENTAL;

-- 179. Run incremental vacuum (reclaim N pages)
PRAGMA incremental_vacuum(100);

-- 180. Run incremental vacuum (reclaim all free pages)
PRAGMA incremental_vacuum;

-- 181. Check space reclaimable
SELECT freelist_count * page_size AS reclaimable_bytes
FROM pragma_freelist_count(), pragma_page_size();
```

## Advanced Diagnostics

```sql
-- 182. List all attached databases with file paths
SELECT seq, name, file FROM pragma_database_list();

-- 183. Check threading mode
SELECT * FROM pragma_compile_options() WHERE compile_option LIKE 'THREADSAFE%';

-- 184. Check if JSON is enabled
SELECT json('{"test":1}');
-- Returns '{"test":1}' if JSON is enabled; error if not

-- 185. Check if FTS5 is enabled
SELECT * FROM pragma_compile_options() WHERE compile_option = 'ENABLE_FTS5';

-- 186. Check if R*Tree is enabled
SELECT * FROM pragma_compile_options() WHERE compile_option = 'ENABLE_RTREE';

-- 187. Check if math functions are enabled
SELECT ceil(1.5);
-- Returns 2 if math functions are enabled; error if not

-- 188. Check if dbstat virtual table is available
SELECT * FROM pragma_compile_options() WHERE compile_option = 'ENABLE_DBSTAT_VTAB';

-- 189. Monitor temp file usage
-- From CLI:
.stats on
-- Look for "Number of Temp Files" and "Size of Temp Files" after queries

-- 190. Check default cache size stored in the header
PRAGMA default_cache_size;

-- 191. Check maximum variable number (for parameter binding limits)
SELECT * FROM pragma_compile_options() WHERE compile_option LIKE 'MAX_VARIABLE_NUMBER%';

-- 192. Database header dump (first 100 bytes)
-- From CLI:
.dbinfo
-- Shows: database page size, write format, read format, file change counter,
--        database page count, freelist page count, schema cookie, schema format,
--        text encoding, user version, application id, software version

-- 193. Verify database can be opened by this version
PRAGMA integrity_check(1);
-- If the first check passes, the file header is readable

-- 194. List all functions available
-- Not directly queryable in SQLite; use compile_options to infer
-- Or test: SELECT typeof(json('{}'));  -- tests JSON
--          SELECT typeof(fts5(''));     -- tests FTS5

-- 195. Check if WAL mode is properly configured
PRAGMA journal_mode;
PRAGMA synchronous;
-- Recommended combo: journal_mode=WAL + synchronous=NORMAL

-- 196. Estimate WAL age (how long since last full checkpoint)
-- Check WAL file modification time from OS
-- Large WAL + old mtime = checkpoint stall (likely a long-running reader)

-- 197. Detect potential index bloat after many DELETEs
SELECT name,
       (SELECT count(*) FROM pragma_index_info(name)) AS key_columns,
       CASE WHEN stat IS NULL THEN 'no stats' ELSE stat END AS statistics
FROM sqlite_schema s
LEFT JOIN sqlite_stat1 st ON s.name = st.idx
WHERE s.type = 'index';
-- If actual selectivity is much worse than expected, consider REINDEX

-- 198. REINDEX a specific index
REINDEX idx_orders_customer;

-- 199. REINDEX all indexes
REINDEX;

-- 200. Test a specific PRAGMA function form
SELECT * FROM pragma_table_info('orders');
-- The pragma_xxx() function form allows use in JOINs and subqueries
```
