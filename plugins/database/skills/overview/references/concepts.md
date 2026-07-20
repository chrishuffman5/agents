# Database Foundational Concepts

Deep reference for cross-engine database theory. This file covers concepts that apply across multiple database technologies, with implementation-specific details where engines diverge.

## Transaction Isolation Levels

The SQL standard defines four isolation levels. Every major RDBMS implements them, but the mechanisms and behaviors differ significantly.

### Standard Levels

| Level | Dirty Read | Non-Repeatable Read | Phantom Read | Serialization Anomaly |
|---|---|---|---|---|
| READ UNCOMMITTED | Possible | Possible | Possible | Possible |
| READ COMMITTED | Prevented | Possible | Possible | Possible |
| REPEATABLE READ | Prevented | Prevented | Possible | Possible |
| SERIALIZABLE | Prevented | Prevented | Prevented | Prevented |

### Implementation Differences Across Engines

**PostgreSQL** uses Multi-Version Concurrency Control (MVCC) for all levels:
- READ COMMITTED: Each statement sees a new snapshot. Default level.
- REPEATABLE READ: Single snapshot for the entire transaction. Prevents phantoms (stricter than SQL standard).
- SERIALIZABLE: Uses Serializable Snapshot Isolation (SSI) with predicate locks. Detects serialization anomalies and aborts one transaction. Applications must retry aborted transactions.
- Does not implement READ UNCOMMITTED; maps to READ COMMITTED.
- Set via: `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;`
- Check current: `SHOW transaction_isolation;`

**SQL Server** uses locking by default, with MVCC optional:
- READ UNCOMMITTED: No shared locks acquired. Equivalent to `NOLOCK` hint.
- READ COMMITTED: Default. Two flavors:
  - Locking (default): Shared locks held only during read, released immediately.
  - Snapshot (RCSI): `ALTER DATABASE mydb SET READ_COMMITTED_SNAPSHOT ON;` -- Uses row versioning in tempdb.
- REPEATABLE READ: Shared locks held until end of transaction. Phantoms still possible.
- SERIALIZABLE: Range locks prevent phantoms. Can cause significant blocking.
- SNAPSHOT: Not a SQL standard level. Full MVCC via row versioning. `ALTER DATABASE mydb SET ALLOW_SNAPSHOT_ISOLATION ON;`
- Check current: `SELECT transaction_isolation_level FROM sys.dm_exec_sessions WHERE session_id = @@SPID;`

**MySQL (InnoDB)** uses MVCC with next-key locking:
- READ UNCOMMITTED: Reads the latest version, even uncommitted.
- READ COMMITTED: Each statement gets a fresh snapshot. Gap locks are released after statement.
- REPEATABLE READ: Default. Single snapshot for the transaction. Uses next-key locks (record + gap) for locking reads to prevent phantoms.
- SERIALIZABLE: Implicitly converts all `SELECT` to `SELECT ... LOCK IN SHARE MODE`.
- Set via: `SET TRANSACTION ISOLATION LEVEL READ COMMITTED;` or `SET SESSION tx_isolation = 'READ-COMMITTED';`
- Check current: `SELECT @@transaction_isolation;`

