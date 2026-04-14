# DuckDB Best Practices Reference

## Memory and Resource Configuration

### Memory Limit

```sql
-- Default: 80% of system RAM. Suitable for dedicated analytics workloads.
-- Check current setting
SELECT current_setting('memory_limit');

-- Set for a workstation with other applications running
SET memory_limit = '8GB';

-- Set for a dedicated analytics server (32GB RAM)
SET memory_limit = '24GB';

-- Rule of thumb: ~5GB per thread for optimal performance
-- 8 threads * 5GB = 40GB memory_limit on a 48GB machine
```

**When to lower memory_limit:**
- DuckDB shares the machine with other memory-hungry applications
- Running inside a container with memory limits (set to ~70% of container limit)
- Embedding in a web application with many potential concurrent users

**When to raise memory_limit:**
- Dedicated analytics workloads on machines with ample RAM
- Large joins or sorts that spill to disk (check `duckdb_temporary_files()`)

### Thread Configuration

```sql
-- Default: number of available CPU cores
SELECT current_setting('threads');

-- Reduce for shared environments
SET threads = 4;

-- Maximize for dedicated analytics
SET threads = 16;
```

**Guidelines:**
- For interactive queries: use all cores (default)
- For background/batch jobs sharing the machine: use 50-75% of cores
- For embedded applications (e.g., web server): limit to 2-4 threads per query to avoid starving the host
- Reducing threads before reducing memory_limit is generally preferred

### Temp Directory

```sql
-- Default: .tmp in the current working directory
SELECT current_setting('temp_directory');

-- Set to a fast disk with ample space
SET temp_directory = '/fast-ssd/duckdb_temp';
```

**Best practices:**
- Point to fast storage (NVMe SSD preferred)
- Ensure sufficient free space (at least 2x the data size for large sorts/joins)
- Do not use network-attached storage for temp files
- In containers, use a tmpfs mount or a fast volume

## File Format Selection

### When to Use Parquet

Parquet is the recommended format for DuckDB analytics:

- **Columnar** -- DuckDB reads only needed columns (projection pushdown)
- **Compressed** -- 2-10x smaller than CSV with ZSTD or Snappy
- **Predicate pushdown** -- DuckDB pushes filters into Parquet row group statistics
- **Schema embedded** -- No need to specify column types
- **Splittable** -- Supports parallel reads across row groups

```sql
-- Write with optimal settings
COPY orders TO 'orders.parquet' (FORMAT PARQUET, COMPRESSION ZSTD, ROW_GROUP_SIZE 122880);

-- Partitioned writes for large datasets
COPY orders TO 'output' (FORMAT PARQUET, PARTITION_BY (year, month), COMPRESSION ZSTD);
```

### When to Use CSV

- Source data arrives as CSV (one-time import)
- Interoperability with tools that don't support Parquet
- Human-readable output for small datasets

```sql
-- Optimized CSV reading
SELECT * FROM read_csv('data.csv',
    header = true,
    sample_size = -1,     -- scan all rows for type detection (slower but more accurate)
    parallel = true       -- enable parallel CSV reading
);
```

### When to Use JSON

- API response data (nested structures)
- Log files in JSON/NDJSON format
- Semi-structured data exploration

```sql
-- NDJSON is more efficient than JSON arrays (streamable, parallelizable)
SELECT * FROM read_json_auto('logs.ndjson', format = 'newline_delimited');
```

### Format Comparison

| Aspect | Parquet | CSV | JSON |
|---|---|---|---|
| **Read speed** | Fastest (columnar, compressed) | Moderate | Slower |
| **Write speed** | Fast | Fastest | Moderate |
| **File size** | Smallest (2-10x less) | Largest | Large |
| **Schema** | Embedded | None (auto-detected) | Inferred |
| **Predicate pushdown** | Yes | No | No |
| **Projection pushdown** | Yes (reads only needed columns) | No (reads all) | Partial |
| **Nested types** | Yes | No | Yes |
| **Human-readable** | No | Yes | Yes |

## Data Loading Strategies

### Bulk Loading into Tables

