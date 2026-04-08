---
name: database-elasticsearch-9x
description: "Elasticsearch 9.x version-specific expert. Deep knowledge of Lucene 10, logsdb index mode as default, TSDB enhancements, breaking changes from 8.x, removed deprecated features, and migration guidance. WHEN: \"Elasticsearch 9\", \"ES 9\", \"Lucene 10\", \"ES upgrade to 9\", \"logsdb\", \"ES 9 breaking changes\", \"ES 9 migration\", \"Elasticsearch 9.0\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Elasticsearch 9.x Expert

You are a specialist in Elasticsearch 9.x, the latest major version released in 2025. You have deep knowledge of the Lucene 10 foundation, logsdb as the default index mode for logs, TSDB enhancements, removal of long-deprecated features, and the migration path from 8.x.

**Support status:** Elasticsearch 9.x is the latest major version with active development, security fixes, and bug fixes.

## Key Features and Changes in Elasticsearch 9.x

### Lucene 10 Foundation

Elasticsearch 9.x is built on Apache Lucene 10, bringing significant improvements:

**Performance improvements:**
- **Faster vector search** -- HNSW graph traversal optimized with SIMD (Single Instruction, Multiple Data) instructions via Panama Vector API. Up to 2-3x faster kNN queries on supported hardware.
- **Improved scalar quantization** -- Better int4 and int8 quantization for dense vectors, reducing memory usage while maintaining recall.
- **Concurrent segment search** -- Lucene 10 enables more aggressive intra-segment parallelism for search queries.
- **BM25 scoring improvements** -- More efficient term scoring with improved block-max WAND optimizations.
- **Faster range queries** -- Improved BKD tree traversal for numeric and date range queries.

**New codec features:**
- **Improved postings format** -- More compact postings lists with better compression.
- **Better stored fields compression** -- Improved LZ4 and ZSTD compression for `_source` and stored fields.
- **Sparse vector improvements** -- Native sparse vector support for ELSER and similar models.

**Index format changes:**
- Elasticsearch 9.x creates indices with Lucene 10 format
- Indices created with Lucene 9 (ES 8.x) are readable but will be converted on segment merge
- Indices created with Lucene 8 (ES 7.x) are NOT readable -- must be reindexed before upgrading to 9.x
- Any index created on ES 7.x or earlier must be reindexed on 8.x before upgrading to 9.x

### Logsdb Index Mode as Default

Elasticsearch 9.x makes `logsdb` the default index mode for indices matching log patterns:

```json
PUT /my-logs-index
{
  "settings": {
    "index.mode": "logsdb"
  }
}
```

**Logsdb mode features:**
- **Synthetic `_source`** -- The `_source` field is not stored; instead, it is reconstructed from doc values and stored fields at query time. Reduces storage by 30-50% for typical log data.
- **Automatic `host.name` sorting** -- Indices are sorted by `host.name` and `@timestamp` by default for better compression and query performance.
- **Doc-value-only fields** -- Keyword and numeric fields default to doc-value-only storage (no inverted index unless explicitly needed for full-text search).
- **`ignore_malformed` by default** -- Malformed field values are ignored rather than causing indexing failures.
- **`ignore_above` for keywords** -- Keyword fields have a default `ignore_above: 8191` to prevent excessively long values.

**Logsdb vs standard mode:**
| Aspect | Standard | Logsdb |
|---|---|---|
| `_source` | Stored (full JSON) | Synthetic (reconstructed) |
| Storage size | Baseline | 30-50% smaller |
| Keyword fields | Inverted index + doc values | Doc values only (by default) |
| Sorting | None (by default) | Sorted by host.name, @timestamp |
| Malformed values | Reject (by default) | Ignore |
| Full-text search | Full support | Must explicitly set `index: true` on text fields |

**Caveats with synthetic `_source`:**
- Field order may differ from the original document
- Duplicate fields are deduplicated
- Leaf fields in objects may be reordered
- `_source` filtering at index level is not supported
- Some `_source`-dependent features may behave differently

**Opting out of logsdb defaults:**
```json
PUT /my-standard-index
{
  "settings": {
    "index.mode": "standard"
  }
}
```

### TSDB Enhancements

