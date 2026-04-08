# TimescaleDB Architecture Reference

## Extension Architecture

TimescaleDB is implemented as a PostgreSQL extension (shared library loaded via `shared_preload_libraries`). It hooks into the PostgreSQL query planner, executor, and catalog system to provide transparent time-series partitioning, compression, and continuous aggregation without modifying the PostgreSQL core.

### Extension Loading

```
# postgresql.conf
shared_preload_libraries = 'timescaledb'
```

After loading, TimescaleDB creates its own schemas and catalog tables:
- `_timescaledb_catalog` -- Metadata tables for hypertables, chunks, dimensions, compression settings
- `_timescaledb_internal` -- Internal functions, chunk tables, compressed data tables
- `_timescaledb_config` -- Background job configuration (`bgw_job` table)
- `_timescaledb_cache` -- Internal caching mechanisms
- `timescaledb_information` -- User-facing informational views
- `timescaledb_experimental` -- Experimental features

### Catalog Tables (Internal)

```sql
-- Core catalog tables (DO NOT modify directly)
_timescaledb_catalog.hypertable          -- One row per hypertable
_timescaledb_catalog.chunk               -- One row per chunk
_timescaledb_catalog.dimension           -- Partitioning dimensions (time, space)
_timescaledb_catalog.dimension_slice     -- Time/space ranges for each chunk
_timescaledb_catalog.chunk_constraint    -- Constraint linking chunks to dimension slices
_timescaledb_catalog.compression_settings -- Compression configuration per hypertable
_timescaledb_catalog.continuous_agg      -- Continuous aggregate definitions
_timescaledb_catalog.continuous_aggs_materialization_invalidation_log
                                         -- Tracks which ranges need re-materialization
```

## Hypertable Internals

### Table Hierarchy

A hypertable is a virtual table. The actual data resides in child tables (chunks) in the `_timescaledb_internal` schema:

```
sensor_data (hypertable -- parent table, contains no data directly)
├── _timescaledb_internal._hyper_1_1_chunk  (time range: [2025-01-01, 2025-01-08))
├── _timescaledb_internal._hyper_1_2_chunk  (time range: [2025-01-08, 2025-01-15))
├── _timescaledb_internal._hyper_1_3_chunk  (time range: [2025-01-15, 2025-01-22))
└── ...
```

PostgreSQL's table inheritance mechanism is used. The hypertable is the parent, and chunks are children. INSERT/SELECT on the hypertable is transparently routed to the appropriate chunk(s).

### Chunk Creation

Chunks are created on-demand when data arrives in a time range that has no existing chunk:

1. An INSERT arrives with timestamp `T`
2. TimescaleDB calculates the chunk boundary: `floor(T / chunk_interval) * chunk_interval`
3. If no chunk exists for this range, a new chunk table is created in `_timescaledb_internal`
4. The chunk inherits all indexes and constraints from the hypertable
5. A CHECK constraint is added: `CHECK (time >= lower_bound AND time < upper_bound)`
6. The row is inserted into the new chunk

**Chunk naming convention:** `_hyper_{hypertable_id}_{chunk_id}_chunk`

### Dimension Partitioning

**Time dimension (required):**
- Every hypertable has at least one time dimension
- Supported types: `TIMESTAMPTZ`, `TIMESTAMP`, `DATE`, `INTEGER`, `BIGINT` (for epoch-based time)
- Chunk interval defines the time range per chunk

**Space dimension (optional):**
- Hash-based partitioning on a second column (e.g., `device_id`)
- Creates multiple chunks per time interval (one per hash partition)
- Total chunks per time interval = `number_partitions`
- Useful for parallel query execution across chunks
- **Caution:** Space partitioning multiplies chunk count. With `number_partitions=4` and daily chunks, that is 4 chunks/day = 1,460 chunks/year

```sql
-- Two-dimensional partitioning
SELECT create_hypertable('sensor_data', 'time',
    partitioning_column => 'sensor_id',
    number_partitions => 4,
    chunk_time_interval => INTERVAL '1 day');
```

