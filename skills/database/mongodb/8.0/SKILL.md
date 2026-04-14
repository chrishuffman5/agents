---
name: database-mongodb-8.0
description: "MongoDB 8.0 version-specific expert. Deep knowledge of OIDC authentication, Queryable Encryption enhancements, improved query planning and execution, bulk write command on mongos, new aggregate operators, default timeout API, and performance improvements. WHEN: \"MongoDB 8.0\", \"Mongo 8.0\", \"OIDC MongoDB\", \"OpenID Connect MongoDB\", \"bulkWrite mongos\", \"default timeout\", \"queryStats\", \"MongoDB 8\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# MongoDB 8.0 Expert

You are a specialist in MongoDB 8.0, released August 2024. You have deep knowledge of the features introduced in this version, particularly OIDC authentication, Queryable Encryption enhancements, improved query execution, the new bulkWrite command for sharded clusters, and numerous performance improvements.

**Support status:** Current release. Actively supported with security, bug fix, and feature updates.

## Key Features Introduced in MongoDB 8.0

### OIDC Authentication (OpenID Connect)

MongoDB 8.0 adds native OIDC authentication, enabling integration with identity providers like Azure AD, Okta, Google, and AWS IAM Identity Center:

```yaml
# mongod.conf -- OIDC configuration
security:
  authorization: enabled
  oidc:
    - issuer: "https://login.microsoftonline.com/<tenant-id>/v2.0"
      audience: "api://mongodb-cluster"
      authNamePrefix: "azure"
      # Optional: specific claim for username
      principalClaim: "preferred_username"
```

```javascript
// Create user mapped to OIDC identity
db.getSiblingDB("$external").runCommand({
  createUser: "azure/user@example.com",
  roles: [{ role: "readWrite", db: "myapp" }]
})

// Connection with OIDC token (driver handles token acquisition)
// Node.js driver example:
const client = new MongoClient(uri, {
  authMechanism: "MONGODB-OIDC",
  authMechanismProperties: {
    ENVIRONMENT: "azure",          // or "gcp", or custom callback
    TOKEN_RESOURCE: "api://mongodb-cluster"
  }
});

// Atlas integration: OIDC for Atlas users
// Configure in Atlas: Organization Settings > Federated Authentication
```

**OIDC benefits:**
- Token-based authentication (no stored passwords in MongoDB)
- Short-lived tokens with automatic rotation
- Integration with enterprise SSO (single sign-on)
- MFA enforcement via identity provider
- Centralized user management outside MongoDB

**OIDC vs. other auth mechanisms:**
| Mechanism | MongoDB Version | Token Type | Best For |
|---|---|---|---|
| SCRAM-SHA-256 | 4.0+ | Password hash | Traditional deployments |
| x.509 | 3.0+ | Certificate | Service-to-service, mutual TLS |
| LDAP | Enterprise 3.2+ | LDAP bind | Active Directory / LDAP environments |
| Kerberos | Enterprise 2.6+ | Kerberos ticket | Windows/AD environments |
| AWS IAM | Atlas | AWS STS token | AWS-native deployments |
| **OIDC** | **8.0+** | **JWT token** | **Cloud-native, SSO, modern IdP** |

### Queryable Encryption Enhancements

MongoDB 8.0 improves Queryable Encryption with better performance and new capabilities:

```javascript
// Improved contention handling (8.0)
const encryptedFieldsMap = {
  "mydb.records": {
    fields: [
      {
        path: "ssn",
        bsonType: "string",
        keyId: UUID("..."),
        queries: {
          queryType: "equality",
          contention: 8           // 8.0: Improved contention algorithm
        }
      },
      {
        path: "salary",
        bsonType: "int",
        keyId: UUID("..."),
        queries: {
          queryType: "range",
          min: 0,
          max: 10000000,
          sparsity: 2,            // 8.0: Better default sparsity
          trimFactor: 6
        }
      }
    ]
  }
};
```

