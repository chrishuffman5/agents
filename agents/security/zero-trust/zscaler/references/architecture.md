# Zscaler Zero Trust Exchange — Architecture Reference

## Data Center Network Topology

### Global Node Hierarchy

Zscaler's infrastructure uses a hierarchical node model:

```
Primary Enforcement Nodes (150+ globally)
    ↑ ↓  (Route via Backbone)
ZEN (Zscaler Enforcement Nodes)
    - Each ZEN is a full stack: ZIA + ZPA + ZDX processing
    - Anycast routing to nearest ZEN
    - Peer-to-peer ZPA broker communication

Zscaler Backbone
    - Private fiber interconnects between major ZENs
    - Routes ZPA broker traffic and telemetry
    - Not customer data traffic (processed at edge ZENs)

Supercluster Nodes
    - Selected ZENs designated for ZPA broker function
    - ZPA authentication and policy lookups
    - App Connector tunnel termination
```

### Traffic Processing Architecture (Single-Pass)

All traffic at a ZEN is processed through a single pass — TLS decrypted once, then inspected by all engines simultaneously.

```
Traffic arrives at ZEN
        ↓
Connection Admission Control
(Check tenant quotas, rate limiting)
        ↓
TLS Termination / SSL Inspection
(Decrypt HTTPS; verify server cert)
        ↓
Protocol Detection
(HTTP/1.1, HTTP/2, WebSocket, FTP, DNS, generic TCP)
        ↓
┌─────────────────────────────────────────────────────┐
│                   Parallel Inspection               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ URL Filter│  │ App-ID   │  │  IPS     │          │
│  │ + DNS     │  │ + CASB   │  │          │          │
│  └──────────┘  └──────────┘  └──────────┘          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ Anti-    │  │  DLP     │  │ Sandbox  │          │
│  │ Malware  │  │          │  │ (async)  │          │
│  └──────────┘  └──────────┘  └──────────┘          │
└─────────────────────────────────────────────────────┘
        ↓
Policy Decision (combine all verdicts)
        ↓
Action: Allow / Block / Quarantine
        ↓
TLS Re-encryption
(Re-encrypt with server's original cert params)
        ↓
Forward to destination
```

**Latency budget:**
- Connection setup + TLS: 10-30ms
- URL/app classification: < 2ms (cached; miss requires DNS/cloud lookup ~5ms)
- AV scan (clean file): < 5ms
- DLP scan: 5-20ms depending on content size
- Total overhead target: < 50ms for non-sandboxed traffic

## ZPA Broker Architecture

### ZPA Session Establishment Flow

```
Phase 1: Authentication
User (ZCC) → Zscaler IdP Proxy → Customer IdP (Okta/AAD) → SAML/OIDC token
ZCC receives identity assertion + ZPA session token

Phase 2: Policy Lookup
ZCC → ZPA Supercluster → Policy Engine
"User X, Device Y, wants to access App Segment Z"
Device posture check: ZCC reports device health signals
Access decision: Allow / Deny / Allow with conditions

Phase 3: Tunnel Establishment
ZPA Supercluster allocates:
  - Source-side tunnel: ZCC ↔ ZPA Cloud (already established)
  - Destination-side tunnel: ZPA Cloud ↔ App Connector (pre-established persistent tunnel)
  - Session correlation: Match source to destination session

Phase 4: Data Path
ZCC → ZPA Edge (nearest ZEN for ZPA) → App Connector → Private Application
      (Traffic passes through ZPA edge at the network level only — no content inspection for ZPA)
```

**Why ZPA traffic isn't SSL inspected:**
ZPA creates an end-to-end encrypted tunnel from user to application. The ZPA edge (broker) routes the tunnel but does not decrypt content. This is by design — the private application's TLS is intact. Content inspection happens at the application layer if the organization deploys an inline WAF.

**Exception:** Zscaler does offer optional DLP scanning for ZPA traffic via a feature called ZPA Inspection (separate from core ZPA tunneling).

### App Connector Persistent Tunnel

App Connectors maintain persistent outbound tunnels to ZPA Enforcement Nodes.

