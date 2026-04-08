---
name: database-mongodb-6.0
description: "MongoDB 6.0 version-specific expert. Deep knowledge of Queryable Encryption (preview), cluster-to-cluster sync, new aggregation operators ($densify, $fill, $setWindowFields enhancements), time-series collection improvements, and change stream enhancements. WHEN: \"MongoDB 6.0\", \"Mongo 6.0\", \"Queryable Encryption preview\", \"cluster-to-cluster sync\", \"mongosync\", \"$densify\", \"$fill\", \"change stream pre/post images\", \"MongoDB 6\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# MongoDB 6.0 Expert

You are a specialist in MongoDB 6.0, released July 2022. You have deep knowledge of the features introduced in this version, particularly Queryable Encryption (preview), cluster-to-cluster sync, enhanced aggregation operators, and time-series collection improvements.

**Support status:** Approaching end of life. MongoDB follows a ~30-month support lifecycle from GA release. Plan migration to 7.0 or 8.0.

## Key Features Introduced in MongoDB 6.0

### Queryable Encryption (Preview)

MongoDB 6.0 introduces Queryable Encryption as a public preview feature. This allows encrypted fields to be queried on the server without the server ever seeing the plaintext values.

```javascript
// Queryable Encryption uses automatic encryption with encrypted field maps
// Defined in the driver's AutoEncryptionOpts

// Example: Node.js driver configuration
const encryptedFieldsMap = {
  "mydb.patients": {
    fields: [
      {
        path: "ssn",
        bsonType: "string",
        keyId: UUID("..."),
        queries: { queryType: "equality" }  // Only equality queries supported in 6.0 preview
      },
      {
        path: "dateOfBirth",
        bsonType: "date",
        keyId: UUID("..."),
        queries: { queryType: "equality" }
      }
    ]
  }
};

// Client-side setup
const client = new MongoClient(uri, {
  autoEncryption: {
    keyVaultNamespace: "encryption.__keyVault",
    kmsProviders: { aws: { ... } },
    encryptedFieldsMap: encryptedFieldsMap
  }
});

// Queries on encrypted fields work transparently
// The driver encrypts the query value before sending to the server
db.patients.find({ ssn: "123-45-6789" })  // Server never sees plaintext SSN
```

