# New Relic Architecture Reference

> Platform overview, agents, OpenTelemetry, Pixie, data model, and account structure.

---

## Platform Overview

New Relic One is a unified observability platform delivered as fully managed SaaS. All data flows into NRDB (New Relic Database), enabling correlation across metrics, events, logs, and traces without managing infrastructure.

### Core Capabilities

| Capability | Description |
|------------|-------------|
| APM | Distributed tracing, service maps, transaction traces, error analytics |
| Infrastructure | Host metrics, process data, cloud integrations (AWS, Azure, GCP) |
| Logs | Centralized log management with log-in-context for APM/infra correlation |
| Browser | Real User Monitoring (RUM), Core Web Vitals, JS error tracking |
| Mobile | iOS/Android performance, crash reporting, HTTP error tracking |
| Synthetics | Scripted monitors (ping, browser, API), global and private locations |
| Network Monitoring | Flow data (SNMP, NetFlow, sFlow), device health |
| Errors Inbox | Unified error triaging across APM, Browser, Mobile |
| Vulnerability Management | CVE detection in application dependencies |
| Pixie (K8s) | In-cluster eBPF observability without instrumentation |

---

## Data Ingestion & Agents

### APM Agents

Language-specific auto-instrumentation agents:
- Java, .NET, Node.js, Python, Ruby, PHP, Go, C SDK
- Auto-instruments HTTP calls, DB queries, external services, frameworks
- Reports to `newrelic.com` (US) or `eu.newrelic.com` (EU data center)

**Key agent config:**
```yaml
license_key: <NEW_RELIC_LICENSE_KEY>
app_name: checkout-service
distributed_tracing:
  enabled: true
application_logging:
  forwarding:
    enabled: true    # log-in-context
```

### Infrastructure Agent

Installed on host (Linux: `/etc/newrelic-infra/newrelic-infra.yml`, Windows service).

**Collects:** CPU, memory, disk, network, processes, running services.

**On-host integrations (OHI):** MySQL, PostgreSQL, Redis, Nginx, Apache, Kafka, and more. Each OHI adds metrics specific to the technology.

**Cloud integrations:** AWS CloudWatch metrics via polling or metric streams. Azure and GCP via API polling.

### OpenTelemetry Integration

New Relic is an OTLP-native endpoint. No proprietary agent required:

```
US endpoint: otlp.nr-data.net:4317 (gRPC) / :4318 (HTTP)
EU endpoint: otlp.eu01.nr-data.net:4317
```

Configure any OTel SDK exporter with `api-key` header set to New Relic license key. OTel data maps to New Relic data types: spans to `Span`, metrics to `Metric`, logs to `Log`.

Recommended for polyglot environments and vendor-neutral instrumentation strategies.

### Pixie (Kubernetes)

Deployed via Helm chart as a DaemonSet. Uses eBPF for zero-code instrumentation.

**Captures:** HTTP/gRPC traffic, DB queries, CPU profiles, memory flamegraphs.

**Data model:** Data stays in-cluster (edge storage) with a subset exported to NRDB. Requires Linux kernel 4.14+ and Kubernetes 1.16+.

---

## Data Model

New Relic organizes all telemetry into four core data types in NRDB:

| Type | Description | Example Sources |
|------|-------------|----------------|
| Events | Discrete timestamped records with attributes | `Transaction`, `PageView`, `InfrastructureEvent`, custom events |
| Metrics | Numeric measurements (gauge, count, summary, distribution) | Infrastructure agent, cloud integrations, Prometheus remote write |
| Logs | Structured/unstructured log lines with metadata | Log forwarder, APM log-in-context, Fluentd/Logstash plugins |
| Traces (Spans) | Distributed trace segments with parent/child relationships | APM agents, OTel SDK, Pixie |

### Key Event Types (NRQL FROM targets)

- `Transaction` -- APM web/non-web transactions
- `TransactionError` -- APM errors with stack traces
- `PageView`, `PageAction`, `BrowserInteraction` -- Browser RUM
- `SystemSample`, `NetworkSample`, `ProcessSample`, `StorageSample` -- Infrastructure
- `Log` -- Log management
- `Span` -- Distributed tracing
- `SyntheticCheck`, `SyntheticRequest` -- Synthetic monitoring
- `NrConsumption`, `NrMTDConsumption` -- Billing data
- `DatastoreSegment` -- Database call segments from APM

---

## Accounts & Organization

- **Hierarchy:** Organization > Accounts > Sub-accounts
- Data lives per account; cross-account queries possible via NerdGraph
- Account ID required in agent config (`account_id` / `NEW_RELIC_ACCOUNT_ID`)
- User management via SCIM provisioning or manual; SSO via SAML 2.0

---

## Dashboards

### Dashboard Builder

Built at **one.newrelic.com > Dashboards**. Each dashboard contains pages; each page contains widgets backed by NRQL queries.

**Features:** Multi-page layouts, template variables (dropdown filters), TV mode (auto-rotating for NOC), PDF export, shareable permalinks, view-only/edit permissions.

### Chart Types

**Time series:** Line, Area (stacked). **Snapshot:** Billboard (KPI with thresholds), Bullet. **Comparative:** Bar, Pie, Table. **Distribution:** Histogram, Heatmap. **Analytical:** Funnel, JSON. **Layout:** Markdown.

### Template Variables

```sql
-- Variable: appName (populated by NRQL)
SELECT uniques(appName) FROM Transaction SINCE 1 day ago

-- Widget query using variable
SELECT average(duration) FROM Transaction
WHERE appName IN ({{appName}}) TIMESERIES AUTO SINCE 1 hour ago
```

### NerdGraph API

New Relic's GraphQL API. Dashboards can be fully managed as code via `dashboardCreate`, `dashboardUpdate`, `dashboardExport` mutations. Terraform provider `newrelic_dashboard` supports GitOps workflows.

### Custom Visualizations (Nerdpack SDK)

Build custom React-based charts using the New Relic One SDK:
- Scaffold: `nr1 create --type visualization`
- Deploy: `nr1 publish`
- Use as "Custom Visualization" widget in dashboards

---

## Default Retention

| Data Type | Default Retention |
|-----------|------------------|
| Events (APM, Browser, Infra) | 8 days |
| Metrics | 13 months |
| Logs | 30 days |
| Distributed traces / Spans | 8 days |

Extended retention available at additional cost.
