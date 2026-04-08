# DuckDB Architecture Reference

## In-Process Execution Model

DuckDB runs as an embedded library inside the host application -- there is no separate server process, no socket communication, no client-server protocol overhead:

```
┌─────────────────────────────────────────────┐
│           Host Application                  │
│  (Python, R, Node.js, Java, C++, Rust, Go)  │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │           DuckDB Engine               │  │
│  │  ┌──────────┐  ┌──────────────────┐   │  │
│  │  │  Parser   │  │  Optimizer       │   │  │
│  │  │  (Bison/  │  │  (cost-based,   │   │  │
│  │  │   PEG)    │  │   join ordering, │   │  │
│  │  │          │  │   filter pushdown)│   │  │
│  │  └──────────┘  └──────────────────┘   │  │
│  │  ┌──────────┐  ┌──────────────────┐   │  │
│  │  │ Catalog  │  │  Execution Engine │   │  │
│  │  │ System   │  │  (vectorized,    │   │  │
│  │  │          │  │   push-based)     │   │  │
│  │  └──────────┘  └──────────────────┘   │  │
│  │  ┌──────────────────────────────────┐ │  │
│  │  │  Buffer Manager / Storage        │ │  │
│  │  │  (columnar, compressed,          │ │  │
│  │  │   single-file database)          │ │  │
│  │  └──────────────────────────────────┘ │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Connection Model

- A DuckDB instance is associated with a single database file (or `:memory:`)
- Multiple connections can be opened to the same database within a single process
- Multiple processes can read a persistent database concurrently (shared read lock)
- Only one process can write to a persistent database at a time (exclusive write lock)
- Named in-memory databases (`:memory:connN`) allow shared catalogs within a process

### Thread Model

DuckDB uses a single-process, multi-threaded model:

- All threads operate within the host process address space
- Worker threads are managed by DuckDB's internal thread pool
- Thread count defaults to the number of available CPU cores
- Each query is parallelized across available threads via morsel-driven parallelism
- Thread-local state minimizes lock contention

## Query Processing Pipeline

### 1. Parsing

DuckDB parses SQL into an abstract syntax tree (AST):

- **Bison parser** (default): Traditional LALR parser, battle-tested and fast
- **PEG parser** (opt-in, v1.5+): Parsing Expression Grammar parser, extensible by extensions, better error messages

```sql
-- Enable the PEG parser (v1.5+)
SET pg_experimental_parser = true;
```

### 2. Binding and Type Resolution

The binder resolves table names, column references, function overloads, and implicit casts:

- Column aliases are resolved early (usable in WHERE, GROUP BY, HAVING -- the "Friendly SQL" behavior)
- Implicit casting follows a well-defined promotion hierarchy
- STRUCT/LIST/MAP types are resolved recursively
- Schema search path: `temp` schema first, then `main`

### 3. Optimization

DuckDB uses a cost-based optimizer with multiple transformation rules:

**Logical optimizations (rule-based):**
- Filter pushdown -- pushes predicates as close to the scan as possible
- Projection pushdown -- removes unused columns early
- Common subexpression elimination
- Constant folding -- evaluates constant expressions at plan time
- CTE materialization (default in 1.4+) -- materializes CTEs to avoid redundant computation
- Unnest rewriting -- flattens correlated subqueries

**Physical optimizations (cost-based):**
- Join order optimization (using a dynamic programming enumerator for up to ~20 tables, greedy for more)
- Join type selection (hash join, merge join, nested loop join, index join)
- Aggregation strategy (hash aggregation vs. sorted/streaming aggregation)
- Scan method selection (sequential scan, index scan, filter scan)
- Parallelism insertion -- determines pipeline breakers and parallelizable segments

**Statistics propagation:**
- Base table statistics from storage metadata (row count, min/max per column per row group)
- Derived statistics propagated through operators
- Histogram-based estimation for filter selectivity

### 4. Execution

DuckDB uses a push-based, vectorized, morsel-driven execution model.

#### Push-Based Model

Unlike Volcano-style (pull-based) engines where the root operator calls `next()` on children, DuckDB's operators push data downstream:

```
Source (Scan) --push--> Filter --push--> HashAggregate --push--> Sink (Result)
```

- Reduces virtual function call overhead vs. pull-based
- Enables better pipeline fusion (operators can be compiled together)
- Pipelines are broken at materialization points (hash table build side, sort, etc.)

#### Vectorized Execution

Operations process columns of data in batches (vectors) of `STANDARD_VECTOR_SIZE` (2048 tuples):

```
Traditional (row-at-a-time):
  for each row:
    filter(row)        -- branch prediction miss, cache miss
    project(row)       -- function call overhead per row
    aggregate(row)

