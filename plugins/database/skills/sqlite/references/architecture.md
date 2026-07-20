# SQLite Architecture Reference

## Overview

SQLite is an in-process, serverless, zero-configuration, transactional SQL database engine. The entire engine compiles into a single C source file (the "amalgamation") of approximately 250,000 lines. It links directly into the host application -- there is no client-server protocol, no socket communication, no separate daemon process.

```
┌──────────────────────────────────────────────────────┐
│              Host Application Process                │
│  (C/C++, Python, Java, Node.js, Go, Rust, etc.)     │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │              SQLite Library                    │  │
│  │                                                │  │
│  │  ┌─────────────┐  ┌────────────────────────┐  │  │
│  │  │  Tokenizer   │  │  SQL Compiler           │  │  │
│  │  │  & Parser    │  │  (code generator)       │  │  │
│  │  └──────┬──────┘  └───────────┬────────────┘  │  │
│  │         │                     │                │  │
│  │  ┌──────▼─────────────────────▼────────────┐  │  │
│  │  │       Virtual Machine (VDBE)            │  │  │
│  │  │  (bytecode interpreter, ~170 opcodes)   │  │  │
│  │  └──────────────────┬──────────────────────┘  │  │
│  │                     │                          │  │
│  │  ┌──────────────────▼──────────────────────┐  │  │
│  │  │        B-tree Module                    │  │  │
│  │  │  (table B+ trees, index B-trees)        │  │  │
│  │  └──────────────────┬──────────────────────┘  │  │
│  │                     │                          │  │
│  │  ┌──────────────────▼──────────────────────┐  │  │
│  │  │        Pager / Page Cache               │  │  │
│  │  │  (transaction, locking, crash recovery)  │  │  │
│  │  └──────────────────┬──────────────────────┘  │  │
│  │                     │                          │  │
│  │  ┌──────────────────▼──────────────────────┐  │  │
│  │  │        OS Interface (VFS)               │  │  │
│  │  │  (file I/O, locking, shared memory)     │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│            Database File (single file)               │
│            WAL file (if WAL mode)                    │
│            SHM file (if WAL mode)                    │
└──────────────────────────────────────────────────────┘
```

## Module Architecture

### 1. Tokenizer and Parser

The tokenizer breaks SQL text into tokens. The parser (a Lemon-generated LALR(1) parser) converts tokens into a parse tree. Key behaviors:

- SQL keywords are case-insensitive
- Identifiers can be quoted with double-quotes, square brackets, or backticks
- String literals use single quotes only
- Comments: `--` for line comments, `/* */` for block comments
- The parser handles SQLite's extended syntax: UPSERT, RETURNING, window functions, CTEs, JSON operators

### 2. SQL Compiler / Code Generator

The code generator transforms the parse tree into bytecode for the Virtual Database Engine (VDBE). This phase includes:

- **Query planning** -- Chooses scan strategies (full table scan, index scan, covering index)
- **Join optimization** -- Reorders joins based on estimated cost using available statistics
- **WHERE clause analysis** -- Decomposes WHERE into terms and matches them against available indexes
- **Subquery flattening** -- Merges subqueries into the outer query when possible
- **Correlated subquery optimization** -- Converts correlated subqueries to joins when possible

### 3. Virtual Database Engine (VDBE)

The VDBE is a register-based virtual machine that executes compiled bytecode. Each SQL statement compiles to a VDBE program:

- Approximately 170 opcodes (Open, Column, MakeRecord, Insert, Delete, Seek, Next, etc.)
- Register-based architecture (not stack-based) for efficiency
- Each `sqlite3_stmt` object holds a compiled VDBE program
- `EXPLAIN` shows the VDBE bytecode; `EXPLAIN QUERY PLAN` shows the high-level query plan

```sql
-- View VDBE bytecode
EXPLAIN SELECT * FROM users WHERE id = 42;
-- Shows: addr, opcode, p1, p2, p3, p4, p5, comment

-- View query plan (more useful for optimization)
EXPLAIN QUERY PLAN SELECT * FROM users WHERE id = 42;
-- Shows: SEARCH users USING INTEGER PRIMARY KEY (rowid=?)
```

### 4. B-tree Module

SQLite uses two types of B-trees:

**Table B+ trees (for rowid tables):**
- Internal pages contain only rowid keys and child pointers
- Leaf pages contain the full row data (all columns serialized together)
- Rowid is a 64-bit signed integer, auto-assigned if not specified
- `INTEGER PRIMARY KEY` is an alias for the rowid (stored in-place, not as a separate column)

