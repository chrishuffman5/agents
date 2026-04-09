# Network Monitoring Deep Dive — NPM / ThousandEyes / Kentik / LibreNMS / PRTG

## Overview

Enterprise network monitoring spans traditional SNMP-based polling (SolarWinds NPM, LibreNMS, PRTG), flow-based analytics (Kentik), synthetic and path monitoring (ThousandEyes), and hybrid SaaS platforms. Modern deployments often combine multiple tools: an NMS for device health, a flow platform for traffic analysis, and a synthetic monitor for end-user experience visibility.

---

# SolarWinds NPM 2025.2

## Architecture — Orion Platform

SolarWinds NPM is built on the **Orion Platform**, a modular observability framework:

- **Orion Web Console** — IIS-hosted web application; HTTPS; role-based access control (RBAC).
- **SQL Server Backend** — All configuration, polling data, and events stored in Microsoft SQL Server; supports SQL Always On AG for high availability.
- **Main Polling Engine** — Primary service collecting data from monitored nodes; installed on the Orion Server.
- **Additional Polling Engines (APE)** — Scale-out pollers for large environments or remote sites; communicate back to main Orion over HTTPS.
- **Agent** — Optional lightweight agent for Windows/Linux systems without SNMP; enables WMI, script execution, and process monitoring.
- **Orion SDK** — .NET/REST SDK for building custom integrations, importing data, and extending the platform.

## NPM 2025.2 New Features

- **Thin Access Point Management** — Discover and manage thin APs as individual SNMP nodes; separate visibility per AP (previously only WLC-level).
- **Layer 2/3 Metrics Monitoring** — Comprehensive topology data: IP address assignments, STP (Spanning Tree Protocol) topology, VLAN configurations, ARP table mappings across multi-vendor switches.
- **Interactive Topology Widgets** — New dashboard widgets showing VLAN membership maps, STP root/blocked port visualization, MAC address table drill-down.
- **Aruba Central API Integration** — Monitor Aruba Central-managed switches and APs via API (not just SNMP); extends coverage to cloud-managed wireless infrastructure.

## Modules and Add-Ons

| Module | Function |
|---|---|
| NPM (Network Performance Monitor) | Core device/interface monitoring; bandwidth, availability, latency |
| NCM (Network Configuration Manager) | Configuration backup, compliance checking, change detection |
| NTA (NetFlow Traffic Analyzer) | Flow-based traffic analysis; NetFlow/IPFIX/J-Flow/sFlow |
| SAM (Server Application Monitor) | Application and server monitoring; process, service, URL checks |
| IPAM (IP Address Manager) | IP address tracking, DHCP/DNS integration, subnet management |
| NTA (Network Topology Mapper) | Network diagram auto-generation from SNMP/CDP/LLDP |

## Monitoring Methods

- **SNMP v1/v2c/v3** — Primary device polling; configurable polling interval (60s default); bulk OID walks for efficiency.
- **WMI** — Windows system monitoring (CPU, memory, processes, events) without agent.
- **ICMP** — Availability and response time; ping-based polling.
- **API Monitoring** — REST API integration for cloud-managed infrastructure (Aruba Central, Meraki).
- **Syslog** — Inbound syslog message collection and alerting; correlated with node events.
- **Trap Receiver** — SNMP trap collection; triggers alerts and log entries.

## NetPath

- **NetPath** — Hop-by-hop path analysis for TCP services (HTTP, TCP port, etc.).
- Discovers and visualizes network path between probe (agent or NPM server) and destination.
- Detects path changes, latency anomalies, and routing shifts over time.
- Works across internet paths, not just internal network.

## PerfStack

- **PerfStack** — Cross-domain performance correlation dashboard.
- Drag-and-drop metrics from NPM, NTA, SAM, APM onto a shared timeline.
- Visually correlates network events with application performance degradation.
- Time-synchronized across all metrics.

## Custom Alerts and Orion SDK

- Alert engine: condition-based (threshold, baseline deviation, state change); multi-condition AND/OR logic.
- Notification methods: email, SMS, Slack, PagerDuty, webhook, script execution, SNMP trap.
- **Orion SDK** — REST API (`/SolarWinds/InformationService/v3/Json/`) for querying all Orion data using SWQL (SolarWinds Query Language, SQL-like).

