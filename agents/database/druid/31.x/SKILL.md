---
name: database-druid-31x
description: "Apache Druid 31.x version expert. Covers Dart query engine, projections, concurrent append and replace GA, MSQ window functions, compaction scheduler, flexible segment sorting, and compressed complex columns. WHEN: \"Druid 31\", \"Druid 31.0\", \"Druid 31.x\", \"Dart engine Druid\", \"Druid projections\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Apache Druid 31.x Version Expert

You are a specialist in Apache Druid 31.x (31.0.0 released Q4 2024, patch 31.0.2 released March 2025). This release introduced major new capabilities including the Dart query engine, projections, concurrent append and replace going GA, and significant storage improvements.

## Key Features in Druid 31.x

### Dart Query Engine (Distributed Asynchronous Runtime Topology)

Dart is a new query engine designed for high-complexity analytical queries that previously required external engines like Spark or Presto:

**Capabilities:**
- Large multi-table JOINs with disk-based shuffle
- High-cardinality GROUP BY queries
- Complex subqueries and common table expressions (CTEs)
- Multi-threaded workers running on Historical nodes
- In-memory shuffles with locally cached segment access
- No deep storage reads during query execution

**Enabling Dart:**
```sql
-- Per-query via context
SET queryEngine = 'dart';
SELECT a.event_type, b.country_name, COUNT(*)
FROM events a
JOIN country_dim b ON a.country_code = b.code
WHERE a.__time >= CURRENT_TIMESTAMP - INTERVAL '7' DAY
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 1000;
```

**When to use Dart vs. native queries:**
| Scenario | Engine | Rationale |
|---|---|---|
| Simple aggregation | Native (Broker) | Sub-second, bitmap-optimized |
| TopN on single dimension | Native (Broker) | Optimized TopN algorithm |
| Multi-table JOIN | Dart | Distributed join execution |
| High-cardinality GROUP BY | Dart | Spill-to-disk support |
| Complex subqueries/CTEs | Dart | Multi-stage planning |
| Batch ingestion | MSQ | INSERT/REPLACE support |

**Dart limitations in 31.x:**
- Experimental status; not recommended for all production workloads
- Query reports not yet available (added in 36.x)
- Resource management is evolving

### Projections

Projections are pre-computed grouped aggregates stored within segments:

```json
{
  "dataSchema": {
    "dataSource": "events",
    "projections": [
      {
        "name": "hourly_by_country",
        "granularity": { "type": "period", "period": "PT1H" },
        "virtualColumns": [],
        "dimensions": [
          { "type": "default", "name": "country", "outputType": "STRING" }
        ],
        "aggregators": [
          { "type": "count", "name": "__count" },
          { "type": "longSum", "name": "total_duration", "fieldName": "duration_ms" },
          { "type": "HLLSketchBuild", "name": "unique_users", "fieldName": "user_id" }
        ]
      }
    ]
  }
}
```

**How projections work:**
1. During ingestion, data is aggregated into the projection shape alongside the raw segment data
2. At query time, the query planner checks if a projection can satisfy the query
3. If a projection matches, the query reads from the pre-aggregated data (far fewer rows)
4. Both MSQ and Dart engines can utilize projections

**Projection limitations in 31.x:**
- Only supported via JSON-based ingestion specs (not SQL-based MSQ ingestion)
- Cannot be added to existing segments (only during initial ingestion)
- Experimental status

### Concurrent Append and Replace (GA)

This feature is now generally available in 31.x. It allows streaming ingestion (append) to continue while batch compaction or re-ingestion (replace) operates on the same datasource:

**Previous behavior:** Compaction locked time chunks, blocking streaming ingestion for those intervals.

**31.x behavior:** Streaming tasks and compaction tasks can operate concurrently on overlapping time ranges. The system reconciles appended data after the replace completes.

**Configuration:**
```json
{
  "type": "kafka",
  "spec": {
    "ioConfig": {
      "appendToExisting": true
    },
    "tuningConfig": {
      "useConcurrentLocks": true
    }
  }
}
```

### MSQ Window Functions

Druid 31.x adds support for SQL window functions in the MSQ query engine, addressing all known correctness issues from previous versions:

```sql
-- Window functions with MSQ
SELECT
  __time,
  event_type,
  duration_ms,
  ROW_NUMBER() OVER (PARTITION BY event_type ORDER BY __time) AS row_num,
  SUM(duration_ms) OVER (PARTITION BY event_type ORDER BY __time ROWS BETWEEN 10 PRECEDING AND CURRENT ROW) AS rolling_sum,
  AVG(duration_ms) OVER (PARTITION BY event_type) AS avg_duration
FROM events
WHERE __time >= TIMESTAMP '2026-04-01' AND __time < TIMESTAMP '2026-04-08';
```

**Supported window functions:**
- `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`
- `LAG()`, `LEAD()`
- `FIRST_VALUE()`, `LAST_VALUE()`
- `SUM()`, `AVG()`, `COUNT()`, `MIN()`, `MAX()` as window aggregates
- `NTILE()`, `PERCENT_RANK()`, `CUME_DIST()`

### Compaction Scheduler

31.x introduces a more flexible compaction scheduler with greater control:

```json
{
  "dataSource": "events",
  "engine": "msq",
  "taskPriority": 25,
  "skipOffsetFromLatest": "PT1H",
  "maxRowsPerSegment": 5000000,
  "ioConfig": {
    "allowNonAlignedInterval": false
  }
}
```

**MSQ-based compaction** (`"engine": "msq"`):
- Significantly faster than native compaction
- Better memory management with disk-based shuffle
- Supports larger compaction jobs
- Recommended for production use in 31.x+

### Storage Improvements

**Compressed complex columns:**
- Complex metric columns (sketches, etc.) can now be compressed
- Reduces segment size for datasources with many sketch metrics
- Enable: included by default in 31.x

**Flexible segment sorting:**
- Segments can be sorted by columns in a different order than the `dimensionsSpec`
- Improves query performance for secondary access patterns without projections

**Warning:** Both features create segments that are NOT backward-compatible with Druid versions earlier than 31.0.0. Do not downgrade after enabling.

## Upgrade Notes for 31.x

### Breaking Changes

1. **Firehose removal** -- Firehose and FirehoseFactory implementations are completely removed. Migrate to inputSource-based ingestion.
2. **Segment format** -- Compressed complex columns and flexible sorting create non-backward-compatible segments.
3. **API changes** -- Some deprecated API endpoints may be removed; check release notes.

### Migration Checklist

1. Verify all ingestion specs use `inputSource` (not firehose)
2. Test compaction with MSQ engine in staging
3. Enable concurrent append/replace for streaming datasources
4. Test Dart engine for complex analytical queries
5. After upgrade, do NOT attempt to downgrade below 31.0.0 if new segment features are used
6. Apply patch 31.0.2 for fixes to topN queries, complex column compression, and projection correctness

### Recommended Patch Version

**Use 31.0.2** (March 2025) -- fixes critical issues:
- TopN query correctness when using query granularity other than ALL
- Complex metric column compression bugs
- Web console fixes
- Projection feature fixes
- Minor performance regression fix
