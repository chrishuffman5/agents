# Apache Druid Best Practices Reference

## Schema Design

### Timestamp and Granularity

The `__time` column is mandatory and is the foundation of all Druid data layout:

**segmentGranularity** -- Time range each segment covers:
| Data Rate | segmentGranularity | Rationale |
|---|---|---|
| < 1M rows/day | MONTH or WEEK | Avoid tiny segments |
| 1M-100M rows/day | DAY | Standard choice |
| 100M-1B rows/day | DAY or HOUR | Keep segments under 5M rows |
| > 1B rows/day | HOUR | Avoid oversized segments |
| Real-time streaming | HOUR | Balance freshness vs. segment count |

**queryGranularity** -- Finest time resolution stored (affects rollup):
| Use Case | queryGranularity | Rationale |
|---|---|---|
| Operational dashboards | MINUTE | Second-level is rarely needed |
| Trend analysis | FIVE_MINUTE or FIFTEEN_MINUTE | Reduce row count further |
| Daily reports | HOUR | Aggressive rollup for historical data |
| Raw event access | NONE | No rollup, preserve original timestamps |

**Anti-patterns:**
- `segmentGranularity: MINUTE` -- Creates thousands of segments per day, overwhelming Coordinator
- `queryGranularity: NONE` with rollup enabled -- Pointless; rollup only works when queryGranularity truncates timestamps
- `segmentGranularity: ALL` -- Single segment for all time, cannot partition-drop old data

### Dimension Design

**String dimensions (most common):**
```json
{
  "dimensionsSpec": {
    "dimensions": [
      "event_type",
      "country",
      { "type": "string", "name": "browser", "multiValueHandling": "SORTED_ARRAY" },
      { "type": "string", "name": "url", "createBitmapIndex": false }
    ]
  }
}
```

**Design rules:**
1. **Low-cardinality strings** -- Always use as dimensions; excellent rollup and fast bitmap filtering
2. **High-cardinality strings** (URLs, user agents) -- Consider disabling bitmap indexes (`createBitmapIndex: false`) to save storage; bitmap indexes on high-cardinality columns are large and rarely useful
3. **Numeric dimensions** -- Use `long` or `double` type; bitmap indexes are NOT created for numeric dimensions by default
4. **Multi-value dimensions** -- Supported for string type; enable with `multiValueHandling: SORTED_ARRAY`

**Dimension ordering matters for compression:**
- Place low-cardinality dimensions first in the dimensionsSpec
- This improves dictionary encoding efficiency within segments
- Consider using `CLUSTERED BY` in MSQ ingestion for explicit ordering

### Metric Design

**Choose appropriate aggregators:**
```json
{
  "metricsSpec": [
    { "type": "count", "name": "count" },
    { "type": "longSum", "name": "total_duration", "fieldName": "duration_ms" },
    { "type": "doubleSum", "name": "total_revenue", "fieldName": "revenue" },
    { "type": "doubleMin", "name": "min_latency", "fieldName": "latency_ms" },
    { "type": "doubleMax", "name": "max_latency", "fieldName": "latency_ms" },
    { "type": "HLLSketchBuild", "name": "unique_users", "fieldName": "user_id", "lgK": 12 },
    { "type": "quantilesDoublesSketch", "name": "latency_dist", "fieldName": "latency_ms", "k": 128 },
    { "type": "thetaSketch", "name": "unique_sessions", "fieldName": "session_id", "size": 16384 }
  ]
}
```

**Sketch sizing guidelines:**
| Sketch | Parameter | Default | Accuracy | Memory per Sketch |
|---|---|---|---|---|
| HLLSketch | lgK | 12 | ~1.6% error | ~4 KB |
| ThetaSketch | size | 16384 | ~1.6% error | ~128 KB |
| QuantilesDoublesSketch | k | 128 | ~1.7% rank error | ~2 KB |

**When to pre-aggregate vs. store raw:**
- **Pre-aggregate (rollup):** When you always query aggregated results (dashboards, reports)
- **Store raw:** When you need individual event access (debugging, session replay, compliance)
- **Hybrid:** Use rollup for recent data, raw archive in a separate datasource

### Rollup Strategy

**Best-effort rollup (streaming ingestion):**
- Streaming tasks produce segments incrementally
- Rollup happens within each persisted batch, not globally
- Duplicate dimension combinations across batches are NOT merged until compaction
- Compaction with hash partitioning achieves perfect rollup

