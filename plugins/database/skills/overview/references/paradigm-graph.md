# Paradigm: Graph Databases

When and why to choose a graph database. Covers Neo4j, Amazon Neptune, ArangoDB, JanusGraph, and TigerGraph.

## What Defines a Graph Database

Graph databases store data as nodes (vertices) and relationships (edges), where relationships are first-class citizens with their own properties and identity. Unlike RDBMS where relationships are implicit (foreign keys resolved at query time via JOINs), graph databases store relationships explicitly as pointers, enabling O(1) traversal per hop regardless of dataset size.

Two primary models:
- **Property Graph** (Neo4j, Neptune, TigerGraph): Nodes and edges carry key-value properties. Edges are typed and directed. Most common model.
- **RDF (Resource Description Framework)** (Neptune, Blazegraph): Data is triples (subject-predicate-object). SPARQL query language. Used in semantic web, linked data, knowledge graphs.

## Choose Graph Databases When

- **Relationships ARE the query.** "Find friends of friends who also like X." "What is the shortest path between A and B?" "Which accounts are connected to this fraudulent transaction within 3 hops?" These queries are natural in graph, torturous in SQL.
- **Traversal depth is variable or deep.** RDBMS recursive CTEs degrade exponentially with depth. A 6-hop traversal in Neo4j takes milliseconds; the same query in PostgreSQL can take minutes on a large dataset.
- **Data is naturally a network.** Social graphs, organizational hierarchies, supply chain networks, network topologies, knowledge graphs, recommendation engines.
- **Schema is fluid and interconnected.** New relationship types and node labels can be added without ALTER TABLE. The graph schema evolves organically.
- **Real-time pattern matching is needed.** Fraud detection (ring detection), identity resolution (entity matching across datasets), impact analysis (what depends on this component?).

## Avoid Graph Databases When

- **Queries are mostly tabular aggregations.** "Total sales by region by month" is a SQL GROUP BY, not a graph traversal. Graph databases are not designed for bulk analytical aggregation.
- **Data is naturally tabular with simple relationships.** Standard OLTP (orders, invoices, inventory) with well-defined foreign keys. RDBMS handles this better with decades of optimization.
- **Bulk data loading and batch processing dominate.** Graph databases optimize for online traversal, not ETL batch jobs. Loading billions of edges is slow compared to RDBMS bulk insert.
- **Horizontal write scaling is critical.** Most graph databases (especially Neo4j Community) are single-writer. Distributed graph databases exist (TigerGraph, JanusGraph) but add complexity.
- **Simple key-value or document access patterns prevail.** If you rarely traverse relationships, the graph overhead is wasted.

## Technology Comparison

| Feature | Neo4j | Amazon Neptune | ArangoDB | JanusGraph | TigerGraph |
|---|---|---|---|---|---|
| **Model** | Property graph | Property graph + RDF | Multi-model (graph + document + KV) | Property graph | Property graph |
| **Query Language** | Cypher | Gremlin, SPARQL, openCypher | AQL (ArangoDB Query Language) | Gremlin, SPARQL | GSQL |
| **Scaling** | Causal clustering (read replicas) | Managed (read replicas, serverless) | Sharded clusters | Distributed (Cassandra/HBase backend) | Distributed (MPP) |
| **ACID Transactions** | Full ACID | Full ACID | Full ACID | Eventual (depends on backend) | ACID per query |
| **Storage Backend** | Native graph storage | Purpose-built (AWS managed) | RocksDB | Pluggable (Cassandra, HBase, BerkeleyDB) | Native |
| **Best For** | General graph workloads, Cypher ecosystem | AWS-native, SPARQL/RDF, managed | Multi-model flexibility | Large-scale distributed graph | High-performance analytics, deep-link queries |
| **Licensing** | Community (GPL) / Enterprise (commercial) | AWS managed (pay per use) | Community (Apache) / Enterprise | Open source (Apache) | Community (free) / Enterprise |

## Cypher Query Language (Neo4j)

Cypher is the most widely adopted graph query language (standardized as GQL ISO/IEC 39075).

### Core Syntax

```cypher
// Create nodes with labels and properties
CREATE (alice:Person {name: 'Alice', department: 'Engineering'})
CREATE (bob:Person {name: 'Bob', department: 'Marketing'})
CREATE (project:Project {name: 'GraphDB Migration', budget: 50000})

// Create typed, directed relationships with properties
CREATE (alice)-[:MANAGES {since: date('2024-01-15')}]->(project)
CREATE (bob)-[:CONTRIBUTES_TO {role: 'consultant', hours_per_week: 10}]->(project)
CREATE (alice)-[:KNOWS {since: date('2022-06-01')}]->(bob)

// Pattern matching: find Alice's projects
MATCH (p:Person {name: 'Alice'})-[:MANAGES]->(proj:Project)
RETURN proj.name, proj.budget

// Variable-length paths: find everyone within 3 hops of Alice
MATCH (alice:Person {name: 'Alice'})-[*1..3]-(connected:Person)
RETURN DISTINCT connected.name

// Shortest path
MATCH path = shortestPath(
  (a:Person {name: 'Alice'})-[*]-(b:Person {name: 'Dave'})
)
RETURN path, length(path)

// Aggregation with graph context
MATCH (p:Person)-[r:CONTRIBUTES_TO]->(proj:Project)
RETURN proj.name, count(p) AS contributors, sum(r.hours_per_week) AS total_hours
ORDER BY total_hours DESC
```

