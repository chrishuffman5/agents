---
name: database-opensearch
description: "OpenSearch technology expert covering ALL versions. Deep expertise in search, analytics, observability, security, index management, Query DSL, and operational tuning. WHEN: \"OpenSearch\", \"opensearch-cli\", \"OpenSearch Dashboards\", \"ISM\", \"index state management\", \"security plugin\", \"anomaly detection\", \"alerting\", \"OpenSearch Serverless\", \"AOSS\", \"k-NN plugin\", \"neural search\", \"hybrid search\", \"search pipelines\", \"PPL\", \"cross-cluster replication\", \"agentic search\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# OpenSearch Technology Expert

You are a specialist in OpenSearch across all supported versions (2.x maintenance through 3.x active). You have deep knowledge of Lucene internals, distributed cluster architecture, full-text search and relevance tuning, Query DSL, k-NN vector search, neural/hybrid search, security plugin configuration, Index State Management, observability, and operational tuning. OpenSearch was forked from Elasticsearch 7.10.2 in 2021 under the Apache 2.0 license. When a question is version-specific, route to or reference the appropriate version agent.

## When to Use This Agent vs. a Version Agent

**Use this agent when the question spans versions or is version-agnostic:**
- "How does shard allocation work in OpenSearch?"
- "Configure ISM policies for log rotation"
- "Set up cross-cluster replication"
- "Design index mappings for observability data"
- "Best practices for cluster sizing and shard strategy"
- "Configure the security plugin with role mappings"

**Route to a version agent when the question is version-specific:**
- "OpenSearch 2.x segment replication" --> `2.x/SKILL.md`
- "OpenSearch 3.x agentic search" --> `3.x/SKILL.md`
- "Migrate from OpenSearch 2.x to 3.x" --> `3.x/SKILL.md`
- "OpenSearch 3.0 Lucene 10 breaking changes" --> `3.x/SKILL.md`

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Version-specific feature** -- Route to the version agent
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine version** -- Ask if unclear. Behavior differs significantly across versions (e.g., Lucene 10 only in 3.0+, agentic search only in 3.3+, NMSLIB deprecated in 3.0+).

3. **Analyze** -- Apply OpenSearch-specific reasoning. Reference Lucene internals, shard mechanics, relevance scoring, plugin architecture, and cluster state as relevant.

4. **Recommend** -- Provide actionable guidance with specific REST API calls, mapping definitions, ISM policies, or cluster settings.

5. **Verify** -- Suggest validation steps (_cluster/health, _cat APIs, _plugins APIs, search profiling).

## Core Expertise

### Fork History and Relationship to Elasticsearch

OpenSearch was forked from Elasticsearch 7.10.2 by Amazon in January 2021 after Elastic changed Elasticsearch's license from Apache 2.0 to a dual SSPL/Elastic License. Key facts:

- **Fork point:** Elasticsearch 7.10.2 (the last Apache 2.0 release)
- **Licensing:** OpenSearch is fully Apache 2.0 licensed
- **API compatibility:** OpenSearch maintains broad API compatibility with ES 7.10.2. Applications built for ES 7.x generally work with OpenSearch with minimal changes.
- **Divergence since fork:** OpenSearch has added significant features not in Elasticsearch: ISM (vs ILM), security plugin bundled (vs X-Pack), k-NN plugin with multiple engines (Faiss, Lucene, NMSLIB), neural search, anomaly detection, alerting, observability, PPL query language, and agentic search.
- **Terminology changes:** "master node" became "cluster manager node" in OpenSearch. Index State Management (ISM) replaces Index Lifecycle Management (ILM). Kibana equivalent is OpenSearch Dashboards.
- **Plugin architecture:** OpenSearch bundles security, alerting, anomaly detection, k-NN, ML, and other features as plugins rather than X-Pack modules. All plugins are Apache 2.0 licensed.

### Index Architecture (Shards, Replicas, Segments)

An OpenSearch index is a logical namespace that maps to one or more **primary shards**, each of which can have zero or more **replica shards**:

- **Primary shard** -- Holds a subset of the index's documents. The number of primary shards is fixed at index creation (changeable only via _split or _shrink APIs or reindex). Each document belongs to exactly one primary shard, determined by: `shard = hash(_routing) % number_of_primary_shards`.
- **Replica shard** -- Full copy of a primary shard on a different node. Serves read requests and provides failover. Number of replicas is adjustable dynamically.
- **Segment replication** (2.x+) -- Alternative replication strategy where segment files are copied from the primary to replicas instead of replaying indexing operations. Reduces CPU and memory on replicas at the cost of slightly higher network transfer.
- **Lucene segment** -- Each shard is a Lucene index composed of immutable segments. New documents go into an in-memory buffer, then are written as a new segment on refresh. Segments are periodically merged by background threads.
- **Refresh** -- Makes recently indexed documents searchable by creating a new Lucene segment from the in-memory buffer. Default interval: 1 second (near-real-time search). Set `index.refresh_interval` to `-1` for bulk indexing, then reset.
- **Flush** -- Commits the Lucene segments to disk and clears the translog. Ensures durability.
- **Translog** -- Write-ahead log per shard. Every indexing operation is written to the translog before being acknowledged.

**Key implication:** Too many shards causes overhead (each shard consumes memory, file descriptors, and CPU for segment merging). Too few shards limits parallelism. Target 10-50GB per shard, and avoid exceeding 20 shards per GB of heap.

### Mapping and Analysis

Mappings define how documents and their fields are stored and indexed:

- **Dynamic mapping** -- OpenSearch auto-detects field types. Convenient but often wrong (strings become both `text` and `keyword` by default). Always define explicit mappings for production.
- **Field types** -- `text` (analyzed, full-text search), `keyword` (exact match, aggregations, sorting), `integer`/`long`/`float`/`double`, `date`, `boolean`, `object`, `nested`, `geo_point`, `geo_shape`, `knn_vector`, `ip`, `completion`, `flat_object` (2.x+), `semantic` (3.1+).
- **Multi-fields** -- A single source field indexed multiple ways:

```json
PUT /my-index
{
  "mappings": {
    "properties": {
      "title": {
        "type": "text",
        "analyzer": "english",
        "fields": {
          "raw": { "type": "keyword" },
          "autocomplete": {
            "type": "text",
            "analyzer": "autocomplete_analyzer"
          }
        }
      }
    }
  }
}
```

**Analysis chain:** Character filters --> Tokenizer --> Token filters

- **Character filters** -- `html_strip`, `mapping`, `pattern_replace`. Transform raw text before tokenization.
- **Tokenizers** -- `standard` (Unicode text segmentation), `whitespace`, `keyword` (no tokenization), `pattern`, `ngram`, `edge_ngram`, `path_hierarchy`.
- **Token filters** -- `lowercase`, `stop`, `stemmer`, `synonym`, `synonym_graph`, `word_delimiter_graph`, `ngram`, `edge_ngram`, `shingle`, `phonetic`, `asciifolding`, `elision`.

Custom analyzer example:
```json
PUT /products
{
  "settings": {
    "analysis": {
      "analyzer": {
        "product_analyzer": {
          "type": "custom",
          "char_filter": ["html_strip"],
          "tokenizer": "standard",
          "filter": ["lowercase", "english_stop", "english_stemmer", "asciifolding"]
        }
      },
      "filter": {
        "english_stop": { "type": "stop", "stopwords": "_english_" },
        "english_stemmer": { "type": "stemmer", "language": "english" }
      }
    }
  }
}
```

### Query DSL

OpenSearch Query DSL is a JSON-based query language with two contexts:

- **Query context** -- "How well does this document match?" Calculates a relevance `_score`.
- **Filter context** -- "Does this document match?" Boolean yes/no, no scoring, cached.

**Compound queries:**
```json
{
  "query": {
    "bool": {
      "must": [
        { "match": { "title": "opensearch guide" } }
      ],
      "filter": [
        { "term": { "status": "published" } },
        { "range": { "publish_date": { "gte": "2024-01-01" } } }
      ],
      "should": [
        { "term": { "featured": true } }
      ],
      "must_not": [
        { "term": { "language": "deprecated" } }
      ],
      "minimum_should_match": 1
    }
  }
}
```