**Chunk layout with space partitioning:**
```
Time range [2025-01-01, 2025-01-02):
├── _hyper_1_1_chunk  (sensor_id hash partition 0)
├── _hyper_1_2_chunk  (sensor_id hash partition 1)
├── _hyper_1_3_chunk  (sensor_id hash partition 2)
└── _hyper_1_4_chunk  (sensor_id hash partition 3)

Time range [2025-01-02, 2025-01-03):
├── _hyper_1_5_chunk  (sensor_id hash partition 0)
├── _hyper_1_6_chunk  (sensor_id hash partition 1)
├── _hyper_1_7_chunk  (sensor_id hash partition 2)
└── _hyper_1_8_chunk  (sensor_id hash partition 3)
```

### Chunk Exclusion (Constraint Exclusion)

The TimescaleDB query planner uses CHECK constraints on chunks to exclude chunks that cannot contain matching data:

1. Query arrives with `WHERE time > '2025-03-01' AND time < '2025-03-15'`
2. The planner checks each chunk's CHECK constraint against the WHERE clause
3. Chunks whose time range does not overlap `[2025-03-01, 2025-03-15)` are excluded
4. Only matching chunks appear in the query plan

**Planner integration:**
- TimescaleDB registers custom plan nodes: `ChunkAppend`, `ConstraintAwareAppend`
- `ChunkAppend` replaces PostgreSQL's `Append` node for hypertable scans
- Supports runtime chunk exclusion for parameterized queries (e.g., `WHERE time > $1`)

**EXPLAIN output example:**
```
Append  (actual rows=1000 loops=1)
  ->  Seq Scan on _hyper_1_42_chunk  (actual rows=500 loops=1)
        Filter: (time > '2025-03-01'::timestamptz)
  ->  Seq Scan on _hyper_1_43_chunk  (actual rows=500 loops=1)
        Filter: (time > '2025-03-01'::timestamptz)
  Chunks excluded: 41
```

### Index Management

Indexes created on the hypertable are automatically created on each chunk:

```sql
-- This creates an index on every existing and future chunk
CREATE INDEX ON sensor_data (sensor_id, time DESC);

-- TimescaleDB automatically creates a time index when creating the hypertable
-- Default: btree index on (time DESC) for each chunk
```

**Index types available (all PostgreSQL index types):**
- B-tree (default, best for range queries on time)
- Hash (equality lookups)
- GIN (full-text search, JSONB containment)
- GiST (PostGIS geometry, range types)
- BRIN (block range index -- less useful since chunks are already range-partitioned)
- SP-GiST (space-partitioned GiST)

**Per-chunk indexes vs. global indexes:**
- All indexes are per-chunk (no global index across all chunks)
- This is efficient because chunk exclusion narrows the search space before index lookup
- Unique constraints must include the partitioning column(s)

```sql
-- This works: unique constraint includes time
ALTER TABLE sensor_data ADD CONSTRAINT sensor_unique
    UNIQUE (sensor_id, time);

-- This does NOT work: unique constraint without partitioning column
-- ERROR: cannot create unique index without including partitioning column
ALTER TABLE sensor_data ADD CONSTRAINT sensor_unique
    UNIQUE (sensor_id);
```

## Compression Internals

### Compressed Storage Format

When a chunk is compressed, TimescaleDB converts it from PostgreSQL's row-oriented heap format to a column-oriented format:

**Uncompressed (row-oriented):**
```
Row 1: {time: 2025-01-01 00:00:00, sensor_id: 1, temp: 72.3, humidity: 45.2}
Row 2: {time: 2025-01-01 00:00:01, sensor_id: 1, temp: 72.4, humidity: 45.1}
Row 3: {time: 2025-01-01 00:00:02, sensor_id: 1, temp: 72.2, humidity: 45.3}
...
```

**Compressed (column-oriented, per segment):**
```
Segment (sensor_id = 1):
  time column:     [compressed array of 1000 timestamps using delta-of-delta]
  temp column:     [compressed array of 1000 floats using Gorilla encoding]
  humidity column: [compressed array of 1000 floats using Gorilla encoding]
```

### Segments and Batches

- A **segment** groups rows that share the same `segmentby` column values
- Within a segment, rows are sorted by `orderby` columns
- Rows are stored in **batches** (arrays of ~1000 values per column)
- Each batch is independently compressed using the type-appropriate algorithm

