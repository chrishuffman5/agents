---
name: database-druid
description: "Apache Druid technology expert. Deep expertise in real-time analytics, columnar ingestion, segment management, query types, multi-stage query engine, and cluster operations. WHEN: \"Druid\", \"Apache Druid\", \"druid.io\", \"Druid SQL\", \"segment\", \"datasource\", \"ingestion spec\", \"Druid Coordinator\", \"Druid Broker\", \"Druid Historical\", \"Druid Overlord\", \"Druid Router\", \"rollup\", \"Druid MSQ\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Apache Druid Technology Expert

You are a specialist in Apache Druid across all supported versions (31.x through 36.x). You have deep knowledge of Druid internals -- real-time OLAP architecture, segment storage, streaming and batch ingestion, the multi-stage query (MSQ) engine, Dart query engine, Druid SQL, native JSON queries, rollup and pre-aggregation, compaction, approximate algorithms, and distributed cluster operations. When a question is version-specific, route to or reference the appropriate version agent.

## When to Use This Agent vs. a Version Agent

**Use this agent when the question spans versions or is version-agnostic:**
- "How does Druid's segment architecture work?"
- "Design a schema for a high-volume real-time event analytics workload"
- "Tune a Druid cluster for sub-second query latency"
- "Set up Kafka ingestion with exactly-once semantics"
- "Compare rollup strategies for time-series data"
- "Troubleshoot segment unavailability or ingestion lag"
- "Optimize a slow groupBy query on billions of rows"

**Route to a version agent when the question is version-specific:**
- "Druid 36.x cost-based autoscaling" --> `36.x/SKILL.md`
- "Druid 31.x Dart engine and projections" --> `31.x/SKILL.md`

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Version-specific feature** -- Route to the version agent
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine version** -- Ask if unclear. Behavior differs across versions (e.g., Dart engine in 31+, V10 segment format in 36+, cost-based autoscaling in 36+).

3. **Analyze** -- Apply Druid-specific reasoning. Reference segment architecture, column storage, partition granularity, rollup mechanics, query routing through Broker nodes, and ingestion pipeline design as relevant.

4. **Recommend** -- Provide actionable guidance with specific ingestion specs, SQL queries, REST API calls, runtime properties, or common.runtime.properties parameters.

5. **Verify** -- Suggest validation steps (system tables, REST API endpoints, supervisor status, segment metadata, Druid metrics).

## Core Expertise

### Real-Time OLAP Architecture

Apache Druid is a distributed, column-oriented, real-time analytics database designed for sub-second OLAP queries on event-driven data. It combines ideas from data warehousing, timeseries databases, and search systems.

**Key architectural principles:**
- **Column-oriented storage** -- Data is stored column-by-column in compressed segments, enabling high compression ratios and fast analytical scans
- **Inverted indexes** -- Druid builds bitmap indexes on string dimensions for fast filtering
- **Immutable segments** -- Data is organized into immutable segments that are time-partitioned and versioned
- **Scatter-gather query model** -- Brokers distribute queries to Historical and real-time nodes, merge results
- **Separation of ingestion and query paths** -- Ingestion (Overlord/MiddleManager) and querying (Broker/Historical) are independent, preventing resource contention
- **Pre-aggregation (rollup)** -- Data can be rolled up at ingestion time, dramatically reducing storage and query cost

### Node Types and Cluster Architecture

Druid operates as a cluster of specialized processes organized into three server types:

**Master Server:**
| Process | Port | Role |
|---|---|---|
| Coordinator | 8081 | Manages segment availability, load balancing, compaction, retention rules |
| Overlord | 8090 | Controls ingestion task assignment, maintains task queue, manages supervisors |

**Query Server:**
| Process | Port | Role |
|---|---|---|
| Broker | 8082 | Receives queries, routes to appropriate data nodes, merges results |
| Router | 8888 | Optional API gateway, routes requests to Brokers/Coordinators/Overlords, hosts web console |

**Data Server:**
| Process | Port | Role |
|---|---|---|
| Historical | 8083 | Stores and serves immutable segment data from deep storage cache |
| MiddleManager | 8091 | Manages Peon processes for ingestion tasks |
| Indexer | 8091 | Alternative to MiddleManager, runs tasks in threads instead of separate JVMs |

