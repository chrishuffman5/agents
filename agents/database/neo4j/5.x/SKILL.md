---
name: database-neo4j-5x
description: "Neo4j 5.x LTS version-specific expert. Deep knowledge of composite databases, quantified path patterns, block storage format, CALL IN TRANSACTIONS, new index types, type system improvements, dynamic labels/types/properties, Cypher subqueries, and migration from 4.x. WHEN: \"Neo4j 5\", \"Neo4j 5.x\", \"Neo4j 5.26\", \"composite database\", \"server-side routing\", \"quantified path pattern\", \"QPP\", \"block format\", \"CALL IN TRANSACTIONS\", \"COLLECT subquery\", \"dynamic labels\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Neo4j 5.x LTS Expert

You are a specialist in Neo4j 5.x, with the Long-Term Support release being version 5.26 (December 2024). You have deep knowledge of the features introduced across the 5.x series, particularly composite databases, quantified path patterns, block storage format, and the enhanced Cypher subquery capabilities.

**Support status:** Neo4j 5.26 LTS is supported until June 2028 with security and bug fix updates.

**Upgrade path:** 5.26 LTS is the recommended upgrade source for migrating to the 2025-2026 CalVer series. Online upgrades from 5.26 LTS to 2025.01+ are supported.

## Key Features Introduced in Neo4j 5.x

### Composite Databases (5.0+)

Composite databases replace the Fabric implementation from 4.x, enabling data federation and sharding across multiple databases with a single Cypher query:

```cypher
-- Create a composite database
CREATE COMPOSITE DATABASE analytics;

-- Add local database aliases as constituents
CREATE ALIAS analytics.sales FOR DATABASE sales_db;
CREATE ALIAS analytics.marketing FOR DATABASE marketing_db;

-- Add remote database aliases (cross-cluster federation)
CREATE ALIAS analytics.partners
  FOR DATABASE partners AT 'neo4j+s://partner-cluster:7687'
  USER neo4j PASSWORD 'secret';
```

**Querying across composite databases:**
```cypher
-- Query across multiple constituent databases
USE analytics
CALL {
  USE analytics.sales
  MATCH (c:Customer)-[:PURCHASED]->(p:Product)
  RETURN c.name AS customer, p.name AS product, 'sales' AS source
UNION
  USE analytics.marketing
  MATCH (l:Lead)-[:INTERESTED_IN]->(p:Product)
  RETURN l.name AS customer, p.name AS product, 'marketing' AS source
}
RETURN customer, product, source;
```

**Composite database use cases:**
- **Data federation**: Query across geographically distributed databases
- **Data sharding**: Split a large graph across databases by region, time period, or domain
- **Multi-tenancy**: Each tenant in a separate database, queried through a composite view
- **Legacy integration**: Combine data from different Neo4j clusters

**Limitations:**
- Write operations must target a specific constituent (not the composite)
- Transactions span only one constituent at a time
- Schema operations (indexes, constraints) are per-constituent, not composite-wide

### Block Storage Format (5.14+, Default in 5.26)

The block storage format is a fundamental redesign of how Neo4j stores data on disk:

```bash
# Check current store format
neo4j-admin database info neo4j

# Migrate from record format to block format (offline)
neo4j stop
neo4j-admin database migrate neo4j --to-format=block
neo4j start
```

**Block format advantages:**
| Aspect | Record Format | Block Format |
|---|---|---|
| Page alignment | Mixed sizes | 8KB blocks (aligned with NVMe/OS pages) |
| Data locality | Node, properties, relationships in separate files | Related data co-located in same block |
| Token name length | 64KB max | 16,383 characters (GQL max) |
| I/O per traversal | Multiple random reads | Often single page read |
| Compression | Per-store-file | Per-block (better compression ratio) |
| Default in 5.26 | No | Yes (Enterprise Edition) |

