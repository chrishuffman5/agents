---
name: elasticsearch
description: "Elasticsearch as a general-purpose search/database engine covering ALL versions: full-text search, index management, cluster operations, Query DSL, aggregations, mappings, and operational tuning for application data. Use for \"Elasticsearch\", \"elastic\", \"index management\", \"Query DSL\", \"mapping\", \"analyzer\", \"shard\", \"replica\", \"cluster health\", \"_cat API\", \"bulk API\", \"ingest pipeline\", \"ILM\", \"snapshot\", \"cross-cluster\". Do NOT use for Elasticsearch/ELK as an observability or log-analytics backend (Kibana dashboards, Elastic Agent/Fleet, Logstash, APM, log pipelines) — that's the `elk` skill in the `monitoring` plugin. Do NOT use for Elastic SIEM/security detection content (EQL, detection rules, Elastic Security) — that's the `elastic-security` skill in the `security` plugin."
license: MIT
---

# Elasticsearch

This skill covers Elasticsearch across all supported versions (7.17 LTS through 9.x). It covers Lucene internals, distributed cluster architecture, full-text search and relevance tuning, Query DSL, aggregations, index lifecycle management, and operational tuning. For version-specific detail, see the matching file under `references/versions/`.

## When to Use This Skill vs. Version-Specific Guidance

**Use this agent when the question spans versions or is version-agnostic:**
- "How does shard allocation work in Elasticsearch?"
- "Tune search relevance with BM25 and function_score"
- "Set up cross-cluster replication"
- "Design index mappings for time-series data"
- "Best practices for cluster sizing and shard strategy"

**See the matching version reference when the question is version-specific:**
- "Elasticsearch 8 security by default" --> `references/versions/8.x.md`
- "kNN vector search in ES 8" --> `references/versions/8.x.md`
- "Elasticsearch 9 breaking changes" --> `references/versions/9.x.md`
- "Lucene 10 improvements in ES 9" --> `references/versions/9.x.md`

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Version-specific feature** -- See the matching `references/versions/<v>.md` file
   - **Comparison with other databases** -- see the `overview` skill

2. **Determine version** -- Ask if unclear. Behavior differs significantly across versions (e.g., security by default only in 8.0+, kNN search only in 8.0+, serverless architecture in 8.11+).

3. **Analyze** -- Apply Elasticsearch-specific reasoning. Reference Lucene internals, shard mechanics, relevance scoring, and cluster state as relevant.

4. **Recommend** -- Provide actionable guidance with specific REST API calls, mapping definitions, or cluster settings.

5. **Verify** -- Suggest validation steps (_cluster/health, _cat APIs, _search profiling, _explain).

## Core Expertise

### Index Architecture (Shards, Replicas, Segments)

An Elasticsearch index is a logical namespace that maps to one or more **primary shards**, each of which can have zero or more **replica shards**:

- **Primary shard** -- Holds a subset of the index's documents. The number of primary shards is fixed at index creation (changeable only via _split or _shrink APIs or reindex). Each document belongs to exactly one primary shard, determined by: `shard = hash(_routing) % number_of_primary_shards`.
- **Replica shard** -- Full copy of a primary shard on a different node. Serves read requests and provides failover. Number of replicas is adjustable dynamically.
- **Lucene segment** -- Each shard is a Lucene index composed of immutable segments. New documents go into an in-memory buffer, then are written as a new segment on refresh. Segments are periodically merged by background threads.
- **Refresh** -- Makes recently indexed documents searchable by creating a new Lucene segment from the in-memory buffer. Default interval: 1 second (near-real-time search). Set `index.refresh_interval` to `-1` for bulk indexing, then reset.
- **Flush** -- Commits the Lucene segments to disk and clears the translog. Ensures durability. Happens automatically based on translog size or on explicit `_flush` API call.
- **Translog** -- Write-ahead log per shard. Every indexing operation is written to the translog before being acknowledged. On crash recovery, the translog replays uncommitted operations.

**Key implication:** Too many shards causes overhead (each shard consumes memory, file descriptors, and CPU for segment merging). Too few shards limits parallelism. Target 10-50GB per shard, and avoid exceeding 20 shards per GB of heap.

### Mapping and Analysis

Mappings define how documents and their fields are stored and indexed:

