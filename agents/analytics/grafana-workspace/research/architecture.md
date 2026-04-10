# Grafana Architecture

## Overview

Grafana is an open-source operational analytics and dashboarding platform that provides a unified interface for visualizing, querying, and alerting on data from diverse sources. The architecture is modular and plugin-driven, enabling extensibility across data sources, visualizations, and application workflows.

---

## Core Components

### Dashboards

Dashboards are the primary organizational unit in Grafana. Each dashboard is a collection of one or more **panels** arranged in rows, providing an at-a-glance view of related operational data.

**Key characteristics:**
- JSON-based definition format, version-controllable and portable
- Support for variables (template variables, ad hoc filters) enabling dynamic, reusable dashboards
- Annotations for marking events on time-series graphs
- Dashboard links and drilldown navigation between dashboards
- Time range controls (global and per-panel overrides)
- Auto-refresh with configurable intervals

**Grafana 12 Dashboard Enhancements:**
- **Tabs**: Segment dashboards by context, user group, or use case without splitting metrics across multiple dashboards
- **Conditional rendering**: Show or hide panels or rows based on variable selections or data availability
- **Auto grid layout**: Flexible panel arrangement with automatic sizing
- **Dashboard content outline**: Side toolbar for navigating large dashboards
- **Git Sync**: Sync dashboards directly to GitHub repositories for version control and collaborative review via pull requests

### Data Sources

Data sources are the backend systems Grafana queries for metrics, logs, traces, and other data. The query engine composes queries per panel using data source plugins.

**Built-in data sources:**
- Prometheus (metrics)
- Loki (logs)
- Tempo (traces)
- Mimir (scalable long-term metrics storage)
- InfluxDB, Graphite, Elasticsearch/OpenSearch
- MySQL, PostgreSQL, Microsoft SQL Server
- CloudWatch, Azure Monitor, Google Cloud Monitoring
- Jaeger, Zipkin (distributed tracing)
- Testdata (for testing and development)

**Data source architecture:**
- Each data source is a plugin that translates Grafana queries into backend-specific query languages (PromQL, LogQL, TraceQL, SQL, etc.)
- Data source proxying: queries route through the Grafana server, preventing direct browser-to-database connections and centralizing authentication
- Mixed data source mode: combine queries from multiple data sources in a single panel
- SQL Expressions (Grafana 12): join and combine data from multiple sources using SQL syntax without backend limitations

**Enterprise/Cloud-only data sources:**
- Splunk, Oracle, ServiceNow, SAP HANA, Snowflake, Databricks, MongoDB, and others

### Panels and Visualizations

Panels are the building blocks of dashboards. Each panel runs one or more queries against a data source and renders the results using a visualization type.

**Core visualization types:**
- Time series (line, bar, points)
- Stat (single value with sparkline)
- Gauge (arc and circular shapes)
- Bar chart, Histogram, Pie chart
- Table (redesigned in 12.x with react-data-grid for 97.8% faster CPU performance)
- Heatmap, Geomap (significantly faster in 12.x)
- Logs, Traces, Flame graph
- Canvas (freeform layout with pan and zoom)
- Node graph, State timeline, Status history
- Alert list, Dashboard list, News, Text

**Panel features:**
- Query inspector for debugging query performance and results
- Transformations pipeline: filter, join, aggregate, rename, calculate, and manipulate query results before visualization
- Regression analysis transformation (12.1): predict future values or estimate missing data points
- Thresholds and value mappings for color-coded status indication
- Panel overrides for field-level styling customization
- Visualization actions with custom variables (12.1)

### Alerting Engine

Grafana Alerting is built on the Prometheus alerting model and provides a unified alerting system across all data sources.

**Architecture components:**

1. **Alert Rules**: Queries + expressions + conditions that define when alerts fire
   - Grafana-managed rules: evaluated by the Grafana alerting engine
   - Data source-managed rules: evaluated by compatible data sources (e.g., Prometheus, Mimir, Loki ruler)
   - Recording rules: pre-compute expensive queries for faster dashboard loading

2. **Alert Evaluation**: Continuous periodic evaluation on a configurable schedule
   - Each rule can produce multiple alert instances (one per time series/dimension)
   - Configurable evaluation timeout (default 30s) and max attempts (default 3)
   - No Data and Error state handling with configurable behavior

3. **Notification Policies**: Tree-structured routing rules
   - Root (default) policy with nested child policies
   - Label-based matching for routing alerts to appropriate contact points
   - Grouping: combine related alert instances into single notifications
   - Timing controls: group_wait, group_interval, repeat_interval

4. **Contact Points**: Notification destinations
   - Email, Slack, PagerDuty, OpsGenie, Microsoft Teams, Webhooks
   - Telegram, Discord, Google Chat, LINE, Threema
   - Each contact point can have multiple integrations

5. **Silences and Mute Timings**:
   - Silences: one-time suppression (e.g., maintenance windows)
   - Mute timings: recurring suppression schedules (e.g., nights and weekends)
   - Mute timings are not inherited from parent policies

### Provisioning

Grafana supports declarative configuration management for infrastructure-as-code workflows.

