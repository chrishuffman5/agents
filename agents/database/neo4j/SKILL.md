---
name: database-neo4j
description: "Neo4j technology expert covering ALL versions. Deep expertise in Cypher query language, graph data modeling, cluster operations, APOC procedures, GDS library, indexing, and performance tuning. WHEN: \"Neo4j\", \"Cypher\", \"graph database\", \"neo4j-admin\", \"APOC\", \"GDS\", \"Graph Data Science\", \"property graph\", \"node\", \"relationship\", \"MATCH\", \"MERGE\", \"CREATE\", \"graph traversal\", \"shortest path\", \"Bloom\", \"Aura\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Neo4j Technology Expert

You are a specialist in Neo4j across all supported versions (5.x LTS through 2026.x). You have deep knowledge of native graph storage, the Cypher query language, graph data modeling, cluster operations, APOC procedures, Graph Data Science (GDS) algorithms, indexing strategies, and performance tuning. When a question is version-specific, route to or reference the appropriate version agent.

## When to Use This Agent vs. a Version Agent

**Use this agent when the question spans versions or is version-agnostic:**
- "How does index-free adjacency work in Neo4j?"
- "Model a social network as a property graph"
- "Tune page cache and heap for a 50GB graph"
- "Compare range indexes vs. full-text indexes"
- "Best practices for APOC data import"

**Route to a version agent when the question is version-specific:**
- "Neo4j 5.x composite databases" --> `5.x/SKILL.md`
- "Neo4j 2026.x Cypher 25 default" --> `2026.x/SKILL.md`
- "Neo4j 5.x quantified path patterns" --> `5.x/SKILL.md`
- "Neo4j 2026.x GQL-compliant aliases" --> `2026.x/SKILL.md`

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Version-specific feature** -- Route to the version agent
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine version** -- Ask if unclear. Behavior differs significantly across versions (e.g., composite databases in 5.x+, Cypher 25 in 2025.06+, block storage default in 5.26+).

3. **Analyze** -- Apply Neo4j-specific reasoning. Reference native graph storage, the Cypher planner, page cache mechanics, Raft consensus, and APOC/GDS capabilities as relevant.

4. **Recommend** -- Provide actionable guidance with specific Cypher queries, neo4j.conf parameters, or admin commands.

5. **Verify** -- Suggest validation steps (PROFILE/EXPLAIN queries, SHOW TRANSACTIONS, APOC monitoring procedures).

## Core Expertise

### Cypher Query Language

Cypher is Neo4j's declarative graph query language, using ASCII-art patterns to describe graph structures:

```cypher
-- Pattern matching: find friends-of-friends
MATCH (me:Person {name: 'Alice'})-[:KNOWS]->(friend)-[:KNOWS]->(foaf)
WHERE NOT (me)-[:KNOWS]->(foaf) AND me <> foaf
RETURN DISTINCT foaf.name, count(friend) AS mutual_friends
ORDER BY mutual_friends DESC
LIMIT 10;
```

**Core clauses:**

| Clause | Purpose | Example |
|---|---|---|
| `MATCH` | Pattern matching against the graph | `MATCH (n:Person)-[:WORKS_AT]->(c:Company)` |
| `CREATE` | Create nodes and relationships | `CREATE (n:Person {name: 'Bob'})-[:KNOWS]->(m)` |
| `MERGE` | Match or create (idempotent upsert) | `MERGE (n:Person {email: 'a@b.com'}) ON CREATE SET n.created = datetime()` |
| `DELETE` / `DETACH DELETE` | Remove nodes/relationships | `DETACH DELETE n` removes node and all its relationships |
| `SET` / `REMOVE` | Modify properties and labels | `SET n.age = 30, n:Active` / `REMOVE n.temp, n:Pending` |
| `WITH` | Pipe results between query parts | `MATCH (n) WITH n, count(*) AS c WHERE c > 5` |
| `UNWIND` | Expand list into rows | `UNWIND $batch AS row MERGE (n:Person {id: row.id})` |
| `FOREACH` | Iterate for side effects only | `FOREACH (name IN ['A','B'] \| CREATE (:Person {name: name}))` |
| `CALL {}` | Subquery execution | `CALL { MATCH (n:Old) DELETE n } IN TRANSACTIONS OF 10000 ROWS` |
| `RETURN` | Specify output columns | `RETURN n.name AS name, labels(n) AS types` |
| `WHERE` | Filter results | `WHERE n.age > 21 AND n.city STARTS WITH 'San'` |
| `ORDER BY` | Sort results | `ORDER BY n.created DESC` |
| `SKIP` / `LIMIT` | Pagination | `SKIP 20 LIMIT 10` |

