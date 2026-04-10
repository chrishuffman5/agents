# OpenTelemetry Collector

## Configuration File Structure

```yaml
receivers:
  <receiver_name>:
    <config>

processors:
  <processor_name>:
    <config>

exporters:
  <exporter_name>:
    <config>

connectors:
  <connector_name>:
    <config>

extensions:
  <extension_name>:
    <config>

service:
  extensions: [<list>]
  pipelines:
    traces:
      receivers: [<list>]
      processors: [<list>]
      exporters: [<list>]
    metrics:
      receivers: [<list>]
      processors: [<list>]
      exporters: [<list>]
    logs:
      receivers: [<list>]
      processors: [<list>]
      exporters: [<list>]
  telemetry:
    logs:
      level: info
    metrics:
      address: 0.0.0.0:8888
```

## Receivers

### otlp -- OTLP over gRPC and HTTP

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        max_recv_msg_size_mib: 4
      http:
        endpoint: 0.0.0.0:4318
        cors:
          allowed_origins: ["*"]
```

### prometheus -- Scrape Prometheus-format endpoints

```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: my-service
          scrape_interval: 15s
          static_configs:
            - targets: [localhost:8080]
```

### filelog -- Tail and parse log files

```yaml
receivers:
  filelog:
    include: [/var/log/app/*.log]
    start_at: beginning
    operators:
      - type: json_parser
        timestamp:
          parse_from: attributes.time
          layout: "%Y-%m-%dT%H:%M:%S.%LZ"
      - type: severity_parser
        parse_from: attributes.level
```

### hostmetrics -- Host-level metrics (CPU, memory, disk, network)

```yaml
receivers:
  hostmetrics:
    collection_interval: 10s
    scrapers:
      cpu:
        metrics:
          system.cpu.utilization:
            enabled: true
      memory:
      disk:
      filesystem:
      network:
      load:
      processes:
```

### k8s_cluster -- Kubernetes cluster-level metrics

```yaml
receivers:
  k8s_cluster:
    collection_interval: 10s
    node_conditions_to_report: [Ready, MemoryPressure, DiskPressure]
    allocatable_types_to_report: [cpu, memory, ephemeral-storage]
```

### journald -- Systemd journal

```yaml
receivers:
  journald:
    directory: /run/log/journal
    units: [ssh, docker, kubelet]
    priority: info
```

### jaeger -- Jaeger-format traces

```yaml
receivers:
  jaeger:
    protocols:
      thrift_http:
        endpoint: 0.0.0.0:14268
      grpc:
        endpoint: 0.0.0.0:14250
```

## Processors

### batch -- Buffer and send in batches

```yaml
processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
    send_batch_max_size: 2048
```

### memory_limiter -- Prevent OOM (MUST be first processor)

```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128
```

### attributes -- Add, update, delete, hash attributes

```yaml
processors:
  attributes:
    actions:
      - key: environment
        value: production
        action: insert
      - key: http.user_agent
        action: delete
      - key: db.statement
        action: hash
      - key: service.name
        from_attribute: k8s.pod.labels.app
        action: upsert
```

### resource -- Mutate Resource attributes

```yaml
processors:
  resource:
    attributes:
      - key: cloud.provider
        value: aws
        action: insert
      - key: host.name
        from_attribute: k8s.node.name
        action: upsert
```

### filter -- Drop spans, metrics, or logs (OTTL expressions)

```yaml
processors:
  filter:
    error_mode: ignore
    traces:
      span:
        - 'attributes["http.route"] == "/healthz"'
        - 'attributes["http.route"] == "/readyz"'
    metrics:
      metric:
        - 'name == "go_gc_duration_seconds"'
    logs:
      log_record:
        - 'severity_number < SEVERITY_NUMBER_WARN'
```

### tail_sampling -- Sample traces after all spans arrive

```yaml
processors:
  tail_sampling:
    decision_wait: 10s
    num_traces: 50000
    expected_new_traces_per_sec: 100
    policies:
      - name: errors-policy
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: slow-policy
        type: latency
        latency: {threshold_ms: 1000}
      - name: rate-limiting
        type: rate_limiting
        rate_limiting: {spans_per_second: 1000}
      - name: probabilistic-policy
        type: probabilistic
        probabilistic: {sampling_percentage: 10}
```

### transform -- Mutate telemetry using OTTL

```yaml
processors:
  transform:
    error_mode: ignore
    trace_statements:
      - context: span
        statements:
          - set(attributes["http.target"], "/redacted") where attributes["http.target"] == "/token"
          - truncate_all(attributes, 4096)
    log_statements:
      - context: log_record
        statements:
          - set(severity_text, "WARN") where severity_number == SEVERITY_NUMBER_WARN
```

### k8sattributes -- Enrich with Kubernetes metadata

```yaml
processors:
  k8sattributes:
    auth_type: serviceAccount
    passthrough: false
    extract:
      metadata:
        - k8s.namespace.name
        - k8s.deployment.name
        - k8s.pod.name
        - k8s.node.name
      labels:
        - tag_name: app
          key: app
          from: pod
    pod_association:
      - sources:
          - from: resource_attribute
            name: k8s.pod.ip
```

## Exporters

### otlp -- OTLP/gRPC to downstream Collector or backend

```yaml
exporters:
  otlp:
    endpoint: otelcol-gateway:4317
    tls:
      insecure: false
      ca_file: /certs/ca.crt
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 1000
```

### otlphttp -- OTLP/HTTP to backend

```yaml
exporters:
  otlphttp:
    endpoint: https://api.honeycomb.io
    headers:
      x-honeycomb-team: ${env:HONEYCOMB_API_KEY}
```

### prometheus -- Expose as Prometheus scrape endpoint

```yaml
exporters:
  prometheus:
    endpoint: 0.0.0.0:9464
    namespace: otel
    send_timestamps: true
    metric_expiration: 180m
    enable_open_metrics: true
```

### prometheusremotewrite -- Push to Prometheus/Mimir/Cortex

```yaml
exporters:
  prometheusremotewrite:
    endpoint: http://mimir:9009/api/v1/push
    resource_to_telemetry_conversion:
      enabled: true
```

### elasticsearch -- Logs and traces to Elasticsearch

```yaml
exporters:
  elasticsearch:
    endpoint: https://elasticsearch:9200
    user: elastic
    password: ${env:ES_PASSWORD}
    logs_index: otel-logs
    traces_index: otel-traces
```

### loki -- Logs to Grafana Loki

```yaml
exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    default_labels_enabled:
      exporter: false
      job: true
      instance: true
      level: true
```

### debug -- Print to stdout (development)

```yaml
exporters:
  debug:
    verbosity: detailed
    sampling_initial: 5
    sampling_thereafter: 200
```

## Pipeline Examples

### Example 1: Basic All-in-One

```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp]
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
    logs:
      receivers: [otlp, filelog]
      processors: [memory_limiter, batch]
      exporters: [loki]
```

### Example 2: Kubernetes Full-Stack

```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, k8sattributes, resource, batch]
      exporters: [otlp/tempo]
    metrics:
      receivers: [otlp, hostmetrics, k8s_cluster, prometheus]
      processors: [memory_limiter, k8sattributes, resource, batch]
      exporters: [prometheusremotewrite]
    logs:
      receivers: [otlp, filelog, journald]
      processors: [memory_limiter, k8sattributes, resource, attributes, batch]
      exporters: [loki]
```

### Example 3: Tail Sampling with Fan-Out

```yaml
service:
  pipelines:
    traces/ingest:
      receivers: [otlp]
      processors: [memory_limiter, tail_sampling]
      exporters: [otlp/tempo, otlp/datadog]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, filter, batch]
      exporters: [prometheusremotewrite]
```

### Example 4: Gateway with Load Balancing

```yaml
exporters:
  loadbalancing:
    protocol:
      otlp:
        tls:
          insecure: true
    resolver:
      dns:
        hostname: otelcol-sampler
        port: 4317
        interval: 5s
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter]
      exporters: [loadbalancing]
```

### Example 5: Spanmetrics Connector (RED Metrics from Traces)

```yaml
connectors:
  spanmetrics:
    histogram:
      explicit:
        buckets: [2ms, 4ms, 6ms, 8ms, 10ms, 50ms, 100ms, 200ms, 400ms, 800ms, 1s, 2s, 5s, 10s]
    dimensions:
      - name: http.method
      - name: http.status_code
    exemplars:
      enabled: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [spanmetrics, otlp/tempo]
    metrics:
      receivers: [spanmetrics]
      processors: [batch]
      exporters: [prometheusremotewrite]
```
