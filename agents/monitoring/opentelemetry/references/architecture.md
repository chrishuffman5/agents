# OpenTelemetry Architecture

## The Three Pillars

OpenTelemetry unifies observability under three signal types, each with its own pipeline and API/SDK:

### Traces

Distributed traces represent the end-to-end journey of a request across services. Composed of `Span` objects with a `TraceID`, `SpanID`, parent reference, timestamps, status, attributes, and events. Spans form a tree (or DAG) representing causality.

### Metrics

Numeric measurements recorded at a point in time or over an interval.

**Instrument types:**
- `Counter` -- Monotonically increasing (total requests)
- `UpDownCounter` -- Can go up or down (active connections)
- `Histogram` -- Distribution of values (request duration)
- `Gauge` -- Point-in-time value (CPU utilization)
- `ObservableCounter` / `ObservableUpDownCounter` / `ObservableGauge` -- Async (callback-based) variants

Data model supports both delta and cumulative temporality.

### Logs

Structured log records with severity, body, attributes, and optional trace/span correlation fields (`TraceId`, `SpanId`, `TraceFlags`). OTel does not replace existing loggers; it bridges them via `LogRecordExporter`.

## OTel Collector

The Collector is a standalone binary that receives, processes, and exports telemetry data. It decouples instrumentation from backend concerns.

```
                  ┌─────────────────────────────────────────┐
  Application ──> │  Receiver  →  Processor  →  Exporter   │ ──> Backend
                  │              (Pipeline)                 │
                  └─────────────────────────────────────────┘
```

### Core Components

| Component | Role |
|-----------|------|
| Receivers | Ingest telemetry from sources (OTLP, Prometheus scrape, filelog, syslog, Jaeger) |
| Processors | Transform, filter, batch, and enrich data in-flight |
| Exporters | Send processed data to one or more backends |
| Connectors | Connect pipelines (output of one becomes input of another) |
| Extensions | Add capabilities without touching the pipeline (health check, pprof, zpages, auth) |

### Collector Distributions

- `otelcol` -- Upstream core distribution (minimal receivers/exporters)
- `otelcol-contrib` -- Community distribution with all available components
- **OpenTelemetry Operator** -- Kubernetes operator managing Collector as CR

## OTLP Protocol

OpenTelemetry Protocol (OTLP) is the canonical wire format for all three signals.

| Transport | Default Port | Format | Use Case |
|-----------|-------------|--------|----------|
| OTLP/gRPC | 4317 | Protocol Buffers | High throughput, streaming |
| OTLP/HTTP | 4318 | Protobuf or JSON | Firewalls, browser SDKs |

HTTP endpoints: `/v1/traces`, `/v1/metrics`, `/v1/logs`.

All three signals are GA in the specification.

## SDK Architecture

Each language SDK implements the same conceptual model:

### TracerProvider

Entry point for tracing. Created once per application. Configured with:
- `Resource` -- Describes the entity producing telemetry
- `Sampler` -- Controls which traces are recorded
- `SpanProcessor`(s) -- `BatchSpanProcessor` (production) or `SimpleSpanProcessor` (dev)
- `SpanExporter`(s) -- Where to send spans (OTLP, Jaeger, Zipkin, console)
- `Propagator`(s) -- How to propagate context across boundaries

### MeterProvider

Entry point for metrics. Configured with:
- `Resource`
- `MetricReader`(s) -- Periodic or pull-based reading
- `MetricExporter`(s) -- OTLP, Prometheus scrape endpoint, console
- `View`(s) -- Customize metric aggregation

### LoggerProvider

Entry point for logs bridge API. Configured with:
- `Resource`
- `LogRecordProcessor`(s) -- Batch or simple
- `LogRecordExporter`(s) -- OTLP, console

Bridges existing logging frameworks (Logback, log4j, Python logging, Winston).

### Resource

Immutable set of key-value attributes describing the entity producing telemetry.

**Required attributes:**
- `service.name` -- Unique service identifier
- `service.version` -- Semantic version
- `deployment.environment` -- production, staging, development

**Recommended attributes:**
- `service.namespace` -- Logical grouping
- `host.name` -- Node hostname
- `k8s.pod.name`, `k8s.namespace.name` -- Kubernetes context
- `cloud.provider`, `cloud.region` -- Cloud context
- `process.runtime.name`, `process.runtime.version` -- Runtime info

Resource detectors auto-detect attributes from cloud, container, process, and host environments.

### Exporters

| Exporter | Use |
|----------|-----|
| OTLP | Sends to Collector or OTLP-compatible backend |
| Prometheus | Exposes metrics via `/metrics` scrape endpoint |
| Zipkin | Zipkin-compatible backends |
| Console/Debug | Prints to stdout for development |
| In-Memory | For testing |

### Samplers

| Sampler | Behavior |
|---------|----------|
| `AlwaysOn` | Record all spans (100%) |
| `AlwaysOff` | Drop all spans (0%) |
| `TraceIdRatioBased` | Sample a fraction by TraceID hash |
| `ParentBased` | Respects parent sampling decision; wraps another sampler for root spans |

### Propagators

| Propagator | Headers | Use Case |
|-----------|---------|----------|
| W3C TraceContext (default) | `traceparent`, `tracestate` | Standard, recommended |
| B3 | `X-B3-TraceId`, `X-B3-SpanId`, `X-B3-Sampled` | Zipkin legacy |
| Baggage | `baggage` | Cross-service key-value metadata |
| Jaeger | `uber-trace-id` | Jaeger legacy |

### SpanProcessors

| Processor | Behavior | Use |
|-----------|----------|-----|
| `SimpleSpanProcessor` | Synchronous, exports immediately | Development/testing |
| `BatchSpanProcessor` | Async, buffers and exports in batches | Production |

BatchSpanProcessor configuration: `maxQueueSize`, `scheduledDelayMillis`, `exportTimeoutMillis`, `maxExportBatchSize`.

## Auto-Instrumentation vs Manual Instrumentation

**Auto-Instrumentation:**
- Zero code changes; libraries and frameworks instrumented via agents or monkey-patching
- Covers HTTP, database, messaging, RPC calls automatically
- Language-specific: Java agent, Python sitecustomize, .NET startup hooks, Node.js `--require`

**Manual Instrumentation:**
- Developer adds spans, attributes, events, and metrics explicitly
- Required for business logic, custom metrics, internal operations
- Uses the OTel API (stable) -- not the SDK directly -- for library authors
