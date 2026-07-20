# Datadog Cost Reference

> Pricing model, custom metric cardinality, log cost optimization, APM sampling, estimated usage metrics, and common cost traps.

---

## Pricing Model

Datadog uses per-unit pricing. Main billing dimensions:

| Product | Billing Unit |
|---------|-------------|
| Infrastructure (Pro/Enterprise) | Per host per month (any host reporting for 1+ hr) |
| APM | Per APM host per month |
| Log Management | Per GB indexed per month (varies by retention tier) |
| Custom Metrics | Per custom metric (above free tier allowance) |
| Log Archives Rehydration | Per GB rehydrated |
| Synthetics | Per test run (API) or per session (Browser) |
| RUM | Per session per month |
| Continuous Profiler | Per profiled host per month |
| Database Monitoring | Per monitored database host per month |
| Security (CWS/CSPM) | Per host per month |
| NPM | Per host per month |

**Free metric allowance:** Each Infrastructure host includes 100 custom metrics; each APM host includes 150 custom metrics. Overage is billed per metric.

---

## Custom Metric Cardinality

Custom metrics are counted by unique (metric_name + tag combination). High-cardinality tags multiply metric count dramatically.

**Cardinality explosion example:**
```
Metric: api.request.count
Tags: env (3) x service (20) x status_code (5) = 300 time series
Adding user_id (100,000 users) = 300,000,000 time series
```

**Best practices:**
- Never tag with unbounded values: user IDs, session IDs, request IDs, raw URLs
- Use distributions for latency (fewer time series than histogram per percentile)
- Audit with `Metrics > Summary`; filter by `is:custom`; sort by distinct tag combinations
- Use **Metric Volumes** report (`Plan & Usage > Metrics`) to identify top contributors

### Metrics without Limits (MwL)

Configure which tag combinations to index without dropping raw data. Reduces custom metric count while preserving raw data in archives for future re-aggregation. Enable per metric in `Metrics > Summary`.

---

## Log Cost Optimization

Logs are typically the most variable cost. Strategies ordered by impact:

**1. Exclusion filters (highest impact)**
Drop noisy logs before indexing. Target: access logs, health-check pings, DEBUG logs.

**2. Tiered indexes**
Create multiple indexes with different retention:
- 3-day index for INFO (filter: `status:info`)
- 15-day index for ERROR/WARN (filter: `status:(error OR warn)`)

**3. Log-based metrics**
Extract counts/measures from high-volume logs without indexing every event. One log-based metric is far cheaper than millions of indexed log lines.

**4. Archives**
Ship everything to S3/GCS/Azure Blob (cheap storage). Rehydrate only when needed for investigation.

**5. Sampling in exclusion filters**
Keep a representative 5-10% sample rather than dropping all. Useful for access logs where pattern visibility matters.

### Log Volume Monitoring

Enable estimated usage metrics to track ingestion before the bill:
- `datadog.estimated_usage.logs.ingested_bytes` -- Bytes ingested per hour
- `datadog.estimated_usage.logs.indexed_events` -- Indexed event count per hour

Build dashboards with `sum by {service}` breakdowns to attribute log volume to teams.

---

## APM Trace Sampling

### Ingestion Controls

- `DD_TRACE_SAMPLE_RATE=0.1` -- 10% library-level sampling (reduces data sent to Agent)
- **Ingestion Rules** (Agent-side) -- Per-service sampling rates in Datadog UI
- **Retention Filters** -- Control which ingested spans are indexed for 15-day search

**Tracing Without Limits:** Adaptive sampling ensures 100% of traces with errors, rare operations, and long-running spans are always kept regardless of configured rate.

### APM Cost Math

APM is billed per APM host. Reducing trace volume does not directly reduce host count, but reducing indexed spans reduces retention costs.

---

## Infrastructure Host Count

- Hosts reporting for any part of the month count as billable
- Ephemeral hosts (CI runners, spot instances) spike host count
- Use `datadog.estimated_usage.infra.hosts` for forecasting dashboards
- Consider agent-less monitoring (cloud integrations only) for short-lived workloads

---

## Estimated Usage Metrics

| Metric | Description |
|--------|-------------|
| `datadog.estimated_usage.infra.hosts` | Current reporting host count |
| `datadog.estimated_usage.apm.hosts` | Current APM host count |
| `datadog.estimated_usage.logs.ingested_bytes` | Log bytes ingested per hour |
| `datadog.estimated_usage.logs.indexed_events` | Indexed log event count per hour |
| `datadog.estimated_usage.custom_metrics` | Current custom metric count |
| `datadog.estimated_usage.synthetics.api_tests_ran` | Synthetics API test run count |

Build a **Cost Dashboard** using these metrics with `sum by {service}` or `sum by {env}` breakdowns to attribute spend to teams.

---

## Common Cost Surprises

**1. Container host counting**
Each Kubernetes node is a host. Products stack: Infra + APM + NPM + CWS per node multiplies fast.

**2. Lambda APM billing**
Lambda functions billed per invocation. 150 invocations = 1 APM host-equivalent. High-invocation functions cost more than EC2 hosts.

**3. Custom metric explosion from containers**
Container tags (pod name, container ID) create unique time series per container restart.

**4. Log rehydration**
Rehydrating archives billed per GB. Unplanned incident rehydration generates unexpected charges.

**5. Synthetics at high frequency**
Browser test every 1 minute from 5 locations = 7,200 sessions/day = 216,000 sessions/month.

**6. RUM session counting**
Single-page app session replays counted per browser session. High-traffic apps accumulate quickly.

**7. Uncommitted metrics from bugs**
DogStatsD metrics emitted by runaway code can spike custom metric counts until deployment rollback.

---

## Cost Governance Practices

- **Usage Attribution** -- Tag costs by `team`, `service`, `env` for chargeback
- **Usage Summary alerts** -- Notify when usage exceeds threshold %
- **Metrics without Limits** -- Reduce indexed tag combinations without losing raw data
- **Plan & Usage dashboard** -- Review monthly at `Organization Settings > Plan & Usage`
- **Committed Use contracts** -- Predictable workloads get lower per-unit rates; use on-demand for burst only
