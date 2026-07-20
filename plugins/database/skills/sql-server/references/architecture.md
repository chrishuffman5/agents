# SQL Server Architecture Reference

## Storage Engine

### Pages and Extents

The fundamental unit of storage is the **page** (8 KB). All data, indexes, and internal structures are stored in pages.

| Page Type | Description |
|---|---|
| Data | Heap or clustered index leaf rows |
| Index | Nonclustered index rows |
| IAM | Index Allocation Map -- tracks which extents belong to an object |
| PFS | Page Free Space -- tracks allocation status and free space per page |
| GAM | Global Allocation Map -- tracks which extents are allocated |
| SGAM | Shared Global Allocation Map -- tracks mixed extents |
| Text/Image | LOB data stored off-row |

An **extent** is 8 contiguous pages (64 KB). Two types:
- **Uniform extent** -- All 8 pages belong to one object. Used once an object grows beyond 8 pages.
- **Mixed extent** -- Pages from multiple objects share the extent. Used for small objects.

### Filegroups

Filegroups are logical containers for data files:
- **PRIMARY** -- Required. Contains system tables and any objects not assigned elsewhere.
- **User-defined filegroups** -- Isolate tables/indexes for administration, backup, or I/O distribution.
- **FILESTREAM filegroup** -- Stores FILESTREAM BLOB data on the file system.
- **Memory-optimized filegroup** -- Required for In-Memory OLTP tables (2014+).

Best practice: Place large tables on separate filegroups to enable piecemeal restores and parallel I/O across disks.

### Heaps vs. Clustered Indexes

A **heap** is a table with no clustered index. Rows are stored in no particular order. The Row ID (RID) is the physical locator: file:page:slot.

A **clustered index** physically orders the table data by the index key. The leaf level IS the data. Only one per table. Choosing the right clustered index key is critical:
- **Narrow** -- Nonclustered indexes store the clustered key, so wide keys bloat every NC index.
- **Unique** -- If not unique, SQL Server adds a 4-byte uniquifier.
- **Static** -- Changing the key causes physical row movement and NC index updates.
- **Ever-increasing** -- IDENTITY or SEQUENCE avoids page splits and fragmentation.

### Row Structure

Each row contains:
- Status bits (4 bytes) -- null bitmap presence, row type
- Column offset -- length of fixed-length data portion
- Fixed-length columns -- stored in catalog order
- Null bitmap -- one bit per column indicating NULL
- Variable-length column count and offset array
- Variable-length columns -- stored in catalog order

Maximum row size: 8,060 bytes (page size minus overhead). Row-overflow pages handle varchar(max) and other large values.

## Buffer Pool

The buffer pool (buffer cache) is SQL Server's primary memory consumer. It caches data pages read from disk.

### How It Works

1. Query requests a page
2. Buffer manager checks if the page is already in the buffer pool
3. **Buffer pool hit** -- Return the in-memory page (fast)
4. **Buffer pool miss** -- Read the page from disk into a free buffer, then return it
5. Modified pages are marked **dirty** in the buffer pool
6. The **checkpoint** process writes dirty pages to disk periodically
7. The **lazy writer** evicts cold pages when memory pressure occurs

### Key Metrics

```sql
-- Buffer pool hit ratio (should be > 99% for OLTP)
SELECT
    (a.cntr_value * 1.0 / b.cntr_value) * 100.0 AS buffer_cache_hit_ratio
FROM sys.dm_os_performance_counters a
JOIN sys.dm_os_performance_counters b
    ON a.object_name = b.object_name
WHERE a.counter_name = 'Buffer cache hit ratio'
  AND b.counter_name = 'Buffer cache hit ratio base';

-- Page life expectancy (higher = less memory pressure)
SELECT cntr_value AS page_life_expectancy_seconds
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page life expectancy'
  AND object_name LIKE '%Buffer Manager%';

-- Buffer pool usage by database
SELECT DB_NAME(database_id) AS db_name,
       COUNT(*) * 8 / 1024 AS buffer_pool_mb
FROM sys.dm_os_buffer_descriptors
GROUP BY database_id
ORDER BY buffer_pool_mb DESC;
```

