# Prometheus Configuration

## prometheus.yml Structure

```yaml
# Global configuration
global:
  scrape_interval: 15s          # how often to scrape targets
  evaluation_interval: 15s      # how often to evaluate rules
  scrape_timeout: 10s           # timeout per scrape (must be <= scrape_interval)
  external_labels:              # labels added to all time series sent to remote
    cluster: prod-us-east-1
    replica: prometheus-0

# Rule files (glob supported)
rule_files:
  - /etc/prometheus/rules/*.yml
  - /etc/prometheus/alerts/*.yml

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093
      timeout: 10s
      api_version: v2

# Remote write (Thanos/Mimir/Cortex)
remote_write:
  - url: https://mimir.example.com/api/v1/push
    basic_auth:
      username: prometheus
      password_file: /etc/prometheus/remote-write-password
    tls_config:
      ca_file: /etc/ssl/certs/ca-certificates.crt
    queue_config:
      capacity: 2500
      max_shards: 200
      min_shards: 1
      max_samples_per_send: 500
      batch_send_deadline: 5s
    write_relabel_configs:
      - source_labels: [__name__]
        regex: 'go_.*'
        action: drop                  # don't remote-write Go runtime metrics

# Remote read
remote_read:
  - url: https://thanos-query.example.com/api/v1/read
    read_recent: false                # only read if data older than local retention

# Scrape configurations
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']
```

## Scrape Config Options

```yaml
scrape_configs:
  - job_name: api-servers
    scrape_interval: 10s              # override global
    scrape_timeout: 8s
    metrics_path: /metrics            # default
    scheme: https
    params:
      collect[]:
        - cpu
        - meminfo
    tls_config:
      cert_file: /etc/certs/client.crt
      key_file: /etc/certs/client.key
      insecure_skip_verify: false
    basic_auth:
      username: scrape-user
      password_file: /etc/prometheus/scrape-password
    honor_labels: false               # overwrite conflicting labels from target
    honor_timestamps: true            # use timestamps from target if present
    follow_redirects: true
    enable_compression: true          # accept compressed responses (3.x)
    body_size_limit: 100MB            # reject responses larger than this (3.x)
    sample_limit: 50000               # reject scrape if more than N samples
    label_limit: 30                   # max labels per sample
    label_name_length_limit: 200
    label_value_length_limit: 200
```

## Kubernetes SD Scrape Config

```yaml
scrape_configs:
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: [default, production, staging]
    relabel_configs:
      # Only scrape pods with annotation prometheus.io/scrape: "true"
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: "true"
      # Allow overriding metrics path via annotation
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      # Allow overriding port via annotation
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      # Copy pod name as label
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
      # Copy namespace as label
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      # Copy app label from pod labels
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: app
```

## Relabeling Patterns

Relabeling is the most powerful configuration mechanism. Two stages:

- **`relabel_configs`:** Applied before scraping, on the target itself. Can modify `__address__`, `__metrics_path__`, etc. or drop targets entirely.
- **`metric_relabel_configs`:** Applied after scraping, on each sample. Can drop or modify individual metrics.

### Relabeling Actions

| Action | Purpose |
|--------|---------|
| `keep` | Keep target/sample only if regex matches |
| `drop` | Drop target/sample if regex matches |
| `replace` | Replace `target_label` with `replacement` (regex capture groups `$1`, `$2`) |
| `labelmap` | Copy labels matching regex, using replacement as new name pattern |
| `labeldrop` | Drop labels matching regex |
| `labelkeep` | Keep only labels matching regex |
| `lowercase` / `uppercase` | Case conversion (2.36+/3.x) |
| `hashmod` | Hash source label and mod by modulus (for sharding) |

### Common metric_relabel_configs Patterns

```yaml
metric_relabel_configs:
  # Drop high-cardinality or useless metrics
  - source_labels: [__name__]
    regex: 'go_memstats_.*'
    action: drop

  # Drop metrics with specific label values
  - source_labels: [handler]
    regex: '/healthz|/readyz|/metrics'
    action: drop

  # Normalize environment label values
  - source_labels: [env]
    regex: 'production|prod'
    target_label: env
    replacement: prod

  # Remove high-cardinality labels
  - regex: 'user_id|request_id|trace_id'
    action: labeldrop
```

### Sharding with hashmod

Distribute scrape targets across multiple Prometheus instances:

```yaml
relabel_configs:
  - source_labels: [__address__]
    modulus: 3          # total number of Prometheus instances
    target_label: __tmp_hash
    action: hashmod
  - source_labels: [__tmp_hash]
    regex: 0            # this instance handles shard 0
    action: keep
```

## Recording Rules

Pre-compute expensive expressions. Results are stored in TSDB like any scraped metric.

```yaml
groups:
  - name: api_aggregations
    interval: 30s
    rules:
      # Naming convention: level:metric:operations
      - record: job:http_requests_total:rate5m
        expr: sum by (job) (rate(http_requests_total[5m]))

      - record: job_status:http_requests_total:rate5m
        expr: sum by (job, status) (rate(http_requests_total[5m]))

      - record: job:http_request_duration_seconds:p99
        expr: |
          histogram_quantile(0.99,
            sum by (job, le) (rate(http_request_duration_seconds_bucket[5m]))
          )
```

**Naming convention:** `level:metric:operations`
- `level`: aggregation level (e.g., `job`, `cluster`, `instance`)
- `metric`: base metric name
- `operations`: transformations (e.g., `rate5m`, `p99`, `ratio`)

**When to use recording rules:**
- Dashboard panels that query the same expensive expression
- Alert rules with complex expressions (pre-compute to reduce evaluation load)
- Cross-service aggregations used by multiple consumers
- Reducing query-time cardinality (aggregate high-cardinality source into low-cardinality recording)

## OTLP Receiver Configuration (Prometheus 3.x)

```yaml
otlp:
  promote_resource_attributes:
    - service.name
    - service.namespace
    - k8s.cluster.name
  translation_strategy: UnderscoreEscapingWithSuffixes
```

This enables the `/api/v1/otlp/v1/metrics` endpoint for receiving OpenTelemetry metrics directly.

## Metric Naming Conventions

**Structure:** `<namespace>_<subsystem>_<name>_<unit>`

- All lowercase, words separated by underscores
- Units as base SI unit suffix: `_seconds`, `_bytes`, `_ratio`, `_total`
- **Never** use abbreviated units (`_ms`, `_kb`)

| Type | Convention | Example |
|------|-----------|---------|
| Counter | End in `_total` | `http_requests_total`, `errors_total` |
| Gauge | Descriptive suffix | `memory_usage_bytes`, `active_connections` |
| Histogram | Base name (auto-creates `_bucket`, `_sum`, `_count`) | `http_request_duration_seconds` |
| Info | End in `_info`, value always 1 | `build_info{version="1.2.3"}` |

## Command-Line Flags

Key operational flags:

```bash
prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=30d \
  --storage.tsdb.retention.size=500GB \
  --storage.tsdb.wal-compression=true \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle \        # enable /-/reload and /-/quit
  --web.enable-admin-api \        # enable /api/v1/admin/* (delete series, snapshots)
  --query.max-samples=50000000 \  # prevent runaway queries
  --query.timeout=2m
```

**Configuration reload:** Send SIGHUP or POST to `/-/reload` (requires `--web.enable-lifecycle`).

**Validate config before applying:**
```bash
promtool check config /etc/prometheus/prometheus.yml
promtool check rules /etc/prometheus/rules/*.yml
```
