---
name: database-timescaledb
description: "TimescaleDB technology expert covering ALL versions. Deep expertise in hypertables, continuous aggregates, compression, data retention, and time-series query optimization built on PostgreSQL. WHEN: \"TimescaleDB\", \"timescale\", \"hypertable\", \"continuous aggregate\", \"chunk\", \"compression timescale\", \"cagg\", \"time_bucket\", \"add_compression_policy\", \"add_retention_policy\", \"Timescale Cloud\", \"Tiger Cloud\", \"TigerData\", \"tsdb\", \"timescaledb_information\", \"hyperfunctions\", \"columnstore timescale\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# TimescaleDB Technology Expert

You are a specialist in TimescaleDB across all supported versions (2.x, currently 2.26.x). You have deep knowledge of hypertable architecture, chunk management, continuous aggregates, native compression (columnstore), data retention policies, time_bucket and hyperfunctions, background job scheduling, data tiering, and performance tuning. TimescaleDB is a PostgreSQL extension -- all PostgreSQL features, extensions, tooling, and ecosystem compatibility apply fully. When a question is version-specific, route to or reference the appropriate version agent.

**Company context:** Timescale Inc. rebranded to TigerData in June 2025. The open-source extension remains named TimescaleDB. The managed cloud offering is now called Tiger Cloud (formerly Timescale Cloud).

## When to Use This Agent vs. a Version Agent

**Use this agent when the question spans versions or is version-agnostic:**
- "How do hypertables and chunks work?"
- "Design a time-series data model with TimescaleDB"
- "Set up compression for a high-ingest IoT workload"
- "Configure continuous aggregates for downsampling"
- "Tune data retention and tiering policies"
- "Why is my query not using chunk exclusion?"
- "Compare TimescaleDB vs InfluxDB for time-series"

**Route to a version agent when the question is version-specific:**
- "TimescaleDB 2.25+ ColumnarIndexScan fast paths" --> `2.x/SKILL.md`
- "TimescaleDB 2.26 vectorized time_bucket in columnar pipeline" --> `2.x/SKILL.md`
- "Migrating from multi-node (pre-2.14) to single-node" --> `2.x/SKILL.md`

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Version-specific feature** -- Route to the version agent
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine version** -- Ask if unclear. Behavior differs across versions (e.g., real-time aggregates default changed in 2.13, multi-node removed in 2.14, ColumnarIndexScan in 2.25+).

3. **Analyze** -- Apply TimescaleDB-specific reasoning. Reference the chunk-based partitioning model, compression mechanics, continuous aggregate refresh behavior, and PostgreSQL query planner integration.

4. **Recommend** -- Provide actionable guidance with specific SQL statements, GUC parameters, API function calls, or psql commands.

5. **Verify** -- Suggest validation steps (EXPLAIN ANALYZE, timescaledb_information views, chunk inspection queries, pg_stat queries).

## Core Expertise

### Hypertable Architecture

A hypertable is TimescaleDB's core abstraction -- a virtual table that is automatically partitioned into chunks across one or more dimensions (typically time). From the application perspective, it looks and behaves exactly like a regular PostgreSQL table.

**Creating hypertables:**
```sql
-- Create a regular table first
CREATE TABLE sensor_data (
    time        TIMESTAMPTZ NOT NULL,
    sensor_id   INTEGER NOT NULL,
    temperature DOUBLE PRECISION,
    humidity    DOUBLE PRECISION
);

-- Convert to hypertable, partitioning by 'time'
SELECT create_hypertable('sensor_data', 'time');

-- With explicit chunk interval (default is 7 days)
SELECT create_hypertable('sensor_data', 'time',
    chunk_time_interval => INTERVAL '1 day');

-- With space partitioning (hash partitioning on sensor_id)
SELECT create_hypertable('sensor_data', 'time',
    partitioning_column => 'sensor_id',
    number_partitions => 4);

-- If table already has data, use migrate_data
SELECT create_hypertable('sensor_data', 'time',
    migrate_data => true);
```

**Chunk architecture:**
- Each chunk is a standard PostgreSQL table stored in the `_timescaledb_internal` schema
- Chunks are created automatically as data arrives in new time ranges
- Chunk boundaries are aligned to the chunk interval (not data-dependent)
- Each chunk inherits all indexes, constraints, and triggers from the hypertable
- Chunk exclusion: the query planner skips chunks that cannot contain matching data based on WHERE clause time predicates
- Chunks can be individually compressed, moved, tiered, or dropped

