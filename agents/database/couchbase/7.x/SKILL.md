---
name: database-couchbase-7x
description: "Couchbase 7.x version-specific expert. Deep knowledge of scopes and collections, distributed ACID transactions, N1QL enhancements, Magma storage engine, UDF support, improved XDCR, Analytics CBO, change history, and Couchstore-to-Magma migration. WHEN: \"Couchbase 7\", \"Couchbase 7.0\", \"Couchbase 7.1\", \"Couchbase 7.2\", \"Couchbase 7.6\", \"scopes and collections\", \"Couchbase transactions\", \"Magma storage\", \"change history\", \"Couchbase UDF\", \"collection-aware XDCR\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Couchbase 7.x Expert

You are a specialist in Couchbase Server 7.x, covering versions 7.0 through 7.6. You have deep knowledge of the features introduced across this major version line, including scopes and collections, distributed ACID transactions, Magma storage engine, N1QL/SQL++ enhancements, UDF support, and operational improvements.

**Supported versions (as of April 2026):**
- **7.6** -- Supported, full maintenance until March 2027. Latest patch: 7.6.10.
- **7.2** -- Supported, full maintenance until July 2026. Latest patch: 7.2.9.
- **7.0 and 7.1** -- End of life. Upgrade to 7.6 or 8.0.

## Key Features by Minor Version

### Couchbase 7.0 (July 2021) -- Foundation Release

#### Scopes and Collections

Scopes and collections introduced a three-level data hierarchy: bucket > scope > collection. This maps directly to RDBMS concepts: database > schema > table.

```
bucket: "ecommerce"
├── scope: "inventory"
│   ├── collection: "products"
│   ├── collection: "categories"
│   └── collection: "suppliers"
├── scope: "orders"
│   ├── collection: "orders"
│   ├── collection: "line_items"
│   └── collection: "payments"
└── scope: "_default"
    └── collection: "_default"  (backward compatibility)
```

**Creating scopes and collections:**

```bash
# CLI
couchbase-cli collection-manage -c localhost:8091 -u Administrator -p password \
  --bucket ecommerce --create-scope inventory

couchbase-cli collection-manage -c localhost:8091 -u Administrator -p password \
  --bucket ecommerce --create-collection inventory.products --max-ttl 0
```

```sql
-- N1QL (7.6+)
CREATE SCOPE `ecommerce`.inventory;
CREATE COLLECTION `ecommerce`.inventory.products;
CREATE COLLECTION `ecommerce`.inventory.categories;
```

**Limits:**
- Up to 1200 collections per bucket (7.6+; was 1000 in 7.0)
- Up to 1000 scopes per bucket
- Each collection has its own document namespace (same key can exist in different collections)

**Data access with collections:**

```sql
-- N1QL with fully qualified path
SELECT p.name, p.price
FROM `ecommerce`.inventory.products p
WHERE p.category = "electronics";

-- KV operations target a specific collection
-- SDK: bucket.scope("inventory").collection("products").get("prod_123")
```

**Benefits:**
- Logical grouping replaces type-field pattern (`WHERE type = "product"`)
- Per-collection RBAC (grant access to specific collections)
- Per-collection TTL
- Per-collection indexing (no WHERE type filter needed)
- Multi-tenancy via scopes (one scope per tenant)

#### Distributed ACID Transactions

Couchbase 7.0 extended multi-document ACID transactions to N1QL (originally SDK-only in 6.5+):

```sql
-- N1QL transaction
BEGIN WORK;

-- Transfer funds
UPDATE `bank`.accounts.checking SET balance = balance - 500
WHERE account_id = "A001";

UPDATE `bank`.accounts.savings SET balance = balance + 500
WHERE account_id = "A001";

-- Record the transfer
INSERT INTO `bank`.accounts.transfers (KEY UUID(), VALUE {
    "from": "checking",
    "to": "savings",
    "amount": 500,
    "timestamp": NOW_STR(),
    "account_id": "A001"
});

COMMIT WORK;
```

**Transaction semantics:**
- Read Committed isolation within the transaction
- Serialized isolation for writes (CAS-based conflict detection)
- Automatic rollback on error or timeout
- SAVEPOINT support for partial rollback
- Default timeout: 15 seconds (configurable)
- Cross-collection and cross-bucket transactions supported

