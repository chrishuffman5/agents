---
name: database-couchbase-8.0
description: "Couchbase 8.0 version-specific expert. Deep knowledge of Hyperscale Vector indexes, native data at rest encryption (DARE), USING AI for natural language queries, Automatic Workload Repository (AWR), OnDeploy handler, Magma as default storage, dynamic service management, BM25 scoring, conflict logging, user locking, and hybrid authentication. WHEN: \"Couchbase 8\", \"Couchbase 8.0\", \"Hyperscale Vector\", \"Composite Vector Index\", \"USING AI\", \"AWR Couchbase\", \"OnDeploy\", \"128 vBucket\", \"DARE Couchbase\", \"Couchbase vector search\", \"BM25 Couchbase\", \"conflict logging\", \"hybrid authentication\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Couchbase 8.0 Expert

You are a specialist in Couchbase Server 8.0, released October 2025. You have deep knowledge of the 400+ features and changes introduced in this major release, particularly Hyperscale Vector indexes, native encryption at rest, AI-powered query generation, Automatic Workload Repository, and operational improvements.

**Support status:** Actively supported with full maintenance until October 2028. Latest patch: 8.0.1 (March 2026).

## Key Features Introduced in Couchbase 8.0

### Hyperscale Vector Indexes (HVI)

Couchbase 8.0 introduces three types of vector indexes for AI/ML workloads:

#### 1. Hyperscale Vector Index (HVI)

Stored in the Index service. Optimized for massive-scale vector search (billions of vectors):

```sql
-- Create a Hyperscale Vector Index
CREATE VECTOR INDEX idx_product_embeddings
ON `ecommerce`.inventory.products(embedding VECTOR)
WITH {
    "dimension": 1536,
    "distance": "L2",          -- L2 (Euclidean), L2_SQUARED, COSINE, DOT
    "description": "Product description embeddings",
    "similarity": "L2",
    "train_list": 100,
    "scan_nprobes": 10
};

-- Query using Hyperscale Vector Index
SELECT p.name, p.description,
       APPROX_VECTOR_DISTANCE(p.embedding, $query_vector) AS distance
FROM `ecommerce`.inventory.products p
ORDER BY APPROX_VECTOR_DISTANCE(p.embedding, $query_vector)
LIMIT 10;
```

Performance characteristics:
- Billion-scale testing: up to 19,000 QPS with 28ms latency
- Separate storage from data (Index service nodes)
- Independent scaling of vector search capacity

#### 2. Composite Vector Index

Combines a vector column with scalar columns for filtered vector search:

```sql
-- Create a Composite Vector Index with scalar filters
CREATE VECTOR INDEX idx_product_filtered
ON `ecommerce`.inventory.products(embedding VECTOR, category, price)
WITH {
    "dimension": 1536,
    "distance": "COSINE"
};

-- Filtered vector search (pre-filter on scalar columns, then vector search)
SELECT p.name, p.price,
       APPROX_VECTOR_DISTANCE(p.embedding, $query_vector) AS similarity
FROM `ecommerce`.inventory.products p
WHERE p.category = "electronics" AND p.price < 500
ORDER BY APPROX_VECTOR_DISTANCE(p.embedding, $query_vector)
LIMIT 10;
```

#### 3. Search Vector Index

Stored in the Search (FTS) service. Supports hybrid queries combining vector search with text search and geospatial:

```sql
-- Search Vector Index via N1QL SEARCH function
SELECT h.name, h.city,
       SEARCH_SCORE() AS relevance
FROM `travel-sample`.inventory.hotel h
WHERE SEARCH(h, {
    "query": {"match": "ocean view pool"},
    "knn": [{
        "field": "description_embedding",
        "vector": [0.1, 0.2, ...],
        "k": 10
    }],
    "knn_operator": "and"
})
ORDER BY relevance DESC;
```

#### Vector Functions

```sql
-- Calculate exact vector distance
SELECT VECTOR_DISTANCE(v1, v2, "COSINE") AS similarity
FROM ...;

-- Approximate vector distance (uses vector index)
SELECT APPROX_VECTOR_DISTANCE(embedding, $query_vector) AS distance
FROM ...;

-- Check if a value is a vector
SELECT ISVECTOR(embedding) FROM products;

-- Encode/decode vectors
SELECT ENCODE_VECTOR(embedding) AS encoded FROM products;
SELECT DECODE_VECTOR(encoded_blob) AS vector FROM products;

-- Normalize a vector
SELECT VECTOR_NORMALIZE(embedding) AS normalized FROM products;
```

### Native Data At Rest Encryption (DARE)

