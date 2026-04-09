# Wireless Platforms — Deep Dive Reference

> Last updated: April 2026 | Cisco IOS-XE 17.15/17.18 | Aruba AOS 10.x | Juniper Mist (2026)

---

## Part 1: Cisco Wireless

---

## 1. Cisco Catalyst 9800 WLC

The Catalyst 9800 series replaced the legacy AIR-CT5508 and AIR-CT8540 with an IOS-XE based platform, bringing full programmability, model-driven telemetry, and nonstop operation to wireless.

### 1.1 Hardware Models

| Model | Form Factor | Scale | Notes |
|---|---|---|---|
| C9800-L | 1RU small | Up to 500 APs / 5,000 clients | Branch/small campus |
| C9800-40 | 1RU | Up to 2,000 APs / 32,000 clients | Mid-size campus |
| C9800-80 | 2RU | Up to 6,000 APs / 64,000 clients | Large campus |
| C9800-CL | Virtual (cloud) | Up to 6,000 APs | Runs on ESXi/KVM/AWS/Azure |
| C9800 Embedded | Switch-embedded | Catalyst 9000 switch | SD-Access fabric only |
| C9800 AP Embedded | AP-embedded | Catalyst 9100 APs | Ultra-small sites |

### 1.2 Deployment Modes

**Centralized (Local Mode)**
- APs tunnel all traffic (management + data) back to WLC via CAPWAP
- WLC handles authentication, policy enforcement, RF management
- Typical for campus deployments with adequate WAN bandwidth

**FlexConnect**
- APs maintain CAPWAP control tunnel to WLC but switch data locally at branch
- Two sub-modes per WLAN:
  - **Local Switching**: Data frames switched locally at AP; WLC only sees control traffic
  - **Central Switching**: Data frames tunneled to WLC (legacy behavior)
- Survives WAN outage: AP caches authentication state (standalone mode)
- C9800-CL public cloud: FlexConnect-only (local switching mode required)
- FlexConnect VLAN mapping: SSID → local VLAN per AP/AP-group

**Fabric / SD-Access**
- Controller embedded on Catalyst 9000 switch; APs fabric-mode
- Traffic encapsulated in VXLAN; switches handle forwarding
- Consistent group-based policy (SGT) across wired and wireless
- Requires Cisco Catalyst Center (DNA Center) for fabric provisioning

**Embedded WLC (EWC)**
- WLC software embedded on Catalyst 9100 APs
- One AP is the "primary" WLC; supports small site (up to 100 APs in cluster)
- Seamless failover to standby EWC

### 1.3 IOS-XE Based WLC

Unlike legacy AireOS WLCs, C9800 runs IOS-XE, providing:
- YANG/NETCONF/RESTCONF management
- gRPC/gNMI streaming telemetry
- Rolling AP upgrades (upgrade APs without WLC downtime)
- Nonstop Wireless (NSF): Clients maintain connectivity during WLC HA failover
- Full CLI parity with IOS-XE routing features (VRF, OSPF, BGP, QoS)

---

## 2. Wi-Fi Standards (802.11ax/be)

### 2.1 Wi-Fi 6 (802.11ax — 2.4/5 GHz)

- **OFDMA**: Orthogonal Frequency Division Multiple Access — subdivides channels into resource units (RU); serves multiple clients simultaneously per OFDM symbol
- **MU-MIMO**: Up to 8×8 downlink, 8×8 uplink MU-MIMO
- **BSS Coloring**: Reduces co-channel interference by tagging frames with BSS Color
- **Target Wake Time (TWT)**: IoT/mobile clients negotiate wake schedules; reduces power consumption
- **1024-QAM**: Higher spectral efficiency (25% improvement over 256-QAM)
- Max theoretical PHY rate: 9.6 Gbps (tri-band)

### 2.2 Wi-Fi 6E (802.11ax — 6 GHz)

