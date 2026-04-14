# MySQL Diagnostics Reference

## Performance Schema

Performance Schema is MySQL's runtime instrumentation framework. It collects detailed statistics about server execution with minimal overhead.

### Instruments and Consumers

- **Instruments** define what is measured (e.g., `wait/synch/mutex/innodb/buf_pool_mutex`)
- **Consumers** define what data is collected (e.g., `events_statements_history`)
- Enable/disable dynamically via `performance_schema.setup_instruments` and `performance_schema.setup_consumers`

```sql
-- Enable all statement instruments (usually ON by default)
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES'
WHERE NAME LIKE 'statement/%';

-- Enable statement history consumer
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME = 'events_statements_history';
```

### Key Performance Schema Tables

#### events_statements_summary_by_digest

The most important table for query performance analysis. Aggregates query statistics by normalized statement (digest):

```sql
SELECT
    DIGEST_TEXT,
    COUNT_STAR AS exec_count,
    ROUND(SUM_TIMER_WAIT / 1e12, 2) AS total_latency_sec,
    ROUND(AVG_TIMER_WAIT / 1e12, 4) AS avg_latency_sec,
    SUM_ROWS_EXAMINED AS rows_examined,
    SUM_ROWS_SENT AS rows_sent,
    SUM_NO_INDEX_USED AS full_scans
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;
```

Key columns: `COUNT_STAR`, `SUM_TIMER_WAIT`, `AVG_TIMER_WAIT`, `SUM_ROWS_EXAMINED`, `SUM_ROWS_SENT`, `SUM_CREATED_TMP_DISK_TABLES`, `SUM_NO_INDEX_USED`, `FIRST_SEEN`, `LAST_SEEN`.

#### file_summary_by_instance

I/O statistics per file (data files, redo log, binlog, temp files):

```sql
SELECT
    FILE_NAME,
    COUNT_READ, SUM_TIMER_READ / 1e12 AS read_latency_sec,
    COUNT_WRITE, SUM_TIMER_WRITE / 1e12 AS write_latency_sec,
    SUM_NUMBER_OF_BYTES_READ / 1024 / 1024 AS read_mb,
    SUM_NUMBER_OF_BYTES_WRITE / 1024 / 1024 AS write_mb
FROM performance_schema.file_summary_by_instance
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;
```

#### table_io_waits_summary_by_table

I/O wait time broken down by table and operation (fetch, insert, update, delete):

```sql
SELECT
    OBJECT_SCHEMA, OBJECT_NAME,
    COUNT_FETCH, SUM_TIMER_FETCH / 1e12 AS fetch_latency_sec,
    COUNT_INSERT, SUM_TIMER_INSERT / 1e12 AS insert_latency_sec,
    COUNT_UPDATE, SUM_TIMER_UPDATE / 1e12 AS update_latency_sec,
    COUNT_DELETE, SUM_TIMER_DELETE / 1e12 AS delete_latency_sec
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys')
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;
```

#### memory_summary_global_by_event_name

Tracks memory allocations by component:

```sql
SELECT
    EVENT_NAME,
    CURRENT_COUNT_USED AS alloc_count,
    CURRENT_NUMBER_OF_BYTES_USED / 1024 / 1024 AS current_mb,
    HIGH_NUMBER_OF_BYTES_USED / 1024 / 1024 AS high_water_mb
FROM performance_schema.memory_summary_global_by_event_name
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 20;
```

#### threads

All server threads with their current state, useful for identifying what the server is doing right now:

```sql
SELECT
    THREAD_ID, PROCESSLIST_ID, NAME, TYPE,
    PROCESSLIST_STATE, PROCESSLIST_INFO,
    PROCESSLIST_TIME
FROM performance_schema.threads
WHERE TYPE = 'FOREGROUND'
ORDER BY PROCESSLIST_TIME DESC;
```

#### data_locks and data_lock_waits

InnoDB lock information (replaces `INFORMATION_SCHEMA.INNODB_LOCKS` in 8.0+):

