# Neo4j Diagnostics Reference

## Database Status

### SHOW DATABASES -- List All Databases

```cypher
-- List all databases with their status
SHOW DATABASES;
```
Shows: name, type (standard/composite/system), access (read-write/read-only), address, role (primary/secondary), writer, currentStatus, statusMessage, default, home, constituents.
**When to use:** First check when investigating any issue. Look for databases in `offline`, `unknown`, or `dirty` status.
**Concerning values:** `currentStatus` != `online`, `statusMessage` is not empty.

### SHOW DATABASE name -- Specific Database Details

```cypher
-- Detailed info for a specific database
SHOW DATABASE neo4j YIELD *;
```
Shows all columns including `lastCommittedTxId`, `replicationLag`, `currentPrimariesCount`, `currentSecondariesCount`, `requestedPrimariesCount`.
**When to use:** Investigating a specific database's health, checking replication lag.
**Concerning values:** `replicationLag` > 0 for extended periods, `currentPrimariesCount` < `requestedPrimariesCount`.

### SHOW DEFAULT DATABASE

```cypher
SHOW DEFAULT DATABASE;
```
Shows which database is the default for connections that do not specify a database.
**When to use:** Verifying configuration after setup or migration.

### Database Store Size and Transaction ID

```cypher
SHOW DATABASES
YIELD name, currentStatus, store, lastCommittedTxId
RETURN name, currentStatus, store, lastCommittedTxId;
```
**When to use:** Checking store sizes across databases, verifying transaction progress, comparing replica lag.

## Cluster Status

### SHOW SERVERS -- Cluster Server Inventory

```cypher
-- List all servers in the cluster
SHOW SERVERS;
```
Shows: serverId, name, address, httpAddress, state (Free/Enabled/Deallocating/Dropped), health (Available/Unavailable), hosting (list of databases).
**When to use:** Verifying cluster membership, checking server health.
**Concerning values:** `state` = `Deallocating` or `Dropped` unexpectedly, `health` = `Unavailable`.

### Cluster Overview (Legacy Procedure)

```cypher
-- Cluster topology overview (4.x compatibility, may be deprecated)
CALL dbms.cluster.overview()
YIELD id, addresses, databases, groups;
```
**When to use:** Quick cluster topology check.

### Routing Table

```cypher
-- Get routing table for a specific database
CALL dbms.routing.getRoutingTable({}, 'neo4j');
```
Shows: TTL, servers grouped by role (READ, WRITE, ROUTE).
**When to use:** Debugging driver routing issues, verifying read/write distribution.
**Concerning values:** Empty WRITE servers list (no leader elected), empty READ servers (no replicas available).

### Cluster Endpoints

```cypher
-- Check which server is the leader for each database
SHOW DATABASES
YIELD name, role, writer, address, currentStatus
WHERE role = 'primary'
RETURN name, address, writer, currentStatus;
```
**When to use:** Finding the current leader, verifying write routing.

## Query Monitoring

### SHOW TRANSACTIONS -- Active Transactions

```cypher
-- All active transactions across all databases
SHOW TRANSACTIONS
YIELD transactionId, database, username, currentQuery,
      currentQueryId, status, elapsedTime,
      cpuTime, waitTime, idleTime,
      allocatedBytes, allocatedDirectBytes,
      outerTransactionId, metaData, statusDetails
ORDER BY elapsedTime DESC;
```
Shows: every active transaction with resource usage.
**When to use:** Finding slow queries, identifying blocking transactions, monitoring resource usage.
**Concerning values:** `elapsedTime` > 30s for OLTP queries, `allocatedBytes` > 1GB (potential OOM), `status` = `Blocked`.

### Long-Running Queries

```cypher
-- Queries running longer than 60 seconds
SHOW TRANSACTIONS
YIELD transactionId, username, currentQuery, elapsedTime, status, allocatedBytes
WHERE elapsedTime > duration('PT60S')
ORDER BY elapsedTime DESC;
```
**When to use:** Identifying runaway queries that consume resources.

### Blocked Transactions

```cypher
-- Find transactions that are blocked (waiting for locks)
SHOW TRANSACTIONS
YIELD transactionId, username, currentQuery, status, statusDetails, elapsedTime
WHERE status = 'Blocked'
RETURN transactionId, username, left(currentQuery, 200) AS query,
       statusDetails, elapsedTime;
```
**When to use:** Diagnosing lock contention and deadlock scenarios.

### Transaction Memory Usage

```cypher
-- Transactions consuming the most memory
SHOW TRANSACTIONS
YIELD transactionId, username, currentQuery, allocatedBytes, allocatedDirectBytes, elapsedTime
ORDER BY allocatedBytes DESC
LIMIT 20;
```
**When to use:** Identifying memory-hungry transactions before OOM.

### Terminate a Transaction