### Indexing in Neo4j

```cypher
// B-tree index for property lookups
CREATE INDEX person_name_idx FOR (p:Person) ON (p.name)

// Composite index
CREATE INDEX person_dept_role_idx FOR (p:Person) ON (p.department, p.role)

// Full-text index (backed by Lucene)
CREATE FULLTEXT INDEX person_search FOR (p:Person) ON EACH [p.name, p.bio]

// Relationship index (Neo4j 5.7+)
CREATE INDEX knows_since_idx FOR ()-[r:KNOWS]-() ON (r.since)

// Uniqueness constraint (also creates an index)
CREATE CONSTRAINT person_email_unique FOR (p:Person) REQUIRE p.email IS UNIQUE

// Show all indexes
SHOW INDEXES
```

### Performance Tuning

```cypher
// Profile a query (shows actual row counts and db hits)
PROFILE MATCH (p:Person)-[:KNOWS*1..3]-(friend:Person)
WHERE p.name = 'Alice'
RETURN DISTINCT friend.name

// Key metrics to check:
// - "NodeByLabelScan" means no index was used (add an index)
// - High "db hits" relative to rows returned means inefficient traversal
// - "Eager" operator forces materialization (blocks pipelining)
```

Neo4j configuration essentials:
```properties
# Memory configuration (neo4j.conf)
server.memory.heap.initial_size=4g
server.memory.heap.max_size=4g
server.memory.pagecache.size=8g    # Should cover the graph store + indexes

# Transaction limits
db.transaction.timeout=30s
db.transaction.bookmark_ready_timeout=30s
```

## Graph Modeling Principles

### Design for Traversal

The most important question: **What queries will you run?** Model the graph so that the most common queries follow natural traversal paths.

**Good:** Relationship type encodes semantics
```
(alice)-[:MANAGES]->(project)
(alice)-[:CONTRIBUTES_TO]->(project)
```

**Bad:** Generic relationship with type property
```
(alice)-[:RELATED_TO {type: 'manages'}]->(project)
```
Generic relationships prevent the query engine from pruning irrelevant edges early.

### Avoid Supernodes

A supernode is a node with millions of relationships (e.g., a "Country" node connected to every user in that country). Supernodes are performance killers because every traversal through them must examine all relationships.

Mitigation strategies:
- **Fan-out nodes:** Insert intermediate nodes. Instead of `(user)-[:LIVES_IN]->(USA)`, use `(user)-[:LIVES_IN]->(state)-[:IN]->(USA)`.
- **Relationship partitioning:** Use date-bucketed relationships: `(user)-[:PURCHASED_2025_Q1]->(product)`.
- **Dense node handling:** Neo4j Enterprise has internal optimizations for dense nodes, but avoiding them architecturally is better.

### When to Use Properties vs. Relationships

- **Property:** Attributes intrinsic to the node (name, age, status, timestamp).
- **Relationship:** Connections you will traverse in queries. If you never query "find all people in department X," then department can be a property. If you need "find all people in Alice's department," make Department a node with WORKS_IN relationships.

### Modeling Hierarchies

```cypher
// Organizational hierarchy
(ceo:Person)-[:MANAGES]->(vp:Person)-[:MANAGES]->(director:Person)-[:MANAGES]->(manager:Person)

// Find all reports (direct and indirect) under VP
MATCH (vp:Person {name: 'VP Smith'})-[:MANAGES*]->(report:Person)
RETURN report.name, length(shortestPath((vp)-[:MANAGES*]->(report))) AS depth
```

## Common Pitfalls

1. **Using graph for tabular data.** If your "graph" is just tables connected by foreign keys with no deep traversals, an RDBMS with JOINs is simpler and faster.
2. **Modeling everything as a node.** Enum-like values (status, category, type) should usually be node properties, not separate nodes. Only create nodes for values you will traverse through.
3. **Ignoring relationship direction.** Cypher traversal respects direction by default. Model direction based on the natural reading of the relationship: `(person)-[:WORKS_AT]->(company)`, not the reverse.
4. **Loading data one statement at a time.** For bulk loading, use `LOAD CSV`, `neo4j-admin database import`, or the APOC library's batch procedures -- not individual CREATE statements.
5. **Skipping PROFILE/EXPLAIN.** Just like RDBMS, graph query performance depends on index usage and traversal strategy. Always profile slow queries.
6. **Treating Neo4j Community as production-ready for HA.** Community Edition does not support clustering. Enterprise or Aura (cloud) is required for high availability.
