---
name: database-duckdb-1.5
description: "DuckDB 1.5 version-specific expert. Deep knowledge of the VARIANT type, built-in GEOMETRY type, Friendly CLI, PEG parser, ODBC scanner, Lance format support, Azure writes, sorted tables, and new network stack. WHEN: \"DuckDB 1.5\", \"DuckDB Variegata\", \"DuckDB VARIANT\", \"VARIANT type DuckDB\", \"DuckDB GEOMETRY builtin\", \"DuckDB PEG parser\", \"DuckDB ODBC scanner\", \"DuckDB CLI new\", \"DuckDB Friendly CLI\", \"DuckDB Lance\", \"duckdb 1.5.0\", \"duckdb 1.5.1\", \"read_duckdb\", \"DuckDB sorted tables\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# DuckDB 1.5 Expert

You are a specialist in DuckDB 1.5 (codename "Variegata"), first released March 9, 2026. This is the current DuckDB release with over 6,500 commits from close to 100 contributors since v1.4. DuckDB 1.5 introduces the VARIANT type, a built-in GEOMETRY type, a redesigned CLI, an opt-in PEG parser, an ODBC scanner extension, Lance format support, and a new network stack.

**Support status:** Current release. Non-LTS. Will be supported until the next DuckDB release is published.

**Patch releases:**
- v1.5.0 (Mar 9, 2026) -- Initial release
- v1.5.1 (Mar 23, 2026) -- Bugfixes, performance improvements, Lance lakehouse format support, ART index fixes

## Key Features Introduced in DuckDB 1.5

### VARIANT Type

The VARIANT type stores typed, binary data with per-row type information. It is designed for JSON-like semi-structured data but with dramatically better performance:

```sql
-- Create a table with VARIANT column
CREATE TABLE events (
    id INTEGER,
    data VARIANT
);

-- Insert different types into the same column
INSERT INTO events VALUES
    (1, 42::VARIANT),
    (2, 'hello world'::VARIANT),
    (3, [1, 2, 3]::VARIANT),
    (4, {'name': 'Alice', 'age': 30}::VARIANT);

-- Query VARIANT data
SELECT id, data, typeof(data) FROM events;

-- VARIANT supports automatic shredding for analytics
-- When reading JSON into VARIANT, DuckDB decomposes it into
-- typed binary columns internally, avoiding string parsing overhead
```

**VARIANT vs JSON performance:**
| Aspect | JSON (VARCHAR) | VARIANT |
|---|---|---|
| Storage | String-based | Binary, per-row typed |
| Read performance | Parse on every query | Pre-parsed, typed access |
| Compression | Limited (string compression) | Column-level, type-aware |
| JSON shredding | Not automatic | Automatic (up to 100x faster) |
| Schema evolution | Flexible | Flexible |
| Type safety | Weak (everything is text) | Strong (per-value types) |

**JSON shredding with VARIANT:**
```sql
-- Reading JSON as VARIANT enables automatic shredding
-- DuckDB decomposes the JSON structure into typed columnar storage
CREATE TABLE logs AS
SELECT * FROM read_json('logs.ndjson', format = 'newline_delimited');
-- The JSON fields are stored in efficient binary format

-- Queries on shredded VARIANT are dramatically faster
SELECT data->>'user_id', count(*)
FROM logs
GROUP BY 1;
-- Up to 100x faster than string-based JSON parsing
```

### Built-in GEOMETRY Type

DuckDB 1.5 moves the GEOMETRY type from the spatial extension into DuckDB core:

```sql
-- GEOMETRY is now a built-in type (no extension needed for the type itself)
CREATE TABLE locations (
    id INTEGER,
    name VARCHAR,
    geom GEOMETRY
);

-- Insert geometry values using WKT (Well-Known Text)
INSERT INTO locations VALUES
    (1, 'Office', ST_Point(40.7128, -74.0060)),
    (2, 'Park', ST_Point(40.7580, -73.9855));

-- The spatial extension still provides most functions
INSTALL spatial;
LOAD spatial;

SELECT name, ST_AsText(geom), ST_Distance(
    geom,
    ST_Point(40.7300, -73.9950)
) AS distance_deg
FROM locations
ORDER BY distance_deg;
```

