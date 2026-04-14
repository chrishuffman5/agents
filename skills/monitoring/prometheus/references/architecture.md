# Prometheus Architecture

## Pull-Based Scraping Model

Prometheus uses a **pull-based** (scrape) model. The server fetches metrics from targets at a configured interval. Targets expose metrics via an HTTP endpoint (default `/metrics`) in Prometheus exposition format or OpenMetrics format.

**Advantages of pull:**
- Easy to detect if a target is down (scrape fails -- `up == 0`)
- Prometheus controls the scrape rate (no thundering herd from clients)
- Simple to run multiple instances against the same targets for HA
- Metrics endpoint doubles as a health check
- No client-side queuing or buffering needed

**Pushgateway:** Bridges the gap for short-lived jobs (batch, cron). Jobs push metrics to the gateway; Prometheus scrapes the gateway. Use only for jobs that cannot be scraped directly -- the Pushgateway is a single point of failure and does not support `up` metric semantics.

## Core Components

```
┌─────────────────────────────────────────────────────────┐
│                    Prometheus Server                     │
│                                                         │
│  ┌─────────────┐   ┌──────────────┐   ┌─────────────┐  │
│  │  Retrieval  │   │   TSDB       │   │  HTTP API   │  │
│  │  (Scraper)  │──>│  (Storage)   │<──│  & UI       │  │
│  └─────────────┘   └──────────────┘   └─────────────┘  │
│         ^                                    ^          │
│         │                                    │          │
│  ┌─────────────┐                    ┌─────────────────┐ │
│  │  Service    │                    │  Rule Manager   │ │
│  │  Discovery  │                    │  (Alert+Record) │ │
│  └─────────────┘                    └─────────────────┘ │
└─────────────────────────────────────────────────────────┘
         ^                                    │
         │ scrape                             │ fire alerts
    ┌────┴────┐                     ┌────────v────────┐
    │ Targets │                     │  Alertmanager   │
    │ /metrics│                     │  (route, dedup, │
    └─────────┘                     │   notify)       │
                                    └─────────────────┘
```

**Retrieval (Scraper):** Resolves targets from service discovery, applies relabeling, fetches metrics on the configured interval. Each scrape is atomic -- all samples from one scrape share the same timestamp.

**TSDB:** Custom time-series database storing all scraped and recording-rule-computed data. On-disk format using chunks, index, and WAL.

**Rule Manager:** Evaluates recording rules (compute derived metrics) and alerting rules on a configurable interval (default 1 minute).

**HTTP API / UI:** Exposes `/api/v1/*` endpoints for PromQL queries, metadata, targets, alerts. Prometheus 3.x ships with a modernized React-based UI.

## TSDB -- Time-Series Database

### On-Disk Layout

```
data/
  ├── 01BX... (block dir, 2h default)
  │   ├── chunks/
  │   │   └── 000001          # chunk files (up to 512MB)
  │   ├── index               # inverted index for label queries
  │   ├── meta.json           # block metadata
  │   └── tombstones          # soft deletes
  ├── wal/                    # Write-Ahead Log
  │   ├── 00000001
  │   └── checkpoint.000001/
  └── chunks_head/            # mmap-backed head chunks
```

### Key Design Decisions

- **2-hour blocks:** Head block (current 2h) lives in memory + WAL. Completed blocks are flushed to disk.
- **XOR compression:** Gorilla-style compression on float64 values. Average ~1.3 bytes/sample for float gauges/counters.
- **Native histogram encoding:** Sparse bucket encoding at ~5 bytes/sample for typical histograms.
- **WAL (Write-Ahead Log):** Ensures crash recovery. On restart, Prometheus replays WAL to reconstruct the head block.
- **Compaction:** Runs periodically, merging blocks and applying tombstones. Configurable max block duration (default 10% of retention).
- **Retention:** Configurable by time (`--storage.tsdb.retention.time`, default 15d) or size (`--storage.tsdb.retention.size`). Both can be set simultaneously; whichever limit is hit first takes effect.

### Storage Estimate

```
disk_bytes = (active_series / scrape_interval) * bytes_per_sample * retention_seconds
```

Example: 500,000 series, 15s interval, 30d retention:
```
= (500,000 / 15) * 1.3 * (30 * 86,400) ≈ 112 GB
```

WAL adds ~2 hours of data. Add 20% overhead for compaction scratch space.

## Native Histograms (Prometheus 3.x)

Native histograms are a stable, first-class feature in 3.x. They replace the need for pre-defined `le` bucket boundaries:

- **Exponential bucket schemas** (base-2 or custom resolution) that adapt to observed values
- **Eliminate `le` bucket labels** -- drastically reducing cardinality
- **Accurate server-side quantiles** without classic staircase error
- **`histogram_quantile()`** works transparently with both classic and native histograms
- Configurable `schema` (resolution factor) and `zero_threshold` for near-zero values

```promql
# Works identically for native and classic histograms
histogram_quantile(0.99, rate(http_request_duration_seconds[5m]))
```

Additional 3.x functions: `histogram_avg()`, `histogram_count()`, `histogram_sum()`.

## UTF-8 Metric Names (Prometheus 3.x)