```cypher
-- Kill a specific transaction
TERMINATE TRANSACTION 'neo4j-transaction-42';

-- Kill multiple transactions
TERMINATE TRANSACTIONS ['neo4j-transaction-42', 'neo4j-transaction-43'];
```
**When to use:** Stopping runaway queries, releasing locks held by blocked transactions.

### Query Progress (2026.02+)

```cypher
-- Show transaction progress (queries with progress tracking)
SHOW TRANSACTIONS
YIELD transactionId, currentQuery, elapsedTime, status, statusDetails
WHERE statusDetails IS NOT NULL;
```
**When to use:** Monitoring long-running batch operations.

## Index Management

### SHOW INDEXES -- All Indexes

```cypher
-- List all indexes with detailed information
SHOW INDEXES
YIELD id, name, state, populationPercent, type, entityType,
      labelsOrTypes, properties, indexProvider, owningConstraint,
      lastRead, readCount
ORDER BY type, name;
```
Shows: index name, type (RANGE/TEXT/POINT/FULLTEXT/LOOKUP), state (ONLINE/POPULATING/FAILED), backing constraint.
**When to use:** Verifying index coverage, checking index health, finding unused indexes.
**Concerning values:** `state` = `FAILED` (recreation required), `populationPercent` < 100 (still building), `readCount` = 0 (potentially unused).

### Unused Indexes

```cypher
-- Indexes that have never been read (candidates for removal)
SHOW INDEXES
YIELD name, type, labelsOrTypes, properties, readCount, lastRead
WHERE readCount = 0
  AND type <> 'LOOKUP'
RETURN name, type, labelsOrTypes, properties;
```
**When to use:** Cleanup during maintenance windows. Unused indexes waste storage and slow writes.
**Caution:** Check over a full business cycle before dropping.

### Failed Indexes

```cypher
-- Indexes that failed to build
SHOW INDEXES
YIELD name, state, type, labelsOrTypes, properties, failureMessage
WHERE state = 'FAILED'
RETURN name, type, labelsOrTypes, properties, failureMessage;
```
**When to use:** After index creation or database restart.
**Resolution:** Drop and recreate the index. Check failureMessage for root cause.

### Index Population Progress

```cypher
-- Indexes currently being populated
SHOW INDEXES
YIELD name, state, populationPercent, type
WHERE state = 'POPULATING'
RETURN name, type, populationPercent;
```
**When to use:** Monitoring index build progress after CREATE INDEX.

### Wait for All Indexes to Come Online

```cypher
-- Block until all indexes are online (timeout in seconds)
CALL db.awaitIndexes(300);
```
**When to use:** After creating indexes in scripts before running queries that depend on them.

### SHOW CONSTRAINTS -- All Constraints

```cypher
-- List all constraints
SHOW CONSTRAINTS
YIELD id, name, type, entityType, labelsOrTypes, properties, ownedIndex;
```
Shows: constraint name, type (UNIQUENESS/NODE_KEY/EXISTENCE/RELATIONSHIP_KEY/PROPERTY_TYPE), backing index.
**When to use:** Verifying schema enforcement, checking which properties are constrained.

### Index Usage for a Specific Query

```cypher
-- Check if a query uses indexes
EXPLAIN MATCH (p:Person {email: 'alice@example.com'}) RETURN p;
```
**When to use:** Verify that queries use expected indexes. Look for `NodeIndexSeek` in the plan.

## Schema Information

### Node Labels

```cypher
-- All labels in the database
CALL db.labels() YIELD label
RETURN label ORDER BY label;
```
Shows: all label names used in the database.
**When to use:** Understanding the graph schema, discovering data model.

### Relationship Types

```cypher
-- All relationship types in the database
CALL db.relationshipTypes() YIELD relationshipType
RETURN relationshipType ORDER BY relationshipType;
```
Shows: all relationship type names used in the database.

### Property Keys

```cypher
-- All property keys in the database
CALL db.propertyKeys() YIELD propertyKey
RETURN propertyKey ORDER BY propertyKey;
```
Shows: all property key names ever used (including from deleted data).

### Schema Visualization

```cypher
-- Visual schema overview (labels, relationship types, properties)
CALL db.schema.visualization()
YIELD nodes, relationships
RETURN nodes, relationships;
```
Shows: graph schema as a virtual graph of labels connected by relationship types.
**When to use:** Understanding unfamiliar databases, documenting schema.

### Node Count by Label

```cypher
-- Count nodes per label
CALL db.labels() YIELD label
CALL db.stats.retrieve('GRAPH COUNTS') YIELD data
WITH label, [x IN data WHERE x.label = label] AS counts
RETURN label, counts;

-- Alternative: direct count (slower but always accurate)
CALL db.labels() YIELD label
CALL {
  WITH label
  MATCH (n)
  WHERE label IN labels(n)
  RETURN count(n) AS count
}
RETURN label, count
ORDER BY count DESC;
```

### Relationship Count by Type

