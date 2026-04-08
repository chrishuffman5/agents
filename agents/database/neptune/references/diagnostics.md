# Amazon Neptune Diagnostics Reference

> 130+ diagnostic commands for Amazon Neptune covering status endpoints, Gremlin/openCypher/SPARQL diagnostics, bulk loader, streams, AWS CLI, CloudWatch metrics, Neptune Analytics, and troubleshooting. Every command includes full syntax, what it reveals, key output fields, concerning thresholds, and remediation steps.

---

## Neptune Status Endpoints

### 1. Cluster Status (General Health)

```bash
curl -s "https://<cluster-endpoint>:8182/status"
```
**Shows:** Cluster health, role (writer/reader), engine version, start time, query language support.
**Key output fields:**
- `status` -- "healthy" (normal), "recovery" (restarting), or "snapshot-restore" (restoring from snapshot)
- `role` -- "writer" or "reader"
- `gremlin.version` -- TinkerPop version
- `opencypher.status` -- "enabled" or "disabled"
- `sparql.status` -- "enabled" or "disabled"
- `labMode` -- Active lab mode features (e.g., DFEQueryEngine)
- `startTime` -- Instance start time (ISO 8601)
- `dbEngineVersion` -- Neptune engine version (e.g., "1.3.2.0")
**Concerning:** Status not "healthy", role mismatch for the endpoint queried.
**Remediation:** Check CloudWatch for recent events. If "recovery", wait for completion. Check reboot events.

### 2. Gremlin Query Status

```bash
curl -s "https://<cluster-endpoint>:8182/gremlin/status"
```
**Shows:** All currently running and queued Gremlin queries.
**Key output fields:**
- `acceptedQueryCount` -- Total queries accepted since last restart
- `runningQueryCount` -- Currently executing queries
- `queries[].queryId` -- Unique query identifier
- `queries[].queryString` -- The Gremlin query text
- `queries[].queryEvalStats.waited` -- Time spent waiting (ms)
- `queries[].queryEvalStats.elapsed` -- Total elapsed time (ms)
- `queries[].queryEvalStats.subqueries` -- Number of subqueries
**Concerning:** High `runningQueryCount` (> 50), queries with elapsed > 60000 ms.
**Remediation:** Cancel long-running queries. Investigate slow queries with profile().

### 3. Gremlin Query Status (Specific Query)

```bash
curl -s "https://<cluster-endpoint>:8182/gremlin/status?queryId=<query-id>"
```
**Shows:** Status of a specific Gremlin query by ID.

### 4. Cancel a Running Gremlin Query

```bash
curl -s -X DELETE "https://<cluster-endpoint>:8182/gremlin/status?queryId=<query-id>&silent=true"
```
**Shows:** Confirmation of query cancellation.
**When to use:** Long-running queries consuming resources, runaway traversals.

### 5. SPARQL Query Status

```bash
curl -s "https://<cluster-endpoint>:8182/sparql/status"
```
**Shows:** All currently running and queued SPARQL queries.
**Key output fields:**
- `acceptedQueryCount` -- Total SPARQL queries accepted
- `runningQueryCount` -- Currently executing SPARQL queries
- `queries[].queryId` -- Unique query identifier
- `queries[].queryString` -- The SPARQL query text
- `queries[].queryEvalStats.elapsed` -- Elapsed time (ms)
**Concerning:** High `runningQueryCount`, queries with elapsed > 60000 ms.

### 6. Cancel a Running SPARQL Query

```bash
curl -s -X DELETE "https://<cluster-endpoint>:8182/sparql/status?queryId=<query-id>&silent=true"
```

### 7. openCypher Query Status

```bash
curl -s "https://<cluster-endpoint>:8182/openCypher/status"
```
**Shows:** All currently running and queued openCypher queries.
**Key output fields:**
- `acceptedQueryCount` -- Total openCypher queries accepted
- `runningQueryCount` -- Currently executing openCypher queries
- `queries[].queryId` -- Unique query identifier
- `queries[].queryString` -- The openCypher query text
- `queries[].queryEvalStats.elapsed` -- Elapsed time (ms)

### 8. Cancel a Running openCypher Query

```bash
curl -s -X DELETE "https://<cluster-endpoint>:8182/openCypher/status?queryId=<query-id>&silent=true"
```

### 9. System Status (Detailed Instance Info)

```bash
curl -s "https://<cluster-endpoint>:8182/system"
```
**Shows:** Detailed system information including memory usage, thread counts, and JVM stats.

---

## Gremlin Diagnostic Traversals

### 10. Total Vertex Count

```groovy
g.V().count()
```
**Shows:** Total number of vertices in the graph.
**Concerning:** If unexpected (much larger or smaller than expected), indicates data loading issues or data corruption.

### 11. Total Edge Count

```groovy
g.E().count()
```
**Shows:** Total number of edges in the graph.

### 12. Vertex Count by Label

```groovy
g.V().groupCount().by(label)
```
**Shows:** Distribution of vertices across labels. Identifies dominant entity types.
**Concerning:** Unexpected labels, or label counts far from expectations.

### 13. Edge Count by Label

```groovy
g.E().groupCount().by(label)
```
**Shows:** Distribution of edges across labels.

### 14. Sample Vertices (Quick Data Inspection)

```groovy
g.V().limit(10).valueMap(true).with(WithOptions.tokens)
```
**Shows:** First 10 vertices with all properties and metadata (id, label).

### 15. Sample Edges

```groovy
g.E().limit(10).valueMap(true).with(WithOptions.tokens)
```
**Shows:** First 10 edges with properties, IDs, labels, and connected vertex IDs.

### 16. Vertex by ID Lookup

```groovy
g.V('person:alice').valueMap(true).with(WithOptions.tokens)
```
**Shows:** All properties and metadata for a specific vertex. Verifies vertex existence.
**Concerning:** Returns empty result when vertex should exist -- data loading issue.

### 17. Edge by ID Lookup

```groovy
g.E('edge:e1').valueMap(true).with(WithOptions.tokens)
```

### 18. Outgoing Edges from a Vertex

```groovy
g.V('person:alice').outE().label().groupCount()
```
**Shows:** Count of outgoing edges by label for a specific vertex. Identifies supernodes.
**Concerning:** Any label count > 100,000 -- potential supernode.

