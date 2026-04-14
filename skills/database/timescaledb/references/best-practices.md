# TimescaleDB Best Practices Reference

## Schema Design for Time-Series

### Table Design Principles

TimescaleDB is PostgreSQL -- you get full relational modeling plus time-series optimizations. The key design decisions are:

1. **Time column:** Every hypertable must have a time column. Use `TIMESTAMPTZ` (with timezone) for most use cases. Use `BIGINT` epoch for high-performance integer-based partitioning.

2. **Identifier columns:** Columns that identify the entity generating data (device_id, sensor_id, user_id). These become segment-by columns for compression and are essential for query filtering.

3. **Metric columns:** The actual measurements (temperature, cpu_usage, price). These compress extremely well with Gorilla/delta encoding.

4. **Metadata columns:** Rarely-changing attributes (location, firmware_version). Consider storing in a separate dimension table and JOINing.

### Schema Patterns

**Pattern 1: Wide table (one row per timestamp per entity)**
```sql
CREATE TABLE metrics (
    time        TIMESTAMPTZ NOT NULL,
    device_id   INTEGER NOT NULL,
    cpu_usage   DOUBLE PRECISION,
    memory_usage DOUBLE PRECISION,
    disk_io     DOUBLE PRECISION,
    network_in  BIGINT,
    network_out BIGINT
);
SELECT create_hypertable('metrics', 'time');
```
- Best for: Fixed set of metrics per entity, analytical queries that access multiple metrics
- Compression: Excellent (all columns compressed per segment)
- Query: `SELECT time, cpu_usage, memory_usage FROM metrics WHERE device_id = 1 AND time > NOW() - '1h'`

**Pattern 2: Narrow table (one row per metric per timestamp)**
```sql
CREATE TABLE metrics_narrow (
    time        TIMESTAMPTZ NOT NULL,
    device_id   INTEGER NOT NULL,
    metric_name TEXT NOT NULL,
    value       DOUBLE PRECISION NOT NULL
);
SELECT create_hypertable('metrics_narrow', 'time');
```
- Best for: Variable/dynamic set of metrics, schema flexibility
- Compression: Good but more rows to store
- Query: `SELECT time, value FROM metrics_narrow WHERE device_id = 1 AND metric_name = 'cpu' AND time > NOW() - '1h'`
- **Recommendation:** Prefer wide tables when the set of metrics is known and stable. Narrow tables add flexibility but increase storage and query complexity.

**Pattern 3: JSONB for flexible metadata**
```sql
CREATE TABLE events (
    time        TIMESTAMPTZ NOT NULL,
    source_id   INTEGER NOT NULL,
    event_type  TEXT NOT NULL,
    payload     JSONB NOT NULL
);
SELECT create_hypertable('events', 'time');
CREATE INDEX ON events USING GIN (payload jsonb_path_ops);
```
- Best for: Semi-structured event data with variable schemas
- Trade-off: JSONB is slower to query and compress than typed columns

**Pattern 4: Dimension table pattern (normalized metadata)**
```sql
-- Dimension table (regular PostgreSQL table, NOT a hypertable)
CREATE TABLE devices (
    device_id   INTEGER PRIMARY KEY,
    name        TEXT,
    location    TEXT,
    model       TEXT,
    deployed_at TIMESTAMPTZ
);

-- Fact table (hypertable)
CREATE TABLE readings (
    time        TIMESTAMPTZ NOT NULL,
    device_id   INTEGER NOT NULL REFERENCES devices(device_id),
    temperature DOUBLE PRECISION,
    humidity    DOUBLE PRECISION
);
SELECT create_hypertable('readings', 'time');

-- Query with JOIN
SELECT r.time, d.name, d.location, r.temperature
FROM readings r
JOIN devices d ON r.device_id = d.device_id
WHERE r.time > NOW() - INTERVAL '1 hour'
  AND d.location = 'Building A';
```
- Best for: Avoid duplicating metadata in every row, metadata changes independently
- Foreign keys work across hypertables and regular tables

