# Grafana Architecture

## Grafana Server

Grafana is a single Go binary serving a React/TypeScript frontend. The server handles:

- **HTTP API** -- REST + WebSocket endpoints for dashboards, data sources, alerting, RBAC, and provisioning management
- **Plugin system** -- Data source, panel, and app plugins loaded at startup. Grafana 12 has removed all Angular plugins; all core panels are React-based
- **Database backend** -- SQLite (default dev), MySQL, or PostgreSQL stores metadata: users, teams, dashboards, alert rules, data source configurations, API keys
- **Authentication** -- Built-in username/password, OAuth2/OIDC (Google, GitHub, Okta, Azure AD), SAML 2.0 (Enterprise/Cloud), LDAP; SCIM provisioning for users and groups (Cloud Advanced / Enterprise, GA in v12)
- **Versioned API model** -- Grafana 12 introduces a consistent, versioned, resource-oriented API. All resources (dashboards, folders, alert rules) are addressable by kind + version + name

## Data Source Plugins

Data sources bridge Grafana panels and external storage. Each plugin exposes a query editor, variable interpolation support, and health-check endpoint.

| Data Source | Primary Use | Query Language |
|---|---|---|
| Prometheus | Metrics (pull model) | PromQL |
| Loki | Log aggregation | LogQL |
| Tempo | Distributed traces | TraceQL |
| Elasticsearch | Full-text search, logs, metrics | Lucene / ES DSL |
| CloudWatch | AWS metrics and logs | CloudWatch Metrics Insights / Logs Insights |
| Azure Monitor | Azure metrics, logs, traces | KQL (Kusto) |
| InfluxDB | Time series metrics | Flux / InfluxQL |
| PostgreSQL | Relational data | SQL |
| Pyroscope | Continuous profiling | FlameQL |
| Mimir/Cortex | Long-retention Prometheus | PromQL |

**Plugin installation (v12):** Plugins must be installed through the Plugin Catalog inside the Grafana instance (Administration > Plugins and data > Plugin catalog).

## Provisioning

Provisioning allows Grafana configuration to be defined as files loaded at startup and reloaded via the Admin API -- enabling GitOps workflows.

### Directory Layout

Default: `/etc/grafana/provisioning/`

```
provisioning/
  datasources/       # YAML files defining data sources
  dashboards/        # YAML providers + JSON dashboard files
  alerting/          # YAML: alert rules, contact points, policies, mute timings
  plugins/           # YAML for plugin installation
  access-control/    # YAML for RBAC role assignments (Enterprise/Cloud)
```

### Data Source Provisioning

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      httpMethod: POST
      prometheusType: Prometheus
      prometheusVersion: 2.54.0
```

### Dashboard Provider

```yaml
apiVersion: 1
providers:
  - name: default
    orgId: 1
    type: file
    disableDeletion: true
    updateIntervalSeconds: 30
    allowUiUpdates: false
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: true
```

Grafana watches the `path` directory and reloads JSON dashboard files on change. `foldersFromFilesStructure: true` maps filesystem subdirectories to Grafana folders automatically.

### Alerting Provisioning

```yaml
apiVersion: 1
groups:
  - orgId: 1
    name: service-slos
    folder: SLOs
    interval: 1m
    rules:
      - uid: error-rate-high
        title: Error Rate > 5%
        condition: C
        data:
          - refId: A
            datasourceUid: prometheus-uid
            model:
              expr: >-
                sum(rate(http_requests_total{status=~"5.."}[5m]))
                / sum(rate(http_requests_total[5m]))
```

Contact points, notification policies, mute timings, and templates can also be provisioned via separate YAML files in `provisioning/alerting/`.

## Git Sync (Grafana 12 -- Observability as Code)

Git Sync is a first-class feature in Grafana 12 (experimental on-prem; public preview on Cloud as of February 2026).

- Mirrors dashboards and folder structures to a Git repository (GitHub, GitLab, Gitea, Azure DevOps)
- Changes made in the Grafana UI are committed automatically; changes pushed to Git are pulled into Grafana
- Supports dashboard JSON schema v2 (public preview) -- a typed, versioned schema replacing the legacy ad-hoc JSON model
- Roadmap: extending Git Sync to alert rules and data sources

## Grafana Cloud vs Self-Hosted

| Aspect | Self-Hosted (OSS/Enterprise) | Grafana Cloud |
|---|---|---|
| Management | Full ownership: patching, HA, backups | Fully managed by Grafana Labs |
| Stack | Grafana + Prometheus + Loki + Tempo + Alertmanager + object storage | Bundled LGTM (Loki, Grafana, Tempo, Mimir) stack |
| Scaling | Manual infrastructure work | Elastic; 1B+ active series |
| Retention | Configurable, storage-bound | 13 months metrics, 30 days logs/traces (paid tiers) |
| RBAC | Enterprise license required | Included |
| Cost | OSS free; Enterprise license fee | Usage-based SaaS pricing; free tier available |
| Compliance | Self-managed | SOC 2 Type II, GDPR |

## RBAC

### Built-in Roles

| Role | Capabilities |
|---|---|
| Viewer | View dashboards and alerts |
| Editor | Create/edit dashboards, alerts, playlists |
| Admin | Full org-level admin (users, data sources, plugins) |
| Grafana Admin | Server-level admin |

### Custom Roles (Enterprise/Cloud)

Define roles by combining specific permissions (actions) on specific resources (scopes). Provision via `provisioning/access-control/`.

```yaml
apiVersion: 1
roles:
  - name: SRE Oncall
    description: Read dashboards and silence alerts
    permissions:
      - action: dashboards:read
        scope: folders:uid:slos
      - action: alert.silences:create
        scope: '*'
```

### RBAC + Folders

Assign roles to teams at the folder level -- team members can only see and edit dashboards in their folder.

### SCIM Integration (v12)

Sync users and teams from SAML/OIDC IdP automatically, including group-to-team and group-to-role mappings.

## Folder Organization

Recommended hierarchy:

```
/ (root)
  General/            # catch-all
  Platform/           # infrastructure dashboards
    Kubernetes/
    Networking/
  Services/           # application service dashboards
    api/
    auth/
    payments/
  SLOs/               # SLO/SLA tracking
  Runbooks/           # diagnostic dashboards
  Alerts/             # alerting-related dashboards
```

Use naming conventions: `[Team] Service -- View` (e.g., `Platform Kubernetes -- Nodes`).

## Performance Optimization

**Query optimization:**
- Reduce time range or increase step interval to reduce data points
- Use Prometheus recording rules for expensive aggregations
- Set `Min interval` in panel query options to align with scrape interval
- Set `Max data points` to cap series per panel
- For Loki, use narrow stream selectors; add line filters early before parsers

**Caching:**
- Prometheus/Mimir query result caching (in-memory or Memcached)
- Grafana Enterprise built-in query caching middleware (datasource-level TTL)

**Limits:**
- Avoid more than 30 panels per dashboard
- Avoid high-cardinality variables with thousands of options
- Limit auto-refresh to 30s or longer
- Increase `dataproxy.max_idle_connections` for dashboards with 50+ panels