### Memory Architecture

SQL Server memory is organized into:

- **Buffer pool** -- Data and index page cache (largest consumer)
- **Plan cache** -- Compiled execution plans
- **Lock manager** -- Lock structures for concurrency control
- **Query workspace memory** -- Memory grants for sorts, hashes, and other operators
- **CLR** -- .NET runtime memory for CLR objects
- **Thread stacks** -- Worker thread memory (512 KB per thread on x64)
- **In-Memory OLTP** -- Memory-optimized table data

Configure with:
- `max server memory` -- Upper bound for buffer pool + plan cache + most allocations. Set to total RAM minus OS/other services (leave 4-8 GB for OS on dedicated servers).
- `min server memory` -- Minimum reservation. Prevents OS from reclaiming too much under pressure.

## tempdb

tempdb is recreated every time SQL Server starts. Used for:

- **Temporary tables** (`#local`, `##global`)
- **Table variables** (`@table`)
- **Sort and hash spills** -- When query memory grants are insufficient
- **Version store** -- Row versions for RCSI, snapshot isolation, online index operations, triggers, MARS
- **Internal objects** -- Worktables for cursors, spools, LOB operations

### tempdb Contention

Classic bottleneck: allocation page contention (PFS, GAM, SGAM). Symptoms: `PAGELATCH_UP` or `PAGELATCH_EX` waits on pages `2:1:1`, `2:1:2`, `2:1:3`.

**Mitigation:**
- Multiple equally-sized data files (1 per logical core, up to 8, then add in groups of 4 if contention persists)
- Trace flag 1118 (pre-2016) -- Force uniform extent allocation
- SQL Server 2016+: Uniform extent allocation is the default; also adds tempdb metadata optimization
- SQL Server 2019+: Memory-optimized tempdb metadata (system table optimization)

### Version Store Sizing

The version store grows when row versions are needed. Monitor:
```sql
SELECT * FROM sys.dm_tran_version_store_space_usage;  -- per-database (2017+)
SELECT * FROM sys.dm_db_file_space_usage;  -- tempdb file usage
```

Long-running transactions with RCSI or snapshot isolation can cause version store bloat.

## Transaction Log

Every database has exactly one transaction log. It records every modification for recovery.

### Write-Ahead Logging (WAL)

The core guarantee: no dirty page is written to disk until its log records are hardened to the transaction log. This ensures crash recovery can redo committed and undo uncommitted transactions.

### Log Structure

The log is circular. It is divided into **Virtual Log Files (VLFs)**:
- Too many VLFs (>1000) slows recovery and backup
- Too few VLFs means large chunks are active at once
- Control VLF count through initial size and growth increment

```sql
-- Check VLF count
DBCC LOGINFO;  -- row count = VLF count

-- Check log space usage
DBCC SQLPERF(LOGSPACE);
```

### Log Truncation

Log space is reused (truncated) when:
- **Simple recovery**: After each checkpoint
- **Full/Bulk-logged recovery**: After a log backup

If the log cannot truncate, it grows. Common reasons:
- `LOG_BACKUP` -- No log backups being taken (full recovery model)
- `ACTIVE_TRANSACTION` -- Long-running open transaction
- `REPLICATION` -- Log reader agent behind
- `AVAILABILITY_REPLICA` -- AG secondary behind on redo

```sql
SELECT name, log_reuse_wait_desc FROM sys.databases;
```

## Query Processing Pipeline

### Compilation and Optimization

