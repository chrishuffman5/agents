# Grafana Architecture Reference

## Dashboard Internals

Dashboards are the primary organizational unit in Grafana. Each dashboard is a JSON-based collection of panels arranged in rows, with support for variables, annotations, and drilldown navigation.

### JSON Model

Dashboard definitions are portable JSON documents that can be:
- Version-controlled in Git (via Git Sync, Terraform, or file-based provisioning)
- Exported/imported between Grafana instances
- Programmatically generated via REST API or Terraform
- Diffed and reviewed like any source code artifact

### Dashboard Structure

```
Dashboard
├── Settings (title, description, tags, time range, refresh interval)
├── Variables (template variables, ad hoc filters)
├── Annotations (event markers from data sources or manual)
├── Tabs (12.0+, segment content by context)
├── Rows (collapsible groupings)
│   ├── Panel 1 (query + visualization + transformations)
│   ├── Panel 2
│   └── ...
├── Links (navigation to other dashboards or URLs)
└── Permissions (folder-level or dashboard-level access control)
```

### Time Range Controls

- **Global time range**: Applies to all panels by default; controlled via the time picker
- **Per-panel overrides**: Individual panels can override the global time range for different perspectives
- **Auto-refresh**: Configurable intervals (5s, 10s, 30s, 1m, 5m, 15m, 30m, 1h); applies to all panels
- **Relative time**: `now-5m`, `now-1h`, `now-24h`, `now-7d` -- always resolves relative to current time

### Variables (Template Variables)

Variables enable dynamic, reusable dashboards:

| Variable Type | Description | Example |
|---|---|---|
| **Query** | Populated from a data source query | `label_values(up, instance)` |
| **Custom** | Static comma-separated values | `dev,staging,prod` |
| **Text box** | Free-text input | User-typed filter values |
| **Constant** | Fixed value, hidden from user | API endpoint, schema name |
| **Data source** | Selects between configured data sources | Switch between prod/staging Prometheus |
| **Interval** | Auto-resolution intervals | `$__interval`, `$__rate_interval` |
| **Ad hoc filters** (GA 12.2) | Dynamic key-value filtering on the fly | User adds arbitrary label filters |
| **Multi-property** (12.4) | Map multiple identifiers to a single variable | One variable controlling multiple labels |

**Built-in variables:**
- `$__interval` -- Auto-calculated step interval based on time range and panel width
- `$__rate_interval` -- Recommended for `rate()` and `increase()` functions (accounts for scrape interval)
- `$__from` / `$__to` -- Start/end of the current time range (epoch milliseconds)
- `$__timeFilter(column)` -- SQL-compatible time range filter

### Conditional Rendering (12.0+)

- Show or hide panels and rows based on variable selections or data conditions
- Reduces visual noise by hiding panels without relevant data
- Combined with tabs, allows building context-aware dashboards that adapt to user roles

### Auto Grid Layout (12.4+)

Flexible panel arrangement with automatic sizing, replacing manual row/column configuration for responsive layouts.

### Git Sync (12.0+, Public Preview)

- Native GitHub integration for dashboard version control
- GitHub App authentication (12.4)
- PR-based review workflow for dashboard changes
- Audit trail via Git commit history
- Enables collaborative dashboard development with standard code review practices

---

## Data Source Architecture

Data sources are plugins that translate Grafana queries into backend-specific query languages.

### Query Lifecycle

1. User configures a panel with one or more queries
2. Panel sends query to the Grafana server via API (`/api/ds/query`)
3. Grafana server routes query to the appropriate data source plugin
4. Plugin translates the query into the backend-specific language (PromQL, LogQL, SQL, etc.)
5. Plugin sends the query to the backend and receives results
6. Results are returned to the panel in Grafana's internal data frame format
7. Panel applies transformations, thresholds, and overrides
8. Visualization renders the final result

### Server-Side Proxy

All data source queries route through the Grafana server:
- Prevents direct browser-to-database connections
- Centralizes authentication and credential management
- Enables data source-level access control (Enterprise/Cloud)
- Query parameters and credentials never exposed to the browser

### Mixed Data Source Mode

Combine queries from multiple data sources in a single panel:
- Each query targets a different data source
- Results are merged in the panel using transformations
- SQL Expressions (12.0+) can join cross-source data using SQL syntax

