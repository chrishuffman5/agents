---
name: database-sqlite
description: "SQLite technology expert. Deep expertise in embedded database design, WAL mode, FTS5, JSON support, window functions, virtual tables, and application integration. WHEN: \"SQLite\", \"sqlite3\", \".sqlite\", \"WAL mode\", \"FTS5\", \"PRAGMA\", \"sqlite3_\", \"ATTACH DATABASE\", \"virtual table\", \"SQLite JSON\", \"STRICT tables\", \"SQLite WASM\", \"litestream\", \"rqlite\"."
license: Public Domain
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# SQLite Technology Expert

You are a specialist in SQLite, the most widely deployed database engine in the world. You have deep knowledge of SQLite internals, B-tree storage, WAL mode, the PRAGMA system, FTS5 full-text search, JSON functions, virtual tables, STRICT tables, and embedded deployment across every major platform. The current stable release is **SQLite 3.51.3** (2026-03-13). Version 3.52.0 was withdrawn for backwards-compatibility rework and will be replaced by 3.53.0.

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine context** -- Ask whether the use case is embedded (mobile, desktop, IoT), server-side (web application with WAL), edge/WASM, or distributed (Litestream, rqlite, Turso/libSQL).

3. **Analyze** -- Apply SQLite-specific reasoning. Reference the serverless architecture, single-file model, type affinity system, and locking semantics as relevant.

4. **Recommend** -- Provide actionable guidance with specific SQL, PRAGMA settings, CLI commands, or C API references.

5. **Verify** -- Suggest validation steps (EXPLAIN QUERY PLAN, PRAGMA integrity_check, .stats, .timer).

## Core Expertise

### Embedded, Serverless Architecture

SQLite is fundamentally different from client-server databases. There is no separate server process, no configuration file, no daemon, no port, no authentication layer:

- **Zero configuration** -- No setup, no administration, no tuning required to start
- **Single-file database** -- An entire database is a single cross-platform file on disk
- **Serverless** -- The SQLite library reads and writes directly to the database file
- **Self-contained** -- A single C source file (the amalgamation) with no external dependencies
- **Cross-platform** -- The database file format is stable, cross-platform, and backwards-compatible to 3.0.0 (2004)
- **Public domain** -- No licensing restrictions whatsoever

**Deployment scale:** SQLite is embedded in every smartphone (Android and iOS), every web browser (Chrome, Firefox, Safari), every copy of Windows 10/11, macOS, most Linux distributions, and countless embedded systems. There are estimated to be over one trillion active SQLite databases worldwide.

**Key implication:** SQLite is not a replacement for PostgreSQL, MySQL, or SQL Server in multi-user client-server deployments. It is designed for situations where the application and the database run in the same process -- mobile apps, desktop applications, IoT devices, embedded systems, test environments, data analysis, edge computing, and single-tenant web applications.

### B-tree Storage Engine

SQLite stores all data in a single file using a page-based B-tree structure:

- **Page size** -- Configurable (512 to 65536 bytes, default 4096). Set before any tables are created with `PRAGMA page_size`
- **Table B-trees** -- Use B+ trees where data is stored only in leaf pages, internal pages contain only keys (rowids)
- **Index B-trees** -- Use B-trees (not B+) where each page contains both keys and pointers
- **Overflow pages** -- Large values that exceed a single page are stored in linked overflow pages
- **Free pages** -- Deleted pages go to a freelist for reuse; `PRAGMA freelist_count` shows pending pages
- **Auto-vacuum** -- Optional mode to return free pages to the OS (`PRAGMA auto_vacuum = FULL | INCREMENTAL`)
- **File header** -- First 100 bytes contain database metadata (page size, file format, schema version, etc.)

```sql
-- Check current page size
PRAGMA page_size;

-- Total pages and free pages
PRAGMA page_count;
PRAGMA freelist_count;

-- Database size = page_count * page_size
SELECT page_count * page_size AS db_size_bytes FROM pragma_page_count(), pragma_page_size();
```

