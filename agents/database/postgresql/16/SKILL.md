---
name: database-postgresql-16
description: "PostgreSQL 16 version-specific expert. Deep knowledge of logical replication from standby, parallel VACUUM FULL/FREEZE, SQL/JSON constructors, SIMD acceleration, pg_stat_io improvements, and new system roles. WHEN: \"PostgreSQL 16\", \"Postgres 16\", \"PG 16\", \"pg16\", \"logical replication standby\", \"JSON_ARRAY\", \"JSON_OBJECT\", \"JSON_ARRAYAGG\", \"JSON_OBJECTAGG\", \"IS JSON\", \"pg_create_subscription\", \"parallel VACUUM\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# PostgreSQL 16 Expert

You are a specialist in PostgreSQL 16, released September 2023. You have deep knowledge of the features introduced in this version, particularly logical replication from standby servers, SQL/JSON constructors, parallel VACUUM improvements, and performance optimizations.

**Support status:** Actively supported with security and bug fix updates. EOL November 2028.

## Key Features Introduced in PostgreSQL 16

### Logical Replication from Standby

PostgreSQL 16 allows standby servers to act as publishers for logical replication. Previously, logical replication could only originate from the primary:

```
Primary ──streaming──> Standby ──logical──> Subscriber
                       (PG 16+)
```

**Setup on standby (publisher):**
```sql
-- On the primary: ensure wal_level = logical
ALTER SYSTEM SET wal_level = 'logical';
-- Restart required

-- On the standby: create publication (standby must have hot_standby_feedback = on)
-- postgresql.conf on standby:
-- hot_standby_feedback = on

-- The publication is created on the primary but replication slots
-- and WAL decoding happen on the standby
```

**Use cases:**
- Offload logical replication CPU/IO overhead from the primary
- Fan-out replication topology (primary -> standby -> multiple subscribers)
- Cross-version replication during migration from standby

**Limitations:**
- The standby must have `hot_standby_feedback = on`
- Failover of the standby requires manual replication slot recreation
- Slot positions may lag behind the standby's replay position

### Parallel VACUUM FULL and FREEZE

PostgreSQL 16 extends parallel processing to VACUUM FULL and VACUUM FREEZE operations:

```sql
-- Parallel VACUUM FULL (rebuilds table with multiple workers)
VACUUM (FULL, PARALLEL 4) large_table;

-- Parallel VACUUM FREEZE (freezes tuples with multiple workers)
VACUUM (FREEZE, PARALLEL 4) large_table;

-- Check parallel vacuum progress
SELECT pid, relid::regclass, phase, 
       heap_blks_total, heap_blks_scanned, heap_blks_vacuumed,
       num_dead_tuples
FROM pg_stat_progress_vacuum;
```

**Performance impact:** Parallel VACUUM FULL can reduce maintenance windows significantly for large tables. The parallelism applies to the index rebuild phase, which is typically the longest part.

### SQL/JSON Constructors

PostgreSQL 16 adds SQL-standard JSON constructor functions:

```sql
-- JSON_OBJECT: construct JSON object from key-value pairs
SELECT JSON_OBJECT('name': 'Alice', 'age': 30, 'active': true);
-- {"name":"Alice","age":30,"active":true}

-- JSON_ARRAY: construct JSON array from values
SELECT JSON_ARRAY(1, 'two', 3.0, null ABSENT ON NULL);
-- [1,"two",3.0]

SELECT JSON_ARRAY(1, 'two', 3.0, null NULL ON NULL);
-- [1,"two",3.0,null]

-- JSON_ARRAYAGG: aggregate rows into JSON array
SELECT JSON_ARRAYAGG(name ORDER BY name) FROM employees;
-- ["Alice","Bob","Charlie"]

-- JSON_OBJECTAGG: aggregate key-value pairs into JSON object
SELECT JSON_OBJECTAGG(dept_name: employee_count)
FROM (SELECT dept_name, count(*) AS employee_count
      FROM employees GROUP BY dept_name) sub;
-- {"Engineering":42,"Sales":15,"HR":8}

-- IS JSON predicate (enhanced from PG 15)
SELECT col IS JSON;
SELECT col IS JSON OBJECT;
SELECT col IS JSON ARRAY;
SELECT col IS JSON SCALAR;
SELECT col IS JSON WITH UNIQUE KEYS;

-- Combine with other queries
SELECT id, JSON_OBJECT(
    'name': name,
    'tags': JSON_ARRAY(tag1, tag2, tag3 ABSENT ON NULL)
) AS profile
FROM users;
```

### SIMD Acceleration

PostgreSQL 16 uses SIMD (Single Instruction, Multiple Data) CPU instructions for performance-critical operations:

- ASCII string operations (upper/lower case conversion)
- JSON parsing and validation
- Base64 encoding/decoding
- CRC computation

This is automatic and transparent -- no configuration needed. Performance improvements are most visible on workloads involving large text or JSON processing.

### Numeric Literal Underscores

PostgreSQL 16 allows underscores in integer and numeric constants for readability:

```sql
SELECT 1_000_000;           -- 1000000
SELECT 3.14_159_265;        -- 3.14159265
SELECT 0xFF_FF;             -- 65535
SELECT 0b1111_0000;         -- 240
SELECT 1_000_000::numeric;  -- 1000000
```

### New System Role: pg_create_subscription

A new predefined role that allows non-superusers to create logical replication subscriptions:

```sql
-- Grant subscription creation to a role
GRANT pg_create_subscription TO replication_admin;

-- Now replication_admin can create subscriptions without superuser
SET ROLE replication_admin;
CREATE SUBSCRIPTION my_sub
    CONNECTION 'host=publisher dbname=mydb'
    PUBLICATION my_pub;
```

### Improved Bulk Loading Performance

PostgreSQL 16 significantly improves COPY and INSERT performance:

- **COPY FROM** optimization: reduces overhead for large bulk loads
- **Binary COPY**: improved performance for binary format imports
- **WAL write optimization**: reduces WAL volume during bulk operations by optimizing full-page writes

```sql
-- Benchmark: COPY with PG 16 optimizations
COPY large_table FROM '/data/import.csv' WITH (FORMAT csv, HEADER true);
-- Expect 10-40% faster than PG 15 for large imports
```

### pg_stat_io Improvements

The pg_stat_io view (introduced in PG 15) gains additional metrics:

```sql
-- New in PG 16: extend operations and times
SELECT backend_type, object, context,
       reads, read_time,
       writes, write_time,
       extends, extend_time,    -- table extension I/O (new granularity)
       hits, evictions,
       fsyncs, fsync_time
FROM pg_stat_io
ORDER BY reads + writes DESC;
```

### Other Notable Features

- **CREATEROLE behavior change:** CREATEROLE can now manage roles it created but cannot manage superuser or other CREATEROLE roles. More restrictive than PG 15.
- **libpq load balancing:** `load_balance_hosts=random` in connection string distributes connections across multiple hosts
- **TLS certificate-based authentication improvements:** Subject and issuer DN matching
- **pg_stat_subscription_stats:** Enhanced statistics for logical replication subscribers
- **Allow logical replication of large transactions:** Streaming of in-progress transactions to subscribers (improved)
- **Regular expression improvements:** Performance optimizations for complex patterns

### libpq Load Balancing

```
# Connection string with load balancing
postgresql://host1,host2,host3/mydb?load_balance_hosts=random&target_session_attrs=read-write

# Distribute read queries across replicas
postgresql://primary,standby1,standby2/mydb?load_balance_hosts=random&target_session_attrs=read-only
```

## Version Boundaries

- **Not available in PG 16:** JSON_TABLE full support (PG 17), incremental backup (PG 17), MERGE RETURNING (PG 17), virtual generated columns (PG 18), UUIDv7 (PG 18), async I/O (PG 18), skip scan (PG 18), OAuth (PG 18)
- **New in PG 16 vs PG 15:** Logical replication from standby, parallel VACUUM FULL/FREEZE, SQL/JSON constructors, SIMD, numeric underscores, pg_create_subscription, improved bulk loading, libpq load balancing
- **Breaking changes from PG 15:** CREATEROLE behavior is more restrictive

## Common Pitfalls

1. **CREATEROLE behavior change** -- In PG 16, roles with CREATEROLE can only manage roles they created (or roles that have granted them ADMIN OPTION). Scripts that relied on CREATEROLE managing arbitrary non-superuser roles will fail. Review role management automation.

2. **Logical replication from standby requires hot_standby_feedback** -- Without `hot_standby_feedback = on`, the primary may remove WAL segments needed by the standby's logical replication slots, causing slot invalidation.

3. **JSON constructors vs jsonb_build_object** -- The new SQL/JSON constructors return `json` type by default. For `jsonb`, explicitly cast: `JSON_OBJECT('key': 'value')::jsonb`. The PostgreSQL-specific `jsonb_build_object()` returns `jsonb` directly.

4. **Parallel VACUUM FULL still locks the table** -- Parallel VACUUM FULL is faster but still acquires AccessExclusiveLock. It does not reduce downtime to zero. Use `pg_repack` for online table rewrites.

5. **Numeric underscore parsing in application code** -- If your application parses SQL or generates queries, ensure it can handle the `1_000_000` syntax. Older SQL parsers may reject it.

## Migration Notes

### Upgrading from PostgreSQL 15 to 16

Pre-upgrade checklist:
1. **Audit CREATEROLE usage** -- Check if any roles with CREATEROLE manage roles they did not create. Test role management scripts against PG 16.
2. **Test JSON constructor adoption** -- Consider replacing `json_build_object()` / `json_build_array()` with SQL-standard constructors for portability.
3. **Plan logical replication topology** -- If offloading to standby is desired, plan the `hot_standby_feedback` configuration.
4. **Review libpq connection strings** -- Consider adding `load_balance_hosts=random` for replica load balancing.

```sql
-- Check CREATEROLE roles
SELECT rolname, rolcreaterole FROM pg_roles WHERE rolcreaterole;

-- Post-upgrade: test role management
SET ROLE role_with_createrole;
ALTER ROLE some_other_role ...;  -- May fail in PG 16 if not admin
```

### Upgrading from PostgreSQL 16 to 17+

- MERGE gains RETURNING in PG 17 -- update upsert patterns that need result rows
- JSON_TABLE gains full support in PG 17
- Consider incremental backup support (PG 17) for backup strategy

## Reference Files

For deep technical details, load the parent technology agent's references:

- `../references/architecture.md` -- Process architecture, shared memory, WAL internals
- `../references/diagnostics.md` -- pg_stat views, EXPLAIN ANALYZE, lock analysis
- `../references/best-practices.md` -- Configuration tuning, backup, security
