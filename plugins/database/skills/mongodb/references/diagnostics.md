# MongoDB Diagnostics Reference

## Diagnostic Workflow

The standard troubleshooting approach for MongoDB performance issues:

```
1. Server Status Overview  -->  What is the server doing right now?
       |
2. Current Operations      -->  What queries/operations are running?
       |
3. Replication Health      -->  Is replication lagging?
       |
4. Slow Query Analysis     -->  Which queries are slow and why?
       |
5. Index Efficiency        -->  Are queries using indexes effectively?
       |
6. Storage and Cache       -->  Is WiredTiger cache under pressure?
       |
7. Connection Analysis     -->  Are connections exhausted or leaked?
```

Always start with `db.serverStatus()` and `db.currentOp()`. They tell you where the bottleneck is before you dig into individual queries.

---

## Section 1: Server Status and Health

### 1.1 Full Server Status

```javascript
// Complete server status (all sections)
db.serverStatus()
```

**When to use:** Starting point for any investigation. Returns a massive document; read specific sections below.

### 1.2 Server Uptime and Host Info

```javascript
// Server uptime in seconds
db.serverStatus().uptime

// Host information (OS, CPU, memory)
db.hostInfo()

// Specific host details
db.hostInfo().system     // hostname, cpuAddrSize, memSizeMB, numCores
db.hostInfo().os         // type, name, version
db.hostInfo().extra      // cpuFeatures, pageSize
```

**Look for:** After a restart, check `uptime` to confirm. `memSizeMB` should match expected RAM allocation.

### 1.3 Build Info and Feature Compatibility

```javascript
// MongoDB version and build details
db.serverBuildInfo()

// Feature compatibility version (FCV) -- determines available features
db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })

// Set FCV (required step during upgrade)
db.adminCommand({ setFeatureCompatibilityVersion: "7.0" })
```

### 1.4 Database Statistics

```javascript
// Stats for the current database
db.stats()

// Stats for all databases
db.adminCommand({ listDatabases: 1, nameOnly: false })

// Human-readable sizes
db.stats(1024 * 1024)  // sizes in MB
```

**Key fields:**
| Field | Meaning | Concern If |
|---|---|---|
| `dataSize` | Uncompressed size of all documents | Much larger than expected |
| `storageSize` | On-disk size (compressed) | Growing faster than data |
| `indexSize` | Total size of all indexes | Larger than data size |
| `objects` | Document count | Unexpected count |
| `avgObjSize` | Average document size | > 1MB (schema design issue) |

### 1.5 Collection Statistics

```javascript
// Detailed collection stats
db.orders.stats()

// Specific fields
db.orders.stats().count           // Document count
db.orders.stats().size            // Uncompressed data size
db.orders.stats().storageSize     // On-disk compressed size
db.orders.stats().nindexes        // Number of indexes
db.orders.stats().totalIndexSize  // Total index size
db.orders.stats().indexSizes      // Size per index

// All collections sorted by size
db.getCollectionNames().forEach(c => {
  const s = db.getCollection(c).stats();
  print(`${c}: docs=${s.count}, dataSize=${(s.size/1024/1024).toFixed(1)}MB, storageSize=${(s.storageSize/1024/1024).toFixed(1)}MB, indexes=${s.nindexes}, indexSize=${(s.totalIndexSize/1024/1024).toFixed(1)}MB`);
})
```

### 1.6 Operation Counters

```javascript
// Operations since server start
db.serverStatus().opcounters
// { insert: N, query: N, update: N, delete: N, getmore: N, command: N }

// For replica set operations
db.serverStatus().opcountersRepl
```

**What to look for:**
- Sudden drop in any counter: potential application issue or connectivity problem
- `getmore` much higher than `query`: large result sets being iterated with cursors
- `command` very high relative to data ops: excessive administrative commands

### 1.7 Operation Latency Statistics

```javascript
// Latency histograms (microseconds)
db.serverStatus().opLatencies

// Reads
db.serverStatus().opLatencies.reads
// { latency: totalMicroseconds, ops: count, histogram: [...] }

// Writes
db.serverStatus().opLatencies.writes

// Commands
db.serverStatus().opLatencies.commands

// Calculate average latency
const reads = db.serverStatus().opLatencies.reads;
print(`Avg read latency: ${(reads.latency / reads.ops / 1000).toFixed(2)} ms`);
const writes = db.serverStatus().opLatencies.writes;
print(`Avg write latency: ${(writes.latency / writes.ops / 1000).toFixed(2)} ms`);
```

**Thresholds:**
- Average read latency > 5ms: investigate index usage and cache pressure
- Average write latency > 10ms: investigate write concern, journaling, or disk I/O
- Latency spike in histogram at high percentiles: tail latency issue (often cache eviction or checkpoint)

---

## Section 2: Current Operations

### 2.1 All Active Operations

```javascript
// All currently running operations
db.currentOp({ active: true })

// Count of active operations
db.currentOp({ active: true }).inprog.length
```

### 2.2 Long-Running Operations

```javascript
// Operations running longer than 10 seconds
db.currentOp({
  active: true,
  secs_running: { $gte: 10 }
})

// Long-running operations with details
db.currentOp({ active: true, secs_running: { $gte: 10 } }).inprog.forEach(op => {
  print(`OpId: ${op.opid}, Type: ${op.op}, NS: ${op.ns}, Secs: ${op.secs_running}, Client: ${op.client}`);
  if (op.command) printjson(op.command);
})
```

### 2.3 Operations Waiting for Locks

```javascript
// Operations blocked waiting for a lock
db.currentOp({ waitingForLock: true })

// Count of lock waiters
db.currentOp({ waitingForLock: true }).inprog.length
```

**Concern if:** Lock waiters > 0 sustained. Check what operation holds the lock.

### 2.4 Operations by Type

```javascript
// All active writes
db.currentOp({ active: true, op: { $in: ["insert", "update", "delete"] } })

// All active queries
db.currentOp({ active: true, op: "query" })

// All active commands (aggregate, createIndex, etc.)
db.currentOp({ active: true, op: "command" })
```

### 2.5 Operations by Namespace

```javascript
// All operations on a specific collection
db.currentOp({ active: true, ns: "mydb.orders" })

// All operations on a specific database
db.currentOp({ active: true, ns: /^mydb\./ })
```

### 2.6 Kill Operations

```javascript
// Kill a specific operation by opid
db.killOp(12345)

// Kill all operations on a specific collection running > 60s
db.currentOp({ active: true, ns: "mydb.orders", secs_running: { $gte: 60 } }).inprog.forEach(op => {
  print(`Killing opid ${op.opid}: ${op.op} on ${op.ns}, running ${op.secs_running}s`);
  db.killOp(op.opid);
})
```

### 2.7 Index Build Progress

```javascript
// Monitor in-progress index builds
db.currentOp({ active: true, "command.createIndexes": { $exists: true } })

// Detailed index build progress
db.currentOp({ active: true }).inprog.filter(op => op.msg && op.msg.includes("Index Build")).forEach(op => {
  print(`Index build on ${op.ns}: ${op.msg}, Progress: ${JSON.stringify(op.progress)}`);
})

// Progress for currentOp on admin database (aggregation form, 4.0+)
db.adminCommand({
  currentOp: true,
  $all: true,
  "command.createIndexes": { $exists: true }
})
```

### 2.8 Aggregation Pipeline Operations

```javascript
// Currently running aggregation pipelines
db.currentOp({
  active: true,
  op: "command",
  "command.aggregate": { $exists: true }
})
```

---

## Section 3: Replication Diagnostics

### 3.1 Replica Set Status

