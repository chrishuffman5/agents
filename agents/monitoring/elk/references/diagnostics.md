# ELK Diagnostics

## Cluster Health

```bash
GET _cluster/health?pretty
GET _cluster/health?level=indices&pretty          # per-index status
GET _cat/shards?v&h=index,shard,prirep,state,unassigned.reason&s=state
GET _cat/nodes?v&h=name,disk.used_percent,heap.percent,cpu&s=disk.used_percent:desc
```

### Explain Unassigned Shard

```bash
GET _cluster/allocation/explain
{ "index": "logs-nginx-prod-000001", "shard": 0, "primary": true }
```

Common unassigned reasons:
- **ALLOCATION_FAILED** -- Disk full, node count < replicas + 1, or shard limit reached
- **NODE_LEFT** -- Node departed cluster; shard will reallocate after `index.unassigned.node_left.delayed_timeout`
- **INDEX_CREATED** -- Newly created index waiting for allocation

## Disk Watermarks

Default thresholds: 85% low (stop allocating new shards), 90% high (relocate shards), 95% flood (make indices read-only).

```json
PUT _cluster/settings
{
  "transient": {
    "cluster.routing.allocation.disk.watermark.low": "85%",
    "cluster.routing.allocation.disk.watermark.high": "90%",
    "cluster.routing.allocation.disk.watermark.flood_stage": "95%"
  }
}
```

**Recovery from flood stage:** After adding disk space, manually unblock affected indices:
```bash
PUT _all/_settings
{ "index.blocks.read_only_allow_delete": null }
```

## Slow Query Diagnostics

```bash
# Enable slow logs
PUT logs-nginx.access-prod/_settings
{
  "index.search.slowlog.threshold.query.warn": "10s",
  "index.search.slowlog.threshold.fetch.warn": "1s",
  "index.search.slowlog.level": "info"
}

GET _nodes/hot_threads                             # CPU-intensive threads
GET _tasks?actions=*search&detailed&pretty         # running queries
POST _tasks/<task_id>/_cancel                      # cancel runaway query

# Profile a query
POST logs-nginx.access-prod/_search
{ "profile": true, "query": { "match": { "message": "error" } } }
```

## ILM Diagnostics

```bash
# ILM state per index
GET _cat/indices?v&h=index,ilm.phase,ilm.action,ilm.step&s=ilm.phase

# Detailed ILM state for a specific index
GET logs-nginx.access-prod-000001/_ilm/explain

# Retry failed ILM step
POST logs-nginx.access-prod-000001/_ilm/retry

# Ongoing snapshots (for cold/frozen tier)
GET _snapshot/_status
```

Common ILM issues:
- **Stuck in `check-rollover-ready`** -- Backing index not writable; check data stream write index
- **Failed `searchable_snapshot`** -- Snapshot repository misconfigured or unreachable
- **`shrink` failed** -- Target shard count must divide evenly into source; ensure index is read-only first

## APM Data Stream Health

```bash
# Count recent APM traces
GET traces-apm-*/_count
{ "query": { "range": { "@timestamp": { "gte": "now-5m" } } } }

# Check Kibana task manager (alerting health)
GET /api/task_manager/_health

# Fleet agent status
GET /api/fleet/agents?showInactive=false&perPage=20
```

## Common API Patterns Quick Reference

```bash
# Cluster and node health
GET _cluster/health
GET _cat/nodes?v
GET _cat/indices?v&s=store.size:desc

# Data stream operations
GET  _data_stream/logs-*
POST <datastream>/_rollover
GET  <index>/_ilm/explain
POST <index>/_ilm/retry

# Test an ingest pipeline
POST _ingest/pipeline/my-pipeline/_simulate
{ "docs": [{ "_source": { "message": "2024-01-15 10:30:00 ERROR login failed" } }] }

# Snapshot operations
GET _slm/policy
POST _slm/policy/<policy>/_execute
GET _snapshot/my-repo/_all
```

## Kibana Observability Navigation

| Goal | Path |
|------|------|
| Explore logs | Observability > Logs Explorer |
| Search any data | Discover |
| APM traces and waterfall | Observability > APM > Traces |
| Service dependency map | Observability > APM > Service Map |
| Infrastructure metrics | Observability > Infrastructure |
| Uptime / Synthetics | Observability > Synthetics |
| Manage alerting rules | Observability > Alerts > Manage Rules |
| Agent management | Management > Fleet |
| Ingest pipelines | Stack Management > Ingest Pipelines |
| ILM policies | Stack Management > Index Lifecycle Policies |
| Index templates | Stack Management > Index Management > Templates |