### Index Strategy

**Essential indexes:**
```sql
-- TimescaleDB automatically creates: (time DESC) on each chunk
-- Add composite indexes for common query patterns:

-- For queries filtering by device_id within time ranges
CREATE INDEX ON readings (device_id, time DESC);

-- For queries filtering by multiple identifiers
CREATE INDEX ON readings (device_id, sensor_type, time DESC);

-- For text search on event types
CREATE INDEX ON events (event_type, time DESC);
```

**Index sizing guideline:**
- Each index is created per-chunk, so total index overhead = index_size_per_chunk * num_chunks
- More indexes = higher INSERT cost (indexes updated on every INSERT)
- On compressed chunks, indexes are dropped (compressed data is accessed via segment-by + order-by)
- For write-heavy workloads, minimize indexes to 2-3 per hypertable

### Unique Constraints

```sql
-- Unique constraints MUST include the time partitioning column
-- This is a fundamental requirement of partitioned tables in PostgreSQL

-- Works:
ALTER TABLE readings ADD CONSTRAINT readings_unique
    UNIQUE (device_id, time);

-- Does NOT work:
ALTER TABLE readings ADD CONSTRAINT readings_unique
    UNIQUE (device_id);
-- ERROR: insufficient columns in UNIQUE constraint definition
```

## Chunk Interval Sizing

### Sizing Methodology

The chunk interval determines how large each chunk grows before a new one is created. The goal is chunks sized at 1-4 GB uncompressed (fitting in ~25% of shared_buffers).

**Formula:**
```
chunk_interval = target_chunk_size / ingest_rate_per_second / 86400

Example:
- Target: 2 GB per chunk
- Row size: 100 bytes
- Ingest rate: 10,000 rows/second
- Daily data: 10,000 * 86,400 * 100 bytes = ~82 GB/day
- chunk_interval = 2 GB / 82 GB/day = ~0.58 hours -> use 1 hour
```

**Quick reference:**

| Daily Ingest | Row Size | Recommended Interval |
|---|---|---|
| < 1 GB/day | Any | 7 days (default) |
| 1-10 GB/day | Any | 1-3 days |
| 10-100 GB/day | Any | 4-12 hours |
| 100+ GB/day | Any | 1-4 hours |
| > 1 TB/day | Any | 15-60 minutes |

### Changing Chunk Intervals

```sql
-- Change for FUTURE chunks only (existing chunks are not affected)
SELECT set_chunk_time_interval('readings', INTERVAL '1 day');

-- Verify the change
SELECT * FROM timescaledb_information.dimensions
WHERE hypertable_name = 'readings';
```

### Space Partitioning Guidance

**When to use space partitioning:**
- Very high ingest rates where a single chunk becomes a write bottleneck
- Queries that consistently filter on the space dimension column
- Need for parallel query execution across space partitions

**When NOT to use:**
- Most workloads (time partitioning alone is sufficient)
- Low to moderate ingest rates
- When it would cause chunk explosion (N space partitions * M time intervals = N*M chunks)

```sql
-- Only use if you have a clear need
SELECT create_hypertable('high_volume_metrics', 'time',
    partitioning_column => 'region_id',
    number_partitions => 4,
    chunk_time_interval => INTERVAL '4 hours');
```

## Compression Configuration

### Segment-By Selection

**Rule: Choose segment-by columns that appear in your most common WHERE clauses.**

```sql
-- If most queries filter by device_id:
ALTER TABLE readings SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);

-- If queries filter by device_id AND region:
ALTER TABLE readings SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id, region',
    timescaledb.compress_orderby = 'time DESC'
);
```

**Segment-by sizing rule:**
- Each segment should contain at least 100 rows per chunk
- If `device_count * region_count > rows_per_chunk / 100`, you have too many segment-by columns
- Too many segments = poor compression (not enough values to exploit patterns)
- If a column creates too many segments, move it to the ORDER BY prefix instead

