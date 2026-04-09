# FortiOS Architecture Deep Reference

## 1. FortiASIC Hardware Architecture

### NP7 Network Processor
The NP7 is Fortinet's highest-performance network processor, designed for hardware-accelerated offloading of firewall and VPN sessions from the main CPU.

**Key specifications:**
- Maximum throughput: 200 Gbps using dual 100 GigE interfaces
- Supports IPv4 and IPv6 traffic offloading
- IPsec VPN encryption offloading including Suite B cipher suites
- GTP (GPRS Tunneling Protocol) traffic offloading
- CAPWAP (wireless) traffic offloading
- VXLAN traffic offloading
- Multicast traffic offloading
- NAT session setup: NAT44, NAT66, NAT64, NAT46
- DoS (Denial of Service) protection at line rate

**NP7 with Hyperscale Firewall license adds:**
- Hardware-based session establishment
- Carrier Grade NAT (CGNAT) operations
- Hardware-based logging
- HA synchronization at the processor level

**Models using NP7:** FortiGate 400F/401F, 400G/401G, 600F/601F, 700G/701G, 900G/901G, 1000F, 1800F, 2600F, 3700F, 4200F, 4400F, 4800F, FIM/FPM chassis modules.

### NP7Lite (used in mid-range platforms)
- Supports all NP7 features except Hyperscale Firewall (hardware sessions)
- Does not support fragmented packet defrag/reassembly
- Maximum throughput: 40 Gbps on a single 40GigE interface
- Architecturally superior to NP6 despite similar throughput ceiling

### NP6 / NP6XLite / NP6Lite (older generation)
| Feature | NP7 | NP6 |
|---------|-----|-----|
| Max throughput | 200 Gbps | 40 Gbps |
| Interface speed | 2x 100GigE | 4x 10Gbps |
| Hyperscale Firewall | Yes | No |
| GTP/VXLAN offload | Yes | No |
| DoS Protection | Yes | No |

### SP5 / SoC5 Content Processor
The SP5 (Security Processor 5) or SoC5 handles deep content inspection acceleration:
- SSL/TLS inspection acceleration
- Pattern matching for IPS signatures
- Antivirus scanning acceleration
- Application identification
- Web filtering categorization lookups

The content processor works in tandem with the NP for full-path acceleration: NP handles L3/L4 forwarding and session management; SP/SoC handles L7 content inspection.

### Traffic Offload Restrictions
Sessions that **cannot** be NP-offloaded include:
- Traffic requiring proxy-based security inspection
- Sessions using session-helpers or ALGs (FTP, DNS, SIP, PPTP)
- PPPoE interfaces and subordinate VLANs on PPPoE
- Traffic requiring NAT64/NAT46 in some configurations
- Software-switch traffic unless `intra-switch-policy` is set to `explicit`

---

## 2. Packet Flow Architecture

### Full Software Path (no NP offloading)
```
Ingress Interface → NIC Driver → Kernel Network Stack
→ DoS Policy Check
→ Policy Lookup (first packet only)
→ Session Table Check / Session Creation
→ NAT Processing
→ UTM/NGFW Inspection (IPS engine or Proxy)
→ Routing Decision / Forwarding
→ Egress Interface → NIC Driver → Wire
```

### Fast Path (NP-offloaded sessions)
After session establishment by CPU, subsequent packets follow the hardware fast path:
```
Ingress NIC → NP7 Processor
→ Session Table Lookup (NP hardware)
→ NAT / TTL Decrement
→ Egress NIC → Wire
```
The NP bypasses the CPU entirely for established, offloaded sessions.

### UTM Inspection: Flow-Based
- Handled entirely by the **IPS engine**
- Single-pass architecture with Direct Filter Approach (DFA) pattern matching
- Packets pass through without buffering (lower latency)
- IPS engine uses protocol decoders to determine applicable security modules
- Deep SSL inspection requires "Inspect All Ports" because flow-based IPS engine cannot determine carried protocol during SSL handshake
- Supports: IPS, Application Control, Web Filtering, DLP, Botnet check, AntiVirus, DNS filtering

