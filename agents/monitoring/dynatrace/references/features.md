# Dynatrace Features Reference

> Full-stack monitoring, distributed tracing, log analytics, Application Security, alerting, and Workflows.

---

## Full-Stack Monitoring

### Infrastructure

| Layer | What Dynatrace Monitors |
|-------|------------------------|
| Infrastructure | Host CPU, memory, disk I/O, network. Physical, VM, container. |
| Cloud | AWS, Azure, GCP native API integration. Cloud service metrics. |
| Kubernetes | Cluster, node, namespace, workload, pod, container metrics. Auto K8s topology. |
| Services | Response time, error rate, throughput per service. Automatic detection. |
| Databases | Query performance, connection pools, slow queries. Per-statement visibility. |
| User Experience | RUM: page load, user actions, Core Web Vitals, crash reporting. |
| Synthetic | Browser and API monitors from global locations. |

### Cloud Integrations

AWS, Azure, and GCP API-based integrations via ActiveGate. Pull cloud service metrics (RDS, Lambda, Azure SQL, GKE) without agents on the cloud resources themselves.

### Kubernetes Monitoring

Deploy OneAgent via DynaKube Operator as DaemonSet. Automatic topology for cluster, nodes, namespaces, workloads, pods, and containers. Correlates pod metrics with service-level traces.

---

## Distributed Tracing (PurePath)

PurePath captures every transaction end-to-end with code-level detail:
- Every method contributing to latency above configurable threshold
- SQL query text, parameters, row counts
- External HTTP calls with full URL and response codes
- Exception stack traces at point of occurrence

No sampling by default. Overhead < 2% CPU.

OpenTelemetry: Dynatrace ingests OTLP traces, metrics, and logs. OneAgent enriches OTel spans with Dynatrace context.

---

## Log Analytics

Dynatrace log monitoring via Grail:
- OneAgent ships logs automatically from detected log files
- Ingestion via Fluent Bit, Logstash, or direct API
- Logs correlated to services, hosts, and traces automatically
- DQL for log analysis: parse, filter, aggregate
- Log metrics: extract numeric fields from log lines as metrics

### Log Content Rules

Configure which log files to ingest and filter noisy lines before ingestion. Critical for cost control since Grail billing is per GB.

---

## Application Security

Uses OneAgent instrumentation (no separate agent):
- **Runtime vulnerability detection (RASP):** Identifies vulnerable libraries in running code
- **Attack detection:** SSRF, SQL injection, command injection, JNDI injection
- **Exploitability scoring:** Uses Smartscape context (internet-exposed vs internal)
- Integrates with DevSecOps workflows for remediation tracking

---

## Business Analytics

- Business events: instrument custom KPIs (orders, checkouts, conversions)
- Funnel analysis, conversion rates, session replay
- Davis AI correlates business metric anomalies with infrastructure problems

---

## Alerting

### Davis AI Problem Detection

Automatic anomaly detection using learned baselines. Davis monitors:
- Response time deviation from baseline
- Error rate spikes
- Throughput drops
- Infrastructure resource saturation
- Availability failures

When detected, Davis:
1. Opens a **Problem** (may group dozens of related alerts)
2. Determines root cause via Smartscape topology
3. Suppresses downstream symptoms
4. Continuously updates with new evidence
5. Auto-closes when metrics return to baseline

### Alerting Profiles

Filter which Problems trigger notifications:
- By severity (Availability, Error, Slowdown, Resource, Custom)
- By entity type (service, host, application)
- By tag (e.g., `env:production`)
- By management zone
- Delay notification (persist > 5 minutes before alerting)

### Metric Events (Threshold-Based)

Custom threshold alerting for cases where Davis anomaly detection is insufficient:
- **Static threshold:** Alert when metric > X for Y minutes
- **Relative threshold:** Alert when metric deviates > N% from sliding average
- **Scope:** Narrow to entity, tag, or management zone

Metric events create Problems visible in the Davis problem stream.

### Custom Events API

Inject external events:
```
POST /api/v2/events/ingest
```

Event types: `AVAILABILITY_EVENT`, `CUSTOM_INFO`, `CUSTOM_ANNOTATION`, `CUSTOM_CONFIGURATION`, `CUSTOM_DEPLOYMENT`. Deployment events used for change correlation with Davis.

### Notification Targets

| Target | Method |
|--------|--------|
| PagerDuty | Native integration (trigger/resolve) |
| Slack | Webhook or native app |
| Microsoft Teams | Webhook connector |
| Email | Built-in SMTP |
| OpsGenie | Native integration |
| Generic webhook | Configurable JSON template |

### Workflows (Alerting Automation)

Event-driven automation:
- **Triggers:** Davis problem opened, metric threshold crossed, scheduled cron
- **Actions:** HTTP request, Slack message, Jira issue, email, run DQL, run JavaScript
- **Conditions and loops** within workflow
- **Conditional routing:** Page PagerDuty only for P1 on production services

Workflows replace legacy notification integrations with programmable automation.
