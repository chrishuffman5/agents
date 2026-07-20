# SD-WAN Fundamentals

## Overlay / Underlay Architecture

SD-WAN decouples the logical network topology (overlay) from the physical transport (underlay). This separation is the foundation of all SD-WAN solutions.

### Underlay

The underlay is the physical transport network that carries encrypted SD-WAN tunnel traffic. Common underlay types:

| Transport | Characteristics | Cost | Typical Use |
|---|---|---|---|
| MPLS | Private, SLA-backed, low jitter | High | Voice, critical data, DC interconnect |
| Broadband (cable/fiber) | Best-effort, variable quality | Low | General business traffic, SaaS |
| DIA (Dedicated Internet Access) | Symmetrical, committed bandwidth | Medium | Internet-bound traffic, SaaS |
| LTE/5G Cellular | Wireless, variable latency | Medium-High | Backup, temporary sites, mobile |
| Satellite (LEO/GEO) | High latency (GEO) or moderate (LEO), limited bandwidth | High | Remote/rural sites |

**Transport diversity** is a core SD-WAN value proposition: combining multiple underlay types provides redundancy, load balancing, and cost optimization that a single MPLS circuit cannot achieve.

### Overlay

The overlay is a mesh of encrypted tunnels (typically IPsec) built between SD-WAN edge devices across the underlay transports. Key properties:

- **Encryption**: IPsec ESP (AES-256-GCM typical) secures all traffic regardless of underlay
- **Abstraction**: Applications see a single logical WAN, unaware of underlying transport
- **Dynamic topology**: Tunnels form and tear down based on traffic demand and health
- **Multi-path**: A single edge device can have tunnels across multiple underlays simultaneously

### Overlay Topology Models

**Full Mesh**: Every edge has direct tunnels to every other edge. Provides lowest latency for any-to-any communication but scales as O(n^2) tunnels.

**Hub-and-Spoke**: All spoke edges tunnel to one or more hub edges. Simple, scalable, but adds latency for spoke-to-spoke traffic (hairpin through hub).

**Dynamic Mesh (Hybrid)**: Hub-and-spoke as the base topology with on-demand direct tunnels between spokes when spoke-to-spoke traffic is detected. Combines scalability of hub-spoke with performance of full mesh.

- Cisco: Full-mesh is the default (all TLOCs connect); hub-spoke enforced via centralized control policy
- Fortinet: ADVPN provides dynamic mesh -- hub-spoke base with automatic shortcut tunnels

## Application-Aware Routing (AAR)

AAR is the defining capability that separates SD-WAN from traditional VPN overlays. It dynamically steers application traffic to the optimal transport path based on real-time performance measurements.

### Core Components

**Application Classification**

Traffic must be identified before it can be steered. SD-WAN platforms use Deep Packet Inspection (DPI) to classify applications:

- **Cisco**: NBAR2 (Network-Based Application Recognition) on IOS-XE edge routers. Identifies thousands of applications by L7 signatures, behavioral patterns, and protocol decoders.
- **Fortinet**: FortiGuard Application Database + ISDB (Internet Service Database). ISDB maps SaaS applications to IP prefix/port/protocol tuples updated automatically from FortiGuard cloud.

Classification happens at session establishment; the first few packets identify the application, and subsequent packets in the session follow the same steering decision.

**Path Quality Measurement**

Active probes measure the real-time quality of each overlay tunnel:

- **Latency**: Round-trip time of probe packets
- **Jitter**: Variation in latency between consecutive probes
- **Packet Loss**: Percentage of probe packets not returned
- **MOS (Mean Opinion Score)**: Calculated score for voice quality (Fortinet)

Probe types: ICMP echo, TCP echo, UDP echo, HTTP/HTTPS GET, DNS query, TWAMP

Probe intervals typically range from 100ms (critical apps) to 10 seconds (best-effort). Shorter intervals detect path degradation faster but consume more bandwidth.

**SLA Classes**

SLA classes define acceptable performance thresholds for application categories:

