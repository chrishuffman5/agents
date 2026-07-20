# Elasticsearch Operations

## Snapshot and Restore

Snapshots provide cluster-level or index-level backup to a repository:

```json
PUT _snapshot/my-s3-repo
{
  "type": "s3",
  "settings": {
    "bucket": "my-es-backups",
    "base_path": "snapshots",
    "compress": true,
    "server_side_encryption": true
  }
}

PUT _snapshot/my-s3-repo/snapshot-2024-01-15?wait_for_completion=false
{
  "indices": "logs-*,metrics-*",
  "ignore_unavailable": true,
  "include_global_state": false
}

POST _snapshot/my-s3-repo/snapshot-2024-01-15/_restore
{
  "indices": "logs-2024.01.*",
  "rename_pattern": "logs-(.+)",
  "rename_replacement": "restored-logs-$1"
}
```

Snapshot Lifecycle Management (SLM) automates snapshot creation:
```json
PUT _slm/policy/daily-snapshots
{
  "schedule": "0 30 1 * * ?",
  "name": "<daily-snap-{now/d}>",
  "repository": "my-s3-repo",
  "config": {
    "indices": ["*"],
    "ignore_unavailable": true,
    "include_global_state": false
  },
  "retention": {
    "expire_after": "30d",
    "min_count": 5,
    "max_count": 50
  }
}
```

## Cross-Cluster Search and Replication

**Cross-Cluster Search (CCS):**
```json
PUT _cluster/settings
{
  "persistent": {
    "cluster.remote.cluster_two": {
      "seeds": ["cluster2-node1:9300"],
      "transport.compress": true,
      "skip_unavailable": true
    }
  }
}

GET /cluster_two:logs-*/_search
{
  "query": { "match": { "message": "error" } }
}
```

**Cross-Cluster Replication (CCR):**
```json
PUT /follower-index/_ccr/follow
{
  "remote_cluster": "leader-cluster",
  "leader_index": "leader-index"
}
```

CCR supports auto-follow patterns for new indices matching a pattern on the leader cluster.

## Ingest Pipelines

Ingest pipelines process documents before indexing:

```json
PUT _ingest/pipeline/web-logs
{
  "description": "Process web access logs",
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
      "convert": {
        "field": "bytes",
        "type": "long"
      }
    },
    {
      "remove": {
        "field": ["message", "agent"],
        "ignore_missing": true
      }
    },
    {
      "set": {
        "field": "ingest_timestamp",
        "value": "{{{_ingest.timestamp}}}"
      }
    }
  ],
  "on_failure": [
    {
      "set": {
        "field": "_index",
        "value": "failed-logs"
      }
    },
    {
      "set": {
        "field": "error.message",
        "value": "{{ _ingest.on_failure_message }}"
      }
    }
  ]
}
```

Enrich processor for data enrichment:
```json
PUT _enrich/policy/users-policy
{
  "match": {
    "indices": "users",
    "match_field": "email",
    "enrich_fields": ["full_name", "department", "role"]
  }
}

POST _enrich/policy/users-policy/_execute

PUT _ingest/pipeline/enrich-events
{
  "processors": [
    {
      "enrich": {
        "policy_name": "users-policy",
        "field": "user_email",
        "target_field": "user_info",
        "max_matches": 1
      }
    }
  ]
}
```

## Performance Tuning

**Indexing performance:**
```json
PUT /my-index/_settings
{
  "index.refresh_interval": "30s",
  "index.translog.durability": "async",
  "index.translog.sync_interval": "30s",
  "index.translog.flush_threshold_size": "1gb"
}
```

Bulk API best practices:
- Target 5-15MB per bulk request (not document count)
- Use parallel bulk requests (number of data nodes is a good starting point)
- Start with a bulk_size of 1000-5000 documents and tune based on response times
- Monitor `_nodes/stats/indices/indexing` for indexing rate and rejected count

**Search performance:**
- Use `filter` context for non-scoring clauses (cached, faster)
- Avoid deep pagination; use `search_after` or scroll/PIT instead of `from` + `size` beyond 10,000
- Profile slow queries with `"profile": true` in the search body
- Use `_source` filtering or `stored_fields` to reduce network transfer
- Enable `index.queries.cache.enabled` for frequently used filters
- Set `index.max_result_window` thoughtfully (default 10,000)

**Circuit breakers:**
```json
PUT _cluster/settings
{
  "persistent": {
    "indices.breaker.total.limit": "70%",
    "indices.breaker.request.limit": "40%",
    "indices.breaker.fielddata.limit": "30%",
    "network.breaker.inflight_requests.limit": "100%"
  }
}
```

**JVM heap sizing:**
- Never exceed 50% of physical RAM (leave the other 50% for Lucene OS cache)
- Maximum recommended: ~31GB to stay under compressed ordinary object pointers (compressed oops) threshold
- Set `-Xms` and `-Xmx` to the same value to avoid heap resizing
- Configure in `jvm.options` or `ES_JAVA_OPTS`

## Text Search and Relevance Tuning

**BM25 (default scoring algorithm):**
- `k1` (default 1.2) -- Controls term frequency saturation. Lower values reduce impact of repeating terms. Higher values increase it.
- `b` (default 0.75) -- Controls field length normalization. 0 disables normalization (all field lengths treated equally). 1 gives full normalization.
- Configure per-field in mapping:

```json
{
  "mappings": {
    "properties": {
      "content": {
        "type": "text",
        "similarity": "custom_bm25"
      }
    }
  },
  "settings": {
    "similarity": {
      "custom_bm25": {
        "type": "BM25",
        "k1": 1.5,
        "b": 0.5
      }
    }
  }
}
```

**Boosting strategies:**
```json
{
  "query": {
    "multi_match": {
      "query": "elasticsearch performance",
      "fields": ["title^3", "summary^2", "body"],
      "type": "best_fields",
      "tie_breaker": 0.3
    }
  }
}
```

**Explain API for debugging relevance:**
```
GET /my-index/_explain/doc-123
{
  "query": { "match": { "title": "elasticsearch" } }
}
```
