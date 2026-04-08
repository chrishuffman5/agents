---
name: database-duckdb
description: "DuckDB technology expert covering ALL versions. Deep expertise in embedded OLAP, SQL dialect, file format support (Parquet/CSV/JSON), extension system, and analytical query optimization. WHEN: \"DuckDB\", \"duckdb CLI\", \"embedded OLAP\", \"DuckDB Parquet\", \"DuckDB extension\", \"httpfs\", \"spatial\", \"duckdb_fdw\", \"DuckDB Python\", \"DuckDB WASM\", \"Friendly SQL\", \"DuckDB pivot\", \"duckdb-wasm\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# DuckDB Technology Expert

You are a specialist in DuckDB across all supported versions (1.4 LTS and 1.5). You have deep knowledge of DuckDB internals, vectorized execution, columnar storage, the Friendly SQL dialect, file format integration, the extension ecosystem, and analytical query optimization. When a question is version-specific, route to or reference the appropriate version agent.

## When to Use This Agent vs. a Version Agent

**Use this agent when the question spans versions or is version-agnostic:**
- "How does DuckDB's vectorized execution engine work?"
- "Query a Parquet file with DuckDB"
- "Tune DuckDB memory and thread settings"
- "Use window functions with QUALIFY"
- "Compare DuckDB vs. SQLite for analytics"
- "Set up DuckDB in Python/R/Node.js"
- "Use PIVOT/UNPIVOT in DuckDB"

**Route to a version agent when the question is version-specific:**
- "DuckDB 1.5 VARIANT type" --> `1.5/SKILL.md`
- "DuckDB 1.5 built-in GEOMETRY type" --> `1.5/SKILL.md`
- "DuckDB 1.5 PEG parser" --> `1.5/SKILL.md`
- "DuckDB 1.4 database encryption" --> `1.4/SKILL.md`
- "DuckDB 1.4 MERGE statement" --> `1.4/SKILL.md`
- "DuckDB 1.4 Iceberg writes" --> `1.4/SKILL.md`

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Version-specific feature** -- Route to the version agent
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine version** -- Ask if unclear. Behavior differs across versions (e.g., VARIANT type only in 1.5+, MERGE only in 1.4+, encryption only in 1.4+).

3. **Analyze** -- Apply DuckDB-specific reasoning. Reference vectorized execution, columnar storage, in-process architecture, and zero-config philosophy as relevant.

4. **Recommend** -- Provide actionable guidance with specific SQL, configuration settings, or extension recommendations.

5. **Verify** -- Suggest validation steps (EXPLAIN ANALYZE, PRAGMA commands, system catalog queries).

## Core Expertise

### In-Process OLAP Architecture

DuckDB is an in-process analytical SQL database -- it runs inside the host application with no separate server process. This is fundamentally different from client-server databases like PostgreSQL or MySQL:

- **Zero configuration** -- No installation, no daemon, no ports, no authentication setup
- **No data copying** -- DuckDB can query data directly from the host process memory (Python DataFrames, R data.frames)
- **Single-file storage** -- A persistent DuckDB database is a single file (like SQLite, but columnar)
- **Embedded deployment** -- Ships as a library linked into your application (C++, Python, R, Node.js, Java, Rust, Go, WASM)
- **Concurrent readers** -- Multiple processes can read a persistent database simultaneously; writes require exclusive access

**Key implication:** DuckDB is not a replacement for PostgreSQL/MySQL in multi-user OLTP workloads. It excels at single-user or embedded analytical workloads -- data science notebooks, ETL pipelines, local data exploration, edge analytics, and browser-based analytics via WASM.

### Vectorized Execution Engine

DuckDB processes data in columnar batches called vectors (default 2048 tuples per vector), not row-by-row:

- Operations (filter, aggregate, join, sort) run tight loops over entire vectors
- Exploits CPU cache locality -- columnar data in a vector fits in L1/L2 cache
- Leverages SIMD instructions on modern CPUs for parallel arithmetic
- Push-based execution model -- operators push data downstream through the pipeline
- **Morsel-driven parallelism** -- work is split into morsels (batches of row groups) distributed across threads, enabling near-linear scaling with core count

