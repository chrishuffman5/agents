# Apache Druid Architecture Reference

## Cluster Topology

### Server Types

Druid processes are organized into three logical server types for deployment:

**Master Server (Coordinator + Overlord):**
- Can be co-located on the same JVM using `druid.coordinator.asOverlord.enabled=true`
- Manages cluster state, segment assignment, and ingestion tasks
- Lightweight CPU/memory requirements; primary concern is metadata store connectivity
- Recommended: 2 nodes for HA (leader election via ZooKeeper)

**Query Server (Broker + Router):**
- Broker handles query parsing, routing, result merging
- Router provides optional API gateway and hosts the web console
- Scale based on concurrent query volume and result set sizes
- Recommended: 2+ Brokers behind a load balancer

**Data Server (Historical + MiddleManager/Indexer):**
- Historical nodes serve immutable segment data for queries
- MiddleManager/Indexer handles ingestion workloads
- Can be co-located or separated depending on workload isolation needs
- Scale based on data volume and query throughput requirements

### Process Internals

**Coordinator:**
```
Coordinator Process
  ├── Segment Management
  │   ├── Load/Drop segment assignments to Historical nodes
  │   ├── Balance segments across Historical tier groups
  │   ├── Enforce retention rules (load rules, drop rules)
  │   └── Manage segment replication factor
  ├── Compaction Scheduler
  │   ├── Monitor segment sizes and count per interval
  │   ├── Submit compaction tasks to Overlord
  │   └── Track compaction progress and debt
  ├── Metadata Polling
  │   ├── Poll metadata store for new/changed segments
  │   ├── Poll for rule changes
  │   └── Mark unused segments for cleanup
  └── Leader Election (ZooKeeper)
      └── Only the leader Coordinator is active
```

**Key Coordinator properties:**
```properties
druid.coordinator.period=PT30S                          # Coordination run interval
druid.coordinator.period.indexingPeriod=PT1800S          # Compaction check interval
druid.coordinator.startDelay=PT300S                     # Delay before first run
druid.coordinator.compaction.maxCompactionTaskSlots=0.1  # Fraction of total slots for compaction
druid.coordinator.load.timeout=PT15M                    # Segment load timeout
druid.coordinator.kill.on=true                          # Enable kill task for unused segments
druid.coordinator.kill.period=P1D                       # Kill task interval
druid.coordinator.kill.durationToRetain=P90D            # Keep unused segments this long
```

**Overlord:**
```
Overlord Process
  ├── Task Management
  │   ├── Task queue (pending, running, complete)
  │   ├── Task assignment to MiddleManagers/Indexers
  │   ├── Task lifecycle management
  │   └── Task locking (time chunk locks, segment locks)
  ├── Supervisor Management
  │   ├── Kafka/Kinesis supervisor lifecycle
  │   ├── Offset tracking and checkpointing
  │   ├── Task group management (replicas)
  │   └── Supervisor state machine (RUNNING, SUSPENDED, etc.)
  ├── Autoscaling (optional)
  │   └── Scale MiddleManagers based on pending tasks
  └── Leader Election (ZooKeeper)
      └── Only the leader Overlord is active
```

**Key Overlord properties:**
```properties
druid.indexer.runner.type=remote                        # Use remote runners (MiddleManagers)
druid.indexer.queue.startDelay=PT30S                    # Queue startup delay
druid.indexer.runner.maxZnodeBytes=524288               # Max task payload size in ZK
druid.indexer.storage.type=metadata                     # Task storage in metadata store
```

**Broker:**
```
Broker Process
  ├── Query Processing
  │   ├── Parse SQL (Calcite) or native JSON queries
  │   ├── Query planning and optimization
  │   ├── Route subqueries to Historical/real-time nodes
  │   ├── Merge partial results from data nodes
  │   └── Apply post-aggregations and limits
  ├── Segment Timeline
  │   ├── Maintain in-memory timeline of all segments
  │   ├── Track which Historical nodes serve which segments
  │   └── Real-time task discovery for streaming data
  ├── Query Caching
  │   ├── Per-segment result cache (caffeine/memcached)
  │   └── Whole-query result cache
  └── Connection Pool
      └── HTTP connections to Historical and real-time nodes
```