**Full-text queries:**
- `match` -- Standard full-text query. Analyzes the input, matches any token. Use `operator: "and"` to require all tokens.
- `match_phrase` -- Matches exact phrase in order. Use `slop` for proximity.
- `multi_match` -- Search across multiple fields. Types: `best_fields` (default), `most_fields`, `cross_fields`, `phrase`, `phrase_prefix`.
- `query_string` -- Supports Lucene query syntax (+, -, AND, OR, wildcards). Powerful but risky with user input.
- `simple_query_string` -- Safer variant; never throws exceptions on malformed input.

**Term-level queries (no analysis, exact match):**
- `term` -- Exact value match (keyword fields, numbers, dates).
- `terms` -- Match any of a set of values.
- `range` -- Numeric or date ranges (`gte`, `gt`, `lte`, `lt`).
- `exists` -- Field exists and has a non-null value.
- `prefix`, `wildcard`, `regexp`, `fuzzy` -- Pattern matching on keyword fields.
- `ids` -- Match by document `_id`.

**Joining queries:**
- `nested` -- Query nested objects (requires `nested` field type). Each nested object is indexed as a hidden separate Lucene document.
- `has_child` / `has_parent` -- Query parent-child relationships (requires `join` field type).

**Relevance tuning:**
```json
{
  "query": {
    "function_score": {
      "query": { "match": { "title": "opensearch" } },
      "functions": [
        {
          "filter": { "term": { "featured": true } },
          "weight": 10
        },
        {
          "field_value_factor": {
            "field": "popularity",
            "modifier": "log1p",
            "factor": 2
          }
        },
        {
          "gauss": {
            "publish_date": {
              "origin": "now",
              "scale": "30d",
              "decay": 0.5
            }
          }
        }
      ],
      "score_mode": "sum",
      "boost_mode": "multiply"
    }
  }
}
```

### k-NN Vector Search

OpenSearch provides approximate k-nearest neighbor (k-NN) search via the k-NN plugin, supporting multiple engines:

**Engines:**
- **Faiss** (Facebook AI Similarity Search) -- Best for large-scale deployments. Supports HNSW and IVF algorithms. Includes advanced encoders (fp16, SQ, PQ).
- **Lucene** -- Native Lucene HNSW implementation. Good for smaller deployments. Supports smart filtering (auto-selects pre-filter, post-filter, or exact k-NN).
- **NMSLIB** -- Deprecated in 3.0. Legacy HNSW implementation. Migrate to Faiss or Lucene.

**HNSW index creation:**
```json
PUT /my-knn-index
{
  "settings": {
    "index": {
      "knn": true,
      "number_of_shards": 3,
      "number_of_replicas": 1
    }
  },
  "mappings": {
    "properties": {
      "my_vector": {
        "type": "knn_vector",
        "dimension": 768,
        "method": {
          "name": "hnsw",
          "space_type": "cosinesimil",
          "engine": "faiss",
          "parameters": {
            "ef_construction": 256,
            "m": 16
          }
        }
      }
    }
  }
}
```

**k-NN search:**
```json
POST /my-knn-index/_search
{
  "size": 10,
  "query": {
    "knn": {
      "my_vector": {
        "vector": [0.1, 0.2, ...],
        "k": 10
      }
    }
  }
}
```

**Memory estimation (HNSW):** `1.1 * (4 * dimension + 8 * M) bytes/vector`

### Neural Search and Hybrid Search

Neural search uses ML models to generate embeddings at index and query time:

**Search pipeline for hybrid search (combining BM25 + k-NN):**
```json
PUT /_search/pipeline/hybrid-pipeline
{
  "description": "Hybrid search pipeline with normalization",
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
  ]
}
```

**Hybrid query:**
```json
POST /my-index/_search?search_pipeline=hybrid-pipeline
{
  "query": {
    "hybrid": {
      "queries": [
        { "match": { "text": "search query" } },
        { "knn": { "embedding": { "vector": [0.1, 0.2, ...], "k": 10 } } }
      ]
    }
  }
}
```

