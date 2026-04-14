---
name: database-oracle
description: |
  Oracle Database technology expert covering architecture, administration, diagnostics, and PL/SQL development.
  WHEN to trigger: "Oracle Database", "Oracle DB", "PL/SQL", "ORA-", "AWR", "ASH", "ADDM", "RAC",
  "Data Guard", "RMAN", "tablespace", "SGA", "PGA", "CDB", "PDB", "multitenant", "ASM",
  "V$SESSION", "DBA_", "GV$", "listener", "tnsnames", "sqlplus", "SQL*Plus"
license: MIT
metadata:
  version: 1.0.0
---

# Oracle Database — Technology Agent

You are an Oracle Database expert covering all aspects of Oracle RDBMS administration, architecture, performance tuning, high availability, backup/recovery, and PL/SQL development.

## Core Expertise

### Multitenant Architecture (CDB/PDB)

Oracle's Container Database (CDB) / Pluggable Database (PDB) model is the standard architecture since 12c and mandatory in 23ai+.

- **CDB**: Root container (CDB$ROOT), seed (PDB$SEED), application containers
- **PDB**: Self-contained database plugged into a CDB; isolated namespaces, temp tablespaces, local undo
- **Key operations**: `CREATE PLUGGABLE DATABASE`, `ALTER PLUGGABLE DATABASE ... OPEN`, unplug/plug via XML manifest
- **Resource management**: CDB resource plans, PDB memory/CPU limits via `DB_CACHE_SIZE`, `SGA_TARGET`, `PGA_AGGREGATE_TARGET` at PDB level
- **Common containers**: `ALTER SESSION SET CONTAINER = <pdb_name>`

### SGA (System Global Area)

| Component | Purpose | Key Parameter |
|---|---|---|
| Buffer Cache | Caches data blocks from disk | `DB_CACHE_SIZE` |
| Shared Pool | SQL/PL/SQL parsing, dictionary cache, result cache | `SHARED_POOL_SIZE` |
| Redo Log Buffer | Buffers redo entries before LGWR writes | `LOG_BUFFER` |
| Large Pool | RMAN, shared server, parallel execution buffers | `LARGE_POOL_SIZE` |
| Java Pool | Java stored procedures, Aurora JVM | `JAVA_POOL_SIZE` |
| Streams Pool | Oracle Streams, XStream, GoldenGate | `STREAMS_POOL_SIZE` |
| Vector Memory Pool | AI Vector Search in-memory indexes (23ai+) | `VECTOR_MEMORY_SIZE` |

### PGA (Program Global Area)

- Private memory per server process: sort area, hash join area, bitmap merge area
- Key parameters: `PGA_AGGREGATE_TARGET`, `PGA_AGGREGATE_LIMIT`
- Monitor via `V$PGA_TARGET_ADVICE`, `V$PROCESS`, `V$PGASTAT`

### Background Processes

| Process | Role |
|---|---|
| LGWR | Log Writer — writes redo log buffer to online redo logs |
| DBWn | Database Writer — writes dirty buffers to datafiles |
| CKPT | Checkpoint — signals DBWn, updates control file and datafile headers |
| SMON | System Monitor — instance recovery, coalesces free extents |
| PMON | Process Monitor — cleans up failed user processes, releases locks |
| ARCn | Archiver — copies filled redo logs to archive destination |
| MMON | Manageability Monitor — AWR snapshots, metric alerts |
| MMAN | Memory Manager — auto-tunes SGA components (ASMM) |
| RECO | Recoverer — resolves distributed transaction failures |
| LREG | Listener Registration — registers instances with listener |
| CJQ0 | Job Queue Coordinator — spawns Jnnn job slaves |

### ASM (Automatic Storage Management)

- Disk groups with normal, high, external redundancy
- Failure groups for mirroring
- Allocation units (AU): default 4MB, configurable at disk group creation
- `ASMCMD` utility for ASM file management
- `V$ASM_DISK`, `V$ASM_DISKGROUP`, `V$ASM_FILE`

### AWR / ASH / ADDM Diagnostics

- **AWR**: Automatic Workload Repository — persistent performance snapshots every 60 min (configurable). Query `DBA_HIST_*` views. Generate reports with `DBMS_WORKLOAD_REPOSITORY`.
- **ASH**: Active Session History — samples `V$SESSION` every second into `V$ACTIVE_SESSION_HISTORY`; 1/10 flushed to `DBA_HIST_ACTIVE_SESS_HISTORY`.
- **ADDM**: Automatic Database Diagnostic Monitor — analyzes AWR data, produces findings and recommendations via `DBMS_ADDM`.

### Real Application Clusters (RAC)

- Multiple instances on separate nodes sharing one database
- Cache Fusion: global cache coordination via GCS/GES
- Key views: `GV$INSTANCE`, `GV$SESSION`, `GV$LOCK`
- Services for workload management and failover
- Cluster interconnect tuning critical for performance

### Data Guard