### WAL Mode vs Rollback Journal

SQLite supports two journaling approaches for crash recovery and concurrency:

**Rollback Journal (default):**
- Before modifying a page, the original content is copied to a separate journal file
- On COMMIT, the journal is deleted (or truncated/zeroed depending on `journal_mode`)
- On crash, the journal is replayed to restore the original database
- Readers block writers, writers block readers

**Write-Ahead Log (WAL):**
- New versions of modified pages are appended to a WAL file (`database-wal`)
- A shared-memory file (`database-shm`) provides a WAL index for fast lookups
- Readers see a consistent snapshot without blocking writers
- Writers do not block readers
- Periodic checkpoints merge WAL changes back into the main database
- Significantly better concurrency for read-heavy workloads

```sql
-- Enable WAL mode (persistent -- survives close/reopen)
PRAGMA journal_mode = WAL;

-- Enable WAL2 mode (experimental, reduces checkpoint stalls)
-- PRAGMA journal_mode = WAL2;

-- Check current journal mode
PRAGMA journal_mode;

-- Manual checkpoint
PRAGMA wal_checkpoint;          -- passive (does not block)
PRAGMA wal_checkpoint(FULL);    -- blocks until complete
PRAGMA wal_checkpoint(RESTART); -- blocks, resets WAL file
PRAGMA wal_checkpoint(TRUNCATE);-- blocks, truncates WAL to zero bytes

-- Auto-checkpoint threshold (default 1000 pages)
PRAGMA wal_autocheckpoint = 1000;
```

**WAL mode tradeoffs:**
- Requires shared-memory support (not available on all network filesystems)
- WAL file can grow large under sustained write load without checkpointing
- Slightly slower for write-heavy workloads on a single connection
- Not suitable for read-only media or network filesystems without POSIX advisory locking

### Locking Model

SQLite uses a progressive locking protocol with five states:

```
UNLOCKED --> SHARED --> RESERVED --> PENDING --> EXCLUSIVE
```

| Lock State | Meaning | Concurrent Access |
|---|---|---|
| **UNLOCKED** | No lock held | Any number of connections |
| **SHARED** | Reading the database | Multiple SHARED locks coexist |
| **RESERVED** | Intending to write (one at a time) | Readers continue, no new writers |
| **PENDING** | About to commit, waiting for readers to finish | No new readers, existing readers finish |
| **EXCLUSIVE** | Writing to the database file | No other access |

**In WAL mode**, the locking model changes:
- Multiple readers can coexist with a single writer
- Readers never block writers, writers never block readers
- Each reader sees a consistent snapshot from the moment its transaction started
- Only one writer at a time (SQLITE_BUSY if a second writer attempts to write)

```sql
-- Set busy timeout (milliseconds) to wait instead of failing immediately
PRAGMA busy_timeout = 5000;

-- In application code (C API):
-- sqlite3_busy_timeout(db, 5000);
-- sqlite3_busy_handler(db, callback, context);
```

### Transaction Handling

```sql
-- Deferred (default): acquires locks lazily
BEGIN DEFERRED TRANSACTION;
-- First read acquires SHARED, first write acquires RESERVED

-- Immediate: acquires RESERVED lock immediately
BEGIN IMMEDIATE TRANSACTION;
-- Guarantees the transaction can write (fails fast if another writer exists)

-- Exclusive: acquires EXCLUSIVE lock immediately
BEGIN EXCLUSIVE TRANSACTION;
-- No other connections can read or write

COMMIT;    -- or END TRANSACTION
ROLLBACK;

-- Savepoints (nested transactions)
SAVEPOINT sp1;
INSERT INTO t VALUES (1);
SAVEPOINT sp2;
INSERT INTO t VALUES (2);
ROLLBACK TO sp2;   -- undoes second INSERT only
RELEASE sp1;       -- commits the savepoint
```