**Decision matrix:**
| Scenario | segment-by | order-by |
|---|---|---|
| 100 devices, 1M rows/chunk | `device_id` | `time DESC` |
| 100 devices, 10 regions, 1M rows/chunk | `device_id` | `region, time DESC` |
| 100K devices, 1M rows/chunk | (none) | `device_id, time DESC` |
| 100 devices, 50 metrics (narrow table) | `device_id` | `metric_name, time DESC` |

### Compression Policy Timing

```sql
-- Compress chunks older than the write window
-- Common patterns:
SELECT add_compression_policy('readings', INTERVAL '2 hours');   -- high ingest, short retention
SELECT add_compression_policy('readings', INTERVAL '1 day');     -- standard
SELECT add_compression_policy('readings', INTERVAL '7 days');    -- when recent data is frequently updated
SELECT add_compression_policy('readings', INTERVAL '30 days');   -- conservative, lots of late-arriving data
```

**Timing considerations:**
- Compress after the "write window" closes (no more INSERTs/UPDATEs expected)
- Compression locks the chunk during the operation (brief, but blocks writes to that chunk)
- If you INSERT into compressed chunks (2.11+), data goes to a staging area and recompression is needed later
- Policy runs every 12 hours by default; adjust with `alter_job`

### Verifying Compression Ratios

```sql
-- After enabling compression, check ratios
SELECT * FROM hypertable_compression_stats('readings');

-- Per-chunk compression ratios
SELECT chunk_name,
       pg_size_pretty(before_compression_total_bytes) AS before,
       pg_size_pretty(after_compression_total_bytes) AS after,
       ROUND((1 - after_compression_total_bytes::numeric / before_compression_total_bytes) * 100, 1) AS ratio_pct
FROM chunk_compression_stats('readings')
ORDER BY chunk_name;
```

**Expected compression ratios:**
| Data Type | Typical Ratio |
|---|---|
| Regular timestamps (1-second intervals) | 95-99% |
| Slowly-changing floats (sensor data) | 90-95% |
| Random floats | 60-80% |
| Low-cardinality text | 85-95% |
| High-cardinality text (UUIDs) | 50-70% |
| Mixed workload overall | 85-95% |

## Continuous Aggregate Design

### Refresh Policy Tuning

```sql
-- Aggressive refresh (low latency, higher resource usage)
SELECT add_continuous_aggregate_policy('sensor_hourly',
    start_offset    => INTERVAL '2 hours',   -- re-materialize last 2 hours
    end_offset      => INTERVAL '30 minutes', -- don't touch very recent data
    schedule_interval => INTERVAL '30 minutes');

-- Conservative refresh (lower resource usage, higher latency)
SELECT add_continuous_aggregate_policy('sensor_hourly',
    start_offset    => INTERVAL '24 hours',
    end_offset      => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');
```

**Parameter guidance:**
| Parameter | Purpose | Guidance |
|---|---|---|
| `start_offset` | How far back to look for changes | >= 2x the time_bucket size; wider if late data arrives |
| `end_offset` | Don't materialize data newer than this | >= 1 time_bucket; prevents materializing incomplete buckets |
| `schedule_interval` | How often the refresh job runs | Trade-off between freshness and resource usage |

### Hierarchical Aggregate Design

