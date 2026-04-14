# OpenSearch Best Practices Reference

## Cluster Sizing

### Node Count and Roles

**Minimum production cluster:**
- 3 dedicated cluster manager nodes (fault-tolerant leader election)
- 2+ data nodes (for replica shard placement)
- Optional: dedicated coordinating node(s) for heavy aggregation workloads
- Optional: dedicated ingest node(s) for heavy pipeline processing
- Optional: dedicated ML node(s) for anomaly detection and neural search models

**Sizing formula (data nodes):**
```
Total data volume = raw_data * (1 + number_of_replicas) * (1 + overhead_factor)
  overhead_factor ~= 0.1 to 0.5 (depends on mappings, _source, doc values)

Number of data nodes = total_data_volume / usable_disk_per_node
  usable_disk_per_node = total_disk * 0.85 (leave 15% for watermarks and merges)

Heap per data node = min(31GB, 50% of RAM)
  Remaining RAM = OS page cache for Lucene segments
```

**Example: 10TB raw logs/day, 30 days retention, 1 replica:**
```
Total storage = 10TB/day * 30 days * 2 (1 replica) * 1.15 (overhead) = ~690TB
Per node (8TB SSD): 690TB / (8TB * 0.85) = ~102 data nodes
Heap: 31GB per node, 64GB+ RAM per node recommended
```

### Cluster Manager Node Sizing

| Cluster Size | Manager Nodes | Manager Heap | Manager CPU |
|---|---|---|---|
| < 20 data nodes | 3 dedicated | 4-8GB | 2-4 cores |
| 20-100 data nodes | 3 dedicated | 8-16GB | 4-8 cores |
| 100+ data nodes | 3-5 dedicated | 16-32GB | 8+ cores |

Cluster manager node heap sizing depends on the number of indices, shards, and the size of the cluster state.

### JVM Heap Sizing

**Rules:**
1. Never allocate more than 50% of physical RAM to heap (Lucene needs the other half for OS page cache)
2. Never exceed ~31GB heap (to stay below the compressed ordinary object pointers threshold)
3. Set `-Xms` and `-Xmx` to the same value (avoid heap resizing)
4. Use G1GC (default in OpenSearch)

```bash
# /etc/opensearch/jvm.options.d/heap.options
-Xms31g
-Xmx31g
```

**Compressed oops threshold:**
- Below ~32GB heap, the JVM uses compressed ordinary object pointers (32-bit references)
- Above ~32GB, the JVM switches to 64-bit pointers, effectively reducing usable heap
- Setting heap to exactly 32GB gives you LESS usable heap than 31GB

**Heap usage breakdown (typical):**
| Component | Typical % of Heap | Notes |
|---|---|---|
| Segment metadata | 20-40% | Grows with number of segments/fields |
| Indexing buffers | 10-15% | `indices.memory.index_buffer_size: 10%` |
| Query/request cache | 5-15% | `indices.queries.cache.size: 10%` |
| Fielddata cache | 0-30% | Should be near 0 if using doc values properly |
| k-NN graph cache | 0-50% | Controlled by `knn.memory.circuit_breaker.limit` |
| Network buffers | 5-10% | HTTP and transport layer |
| Overhead/other | 10-20% | GC overhead, internal structures |

### Shard Sizing Strategy

**Target: 10-50GB per shard.** This range balances search performance, recovery time, and resource overhead.

| Shard Size | Trade-off |
|---|---|
| < 1GB | Too small. Excessive overhead. Thousands of tiny shards waste heap and CPU. |
| 1-10GB | Acceptable for small indices. Fast recovery but more shards per index. |
| **10-50GB** | **Ideal range.** Good balance of search speed, merge efficiency, and recovery time. |
| 50-200GB | Large. Slower recovery, longer merge times. But fewer shards overall. |
| > 200GB | Too large. Recovery takes very long, search latency increases. |