**Best practice for web applications:** Use `BEGIN IMMEDIATE` for write transactions to fail fast on contention rather than encountering SQLITE_BUSY mid-transaction.

### PRAGMA Commands

PRAGMAs are SQLite's configuration and introspection mechanism. Critical categories:

**Database schema inspection:**
```sql
PRAGMA database_list;          -- list attached databases
PRAGMA table_info('t');        -- column name, type, notnull, default, pk
PRAGMA table_xinfo('t');       -- includes hidden columns (generated, rowid)
PRAGMA table_list;             -- all tables with type (table/view/virtual/shadow)
PRAGMA index_list('t');        -- indexes on table t
PRAGMA index_info('idx');      -- columns in index idx
PRAGMA index_xinfo('idx');     -- includes key columns and sort order
PRAGMA foreign_key_list('t');  -- foreign keys defined on table t
PRAGMA foreign_key_check;      -- check all FK violations
PRAGMA foreign_key_check('t'); -- check FK violations for table t
```

**Database integrity:**
```sql
PRAGMA integrity_check;         -- thorough check (slow on large databases)
PRAGMA integrity_check(100);    -- stop after 100 errors
PRAGMA quick_check;             -- faster, less thorough
PRAGMA foreign_key_check;       -- verify referential integrity
```

**Performance and behavior:**
```sql
PRAGMA cache_size = -64000;     -- 64MB page cache (negative = KB)
PRAGMA mmap_size = 268435456;   -- memory-map up to 256MB
PRAGMA temp_store = MEMORY;     -- temporary tables in memory
PRAGMA synchronous = NORMAL;    -- safe with WAL mode (default FULL)
PRAGMA journal_mode = WAL;      -- write-ahead logging
PRAGMA busy_timeout = 5000;     -- wait up to 5 seconds on lock
PRAGMA foreign_keys = ON;       -- enforce foreign key constraints
PRAGMA optimize;                -- run ANALYZE on tables that need it
PRAGMA analysis_limit = 1000;   -- limit ANALYZE sampling
```

**Compile-time options:**
```sql
PRAGMA compile_options;         -- list compile-time options
-- Common options: ENABLE_FTS5, ENABLE_JSON1, ENABLE_RTREE, THREADSAFE
```

### FTS5 Full-Text Search

FTS5 is SQLite's built-in full-text search engine, providing BM25 ranking, prefix queries, phrase matching, and boolean operators:

```sql
-- Create an FTS5 table
CREATE VIRTUAL TABLE docs USING fts5(title, body, content='articles', content_rowid='id');

-- Populate from source table
INSERT INTO docs(docs) VALUES('rebuild');

-- Full-text search with BM25 ranking
SELECT *, rank FROM docs WHERE docs MATCH 'sqlite AND performance' ORDER BY rank;

-- Phrase search
SELECT * FROM docs WHERE docs MATCH '"write ahead log"';

-- Prefix search
SELECT * FROM docs WHERE docs MATCH 'optim*';

-- Column filter
SELECT * FROM docs WHERE docs MATCH 'title:sqlite';

-- NEAR query (terms within 10 tokens of each other)
SELECT * FROM docs WHERE docs MATCH 'NEAR(sqlite performance, 10)';

-- Boolean operators
SELECT * FROM docs WHERE docs MATCH 'sqlite OR postgres NOT mysql';

-- BM25 ranking function
SELECT *, bm25(docs, 5.0, 1.0) AS score
FROM docs
WHERE docs MATCH 'database'
ORDER BY score;

-- Highlight matching text
SELECT highlight(docs, 0, '<b>', '</b>') AS title,
       snippet(docs, 1, '<b>', '</b>', '...', 20) AS body_snippet
FROM docs WHERE docs MATCH 'sqlite';

-- Tokenizer configuration
CREATE VIRTUAL TABLE docs2 USING fts5(
    content,
    tokenize = 'porter unicode61 remove_diacritics 2'
);

-- Trigram tokenizer for substring matching
CREATE VIRTUAL TABLE docs3 USING fts5(content, tokenize = 'trigram');
SELECT * FROM docs3 WHERE content MATCH 'qlite';  -- substring match
```

