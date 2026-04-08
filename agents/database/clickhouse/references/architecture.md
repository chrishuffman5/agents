# ClickHouse Architecture Reference

## Storage Layer Internals

### Part Structure

Every MergeTree table stores data in **parts** -- immutable directories on disk. Each part contains:

```
/var/lib/clickhouse/data/<database>/<table>/<partition>_<min_block>_<max_block>_<level>/
├── checksums.txt          -- CRC32 checksums for all files
├── columns.txt            -- List of columns and their types
├── count.txt              -- Number of rows in the part
├── primary.idx            -- Sparse primary index (binary, one entry per granule)
├── partition.dat          -- Partition expression value
├── minmax_<col>.idx       -- Min/max values for partition key columns
├── <column>.bin           -- Compressed column data
├── <column>.mrk2          -- Mark file mapping granule number to offset in .bin
├── skp_idx_<name>.idx     -- Skip index data (if defined)
├── skp_idx_<name>.mrk2    -- Skip index marks
├── default_compression_codec.txt
└── ttl.txt                -- TTL expression metadata (if defined)
```

**Part naming convention:** `<partition_id>_<min_block_number>_<max_block_number>_<merge_level>`
- `partition_id` -- Hash or value of the partition expression
- `min_block_number` / `max_block_number` -- Monotonically increasing block numbers assigned at insert time
- `merge_level` -- Incremented each time the part participates in a merge (0 = freshly inserted)

### Granules and Marks

The **granule** is the fundamental unit of data reading in ClickHouse:

- A granule contains `index_granularity` consecutive rows (default 8192)
- The sparse primary index stores one entry per granule (the primary key values of the first row)
- **Mark files** (`.mrk2`) map each granule to a byte offset and row offset in the compressed column file
- When a query needs to read specific granules, ClickHouse:
  1. Binary-searches the sparse index to find matching granule ranges
  2. Uses mark files to seek directly to the compressed block
  3. Decompresses only the needed blocks
  4. Applies filters within the granule

**Adaptive index granularity** (enabled by default since 22.x):
```xml
<merge_tree>
    <index_granularity>8192</index_granularity>
    <index_granularity_bytes>10485760</index_granularity_bytes>  <!-- 10MB -->
    <!-- Granule size adapts: min(8192 rows, 10MB of data) -->
</merge_tree>
```

This ensures that granules for wide tables (many columns, large strings) do not become excessively large in bytes.

### Column File Format

Each column is stored in a `.bin` file with the following structure:

```
[Compressed Block 1]
  - Header: checksum (128-bit) | compression method (1 byte) | compressed size (4 bytes) | uncompressed size (4 bytes)
  - Compressed data (LZ4/ZSTD/Delta+LZ4/etc.)
[Compressed Block 2]
  ...
```

- Default compressed block size: 64KB-1MB (`min_compress_block_size` / `max_compress_block_size`)
- Multiple granules may share a compressed block
- Mark files record both the compressed block offset and the row offset within the decompressed block

### Wide vs. Compact Part Format

ClickHouse uses two part storage formats:

**Wide format** (default for large parts):
- One `.bin` and `.mrk2` file per column
- Efficient for large parts (millions of rows)
- Only needed columns are read from disk

**Compact format** (for small parts):
- All columns stored in a single `data.bin` file with a single `data.mrk2`
- Reduces the number of file descriptors for small parts
- Controlled by `min_bytes_for_wide_part` (default 10MB) and `min_rows_for_wide_part` (default 512)

**In-memory format** (for tiny inserts):
- Parts with < `min_bytes_for_compact_part` are stored in memory
- Flushed on shutdown or when memory pressure triggers it

### Merge Process

Merges are ClickHouse's core background operation, analogous to LSM-tree compaction:

**Merge selection algorithm:**
1. The merge scheduler periodically scans active parts per partition
2. It selects a set of adjacent parts (by block number range) to merge
3. Selection criteria consider: part sizes, part count, time since last merge
4. The `merge_selecting_sleep_ms` setting controls scan frequency (default 5000ms)