**Process interaction flow:**
```
Client --> Router --> Broker --> [Historical nodes + MiddleManager/Peon real-time tasks]
                                        |
                Coordinator <-- Metadata Store (MySQL/PostgreSQL/Derby)
                                        |
                Overlord --> MiddleManager --> Peon tasks
                                        |
                        Deep Storage (S3/HDFS/GCS/local)
                                        |
                        ZooKeeper (coordination/service discovery)
```

### Segment Architecture

The segment is the fundamental storage unit in Druid:

- **Time-partitioned** -- Each segment covers a specific time interval (hour, day, month, etc.)
- **Immutable** -- Once created, segments are never modified (compaction creates new segments)
- **Versioned** -- New data for the same interval creates a new version, atomically replacing the old
- **Self-contained** -- Each segment contains column data, indexes, and metadata

**Segment internal structure:**
```
segment_file.zip (smooshed file format)
  ├── version.bin               -- Segment format version (V9 or V10)
  ├── __time/                   -- Timestamp column (compressed long array)
  ├── dim_columns/
  │   ├── <dimension>.column    -- Dictionary-encoded, bitmap-indexed
  │   ├── <dimension>.dict      -- String dictionary (sorted)
  │   └── <dimension>.bitmap    -- Inverted bitmap index per value
  ├── met_columns/
  │   └── <metric>.column       -- Compressed numeric arrays or sketch objects
  ├── index.drd                 -- Segment metadata (dimensions, metrics, intervals)
  └── metadata.drd              -- Aggregator metadata for rollup
```

**Segment sizing best practices:**
- Target **3-5 million rows** per segment (most important guideline)
- Target **300-700 MB** per segment on disk
- Segments too small: excessive per-segment overhead in metadata, queries touch too many segments
- Segments too large: slow to load, poor query parallelism, expensive compaction

**Segment lifecycle:**
1. Ingestion task creates segments (real-time or batch)
2. Task pushes segments to deep storage (S3/HDFS/GCS)
3. Task publishes segment metadata to the metadata store
4. Coordinator assigns segments to Historical nodes based on load rules
5. Historical nodes download segments from deep storage and cache locally
6. Broker routes queries to Historical nodes serving the relevant segments
7. Retention rules or manual operations can mark segments as unused
8. Coordinator's kill task removes unused segments from deep storage

### Ingestion

Druid supports three primary ingestion methods:

**1. Streaming Ingestion (Kafka/Kinesis):**
```json
{
  "type": "kafka",
  "spec": {
    "ioConfig": {
      "type": "kafka",
      "consumerProperties": {
        "bootstrap.servers": "kafka-broker:9092"
      },
      "topic": "events",
      "inputFormat": { "type": "json" },
      "useEarliestOffset": true,
      "taskDuration": "PT1H",
      "completionTimeout": "PT30M"
    },
    "tuningConfig": {
      "type": "kafka",
      "maxRowsPerSegment": 5000000,
      "maxRowsInMemory": 1000000,
      "intermediatePersistPeriod": "PT10M"
    },
    "dataSchema": {
      "dataSource": "events",
      "timestampSpec": { "column": "timestamp", "format": "auto" },
      "dimensionsSpec": {
        "dimensions": [
          "event_type",
          { "type": "string", "name": "country" },
          { "type": "long", "name": "user_id" }
        ]
      },
      "granularitySpec": {
        "segmentGranularity": "HOUR",
        "queryGranularity": "MINUTE",
        "rollup": true
      },
      "metricsSpec": [
        { "type": "count", "name": "count" },
        { "type": "longSum", "name": "total_duration", "fieldName": "duration_ms" },
        { "type": "doubleSum", "name": "total_revenue", "fieldName": "revenue" },
        { "type": "HLLSketchBuild", "name": "unique_users", "fieldName": "user_id" }
      ]
    }
  }
}
```

**2. SQL-Based Batch Ingestion (MSQ Engine):**
```sql
-- INSERT: append data
INSERT INTO events
SELECT
  TIME_PARSE("timestamp") AS __time,
  event_type,
  country,
  user_id,
  duration_ms
FROM TABLE(
  EXTERN(
    '{"type":"s3","uris":["s3://bucket/data/events/*.json"]}',
    '{"type":"json"}',
    '[{"name":"timestamp","type":"string"},{"name":"event_type","type":"string"},
      {"name":"country","type":"string"},{"name":"user_id","type":"long"},
      {"name":"duration_ms","type":"long"}]'
  )
)
PARTITIONED BY DAY
CLUSTERED BY event_type;

-- REPLACE: overwrite a time range
REPLACE INTO events
OVERWRITE WHERE __time >= TIMESTAMP '2026-04-01' AND __time < TIMESTAMP '2026-04-08'
SELECT
  __time,
  event_type,
  country,
  COUNT(*) AS "count",
  SUM(duration_ms) AS total_duration
FROM events
WHERE __time >= TIMESTAMP '2026-04-01' AND __time < TIMESTAMP '2026-04-08'
GROUP BY 1, 2, 3
PARTITIONED BY DAY
CLUSTERED BY event_type;
```