```
App Connector VM
    |
    | Outbound TCP 443 → *.zpa.zscaler.com
    |
    ↓
ZPA Enforcement Node (Supercluster)
    |
    | Session correlation
    | (when user requests access to app)
    |
    ↓
ZPA Edge (nearest to user)
    |
    | ZCC ↔ ZPA Edge ↔ ZPA Supercluster ↔ App Connector ↔ Application
```

**Persistent tunnel benefits:**
- Zero inbound ports on App Connector's firewall — reduces attack surface
- Tunnel is always ready; connection is near-instantaneous when user requests access
- Reconnection: App Connector re-establishes if tunnel drops (30-second retry with backoff)

### App Connector Sizing

| Traffic Volume | CPU | RAM | Network |
|---|---|---|---|
| Small (< 100 concurrent users) | 2 vCPU | 4 GB | 1 Gbps |
| Medium (100-500 concurrent users) | 4 vCPU | 8 GB | 2.5 Gbps |
| Large (500+ concurrent users) | 8 vCPU | 16 GB | 10 Gbps |

**High availability:** Always deploy 2+ App Connectors per group. ZPA uses Round Robin load balancing across healthy connectors.

## Z-Tunnel Protocol

### Z-Tunnel 2.0 Architecture

Z-Tunnel 2.0 uses DTLS (Datagram TLS) to encapsulate all traffic in a UDP-based encrypted tunnel.

```
ZCC Client
    |
    | Raw TCP/UDP/ICMP traffic from applications
    |
    ↓
ZCC Interceptor (kernel driver on Windows/macOS/Linux)
    |
    | Intercepts all IP traffic
    | Applies forwarding profile: route to ZIA or direct
    |
    ↓ (ZIA-bound traffic)
DTLS tunnel on UDP/443 or fallback TCP/443
    |
    | Encrypted Z-Tunnel 2.0 packets
    |
    ↓
Nearest ZEN (via DNS anycast resolution of gateway.zscaler.net)
    |
    | ZEN decapsulates, processes, forwards
```

**DTLS vs. TCP for tunneling:**
- TCP-based tunnels (legacy): TCP-in-TCP causes performance issues (TCP retransmit within tunnel + outer TCP retransmit)
- DTLS (UDP-based): No TCP-in-TCP issue; better for latency-sensitive traffic; retransmit handled by inner TCP only

**Fallback to TCP/443:**
Many networks block UDP. ZCC detects this and falls back to Z-Tunnel 2.0 over TCP/443 (TLS-wrapped). Performance is somewhat reduced.

### Traffic Forwarding Profiles

**Profile components:**
- **ZIA forwarding:** Which traffic goes through ZIA (web, email, all)
- **ZPA forwarding:** Which traffic goes through ZPA (private app destinations)
- **Split tunnel bypass:** IP ranges or FQDNs that route directly (bypass Zscaler)
- **Trusted network detection:** If user is on corporate network, optionally bypass ZCC

**Microsoft 365 optimization:**
Following Microsoft's best practice, M365 Optimize-category endpoints are typically added to the split tunnel bypass:
```
# M365 Optimize category - bypass Zscaler for these (Microsoft recommendation)
13.107.6.152/31, 13.107.18.10/31, 13.107.128.0/22
23.103.160.0/20, 40.96.0.0/13, 40.104.0.0/15
52.96.0.0/14, 131.253.33.215/32, 132.245.0.0/16
150.171.32.0/22, 150.171.40.0/22, 204.79.197.215/32
```

## Zscaler Deception

Zscaler Deception (acquired from Smokescreen) deploys decoys in the network to detect attackers who have bypassed perimeter security.

### How Deception Works

**Lures:** Fake credentials, fake connections, fake data placed on real endpoints (Windows credential cache, browser saved passwords, fake SSH keys). If attacker harvests and uses these lures, alert fires.

**Decoys:** Fake servers deployed alongside real servers. If any system attempts to connect to a decoy (legitimate users have no reason to), alert fires.

**Zero false positives:** Decoys are never real resources. Any interaction is definitionally malicious.

