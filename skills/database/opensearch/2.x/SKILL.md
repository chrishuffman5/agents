---
name: database-opensearch-2x
description: "OpenSearch 2.x version-specific expert. Deep knowledge of neural search, search pipelines, segment replication, flat object field type, concurrent segment search, remote-backed storage, k-NN improvements, and migration to 3.x. WHEN: \"OpenSearch 2\", \"OS 2\", \"neural search 2.x\", \"search pipelines\", \"segment replication\", \"flat_object\", \"concurrent segment search\", \"remote-backed storage\", \"opensearch 2.0\", \"opensearch 2.1\", \"opensearch 2.2\", \"opensearch 2.3\", \"opensearch 2.4\", \"opensearch 2.5\", \"opensearch 2.6\", \"opensearch 2.7\", \"opensearch 2.8\", \"opensearch 2.9\", \"opensearch 2.10\", \"opensearch 2.11\", \"opensearch 2.12\", \"opensearch 2.13\", \"opensearch 2.14\", \"opensearch 2.15\", \"opensearch 2.16\", \"opensearch 2.17\", \"opensearch 2.18\", \"opensearch 2.19\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# OpenSearch 2.x Expert

You are a specialist in OpenSearch 2.x (2.0 through 2.19), the maintenance major version. You have deep knowledge of neural search, search pipelines, segment replication, flat object field type, concurrent segment search, remote-backed storage, k-NN improvements with multiple engines, and the migration path to 3.x.

**Support status:** OpenSearch 2.x is in maintenance mode. It receives security patches and bug fixes but no new features. New features are developed exclusively for 3.x. Maintenance support continues until OpenSearch 4.0 is released.

## Key Features Introduced in OpenSearch 2.x

### Neural Search (2.4+, GA in 2.11+)

Neural search enables semantic search by using ML models to generate embeddings at index and query time:

**Ingest pipeline for text embedding:**
```json
PUT /_ingest/pipeline/text-embedding-pipeline
{
  "description": "Generate embeddings at index time",
  "processors": [
    {
      "text_embedding": {
        "model_id": "<model_id>",
        "field_map": {
          "text": "text_embedding"
        }
      }
    }
  ]
}
```

**Index with k-NN vector field:**
```json
PUT /semantic-search-index
{
  "settings": {
    "index": {
      "knn": true,
      "default_pipeline": "text-embedding-pipeline"
    }
  },
  "mappings": {
    "properties": {
      "text": { "type": "text" },
      "text_embedding": {
        "type": "knn_vector",
        "dimension": 768,
        "method": {
          "name": "hnsw",
          "engine": "faiss",
          "space_type": "l2",
          "parameters": { "m": 16, "ef_construction": 256 }
        }
      }
    }
  }
}
```

**Neural search query (generates embedding at query time):**
```json
POST /semantic-search-index/_search
{
  "query": {
    "neural": {
      "text_embedding": {
        "query_text": "What is OpenSearch?",
        "model_id": "<model_id>",
        "k": 10
      }
    }
  }
}
```

### Search Pipelines (2.9+)

Search pipelines enable request and response processing without modifying application code:

**Request processors** modify the search request:
- `filter_query` -- Add mandatory filters
- `script` -- Custom request transformation
- `oversample` -- Increase result set for post-processing
- `neural_query_enricher` -- Add model IDs to neural queries

**Response processors** modify the search response:
- `rename_field` -- Rename fields in results
- `truncate_hits` -- Limit number of results after processing
- `collapse` -- Collapse duplicate results
- `personalize_search_ranking` -- Re-rank using Amazon Personalize

**Phase results processors** run between query and fetch:
- `normalization-processor` -- Normalize and combine scores from multiple query types (essential for hybrid search)

```json
PUT /_search/pipeline/my-search-pipeline
{
  "description": "Search pipeline with filtering and normalization",
  "request_processors": [
    {
      "filter_query": {
        "query": { "term": { "status": "active" } }
      }
    }
  ],
  "phase_results_processors": [
    {
      "normalization-processor": {
        "normalization": { "technique": "min_max" },
        "combination": {
          "technique": "arithmetic_mean",
          "parameters": { "weights": [0.3, 0.7] }
        }
      }
    }
  ],
  "response_processors": [
    {
      "truncate_hits": { "target_size": 20 }
    }
  ]
}
```

### Hybrid Search (2.10+)

Combines lexical (BM25) and semantic (k-NN) search with score normalization:

```json
POST /my-index/_search?search_pipeline=hybrid-pipeline
{
  "query": {
    "hybrid": {
      "queries": [
        {
          "match": {
            "text": {
              "query": "What is OpenSearch?",
              "boost": 1.0
            }
          }
        },
        {
          "neural": {
            "text_embedding": {
              "query_text": "What is OpenSearch?",
              "model_id": "<model_id>",
              "k": 50
            }
          }
        }
      ]
    }
  }
}
```

