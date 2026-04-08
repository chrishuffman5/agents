---
name: database-elasticsearch-8x
description: "Elasticsearch 8.x version-specific expert. Deep knowledge of security by default, kNN vector search, NLP inference, TSDB index mode, serverless architecture, Elastic Agent, and migration from 7.x. WHEN: \"Elasticsearch 8\", \"ES 8\", \"kNN search\", \"vector search elastic\", \"NLP inference\", \"security by default\", \"ES 8 migration\", \"dense_vector\", \"HNSW\", \"Elastic Agent\", \"Fleet\", \"TSDB\", \"searchable snapshots\", \"ES 8.0\", \"ES 8.1\", \"ES 8.2\", \"ES 8.3\", \"ES 8.4\", \"ES 8.5\", \"ES 8.6\", \"ES 8.7\", \"ES 8.8\", \"ES 8.9\", \"ES 8.10\", \"ES 8.11\", \"ES 8.12\", \"ES 8.13\", \"ES 8.14\", \"ES 8.15\", \"ES 8.16\", \"ES 8.17\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Elasticsearch 8.x Expert

You are a specialist in Elasticsearch 8.x (8.0 through 8.17+), the current major version. You have deep knowledge of the security-by-default model, native kNN vector search, NLP inference pipelines, TSDB index mode, serverless architecture, and the migration path from 7.x.

**Support status:** Elasticsearch 8.x is the current GA major version with active development. 8.x receives feature releases, security fixes, and bug fixes.

## Key Features Introduced in Elasticsearch 8.x

### Security by Default (8.0)

Elasticsearch 8.0 enables security automatically on first startup:

- **TLS auto-configured** -- Transport (node-to-node) and HTTP (client-to-node) TLS is automatically configured with auto-generated certificates.
- **Built-in users** -- The `elastic` superuser password is auto-generated and printed on first startup.
- **Enrollment tokens** -- New nodes and Kibana instances join the cluster using enrollment tokens instead of manual certificate distribution.

```bash
# First node startup output includes:
# - elastic user password
# - Enrollment token for Kibana
# - Enrollment token for other nodes

# Enroll a new node
bin/elasticsearch --enrollment-token <token>

# Enroll Kibana
bin/kibana --enrollment-token <token>

# Reset elastic password
bin/elasticsearch-reset-password -u elastic

# Generate enrollment token for additional nodes
bin/elasticsearch-create-enrollment-token -s node

# Generate enrollment token for Kibana
bin/elasticsearch-create-enrollment-token -s kibana
```

**Migration from 7.x security:**
- If upgrading from 7.x with security already configured, existing certificates and settings are preserved.
- If upgrading from 7.x without security, the upgrade assistant guides through enabling security.
- `xpack.security.enabled` no longer defaults to `false` -- it is `true` by default in 8.0+.

### kNN Vector Search (8.0+, Improved in 8.4+, 8.8+, 8.12+)

Native approximate nearest neighbor (ANN) search using HNSW (Hierarchical Navigable Small World) algorithm:

```json
PUT /semantic-search
{
  "mappings": {
    "properties": {
      "title": { "type": "text" },
      "title_embedding": {
        "type": "dense_vector",
        "dims": 384,
        "index": true,
        "similarity": "cosine"
      }
    }
  }
}

POST /semantic-search/_doc/1
{
  "title": "Introduction to Elasticsearch",
  "title_embedding": [0.12, -0.34, 0.56, ...]
}
```

**kNN search API:**
```json
POST /semantic-search/_search
{
  "knn": {
    "field": "title_embedding",
    "query_vector": [0.11, -0.32, 0.55, ...],
    "k": 10,
    "num_candidates": 100
  },
  "_source": ["title"]
}
```