```cypher
-- Count relationships per type
CALL db.relationshipTypes() YIELD relationshipType
CALL {
  WITH relationshipType
  MATCH ()-[r]->()
  WHERE type(r) = relationshipType
  RETURN count(r) AS count
}
RETURN relationshipType, count
ORDER BY count DESC;
```

### Full Schema Report

```cypher
-- APOC schema report
CALL apoc.meta.schema()
YIELD value
RETURN value;
```
Shows: complete schema with labels, relationship types, property types, cardinalities.

## Performance Diagnostics

### PROFILE Queries

```cypher
-- Profile a query: shows actual execution with row counts and db hits
PROFILE
MATCH (p:Person {name: 'Alice'})-[:KNOWS]->(friend)-[:WORKS_AT]->(company)
RETURN friend.name, company.name;
```
**Key metrics per operator:**
- `Rows`: actual number of rows passing through
- `DB Hits`: number of store/index accesses (lower = better)
- `Page Cache Hits/Misses`: page cache effectiveness for this operator
- `Time`: wall-clock time spent in this operator

**Red flags in PROFILE output:**
- `CartesianProduct` operator (unintended cross-join)
- `Filter` with high Rows input and low output (missing index)
- `Eager` operator (forces materialization; memory risk)
- `NodeByLabelScan` when an index should be used
- Very high `DB Hits` relative to `Rows` returned

### EXPLAIN Queries

```cypher
-- Explain plan only (does not execute)
EXPLAIN
MATCH (p:Person)-[:KNOWS*3..5]->(foaf)
WHERE p.name = 'Alice'
RETURN foaf;
```
**When to use:** Checking query plan before executing expensive queries.

### Graph Statistics

```cypher
-- Retrieve graph statistics used by the query planner
CALL db.stats.retrieve('GRAPH COUNTS') YIELD data
UNWIND data AS stat
RETURN stat;
```
Shows: node counts by label, relationship counts by type, property existence counts.
**When to use:** Understanding cardinality estimates, diagnosing planner misestimates.

### Planner Cardinality Estimates vs. Actuals

```cypher
-- Compare estimated vs actual rows (run PROFILE first, then inspect)
-- Look for operators where EstimatedRows >> Rows or EstimatedRows << Rows
-- Large discrepancies indicate stale statistics or modeling issues
PROFILE MATCH (p:Person)-[:LIVES_IN]->(c:City {name: 'London'})
RETURN p.name;
```
**When to use:** When the planner chooses suboptimal plans.
**Resolution:** Run statistics refresh or use index hints.

## Memory Diagnostics

### Current Memory Configuration

```cypher
-- List all memory-related configuration
CALL dbms.listConfig() YIELD name, value, description
WHERE name CONTAINS 'memory' OR name CONTAINS 'heap' OR name CONTAINS 'pagecache'
RETURN name, value, description
ORDER BY name;
```
Shows: all memory-related settings and their current values.

### Heap Usage via JMX

```cypher
-- Query JMX for heap usage
CALL dbms.queryJmx('java.lang:type=Memory')
YIELD name, attributes
RETURN name, attributes.HeapMemoryUsage, attributes.NonHeapMemoryUsage;
```
Shows: heap used/committed/max, non-heap used/committed/max.
**When to use:** Monitoring heap pressure, diagnosing OOM issues.
**Concerning values:** `HeapMemoryUsage.used` / `HeapMemoryUsage.max` > 0.9 (heap nearly full).

### Page Cache Hit Ratio

```cypher
-- Page cache statistics via JMX
CALL dbms.queryJmx('org.neo4j:instance=kernel#0,name=Page cache')
YIELD attributes
RETURN attributes.HitRatio, attributes.Faults, attributes.Evictions,
       attributes.BytesRead, attributes.BytesWritten;
```
Shows: cache hit ratio, fault count (misses), eviction count.
**When to use:** Determining if page cache is sized correctly.
**Concerning values:** `HitRatio` < 0.95 for OLTP workloads, high `Evictions` (cache too small).

### Transaction Memory Limits

```cypher
-- Check transaction memory configuration
CALL dbms.listConfig() YIELD name, value
WHERE name CONTAINS 'transaction' AND (name CONTAINS 'memory' OR name CONTAINS 'max')
RETURN name, value;
```
Key parameters:
- `dbms.memory.transaction.total.max` -- max memory for all transactions combined
- `dbms.memory.transaction.max` -- max memory per individual transaction

### Garbage Collection Statistics

```cypher
-- GC information via JMX
CALL dbms.queryJmx('java.lang:type=GarbageCollector,name=*')
YIELD name, attributes
RETURN name, attributes.CollectionCount, attributes.CollectionTime;
```
**When to use:** Diagnosing GC-related latency spikes.
**Concerning values:** High `CollectionTime` / `CollectionCount` ratio (long GC pauses), total collection time growing rapidly.

## Store Information

### Store Size Details

```cypher
-- Database store size breakdown (requires APOC Extended)
CALL apoc.monitor.store()
YIELD logSize, stringStoreSize, arrayStoreSize,
      relStoreSize, propStoreSize, totalStoreSize, nodeStoreSize
RETURN *;
```
Shows: size of each store file component.
**When to use:** Understanding storage breakdown, planning page cache sizing.