- Same 802.11ax technology extended to 6 GHz band (5.925–7.125 GHz)
- 1.2 GHz of additional spectrum; up to 59 non-overlapping 20 MHz channels (US)
- Enables 80 MHz and 160 MHz channels with minimal co-channel interference
- Requires WPA3 (no legacy WPA2 in 6 GHz)

### 2.3 Wi-Fi 7 (802.11be)

- Operates in 2.4 GHz, 5 GHz, and 6 GHz simultaneously
- **Multi-Link Operation (MLO)**: Client aggregates multiple bands simultaneously for higher throughput and lower latency; seamless band steering
- **4096-QAM**: Further spectral efficiency improvement
- **320 MHz channels**: In 6 GHz band (2x improvement over Wi-Fi 6E 160 MHz)
- **16×16 MU-MIMO**: Doubled from Wi-Fi 6
- **Enhanced MU-MIMO and OFDMA**: Multi-resource unit (MRU) operation
- Max theoretical PHY rate: 46 Gbps

**Security Requirements for Wi-Fi 7:**
- WPA3-Enterprise: AES(CCMP128) + 802.1X-SHA256 or FT+802.1X
- WPA3-Personal: GCMP256 + SAE-EXT-KEY and/or FT+SAE-EXT-KEY
- WPA2 not permitted in Wi-Fi 7 certified deployments

**IOS-XE 17.18 Wi-Fi 7 Configuration:**
- New 802.11be Profile under Configuration > Tags & Profiles > 802.11be
- Per-SSID and per-radio activation control
- MLO peer negotiation managed by WLC

### 2.4 Cisco AP Families

| Family | Wi-Fi Standard | Bands | Use Case |
|---|---|---|---|
| CW9100 | Wi-Fi 6 (802.11ax) | 2.4 / 5 GHz | Cost-effective enterprise indoor |
| CW9160/9162/9164/9166 | Wi-Fi 6E | 2.4 / 5 / 6 GHz | High-density, modern enterprise |
| CW9170/9172/9176/9178 | Wi-Fi 7 (802.11be) | 2.4 / 5 / 6 GHz | High-performance enterprise, MLO |
| CW9186 | Wi-Fi 7 outdoor | All bands | Outdoor deployments |

---

## 3. RRM (Radio Resource Management)

RRM is the C9800's automated RF optimization system.

### 3.1 RRM Functions

| Function | Description |
|---|---|
| Dynamic Channel Assignment (DCA) | Automatically assigns non-overlapping channels to minimize interference |
| Transmit Power Control (TPC) | Adjusts AP transmit power to maintain optimal cell overlap |
| Coverage Hole Detection (CHD) | Increases power or alerts when coverage gaps detected |
| Load-Based CAC | Limits new associations when channel utilization exceeds threshold |
| CleanAir | Classifies non-Wi-Fi interference (microwave, BT, ZigBee) spectrum sources |
| Flexible Radio Assignment (FRA) | Dual-radio APs can dedicate one radio to 5 GHz when 2.4 GHz is underutilized |

### 3.2 RRM Groups

APs can be assigned to RRM groups; within a group, WLC coordinates RF decisions globally (cluster RF management). Custom RRM triggers and thresholds are configurable per group.

---

## 4. Client Troubleshooting

### 4.1 Radioactive Tracing

Radioactive Tracing (RAC) provides detailed client event logging without broad debug impact:

```
Catalyst Center OR WLC GUI:
Troubleshooting → Radioactive Trace
  → Enter client MAC address
  → Enable trace → reproduce issue → download logs
```

CLI equivalent:
```
debug wireless mac <client-mac> {monitor-time 300}
show wireless client detail mac <client-mac>
show wireless client mac <client-mac> detail
```

### 4.2 Common Wireless Troubleshooting Commands

```
show ap summary
show wireless client summary
show wireless client detail mac <mac>
show ap dot11 5ghz summary
show wireless stats client delete reason
show wireless stats ap join summary
show capwap client rcb
```

---

## 5. Cisco DNA Spaces and AI Analytics