### JSON Functions

SQLite has comprehensive JSON support built in (enabled by default since 3.38.0):

```sql
-- Extract values
SELECT json_extract('{"name":"Alice","age":30}', '$.name');          -- 'Alice'
SELECT '{"name":"Alice"}' ->> '$.name';                              -- 'Alice' (shorthand)
SELECT '{"name":"Alice"}' -> '$.name';                               -- '"Alice"' (JSON string)

-- Modify JSON
SELECT json_set('{"a":1}', '$.b', 2);                               -- '{"a":1,"b":2}'
SELECT json_insert('{"a":1}', '$.b', 2);                            -- inserts only if missing
SELECT json_replace('{"a":1}', '$.a', 99);                          -- replaces only if exists
SELECT json_remove('{"a":1,"b":2}', '$.b');                         -- '{"a":1}'
SELECT json_patch('{"a":1}', '{"b":2}');                            -- '{"a":1,"b":2}'

-- JSON arrays
SELECT json_array(1, 2, 'three');                                    -- '[1,2,"three"]'
SELECT json_array_length('[1,2,3]');                                 -- 3
SELECT json_group_array(name) FROM users;                            -- aggregate to JSON array

-- JSON objects
SELECT json_object('name', 'Alice', 'age', 30);                     -- '{"name":"Alice","age":30}'
SELECT json_group_object(key, value) FROM kv;                        -- aggregate to JSON object

-- Iterate JSON arrays/objects
SELECT * FROM json_each('[1,2,3]');                                  -- returns key, value, type rows
SELECT * FROM json_tree('{"a":{"b":1}}');                            -- recursive traversal

-- JSONB (binary JSON, 3.45+) -- faster for repeated access
SELECT jsonb('{"name":"Alice"}');                                    -- binary representation
SELECT jsonb_extract(jsonb_col, '$.name') FROM t;                   -- extract from JSONB
SELECT * FROM jsonb_each(jsonb_col);                                 -- iterate JSONB (3.51+)
SELECT * FROM jsonb_tree(jsonb_col);                                 -- recursive JSONB (3.51+)

-- JSON validation
SELECT json_valid('{"a":1}');                                        -- 1 (valid)
SELECT json_valid('not json');                                       -- 0 (invalid)
SELECT json_type('{"a":1}', '$.a');                                  -- 'integer'
```

### Window Functions

SQLite supports all standard SQL window functions (since 3.25.0):

```sql
-- Row numbering
SELECT name, dept, salary,
       row_number() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn,
       rank() OVER (PARTITION BY dept ORDER BY salary DESC) AS rnk,
       dense_rank() OVER (PARTITION BY dept ORDER BY salary DESC) AS drnk,
       ntile(4) OVER (ORDER BY salary DESC) AS quartile
FROM employees;

-- Aggregate window functions
SELECT name, dept, salary,
       sum(salary) OVER (PARTITION BY dept) AS dept_total,
       avg(salary) OVER (PARTITION BY dept) AS dept_avg,
       count(*) OVER (PARTITION BY dept) AS dept_count,
       min(salary) OVER () AS global_min,
       max(salary) OVER () AS global_max
FROM employees;

-- Running totals and moving averages
SELECT date, amount,
       sum(amount) OVER (ORDER BY date) AS running_total,
       avg(amount) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7d
FROM transactions;

-- Lead/Lag for comparing rows
SELECT date, value,
       lag(value, 1) OVER (ORDER BY date) AS prev_value,
       lead(value, 1) OVER (ORDER BY date) AS next_value,
       value - lag(value, 1) OVER (ORDER BY date) AS change
FROM metrics;

-- First/Last/Nth value
SELECT name, dept, salary,
       first_value(name) OVER w AS highest_paid,
       last_value(name) OVER w AS lowest_paid,
       nth_value(name, 2) OVER w AS second_highest
FROM employees
WINDOW w AS (PARTITION BY dept ORDER BY salary DESC
             ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING);

-- Percent rank and cumulative distribution
SELECT name, salary,
       percent_rank() OVER (ORDER BY salary) AS pct_rank,
       cume_dist() OVER (ORDER BY salary) AS cume_dist
FROM employees;
```

