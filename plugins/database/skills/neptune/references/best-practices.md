# Amazon Neptune Best Practices Reference

## Graph Data Modeling

### Property Graph Modeling

**Choosing vertex labels:**
- Use a single, specific label per vertex type (e.g., `Person`, `Company`, `Account`)
- Neptune supports multiple labels per vertex, but queries perform best with a single primary label
- Labels are indexed -- use them for type-based filtering

**Choosing edge labels:**
- Use descriptive, directional labels: `WORKS_AT`, `PURCHASED`, `TRANSFERRED_TO`
- Avoid generic labels like `RELATED_TO` or `HAS` -- they make traversals ambiguous and slow
- Keep the number of distinct edge labels manageable (hundreds, not thousands)

**Property design:**
- Use typed properties: Neptune supports boolean, byte, short, int, long, float, double, string, datetime
- For CSV bulk loading, specify types in column headers: `name:String`, `age:Int`, `balance:Double`, `created:Date`
- Keep property values small. Store large documents in S3 and reference them by URI.
- Multi-valued properties: Neptune supports set cardinality (multiple values for the same property key on a vertex)

**Vertex ID strategy:**
- Always assign explicit, meaningful IDs: `person:alice`, `account:12345`, `product:SKU-789`
- Use a prefix convention to encode type into the ID: `{type}:{identifier}`
- This allows O(1) lookups by ID and avoids reliance on label+property scans
- Avoid auto-generated UUIDs unless necessary -- meaningful IDs improve debugging and logging

**Edge ID strategy:**
- Edge IDs are optional but recommended for updateability
- Without an explicit edge ID, Neptune auto-generates one, making it harder to reference later
- Convention: `{from_id}-{label}-{to_id}` or `{from_id}-{label}-{to_id}-{discriminator}` for parallel edges

### Supernode Mitigation

Supernodes (vertices with millions of edges) degrade traversal performance because every traversal through a supernode must scan all its edges.

**Strategies:**

1. **Edge label partitioning:** Use specific edge labels instead of generic ones. Instead of one `FOLLOWS` edge type, split into `FOLLOWS_USER`, `FOLLOWS_TOPIC`, `FOLLOWS_PAGE` -- then traversals can target only relevant edges.

2. **Time bucketing:** Create intermediate "bucket" vertices for temporal data:
   ```
   (celebrity)-[:HAS_FOLLOWERS_2025_Q1]->(bucket1)-[:FOLLOWER]->(user1)
   (celebrity)-[:HAS_FOLLOWERS_2025_Q2]->(bucket2)-[:FOLLOWER]->(user2)
   ```

3. **Fan-out vertices:** Insert intermediate routing vertices:
   ```
   (airport)-[:FLIGHTS_TO_US]->(region_us)-[:FLIGHT]->(flight1)
   (airport)-[:FLIGHTS_TO_EU]->(region_eu)-[:FLIGHT]->(flight2)
   ```

4. **Property filtering:** If edges have distinguishing properties, use them to narrow traversals:
   ```groovy
   g.V('supernode').outE('PURCHASED').has('year', 2025).inV()
   ```

### RDF Modeling Best Practices

- Define a clear namespace: `@prefix app: <http://example.org/app/>`
- Use well-known vocabularies: `foaf:`, `schema:`, `dcterms:`, `skos:`
- Model type hierarchies with `rdfs:subClassOf`
- Use named graphs for data provenance, versioning, or access control
- Avoid blank nodes for entities that need stable references
- Use `xsd:dateTime` for temporal literals
- Keep predicate URIs consistent (choose one URI per concept and stick with it)

## Query Optimization

### Gremlin Optimization

**Use explain and profile:**
```groovy
// Static query plan (no execution)
g.V().has('Person', 'name', 'Alice').out('KNOWS').explain()

// Executed plan with runtime statistics
g.V().has('Person', 'name', 'Alice').out('KNOWS').profile()
```

**Optimization rules:**