**DNA Spaces**: Cloud-based location analytics and IoT services platform
- Location tracking (floor map visualization, client/asset heatmaps)
- Presence analytics (dwell time, repeat visits)
- IoT device profiling and management
- API for third-party integrations

**Cisco AI Network Analytics** (Catalyst Center / cloud):
- Anomaly detection: Identifies unusual patterns in RF, client onboarding, application performance
- Guided remediation: AI-driven root cause analysis with suggested fixes
- Baseline comparison: Compares current KPIs against historical norms per site/AP group

**Meraki Cloud Monitoring**:
- Catalyst 9800 WLC can send telemetry to Meraki Dashboard for cloud visibility
- Unified dashboard for Meraki and Catalyst environments in the same organization

---

## Part 2: Aruba Wireless

---

## 6. Aruba AOS 10 (Cloud-Managed)

AOS 10 is Aruba's cloud-first architecture managed via HPE Aruba Networking Central (GreenLake platform).

### 6.1 Architecture

- **Aruba Central**: Cloud management plane; provisions APs, gateways, switches
- **AOS 10 AP**: Runs AOS 10 firmware; can operate in AP-only mode or with gateway
- **Aruba Gateway (SD-WAN/Security)**: On-premises gateway for traffic processing, SD-WAN, firewall
- **No on-premises controller required**: Control plane moves to cloud (unlike AOS 8)

### 6.2 AOS 10 vs AOS 8

| Feature | AOS 10 | AOS 8 |
|---|---|---|
| Management | Aruba Central (cloud) | On-prem Mobility Controller |
| Control Plane | Cloud-based | MC-based (on-prem) |
| Data Plane | Local at AP or Gateway | Tunnel to MC (centralized default) |
| SD-WAN | Integrated into Gateway | Separate SD-WAN license |
| Licensing | Subscription via Central | Per-feature licenses |

### 6.3 AOS 10 Deployment Options

- **AP Only (no gateway)**: Simple deployments; limited security features; data locally bridged
- **AP + Gateway**: Full SD-WAN, ZTNA, stateful firewall, DPI; recommended for enterprise
- **Micro-Branch (AP with embedded gateway)**: Small sites; AP performs gateway functions

---

## 7. Aruba AP Families

| Series | Wi-Fi Standard | Notes |
|---|---|---|
| AP 5xx (515, 535, 555, 575) | Wi-Fi 6 / 6E | Enterprise indoor; 802.11ax |
| AP 730 | Wi-Fi 7 (802.11be) | Flagship; 2.4/5/6 GHz; MLO support |
| AP 6xx | Wi-Fi 6E outdoor | Outdoor/ruggedized |
| AP 3xx | Wi-Fi 6 | Value tier; small-medium office |

---

## 8. AirMatch

AirMatch is Aruba's cloud-based AI RF optimization (analogous to Cisco RRM):
- Runs in Aruba Central; analyzes RF environment across all sites
- Computes globally optimal channel and power assignments
- Sends plan to APs once per day (off-peak) to minimize reconfigurations
- Considers 5 GHz and 6 GHz independently
- More holistic than traditional RRM: looks at interference between all APs in the network, not just neighbors

---

## 9. ClearPass Integration

Aruba ClearPass is the NAC (Network Access Control) / policy server:
- **Authentication**: 802.1X (EAP-TLS, PEAP, EAP-TTLS), MAC Authentication Bypass (MAB), Guest portal
- **Authorization**: Returns RADIUS attributes (VLAN, role, bandwidth limit, ACL) to Aruba gateway/AP
- **Profiling**: Identifies device type via DHCP fingerprint, MAC OUI, HTTP User-Agent, SNMP
- **Posture**: Checks endpoint health (antivirus, patch level) via FortiClient/Aruba agent
- **OnBoard**: BYOD certificate enrollment (automated certificate provisioning)
- **Guest Management**: Self-registration, sponsor-approval, social login, usage policies

---

## 10. Dynamic Segmentation and Tunneled Node