**Rule of thumb:** Avoid exceeding 20 shards per GB of heap. A node with 31GB heap should hold at most ~600 shards.

## Indexing Performance

### Bulk Indexing

Always use the `_bulk` API for batch operations:

```json
POST /_bulk
{"index": {"_index": "logs", "_id": "1"}}
{"@timestamp": "2026-04-07T12:00:00Z", "message": "event 1"}
{"index": {"_index": "logs", "_id": "2"}}
{"@timestamp": "2026-04-07T12:00:01Z", "message": "event 2"}
```

**Bulk sizing guidelines:**
- Start with 5-15MB per bulk request (not document count)
- Adjust based on response times; watch for `429 Too Many Requests`
- Use multiple parallel bulk clients (typically 2-4 per data node)
- Consider using the `_bulk` API with `pipeline` parameter for ingest pipelines

### Refresh Interval Tuning

```json
// Disable refresh during bulk loading
PUT /my-index/_settings
{ "index.refresh_interval": "-1" }

// Re-enable after bulk loading
PUT /my-index/_settings
{ "index.refresh_interval": "30s" }
```

For write-heavy workloads where near-real-time search is not required, set `index.refresh_interval` to 30s or higher. Default is 1s.

### Translog Settings

```json
PUT /my-index/_settings
{
  "index.translog.durability": "async",
  "index.translog.sync_interval": "30s",
  "index.translog.flush_threshold_size": "1024mb"
}
```

`async` durability improves indexing speed at the cost of potential data loss (up to `sync_interval` worth of data) on crash.

### Merge Policy Tuning

```json
PUT /my-index/_settings
{
  "index.merge.policy.max_merged_segment": "5gb",
  "index.merge.policy.segments_per_tier": "10",
  "index.merge.policy.max_merge_at_once": "10",
  "index.merge.scheduler.max_thread_count": 1
}
```

For spinning disks, limit merge threads to 1. For SSDs, the default (based on CPU count) is usually fine.

### Index Template Best Practices

```json
PUT /_index_template/logs-template
{
  "index_patterns": ["logs-*"],
  "priority": 200,
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1,
      "index.refresh_interval": "30s",
      "index.codec": "best_compression",
      "index.mapping.total_fields.limit": 2000,
      "index.mapping.nested_objects.limit": 10000
    },
    "mappings": {
      "dynamic": "strict",
      "properties": {
        "@timestamp": { "type": "date" },
        "message": { "type": "text", "norms": false },
        "level": { "type": "keyword" },
        "service": { "type": "keyword" },
        "host": { "type": "keyword" }
      }
    },
    "aliases": {
      "logs-current": {}
    }
  }
}
```

## Search Performance

### Query Optimization

1. **Use filter context** for non-scoring clauses. Filters are cached and skip scoring:
   ```json
   {
     "query": {
       "bool": {
         "must": [{ "match": { "title": "search query" }}],
         "filter": [
           { "term": { "status": "active" }},
           { "range": { "@timestamp": { "gte": "now-1h" }}}
         ]
       }
     }
   }
   ```

2. **Avoid deep pagination.** Use `search_after` instead of `from`/`size` for large offsets:
   ```json
   POST /my-index/_search
   {
     "size": 20,
     "sort": [{ "@timestamp": "desc" }, { "_id": "asc" }],
     "search_after": ["2026-04-07T11:00:00Z", "doc-id-123"]
   }
   ```

3. **Use `_source` filtering** to reduce response size:
   ```json
   { "_source": ["title", "timestamp", "status"], "query": { "match_all": {} } }
   ```

4. **Routing** -- If queries always filter by a key (e.g., tenant_id), use custom routing to search a single shard:
   ```json
   PUT /multi-tenant/_doc/1?routing=tenant_a
   { "tenant_id": "tenant_a", "data": "..." }

   POST /multi-tenant/_search?routing=tenant_a
   { "query": { "term": { "tenant_id": "tenant_a" } } }
   ```