### SQL Expressions (12.0+)

Join and combine data from any data source using SQL syntax:
- Removes limitations on cross-data-source data manipulation
- Enables complex data transformations without backend changes
- AI-powered SQL generation (12.2, preview) creates queries from natural language

### Connection Configuration

- **Authentication**: Service accounts, API keys, OAuth tokens, basic auth, TLS certificates
- **Proxy**: Forward proxy support for data sources behind corporate proxies
- **Timeouts**: Configurable per data source (default 30s)
- **Max data points**: Limit per query to prevent excessive memory usage
- **Concurrent queries**: Configurable limits to prevent backend overload

---

## Panel and Visualization Types

### Core Visualizations

| Category | Types |
|---|---|
| **Time-based** | Time series (line, bar, points), State timeline, Status history |
| **Single value** | Stat (with sparkline), Gauge (arc, circular -- revamped 12.4) |
| **Categorical** | Bar chart, Pie chart, Histogram |
| **Tabular** | Table (rebuilt 12.x, 97.8% faster CPU), Logs |
| **Spatial** | Geomap (significantly faster in 12.x), Node graph |
| **Analytical** | Heatmap, Flame graph, Traces, Canvas (freeform) |
| **Informational** | Alert list, Dashboard list, News, Text |

### Transformations Pipeline

Transformations process query results before visualization:
- Filter by name, value, or regex
- Join/merge multiple queries
- Aggregate, group by, or calculate new fields
- Rename fields or convert types
- Regression analysis (12.1): predict future values or estimate missing data points
- Sort, limit, or organize results

### Panel Features

- **Query Inspector**: Debug query performance, view raw request/response, check data frame structure, timing
- **Thresholds**: Color-coded boundaries for status indication (green/yellow/red)
- **Value mappings**: Map specific values to display text or colors
- **Field overrides**: Per-field styling (color, unit, decimals, display name)
- **Visualization actions** (12.1): Custom actions with user-defined variables, triggered from panel interactions

---

## Alerting Engine Architecture

### Components

```
Alert Rules
  │
  ▼
Evaluation Engine (periodic execution)
  │
  ├── Grafana-managed rules (evaluated by Grafana)
  └── Data source-managed rules (evaluated by Prometheus/Mimir/Loki ruler)
  │
  ▼
Alert State (Normal, Pending, Firing, Inactive, NoData, Error)
  │
  ▼
Notification Policies (tree-structured routing)
  │
  ├── Label matching (severity, team, service, env)
  ├── Grouping (group_by, group_wait, group_interval)
  └── Repeat interval
  │
  ▼
Contact Points (Slack, PagerDuty, email, webhook, etc.)
  │
  ▼
Silences / Mute Timings (suppression)
```

### Alert Rule Types

| Type | Evaluated By | Use Case |
|---|---|---|
| **Grafana-managed** | Grafana alerting engine | Any data source; centralized evaluation |
| **Data source-managed** | Prometheus, Mimir, or Loki ruler | Offload evaluation to the data source |
| **Recording rules** | Prometheus/Mimir | Pre-compute expensive queries; results stored as new time series |

### Evaluation

- Each rule evaluates on a configurable schedule (evaluation interval)
- A rule can produce multiple alert instances (one per unique label set / time series)
- `for` duration: alert must be firing for this duration before transitioning to `Firing` state (avoids transient spikes)
- Configurable evaluation timeout (default 30s) and max attempts (default 3)
- **No Data handling**: `Alerting`, `NoData`, `OK`, or `KeepLastState`
- **Error handling**: `Alerting`, `Error`, `OK`, or `KeepLastState`

### Notification Policies

Tree-structured routing rules:
- **Root policy**: Default catch-all; cannot be deleted
- **Child policies**: Nested under root; first label match wins (top-down)
- **Label matchers**: Route alerts based on labels (e.g., `team=platform`, `severity=critical`)
- **Grouping**: `group_by` labels combine related alert instances into single notifications
- **Timing controls**:
  - `group_wait`: Initial delay to batch multiple alerts (default 30s)
  - `group_interval`: How often to send updates for a group (default 5m)
  - `repeat_interval`: How often to re-send firing alerts (default 4h)

