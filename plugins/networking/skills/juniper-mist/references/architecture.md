# Juniper Mist Architecture Reference

## Mist AI Cloud Platform

### Cloud Architecture

Mist is an AI-native cloud networking platform built on microservices:

**Infrastructure:**
- Hosted on AWS with multi-region availability
- Microservices architecture: each function (monitoring, config, AI/ML, analytics, firmware) scales independently
- Real-time event streaming: APs and switches stream telemetry every second to cloud
- ML pipeline: dedicated compute for AI/ML model training and inference
- Global clusters: NA, EU, APAC regions for data sovereignty compliance

**Data Flow:**
```
AP/Switch -> HTTPS (443) -> Mist Cloud Load Balancer -> Event Processing
                                                     -> Time-Series DB (metrics)
                                                     -> ML Pipeline (anomaly detection)
                                                     -> Configuration Engine
                                                     -> API Gateway (REST/Webhook)
```

**Tenancy Model:**
- Organization (Org): Top-level tenant; contains all sites, devices, users
- Site: Physical location; contains APs, switches, WAN devices
- Site Group: Logical grouping of sites for configuration inheritance
- Network Template: Reusable network configuration applied to sites/site groups

### Device Management Lifecycle

**Zero-Touch Provisioning (ZTP):**
1. Device powers on (AP or EX switch)
2. Device obtains IP via DHCP
3. Device resolves Mist cloud address via DNS or DHCP option
4. Device establishes HTTPS connection to Mist cloud
5. Admin claims device to Org/Site via Mist dashboard (or pre-claimed via activation code)
6. Mist pushes site configuration to device
7. Device begins operation (forwarding traffic, streaming telemetry)

No pre-staging, no console access, no manual configuration required.

**Firmware Management:**
- Mist cloud maintains firmware repository for all supported devices
- Auto-upgrade: devices can be configured to auto-update to latest stable
- Scheduled upgrade: admin sets maintenance window; Mist stages firmware and reboots during window
- Compliance tracking: dashboard shows firmware version distribution across all devices

## Marvis AI Engine

### Architecture

Marvis is not a chatbot -- it is a purpose-built AI engine for network operations:

**ML Models:**
- Anomaly detection: Identifies deviations from learned baselines (per-site, per-AP, per-client)
- Root-cause analysis: Correlates symptoms across wireless, wired, and WAN to identify single root cause
- Predictive analytics: Forecasts capacity issues and performance degradation
- Natural language understanding: Processes free-text queries about network status

**Data Sources:**
- Wireless telemetry: client RSSI, SNR, data rate, retry rate, roaming events, authentication events
- Wired telemetry: switch port status, PoE, LLDP/CDP neighbors, STP topology, VLAN config
- WAN telemetry: SSR link status, application SLA metrics, path latency/jitter/loss
- Infrastructure telemetry: AP/switch CPU, memory, temperature, uptime

### Marvis Actions Categories

| Category | Examples |
|---|---|
| AP Health | AP offline, AP rebooting, AP high utilization |
| Connectivity | DHCP failure, DNS failure, authentication failure, gateway unreachable |
| RF | High co-channel interference, non-Wi-Fi interference, coverage hole |
| Switch | Port flapping, PoE failure, STP topology change, missing VLAN |
| WAN | Link down, SLA violation, path failover, high latency |
| Security | Rogue AP, unauthorized client, anomalous traffic pattern |

### Agentic AI (2025-2026)

Marvis agentic workflows represent the next evolution:
- **Autonomous investigation**: Marvis initiates multi-step investigation without human prompt
- **Cross-domain remediation**: Identifies issue in wireless, traces to wired cause, suggests switch fix
- **Automated resolution**: For routine issues (AP reboot, channel change), Marvis can act autonomously with admin approval
- **Escalation**: Complex issues escalated to human operator with full diagnostic context

## Marvis Minis Architecture

### Virtual Sensor Model

Marvis Minis run as virtual clients on Mist APs:
```
AP Hardware -> Dedicated Mini radio slice -> Simulates full client lifecycle:
  1. Association to configured SSID
  2. Authentication (802.1X, PSK, or open)
  3. DHCP (obtain IP address, measure response time)
  4. DNS (resolve configured domain, measure response time)
  5. Gateway reachability (ping default gateway)
  6. Application reachability (HTTP GET to configured URL)
```

### Mini Test Results

Each Mini test produces:
- Pass/Fail status for each step (association, auth, DHCP, DNS, gateway, app)
- Latency measurements for each step
- Error details for failed steps (timeout, rejection, unreachable)

Results feed into:
- SLE metrics (improve or degrade SLE scores based on Mini results)
- Marvis AI (anomaly detection uses Mini data as additional signal)
- Org Insights dashboard (NOC view of all Minis across all sites)

### Configuration Options
- **SSID selection**: Which SSID to test (one Mini per SSID per AP)
- **Authentication**: PSK, 802.1X (with test credentials), or open
- **Test interval**: How often to run the full test cycle
- **Custom application**: URL or IP to test for application-specific reachability
- **Alert threshold**: Trigger alert when Mini fails N consecutive tests

## Service Level Expectations (SLEs)

### SLE Architecture

SLEs are computed in the Mist cloud from real-time telemetry:

```
AP telemetry (per-client events) -> Cloud event processor -> SLE calculator
  -> Per-SLE metric (e.g., Successful Connects = 98.7%)
  -> Per-classifier breakdown (e.g., 0.8% DHCP timeout, 0.5% auth failure)
  -> Time-series storage for historical trending
  -> Dashboard visualization with drill-down
```

### Classifier Deep Dive