1. **Start traversals with specific lookups:**
   ```groovy
   // GOOD: Start with a specific vertex by ID
   g.V('person:alice').out('KNOWS')

   // GOOD: Start with an indexed property lookup
   g.V().has('Person', 'email', 'alice@example.com')

   // BAD: Start with a full scan
   g.V().hasLabel('Person').has('name', 'Alice')  // Only bad if 'name' is not selective
   ```

2. **Filter early, traverse late:**
   ```groovy
   // GOOD: Filter before expensive traversal
   g.V().has('Person', 'status', 'active').out('KNOWS').count()

   // BAD: Traverse first, then filter
   g.V().hasLabel('Person').out('KNOWS').has('status', 'active').count()
   ```

3. **Limit fan-out:**
   ```groovy
   // GOOD: Limit edges traversed
   g.V('person:alice').outE('KNOWS').limit(100).inV().values('name')

   // BAD: Traverse all edges from a potential supernode
   g.V('person:alice').out('KNOWS').values('name')
   ```

4. **Use valueMap instead of multiple values() calls:**
   ```groovy
   // GOOD: Single step to retrieve multiple properties
   g.V('person:alice').valueMap('name', 'age', 'email')

   // BAD: Multiple values() calls
   g.V('person:alice').values('name')
   g.V('person:alice').values('age')
   ```

5. **Avoid mid-traversal V() steps:**
   ```groovy
   // BAD: V() in the middle restarts from the entire graph
   g.V('person:alice').out('KNOWS').V().hasLabel('Company')

   // GOOD: Continue the traversal
   g.V('person:alice').out('KNOWS').out('WORKS_AT')
   ```

6. **Use fold/coalesce for conditional upserts:**
   ```groovy
   // Efficient conditional insert
   g.V().has('Person', 'email', 'alice@example.com')
     .fold()
     .coalesce(
       unfold(),
       addV('Person').property('email', 'alice@example.com')
     )
     .property(single, 'name', 'Alice')
   ```

7. **Batch writes with inject/unfold:**
   ```groovy
   // Batch multiple inserts in a single query
   g.inject([
     [id: 'p1', name: 'Alice', age: 30],
     [id: 'p2', name: 'Bob', age: 25]
   ]).unfold().as('row')
    .addV('Person')
    .property(id, select('row').select('id'))
    .property('name', select('row').select('name'))
    .property('age', select('row').select('age'))
   ```

### openCypher Optimization

1. **Use parameterized queries:**
   ```cypher
   -- Avoids query plan recompilation
   MATCH (p:Person {name: $name}) RETURN p
   ```

2. **Limit variable-length paths:**
   ```cypher
   -- GOOD: Bounded path length
   MATCH (a)-[:KNOWS*1..3]->(b) RETURN b

   -- BAD: Unbounded (can explode on large graphs)
   MATCH (a)-[:KNOWS*]->(b) RETURN b
   ```

3. **Use EXPLAIN for plan inspection:**
   ```cypher
   EXPLAIN MATCH (p:Person)-[:WORKS_AT]->(c:Company) WHERE p.age > 30 RETURN p, c
   ```

4. **Filter with WHERE close to the MATCH:**
   ```cypher
   -- GOOD: Filter in MATCH or immediately after
   MATCH (p:Person {status: 'active'})-[:KNOWS]->(f)
   RETURN f.name

   -- AVOID: Late filtering after large intermediate result
   MATCH (p:Person)-[:KNOWS]->(f)
   WHERE p.status = 'active'
   RETURN f.name
   ```

5. **Use MERGE carefully:**
   ```cypher
   -- GOOD: MERGE on a unique property
   MERGE (p:Person {email: 'alice@example.com'})

   -- BAD: MERGE on multiple properties (may create duplicates if any property differs)
   MERGE (p:Person {name: 'Alice', age: 30, city: 'NYC'})
   ```

### SPARQL Optimization

1. **Use selective triple patterns first:**
   ```sparql
   -- GOOD: Start with the most selective pattern
   SELECT ?name WHERE {
     <http://example.org/person/alice> foaf:knows ?friend .
     ?friend foaf:name ?name .
   }

   -- BAD: Start with a scan
   SELECT ?name WHERE {
     ?friend foaf:name ?name .
     <http://example.org/person/alice> foaf:knows ?friend .
   }
   ```
   Neptune's optimizer reorders patterns, but explicit ordering helps.