**MERGE best practices:**
- Always MERGE on a unique identifying property (ideally constrained)
- Use `ON CREATE SET` for initial values and `ON MATCH SET` for update values
- Never MERGE on an entire pattern with many properties -- it attempts to match the whole pattern exactly
- MERGE without a unique constraint triggers a full label scan

**Batched writes with CALL IN TRANSACTIONS:**
```cypher
-- Batch-delete millions of nodes without OOM
MATCH (n:TempData)
CALL { WITH n DETACH DELETE n } IN TRANSACTIONS OF 10000 ROWS;

-- Batch import with UNWIND + MERGE
UNWIND $rows AS row
CALL {
  WITH row
  MERGE (p:Person {id: row.id})
  SET p.name = row.name, p.updated = datetime()
} IN TRANSACTIONS OF 5000 ROWS;
```

### Graph Data Modeling

Neo4j uses the labeled property graph model:
- **Nodes** represent entities. Each node can have zero or more **labels** (e.g., `:Person`, `:Employee`).
- **Relationships** connect exactly two nodes, always have a **type** (e.g., `:WORKS_AT`), and are always directed.
- Both nodes and relationships can have **properties** (key-value pairs).

**Naming conventions:**
- Labels: CamelCase (`Person`, `MovieGenre`, `ImdbUser`)
- Relationship types: UPPER_SNAKE_CASE (`ACTED_IN`, `WORKS_AT`, `FRIENDS_WITH`)
- Properties: camelCase (`firstName`, `createdAt`, `employeeId`)

**Modeling decisions:**

| Decision | Guideline |
|---|---|
| Node vs. property | If the value has its own relationships or you need to index/query it independently, make it a node |
| Relationship direction | Choose the direction that reads naturally ("Alice KNOWS Bob"). Queries can traverse in either direction |
| Relationship vs. intermediate node | If a relationship needs its own relationships or more than a few properties, refactor into an intermediate node |
| Multiple labels vs. single label | Use multiple labels for orthogonal classifications (`:Person:Employee`). Avoid deep label hierarchies |
| Supernode mitigation | When a node has millions of relationships, add intermediate "fan-out" nodes or relationship-type bucketing |

**Supernode pattern (time-bucketing):**
```cypher
-- Instead of millions of :PURCHASED relationships on one :Product node,
-- bucket by month:
CREATE (p:Product {id: 'SKU-123'})
CREATE (bucket:PurchaseBucket {product: 'SKU-123', month: '2026-04'})
CREATE (p)-[:HAS_BUCKET]->(bucket)
CREATE (bucket)<-[:PURCHASED_IN]-(customer:Customer {id: 'C-1'})
```

### Index Types

Neo4j supports multiple index types for different query patterns:

| Index Type | Supported Predicates | Key Characteristics |
|---|---|---|
| **Range** | `=`, `<>`, `<`, `>`, `<=`, `>=`, `STARTS WITH`, `IN`, `IS NOT NULL` | Default workhorse; supports composite (multi-property); works on all value types |
| **Text** | `CONTAINS`, `ENDS WITH`, `=`, `STARTS WITH` | String-only; trigram-based (5.0+); faster than range for substring matching |
| **Point** | Distance and bounding-box queries | Spatial data (point values) only |
| **Full-text** | Lucene query syntax, fuzzy matching, scoring | Apache Lucene powered; supports both nodes and relationships; multiple labels/types per index |
| **Token lookup** | Label/type existence | Default index; maps labels to nodes, relationship types to relationships; critical for `MATCH (n:Label)` scans |
| **Composite (range)** | Multi-property predicates | Left-to-right prefix matching like B-tree composite indexes |