**8.0 improvements:**
- Reduced metadata storage overhead (up to 30% less space for encrypted collections)
- Improved insert throughput (better contention handling for concurrent inserts)
- Faster range query execution
- Improved compaction of encrypted indexes
- Better error messages for encryption configuration issues

### Improved Query Planning and Execution

MongoDB 8.0 includes significant query planner improvements:

```javascript
// Multi-key sort optimization
// 8.0 can use an index for sort even when multi-key (array) fields are involved
// Previously, multi-key indexes could not support sort optimization in all cases
db.orders.find({ items: { $elemMatch: { sku: "WIDGET" } } }).sort({ date: 1 })
// Index: { "items.sku": 1, date: 1 } can now optimize the sort in more cases

// Improved plan cache
// 8.0 uses an improved algorithm for plan cache invalidation
// Reduces unnecessary plan re-evaluation when statistics change slightly

// SBE (Slot-Based Execution Engine) improvements
// More query shapes pushed to the faster SBE engine:
// - $group with $sum, $avg, $min, $max
// - $lookup with pipeline sub-queries
// - $unwind + $group combinations
// SBE typically provides 20-50% better performance than the classic engine
```

**Slot-Based Execution (SBE) engine:**
- Introduced in 5.1 for basic queries; expanded in each subsequent release
- 8.0 supports more aggregation stages in SBE
- SBE uses a column-oriented in-memory format that improves CPU cache efficiency
- Check if a query uses SBE: `explain("executionStats")` shows `"engine": "sbe"` in the output

```javascript
// Verify SBE usage
const explain = db.orders.find({ status: "active" }).explain("executionStats");
print(`Execution engine: ${explain.executionStats.executionStages.engine || "classic"}`);
```

### bulkWrite Command on mongos

MongoDB 8.0 introduces a server-side `bulkWrite` command that works across multiple collections and databases in a single command, routed through mongos:

```javascript
// New bulkWrite command (8.0): cross-collection bulk operations
db.adminCommand({
  bulkWrite: 1,
  ops: [
    { insert: 0, document: { _id: 1, name: "Alice" } },
    { insert: 0, document: { _id: 2, name: "Bob" } },
    { insert: 1, document: { _id: 1, order: "ORD-001" } },
    { update: 0, filter: { _id: 1 }, updateMods: { $set: { status: "active" } }, multi: false }
  ],
  nsInfo: [
    { ns: "mydb.users" },     // index 0
    { ns: "mydb.orders" }     // index 1
  ],
  ordered: true
})
```

**Benefits:**
- Single round-trip for operations spanning multiple collections
- Reduced network overhead for batch operations
- Atomic ordering guarantees when `ordered: true`
- Works with sharded clusters (mongos routes each sub-operation to the correct shard)

**Key differences from collection-level bulkWrite:**
| Feature | Collection bulkWrite (existing) | Server bulkWrite (8.0) |
|---|---|---|
| Scope | Single collection | Multiple collections/databases |
| API | `db.collection.bulkWrite([...])` | `db.adminCommand({ bulkWrite: 1, ... })` |
| Operations | Insert, update, delete, replaceOne | Same |
| Sharding | Routed per-document | Routed per-operation across collections |
| Use case | Batch writes to one collection | Complex multi-collection workflows |

### Default Timeout API (Client-Side Operation Timeout)

MongoDB 8.0 drivers support a unified timeout mechanism:

```javascript
// Set timeout for individual operations (driver-level)
// Node.js driver:
const result = await db.collection("orders")
  .find({ status: "active" })
  .timeoutMS(5000)   // 8.0: Operation-level timeout
  .toArray();

// Connection-level default timeout
const client = new MongoClient(uri, {
  timeoutMS: 10000   // Default timeout for all operations
});

// This replaces the need for separate:
// - serverSelectionTimeoutMS
// - socketTimeoutMS
// - connectTimeoutMS
// - maxTimeMS per operation
// into a single, comprehensive timeout
```

