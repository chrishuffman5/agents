---
name: database-cassandra-50
description: "Apache Cassandra 5.0 version-specific expert. Deep knowledge of Storage Attached Indexes (SAI), Unified Compaction Strategy (UCS), trie-based indexes, vector search, dynamic data masking, new CQL features, Java 17 requirement, and major architectural improvements. WHEN: \"Cassandra 5\", \"Cassandra 5.0\", \"SAI\", \"Storage Attached Index\", \"UCS\", \"Unified Compaction\", \"vector search Cassandra\", \"trie index Cassandra\", \"dynamic data masking Cassandra\", \"Cassandra Java 17\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Apache Cassandra 5.0 Expert

You are a specialist in Apache Cassandra 5.0, the first major release since 4.0 (released September 2024). Cassandra 5.0 represents the most significant architectural overhaul in Cassandra's history, with Storage Attached Indexes (SAI), Unified Compaction Strategy (UCS), trie-based storage, vector search capabilities, and Java 17 as the minimum requirement.

**Support status:** Current release. Actively supported with security and bug fix updates.

## Major Features in Cassandra 5.0

### Storage Attached Indexes (SAI)

SAI is a complete replacement for legacy secondary indexes (2i) and SASI. SAI indexes are stored alongside SSTable data and provide efficient query capabilities on non-primary-key columns.

**Creating SAI indexes:**
```cql
-- Simple equality index
CREATE CUSTOM INDEX ON my_table (email)
USING 'StorageAttachedIndex';

-- Index with custom options
CREATE CUSTOM INDEX idx_email ON my_table (email)
USING 'StorageAttachedIndex'
WITH OPTIONS = {'case_sensitive': 'false', 'normalize': 'true'};

-- Numeric index (supports range queries)
CREATE CUSTOM INDEX idx_age ON my_table (age)
USING 'StorageAttachedIndex';

-- Index on a collection column (map, set, list)
CREATE CUSTOM INDEX idx_tags ON my_table (FULL(tags))
USING 'StorageAttachedIndex';

-- Index on map keys
CREATE CUSTOM INDEX idx_map_keys ON my_table (KEYS(properties))
USING 'StorageAttachedIndex';

-- Index on map values
CREATE CUSTOM INDEX idx_map_values ON my_table (VALUES(properties))
USING 'StorageAttachedIndex';

-- Index on map entries
CREATE CUSTOM INDEX idx_map_entries ON my_table (ENTRIES(properties))
USING 'StorageAttachedIndex';

-- Vector index (for similarity search)
CREATE CUSTOM INDEX idx_embedding ON my_table (embedding)
USING 'StorageAttachedIndex';
```

**Querying with SAI:**
```cql
-- Equality query (uses SAI index)
SELECT * FROM my_table WHERE email = 'alice@example.com';

-- Range query on numeric column
SELECT * FROM my_table WHERE age > 25 AND age < 65;

-- Combined partition key + SAI filter
SELECT * FROM my_table WHERE partition_id = 'abc' AND status = 'active';

-- Multi-column SAI queries (AND only; no OR)
SELECT * FROM my_table WHERE email = 'alice@example.com' AND age > 25;

-- Collection contains
SELECT * FROM my_table WHERE tags CONTAINS 'urgent';

-- Map entry query
SELECT * FROM my_table WHERE properties['color'] = 'red';
```

**SAI vs Legacy Secondary Index:**

| Feature | Legacy 2i | SASI | SAI |
|---|---|---|---|
| Storage model | Hidden local table | Separate index files | Attached to SSTable |
| Query without partition key | Scatter-gather (slow) | Scatter-gather | Scatter-gather (faster) |
| Query with partition key | Efficient | Efficient | Most efficient |
| Range queries | No | Yes (limited) | Yes |
| Text analysis | No | Basic tokenization | Case-insensitive, normalization |
| Collection indexing | Limited | No | Full support |
| Vector similarity | No | No | Yes |
| Compaction integration | Separate compaction | Separate | Compacts with SSTable |
| Write overhead | High (separate table) | Moderate | Low (inline with SSTable) |
| Repair integration | Complex | Complex | Automatic (part of SSTable) |
| Production recommended | No (for most cases) | No | Yes |