**Oracle** supports only two levels:
- READ COMMITTED: Default. Uses undo segments for consistent reads. No dirty reads ever.
- SERIALIZABLE: Uses snapshot isolation. `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;`
- Oracle never blocks readers for writers or writers for readers (unlike SQL Server's locking mode).
- Does not support READ UNCOMMITTED or REPEATABLE READ as named levels.

### Practical Guidance

For most OLTP workloads, READ COMMITTED is correct. Use REPEATABLE READ or SERIALIZABLE only when:
- The application performs read-then-write patterns where the read result must not change (inventory checks, balance transfers).
- You need to prevent write skew anomalies.
- You are willing to handle serialization failures with retry logic.

## Locking and Concurrency

### Pessimistic Locking

Acquire locks before accessing data. Prevents conflicts but reduces concurrency.

```sql
-- SQL Server / MySQL / PostgreSQL: explicit row locking
SELECT * FROM accounts WHERE id = 42 FOR UPDATE;

-- SQL Server: table hints
SELECT * FROM accounts WITH (UPDLOCK, ROWLOCK) WHERE id = 42;

-- Oracle: SELECT FOR UPDATE with SKIP LOCKED (useful for queue patterns)
SELECT * FROM jobs WHERE status = 'pending' FOR UPDATE SKIP LOCKED FETCH FIRST 1 ROW ONLY;
```

Lock granularities across engines:
- **Row-level**: All major RDBMS support this. InnoDB, PostgreSQL, and Oracle default to row locks.
- **Page-level**: SQL Server may escalate to page locks. `sp_indexoption` controls this.
- **Table-level**: MySQL MyISAM uses table locks only. InnoDB escalates after ~5000 row locks by default (`innodb_lock_escalation` threshold doesn't exist; SQL Server escalates at ~5000 locks configurable via trace flag 1211/1224).
- **Range/Key-range locks**: SQL Server SERIALIZABLE uses these. InnoDB uses next-key locks.

### Optimistic Locking

No locks during read. Detect conflicts at write time using a version column or checksum.

```sql
-- Application-level optimistic locking with version column
UPDATE accounts
SET balance = 950, version = 4
WHERE id = 42 AND version = 3;
-- If 0 rows affected: conflict detected, retry
```

ORMs (Entity Framework, Hibernate, SQLAlchemy) implement this automatically with `@Version` / `rowversion` / `xmin` columns.

### MVCC (Multi-Version Concurrency Control)

Readers see a consistent snapshot without blocking writers. Implementation varies:

| Engine | MVCC Storage | Cleanup Mechanism |
|---|---|---|
| PostgreSQL | Dead tuples in-place (heap) | VACUUM (autovacuum) |
| MySQL InnoDB | Undo tablespace | Purge thread |
| Oracle | Undo segments (rollback segments) | Automatic undo management (AUM) |
| SQL Server (RCSI/Snapshot) | Version store in tempdb | Ghost cleanup task |

**PostgreSQL caveat:** Bloat accumulates if VACUUM cannot keep up. Monitor `pg_stat_user_tables.n_dead_tup` and `last_autovacuum`. Tune `autovacuum_vacuum_scale_factor` (default 0.2 = vacuum when 20% of table is dead).

**SQL Server caveat:** RCSI/Snapshot isolation increases tempdb pressure. Monitor `sys.dm_tran_version_store_space_usage` and ensure tempdb has enough files (1 per logical CPU, up to 8).

## Replication Topologies

### Single-Primary (Primary-Replica)

One node accepts writes; replicas receive changes asynchronously or synchronously.

| Engine | Technology | Sync Options |
|---|---|---|
| PostgreSQL | Streaming replication, logical replication | Async, sync, quorum (`synchronous_standby_names`) |
| SQL Server | Always On Availability Groups, log shipping | Sync commit, async commit |
| MySQL | Binary log replication (GTID-based) | Async, semi-sync (`rpl_semi_sync_master_wait_point`) |
| Oracle | Data Guard (physical/logical standby) | Maximum Protection, Maximum Availability, Maximum Performance |
| MongoDB | Replica Set | `w:majority` for acknowledged writes, `w:1` for fast writes |

### Multi-Primary (Active-Active)

Multiple nodes accept writes. Requires conflict resolution.

| Engine | Technology | Conflict Resolution |
|---|---|---|
| MySQL | Group Replication, NDB Cluster | Certification-based (first committer wins) |
| MariaDB | Galera Cluster | Certification-based, flow control for slow nodes |
| Oracle | RAC (shared storage, not replication) | Shared-disk, cache fusion -- no conflicts by design |
| PostgreSQL | BDR (EDB), Citus | Last-writer-wins, CRDT-based, or application-defined |
| CockroachDB | Built-in (Raft consensus) | Serializable transactions via consensus |

### Consensus-Based

Distributed databases using Raft or Paxos for strong consistency.

- **CockroachDB**: Raft consensus per range. Serializable by default.
- **TiDB**: TiKV storage layer uses Raft. MySQL wire-protocol compatible.
- **etcd**: Raft consensus for key-value configuration store.
- **YugabyteDB**: Raft per tablet. PostgreSQL wire-protocol compatible.

## Partitioning Strategies

### Horizontal Partitioning (Sharding)

Distribute rows across partitions/shards based on a key.

**Range partitioning**: Partition by value ranges. Good for time-series.
```sql
-- PostgreSQL
CREATE TABLE events (id bigint, created_at timestamptz, data jsonb)
PARTITION BY RANGE (created_at);
CREATE TABLE events_2025_q1 PARTITION OF events
    FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');

-- SQL Server
CREATE PARTITION FUNCTION pf_date (datetime2)
    AS RANGE RIGHT FOR VALUES ('2025-01-01', '2025-04-01', '2025-07-01');
```

**Hash partitioning**: Even distribution. Good when no natural range.
```sql
-- PostgreSQL
CREATE TABLE users (id bigint, name text)
PARTITION BY HASH (id);
CREATE TABLE users_p0 PARTITION OF users FOR VALUES WITH (MODULUS 4, REMAINDER 0);

-- MySQL
ALTER TABLE users PARTITION BY HASH(id) PARTITIONS 4;
```

**List partitioning**: Explicit value assignment. Good for categorical data.
```sql
-- Oracle / PostgreSQL
CREATE TABLE orders (id int, region varchar(20), amount decimal)
PARTITION BY LIST (region);
CREATE TABLE orders_na PARTITION OF orders FOR VALUES IN ('US', 'CA', 'MX');
```

### Vertical Partitioning

Split columns across tables. Move infrequently accessed or large columns to separate storage.
```sql
-- Keep hot columns in main table
CREATE TABLE users (id bigint PRIMARY KEY, name varchar(100), email varchar(255), status smallint);
-- Move cold/large columns to extension table
CREATE TABLE user_profiles (user_id bigint PRIMARY KEY REFERENCES users(id), bio text, avatar_url text, preferences jsonb);
```

### Partition Pruning

All engines with native partitioning support partition pruning -- the optimizer eliminates partitions that cannot contain matching rows. Verify pruning is working:
- **PostgreSQL**: `EXPLAIN` shows `-> Seq Scan on events_2025_q1` (only relevant partition)
- **SQL Server**: `SET STATISTICS PROFILE ON;` check `ActualPartitionsAccessed`
- **MySQL**: `EXPLAIN PARTITIONS SELECT ...;` shows which partitions are scanned
- **Oracle**: `EXPLAIN PLAN` shows `PARTITION RANGE SINGLE` or `PARTITION RANGE ITERATOR`

## Data Modeling Patterns

### Star Schema (OLAP / Data Warehousing)

Central fact table surrounded by dimension tables. Optimized for analytical aggregation.

```
           dim_date
              |
dim_product --+-- fact_sales --+-- dim_customer
              |                |
           dim_store       dim_promotion
```

- Fact tables: narrow, many rows, foreign keys to dimensions, additive measures (quantity, amount).
- Dimension tables: wide, fewer rows, descriptive attributes (name, category, address).
- Use surrogate keys (integer) in dimensions, not natural keys.
- Advantages: Simple queries, fast aggregation with bitmap/columnstore indexes.

### Snowflake Schema

Normalized dimensions. `dim_product` splits into `dim_product`, `dim_category`, `dim_brand`.
- Use when dimension tables are large and storage matters.
- Trade-off: More JOINs in queries, but less data redundancy.

### Document Embedding vs. Referencing (MongoDB/Document Stores)

**Embed** when:
- Child data is always accessed with parent (1:1 or 1:few)
- Child data doesn't change independently
- Document size stays under 16 MB (MongoDB limit)
```json
{ "order_id": 1, "items": [{"sku": "A1", "qty": 2}, {"sku": "B3", "qty": 1}] }
```

**Reference** when:
- Child data is shared across parents (many:many)
- Child data changes independently
- Unbounded arrays (1:many with high cardinality)
```json
{ "order_id": 1, "item_ids": [101, 203] }
// Separate collection: { "_id": 101, "sku": "A1", "price": 29.99 }
```

### Graph Modeling (Neo4j / Property Graphs)

Model entities as nodes, relationships as edges. Both can carry properties.

```cypher
// Create nodes
CREATE (alice:Person {name: 'Alice', age: 30})
CREATE (bob:Person {name: 'Bob', age: 25})
CREATE (acme:Company {name: 'Acme Corp'})

// Create relationships
CREATE (alice)-[:WORKS_AT {since: 2020}]->(acme)
CREATE (alice)-[:KNOWS {since: 2018}]->(bob)
CREATE (bob)-[:WORKS_AT {since: 2022}]->(acme)

// Traverse: find colleagues within 2 hops
MATCH (alice:Person {name: 'Alice'})-[:KNOWS*1..2]-(colleague)-[:WORKS_AT]->(company)
RETURN colleague.name, company.name
```

Key modeling principles:
- Relationships are first-class citizens with their own properties.
- Avoid "supernodes" (nodes with millions of relationships) -- they become query bottlenecks.
- Model relationship direction based on the most common traversal pattern.
- Use labels for node types, relationship types for edge semantics.