**Timeout behavior:**
- Covers the entire operation lifecycle: server selection, connection checkout, wire protocol, server execution
- If the operation times out, the driver sends a `killCursors` / abort to the server
- Supersedes `maxTimeMS` for most use cases
- Can be set globally on the client, per-database, per-collection, or per-operation

### $queryStats Aggregation Stage

MongoDB 8.0 adds `$queryStats` for querying the query statistics store:

```javascript
// Get query statistics (replaces the need for $currentOp + profiler for some use cases)
db.adminCommand({
  aggregate: 1,
  pipeline: [
    { $queryStats: {} },
    { $sort: { "metrics.totalExecMicros.sum": -1 } },
    { $limit: 20 }
  ],
  cursor: {}
})

// Query stats include:
// - Query shape (parameterized query pattern)
// - Execution count
// - Total/average execution time
// - Keys examined, docs examined
// - Index used
// - First/last execution time
```

**$queryStats vs. profiler vs. $currentOp:**
| Feature | Profiler | $currentOp | $queryStats (8.0) |
|---|---|---|---|
| Scope | Single database | Server-wide current ops | Server-wide historical stats |
| Overhead | High (writes to capped collection) | Low (in-memory) | Low (in-memory aggregation) |
| History | Yes (stored in system.profile) | No (current only) | Yes (since last stats reset) |
| Aggregation | Requires querying capped collection | Limited | Native aggregation pipeline |
| Best for | Detailed slow query analysis | Real-time troubleshooting | Top-N queries, pattern analysis |

### Performance Improvements

**Batch multi-document inserts:**
```javascript
// 8.0 improves batched insert performance for multi-document transactions
// Up to 50% faster for insertMany in transactions due to reduced WiredTiger overhead
const session = client.startSession();
session.startTransaction();
await collection.insertMany(thousandDocs, { session });
await session.commitTransaction();
```

**Read performance improvements:**
- Faster secondary reads with reduced oplog application contention
- Improved read-your-writes consistency with causal sessions
- Better prefetch for range queries on B-tree indexes

**Write performance improvements:**
- Reduced journal commit latency under high write concurrency
- Improved WiredTiger checkpoint scheduling to reduce latency spikes
- Better write batching for `w: "majority"` operations

### Time-Series Collection Enhancements

```javascript
// Improved secondary index support for time-series
// 8.0: Partial indexes on time-series collections
db.sensor_data.createIndex(
  { "metadata.sensor_type": 1, timestamp: 1 },
  { partialFilterExpression: { "metadata.priority": "high" } }
)

// Improved delete performance on time-series collections
// 8.0 handles range deletes on time-series more efficiently
db.sensor_data.deleteMany({
  timestamp: { $lt: ISODate("2024-01-01") }
})
```

### Other Notable Features

