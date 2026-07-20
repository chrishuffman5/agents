# PostgreSQL Diagnostics Reference

## pg_stat Views

### pg_stat_activity -- Current Sessions

The most frequently used diagnostic view. Shows all current backend processes:

```sql
-- Active queries running longer than 5 seconds
SELECT pid, usename, application_name, client_addr,
       state, wait_event_type, wait_event,
       now() - query_start AS query_duration,
       left(query, 200) AS query_snippet
FROM pg_stat_activity
WHERE state = 'active'
  AND query_start < now() - interval '5 seconds'
  AND pid <> pg_backend_pid()
ORDER BY query_start;
```

Key columns:
| Column | Meaning |
|---|---|
| `state` | `active`, `idle`, `idle in transaction`, `idle in transaction (aborted)` |
| `wait_event_type` | `Lock`, `IO`, `LWLock`, `Client`, `Activity`, `Extension`, etc. |
| `wait_event` | Specific wait: `relation`, `transactionid`, `DataFileRead`, `WALWrite` |
| `backend_type` | `client backend`, `autovacuum worker`, `background writer`, etc. |
| `xact_start` | When the current transaction started (NULL if none) |
| `query_start` | When the current/last query started |
| `state_change` | When `state` last changed |

**Detecting idle-in-transaction sessions:**
```sql
SELECT pid, usename, state, now() - xact_start AS xact_duration, query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND xact_start < now() - interval '5 minutes';
```

Set `idle_in_transaction_session_timeout` to automatically kill stale sessions:
```sql
ALTER SYSTEM SET idle_in_transaction_session_timeout = '10min';
SELECT pg_reload_conf();
```

### pg_stat_user_tables -- Table Statistics

```sql
SELECT schemaname, relname,
       seq_scan, idx_scan,
       n_tup_ins, n_tup_upd, n_tup_del,
       n_live_tup, n_dead_tup,
       round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
       last_vacuum, last_autovacuum,
       last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;
```

**Red flags:**
- `seq_scan` high + `idx_scan` = 0: missing index on frequently queried table
- `n_dead_tup` / `n_live_tup` > 20%: autovacuum not keeping up
- `last_autovacuum` is NULL or very old: autovacuum may be blocked or misconfigured

### pg_stat_user_indexes -- Index Usage

```sql
-- Find unused indexes (candidates for removal)
SELECT schemaname, relname, indexrelname,
       idx_scan, idx_tup_read, idx_tup_fetch,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname NOT IN ('pg_catalog', 'pg_toast')
ORDER BY pg_relation_size(indexrelid) DESC;
```

**Caution:** Check over a full business cycle (weeks, not hours) before dropping unused indexes. Some indexes are used only by nightly jobs or monthly reports.

### pg_stat_bgwriter -- Checkpoint and Background Writer

```sql
SELECT checkpoints_timed, checkpoints_req,
       buffers_checkpoint, buffers_clean, buffers_backend,
       maxwritten_clean,
       round(100.0 * buffers_backend / NULLIF(buffers_checkpoint + buffers_clean + buffers_backend, 0), 1) AS backend_write_pct
FROM pg_stat_bgwriter;
```

**Red flags:**
- `checkpoints_req` >> `checkpoints_timed`: increase `max_wal_size`
- `buffers_backend` high: backends writing dirty buffers themselves (increase shared_buffers or improve checkpoint/bgwriter throughput)
- `maxwritten_clean` > 0: background writer hitting `bgwriter_lru_maxpages` limit

### pg_stat_io (PostgreSQL 16+)

I/O statistics broken down by backend type and I/O target:

```sql
SELECT backend_type, object, context,
       reads, read_time,
       writes, write_time,
       fsyncs, fsync_time,
       hits
FROM pg_stat_io
WHERE reads > 0 OR writes > 0
ORDER BY backend_type, object;
```

### pg_stat_wal (PostgreSQL 14+)

WAL generation statistics:

```sql
SELECT wal_records, wal_fpi, wal_bytes,
       pg_size_pretty(wal_bytes) AS wal_human,
       wal_buffers_full, wal_write, wal_sync,
       stats_reset
FROM pg_stat_wal;
```

- `wal_fpi` (full page images): high values may indicate too-frequent checkpoints
- `wal_buffers_full`: if > 0, consider increasing `wal_buffers`

