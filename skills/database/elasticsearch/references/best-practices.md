# Elasticsearch Best Practices Reference

## Cluster Sizing

### Node Count and Roles

**Minimum production cluster:**
- 3 dedicated master-eligible nodes (fault-tolerant master election)
- 2+ data nodes (for replica shard placement)
- Optional: dedicated coordinating node(s) for heavy aggregation workloads
- Optional: dedicated ingest node(s) for heavy pipeline processing

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
Heap: 31GB per node, 32GB+ RAM per node (64GB recommended)
```

### Master Node Sizing

| Cluster Size | Master Nodes | Master Heap | Master CPU |
|---|---|---|---|
| < 20 data nodes | 3 dedicated | 4-8GB | 2-4 cores |
| 20-100 data nodes | 3 dedicated | 8-16GB | 4-8 cores |
| 100+ data nodes | 3-5 dedicated | 16-32GB | 8+ cores |

Master node heap sizing depends on the number of indices, shards, and the size of the cluster state. Very large clusters (thousands of indices, tens of thousands of shards) require more master heap.

### JVM Heap Sizing

**Rules:**
1. Never allocate more than 50% of physical RAM to heap (Lucene needs the other half for OS page cache)
2. Never exceed ~31GB heap (to stay below the compressed ordinary object pointers threshold)
3. Set `-Xms` and `-Xmx` to the same value (avoid heap resizing)
4. Use G1GC (default in ES 7+/8+)

```bash
# /etc/elasticsearch/jvm.options.d/heap.options
-Xms31g
-Xmx31g
```

**Compressed oops threshold:**
- Below ~32GB heap, the JVM uses compressed ordinary object pointers (32-bit references)
- Above ~32GB, the JVM switches to 64-bit pointers, effectively reducing usable heap
- Setting heap to exactly 32GB gives you LESS usable heap than 31GB
- Test with: `java -Xmx31g -XX:+PrintFlagsFinal 2>&1 | grep UseCompressedOops`

**Heap usage breakdown (typical):**
| Component | Typical % of Heap | Notes |
|---|---|---|
| Segment metadata | 20-40% | Grows with number of segments/fields |
| Indexing buffers | 10-15% | `indices.memory.index_buffer_size: 10%` |
| Query/request cache | 5-15% | `indices.queries.cache.size: 10%` |
| Fielddata cache | 0-30% | Should be near 0 if using doc values properly |
| Network buffers | 5-10% | HTTP and transport layer |
| Overhead/other | 10-20% | GC overhead, internal structures |

### Shard Sizing Strategy

**Target: 10-50GB per shard.** This range balances search performance, recovery time, and resource overhead.

| Shard Size | Trade-off |
|---|---|
| < 1GB | Too small. Excessive overhead. Thousands of tiny shards waste heap and CPU. |
| 1-10GB | Acceptable for small indices. Fast recovery but more shards per index. |
| **10-50GB** | **Ideal range.** Good balance of search speed, merge efficiency, and recovery time. |
| 50-100GB | Large but workable. Slower recovery, but fewer shards to manage. |
| > 100GB | Too large. Recovery takes very long. Relocations during rebalancing are slow. |

**Shard count rules:**
- Keep total shards below `20 * heap_in_GB` per node (e.g., 31GB heap -> max ~620 shards per node)
- Each shard has a fixed overhead of ~10MB heap for segment metadata
- Fewer, larger shards is almost always better than many small shards

**Time-series index sizing:**
```
Shards per index = daily_data_volume / target_shard_size
Example: 100GB/day -> 100GB / 50GB = 2 primary shards per daily index
```

Use ILM rollover to control shard size:
```json
{
  "actions": {
    "rollover": {
      "max_primary_shard_size": "50gb",
      "max_age": "1d"
    }
  }
}
```

## Index Templates

### Composable Index Templates (7.8+)

Use composable templates with component templates for reusability:

```json
PUT _component_template/base-settings
{
  "template": {
    "settings": {
      "number_of_replicas": 1,
      "refresh_interval": "5s",
      "index.lifecycle.name": "default-ilm-policy",
      "index.codec": "best_compression"
    }
  }
}

PUT _component_template/base-mappings
{
  "template": {
    "mappings": {
      "dynamic": "strict",
      "properties": {
        "@timestamp": { "type": "date" },
        "message": { "type": "text" },
        "host.name": { "type": "keyword" },
        "tags": { "type": "keyword" }
      }
    }
  }
}