**Merge execution:**
1. Read all selected parts in sort-key order
2. Perform a k-way merge (since each part is already sorted by the primary key)
3. Apply engine-specific logic during merge:
   - `ReplacingMergeTree`: Keep only the latest row per sorting key
   - `AggregatingMergeTree`: Combine aggregate function states
   - `SummingMergeTree`: Sum numeric columns
   - `CollapsingMergeTree`: Cancel rows with opposite Sign values
4. Write the merged result as a new part
5. Mark old parts as inactive (they remain on disk temporarily for crash recovery)
6. Old parts are removed after `old_parts_lifetime` (default 8 minutes)

**Merge settings:**
```sql
-- Server-level (config.xml or system settings)
background_pool_size = 16                         -- number of merge threads
background_merges_mutations_concurrency_ratio = 2 -- max concurrent merges relative to pool
max_bytes_to_merge_at_max_space_in_pool = 161061273600  -- max merge size (~150GB)
max_bytes_to_merge_at_min_space_in_pool = 1048576       -- min merge size (1MB)
merge_max_block_size = 8192                              -- rows per block during merge read
```

**Monitoring merges:**
```sql
SELECT database, table, elapsed, progress,
       num_parts, result_part_name,
       total_size_bytes_compressed, total_size_marks,
       bytes_read_uncompressed, bytes_written_uncompressed
FROM system.merges;
```

### Mutations

Mutations are ALTER TABLE operations that rewrite data (UPDATE, DELETE):

```sql
-- Lightweight delete (marks rows as deleted, filtered at query time)
DELETE FROM events WHERE user_id = 0;

-- Traditional mutation (rewrites parts)
ALTER TABLE events DELETE WHERE user_id = 0;
ALTER TABLE events UPDATE status = 'cancelled' WHERE order_id = 123;
```

**Mutation execution:**
1. The mutation is added to a queue and assigned a mutation version number
2. Each part is rewritten with the mutation applied, creating a new part
3. The mutation is complete when all parts have been rewritten
4. Mutations are applied in order; concurrent mutations queue up

**Lightweight deletes (DELETE FROM) vs. Mutations (ALTER TABLE DELETE):**
- `DELETE FROM` marks rows with a bitmask in `_row_exists` virtual column. Fast to execute, but filtered at read time (slight read overhead).
- `ALTER TABLE DELETE` physically rewrites parts to remove rows. Slower to execute, but no read overhead after completion.
- Lightweight deletes are recommended for most use cases as of 24.x+.

**Monitoring mutations:**
```sql
SELECT database, table, mutation_id, command,
       create_time, parts_to_do, is_done,
       latest_failed_part, latest_fail_reason
FROM system.mutations
WHERE NOT is_done
ORDER BY create_time;
```

## Query Execution Engine

### Pipeline Architecture

ClickHouse processes queries as a directed acyclic graph (DAG) of processors (operators):

```
ReadFromMergeTree  -->  FilterTransform  -->  AggregatingTransform  -->  SortingTransform  -->  LimitTransform  -->  Output
```

**Key pipeline components:**
- **Sources**: Read data from storage (MergeTree, Distributed, external tables, etc.)
- **Transforms**: Filter, aggregate, sort, join, project, limit
- **Sinks**: Output formatting, insertion into target tables

**Viewing the pipeline:**
```sql
EXPLAIN PIPELINE SELECT event_type, count() FROM events GROUP BY event_type;
```

Output example:
```
(Expression)
ExpressionTransform
  (Aggregating)
  Resize 16 → 1
    AggregatingTransform × 16
      (Expression)
      ExpressionTransform × 16
        (ReadFromMergeTree)
        MergeTreeThread × 16 0 → 1
```

The `× 16` indicates 16 parallel threads, matching the number of CPU cores.

### Vectorized Execution

