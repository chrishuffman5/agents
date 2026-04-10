# ELK Log Management

## Log Collection -- Filebeat / Elastic Agent

### Filebeat Configuration

```yaml
# filebeat.yml
filebeat.inputs:
  - type: filestream          # preferred over legacy "log" type (7.9+)
    id: nginx-access
    paths: ["/var/log/nginx/access.log"]
  - type: filestream
    id: app-json
    paths: ["/opt/app/logs/*.json"]
    parsers:
      - ndjson: { target: "", overwrite_keys: true }

filebeat.modules:
  - module: nginx
    access: { enabled: true }
    error:  { enabled: true }
  - module: system
    syslog: { enabled: true }
    auth:   { enabled: true }

output.elasticsearch:
  hosts: ["https://es:9200"]
  api_key: "${ES_API_KEY}"
  pipeline: "nginx-access-parse"
  data_stream.enable: true

setup.ilm.enabled: true
```

### Kubernetes Log Collection (Autodiscover)

```yaml
filebeat.autodiscover:
  providers:
    - type: kubernetes
      node: ${NODE_NAME}
      hints.enabled: true        # reads labels: co.elastic.logs/module, etc.
      hints.default_config:
        type: container
        paths: ["/var/log/containers/*${data.kubernetes.container.id}.log"]
```

With Elastic Agent on Kubernetes: install as a DaemonSet via the Kubernetes integration in Fleet. Automatically enriches logs with `kubernetes.pod.name`, `kubernetes.namespace`, `kubernetes.container.name`.

## Index Templates for Logs

```json
PUT _index_template/logs-myapp
{
  "index_patterns": ["logs-myapp-*"],
  "data_stream": {},
  "priority": 200,
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 1,
      "index.lifecycle.name": "observability-logs",
      "default_pipeline": "logs-myapp-parse"
    },
    "mappings": {
      "dynamic_templates": [{
        "strings_as_keyword": {
          "match_mapping_type": "string",
          "mapping": { "type": "keyword", "ignore_above": 1024 }
        }
      }],
      "properties": {
        "@timestamp":   { "type": "date" },
        "message":      { "type": "text" },
        "log.level":    { "type": "keyword" },
        "service.name": { "type": "keyword" },
        "trace.id":     { "type": "keyword" }
      }
    }
  }
}
```

## Data Stream Operations

```bash
GET  _data_stream/logs-*                          # list data streams
GET  _data_stream/logs-nginx.access-prod/_stats   # stats
POST logs-nginx.access-prod/_rollover             # manual rollover
GET  logs-nginx.access-prod-000001/_ilm/explain   # ILM state
POST logs-nginx.access-prod-000001/_ilm/retry     # retry failed ILM step
```

## KQL (Kibana Query Language)

KQL is the default query language in Kibana's search bar:

```kql
service.name: "nginx"                           # field match
url.path: /api/*                                # wildcard
log.level: ("ERROR" OR "FATAL")                 # multiple values
http.response.status_code >= 400 and http.response.status_code < 500   # range
NOT http.response.status_code: 200              # negation
kubernetes.pod.name: "myapp-*"                  # nested field
http.request.body.content: *                    # field exists
```

## Lucene Query Syntax

For Lens, ES|QL contexts, and advanced filters:

```
service.name:nginx AND status:[400 TO 599]
message:"connection refused"
url.path:/\/api\/v[0-9]+\//
@timestamp:[now-1h TO now]
message:connectoin~1                            # fuzzy
```

## ES|QL (8.11+ GA)

Pipe-based analytics language:

```esql
FROM logs-nginx.access-prod
| WHERE @timestamp >= NOW() - 1 hour
| WHERE http.response.status_code >= 500
| STATS count = COUNT(*) BY service.name
| SORT count DESC
| LIMIT 10
```

ES|QL 9.x additions: `LOOKUP JOIN`, `INLINESTATS`, window functions.

## Discover and Logs Explorer

- **Discover:** Select data view, set time range, write KQL/Lucene. Save searches for dashboards.
- **Logs Explorer (8.9+):** Observability > Logs Explorer. Dataset selector by integration or data stream. ML-based log categories, field statistics distribution, surrounding context view. Direct "Create rule" from current query.

## Metric Data Streams and Downsampling

Metrics follow `metrics-<dataset>-<namespace>` naming. TSDB mode + ILM downsampling reduces long-term storage:

```json
PUT _ilm/policy/metrics-7d
{
  "policy": {
    "phases": {
      "hot":  { "actions": { "rollover": { "max_age": "1d" }, "downsample": { "fixed_interval": "1m" } } },
      "warm": { "min_age": "2d", "actions": { "downsample": { "fixed_interval": "1h" } } },
      "delete": { "min_age": "7d", "actions": { "delete": {} } }
    }
  }
}
```

## Kibana Visualization

- **Lens (recommended):** Drag-and-drop. Chart types: line, bar, area, metric, gauge, heatmap. Formula editor: `count() / moving_average(count(), window=5)`. Layer-based overlays and reference lines.
- **TSVB (Time Series Visual Builder):** Purpose-built for time series. Aggregations: min/max/avg/sum/percentiles/derivative/moving_average/cumulative_sum.

## Shard Strategy Best Practices

- **Target shard size:** 10-50 GB for logs; 1-5 GB for metrics (TSDB)
- **Rollover thresholds:** `max_primary_shard_size: 50gb` + `max_age: 1d` -- whichever comes first
- **Avoid over-sharding:** Each shard consumes heap; many small shards degrade cluster stability
- **Replicas:** 1 replica on hot/warm for resilience; 0 replicas on cold/frozen to save storage