2. **Use FILTER placement:**
   ```sparql
   -- GOOD: FILTER immediately after the pattern it constrains
   SELECT ?person ?age WHERE {
     ?person foaf:age ?age .
     FILTER (?age > 25)
     ?person foaf:name ?name .
   }
   ```

3. **Avoid SELECT * in production:**
   ```sparql
   -- GOOD: Select only needed variables
   SELECT ?name ?email WHERE { ... }

   -- AVOID: Wildcard projection
   SELECT * WHERE { ... }
   ```

4. **Use BIND for computed values:**
   ```sparql
   SELECT ?person ?fullName WHERE {
     ?person foaf:firstName ?first .
     ?person foaf:lastName ?last .
     BIND(CONCAT(?first, " ", ?last) AS ?fullName)
   }
   ```

5. **Enable the OSGP index for reverse lookups:**
   If your queries frequently search by object value (e.g., `?s ?p "specific-value"`), enable the OSGP index in the parameter group.

## Bulk Loading Best Practices

### Data Preparation

**CSV format for property graph:**
```csv
# vertices.csv -- Required columns: ~id, ~label
~id,~label,name:String,age:Int,balance:Double,created:Date
person:alice,Person,Alice,30,1500.50,2024-01-15
person:bob,Person,Bob,25,2300.00,2024-02-20
company:acme,Company,ACME Corp,,500000.00,2020-06-01

# edges.csv -- Required columns: ~id, ~label, ~from, ~to
~id,~label,~from,~to,since:Int,weight:Double
e1,WORKS_AT,person:alice,company:acme,2022,1.0
e2,KNOWS,person:alice,person:bob,2020,0.8
```

**Data type suffixes for CSV columns:**
| Suffix | Type | Example |
|---|---|---|
| `:String` | String (default) | `name:String` |
| `:Int` | Integer (32-bit) | `age:Int` |
| `:Long` | Long (64-bit) | `timestamp:Long` |
| `:Float` | Float (32-bit) | `score:Float` |
| `:Double` | Double (64-bit) | `balance:Double` |
| `:Bool` | Boolean | `active:Bool` |
| `:Date` | ISO 8601 date/datetime | `created:Date` |
| `:Byte` | Byte | `flags:Byte` |
| `:Short` | Short (16-bit) | `rank:Short` |

**RDF format (N-Triples):**
```
<http://example.org/person/alice> <http://xmlns.com/foaf/0.1/name> "Alice" .
<http://example.org/person/alice> <http://xmlns.com/foaf/0.1/age> "30"^^<http://www.w3.org/2001/XMLSchema#integer> .
<http://example.org/person/alice> <http://xmlns.com/foaf/0.1/knows> <http://example.org/person/bob> .
```

### Loader Configuration

**Parallelism settings:**

| Setting | Description | When to Use |
|---|---|---|
| `LOW` | Single-threaded loading | Small datasets, minimal impact on running queries |
| `MEDIUM` | Multi-threaded, moderate resource use | Medium datasets with concurrent queries |
| `HIGH` | Multi-threaded, high resource use | Large datasets, dedicated load window |
| `OVERSUBSCRIBE` | Maximum parallelism | Fastest load, no concurrent queries expected |

**Error handling:**
- `failOnError: "FALSE"` -- Continue loading despite errors (recommended for large loads). Review errors after.
- `failOnError: "TRUE"` -- Stop on first error. Use for small, critical datasets.
- Error log: Available via `GET /loader/{loadId}?details=true&errors=true`

**Incremental loading:**
- `updateSingleCardinalityProperties: "TRUE"` -- Update existing vertex/edge properties on ID conflict (upsert behavior)
- `updateSingleCardinalityProperties: "FALSE"` -- Skip conflicting records (default)

**Load from multiple files:**
- Point the `source` to an S3 prefix (folder). Neptune loads all files under that prefix.
- Use file naming to control load order: `001-vertices.csv`, `002-edges.csv`
- Load vertices before edges (edges reference vertex IDs)

