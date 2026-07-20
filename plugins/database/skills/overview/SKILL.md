---
name: overview
description: "Cross-engine database expertise for architecture selection, data modeling, and database comparison across all paradigms (RDBMS, document, key-value, wide-column, graph, time-series, search, columnar/OLAP, cloud warehouses, embedded). Use when the question is technology-agnostic: \"which database\", \"database architecture\", \"SQL vs NoSQL\", \"database comparison\", \"choose a database\", \"data modeling\", \"ACID vs BASE\", \"CAP theorem\", \"database paradigm\", \"relational vs document\", \"normalization\", \"indexing strategy\", \"partition strategy\", \"replication topology\"."
license: MIT
---

# Database Overview

This skill covers cross-paradigm database architecture, data modeling, technology selection, and foundational theory across all database technologies. For deep implementation details on a specific engine, use that technology's own skill instead.

## When to Use This Skill vs. a Technology Skill

**Use this skill when the question is technology-agnostic:**
- "Which database should I use for X?"
- "SQL vs NoSQL for my workload?"
- "How does ACID differ from BASE?"
- "Explain CAP theorem trade-offs"
- "Compare replication strategies across engines"
- "What indexing strategy for this access pattern?"
- "Star schema vs snowflake vs document embedding?"

**Use a technology skill when the question is technology-specific:**
- "My PostgreSQL query is slow" --> the `postgresql` skill
- "SQL Server 2022 Always On setup" --> the `sql-server` skill (see its version-specific guidance for 2022)
- "Oracle 23ai JSON Relational Duality" --> the `oracle` skill (see its version-specific guidance for 23ai)
- "MySQL 8.4 replication lag" --> the `mysql` skill (see its version-specific guidance for 8.4)
- "MariaDB ColumnStore tuning" --> the `mariadb` skill
- "MongoDB sharding strategy" --> the `mongodb` skill
- "Redis cluster mode" --> the `redis` skill
- "Elasticsearch index mapping" --> the `elasticsearch` skill
- "Cassandra compaction falling behind" --> the `cassandra` skill
- "Neo4j Cypher optimization" --> the `neo4j` skill
- "DynamoDB single-table design" --> the `dynamodb` skill
- "Snowflake warehouse sizing" --> the `snowflake` skill
- "ClickHouse MergeTree tuning" --> the `clickhouse` skill
- "DuckDB Parquet analysis" --> the `duckdb` skill

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Technology selection** -- Load `references/paradigm-*.md` for the relevant paradigms
   - **Architecture comparison** -- Use the comparison table below, then load references as needed
   - **Data modeling** -- Load `references/concepts.md` for modeling patterns
   - **Foundational theory** -- Load `references/concepts.md` for isolation levels, locking, CAP, ACID
   - **Technology-specific** -- Use the appropriate technology skill

2. **Gather context** -- What is the workload? Read/write ratio, data shape, consistency requirements, scale, team expertise, budget

3. **Analyze** -- Apply database theory to the specific use case. Never recommend a technology without understanding constraints.

4. **Recommend** -- Provide a ranked recommendation with trade-offs, not a single answer

5. **Qualify** -- State assumptions and conditions under which the recommendation changes

## Cross-Paradigm Fundamentals

### ACID Properties

The guarantees that define traditional RDBMS behavior:

- **Atomicity** -- Transactions are all-or-nothing. Implemented via write-ahead logging (WAL/redo log) and undo logs.
- **Consistency** -- Transactions move the database between valid states. Enforced by constraints (CHECK, FK, UNIQUE, NOT NULL).
- **Isolation** -- Concurrent transactions don't interfere. Implementation varies significantly (see `references/concepts.md` for isolation level details across engines).
- **Durability** -- Committed data survives crashes. Requires fsync to persistent storage, WAL flushing.

### BASE Properties

The alternative model for distributed/NoSQL systems:

- **Basically Available** -- The system guarantees availability (responds to requests) even during partial failures.
- **Soft state** -- The system's state may change over time even without input, due to eventual consistency.
- **Eventually consistent** -- Given enough time without updates, all replicas converge to the same value.

### CAP Theorem

In a network partition, you choose either Consistency or Availability:

| System Type | Partition Behavior | Examples |
|---|---|---|
| CP (Consistency + Partition tolerance) | Rejects writes during partition to maintain consistency | PostgreSQL (synchronous replication), MongoDB (w:majority), etcd |
| AP (Availability + Partition tolerance) | Accepts writes during partition, resolves conflicts later | Cassandra, DynamoDB, CouchDB |
| CA (Consistency + Availability) | Only possible without partitions (single node) | Single-node RDBMS |

**Important nuance:** CAP is about behavior *during* a partition. Most systems are tunable -- MongoDB can behave as CP or AP depending on write concern and read preference settings.

### Indexing Theory

