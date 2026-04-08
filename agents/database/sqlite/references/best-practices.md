# SQLite Best Practices Reference

## Essential PRAGMA Configuration

Every SQLite connection should set a standard set of PRAGMAs. These settings are per-connection and do not persist (except journal_mode and auto_vacuum):

### Recommended Production Configuration

```sql
-- WAL mode: enables concurrent reads + writes (persistent across connections)
PRAGMA journal_mode = WAL;

-- Synchronous NORMAL: safe with WAL, significantly faster than FULL
PRAGMA synchronous = NORMAL;

-- Busy timeout: wait up to 5 seconds instead of failing immediately on lock
PRAGMA busy_timeout = 5000;

-- Foreign keys: enforce referential integrity (OFF by default!)
PRAGMA foreign_keys = ON;

-- Page cache: set to ~64MB (negative value = KB)
PRAGMA cache_size = -64000;

-- Memory-mapped I/O: map up to 256MB for faster reads
PRAGMA mmap_size = 268435456;

-- Temp storage in memory: faster temp tables and sorts
PRAGMA temp_store = MEMORY;

-- Analysis limit: cap ANALYZE sampling for large tables
PRAGMA analysis_limit = 1000;
```

### Why Each PRAGMA Matters

| PRAGMA | Default | Recommended | Why |
|---|---|---|---|
| `journal_mode` | DELETE | WAL | Concurrent reads/writes, better performance |
| `synchronous` | FULL | NORMAL (with WAL) | FULL forces fsync on every commit; NORMAL is safe with WAL and 2-10x faster |
| `busy_timeout` | 0 | 5000+ | Without timeout, SQLITE_BUSY fails immediately on contention |
| `foreign_keys` | OFF | ON | Foreign keys are parsed but NOT enforced unless this is ON |
| `cache_size` | -2000 (2MB) | -64000 (64MB) | Larger cache reduces disk I/O for read-heavy workloads |
| `mmap_size` | 0 | 268435456 | Memory-mapped reads avoid read() system call overhead |
| `temp_store` | 0 (DEFAULT) | MEMORY | Avoids temp file I/O for sorts, joins, and temp tables |
| `analysis_limit` | 0 (unlimited) | 1000 | Prevents ANALYZE from scanning millions of rows per index |

### Read-Only Optimization Configuration

```sql
-- For read-only connections (analytics, reporting, backups)
PRAGMA journal_mode = WAL;
PRAGMA query_only = ON;          -- prevent accidental writes
PRAGMA cache_size = -128000;     -- 128MB cache for heavy reads
PRAGMA mmap_size = 1073741824;   -- 1GB memory-map
PRAGMA temp_store = MEMORY;
```

### Embedded/IoT Minimal Configuration

```sql
-- For memory-constrained environments
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 3000;
PRAGMA foreign_keys = ON;
PRAGMA cache_size = -2000;       -- keep default 2MB
PRAGMA mmap_size = 0;            -- disable mmap (reduces memory footprint)
PRAGMA temp_store = DEFAULT;     -- let SQLite decide
PRAGMA page_size = 4096;         -- match OS page size (set before creating tables)
```

## WAL Mode Configuration

### When to Use WAL Mode

**Use WAL mode when:**
- Application has concurrent readers and writers
- Read-heavy workload with occasional writes
- Web application with multiple request handlers
- Any multi-threaded or multi-process access pattern

**Use rollback journal when:**
- Database is on a network filesystem (NFS, SMB)
- Read-only database on read-only media
- Application requires atomic cross-database transactions (ATTACH)
- Single-process, single-thread, write-heavy workload

### WAL Mode Tuning

```sql
-- Set WAL mode (one-time, persistent)
PRAGMA journal_mode = WAL;

-- Auto-checkpoint: checkpoint after writing this many pages to WAL
PRAGMA wal_autocheckpoint = 1000;     -- default: 1000 pages (~4MB with 4096 page size)
-- Lower = more frequent checkpoints, smaller WAL, more I/O
-- Higher = less frequent checkpoints, larger WAL, fewer I/O interruptions
-- Set to 0 to disable auto-checkpoint (manual only)

-- Manual checkpoint strategies:
-- Passive: checkpoint without blocking (best for online systems)
PRAGMA wal_checkpoint(PASSIVE);

-- Truncate: checkpoint + truncate WAL to zero bytes (best for maintenance windows)
PRAGMA wal_checkpoint(TRUNCATE);

-- Synchronous NORMAL is safe with WAL (transactions survive power loss)
-- Synchronous OFF with WAL risks losing the last transaction on power failure (but not corruption)
PRAGMA synchronous = NORMAL;
```