**Integration with ZPA:** Deception decoys can be protected resources behind ZPA, so legitimate access is impossible — making any decoy interaction unambiguous.

## Zscaler Browser Isolation (ZBI)

ZBI renders web content in Zscaler's cloud, streaming only pixels to the user's browser. Web code never runs on the user's device.

### Architecture

```
User browser → ZBI PoP (renders page in isolated cloud browser) → Pixel stream to user
                                    ↑
                           All JavaScript, DOM, network
                           activity happens here, isolated
                           from user's device
```

**Use cases:**
- Unmanaged device access (contractors) — protect SaaS apps from unmanaged endpoints
- High-risk URL categories — allow access but isolate execution
- Zero-day browser exploits — exploit code runs in Zscaler's disposable container, not user device
- Data protection — disable clipboard, download, print within isolated session

**Integration with ZIA:**
ZBI can be configured as an action for specific URL categories in ZIA policy:
- Block: No access
- Allow: Full access
- Isolate: Allow but run in ZBI

## SSMA — Secure Service Mesh for Apps

SSMA extends ZPA to application-to-application communication (workload-to-workload ZTNA).

**Use case:** Microservices in different VPCs/on-prem that need to communicate securely without network-level trust.

**Architecture:**
- App Connectors deployed at each workload segment
- Service-to-service access policies defined in ZPA (same policy engine as user-to-app)
- mTLS between connectors; workloads don't need to manage certificates

**Benefit:** Replaces complex VPC peering, Transit Gateway configurations, and security group rules with application-level policy.

## Zscaler Posture Control (ZCP)

ZCP is Zscaler's CNAPP (Cloud Native Application Protection Platform) covering cloud security posture.

### CSPM (Cloud Security Posture Management)

Continuously scans AWS, Azure, GCP configurations for misconfigurations:
- S3 bucket public access
- Security group overly permissive rules
- Unencrypted databases
- IAM privilege escalation paths
- Compliance benchmarks: CIS, SOC 2, PCI DSS, HIPAA, NIST

### CIEM (Cloud Infrastructure Entitlement Management)

Analyzes IAM policies in cloud environments:
- Identifies unused permissions (over-provisioned roles)
- Detects privilege escalation paths
- Recommends least-privilege policies

### Integration with ZIA/ZPA

ZCP findings can feed into ZIA policy:
- Workloads with CSPM findings get higher inspection levels
- Infected cloud instances quarantined from ZPA access

## Logging and Analytics Architecture

### Nanolog Streaming Service (NSS) Technical

NSS is a dedicated Zscaler cloud service that aggregates logs from all ZENs and streams to customer SIEM.

**NSS feed types and formats:**

| Feed | Format | Fields |
|---|---|---|
| Web | LEEF / CEF / Zscaler JSON | Transaction time, user, URL, category, action, bytes, threat name |
| Firewall | CEF / Zscaler JSON | Src IP, dst IP, port, protocol, rule, action, bytes |
| DNS | Zscaler JSON | Query, response, category, action |
| DLP | Zscaler JSON | User, file, rule, matched content type, action |
| ATP (Sandbox) | Zscaler JSON | File hash, file name, verdict, threat classification |

**NSS throughput:**
NSS can handle millions of events per second. For very large deployments, multiple NSS nodes can be deployed.

**Alternative: Zscaler Cloud Activity Log (micro-tenants):**
For smaller deployments, logs can be pulled via API instead of NSS streaming.

## ThreatLabZ Intelligence

Zscaler's threat research team processes 300+ billion daily transactions for threat intelligence.

**Intelligence feeds:**
- IP reputation (updated every 5 minutes to all ZENs)
- URL categorization (real-time additions)
- Phishing page detection (ML-based, real-time)
- Malware signatures and behavioral detections
- Botnet C2 tracking

**ThreatLabZ research publications:**
Available at research.zscaler.com — detailed malware analysis reports, annual threat reports, specific campaign analyses.

**ThreatLibrary API:**
Internal API (used by ZIA DLP and threat protection) for querying ThreatLabZ intelligence. Not directly exposed to customers, but customers can request URL re-categorization or malware verdict review via the Admin Portal.
