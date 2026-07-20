# Neo4j Best Practices Reference

## Graph Modeling Methodology

### Step 1: Identify Entities (Nodes)

Start with your use cases and identify the nouns:
- **Things**: Person, Company, Product, Location, Event
- **Concepts**: Category, Tag, Status, Role

**Decision: Node vs. Property:**
| Criterion | Use a Node | Use a Property |
|---|---|---|
| Has its own relationships? | Node | Property |
| Needs independent indexing? | Node | Property |
| Shared across multiple entities? | Node (and relate to it) | Property (duplicated) |
| Has sub-structure? | Node | Property (flatten or use map/list) |
| Will be traversed to? | Node | N/A |
| Simple scalar value? | Property | Property |

### Step 2: Identify Connections (Relationships)

Identify the verbs from your use cases:
- "Alice KNOWS Bob" -> `(:Person)-[:KNOWS]->(:Person)`
- "Alice WORKS_AT Acme" -> `(:Person)-[:WORKS_AT]->(:Company)`
- "Alice PURCHASED Widget on 2026-01-15" -> `(:Person)-[:PURCHASED {date: date('2026-01-15')}]->(:Product)`

**Decision: Relationship type vs. Property on relationship:**

| Criterion | Use Distinct Relationship Types | Use a Property |
|---|---|---|
| Needs fast filtered traversal? | Type (e.g., `LIKED` vs `DISLIKED`) | Property (requires post-filter) |
| Limited set of values? | Type | Property |
| High cardinality values? | Property (avoid thousands of types) | Property |
| Influences query pattern? | Type | Property |

### Step 3: Choose Relationship Direction

Relationships in Neo4j are always stored with a direction. Choose the direction that reads naturally:

```
(:Person)-[:WORKS_AT]->(:Company)       -- Person works at company
(:Person)-[:LIVES_IN]->(:City)          -- Person lives in city
(:Person)-[:KNOWS]->(:Person)           -- Alice knows Bob
(:Order)-[:CONTAINS]->(:Product)        -- Order contains product
(:Employee)-[:REPORTS_TO]->(:Employee)  -- Employee reports to manager
```

**Key principle:** Direction is a storage detail. Cypher queries can traverse in either direction regardless of how the relationship is stored:
```cypher
-- Both work, regardless of stored direction:
MATCH (a:Person)-[:KNOWS]->(b:Person) ...     -- follow stored direction
MATCH (a:Person)<-[:KNOWS]-(b:Person) ...     -- reverse direction
MATCH (a:Person)-[:KNOWS]-(b:Person) ...      -- ignore direction
```

Choose one natural direction and be consistent. Do NOT create duplicate relationships in both directions -- this wastes storage and complicates writes.

### Step 4: Add Properties

Add properties to nodes and relationships as key-value pairs:

```cypher
CREATE (p:Person {
  name: 'Alice Smith',
  email: 'alice@example.com',
  dateOfBirth: date('1990-05-15'),
  active: true
})-[:WORKS_AT {
  since: date('2020-01-10'),
  role: 'Engineer',
  department: 'Platform'
}]->(c:Company {name: 'Acme Corp'})
```

**Property type choices:**
| Neo4j Type | Use For | Example |
|---|---|---|
| `STRING` | Text, identifiers | `name: 'Alice'` |
| `INTEGER` | Whole numbers, IDs | `age: 35, employeeId: 12345` |
| `FLOAT` | Decimal numbers | `rating: 4.7` |
| `BOOLEAN` | Flags | `active: true` |
| `DATE` | Calendar dates | `dateOfBirth: date('1990-05-15')` |
| `DATETIME` | Timestamps | `createdAt: datetime()` |
| `DURATION` | Time intervals | `tenure: duration('P2Y3M')` |
| `POINT` | Geospatial coordinates | `location: point({latitude: 37.7749, longitude: -122.4194})` |
| `LIST` | Arrays | `tags: ['graph', 'database']` |