```sql
-- Current locks
SELECT ENGINE, LOCK_TYPE, LOCK_MODE, LOCK_STATUS, LOCK_DATA,
       OBJECT_SCHEMA, OBJECT_NAME
FROM performance_schema.data_locks;

-- Lock waits (blocking relationships)
SELECT
    r.THREAD_ID AS waiting_thread,
    r.OBJECT_SCHEMA, r.OBJECT_NAME,
    r.LOCK_MODE AS waiting_for,
    b.THREAD_ID AS blocking_thread,
    b.LOCK_MODE AS blocking_lock
FROM performance_schema.data_lock_waits w
JOIN performance_schema.data_locks r ON w.REQUESTING_ENGINE_LOCK_ID = r.ENGINE_LOCK_ID
JOIN performance_schema.data_locks b ON w.BLOCKING_ENGINE_LOCK_ID = b.ENGINE_LOCK_ID;
```

## sys Schema

The sys schema provides human-friendly views built on top of Performance Schema. It is installed by default in MySQL 8.0+.

### Key sys Schema Views

#### statement_analysis

Top queries by total latency (wraps `events_statements_summary_by_digest`):

```sql
SELECT query, exec_count, total_latency, avg_latency,
       rows_examined, rows_examined_avg, rows_sent, rows_sent_avg,
       tmp_disk_tables, full_scans
FROM sys.statement_analysis
LIMIT 20;
```

#### host_summary

Connection and statement statistics aggregated by client host:

```sql
SELECT host, statements, statement_latency, statement_avg_latency,
       table_scans, current_connections, total_connections
FROM sys.host_summary;
```

#### schema_table_statistics

Table-level I/O latency and row counts:

```sql
SELECT table_schema, table_name,
       rows_fetched, fetch_latency,
       rows_inserted, insert_latency,
       rows_updated, update_latency,
       rows_deleted, delete_latency,
       io_read, io_write
FROM sys.schema_table_statistics
WHERE table_schema NOT IN ('mysql', 'sys', 'performance_schema')
ORDER BY (fetch_latency + insert_latency + update_latency + delete_latency) DESC
LIMIT 20;
```

#### innodb_buffer_stats_by_table

Buffer pool page usage by table:

```sql
SELECT object_schema, object_name,
       allocated, data, pages,
       pages_hashed, pages_old, rows_cached
FROM sys.innodb_buffer_stats_by_table
ORDER BY allocated DESC
LIMIT 20;
```

#### schema_unused_indexes

Indexes that have not been used since the server was last restarted:

```sql
SELECT object_schema, object_name, index_name
FROM sys.schema_unused_indexes
WHERE object_schema NOT IN ('mysql', 'sys', 'performance_schema');
```

**Caveat:** Only reflects usage since the last restart. Wait for a full workload cycle before dropping.

#### schema_redundant_indexes

Indexes that are duplicated by or are a prefix of another index:

```sql
SELECT table_schema, table_name,
       redundant_index_name, redundant_index_columns,
       dominant_index_name, dominant_index_columns
FROM sys.schema_redundant_indexes;
```

## EXPLAIN

### Output Formats

| Format | Syntax | Best For |
|---|---|---|
| **Traditional** | `EXPLAIN SELECT ...` | Quick tabular overview |
| **JSON** | `EXPLAIN FORMAT=JSON SELECT ...` | Maximum detail; cost estimates, attached conditions |
| **Tree** | `EXPLAIN FORMAT=TREE SELECT ...` (8.0.16+) | Readable iterator-based plan; shows data flow |
| **EXPLAIN ANALYZE** | `EXPLAIN ANALYZE SELECT ...` (8.0.18+) | Actual execution with per-iterator timing and row counts |

### EXPLAIN Traditional Columns

| Column | What to Look For |
|---|---|
| **id** | SELECT identifier; higher numbers execute first in subqueries |
| **select_type** | SIMPLE, PRIMARY, SUBQUERY, DERIVED, UNION, MATERIALIZED |
| **table** | Table or alias being accessed |
| **type** | Access method (best to worst): `system` > `const` > `eq_ref` > `ref` > `fulltext` > `ref_or_null` > `index_merge` > `range` > `index` > `ALL` |
| **possible_keys** | Indexes the optimizer considered |
| **key** | Index actually chosen (NULL = no index used) |
| **key_len** | Bytes of the index key used; reveals how many columns of a composite index are used |
| **ref** | Columns or constants compared to the index |
| **rows** | Estimated rows to examine (not returned) |
| **filtered** | Percentage of rows remaining after table condition filtering |
| **Extra** | Critical: `Using index` (covering index), `Using where` (post-index filter), `Using temporary` (temp table needed), `Using filesort` (extra sort pass), `Using index condition` (ICP pushdown) |