```sql
-- Level 1: Raw -> Hourly
CREATE MATERIALIZED VIEW metrics_hourly WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) AS bucket, device_id,
       AVG(value) AS avg_val,
       SUM(value) AS sum_val,
       COUNT(*) AS cnt,
       MIN(value) AS min_val,
       MAX(value) AS max_val
FROM readings GROUP BY bucket, device_id WITH NO DATA;

-- Level 2: Hourly -> Daily
CREATE MATERIALIZED VIEW metrics_daily WITH (timescaledb.continuous) AS
SELECT time_bucket('1 day', bucket) AS bucket, device_id,
       SUM(sum_val) / SUM(cnt) AS avg_val,  -- exact average, not AVG(avg_val)
       SUM(sum_val) AS sum_val,
       SUM(cnt) AS cnt,
       MIN(min_val) AS min_val,
       MAX(max_val) AS max_val
FROM metrics_hourly GROUP BY 1, device_id WITH NO DATA;

-- Level 3: Daily -> Monthly
CREATE MATERIALIZED VIEW metrics_monthly WITH (timescaledb.continuous) AS
SELECT time_bucket('1 month', bucket) AS bucket, device_id,
       SUM(sum_val) / SUM(cnt) AS avg_val,
       SUM(sum_val) AS sum_val,
       SUM(cnt) AS cnt,
       MIN(min_val) AS min_val,
       MAX(max_val) AS max_val
FROM metrics_daily GROUP BY 1, device_id WITH NO DATA;
```

**Key pattern:** Store `SUM` and `COUNT` separately, compute AVG as `SUM/COUNT` at each level for exact averages. Using `AVG(avg_val)` produces incorrect results due to unequal group sizes.

### Real-Time Aggregates Decision

| Scenario | real_time | Reason |
|---|---|---|
| Dashboard with 5-second refresh | ON | Users expect current data |
| Historical reporting | OFF | Only materialized data needed |
| Alerting on recent data | ON | Must see the latest values |
| Heavy aggregation with many users | OFF | Avoid redundant computation per query |

```sql
-- Enable real-time
ALTER MATERIALIZED VIEW metrics_hourly SET (timescaledb.materialized_only = false);

-- Disable real-time (only materialized data)
ALTER MATERIALIZED VIEW metrics_hourly SET (timescaledb.materialized_only = true);
```

## Data Retention Strategy

### Tiered Retention Model

```sql
-- Tier 1: Hot data (uncompressed, fast queries)
-- 0 to 7 days, no compression

-- Tier 2: Warm data (compressed, good query performance)
SELECT add_compression_policy('readings', INTERVAL '7 days');

-- Tier 3: Cold data (tiered to object storage, Tiger Cloud only)
SELECT add_tiering_policy('readings', INTERVAL '90 days');

-- Tier 4: Delete (drop old data entirely)
SELECT add_retention_policy('readings', INTERVAL '365 days');
```

### Retention with Continuous Aggregates

When you drop raw data but want to keep aggregates:

```sql
-- Keep hourly aggregates for 2 years
SELECT add_retention_policy('metrics_hourly', INTERVAL '2 years');

-- Keep daily aggregates for 5 years
SELECT add_retention_policy('metrics_daily', INTERVAL '5 years');

-- Drop raw data after 90 days
SELECT add_retention_policy('readings', INTERVAL '90 days');

-- Now queries on metrics_daily still work for historical data
-- even after raw data is gone
```

### Retention Policy Interaction with Compression

- Retention policies drop entire chunks
- If a chunk is compressed, it is still dropped (no decompression needed)
- Order of policies: compression runs first (older data compressed), then retention drops even older compressed chunks
- Ensure `retention_interval > compression_interval`

## PostgreSQL Tuning for TimescaleDB

### Memory Configuration

```
# shared_buffers: 25% of total RAM (standard PG guidance)
# TimescaleDB benefits from caching recent/active chunks
shared_buffers = '8GB'          # For 32GB RAM server

# effective_cache_size: 75% of RAM (tells planner about OS cache)
effective_cache_size = '24GB'

# work_mem: memory per sort/hash operation
# Higher values reduce temp file usage but multiply by max_connections
work_mem = '64MB'               # For analytical queries
# For OLTP-heavy: work_mem = '16MB'

# maintenance_work_mem: for VACUUM, CREATE INDEX, compression operations
maintenance_work_mem = '2GB'
```

### Parallelism