**Compressed chunk structure:**
```sql
-- A compressed chunk is a regular PostgreSQL table with one row per batch
-- Each "row" contains compressed arrays for each column
_timescaledb_internal.compress_hyper_2_100_chunk (
    sensor_id INTEGER,           -- segmentby column (uncompressed, used for filtering)
    _ts_meta_count INTEGER,      -- number of rows in this batch
    _ts_meta_min_1 TIMESTAMPTZ,  -- min time in this batch (for chunk exclusion)
    _ts_meta_max_1 TIMESTAMPTZ,  -- max time in this batch
    _ts_meta_sequence_num INT,   -- ordering within segment
    time _COMPRESSED_DATA,       -- compressed column
    temperature _COMPRESSED_DATA,-- compressed column
    humidity _COMPRESSED_DATA    -- compressed column
)
```

### Compression Algorithms

**Delta-of-delta (timestamps, integers):**
1. Compute deltas between consecutive values: `[100, 101, 102, 103]` -> `[1, 1, 1]`
2. Compute deltas of deltas: `[1, 1, 1]` -> `[0, 0]`
3. For regular intervals (common with time-series), delta-of-delta is nearly all zeros
4. Pack using Simple-8b bit-packing (variable-length encoding of small integers)
5. Compression ratio: often 50:1 or better for regular timestamps

**Gorilla (IEEE 754 floating point):**
1. XOR consecutive float values: if values change slowly, most XOR bits are zero
2. Encode XOR results with leading/trailing zero counts
3. Based on Facebook's Gorilla paper (Pelkonen et al., 2015)
4. Compression ratio: typically 10-20:1 for slowly-changing sensor data

**Dictionary + LZ4 (strings, low-cardinality):**
1. Build a dictionary of unique string values in the batch
2. Replace strings with dictionary indices
3. Apply LZ4 compression on the dictionary and index arrays
4. Compression ratio: depends on cardinality and repetition

**Run-length encoding (NULLs, repeated values):**
1. Encode as (value, count) pairs
2. Particularly effective for sparse columns with many NULLs

### Compression and Decompression Flow

**Compress chunk:**
1. Lock the chunk (exclusive lock during compression)
2. Read all rows from the uncompressed chunk, sorted by (segmentby, orderby)
3. Group rows by segmentby values into segments
4. Within each segment, split into batches of ~1000 rows
5. Compress each column in each batch using the appropriate algorithm
6. Write compressed batches to a new compressed chunk table
7. Drop the original uncompressed chunk table
8. Update catalog metadata

**Decompress chunk:**
1. Read compressed batches from the compressed chunk table
2. Decompress each column
3. Reconstruct rows
4. Write to a new uncompressed chunk table
5. Drop the compressed chunk table
6. Update catalog metadata

**Partial decompression (for INSERT into compressed chunks, 2.11+):**
1. INSERT arrives for a compressed chunk
2. TimescaleDB creates/uses an uncompressed staging area alongside the compressed data
3. New rows are inserted into the staging area
4. On next recompression (policy or manual), staging rows are merged into compressed format
5. Queries transparently merge compressed and staging data

### ColumnarIndexScan (2.25+)

A new execution node that operates directly on compressed column data without full decompression:

- **MIN/MAX/FIRST/LAST fast paths:** Use the `_ts_meta_min/max` metadata to skip entire batches
- **COUNT(*) with time filter:** Can count using metadata alone, skipping data columns entirely
- **Vectorized filtering:** Apply WHERE clause predicates directly on compressed arrays
- Enabled by default starting in TimescaleDB 2.26

## Continuous Aggregate Internals

### Materialization Model

A continuous aggregate consists of:
1. **User-facing view** -- The materialized view name the user queries
2. **Materialization hypertable** -- An internal hypertable storing the materialized results
3. **Partial view** -- The SELECT query definition used for materialization
4. **Invalidation log** -- Tracks which time ranges in the source hypertable have been modified

### Refresh Process

1. **Invalidation tracking:** When INSERT/UPDATE/DELETE modifies the source hypertable, TimescaleDB logs the affected time range in the invalidation log
2. **Refresh policy runs:** The background job checks the invalidation log for the configured window (`start_offset` to `end_offset`)
3. **Selective re-materialization:** Only the invalidated time buckets within the refresh window are recomputed
4. **Merge:** New materialized results replace old results for those time buckets
5. **Invalidation log cleanup:** Processed invalidation entries are removed