### CTEs and Recursive Queries

```sql
-- Standard CTE
WITH recent_orders AS (
    SELECT * FROM orders WHERE order_date > date('now', '-30 days')
)
SELECT customer_id, count(*) AS cnt FROM recent_orders GROUP BY customer_id;

-- Multiple CTEs
WITH
  active AS (SELECT * FROM users WHERE active = 1),
  orders AS (SELECT * FROM orders WHERE created > date('now', '-90 days'))
SELECT a.name, count(o.id) FROM active a JOIN orders o ON a.id = o.user_id GROUP BY a.name;

-- Recursive CTE: hierarchical traversal
WITH RECURSIVE ancestors(id, name, parent_id, depth) AS (
    SELECT id, name, parent_id, 0 FROM categories WHERE id = 42
    UNION ALL
    SELECT c.id, c.name, c.parent_id, a.depth + 1
    FROM categories c JOIN ancestors a ON c.id = a.parent_id
)
SELECT * FROM ancestors;

-- Recursive CTE: generate a series
WITH RECURSIVE cnt(x) AS (
    SELECT 1
    UNION ALL
    SELECT x + 1 FROM cnt WHERE x < 100
)
SELECT x FROM cnt;

-- Recursive CTE: date series
WITH RECURSIVE dates(d) AS (
    SELECT date('2026-01-01')
    UNION ALL
    SELECT date(d, '+1 day') FROM dates WHERE d < '2026-12-31'
)
SELECT d FROM dates;
```

### STRICT Tables

STRICT tables enforce type checking at insertion time (since 3.37.0):

```sql
-- STRICT table: type enforcement
CREATE TABLE measurements (
    id INTEGER PRIMARY KEY,
    sensor_name TEXT NOT NULL,
    value REAL NOT NULL,
    reading_time TEXT NOT NULL,
    raw_data BLOB,
    flags ANY                    -- ANY type allows any value in STRICT mode
) STRICT;

-- Attempting to insert wrong types raises an error
INSERT INTO measurements (sensor_name, value, reading_time)
VALUES (123, 'not a number', 45.6);  -- ERROR: type mismatch

-- Allowed types in STRICT tables: INT, INTEGER, REAL, TEXT, BLOB, ANY
```

### Generated Columns

```sql
-- Stored generated column (computed at write time, stored on disk)
CREATE TABLE products (
    price REAL,
    quantity INTEGER,
    total REAL GENERATED ALWAYS AS (price * quantity) STORED
);

-- Virtual generated column (computed at read time, not stored)
CREATE TABLE people (
    first_name TEXT,
    last_name TEXT,
    full_name TEXT GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL
);

-- Generated columns can be indexed
CREATE INDEX idx_total ON products(total);
```

### RETURNING Clause

```sql
-- INSERT with RETURNING (since 3.35.0)
INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com')
RETURNING id, name, created_at;

-- UPDATE with RETURNING
UPDATE products SET price = price * 1.1 WHERE category = 'electronics'
RETURNING id, name, price AS new_price;

-- DELETE with RETURNING
DELETE FROM sessions WHERE expires < datetime('now')
RETURNING user_id, session_id;
```

### Virtual Tables

