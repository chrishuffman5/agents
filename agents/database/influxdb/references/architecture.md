# InfluxDB Architecture Reference

## Data Model Internals

### Series Key

In InfluxDB, a **series** is the fundamental unit of storage. A series is uniquely identified by:

```
series_key = measurement + sorted(tag_key=tag_value pairs)
```

Example series keys:
```
cpu,host=server01,region=us-east
cpu,host=server01,region=us-west
cpu,host=server02,region=us-east
temperature,location=building-a,sensor=t1
```

Each series holds a sequence of (timestamp, field_key, field_value) tuples. The total number of unique series keys is the **series cardinality** -- the most important metric for InfluxDB performance planning.

### Measurement

A measurement is a logical grouping of series (analogous to a table in relational databases). All series within a measurement share the same set of tag keys and field keys (though values differ). In InfluxDB 3.x, measurements are explicitly called **tables**.

### Tags vs. Fields -- Storage Implications

**Tags** are indexed. In 2.x, they form part of the series key and are stored in the TSI (Time Series Index). Every unique combination of tag values creates a new series. Tags support equality and regex filtering with index lookups.

**Fields** are not indexed in 2.x (full scan required for field-value predicates). In 3.x, fields are stored in columnar Parquet format with zone maps, bloom filters, and dictionary encoding that provide efficient predicate pushdown without traditional indexing.

### Timestamp Resolution

InfluxDB stores timestamps as 64-bit integers in nanoseconds since the Unix epoch (January 1, 1970 UTC). This provides:
- Maximum resolution: 1 nanosecond
- Range: 1677-09-21 to 2262-04-11 (signed 64-bit nanoseconds)
- Write precision can be specified as ns, us, ms, or s
- Internally always stored as nanoseconds regardless of write precision

---

## InfluxDB 2.x Architecture (TSM Engine)

### Component Overview

```
                    ┌──────────────┐
                    │  HTTP API    │
                    │  /api/v2/*   │
                    └──────┬───────┘
                           │
              ┌────────────┴────────────┐
              │                         │
        ┌─────▼─────┐           ┌──────▼──────┐
        │  Write     │           │  Query      │
        │  Handler   │           │  Engine     │
        └─────┬──────┘           │  (Flux)     │
              │                  └──────┬──────┘
              │                         │
        ┌─────▼──────────────────────────▼──────┐
        │           Storage Engine               │
        │  ┌─────┐  ┌────────┐  ┌────────────┐ │
        │  │ WAL │  │ Cache  │  │ TSM Files  │ │
        │  └─────┘  └────────┘  └────────────┘ │
        │  ┌─────────────────────────────────┐  │
        │  │    Time Series Index (TSI)      │  │
        │  └─────────────────────────────────┘  │
        └───────────────────────────────────────┘
```

### Write-Ahead Log (WAL)

The WAL provides immediate durability for incoming writes:

1. **Write receipt** -- Points arrive via HTTP API in line protocol format
2. **WAL entry** -- Points are compressed (Snappy) and appended to the active WAL segment file
3. **Cache population** -- Points are simultaneously written to an in-memory cache
4. **Acknowledgment** -- Write is acknowledged to the client after WAL + cache write
5. **Segment rotation** -- When a WAL segment exceeds 10MB (default), a new segment is created
6. **Snapshot** -- Periodically, the cache is flushed to TSM files and WAL segments are truncated

**WAL segment files:**
```
<data-dir>/wal/<bucket-id>/<shard-id>/
  _00001.wal
  _00002.wal
  _00003.wal  (active)
```

**Crash recovery:** On restart, InfluxDB replays WAL segments to reconstruct the in-memory cache. This is why the WAL is critical for durability.

### In-Memory Cache

The cache is a write-through, in-memory store that makes recently written data immediately queryable:

- Organized by series key, then sorted by timestamp
- Default maximum size: `cache-max-memory-size = 1073741824` (1GB)
- Snapshot threshold: `cache-snapshot-memory-size = 26214400` (25MB)
- Write reject threshold: When cache exceeds `cache-max-memory-size`, writes are rejected with HTTP 503
- Snapshot interval: `cache-snapshot-write-cold-duration = 10m` (flush if no writes for 10 minutes)

**Cache eviction triggers:**
1. Cache size exceeds snapshot threshold --> triggers snapshot to TSM
2. No writes for cold duration --> triggers snapshot to TSM
3. Cache size exceeds max memory --> writes rejected (back-pressure)

### TSM File Format

TSM (Time-Structured Merge tree) files are the on-disk storage format for time-series data:

```
┌──────────────────────────────────────────────────┐
│                   TSM File                        │
├──────────┬──────────┬──────────┬─────────────────┤
│  Header  │  Blocks  │  Index   │     Footer      │
│  (5 B)   │ (var)    │  (var)   │     (8 B)       │
└──────────┴──────────┴──────────┴─────────────────┘
```

**Header (5 bytes):** Magic number (4 bytes) + version (1 byte)

**Blocks:** Compressed data blocks, each containing:
- CRC32 checksum (4 bytes)
- Data length (2 bytes)
- Compressed timestamp values + compressed field values
- Compression algorithms vary by data type:
  - Timestamps: Delta-of-delta + simple8b encoding (or RLE for regular intervals)
  - Floats: Facebook Gorilla XOR encoding
  - Integers: Zig-zag delta + simple8b encoding
  - Strings: Snappy compression
  - Booleans: Bit-packed

**Index:** Sorted index of series keys to block locations:
- Key: series key + field key
- Value: list of (min_time, max_time, offset, size) entries per block
- Enables efficient time-range lookups within a TSM file

**Footer:** Offset to the start of the index section.

### Time Series Index (TSI)

TSI is a disk-based index that maps series keys to shard locations, replacing the earlier in-memory index:

```
<data-dir>/index/<bucket-id>/<shard-id>/
  L0-00000001.tsl    (log file, in-memory)
  L1-00000001.tsi    (compacted index file)
  L2-00000001.tsi    (further compacted)
  MANIFEST            (tracks active files)
```

**TSI structure:**
- **Log file (L0):** Append-only log of new series; kept in memory
- **Index files (L1+):** Immutable, disk-based files with sorted series keys
- **Measurement block:** Maps measurement names to tag blocks
- **Tag block:** Maps tag keys to tag value blocks
- **Tag value block:** Maps tag values to posting lists (series IDs)
- **Series block:** Maps series IDs to series keys

**Cardinality impact:** Every unique series key requires an entry in the TSI. When cardinality exceeds available memory, TSI falls back to disk, dramatically slowing lookups.

### Shard Groups and Shards

Data is organized into shard groups based on time ranges:

| Bucket Retention | Shard Group Duration |
|---|---|
| < 2 days | 1 hour |
| 2 days - 6 months | 1 day |
| > 6 months | 7 days |
| Infinite | 7 days |

Each shard group contains one or more shards. In OSS (single node), there is one shard per shard group. Each shard contains:
- Its own WAL directory
- Its own TSM file directory
- Its own TSI partition

**Shard lifecycle:**
1. **Hot shard:** Currently accepting writes (current time range)
2. **Warm shard:** Recently closed, still being compacted
3. **Cold shard:** Fully compacted, read-only
4. **Expired shard:** Past retention period, eligible for deletion

### Compaction Process (2.x)

Compaction optimizes TSM files by merging and re-encoding data:

**Compaction levels:**

| Level | Source | Trigger | Output |
|---|---|---|---|
| **L0** | WAL snapshots | Cache snapshot | Small TSM files |
| **L1** | L0 files | Multiple L0 files accumulate | Merged, better compressed |
| **L2** | L1 files | Multiple L1 files accumulate | Larger, more optimal files |
| **L3** | L2 files | Multiple L2 files accumulate | Near-optimal files |
| **L4 (Full)** | All levels | Cold duration or manual trigger | Single optimized file per series |

**Compaction tuning parameters:**
```
[data]
  compact-full-write-cold-duration = "4h"    # Time before full compaction of idle shards
  compact-throughput = 50331648              # Bytes per second compaction rate limit
  compact-throughput-burst = 50331648        # Burst rate for compaction
  max-concurrent-compactions = 0             # 0 = runtime.GOMAXPROCS / 2
```

**Full compaction:** When no writes occur for `compact-full-write-cold-duration`, all TSM files for a shard are merged into optimally-compressed files. This produces the best compression but requires significant I/O.

### Flux Query Engine (2.x)

Flux is a functional data scripting language with a pipeline model:

```
Source --> Filter --> Transform --> Aggregate --> Output
```

**Query execution pipeline:**
1. **Planning:** Flux script is parsed into an Abstract Syntax Tree (AST)
2. **Logical plan:** AST is converted to a logical query plan (directed acyclic graph of operations)
3. **Physical plan:** Logical plan is optimized and mapped to physical operators
4. **Execution:** Physical operators execute against the storage engine
5. **Streaming results:** Results are streamed back via annotated CSV or JSON

**Key Flux optimizations:**
- **Pushdown predicates:** Time range filters, tag filters, and field selections are pushed down to the storage layer
- **Schema-on-read:** Field types are resolved during query execution
- **Memory management:** Flux uses table-based memory allocation with configurable limits

