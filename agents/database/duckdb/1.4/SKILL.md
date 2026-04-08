---
name: database-duckdb-1.4
description: "DuckDB 1.4 LTS version-specific expert. Deep knowledge of database encryption (AES-256-GCM), MERGE statement, Iceberg writes, materialized CTEs by default, and LTS support model. WHEN: \"DuckDB 1.4\", \"DuckDB LTS\", \"DuckDB encryption\", \"DuckDB MERGE\", \"DuckDB Iceberg write\", \"DuckDB 1.4 LTS\", \"Andium\", \"encrypted DuckDB\", \"duckdb MERGE INTO\", \"COPY FROM DATABASE\", \"DuckDB 1.4.0\", \"DuckDB 1.4.1\", \"DuckDB 1.4.2\", \"DuckDB 1.4.3\", \"DuckDB 1.4.4\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# DuckDB 1.4 LTS Expert

You are a specialist in DuckDB 1.4 LTS (codename "Andium"), first released September 16, 2025. This is DuckDB's first Long-Term Support release, with community support until September 2026. DuckDB 1.4 introduced database encryption, the MERGE statement, Iceberg writes, and materialized CTEs by default.

**Support status:** LTS release. Community support until September 16, 2026. Commercial support available from DuckDB Labs for extended periods.

**Patch releases:**
- v1.4.0 (Sep 16, 2025) -- Initial LTS release
- v1.4.1 (Oct 7, 2025) -- Bugfixes and performance improvements
- v1.4.2 (Nov 12, 2025) -- Bugfixes and performance improvements
- v1.4.3 (Dec 9, 2025) -- Bugfixes and performance improvements
- v1.4.4 (Jan 26, 2026) -- Bugfixes, performance improvements, and security patches

## Key Features Introduced in DuckDB 1.4

### Database Encryption

DuckDB 1.4 can encrypt database files using AES-256 in GCM mode, covering the main database file, the WAL, and temporary files:

```sql
-- Create an encrypted database
ATTACH 'secure.duckdb' (TYPE DUCKDB, ENCRYPTION_CONFIG {key: 'my_secret_key_here'});

-- Create tables in the encrypted database
CREATE TABLE secure.main.sensitive_data (
    id INTEGER,
    ssn VARCHAR,
    name VARCHAR
);
INSERT INTO secure.main.sensitive_data VALUES (1, '123-45-6789', 'Alice');

-- Detach and reattach (key is required to open)
DETACH secure;
ATTACH 'secure.duckdb' (TYPE DUCKDB, ENCRYPTION_CONFIG {key: 'my_secret_key_here'});
SELECT * FROM secure.main.sensitive_data;

-- Attempting to open without key fails
ATTACH 'secure.duckdb' AS secure2;
-- Error: cannot open encrypted database without key
```

**Encryption implementation details:**
- Algorithm: AES-256-GCM (authenticated encryption)
- Coverage: main file, WAL, temp files
- Key management: key passed at ATTACH/CREATE time (DuckDB does not store the key)
- Backend options:
  - Built-in mbedtls library (default)
  - OpenSSL from httpfs extension (much faster due to hardware acceleration)

```sql
-- Use OpenSSL backend for better performance
INSTALL httpfs;
LOAD httpfs;
-- OpenSSL is now available for encryption operations
ATTACH 'fast_encrypted.duckdb' (TYPE DUCKDB, ENCRYPTION_CONFIG {key: 'key123'});
```

**Encryption best practices:**
- Store encryption keys in a secrets manager (not in source code or SQL scripts)
- Use OpenSSL backend for workloads that frequently read/write encrypted databases
- Encryption adds ~10-20% overhead for read-heavy workloads, more for write-heavy
- The key cannot be changed after creation -- to rotate, export data and re-create the database

### MERGE Statement

DuckDB 1.4 adds support for MERGE INTO, the SQL standard upsert mechanism:

```sql
-- Basic upsert (update existing, insert new)
MERGE INTO orders AS target
USING staging_orders AS source
ON target.order_id = source.order_id
WHEN MATCHED THEN
    UPDATE SET amount = source.amount, status = source.status
WHEN NOT MATCHED THEN
    INSERT (order_id, customer_id, amount, status)
    VALUES (source.order_id, source.customer_id, source.amount, source.status);

-- MERGE with DELETE action
MERGE INTO inventory AS target
USING updates AS source
ON target.product_id = source.product_id
WHEN MATCHED AND source.action = 'delete' THEN DELETE
WHEN MATCHED AND source.action = 'update' THEN
    UPDATE SET qty = source.qty, price = source.price
WHEN NOT MATCHED AND source.action = 'insert' THEN
    INSERT *;

-- MERGE from a file source
MERGE INTO orders AS target
USING read_parquet('updates.parquet') AS source
ON target.order_id = source.order_id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- Conditional MERGE with additional predicates
MERGE INTO customers AS target
USING new_customers AS source
ON target.email = source.email
WHEN MATCHED AND source.updated_at > target.updated_at THEN
    UPDATE SET name = source.name, phone = source.phone, updated_at = source.updated_at
WHEN NOT MATCHED THEN
    INSERT *;
```

**MERGE vs. INSERT ... ON CONFLICT:**
| Feature | MERGE INTO | INSERT ... ON CONFLICT |
|---|---|---|
| Requires primary key | No (any custom condition) | Yes |
| DELETE action | Yes | No |
| Multiple WHEN clauses | Yes (with conditions) | Limited |
| SQL standard | Yes | PostgreSQL extension |
| OLAP use case | Designed for it | Originally OLTP |

