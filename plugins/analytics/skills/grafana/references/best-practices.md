# Grafana Best Practices Reference

## Dashboard Design

### Layout and Organization

**Follow the Z-Pattern Layout:**
- Arrange panels following natural left-to-right, top-to-bottom reading patterns
- Place the most critical metrics (golden signals) in the top-left area
- Use consistent spacing: 20px margins between rows, 10px gaps between panels
- Z-pattern layouts reduce cognitive load by approximately 40% compared to random arrangements

**Use the RED Method for Service Dashboards:**
- Request rate and error rate on the left side of each row
- Latency/duration metrics on the right side
- One row per service, ordered to reflect the data flow through the system

**Dashboard Hierarchy:**
- Create a tiered structure: overview > service-level > component-level
- Use dashboard links and drilldown navigation to connect tiers
- Keep overview dashboards to 10-15 panels maximum
- Use Grafana 12 tabs to segment complex dashboards by context instead of creating multiple dashboards

**Audience-Specific Dashboards:**

| Audience | Content | Refresh Rate |
|---|---|---|
| Executive/management | High-level KPIs, SLOs, business metrics | 5m-15m |
| Operations | System health, alerts, resource utilization | 30s-1m |
| Engineering | Detailed service metrics, debugging views, traces | 30s-1m |
| Capacity planning | Trends, forecasts, utilization patterns | 5m-15m |

### Panel Design

**Single Purpose per Panel:**
- Each panel should answer one specific question
- Use descriptive panel titles that state what the panel shows (e.g., "HTTP Request Rate by Service" not "Requests")
- Add panel descriptions explaining the metric, thresholds, and expected ranges

**Choose Appropriate Visualization Types:**

| Data Type | Best Visualization | Avoid |
|---|---|---|
| Trends over time | Time series (line) | Pie chart, gauge |
| Current value / KPI | Stat panel (with sparkline) | Full time series chart |
| Value within known range | Gauge (CPU %, memory %, SLO %) | Table |
| Multi-dimensional comparison | Table (redesigned 12.x) | Multiple stat panels |
| Distribution patterns | Heatmap | Bar chart |
| Latency percentiles | Heatmap | Line chart (too many lines) |
| Geographic data | Geomap | Table with location columns |

### Variable Usage

- Use template variables for environment, region, service, and instance selection
- Limit the number of variables to 5-7 maximum to avoid cognitive overload
- Use ad hoc filters (GA in 12.2) for dynamic filtering without predefined variables
- Multi-property variables (12.4) allow mapping multiple identifiers to a single variable

**Variable best practices:**
- Set sensible defaults so dashboards load meaningful data immediately
- Use `$__interval` and `$__rate_interval` for automatic resolution adjustment
- Chain variables with dependent queries for cascading dropdowns
- Hide variables that are only used for internal calculations

### Conditional Rendering (12.0+)

- Hide panels that have no data to reduce visual noise
- Show/hide sections based on variable selections (e.g., show debug panels only when `$env = "dev"`)
- Use tabs to organize related but distinct views within a single dashboard

### Annotations and Context

- Add annotations for deployments, incidents, and configuration changes
- Link annotation events to external systems (CI/CD, incident management)
- Use consistent annotation colors across dashboards (e.g., green for deploy, red for incident)

---

## Data Source Optimization

### Query Performance

**Reduce Query Scope:**
- Use appropriate time ranges; avoid querying longer periods than necessary
- Set per-panel time range overrides when panels need shorter windows than the dashboard default
- Use `$__interval` and `$__rate_interval` for automatic resolution adjustment
- Limit label selectors to reduce the number of time series returned

**Optimize PromQL Queries:**

```promql
# BAD: Catch-all selector -- scans everything
{__name__=~".+"}

# GOOD: Specific metric with label filters
http_requests_total{service="api-gateway", environment="production"}

# BAD: irate() is noisy on dashboards
irate(http_requests_total[5m])

# GOOD: rate() is smoother and more stable
rate(http_requests_total[$__rate_interval])

# GOOD: Limit high-cardinality results
topk(10, sum by (service) (rate(http_requests_total[$__rate_interval])))
```