### 10.1 Dynamic Segmentation

Dynamic segmentation enforces consistent policy across wired and wireless regardless of connection point:
- User connects (wireless or wired)
- ClearPass assigns a user/device role
- Consistent firewall policy applied based on role, regardless of port/SSID
- Policy follows the user across wired/wireless roaming

### 10.2 Tunneled Node (Wired)

Tunneled Node extends SD-WAN/security services to wired edge ports:
- Wired switch ports configured as "tunneled nodes"
- Traffic from wired clients tunneled to Aruba Gateway for policy enforcement
- Enables consistent ZTNA / firewall policies for wired devices managed from Central

### 10.3 Aruba Central APIs

Aruba Central exposes comprehensive REST APIs:
```
GET  /monitoring/v2/aps          # AP list and status
GET  /monitoring/v2/clients      # Client details
POST /configuration/v1/devices   # Push configuration
GET  /analytics/v2/rogue_aps     # Rogue AP detection
```
Python SDK: `pycentral` — official Aruba library for Central API automation

---

## Part 3: Juniper Mist

---

## 11. Mist AI Cloud Platform

Juniper Mist is an AI-native cloud networking platform for wireless, wired, and WAN. Acquired by Juniper in 2019.

### 11.1 Architecture

- **Mist Cloud**: SaaS management plane; runs Mist AI engine
- **Mist APs**: Intelligent APs that maintain cloud connection for management; local forwarding
- **Mist Edge**: On-premises gateway for tunneling, ZTNA, and security services
- **Wired Assurance**: EX Series switch management via Mist cloud
- **WAN Assurance**: SD-WAN/SSR (Session Smart Router) management via Mist cloud

### 11.2 Marvis AI Assistant

Marvis is the conversational AI assistant embedded in Mist:
- Natural language queries: "Why is the Wi-Fi slow at Building 3 Floor 2?"
- Root cause analysis across wireless, wired, and WAN domains
- Proactive alerts and guided remediation (Marvis Actions)
- **Agentic workflows (2025-2026)**: Marvis can autonomously investigate and resolve issues spanning wired/wireless/WAN without human intervention for routine problems

### 11.3 Marvis Minis

Marvis Minis are virtual network sensors that digitally simulate user connections:
- Proactively test connectivity end-to-end (association, DHCP, DNS, gateway, application)
- Identify failures before real users are affected
- Can monitor custom applications (custom application name/endpoint configured per Mini)
- Network Operations Center (NOC) users can view Org Insights dashboard (single-pane-of-glass) showing all Minis status

---

## 12. Mist AP Families

| Family | Wi-Fi Standard | Notes |
|---|---|---|
| AP12 | Wi-Fi 6 | Entry-level indoor |
| AP21 | Wi-Fi 6 | Indoor general purpose |
| AP32 | Wi-Fi 6E | Indoor 3-band; 2.4/5/6 GHz |
| AP43/45 | Wi-Fi 6E | High-density indoor |
| AP63/64 | Wi-Fi 6E outdoor | Outdoor/ruggedized |
| AP41 | Wi-Fi 6 | General indoor enterprise |

---

## 13. Mist Edge

Mist Edge is an on-premises appliance (physical or virtual) providing:
- **Tunnel termination**: APs tunnel SSID traffic to Mist Edge for local security enforcement
- **ZTNA Connector**: Zero-trust access for private applications (on-prem or cloud-hosted)
- **RadSec Proxy**: Secure RADIUS proxy for authentication
- **Guest isolation**: Separate internet path for guest SSIDs

---

## 14. Wired Assurance (EX Series)

Wired Assurance brings Mist AI to Juniper EX Series access layer switches:
- **Zero-Touch Provisioning**: EX switches auto-claim to Mist cloud via DHCP/DNS; no manual config
- **AI-driven insights**: Port anomalies, STP issues, PoE problems detected automatically
- **Key health metrics**: Switch firmware compliance, AP-switch affinity (AP connects to expected switch), PoE compliance, missing VLANs
- **Marvis Actions**: Suggested fixes for detected switch issues
- **CableSim**: Virtual cable testing — identifies cable/transceiver issues without physical testing