### UTM Inspection: Proxy-Based
- Traffic is buffered and reconstructed in memory
- Full content caching for file-based scanning
- More thorough inspection, higher latency and resource usage
- SSL inspection: proxy terminates SSL client-side, re-encrypts to server
- Content inspection order: VoIP → DLP → Anti-Spam → Web Filtering → AntiVirus → ICAP
- Recommended for policies where preventing data leakage is critical

### Session Table
FortiOS maintains a stateful session table:
- Tracks 5-tuple: src IP, dst IP, src port, dst port, protocol
- Session flags: offloaded, helper, dirty, npu-offload-failed
- Session helpers (ALGs) track related connections (FTP data, SIP RTP, H.323)
- `get system session list` / `diagnose sys session list` for inspection
- `diagnose sys session stat` for session statistics

---

## 3. Virtual Domains (VDOMs)

### VDOM Modes
**No VDOM (single):** Default mode. One logical firewall instance. Root VDOM handles all traffic.

**Multi-VDOM mode:**
- Multiple VDOMs operate as independent firewall instances
- Each VDOM has its own: interfaces, routing table, firewall policies, security profiles, VPNs
- Root VDOM cannot be deleted; manages global settings and can be used for management or traffic
- Inter-VDOM communication uses VDOM links (virtual interfaces)
- Enable via: `config system global → set vdom-mode multi-vdom`
- Does not require reboot but logs out active sessions

**Split-Task VDOM mode:**
- Exactly two VDOMs: management VDOM (root) and traffic VDOM (FG-traffic)
- Management VDOM: handles FortiGate administration only, no user traffic
- Traffic VDOM: processes all user traffic, cannot be used for management
- Clean separation of management plane from data plane

### VDOM Operating Modes
Each VDOM independently operates in:
- **NAT mode** (default): FortiGate performs routing and NAT between interfaces
- **Transparent mode**: FortiGate acts as a Layer 2 bridge; no IP address changes; security scanning applied without affecting topology

### VDOM Resource Allocation
- `config vdom-property`: set per-VDOM resource limits (session table, policy count, etc.)
- Admin users can be scoped to specific VDOMs
- VDOM administrators cannot see other VDOMs' configuration

---

## 4. Security Fabric Architecture

### Fabric Components and Roles
| Component | Role |
|-----------|------|
| FortiGate | Root fabric member; policy enforcement; fabric root |
| FortiSwitch | LAN switching; managed via FortiLink; receives policies from FortiGate |
| FortiAP | Wireless access; managed via CAPWAP; integrated into fabric topology |
| FortiManager | Centralized management; policy/config deployment; SD-WAN orchestration |
| FortiAnalyzer | Log aggregation; analytics; FortiSOC; incident response |
| FortiClient/EMS | Endpoint agent; ZTNA tags; compliance telemetry |
| FortiSandbox | Advanced threat detection; integrated with AV profiles |
| FortiNAC | Network access control; device profiling |

### Fabric Communication
- FortiGate establishes fabric connections to upstream devices via HTTPS/WebSocket
- Downstream devices (FortiSwitch, FortiAP) connect to FortiGate as fabric root
- Security ratings are aggregated across the fabric and scored against best practices
- Fabric connectors integrate with public clouds (AWS, Azure, GCP), SDN controllers, and IPAM

### Security Fabric in Multi-VDOM Environments
- Fabric can be deployed across VDOMs; each VDOM can participate in fabric
- The management VDOM typically acts as the fabric root for multi-VDOM deployments
- Fabric topology view shows device hierarchy, connection status, and security posture
- Automation stitches (triggers + actions) work across fabric members

### FortiLink (FortiSwitch Management)
- Dedicated VLAN-capable trunk between FortiGate and FortiSwitch
- FortiSwitch VLANs appear as interfaces on FortiGate
- Policies applied at FortiGate control traffic flowing through FortiSwitch ports
- 802.1X NAC integration through FortiSwitch port policies

---

## 5. High Availability (HA)