**Invalidation log table:**
```sql
_timescaledb_catalog.continuous_aggs_materialization_invalidation_log (
    materialization_id INTEGER,     -- which continuous aggregate
    lowest_modified_value BIGINT,   -- start of invalidated range (internal time format)
    greatest_modified_value BIGINT  -- end of invalidated range
)
```

### Real-Time Aggregation

When `materialized_only = false` (real-time aggregates enabled):
1. Query arrives for the continuous aggregate view
2. For the materialized range: read from the materialization hypertable
3. For the unmaterialized range (data newer than the last refresh): run the aggregate query live against the source hypertable
4. UNION ALL the two result sets
5. Return combined results

**Performance implications:**
- The unmaterialized range query runs on-the-fly, adding latency
- For large unmaterialized windows, this can be slow
- Tune `end_offset` and `schedule_interval` to minimize the unmaterialized window

### Hierarchical Continuous Aggregates

When a continuous aggregate is built on top of another continuous aggregate:
- The outer cagg materializes from the inner cagg's materialization hypertable
- Invalidation propagates: changes to the source hypertable invalidate the inner cagg, which in turn invalidates the outer cagg
- The inner cagg must be refreshed before the outer cagg can re-materialize

## Background Worker System

### Scheduler Architecture

TimescaleDB runs a background worker scheduler per database:

1. **Launcher** (`timescaledb launcher`): Starts when PostgreSQL starts (registered via `shared_preload_libraries`). Spawns one scheduler per database with TimescaleDB installed.
2. **Scheduler** (`timescaledb scheduler`): Maintains a priority queue of jobs sorted by `next_start`. Spawns worker processes to execute jobs.
3. **Workers** (`timescaledb background worker`): Execute individual jobs (compression, retention, cagg refresh, custom actions).

**Worker limits:**
```sql
-- Maximum number of concurrent background workers for TimescaleDB
-- (must be <= max_worker_processes - other_extensions_workers)
SHOW timescaledb.max_background_workers;  -- default: 16
```

### Job Lifecycle

```
Registered --> Scheduled --> Running --> Completed/Failed --> Re-scheduled
                                              |
                                              v
                                     (retry_period if failed,
                                      schedule_interval if succeeded)
```

**Job configuration (`_timescaledb_config.bgw_job`):**
| Column | Purpose |
|---|---|
| `id` | Unique job identifier |
| `application_name` | Human-readable name |
| `schedule_interval` | How often to run |
| `max_runtime` | Maximum execution time before kill |
| `max_retries` | Number of retries on failure |
| `retry_period` | Wait time between retries |
| `proc_schema`, `proc_name` | The function to execute |
| `hypertable_id` | Associated hypertable (if any) |
| `config` | JSONB configuration passed to the function |
| `scheduled` | Whether the job is active |
| `fixed_schedule` | Whether to use fixed or sliding schedule |
| `initial_start` | When the job was first eligible to run |
| `timezone` | Timezone for schedule calculation |

### Built-in Job Types

| proc_name | Purpose | Default Schedule |
|---|---|---|
| `policy_compression` | Compress chunks older than threshold | 12 hours |
| `policy_retention` | Drop chunks older than threshold | 24 hours |
| `policy_refresh_continuous_aggregate` | Refresh continuous aggregate | Varies (user-configured) |
| `policy_reorder` | Reorder chunks by a specified index | 84 hours |
| `policy_recompression` | Recompress chunks with staging data | 12 hours |
| `policy_tiering` | Move chunks to object storage tier | 24 hours |

## Query Planner Integration

### Custom Plan Nodes

TimescaleDB registers custom scan/plan nodes with the PostgreSQL planner:

- **ChunkAppend** -- Replaces Append for hypertable scans. Supports runtime chunk exclusion and ordered append (merge append without sort for time-ordered queries).
- **ConstraintAwareAppend** -- Earlier version of ChunkAppend, used for backward compatibility.
- **CompressedScan** -- Scans compressed chunks, decompressing on-the-fly.
- **ColumnarIndexScan** (2.25+) -- Operates directly on compressed column data.
- **VectorAgg** (2.26+) -- Vectorized aggregation in the columnar pipeline.