PUT _index_template/logs-template
{
  "index_patterns": ["logs-*"],
  "composed_of": ["base-settings", "base-mappings"],
  "priority": 200,
  "template": {
    "settings": {
      "number_of_shards": 3
    },
    "mappings": {
      "properties": {
        "log.level": { "type": "keyword" },
        "log.logger": { "type": "keyword" }
      }
    }
  },
  "_meta": {
    "description": "Template for application logs",
    "version": 2
  }
}
```

### Data Streams (7.9+)

Data streams are the preferred abstraction for time-series data:

```json
PUT _index_template/metrics-template
{
  "index_patterns": ["metrics-*"],
  "data_stream": {},
  "composed_of": ["base-settings"],
  "template": {
    "settings": {
      "number_of_shards": 2,
      "number_of_replicas": 1
    },
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "metric.name": { "type": "keyword" },
        "metric.value": { "type": "double" },
        "host.name": { "type": "keyword" }
      }
    }
  }
}

PUT _data_stream/metrics-app

POST metrics-app/_doc
{
  "@timestamp": "2024-01-15T10:30:00Z",
  "metric.name": "cpu_usage",
  "metric.value": 75.5,
  "host.name": "web-01"
}
```

Data stream benefits:
- Automatic rollover with ILM
- Append-only (updates/deletes require `_update_by_query` or `_delete_by_query`)
- Backing indices are managed transparently
- Simplified lifecycle management

## Mapping Best Practices

### Explicit Mappings

Always define explicit mappings for production indices:

```json
PUT /products
{
  "settings": {
    "number_of_shards": 2,
    "number_of_replicas": 1
  },
  "mappings": {
    "dynamic": "strict",
    "properties": {
      "product_id": { "type": "keyword" },
      "name": {
        "type": "text",
        "analyzer": "english",
        "fields": {
          "raw": { "type": "keyword" },
          "autocomplete": {
            "type": "text",
            "analyzer": "autocomplete_analyzer",
            "search_analyzer": "standard"
          }
        }
      },
      "description": {
        "type": "text",
        "analyzer": "english"
      },
      "price": { "type": "scaled_float", "scaling_factor": 100 },
      "category": { "type": "keyword" },
      "tags": { "type": "keyword" },
      "created_at": { "type": "date" },
      "in_stock": { "type": "boolean" },
      "specs": {
        "type": "object",
        "dynamic": true
      },
      "reviews": {
        "type": "nested",
        "properties": {
          "author": { "type": "keyword" },
          "rating": { "type": "byte" },
          "text": { "type": "text" },
          "date": { "type": "date" }
        }
      }
    }
  }
}
```

### Dynamic Mapping Control

| Setting | Behavior |
|---|---|
| `"dynamic": true` | New fields auto-mapped (default). Risky in production. |
| `"dynamic": "runtime"` | New fields mapped as runtime fields (not indexed, computed at query time). Safer. |
| `"dynamic": "strict"` | Reject documents with unmapped fields. Safest for production. |
| `"dynamic": false` | New fields stored in `_source` but NOT indexed or searchable. |

### Field Type Selection Guide

| Data | Recommended Type | Why |
|---|---|---|
| Free-text content | `text` | Full-text search with analysis |
| Identifiers, status codes, tags | `keyword` | Exact match, aggregations, sorting |
| Searchable AND aggregatable strings | `text` + `keyword` multi-field | Both use cases |
| Numbers for range queries | `integer`, `long`, `float`, `double` | BKD tree range queries |
| Numbers for exact match only | `keyword` | Avoid unnecessary numeric indexing overhead |
| Money/currency | `scaled_float` (scaling_factor: 100) | Avoids floating-point precision issues |
| Dates | `date` with explicit format | Range queries, date histograms |
| IP addresses | `ip` | CIDR range queries |
| Boolean flags | `boolean` | Filtering |
| Lat/lon coordinates | `geo_point` | Geo distance/bounding box queries |
| Complex shapes | `geo_shape` | Polygon intersection queries |
| Variable/unknown structure | `flattened` | Prevents mapping explosion |
| Nested objects with per-item queries | `nested` | Independent object matching |
| Simple key-value metadata | `object` (default) | No per-object querying needed |

### Mapping Explosion Prevention

```json
PUT /my-index
{
  "settings": {
    "index.mapping.total_fields.limit": 1000,
    "index.mapping.depth.limit": 5,
    "index.mapping.nested_fields.limit": 25,
    "index.mapping.nested_objects.limit": 10000,
    "index.mapping.field_name_length.limit": 256
  }
}
```

For user-generated or variable structure data, use the `flattened` field type:
```json
{
  "properties": {
    "user_metadata": {
      "type": "flattened"
    }
  }
}
```

## Monitoring Setup

### Essential Monitoring APIs

Check these regularly or integrate into monitoring dashboards:

```bash
# Cluster health (the single most important check)
curl -s localhost:9200/_cluster/health?pretty

