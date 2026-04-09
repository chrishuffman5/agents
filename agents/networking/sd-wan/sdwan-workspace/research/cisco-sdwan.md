# Cisco Catalyst SD-WAN — Deep Dive Reference

> Last updated: April 2026 | Covers controller release 20.18.x / IOS-XE 17.12–17.18

---

## 1. Architecture Overview

Cisco Catalyst SD-WAN (formerly Cisco SD-WAN / Viptela) is a cloud-delivered or on-premises WAN solution built around a separation of management, control, and data planes. The four logical planes map to discrete components.

### 1.1 Control Plane Components

| Old Name | Current Name | Role |
|---|---|---|
| vManage | SD-WAN Manager | Management & orchestration |
| vSmart | SD-WAN Controller | Control-plane intelligence / OMP |
| vBond | SD-WAN Validator | Orchestration & NAT traversal |
| vEdge / ISR / ASR / C8K | WAN Edge router | Data-plane forwarding |

**SD-WAN Manager (vManage)**
- Single-pane-of-glass NMS; provides GUI, REST API (NETCONF southbound to devices), and dashboard analytics
- Manages device onboarding, feature/device templates, policy distribution, software upgrades, and certificate provisioning
- Can run as a single instance or a cluster (minimum 3 nodes) for HA and scale; cluster uses an internal Elasticsearch + Cassandra data layer
- Communicates to controllers and edge routers via DTLS/TLS on port 12446 (NETCONF)
- Release 20.18 added a global search across devices, templates, policies, and logs; guided Day-0 task flow

**SD-WAN Controller (vSmart)**
- Runs OMP (Overlay Management Protocol); acts as route reflector for the overlay
- Maintains TLS sessions to all WAN Edge devices; distributes routes, TLOCs, keys, and policy
- Applies centralized control policy before advertising routes
- Failure does NOT break existing data-plane tunnels (BFD sessions stay up); no new route/policy changes until recovery
- Scale: 1 vSmart per 2,000 WAN Edge devices; up to 6 vSmart instances in large deployments

**SD-WAN Validator (vBond)**
- First point of contact for any new WAN Edge device
- Performs authentication (whitelist of serial numbers via SD-WAN Manager) and facilitates NAT traversal (STUN-like behavior)
- Advertises vSmart and vManage addresses to authenticating edge devices
- Must have a public IP (or 1:1 NAT); deployed in DMZ
- Port 12346 UDP (DTLS)

**WAN Edge Routers**
- Cisco Catalyst 8000 series (C8200, C8300, C8500), ISR 1000/4000, ASR 1000, Catalyst 8000V (virtual)
- Run IOS-XE with SD-WAN persona; data-plane forwarding, IPsec tunnels, BFD probes, policy enforcement
- Connect to SD-WAN Manager (NETCONF), SD-WAN Controller (OMP/DTLS), and SD-WAN Validator (initial auth)

---

## 2. Control Plane — OMP (Overlay Management Protocol)

OMP is a TCP-based protocol (similar in design to BGP) that runs inside DTLS/TLS sessions between WAN Edge devices and the SD-WAN Controller. It carries all overlay routing information.

### 2.1 OMP Route Types

| Route Type | Description |
|---|---|
| OMP routes (vRoutes) | Overlay prefixes (IPv4/IPv6) learned from connected/static/OSPF/BGP |
| TLOC routes | Transport Locators — describe how to reach a WAN Edge tunnel endpoint |
| Service routes | Advertise services (firewall, IDS, etc.) for service chaining |

### 2.2 TLOC (Transport Locator)

A TLOC uniquely identifies a WAN Edge tunnel endpoint and is a 3-tuple:
```
TLOC = (System-IP, Color, Encapsulation)
```
- **System-IP**: Loopback-like identifier (router-id), never changes
- **Color**: Logical label for a transport (mpls, biz-internet, public-internet, private1–6, lte, etc.)
- **Encapsulation**: ipsec or gre

TLOCs are advertised via OMP to vSmart, which distributes them to all peers. A WAN Edge builds IPsec tunnels to remote TLOCs based on the TLOC routes received.

### 2.3 OMP Best Path Selection

vSmart uses OMP path selection (similar to BGP best-path) considering:
1. Originator (prefer routes originated locally)
2. Admin distance
3. OMP preference attribute
4. TLOC preference
5. System-IP (tie-break)

### 2.4 OMP Graceful Restart

WAN Edge devices cache OMP routes locally. During vSmart unavailability, existing data-plane state is preserved for the graceful-restart timer (default 12 hours).

---

## 3. Data Plane — IPsec Tunnels and BFD

### 3.1 IPsec Tunnel Formation

