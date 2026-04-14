# OpenSearch Architecture Reference

## Lucene Internals

OpenSearch is built on Apache Lucene. Every shard is a self-contained Lucene index. Understanding Lucene internals is essential for performance tuning and troubleshooting. OpenSearch 2.x uses Lucene 9.x; OpenSearch 3.x uses Lucene 10.x.

### Inverted Index

The inverted index is the core data structure for full-text search:

- Maps each unique **term** to a list of **document IDs** (postings list) that contain that term
- Built per-field: each analyzed text field has its own inverted index
- Includes term frequency (TF), document frequency (DF), and positional information

```
Term         | Document IDs (postings list)
-------------|-----------------------------
"opensearch" | [1, 5, 12, 45, 99]
"search"     | [1, 3, 5, 12, 33, 99]
"cluster"    | [3, 12, 45]
"shard"      | [5, 45, 99]
```

Postings list components:
- **Document frequency** -- Number of documents containing the term (used for IDF in BM25)
- **Term frequency** -- How many times the term appears in each document
- **Positions** -- Token positions within the document (for phrase queries and proximity matching)
- **Offsets** -- Character start/end offsets (for highlighting)
- **Payloads** -- Arbitrary byte data attached to term occurrences (rarely used directly)

The inverted index is stored in multiple files per segment:
- `.tim` -- Term dictionary (sorted term list with metadata)
- `.tip` -- Term index (prefix trie for fast lookup into .tim)
- `.doc` -- Postings lists (document IDs and term frequencies)
- `.pos` -- Position data (for phrase and proximity queries)
- `.pay` -- Payloads and offsets

### Doc Values

Doc values are an on-disk columnar data structure used for sorting, aggregations, and scripting:

- Column-oriented: all values for a single field stored contiguously
- Built at index time (not lazily like fielddata)
- Stored in `.dvd` (data) and `.dvm` (metadata) files
- Enabled by default for all fields except `text` (which uses fielddata if needed)
- Can be disabled to save disk space for fields never used in aggregations/sorting:

```json
{
  "properties": {
    "description": {
      "type": "keyword",
      "doc_values": false
    }
  }
}
```

Doc values encoding strategies (Lucene auto-selects):
- **Numeric** -- Delta encoding, GCD compression, table encoding for low-cardinality
- **Binary** -- Variable-length byte arrays with shared prefixes
- **Sorted** -- Ordinal mapping (ordinal -> value lookup table) for keyword fields
- **Sorted Set** -- For multi-valued fields (arrays)
- **Sorted Numeric** -- For multi-valued numeric fields

### Stored Fields

Stored fields hold the original document `_source` and any explicitly stored fields:

- The `_source` field stores the entire original JSON document (compressed)
- Stored in `.fdt` (field data) and `.fdx` (field index) files
- Compressed using LZ4 (fast) or best_compression (DEFLATE, higher ratio)
- Loading stored fields requires disk I/O; avoid fetching `_source` when only aggregation results are needed
- `_source` can be disabled to save disk (but breaks reindex, update, highlight without stored fields):

```json
PUT /my-index
{
  "mappings": {
    "_source": { "enabled": false }
  }
}
```

### Segment Lifecycle

1. **Indexing** -- Documents are written to an in-memory buffer and the translog
2. **Refresh** -- Buffer is flushed to a new immutable Lucene segment (default every 1 second)
3. **Merge** -- Background threads merge small segments into larger ones, removing deleted documents
4. **Flush** -- Lucene commits segments to disk and clears the translog

Segment merging is critical for performance:
- Too many small segments = slow search (more segments to check per query)
- Merge is I/O intensive and competes with indexing/search
- `index.merge.policy.max_merged_segment` controls the maximum segment size eligible for merging (default 5GB)
- `index.merge.scheduler.max_thread_count` controls merge parallelism

### BM25 Scoring (Default)

OpenSearch uses BM25 (Best Matching 25) as the default similarity model:

```
score(q, d) = SUM over terms t in q:
  IDF(t) * (tf(t,d) * (k1 + 1)) / (tf(t,d) + k1 * (1 - b + b * |d| / avgdl))
```

