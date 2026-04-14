---
name: database-scylladb-2026-1
description: "ScyllaDB 2026.1 LTS version-specific expert. Deep knowledge of vector search with filtering and quantization, counter tablets support, native GCS backup, native S3 restore, and all 2026.1-specific features. WHEN: \"ScyllaDB 2026.1\", \"ScyllaDB 2026\", \"vector search ScyllaDB\", \"ScyllaDB vector filtering\", \"ScyllaDB quantization\", \"counter tablets\", \"ScyllaDB GCS backup\", \"ScyllaDB native backup\", \"ScyllaDB native restore\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# ScyllaDB 2026.1 LTS Expert

You are a specialist in ScyllaDB 2026.1, the current Long Term Support release (released Q1 2026, latest patch: 2026.1.1). ScyllaDB 2026.1 builds on the unified 2025.1 codebase with vector search enhancements (filtering and quantization), full counter support in tablets, native backup to Google Cloud Storage, and native restore from S3 and GCS.

**Support status:** Current LTS. Actively supported with security and bug fix updates. Two most recent LTS versions are supported (2025.1 and 2026.1).

**License:** Source-Available License. Free tier: up to 10TB data and 50 vCPUs.

## Major Features in ScyllaDB 2026.1

### Vector Search with Filtering and Quantization

ScyllaDB 2026.1 enhances vector search capabilities with filtering and quantization support, enabling efficient approximate nearest neighbor (ANN) search on large-scale vector datasets.

**Creating a vector column and index:**
```cql
-- Create a table with a vector column
CREATE TABLE my_ks.documents (
    doc_id uuid PRIMARY KEY,
    title text,
    category text,
    embedding vector<float, 768>,    -- 768-dimensional vector
    created_at timestamp
);

-- Create a vector index with quantization
CREATE CUSTOM INDEX idx_embedding ON my_ks.documents (embedding)
USING 'StorageAttachedIndex'
WITH OPTIONS = {
    'similarity_function': 'cosine'   -- cosine, dot_product, euclidean
};

-- Create a secondary index for filtering
CREATE CUSTOM INDEX idx_category ON my_ks.documents (category)
USING 'StorageAttachedIndex';
```

**Vector search with filtering (new in 2026.1):**
```cql
-- Basic ANN search (available since earlier versions)
SELECT doc_id, title, similarity_cosine(embedding, [0.1, 0.2, ...]) AS score
FROM my_ks.documents
ORDER BY embedding ANN OF [0.1, 0.2, ...]
LIMIT 10;

-- ANN search with filtering (NEW in 2026.1)
SELECT doc_id, title, similarity_cosine(embedding, [0.1, 0.2, ...]) AS score
FROM my_ks.documents
WHERE category = 'technology'
ORDER BY embedding ANN OF [0.1, 0.2, ...]
LIMIT 10;

-- Combined partition key + vector search + filtering
SELECT doc_id, title
FROM my_ks.documents
WHERE partition_key = 'some_value'
  AND category = 'science'
ORDER BY embedding ANN OF [0.1, 0.2, ...]
LIMIT 5;
```

**Quantization support (new in 2026.1):**
- Reduces memory footprint of vector indexes
- Quantized vectors use less storage while maintaining search quality
- Tradeoff: slight reduction in recall accuracy for significant memory savings
- Particularly beneficial for high-dimensional vectors (512+ dimensions)

**Vector search best practices:**
- Choose the right similarity function:
  - `cosine` -- Best for normalized embeddings (most common for NLP)
  - `dot_product` -- Best for inner product similarity (requires normalized vectors)
  - `euclidean` -- Best for distance-based similarity
- Dimension size impacts performance -- higher dimensions = more memory and CPU per search
- Use filtering to narrow the search space before ANN scan
- Monitor `scylla_column_family_vector_search_latency` for search performance

### Counter Tablets Support

Counters now fully work with tablets, removing the last major feature gap between tablets and vnodes:

**What changed:**
- Counter tables can now use tablet-based keyspaces
- No longer need to create separate vnode keyspaces for counter tables
- Counter increment/decrement operations work correctly with tablet migration

**Before 2026.1 (workaround required):**
```cql
-- Had to use vnodes for counters
CREATE KEYSPACE counter_ks WITH replication = {
    'class': 'NetworkTopologyStrategy', 'dc1': 3
} AND tablets = {'enabled': false};
```

