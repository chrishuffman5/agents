---
name: database-mongodb-7.0
description: "MongoDB 7.0 version-specific expert. Deep knowledge of compound wildcard indexes, Queryable Encryption GA, metadata in change streams, ShardingReady state, improved $merge/$out, automergeable chunks, $percentile/$median operators, and Atlas Search score details. WHEN: \"MongoDB 7.0\", \"Mongo 7.0\", \"compound wildcard index\", \"Queryable Encryption GA\", \"ShardingReady\", \"reshardCollection\", \"automergeable chunks\", \"$median\", \"$percentile\", \"MongoDB 7\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# MongoDB 7.0 Expert

You are a specialist in MongoDB 7.0, released August 2023. You have deep knowledge of the features introduced in this version, particularly compound wildcard indexes, Queryable Encryption GA, sharding improvements, and new aggregation operators.

**Support status:** Actively supported with security and bug fix updates. Follows MongoDB's standard ~30-month lifecycle from GA.

## Key Features Introduced in MongoDB 7.0

### Compound Wildcard Indexes

MongoDB 7.0 allows combining wildcard index fields with regular indexed fields in a single compound index. Previously, wildcard indexes could only index a single field pattern.

```javascript
// Compound wildcard: fixed prefix + wildcard on dynamic attributes
db.products.createIndex({ category: 1, "attributes.$**": 1 })
// Supports queries like:
db.products.find({ category: "electronics", "attributes.color": "red" })
db.products.find({ category: "clothing", "attributes.size": "L", "attributes.brand": "Nike" })

// Compound wildcard with multiple fixed fields
db.events.createIndex({ tenant_id: 1, event_type: 1, "metadata.$**": 1 })

// Wildcard with projection filter (index only specific sub-paths)
db.products.createIndex(
  { category: 1, "specs.$**": 1 },
  { wildcardProjection: { "specs.weight": 1, "specs.dimensions": 1 } }
)

// Wildcard at different positions (not just suffix)
db.logs.createIndex({ "$**": 1, timestamp: 1 })  // Wildcard prefix + fixed suffix
```

**When to use compound wildcard indexes:**
- Polymorphic data where different documents have different attribute fields
- Multi-tenant systems where tenant-specific metadata varies
- Product catalogs with variable specifications per category
- Log/event data with dynamic metadata fields

**Limitations:**
- Cannot combine multiple wildcard fields (`{ "a.$**": 1, "b.$**": 1 }` is not valid)
- Wildcard component cannot be used for sort optimization (only equality/range on wildcard paths)
- Regular compound index fields support ESR rule; the wildcard part supports equality/range but not sort

**Upgrade from plain wildcard indexes:**
```javascript
// Before (6.0): Separate wildcard index, cannot combine with other fields
db.products.createIndex({ "$**": 1 })  // Indexes all fields
// Query: db.products.find({ category: "X", "attrs.color": "red" })
// → Uses wildcard, but cannot efficiently filter on both fields together

// After (7.0): Compound wildcard targets specific patterns
db.products.createIndex({ category: 1, "attrs.$**": 1 })
// → Efficiently uses category prefix + wildcard for attrs sub-fields
```

### Queryable Encryption (GA)

Queryable Encryption moves from preview (6.0) to General Availability in 7.0 with significant improvements:

```javascript
// Encrypted field map with equality and range queries (7.0 GA)
const encryptedFieldsMap = {
  "mydb.patients": {
    fields: [
      {
        path: "ssn",
        bsonType: "string",
        keyId: UUID("..."),
        queries: { queryType: "equality" }   // Equality search on encrypted field
      },
      {
        path: "age",
        bsonType: "int",
        keyId: UUID("..."),
        queries: {
          queryType: "range",                 // 7.0: Range queries on encrypted fields
          min: 0,
          max: 200,
          sparsity: 1,
          trimFactor: 6
        }
      }
    ]
  }
};

// Range query on encrypted field (7.0+)
db.patients.find({ age: { $gte: 18, $lte: 65 } })
// Server never sees plaintext age values; query is processed on encrypted data
```

**7.0 GA improvements over 6.0 preview:**
- Range query support (`$gt`, `$gte`, `$lt`, `$lte`) on encrypted fields
- Improved insert/query performance (3-5x faster than 6.0 preview)
- Reduced metadata size (less storage overhead for encrypted collections)
- Contention parameter for tuning insert throughput vs. query performance
- Production-quality stability and security audit

**When to use Queryable Encryption:**
- PII data (SSN, medical records, financial data) that must be encrypted but queried
- Regulatory compliance (GDPR, HIPAA, PCI-DSS) requiring encryption of sensitive fields
- Zero-trust architectures where the database operator should not see plaintext
- Multi-tenant systems where tenant data must be cryptographically isolated