**Perfect rollup (batch ingestion):**
```json
{
  "tuningConfig": {
    "type": "index_parallel",
    "partitionsSpec": {
      "type": "hashed",
      "numShards": null,
      "partitionDimensions": ["event_type", "country"]
    },
    "forceGuaranteedRollup": true,
    "maxNumConcurrentSubTasks": 8
  }
}
```

Or via MSQ:
```sql
INSERT INTO events_rolled_up
SELECT
  FLOOR(__time TO HOUR) AS __time,
  event_type,
  country,
  COUNT(*) AS "count",
  SUM(duration_ms) AS total_duration,
  APPROX_COUNT_DISTINCT_DS_HLL(user_id) AS unique_users
FROM events_raw
WHERE __time >= TIMESTAMP '2026-04-01' AND __time < TIMESTAMP '2026-04-08'
GROUP BY 1, 2, 3
PARTITIONED BY DAY
CLUSTERED BY event_type;
```

## Ingestion Optimization

### Kafka Supervisor Tuning

**Key supervisor spec parameters:**
```json
{
  "type": "kafka",
  "spec": {
    "ioConfig": {
      "taskCount": 4,
      "replicas": 1,
      "taskDuration": "PT1H",
      "completionTimeout": "PT30M",
      "useEarliestOffset": true,
      "idleConfig": {
        "enabled": true,
        "inactiveAfterMillis": 600000
      }
    },
    "tuningConfig": {
      "maxRowsInMemory": 1000000,
      "maxBytesInMemory": 0,
      "maxRowsPerSegment": 5000000,
      "maxTotalRows": 20000000,
      "intermediatePersistPeriod": "PT10M",
      "indexSpec": {
        "bitmap": { "type": "roaring" },
        "dimensionCompression": "lz4",
        "metricCompression": "lz4",
        "longEncoding": "auto"
      }
    }
  }
}
```

**Tuning for throughput:**
| Parameter | Guideline | Impact |
|---|---|---|
| `taskCount` | Match Kafka partition count (or fraction) | More tasks = more parallelism |
| `replicas` | 1 for most cases, 2 for critical pipelines | Redundancy vs. resource cost |
| `taskDuration` | PT30M to PT2H | Shorter = faster segment availability, more overhead |
| `maxRowsInMemory` | 500K-2M depending on row width | Higher = better rollup, more memory |
| `intermediatePersistPeriod` | PT10M-PT30M | Shorter = less data loss on crash, more I/O |
| `maxRowsPerSegment` | 3M-5M | Target segment size |

**Tuning for latency (minimize time to queryable):**
- Reduce `taskDuration` to PT10M-PT30M
- Reduce `completionTimeout` to PT10M
- Ensure Historical nodes have capacity to load new segments quickly
- Consider `druid.coordinator.period=PT10S` for faster segment assignment

### Batch Ingestion Best Practices

**MSQ-based (recommended for Druid 25+):**
```sql
-- Use PARTITIONED BY for time partitioning
-- Use CLUSTERED BY for secondary partitioning (hash-based)
INSERT INTO events_daily
SELECT
  TIME_PARSE("timestamp") AS __time,
  event_type,
  country,
  COUNT(*) AS "count",
  SUM(duration_ms) AS total_duration
FROM TABLE(EXTERN(...))
GROUP BY 1, 2, 3
PARTITIONED BY DAY
CLUSTERED BY event_type, country;
```

**MSQ tuning parameters:**
```sql
-- Control parallelism and memory
INSERT INTO ...
SELECT ... FROM ...
PARTITIONED BY DAY
CLUSTERED BY event_type
-- Context parameters:
-- maxNumTasks: 10          -- max worker tasks
-- rowsPerSegment: 5000000  -- target rows per segment
-- taskAssignment: auto     -- or 'max' for maximum parallelism
```

### Compaction Configuration

**Auto-compaction (recommended):**
```json
POST /druid/coordinator/v1/compaction/config
{
  "dataSource": "events",
  "taskPriority": 25,
  "skipOffsetFromLatest": "PT1H",
  "maxRowsPerSegment": 5000000,
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
  },
  "engine": "msq"
}
```

