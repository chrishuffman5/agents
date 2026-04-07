# MariaDB Diagnostics Reference

## Performance Schema

Performance Schema provides low-level instrumentation of the server:

```sql
-- Check if enabled
SHOW VARIABLES LIKE 'performance_schema';

-- Active queries and their wait events
SELECT THREAD_ID, EVENT_NAME, TIMER_WAIT/1000000000 AS wait_sec, SQL_TEXT
FROM performance_schema.events_statements_current
WHERE SQL_TEXT IS NOT NULL;

-- Top wait events
SELECT EVENT_NAME, COUNT_STAR, SUM_TIMER_WAIT/1000000000 AS total_sec
FROM performance_schema.events_waits_summary_global_by_event_name
WHERE COUNT_STAR > 0
ORDER BY SUM_TIMER_WAIT DESC LIMIT 20;

-- Table I/O statistics
SELECT OBJECT_SCHEMA, OBJECT_NAME, COUNT_READ, COUNT_WRITE,
       SUM_TIMER_READ/1000000000 AS read_sec,
       SUM_TIMER_WRITE/1000000000 AS write_sec
FROM performance_schema.table_io_waits_summary_by_table
ORDER BY SUM_TIMER_WAIT DESC LIMIT 20;

-- Mutex contention
SELECT EVENT_NAME, COUNT_STAR, SUM_TIMER_WAIT/1000000000 AS total_sec
FROM performance_schema.events_waits_summary_global_by_event_name
WHERE EVENT_NAME LIKE 'wait/synch/mutex%' AND COUNT_STAR > 0
ORDER BY SUM_TIMER_WAIT DESC LIMIT 10;
```

## ANALYZE FORMAT=JSON

MariaDB's enhanced execution plan output includes actual runtime statistics:

```sql
ANALYZE FORMAT=JSON
SELECT o.order_id, c.name
FROM orders o JOIN customers c ON o.customer_id = c.id
WHERE o.status = 'pending';
```

**Key fields to examine:**

| Field | Meaning | What to Look For |
|---|---|---|
| `r_loops` | Actual number of iterations | Compare with `loops` (estimated) |
| `r_rows` | Actual rows returned | Compare with `rows` (estimated); large gap = stale stats |
| `r_total_time_ms` | Actual wall-clock time (ms) | Identifies the slowest operations |
| `r_buffer_size` | Actual memory used for buffering | Detect operations spilling to disk |
| `r_filtered` | Actual percentage of rows passing filter | Low values suggest missing index |
| `r_engine_stats` | InnoDB engine-level stats | Pages read, undo records |

**Diagnosing stale statistics:**
```sql
-- If r_rows >> rows, statistics are stale
ANALYZE TABLE orders;
ANALYZE TABLE customers;
-- Then re-run ANALYZE FORMAT=JSON to verify improvement
```

## EXPLAIN

Standard execution plan (estimated, not actual):

```sql
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
EXPLAIN EXTENDED SELECT * FROM orders WHERE status = 'active';
```

Key columns:
- `type`: Join type (system > const > eq_ref > ref > range > index > ALL)
- `possible_keys`: Indexes the optimizer considered
- `key`: Index actually chosen
- `rows`: Estimated rows to examine
- `Extra`: Important flags (Using where, Using index, Using temporary, Using filesort)

**Red flags in Extra:**
- `Using temporary` -- Query requires a temp table (common with GROUP BY on non-indexed columns)
- `Using filesort` -- Sort cannot use an index; consider adding one
- `Using where` with `type=ALL` -- Full table scan with row filtering; needs an index

## Slow Query Log

```sql
-- Enable slow query log
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 1;          -- seconds
SET GLOBAL log_queries_not_using_indexes = ON;
SET GLOBAL log_slow_admin_statements = ON;

-- Check configuration
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';

-- View slow query log location
SHOW VARIABLES LIKE 'slow_query_log_file';
```

Use `pt-query-digest` (Percona Toolkit) to analyze the slow query log:
```bash
pt-query-digest /var/log/mysql/mariadb-slow.log
```

## Galera Cluster Monitoring

### Essential wsrep Status Variables

