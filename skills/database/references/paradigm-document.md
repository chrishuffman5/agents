# Paradigm: Document Databases

When and why to choose a document store. Covers MongoDB, Couchbase, Amazon DocumentDB, Azure Cosmos DB (Document API), and Firebase Firestore.

## What Defines a Document Database

Document databases store data as self-contained documents, typically JSON (or BSON, MessagePack). Each document can have a different structure. Documents are grouped into collections (analogous to tables), but no schema is enforced by the database itself (schema-on-read, not schema-on-write).

Key differentiators from RDBMS:
- **No JOINs by design.** Related data is embedded within the document or fetched via application-side joins.
- **Flexible schema.** Documents in the same collection can have different fields. Schema validation is optional.
- **Nested structures.** Arrays and sub-documents are first-class, queryable, and indexable.
- **Horizontal scaling.** Sharding is a built-in primitive, not a bolt-on.

## Choose Document Stores When

- **Data is naturally hierarchical.** Product catalogs (each product type has different attributes), content management, user profiles with variable metadata. The document IS the natural unit of retrieval.
- **Schema evolves rapidly.** Early-stage products iterating on data models weekly. Adding a field is zero-cost -- no ALTER TABLE on millions of rows.
- **Read patterns align with documents.** If the application almost always reads and writes an entire entity at once (a user profile, a blog post with comments), embedding avoids JOIN overhead.
- **Horizontal write scaling is needed early.** MongoDB auto-sharding distributes writes across nodes. RDBMS sharding requires significant application changes.
- **Developer velocity matters more than query flexibility.** The data model maps directly to application objects. No ORM impedance mismatch.

## Avoid Document Stores When

- **Data is highly relational.** If you need to JOIN 5 tables to answer common questions, a document store forces you to either denormalize aggressively (data duplication, update anomalies) or perform multiple queries (N+1 problem).
- **Multi-document transactions are frequent.** MongoDB supports multi-document ACID transactions since 4.0, but they carry performance overhead and are not the intended usage pattern. If most operations span multiple collections, use an RDBMS.
- **Ad-hoc analytical queries are common.** "What is the average order value by region by month?" requires the aggregation pipeline in MongoDB, which is less expressive than SQL for complex analytics.
- **Strong consistency across related entities is critical.** Financial ledgers, inventory systems with cross-entity invariants. Document stores optimize for single-document atomicity.
- **Reporting tools expect SQL.** BI tools (Tableau, Power BI, Looker) speak SQL natively. Document stores require connectors or ETL pipelines.

## Technology Comparison

| Feature | MongoDB | Couchbase | Amazon DocumentDB | Cosmos DB (Document) | Firestore |
|---|---|---|---|---|---|
| **Query Language** | MQL (MongoDB Query Language) | N1QL (SQL-like) | MongoDB-compatible API (subset) | SQL-like API | SDK-only (no query language) |
| **Transactions** | Multi-document ACID (4.0+) | Multi-document ACID | Multi-document ACID | Multi-document (within partition) | Batched writes, transactions |
| **Sharding** | Hash, range, zone-based | Auto-sharding (vBuckets) | Managed (transparent) | Partition key-based | Automatic |
| **Consistency** | Tunable (`w`, `r`, `readConcern`) | Strong or eventual per-op | Strong (single-region) | 5 levels (Strong to Eventual) | Strong |
| **Max Document Size** | 16 MB | 20 MB | 16 MB | 2 MB | 1 MB |
| **Indexing** | B-tree, compound, multikey, text, geospatial, wildcard | GSI, full-text (FTS), geospatial | Same as MongoDB subset | Automatic (all fields indexed) | Composite indexes (manual) |
| **Best For** | General document workloads | Caching + document hybrid | MongoDB compatibility on AWS | Multi-model global distribution | Mobile/web real-time sync |

## Document Modeling Patterns

### Embedding (Denormalization)

Place related data inside the parent document. Best for 1:1 and 1:few relationships.