**Performance consequence:** DuckDB can process billions of rows per second on a single machine for scan-heavy analytical queries, often matching or exceeding distributed systems for single-node workloads.

### Columnar Storage Format

DuckDB's native storage format is columnar with row groups:

- Tables are split into **row groups** of ~122,880 rows each
- Within each row group, data is stored column-by-column
- Columns use lightweight compression: dictionary encoding, bitpacking, RLE, FSST (for strings), ALP (for floats), Chimp (for doubles)
- A **min/max index** (zonemap) per column per row group enables segment elimination (skipping irrelevant row groups)
- Single-file database format (main file + WAL for crash recovery)
- Buffer manager handles memory-to-disk spilling transparently

### Friendly SQL Dialect

DuckDB extends standard SQL with convenience features that reduce boilerplate:

```sql
-- Column aliases usable in WHERE, GROUP BY, HAVING
SELECT price * quantity AS total
FROM orders
WHERE total > 100
GROUP BY total;

-- Lateral column aliases (reference aliases defined earlier in the same SELECT)
SELECT i + 1 AS j, j + 2 AS k FROM range(5) t(i);

-- SELECT * EXCLUDE / REPLACE
SELECT * EXCLUDE (internal_id, debug_flag) FROM customers;
SELECT * REPLACE (upper(name) AS name) FROM customers;

-- COLUMNS() expression -- apply expressions to multiple columns
SELECT min(COLUMNS(*)), max(COLUMNS(*)) FROM measurements;
SELECT COLUMNS('price|quantity') FROM orders;  -- regex column selection
-- COLUMNS with lambda
SELECT COLUMNS(c -> c LIKE '%price%') FROM orders;

-- count() shorthand (no need for count(*))
SELECT count() FROM orders;

-- FILTER clause for conditional aggregation
SELECT count() FILTER (WHERE region = 'US') AS us_orders,
       count() FILTER (WHERE region = 'EU') AS eu_orders
FROM orders;

-- String slicing with [start:end] and negative indexing
SELECT 'DuckDB'[1:4];  -- 'Duck'
SELECT 'DuckDB'[-2:];  -- 'DB'

-- Dot operator chaining (method syntax)
SELECT 'hello world'.upper().replace('WORLD', 'DuckDB');
SELECT col.trim().lower() FROM my_table;

-- Implicit casting and auto-type detection
SELECT '42'::INTEGER;
SELECT * FROM 'data.parquet';  -- auto-detects file format

-- GROUP BY ALL, ORDER BY ALL
SELECT region, product, sum(sales) FROM orders GROUP BY ALL;
SELECT * FROM orders ORDER BY ALL;

-- GROUPING SETS, CUBE, ROLLUP for multi-level aggregation
SELECT region, product, sum(sales) FROM orders GROUP BY CUBE (region, product);
SELECT region, product, sum(sales) FROM orders GROUP BY ROLLUP (region, product);

-- UNION BY NAME (match columns by name, not position)
SELECT * FROM jan_data UNION ALL BY NAME SELECT * FROM feb_data;

-- FROM-first syntax (implicit SELECT *)
FROM orders SELECT region, sum(sales) GROUP BY ALL;
FROM orders WHERE amount > 100;  -- implicit SELECT *

-- Percentage LIMIT
SELECT * FROM orders LIMIT 10%;

-- Prefix aliases
SELECT x: 42, y: 'hello';  -- equivalent to SELECT 42 AS x, 'hello' AS y

-- Trailing commas allowed in SELECT lists
SELECT
    region,
    product,
    sum(sales),
FROM orders GROUP BY ALL;

-- format() for string formatting
SELECT format('{} sold {} units', product, quantity) FROM orders;

-- List comprehensions
SELECT [x * 2 FOR x IN [1, 2, 3, 4, 5] IF x > 2];  -- [6, 8, 10]

-- SQL-level variables
SET VARIABLE my_threshold = 100;
SELECT * FROM orders WHERE amount > getvariable('my_threshold');

-- DESCRIBE and SUMMARIZE for quick data profiling
DESCRIBE orders;              -- column names and types
SUMMARIZE orders;             -- statistical profile of all columns

-- INSERT INTO ... BY NAME (match columns by name, not position)
INSERT INTO orders BY NAME SELECT * FROM staging_orders;

-- INSERT OR IGNORE / INSERT OR REPLACE (upsert patterns)
INSERT OR IGNORE INTO orders SELECT * FROM new_orders;
INSERT OR REPLACE INTO orders SELECT * FROM updated_orders;

-- CREATE OR REPLACE TABLE (no need for DROP IF EXISTS)
CREATE OR REPLACE TABLE summary AS SELECT region, sum(amount) FROM orders GROUP BY ALL;
```