```javascript
// Full replica set status
rs.status()

// Key fields to check:
rs.status().members.forEach(m => {
  print(`${m.name}: state=${m.stateStr}, health=${m.health}, uptime=${m.uptime}s, ` +
        `optime=${JSON.stringify(m.optime)}, ` +
        `lastHeartbeat=${m.lastHeartbeat}, ` +
        `lastHeartbeatRecv=${m.lastHeartbeatRecv}, ` +
        `syncSourceHost=${m.syncSourceHost || 'N/A'}`);
})
```

**Member states:**
| State | Meaning | Action |
|---|---|---|
| PRIMARY (1) | Accepting writes | Normal |
| SECONDARY (2) | Replicating from primary/sync source | Normal |
| RECOVERING (3) | Performing initial sync or recovery | Wait; check logs if stuck |
| STARTUP2 (5) | Loading config / initial sync data | Wait |
| ARBITER (7) | Arbiter (no data) | Normal |
| DOWN (8) | Unreachable | Check network/process |
| ROLLBACK (9) | Rolling back unreplicated writes | Will resolve; check oplog |
| REMOVED (10) | Removed from replica set | Reconfigure if unintentional |

### 3.2 Replication Lag

```javascript
// Oplog window (how much oplog history is available)
rs.printReplicationInfo()
// Output: configured oplog size, log length (hours), oplog first/last event times

// Secondary replication lag
rs.printSecondaryReplicationInfo()
// Output: per-secondary lag in seconds behind primary

// Programmatic lag calculation
const primary = rs.status().members.find(m => m.stateStr === "PRIMARY");
rs.status().members.filter(m => m.stateStr === "SECONDARY").forEach(m => {
  const lagMs = primary.optimeDate - m.optimeDate;
  print(`${m.name}: lag = ${lagMs / 1000} seconds`);
})
```

**Thresholds:**
- Lag < 1s: healthy
- Lag 1-10s: monitor closely; may be transient
- Lag > 10s: investigate -- slow secondary, network issue, or primary write rate exceeds secondary apply rate
- Lag > 60s: critical -- secondary at risk of falling off the oplog (requiring initial sync)

### 3.3 Oplog Size and Window

```javascript
// Oplog details
use local
db.oplog.rs.stats()

// Oplog size in MB
const oplogStats = db.oplog.rs.stats();
print(`Oplog size: ${(oplogStats.maxSize / 1024 / 1024).toFixed(0)} MB`);
print(`Oplog used: ${(oplogStats.size / 1024 / 1024).toFixed(0)} MB`);

// First and last oplog entries (oplog time window)
const first = db.oplog.rs.find().sort({ $natural: 1 }).limit(1).next();
const last = db.oplog.rs.find().sort({ $natural: -1 }).limit(1).next();
const windowHours = (last.ts.getTime() - first.ts.getTime()) / 3600;
print(`Oplog window: ${windowHours.toFixed(1)} hours`);

// Resize oplog at runtime (3.6+)
db.adminCommand({ replSetResizeOplog: 1, size: 51200 })  // 50GB in MB
```

**Guidance:** Oplog window should be at least 24-72 hours. If it is less than 24 hours, increase the oplog size or reduce write volume.

### 3.4 Replication Configuration

```javascript
// Current replica set configuration
rs.conf()

// Specific settings
rs.conf().settings
rs.conf().members.forEach(m => {
  print(`${m.host}: priority=${m.priority}, votes=${m.votes}, hidden=${m.hidden}, arbiterOnly=${m.arbiterOnly}, slaveDelay=${m.secondaryDelaySecs || m.slaveDelay || 0}`);
})
```

### 3.5 Step Down Primary

```javascript
// Step down primary (triggers election)
rs.stepDown(60)  // step down for 60 seconds; another member becomes primary

// Step down with catch-up period
rs.stepDown(120, 30)  // 120s step-down, 30s for secondaries to catch up first

// Freeze a secondary (prevent it from seeking election)
rs.freeze(300)  // freeze for 300 seconds
```

### 3.6 Replication Metrics

```javascript
// Replication-specific server status
db.serverStatus().repl
// { setName, ismaster, secondary, primary, hosts, me, electionId, ... }

// Replication buffer (oplog fetcher)
db.serverStatus().metrics.repl.buffer
// { count, maxSizeBytes, sizeBytes }

// Replication apply batch stats
db.serverStatus().metrics.repl.apply
// { batches: { num, totalMillis }, ops }

// Replication network stats
db.serverStatus().metrics.repl.network
// { bytes, getmores: { num, totalMillis }, ops, readersCreated }
```

**Look for:**
- `buffer.sizeBytes` near `buffer.maxSizeBytes`: secondary cannot apply ops fast enough
- `apply.batches.totalMillis / apply.batches.num` increasing: apply getting slower

---

## Section 4: Sharding Diagnostics

### 4.1 Sharding Status

```javascript
// Full sharding status
sh.status()

// Verbose (shows chunk distribution)
sh.status(true)

// JSON format with more detail
db.adminCommand({ balancerStatus: 1 })
```

### 4.2 Balancer Status

```javascript
// Is the balancer running?
sh.balancerStatus()

// Balancer state (on/off)
sh.getBalancerState()

// Is the balancer currently running a migration?
sh.isBalancerRunning()

// Stop/start the balancer
sh.stopBalancer()
sh.startBalancer()

// Balancer window (only run during off-hours)
db.getSiblingDB("config").settings.updateOne(
  { _id: "balancer" },
  { $set: { activeWindow: { start: "02:00", stop: "06:00" } } },
  { upsert: true }
)
```

### 4.3 Chunk Distribution

```javascript
// Chunk count per shard for each collection
db.getSiblingDB("config").chunks.aggregate([
  { $group: { _id: { ns: "$ns", shard: "$shard" }, count: { $sum: 1 } } },
  { $sort: { "_id.ns": 1, "_id.shard": 1 } }
])

// Chunk count per shard for a specific collection
db.getSiblingDB("config").chunks.aggregate([
  { $match: { ns: "mydb.orders" } },
  { $group: { _id: "$shard", count: { $sum: 1 } } },
  { $sort: { count: -1 } }
])

// Find jumbo chunks (cannot be split)
db.getSiblingDB("config").chunks.find({ jumbo: true })

// Chunk ranges for a collection
db.getSiblingDB("config").chunks.find(
  { ns: "mydb.orders" },
  { min: 1, max: 1, shard: 1, _id: 0 }
).sort({ min: 1 })
```

**Concern if:**
- One shard has significantly more chunks than others (imbalanced distribution)
- Jumbo chunks exist (indicates low-cardinality shard key or data skew)

### 4.4 Migration Activity

```javascript
// Recent migrations from changelog
db.getSiblingDB("config").changelog.find(
  { what: { $regex: /moveChunk/ } }
).sort({ time: -1 }).limit(20)

// Active migrations
db.adminCommand({ currentOp: true, desc: /moveChunk/ })

// Failed migrations
db.getSiblingDB("config").changelog.find(
  { what: "moveChunk.error" }
).sort({ time: -1 }).limit(10)
```

### 4.5 Orphaned Documents

```javascript
// Check for orphaned documents on a shard (run on each shard)
// Orphans are documents left behind after a failed migration
db.orders.find().hint({ _id: 1 }).count()  // All documents on this shard
// Compare with expected count from config.chunks ranges

// Shard-level stats
db.orders.stats().shards  // Per-shard counts for sharded collections

// Clean up orphans (4.4+, runs automatically via range deleter)
db.adminCommand({ cleanupOrphaned: "mydb.orders" })
```

### 4.6 Shard Key Analysis

