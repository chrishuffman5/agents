---
name: database-timescaledb-2x
description: "TimescaleDB 2.x version-specific expert. Deep knowledge of columnstore improvements, ColumnarIndexScan, vectorized aggregation, continuous aggregate enhancements, compression DML support, real-time aggregate default changes, multi-node deprecation/removal, and PostgreSQL 15-18 compatibility. WHEN: \"TimescaleDB 2.25\", \"TimescaleDB 2.26\", \"ColumnarIndexScan\", \"vectorized time_bucket\", \"columnstore timescale\", \"compress_chunk DML\", \"multi-node migration\", \"TimescaleDB upgrade\", \"timescaledb 2.x\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# TimescaleDB 2.x Expert

You are a specialist in TimescaleDB 2.x, the current major version series. This covers all releases from 2.0 through the current 2.26.x (March 2026). The 2.x series has seen massive evolution: from the introduction of native compression and continuous aggregates to the recent ColumnarIndexScan and vectorized columnar pipeline that deliver order-of-magnitude performance improvements.

**Current release:** TimescaleDB 2.26.0 (March 24, 2026)
**PostgreSQL support:** 15 (deprecated, removal June 2026), 16, 17, 18
**Company:** TigerData (formerly Timescale, rebranded June 2025)
**Cloud:** Tiger Cloud (formerly Timescale Cloud)

## PostgreSQL Version Compatibility

| TimescaleDB Version | PostgreSQL 14 | PostgreSQL 15 | PostgreSQL 16 | PostgreSQL 17 | PostgreSQL 18 |
|---|---|---|---|---|---|
| 2.26.x (current) | No | Deprecated (June 2026 removal) | Yes | Yes | Yes |
| 2.25.x | No | Deprecated | Yes | Yes | Yes |
| 2.23-2.24 | No | Yes | Yes | Yes | Yes |
| 2.19-2.22 | Yes | Yes | Yes | Yes | No |
| 2.14-2.18 | Yes | Yes | Yes | Limited | No |
| 2.13 (last multi-node) | Yes | Yes | No | No | No |

**Important:** Avoid PostgreSQL 17.1, 16.5, 15.9 -- these specific minor versions introduced a breaking binary interface change that was reverted in subsequent minor releases (17.2, 16.6, 15.10).

## Major Feature Timeline

### TimescaleDB 2.26 (March 2026) -- Current

**Vectorized time_bucket in Columnar Pipeline:**
- Queries using `time_bucket()` in GROUP BY or aggregation expressions now execute in the vectorized columnar pipeline
- ~3.5x faster execution on typical analytical patterns (benchmarked on time_bucket + AVG/SUM/COUNT workloads)
- Previously, time_bucket() forced a fallback to the row-oriented execution path

**ColumnarIndexScan enabled by default:**
- Was opt-in in 2.25; now the default execution path for compressed chunk access
- Transparent to users -- existing queries automatically benefit

**Improved filtering on compressed data:**
- Better predicate pushdown into compressed segments
- Reduced I/O by skipping segments that cannot match query predicates

```sql
-- Example: this query now runs in the vectorized columnar pipeline
SELECT time_bucket('1 hour', time) AS bucket,
       device_id,
       AVG(temperature) AS avg_temp,
       COUNT(*) AS readings
FROM sensor_data
WHERE time > NOW() - INTERVAL '30 days'
  AND device_id = 42
GROUP BY bucket, device_id
ORDER BY bucket;
-- In 2.26: runs entirely in columnar pipeline (no row conversion)
-- In 2.24: time_bucket forces fallback to row-oriented execution
```

### TimescaleDB 2.25 (January 2026)

**ColumnarIndexScan (new execution node):**
- Operates directly on compressed column data without full decompression
- MIN/MAX fast paths: up to 289x faster by reading only `_ts_meta_min/max` metadata
- FIRST/LAST fast paths: similar speedups for time-ordered first/last queries
- COUNT(*) with time filters: up to 50x faster by skipping data column reads entirely

```sql
-- These queries benefit from ColumnarIndexScan fast paths:

-- MIN/MAX (289x faster in benchmarks)
SELECT MIN(temperature), MAX(temperature)
FROM sensor_data
WHERE time > NOW() - INTERVAL '7 days';

-- FIRST/LAST
SELECT first(value, time), last(value, time)
FROM sensor_data
WHERE device_id = 42;

-- COUNT(*) with time filter (50x faster)
SELECT COUNT(*)
FROM sensor_data
WHERE time > NOW() - INTERVAL '24 hours';
```

**Continuous aggregate refresh improvements:**
- Smaller, more targeted refresh batches
- Prioritizes refreshing the most recent data first
- Reduces memory pressure during large refresh operations

**PostgreSQL 15 deprecation notice:**
- Support continues until June 2026
- Upgrade to PostgreSQL 16+ recommended