### WAL Growth Prevention

If the WAL file grows unbounded:

1. **Check for long-running readers** -- A reader holds a snapshot, preventing checkpoint from recycling pages
2. **Check auto-checkpoint threshold** -- `PRAGMA wal_autocheckpoint` should be non-zero
3. **Force a checkpoint** -- `PRAGMA wal_checkpoint(TRUNCATE)`
4. **Application patterns** -- Ensure connections close promptly, transactions are short

```sql
-- Diagnose: check WAL size from application
-- Python: os.path.getsize('database.db-wal')
-- If WAL is several GB, a reader is preventing checkpointing

-- Fix: ensure all connections use short transactions
-- Fix: periodically run PRAGMA wal_checkpoint(PASSIVE) from a maintenance connection
-- Fix: close idle connections that might hold read snapshots
```

## Connection Management

### Connection Pool Strategy

SQLite does not have a built-in connection pool. Application-level pooling strategies:

**Single-writer, multiple-reader pattern (recommended for web apps):**

```python
# Python example with separate read/write connections
import sqlite3
import threading

# One persistent write connection
write_conn = sqlite3.connect('app.db', timeout=10)
write_conn.execute("PRAGMA journal_mode = WAL")
write_conn.execute("PRAGMA synchronous = NORMAL")
write_conn.execute("PRAGMA busy_timeout = 10000")
write_conn.execute("PRAGMA foreign_keys = ON")
write_lock = threading.Lock()

# Pool of read connections (one per thread)
thread_local = threading.local()

def get_read_connection():
    if not hasattr(thread_local, 'conn'):
        thread_local.conn = sqlite3.connect('app.db', timeout=5)
        thread_local.conn.execute("PRAGMA journal_mode = WAL")
        thread_local.conn.execute("PRAGMA query_only = ON")
        thread_local.conn.execute("PRAGMA mmap_size = 268435456")
        thread_local.conn.execute("PRAGMA cache_size = -64000")
    return thread_local.conn

def write(sql, params=None):
    with write_lock:
        write_conn.execute(sql, params or [])
        write_conn.commit()

def read(sql, params=None):
    conn = get_read_connection()
    return conn.execute(sql, params or []).fetchall()
```

**Key principles:**
- In WAL mode, multiple readers do not block each other or the writer
- Only one writer at a time; serialize writes with a lock or single connection
- Set `busy_timeout` on all connections to handle transient contention
- Use `BEGIN IMMEDIATE` for write transactions to fail fast on contention
- Close connections when no longer needed (prevents WAL growth from stale read snapshots)

### Connection Lifecycle

```python
# Best practice: configure PRAGMAs immediately after opening
import sqlite3

def create_connection(db_path, readonly=False):
    conn = sqlite3.connect(db_path, timeout=10)
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA synchronous = NORMAL")
    conn.execute("PRAGMA busy_timeout = 5000")
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA cache_size = -64000")
    conn.execute("PRAGMA temp_store = MEMORY")
    if readonly:
        conn.execute("PRAGMA query_only = ON")
        conn.execute("PRAGMA mmap_size = 268435456")
    return conn

# On close: run optimize to update statistics
def close_connection(conn):
    conn.execute("PRAGMA optimize")
    conn.close()
```

## Schema Design

### Use INTEGER PRIMARY KEY for Best Performance

```sql
-- INTEGER PRIMARY KEY is an alias for the rowid (stored inline, no extra index)
CREATE TABLE users (
    id INTEGER PRIMARY KEY,      -- this IS the rowid
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL
);

-- AUTOINCREMENT prevents rowid reuse (slightly slower, not usually needed)
CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    ts TEXT DEFAULT (datetime('now'))
);
-- Note: AUTOINCREMENT creates the sqlite_sequence table for tracking
-- Without AUTOINCREMENT, SQLite may reuse deleted rowids (usually fine)
```

### Use STRICT Tables for Data Integrity

```sql
-- STRICT tables enforce type checking at insertion time
CREATE TABLE measurements (
    id INTEGER PRIMARY KEY,
    sensor TEXT NOT NULL,
    value REAL NOT NULL,
    ts TEXT NOT NULL,         -- ISO 8601 datetime string
    metadata ANY             -- ANY allows any type in STRICT mode
) STRICT;

-- Allowed types in STRICT: INT, INTEGER, REAL, TEXT, BLOB, ANY
```