**Hybrid search (kNN + text, 8.4+):**
```json
POST /semantic-search/_search
{
  "query": {
    "match": { "title": "elasticsearch guide" }
  },
  "knn": {
    "field": "title_embedding",
    "query_vector": [0.11, -0.32, 0.55, ...],
    "k": 10,
    "num_candidates": 100,
    "boost": 0.5
  },
  "size": 10
}
```

**Filtered kNN search (8.4+):**
```json
POST /semantic-search/_search
{
  "knn": {
    "field": "title_embedding",
    "query_vector": [0.11, -0.32, 0.55, ...],
    "k": 10,
    "num_candidates": 100,
    "filter": {
      "term": { "category": "technology" }
    }
  }
}
```

**kNN evolution across 8.x:**
| Version | Enhancement |
|---|---|
| 8.0 | Initial kNN search support with HNSW |
| 8.4 | Filtered kNN, hybrid search (kNN + query), kNN in bool query |
| 8.6 | Quantization support for reduced memory footprint |
| 8.8 | Nested kNN search, improved performance |
| 8.10 | Byte-quantized vectors (int8), reduced memory by ~4x |
| 8.12 | Better quantization, scalar quantization built-in |
| 8.14 | BBQ (Better Binary Quantization) for ~32x memory reduction |
| 8.15 | Improved HNSW graph building, bit vectors |

**dense_vector field options:**
```json
{
  "type": "dense_vector",
  "dims": 768,
  "index": true,
  "similarity": "cosine",
  "index_options": {
    "type": "hnsw",
    "m": 16,
    "ef_construction": 100
  }
}
```

Similarity options: `cosine` (normalized), `dot_product` (pre-normalized vectors), `l2_norm` (Euclidean distance), `max_inner_product`.

### NLP Inference (8.0+, PyTorch Models)

Elasticsearch 8.0 introduced the ability to deploy NLP models directly in the cluster:

```json
PUT _ml/trained_models/sentence-transformers__all-minilm-l6-v2/deployment/_start
{
  "number_of_allocations": 1,
  "threads_per_allocation": 2,
  "queue_capacity": 1024
}
```

**Inference in an ingest pipeline:**
```json
PUT _ingest/pipeline/text-embedding
{
  "processors": [
    {
      "inference": {
        "model_id": "sentence-transformers__all-minilm-l6-v2",
        "input_output": [
          {
            "input_field": "text",
            "output_field": "text_embedding"
          }
        ]
      }
    }
  ]
}
```

**Inference at query time (8.8+):**
```json
POST /my-index/_search
{
  "knn": {
    "field": "text_embedding",
    "query_vector_builder": {
      "text_embedding": {
        "model_id": "sentence-transformers__all-minilm-l6-v2",
        "model_text": "What is Elasticsearch?"
      }
    },
    "k": 10,
    "num_candidates": 100
  }
}
```

**Supported NLP tasks:**
- Text embedding (dense vector generation)
- Named Entity Recognition (NER)
- Text classification / sentiment analysis
- Zero-shot classification
- Question answering
- Fill-mask
- Language identification

**ELSER (Elastic Learned Sparse Encoder, 8.8+):**
Elastic's own retrieval model for semantic search without dense vectors:
```json
PUT /my-index
{
  "mappings": {
    "properties": {
      "content_embedding": {
        "type": "sparse_vector"
      }
    }
  }
}

POST /my-index/_search
{
  "query": {
    "sparse_vector": {
      "field": "content_embedding",
      "inference_id": "elser_model",
      "query": "What is Elasticsearch?"
    }
  }
}
```

### TSDB Index Mode (8.1+, GA in 8.7)

Time Series Data Base index mode optimizes storage and query performance for metrics:

```json
PUT _index_template/metrics-template
{
  "index_patterns": ["metrics-*"],
  "template": {
    "settings": {
      "index.mode": "time_series",
      "index.routing_path": ["host.name", "metric.name"],
      "index.time_series.start_time": "2024-01-01T00:00:00Z",
      "index.time_series.end_time": "2024-12-31T23:59:59Z"
    },
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "host.name": { "type": "keyword", "time_series_dimension": true },
        "metric.name": { "type": "keyword", "time_series_dimension": true },
        "metric.value": { "type": "double", "time_series_metric": "gauge" }
      }
    }
  }
}
```