### Step 5: Refactor for Performance

After initial modeling, refactor for query performance:

**Pattern: Intermediate nodes for rich relationships:**
```cypher
-- Before: relationship with many properties
(:Person)-[:REVIEWED {rating: 5, text: '...', date: date(), helpful: 42}]->(:Product)

-- After: intermediate node (enables indexing, additional relationships)
(:Person)-[:WROTE]->(:Review {rating: 5, text: '...', date: date(), helpful: 42})-[:REVIEWS]->(:Product)
```

**Pattern: Time-tree for temporal queries:**
```cypher
-- Create a time tree for efficient date-range queries
CREATE (y:Year {value: 2026})-[:HAS_MONTH]->(m:Month {value: 4})-[:HAS_DAY]->(d:Day {value: 7})
CREATE (event:Event)-[:OCCURRED_ON]->(d)
```

**Pattern: Supernode mitigation with fan-out nodes:**
```cypher
-- Problem: celebrity node with 10M followers
-- Solution: bucket by time period
CREATE (celeb:Person {name: 'Celebrity'})
CREATE (bucket:FollowerBucket {period: '2026-Q1', personId: celeb.id})
CREATE (celeb)-[:HAS_FOLLOWER_BUCKET]->(bucket)
CREATE (fan:Person)-[:FOLLOWS_IN]->(bucket)
```

## Naming Conventions

### Labels
- **CamelCase**: `Person`, `BlogPost`, `MovieGenre`
- Use singular form: `Person` not `Persons`
- Use nouns: `Company` not `Employing`
- Multiple labels for classification: `(:Person:Employee:Manager)`

### Relationship Types
- **UPPER_SNAKE_CASE**: `WORKS_AT`, `ACTED_IN`, `FRIENDS_WITH`
- Use verbs/verb phrases: `PURCHASED`, `REVIEWED`, `REPORTS_TO`
- Be specific: `AUTHORED` not `RELATED_TO`
- Prefer active voice: `MANAGES` not `IS_MANAGED_BY`

### Properties
- **camelCase**: `firstName`, `dateOfBirth`, `employeeId`
- Use consistent naming across labels
- Prefix with context if ambiguous: `startDate` vs `endDate`

### Database and Index Names
- **lowercase-kebab-case**: `social-network`, `product-catalog`
- Index names: descriptive, including label and properties: `person_email_unique`, `company_name_range`

## Relationship Direction Decisions

### Guidelines

1. **Follow natural language**: "Person WORKS_AT Company" (not Company EMPLOYS Person)
2. **Follow data flow**: "Order CONTAINS Product" (order references products)
3. **Follow time**: "Person PURCHASED Product" (person initiated the action)
4. **Be consistent**: If `FOLLOWS` goes from follower to followed, use the same pattern everywhere
5. **Hierarchy**: Child points to parent (`REPORTS_TO`, `BELONGS_TO`, `PART_OF`)

### When Direction Matters for Performance

Direction matters most when nodes have asymmetric degree distribution:
```cypher
-- City has millions of LIVES_IN relationships
-- Direction: (:Person)-[:LIVES_IN]->(:City)
-- Query starting from Person traverses 1 relationship (fast)
-- Query starting from City traverses millions (slow)
MATCH (p:Person {name: 'Alice'})-[:LIVES_IN]->(c:City) RETURN c;  -- fast
MATCH (c:City {name: 'London'})<-[:LIVES_IN]-(p:Person) RETURN p;  -- traverses all residents
```

## Supernode Handling

A **supernode** is a node with an extremely high number of relationships (typically > 100K). Supernodes cause:
- Slow traversal (must scan the entire relationship chain)
- Lock contention (writes to the node or its relationships)
- Memory pressure (loading all relationships into page cache)

### Detection