**Key Broker properties:**
```properties
druid.broker.cache.useCache=true
druid.broker.cache.populateCache=true
druid.broker.cache.useResultLevelCache=true
druid.broker.cache.populateResultLevelCache=true
druid.server.http.numThreads=60
druid.broker.http.numConnections=20
druid.broker.http.readTimeout=PT5M
```

**Historical:**
```
Historical Process
  ├── Segment Loading
  │   ├── Download segments from deep storage
  │   ├── Cache segments on local disk
  │   ├── Memory-map segment files for query access
  │   └── Announce loaded segments to ZooKeeper
  ├── Query Execution
  │   ├── Process subqueries from Broker
  │   ├── Scan relevant segments
  │   ├── Apply filters using bitmap indexes
  │   ├── Compute partial aggregations
  │   └── Stream results back to Broker
  ├── Segment Cache Management
  │   ├── LRU eviction when cache is full
  │   ├── Track segment usage for eviction priority
  │   └── Configurable cache size
  └── Tiering
      ├── Multiple tier groups (hot, warm, cold)
      └── Load rules determine tier assignment
```

**Key Historical properties:**
```properties
druid.server.maxSize=500000000000                       # Max segment cache size (500GB)
druid.segmentCache.locations=[{"path":"/data/druid/segment-cache","maxSize":500000000000}]
druid.server.tier=_default_tier                         # Tier name for load rules
druid.server.priority=0                                 # Higher priority = loads first
druid.processing.buffer.sizeBytes=536870912             # 512MB processing buffer
druid.processing.numThreads=7                           # Processing threads (cores - 1)
druid.processing.numMergeBuffers=2                      # Merge buffers for groupBy
```

**MiddleManager/Indexer:**
```
MiddleManager Process
  ├── Peon Management
  │   ├── Fork Peon JVMs for each task
  │   ├── Resource allocation per Peon
  │   └── Task lifecycle monitoring
  └── Task Slots
      ├── druid.worker.capacity = N (max concurrent tasks)
      └── Each slot = 1 Peon JVM

Indexer Process (alternative, single JVM)
  ├── Thread-based task execution
  │   ├── Tasks run as threads, not separate JVMs
  │   ├── Lower overhead, shared heap
  │   └── Better for small/medium task counts
  └── Task Slots
      └── druid.worker.capacity = N
```

## Segment Storage Internals

### Column Storage Format

Each segment stores columns independently in a compressed, indexed format:

**String dimensions:**
```
Dictionary: sorted unique values -> integer IDs
  0 -> "click"
  1 -> "impression"
  2 -> "purchase"

Encoded column: [0, 1, 0, 2, 0, 1, ...]  (integer array, compressed)

Bitmap indexes (one per dictionary value):
  "click"      -> [1, 0, 1, 0, 1, 0, ...]
  "impression" -> [0, 1, 0, 0, 0, 1, ...]
  "purchase"   -> [0, 0, 0, 1, 0, 0, ...]
```

Bitmap indexes enable extremely fast filtering: filtering by `event_type = 'click'` is a simple bitmap lookup, returning matching row positions in microseconds regardless of segment size.

**Numeric columns (long, float, double):**
```
Compressed array: LZ4 or similar compression
  [150, 200, 100, 350, ...]
No bitmap index by default (can be enabled)
```

**Timestamp column (__time):**
```
Compressed long array (epoch milliseconds)
Special encoding: delta + LZ4 for monotonic timestamps
Always present, always the first column
```

### V9 vs. V10 Segment Format

**V9 (default through Druid 35.x):**
- Production-stable format used since Druid 0.9
- Smooshed file format (multiple logical files in one physical file)
- Dictionary-encoded strings with bitmap indexes
- Compressed numeric columns

**V10 (experimental in 36.x):**
- Enabled via `druid.indexer.task.buildV10=true`
- Improved compression for complex metric columns
- Better handling of wide segments (many columns)
- Not backward-compatible with pre-31.x releases

### Partitioning and Sharding

Segments are first partitioned by time, then optionally sharded:

**Time partitioning (segmentGranularity):**
```
events/2026-04-07T00:00:00.000Z_2026-04-07T01:00:00.000Z/  (HOUR)
events/2026-04-07T00:00:00.000Z_2026-04-08T00:00:00.000Z/  (DAY)
events/2026-04-01T00:00:00.000Z_2026-05-01T00:00:00.000Z/  (MONTH)
```

**Secondary partitioning (sharding within a time chunk):**