### Metadata in Change Streams

Change stream events now include configurable metadata:

```javascript
// Open change stream with additional metadata
const stream = db.orders.watch([], {
  showExpandedEvents: true  // Include additional metadata
});

// Events now include:
// - wallTime: wall clock time of the event (more precise than clusterTime for timing)
// - collectionUUID: UUID of the collection (stable across renames)
// - operationDescription: Human-readable description of DDL operations
```

**Use cases:**
- Precise event timing for audit trails (wallTime vs. clusterTime)
- Tracking collection identity across renames (collectionUUID)
- Better observability for DDL operations in event-driven architectures

### ShardingReady State

MongoDB 7.0 introduces the `ShardingReady` state, enabling smoother transitions from replica sets to sharded clusters:

```javascript
// Mark a standalone replica set as ready for sharding
db.adminCommand({ transitionToShardedCluster: 1 })

// The replica set enters ShardingReady state:
// - It can function as a standalone replica set
// - It is pre-configured for sharding (config metadata prepared)
// - When you add it to a sharded cluster, the transition is faster

// Check if cluster is in ShardingReady state
db.adminCommand({ getClusterParameter: "shardingReady" })
```

**Benefits:**
- Reduced downtime when converting a replica set to a sharded cluster
- Pre-flight validation that the replica set is compatible with sharding
- Smoother migration path for growing applications

### Automergeable Chunks

MongoDB 7.0 improves the balancer with automatic chunk merging:

```javascript
// Chunks that are below the optimal size are automatically merged by the balancer
// This reduces the total number of chunks and metadata overhead

// Check auto-merge status
sh.balancerStatus()

// Auto-merge is enabled by default in 7.0
// It runs during the balancer window and merges adjacent chunks on the same shard
// that are below a threshold size
```

**Why it matters:**
- After many deletes, chunks may shrink below optimal size
- Too many small chunks waste metadata and increase balancer work
- Previously, administrators had to manually merge chunks with `sh.mergeChunks()`
- Auto-merge keeps chunk counts healthy automatically

### New Aggregation Operators

**$percentile and $median:**
```javascript
// Calculate percentiles in a single aggregation pass
db.response_times.aggregate([
  {
    $group: {
      _id: "$endpoint",
      p50: {
        $percentile: {
          input: "$latency_ms",
          p: [0.5],
          method: "approximate"
        }
      },
      p95: {
        $percentile: {
          input: "$latency_ms",
          p: [0.95],
          method: "approximate"
        }
      },
      p99: {
        $percentile: {
          input: "$latency_ms",
          p: [0.99],
          method: "approximate"
        }
      },
      median: {
        $median: {
          input: "$latency_ms",
          method: "approximate"
        }
      }
    }
  }
])

// Multiple percentiles in one expression
db.orders.aggregate([
  {
    $group: {
      _id: null,
      distribution: {
        $percentile: {
          input: "$total",
          p: [0.25, 0.5, 0.75, 0.9, 0.95, 0.99],
          method: "approximate"
        }
      }
    }
  }
])
```

**Methods:**
- `"approximate"`: Uses the t-digest algorithm. Fast, memory-efficient, suitable for large datasets.
- `"exact"` (future): Precise percentile computation. Not available in 7.0 for $group; only for $setWindowFields.

### Improved $merge and $out

```javascript
// $merge with whenMatched "pipeline" option improvements
db.daily_stats.aggregate([
  { $match: { date: ISODate("2025-03-15") } },
  {
    $merge: {
      into: "weekly_stats",
      on: ["product_id", "week"],
      whenMatched: [
        { $set: {
          total: { $add: ["$$new.total", "$total"] },
          count: { $add: ["$$new.count", "$count"] },
          last_updated: "$$NOW"
        }}
      ],
      whenNotMatched: "insert"
    }
  }
])

// $out to a different database (improved in 7.0)
db.source.aggregate([
  { $match: { status: "active" } },
  { $out: { db: "analytics", coll: "active_records" } }
])
```

### User Roles and Security Enhancements

```javascript
// New built-in role: directShardOperations
// Allows running commands directly on a shard (bypassing mongos) for maintenance
db.adminCommand({
  createUser: "shard_admin",
  pwd: passwordPrompt(),
  roles: [{ role: "directShardOperations", db: "admin" }]
})

// Improved authentication event logging
// 7.0 logs more detail on auth failures for security audit
```

### Atlas Search Improvements

```javascript
// Score details in Atlas Search (explain-like for search relevance)
db.articles.aggregate([
  {
    $search: {
      index: "default",
      text: { query: "mongodb performance", path: "content" },
      scoreDetails: true   // 7.0: Detailed scoring breakdown
    }
  },
  { $project: {
    title: 1,
    score: { $meta: "searchScore" },
    scoreDetails: { $meta: "searchScoreDetails" }  // Per-clause scoring
  }}
])
```

