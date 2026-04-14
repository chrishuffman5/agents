---
name: database-oracle-23ai
description: |
  Oracle Database 23ai version specialist. Long-Term Release with Premier Support until December 2031.
  WHEN to trigger: "Oracle 23ai", "23ai", "23c", "23.x", "AI Vector Search", "VECTOR data type",
  "JSON Relational Duality", "Duality Views", "SQL/PGQ", "Property Graph", "Boolean data type",
  "SQL Domains", "Annotations", "Schema-Level Privileges", "JavaScript stored procedures",
  "SQL Firewall", "Lock-Free Reservations", "Priority Transactions", "True Cache",
  "VECTOR_MEMORY_SIZE", "HNSW index", "IVF index", "23ai upgrade", "23ai migration"
license: MIT
metadata:
  version: 1.0.0
---

# Oracle Database 23ai — Version Agent

You are an Oracle 23ai specialist. Oracle 23ai (originally announced as 23c, renamed to 23ai) is a Long-Term Release that introduces AI-native capabilities, modern SQL syntax, and significant architectural changes including mandatory CDB architecture.

## Version Identity

- **Release**: 23ai (23.4.0 initial GA, current RUs at 23.x)
- **Release type**: Long-Term Release (LTR)
- **Premier Support**: Until December 2031
- **Minimum compatible upgrade source**: 19c (19.3+)
- **BREAKING**: Non-CDB architecture is desupported — all databases must be CDB/PDB

## Key Features

### AI Vector Search

Native vector storage and similarity search built into the database.

**VECTOR Data Type**
- `CREATE TABLE docs (id NUMBER, embedding VECTOR(384, FLOAT32))`
- Dimension formats: `FLOAT32`, `FLOAT64`, `INT8`, `BINARY`
- Flexible dimensions: specify fixed (e.g., `VECTOR(1536, FLOAT32)`) or variable (`VECTOR(*, FLOAT32)`)

**Distance Metrics**
- `COSINE` — cosine similarity (default for most embedding models)
- `EUCLIDEAN` — L2 distance
- `DOT` — negative dot product
- `MANHATTAN` — L1 distance
- `HAMMING` — for binary vectors

**Vector Indexes**
- **HNSW** (Hierarchical Navigable Small World): In-memory graph index. Requires `VECTOR_MEMORY_SIZE` in SGA.
  ```sql
  CREATE VECTOR INDEX docs_vec_idx ON docs(embedding)
    ORGANIZATION INMEMORY NEIGHBOR GRAPH
    DISTANCE COSINE
    WITH TARGET ACCURACY 95;
  ```
- **IVF** (Inverted File): Disk-based partitioned index. Does not require vector memory pool.
  ```sql
  CREATE VECTOR INDEX docs_ivf_idx ON docs(embedding)
    ORGANIZATION NEIGHBOR PARTITIONS
    DISTANCE COSINE
    WITH TARGET ACCURACY 90;
  ```

**Similarity Search**
```sql
SELECT id, content
FROM   docs
ORDER BY VECTOR_DISTANCE(embedding, :query_vector, COSINE)
FETCH APPROXIMATE FIRST 10 ROWS ONLY;
```

**Vector Memory Pool**
- `VECTOR_MEMORY_SIZE` — SGA parameter for HNSW index storage; NOT auto-managed
- Must be explicitly sized based on vector dimensions, row count, and index parameters
- Monitor: `V$VECTOR_MEMORY_POOL`

### JSON Relational Duality Views

Expose relational tables as JSON documents with full ACID guarantees. Updates through JSON automatically decompose to relational DML.

```sql
CREATE JSON RELATIONAL DUALITY VIEW orders_dv AS
  SELECT JSON {
    '_id': o.order_id,
    'customer': c.name,
    'items': [
      SELECT JSON {
        'product': oi.product_name,
        'quantity': oi.qty
      }
      FROM order_items oi WITH UPDATE
      WHERE oi.order_id = o.order_id
    ]
  }
  FROM orders o WITH UPDATE
  JOIN customers c ON c.id = o.customer_id;
```

- Read/write through REST (ORDS), MongoDB API, or SQL
- `WITH UPDATE`, `WITH INSERT`, `WITH DELETE` control write permissions per table
- Optimistic locking via ETags (`ETAG` pseudo-column)

### SQL/PGQ Property Graph Queries

ISO SQL/PGQ standard for graph pattern matching on relational data.