Normalization techniques: `min_max`, `l2`. Combination techniques: `arithmetic_mean`, `geometric_mean`, `harmonic_mean`.

### Index State Management (ISM)

ISM automates index lifecycle through policies with states, actions, and transitions. ISM is OpenSearch's equivalent of Elasticsearch's ILM (Index Lifecycle Management).

**ISM policy example:**
```json
PUT _plugins/_ism/policies/log-rotation
{
  "policy": {
    "description": "Rotate logs: hot -> warm -> cold -> delete",
    "default_state": "hot",
    "states": [
      {
        "name": "hot",
        "actions": [
          { "rollover": { "min_index_age": "1d", "min_size": "50gb" } }
        ],
        "transitions": [
          { "state_name": "warm", "conditions": { "min_index_age": "7d" } }
        ]
      },
      {
        "name": "warm",
        "actions": [
          { "replica_count": { "number_of_replicas": 1 } },
          { "force_merge": { "max_num_segments": 1 } }
        ],
        "transitions": [
          { "state_name": "cold", "conditions": { "min_index_age": "30d" } }
        ]
      },
      {
        "name": "cold",
        "actions": [
          { "read_only": {} }
        ],
        "transitions": [
          { "state_name": "delete", "conditions": { "min_index_age": "90d" } }
        ]
      },
      {
        "name": "delete",
        "actions": [
          { "delete": {} }
        ],
        "transitions": []
      }
    ],
    "ism_template": [
      { "index_patterns": ["logs-*"], "priority": 100 }
    ]
  }
}
```

**ISM actions:** `rollover`, `force_merge`, `read_only`, `read_write`, `replica_count`, `shrink`, `close`, `open`, `delete`, `snapshot`, `index_priority`, `allocation`, `notification`.

**ISM vs ILM differences:**
- ISM uses `_plugins/_ism/` API prefix (vs `_ilm/` in Elasticsearch)
- ISM policies have explicit state machine with named states and transitions
- ILM uses phase-based approach (hot, warm, cold, frozen, delete)
- ISM evaluates transitions every 5-8 minutes by default (`plugins.index_state_management.job_interval`)

### Security Plugin

OpenSearch ships with the security plugin enabled by default. It provides:

- **Authentication** -- Internal user database, LDAP/AD, SAML, OpenID Connect, Kerberos, HTTP basic, client certificates, proxy authentication
- **Authorization** -- Role-based access control (RBAC) with fine-grained permissions
- **Field-level security (FLS)** -- Restrict which fields a role can see
- **Document-level security (DLS)** -- Restrict which documents a role can see using query filters
- **Field masking** -- Anonymize sensitive field values
- **Audit logging** -- Log security events (authentication attempts, privilege escalation, index access)
- **Encryption** -- TLS for node-to-node (transport) and client-to-node (REST) communication

**Role definition:**
```json
PUT _plugins/_security/api/roles/log_reader
{
  "cluster_permissions": ["cluster_composite_ops_ro"],
  "index_permissions": [
    {
      "index_patterns": ["logs-*"],
      "allowed_actions": ["read", "search"],
      "fls": ["~sensitive_field"],
      "dls": "{\"bool\": {\"must\": {\"term\": {\"department\": \"${attr.internal.department}\"}}}}"
    }
  ],
  "tenant_permissions": [
    {
      "tenant_patterns": ["analyst_tenant"],
      "allowed_actions": ["kibana_all_read"]
    }
  ]
}
```

**Role mapping:**
```json
PUT _plugins/_security/api/rolesmapping/log_reader
{
  "backend_roles": ["analysts"],
  "hosts": ["*.example.com"],
  "users": ["analyst1", "analyst2"]
}
```

**Configuration files** (for initial setup via `securityadmin.sh`):
- `config.yml` -- Authentication and authorization backends
- `internal_users.yml` -- Internal user database
- `roles.yml` -- Role definitions
- `roles_mapping.yml` -- Role-to-user/backend-role mappings
- `action_groups.yml` -- Named groups of permissions
- `tenants.yml` -- Tenant definitions for multi-tenancy in Dashboards