### 19. Incoming Edges to a Vertex

```groovy
g.V('person:alice').inE().label().groupCount()
```
**Shows:** Count of incoming edges by label.

### 20. Detect Supernodes (High-Degree Vertices)

```groovy
g.V().where(outE().count().is(gt(10000))).project('id', 'label', 'degree').by(id).by(label).by(outE().count())
```
**Shows:** Vertices with more than 10,000 outgoing edges. These are supernodes that degrade traversal performance.
**Concerning:** Any result means supernodes exist.
**Remediation:** Implement edge partitioning, time-bucketing, or fan-out vertex patterns.

### 21. Detect Orphaned Vertices (No Edges)

```groovy
g.V().not(bothE()).count()
```
**Shows:** Count of vertices with zero edges (isolated vertices).
**Concerning:** High count may indicate incomplete data loading (edges failed to load).

### 22. List Distinct Property Keys on Vertices

```groovy
g.V().properties().key().dedup()
```
**Shows:** All distinct property keys used on any vertex.

### 23. List Distinct Property Keys on Edges

```groovy
g.E().properties().key().dedup()
```

### 24. Null Property Check (Vertices Missing Expected Property)

```groovy
g.V().hasLabel('Person').not(has('email')).count()
```
**Shows:** Count of Person vertices without an 'email' property. Identifies data quality issues.

### 25. Gremlin Explain (Static Query Plan)

```groovy
g.V().has('Person', 'name', 'Alice').out('KNOWS').values('name').explain()
```
**Shows:** The query execution plan without actually running the query. Shows which indexes are used, join strategies, and step ordering.
**Use when:** Understanding why a query is slow before running it in production.

### 26. Gremlin Profile (Executed Query Plan)

```groovy
g.V().has('Person', 'name', 'Alice').out('KNOWS').values('name').profile()
```
**Shows:** Per-step execution statistics including:
- Time spent in each step (ms)
- Number of traversers at each step
- Index usage
- DFE vs. non-DFE execution
**Concerning:** Steps with disproportionate time or traverser explosion (large counts at intermediate steps).
**Remediation:** Add filters or limits before expensive steps.

### 27. Gremlin Profile with DFE

```groovy
g.with('Neptune#useDFE', true).V().has('Person', 'name', 'Alice').out('KNOWS').values('name').profile()
```
**Shows:** Profile with the DFE engine enabled. Compare with non-DFE profile to evaluate performance impact.

### 28. Path Traversal Diagnostic

```groovy
g.V('person:alice').repeat(out('KNOWS').simplePath()).until(hasId('person:bob')).path().by('name').limit(5)
```
**Shows:** Up to 5 paths between two vertices. Use for validating connectivity and path lengths.
**Concerning:** Empty result means no path exists. Very long paths may indicate data model issues.

### 29. Connected Component Check (Reachability)

```groovy
g.V('person:alice').repeat(both().dedup()).emit().count()
```
**Shows:** Number of vertices reachable from a starting vertex. Verifies graph connectivity.

### 30. Average Edge Degree

```groovy
g.V().project('id', 'out', 'in').by(id).by(outE().count()).by(inE().count()).fold()
  .project('avgOut', 'avgIn')
  .by(unfold().select('out').mean())
  .by(unfold().select('in').mean())
```
**Shows:** Average in-degree and out-degree across all vertices. Characterizes graph density.

### 31. Traversal Latency Test (Simple Hop)

```groovy
g.V('person:alice').out('KNOWS').count()
```
**Shows:** Tests basic single-hop traversal latency. Run repeatedly to measure p50/p99.
**Concerning:** > 50 ms for a single hop with small fan-out suggests cold cache or underpowered instance.

### 32. Multi-Hop Traversal Test

```groovy
g.V('person:alice').out('KNOWS').out('KNOWS').dedup().count()
```
**Shows:** Tests 2-hop traversal. Compare latency to single-hop to assess fan-out impact.

### 33. Property Index Verification

```groovy
g.V().has('Person', 'email', 'test@example.com').profile()
```
**Shows:** Whether Neptune uses an index lookup for property queries. Check the profile output for "NeptuneIndexLookup" vs. "NeptuneScan".
**Concerning:** "NeptuneScan" means a full scan is occurring instead of an index lookup.

### 34. Edge Property Query Performance

```groovy
g.E().has('weight', gt(0.9)).count().profile()
```
**Shows:** Performance of edge property filtering. Verifies edge property indexing.

### 35. Drop All Data (CAUTION)

```groovy
g.V().drop()
```
**Shows:** Drops all vertices and edges. USE ONLY IN DEV/TEST.
**Warning:** This is irreversible. Always take a snapshot before.

---

## openCypher Diagnostic Queries

### 36. Total Node Count

```cypher
MATCH (n) RETURN count(n) AS nodeCount
```

### 37. Total Relationship Count

```cypher
MATCH ()-[r]->() RETURN count(r) AS relCount
```

### 38. Node Count by Label

```cypher
MATCH (n) RETURN labels(n) AS label, count(n) AS count ORDER BY count DESC
```

### 39. Relationship Count by Type

```cypher
MATCH ()-[r]->() RETURN type(r) AS relType, count(r) AS count ORDER BY count DESC
```

### 40. Sample Nodes (Quick Inspection)

```cypher
MATCH (n) RETURN n LIMIT 10
```

### 41. Sample Relationships

```cypher
MATCH (a)-[r]->(b) RETURN a, r, b LIMIT 10
```

### 42. Node by ID

```cypher
MATCH (n) WHERE id(n) = 'person:alice' RETURN n
```

### 43. Detect High-Degree Nodes (Supernodes)

```cypher
MATCH (n)-[r]->()
WITH n, count(r) AS degree
WHERE degree > 10000
RETURN id(n) AS nodeId, labels(n) AS labels, degree
ORDER BY degree DESC
LIMIT 20
```
**Concerning:** Any results -- these are supernodes.

### 44. Orphaned Nodes

```cypher
MATCH (n)
WHERE NOT (n)--()
RETURN count(n) AS orphanedCount
```

### 45. Distinct Property Keys

```cypher
MATCH (n) UNWIND keys(n) AS key RETURN DISTINCT key ORDER BY key
```

