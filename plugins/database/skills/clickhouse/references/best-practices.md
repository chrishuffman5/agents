# ClickHouse Best Practices Reference

## Schema Design

### Primary Key (ORDER BY) Design

The ORDER BY clause is the single most important design decision for a ClickHouse table. It determines:
- How data is physically sorted on disk (compression efficiency)
- Which queries can use the sparse primary index (query speed)
- Skip index effectiveness (granule-level filtering)

**Column ordering rules:**

1. **Lowest cardinality first** -- Columns with fewer distinct values produce better compression and more effective index pruning. Place enum-like or categorical columns first.
2. **Most-queried filter columns next** -- Columns that appear in WHERE clauses should be in the ORDER BY prefix.
3. **Higher cardinality columns later** -- user_id, session_id, etc.
4. **Time columns typically last** -- Unless time-range is the primary access pattern.

**Example -- event analytics table:**
```sql
CREATE TABLE events (
    event_date    Date,
    event_type    LowCardinality(String),     -- ~50 distinct values
    country       LowCardinality(String),     -- ~200 distinct values
    user_id       UInt64,                      -- millions of distinct values
    event_time    DateTime64(3),               -- nanosecond precision
    session_id    String,
    properties    Map(String, String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_type, country, user_id, event_time)
SETTINGS index_granularity = 8192;
```

This ORDER BY supports efficient queries like:
- `WHERE event_type = 'click'` -- Uses first column of index
- `WHERE event_type = 'click' AND country = 'US'` -- Uses first two columns
- `WHERE event_type = 'click' AND country = 'US' AND user_id = 12345` -- Uses three columns
- `WHERE event_type = 'click' AND event_time > '2026-01-01'` -- Uses first column + scans within

This ORDER BY does NOT efficiently support:
- `WHERE user_id = 12345` -- Cannot use index (user_id is not the prefix)
- `WHERE country = 'US'` -- Skips event_type, only partial index use

**Solution for secondary access patterns:** Projections or materialized views.

### Partitioning Strategy

**Rules:**
| Data Volume / Day | Partition By | Expected Partitions |
|---|---|---|
| < 10M rows/day | `toYYYYMM(date)` | 12-24 |
| 10M-1B rows/day | `toYYYYMM(date)` | 12-24 |
| > 1B rows/day | `toMonday(date)` or `toYYYYMM(date)` | 12-52 |
| Multi-tenant | `(tenant_id, toYYYYMM(date))` | tenants * 12 |

**Anti-patterns:**
- Partitioning by hour or day on a low-volume table (creates too many tiny parts)
- Partitioning by high-cardinality column (e.g., user_id) -- creates millions of partitions
- Not partitioning at all on a table that grows unboundedly (makes DROP old data difficult)

**Total partition limit:** Keep total active partitions per table under 1,000. ClickHouse will warn at higher counts and performance degrades.

### Data Type Selection

**Choosing the right type:**

| Data | Recommended Type | Avoid | Why |
|---|---|---|---|
| Short enum-like strings | `LowCardinality(String)` | `String` | 5-10x faster, 5-10x less space |
| Status codes | `Enum8` or `LowCardinality(String)` | `String` | Fixed set: Enum enforces values |
| Timestamps | `DateTime` or `DateTime64(3)` | `String` | 4-8 bytes vs. 20+ bytes |
| Dates | `Date` or `Date32` | `DateTime`, `String` | 2-4 bytes |
| IP addresses | `IPv4`, `IPv6` | `String` | 4-16 bytes vs. 15-39 bytes |
| UUIDs | `UUID` | `String` | 16 bytes vs. 36 bytes |
| Boolean | `UInt8` (0/1) | `Bool` or `String` | Native boolean is fine in newer versions, but UInt8 is idiomatic |
| Monetary values | `Decimal64(2)` or `Decimal128(4)` | `Float64` | Exact decimal arithmetic |
| Optional values | Default value + convention | `Nullable(T)` | Nullable adds 1 byte per row + processing overhead |

