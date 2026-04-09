# Check Point Architecture Reference

## SmartConsole

SmartConsole is the primary management interface (Windows desktop and web-based):

- **Policy Management** -- Unified security policy with layered rule bases; drag-and-drop rule reordering; inline layer editing
- **Session Collaboration** -- Multiple admins work concurrently in separate sessions; publish/discard/lock model prevents conflicts
- **Revision Control** -- Every policy publish creates a versioned snapshot; roll back to any previous state
- **Software Deployment** -- Central patch management for gateways and cluster members
- **SmartEvent Integration** -- Embedded event analysis, threat timeline, SmartLog search
- **AI Copilot (R82+)** -- Natural language queries for policy search, log analysis, threat hunting (Take 1027+ desktop, Take 125+ web)
- **Web SmartConsole** -- Browser-based alternative; feature parity growing with each Take

## SmartCenter and Multi-Domain Management

### SmartCenter (Single-Domain)
Classic management server model. One Security Management Server (SMS) manages all gateways and policies within a single domain. Suitable for most enterprises.

### Multi-Domain Management (MDS)
Hierarchical architecture for large enterprises and MSSPs:

- **Multi-Domain Server (MDS)** -- Top-level container hosting multiple independent Domain Management Servers
- **Domain Management Server (DMS)** -- Each domain is an isolated SmartCenter instance with its own policy, object database, logs, and administrators
- **Multi-Domain Log Server** -- Centralized log collection across all domains
- **Global Policy** -- Shared policy objects and rules pushed down to all domains:
  - Global pre-rulebase: evaluated before domain-specific rules (corporate mandatory policy)
  - Global post-rulebase: evaluated after domain-specific rules (corporate catch-all)
- **SmartProvisioning** -- Bulk gateway provisioning and profile management

### Domain Isolation
Each DMS maintains completely independent:
- Object databases (hosts, networks, groups, services)
- Security policy packages and rule bases
- Administrator accounts and permissions
- Log databases
- Revision history

## Infinity Architecture

Check Point Infinity unifies five pillars under a single platform strategy:

1. **Quantum** -- Network security (gateways, data center, perimeter, Maestro)
2. **Harmony** -- User/endpoint/access security:
   - Harmony Endpoint: EPP + EDR + DLP in a unified agent
   - Harmony SASE: SWG, CASB, ZTNA, FWaaS, SD-WAN (cloud-delivered)
   - Harmony Email & Collaboration: Email security
   - Harmony Browse: Secure browser extension
   - Harmony Mobile: Mobile threat defense
3. **CloudGuard** -- Cloud workload and network security:
   - Network Security: Virtual gateways in AWS/Azure/GCP with auto-scaling, Transit Gateway, GWLB
   - Posture Management (CSPM): Compliance and misconfiguration detection
   - Workload: Container and serverless security
   - AppSec: WAF and API protection
4. **Infinity Portal** -- Single SaaS management plane with MDR, threat hunting, SOC-as-a-service
5. **ThreatCloud AI** -- Shared threat intelligence layer feeding all pillars

## ThreatCloud AI

Real-time threat intelligence network:

- Aggregates data from 150,000+ networks and millions of endpoint sensors
- 30+ AI/ML engines: malware classification, phishing detection, zero-day identification, campaign correlation
- **Blade integration**: Feeds ThreatEmulation (sandboxing), ThreatExtraction (CDR), Anti-Bot, Anti-Virus, IPS, URL Filtering in real time
- **Zero-day Phishing Protection** -- AI-based URL and page analysis for novel phishing pages
- **DNS Trap / Anti-Bot** -- ThreatCloud identifies C2 domains; gateway blocks outbound and quarantines hosts
- **Custom IoC feeds** -- Import via SmartConsole or API
- Claimed 99.9% catch rate with under 0.1% false positives

## Security Policy Layers

### Access Control Layer
- 5-tuple + application control + URL filtering
- Ordered rules evaluated top-down, first-match within a layer
- **Inline layers**: Nested sub-policies within a rule; evaluated when parent rule matches
- **Ordered layers**: Multiple Access Control layers processed sequentially
- Implicit cleanup rule (deny all) at bottom

### Threat Prevention Layer
- IPS, Anti-Virus, Anti-Bot, ThreatEmulation, ThreatExtraction
- Profile-based configuration: Optimized (balanced), Strict (maximum detection), Custom
- Applied after Access Control permits traffic
- Inline or detect mode per profile

### HTTPS Inspection Layer
- SSL/TLS interception for encrypted traffic inspection
- **Outbound (forward proxy)**: Inspect user-initiated HTTPS; re-signs with CA cert
- **Inbound (reverse proxy)**: Protect published applications; import server certificate
- Certificate pinning bypass lists, category exclusions
- Must be enabled for Threat Prevention to inspect encrypted content

## Anti-Bot, Threat Extraction, and Threat Emulation

### Anti-Bot
- Detects infected hosts communicating with C2 using ThreatCloud AI signatures and behavioral patterns
- DNS sinkholing for C2 domains; blocks outbound connections and alerts
- Generates Security Incidents linked to affected host

### Threat Extraction (CDR)
- Removes potentially malicious content (macros, embedded objects, active content) from files in transit
- Delivers clean version immediately; original sent to ThreatEmulation in parallel
- Supports Office documents, PDFs; web downloads and email attachments
- Zero-latency: user gets clean file while sandbox runs asynchronously