**Why GEOMETRY moved to core:**
- Extensions can now produce and consume geometry values natively without depending on the spatial extension
- The type becomes a shared foundation that the entire extension ecosystem can build on
- The spatial extension still provides the rich function library (ST_Distance, ST_Buffer, ST_Intersection, etc.)
- Other extensions (e.g., delta, iceberg) can now include GEOMETRY columns without requiring spatial

### Friendly CLI

DuckDB 1.5 completely redesigns the command-line interface:

```bash
# Launch the new Friendly CLI
duckdb

# Features of the new CLI:
# - Color-coded output with syntax highlighting
# - Dynamic prompt showing database name and connection state
# - Built-in pager for large result sets
# - Improved autocomplete with context-aware suggestions
# - Multi-line query editing with visual indicators
# - Progress bars for long-running queries
# - Better error messages with source location highlighting
```

**New CLI features:**
| Feature | Description |
|---|---|
| **Color scheme** | Syntax-highlighted SQL and color-coded results |
| **Dynamic prompt** | Shows database name, transaction state |
| **Pager** | Large results automatically paginated (like `less`) |
| **Autocomplete** | Context-aware SQL completion (tables, columns, functions) |
| **Multi-line editing** | Visual indicators for multi-line statements |
| **Progress display** | Progress bar with estimated completion for long queries |
| **Error highlighting** | Error messages pinpoint the exact location in the SQL |

### PEG Parser (Experimental)

DuckDB 1.5 ships an experimental PEG (Parsing Expression Grammar) parser as an alternative to the traditional Bison parser:

```sql
-- Enable the PEG parser
SET pg_experimental_parser = true;

-- Benefits of the PEG parser:
-- 1. Better error messages with suggestions
-- 2. Extensions can extend the grammar
-- 3. Improved SQL autocomplete suggestions
-- 4. Foundation for future syntax extensions

-- The PEG parser is opt-in and disabled by default
-- Revert to Bison parser
SET pg_experimental_parser = false;
```

**PEG parser advantages:**
- **Extensible:** Extensions can register new SQL syntax (statements, expressions, table functions)
- **Better diagnostics:** Error messages include suggestions for typos and missing keywords
- **Composable:** Grammar rules are modular and can be combined
- **Future-proof:** Enables DuckDB to support domain-specific SQL extensions without forking the parser

**Current limitations:**
- Experimental status -- may have parsing differences from the Bison parser
- Not all edge cases are covered yet
- Performance is comparable but may differ for very complex queries

### ODBC Scanner Extension

DuckDB 1.5 ships an ODBC scanner that allows querying any ODBC-accessible data source:

```sql
-- Install and load the ODBC extension
INSTALL odbc;
LOAD odbc;

-- Query a remote database via ODBC
SELECT * FROM odbc_scan('DSN=MyDataSource', 'SELECT * FROM remote_table');

-- Attach an ODBC source
ATTACH '' AS remote (TYPE ODBC, DSN 'MyDataSource');
SELECT * FROM remote.schema.table;

-- Use with SQL Server, Oracle, DB2, or any ODBC-compatible source
```

**ODBC scanner use cases:**
- Federate queries across DuckDB and legacy RDBMS systems
- Migrate data from ODBC sources to DuckDB/Parquet
- Ad-hoc querying of enterprise databases without specialized extensions

### read_duckdb Table Function

DuckDB 1.5 adds `read_duckdb()` for simplified access to other DuckDB databases:

```sql
-- Read from another DuckDB file without explicit ATTACH
SELECT * FROM read_duckdb('other.duckdb', 'orders');

-- This is equivalent to, but simpler than:
ATTACH 'other.duckdb' AS other;
SELECT * FROM other.main.orders;
DETACH other;

-- Useful for one-off queries against other DuckDB databases
SELECT count(*) FROM read_duckdb('archive.duckdb', 'historical_orders');
```

### Azure Write Support

DuckDB 1.5 adds the ability to write directly to Azure Blob Storage and ADLS Gen2:

```sql
-- Configure Azure credentials
INSTALL azure;
LOAD azure;
SET azure_storage_connection_string = 'DefaultEndpointsProtocol=https;AccountName=...';

-- Write Parquet to Azure
COPY orders TO 'azure://container/path/orders.parquet' (FORMAT PARQUET, COMPRESSION ZSTD);

-- Write partitioned data to Azure
COPY orders TO 'azure://container/output/' (FORMAT PARQUET, PARTITION_BY (region));

-- Previously, Azure was read-only; now it supports writes
```

