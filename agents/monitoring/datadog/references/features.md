# Datadog Features Reference

> Metrics, log management, APM, monitors, and SLOs.

---

## Metrics & Infrastructure

### Metric Query Language

Metric queries follow the pattern:

```
aggregation:metric_name{tag_filter} by {group_by}
```

Examples:
```
avg:system.cpu.user{env:production} by {host}
sum:aws.elb.request_count{service:checkout} by {availability-zone}.as_rate()
p99:trace.web.request.duration{service:api,env:prod}
```

**Aggregation functions:** `avg`, `sum`, `min`, `max`, `count`
**Space aggregation:** Applied across the `by {}` grouping
**Time aggregation:** Rollup over time windows (`.rollup(sum, 60)`)
**Math functions:** `abs()`, `log2()`, `cumsum()`, `diff()`, `fill()`, `top()`

### Host Maps and Container Maps

- **Host Map** -- Visual grid of all monitored hosts; color/size by any metric; group/filter by tags
- **Container Map** -- Same concept for containers; shows resource utilization per container
- Both support tag-based filtering and grouping for fleet-wide status at a glance

---

## Log Management

### Log Collection Methods

**Agent log collection** (file tailing, journald, Docker/container logs):
```yaml
# /etc/datadog-agent/conf.d/python.d/conf.yaml
logs:
  - type: file
    path: /var/log/myapp/*.log
    service: myapp
    source: python
    env: production
```

**Logs API (direct HTTP intake):**
```bash
curl -X POST "https://http-intake.logs.datadoghq.com/v1/input" \
  -H "DD-API-KEY: <API_KEY>" \
  -H "Content-Type: application/json" \
  -d '[{"message":"Payment processed","service":"payments","ddsource":"nodejs","env":"prod"}]'
```

**Cloud log forwarding:** AWS CloudWatch Logs via Lambda forwarder, S3 access logs via Lambda, Azure Event Hub via Function, GCP Cloud Logging via Pub/Sub.

### Log Processing Pipelines

Pipelines apply processors to incoming logs in order. Each log matches at most one pipeline (based on filter).

| Processor | Purpose |
|-----------|---------|
| Grok Parser | Extract structured fields from raw text using named patterns |
| Date Remapper | Set `date` attribute from parsed timestamp field |
| Status Remapper | Map severity strings to Datadog log status |
| Service Remapper | Set the `service` attribute |
| Attribute Remapper | Rename/copy attributes |
| URL Parser | Parse query parameters from URLs |
| Category Processor | Assign category tag based on conditions |
| Arithmetic Processor | Compute new numeric attributes |
| Lookup Processor | Enrich with external reference table |
| Trace ID Remapper | Link logs to APM traces via trace ID |
| Message Remapper | Designate official log message field |

**Grok parser example:**
```
%{ip:network.client.ip} - %{notSpace:http.auth} \[%{date("dd/MMM/yyyy:HH:mm:ss Z"):date}\] "%{word:http.method} %{notSpace:http.url} HTTP/%{number:http.version}" %{number:http.status_code} %{number:network.bytes_written}
```

### Indexes and Exclusion Filters

Logs are retained in indexes which define retention period (3, 7, 15, 30 days). Exclusion filters drop logs before indexing (they still pass through pipelines and can generate metrics).

**Cost control strategy:**
- Index high-value logs (ERROR, WARN, production)
- Exclude noisy DEBUG/INFO logs with exclusion filters
- Use sampling in exclusion filters (keep 10% of health-check INFO logs)
- Route excluded logs to archives for compliance

### Log Archives

Long-term cold storage for compliance. Destinations: S3, Azure Blob, GCS. Format: compressed JSON. Rehydration brings archived logs back into indexes on demand (billed per GB).

### Log-Based Metrics

Generate custom metrics from log data without storing individual logs:
```
Metric: logs.error.count
Filter: status:error
Measure: count
Group by: service, env
```

Far cheaper than indexing every log when you only need aggregate counts.

### Live Tail

Real-time streaming view of incoming logs. Zero-retention debugging tool. Does not affect indexing or cost.

---

## APM & Distributed Tracing

### Tracing Libraries

| Language | Package | Install |
|----------|---------|---------|
| Java | `dd-java-agent.jar` | `-javaagent:/path/to/dd-java-agent.jar` |
| Python | `ddtrace` | `pip install ddtrace`, run with `ddtrace-run python app.py` |
| .NET | `Datadog.Trace` | NuGet package + `DD_DOTNET_TRACER_HOME` |
| Node.js | `dd-trace` | `npm install dd-trace`, `require('dd-trace').init()` |
| Go | `dd-trace-go.v1` | Import contrib packages per framework |
| Ruby | `ddtrace` gem | `require 'datadog/auto_instrument'` |
| PHP | `datadog/dd-trace` | PHP extension via package manager |