### Use WITHOUT ROWID for Narrow, Lookup-Heavy Tables

```sql
-- WITHOUT ROWID tables use a clustered index on the PRIMARY KEY
-- Best for: small rows, composite keys, lookup-heavy access patterns
CREATE TABLE session_kv (
    session_id TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT,
    PRIMARY KEY (session_id, key)
) WITHOUT ROWID;

-- NOT recommended for:
-- - Tables with large rows (causes B-tree bloat)
-- - Tables with single INTEGER PRIMARY KEY (rowid tables are already optimal)
-- - Tables that need rowid-based access
```

### Index Design Guidelines

```sql
-- Composite indexes: put equality columns first, range columns last
CREATE INDEX idx_orders_cust_date ON orders(customer_id, order_date);
-- Efficient for: WHERE customer_id = ? AND order_date > ?
-- Also efficient for: WHERE customer_id = ? (prefix match)
-- NOT efficient for: WHERE order_date > ? (no prefix match)

-- Covering indexes: include all selected columns to avoid table lookups
CREATE INDEX idx_orders_covering ON orders(customer_id, order_date, total, status);
-- SELECT total, status FROM orders WHERE customer_id = ? AND order_date > ?
-- Can be answered entirely from the index (no rowid lookup needed)

-- Partial indexes: index only a subset of rows
CREATE INDEX idx_active_users ON users(email) WHERE active = 1;
-- Only indexes rows where active = 1; smaller and faster

-- Expression indexes
CREATE INDEX idx_lower_email ON users(lower(email));
-- SELECT * FROM users WHERE lower(email) = 'alice@example.com';

-- UNIQUE indexes double as constraints
CREATE UNIQUE INDEX idx_users_email ON users(email);
```

### Date and Time Handling

SQLite has no native DATE/DATETIME type. Use one of these strategies:

```sql
-- Strategy 1: TEXT with ISO 8601 format (most common, human-readable)
CREATE TABLE events (
    id INTEGER PRIMARY KEY,
    name TEXT,
    start_time TEXT DEFAULT (datetime('now')),  -- '2026-04-07 12:00:00'
    end_time TEXT
);
-- Use date/time functions for comparisons:
SELECT * FROM events WHERE start_time > datetime('now', '-7 days');
SELECT * FROM events WHERE date(start_time) = '2026-04-07';

-- Strategy 2: INTEGER with Unix timestamp (compact, fast sorting)
CREATE TABLE logs (
    id INTEGER PRIMARY KEY,
    message TEXT,
    ts INTEGER DEFAULT (unixepoch())
);
-- Convert for display:
SELECT message, datetime(ts, 'unixepoch') FROM logs;

-- Strategy 3: REAL with Julian day number (highest precision)
CREATE TABLE science_data (
    id INTEGER PRIMARY KEY,
    measurement REAL,
    ts REAL DEFAULT (julianday('now'))
);
```

## Backup Strategies

### Online Backup API (Best Method)

```python
# Python: sqlite3 backup API (does not require stopping writes)
import sqlite3

source = sqlite3.connect('production.db')
dest = sqlite3.connect('backup.db')
source.backup(dest)
dest.close()
source.close()

# With progress callback
def progress(status, remaining, total):
    print(f'Copied {total - remaining}/{total} pages')

source.backup(dest, pages=100, progress=progress)
```

```sql
-- CLI: .backup command
.backup main backup.db

-- VACUUM INTO (creates a compacted copy, 3.27.0+)
VACUUM INTO 'backup.db';
```

### Litestream Configuration

```yaml
# /etc/litestream.yml
dbs:
  - path: /data/app.db
    replicas:
      - type: s3
        bucket: my-backup-bucket
        path: backups/app.db
        region: us-east-1
        retention: 720h          # 30 days
        sync-interval: 1s        # replicate every second

      - type: file
        path: /mnt/backup/app.db
```

```bash
# Start Litestream replication
litestream replicate

# Restore from backup
litestream restore -o /data/app.db s3://my-backup-bucket/backups/app.db

# Restore to a specific point in time
litestream restore -o /data/app.db -timestamp "2026-04-07T12:00:00Z" \
    s3://my-backup-bucket/backups/app.db
```