**Successful Connects classifiers:**
- Authentication failure (RADIUS reject, timeout, certificate error)
- DHCP failure (no response, pool exhaustion, relay misconfiguration)
- Association failure (AP reject, max client limit, 802.11 error)
- Network failure (VLAN misconfiguration, trunk issue on switch)

**Time to Connect classifiers:**
- Slow authentication (RADIUS server latency, complex EAP)
- Slow DHCP (DHCP server overloaded, relay delay)
- Slow DNS (DNS server unreachable or overloaded)

**Throughput classifiers:**
- Low RSSI (client too far from AP)
- High channel utilization (too many clients or interference)
- Low data rate (poor RF conditions forcing low modulation)
- Wi-Fi retry (interference causing retransmissions)

**Coverage classifiers:**
- Weak signal (inadequate AP density)
- Asymmetric signal (AP hears client but client cannot hear AP)

### SLE Thresholds
- Default thresholds provided by Mist (tuned from global telemetry data)
- Admin can customize thresholds per site or per SSID
- Example: set Successful Connects target to 99.5% for critical sites, 98% for general offices

## Mist Edge Architecture

### Deployment Model
```
AP -> IPsec/GRE tunnel -> Mist Edge (on-premises) -> Local network/WAN
                                                   -> ZTNA connector -> Private apps
                                                   -> RadSec -> RADIUS server
                                                   -> Guest isolation -> Internet
```

### Mist Edge Models
- **Physical appliance**: Dedicated hardware for high-throughput environments
- **Virtual appliance**: VM on ESXi/KVM for flexible deployment
- **Clustered**: Multiple Mist Edge instances for HA and load balancing

### Mist Edge Functions

**Tunnel Termination:**
- APs establish IPsec or GRE tunnels to Mist Edge
- Per-SSID tunnel configuration (corporate tunneled, guest bridged)
- Mist Edge decapsulates and forwards traffic to local VLAN or WAN
- Centralized policy enforcement point without on-premises controller

**ZTNA (Zero Trust Network Access):**
- Mist Edge acts as application proxy for private resources
- Clients authenticate via Mist identity; access granted per-application
- No full network access (VPN replacement for specific applications)
- Integration with IdP (Okta, Azure AD, Google Workspace) for identity

**RadSec Proxy:**
- Mist Edge receives RADIUS from APs and forwards to on-premises RADIUS/NPS/ClearPass
- RADIUS encapsulated in TLS (RadSec) between AP and Mist Edge
- Simplifies firewall rules (single Mist Edge IP instead of all APs needing RADIUS access)

## Wired Assurance Architecture

### EX Switch Integration

Mist manages Juniper EX switches natively:
- Switches run Junos OS; Mist pushes configuration via NETCONF
- Switch telemetry streamed to Mist cloud (port status, traffic, PoE, LLDP, STP)
- Mist AI analyzes switch data alongside wireless data for cross-domain correlation

### Key Capabilities

**AP-Switch Affinity:**
- Mist tracks which AP connects to which switch port
- Detects AP-switch affinity violations (AP connected to wrong switch/port)
- Useful for validating physical cabling matches design documentation

**PoE Compliance:**
- Monitors PoE delivery per port
- Detects under-powered APs (e.g., AP requiring 802.3bt connected to 802.3at switch)
- Alerts when PoE budget is nearing capacity

**VLAN Compliance:**
- Verifies switch port VLANs match expected configuration (AP trunk VLANs, user access VLANs)
- Detects missing VLANs that would cause client connectivity failure

**CableSim:**
- Virtual cable testing via switch diagnostics
- Identifies cable length, quality, and potential faults
- Replaces physical cable tester for basic diagnostics

## WAN Assurance Architecture

### Session Smart Router (SSR) Integration

WAN Assurance manages Juniper SSR (formerly 128 Technology) routers:
- SSR uses session-based routing (not tunnel-based like traditional SD-WAN)
- Zero-trust WAN: no tunnels between sites; encrypted sessions with identity-based policy
- Application-aware routing: per-application SLA steering across MPLS, broadband, LTE links

### Cross-Domain Correlation

WAN Assurance enables Marvis to correlate across all three domains:
```
Issue: "Client Wi-Fi is slow"
Marvis investigation:
  1. Check wireless SLEs -> Throughput SLE degraded
  2. Check AP RF -> AP RF is healthy
  3. Check switch port -> Switch port healthy
  4. Check WAN path -> WAN link latency spike detected on SSR
  5. Root cause: WAN ISP latency issue affecting all traffic at this site
  6. Recommendation: SSR should failover to backup WAN link
```

## BLE and Location Architecture

### vBLE Technology

Mist's patented Virtual BLE (vBLE):
- Each Mist AP contains a 16-element BLE antenna array
- Software-defined beamforming creates directional BLE beams
- AP can determine angle-of-arrival for BLE tag signals
- Multiple APs triangulate BLE tag position with sub-meter accuracy
- No external BLE beacons needed (AP is the beacon and the sensor)

### Location Engine

Location computation:
```
BLE tag transmits -> Multiple APs receive (angle-of-arrival + RSSI)
  -> Location engine (cloud) computes position
  -> Position mapped to floor plan coordinates
  -> Real-time location stream via API/webhook
```

Accuracy:
- vBLE: 1-3 meter accuracy (with proper floor map and AP density)
- Wi-Fi: 3-5 meter accuracy (RSSI triangulation + AI)
- Hybrid (vBLE + Wi-Fi): Best accuracy for devices with both radios

### Location Data Access
- Mist dashboard: real-time floor map visualization with device positions
- REST API: query current and historical location data
- Webhooks: real-time position updates streamed to external systems
- Zone-based triggers: define geographic zones; receive events when devices enter/exit
- Integration: ServiceNow, Slack, custom applications via API/webhook
