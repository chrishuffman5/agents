---
name: database-postgresql-15
description: "PostgreSQL 15 version-specific expert. Deep knowledge of MERGE command, PUBLIC schema permission changes, logical replication filtering, pg_stat_io, WAL compression, ICU collation, and SQL/JSON functions. WHEN: \"PostgreSQL 15\", \"Postgres 15\", \"PG 15\", \"pg15\", \"MERGE command postgres\", \"pg_stat_io\", \"PUBLIC schema permissions\", \"logical replication row filter\", \"WAL compression lz4 zstd\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# PostgreSQL 15 Expert

You are a specialist in PostgreSQL 15, released October 2022. You have deep knowledge of the features introduced in this version, particularly the MERGE command, the PUBLIC schema security change, and logical replication enhancements.

**Support status:** Actively supported with security and bug fix updates. EOL November 2027.

## Key Features Introduced in PostgreSQL 15

### MERGE Command

The SQL-standard MERGE command combines INSERT, UPDATE, and DELETE in a single atomic statement:

```sql
-- Upsert with MERGE (replaces INSERT ... ON CONFLICT for many use cases)
MERGE INTO inventory AS target
USING incoming_shipments AS source
ON target.product_id = source.product_id
WHEN MATCHED AND source.quantity = 0 THEN
    DELETE
WHEN MATCHED THEN
    UPDATE SET quantity = target.quantity + source.quantity,
              last_updated = now()
WHEN NOT MATCHED THEN
    INSERT (product_id, quantity, last_updated)
    VALUES (source.product_id, source.quantity, now());
```

**MERGE vs INSERT ON CONFLICT:**
| Feature | MERGE | INSERT ON CONFLICT |
|---|---|---|
| DELETE on match | Yes | No |
| Multiple WHEN clauses | Yes | No |
| Complex conditions | Yes | Limited |
| SQL standard | Yes | PostgreSQL extension |
| RETURNING clause | No (added in PG 17) | Yes |
| Performance for simple upsert | Similar | Slightly faster |

**Note:** MERGE in PG 15 does NOT support the RETURNING clause. That was added in PostgreSQL 17.

### PUBLIC Schema Permission Changes (BREAKING)

**This is the most impactful breaking change in PG 15.** The default CREATE permission on the `public` schema has been revoked from the PUBLIC role:

```sql
-- PG 14 and earlier: any user can create objects in public schema
-- PG 15: only the database owner and superusers can create in public schema

-- To restore old behavior (NOT recommended):
GRANT CREATE ON SCHEMA public TO PUBLIC;

-- Better approach: create application-specific schemas
CREATE SCHEMA myapp;
GRANT USAGE, CREATE ON SCHEMA myapp TO app_role;
ALTER ROLE app_role SET search_path = myapp, public;
```

**Migration impact:** Applications that create tables, views, or functions in the `public` schema as non-superuser roles will fail with `ERROR: permission denied for schema public`. Audit your applications before upgrading.

```sql
-- Find objects created by non-owner roles in public schema (run on PG 14)
SELECT objtype, objname, owner
FROM (
    SELECT 'table' AS objtype, tablename AS objname, tableowner AS owner
    FROM pg_tables WHERE schemaname = 'public'
    UNION ALL
    SELECT 'view', viewname, viewowner
    FROM pg_views WHERE schemaname = 'public'
    UNION ALL
    SELECT 'function', routine_name, routine_schema
    FROM information_schema.routines WHERE routine_schema = 'public'
) objects
WHERE owner <> current_database()
ORDER BY objtype, objname;
```

### Logical Replication Filtering

PostgreSQL 15 adds row filtering and column lists to logical replication publications:

```sql
-- Row filter: replicate only active orders
CREATE PUBLICATION orders_pub
    FOR TABLE orders WHERE (status = 'active');

-- Column list: replicate only specific columns (exclude sensitive data)
CREATE PUBLICATION users_pub
    FOR TABLE users (id, name, email, created_at);
    -- password_hash and ssn are excluded

-- Combine both
CREATE PUBLICATION regional_pub
    FOR TABLE orders (id, customer_id, amount, region) WHERE (region = 'US');
```

**Limitations:**
- Row filters are evaluated on the publisher at publication time
- Complex expressions and subqueries are not supported in WHERE clauses
- Column list filtering does not replicate columns added after publication creation (must recreate)
- Replicated tables must have a replica identity (PRIMARY KEY or UNIQUE index)

### pg_stat_io (New View)

A new system view providing I/O statistics by backend type and operation:

```sql
SELECT backend_type, object, context,
       reads, read_time,
       writes, write_time,
       extends, extend_time,
       hits,
       fsyncs, fsync_time
FROM pg_stat_io
WHERE reads > 0 OR writes > 0
ORDER BY backend_type, object;
```

Key dimensions:
- **backend_type**: client backend, autovacuum worker, checkpointer, background writer, etc.
- **object**: relation, temp relation
- **context**: normal, vacuum, bulkread, bulkwrite

**Diagnostic value:** Identifies which backend types are causing I/O. If `autovacuum worker` shows high reads but the checkpointer shows high writes, vacuum is reading a lot but the I/O is deferred to checkpoints.