5. **Profile queries** to identify bottlenecks:
   ```json
   POST /my-index/_search
   {
     "profile": true,
     "query": { "match": { "title": "opensearch" } }
   }
   ```

### Slow Log Configuration

```json
PUT /my-index/_settings
{
  "index.search.slowlog.threshold.query.warn": "10s",
  "index.search.slowlog.threshold.query.info": "5s",
  "index.search.slowlog.threshold.query.debug": "2s",
  "index.search.slowlog.threshold.query.trace": "500ms",
  "index.search.slowlog.threshold.fetch.warn": "1s",
  "index.search.slowlog.threshold.fetch.info": "800ms",
  "index.indexing.slowlog.threshold.index.warn": "10s",
  "index.indexing.slowlog.threshold.index.info": "5s"
}
```

### Caching Strategy

- **Node query cache** -- Caches filter results. Enabled by default. `indices.queries.cache.size: 10%`.
- **Shard request cache** -- Caches search results for repeated identical queries. Enabled by default for requests with `size: 0` (aggregation-only). `index.requests.cache.enable: true`.
- **Fielddata cache** -- Used for `text` field aggregations/sorting. Avoid by using `keyword` fields or doc values. Set `indices.fielddata.cache.size` to limit.

## ISM (Index State Management) Best Practices

### Policy Design Patterns

**Log rotation pattern:**
```
hot (write, rollover at 50GB or 1 day)
  --> warm (force merge to 1 segment, reduce replicas)
    --> cold (read-only, move to cold storage)
      --> delete (after 90 days)
```

**Metrics pattern:**
```
hot (write, rollover at 100GB or 7 days)
  --> rollup (create rollup index for aggregated data)
    --> delete (after 365 days)
```

### ISM Best Practices

1. **Use `ism_template`** to auto-attach policies to new indices matching patterns
2. **Set appropriate `min_index_age`** for transitions -- too frequent transitions cause overhead
3. **Monitor ISM execution** via `_plugins/_ism/explain/<index>` to check state and errors
4. **Use `error_notification`** in policies to alert on ISM failures
5. **Coordinate with data streams** -- ISM works with data stream backing indices
6. **Test policies** on non-production indices first

### ISM Error Handling

```json
{
  "policy": {
    "description": "Policy with error notification",
    "error_notification": {
      "channel": {
        "id": "notification-channel-id"
      },
      "message_template": {
        "source": "ISM policy failed on index {{ctx.index}} in state {{ctx.state}}: {{ctx.error}}"
      }
    },
    "default_state": "hot",
    "states": [...]
  }
}
```

## Security Best Practices

### Initial Setup

1. **Change default admin password immediately** after installation
2. **Generate and use TLS certificates** for both transport and REST layers
3. **Disable demo certificates** in production (`plugins.security.allow_default_init_securityindex: false`)
4. **Use the security admin tool** for initial configuration:
   ```bash
   cd /usr/share/opensearch/plugins/opensearch-security/tools/
   ./securityadmin.sh -cd ../../../config/opensearch-security/ \
     -icl -nhnv \
     -cacert /path/to/root-ca.pem \
     -cert /path/to/admin.pem \
     -key /path/to/admin-key.pem
   ```

### Role Design Principles

1. **Principle of least privilege** -- Grant only the permissions needed
2. **Use action groups** for common permission sets:
   ```json
   PUT _plugins/_security/api/actiongroups/log_access
   {
     "allowed_actions": ["indices:data/read/search", "indices:data/read/get", "indices:data/read/mget"]
   }
   ```
3. **Separate read and write roles** for different user groups
4. **Use index patterns** with wildcards judiciously -- `logs-*` is fine, `*` is dangerous
5. **Enable audit logging** for compliance:
   ```json
   PUT _plugins/_security/api/audit
   {
     "config": {
       "enabled": true,
       "audit": {
         "enable_rest": true,
         "enable_transport": true,
         "resolve_indices": true,
         "log_request_body": true,
         "disabled_rest_categories": ["AUTHENTICATED"],
         "disabled_transport_categories": ["AUTHENTICATED"]
       }
     }
   }
   ```