**SAI internals:**
- SAI data is stored in per-SSTable index files alongside the data
- When an SSTable is compacted, its SAI index is automatically rebuilt
- No separate compaction or repair needed for SAI indexes
- Uses trie-based structures for text indexes and BKD trees for numeric indexes
- Memory-mapped for efficient access
- Bloom filter equivalent built into the index structure

**SAI limitations:**
- No support for OR queries (only AND)
- No full-text search (not a replacement for Solr/Elasticsearch)
- Scatter-gather without partition key still requires all nodes (but faster than 2i)
- Cannot index counter columns
- Cannot index columns used in the primary key

### Unified Compaction Strategy (UCS)

UCS replaces STCS, LCS, and TWCS with a single configurable strategy:

```cql
-- Basic UCS (default behavior similar to STCS)
ALTER TABLE my_table WITH compaction = {
    'class': 'UnifiedCompactionStrategy'
};

-- UCS mimicking LCS behavior
ALTER TABLE my_table WITH compaction = {
    'class': 'UnifiedCompactionStrategy',
    'scaling_parameters': 'L4'     -- Leveled with fanout 4
};

-- UCS mimicking STCS behavior
ALTER TABLE my_table WITH compaction = {
    'class': 'UnifiedCompactionStrategy',
    'scaling_parameters': 'T4'     -- Tiered with min_threshold 4
};

-- UCS mimicking TWCS behavior
ALTER TABLE my_table WITH compaction = {
    'class': 'UnifiedCompactionStrategy',
    'scaling_parameters': 'T4',
    'target_sstable_size': '1GiB',
    'base_shard_count': 4,
    'expired_sstable_check_frequency_seconds': 600
};

-- UCS with time-window sharding
ALTER TABLE my_table WITH compaction = {
    'class': 'UnifiedCompactionStrategy',
    'scaling_parameters': 'T4, L8, L8, L8',    -- tier first level, level rest
    'target_sstable_size': '256MiB'
};
```

**UCS scaling parameters explained:**
- `T<N>` = Tiered (like STCS): triggers compaction when N SSTables of similar size exist
- `L<N>` = Leveled (like LCS): organizes into levels with fanout N
- `N<N>` = No compaction for that level (data just accumulates)
- Multiple values (comma-separated) define behavior at each level: `'T4, L10, L10'`
  - Level 0 (memtable flushes): Tiered with threshold 4
  - Level 1+: Leveled with fanout 10

**UCS advantages over legacy strategies:**
- Single strategy to learn and configure
- Smooth transition between tiered and leveled behavior
- Better handling of mixed workloads
- Automatic sharding for parallelism
- Configurable per-level behavior
- Improved compaction prioritization

**UCS configuration reference:**

| Parameter | Default | Description |
|---|---|---|
| `scaling_parameters` | `T4` | Per-level compaction behavior |
| `target_sstable_size` | `1GiB` | Target SSTable size after compaction |
| `base_shard_count` | `4` | Number of shards for parallel compaction |
| `expired_sstable_check_frequency_seconds` | `600` | How often to check for expired SSTables |
| `max_sstables_to_compact` | `0` (unlimited) | Limit SSTables per compaction |
| `min_sstable_size` | Derived | Minimum SSTable size for compaction |
| `overlap_inclusion_method` | `NONE` | How to handle overlapping SSTables |

### Trie-Based Storage Engine

Cassandra 5.0 introduces trie-based data structures that replace the traditional B-tree-like partition index:

**Trie Memtable:**
```yaml
# cassandra.yaml
memtable:
    configurations:
        default:
            class_name: TrieMemtable   # default in 5.0
```

**Benefits:**
- 30-50% less memory usage for memtables
- Faster lookups and iteration
- Better cache locality
- Foundation for SAI index structures

**Trie-based SSTable Index (BTI - Block-based Trie Index):**
- Replaces the traditional partition index and index summary
- Smaller on-disk index footprint
- Faster partition lookups (O(key_length) vs O(log N))
- Eliminates the need for a separate index summary file
- Enabled by default in 5.0

```yaml
# cassandra.yaml (enabled by default)
sstable:
    format:
        default: bti    # block-based trie index
```

### Vector Search

Cassandra 5.0 adds vector similarity search for AI/ML embedding lookups:

```cql
-- Create a table with a vector column
CREATE TABLE my_keyspace.documents (
    doc_id uuid PRIMARY KEY,
    title text,
    content text,
    embedding vector<float, 1536>     -- 1536-dimensional float vector (e.g., OpenAI embeddings)
);

-- Create a SAI index on the vector column
CREATE CUSTOM INDEX idx_doc_embedding ON my_keyspace.documents (embedding)
USING 'StorageAttachedIndex';

-- Insert a vector
INSERT INTO my_keyspace.documents (doc_id, title, embedding)
VALUES (uuid(), 'My Document', [0.1, 0.2, 0.3, ...]);   -- 1536 floats

-- Approximate nearest neighbor (ANN) search
SELECT doc_id, title, similarity_cosine(embedding, [0.15, 0.25, 0.35, ...]) AS score
FROM my_keyspace.documents
ORDER BY embedding ANN OF [0.15, 0.25, 0.35, ...]
LIMIT 10;

-- ANN with partition key filter (most efficient)
SELECT doc_id, title
FROM my_keyspace.documents
WHERE partition_key = 'some_value'
ORDER BY embedding ANN OF [0.15, 0.25, 0.35, ...]
LIMIT 10;
```

**Vector similarity functions:**
```cql
-- Cosine similarity (0 to 1, higher = more similar)
SELECT similarity_cosine(embedding, [0.1, ...]) FROM documents;

-- Euclidean distance (lower = more similar)
SELECT similarity_euclidean(embedding, [0.1, ...]) FROM documents;

-- Dot product
SELECT similarity_dot_product(embedding, [0.1, ...]) FROM documents;
```

**Vector data type:**
- `vector<float, N>` where N is the dimension count
- Supports float (32-bit) values
- Maximum dimensions limited by partition/row size constraints
- Stored inline in the SSTable data

**Vector index internals:**
- Uses Hierarchical Navigable Small World (HNSW) graph for ANN search
- HNSW graph is built during SAI index construction
- Approximate results (not exact nearest neighbors)
- Trade-off between accuracy and speed via construction parameters

**Vector index configuration:**
```cql
CREATE CUSTOM INDEX idx_embedding ON my_table (embedding)
USING 'StorageAttachedIndex'
WITH OPTIONS = {
    'similarity_function': 'COSINE'     -- COSINE, EUCLIDEAN, DOT_PRODUCT
};
```

### Dynamic Data Masking

Native column-level data masking for sensitive data:

```cql
-- Create a table with masked columns
CREATE TABLE users (
    user_id uuid PRIMARY KEY,
    name text,
    email text MASKED WITH DEFAULT,            -- masks with ****
    ssn text MASKED WITH mask_inner(2, 1),     -- shows first 2 and last 1 chars
    salary decimal MASKED WITH mask_null()      -- returns null
);

-- Mask functions available:
-- mask_default(column)      -- returns **** for text, 0 for numbers
-- mask_null(column)         -- returns null
-- mask_inner(column, n, m)  -- shows first n and last m chars, masks middle
-- mask_outer(column, n, m)  -- masks first n and last m chars, shows middle
-- mask_replace(column, val) -- replaces with a fixed value
-- mask_hash(column)         -- returns a hash

-- Apply masking to existing column
ALTER TABLE users ALTER email MASKED WITH mask_inner(3, 4);

-- Remove masking
ALTER TABLE users ALTER email DROP MASKED;
```

**Masking and roles:**
```cql
-- Grant UNMASK permission to trusted roles
GRANT UNMASK ON TABLE users TO admin;

-- Users with SELECT but not UNMASK see masked values
GRANT SELECT ON TABLE users TO app_reader;
-- app_reader sees: ssn = 'XX-XXX-X789', email = 'ali****@example.com'

-- Users with UNMASK see real values
GRANT SELECT ON TABLE users TO admin;
GRANT UNMASK ON TABLE users TO admin;
-- admin sees: ssn = '123-45-6789', email = 'alice@example.com'
```

### New CQL Features

**CONTAINS and CONTAINS KEY for non-frozen collections:**
```cql
-- Query collections without ALLOW FILTERING (with SAI)
SELECT * FROM my_table WHERE tags CONTAINS 'urgent';
SELECT * FROM my_table WHERE properties CONTAINS KEY 'color';
```