### 46. openCypher EXPLAIN

```cypher
EXPLAIN MATCH (p:Person {name: 'Alice'})-[:KNOWS]->(friend)
RETURN friend.name
```
**Shows:** Query execution plan. Look for "NodeByLabelScan" (efficient) vs. "AllNodesScan" (full scan).

### 47. Shortest Path Diagnostic

```cypher
MATCH p = shortestPath((a:Person {name: 'Alice'})-[:KNOWS*..10]-(b:Person {name: 'Bob'}))
RETURN length(p) AS pathLength, [node IN nodes(p) | node.name] AS names
```

### 48. Check for Duplicate Nodes

```cypher
MATCH (n:Person)
WITH n.email AS email, count(n) AS cnt
WHERE cnt > 1
RETURN email, cnt ORDER BY cnt DESC LIMIT 20
```

### 49. Variable-Length Path Performance Test

```cypher
MATCH (a:Person {name: 'Alice'})-[:KNOWS*1..3]->(b)
RETURN count(DISTINCT b) AS reachableIn3Hops
```

### 50. Aggregation Performance Test

```cypher
MATCH (p:Person)-[:WORKS_AT]->(c:Company)
RETURN c.name AS company, count(p) AS employees, avg(p.age) AS avgAge
ORDER BY employees DESC
LIMIT 20
```

---

## SPARQL Diagnostic Queries

### 51. Total Triple Count

```sparql
SELECT (COUNT(*) AS ?count) WHERE { ?s ?p ?o }
```

### 52. Triple Count by Predicate (Property Distribution)

```sparql
SELECT ?p (COUNT(*) AS ?count)
WHERE { ?s ?p ?o }
GROUP BY ?p
ORDER BY DESC(?count)
```
**Shows:** Distribution of triples across predicates. Identifies the most common relationships.

### 53. Triple Count by Named Graph

```sparql
SELECT ?g (COUNT(*) AS ?count)
WHERE { GRAPH ?g { ?s ?p ?o } }
GROUP BY ?g
ORDER BY DESC(?count)
```

### 54. Sample Triples

```sparql
SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 10
```

### 55. Describe a Specific Resource

```sparql
DESCRIBE <http://example.org/person/alice>
```
**Shows:** All triples where the given URI is the subject.

### 56. Count Distinct Subjects

```sparql
SELECT (COUNT(DISTINCT ?s) AS ?subjectCount) WHERE { ?s ?p ?o }
```

### 57. Count Distinct Predicates

```sparql
SELECT (COUNT(DISTINCT ?p) AS ?predicateCount) WHERE { ?s ?p ?o }
```

### 58. Count Distinct Objects

```sparql
SELECT (COUNT(DISTINCT ?o) AS ?objectCount) WHERE { ?s ?p ?o }
```

### 59. SPARQL Explain (Static Plan)

```bash
curl -s "https://<endpoint>:8182/sparql" \
  -d "query=SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 10" \
  -d "explain=static"
```
**Shows:** Static query plan. Look for "IndexScan" operations and join ordering.

### 60. SPARQL Explain (Dynamic/Executed Plan)

```bash
curl -s "https://<endpoint>:8182/sparql" \
  -d "query=SELECT ?name WHERE { <http://example.org/person/alice> <http://xmlns.com/foaf/0.1/knows> ?friend . ?friend <http://xmlns.com/foaf/0.1/name> ?name }" \
  -d "explain=dynamic"
```
**Shows:** Executed query plan with cardinalities and timing.

### 61. SPARQL Explain (Details Mode)

```bash
curl -s "https://<endpoint>:8182/sparql" \
  -d "query=SELECT ?name WHERE { ?s <http://xmlns.com/foaf/0.1/name> ?name }" \
  -d "explain=details"
```
**Shows:** Detailed plan with DFE pipeline information.

### 62. RDF Type Distribution (Ontology Check)

```sparql
SELECT ?type (COUNT(?s) AS ?count)
WHERE { ?s a ?type }
GROUP BY ?type
ORDER BY DESC(?count)
```
**Shows:** Count of instances per RDF type. Validates ontology instance data.

### 63. Orphaned Subjects (No Outgoing Predicates Except Type)

```sparql
SELECT ?s WHERE {
  ?s a ?type .
  FILTER NOT EXISTS { ?s ?p ?o . FILTER(?p != <http://www.w3.org/1999/02/22-rdf-syntax-ns#type>) }
}
LIMIT 20
```

### 64. Named Graphs List

```sparql
SELECT DISTINCT ?g WHERE { GRAPH ?g { ?s ?p ?o } }
```

### 65. Validate URI Patterns

```sparql
SELECT ?s WHERE {
  ?s ?p ?o .
  FILTER(isIRI(?s) && !STRSTARTS(STR(?s), "http://example.org/"))
}
LIMIT 20
```
**Shows:** Subjects that do not follow the expected namespace. Identifies data quality issues.

---

## Bulk Loader Diagnostics

### 66. Start a Bulk Load Job (Property Graph CSV)

```bash
curl -X POST "https://<cluster-endpoint>:8182/loader" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "s3://my-bucket/graph-data/",
    "format": "csv",
    "iamRoleArn": "arn:aws:iam::123456789012:role/NeptuneLoadFromS3",
    "region": "us-east-1",
    "failOnError": "FALSE",
    "parallelism": "OVERSUBSCRIBE",
    "updateSingleCardinalityProperties": "TRUE"
  }'
```
**Returns:** `{ "status": "200 OK", "payload": { "loadId": "<load-id>" } }`

### 67. Start a Bulk Load Job (RDF N-Triples)

```bash
curl -X POST "https://<cluster-endpoint>:8182/loader" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "s3://my-bucket/rdf-data/data.nt",
    "format": "ntriples",
    "iamRoleArn": "arn:aws:iam::123456789012:role/NeptuneLoadFromS3",
    "region": "us-east-1",
    "failOnError": "FALSE",
    "parallelism": "HIGH"
  }'
```

### 68. Check Load Job Status

