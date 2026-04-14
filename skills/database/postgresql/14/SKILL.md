---
name: database-postgresql-14
description: "PostgreSQL 14 version-specific expert. Deep knowledge of multirange types, stored procedure OUT parameters, CTE SEARCH/CYCLE, pipeline mode, and PG 14 monitoring improvements. WHEN: \"PostgreSQL 14\", \"Postgres 14\", \"PG 14\", \"pg14\", \"multirange\", \"pg_stat_wal\", \"pg_stat_replication_slots\", \"SEARCH clause CTE\", \"CYCLE clause CTE\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# PostgreSQL 14 Expert

You are a specialist in PostgreSQL 14, released October 2021. You have deep knowledge of the features introduced in this version, its behavioral changes, and its operational characteristics. PostgreSQL 14 reaches end-of-life in November 2026.

**Support status:** Actively supported with security and bug fix updates. EOL November 2026 -- plan migrations to 16+ before this date.

## Key Features Introduced in PostgreSQL 14

### Multirange Types

PostgreSQL 14 introduces multirange types -- a set of non-overlapping, non-adjacent ranges stored as a single value. Every built-in range type now has a corresponding multirange type:

| Range Type | Multirange Type |
|---|---|
| `int4range` | `int4multirange` |
| `int8range` | `int8multirange` |
| `numrange` | `nummultirange` |
| `tsrange` | `tsmultirange` |
| `tstzrange` | `tstzmultirange` |
| `daterange` | `datemultirange` |

```sql
-- Create a multirange value
SELECT '{[1,3), [5,8), [10,15)}'::int4multirange;

-- Containment check
SELECT '{[1,5), [10,20)}'::int4multirange @> 12;  -- true

-- Union of multiranges
SELECT '{[1,5)}'::int4multirange + '{[3,8)}'::int4multirange;
-- Result: {[1,8)}

-- Intersection
SELECT '{[1,10)}'::int4multirange * '{[5,15)}'::int4multirange;
-- Result: {[5,10)}

-- Use in scheduling: find all available time slots
CREATE TABLE availability (
    employee_id int,
    available tstzmultirange
);

INSERT INTO availability VALUES
    (1, '{[2025-06-01 09:00, 2025-06-01 12:00), [2025-06-01 13:00, 2025-06-01 17:00)}');

-- Find employees available at a specific time
SELECT employee_id FROM availability
WHERE available @> '2025-06-01 10:00'::timestamptz;
```

### Stored Procedures with OUT Parameters

Stored procedures (introduced in PG 11) now support OUT parameters, making them more interoperable with applications that expect output from procedure calls:

```sql
CREATE PROCEDURE transfer_funds(
    IN from_account int,
    IN to_account int,
    IN amount numeric,
    OUT new_from_balance numeric,
    OUT new_to_balance numeric
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE accounts SET balance = balance - amount
        WHERE id = from_account
        RETURNING balance INTO new_from_balance;

    UPDATE accounts SET balance = balance + amount
        WHERE id = to_account
        RETURNING balance INTO new_to_balance;

    IF new_from_balance < 0 THEN
        RAISE EXCEPTION 'Insufficient funds';
    END IF;
END;
$$;

CALL transfer_funds(1, 2, 100.00, NULL, NULL);
```

### SEARCH and CYCLE Clauses for Recursive CTEs

SQL-standard syntax for controlling recursive CTE traversal:

```sql
-- SEARCH: control traversal order
-- Breadth-first search (level by level)
WITH RECURSIVE org_chart AS (
    SELECT id, name, manager_id, 1 AS depth
    FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, e.manager_id, oc.depth + 1
    FROM employees e JOIN org_chart oc ON e.manager_id = oc.id
)
SEARCH BREADTH FIRST BY id SET ordercol
SELECT * FROM org_chart ORDER BY ordercol;

-- Depth-first search (follow each branch)
WITH RECURSIVE org_chart AS (
    SELECT id, name, manager_id
    FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, e.manager_id
    FROM employees e JOIN org_chart oc ON e.manager_id = oc.id
)
SEARCH DEPTH FIRST BY id SET ordercol
SELECT * FROM org_chart ORDER BY ordercol;

-- CYCLE: detect and handle cycles
WITH RECURSIVE graph_walk AS (
    SELECT id, linked_to, ARRAY[id] AS path
    FROM graph WHERE id = 1
    UNION ALL
    SELECT g.id, g.linked_to, gw.path || g.id
    FROM graph g JOIN graph_walk gw ON g.id = gw.linked_to
)
CYCLE id SET is_cycle USING path
SELECT * FROM graph_walk WHERE NOT is_cycle;
```

### Parallelism Improvements

PostgreSQL 14 extends parallel query to more operations:

- **RETURN QUERY** in PL/pgSQL functions now supports parallel execution of the underlying query
- **REFRESH MATERIALIZED VIEW CONCURRENTLY** can now use parallel plans
- **Parallel sequential scan** improvements for better load balancing across workers