Vectorized (DuckDB):
  for each vector (2048 rows):
    filter(vector)     -- tight loop, SIMD, branch-free
    project(vector)    -- operate on arrays, cache-friendly
    aggregate(vector)  -- batch updates to hash table
```

Benefits:
- **CPU cache efficiency** -- 2048 values of a single column fit in L1/L2 cache
- **SIMD utilization** -- arithmetic operations on integer/float arrays use AVX2/SSE instructions
- **Branch elimination** -- selection vectors (bitmasks) replace branching in filters
- **Reduced interpretation overhead** -- per-vector dispatch rather than per-row

#### Selection Vectors

Instead of materializing filtered rows, DuckDB uses selection vectors (bitmasks) that indicate which rows in a vector passed a filter:

```
Vector: [10, 20, 30, 40, 50, 60, 70, 80]
Filter: value > 30
Selection vector: [0, 0, 0, 1, 1, 1, 1, 1]

Subsequent operators only process selected rows without copying data.
```

#### Morsel-Driven Parallelism

DuckDB divides work into morsels (chunks of row groups) and distributes them across threads:

```
Table (1M rows)
├── Row Group 0 (122,880 rows) ──> Thread 1
├── Row Group 1 (122,880 rows) ──> Thread 2
├── Row Group 2 (122,880 rows) ──> Thread 3
├── Row Group 3 (122,880 rows) ──> Thread 1  (work-stealing)
├── ...
└── Row Group 8 (partial)       ──> Thread 4
```

- Each thread processes one morsel at a time
- Work-stealing: idle threads can claim work from other threads' queues
- Pipeline-local state (e.g., partial aggregation hash tables) is thread-local
- Global synchronization only at pipeline breakers (hash table merge, sort merge)
- Result: near-linear speedup with thread count for scan-heavy queries

### 5. Result Materialization

Results are delivered in one of several formats depending on the client:

- **DuckDB vectors** -- internal columnar format (C/C++ API)
- **Arrow arrays** -- zero-copy transfer to Arrow-compatible consumers (Python, R)
- **Pandas DataFrame** -- via Arrow conversion (Python)
- **Polars DataFrame** -- via Arrow conversion (Python)
- **Row-by-row fetch** -- traditional cursor-style (all client APIs)

## Storage Architecture

### Single-File Database

A persistent DuckDB database consists of:

```
my_database.duckdb          -- main database file
my_database.duckdb.wal      -- write-ahead log (temporary, removed on clean shutdown)
```

The main file contains:
- **Header block** -- magic bytes, version, configuration
- **Metadata blocks** -- schema definitions, table metadata, statistics
- **Data blocks** -- columnar data organized in row groups
- **Free list** -- tracks deallocated blocks for reuse

### Row Groups

Tables are partitioned into row groups of approximately 122,880 rows:

```
Table: orders (500,000 rows)
├── Row Group 0: rows 0-122,879
│   ├── Column 'id':      compressed integer segment
│   ├── Column 'date':    compressed timestamp segment
│   ├── Column 'amount':  compressed double segment
│   └── Column 'region':  dictionary-encoded string segment
├── Row Group 1: rows 122,880-245,759
│   ├── ...
├── Row Group 2: rows 245,760-368,639
│   ├── ...
└── Row Group 3: rows 368,640-499,999
    ├── ...
```

### Column Compression

DuckDB automatically selects the best compression per column segment:

| Compression | Data Types | When Used |
|---|---|---|
| **Constant** | Any | All values in segment are identical |
| **Dictionary** | String, numeric | Low cardinality (few distinct values) |
| **Bitpacking** | Integer | Values fit in fewer bits than the type width |
| **RLE** (Run-Length Encoding) | Any | Long runs of repeated values |
| **FSST** (Fast Static Symbol Table) | String | High-cardinality strings |
| **ALP** (Adaptive Lossless floating-Point) | Float/Double | Floating-point with patterns |
| **Chimp** | Double | Time-series double values |
| **Uncompressed** | Any | Fallback when compression doesn't help |

Compression is chosen per column per row group. DuckDB tests multiple encodings and picks the one with the best compression ratio.

### Zonemaps (Min/Max Indexes)

Every column segment stores min and max values. During scans, entire row groups can be skipped:

```sql
-- If row group 2 has min(date) = '2025-06-01' and max(date) = '2025-06-30':
SELECT * FROM orders WHERE date = '2025-01-15';
-- Row group 2 is SKIPPED entirely (zonemap pruning)
```

Zonemaps work best when data has natural ordering (e.g., timestamps, sequential IDs). For unordered data, zonemaps may not prune effectively.

### Buffer Manager

The buffer manager controls memory allocation and disk spilling:

- Manages a budget defined by `memory_limit` (default: 80% of system RAM)
- Pages are loaded on demand and evicted using a clock-sweep algorithm
- When memory pressure exceeds the limit, intermediate results spill to the `temp_directory`
- Buffer pins prevent eviction of actively used pages
- Block size: 256KB (configurable)

```sql
-- Check current memory usage
SELECT * FROM pragma_database_size();