- WAN Edge devices form full-mesh IPsec tunnels to all remote TLOCs (per color pairing)
- Tunnel mode: IPsec ESP in tunnel mode
- Cipher: AES-256-GCM (default in modern releases), AES-128-CBC legacy
- Keys are distributed by SD-WAN Manager; zero-touch key rotation
- Each tunnel is uniquely identified by the (local-TLOC, remote-TLOC) pair

### 3.2 BFD (Bidirectional Forwarding Detection)

BFD probes run inside every IPsec tunnel and serve two purposes:
1. **Tunnel liveness** — detect tunnel failures (sub-second, configurable hello/multiplier)
2. **Path quality measurement** — BFD hello packets measure latency, jitter, and packet loss per tunnel every BFD interval (default 1 second, configurable)

BFD sessions report per-tunnel statistics to the AAR engine every polling interval (default 10 minutes; configurable down to 1 minute).

```
Default BFD timers:
  hello-interval: 1000 ms
  multiplier: 7  (7s before declaring down)
  app-route polling-interval: 600 seconds
  app-route multiplier: 6  (use last 6 polling intervals for SLA calc)
```

---

## 4. Application-Aware Routing (AAR)

AAR steers application traffic to the tunnel that best satisfies defined SLA thresholds.

### 4.1 SLA Classes

SLA classes define acceptable thresholds:
```
sla-class VOICE
  loss    1      ! percent
  latency 150    ! milliseconds
  jitter  30     ! milliseconds
```
Up to 8 SLA classes configurable (from 17.2.1r). From 17.15.1a, threshold values were adjusted for improved accuracy.

### 4.2 App-Route Policies

App-route policies (centralized, pushed from SD-WAN Manager) match traffic and assign SLA class:
```
app-route-policy ENTERPRISE-AAR
  sequence 10
    match
      app-list VOICE-APPS
    action
      sla-class VOICE
        preferred-color mpls
  sequence 20
    match
      app-list CRITICAL-DATA
    action
      sla-class DATA-SLA
        preferred-color mpls biz-internet
```

### 4.3 AAR Decision Logic

1. Match application (DPI-based, NBAR2 app recognition on IOS-XE edge)
2. Look up assigned SLA class thresholds
3. Evaluate all tunnels' BFD-measured metrics against thresholds
4. Select tunnel(s) satisfying SLA; prefer color specified (if any)
5. If no tunnel satisfies SLA: configurable fallback — use best available or drop

### 4.4 Enhanced AAR (EAAR) — 17.12+

EAAR (Enhanced Application-Aware Routing) introduced in IOS-XE 17.12 adds:
- Per-flow rerouting (not just per-session)
- SLA violation detection at 1-second granularity
- Sub-second path switching on MPLS/private transports
- Application-aware load balancing across multiple SLA-compliant paths

---

## 5. Policy Framework

Cisco Catalyst SD-WAN has three policy planes:

### 5.1 Centralized Policy (vSmart)

Applied at vSmart; affects control plane or data plane across the entire fabric.

**Control Policy** — manipulates OMP route advertisements:
- Route filtering (accept/reject prefixes by site, TLOC, tag)
- Traffic engineering (preferred TLOC, TLOC lists)
- Hub-and-spoke topologies (restrict full-mesh to hub-spoke)
- Service insertion (route traffic through firewall service nodes)

**Data Policy** — applied at WAN Edge ingress/egress:
- QoS marking, shaping, queuing
- NAT (DIA — Direct Internet Access)
- ACL / packet filtering
- Mirror / sFlow

### 5.2 Localized Policy (WAN Edge)

Policies applied locally on the WAN Edge router:
- QoS scheduling queues
- ACLs (in/out on interfaces)
- Route policy (manipulate routing table entries)
- VPN membership (which VPNs exist on the device)

### 5.3 App-Aware Routing Policy

A specialized centralized data policy; covered in Section 4.

### 5.4 Policy Hierarchy

```
Centralized Control Policy (vSmart distributes)
      ↓
Centralized Data Policy (pushed to WAN Edge)
      ↓
Localized Policy (per-device)
      ↓
App-Route Policy (per-device, driven by centralized AAR config)
```

---

## 6. Templates

Templates eliminate CLI-by-CLI device management; all configs are version-controlled in SD-WAN Manager.

### 6.1 Feature Templates

Modular building blocks for individual configuration features:
- System (system-ip, site-id, hostname, NTP, DNS)
- VPN (VPN 0 = transport, VPN 512 = management, VPN 1+ = service)
- Interface (WAN/LAN interface type, IP addressing, tunnel params)
- BGP, OSPF, EIGRP
- BFD, OMP
- Security (UTM chain)
- SNMP, Syslog, AAA

### 6.2 Device Templates

A device template assembles multiple feature templates into a full device configuration. Each device template is assigned to one or more physical devices.