| Partition Type | How It Works | When to Use |
|---|---|---|
| Dynamic | Segments created as data arrives, split at maxRowsPerSegment | Streaming ingestion (default) |
| Hashed | Hash partition on specified dimensions | Batch ingestion, perfect rollup |
| Range | Range partition on a single dimension | Batch ingestion, ordered queries |
| Single-dim | Partition by ranges of a single dimension | Batch ingestion, dimension-specific queries |

**Hash partitioning for perfect rollup:**
```json
{
  "tuningConfig": {
    "type": "index_parallel",
    "partitionsSpec": {
      "type": "hashed",
      "numShards": 8,
      "partitionDimensions": ["event_type", "country"]
    },
    "forceGuaranteedRollup": true
  }
}
```

### Segment Versioning and Shadowing

Druid uses version strings to manage concurrent data for the same time interval:

```
Segment: events_2026-04-07T00:00:00.000Z_2026-04-08T00:00:00.000Z_2026-04-07T12:00:00.000Z_0
         |datasource|          |interval start|         |interval end|          |version|      |partition|

Version format: timestamp when the segment was created
```

- **Newer version shadows older version** for the same interval
- Queries always use the latest version
- Old versions remain in deep storage until explicitly killed
- REPLACE operations create a new version, atomically replacing old data

### Deep Storage Layout

**S3 deep storage example:**
```
s3://druid-deep-storage/
  druid/segments/
    events/
      2026-04-07T00:00:00.000Z_2026-04-07T01:00:00.000Z/
        2026-04-07T12:34:56.789Z/
          0/
            index.zip    (the segment file)
          1/
            index.zip    (shard 1 if partitioned)
```

## Query Execution Engine

### SQL Query Flow

```
1. Client sends SQL to Broker (POST /druid/v2/sql)
2. Broker parses SQL using Apache Calcite
3. Calcite generates a logical plan (RelNode tree)
4. Druid's query planner converts to native Druid queries:
   - Simple aggregation -> Timeseries
   - Single-dimension top-k -> TopN
   - Multi-dimension grouping -> GroupBy
   - No aggregation -> Scan
5. Broker looks up segment timeline for the queried interval
6. Broker routes subqueries to Historical nodes serving those segments
7. Historical nodes execute against local segments:
   a. Apply time interval filter (skip irrelevant segments)
   b. Apply dimension filters using bitmap indexes
   c. Scan matching rows and compute partial aggregations
   d. Return partial results to Broker
8. Broker merges partial results (final aggregation, sorting, limiting)
9. Broker returns results to client
```

### Native Query Execution on Historical

```
Filter Phase:
  1. Time interval check -> skip entire segment if out of range
  2. Bitmap index intersection for dimension filters
     e.g., event_type='click' AND country='US'
     -> bitmap_click AND bitmap_US = matching row positions
  3. Apply non-indexed filters (numeric ranges, regex)

Scan Phase:
  4. For matching row positions, read required columns
  5. Decompress column blocks on demand
  6. Apply aggregations in a streaming fashion

Output Phase:
  7. Serialize partial results
  8. Stream back to Broker via HTTP
```

### MSQ (Multi-Stage Query) Engine

The MSQ engine supports SQL-based batch ingestion and complex analytical queries:

**Architecture:**
```
MSQ Task (Overlord)
  ├── Controller Task
  │   ├── Plans the query across stages
  │   ├── Manages stage transitions
  │   └── Coordinates shuffle between stages
  └── Worker Tasks (on MiddleManagers)
      ├── Stage 0: Read from external data or segments
      ├── Stage 1: Filter, transform, partial aggregate
      ├── Stage 2: Shuffle (hash or sort by partition key)
      ├── Stage 3: Final aggregate, generate segments
      └── Stage N: Write segments to deep storage
```

**MSQ vs. Native Queries:**
| Feature | Native (Broker) | MSQ (Overlord) |
|---|---|---|
| Query type | Real-time analytical queries | Batch ingestion, complex analytics |
| Latency | Sub-second to seconds | Minutes to hours |
| Data volume | Bounded by memory | Disk-based shuffle, unbounded |
| Joins | Hash join (right side in memory) | Disk-based sort-merge joins |
| Window functions | Limited | Full support (31+) |
| INSERT/REPLACE | Not supported | Supported |

### Dart Query Engine (31+)

Dart (Distributed Asynchronous Runtime Topology) is designed for complex analytical queries:

**How Dart differs from native queries:**
- Uses multi-threaded workers on Historical nodes
- Supports in-memory shuffles between stages
- Accesses locally cached segment data directly (no deep storage reads)
- Supports complex joins, subqueries, and CTEs
- Lower latency than MSQ for complex queries

**When to use Dart:**
- Complex joins between large datasources
- High-cardinality GROUP BY queries
- Queries with multiple subqueries or CTEs
- Ad-hoc analytical workloads that need interactive latency

```sql
-- Enable Dart for a query
SET queryEngine = 'dart';

SELECT
  e.event_type,
  l.country_name,
  COUNT(*) AS events,
  APPROX_COUNT_DISTINCT_DS_HLL(e.user_id) AS unique_users
FROM events e
JOIN country_lookup l ON e.country_code = l.country_code
WHERE e.__time >= CURRENT_TIMESTAMP - INTERVAL '7' DAY
GROUP BY 1, 2
ORDER BY events DESC
LIMIT 1000;
```

## Memory Architecture

### Historical Memory Model

```
Total RAM (e.g., 64 GB)
├── JVM Heap (24-30 GB)
│   ├── Segment metadata and indexes (~20%)
│   ├── Query processing (merge buffers, result sets)
│   ├── Cache (if using on-heap cache)
│   └── GC overhead
├── Direct Memory (4-8 GB)
│   ├── Processing buffers: buffer.sizeBytes * (numThreads + 1 + numMergeBuffers)
│   └── Network I/O buffers
└── OS Page Cache (remaining ~30 GB)
    └── Memory-mapped segment files (most critical for performance)
```

**JVM settings for Historical (64GB RAM example):**
```bash
-Xms24g -Xmx24g                    # 24GB heap
-XX:MaxDirectMemorySize=8g          # 8GB direct memory
-XX:+UseG1GC                        # G1 garbage collector
-XX:+ExitOnOutOfMemoryError          # Crash instead of thrashing
# Remaining ~32GB for OS page cache
```

**Processing buffer sizing:**
```properties
# Must satisfy: buffer.sizeBytes * (numThreads + numMergeBuffers + 1) <= MaxDirectMemorySize
druid.processing.buffer.sizeBytes=536870912     # 512 MB per buffer
druid.processing.numThreads=7                   # Processing threads
druid.processing.numMergeBuffers=2              # GroupBy merge buffers
# Total: 512 MB * (7 + 2 + 1) = 5 GB direct memory
```

### Broker Memory Model

```
Total RAM (e.g., 32 GB)
├── JVM Heap (16-20 GB)
│   ├── Query result merging
│   ├── Result-level cache
│   ├── Segment timeline metadata
│   └── HTTP connection pools
├── Direct Memory (4 GB)
│   ├── Processing buffers for merge
│   └── Network I/O
└── OS (remaining)
```

## Ingestion Internals

### Kafka Supervisor State Machine

```
States:
  PENDING           -> Supervisor created, awaiting initialization
  RUNNING           -> Actively managing ingestion tasks
  SUSPENDED         -> Paused by user, tasks stopped
  STOPPING          -> Shutting down gracefully
  UNHEALTHY_SUPERVISOR -> Supervisor process failing
  UNHEALTHY_TASKS   -> Tasks failing repeatedly

Transitions:
  PENDING -> RUNNING (initialization complete)
  RUNNING -> SUSPENDED (POST /druid/indexer/v1/supervisor/<id>/suspend)
  SUSPENDED -> RUNNING (POST /druid/indexer/v1/supervisor/<id>/resume)
  RUNNING -> UNHEALTHY_TASKS (task failures exceed threshold)
  * -> STOPPING (POST /druid/indexer/v1/supervisor/<id>/terminate)
```

### Ingestion Task Lifecycle

```
1. Task submitted to Overlord (via supervisor or API)
2. Overlord assigns task to a MiddleManager with available capacity
3. MiddleManager forks a Peon JVM (or runs as thread in Indexer mode)
4. Peon reads data from source:
   - Kafka: consumes messages from assigned partitions
   - Batch: reads from configured input source
5. Peon builds segment data in memory:
   - Dictionary-encodes string dimensions
   - Builds bitmap indexes
   - Accumulates metrics (with rollup if enabled)
6. When maxRowsInMemory reached or persist period expires:
   - Peon persists data to local disk as an intermediate segment
7. At task completion (taskDuration for streaming, end of data for batch):
   a. Peon merges intermediate segments into final segments
   b. Pushes final segments to deep storage
   c. Publishes segment metadata to metadata store
   d. Signals task completion to Overlord
8. Coordinator detects new segments and assigns to Historical nodes
9. Historical nodes download and serve the new segments
```