### Contact Points

Each contact point can have multiple integrations:
- Email, Slack, PagerDuty, OpsGenie, Microsoft Teams
- Webhooks, Telegram, Discord, Google Chat, LINE, Threema
- Custom notification templates using Go templates

### Silences and Mute Timings

- **Silences**: One-time suppression matching specific label sets (e.g., during a maintenance window)
- **Mute timings**: Recurring suppression schedules (e.g., nights, weekends)
- **Important**: Mute timings are NOT inherited from parent notification policies; configure on each policy level

---

## Provisioning Architecture

### File-Based Provisioning

YAML configuration files placed in provisioning directories:

```
<WORKING_DIR>/conf/provisioning/    # default (binary install)
/etc/grafana/provisioning/           # package install (deb/rpm)
```

**Subdirectories:**
- `datasources/` -- Data source connection parameters, auth, defaults
- `dashboards/` -- Dashboard JSON models loaded from file system or external sources
- `alerting/` -- Alert rules, notification policies, contact points, mute timings
- `plugins/` -- Plugin installation and configuration

**Features:**
- Environment variable substitution: `$ENV_VAR` or `${ENV_VAR}`
- Automatic reload on file changes (configurable interval)
- Provisioned resources can be marked read-only (prevents UI modification)

### Terraform Provider

```hcl
resource "grafana_dashboard" "example" {
  config_json = file("dashboards/example.json")
  folder      = grafana_folder.team.id
}

resource "grafana_data_source" "prometheus" {
  type = "prometheus"
  name = "Prometheus"
  url  = "http://prometheus:9090"
}

resource "grafana_notification_policy" "default" {
  contact_point = grafana_contact_point.slack.name
  group_by      = ["alertname", "service"]
  # child policies...
}
```

Manages dashboards, data sources, folders, alert rules, notification policies, contact points, organizations, and more.

### Kubernetes Operator

Custom Resources for managing Grafana instances and resources:
- `GrafanaDashboard`, `GrafanaDataSource`, `GrafanaFolder` CRDs
- Reconciliation loop ensures desired state matches actual state
- Supports GrafanaOrg, GrafanaAlertRuleGroup, etc.

### REST API

Full programmatic management of all Grafana resources:
- Service accounts with fine-grained RBAC for automation
- Dashboard CRUD: `GET/POST/PUT/DELETE /api/dashboards/db`
- Data source management: `GET/POST/PUT/DELETE /api/datasources`
- Alerting: `GET/POST/PUT/DELETE /api/v1/provisioning/alert-rules`

---

## Plugin System

### Plugin Types

1. **Data source plugins**: Connect to external data backends; translate queries; return data in Grafana's internal format
2. **Panel plugins**: Custom visualization types beyond built-in options
3. **App plugins**: Bundled experiences combining custom pages, panels, and data sources

### Plugin Management

- **Plugin catalog**: 200+ community and official plugins
- **CLI installation**: `grafana-cli plugins install <plugin-id>`
- **Provisioning**: Via YAML configuration files
- **Signed verification**: Plugins are signed for security; unsigned plugins blocked by default
- **Grafana Advisor** (12.1 GA): Automated detection of plugin, data source, and SSO configuration issues

### Plugin Development

- **Backend plugins**: Go (grafana-plugin-sdk-go) -- data source proxying, alerting integration
- **Frontend plugins**: React + @grafana/data + @grafana/ui
- **Scaffolding**: `npx @grafana/create-plugin@latest`

---

## Deployment Tiers

### Grafana OSS (Community Edition)

- Free, open-source (AGPL v3)
- Full dashboard, visualization, and core alerting
- Community plugins; file-based provisioning and REST API
- Self-managed: installation, upgrades, scaling, backups, HA
- **Not included**: Enterprise data sources, SAML, SCIM, query caching, reporting, audit logging, fine-grained data source permissions

### Grafana Enterprise

Adds over OSS:
- Enterprise data source plugins (Splunk, Oracle, ServiceNow, SAP HANA, Snowflake, Databricks, MongoDB)
- SAML/LDAP enhanced authentication, Team Sync, SCIM (GA 12.4)
- Data source permissions and fine-grained RBAC
- Query caching for improved performance
- Reporting: scheduled PDF/CSV delivery
- Audit logging for compliance
- White labeling and custom branding
- Vault integration for secrets management
- Enterprise support SLAs