```javascript
// Collection metadata (shard key, unique)
db.getSiblingDB("config").collections.find(
  { _id: "mydb.orders" },
  { key: 1, unique: 1, noBalance: 1 }
)

// Shard key cardinality check
db.orders.aggregate([
  { $group: { _id: "$shard_key_field", count: { $sum: 1 } } },
  { $group: { _id: null, distinctValues: { $sum: 1 }, maxFreq: { $max: "$count" }, avgFreq: { $avg: "$count" } } }
])
```

### 4.7 Zone (Tag) Configuration

```javascript
// View zones
sh.status()  // Shows zones at the bottom

// Zone assignments
db.getSiblingDB("config").tags.find()

// Add zone
sh.addShardTag("shard01", "US-EAST")
sh.addTagRange("mydb.orders", { region: "US" }, { region: "US~" }, "US-EAST")
```

---

## Section 5: Performance and Slow Query Analysis

### 5.1 Database Profiler

```javascript
// Check current profiling level
db.getProfilingStatus()

// Enable profiling for slow operations (> 100ms)
db.setProfilingLevel(1, { slowms: 100 })

// Enable profiling for ALL operations (caution: high overhead)
db.setProfilingLevel(2)

// Disable profiling
db.setProfilingLevel(0)

// Enable with sample rate (profile 10% of operations)
db.setProfilingLevel(1, { slowms: 100, sampleRate: 0.1 })
```

### 5.2 Query Profiler Data

```javascript
// Recent slow queries
db.system.profile.find().sort({ ts: -1 }).limit(10).forEach(printjson)

// Slowest queries (top 10 by millis)
db.system.profile.find().sort({ millis: -1 }).limit(10).forEach(p => {
  print(`${p.millis}ms | ${p.op} | ${p.ns} | docsExamined=${p.docsExamined} | keysExamined=${p.keysExamined} | nreturned=${p.nreturned}`);
  if (p.command) printjson(p.command);
})

// Slow queries on a specific collection
db.system.profile.find({
  ns: "mydb.orders",
  millis: { $gte: 200 }
}).sort({ ts: -1 }).limit(20)

// Queries doing collection scans
db.system.profile.find({
  "planSummary": "COLLSCAN",
  millis: { $gte: 50 }
}).sort({ millis: -1 })

// Queries with high docsExamined / nreturned ratio
db.system.profile.find({
  docsExamined: { $gte: 1000 },
  $expr: { $gt: [{ $divide: ["$docsExamined", { $max: ["$nreturned", 1] }] }, 100] }
}).sort({ millis: -1 }).limit(10)

// Aggregation pipelines in profiler
db.system.profile.find({
  "command.aggregate": { $exists: true },
  millis: { $gte: 100 }
}).sort({ millis: -1 })

// Profiler summary by operation type
db.system.profile.aggregate([
  { $group: {
    _id: { op: "$op", ns: "$ns" },
    count: { $sum: 1 },
    avgMillis: { $avg: "$millis" },
    maxMillis: { $max: "$millis" },
    totalMillis: { $sum: "$millis" }
  }},
  { $sort: { totalMillis: -1 } },
  { $limit: 20 }
])
```

### 5.3 Explain Plans

```javascript
// Query execution stats (most useful mode)
db.orders.find({ status: "active", total: { $gte: 100 } })
  .sort({ date: -1 })
  .explain("executionStats")

// All plans considered by the optimizer
db.orders.find({ status: "active" })
  .explain("allPlansExecution")

// Aggregation pipeline explain
db.orders.explain("executionStats").aggregate([
  { $match: { status: "active" } },
  { $group: { _id: "$category", total: { $sum: "$amount" } } },
  { $sort: { total: -1 } }
])

// Quick explain summary function
function explainSummary(explainResult) {
  const stats = explainResult.executionStats;
  print(`Execution time: ${stats.executionTimeMillis}ms`);
  print(`Documents examined: ${stats.totalDocsExamined}`);
  print(`Keys examined: ${stats.totalKeysExamined}`);
  print(`Documents returned: ${stats.nReturned}`);
  print(`Efficiency (returned/examined): ${(stats.nReturned / Math.max(stats.totalDocsExamined, 1) * 100).toFixed(1)}%`);
  const plan = explainResult.queryPlanner.winningPlan;
  print(`Winning plan: ${JSON.stringify(plan.stage)}`);
  if (plan.inputStage) print(`Input stage: ${plan.inputStage.stage} (index: ${plan.inputStage.indexName || 'none'})`);
}
```

### 5.4 Slow Query Log Analysis

```javascript
// Get recent log entries (4.4+ structured JSON logs)
db.adminCommand({ getLog: "global" })

// Filter for slow queries in the log
db.adminCommand({ getLog: "global" }).log.filter(entry => {
  try {
    const parsed = JSON.parse(entry);
    return parsed.attr && parsed.attr.durationMillis > 100;
  } catch(e) { return false; }
}).slice(-20).forEach(entry => print(entry))

// Set slow query threshold (default: 100ms)
db.adminCommand({ setParameter: 1, slowOpThresholdMs: 50 })

// Set per-component log verbosity
db.adminCommand({ setParameter: 1, logComponentVerbosity: {
  command: { verbosity: 1 },
  query: { verbosity: 1 }
}})
```

### 5.5 $currentOp Aggregation (Advanced)

```javascript
// Using $currentOp aggregation stage (more flexible than db.currentOp)
db.adminCommand({
  aggregate: 1,
  pipeline: [
    { $currentOp: { allUsers: true, idleConnections: false } },
    { $match: { active: true, secs_running: { $gte: 5 } } },
    { $project: {
      opid: 1, op: 1, ns: 1, secs_running: 1, client: 1,
      command: 1, waitingForLock: 1, lockStats: 1
    }},
    { $sort: { secs_running: -1 } }
  ],
  cursor: {}
})
```

---

## Section 6: Index Analysis

### 6.1 List All Indexes

```javascript
// Indexes on a collection
db.orders.getIndexes()

// All indexes in the database
db.getCollectionNames().forEach(c => {
  const indexes = db.getCollection(c).getIndexes();
  print(`\n=== ${c} (${indexes.length} indexes) ===`);
  indexes.forEach(idx => print(`  ${idx.name}: ${JSON.stringify(idx.key)}`));
})
```

### 6.2 Index Usage Statistics

```javascript
// Index usage stats (accesses since last restart)
db.orders.aggregate([{ $indexStats: {} }]).forEach(idx => {
  print(`${idx.name}: ops=${idx.accesses.ops}, since=${idx.accesses.since}`);
})

// Find unused indexes (ops == 0)
db.orders.aggregate([{ $indexStats: {} }]).forEach(idx => {
  if (idx.accesses.ops === 0 && idx.name !== "_id_") {
    const size = db.orders.stats().indexSizes[idx.name] || 0;
    print(`UNUSED: ${idx.name} (${(size/1024/1024).toFixed(1)} MB)`);
  }
})

// Find unused indexes across all collections
db.getCollectionNames().forEach(c => {
  db.getCollection(c).aggregate([{ $indexStats: {} }]).forEach(idx => {
    if (idx.accesses.ops === 0 && idx.name !== "_id_") {
      print(`UNUSED: ${c}.${idx.name}`);
    }
  });
})
```

### 6.3 Index Size Analysis

```javascript
// Index sizes for a collection
const stats = db.orders.stats();
print(`Data: ${(stats.size/1024/1024).toFixed(1)} MB`);
print(`Total indexes: ${(stats.totalIndexSize/1024/1024).toFixed(1)} MB`);
Object.entries(stats.indexSizes).forEach(([name, size]) => {
  print(`  ${name}: ${(size/1024/1024).toFixed(1)} MB`);
})

// All collection index sizes
db.getCollectionNames().forEach(c => {
  const s = db.getCollection(c).stats();
  if (s.totalIndexSize > 1024 * 1024) {  // > 1MB
    print(`${c}: indexSize=${(s.totalIndexSize/1024/1024).toFixed(1)}MB, dataSize=${(s.size/1024/1024).toFixed(1)}MB, ratio=${(s.totalIndexSize/Math.max(s.size,1)).toFixed(2)}`);
  }
})
```