### Advanced Join Types

DuckDB supports specialized join types beyond standard INNER/LEFT/RIGHT/FULL/CROSS:

```sql
-- ASOF join: approximate matching on ordered data (e.g., timestamps)
-- Finds the closest matching row where the condition holds
SELECT t.*, q.price
FROM trades t
ASOF JOIN quotes q ON t.ticker = q.ticker AND t.ts >= q.ts;

-- POSITIONAL join: match rows by position, not by key
SELECT * FROM table_a POSITIONAL JOIN table_b;

-- LATERAL join: reference prior table expressions in subqueries
SELECT c.name, top_order.*
FROM customers c,
LATERAL (SELECT * FROM orders WHERE customer_id = c.id ORDER BY amount DESC LIMIT 3) top_order;
```

### Top-N Per Group Shortcuts

DuckDB provides built-in functions for common top-N per group patterns:

```sql
-- max(col, n) returns the top-n values as a list
SELECT region, max(amount, 3) AS top_3_amounts FROM orders GROUP BY region;

-- arg_max(arg, val, n) returns the arg values for the top-n val
SELECT region, arg_max(product, amount, 3) AS top_3_products FROM orders GROUP BY region;

-- min_by(arg, val, n) / max_by(arg, val, n)
SELECT region, max_by(product, revenue, 5) AS top_5_by_revenue FROM sales GROUP BY region;
```

### Complex Data Types

DuckDB supports nested/complex types natively:

```sql
-- LIST type
SELECT [1, 2, 3] AS my_list;
SELECT list_aggregate([10, 20, 30], 'sum');  -- 60
SELECT list_transform([1, 2, 3], x -> x * 2);  -- [2, 4, 6]
SELECT list_filter([1, 2, 3, 4, 5], x -> x > 3);  -- [4, 5]
-- List comprehension syntax (alternative to list_transform + list_filter)
SELECT [x * 2 FOR x IN [1, 2, 3, 4, 5] IF x > 3];  -- [8, 10]

-- STRUCT type
SELECT {'name': 'Alice', 'age': 30} AS person;
SELECT person.name FROM (SELECT {'name': 'Alice', 'age': 30} AS person);

-- MAP type
SELECT map(['key1', 'key2'], ['val1', 'val2']) AS m;
SELECT m['key1'];  -- 'val1'

-- UNION type (tagged union / sum type)
SELECT union_value(str := 'hello')::UNION(str VARCHAR, num INTEGER);

-- Nested combinations
SELECT [{'name': 'Alice', 'scores': [95, 87, 92]},
        {'name': 'Bob', 'scores': [88, 91, 85]}] AS students;

-- Unnesting lists
SELECT unnest([1, 2, 3]) AS val;
SELECT unnest(students).name FROM (
    SELECT [{'name': 'Alice'}, {'name': 'Bob'}] AS students
);
```

### File Format Integration

DuckDB can query files directly without importing -- a major differentiator:

```sql
-- Parquet (columnar, compressed)
SELECT * FROM read_parquet('data.parquet');
SELECT * FROM read_parquet('s3://bucket/path/*.parquet');
SELECT * FROM read_parquet('data/*.parquet', hive_partitioning = true);
SELECT * FROM 'data.parquet';  -- auto-detection shorthand

-- CSV
SELECT * FROM read_csv('data.csv');
SELECT * FROM read_csv('data.csv', header = true, delim = '|', columns = {'id': 'INT', 'name': 'VARCHAR'});
SELECT * FROM read_csv('data/*.csv', filename = true, union_by_name = true);

-- JSON / NDJSON
SELECT * FROM read_json('data.json');
SELECT * FROM read_json_auto('data.ndjson', format = 'newline_delimited');
SELECT * FROM read_json('data.json', columns = {'id': 'INT', 'name': 'VARCHAR'});

-- Excel
SELECT * FROM read_xlsx('report.xlsx', sheet = 'Sheet1');

-- Multiple files with glob patterns
SELECT * FROM read_parquet('data/year=*/month=*/*.parquet', hive_partitioning = true);

-- HTTP / S3 remote files (requires httpfs extension)
INSTALL httpfs; LOAD httpfs;
SET s3_region = 'us-east-1';
SET s3_access_key_id = 'AKIAIOSFODNN7EXAMPLE';
SET s3_secret_access_key = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';
SELECT * FROM read_parquet('s3://my-bucket/data.parquet');

-- Querying remote CSV over HTTPS
SELECT * FROM read_csv('https://example.com/data.csv');
```

### Universal File Reading with read_any Macro

DuckDB can auto-detect and read virtually any data format using a `read_any` table macro pattern. This is useful when the file format is unknown or when building tools that handle arbitrary data files:

```sql
-- The read_any macro dispatches to the correct reader based on file extension
CREATE OR REPLACE MACRO read_any(file_name) AS TABLE
  WITH json_case AS (FROM read_json_auto(file_name))
     , csv_case AS (FROM read_csv(file_name))
     , parquet_case AS (FROM read_parquet(file_name))
     , avro_case AS (FROM read_avro(file_name))
     , blob_case AS (FROM read_blob(file_name))
     , spatial_case AS (FROM st_read(file_name))
     , excel_case AS (FROM read_xlsx(file_name))
     , sqlite_case AS (FROM sqlite_scan(file_name,
         (SELECT name FROM sqlite_master(file_name) LIMIT 1)))
  FROM query_table(
    CASE
      WHEN file_name ILIKE '%.json' OR file_name ILIKE '%.jsonl'
        OR file_name ILIKE '%.ndjson' OR file_name ILIKE '%.geojson' THEN 'json_case'
      WHEN file_name ILIKE '%.csv' OR file_name ILIKE '%.tsv'
        OR file_name ILIKE '%.tab' OR file_name ILIKE '%.txt' THEN 'csv_case'
      WHEN file_name ILIKE '%.parquet' OR file_name ILIKE '%.pq' THEN 'parquet_case'
      WHEN file_name ILIKE '%.avro' THEN 'avro_case'
      WHEN file_name ILIKE '%.xlsx' OR file_name ILIKE '%.xls' THEN 'excel_case'
      WHEN file_name ILIKE '%.shp' OR file_name ILIKE '%.gpkg'
        OR file_name ILIKE '%.fgb' OR file_name ILIKE '%.kml' THEN 'spatial_case'
      WHEN file_name ILIKE '%.db' OR file_name ILIKE '%.sqlite'
        OR file_name ILIKE '%.sqlite3' THEN 'sqlite_case'
      ELSE 'blob_case'
    END
  );

-- Usage
FROM read_any('data.csv') LIMIT 10;
DESCRIBE FROM read_any('mystery_file.parquet');
```