Where:
- `tf(t,d)` = term frequency of term t in document d
- `IDF(t)` = inverse document frequency = log(1 + (N - n + 0.5) / (n + 0.5))
- `k1` = term frequency saturation parameter (default 1.2)
- `b` = length normalization parameter (default 0.75)
- `|d|` = document length (number of terms)
- `avgdl` = average document length across the index

## Cluster Architecture

### Node Roles

OpenSearch nodes can serve one or more roles. By default, every node has all roles enabled. In production, separate roles for dedicated nodes:

| Role | Config Value | Purpose |
|------|-------------|---------|
| Cluster Manager | `cluster_manager` | Maintains cluster state, metadata, shard allocation. Requires 3+ dedicated nodes for quorum. |
| Data | `data` | Stores shards, handles CRUD, search, and aggregations. Most resource-intensive role. |
| Ingest | `ingest` | Runs ingest pipelines to transform documents before indexing. |
| Coordinating-only | (no roles) | Routes requests, merges results. Acts as smart load balancer. |
| ML | `ml` | Runs machine learning tasks (anomaly detection, neural search models). Isolates ML workload. |
| Remote Cluster Client | `remote_cluster_client` | Enables cross-cluster search and replication connections. |
| Search | `search` | (2.x+) Dedicated search node role for reader/writer separation with segment replication. |

**opensearch.yml node role configuration:**
```yaml
# Dedicated cluster manager node
node.roles: [cluster_manager]

# Dedicated data node
node.roles: [data, ingest]

# Coordinating-only node (empty roles)
node.roles: []

# ML node
node.roles: [ml]

# Data + search node
node.roles: [data, search]
```

### Cluster State

The cluster state is a metadata structure maintained by the active cluster manager node:

- **Routing table** -- Maps every shard to a node
- **Index metadata** -- Mappings, settings, aliases for every index
- **Node membership** -- Which nodes are in the cluster and their roles
- **Cluster settings** -- Persistent and transient settings

The cluster state is replicated to every node. Large cluster states (thousands of indices, tens of thousands of shards) increase cluster manager heap pressure and slow down state updates.

### Shard Allocation

The cluster manager decides shard placement based on:

- **Allocation awareness** -- Distribute shards across zones, racks, or custom attributes
- **Disk watermarks** -- Low (85%), high (90%), flood stage (95%) thresholds control allocation
- **Shard balancing** -- Even distribution of shards across nodes
- **Allocation filtering** -- Include/exclude/require nodes by attribute

```yaml
# opensearch.yml: zone awareness
cluster.routing.allocation.awareness.attributes: zone
node.attr.zone: us-east-1a

# Forced awareness (never place all replicas in one zone)
cluster.routing.allocation.awareness.force.zone.values: us-east-1a,us-east-1b,us-east-1c
```

**Disk watermarks:**
```json
PUT /_cluster/settings
{
  "persistent": {
    "cluster.routing.allocation.disk.watermark.low": "85%",
    "cluster.routing.allocation.disk.watermark.high": "90%",
    "cluster.routing.allocation.disk.watermark.flood_stage": "95%"
  }
}
```

### Segment Replication (2.x+)

Traditional document replication re-indexes documents on every replica. Segment replication copies Lucene segment files directly from primary to replica:

- **Benefits:** Lower CPU and memory on replicas (no re-analysis, no re-indexing). Better indexing throughput.
- **Trade-offs:** Higher network bandwidth (segment files are larger than document payloads). Slightly higher replication lag. Replicas serve stale data until segments are copied.
- **Best for:** Write-heavy workloads where indexing throughput matters more than real-time replica consistency.

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

### Remote-Backed Storage (2.x+)

Remote-backed storage decouples compute from storage by using remote object stores (S3, etc.) as the backing store for segments:

- Segments are written to remote storage instead of local disk
- Translog is also backed by remote storage for durability
- Enables faster recovery (segments pulled from remote instead of peer-to-peer)
- Reduces local storage requirements

```yaml
# opensearch.yml
node.attr.remote_store.segment.repository: my-s3-repo
node.attr.remote_store.translog.repository: my-s3-repo
node.attr.remote_store.state.repository: my-s3-repo
```

