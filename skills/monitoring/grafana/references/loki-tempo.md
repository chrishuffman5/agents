# Loki and Tempo Integration

## Loki Overview

Grafana Loki is a horizontally scalable, multi-tenant log aggregation system. It indexes only metadata (labels), not log content, making it more cost-effective than full-text indexing solutions. Log collection agents (Grafana Alloy, Promtail, Fluentd, Fluentbit) attach labels and ship log streams to the Loki push API.

## Loki Data Source Configuration

```yaml
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: false
    jsonData:
      maxLines: 1000
      timeout: 60
      derivedFields:
        - name: TraceID
          matcherRegex: '"traceId":"(\w+)"'
          url: '${__value.raw}'
          datasourceUid: tempo-uid
```

Key `jsonData` options:
- `maxLines` -- Cap on log lines returned per query
- `timeout` -- Query timeout in seconds
- `derivedFields` -- Extract values from log lines and render as links (e.g., trace IDs linking to Tempo)

## LogQL

LogQL is the query language for Loki. Queries consist of a **log stream selector** and an optional **log pipeline**.

### Stream Selectors (Label Matchers)

```logql
{app="nginx", env="prod"}               # exact match
{app=~"nginx|apache"}                   # regex match
{app!="mysql"}                          # negative match
{app!~"test.*"}                         # negative regex
```

### Filter Expressions

```logql
{app="api"} |= "error"                  # line contains string
{app="api"} != "health"                 # line does not contain
{app="api"} |~ "ERR|WARN"              # regex match
{app="api"} !~ "debug.*"               # regex exclude
```

### Parser Expressions

```logql
{app="api"} | json                      # parse JSON; extract keys as labels
{app="api"} | logfmt                    # parse key=value format
{app="api"} | pattern "<ip> - <user> [<ts>] \"<method> <path> <proto>\" <status>"
{app="api"} | regexp "(?P<level>\\w+) (?P<msg>.*)"
```

### Label Filter Expressions (Post-Parse)

```logql
{app="api"} | json | level="error"
{app="api"} | json | status >= 500
{app="api"} | json | duration > 1s
```

### Line Format Expression

```logql
{app="api"} | json | line_format "{{.level}} {{.msg}}"
```

### Metric Queries (Log-to-Metric)

```logql
# Rate of log lines per second
rate({app="api"}[5m])

# Count of error logs per minute, grouped by pod
sum by (pod) (count_over_time({app="api"} |= "error" [1m]))

# Quantile over extracted numeric field
quantile_over_time(0.99, {app="api"} | json | unwrap duration [5m]) by (endpoint)
```

Metric queries produce time series that can be graphed and used in alert rules.

### LogQL Best Practices

- Use narrow stream selectors (label-based filtering is fast; content filtering is slow)
- Add line filters (`|=`, `!=`) before parsers to reduce parsing volume
- Avoid high-cardinality labels in Loki (same principle as Prometheus)
- Use `rate()` and `count_over_time()` for log-based alerting

## Tempo Overview

Grafana Tempo is a high-volume, cost-efficient distributed tracing backend that stores traces in object storage (S3, GCS, Azure Blob). It accepts traces via OTLP, Jaeger, Zipkin, and Kafka.

## Tempo Data Source Configuration

```yaml
apiVersion: 1
datasources:
  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    jsonData:
      httpMethod: GET
      tracesToLogsV2:
        datasourceUid: loki-uid
        tags: [{ key: "service.name", value: "app" }]
        filterByTraceID: true
      tracesToMetrics:
        datasourceUid: prometheus-uid
        tags: [{ key: "service.name", value: "job" }]
        queries:
          - name: Request rate
            query: sum(rate(traces_spanmetrics_calls_total{$$__tags}[5m]))
      serviceMap:
        datasourceUid: prometheus-uid
      nodeGraph:
        enabled: true
      lokiSearch:
        datasourceUid: loki-uid
```

## TraceQL

TraceQL selects traces and spans using a pipeline syntax.

### Span Attribute Selectors

```traceql
{ span.http.method = "GET" }             # span attribute
{ resource.service.name = "api" }        # resource attribute
{ duration > 500ms }                     # intrinsic: duration
{ status = error }                       # intrinsic: status
{ name = "GET /api/v1/users" }          # intrinsic: span name
```

### Combining Conditions

```traceql
{ span.http.method = "POST" && duration > 1s }
{ resource.service.name =~ "api|gateway" }
{ span.http.status_code >= 500 }
```

### Structural Operators (Parent/Child/Sibling)

```traceql
{ resource.service.name = "frontend" } >> { status = error }
# traces where frontend span has a descendant with error status
```

### TraceQL Metrics (Public Preview)

```traceql
{ resource.service.name = "api" } | rate()
{ status = error } | rate() by (resource.service.name)
{ duration > 1s } | histogram_over_time(duration) by (span.http.route)
```

## Trace Correlations

The power of the LGTM stack lies in connecting all three pillars:

### Trace to Logs

Click a span in the trace waterfall; Grafana opens a Loki query filtered by trace ID and time range. Configured via `tracesToLogsV2` in the Tempo data source settings.

### Trace to Metrics

Click a span; Grafana opens a Prometheus query using span attributes as metric labels. Configured via `tracesToMetrics`. The `$__tags` macro converts span attributes to metric label matchers.

### Metrics to Traces (Exemplars)

Prometheus exemplars embed trace IDs in metric samples. Clicking an exemplar point in a time series panel opens the linked trace in Tempo. Requires exemplar support enabled in the Prometheus data source.

### Logs to Traces

Derived fields in the Loki data source extract trace IDs from log lines and render them as clickable links to Tempo. Configure via `derivedFields` in the Loki data source `jsonData`.

### Correlation Flow

```
Grafana Dashboard (metrics) ──(exemplar click)──> Tempo (trace waterfall)
                                                       │
                                         (span click)──> Loki (correlated logs)
                                                       │
                                         (span click)──> Prometheus (related metrics)

Loki Explore (logs) ──(derived field click)──> Tempo (trace waterfall)
```

This bidirectional linking enables a complete debugging workflow: detect anomalies in metrics, identify affected traces, find root cause in logs.