- **Dynamic mapping** -- Elasticsearch auto-detects field types. Convenient but often wrong (strings become both `text` and `keyword` by default, dates may be misidentified). Always define explicit mappings for production.
- **Field types** -- `text` (analyzed, full-text search), `keyword` (exact match, aggregations, sorting), `integer`/`long`/`float`/`double`, `date`, `boolean`, `object`, `nested`, `geo_point`, `geo_shape`, `dense_vector`, `ip`, `completion`.
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
        },
        "autocomplete_analyzer": {
          "type": "custom",
          "tokenizer": "autocomplete_tokenizer",
          "filter": ["lowercase"]
        }
      },
      "tokenizer": {
        "autocomplete_tokenizer": {
          "type": "edge_ngram",
          "min_gram": 2,
          "max_gram": 15,
          "token_chars": ["letter", "digit"]
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

**Normalizers** -- For keyword fields, apply character-level transformations (lowercase, asciifolding) without tokenization:
```json
"settings": {
  "analysis": {
    "normalizer": {
      "lowercase_normalizer": {
        "type": "custom",
        "filter": ["lowercase", "asciifolding"]
      }
    }
  }
}
```

### Query DSL

Elasticsearch Query DSL is a JSON-based query language with two contexts:

- **Query context** -- "How well does this document match?" Calculates a relevance `_score`.
- **Filter context** -- "Does this document match?" Boolean yes/no, no scoring, cached.

**Compound queries:**
```json
{
  "query": {
    "bool": {
      "must": [
        { "match": { "title": "elasticsearch guide" } }
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
- `has_child` / `has_parent` -- Query parent-child relationships (requires `join` field type). Documents must be on the same shard.

**Relevance tuning:**
```json
{
  "query": {
    "function_score": {
      "query": { "match": { "title": "elasticsearch" } },
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

`script_score` for custom scoring:
```json
{
  "query": {
    "script_score": {
      "query": { "match_all": {} },
      "script": {
        "source": "cosineSimilarity(params.query_vector, 'embedding_field') + 1.0",
        "params": {
          "query_vector": [0.1, 0.2, 0.3]
        }
      }
    }
  }
}
```

### Aggregations

Three main types of aggregations:

**Bucket aggregations** -- Group documents into buckets:
```json
{
  "aggs": {
    "by_status": {
      "terms": { "field": "status.keyword", "size": 20 },
      "aggs": {
        "avg_response_time": { "avg": { "field": "response_time_ms" } }
      }
    },
    "by_date": {
      "date_histogram": {
        "field": "timestamp",
        "calendar_interval": "day"
      }
    },
    "price_ranges": {
      "range": {
        "field": "price",
        "ranges": [
          { "to": 50 },
          { "from": 50, "to": 200 },
          { "from": 200 }
        ]
      }
    },
    "by_location": {
      "geohash_grid": { "field": "location", "precision": 5 }
    }
  }
}
```

**Metric aggregations** -- Calculate metrics over documents:
```json
{
  "aggs": {
    "avg_price": { "avg": { "field": "price" } },
    "max_price": { "max": { "field": "price" } },
    "price_stats": { "stats": { "field": "price" } },
    "price_percentiles": { "percentiles": { "field": "price", "percents": [50, 95, 99] } },
    "unique_users": { "cardinality": { "field": "user_id" } },
    "top_hits_per_bucket": {
      "top_hits": { "size": 3, "sort": [{ "timestamp": "desc" }] }
    }
  }
}
```

**Pipeline aggregations** -- Process output of other aggregations:
```json
{
  "aggs": {
    "sales_per_month": {
      "date_histogram": { "field": "date", "calendar_interval": "month" },
      "aggs": {
        "total_sales": { "sum": { "field": "amount" } }
      }
    },
    "max_monthly_sales": {
      "max_bucket": { "buckets_path": "sales_per_month>total_sales" }
    },
    "moving_avg_sales": {
      "moving_fn": {
        "buckets_path": "sales_per_month>total_sales",
        "window": 3,
        "script": "MovingFunctions.unweightedAvg(values)"
      }
    },
    "sales_derivative": {
      "derivative": { "buckets_path": "sales_per_month>total_sales" }
    }
  }
}
```

### Cluster Architecture

Elasticsearch is a distributed system with multiple node roles:

| Node Role | Flag | Purpose | Sizing |
|---|---|---|---|
| **Master-eligible** | `node.roles: [master]` | Manages cluster state (mappings, settings, shard allocation). Lightweight. | 3 dedicated masters minimum for production. Low CPU/RAM/disk. |
| **Data** | `node.roles: [data]` | Stores data and executes search/aggregation. The workhorse. | High CPU, RAM (heap + OS cache), fast SSD. |
| **Data Content** | `node.roles: [data_content]` | Stores non-time-series data (catalog, user data). | Balanced CPU/RAM/disk. |
| **Data Hot** | `node.roles: [data_hot]` | Stores newest, most-queried time-series data. | Fast SSD/NVMe, high CPU. |
| **Data Warm** | `node.roles: [data_warm]` | Stores older time-series data with fewer queries. | Larger HDD, moderate CPU. |
| **Data Cold** | `node.roles: [data_cold]` | Stores rarely queried data, potentially searchable snapshots. | Large HDD, minimal CPU. |
| **Data Frozen** | `node.roles: [data_frozen]` | Searchable snapshots only (data in object storage). | Minimal local disk, uses shared cache. |
| **Ingest** | `node.roles: [ingest]` | Runs ingest pipelines (Grok, GeoIP, enrichment). | CPU-heavy, moderate RAM. |
| **Coordinating-only** | `node.roles: []` | Routes requests, scatters/gathers search results. | High RAM for aggregation reduce phase. |
| **ML** | `node.roles: [ml]` | Runs machine learning jobs (anomaly detection, NLP inference). | GPU-optional, high RAM. |
| **Transform** | `node.roles: [transform]` | Runs continuous transforms (pivot, latest). | Moderate CPU/RAM. |
| **Remote Cluster Client** | `node.roles: [remote_cluster_client]` | Enables cross-cluster search. | Minimal. |

**Cluster state:** The master node manages a global cluster state including:
- Index metadata (mappings, settings, aliases)
- Shard routing table (which shard on which node)
- Node membership
- Persistent and transient cluster settings

**Shard allocation:** Controlled by the master using allocation deciders:
- Disk watermark (low: 85%, high: 90%, flood stage: 95%)
- Awareness attributes (rack, zone, region)
- Filtering (include/exclude/require by node attributes)
- Rebalancing thresholds

### Index Lifecycle Management (ILM)

ILM automates the management of indices through lifecycle phases:

```json
PUT _ilm/policy/logs-policy
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_primary_shard_size": "50gb",
            "max_age": "1d"
          },
          "set_priority": { "priority": 100 }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": { "number_of_shards": 1 },
          "forcemerge": { "max_num_segments": 1 },
          "allocate": {
            "number_of_replicas": 1,
            "require": { "data": "warm" }
          },
          "set_priority": { "priority": 50 }
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "allocate": {
            "number_of_replicas": 0,
            "require": { "data": "cold" }
          },
          "set_priority": { "priority": 0 }
        }
      },
      "frozen": {
        "min_age": "90d",
        "actions": {
          "searchable_snapshot": {
            "snapshot_repository": "my-s3-repo"
          }
        }
      },
      "delete": {
        "min_age": "365d",
        "actions": { "delete": {} }
      }
    }
  }
}
```

Attach the policy to an index template:
```json
PUT _index_template/logs-template
{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1,
      "index.lifecycle.name": "logs-policy",
      "index.lifecycle.rollover_alias": "logs-write"
    }
  }
}
```

### Snapshot and Restore

See `references/operations.md#snapshot-and-restore` — S3 repository setup, snapshot/restore API calls, and Snapshot Lifecycle Management (SLM) policies.

### Cross-Cluster Search and Replication

See `references/operations.md#cross-cluster-search-and-replication` — Cross-Cluster Search (CCS) remote cluster setup and Cross-Cluster Replication (CCR) follower index configuration.

### Security

Elastic Security provides layered security:

- **Authentication** -- Native realm, LDAP, Active Directory, SAML, OIDC, PKI, Kerberos, API keys, service tokens.
- **Authorization** -- Role-based access control (RBAC) with cluster privileges, index privileges, field-level security, document-level security.
- **Encryption** -- TLS for node-to-node (transport layer) and client-to-node (HTTP layer).
- **Audit logging** -- Track authentication, authorization, and data access events.

Role example with field-level and document-level security:
```json
POST _security/role/restricted_analyst
{
  "cluster": ["monitor"],
  "indices": [
    {
      "names": ["logs-*"],
      "privileges": ["read"],
      "field_security": {
        "grant": ["timestamp", "message", "level", "service"],
        "except": ["user.email", "user.ip"]
      },
      "query": {
        "term": { "environment": "production" }
      }
    }
  ]
}
```

API key creation:
```json
POST _security/api_key
{
  "name": "ingest-key",
  "role_descriptors": {
    "ingest_role": {
      "cluster": ["monitor"],
      "indices": [
        {
          "names": ["logs-*"],
          "privileges": ["create_index", "write", "manage"]
        }
      ]
    }
  },
  "expiration": "30d"
}
```

### Ingest Pipelines

See `references/operations.md#ingest-pipelines` — processor types (grok, date, geoip, user_agent, convert, remove, set), pipeline failure handling, and the enrich processor for data enrichment.

### Performance Tuning

See `references/operations.md#performance-tuning` — indexing performance settings, bulk API sizing, search performance tuning, circuit breakers, and JVM heap sizing.

### Text Search and Relevance Tuning

See `references/operations.md#text-search-and-relevance-tuning` — BM25 parameter tuning, per-field similarity configuration, boosting strategies, and the Explain API for debugging relevance.

## Common Pitfalls

1. **Mapping explosion** -- Dynamic mapping with high-cardinality fields (e.g., user-generated keys in JSON) creates thousands of fields. Set `index.mapping.total_fields.limit` (default 1000) and use `strict` dynamic mapping or `flattened` field type.

2. **Over-sharding** -- Creating too many small shards wastes cluster resources. Each shard has fixed overhead (~10MB heap). A 1TB index with 1000 shards of 1GB each is far worse than 20 shards of 50GB. Target 10-50GB per shard.

3. **Deep pagination with from/size** -- `from: 100000, size: 10` requires coordinating node to fetch and sort 100,010 documents from each shard. Use `search_after` with a PIT (point in time) for deep pagination.

4. **Analyzing keyword-intended fields** -- Storing email addresses or status codes as `text` type splits them into tokens. Use `keyword` for exact match fields. Use multi-fields if you need both.

5. **Not using filter context** -- Putting non-scoring clauses in `must` instead of `filter` wastes CPU on scoring and misses the filter cache.

6. **Fielddata on text fields** -- Aggregating or sorting on `text` fields loads fielddata into heap (expensive). Use `keyword` multi-field for aggregations, or use `doc_values` (default for keyword, numeric, date).

7. **Ignoring disk watermarks** -- When disk usage hits flood stage (95%), Elasticsearch makes indices read-only. Requires manual intervention: `PUT /index/_settings { "index.blocks.read_only_allow_delete": null }` after freeing space.

8. **Bulk indexing without tuning** -- Default settings (1s refresh, sync translog) during bulk ingestion waste I/O. Set `refresh_interval: -1` and `translog.durability: async` during bulk loads, then restore.

9. **Scroll context leaks** -- Open scroll contexts hold resources. Always clear them with `DELETE _search/scroll`. Prefer Point in Time (PIT) + `search_after` (7.10+) over scroll for most use cases.

10. **Nested field overuse** -- Each nested object is a separate Lucene document. An array of 100 nested objects creates 101 Lucene documents. Use `flattened` or denormalize if you do not need per-object querying.

## Version-specific guidance

| Version | Status | Key Feature | Reference |
|---|---|---|---|
| **Elasticsearch 8.x** | Current GA (8.0-8.17+) | Security by default, kNN vector search, NLP inference, serverless | `references/versions/8.x.md` |
| **Elasticsearch 9.x** | Latest (2025+) | Lucene 10, logsdb default, TSDB enhancements, breaking changes from 8.x | `references/versions/9.x.md` |

## Reference Files

Load these when you need deep knowledge for a specific area:

- `references/architecture.md` -- Lucene internals (inverted index, doc values, segments), node roles, cluster state, shard allocation, translog, refresh vs flush, circuit breakers. Read for "how does Elasticsearch work internally" questions.
- `references/diagnostics.md` -- 100+ REST API diagnostic commands with curl format. Cluster health, node stats, shard analysis, query profiling, JVM monitoring, task management. Read when troubleshooting performance or cluster issues.
- `references/best-practices.md` -- Cluster sizing, shard strategy, mapping design, JVM heap, monitoring, security hardening, backup strategies. Read for configuration and operational guidance.