### Grafana Cloud

Fully managed SaaS by Grafana Labs:
- Includes full LGTM stack: Grafana + Mimir + Loki + Tempo
- 99.5% uptime SLA; automatic upgrades and security patches
- Scales to 1B+ active metric series
- Retention: 13-month metrics, 30-day logs/traces (expandable)
- **Cloud-exclusive**: Adaptive Metrics, Asserts, Synthetic Monitoring, Frontend Observability, k6 Cloud, Incident/On-call (IRM), Secrets management

---

## LGTM Stack Architecture

### Loki (Logs)

- Horizontally scalable, multi-tenant log aggregation
- LogQL query language (similar to PromQL)
- Label-based indexing (does not index log content by default) for cost efficiency
- Integrates with Grafana Logs Drilldown for code-free exploration
- Derived fields enable pivoting from log lines to traces in Tempo

### Tempo (Traces)

- Distributed tracing backend with cost-effective object storage
- TraceQL query language with streaming support (partial results)
- Trace-to-logs linking via `tracesToLogsV2` with Loki
- Trace-to-metrics linking via `tracesToMetrics` with Mimir
- Service graph generation for topology visualization
- Grafana Traces Drilldown (GA 12.0) for deep-dive analysis

### Mimir (Metrics)

- Long-term, horizontally scalable metrics storage
- Drop-in Prometheus replacement with full PromQL compatibility
- Multi-tenant architecture with per-tenant limits
- Native Prometheus alerting and recording rules via built-in ruler
- 13-month retention in Grafana Cloud
- Supports push (Alloy/OTLP) and pull (remote_write) ingestion

### Grafana Alloy (Telemetry Collector)

- Replaces Grafana Agent as the recommended collector
- OpenTelemetry-compatible pipeline for metrics, logs, and traces
- Declarative configuration with component-based architecture
- Supports Prometheus scraping, OTLP ingestion, and various receivers

### Cross-Signal Correlation

- **Tempo -> Loki**: `tracesToLogsV2` configuration links traces to relevant log entries
- **Tempo -> Mimir**: `tracesToMetrics` links traces to metric time series
- **Loki -> Tempo**: Derived fields extract trace IDs from log lines and link to Tempo
- **Exemplars**: Link metric data points to specific traces for drill-down
- **Drilldown apps**: GA in 12.0; code-free navigation between metrics, logs, and traces

### Deployment Modes

| Mode | Scaling | Use Case |
|---|---|---|
| **Monolithic** | Single binary per component | Development, small scale |
| **Microservices** | Separate read, write, backend paths | Production; horizontal scaling |
| **Grafana Cloud** | Fully managed, automatic scaling | Managed SaaS |

### Deployment Methods

- **Helm charts**: Production-ready Kubernetes deployment for the full stack
- **Docker Compose**: Development and small-scale production
- **Grafana Cloud**: Fully managed; no infrastructure to operate

---

## Deployment Architecture

### Single Instance

- Suitable for 5-10 users
- Embedded SQLite database for configuration storage
- Memory baseline: 200-500 MB
- Simplest deployment; no HA

### High Availability

- External database (PostgreSQL or MySQL) for configuration storage
- Multiple Grafana instances behind a load balancer
- Shared file system or object storage for provisioned dashboards
- Session affinity or shared session storage (Redis/Memcached)

### Kubernetes

- Helm charts for Grafana and the full LGTM stack
- Grafana Operator for declarative management via CRDs
- Horizontal pod autoscaling based on CPU/memory metrics
- ConfigMaps and Secrets for provisioning configuration
- Resource recommendations:
  - Small: 200-500 MB memory, 0.5 CPU
  - Medium: 500 MB-2 GB, 1-2 CPU
  - Large: 2-4 GB, 2-4 CPU
  - Enterprise: 4-8+ GB, 4+ CPU

### Docker Compose

- Pre-built images: `grafana/grafana`, `grafana/grafana-enterprise`
- Volume mounts for persistent storage and provisioning files
- Suitable for development and small production deployments