```cypher
-- Find potential supernodes
MATCH (n)
WITH n, size([(n)-->() | 1]) + size([(n)<--() | 1]) AS totalDegree
WHERE totalDegree > 100000
RETURN labels(n) AS labels, n.name AS name, totalDegree
ORDER BY totalDegree DESC;
```

### Mitigation Strategies

1. **Relationship-type bucketing**: Split generic types into specific types
   ```cypher
   -- Before: (:User)-[:INTERACTED]->(:Content)
   -- After:
   (:User)-[:LIKED]->(:Content)
   (:User)-[:COMMENTED]->(:Content)
   (:User)-[:SHARED]->(:Content)
   ```

2. **Fan-out / bucketing nodes**: Interpose intermediate nodes
   ```cypher
   (:Celebrity)-[:HAS_BUCKET]->(b:FollowerBucket {period: '2026-Q1'})<-[:FOLLOWS_IN]-(:Fan)
   ```

3. **Relationship properties + filtering**: If you must keep the relationships, filter early
   ```cypher
   MATCH (c:City)<-[r:LIVES_IN]-(p:Person)
   WHERE r.since > date('2025-01-01')  -- filter relationships early
   RETURN p;
   ```

4. **APOC path expander with limits**:
   ```cypher
   CALL apoc.path.expandConfig(startNode, {
     maxLevel: 2,
     limit: 100,
     relationshipFilter: 'KNOWS>'
   }) YIELD path RETURN path;
   ```

## Batch Operations for Large Graphs

### Batch Writes with CALL IN TRANSACTIONS

```cypher
-- Batch update millions of nodes
MATCH (p:Person) WHERE p.migrated IS NULL
CALL {
  WITH p
  SET p.migrated = true, p.migratedAt = datetime()
} IN TRANSACTIONS OF 10000 ROWS;
```

### Batch Deletes

```cypher
-- Delete millions of nodes without OOM
MATCH (n:TempData)
CALL { WITH n DETACH DELETE n } IN TRANSACTIONS OF 10000 ROWS;
```

### APOC Periodic Iterate (Alternative)

```cypher
-- Batch processing with APOC (useful for complex operations)
CALL apoc.periodic.iterate(
  'MATCH (p:Person) WHERE p.score IS NULL RETURN p',
  'SET p.score = apoc.coll.avg([(p)-[:RATED]->(m) | m.rating])',
  {batchSize: 10000, parallel: false, iterateList: true}
);
```

### Bulk Import Best Practices

1. **Use `neo4j-admin database import`** for initial loads > 10M nodes:
   ```bash
   neo4j-admin database import full neo4j \
     --nodes=import/nodes.csv \
     --relationships=import/rels.csv \
     --trim-strings=true \
     --max-off-heap-memory=8g
   ```

2. **For online incremental loads, disable indexes temporarily:**
   ```cypher
   -- Drop non-essential indexes before bulk load
   DROP INDEX non_essential_idx;
   -- Load data
   LOAD CSV WITH HEADERS FROM 'file:///data.csv' AS row
   CALL { WITH row MERGE (n:Node {id: row.id}) SET n += row }
   IN TRANSACTIONS OF 10000 ROWS;
   -- Recreate indexes after load
   CREATE INDEX non_essential_idx FOR (n:Node) ON (n.someProperty);
   ```

3. **Use UNWIND for parameterized batch inserts:**
   ```cypher
   UNWIND $batch AS row
   MERGE (p:Person {id: row.id})
   ON CREATE SET p.name = row.name, p.created = datetime()
   ON MATCH SET p.name = row.name, p.updated = datetime();
   ```

## Memory Configuration

### Page Cache Sizing

The page cache holds graph store pages in memory. Ideally it should be large enough to hold the entire store:

```properties
# neo4j.conf
server.memory.pagecache.size=32g
```