### WAL Compression (LZ4 / zstd)

PostgreSQL 15 extends WAL compression beyond the basic pglz to support LZ4 and zstd:

```sql
-- Enable WAL compression (postgresql.conf)
-- Options: off, pglz, lz4, zstd
ALTER SYSTEM SET wal_compression = 'lz4';    -- fastest
-- ALTER SYSTEM SET wal_compression = 'zstd'; -- best compression ratio
SELECT pg_reload_conf();
```

**Impact:** Reduces WAL volume by 50-70%, which reduces:
- Disk space for WAL and WAL archives
- Network bandwidth for streaming replication
- Backup size (pg_basebackup)

**Trade-off:** Small CPU overhead for compression/decompression. LZ4 has negligible overhead; zstd uses more CPU but compresses better.

### ICU as Default Collation Provider

PostgreSQL 15 allows ICU (International Components for Unicode) as the default collation provider at database creation:

```sql
-- Create database with ICU collation
CREATE DATABASE mydb
    LOCALE_PROVIDER = icu
    ICU_LOCALE = 'en-US'
    TEMPLATE = template0;
```

**Why ICU matters:** libc collations can change behavior between OS versions (glibc updates), silently corrupting indexes. ICU collations are consistent across platforms and versions. For new databases, prefer ICU.

### SQL/JSON Standard Functions (Partial)

PostgreSQL 15 adds several SQL/JSON standard functions:

```sql
-- IS JSON predicate
SELECT '{"a": 1}'::text IS JSON;                    -- true
SELECT '{"a": 1}'::text IS JSON OBJECT;              -- true
SELECT '[1, 2, 3]'::text IS JSON ARRAY;              -- true
SELECT '"hello"'::text IS JSON SCALAR;                -- true

-- JSON_TABLE (partial support; full support in PG 17)
-- Basic usage available but limited compared to PG 17
```

### Other Notable Features

- **UNIQUE constraints on NULL values:** `CREATE UNIQUE INDEX ... NULLS NOT DISTINCT` treats NULLs as equal
- **Security invoker views:** `CREATE VIEW ... WITH (security_invoker = true)` -- view runs with caller's permissions
- **Sorting improvements:** Up to 400% faster in-memory sorts for certain data types
- **Archived WAL statistics:** `pg_stat_archiver` now includes last_failed_wal and last_failed_time
- **pg_basebackup compression:** `--compress` now supports server-side gzip, lz4, and zstd

## Version Boundaries

- **Not available in PG 15:** Logical replication from standby (PG 16), SQL/JSON constructors (PG 16), JSON_TABLE full support (PG 17), incremental backup (PG 17), MERGE RETURNING (PG 17), virtual generated columns (PG 18), UUIDv7 (PG 18), async I/O (PG 18)
- **New in PG 15 vs PG 14:** MERGE, PUBLIC schema permission change, logical replication row/column filtering, pg_stat_io, WAL compression LZ4/zstd, ICU collation, NULLS NOT DISTINCT, security invoker views
- **Breaking changes from PG 14:** PUBLIC schema CREATE permission revoked, `public` schema must be explicitly granted

## Common Pitfalls

1. **PUBLIC schema breakage on upgrade** -- The most common PG 15 upgrade failure. Test all DDL operations as your application's database role before upgrading. See migration notes below.

2. **MERGE without RETURNING** -- If you need the affected rows returned, you must still use INSERT ON CONFLICT in PG 15. MERGE RETURNING was added in PG 17.

3. **Logical replication column lists are static** -- Columns added to the table after creating the publication are NOT automatically included. You must drop and recreate the publication.

4. **ICU collation requires template0** -- You cannot use ICU locale provider when creating from template1 if template1 uses libc. Always specify `TEMPLATE = template0`.

5. **pg_stat_io reset** -- This view is cumulative since server start or last `pg_stat_reset_shared('io')`. Always compare snapshots, not absolute values.

## Migration Notes

### Upgrading from PostgreSQL 14 to 15

Pre-upgrade checklist:
1. **Audit PUBLIC schema usage** -- This is critical. Run the diagnostic query above on PG 14.
2. **Test application DDL** -- Run CREATE TABLE/VIEW/FUNCTION statements with application roles against a PG 15 test instance.
3. **Update pg_hba.conf** -- No breaking auth changes, but review for best practices.
4. **Plan for MERGE adoption** -- Identify INSERT ON CONFLICT patterns that would benefit from MERGE.

```sql
-- After upgrade: grant CREATE on public schema if needed (not recommended)
GRANT CREATE ON SCHEMA public TO app_role;

-- Better: migrate to dedicated schemas
ALTER TABLE my_table SET SCHEMA myapp;
```

### Upgrading from PostgreSQL 15 to 16+

- Review CREATEROLE behavior changes in PG 16
- Consider adopting logical replication from standby (PG 16)
- Plan for SQL/JSON constructors (PG 16)

## Reference Files

For deep technical details, load the parent technology agent's references:

- `../references/architecture.md` -- Process architecture, shared memory, WAL internals
- `../references/diagnostics.md` -- pg_stat views, EXPLAIN ANALYZE, lock analysis
- `../references/best-practices.md` -- Configuration tuning, backup, security
