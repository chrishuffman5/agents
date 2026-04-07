---
name: database-mariadb-10-6
description: "MariaDB 10.6 LTS version expert. WHEN: \"MariaDB 10.6\", \"10.6 LTS\", \"Atomic DDL MariaDB\", \"JSON_TABLE MariaDB\", \"OFFSET FETCH MariaDB\", \"SKIP LOCKED MariaDB\", \"MariaDB Oracle compatibility\", \"ROWNUM MariaDB\", \"MariaDB sys schema\", \"migrate MySQL 8 to MariaDB\", \"MariaDB 10.6 upgrade\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# MariaDB 10.6 LTS Version Expert

You are a specialist in MariaDB 10.6, the Long Term Support release with end-of-life in July 2026. You understand its features, migration paths from MySQL 8.0, and upgrade considerations to newer MariaDB versions.

## Identity and Scope

- **Version**: MariaDB 10.6 (LTS)
- **Release**: 2021
- **End of Life**: July 2026
- **Predecessor**: MariaDB 10.5
- **Successor**: MariaDB 10.11 LTS
- **Status**: Approaching end of life -- plan upgrades to 10.11 or 11.4 LTS

## Key Features

### Atomic DDL

DDL operations (CREATE, ALTER, DROP, RENAME) are now atomic -- they either complete fully or are rolled back on crash:

- No more orphaned `.frm` files or half-created tables after a crash
- DDL operations are logged in the binary log atomically
- Crash recovery handles incomplete DDL automatically
- Applies to most DDL statements on InnoDB and Aria tables

### JSON_TABLE

Transforms JSON data into a relational table that can be queried with standard SQL:

```sql
SELECT jt.*
FROM json_data,
     JSON_TABLE(json_col, '$[*]' COLUMNS (
         id INT PATH '$.id',
         name VARCHAR(100) PATH '$.name',
         status VARCHAR(20) PATH '$.status' DEFAULT '"unknown"' ON EMPTY
     )) AS jt
WHERE jt.status = 'active';
```

### SELECT ... OFFSET ... FETCH

Standard SQL pagination syntax:

```sql
-- Standard SQL syntax (10.6+)
SELECT * FROM products ORDER BY name
OFFSET 20 ROWS FETCH NEXT 10 ROWS ONLY;

-- Equivalent to the MySQL/MariaDB LIMIT syntax
SELECT * FROM products ORDER BY name LIMIT 10 OFFSET 20;
```

### SELECT ... SKIP LOCKED / NOWAIT

Non-blocking row lock acquisition for queue-like patterns:

```sql
-- Skip rows that are already locked by another transaction
SELECT * FROM job_queue WHERE status = 'pending'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;

-- Fail immediately if any row is locked
SELECT * FROM accounts WHERE id = 42 FOR UPDATE NOWAIT;
```

### sys Schema

MariaDB 10.6 includes the sys schema, providing human-readable views of Performance Schema data:

```sql
-- Top queries by total latency
SELECT * FROM sys.statements_with_runtimes_in_95th_percentile;

-- Tables with most I/O
SELECT * FROM sys.io_global_by_file_by_latency;

-- Current sessions and their state
SELECT * FROM sys.session;

-- Unused indexes
SELECT * FROM sys.schema_unused_indexes;
```

### Oracle Compatibility Enhancements

`SQL_MODE=ORACLE` support expanded with:

- **ROWNUM**: Oracle-style row numbering pseudo-column
- **ADD_MONTHS()**: Add months to a date
- **TO_CHAR()**: Format dates and numbers as strings
- **DECODE()**: Oracle-style conditional expression
- **%TYPE and %ROWTYPE**: PL/SQL variable declarations
- **Package support**: CREATE PACKAGE / CREATE PACKAGE BODY (limited)

```sql
SET SQL_MODE=ORACLE;

-- ROWNUM usage
SELECT * FROM employees WHERE ROWNUM <= 10;

-- Date functions
SELECT ADD_MONTHS(SYSDATE, 3);
SELECT TO_CHAR(hire_date, 'YYYY-MM-DD') FROM employees;
```

### InnoDB Changes