```sql
-- Method 1: CREATE TABLE AS (CTAS) -- fastest for initial load
CREATE TABLE orders AS SELECT * FROM read_parquet('orders/*.parquet');

-- Method 2: INSERT INTO ... SELECT
INSERT INTO orders SELECT * FROM read_parquet('new_orders.parquet');

-- Method 3: COPY FROM
COPY orders FROM 'data.csv' (FORMAT CSV, HEADER true);

-- Method 4: Direct file query (no loading needed!)
-- Often the best approach -- DuckDB queries files directly with excellent performance
SELECT region, sum(amount) FROM read_parquet('orders/*.parquet') GROUP BY region;
```

### Incremental Loading Patterns

```sql
-- Pattern 1: Append new data
INSERT INTO orders
SELECT * FROM read_parquet('new_data_20250115.parquet');

-- Pattern 2: Upsert with MERGE (v1.4+)
MERGE INTO orders AS target
USING read_parquet('updates.parquet') AS source
ON target.order_id = source.order_id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- Pattern 3: Replace partition
DELETE FROM orders WHERE year = 2025 AND month = 1;
INSERT INTO orders SELECT * FROM read_parquet('2025/01/*.parquet');
```

### Loading from Multiple Sources

```sql
-- Combine files with different schemas
SELECT * FROM read_parquet('data/*.parquet', union_by_name = true);

-- Load from S3 with Hive partitioning
CREATE TABLE sales AS
SELECT * FROM read_parquet('s3://bucket/sales/year=*/month=*/*.parquet',
    hive_partitioning = true);

-- Load from multiple file types
SELECT * FROM read_csv('data.csv')
UNION ALL BY NAME
SELECT * FROM read_parquet('data.parquet');
```

## Query Optimization Best Practices

### Use Projection Pushdown

```sql
-- BAD: reads all columns, then discards
SELECT id, amount FROM (SELECT * FROM read_parquet('large_file.parquet'));

-- GOOD: reads only needed columns from Parquet
SELECT id, amount FROM read_parquet('large_file.parquet');
```

### Use Predicate Pushdown

```sql
-- GOOD: filter pushes into Parquet scan (skips row groups)
SELECT * FROM read_parquet('sales.parquet')
WHERE sale_date > '2025-01-01';

-- The WHERE clause is pushed into the Parquet reader, leveraging
-- row group min/max statistics to skip irrelevant data
```

### Leverage Zonemap-Friendly Data Layout

```sql
-- Data sorted by date enables effective zonemap pruning
CREATE TABLE events AS
SELECT * FROM read_parquet('events.parquet')
ORDER BY event_date;

-- Now queries filtering on event_date skip many row groups
SELECT * FROM events WHERE event_date = '2025-06-15';
```

### Avoid Unnecessary Materialization

```sql
-- BAD: creates intermediate table
CREATE TABLE temp AS SELECT * FROM large_table WHERE condition;
SELECT * FROM temp GROUP BY region;
DROP TABLE temp;

-- GOOD: use CTE or subquery
WITH filtered AS (
    SELECT * FROM large_table WHERE condition
)
SELECT region, count(*) FROM filtered GROUP BY region;

-- BEST: just write it directly
SELECT region, count(*) FROM large_table WHERE condition GROUP BY region;
```

### Use QUALIFY Instead of Subqueries

```sql
-- BAD: subquery/CTE for window function filtering
WITH ranked AS (
    SELECT *, row_number() OVER (PARTITION BY customer ORDER BY date DESC) AS rn
    FROM orders
)
SELECT * FROM ranked WHERE rn = 1;

-- GOOD: QUALIFY clause
SELECT * FROM orders
QUALIFY row_number() OVER (PARTITION BY customer ORDER BY date DESC) = 1;
```

### Use GROUP BY ALL and ORDER BY ALL

```sql
-- Verbose
SELECT region, product, sum(sales)
FROM orders
GROUP BY region, product
ORDER BY region, product;

-- Concise (DuckDB Friendly SQL)
SELECT region, product, sum(sales)
FROM orders
GROUP BY ALL
ORDER BY ALL;
```

### Use COLUMNS() for Repetitive Operations