**Nullable anti-pattern:**
```sql
-- BAD: Nullable adds overhead and complicates queries
CREATE TABLE events (
    user_id Nullable(UInt64),
    event_type Nullable(String),
    amount Nullable(Float64)
) ENGINE = MergeTree() ORDER BY tuple();

-- GOOD: Use default values instead
CREATE TABLE events (
    user_id UInt64 DEFAULT 0,                     -- 0 = unknown
    event_type LowCardinality(String) DEFAULT '',  -- '' = unknown
    amount Float64 DEFAULT 0                       -- 0 = no amount
) ENGINE = MergeTree() ORDER BY (event_type, user_id);
```

Nullable is appropriate when the distinction between "unknown" and "zero/empty" is semantically important (e.g., a temperature reading where NULL means "sensor offline" and 0 means "zero degrees").

### Codec Selection

**Recommended codecs by data type:**

| Data Pattern | Codec | Example |
|---|---|---|
| Monotonic timestamps | `DoubleDelta, LZ4` | `DateTime CODEC(DoubleDelta, LZ4)` |
| Monotonic counters | `Delta, LZ4` | `UInt64 CODEC(Delta, LZ4)` |
| IEEE 754 floats | `Gorilla, LZ4` | `Float64 CODEC(Gorilla, LZ4)` |
| Small integers | `T64, LZ4` | `UInt16 CODEC(T64, LZ4)` |
| Large text/JSON | `ZSTD(3)` | `String CODEC(ZSTD(3))` |
| High-entropy random | `ZSTD(1)` or `LZ4` | `UUID CODEC(LZ4)` |
| Very compressible | `ZSTD(9)` | Cold storage archives |

**Measuring codec effectiveness:**
```sql
-- Compare compression for a column
SELECT
    formatReadableSize(sum(column_data_compressed_bytes)) AS compressed,
    formatReadableSize(sum(column_data_uncompressed_bytes)) AS uncompressed,
    round(sum(column_data_uncompressed_bytes) / sum(column_data_compressed_bytes), 2) AS ratio
FROM system.parts_columns
WHERE active AND database = 'default' AND table = 'events' AND column = 'event_time';
```

## Insert Performance

### Batch Insert Best Practices

**Target metrics:**
| Metric | Target | Danger Zone |
|---|---|---|
| Rows per INSERT | 10,000 - 1,000,000 | < 100 per INSERT |
| Inserts per second (per table) | 1-5 | > 20 without async |
| Parts created per minute | < 50 | > 300 (too many parts risk) |

**Insert batching patterns:**

```sql
-- GOOD: Bulk insert via VALUES
INSERT INTO events VALUES
    ('2026-04-07 10:00:00', 'click', 'US', 42, ...),
    ('2026-04-07 10:00:01', 'view', 'UK', 43, ...),
    ... -- thousands of rows
;

-- GOOD: Insert from file
clickhouse-client --query "INSERT INTO events FORMAT CSVWithNames" < batch.csv

-- GOOD: Insert from S3 (parallel reads)
INSERT INTO events SELECT * FROM s3('s3://bucket/data/*.parquet', 'Parquet')
SETTINGS max_insert_threads = 8;

-- BAD: Single-row inserts in a loop
-- Each creates a new part; will hit "too many parts" quickly
for row in data:
    execute(f"INSERT INTO events VALUES ({row})")  -- DON'T DO THIS
```

### Async Insert Configuration

For applications that cannot batch (e.g., event streaming with individual HTTP requests):

```sql
-- Server-level (users.xml or SET)
SET async_insert = 1;
SET wait_for_async_insert = 0;                   -- fire-and-forget (fastest)
SET async_insert_max_data_size = 10485760;       -- flush at 10MB
SET async_insert_busy_timeout_ms = 1000;         -- flush every 1 second
SET async_insert_max_query_number = 450;         -- flush at 450 pending queries
SET async_insert_deduplicate = 0;                -- disable dedup for perf (unless needed)
```