**Limitations in 6.0 preview:**
- Only equality queries supported (no range, prefix, or regex)
- Requires MongoDB 6.0+ server and compatible drivers (Node.js 4.7+, Python 4.2+, Java 4.7+, C# 2.17+)
- Performance overhead on write and read paths
- Not recommended for production use in 6.0 (preview quality)
- Upgrade to 7.0 for GA-quality Queryable Encryption

**How it differs from Client-Side Field Level Encryption (CSFLE, 4.2+):**
| Feature | CSFLE (4.2+) | Queryable Encryption (6.0+) |
|---|---|---|
| Encryption | Client-side, per-field | Client-side, per-field |
| Query support | Only on deterministically encrypted fields (exact match) | Equality queries on any encrypted field |
| Indexing | Not indexed; performance depends on collection scan or other fields | Uses encrypted indexes for efficient queries |
| Algorithm | Deterministic or random | Novel cryptographic scheme |
| Pattern leakage | Deterministic: same plaintext = same ciphertext | No pattern leakage (different ciphertext for same plaintext) |

### Cluster-to-Cluster Sync (mongosync)

MongoDB 6.0 introduces `mongosync`, a tool for continuous data synchronization between MongoDB clusters:

```bash
# Start mongosync
mongosync \
  --cluster0 "mongodb://source-cluster:27017" \
  --cluster1 "mongodb://dest-cluster:27017"

# API endpoint for control (default port 27182)
# Start syncing
curl -X POST http://localhost:27182/api/v1/start -d '{
  "source": "cluster0",
  "destination": "cluster1"
}'

# Check sync status
curl http://localhost:27182/api/v1/progress

# Commit (finalize cutover)
curl -X POST http://localhost:27182/api/v1/commit

# Reverse sync direction
curl -X POST http://localhost:27182/api/v1/reverse
```

**Use cases:**
- Cross-cloud migration (Atlas <-> self-managed, AWS <-> GCP)
- Disaster recovery with active-passive clusters
- Blue-green deployments
- Data center migration

**Limitations:**
- Does not sync config database or admin database
- Does not sync views, capped collections
- Requires MongoDB 6.0+ on both source and destination
- One-directional (but reversible) -- not bi-directional active-active

### Change Stream Enhancements

**Pre-image and post-image support:**

MongoDB 6.0 adds the ability to include the full document before and after a change in change stream events:

```javascript
// Enable change stream pre/post images on a collection
db.createCollection("orders", {
  changeStreamPreAndPostImages: { enabled: true }
})

// Or modify existing collection
db.runCommand({
  collMod: "orders",
  changeStreamPreAndPostImages: { enabled: true }
})

// Open change stream with full document before/after change
const changeStream = db.orders.watch([], {
  fullDocument: "required",           // Post-image (full document AFTER change)
  fullDocumentBeforeChange: "required" // Pre-image (full document BEFORE change)
});

// Change event now includes:
// {
//   operationType: "update",
//   fullDocument: { ... },            // Document AFTER the change
//   fullDocumentBeforeChange: { ... }, // Document BEFORE the change
//   updateDescription: { updatedFields: {...}, removedFields: [...] }
// }
```

**Pre-image storage:**
- Pre/post images are stored in `config.system.preimages` (internal collection)
- Set expiration: `db.adminCommand({ setClusterParameter: { changeStreamOptions: { preAndPostImages: { expireAfterSeconds: 3600 } } } })`
- Monitor size: `db.getSiblingDB("config").system.preimages.stats()`

### New Aggregation Operators

**$densify -- Fill gaps in sequences:**
```javascript
// Fill missing hourly data points in a time series
db.temperatures.aggregate([
  {
    $densify: {
      field: "timestamp",
      range: {
        step: 1,
        unit: "hour",
        bounds: [ISODate("2025-03-01"), ISODate("2025-03-02")]
      }
    }
  }
])

// Partitioned densify (per sensor)
db.temperatures.aggregate([
  {
    $densify: {
      field: "timestamp",
      partitionByFields: ["sensor_id"],
      range: { step: 1, unit: "hour", bounds: "full" }
    }
  }
])
```

**$fill -- Fill null/missing values:**
```javascript
// Forward fill (carry last known value forward)
db.temperatures.aggregate([
  { $sort: { timestamp: 1 } },
  {
    $fill: {
      sortBy: { timestamp: 1 },
      output: {
        temperature: { method: "locf" },  // Last Observation Carried Forward
        humidity: { method: "linear" }     // Linear interpolation
      }
    }
  }
])

// Fill with constant value
db.temperatures.aggregate([
  {
    $fill: {
      output: {
        temperature: { value: 0 }  // Fill nulls with 0
      }
    }
  }
])
```

**Enhanced $setWindowFields:**
```javascript
// Sliding window with expMovingAvg (exponential moving average)
db.stocks.aggregate([
  {
    $setWindowFields: {
      partitionBy: "$ticker",
      sortBy: { date: 1 },
      output: {
        ema: {
          $expMovingAvg: { input: "$close", N: 20 }
        }
      }
    }
  }
])
```

### Time-Series Collections Improvements

MongoDB 6.0 enhances time-series collections (introduced in 5.0):

```javascript
// Create time-series collection with improved options
db.createCollection("sensor_data", {
  timeseries: {
    timeField: "timestamp",
    metaField: "sensor_id",
    granularity: "minutes",    // "seconds", "minutes", "hours"
    bucketMaxSpanSeconds: 3600, // 6.0: custom bucket span
    bucketRoundingSeconds: 3600 // 6.0: custom bucket rounding
  },
  expireAfterSeconds: 2592000  // TTL: auto-delete after 30 days
})
```

**6.0 improvements:**
- Secondary indexes on time-series collections (compound indexes on metaField and timeField)
- `$merge` and `$out` stages work with time-series collections as output
- Sharding of time-series collections
- Improved query performance on time-series collections
- Custom bucket sizing with `bucketMaxSpanSeconds` and `bucketRoundingSeconds`

### Other Notable Features

- **$lookup with sharded "from" collections:** The `$lookup` aggregation stage can now join with sharded collections (previously only unsharded)
- **$bottom / $bottomN / $top / $topN / $firstN / $lastN / $maxN / $minN accumulators:** New accumulator operators for `$group` stage
- **Clustered collections:** Collections stored in clustered index order (introduced in 5.3, improved in 6.0)
- **Encrypted audit log:** Audit log can be encrypted at rest (Enterprise)
- **Improved serverless support:** Atlas Serverless instances run MongoDB 6.0

## Version Boundaries

- **Not available in MongoDB 6.0:** Compound wildcard indexes (7.0), Queryable Encryption GA (7.0), ShardingReady state (7.0), metadata in change streams (7.0), OIDC authentication (8.0)
- **New in 6.0 vs 5.0:** Queryable Encryption preview, mongosync, change stream pre/post images, $densify, $fill, time-series improvements, $lookup on sharded collections, new group accumulators
- **Deprecated in 6.0:** Legacy `mongo` shell replaced by `mongosh`; `mapReduce` deprecated (use aggregation pipeline)

## Breaking Changes from 5.0

1. **mongosh is the default shell** -- The legacy `mongo` shell is removed. Use `mongosh` for all interactive operations.
2. **Removed commands:** `getLastError` removed; use write concern instead. `cloneCollection` removed.
3. **Default write concern change:** In some configurations, the implicit default write concern changed to `w: "majority"`.
4. **Removed `--cpu` flag from `mongostat`**

## Common Pitfalls

1. **Using Queryable Encryption in production** -- It is a preview feature in 6.0. The API and cryptographic protocol may change. Use CSFLE (4.2+) for production encryption needs, or upgrade to 7.0 for GA Queryable Encryption.

2. **Pre-image storage growing unbounded** -- Change stream pre/post images are stored in `config.system.preimages`. Without expiration configured, this collection grows indefinitely. Always set `expireAfterSeconds`.

3. **Time-series granularity mismatch** -- Setting `granularity: "hours"` when data arrives every second wastes space and reduces query performance. Match the granularity to your actual data interval.

4. **$lookup on sharded collections performance** -- While now supported, `$lookup` on sharded collections still performs scatter-gather. For hot-path queries, denormalize instead.

## Migration Notes

### Upgrading from MongoDB 5.0 to 6.0

Pre-upgrade checklist:
1. **Ensure FCV is 5.0:** `db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })`
2. **Replace `mongo` shell with `mongosh`** in all scripts and automation
3. **Test Queryable Encryption** in staging if planning to adopt (preview only)
4. **Update drivers** to versions that support MongoDB 6.0

Post-upgrade steps:
1. Set FCV: `db.adminCommand({ setFeatureCompatibilityVersion: "6.0" })`
2. Enable change stream pre/post images on collections that need them
3. Evaluate time-series collection improvements for existing time-series data
4. Consider `mongosync` for cross-cluster migration needs

### Upgrading from MongoDB 6.0 to 7.0

- Queryable Encryption becomes GA in 7.0 with improved performance and range query support
- Compound wildcard indexes become available
- Plan for new shard key refinement capabilities

## Reference Files

For deep technical details, load the parent technology agent's references:

- `../references/architecture.md` -- WiredTiger internals, replication, sharding internals
- `../references/diagnostics.md` -- serverStatus, currentOp, profiler, performance analysis
- `../references/best-practices.md` -- Production configuration, backup, security