```
# Allow parallel query across chunks
max_parallel_workers_per_gather = 4    # per-query parallelism
max_parallel_workers = 8               # total parallel workers
parallel_tuple_cost = 0.01             # encourage parallel plans
parallel_setup_cost = 100              # lower for more parallelism

# Total worker processes (PG workers + TimescaleDB workers)
max_worker_processes = 32
```

### WAL and Checkpoint Tuning

```
# For high ingest rates
max_wal_size = '8GB'                   # allow more WAL before checkpoint
min_wal_size = '2GB'
checkpoint_completion_target = 0.9     # spread checkpoint writes
wal_buffers = '64MB'                   # WAL buffer in shared memory

# For very high ingest (>100K rows/sec)
wal_compression = lz4                  # compress WAL records (PG 15+)
```

### Autovacuum Tuning

```
# Autovacuum runs on each chunk independently
# More aggressive settings for high-ingest hypertables
autovacuum_max_workers = 5             # default 3, increase for many chunks
autovacuum_vacuum_scale_factor = 0.01  # vacuum after 1% dead tuples (default 20%)
autovacuum_analyze_scale_factor = 0.01 # analyze after 1% changes
autovacuum_vacuum_cost_limit = 1000    # default 200, increase for faster vacuum

# Per-table override for high-ingest hypertables
ALTER TABLE readings SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_analyze_scale_factor = 0.01
);
```

### TimescaleDB-Specific Settings

```
# Background workers for policies
timescaledb.max_background_workers = 8  # default 16; set based on policy count

# Telemetry (optional, disable in air-gapped environments)
timescaledb.telemetry_level = 'basic'   # off | basic | full

# License
timescaledb.license = 'timescale'       # 'apache' for OSS-only features

# Insert batch size (for COPY-like performance on multi-row INSERTs)
timescaledb.max_insert_batch_size = 1000
```

### Connection Pooling

TimescaleDB background workers consume connections. Account for them in max_connections and pool sizing:

```
# Total connections needed:
# application_connections + timescaledb.max_background_workers + superuser_reserved + monitoring
max_connections = 200

# Use pgBouncer or pgpool-II for connection pooling
# PgBouncer configuration:
# pool_mode = transaction     # recommended for TimescaleDB
# default_pool_size = 20
# max_client_conn = 1000
```

### SSD/NVMe Planner Settings

```
# For SSD storage (most TimescaleDB deployments)
random_page_cost = 1.1                 # default 4.0, lower for SSD
seq_page_cost = 1.0                    # baseline
effective_io_concurrency = 200         # SSD supports high concurrency (Linux only)
```

## Hardware Selection

### Minimum Requirements

| Component | Development | Production (Small) | Production (Large) |
|---|---|---|---|
| CPU | 2 cores | 8 cores | 32+ cores |
| RAM | 4 GB | 32 GB | 128+ GB |
| Storage | 50 GB SSD | 500 GB NVMe | 4+ TB NVMe RAID |
| Ingest rate | < 1K rows/sec | < 100K rows/sec | 100K+ rows/sec |

### Storage Guidance

- **NVMe SSD** strongly recommended for all production deployments
- Separate disks for WAL and data directories if possible
- RAID 10 for data directories (best balance of performance and redundancy)
- Compression reduces storage needs by 90%+ (plan based on compressed size)
- Size storage for: uncompressed hot data + compressed warm data + indexes + WAL + temp space

### Memory Sizing

```
Rule of thumb:
- shared_buffers should hold all active (uncompressed) chunks
- Active chunks = chunks for the last chunk_interval * number_of_hypertables
- Example: 10 hypertables, 1-day chunks, 500 MB each = 5 GB of active data
  -> shared_buffers >= 8 GB
  -> Total RAM >= 32 GB
```

## Migration Guidance

### From PostgreSQL Regular Tables