### sqlite3_rsync for Efficient Sync

```bash
# Synchronize local to remote (page-level, efficient)
sqlite3_rsync local.db user@remote:/path/to/remote.db

# Synchronize remote to local
sqlite3_rsync user@remote:/path/to/remote.db local.db

# Both databases can be in active use during sync
```

### Manual Backup with .dump

```bash
# Full SQL dump (portable, human-readable)
sqlite3 production.db ".dump" > backup.sql

# Restore from dump
sqlite3 restored.db < backup.sql

# Dump specific tables
sqlite3 production.db ".dump users orders" > partial_backup.sql
```

## Migration Patterns

### Schema Migrations with user_version

```sql
-- Check current version
PRAGMA user_version;

-- Apply migration (application code pattern)
-- if user_version == 0:
BEGIN;
CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE);
CREATE TABLE orders (id INTEGER PRIMARY KEY, user_id INTEGER REFERENCES users(id), total REAL);
PRAGMA user_version = 1;
COMMIT;

-- if user_version == 1:
BEGIN;
ALTER TABLE users ADD COLUMN created_at TEXT DEFAULT (datetime('now'));
CREATE INDEX idx_orders_user ON orders(user_id);
PRAGMA user_version = 2;
COMMIT;

-- if user_version == 2:
BEGIN;
CREATE TABLE audit_log (id INTEGER PRIMARY KEY, table_name TEXT, action TEXT, ts TEXT);
PRAGMA user_version = 3;
COMMIT;
```

### Safe ALTER TABLE Operations

SQLite supports limited ALTER TABLE:

```sql
-- Supported operations:
ALTER TABLE t RENAME TO new_name;
ALTER TABLE t RENAME COLUMN old_col TO new_col;
ALTER TABLE t ADD COLUMN new_col TEXT DEFAULT 'value';
ALTER TABLE t DROP COLUMN old_col;    -- 3.35.0+

-- NOT directly supported (requires table rebuild):
-- Changing column type
-- Adding NOT NULL to existing column
-- Changing PRIMARY KEY
-- Reordering columns

-- Table rebuild pattern for unsupported changes:
BEGIN;
CREATE TABLE new_t (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,    -- added NOT NULL
    value REAL             -- changed from TEXT to REAL
);
INSERT INTO new_t (id, name, value) SELECT id, name, CAST(value AS REAL) FROM old_t;
DROP TABLE old_t;
ALTER TABLE new_t RENAME TO old_t;
COMMIT;
```

## Security Hardening

### SQL Injection Prevention

```python
# ALWAYS use parameterized queries
cursor.execute("SELECT * FROM users WHERE email = ?", (email,))

# NEVER concatenate user input into SQL
# BAD: cursor.execute(f"SELECT * FROM users WHERE email = '{email}'")
# BAD: cursor.execute("SELECT * FROM users WHERE email = '%s'" % email)

# Named parameters
cursor.execute("SELECT * FROM users WHERE name = :name AND age > :min_age",
               {"name": "Alice", "min_age": 18})
```

### Authorization Callbacks

```c
// C API: set an authorizer callback to control SQL operations
int authorizer(void *pCtx, int actionCode, const char *p3, const char *p4,
               const char *p5, const char *p6) {
    switch (actionCode) {
        case SQLITE_DROP_TABLE:
            return SQLITE_DENY;    // prevent dropping tables
        case SQLITE_ATTACH:
            return SQLITE_DENY;    // prevent attaching databases
        case SQLITE_PRAGMA:
            if (strcmp(p3, "table_info") == 0) return SQLITE_OK;
            return SQLITE_DENY;    // restrict PRAGMA access
        default:
            return SQLITE_OK;
    }
}
sqlite3_set_authorizer(db, authorizer, NULL);
```

### Database Encryption

SQLite does not include built-in encryption. Third-party solutions:

- **SQLCipher** -- Open-source, AES-256-CBC encryption (most widely used)
- **SQLite3MultipleCiphers** -- Supports multiple encryption schemes (ChaCha20, AES-128/256, RC4)
- **wxSQLite3** -- Encryption extension with multiple cipher options
- **SEE (SQLite Encryption Extension)** -- Official commercial extension from the SQLite developers

```python
# SQLCipher example (Python via pysqlcipher3)
import pysqlcipher3.dbapi2 as sqlcipher

conn = sqlcipher.connect('encrypted.db')
conn.execute("PRAGMA key = 'my-secret-key'")
conn.execute("PRAGMA cipher_compatibility = 4")
conn.execute("CREATE TABLE IF NOT EXISTS secrets (id INTEGER PRIMARY KEY, data TEXT)")
```