# Key metrics to alert on:
# - status: yellow or red
# - unassigned_shards > 0
# - number_of_pending_tasks > 0 (sustained)
# - active_shards_percent_as_number < 100

# Node stats summary
curl -s localhost:9200/_cat/nodes?v&h=name,heap.percent,ram.percent,cpu,load_1m,disk.used_percent,node.role

# Alert thresholds:
# - heap.percent > 85% sustained
# - cpu > 90% sustained
# - disk.used_percent > 80%
```

### Metrics to Monitor

| Metric | Source | Warning Threshold | Critical Threshold |
|---|---|---|---|
| Cluster status | `_cluster/health` | yellow | red |
| Heap usage % | `_nodes/stats/jvm` | > 75% | > 85% |
| GC collection time | `_nodes/stats/jvm` | > 500ms young GC | > 5s old GC |
| Disk usage % | `_cat/allocation` | > 80% | > 90% |
| Search latency | `_nodes/stats/indices/search` | > 500ms p95 | > 2s p95 |
| Indexing latency | `_nodes/stats/indices/indexing` | > 200ms p95 | > 1s p95 |
| Rejected threads | `_cat/thread_pool` | any rejected | sustained rejection |
| Circuit breaker trips | `_nodes/stats/breaker` | any trip | repeated trips |
| Pending tasks | `_cluster/pending_tasks` | > 5 sustained | > 50 |
| Unassigned shards | `_cluster/health` | > 0 | > 0 for > 30min |
| Segment count | `_cat/segments` | > 50 per shard | > 100 per shard |

### Stack Monitoring (Elastic Agent / Metricbeat)

For comprehensive monitoring, use Elastic Stack monitoring:

```json
PUT _cluster/settings
{
  "persistent": {
    "xpack.monitoring.collection.enabled": true,
    "xpack.monitoring.collection.interval": "10s",
    "xpack.monitoring.elasticsearch.collection.enabled": true
  }
}
```

Best practice: Ship monitoring data to a **dedicated monitoring cluster**, not the production cluster itself. This ensures monitoring continues even when the production cluster is unhealthy.

## Security Hardening

### TLS Configuration

```yaml
# elasticsearch.yml -- Transport layer (node-to-node)
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.keystore.path: elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: elastic-certificates.p12

# HTTP layer (client-to-node)
xpack.security.http.ssl.enabled: true
xpack.security.http.ssl.keystore.path: http.p12
```

Generate certificates:
```bash
# Generate CA
bin/elasticsearch-certutil ca --out elastic-stack-ca.p12

# Generate node certificates signed by CA
bin/elasticsearch-certutil cert --ca elastic-stack-ca.p12 --out elastic-certificates.p12

# Generate HTTP certificate
bin/elasticsearch-certutil http
```

### Authentication and Authorization

```json
POST _security/user/app_user
{
  "password": "strong_password_here",
  "roles": ["app_read_role"],
  "full_name": "Application User",
  "enabled": true
}

POST _security/role/app_read_role
{
  "cluster": ["monitor"],
  "indices": [
    {
      "names": ["app-*"],
      "privileges": ["read", "view_index_metadata"],
      "field_security": {
        "grant": ["*"],
        "except": ["sensitive_field"]
      },
      "query": "{\"term\": {\"department\": \"engineering\"}}"
    }
  ]
}

POST _security/role/ingest_role
{
  "cluster": ["manage_ingest_pipelines", "monitor"],
  "indices": [
    {
      "names": ["logs-*", "metrics-*"],
      "privileges": ["create_index", "write", "manage"]
    }
  ]
}
```

### API Key Best Practices

```json
POST _security/api_key
{
  "name": "ingest-service-key",
  "role_descriptors": {
    "ingest_writer": {
      "cluster": ["monitor"],
      "indices": [
        {
          "names": ["logs-*"],
          "privileges": ["create_index", "write"]
        }
      ]
    }
  },
  "expiration": "90d",
  "metadata": {
    "application": "log-shipper",
    "team": "platform"
  }
}
```

Rotate API keys:
```json
GET _security/api_key?name=ingest-service-key
POST _security/api_key/invalidate
{
  "ids": ["old-key-id"]
}
```

### Audit Logging

```yaml
# elasticsearch.yml
xpack.security.audit.enabled: true
xpack.security.audit.logfile.events.include:
  - access_denied
  - access_granted
  - authentication_failed
  - connection_denied
  - tampered_request
  - security_config_change