```sql
-- Savepoint example
BEGIN WORK;
UPDATE bucket.scope.coll1 SET x = 1 WHERE id = "doc1";
SAVEPOINT sp1;
UPDATE bucket.scope.coll2 SET y = 2 WHERE id = "doc2";
-- If this fails, rollback to savepoint
ROLLBACK TO SAVEPOINT sp1;
COMMIT WORK;
```

**SDK transaction example (Java):**

```java
cluster.transactions().run(ctx -> {
    TransactionGetResult doc = ctx.get(collection, "doc_id");
    JsonObject content = doc.contentAsObject();
    content.put("status", "processed");
    ctx.replace(doc, content);
    ctx.insert(auditCollection, "audit_" + UUID.randomUUID(),
        JsonObject.create().put("action", "status_change"));
});
```

#### N1QL Enhancements in 7.0

- **SQL++ standard naming** -- N1QL formally adopts SQL++ standard
- **Window functions** -- ROW_NUMBER(), RANK(), DENSE_RANK(), NTILE(), LAG(), LEAD(), FIRST_VALUE(), LAST_VALUE()
- **Collection-aware queries** -- Fully qualified three-part names
- **User-Defined Functions (UDF)** -- JavaScript and N1QL inline functions

```sql
-- Window function
SELECT name, city,
       ROW_NUMBER() OVER (PARTITION BY city ORDER BY avg_rating DESC) AS rank
FROM `travel-sample`.inventory.hotel;

-- Create a JavaScript UDF
CREATE FUNCTION calculate_discount(price, category) LANGUAGE JAVASCRIPT AS
"function calculate_discount(price, category) {
    var rates = {'electronics': 0.1, 'clothing': 0.2, 'books': 0.05};
    return price * (1 - (rates[category] || 0));
}";

-- Create an inline N1QL UDF
CREATE FUNCTION hotel_count(city_param) {
    SELECT COUNT(*) AS cnt
    FROM `travel-sample`.inventory.hotel
    WHERE city = city_param
};

-- Use UDFs in queries
SELECT name, price, calculate_discount(price, category) AS discounted_price
FROM `ecommerce`.inventory.products;
```

#### Collection-Aware XDCR

XDCR in 7.0 supports scope and collection mapping:

```bash
# Map specific collections for replication
couchbase-cli xdcr-replicate -c localhost:8091 -u Administrator -p password \
  --create \
  --xdcr-cluster-name remote-dc \
  --xdcr-from-bucket source-bucket \
  --xdcr-to-bucket target-bucket \
  --collection-explicit-mapping 1 \
  --collection-mapping-rules '{"inventory.products":"inventory.products","orders.orders":"orders.orders"}'
```

#### Magma Storage Engine (GA)

Magma became generally available in 7.0 (developer preview in 6.5):

```bash
# Create a bucket with Magma storage
couchbase-cli bucket-create -c localhost:8091 -u Administrator -p password \
  --bucket large-data \
  --bucket-type couchbase \
  --bucket-ramsize 1024 \
  --storage-backend magma \
  --bucket-replica 1
```

Key Magma characteristics in 7.x:
- Minimum bucket RAM: 1GB (reduced to 100MB for 128-vBucket Magma in 8.0)
- 1024 vBuckets (same as Couchstore)
- ~1% memory-to-data ratio (vs 10% for Couchstore)
- LZ4 block-level compression
- Incremental, concurrent compaction

### Couchbase 7.1 (May 2022)

#### Magma Improvements

- Reduced write amplification
- Improved compaction efficiency
- Better memory usage under sustained write loads

#### Change History Preview

Preview of document change history tracking for Magma buckets.

#### Platform Updates

- ARM64 (Apple M1) support for development
- Additional Linux distribution support

### Couchbase 7.2 (June 2023) -- Analytics and Storage

#### Time Series Support

```sql
-- Use _TIMESERIES function for time series data
-- Store time series data in compact array format
INSERT INTO `iot`.`data`.`readings` (KEY "sensor_001", VALUE {
    "sensor_id": "sensor_001",
    "readings": _TIMESERIES([
        {"ts": "2025-10-15T10:00:00Z", "temp": 22.5, "humidity": 45},
        {"ts": "2025-10-15T10:01:00Z", "temp": 22.6, "humidity": 44},
        {"ts": "2025-10-15T10:02:00Z", "temp": 22.4, "humidity": 46}
    ])
});

-- Query time series with extraction functions
SELECT sensor_id,
       _TS_RANGE(readings, "2025-10-15T10:00:00Z", "2025-10-15T10:05:00Z") AS recent
FROM `iot`.`data`.`readings`
WHERE sensor_id = "sensor_001";
```

