# FortiOS Architecture Reference

## FortiASIC Hardware

### NP7 Network Processor
- Max throughput: 200 Gbps (dual 100GigE)
- IPv4/IPv6 offloading, IPsec VPN, GTP, CAPWAP, VXLAN, multicast, NAT, DoS protection
- Hyperscale Firewall license adds: hardware session establishment, CGNAT, hardware logging, HA sync
- Models: FortiGate 400F/G, 600F, 700G, 900G, 1000F, 1800F, 2600F, 3700F, 4200F, 4400F, 4800F

### NP7Lite
- All NP7 features except Hyperscale; no fragmented packet defrag; max 40 Gbps

### SP5/SoC5 Content Processor
- SSL/TLS acceleration, IPS pattern matching, AV scanning, application ID, web filtering
- Works in tandem with NP: NP handles L3/L4; SP handles L7

### NP Offload Restrictions
Sessions that CANNOT be NP-offloaded:
- Proxy-based UTM inspection
- Session helpers/ALGs (FTP, DNS, SIP, H.323, PPTP)
- PPPoE interfaces
- Software-switch traffic (unless `intra-switch-policy = explicit`)
- Fragmented packets (NP7Lite)

## Packet Flow

### Software Path (no NP offloading)
```
Ingress -> NIC -> Kernel -> DoS Policy -> Policy Lookup -> Session Table -> NAT -> UTM Inspection (IPS/Proxy) -> Routing -> Egress
```

### Fast Path (NP-offloaded)
After CPU session establishment:
```
Ingress NIC -> NP7 -> Session Lookup (hardware) -> NAT/TTL -> Egress NIC
```
NP bypasses CPU entirely for established offloaded sessions.

### UTM: Flow-Based
- IPS engine with DFA pattern matching; single-pass; no buffering
- Lower latency, higher throughput
- SSL deep inspection requires "Inspect All Ports"

### UTM: Proxy-Based
- Full content buffering and reconstruction
- SSL proxy: terminates + re-encrypts
- Content inspection order: VoIP > DLP > Anti-Spam > Web Filter > AV > ICAP
- Higher detection, higher latency

## Session Table
- Tracks 5-tuple: src IP, dst IP, src port, dst port, protocol
- Flags: offloaded, helper, dirty, npu-offload-failed
- Session helpers for related connections (FTP data, SIP RTP)
- Commands: `diagnose sys session list`, `diagnose sys session stat`

## VDOMs
- Independent firewall instances on single hardware
- Each VDOM: own interfaces, routing, policies, profiles, VPN
- Root VDOM: manages global settings
- Split-Task VDOM: management (root) + traffic (FG-traffic)
- Inter-VDOM: VDOM link virtual interfaces
- Per-VDOM mode: NAT or Transparent

## Security Fabric
- FortiGate (root) + FortiSwitch + FortiAP + FortiManager + FortiAnalyzer + FortiClient EMS + FortiSandbox + FortiNAC
- HTTPS/WebSocket fabric connections
- Security ratings aggregated across fabric
- Fabric connectors for cloud (AWS, Azure, GCP), SDN, IPAM
- Automation stitches (triggers + actions) across fabric members

### FortiLink (FortiSwitch Management)
- Dedicated trunk between FortiGate and FortiSwitch
- FortiSwitch VLANs appear as FortiGate interfaces
- Policies at FortiGate control FortiSwitch port traffic
- 802.1X NAC integration

## High Availability

### FGCP (FortiGate Clustering Protocol)
**Active-Passive:**
- Primary processes all traffic; secondary monitors heartbeat
- Virtual MAC addresses; gratuitous ARP on failover
- Failover time: under 1 second
- Session sync over heartbeat or dedicated interface

**Active-Active:**
- Primary receives traffic and redirects to secondaries
- NP can redirect subsequent packets to cluster members
- Asymmetric routing possible

**FGCP Requirements:**
- Identical hardware models and firmware versions
- Dedicated heartbeat interfaces
- Management interface for independent device access

### FGSP (Session Life Support Protocol)
- Active-active without virtual MAC/IP
- Each unit independently makes forwarding decisions
- Synchronizes TCP sessions and IPsec tunnels
- Used with ECMP routing or external load balancers
- Can nest inside FGCP clusters

## SD-WAN Architecture
- **Zones**: Group of SD-WAN member interfaces; used in policies
- **Members**: Physical/VPN interfaces with priority and cost
- **Performance SLA**: Health monitors (ping, http, dns, tcp-echo, twamp, ftp)
- **Rules**: Traffic steering (manual, best-quality, lowest-cost, maximize-bandwidth)
- **ADVPN**: Hub-spoke IPsec with dynamic spoke-to-spoke shortcuts
- ADVPN 2.0 (7.6+): enhanced shortcut triggering

## VXLAN
- VXLAN interfaces with VNI and remote VTEP IP
- UDP/4789 encapsulation
- NP7 offloads VXLAN for hardware-accelerated forwarding
- Used for DC interconnect, multi-site fabric, SD-WAN overlay