### Connection Pipeline Mode (libpq)

libpq now supports pipeline mode for sending multiple queries without waiting for each response:

```c
/* C application example */
PQenterPipelineMode(conn);

PQsendQueryParams(conn, "INSERT INTO t VALUES($1)", 1, NULL, v1, NULL, NULL, 0);
PQsendQueryParams(conn, "INSERT INTO t VALUES($1)", 1, NULL, v2, NULL, NULL, 0);
PQsendQueryParams(conn, "INSERT INTO t VALUES($1)", 1, NULL, v3, NULL, NULL, 0);
PQpipelineSync(conn);

/* Process all results */
while ((res = PQgetResult(conn)) != NULL) { /* ... */ }

PQexitPipelineMode(conn);
```

This dramatically reduces network round-trip overhead for applications that issue many small statements. JDBC and other drivers have added pipeline support in their PG 14+ releases.

### Performance Monitoring Improvements

**pg_stat_wal** (new view):
```sql
-- Monitor WAL generation
SELECT wal_records, wal_fpi, wal_bytes,
       pg_size_pretty(wal_bytes) AS wal_human,
       wal_buffers_full, wal_write, wal_sync
FROM pg_stat_wal;
```

**pg_stat_replication_slots** (new view):
```sql
-- Monitor replication slot activity
SELECT slot_name, slot_type,
       total_txns, total_bytes,
       pg_size_pretty(total_bytes) AS total_human
FROM pg_stat_replication_slots;
```

**pg_stat_progress_copy** (new -- COPY progress):
```sql
-- Monitor COPY progress
SELECT pid, relid::regclass, command, type,
       bytes_processed, bytes_total, tuples_processed, tuples_excluded
FROM pg_stat_progress_copy;
```

### Other Notable Features

- **LZ4 TOAST compression**: `ALTER TABLE t ALTER COLUMN c SET COMPRESSION lz4;` -- faster than pglz
- **Idle session timeout**: `idle_session_timeout` terminates sessions idle for too long (distinct from `idle_in_transaction_session_timeout`)
- **Predefined roles**: `pg_read_all_data`, `pg_write_all_data` for granting broad read/write access
- **REINDEX CONCURRENTLY for system catalogs**: previously only user tables
- **Range type GiST and SP-GiST improvements**: multirange indexing support

## Version Boundaries

- **Not available in PG 14:** MERGE command (PG 15), pg_stat_io (PG 16), logical replication from standby (PG 16), incremental backup (PG 17), JSON_TABLE (PG 17), virtual generated columns (PG 18), UUIDv7 (PG 18)
- **New in PG 14 vs PG 13:** Multirange types, pg_stat_wal, pg_stat_replication_slots, SEARCH/CYCLE for CTEs, stored procedure OUT params, pipeline mode, LZ4 TOAST compression
- **Deprecated in PG 14:** `postmaster` command name deprecated in favor of `postgres`

## Common Pitfalls

1. **Multirange vs range confusion** -- Multirange operators are different from range operators. `@>` on a multirange checks containment across all sub-ranges. Check documentation for operator differences.

2. **Pipeline mode requires driver support** -- The PostgreSQL server has supported pipeline mode since PG 14, but your application driver (JDBC, psycopg, etc.) must also support it. Check your driver version.

3. **LZ4 compression requires initdb support** -- LZ4 TOAST compression for new columns works without special setup, but LZ4 WAL compression requires the server to be built with LZ4 support.

4. **idle_session_timeout kills all idle sessions** -- Unlike `idle_in_transaction_session_timeout`, `idle_session_timeout` terminates sessions that are idle between queries, which may break connection poolers. Test carefully.

## Migration Notes

### Upgrading from PostgreSQL 13 to 14

- Run `pg_upgrade` with `--check` first to identify issues
- Review application queries for any behavioral changes in the planner
- Update connection drivers to versions that support pipeline mode (optional but recommended)
- Consider enabling LZ4 TOAST compression on large text/jsonb columns after upgrade
- Review `pg_hba.conf` -- no breaking auth changes in PG 14
- Post-upgrade: run `ANALYZE` on all databases to rebuild statistics

### Upgrading from PostgreSQL 14 to 15+

- **Critical:** PG 15 revokes CREATE on the public schema by default. Test application DDL before upgrading.
- Review any usage of `CREATEROLE` -- PG 16 changes its behavior
- Consider adopting the MERGE command (PG 15) for upsert patterns

## Reference Files

For deep technical details, load the parent technology agent's references:

- `../references/architecture.md` -- Process architecture, shared memory, WAL internals
- `../references/diagnostics.md` -- pg_stat views, EXPLAIN ANALYZE, lock analysis
- `../references/best-practices.md` -- Configuration tuning, backup, security