**Concern if:** Total index size > data size (indicates too many or too broad indexes).

### 6.4 Covered Queries Detection

```javascript
// A covered query is one where all fields are in the index (no FETCH stage)
// Check with explain:
const explain = db.orders.find(
  { status: "active" },
  { status: 1, date: 1, _id: 0 }  // Projection must include ONLY indexed fields
).explain("executionStats");

// If totalDocsExamined == 0 and totalKeysExamined > 0, it's a covered query
const stats = explain.executionStats;
print(`Covered query: ${stats.totalDocsExamined === 0 && stats.totalKeysExamined > 0}`);
```

### 6.5 Redundant Index Detection

```javascript
// Find indexes that are prefixes of other compound indexes
function findRedundantIndexes(collection) {
  const indexes = db.getCollection(collection).getIndexes();
  const keys = indexes.map(i => ({ name: i.name, fields: Object.keys(i.key) }));
  keys.forEach(idx => {
    keys.forEach(other => {
      if (idx.name !== other.name && idx.fields.length < other.fields.length) {
        const isPrefix = idx.fields.every((f, i) => f === other.fields[i]);
        if (isPrefix) {
          print(`REDUNDANT: ${collection}.${idx.name} ${JSON.stringify(idx.fields)} is a prefix of ${other.name} ${JSON.stringify(other.fields)}`);
        }
      }
    });
  });
}
db.getCollectionNames().forEach(c => findRedundantIndexes(c));
```

### 6.6 Missing Index Suggestions

```javascript
// Queries doing collection scans (from profiler)
db.system.profile.aggregate([
  { $match: { planSummary: "COLLSCAN", millis: { $gte: 50 } } },
  { $group: {
    _id: { ns: "$ns", queryHash: "$queryHash" },
    count: { $sum: 1 },
    avgMillis: { $avg: "$millis" },
    sampleQuery: { $first: "$command" }
  }},
  { $sort: { count: -1 } },
  { $limit: 20 }
])
```

---

## Section 7: Connection Monitoring

### 7.1 Connection Counts

```javascript
// Current connection stats
db.serverStatus().connections
// { current, available, totalCreated, rejected, active }

// Connection summary
const conn = db.serverStatus().connections;
print(`Current: ${conn.current}`);
print(`Available: ${conn.available}`);
print(`Active: ${conn.active}`);
print(`Total created: ${conn.totalCreated}`);
print(`Rejected (limit reached): ${conn.rejected || 0}`);
print(`Utilization: ${(conn.current / (conn.current + conn.available) * 100).toFixed(1)}%`);
```

**Thresholds:**
- Utilization > 80%: connection leak or pool misconfiguration
- `rejected > 0`: connections being turned away; increase `maxIncomingConnections`
- `current` growing without plateau: connection leak in application

### 7.2 Connection Details by Client

```javascript
// Connections grouped by client application/IP
db.currentOp({ active: false, op: "" }).inprog  // idle connections

// Active connections by client IP
db.aggregate([
  { $currentOp: { allUsers: true, idleConnections: true } },
  { $group: { _id: "$client", count: { $sum: 1 } } },
  { $sort: { count: -1 } },
  { $limit: 20 }
])

// Connections by application name
db.aggregate([
  { $currentOp: { allUsers: true, idleConnections: true } },
  { $group: { _id: "$appName", count: { $sum: 1 }, active: { $sum: { $cond: ["$active", 1, 0] } } } },
  { $sort: { count: -1 } }
])
```

### 7.3 Connection Pool on Server Side

```javascript
// Network statistics
db.serverStatus().network
// { bytesIn, bytesOut, numRequests, ... }

// Service executor stats (thread pool)
db.serverStatus().network.serviceExecutorTaskStats
```

---

## Section 8: Storage and Disk Analysis

### 8.1 Storage Size vs Data Size

```javascript
// Compression ratio analysis per collection
db.getCollectionNames().forEach(c => {
  const s = db.getCollection(c).stats();
  if (s.size > 0) {
    const ratio = s.size / s.storageSize;
    print(`${c}: dataSize=${(s.size/1024/1024).toFixed(1)}MB, storageSize=${(s.storageSize/1024/1024).toFixed(1)}MB, compressionRatio=${ratio.toFixed(2)}x`);
  }
})
```

### 8.2 Disk Space Usage

```javascript
// Total database sizes
db.adminCommand({ listDatabases: 1 }).databases.forEach(d => {
  print(`${d.name}: ${(d.sizeOnDisk/1024/1024/1024).toFixed(2)} GB`);
})

// Free disk space (from hostInfo, may not be available on all platforms)
db.hostInfo().system
```

### 8.3 Collection Scan Performance

```javascript
// Estimate full collection scan time
const stats = db.orders.stats();
const avgObjSize = stats.avgObjSize;
const count = stats.count;
print(`Collection: ${count} documents, avg ${avgObjSize} bytes`);
print(`Full scan reads: ~${(stats.storageSize / (16 * 1024)).toFixed(0)} 16KB pages`);
```

### 8.4 Document Size Distribution

```javascript
// Sample document sizes
db.orders.aggregate([
  { $sample: { size: 10000 } },
  { $project: { size: { $bsonSize: "$$ROOT" } } },
  { $group: {
    _id: null,
    avgSize: { $avg: "$size" },
    minSize: { $min: "$size" },
    maxSize: { $max: "$size" },
    p50: { $percentile: { input: "$size", p: [0.5], method: "approximate" } },
    p95: { $percentile: { input: "$size", p: [0.95], method: "approximate" } },
    p99: { $percentile: { input: "$size", p: [0.99], method: "approximate" } }
  }}
])
```

### 8.5 WiredTiger Storage Engine Stats

```javascript
// WiredTiger engine-level statistics
db.serverStatus().wiredTiger

// Block manager (I/O)
db.serverStatus().wiredTiger["block-manager"]
// { "blocks read", "blocks written", "bytes read", "bytes written" }

// Concurrency control
db.serverStatus().wiredTiger.concurrentTransactions
// { write: { out, available, totalTickets }, read: { out, available, totalTickets } }

// Transaction stats
db.serverStatus().wiredTiger.transaction
```

---

## Section 9: Memory and Cache Analysis

### 9.1 WiredTiger Cache Statistics

```javascript
// Full cache stats
const cache = db.serverStatus().wiredTiger.cache;

// Key metrics
print(`Cache configured: ${(cache["maximum bytes configured"] / 1024/1024/1024).toFixed(2)} GB`);
print(`Cache used: ${(cache["bytes currently in the cache"] / 1024/1024/1024).toFixed(2)} GB`);
print(`Cache utilization: ${(cache["bytes currently in the cache"] / cache["maximum bytes configured"] * 100).toFixed(1)}%`);
print(`Cache dirty: ${(cache["tracked dirty bytes in the cache"] / 1024/1024).toFixed(1)} MB`);
print(`Cache dirty %: ${(cache["tracked dirty bytes in the cache"] / cache["maximum bytes configured"] * 100).toFixed(2)}%`);
print(`Pages read into cache: ${cache["pages read into cache"]}`);
print(`Pages written from cache: ${cache["pages written from cache"]}`);
print(`Pages evicted by app threads: ${cache["pages evicted by application threads"]}`);
print(`Unmodified pages evicted: ${cache["unmodified pages evicted"]}`);
print(`Modified pages evicted: ${cache["modified pages evicted"]}`);
```