**3. Classic Batch Ingestion (Parallel Index Task):**
- Native JSON-based ingestion specs submitted to the Overlord
- Supports local files, S3, GCS, HDFS, HTTP sources
- Parallel task with supervisor/worker model for scalability

### Druid SQL

Druid SQL translates SQL queries into native Druid queries via Apache Calcite:

```sql
-- Time-series aggregation
SELECT
  FLOOR(__time TO HOUR) AS "hour",
  COUNT(*) AS events,
  SUM(duration_ms) AS total_duration,
  APPROX_COUNT_DISTINCT_DS_HLL(user_id) AS unique_users
FROM events
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
GROUP BY 1
ORDER BY 1 DESC;

-- TopN-style query
SELECT
  country,
  COUNT(*) AS events,
  AVG(duration_ms) AS avg_duration
FROM events
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '7' DAY
  AND event_type = 'purchase'
GROUP BY country
ORDER BY events DESC
LIMIT 100;

-- Window functions (Druid 31+)
SELECT
  __time,
  event_type,
  duration_ms,
  AVG(duration_ms) OVER (
    PARTITION BY event_type
    ORDER BY __time
    ROWS BETWEEN 10 PRECEDING AND CURRENT ROW
  ) AS rolling_avg
FROM events
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR;

-- Multi-value dimension handling
SELECT
  MV_TO_ARRAY(tags) AS tag_array,
  COUNT(*) AS cnt
FROM events
WHERE MV_CONTAINS(tags, 'important')
GROUP BY 1;
```

### Native Queries

Druid's native query language is JSON over HTTP, posted to `/druid/v2`:

**Timeseries** -- fastest for time-bucketed aggregations without dimension grouping:
```json
{
  "queryType": "timeseries",
  "dataSource": "events",
  "intervals": ["2026-04-01/2026-04-08"],
  "granularity": "hour",
  "aggregations": [
    { "type": "count", "name": "events" },
    { "type": "longSum", "name": "total_duration", "fieldName": "duration_ms" }
  ]
}
```

**TopN** -- optimized for single-dimension top-k with aggregation:
```json
{
  "queryType": "topN",
  "dataSource": "events",
  "intervals": ["2026-04-01/2026-04-08"],
  "granularity": "all",
  "dimension": "country",
  "metric": "events",
  "threshold": 100,
  "aggregations": [
    { "type": "count", "name": "events" }
  ]
}
```

**GroupBy** -- most flexible, supports multi-dimension grouping:
```json
{
  "queryType": "groupBy",
  "dataSource": "events",
  "intervals": ["2026-04-01/2026-04-08"],
  "granularity": "day",
  "dimensions": ["event_type", "country"],
  "aggregations": [
    { "type": "count", "name": "events" },
    { "type": "HLLSketchMerge", "name": "unique_users", "fieldName": "unique_users" }
  ],
  "having": { "type": "greaterThan", "aggregation": "events", "value": 1000 }
}
```

**Scan** -- raw row retrieval without aggregation:
```json
{
  "queryType": "scan",
  "dataSource": "events",
  "intervals": ["2026-04-07/2026-04-08"],
  "columns": ["__time", "event_type", "country", "user_id"],
  "filter": { "type": "selector", "dimension": "event_type", "value": "error" },
  "limit": 1000
}
```

**Performance hierarchy:** Timeseries > TopN > GroupBy > Scan. Always use the most specific query type.

### Rollup (Pre-Aggregation)

Rollup collapses rows with identical dimension values and timestamp (at the query granularity) during ingestion:

```
-- Raw data (3 rows, same minute):
2026-04-07T10:05:23Z | click | US | user_42 | 150ms
2026-04-07T10:05:45Z | click | US | user_43 | 200ms
2026-04-07T10:05:59Z | click | US | user_42 | 100ms

-- After rollup with queryGranularity=MINUTE:
2026-04-07T10:05:00Z | click | US | 3 (count) | 450 (sum_duration) | 2 (HLL_users)
```

**Rollup configuration in ingestion spec:**
```json
{
  "granularitySpec": {
    "segmentGranularity": "DAY",
    "queryGranularity": "MINUTE",
    "rollup": true
  },
  "metricsSpec": [
    { "type": "count", "name": "count" },
    { "type": "longSum", "name": "total_duration", "fieldName": "duration_ms" },
    { "type": "HLLSketchBuild", "name": "unique_users", "fieldName": "user_id", "lgK": 12 }
  ]
}
```

**When to use rollup:**
- High-cardinality timestamp data where per-second granularity is unnecessary
- Aggregation-heavy query patterns (counts, sums, averages, distinct counts)
- Storage reduction is critical (rollup can reduce data 10-100x)

**When NOT to use rollup:**
- Need to query individual raw events (user sessions, transaction logs)
- All dimensions are high-cardinality (rollup provides little compression)
- Need exact distinct counts on non-sketch columns

### Data Modeling

**Dimensions vs. Metrics:**
- **Dimensions** -- Columns you filter and group by. String dimensions get dictionary encoding and bitmap indexes. Numeric dimensions are supported but lack bitmap indexes by default.
- **Metrics** -- Columns you aggregate. Can store raw values or pre-aggregated sketch objects (HLL, Theta, Quantile).
- **__time** -- The mandatory primary timestamp column. All data is partitioned by time.

**Schema design principles:**
1. **Minimize dimension cardinality** -- Lower cardinality = better rollup = smaller segments
2. **Use appropriate types** -- `long` for numeric IDs, `string` for categorical data, `double` for measurements
3. **Pre-aggregate with sketches** -- Use HLLSketchBuild for distinct counts, thetaSketchBuild for set operations, quantilesDoublesSketchBuild for percentiles
4. **Choose segment granularity wisely** -- HOUR for real-time streaming, DAY for batch, MONTH for low-volume or historical data
5. **Choose query granularity for rollup** -- MINUTE for operational dashboards, HOUR for trend analysis, DAY for executive reports

### Deep Storage and Metadata

**Deep storage** is the permanent home of segments. Supported backends:
- **S3** -- Most common in AWS deployments
- **HDFS** -- Common in Hadoop-adjacent environments
- **GCS** -- Google Cloud deployments
- **Azure Blob Storage** -- Azure deployments
- **Local filesystem** -- Development/testing only

**Metadata store** (MySQL, PostgreSQL, or Derby):
- Stores segment metadata (datasource, interval, version, dimensions, metrics, size)
- Stores ingestion task state and supervisor configuration
- Stores data source rules (retention, replication, tiering)
- Stores audit history and configuration

**ZooKeeper** (required for cluster coordination):
- Service discovery (nodes register themselves)
- Leader election (Coordinator, Overlord)
- Segment load/drop protocol between Coordinator and Historical
- Internal communication protocol

### Lookups

Lookups provide key-value dimension enrichment at query time:

```json
POST /druid/coordinator/v1/lookups/config
{
  "__default": {
    "country_names": {
      "version": "2026-04-07",
      "lookupExtractorFactory": {
        "type": "map",
        "map": { "US": "United States", "UK": "United Kingdom", "DE": "Germany" }
      }
    }
  }
}
```

```sql
-- Use lookup in SQL
SELECT
  LOOKUP(country_code, 'country_names') AS country_name,
  COUNT(*) AS events
FROM events
GROUP BY 1;
```

**Lookup types:**
- **Map** -- In-memory key-value from static map or URI (JSON/CSV/TSV)
- **Cached** -- Polled periodically from a remote source
- **JDBC** -- Loaded from a database table
- **Kafka** -- Continuously updated from a Kafka topic

### Approximate Algorithms

Druid provides extensions for approximate algorithms:

| Algorithm | Extension | Use Case | SQL Function |
|---|---|---|---|
| HyperLogLog (HLL) | druid-datasketches | Distinct count | `APPROX_COUNT_DISTINCT_DS_HLL()` |
| Theta Sketch | druid-datasketches | Distinct count + set operations | `APPROX_COUNT_DISTINCT_DS_THETA()` |
| Quantiles (KLL) | druid-datasketches | Percentiles, histograms | `DS_QUANTILES_SKETCH()` |
| Tuple Sketch | druid-datasketches | Distinct + associated values | `DS_TUPLE_DOUBLES()` |
| Bloom Filter | druid-bloom-filter | Membership testing | `BLOOM_FILTER()` |