### File Permissions

```bash
# Set restrictive permissions on database files
chmod 600 database.db
chmod 600 database.db-wal
chmod 600 database.db-shm

# For web applications, ensure the web server user owns the files
chown www-data:www-data database.db database.db-wal database.db-shm

# The DIRECTORY containing the database must also be writable
# (SQLite creates journal/WAL files in the same directory)
chmod 700 /path/to/db/directory
```

## Performance Optimization Patterns

### Bulk Insert Optimization

```sql
-- Slow: individual inserts with auto-commit
INSERT INTO t VALUES (1, 'a');  -- each is its own transaction
INSERT INTO t VALUES (2, 'b');
INSERT INTO t VALUES (3, 'c');

-- Fast: batch inserts in a single transaction (100x+ faster)
BEGIN;
INSERT INTO t VALUES (1, 'a');
INSERT INTO t VALUES (2, 'b');
INSERT INTO t VALUES (3, 'c');
-- ... thousands more ...
COMMIT;

-- Fastest: prepared statement + transaction (from application code)
-- Python:
-- conn.executemany("INSERT INTO t VALUES (?, ?)", data_list)
-- conn.commit()

-- For initial bulk loads, temporarily optimize:
PRAGMA journal_mode = OFF;       -- no crash recovery (data loss on crash!)
PRAGMA synchronous = OFF;        -- no fsync (data loss on power failure!)
PRAGMA cache_size = -256000;     -- 256MB cache
BEGIN;
-- ... mass inserts ...
COMMIT;
PRAGMA journal_mode = WAL;       -- restore WAL mode
PRAGMA synchronous = NORMAL;     -- restore safe sync
```

### Query Optimization Tips

```sql
-- 1. Use EXISTS instead of IN for subqueries on large tables
-- Slow:
SELECT * FROM orders WHERE customer_id IN (SELECT id FROM customers WHERE active = 1);
-- Fast:
SELECT * FROM orders o WHERE EXISTS (SELECT 1 FROM customers c WHERE c.id = o.customer_id AND c.active = 1);

-- 2. Use UNION ALL instead of UNION when duplicates are impossible
SELECT id FROM table_a WHERE x = 1
UNION ALL
SELECT id FROM table_b WHERE x = 1;

-- 3. Limit early in CTEs
WITH recent AS (
    SELECT * FROM events WHERE ts > datetime('now', '-1 hour') LIMIT 1000
)
SELECT * FROM recent WHERE type = 'error';

-- 4. Use covering indexes to avoid table lookups
CREATE INDEX idx_cover ON orders(customer_id, status, total);
SELECT status, total FROM orders WHERE customer_id = 42;
-- SEARCH USING COVERING INDEX (no rowid lookup)

-- 5. Avoid functions on indexed columns in WHERE
-- Bad (can't use index):
SELECT * FROM users WHERE lower(email) = 'alice@example.com';
-- Good (expression index):
CREATE INDEX idx_lower_email ON users(lower(email));
SELECT * FROM users WHERE lower(email) = 'alice@example.com';

-- 6. Use BETWEEN for range queries
SELECT * FROM orders WHERE order_date BETWEEN '2026-01-01' AND '2026-03-31';

-- 7. Avoid SELECT * when only specific columns are needed
SELECT id, name FROM users WHERE active = 1;
-- Narrower result = less I/O, potential covering index

-- 8. Use EXPLAIN QUERY PLAN to verify index usage
EXPLAIN QUERY PLAN SELECT * FROM orders WHERE customer_id = 42;
-- Should show SEARCH ... USING INDEX, not SCAN
```

### VACUUM Best Practices

```sql
-- When to VACUUM:
-- 1. After deleting a large fraction of data (>50%)
-- 2. Database file is much larger than expected
-- 3. Fragmentation is causing slow sequential scans
-- 4. After schema changes (ALTER TABLE, DROP TABLE)

-- Regular VACUUM alternatives:
-- Option A: auto_vacuum = INCREMENTAL (set on empty database)
PRAGMA auto_vacuum = INCREMENTAL;
-- Then periodically:
PRAGMA incremental_vacuum(1000);  -- reclaim up to 1000 pages

-- Option B: VACUUM INTO for non-disruptive compaction
VACUUM INTO '/tmp/compacted.db';
-- Then atomically replace the original (requires brief exclusive lock)

-- VACUUM considerations:
-- - Requires ~2x disk space temporarily
-- - Holds exclusive lock for the entire duration
-- - Can take minutes to hours on very large databases
-- - Resets auto_vacuum setting (must be re-set if changed)
-- - With WAL mode, VACUUM is a single large write transaction
```

