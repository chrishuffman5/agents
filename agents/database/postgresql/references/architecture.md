# PostgreSQL Architecture Reference

## Process Architecture

PostgreSQL uses a multi-process architecture (not multi-threaded). Every component runs as a separate OS process.

### Postmaster (postgres)

The postmaster is the supervisor process:
- Listens on the configured TCP port (default 5432) and Unix domain socket
- Forks a new **backend process** for each client connection
- Manages shared memory initialization at startup
- Restarts background processes if they crash
- Handles graceful shutdown (SIGTERM), fast shutdown (SIGINT), and immediate shutdown (SIGQUIT)

```
postmaster (PID 1)
├── backend (PID 100)      -- client connection 1
├── backend (PID 101)      -- client connection 2
├── background writer
├── checkpointer
├── WAL writer
├── autovacuum launcher
│   ├── autovacuum worker (PID 200) -- vacuuming table X
│   └── autovacuum worker (PID 201) -- vacuuming table Y
├── WAL sender (PID 300)   -- streaming replication
├── WAL receiver           -- on standby only
├── logical replication launcher
│   └── logical replication worker
├── stats collector (pre-15) / stats activity (15+)
└── archiver               -- if archive_mode = on
```

### Backend Processes

Each client connection gets a dedicated backend process:
- Parses, plans, and executes SQL statements
- Has its own private memory area (work_mem, temp_buffers, maintenance_work_mem)
- Communicates with other backends via shared memory and semaphores
- Terminates when the client disconnects

**Memory per backend:**
- Stack size: ~8MB default
- work_mem: allocated per sort/hash operation (can be multiple per query)
- temp_buffers: for temporary table access
- Total per-connection overhead: typically 5-15MB baseline

### Background Workers

| Process | Purpose | Key Behavior |
|---|---|---|
| **Background Writer** | Writes dirty buffers from shared_buffers to disk | Runs continuously; reduces checkpoint I/O spikes |
| **Checkpointer** | Performs checkpoints (full flush of dirty buffers) | Triggered by time (checkpoint_timeout) or WAL volume (max_wal_size) |
| **WAL Writer** | Flushes WAL buffers to disk | Runs every wal_writer_delay (200ms default) |
| **Autovacuum Launcher** | Spawns autovacuum workers as needed | Checks every autovacuum_naptime (1min default) |
| **Stats Collector** | Collects activity statistics | Pre-15: separate process with UDP. 15+: shared memory based |
| **Archiver** | Archives completed WAL segments | Calls archive_command or archive_library for each segment |
| **WAL Sender** | Sends WAL to standby servers | One per replication connection |
| **WAL Receiver** | Receives WAL from primary (standby only) | Writes received WAL to standby's pg_wal |
| **Logical Replication Worker** | Applies logical changes from publisher | One per subscription |

## Shared Memory

Shared memory is allocated at server startup and shared by all processes.

### shared_buffers

The main buffer cache. PostgreSQL pages (8KB default) are cached here:
- Default: 128MB (far too low for production)
- Recommendation: 25% of total RAM (but rarely > 8-16GB due to double-caching with OS page cache)
- Uses a clock-sweep eviction algorithm
- Buffer pins prevent eviction of in-use pages
- The OS page cache acts as a second-level cache (effective_cache_size hints at this)

**Buffer management flow:**
```
Query needs page 42 of table T
  → Check shared_buffers hash table
    → HIT: pin buffer, read data
    → MISS: request page from OS
      → OS page cache HIT: fast read
      → OS page cache MISS: disk I/O
        → Load page into shared_buffers (evict a victim if needed)
```

### WAL Buffers

- Size controlled by `wal_buffers` (default: -1, auto-sized to 1/32 of shared_buffers, max 16MB)
- WAL records are written here before flushing to disk
- Flushed on commit (synchronous_commit = on) or by WAL writer

### Other Shared Memory Areas