```bash
curl -s "https://<cluster-endpoint>:8182/loader/<load-id>"
```
**Key output fields:**
- `payload.feedCount[].status` -- LOAD_COMPLETED, LOAD_IN_PROGRESS, LOAD_FAILED, LOAD_CANCELLED
- `payload.feedCount[].totalRecords` -- Total records processed
- `payload.feedCount[].totalDuplicates` -- Duplicate records skipped
- `payload.feedCount[].totalTimeSpent` -- Time spent (seconds)
- `payload.feedCount[].errors` -- Array of load errors
**Concerning:** LOAD_FAILED, high error count, totalDuplicates >> 0.

### 69. Check Load Job with Error Details

```bash
curl -s "https://<cluster-endpoint>:8182/loader/<load-id>?details=true&errors=true&page=1&errorsPerPage=10"
```
**Shows:** Detailed error messages for failed records including line numbers and error descriptions.
**Common errors:**
- "Could not find vertex" -- Edge references a non-existent vertex ID
- "Invalid type" -- Data type mismatch in CSV column
- "Malformed line" -- CSV formatting error (bad escaping, wrong column count)

### 70. List All Load Jobs

```bash
curl -s "https://<cluster-endpoint>:8182/loader?details=true"
```
**Shows:** All load jobs with their status.

### 71. Cancel a Load Job

```bash
curl -X DELETE "https://<cluster-endpoint>:8182/loader/<load-id>"
```

### 72. Check Load Job with Specific Feed Details

```bash
curl -s "https://<cluster-endpoint>:8182/loader/<load-id>?details=true&errors=true&page=1&errorsPerPage=50"
```
**Shows:** Paginated error details for debugging specific loading failures.

---

## Streams Diagnostics

### 73. Read Property Graph Stream (Latest Events)

```bash
curl -s "https://<cluster-endpoint>:8182/propertygraph/stream" \
  -H "Content-Type: application/json" \
  -d '{"limit": 10}'
```
**Key output fields:**
- `lastEventId` -- Sequence number of the last event in the response
- `lastTrxTimestamp` -- Timestamp of the last transaction
- `format` -- PG_JSON
- `records[].commitTimestamp` -- When the change was committed
- `records[].eventId` -- `{commitNum}:{opNum}`
- `records[].data.id` -- Vertex/edge ID
- `records[].data.type` -- "vl" (vertex label), "vp" (vertex property), "e" (edge), "ep" (edge property)
- `records[].op` -- "ADD" or "REMOVE"
**Use:** CDC consumer debugging, verifying stream data is flowing.

### 74. Read Property Graph Stream (From Specific Position)

```bash
curl -s "https://<cluster-endpoint>:8182/propertygraph/stream" \
  -H "Content-Type: application/json" \
  -d '{"limit": 100, "commitNum": 12345, "opNum": 1}'
```
**Shows:** Stream events starting after the specified commit number and operation number. Used for resuming consumption.

### 75. Read SPARQL Stream

```bash
curl -s "https://<cluster-endpoint>:8182/sparql/stream" \
  -H "Content-Type: application/json" \
  -d '{"limit": 10}'
```
**Key output fields:** Similar to property graph stream but records contain triples:
- `records[].data.stmt.s` -- Subject URI
- `records[].data.stmt.p` -- Predicate URI
- `records[].data.stmt.o` -- Object (URI or literal)
- `records[].data.stmt.g` -- Graph URI (if named graph)

### 76. Read SPARQL Stream (From Specific Position)

```bash
curl -s "https://<cluster-endpoint>:8182/sparql/stream" \
  -H "Content-Type: application/json" \
  -d '{"limit": 100, "commitNum": 12345, "opNum": 1}'
```

### 77. Check Stream Lag (Compare Last Event)

```bash
# Get the latest event from the stream
curl -s "https://<cluster-endpoint>:8182/propertygraph/stream" \
  -H "Content-Type: application/json" \
  -d '{"limit": 1, "iteratorType": "LATEST"}'
```
**Shows:** The most recent event in the stream. Compare `commitTimestamp` with the last processed timestamp in your consumer to measure lag.

---

## AWS CLI -- Neptune Database Management

### 78. Describe Neptune Cluster

```bash
aws neptune describe-db-clusters --db-cluster-identifier my-cluster
```
**Key output fields:**
- `DBClusters[].Status` -- "available", "creating", "deleting", "modifying", "backing-up"
- `DBClusters[].Engine` -- "neptune"
- `DBClusters[].EngineVersion` -- e.g., "1.3.2.0"
- `DBClusters[].Endpoint` -- Writer endpoint
- `DBClusters[].ReaderEndpoint` -- Reader endpoint
- `DBClusters[].DBClusterMembers[].DBInstanceIdentifier` -- Instance IDs
- `DBClusters[].DBClusterMembers[].IsClusterWriter` -- true/false
- `DBClusters[].DBClusterMembers[].DBClusterParameterGroupStatus` -- "in-sync" or "pending-reboot"
- `DBClusters[].StorageEncrypted` -- true/false
- `DBClusters[].IAMDatabaseAuthenticationEnabled` -- true/false
- `DBClusters[].ServerlessV2ScalingConfiguration` -- Min/Max NCU for serverless
- `DBClusters[].BackupRetentionPeriod` -- Days (1-35)
- `DBClusters[].PreferredBackupWindow` -- Backup window
- `DBClusters[].PreferredMaintenanceWindow` -- Maintenance window
**Concerning:** Status not "available", `IAMDatabaseAuthenticationEnabled: false`, `StorageEncrypted: false`, `BackupRetentionPeriod: 1`.

### 79. List All Neptune Clusters

```bash
aws neptune describe-db-clusters --query 'DBClusters[?Engine==`neptune`].[DBClusterIdentifier,Status,EngineVersion,Endpoint]' --output table
```

### 80. Describe Neptune Instance

```bash
aws neptune describe-db-instances --db-instance-identifier my-instance
```
**Key output fields:**
- `DBInstances[].DBInstanceStatus` -- "available", "creating", "modifying", "rebooting"
- `DBInstances[].DBInstanceClass` -- Instance type (e.g., "db.r6g.4xlarge")
- `DBInstances[].Engine` -- "neptune"
- `DBInstances[].EngineVersion` -- Neptune engine version
- `DBInstances[].Endpoint.Address` -- Instance endpoint DNS name
- `DBInstances[].AvailabilityZone` -- AZ placement
- `DBInstances[].PromotionTier` -- Failover priority (0=highest)
- `DBInstances[].AutoMinorVersionUpgrade` -- true/false
- `DBInstances[].PerformanceInsightsEnabled` -- true/false

