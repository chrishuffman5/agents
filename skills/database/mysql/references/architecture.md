# InnoDB Architecture Reference

## Buffer Pool

The buffer pool is InnoDB's main memory area for caching table data and index pages.

### LRU with Midpoint Insertion

InnoDB uses a modified LRU (Least Recently Used) algorithm:

- The list is divided into a "young" sublist (head, ~5/8) and an "old" sublist (tail, ~3/8)
- New pages are inserted at the midpoint (head of the old sublist), NOT at the head of the entire list
- A page in the old sublist is promoted to the young sublist only if it is accessed again after `innodb_old_blocks_time` milliseconds (default 1000ms)
- This prevents full table scans and one-time bulk reads from evicting frequently accessed pages

### Buffer Pool Instances

- Controlled by `innodb_buffer_pool_instances` (default 8 when buffer pool >= 1GB)
- Each instance has its own LRU list, free list, flush list, and mutex
- Reduces contention on the buffer pool mutex under concurrent workloads
- Total buffer pool size is divided evenly across instances

### Chunk Size

- `innodb_buffer_pool_chunk_size` (default 128MB) determines the granularity of online resizing
- Buffer pool size must be a multiple of `chunk_size * instances`
- MySQL adjusts the actual size to meet this requirement

### Preflushing and Page Cleaner

- Background page cleaner threads (`innodb_page_cleaners`, default 4) flush dirty pages from the buffer pool to disk
- Adaptive flushing monitors the redo log fill rate and increases flushing speed when the log is filling up
- `innodb_io_capacity` and `innodb_io_capacity_max` control the IOPS budget for flushing
- `innodb_max_dirty_pages_pct` (default 90) and `innodb_max_dirty_pages_pct_lwm` (default 10) trigger preflushing when dirty page ratio exceeds the low-water mark

## Redo Log (Write-Ahead Log)

The redo log ensures durability. Every modification to a data page is first recorded in the redo log. After a crash, InnoDB replays the redo log to recover committed transactions.

### WAL Protocol

1. Transaction modifies a page in the buffer pool (dirty page)
2. The modification is recorded as a redo log record in the log buffer (`innodb_log_buffer_size`, default 16MB)
3. On commit (with `innodb_flush_log_at_trx_commit=1`), the log buffer is flushed to the redo log files on disk
4. The dirty page is flushed to the tablespace later by the page cleaner

### Redo Log Capacity

- **8.0.30+:** `innodb_redo_log_capacity` (single variable, replaces the pair below). Redo log files are auto-managed in `#innodb_redo/` directory.
- **Pre-8.0.30:** `innodb_log_file_size` * `innodb_log_files_in_group` determines total redo log space. Requires restart to change.

### Log Sequence Number (LSN)

- The LSN is a monotonically increasing counter tracking the byte offset in the redo log
- Key LSN values from `SHOW ENGINE INNODB STATUS`:
  - `Log sequence number` -- current LSN (latest write)
  - `Log flushed up to` -- how far the log has been flushed to disk
  - `Pages flushed up to` -- how far data pages have been flushed
  - `Last checkpoint at` -- LSN of last checkpoint
- The gap between `Log sequence number` and `Last checkpoint at` represents the redo log space in use; if it approaches capacity, InnoDB forces aggressive flushing

### Flush Modes

`innodb_flush_log_at_trx_commit`:
- `1` -- Flush and sync to disk on every commit (full ACID, default)
- `2` -- Write to OS buffer on every commit, sync once per second (fast, survives mysqld crash, risks OS crash)
- `0` -- Write and sync once per second (fastest, risks 1 second of data on any crash)

### Lock-Free Redo Log (8.0)

MySQL 8.0 redesigned the redo log subsystem to be lock-free:
- Multiple user threads can write to the log buffer concurrently without acquiring a mutex
- A dedicated log writer thread handles flushing
- Significant throughput improvement under high-concurrency write workloads

## Undo Log

The undo log stores old versions of rows for MVCC (Multi-Version Concurrency Control) and transaction rollback.

### MVCC

- When a transaction modifies a row, the old version is written to the undo log
- Readers see the appropriate old version based on their transaction's read view (snapshot)
- This allows consistent reads without locking (REPEATABLE READ and READ COMMITTED isolation)

### Undo Tablespaces

- Default: 2 undo tablespaces (`innodb_undo_001`, `innodb_undo_002`)
- Additional undo tablespaces can be created: `CREATE UNDO TABLESPACE ts_name ADD DATAFILE 'file.ibu'`
- Minimum 2 undo tablespaces required for automatic truncation

### Purge and Truncation

- The purge system runs in background threads (`innodb_purge_threads`, default 4)
- Purge removes undo log records that are no longer needed by any active transaction
- Undo tablespace truncation (`innodb_undo_log_truncate=ON`, default ON) reclaims disk space when an undo tablespace exceeds `innodb_max_undo_log_size` (default 1GB)

