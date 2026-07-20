# Paradigm: Operational Analytics

When and why to choose operational dashboards and AI-driven analytics platforms. Covers Grafana and ThoughtSpot.

## What Defines Operational Analytics

Operational analytics platforms focus on real-time visibility, alerting, and fast time-to-insight. Unlike enterprise BI (which optimizes for governed self-service on modeled data) or reporting (which produces formatted scheduled output), operational analytics prioritizes live data, immediate response, and low-latency querying across federated data sources.

Key characteristics:
- **Real-time or near-real-time data** -- Dashboards reflect current state, not yesterday's ETL run
- **Alerting and notification** -- Threshold-based or anomaly-based alerts trigger when data crosses boundaries
- **Data source federation** -- Query multiple backends simultaneously without centralizing into a warehouse
- **Low-ceremony setup** -- Connect a data source, build a dashboard, share it. Minimal modeling overhead.
- **Operations-oriented audience** -- SREs, DevOps engineers, support teams, operations managers

## Choose Operational Analytics When

- **Monitoring and observability are the use case** -- System metrics (CPU, memory, latency, error rates), application performance, infrastructure health. Grafana is the industry standard here.
- **Time-series data dominates** -- IoT sensor readings, financial tick data, application metrics, log volumes over time. These tools are optimized for time-indexed data.
- **Alerting is a first-class requirement** -- You need alerts that fire when response time exceeds 500ms, error rate spikes above 1%, or anomaly detection flags unusual patterns.
- **Data lives in many sources and cannot be centralized** -- Grafana queries Prometheus, InfluxDB, Elasticsearch, PostgreSQL, and CloudWatch simultaneously from a single dashboard. No ETL pipeline required.
- **Users want answers without learning a BI tool** -- ThoughtSpot's natural-language search interface lets users type "revenue by region last quarter" and get a chart without training.

## Avoid Operational Analytics When

- **The use case is traditional business intelligence** -- Star schemas, governed metrics, self-service report building. Grafana lacks a semantic layer and dimensional modeling. ThoughtSpot can do this but at a high price point.
- **Pixel-perfect formatted reports are needed** -- Neither Grafana nor ThoughtSpot produces paginated, print-ready output. Use SSRS or Looker.
- **The primary audience is business executives** -- Executives expect polished, branded dashboards with drill-through storytelling. Power BI or Tableau is a better fit.
- **Complex data transformations are required before visualization** -- Operational tools query data as-is. If significant modeling or transformation is needed, add a warehouse + dbt layer first.

## Technology Comparison Within This Paradigm

| Feature | Grafana | ThoughtSpot |
|---|---|---|
| **Primary model** | Dashboard builder with federated data sources | Search-based analytics with AI-driven insights |
| **Query interface** | Per-data-source query editors (PromQL, LogQL, SQL, Flux) | Natural-language search bar, SpotIQ AI analysis |
| **Data sources** | 100+ plugins: Prometheus, InfluxDB, Elasticsearch, Loki, PostgreSQL, MySQL, CloudWatch, Tempo, Graphite | Cloud warehouses: Snowflake, BigQuery, Redshift, Databricks, Azure Synapse |
| **Visualization** | Time-series panels, heatmaps, stat panels, logs, traces, node graphs | Charts, tables, Liveboards, pinboards, SpotIQ insights |
| **Alerting** | Unified alerting (Grafana 9+): threshold, multi-dimensional, contact points (email, Slack, PagerDuty, OpsGenie) | Monitor alerts on saved searches, threshold-based |
| **AI/ML** | Anomaly detection via ML plugins, Grafana Machine Learning (commercial) | SpotIQ: automated anomaly detection, trend analysis, change point detection |
| **Deployment** | Self-hosted (Docker, Kubernetes, binary) or Grafana Cloud (managed) | ThoughtSpot Cloud (managed) or ThoughtSpot Software (on-prem) |
| **Embedding** | iFrame, Grafana embedding (auth proxy or anonymous), Grafana Scenes (React SDK) | ThoughtSpot Everywhere: Visual Embed SDK, REST API |
| **Licensing** | OSS (AGPL), Grafana Cloud Free/Pro/Enterprise | Commercial (per-user subscription, enterprise pricing) |
| **Best for** | Infrastructure monitoring, observability (metrics + logs + traces) | Business users who want AI-driven analytics on cloud warehouses |

## Common Patterns

### Grafana: The Observability Dashboard

**Core architecture:**
- Grafana does not store data -- it queries external data sources at render time
- Each panel in a dashboard has its own query against a configured data source
- Mixed data sources in a single dashboard are standard (Prometheus metrics + Loki logs + PostgreSQL business data)