**Critical thresholds:**
| Metric | Warning | Critical | Meaning |
|---|---|---|---|
| Cache utilization | > 80% | > 95% | Working set exceeds cache; eviction under pressure |
| Cache dirty % | > 10% | > 20% | Writes faster than checkpoints can flush |
| Pages evicted by app threads | > 0 sustained | > 100/s | Application threads doing eviction work (latency impact) |

### 9.2 WiredTiger Cache Pressure Over Time

```javascript
// Snapshot cache metrics for comparison (run periodically)
function cacheSample() {
  const c = db.serverStatus().wiredTiger.cache;
  return {
    ts: new Date(),
    usedGB: (c["bytes currently in the cache"] / 1024/1024/1024).toFixed(2),
    dirtyMB: (c["tracked dirty bytes in the cache"] / 1024/1024).toFixed(1),
    utilPct: (c["bytes currently in the cache"] / c["maximum bytes configured"] * 100).toFixed(1),
    appEvict: c["pages evicted by application threads"],
    pagesIn: c["pages read into cache"],
    pagesOut: c["pages written from cache"]
  };
}
printjson(cacheSample());
```

### 9.3 WiredTiger Ticket (Concurrency) Analysis

```javascript
// Read/write ticket availability
const tickets = db.serverStatus().wiredTiger.concurrentTransactions;
print(`Read tickets: ${tickets.read.out} used / ${tickets.read.totalTickets} total (${tickets.read.available} available)`);
print(`Write tickets: ${tickets.write.out} used / ${tickets.write.totalTickets} total (${tickets.write.available} available)`);
```

**Concern if:**
- Available tickets near 0: WiredTiger is at maximum concurrency; operations are queueing
- Default tickets: 128 read, 128 write. If consistently exhausted, investigate slow operations consuming tickets

### 9.4 Memory Consumption Analysis

```javascript
// Memory reported by server
db.serverStatus().mem
// { bits: 64, resident: MB, virtual: MB, supported: true }

// tcmalloc stats (memory allocator details)
db.serverStatus().tcmalloc
```

**Key memory fields:**
- `resident`: Actual RAM usage (should be close to cacheSizeGB + overhead)
- `virtual`: Virtual memory (can be much larger due to memory-mapped files)
- If `resident` >> cacheSizeGB + 2GB: potential memory leak or excessive connection memory

---

## Section 10: Lock Analysis

### 10.1 Global Lock Statistics

```javascript
// Global lock stats
const locks = db.serverStatus().globalLock;
print(`Active clients: readers=${locks.activeClients.readers}, writers=${locks.activeClients.writers}`);
print(`Current queue: readers=${locks.currentQueue.readers}, writers=${locks.currentQueue.writers}`);
print(`Total time locked (microsec): ${locks.totalTime}`);
```

**Concern if:**
- `currentQueue.writers > 0` sustained: write operations are blocked
- `currentQueue.readers > 10` sustained: read operations are queueing behind a write lock

### 10.2 Lock Statistics by Type

```javascript
// Per-type lock stats
const lockStats = db.serverStatus().locks;
Object.entries(lockStats).forEach(([type, stats]) => {
  print(`${type}:`);
  if (stats.acquireCount) {
    Object.entries(stats.acquireCount).forEach(([mode, count]) => {
      print(`  acquire ${mode}: ${count}`);
    });
  }
  if (stats.acquireWaitCount) {
    Object.entries(stats.acquireWaitCount).forEach(([mode, count]) => {
      print(`  WAIT ${mode}: ${count}`);
    });
  }
  if (stats.timeAcquiringMicros) {
    Object.entries(stats.timeAcquiringMicros).forEach(([mode, time]) => {
      print(`  time acquiring ${mode}: ${(time/1000).toFixed(1)}ms`);
    });
  }
})
```

**Key lock types:**
- `Global`: Instance-wide locks
- `Database`: Per-database locks
- `Collection`: Per-collection locks
- `Mutex`: Internal mutexes
- `oplog`: Oplog access locks

### 10.3 Lock Percentage Calculation

```javascript
// Calculate lock wait percentage
const status = db.serverStatus();
const uptime = status.uptime;
const lockStats = status.locks.Global;
if (lockStats.acquireWaitCount) {
  const totalAcquires = Object.values(lockStats.acquireCount).reduce((a, b) => a + b, 0);
  const totalWaits = Object.values(lockStats.acquireWaitCount).reduce((a, b) => a + b, 0);
  print(`Lock wait percentage: ${(totalWaits / totalAcquires * 100).toFixed(4)}%`);
}
```

---

## Section 11: Network and Connection Diagnostics

### 11.1 Network I/O Statistics

```javascript
// Network throughput
const net = db.serverStatus().network;
print(`Bytes in: ${(net.bytesIn / 1024/1024/1024).toFixed(2)} GB`);
print(`Bytes out: ${(net.bytesOut / 1024/1024/1024).toFixed(2)} GB`);
print(`Total requests: ${net.numRequests}`);
```

### 11.2 Slow Connections

```javascript
// Connections with long-running operations (potential slow clients)
db.aggregate([
  { $currentOp: { allUsers: true, idleConnections: false } },
  { $match: { secs_running: { $gte: 30 } } },
  { $project: { client: 1, appName: 1, ns: 1, op: 1, secs_running: 1 } },
  { $sort: { secs_running: -1 } }
])
```

### 11.3 Connection Churn

```javascript
// Connection creation rate (compare totalCreated over time)
const c1 = db.serverStatus().connections.totalCreated;
// Wait 60 seconds...
const c2 = db.serverStatus().connections.totalCreated;
print(`New connections/min: ${c2 - c1}`);
// High churn (> 100/min) indicates missing connection pooling
```

---

## Section 12: Log Analysis

### 12.1 Server Log Access

```javascript
// Get recent log entries
const log = db.adminCommand({ getLog: "global" });
print(`Log entries: ${log.log.length}`);

// Last 20 entries
log.log.slice(-20).forEach(entry => print(entry))

// Available log types
db.adminCommand({ getLog: "*" })
// Returns: { names: ["global", "startupWarnings"] }

// Startup warnings (always check after deployment)
db.adminCommand({ getLog: "startupWarnings" }).log.forEach(l => print(l))
```

### 12.2 Parse Structured Logs for Slow Queries

```javascript
// Parse JSON logs for slow operations (4.4+)
db.adminCommand({ getLog: "global" }).log.forEach(entry => {
  try {
    const parsed = JSON.parse(entry);
    if (parsed.attr && parsed.attr.durationMillis && parsed.attr.durationMillis > 200) {
      print(`[${parsed.t.$date}] ${parsed.attr.durationMillis}ms | ${parsed.attr.ns || ''} | ${parsed.msg}`);
    }
  } catch(e) {}
})
```

### 12.3 Log Component Verbosity

```javascript
// Get current verbosity settings
db.adminCommand({ getParameter: 1, logComponentVerbosity: 1 })

// Increase query logging temporarily (0-5, default 0)
db.adminCommand({ setParameter: 1, logComponentVerbosity: {
  query: { verbosity: 2 },
  write: { verbosity: 1 }
}})

// Reset to defaults
db.adminCommand({ setParameter: 1, logComponentVerbosity: {
  query: { verbosity: 0 },
  write: { verbosity: 0 }
}})
```

---

## Section 13: FTDC (Full-Time Diagnostic Data Capture)

### 13.1 FTDC Overview

FTDC automatically captures diagnostic data every 1 second and writes it to `diagnostic.data/` in the dbpath. This data is essential for historical analysis.

