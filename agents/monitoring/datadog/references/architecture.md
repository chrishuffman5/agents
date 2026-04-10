# Datadog Architecture Reference

> Agent internals, Kubernetes deployment, DogStatsD, API, integrations, autodiscovery, and tagging strategy.

---

## Datadog Agent

The Agent is the primary data collection component running as a process on hosts or as a DaemonSet in Kubernetes. It ships metrics, logs, traces, and process data to Datadog's SaaS backend.

### Agent Sub-Components

| Component | Purpose | Default Port |
|-----------|---------|-------------|
| Collector | System metrics (CPU, memory, disk, network) + integration checks on 15s interval | -- |
| DogStatsD | UDP/UDS server receiving custom metrics via StatsD protocol with Datadog extensions | 8125 |
| Trace Agent | APM traces from tracing libraries, applies sampling, forwards to backend | 8126 |
| Process Agent | Live process and container data for Live Processes and Container Maps | -- |
| Security Agent | Cloud Workload Security (CWS) via eBPF kernel-level event collection | -- |
| NPM Agent | Network flow data between services via eBPF | -- |

### Agent Configuration

Primary config: `/etc/datadog-agent/datadog.yaml`

```yaml
api_key: <DD_API_KEY>
site: datadoghq.com          # or datadoghq.eu, us3, us5, ap1
logs_enabled: true
apm_config:
  enabled: true
process_config:
  enabled: true
```

Integration configs live under `/etc/datadog-agent/conf.d/<integration>.d/conf.yaml`.

### Agent CLI

```bash
datadog-agent status          # full agent status with check results
datadog-agent check <name>    # run an integration check manually
datadog-agent flare           # collect diagnostics for support case
datadog-agent configcheck     # validate all configuration files
datadog-agent health          # quick liveness check
```

---

## Kubernetes Deployment

### Helm Chart (Recommended)

```bash
helm repo add datadog https://helm.datadoghq.com
helm install datadog-agent datadog/datadog \
  --set datadog.apiKey=<DD_API_KEY> \
  --set datadog.logs.enabled=true \
  --set datadog.apm.portEnabled=true \
  --set agents.image.tag=7
```

Deploys the Agent as a DaemonSet (one pod per node) and the Cluster Agent as a Deployment.

### Cluster Agent

The Cluster Agent is a companion Deployment (not DaemonSet) that reduces API server load by centralizing cluster-level metadata collection.

**Roles:**
- Kubernetes State Metrics (built-in or via kube-state-metrics)
- External Metrics Provider for HPA autoscaling on Datadog metrics
- Admission Controller for automatic library injection and UST tagging

### Datadog Operator

Alternative to Helm for declarative management. Uses `DatadogAgent` CRD. Better for GitOps workflows.

### Autodiscovery

Agent detects containers and applies integration configs based on pod annotations:

```yaml
annotations:
  ad.datadoghq.com/redis.check_names: '["redisdb"]'
  ad.datadoghq.com/redis.init_configs: '[{}]'
  ad.datadoghq.com/redis.instances: '[{"host":"%%host%%","port":"6379"}]'
```

Autodiscovery sources: pod annotations, ConfigMaps, Cluster Agent CRDs, file-based configs.

---

## DogStatsD

UDP/UDS server on port 8125 receiving custom metrics from application code.

### Metric Types

| Type | Syntax | Aggregation |
|------|--------|------------|
| Counter | `name:value\|c` | Summed per flush interval, reported as rate/s |
| Gauge | `name:value\|g` | Last value wins per flush interval |
| Histogram | `name:value\|h` | Per-agent avg, count, max, median, p95 |
| Distribution | `name:value\|d` | Global percentiles across all agents |
| Set | `name:value\|s` | Unique value count per flush interval |

### Client Library Example (Python)

