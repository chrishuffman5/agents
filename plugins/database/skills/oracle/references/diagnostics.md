# Oracle Database Diagnostics Reference

## AWR (Automatic Workload Repository)

AWR collects, processes, and maintains persistent performance statistics. It is the foundation for Oracle's self-diagnostic framework.

### Snapshots

- Automatic snapshots every 60 minutes by default (retained 8 days)
- Configure: `DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(retention => 43200, interval => 30)`
- Manual snapshot: `DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT`
- View snapshots: `DBA_HIST_SNAPSHOT`

### Key DBA_HIST_* Views

| View | Content |
|---|---|
| `DBA_HIST_SQLSTAT` | Per-SQL execution stats (elapsed time, CPU, buffer gets, rows) |
| `DBA_HIST_SYSSTAT` | System-wide statistics per snapshot |
| `DBA_HIST_SYSTEM_EVENT` | Wait event totals per snapshot |
| `DBA_HIST_ACTIVE_SESS_HISTORY` | Persisted ASH samples (1 in 10) |
| `DBA_HIST_OSSTAT` | OS-level metrics (CPU, memory) |
| `DBA_HIST_SGA_STAT` | SGA component sizes over time |
| `DBA_HIST_TBSPC_SPACE_USAGE` | Tablespace space usage history |
| `DBA_HIST_UNDOSTAT` | Undo usage and tuning data |
| `DBA_HIST_IOSTAT_FUNCTION` | I/O stats by function (DBWR, LGWR, etc.) |
| `DBA_HIST_SQL_PLAN` | Execution plans for captured SQL |

### Report Generation

```sql
-- Text report between two snapshots
SELECT * FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_TEXT(
  l_dbid     => (SELECT dbid FROM v$database),
  l_inst_num => 1,
  l_bid      => 100,  -- begin snap_id
  l_eid      => 110   -- end snap_id
));

-- HTML report
SELECT * FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(...));

-- RAC global report
SELECT * FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_GLOBAL_REPORT_TEXT(...));

-- SQL-level report
SELECT * FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_SQL_REPORT_TEXT(
  l_dbid => ..., l_inst_num => ..., l_bid => ..., l_eid => ...,
  l_sqlid => 'abc123def'
));
```

### AWR Baselines

- Capture known-good periods: `DBMS_WORKLOAD_REPOSITORY.CREATE_BASELINE`
- Compare current vs. baseline with AWR Diff reports
- Moving window baseline automatically adjusts to AWR retention period

## ASH (Active Session History)

ASH samples `V$SESSION` every second, capturing only **active** sessions (sessions waiting on non-idle wait events or on CPU).

### V$ACTIVE_SESSION_HISTORY

Key columns:
- `SAMPLE_TIME`, `SESSION_ID`, `SESSION_SERIAL#`
- `SQL_ID`, `SQL_PLAN_HASH_VALUE`, `SQL_OPNAME`
- `EVENT`, `WAIT_CLASS`, `P1`, `P2`, `P3`
- `SESSION_STATE` (ON CPU / WAITING)
- `BLOCKING_SESSION`, `BLOCKING_SESSION_SERIAL#`
- `MODULE`, `ACTION`, `CLIENT_ID` (set via `DBMS_APPLICATION_INFO`)
- `CURRENT_OBJ#`, `CURRENT_FILE#`, `CURRENT_BLOCK#` (object-level contention)
- `IN_PARSE`, `IN_HARD_PARSE`, `IN_SQL_EXECUTION`, `IN_BIND`
- `PGA_ALLOCATED`, `TEMP_SPACE_ALLOCATED`

### Common ASH Queries

```sql
-- Top SQL by elapsed time in last hour
SELECT sql_id, COUNT(*) AS sample_count,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
GROUP BY sql_id
ORDER BY sample_count DESC
FETCH FIRST 10 ROWS ONLY;

-- Top wait events in last hour
SELECT event, wait_class, COUNT(*) AS samples
FROM   v$active_session_history
WHERE  sample_time > SYSDATE - 1/24
  AND  session_state = 'WAITING'
GROUP BY event, wait_class
ORDER BY samples DESC
FETCH FIRST 10 ROWS ONLY;

-- Identify blocking chains
SELECT blocking_session, event, COUNT(*) AS blocked_samples
FROM   v$active_session_history
WHERE  blocking_session IS NOT NULL
  AND  sample_time > SYSDATE - 1/24
GROUP BY blocking_session, event
ORDER BY blocked_samples DESC;
```

### ASH Reports

```sql
-- Generate ASH report for a time range
SELECT * FROM TABLE(DBMS_WORKLOAD_REPOSITORY.ASH_REPORT_TEXT(
  l_dbid     => (SELECT dbid FROM v$database),
  l_inst_num => 1,
  l_btime    => SYSDATE - 1/24,
  l_etime    => SYSDATE
));
```