xpack.security.audit.logfile.events.exclude:
  - system_access_granted
xpack.security.audit.logfile.events.emit_request_body: false
```

## Backup Strategy

### Snapshot Lifecycle Management (SLM)

```json
PUT _snapshot/s3-repository
{
  "type": "s3",
  "settings": {
    "bucket": "elasticsearch-backups",
    "base_path": "production",
    "compress": true,
    "server_side_encryption": true,
    "max_restore_bytes_per_sec": "200mb",
    "max_snapshot_bytes_per_sec": "200mb"
  }
}

PUT _slm/policy/nightly-snapshots
{
  "schedule": "0 0 2 * * ?",
  "name": "<nightly-{now/d}>",
  "repository": "s3-repository",
  "config": {
    "indices": ["*", "-.monitoring-*", "-.security-*"],
    "ignore_unavailable": true,
    "include_global_state": true
  },
  "retention": {
    "expire_after": "30d",
    "min_count": 7,
    "max_count": 60
  }
}

POST _slm/policy/nightly-snapshots/_execute
```

### Backup Verification

```bash
# List all snapshots
curl -s localhost:9200/_snapshot/s3-repository/_all?pretty | jq '.snapshots[-1]'

# Check snapshot status
curl -s localhost:9200/_snapshot/s3-repository/nightly-2024.01.15/_status?pretty

# Test restore to a different index name
curl -X POST localhost:9200/_snapshot/s3-repository/nightly-2024.01.15/_restore -H 'Content-Type: application/json' -d '{
  "indices": "critical-data",
  "rename_pattern": "(.+)",
  "rename_replacement": "restored-$1"
}'

# Verify restored data
curl -s localhost:9200/restored-critical-data/_count?pretty
```

### Backup Strategy Comparison

| Strategy | Speed | Storage | PITR | Complexity |
|---|---|---|---|---|
| SLM snapshots (S3/GCS/Azure) | Fast (incremental) | Efficient (deduplicated) | Yes (per-snapshot) | Low |
| Filesystem snapshots | Fast | Full size per snapshot | Yes | Medium |
| Reindex to another cluster | Slow | Full size | No | High |
| Cross-cluster replication (CCR) | Real-time | Full replica | No (continuous) | Medium |

## Index Performance Tuning

### Indexing Optimization

```json
PUT /high-throughput-index/_settings
{
  "index.refresh_interval": "30s",
  "index.number_of_replicas": 0,
  "index.translog.durability": "async",
  "index.translog.sync_interval": "30s",
  "index.translog.flush_threshold_size": "1gb"
}
```

After bulk load completes, restore safe settings:
```json
PUT /high-throughput-index/_settings
{
  "index.refresh_interval": "1s",
  "index.number_of_replicas": 1,
  "index.translog.durability": "request"
}
```

### Bulk API Best Practices

```bash
# Optimal bulk request format (newline-delimited JSON)
curl -X POST localhost:9200/_bulk -H 'Content-Type: application/x-ndjson' --data-binary @bulk-data.ndjson