### S3 Configuration for Loading

- S3 bucket must be in the same AWS region as the Neptune cluster
- Neptune IAM role must have `s3:GetObject`, `s3:ListBucket` on the bucket
- The IAM role must be attached to the Neptune cluster (`aws neptune add-role-to-db-cluster`)
- Use S3 VPC endpoint (gateway endpoint) for private network loading -- avoids NAT gateway costs
- Compress files with gzip for faster transfer: Neptune auto-detects `.gz` extension

### Performance Tips for Bulk Loading

1. **Use OVERSUBSCRIBE parallelism** for initial loads when no queries are running
2. **Gzip compress** all CSV/RDF files (reduces S3 transfer time)
3. **Split large files** into multiple smaller files (100 MB - 1 GB each) for parallel loading
4. **Load vertices before edges** -- edges reference vertex IDs that must exist
5. **Use the largest instance available** during the initial load, then scale down
6. **Monitor the load** via `GET /loader/{loadId}` and check for errors
7. **Disable audit logging** during bulk load to reduce overhead (re-enable after)

## Operational Best Practices

### Instance Sizing

**Memory is the primary scaling dimension.** Neptune performance is dominated by how much of the graph fits in the buffer cache.

**Sizing approach:**
1. Estimate graph size: `(vertex count x avg vertex size) + (edge count x avg edge size) + (property count x avg property size)`
2. Multiply by 2-3x for index overhead
3. Choose an instance with at least that much memory (75% of instance memory is buffer cache)
4. If graph > single instance memory, consider queries will hit storage (slower but functional)

**Rules of thumb:**
- 1 billion edges: ~32-64 GB graph data, needs db.r6g.4xlarge (128 GB) or larger
- 10 billion edges: ~320-640 GB graph data, needs db.x2g.8xlarge (512 GB) or db.x2iedn
- For Neptune Serverless: Start with min 2.5 NCU, max 128 NCU and adjust based on observed scaling

### Read Replica Strategy

- **Minimum for production:** 1 writer + 1 read replica in a different AZ
- **Read-heavy workloads:** Add replicas as needed (up to 15). Use the reader endpoint for automatic load balancing.
- **Failover priority:** Set the most capable replica to priority tier 0 for fastest failover
- **Mixed instance sizes:** Use larger replicas for heavy analytical queries, smaller replicas for simple lookups
- **Cross-AZ replicas:** Ensure at least one replica in a different AZ than the writer for HA

### Connection Management

**Gremlin connections:**
- Use WebSocket connections (persistent, lower overhead than HTTP)
- Connection pool size: 8-64 connections per client application
- Use the Gremlin driver's built-in connection pooling (Java: `Cluster.build()`, Python: `DriverRemoteConnection`)
- Set `maxConnectionPoolSize`, `minConnectionPoolSize`, `maxInProcessPerConnection` in the driver
- Close connections gracefully on application shutdown

**openCypher connections:**
- HTTP: Use connection pooling in your HTTP client (keep-alive)
- Bolt protocol: Use the Neo4j driver with connection pooling
  ```
  bolt://<endpoint>:8182
  ```
- IAM authentication: Use the `neptune_iam_bolt_plugin` for Bolt connections

**SPARQL connections:**
- HTTP with Keep-Alive headers
- Use a SPARQL client library with connection pooling (Apache Jena, RDF4J)

### Parameter Group Tuning

Key parameters in the Neptune cluster parameter group:

| Parameter | Default | Recommendation |
|---|---|---|
| `neptune_query_timeout` | 120000 ms | Increase for complex analytical queries (up to 7200000 ms) |
| `neptune_enable_audit_log` | 0 | Enable (1) for production compliance; disable during bulk loads |
| `neptune_streams` | 0 | Enable (1) if you need CDC |
| `neptune_streams_expiry_days` | 7 | Adjust based on consumer lag tolerance (1-90 days) |
| `neptune_enable_osgp_index` | 0 | Enable (1) for SPARQL workloads with frequent reverse lookups |
| `neptune_lookup_cache` | 0 | Enable (1) on r5.8xlarge or larger for faster property lookups |
| `neptune_result_cache` | 0 | Enable (1) to cache query results (useful for repeated identical queries) |
| `neptune_lab_mode` | (various) | Enable experimental features (e.g., DFE engine for Gremlin) |

