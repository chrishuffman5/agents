# Grafana 12.x Features

## Overview

Grafana 12 was released at GrafanaCON 2025 (May 2025) and represents a major evolution of the platform with a focus on observability as code, dynamic dashboards, and deeper integration across the LGTM stack. As of April 2026, the latest minor release is Grafana 12.4.

---

## Grafana 12.0 (May 2025) -- Major Release

### Observability as Code
- New suite of tools for automating observability workflows
- Version, validate, and deploy dashboards like any other codebase
- Terraform provider and CLI for infrastructure as code (public preview)
- Foundation for Git Sync and declarative management

### Dynamic Dashboards
- **Tabs**: Segment dashboard content by context, user group, or use case without creating separate dashboards
- **Conditional rendering**: Show or hide panels and rows based on variable selections or data availability
- **Flexible layout**: Improved arrangement options for panels and content

### Git Sync (Public Preview)
- Sync dashboards directly to a GitHub repository
- PR-based review workflow for dashboard changes
- Enables GitOps practices for dashboard management

### SQL Expressions
- Join and combine data from any data source using SQL syntax
- Removes limitations on cross-data-source data manipulation
- Enables complex data transformations without backend changes

### Performance Improvements
- Table visualization rebuilt with react-data-grid: **97.8% faster CPU performance** for large datasets
- Geomap visualization significantly faster rendering
- Overall dashboard loading performance improvements

### Grafana Drilldown (GA)
- Formerly "Explore Metrics, Logs, and Traces"
- Code-free, point-and-click deep-dive analysis
- Metrics Drilldown, Logs Drilldown, and Traces Drilldown
- TraceQL query streaming: partial results delivered as they arrive

### Cloud Migration Tooling (GA)
- Migration assistant for moving from OSS/Enterprise to Grafana Cloud
- Automated resource migration workflows

### SCIM User and Group Provisioning (Public Preview)
- Automatically synchronize users and teams from SAML identity providers
- Eliminates manual user creation in Grafana Cloud and Enterprise

### UI Enhancements
- Multiple new color themes for dashboard and UI customization
- Improved visual consistency across the platform

---

## Grafana 12.1 (July 2025)

### Alerting
- **New alert rule page (GA)**: Redesigned interface for faster alert rule management and location
- Improved alert rule creation and editing workflows

### Regression Analysis Transformation
- Predict future data values based on historical trends
- Estimate missing data points in datasets
- Built-in transformation available in any panel

### Visualization Actions with Custom Variables
- Actions now support user-defined custom variables
- Prompt for input when triggered, enabling real-time request customization
- No dashboard reconfiguration needed for parameterized actions

### Grafana Advisor (GA)
- Automated health monitoring for Grafana instances
- Detects plugin, data source, and SSO configuration issues
- Proactive recommendations for instance security and reliability

### Server-Configurable Quick Time Ranges
- Define custom time range presets for the dashboard time picker
- Support team-specific temporal analysis workflows

### Security
- Microsoft Entra Workload Identity support for Azure OAuth
- Improved Azure-based instance authentication and security

---

## Grafana 12.2 (September 2025)

### Enhanced Ad Hoc Filtering (GA)
- Dynamically filter dashboard data on the fly
- Transforms dashboards into interactive command centers
- Real-time data slicing without dashboard modification

### Redesigned Table Visualization (GA)
- Improved performance for large datasets
- Visual indicators for quick pattern and anomaly identification
- Better sorting, filtering, and column management

### Logs Drilldown JSON Viewer (GA)
- Navigate complex log structures with ease
- Expandable JSON tree view for structured log data

### Metrics Drilldown with Alert Integration (GA)
- Direct integration with Grafana Alerting
- Explore Prometheus data through point-and-click interactions
- Convert discovered queries directly into alert rules

### AI-Powered SQL Expressions (Public Preview)
- Generate SQL queries from natural language prompts
- Instant explanations for existing SQL queries
- Lowers barriers for users unfamiliar with SQL syntax

### Enhanced Canvas Pan and Zoom (Public Preview)
- Improved design capabilities for complex dashboard layouts
- Precise control over visualization positioning and scaling

---

## Grafana 12.3 (November 2025)

### Redesigned Logs Panel
- Completely redesigned for faster pattern recognition
- Clearer context display and smoother exploration experience
- Improved log line rendering and navigation

### New Data Source Integrations
- SolarWinds Enterprise data source
- Enhanced capabilities for Honeycomb querying
- Improved OpenSearch query support

### Dashboard Sharing Improvements
- Streamlined dashboard image export functionality
- Consolidated panel time controls for easier comparisons
- Time-range overrides for shared views

### Interactive Learning Experience (Public Preview)
- Contextual guidance system within the Grafana UI
- Tips, tutorials, and documentation delivered in-product
- Supports users throughout observability workflows