---

## 15. WAN Assurance

WAN Assurance integrates Juniper's Session Smart Routing (SSR, formerly 128T) into the Mist AI cloud:
- **SD-WAN management**: SSR routers managed from Mist dashboard alongside wireless
- **Application-aware routing**: Per-application SLA steering
- **AI operations**: Mist AI detects WAN anomalies, links them to wireless/wired correlations
- **MTTR reduction**: The primary value proposition — faster mean time to repair via AI correlation across all network layers
- **Marvis Minis in WAN context**: Simulate user flows through WAN paths to proactively detect issues

---

## 16. Service Levels / SLAs

Mist defines Service Level Expectations (SLEs) as measurable KPIs per network domain:

**Wireless SLEs:**
| SLE | Description |
|---|---|
| Successful Connects | % of connection attempts that succeed |
| Time to Connect | How long client association + DHCP + auth takes |
| Throughput | Per-client throughput vs. expected baseline |
| Coverage | Signal strength adequate for service |
| Roaming | Successful 802.11r/k/v fast roaming events |
| Capacity | Channel utilization vs. threshold |
| AP Availability | AP uptime percentage |

**Wired SLEs:**
- Switch availability
- PoE compliance
- AP affinity
- VLAN compliance

Each SLE has a classifiers breakdown — shows which root causes (interference, wrong channel, low RSSI, etc.) are contributing to SLE failures.

---

## 17. Location Services and BLE

Mist APs include Bluetooth Low Energy (BLE) radios for:
- **Asset Tracking**: BLE tags on equipment tracked in real-time on floor maps
- **Wayfinding**: Turn-by-turn indoor navigation (integration with third-party apps)
- **Proximity-based services**: Trigger notifications/workflows when assets/people enter zones
- **Virtual BLE (vBLE)**: Mist's patented directional BLE technology using software-defined antenna arrays for sub-meter accuracy

**Wi-Fi Location**: Also available; combines RSSI triangulation with AI for 3–5 meter accuracy.

---

## References

- [Cisco Catalyst 9800 Wi-Fi 7 Operations (17.15)](https://www.cisco.com/c/en/us/td/docs/wireless/controller/9800/17-15/config-guide/b_wl_17_15_cg/m_wi-fi-7_operations.html)
- [Migrate to Wi-Fi 7 and 6 GHz with Cisco](https://www.cisco.com/c/en/us/support/docs/wireless/catalyst-9800-series-wireless-controllers/223061-migrate-to-wi-fi-7-and-6ghz.html)
- [Understand FlexConnect on Catalyst 9800](https://www.cisco.com/c/en/us/support/docs/wireless/catalyst-9800-series-wireless-controllers/213945-understand-flexconnect-on-9800-wireless.html)
- [Cisco 9800 Best Practices](https://www.cisco.com/c/en/us/td/docs/wireless/controller/9800/technical-reference/c9800-best-practices.html)
- [AOS 10 Architecture Overview](https://arubanetworking.hpe.com/techdocs/aos/aos10/components/overview/)
- [Aruba Central AOS 10 Key Features](https://arubanetworking.hpe.com/techdocs/central/2.5.8/content/aos10x/aos10x-overview/keyfeatures.htm)
- [Juniper Mist Wired Assurance](https://www.juniper.net/us/en/products/cloud-services/wired-assurance.html)
- [Juniper WAN Assurance](https://www.juniper.net/us/en/products/cloud-services/wan-assurance.html)
- [Mist February 2026 Updates](https://www.juniper.net/documentation/us/en/software/mist/product-updates/2026/february-16th-2026-updates.html)
- [HPE Juniper Mist Innovations 2026](https://www.channele2e.com/news/hpe-advances-agentic-ai-native-networking-with-new-juniper-mist-innovations)