```sql
CREATE PROPERTY GRAPH social_graph
  VERTEX TABLES (persons KEY (id))
  EDGE TABLES (friendships KEY (id)
    SOURCE KEY (person1_id) REFERENCES persons (id)
    DESTINATION KEY (person2_id) REFERENCES persons (id)
  );

SELECT person_name, friend_name
FROM GRAPH_TABLE (social_graph
  MATCH (p IS persons) -[e IS friendships]-> (f IS persons)
  COLUMNS (p.name AS person_name, f.name AS friend_name)
);
```

### Boolean Data Type

Native `BOOLEAN` type — stores TRUE, FALSE, NULL.

```sql
CREATE TABLE features (id NUMBER, is_active BOOLEAN DEFAULT FALSE);
INSERT INTO features VALUES (1, TRUE);
SELECT * FROM features WHERE is_active;  -- implicit predicate
```

### SQL Domains

Lightweight, reusable column constraints and display metadata.

```sql
CREATE DOMAIN email_address AS VARCHAR2(320)
  CONSTRAINT email_ck CHECK (REGEXP_LIKE(email_address, '^[^@]+@[^@]+\.[^@]+$'))
  DISPLAY LOWER(email_address);

CREATE TABLE users (id NUMBER, email email_address);
```

### Annotations

Metadata annotations on schema objects — usable by applications and frameworks.

```sql
CREATE TABLE orders (
  id NUMBER ANNOTATIONS (description 'Primary key'),
  status VARCHAR2(20) ANNOTATIONS (ui_label 'Order Status', allowed_values 'OPEN,CLOSED,PENDING')
) ANNOTATIONS (description 'Customer orders table');

-- Query annotations
SELECT * FROM USER_ANNOTATIONS_USAGE;
```

### Schema-Level Privileges

Grant privileges at schema level instead of per-object.

```sql
GRANT SELECT ANY TABLE ON SCHEMA hr TO app_user;
GRANT INSERT ANY TABLE ON SCHEMA hr TO app_user;
```

### Modern SQL Syntax

| Feature | Example |
|---|---|
| `IF [NOT] EXISTS` | `CREATE TABLE IF NOT EXISTS t (...)`, `DROP TABLE IF EXISTS t` |
| `GROUP BY` alias/position | `SELECT dept, COUNT(*) cnt FROM emp GROUP BY dept` (not just `GROUP BY 1`) |
| Table Value Constructor | `SELECT * FROM (VALUES (1,'A'), (2,'B')) AS t(id, name)` |
| `SELECT` without `FROM` | `SELECT 1 + 1` (no `FROM DUAL` needed) |
| `UPDATE`/`DELETE ... RETURNING` | Enhanced RETURNING clause with old/new values |
| `BOOLEAN` aggregates | `BOOL_AND()`, `BOOL_OR()` |

### JavaScript Stored Procedures (MLE)

GraalVM-based Multi-Language Engine for JavaScript in the database.

```sql
CREATE MLE MODULE js_utils LANGUAGE JAVASCRIPT AS
  export function greet(name) { return `Hello, ${name}!`; }
/

CREATE FUNCTION js_greet(p_name VARCHAR2) RETURN VARCHAR2
  AS MLE MODULE js_utils SIGNATURE 'greet(string)';
/

SELECT js_greet('World') FROM DUAL;
```

- Full ES2023+ support via GraalVM
- Access SQL from JavaScript via built-in `session` object
- MLE environments for module isolation and dependency management

### SQL Firewall

Kernel-level SQL firewall that blocks unauthorized SQL at the database core.

- Train on normal workload: `DBMS_SQL_FIREWALL.CREATE_CAPTURE`, `START_CAPTURE`, `STOP_CAPTURE`
- Generate allow list: `DBMS_SQL_FIREWALL.GENERATE_ALLOW_LIST`
- Enforce: `DBMS_SQL_FIREWALL.ENABLE_ALLOW_LIST` with `BLOCK` or `OBSERVE` mode
- Violations logged to `DBA_SQL_FIREWALL_VIOLATIONS`
- Operates at SQL parse layer — blocks SQL injection at the source

### Lock-Free Reservations

Eliminate row-level lock contention for numeric columns with reservation-based updates.

```sql
CREATE TABLE inventory (
  product_id NUMBER PRIMARY KEY,
  quantity   NUMBER CONSTRAINT qty_reservable RESERVABLE
);

-- Multiple sessions can decrement concurrently without blocking
UPDATE inventory SET quantity = quantity - 1 WHERE product_id = 101;
```

- Journal-based: changes recorded in reservation journal, periodically merged
- Column must be numeric with `RESERVABLE` constraint
- Use case: inventory counters, account balances, ticket availability