### pg_stat_statements -- Query Performance

Requires the `pg_stat_statements` extension:

```sql
-- Enable
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Top 10 queries by total time
SELECT left(query, 100) AS query,
       calls,
       round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2) AS mean_ms,
       round(stddev_exec_time::numeric, 2) AS stddev_ms,
       rows,
       round(100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0), 1) AS hit_pct
FROM pg_stat_statements
WHERE userid = (SELECT oid FROM pg_roles WHERE rolname = current_user)
ORDER BY total_exec_time DESC
LIMIT 10;
```

Reset statistics: `SELECT pg_stat_statements_reset();`

## Lock Analysis

### pg_locks

```sql
-- Current locks with human-readable details
SELECT l.pid, l.locktype, l.mode, l.granted, l.waitstart,
       d.datname, c.relname,
       a.usename, a.state, left(a.query, 100) AS query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
LEFT JOIN pg_class c ON l.relation = c.oid
LEFT JOIN pg_database d ON l.database = d.oid
WHERE NOT l.granted
ORDER BY l.waitstart;
```

### Blocking Query Detection

```sql
-- Find blocking and blocked sessions
SELECT
    blocked.pid AS blocked_pid,
    blocked.usename AS blocked_user,
    left(blocked.query, 80) AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.usename AS blocking_user,
    left(blocking.query, 80) AS blocking_query,
    blocking.state AS blocking_state,
    now() - blocked.query_start AS blocked_duration
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid AND NOT bl.granted
JOIN pg_locks kl ON kl.transactionid = bl.transactionid AND kl.granted
JOIN pg_stat_activity blocking ON kl.pid = blocking.pid
WHERE blocked.pid <> blocking.pid
ORDER BY blocked_duration DESC;
```

**Alternative using pg_blocking_pids() (PG 9.6+):**
```sql
SELECT pid, usename, state,
       pg_blocking_pids(pid) AS blocked_by,
       left(query, 100) AS query,
       now() - query_start AS duration
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
```

### Lock Types and Conflicts

| Lock Mode | Conflicts With | Common Cause |
|---|---|---|
| AccessShareLock | AccessExclusiveLock | SELECT |
| RowShareLock | ExclusiveLock, AccessExclusiveLock | SELECT FOR UPDATE/SHARE |
| RowExclusiveLock | ShareLock, ShareRowExclusiveLock, ExclusiveLock, AccessExclusiveLock | INSERT, UPDATE, DELETE |
| ShareLock | RowExclusiveLock, ShareUpdateExclusiveLock, ShareRowExclusiveLock, ExclusiveLock, AccessExclusiveLock | CREATE INDEX (non-concurrent) |
| AccessExclusiveLock | ALL | ALTER TABLE, DROP TABLE, VACUUM FULL, REINDEX |

**Key insight:** `ALTER TABLE ... ADD COLUMN` with a default value acquires AccessExclusiveLock. In PG 11+, adding a column with a non-volatile default is instant (metadata-only change), but it still briefly holds AccessExclusiveLock.

## EXPLAIN ANALYZE Deep Dive

### Reading Execution Plans

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT)
SELECT o.order_id, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.created_at > '2025-01-01'
ORDER BY o.created_at DESC
LIMIT 100;
```

**Plan structure reads bottom-up, inside-out:**

```
Limit (cost=1000.43..1025.50 rows=100 width=45) (actual time=5.2..5.8 rows=100 loops=1)
  -> Nested Loop (cost=1000.43..5000.50 rows=1500 width=45) (actual time=5.2..5.7 rows=100 loops=1)
       -> Index Scan Backward using idx_orders_created on orders o (cost=0.43..2500.50 rows=1500 width=20)
            (actual time=0.05..1.2 rows=100 loops=1)
            Index Cond: (created_at > '2025-01-01')
            Buffers: shared hit=150
       -> Index Scan using customers_pkey on customers c (cost=0.29..1.50 rows=1 width=25)
            (actual time=0.02..0.02 rows=1 loops=100)
            Index Cond: (id = o.customer_id)
            Buffers: shared hit=300