### Threat Emulation (Sandboxing)
- Detonates suspicious files in isolated virtual environments
- Cloud-based (ThreatCloud) or on-premises (TE appliance)
- MITRE ATT&CK mapping of detected techniques; forensic reports
- CPU-level emulation (TE250X hardware) defeats VM-aware malware evasion

## ClusterXL High Availability

### Modes
| Mode | Behavior |
|---|---|
| Active/Standby (HA) | One active member; automatic failover; sub-second with sync |
| Active/Active (Load Sharing - Unicast) | Sessions distributed; stateful sync; deployment-flexible |
| Active/Active (Load Sharing - Multicast) | Same as unicast but uses multicast for CCP |

### State Synchronization
- Connection table, NAT table, VPN tunnels synchronized via dedicated sync interface
- Configurable exclusions: exclude non-critical protocols (DNS short-lived, HTTP non-persistent) for performance
- Sync interface must be dedicated physical link, never shared with production traffic

### Cluster Control Protocol (CCP)
- Proprietary heartbeat between members
- Monitors member health, interface status, and propagates failover decisions
- Configurable advertisement intervals

### Multi-Version Cluster (MVC)
Allows rolling upgrades between minor versions without downtime. Members can run different minor versions during the upgrade window.

## Maestro Hyperscale Orchestration

### Architecture
- **Maestro Hyperscale Orchestrator (MHO)** -- Dedicated appliance connecting gateways via high-speed backplane
- **Security Group** -- Logical unit of multiple gateways appearing as Single Management Object (SMO) in SmartConsole
- **Dual Orchestrator HA** -- Two MHOs for resilience

### Scaling
- 2 to 52 gateways per Security Group
- Add members without downtime; dynamic session rebalancing
- Multi-Terabit/second combined threat prevention (26000-series)

### Session Distribution
- Stateful session distribution across all members
- Session affinity maintained
- Dynamic rebalancing handles asymmetric routing
- Policy deployed once to SMO, enforced identically on all members

### Use Cases
- Hyperscale data center perimeter
- Carrier-grade security / ISP peering
- Large enterprise internet edge requiring elastic scaling

## Quantum Security Gateway Hardware

### Quantum Spark (Entry / Branch)
- 1500 / 1600 / 1800 Series -- Branch office; unified firewall, VPN, IPS, URL filtering
- Managed via local WebUI or Quantum Spark Cloud Management

### Mid-Range Quantum
- 3600 -- 4 Gbps NGFW; 1U, dual PSU option
- 6200 / 6400 / 6600 / 6800 -- 10-30 Gbps NGFW; 40 GbE; hardware acceleration
- 7000 Series -- Up to 52 Gbps NGFW with SecureXL

### High-End Quantum
- 16000 Series -- Multi-terabit with Maestro; 100 GbE, NIC expansion
- 26000 Series -- Flagship; Tbps threat prevention with Maestro; 400 GbE ready
- 28000 Series -- Ultra-high density carrier/DC chassis; modular blade design

## SecureXL Acceleration

SecureXL is the acceleration layer that offloads established sessions from the firewall kernel:

### Path Classification
- **Accelerated Path** -- Established sessions forwarded entirely in SecureXL; no kernel processing; line-rate
- **Medium Path** -- Partial acceleration; some kernel involvement (e.g., NAT, QoS)
- **Slow Path (Firewall Path)** -- Full kernel processing; new sessions, complex features

### What Prevents Acceleration
- HTTPS Inspection (must decrypt in kernel)
- Certain NAT configurations (dynamic hide NAT with port allocation)
- QoS / traffic shaping
- Accounting features
- Certain VPN configurations

### CoreXL
- Multi-core processing: Firewall Worker (FWK) instances and SND (Secure Network Distributor) cores
- `sim affinity -l` shows core allocation
- Tune SND/FWK ratio for workload (more FWKs for inspection-heavy, more SNDs for connection-heavy)

## NAT Architecture

### Evaluation Order
1. Manual NAT rules (top-down, first-match)
2. Automatic NAT rules (object-defined, evaluated by specificity)

### NAT Types
- **Hide NAT (Many-to-One)**: Source NAT; auto-configured per network object or manual
- **Static NAT (One-to-One)**: Bidirectional; supports port translation
- **Proxy ARP**: Automatically configured for static NAT addresses on local subnets

### Key Behaviors
- Connection matching uses original packet directionality
- NAT translated bidirectionally automatically
- IPv6 NAT64/NAT66 supported in R82
- Manual rules take precedence; be careful not to shadow automatic NAT

## VPN Architecture

### Site-to-Site
- IKEv1/IKEv2; PSK or certificate
- Policy-based (domain-based encryption rules) and route-based (VTI)
- VPN Communities: Star and Meshed topologies
- MEP (Multiple Entry Points): failover across redundant gateways
- Directional VPN: granular control over encrypted vs. plaintext traffic

### Remote Access
- Endpoint Security VPN (full client)
- Check Point Mobile (SSL VPN)
- L2TP/IPsec
- MFA via RADIUS/LDAP/SAML

### Post-Quantum VPN (R82)
- Hybrid Kyber (ML-KEM / CRYSTALS-Kyber) + classical IKE
- NIST-certified algorithms
- Backward compatible with non-PQC peers
