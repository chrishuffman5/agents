# Oracle Database Architecture Reference

## Memory Architecture

### SGA (System Global Area)

The SGA is a shared memory region allocated at instance startup. All server and background processes access it.

**Buffer Cache**
- Caches data blocks read from datafiles in memory
- Uses LRU (touch-count based) algorithm with hot/cold lists
- Multiple buffer pools: DEFAULT, KEEP (`DB_KEEP_CACHE_SIZE`), RECYCLE (`DB_RECYCLE_CACHE_SIZE`)
- Multiple block sizes: standard (`DB_BLOCK_SIZE`), non-standard (2K, 4K, 8K, 16K, 32K via `DB_nK_CACHE_SIZE`)
- Monitor: `V$BH`, `V$BUFFER_POOL_STATISTICS`, `V$DB_CACHE_ADVICE`

**Shared Pool**
- **Library Cache**: Parsed SQL/PL/SQL, execution plans, dependency tracking
- **Dictionary Cache** (Row Cache): Data dictionary metadata (table/column definitions, privileges)
- **Result Cache**: Query and PL/SQL function results (`DBMS_RESULT_CACHE`, `RESULT_CACHE_MAX_SIZE`)
- **Reserved area**: `SHARED_POOL_RESERVED_SIZE` for large allocations (avoids ORA-04031)
- Monitor: `V$SGASTAT`, `V$SHARED_POOL_ADVICE`, `V$LIBRARYCACHE`, `V$ROWCACHE`

**Redo Log Buffer**
- Circular buffer for redo entries before LGWR writes to online redo logs
- `LOG_BUFFER` parameter (typically 1MB-256MB)
- LGWR flushes on commit, every 3 seconds, at 1/3 full, or at 1MB
- Monitor: `V$SYSSTAT` (`redo log space requests`, `redo buffer allocation retries`)

**Large Pool**
- Optional; used by RMAN backup/restore, shared server (UGA), parallel execution message buffers
- `LARGE_POOL_SIZE` — not managed by LRU, avoids shared pool contention
- Monitor: `V$SGASTAT` filtered by `pool = 'large pool'`

**Java Pool**
- Memory for Java classes, Aurora JVM session state
- `JAVA_POOL_SIZE` — only needed if using Java stored procedures
- Monitor: `V$SGASTAT` filtered by `pool = 'java pool'`

**Streams Pool**
- Used by Oracle Streams, Advanced Queuing, XStream, GoldenGate integrated capture
- `STREAMS_POOL_SIZE` — auto-allocated from shared pool if not set
- Monitor: `V$SGASTAT` filtered by `pool = 'streams pool'`

**Vector Memory Pool (23ai+)**
- In-memory storage for HNSW vector indexes used by AI Vector Search
- `VECTOR_MEMORY_SIZE` — must be explicitly sized; not auto-managed
- Allocated from SGA; requires careful capacity planning based on vector dimensions and row counts
- Monitor: `V$VECTOR_MEMORY_POOL`

### PGA (Program Global Area)

Private memory for each server process. NOT shared.

- **Sort Area**: In-memory sorts (spills to temp tablespace if exceeded)
- **Hash Join Area**: Hash tables for hash joins
- **Bitmap Merge Area**: Bitmap index operations
- **Session Memory**: Variables, cursors, bind values (UGA for shared server moves to SGA)
- Auto-managed via `WORKAREA_SIZE_POLICY = AUTO` (default)
- `PGA_AGGREGATE_TARGET`: Advisory target for total PGA
- `PGA_AGGREGATE_LIMIT`: Hard limit (12c+); ORA-04036 if exceeded
- Monitor: `V$PGA_TARGET_ADVICE`, `V$PROCESS` (PGA_USED_MEM, PGA_ALLOC_MEM, PGA_MAX_MEM), `V$PGASTAT`

## Background Processes

### Mandatory Processes

| Process | Full Name | Function |
|---|---|---|
| LGWR | Log Writer | Writes redo log buffer to online redo log files. Triggered by commit, 3-second timeout, 1/3 full, or 1MB threshold. |
| DBWn | Database Writer | Writes dirty buffers from buffer cache to datafiles. Triggered by checkpoint, dirty buffer threshold, no free buffers, tablespace operations. Multiple writers: DBW0-DBW9, BW10-BW99. |
| CKPT | Checkpoint | Updates datafile headers and control file with checkpoint info. Signals DBWn during full/incremental checkpoints. |
| SMON | System Monitor | Instance recovery at startup (roll forward redo, roll back uncommitted). Coalesces free extents in dictionary-managed tablespaces. Cleans temp segments. |
| PMON | Process Monitor | Detects terminated user processes, rolls back uncommitted transactions, releases locks and resources. Registers instance with listener (pre-12c). |
| RECO | Recoverer | Resolves in-doubt distributed transactions (two-phase commit failures). |