```
Device Template: BRANCH-C8300
  ├── Feature Template: SYSTEM-BASE
  ├── Feature Template: VPN0-MPLS
  ├── Feature Template: VPN0-INET
  ├── Feature Template: VPN1-LAN
  ├── Feature Template: BGP-PE
  └── Feature Template: SECURITY-UTM
```

### 6.3 CLI Add-On Templates

When feature templates don't cover a specific CLI command, CLI add-on templates inject raw IOS-XE CLI into the device config without overriding the template framework. Useful for edge cases and platform-specific commands.

### 6.4 Configuration Groups (20.12+)

Configuration Groups (replacing device templates in newer deployments) use a more modular, profile-based approach aligned with Catalyst Center concepts. Feature profiles group related settings; a configuration group bundles feature profiles and applies to device tags or specific devices.

---

## 7. Security

### 7.1 Unified Threat Defense (UTD)

UTD runs as a containerized security stack on IOS-XE WAN Edge routers (C8000 series). Components:

| Feature | Description |
|---|---|
| Enterprise Firewall (ZBFW) | Zone-based stateful firewall, app-aware |
| IPS/IDS | Snort-based intrusion prevention/detection; signature updates from Talos |
| URL Filtering | Category/reputation-based web filtering (Cisco Talos cloud lookup) |
| Advanced Malware Protection (AMP) | File reputation via SHA-256 hash lookup; retrospective detection |
| DNS-layer Security | DNS sinkholing, malicious domain blocking (Cisco Umbrella integration) |
| TLS/SSL Decryption | Inline TLS inspection for UTD modules |

### 7.2 Security Policy Integration

- UTD policies are configured via SD-WAN Manager security templates and pushed to WAN Edge devices
- Policies reference VPN/zone pairs; traffic inspected inline on the WAN Edge
- Centralized security dashboard in SD-WAN Manager shows IPS alerts, URL filtering hits, AMP verdicts

### 7.3 SASE Integration

- Cisco Umbrella SIG (Secure Internet Gateway): Branch traffic tunneled to Umbrella PoPs via IPsec for cloud-based inspection
- Integration configured directly in SD-WAN Manager; traffic steered based on app-route policies
- Supports Umbrella DNS Security, CASB, and SWG

---

## 8. SD-WAN Manager Versions and IOS-XE Compatibility

### 8.1 Controller Software Track

| Release | Track | Status | Notes |
|---|---|---|---|
| 20.12.x | Extended Maintenance (LTS) | Active | Long-term support; recommended for stable production |
| 20.15.x | Extended Maintenance (LTS) | Active | LTS; next stable long-term release |
| 20.18.x | Standard Maintenance (current) | Active | Latest; major new features; 3rd in sequence will become LTS |

### 8.2 IOS-XE WAN Edge Versions

| IOS-XE Release | Paired Controller | Track | Notes |
|---|---|---|---|
| 17.12.x | 20.12.x | LTS | Stable pair; recommended for production LTS |
| 17.13.x | 20.13.x | Standard | |
| 17.14.x | 20.14.x | Standard | |
| 17.15.x | 20.15.x | LTS | SLA threshold improvements; EAAR enhancements |
| 17.16.x | 20.16.x | Standard | |
| 17.17.x | 20.17.x | Standard | |
| 17.18.x | 20.18.x | Current | Wi-Fi 7 profile support; NWPI security alert tracing |

**Version alignment rule**: Controller major.minor version must match IOS-XE release (20.18 pairs with 17.18). Controller can be 1 version ahead of edge routers during upgrades.

---

## 9. Catalyst Center Integration

Catalyst Center (formerly DNA Center) integrates with SD-WAN Manager:
- Unified intent-based policy management across LAN (Catalyst switching) and WAN (SD-WAN)
- SD-Access fabric sites can extend to WAN edges; consistent group-based policy (SGT) from campus to branch
- Catalyst Center pushes SD-WAN policy for consistent QoS end-to-end
- Network Hierarchy (site/area/building/floor) synced between products
- Assurance data from both platforms surfaced in unified dashboard

---

## 10. Multi-Cloud (Cloud OnRamp)

### 10.1 Cloud OnRamp for IaaS (AWS / Azure / GCP)

- Automates deployment of Cisco Catalyst 8000V (C8000V) virtual routers in cloud VPCs/VNets
- SD-WAN Manager orchestrates tunnel establishment from WAN Edge branches to cloud instances
- AWS: Supports VPC attachments, Transit Gateway (TGW) integration; 20.18 adds discover/connect to existing TGWs
- Azure: vNet integration, Virtual WAN hub support
- Application-aware routing steers cloud-bound traffic to optimal tunnel

### 10.2 Cloud OnRamp for SaaS

- Monitors performance of SaaS apps (Office 365, Salesforce, Webex, etc.) from each branch transport
- Automatically steers branch traffic to the best-performing gateway (DIA, regional hub, cloud gateway)
- Uses active probing to SaaS endpoints; per-transport SLA scoring