**Key PromQL guidelines:**
- Prefer `rate()` over `irate()` for dashboard panels (more stable)
- Use `$__rate_interval` instead of hardcoded intervals for correct resolution
- Use `topk()` or `bottomk()` to limit high-cardinality results
- Aggregate across unnecessary dimensions: `sum by (service)` not per-instance

**Optimize LogQL Queries (Loki):**

```logql
# BAD: Broad selector scans excessive data
{namespace="production"}

# GOOD: Specific labels before line filters
{namespace="production", app="api-gateway"} |= "error"

# GOOD: Use structured metadata for fine-grained filtering
{namespace="production", app="api-gateway"} | level="error" | json | status >= 500
```

- Always include at least one label filter before line filters
- Use structured metadata labels for fine-grained filtering
- Use log volume API for overview before drilling into specific logs

**Recording Rules:**
- Pre-compute expensive aggregations as recording rules in Prometheus/Mimir
- Dramatically reduces dashboard loading time for complex queries
- Name convention: `level:metric:operations` (e.g., `job:http_requests_total:rate5m`)
- Store results as new time series that visualize nearly instantly

### Connection Configuration

**Data Source Proxying:**
- Always use Grafana's server-side proxy (default) rather than direct browser connections
- Centralizes authentication; prevents credential exposure to clients

**Authentication:**
- Use service accounts with minimal required permissions
- Rotate credentials on a regular schedule
- Use secrets management (Grafana Cloud) or HashiCorp Vault integration for credential storage

**Timeouts and Limits:**
- Configure appropriate query timeouts per data source (default 30s)
- Set max data points per query to prevent excessive memory usage
- Configure concurrent query limits to prevent backend overload

### Caching

- Grafana does not cache data source responses by default (OSS)
- Enable query caching in Grafana Enterprise/Cloud for frequently accessed dashboards
- Use external caching (reverse proxy, data source-side caching) in OSS
- Configure cache TTLs based on data freshness requirements
- Prometheus-side: use `--query.lookback-delta` and recording rules to reduce repeated computation

---

## Alerting Rules

### Alert Rule Design

**Focus on Symptoms, Not Causes:**
- Alert on user-facing symptoms (error rates, latency, availability) rather than infrastructure causes (CPU usage)
- Use the SLO-based approach: alert when error budget is being consumed too rapidly
- Include runbook links in alert annotations for responder guidance

**Thresholds and Conditions:**
- Use `for` duration to avoid alerting on transient spikes (e.g., `for: 5m`)
- Set meaningful thresholds based on historical data and SLO targets
- Use percentage-based thresholds rather than absolute values when possible
- Configure No Data behavior explicitly: `Alerting`, `NoData`, `OK`, or `KeepLastState`
- Configure Error state behavior to avoid false `DatasourceError` alerts during transient failures

**Multi-Signal Alerting:**
- Combine metrics from multiple data sources using SQL Expressions
- Correlate metrics with log patterns for more context-aware alerts
- Use Metrics Drilldown with Alert Integration (12.2) to discover and convert queries to alerts

**Alert Rule Organization:**
- Group related alert rules into folders with meaningful names
- Use consistent labeling: `severity`, `team`, `service`, `environment`
- Keep evaluation groups focused: rules that should be evaluated together

### Notification Policies

**Tree Structure Design:**

```
Root Policy (default)
├── team=platform
│   ├── severity=critical → PagerDuty
│   └── severity=warning → Slack #platform-alerts
├── team=frontend
│   ├── severity=critical → PagerDuty
│   └── severity=warning → Slack #frontend-alerts
└── (default) → Email to on-call
```

- Start with a broad root default policy
- Create team-based routing as first-level child policies
- Add severity-specific or service-specific routing as deeper nested policies
- Use label matchers for routing: `team`, `severity`, `service`, `environment`

**Grouping:**
- Use `group_by` to combine related alert instances into single notifications
- Common grouping labels: `alertname`, `service`, `cluster`
- `group_wait` (30s default): Initial delay for batching multiple alerts
- `group_interval` (5m default): How often to send updates for a group
- `repeat_interval` (4h default): How often to re-send firing alerts

**Escalation:**
- Critical alerts → immediate channels (PagerDuty, OpsGenie)
- Warning alerts → team channels (Slack, Teams)
- Informational alerts → email or ticketing systems
- Test notification routing thoroughly before deploying