### FGCP — FortiGate Clustering Protocol
The primary HA protocol for FortiGate clusters.

**Active-Passive (failover HA):**
- Primary unit processes all traffic; secondary monitors heartbeat
- Secondary holds a synchronized copy of session table, routing, and config
- Failover: if primary fails heartbeat checks, secondary assumes primary role
- Virtual MAC addresses move to new primary; gratuitous ARP sent
- Typical failover time: under 1 second for new sessions; ongoing sessions may be maintained if session sync is enabled

**Active-Active (load-balancing HA):**
- Primary receives all traffic and redirects sessions to secondaries via traffic interfaces
- Load balancing via session-pick-up; primary redirects based on configured algorithm
- All members share load; CPU-intensive UTM can be distributed
- NP processors can redirect subsequent session traffic to other cluster members
- Note: asymmetric routing may occur; both members must be in path for stateful inspection

**FGCP Heartbeat:**
- Dedicated HA heartbeat interfaces (recommended: dedicated physical links)
- Heartbeat interval and dead count configurable
- Management interface can be included for out-of-band management

**Session Synchronization:**
- TCP sessions synchronized over heartbeat or dedicated sync interface (`session-sync-dev`)
- UDP/ICMP session sync optional (session-pickup)
- Expectation sessions and NAT sessions optionally synchronized

### FGSP — FortiGate Session Life Support Protocol
Used for active-active deployments where two independent units (or clusters) share session state without FGCP:
- Synchronizes IPv4/IPv6 TCP sessions and IPsec tunnels by default
- Optional: UDP/ICMP sessions, expectation sessions, NAT sessions
- Each unit independently makes forwarding decisions
- If one FGSP peer fails, active sessions fail over to the surviving peer
- Commonly used with ECMP routing or external load balancers
- Does not use virtual MACs or virtual IPs; each unit has its own IP/MAC

---

## 6. VXLAN

FortiGate supports VXLAN (Virtual Extensible LAN) for overlay networking:
- VXLAN interfaces created with VNI (VXLAN Network Identifier) and remote VTEP IP
- Traffic encapsulated in UDP/4789
- NP7 offloads VXLAN traffic for hardware-accelerated forwarding
- Used for DC interconnect, multi-site fabric, and SD-WAN overlay scenarios
- Configuration: `config system vxlan` with interface, vni, dstport, remote-ip settings
- Supports both unicast and multicast VXLAN

---

## 7. SD-WAN Architecture

SD-WAN in FortiOS operates as an overlay network management layer:

### Core Components
- **SD-WAN Zones**: Group of SD-WAN member interfaces; virtual zone used in firewall policies
- **SD-WAN Members**: Physical/VPN interfaces included in SD-WAN (WAN1, WAN2, ISP1, ISP2, IPsec tunnels)
- **Performance SLA**: Health monitors measuring latency, jitter, packet loss per link
- **SD-WAN Rules (Service Rules)**: Traffic steering policies with strategies and SLA targets
- **Overlay Management**: ADVPN for auto-discovery hub-spoke shortcuts

### Data Plane Flow
```
Incoming packet → Match SD-WAN rule by destination/app/user
→ Evaluate strategy (manual / best-quality / lowest-cost / max-bandwidth)
→ Check SLA compliance of available members
→ Select egress member → Forward
```

### ADVPN (Auto-Discovery VPN)
- Hub-spoke IPsec with dynamic spoke-to-spoke shortcuts
- ADVPN 2.0 (7.6+): enhanced shortcut triggering for distinct underlay paths
- SD-WAN monitors shortcut link quality with dynamic ICMP probes
- Shortcuts established on-demand; removed when idle
- BGP over ADVPN distributes routing information dynamically

### SD-WAN Manager (FortiManager 7.6+)
- Dedicated SD-WAN management section in FortiManager
- Overlay templates replace deprecated SD-WAN Orchestrator
- Supports up to 4 hubs in overlay templates
- Traffic segmentation over single overlays via VRF
- FortiAI integration for intelligent SD-WAN configuration assistance
