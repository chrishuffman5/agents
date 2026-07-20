# Zabbix Features Reference

> Templates, items, triggers, Low-Level Discovery, dashboards, and network maps.

---

## Template System

Templates are reusable collections of items, triggers, graphs, dashboards, and discovery rules linked to hosts. Zabbix 7.4 ships with 500+ official templates.

### Template Inheritance

Templates can link other templates, creating hierarchical inheritance. A "Linux by Zabbix Agent" template linked by a "Linux Web Server" template adds web-specific checks. Overrides allow per-host customization without breaking linkage.

### Template Groups

Organized into groups: "Templates/Operating systems", "Templates/Network devices", "Templates/Databases". Groups drive navigation and access control.

### Export/Import

Templates export to YAML (default in 7.x), XML, or JSON. YAML is git-friendly. Community templates at share.zabbix.com and official GitHub (`zabbix/zabbix` > `templates/`).

---

## Item Types

| Type | Description |
|------|-------------|
| Zabbix Agent (passive) | Server polls agent. Key: `system.cpu.load[all,avg1]` |
| Zabbix Agent (active) | Agent polls server for list, pushes results |
| SNMP Agent | Polls via OID. Key: `ifInOctets.1` |
| SNMP Trap | Receives traps via `snmptrapd` |
| HTTP Agent | HTTP/HTTPS GET/POST with full response capture |
| Calculated | Expressions over other items: `avg(//system.cpu.load,5m)` |
| Dependent | Derives from master item via preprocessing |
| Zabbix Trapper | Receives pushed data via `zabbix_sender` |
| Zabbix Internal | Internal metrics via `zabbix[*]` keys |
| Script | JavaScript in V8 engine with `Zabbix.request()` |
| SSH Agent | Remote SSH command, captures stdout |
| JMX Agent | JMX MBean attribute query |

### Common Item Keys

```
system.cpu.load[all,avg1]        # 1-minute load average
system.cpu.util[,user]           # CPU user time %
vm.memory.size[available]        # Available memory bytes
vfs.fs.size[/,pused]             # Filesystem % used
net.if.in[eth0,bytes]            # Network bytes in
proc.num[nginx]                  # Process count
web.page.get[https://example.com]# HTTP response body
log[/var/log/app.log,ERROR]      # Log file monitoring
```

### Preprocessing

Up to 20 steps per item, applied in order:

| Category | Preprocessors |
|----------|--------------|
| Text | Regular expression, trim, custom multiplier |
| Structured data | JSONPath, XML XPath, CSV |
| JavaScript | Full ECMAScript 5.1 in V8 engine |
| Prometheus | Pattern extraction from exposition format |
| Validation | Check for not-supported, discard unchanged, discard unchanged with heartbeat |

**JavaScript example:**
```javascript
var data = JSON.parse(value);
return (data.used / data.total * 100).toFixed(2);
```

### History and Trends

- **History:** Raw collected values. Default retention 90 days. High write volume.
- **Trends:** Hourly aggregates (min, max, avg, count). Default retention 365 days. Powers historical graphs efficiently.
- **Value types:** float, integer, string, log, text. Type mismatch causes "not supported" errors.

---

## Triggers & Alerting

### Trigger Expression Functions

| Function | Purpose |
|----------|---------|
| `last(/host/key)` | Most recent value |
| `last(/host/key,#N)` | Nth most recent value |
| `avg(/host/key,Ns)` | Average over N seconds |
| `max(/host/key,Ns)` / `min(...)` | Max/min over period |
| `sum(/host/key,Ns)` | Sum over period |
| `count(/host/key,Ns)` | Count of values |
| `diff(/host/key)` | 1 if last two values differ |
| `change(/host/key)` | Difference between last two |
| `nodata(/host/key,Ns)` | 1 if no data in N seconds |
| `find(/host/key,Ns,"like","pattern")` | Text pattern match |
| `percentile(/host/key,Ns,P)` | Pth percentile |
| `trendavg(/host/key,period)` | Average from trend data |

### Expression Examples

```
# CPU high for 5 minutes
avg(/Linux host/system.cpu.load[all,avg1],5m) > 5

# Disk space critical
last(/Linux host/vfs.fs.size[/,pused]) > 90

# Service down
last(/Linux host/proc.num[nginx]) = 0

# No data received
nodata(/Linux host/agent.ping,5m) = 1

# Log contains error
find(/App host/log[/var/log/app.log],60s,"regexp","FATAL|ERROR") = 1
```