```sql
-- Instead of listing every column
SELECT min(col1), max(col1), min(col2), max(col2), min(col3), max(col3)
FROM measurements;

-- Use COLUMNS()
SELECT min(COLUMNS(*)), max(COLUMNS(*)) FROM measurements;

-- With regex filter
SELECT avg(COLUMNS('price|quantity|discount')) FROM orders;
```

### Use FILTER Clause for Conditional Aggregation

```sql
-- Instead of CASE WHEN in aggregations
SELECT
    count(CASE WHEN region = 'US' THEN 1 END) AS us_count,
    sum(CASE WHEN status = 'completed' THEN amount ELSE 0 END) AS completed_total
FROM orders;

-- Use FILTER clause (cleaner and sometimes faster)
SELECT
    count() FILTER (WHERE region = 'US') AS us_count,
    sum(amount) FILTER (WHERE status = 'completed') AS completed_total
FROM orders;
```

### Use Top-N Per Group Functions

```sql
-- Instead of window functions for top-N per group
WITH ranked AS (
    SELECT *, row_number() OVER (PARTITION BY region ORDER BY amount DESC) AS rn
    FROM orders
)
SELECT * FROM ranked WHERE rn <= 3;

-- Use arg_max with N parameter (simpler for getting top values)
SELECT region, arg_max(product, amount, 3) AS top_3_products
FROM orders
GROUP BY region;

-- Use max(col, n) to get top-N values as a list
SELECT region, max(amount, 5) AS top_5_amounts
FROM orders
GROUP BY region;
```

### Use ASOF Joins for Time-Series Data

```sql
-- Instead of complex subqueries for point-in-time lookups
-- ASOF join finds the closest preceding match
SELECT t.*, q.price
FROM trades t
ASOF JOIN quotes q ON t.ticker = q.ticker AND t.ts >= q.ts;
```

### Use INSERT BY NAME for Schema Flexibility

```sql
-- Instead of relying on column position matching
INSERT INTO target SELECT col_a, col_b, col_c FROM source;

-- Use BY NAME to match columns by name (order-independent, extra columns ignored)
INSERT INTO target BY NAME SELECT * FROM source;
```

## Python Integration Best Practices

### Connection Management

```python
import duckdb

# Use context manager for automatic cleanup
with duckdb.connect('my_db.duckdb') as con:
    result = con.sql("SELECT * FROM orders").df()

# For notebooks: use the default connection for convenience
import duckdb
duckdb.sql("SELECT 42").show()

# For applications: create explicit connections
con = duckdb.connect('app.duckdb', config={
    'threads': 4,
    'memory_limit': '4GB',
    'temp_directory': '/tmp/duckdb'
})
```

### Zero-Copy Integration with DataFrames

```python
import duckdb
import pandas as pd

# DuckDB can query Pandas DataFrames directly (zero-copy via Arrow)
df = pd.read_csv('large_file.csv')
result = duckdb.sql("SELECT region, sum(amount) FROM df GROUP BY region").df()

# This is much faster than loading into a DuckDB table first!
# DuckDB reads the Pandas DataFrame memory directly via Arrow

# Same works with Polars
import polars as pl
lf = pl.scan_parquet('data.parquet')
duckdb.sql("SELECT * FROM lf WHERE amount > 100")

# And with PyArrow
import pyarrow.parquet as pq
table = pq.read_table('data.parquet')
duckdb.sql("SELECT * FROM table")
```

### Efficient Data Transfer

```python
# Fetch as Arrow (fastest, zero-copy)
arrow_table = con.sql("SELECT * FROM orders").arrow()

# Fetch as Pandas (Arrow -> Pandas conversion)
df = con.sql("SELECT * FROM orders").df()

# Fetch as Polars (Arrow -> Polars)
polars_df = con.sql("SELECT * FROM orders").pl()

# Fetch as Python lists (slowest, for small results)
rows = con.sql("SELECT * FROM orders LIMIT 10").fetchall()
```

### Bulk Insert with Appender

```python
# Fast bulk insert (bypasses SQL parsing)
con = duckdb.connect('my_db.duckdb')
con.sql("CREATE TABLE events (id INTEGER, ts TIMESTAMP, value DOUBLE)")

appender = con.appender('events')
for i in range(1000000):
    appender.append_row([i, datetime.now(), random.random()])
appender.flush()
appender.close()
```