### Kernel Information

```cypher
-- Kernel and store metadata (requires APOC Extended)
CALL apoc.monitor.kernel()
YIELD readOnly, kernelVersion, storeId, kernelStartTime,
      databaseName, storeLogVersion, storeCreationDate
RETURN *;
```

### Store Format Information (Admin Command)

```bash
# Display store format and version information
neo4j-admin database info neo4j

# Output includes:
# - Store format version
# - Store format introduction version
# - Whether migration is needed
# - Last committed transaction ID
```
**When to use:** Before upgrades to check if store migration is needed.

### JMX Store Metrics

```cypher
-- Comprehensive store metrics via JMX
CALL dbms.queryJmx('org.neo4j:instance=kernel#0,name=Store sizes')
YIELD attributes
RETURN attributes;
```

## Transaction Log Diagnostics

### Transaction ID Progress

```cypher
-- Last committed transaction ID per database
SHOW DATABASES
YIELD name, lastCommittedTxId, currentStatus
RETURN name, lastCommittedTxId, currentStatus;
```
**When to use:** Monitoring write activity, verifying replication progress.
**Concerning values:** Transaction ID not advancing (writes may be blocked), large gap between primary and replica.

### Active Locks

```cypher
-- List currently held locks (requires appropriate privileges)
SHOW TRANSACTIONS
YIELD transactionId, currentQuery, status, statusDetails
WHERE status = 'Blocked' OR statusDetails CONTAINS 'lock'
RETURN transactionId, currentQuery, status, statusDetails;
```
**When to use:** Diagnosing lock contention.

### Transaction Log Configuration

```cypher
-- Check transaction log settings
CALL dbms.listConfig() YIELD name, value
WHERE name CONTAINS 'tx_log'
RETURN name, value;
```
Key settings:
- `db.tx_log.rotation.size` -- log file rotation threshold
- `db.tx_log.rotation.retention_policy` -- how long to keep old logs

## Procedure and Function Listing

### SHOW PROCEDURES

```cypher
-- All available procedures
SHOW PROCEDURES
YIELD name, description, mode, worksOnSystem
ORDER BY name;

-- Filter to APOC procedures
SHOW PROCEDURES
YIELD name, description
WHERE name STARTS WITH 'apoc.'
RETURN name, description;

-- Filter to GDS procedures
SHOW PROCEDURES
YIELD name, description
WHERE name STARTS WITH 'gds.'
RETURN name, description;

-- Filter to dbms procedures
SHOW PROCEDURES
YIELD name, description
WHERE name STARTS WITH 'dbms.'
RETURN name, description;
```

### SHOW FUNCTIONS

```cypher
-- All available functions
SHOW FUNCTIONS
YIELD name, description, category, isBuiltIn
ORDER BY category, name;

-- User-defined functions only
SHOW FUNCTIONS
YIELD name, description, isBuiltIn
WHERE NOT isBuiltIn
RETURN name, description;
```

### Specific Procedure Signature

```cypher
-- Get signature for a specific procedure
SHOW PROCEDURES
YIELD name, signature, description
WHERE name = 'apoc.meta.stats'
RETURN name, signature, description;
```

## APOC Diagnostics

### Graph Metadata Statistics

```cypher
-- Comprehensive database statistics
CALL apoc.meta.stats()
YIELD labelCount, relTypeCount, propertyKeyCount,
      nodeCount, relCount, labels, relTypes, relTypesCount, stats
RETURN *;
```
Shows: total counts, per-label node counts, per-type relationship counts.
**When to use:** Quick overview of database contents, verifying data load completeness.

### APOC Monitoring Suite

```cypher
-- Kernel monitoring
CALL apoc.monitor.kernel()
YIELD databaseName, kernelVersion, storeCreationDate, kernelStartTime
RETURN *;

-- Store monitoring
CALL apoc.monitor.store()
YIELD totalStoreSize, nodeStoreSize, relStoreSize, propStoreSize, logSize
RETURN *;

-- Transaction monitoring
CALL apoc.monitor.tx()
YIELD rolledBackTx, peakTx, lastTxId, totalOpenedTx, totalClosedTx
RETURN *;

-- ID usage monitoring
CALL apoc.monitor.ids()
YIELD nodeIds, relIds, propIds, relTypeIds, labelIds
RETURN *;
```

### APOC Data Profiling

```cypher
-- Profile node properties across the database
CALL apoc.meta.nodeTypeProperties()
YIELD nodeType, nodeLabels, propertyName, propertyTypes, mandatory, propertyObservations, totalObservations
RETURN *;

-- Profile relationship properties
CALL apoc.meta.relTypeProperties()
YIELD relType, sourceNodeLabels, targetNodeLabels, propertyName, propertyTypes, mandatory
RETURN *;
```
**When to use:** Discovering actual data types and property usage patterns.