### Field-Level and Document-Level Security

```json
PUT _plugins/_security/api/roles/pii_reader
{
  "index_permissions": [
    {
      "index_patterns": ["customers-*"],
      "allowed_actions": ["read"],
      "fls": ["~ssn", "~credit_card"],
      "masked_fields": ["email"],
      "dls": "{\"bool\": {\"must\": {\"term\": {\"region\": \"us-east\"}}}}"
    }
  ]
}
```

- `fls` with `~` prefix excludes fields (blocklist). Without `~`, it includes only specified fields (allowlist).
- `masked_fields` anonymizes field values (hashes by default).
- `dls` applies a query filter so the role only sees matching documents.

## k-NN Vector Search Best Practices

### Engine Selection

| Use Case | Recommended Engine | Reason |
|---|---|---|
| Small dataset (< 1M vectors) | Lucene | Smart filtering, lower memory overhead |
| Large dataset (> 1M vectors) | Faiss | Better scalability, more algorithms |
| Memory-constrained | Faiss with SQ/PQ encoding | Quantization reduces memory 2-8x |
| Heavy filtering | Lucene | Pre-filter/post-filter auto-optimization |
| New deployments (3.x) | Faiss or Lucene | NMSLIB is deprecated |

### Memory Planning

```
HNSW memory per vector = 1.1 * (4 * dimension + 8 * M) bytes
Example: 768-dim, M=16 = 1.1 * (3072 + 128) = ~3,520 bytes/vector

For 10 million vectors: ~35 GB native memory needed
```

Set circuit breaker appropriately:
```json
PUT /_cluster/settings
{
  "persistent": {
    "knn.memory.circuit_breaker.limit": "60%"
  }
}
```

### Performance Tips

1. **Warmup indices** before production traffic:
   ```
   GET /_plugins/_knn/warmup/my-knn-index
   ```
2. **Tune `ef_search`** -- Higher values improve recall at the cost of latency
3. **Use pre-filtering** for filtered k-NN queries (Lucene engine does this automatically)
4. **Monitor k-NN stats** regularly:
   ```
   GET /_plugins/_knn/stats
   ```
5. **Consider quantization** for large datasets to reduce memory

## Hybrid Search Best Practices

1. **Set up normalization pipeline** -- BM25 and k-NN scores are on different scales:
   ```json
   PUT /_search/pipeline/hybrid-pipeline
   {
     "phase_results_processors": [{
       "normalization-processor": {
         "normalization": { "technique": "min_max" },
         "combination": {
           "technique": "arithmetic_mean",
           "parameters": { "weights": [0.3, 0.7] }
         }
       }
     }]
   }
   ```

2. **Tune weights** -- Start with equal weights, then adjust based on relevance testing. Typical ranges:
   - Keyword-heavy queries: 0.6 BM25, 0.4 vector
   - Semantic queries: 0.3 BM25, 0.7 vector

3. **Use the Maximal Marginal Relevance (MMR)** technique (3.3+) to balance relevance and diversity

4. **Benchmark with real queries** -- Use the Search Relevance Workbench (3.5+) for A/B testing

## Snapshot and Restore Best Practices

1. **Use dedicated snapshot repository** (S3, Azure Blob, GCS, HDFS, or shared filesystem)
2. **Schedule regular snapshots** via ISM snapshot action or cron
3. **Exclude unnecessary indices** (e.g., `.opensearch-*` system indices can often be excluded)
4. **Test restores regularly** -- Do not assume snapshots work until you verify
5. **Use `max_snapshot_bytes_per_sec`** to limit snapshot I/O impact on cluster performance
6. **Repository-level encryption** for sensitive data at rest