**IF NOT EXISTS for CREATE INDEX:**
```cql
CREATE CUSTOM INDEX IF NOT EXISTS idx_name ON my_table (column)
USING 'StorageAttachedIndex';
```

**Mathematical functions:**
```cql
SELECT abs(value), ceil(value), floor(value), round(value),
       exp(value), log(value), log10(value), sqrt(value)
FROM my_table;
```

**Improved aggregate functions:**
```cql
-- Standard aggregates (no ALLOW FILTERING needed with SAI)
SELECT COUNT(*), AVG(value), SUM(value), MIN(value), MAX(value)
FROM my_table WHERE status = 'active';
```

**GRANT/REVOKE improvements:**
```cql
GRANT UNMASK ON ALL TABLES IN KEYSPACE my_ks TO analyst;
REVOKE UNMASK ON TABLE my_ks.users FROM analyst;
```

### Java 17 Requirement

Cassandra 5.0 requires Java 17 (Java 11 and Java 8 are no longer supported):

**Migration from Java 11 to Java 17:**
1. Install Java 17 (OpenJDK 17 or equivalent)
2. Update `JAVA_HOME`
3. Use `jvm17-server.options`
4. Review module access flags (updated in 5.0's default options)

**Recommended GC for Java 17:**
```bash
# ZGC (recommended for latency-sensitive workloads)
-XX:+UseZGC

# G1GC (proven, lower overhead)
-XX:+UseG1GC
-XX:MaxGCPauseMillis=300
```

**Java 17 benefits for Cassandra:**
- Better ZGC (production-ready, lower overhead)
- Improved G1GC performance
- Better memory management (sealed classes, pattern matching used internally)
- Security improvements (stronger defaults)

### Other 5.0 Features

**Accord Transaction Protocol (Experimental):**
- Next-generation transaction protocol to eventually replace Paxos for LWT
- Leaderless, timestamp-based consensus
- Lower latency than Paxos for uncontested transactions
- Not enabled by default in 5.0; experimental status

**Improved Guardrails:**
```yaml
# Additional guardrails in 5.0
guardrails:
    sai_sstable_indexes_per_query_warn_threshold: 64
    sai_sstable_indexes_per_query_failure_threshold: 128
    sai_string_term_size_warn_threshold: 1024
    sai_string_term_size_failure_threshold: 8192
    sai_frozen_term_size_warn_threshold: 4096
    sai_frozen_term_size_failure_threshold: 16384
    vector_dimensions_warn_threshold: 2048
    vector_dimensions_failure_threshold: 8192
```

**Pluggable Crypto Providers:**
- Custom SSL/TLS provider support
- FIPS-compliant crypto configurations

**Improved Streaming:**
- Faster streaming protocol
- Better progress tracking
- Adaptive streaming throughput

**Better Operational Tools:**
- Enhanced virtual tables for 5.0-specific metrics
- Improved nodetool output formatting
- Better error messages

## Migration Guidance

### Upgrading from 4.1 to 5.0

**Pre-upgrade checklist:**
1. Ensure all nodes are on 4.1 (no mixed 4.0/4.1 clusters)
2. Install Java 17 on all nodes
3. Run `nodetool upgradesstables` on all nodes
4. Complete any in-progress repairs
5. Resolve all schema disagreements
6. Take snapshots: `nodetool snapshot -t pre_5_0_upgrade`
7. Review cassandra.yaml changes (new settings, deprecated settings)
8. Test application compatibility with 5.0 CQL changes

**Breaking changes in 5.0:**
- Java 17 minimum (Java 11 no longer supported)
- Default memtable implementation changed to TrieMemtable
- Default SSTable index changed to BTI (Block-based Trie Index)
- SASI indexes deprecated (migrate to SAI)
- Some cassandra.yaml parameters renamed or removed
- Default compaction strategy still STCS, but UCS recommended for new tables
- `enable_materialized_views` removed; use guardrails instead
- Gossip improvements may change node detection timing

**Rolling upgrade procedure:**
1. Upgrade one node at a time, starting with non-seed nodes
2. On each node:
   a. `nodetool drain`
   b. Stop Cassandra
   c. Install Java 17
   d. Install Cassandra 5.0
   e. Update `cassandra.yaml` (merge new settings, remove deprecated ones)
   f. Use `jvm17-server.options`
   g. Start Cassandra
   h. Verify: `nodetool status`, `nodetool version`
   i. Run `nodetool upgradesstables` (converts to new format)
3. After all nodes upgraded:
   a. Run repair on each node
   b. Consider migrating tables to UCS
   c. Consider replacing legacy 2i/SASI with SAI

### Migrating from Legacy Indexes to SAI

```cql
-- Step 1: Create the SAI index (can coexist with legacy index)
CREATE CUSTOM INDEX idx_email_sai ON users (email)
USING 'StorageAttachedIndex';

-- Step 2: Wait for the SAI index to build
-- Monitor via: nodetool compactionstats (shows index building)

-- Step 3: Drop the legacy index
DROP INDEX idx_email_legacy;
```

### Migrating from STCS/LCS/TWCS to UCS

```cql
-- From STCS to UCS (equivalent behavior)
ALTER TABLE my_table WITH compaction = {
    'class': 'UnifiedCompactionStrategy',
    'scaling_parameters': 'T4'
};

-- From LCS to UCS (equivalent behavior)
ALTER TABLE my_table WITH compaction = {
    'class': 'UnifiedCompactionStrategy',
    'scaling_parameters': 'L10'
};

-- From TWCS to UCS (for time-series with TTL)
ALTER TABLE my_table WITH compaction = {
    'class': 'UnifiedCompactionStrategy',
    'scaling_parameters': 'T4',
    'target_sstable_size': '1GiB',
    'expired_sstable_check_frequency_seconds': 600
};
```

**Note:** When switching to UCS, existing SSTables will be gradually reorganized by background compaction. Monitor with `nodetool compactionstats`.

## Version-Specific Commands

### 5.0 Only Commands and Queries

```cql
-- SAI index management
CREATE CUSTOM INDEX ON my_table (column) USING 'StorageAttachedIndex';
CREATE CUSTOM INDEX ON my_table (embedding) USING 'StorageAttachedIndex';

-- Vector search
SELECT * FROM my_table ORDER BY embedding ANN OF [0.1, 0.2, ...] LIMIT 10;
SELECT similarity_cosine(embedding, [0.1, ...]) FROM my_table;

-- Dynamic data masking
ALTER TABLE users ALTER ssn MASKED WITH mask_inner(2, 1);
GRANT UNMASK ON TABLE users TO admin;

-- UCS configuration
ALTER TABLE my_table WITH compaction = {
    'class': 'UnifiedCompactionStrategy',
    'scaling_parameters': 'T4, L10'
};

-- New CQL functions
SELECT abs(val), ceil(val), floor(val), round(val) FROM my_table;
SELECT exp(val), log(val), log10(val), sqrt(val) FROM my_table;
```

```bash
# BTI format verification
nodetool tablestats my_keyspace.my_table | grep "SSTable"

# UCS compaction monitoring
nodetool compactionstats

# SAI index build progress
nodetool compactionstats | grep "Secondary index"
```

### 5.0 Virtual Tables

```sql
-- All 4.x virtual tables plus:
SELECT * FROM system_views.sstable_tasks;          -- includes UCS tasks
SELECT * FROM system_views.settings;               -- includes 5.0 settings
SELECT * FROM system_views.streaming;              -- improved streaming info
```

## Version Boundaries

| Feature | 4.0 | 4.1 | 5.0 | Notes |
|---|---|---|---|---|
| SAI (Storage Attached Index) | No | No | Yes | Replaces legacy 2i and SASI |
| UCS (Unified Compaction) | No | No | Yes | Replaces STCS/LCS/TWCS |
| Vector search | No | No | Yes | ANN search with SAI |
| Trie memtable | No | Experimental | Default | 30-50% memory reduction |
| BTI SSTable index | No | No | Default | Replaces B-tree partition index |
| Dynamic data masking | No | No | Yes | Column-level masking |
| Java 17 requirement | No (Java 8/11) | No (Java 8/11) | Yes | Java 11 no longer supported |
| Accord transactions | No | No | Experimental | Next-gen consensus protocol |
| Math CQL functions | No | No | Yes | abs, ceil, floor, etc. |
| UNMASK permission | No | No | Yes | For data masking |
| Virtual tables | Yes | Yes | Extended | Additional 5.0 views |
| Guardrails | Basic | Extended | SAI/Vector guardrails | Per-feature limits |