### UX Enhancements
- Reduced navigation complexity
- Improved accessibility across the platform

---

## Grafana 12.4 (February 2026)

### Git Sync Improvements (Public Preview)
- GitHub App authentication support
- Improved PR workflow: version dashboards, submit PRs, manage approvals
- Git-backed workflow for safer, auditable dashboard changes

### Dynamic Dashboards Updates (Public Preview)
- Improved tabs with flexible show/hide functionality
- Auto grid layout for responsive panel arrangement
- Dashboard content outline via side toolbar

### Suggested Dashboards (Public Preview)
- Surfaces pre-built dashboard suggestions based on connected data sources
- Reduces time to first meaningful dashboard

### Dashboard Templates (Public Preview)
- Create dashboards from standardized layouts
- Includes DORA metrics templates for engineering team workflows
- Template-driven dashboard creation for common use cases

### Revamped Gauge Visualization (Public Preview)
- New circular shape option (alternative to arc gauge)
- Sparkline support within gauge panels
- Gradient color support
- Accessibility improvements

### Time Range Pan and Zoom
- Interactive x-axis controls for intuitive time navigation
- New keyboard shortcuts for time range manipulation
- More efficient metric and data exploration

### Dashboard Controls
- Hide variables and annotations to reduce toolbar clutter
- Query variable regex filtering for display text customization
- Multi-property variables: map multiple identifiers to a single variable

### OpenTelemetry Log Display (Experimental)
- Enhanced metadata visibility for OTel-structured logging
- Better integration with OpenTelemetry log pipelines

### Logs Drilldown Updates (Public Preview)
- Configure default columns for log exploration
- Save and resume exploration sessions

### SCIM Provisioning (GA)
- Automate user and team lifecycle from identity providers
- Full production-ready SCIM synchronization

### RBAC for Saved Queries (Public Preview)
- Role-based access control with Writer and Reader roles
- Fine-grained permissions for shared query resources

### Data Source Updates
- Zabbix Data Source v6.1: external dashboard sharing, query guardrails, host tag filtering
- Google Sheets Data Source: default spreadsheet configuration

---

## LGTM Stack Integration

The LGTM (Loki, Grafana, Tempo, Mimir) stack is Grafana's unified observability platform, with each component addressing a critical signal type.

### Loki (Logs)
- Horizontally scalable, multi-tenant log aggregation system
- Uses LogQL query language (similar to PromQL)
- Label-based indexing (does not index log content by default) for cost efficiency
- Integrates with Grafana Logs Drilldown for code-free exploration
- Derived fields enable pivoting from log lines to traces in Tempo

### Tempo (Traces)
- Distributed tracing backend, cost-effective with object storage
- Uses TraceQL query language with streaming support (partial results)
- Trace-to-logs linking via `tracesToLogsV2` configuration with Loki
- Trace-to-metrics linking via `tracesToMetrics` configuration with Mimir
- Service graph generation for topology visualization
- Grafana Traces Drilldown (GA in 12.0) for deep-dive trace analysis

### Mimir (Metrics)
- Long-term, horizontally scalable metrics storage
- Drop-in Prometheus replacement with full PromQL compatibility
- Multi-tenant architecture with per-tenant limits
- Native Prometheus alerting and recording rules via built-in ruler
- 13-month retention in Grafana Cloud
- Supports both push (via Grafana Alloy/OpenTelemetry) and pull (Prometheus remote_write) ingestion

### Cross-Signal Correlation
- Tempo links to Loki (`tracesToLogsV2`) and Mimir (`tracesToMetrics`)
- Loki links to Tempo via derived fields (extract trace IDs from log entries)
- Creates a fully connected graph: start at any signal and navigate to any other
- Exemplars: link metric data points to specific traces
- Unified exploration through Grafana Drilldown apps

### Grafana Alloy (Telemetry Collector)
- Replaces Grafana Agent as the recommended telemetry collector
- OpenTelemetry-compatible pipeline for metrics, logs, and traces
- Declarative configuration with component-based architecture
- Supports Prometheus scraping, OTLP ingestion, and various receivers

### Performance Benchmarks (GrafanaCON 2025)
- LGTM stack achieves query P99 of 85ms (vs. ELK stack at 650ms -- 7x faster)
- Efficient object storage utilization for cost optimization

### Deployment Options
- **Helm charts**: Production-ready Kubernetes deployment for the full stack
- **Docker Compose**: Development and small-scale deployments
- **Grafana Cloud**: Fully managed LGTM stack with automatic scaling
- **Monolithic mode**: Single-binary deployment for each component (development/small scale)
- **Microservices mode**: Separate scaling of read, write, and backend paths (production)