**Required:** A search pipeline with `normalization-processor` must be applied because BM25 and k-NN use different scoring scales.

### Conversational Search (2.10+, GA in 2.12)

Enables building conversational experiences using OpenSearch:

```json
// Create a conversation memory
POST /_plugins/_ml/memory
{
  "name": "Customer support chat"
}

// Use RAG (Retrieval Augmented Generation) pipeline
PUT /_search/pipeline/rag-pipeline
{
  "response_processors": [
    {
      "retrieval_augmented_generation": {
        "model_id": "<llm_model_id>",
        "context_field_list": ["text"],
        "system_prompt": "You are a helpful assistant. Answer based on the provided context.",
        "user_instructions": "Answer this question: ${input}"
      }
    }
  ]
}
```

### Segment Replication (2.3+)

Alternative replication strategy that copies Lucene segment files directly from primary to replicas:

```json
PUT /my-index
{
  "settings": {
    "index": {
      "replication.type": "SEGMENT",
      "number_of_shards": 3,
      "number_of_replicas": 1
    }
  }
}
```

**Benefits:**
- Lower CPU and memory on replicas (no re-analysis, no re-indexing)
- Better indexing throughput (up to 40% improvement in some benchmarks)
- Replicas receive pre-built Lucene segments

**Trade-offs:**
- Higher network bandwidth usage
- Slightly higher replication lag
- Not compatible with remote-backed storage in early 2.x versions

**Best for:** Write-heavy workloads (logging, metrics) where indexing throughput matters more than real-time replica consistency.

### Flat Object Field Type (2.7+)

The `flat_object` field type stores entire JSON objects as a single field, avoiding mapping explosion from dynamic keys:

```json
PUT /config-index
{
  "mappings": {
    "properties": {
      "labels": { "type": "flat_object" }
    }
  }
}

// Index document with arbitrary nested keys
POST /config-index/_doc/1
{
  "labels": {
    "env": "production",
    "region": "us-east-1",
    "team.name": "platform",
    "custom.tag.v1": "important"
  }
}

// Search by any key
POST /config-index/_search
{
  "query": {
    "term": { "labels": "production" }
  }
}

// Search by specific key-value
POST /config-index/_search
{
  "query": {
    "term": { "labels.env": "production" }
  }
}
```

**Use cases:** Kubernetes labels, custom tags, configuration metadata, any field with high-cardinality dynamic keys.

### Concurrent Segment Search (2.12+, Experimental)

Searches multiple Lucene segments in parallel within a single shard, improving search latency for large shards:

```json
// Enable cluster-wide
PUT /_cluster/settings
{
  "persistent": {
    "search.concurrent_segment_search.enabled": true
  }
}

// Configure concurrency
PUT /_cluster/settings
{
  "persistent": {
    "search.concurrent_segment_search.mode": "auto"
  }
}
```

**Benefits:** Up to 50% latency reduction for aggregation-heavy queries on large shards.
**Considerations:** Increases CPU usage per query. Not all aggregation types benefit equally.

### Remote-Backed Storage (2.10+, Experimental)

Decouples compute from storage by using remote object stores (S3, etc.) as the primary storage:

```yaml
# opensearch.yml
node.attr.remote_store.segment.repository: my-s3-repo
node.attr.remote_store.translog.repository: my-s3-repo
node.attr.remote_store.state.repository: my-s3-repo

# Repository must be registered first
```

**Benefits:**
- Faster node recovery (segments pulled from S3 instead of peer nodes)
- Reduced local storage requirements
- Improved cluster resiliency (data survives node loss)

**Trade-offs:**
- Higher latency for reads (mitigated by local caching)
- Requires reliable, low-latency object store access
- Additional cost for object store operations

### k-NN Improvements in 2.x

**2.2:** Faiss engine support added alongside NMSLIB and Lucene
**2.4:** Byte vectors support for reduced memory
**2.9:** Efficient k-NN filtering with Faiss engine
**2.10:** Nested field support for k-NN vectors
**2.11:** Disk-based vector search (reduces memory requirements)
**2.12:** IVF support with Faiss, product quantization
**2.14:** Binary vector support, radial search
**2.16:** fp16 and SQ encoders for Faiss HNSW

### Notification Channels (2.0+, Replaces Destinations)

Starting in 2.0, notification channels replaced alerting destinations:

```json
// Create notification channel
POST /_plugins/_notifications/configs
{
  "config_id": "slack-channel",
  "config": {
    "name": "Team Slack Channel",
    "description": "Notifications for team alerts",
    "config_type": "slack",
    "is_enabled": true,
    "slack": {
      "url": "https://hooks.slack.com/services/xxx/yyy/zzz"
    }
  }
}
```