**Sizing rules:**
1. **Ideal**: `pagecache >= store_size` (entire graph in memory, zero disk reads for traversals)
2. **Minimum**: `pagecache >= hot_working_set` (frequently accessed subgraph)
3. **Check store size**: `du -sh data/databases/neo4j/` or `CALL apoc.monitor.store()`

**Signs page cache is too small:**
- Page cache hit ratio < 95%
- High disk I/O during traversal queries
- Query latency varies wildly (cache-dependent)

### Heap Sizing

The JVM heap is used for query execution, transaction state, and caching:

```properties
# neo4j.conf -- ALWAYS set initial = max to avoid resize GC pauses
server.memory.heap.initial_size=16g
server.memory.heap.max_size=16g
```

**Sizing rules:**
1. **Minimum**: 2-4GB for small databases
2. **Typical**: 8-16GB for production workloads
3. **Maximum**: 31GB (to stay within JVM compressed oops range; beyond 31GB, pointer size doubles)
4. **Never**: Heap > 50% of total RAM (leaves no room for page cache and OS)

**Signs heap is too small:**
- Frequent GC pauses (> 500ms)
- `OutOfMemoryError` in logs
- Transaction failures with memory errors

**Signs heap is too large:**
- GC pauses are long (seconds) -- the GC has more memory to scan
- Page cache or OS cache is starved

### JVM Tuning

```properties
# neo4j.conf -- JVM additional settings
server.jvm.additional=-XX:+UseG1GC
server.jvm.additional=-XX:MaxGCPauseMillis=200
server.jvm.additional=-XX:+ParallelRefProcEnabled
server.jvm.additional=-XX:-OmitStackTraceInFastThrow

# GC logging (for diagnostics)
server.jvm.additional=-Xlog:gc*:file=/var/log/neo4j/gc.log:time,uptime,level,tags:filecount=5,filesize=20m
```

**G1GC tuning for Neo4j:**
- G1GC is the recommended collector for Neo4j
- `MaxGCPauseMillis=200`: Target 200ms max pause (lower = more frequent but shorter pauses)
- Monitor with GC logs and adjust if pause times exceed targets

### Transaction Memory Limits

```properties
# neo4j.conf
# Maximum memory per transaction (prevents single query OOM)
dbms.memory.transaction.max=2g

# Maximum total memory for all transactions combined
dbms.memory.transaction.total.max=16g
```

### Memory Recommendation Tool

```bash
# Get recommendations based on available RAM
neo4j-admin server memory-recommendation --memory=64g

# Expected output:
# server.memory.heap.initial_size=16g
# server.memory.heap.max_size=16g
# server.memory.pagecache.size=38g
# Remaining 10g for OS and other processes
```

### Complete Memory Configuration Example

For a dedicated server with 64GB RAM and a 40GB store:

```properties
# neo4j.conf
server.memory.heap.initial_size=16g
server.memory.heap.max_size=16g
server.memory.pagecache.size=42g      # Covers 40GB store + room for growth
# Remaining ~6GB for OS, filesystem cache, native allocations

# Transaction limits
dbms.memory.transaction.max=2g
dbms.memory.transaction.total.max=12g
```

## Monitoring Setup

### Essential Metrics to Monitor

| Metric | Threshold | Action |
|---|---|---|
| Page cache hit ratio | < 95% | Increase `server.memory.pagecache.size` |
| Heap usage | > 85% sustained | Increase heap or investigate memory-heavy queries |
| GC pause time | > 500ms | Tune GC, reduce heap, or optimize queries |
| Active transactions | > 100 sustained | Connection pooling issue or slow queries |
| Transaction commit rate | Sudden drop | Check for locking, leader election, disk I/O |
| Bolt idle connections | Growing without bound | Client connection leak |
| Cluster replication lag | > 1000 tx | Network, disk I/O, or overloaded secondary |
| Query execution time p99 | Increasing trend | Query regression, missing index, data growth |

### Enable Query Logging