```json
{
  "_id": "order_1001",
  "customer": { "name": "Alice", "email": "alice@example.com" },
  "items": [
    { "sku": "WIDGET-A", "quantity": 2, "price": 19.99 },
    { "sku": "GADGET-B", "quantity": 1, "price": 49.99 }
  ],
  "total": 89.97,
  "status": "shipped",
  "created_at": "2025-03-15T10:30:00Z"
}
```

Trade-offs:
- Single read retrieves everything needed (fast).
- Updating customer email requires updating every order document (update anomaly).
- Document grows with each embedded item (watch the 16 MB limit in MongoDB).

### Referencing (Normalization)

Store IDs and resolve in application code or with `$lookup` (MongoDB's left outer join).

```json
// orders collection
{ "_id": "order_1001", "customer_id": "cust_42", "item_ids": ["item_101", "item_203"] }

// customers collection
{ "_id": "cust_42", "name": "Alice", "email": "alice@example.com" }
```

Trade-offs:
- No update anomalies (customer email is in one place).
- Multiple queries or `$lookup` needed for full order view.
- `$lookup` cannot use sharded collections as the "from" collection (MongoDB limitation).

### Bucket Pattern

Group multiple small documents into a single document. Essential for time-series and IoT.

```json
{
  "sensor_id": "temp_sensor_42",
  "bucket_start": "2025-03-15T10:00:00Z",
  "readings": [
    { "ts": "2025-03-15T10:00:05Z", "value": 22.3 },
    { "ts": "2025-03-15T10:00:10Z", "value": 22.4 }
  ],
  "count": 2,
  "sum": 44.7,
  "min": 22.3,
  "max": 22.4
}
```

Benefits: Fewer documents (less index overhead), pre-computed aggregates, predictable document size.

### Schema Validation (MongoDB)

Optional but recommended for production. Enforces structure at the database level.

```javascript
db.createCollection("orders", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["customer_id", "items", "status", "created_at"],
      properties: {
        customer_id: { bsonType: "string" },
        items: {
          bsonType: "array",
          minItems: 1,
          items: {
            bsonType: "object",
            required: ["sku", "quantity", "price"],
            properties: {
              sku: { bsonType: "string" },
              quantity: { bsonType: "int", minimum: 1 },
              price: { bsonType: "decimal" }
            }
          }
        },
        status: { enum: ["pending", "processing", "shipped", "delivered", "cancelled"] }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});
```

## Indexing in Document Stores

MongoDB indexing essentials:

```javascript
// Compound index (most common)
db.orders.createIndex({ customer_id: 1, created_at: -1 });

// Multikey index (indexes each array element)
db.orders.createIndex({ "items.sku": 1 });

// Partial index (equivalent to filtered index in RDBMS)
db.orders.createIndex(
  { status: 1 },
  { partialFilterExpression: { status: { $in: ["pending", "processing"] } } }
);

// Wildcard index (indexes all fields in a sub-document -- use sparingly)
db.products.createIndex({ "attributes.$**": 1 });

// Text index (full-text search)
db.articles.createIndex({ title: "text", body: "text" });
```

Monitor index usage with `db.collection.aggregate([{$indexStats: {}}])`. Drop indexes with zero `accesses.ops` -- they cost write performance and storage for no benefit.

## Common Pitfalls

1. **Treating MongoDB like an RDBMS.** If you have 15 collections with `$lookup` everywhere, you want a relational database.
2. **Unbounded arrays.** An array that grows without limit will eventually hit the 16 MB document limit and cause increasingly expensive updates. Use the bucket pattern or referencing.
3. **Missing indexes on query fields.** MongoDB performs collection scans without an index, just like a table scan. Run `db.collection.find(...).explain("executionStats")` and check `totalDocsExamined` vs `nReturned`.
4. **Ignoring write concern.** `w:1` (default) acknowledges after primary write. Data can be lost if the primary fails before replication. Use `w:"majority"` for critical data.
5. **Schemaless in production.** "Flexible schema" does not mean "no schema." Without validation, bad data silently enters the database and breaks application code downstream.