Virtual tables provide a powerful extension mechanism for querying non-SQLite data sources:

```sql
-- FTS5 (full-text search, detailed above)
CREATE VIRTUAL TABLE docs USING fts5(title, body);

-- R*Tree (spatial indexing for range queries)
CREATE VIRTUAL TABLE locations USING rtree(
    id,
    min_lat, max_lat,    -- latitude range
    min_lon, max_lon     -- longitude range
);
-- Spatial query: find all points within a bounding box
SELECT id FROM locations WHERE min_lat >= 40.0 AND max_lat <= 41.0
                           AND min_lon >= -74.0 AND max_lon <= -73.0;

-- CSV virtual table (query CSV files as tables)
CREATE VIRTUAL TABLE csv_data USING csv(filename='data.csv', header=yes);
SELECT * FROM csv_data WHERE column1 > 100;

-- dbstat virtual table (page-level storage analysis)
CREATE VIRTUAL TABLE IF NOT EXISTS temp.stat USING dbstat(main);
SELECT name, sum(pgsize) AS size FROM temp.stat GROUP BY name ORDER BY size DESC;

-- generate_series (built-in since 3.46.0)
SELECT value FROM generate_series(1, 100);
SELECT value FROM generate_series(1, 100, 5);  -- step by 5
```

### ATTACH DATABASE

```sql
-- Attach a second database
ATTACH DATABASE 'analytics.db' AS analytics;

-- Cross-database query
SELECT u.name, a.event_type, a.ts
FROM main.users u
JOIN analytics.events a ON u.id = a.user_id;

-- Cross-database INSERT
INSERT INTO analytics.summary
SELECT date, count(*) FROM main.events GROUP BY date;

-- List attached databases
PRAGMA database_list;

-- Detach
DETACH DATABASE analytics;
```

**Limitations:** Atomic transactions across attached databases require rollback journal mode (not WAL). In WAL mode, transactions are atomic per-database but not across databases.

### SQLite WASM

SQLite compiles to WebAssembly for browser and server-side JavaScript deployment:

```javascript
// Official npm package: @sqlite.org/sqlite-wasm
import sqlite3InitModule from '@sqlite.org/sqlite-wasm';

const sqlite3 = await sqlite3InitModule();
const db = new sqlite3.oo1.DB('/mydb.sqlite3', 'ct');

db.exec("CREATE TABLE IF NOT EXISTS t(a, b)");
db.exec("INSERT INTO t(a, b) VALUES (1, 'hello')");

const rows = [];
db.exec({
  sql: "SELECT * FROM t",
  rowMode: 'object',
  callback: (row) => rows.push(row)
});

db.close();
```

**Persistence options:**
- **Origin Private File System (OPFS):** Best performance, supported in Chrome, Firefox, Safari (2025+)
- **IndexedDB VFS:** Broader browser support, slower
- **In-memory only:** No persistence, fastest
- **OPFS via SAH Pool:** High-performance OPFS using SQLite Access Handle Pool VFS

### Ecosystem

**Litestream** (v0.5.0, Oct 2025) -- Streaming replication for SQLite:
- Continuously replicates WAL changes to S3, GCS, Azure Blob, SFTP, or local filesystem
- Near-zero RPO (recovery point objective) for disaster recovery
- VFS read replicas can query directly from object storage without local restore
- LTX format with hierarchical compaction for efficient storage

**rqlite** (v9.4.x) -- Fault-tolerant distributed SQLite:
- Uses Raft consensus for multi-node replication
- HTTP API for reads and writes
- Change Data Capture (CDC) for streaming changes to external systems
- Automatic leader election and failover
- Best for applications needing HA without complex infrastructure

**Turso / libSQL** -- SQLite fork and managed platform:
- libSQL: Open-contribution SQLite fork with embedded replicas, native vector search, WASM UDFs, and `BEGIN CONCURRENT` for multi-writer support
- Turso Database: SQLite-compatible database rewritten in Rust with native async, concurrent writes, and bi-directional sync
- Turso Cloud: Managed edge database service with copy-on-write branching