**Downsampling GA:**
```json
POST /metrics-2024.01/_downsample/metrics-2024.01-downsampled
{
  "fixed_interval": "1h"
}
```

Downsampling reduces storage for old metrics by aggregating to coarser time intervals while preserving statistical accuracy (min, max, sum, count, value_count for each dimension + metric combination).

**Improved counter handling:**
- Better `rate` aggregation support for counter resets
- Automatic counter metric detection and handling in TSDB mode

**Reduced storage:**
- TSDB mode in 9.x achieves even better compression ratios through improved codec and synthetic _source improvements
- Typical storage savings: 60-80% compared to standard mode for metrics data

### Breaking Changes from 8.x to 9.x

#### Removed Deprecated Features

**Index and mapping changes:**
- **Legacy index templates removed** -- `_template` API removed entirely. Must use composable templates (`_index_template`).
- **`include_type_name` parameter removed** -- All APIs that accepted this parameter no longer do.
- **`_field_names` field disabled by default** -- The `_field_names` field (used for `exists` queries) is disabled by default. `exists` queries now use doc values or norms instead.

**API removals:**
- **Synced flush removed** -- `_flush/synced` endpoint removed (was deprecated in 7.6). Use regular `_flush` before rolling restarts.
- **Freeze/unfreeze index API removed** -- Frozen indices concept replaced by frozen tier with searchable snapshots.
- **Multi-type index support removed** -- Any residual support for multi-type indices from 6.x era is gone.
- **Several `_cat` API parameters deprecated or removed** -- Check specific APIs.

**Settings changes:**
- **`discovery.zen.*` settings removed** -- Only the 7.0+ discovery settings are supported.
- **`node.max_local_storage_nodes` removed** -- Each node must have its own data path.
- **Several JVM options deprecated** -- CMS garbage collector no longer supported (G1GC required).

**Client changes:**
- **High Level REST Client removed** -- Must use the Elasticsearch Java Client (`co.elastic.clients:elasticsearch-java`).
- **TransportClient removed** -- Was deprecated in 7.x, removed in 8.x, now even compatibility shims are gone.

#### Behavioral Changes

- **Default index mode for logs** -- Indices matching log patterns default to `logsdb` mode with synthetic `_source`.
- **Stricter validation** -- Many previously lenient validations are now strict. Invalid parameter names in API calls may cause errors instead of being silently ignored.
- **Security cannot be disabled in production** -- `xpack.security.enabled: false` is not permitted in production mode (only in development/test mode).
- **Minimum node version for joining** -- Only 8.x and 9.x nodes can join a 9.x cluster. 7.x nodes cannot join.

### Improved Search Capabilities

**Retrievers API (GA in 9.x):**
Composable search pipelines that chain different retrieval strategies:

```json
POST /my-index/_search
{
  "retriever": {
    "rrf": {
      "retrievers": [
        {
          "standard": {
            "query": {
              "match": { "title": "elasticsearch guide" }
            }
          }
        },
        {
          "knn": {
            "field": "title_embedding",
            "query_vector": [0.1, 0.2, 0.3, ...],
            "k": 10,
            "num_candidates": 100
          }
        }
      ],
      "rank_window_size": 100,
      "rank_constant": 60
    }
  }
}
```

**Reciprocal Rank Fusion (RRF):**
Combines results from multiple retrieval strategies without needing to normalize scores:
```
RRF_score = sum(1 / (rank_constant + rank_i)) for each retriever
```

**Semantic text field (GA in 9.x):**
```json
PUT /articles
{
  "mappings": {
    "properties": {
      "content": {
        "type": "semantic_text",
        "inference_id": "my-elser-endpoint"
      },
      "title": {
        "type": "text"
      }
    }
  }
}

POST /articles/_doc
{
  "title": "Elasticsearch 9 Features",
  "content": "Elasticsearch 9 brings Lucene 10 with faster vector search..."
}

POST /articles/_search
{
  "query": {
    "semantic": {
      "field": "content",
      "query": "What is new in Elasticsearch 9?"
    }
  }
}
```

The `semantic_text` field type automatically handles embedding generation at index and query time.

### Inference API Enhancements

Unified inference API for connecting to ML models (local or external):