Enterprise Edition 8.0 provides built-in encryption for data stored on disk:

```bash
# Enable encryption at rest
couchbase-cli setting-encryption -c localhost:8091 -u Administrator -p password \
  --set --data-at-rest-encryption 1

# View encryption status
couchbase-cli setting-encryption -c localhost:8091 -u Administrator -p password --get
```

What is encrypted:
- Bucket data files (Couchstore/Magma)
- Log files
- Audit log files
- Configuration data

Key management:
- Internal key management (default)
- External KMS integration (KMIP-compliant)
- Automatic key rotation support

**Important:** Enabling DARE on an existing cluster requires a rolling restart. Plan accordingly.

### USING AI -- Natural Language Query Generation

```sql
-- Generate SQL++ from natural language
SELECT * FROM USING AI "How many airlines are based in Europe?"
ON `travel-sample`.inventory.airline;

-- More complex natural language prompts
SELECT * FROM USING AI "List the names of all hotels in the same city as an airport"
ON `travel-sample`.inventory.hotel, `travel-sample`.inventory.airport;

-- The system generates and executes the corresponding SQL++ query
-- Requires AI service configuration (API key for LLM)
```

### Automatic Workload Repository (AWR)

AWR automatically captures and maintains performance statistics for trend analysis:

```sql
-- Query AWR data for historical query performance
SELECT * FROM system:awr_query_stats
WHERE timestamp > NOW_STR() - "24h"
ORDER BY total_time DESC
LIMIT 20;

-- AWR captures:
-- Query execution statistics over time
-- Resource utilization trends
-- Top-N queries by various metrics
-- Performance regression detection
```

```bash
# AWR configuration via REST
curl -s -u Administrator:password http://localhost:8093/admin/settings | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps({k:v for k,v in d.items() if 'awr' in k.lower()}, indent=2))"
```

### Magma as Default Storage Engine

In 8.0, new buckets use Magma with 128 vBuckets by default (instead of Couchstore with 1024 vBuckets):

| Property | 128 vBucket Magma (new default) | 1024 vBucket Magma | Couchstore |
|---|---|---|---|
| Min bucket RAM | 100 MiB | 1 GiB | 100 MiB |
| vBuckets | 128 | 1024 | 1024 |
| Memory efficiency | Best (lowest metadata) | Good | Moderate |
| Compaction | Incremental, concurrent | Incremental, concurrent | Full rewrite |

```bash
# Create bucket with explicit 1024-vBucket Magma
couchbase-cli bucket-create -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket --bucket-type couchbase \
  --bucket-ramsize 1024 --storage-backend magma \
  --bucket-durability-min-level none

# Create bucket with Couchstore (explicitly override new default)
couchbase-cli bucket-create -c localhost:8091 -u Administrator -p password \
  --bucket my-cache --bucket-type couchbase \
  --bucket-ramsize 256 --storage-backend couchstore
```

**128 vBucket implications:**
- Fewer vBuckets means less metadata overhead
- Minimum cluster size considerations: with 128 vBuckets and 2 replicas, you need at least 3 nodes to distribute all active + replica vBuckets
- Rebalance moves fewer vBuckets (faster rebalance for small clusters)

### Dynamic Service Management

Add or remove non-Data services from existing nodes without adding/removing nodes:

```bash
# Add Index service to an existing Data-only node
curl -s -u Administrator:password -X POST \
  http://10.0.0.2:8091/node/controller/setupServices \
  -d "services=kv,index"
# Rebalance is automatically triggered

# Remove FTS service from a node
curl -s -u Administrator:password -X POST \
  http://10.0.0.3:8091/node/controller/setupServices \
  -d "services=kv"
# Note: Cannot remove the Data (kv) service from an existing node
```

**Key restriction:** The Data service (kv) cannot be dynamically added or removed. Only non-Data services (Query, Index, Search, Analytics, Eventing, Backup) can be dynamically managed.

### SQL++ Enhancements in 8.0

#### DDL for Users, Groups, and Buckets

```sql
-- Create a user
CREATE USER app_reader IDENTIFIED BY "secure_password"
WITH ROLES query_select ON `ecommerce`, data_reader ON `ecommerce`;

-- Alter a user
ALTER USER app_reader ADD ROLES query_insert ON `ecommerce`;

-- Drop a user
DROP USER app_reader;

-- Create a group
CREATE GROUP analysts WITH ROLES query_select ON `ecommerce`, analytics_reader;

-- Alter a group
ALTER GROUP analysts ADD ROLES query_manage_index ON `ecommerce`;

-- Drop a group
DROP GROUP analysts;

-- Create a bucket via SQL++
CREATE BUCKET `new-bucket` WITH {"ramQuota": 1024, "storageBackend": "magma"};

-- Drop a bucket via SQL++
DROP BUCKET `new-bucket`;
```