1. **Parsing** -- T-SQL text is parsed into a parse tree. Syntax errors caught here.
2. **Binding** -- Names resolved to objects. Permissions checked. Algebrizer produces a query tree.
3. **Optimization** -- The query optimizer transforms the query tree into a physical execution plan:
   - **Trivial plan** -- Simple queries (single table, no joins) get a trivial plan without full optimization
   - **Full optimization** -- Multi-phase search with increasing plan space exploration
   - **Timeout** -- Optimizer has a budget based on estimated query cost. Complex queries may get "good enough" plans.
4. **Execution** -- The execution engine runs the physical plan using an iterator model (volcano/pull model).

### Plan Cache

Compiled plans are cached for reuse. Cache key includes:
- Query text (exact match, including whitespace and case)
- SET options (ANSI_NULLS, QUOTED_IDENTIFIER, etc.)
- Schema version
- Database context

Plan eviction: LRU-based under memory pressure. Plans with low reuse cost are evicted first.

```sql
-- Top cached plans by execution count
SELECT TOP 20
    cp.objtype, cp.usecounts, cp.size_in_bytes,
    qp.query_plan, qt.text
FROM sys.dm_exec_cached_plans cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) qt
ORDER BY cp.usecounts DESC;
```

### Execution Modes

- **Row mode** -- Traditional iterator model. Each operator processes one row at a time.
- **Batch mode** -- Processes ~900 rows at a time in columnar format. Originally columnstore-only, extended to rowstore in SQL Server 2019 (batch mode on rowstore).

Batch mode is significantly faster for analytical queries with aggregations, sorts, and window functions.

### Memory Grants

Operators like Sort, Hash Match, and Hash Join request memory grants before execution:
- Grant is estimated at compile time based on cardinality estimates
- Underestimate: operator spills to tempdb (slow)
- Overestimate: memory is reserved but unused (wasted, limits concurrency)

Monitor spills:
```sql
-- Recent spills from Query Store (2017+)
SELECT TOP 20
    qt.query_sql_text, rs.avg_tempdb_space_used,
    rs.max_tempdb_space_used, rs.count_executions
FROM sys.query_store_runtime_stats rs
JOIN sys.query_store_plan p ON rs.plan_id = p.plan_id
JOIN sys.query_store_query q ON p.query_id = q.query_id
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
WHERE rs.avg_tempdb_space_used > 0
ORDER BY rs.avg_tempdb_space_used DESC;
```

## Concurrency and Locking

### Lock Hierarchy

SQL Server uses hierarchical locking: Database > Table > Partition > Page > Row (or Key in indexes).

Lock modes:
- **S (Shared)** -- Read locks. Multiple readers can coexist.
- **X (Exclusive)** -- Write locks. Block all other access.
- **U (Update)** -- Prevents deadlocks in read-then-update patterns.
- **IS/IX/IU (Intent)** -- Signals intent at higher granularity levels.
- **Sch-S/Sch-M** -- Schema stability/modification locks.

### Lock Escalation

When a single transaction holds >5,000 locks on a single object, SQL Server escalates to a table lock. This can cause blocking. Control with:
```sql
ALTER TABLE dbo.MyTable SET (LOCK_ESCALATION = DISABLE);  -- prevent escalation
ALTER TABLE dbo.MyTable SET (LOCK_ESCALATION = AUTO);      -- escalate to partition first
```

### Isolation Levels

| Level | Dirty Reads | Non-Repeatable | Phantoms | Behavior |
|---|---|---|---|---|
| READ UNCOMMITTED | Yes | Yes | Yes | No shared locks taken |
| READ COMMITTED (default) | No | Yes | Yes | Shared locks released after read |
| READ COMMITTED SNAPSHOT | No | Yes | Yes | Row versioning; no reader-writer blocking |
| REPEATABLE READ | No | No | Yes | Shared locks held until end of transaction |
| SNAPSHOT | No | No | No | Row versioning; statement-level consistency |
| SERIALIZABLE | No | No | No | Range locks; highest isolation |

**Recommendation:** Enable `READ_COMMITTED_SNAPSHOT` for OLTP workloads. It eliminates reader-writer blocking without the data integrity risks of `NOLOCK`.