**Compaction best practices:**
1. **Set `skipOffsetFromLatest`** -- Avoid compacting segments still being written by streaming tasks (default PT24H; reduce for faster compaction)
2. **Use MSQ engine** -- `"engine": "msq"` is significantly faster than native compaction (31+)
3. **Target perfect rollup** -- Use hashed partitioning with `partitionDimensions` for maximum compression
4. **Schedule during off-peak** -- Compaction competes with ingestion for task slots
5. **Monitor compaction debt** -- Track segments below optimal size via Coordinator API
6. **Change granularity** -- Compact HOUR segments into DAY segments for older data

## Query Optimization

### Filter Optimization

**Filters that use bitmap indexes (fast):**
```sql
-- Equality (bitmap lookup)
WHERE event_type = 'click'

-- IN clause (bitmap OR)
WHERE country IN ('US', 'UK', 'DE')

-- Bound (range on dictionary-encoded strings)
WHERE city >= 'A' AND city < 'N'
```

**Filters that do NOT use bitmap indexes (slower):**
```sql
-- Numeric range (no bitmap by default)
WHERE user_id > 1000 AND user_id < 2000

-- LIKE with leading wildcard
WHERE url LIKE '%/checkout%'

-- Regular expression
WHERE path REGEXP '.*api/v[0-9]+.*'

-- JavaScript filter (slowest, avoid)
WHERE CAST(custom_field AS DOUBLE) > 100.0
```

**Optimization strategies:**
1. **Always filter on `__time`** -- This is the primary partitioning dimension; without it, all segments are scanned
2. **Use equality/IN on dimensions** -- Leverages bitmap indexes
3. **Pre-filter before aggregation** -- Use WHERE, not HAVING, for dimension filters
4. **Avoid high-cardinality IN lists** -- Hundreds of values in IN() degrades to near-scan performance
5. **Consider datasketches for approximate filtering** -- Bloom filters for membership testing

### GroupBy Optimization

```sql
-- GOOD: Small number of dimensions, filtered
SELECT
  event_type,
  FLOOR(__time TO HOUR) AS hour,
  COUNT(*) AS events
FROM events
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
  AND country = 'US'
GROUP BY 1, 2;

-- CAUTION: High-cardinality groupBy
SELECT
  user_id,         -- millions of distinct values
  COUNT(*) AS events
FROM events
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '7' DAY
GROUP BY 1
ORDER BY events DESC
LIMIT 100;
-- Consider: Use TopN query type or Dart engine for this pattern
```

**GroupBy tuning:**
```properties
# Allow groupBy to spill to disk (prevent OOM)
druid.query.groupBy.maxOnDiskStorage=1073741824          # 1GB spill space

# GroupBy merge buffer sizing
druid.processing.numMergeBuffers=2
druid.processing.buffer.sizeBytes=536870912              # 512MB

# For v2 groupBy engine
druid.query.groupBy.maxMergingDictionarySize=100000000   # 100MB dictionary per query
druid.query.groupBy.maxSelectorDictionarySize=100000000  # 100MB selector dictionary
```

### Using Approximate Algorithms

**Distinct count (HLL vs. exact):**
```sql
-- Approximate: fast, ~1.6% error (RECOMMENDED for dashboards)
SELECT APPROX_COUNT_DISTINCT_DS_HLL(user_id) AS unique_users FROM events;

-- Approximate: Theta sketch with set operations
SELECT
  THETA_SKETCH_ESTIMATE(
    THETA_SKETCH_INTERSECT(
      DS_THETA(user_id) FILTER(WHERE event_type = 'view'),
      DS_THETA(user_id) FILTER(WHERE event_type = 'purchase')
    )
  ) AS users_who_viewed_and_purchased
FROM events;

-- Exact: slower, use only when precision is critical
SELECT COUNT(DISTINCT user_id) AS exact_unique_users FROM events;
```

**Percentiles (quantile sketches):**
```sql
-- Approximate percentiles (RECOMMENDED)
SELECT
  DS_QUANTILES_SKETCH(latency_ms, 128) AS latency_sketch,
  APPROX_QUANTILE_DS(latency_ms, 0.50) AS p50,
  APPROX_QUANTILE_DS(latency_ms, 0.95) AS p95,
  APPROX_QUANTILE_DS(latency_ms, 0.99) AS p99
FROM events
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR;
```

### Lookup Optimization