### 10.3 Cloud OnRamp for Colocation

- Automates deployment of network services (routing, SD-WAN, firewall) in colo facilities (Equinix, CyrusOne, etc.)
- Integrates with Cisco SD-WAN Gateway (C8000V) deployments in colo

---

## 11. Troubleshooting

### 11.1 Real-Time Monitoring (SD-WAN Manager)

- **Device Dashboard**: Overall device health, tunnel status, CPU/memory, interface stats
- **Real-Time Statistics**: Live counters (packets, bytes, drops) via on-demand polling to device
- **Events**: Syslog-level events from all devices; filterable by type, severity, site

### 11.2 Application Route Statistics

In SD-WAN Manager → Monitor → Network → App Route Statistics:
- Per-tunnel BFD metrics: latency, jitter, loss
- SLA compliance per tunnel (pass/fail against each SLA class)
- Historical 24h / 7d / 30d graphs
- Useful for diagnosing application performance problems

CLI on WAN Edge:
```
show sdwan app-route statistics
show sdwan app-route stats remote-system-ip 10.0.0.5
show sdwan bfd sessions
show sdwan bfd summary
```

### 11.3 BFD Session Troubleshooting

```
! Show all BFD sessions and state
show sdwan bfd sessions
! Detailed per-session metrics
show sdwan bfd history
! Check OMP sessions to vSmart
show sdwan omp peers
show sdwan omp routes
show sdwan omp tlocs
```

### 11.4 Tunnel Statistics

```
show sdwan tunnel statistics
show sdwan tunnel sla-class
show sdwan control connections
show sdwan control connections-history
```

### 11.5 Network-Wide Path Insights (NWPI)

NWPI (available in SD-WAN Manager) provides end-to-end path tracing:
- Visual topology from source branch to destination
- Per-hop latency, jitter, loss overlaid on topology
- 20.18: Automatic security alert tracing — links IPS/UTD hits to specific path segments
- Exportable trace data (JSON/CSV) for ticketing system integration

### 11.6 Radioactive Tracing (Debugging)

For deep packet-level debug on IOS-XE WAN Edge without impacting production:
```
debug platform condition feature sdwan-data-plane submode all level verbose
debug platform condition start
! Collect output...
debug platform condition stop
```

### 11.7 Common Issues and Checks

| Symptom | First Check |
|---|---|
| WAN Edge not connecting | vBond reachable? `show sdwan control connections-history` |
| Tunnels not forming | TLOC color mismatch? NAT traversal? `show sdwan tunnel statistics` |
| Application on wrong path | AAR policy applied? BFD metrics meeting SLA? `show sdwan app-route stats` |
| Policy not taking effect | Template activated? Policy pushed from vManage? Centralized policy has site-list? |
| Throughput degraded | BFD jitter/loss elevated? Check `show sdwan bfd sessions`; interface drops? |

---

## 12. Key CLI Reference (IOS-XE WAN Edge)

```bash
# System status
show sdwan system status
show version

# Control plane
show sdwan control connections
show sdwan omp peers
show sdwan omp routes vpn 1
show sdwan omp tlocs
show sdwan certificates validity

# Data plane
show sdwan tunnel statistics
show sdwan ipsec outbound-connections
show sdwan ipsec inbound-connections

# Policy
show sdwan policy from-vsmart
show sdwan policy app-route-policy-filter

# Interface and transport
show sdwan interface
show interfaces GigabitEthernet 0/0/0

# Events and logs
show sdwan events
show logging | include SDWAN
```

---

## References

- [Cisco Catalyst SD-WAN Solution Overview](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/sdwan-xe-gs-book/system-overview.html)
- [Cisco Catalyst SD-WAN AAR Configuration Guide](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/policies/ios-xe-17/policies-book-xe/application-aware-routing.html)
- [Enhanced AAR](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/policies/ios-xe-17/policies-book-xe/m-enhanced-application-aware-routing.html)
- [Centralized Policy Guide](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/policies/ios-xe-17/policies-book-xe/centralized-policy.html)
- [Release 20.18 Notes](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/release/notes/20-18/control-comp-20-18-x.html)
- [Recommended Software Versions](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/215676-cisco-tac-and-bu-recommended-sd-wan-soft.html)
- [SD-WAN Manager API 20.18](https://developer.cisco.com/docs/sdwan/sd-wan-services-overview/)
- [Cisco SD-WAN Design Guide](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/SDWAN/cisco-sdwan-design-guide.html)
- [AAR Deployment Guide](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/SDWAN/cisco-sdwan-application-aware-routing-deploy-guide.html)
- [Migrate to Wi-Fi 7 with Cisco Wireless](https://www.cisco.com/c/en/us/support/docs/wireless/catalyst-9800-series-wireless-controllers/223061-migrate-to-wi-fi-7-and-6ghz.html)