## Plugin Architecture

OpenSearch uses a plugin architecture for extending functionality. Core plugins ship with the distribution:

| Plugin | Purpose | API Prefix |
|--------|---------|-----------|
| Security | Authentication, authorization, encryption | `_plugins/_security/` |
| Alerting | Monitors, triggers, notifications | `_plugins/_alerting/` |
| Anomaly Detection | RCF-based anomaly detection | `_plugins/_anomaly_detection/` |
| ISM | Index lifecycle management | `_plugins/_ism/` |
| k-NN | Vector similarity search | `_plugins/_knn/` |
| ML Commons | ML model management, inference | `_plugins/_ml/` |
| SQL | SQL and PPL query support | `_plugins/_sql/`, `_plugins/_ppl/` |
| Observability | Trace analytics, notebooks, metrics | `_plugins/_observability/` |
| Notifications | Notification channels (Slack, email, SNS) | `_plugins/_notifications/` |
| Cross-Cluster Replication | Active-passive index replication | `_plugins/_replication/` |
| Asynchronous Search | Background search for long-running queries | `_plugins/_asynchronous_search/` |
| Performance Analyzer | JVM/OS/index metrics collection | `_plugins/_performanceanalyzer/` |
| Index Management | Rollup, transform, data streams | `_plugins/_rollup/`, `_plugins/_transform/` |

## k-NN Vector Search Architecture

### HNSW (Hierarchical Navigable Small World)

HNSW builds a multi-layered graph structure for approximate nearest neighbor search:

- **Layer 0** contains all vectors connected to their nearest neighbors
- **Higher layers** contain progressively fewer vectors, acting as "express lanes" for navigation
- **Search** starts at the top layer and navigates down through the hierarchy
- **Parameters:**
  - `m` -- Number of bi-directional links per node (default 16). Higher = more accurate but more memory.
  - `ef_construction` -- Size of the dynamic candidate list during index building (default 100). Higher = more accurate index but slower build.
  - `ef_search` -- Size of the dynamic candidate list during search (default 100). Higher = more accurate search but slower.

### IVF (Inverted File Index)

IVF partitions vectors into clusters (Voronoi cells) and searches only nearby clusters:

- Requires a training step to learn cluster centroids
- **Parameters:**
  - `nlist` -- Number of clusters/buckets
  - `nprobes` -- Number of clusters to search at query time

### Memory Management

k-NN uses native memory (off-heap) for graph structures:

- **Circuit breaker:** `knn.memory.circuit_breaker.limit` (default 50% of JVM heap)
- **Graph loading:** Graphs are loaded lazily on first search and cached
- **Warmup API:** Pre-load graphs into memory:
  ```
  GET /_plugins/_knn/warmup/my-knn-index
  ```
- **Memory estimation:** See SKILL.md for formulas per algorithm

### Vector Quantization

Reduce memory footprint by encoding vectors with lower precision:

- **fp16 encoder** -- Reduces memory by 2x with minimal accuracy loss. Available in Faiss.
- **SQ (Scalar Quantization)** -- Maps float32 values to int8. Available in Faiss and Lucene (3.x).
- **PQ (Product Quantization)** -- Compresses vectors into compact codes. Significant memory savings but requires training. Available in Faiss.

```json
PUT /quantized-knn-index
{
  "settings": { "index": { "knn": true } },
  "mappings": {
    "properties": {
      "my_vector": {
        "type": "knn_vector",
        "dimension": 768,
        "method": {
          "name": "hnsw",
          "engine": "faiss",
          "space_type": "l2",
          "parameters": {
            "m": 16,
            "ef_construction": 256,
            "encoder": {
              "name": "sq",
              "parameters": { "type": "fp16" }
            }
          }
        }
      }
    }
  }
}
```

## Search Pipeline Architecture

Search pipelines process search requests and responses through a series of processors:

- **Request processors** -- Modify the search request before execution (e.g., add filters, rewrite queries)
- **Response processors** -- Modify search results after execution (e.g., re-rank, truncate, personalize)
- **Phase results processors** -- Process intermediate results between query and fetch phases (e.g., normalization for hybrid search)