**Migration considerations:**
- Block format migration is one-way (cannot revert to record format)
- Database must be stopped for migration
- Migration time depends on store size (plan for 30-60 min per 100GB)
- It is strongly recommended to migrate to block format on 5.26 before upgrading to 2025-2026 CalVer

### Quantified Path Patterns (QPP) (5.9+)

QPPs provide more powerful and efficient path matching than variable-length relationships:

```cypher
-- Traditional variable-length path: find all paths of length 2-4
MATCH (a:Person {name: 'Alice'})-[:KNOWS*2..4]->(b:Person)
RETURN b.name;

-- QPP equivalent with inline filtering (much more expressive)
MATCH (a:Person {name: 'Alice'}) (()-[:KNOWS]->(intermediate:Person WHERE intermediate.active = true)){2,4} (b:Person)
RETURN b.name;
```

**QPP advantages over variable-length relationships:**
- Inline filtering on intermediate nodes and relationships (avoids post-filter)
- Multiple relationship types in the pattern
- Named variables within the quantified part
- Significantly better performance due to early pruning

**Complex QPP examples:**
```cypher
-- Find paths where each intermediate person is in the same department
MATCH (start:Person {name: 'Alice'})
      ((a)-[:WORKS_WITH]->(b) WHERE a.department = b.department){1,5}
      (end:Person)
RETURN end.name;

-- Supply chain: find products through 2-6 supplier hops, each with active contracts
MATCH (origin:Supplier {name: 'OriginCo'})
      (()-[c:SUPPLIES WHERE c.contractActive = true]->(:Supplier)){2,6}
      (dest:Supplier)
RETURN dest.name, dest.country;
```

### CALL {} Subqueries (5.0+) and CALL IN TRANSACTIONS (5.0+)

**Subqueries** allow encapsulation of query parts:
```cypher
-- Correlated subquery
MATCH (p:Person)
CALL {
  WITH p
  MATCH (p)-[:PURCHASED]->(product)
  RETURN count(product) AS purchaseCount
}
RETURN p.name, purchaseCount
ORDER BY purchaseCount DESC;
```

**CALL IN TRANSACTIONS** (replacing `USING PERIODIC COMMIT`):
```cypher
-- Batch update with explicit transaction batching
MATCH (n:LegacyNode)
CALL {
  WITH n
  SET n:MigratedNode
  REMOVE n:LegacyNode
} IN TRANSACTIONS OF 10000 ROWS;

-- Batch delete with error handling
MATCH (n:TempData)
CALL { WITH n DETACH DELETE n }
IN TRANSACTIONS OF 5000 ROWS
  ON ERROR CONTINUE;
```

**ON ERROR options (5.17+):**
- `ON ERROR FAIL` (default): Abort entire operation on first error
- `ON ERROR CONTINUE`: Skip failed batches, continue processing
- `ON ERROR BREAK`: Stop processing but keep successful batches

### COLLECT Subqueries (5.6+)

COLLECT subqueries aggregate results into a list with fine-grained control:

```cypher
-- Collect top 5 friends ordered by name
MATCH (p:Person {name: 'Alice'})
RETURN p.name,
  COLLECT {
    MATCH (p)-[:KNOWS]->(friend)
    RETURN friend.name
    ORDER BY friend.name
    LIMIT 5
  } AS topFriends;
```

**Advantages over collect() function:**
- Support for ORDER BY, LIMIT, SKIP, DISTINCT within the subquery
- More readable for complex aggregation patterns

### COUNT and EXISTS Subqueries (5.0+)

```cypher
-- COUNT subquery: count matching patterns inline
MATCH (p:Person)
WHERE COUNT {
  MATCH (p)-[:PURCHASED]->(:Product)
} > 5
RETURN p.name;

-- EXISTS subquery: check existence of a pattern
MATCH (p:Person)
WHERE EXISTS {
  MATCH (p)-[:WORKS_AT]->(:Company {name: 'Acme'})
}
RETURN p.name;
```