```
Example SLA Classes:

VOICE:       latency < 150ms, jitter < 30ms, loss < 1%
VIDEO:       latency < 200ms, jitter < 50ms, loss < 2%
CRITICAL:    latency < 100ms, loss < 0.1%
BEST-EFFORT: latency < 500ms, loss < 5%
```

An SLA class is "met" when all measured metrics fall within the defined thresholds simultaneously.

**Steering Decision**

The AAR engine combines classification, measurement, and SLA to select the optimal path:

1. Identify the application (DPI)
2. Look up the assigned SLA class
3. Evaluate all available tunnels against SLA thresholds
4. Select the tunnel that meets SLA and matches preference (if configured)
5. If no tunnel meets SLA: fallback action (use best-available or drop)
6. Continuously re-evaluate; switch paths if a better one becomes available or current path degrades

### Steering Strategies

| Strategy | Description | Use Case |
|---|---|---|
| Preferred path | Use specified transport if SLA met; fallback otherwise | Voice over MPLS, fallback to broadband |
| Best quality | Dynamically select path with best metric (lowest latency, jitter, or loss) | Video conferencing |
| Load balance | Distribute across all SLA-compliant paths | Bulk data, maximize aggregate throughput |
| Lowest cost | Use cheapest transport that meets SLA | Cost-conscious general traffic |
| Minimum SLA (stability) | Stay on current path unless SLA violated | Avoid unnecessary reroutes |

## Zero-Touch Provisioning (ZTP)

ZTP eliminates per-site manual configuration for SD-WAN edge deployment.

### ZTP Workflow

```
1. Pre-stage: Register device serial number in orchestrator
2. Ship device to remote site
3. Power on: Device boots with factory default config
4. Connect: Device reaches internet (DHCP on WAN port)
5. Discover: Device contacts orchestrator cloud service
   - Cisco: SD-WAN Validator (vBond) on port 12346/UDP
   - Fortinet: FortiManager or FortiGuard ZTP cloud
6. Authenticate: Serial number verified against whitelist
7. Download: Full configuration, firmware, certificates, policies
8. Activate: Device builds overlay tunnels, applies policies
```

### ZTP Prerequisites

- Device serial numbers registered in orchestrator before shipping
- WAN port must reach the internet (DHCP, or static IP pre-configured)
- DNS resolution required for orchestrator FQDN
- Firewall rules at the site must permit outbound DTLS/TLS to orchestrator
- Certificate infrastructure provisioned (automatic on both platforms)

### ZTP at Scale

For large deployments (hundreds of sites):
- Use CSV/API bulk import of serial numbers and site variables
- Define template hierarchies (Cisco: device templates / configuration groups; Fortinet: FortiManager ADOM templates)
- Stage firmware images on orchestrator before bulk deployment
- Monitor ZTP status dashboard for failed onboardings

## Orchestration Models

### Centralized Controller (Cisco Model)

Cisco Catalyst SD-WAN uses dedicated controller infrastructure:

- **SD-WAN Manager (vManage)**: Management plane -- GUI, API, templates, monitoring
- **SD-WAN Controller (vSmart)**: Control plane -- OMP route reflector, policy distribution
- **SD-WAN Validator (vBond)**: Orchestration -- device authentication, NAT traversal

Controllers can be deployed on-premises (VMware ESXi, KVM) or consumed as a cloud-hosted service. Minimum 3-node cluster for SD-WAN Manager HA.

**Advantages**: Clear separation of concerns; control plane scales independently; WAN Edge devices are lightweight.

**Trade-offs**: Higher infrastructure cost; controller availability is critical (though data plane survives controller outage via OMP graceful restart).

### Embedded Controller (Fortinet Model)

Fortinet SD-WAN embeds all control functions in the FortiGate:

- **FortiGate**: Combined SD-WAN edge + security + routing -- all control logic runs locally
- **FortiManager**: Optional centralized orchestration for template push and monitoring
- **FortiAnalyzer**: Optional analytics and reporting

