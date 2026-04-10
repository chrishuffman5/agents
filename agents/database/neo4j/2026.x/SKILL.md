---
name: database-neo4j-2026x
description: "Neo4j 2026.x version-specific expert. Deep knowledge of CalVer releases, Cypher 25 as default language, GQL compliance, block storage requirement, attribute-based access control (ABAC) GA, vector type, query progress tracking, and migration from 5.26 LTS. WHEN: \"Neo4j 2026\", \"Neo4j current\", \"GQL\", \"block storage format\", \"Cypher 25\", \"CYPHER_25\", \"CalVer\", \"ABAC\", \"attribute-based access control\", \"vector type\", \"Neo4j 2026.01\", \"Neo4j 2026.02\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Neo4j 2026.x Expert

You are a specialist in Neo4j 2026.x, the current release series using Calendar Versioning (CalVer) in the format YYYY.MM.PATCH. You have deep knowledge of the features introduced in the 2025-2026 CalVer series, particularly Cypher 25 as the default query language, GQL compliance, block storage as the only supported format, attribute-based access control GA, and the new vector type.

**Release model:** Monthly releases in CalVer format (e.g., 2026.01, 2026.02, 2026.03). Each release includes new features, bug fixes, and security patches.

**Support status:** Current active release. Monthly updates with backward compatibility within the CalVer series.

**Upgrade path:** Online upgrade from Neo4j 5.26 LTS is the recommended path.

## Calendar Versioning (CalVer)

Starting January 2025, Neo4j adopted CalVer:
- Format: `YYYY.MM.PATCH` (e.g., `2026.02.1`)
- `YYYY`: Release year
- `MM`: Release month
- `PATCH`: Incremented for patches within the same month

This replaces the traditional semantic versioning (5.x) with a time-based release cadence.

## Key Features in the 2025-2026 Series

### Cypher 25 (Default in 2026.02+)

Cypher 25 is the next evolution of the Cypher query language, introduced alongside Neo4j 2025.06 as an evolution of Cypher 5:

```properties
# neo4j.conf -- default from 2026.02 for new deployments
db.query.default_language=CYPHER_25
```

**Selecting Cypher version per query:**
```cypher
-- Explicitly use Cypher 25
CYPHER 25 MATCH (n:Person) RETURN n;

-- Explicitly use Cypher 5 (for backward compatibility)
CYPHER 5 MATCH (n:Person) RETURN n;
```

**Cypher 25 new features:**

**1. Walk Semantics with REPEATABLE ELEMENTS:**
```cypher
-- Default: trail semantics (relationships not repeated)
MATCH DIFFERENT RELATIONSHIPS (a)-[*1..5]->(b)
RETURN a, b;

-- New: walk semantics (relationships CAN be repeated)
MATCH REPEATABLE ELEMENTS (a)-[*1..5]->(b)
RETURN a, b;
```
Trail semantics (relationships not repeated) remains the default. The explicit keywords make the intent clear.

**2. Enclosing Queries in Curly Braces (GQL syntax):**
```cypher
-- GQL-style enclosed query
{
  MATCH (n:Person)
  RETURN n.name
}
```

**3. WHEN/ELSE Conditional Composition:**
```cypher
-- Conditional query branches based on runtime conditions
MATCH (p:Person {name: $name})
WHEN p.type = 'employee' THEN {
  MATCH (p)-[:WORKS_AT]->(c:Company)
  RETURN p.name, c.name AS context
}
ELSE {
  MATCH (p)-[:STUDIES_AT]->(u:University)
  RETURN p.name, u.name AS context
}
```

**4. FILTER Clause:**
```cypher
-- Mid-query filtering (alternative to WHERE in some contexts)
MATCH (n:Person)
FILTER n.age > 21
RETURN n.name;
```

**5. VECTOR Type:**
```cypher
-- Vector type support for embeddings and similarity search
CREATE (n:Document {
  title: 'Graph Databases',
  embedding: toVector([0.1, 0.5, 0.3, 0.8], 4)
});

-- Vector index for similarity search
CREATE VECTOR INDEX doc_embeddings FOR (n:Document) ON (n.embedding)
OPTIONS {
  indexConfig: {
    `vector.dimensions`: 384,
    `vector.similarity_function`: 'cosine'
  }
};

-- Query by vector similarity
CALL db.index.vector.queryNodes('doc_embeddings', 10, $queryVector)
YIELD node, score
RETURN node.title, score;
```

### GQL Compliance

Neo4j 2026.x adds GQL (Graph Query Language, ISO/IEC 39075) compliant aliases for existing Cypher functions:

| Cypher Function | GQL Alias |
|---|---|
| `ceil()` | `ceiling()` |
| `localtime()` | `local_time()` |
| `localdatetime()` | `local_datetime()` |
| `time()` | `zoned_time()` |
| `datetime()` | `zoned_datetime()` |
| `duration.between()` | `duration_between()` |
| `length()` on paths | `path_length()` |
| `log()` | `ln()` |
| `collect()` | `collect_list()` |
| `percentileDisc()` | `percentile_disc()` |
| `percentileCont()` | `percentile_cont()` |
| `stDevP()` | `stdev_pop()` |
| `stDev()` | `stdev_samp()` |

