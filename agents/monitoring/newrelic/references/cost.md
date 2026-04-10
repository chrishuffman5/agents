# New Relic Cost Reference

> Consumption pricing, drop rules, ingest monitoring, user seat optimization, and cost estimation.

---

## Pricing Model

New Relic uses consumption-based pricing with two primary cost drivers:

| Driver | Description |
|--------|-------------|
| Data Ingest | Charged per GB ingested into NRDB (~$0.35/GB, varies by edition) |
| User Seats | Charged per user type per month |

### User Types

| Type | Capabilities | Approximate Cost |
|------|-------------|-----------------|
| Basic | Limited dashboard viewing, alert acknowledgment | Free |
| Core | Full platform access (read-only for some features), Logs, Explorer | ~$49/user/month |
| Full Platform | All features, alerting management, admin | ~$99-349/user/month |

### Editions

Free, Standard, Pro, Enterprise. Higher editions provide better ingest rates, security features, and support SLAs.

### Free Tier

100 GB ingest/month + 1 Full Platform user. Forever free. Covers small environments entirely.

---

## Monitoring Ingest

### Ingest Breakdown Query

```sql
SELECT sum(GigabytesIngested) AS 'GB'
FROM NrConsumption
WHERE productLine = 'DataPlatform'
FACET usageMetric
SINCE this month
```

### Month-to-Date Total

```sql
SELECT latest(GigabytesIngested) AS 'MTD GB'
FROM NrMTDConsumption
WHERE productLine = 'DataPlatform'
```

### Ingest by Account

```sql
SELECT sum(GigabytesIngested)
FROM NrConsumption
FACET consumingAccountId, usageMetric
SINCE 30 days ago
ORDER BY sum(GigabytesIngested) DESC
```

Navigate to: **one.newrelic.com > Administration > Data management > Data ingestion** for the built-in dashboard.

---

## Drop Rules

Drop rules discard data before it is written to NRDB, reducing ingest cost. Configured via NerdGraph or UI.

### Drop Entire Events

```graphql
mutation {
  nrqlDropRulesCreate(accountId: 1234567, rules: [{
    action: DROP_DATA,
    nrql: "SELECT * FROM Log WHERE service.name = 'debug-logger' AND level = 'DEBUG'",
    description: "Drop debug logs from debug-logger service"
  }]) {
    successes { id }
    failures { error { description } }
  }
}
```

### Drop Attributes Only

Keep event, remove sensitive or noisy fields:

```graphql
mutation {
  nrqlDropRulesCreate(accountId: 1234567, rules: [{
    action: DROP_ATTRIBUTES,
    nrql: "SELECT request.body, user.ssn FROM Transaction",
    description: "Remove PII from transaction events"
  }]) {
    successes { id }
  }
}
```

Drop rules are permanent and cannot recover already-dropped data.

---

## Ingest Optimization Strategies

**1. Sampling / tail-based sampling**
Configure APM agents to send only a percentage of traces. Use Infinite Tracing for head-based sampling with tail-based override for errors and slow traces.

**2. Log filtering at source**
Filter DEBUG/TRACE logs before forwarding. Use Fluentd/Fluent Bit `grep` filter or Vector transforms.

**3. Infrastructure agent tuning**
Increase `metrics_process_sample_rate` from default 20s to 60s for low-priority hosts. Disable unused on-host integrations.

**4. Metric cardinality management**
High-cardinality dimensions (`user_id`, `request_id`) on metrics explode ingest volume. Strip or hash before sending.

**5. Prometheus remote write filtering**
Use `write_relabel_configs` to drop unused metric series before forwarding.

**6. Data governance & ingest alerts**
Assign ingest budgets per team/account using sub-accounts. Alert when daily ingest crosses projected budget using `NrConsumption` queries.

---

## Cost Estimation Template

**Step 1 -- Measure current ingest:**
Run MTD ingest query; extrapolate to 30 days.

**Step 2 -- Calculate data cost:**
```
Monthly GB x $0.35/GB = data cost
```

**Step 3 -- Calculate user cost:**
```
Full Platform users x $349 + Core users x $49
```

**Step 4 -- Apply free tier:**
```
Max(0, Monthly GB - 100) x rate = billable data cost
```

**Example:**
- 500 GB/month ingest: (500 - 100) x $0.35 = **$140/month data**
- 3 Full Platform users (Pro): 3 x $349 = **$1,047/month users**
- Total estimated: **~$1,187/month** (before discounts)

---

## Cost Reduction Checklist

- Drop DEBUG/TRACE logs via NerdGraph drop rules
- Remove high-cardinality metric labels at source
- Reduce infrastructure sample rates on non-critical hosts
- Enable tail-based sampling for distributed traces
- Use Core users instead of Full Platform where admin access is not needed
- Review and delete unused synthetic monitors
- Set ingest budget alerts to catch unexpected spikes
- Use Data Plus add-on for extended retention without daily cost spikes