#### EVALUATE Function

Execute dynamic SQL++ statements:

```sql
-- Execute a dynamically constructed query
SELECT EVALUATE("SELECT COUNT(*) FROM `" || $bucket || "`.`" || $scope || "`.`" || $coll || "`");

-- Useful for administrative scripts and dynamic reporting
```

#### COMPRESS and UNCOMPRESS Functions

```sql
-- Compress a string value (zlib)
SELECT COMPRESS("This is a long string that benefits from compression") AS compressed;

-- Uncompress
SELECT UNCOMPRESS(compressed_field) AS original FROM my_collection;
```

#### Enhanced Optimizer Hints

```sql
-- Negative hints (prevent specific optimizations)
SELECT /*+ NO_INDEX(h idx_city) */ h.name
FROM `travel-sample`.inventory.hotel h
WHERE h.city = "Paris";

-- No FTS index hint
SELECT /*+ NO_INDEX_FTS(h) */ h.name
FROM `travel-sample`.inventory.hotel h
WHERE SEARCH(h, {"query": {"match": "pool"}});

-- Force nested loop or hash join
SELECT /*+ NO_USE_HASH(a) */ h.name, a.name
FROM `travel-sample`.inventory.hotel h
JOIN `travel-sample`.inventory.airline a ON ...;

-- Hints work with DELETE, UPDATE, MERGE (new in 8.0)
DELETE /*+ USE_INDEX(o idx_old_orders) */ FROM `ecommerce`.orders.orders o
WHERE o.created < "2024-01-01";
```

#### Auto-Update Statistics

Enterprise Edition automatically identifies and refreshes outdated optimizer statistics:

```sql
-- Manual statistics update still available
UPDATE STATISTICS FOR `travel-sample`.inventory.hotel(city, country);

-- Auto-update runs in background; no action needed
-- Check statistics status
SELECT * FROM system:indexes WHERE name = "idx_hotel_city";
-- Look for "stats_timestamp" field
```

#### Auto-Reprepare

Prepared statements automatically update their query plans when GSI metadata changes:

```sql
-- Prepare a statement
PREPARE find_hotels FROM
    SELECT name, city FROM `travel-sample`.inventory.hotel WHERE city = $city;

-- If a new, better index is created:
CREATE INDEX idx_hotel_city_name ON `travel-sample`.inventory.hotel(city, name);

-- The prepared statement automatically reprepares with the new index
-- No manual intervention needed (previously required manual re-prepare)
EXECUTE find_hotels USING {"city": "Paris"};
```

#### XATTR Modifications via SQL++

```sql
-- Read extended attributes
SELECT META(d).xattrs.`_sync` FROM `bucket`.`scope`.`collection` d
WHERE META(d).id = "doc_123";

-- Modify extended attributes (new in 8.0; up to 15 XATTRs per query)
UPDATE `bucket`.`scope`.`collection` d
SET META(d).xattrs.custom_attr = {"source": "migration", "timestamp": NOW_STR()}
WHERE META(d).id = "doc_123";
```

#### Enhanced Query Logging

```bash
# Configure query logging with filters
curl -s -u Administrator:password -X POST http://localhost:8093/admin/settings \
  -d '{
    "completed-threshold": "500ms",
    "completed-limit": 10000,
    "log-level": "info"
  }'

# New in 8.0: Log based on query text or plan values
# Useful for auditing specific query patterns
```

#### System Catalogs (New)

```sql
-- User information
SELECT * FROM system:user_info;

-- Group information
SELECT * FROM system:group_info;

-- Bucket information
SELECT * FROM system:bucket_info;
```

### Search Service Enhancements

#### BM25 Scoring Algorithm

```bash
# Create FTS index with BM25 scoring
curl -s -u Administrator:password -X PUT \
  http://localhost:8094/api/bucket/travel-sample/scope/inventory/index/hotel-search-bm25 \
  -H "Content-Type: application/json" \
  -d '{
    "type": "fulltext-index",
    "params": {
        "doc_config": {"mode": "scope.collection.type_field"},
        "mapping": {"default_mapping": {"enabled": true}},
        "store": {"indexType": "scorch", "scoringModel": "bm25"}
    },
    "sourceType": "gocbcore",
    "sourceName": "travel-sample"
  }'
```