### 81. List All Neptune Instances

```bash
aws neptune describe-db-instances --query 'DBInstances[?Engine==`neptune`].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus,AvailabilityZone]' --output table
```

### 82. Describe Cluster Parameter Group

```bash
aws neptune describe-db-cluster-parameters --db-cluster-parameter-group-name my-neptune-param-group
```
**Shows:** All parameter settings for the cluster. Look for:
- `neptune_query_timeout`
- `neptune_enable_audit_log`
- `neptune_streams`
- `neptune_streams_expiry_days`
- `neptune_enable_osgp_index`
- `neptune_lookup_cache`
- `neptune_result_cache`
- `neptune_lab_mode`

### 83. Describe Instance Parameter Group

```bash
aws neptune describe-db-parameters --db-parameter-group-name my-neptune-instance-param-group
```

### 84. List Tags on a Neptune Resource

```bash
aws neptune list-tags-for-resource --resource-name arn:aws:rds:us-east-1:123456789012:cluster:my-cluster
```

### 85. Check Cluster Endpoints

```bash
aws neptune describe-db-cluster-endpoints --db-cluster-identifier my-cluster
```
**Key output fields:**
- `DBClusterEndpoints[].Endpoint` -- DNS name
- `DBClusterEndpoints[].EndpointType` -- "WRITER", "READER", "CUSTOM"
- `DBClusterEndpoints[].Status` -- "available"
- `DBClusterEndpoints[].CustomEndpointType` -- "READER", "ANY" (for custom endpoints)
- `DBClusterEndpoints[].StaticMembers` / `.ExcludedMembers` -- Instance lists for custom endpoints

### 86. Check Pending Maintenance Actions

```bash
aws neptune describe-pending-maintenance-actions --resource-identifier arn:aws:rds:us-east-1:123456789012:cluster:my-cluster
```
**Concerning:** Pending actions with `AutoAppliedAfterDate` in the near future -- plan for maintenance.

### 87. Describe Event Subscriptions

```bash
aws neptune describe-event-subscriptions
```
**Shows:** SNS notification subscriptions for Neptune events (failover, maintenance, etc.).

### 88. List Recent Events

```bash
aws neptune describe-events --source-type db-cluster --source-identifier my-cluster --duration 1440
```
**Shows:** Events from the last 24 hours (1440 minutes). Look for failover, restart, and error events.
**Concerning:** "Failover", "Restart", "Error" events.

### 89. List Neptune Snapshots

```bash
aws neptune describe-db-cluster-snapshots --db-cluster-identifier my-cluster
```
**Key output fields:**
- `DBClusterSnapshots[].DBClusterSnapshotIdentifier`
- `DBClusterSnapshots[].Status` -- "available", "creating", "deleting"
- `DBClusterSnapshots[].SnapshotCreateTime`
- `DBClusterSnapshots[].AllocatedStorage` -- Size in GB
- `DBClusterSnapshots[].SnapshotType` -- "manual" or "automated"

### 90. Create a Manual Snapshot

```bash
aws neptune create-db-cluster-snapshot \
  --db-cluster-identifier my-cluster \
  --db-cluster-snapshot-identifier my-snapshot-$(date +%Y%m%d-%H%M%S)
```

### 91. Restore from Snapshot

```bash
aws neptune restore-db-cluster-from-snapshot \
  --db-cluster-identifier my-restored-cluster \
  --snapshot-identifier my-snapshot \
  --engine neptune \
  --vpc-security-group-ids sg-12345678 \
  --db-subnet-group-name my-subnet-group
```

### 92. Restore to Point in Time

```bash
aws neptune restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier my-cluster \
  --db-cluster-identifier my-pitr-cluster \
  --restore-to-time "2026-04-07T10:00:00Z" \
  --vpc-security-group-ids sg-12345678 \
  --db-subnet-group-name my-subnet-group
```

### 93. Check IAM Roles Attached to Cluster

```bash
aws neptune describe-db-clusters --db-cluster-identifier my-cluster \
  --query 'DBClusters[].AssociatedRoles'
```
**Shows:** IAM roles attached for S3 access (bulk loading), SageMaker access (Neptune ML), etc.
**Concerning:** Empty list when bulk loading is needed.

### 94. Add IAM Role to Cluster

```bash
aws neptune add-role-to-db-cluster \
  --db-cluster-identifier my-cluster \
  --role-arn arn:aws:iam::123456789012:role/NeptuneLoadFromS3
```

### 95. Modify Cluster Parameters

```bash
aws neptune modify-db-cluster-parameter-group \
  --db-cluster-parameter-group-name my-neptune-param-group \
  --parameters "ParameterName=neptune_enable_audit_log,ParameterValue=1,ApplyMethod=pending-reboot"
```

### 96. Reboot an Instance (Apply Parameter Changes)

```bash
aws neptune reboot-db-instance --db-instance-identifier my-instance
```
**Warning:** Causes brief downtime for the instance. If rebooting the writer, a failover occurs if replicas exist.

### 97. Failover Cluster (Manual Failover)

```bash
aws neptune failover-db-cluster --db-cluster-identifier my-cluster \
  --target-db-instance-identifier my-preferred-replica
```
**Shows:** Initiates a manual failover to the specified replica. Use for testing failover behavior.

### 98. Modify Instance Class (Vertical Scaling)

```bash
aws neptune modify-db-instance \
  --db-instance-identifier my-instance \
  --db-instance-class db.r6g.8xlarge \
  --apply-immediately
```
**Warning:** Causes downtime during instance class change. Consider blue/green deployment for production.

### 99. Enable Serverless Scaling

```bash
aws neptune modify-db-cluster \
  --db-cluster-identifier my-cluster \
  --serverless-v2-scaling-configuration MinCapacity=2.5,MaxCapacity=128
```

### 100. Delete a Cluster (with Final Snapshot)

```bash
aws neptune delete-db-instance --db-instance-identifier my-reader-instance --skip-final-snapshot
aws neptune delete-db-instance --db-instance-identifier my-writer-instance --skip-final-snapshot
aws neptune delete-db-cluster --db-cluster-identifier my-cluster \
  --final-db-snapshot-identifier my-final-snapshot
```
**Warning:** Deletes the cluster. Ensure final snapshot is taken.