### APOC Warmup (Page Cache Priming)

```cypher
-- Load entire graph into page cache (run after restart)
CALL apoc.warmup.run(true, true, true);
-- Parameters: (loadNodes, loadRelationships, loadProperties)
```
**When to use:** After database restart to prime page cache before serving traffic.
**Expected output:** Reports number of pages loaded for each store component.

## GDS Catalog Diagnostics

### List Graph Projections

```cypher
-- List all in-memory graph projections
CALL gds.graph.list()
YIELD graphName, database, nodeCount, relationshipCount,
      schema, density, creationTime, modificationTime,
      sizeInBytes, memoryUsage
RETURN *;
```
Shows: all active GDS graph projections with memory usage.
**When to use:** Monitoring GDS memory consumption, finding orphaned projections.
**Concerning values:** Large `sizeInBytes` on forgotten projections (memory leak).

### Check If Projection Exists

```cypher
-- Check if a specific projection exists
CALL gds.graph.exists('my-graph')
YIELD graphName, exists
RETURN *;
```

### Memory Estimation

```cypher
-- Estimate memory for a graph projection
CALL gds.graph.project.estimate('Person', 'KNOWS')
YIELD requiredMemory, nodeCount, relationshipCount;

-- Estimate memory for an algorithm
CALL gds.pageRank.estimate('my-graph', {maxIterations: 20})
YIELD requiredMemory, nodeCount, relationshipCount;

-- Estimate memory for community detection
CALL gds.louvain.estimate('my-graph', {})
YIELD requiredMemory;
```
**When to use:** Before running algorithms on large graphs to prevent OOM.

### Drop Graph Projection

```cypher
-- Drop a specific graph projection to free memory
CALL gds.graph.drop('my-graph') YIELD graphName;

-- Drop all projections
CALL gds.graph.list() YIELD graphName
CALL gds.graph.drop(graphName) YIELD graphName AS dropped
RETURN dropped;
```
**When to use:** Freeing memory after algorithm execution.

## Log Analysis

### Log File Locations

```
# Default log locations (may vary by installation)
/var/log/neo4j/neo4j.log       # Main server log
/var/log/neo4j/debug.log        # Debug-level logging
/var/log/neo4j/query.log        # Query logging (when enabled)
/var/log/neo4j/security.log     # Authentication events
/var/log/neo4j/http.log         # HTTP API access log
```

### Enable Query Logging

```properties
# neo4j.conf -- enable query logging
db.logs.query.enabled=INFO

# Log queries slower than this threshold
db.logs.query.threshold=1s

# Log query parameters (be careful with sensitive data)
db.logs.query.parameter_logging_enabled=true

# Log allocated bytes per query
db.logs.query.allocation_logging_enabled=true

# Log page cache hits/misses per query
db.logs.query.page_logging_enabled=true

# Rotate query log
db.logs.query.rotation.size=50m
db.logs.query.rotation.keep_number=10
```

### Query Log Format

```
# Example query.log entry:
2026-04-07 14:30:15.123+0000 INFO  id:12345 - 250 ms: 15234 B - ... - neo4j - MATCH (p:Person {name: $name})-[:KNOWS]->(f) RETURN f - {name: 'Alice'} - runtime=pipelined - {}
```
Fields: timestamp, level, query ID, elapsed time, allocated bytes, database, username, query text, parameters, runtime, metadata.

### Common Log Patterns to Watch For

```
# GC warnings (look in neo4j.log or debug.log)
WARN  GC Monitor: GC Paused for 2500ms

# Out of memory
ERROR OutOfMemoryError: Java heap space

# Connection pool exhaustion
WARN  Connection pool exhausted

# Deadlock detection
ERROR DeadlockDetectedException: ForsetiClient[42] can't acquire ExclusiveLock

# Cluster leadership change
INFO  Leader changed from server-1 to server-2 for database neo4j

# Transaction timeout
WARN  Transaction timed out and was terminated

# Checkpoint completion
INFO  Checkpoint triggered by time threshold @ txId: 12345678
```

### Debug Log Analysis

```bash
# Find GC pauses > 1 second
grep "GC Paused" /var/log/neo4j/debug.log | grep -E "[0-9]{4,}ms"

# Find OOM events
grep -i "OutOfMemory\|heap space\|out of memory" /var/log/neo4j/neo4j.log

# Find deadlocks
grep -i "DeadlockDetected" /var/log/neo4j/debug.log

# Find slow queries (from query log)
grep -E "^.* [0-9]{5,} ms:" /var/log/neo4j/query.log

# Find leader election events
grep -i "leader\|election\|raft" /var/log/neo4j/debug.log

# Count queries per minute (from query log)
awk '{print $1, $2}' /var/log/neo4j/query.log | cut -d: -f1-2 | sort | uniq -c | sort -rn | head -20
```

## Admin Commands

### neo4j-admin database check -- Consistency Check