## R Integration Best Practices

```r
library(duckdb)
library(DBI)

# Persistent database
con <- dbConnect(duckdb(), "analytics.duckdb")

# Configuration at connection time
con <- dbConnect(duckdb(), "analytics.duckdb",
                 config = list(threads = "4", memory_limit = "8GB"))

# Use dplyr for lazy evaluation (queries are pushed to DuckDB)
library(dplyr)
orders_tbl <- tbl(con, "orders")
result <- orders_tbl %>%
  filter(amount > 100) %>%
  group_by(region) %>%
  summarize(total = sum(amount, na.rm = TRUE)) %>%
  collect()  # collect() triggers execution

# Register R data.frame as DuckDB view (zero-copy)
duckdb_register(con, "mtcars_view", mtcars)
dbGetQuery(con, "SELECT cyl, avg(mpg) FROM mtcars_view GROUP BY cyl")

# Always disconnect
dbDisconnect(con, shutdown = TRUE)
```

## Deployment Models

### Local Development / Data Science

```python
# In-memory for exploratory analysis
import duckdb
con = duckdb.connect()
con.sql("SELECT * FROM 'data/*.parquet' LIMIT 10").show()
```

Best for: Jupyter notebooks, data exploration, prototyping

### Persistent Local Database

```python
# File-backed database for repeatable analytics
con = duckdb.connect('analytics.duckdb')
con.sql("CREATE TABLE IF NOT EXISTS orders AS SELECT * FROM 'raw_orders.parquet'")
```

Best for: Local data warehouses, personal analytics, edge deployments

### ETL Pipeline

```python
# Transform and export
con = duckdb.connect()
con.sql("""
    COPY (
        SELECT region, date_trunc('month', order_date) AS month, sum(amount) AS total
        FROM read_parquet('s3://bucket/raw/*.parquet')
        GROUP BY ALL
    ) TO 's3://bucket/aggregated/monthly_sales.parquet' (FORMAT PARQUET, COMPRESSION ZSTD)
""")
```

Best for: Data transformation, format conversion, aggregation pipelines

### Browser / Edge (WASM)

```javascript
// DuckDB-WASM for client-side analytics
import * as duckdb from '@duckdb/duckdb-wasm';
const db = await initDuckDB();
const conn = await db.connect();
await conn.query("SELECT * FROM 'https://cdn.example.com/data.parquet'");
```

Best for: Dashboards, client-side filtering, offline analytics

### MotherDuck (Cloud Hybrid)

```sql
-- Connect to MotherDuck for cloud-scale analytics with local DuckDB
-- Hybrid execution: some queries run locally, some in the cloud
ATTACH 'md:my_database';
SELECT * FROM my_database.orders WHERE region = 'US';
```

## Backup and Recovery

### Full Database Backup

```sql
-- Method 1: Export to Parquet (portable, compressed)
EXPORT DATABASE 'backup_20250115' (FORMAT PARQUET, COMPRESSION ZSTD);

-- Method 2: Copy database file (while no writers active)
-- Simply copy the .duckdb file. Ensure no write operations are in progress.

-- Method 3: Cross-database copy
ATTACH 'backup.duckdb' AS backup;
COPY FROM DATABASE main TO backup;
DETACH backup;
```

### Recovery

```sql
-- Restore from Parquet export
IMPORT DATABASE 'backup_20250115';

-- Verify restored data
SELECT table_name, estimated_size FROM duckdb_tables();
```

### Incremental Backup Pattern

```sql
-- Export only recent data
COPY (SELECT * FROM orders WHERE modified_at > '2025-01-14')
TO 'incremental_20250115.parquet' (FORMAT PARQUET);
```

## Security Best Practices

### File Access Control

```sql
-- Disable external file access (for untrusted SQL)
SET enable_external_access = false;

-- This prevents:
-- - Reading files from the filesystem
-- - Making HTTP requests
-- - Loading extensions from non-default paths
-- - Accessing S3/Azure/GCS storage
```

### Extension Security