### Iceberg Writes

DuckDB 1.4 supports writing to Apache Iceberg tables via the iceberg extension:

```sql
-- Install and load the Iceberg extension
INSTALL iceberg;
LOAD iceberg;

-- Create an Iceberg catalog
CREATE SECRET (
    TYPE ICEBERG,
    ENDPOINT 'http://localhost:8181',
    CLIENT_ID 'my_client',
    CLIENT_SECRET 'my_secret'
);

-- Write data to Iceberg
COPY FROM DATABASE duckdb_db TO iceberg_catalog;

-- Read from Iceberg tables
SELECT * FROM iceberg_scan('s3://bucket/warehouse/db/orders');
```

**Iceberg write capabilities:**
- Supports COPY FROM DATABASE for bulk writes
- Writes to S3-based Iceberg warehouses
- Integrates with REST catalogs, Glue catalogs
- Bidirectional: DuckDB can now both read and write Iceberg

### Materialized CTEs by Default

In DuckDB 1.4, Common Table Expressions are materialized by default:

```sql
-- The CTE is computed once and reused (materialized)
WITH expensive_calc AS (
    SELECT region, sum(amount) AS total
    FROM orders
    GROUP BY region
)
SELECT * FROM expensive_calc WHERE total > 10000
UNION ALL
SELECT * FROM expensive_calc WHERE total < 1000;
-- The aggregation runs only ONCE, not twice

-- Explicit materialization hint (always worked, now default)
WITH expensive_calc AS MATERIALIZED (
    SELECT region, sum(amount) AS total FROM orders GROUP BY region
)
SELECT * FROM expensive_calc;

-- Opt out of materialization if the optimizer can do better
WITH cheap_filter AS NOT MATERIALIZED (
    SELECT * FROM orders WHERE status = 'active'
)
SELECT * FROM cheap_filter LIMIT 10;
```

**Why this matters:**
- Pre-1.4: CTEs could be inlined, causing the same computation to run multiple times
- 1.4+: CTEs are materialized, guaranteeing single evaluation even when referenced multiple times
- This resolves correctness bugs in rare edge cases and improves performance for CTEs referenced multiple times

### COPY FROM DATABASE

DuckDB 1.4 introduced the COPY FROM DATABASE statement for cross-database copying:

```sql
-- Copy entire database to another DuckDB file
ATTACH 'target.duckdb' AS target;
COPY FROM DATABASE memory TO target;

-- Copy to an Iceberg catalog
COPY FROM DATABASE my_duckdb TO iceberg_catalog;

-- Useful for migration, backup, and cross-format transfers
```

## Additional Improvements in the 1.4 Line

### v1.4.1 Improvements
- Performance improvements for various query patterns
- Bugfixes for edge cases in storage and transactions

### v1.4.2 Improvements
- Additional bugfixes and stability improvements
- Performance enhancements for specific operators

### v1.4.3 Improvements
- Continued bugfixes and performance patches
- Storage layer improvements

### v1.4.4 Improvements
- Security patches
- Bugfixes for ART indexes
- Performance improvements

## LTS Support Model

DuckDB 1.4 established the LTS release model:

- **LTS releases:** Every other DuckDB version is LTS
- **Support duration:** 1 year of community support (until Sep 2026 for 1.4)
- **Patch releases:** Bugfixes, security patches, and performance improvements (no new features)
- **Commercial support:** DuckDB Labs offers extended commercial support beyond the community window
- **Non-LTS releases:** Supported only until the next release (LTS or non-LTS)

**Upgrade path:** When 1.4 LTS reaches end-of-community-support (Sep 2026), upgrade to the next LTS release. Storage format compatibility is maintained across minor versions within the same major line.

## Migration from Pre-1.4 Versions

### Breaking Changes to Watch

1. **CTEs are now materialized by default** -- Queries that relied on CTE inlining for optimization may behave differently. Use `NOT MATERIALIZED` if needed.

2. **Extension compatibility** -- Extensions must be updated for 1.4. Run `UPDATE EXTENSIONS;` after upgrading.

3. **Storage format** -- DuckDB 1.4 can read databases created by earlier versions, but databases written by 1.4 may not be readable by older versions. Back up before upgrading.

### Upgrade Steps

```bash
# 1. Back up existing database
duckdb old_version.duckdb "EXPORT DATABASE 'backup' (FORMAT PARQUET)"

# 2. Install DuckDB 1.4
pip install duckdb==1.4.4  # or download CLI

# 3. Update extensions
duckdb my_database.duckdb "UPDATE EXTENSIONS;"

# 4. Verify
duckdb my_database.duckdb "SELECT version(); PRAGMA database_size;"
```

## When to Choose DuckDB 1.4 LTS

Choose 1.4 LTS when:
- **Stability is paramount** -- Production systems that need predictable behavior
- **Long support window** -- You need a version supported until September 2026
- **Encryption is required** -- Database encryption is a 1.4+ feature
- **MERGE is needed** -- The MERGE statement is a 1.4+ feature
- **Iceberg integration** -- Bidirectional Iceberg read/write support

Choose 1.5 (current) when:
- You need the VARIANT type for JSON-like workloads
- You need the built-in GEOMETRY type
- You want the improved CLI experience
- You need the PEG parser or ODBC scanner
- You are starting a new project without LTS constraints