```bash
# Check consistency of a database (offline recommended)
neo4j-admin database check neo4j --report-dir=/tmp/reports/

# Check a backup file for consistency
neo4j-admin database check --from-path=/backups/neo4j-backup --report-dir=/tmp/reports/

# Verbose consistency check
neo4j-admin database check neo4j --report-dir=/tmp/reports/ --verbose
```
**When to use:** After crashes, before restoring backups, periodic health checks.
**Expected output:** Reports inconsistencies in node/relationship/property stores, schema, indexes.

### neo4j-admin database info -- Store Information

```bash
# Display store format and metadata
neo4j-admin database info neo4j

# Output:
# Database name:     neo4j
# Store format:      Block (introduced in 5.14)
# Last committed TX: 1234567
# Store needs recovery: false
```
**When to use:** Before upgrades, checking store format, verifying backup integrity.

### neo4j-admin server report -- System Report

```bash
# Generate a full system report (zip archive)
neo4j-admin server report --to-path=/tmp/

# Report with specific sections
neo4j-admin server report --to-path=/tmp/ logs config metrics

# Report for a specific database
neo4j-admin server report --to-path=/tmp/ --database=neo4j

# Available classifiers: config, logs, metrics, plugins, ps, sysprop, threads, tree, tx, version
```
**When to use:** Gathering diagnostic information for support cases, pre-upgrade assessment.

### neo4j-admin server memory-recommendation

```bash
# Get memory configuration recommendations
neo4j-admin server memory-recommendation --memory=64g

# Output:
# server.memory.heap.initial_size=16g
# server.memory.heap.max_size=16g
# server.memory.pagecache.size=40g
# ...remaining for OS...
```
**When to use:** Initial server configuration, after hardware changes.

### neo4j-admin database migrate

```bash
# Migrate database to block format
neo4j-admin database migrate neo4j --to-format=block

# Check if migration is needed
neo4j-admin database info neo4j
```
**When to use:** Upgrading store format for better performance.

### neo4j-admin database backup and restore

```bash
# Full online backup
neo4j-admin database backup neo4j --to-path=/backups/

# Differential backup (Enterprise)
neo4j-admin database backup neo4j --to-path=/backups/ --type=DIFFERENTIAL

# Restore from backup
neo4j-admin database restore --from-path=/backups/neo4j-2026-04-07.backup --database=neo4j --overwrite-destination

# Offline dump
neo4j-admin database dump neo4j --to-path=/dumps/

# Load from dump
neo4j-admin database load neo4j --from-path=/dumps/neo4j.dump --overwrite-destination
```

### neo4j-admin database import

```bash
# Bulk import from CSV (initial load, database must not exist)
neo4j-admin database import full neo4j \
  --nodes=Person=import/persons-header.csv,import/persons.csv \
  --nodes=Company=import/companies-header.csv,import/companies.csv \
  --relationships=WORKS_AT=import/works-at-header.csv,import/works-at.csv \
  --skip-bad-relationships=true \
  --skip-duplicate-nodes=true \
  --trim-strings=true \
  --max-off-heap-memory=8g

# Incremental import (appends to existing database)
neo4j-admin database import incremental neo4j \
  --nodes=import/new-persons.csv \
  --relationships=import/new-relationships.csv
```

## Metrics and Monitoring

### Built-in Metrics Endpoints

```properties
# neo4j.conf -- enable metrics
server.metrics.enabled=true

# CSV metrics export
server.metrics.csv.enabled=true
server.metrics.csv.interval=30s
server.metrics.csv.rotation.size=10m
server.metrics.csv.rotation.keep_number=5

# Prometheus metrics endpoint
server.metrics.prometheus.enabled=true
server.metrics.prometheus.endpoint=localhost:2004
```

### Key Prometheus Metrics

```
# Page cache
neo4j_page_cache_hits_total
neo4j_page_cache_page_faults_total
neo4j_page_cache_evictions_total
neo4j_page_cache_usage_ratio

# Bolt connections
neo4j_bolt_connections_opened_total
neo4j_bolt_connections_closed_total
neo4j_bolt_connections_running
neo4j_bolt_connections_idle

# Transactions
neo4j_transaction_started_total
neo4j_transaction_committed_total
neo4j_transaction_rollbacks_total
neo4j_transaction_active
neo4j_transaction_peak_concurrent

# Query execution
neo4j_db_query_execution_latency_millis (histogram)
neo4j_db_query_execution_success_total
neo4j_db_query_execution_failure_total

# Store size
neo4j_store_size_total_bytes
neo4j_store_size_database_bytes

# JVM
neo4j_vm_heap_used_bytes
neo4j_vm_heap_committed_bytes
neo4j_vm_gc_time_total_ms
neo4j_vm_gc_count_total
neo4j_vm_thread_count

# Cluster
neo4j_cluster_raft_leader (gauge: 1 if leader, 0 otherwise)
neo4j_cluster_raft_append_index
neo4j_cluster_raft_commit_index
neo4j_cluster_raft_applied_index
neo4j_cluster_raft_replication_attempt_total
neo4j_cluster_raft_is_healthy (gauge)
```