**TSDB benefits:**
- Automatic TSID (time series ID) generation from dimension fields
- Doc-value-only storage for metrics (reduced storage by 40-60%)
- Automatic sorted index (by TSID + @timestamp)
- Synthetic `_source` reconstruction (no stored _source, further storage savings)
- Rate aggregation support for counter metrics

**time_series_metric types:** `gauge` (point-in-time value), `counter` (monotonically increasing), `position` (lat/lon), `summary` (pre-computed summary).

### Searchable Snapshots (GA in 8.0)

Mount snapshots as searchable indices with data in object storage:

```json
POST _snapshot/my-repo/snapshot-1/_mount?storage=shared_cache
{
  "index": "old-logs-2023",
  "renamed_index": "searchable-old-logs-2023"
}
```

**Storage types:**
| Type | Data Location | Performance | Use Case |
|---|---|---|---|
| `full_copy` | Full copy on local node | Fast (same as normal) | Warm tier (frequent access) |
| `shared_cache` | Object storage + local cache | Slower (cache misses = S3 reads) | Frozen tier (infrequent access) |

**Frozen tier with shared cache:**
```yaml
# elasticsearch.yml (frozen data node)
node.roles: [data_frozen]
xpack.searchable.snapshot.shared_cache.size: 90%
```

### Elastic Agent and Fleet (8.0+)

Elastic Agent replaces individual Beats (Filebeat, Metricbeat, etc.):

- **Fleet Server** -- Centralized management of Elastic Agents
- **Agent policies** -- Define data collection integrations per agent group
- **Integrations** -- Pre-built data collection for 300+ data sources

Data streams naming convention: `{type}-{dataset}-{namespace}`
Example: `logs-nginx.access-production`, `metrics-system.cpu-production`

### API Key Authentication Improvements (8.0+)

```json
POST _security/api_key
{
  "name": "search-service",
  "role_descriptors": {
    "search": {
      "indices": [
        {
          "names": ["products*"],
          "privileges": ["read"]
        }
      ]
    }
  },
  "expiration": "30d",
  "metadata": {
    "application": "search-service",
    "environment": "production"
  }
}
```

**API key updates (8.4+):**
```json
PUT _security/api_key/api-key-id
{
  "role_descriptors": {
    "search": {
      "indices": [
        {
          "names": ["products*", "catalog*"],
          "privileges": ["read"]
        }
      ]
    }
  },
  "metadata": {
    "updated_at": "2024-01-15"
  }
}
```

**Cross-cluster API keys (8.10+):**
```json
POST _security/cross_cluster/api_key
{
  "name": "cross-cluster-key",
  "access": {
    "search": [
      { "names": ["logs-*"] }
    ],
    "replication": [
      { "names": ["critical-data"] }
    ]
  }
}
```

### ES|QL (Elasticsearch Query Language, 8.11+)

A pipe-based query language:

```
POST _query
{
  "query": """
    FROM logs-*
    | WHERE log.level == "error" AND @timestamp > NOW() - 24 hours
    | STATS count = COUNT(*) BY host.name
    | SORT count DESC
    | LIMIT 10
  """
}
```

ES|QL examples:
```
// Aggregation with multiple metrics
FROM metrics-*
| WHERE @timestamp > NOW() - 1 hour
| STATS avg_cpu = AVG(system.cpu.percent), max_cpu = MAX(system.cpu.percent) BY host.name
| WHERE avg_cpu > 80
| SORT avg_cpu DESC

// Enrichment and transformation
FROM logs-*
| WHERE log.level == "error"
| EVAL error_type = CASE(
    message LIKE "*timeout*", "timeout",
    message LIKE "*connection refused*", "connection",
    "other"
  )
| STATS count = COUNT(*) BY error_type
| SORT count DESC

// Pattern matching
FROM logs-*
| GROK message "%{IP:client_ip} %{WORD:method} %{URIPATHPARAM:path} %{NUMBER:status}"
| WHERE status >= 500
| STATS error_count = COUNT(*) BY path
| SORT error_count DESC
```

