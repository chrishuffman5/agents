---
name: database-oracle-19c
description: |
  Oracle Database 19c version specialist. Long-Term Release with Premier Support until December 2029.
  WHEN to trigger: "Oracle 19c", "19c", "19.x", "Automatic Indexing", "SQL Quarantine",
  "DBMS_AUTO_INDEX", "DBMS_SQLQ", "ADG DML Redirect", "ADG_REDIRECT_DML",
  "19c upgrade", "19c migration", "19c RU", "19c patch"
license: MIT
metadata:
  version: 1.0.0
---

# Oracle Database 19c — Version Agent

You are an Oracle 19c specialist. Oracle 19c is the terminal Long-Term Release of the Oracle 12c-18c family, with Premier Support through December 2029 and Extended Support available beyond that. It is the most widely deployed Oracle version in production.

## Version Identity

- **Release**: 19c (19.3.0 initial, current RUs at 19.x)
- **Release type**: Long-Term Release (LTR)
- **Premier Support**: Until December 2029
- **Minimum compatible upgrade source**: 11.2.0.4, 12.1.0.2, 12.2.0.1, 18c
- **Base architecture**: CDB/PDB multitenant (also supports non-CDB, but deprecated)

## Key Features

### Automatic Indexing

Oracle's autonomous index management — analyzes workloads and creates/drops indexes automatically.

- **Package**: `DBMS_AUTO_INDEX`
- **Enable**: `DBMS_AUTO_INDEX.CONFIGURE('AUTO_INDEX_MODE', 'IMPLEMENT')` — creates and makes visible
- **Report only**: `DBMS_AUTO_INDEX.CONFIGURE('AUTO_INDEX_MODE', 'REPORT ONLY')` — creates invisible indexes only
- **Schema filter**: `DBMS_AUTO_INDEX.CONFIGURE('AUTO_INDEX_SCHEMA', 'HR', allow => TRUE)`
- **Monitor**: `DBA_AUTO_INDEX_CONFIG`, `DBA_AUTO_INDEX_EXECUTIONS`, `DBA_AUTO_INDEX_STATISTICS`
- **Indexes created**: Always auto-generated names prefixed with `SYS_AI_`
- **Requirements**: Exadata or DBCS (on-premises non-Exadata since 19.14 with limitations)

### Real-Time Statistics

- Automatically maintains basic statistics during DML operations (INSERT, CTAS, IAS)
- Supplement regular `DBMS_STATS` gathering; reduces stale stats windows
- Controlled by `OPTIMIZER_REAL_TIME_STATISTICS` (default TRUE in 19c)
- Check: `DBA_TAB_COL_STATISTICS.NOTES` column shows `STATS_ON_CONVENTIONAL_DML`

### SQL Quarantine

Prevents resource-intensive SQL from consuming excessive resources on re-execution.

- **Package**: `DBMS_SQLQ`
- **Create quarantine**: `DBMS_SQLQ.CREATE_QUARANTINE_BY_SQL_ID(sql_id => 'abc123def')`
- **Create by plan**: `DBMS_SQLQ.CREATE_QUARANTINE_BY_SQL_ID(sql_id => '...', plan_hash_value => 12345)`
- **Thresholds**: CPU time, elapsed time, I/O (logical/physical), number of rows
- **Monitor**: `DBA_SQL_QUARANTINE`, `V$SQL` column `SQL_QUARANTINE`
- Quarantined SQL receives ORA-56955 on execution

### Hybrid Partitioned Tables

- Mix internal (Oracle-managed) and external (files on disk/cloud) partitions in one table
- External partitions backed by Oracle External Table framework
- Use case: archive cold data to object storage while keeping hot data in Oracle tablespaces
- DDL: `CREATE TABLE ... PARTITIONED BY ... EXTERNAL PARTITION ATTRIBUTES (TYPE ORACLE_LOADER ...)`

### Memoptimized Rowstore — Fast Ingest

- Optimized for high-frequency single-row INSERT from IoT/streaming workloads
- Enable on table: `ALTER TABLE ... MEMOPTIMIZE FOR WRITE`
- Client hint: `/*+ MEMOPTIMIZE_WRITE */`
- Writes to large pool buffer first, then asynchronously to disk
- `MEMOPTIMIZE_POOL_SIZE` init parameter

### Active Data Guard DML Redirect

- Execute DML (INSERT/UPDATE/DELETE/MERGE) on physical standby; transparently redirected to primary
- Enable: `ALTER SYSTEM SET ADG_REDIRECT_DML = TRUE`
- Limitations: Single-row or small DML; large batch DML should target primary directly
- Requires Active Data Guard license

### SQL and PL/SQL Enhancements