### Optional / Conditional Processes

| Process | Full Name | Function |
|---|---|---|
| ARCn | Archiver | Copies filled online redo logs to archive destinations. Active only in ARCHIVELOG mode. Multiple archivers: ARC0-ARC9, ARCa-ARCt. |
| MMON | Manageability Monitor | Collects AWR snapshots, generates metric alerts, spawns MMNL for ASH flushing. |
| MMAN | Memory Manager | Auto-tunes SGA components under ASMM (`SGA_TARGET`) or AMM (`MEMORY_TARGET`). Adjusts component sizes based on workload. |
| LREG | Listener Registration | Registers instance and service information with the Oracle Net listener (12c+, replaces PMON's registration role). |
| CJQ0 | Job Queue Coordinator | Monitors `DBA_SCHEDULER_JOBS` and `DBMS_JOB` entries. Spawns Jnnn slave processes to execute jobs. |
| DBRM | Database Resource Manager | Enforces resource plans (CPU, I/O, parallel execution limits) per consumer group. |
| SMCO | Space Management Coordinator | Coordinates space management tasks: auto-extend, proactive space allocation. Spawns Wnnn slave processes. |
| VKTM | Virtual Keeper of Time | Provides wall-clock time and reference-time for internal timing. |

## Storage Architecture

### Logical Structure

```
Database
 └── Tablespace (logical container, one or more datafiles)
      └── Segment (table, index, undo, temp, LOB)
           └── Extent (contiguous group of data blocks)
                └── Data Block (smallest I/O unit, default 8KB)
```

- **Tablespaces**: SYSTEM, SYSAUX, UNDOTBS, TEMP, USERS (default); create additional for application data
- **Segments**: Each table/index/LOB is a segment; partitioned objects have one segment per partition
- **Extents**: Auto-allocated by default (`AUTOALLOCATE`); uniform extent sizes optional
- **Data Blocks**: `DB_BLOCK_SIZE` (2K, 4K, 8K, 16K, 32K); 8K default and recommended for OLTP

### Physical Structure

| File Type | Purpose |
|---|---|
| Datafiles (`.dbf`) | Store segment data; belong to exactly one tablespace |
| Online Redo Logs | Record all changes for recovery; minimum 2 groups, 2 members each recommended |
| Control Files | Metadata about database structure; multiplex to 3+ locations |
| Archive Logs | Copies of filled redo logs for point-in-time recovery |
| Parameter File (`spfile`) | Binary server parameter file; `ALTER SYSTEM` persists changes |
| Password File (`orapwd`) | Authentication for SYSDBA/SYSOPER remote connections |
| Alert Log | Instance messages, errors, startup/shutdown events |
| Trace Files | Diagnostic dumps per process in ADR (`V$DIAG_INFO`) |

### ASM (Automatic Storage Management)

ASM is Oracle's volume manager and filesystem, purpose-built for Oracle Database files.

**Disk Groups**
- Collection of ASM disks managed as a unit
- Redundancy: EXTERNAL (no mirroring), NORMAL (2-way), HIGH (3-way), FLEX (file-level control)
- `CREATE DISKGROUP data NORMAL REDUNDANCY DISK '/dev/sd*' FAILGROUP fg1 DISK ...`

**Allocation Units (AU)**
- Minimum allocation: default 4MB, configurable (1MB, 2MB, 4MB, 8MB, 16MB, 32MB, 64MB)
- Larger AU sizes improve sequential I/O for data warehousing
- Variable extent sizes: 1 AU (0-20K extents), 4 AU (20K-40K), 16 AU (40K+)

**Failure Groups**
- Mirroring boundary — each mirror copy placed in a different failure group
- Map to physical isolation (controllers, shelves, racks)

**Key Views**: `V$ASM_DISK`, `V$ASM_DISKGROUP`, `V$ASM_FILE`, `V$ASM_OPERATION`
**Utility**: `ASMCMD` (command-line), `ASMCA` (GUI configuration assistant)
