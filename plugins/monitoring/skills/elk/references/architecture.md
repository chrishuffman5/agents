# ELK Stack Architecture

## Elastic Stack Components

```
DATA SOURCES (Apps, OS, Containers, Network, Cloud)
        |
COLLECTION LAYER
  Elastic Agent (unified, Fleet-managed)     Beats (legacy/lightweight)
  └─ Integrations: logs, metrics, APM        ├─ Filebeat  ├─ Metricbeat
                                             ├─ Heartbeat ├─ Auditbeat
                                             └─ Packetbeat
        |
PROCESSING LAYER
  Ingest Node Pipelines (grok/dissect/date/enrich)
  Logstash (heavy ETL -- optional)
        |
STORAGE LAYER
  Elasticsearch Cluster
  ├─ Hot nodes (fast NVMe SSD, recent data)
  ├─ Warm nodes (SSD/HDD, 1-30 days, read-only)
  ├─ Cold nodes (searchable snapshots from S3/GCS)
  └─ Frozen tier (on-demand snapshot mounts)
        |
VISUALIZATION / MANAGEMENT
  Kibana: Discover, Logs Explorer, APM, Dashboards, Fleet, Alerting
```

## Elasticsearch -- Observability Role

Stores and indexes logs, metrics, and traces. Provides near-real-time search and aggregation.

**Data streams:** Time-ordered abstraction over backing indices. Naming: `<type>-<dataset>-<namespace>` (e.g., `logs-nginx.access-production`). Always writes to the latest backing index; ILM triggers automatic rollover.

**TSDB index mode (8.1+):** `index.mode: time_series` for metrics -- reduces storage 40-70% via synthetic source and dimension-based routing.

**Logsdb index mode (8.13+, default in 9.x):** Column-store for logs -- ~65% storage reduction versus 8.x default.

## Elastic Agent and Fleet

**Elastic Agent** is a single binary running multiple integrations, replacing separate Beats:

- **Fleet-managed:** Policies pushed from Kibana Fleet UI. Zero-touch rollout -- enroll once, policy applied automatically
- **Standalone mode:** Config file (`elastic-agent.yml`) without Fleet Server -- useful for air-gapped environments
- **Fleet Server:** Special Elastic Agent instance acting as relay between agents and Kibana/Elasticsearch
- **Integration packages:** 300+ pre-built configurations from the Elastic Package Registry

```yaml
# elastic-agent.yml (standalone)
outputs:
  default:
    type: elasticsearch
    hosts: ["https://es-cluster:9200"]
    api_key: "key-id:key-value"
inputs:
  - type: logfile
    streams:
      - paths: ["/var/log/nginx/access.log"]
        processors:
          - add_fields: { fields: { service.name: nginx } }
  - type: system/metrics
    streams:
      - metricsets: [cpu, memory, network, diskio]
        period: 10s
```

```bash
# Enroll an agent with Fleet
elastic-agent install \
  --url=https://fleet-server:8220 \
  --enrollment-token=<token> \
  --certificate-authorities=/path/to/ca.crt
```

## APM Server

Receives traces, transactions, errors, and metrics from language agents:
- In 8.x+: bundled inside Elastic Agent as the `apm` integration -- no separate binary
- Default port: 8200
- Supports Elastic native protocol and OpenTelemetry OTLP (gRPC and HTTP)

## Index Lifecycle Management (ILM)

| Phase | Typical Age | Storage | Key Actions |
|-------|-------------|---------|-------------|
| Hot | 0-1 days | Fast NVMe SSD | Write, rollover, set_priority |
| Warm | 1-30 days | SSD/HDD | Read-only, shrink, forcemerge |
| Cold | 30-90 days | Searchable snapshots (S3/GCS) | Occasional search |
| Frozen | 90-365 days | On-demand snapshot mount | Rare search |
| Delete | >365 days | -- | delete |

```json
PUT _ilm/policy/observability-logs
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": { "max_age": "1d", "max_primary_shard_size": "50gb" },
          "set_priority": { "priority": 100 }
        }
      },
      "warm": {
        "min_age": "2d",
        "actions": {
          "shrink": { "number_of_shards": 1 },
          "forcemerge": { "max_num_segments": 1 },
          "set_priority": { "priority": 50 }
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "searchable_snapshot": { "snapshot_repository": "my-s3-repo" },
          "set_priority": { "priority": 0 }
        }
      },
      "frozen": {
        "min_age": "90d",
        "actions": { "searchable_snapshot": { "snapshot_repository": "my-s3-repo" } }
      },
      "delete": { "min_age": "365d", "actions": { "delete": {} } }
    }
  }
}
```