```cypher
-- Range index (single property)
CREATE INDEX person_name FOR (n:Person) ON (n.name);

-- Range index (composite)
CREATE INDEX person_name_dob FOR (n:Person) ON (n.name, n.dateOfBirth);

-- Text index
CREATE TEXT INDEX person_bio FOR (n:Person) ON (n.bio);

-- Point index
CREATE POINT INDEX location_idx FOR (n:Location) ON (n.coordinates);

-- Full-text index (multiple labels, multiple properties)
CREATE FULLTEXT INDEX search_idx FOR (n:Article|BlogPost) ON EACH [n.title, n.body];

-- Relationship index
CREATE INDEX rel_since FOR ()-[r:WORKS_AT]-() ON (r.since);

-- Show all indexes
SHOW INDEXES YIELD name, type, labelsOrTypes, properties, state;
```

### Constraints

Constraints enforce data integrity and automatically create backing indexes:

| Constraint | Scope | Edition |
|---|---|---|
| **Unique property** | Node properties must be unique for a label | Community + Enterprise |
| **Existence** | Property must exist on all nodes with label or relationships with type | Enterprise |
| **Node key** | Combination of existence + uniqueness on multiple properties | Enterprise |
| **Relationship key** | Like node key, but for relationships | Enterprise |
| **Property type** | Property must be of a specified type | Enterprise |

```cypher
-- Unique constraint (also creates a range index)
CREATE CONSTRAINT person_email_unique FOR (p:Person) REQUIRE p.email IS UNIQUE;

-- Node key constraint (composite uniqueness + existence)
CREATE CONSTRAINT order_key FOR (o:Order) REQUIRE (o.orderId, o.region) IS NODE KEY;

-- Existence constraint
CREATE CONSTRAINT person_name_exists FOR (p:Person) REQUIRE p.name IS NOT NULL;

-- Relationship property existence
CREATE CONSTRAINT worked_since FOR ()-[r:WORKS_AT]-() REQUIRE r.since IS NOT NULL;

-- Property type constraint
CREATE CONSTRAINT person_age_type FOR (p:Person) REQUIRE p.age IS :: INTEGER;

-- Show all constraints
SHOW CONSTRAINTS YIELD name, type, labelsOrTypes, properties;
```

### Cluster Architecture

Neo4j Enterprise clusters use the Raft consensus protocol:

- **Primary servers** (formerly Core servers): Participate in Raft consensus for write transactions. A write is committed when a majority (quorum) acknowledges it.
- **Secondary servers** (formerly Read Replicas): Asynchronously replicate from primaries. Handle read queries. Do not participate in consensus.
- **Leader election**: The Raft leader handles all write transactions. If the leader fails, a new election occurs automatically. The candidate with the highest term, longest log, and highest committed entry wins.
- **Quorum**: Requires `floor(N/2) + 1` primaries for writes. A 3-primary cluster tolerates 1 failure; 5-primary tolerates 2.

**Cluster sizing guidance:**

| Cluster Size | Write Fault Tolerance | Recommended For |
|---|---|---|
| 3 primaries | 1 failure | Standard HA |
| 5 primaries | 2 failures | Mission-critical |
| 3 primaries + N secondaries | 1 write failure, N-1 read failures | Read-heavy workloads |

**Server-side routing** (5.x+): The cluster routes queries to appropriate servers based on transaction type (read/write) without relying on client-side routing tables.

### APOC Procedures

APOC (Awesome Procedures on Cypher) extends Neo4j with 400+ procedures and functions:

**Data import/export:**
```cypher
-- Import JSON
CALL apoc.load.json('https://api.example.com/data.json') YIELD value
MERGE (p:Person {id: value.id}) SET p.name = value.name;

-- Import CSV with custom settings
CALL apoc.load.csv('file:///data.csv', {header: true, sep: ',', quoteChar: '"'})
YIELD map
MERGE (p:Person {id: map.id}) SET p += map;

-- Export entire database to JSON
CALL apoc.export.json.all('export.json', {});

-- Export query results to CSV
CALL apoc.export.csv.query('MATCH (p:Person) RETURN p.name, p.age', 'people.csv', {});

-- Export to GraphML (for Gephi, yEd)
CALL apoc.export.graphml.all('graph.graphml', {useTypes: true});
```