---

## CloudWatch Metrics Queries

### 101. CPU Utilization (All Instances)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum \
  --output table
```
**Concerning:** Average > 80%, Maximum > 95%.
**Remediation:** Scale up instance, add read replicas, optimize queries.

### 102. Freeable Memory

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name FreeableMemory \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster Name=DBInstanceIdentifier,Value=my-writer \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Minimum Average \
  --output table
```
**Concerning:** Minimum < 1 GB on a large instance (approaching OOM).

### 103. Buffer Cache Hit Ratio

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name BufferCacheHitRatio \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster Name=DBInstanceIdentifier,Value=my-writer \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Minimum \
  --output table
```
**Concerning:** Average < 99.5% or Minimum < 95%.
**Remediation:** Upgrade to a larger instance (more memory for buffer cache).

### 104. Gremlin Requests Per Second

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name GremlinRequestsPerSec \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum Average Maximum \
  --output table
```

### 105. SPARQL Requests Per Second

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name SparqlRequestsPerSec \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum Average Maximum \
  --output table
```

### 106. openCypher Requests Per Second

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name OpenCypherRequestsPerSec \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum Average Maximum \
  --output table
```

### 107. Gremlin Errors

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name GremlinErrors \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum \
  --output table
```
**Concerning:** Sum > 0.
**Remediation:** Check query syntax, timeout settings, instance health.

### 108. SPARQL Errors

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name SparqlErrors \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum \
  --output table
```

### 109. openCypher Errors

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name OpenCypherErrors \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum \
  --output table
```

### 110. Pending Requests in Main Queue

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name MainRequestQueuePendingRequests \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster Name=DBInstanceIdentifier,Value=my-writer \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average Maximum \
  --output table
```
**Concerning:** Average > 50 or Maximum > 200 -- queries are queueing.
**Remediation:** Add read replicas, optimize queries, increase instance size.

### 111. Volume Bytes Used (Storage)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name VolumeBytesUsed \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average \
  --output table
```
**Shows:** Storage usage over time. Monitor for unexpected growth.

### 112. Transactions Committed

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name NumTxCommitted \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum \
  --output table
```

### 113. Transactions Rolled Back

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name NumTxRolledBack \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum \
  --output table
```
**Concerning:** Sum > 0 sustained -- indicates transaction conflicts or OCC failures.

### 114. Cluster Replica Lag

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name ClusterReplicaLag \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster Name=DBInstanceIdentifier,Value=my-reader-1 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average Maximum \
  --output table
```
**Concerning:** Average > 200 ms, Maximum > 1000 ms.

### 115. Engine Uptime

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name EngineUptime \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster Name=DBInstanceIdentifier,Value=my-writer \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Minimum \
  --output table
```
**Concerning:** Minimum drops to 0 -- indicates a restart or failover occurred.

### 116. Loader Requests Per Second

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name LoaderRequestsPerSec \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average Maximum \
  --output table
```

### 117. Serverless NCU Consumption (Database)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Neptune \
  --metric-name ServerlessDatabaseCapacity \
  --dimensions Name=DBClusterIdentifier,Value=my-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average Maximum \
  --output table
```
**Shows:** NCU consumption over time for serverless instances. Use to tune min/max NCU settings.

---

## Audit Log Analysis

### 118. View Neptune Audit Logs (CloudWatch Logs)

```bash
aws logs describe-log-groups --log-group-name-prefix /aws/neptune/my-cluster/audit
```
**Shows:** Whether audit log group exists for the cluster.

### 119. Query Audit Logs (Recent Queries)

```bash
aws logs filter-log-events \
  --log-group-name /aws/neptune/my-cluster/audit \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --end-time $(date -u +%s)000 \
  --limit 50
```
**Shows:** Recent queries logged with timestamps, client IP, query text, and status.

### 120. Find Slow Queries in Audit Logs

```bash
aws logs filter-log-events \
  --log-group-name /aws/neptune/my-cluster/audit \
  --filter-pattern "{ $.queryTime > 5000 }" \
  --start-time $(date -u -d '24 hours ago' +%s)000 \
  --end-time $(date -u +%s)000 \
  --limit 100
```
**Shows:** Queries that took longer than 5 seconds. Candidates for optimization.

### 121. Find Failed Queries in Audit Logs

```bash
aws logs filter-log-events \
  --log-group-name /aws/neptune/my-cluster/audit \
  --filter-pattern "{ $.status = \"Failure\" }" \
  --start-time $(date -u -d '24 hours ago' +%s)000 \
  --end-time $(date -u +%s)000 \
  --limit 100
```

### 122. Find Queries by Client IP

```bash
aws logs filter-log-events \
  --log-group-name /aws/neptune/my-cluster/audit \
  --filter-pattern "{ $.clientHost = \"10.0.1.50\" }" \
  --start-time $(date -u -d '24 hours ago' +%s)000 \
  --end-time $(date -u +%s)000 \
  --limit 50
```

### 123. Find Gremlin-Specific Queries in Audit Logs

```bash
aws logs filter-log-events \
  --log-group-name /aws/neptune/my-cluster/audit \
  --filter-pattern "{ $.queryLanguage = \"Gremlin\" }" \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --end-time $(date -u +%s)000 \
  --limit 50
```

---

## Neptune Analytics Diagnostics

### 124. List Neptune Analytics Graphs

```bash
aws neptune-graph list-graphs
```
**Key output fields:**
- `graphs[].id` -- Graph identifier
- `graphs[].name` -- Graph name
- `graphs[].status` -- "AVAILABLE", "CREATING", "DELETING", "FAILED"
- `graphs[].provisionedMemory` -- Provisioned memory in GB
- `graphs[].endpoint` -- Graph endpoint URL
- `graphs[].buildNumber` -- Engine build version

### 125. Describe a Neptune Analytics Graph

```bash
aws neptune-graph get-graph --graph-identifier my-analytics-graph
```
**Key output fields:**
- `id`, `name`, `arn`
- `status` -- "AVAILABLE", "CREATING", etc.
- `statusReason` -- Reason if status is not AVAILABLE
- `provisionedMemory` -- Memory in GB
- `endpoint` -- Endpoint for openCypher queries
- `vectorSearchConfiguration` -- Dimension of vector embeddings if enabled
- `replicaCount` -- Number of replicas

### 126. Create a Neptune Analytics Graph

```bash
aws neptune-graph create-graph \
  --graph-name my-analytics-graph \
  --provisioned-memory 128 \
  --public-connectivity false \
  --vector-search-configuration dimension=256 \
  --tags Key=Environment,Value=Production