```properties
# Lookup configuration (common.runtime.properties)
druid.lookup.enableLookupSyncOnStartup=true
druid.lookup.numLookupLoadingThreads=2
druid.lookup.coordinatorFetchRetries=3
```

**Lookup types comparison:**
| Type | Latency | Memory | Update Frequency | Use Case |
|---|---|---|---|---|
| Map (static) | Microseconds | Full dataset in RAM | On redeploy | Small, rarely changing |
| Cached (URI) | Microseconds | Full dataset in RAM | Polled (configurable) | Medium, periodic updates |
| JDBC | Microseconds | Full dataset in RAM | Polled | Database-sourced |
| Kafka | Microseconds | Full dataset in RAM | Real-time | Continuously changing |

**Best practices:**
- Keep lookups under 100K entries for optimal memory usage
- For larger lookups, consider pre-joining during ingestion instead
- Monitor lookup memory with `druid.lookup.cache.type=caffeine` and size limits
- Use `LOOKUP()` function in SQL for dimension enrichment instead of JOINs

## Cluster Operations

### Hardware Sizing

**Historical node (query serving):**
| Cluster Size | CPU | RAM | Storage | Network |
|---|---|---|---|---|
| Small (< 1 TB) | 8 cores | 32 GB | 500 GB SSD | 1 Gbps |
| Medium (1-10 TB) | 16-32 cores | 64-128 GB | 2-4 TB NVMe | 10 Gbps |
| Large (10-100 TB) | 32-64 cores | 128-256 GB | 4-16 TB NVMe | 25 Gbps |

**MiddleManager node (ingestion):**
| Workload | CPU | RAM | Storage | Tasks/Node |
|---|---|---|---|---|
| Light | 8 cores | 32 GB | 500 GB SSD | 2-4 |
| Heavy | 16-32 cores | 64-128 GB | 1-2 TB NVMe | 8-16 |

**Broker node (query routing):**
| Concurrency | CPU | RAM | Storage |
|---|---|---|---|
| < 50 qps | 8 cores | 32 GB | Minimal |
| 50-200 qps | 16 cores | 64 GB | Minimal |
| > 200 qps | 32 cores | 128 GB | Minimal |

**Master node (Coordinator + Overlord):**
- 4-8 cores, 16-32 GB RAM
- Minimal storage (metadata in external DB)
- Scale by datasource count, not data volume

### JVM Configuration

**Historical (64 GB RAM):**
```bash
-server
-Xms24g -Xmx24g
-XX:MaxDirectMemorySize=8g
-XX:+UseG1GC
-XX:+ExitOnOutOfMemoryError
-Duser.timezone=UTC
-Dfile.encoding=UTF-8
-Djava.io.tmpdir=/tmp/druid
-Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager
```

**Broker (32 GB RAM):**
```bash
-server
-Xms16g -Xmx16g
-XX:MaxDirectMemorySize=4g
-XX:+UseG1GC
-XX:+ExitOnOutOfMemoryError
-Duser.timezone=UTC
```

**MiddleManager (64 GB RAM, 8 task slots):**
```bash
# MiddleManager JVM (lightweight)
-server
-Xms128m -Xmx128m

# Peon JVM (per task, allocated via druid.indexer.fork.property)
druid.indexer.fork.property.druid.processing.buffer.sizeBytes=256000000
druid.indexer.fork.property.druid.processing.numThreads=2
# Each Peon: -Xms2g -Xmx2g typically
```

### Security Configuration

**Authentication (basic):**
```properties
druid.auth.authenticatorChain=["basic"]
druid.auth.authenticator.basic.type=basic
druid.auth.authenticator.basic.initialAdminPassword=admin_password
druid.auth.authenticator.basic.initialInternalClientPassword=internal_password
druid.auth.authenticator.basic.credentialsValidator.type=metadata
```

**Authorization (basic):**
```properties
druid.auth.authorizers=["basic"]
druid.auth.authorizer.basic.type=basic
```

**TLS/SSL:**
```properties
druid.server.https.port=8281
druid.server.https.keyStorePath=/path/to/keystore.jks
druid.server.https.keyStorePassword=changeit
druid.server.https.certAlias=druid
druid.client.https.protocol=TLSv1.2
druid.client.https.trustStorePath=/path/to/truststore.jks
```

### Backup and Recovery