---

## InfluxDB 3.x Architecture (IOx Engine)

### Component Overview

```
                    ┌──────────────────┐
                    │   HTTP/gRPC API  │
                    │  v3 + v2 compat  │
                    └────────┬─────────┘
                             │
              ┌──────────────┴──────────────┐
              │                              │
        ┌─────▼──────┐              ┌───────▼───────┐
        │  Ingester   │              │  Query Engine │
        │  (Write)    │              │  (DataFusion) │
        └─────┬───────┘              └───────┬───────┘
              │                              │
        ┌─────▼──────┐              ┌───────▼───────┐
        │    WAL      │              │   Catalog     │
        │  (1s flush) │              │  (Metadata)   │
        └─────┬───────┘              └───────┬───────┘
              │                              │
        ┌─────▼──────────────────────────────▼──────┐
        │              Object Store                  │
        │        (Parquet files on disk/S3)          │
        └──────────────────┬────────────────────────┘
                           │
                    ┌──────▼───────┐
                    │  Compactor   │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │   Garbage    │
                    │  Collector   │
                    └──────────────┘
```

### FDAP Technology Stack

InfluxDB 3.x is built entirely on the Apache Arrow ecosystem (the "FDAP stack"):

| Component | Role | Description |
|---|---|---|
| **Apache Arrow** | Memory format | Columnar in-memory data representation. Zero-copy data sharing between components. |
| **Apache DataFusion** | Query engine | Rust-based SQL query engine with extensible optimizer. Supports SQL and custom logical/physical plans. |
| **Apache Arrow Flight** | Data transfer | gRPC-based protocol for efficient columnar data transfer. Used by client libraries. |
| **Apache Parquet** | Storage format | Columnar file format with row groups, column chunks, and page-level encoding. Self-describing schema. |

### Ingester

The Ingester is responsible for accepting writes and persisting data:

1. **Receive** -- Line protocol arrives via HTTP API (v3 or v2 compat endpoints)
2. **Parse** -- Line protocol is parsed into Arrow RecordBatches
3. **Buffer** -- RecordBatches are held in a write buffer (in-memory)
4. **WAL flush** -- Every 1 second (default), the write buffer is flushed to the WAL
5. **Persist** -- Periodically, buffered data is persisted as Parquet files to the object store
6. **Catalog update** -- The Catalog is updated with the new Parquet file metadata

**Write buffer characteristics:**
- Data is immediately queryable from the write buffer
- Organized by database and table (measurement)
- Partitioned by time (default: daily partitions)
- Arrow RecordBatch format enables zero-copy query access

### Write-Ahead Log (3.x)

The InfluxDB 3.x WAL differs significantly from 2.x:

- **Flush interval:** 1 second (configurable via `--wal-flush-interval`)
- **Purpose:** Durability between in-memory buffer and object store persistence
- **Format:** Serialized write buffer contents
- **Recovery:** On restart, WAL is replayed to reconstruct the in-memory state
- **Retention:** WAL segments are removed after data is persisted to the object store

### Object Store (Parquet Files)

The object store is the primary durable storage layer:

**Supported backends:**
| Backend | Flag | Use Case |
|---|---|---|
| Local filesystem | `--object-store file --data-dir /path` | Development, single-node |
| Memory | `--object-store memory` | Testing only |
| AWS S3 | `--object-store s3` | Production cloud |
| S3-compatible | `--object-store s3` + endpoint override | MinIO, Ceph, etc. |

**Parquet file organization:**
```
<object-store-root>/
  <database>/
    <table>/
      <partition_key>/
        <file_id>.parquet
```

**Parquet file internals:**
```
┌────────────────────────────────────┐
│           Parquet File             │
├────────────────────────────────────┤
│  Row Group 1                       │
│  ├── Column Chunk: time            │
│  │   ├── Page 1 (data)             │
│  │   └── Page 2 (data)             │
│  ├── Column Chunk: host (tag)      │
│  │   └── Page 1 (dictionary enc.)  │
│  ├── Column Chunk: usage (field)   │
│  │   └── Page 1 (data)             │
│  └── Column Chunk: region (tag)    │
│      └── Page 1 (dictionary enc.)  │
├────────────────────────────────────┤
│  Row Group 2                       │
│  └── ...                           │
├────────────────────────────────────┤
│  Footer                            │
│  ├── Schema                        │
│  ├── Row group metadata            │
│  │   ├── Column chunk offsets      │
│  │   ├── Column statistics         │
│  │   │   ├── min/max values        │
│  │   │   ├── null count            │
│  │   │   └── distinct count        │
│  │   └── Encodings used            │
│  └── Key-value metadata            │
└────────────────────────────────────┘
```