## ADDM (Automatic Database Diagnostic Monitor)

ADDM automatically analyzes AWR snapshots and produces findings with quantified impact and recommendations.

### Automatic Analysis

- Runs automatically after each AWR snapshot
- Results stored in `DBA_ADDM_TASKS`, `DBA_ADDM_FINDINGS`, `DBA_ADDM_RECOMMENDATIONS`
- View latest: `DBA_ADVISOR_FINDINGS` where `TASK_NAME LIKE 'ADDM%'`

### Manual Analysis

```sql
-- Analyze a specific AWR period
DECLARE
  v_task_name VARCHAR2(100);
BEGIN
  DBMS_ADDM.ANALYZE_DB(
    task_name     => v_task_name,
    begin_snapshot => 100,
    end_snapshot   => 110
  );
  DBMS_OUTPUT.PUT_LINE('Task: ' || v_task_name);
END;
/

-- View findings
SELECT type, message, impact
FROM   dba_addm_findings
WHERE  task_name = '<task_name>'
ORDER BY impact DESC;
```

### ADDM Finding Categories

- CPU bottlenecks, I/O issues, memory sizing
- SQL tuning candidates (high-load SQL)
- RAC-specific: interconnect latency, global cache contention
- Configuration issues: undersized logs, missing indexes

## V$ Views by Category

### Session and SQL

| View | Purpose |
|---|---|
| `V$SESSION` | Current sessions — SID, serial#, username, status, SQL_ID, event, blocking_session |
| `V$SQL` | SQL statements in shared pool — plan_hash_value, executions, elapsed_time, buffer_gets |
| `V$SQL_PLAN` | Execution plans for cached SQL |
| `V$SQL_MONITOR` | Real-time SQL monitoring (queries > 5 seconds or parallel) |
| `V$SQL_PLAN_MONITOR` | Per-operation real-time plan stats |
| `V$SQLAREA` | Aggregated SQL stats (one row per SQL_ID) |

### Wait Events and Statistics

| View | Purpose |
|---|---|
| `V$SYSTEM_EVENT` | Cumulative wait event stats since instance startup |
| `V$SESSION_EVENT` | Wait events per session |
| `V$EVENT_HISTOGRAM` | Wait event duration distribution |
| `V$SYSSTAT` | System-wide statistics (logical reads, physical reads, parse counts) |
| `V$SESSTAT` | Per-session statistics |
| `V$METRIC` | Recent metric values (last 60 seconds, last 15 minutes) |

### Locks and Contention

| View | Purpose |
|---|---|
| `V$LOCK` | Enqueue locks currently held and requested |
| `V$LOCKED_OBJECT` | Objects currently locked with session info |
| `V$LATCH` | Latch statistics (low-level serialization) |
| `V$MUTEX_SLEEP` | Mutex contention details |

### I/O and Storage

| View | Purpose |
|---|---|
| `V$DATAFILE` | Datafile information |
| `V$FILESTAT` / `V$IOSTAT_FILE` | File-level I/O statistics |
| `V$TEMP_SPACE_HEADER` | Temp tablespace usage |
| `V$UNDOSTAT` | Undo usage and tuning stats |
| `V$LOG` / `V$LOGFILE` | Online redo log status and locations |
| `V$ARCHIVED_LOG` | Archive log history |

## Common Wait Events

| Wait Event | Class | Typical Cause | Resolution |
|---|---|---|---|
| `db file sequential read` | User I/O | Single-block reads (index lookups) | Tune SQL, cache hot data, faster storage |
| `db file scattered read` | User I/O | Multi-block reads (full table scans) | Add indexes, partition pruning |
| `log file sync` | Commit | LGWR writing redo on commit | Reduce commit frequency, faster redo storage |
| `log file parallel write` | System I/O | LGWR writing to redo members | Faster redo disks, reduce redo members |
| `enq: TX - row lock contention` | Application | Row-level lock conflicts | Fix application logic, reduce lock hold time |
| `enq: TM - contention` | Application | Table-level lock (missing FK index) | Add indexes on foreign key columns |
| `latch: shared pool` | Concurrency | Hard parsing pressure | Use bind variables, increase shared pool |
| `cursor: pin S wait on X` | Concurrency | Mutex contention on cursor | Reduce hard parsing, check for bugs |
| `gc buffer busy` (RAC) | Cluster | Global cache block contention | Reduce cross-instance access, partition by instance |
| `gc cr multi block request` (RAC) | Cluster | Full scans requesting blocks from remote | Local affinity, reduce full scans |
| `read by other session` | User I/O | Multiple sessions reading same block | Application design, increase buffer cache |
| `direct path read` | User I/O | Direct path reads (serial full scans 12c+) | Normal for large scans; check `_serial_direct_read` |
| `free buffer waits` | Configuration | No free buffers in cache | Increase `DB_CACHE_SIZE`, tune checkpointing |