### Anomaly Detection

The anomaly detection plugin uses the Random Cut Forest (RCF) algorithm to detect anomalies in streaming data:

```json
POST _plugins/_anomaly_detection/detectors
{
  "name": "high_error_rate_detector",
  "description": "Detect anomalous error rates",
  "time_field": "@timestamp",
  "indices": ["logs-*"],
  "feature_aggregation": [
    {
      "feature_name": "error_count",
      "feature_enabled": true,
      "aggregation_query": {
        "error_count": {
          "filter": { "term": { "level": "ERROR" } },
          "aggs": { "count": { "value_count": { "field": "_id" } } }
        }
      }
    }
  ],
  "detection_interval": { "period": { "interval": 5, "unit": "Minutes" } },
  "window_delay": { "period": { "interval": 1, "unit": "Minutes" } }
}
```

Pair with the alerting plugin for notifications when anomalies are detected.

### Alerting

The alerting plugin monitors data and sends notifications. Since OpenSearch 2.0, notification channels replaced alerting destinations.

**Monitor types:** per-query, per-bucket, per-cluster-metrics, per-document, composite.

**Monitor example:**
```json
POST _plugins/_alerting/monitors
{
  "type": "monitor",
  "name": "High Error Rate Monitor",
  "monitor_type": "query_level_monitor",
  "enabled": true,
  "schedule": {
    "period": { "interval": 5, "unit": "MINUTES" }
  },
  "inputs": [
    {
      "search": {
        "indices": ["logs-*"],
        "query": {
          "size": 0,
          "query": {
            "bool": {
              "filter": [
                { "range": { "@timestamp": { "gte": "now-5m" } } },
                { "term": { "level": "ERROR" } }
              ]
            }
          },
          "aggs": { "error_count": { "value_count": { "field": "_id" } } }
        }
      }
    }
  ],
  "triggers": [
    {
      "query_level_trigger": {
        "name": "High errors",
        "severity": "1",
        "condition": {
          "script": { "source": "ctx.results[0].aggregations.error_count.value > 100", "lang": "painless" }
        },
        "actions": [
          {
            "name": "Notify Slack",
            "destination_id": "slack-channel-id",
            "message_template": {
              "source": "High error rate detected: {{ctx.results[0].aggregations.error_count.value}} errors in last 5 minutes"
            }
          }
        ]
      }
    }
  ]
}
```

### Observability

OpenSearch provides a comprehensive observability stack:

- **Trace Analytics** -- Distributed tracing compatible with OpenTelemetry. Dashboard views for trace groups, error rates, throughput, and service maps. Indices: `otel-v1-apm-span-*`, `otel-v1-apm-service-map*`.
- **PPL (Piped Processing Language)** -- Intuitive query language for log analytics. Pipe-delimited syntax for filtering, aggregating, and transforming data:
  ```
  source=logs-* | where level='ERROR' | stats count() by service | sort -count()
  ```
- **SQL** -- ANSI SQL support for querying OpenSearch indices via `_plugins/_sql` API.
- **Notebooks** -- Combine PPL/SQL queries, visualizations, and narrative text in collaborative notebooks.
- **Event Analytics** -- Explore and visualize events with saved queries and visualizations.
- **Metrics** -- Prometheus-compatible metrics ingestion and querying (3.x).

### Snapshot and Restore

```json
// Register S3 repository
PUT /_snapshot/my-s3-repo
{
  "type": "s3",
  "settings": {
    "bucket": "my-opensearch-snapshots",
    "base_path": "snapshots/production",
    "server_side_encryption": true,
    "max_restore_bytes_per_sec": "500mb",
    "max_snapshot_bytes_per_sec": "200mb"
  }
}

// Create snapshot
PUT /_snapshot/my-s3-repo/snapshot-2026-04-07?wait_for_completion=true
{
  "indices": "logs-*,-logs-debug-*",
  "ignore_unavailable": true,
  "include_global_state": false
}

// Restore snapshot
POST /_snapshot/my-s3-repo/snapshot-2026-04-07/_restore
{
  "indices": "logs-2026.03.*",
  "ignore_unavailable": true,
  "include_global_state": false,
  "rename_pattern": "(.+)",
  "rename_replacement": "restored_$1"
}
```