```javascript
// FTDC parameters
db.adminCommand({ getParameter: 1, diagnosticDataCollectionEnabled: 1 })
db.adminCommand({ getParameter: 1, diagnosticDataCollectionDirectorySizeMB: 1 })
db.adminCommand({ getParameter: 1, diagnosticDataCollectionFileSizeMB: 1 })
db.adminCommand({ getParameter: 1, diagnosticDataCollectionPeriodMillis: 1 })

// Default: 200MB directory limit, 10MB per file, 1-second interval
```

### 13.2 FTDC Analysis

```bash
# Decode FTDC data using mongod (command line)
# FTDC files are in dbpath/diagnostic.data/
ls /data/db/diagnostic.data/

# Use ftdc tool (part of MongoDB tools) or upload to Atlas for analysis
# Or use third-party tools like keyhole:
# go install github.com/simagix/keyhole@latest
# keyhole --ftdc /data/db/diagnostic.data/

# Export FTDC to JSON for analysis
mongod --ftdcDecode /data/db/diagnostic.data/metrics.2025-03-15T00-00-00Z > ftdc_output.json
```

### 13.3 FTDC in Atlas

In Atlas, FTDC data is available in the Performance Advisor and Real-Time Performance panel. Use Atlas CLI:

```bash
# Download FTDC data from Atlas
atlas logs download <hostname> --type ftdc --output ftdc_data.tar.gz
```

---

## Section 14: Atlas-Specific Diagnostics

### 14.1 Atlas CLI Commands

```bash
# Cluster status
atlas clusters describe myCluster

# List clusters
atlas clusters list

# Cluster metrics
atlas metrics processes myCluster --period P1D --granularity PT1M --type CONNECTIONS

# Available metric types:
# CONNECTIONS, OPCOUNTER_CMD, OPCOUNTER_QUERY, OPCOUNTER_INSERT, OPCOUNTER_UPDATE,
# OPCOUNTER_DELETE, OPCOUNTER_GETMORE, LOGICAL_SIZE, CACHE_BYTES_READ_INTO,
# CACHE_DIRTY_BYTES, CACHE_USED_BYTES, DOCUMENT_METRICS_RETURNED,
# DOCUMENT_METRICS_INSERTED, DOCUMENT_METRICS_UPDATED, DOCUMENT_METRICS_DELETED,
# QUERY_EXECUTOR_SCANNED, QUERY_EXECUTOR_SCANNED_OBJECTS, SYSTEM_CPU_USER,
# SYSTEM_MEMORY_AVAILABLE, DISK_PARTITION_IOPS_READ, DISK_PARTITION_IOPS_WRITE
```

### 14.2 Atlas Performance Advisor

```bash
# Get performance advisor slow query logs
atlas performanceAdvisor slowQueryLogs list --clusterName myCluster --since 2025-03-15T00:00:00Z

# Get suggested indexes from Performance Advisor
atlas performanceAdvisor suggestedIndexes list --clusterName myCluster

# Get namespace suggestions
atlas performanceAdvisor namespaces list --clusterName myCluster
```

### 14.3 Atlas Alerts

```bash
# List configured alerts
atlas alerts list --projectId <projectId>

# List triggered alerts
atlas alerts list --status OPEN --projectId <projectId>

# Acknowledge an alert
atlas alerts acknowledge <alertId> --projectId <projectId>
```

---

## Section 15: Automation and Health Check Scripts

### 15.1 Comprehensive Health Check

```javascript
// MongoDB Health Check Script
// Run: mongosh --eval 'load("/path/to/healthcheck.js")' mongodb://host:27017

function healthCheck() {
  print("=== MongoDB Health Check ===");
  print(`Time: ${new Date().toISOString()}`);

  // 1. Server info
  const status = db.serverStatus();
  print(`\n--- Server Info ---`);
  print(`Version: ${status.version}`);
  print(`Uptime: ${(status.uptime / 3600).toFixed(1)} hours`);
  print(`Connections: ${status.connections.current} / ${status.connections.current + status.connections.available}`);

  // 2. Replication
  if (status.repl) {
    print(`\n--- Replication ---`);
    print(`Set: ${status.repl.setName}`);
    print(`Is Primary: ${status.repl.ismaster}`);
    try {
      const rsStatus = rs.status();
      rsStatus.members.forEach(m => {
        print(`  ${m.name}: ${m.stateStr} (health: ${m.health})`);
      });
    } catch(e) { print(`  Error: ${e.message}`); }
  }

  // 3. WiredTiger cache
  print(`\n--- WiredTiger Cache ---`);
  const cache = status.wiredTiger.cache;
  const cacheUsedPct = (cache["bytes currently in the cache"] / cache["maximum bytes configured"] * 100);
  const cacheDirtyPct = (cache["tracked dirty bytes in the cache"] / cache["maximum bytes configured"] * 100);
  print(`Cache: ${cacheUsedPct.toFixed(1)}% used, ${cacheDirtyPct.toFixed(2)}% dirty`);
  print(`App evictions: ${cache["pages evicted by application threads"]}`);
  if (cacheUsedPct > 90) print("  WARNING: Cache usage above 90%!");
  if (cacheDirtyPct > 15) print("  WARNING: Dirty cache above 15%!");

  // 4. Connections
  print(`\n--- Connections ---`);
  const connPct = status.connections.current / (status.connections.current + status.connections.available) * 100;
  print(`Utilization: ${connPct.toFixed(1)}%`);
  if (connPct > 80) print("  WARNING: Connection utilization above 80%!");

  // 5. Operations
  print(`\n--- Op Counters ---`);
  const ops = status.opcounters;
  print(`insert=${ops.insert}, query=${ops.query}, update=${ops.update}, delete=${ops.delete}, getmore=${ops.getmore}, command=${ops.command}`);

  // 6. Latency
  print(`\n--- Latency ---`);
  if (status.opLatencies) {
    const readLatency = status.opLatencies.reads.ops > 0 ? status.opLatencies.reads.latency / status.opLatencies.reads.ops / 1000 : 0;
    const writeLatency = status.opLatencies.writes.ops > 0 ? status.opLatencies.writes.latency / status.opLatencies.writes.ops / 1000 : 0;
    print(`Avg read: ${readLatency.toFixed(2)}ms, Avg write: ${writeLatency.toFixed(2)}ms`);
  }

  // 7. Tickets
  print(`\n--- WiredTiger Tickets ---`);
  const tickets = status.wiredTiger.concurrentTransactions;
  print(`Read: ${tickets.read.out}/${tickets.read.totalTickets} used`);
  print(`Write: ${tickets.write.out}/${tickets.write.totalTickets} used`);

  // 8. Long-running ops
  print(`\n--- Long-Running Operations (>30s) ---`);
  const longOps = db.currentOp({ active: true, secs_running: { $gte: 30 } }).inprog;
  print(`Count: ${longOps.length}`);
  longOps.forEach(op => {
    print(`  opid=${op.opid} op=${op.op} ns=${op.ns} secs=${op.secs_running}`);
  });

  print(`\n=== Health Check Complete ===`);
}
healthCheck();
```

### 15.2 Replication Lag Monitor

```javascript
// Replication Lag Monitor -- run periodically
function checkReplicationLag(warningThresholdSec, criticalThresholdSec) {
  warningThresholdSec = warningThresholdSec || 10;
  criticalThresholdSec = criticalThresholdSec || 60;

  const rsStatus = rs.status();
  const primary = rsStatus.members.find(m => m.stateStr === "PRIMARY");
  if (!primary) { print("ERROR: No primary found!"); return; }

  rsStatus.members.filter(m => m.stateStr === "SECONDARY").forEach(m => {
    const lagMs = primary.optimeDate - m.optimeDate;
    const lagSec = lagMs / 1000;
    let severity = "OK";
    if (lagSec >= criticalThresholdSec) severity = "CRITICAL";
    else if (lagSec >= warningThresholdSec) severity = "WARNING";
    print(`[${severity}] ${m.name}: lag=${lagSec.toFixed(1)}s`);
  });
}
checkReplicationLag(10, 60);
```