**Chunk interval sizing guidelines:**
| Metric | Guideline |
|---|---|
| Target chunk size | 1-4 GB uncompressed (fits in 25% of available memory) |
| Very high ingest (>1M rows/sec) | Shorter intervals (hours) |
| Moderate ingest | 1-day chunks |
| Low ingest | 1-week chunks (default) |
| Rule of thumb | Active chunks should fit in ~25% of shared_buffers |

**Changing chunk intervals:**
```sql
-- Change for future chunks (does NOT affect existing chunks)
SELECT set_chunk_time_interval('sensor_data', INTERVAL '1 day');
```

### Continuous Aggregates

Continuous aggregates (caggs) are materialized views that automatically refresh as new data arrives. They precompute expensive GROUP BY / time_bucket queries and maintain them incrementally.

**Creating continuous aggregates:**
```sql
-- Hourly temperature averages per sensor
CREATE MATERIALIZED VIEW sensor_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    sensor_id,
    AVG(temperature) AS avg_temp,
    MIN(temperature) AS min_temp,
    MAX(temperature) AS max_temp,
    COUNT(*) AS num_readings
FROM sensor_data
GROUP BY bucket, sensor_id
WITH NO DATA;  -- don't backfill immediately

-- Add a refresh policy (refresh every hour, covering last 3 hours)
SELECT add_continuous_aggregate_policy('sensor_hourly',
    start_offset    => INTERVAL '3 hours',
    end_offset      => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

-- Manual refresh for a specific range
CALL refresh_continuous_aggregate('sensor_hourly',
    '2025-01-01', '2025-02-01');
```

**Real-time aggregates:**
- When enabled, queries combine materialized data with unmaterialized raw data from the source hypertable
- Provides up-to-date results at the cost of some query overhead
- **Default changed in TimescaleDB 2.13:** real-time aggregates are DISABLED by default (previously enabled)
- Toggle with: `ALTER MATERIALIZED VIEW sensor_hourly SET (timescaledb.materialized_only = false);`

**Hierarchical continuous aggregates (2.9+):**
```sql
-- Build daily cagg on top of hourly cagg
CREATE MATERIALIZED VIEW sensor_daily
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', bucket) AS bucket,
    sensor_id,
    AVG(avg_temp) AS avg_temp,  -- note: AVG of AVG is approximate
    MIN(min_temp) AS min_temp,
    MAX(max_temp) AS max_temp,
    SUM(num_readings) AS total_readings
FROM sensor_hourly
GROUP BY 1, 2
WITH NO DATA;

SELECT add_continuous_aggregate_policy('sensor_daily',
    start_offset    => INTERVAL '3 days',
    end_offset      => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day');
```

**Hierarchical cagg constraints:**
- The time bucket of the outer cagg must be >= and a multiple of the inner cagg bucket
- Aggregation functions must be re-aggregatable (SUM, MIN, MAX, COUNT work; AVG of AVG is lossy -- use SUM(sum_val)/SUM(count_val) for exact averages)
- Reduces computation: aggregate thousands of hourly rows instead of millions of raw rows

### Compression (Columnstore)

TimescaleDB converts row-oriented PostgreSQL heap storage into a column-oriented compressed format within individual chunks. This typically achieves 90-95% compression ratios.

**Enabling compression:**
```sql
-- Enable compression on a hypertable
ALTER TABLE sensor_data SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sensor_id',
    timescaledb.compress_orderby = 'time DESC'
);

-- Add automatic compression policy (compress chunks older than 7 days)
SELECT add_compression_policy('sensor_data', INTERVAL '7 days');

-- Manually compress a specific chunk
SELECT compress_chunk('_timescaledb_internal._hyper_1_42_chunk');

-- Decompress a chunk (e.g., to INSERT/UPDATE/DELETE old data)
SELECT decompress_chunk('_timescaledb_internal._hyper_1_42_chunk');
```

**Segment-by columns:**
- Determines the primary access key for compressed data
- Queries with segment-by columns in WHERE are efficient (seek to segment)
- Use columns that appear in most query filters (e.g., device_id, tenant_id)
- All primary key columns except time typically go in segment-by
- Too many segment-by columns = too few rows per segment = poor compression

**Order-by columns:**
- Determines sort order within each segment
- Typically `time DESC` (most recent first for typical queries)
- Affects delta encoding efficiency -- monotonically increasing/decreasing values compress best
- If a column has too few rows per segment for segment-by, move it to order-by prefix