```properties
# neo4j.conf
db.logs.query.enabled=INFO
db.logs.query.threshold=1s              # Log queries slower than 1 second
db.logs.query.parameter_logging_enabled=true
db.logs.query.allocation_logging_enabled=true
db.logs.query.page_logging_enabled=true
db.logs.query.rotation.size=50m
db.logs.query.rotation.keep_number=10
```

### Prometheus + Grafana Setup

```properties
# neo4j.conf -- enable Prometheus endpoint
server.metrics.enabled=true
server.metrics.prometheus.enabled=true
server.metrics.prometheus.endpoint=0.0.0.0:2004
```

```yaml
# prometheus.yml scrape config
scrape_configs:
  - job_name: 'neo4j'
    scrape_interval: 15s
    static_configs:
      - targets: ['neo4j-host:2004']
```

## Backup Strategies

### Strategy 1: Full + Differential (Enterprise)

```bash
# Full backup weekly (Sunday 2 AM)
0 2 * * 0 neo4j-admin database backup neo4j --to-path=/backups/full/

# Differential backup daily (2 AM, Mon-Sat)
0 2 * * 1-6 neo4j-admin database backup neo4j --to-path=/backups/diff/ --type=DIFFERENTIAL

# Verify latest backup monthly
0 3 1 * * neo4j-admin database check --from-path=/backups/full/latest --report-dir=/backups/reports/
```

**Recovery point objective (RPO):** Up to 24 hours of data loss.
**Recovery time objective (RTO):** Minutes (restore from most recent differential).

### Strategy 2: Dump/Load (Community + Enterprise)

```bash
# Offline dump (requires stopping the database)
neo4j stop
neo4j-admin database dump neo4j --to-path=/backups/dumps/
neo4j start

# Or schedule during maintenance window
```

**RPO:** Depends on dump frequency.
**RTO:** Minutes to hours (depending on database size).

### Backup Verification

Always verify backups can be restored:
```bash
# 1. Check backup consistency
neo4j-admin database check --from-path=/backups/full/neo4j-backup --report-dir=/tmp/check/

# 2. Test restore to a separate instance
neo4j-admin database restore --from-path=/backups/full/neo4j-backup --database=test-restore --overwrite-destination

# 3. Start and verify
neo4j start
cypher-shell -d test-restore "MATCH (n) RETURN count(n);"
```

### Backup Retention Policy

```bash
# Keep 4 weekly full backups, 30 daily differentials
# Script to clean old backups:
find /backups/full/ -type f -mtime +28 -delete
find /backups/diff/ -type f -mtime +30 -delete
```

## Security Hardening

### Authentication

```properties
# neo4j.conf
# Require authentication (default: true)
dbms.security.auth_enabled=true

# Force password change on first login
dbms.security.auth_minimum_password_length=12

# Lock account after failed attempts
dbms.security.auth_max_failed_attempts=5
dbms.security.auth_lock_time=5m
```

### Change Default Password

```cypher
-- First login: change the default neo4j/neo4j password
ALTER CURRENT USER SET PASSWORD FROM 'neo4j' TO 'new-secure-password';
```

### Network Security

```properties
# neo4j.conf
# Bind to specific interface (not 0.0.0.0 in production)
server.default_listen_address=10.0.1.100

# Enable TLS for Bolt
server.bolt.tls_level=REQUIRED
dbms.ssl.policy.bolt.enabled=true
dbms.ssl.policy.bolt.base_directory=certificates/bolt
dbms.ssl.policy.bolt.private_key=private.key
dbms.ssl.policy.bolt.public_certificate=public.crt

# Enable TLS for HTTPS
server.https.enabled=true
dbms.ssl.policy.https.enabled=true
dbms.ssl.policy.https.base_directory=certificates/https

# Disable HTTP (use HTTPS only)
server.http.enabled=false

# Enable TLS for cluster communication
dbms.ssl.policy.cluster.enabled=true
dbms.ssl.policy.cluster.base_directory=certificates/cluster
```