### DFE (Data Flow Engine)

The DFE is Neptune's alternative query execution engine (available for Gremlin and SPARQL):

- Designed for complex traversals involving joins and aggregations
- Enable via `neptune_lab_mode` parameter: `DFEQueryEngine=viaQueryHint`
- Use query hints to opt in per query:
  ```groovy
  // Gremlin DFE hint
  g.with('Neptune#useDFE', true).V().has('Person', 'name', 'Alice').out('KNOWS').count()
  ```
- DFE often outperforms the default engine for multi-hop traversals and graph-wide aggregations
- Not all Gremlin steps are supported by DFE -- unsupported steps fall back to the default engine

### Neptune Result Cache

When enabled, Neptune caches the results of read queries:

- Cache is invalidated automatically when underlying data changes
- Useful for dashboards or applications that repeatedly execute the same query
- Enable via parameter group: `neptune_result_cache = 1`
- Force a specific query to use cache: add `queryId` hint
- Force a specific query to bypass cache: use `Neptune#noCache` hint

### Monitoring Strategy

**Critical CloudWatch metrics:**

| Metric | Alert Threshold | Meaning |
|---|---|---|
| `BufferCacheHitRatio` | < 99.5% | Graph data exceeding buffer cache -- consider larger instance |
| `CPUUtilization` | > 80% sustained | Query load exceeding compute capacity |
| `FreeableMemory` | < 10% of instance memory | Memory pressure -- OOM risk |
| `VolumeBytesUsed` | Trend monitoring | Storage growth tracking |
| `GremlinRequestsPerSec` | Baseline comparison | Query throughput |
| `SparqlRequestsPerSec` | Baseline comparison | SPARQL query throughput |
| `OpenCypherRequestsPerSec` | Baseline comparison | openCypher query throughput |
| `GremlinErrors` / `SparqlErrors` / `OpenCypherErrors` | > 0 | Query failures |
| `MainRequestQueuePendingRequests` | > 100 sustained | Query queueing -- overloaded instance |
| `LoaderRequestsPerSec` | During loads only | Bulk load throughput |
| `NumTxCommitted` | Baseline comparison | Write transaction rate |
| `NumTxRolledBack` | > 0 sustained | Transaction conflicts or failures |
| `EngineUptime` | Drop to 0 | Instance restart or failover occurred |
| `ClusterReplicaLag` | > 200 ms | Replica falling behind writer |

**CloudWatch dashboard setup:**
Create a dashboard with panels for: CPU, Memory, BufferCacheHitRatio, Requests/sec (all three languages), Errors, ReplicaLag, and Storage.

### Security Best Practices

1. **Always enable IAM authentication.** IAM provides fine-grained access control and audit trails.
2. **Use VPC security groups** to restrict access to Neptune port 8182 to only authorized sources.
3. **Enable encryption at rest** at cluster creation time (cannot be enabled later).
4. **Enable audit logging** for compliance and forensics.
5. **Use IAM condition keys** to restrict query language access:
   ```json
   {
     "Effect": "Allow",
     "Action": "neptune-db:ReadDataViaQuery",
     "Resource": "arn:aws:neptune-db:us-east-1:123456789012:cluster-id/*",
     "Condition": {
       "StringEquals": {
         "neptune-db:QueryLanguage": "Gremlin"
       }
     }
   }
   ```
6. **Rotate IAM credentials** regularly. Use IAM roles (not long-lived access keys) for applications.
7. **Use VPC endpoints** for S3 access during bulk loading (avoid sending data over the internet).
8. **Restrict Neptune notebook access** to authorized users via IAM policies.

### Backup and Recovery

**Automated backups:**
- Enabled by default with 1-day retention
- Increase retention to 7-35 days for production
- Backups are incremental and do not impact performance
- Point-in-time restore creates a new cluster from any second in the retention window