**How async inserts work:**
1. Client sends an INSERT (even a single row)
2. Server buffers the data in memory
3. When any threshold is reached (size, time, count), server flushes the buffer as a single part
4. If `wait_for_async_insert = 1`, client blocks until flush completes
5. If `wait_for_async_insert = 0`, client gets immediate acknowledgment (data could be lost if server crashes before flush)

### Buffer Table Pattern

For extremely high-frequency inserts where even async inserts are insufficient:

```sql
CREATE TABLE events_buffer AS events
ENGINE = Buffer(default, events, 16,   -- 16 buffer slots
    10, 100,                            -- min/max seconds before flush
    10000, 1000000,                     -- min/max rows before flush
    10000000, 100000000                 -- min/max bytes before flush
);

-- Inserts go to the buffer
INSERT INTO events_buffer VALUES (...);

-- Reads can query the buffer (includes unflushed data)
SELECT count() FROM events_buffer;
```

**Warning:** Buffer tables do not guarantee durability. Data in the buffer is lost on server crash.

## Query Optimization

### Primary Key Optimization

**Verify index usage with EXPLAIN:**
```sql
EXPLAIN indexes = 1
SELECT * FROM events WHERE event_type = 'click' AND country = 'US';
```

Good output:
```
ReadFromMergeTree
  Indexes:
    PrimaryKey
      Keys: event_type, country
      Condition: (event_type = 'click') AND (country = 'US')
      Parts: 5/200          -- only 5 of 200 parts scanned
      Granules: 120/50000   -- only 120 of 50000 granules scanned
```

Bad output (full scan):
```
ReadFromMergeTree
  Indexes:
    PrimaryKey
      Condition: true       -- no filtering by primary key
      Parts: 200/200        -- all parts scanned
      Granules: 50000/50000 -- all granules scanned
```

### JOIN Optimization

**Rule 1: Put the smaller table on the right:**
```sql
-- GOOD: small dimension table on right
SELECT e.*, u.name
FROM events e                      -- billions of rows
JOIN users u ON e.user_id = u.id;  -- millions of rows (right side, loaded into hash table)

-- BAD: large table on right (hash table won't fit in memory)
SELECT u.*, e.event_type
FROM users u
JOIN events e ON u.id = e.user_id;  -- billions of rows on the right = OOM
```

**Rule 2: Use dictionaries for dimension lookups:**
```sql
-- Instead of JOIN
SELECT e.*, u.name
FROM events e JOIN users u ON e.user_id = u.id;

-- Use dictGet (much faster, no hash table build)
SELECT e.*, dictGet('users_dict', 'name', e.user_id) AS user_name
FROM events e;
```

**Rule 3: GLOBAL JOIN for distributed tables:**
```sql
-- BAD: Without GLOBAL, the subquery runs on each shard independently
SELECT * FROM dist_events WHERE user_id IN (SELECT user_id FROM special_users);

-- GOOD: GLOBAL sends the subquery result to all shards once
SELECT * FROM dist_events WHERE user_id GLOBAL IN (SELECT user_id FROM special_users);
```

**Rule 4: Choose the right join algorithm:**
```sql
-- For large joins that may exceed memory
SET join_algorithm = 'grace_hash';
SET grace_hash_join_initial_buckets = 16;

-- For pre-sorted data
SET join_algorithm = 'full_sorting_merge';
```

### Aggregation Optimization

**Pre-aggregation with materialized views:**
```sql
-- Create a summary table
CREATE TABLE daily_stats (
    event_date Date,
    event_type LowCardinality(String),
    country LowCardinality(String),
    events SimpleAggregateFunction(sum, UInt64),
    users AggregateFunction(uniq, UInt64),
    total_amount SimpleAggregateFunction(sum, Float64)
) ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_type, country, event_date);

-- Materialized view populates it
CREATE MATERIALIZED VIEW daily_stats_mv TO daily_stats AS
SELECT
    toDate(event_time) AS event_date,
    event_type,
    country,
    count() AS events,
    uniqState(user_id) AS users,
    sum(amount) AS total_amount
FROM events
GROUP BY event_date, event_type, country;
```