# bulk-data.ndjson format:
# {"index":{"_index":"logs","_id":"1"}}
# {"message":"log entry 1","@timestamp":"2024-01-15T10:00:00Z"}
# {"index":{"_index":"logs","_id":"2"}}
# {"message":"log entry 2","@timestamp":"2024-01-15T10:01:00Z"}
```

Bulk sizing guidelines:
| Factor | Recommendation |
|---|---|
| Request size | 5-15MB per bulk request |
| Document count | 1,000-5,000 documents per request (adjust based on doc size) |
| Concurrency | Start with number_of_data_nodes concurrent bulk requests |
| Retries | Retry 429 (rejected) with exponential backoff |
| Pipeline | Specify pipeline in bulk metadata to avoid per-request overhead |

### Search Optimization

```json
PUT /my-index/_settings
{
  "index.queries.cache.enabled": true,
  "index.max_result_window": 10000
}
```

Query optimization checklist:
1. Use `filter` context for all non-scoring clauses
2. Avoid wildcards at the beginning of terms (`*error` is slow; `error*` is fast)
3. Use `search_after` + PIT for deep pagination instead of `from`/`size`
4. Limit `_source` fields returned: `"_source": ["field1", "field2"]`
5. Use `terminate_after` for existence checks: `"terminate_after": 1`
6. Pre-sort data at index time for sorted indices (ES 7.11+):
```json
PUT /sorted-index
{
  "settings": {
    "sort.field": ["@timestamp"],
    "sort.order": ["desc"]
  }
}
```

## Operational Checklists

### Pre-Production Checklist

- [ ] Explicit mappings defined for all production indices (no dynamic mapping in production)
- [ ] Index templates created with proper settings and mappings
- [ ] ILM policies configured for time-series indices
- [ ] SLM policies configured with retention
- [ ] Snapshot repository tested with restore verification
- [ ] TLS enabled on transport and HTTP layers
- [ ] Authentication enabled with proper roles (no superuser for applications)
- [ ] Audit logging enabled for compliance
- [ ] Dedicated master nodes (3 minimum)
- [ ] JVM heap set to 50% RAM, max 31GB, Xms=Xmx
- [ ] Disk watermarks reviewed and adjusted if needed
- [ ] Monitoring configured (shipping to separate cluster)
- [ ] Alerting configured for cluster health, heap, disk, rejected threads
- [ ] `vm.max_map_count` set to 262144 or higher
- [ ] File descriptor limit set to 65536 or higher
- [ ] Disable swapping: `bootstrap.memory_lock: true` or `swapoff -a`

### Rolling Restart Procedure

```bash
# 1. Disable shard allocation (prevents unnecessary rebalancing)
curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{
  "persistent": {
    "cluster.routing.allocation.enable": "primaries"
  }
}'

# 2. Perform a synced flush (pre-8.0) or flush (8.0+)
curl -X POST localhost:9200/_flush

# 3. Stop Elasticsearch on the target node
systemctl stop elasticsearch

# 4. Perform maintenance (upgrade, config change, etc.)

# 5. Start Elasticsearch on the target node
systemctl start elasticsearch

# 6. Wait for the node to rejoin and local recovery to complete
curl -s localhost:9200/_cat/health?v
curl -s localhost:9200/_cat/recovery?v&active_only=true

# 7. Re-enable shard allocation
curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{
  "persistent": {
    "cluster.routing.allocation.enable": "all"
  }
}'

# 8. Wait for cluster to go green before proceeding to next node
curl -s localhost:9200/_cluster/health?wait_for_status=green&timeout=5m
```

### Upgrade Procedure (Rolling Upgrade)

1. Review breaking changes and deprecation logs
2. Take a snapshot before upgrading
3. Upgrade nodes one at a time using the rolling restart procedure above
4. Upgrade master-eligible nodes last (or first if required by version)
5. Monitor cluster health throughout
6. After all nodes are upgraded, re-enable features that require all nodes on the new version
7. Run the deprecation API to check for issues: `GET _migration/deprecations`

## OS-Level Tuning

### Linux Kernel Settings

```bash
# /etc/sysctl.conf
vm.max_map_count = 262144              # Required for Lucene mmapped files
vm.swappiness = 1                       # Minimize swapping
net.core.somaxconn = 32768             # Max socket backlog
net.ipv4.tcp_max_syn_backlog = 16384   # TCP SYN backlog

# Apply immediately
sysctl -p
```

### System Limits

```bash
# /etc/security/limits.conf
elasticsearch  soft  nofile  65536
elasticsearch  hard  nofile  65536
elasticsearch  soft  nproc   4096
elasticsearch  hard  nproc   4096
elasticsearch  soft  memlock unlimited
elasticsearch  hard  memlock unlimited
```

### Disable Swapping

```yaml
# elasticsearch.yml (preferred method)
bootstrap.memory_lock: true
```

Verify memory lock:
```bash
curl -s localhost:9200/_nodes?filter_path=**.mlockall
```

If memory lock fails, use OS-level settings:
```bash
# Disable swap entirely
swapoff -a

# Or set swappiness very low
echo 'vm.swappiness = 1' >> /etc/sysctl.conf
```

### Filesystem

- Use `ext4` or `XFS` (XFS preferred for large files)
- Mount with `noatime` to reduce metadata updates
- Use SSD/NVMe for hot data nodes
- RAID 0 across multiple SSDs for data nodes (Elasticsearch handles replication)
- Do NOT use NFS or remote filesystems for data paths (high latency, locking issues)

```yaml
# elasticsearch.yml
path.data: /data/elasticsearch
path.logs: /var/log/elasticsearch
```

Multiple data paths (stripe across disks):
```yaml
path.data:
  - /data1/elasticsearch
  - /data2/elasticsearch
```
