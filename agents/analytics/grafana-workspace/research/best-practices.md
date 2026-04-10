# Grafana Best Practices

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
- Create a tiered dashboard structure: overview > service-level > component-level
- Use dashboard links and drilldown navigation to connect tiers
- Keep overview dashboards to 10-15 panels maximum
- Use Grafana 12 tabs to segment complex dashboards by context instead of creating multiple dashboards

**Audience-Specific Dashboards:**
- Executive/management: high-level KPIs, SLOs, business metrics
- Operations: system health, alerts, resource utilization
- Engineering: detailed service metrics, debugging views, traces
- Tailor complexity and refresh rates to the audience

### Panel Design

**Single Purpose per Panel:**
- Each panel should answer one specific question
- Use descriptive panel titles that state what the panel shows
- Add panel descriptions explaining the metric, thresholds, and expected ranges

**Choose Appropriate Visualization Types:**
- Time series: trends over time, rate changes
- Stat panels: current values, key indicators
- Gauges: values within a known range (CPU %, memory %, SLO compliance)
- Tables: multi-dimensional data comparison
- Heatmaps: distribution patterns, latency percentiles
- Use Grafana 12 suggested visualizations for data-source-aware recommendations

**Variable Usage:**
- Use template variables for environment, region, service, and instance selection
- Limit the number of variables to avoid cognitive overload (5-7 maximum)
- Use ad hoc filters (GA in 12.2) for dynamic filtering without predefined variables
- Multi-property variables (12.4) allow mapping multiple identifiers to a single variable

**Conditional Rendering (Grafana 12):**
- Hide panels that have no data to reduce visual noise
- Show/hide sections based on variable selections
- Use tabs to organize related but distinct views within a single dashboard

### Annotations and Context

- Add annotations for deployments, incidents, and configuration changes
- Link annotation events to external systems (CI/CD, incident management)
- Use consistent annotation colors across dashboards

---

## Data Source Optimization

### Query Performance

**Reduce Query Scope:**
- Use appropriate time ranges; avoid querying longer periods than necessary
- Set per-panel time range overrides when panels need shorter windows than the dashboard default
- Use `$__interval` and `$__rate_interval` variables for automatic resolution adjustment
- Limit label selectors to reduce the number of time series returned

**Optimize PromQL Queries:**
- Avoid `{__name__=~".+"}` or other catch-all selectors
- Use recording rules for expensive or frequently used queries
- Prefer `rate()` over `irate()` for dashboard panels (more stable)
- Use `topk()` or `bottomk()` to limit high-cardinality results

**Optimize LogQL Queries (Loki):**
- Always include at least one label filter before line filters
- Use structured metadata labels for fine-grained filtering
- Avoid broad log stream selectors that scan excessive data
- Use log volume API for overview before drilling into specific logs

**Recording Rules:**
- Pre-compute expensive aggregations as recording rules in Prometheus/Mimir
- Dramatically reduces dashboard loading time for complex queries
- Store results in new time series that visualize nearly instantly
- Name recording rules following the convention: `level:metric:operations`

### Connection Configuration

**Data Source Proxying:**
- Always use Grafana's server-side proxy (default) rather than direct browser connections
- Centralizes authentication and prevents credential exposure to clients

**Authentication:**
- Use service accounts with minimal required permissions
- Rotate credentials on a regular schedule
- Use secrets management (Grafana Cloud) or HashiCorp Vault integration for credential storage

**Timeouts and Limits:**
- Configure appropriate query timeouts per data source (default 30s)
- Set max data points per query to prevent excessive memory usage
- Configure concurrent query limits to prevent backend overload

### Caching

- Grafana does not cache data source responses by default
- Enable query caching in Grafana Enterprise/Cloud for frequently accessed dashboards
- Use external caching (reverse proxy, data source-side caching) in OSS
- Configure cache TTLs based on data freshness requirements
- Prometheus: use `--query.lookback-delta` and recording rules to reduce repeated computation

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
- Configure No Data behavior explicitly (Alerting, NoData, OK, or KeepLastState)
- Configure Error state behavior to avoid false DatasourceError alerts

**Multi-Signal Alerting:**
- Combine metrics from multiple data sources using SQL Expressions
- Correlate metrics with log patterns for more context-aware alerts
- Use Metrics Drilldown with Alert Integration (12.2) to discover and convert queries to alerts

**Alert Rule Organization:**
- Group related alert rules into folders with meaningful names
- Use consistent labeling: severity, team, service, environment
- Keep evaluation groups focused: rules that should be evaluated together

### Notification Policies

**Tree Structure Design:**
- Start with a broad root default policy
- Create team-based routing as first-level child policies
- Add service-specific or severity-specific routing as deeper nested policies
- Use label matchers for routing: `team`, `severity`, `service`, `environment`

**Grouping:**
- Use `group_by` to combine related alert instances into single notifications
- Common grouping labels: `alertname`, `service`, `cluster`
- Configure `group_wait` (initial delay for grouping), `group_interval` (batch frequency), and `repeat_interval` (re-notification frequency)

**Escalation:**
- Route critical alerts to immediate channels (PagerDuty, OpsGenie)
- Route warning alerts to team channels (Slack, Teams)
- Route informational alerts to email or ticketing systems
- Test notification routing thoroughly before deploying

### Mute Timings and Silences

- **Mute timings**: Use for recurring quiet periods (nights, weekends, maintenance windows)
- **Silences**: Use for one-time suppression (planned deployments, known issues)
- Mute timings are not inherited from parent policies; configure on each level
- Document the reason for every silence for audit purposes

---

## Provisioning as Code

### File-Based Provisioning

**Directory Structure:**
```
/etc/grafana/provisioning/
  datasources/
    datasource.yaml
  dashboards/
    dashboard-provider.yaml
  alerting/
    alert-rules.yaml
    contact-points.yaml
    notification-policies.yaml
    mute-timings.yaml
  plugins/
    plugin.yaml
```

**Best Practices:**
- Store all provisioning files in version control (Git)
- Use environment variable substitution (`$ENV_VAR`) for environment-specific values
- Separate configurations per environment (dev, staging, production)
- Use meaningful file names reflecting the resources they contain
- Test provisioning changes in a staging environment before production

### Terraform Provider

**Resource Management:**
- Manage dashboards, data sources, folders, alert rules, notification policies, contact points, and organizations
- Use `terraform plan` to preview changes before applying
- Store Terraform state in remote backends (S3, GCS, Terraform Cloud)
- Use modules for reusable Grafana resource patterns

**Dashboard Management:**
```hcl
resource "grafana_dashboard" "example" {
  config_json = file("dashboards/example.json")
  folder      = grafana_folder.team.id
}
```

### Kubernetes-Native Provisioning

**Grafana Operator:**
- Manages Grafana instances via Kubernetes Custom Resources
- Automatically syncs CRs with Grafana resources
- Supports GrafanaDashboard, GrafanaDataSource, GrafanaFolder CRDs
- Reconciliation loop ensures desired state matches actual state

**Crossplane Provider (Alpha):**
- Kubernetes manifests for all Grafana Terraform resources
- GitOps-compatible with ArgoCD and Flux pipelines
- Still in alpha; not recommended for production

### Git Sync (Grafana 12)

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

- Prefer official Grafana Labs plugins over community alternatives when available
- Check plugin signature status (signed vs. unsigned) for security
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

- Use the Plugin Tools CLI (`npx @grafana/create-plugin@latest`) for scaffolding
- Follow Grafana plugin SDK conventions for frontend (React + @grafana/ui) and backend (Go)
- Implement proper error handling and logging
- Submit to the Grafana plugin catalog for community distribution
