---
name: duckdb
description: "DuckDB as a database engine: internals, SQL dialect, storage/indexing, extension system, the Quack remote/client-server protocol, and query optimization/tuning. Use for \"DuckDB\", \"duckdb CLI\", \"embedded OLAP\", \"DuckDB extension\", \"httpfs\", \"spatial\", \"duckdb_fdw\", \"DuckDB WASM\", \"Friendly SQL\", \"DuckDB pivot\", \"duckdb-wasm\", \"DuckDB Quack\", \"quack_serve\", \"DuckDB remote protocol\", \"DuckDB client-server\", \"DuckDB performance tuning\". Do NOT use for DuckDB as an ETL/pipeline transformation step (dbt-duckdb, ingesting/transforming files in a data pipeline) — that's the `duckdb` skill in the `etl` plugin. Do NOT use for DuckDB as a BI/analytics query backend (dashboarding, ad-hoc analyst queries) — that's the `duckdb` skill in the `analytics` plugin."
license: MIT
---

# DuckDB

This skill covers DuckDB across all supported versions (1.4 LTS and 1.5). It covers DuckDB internals, vectorized execution, columnar storage, the Friendly SQL dialect, file format integration, the extension ecosystem, and analytical query optimization. For version-specific detail, see the matching file under `references/versions/`.

## When to Use This Skill vs. Version-Specific Guidance

**Use this agent when the question spans versions or is version-agnostic:**
- "How does DuckDB's vectorized execution engine work?"
- "Query a Parquet file with DuckDB"
- "Tune DuckDB memory and thread settings"
- "Use window functions with QUALIFY"
- "Compare DuckDB vs. SQLite for analytics"
- "Set up DuckDB in Python/R/Node.js"
- "Use PIVOT/UNPIVOT in DuckDB"

**See the matching version reference when the question is version-specific:**
- "DuckDB 1.5 VARIANT type" --> `references/versions/1.5.md`
- "DuckDB 1.5 built-in GEOMETRY type" --> `references/versions/1.5.md`
- "DuckDB 1.5 PEG parser" --> `references/versions/1.5.md`
- "DuckDB 1.5.3 Quack remote protocol / quack_serve / how to secure Quack" --> `references/versions/1.5.md` (+ `references/quack.md`)
- "DuckDB 1.4 database encryption" --> `references/versions/1.4.md`
- "DuckDB 1.4 MERGE statement" --> `references/versions/1.4.md`
- "DuckDB 1.4 Iceberg writes" --> `references/versions/1.4.md`

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Version-specific feature** -- See the matching `references/versions/<v>.md` file
   - **Comparison with other databases** -- see the `overview` skill

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

**Key implication:** DuckDB is not a replacement for PostgreSQL/MySQL in multi-user OLTP workloads. It excels at single-user or embedded analytical workloads -- data science notebooks, ETL pipelines, local data exploration, edge analytics, and browser-based analytics via WASM. (As of v1.5.3, the **Quack** protocol adds an *optional* client-server mode on top of this -- see below.)

### Remote Access via the Quack Protocol (v1.5.3+)

DuckDB's in-process model means a persistent database file allows concurrent readers but only a single writer. The **Quack remote protocol** (a core extension shipped in v1.5.3, currently **beta**) relaxes this by turning a DuckDB process into an HTTP(S) server that other DuckDB processes connect to as clients -- giving DuckDB an optional client-server / RPC mode for concurrent remote read-write against a shared database.

```sql
-- Server: expose this DuckDB over HTTP (default port 9494, localhost-only by default)
CALL quack_serve('quack:localhost', token = 'super_secret');

-- Client: attach and query the remote database as if it were local
CREATE SECRET (TYPE quack, TOKEN 'super_secret', SCOPE 'quack:localhost');
ATTACH 'quack:localhost' AS remote;
FROM remote.my_table;
```

The client uses plain HTTP for local URIs and **HTTPS for everything else** automatically. The server does not terminate TLS itself: for any non-local deployment the recommendation is to **front it with a TLS-terminating reverse proxy (e.g. nginx) and serve over standard HTTPS** rather than exposing Quack directly. Quack is version-specific to 1.5.3+ -- route deep questions to `references/versions/1.5.md`, and load `references/quack.md` for the full setup, security model, and endpoint guidance.

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

See `references/file-reading.md#universal-file-reading-with-read_any-macro` — the `read_any` macro definition and its extension-to-reader dispatch table for auto-detecting arbitrary file formats.

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
| **quack** | Remote/client-server RPC protocol over HTTP (v1.5.3+, beta) | Concurrent remote read/write to a shared DuckDB |

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

See `references/language-integrations.md#python-integration` — connection setup, querying Pandas/Polars/Arrow in place, the relational API, prepared statements, and the Appender for bulk inserts.

### WASM Deployment

