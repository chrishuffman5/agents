# Elastic APM

## APM Agents

| Language | Agent | Key Auto-Instrumentation |
|----------|-------|--------------------------|
| Java | `elastic-apm-agent.jar` (javaagent) | Spring, Hibernate, JDBC, HTTP clients, Kafka |
| .NET | `Elastic.Apm` NuGet | ASP.NET Core, EF Core, HttpClient |
| Node.js | `elastic-apm-node` npm | Express, Fastify, pg, mysql, Redis |
| Python | `elastic-apm` pip | Django, Flask, SQLAlchemy, Redis |
| Go | `go.elastic.co/apm` | net/http, gRPC, database/sql |
| Ruby | `elastic-apm` gem | Rails, Sinatra, ActiveRecord |
| PHP | `elastic/apm-agent-php` | Auto via PHP extension |
| Browser/RUM | `@elastic/apm-rum-js` | Page load, XHR, fetch, route changes |

### Agent Setup Examples

**Java:**
```bash
java -javaagent:/opt/elastic/apm-agent.jar \
  -Delastic.apm.server_url=http://apm-server:8200 \
  -Delastic.apm.service_name=order-service \
  -Delastic.apm.environment=production \
  -Delastic.apm.secret_token=${APM_SECRET_TOKEN} \
  -Delastic.apm.application_packages=com.mycompany \
  -jar my-application.jar
```

**Node.js:**
```javascript
// Must be FIRST line
require('elastic-apm-node').start({
  serviceName: 'payment-service',
  serverUrl: 'http://apm-server:8200',
  environment: 'production',
  secretToken: process.env.APM_SECRET_TOKEN,
  transactionSampleRate: 0.1   // 10% sampling in production
});
```

**Python (Django):**
```python
INSTALLED_APPS = ['elasticapm.contrib.django']
ELASTIC_APM = {
  'SERVICE_NAME': 'user-service',
  'SERVER_URL': 'http://apm-server:8200',
  'ENVIRONMENT': 'production',
  'SECRET_TOKEN': os.environ.get('APM_SECRET_TOKEN'),
  'TRANSACTION_SAMPLE_RATE': 0.1,
}
```

## APM Data Model

| Type | Description | Data Stream |
|------|-------------|-------------|
| Transaction | Unit of work: HTTP request, job, message | `traces-apm-*` |
| Span | Operation within a transaction: DB query, HTTP call | `traces-apm-*` |
| Error | Captured exception or error log | `logs-apm.error-*` |
| Metric | Agent-collected: JVM heap, GC, CPU | `metrics-apm.app.*` |
| Profile | eBPF continuous CPU profiling | `profiling-*` |

**Key transaction fields:** `transaction.id`, `trace.id`, `parent.id`, `transaction.name` (e.g., `GET /api/orders/{id}`), `transaction.type` (`request`/`messaging`/`scheduled`), `transaction.duration.us`, `transaction.result`, `service.name`, `service.environment`.

## Distributed Tracing

W3C Trace Context (`traceparent` header) propagated automatically by all Elastic APM agents:
```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```

### Waterfall View

APM > Traces > click transaction -- spans across all services with timing, SQL query text, stack traces.

### Service Map

APM > Service Map -- auto-generated dependency graph. Node color indicates health (error rate + latency). Shows throughput and p99 on each edge.

### Correlations (8.0+)

APM automatically finds fields statistically over-represented in slow transactions or errors (e.g., `user.tier: free` correlates with latency spikes).

## OpenTelemetry Integration

```yaml
# OTel Collector exporting to Elastic APM / Elasticsearch
exporters:
  otlp/elastic:
    endpoint: "https://apm-server:8200"
    headers:
      Authorization: "ApiKey <key>"
service:
  pipelines:
    traces:   { exporters: [otlp/elastic] }
    metrics:  { exporters: [otlp/elastic] }
    logs:     { exporters: [otlp/elastic] }
```

- OTel data stored in same data streams as Elastic APM -- Kibana APM, Service Maps, dashboards work identically
- **Native OTLP endpoint (8.12+):** Elasticsearch exposes OTLP endpoints directly -- APM Server hop optional for OTel-only deployments

## Continuous Profiling (8.9+)

eBPF-based, always-on, no code changes required. Deployed as Kubernetes DaemonSet. Correlates CPU flame graphs with APM trace spans -- click a span to see its profiling data.

## Alerting for APM

### Rule Types

| Rule Type | Condition | Use Case |
|-----------|-----------|----------|
| Metric Threshold | avg/max/min of metric field | CPU > 85% for 3 consecutive minutes |
| Log Threshold | log document count | ERROR count > 100 in 10m per service |
| Anomaly (ML) | anomaly score > threshold | Unusual log rate, metric drop |
| SLO Burn Rate (8.11+) | error budget burn rate | Budget burning 14x faster than sustainable |

### SLO Alerting

Define SLOs (e.g., 99.9% of HTTP requests return 2xx in rolling 30-day window). Burn rate alerts detect rapid budget consumption:
- 14x burn rate in past 1 hour -- page immediately
- 2x burn rate in past 6 hours -- ticket

### Connectors

| Connector | Key Config |
|-----------|-----------|
| Slack | Webhook URL, Mustache message template |
| PagerDuty | Integration key, severity mapping |
| Email | SMTP config, to/cc/subject/body template |
| Webhook | URL, method, headers, body (Mustache) |
| ServiceNow | Instance URL, credentials, table name |
| OpsGenie | API key, priority mapping |

### Maintenance Windows (8.5+)

Suppress alert notifications during planned maintenance. Configure by schedule (one-time or recurring), time range, and scope (all rules or specific tags).