**Manual snapshots:**
- Create before major changes (schema changes, bulk loads, engine upgrades)
- Share across accounts for DR or migration
- Copy to other regions for cross-region DR

**Recovery time objectives:**
- Point-in-time restore: ~10-30 minutes depending on graph size
- Snapshot restore: ~10-30 minutes
- Failover to replica: 30-120 seconds
- Global Database failover: < 1 minute

### Cost Optimization

1. **Use Graviton instances (r6g, x2g):** 20% better price-performance than Intel equivalents
2. **Use Neptune Serverless** for variable workloads to avoid paying for idle capacity
3. **Reserved instances:** 1-year or 3-year commitments for 30-60% savings on steady-state workloads
4. **Right-size instances:** Use CloudWatch metrics (CPU, memory, buffer cache hit ratio) to identify over-provisioned instances
5. **Use read replicas efficiently:** Remove underutilized replicas; add during peak hours
6. **Gzip bulk load files:** Reduces S3 storage costs and transfer time
7. **Clean up manual snapshots:** Old snapshots incur storage charges
8. **Disable streams if not needed:** Streams consume additional I/O
9. **Neptune Analytics:** Only keep analytical graphs active when needed; delete idle graphs

## Troubleshooting Playbooks

### Slow Gremlin Traversals

**Symptoms:** High latency on Gremlin queries, increasing GremlinRequestLatency metric.

**Diagnosis steps:**
1. Run `profile()` on the slow query to see per-step execution times
2. Check `BufferCacheHitRatio` -- if < 99%, cache misses are causing I/O
3. Check `CPUUtilization` -- if > 80%, compute-bound
4. Check `MainRequestQueuePendingRequests` -- if high, queries are queueing
5. Look for supernodes: `g.V().outE().count().is(gt(100000))` -- vertices with > 100K edges

**Resolution:**
- Add `limit()` steps to bound traversal fan-out
- Use `explain()` to verify the query plan uses index lookups
- Enable the DFE engine for complex multi-hop traversals
- Increase instance size if buffer cache is too small
- Add read replicas to distribute query load
- Restructure data to eliminate supernodes (time-bucketing, edge partitioning)

### Out-of-Memory (OOM) Errors

**Symptoms:** Instance restarts, "QueryLimitExceededException", OOM entries in error logs.

**Diagnosis steps:**
1. Check `FreeableMemory` metric -- watch for steady decline to near zero
2. Check `MainRequestQueuePendingRequests` -- too many concurrent complex queries
3. Identify queries returning large result sets (no LIMIT)
4. Check for runaway traversals (unbounded `repeat()` or `*` paths)

**Resolution:**
- Add `limit()` to all read queries
- Set `neptune_query_timeout` to a reasonable value (prevent runaway queries)
- Reduce concurrent query count with application-level throttling
- Upgrade to a larger instance
- For Gremlin: avoid `fold()` on large intermediate results
- For SPARQL: avoid unbounded `SELECT *` without LIMIT
- For openCypher: bound variable-length paths (`*1..5` instead of `*`)

### Bulk Load Failures

**Symptoms:** Loader returns errors, partial data loaded.

**Diagnosis steps:**
1. Check loader status: `GET /loader/{loadId}`
2. Get error details: `GET /loader/{loadId}?details=true&errors=true&page=1&errorsPerPage=10`
3. Common error: "IAM role cannot access S3" -- verify role is attached to cluster
4. Common error: "Source not found" -- verify S3 path and region match
5. Common error: "Invalid vertex ID" -- edge references a non-existent vertex

**Resolution:**
- Ensure IAM role has `s3:GetObject` and `s3:ListBucket` permissions
- Verify S3 bucket is in the same region as Neptune cluster
- Load vertices before edges
- Fix CSV formatting issues (proper escaping, correct column headers)
- Use `failOnError: "FALSE"` to load valid data, then fix and reload errors

### Stream Consumer Lag

**Symptoms:** CDC consumers falling behind, stale data in downstream systems.