### EXPLAIN ANALYZE Interpretation

EXPLAIN ANALYZE executes the query and reports actual vs. estimated metrics:

```
-> Nested loop inner join  (cost=45.26 rows=100) (actual time=0.150..12.340 rows=95 loops=1)
    -> Index scan on t1 using PRIMARY  (cost=10.00 rows=100) (actual time=0.050..0.500 rows=100 loops=1)
    -> Single-row index lookup on t2 using idx_fk (fk_id=t1.id)  (cost=0.25 rows=1) (actual time=0.080..0.080 rows=1 loops=100)
```

Key elements:
- `cost` and `rows` -- optimizer estimates
- `actual time` -- first row..last row in milliseconds
- `rows` -- actual rows produced
- `loops` -- number of times this iterator executed

**Red flags:**
- Large discrepancy between estimated `rows` and actual `rows` (stale statistics; run `ANALYZE TABLE`)
- `actual time` much higher than expected (I/O bottleneck or lock contention)
- High `loops` count on inner iterator (consider hash join or different join order)

## Slow Query Log

### Configuration

```ini
[mysqld]
slow_query_log = ON
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1                    # log queries taking > 1 second
log_queries_not_using_indexes = ON     # also log queries not using indexes
min_examined_row_limit = 100           # ignore queries examining < 100 rows
log_slow_extra = ON                    # 8.0.14+: log extra fields
log_throttle_queries_not_using_indexes = 60  # limit no-index logs per minute
```

### Slow Log Fields (with log_slow_extra)

The extended fields added by `log_slow_extra` (8.0.14+):
- `Rows_examined` -- total rows scanned
- `Rows_sent` -- rows returned to client
- `Bytes_sent` -- bytes returned to client
- `Thread_id` -- connection thread ID
- `Errno` -- error number (0 for success)

### Analysis with pt-query-digest

Percona Toolkit's `pt-query-digest` aggregates slow log entries into a ranked report:

```bash
# Basic analysis
pt-query-digest /var/log/mysql/slow.log > slow_report.txt

# Filter by time range
pt-query-digest --since '2025-01-01 00:00:00' --until '2025-01-02 00:00:00' /var/log/mysql/slow.log

# Top queries by total execution time
pt-query-digest --order-by Query_time:sum /var/log/mysql/slow.log

# Analyze specific query fingerprint
pt-query-digest --filter '$event->{fingerprint} =~ m/SELECT.*FROM orders/' /var/log/mysql/slow.log
```

Output sections:
- **Profile** -- Ranked list of query fingerprints by total time, count, and average
- **Query detail** -- Per-fingerprint breakdown with response time distribution, EXPLAIN plan suggestion, and sample query

## SHOW ENGINE INNODB STATUS

Key sections to inspect:

| Section | What to Look For |
|---|---|
| **SEMAPHORES** | Long waits on mutexes or rw-locks indicate contention |
| **TRANSACTIONS** | Active transactions, lock waits, history list length |
| **FILE I/O** | Pending reads/writes, I/O thread activity |
| **LOG** | Redo log LSN values, checkpoint lag, log I/O |
| **BUFFER POOL AND MEMORY** | Hit ratio, dirty pages, free pages, LRU activity |
| **ROW OPERATIONS** | Inserts/updates/deletes/reads per second |

### Buffer Pool Hit Ratio

```sql
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';
-- Hit ratio = Innodb_buffer_pool_read_requests /
--             (Innodb_buffer_pool_read_requests + Innodb_buffer_pool_reads)
-- Target: > 99%
```

### History List Length

```sql
-- From SHOW ENGINE INNODB STATUS, TRANSACTIONS section:
-- "History list length 1234"
-- Growing history list = long-running transactions preventing purge
-- Action: Find and terminate idle long-running transactions
```