---

# ThousandEyes

## Overview

Cisco ThousandEyes is a **synthetic monitoring** and **internet intelligence** platform acquired by Cisco in 2020. It provides external-in and inside-out visibility using distributed agent probes.

## Agent Types

### Cloud Agents
- Deployed and managed by Cisco ThousandEyes in **1,057+ globally distributed vantage points** across 271 cities.
- Hosted in Tier 1/2/3 ISPs, broadband providers, and major cloud provider regions.
- No customer infrastructure required; immediate coverage for external monitoring.
- Used for: testing website reachability from customer geographies, monitoring SaaS applications from diverse ISPs.

### Enterprise Agents
- Customer-deployed software probes on Linux VMs, Docker containers, Cisco routers/switches, or physical appliances.
- Placed at: data centers, branch offices, cloud VPCs/VNets.
- Enable: internal application testing, LAN performance measurement, cross-site path visualization.
- Natively integrated within **Cisco SD-WAN (IOS XE)** routers; no separate deployment required.
- Support SD-WAN overlay and underlay path visibility, including WAN Quality metrics.

### Endpoint Agents
- Browser-based lightweight agents installed on employee laptops/desktops.
- Capture: real user experience data, WiFi quality, VPN performance, application response times.
- Activated by scheduled tests or browser extension triggers (user visits monitored URL).
- Privacy controls: only collect during business hours or defined time windows.

## Test Types

| Test Type | Layer | What It Measures |
|---|---|---|
| HTTP Server | L7 | Availability, response code, response time, cert validity |
| Page Load | L7 | Full browser page load including JS/CSS/images (Chromium) |
| Web Transaction | L7 | Multi-step scripted browser journeys; Selenium-like |
| DNS Server | L7 | Resolution time, answer correctness, DNSSEC validation |
| DNS Trace | L7 | Full recursive resolution path tracing |
| BGP | L3 | BGP route reachability, prefix visibility, path changes |
| Network (ICMP/TCP) | L3/L4 | Latency, jitter, packet loss, MTU |
| API | L7 | REST API endpoint testing with assertions |
| Voice (RTP) | L4/L7 | MOS score, jitter, packet loss for VoIP |

## Path Visualization

- **End-to-end path mapping** — Visualizes every network hop from agent to destination including ISP routers.
- **Hop-level latency and loss** — Identifies exactly which hop introduces degradation.
- **BGP route overlay** — Correlates BGP path data with traceroute-derived forwarding path.
- **SD-WAN overlay/underlay** — For Enterprise Agents on Cisco SD-WAN, shows both the application overlay tunnel and the underlying WAN path.
- Historical path comparison: detect path changes that correlate with performance degradation.

## Internet Insights

- **Macro-level outage detection** — Aggregates data from Cloud Agent network to identify ISP, CDN, DNS provider, and cloud outages.
- **Coverage Packages** — Licensed by provider type and geography: ISP, CDN, DNS, IaaS, SECaaS, UCaaS × North America, EMEA, APAC, LATAM.
- **Outage Timeline** — When an outage occurs, Internet Insights provides affected network prefixes, impacted providers, and geographic scope.
- **Global Insights Bundle** — Unlocks all packages in a single license.
- Critical for distinguishing "our network is down" from "the internet is having a bad day."

## Cisco XDR Integration

- ThousandEyes data feeds into **Cisco XDR** (Extended Detection and Response) for network context enrichment.
- **Cisco Secure Access Experience Insights** (powered by ThousandEyes) provides endpoint health, network stability, and SaaS performance in unified XDR console.
- Accelerates triage: network path data surfaces alongside security event timeline.

---

# Kentik

## Overview

Kentik is a SaaS-based **network observability** platform combining flow analytics, BGP intelligence, synthetic monitoring, and AI-powered analysis. Targets telcos, large enterprises, and cloud providers.

## Flow Analytics

- **Ingestion** — NetFlow v5/v9, IPFIX, sFlow, VPC Flow Logs (AWS, GCP, Azure), eBPF agent.
- **Scale** — Designed for billions of flow records per day; proprietary time-series datastore with sub-second ad-hoc query response.
- **Enrichment** — Each flow enriched with BGP AS path, geographic data (MaxMind), RPKI validation, IANA port registry, custom tags (device, site, customer).
- **Retention** — Full-granularity flow data retained for months (not sampled/rolled up).