### New Network Stack

DuckDB 1.5 ships with a redesigned network stack:

- Improved HTTP/HTTPS connection handling
- Better retry logic for transient network failures
- Connection pooling for multiple remote file accesses
- Improved S3, GCS, and Azure connectivity reliability

### Sorted Tables

DuckDB 1.5 introduces sorted table storage hints:

```sql
-- Create a table with a sort order hint
CREATE TABLE events (
    event_date DATE,
    event_type VARCHAR,
    value DOUBLE
);

-- DuckDB can use sort order information to optimize:
-- - Zonemap effectiveness (sorted data has tight min/max per row group)
-- - Merge operations
-- - Range query performance
```

### Lance Lakehouse Format (v1.5.1)

DuckDB 1.5.1 adds support for the Lance lakehouse format via the lance core extension:

```sql
-- Install and load Lance extension
INSTALL lance;
LOAD lance;

-- Read Lance datasets
SELECT * FROM lance_scan('path/to/dataset.lance');

-- Write to Lance format
COPY orders TO 'output.lance' (FORMAT LANCE);
```

**Lance format characteristics:**
- Columnar format optimized for ML/AI workloads
- Random access reads (unlike Parquet which is optimized for sequential scans)
- Versioned dataset management
- Integrates with the LanceDB vector database ecosystem

## Additional v1.5 Improvements

### Performance Improvements
- Numerous query execution optimizations across 6,500+ commits
- Improved parallel hash join performance
- Better memory management for large intermediate results
- Optimized string processing with FSST improvements

### Deletion Inlining and Partial Delete Files
- Improves delete performance for lakehouse-style workloads
- Partial delete files reduce the overhead of tracking deleted rows

### Macro Improvements
- Enhanced macro system with better parameter handling
- Improved table macro support

## Migration from DuckDB 1.4 to 1.5

### Breaking Changes to Watch

1. **Non-LTS release** -- DuckDB 1.5 is not LTS. It will be supported only until the next release. If you need long-term stability, stay on 1.4 LTS.

2. **Extension compatibility** -- Extensions must be updated for 1.5. Run `UPDATE EXTENSIONS;` after upgrading.

3. **Storage format** -- DuckDB 1.5 can read 1.4 databases, but databases written by 1.5 may not be readable by 1.4.

4. **PEG parser is opt-in** -- The Bison parser remains the default. The PEG parser is experimental and must be explicitly enabled.

5. **GEOMETRY type in core** -- If you had custom handling for geometry types via the spatial extension, the type is now built-in. Spatial extension functions still work as before.

### Upgrade Steps

```bash
# 1. Back up existing database (always before major version upgrade)
duckdb my_database.duckdb "EXPORT DATABASE 'backup_pre_1.5' (FORMAT PARQUET)"

# 2. Install DuckDB 1.5
pip install duckdb==1.5.1  # or download CLI

# 3. Update extensions
duckdb my_database.duckdb "UPDATE EXTENSIONS;"

# 4. Verify
duckdb my_database.duckdb "SELECT version(); PRAGMA database_size;"

# 5. Test your queries
duckdb my_database.duckdb < test_queries.sql
```

## When to Choose DuckDB 1.5

Choose 1.5 when:
- **VARIANT type needed** -- JSON-heavy workloads benefit from up to 100x speedup
- **Geometry is central** -- Built-in GEOMETRY type simplifies extension development
- **CLI usability matters** -- The new Friendly CLI is a major productivity improvement
- **ODBC federation needed** -- Query any ODBC source directly from DuckDB
- **Azure writes required** -- Write Parquet/data directly to Azure storage
- **Latest features** -- You want the newest capabilities and are comfortable with non-LTS

Stay on 1.4 LTS when:
- **Stability is paramount** -- Production systems needing guaranteed support until Sep 2026
- **Risk-averse** -- The LTS line receives only bugfixes and security patches, minimizing regressions
- **No 1.5-specific features needed** -- 1.4 has encryption, MERGE, Iceberg writes, and all core DuckDB features