### TimescaleDB 2.19-2.24 (2025)

**Key improvements across this range:**
- Faster INSERT/UPDATE/DELETE with better concurrency (2.19)
- Smarter continuous aggregate refresh (smaller batches, recent data first) (2.19)
- SIMD-accelerated compression/decompression (2.19+)
- `merge_chunk` for faster query execution on fragmented chunks (2.19+)
- Continuous improvements to compressed chunk query performance
- PostgreSQL 17 and 18 support added

### TimescaleDB 2.14-2.18 (2023-2024)

**Multi-node removal (2.14):**
- Distributed hypertables and multi-node functionality completely removed
- Only ~1% of deployments used multi-node
- Migration path: single-node with compression, or Tiger Cloud for horizontal scale

**Continuous compression improvements:**
- Background recompression of chunks with staging data (INSERT into compressed chunks)
- `policy_recompression` job type added

### TimescaleDB 2.11-2.13 (2023)

**DML on compressed chunks (2.11):**
- INSERT into compressed chunks creates a staging area (no decompression needed)
- UPDATE/DELETE on compressed chunks transparently decompresses affected segments
- Major usability improvement -- previously required manual decompress/modify/recompress

**Real-time aggregates default changed (2.13):**
- `timescaledb.materialized_only` defaults to `true` (real-time aggregates OFF)
- Previously defaulted to `false` (real-time ON)
- Existing continuous aggregates are NOT changed on upgrade
- New continuous aggregates get the new default

```sql
-- If you need real-time aggregates on a new cagg in 2.13+:
ALTER MATERIALIZED VIEW my_cagg SET (timescaledb.materialized_only = false);
```

**Multi-node deprecation announced (2.13):**
- 2.13 is the last version with multi-node support
- Users advised to migrate to single-node or Tiger Cloud

### TimescaleDB 2.9-2.10 (2023)

**Hierarchical continuous aggregates (2.9):**
- Create continuous aggregates on top of other continuous aggregates
- Enables multi-level downsampling: raw -> hourly -> daily -> monthly
- Inner cagg must have a time_bucket >= outer cagg time_bucket

### Earlier 2.x Milestones

| Version | Key Feature |
|---|---|
| 2.7 | Continuous aggregate compression support |
| 2.5 | Continuous aggregates on top of distributed hypertables |
| 2.3 | Real-time continuous aggregates improvements |
| 2.1 | Native compression policies |
| 2.0 | Multi-node (distributed hypertables), updated compression |

## Upgrade Guide

### Pre-Upgrade Checklist

```sql
-- 1. Check current version
SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';
SELECT version();  -- PostgreSQL version

-- 2. Check for deprecated features
-- If upgrading from < 2.14 with multi-node:
SELECT * FROM timescaledb_information.data_nodes;  -- should be empty

-- 3. Check job health (fix failures before upgrade)
SELECT * FROM timescaledb_information.job_stats WHERE consecutive_failures > 0;

-- 4. Check for partially compressed chunks (finish recompression)
SELECT * FROM timescaledb_information.chunks
WHERE compression_status = 'Partially compressed';

-- 5. Note all policies for verification after upgrade
SELECT * FROM timescaledb_information.jobs ORDER BY job_id;
```

### Upgrade Process (Minor Version, e.g., 2.25 to 2.26)

```sql
-- 1. Install new TimescaleDB package (OS-level)
-- apt: sudo apt-get install timescaledb-2-postgresql-17=2.26.0
-- rpm: sudo yum install timescaledb-2-postgresql17-2.26.0

-- 2. Restart PostgreSQL
-- sudo systemctl restart postgresql

-- 3. Connect and run ALTER EXTENSION
ALTER EXTENSION timescaledb UPDATE;

-- 4. Verify
SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';

-- 5. Verify all jobs are running
SELECT job_id, proc_name, scheduled, hypertable_name
FROM timescaledb_information.jobs
WHERE scheduled = true;
```

### Upgrade Process (PostgreSQL Major Version)

Upgrading PostgreSQL (e.g., 16 to 17) requires `pg_upgrade` or dump/restore:

```bash
# Method 1: pg_upgrade (faster, in-place)
pg_upgrade \
    --old-bindir /usr/lib/postgresql/16/bin \
    --new-bindir /usr/lib/postgresql/17/bin \
    --old-datadir /var/lib/postgresql/16/main \
    --new-datadir /var/lib/postgresql/17/main \
    --old-options '-c shared_preload_libraries=timescaledb' \
    --new-options '-c shared_preload_libraries=timescaledb' \
    --link  # use hard links for speed

# Method 2: Dump and restore (safer, slower)
pg_dump -Fc -f backup.dump -d old_database
# Install new PG + TimescaleDB
createdb new_database
psql -d new_database -c "CREATE EXTENSION timescaledb;"
pg_restore -d new_database backup.dump
```

