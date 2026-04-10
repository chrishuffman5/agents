# Grafana Dashboards

## Panel Types

Grafana 12 ships these core visualization types:

| Panel | Best For |
|---|---|
| **Time series** | Line/area charts over time; thresholds, fill below to, stacking |
| **Stat** | Single big number; sparkline optional; color thresholds |
| **Gauge** | Radial or linear gauge; threshold-colored fill |
| **Bar chart** | Categorical comparisons; horizontal or vertical |
| **Bar gauge** | Row of horizontal bars for ranked comparison |
| **Table** | Tabular data; column filtering, sorting, sparklines; refactored in v12 (97.8% faster on 40k+ rows) |
| **Heatmap** | Distribution over time; bucket-based color encoding |
| **Logs** | Streaming log lines from Loki/Elasticsearch; level coloring, deduplication |
| **Traces** | Waterfall spans from Tempo/Jaeger/Zipkin/OTel |
| **Node graph** | Service maps, dependency graphs (nodes + edges) |
| **Geomap** | Geographic data on tiled maps; markers, heatmap, GeoJSON layers |
| **Canvas** | Pixel-precise custom layout with element placement |
| **State timeline** | Discrete state changes over time |
| **Status history** | Color-coded history grid |
| **Pie chart** | Proportional shares; donut variant |
| **XY chart** | Scatter plots and correlation analysis |
| **Text** | Markdown / HTML content panels |
| **Alert list** | Live alert state panel |
| **Dashboard list** | Links to other dashboards |

### Grafana 12 Panel Additions

- **Conditional rendering** -- Panels and rows shown/hidden based on variable values or whether the panel has data
- **Auto-grid layout** (Dynamic Dashboards, experimental) -- Panels reflow automatically across screen sizes
- **Tabs** (Dynamic Dashboards) -- Contextual tab layout groups panels by topic within a single dashboard
- **Dashboard outline** -- Tree-view navigation pane for fast structural navigation

## Variables

Variables drive templating -- changing a variable re-runs all panels that reference it via `${variable_name}` or `[[variable_name]]` syntax.

| Variable Type | Source | Example Use |
|---|---|---|
| **Query** | Runs a data source query | `label_values(up, job)` from Prometheus |
| **Custom** | Comma-separated static values | `prod,staging,dev` |
| **Interval** | Time interval list | `1m,5m,15m,1h` |
| **Text box** | Free-form user input | Filter by arbitrary string |
| **Constant** | Fixed value; hidden from UI | Base URL for a link |
| **Data source** | List of configured data sources by type | Switch active Prometheus instance |
| **Ad hoc filters** | Dynamic key=value label filters applied to all queries | On-the-fly Prometheus label filtering |

### Variable Chaining

Variables can reference other variables. Example: `namespace` variable feeds a `deployment` variable whose query is `label_values(kube_deployment_labels{namespace="$namespace"}, deployment)`.

### Variables in Transformations (v12)

All text-input fields in transformations accept `${variable}` syntax; variables are interpolated before transformations execute.

## Transformations

Transformations process query results in the browser without modifying the data source query. They chain sequentially.

| Transformation | Purpose |
|---|---|
| **Merge** | Combine multiple frames into one table |
| **Filter by name** | Include or exclude specific fields |
| **Filter by value** | Row-level filtering with conditions |
| **Group by** | Aggregate rows; functions: sum, mean, min, max, count, last |
| **Calculate field** | Add computed columns; math expressions and `${__field.name}` |
| **Organize fields** | Reorder, rename, and hide columns |
| **Rename by regex** | Bulk-rename fields using regex capture groups |
| **Join by field** | SQL-style join on a common field (time, id) |
| **Series to rows** | Pivot series from columns to rows |
| **Rows to fields** | Pivot a config table into field overrides |
| **Prepare time series** | Convert wide to long format (or vice versa) |
| **Sort by** | Sort rows by a field |
| **Limit** | Restrict row count |
| **Extract fields** | Parse JSON/text fields into separate columns |
| **Regression analysis** | Linear regression line overlay |

**Transformation order matters:** Filters placed early reduce the dataset processed by later steps, improving browser performance.

## Annotations

Annotations overlay event markers on time series panels.

- **Built-in annotations** -- Alert state changes are automatically annotated on panels
- **Query annotations** -- Define an annotation query against any data source (Loki log events, Elasticsearch events, Prometheus alerts)
- **Manual annotations** -- Click-to-annotate in edit mode; stored in Grafana's database
- **Dashboard annotations** -- Scoped to a single dashboard; panel annotations apply to specific panels

Configuration: Dashboard settings > Annotations > Add annotation query.

## Dashboard Links and Data Links

- **Dashboard links** -- Navigation links in the dashboard header to other dashboards; support variable interpolation
- **Panel links** -- Per-panel links using `${__value.raw}`, `${__field.name}`, and other built-in variables
- **Data links** -- Click a data point to navigate to a target URL (another dashboard, Loki Explore, external system); support `${__data.fields.fieldname}` and time range variables

Data links are essential for connecting the L1 > L2 > L3 dashboard hierarchy. Click a service in the overview to open its detail dashboard with the right filters applied.

## Dashboard JSON Model

Every dashboard is stored as a JSON document. Top-level keys:

```json
{
  "uid": "abc123",
  "title": "Service Overview",
  "schemaVersion": 39,
  "version": 5,
  "refresh": "30s",
  "time": { "from": "now-1h", "to": "now" },
  "timepicker": {},
  "templating": { "list": [ /* variable definitions */ ] },
  "annotations": { "list": [] },
  "links": [],
  "tags": ["service", "prod"],
  "panels": [
    {
      "id": 1,
      "type": "timeseries",
      "title": "Request Rate",
      "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 },
      "targets": [ /* query definitions */ ],
      "transformations": [],
      "fieldConfig": { "defaults": {}, "overrides": [] },
      "options": {}
    }
  ]
}
```

**Schema v2** (public preview, Grafana 12): Typed, versioned schema with formal kind definitions. Enables validation, diffing, and IDE support. Backward compatible with v1.

**Export:** Dashboard menu > Share > Export > Save to file.
**Import:** `+` > Import > upload JSON.

## Dashboard Design Guidelines

- Use **thresholds** with consistent colors: green (normal), yellow (warning), red (critical)
- Normalize Y-axis units; always specify the unit (requests/s, ms, bytes)
- Use **repeat panels** (by variable) rather than duplicating panels manually
- Set **panel descriptions** explaining what the metric means and what action to take
- Use **dashboard tags** for discovery: service name, team, environment
- Set appropriate **default time range** (1h for ops, 24h for capacity)
- Set a **sensible refresh rate** -- avoid < 30s; use streaming panels for live data
- Use **data links** and **panel links** to connect related dashboards (drill-down)
- Store dashboards in version control (provisioning or Git Sync)
- Use `foldersFromFilesStructure: true` in dashboard providers to auto-create folder structure
