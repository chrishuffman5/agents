# Splunk Features Reference

> Data ingestion, dashboards, alerting, and ITSI.

---

## Data Ingestion

### Input Methods

**Files and Directories (Monitor Inputs)**

`inputs.conf` stanza watches files or directories. Tracks file position with fishbucket (CRC-based) to avoid re-indexing.

```ini
[monitor:///var/log/nginx/access.log]
index = web_logs
sourcetype = nginx_access
disabled = false
```

**HTTP Event Collector (HEC)**

REST API on port 8088 accepting JSON events over HTTPS. Token-based auth. Supports single, batched, and raw events.

```bash
curl -k https://splunk:8088/services/collector/event \
  -H "Authorization: Splunk <HEC_TOKEN>" \
  -d '{"event": {"level":"ERROR","service":"checkout"}, "sourcetype":"app_json"}'
```

**Syslog**

UDP/514 or TCP/514 via Heavy Forwarder or SC4S (Splunk Connect for Syslog). SC4S is a containerized syslog layer handling 100+ vendor sourcetypes before forwarding to HEC.

**Scripted Inputs**

Execute a script on schedule; stdout ingested as events.
```ini
[script://./bin/poll_api.py]
interval = 60
sourcetype = custom_api_metrics
index = metrics
```

**Modular Inputs**

Packaged as Splunk apps (Python or Java SDK) with UI configuration. Examples: Splunk Add-on for AWS, Add-on for Microsoft Cloud Services.

### Forwarder Deployment

1. Install UF on target host (RPM, MSI, tarball)
2. Set `SPLUNK_DEPLOYMENT_SERVER` or configure `deploymentclient.conf`
3. Deployment Server assigns forwarder to server class
4. App with `inputs.conf` and `outputs.conf` deployed to forwarder
5. Forwarder begins collecting and forwarding to indexer cluster

```ini
# outputs.conf
[tcpout]
defaultGroup = indexer_cluster

[tcpout:indexer_cluster]
server = idx1.corp:9997, idx2.corp:9997, idx3.corp:9997
autoLBFrequency = 30
compressed = true
```

### Index Management

```ini
# indexes.conf
[web_logs]
homePath   = $SPLUNK_DB/web_logs/db
coldPath   = $SPLUNK_DB/web_logs/colddb
thawedPath = $SPLUNK_DB/web_logs/thaweddb
maxTotalDataSizeMB = 500000
frozenTimePeriodInSecs = 7776000   # 90 days
```

Key settings: `maxTotalDataSizeMB` (disk cap), `frozenTimePeriodInSecs` (time retention), `maxHotBuckets`, `repFactor = auto` (clustered).

### Sourcetype Configuration (props.conf)

```ini
[nginx_access]
SHOULD_LINEMERGE = false
TIME_PREFIX = \[
TIME_FORMAT = %d/%b/%Y:%H:%M:%S %z
MAX_TIMESTAMP_LOOKAHEAD = 30
KV_MODE = none
TRANSFORMS-routing = nginx_route_to_web_index
```

### transforms.conf

```ini
# Routing rule
[nginx_route_to_web_index]
REGEX = .
DEST_KEY = _MetaData:Index
FORMAT = web_logs

# PII masking
[mask_cc]
REGEX = \b(\d{4})[- ](\d{4})[- ](\d{4})[- ](\d{4})\b
FORMAT = XXXX-XXXX-XXXX-$4
DEST_KEY = _raw
```

---

## Dashboards & Visualization

### Classic Dashboards (SimpleXML)

XML-based, stored in `$SPLUNK_HOME/etc/apps/<app>/local/data/ui/views/`. Components: panels, rows, search elements, input controls, tokens, drilldown.

```xml
<dashboard>
  <label>Service Health</label>
  <row>
    <panel>
      <title>Request Rate</title>
      <chart>
        <search>
          <query>index=web | timechart span=5m count by status</query>
          <earliest>-1h</earliest>
        </search>
        <option name="charting.chart">line</option>
      </chart>
    </panel>
  </row>
</dashboard>
```