**Data source federation pattern:**
```
Dashboard: "Production Overview"
├── Panel: Request Rate (Prometheus - PromQL)
│   rate(http_requests_total{env="prod"}[5m])
├── Panel: Error Logs (Loki - LogQL)
│   {app="api", level="error"} |= "timeout"
├── Panel: Database Connections (PostgreSQL - SQL)
│   SELECT count(*) FROM pg_stat_activity WHERE state = 'active'
├── Panel: Revenue Today (PostgreSQL - SQL)
│   SELECT SUM(amount) FROM orders WHERE created_at >= CURRENT_DATE
└── Panel: Cloud Costs (CloudWatch - CloudWatch query)
    AWS/Billing EstimatedCharges
```

**Alerting architecture (Grafana 9+ unified alerting):**
1. Define alert rules with conditions (e.g., `avg(cpu_usage) > 80% for 5 minutes`)
2. Alert rules evaluate on a configurable schedule (default: every 1 minute)
3. Firing alerts route through notification policies (label-based routing)
4. Contact points deliver to Slack, PagerDuty, OpsGenie, email, webhooks, Microsoft Teams
5. Silences and mute timings suppress alerts during maintenance windows

**Grafana dashboard design for operations:**
- Top row: traffic-light status panels (green/yellow/red) for key services
- Middle: time-series graphs for the last 1h/6h/24h (request rate, error rate, latency percentiles)
- Bottom: logs panel showing recent errors filtered by the selected service
- Variables: dropdown selectors for environment (prod/staging), service, region -- filter all panels simultaneously

**Limitations for business BI:**
- No semantic layer, no dimensional modeling, no star schema awareness
- Every panel runs a raw query -- no shared metric definitions
- Visualization types are optimized for time-series; treemaps, waterfall charts, and Sankey diagrams are plugins with varying quality
- User management is basic; row-level security does not exist in the data layer

### ThoughtSpot: AI-Driven Search Analytics

**Search-based paradigm:**
- Users type natural-language queries: "revenue by product category last 6 months"
- ThoughtSpot translates to SQL, executes against the connected warehouse, and renders a chart
- SpotIQ analyzes data automatically: finds anomalies, trend changes, and outliers without user prompting
- Liveboards (dashboards) are assembled from saved search results

**ThoughtSpot Everywhere (embedded analytics):**
```javascript
// Embed a Liveboard in a React application
import { LiveboardEmbed } from '@thoughtspot/visual-embed-sdk';

const embed = new LiveboardEmbed('#embed-container', {
  liveboardId: 'abc-123-def',
  frameParams: { height: '800px' },
  runtimeFilters: [{
    columnName: 'Region',
    operator: 'EQ',
    values: ['North America']
  }]
});
embed.render();
```

**SpotIQ capabilities:**
- **Change analysis:** Detects when a metric shifted significantly and identifies contributing dimensions
- **Trend detection:** Identifies upward/downward trends, seasonality patterns
- **Anomaly detection:** Flags data points that deviate from historical patterns
- **What-if analysis:** Scenario modeling on selected metrics

**Limitations:**
- Expensive -- enterprise pricing is not competitive with open-source or even Power BI Pro
- The search paradigm is powerful for known-question analytics but frustrating for open-ended exploration
- Requires well-modeled warehouse tables; performs poorly on raw, unnormalized data
- SpotIQ insights are useful but can produce false positives that erode user trust if not tuned

### Alerting and Anomaly Detection

| Feature | Grafana | ThoughtSpot |
|---|---|---|
| **Alert types** | Threshold, multi-condition, query-based (any data source) | Threshold on saved searches, SpotIQ anomaly alerts |
| **Evaluation** | Server-side, configurable interval (1m-24h) | SpotIQ scheduled analysis, monitor-based |
| **Routing** | Label-based routing to contact points (Slack, PD, email) | Email notifications, webhook actions |
| **Anomaly detection** | ML plugin (Grafana Enterprise), or external (Prometheus Anomaly Detection) | SpotIQ built-in (statistical, ML-based) |
| **Maintenance windows** | Silences and mute timings (time-based, label-based) | Not built-in -- suppress via external workflow |

### When to Use Both

A common enterprise pattern combines Grafana for operations and ThoughtSpot (or another BI tool) for business analytics:

| Layer | Tool | Audience | Data |
|---|---|---|---|
| Infrastructure monitoring | Grafana | SRE / DevOps | Prometheus, Loki, Tempo |
| Application performance | Grafana | Engineering | Application metrics, traces, logs |
| Business KPI dashboards | Power BI / Tableau / ThoughtSpot | Business users | Data warehouse (star schema) |
| Ad-hoc business questions | ThoughtSpot / Superset | Analysts | Data warehouse |

This avoids the anti-pattern of forcing Grafana into business BI or forcing Tableau into operational monitoring -- each tool handles its strength.