```sql
-- Step 1: Ensure TimescaleDB extension is loaded
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Step 2: Convert existing table (with data migration)
SELECT create_hypertable('existing_table', 'time_column',
    chunk_time_interval => INTERVAL '1 day',
    migrate_data => true);
-- Warning: migrate_data locks the table and can take a long time for large tables

-- Step 3: Add compression policy
ALTER TABLE existing_table SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'entity_id',
    timescaledb.compress_orderby = 'time_column DESC'
);
SELECT add_compression_policy('existing_table', INTERVAL '7 days');
```

### From InfluxDB

Key mapping:
| InfluxDB Concept | TimescaleDB Equivalent |
|---|---|
| Measurement | Hypertable |
| Tag | Indexed column (in segment-by) |
| Field | Regular column |
| Timestamp | TIMESTAMPTZ column |
| Retention policy | `add_retention_policy()` |
| Continuous query | Continuous aggregate |
| Bucket | `time_bucket()` |

```sql
-- InfluxDB: SELECT mean(temperature) FROM sensors WHERE time > now() - 1h GROUP BY time(5m), device_id
-- TimescaleDB:
SELECT time_bucket('5 minutes', time) AS bucket,
       device_id,
       AVG(temperature) AS mean_temperature
FROM sensors
WHERE time > NOW() - INTERVAL '1 hour'
GROUP BY bucket, device_id
ORDER BY bucket;
```

### Bulk Loading

```bash
# Use timescaledb-parallel-copy for fastest bulk loading
timescaledb-parallel-copy \
    --connection "host=localhost user=postgres dbname=mydb" \
    --table readings \
    --file data.csv \
    --workers 4 \
    --batch-size 10000

# Or use PostgreSQL COPY
psql -c "\COPY readings FROM 'data.csv' CSV HEADER"
```

**Bulk loading tips:**
- Disable compression policies during bulk load
- Load data in time order (newest last) for best chunk creation efficiency
- Use `timescaledb-parallel-copy` for multi-threaded loading
- Set `synchronous_commit = off` during bulk load (if data loss during load is acceptable)
- Increase `checkpoint_timeout` and `max_wal_size` during bulk load

## Monitoring Setup

### Essential Metrics to Monitor

| Metric | Source | Warning Threshold |
|---|---|---|
| Chunk count per hypertable | `timescaledb_information.chunks` | > 5,000 |
| Compression ratio | `hypertable_compression_stats()` | < 50% |
| Job failure count | `timescaledb_information.job_stats` | consecutive_failures > 3 |
| Data freshness | Latest chunk range_end | > 2x expected ingest interval |
| Disk usage growth | `pg_database_size()` over time | > 80% disk capacity |
| Connection count | `pg_stat_activity` | > 80% max_connections |
| Cache hit ratio | `pg_stat_database` | < 95% |
| Replication lag | `pg_stat_replication` | > 1 minute |
| Dead tuple ratio | `pg_stat_user_tables` | > 10% on active chunks |
| Background worker count | `pg_stat_activity` | Near max_background_workers |

### Grafana Dashboard Queries

```sql
-- Ingest rate (use with Grafana's rate() or increase() on counter)
SELECT NOW() AS time, relname,
       n_tup_ins AS total_inserts
FROM pg_stat_user_tables
WHERE relname IN (SELECT hypertable_name::text FROM timescaledb_information.hypertables);

-- Compression status over time
SELECT NOW() AS time, hypertable_name,
       COUNT(*) FILTER (WHERE is_compressed) AS compressed_chunks,
       COUNT(*) FILTER (WHERE NOT is_compressed) AS uncompressed_chunks
FROM timescaledb_information.chunks
GROUP BY hypertable_name;

-- Job health
SELECT NOW() AS time,
       j.proc_name, j.hypertable_name,
       js.last_run_status, js.consecutive_failures
FROM timescaledb_information.job_stats js
JOIN timescaledb_information.jobs j ON js.job_id = j.job_id;
```

### Prometheus / pg_exporter Metrics