### Exactly-Once Semantics in Streaming

Druid achieves exactly-once ingestion through:

1. **Offset checkpointing** -- Supervisor tracks Kafka offsets in metadata store
2. **Segment transaction** -- Publishing segments is atomic with offset commits
3. **Task replicas** -- Multiple task replicas can consume the same partitions; only one publishes
4. **Idempotent publishing** -- If a task replays, it creates the same segments (deterministic)

## Tiering and Data Lifecycle

### Load Rules

Load rules control which Historical nodes serve which segments:

```json
[
  {
    "type": "loadByInterval",
    "interval": "2026-04-01/2026-05-01",
    "tieredReplicants": { "hot": 2 }
  },
  {
    "type": "loadByPeriod",
    "period": "P30D",
    "includeFuture": true,
    "tieredReplicants": { "hot": 2 }
  },
  {
    "type": "loadByPeriod",
    "period": "P365D",
    "includeFuture": false,
    "tieredReplicants": { "warm": 1 }
  },
  {
    "type": "dropForever"
  }
]
```

**Rule evaluation:**
- Rules are evaluated top-to-bottom; first matching rule wins
- `dropForever` at the end drops segments older than any load rule
- `tieredReplicants` specifies replicas per tier
- Coordinator enforces rules periodically

### Historical Tiering

```properties
# Hot tier (NVMe SSD, high memory)
druid.server.tier=hot
druid.server.priority=10
druid.server.maxSize=2000000000000    # 2TB

# Warm tier (SSD, moderate memory)
druid.server.tier=warm
druid.server.priority=5
druid.server.maxSize=5000000000000    # 5TB

# Cold tier (HDD or S3, minimal memory)
druid.server.tier=cold
druid.server.priority=0
druid.server.maxSize=20000000000000   # 20TB
```

## ZooKeeper Usage

### ZNode Structure

```
/druid/
  ├── announcements/          # Service announcements
  │   ├── broker_host:8082
  │   ├── historical_host:8083
  │   └── middlemanager_host:8091
  ├── coordinator/
  │   └── _LEADER            # Coordinator leader election
  ├── overlord/
  │   └── _LEADER            # Overlord leader election
  ├── segments/               # Segment load/drop protocol
  │   └── historical_host:8083/
  │       ├── _loadqueue      # Segments to load
  │       └── _dropqueue      # Segments to drop
  ├── discovery/              # Service discovery
  └── internal-discovery/     # Internal service discovery
```

### Reducing ZooKeeper Dependency

Recent Druid versions support HTTP-based segment management as an alternative:
```properties
druid.serverview.type=http
druid.coordinator.loadqueuepeon.type=http
```

This reduces ZooKeeper load for large clusters by moving segment load/drop coordination to direct HTTP calls.

## Extensions Architecture

Druid's functionality is extended through a pluggable extension system:

**Core extensions (bundled):**
- `druid-kafka-indexing-service` -- Kafka streaming ingestion
- `druid-kinesis-indexing-service` -- Kinesis streaming ingestion
- `druid-datasketches` -- HLL, Theta, Quantiles, Tuple sketches
- `druid-bloom-filter` -- Bloom filter for queries and ingestion
- `druid-multi-stage-query` -- MSQ engine for SQL-based ingestion
- `druid-s3-extensions` -- S3 deep storage
- `druid-hdfs-storage` -- HDFS deep storage
- `druid-google-extensions` -- GCS deep storage
- `druid-azure-extensions` -- Azure Blob deep storage
- `druid-lookups-cached-global` -- Global cached lookups
- `druid-kafka-extraction-namespace` -- Kafka-based lookups
- `druid-histogram` -- Approximate histograms
- `druid-stats` -- Statistical aggregations (variance, stddev)

**Loading extensions:**
```properties
# common.runtime.properties
druid.extensions.loadList=["druid-kafka-indexing-service","druid-datasketches",
  "druid-multi-stage-query","druid-s3-extensions","druid-lookups-cached-global",
  "druid-bloom-filter"]
```