**Diagnosis steps:**
1. Check stream endpoint: `GET /propertygraph/stream` or `GET /sparql/stream`
2. Compare `lastEventId` from consumer with `lastTrxTimestamp` on the stream
3. Check consumer Lambda invocation errors in CloudWatch
4. Check `neptune_streams_expiry_days` -- if events expire before consumption, data is lost

**Resolution:**
- Increase consumer concurrency (Lambda concurrency, more polling workers)
- Optimize consumer processing time (batch writes to downstream)
- Increase `neptune_streams_expiry_days` to allow more catch-up time
- Use checkpointing: store `lastEventId` and resume from there
- If severely behind, consider a full re-sync from Neptune to the downstream system

### High Replica Lag

**Symptoms:** `ClusterReplicaLag` metric > 200 ms, stale reads on replicas.

**Diagnosis steps:**
1. Check writer `CPUUtilization` -- overloaded writer delays log shipping
2. Check replica `CPUUtilization` -- overloaded replica delays log application
3. Check replica instance size -- undersized replicas apply logs slower

**Resolution:**
- Reduce write volume if possible (batch writes, reduce update frequency)
- Upgrade writer instance to reduce log generation latency
- Upgrade replica instances to apply logs faster
- Add more replicas to distribute read load (reducing per-replica query CPU)
- For applications requiring strong consistency, read from the writer endpoint

### Connection Issues

**Symptoms:** "Connection refused", "Connection timed out", authentication errors.

**Diagnosis steps:**
1. Verify security group allows inbound TCP 8182 from the client
2. Verify the client is in the same VPC (or peered VPC) as Neptune
3. Verify IAM authentication is correctly configured (SigV4 signing)
4. Check the cluster status endpoint: `curl https://<endpoint>:8182/status`
5. Check `EngineUptime` metric for recent restarts

**Resolution:**
- Update security group rules to allow port 8182 from the client's security group/CIDR
- For Lambda: ensure the function is in the Neptune VPC with a proper subnet and security group
- For IAM auth: verify the signing URL matches the cluster endpoint, and the request uses the correct region
- Check for expired temporary credentials (STS tokens)

## Neptune Analytics Best Practices

### When to Use Neptune Analytics

- Running graph algorithms (PageRank, community detection, centrality) on the full graph
- Vector similarity search combined with graph structure
- Ad-hoc analytical queries that would be too expensive on the transactional database
- One-time or periodic analytical workloads (load data, run analysis, delete graph)

### Graph Sizing

- Provision graph memory >= 2x the raw data size (for in-memory graph representation and algorithm working memory)
- Start with the recommended size from the `neptune-graph estimate` CLI command
- Monitor memory utilization after loading; resize if needed

### Loading Data into Neptune Analytics

**From S3:**
```bash
aws neptune-graph start-import-task \
  --graph-identifier my-analytics-graph \
  --source "s3://my-bucket/graph-data/" \
  --format CSV \
  --role-arn arn:aws:iam::123456789012:role/NeptuneAnalyticsRole
```

**From Neptune Database snapshot:**
```bash
aws neptune-graph create-graph-using-import-task \
  --graph-name my-analytics-graph \
  --source "arn:aws:neptune:us-east-1:123456789012:cluster-snapshot:my-snapshot" \
  --role-arn arn:aws:iam::123456789012:role/NeptuneAnalyticsRole \
  --provisioned-memory 128 \
  --public-connectivity false
```

### Algorithm Execution Tips

- Run algorithms on the entire graph first, then filter results (algorithms need the full graph structure)
- Use `samplingSize` for approximation on very large graphs (e.g., betweenness centrality sampling)
- Store algorithm results as node properties for subsequent queries:
  ```cypher
  CALL neptune.algo.pageRank({writeProperty: 'pagerank'})
  YIELD node, score
  RETURN count(node)
  -- Now query by stored PageRank:
  MATCH (n:Person) WHERE n.pagerank > 0.01 RETURN n.name, n.pagerank ORDER BY n.pagerank DESC
  ```
- Chain algorithms: run community detection first, then centrality within each community