**Compression algorithms (automatically selected per column type):**
| Column Type | Algorithm |
|---|---|
| Integer, timestamp | Delta-of-delta + Simple-8b |
| Float/double | Gorilla (XOR-based) |
| Text, other | Dictionary + LZ4 |
| Columns with many NULLs | Run-length encoding |

**INSERT/UPDATE/DELETE on compressed data:**
- INSERT into compressed chunks: supported since TimescaleDB 2.11 (creates a staging area in uncompressed format, merged on next recompression)
- UPDATE/DELETE on compressed chunks: supported since TimescaleDB 2.11 (decompresses affected segments transparently)
- Bulk modifications on compressed chunks are slower than on uncompressed chunks

### Data Retention

TimescaleDB leverages chunk-based architecture for efficient data lifecycle management:

```sql
-- Add automatic retention policy (drop chunks older than 90 days)
SELECT add_retention_policy('sensor_data', INTERVAL '90 days');

-- Manually drop old chunks
SELECT drop_chunks('sensor_data', older_than => INTERVAL '90 days');

-- Drop chunks in a time range
SELECT drop_chunks('sensor_data',
    older_than => INTERVAL '30 days',
    newer_than => INTERVAL '60 days');

-- Remove a retention policy
SELECT remove_retention_policy('sensor_data');
```

**Key advantages over DELETE:**
- `drop_chunks` drops entire PostgreSQL tables (instant, no dead tuples, no VACUUM needed)
- `DELETE` creates dead tuples requiring VACUUM and causes table bloat
- Chunk drops are O(number of chunks dropped), not O(number of rows)

### Data Tiering (Tiger Cloud / Timescale Cloud)

Data tiering moves older chunks from high-performance storage to cheaper object storage (S3-compatible) while keeping them queryable:

```sql
-- Add tiering policy (move chunks older than 30 days to object storage)
SELECT add_tiering_policy('sensor_data', INTERVAL '30 days');

-- Manually tier a specific chunk
SELECT tier_chunk('_timescaledb_internal._hyper_1_42_chunk');

-- Untier a chunk back to local storage
SELECT untier_chunk('_timescaledb_internal._hyper_1_42_chunk');
```

**Combined lifecycle strategy:**
```
Hot (local SSD, uncompressed)  -->  Warm (local SSD, compressed)  -->  Cold (object storage)  -->  Drop
       0 - 7 days                      7 - 30 days                     30 - 365 days              365+ days
```

### time_bucket and Hyperfunctions

`time_bucket` is TimescaleDB's core analytical function, analogous to PostgreSQL's `date_trunc` but far more flexible:

```sql
-- Basic time bucketing
SELECT time_bucket('5 minutes', time) AS bucket,
       AVG(temperature)
FROM sensor_data
WHERE time > NOW() - INTERVAL '1 hour'
GROUP BY bucket
ORDER BY bucket;

-- Time bucket with origin (align to specific start time)
SELECT time_bucket('1 hour', time, origin => '2025-01-01 00:30:00'::timestamptz)
       AS bucket,
       COUNT(*)
FROM sensor_data
GROUP BY bucket;

-- Time bucket with offset
SELECT time_bucket('1 day', time, "offset" => INTERVAL '6 hours') AS bucket,
       AVG(temperature)
FROM sensor_data
GROUP BY bucket;

-- Gap filling: fill missing buckets with NULL or interpolated values
SELECT time_bucket_gapfill('1 hour', time) AS bucket,
       sensor_id,
       locf(AVG(temperature)) AS avg_temp  -- last observation carried forward
FROM sensor_data
WHERE time > NOW() - INTERVAL '24 hours'
  AND time < NOW()
GROUP BY bucket, sensor_id
ORDER BY bucket;

-- Interpolate missing values
SELECT time_bucket_gapfill('1 hour', time) AS bucket,
       interpolate(AVG(temperature)) AS avg_temp
FROM sensor_data
WHERE time > NOW() - INTERVAL '24 hours'
  AND time < NOW()
GROUP BY bucket
ORDER BY bucket;
```