**Parquet encoding strategies:**
| Data Type | Encoding | Benefit |
|---|---|---|
| Tags (low cardinality) | Dictionary encoding | Compact storage, fast equality predicates |
| Tags (high cardinality) | Plain + Snappy/Zstd | Handles unbounded values |
| Timestamps | Delta binary packed | Exploits monotonic nature of time series |
| Floats | Byte stream split | Better compression for IEEE 754 |
| Integers | Delta binary packed | Exploits correlation in sequential values |
| Strings | Plain + Snappy/Zstd | General-purpose compression |

### Catalog (Metadata Store)

The Catalog tracks all metadata about databases, tables, columns, and Parquet files:

- Stores schema information (table definitions, column types)
- Tracks Parquet file locations, sizes, and statistics
- Maintains partition information
- Persisted alongside the object store
- In Enterprise: replicated across nodes for consistency

### Apache DataFusion Query Engine

DataFusion provides the query execution engine for InfluxDB 3.x:

**Query execution pipeline:**
1. **Parse** -- SQL or InfluxQL is parsed into an AST
2. **Logical plan** -- AST is converted to a logical plan (relational algebra)
3. **Optimization** -- Rule-based and cost-based optimizations:
   - Predicate pushdown (push filters to Parquet reader)
   - Projection pushdown (read only needed columns)
   - Partition pruning (skip irrelevant time partitions)
   - Statistics-based pruning (skip row groups based on min/max)
4. **Physical plan** -- Logical plan is mapped to physical operators
5. **Execution** -- Physical operators execute against buffered data and Parquet files
6. **Result** -- Results are returned as Arrow RecordBatches via JSON, CSV, or Arrow Flight

**Key DataFusion optimizations for time series:**
- **Partition pruning:** Time-based queries skip entire partitions (days of data)
- **Row group pruning:** Column statistics in Parquet footers allow skipping row groups
- **Dictionary filter pushdown:** Tag predicates leverage dictionary-encoded columns
- **Late materialization:** Only referenced columns are read from Parquet
- **Parallel execution:** Multiple partitions and row groups are scanned in parallel

### Partitioning

Data in InfluxDB 3.x is partitioned by time (default: daily):

**Default partition template:**
- One partition per day per table
- Partition key format: `YYYY-MM-DD`
- Each partition maps to one or more Parquet files

**Custom partition templates (Enterprise/Clustered):**
```
# Partition by day and a tag value
partition_template:
  - time: "%Y-%m-%d"
  - tag: "host"

# Partition by day and tag bucket (hash-based)
partition_template:
  - time: "%Y-%m-%d"
  - tag_bucket:
      tag: "host"
      num_buckets: 16
```

**Partition pruning benefits:**
- Query for last 1 hour only reads today's partition (1 of potentially thousands)
- Tag-based partitioning additionally prunes on tag predicates
- Reduces I/O dramatically for selective queries

### Compactor (3.x)

The Compactor is a background process that optimizes Parquet files in the object store:

**Compaction goals:**
1. **Merge small files** -- Combine many small Parquet files into fewer larger files
2. **Sort data** -- Ensure data within files is sorted optimally (by time, then tags)
3. **Deduplicate** -- Remove duplicate data points (same series + timestamp)
4. **Re-encode** -- Apply optimal encoding based on actual data distribution
5. **Update statistics** -- Refresh column statistics in Parquet metadata

**Compaction in Core vs. Enterprise:**
- **Core:** Limited background compaction (recent data optimization)
- **Enterprise:** Full compaction pipeline for historical data, configurable compaction policies

### Garbage Collector (3.x)

The Garbage Collector runs as a background process:
- Removes Parquet files that have been replaced by compaction output
- Deletes data that exceeds retention policies
- Reclaims object store space
- Updates the Catalog to remove references to deleted files

### Last Value Cache (LVC)

An in-memory cache that stores the most recent N values for specified fields:

```sql
-- Create a last value cache
influxdb3 create last_cache --database mydb --table cpu \
  --cache-name cpu_latest \
  --key-columns host,region \
  --value-columns usage_user,usage_system \
  --count 1

-- Query the cache (SQL)
SELECT * FROM last_cache('cpu_latest');
```

**Use cases:** Dashboard "current value" panels, status boards, alerting on latest state.

### Distinct Value Cache (DVC)

An in-memory cache that stores distinct values for specified columns:

```sql
-- Create a distinct value cache
influxdb3 create distinct_cache --database mydb --table cpu \
  --cache-name cpu_hosts \
  --columns host,region

-- Query the cache (SQL)
SELECT * FROM distinct_cache('cpu_hosts');
```

**Use cases:** Populating dropdown filters, auto-discovery of tag values, template variable population.

### Processing Engine (3.x)

InfluxDB 3.x includes an embedded Python processing engine for data transformation, enrichment, and alerting:

**Trigger types:**
| Trigger | Fires When | Use Case |
|---|---|---|
| **WAL flush** | Write buffer flushes to WAL (~1s) | Real-time data transformation, alerting |
| **Schedule** | Cron expression fires | Periodic aggregation, cleanup, reporting |
| **HTTP request** | Custom API endpoint called | On-demand processing, webhooks |

**Plugin lifecycle:**
1. Install a Python package: `influxdb3 install package <pip-package>`
2. Create a trigger: `influxdb3 create trigger --trigger-spec <spec> --plugin-file <file> --database <db>`
3. Enable/disable: `influxdb3 enable trigger` / `influxdb3 disable trigger`
4. Monitor: `influxdb3 show triggers`

---

## Multi-Node Architecture (Enterprise)

### Node Roles

| Role | Responsibility | Scaling |
|---|---|---|
| **Writer** | Accepts writes, runs WAL, persists Parquet | 1 writer per cluster (active/standby HA) |
| **Reader** | Serves queries, reads from object store | Scale horizontally (up to 15 nodes) |
| **Writer/Reader** | Both roles on one node | Small deployments |
| **Compactor** | Background compaction of Parquet files | Runs alongside writer or dedicated |

### High Availability

- **Writer HA:** Active/standby writer with automatic failover
- **Reader scaling:** Multiple reader nodes share the query load
- **Object store durability:** S3 (or compatible) provides 11 nines of durability
- **Catalog replication:** Metadata is replicated across nodes
- **No single point of failure:** Object store is the source of truth

### Data Flow in Enterprise

```
Writes --> Writer Node --> WAL --> Object Store (Parquet)
                                       │
              ┌────────────────────────┤
              │            │           │
         Reader Node  Reader Node  Compactor
              │            │           │
         Query Results  Query Results  Optimized Parquet
```

---

## Network Protocol and API Architecture

### InfluxDB 2.x API

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/v2/write` | POST | Write line protocol data |
| `/api/v2/query` | POST | Execute Flux queries |
| `/api/v2/buckets` | GET/POST/PATCH/DELETE | Bucket management |
| `/api/v2/orgs` | GET/POST/PATCH/DELETE | Organization management |
| `/api/v2/tasks` | GET/POST/PATCH/DELETE | Task management |
| `/api/v2/authorizations` | GET/POST/PATCH/DELETE | Token management |
| `/api/v2/dashboards` | GET/POST/PATCH/DELETE | Dashboard management |
| `/health` | GET | Health check |
| `/ready` | GET | Readiness check |
| `/metrics` | GET | Prometheus metrics |

### InfluxDB 3.x API

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/v3/write_lp` | POST | Write line protocol (new v3 endpoint) |
| `/api/v3/query_sql` | GET/POST | Execute SQL queries |
| `/api/v3/query_influxql` | GET/POST | Execute InfluxQL queries |
| `/api/v3/configure/database` | GET/POST/DELETE | Database management |
| `/api/v3/configure/table` | GET/POST/DELETE | Table management |
| `/api/v3/configure/last_cache` | GET/POST/DELETE | Last value cache management |
| `/api/v3/configure/distinct_cache` | GET/POST/DELETE | Distinct value cache management |
| `/api/v3/configure/processing_engine_trigger` | GET/POST/DELETE | Trigger management |
| `/api/v2/write` | POST | Write (v2 compatibility) |
| `/health` | GET | Health check |
| `/metrics` | GET | Prometheus metrics |

### Arrow Flight Interface (3.x)

InfluxDB 3.x exposes an Apache Arrow Flight gRPC interface for high-performance data transfer:

- **Port:** 8181 (same as HTTP by default)
- **Protocol:** gRPC with Arrow Flight RPC
- **Use case:** Client libraries use Flight for query results (much faster than JSON/CSV for large result sets)
- **Authentication:** Bearer token via Flight handshake

```python
# Python client using Arrow Flight
from influxdb_client_3 import InfluxDBClient3

client = InfluxDBClient3(
    host="http://localhost:8181",
    database="mydb",
    token="your-token"
)

# Query returns a PyArrow Table
table = client.query("SELECT * FROM cpu WHERE time > now() - INTERVAL '1 hour'")
df = table.to_pandas()
```