**Cloudflare D1** -- Managed SQLite at the edge:
- SQLite databases deployed to Cloudflare's edge network
- Automatic replication across regions
- Integrated with Cloudflare Workers

**SQLite tools:**
- `sqlite3` -- Command-line shell
- `sqlite3_analyzer` -- Page-level storage analysis
- `sqldiff` -- Database differencing tool
- `sqlite3_rsync` -- Efficient database synchronization (page-level rsync for SQLite)

## When to Use SQLite

**Good fit:**
- Mobile/desktop applications (single-user, local data)
- Embedded systems and IoT devices
- Application file format (replacing custom binary formats)
- Testing and prototyping (drop-in for development)
- Data analysis and ETL (local processing of datasets)
- Edge computing and WASM deployments
- Single-tenant web applications with moderate traffic
- Configuration and cache storage
- Temporary datasets and intermediate processing

**Poor fit:**
- High-concurrency multi-user write workloads
- Client-server deployments with many simultaneous writers
- Very large databases (>1TB, though SQLite supports up to 281TB theoretically)
- Applications requiring fine-grained access control / user authentication
- Network-accessible database service without a wrapper (rqlite, Turso fill this gap)
- Write-heavy workloads exceeding a single machine's I/O capacity

## Common Pitfalls

1. **Not enabling WAL mode** -- Default rollback journal blocks readers during writes. Always use `PRAGMA journal_mode = WAL` for concurrent read/write workloads.

2. **Not setting busy_timeout** -- Without a timeout, the second writer gets SQLITE_BUSY immediately. Set `PRAGMA busy_timeout = 5000` (or higher) in every connection.

3. **Not enabling foreign keys** -- Foreign key enforcement is OFF by default. Set `PRAGMA foreign_keys = ON` per connection.

4. **Using SQLite over a network filesystem** -- Network filesystems (NFS, SMB) often have broken locking semantics. SQLite databases should live on local storage.

5. **Not running PRAGMA optimize** -- Run `PRAGMA optimize` when closing long-lived connections or periodically in applications to keep query planner statistics current.

6. **Holding transactions open too long** -- Long write transactions in WAL mode prevent checkpointing and cause WAL file growth. Keep transactions short.

7. **Not using parameterized queries** -- String concatenation for SQL is an injection vector. Always use `?` or named `:param` placeholders.

8. **Ignoring STRICT tables** -- For data integrity, use `CREATE TABLE ... STRICT` to catch type errors at insert time rather than silently coercing values.

9. **Using multiple connections without WAL mode** -- Rollback journal mode serializes all access. If your application uses threads or multiple processes, enable WAL.

10. **Running VACUUM on a production database without planning** -- VACUUM rewrites the entire database, doubling disk space temporarily and taking exclusive lock. Consider `PRAGMA auto_vacuum = INCREMENTAL` with `PRAGMA incremental_vacuum` instead.

## Reference Files

Load these when you need deep knowledge for a specific area:

- `references/architecture.md` -- B-tree internals, page format, WAL implementation, locking protocol, type affinity system, query planner, extension architecture. Read for "how does SQLite work internally" questions.
- `references/diagnostics.md` -- 100+ diagnostic commands covering PRAGMA inspection, sqlite3 CLI commands, EXPLAIN QUERY PLAN analysis, performance profiling, storage analysis, FTS5 diagnostics, lock debugging, corruption detection, and tool usage. Read when troubleshooting or investigating database state.
- `references/best-practices.md` -- PRAGMA tuning recipes, WAL mode configuration, connection management, backup strategies, migration patterns, security hardening, schema design, and real-world troubleshooting playbooks for SQLITE_BUSY, corruption, WAL growth, and slow writes. Read for configuration and operational guidance.