**Environment variables for all libraries:**
```bash
DD_AGENT_HOST=localhost
DD_TRACE_AGENT_PORT=8126
DD_SERVICE=checkout-api
DD_ENV=production
DD_VERSION=1.4.2
DD_TRACE_SAMPLE_RATE=0.1   # 10% sampling
```

### Distributed Tracing Concepts

Traces propagate context via HTTP headers (`x-datadog-trace-id`, `x-datadog-parent-id`, `x-datadog-sampling-priority`). Also supports W3C TraceContext and B3 for OpenTelemetry/Zipkin interoperability.

A **trace** consists of **spans**. Each span has: `service`, `resource` (e.g., `GET /api/orders`), `duration`, `error` flag, and arbitrary metadata.

### Key APM Features

- **Service Catalog** -- Registry of all services from APM traces with ownership, docs, SLOs
- **Service Map** -- Auto-generated dependency graph colored by error rate or latency
- **Flame Graphs** -- Per-trace waterfall showing span hierarchy and critical path
- **Trace Explorer** -- Search/aggregate trace data by service, resource, status, duration
- **Continuous Profiler** -- Always-on CPU/memory profiling correlated with traces

### Trace Sampling

**Ingestion controls:**
- `DD_TRACE_SAMPLE_RATE=0.1` -- Library-level 10% sampling
- **Ingestion Rules** -- Per-service sampling rates in Datadog UI
- **Retention Filters** -- Control which ingested spans are indexed for search (15-day default)

**Tracing Without Limits:** Adaptive sampling ensures 100% of traces with errors, rare operations, and long-running spans are always kept regardless of sampling rate.

---

## Monitors & Alerting

### Monitor Types

| Type | Use Case |
|------|----------|
| Metric Monitor | Threshold breach on any metric (simple or anomaly) |
| Log Monitor | Log search query count exceeds threshold |
| APM Monitor | Error rate, p99 latency, hits/s from trace metrics |
| Composite Monitor | Boolean combination (AND, OR) of multiple monitors |
| Forecast Monitor | Predict future metric value breach |
| Anomaly Monitor | ML-detected deviation from expected pattern |
| Outlier Monitor | One host/group behaves differently from peers |
| Process Monitor | Process not running on host |
| SLO Alert Monitor | Error budget consumed too fast |
| Watchdog Monitor | Auto-detected anomalies (no config needed) |

### Monitor Configuration Example

```yaml
Monitor name: "API p99 latency > 500ms"
Metric query: avg(last_5m):p99:trace.web.request{service:api,env:production} > 0.5
Alert threshold: 0.5
Warning threshold: 0.3
Recovery threshold: 0.25
Notify: @slack-on-call-channel, @pagerduty-api-team
```

**Multi-alert:** Use `by {host}` or `by {service}` to create one monitor alerting separately per group.

### Notification Channels

| Channel | Syntax | Notes |
|---------|--------|-------|
| Slack | `@slack-channel-name` | Requires Slack integration |
| PagerDuty | `@pagerduty-service-name` | Maps severity to PD urgency |
| Email | `@user@company.com` | Direct or team list |
| Webhook | `@webhook-name` | JSON to HTTPS endpoint |
| Opsgenie | `@opsgenie-team` | Via native integration |
| Microsoft Teams | `@teams-channel` | Via Teams integration |

### Downtime

Silence monitors during maintenance. Supports tag-based scope (mute all `env:staging` monitors), scheduled (recurring), and one-off windows.

---

## SLOs (Service Level Objectives)

### Monitor-Based SLO

Aggregates uptime from an existing monitor. Tracks % of time monitor was in OK state.

### Metric-Based SLO

Defines a ratio of good events to total events:

```
Good events:  sum:trace.web.request.hits{service:api,http.status_code:2xx}.as_count()
Total events: sum:trace.web.request.hits{service:api}.as_count()
Target: 99.9% over 30 days
```

### SLO Alerts

Burn-rate alerts notify when error budget is being consumed faster than sustainable. Supports multi-window burn-rate alerts (1h + 5min for fast burn, 6h + 30min for slow burn).

---

## Log Search Syntax

```
service:api status:error @http.status_code:500
```

- **Facets** -- Indexed field extractions for sidebar filtering
- **Log Analytics** -- Count, unique count, measure aggregations with GROUP BY
- **Saved Views** -- Bookmark search queries + facet state
- **Patterns** -- ML-clustered similar log messages