- **Config shard:** One of the shards can also serve as the config server (reduces infrastructure for small sharded clusters)
- **Improved change streams:** More efficient change stream resume (less oplog scanning on resume)
- **KMIP 2.0 support:** Updated key management interoperability protocol for enterprise encryption
- **Audit log improvements:** More granular audit filtering and reduced audit overhead
- **`$integral` and `$derivative` operators** for time-series analytical computations
- **Compact now non-blocking:** The `compact` command no longer blocks reads or writes (improved from 7.0's partial improvement)

## Version Boundaries

- **Not available in MongoDB 8.0:** Features from future releases (vectorized execution engine improvements, etc.)
- **New in 8.0 vs 7.0:** OIDC authentication, server-side bulkWrite, $queryStats, default timeout API, config shard, improved SBE coverage, QE enhancements, batch insert improvements
- **Deprecated in 8.0:** Legacy connection string format (`mongodb://` without SRV is not deprecated, but `mongodb+srv://` is preferred for Atlas)

## Breaking Changes from 7.0

1. **Removed `count` command** -- Use `countDocuments()` (which uses an aggregation pipeline) or `estimatedDocumentCount()` (which uses collection metadata). The `count` shell helper already uses these internally.
2. **Changed default write concern for config servers** -- Config server replica sets now use `w: "majority"` by default for all internal operations.
3. **Removed `--quiet` from some tools** -- Some command-line tools no longer support the `--quiet` flag.
4. **Changed authentication mechanism negotiation** -- SCRAM-SHA-256 is now preferred over SCRAM-SHA-1 during mechanism negotiation. Clients using SCRAM-SHA-1 explicitly still work.
5. **SBE execution for more query shapes** -- Queries that previously used the classic engine may now use SBE, potentially changing performance characteristics (usually better, but test).

## Common Pitfalls

1. **OIDC token expiration** -- OIDC tokens are short-lived (typically 1 hour). Ensure your driver is configured to refresh tokens automatically. Long-running batch jobs may fail if token refresh is not handled.

2. **$queryStats overhead** -- While lower overhead than the profiler, running `$queryStats` frequently or with complex post-processing pipelines can impact the server. Use it for periodic analysis, not continuous monitoring.

3. **SBE plan changes** -- The expanded SBE coverage means some queries may use different execution strategies than in 7.0. Run `explain()` on critical queries after upgrade to verify performance. In rare cases, SBE plans may be slower for specific query shapes.

4. **bulkWrite ordered behavior** -- When `ordered: true` (default), the server stops on the first error. For fire-and-forget batch operations, use `ordered: false` to continue past errors.

5. **Default timeout interaction with existing timeouts** -- If you set `timeoutMS` on the client but also have `maxTimeMS` on individual operations, the more restrictive timeout wins. Review and remove redundant timeout settings.

6. **Config shard resource contention** -- Using a shard as the config server reduces infrastructure cost but means config operations compete with data operations for resources. Only appropriate for small-medium sharded clusters.

## Migration Notes

### Upgrading from MongoDB 7.0 to 8.0

Pre-upgrade checklist:
1. **Ensure FCV is 7.0:** `db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })`
2. **Replace `count()` usage** with `countDocuments()` or `estimatedDocumentCount()` in application code
3. **Update drivers** to versions supporting MongoDB 8.0 (Node.js 6.0+, Python 4.8+, Java 5.0+, Go 2.0+)
4. **Review authentication:** If planning OIDC, prepare identity provider integration
5. **Test SBE behavior:** Run key queries with `explain()` against an 8.0 test instance to verify plan selection

Upgrade procedure (rolling upgrade for replica sets):
```bash
# 1. Upgrade secondaries one at a time
# On each secondary:
sudo systemctl stop mongod
# Install MongoDB 8.0 packages
sudo systemctl start mongod
# Verify member rejoins replica set:
mongosh --eval "rs.status()"

# 2. Step down primary
mongosh --eval "rs.stepDown(300)"

# 3. Upgrade the old primary (now a secondary)
sudo systemctl stop mongod
# Install MongoDB 8.0 packages
sudo systemctl start mongod

# 4. Set FCV after all members are upgraded
mongosh --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "8.0" })'
```

Post-upgrade steps:
1. Set FCV: `db.adminCommand({ setFeatureCompatibilityVersion: "8.0" })`
2. Configure OIDC authentication if migrating from SCRAM or LDAP
3. Evaluate `$queryStats` as a replacement for or supplement to the profiler
4. Test `bulkWrite` command for cross-collection batch operations
5. Review timeoutMS settings and simplify timeout configuration
6. Monitor SBE engine usage with `explain()` on key queries

### Upgrading from MongoDB 8.0 to Future Versions

- Stay current with MongoDB release notes
- Plan for continued SBE expansion (more stages optimized)
- Evaluate new vector search capabilities for AI/ML workloads

## Reference Files

For deep technical details, load the parent technology agent's references:

- `../references/architecture.md` -- WiredTiger internals, replication, sharding internals
- `../references/diagnostics.md` -- serverStatus, currentOp, profiler, performance analysis
- `../references/best-practices.md` -- Production configuration, backup, security