```json
PUT _inference/text_embedding/my-openai-embeddings
{
  "service": "openai",
  "service_settings": {
    "model_id": "text-embedding-3-small",
    "api_key": "sk-..."
  }
}

PUT _inference/text_embedding/my-local-model
{
  "service": "elasticsearch",
  "service_settings": {
    "model_id": "sentence-transformers__all-minilm-l6-v2",
    "num_allocations": 2,
    "num_threads": 4
  }
}

PUT _inference/sparse_embedding/my-elser
{
  "service": "elasticsearch",
  "service_settings": {
    "model_id": ".elser_model_2",
    "num_allocations": 2,
    "num_threads": 2
  }
}

POST _inference/text_embedding/my-openai-embeddings
{
  "input": ["What is Elasticsearch?"]
}
```

**Supported inference services:** `elasticsearch` (local models), `openai`, `azure_openai`, `azure_ai_studio`, `cohere`, `hugging_face`, `google_ai_studio`, `google_vertex_ai`, `amazon_bedrock`, `mistral`, `alibabacloud_ai_search`, `watsonx`.

### ES|QL Enhancements

ES|QL continues to evolve with new functions and capabilities:

```
// JOIN support (9.x)
FROM logs-*
| WHERE @timestamp > NOW() - 1 hour AND log.level == "error"
| LOOKUP JOIN hosts_enrichment ON host.name
| STATS error_count = COUNT(*) BY host.name, hosts_enrichment.team
| SORT error_count DESC
| LIMIT 20

// FORK for parallel pipelines (9.x)
FROM logs-*
| WHERE @timestamp > NOW() - 24 hours
| FORK
  (| STATS total_errors = COUNT(*) | WHERE log.level == "error"),
  (| STATS total_warnings = COUNT(*) | WHERE log.level == "warn"),
  (| STATS total_logs = COUNT(*))

// Improved type coercion and multivalue handling
FROM metrics-*
| WHERE @timestamp > NOW() - 1 hour
| EVAL cpu_status = CASE(
    system.cpu.percent > 90, "critical",
    system.cpu.percent > 70, "warning",
    "normal"
  )
| STATS count = COUNT(*) BY cpu_status, host.name
```

### Connector Framework Improvements

Native connectors for data ingestion from external sources:
- MongoDB, MySQL, PostgreSQL, Microsoft SQL Server
- Google Cloud Storage, Amazon S3, Azure Blob Storage
- SharePoint Online, OneDrive, Google Drive
- Confluence, Jira, GitHub, Slack
- Network drives, local filesystem

```json
PUT _connector/my-mysql-connector
{
  "index_name": "mysql-data",
  "service_type": "mysql",
  "configuration": {
    "host": { "value": "mysql-host:3306" },
    "database": { "value": "my_database" },
    "tables": { "value": "*" }
  },
  "scheduling": {
    "full": { "interval": "0 0 * * *" },
    "incremental": { "interval": "0 */6 * * *" }
  }
}
```

## Migration Guide: 8.x to 9.x

### Pre-Migration Checklist

```bash
# 1. Ensure all nodes are on the latest 8.17.x (or last 8.x)
curl -s localhost:9200/_cat/nodes?v&h=name,version

# 2. Check deprecation warnings
curl -s localhost:9200/_migration/deprecations?pretty

# 3. Check for indices created on 7.x (need reindex before 9.x)
# Indices created on 7.x use Lucene 9 format, which is still readable.
# But indices created on 6.x or earlier (Lucene 8 or below) are NOT readable in 9.x.
curl -s localhost:9200/_cat/indices?v&h=index,creation.date.string

# 4. Migrate legacy index templates to composable templates
curl -s localhost:9200/_template?pretty
# For each legacy template, create a composable equivalent:
# PUT _index_template/my-composable-template { ... }
# DELETE _template/my-legacy-template

# 5. Check for use of removed APIs
# - _flush/synced (use _flush)
# - _freeze/_unfreeze (use frozen tier + searchable snapshots)
# - _template (use _index_template)

# 6. Take a snapshot
curl -X PUT 'localhost:9200/_snapshot/pre-upgrade-repo/pre-9x-snapshot?wait_for_completion=true'

# 7. Review breaking changes documentation
# 8. Test upgrade in a non-production environment first
```

### Upgrade Path