### Role-Based Access Control

```cypher
-- Create application-specific roles
CREATE ROLE app_readonly;
GRANT MATCH {*} ON GRAPH neo4j TO app_readonly;
GRANT ACCESS ON DATABASE neo4j TO app_readonly;

CREATE ROLE app_readwrite;
GRANT MATCH {*} ON GRAPH neo4j TO app_readwrite;
GRANT WRITE ON GRAPH neo4j TO app_readwrite;
GRANT ACCESS ON DATABASE neo4j TO app_readwrite;

CREATE ROLE app_admin;
GRANT ALL ON DATABASE neo4j TO app_admin;

-- Create application users with appropriate roles
CREATE USER app_reader SET PASSWORD 'reader-pass' CHANGE NOT REQUIRED;
GRANT ROLE app_readonly TO app_reader;

CREATE USER app_writer SET PASSWORD 'writer-pass' CHANGE NOT REQUIRED;
GRANT ROLE app_readwrite TO app_writer;

-- Deny access to sensitive properties
DENY READ {ssn, creditCard} ON GRAPH neo4j TO app_readonly;
DENY READ {ssn, creditCard} ON GRAPH neo4j TO app_readwrite;
```

### Audit Logging

```properties
# neo4j.conf
# Enable security event logging
dbms.security.log_successful_authentication=true
```

### SSO / LDAP Configuration

```properties
# neo4j.conf -- LDAP authentication
dbms.security.authentication_providers=ldap
dbms.security.authorization_providers=ldap

dbms.security.ldap.host=ldap://ldap.example.com:389
dbms.security.ldap.authentication.user_dn_template=uid={0},ou=people,dc=example,dc=com
dbms.security.ldap.authorization.user_search_base=ou=people,dc=example,dc=com
dbms.security.ldap.authorization.user_search_filter=(&(objectClass=person)(uid={0}))
dbms.security.ldap.authorization.group_membership_attributes=memberOf
dbms.security.ldap.authorization.group_to_role_mapping=\
  cn=neo4j-admins,ou=groups,dc=example,dc=com=admin;\
  cn=neo4j-readers,ou=groups,dc=example,dc=com=reader
```

## Performance Tuning Checklist

### Query Performance

- [ ] Use parameterized queries (avoid string concatenation)
- [ ] Create indexes on all MERGE key properties
- [ ] Create indexes on properties used in WHERE clauses
- [ ] Bound all variable-length paths (`[*1..5]` not `[*]`)
- [ ] PROFILE expensive queries and check for CartesianProduct
- [ ] Use WITH to reduce cardinality between query parts
- [ ] Filter early (push WHERE as close to MATCH as possible)
- [ ] Use LIMIT when only a subset of results is needed
- [ ] Avoid `collect()` on large result sets (memory risk)
- [ ] Use CALL IN TRANSACTIONS for large write operations

### Infrastructure Performance

- [ ] Size page cache to cover the store (check hit ratio > 95%)
- [ ] Set heap initial_size = max_size (avoid resize GC pauses)
- [ ] Keep heap <= 31GB (compressed oops)
- [ ] Use SSD/NVMe storage (graph traversals are random I/O)
- [ ] Separate transaction log and store onto different disks
- [ ] Enable query logging with threshold to find slow queries
- [ ] Monitor GC pauses and keep < 500ms
- [ ] Use connection pooling in application drivers
- [ ] Set transaction timeouts to prevent runaway queries

### Data Model Performance

- [ ] Review for supernodes and mitigate (fan-out nodes, type bucketing)
- [ ] Use specific relationship types instead of generic ones
- [ ] Place frequently filtered properties on relationships
- [ ] Consider intermediate nodes for rich relationships
- [ ] Avoid over-labeling (each additional label adds storage and index overhead)
- [ ] Use temporal bucketing for time-series relationships
