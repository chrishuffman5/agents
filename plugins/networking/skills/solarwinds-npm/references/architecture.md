# SolarWinds NPM Architecture Reference

## Orion Platform Overview

SolarWinds NPM is built on the Orion Platform, a modular observability framework designed for on-premises enterprise network monitoring.

### Core Components

#### Orion Web Console
- IIS-hosted (Internet Information Services) web application
- HTTPS by default (port 443)
- Role-Based Access Control (RBAC) with account limitations, view limitations, and device group restrictions
- Customizable dashboards with drag-and-drop widgets
- Embeddable views for NOC displays

#### SQL Server Backend
- All configuration, polling data, events, and alerts stored in Microsoft SQL Server
- Supported versions: SQL Server 2016-2022, Enterprise or Standard edition
- **SQL Always On Availability Groups** for high availability
- Schema optimized for time-series data with automatic rollup (detailed -> hourly -> daily)
- Key databases: `SolarWindsOrion` (main), `SolarWindsOrionLog` (syslog/traps)

#### Main Polling Engine (MPE)
- Primary Windows service on the Orion Server
- Manages SNMP/WMI/ICMP polling cycles
- Coordinates with Additional Polling Engines
- Handles alert evaluation and notification dispatch
- Runs scheduled discoveries and report generation

#### Additional Polling Engines (APE)
- Scale-out pollers deployed on separate Windows servers
- Communicate back to main Orion over HTTPS (port 17777)
- Devices assigned to specific APEs (manual or auto-distribution)
- Use cases:
  - Large environments exceeding single poller capacity (>1,200 nodes)
  - Remote sites with WAN latency (local poller reduces SNMP round-trips)
  - Security zones requiring local polling (DMZ, restricted networks)
  - Redundancy (if one poller fails, reassign nodes)

#### SolarWinds Agent
- Lightweight agent for Windows and Linux systems
- Alternative to SNMP/WMI for host monitoring
- Capabilities: CPU/memory/disk monitoring, process monitoring, log collection, script execution
- Communicates to Orion over HTTPS
- Use when SNMP is not available or insufficient

### Service Architecture
```
[Monitored Devices]
    |-- SNMP/WMI/ICMP --> [Additional Polling Engine (remote site)]
    |-- SNMP/WMI/ICMP --> [Main Polling Engine (HQ)]
    |-- NetFlow/sFlow --> [NTA Collector (can be on APE)]
    |-- Syslog/Traps --> [Syslog/Trap Receiver]
    |
    v
[Orion Server (MPE + Web Console + Services)]
    |
    v
[SQL Server (data, config, events)]
    |
    v
[Orion Web Console] <-- [Admin/NOC browsers]
```

## Module Architecture

### NPM (Network Performance Monitor)
Core module providing:
- **Node monitoring**: Device availability (ICMP), SNMP-polled metrics (CPU, memory, hardware health)
- **Interface monitoring**: Bandwidth utilization (in/out octets), errors, discards, operational/admin status
- **Hardware health**: Temperature, fan, power supply status via vendor MIBs
- **Custom SNMP pollers**: Poll arbitrary OIDs and graph/alert on results
- **Network Atlas**: Manual topology mapping tool

### NTA (NetFlow Traffic Analyzer)
Flow-based traffic analysis module:
- **Flow protocols**: NetFlow v5/v9, IPFIX, J-Flow, sFlow
- **Flow receiver**: Collects flows on configurable UDP port
- **Data storage**: Flow summaries stored in SQL (not raw flows for performance)
- **Analysis**: Top talkers, top applications, top conversations, traffic by interface
- **Integration**: NTA data appears on NPM interface detail pages
- **CBQoS**: Class-Based QoS monitoring from NetFlow

### NCM (Network Configuration Manager)
Configuration management module:
- **Config backup**: SSH/Telnet to devices; retrieve running/startup config on schedule
- **Change detection**: Diff configs between backups; alert on unauthorized changes
- **Compliance**: Define configuration policies (required lines, forbidden lines); report violations
- **Config push**: Deploy config snippets to multiple devices (bulk change management)
- **Integration**: NCM data linked to NPM nodes; config changes correlated with performance events

### SAM (Server & Application Monitor)
Application monitoring module:
- **Application templates**: Pre-built monitoring for 1,200+ applications
- **Component monitors**: Process, service, Windows performance counter, URL, script, port, SNMP
- **Custom scripts**: PowerShell, VBScript, Bash, Python
- **Application dependency mapping**: Auto-discovered or manually defined
- **Integration**: SAM data in PerfStack; application health correlated with network metrics

### IPAM (IP Address Manager)
IP address management module:
- **Subnet scanning**: ICMP/SNMP scan to discover active IPs
- **DHCP/DNS integration**: Sync with Microsoft DHCP and DNS servers
- **Conflict detection**: Duplicate IP detection
- **Capacity reporting**: Subnet utilization trends

## NetPath

### Architecture
- Uses TCP probing (SYN/ACK timing) to measure hop-by-hop latency
- Probes initiated from NetPath-enabled agents or the Orion server itself
- Each probe traces the network path to a TCP service (HTTP, HTTPS, custom port)

### Data Collection
- Discovers intermediate hops (routers, switches, ISP devices) via TTL manipulation
- Measures per-hop latency and packet loss
- Correlates with BGP and DNS data for path context
- Historical data retained for path change analysis