## Kentik NMS (SNMP Monitoring)

- Layer added on top of flow analytics to correlate device-level metrics with traffic data.
- SNMP polling for device CPU, memory, interface utilization, error counters.
- **Kentik Map** — Automated network topology map combining device metrics and BGP/flow data; geographic and logical views.

## DDoS Detection and Defense

- Baseline traffic profiling per customer/network/application using ML.
- Real-time anomaly detection when traffic exceeds normal baseline (volume, packet rate, protocol distribution).
- **Automated mitigation triggers** — Integration with A10 Networks, Radware, RTBH (Remote Triggered Black Hole) for automated traffic blocking.
- DDoS alerts with attack classification: volumetric, protocol (SYN flood), application layer.

## BGP Monitoring

- **BGP route collector** — Receives full table feeds from customer routers and public route collectors.
- Route change detection and alerting (prefix hijack, route leak, RPKI ROA validation failures).
- **BGP path analysis** — Correlate route changes with traffic shifts observed in flow data.
- Visibility into prefix reachability from global vantage points.

## AI Insights

- **"What Changed?"** ML analysis — Automatically identifies top contributing dimensions to a traffic anomaly (which ASN, application, src/dst prefix, device).
- **Saved Queries and Dashboards** — Custom metrics views with alerting thresholds.
- **Natural Language Queries** — AI-powered interface allows conversational queries on flow data.

## Kentik API

- REST API: ad-hoc query execution, device management, alert management, tag management.
- 2025 updates: Alerting Public API v6 (policies endpoint), NMS IP address search.
- Webhooks for alert notifications to external systems.
- Python SDK available; Terraform provider for device/tag management.

---

# LibreNMS

## Overview

LibreNMS is the leading open-source network monitoring system, forked from Observium in 2013. Fully community-maintained, Apache 2.0 licensed.

## Architecture

- **Web Application** — PHP/Laravel; MySQL/MariaDB backend; Redis for caching.
- **Polling Daemons** — `poller.php` or `lnms polling:poll`; distributed polling via multiple pollers.
- **RRDtool** — Round-robin database for time-series metric storage; Whisper/InfluxDB optional.
- **Alert Engine** — Continuous rule evaluation against device/interface/sensor data.

## SNMP Auto-Discovery

- Discovers devices via SNMP, CDP, LLDP, BGP peer discovery, ARP table walks, and manual subnet scanning.
- **Device Library** — 10,000+ device definitions with custom OIDs, graphs, and health checks.
- Automatically applies appropriate graphs, health sensors, and alerts based on device sysObjectID.
- IPv6 discovery supported.

## Alerting

- Alert rules: SQL-like syntax querying LibreNMS data model (devices, ports, services, sensors).
- **Transports** — Email, Slack, Microsoft Teams, PagerDuty, OpsGenie, Telegram, VictorOps, JIRA, webhook, and more.
- Alert escalation policies; per-group notification routing.
- Scheduled maintenance windows suppress alerts during planned outages.

## API

- REST API covers: device management (add/edit/delete), alert management, graphs, data retrieval, port status.
- Used for CMDB synchronization, automated device onboarding, custom dashboards.
- Python library `librenms-api-client` available.

## Custom Dashboards

- **Overview dashboards** — Device availability, alerts, traffic summaries.
- **Custom dashboard builder** — Drag-and-drop widgets: graphs, maps, tables, alert lists.
- **Grafana Integration** — LibreNMS as Grafana data source; full Grafana dashboard ecosystem.

## Oxidized Integration

- **Oxidized** — Open-source network configuration backup tool (inspired by RANCID).
- **LibreNMS → Oxidized** — LibreNMS provides device list to Oxidized automatically; no duplicate inventory maintenance.
- Oxidized connects to devices via SSH/Telnet, retrieves running configuration, commits to Git.
- Git-backed config history: diff configs across time, detect unauthorized changes.
- Supports 300+ device types; extensible with Ruby scripts.

## Distributed Polling

- Multiple `poller` instances on separate servers; devices assigned to specific pollers.
- Enables horizontal scale for large networks (tens of thousands of devices).
- `rrdcached` for RRDtool write performance at scale.

---

# PRTG Network Monitor