```json
PUT /_search/pipeline/my-pipeline
{
  "description": "Example search pipeline",
  "request_processors": [
    {
      "filter_query": {
        "query": { "term": { "status": "active" } }
      }
    }
  ],
  "response_processors": [
    {
      "rename_field": {
        "field": "old_name",
        "target_field": "new_name"
      }
    }
  ],
  "phase_results_processors": [
    {
      "normalization-processor": {
        "normalization": { "technique": "min_max" },
        "combination": { "technique": "arithmetic_mean", "parameters": { "weights": [0.4, 0.6] } }
      }
    }
  ]
}
```

## ML Commons Framework

The ML Commons plugin provides a framework for deploying and managing machine learning models:

### Model Types
- **Local models** -- Models deployed directly on ML nodes (e.g., sentence transformers)
- **Remote models** -- Models hosted externally (e.g., Amazon Bedrock, OpenAI, Cohere) accessed via connectors
- **Pre-trained models** -- OpenSearch-provided models available for download

### Model Deployment Workflow
```json
// 1. Register a model group
POST /_plugins/_ml/model_groups/_register
{
  "name": "embedding_models",
  "description": "Embedding models for semantic search"
}

// 2. Register a model
POST /_plugins/_ml/models/_register
{
  "name": "sentence-transformers/all-MiniLM-L6-v2",
  "version": "1.0.0",
  "model_group_id": "<group_id>",
  "model_format": "TORCH_SCRIPT"
}

// 3. Deploy the model
POST /_plugins/_ml/models/<model_id>/_deploy

// 4. Predict (inference)
POST /_plugins/_ml/models/<model_id>/_predict
{
  "text_docs": ["What is OpenSearch?"]
}
```

### Connectors (Remote Models)
```json
POST /_plugins/_ml/connectors/_create
{
  "name": "Amazon Bedrock Connector",
  "description": "Connector for Bedrock embeddings",
  "version": 1,
  "protocol": "aws_sigv4",
  "parameters": {
    "region": "us-east-1",
    "service_name": "bedrock"
  },
  "actions": [
    {
      "action_type": "predict",
      "method": "POST",
      "url": "https://bedrock-runtime.us-east-1.amazonaws.com/model/amazon.titan-embed-text-v1/invoke",
      "headers": { "content-type": "application/json" },
      "request_body": "{ \"inputText\": \"${parameters.inputText}\" }"
    }
  ]
}
```

## Data Streams

Data streams simplify time-series data management by auto-managing backing indices:

```json
// Create index template for data stream
PUT /_index_template/logs-template
{
  "index_patterns": ["logs-*"],
  "data_stream": {},
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1
    },
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "message": { "type": "text" }
      }
    }
  }
}

// Create the data stream
PUT /_data_stream/logs-app

// Index documents (append-only, requires @timestamp)
POST /logs-app/_doc
{
  "@timestamp": "2026-04-07T12:00:00Z",
  "message": "Application started"
}
```

Data streams automatically rollover backing indices when ISM conditions are met. They support only append-only operations (no updates/deletes on individual documents by default).

## Ingest Pipelines

Ingest pipelines transform documents before indexing:

```json
PUT /_ingest/pipeline/web-logs
{
  "description": "Process web logs",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": ["%{COMBINEDAPACHELOG}"]
      }
    },
    {
      "date": {
        "field": "timestamp",
        "formats": ["dd/MMM/yyyy:HH:mm:ss Z"],
        "target_field": "@timestamp"
      }
    },
    {
      "geoip": {
        "field": "clientip",
        "target_field": "geo"
      }
    },
    {
      "user_agent": {
        "field": "agent",
        "target_field": "user_agent"
      }
    },
    {
      "remove": {
        "field": ["message", "timestamp", "agent"]
      }
    }
  ]
}
```

Common processors: `grok`, `date`, `geoip`, `user_agent`, `convert`, `rename`, `remove`, `set`, `split`, `trim`, `uppercase`, `lowercase`, `json`, `csv`, `dissect`, `script`, `pipeline` (chain pipelines), `text_embedding` (neural search).