Universal indexing concepts that apply across engines:

| Index Type | Structure | Best For | Engines |
|---|---|---|---|
| B-tree / B+tree | Balanced tree, O(log n) lookup | Range scans, equality, ordering | All RDBMS, MongoDB |
| Hash | Hash table, O(1) lookup | Exact equality only | PostgreSQL, MySQL MEMORY, Redis |
| GIN (Generalized Inverted) | Inverted index | Full-text search, arrays, JSONB | PostgreSQL |
| GiST (Generalized Search Tree) | Balanced tree with custom operators | Geospatial, range types, nearest-neighbor | PostgreSQL |
| Bitmap | Bit array per distinct value | Low-cardinality columns in OLAP | Oracle, PostgreSQL (BitmapScan) |
| Columnstore | Column-oriented storage | Analytical aggregations | SQL Server, MariaDB ColumnStore |
| Covering / Included | B-tree with extra columns | Avoiding key lookups | SQL Server (INCLUDE), PostgreSQL (INCLUDE), MySQL |
| Filtered / Partial | B-tree with WHERE predicate | Sparse data, active-only rows | SQL Server, PostgreSQL |

**Index selection heuristic:** Start with the access pattern. If the query filters on column A, orders by column B, and selects columns C and D, the ideal index is `(A, B) INCLUDE (C, D)`. This is a covering index that satisfies the query without touching the heap/clustered index.

### Normalization vs. Denormalization

| Normal Form | Rule | When to Break It |
|---|---|---|
| 1NF | Atomic values, no repeating groups | Arrays in PostgreSQL/document stores when access is always together |
| 2NF | No partial dependencies on composite keys | Rarely broken |
| 3NF | No transitive dependencies | Reporting tables, materialized views |
| BCNF | Every determinant is a candidate key | Almost never broken intentionally |

**Denormalization triggers:** When JOIN cost dominates query time, when read:write ratio exceeds 100:1, when data changes infrequently. Always denormalize into materialized views or summary tables rather than the base schema when possible.

## Technology Comparison

| Technology | Paradigm | Best For | Licensing | Trade-offs |
|---|---|---|---|---|
| **SQL Server** | RDBMS | Windows/.NET shops, BI/SSRS/SSIS, enterprise | Commercial (Express free) | Expensive at scale, Windows-centric (Linux support improving) |
| **PostgreSQL** | RDBMS + extensible | Complex queries, GIS, JSON hybrid, extensibility | Open source (PostgreSQL License) | Higher memory usage, VACUUM overhead, smaller managed-service ecosystem than MySQL |
| **Oracle** | RDBMS | Large enterprise, RAC clustering, PL/SQL codebases | Commercial (XE free) | Extremely expensive, vendor lock-in, complex licensing |
| **MySQL** | RDBMS | Web applications, read-heavy, simple schemas | Open source (GPL) / Commercial | Weaker optimizer, limited window functions (pre-8.0), no partial indexes |
| **MariaDB** | RDBMS | MySQL alternative, ColumnStore analytics | Open source (GPL) | Diverging from MySQL compatibility, smaller enterprise support ecosystem |
| **MongoDB** | Document | Flexible schemas, rapid prototyping, content management | SSPL / Commercial | Eventual consistency gotchas, storage overhead, query limitations vs SQL |
| **Cosmos DB** | Multi-model | Global distribution, multi-API, tunable consistency | Azure managed | Expensive at scale, partition key design critical, 2MB document limit |
| **DynamoDB** | Key-Value / Document | Serverless, predictable latency at any scale | AWS managed | Vendor lock-in, limited query flexibility, single-table design complexity |
| **Couchbase** | Document + KV | Combined cache + document, mobile sync | Commercial / Community | Smaller ecosystem, operational complexity, memory-intensive |
| **Redis** | Key-Value / Cache | Caching, session store, pub/sub, leaderboards | RSALv2 / SSPLv1 (8.0+) | Single-threaded, data must fit in memory, persistence trade-offs |
| **Memcached** | Key-Value / Cache | Simple caching, multi-threaded high throughput | Open source (BSD) | No persistence, no data structures, no replication built-in |
| **ElastiCache** | Managed Cache | AWS managed Redis/Valkey/Memcached | AWS managed | Vendor lock-in, VPC-only access, limited customization |
| **Elasticsearch** | Search / Analytics | Full-text search, log analytics, observability | Elastic License / SSPL | Not a primary database, eventual consistency, high resource usage |
| **OpenSearch** | Search / Analytics | Search, observability, neural/vector search (AWS-aligned) | Apache 2.0 | Elasticsearch fork, smaller plugin ecosystem |
| **Cassandra** | Wide-Column | Time-series, IoT, massive write throughput | Open source (Apache) | Query-driven modeling required, no ad-hoc queries, operational complexity |
| **ScyllaDB** | Wide-Column | Cassandra-compatible with lower latency (C++) | Source-available | Smaller community, less tooling than Cassandra |
| **Neo4j** | Graph | Social networks, fraud detection, knowledge graphs | GPL / Commercial | Not suited for bulk analytics, limited horizontal scaling |
| **Neptune** | Graph | Managed graph on AWS (Gremlin/SPARQL/openCypher) | AWS managed | Vendor lock-in, no Cypher (openCypher subset), VPC-only |
| **InfluxDB** | Time-Series | Metrics, IoT, monitoring, Telegraf ecosystem | Apache 2.0 (3.x) / MIT (2.x) | Breaking changes between 2.x and 3.x, cardinality limits in 2.x |
| **TimescaleDB** | Time-Series | Time-series on PostgreSQL, full SQL, extensions | Apache 2.0 + Timescale License | Single-node only (multi-node deprecated), PG version coupling |
| **ClickHouse** | Columnar / OLAP | Real-time analytics, log aggregation | Open source (Apache) | Not for OLTP, mutations are expensive, operational complexity |
| **DuckDB** | Embedded OLAP | In-process analytics, Parquet/CSV, data science | MIT | Not for concurrent writes, single-process, no server mode |
| **Apache Druid** | Real-time OLAP | Sub-second analytics on streaming data | Open source (Apache) | Complex architecture, high resource usage, limited JOINs |
| **Snowflake** | Cloud Warehouse | Elastic analytics, data sharing, zero-admin | Commercial (managed) | Expensive at scale, vendor lock-in, credit-based pricing complexity |
| **BigQuery** | Cloud Warehouse | Massive-scale analytics, ML integration | Google managed | Slot contention, eventual consistency for streaming, cost unpredictability |
| **Redshift** | Cloud Warehouse | AWS analytics, Spectrum for data lake queries | AWS managed | Distribution key design critical, VACUUM overhead, concurrency limits |
| **Synapse** | Cloud Warehouse | Azure analytics, Spark integration, Pipelines | Azure managed | Complex pricing, dedicated pool maintenance, Spark/SQL pool gap |
| **Databricks** | Lakehouse | Delta Lake, ML/AI, unified analytics + engineering | Commercial (managed) | Expensive, Spark expertise required, vendor lock-in |
| **SQLite** | Embedded RDBMS | Mobile/desktop, testing, edge computing, single-user | Public domain | Single-writer, no network access, limited concurrency |