**Tokens** enable dynamic filtering:
```xml
<input type="dropdown" token="selected_host">
  <label>Host</label>
  <choice value="*">All</choice>
  <populatingSearch fieldForValue="host" fieldForLabel="host">
    index=web | stats count by host
  </populatingSearch>
</input>
```

### Dashboard Studio (JSON-based)

Modern framework (GA in Splunk 9.x). JSON definition, absolute/grid layouts, dynamic coloring, richer visualizations (radials, choropleths, custom D3). Does not fully replace SimpleXML for all legacy features.

### Splunk Observability Cloud

Separate SaaS product integrated with Splunk Enterprise:
- **Infrastructure Monitoring:** Metrics-based with SignalFlow streaming analytics
- **APM:** Distributed tracing via OpenTelemetry; service maps, RED metrics
- **RUM:** Browser/mobile session data, Core Web Vitals
- **Synthetics:** Uptime, browser, API tests
- **Log Observer Connect:** Bridges Enterprise logs with Observability Cloud traces

### Drilldown Patterns

- Token passing: click value sets token, filters other panels
- Link to search: open underlying SPL from dashboard
- Link to dashboard: navigate with pre-populated filter tokens
- Custom URL: link to PagerDuty, ServiceNow, Grafana with interpolated field values

---

## Alerting

### Saved Searches as Alerts

All Splunk alerts are saved searches with trigger conditions and alert actions.

```ini
[High Error Rate Alert]
search = index=web | timechart span=5m count as total, \
  sum(eval(status>=500)) as errors | eval rate = errors/total | where rate > 0.05
cron_schedule = */5 * * * *
dispatch.earliest_time = -10m
alert.track = 1
alert.condition = search count > 0
alert.severity = 4
action.email = 1
action.email.to = oncall@corp.com
```

### Alert Types

| Type | Behavior |
|------|----------|
| Scheduled | Run on cron schedule, evaluate after completion |
| Real-Time (per-result) | Fires on every matching event (high resource cost) |
| Real-Time (rolling-window) | Aggregates over window, evaluates continuously |

### Trigger Conditions

- Number of Results: count crosses threshold
- Number of Hosts: event host count exceeds expected
- Number of Sources: source count threshold
- Custom Condition: eval expression

### Alert Actions

| Action | Method |
|--------|--------|
| Email | HTML/plain-text with CSV attachment |
| Webhook | POST JSON to PagerDuty, Slack, Teams, ServiceNow |
| Script | Shell/Python on Splunk server (prefer webhook) |
| HEC | Write alert events back to Splunk (audit trail) |
| Notable Event | ES incident review queue (Enterprise Security) |

### Throttling

```ini
alert.suppress = 1
alert.suppress.period = 1h
alert.suppress.fields = host, error_code
```

---

## ITSI (IT Service Intelligence)

Premium app providing service-oriented monitoring on Splunk Enterprise.

### Service Trees

- **Services:** Logical groupings (Checkout Service, Payment Gateway)
- **Entities:** Physical/virtual components assigned to services
- **Dependencies:** Health propagates upward through service tree
- **Entity Rules:** Dynamic assignment via field-value matching

### KPIs (Key Performance Indicators)

Each KPI is a saved SPL search with threshold levels (Normal, Low, Medium, High, Critical), urgency weight, and time policies.

```spl
index=app_logs service=$service$
| timechart span=5m avg(response_ms) as avg_latency
```

### Glass Tables

Canvas-based drag-and-drop designer. Overlay KPI values, health scores, and sparklines on topology diagrams. Threshold-based color coding for operational awareness.

### Event Analytics

- **Episodes:** Groups of related notable events correlated by service/entity/time
- **Episode Review:** Triage queue for acknowledgment and resolution
- **Correlation Rules:** Define grouping logic
- **Suppression Rules:** Silence maintenance windows

### Predictive Analytics

- **Adaptive Thresholds:** ML-based seasonal decomposition auto-adjusts KPI thresholds
- **Predictive Analytics:** Forecasts KPI values 1-4 hours ahead
- Requires 2+ weeks historical data for seasonality