### Grafana Dashboard Queries (Prometheus)

```promql
# Page cache hit ratio (should be > 95%)
rate(neo4j_page_cache_hits_total[5m]) /
(rate(neo4j_page_cache_hits_total[5m]) + rate(neo4j_page_cache_page_faults_total[5m]))

# Transaction throughput (commits/sec)
rate(neo4j_transaction_committed_total[5m])

# Active connections
neo4j_bolt_connections_running

# Heap usage percentage
neo4j_vm_heap_used_bytes / neo4j_vm_heap_committed_bytes

# Query latency p99 (if histogram)
histogram_quantile(0.99, rate(neo4j_db_query_execution_latency_millis_bucket[5m]))

# GC pause rate
rate(neo4j_vm_gc_time_total_ms[5m])
```

## Connection Pool Diagnostics

### Driver Connection Pool Monitoring

```cypher
-- Check Bolt connection metrics via JMX
CALL dbms.queryJmx('org.neo4j:instance=kernel#0,name=Bolt')
YIELD attributes
RETURN attributes;
```
Shows: connections opened/closed/running/idle, messages received/started/done/failed.

### Server-Side Connection Tracking

```cypher
-- Count connections by user and client
SHOW TRANSACTIONS
YIELD username, clientAddress, status
RETURN username, clientAddress, count(*) AS connections, collect(status) AS statuses
ORDER BY connections DESC;
```

### Connection Configuration

```properties
# neo4j.conf
# Maximum Bolt connections
server.bolt.thread_pool_max_size=400

# Connection keep-alive
server.bolt.connection_keep_alive=30s
server.bolt.connection_keep_alive_for_requests=ALL

# Connection timeout
server.bolt.connection_idle_timeout=0  # 0 = no timeout
```

## Configuration Diagnostics

### List All Configuration

```cypher
-- All current configuration values
CALL dbms.listConfig()
YIELD name, value, description, dynamic
RETURN name, value, description, dynamic
ORDER BY name;
```

### Dynamic Configuration Changes

```cypher
-- List only dynamically changeable settings
CALL dbms.listConfig()
YIELD name, value, dynamic
WHERE dynamic = true
RETURN name, value;

-- Change a dynamic setting at runtime
CALL dbms.setConfigValue('db.logs.query.threshold', '500ms');
```

### Specific Configuration Checks

```cypher
-- Memory settings
CALL dbms.listConfig() YIELD name, value WHERE name CONTAINS 'memory' RETURN name, value;

-- Security settings
CALL dbms.listConfig() YIELD name, value WHERE name CONTAINS 'auth' OR name CONTAINS 'security' RETURN name, value;

-- Cluster settings
CALL dbms.listConfig() YIELD name, value WHERE name CONTAINS 'cluster' OR name CONTAINS 'raft' RETURN name, value;

-- Query logging settings
CALL dbms.listConfig() YIELD name, value WHERE name CONTAINS 'query' AND name CONTAINS 'log' RETURN name, value;
```

## Troubleshooting Playbooks

### Playbook: Slow Traversals

**Symptoms:** Queries with variable-length paths or multi-hop traversals are slow.

1. **Profile the query:**
   ```cypher
   PROFILE MATCH (a:Person {name: 'Alice'})-[:KNOWS*1..3]->(b) RETURN b;
   ```
2. **Check for supernodes** (nodes with excessive relationships):
   ```cypher
   MATCH (n) WITH n, size([(n)-->() | 1]) AS degree
   WHERE degree > 10000
   RETURN labels(n), n.name, degree ORDER BY degree DESC LIMIT 20;
   ```
3. **Check page cache hit ratio** -- see Memory Diagnostics section
4. **Verify indexes on starting nodes:**
   ```cypher
   SHOW INDEXES YIELD labelsOrTypes, properties, type
   WHERE 'Person' IN labelsOrTypes;
   ```
5. **Bound the path length** -- never use unbounded `[*]`
6. **Filter early** -- add WHERE clauses on relationship properties or intermediate nodes
7. **Consider APOC path expander** for complex traversal control:
   ```cypher
   CALL apoc.path.subgraphNodes(startNode, {
     maxLevel: 3,
     relationshipFilter: 'KNOWS>',
     labelFilter: '+Person'
   }) YIELD node;
   ```

### Playbook: Lock Contention

**Symptoms:** Transactions blocked, deadlock exceptions, high wait times.

1. **Find blocked transactions:**
   ```cypher
   SHOW TRANSACTIONS YIELD transactionId, username, currentQuery, status, statusDetails, elapsedTime
   WHERE status = 'Blocked';
   ```
2. **Identify the blocker:** Check `statusDetails` for the blocking transaction ID.
3. **Terminate the blocking transaction if safe:**
   ```cypher
   TERMINATE TRANSACTION 'neo4j-transaction-blocking-id';
   ```