Key `pg_stat` tables to export:
- `pg_stat_user_tables` (filtered to `_timescaledb_internal` schema)
- `pg_stat_database`
- `pg_stat_bgwriter`
- `timescaledb_information.job_stats`
- `timescaledb_information.chunks` (aggregated counts and sizes)

## Security Hardening

### Role-Based Access

```sql
-- Create a read-only role for dashboards
CREATE ROLE dashboard_reader;
GRANT USAGE ON SCHEMA public TO dashboard_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dashboard_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA _timescaledb_internal TO dashboard_reader;

-- Create a write role for ingest applications
CREATE ROLE ingest_writer;
GRANT USAGE ON SCHEMA public TO ingest_writer;
GRANT INSERT ON readings TO ingest_writer;
-- No SELECT, UPDATE, DELETE needed for pure ingest

-- Create an admin role for policy management
CREATE ROLE tsdb_admin;
GRANT ALL ON ALL TABLES IN SCHEMA public TO tsdb_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO tsdb_admin;
```

### Row-Level Security

```sql
-- Multi-tenant isolation using RLS
ALTER TABLE readings ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON readings
    USING (tenant_id = current_setting('app.tenant_id')::integer);

-- Application sets tenant context per connection
SET app.tenant_id = '42';
SELECT * FROM readings WHERE time > NOW() - INTERVAL '1 hour';
-- Only returns rows where tenant_id = 42
```

### SSL/TLS

```
# postgresql.conf
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'
ssl_ca_file = '/etc/ssl/certs/ca.crt'

# pg_hba.conf -- require SSL for all connections
hostssl all all 0.0.0.0/0 scram-sha-256
```

## High Availability

### Streaming Replication

TimescaleDB works with standard PostgreSQL streaming replication:

```
# Primary: postgresql.conf
wal_level = replica
max_wal_senders = 5
wal_keep_size = '1GB'     # PG 13+

# Standby: recovery.conf / postgresql.conf (PG 12+)
primary_conninfo = 'host=primary_ip port=5432 user=replicator'
hot_standby = on
```

**Important:** The standby must also have `shared_preload_libraries = 'timescaledb'`. TimescaleDB background workers only run on the primary; the standby is read-only.

### Patroni Integration

```yaml
# patroni.yml excerpt
postgresql:
  parameters:
    shared_preload_libraries: 'timescaledb'
    timescaledb.max_background_workers: 8
    max_worker_processes: 32
```

Patroni handles failover transparently. After failover:
- The new primary starts TimescaleDB background workers automatically
- Compression, retention, and cagg refresh policies resume on the new primary
- No manual intervention needed for TimescaleDB-specific operations

## Backup Strategy

### Backup Methods

| Method | Speed | Size | Point-in-Time | Online |
|---|---|---|---|---|
| `pg_basebackup` | Fast | Full DB size | Yes (with WAL archiving) | Yes |
| `pg_dump -Fc` | Moderate | Compressed logical | No | Yes |
| Filesystem snapshot | Fastest | Full DB size | No (unless consistent) | Requires consistent snapshot |
| `pgBackRest` | Fast | Incremental support | Yes | Yes |

### Recommended: pgBackRest

```bash
# Full backup
pgbackrest --stanza=timescale backup --type=full

# Incremental backup (after first full)
pgbackrest --stanza=timescale backup --type=incr

# Restore to point in time
pgbackrest --stanza=timescale restore \
    --type=time --target='2025-03-15 10:00:00'
```

### pg_dump Considerations

- `pg_dump` includes all chunk data and TimescaleDB catalog tables
- Compressed chunks are dumped in compressed form (efficient)
- On restore, TimescaleDB extension must be created first
- Large databases: use `pg_dump -j <workers>` for parallel dump

```bash
# Parallel dump (8 workers)
pg_dump -Fd -j 8 -f /backup/timescale_dump mydb

# Restore
pg_restore -d mydb -j 8 /backup/timescale_dump
```