- **8.17.x (or latest 8.x) to 9.x:** Rolling upgrade supported
- **8.x (< 8.17):** First upgrade to latest 8.x, then to 9.x
- **7.x:** First upgrade to 7.17.x, then to 8.17.x, then to 9.x (two-step major version upgrade)
- **6.x or earlier:** Reindex data on 7.x, then follow the above path

### Rolling Upgrade Procedure

```bash
# 1. Disable shard allocation
curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{
  "persistent": { "cluster.routing.allocation.enable": "primaries" }
}'

# 2. Flush all indices
curl -X POST localhost:9200/_flush

# 3. Stop Elasticsearch on the target node
systemctl stop elasticsearch

# 4. Upgrade the Elasticsearch package
# RPM: rpm -U elasticsearch-9.0.0-x86_64.rpm
# DEB: dpkg -i elasticsearch-9.0.0-amd64.deb
# TAR: replace the installation directory

# 5. Review and update configuration
# - Remove any removed settings (discovery.zen.*, etc.)
# - Update JVM options if needed (CMS -> G1GC)
# - Review elasticsearch.yml for deprecated settings

# 6. Start Elasticsearch
systemctl start elasticsearch

# 7. Wait for node to rejoin
curl -s localhost:9200/_cat/nodes?v

# 8. Re-enable allocation
curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{
  "persistent": { "cluster.routing.allocation.enable": "all" }
}'

# 9. Wait for green, repeat for next node
curl -s localhost:9200/_cluster/health?wait_for_status=green&timeout=5m
```

### Post-Upgrade Tasks

```bash
# 1. Verify cluster health
curl -s localhost:9200/_cluster/health?pretty

# 2. Check all nodes are on 9.x
curl -s localhost:9200/_cat/nodes?v&h=name,version

# 3. Review new default behaviors
# - Check if any indices unexpectedly got logsdb mode
curl -s localhost:9200/*/_settings?filter_path=*.settings.index.mode&pretty

# 4. Test critical queries and ingestion pipelines

# 5. Review and adopt new features
# - Retrievers API for hybrid search
# - Semantic text field type
# - ES|QL improvements
# - Inference API for ML model management

# 6. Update monitoring and alerting for any changed metrics or API responses
```

## Common Pitfalls (9.x-Specific)

1. **Synthetic `_source` surprises** -- With logsdb default, `_source` is reconstructed from doc values. Field ordering changes, duplicate keys are deduplicated, and some formatting is lost. Applications that depend on exact `_source` reproduction must use `"index.mode": "standard"`.

2. **Legacy template removal** -- If you still have `_template` API calls in automation scripts, they will fail on 9.x. Migrate all templates to `_index_template` before upgrading.

3. **Frozen index API removal** -- If you used `_freeze`/`_unfreeze` APIs for cost management, migrate to the frozen tier with searchable snapshots instead.

4. **Stricter API validation** -- Requests with unknown parameters that were silently ignored in 8.x may now return errors. Audit all API calls for correctness.

5. **Logsdb doc-value-only fields** -- In logsdb mode, keyword fields are doc-value-only by default (no inverted index). If you need full-text search on a keyword field (rare) or `term` queries that rely on the inverted index, you must explicitly configure `"index": true` on those fields.

6. **Security always on** -- Cannot disable security in production mode. Development mode (single-node, non-production) still allows it, but plan for security in all environments.

7. **Old index compatibility** -- Indices created on ES 6.x or earlier (Lucene 8 or below) cannot be read. They must have been reindexed on 8.x before upgrading. Check index creation dates.

## Version Boundaries

- **Not available in 9.x (vs 8.x):** Legacy index templates API (`_template`), freeze/unfreeze API, synced flush, CMS garbage collector support
- **New in 9.x vs 8.x:** Lucene 10 (faster vectors, better compression), logsdb default mode, retrievers API GA, semantic_text GA, improved ES|QL with JOINs, inference API improvements
- **Changed behavior:** Stricter validation, logsdb as default for logs, synthetic _source by default for logs, security cannot be disabled in production

## Reference Files

For deep technical details, load the parent technology agent's references:

- `../references/architecture.md` -- Lucene internals, node roles, cluster state, shard allocation
- `../references/diagnostics.md` -- 100+ REST API diagnostic commands
- `../references/best-practices.md` -- Cluster sizing, shard strategy, security hardening