## Decision Framework

### Step 1: What is the data shape?

| Data Shape | Strong Candidates | Weak Candidates |
|---|---|---|
| Highly relational (many FKs, JOINs) | PostgreSQL, SQL Server, Oracle, MySQL | MongoDB, Redis, Cassandra, DynamoDB |
| Semi-structured / variable schema | MongoDB, Couchbase, PostgreSQL (JSONB), DynamoDB, Cosmos DB | Oracle, MySQL |
| Key-value pairs | Redis, DynamoDB, Memcached, ElastiCache | Any RDBMS (overkill) |
| Graph / relationships ARE the query | Neo4j, Neptune | RDBMS (recursive CTEs are slow at depth), Cassandra |
| Time-series | TimescaleDB, InfluxDB, Cassandra, ClickHouse, Druid | MongoDB, Neo4j |
| Full-text search dominant | Elasticsearch, OpenSearch, PostgreSQL (tsvector) | MySQL (basic), Redis |
| Real-time analytics / OLAP | ClickHouse, Druid, Snowflake, BigQuery, Redshift | OLTP databases under analytical load |
| Embedded / edge / single-process | SQLite, DuckDB | Any client-server database (overkill) |
| Data lake / lakehouse | Databricks, BigQuery, Snowflake, Redshift Spectrum | Traditional RDBMS |

### Step 2: What are the consistency requirements?

- **Strong consistency required** (financial, inventory) --> RDBMS with synchronous replication, or MongoDB w:majority
- **Eventual consistency acceptable** (social feeds, analytics) --> Cassandra, DynamoDB, Redis
- **Mixed** --> Use RDBMS for transactional core, feed events to eventual-consistency systems for reads

### Step 3: What is the scale?

- **< 1 TB, < 10K QPS** --> Any well-tuned RDBMS handles this comfortably
- **1-10 TB, 10K-100K QPS** --> RDBMS with read replicas, or purpose-built NoSQL
- **> 10 TB, > 100K QPS** --> Sharded RDBMS (Citus, Vitess), Cassandra, DynamoDB, ClickHouse

### Step 4: What does the team know?

This matters more than most architects admit. A PostgreSQL expert team will outperform with PostgreSQL even when MongoDB is theoretically better for the data shape. Factor in:
- Existing operational expertise
- Monitoring and backup tooling already in place
- ORM and driver maturity in the application's language
- Hiring market for the technology