## Ingest Pipelines

Transform documents before indexing. Defined via Kibana or API.

| Processor | Purpose |
|-----------|---------|
| `grok` | Regex-based field extraction from unstructured text |
| `dissect` | Fast tokenization for structured text (faster than grok) |
| `date` | Parse timestamp strings into `@timestamp` |
| `rename` / `remove` / `set` | ECS field normalization |
| `json` / `kv` | Parse JSON strings or key=value pairs |
| `geoip` / `user_agent` | Enrich IP with location / parse User-Agent |
| `enrich` | Lookup from an enrich policy (e.g., asset DB) |
| `script` | Painless script for complex transforms |
| `drop` | Discard documents matching a condition |

```json
PUT _ingest/pipeline/nginx-access-parse
{
  "processors": [
    { "grok": { "field": "message", "patterns": ["%{COMBINEDAPACHELOG}"] } },
    { "date": { "field": "timestamp", "formats": ["dd/MMM/yyyy:HH:mm:ss Z"], "target_field": "@timestamp" } },
    { "rename": { "field": "clientip", "target_field": "source.ip" } },
    { "remove": { "field": ["timestamp", "ident", "auth"] } },
    { "set": { "field": "event.dataset", "value": "nginx.access" } }
  ],
  "on_failure": [{ "set": { "field": "error.message", "value": "{{ _ingest.on_failure_message }}" } }]
}
```

## Elastic Common Schema (ECS)

Always normalize to ECS in ingest pipelines -- required for Kibana Observability features.

| Category | Fields |
|----------|--------|
| Core | `@timestamp`, `message` |
| Host | `host.name`, `host.ip`, `host.os.type` |
| Service | `service.name`, `service.version`, `service.environment` |
| Log | `log.level`, `log.logger` |
| Event | `event.dataset`, `event.module`, `event.category`, `event.outcome` |
| Trace | `trace.id`, `transaction.id`, `span.id` |
| HTTP | `http.request.method`, `http.response.status_code`, `url.full` |
| User | `user.name`, `user.id` |

## Hot-Warm-Cold-Frozen Node Configuration

```yaml
# elasticsearch.yml -- hot node
node.roles: [data_hot, ingest]

# elasticsearch.yml -- warm node
node.roles: [data_warm]

# ILM automatically targets tiers via _tier_preference routing
```

## Performance Tuning

- **Refresh interval:** Set `index.refresh_interval: 30s` on hot indices during high ingest (default 1s burns I/O)
- **Bulk indexing:** 5-15 MB batches; 1-3 concurrent bulk threads per shard
- **Mapping explosion:** Use `dynamic: false` or `dynamic: runtime` to prevent unbounded field creation
- **Index sorting:** Sort logs by `service.name, @timestamp DESC` for better compression
- **Circuit breakers:** Monitor `GET _nodes/stats/breaker` -- trips indicate heap pressure; tune JVM heap to 50% of RAM (max 32 GB)

## Snapshot Lifecycle Management (SLM)

```json
PUT _snapshot/my-s3-repo
{ "type": "s3", "settings": { "bucket": "my-es-snapshots", "region": "us-east-1" } }

PUT _slm/policy/daily-snapshots
{
  "schedule": "0 30 1 * * ?",
  "name": "<daily-snap-{now/d}>",
  "repository": "my-s3-repo",
  "config": {
    "indices": ["logs-*", "metrics-*", "traces-*"],
    "include_global_state": false
  },
  "retention": { "expire_after": "30d", "min_count": 5, "max_count": 50 }
}
```

## Cross-Cluster Search (CCS)

```json
PUT _cluster/settings
{ "persistent": { "cluster.remote.us-east.seeds": ["es-us-east-1:9300"] } }
```

Query: `GET us-east:logs-nginx-*,eu-west:logs-nginx-*/_search`. In Kibana data views, use pattern: `us-east:logs-*,eu-west:logs-*`.
