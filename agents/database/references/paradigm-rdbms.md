# Paradigm: Relational Databases (RDBMS)

When and why to choose a relational database. This file covers the paradigm itself, not specific engines -- see technology agents for engine-specific guidance.

## Choose RDBMS When

- **Data is structured and relationships are well-defined.** You have entities with clear relationships (orders have line items, users belong to organizations). The schema is known at design time and changes infrequently.
- **ACID transactions are required.** Financial systems, inventory management, booking systems -- anywhere a partial write is unacceptable. RDBMS guarantees atomicity and consistency that document/key-value stores treat as optional.
- **Complex queries are a core requirement.** Multi-table JOINs, window functions, CTEs, subqueries, aggregations with GROUP BY/HAVING. SQL is the most expressive query language available and RDBMS optimizers handle complex plans well.
- **Referential integrity matters.** Foreign keys, cascading deletes, CHECK constraints. The database enforces business rules that would otherwise leak into every application.
- **Reporting and ad-hoc analysis are needed.** RDBMS supports arbitrary queries against any column combination. NoSQL databases require you to design your schema around known query patterns.
- **Regulatory compliance requires audit trails.** Temporal tables (SQL Server, PostgreSQL, MariaDB) and flashback (Oracle) provide built-in change tracking.

## Avoid RDBMS When

- **Schema changes frequently and unpredictably.** If each record can have different fields and you are iterating rapidly, a document store avoids costly ALTER TABLE operations on large tables.
- **Massive write throughput is the primary concern.** Beyond ~50K writes/sec on a single node, RDBMS becomes the bottleneck. Cassandra, DynamoDB, or ClickHouse handle write-heavy workloads better.
- **Data is naturally a graph.** Social networks, fraud detection, recommendation engines -- when the query is "find all paths between A and B within 5 hops," recursive CTEs in RDBMS are orders of magnitude slower than native graph traversal.
- **Simple key-value access patterns dominate.** If 90% of operations are GET/SET by primary key, a key-value store like Redis or DynamoDB is faster and cheaper.
- **Horizontal scalability is a day-one requirement.** RDBMS scales vertically well but horizontal sharding adds significant complexity. Purpose-built distributed databases (CockroachDB, TiDB, Spanner) handle this natively.

## Technology Comparison

| Feature | SQL Server | PostgreSQL | Oracle | MySQL | MariaDB |
|---|---|---|---|---|---|
| **License** | Commercial (Express: free, 10GB limit) | Open source (PostgreSQL License) | Commercial (XE: free, limited) | Open source (GPL) / Commercial | Open source (GPL / BSL for some) |
| **OS Support** | Windows, Linux (since 2017) | All major platforms | All major platforms | All major platforms | All major platforms |
| **Default Isolation** | READ COMMITTED (locking) | READ COMMITTED (MVCC) | READ COMMITTED (MVCC) | REPEATABLE READ (MVCC + gap locks) | REPEATABLE READ (MVCC + gap locks) |
| **JSON Support** | `JSON_VALUE()`, `OPENJSON()`, no native type | `jsonb` type, GIN indexes, `@>` operator | JSON Duality Views (23ai), `JSON_TABLE()` | `JSON` type, generated columns for indexing | `JSON` type (alias for LONGTEXT) |
| **Partitioning** | Partition functions + schemes | Declarative (RANGE, LIST, HASH) since PG 10 | RANGE, LIST, HASH, composite, interval | RANGE, LIST, HASH, KEY | RANGE, LIST, HASH, KEY, SYSTEM |
| **Replication** | Always On AG, log shipping | Streaming, logical, pglogical | Data Guard, GoldenGate, Active DG | GTID-based, Group Replication | Galera Cluster, standard replication |
| **Full-Text Search** | Built-in (FTS catalogs) | Built-in (`tsvector`, `tsquery`, GIN) | Oracle Text | Built-in (InnoDB FTS) | Built-in (InnoDB/Mroonga) |
| **Extensibility** | CLR procedures, external languages | Extensions (PostGIS, pg_cron, pgvector) | Cartridges, Java stored procs | Plugins (limited) | Plugins, storage engines |
| **Managed Services** | Azure SQL, AWS RDS | AWS RDS/Aurora, Azure, GCP Cloud SQL | Oracle Cloud, AWS RDS | AWS RDS/Aurora, Azure, GCP | AWS RDS, SkySQL |
| **Best For** | .NET ecosystem, BI/reporting, Windows | Complex queries, extensibility, hybrid JSON | Large enterprise, RAC, PL/SQL shops | Simple web apps, read-heavy, MySQL ecosystem | MySQL alternative, ColumnStore analytics |