| Area | Purpose |
|---|---|
| **Lock table** | Tracks all heavyweight locks (row, table, advisory) |
| **Proc array** | Array of PGPROC structures for all backends (transaction status, PID) |
| **CLOG (pg_xact)** | Transaction commit status (committed, aborted, in-progress, sub-committed) |
| **Subtransaction data** | SUBTRANS mapping for savepoints |
| **Notify queue** | LISTEN/NOTIFY message queue |
| **Predicate lock table** | Serializable Snapshot Isolation (SSI) predicate locks |
| **Stats area (15+)** | Shared memory statistics (replaces stats collector process) |

## Storage Architecture

### Heap Files

Tables are stored as heap files in `$PGDATA/base/{dboid}/{relfilenode}`:
- Each file is divided into 8KB **pages** (blocks)
- Files are segmented at 1GB boundaries (relfilenode, relfilenode.1, relfilenode.2, ...)
- Each page contains:
  - **Page header** (24 bytes): LSN, checksum, flags, free space pointers
  - **Item pointers** (line pointers): 4-byte offsets pointing to tuples within the page
  - **Tuples**: actual row data with header (xmin, xmax, ctid, infomask, null bitmap)
  - **Special area**: index-specific data (for index pages)

```
Page Layout (8192 bytes):
┌─────────────────────────────┐
│ Page Header (24 bytes)      │
├─────────────────────────────┤
│ Item Pointer 1 → ──────────│──→ Tuple 1
│ Item Pointer 2 → ──────────│──→ Tuple 2
│ Item Pointer 3 → ──────────│──→ Tuple 3
│ ...                         │
├─────────────────────────────┤
│ Free Space                  │
├─────────────────────────────┤
│ Tuple 3                     │
│ Tuple 2                     │
│ Tuple 1                     │
├─────────────────────────────┤
│ Special (0 bytes for heap)  │
└─────────────────────────────┘
```

### Tuple Header

Each tuple carries a 23-byte header (plus null bitmap):

| Field | Size | Purpose |
|---|---|---|
| t_xmin | 4 bytes | Transaction ID that inserted this tuple |
| t_xmax | 4 bytes | Transaction ID that deleted/updated this tuple (0 if alive) |
| t_cid | 4 bytes | Command ID within the transaction |
| t_ctid | 6 bytes | Current tuple ID (self-referencing if latest; points to update chain if not) |
| t_infomask2 | 2 bytes | Number of attributes + flags |
| t_infomask | 2 bytes | Visibility flags (HEAP_XMIN_COMMITTED, HEAP_XMAX_INVALID, etc.) |
| t_hoff | 1 byte | Offset to tuple data |
| Null bitmap | variable | 1 bit per column (only if tuple has nullable columns) |

### HOT (Heap-Only Tuples)

When an UPDATE does not modify any indexed column and the new tuple fits on the same page:
- The new tuple is a HOT tuple (no index entry needed)
- The old tuple's ctid points to the new tuple (forming a chain)
- Micro-vacuum can prune HOT chains without full VACUUM
- HOT significantly reduces index bloat for UPDATE-heavy tables with stable indexed columns

### TOAST (The Oversized-Attribute Storage Technique)

For values exceeding ~2KB (1/4 of page size):
1. **Compression** (PGLZ or LZ4 in PG 14+): attempted first
2. **Out-of-line storage**: if still too large, value is chunked and stored in a separate TOAST table
3. Each main table with TOAST-able columns has an associated `pg_toast.pg_toast_{oid}` table

TOAST strategies per column:
- **PLAIN**: no TOAST (for fixed-size types like integer)
- **EXTENDED**: compress then out-of-line if needed (default for text, bytea, jsonb)
- **EXTERNAL**: out-of-line without compression (faster for already-compressed data)
- **MAIN**: compress only, avoid out-of-line (may still out-of-line if necessary)

### Free Space Map (FSM)