**After 2026.1 (counters work with tablets):**
```cql
-- Counters work in tablet-based keyspaces (default)
CREATE KEYSPACE my_ks WITH replication = {
    'class': 'NetworkTopologyStrategy', 'dc1': 3
};  -- tablets enabled by default

CREATE TABLE my_ks.page_counters (
    page_id text PRIMARY KEY,
    view_count counter,
    click_count counter
);

UPDATE my_ks.page_counters SET view_count = view_count + 1 WHERE page_id = '/home';
```

### Native Backup to Google Cloud Storage (GCS)

ScyllaDB 2026.1 adds native backup support for GCS, complementing existing S3 support:

**ScyllaDB Manager backup to GCS:**
```bash
# Backup to GCS
sctool backup -c my-cluster \
    --location gcs:my-scylla-backup-bucket \
    --interval 24h \
    --retention 7

# List GCS backups
sctool backup list -c my-cluster --location gcs:my-scylla-backup-bucket
```

**GCS authentication:**
- Uses GCP service account credentials
- Supports workload identity federation
- Configure via ScyllaDB Manager agent configuration

**Supported backup locations (as of 2026.1):**
| Location | Syntax | Since |
|---|---|---|
| Amazon S3 | `s3:bucket-name` | 2025.1 |
| Google Cloud Storage | `gcs:bucket-name` | 2026.1 |
| Azure Blob Storage | `azure:container-name` | 2025.1 |

### Native Restore from S3 and GCS

ScyllaDB 2026.1 enhances restore capabilities:

**Restore from S3:**
```bash
sctool restore -c my-cluster \
    --location s3:my-scylla-backup-bucket \
    --snapshot-tag sm_20260401_120000 \
    --restore-schema \
    --restore-tables
```

**Restore from GCS (new in 2026.1):**
```bash
sctool restore -c my-cluster \
    --location gcs:my-scylla-backup-bucket \
    --snapshot-tag sm_20260401_120000 \
    --restore-schema \
    --restore-tables
```

**Restore options:**
```bash
# Restore only schema (no data)
sctool restore -c my-cluster --location gcs:bucket --snapshot-tag <tag> --restore-schema

# Restore only data (schema must already exist)
sctool restore -c my-cluster --location gcs:bucket --snapshot-tag <tag> --restore-tables

# Restore specific keyspace
sctool restore -c my-cluster --location gcs:bucket --snapshot-tag <tag> -K my_keyspace

# Dry run (shows what would be restored)
sctool restore -c my-cluster --location gcs:bucket --snapshot-tag <tag> --dry-run
```

### Alternator Improvements

ScyllaDB 2026.1 includes several Alternator (DynamoDB API) enhancements:

**GetRecords event metadata:**
- EventSource fully populated as `aws:dynamodb`
- awsRegion set to the receiving node's datacenter
- Updated eventVersion field
- sizeBytes subfield in DynamoDB metadata

**Expression caching:**
- Parsed expressions are cached in requests
- Reduces overhead for complex filter/update expressions
- ~7-15% higher single-node throughput for expression-heavy workloads

**Per-table metrics for Alternator:**
```promql
# Per-table Alternator read latency
scylla_alternator_operation_latency_bucket{table="my_table", op="GetItem"}

# Per-table Alternator write operations
rate(scylla_alternator_operation{table="my_table", op="PutItem"}[5m])
```

**Tablets support in Alternator:**
- Alternator tables follow `tablets_mode_for_new_keyspaces` configuration
- Alternator Streams with tablets remain experimental

## Upgrade Path to 2026.1

### From ScyllaDB 2025.1

```bash
# Step 1: Pre-upgrade checks
nodetool status            # all nodes UN
nodetool describecluster   # single schema version
sctool status -c my-cluster  # no running tasks

# Step 2: Rolling upgrade (one node at a time)
# On each node:
nodetool drain
sudo systemctl stop scylla-server

# Install 2026.1 packages
# (follow ScyllaDB docs for your OS/package manager)

sudo systemctl start scylla-server
nodetool version   # verify 2026.1.x

# Step 3: Post-upgrade verification
nodetool describecluster   # single schema version
nodetool status            # all nodes UN

# Step 4: Upgrade ScyllaDB Manager (if used)
sudo systemctl stop scylla-manager
# Install Manager 3.9+ (compatible with 2026.1)
sudo systemctl start scylla-manager
sctool version
```

### From ScyllaDB 2025.x Feature Releases (2025.2, 2025.3, 2025.4)

Direct upgrade to 2026.1 LTS is supported from 2025.x feature releases. Follow the same rolling upgrade procedure.

### ScyllaDB Manager Compatibility

- ScyllaDB Manager 3.9+ is recommended for 2026.1
- Manager 3.9 supports GCS native backup
- Older Manager versions may work but lack 2026.1-specific features