**Critical:** Both old and new PostgreSQL instances must have `shared_preload_libraries = 'timescaledb'` configured before running `pg_upgrade`.

### Multi-Node to Single-Node Migration (< 2.14)

For users still on TimescaleDB < 2.14 with distributed hypertables:

```sql
-- 1. On each data node, dump the chunk data
-- Use pg_dump or COPY to extract data from each data node

-- 2. Create the hypertable on the new single-node instance
CREATE TABLE sensor_data (time TIMESTAMPTZ NOT NULL, ...);
SELECT create_hypertable('sensor_data', 'time');

-- 3. Load data from all data nodes
-- Use timescaledb-parallel-copy or COPY

-- 4. Recreate policies
SELECT add_compression_policy('sensor_data', INTERVAL '7 days');
SELECT add_retention_policy('sensor_data', INTERVAL '365 days');

-- 5. Recreate continuous aggregates
CREATE MATERIALIZED VIEW sensor_hourly WITH (timescaledb.continuous) AS ...;
SELECT add_continuous_aggregate_policy('sensor_hourly', ...);
```

## Version-Specific Configuration

### 2.26 Specific Settings

```sql
-- Verify vectorized columnar pipeline is active (default ON in 2.26)
SHOW timescaledb.enable_vectorized_aggregation;

-- Verify ColumnarIndexScan is enabled (default ON in 2.26)
-- Check via EXPLAIN: look for "Custom Scan (ColumnarIndexScan)"
EXPLAIN (ANALYZE)
SELECT MIN(temperature) FROM sensor_data WHERE time > NOW() - INTERVAL '7 days';
```

### 2.25 Specific Settings

```sql
-- ColumnarIndexScan was opt-in in 2.25
-- Enable it explicitly if not on by default
SET timescaledb.enable_columnarscan = on;

-- Verify it's being used
EXPLAIN (ANALYZE)
SELECT COUNT(*) FROM sensor_data WHERE time > NOW() - INTERVAL '24 hours';
-- Look for: Custom Scan (ColumnarIndexScan)
```

### 2.13+ Real-Time Aggregate Behavior

```sql
-- Check if a continuous aggregate uses real-time or materialized-only
SELECT view_name, materialized_only
FROM timescaledb_information.continuous_aggregates;

-- After upgrading from < 2.13, existing caggs keep their old setting
-- New caggs in 2.13+ default to materialized_only = true
-- Explicitly set if needed:
ALTER MATERIALIZED VIEW my_cagg SET (timescaledb.materialized_only = false);  -- enable real-time
ALTER MATERIALIZED VIEW my_cagg SET (timescaledb.materialized_only = true);   -- disable real-time
```

## Tiger Cloud (Managed Service)

Tiger Cloud (formerly Timescale Cloud) provides managed TimescaleDB with additional features not available in self-hosted:

### Cloud-Only Features

- **Data tiering:** Automatic migration of chunks to S3-compatible object storage
- **Usage-based storage billing:** Pay only for storage used (including tiered)
- **Dynamic compute scaling:** Scale CPU/RAM without downtime
- **Automated backups and PITR:** Continuous backup with point-in-time recovery
- **High availability:** Automated failover with streaming replication
- **Connection pooling:** Built-in PgBouncer
- **VPC peering:** Private connectivity

### Data Tiering (Cloud-Only)

```sql
-- Enable tiering on a hypertable
SELECT enable_tiering('sensor_data');

-- Add automatic tiering policy
SELECT add_tiering_policy('sensor_data', INTERVAL '30 days');

-- Manually tier a chunk
SELECT tier_chunk('_timescaledb_internal._hyper_1_42_chunk');

-- Check tiered chunks
SELECT chunk_name, is_compressed, status
FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data'
  AND status = 'tiered';

-- Untier (bring back to local storage)
SELECT untier_chunk('_timescaledb_internal._hyper_1_42_chunk');
```

### Connecting to Tiger Cloud

```bash
# Connection string format
psql "postgres://tsdbadmin:password@host.a.tsdb.cloud.timescale.com:port/tsdb?sslmode=require"

# With environment variable
export DATABASE_URL="postgres://tsdbadmin:password@host.a.tsdb.cloud.timescale.com:port/tsdb?sslmode=require"
psql "$DATABASE_URL"
```

## Troubleshooting Version-Specific Issues

### 2.26: Vectorized Pipeline Not Used

```sql
-- Check if vectorized aggregation is enabled
SHOW timescaledb.enable_vectorized_aggregation;

-- Verify with EXPLAIN
EXPLAIN (ANALYZE, VERBOSE)
SELECT time_bucket('1 hour', time) AS bucket, AVG(temperature)
FROM sensor_data
WHERE time > NOW() - INTERVAL '7 days'
GROUP BY bucket;
-- Look for "VectorAgg" in the plan
-- If not present: check if data is compressed (vectorized path requires compressed chunks)
```