```sql
-- Only load signed extensions (default behavior)
-- Community extensions are signed by the DuckDB community extension repository

-- To load unsigned extensions (development only):
SET allow_unsigned_extensions = true;

-- Best practice: audit extensions before deploying to production
SELECT extension_name, install_mode, installed_from
FROM duckdb_extensions()
WHERE installed;
```

### Database Encryption (v1.4+)

```sql
-- Create an encrypted database
ATTACH 'secure.duckdb' (TYPE DUCKDB, ENCRYPTION_CONFIG {key: 'my_secret_key'});

-- The encryption covers:
-- - Main database file
-- - WAL file
-- - Temp files
-- Uses AES-256-GCM by default
```

### Connection Configuration for Untrusted Input

```python
# Restrict DuckDB for multi-tenant or untrusted SQL scenarios
con = duckdb.connect(config={
    'enable_external_access': False,       # no file/network access
    'allow_unsigned_extensions': False,     # only signed extensions
    'threads': 2,                          # limit resource usage
    'memory_limit': '512MB',               # prevent memory abuse
    'max_expression_depth': 250,           # prevent stack overflow from deep nesting
})
```

### Sandboxed CLI Execution

```sql
-- For CLI-based sandboxing (restrict queries to specific files only)
-- Useful when accepting user-provided SQL in automation or tools
SET allowed_paths = ['/path/to/data.parquet', '/path/to/other.csv'];
SET enable_external_access = false;
SET allow_persistent_secrets = false;
SET lock_configuration = true;
-- After lock_configuration=true, no further SET commands are allowed
-- Queries can only read files listed in allowed_paths
```

### Cloud Credential Management with Secrets

```sql
-- S3 credentials via credential chain (auto-discovers from environment/IAM)
CREATE SECRET (TYPE S3, PROVIDER credential_chain);

-- GCS credentials via credential chain
CREATE SECRET (TYPE GCS, PROVIDER credential_chain);

-- Azure credentials via credential chain
LOAD azure;
CREATE SECRET (TYPE AZURE, PROVIDER credential_chain);

-- Explicit S3 credentials
CREATE SECRET my_s3 (
    TYPE S3,
    KEY_ID 'AKIAIOSFODNN7EXAMPLE',
    SECRET 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
    REGION 'us-east-1'
);

-- List active secrets
SELECT * FROM duckdb_secrets();

-- Drop a secret
DROP SECRET my_s3;
```

## Common Operational Patterns

### Format Conversion

```sql
-- CSV to Parquet
COPY (SELECT * FROM read_csv('input.csv'))
TO 'output.parquet' (FORMAT PARQUET, COMPRESSION ZSTD);

-- JSON to Parquet
COPY (SELECT * FROM read_json_auto('input.ndjson'))
TO 'output.parquet' (FORMAT PARQUET);

-- Parquet to CSV
COPY (SELECT * FROM read_parquet('input.parquet'))
TO 'output.csv' (FORMAT CSV, HEADER true);

-- Multiple CSVs to single Parquet
COPY (SELECT * FROM read_csv('data/*.csv', union_by_name = true))
TO 'combined.parquet' (FORMAT PARQUET, COMPRESSION ZSTD);
```

### Data Federation

```sql
-- Query PostgreSQL and DuckDB together
INSTALL postgres_scanner; LOAD postgres_scanner;
ATTACH 'dbname=analytics host=localhost' AS pg (TYPE POSTGRES);

SELECT d.customer_id, d.total_orders, pg.customer_name
FROM main.order_summary d
JOIN pg.public.customers pg ON d.customer_id = pg.id;
```

### Scheduling and Automation

```bash
# CLI one-liner for cron jobs
duckdb my_db.duckdb "COPY (SELECT * FROM orders WHERE date = current_date - 1) TO 'daily_export.parquet' (FORMAT PARQUET)"

# Python script for scheduled ETL
python -c "
import duckdb
con = duckdb.connect('analytics.duckdb')
con.sql(\"\"\"
    INSERT INTO daily_aggregates
    SELECT current_date - 1 AS date, region, sum(amount)
    FROM raw_orders
    WHERE order_date = current_date - 1
    GROUP BY ALL
\"\"\")
con.close()
"
```