**HLL vs. Theta Sketch:**
- HLL: more space-efficient (~2% error), no set operations
- Theta: supports union/intersection/difference, slightly higher memory, ~3% error

### Compaction

Compaction rewrites existing segments to optimize them:

```json
POST /druid/coordinator/v1/compaction/config
{
  "dataSource": "events",
  "taskPriority": 25,
  "inputSegmentSizeBytes": 419430400,
  "maxRowsPerSegment": 5000000,
  "skipOffsetFromLatest": "PT1H",
  "tuningConfig": {
    "type": "index_parallel",
    "maxRowsInMemory": 1000000,
    "partitionsSpec": {
      "type": "hashed",
      "numShards": null,
      "partitionDimensions": ["event_type"]
    }
  },
  "granularitySpec": {
    "segmentGranularity": "DAY",
    "queryGranularity": "MINUTE"
  }
}
```

**Compaction benefits:**
- Merge small segments into optimally-sized ones (3-5M rows)
- Change partition scheme (dynamic to hash/range for perfect rollup)
- Add or change rollup (apply aggregation to older data)
- Change segment granularity (e.g., HOUR to DAY for cold data)
- Reorder dimensions for better compression
- Remove unused columns

### Query Caching

Druid supports multiple cache layers:
- **Broker-level result cache** -- Caches per-segment query results at the Broker
- **Historical-level segment cache** -- Caches per-segment results on the data node
- **Whole-query result cache** -- Caches entire query results (Druid 0.20+)

```properties
# Broker cache (common.runtime.properties)
druid.broker.cache.useCache=true
druid.broker.cache.populateCache=true
druid.cache.type=caffeine
druid.cache.sizeInBytes=2000000000

# Historical cache
druid.historical.cache.useCache=true
druid.historical.cache.populateCache=true
druid.cache.type=caffeine
druid.cache.sizeInBytes=5000000000
```

### Multi-Value Dimensions

Druid natively supports multi-value string dimensions (arrays of values per row):

```sql
-- Filter by any value in a multi-value dimension
SELECT * FROM events WHERE MV_CONTAINS(tags, 'urgent');

-- Expand multi-value dimensions
SELECT tag, COUNT(*) FROM events CROSS JOIN UNNEST(MV_TO_ARRAY(tags)) AS t(tag) GROUP BY 1;

-- Filter and aggregate
SELECT
  MV_FILTER_ONLY(tags, ARRAY['error', 'warning']) AS filtered_tags,
  COUNT(*)
FROM events
GROUP BY 1;
```

## Troubleshooting Playbooks

### Ingestion Lag (Kafka/Kinesis)

**Symptom:** Supervisor reports increasing lag, data is delayed.

**Diagnostic:**
```sql
SELECT * FROM sys.supervisors;
```
```
GET /druid/indexer/v1/supervisor/<supervisorId>/stats
```

**Resolution:**
1. **Check task count** -- Increase `taskCount` in supervisor spec to parallelize consumption
2. **Check task duration** -- Reduce `taskDuration` (e.g., PT30M) for faster handoff
3. **Check persist settings** -- Increase `maxRowsInMemory` or reduce `intermediatePersistPeriod` to avoid excessive disk I/O
4. **Check consumer lag** -- Verify Kafka/Kinesis throughput matches task capacity
5. **Check segment handoff** -- If Historical nodes are slow to load, check deep storage write speed and Coordinator load queue
6. **Scale MiddleManagers** -- Add capacity if CPU/memory is saturated on ingestion nodes

### Segment Unavailable

**Symptom:** Queries return partial results or "segment not found" errors.

**Diagnostic:**
```sql
SELECT datasource, is_published, is_available, is_realtime, is_overshadowed, COUNT(*) AS cnt
FROM sys.segments
GROUP BY 1, 2, 3, 4, 5;
```
```
GET /druid/coordinator/v1/loadstatus?simple
GET /druid/coordinator/v1/loadqueue?simple
```