-- Current memory configuration
SELECT current_setting('memory_limit');
SELECT current_setting('temp_directory');
```

### Write-Ahead Log (WAL)

DuckDB uses a WAL for crash recovery on persistent databases:

- Writes are first appended to the WAL before modifying data blocks
- On clean shutdown, the WAL is replayed and removed
- On crash, the WAL is replayed on the next database open
- Checkpointing flushes WAL changes to the main file

```sql
-- Force a checkpoint (flush WAL to main file)
CHECKPOINT;
FORCE CHECKPOINT;

-- Configure auto-checkpoint threshold
SET wal_autocheckpoint = '256MB';
```

## Catalog System

DuckDB maintains a transactional catalog with ACID semantics:

### Database Hierarchy

```
Database Instance
├── database: memory (or file)
│   ├── schema: main (default)
│   │   ├── tables
│   │   ├── views
│   │   ├── macros (scalar and table)
│   │   ├── sequences
│   │   ├── types
│   │   └── indexes
│   ├── schema: information_schema
│   └── schema: pg_catalog (PostgreSQL compatibility)
├── database: temp (session-scoped temporary objects)
│   └── schema: main
└── attached databases (ATTACH)
```

### ATTACH for Multi-Database Queries

```sql
-- Attach another DuckDB file
ATTACH 'other.duckdb' AS other_db;

-- Attach a PostgreSQL database (via postgres_scanner)
ATTACH 'dbname=mydb' AS pg_db (TYPE POSTGRES);

-- Attach a SQLite database (via sqlite_scanner)
ATTACH 'data.sqlite' AS sqlite_db (TYPE SQLITE);

-- Attach a MySQL database (via mysql_scanner)
ATTACH 'host=localhost database=mydb user=root' AS mysql_db (TYPE MYSQL);

-- Cross-database query
SELECT a.*, b.*
FROM main.orders a
JOIN other_db.customers b ON a.customer_id = b.id;

-- Detach
DETACH other_db;
```

### Macro System

DuckDB supports both scalar and table macros as reusable query building blocks:

```sql
-- Scalar macro
CREATE MACRO add_tax(price, rate := 0.08) AS price * (1 + rate);
SELECT add_tax(100);       -- 108.0
SELECT add_tax(100, 0.10); -- 110.0

-- Table macro
CREATE MACRO recent_orders(days := 30) AS TABLE
    SELECT * FROM orders WHERE order_date > current_date - INTERVAL (days) DAYS;
SELECT * FROM recent_orders(7);  -- last 7 days

-- Macro in combination with COLUMNS
CREATE MACRO normalize(x) AS (x - min(x)) OVER () / (max(x) - min(x)) OVER ();
```

## Extension Architecture

### Loading Mechanism

Extensions are shared libraries (.duckdb_extension) loaded at runtime:

```
Extension search paths (in order):
1. In-memory (already loaded)
2. Local extension directory (~/.duckdb/extensions/{platform}/{duckdb_version}/)
3. Remote extension repository (extensions.duckdb.org or community repo)
```

### Extension Categories

- **Core extensions** -- maintained by DuckDB team, hosted on extensions.duckdb.org (27+ extensions)
- **Community extensions** -- maintained by third parties, hosted on community.duckdb.org (150+ extensions)
- **Custom extensions** -- user-built extensions using the DuckDB extension API

### Autoloading

DuckDB can automatically install and load extensions when a function or feature they provide is first used:

```sql
-- This auto-installs and loads the httpfs extension
SELECT * FROM read_parquet('s3://bucket/data.parquet');

-- Autoloading can be disabled
SET autoinstall_known_extensions = false;
SET autoload_known_extensions = false;
```

### Extension Security

```sql
-- Allow loading unsigned extensions (community extensions are signed)
SET allow_unsigned_extensions = true;