BM25 advantages over tf-idf:
- Better term frequency saturation (diminishing returns for repeated terms)
- Document length normalization
- More relevant results for natural language queries
- Preferred for hybrid text+vector search

#### User-Defined Synonyms

```bash
# Add synonym collection to an FTS index
# Synonyms: "hotel" = "inn", "lodge", "resort"
# Configured in the FTS index definition under "analysis" → "token_maps"
```

#### Custom Document Filters

Replace default type identifiers with custom filters to control which documents enter Search indexes. Provides finer-grained control than collection-level indexing.

#### Partition Selection

```bash
# Query specific partitions (reduce search scope for faster queries)
curl -s -u Administrator:password -X POST \
  http://localhost:8094/api/bucket/travel-sample/scope/inventory/index/hotel-search/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": {"match": "pool", "field": "description"},
    "partition_selection": ["0", "1", "2"],
    "size": 10
  }'
```

### Eventing Service Enhancements

#### OnDeploy Handler

New handler that executes once when a function is deployed or resumed:

```javascript
// OnDeploy runs before any mutations are processed
function OnDeploy() {
    // One-time setup tasks
    log("Function deployed at: " + new Date().toISOString());

    // Initialize lookup tables
    var config = {"retry_count": 3, "timeout_ms": 5000};
    dst_bucket["config::eventing"] = config;

    // Warm up caches
    // Validate external service connectivity
}

function OnUpdate(doc, meta) {
    // Normal mutation processing
    if (doc.status === "pending") {
        doc.processed_at = new Date().toISOString();
        dst_bucket[meta.id] = doc;
    }
}

function OnDelete(meta, options) {
    if (options.expired) {
        log("Document expired: " + meta.id);
    }
}
```

#### Scope-Level Configuration

```bash
# Set enable_curl at scope level (instead of globally)
curl -s -u Administrator:password -X POST \
  http://localhost:8096/api/v1/config \
  -H "Content-Type: application/json" \
  -d '{
    "enable_curl": true,
    "scope": "my-bucket.my-scope"
  }'
```

#### cURL Timeout Control

```javascript
// Set per-request timeout in curl calls
function OnUpdate(doc, meta) {
    var response = curl("POST", external_service, {
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify(doc),
        timeout: 5000  // 5 second timeout (new in 8.0)
    });
    if (response.status === 200) {
        doc.synced = true;
        dst_bucket[meta.id] = doc;
    }
}
```

### XDCR Enhancements

#### Conflict Logging

XDCR now logs concurrent conflicts to a designated collection:

```bash
# Enable conflict logging for an XDCR replication
curl -s -u Administrator:password -X POST \
  "http://localhost:8091/settings/replications/<replication_id>" \
  -d "conflictLoggingEnabled=true" \
  -d "conflictLoggingBucket=audit" \
  -d "conflictLoggingScope=xdcr" \
  -d "conflictLoggingCollection=conflicts"
```

Conflict log entries contain:
- Source and target document versions
- Conflict resolution outcome (which version won)
- Timestamp of conflict detection
- Source and target cluster identifiers

#### Incoming Replication Visibility

```bash
# View replications targeting this cluster (new in 8.0)
curl -s -u Administrator:password \
  http://localhost:8091/pools/default/remoteClusters?direction=incoming | python3 -m json.tool
```

#### xdcrDiffer Utility

```bash
# Compare documents between source and target clusters
# Now included in the Couchbase installation package
/opt/couchbase/bin/xdcrDiffer \
  --source http://source:8091 --source-bucket my-bucket \
  --target http://target:8091 --target-bucket my-bucket \
  --source-username Administrator --source-password password \
  --target-username Administrator --target-password password
```

### Security Enhancements

#### Hybrid Authentication Mode

```bash
# Enable hybrid authentication (certificates AND passwords simultaneously)
couchbase-cli setting-security -c localhost:8091 -u Administrator -p password \
  --set --cluster-encryption-level all \
  --tls-min-version tlsv1.2

# Both mTLS for node-to-node AND certificate-based client auth work alongside password auth
```

#### User Account Locking

```sql
-- Lock a user account (prevent authentication)
ALTER USER app_user SET LOCKED = true;

-- Unlock a user account
ALTER USER app_user SET LOCKED = false;

-- Force password change at next login
ALTER USER app_user SET MUST_CHANGE_PASSWORD = true;
```

```bash
# Via REST API
curl -s -u Administrator:password -X PUT \
  http://localhost:8091/settings/rbac/users/local/app_user \
  -d "locked=true"

# Identify inactive user accounts
curl -s -u Administrator:password http://localhost:8091/settings/rbac/users/local | \
  python3 -c "import sys,json; users=json.load(sys.stdin); \
  [print(u['id'], u.get('last_login','never')) for u in users]"
```