#### Cost-Based Optimizer for Analytics

The Analytics service received a cost-based optimizer for better query plan selection:

```sql
-- Analytics queries automatically benefit from CBO
-- No action needed; optimizer uses statistics from DCP-fed shadow data
SELECT country, COUNT(*) AS hotel_count, AVG(avg_rating)
FROM `travel-sample`.analytics.hotels
GROUP BY country
HAVING COUNT(*) > 10
ORDER BY hotel_count DESC;
```

#### Change History (GA for Magma Buckets)

Document change history records all modifications to documents. Useful for audit trails, regulatory compliance, and temporal queries:

```bash
# Enable change history on a Magma bucket
curl -s -u Administrator:password -X POST \
  http://localhost:8091/pools/default/buckets/my-bucket \
  -d "historyRetentionCollectionDefault=true" \
  -d "historyRetentionBytes=2147483648" \
  -d "historyRetentionSeconds=86400"
```

Properties:
- Available only on Magma-backed buckets
- Configurable retention by bytes or seconds
- Automatic compaction removes records beyond retention
- Exposed via DCP for consumption by Analytics, XDCR, connectors

#### Custom Conflict Resolution for XDCR

Custom conflict resolution via Eventing functions:

```javascript
// Eventing function for custom XDCR conflict resolution
function OnUpdate(doc, meta) {
    // Custom merge logic: keep the document with the higher version counter
    if (doc.version > meta.old_doc_version) {
        // Accept the incoming document
        return;
    }
    // Reject the incoming document (keep existing)
    throw "Rejecting lower version";
}
```

#### Audit Log Pruning

```bash
# Configure audit log pruning (auto-delete old audit logs)
curl -s -u Administrator:password -X POST http://localhost:8091/settings/audit \
  -d '{"auditd_enabled": true, "rotate_interval": 86400, "prune_age": 604800}'
```

### Couchbase 7.6 (March 2024) -- Stability and Migration

#### Couchstore-to-Magma Online Migration

Migrate storage engines without downtime:

```bash
# Migrate one or more Couchstore buckets to Magma (7.6+)
curl -s -u Administrator:password -X PUT \
  "http://localhost:8091/pools/default/buckets/my-bucket" \
  -d "storageBackend=magma"

# Monitor migration progress
curl -s -u Administrator:password http://localhost:8091/pools/default/tasks | \
  python3 -c "import sys,json; [print(t) for t in json.load(sys.stdin) if 'migrate' in str(t).lower()]"
```

#### _system Scope

Each bucket automatically has a `_system` scope containing service-managed collections:
- Used internally by Eventing, XDCR conflict logging, and other services
- Not for user data; managed by Couchbase

#### Enhanced FTS

- Relaxed analyzer requirements for non-analytic queries
- Better handling of missing entries in nested flattened array indexes

#### Security Updates

- Removed TLS 1.0 and TLS 1.1 support
- Password-less bucket access removed (all access requires authentication)

#### Deprecated Features in 7.6

- `cbbackup` and `cbrestore` tools removed (use `cbbackupmgr`)
- Older Linux platforms removed (CentOS 7, Debian 10, RHEL 7)

## Migration Guide: 6.x to 7.x

### Key Migration Steps

```
1. Pre-migration:
   - Verify platform compatibility
   - Back up all data
   - Review deprecated features
   - Test in staging environment

2. Upgrade path:
   - 6.5/6.6 → 7.0 → 7.2 → 7.6 (sequential minor upgrades recommended)
   - Rolling upgrade: one node at a time
   - Delta recovery preferred for faster rebalance

3. Post-migration:
   - Migrate from _default scope/collection to named collections
   - Create collection-specific indexes (replace WHERE type = "X" patterns)
   - Update XDCR to use collection mapping
   - Consider Magma migration for large datasets
   - Update SDK clients to use collection-aware API
```

### Migrating from Type Field to Collections

```sql
-- Before (6.x): Type field pattern
SELECT * FROM `bucket` WHERE type = "hotel" AND city = "Paris";
CREATE INDEX idx_hotel_city ON `bucket`(city) WHERE type = "hotel";

-- After (7.x): Collection pattern
SELECT * FROM `bucket`.inventory.hotel WHERE city = "Paris";
CREATE INDEX idx_hotel_city ON `bucket`.inventory.hotel(city);
-- No type filter needed; collection provides the type distinction
```