Channel types: `slack`, `chime`, `webhook`, `email`, `sns`, `ses`.

### Data Streams (2.0+)

Data streams simplify time-series index management:

```json
// Create index template with data_stream
PUT /_index_template/logs-template
{
  "index_patterns": ["logs-*"],
  "data_stream": {},
  "priority": 200,
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1,
      "index.refresh_interval": "30s"
    },
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "message": { "type": "text" },
        "level": { "type": "keyword" }
      }
    }
  }
}

// Create data stream
PUT /_data_stream/logs-app

// Data stream auto-rollover via ISM
```

### Asynchronous Search (2.0+)

For long-running queries that may exceed timeout:

```json
// Submit async search
POST /logs-*/_plugins/_asynchronous_search -H 'Content-Type: application/json' -d '{
  "size": 0,
  "aggs": {
    "daily_errors": {
      "date_histogram": { "field": "@timestamp", "calendar_interval": "day" },
      "aggs": { "error_count": { "filter": { "term": { "level": "ERROR" } } } }
    }
  }
}'

// Check status
GET /_plugins/_asynchronous_search/<search_id>

// Get partial results
GET /_plugins/_asynchronous_search/<search_id>?pretty

// Delete async search
DELETE /_plugins/_asynchronous_search/<search_id>
```

## Version-by-Version Feature Timeline

| Version | Release | Key Features |
|---------|---------|-------------|
| 2.0 | May 2022 | Notification channels, data streams, Lucene 9.1 |
| 2.1 | Jul 2022 | Transform jobs, custom codecs (zstd) |
| 2.2 | Aug 2022 | Faiss k-NN engine, searchable snapshots (experimental) |
| 2.3 | Sep 2022 | Segment replication (experimental), drag-and-drop dashboard |
| 2.4 | Nov 2022 | Neural search (experimental), byte vectors |
| 2.5 | Jan 2023 | Point-in-time (PIT) search, ML model access control |
| 2.6 | Feb 2023 | Multiple data sources in Dashboards, flat_object (experimental) |
| 2.7 | Apr 2023 | Flat object GA, index management UI improvements |
| 2.8 | Jun 2023 | Correlations engine (security analytics), Lucene 9.7 |
| 2.9 | Jul 2023 | Search pipelines, efficient k-NN filtering |
| 2.10 | Sep 2023 | Hybrid search, conversational search, remote-backed storage (experimental) |
| 2.11 | Oct 2023 | Neural search GA, disk-based vector search, search comparison tool |
| 2.12 | Feb 2024 | Conversational search GA, concurrent segment search, Apache Spark integration |
| 2.13 | Mar 2024 | Ingest pipeline metric aggregations, multiple search providers |
| 2.14 | May 2024 | Binary vectors, radial search, Lucene 9.10 |
| 2.15 | Jul 2024 | Derived fields, cross-cluster monitors |
| 2.16 | Aug 2024 | fp16/SQ encoders, streaming aggregations |
| 2.17 | Oct 2024 | Star-tree index (experimental), tiered caching |
| 2.18 | Dec 2024 | Performance improvements, stability fixes |
| 2.19 | Feb 2025 | Final 2.x minor release, maintenance-only hereafter |

## Migration from OpenSearch 2.x to 3.x

### Breaking Changes in 3.0

1. **Java 21 minimum** -- JVM must be updated to Java 21+ (was Java 11+ in 2.x)
2. **Lucene 10** -- Index format changes. Indices must be reindexed or created fresh in 3.x.
3. **NMSLIB deprecated** -- k-NN indices using NMSLIB engine must be migrated to Faiss or Lucene
4. **Java Security Manager removed** -- Replaced with alternative sandboxing
5. **Query groups renamed** -- `wlm/query_group` endpoint becomes `wlm/workload_group`
6. **Notebooks migration** -- Notebooks must be migrated to new storage system before upgrade

### Migration Steps

1. **Pre-migration assessment:**
   - Check Java version compatibility (must be 21+)
   - Identify NMSLIB k-NN indices that need engine migration
   - Review breaking changes documentation
   - Backup notebooks and ISM policies

2. **Upgrade path:**
   - OpenSearch 2.x --> 3.0 (direct upgrade supported)
   - Take a full snapshot before upgrading
   - Rolling upgrade is supported for compatible configurations

3. **Post-migration validation:**
   - Verify all indices are green
   - Test k-NN search performance
   - Validate ISM policies are executing
   - Confirm security plugin configuration

### Compatibility Notes

- OpenSearch 2.x snapshots can be restored on 3.x
- Client libraries may need updating for 3.x API changes
- Dashboards saved objects from 2.x are compatible with 3.x Dashboards
- ISM policies from 2.x work in 3.x without modification