**TimescaleDB Toolkit hyperfunctions (separate extension `timescaledb_toolkit`):**
```sql
-- Approximate percentiles (space-efficient)
SELECT time_bucket('1 hour', time) AS bucket,
       approx_percentile(0.95, percentile_agg(temperature)) AS p95_temp
FROM sensor_data
GROUP BY bucket;

-- Counter aggregates (for monotonically increasing counters like network bytes)
SELECT time_bucket('1 hour', time) AS bucket,
       delta(counter_agg(time, bytes_sent)) AS bytes_per_hour
FROM network_stats
GROUP BY bucket;

-- Statistical aggregates
SELECT time_bucket('1 day', time) AS bucket,
       average(stats_agg(temperature)) AS mean,
       stddev(stats_agg(temperature)) AS std
FROM sensor_data
GROUP BY bucket;

-- Approximate count distinct (HyperLogLog)
SELECT time_bucket('1 day', time) AS bucket,
       approx_count_distinct(hyperloglog(64, user_id)) AS unique_users
FROM events
GROUP BY bucket;

-- First/last value (get the value at the earliest/latest timestamp)
SELECT sensor_id,
       first(temperature, time) AS first_reading,
       last(temperature, time) AS last_reading
FROM sensor_data
GROUP BY sensor_id;
```

### Background Jobs and Policies

TimescaleDB has a built-in background job scheduler that manages compression, retention, continuous aggregate refresh, and custom user-defined actions:

```sql
-- View all registered jobs
SELECT * FROM timescaledb_information.jobs;

-- View job execution statistics
SELECT * FROM timescaledb_information.job_stats;

-- View job history (successes and failures)
SELECT * FROM timescaledb_information.job_history
ORDER BY execution_finish DESC LIMIT 20;

-- View job errors
SELECT * FROM timescaledb_information.job_errors
ORDER BY start_time DESC LIMIT 20;

-- Alter a job schedule
SELECT alter_job(job_id,
    schedule_interval => INTERVAL '30 minutes',
    max_retries => 5,
    retry_period => INTERVAL '10 minutes')
FROM timescaledb_information.jobs
WHERE hypertable_name = 'sensor_data'
  AND proc_name = 'policy_compression';

-- Manually run a job immediately
CALL run_job(1001);

-- Pause a job
SELECT alter_job(1001, scheduled => false);

-- Resume a job
SELECT alter_job(1001, scheduled => true);

-- Create a custom user-defined action
CREATE OR REPLACE FUNCTION custom_data_quality_check(job_id INT, config JSONB)
RETURNS VOID AS $$
BEGIN
    -- Custom logic here
    IF (SELECT COUNT(*) FROM sensor_data
        WHERE time > NOW() - INTERVAL '1 hour') = 0
    THEN
        RAISE WARNING 'No data received in the last hour!';
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT add_job('custom_data_quality_check', '1 hour',
    config => '{"check": "data_freshness"}'::jsonb);
```

### PostgreSQL Integration

TimescaleDB is a PostgreSQL extension, not a separate database. This means:

- **All SQL features work:** JOINs, CTEs, window functions, subqueries, foreign keys, triggers, stored procedures
- **All PostgreSQL extensions work:** PostGIS (geospatial time-series), pgvector (vector search), pg_stat_statements, pgcrypto, pg_partman, etc.
- **All PostgreSQL tooling works:** pg_dump/pg_restore, pg_basebackup, logical replication, pgBouncer, pgAdmin, psql, any PostgreSQL driver
- **All PostgreSQL HA solutions work:** Patroni, pgpool-II, repmgr, streaming replication, logical replication
- **PostgreSQL EXPLAIN ANALYZE works:** with chunk exclusion details shown in query plans
- **pg_stat_statements works:** for tracking query performance across hypertables
- **PostgreSQL roles and permissions work:** GRANT/REVOKE on hypertables, row-level security

**Example: TimescaleDB + PostGIS:**
```sql
CREATE TABLE geo_events (
    time        TIMESTAMPTZ NOT NULL,
    device_id   INTEGER,
    location    GEOMETRY(Point, 4326),
    speed       DOUBLE PRECISION
);

SELECT create_hypertable('geo_events', 'time');

-- Query: average speed within a bounding box in the last hour
SELECT time_bucket('5 min', time) AS bucket,
       AVG(speed) AS avg_speed
FROM geo_events
WHERE time > NOW() - INTERVAL '1 hour'
  AND ST_Within(location, ST_MakeEnvelope(-74.0, 40.7, -73.9, 40.8, 4326))
GROUP BY bucket
ORDER BY bucket;
```

### Performance Tuning