**Advantages**: Simpler architecture; no dedicated controller infrastructure; FortiGate operates autonomously even without FortiManager.

**Trade-offs**: FortiManager is effectively required at scale; no centralized control plane for topology decisions (each FortiGate makes local decisions based on its SD-WAN rules).

## Transport Selection and Circuit Design

### Bandwidth Sizing

Rule of thumb for SD-WAN circuit sizing:
- **Primary transport**: Match existing MPLS bandwidth or size for peak application demand
- **Secondary transport**: 50-75% of primary for meaningful redundancy
- **IPsec overhead**: ~10-15% overhead for encryption headers; size accordingly
- **BFD/probe traffic**: Minimal (< 100 kbps per tunnel) but scales with number of tunnels

### Transport Pairing

Common transport combinations per site type:

| Site Type | Primary | Secondary | Tertiary |
|---|---|---|---|
| Data Center / Hub | MPLS (1G+) | DIA (1G) | -- |
| Large Branch (50+ users) | MPLS (100M) | Broadband (200M) | LTE (backup) |
| Medium Branch (20-50) | Broadband (100M) | Broadband (50M) | LTE (backup) |
| Small Branch (< 20) | Broadband (50M) | LTE (backup) | -- |
| Temporary / Pop-up | LTE/5G (primary) | Satellite (backup) | -- |

### Quality of Service (QoS)

SD-WAN QoS operates at two levels:
1. **WAN-side QoS**: Per-tunnel traffic shaping and queuing (DSCP marking, scheduling queues)
2. **Application-aware QoS**: AAR steers applications to the right transport; within that transport, QoS queues prioritize further

Best practice: Define 4-6 QoS queues (voice, video, critical data, best effort, bulk, scavenger) and map application classes to queues consistently across all transports.

## Security in SD-WAN

### Direct Internet Access (DIA)

DIA allows branch traffic destined for the internet to exit locally rather than backhauling to the data center. This is critical for SaaS performance but introduces security requirements:

- **On-box security**: NGFW, IPS, URL filtering, malware inspection at the WAN edge
- **Cloud security (SASE)**: Traffic tunneled to cloud security PoPs (Cisco Umbrella, Fortinet FortiSASE)
- **Split tunnel**: Internet traffic goes direct; private app traffic goes through overlay to DC

### Encryption

All SD-WAN overlay traffic is encrypted:
- **IPsec ESP**: Standard encryption for all tunnels (AES-256-GCM typical)
- **Key management**: Centralized key distribution and rotation via controller/orchestrator
- **Certificate-based authentication**: X.509 certificates for device identity (preferred over PSK)

### Segmentation

SD-WAN supports network segmentation via VPN/VRF constructs:
- **Cisco**: VPN IDs (VPN 0 = transport, VPN 512 = management, VPN 1+ = service VPNs)
- **Fortinet**: VDOMs + SD-WAN zones provide logical segmentation

Segmentation ensures guest traffic, IoT traffic, and corporate traffic remain isolated end-to-end across the overlay.

## Monitoring and Analytics

### Key Metrics to Monitor

| Metric | Description | Alert Threshold |
|---|---|---|
| Tunnel state | Up/down status of all overlay tunnels | Any tunnel down |
| BFD/health check metrics | Per-tunnel latency, jitter, loss | Exceeds SLA thresholds |
| SLA compliance | Percentage of time each tunnel meets SLA | < 95% compliance |
| Application path | Which transport each application is using | Unexpected path selection |
| Bandwidth utilization | Per-transport utilization percentage | > 80% sustained |
| ZTP status | New device onboarding success/failure | Any failure |
| Controller health | Controller cluster status and reachability | Any controller down |

### Capacity Planning

- Track per-transport bandwidth utilization trending (weekly, monthly)
- Alert when sustained utilization exceeds 80% on any transport
- Plan circuit upgrades 60-90 days ahead of projected capacity exhaustion
- Use application-level bandwidth data to justify circuit changes