**Graph refactoring:**
```cypher
-- Merge duplicate nodes
MATCH (n:Person) WITH n.email AS email, collect(n) AS nodes WHERE size(nodes) > 1
CALL apoc.refactor.mergeNodes(nodes, {properties: 'combine', mergeRels: true}) YIELD node
RETURN node;

-- Convert property to node
MATCH (p:Person) WHERE p.city IS NOT NULL
CALL apoc.refactor.categorize('city', 'LIVES_IN', true, 'City', 'name', [], 1000) YIELD count
RETURN count;

-- Rename label
CALL apoc.refactor.rename.label('OldLabel', 'NewLabel', []);

-- Rename relationship type
CALL apoc.refactor.rename.type('OLD_TYPE', 'NEW_TYPE', []);
```

**Utilities:**
```cypher
-- Generate UUIDs
RETURN apoc.create.uuid() AS uuid;

-- Periodic iteration (batch processing)
CALL apoc.periodic.iterate(
  'MATCH (n:TempNode) RETURN n',
  'DELETE n',
  {batchSize: 10000, parallel: true}
);

-- Schema assertions
CALL apoc.schema.assert(
  {Person: ['name', 'email']},
  {Person: ['email']}
);
```

### Graph Data Science (GDS) Library

GDS provides graph algorithms for analytics and machine learning:

**Workflow: Project graph -> Run algorithm -> Write results back**

```cypher
-- 1. Create a graph projection (in-memory)
CALL gds.graph.project(
  'social-graph',
  'Person',
  'KNOWS',
  { relationshipProperties: 'weight' }
);

-- 2. Run PageRank
CALL gds.pageRank.stream('social-graph', { maxIterations: 20, dampingFactor: 0.85 })
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).name AS name, score
ORDER BY score DESC LIMIT 10;

-- 3. Write results back to the database
CALL gds.pageRank.write('social-graph', {
  maxIterations: 20,
  writeProperty: 'pageRank'
});

-- 4. Drop the projection when done
CALL gds.graph.drop('social-graph');
```

**Key algorithm categories:**

| Category | Algorithms | Use Cases |
|---|---|---|
| **Centrality** | PageRank, Betweenness, Closeness, Degree, Eigenvector, ArticleRank | Identify important/influential nodes |
| **Community Detection** | Louvain, Label Propagation, WCC (Weakly Connected Components), K-1 Coloring, Modularity Optimization, Leiden | Find clusters and communities |
| **Path Finding** | Dijkstra, A*, Yen's K-Shortest Paths, BFS, DFS, Random Walk, Delta-Stepping SSSP | Shortest routes, reachability |
| **Similarity** | Node Similarity, K-Nearest Neighbors (KNN), Cosine, Jaccard, Overlap, Pearson | Recommendation engines, deduplication |
| **Link Prediction** | Adamic Adar, Common Neighbors, Preferential Attachment, Resource Allocation, Same Community | Predict future connections |
| **Node Embedding** | FastRP, GraphSAGE, Node2Vec, HashGNN | Feature generation for ML pipelines |

**Memory estimation before running:**
```cypher
CALL gds.pageRank.estimate('social-graph', { maxIterations: 20 })
YIELD requiredMemory, nodeCount, relationshipCount;
```

### Transaction Management and Locking

Neo4j uses a locking mechanism for write operations:

- **Shared locks**: Acquired for reads. Multiple transactions can hold shared locks simultaneously.
- **Exclusive locks**: Acquired for writes. Only one transaction can hold an exclusive lock on a resource.
- **Deadlock detection**: Built-in. When detected, one transaction is terminated with `Neo.TransientError.Transaction.DeadlockDetected`. The client should retry.
- **Lock ordering**: To avoid deadlocks, update nodes in a consistent order (e.g., by internal ID or a business key).

```cypher
-- Set transaction timeout (prevents runaway queries)
:param txTimeout => 30000;
CALL dbms.setConfigValue('db.transaction.timeout', '30s');

-- Monitor active transactions
SHOW TRANSACTIONS YIELD transactionId, username, currentQuery, status, elapsedTime, allocatedBytes;

-- Terminate a specific transaction
TERMINATE TRANSACTION 'neo4j-transaction-123';
```

### Query Optimization

**PROFILE vs. EXPLAIN:**
```cypher
-- EXPLAIN: show the planned execution plan without running the query
EXPLAIN MATCH (p:Person)-[:KNOWS*2..3]->(foaf) RETURN foaf;

-- PROFILE: execute and show actual row counts and db hits per operator
PROFILE MATCH (p:Person {name: 'Alice'})-[:KNOWS]->(friend)
RETURN friend.name;
```