**Index B-trees (for indexes and WITHOUT ROWID tables):**
- Every page contains both keys and data
- Index entries contain the indexed column values plus the rowid
- WITHOUT ROWID tables store the entire row in the index B-tree, keyed by PRIMARY KEY

**Page structure within a B-tree page:**
```
┌────────────────────────────────────────────────────┐
│ Page Header (8-12 bytes)                           │
│   - Page type (leaf/interior, table/index)         │
│   - First free block offset                        │
│   - Number of cells                                │
│   - Offset to first byte of content area           │
│   - Number of fragmented free bytes                │
│   - Right-most child pointer (interior pages only) │
├────────────────────────────────────────────────────┤
│ Cell Pointer Array (2 bytes per cell)              │
│   - Sorted by key value                            │
│   - Points to cell content within the page         │
├────────────────────────────────────────────────────┤
│ Unallocated Space                                  │
├────────────────────────────────────────────────────┤
│ Cell Content Area (grows from bottom up)           │
│   - Each cell: payload size, rowid/key, data       │
│   - Overflow pointer if data exceeds page          │
└────────────────────────────────────────────────────┘
```

**Overflow pages:**
- When a single record exceeds the usable page space, data spills to overflow pages
- Overflow pages are linked via 4-byte pointers at the start of each overflow page
- The threshold depends on page size: approximately `(usable_size - 12) * 64/255 - 23` bytes fit on a leaf page before overflow

### 5. Pager / Page Cache

The pager manages reading/writing database pages, caching, transaction semantics, and crash recovery:

- **Page cache** -- LRU cache of database pages in memory; size controlled by `PRAGMA cache_size`
- **Memory-mapped I/O** -- Optional via `PRAGMA mmap_size`; maps pages directly from the file into process memory
- **Transaction management** -- Implements BEGIN/COMMIT/ROLLBACK using either rollback journal or WAL
- **Crash recovery** -- On startup, checks for hot journals/WAL and replays if needed
- **Locking** -- Acquires and releases file locks through the VFS

### 6. OS Interface (VFS)

The Virtual File System layer abstracts all OS interactions:

- **Default VFS:** `unix` on Linux/macOS, `win32` on Windows
- **File operations:** Open, close, read, write, truncate, sync, size, lock, unlock
- **Lock operations:** POSIX advisory locks (unix), LockFile/UnlockFile (win32)
- **Shared memory:** For WAL mode's shm file (mmap on unix, file mapping on win32)
- **Custom VFS:** Applications can register custom VFS implementations for encryption, compression, logging, or alternative storage backends

```c
// Register a custom VFS (C API)
sqlite3_vfs_register(&my_custom_vfs, 0);

// Open a database with a specific VFS
sqlite3_open_v2("database.db", &db, SQLITE_OPEN_READWRITE, "my_vfs_name");
```

## Database File Format

### File Header (first 100 bytes)

| Offset | Size | Description |
|---|---|---|
| 0 | 16 | Magic string: "SQLite format 3\000" |
| 16 | 2 | Page size (512-65536, or 1 for 65536) |
| 18 | 1 | File format write version (1=legacy, 2=WAL) |
| 19 | 1 | File format read version (1=legacy, 2=WAL) |
| 20 | 1 | Reserved space at end of each page |
| 24 | 4 | File change counter (incremented on each transaction) |
| 28 | 4 | Database size in pages |
| 32 | 4 | First freelist trunk page |
| 36 | 4 | Total freelist pages |
| 40 | 4 | Schema cookie (incremented on schema change) |
| 44 | 4 | Schema format number (currently 4) |
| 48 | 4 | Default page cache size |
| 52 | 4 | Largest root B-tree page for auto/incremental vacuum |
| 56 | 4 | Database text encoding (1=UTF8, 2=UTF16le, 3=UTF16be) |
| 60 | 4 | User version (PRAGMA user_version) |
| 64 | 4 | Incremental vacuum mode (non-zero = incremental) |
| 68 | 4 | Application ID (PRAGMA application_id) |
| 96 | 4 | Version-valid-for number |
| 100 | 4 | SQLite version number that wrote the database |

### Page Types

| Type | Code | Description |
|---|---|---|
| Interior table B-tree | 0x05 | Internal node of a rowid table |
| Leaf table B-tree | 0x0D | Leaf node of a rowid table (contains row data) |
| Interior index B-tree | 0x02 | Internal node of an index |
| Leaf index B-tree | 0x0A | Leaf node of an index |
| Freelist trunk | -- | Linked list of free page numbers |
| Freelist leaf | -- | Contains page numbers of free pages |
| Overflow | -- | Continuation of large records |
| Pointer map | -- | Used by auto-vacuum to track page ownership |