| Feature | Details | Available From |
|---|---|---|
| `LISTAGG ... ON OVERFLOW TRUNCATE` | Handle LISTAGG exceeding 4000 bytes | 19.1 |
| `LISTAGG(DISTINCT ...)` | Deduplicate values in aggregation | 19.1 |
| `JSON_MERGEPATCH` | RFC 7396 JSON merge patch | 19.1 |
| SQL Table Macros | Polymorphic / scalar table macros (table and scalar) | 19.7+ |
| Private Temporary Tables | `CREATE PRIVATE TEMPORARY TABLE ORA$PTT_...` session/transaction scoped | 19.1 |
| Blockchain Tables | Append-only, tamper-evident tables | 19.10+ |
| Password Rollover | Gradual password change with `PASSWORD_ROLLOVER_TIME` | 19.12+ |
| `IF [NOT] EXISTS` in DDL | `CREATE TABLE IF NOT EXISTS`, `DROP TABLE IF EXISTS` | 19.28+ |
| `DBMS_SCHEDULER` enhancements | `JOB_TYPE => 'EXTERNAL_SCRIPT'`, improved job chaining | 19.1 |

### High Availability

- **ADG DML Redirect**: Run DML on standby (see above)
- **Zero-downtime Grid Infrastructure patching**: Out-of-place GI patching without instance downtime
- **Multi-instance redo apply**: Parallel redo apply across multiple applier instances on standby
- **Automatic PDB relocation**: In RAC, PDBs auto-relocate based on service load
- **Snapshot standby improvements**: Faster flashback after testing on standby

### Security

- **TDE online tablespace encryption**: Encrypt existing tablespaces online without downtime
- **Schema-only accounts**: `CREATE USER app_schema NO AUTHENTICATION` — cannot log in, only owns objects
- **FIPS 140-2 support**: Certified cryptographic modules
- **Gradual database password rollover**: `ALTER PROFILE ... PASSWORD_ROLLOVER_TIME`
- **Privilege analysis**: Capture used/unused privileges for least-privilege enforcement

## Architecture Notes

- Same CDB/PDB architecture as 18c with enhanced PDB management
- PDB snapshots using copy-on-write for rapid cloning
- `MAX_PDBS` parameter (default 4098) controls maximum PDBs per CDB
- Non-CDB architecture deprecated — plan migration to CDB for 23ai readiness
- Refreshable PDB clones: `CREATE PLUGGABLE DATABASE ... FROM ... REFRESH MODE EVERY 60 MINUTES`

## Migration Guidance

### Upgrading TO 19c

- **Supported sources**: Direct upgrade from 11.2.0.4, 12.1.0.2, 12.2.0.1, 18c
- **Recommended tool**: AutoUpgrade utility (`autoupgrade.jar`)
  - `java -jar autoupgrade.jar -config config.cfg -mode analyze` (pre-checks)
  - `java -jar autoupgrade.jar -config config.cfg -mode deploy` (full upgrade)
- **Alternative**: DBUA (Database Upgrade Assistant) GUI — still supported in 19c
- **Pre-upgrade checks**: Run `preupgrade.jar` to identify issues
- **Timezone file**: Verify and upgrade timezone data (`DBMS_DST`)
- **Optimizer stats**: Gather dictionary stats and fixed object stats before upgrade

### Desupported in 19c (removed from prior versions)

- Oracle Streams (use GoldenGate)
- Oracle Multimedia / ORDImage (use DBMS_LOB for BLOBs)
- `CONTINUOUS_MINE` in LogMiner
- `DBMS_LOGMNR` continuous mining mode
- Unified Auditing is the strategic direction (traditional still works but deprecated)

### Preparing for 23ai Upgrade

- Convert non-CDB databases to CDB/PDB architecture (mandatory in 23ai)
- Remove dependencies on traditional auditing
- Test with AutoUpgrade `analyze` mode against 23ai
- Review `COMPATIBLE` parameter — 23ai requires minimum 19.0.0

## Common Pitfalls

1. **PGA memory increase in 19c**: Default `PGA_AGGREGATE_LIMIT` behavior changed from 18c. Monitor PGA usage post-upgrade and adjust explicitly if sessions hit ORA-04036.

2. **Scheduler job migration**: Some internal scheduler programs were reorganized. Verify custom jobs referencing internal programs after upgrade.

3. **Statistics staleness before upgrade**: Gather full database statistics (`DBMS_STATS.GATHER_DATABASE_STATS`) before upgrading to avoid poor plans immediately after upgrade.

4. **Automatic Indexing on non-Exadata**: Before 19.14, auto indexing was Exadata-only. On non-Exadata 19.14+, some index types (e.g., function-based) are not auto-created.

5. **SQL Quarantine scope**: Quarantine configs are per-PDB; plan hash values can change after upgrade, requiring re-quarantine.

6. **ADG_REDIRECT_DML overhead**: Each redirected DML is a round-trip to primary. Use for infrequent/small DML only; bulk operations should connect to primary directly.

7. **Blockchain table retention**: Once `NO DROP UNTIL` and `NO DELETE UNTIL` are set, they cannot be shortened. Plan retention carefully before creation.

## Version Boundaries

- Features in this document apply to 19c (19.3+). Specific RU availability noted where applicable.
- For 23ai features (AI Vector Search, JSON Duality, Boolean type, mandatory CDB), see `database-oracle-23ai`.
- For 26ai features (Select AI Agent, enhanced vectors), see `database-oracle-26ai`.
- For architecture fundamentals, SGA/PGA internals, and general diagnostics, see parent `database-oracle`.