**Key implication:** Long-running transactions prevent purge from reclaiming undo space, leading to undo tablespace growth and history list length increase. Monitor `History list length` in `SHOW ENGINE INNODB STATUS`.

## Doublewrite Buffer

The doublewrite buffer protects against partial (torn) page writes during a crash.

- InnoDB pages are 16KB but OS filesystem writes may not be atomic at 16KB
- Before writing a page to its tablespace, InnoDB writes it to the doublewrite buffer (a contiguous area on disk)
- If a crash occurs during the tablespace write, InnoDB recovers the intact copy from the doublewrite buffer
- **8.0.20+:** Doublewrite buffer moved to separate files (`#ib_16384_0.dblwr`, `#ib_16384_1.dblwr`)
- **SSD with atomic writes:** Can be safely disabled (`innodb_doublewrite=0`) if the storage guarantees atomic 16KB writes

## Change Buffer

The change buffer caches modifications to secondary index pages that are not currently in the buffer pool.

- Applies to INSERT, UPDATE, DELETE operations on non-unique secondary indexes
- Changes are merged when the affected page is later read into the buffer pool, or by a background merge thread
- Reduces random I/O for write-heavy workloads with many secondary indexes
- Controlled by `innodb_change_buffer_max_size` (default 25, percentage of buffer pool)
- Can be disabled (`innodb_change_buffering=none`) for read-heavy workloads where the overhead is not beneficial

## Adaptive Hash Index (AHI)

InnoDB monitors index searches and automatically builds a hash index on frequently accessed index pages.

- Provides O(1) lookups for equality searches on hot pages
- Maintained automatically; no DDL required
- Partitioned into `innodb_adaptive_hash_index_parts` (default 8) to reduce contention
- Can cause contention under certain workloads (visible as `btr_search` latch waits in `SHOW ENGINE INNODB STATUS`)
- Disable with `innodb_adaptive_hash_index=0` if AHI latch contention is observed

## Tablespace Types

| Tablespace | Purpose | Files |
|---|---|---|
| **System tablespace** | InnoDB data dictionary (pre-8.0), doublewrite buffer (pre-8.0.20), change buffer, undo logs (if not separate) | `ibdata1` |
| **File-per-table** | Each InnoDB table in its own file. Default (`innodb_file_per_table=ON`) | `schema/table.ibd` |
| **General tablespace** | User-created shared tablespace for multiple tables | `CREATE TABLESPACE ts ADD DATAFILE 'ts.ibd'` |
| **Undo tablespace** | Dedicated undo logs | `innodb_undo_001`, `innodb_undo_002` |
| **Temporary tablespace** | Session and global temporary tables, sort/join temp data | `ibtmp1` (global), `#innodb_temp/` (session) |
| **Redo log files** | Write-ahead log for crash recovery | `#innodb_redo/` (8.0.30+) or `ib_logfile0`, `ib_logfile1` |

### File-Per-Table Advantages

- Individual tables can be truncated or dropped to reclaim disk space immediately
- Tables can be moved between storage devices
- `OPTIMIZE TABLE` rebuilds the table and releases unused space
- Enables transportable tablespaces (`ALTER TABLE t DISCARD TABLESPACE` / `IMPORT TABLESPACE`)

### System Tablespace Considerations

- `ibdata1` only grows, never shrinks (unless you rebuild)
- Keep the system tablespace small by using file-per-table and separate undo tablespaces
- In pre-8.0, the system tablespace contained the data dictionary; 8.0+ uses a transactional data dictionary in `.sdi` files within tablespaces

## InnoDB Row Format

| Format | Description | Use Case |
|---|---|---|
| **DYNAMIC** (default) | Long columns (BLOB, TEXT, large VARCHAR) stored off-page. Prefix not stored inline. | General purpose (default since 5.7.9) |
| **COMPACT** | Similar to DYNAMIC but stores 768-byte prefix of long columns inline | Legacy; avoid for new tables |
| **REDUNDANT** | Oldest format; stores more metadata per row | Legacy compatibility only |
| **COMPRESSED** | Compresses data and index pages | Rarely used; prefer page compression or application-level compression |

## Clustered Index

Every InnoDB table has a clustered index:

1. If a PRIMARY KEY is defined, it is the clustered index
2. If no PRIMARY KEY, the first UNIQUE NOT NULL index is used
3. If neither exists, InnoDB generates a hidden 6-byte row ID (`GEN_CLUST_INDEX`)

**Implications:**
- Table data is physically ordered by the clustered index key
- Secondary indexes carry the primary key value (not a row pointer) to locate the full row
- A large primary key (e.g., UUID) inflates every secondary index
- Sequential primary keys (auto-increment, ordered UUIDs) avoid page splits and fragmentation