### Other Notable Features

- **Slow query logging improvements:** Slow query log entries now include more diagnostic information including plan summary and key metrics
- **$bitAnd, $bitOr, $bitNot, $bitXor operators:** Bitwise operations in aggregation pipeline
- **db.checkMetadataConsistency():** Validates sharding metadata integrity
- **Improved query planning:** Better cost estimates for compound index selection
- **Concurrent compact:** The `compact` command can now run concurrently with reads (reduced lock contention)

## Version Boundaries

- **Not available in MongoDB 7.0:** OIDC authentication (8.0), enhanced query execution engine improvements (8.0)
- **New in 7.0 vs 6.0:** Compound wildcard indexes, Queryable Encryption GA with range queries, metadata in change streams, ShardingReady, auto-mergeable chunks, $percentile/$median, bitwise aggregation operators
- **Deprecated in 7.0:** Legacy SCRAM-SHA-1 authentication (prefer SCRAM-SHA-256), `system.users` direct modification (use user management commands)

## Breaking Changes from 6.0

1. **Removed `db.collection.mapReduce()`** -- Fully removed. Use the aggregation pipeline (`$group`, `$reduce`, `$accumulator`) instead.
2. **Removed `--serviceExecutor adaptive` option** -- Only the default synchronous service executor is supported.
3. **Removed `--wiredTigerCacheSizeGB 0` interpretation** -- A value of 0 no longer means "use default"; it means 0GB (effectively broken). Always set an explicit cache size.
4. **Changed default for `migrateClone` batch size** -- May affect migration performance in sharded clusters.
5. **Removed `failIndexKeyTooLong` parameter** -- The 1024-byte index key limit was already removed in 4.2 FCV.

## Common Pitfalls

1. **Compound wildcard index misuse** -- Do not use compound wildcard indexes as a replacement for well-designed compound indexes. If you know the field names at design time, a regular compound index is more efficient. Use compound wildcards only for truly dynamic/polymorphic fields.

2. **Queryable Encryption performance expectations** -- Queryable Encryption adds overhead to every read and write on encrypted fields. Writes are ~2-5x slower; reads with range queries may be 5-10x slower depending on data distribution. Benchmark with realistic workloads.

3. **Ignoring automergeable chunk impact** -- Auto-merge runs during the balancer window. If you have a very active system, the merge operations consume I/O. Monitor balancer activity during auto-merge windows.

4. **$percentile with exact method** -- The "exact" method is not available in `$group` in 7.0. Using it there will fail. Use "approximate" for group operations.

5. **ShardingReady is not sharding** -- Transitioning to ShardingReady state does not shard the cluster. It only prepares the metadata. You still need to add the replica set to a sharded cluster configuration.

## Migration Notes

### Upgrading from MongoDB 6.0 to 7.0

Pre-upgrade checklist:
1. **Ensure FCV is 6.0:** `db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })`
2. **Replace `mapReduce` usage** with aggregation pipeline equivalents (mapReduce is removed in 7.0)
3. **Update drivers** to versions supporting MongoDB 7.0
4. **Review `--wiredTigerCacheSizeGB` settings** -- Ensure value is > 0
5. **Upgrade in rolling fashion** for replica sets: secondaries first, then step-down primary, upgrade, step-up

Post-upgrade steps:
1. Set FCV: `db.adminCommand({ setFeatureCompatibilityVersion: "7.0" })`
2. Replace plain wildcard indexes with compound wildcards where beneficial
3. Evaluate Queryable Encryption GA for sensitive data workloads
4. Monitor auto-merge balancer activity
5. Add `$percentile` / `$median` to analytics pipelines

### mapReduce to Aggregation Migration

```javascript
// Before (6.0 and earlier): mapReduce
db.orders.mapReduce(
  function() { emit(this.category, this.amount); },
  function(key, values) { return Array.sum(values); },
  { out: "category_totals" }
)

// After (7.0+): aggregation pipeline
db.orders.aggregate([
  { $group: { _id: "$category", total: { $sum: "$amount" } } },
  { $merge: { into: "category_totals", whenMatched: "replace", whenNotMatched: "insert" } }
])
```

### Upgrading from MongoDB 7.0 to 8.0

- OIDC authentication becomes available (plan identity provider integration)
- Enhanced query execution improvements may change query plans (test performance)
- Plan for new aggregate operators and improvements

## Reference Files

For deep technical details, load the parent technology agent's references:

- `../references/architecture.md` -- WiredTiger internals, replication, sharding internals
- `../references/diagnostics.md` -- serverStatus, currentOp, profiler, performance analysis
- `../references/best-practices.md` -- Production configuration, backup, security