### Synonyms API (8.10+)

Manage synonyms via REST API (no index restart required):

```json
PUT _synonyms/my-synonyms-set
{
  "synonyms_set": [
    { "id": "rule1", "synonyms": "elasticsearch, ES, elastic search" },
    { "id": "rule2", "synonyms": "kubernetes, k8s, kube" },
    { "id": "rule3", "synonyms": "database => db" }
  ]
}

PUT /my-index
{
  "settings": {
    "analysis": {
      "filter": {
        "syn_filter": {
          "type": "synonym_graph",
          "synonyms_set": "my-synonyms-set",
          "updateable": true
        }
      },
      "analyzer": {
        "syn_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "syn_filter"]
        }
      }
    }
  }
}

PUT _synonyms/my-synonyms-set/rule4
{
  "synonyms": "AWS, Amazon Web Services"
}
```

### Other Notable 8.x Features

**By minor version:**

| Version | Feature |
|---|---|
| 8.0 | Security by default, kNN search, NLP inference, removal of mapping types |
| 8.1 | TSDB index mode (preview), Kibana Discover improvements |
| 8.2 | Improved kNN performance, geo_grid aggregation |
| 8.3 | Downsampling for TSDB, runtime fields improvements |
| 8.4 | Filtered kNN search, hybrid kNN+BM25, API key updates |
| 8.5 | Random sampler aggregation, improved keyword suggestion |
| 8.6 | kNN quantization support, improved join field performance |
| 8.7 | TSDB GA, health API, improved multi-field kNN |
| 8.8 | ELSER model, query-time vector generation, nested kNN |
| 8.9 | Improved ES|QL preview, better error reporting |
| 8.10 | Synonyms API, cross-cluster API keys, byte-quantized kNN |
| 8.11 | ES|QL GA, Serverless GA, connector framework |
| 8.12 | Scalar quantization for vectors, improved logsdb |
| 8.13 | Semantic text field type, retrievers API |
| 8.14 | BBQ quantization, improved search performance |
| 8.15 | Bit vectors, improved HNSW, logsdb improvements |
| 8.16 | Improved synthetic source, passkey authentication |
| 8.17 | Final 8.x feature release before 9.0 |

## Breaking Changes from 7.x to 8.x

### Removed Features

- **Mapping types removed** -- No more `_doc` type in URLs (use `_doc` endpoint directly). Index creation no longer accepts type mappings.
- **Transport client removed** -- Use the Java API Client or REST client instead.
- **High-level REST client deprecated** -- Use the new Elasticsearch Java Client (`co.elastic.clients:elasticsearch-java`).
- **_type field removed** -- No type field in documents.

### Behavioral Changes

- **Security enabled by default** -- Cannot run without security unless explicitly disabled (`xpack.security.enabled: false`).
- **Legacy index templates deprecated** -- Use composable index templates (`_index_template` instead of `_template`).
- **Built-in index patterns changed** -- System indices are hidden by default. Use `expand_wildcards=hidden` to include them.
- **Default shard count** -- Default `number_of_shards` changed from 5 (ES 5/6) to 1 (ES 7+/8).
- **`_source` required** -- Cannot index without `_source` unless explicitly disabled.

### API Changes

```
# 7.x (deprecated)
PUT /my-index/_mapping/_doc { ... }

# 8.x (correct)
PUT /my-index/_mapping { ... }

# 7.x (deprecated)
GET /my-index/_doc/1/_source

# 8.x (correct)
GET /my-index/_source/1
```