Both the original Cypher names and the GQL aliases work. The GQL aliases improve compliance with the ISO standard.

### Block Storage Format (Required)

In the 2025-2026 series, block storage format is the only supported format for Enterprise Edition:

- All new databases are created in block format
- Databases must be migrated to block format before upgrading from 5.26 LTS
- Record format is no longer supported for new databases

**Pre-upgrade migration on 5.26 LTS:**
```bash
# On Neo4j 5.26 LTS, migrate all databases to block format BEFORE upgrading
neo4j stop
neo4j-admin database migrate neo4j --to-format=block
neo4j-admin database migrate system --to-format=block
neo4j start

# Verify format
neo4j-admin database info neo4j
# Should show: Store format: Block
```

### Attribute-Based Access Control (ABAC) -- GA (2026.01+)

ABAC extends RBAC with property-based conditions for fine-grained access control:

```cypher
-- Grant read access only to nodes where department matches the user's department
GRANT MATCH {*} ON GRAPH neo4j
  NODE Person
  WHERE person.department = $auth.jwt.department
  TO department_reader;

-- Grant write access only to records the user owns
GRANT SET PROPERTY {*} ON GRAPH neo4j
  NODE Document
  WHERE document.ownerId = $auth.jwt.sub
  TO document_editor;
```

**ABAC features:**
- Filter access based on node/relationship properties
- Reference JWT claims from the authenticated user
- Combine with RBAC roles for layered security
- Users cannot distinguish between hidden data and nonexistent data

### Query Progress Tracking (2026.02+)

```cypher
-- Monitor progress of long-running queries
SHOW TRANSACTIONS
YIELD transactionId, currentQuery, elapsedTime, status, statusDetails
WHERE statusDetails IS NOT NULL;
```

Query progress is now included in the `SHOW TRANSACTIONS` output, providing visibility into how far along a long-running batch operation is.

### Maximum Query Size for Caching (2026.01+)

A maximum query size limit was introduced for query caching:

```properties
# neo4j.conf -- default 128 KiB
server.memory.query_cache.per_entry_max_query_size=128k
```

**Override per query:**
```cypher
-- Force caching of a large query
CYPHER cache=force
MATCH (n:Person)-[:KNOWS*1..3]->(friend)
RETURN friend;

-- Skip caching for a one-off query
CYPHER cache=skip
MATCH (n) RETURN count(n);
```

### New Routing Policies (2025.12+)

Built-in routing policies provide better control over read/write distribution:

```properties
# neo4j.conf
# Allow reads on primary servers (default: true)
dbms.routing.reads_on_primaries_enabled=true

# Allow reads on the writer/leader (default: false)
dbms.routing.reads_on_writers_enabled=false
```

## Breaking Changes from 5.26 LTS

### Block Format Required

- All databases MUST be in block format before upgrading to 2025-2026
- Record format databases cannot be opened in 2025-2026 versions
- System database must also be in block format

### Default Language Change

- Starting from 2026.02, the distributed `neo4j.conf` sets `db.query.default_language=CYPHER_25`
- Existing databases retain their configured language
- Applications using deprecated Cypher 5 syntax should test with Cypher 25

### Configuration Changes

```properties
# New or changed settings in 2025-2026
server.memory.query_cache.per_entry_max_query_size=128k    # New: max query size for caching
dbms.routing.reads_on_primaries_enabled=true                # New: routing policy
dbms.routing.reads_on_writers_enabled=false                  # New: routing policy
```

### Deprecated Procedures

| Deprecated | Replacement |
|---|---|
| `dbms.listQueries()` | `SHOW TRANSACTIONS` |
| `dbms.killQuery()` | `TERMINATE TRANSACTION` |
| `dbms.listTransactions()` | `SHOW TRANSACTIONS` |
| `dbms.killTransaction()` | `TERMINATE TRANSACTION` |
| `dbms.cluster.overview()` | `SHOW SERVERS` + `SHOW DATABASES` |

## Migration Guidance (5.26 LTS to 2026.x)

### Pre-Migration Checklist

1. **Ensure all databases are in block format:**
   ```bash
   neo4j-admin database info neo4j
   neo4j-admin database info system
   # Both must show "Block" format
   ```

2. **Test Cypher 25 compatibility:**
   ```cypher
   -- Run critical queries with explicit Cypher 25 to check for issues
   CYPHER 25 MATCH (n:Person) WHERE n.age > 21 RETURN n;
   ```

3. **Review deprecated procedure usage:**
   ```cypher
   -- Check application code for deprecated procedures
   -- Replace: dbms.listQueries() -> SHOW TRANSACTIONS
   -- Replace: dbms.killQuery() -> TERMINATE TRANSACTION
   ```

4. **Backup:**
   ```bash
   neo4j-admin database backup neo4j --to-path=/backups/pre-migration/
   neo4j-admin database backup system --to-path=/backups/pre-migration/
   ```

### Migration Steps