**Druid is designed for resilience through redundancy:**

1. **Deep storage is the backup** -- All published segments exist in deep storage (S3/HDFS/GCS)
2. **Metadata store backup** -- Back up MySQL/PostgreSQL metadata regularly
3. **Recovery from total loss:**
   - Restore metadata store from backup
   - Start Coordinator/Overlord -- they will rebuild cluster state from metadata
   - Start Historical nodes -- they will re-download segments from deep storage
   - Restart supervisors -- they will resume from last committed offsets

**Metadata backup:**
```bash
# MySQL metadata backup
mysqldump -u druid -p druid_metadata > druid_metadata_backup.sql

# PostgreSQL metadata backup
pg_dump -U druid druid_metadata > druid_metadata_backup.sql
```

### Rolling Upgrade Procedure

1. **Pre-upgrade checks:**
   ```
   GET /druid/coordinator/v1/loadstatus?simple
   GET /druid/indexer/v1/supervisor?state=true
   ```

2. **Upgrade order:** Historical -> MiddleManager -> Broker -> Router -> Coordinator -> Overlord

3. **Per-node process:**
   ```bash
   # Graceful shutdown
   curl -X POST http://node:port/druid/admin/shutdown
   # Wait for process to stop
   # Install new version
   # Start process
   # Verify health
   curl http://node:port/status/health
   ```

4. **Post-upgrade verification:**
   - Check all nodes are healthy
   - Verify segment loading is complete
   - Verify supervisors are RUNNING
   - Run sample queries

## Common Anti-Patterns

### 1. Too Many Small Segments

**Problem:** Streaming ingestion with short taskDuration and low volume creates thousands of tiny segments.
**Solution:** Increase taskDuration, configure auto-compaction, use appropriate segmentGranularity.

### 2. Wrong Query Type

**Problem:** Using GroupBy for simple time-series aggregation.
**Solution:** Druid SQL auto-selects optimal query type, but verify with EXPLAIN PLAN. For native queries, use Timeseries when no dimension grouping, TopN for single-dimension top-k.

### 3. No Time Filter

**Problem:** Queries without `__time` filter scan all segments.
**Solution:** Always include `WHERE __time >= ... AND __time < ...` in queries.

### 4. Over-Dimensioning

**Problem:** Including high-cardinality fields as dimensions destroys rollup effectiveness.
**Solution:** Only include fields you actually filter/group by as dimensions. Store high-cardinality identifiers as metrics with sketch aggregators, or in a separate raw datasource.

### 5. Lookup Tables Too Large

**Problem:** Loading multi-million-row lookup tables into every node's memory.
**Solution:** Pre-join during ingestion for large dimensions. Reserve lookups for small reference data (<100K entries).

### 6. Ignoring Compaction

**Problem:** Never compacting streaming-ingested data leads to suboptimal segment sizes and best-effort rollup.
**Solution:** Configure auto-compaction with hash partitioning for perfect rollup after data is stable.

### 7. Single MiddleManager for Streaming

**Problem:** All Kafka ingestion tasks on one MiddleManager; if it fails, all ingestion stops.
**Solution:** Run multiple MiddleManagers with task capacity distributed across them. Use replicas > 1 for critical pipelines.

### 8. Missing Bitmap Index Optimization

**Problem:** Bitmap indexes on very high-cardinality columns (UUIDs, URLs) waste storage and slow ingestion.
**Solution:** Set `createBitmapIndex: false` for columns with >100K distinct values that are rarely filtered on.

## Monitoring Checklist

**Critical alerts:**
| Metric | Threshold | Impact |
|---|---|---|
| Segments unavailable | Any | Partial query results |
| Supervisor state != RUNNING | Any | Ingestion stopped |
| Task failure rate | > 10% | Data loss risk |
| Ingestion lag | > 5 minutes | Stale data |
| Historical disk usage | > 85% | Segment eviction |
| JVM heap usage | > 85% sustained | OOM risk |

**Warning alerts:**
| Metric | Threshold | Impact |
|---|---|---|
| Compaction debt segments | > 100 | Degraded query performance |
| Query latency p99 | > 10s | User experience |
| Coordinator load queue | > 100 segments | Slow segment availability |
| Pending tasks | > 50 | Ingestion bottleneck |
| ZooKeeper session expired | Any | Cluster coordination issue |