## Troubleshooting Playbooks

### Playbook: SQLITE_BUSY Errors

**Symptoms:** Application receives error code 5 (SQLITE_BUSY) or "database is locked" messages.

**Diagnosis:**
```sql
-- 1. Check busy timeout
PRAGMA busy_timeout;
-- If 0, set it: PRAGMA busy_timeout = 5000;

-- 2. Check journal mode
PRAGMA journal_mode;
-- If DELETE/TRUNCATE, switch to WAL for better concurrency

-- 3. Look for long-running transactions in application logs
-- A read transaction in WAL mode holds a snapshot; a write transaction holds RESERVED lock

-- 4. Check for multiple writers
-- SQLite allows only ONE writer at a time, even in WAL mode
-- If SQLITE_BUSY occurs after busy_timeout expires, writes are genuinely contended
```

**Resolution:**
1. Set `PRAGMA busy_timeout = 5000` on every connection
2. Switch to WAL mode: `PRAGMA journal_mode = WAL`
3. Use `BEGIN IMMEDIATE` for write transactions (fail fast instead of mid-transaction)
4. Keep write transactions as short as possible (< 100ms ideal)
5. Serialize writes through a single connection or write queue
6. Close idle connections promptly (stale read snapshots block checkpointing)

### Playbook: Database Corruption

**Symptoms:** PRAGMA integrity_check reports errors, queries return unexpected results, "database disk image is malformed" errors.

**Diagnosis:**
```sql
-- 1. Run integrity check
PRAGMA integrity_check;

-- 2. Check for hardware issues
-- - Disk errors: check dmesg/syslog for I/O errors
-- - File system corruption: run fsck
-- - NFS/network storage: SQLite should NOT be used over network filesystems

-- 3. Check for incomplete WAL recovery
-- Look for stale -wal and -shm files
-- Opening the database triggers automatic recovery

-- 4. Check for concurrent access violations
-- Are multiple processes writing without WAL mode?
-- Is locking working correctly on this filesystem?
```

**Recovery:**
```bash
# Method 1: .recover (most resilient, salvages data from corrupt pages)
sqlite3 corrupt.db ".recover" | sqlite3 recovered.db

# Method 2: .dump (works if schema is intact)
sqlite3 corrupt.db ".dump" | sqlite3 recovered.db

# Method 3: Copy accessible tables manually
sqlite3 corrupt.db "SELECT * FROM users" | sqlite3 recovered.db ".import /dev/stdin users"

# Method 4: Restore from backup
cp backup.db production.db

# After recovery: verify
sqlite3 recovered.db "PRAGMA integrity_check"
sqlite3 recovered.db "PRAGMA foreign_key_check"
```

**Prevention:**
- Use WAL mode with `synchronous = NORMAL` (minimum for crash safety)
- Never use `synchronous = OFF` in production
- Never put SQLite databases on network filesystems
- Use Litestream or sqlite3_rsync for continuous backup
- Set `PRAGMA journal_mode = WAL` before any writes

### Playbook: WAL File Growing Unbounded

**Symptoms:** The `-wal` file grows to hundreds of MB or GB, consuming disk space.

**Diagnosis:**
```bash
# Check WAL file size
ls -la database.db-wal

# Check if checkpointing is happening
sqlite3 database.db "PRAGMA wal_checkpoint;"
# Returns: busy, log, checkpointed
# If log >> checkpointed, checkpoint cannot complete
```

**Root causes:**
1. **Long-running read transaction** -- A reader holds a snapshot, preventing the checkpoint from recycling those WAL frames
2. **Auto-checkpoint disabled** -- `PRAGMA wal_autocheckpoint = 0`
3. **No connections closing** -- Read connections kept open indefinitely
4. **Checkpoint contention** -- Checkpoint cannot acquire needed locks