-- Extensions run in the same process as DuckDB -- they have full access
-- to the host process memory. Only load trusted extensions.
```

## Transaction Model

DuckDB implements serializable ACID transactions using MVCC (Multi-Version Concurrency Control):

- **Read transactions** -- see a consistent snapshot of the database at transaction start time
- **Write transactions** -- exclusive access; only one write transaction at a time
- **Implicit transactions** -- each statement is wrapped in an implicit transaction if not in an explicit one
- **Optimistic concurrency** -- multiple connections can start read transactions concurrently; writes are serialized

```sql
-- Explicit transaction
BEGIN TRANSACTION;
INSERT INTO orders VALUES (1, 'US', 100);
UPDATE inventory SET qty = qty - 1 WHERE id = 1;
COMMIT;

-- Rollback
BEGIN TRANSACTION;
DELETE FROM orders WHERE id = 1;
ROLLBACK;  -- undo the delete
```

### Concurrency Rules

| Operation | Concurrent Reads | Concurrent Writes |
|---|---|---|
| Read-only query | Yes (unlimited) | Yes (reads see snapshot before write) |
| Write query | Yes | No (serialized) |
| DDL (CREATE/ALTER/DROP) | Yes (reads see old schema) | No |
| CHECKPOINT | Blocks writes | No |

## Data Type System

### Numeric Types

| Type | Size | Range |
|---|---|---|
| `TINYINT` | 1 byte | -128 to 127 |
| `SMALLINT` | 2 bytes | -32,768 to 32,767 |
| `INTEGER` | 4 bytes | -2,147,483,648 to 2,147,483,647 |
| `BIGINT` | 8 bytes | -9.2e18 to 9.2e18 |
| `HUGEINT` | 16 bytes | -1.7e38 to 1.7e38 |
| `UHUGEINT` | 16 bytes | 0 to 3.4e38 |
| `UTINYINT`, `USMALLINT`, `UINTEGER`, `UBIGINT` | varies | Unsigned variants |
| `FLOAT` | 4 bytes | IEEE 754 single precision |
| `DOUBLE` | 8 bytes | IEEE 754 double precision |
| `DECIMAL(p, s)` | varies | Exact numeric with precision p, scale s |

### String Types

| Type | Description |
|---|---|
| `VARCHAR` | Variable-length string (no maximum length) |
| `BLOB` | Binary large object |
| `BIT` | Bit string |

### Date/Time Types

| Type | Description | Example |
|---|---|---|
| `DATE` | Calendar date | `DATE '2025-01-15'` |
| `TIME` | Time of day | `TIME '14:30:00'` |
| `TIMESTAMP` | Date + time (microsecond) | `TIMESTAMP '2025-01-15 14:30:00'` |
| `TIMESTAMP WITH TIME ZONE` | Timestamp + timezone | `TIMESTAMPTZ '2025-01-15 14:30:00+05:00'` |
| `INTERVAL` | Time interval | `INTERVAL 3 DAYS` |

### Complex Types

| Type | Description | Literal |
|---|---|---|
| `LIST` | Ordered array of values | `[1, 2, 3]` |
| `STRUCT` | Named fields (like a row) | `{'name': 'Alice', 'age': 30}` |
| `MAP` | Key-value pairs | `map(['a', 'b'], [1, 2])` |
| `UNION` | Tagged union (sum type) | `union_value(str := 'hello')` |
| `ARRAY` | Fixed-size array | `[1, 2, 3]::INTEGER[3]` |
| `ENUM` | Enumerated type | `CREATE TYPE mood AS ENUM ('happy', 'sad')` |
| `VARIANT` (v1.5+) | Self-describing typed binary | Binary JSON-like storage |
| `GEOMETRY` (v1.5+) | Built-in geometry type | Spatial data |

## Parallel Execution Details

### Pipeline Construction

The optimizer splits the query plan into pipelines separated by pipeline breakers:

```
Query: SELECT region, sum(amount) FROM orders WHERE amount > 100 GROUP BY region ORDER BY sum DESC

Pipeline 1 (parallelizable):
  Scan(orders) → Filter(amount > 100) → HashAggregate(build)

Pipeline breaker: hash table finalization

Pipeline 2:
  HashAggregate(probe) → Sort(sum DESC) → ResultCollector
```

### Parallel Operators

| Operator | Parallelization Strategy |
|---|---|
| Table Scan | Morsel-based: each thread scans different row groups |
| Filter | Inherits parallelism from scan |
| Projection | Inherits parallelism from scan |
| Hash Join (build) | Parallel build into thread-local hash tables, then merge |
| Hash Join (probe) | Parallel probe with partitioned output |
| Hash Aggregate | Thread-local partial aggregation, then global merge |
| Sort | Parallel sort of partitions, then merge sort |
| Window | Parallel per-partition computation |
| Limit | Global limit with early termination |

### Inter-Operator Parallelism

DuckDB can execute independent pipelines concurrently when the query plan allows it (e.g., building both sides of a hash join simultaneously).