### Record Format

Each row is stored as a serialized record:

```
┌─────────────────────────────────────────┐
│ Header Size (varint)                    │
│ Column Type 1 (varint)                  │
│ Column Type 2 (varint)                  │
│ ...                                     │
│ Column Type N (varint)                  │
├─────────────────────────────────────────┤
│ Column Value 1                          │
│ Column Value 2                          │
│ ...                                     │
│ Column Value N                          │
└─────────────────────────────────────────┘
```

Column type codes:
| Code | Meaning | Size |
|---|---|---|
| 0 | NULL | 0 bytes |
| 1 | 8-bit signed integer | 1 byte |
| 2 | 16-bit signed big-endian integer | 2 bytes |
| 3 | 24-bit signed big-endian integer | 3 bytes |
| 4 | 32-bit signed big-endian integer | 4 bytes |
| 5 | 48-bit signed big-endian integer | 6 bytes |
| 6 | 64-bit signed big-endian integer | 8 bytes |
| 7 | IEEE 754 64-bit float | 8 bytes |
| 8 | Integer constant 0 | 0 bytes |
| 9 | Integer constant 1 | 0 bytes |
| N>=12, even | BLOB of (N-12)/2 bytes | (N-12)/2 bytes |
| N>=13, odd | TEXT of (N-13)/2 bytes | (N-13)/2 bytes |

## WAL Implementation Details

### WAL File Structure

```
┌───────────────────────────────┐
│ WAL Header (32 bytes)         │
│   Magic: 0x377f0682 (LE)     │
│      or  0x377f0683 (BE)     │
│   File format version         │
│   Database page size          │
│   Checkpoint sequence number  │
│   Salt-1, Salt-2              │
│   Checksum-1, Checksum-2     │
├───────────────────────────────┤
│ Frame 1 Header (24 bytes)    │
│   Page number                 │
│   Database size (pages)       │
│   Salt-1, Salt-2              │
│   Checksum-1, Checksum-2     │
│ Frame 1 Data (page_size)     │
├───────────────────────────────┤
│ Frame 2 Header               │
│ Frame 2 Data                  │
├───────────────────────────────┤
│ ...                           │
└───────────────────────────────┘
```

### WAL Index (SHM file)

The WAL index is a shared-memory region (memory-mapped from the `-shm` file) containing:

- **Hash tables** -- Map page numbers to frame numbers for fast lookup
- **WAL index header** -- Contains maximum frame number, checkpoint info, read marks
- **Read marks** -- Each reader records its "end mark" (last valid frame when the transaction started)
- **Write lock** -- Ensures single-writer semantics

### Checkpoint Process

A checkpoint copies committed frames from the WAL back into the main database:

1. Acquire the checkpoint lock
2. For each page in the WAL (from earliest to latest):
   a. Check if any active reader still needs this frame (via read marks)
   b. If no reader needs it, copy the page back to the main database
3. If all frames are transferred, reset the WAL (truncate or rewrite header)
4. Release the checkpoint lock

Checkpoint modes:
- **PASSIVE** -- Checkpoint as many frames as possible without blocking, skip frames needed by active readers
- **FULL** -- Wait for active readers to finish, then checkpoint all frames
- **RESTART** -- Like FULL, but also reset WAL file position to the beginning
- **TRUNCATE** -- Like RESTART, but truncate WAL file to zero bytes

### WAL vs Rollback Journal Comparison

| Aspect | Rollback Journal | WAL Mode |
|---|---|---|
| Journal file | `database-journal` | `database-wal` + `database-shm` |
| Write behavior | Copy original page to journal, then modify in-place | Append new page version to WAL |
| Read concurrency | Readers blocked during write | Readers not blocked by writers |
| Write concurrency | Single writer, blocks all readers | Single writer, does not block readers |
| Crash recovery | Replay journal to restore original pages | Replay WAL to reconstruct latest pages |
| Checkpoint | Not needed | Periodic (auto or manual) |
| Disk usage | Journal grows with transaction size | WAL grows continuously until checkpoint |
| Network FS | Works (with proper locking) | Does not work (requires shared memory) |
| Read-only media | Works | Does not work |

## Type Affinity System

SQLite uses type affinity rather than strict typing. Any column can hold any type of value (unless STRICT mode is used):

### Column Affinity Rules

The affinity of a column is determined by the declared type name in CREATE TABLE:

1. **INTEGER** affinity -- If the type contains "INT" (e.g., INT, INTEGER, SMALLINT, BIGINT, TINYINT)
2. **TEXT** affinity -- If the type contains "CHAR", "CLOB", or "TEXT" (e.g., VARCHAR(255), TEXT, NCHAR)
3. **BLOB** affinity -- If the type is "BLOB" or no type is specified
4. **REAL** affinity -- If the type contains "REAL", "FLOA", or "DOUB" (e.g., REAL, FLOAT, DOUBLE)
5. **NUMERIC** affinity -- Everything else (e.g., NUMERIC, DECIMAL, BOOLEAN, DATE, DATETIME)

### Type Coercion Rules

When storing a value, SQLite applies the column's affinity:
- **INTEGER affinity** -- Text that looks like an integer is stored as an integer
- **REAL affinity** -- Text that looks like a number is stored as a real
- **NUMERIC affinity** -- Text is stored as integer if possible, then real, then text
- **TEXT affinity** -- Everything is stored as text
- **BLOB affinity** -- No coercion, stored as-is

```sql
-- Demonstrate type affinity
CREATE TABLE demo(a INTEGER, b TEXT, c REAL, d BLOB, e NUMERIC);
INSERT INTO demo VALUES('123', 456, '78.9', x'ABCD', '100');
SELECT typeof(a), typeof(b), typeof(c), typeof(d), typeof(e) FROM demo;
-- Result: integer, text, real, blob, integer
```

## Query Planner

### Index Selection

The query planner estimates the cost of various strategies:

1. **Full table scan** -- Reads every row; cost proportional to table size
2. **Index scan** -- Uses an index to find matching rows, then looks up row data
3. **Covering index** -- Index contains all needed columns; no table lookup required
4. **Automatic index** -- SQLite may create a transient index for a query if the estimated cost is lower
5. **Bloom filter** -- For joins, SQLite may use a Bloom filter to pre-screen rows (3.38.0+)

### EXPLAIN QUERY PLAN Output

```sql
EXPLAIN QUERY PLAN SELECT * FROM orders WHERE customer_id = 42 ORDER BY order_date;
-- QUERY PLAN
-- |--SEARCH orders USING INDEX idx_customer (customer_id=?)
-- `--USE TEMP B-TREE FOR ORDER BY

-- Key terms:
-- SCAN = full table scan (no useful index)
-- SEARCH = index-assisted lookup
-- USING INDEX = which index is used
-- USING INTEGER PRIMARY KEY = rowid lookup (fastest)
-- USING COVERING INDEX = index-only scan (no table data page access)
-- USE TEMP B-TREE FOR ORDER BY = separate sort step needed
-- CO-ROUTINE = subquery materialized via coroutine
-- COMPOUND SUBQUERY = UNION/EXCEPT/INTERSECT intermediate
```

### Statistics and ANALYZE

The query planner uses statistics stored in the `sqlite_stat1`, `sqlite_stat3`, and `sqlite_stat4` tables:

```sql
-- Generate statistics for all tables and indexes
ANALYZE;

-- Generate statistics for a specific table
ANALYZE orders;

-- Limit rows sampled per index (faster ANALYZE on large tables)
PRAGMA analysis_limit = 1000;
ANALYZE;

-- Let SQLite decide which tables need fresh statistics
PRAGMA optimize;

-- View stored statistics
SELECT * FROM sqlite_stat1;  -- index name, table name, stat string
-- stat string format: "rows idx_rows" (e.g., "1000000 50" means 1M rows, 50 per index value)
```

## Extension Architecture

### Loadable Extensions

SQLite supports dynamically loaded extensions via shared libraries:

```sql
-- Load an extension (must be enabled first)
-- In C: sqlite3_enable_load_extension(db, 1);
-- In CLI:
.load ./my_extension

