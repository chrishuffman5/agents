# Cisco Wireless Architecture Reference

## C9800 WLC Platform Architecture

### IOS-XE Foundation

The Catalyst 9800 WLC runs IOS-XE, the same operating system as Catalyst 9000 switches and ISR/ASR routers. This means:
- Full routing protocol support (OSPF, BGP, EIGRP) directly on the WLC
- VRF support for management and data plane separation
- QoS policies (MQC model) applied at the WLC for centralized mode traffic
- ACL and security features identical to other IOS-XE platforms
- YANG model-driven configuration via NETCONF (port 830) and RESTCONF (HTTPS)
- gRPC/gNMI streaming telemetry for real-time monitoring

### Management Plane vs Data Plane

- **Management Plane**: Handles GUI (HTTPS), CLI (SSH/console), API (NETCONF/RESTCONF), logging, SNMP, RADIUS communication, AP management (CAPWAP control). Runs on general-purpose CPU.
- **Data Plane**: Handles client traffic forwarding in centralized mode. CAPWAP data tunnels terminate here. Hardware-assisted forwarding on physical appliances; software forwarding on C9800-CL virtual.

### CAPWAP (Control And Provisioning of Wireless Access Points)

CAPWAP is the tunnel protocol between APs and WLC:
- **Control tunnel**: UDP 5246, DTLS-encrypted. Carries AP management, configuration, client authentication events.
- **Data tunnel**: UDP 5247, optionally DTLS-encrypted. Carries client data frames in centralized mode.
- **Discovery**: APs discover WLC via (in order): DHCP option 43, DNS (CISCO-CAPWAP-CONTROLLER.localdomain), broadcast, primary/secondary/tertiary WLC configured on AP.
- **Join process**: AP sends join request -> WLC authenticates AP (certificate or MAB) -> WLC pushes configuration -> AP downloads firmware if version mismatch -> AP enters RUN state.
- **Keepalive**: Heartbeat between AP and WLC (default 30 seconds, dead interval 5 missed = 150 seconds).

### HA (High Availability)

**SSO (Stateful Switchover):**
- Active + Standby WLC pair with RP (Redundancy Port) connection
- Full configuration, client state, and AP state replicated to standby
- On failover: standby assumes active role; clients and APs remain connected (Nonstop Wireless)
- Failover time: sub-second for control plane, <1 second for client sessions
- Requires identical hardware model and IOS-XE version

**N+1 HA:**
- One backup WLC serves as failover for multiple primary WLCs
- APs configured with primary, secondary, and tertiary WLC addresses
- On primary WLC failure, APs rejoin to secondary/tertiary WLC
- APs undergo full CAPWAP join process (clients disconnected briefly during rejoin)
- Lower cost than SSO but longer failover (30-60 seconds AP rejoin time)

## Deployment Mode Details

### Centralized (Local Mode) Internals

Traffic flow:
```
Client -> AP (802.11 frame) -> CAPWAP data tunnel -> WLC -> Wired network
```
- AP performs 802.11 frame encapsulation/decapsulation
- AP performs radio-level QoS (WMM)
- WLC performs VLAN assignment, ACL enforcement, QoS marking, client policy
- WLC is a Layer 2/3 forwarding device for all client traffic
- Scalability limited by WLC data plane capacity

### FlexConnect Internals

**Local Switching mode:**
```
Client -> AP (802.11 frame) -> AP switches to local VLAN -> Wired network (local)
Control: AP ←─ CAPWAP control ─→ WLC (management only)
```
- AP performs VLAN assignment and local forwarding
- Authentication: AP sends RADIUS request via WLC (or direct if configured), caches result
- ACL enforcement: AP applies ACLs locally (downloaded from WLC)
- Standalone mode: If WAN link to WLC fails, AP uses cached authentication state

**FlexConnect Groups:**
- Group APs that share the same local VLANs and switching behavior
- VLAN-to-SSID mapping configured per FlexConnect group
- CCKM/OKC key caching shared within a FlexConnect group for fast roaming
- Efficient image download: one AP in group downloads image, others pull from that AP

### SD-Access Fabric Mode Internals

```
Client -> AP (802.11 frame) -> VXLAN encapsulation -> Fabric Edge switch -> Fabric
Control: AP ←─ CAPWAP control ─→ C9800 WLC (fabric wireless controller)
```
- WLC acts as control plane only (no data plane involvement for client traffic)
- AP registers client MAC with fabric control plane (LISP)
- Fabric edge switch handles VXLAN encapsulation and SGT tagging
- Policy enforced by fabric (SGACLs) rather than WLC ACLs
- Catalyst Center provisions fabric topology, VNs (Virtual Networks), SGTs

### Embedded WLC (EWC)

- WLC process runs on a Catalyst 9100 series AP
- Managed via standard C9800 GUI/CLI (same IOS-XE interface)
- Primary EWC elected automatically; standby EWC provides HA
- Supports up to 100 APs in EWC cluster (varies by AP model)
- Ideal for retail stores, small branches, or sites without WLC hardware

## AP Model Details

### CW9100 Series (Wi-Fi 6)
- 2.4 GHz + 5 GHz radios
- 2x2:2 or 4x4:4 MIMO (model dependent)
- Suitable for standard enterprise density
- PoE powered (802.3at)

### CW9160 Series (Wi-Fi 6E)
- Tri-band: 2.4 GHz + 5 GHz + 6 GHz
- CW9166: Flagship 6E AP; 4x4:4 on 5 GHz and 6 GHz
- 6 GHz support requires IOS-XE 17.9+
- Requires 802.3bt (PoE++) for full tri-band operation at maximum power
- AFC support for 6 GHz standard power mode

### CW9170 Series (Wi-Fi 7)
- Tri-band: 2.4 GHz + 5 GHz + 6 GHz
- 802.11be support with MLO (Multi-Link Operation)
- CW9178: Highest performance; 4x4:4 per radio with Wi-Fi 7
- Requires IOS-XE 17.15+ for Wi-Fi 7 features
- 320 MHz channel support in 6 GHz
- 4096-QAM support
- Requires 802.3bt (PoE++) for full operation

### CW9186 (Wi-Fi 7 Outdoor)
- All-band outdoor AP with Wi-Fi 7
- IP67 rated for outdoor/harsh environments
- External antenna options for directional deployment
- Stadium, warehouse, outdoor campus use cases

## DNA Spaces Architecture

DNA Spaces is a cloud-based platform that connects to C9800 WLCs:
- **Data flow**: WLC sends NMSP (Network Mobility Services Protocol) or telemetry data to DNA Spaces cloud
- **Location engine**: Triangulates client position using RSSI reports from multiple APs
- **Floor maps**: Imported from Catalyst Center or configured directly in DNA Spaces
- **APIs**: REST APIs for location data, presence analytics, IoT telemetry
- **Privacy**: Supports opt-in/opt-out via MAC randomization detection and consent mechanisms

### Meraki Cloud Monitoring
- C9800 WLC can send telemetry to Meraki Dashboard
- Provides unified monitoring for mixed Catalyst + Meraki environments
- Read-only visibility from Meraki Dashboard (configuration remains on C9800)

## AI Network Analytics

Available via Catalyst Center or cloud:
- **Anomaly detection**: Identifies unusual patterns in RF, client onboarding, application performance
- **Guided remediation**: AI-driven root cause analysis with suggested fixes
- **Baseline comparison**: Compares current KPIs against historical norms per site/AP group
- **Predictive insights**: Anticipates capacity issues, RF degradation trends