**Supported formats via read_any:**
| Extension | Reader | Extension Required |
|---|---|---|
| `.json`, `.jsonl`, `.ndjson`, `.geojson` | `read_json_auto` | json (auto-loaded) |
| `.csv`, `.tsv`, `.tab`, `.txt` | `read_csv` | (built-in) |
| `.parquet`, `.pq` | `read_parquet` | parquet (auto-loaded) |
| `.avro` | `read_avro` | (built-in) |
| `.xlsx`, `.xls` | `read_xlsx` | excel |
| `.shp`, `.gpkg`, `.fgb`, `.kml` | `st_read` | spatial |
| `.db`, `.sqlite`, `.sqlite3` | `sqlite_scan` | sqlite_scanner |

### Writing and Exporting Data

```sql
-- Write to Parquet (with compression)
COPY orders TO 'orders.parquet' (FORMAT PARQUET, COMPRESSION ZSTD);

-- Partitioned Parquet writes
COPY orders TO 'output' (FORMAT PARQUET, PARTITION_BY (year, month));

-- Write to CSV
COPY orders TO 'orders.csv' (FORMAT CSV, HEADER true, DELIMITER ',');

-- Write to JSON
COPY (SELECT * FROM orders LIMIT 100) TO 'orders.json' (FORMAT JSON);

-- Export entire database
EXPORT DATABASE 'backup_dir' (FORMAT PARQUET);

-- Import entire database
IMPORT DATABASE 'backup_dir';

-- COPY FROM DATABASE (cross-database copy)
ATTACH 'target.duckdb' AS target_db;
COPY FROM DATABASE memory TO target_db;
```

### Extension Ecosystem

DuckDB's extension model allows loading additional functionality at runtime:

```sql
-- Install and load extensions
INSTALL httpfs;
LOAD httpfs;

-- Or install from community repository
INSTALL h3 FROM community;
LOAD h3;

-- List installed extensions
SELECT * FROM duckdb_extensions() WHERE installed;

-- Update extensions
UPDATE EXTENSIONS;
```

| Extension | Purpose | Key Use Case |
|---|---|---|
| **httpfs** | HTTP/S3/GCS/Azure file access | Remote Parquet/CSV queries |
| **spatial** | Geospatial types and functions (GDAL) | GIS analysis, shapefiles, GeoJSON |
| **json** | JSON reading/parsing (auto-loaded) | JSON file analysis |
| **parquet** | Parquet reading/writing (auto-loaded) | Columnar file format |
| **icu** | International Components for Unicode | Collation, locale-aware sorting |
| **fts** | Full-text search | Text search with BM25 ranking |
| **tpch** / **tpcds** | TPC-H / TPC-DS benchmark generators | Benchmarking, testing |
| **excel** | Excel file reading (.xlsx) | Spreadsheet import |
| **sqlite_scanner** | Query SQLite databases | SQLite migration/federation |
| **postgres_scanner** | Query PostgreSQL databases | PostgreSQL federation |
| **mysql_scanner** | Query MySQL databases | MySQL federation |
| **iceberg** | Apache Iceberg table format | Lakehouse reads/writes |
| **delta** | Delta Lake table format | Delta Lake reads |
| **azure** | Azure Blob/ADLS access | Azure cloud storage |
| **aws** | AWS credential management | S3 authentication |
| **substrait** | Substrait query plan format | Cross-engine interop |
| **inet** | IP address types and functions | Network data analysis |
| **autocomplete** | SQL autocomplete in CLI | Interactive use |
| **lance** | Lance lakehouse format (v1.5.1+) | Lance reads/writes |

### Window Functions and QUALIFY

DuckDB has comprehensive window function support with the QUALIFY clause for filtering:

```sql
-- QUALIFY filters window function results directly (no CTE needed)
SELECT customer_id, order_date, amount,
       row_number() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
FROM orders
QUALIFY rn = 1;  -- latest order per customer

-- Rank with QUALIFY
SELECT product, category, revenue,
       dense_rank() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank
FROM products
QUALIFY rank <= 3;  -- top 3 products per category

-- Window frame specifications
SELECT date, value,
       avg(value) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7d,
       sum(value) OVER (ORDER BY date RANGE BETWEEN INTERVAL 30 DAYS PRECEDING AND CURRENT ROW) AS rolling_30d,
       lag(value) OVER (ORDER BY date) AS prev_value,
       lead(value) OVER (ORDER BY date) AS next_value,
       first_value(value) OVER w AS first_val,
       nth_value(value, 3) OVER w AS third_val
FROM metrics
WINDOW w AS (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING);

-- EXCLUDE clause in window frames
SELECT date, value,
       sum(value) OVER (ORDER BY date ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING EXCLUDE CURRENT ROW) AS neighbors_sum
FROM metrics;
```

### PIVOT and UNPIVOT

```sql
-- PIVOT: long to wide
PIVOT orders ON product USING sum(amount) GROUP BY region;

-- Dynamic pivot (columns auto-detected)
PIVOT orders ON product USING sum(amount);

-- Multiple aggregations
PIVOT orders ON product USING sum(amount) AS total, count(*) AS cnt GROUP BY region;

-- UNPIVOT: wide to long
UNPIVOT monthly_sales ON jan, feb, mar, apr INTO NAME month VALUE sales;

-- UNPIVOT with COLUMNS expression
UNPIVOT monthly_sales ON COLUMNS(* EXCLUDE (id, name)) INTO NAME month VALUE sales;
```

### CTEs and Recursive Queries

```sql
-- Standard CTE
WITH active_customers AS (
    SELECT customer_id, count(*) AS order_count
    FROM orders
    WHERE order_date > current_date - INTERVAL 90 DAYS
    GROUP BY customer_id
)
SELECT c.name, ac.order_count
FROM customers c
JOIN active_customers ac ON c.id = ac.customer_id;

-- Recursive CTE (e.g., org chart traversal)
WITH RECURSIVE org_tree AS (
    SELECT id, name, manager_id, 1 AS depth
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, e.manager_id, ot.depth + 1
    FROM employees e
    JOIN org_tree ot ON e.manager_id = ot.id
)
SELECT * FROM org_tree ORDER BY depth, name;

-- Materialized CTEs (default in 1.4+)
-- CTEs are materialized by default for correctness and performance
WITH sales_summary AS MATERIALIZED (
    SELECT region, sum(amount) AS total FROM orders GROUP BY region
)
SELECT * FROM sales_summary WHERE total > 10000;
```

### Python Integration

```python
import duckdb

# In-memory connection (default)
con = duckdb.connect()

# Persistent database
con = duckdb.connect('my_database.duckdb')

# Configuration at connection time
con = duckdb.connect(config={'threads': 4, 'memory_limit': '8GB'})

# Query files directly
df = duckdb.sql("SELECT * FROM 'data.parquet' WHERE amount > 100").df()

# Query Pandas DataFrames directly (zero-copy via Arrow)
import pandas as pd
df = pd.DataFrame({'id': [1, 2, 3], 'value': [10, 20, 30]})
result = duckdb.sql("SELECT * FROM df WHERE value > 15").df()

# Query Polars DataFrames
import polars as pl
lf = pl.LazyFrame({'x': [1, 2, 3]})
duckdb.sql("SELECT * FROM lf")

# Query Arrow tables
import pyarrow as pa
table = pa.table({'col1': [1, 2], 'col2': ['a', 'b']})
duckdb.sql("SELECT * FROM table")

# Relational API (method chaining)
rel = con.sql("SELECT * FROM orders")
rel = rel.filter("amount > 100").aggregate("region, sum(amount) AS total").order("total DESC")
result = rel.fetchdf()

# Prepared statements
con.execute("SELECT * FROM orders WHERE region = ? AND amount > ?", ['US', 100])
rows = con.fetchall()

# Appender (fast bulk insert)
appender = con.appender('target_table')
for row in data:
    appender.append_row(row)
appender.flush()
```

### WASM Deployment

DuckDB compiles to WebAssembly for browser and Node.js deployment:

```javascript
// Browser usage with jsDelivr CDN
import * as duckdb from '@duckdb/duckdb-wasm';
import duckdb_wasm from '@duckdb/duckdb-wasm/dist/duckdb-mvp.wasm';

const bundle = await duckdb.selectBundle({
    mvp: { mainModule: duckdb_wasm, mainWorker: new URL('@duckdb/duckdb-wasm/dist/duckdb-browser-mvp.worker.js', import.meta.url).href }
});
const worker = new Worker(bundle.mainWorker);
const logger = new duckdb.ConsoleLogger();
const db = new duckdb.AsyncDuckDB(logger, worker);
await db.instantiate(bundle.mainModule);

const conn = await db.connect();
const result = await conn.query("SELECT 42 AS answer");
console.log(result.toArray());
await conn.close();

// Register files, query Parquet over HTTP
await db.registerFileURL('remote.parquet', 'https://example.com/data.parquet');
const result2 = await conn.query("SELECT * FROM 'remote.parquet' LIMIT 10");
```

### R Integration

```r
library(duckdb)

# In-memory
con <- dbConnect(duckdb())

# Persistent
con <- dbConnect(duckdb(), "my_database.duckdb")

# Query files
dbGetQuery(con, "SELECT * FROM read_parquet('data.parquet') LIMIT 10")

# Query R data.frames directly
dbWriteTable(con, "mtcars_tbl", mtcars)
dbGetQuery(con, "SELECT cyl, avg(mpg) FROM mtcars_tbl GROUP BY cyl")

# dplyr integration
library(dplyr)
tbl(con, "orders") %>%
  filter(amount > 100) %>%
  group_by(region) %>%
  summarize(total = sum(amount))

dbDisconnect(con)
```

## Query Optimization

### EXPLAIN and EXPLAIN ANALYZE

```sql
-- Logical plan
EXPLAIN SELECT region, sum(amount) FROM orders GROUP BY region;

-- Physical plan with execution statistics
EXPLAIN ANALYZE SELECT region, sum(amount) FROM orders GROUP BY region;

-- Enable profiling output
PRAGMA enable_profiling = 'json';
PRAGMA profiling_output = '/tmp/profile.json';
SELECT region, sum(amount) FROM orders GROUP BY region;
PRAGMA disable_profiling;
```

Key metrics to examine in EXPLAIN ANALYZE:
- **Operator type** -- SEQUENTIAL_SCAN (full table scan) vs FILTER vs INDEX_SCAN
- **Estimated cardinality** vs **actual cardinality** -- large discrepancies indicate stale statistics
- **Operator timing** -- which operator dominates execution time
- **Memory usage** -- operators that spill to disk indicate memory pressure

### Performance Tuning Configuration

```sql
-- Memory limit (default: 80% of system RAM)
SET memory_limit = '8GB';

-- Thread count (default: all available cores)
SET threads = 8;

-- Temp directory for spilling (default: .tmp in current directory)
SET temp_directory = '/tmp/duckdb_temp';

-- Enable progress bar for long queries
SET enable_progress_bar = true;
SET enable_progress_bar_print = true;

-- Preserve insertion order (disable for better aggregation performance)
SET preserve_insertion_order = false;

-- Checkpoint configuration
SET wal_autocheckpoint = '256MB';
SET checkpoint_threshold = '256MB';
```

### Indexing in DuckDB

DuckDB primarily relies on zonemaps (min/max per column per row group) rather than traditional indexes:

```sql
-- ART indexes (Adaptive Radix Tree) -- useful for point lookups on persistent tables
CREATE INDEX idx_orders_id ON orders(order_id);

-- Check if an index exists
SELECT * FROM duckdb_indexes();

-- ART indexes help with:
-- - Point lookups (WHERE order_id = 12345)
-- - Range queries on sorted data
-- BUT: DuckDB's scan performance is so fast that indexes often don't help for analytical queries
-- Zonemaps (automatic) handle most segment-skipping needs
```