### Visualization
- Interactive path diagram showing all discovered hops
- Color-coded latency (green/yellow/red)
- Path comparison over time (detect routing changes)
- Drill-down to specific hop performance history

### Requirements
- NetPath probe agent on the source side
- TCP connectivity to destination (port must be open)
- Intermediate hops must respond to TTL-exceeded (ICMP); some hops may be hidden
- Works across internet paths; not limited to SNMP-managed networks

## PerfStack

### Concept
Time-synchronized cross-domain metric correlation:
- Drag metrics from any Orion module onto a shared timeline
- Visually correlate events across network, server, and application layers
- Answer: "Did the network event cause the application slowdown?"

### Data Sources
- NPM: Interface utilization, node CPU/memory, availability
- NTA: Traffic volume, top talkers, application bandwidth
- SAM: Application response time, component status
- NCM: Configuration change events
- Custom SWQL queries

### Usage Pattern
```
1. User reports application slowdown at 14:30
2. Drag application response time metric to PerfStack
3. Drag WAN interface utilization to same timeline
4. Drag router CPU to same timeline
5. Visual correlation: WAN utilization spike at 14:28 -> Router CPU spike at 14:29 -> App response time spike at 14:30
6. Root cause: WAN congestion
```

## Alert Engine

### Alert Evaluation
- Alerts evaluated every polling cycle (default 60 seconds for availability, 5 minutes for metrics)
- Conditions checked against current polled data
- Multi-condition alerts: all conditions must be true simultaneously (AND) or any condition (OR)
- **Sustain duration**: Require condition to be true for N consecutive polling cycles

### Alert Components
1. **Trigger condition**: Metric threshold, state change, or complex expression
2. **Reset condition**: When alert auto-clears (metric below threshold, state restored)
3. **Notification actions**: What happens when triggered (email, script, webhook)
4. **Escalation actions**: What happens if not acknowledged within N minutes
5. **Scope**: Which objects the alert applies to (all nodes, specific groups, custom properties)

### Notification Architecture
- **Email**: SMTP relay configuration; HTML email templates with variable substitution
- **Webhook**: HTTP POST to external URL with JSON/XML payload
- **Script**: Execute PowerShell/VBScript on Orion server or remote target
- **SNMP Trap**: Forward alert as SNMP trap to another NMS
- **Integration**: Pre-built integrations for Slack, Teams, PagerDuty, ServiceNow

## SWQL (SolarWinds Query Language)

### Language Features
- SQL-like syntax: SELECT, FROM, WHERE, JOIN, ORDER BY, GROUP BY, TOP
- Orion-specific functions: ADDDAY(), ADDMINUTE(), GETUTCDATE(), TOLOCAL()
- Navigation properties: Traverse relationships without explicit JOINs
- Entity model: All Orion data exposed as queryable entities

### Key Entities
| Entity | Description |
|---|---|
| Orion.Nodes | All monitored nodes |
| Orion.NPM.Interfaces | Network interfaces |
| Orion.AlertStatus | Active and historical alerts |
| Orion.Events | System and device events |
| Orion.NetFlow.Flows | Flow data (NTA) |
| Orion.NCM.Configs | Configuration snapshots (NCM) |
| Orion.APM.Application | Application monitors (SAM) |

### Access Methods
- **SWQL Studio**: Desktop application (part of Orion SDK); interactive query editor with entity browser
- **REST API**: `GET https://<server>:17778/SolarWinds/InformationService/v3/Json/Query?query=<URL-encoded-SWQL>`
- **Web Console**: Report builder uses SWQL; custom query widgets available
- **PowerShell**: `Get-SwisData -SwisConnection $conn -Query "SELECT ..."`

## Orion SDK / REST API

### Endpoints
- Base: `https://<orion-server>:17778/SolarWinds/InformationService/v3/Json/`
- Query: `GET /Query?query=<SWQL>`
- CRUD: `POST /Create/<entity>`, `POST /<entity>/Update`, `POST /<entity>/Delete`
- Invoke: `POST /Invoke/<entity>/<verb>`

### Authentication
- Windows Integrated Authentication (Kerberos/NTLM)
- Basic Authentication (username/password, Orion account)

### Common Automations
- **Auto-onboarding**: Query CMDB, create nodes via API, assign to polling engines
- **Maintenance mode**: Unmanage nodes during change windows via API
- **Custom dashboards**: Pull Orion data into Grafana, Power BI, or custom web apps
- **Alert automation**: Webhook triggers external remediation scripts

## Scalability

### Sizing Guidelines
| Metric | Single Engine | Multi-Engine |
|---|---|---|
| Nodes | Up to 1,200 | 10,000+ (with APEs) |
| Interfaces | Up to 50,000 | 250,000+ |
| Pollers | 1 | 5-20 APEs |
| SQL Server | Standard | Enterprise (Always On AG) |

### Performance Tuning
- **SQL I/O**: SSD storage for SQL data and tempdb; most common bottleneck
- **Polling interval**: Increase from 60s to 120s or 300s for non-critical devices
- **Custom pollers**: Minimize; each adds polling overhead
- **Database maintenance**: Regular index rebuilds, statistics updates, log cleanup
- **APE placement**: Place APEs near monitored devices to reduce WAN SNMP traffic