### 15.3 Index Efficiency Report

```javascript
// Index Efficiency Report -- identify optimization opportunities
function indexEfficiencyReport() {
  print("=== Index Efficiency Report ===");
  db.getCollectionNames().forEach(collName => {
    const stats = db.getCollection(collName).stats();
    if (stats.count < 100) return;  // Skip small collections

    print(`\n--- ${collName} ---`);
    print(`  Documents: ${stats.count}`);
    print(`  Data size: ${(stats.size/1024/1024).toFixed(1)} MB`);
    print(`  Index count: ${stats.nindexes}`);
    print(`  Total index size: ${(stats.totalIndexSize/1024/1024).toFixed(1)} MB`);

    // Index usage
    db.getCollection(collName).aggregate([{ $indexStats: {} }]).forEach(idx => {
      const sizeBytes = stats.indexSizes[idx.name] || 0;
      const sizeMB = (sizeBytes / 1024 / 1024).toFixed(1);
      const status = idx.accesses.ops === 0 && idx.name !== "_id_" ? "UNUSED" : "ACTIVE";
      print(`  [${status}] ${idx.name}: ${idx.accesses.ops} ops, ${sizeMB} MB`);
    });
  });
}
indexEfficiencyReport();
```

### 15.4 Connection Leak Detection

```javascript
// Connection leak detection -- identify clients with too many connections
function connectionLeakCheck(threshold) {
  threshold = threshold || 50;
  print("=== Connection Leak Check ===");
  const results = db.aggregate([
    { $currentOp: { allUsers: true, idleConnections: true } },
    { $group: {
      _id: { client: "$client_s", appName: "$appName" },
      total: { $sum: 1 },
      idle: { $sum: { $cond: [{ $not: "$active" }, 1, 0] } },
      active: { $sum: { $cond: ["$active", 1, 0] } }
    }},
    { $match: { total: { $gte: threshold } } },
    { $sort: { total: -1 } }
  ]).toArray();

  results.forEach(r => {
    print(`${r._id.client || 'unknown'} (${r._id.appName || 'unknown'}): total=${r.total}, active=${r.active}, idle=${r.idle}`);
  });
  if (results.length === 0) print("No clients exceeding threshold.");
}
connectionLeakCheck(20);
```

### 15.5 Prometheus-Compatible Metrics Extraction

```javascript
// Extract key metrics in a format suitable for a custom Prometheus exporter
function prometheusMetrics() {
  const status = db.serverStatus();
  const cache = status.wiredTiger.cache;
  const conn = status.connections;
  const ops = status.opcounters;

  const metrics = [];
  metrics.push(`mongodb_uptime_seconds ${status.uptime}`);
  metrics.push(`mongodb_connections_current ${conn.current}`);
  metrics.push(`mongodb_connections_available ${conn.available}`);
  metrics.push(`mongodb_connections_total_created ${conn.totalCreated}`);
  metrics.push(`mongodb_opcounters_insert_total ${ops.insert}`);
  metrics.push(`mongodb_opcounters_query_total ${ops.query}`);
  metrics.push(`mongodb_opcounters_update_total ${ops.update}`);
  metrics.push(`mongodb_opcounters_delete_total ${ops.delete}`);
  metrics.push(`mongodb_wt_cache_bytes_used ${cache["bytes currently in the cache"]}`);
  metrics.push(`mongodb_wt_cache_bytes_max ${cache["maximum bytes configured"]}`);
  metrics.push(`mongodb_wt_cache_dirty_bytes ${cache["tracked dirty bytes in the cache"]}`);
  metrics.push(`mongodb_wt_cache_evictions_app ${cache["pages evicted by application threads"]}`);
  metrics.push(`mongodb_mem_resident_mb ${status.mem.resident}`);
  metrics.push(`mongodb_mem_virtual_mb ${status.mem.virtual}`);

  if (status.opLatencies) {
    metrics.push(`mongodb_latency_reads_microseconds ${status.opLatencies.reads.latency}`);
    metrics.push(`mongodb_latency_writes_microseconds ${status.opLatencies.writes.latency}`);
    metrics.push(`mongodb_latency_reads_ops ${status.opLatencies.reads.ops}`);
    metrics.push(`mongodb_latency_writes_ops ${status.opLatencies.writes.ops}`);
  }

  return metrics.join("\n");
}
print(prometheusMetrics());
```

---

## Section 16: Troubleshooting Playbooks

### Playbook: High Replication Lag

```
Symptoms: Secondary lag > 10 seconds, growing over time

1. Check lag magnitude:
   rs.printSecondaryReplicationInfo()

2. Check oplog window:
   rs.printReplicationInfo()
   → If oplog window < lag, secondary will need initial sync

3. Check secondary apply rate:
   db.serverStatus().metrics.repl.apply.batches
   → Compare totalMillis/num (average batch apply time)

4. Check secondary I/O:
   db.serverStatus().wiredTiger.cache
   → High app evictions on secondary = I/O bottleneck

5. Check for long-running operations on secondary:
   db.currentOp({ active: true })
   → Kill any long readers blocking the applier

6. Check replication buffer:
   db.serverStatus().metrics.repl.buffer
   → sizeBytes near maxSizeBytes = buffer full (network or apply bottleneck)

Root causes:
- Slow disk on secondary (upgrade to SSD/NVMe)
- Insufficient RAM on secondary (cache thrashing)
- Long-running queries on secondary holding snapshots
- Network bandwidth saturated between primary and secondary
- Large write bursts exceeding secondary apply throughput
```

### Playbook: Slow Queries

```
Symptoms: Application latency increase, user complaints

1. Check profiler for slow queries:
   db.setProfilingLevel(1, { slowms: 50 })
   db.system.profile.find().sort({ millis: -1 }).limit(10)

2. For the slowest query, run explain:
   db.collection.find(query).explain("executionStats")

3. Check explain output:
   - COLLSCAN? → Create an index
   - totalDocsExamined >> nReturned? → Index not selective enough
   - SORT stage with large memory? → Add sort field to index
   - FETCH after IXSCAN with many docs? → Consider covered query (projection)

4. Check WiredTiger cache:
   db.serverStatus().wiredTiger.cache
   → Cache eviction by app threads = data not in memory

5. Check lock contention:
   db.serverStatus().globalLock
   → Queue readers/writers > 0 = lock bottleneck

6. Check connection count:
   db.serverStatus().connections
   → If near limit, operations queue for connections
```

### Playbook: Out of Memory (OOM)

```
Symptoms: mongod killed by OOM killer, or resident memory growing unbounded

1. Check current memory:
   db.serverStatus().mem
   db.serverStatus().wiredTiger.cache

2. Check connection count (each ~1MB):
   db.serverStatus().connections.current

3. Check for large sorts/aggregations:
   db.currentOp({ active: true, op: "command" })
   → Aggregation pipelines can use 100MB per stage

4. Check history store size:
   db.serverStatus().wiredTiger["history store"]
   → Large HS = long-running transactions holding old snapshots

5. Check cache size setting:
   db.serverStatus().wiredTiger.cache["maximum bytes configured"]
   → If set too high, no room for OS, connections, aggregations

Fix:
- Reduce cacheSizeGB to leave more room for OS and application
- Reduce maxIncomingConnections
- Add allowDiskUse: true to large aggregations
- Kill long-running transactions
- Investigate and fix long-running snapshots / cursors
```

### Playbook: Hot Chunks (Sharded Cluster)