### Severity Levels

| Severity | Color | Use Case |
|----------|-------|----------|
| Not classified | Gray | Unknown impact |
| Information | Blue | No action needed |
| Warning | Yellow | Degraded, monitor closely |
| Average | Orange | Significant impact |
| High | Orange-red | Serious, prompt action |
| Disaster | Red | Critical outage, immediate |

### Trigger Dependencies

When a dependency trigger is in PROBLEM state, dependent triggers are suppressed. Use case: suppress host alerts when upstream switch is down.

### Event Correlation

Global rules close open problems when matching events occur. Tags on triggers (`component:database`, `scope:performance`) enable flexible grouping and routing.

### Actions and Escalations

- **Conditions:** Trigger severity, host group, tags, maintenance status
- **Operations:** Send message, execute remote command, add host to group
- **Escalations:** Step 1 at 0 min (on-call), Step 2 at 30 min (team lead), Step 3 at 60 min (management)

### Media Types

Built-in: Email, SMS, Slack, Microsoft Teams, PagerDuty, Opsgenie, Telegram, Jira, ServiceNow. Custom script and JavaScript webhook media types extend to any system.

---

## Low-Level Discovery (LLD)

### Discovery Rules

Rules run on schedule (default 1 hour), producing JSON arrays of LLD macros.

**Built-in keys:**
- `vfs.fs.discovery` -- Filesystems (`{#FSNAME}`, `{#FSTYPE}`)
- `net.if.discovery` -- Interfaces (`{#IFNAME}`, `{#IFALIAS}`)
- `vfs.dev.discovery` -- Block devices
- `system.cpu.discovery` -- CPU cores

**Custom LLD:** UserParameter or Script items returning JSON:
```json
[
  {"{#SERVICE}": "nginx", "{#PORT}": "80"},
  {"{#SERVICE}": "mysql", "{#PORT}": "3306"}
]
```

### Item Prototypes

Use LLD macros in keys/names. For each discovered entity, a real item is created:
- Key: `vfs.fs.size[{#FSNAME},pused]`
- Name: `Filesystem {#FSNAME}: Used space in %`

### Trigger Prototypes

```
last(/{#HOST}/vfs.fs.size[{#FSNAME},pused]) > 85
```

Creates individual triggers per filesystem. Each independently tracks state.

### Filters and Overrides

**Filters:** Restrict entities (e.g., `{#FSTYPE}` matches `ext4|xfs|btrfs`).
**Overrides:** Per-entity customization (e.g., `/tmp` disables disk-full trigger, `lo` disables all items).

### Lifetime Management

- `Keep lost resources period`: How long to keep items for vanished entities (default 30 days)
- `Delete lost resources immediately`: Remove when entity disappears

---

## Dashboards & Maps

### Dashboard Widgets

| Widget | Purpose |
|--------|---------|
| Graph / SVG graph | Item history over time, stacking, thresholds |
| Problems | Filterable problem list by severity/tags |
| Top hosts | Ranked host list by item value |
| Honeycomb | Color-coded host status grid |
| Item value | Single metric display with sparkline |
| Gauge | Visual dial for single metrics |
| Map | Embedded network map |
| Geomap | Geographic map with host pins |
| SLA report | Service Level Agreement compliance |
| Data overview | Tabular item values for host group |
| Host availability | Agent/SNMP/JMX availability summary |

### Network Maps

Visual topology with hosts, host groups, triggers, images, shapes, and links. Elements display trigger severity as color. Support drill-down to sub-maps or host dashboards.

### Host Groups

Organize hosts logically (by environment, team, technology). Drive dashboard filtering, action conditions, user permissions, template application. Nested groups (e.g., `Linux/Production/Web`) in Zabbix 6.2+.

### SLA Monitoring

Native SLA objects (6.0+). Define SLAs with service trees, SLO percentages, and reporting periods. SLA widget shows compliance. Services link to triggers (trigger firing = downtime).

### Maintenance Windows

Suppress alerts during scheduled downtime. Types:
- **With data collection:** Items continue, triggers suppressed
- **No data collection:** Polling pauses entirely

One-time and recurring schedules supported.