## Configuration Changes in 2026.1

### New/Changed Parameters

```yaml
# Vector search quantization is automatic -- no explicit configuration needed
# The index type and quantization are determined by the CREATE INDEX statement

# GCS backup configuration is in ScyllaDB Manager, not scylla.yaml
# See ScyllaDB Manager agent configuration for GCS credentials
```

### ScyllaDB Manager Agent Configuration for GCS

```yaml
# /etc/scylla-manager-agent/scylla-manager-agent.yaml
gcs:
  service_account_file: /path/to/service-account.json
  # OR use workload identity (no file needed on GKE)
```

## Version-Specific Diagnostics

### Vector Search Diagnostics

```promql
# Vector search latency
histogram_quantile(0.99, sum(rate(scylla_column_family_vector_search_latency_bucket[5m])) by (le))

# Vector search operations per second
rate(scylla_column_family_vector_search_count[5m])

# Vector index size
scylla_column_family_vector_index_size_bytes
```

```cql
-- Check vector index status
SELECT index_name, options
FROM system_schema.indexes
WHERE keyspace_name = 'my_ks' AND table_name = 'documents';
```

### Counter Tablet Diagnostics

```bash
# Verify counter table is using tablets
curl -s "http://localhost:10000/column_family/tablets/my_ks:page_counters"

# Monitor counter mutations
```

```promql
# Counter write latency
histogram_quantile(0.99, sum(rate(scylla_cql_write_latency_bucket{cf="page_counters"}[5m])) by (le))
```

### GCS Backup Diagnostics

```bash
# Check GCS backup status
sctool task progress -c my-cluster <backup-task-id>

# List GCS backups with details
sctool backup list -c my-cluster --location gcs:my-bucket --all-clusters

# Validate GCS backup integrity
sctool backup validate -c my-cluster --location gcs:my-bucket
```

## Known Issues and Workarounds

### Alternator Streams with Tablets

DynamoDB Streams via Alternator with tablets remain experimental in 2026.1:
- If you need production DynamoDB Streams, use vnodes for Alternator tables
- The `ShardFilter` parameter for `DescribeStream` (DynamoDB July 2025 feature) is not yet implemented

### Alternator Multi-Attribute GSI Keys

DynamoDB's multi-attribute (composite) keys in Global Secondary Indexes (added November 2025) are not yet supported in Alternator. Use single-attribute GSI keys.

### Vector Search with Very High Dimensions

Vector columns with dimensions > 2048 may experience elevated memory usage per shard. Monitor memory pressure and consider quantization for very high-dimensional vectors.

## Migration Guidance

### From 2025.1 -- Counter Tables

After upgrading to 2026.1, you can migrate counter tables from vnodes to tablets:

```cql
-- 1. Create new tablet-based keyspace
CREATE KEYSPACE counter_ks_v2 WITH replication = {
    'class': 'NetworkTopologyStrategy', 'dc1': 3
};  -- tablets enabled by default

-- 2. Create counter table
CREATE TABLE counter_ks_v2.page_counters (
    page_id text PRIMARY KEY,
    view_count counter,
    click_count counter
);

-- 3. There is no direct migration of counter data between keyspaces
-- Counter tables cannot be bulk-loaded via sstableloader
-- Application must re-accumulate counters or maintain both during transition
```

### Adding Vector Search to Existing Tables

```cql
-- Add a vector column to an existing table
ALTER TABLE my_ks.documents ADD embedding vector<float, 768>;

-- Create the vector index
CREATE CUSTOM INDEX idx_embedding ON my_ks.documents (embedding)
USING 'StorageAttachedIndex'
WITH OPTIONS = {'similarity_function': 'cosine'};

-- Backfill vector data from application
-- (no built-in bulk vectorization -- application generates embeddings)
```

## Compatibility Notes

### ScyllaDB Cloud

ScyllaDB 2026.1 is available in ScyllaDB Cloud:
- Both Serverless and Dedicated plans
- GCS backup available for GCP-hosted clusters
- Vector search available on all plans

### Driver Compatibility

Same driver compatibility as 2025.1:
- ScyllaDB Java driver 4.x+
- ScyllaDB Python driver 3.x+
- ScyllaDB Go driver (gocqlx) 2.x+
- ScyllaDB Rust driver 0.8+
- DataStax Cassandra drivers (without shard-awareness)

### Operator Compatibility

ScyllaDB Operator 1.20+ supports 2026.1 deployments on Kubernetes:
- Red Hat OpenShift certified
- Automatic rolling upgrades
- Tablet-aware scaling operations