```python
from datadog import initialize, statsd

initialize(statsd_host='localhost', statsd_port=8125)

statsd.increment('web.requests', tags=['env:prod', 'service:api'])
statsd.gauge('cache.size', 1200, tags=['env:prod'])
statsd.histogram('request.latency', 0.342, tags=['endpoint:/checkout'])
statsd.distribution('payment.amount', 49.99, tags=['currency:usd'])
```

**Counter vs Distribution:** Histograms aggregate per-Agent before shipping; distributions aggregate globally in the Datadog backend, enabling accurate cross-host percentiles. Distributions count as multiple custom metrics (one per configured percentile).

---

## Datadog API

All data can be sent directly via HTTPS REST API (useful for serverless, CI pipelines, agentless environments):

| Endpoint | Purpose |
|----------|---------|
| `POST /api/v2/series` | Submit metrics (v2, supports distributions) |
| `POST /v1/input/<DD_API_KEY>` | Logs intake |
| `POST /api/v1/events` | Events |
| `POST /v0.3/traces` | Traces (Agent local endpoint) |

Authentication: `DD-API-KEY` header for data submission. `DD-APPLICATION-KEY` header for management operations (create monitors, dashboards).

---

## Integrations

Datadog ships 600+ integrations as Agent checks or cloud-based crawlers.

### Cloud Integrations (API-Based, No Agent)

| Provider | Auth Method | Coverage |
|----------|------------|---------|
| AWS | IAM role assumption | EC2, RDS, ELB, Lambda, S3, SQS, CloudWatch |
| Azure | App Registration (Reader role) | VMs, AKS, SQL Database, App Service |
| GCP | Service Account (Monitoring Viewer) | GKE, Cloud SQL, Pub/Sub, Cloud Functions |

### Agent-Based Integrations

YAML configs under `/etc/datadog-agent/conf.d/`. Common integrations: PostgreSQL, MySQL, MongoDB, Redis, Elasticsearch, Kafka, NGINX, HAProxy, JMX-based Java applications.

---

## Tagging Strategy

### Unified Service Tagging (UST)

Three reserved tags that power cross-product correlation:

```bash
DD_ENV=production
DD_SERVICE=checkout-api
DD_VERSION=1.4.2
```

Apply via environment variables on containers. Without UST, service maps show unknown services, trace-to-log linking fails, and deployment tracking is blind.

### Tag Application Points

- Agent config level (global tags)
- Integration config level (per-check tags)
- Cloud provider tag sync (AWS resource tags synced to Datadog)
- APM library level (code-level tags)
- Container labels and annotations

### Cardinality Guidelines

- Use UST tags (`env`, `service`, `version`) everywhere
- Add infrastructure tags: `region`, `availability-zone`, `team`, `cost-center`
- Never use unbounded values as tags: user IDs, session IDs, request IDs, raw URLs
- Monitor cardinality via `Metrics > Summary` sorted by distinct tag combinations

---

## Product Surface

| Product | Purpose |
|---------|---------|
| Infrastructure Monitoring | Host/container metrics, host maps, live processes |
| APM & Distributed Tracing | End-to-end request tracing across services |
| Log Management | Centralized log collection, parsing, search |
| Synthetics | Proactive API and browser testing |
| Real User Monitoring (RUM) | Frontend performance and session replay |
| Security Monitoring | SIEM (Cloud SIEM), CWS, CSPM, ASM |
| Network Performance Monitoring | Service-to-service network flows via eBPF |
| Database Monitoring | Query-level metrics and explain plans |
| CI Visibility | Pipeline and test visibility |

---

## Key URLs

| Purpose | URL |
|---------|-----|
| US1 site | `app.datadoghq.com` |
| EU site | `app.datadoghq.eu` |
| US3 site | `us3.datadoghq.com` |
| US5 site | `us5.datadoghq.com` |
| Logs intake (US1) | `http-intake.logs.datadoghq.com` |
| API base URL (US1) | `api.datadoghq.com` |