```bash
# 1. Verify 5.26 LTS is on latest patch
neo4j --version

# 2. Migrate all databases to block format (if not already done)
neo4j stop
neo4j-admin database migrate neo4j --to-format=block
neo4j-admin database migrate system --to-format=block
neo4j start
# Verify: neo4j-admin database info neo4j

# 3. Backup
neo4j-admin database backup neo4j --to-path=/backups/pre-upgrade/
neo4j-admin database backup system --to-path=/backups/pre-upgrade/

# 4. Stop Neo4j 5.26
neo4j stop

# 5. Install Neo4j 2026.x (replace binaries, keep data directory)

# 6. Update neo4j.conf
# - Review new settings
# - Optionally set db.query.default_language=CYPHER_5 for gradual migration

# 7. Start Neo4j 2026.x (online upgrade happens automatically)
neo4j start

# 8. Verify
cypher-shell "SHOW DATABASES;"
cypher-shell "MATCH (n) RETURN count(n);"
cypher-shell "SHOW INDEXES;"
```

### Gradual Cypher 25 Migration

If you are not ready for Cypher 25 as default:

```properties
# neo4j.conf -- keep Cypher 5 as default during transition
db.query.default_language=CYPHER_5
```

Then migrate application queries incrementally:
```cypher
-- Test individual queries with Cypher 25
CYPHER 25 MATCH (n:Person) RETURN n LIMIT 10;

-- Once all queries are validated, switch default
-- CALL dbms.setConfigValue('db.query.default_language', 'CYPHER_25');
```

## 2026.x Release Timeline

| Version | Release | Key Changes |
|---|---|---|
| 2025.01 | Jan 2025 | First CalVer release; online upgrade from 5.26 LTS |
| 2025.06 | Jun 2025 | Cypher 25 introduced (optional) |
| 2025.09 | Sep 2025 | Remote backup source selection, consistency check improvements |
| 2025.12 | Dec 2025 | New built-in routing policies |
| 2026.01 | Jan 2026 | ABAC GA, max query size for caching |
| 2026.02 | Feb 2026 | Cypher 25 default for new deployments, query progress in SHOW TRANSACTIONS |
| 2026.03+ | Mar 2026+ | Continued monthly releases |

## Version-Specific Cypher Examples

### Cypher 25: Walk Semantics

```cypher
-- Find cycles in the graph (requires walk semantics to revisit nodes)
CYPHER 25
MATCH REPEATABLE ELEMENTS
  p = (start:Person {name: 'Alice'})-[:KNOWS*3..6]->(start)
RETURN [n IN nodes(p) | n.name] AS cycle;
```

### Cypher 25: FILTER Clause

```cypher
-- Filter mid-query without embedding in WHERE
CYPHER 25
MATCH (p:Person)-[:LIVES_IN]->(c:City)
FILTER c.population > 1000000
MATCH (p)-[:WORKS_AT]->(company:Company)
RETURN p.name, c.name, company.name;
```

### Vector Search with Cypher 25

```cypher
-- Create vector index
CREATE VECTOR INDEX article_embeddings FOR (n:Article) ON (n.embedding)
OPTIONS {
  indexConfig: {
    `vector.dimensions`: 768,
    `vector.similarity_function`: 'cosine'
  }
};

-- Query: find similar articles
CYPHER 25
CALL db.index.vector.queryNodes('article_embeddings', 5, $queryEmbedding)
YIELD node AS article, score
MATCH (article)-[:WRITTEN_BY]->(author:Person)
RETURN article.title, author.name, score
ORDER BY score DESC;
```

### GQL-Compliant Function Usage

```cypher
-- Using GQL aliases (both old and new names work)
CYPHER 25
MATCH (p:Person)
RETURN p.name,
       ceiling(p.rating) AS roundedRating,          -- GQL alias for ceil()
       zoned_datetime() AS currentTime,              -- GQL alias for datetime()
       collect_list(p.tag) AS allTags;               -- GQL alias for collect()
```

### ABAC Example

```cypher
-- Create a role with attribute-based filtering
CREATE ROLE regional_manager;

-- Grant access only to employees in the manager's region
GRANT MATCH {*} ON GRAPH hr
  NODE Employee
  TO regional_manager;

-- The actual filtering happens via the ABAC policy,
-- which checks the JWT claims of the authenticated user
-- against the node properties at query time.
```

## Compatibility Notes

### Driver Compatibility

- Neo4j 2026.x is fully compatible with Bolt protocol v5+ drivers
- Driver versions 5.x and later work without changes
- The `neo4j://` routing protocol continues to work as expected
- v6 drivers add support for the VECTOR type

### Plugin and Extension Compatibility

- APOC versions follow Neo4j CalVer (e.g., APOC 2026.02 for Neo4j 2026.02)
- GDS versions are independently versioned but maintain compatibility tables
- Check release notes for specific APOC/GDS version compatibility

```cypher
-- Verify installed plugin versions
SHOW PROCEDURES YIELD name WHERE name STARTS WITH 'apoc.' RETURN count(*) AS apocProcedures;
SHOW PROCEDURES YIELD name WHERE name STARTS WITH 'gds.' RETURN count(*) AS gdsProcedures;
```