```sql
-- Cluster health snapshot
SHOW STATUS LIKE 'wsrep_%';

-- Key variables to check:
SELECT VARIABLE_NAME, VARIABLE_VALUE
FROM information_schema.GLOBAL_STATUS
WHERE VARIABLE_NAME IN (
    'wsrep_cluster_size',
    'wsrep_cluster_status',
    'wsrep_local_state_comment',
    'wsrep_ready',
    'wsrep_connected',
    'wsrep_flow_control_paused',
    'wsrep_local_recv_queue_avg',
    'wsrep_local_send_queue_avg',
    'wsrep_cert_deps_distance',
    'wsrep_last_committed'
);
```

**Variable interpretation:**

| Variable | Healthy Value | Alarm Condition |
|---|---|---|
| `wsrep_cluster_size` | Expected node count | Less than expected (node down) |
| `wsrep_cluster_status` | `Primary` | `Non-Primary` = quorum lost |
| `wsrep_local_state_comment` | `Synced` | `Donor`, `Joining`, `Disconnected` |
| `wsrep_ready` | `ON` | `OFF` = node cannot accept queries |
| `wsrep_connected` | `ON` | `OFF` = node disconnected from cluster |
| `wsrep_flow_control_paused` | < 0.01 | > 0.1 = cluster frequently stalled |
| `wsrep_local_recv_queue_avg` | < 1.0 | > 5.0 = node applying too slowly |
| `wsrep_local_send_queue_avg` | < 1.0 | > 1.0 = network bottleneck |
| `wsrep_cert_deps_distance` | High | Low = limited parallelism |

### Detecting Galera Conflicts

```sql
-- Certification failures (BF aborts)
SHOW STATUS LIKE 'wsrep_local_bf_aborts';
SHOW STATUS LIKE 'wsrep_local_cert_failures';

-- If these values are climbing, you have write-write conflicts
-- Diagnose by examining which tables are written concurrently on multiple nodes
```

## InnoDB Status and Diagnostics

```sql
-- Full InnoDB status report
SHOW ENGINE INNODB STATUS\G

-- Key sections to examine:
-- SEMAPHORES: mutex/lock waits (high waits = contention)
-- TRANSACTIONS: active transactions, lock waits, deadlocks
-- BUFFER POOL AND MEMORY: hit rate, pages read/written
-- LOG: redo log sequence numbers, checkpoint age
-- ROW OPERATIONS: rows inserted/updated/deleted/read per second
```

**Buffer pool hit ratio:**
```sql
SELECT
  (1 - (Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests)) * 100
  AS buffer_pool_hit_ratio
FROM (
  SELECT
    VARIABLE_VALUE AS Innodb_buffer_pool_reads
  FROM information_schema.GLOBAL_STATUS
  WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads'
) a, (
  SELECT
    VARIABLE_VALUE AS Innodb_buffer_pool_read_requests
  FROM information_schema.GLOBAL_STATUS
  WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'
) b;
-- Target: > 99%
```

## Diagnostic Tools

### Percona Toolkit

| Tool | Purpose |
|---|---|
| `pt-query-digest` | Analyze slow query log, general log, or tcpdump |
| `pt-online-schema-change` | ALTER TABLE without blocking (for pre-Atomic DDL versions) |
| `pt-table-checksum` | Verify replication consistency |
| `pt-deadlock-logger` | Monitor and log deadlocks |
| `pt-stalk` | Collect diagnostics when a condition triggers |
| `pt-summary` | System summary report |
| `pt-mysql-summary` | MariaDB/MySQL configuration and status summary |

### MySQLTuner

```bash
mysqltuner --host 127.0.0.1 --user root --pass secret
```

Provides recommendations for:
- Buffer pool sizing
- Query cache (if still enabled on older versions)
- Thread configuration
- Slow query analysis
- Security hardening

### PMM (Percona Monitoring and Management)

PMM provides dashboards and query analytics for MariaDB:
- Query Analytics (QAN): ranks queries by total time, calls, rows
- Node-level metrics: CPU, memory, disk, network
- MariaDB dashboards: InnoDB metrics, replication lag, connections
- Galera dashboards: cluster size, flow control, queue lengths
- Alerting integration with Grafana