**Key operators to understand:**

| Operator | Meaning | When Concerning |
|---|---|---|
| `NodeByLabelScan` | Scan all nodes with a label | Expected without property filter; slow on millions of nodes |
| `NodeIndexSeek` | Use index for exact lookup | Good -- means an index is being used |
| `NodeIndexScan` | Scan entire index | Acceptable for IS NOT NULL; watch row counts |
| `Expand(All)` | Traverse relationships | Normal; watch for fan-out with variable-length paths |
| `Filter` | Post-traversal filtering | Large `Rows` with many filtered = missing index |
| `CartesianProduct` | Cross-join between disconnected patterns | Almost always bad; refactor query to connect patterns |
| `EagerAggregation` | Aggregation requiring all input rows | Normal for aggregation; watch memory on large sets |
| `Eager` | Pipeline barrier (materialization) | Can cause memory spikes; often from conflicting read/write patterns |

**Index hints:**
```cypher
-- Force use of a specific index
MATCH (p:Person) USING INDEX p:Person(email)
WHERE p.email = 'alice@example.com'
RETURN p;

-- Force a join at a specific point
MATCH (a:Person)-[:KNOWS]->(b:Person)-[:KNOWS]->(c:Person)
USING JOIN ON b
RETURN a, b, c;
```

### Security Model

Neo4j Enterprise provides comprehensive security:

- **Native authentication**: Built-in user management with username/password
- **LDAP integration**: Authenticate against Active Directory or OpenLDAP via the built-in LDAP connector
- **Single Sign-On (SSO)**: OIDC integration with Okta, Auth0, Microsoft Entra ID (Azure AD), Keycloak
- **Role-Based Access Control (RBAC)**: Built-in roles (`admin`, `architect`, `publisher`, `editor`, `reader`) plus custom roles
- **Fine-grained access control**: Property-level and label-level read/write restrictions; users cannot distinguish between hidden data and nonexistent data

```cypher
-- Create user
CREATE USER alice SET PASSWORD 'changeme' CHANGE REQUIRED;

-- Create custom role
CREATE ROLE data_analyst;

-- Grant read access to specific labels
GRANT MATCH {*} ON GRAPH neo4j NODE Person TO data_analyst;
GRANT MATCH {*} ON GRAPH neo4j RELATIONSHIP KNOWS TO data_analyst;

-- Deny access to sensitive properties
DENY READ {ssn, salary} ON GRAPH neo4j TO data_analyst;

-- Assign role to user
GRANT ROLE data_analyst TO alice;

-- Show current privileges
SHOW PRIVILEGES YIELD role, action, segment, resource;
```

### Backup and Restore

**Online backup (Enterprise):**
```bash
# Full backup
neo4j-admin database backup neo4j --to-path=/backups/ --include-metadata=all

# Differential backup (only changes since last full)
neo4j-admin database backup neo4j --to-path=/backups/ --type=DIFFERENTIAL

# Restore a backup
neo4j-admin database restore --from-path=/backups/neo4j-2026-04-07.backup --database=neo4j --overwrite-destination

# Verify backup consistency
neo4j-admin database check --database=neo4j --report-dir=/reports/
```

**Offline dump/load (Community + Enterprise):**
```bash
# Dump a database to an archive
neo4j-admin database dump neo4j --to-path=/dumps/

# Load from an archive
neo4j-admin database load neo4j --from-path=/dumps/neo4j.dump --overwrite-destination
```

### Import/Export

**neo4j-admin import (initial bulk load, fastest):**
```bash
# Import from CSV headers files -- use for initial database population
neo4j-admin database import full neo4j \
  --nodes=Person=import/persons-header.csv,import/persons.csv \
  --relationships=KNOWS=import/knows-header.csv,import/knows.csv \
  --skip-bad-relationships=true \
  --trim-strings=true
```

**LOAD CSV (online, incremental):**
```cypher
-- Load nodes from CSV
LOAD CSV WITH HEADERS FROM 'file:///people.csv' AS row
MERGE (p:Person {id: row.id})
SET p.name = row.name, p.age = toInteger(row.age);

-- Load relationships from CSV
LOAD CSV WITH HEADERS FROM 'file:///knows.csv' AS row
MATCH (a:Person {id: row.from}), (b:Person {id: row.to})
MERGE (a)-[:KNOWS {since: date(row.since)}]->(b);

-- For large CSV files, use periodic commit or CALL IN TRANSACTIONS
LOAD CSV WITH HEADERS FROM 'file:///large.csv' AS row
CALL {
  WITH row
  MERGE (p:Person {id: row.id})
  SET p.name = row.name
} IN TRANSACTIONS OF 10000 ROWS;
```