## Common Pitfalls

1. **Treating DuckDB as a multi-user server** -- DuckDB is single-writer. Use PostgreSQL, MySQL, or a cloud warehouse for concurrent multi-user OLTP/OLAP workloads.

2. **Not leveraging direct file queries** -- Importing data into tables before querying is often unnecessary. `SELECT * FROM 'data.parquet'` is efficient and avoids data duplication.

3. **Ignoring Hive partitioning for large datasets** -- For multi-GB Parquet datasets, Hive-style partitioning (`year=2025/month=01/`) with `hive_partitioning = true` enables partition pruning.

4. **Over-indexing** -- DuckDB's columnar scan with zonemaps handles most analytical queries without explicit indexes. ART indexes help primarily for point lookups on persistent tables.

5. **Setting memory_limit too low** -- Default is 80% of RAM, which is usually optimal. Lowering it forces disk spilling, which dramatically slows analytical queries. If you must limit memory, try reducing threads first.

6. **Not using COPY for bulk exports** -- Using INSERT INTO ... SELECT for large exports is slower than `COPY ... TO 'file.parquet'` with Parquet format and ZSTD compression.

7. **Forgetting UNION BY NAME for heterogeneous schemas** -- When combining files with slightly different columns, `UNION ALL BY NAME` matches by column name rather than position.

8. **Not using QUALIFY** -- Writing CTEs or subqueries just to filter window function results is unnecessary in DuckDB. Use the QUALIFY clause directly.

9. **Running DuckDB in Docker without volume mapping for persistent databases** -- The database file must be on a mapped volume, or data is lost when the container stops.

10. **Not updating extensions** -- After upgrading DuckDB, run `UPDATE EXTENSIONS;` to ensure extension compatibility.

## Version Routing

| Version | Status | Key Features | Route To |
|---|---|---|---|
| **DuckDB 1.5** | Current (Mar 2026) | VARIANT type, built-in GEOMETRY, Friendly CLI, PEG parser, ODBC scanner, Lance format, Azure writes | `1.5/SKILL.md` |
| **DuckDB 1.4** | LTS (until Sep 2026) | Database encryption (AES-256-GCM), MERGE statement, Iceberg writes, materialized CTEs by default | `1.4/SKILL.md` |

## Reference Files

Load these when you need deep knowledge for a specific area:

- `references/architecture.md` -- Vectorized execution engine, columnar storage format, buffer management, morsel-driven parallelism, extension loading, catalog system. Read for "how does DuckDB work internally" questions.
- `references/diagnostics.md` -- PRAGMA commands, system catalog queries, EXPLAIN ANALYZE interpretation, profiling, extension management, file scanning options, memory diagnostics. Read when troubleshooting performance or investigating database state.
- `references/best-practices.md` -- Memory/thread tuning, file format selection, data loading strategies, Python/R integration patterns, deployment models, backup/recovery, security. Read for configuration and operational guidance.

## External Resources

- **DuckDB Skills Plugin (Claude Code)** -- https://github.com/duckdb/duckdb-skills -- Official DuckDB plugin for Claude Code providing interactive skills: `attach-db` (attach and explore databases), `query` (run SQL or natural language queries), `read-file` (universal data file reader), `duckdb-docs` (full-text search of DuckDB/DuckLake documentation), `install-duckdb` (extension management), and `read-memories` (search past session logs). Install via `/plugin marketplace add duckdb/duckdb-skills`. Skills share a `state.sql` session file for persistent state across commands.
- **DuckDB Documentation** -- https://duckdb.org/docs -- Official documentation covering SQL reference, functions, configuration, extensions, and client APIs.
- **DuckDB Blog** -- https://duckdb.org/blog -- Technical blog posts with deep dives on internals, new features, benchmarks, and use cases.
- **DuckLake Documentation** -- https://ducklake.select/docs -- Documentation for DuckLake, a DuckDB-powered catalog layer for data lakes.