```

### 127. Delete a Neptune Analytics Graph

```bash
aws neptune-graph delete-graph --graph-identifier my-analytics-graph --skip-snapshot
```

### 128. Start an Import Task (S3 to Neptune Analytics)

```bash
aws neptune-graph start-import-task \
  --graph-identifier my-analytics-graph \
  --source "s3://my-bucket/graph-data/" \
  --format CSV \
  --role-arn arn:aws:iam::123456789012:role/NeptuneAnalyticsImportRole
```

### 129. Check Import Task Status

```bash
aws neptune-graph get-import-task --task-identifier my-import-task-id
```
**Key output fields:**
- `status` -- "IN_PROGRESS", "COMPLETED", "FAILED", "CANCELLING", "CANCELLED"
- `importOptions` -- Format, S3 source
- `importTaskDetails.startTime`, `importTaskDetails.timeElapsedSeconds`
- `importTaskDetails.progressPercentage`
- `importTaskDetails.errorCount`
- `importTaskDetails.errorDetails`

### 130. List Import Tasks

```bash
aws neptune-graph list-import-tasks --graph-identifier my-analytics-graph
```

### 131. Run openCypher Query on Neptune Analytics

```bash
aws neptune-graph execute-query \
  --graph-identifier my-analytics-graph \
  --query-string "MATCH (n) RETURN count(n) AS nodeCount" \
  --language OPEN_CYPHER \
  output.json
```

### 132. Run PageRank on Neptune Analytics

```bash
aws neptune-graph execute-query \
  --graph-identifier my-analytics-graph \
  --query-string "CALL neptune.algo.pageRank() YIELD node, score RETURN node, score ORDER BY score DESC LIMIT 10" \
  --language OPEN_CYPHER \
  output.json
```

### 133. Vector Search on Neptune Analytics

```bash
aws neptune-graph execute-query \
  --graph-identifier my-analytics-graph \
  --query-string "CALL neptune.algo.vectors.topKByNode({node: 'product:123', k: 10}) YIELD node, score RETURN node, score" \
  --language OPEN_CYPHER \
  output.json
```

### 134. Reset (Clear) a Neptune Analytics Graph

```bash
aws neptune-graph reset-graph --graph-identifier my-analytics-graph --perform-clean-up true
```
**Warning:** Deletes all data in the graph. Use before reloading fresh data.

### 135. Create Graph from Neptune Database Snapshot

```bash
aws neptune-graph create-graph-using-import-task \
  --graph-name analytics-from-snapshot \
  --source "arn:aws:rds:us-east-1:123456789012:cluster-snapshot:my-neptune-snapshot" \
  --role-arn arn:aws:iam::123456789012:role/NeptuneAnalyticsImportRole \
  --provisioned-memory 256 \
  --public-connectivity false
```

---

## Neptune Global Database

### 136. Create a Global Database

```bash
aws neptune create-global-cluster \
  --global-cluster-identifier my-global-graph \
  --source-db-cluster-identifier arn:aws:rds:us-east-1:123456789012:cluster:my-primary-cluster
```

### 137. Add a Secondary Region

```bash
aws neptune create-db-cluster \
  --db-cluster-identifier my-secondary-cluster \
  --engine neptune \
  --global-cluster-identifier my-global-graph \
  --region eu-west-1
```

### 138. Describe Global Database

```bash
aws neptune describe-global-clusters --global-cluster-identifier my-global-graph
```
**Key output fields:**
- `GlobalClusters[].Status` -- "available"
- `GlobalClusters[].GlobalClusterMembers[].DBClusterArn` -- Member cluster ARNs
- `GlobalClusters[].GlobalClusterMembers[].IsWriter` -- true for primary region
- `GlobalClusters[].GlobalClusterMembers[].GlobalWriteForwardingStatus` -- write forwarding status

### 139. Failover Global Database

```bash
aws neptune failover-global-cluster \
  --global-cluster-identifier my-global-graph \
  --target-db-cluster-identifier arn:aws:rds:eu-west-1:123456789012:cluster:my-secondary-cluster
```
**Warning:** Promotes a secondary region to primary. The old primary becomes a secondary.

---

## Neptune ML Diagnostics

### 140. Neptune Export (Data Export to S3 for ML)

```bash
curl -X POST "https://<cluster-endpoint>:8182/ml/dataprocessing" \
  -H "Content-Type: application/json" \
  -d '{
    "inputDataS3Location": "s3://my-bucket/neptune-export/",
    "processedDataS3Location": "s3://my-bucket/neptune-ml-processed/",
    "sagemakerIamRoleArn": "arn:aws:iam::123456789012:role/NeptuneSageMakerRole",
    "neptuneIamRoleArn": "arn:aws:iam::123456789012:role/NeptuneMLRole"
  }'
```

### 141. Check ML Data Processing Job Status

```bash
curl -s "https://<cluster-endpoint>:8182/ml/dataprocessing/<processing-id>"
```
**Key output fields:**
- `status` -- "InProgress", "Completed", "Failed"
- `outputS3Location` -- Where processed data is stored

### 142. Start ML Model Training

```bash
curl -X POST "https://<cluster-endpoint>:8182/ml/modeltraining" \
  -H "Content-Type: application/json" \
  -d '{
    "dataProcessingJobId": "<processing-id>",
    "trainModelS3Location": "s3://my-bucket/neptune-ml-model/",
    "sagemakerIamRoleArn": "arn:aws:iam::123456789012:role/NeptuneSageMakerRole",
    "neptuneIamRoleArn": "arn:aws:iam::123456789012:role/NeptuneMLRole",
    "maxHPONumberOfTrainingJobs": 10,
    "maxHPOParallelTrainingJobs": 2
  }'