```
Symptoms: One shard receiving majority of traffic, uneven latency

1. Check chunk distribution:
   db.getSiblingDB("config").chunks.aggregate([
     { $match: { ns: "mydb.collection" } },
     { $group: { _id: "$shard", count: { $sum: 1 } } },
     { $sort: { count: -1 } }
   ])

2. Check if monotonic shard key:
   db.getSiblingDB("config").collections.findOne({ _id: "mydb.collection" })
   → If shard key is { _id: 1 } or { timestamp: 1 }, all new inserts go to last chunk

3. Check for jumbo chunks:
   db.getSiblingDB("config").chunks.find({ ns: "mydb.collection", jumbo: true })

4. Check balancer activity:
   sh.isBalancerRunning()
   sh.balancerStatus()

5. Check shard-level operation distribution:
   // On each shard:
   db.serverStatus().opcounters

Fix:
- Migrate to hashed shard key (requires re-sharding with reshardCollection in 5.0+)
- Use compound shard key with better distribution prefix
- For jumbo chunks: increase chunkSize temporarily, or use clearJumboFlag (4.4+)
- Enable zone-based sharding to manually distribute hot ranges
```

### Playbook: Election Storms

```
Symptoms: Frequent primary elections, write availability drops

1. Check election history:
   rs.status().members.forEach(m => print(`${m.name}: electionTime=${m.electionTime}, electionDate=${m.electionDate}`))

2. Check heartbeat connectivity:
   rs.status().members.forEach(m => {
     if (m.lastHeartbeat) {
       const age = new Date() - m.lastHeartbeat;
       print(`${m.name}: lastHeartbeat ${age}ms ago, state=${m.stateStr}`);
     }
   })

3. Check for network issues:
   - Verify all members can reach each other on port 27017
   - Check for network partitions, firewall rules, DNS resolution
   - Check round-trip latency between members

4. Check for resource pressure:
   - High CPU on primary can cause heartbeat delays
   - Disk I/O saturation during checkpoints can cause heartbeat timeout
   - Check db.serverStatus().wiredTiger.cache on primary

5. Check election timeout:
   rs.conf().settings.electionTimeoutMillis
   → Default 10000ms; increase if network is occasionally slow (but increases failover time)

Fix:
- Fix network connectivity issues between members
- Increase electionTimeoutMillis (e.g., 15000-20000ms) if network jitter is expected
- Ensure all members have adequate CPU and disk I/O
- Consider members in the same datacenter or low-latency network
```

---

## Section 17: Command-Line Diagnostic Tools

### 17.1 mongostat

```bash
# Real-time server statistics (like vmstat for MongoDB)
mongostat --host rs0/host1:27017 --rowcount 10

# Key columns:
# insert/query/update/delete: operations per second
# getmore: cursor batch fetches per second
# command: commands per second
# dirty: WiredTiger dirty cache percentage
# used: WiredTiger cache utilization percentage
# vsize: virtual memory
# res: resident memory
# qrw: queue length (read|write)
# arw: active clients (read|write)
# conn: connections
```

### 17.2 mongotop

```bash
# Show time spent per collection (like top for MongoDB)
mongotop --host rs0/host1:27017 10  # refresh every 10 seconds

# Key columns:
# ns: namespace (database.collection)
# total: total time in ms
# read: read time in ms
# write: write time in ms
```

### 17.3 mongosh Diagnostic One-Liners

```bash
# Quick connection count check
mongosh --eval "db.serverStatus().connections" mongodb://host:27017

# Quick replication lag check
mongosh --eval "rs.printSecondaryReplicationInfo()" mongodb://host:27017

# Quick cache check
mongosh --eval "const c=db.serverStatus().wiredTiger.cache; print('Used: '+(c['bytes currently in the cache']/1024/1024/1024).toFixed(2)+'GB, Dirty: '+(c['tracked dirty bytes in the cache']/1024/1024).toFixed(1)+'MB')" mongodb://host:27017

# Quick oplog window
mongosh --eval "rs.printReplicationInfo()" mongodb://host:27017

# List all databases and sizes
mongosh --eval "db.adminCommand({listDatabases:1}).databases.forEach(d=>print(d.name+': '+(d.sizeOnDisk/1024/1024/1024).toFixed(2)+' GB'))" mongodb://host:27017
```

---

## Section 18: Change Streams Diagnostics

### 18.1 Monitor Change Stream Cursors

```javascript
// Active change stream cursors
db.currentOp({ "cursor.originatingCommand.aggregate": { $exists: true } }).inprog.filter(op => {
  return op.cursor && op.cursor.originatingCommand && op.cursor.originatingCommand.pipeline &&
    JSON.stringify(op.cursor.originatingCommand.pipeline).includes("$changeStream");
})

// Change stream resume token tracking
db.serverStatus().metrics.changeStreams
```

### 18.2 Change Stream Health

```javascript
// Open cursors count
const cursorMetrics = db.serverStatus().metrics.cursor;
print(`Open cursors: ${cursorMetrics.open.total}`);
print(`No-timeout cursors: ${cursorMetrics.open.noTimeout}`);
print(`Timed out cursors: ${cursorMetrics.timedOut}`);
```

---

## Section 19: Transaction Diagnostics

### 19.1 Active Transactions

```javascript
// Currently active transactions
db.currentOp({ "transaction": { $exists: true } })

// Transactions with details
db.currentOp({ "transaction": { $exists: true } }).inprog.forEach(op => {
  const txn = op.transaction;
  print(`Session: ${op.lsid.id}, TxnNumber: ${txn.txnNumber}, ` +
        `Duration: ${txn.timePreparedMicros || txn.timeOpenMicros}us, ` +
        `State: ${txn.parameters.readConcern.level}`);
})
```

### 19.2 Transaction Metrics

```javascript
// Transaction statistics
const txnStats = db.serverStatus().transactions;
print(`Started: ${txnStats.totalStarted}`);
print(`Committed: ${txnStats.totalCommitted}`);
print(`Aborted: ${txnStats.totalAborted}`);
print(`Current active: ${txnStats.currentActive}`);
print(`Current inactive: ${txnStats.currentInactive}`);
print(`Current open: ${txnStats.currentOpen}`);
```

### 19.3 Transaction Timeout Configuration

```javascript
// Check transaction lifetime limit
db.adminCommand({ getParameter: 1, transactionLifetimeLimitSeconds: 1 })

// Adjust (default: 60 seconds)
db.adminCommand({ setParameter: 1, transactionLifetimeLimitSeconds: 120 })
```

---

## Section 20: Validation and Integrity

### 20.1 Collection Validation

```javascript
// Validate collection integrity (checks data and indexes)
db.orders.validate()

// Full validation (slower, checks B-tree structure)
db.orders.validate({ full: true })

// Validate all collections
db.getCollectionNames().forEach(c => {
  const result = db.getCollection(c).validate();
  print(`${c}: valid=${result.valid}, errors=${result.errors.length}, warnings=${result.warnings.length}`);
  if (!result.valid) printjson(result.errors);
})
```

### 20.2 Index Consistency Check

```javascript
// Check for inconsistent indexes
db.orders.validate().indexDetails  // Per-index validation results

// Rebuild a specific index
db.orders.dropIndex("idx_name")
db.orders.createIndex({ field: 1 }, { name: "idx_name" })

// Rebuild all indexes (takes exclusive lock)
db.orders.reIndex()
```

### 20.3 dbCheck (Background Consistency Check, 4.0+)

```javascript
// Run background consistency check between primary and secondary
db.runCommand({
  dbCheck: "orders",
  minKey: MinKey,
  maxKey: MaxKey,
  maxDocsPerBatch: 5000,
  maxBatchTimeMillis: 1000
})

// Results appear in the health log
db.getSiblingDB("local").system.healthlog.find(
  { namespace: "mydb.orders", operation: "dbCheckBatch" }
).sort({ data: -1 }).limit(10)
```