**Resolution:**
```sql
-- 1. Check and set auto-checkpoint
PRAGMA wal_autocheckpoint;        -- should be non-zero (default 1000)
PRAGMA wal_autocheckpoint = 1000; -- re-enable if disabled

-- 2. Force a truncating checkpoint
PRAGMA wal_checkpoint(TRUNCATE);

-- 3. If TRUNCATE returns busy > 0, close idle connections first
-- Application must close connections holding read snapshots

-- 4. Use exclusive locking mode temporarily to force checkpoint
PRAGMA locking_mode = EXCLUSIVE;
PRAGMA wal_checkpoint(TRUNCATE);
PRAGMA locking_mode = NORMAL;
```

### Playbook: Slow Write Performance

**Symptoms:** Write operations (INSERT, UPDATE, DELETE) take much longer than expected.

**Diagnosis:**
```sql
-- 1. Check synchronous mode
PRAGMA synchronous;
-- FULL (2) forces fsync on every commit; switch to NORMAL (1) with WAL

-- 2. Check if writes are auto-committing (each write = separate transaction)
-- Batch writes in explicit transactions: BEGIN; ... COMMIT;

-- 3. Check journal mode
PRAGMA journal_mode;
-- DELETE mode is slower than WAL for most workloads

-- 4. Check for excessive indexing
SELECT name, sql FROM sqlite_schema WHERE type = 'index';
-- Each index slows down writes proportionally

-- 5. Check for triggers
SELECT name, sql FROM sqlite_schema WHERE type = 'trigger';
-- Triggers run on every affected row

-- 6. Profile the write operation
.timer on
BEGIN;
INSERT INTO t VALUES (1, 'test');
COMMIT;
-- Most of the time is in COMMIT (fsync)
```

**Resolution:**
1. Batch writes in transactions (100x+ improvement)
2. Switch to WAL mode with `synchronous = NORMAL`
3. Drop unnecessary indexes during bulk loads, rebuild after
4. Increase `cache_size` to reduce disk I/O during writes
5. Use `INSERT OR REPLACE` or `UPSERT` instead of SELECT-then-INSERT patterns
6. Consider `PRAGMA synchronous = OFF` only for initial bulk loads (not production)

### Playbook: Slow Read Performance

**Symptoms:** SELECT queries take longer than expected.

**Diagnosis:**
```sql
-- 1. Check query plan
EXPLAIN QUERY PLAN <your_query>;
-- Look for SCAN (full table scan) on large tables

-- 2. Check if statistics are current
SELECT * FROM sqlite_stat1;
-- Empty = no statistics; run ANALYZE

-- 3. Check cache hit rate
.stats on
<your_query>
-- Look for: Page cache hits, Page cache misses
-- Low hit rate = cache too small or workload exceeds cache

-- 4. Check for automatic indexes
.stats on
<your_query>
-- Look for "Autoindex" count > 0
-- Autoindex = SQLite is building a temp index each query; add a permanent one
```

**Resolution:**
1. Add appropriate indexes (see EXPLAIN QUERY PLAN output for guidance)
2. Run `ANALYZE` to update query planner statistics
3. Increase `cache_size` for larger working sets
4. Enable `mmap_size` for read-heavy workloads
5. Use covering indexes to eliminate table lookups
6. Ensure WAL mode is enabled (prevents reader-writer blocking)
7. Consider `VACUUM` if database is highly fragmented

### Playbook: Database Locked in Web Application

**Symptoms:** Web requests intermittently fail with "database is locked" even with busy_timeout set.

**Diagnosis:**
```python
# 1. Verify PRAGMAs are set on EVERY connection
# busy_timeout must be set per-connection, not just once

# 2. Check for connection leaks
# Unclosed connections hold locks indefinitely
# Use context managers: with sqlite3.connect('db.db') as conn:

# 3. Check for interleaved read-write on same connection
# In WAL mode, a connection that starts reading, then tries to write,
# can deadlock with another connection doing the reverse

# 4. Check for EXCLUSIVE locking mode
# PRAGMA locking_mode; should be NORMAL, not EXCLUSIVE
```

**Resolution:**
1. Set PRAGMAs on every connection open (use a factory function)
2. Use WAL mode on every connection
3. Use `BEGIN IMMEDIATE` for all write transactions
4. Implement a write queue or single-writer connection pattern
5. Use connection pooling with proper lifecycle management
6. Set generous busy_timeout (5-30 seconds for web apps)
7. Ensure database file is on local storage (not NFS/SMB)

## Application Integration Patterns

### Python (sqlite3 module)