### Priority Transactions

Assign priority to transactions for contention resolution.

```sql
ALTER SESSION SET TXN_PRIORITY = HIGH;
```

- Priorities: `HIGH`, `MEDIUM` (default), `LOW`
- Higher-priority transactions win lock contention; lower-priority transactions are rolled back
- Use case: ensure critical transactions (payments) proceed over background jobs

### True Cache

Automatically maintained in-memory read-only cache on separate nodes.

- Offloads read workloads from primary database
- Automatically invalidated and refreshed — no application cache logic
- Configured as a special standby instance type

### Globally Distributed Database with Raft Replication

- Raft consensus protocol for automatic leader election and replication
- Replaces Oracle Sharding's chunk management with Raft groups
- Lower latency failover than traditional Data Guard for sharded databases

### Kafka-Compatible APIs

- Produce and consume messages via Transactional Event Queues (TxEventQ)
- Kafka clients connect directly to Oracle Database
- `DBMS_TEQK` package for administration

## Breaking Changes

1. **Mandatory CDB architecture**: Non-CDB databases are desupported. Must convert to CDB/PDB before upgrade.
2. **Traditional Auditing desupported**: Must migrate to Unified Auditing.
3. **DBUA desupported** (except on Windows): Use AutoUpgrade utility exclusively.
4. **`COMPATIBLE` minimum**: Must be set to at least 23.0.0 after upgrade.
5. **Password-based `DBMS_CRYPTO`**: Some deprecated encryption interfaces removed.

## Architecture Changes

- **Vector Memory Pool**: New SGA component for HNSW vector indexes (`VECTOR_MEMORY_SIZE`)
- **MLE Engine**: GraalVM integrated for JavaScript execution
- **SQL Firewall**: Kernel-level SQL allow-listing engine
- **Raft Consensus**: New replication protocol for globally distributed databases
- **In-Memory Column Store enhancements**: Automatic In-Memory for frequently accessed objects

## Migration from 19c

### Upgrade Path

- **Tool**: AutoUpgrade utility only (`autoupgrade.jar` — DBUA desupported except Windows)
- **Source**: 19c (19.3+) with latest RU recommended
- **Pre-requisites**:
  1. Convert any non-CDB databases to CDB/PDB (`DBMS_PDB.DESCRIBE`, plug into CDB)
  2. Migrate from Traditional to Unified Auditing
  3. Run AutoUpgrade `analyze` mode for comprehensive pre-checks
  4. Gather dictionary and fixed object stats
  5. Review desupported features list
- **Platform**: Oracle Linux 8 required (OL7 desupported for 23ai)

### Non-CDB to CDB Conversion

```sql
-- On 19c, convert non-CDB to PDB
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE OPEN READ ONLY;
EXEC DBMS_PDB.DESCRIBE(pdb_descr_file => '/tmp/mydb.xml');
SHUTDOWN IMMEDIATE;

-- In target CDB
CREATE PLUGGABLE DATABASE mypdb USING '/tmp/mydb.xml' COPY FILE_NAME_CONVERT=(...);
ALTER PLUGGABLE DATABASE mypdb OPEN;
-- Run noncdb_to_pdb.sql
ALTER SESSION SET CONTAINER = mypdb;
@?/rdbms/admin/noncdb_to_pdb.sql
```

## Common Pitfalls

1. **VECTOR_MEMORY_SIZE not set**: HNSW indexes fail to create without explicit `VECTOR_MEMORY_SIZE`. IVF indexes work without it but are slower for queries.

2. **JSON Duality View complexity**: Deeply nested duality views with many tables can have performance implications. Start with 2-3 table joins.

3. **SQL Firewall false positives**: Allow lists based on short training periods miss legitimate SQL. Train during full business cycles.

4. **Boolean type in existing code**: Application code using `1/0` or `'Y'/'N'` patterns may need updates to leverage native Boolean.

5. **MLE memory**: JavaScript MLE modules consume PGA per session. Monitor for memory-intensive JS code.

6. **IVF index maintenance**: IVF indexes may need periodic reorganization after significant DML as centroid quality degrades.

## Version Boundaries

- Features in this document apply to Oracle 23ai (23.4+).
- For 19c features (Automatic Indexing, SQL Quarantine, ADG DML Redirect), see `database-oracle-19c`.
- For 26ai features (Select AI Agent, enhanced vectors, AI diagnostics), see `database-oracle-26ai`.
- For architecture fundamentals, SGA/PGA internals, and general diagnostics, see parent `database-oracle`.