### Data Service Enhancements

#### Configurable Warmup Behavior

```bash
# Set warmup behavior for a bucket
curl -s -u Administrator:password -X POST \
  http://localhost:8091/pools/default/buckets/my-bucket \
  -d "warmupBehavior=background"

# Options:
# "background" (default): bucket available immediately, warmup continues in background
# "blocking": bucket unavailable until warmup completes (ensures full cache)
# "none": skip warmup entirely (for ephemeral or cache-only workloads)
```

#### Filesystem Protection

```bash
# Configure disk usage thresholds
curl -s -u Administrator:password -X POST http://localhost:8091/internalSettings \
  -d "diskUsageThreshold=85"
# Prevents Data Service from filling disk beyond threshold
# Helps avoid recovery issues during disk space emergencies
```

#### Eviction Policy Changes Without Restart

```bash
# Change eviction policy on a running bucket (new in 8.0)
curl -s -u Administrator:password -X POST \
  http://localhost:8091/pools/default/buckets/my-bucket \
  -d "evictionPolicy=fullEviction"
# Previously required bucket restart; now applied dynamically
```

#### Durable Write Flexibility

```bash
# Allow durable writes to proceed without majority during graceful failover
curl -s -u Administrator:password -X POST http://localhost:8091/settings/cluster \
  -d "durableWriteFlexibility=true"
# Use with caution: reduces data loss guarantees during failover scenarios
```

### Backup Service Enhancements

```bash
# Configure retention period for a repository (new in 8.0)
curl -s -u Administrator:password -X POST \
  http://localhost:8097/api/v1/cluster/self/repository/active/my-repo \
  -H "Content-Type: application/json" \
  -d '{"retention_period": "30d"}'

# Automatic pruning of old backups
# Backups older than retention period are automatically deleted
# Dependency tracking prevents deletion of needed incremental base backups
```

### Removed Features in 8.0

| Removed Feature | Replacement |
|---|---|
| Memcached buckets | Ephemeral buckets (no persistence, NRU eviction) |
| Amazon Linux 2 | Amazon Linux 2023 |
| macOS 12 | macOS 15 Sequoia |
| SLES 12 | SLES 15 |
| Ubuntu 20.04 | Ubuntu 22.04/24.04 |
| Windows 10 | Windows Server 2025 |

**Critical migration note:** Clusters cannot upgrade to 8.0 if they contain Memcached buckets. Delete or migrate all Memcached buckets before upgrading.

## Upgrade Guide: 7.x to 8.0

### Pre-Upgrade Checklist

```
1. Verify no Memcached buckets exist:
   couchbase-cli bucket-list -c localhost:8091 -u Administrator -p password
   # Any bucket with type "memcached" must be deleted or replaced with ephemeral

2. Verify platform support (check removed platforms list above)

3. Back up all data:
   cbbackupmgr backup -c http://localhost:8091 -u Administrator -p password \
     --archive /backup/pre-upgrade --repo full-backup

4. Test upgrade in staging environment

5. Review application SDK compatibility:
   # Ensure SDK version supports Couchbase 8.0
   # Java SDK 3.5+, Python SDK 4.2+, .NET SDK 3.5+, Node.js SDK 4.3+, Go SDK 2.8+

6. Plan for storage engine default change:
   # New buckets will default to 128-vBucket Magma
   # Existing buckets retain their storage engine
```

### Upgrade Steps

```bash
# Rolling upgrade (one node at a time)
# 1. Failover node
couchbase-cli failover -c localhost:8091 -u Administrator -p password \
  --server-failover 10.0.0.2:8091

# 2. Upgrade software on the node
# (install 8.0 package)

# 3. Add node back and rebalance
couchbase-cli server-add -c localhost:8091 -u Administrator -p password \
  --server-add 10.0.0.2:8091 \
  --server-add-username Administrator --server-add-password password \
  --services data,index,query

couchbase-cli rebalance -c localhost:8091 -u Administrator -p password

# 4. Repeat for each node
```

### Post-Upgrade Actions

```
1. Enable new features:
   - DARE encryption (if needed)
   - Conflict logging for XDCR
   - AWR for query performance monitoring

2. Consider migrating existing buckets to 128-vBucket Magma:
   - Evaluate if lower memory footprint justifies migration
   - Test with representative workload first

3. Create vector indexes for AI/ML workloads

4. Update monitoring for new metrics:
   - AWR statistics
   - Vector index performance
   - Conflict logging volume
```