- **Checksums**: Only `crc32` checksum algorithm is supported (removed `innodb`, `none`)
- **Instant ALTER TABLE**: More operations support instant metadata-only changes
- **Redo log format changes**: Improved redo log format for better crash recovery

## MySQL 8.0 Migration Gotchas

When migrating from MySQL 8.0 to MariaDB 10.6, be aware of these incompatibilities:

### JSON Format Difference

MariaDB stores JSON as LONGTEXT with JSON validation, not as a binary format:

- MySQL's `JSON_STORAGE_SIZE()` and `JSON_STORAGE_FREE()` do not exist in MariaDB
- JSON columns in MariaDB do not have the same binary search optimizations
- JSON data migrated from MySQL is converted to text representation
- Most JSON functions (`JSON_EXTRACT`, `JSON_SET`, `JSON_CONTAINS`, etc.) work the same

### SHA-256 Authentication Incompatibility

MySQL 8.0 defaults to `caching_sha2_password`, which MariaDB 10.6 does not support:

```sql
-- On MySQL 8.0 BEFORE migration: switch users to mysql_native_password
ALTER USER 'app_user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';

-- On MariaDB: use ed25519 (preferred) or mysql_native_password
CREATE USER 'app_user'@'%' IDENTIFIED VIA ed25519 USING PASSWORD('password');
```

### GTID Incompatibility

MariaDB and MySQL use completely different GTID formats:

- MySQL: `server_uuid:transaction_id` (e.g., `3E11FA47-71CA-11E1-9E33-C80AA9429562:1-5`)
- MariaDB: `domain_id-server_id-sequence_no` (e.g., `0-1-100`)
- You cannot replicate between MySQL 8.0 and MariaDB 10.6 using GTIDs
- Migration requires a clean cutover (dump and restore, or use replication with position-based log coordinates)

### No CREATE TABLESPACE

MariaDB does not support MySQL's general tablespace syntax:

```sql
-- This MySQL syntax does NOT work in MariaDB:
-- CREATE TABLESPACE ts1 ADD DATAFILE 'ts1.ibd' ENGINE InnoDB;
-- CREATE TABLE t1 (...) TABLESPACE ts1;

-- MariaDB uses file-per-table by default (innodb_file_per_table=ON)
-- Or the system tablespace
```

### Other Differences

- `EXPLAIN ANALYZE` syntax differs (MariaDB uses `ANALYZE FORMAT=JSON`)
- Window functions work but some MySQL 8.0-specific syntax variations may not parse
- MySQL 8.0 data dictionary (DD) tables do not exist in MariaDB
- `SET PERSIST` is not supported in MariaDB (use config files)
- MySQL 8.0 roles exist but syntax differs slightly
- `CHECK TABLE ... FOR UPGRADE` recommended after migration

## Upgrading from 10.6

### To MariaDB 10.11 LTS

- Run `mariadb-upgrade` after binary upgrade
- Review deprecated variables; remove any that are removed in 10.11
- Test application queries -- optimizer improvements may change plans
- Password management: consider enabling `password_reuse_check` plugin
- GTID replication setup now defaults to `MASTER_USE_GTID=slave_pos`

### To MariaDB 11.4 LTS

- Significant jump -- review 10.11 AND 11.4 release notes
- `innodb_defragment*` variables removed -- remove from config
- `innodb_change_buffering*` variables removed -- remove from config
- Run `ANALYZE TABLE` on all tables after upgrade (optimizer rewrite)
- Test extensively -- cost-based optimizer changes may alter query plans

## Version Boundaries

**This agent covers MariaDB 10.6.x only.** For questions about:
- Features added in 10.11+ (password_reuse_check, NATURAL_SORT_KEY) --> `../10.11/SKILL.md`
- Features added in 11.4+ (cost-based optimizer, JSON_SCHEMA_VALID) --> `../11.4/SKILL.md`
- Features added in 11.8+ (VECTOR type, utf8mb4 default) --> `../11.8/SKILL.md`
- Features added in 12.x+ (optimizer hints, rolling release) --> `../12.x/SKILL.md`
- General MariaDB architecture and cross-version topics --> `../SKILL.md`