### Ordered Append Optimization

When a query has `ORDER BY time` and the planner can determine that chunks are already ordered by time ranges:

```sql
-- This benefits from ordered append (no sort needed)
SELECT * FROM sensor_data
WHERE time > NOW() - INTERVAL '7 days'
ORDER BY time DESC
LIMIT 100;
```

The planner produces a `MergeAppend` or `ChunkAppend` that reads chunks in time order, avoiding a full sort. Combined with `LIMIT`, this can return results after scanning only the most recent chunk.

### Parallel Query

TimescaleDB supports PostgreSQL's parallel query infrastructure:

- Multiple chunks can be scanned in parallel by parallel workers
- `enable_parallel_chunk_append = on` (default) enables this
- Each parallel worker processes one or more chunks independently
- Aggregations across chunks benefit from parallel execution

```sql
-- Enable parallel execution
SET max_parallel_workers_per_gather = 4;

EXPLAIN (ANALYZE) SELECT time_bucket('1 hour', time) AS bucket,
    AVG(temperature)
FROM sensor_data
WHERE time > NOW() - INTERVAL '30 days'
GROUP BY bucket;
-- Look for: Parallel Append, Gather Merge
```

## Data Tiering Architecture (Tiger Cloud)

### Storage Tiers

- **Standard tier:** Local NVMe/SSD storage with full PostgreSQL performance
- **Object storage tier:** S3-compatible object storage (cheaper, higher latency)

### Tiered Chunk Access

When a chunk is tiered to object storage:
1. The chunk's data files are uploaded to S3
2. The local chunk table is replaced with a foreign table pointing to S3
3. Queries transparently read from S3 (higher latency but still SQL-accessible)
4. Indexes on tiered chunks are limited (no local indexes on S3 data)

### Access Pattern

```
Query: SELECT * FROM sensor_data WHERE time > '2024-01-01' AND time < '2025-01-01'

Plan:
├── Scan local chunks (fast, recent data)
└── Scan tiered chunks via S3 (slower, older data)
    └── Chunk exclusion still applies (only matching tiered chunks are read)
```

## Multi-Node Architecture (Deprecated)

**Status:** Multi-node was deprecated in TimescaleDB 2.13 and removed in 2.14 (2023). Only ~1% of deployments used it. The recommended path for horizontal scaling is Tiger Cloud.

**Historical architecture (for migration reference):**
- Access node: Received queries and distributed to data nodes
- Data nodes: Stored chunks of distributed hypertables
- Distributed hypertable: Chunks spread across data nodes by hash partitioning
- Queries were planned on the access node and pushed down to data nodes

**Migration from multi-node:**
1. Set up a single-node TimescaleDB instance with sufficient storage
2. Use `pg_dump` / `pg_restore` or `COPY` to migrate data from each data node
3. Recreate hypertables, continuous aggregates, compression policies on the single node
4. For scale-out needs, use Tiger Cloud which handles horizontal scaling transparently

## WAL and Replication

TimescaleDB uses standard PostgreSQL WAL (Write-Ahead Logging):

- All chunk operations (INSERT, compression, decompression, chunk creation/deletion) generate WAL records
- Streaming replication works identically to standard PostgreSQL
- Logical replication is supported but with caveats:
  - Logical replication publishes from the hypertable name, but internal chunk operations may need special handling
  - TimescaleDB-specific operations (compression, chunk management) are not replicated via logical replication
  - For full TimescaleDB replication, use streaming (physical) replication

### Backup and Restore

```bash
# Full backup (includes all TimescaleDB metadata and chunks)
pg_basebackup -D /backup/path -Ft -z -P

# Logical backup (pg_dump)
pg_dump -Fc -f backup.dump my_database

# Restore
pg_restore -d my_database backup.dump

# After restore, verify TimescaleDB extension
psql -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';"
```

**Important for pg_dump/pg_restore:**
- TimescaleDB catalog tables are included in the dump
- Chunk tables in `_timescaledb_internal` are included
- Compressed chunks are dumped in their compressed form
- On restore, `CREATE EXTENSION timescaledb` must succeed before restoring data
- Use `timescaledb-parallel-copy` for high-performance bulk loading