**Approximate aggregation (much faster for large datasets):**
```sql
-- Instead of COUNT(DISTINCT user_id) -- exact but slow
SELECT uniqExact(user_id) FROM events;  -- exact, still faster than COUNT(DISTINCT)

-- Approximate (2% error, much faster)
SELECT uniq(user_id) FROM events;  -- HyperLogLog, ~2% error

-- Even faster approximation
SELECT uniqHLL12(user_id) FROM events;

-- Quantiles: exact vs approximate
SELECT quantileExact(0.95)(response_time_ms) FROM requests;  -- exact
SELECT quantile(0.95)(response_time_ms) FROM requests;       -- approximate, faster
SELECT quantileTDigest(0.95)(response_time_ms) FROM requests; -- T-Digest, good accuracy
```

### FINAL Optimization

When using `ReplacingMergeTree`, `FINAL` forces on-the-fly deduplication:

```sql
-- SLOW: FINAL forces merge-on-read
SELECT * FROM users FINAL WHERE user_id = 42;

-- FASTER alternatives:

-- 1. Use argMax to get latest version
SELECT argMax(name, updated_at), argMax(email, updated_at)
FROM users WHERE user_id = 42;

-- 2. Use FINAL with do_not_merge_across_partitions_select_final
SET do_not_merge_across_partitions_select_final = 1;
SELECT * FROM users FINAL WHERE user_id = 42;

-- 3. Use subquery with ROW_NUMBER
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY version DESC) AS rn
    FROM users WHERE user_id = 42
) WHERE rn = 1;
```

### PREWHERE Optimization

ClickHouse automatically applies `PREWHERE` optimization: filter columns are read first, and only rows passing the filter trigger reads of remaining columns.

```sql
-- ClickHouse automatically converts WHERE to PREWHERE when beneficial
SELECT * FROM events WHERE event_type = 'click';
-- Internally becomes: PREWHERE event_type = 'click'
-- Only reads event_type column first, then reads other columns for matching rows

-- You can force PREWHERE explicitly
SELECT * FROM events PREWHERE event_type = 'click' WHERE length(url) > 100;
-- event_type is evaluated in PREWHERE (fast), url filter applied after
```

**When PREWHERE helps most:** When the filter is highly selective (eliminates >50% of rows) and the filtered column is much smaller than the projected columns.

## Cluster Operations

### Rolling Upgrade Procedure

1. **Check replication health before starting:**
```sql
SELECT database, table, absolute_delay, queue_size
FROM system.replicas WHERE absolute_delay > 0 OR queue_size > 100;
```

2. **Upgrade one replica at a time:**
```bash
# On each node:
sudo systemctl stop clickhouse-server
sudo apt-get install clickhouse-server=25.12.*  # or equivalent
sudo systemctl start clickhouse-server
```

3. **Verify after each node:**
```sql
SELECT version();
SELECT database, table, absolute_delay FROM system.replicas;
```

4. **Wait for replication to catch up before moving to the next node.**

### Cluster Scaling: Adding a Shard

1. **Update cluster config** on all nodes (add the new shard definition)
2. **Reload config:**
```sql
SYSTEM RELOAD CONFIG;
```

3. **Create tables on the new shard:**
```sql
CREATE TABLE events_local ON CLUSTER my_cluster (...) ENGINE = ReplicatedMergeTree(...);
```

4. **Rebalance data** (optional, if you want to redistribute existing data):
```bash
# Use clickhouse-copier for large-scale data redistribution
clickhouse-copier --config-file copier-config.xml --task-path /clickhouse/copier/task1
```

### Backup Strategy

**Native backup (recommended for ClickHouse 23.x+):**
```sql
-- Full backup
BACKUP DATABASE analytics TO Disk('backups', 'full_20260407/');

-- Incremental backup
BACKUP DATABASE analytics TO Disk('backups', 'incr_20260407/')
SETTINGS base_backup = Disk('backups', 'full_20260401/');

-- Restore
RESTORE DATABASE analytics FROM Disk('backups', 'full_20260407/');

-- Backup to S3
BACKUP DATABASE analytics TO S3('https://bucket.s3.amazonaws.com/clickhouse-backups/20260407/', 'key', 'secret');
```