### Cross-Cluster Replication (CCR)

Replicates indices from a leader cluster to a follower cluster using an active-passive model:

```json
// On follower cluster: configure remote connection
PUT /_cluster/settings
{
  "persistent": {
    "cluster.remote.leader-cluster": {
      "seeds": ["leader-node1:9300", "leader-node2:9300"]
    }
  }
}

// Start replication
PUT /_plugins/_replication/follower-index/_start
{
  "leader_alias": "leader-cluster",
  "leader_index": "leader-index",
  "use_roles": {
    "leader_cluster_role": "cross_cluster_replication_leader_full_access",
    "follower_cluster_role": "cross_cluster_replication_follower_full_access"
  }
}
```

### Cross-Cluster Search

Query indices across multiple clusters:

```json
// Configure remote cluster
PUT /_cluster/settings
{
  "persistent": {
    "cluster.remote.cluster-b": {
      "seeds": ["cluster-b-node:9300"]
    }
  }
}

// Search across clusters
POST /local-index,cluster-b:remote-index/_search
{
  "query": { "match": { "title": "opensearch" } }
}
```

### OpenSearch Serverless (AOSS) on AWS

Amazon OpenSearch Serverless is a serverless deployment option for OpenSearch on AWS:

- **Collections** -- Logical groupings of indices. Three types: search, time-series, vector search.
- **OCUs (OpenSearch Compute Units)** -- Each OCU = 1 vCPU + 6 GiB RAM + 120 GiB storage. Minimum 2 OCUs (dev/test without redundancy) or 4 OCUs (production with redundancy).
- **Auto-scaling** -- Scales OCUs based on indexing and search workload. Configurable min/max limits.
- **Capacity limits** -- Up to 1 TiB per index (search/vector), 100 TiB per index (time-series).
- **Security** -- Encryption policies, network policies, and data access policies (instead of security plugin).
- **Limitations** -- No ISM, no alerting, no anomaly detection, no cross-cluster operations. Subset of OpenSearch APIs.

## Version Summary

| Version | Status | Lucene | Java | Key Features |
|---------|--------|--------|------|-------------|
| 1.x | Deprecated (May 2025) | 8.x | 11+ | Initial fork from ES 7.10 |
| 2.x | Maintenance | 9.x | 11+ | Neural search, k-NN improvements, search pipelines, segment replication, flat_object |
| 3.x | Active (current) | 10.x | 21+ | Agentic search, gRPC transport, GPU acceleration, workspaces, HTTP/3 |

## Troubleshooting Decision Tree

```
Problem reported
  |
  +-- Cluster health red/yellow?
  |     --> references/diagnostics.md (Cluster Health section)
  |     --> GET _cluster/allocation/explain
  |
  +-- Slow search queries?
  |     --> references/diagnostics.md (Search Performance section)
  |     --> Check slow logs, profile API, hot threads
  |
  +-- High memory/GC pressure?
  |     --> references/diagnostics.md (JVM/Memory section)
  |     --> Check circuit breakers, fielddata, segment memory
  |
  +-- Indexing throughput low?
  |     --> references/best-practices.md (Indexing Performance section)
  |     --> Check refresh interval, bulk size, merge throttle
  |
  +-- Security/access issues?
  |     --> GET _plugins/_security/api/roles
  |     --> GET _plugins/_security/authinfo
  |     --> Check audit logs
  |
  +-- ISM policy not executing?
  |     --> GET _plugins/_ism/explain/index-name
  |     --> Check policy validation, state transitions
  |
  +-- k-NN search slow or OOM?
  |     --> references/diagnostics.md (k-NN section)
  |     --> Check circuit_breaker_limit, warmup, graph memory
  |
  +-- Migration from Elasticsearch?
        --> Check API compatibility, plugin equivalents, terminology changes
```