```json
// Schedule snapshot via ISM
{
  "name": "snapshot_state",
  "actions": [
    {
      "snapshot": {
        "repository": "my-s3-repo",
        "snapshot": "{{ctx.index}}-{{ctx.index_uuid}}"
      }
    }
  ]
}
```

## Monitoring and Alerting Best Practices

1. **Critical alerts to set up:**
   - Cluster health status change (yellow or red)
   - Disk usage > 80% on any node
   - JVM heap usage > 85% sustained
   - Circuit breaker tripped
   - Unassigned shards > 0 for more than 10 minutes
   - Search latency p99 exceeding SLA
   - Indexing rejection rate > 0

2. **Use Performance Analyzer** for detailed metrics:
   ```
   GET /_plugins/_performanceanalyzer/metrics?metrics=Latency,CPU_Utilization&agg=avg&dim=Operation
   ```

3. **Dashboard essentials:**
   - Cluster health timeline
   - Node-level CPU, memory, disk utilization
   - Index-level operation rates and latencies
   - GC frequency and duration
   - Thread pool queue depths and rejections

## Migration from Elasticsearch

### Compatibility

- **API compatibility:** OpenSearch is broadly compatible with Elasticsearch 7.10.2 REST APIs
- **Client libraries:** Use OpenSearch client libraries (`opensearch-py`, `opensearch-js`, `opensearch-java`). Elasticsearch 7.x clients often work but are not officially supported.
- **Kibana to Dashboards:** OpenSearch Dashboards is a fork of Kibana 7.10.2. Saved objects can be imported.

### Key Terminology Changes

| Elasticsearch | OpenSearch |
|---|---|
| Master node | Cluster manager node |
| ILM (Index Lifecycle Management) | ISM (Index State Management) |
| Kibana | OpenSearch Dashboards |
| X-Pack Security | Security plugin |
| X-Pack Alerting (Watcher) | Alerting plugin |
| X-Pack ML | ML Commons plugin + Anomaly Detection plugin |
| `_xpack/` API prefix | `_plugins/` API prefix |
| `elasticsearch.yml` | `opensearch.yml` |
| `ES_JAVA_OPTS` | `OPENSEARCH_JAVA_OPTS` |

### Migration Steps

1. **Snapshot from Elasticsearch** (7.x) to a shared repository
2. **Restore on OpenSearch** -- Compatible with ES 7.x snapshots
3. **Update client configurations** -- Change endpoint URLs, client libraries
4. **Update ISM policies** -- Rewrite ILM policies as ISM policies
5. **Update security configurations** -- Migrate X-Pack security to OpenSearch security plugin
6. **Test thoroughly** -- Verify query results, aggregations, and dashboard visualizations

### Common Migration Pitfalls

- ES 8.x snapshots are NOT compatible with OpenSearch (only ES 7.x)
- Some Elasticsearch-specific query parameters may not exist in OpenSearch
- X-Pack licensed features may have different plugin names or API paths
- `_type` field was removed in OpenSearch (as it was in ES 7.x)
- NMSLIB was the default k-NN engine in early OpenSearch but is now deprecated (3.0+)

## OpenSearch Serverless (AOSS) Best Practices

1. **Choose the right collection type:**
   - **Search** -- Full-text search workloads
   - **Time-series** -- Log analytics, metrics (supports 100 TiB per index)
   - **Vector search** -- k-NN and semantic search workloads

2. **Minimize OCU usage in dev/test** by disabling redundancy (2 OCUs instead of 4)

3. **Use data access policies** for fine-grained access control (replaces security plugin)

4. **Understand limitations:**
   - No ISM policies
   - No alerting or anomaly detection plugins
   - No cross-cluster operations
   - No custom plugins
   - Subset of OpenSearch APIs
   - No direct node access or `_cat` APIs

5. **Use collection groups** (if available) to share OCU capacity across collections