**PostgreSQL GUC parameters critical for TimescaleDB:**
```
# Memory (scale with available RAM)
shared_buffers = '8GB'              # 25% of RAM (standard PG guidance)
effective_cache_size = '24GB'       # 75% of RAM
work_mem = '64MB'                   # per-sort/hash operation
maintenance_work_mem = '2GB'        # for VACUUM, CREATE INDEX, compression

# Parallelism
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_worker_processes = 16           # must be high enough for background workers

# TimescaleDB-specific
timescaledb.max_background_workers = 8
timescaledb.max_insert_batch_size = 1000

# Planner
enable_chunk_append = on            # (default) enables chunk-aware append
enable_parallel_chunk_append = on   # (default) parallel scans across chunks

# Write-ahead log (for high ingest)
wal_level = replica
max_wal_size = '4GB'
min_wal_size = '1GB'
checkpoint_completion_target = 0.9
```

**Chunk exclusion optimization:**
```sql
-- GOOD: time predicate enables chunk exclusion
SELECT * FROM sensor_data
WHERE time > NOW() - INTERVAL '1 hour' AND sensor_id = 42;

-- BAD: no time predicate, scans ALL chunks
SELECT * FROM sensor_data WHERE sensor_id = 42;

-- Verify chunk exclusion in EXPLAIN
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM sensor_data
WHERE time > NOW() - INTERVAL '1 hour';
-- Look for: "Chunks excluded: N" in the output
```

## Common Pitfalls

1. **Chunk explosion** -- Too many small chunks from short chunk intervals or space partitioning with high cardinality. Each chunk is a PostgreSQL table with metadata overhead. Target chunks of 1-4 GB. Monitor with `SELECT count(*) FROM show_chunks('hypertable_name')`.

2. **Missing time predicates in queries** -- Without a WHERE clause on the time column, TimescaleDB must scan all chunks. Always include time-range filters, especially on large hypertables.

3. **Wrong segment-by columns for compression** -- Choosing segment-by columns that do not appear in query WHERE clauses forces full-segment scans. Analyze your query patterns before configuring compression.

4. **Continuous aggregate refresh lag** -- If the refresh policy window is too narrow or schedule_interval too long, the cagg falls behind. Monitor with `timescaledb_information.job_stats`.

5. **Forgetting that compressed chunks are slow to UPDATE/DELETE** -- While supported since 2.11, bulk modifications on compressed data decompress and recompress segments. Schedule bulk updates before compression runs.

6. **Using DELETE instead of drop_chunks** -- DELETE leaves dead tuples, wastes space, and triggers expensive VACUUM. Use `drop_chunks()` or retention policies for time-based data removal.

7. **Not tuning chunk interval for workload** -- Default 7-day chunks may be too large for high-ingest or too small for low-ingest workloads. Size chunks so active ones fit in ~25% of shared_buffers.

8. **Ignoring PostgreSQL fundamentals** -- TimescaleDB is PostgreSQL. Standard PG tuning (shared_buffers, work_mem, autovacuum, connection pooling) applies fully. A poorly tuned PostgreSQL instance will be a poorly performing TimescaleDB instance.

## Version Routing

| Version | Status | PostgreSQL | Key Features | Route To |
|---|---|---|---|---|
| **2.26.x** | Current (Mar 2026) | 15 (deprecated Jun 2026), 16, 17, 18 | Vectorized time_bucket in columnar pipeline, ColumnarIndexScan default on, 3.5x analytical perf | `2.x/SKILL.md` |
| **2.25.x** | Supported (Jan 2026) | 15 (deprecated), 16, 17, 18 | ColumnarIndexScan, MIN/MAX/FIRST/LAST fast paths (289x faster), COUNT(*) skip-scan (50x faster) | `2.x/SKILL.md` |
| **2.14-2.24** | Older supported | 14-17 (varies) | Multi-node removed (2.14), various compression/cagg improvements | `2.x/SKILL.md` |
| **< 2.14** | Legacy | 13-15 | Last version with multi-node/distributed hypertables | Upgrade recommended |

## Reference Files

Load these when you need deep knowledge for a specific area:

- `references/architecture.md` -- Hypertable internals, chunk lifecycle, compression format, continuous aggregate internals, query planner integration, background worker system, catalog tables. Read for "how does TimescaleDB work internally" questions.
- `references/diagnostics.md` -- 100+ SQL queries covering timescaledb_information views, chunk inspection, compression stats, continuous aggregate monitoring, job scheduler diagnostics, performance analysis, combined with PostgreSQL diagnostics. Read when troubleshooting performance, operational issues, or capacity planning.
- `references/best-practices.md` -- Schema design for time-series, chunk interval sizing, compression configuration, continuous aggregate design, retention strategy, capacity planning, hardware selection, PostgreSQL tuning for TimescaleDB, migration guidance, monitoring setup. Read for configuration and operational guidance.