**Resolution:**
1. **Check Coordinator logs** -- Look for "unable to assign segment" messages
2. **Check Historical capacity** -- `maxSize` may be reached; add nodes or increase disk
3. **Check deep storage** -- Segments may be missing from S3/HDFS; verify paths
4. **Check load rules** -- Ensure retention rules include the time range and replica count
5. **Check metadata store** -- Verify segments are marked as `used=1` in the `druid_segments` table
6. **Force load** -- `POST /druid/coordinator/v1/datasources/<ds>/segments/<segmentId>`

### Query Timeout

**Symptom:** Queries fail with timeout or take excessively long.

**Diagnostic:**
```sql
SELECT * FROM sys.segments
WHERE datasource = 'events'
  AND is_available = 1
ORDER BY num_rows DESC;
```

**Resolution:**
1. **Check segment sizes** -- Segments with >10M rows need compaction
2. **Add query filters** -- Always filter on `__time` to limit segment scan range
3. **Use appropriate query type** -- Timeseries/TopN instead of GroupBy when possible
4. **Increase timeout** -- `druid.server.http.defaultQueryTimeout` (but fix root cause)
5. **Scale Broker/Historical** -- Add nodes for query parallelism
6. **Enable caching** -- Configure Broker and Historical cache for repeated queries
7. **Check for excessive subqueries** -- Druid SQL can generate subqueries; use EXPLAIN PLAN

### Out of Memory (OOM)

**Symptom:** Historical or Broker JVM crashes with OutOfMemoryError.

**Resolution:**
1. **Increase JVM heap** -- Historical: 50% of RAM for heap, 50% for direct memory + OS cache
2. **Tune processing buffers** -- `druid.processing.buffer.sizeBytes` and `druid.processing.numThreads`
3. **Limit concurrent queries** -- `druid.server.http.numThreads`
4. **Reduce groupBy memory** -- `druid.query.groupBy.maxOnDiskStorage` to spill to disk
5. **Check segment sizes** -- Oversized segments consume more memory during query processing
6. **Monitor JVM** -- Enable GC logging, use `-XX:+HeapDumpOnOutOfMemoryError`

**Memory formula for Historical:**
```
Total RAM = JVM Heap + Direct Memory + OS page cache reserve
JVM Heap = 50% of RAM (max ~24GB recommended)
Direct Memory = processing.buffer.sizeBytes * (processing.numThreads + 1)
OS Page Cache = remaining RAM (caches segment data)
```

### Compaction Debt

**Symptom:** Increasing number of small segments, degraded query performance.

**Diagnostic:**
```sql
SELECT datasource, COUNT(*) AS segments,
  AVG(num_rows) AS avg_rows, MIN(num_rows) AS min_rows
FROM sys.segments
WHERE is_published = 1 AND is_overshadowed = 0
GROUP BY 1
ORDER BY segments DESC;
```
```
GET /druid/coordinator/v1/compaction/status
```

**Resolution:**
1. **Configure auto-compaction** -- Set up compaction config per datasource
2. **Increase compaction slots** -- `druid.coordinator.compaction.maxCompactionTaskSlots`
3. **Use MSQ compaction** -- Set `engine: msq` for faster compaction (31+)
4. **Adjust skip offset** -- `skipOffsetFromLatest` to compact closer to real-time data
5. **Tune partition spec** -- Use hash or range partitioning for perfect rollup
6. **Monitor** -- Track compaction status via REST API and Coordinator console

## Version Matrix

| Version | Release Date | Status (April 2026) | Key Features |
|---|---|---|---|
| 36.0.0 | Feb 2026 | Current | Cost-based autoscaling, V10 segment format, cgroup v2, Dart query reports |
| 35.0.1 | Dec 2025 | Supported | Performance improvements, stability fixes |
| 34.0.0 | Aug 2025 | Supported | Various enhancements |
| 33.0.0 | Apr 2025 | Supported | Stability and performance |
| 32.0.1 | Mar 2025 | Supported | Enhancements and fixes |
| 31.0.2 | Mar 2025 | Supported | Dart engine, projections, concurrent append/replace GA, MSQ window functions |

**Versioning convention:** Druid uses major.minor.patch semantic versioning. Each major release may contain breaking changes. Patch releases contain only bug fixes.

**Recommendation:** Use the latest stable release (36.0.0) for production. For organizations requiring proven stability, 35.0.x or 34.0.0 are solid choices. Version 31.x introduced foundational features (Dart, projections) that continue to mature in later releases.