### New Index Types (5.0+)

**Text indexes (trigram-based):**
```cypher
-- Text index: optimized for CONTAINS and ENDS WITH
CREATE TEXT INDEX person_bio_text FOR (n:Person) ON (n.bio);

-- Queries that benefit from text indexes
MATCH (n:Person) WHERE n.bio CONTAINS 'graph database' RETURN n;
MATCH (n:Person) WHERE n.bio ENDS WITH 'engineer' RETURN n;
```

**Relationship indexes:**
```cypher
-- Range index on relationship property
CREATE INDEX works_at_since FOR ()-[r:WORKS_AT]-() ON (r.since);

-- Text index on relationship property
CREATE TEXT INDEX review_text FOR ()-[r:REVIEWED]-() ON (r.text);
```

### Dynamic Labels, Types, and Properties (5.26)

Dynamic expressions can now be used for labels, relationship types, and properties:

```cypher
-- Dynamic label
WITH 'Person' AS labelName
MATCH (n) WHERE labelName IN labels(n)
RETURN n;

-- Dynamic property access
WITH 'name' AS propKey
MATCH (n:Person)
RETURN n[propKey] AS value;
```

### Type System Improvements

**Property type constraints (5.9+, Enterprise):**
```cypher
-- Enforce property types
CREATE CONSTRAINT person_age_type FOR (p:Person)
  REQUIRE p.age IS :: INTEGER;

CREATE CONSTRAINT event_date_type FOR (e:Event)
  REQUIRE e.date IS :: DATE;

-- Allowed types: BOOLEAN, STRING, INTEGER, FLOAT, DATE, LOCAL TIME,
-- ZONED TIME, LOCAL DATETIME, ZONED DATETIME, DURATION, POINT,
-- LIST<type>, and NOTHING (nullable)
```

### Server-Side Routing (5.x+)

Server-side routing eliminates the need for client-side routing tables in clusters:

```properties
# neo4j.conf
# Enable server-side routing (recommended for 5.x clusters)
dbms.routing.enabled=true

# Client connection entry point
dbms.routing.default_router=SERVER

# Advertised address for routing
server.routing.advertised_address=neo4j-server-1:7688
```

**Benefits:**
- Simplifies client configuration (single endpoint instead of multiple)
- Better load balancing control on the server side
- Works with load balancers and Kubernetes services
- Clients use `neo4j://` protocol and the cluster handles routing internally

## Breaking Changes from 4.x to 5.x

### Renamed Configuration Properties

| 4.x Setting | 5.x Setting |
|---|---|
| `dbms.memory.heap.initial_size` | `server.memory.heap.initial_size` |
| `dbms.memory.heap.max_size` | `server.memory.heap.max_size` |
| `dbms.memory.pagecache.size` | `server.memory.pagecache.size` |
| `dbms.connector.bolt.listen_address` | `server.bolt.listen_address` |
| `dbms.connector.http.listen_address` | `server.http.listen_address` |
| `dbms.default_database` | `initial.dbms.default_database` |
| `dbms.directories.data` | `server.directories.data` |

### Removed or Changed Cypher Features

- `CREATE INDEX ON :Label(property)` syntax replaced by `CREATE INDEX FOR (n:Label) ON (n.property)`
- `DROP INDEX ON :Label(property)` syntax replaced by `DROP INDEX indexName`
- `CREATE CONSTRAINT ON (n:Label) ASSERT n.property IS UNIQUE` replaced by `CREATE CONSTRAINT FOR (n:Label) REQUIRE n.property IS UNIQUE`
- `USING PERIODIC COMMIT` replaced by `CALL {} IN TRANSACTIONS`
- Fabric `USE fabric.graph(name)` replaced by composite database `USE composite.alias`

### Cluster Architecture Changes