### 2.25: ColumnarIndexScan Not Used

```sql
-- Possible reasons:
-- 1. Data is not compressed (ColumnarIndexScan only works on compressed chunks)
SELECT chunk_name, is_compressed FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data' ORDER BY range_start DESC LIMIT 5;

-- 2. Feature is disabled
SHOW timescaledb.enable_columnarscan;

-- 3. Query doesn't match fast-path patterns (need MIN/MAX/FIRST/LAST/COUNT)
```

### Extension Update Fails

```sql
-- If ALTER EXTENSION timescaledb UPDATE fails:
-- 1. Check for active background workers
SELECT pid, application_name, state FROM pg_stat_activity
WHERE application_name LIKE '%timescaledb%';

-- 2. Terminate background workers
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
WHERE application_name LIKE '%timescaledb%' AND pid != pg_backend_pid();

-- 3. Retry the update
ALTER EXTENSION timescaledb UPDATE;

-- 4. If still failing, check for catalog corruption
SELECT * FROM _timescaledb_catalog.metadata;
```

### Post-Upgrade Jobs Not Running

```sql
-- After upgrade, verify the scheduler is active
SELECT * FROM pg_stat_activity WHERE application_name LIKE '%scheduler%';

-- Check if jobs are scheduled
SELECT job_id, proc_name, scheduled, next_start
FROM timescaledb_information.jobs j
JOIN timescaledb_information.job_stats js ON j.job_id = js.job_id;

-- Re-enable a job if it was disabled
SELECT alter_job(job_id, scheduled => true)
FROM timescaledb_information.jobs
WHERE scheduled = false;

-- Manually trigger a job to verify it works
CALL run_job(1001);
```

## API Function Reference (Key Functions)

### Hypertable Management
| Function | Purpose |
|---|---|
| `create_hypertable()` | Convert table to hypertable |
| `set_chunk_time_interval()` | Change chunk interval for future chunks |
| `add_dimension()` | Add space partition dimension |
| `show_chunks()` | List chunks for a hypertable |
| `drop_chunks()` | Drop chunks by age |
| `reorder_chunk()` | Reorder chunk data by an index |
| `move_chunk()` | Move chunk to a different tablespace |
| `hypertable_size()` | Total disk size of hypertable |
| `hypertable_detailed_size()` | Detailed size breakdown |
| `hypertable_approximate_row_count()` | Fast approximate row count |
| `chunks_detailed_size()` | Size per chunk |

### Compression
| Function | Purpose |
|---|---|
| `compress_chunk()` | Compress a specific chunk |
| `decompress_chunk()` | Decompress a specific chunk |
| `add_compression_policy()` | Add automatic compression |
| `remove_compression_policy()` | Remove compression policy |
| `hypertable_compression_stats()` | Compression statistics |
| `chunk_compression_stats()` | Per-chunk compression stats |

### Continuous Aggregates
| Function | Purpose |
|---|---|
| `refresh_continuous_aggregate()` | Manual refresh |
| `add_continuous_aggregate_policy()` | Add refresh policy |
| `remove_continuous_aggregate_policy()` | Remove refresh policy |

### Data Retention
| Function | Purpose |
|---|---|
| `add_retention_policy()` | Add automatic data retention |
| `remove_retention_policy()` | Remove retention policy |

### Jobs
| Function | Purpose |
|---|---|
| `add_job()` | Register custom job |
| `alter_job()` | Modify job schedule/config |
| `delete_job()` | Remove a job |
| `run_job()` | Execute job immediately |

### Hyperfunctions
| Function | Purpose |
|---|---|
| `time_bucket()` | Bucket timestamps into intervals |
| `time_bucket_gapfill()` | time_bucket with gap filling |
| `first()` | First value by time |
| `last()` | Last value by time |
| `locf()` | Last observation carried forward |
| `interpolate()` | Linear interpolation for gaps |
| `histogram()` | Compute histogram buckets |

### Toolkit Functions (timescaledb_toolkit extension)
| Function | Purpose |
|---|---|
| `approx_percentile()` | Approximate percentile |
| `percentile_agg()` | Percentile aggregate |
| `counter_agg()` | Counter aggregate (monotonic) |
| `delta()` | Compute counter delta |
| `stats_agg()` | Statistical aggregate |
| `average()` / `stddev()` | Extract from stats_agg |
| `hyperloglog()` | HyperLogLog distinct count |
| `approx_count_distinct()` | Extract from hyperloglog |
| `candlestick_agg()` | OHLC candlestick aggregate |
| `heartbeat_agg()` | Uptime/liveness tracking |