### Mute Timings and Silences

- **Mute timings**: Use for recurring quiet periods (nights, weekends, maintenance windows)
- **Silences**: Use for one-time suppression (planned deployments, known issues)
- **Important**: Mute timings are NOT inherited from parent policies; configure on each level that needs them
- Document the reason for every silence for audit purposes
- Set expiration times on silences to prevent indefinite suppression

---

## Provisioning as Code

### File-Based Provisioning

**Directory Structure:**
```
/etc/grafana/provisioning/
  datasources/
    datasource.yaml          # Prometheus, Loki, etc.
  dashboards/
    dashboard-provider.yaml  # Points to JSON dashboard files
  alerting/
    alert-rules.yaml         # Alert rule definitions
    contact-points.yaml      # Notification destinations
    notification-policies.yaml
    mute-timings.yaml
  plugins/
    plugin.yaml              # Plugin installation
```

**Best Practices:**
- Store all provisioning files in version control (Git)
- Use environment variable substitution (`$ENV_VAR`) for environment-specific values (URLs, credentials, thresholds)
- Separate configurations per environment (dev, staging, production)
- Use meaningful file names reflecting the resources they contain
- Test provisioning changes in a staging environment before production
- Mark provisioned resources as read-only to prevent UI drift

### Terraform Provider

**Resource Management:**
```hcl
resource "grafana_data_source" "prometheus" {
  type = "prometheus"
  name = "Prometheus"
  url  = var.prometheus_url

  json_data_encoded = jsonencode({
    httpMethod = "POST"
    timeInterval = "15s"
  })
}

resource "grafana_folder" "platform" {
  title = "Platform Team"
}

resource "grafana_dashboard" "service_overview" {
  config_json = file("dashboards/service-overview.json")
  folder      = grafana_folder.platform.id
}

resource "grafana_contact_point" "slack" {
  name = "Platform Slack"
  slack {
    url = var.slack_webhook_url
    channel = "#platform-alerts"
  }
}
```

**Best Practices:**
- Use `terraform plan` to preview changes before applying
- Store Terraform state in remote backends (S3, GCS, Terraform Cloud)
- Use modules for reusable Grafana resource patterns
- Import existing resources into Terraform state before managing them

### Kubernetes-Native Provisioning

**Grafana Operator:**
- Custom Resources: `GrafanaDashboard`, `GrafanaDataSource`, `GrafanaFolder`
- Reconciliation loop ensures desired state matches actual state
- GitOps-compatible with ArgoCD and Flux

**Crossplane Provider (Alpha):**
- Kubernetes manifests for all Grafana Terraform resources
- Not recommended for production (alpha stage)

### Git Sync (12.0+)

- Native GitHub integration for dashboard version control
- GitHub App authentication (12.4)
- PR-based review workflow for dashboard changes
- Audit trail via Git commit history
- Enables collaborative dashboard development with standard code review practices

### CI/CD Integration

- Validate dashboard JSON with `grafana-dashboard-linter` or custom schema validation
- Run `terraform plan` in CI for Grafana resource changes
- Use Grafana API for smoke testing dashboards after deployment
- Automate plugin updates through provisioning pipelines

---

## Plugin Management

### Selection and Evaluation

- Prefer official Grafana Labs plugins over community alternatives
- Check plugin signature status (signed vs unsigned) for security
- Review plugin update frequency and community activity
- Test plugins in non-production environments before deployment

### Installation and Updates

- Use provisioning for consistent plugin management across environments
- Pin plugin versions for reproducible deployments
- Update plugins during maintenance windows; test after updates
- Use Grafana Advisor (12.1 GA) for automated plugin health checks

### Security

- Only install signed plugins in production
- Configure `allow_loading_unsigned_plugins` only for development
- Review plugin permissions and data access requirements
- Monitor plugin resource usage for performance impact

### Custom Plugin Development

- Scaffolding: `npx @grafana/create-plugin@latest`
- Frontend: React + @grafana/ui component library
- Backend: Go (grafana-plugin-sdk-go) for data source proxying and alerting integration
- Submit to the Grafana plugin catalog for community distribution