| 4.x Concept | 5.x Concept |
|---|---|
| Core Server | Primary Server |
| Read Replica | Secondary Server |
| Causal Clustering | Clustering (simplified) |
| `dbms.mode=CORE` | `server.cluster.system_database_mode=PRIMARY` |
| `dbms.mode=READ_REPLICA` | `server.cluster.system_database_mode=SECONDARY` |

## Migration Guidance (4.x to 5.x)

### Pre-Migration Checklist

1. **Upgrade to latest 4.4.x** first (incremental upgrade path)
2. **Check deprecated feature usage:**
   ```cypher
   -- Look for deprecated syntax in application code
   -- Check for: old index/constraint syntax, PERIODIC COMMIT, Fabric queries
   SHOW PROCEDURES YIELD name WHERE name STARTS WITH 'dbms.' RETURN name;
   ```
3. **Review configuration changes:** Map all 4.x settings to 5.x equivalents
4. **Test with 5.x in a staging environment** before production migration
5. **Plan for block format migration** (recommended after upgrading to 5.26)

### Migration Steps

```bash
# 1. Stop Neo4j 4.4
neo4j stop

# 2. Backup (critical!)
neo4j-admin dump --database=neo4j --to=/backups/pre-migration/neo4j.dump

# 3. Install Neo4j 5.x alongside 4.4

# 4. Update neo4j.conf with new property names

# 5. Migrate the database
neo4j-admin database migrate neo4j

# 6. Start Neo4j 5.x
neo4j start

# 7. Verify
cypher-shell "MATCH (n) RETURN count(n);"
cypher-shell "SHOW INDEXES;"
cypher-shell "SHOW CONSTRAINTS;"

# 8. Migrate to block format (optional but recommended)
neo4j stop
neo4j-admin database migrate neo4j --to-format=block
neo4j start
```

## 5.x Version Timeline

| Version | Release | Key Feature |
|---|---|---|
| 5.0 | Oct 2022 | Composite databases, CALL IN TRANSACTIONS, new index syntax |
| 5.6 | Mar 2023 | COLLECT subqueries |
| 5.9 | Jun 2023 | Quantified Path Patterns (QPP), property type constraints |
| 5.14 | Nov 2023 | Block storage format (optional) |
| 5.17 | Feb 2024 | ON ERROR for CALL IN TRANSACTIONS |
| 5.21 | Jun 2024 | CALL IN CONCURRENT TRANSACTIONS |
| 5.26 LTS | Dec 2024 | Block format default (Enterprise), dynamic labels/types/properties |

## Version-Specific Cypher Examples

### EXISTS and COUNT Subqueries (5.0+)

```cypher
-- Find people who have at least 3 friends who work at the same company
MATCH (p:Person)-[:WORKS_AT]->(c:Company)
WHERE COUNT {
  MATCH (p)-[:KNOWS]->(friend)-[:WORKS_AT]->(c)
} >= 3
RETURN p.name, c.name;
```

### QPP + COLLECT Subquery Combination (5.9+)

```cypher
-- For each person, find all reachable people through active KNOWS chains (1-3 hops)
-- and collect their names ordered by degree
MATCH (start:Person {name: 'Alice'})
RETURN start.name,
  COLLECT {
    MATCH (start) (()-[:KNOWS WHERE _.active = true]->()){1,3} (reachable:Person)
    WHERE reachable <> start
    RETURN DISTINCT reachable.name
    ORDER BY reachable.name
    LIMIT 20
  } AS reachableContacts;
```

### CALL IN CONCURRENT TRANSACTIONS (5.21+)

```cypher
-- Parallel batch processing (each batch runs in its own transaction, concurrently)
MATCH (p:Person) WHERE p.score IS NULL
CALL {
  WITH p
  SET p.score = 0.5
} IN CONCURRENT TRANSACTIONS OF 10000 ROWS;
```
**Note:** Concurrent transactions can cause lock contention if batches modify overlapping data. Use for independent updates only.