Planning Time: 0.5 ms
Execution Time: 6.1 ms
```

### Key Metrics to Examine

| Metric | Healthy | Problem |
|---|---|---|
| actual rows vs estimated rows | Within 10x | > 100x off = stale stats, run ANALYZE |
| shared hit vs shared read | hit >> read | read >> hit = cold cache or working set > shared_buffers |
| Sort Method: quicksort | In-memory sort | external merge Disk = increase work_mem |
| Rows Removed by Filter | Low | High = sequential scan filtering many rows, needs index |
| actual loops * actual rows | Reasonable | High loop count with inner rows = nested loop inefficiency |
| Planning Time | < 10ms | > 100ms = complex query or too many partitions |

### Common Plan Node Types

| Node | Description | Optimization |
|---|---|---|
| Seq Scan | Full table scan | Add index, or accept if table is small |
| Index Scan | B-tree traversal + heap fetch | Ideal for selective queries |
| Index Only Scan | B-tree only, no heap | Best case; requires all-visible pages (VACUUM) |
| Bitmap Index Scan + Bitmap Heap Scan | Bitmap of matching pages, then heap fetch | Good for moderate selectivity |
| Hash Join | Build hash table on smaller relation | Needs adequate work_mem |
| Merge Join | Both inputs sorted, merge | Best for large pre-sorted datasets |
| Nested Loop | For each outer row, scan inner | Efficient only with small outer or indexed inner |
| Sort | In-memory or on-disk sort | Increase work_mem if spilling to disk |
| HashAggregate | Hash-based grouping | Needs adequate work_mem |
| Gather / Gather Merge | Parallel query coordination | Parallel workers active |

## auto_explain

Automatically logs execution plans for slow queries:

```sql
-- Enable in postgresql.conf or per-session
LOAD 'auto_explain';
SET auto_explain.log_min_duration = '1s';    -- log plans for queries > 1 second
SET auto_explain.log_analyze = on;            -- include actual times
SET auto_explain.log_buffers = on;            -- include buffer stats
SET auto_explain.log_format = 'text';         -- or 'json' for programmatic parsing
SET auto_explain.log_nested_statements = on;  -- include plans inside functions

-- For production, set in postgresql.conf:
-- shared_preload_libraries = 'auto_explain'
-- auto_explain.log_min_duration = '5s'
```

## Log Analysis

### Essential Log Settings

```
log_destination = 'stderr'          -- or 'csvlog' for structured parsing
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d.log'
log_rotation_age = 1d
log_rotation_size = 100MB

-- What to log
log_min_duration_statement = 1000   -- log queries > 1 second (ms)
log_checkpoints = on                -- log checkpoint activity
log_connections = on                -- log connection attempts
log_disconnections = on             -- log session end with duration
log_lock_waits = on                 -- log lock waits > deadlock_timeout
log_temp_files = 0                  -- log all temp file usage
log_autovacuum_min_duration = 0     -- log all autovacuum activity

-- Query logging (caution: high volume)
log_statement = 'ddl'               -- log DDL only (none, ddl, mod, all)
log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h '
```

### Common Log Patterns to Watch

| Log Message | Meaning | Action |
|---|---|---|
| `LOG: checkpoints are occurring too frequently` | WAL volume exceeds max_wal_size | Increase max_wal_size |
| `LOG: temporary file: path "...", size ...` | Query spilling sort/hash to disk | Increase work_mem for that query |
| `FATAL: remaining connection slots are reserved` | max_connections nearly exhausted | Use PgBouncer; reduce connection count |
| `LOG: process ... still waiting for ShareLock` | Lock contention | Check pg_locks for blocking sessions |
| `WARNING: oldest xmin is far in the past` | Long-running transaction preventing vacuum | Kill idle-in-transaction sessions |
| `LOG: automatic vacuum of table ...` | Autovacuum ran | Monitor duration and pages processed |
| `PANIC: could not write to file "pg_wal/..."` | Disk full for WAL | Emergency: free disk space immediately |

### pgBadger Log Analyzer

pgBadger parses PostgreSQL logs and generates HTML reports:

```bash
# Generate report from log files
pgbadger /var/log/postgresql/postgresql-*.log -o report.html

# For csvlog format
pgbadger --format csv /var/log/postgresql/postgresql-*.csv -o report.html

# Incremental mode (for continuous monitoring)
pgbadger --incremental /var/log/postgresql/postgresql-*.log -O /var/www/pgbadger/
```

Reports include: query statistics, slowest queries, lock analysis, checkpoint activity, connection patterns, temporary file usage, and error distribution.