```python
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), 'app.db')

def get_connection(readonly=False):
    uri = f'file:{DB_PATH}?mode=ro' if readonly else f'file:{DB_PATH}'
    conn = sqlite3.connect(uri, uri=True, timeout=10,
                           detect_types=sqlite3.PARSE_DECLTYPES)
    conn.row_factory = sqlite3.Row  # dict-like row access
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA synchronous = NORMAL")
    conn.execute("PRAGMA busy_timeout = 5000")
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA cache_size = -64000")
    conn.execute("PRAGMA temp_store = MEMORY")
    return conn

# Context manager pattern
with get_connection() as conn:
    conn.execute("INSERT INTO users (name) VALUES (?)", ("Alice",))
    # auto-commits on exit, auto-rollbacks on exception

# Close with optimize
conn = get_connection()
try:
    # ... use connection ...
    pass
finally:
    conn.execute("PRAGMA optimize")
    conn.close()
```

### Node.js (better-sqlite3)

```javascript
const Database = require('better-sqlite3');

const db = new Database('app.db', { readonly: false });
db.pragma('journal_mode = WAL');
db.pragma('synchronous = NORMAL');
db.pragma('busy_timeout = 5000');
db.pragma('foreign_keys = ON');
db.pragma('cache_size = -64000');
db.pragma('temp_store = MEMORY');

// Prepared statements (faster for repeated queries)
const insert = db.prepare('INSERT INTO users (name, email) VALUES (?, ?)');
const getByEmail = db.prepare('SELECT * FROM users WHERE email = ?');

// Transaction helper
const insertMany = db.transaction((users) => {
    for (const user of users) {
        insert.run(user.name, user.email);
    }
});

insertMany([
    { name: 'Alice', email: 'alice@example.com' },
    { name: 'Bob', email: 'bob@example.com' },
]);

// On shutdown
db.pragma('optimize');
db.close();
```

### Go (modernc.org/sqlite or mattn/go-sqlite3)

```go
import (
    "database/sql"
    _ "github.com/mattn/go-sqlite3"
)

func openDB(path string) (*sql.DB, error) {
    db, err := sql.Open("sqlite3", path+"?_journal_mode=WAL&_synchronous=NORMAL&_busy_timeout=5000&_foreign_keys=ON&cache=shared")
    if err != nil {
        return nil, err
    }
    db.SetMaxOpenConns(1) // single writer
    db.SetMaxIdleConns(10)
    return db, nil
}
```

### Rust (rusqlite)

```rust
use rusqlite::{Connection, OpenFlags, params};

fn open_db(path: &str) -> rusqlite::Result<Connection> {
    let conn = Connection::open_with_flags(path, OpenFlags::SQLITE_OPEN_READ_WRITE | OpenFlags::SQLITE_OPEN_CREATE)?;
    conn.execute_batch("
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        PRAGMA busy_timeout = 5000;
        PRAGMA foreign_keys = ON;
        PRAGMA cache_size = -64000;
        PRAGMA temp_store = MEMORY;
    ")?;
    Ok(conn)
}
```

## Deployment Patterns

### Single-Tenant Web Application

SQLite is a viable database for single-tenant web applications with moderate traffic:

- Use WAL mode with a single-writer connection
- Pool read connections (one per thread/worker)
- Set generous busy_timeout (10-30 seconds)
- Use Litestream for continuous backup to S3/GCS
- Deploy database file on fast local SSD (NVMe preferred)
- Monitor WAL file size; set up periodic checkpoint via cron or background task

### Edge/CDN Deployment

- Deploy SQLite databases at edge locations (Cloudflare D1, Fly.io, Turso)
- Use read replicas via Litestream VFS for read-heavy workloads
- Keep databases small (<100MB) for fast edge replication
- Use libSQL for embedded replicas with sync from primary

### Mobile/Desktop Application

- Use WAL mode for responsive UI (reads don't block on writes)
- Set `PRAGMA secure_delete = ON` for privacy-sensitive data
- Use `PRAGMA application_id` and `PRAGMA user_version` for file format versioning
- Implement schema migrations via user_version checks on startup
- Consider SQLCipher for encrypted local databases

### CI/CD and Testing

- Use in-memory databases (`:memory:`) for fast test execution
- Use `ATTACH DATABASE ':memory:' AS test_db` for isolated test schemas
- Pre-populate test databases with `VACUUM INTO` from a template
- SQLite's zero-config nature makes it ideal for test environments