-- Common built-in extensions (compile-time flags):
-- SQLITE_ENABLE_FTS5        -- Full-text search 5
-- SQLITE_ENABLE_RTREE       -- R*Tree spatial index
-- SQLITE_ENABLE_JSON1       -- JSON functions (default ON since 3.38.0)
-- SQLITE_ENABLE_GEOPOLY     -- Geospatial polygon support
-- SQLITE_ENABLE_MATH_FUNCTIONS  -- Math functions (ceil, floor, ln, log, etc.)
-- SQLITE_ENABLE_DBSTAT_VTAB -- dbstat virtual table for storage analysis
-- SQLITE_ENABLE_STMTVTAB    -- Statement virtual table
-- SQLITE_ENABLE_CARRAY      -- C-array table-valued function (3.51.0+)
-- SQLITE_ENABLE_PERCENTILE  -- Percentile aggregate function (3.51.0+)
```

### Virtual Table Interface

The virtual table mechanism allows extensions to expose custom data sources as SQL tables:

```c
// A virtual table module defines these methods:
typedef struct sqlite3_module {
    int iVersion;
    int (*xCreate)(sqlite3*, void*, int, const char*const*, sqlite3_vtab**, char**);
    int (*xConnect)(sqlite3*, void*, int, const char*const*, sqlite3_vtab**, char**);
    int (*xBestIndex)(sqlite3_vtab*, sqlite3_index_info*);
    int (*xDisconnect)(sqlite3_vtab*);
    int (*xDestroy)(sqlite3_vtab*);
    int (*xOpen)(sqlite3_vtab*, sqlite3_vtab_cursor**);
    int (*xClose)(sqlite3_vtab_cursor*);
    int (*xFilter)(sqlite3_vtab_cursor*, int, const char*, int, sqlite3_value**);
    int (*xNext)(sqlite3_vtab_cursor*);
    int (*xEof)(sqlite3_vtab_cursor*);
    int (*xColumn)(sqlite3_vtab_cursor*, sqlite3_context*, int);
    int (*xRowid)(sqlite3_vtab_cursor*, sqlite3_int64*);
    // ... additional methods for write support, transactions, renaming
} sqlite3_module;
```

**xBestIndex** is the critical method: SQLite calls it during query planning to determine the best strategy for the virtual table. The virtual table reports estimated cost and indicates which WHERE clause terms it can handle.

### User-Defined Functions

```sql
-- In application code (Python example)
-- import sqlite3
-- conn = sqlite3.connect(':memory:')
-- conn.create_function('reverse', 1, lambda s: s[::-1] if s else None)
-- conn.execute("SELECT reverse('hello')")  -- returns 'olleh'

-- In application code (C API)
-- sqlite3_create_function(db, "my_func", nArg, SQLITE_UTF8, pCtx, xFunc, NULL, NULL);
-- sqlite3_create_function(db, "my_agg", nArg, SQLITE_UTF8, pCtx, NULL, xStep, xFinal);
```

## Threading Model

SQLite supports three threading modes (set at compile time or startup):

| Mode | Flag | Description |
|---|---|---|
| **Single-thread** | `SQLITE_CONFIG_SINGLETHREAD` | No mutexes; unsafe for multi-threaded use |
| **Multi-thread** | `SQLITE_CONFIG_MULTITHREAD` | Safe if each thread uses its own connection |
| **Serialized** | `SQLITE_CONFIG_SERIALIZED` | Safe for multiple threads sharing a connection (default) |

```sql
-- Check threading mode at runtime
PRAGMA compile_options;
-- Look for THREADSAFE=1 (serialized) or THREADSAFE=2 (multi-thread)

-- From C API:
-- int mode = sqlite3_threadsafe();
-- 0 = single-thread, 1 = serialized, 2 = multi-thread
```

**Best practice:** Use one connection per thread (multi-thread mode) rather than sharing connections with mutexes (serialized mode). The reduced lock contention significantly improves throughput.

## Schema Storage

All schema information is stored in the `sqlite_schema` table (also accessible as `sqlite_master`):

```sql
SELECT * FROM sqlite_schema;
-- type: 'table', 'index', 'view', 'trigger'
-- name: object name
-- tbl_name: associated table name
-- rootpage: root B-tree page number
-- sql: CREATE statement that defines the object
```

- Page 1 of the database always contains the root of the `sqlite_schema` table
- The schema cookie (offset 40 in the file header) is incremented on every schema change
- Each connection caches the parsed schema; if the cookie changes, the cache is invalidated and the schema is re-read

## Memory Management

SQLite uses pluggable memory allocators:

- **Default allocator** -- malloc/free
- **Memory pools** -- `SQLITE_CONFIG_PAGECACHE` for page cache, `SQLITE_CONFIG_SCRATCH` for scratch memory
- **Memsys5** -- A zero-fragmentation allocator for embedded systems with fixed memory pools
- **Memory tracking** -- `sqlite3_memory_used()` and `sqlite3_memory_highwater()` report usage

```sql
-- Current memory usage (from C API):
-- sqlite3_int64 used = sqlite3_memory_used();
-- sqlite3_int64 high = sqlite3_memory_highwater(0);

-- Set soft heap limit (advisory)
-- sqlite3_soft_heap_limit64(128 * 1024 * 1024);  -- 128MB

-- Set hard heap limit (3.31.0+)
-- sqlite3_hard_heap_limit64(256 * 1024 * 1024);  -- 256MB
```