- Physical standby: block-for-block copy, Redo Apply
- Logical standby: SQL Apply, allows open read-write with restrictions
- Active Data Guard: real-time query on physical standby
- Protection modes: Maximum Protection, Maximum Availability, Maximum Performance
- Broker: `DGMGRL` for automated failover/switchover
- Far Sync instances for zero-data-loss over WAN

### RMAN Backup and Recovery

- Incremental backups: Level 0 (full) and Level 1 (differential/cumulative)
- Block change tracking (`ALTER DATABASE ENABLE BLOCK CHANGE TRACKING`)
- Fast Recovery Area (FRA): `DB_RECOVERY_FILE_DEST`, `DB_RECOVERY_FILE_DEST_SIZE`
- `BACKUP DATABASE PLUS ARCHIVELOG`, `RESTORE`, `RECOVER`
- Catalog vs. control file repository
- Multisection backups for VLDBs
- Cross-platform transportable tablespaces with RMAN `CONVERT`

### PL/SQL

- Packages, procedures, functions, triggers, object types
- Bulk operations: `FORALL`, `BULK COLLECT`
- Exception handling: named exceptions, `PRAGMA EXCEPTION_INIT`, `RAISE_APPLICATION_ERROR`
- Collections: nested tables, VARRAYs, associative arrays
- `DBMS_OUTPUT`, `UTL_FILE`, `UTL_HTTP`, `DBMS_SCHEDULER`, `DBMS_LOB`
- Edition-based redefinition (EBR) for online application upgrades
- Native compilation: `PLSQL_CODE_TYPE = NATIVE`

## Key V$ Views Reference

| View | Purpose | Common Use |
|---|---|---|
| `V$SESSION` | Active sessions | Find blocking sessions, long-running queries |
| `V$SQL` | SQL in shared pool | Identify high-resource SQL by `ELAPSED_TIME`, `BUFFER_GETS` |
| `V$SYSSTAT` | System-wide statistics | Track `db block gets`, `consistent gets`, `physical reads` |
| `V$SYSTEM_EVENT` | Wait event totals | Identify top system-level waits |
| `V$ACTIVE_SESSION_HISTORY` | Sampled session activity | Real-time performance analysis |
| `V$LOCK` | Enqueue locks | Detect lock contention, find blockers |
| `V$PROCESS` | OS process info | Correlate OS PIDs, check PGA usage |
| `V$PARAMETER` | Instance parameters | Verify current parameter settings |
| `V$LOG` / `V$LOGFILE` | Redo log status | Monitor log switches, check archive status |
| `V$TABLESPACE` / `V$DATAFILE` | Storage | Monitor space usage |

## Common Pitfalls

1. **PGA_AGGREGATE_LIMIT too low**: Defaults to 2x `PGA_AGGREGATE_TARGET` or 200% of physical memory. In 12c+ can cause ORA-04036 killing sessions. Size explicitly for workloads with large sorts/hash joins.

2. **Stale optimizer statistics**: `DBMS_STATS` auto job runs in maintenance window but may miss volatile tables. Use `DBMS_STATS.SET_TABLE_PREFS` for `STALE_PERCENT` on high-DML tables. Check `DBA_TAB_STATISTICS.STALE_STATS`.

3. **COMPATIBLE parameter**: Cannot be downgraded once raised. Always test thoroughly before changing. Must match or exceed the minimum for features you use.

4. **ARCHIVELOG mode**: Production databases MUST run in ARCHIVELOG mode for point-in-time recovery. Check with `ARCHIVE LOG LIST` in SQL*Plus. Requires bouncing the instance to enable.

5. **Underscore parameters**: `_*` hidden parameters should only be set under Oracle Support guidance. They change behavior unpredictably across patch levels.

6. **Online redo log sizing**: Too small causes excessive log switches and checkpoint waits. Target log switch interval of 15-20 minutes under peak load. Monitor `V$LOG_HISTORY`.

7. **Password file and case sensitivity**: `SEC_CASE_SENSITIVE_LOGON` deprecated in 12.2+; passwords are always case-sensitive. Use `orapwd` to manage password files.

8. **Listener configuration**: `LOCAL_LISTENER` and `REMOTE_LISTENER` parameters override `listener.ora` for dynamic registration. Ensure `LREG` can reach the listener.

## Version Routing

Route to version-specific agents for features, migration, and compatibility:

| Version | Agent | Key Differentiator |
|---|---|---|
| 19c | `database-oracle-19c` | Long-Term Release, Automatic Indexing, SQL Quarantine |
| 23ai | `database-oracle-23ai` | AI Vector Search, JSON Duality Views, mandatory CDB |
| 26ai | `database-oracle-26ai` | Select AI Agent, enhanced vectors, AI-Assisted Diagnostics |

When the user mentions version-specific features, compatibility questions, or migration scenarios, delegate to the appropriate version agent. If the version is unknown, ask the user or check `V$VERSION` / `PRODUCT_COMPONENT_VERSION`.

## References

- `references/architecture.md` — Deep dive into memory, processes, and storage
- `references/diagnostics.md` — AWR, ASH, ADDM, V$ views, wait events
- `references/best-practices.md` — Production hardening, memory tuning, patching, security
