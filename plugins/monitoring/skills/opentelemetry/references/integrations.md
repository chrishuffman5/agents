# OpenTelemetry Integrations

## OTel to Prometheus (Metrics)

### Option A: SDK Exposes Prometheus Endpoint Directly

The application SDK serves a `/metrics` endpoint that Prometheus scrapes:

```python
from opentelemetry.exporter.prometheus import PrometheusExporter
exporter = PrometheusExporter(port=8000)  # serves at :8000/metrics
```

### Option B: Collector Pushes via Prometheus Remote Write

```yaml
exporters:
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
    resource_to_telemetry_conversion:
      enabled: true   # converts Resource attrs to metric labels
```

### Option C: Collector Exposes Scrape Endpoint

```yaml
exporters:
  prometheus:
    endpoint: 0.0.0.0:9464
```

### Option D: OTLP Push to Prometheus 3.x

Prometheus 3.x accepts OTLP metrics directly at `/api/v1/otlp/v1/metrics`. No Collector needed for simple setups.

## OTel to Grafana Tempo (Traces)

```yaml
exporters:
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true
```

Tempo natively accepts OTLP/gRPC and OTLP/HTTP. Exemplars in Prometheus metrics link to Tempo trace IDs, enabling metrics-to-traces correlation in Grafana.

## OTel to Grafana Loki (Logs)

```yaml
exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    default_labels_enabled:
      job: true
      instance: true
      level: true
```

In Grafana, configure Loki derived fields to extract trace IDs from log lines and link to Tempo for log-to-trace correlation.

## OTel to Elasticsearch

```yaml
exporters:
  elasticsearch:
    endpoint: https://elasticsearch:9200
    user: elastic
    password: ${env:ES_PASSWORD}
    logs_index: otel-logs-%{yyyy.MM.dd}
    traces_index: otel-traces-%{yyyy.MM.dd}
    mapping:
      mode: ecs  # Elastic Common Schema alignment
```

Kibana APM UI integrates with OTel traces when sent to Elasticsearch. Native OTLP endpoint available in Elasticsearch 8.12+.

## OTel to Datadog

```yaml
exporters:
  datadog:
    api:
      key: ${env:DD_API_KEY}
      site: datadoghq.com
    traces:
      span_name_as_resource_name: true
    metrics:
      histograms:
        mode: distributions
```

## OTel to New Relic

```yaml
exporters:
  otlphttp/newrelic:
    endpoint: https://otlp.nr-data.net
    headers:
      api-key: ${env:NEW_RELIC_LICENSE_KEY}
```

New Relic accepts OTLP natively. All three signals (traces, metrics, logs) are supported.

## OTel to Dynatrace

```yaml
exporters:
  otlphttp/dynatrace:
    endpoint: https://{your-environment-id}.live.dynatrace.com/api/v2/otlp
    headers:
      Authorization: "Api-Token ${env:DT_API_TOKEN}"
```

## Kubernetes Deployment Patterns

### DaemonSet (Node Agent)

One Collector per node. Ideal for hostmetrics, filelog, journald collection.

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-daemonset
spec:
  mode: daemonset
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
      hostmetrics:
        collection_interval: 30s
        scrapers:
          cpu:
          memory:
          filesystem:
      filelog:
        include: [/var/log/pods/*/*/*.log]
        include_file_path: true
    processors:
      k8sattributes:
        auth_type: serviceAccount
      batch:
    exporters:
      otlp:
        endpoint: otel-gateway:4317
    service:
      pipelines:
        metrics:
          receivers: [hostmetrics]
          processors: [k8sattributes, batch]
          exporters: [otlp]
        logs:
          receivers: [otlp, filelog]
          processors: [k8sattributes, batch]
          exporters: [otlp]
        traces:
          receivers: [otlp]
          processors: [k8sattributes, batch]
          exporters: [otlp]
```

### Sidecar

Collector as sidecar container. Isolates per-pod telemetry.

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-sidecar
spec:
  mode: sidecar
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: localhost:4317
    processors:
      batch:
    exporters:
      otlp:
        endpoint: otel-gateway:4317
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [otlp]
```

### Deployment (Gateway)

Centralized Collector fleet. Handles tail sampling, fan-out, and heavy processing.

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-gateway
spec:
  mode: deployment
  replicas: 3
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
    processors:
      memory_limiter:
        limit_mib: 1500
      tail_sampling:
        decision_wait: 10s
        policies:
          - name: error-or-slow
            type: and
            and:
              and_sub_policy:
                - name: status-check
                  type: status_code
                  status_code: {status_codes: [ERROR]}
                - name: latency-check
                  type: latency
                  latency: {threshold_ms: 500}
          - name: sample-rest
            type: probabilistic
            probabilistic: {sampling_percentage: 5}
      batch:
    exporters:
      otlp/tempo:
        endpoint: tempo:4317
        tls:
          insecure: true
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, tail_sampling, batch]
          exporters: [otlp/tempo]
```

## Collector Scaling

### Agent-Gateway Pattern

- **Agents (DaemonSet)** -- Lightweight; forward to gateway; minimal processing
- **Gateway (Deployment)** -- Heavy processing (tail sampling, enrichment); scales horizontally

### Memory Management

- Always include `memory_limiter` as the FIRST processor in every pipeline
- Set `limit_mib` to 80% of container memory limit
- Set `spike_limit_mib` to 20-25% of `limit_mib`

### Queue and Retry

- Enable `sending_queue` on exporters for resilience against backend outages
- Set `retry_on_failure` with exponential backoff

### Collector Self-Observability

```yaml
service:
  telemetry:
    logs:
      level: warn          # info in dev, warn in prod
    metrics:
      address: 0.0.0.0:8888  # scrape Collector's own metrics
```

Scrape `http://otelcol:8888/metrics` for: queue size, dropped spans, export errors.

## Security Considerations

- Use TLS for all OTLP connections in production (`tls.insecure: false`)
- Authenticate with API keys via environment variables, not hardcoded in config
- Use the `filter` processor to remove sensitive data (PII, secrets) before exporting
- Hash PII attributes with the `attributes` processor `hash` action
- Apply RBAC to Kubernetes service accounts used by Collector for pod/node metadata
- Rotate API keys and use secret management (Vault, AWS Secrets Manager)

## Semantic Conventions Quick Reference

### HTTP

```
http.request.method    -> GET, POST, etc.
http.response.status_code -> 200, 404, etc.
http.route             -> /users/{id}
url.full               -> https://example.com/users/123
server.address         -> example.com
```

### Database

```
db.system              -> postgresql, mysql, redis, mongodb
db.name                -> my_database
db.operation           -> SELECT, INSERT
db.statement           -> SELECT * FROM users WHERE id = ?
```

### Messaging

```
messaging.system       -> kafka, rabbitmq, aws_sqs
messaging.destination.name -> my-topic
messaging.operation    -> publish, receive, process
```

### Resource Attributes

Every service MUST set:
- `service.name` -- Unique service identifier
- `service.version` -- Semantic version
- `deployment.environment` -- production, staging, development

Recommended: `service.namespace`, `host.name`, `k8s.pod.name`, `cloud.provider`, `cloud.region`.