- Tracks available space in each page
- Stored in `{relfilenode}_fsm`
- Used by INSERT to find pages with enough space for new tuples
- Updated by VACUUM
- Binary tree structure: each leaf stores the max free space in a page

### Visibility Map (VM)

- Two bits per page:
  - **All-visible**: all tuples on the page are visible to all transactions (VACUUM can skip)
  - **All-frozen**: all tuples are frozen (neither VACUUM nor anti-wraparound vacuum needs to visit)
- Stored in `{relfilenode}_vm`
- Critical for index-only scans (can skip heap fetch for all-visible pages)
- Updated by VACUUM

## WAL Internals

### WAL Record Structure

Each WAL record contains:
- **Resource manager ID**: identifies the subsystem (heap, btree, xact, etc.)
- **Record type**: specific operation (INSERT, UPDATE, DELETE, COMMIT)
- **LSN** (Log Sequence Number): unique position in the WAL stream
- **Before/after images**: data needed to redo the operation

### WAL Segment Files

- Stored in `$PGDATA/pg_wal/`
- Default segment size: 16MB (configurable at initdb with --wal-segsize)
- Named as 24-character hex strings: `{timeline}{segment_high}{segment_low}`
- Recycled after checkpoint (renamed rather than deleted)

### Full-Page Writes

After a checkpoint, the first modification to any page writes the **entire page** to WAL (full-page image / FPI):
- Prevents torn-page problems (partial write during OS crash)
- Controlled by `full_page_writes` (should always be ON)
- Causes WAL volume spike immediately after checkpoint
- `wal_compression` (PG 15+: LZ4/zstd) reduces FPI size significantly

## Checkpoint Mechanism

Checkpoints ensure all dirty buffers are flushed to disk, creating a known-good recovery point:

### Checkpoint Process

1. Write all dirty buffers in shared_buffers to their data files
2. Flush all data files to durable storage (fsync)
3. Write a checkpoint record to WAL
4. Remove/recycle old WAL segments no longer needed for recovery
5. Update `pg_control` with the new checkpoint location

### Checkpoint Tuning

```
checkpoint_timeout = 15min           -- max time between checkpoints (default 5min)
max_wal_size = 4GB                   -- WAL volume that triggers checkpoint (default 1GB)
checkpoint_completion_target = 0.9   -- spread writes over 90% of the interval
min_wal_size = 1GB                   -- minimum WAL to retain (avoid segment recycling churn)
```

**Tuning goal:** Checkpoints should be triggered by timeout, not WAL volume. If `pg_stat_bgwriter.checkpoints_req` (requested/forced checkpoints) is high relative to `checkpoints_timed`, increase `max_wal_size`.

### Recovery

On crash recovery:
1. Read `pg_control` to find the last checkpoint
2. Replay WAL from that checkpoint's REDO point forward
3. All committed transactions are restored; uncommitted transactions are rolled back
4. Time proportional to WAL generated since last checkpoint

## Transaction ID (XID) Management

- XIDs are 32-bit unsigned integers (about 4 billion values)
- XIDs wrap around: PostgreSQL must "freeze" old tuples (replace xmin with FrozenTransactionId) before wraparound
- `autovacuum_freeze_max_age` (default 200M): triggers aggressive anti-wraparound vacuum
- `vacuum_freeze_min_age` (default 50M): minimum XID age before freezing
- Monitor `age(datfrozenxid)` per database -- must stay well below 2 billion

```sql
-- Check XID age per database
SELECT datname, age(datfrozenxid) AS xid_age,
       datfrozenxid
FROM pg_database
ORDER BY xid_age DESC;

-- Check per table
SELECT schemaname, relname, age(relfrozenxid) AS xid_age
FROM pg_stat_user_tables
ORDER BY xid_age DESC
LIMIT 20;
```

**Critical alert:** If `age(datfrozenxid)` approaches 1 billion, you have a wraparound emergency. The database will shut down to prevent data corruption when it reaches 2 billion.