**Partition-level snapshots (for targeted backup):**
```sql
-- Freeze a partition (creates hardlinks in shadow/ directory)
ALTER TABLE events FREEZE PARTITION '202604';

-- The frozen data is at:
-- /var/lib/clickhouse/shadow/N/data/<database>/<table>/...
-- Copy this to backup storage
```

### Monitoring Checklist

**Critical alerts (immediate action needed):**
| Metric | Alert Threshold | Query |
|---|---|---|
| Max parts per partition | > 300 | `SELECT value FROM system.asynchronous_metrics WHERE metric = 'MaxPartCountForPartition'` |
| Replication lag | > 300 seconds | `SELECT max(absolute_delay) FROM system.replicas` |
| Keeper session expired | Any | `SELECT count() FROM system.replicas WHERE is_session_expired` |
| Disk usage | > 85% | `SELECT 100 * (1 - free_space / total_space) FROM system.disks` |
| OOM exceptions | Any | `SELECT count() FROM system.query_log WHERE exception LIKE '%MEMORY_LIMIT%' AND event_date = today()` |

**Warning alerts (investigate soon):**
| Metric | Alert Threshold | Query |
|---|---|---|
| Failed merges | Any | `SELECT count() FROM system.part_log WHERE event_type = 'MergePartsError' AND event_date = today()` |
| Stuck mutations | > 1 hour | `SELECT count() FROM system.mutations WHERE NOT is_done AND create_time < now() - INTERVAL 1 HOUR` |
| Slow queries | > 30s avg | `SELECT avg(query_duration_ms) FROM system.query_log WHERE type = 'QueryFinish' AND event_date = today()` |
| Replication queue | > 100 tasks | `SELECT max(queue_size) FROM system.replicas` |

## Configuration Tuning

### Server Settings (config.xml)

**Memory:**
```xml
<!-- 90% of RAM for ClickHouse (leave 10% for OS) -->
<max_server_memory_usage_to_ram_ratio>0.9</max_server_memory_usage_to_ram_ratio>

<!-- Mark cache: 5GB (important for read performance) -->
<mark_cache_size>5368709120</mark_cache_size>

<!-- Uncompressed cache: Enable only if queries re-read the same data -->
<uncompressed_cache_size>0</uncompressed_cache_size>
```

**Merge threads:**
```xml
<!-- For write-heavy workloads, increase merge pool -->
<background_pool_size>32</background_pool_size>
<background_merges_mutations_concurrency_ratio>2</background_merges_mutations_concurrency_ratio>

<!-- For replication-heavy workloads -->
<background_schedule_pool_size>32</background_schedule_pool_size>
<background_fetches_pool_size>8</background_fetches_pool_size>
```

**Connections:**
```xml
<max_connections>4096</max_connections>
<max_concurrent_queries>100</max_concurrent_queries>
<max_concurrent_insert_queries>20</max_concurrent_insert_queries>
<max_concurrent_select_queries>80</max_concurrent_select_queries>
```

### User-Level Settings (users.xml or SET)

**Query memory limits:**
```xml
<profiles>
    <default>
        <max_memory_usage>10000000000</max_memory_usage>           <!-- 10GB per query -->
        <max_bytes_before_external_group_by>5000000000</max_bytes_before_external_group_by>
        <max_bytes_before_external_sort>5000000000</max_bytes_before_external_sort>
        <max_execution_time>300</max_execution_time>                <!-- 5 min timeout -->
        <max_rows_to_read>10000000000</max_rows_to_read>           <!-- 10B rows safety -->
    </default>
    <readonly>
        <readonly>1</readonly>
        <max_memory_usage>5000000000</max_memory_usage>
        <max_execution_time>60</max_execution_time>
    </readonly>
</profiles>
```

### Hardware Recommendations

**Per-node guidelines:**