ClickHouse processes data in blocks (vectors) of rows, not row-by-row:

- Default block size: 8192 rows (`max_block_size`)
- Each block contains column arrays (not row arrays)
- Operations are applied to entire column arrays using SIMD instructions where possible
- Functions like `countIf`, `sumIf`, `avgIf` use vectorized conditional evaluation

**Performance impact of vectorization:**
- Eliminates virtual function call overhead per row
- Enables SIMD (SSE4.2, AVX2, AVX-512) auto-vectorization
- Maximizes CPU cache utilization (columnar data is cache-friendly)
- Typical throughput: 1-5 billion rows/second for simple aggregations on modern hardware

### JOIN Execution

ClickHouse supports multiple JOIN algorithms:

| Algorithm | Setting Value | When Used |
|---|---|---|
| Hash join | `hash` | Default. Right table is built into an in-memory hash table. |
| Parallel hash | `parallel_hash` | Multi-threaded hash table build. Better for large right tables. |
| Grace hash | `grace_hash` | Spills to disk when right table exceeds memory. |
| Sort-merge | `full_sorting_merge` | Both sides sorted by join key. Low memory, good for pre-sorted data. |
| Direct join | `direct` | Right table is a Dictionary or Join engine table. Fastest for lookups. |
| Auto | `auto` | Starts with hash, falls back to merge if memory exceeded. |

```sql
SET join_algorithm = 'auto';
SET max_bytes_in_join = 1000000000;  -- 1GB limit before spill

-- For distributed JOINs, use GLOBAL to avoid N*N subquery execution
SELECT *
FROM distributed_events e
GLOBAL JOIN dim_users u ON e.user_id = u.id;
```