4. **Review application code:** Ensure consistent lock ordering (update nodes in deterministic order).
5. **Check for read-write conflicts** in Cypher:
   ```cypher
   -- This causes Eager + lock contention:
   MATCH (a:Person) SET a.processed = true;
   -- Better: batch with CALL IN TRANSACTIONS
   MATCH (a:Person) WHERE a.processed IS NULL
   CALL { WITH a SET a.processed = true } IN TRANSACTIONS OF 10000 ROWS;
   ```

### Playbook: Out of Memory (OOM)

**Symptoms:** `OutOfMemoryError` in logs, database crashes, transaction failures with memory errors.

1. **Check current heap usage:**
   ```cypher
   CALL dbms.queryJmx('java.lang:type=Memory') YIELD attributes
   RETURN attributes.HeapMemoryUsage;
   ```
2. **Find memory-hungry transactions:**
   ```cypher
   SHOW TRANSACTIONS YIELD transactionId, currentQuery, allocatedBytes
   ORDER BY allocatedBytes DESC LIMIT 10;
   ```
3. **Check GDS projections consuming memory:**
   ```cypher
   CALL gds.graph.list() YIELD graphName, sizeInBytes, memoryUsage
   ORDER BY sizeInBytes DESC;
   ```
4. **Set transaction memory limits:**
   ```properties
   # neo4j.conf
   dbms.memory.transaction.max=1g
   dbms.memory.transaction.total.max=8g
   ```
5. **Review query patterns:** Look for queries that collect entire graph into lists, unbounded COLLECT, or CartesianProduct.
6. **Increase heap if justified** (max recommended ~31GB to stay in compressed oops range):
   ```properties
   server.memory.heap.initial_size=16g
   server.memory.heap.max_size=16g
   ```

### Playbook: Cluster Desync (Replica Lag)

**Symptoms:** Read replicas show stale data, `replicationLag` > 0, follower not catching up.

1. **Check replication lag:**
   ```cypher
   SHOW DATABASES YIELD name, role, currentStatus, lastCommittedTxId, replicationLag
   WHERE role = 'secondary' OR role = 'primary'
   ORDER BY name, role;
   ```
2. **Check server health:**
   ```cypher
   SHOW SERVERS YIELD name, address, state, health;
   ```
3. **Check network connectivity** between cluster members (Raft port 5000 and transaction port 6000).
4. **Check disk I/O on lagging server** -- replicas must apply transactions to local store.
5. **Check transaction log retention:**
   ```cypher
   CALL dbms.listConfig() YIELD name, value
   WHERE name CONTAINS 'tx_log.rotation.retention'
   RETURN name, value;
   ```
   If logs are pruned before the replica can catch up, a full store copy is needed.
6. **Force store copy** (last resort): restart the lagging secondary to trigger a fresh copy from a primary.

### Playbook: Import Failures

**Symptoms:** LOAD CSV errors, neo4j-admin import failures, APOC import exceptions.

1. **LOAD CSV common errors:**
   ```cypher
   -- Check CSV file accessibility
   LOAD CSV WITH HEADERS FROM 'file:///test.csv' AS row
   RETURN row LIMIT 5;
   ```
   - `FileNotFoundException`: File not in the `import/` directory (check `server.directories.import`)
   - `NumberFormatException`: String value in numeric field -- use `toInteger()`, `toFloat()` with null checks
   - `MissingConstraint`: MERGE on unconstrained property is slow, not an error, but add constraint
   
2. **Data type validation before import:**
   ```cypher
   LOAD CSV WITH HEADERS FROM 'file:///data.csv' AS row
   WITH row WHERE row.id IS NULL OR trim(row.id) = ''
   RETURN count(*) AS rows_with_missing_id;
   ```

3. **neo4j-admin import errors:**
   ```bash
   # Run with verbose logging
   neo4j-admin database import full neo4j \
     --nodes=import/nodes.csv \
     --relationships=import/rels.csv \
     --skip-bad-relationships=true \
     --skip-duplicate-nodes=true \
     --bad-tolerance=1000 \
     --verbose
   ```
   - `DUPLICATE_NODE`: Two rows with the same ID -- use `--skip-duplicate-nodes`
   - `MISSING_RELATIONSHIP_DATA`: Relationship references nonexistent node -- use `--skip-bad-relationships`
   - Header mismatch: Verify CSV header matches `--nodes`/`--relationships` column definitions

4. **APOC import debugging:**
   ```cypher
   -- Test JSON parsing
   CALL apoc.load.json('file:///data.json') YIELD value
   RETURN value LIMIT 3;
   
   -- Test with error handling
   CALL apoc.load.json('file:///data.json') YIELD value
   CALL {
     WITH value
     MERGE (n:Item {id: value.id})
     SET n.name = value.name
   } IN TRANSACTIONS OF 5000 ROWS
   ON ERROR CONTINUE;
   ```