| Workload | CPU | RAM | Storage | Network |
|---|---|---|---|---|
| Light (< 1TB) | 8 cores | 32 GB | 1 TB NVMe SSD | 1 Gbps |
| Medium (1-10 TB) | 16-32 cores | 64-128 GB | 4-8 TB NVMe SSD | 10 Gbps |
| Heavy (10-100 TB) | 32-64 cores | 128-256 GB | 8-24 TB NVMe SSD | 25 Gbps |
| Cold storage tier | 8 cores | 32 GB | HDD or S3 | 10 Gbps |

**Key principles:**
- ClickHouse is CPU-bound for aggregation, I/O-bound for scans
- NVMe SSDs are strongly recommended for hot data
- RAM is primarily used by the OS page cache (compressed data) -- more RAM = more cached data = fewer disk reads
- ClickHouse scales linearly with CPU cores for most operations
- Network bandwidth matters for distributed queries and replication

### Linux OS Tuning

```bash
# Disable transparent huge pages (can cause latency spikes)
echo never > /sys/kernel/mm/transparent_hugepage/enabled

# Increase max open files
echo "clickhouse soft nofile 262144" >> /etc/security/limits.conf
echo "clickhouse hard nofile 262144" >> /etc/security/limits.conf

# Increase max memory map areas
echo "vm.max_map_count = 262144" >> /etc/sysctl.conf

# Set I/O scheduler to none/noop for NVMe
echo none > /sys/block/nvme0n1/queue/scheduler

# Disable swap (or set swappiness very low)
echo "vm.swappiness = 1" >> /etc/sysctl.conf

sysctl -p
```

## Common Anti-Patterns

### 1. Single-Row Inserts

**Problem:** Each INSERT creates a new part. 1000 single-row inserts/second = 1000 parts/second = "too many parts" within minutes.

**Solution:** Batch to 10K+ rows per INSERT, or enable async inserts.

### 2. Over-Partitioning

**Problem:** Partitioning by hour on a low-volume table creates 24 partitions/day = 8,760/year, each with tiny parts that are slow to merge.

**Solution:** Partition by month. Only partition by day/week for very high volumes (>100M rows/day).

### 3. Wrong ORDER BY

**Problem:** ORDER BY (timestamp, user_id) when most queries filter by user_id first.

**Solution:** ORDER BY (user_id, timestamp). Or add a projection: `ALTER TABLE t ADD PROJECTION p (SELECT * ORDER BY (user_id, timestamp))`.

### 4. Nullable Everywhere

**Problem:** Every column is `Nullable(T)`, adding 1 byte per row per column overhead and complicating queries (NULL semantics in aggregations).

**Solution:** Use default values (0, '', '1970-01-01') unless NULL has distinct business meaning.

### 5. Using ClickHouse as an OLTP Database

**Problem:** High-frequency single-row reads/writes, point lookups by primary key, transactional updates.

**Solution:** ClickHouse is not an OLTP database. Use PostgreSQL/MySQL for OLTP workloads. Use ClickHouse for analytical queries over large datasets. For hybrid patterns, use `ReplacingMergeTree` with `FINAL` for mutable state, but accept eventual consistency.

### 6. Excessive Use of FINAL

**Problem:** Every query on a `ReplacingMergeTree` uses `FINAL`, adding significant overhead.

**Solution:**
- Schedule periodic `OPTIMIZE TABLE FINAL` during low-traffic windows
- Use `argMax()` pattern for point lookups
- Use `do_not_merge_across_partitions_select_final = 1` when possible
- Accept slight stale data for dashboards (merges happen continuously)

### 7. Distributed Table Writes Without Sharding Key

**Problem:** Writing to a `Distributed` table without a sharding key sends all data to a random shard, not co-locating related data.

**Solution:** Always define a meaningful sharding key in the `Distributed` engine: `Distributed(cluster, db, table, xxHash64(user_id))`.

### 8. Ignoring Compression Codecs

**Problem:** Default LZ4 for all columns, missing 2-5x additional compression from specialized codecs.

**Solution:** Apply `DoubleDelta` for timestamps, `Delta` for counters, `Gorilla` for floats, `ZSTD` for strings.