```

### 143. Check ML Model Training Status

```bash
curl -s "https://<cluster-endpoint>:8182/ml/modeltraining/<training-id>"
```
**Key output fields:**
- `status` -- "InProgress", "Completed", "Failed"
- `mlModels[].modelId` -- Model identifiers
- `hpoJob.status` -- Hyperparameter optimization status

### 144. Create ML Inference Endpoint

```bash
curl -X POST "https://<cluster-endpoint>:8182/ml/endpoints" \
  -H "Content-Type: application/json" \
  -d '{
    "mlModelTrainingJobId": "<training-id>",
    "neptuneIamRoleArn": "arn:aws:iam::123456789012:role/NeptuneMLRole"
  }'
```

### 145. List ML Endpoints

```bash
curl -s "https://<cluster-endpoint>:8182/ml/endpoints"
```

### 146. Check ML Endpoint Status

```bash
curl -s "https://<cluster-endpoint>:8182/ml/endpoints/<endpoint-id>"
```
**Key output fields:**
- `status` -- "InService", "Creating", "Failed"
- `endpoint.name` -- SageMaker endpoint name
- `endpoint.instanceType` -- SageMaker instance type

### 147. Delete ML Endpoint

```bash
curl -X DELETE "https://<cluster-endpoint>:8182/ml/endpoints/<endpoint-id>"
```

---

## Connectivity and Network Diagnostics

### 148. Test Neptune Connectivity

```bash
# Test TCP connectivity to Neptune endpoint
nc -zv <cluster-endpoint> 8182

# Alternative with timeout
timeout 5 bash -c "echo > /dev/tcp/<cluster-endpoint>/8182" && echo "Connected" || echo "Failed"
```

### 149. Test Neptune Status with IAM Auth (SigV4)

```bash
# Using awscurl (pip install awscurl)
awscurl --service neptune-db --region us-east-1 \
  "https://<cluster-endpoint>:8182/status"
```

### 150. Test Gremlin Endpoint with IAM Auth

```bash
awscurl --service neptune-db --region us-east-1 \
  -X POST "https://<cluster-endpoint>:8182/gremlin" \
  -H "Content-Type: application/json" \
  -d '{"gremlin": "g.V().limit(1).valueMap(true)"}'
```

### 151. Test openCypher Endpoint with IAM Auth

```bash
awscurl --service neptune-db --region us-east-1 \
  -X POST "https://<cluster-endpoint>:8182/openCypher" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "query=MATCH (n) RETURN n LIMIT 1"
```

### 152. Test SPARQL Endpoint with IAM Auth

```bash
awscurl --service neptune-db --region us-east-1 \
  -X POST "https://<cluster-endpoint>:8182/sparql" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "query=SELECT * WHERE { ?s ?p ?o } LIMIT 1"
```

### 153. DNS Resolution Check

```bash
nslookup <cluster-endpoint>
```
**Concerning:** NXDOMAIN or timeout -- DNS resolution failure. Verify VPC DNS settings.

### 154. Security Group Verification

```bash
aws ec2 describe-security-groups --group-ids sg-12345678 \
  --query 'SecurityGroups[].IpPermissions[?ToPort==`8182`]'
```
**Shows:** Inbound rules allowing traffic on port 8182.

---

## Troubleshooting Quick Reference

### Common Error Messages and Resolution

| Error | Cause | Resolution |
|---|---|---|
| `ReadOnlyViolationException` | Write sent to read replica | Direct writes to the cluster (writer) endpoint |
| `QueryLimitExceededException` | Query exceeded timeout or memory | Add `limit()`, increase `neptune_query_timeout`, scale up instance |
| `ConcurrentModificationException` | Optimistic concurrency conflict | Retry the transaction with backoff |
| `ConstraintViolationException` | Duplicate vertex/edge ID on insert | Use upsert pattern (fold/coalesce) or check existence first |
| `TimeLimitExceededException` | Query exceeded configured timeout | Optimize the query, increase timeout, or add `limit()` |
| `MalformedQueryException` | Syntax error in query | Check query syntax for the specific language |
| `AccessDeniedException` | IAM policy does not permit the action | Verify IAM policy includes `neptune-db:*` or specific actions |
| `ThrottlingException` | Rate limiting on API calls | Implement exponential backoff and retry |
| `InvalidParameterException` | Invalid loader parameter | Verify S3 path, format, IAM role ARN |
| `S3Exception` (bulk load) | Cannot access S3 bucket | Verify IAM role attached to cluster, S3 bucket in same region, S3 VPC endpoint |
| `MemoryLimitExceededException` | Instance out of memory | Scale up instance, reduce concurrent queries, add `limit()` |

### Performance Diagnostic Checklist

1. **Check instance health:**
   ```bash
   curl -s "https://<endpoint>:8182/status" | jq .
   ```

2. **Check running queries:**
   ```bash
   curl -s "https://<endpoint>:8182/gremlin/status" | jq .runningQueryCount
   curl -s "https://<endpoint>:8182/sparql/status" | jq .runningQueryCount
   curl -s "https://<endpoint>:8182/openCypher/status" | jq .runningQueryCount
   ```

3. **Check buffer cache:**
   ```bash
   # CloudWatch: BufferCacheHitRatio should be > 99%
   aws cloudwatch get-metric-statistics --namespace AWS/Neptune \
     --metric-name BufferCacheHitRatio --dimensions Name=DBInstanceIdentifier,Value=my-writer \
     --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Average
   ```

4. **Profile the slow query:**
   ```groovy
   g.V().has('Person', 'name', 'Alice').out('KNOWS').out('KNOWS').count().profile()
   ```

5. **Check for supernodes:**
   ```groovy
   g.V().where(bothE().count().is(gt(10000))).project('id', 'degree').by(id).by(bothE().count())
   ```

6. **Check pending requests:**
   ```bash
   aws cloudwatch get-metric-statistics --namespace AWS/Neptune \
     --metric-name MainRequestQueuePendingRequests --dimensions Name=DBInstanceIdentifier,Value=my-writer \
     --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Maximum
   ```

7. **Check replica lag (if using replicas for reads):**
   ```bash
   aws cloudwatch get-metric-statistics --namespace AWS/Neptune \
     --metric-name ClusterReplicaLag --dimensions Name=DBInstanceIdentifier,Value=my-reader-1 \
     --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Average Maximum
   ```
