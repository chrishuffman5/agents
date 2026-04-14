# Oracle Database Best Practices Reference

## ARCHIVELOG Mode

All production databases must run in ARCHIVELOG mode for point-in-time recovery.

```sql
-- Check current mode
ARCHIVE LOG LIST;
SELECT log_mode FROM v$database;

-- Enable (requires restart)
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
```

- Configure at least two `LOG_ARCHIVE_DEST_n` for redundancy
- Monitor `V$ARCHIVED_LOG`, `V$ARCHIVE_DEST` for errors
- Set `LOG_ARCHIVE_MAX_PROCESSES` (default 4) based on redo volume

## Memory Management

### ASMM (Automatic Shared Memory Management)

- Set `SGA_TARGET` to desired total SGA size; Oracle auto-tunes components
- `SGA_MAX_SIZE` >= `SGA_TARGET` (upper bound for dynamic resize)
- Individual component minimums (`DB_CACHE_SIZE`, `SHARED_POOL_SIZE`) act as floors
- Monitor: `V$SGA_TARGET_ADVICE`, `V$MEMORY_TARGET_ADVICE`

### AMM (Automatic Memory Management)

- Set `MEMORY_TARGET` to total SGA + PGA; Oracle manages both automatically
- `MEMORY_MAX_TARGET` >= `MEMORY_TARGET`
- On Linux: requires `/dev/shm` sized appropriately
- Not recommended for large systems (>16GB SGA) or Huge Pages environments
- Huge Pages require ASMM (not AMM) — set `SGA_TARGET`, leave `MEMORY_TARGET = 0`

### PGA Sizing

- `PGA_AGGREGATE_TARGET`: Advisory target — Oracle distributes among work areas
- `PGA_AGGREGATE_LIMIT`: Hard ceiling (default 2x PGA_AGGREGATE_TARGET or 200% physical memory)
- Monitor: `V$PGA_TARGET_ADVICE` — look for "optimal" executions vs. "one-pass"/"multi-pass"
- Target >95% optimal executions in `V$PGASTAT`
- For large ETL/sort workloads, explicitly size higher

## Patching Strategy

### Release Updates (RU)

- Apply quarterly Release Updates for bug fixes and security
- Use `opatchauto` for GI+DB patching, `opatch apply` for DB-only
- Always apply on non-production first; validate with `datapatch` post-patching
- Keep `COMPATIBLE` parameter at minimum required — never raise preemptively

### AutoUpgrade

- Use `AutoUpgrade` utility for major version upgrades (19c+)
- Modes: `analyze` (pre-check), `fixups` (auto-fix issues), `deploy` (full upgrade)
- Command: `java -jar autoupgrade.jar -config config.cfg -mode deploy`
- Always run `analyze` mode first to identify blockers

## Unified Auditing

Unified Auditing consolidates all audit trails into a single `UNIFIED_AUDIT_TRAIL` view.

- Enable pure mode: relink with `make -f ins_rdbms.mk uniaud_on ioracle` (Linux)
- Create policies: `CREATE AUDIT POLICY`, `AUDIT POLICY ... BY ...`
- Built-in policies: `ORA_SECURECONFIG`, `ORA_LOGON_FAILURES`
- Purge old records: `DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL`
- Traditional auditing is desupported in 23ai

## Optimizer Statistics (DBMS_STATS)

```sql
-- Gather schema stats with recommended options
EXEC DBMS_STATS.GATHER_SCHEMA_STATS(
  ownname          => 'APP_SCHEMA',
  options          => 'GATHER AUTO',
  estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
  method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
  degree           => DBMS_STATS.AUTO_DEGREE
);

-- Set stale percentage for volatile tables
EXEC DBMS_STATS.SET_TABLE_PREFS('APP_SCHEMA', 'ORDERS', 'STALE_PERCENT', '5');

-- Lock stats on reference/config tables that rarely change
EXEC DBMS_STATS.LOCK_TABLE_STATS('APP_SCHEMA', 'COUNTRY_CODES');

-- Create extended stats for correlated columns
SELECT DBMS_STATS.CREATE_EXTENDED_STATS('APP_SCHEMA', 'ORDERS', '(REGION, PRODUCT_TYPE)')
FROM dual;
```

- Auto stats job runs in default maintenance window — verify it completes
- Check `DBA_AUTOTASK_CLIENT` for `auto optimizer stats collection`
- Use incremental stats for partitioned tables: `INCREMENTAL` preference = `TRUE`
- Pending stats: test with `DBMS_STATS.PUBLISH_PENDING_STATS` before publishing

## RMAN with Fast Recovery Area (FRA)

```sql
-- Configure FRA
ALTER SYSTEM SET DB_RECOVERY_FILE_DEST = '+RECO' SCOPE=BOTH;
ALTER SYSTEM SET DB_RECOVERY_FILE_DEST_SIZE = 500G SCOPE=BOTH;

-- Enable block change tracking for faster incrementals
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA/bct.ctf';
```

### Recommended RMAN Strategy

- **Level 0** incremental weekly (full baseline)
- **Level 1** incremental daily (cumulative preferred for simpler recovery)
- Archive log backups every 15-30 minutes for minimal data loss
- Enable `CONTROLFILE AUTOBACKUP`
- Validate backups regularly: `RESTORE DATABASE VALIDATE` and `BACKUP VALIDATE DATABASE`
- Retention policy: `CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 30 DAYS`
- Compression: `CONFIGURE DEVICE TYPE DISK BACKUP TYPE TO COMPRESSED BACKUPSET`
- Encryption for off-site: `CONFIGURE ENCRYPTION FOR DATABASE ON`

## Data Guard for DR

- Deploy physical standby with real-time redo transport (`LOG_ARCHIVE_DEST_2 ... ASYNC/SYNC`)
- Use Data Guard Broker (`DGMGRL`) for automated switchover/failover
- Enable Active Data Guard for read-only offload and real-time query
- Configure Fast-Start Failover (FSFO) with observer for automatic failover
- Test switchover quarterly; validate standby with `VALIDATE DATABASE`
- Apply gap: monitor `V$ARCHIVE_GAP`, `V$DATAGUARD_STATS`

```sql
-- Broker status check
DGMGRL> SHOW CONFIGURATION;
DGMGRL> SHOW DATABASE 'standby_db';
DGMGRL> VALIDATE DATABASE 'standby_db';
```

## SQL Plan Management (SPM)

SPM prevents plan regressions by maintaining a baseline of accepted execution plans.

```sql
-- Auto-capture plans (captures repeating SQL)
ALTER SYSTEM SET OPTIMIZER_CAPTURE_SQL_PLAN_BASELINES = TRUE;

-- Use baselines
ALTER SYSTEM SET OPTIMIZER_USE_SQL_PLAN_BASELINES = TRUE;  -- default TRUE

-- Load a specific plan from cursor cache
DECLARE
  v_plans PLS_INTEGER;
BEGIN
  v_plans := DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(
    sql_id => 'abc123def',
    plan_hash_value => 1234567890
  );
END;
/

-- Evolve non-accepted plans (verify they perform better)
DECLARE
  v_report CLOB;
BEGIN
  v_report := DBMS_SPM.EVOLVE_SQL_PLAN_BASELINE(sql_handle => 'SQL_abc123');
  DBMS_OUTPUT.PUT_LINE(v_report);
END;
/
```

- View baselines: `DBA_SQL_PLAN_BASELINES`
- SPM supersedes stored outlines (deprecated) and SQL profiles
- Combine with SQL Quarantine (19c+) to block known-bad plans