### SDK Migration

```python
# Before (6.x SDK): Default collection
bucket = cluster.bucket("travel-sample")
result = bucket.default_collection().get("hotel_123")

# After (7.x SDK): Named collection
bucket = cluster.bucket("travel-sample")
scope = bucket.scope("inventory")
collection = scope.collection("hotel")
result = collection.get("hotel_123")
```

## N1QL Enhancements Across 7.x

### CTE (Common Table Expressions)

```sql
-- Recursive CTE for hierarchical data
WITH RECURSIVE category_tree AS (
    SELECT id, name, parent_id, 1 AS depth
    FROM `ecommerce`.inventory.categories
    WHERE parent_id IS MISSING

    UNION ALL

    SELECT c.id, c.name, c.parent_id, ct.depth + 1
    FROM `ecommerce`.inventory.categories c
    JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT * FROM category_tree ORDER BY depth, name;
```

### MERGE Statement

```sql
-- Upsert pattern using MERGE
MERGE INTO `bucket`.`scope`.`target` t
USING `bucket`.`scope`.`source` s
ON t.id = s.id
WHEN MATCHED THEN UPDATE SET t.value = s.value, t.updated = NOW_STR()
WHEN NOT MATCHED THEN INSERT (KEY s.id, VALUE {"id": s.id, "value": s.value, "created": NOW_STR()});
```

### OFFSET and LIMIT with Expressions

```sql
-- Dynamic pagination
SELECT name, city FROM `travel-sample`.inventory.hotel
ORDER BY name
LIMIT $page_size OFFSET $page_size * ($page_num - 1);
```

### ADVISE and UPDATE STATISTICS

```sql
-- Index advisor
ADVISE SELECT h.name FROM `travel-sample`.inventory.hotel h
WHERE h.city = "San Francisco" AND h.vacancy = true;

-- Update optimizer statistics (7.2+)
UPDATE STATISTICS FOR `travel-sample`.inventory.hotel(city, country);
UPDATE STATISTICS FOR `travel-sample`.inventory.hotel INDEX ALL;
```

## Operational Considerations for 7.x

### Scopes and Collections Impact on Indexes

Each collection requires its own indexes. Migrating from type-field to collections means recreating indexes:

```sql
-- Old: One index with type filter
CREATE INDEX idx_hotel_city ON `bucket`(city) WHERE type = "hotel";

-- New: Index on specific collection (no type filter needed)
CREATE INDEX idx_hotel_city ON `bucket`.inventory.hotel(city);
```

**Index limit:** Up to ~600 indexes per bucket in standard GSI mode.

### Transaction Configuration

```bash
# Set transaction timeout (cluster-wide default)
curl -s -u Administrator:password -X POST http://localhost:8093/admin/settings \
  -d '{"txTimeout":"30s"}'

# Set transaction cleanup window
curl -s -u Administrator:password -X POST http://localhost:8093/admin/settings \
  -d '{"cleanupWindow":"120s"}'

# Monitor active transactions
SELECT * FROM system:transactions;
```

### Collection-Level Security

```bash
# Grant read access to a specific collection
couchbase-cli user-manage -c localhost:8091 -u Administrator -p password \
  --set --rbac-username analyst --rbac-password <pass> \
  --roles "query_select[ecommerce:inventory:products],data_reader[ecommerce:inventory:products]" \
  --auth-domain local
```

## Version Comparison Table

| Feature | 7.0 | 7.1 | 7.2 | 7.6 |
|---|---|---|---|---|
| Scopes and collections | GA | GA | GA | GA (1200 limit) |
| N1QL transactions | GA | GA | GA | GA |
| Magma | GA | Improved | Improved | Online migration |
| Window functions | GA | GA | GA | GA |
| UDFs (JavaScript + N1QL) | GA | GA | GA | GA |
| Collection-aware XDCR | GA | GA | GA | GA |
| Change history | -- | Preview | GA (Magma) | GA |
| Time series | -- | -- | GA | GA |
| Analytics CBO | -- | -- | GA | GA |
| Custom XDCR conflict resolution | -- | -- | GA | GA |
| Couchstore → Magma migration | -- | -- | -- | GA |
| _system scope | -- | -- | -- | GA |
| TLS 1.0/1.1 removed | -- | -- | -- | Yes |