### REST API Compatibility (7.x to 8.x)

Use REST API compatibility headers to ease migration:
```bash
curl -H "Content-Type: application/vnd.elasticsearch+json;compatible-with=7" \
     -H "Accept: application/vnd.elasticsearch+json;compatible-with=7" \
     localhost:9200/my-index/_search
```

This allows 7.x-style requests to work against an 8.x cluster during migration.

## Migration Guide: 7.x to 8.x

### Pre-Migration Checklist

```bash
# 1. Check deprecation log
curl -s localhost:9200/_migration/deprecations?pretty

# 2. Resolve all deprecation warnings before upgrading

# 3. Ensure all nodes are on the latest 7.17.x
curl -s localhost:9200/_cat/nodes?v&h=name,version

# 4. Take a snapshot
curl -X PUT localhost:9200/_snapshot/pre-upgrade-repo/pre-8x-snapshot?wait_for_completion=true

# 5. Check index compatibility (indices created in 6.x need reindexing)
curl -s localhost:9200/_cat/indices?v&h=index,creation.date.string
```

### Upgrade Path

- **7.17.x to 8.x**: Rolling upgrade supported
- **7.x (< 7.17)**: First upgrade to 7.17.x, then to 8.x
- **6.x or earlier**: Reindex required (cannot skip major versions)

### Rolling Upgrade Procedure

```bash
# 1. Disable shard allocation
curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{
  "persistent": { "cluster.routing.allocation.enable": "primaries" }
}'

# 2. Flush
curl -X POST localhost:9200/_flush

# 3. Stop ES on target node, upgrade, start ES
systemctl stop elasticsearch
# ... upgrade package/binary ...
systemctl start elasticsearch

# 4. Wait for node to rejoin
curl -s localhost:9200/_cat/nodes?v

# 5. Re-enable allocation
curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{
  "persistent": { "cluster.routing.allocation.enable": "all" }
}'

# 6. Wait for green, repeat for next node
curl -s localhost:9200/_cluster/health?wait_for_status=green&timeout=5m
```

## Common Pitfalls (8.x-Specific)

1. **Security blocks after upgrade** -- If upgrading from 7.x without security, ES 8.0 may fail to start. Either configure security or set `xpack.security.enabled: false` (not recommended for production).

2. **Enrollment token expiration** -- Enrollment tokens expire after 30 minutes. Generate new ones if needed.

3. **kNN requires index: true** -- The `dense_vector` field must have `index: true` for kNN search. Setting it after index creation requires reindexing.

4. **NLP model memory** -- Each deployed NLP model consumes significant memory. Plan ML node sizing accordingly. A typical sentence-transformer model uses 200-500MB of memory.

5. **TSDB routing path immutable** -- The `index.routing_path` for TSDB indices cannot be changed after creation. Plan dimension fields carefully.

6. **Legacy template migration** -- Legacy index templates (`_template`) still work but are deprecated. Migrate to composable templates (`_index_template`) before upgrading to 9.x where legacy templates may be removed.

7. **Java client migration** -- The High Level REST Client is deprecated. Migrate to the new Elasticsearch Java Client (`co.elastic.clients:elasticsearch-java`).

## Version Boundaries

- **Not available in 8.x:** Logsdb default mode (9.x), Lucene 10 (9.x)
- **New in 8.x vs 7.x:** Security by default, kNN search, NLP inference, TSDB, searchable snapshots GA, removal of mapping types, ES|QL, ELSER, synonyms API
- **Deprecated in 8.x:** Legacy index templates, High Level REST Client, some _cat API formats

## Reference Files

For deep technical details, load the parent technology agent's references:

- `../references/architecture.md` -- Lucene internals, node roles, cluster state, shard allocation
- `../references/diagnostics.md` -- 100+ REST API diagnostic commands
- `../references/best-practices.md` -- Cluster sizing, shard strategy, security hardening