### Data Validation Pipeline

```sql
-- Validate incoming data before loading
WITH validation AS (
    SELECT *,
        CASE WHEN amount < 0 THEN 'negative_amount'
             WHEN customer_id IS NULL THEN 'null_customer'
             WHEN order_date > current_date THEN 'future_date'
             ELSE 'valid'
        END AS validation_status
    FROM read_parquet('incoming_orders.parquet')
)
-- Load valid records
INSERT INTO orders SELECT * EXCLUDE (validation_status) FROM validation WHERE validation_status = 'valid';
-- Log invalid records
COPY (SELECT * FROM validation WHERE validation_status != 'valid')
TO 'rejected_orders.parquet' (FORMAT PARQUET);
```

## Session State Management

### State File Pattern (duckdb-skills Convention)

When working with DuckDB interactively across multiple sessions or tools, a `state.sql` file can persist session state (attached databases, loaded extensions, macros, secrets):

```sql
-- state.sql is a plain SQL file containing idempotent setup commands:
ATTACH IF NOT EXISTS '/absolute/path/to/analytics.duckdb' AS analytics;
USE analytics;
LOAD httpfs;
CREATE SECRET IF NOT EXISTS (TYPE S3, PROVIDER credential_chain);

-- Restore a session from a state file:
-- CLI: duckdb -init state.sql
-- Then all subsequent queries run in the restored context
```

**Best practices for state files:**
- Use `ATTACH IF NOT EXISTS` to make statements idempotent (safe to re-run)
- Use absolute paths for database files to avoid working directory issues
- Store per-project state either in `.duckdb-skills/state.sql` (colocated with project) or `~/.duckdb-skills/<project-id>/state.sql` (keeps repo clean)
- The file is append-only -- add new statements, don't edit existing ones
- Consider gitignoring the state file if it contains secrets or local paths

### DuckDB CLI Session Patterns

```bash
# One-liner query against a database
duckdb analytics.duckdb -csv -c "SELECT region, sum(amount) FROM orders GROUP BY ALL"

# Execute a SQL script
duckdb analytics.duckdb < transform.sql

# Restore session from state file and run a query
duckdb -init state.sql -csv -c "FROM orders LIMIT 10"

# Multi-line query with heredoc (avoids shell quoting issues)
duckdb analytics.duckdb -csv <<'SQL'
SELECT region, sum(amount) AS total
FROM orders
WHERE order_date > '2025-01-01'
GROUP BY ALL
ORDER BY total DESC;
SQL
```

## Performance Anti-Patterns to Avoid

1. **Importing data into tables when direct file queries suffice** -- `SELECT * FROM 'file.parquet'` is often just as fast as querying a table, and avoids data duplication.

2. **Using row-by-row Python loops instead of SQL** -- DuckDB's vectorized engine is orders of magnitude faster. Push computation into SQL whenever possible.

3. **Creating too many small Parquet files** -- Each file has overhead. Aim for files in the 100MB-1GB range. Use `COPY ... PARTITION_BY` for partitioned writes.

4. **Not using ZSTD compression for Parquet writes** -- ZSTD provides excellent compression ratio with fast decompression. Always specify `COMPRESSION ZSTD`.

5. **Ignoring union_by_name for heterogeneous file sets** -- When file schemas evolve over time, `union_by_name = true` handles the mismatch gracefully.

6. **Not batching inserts** -- Individual INSERT statements are slow. Use `INSERT INTO ... SELECT`, `COPY FROM`, or the Appender API for bulk loading.

7. **Using ORDER BY without LIMIT for large results** -- Sorting is expensive. If you need only top-N results, always add LIMIT.

8. **Not partitioning large Parquet exports** -- A single multi-GB Parquet file is harder to manage than partitioned files. Use `PARTITION_BY (year, month)` for time-series data.

9. **Running DuckDB with default settings in constrained environments** -- In Docker containers or shared servers, explicitly set `memory_limit`, `threads`, and `temp_directory`.

10. **Not leveraging the COLUMNS() expression** -- Writing repetitive per-column expressions when COLUMNS() with regex can do it in one line.