## Technology Routing

Use these technology skills for deep implementation guidance (each has its own `references/versions/<v>.md` for version-specific nuance):

| Request Pattern | Skill |
|---|---|
| **Relational (RDBMS)** | |
| SQL Server questions (T-SQL, SSMS, Always On, SSIS) | `sql-server` |
| PostgreSQL questions (psql, extensions, VACUUM, WAL) | `postgresql` |
| Oracle questions (PL/SQL, RAC, ASM, Data Guard) | `oracle` |
| MySQL questions (InnoDB, replication, MySQL Shell) | `mysql` |
| MariaDB questions (Galera, ColumnStore, Spider) | `mariadb` |
| **Document** | |
| MongoDB questions (MQL, aggregation, sharding, replica sets) | `mongodb` |
| Cosmos DB questions (RU, consistency levels, partition keys) | `cosmosdb` |
| DynamoDB questions (single-table design, GSI, streams) | `dynamodb` |
| Couchbase questions (N1QL, XDCR, Eventing, vBuckets) | `couchbase` |
| **Key-Value / Cache** | |
| Redis questions (data structures, clustering, sentinel) | `redis` |
| Memcached questions (slab allocator, consistent hashing) | `memcached` |
| ElastiCache / MemoryDB questions (managed Redis/Valkey/Memcached) | `elasticache` |
| **Search / Analytics Engine** | |
| Elasticsearch questions (Query DSL, mappings, cluster ops) | `elasticsearch` |
| OpenSearch questions (neural search, ISM, security plugin) | `opensearch` |
| **Wide-Column** | |
| Cassandra questions (CQL, nodetool, compaction, repair) | `cassandra` |
| ScyllaDB questions (shard-per-core, Seastar, Alternator) | `scylladb` |
| **Graph** | |
| Neo4j questions (Cypher, APOC, GDS, graph modeling) | `neo4j` |
| Neptune questions (Gremlin, SPARQL, openCypher, Neptune Analytics) | `neptune` |
| **Time-Series** | |
| InfluxDB questions (Flux, SQL, Telegraf, IOx) | `influxdb` |
| TimescaleDB questions (hypertables, continuous aggregates, compression) | `timescaledb` |
| **Columnar / Analytical** | |
| ClickHouse questions (MergeTree, materialized views, distributed) | `clickhouse` |
| DuckDB questions (embedded OLAP, Parquet, Friendly SQL) | `duckdb` |
| Apache Druid questions (real-time OLAP, segments, ingestion) | `druid` |
| **Cloud Data Warehouses** | |
| Snowflake questions (warehouses, micro-partitions, Cortex) | `snowflake` |
| BigQuery questions (slots, BQML, BigLake, Dremel) | `bigquery` |
| Redshift questions (distribution keys, Spectrum, Serverless) | `redshift` |
| Azure Synapse questions (dedicated/serverless pools, Pipelines) | `synapse` |
| Databricks questions (Delta Lake, Unity Catalog, Photon) | `databricks` |
| **Embedded** | |
| SQLite questions (WAL, FTS5, PRAGMA, embedded use) | `sqlite` |

## Anti-Patterns to Watch For

1. **"MongoDB for everything"** -- Document stores are not general-purpose. If you need JOINs, you need relational.
2. **"PostgreSQL can do it all"** -- PostgreSQL is remarkably versatile, but a purpose-built time-series or graph database will outperform it for specialized workloads at scale.
3. **"NoSQL means no schema"** -- Every database has a schema; document stores just shift schema enforcement to the application. This is a liability, not a feature, unless schema flexibility is a genuine requirement.
4. **"Microservices need separate databases"** -- Database-per-service is a pattern, not a law. Shared databases with schema-per-service is often simpler and sufficient.
5. **"Scale up before scaling out"** -- Actually, this IS usually correct. Vertical scaling is simpler and cheaper until you hit hardware limits. The anti-pattern is premature horizontal scaling.
6. **Polyglot persistence without justification** -- Every additional database technology adds operational overhead (backups, monitoring, upgrades, on-call expertise). Add technologies only when the benefit clearly outweighs the cost.

## Reference Files

Load these for deep foundational knowledge:

- `references/concepts.md` -- Transaction isolation, locking, replication, partitioning, data modeling patterns. Read for "how does X work" or "compare X across engines" questions.
- `references/paradigm-rdbms.md` -- When and why to choose a relational database. Read when the user is evaluating RDBMS options.
- `references/paradigm-document.md` -- When and why to choose a document store. Read when evaluating MongoDB, Couchbase, or similar.
- `references/paradigm-keyvalue.md` -- When and why to choose a key-value store. Read when evaluating Redis, DynamoDB, or similar.
- `references/paradigm-graph.md` -- When and why to choose a graph database. Read when evaluating Neo4j, Neptune, or similar.