## When to Pick Which RDBMS

**Choose SQL Server when:**
- The stack is .NET / C# / Windows
- SSRS, SSIS, SSAS (BI stack) integration is needed
- Enterprise support and Microsoft ecosystem alignment matter
- You need temporal tables, graph tables, or in-memory OLTP in one engine

**Choose PostgreSQL when:**
- You need the most standards-compliant, feature-rich open-source RDBMS
- Extensions are critical (PostGIS for geospatial, pgvector for embeddings, TimescaleDB for time-series)
- You need to store and query JSON alongside relational data (JSONB)
- Complex queries with CTEs, window functions, and custom types are common

**Choose Oracle when:**
- The organization has existing Oracle licenses and PL/SQL expertise
- Real Application Clusters (RAC) for active-active clustering is required
- Extreme scale with a single vendor-supported stack is the priority
- Regulatory requirements mandate a specific vendor's support SLA

**Choose MySQL when:**
- The application is a standard web application (LAMP/LEMP stack)
- Read-heavy workloads with simple schemas dominate
- The team has MySQL expertise and the ORM/driver ecosystem is mature
- AWS Aurora MySQL compatibility is desired

**Choose MariaDB when:**
- You want a MySQL-compatible drop-in with added features (ColumnStore, Galera built-in)
- Open-source governance matters (community-driven vs. Oracle-owned MySQL)
- ColumnStore for mixed OLTP/OLAP workloads is needed

## Schema Design Principles

### Primary Keys

- Prefer surrogate keys (`BIGINT IDENTITY` / `BIGSERIAL` / `AUTO_INCREMENT`) for internal tables.
- Use natural keys only when they are immutable and compact (ISO country codes, UUIDs for distributed systems).
- UUIDs as clustered primary keys cause fragmentation in B-tree indexes. Use `uuid_generate_v7()` (PostgreSQL) or `NEWSEQUENTIALID()` (SQL Server) for time-ordered UUIDs.

### Foreign Keys

- Always define foreign keys. The performance cost is minimal (an index lookup on INSERT/UPDATE/DELETE) and the data integrity benefit is enormous.
- Index foreign key columns. Most RDBMS do not auto-create indexes on FK columns (PostgreSQL and MySQL do not; SQL Server does not).
- Use `ON DELETE CASCADE` sparingly -- only when the child has no meaning without the parent.

### Naming Conventions

Consistency matters more than any specific convention. Pick one and enforce it:

```
-- Snake case (PostgreSQL/MySQL convention)
CREATE TABLE order_items (
    order_item_id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(order_id),
    product_id BIGINT NOT NULL REFERENCES products(product_id),
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL
);

-- Pascal case (SQL Server convention)
CREATE TABLE OrderItems (
    OrderItemId BIGINT IDENTITY PRIMARY KEY,
    OrderId BIGINT NOT NULL REFERENCES Orders(OrderId),
    ProductId BIGINT NOT NULL REFERENCES Products(ProductId),
    Quantity INT NOT NULL CHECK (Quantity > 0),
    UnitPrice DECIMAL(10,2) NOT NULL
);
```

### Common Anti-Patterns

1. **EAV (Entity-Attribute-Value) tables.** Use JSONB (PostgreSQL), JSON columns (MySQL/SQL Server), or proper normalization instead.
2. **Soft deletes everywhere.** `is_deleted` columns complicate every query. Use hard deletes with audit tables, or temporal tables for history.
3. **Storing comma-separated values.** Violates 1NF. Use a junction table or an array type (PostgreSQL).
4. **Over-indexing.** Each index slows writes and consumes storage. Index based on actual query patterns, not speculation. Monitor unused indexes: `pg_stat_user_indexes` (PostgreSQL), `sys.dm_db_index_usage_stats` (SQL Server).
5. **SELECT * in production code.** Defeats covering indexes, increases I/O, and breaks when columns are added.