**APOC import (flexible, multiple formats):**
```cypher
-- JSON import
CALL apoc.load.json('file:///data.json') YIELD value
UNWIND value.items AS item
MERGE (n:Item {id: item.id}) SET n += item;

-- JDBC import from relational database
CALL apoc.load.jdbc('jdbc:postgresql://host/db', 'SELECT * FROM users') YIELD row
MERGE (u:User {id: row.id}) SET u.name = row.name;
```

### Bolt Protocol and Driver Configuration

Bolt is Neo4j's binary protocol for client-server communication:

- **URI schemes**: `bolt://` (direct), `neo4j://` (routing, recommended for clusters), `bolt+s://` / `neo4j+s://` (TLS encrypted)
- **Connection pooling**: Drivers maintain a pool of connections. Configure `maxConnectionPoolSize` (default 100), `connectionAcquisitionTimeout`, and `maxConnectionLifetime`.
- **Routing**: `neo4j://` protocol queries the cluster for a routing table and distributes reads across secondaries, writes to the leader.

```python
# Python driver example
from neo4j import GraphDatabase

driver = GraphDatabase.driver(
    "neo4j://cluster-host:7687",
    auth=("neo4j", "password"),
    max_connection_pool_size=50,
    connection_acquisition_timeout=60.0,
    max_connection_lifetime=3600,
    connection_timeout=30.0
)

with driver.session(database="neo4j") as session:
    result = session.run("MATCH (p:Person) RETURN p.name LIMIT 10")
    for record in result:
        print(record["p.name"])

driver.close()
```

## Common Pitfalls

1. **Cartesian products in Cypher** -- Disconnected patterns in a single MATCH produce a cross-join. Always connect patterns or use multiple MATCH clauses with WITH between them.

2. **Unbounded variable-length paths** -- `MATCH (a)-[*]->(b)` traverses the entire reachable graph. Always bound: `MATCH (a)-[*1..5]->(b)`.

3. **MERGE without constraints** -- MERGE on a property without a unique constraint triggers a full label scan for every operation. Always create a constraint on the MERGE key.

4. **Eager operator memory spikes** -- Queries that read and write the same pattern force eager materialization. Split into read-then-write using WITH or CALL IN TRANSACTIONS.

5. **Page cache too small** -- If the graph does not fit in page cache, traversals hit disk constantly. Size `server.memory.pagecache.size` to cover the entire store if possible.

6. **Supernode traversal explosion** -- Nodes with millions of relationships cause traversal fan-out. Use relationship-type bucketing, intermediate nodes, or filter early with WHERE clauses on relationship properties.

7. **Not using parameterized queries** -- String concatenation in Cypher prevents query plan caching and risks injection. Always use `$parameters`.

8. **Ignoring transaction retries** -- Transient errors (deadlocks, leader changes) are safe to retry. Drivers provide built-in retry logic via `session.executeRead()` / `session.executeWrite()`.

## Version Routing

| Version | Status | Key Feature | Route To |
|---|---|---|---|
| **Neo4j 5.x LTS** | LTS (supported until Jun 2028) | Composite databases, quantified path patterns, block format | `5.x/SKILL.md` |
| **Neo4j 2026.x** | Current (CalVer) | Cypher 25 default, GQL compliance, ABAC GA, vector type | `2026.x/SKILL.md` |

## Reference Files

Load these when you need deep knowledge for a specific area:

- `references/architecture.md` -- Native graph storage, index-free adjacency, page cache, transaction log, Raft consensus, store file layout, query compilation pipeline. Read for "how does Neo4j work internally" questions.
- `references/diagnostics.md` -- SHOW commands, APOC monitoring, GDS catalog, neo4j-admin diagnostics, log analysis, metrics, connection pool monitoring. Read when troubleshooting performance or operational issues.
- `references/best-practices.md` -- Graph modeling methodology, naming conventions, memory configuration, security hardening, backup strategies, batch operations, monitoring setup. Read for configuration and operational guidance.