**File-based provisioning:**
- YAML configuration files in `<WORKING_DIR>/conf/provisioning/` (or `/etc/grafana/provisioning/` for package installs)
- Subdirectories: `datasources/`, `dashboards/`, `alerting/`, `plugins/`
- Environment variable substitution using `$ENV_VAR` or `${ENV_VAR}` syntax
- Automatic reload on file changes (configurable interval)

**Provisioning scope:**
- Data sources: connection parameters, authentication, default settings
- Dashboards: JSON models loaded from file system or external sources
- Alerting resources: alert rules, notification policies, contact points, mute timings
- Plugin installation and configuration

**Infrastructure as Code tools:**
- **Terraform provider**: Manage Grafana resources (dashboards, data sources, folders, alerts, organizations) declaratively
- **Grafana Operator** (Kubernetes): Custom Resources for managing Grafana instances and their associated resources
- **Crossplane provider**: Kubernetes-native Terraform-based management (alpha stage)
- **Git Sync** (Grafana 12): Native GitHub integration for dashboard version control with PR-based workflows

**API-based provisioning:**
- Full REST API for programmatic management of all Grafana resources
- Service accounts with fine-grained RBAC for automation pipelines

### Plugins

Grafana's plugin system is the primary extensibility mechanism.

**Plugin types:**

1. **Data source plugins**: Connect to external data backends, translate queries, return data in Grafana's internal format
2. **Panel plugins**: Custom visualization types beyond the built-in options
3. **App plugins**: Bundled experiences combining custom pages, panels, and data sources into cohesive monitoring solutions

**Plugin management:**
- Plugin catalog: 200+ community and official plugins
- CLI installation: `grafana-cli plugins install <plugin-id>`
- Provisioning-based installation via configuration files
- Signed plugin verification for security
- Grafana Advisor (12.1 GA): Automated detection of plugin, data source, and SSO configuration issues

**Plugin development:**
- Plugin SDK (grafana-plugin-sdk-go for backend, @grafana/data + @grafana/ui for frontend)
- Plugin tools CLI for scaffolding new plugins
- Support for backend plugins (Go) with data source proxying and alerting integration

---

## Grafana Cloud vs. OSS vs. Enterprise

### Grafana OSS (Community Edition)

**Characteristics:**
- Free, open-source (AGPL v3 license)
- Self-hosted on your own infrastructure
- Full dashboard, visualization, and core alerting capabilities
- Community plugin ecosystem
- File-based provisioning and REST API
- You manage installation, upgrades, scaling, backups, and high availability

**Limitations vs. Enterprise/Cloud:**
- No enterprise data source plugins (Splunk, Oracle, ServiceNow, etc.)
- No advanced reporting and scheduled PDF generation
- No granular data source permissions
- No SAML authentication or Team Sync
- No SCIM user/group provisioning
- No query caching (built-in)
- No audit logging

### Grafana Enterprise

**Additions over OSS:**
- Enterprise data source plugins
- SAML/LDAP enhanced authentication, Team Sync
- Data source permissions and fine-grained RBAC
- Query caching for improved performance
- Reporting: scheduled PDF/CSV delivery
- Audit logging for compliance
- White labeling and custom branding
- Vault integration for secrets management
- Enterprise support SLAs

### Grafana Cloud

**Characteristics:**
- Fully managed SaaS platform by Grafana Labs
- Includes the full LGTM stack: Grafana + Mimir (metrics) + Loki (logs) + Tempo (traces)
- Automatic upgrades, security patches, and backups
- 99.5% uptime SLA
- Scales to 1B+ active metric series

**Retention:**
- 13-month metrics retention
- 30-day log and trace retention (expandable)

**Free tier:**
- 10,000 metrics series
- 50 GB logs, 50 GB traces, 50 GB profiles
- 50,000 frontend sessions
- 500 VUh k6 testing
- 2-week data retention
- 3 users

**Pro plan:**
- $19/month platform fee + usage-based pricing per product
- Extended retention, support, and all features

**Cloud-exclusive features:**
- Grafana Cloud Migration Assistant
- Adaptive Metrics (cost optimization)
- Grafana Cloud Asserts (entity-based root cause analysis)
- Synthetic Monitoring, Frontend Observability
- k6 Cloud (load testing)
- Incident and On-call (IRM)
- Secrets management (centralized UI, launched August 2025)

---

## Deployment Architecture

### Single Instance
- Suitable for small teams (5-10 users)
- Embedded SQLite database for configuration storage
- Memory baseline: 200-500 MB

### High Availability
- External database (PostgreSQL or MySQL) for configuration storage
- Multiple Grafana instances behind a load balancer
- Shared file system or object storage for provisioned dashboards
- Session affinity or shared session storage (Redis/Memcached)

### Kubernetes Deployment
- Helm charts for Grafana and the full LGTM stack
- Grafana Operator for declarative management via Custom Resources
- Horizontal pod autoscaling based on CPU/memory metrics
- ConfigMaps and Secrets for provisioning configuration

### Docker Compose
- Suitable for development and small production deployments
- Pre-built images: `grafana/grafana`, `grafana/grafana-enterprise`
- Volume mounts for persistent storage and provisioning files