See `references/language-integrations.md#wasm-deployment` — browser/Node.js setup via `@duckdb/duckdb-wasm`, worker/module instantiation, and querying remote Parquet over HTTP.

### R Integration

See `references/language-integrations.md#r-integration` — DBI connection setup, querying R data.frames, and dplyr integration.

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

1. **Treating DuckDB as a multi-user server** -- DuckDB is single-writer at the file level. The Quack protocol (v1.5.3+, beta) adds a client-server mode for concurrent remote read/write against a shared DuckDB, but it is point-to-point (not a distributed engine) and tops out around 8 concurrent write threads today. For high-concurrency multi-user OLTP/OLAP, still use PostgreSQL, MySQL, or a cloud warehouse.

2. **Not leveraging direct file queries** -- Importing data into tables before querying is often unnecessary. `SELECT * FROM 'data.parquet'` is efficient and avoids data duplication.

3. **Ignoring Hive partitioning for large datasets** -- For multi-GB Parquet datasets, Hive-style partitioning (`year=2025/month=01/`) with `hive_partitioning = true` enables partition pruning.

4. **Over-indexing** -- DuckDB's columnar scan with zonemaps handles most analytical queries without explicit indexes. ART indexes help primarily for point lookups on persistent tables.

5. **Setting memory_limit too low** -- Default is 80% of RAM, which is usually optimal. Lowering it forces disk spilling, which dramatically slows analytical queries. If you must limit memory, try reducing threads first.

6. **Not using COPY for bulk exports** -- Using INSERT INTO ... SELECT for large exports is slower than `COPY ... TO 'file.parquet'` with Parquet format and ZSTD compression.

7. **Forgetting UNION BY NAME for heterogeneous schemas** -- When combining files with slightly different columns, `UNION ALL BY NAME` matches by column name rather than position.

8. **Not using QUALIFY** -- Writing CTEs or subqueries just to filter window function results is unnecessary in DuckDB. Use the QUALIFY clause directly.

9. **Running DuckDB in Docker without volume mapping for persistent databases** -- The database file must be on a mapped volume, or data is lost when the container stops.

10. **Not updating extensions** -- After upgrading DuckDB, run `UPDATE EXTENSIONS;` to ensure extension compatibility.

## Version-specific guidance

| Version | Status | Key Features | Reference |
|---|---|---|---|
| **DuckDB 1.5** | Current (Mar 2026) | VARIANT type, built-in GEOMETRY, Friendly CLI, PEG parser, ODBC scanner, Lance format, Azure writes, Quack remote protocol (v1.5.3, beta) | `references/versions/1.5.md` |
| **DuckDB 1.4** | LTS (until Sep 2026) | Database encryption (AES-256-GCM), MERGE statement, Iceberg writes, materialized CTEs by default | `references/versions/1.4.md` |

## Reference Files

Load these when you need deep knowledge for a specific area:

- `references/architecture.md` -- Vectorized execution engine, columnar storage format, buffer management, morsel-driven parallelism, extension loading, catalog system. Read for "how does DuckDB work internally" questions.
- `references/diagnostics.md` -- PRAGMA commands, system catalog queries, EXPLAIN ANALYZE interpretation, profiling, extension management, file scanning options, memory diagnostics. Read when troubleshooting performance or investigating database state.
- `references/best-practices.md` -- Memory/thread tuning, file format selection, data loading strategies, Python/R integration patterns, deployment models, backup/recovery, security (including Quack remote-protocol security). Read for configuration and operational guidance.
- `references/quack.md` -- The Quack remote/client-server protocol (v1.5.3+, beta): what it is, server and client setup, the full security model (HTTP-vs-HTTPS rule, TLS-terminating reverse proxy, token/secret auth, bind defaults), the recommended HTTPS endpoint, hardening checklist, and limitations. Read for "how do I set up / secure DuckDB remote access" questions.

## External Resources

- **DuckDB Skills Plugin (Claude Code)** -- https://github.com/duckdb/duckdb-skills -- Official DuckDB plugin for Claude Code providing interactive skills: `attach-db` (attach and explore databases), `query` (run SQL or natural language queries), `read-file` (universal data file reader), `duckdb-docs` (full-text search of DuckDB/DuckLake documentation), `install-duckdb` (extension management), and `read-memories` (search past session logs). Install via `/plugin marketplace add duckdb/duckdb-skills`. Skills share a `state.sql` session file for persistent state across commands.
- **DuckDB Documentation** -- https://duckdb.org/docs -- Official documentation covering SQL reference, functions, configuration, extensions, and client APIs.
- **DuckDB Blog** -- https://duckdb.org/blog -- Technical blog posts with deep dives on internals, new features, benchmarks, and use cases.
- **DuckLake Documentation** -- https://ducklake.select/docs -- Documentation for DuckLake, a DuckDB-powered catalog layer for data lakes.