## Overview

PRTG (Paessler) is a commercial network monitoring platform for SMB to large enterprise. Unique sensor-based pricing model. Available as on-premises (Windows) and **PRTG Hosted Monitor** (SaaS).

## Sensor-Based Model

- Everything monitored is a **sensor** — one sensor = one data point on one device.
- **Free tier** — Up to 100 sensors at no cost; suitable for small environments.
- **Licensed tiers** — 500, 1000, 2500, 5000, XL1, XL5 sensors; unlimited available.
- Each interface, CPU core, URL check, flow source, or custom metric = one sensor.

## Auto-Discovery

- PRTG scans IP ranges via SNMP/ICMP/WMI; automatically creates devices and suggests sensors.
- Device templates apply pre-defined sensor sets to device types (Cisco router, Windows server, VMware host).
- Saves initial configuration time for new deployments.

## Sensor Types

| Category | Sensor Examples |
|---|---|
| SNMP | Interface traffic, CPU load, custom OID, SNMP trap receiver |
| WMI | Windows CPU, memory, disk, process, event log, service |
| NetFlow/IPFIX/sFlow | Traffic flow analysis (separate Flow sensor license tier) |
| Packet Sniffing | Protocol-level visibility on monitored interface (RSPAN feed) |
| HTTP/HTTPS | Availability, response time, content check, SSL cert expiry |
| Ping/ICMP | Basic reachability and latency |
| Custom | Python/PowerShell script sensor; REST API JSON sensor; SSH sensor |

## Maps and Dashboards

- **Maps** — Visual network diagrams with live sensor status overlays; drag-and-drop editor; publish as web page.
- **Custom dashboards** — configurable overview screens; Geo Maps for global deployments.
- **Reports** — Scheduled PDF/HTML reports for availability, SLA, and capacity data.

## Notifications

- Email, SMS, push notification (PRTG app), Slack, Microsoft Teams, PagerDuty.
- **Escalation chains** — Notify on-call 1 → on-call 2 → manager if not acknowledged within N minutes.
- **Notification triggers** — Threshold, state change (up/down/warning), volume anomaly.

## PRTG Hosted Monitor (SaaS)

- Cloud-hosted version; Paessler manages infrastructure, updates, and backups.
- **Remote Probes** — On-premises PRTG probe agents connect to cloud core; monitor internal devices without exposing SNMP to internet.
- Same sensor model as on-premises; same UI.
- Reduces operational burden; suitable for organizations without dedicated monitoring infrastructure.

## Comparison Summary

| Feature | SolarWinds NPM | ThousandEyes | Kentik | LibreNMS | PRTG |
|---|---|---|---|---|---|
| Model | On-prem (SaaS add-ons) | SaaS | SaaS | On-prem (self-host) | On-prem + SaaS |
| Primary Strength | Enterprise NMS, SQL-backed | Synthetic + Internet path | Flow analytics + BGP | Open source, broad device support | Sensor model, SMB to enterprise |
| Flow Analytics | NTA module | No (synthetic only) | Core capability | Yes (basic, NfSen) | Yes (separate sensor) |
| Synthetic Monitoring | NetPath (limited) | Core capability | Yes (included) | No | HTTP/ping sensors |
| API | Orion SDK (SWQL) | REST + streaming | REST + webhooks | REST | REST |
| Cost | High (module licensing) | High (consumption) | High (enterprise) | Free (hosting cost) | Sensor-based; affordable |

---

## References

- [SolarWinds NPM 2025.2 Release Notes](https://documentation.solarwinds.com/en/success_center/npm/content/release_notes/npm_2025-2_release_notes.htm)
- [ThousandEyes Enterprise Agents](https://www.thousandeyes.com/product/enterprise-agents)
- [ThousandEyes + Cisco SD-WAN Integration](https://www.thousandeyes.com/solutions/cisco-sdwan)
- [Kentik Release Notes 2025](https://kb.kentik.com/docs/release-notes-2025)
- [Kentik NetFlow Analyzer](https://www.kentik.com/kentipedia/netflow-analyzer/)
- [LibreNMS Oxidized Integration](https://docs.librenms.org/Extensions/Oxidized/)
- [PRTG vs LibreNMS Comparison](https://network-king.net/prtg-vs-librenms/)