**JOIN optimization tips:**
1. Always put the smaller table on the right side of JOIN
2. Use `GLOBAL JOIN` / `GLOBAL IN` in distributed queries to ship the right table once rather than executing the subquery on each shard
3. For dimension table lookups, use Dictionaries instead of JOINs
4. Pre-filter with WHERE before JOIN to reduce hash table size
5. Consider denormalizing data to avoid JOINs entirely (ClickHouse's strength is flat wide tables)

### Subquery Processing

**IN vs. JOIN:**
- `IN` with a subquery builds a hash set, not a hash table (less memory)
- For existence checks, `IN` is more efficient than `JOIN`
- `GLOBAL IN` ships the set to all shards once (critical for distributed queries)

```sql
-- Efficient: uses hash set
SELECT * FROM events WHERE user_id IN (SELECT user_id FROM vip_users);

-- GLOBAL version for distributed tables
SELECT * FROM dist_events WHERE user_id GLOBAL IN (SELECT user_id FROM vip_users);
```

## Distributed Architecture

### Cluster Configuration

A ClickHouse cluster is defined in config.xml:

```xml
<remote_servers>
    <my_cluster>
        <shard>
            <replica>
                <host>ch-shard1-replica1.example.com</host>
                <port>9000</port>
            </replica>
            <replica>
                <host>ch-shard1-replica2.example.com</host>
                <port>9000</port>
            </replica>
        </shard>
        <shard>
            <replica>
                <host>ch-shard2-replica1.example.com</host>
                <port>9000</port>
            </replica>
            <replica>
                <host>ch-shard2-replica2.example.com</host>
                <port>9000</port>
            </replica>
        </shard>
    </my_cluster>
</remote_servers>
```

**Cluster macros** (used in ReplicatedMergeTree paths):
```xml
<macros>
    <shard>01</shard>
    <replica>ch-shard1-replica1</replica>
    <cluster>my_cluster</cluster>
</macros>
```

### Distributed Query Flow

When a query hits a `Distributed` table:

1. **Initiator node** receives the query from the client
2. **Query planning**: The initiator determines which shards to contact based on:
   - The sharding key expression in the Distributed engine
   - WHERE clause conditions (shard pruning if the WHERE matches the sharding key)
3. **Subquery dispatch**: The initiator sends the transformed subquery to each shard
4. **Local execution**: Each shard executes the query against its local MergeTree table
5. **Result streaming**: Shards stream partial results back to the initiator
6. **Final merge**: The initiator applies final aggregation, sorting, and limits

**Important behaviors:**
- GROUP BY on distributed tables performs two-phase aggregation: local pre-aggregation on each shard, then final aggregation on the initiator
- ORDER BY ... LIMIT N sends `LIMIT N` to each shard, then the initiator sorts and applies the final LIMIT
- COUNT(DISTINCT x) on distributed tables is approximate by default (each shard returns its local distinct count). Use `uniq()` or `uniqExact()` for correct results.

### ON CLUSTER DDL

`ON CLUSTER` propagates DDL statements to all nodes in a cluster:

```sql
CREATE TABLE events_local ON CLUSTER my_cluster (...)
ENGINE = ReplicatedMergeTree(...)
...;

ALTER TABLE events_local ON CLUSTER my_cluster ADD COLUMN new_col String DEFAULT '';

DROP TABLE events_local ON CLUSTER my_cluster;
```

DDL execution is coordinated through ClickHouse Keeper via the distributed DDL queue. Monitor with:
```sql
SELECT * FROM system.distributed_ddl_queue ORDER BY entry DESC LIMIT 10;
```

### ClickHouse Keeper Internals

ClickHouse Keeper is a drop-in ZooKeeper replacement built into ClickHouse:

**Architecture:**
- Uses the Raft consensus protocol (not ZAB like ZooKeeper)
- Written in C++ (part of ClickHouse codebase, not Java)
- Lower memory footprint and latency than ZooKeeper
- Compatible with the ZooKeeper wire protocol
- Stores: replication logs, part metadata, merge/mutation assignments, leader election state

**What Keeper stores per replicated table:**
```
/clickhouse/tables/{shard}/{table}/
├── metadata         -- table schema (CREATE TABLE statement)
├── columns          -- column list
├── log/             -- replication log entries (insert, merge, mutate)
├── replicas/
│   ├── replica1/
│   │   ├── is_active
│   │   ├── host
│   │   ├── queue/   -- pending replication tasks for this replica
│   │   └── parts/   -- list of parts this replica has
│   └── replica2/
│       └── ...
├── leader_election/ -- ephemeral nodes for leader election
├── quorum/          -- insert quorum state
├── block_numbers/   -- block number allocation per partition
└── mutations/       -- active mutations
```

**Keeper sizing guidelines:**
| Metric | Small (< 50 tables) | Medium (50-500 tables) | Large (500+ tables) |
|---|---|---|---|
| CPU | 2 cores | 4 cores | 8+ cores |
| RAM | 4 GB | 8 GB | 16-32 GB |
| Disk | 50 GB SSD | 200 GB SSD | 500 GB+ NVMe |
| Nodes | 3 (minimum quorum) | 3 | 3 or 5 |

## Memory Management

### Memory Allocation

ClickHouse tracks memory usage at multiple levels:

- **Per-query**: `max_memory_usage` (default unlimited until server-level limit)
- **Per-user**: `max_memory_usage_for_user`
- **Per-server**: `max_server_memory_usage` and `max_server_memory_usage_to_ram_ratio`

**Memory pools:**
- **Query memory**: Used during query execution (hash tables for JOINs/GROUP BY, sort buffers, etc.)
- **Mark cache**: Caches `.mrk2` files in memory to avoid disk reads on mark lookups
- **Uncompressed cache**: Caches decompressed data blocks (disabled by default; enable for frequently re-read data)
- **OS page cache**: The most important cache -- Linux kernel caches compressed column data in RAM automatically
- **Primary key cache**: Sparse index entries cached in memory (small, always cached)
- **Dictionary memory**: Memory used by loaded dictionaries

**Key memory settings:**
```xml
<!-- config.xml -->
<mark_cache_size>5368709120</mark_cache_size>            <!-- 5GB mark cache -->
<uncompressed_cache_size>0</uncompressed_cache_size>     <!-- disabled by default -->
<max_server_memory_usage_to_ram_ratio>0.9</max_server_memory_usage_to_ram_ratio>
<max_concurrent_queries>100</max_concurrent_queries>
```

### External Aggregation and Sorting

When GROUP BY or ORDER BY exceeds memory limits, ClickHouse can spill to disk:

```sql
-- Enable external aggregation (spill to disk at 5GB)
SET max_bytes_before_external_group_by = 5000000000;

-- Enable external sorting (spill to disk at 5GB)
SET max_bytes_before_external_sort = 5000000000;

-- Temporary data directory (should be on fast storage)
-- In config.xml: <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
```

**How external aggregation works:**
1. Hash table grows in memory until the limit is reached
2. The hash table is flushed to a temporary file on disk (sorted by key)
3. A new in-memory hash table is created for incoming data
4. After all input is processed, the temporary files and final hash table are merge-sorted
5. Result: correct aggregation with bounded memory usage, at the cost of I/O

## Data Lifecycle

### TTL (Time-to-Live)

TTL rules automatically expire or move data:

```sql
-- Row-level TTL: delete rows after 90 days
CREATE TABLE events (
    event_time DateTime,
    data String
) ENGINE = MergeTree()
ORDER BY event_time
TTL event_time + INTERVAL 90 DAY;

-- Column-level TTL: clear column data after 30 days
CREATE TABLE events (
    event_time DateTime,
    detail_json String TTL event_time + INTERVAL 30 DAY,
    summary String
) ENGINE = MergeTree()
ORDER BY event_time;

-- Tiered storage TTL: move to cold storage after 30 days, delete after 365 days
CREATE TABLE events (
    event_time DateTime,
    data String
) ENGINE = MergeTree()
ORDER BY event_time
TTL event_time + INTERVAL 30 DAY TO VOLUME 'cold',
    event_time + INTERVAL 365 DAY DELETE;
```

**TTL execution:**
- TTL rules are evaluated during merges (not immediately when rows expire)
- `merge_with_ttl_timeout` controls minimum interval between TTL merges (default 14400 seconds = 4 hours)
- Force TTL evaluation: `OPTIMIZE TABLE events FINAL`
- Monitor: `SELECT * FROM system.parts WHERE delete_ttl_info_min != '1970-01-01 00:00:00'`

### Tiered Storage

ClickHouse supports multi-volume storage policies for hot/warm/cold data:

```xml
<!-- config.xml storage configuration -->
<storage_configuration>
    <disks>
        <nvme>
            <path>/mnt/nvme/clickhouse/</path>
        </nvme>
        <ssd>
            <path>/mnt/ssd/clickhouse/</path>
        </ssd>
        <hdd>
            <path>/mnt/hdd/clickhouse/</path>
        </hdd>
        <s3_cold>
            <type>s3</type>
            <endpoint>https://bucket.s3.amazonaws.com/clickhouse/</endpoint>
            <access_key_id>AKIAIOSFODNN7EXAMPLE</access_key_id>
            <secret_access_key>wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY</secret_access_key>
        </s3_cold>
    </disks>
    <policies>
        <tiered>
            <volumes>
                <hot>
                    <disk>nvme</disk>
                    <max_data_part_size_bytes>10737418240</max_data_part_size_bytes> <!-- 10GB -->
                </hot>
                <warm>
                    <disk>ssd</disk>
                    <max_data_part_size_bytes>107374182400</max_data_part_size_bytes> <!-- 100GB -->
                </warm>
                <cold>
                    <disk>hdd</disk>
                </cold>
                <archive>
                    <disk>s3_cold</disk>
                </archive>
            </volumes>
            <move_factor>0.1</move_factor> <!-- move when volume is >90% full -->
        </tiered>
    </policies>
</storage_configuration>
```

```sql
-- Use the storage policy
CREATE TABLE events (...)
ENGINE = MergeTree()
ORDER BY ...
SETTINGS storage_policy = 'tiered';

-- TTL-based movement between volumes
ALTER TABLE events MODIFY TTL
    event_time + INTERVAL 7 DAY TO VOLUME 'warm',
    event_time + INTERVAL 30 DAY TO VOLUME 'cold',
    event_time + INTERVAL 365 DAY TO VOLUME 'archive';
```

## Skip Indexes (Secondary Data Skipping Indexes)

Skip indexes allow ClickHouse to skip granules that definitely do not match a filter:

```sql
-- Bloom filter index for equality checks on high-cardinality columns
ALTER TABLE events ADD INDEX idx_trace_id trace_id TYPE bloom_filter(0.01) GRANULARITY 4;

-- Set index for low-cardinality columns
ALTER TABLE events ADD INDEX idx_status status TYPE set(100) GRANULARITY 4;

-- Min/max index (ngrambf for string substring search)
ALTER TABLE events ADD INDEX idx_url url TYPE ngrambf_v1(3, 256, 2, 0) GRANULARITY 4;

-- Token bloom filter for tokenized string search
ALTER TABLE events ADD INDEX idx_message message TYPE tokenbf_v1(256, 2, 0) GRANULARITY 4;

-- Materialize index for existing data
ALTER TABLE events MATERIALIZE INDEX idx_trace_id;
```

**Skip index types:**

| Type | Use Case | How It Works |
|---|---|---|
| `minmax` | Range queries on ordered columns | Stores min/max per granule set |
| `set(N)` | Equality checks, low cardinality | Stores set of distinct values (up to N) |
| `bloom_filter(fp_rate)` | Equality checks, high cardinality | Probabilistic; false positives possible |
| `ngrambf_v1(n, size, hashes, seed)` | Substring LIKE '%pattern%' search | N-gram bloom filter on string tokens |
| `tokenbf_v1(size, hashes, seed)` | Token-level search (space/punct delimited) | Bloom filter on word tokens |

**GRANULARITY parameter:** Determines how many index granularity blocks are combined into one skip index block. `GRANULARITY 4` means each skip index entry covers 4 * 8192 = 32,768 rows. Higher values = smaller index, coarser filtering.

## User-Defined Functions (UDFs)

ClickHouse supports SQL-based and executable UDFs:

```sql
-- SQL UDF
CREATE FUNCTION linear_interpolate AS (x, x0, y0, x1, y1) ->
    y0 + (x - x0) * (y1 - y0) / (x1 - x0);

SELECT linear_interpolate(5, 0, 0, 10, 100);  -- Returns 50

-- Executable UDF (calls external process)
-- Defined in /etc/clickhouse-server/user_defined_functions/my_udf.xml
```

## Access Control and Security

ClickHouse supports RBAC (Role-Based Access Control):

```sql
-- Create users
CREATE USER analyst IDENTIFIED WITH sha256_password BY 'secure_password';
CREATE USER etl_service IDENTIFIED WITH sha256_hash BY '...';

-- Create roles
CREATE ROLE readonly;
GRANT SELECT ON analytics.* TO readonly;
GRANT SHOW TABLES, SHOW COLUMNS, SHOW DATABASES ON *.* TO readonly;

CREATE ROLE etl_writer;
GRANT INSERT, SELECT ON analytics.* TO etl_writer;
GRANT CREATE TEMPORARY TABLE ON *.* TO etl_writer;

-- Assign roles
GRANT readonly TO analyst;
GRANT etl_writer TO etl_service;

-- Row-level security
CREATE ROW POLICY tenant_isolation ON analytics.events
FOR SELECT USING tenant_id = currentUser()
TO analyst;

-- Quota (rate limiting)
CREATE QUOTA analyst_quota
FOR INTERVAL 1 hour MAX queries = 1000, result_rows = 100000000
TO analyst;
```