Prometheus 3.x lifts the ASCII-only restriction. Metric names can now include UTF-8 characters:
- Dots in metric names: `http.server.request.duration` (previously illegal)
- Non-Latin script labels
- Better OpenTelemetry semantic convention compatibility

UTF-8 names in PromQL use quoting: `{"http.server.request.duration_seconds"[5m]}`.

## OTLP Ingestion (Prometheus 3.x)

Native OTLP receiver at `/api/v1/otlp/v1/metrics`. OpenTelemetry SDK-instrumented applications can push metrics directly to Prometheus without a separate Collector. Prometheus translates OTLP metrics into its internal format, including native histograms from OTLP ExponentialHistogram types.

## Service Discovery

Prometheus dynamically resolves scrape targets without manual configuration updates.

### Kubernetes SD

Discovers: `node`, `pod`, `service`, `endpoints`, `endpointslice`, `ingress`. Uses the Kubernetes API. Exposes metadata as `__meta_kubernetes_*` labels (pod name, namespace, annotations, labels).

Common pattern: annotate pods with `prometheus.io/scrape: "true"` and `prometheus.io/port: "8080"`, then filter in `relabel_configs`.

### Other SD Mechanisms

| Mechanism | Discovery Source | Key Metadata |
|-----------|-----------------|-------------|
| Consul SD | Consul service catalog | `__meta_consul_service`, `__meta_consul_tags` |
| EC2 SD | AWS EC2 instances | `__meta_ec2_instance_id`, `__meta_ec2_tag_*` |
| File SD | JSON/YAML files (watched) | Custom labels per target group |
| DNS SD | DNS SRV/A records | Hostname, port |
| HTTP SD | Generic REST endpoint | Custom labels |
| Azure SD | Azure VMs | `__meta_azure_machine_*` |
| GCE SD | Google Compute instances | `__meta_gce_instance_*` |
| Docker SD | Docker containers | `__meta_docker_container_*` |

File-based SD is useful for custom integrations: write a script that generates target files and Prometheus watches them via inotify.

## Federation

Federation allows a global Prometheus to scrape metrics from other Prometheus instances via the `/federate` endpoint with `match[]` parameters.

```yaml
scrape_configs:
  - job_name: federate
    honor_labels: true
    metrics_path: /federate
    params:
      match[]:
        - '{job="api-server"}'
        - 'http_requests_total'
    static_configs:
      - targets: [prometheus-dc1:9090, prometheus-dc2:9090]
```

**Limitations:** Federation is a scrape (subject to interval lag), and queries cannot span federated servers without routing logic. For production-scale multi-datacenter setups, prefer remote_write to Thanos or Mimir.

## Remote Read / Write

### Remote Write

Sends samples from Prometheus to a remote backend in real time as they are scraped. Protobuf-over-HTTP, snappy-compressed. Supports sharding, queuing, and retry.

**Compatible backends:** Thanos Receiver, Grafana Mimir, Cortex, VictoriaMetrics, InfluxDB, Elasticsearch, TimescaleDB.

```yaml
remote_write:
  - url: https://mimir.example.com/api/v1/push
    basic_auth:
      username: prometheus
      password_file: /etc/prometheus/mimir-password
    queue_config:
      max_samples_per_send: 10000
      capacity: 500000
      max_shards: 50
```

Use `write_relabel_configs` to filter which metrics are sent remotely (e.g., drop `go_*` runtime metrics).

### Remote Read

Allows Prometheus to query a remote backend for data older than local retention. Transparent to PromQL -- Prometheus merges remote and local results.

## Long-Term Storage Integration

### Thanos

- **Sidecar:** Runs alongside Prometheus, uploads TSDB blocks to object storage (S3/GCS/Azure), exposes gRPC StoreAPI
- **Query:** Aggregates queries across Sidecars and Store Gateways, handles deduplication via `--query.replica-label`
- **Compactor:** Compacts and downsamples blocks in object storage
- **Ruler:** Evaluates recording/alerting rules against the Thanos Store

### Grafana Mimir

Fully remote_write compatible, horizontally scalable, multi-tenant Prometheus backend. Accepts remote_write, provides long-term storage with built-in Ruler and Alertmanager components. Mimir is the recommended choice for Grafana-ecosystem deployments.

## High Availability Patterns

### Basic HA: Dual Prometheus + Alertmanager Cluster

Run two identical Prometheus instances scraping the same targets. Both evaluate the same rules and send alerts to an Alertmanager cluster (3-node, gossip-based dedup).

```
Prometheus-0 ──┐
               ├──> Alertmanager-0 ──┐
Prometheus-1 ──┘    Alertmanager-1    ├──> Receivers
                    Alertmanager-2 ──┘
```

Configuration: each Prometheus sets `external_labels: {replica: "0"}` / `{replica: "1"}`. Alertmanager deduplicates based on all labels except `replica`.

### Thanos HA

- Prometheus pairs with Thanos Sidecar per instance
- Thanos Query deduplicates at query time via `--query.replica-label=replica`
- Object storage provides global long-term retention

### Mimir HA

- Both Prometheus instances `remote_write` to Mimir
- Mimir deduplicates using `ha_replica_label` configuration
- Horizontally scalable read and write paths
