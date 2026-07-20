# Prisma Access — Architecture Reference

## Compute Location Architecture

Each Prisma Access compute location is a fully instantiated PAN-OS firewall cluster running in Palo Alto's cloud infrastructure.

### Compute Location Components

```
Prisma Access Compute Location (PoP)
├── Ingress Controller
│   - Receives traffic from: GlobalProtect clients, IPsec tunnels (branch, service connection)
│   - Anycast routing to nearest compute location
│   - Load balancing across firewall cluster nodes
│
├── Firewall Cluster (PAN-OS)
│   - Multiple PAN-OS instances per location (HA + scale-out)
│   - App-ID engine
│   - Content-ID engine (Threat Prevention, URL, DNS, WildFire, DLP)
│   - User-ID mapping
│   - Security policy enforcement
│
├── WildFire Forwarding
│   - Suspicious files forwarded to WildFire Cloud (nearest WF instance)
│   - Inline blocking: Hold file until verdict (or allow and retroactive verdict)
│
└── Egress
    - Direct peering with SaaS providers (M365, Google, Salesforce)
    - Public internet for general web traffic
    - Private app return path via service connection tunnels
```

### PAN-OS Processing Pipeline

PAN-OS processes packets through a strict pipeline within each compute location node:

```
Packet arrives
    ↓
Interface ingress + decapsulation (GRE/IPsec/DTLS)
    ↓
Security Zone determination
    ↓
Session lookup
    ↓ (new session)
App-ID classification
    ↓
User-ID lookup (identify user from source IP or GP token)
    ↓
Security policy lookup (match rule based on zone, app, user, destination)
    ↓
Profile application:
  ├── Threat Prevention (IPS/AV/spyware)
  ├── URL Filtering (if web traffic)
  ├── WildFire (if file transfer)
  ├── DNS Security (if DNS)
  └── DLP (if enabled)
    ↓
NAT (if applicable)
    ↓
Egress interface + re-encapsulation
    ↓
Forwarding to destination
```

### App-ID Deep Packet Inspection

App-ID identifies applications through multiple techniques in sequence:

1. **Application signatures:** Known pattern at fixed offset in first few packets
2. **Application protocol decoding:** Parse application protocol to extract app identity
3. **Heuristics:** Behavioral patterns (traffic timing, packet sizes) for encrypted apps
4. **Context:** Protocol context (e.g., SSL/TLS with SNI identifying the app)

**App-ID for encrypted traffic:**
- TLS SNI (Server Name Indication) reveals destination hostname → maps to application
- JA3/JA3S fingerprinting (TLS handshake characteristics) → identifies specific clients/apps
- Behavioral heuristics for apps that obfuscate their identity

**App-ID for QUIC/HTTP/3:**
PAN-OS includes App-ID for QUIC-based traffic (Google's transport protocol). Many Google and YouTube services use QUIC. PAN-OS can enforce policy on QUIC traffic or block QUIC to force fallback to HTTPS.

### Content-ID Processing

Content-ID handles all content inspection within App-ID-identified sessions:

**Stream-based scanning:**
Content-ID scans files in streaming fashion (as data arrives) rather than buffering entire files. This reduces latency.

**Threat Prevention:**
- Vulnerability Protection: Matches CVE-based exploit signatures
- Anti-spyware: Matches C2 traffic patterns, DNS tunneling
- Anti-virus: Multiple AV engines + ML-based malware detection
- WildFire integration: Unknown files forwarded; verdict returned

**URL Filtering:**
- PAN-DB lookup: Categorize URL against 40B+ URL database
- Real-time lookup: Newly seen URLs checked against cloud PAN-DB
- Inline ML: ML-based phishing detection (does not require prior category)

## GlobalProtect Gateway Architecture

### Gateway Types

**Prisma Access External Gateway:**
- Cloud-hosted in Prisma Access compute locations
- Handles all remote/mobile user connections
- Deployed automatically when Prisma Access is configured for mobile users

**Internal Gateway (on-premises, optional):**
- Physical or virtual PAN-OS firewall on-premises
- Handles user connections when on corporate network
- Provides HIP enforcement for internal network access
- Not required for Prisma Access; only needed for on-prem segmentation

### Connection Flow

```
User endpoint (GlobalProtect agent)
    |
    1. Portal discovery: GP agent queries portal (cloud GP portal or internal)
    2. Portal returns: List of gateways (external=Prisma Access, internal=on-prem)
    3. Gateway selection: GP pings gateways, selects lowest RTT
    4. Authentication: IdP auth (SAML) → identity token
    5. HIP collection: Agent collects device posture data
    6. Tunnel establishment: IPsec/SSL tunnel to selected gateway
    7. IP assignment: GP receives VPN IP from Prisma Access IP pool
    8. Traffic flows: Split tunnel or full tunnel per forwarding profile
```

### HIP Processing

**HIP (Host Information Profile) data collection:**
GlobalProtect agent queries:
- OS: Version, service pack, hotfixes
- Disk encryption: BitLocker/FileVault status, encryption algorithm
- Antivirus: Vendor, definition date, real-time protection status
- Firewall: Status, vendor
- Patch Management: Windows Update, WSUS, SCCM patch level
- Custom checks: Specific registry keys, file existence, running processes

**HIP match objects:**
Define conditions in Panorama/SCM:
```
HIP Object: "Compliant-Windows"
  Match: OS family = "Windows" AND
         Disk Encryption = "Enabled" AND
         Antivirus last update < 3 days AND
         CrowdStrike process running = true
```

**HIP-based security policy:**
```
Rule: Full-Access
  Source User: Domain Users
  HIP: Compliant-Windows OR Compliant-macOS
  Action: Allow

Rule: Restricted-Access  
  Source User: Domain Users
  HIP: non-Compliant
  Application: web-browsing, ssl (limited apps only)
  Action: Allow

Rule: Block-Unmanaged
  Source User: Domain Users
  HIP: any (doesn't match above)
  Action: Block
```

## ZTNA 2.0 Policy Engine

### Service Connection Architecture

Service connections are IPsec tunnels from the infrastructure hosting private applications to the nearest Prisma Access compute location.

```
Private Application (10.100.0.x)
        |
[Application Server (AD, SAP, etc.)]
        |
[IPsec-capable router or firewall]
        |  IPsec IKEv2 tunnel, outbound to Prisma Access
        ↓
Prisma Access Compute Location
        |
[Security Policy enforcement]
        |
        ↓ (matching allowed session)
GlobalProtect user at remote location
```

**Service connection redundancy:**
- Configure two service connections (to different compute locations) for redundancy
- BGP or static routing on customer side; Prisma Access routes are advertised to customer via BGP

**Application Segment (Prisma Access ZTNA):**
```
Application: Internal-ERP
  Hostname: erp.internal.corp.com
  IP Address: 10.100.0.50
  Ports: TCP 8443 (HTTPS)
  App-ID: Custom (application-override if not in default catalog)
  Service Connection: DC-ServiceConnection-01
```

### Continuous Trust Verification Mechanism

ZTNA 2.0 continuously re-evaluates access during sessions through:

**Inline session monitoring:**
- App-ID continues to inspect traffic within allowed sessions
- If App-ID detects a different application than authorized (e.g., session started as web-browsing but now shows signs of ssh tunneling), session is blocked
- Threat Prevention watches for exploit traffic within allowed session

**Dynamic policy updates:**
- Policy changes take effect on next packet for active sessions (not just new sessions)
- User risk signals from Cortex XDR can dynamically revoke access mid-session

**Session context:**
- Time-based: If session duration exceeds policy limit, re-authentication required
- Behavioral: Sudden data volume spike triggers inspection or alerting

## Panorama vs. Strata Cloud Manager

### When to Use Each

**Use Panorama if:**
- Existing large PAN-OS deployment with Panorama already in use
- Complex on-premises + cloud policy inheritance required
- Regulatory requirement for on-premises management plane
- Advanced automation using Panorama XML API

**Use Strata Cloud Manager (SCM) if:**
- New Prisma Access deployment
- AI-powered policy recommendations desired
- Simpler, cloud-native management experience
- Prisma SD-WAN integration (SCM provides unified SASE management)

### Management Architecture

**Panorama-managed Prisma Access:**
```
Admin → Panorama (on-prem or cloud-hosted) → Prisma Access Cloud Service plugin
         ↓                                           ↓
    Device Groups                              Compute locations treated as
    (on-prem NGFWs)                            virtual firewalls
         ↓
    Shared policies and objects
    (apply to both on-prem and Prisma Access)
```

**SCM-managed Prisma Access:**
```
Admin → Strata Cloud Manager (cloud SaaS) → Prisma Access
                    ↓
            AI Security Assistant
            (Strata Copilot — AI-powered policy analysis)
            Security Score (posture assessment)
            Best Practice Check
            Change Impact Analysis
```

### Policy Inheritance in Panorama

Device Groups in Panorama allow hierarchical policy:

```
Panorama
├── Shared (applies to ALL firewalls)
│   └── Block known-bad URLs (Malware/Phishing categories)
│   └── Allow M365 applications
│
├── Device Group: Prisma-Access-Production
│   ├── Inherited from Shared (above)
│   └── Prisma Access-specific rules
│       └── ZTNA access rules
│       └── Remote user internet policy
│
└── Device Group: On-Prem-Firewalls
    ├── Inherited from Shared (above)
    └── On-prem specific rules
        └── Data center east-west rules
        └── Server zone rules
```

## Cortex Data Lake Integration

### Log Forwarding

All Prisma Access logs are automatically forwarded to Cortex Data Lake.

**Log schema (key fields for Traffic log):**
```
time_generated       # Timestamp
src                  # Source IP
dst                  # Destination IP
srcloc               # Source country
dstloc               # Destination country
from                 # Source zone
to                   # Destination zone
inbound_if           # Ingress interface
outbound_if          # Egress interface
proto                # Protocol (tcp/udp/icmp)
app                  # App-ID application name
rule                 # Security policy rule name
action               # Allow/Deny
bytes_sent           # Bytes sent
bytes_received       # Bytes received
session_end_reason   # Why session ended
flags                # Session flags
srccountry           # Source country
dstcountry           # Destination country
```

**Querying via Cortex Query Language (CQL):**
```sql
-- Find all blocked connections from external sources
SELECT src, dst, app, rule, action, time_generated
FROM `firewall.traffic`
WHERE action = 'deny' AND srcloc != 'US'
ORDER BY time_generated DESC
LIMIT 1000

-- Top applications by bandwidth in last hour
SELECT app, SUM(bytes_sent + bytes_received) AS total_bytes
FROM `firewall.traffic`
WHERE time_generated > NOW() - INTERVAL 1 HOUR
GROUP BY app
ORDER BY total_bytes DESC
LIMIT 20
```

**Integration with Microsoft Sentinel:**
Cortex Data Lake can forward logs to Microsoft Sentinel via the Palo Alto Networks Cortex Sentinel connector.

**Integration with Splunk:**
Cortex Data Lake → Splunk (via Palo Alto Networks Splunk App for Cortex Data Lake).

## WildFire Sandbox Architecture

### Processing Flow

```
File encountered by Prisma Access (download, email attachment via SMTP proxy, etc.)
        ↓
Hash lookup in WildFire cloud verdict cache
    ↓ Cache HIT                     ↓ Cache MISS
Return known verdict             Submit to WildFire for analysis
(milliseconds)                          ↓
                                Analysis environments:
                                  Windows 10 (multiple versions)
                                  Windows 7
                                  macOS
                                  Linux
                                  Android
                                        ↓
                                Behavioral analysis:
                                  Process activity
                                  Network connections (DNS, HTTP, IRC, TCP)
                                  File system changes
                                  Registry changes
                                  Memory analysis
                                  API calls
                                        ↓
                                ML + signature analysis
                                        ↓
                                Verdict: Benign / Grayware / Malware / Phishing
                                        ↓
                                Verdict cached and distributed to all WildFire
                                subscribers within 5 minutes
```

### WildFire Inline vs. Hold Mode

**Hold (blocking) mode:**
- Prisma Access holds file delivery until WildFire verdict
- User experience: Waiting spinner for 30-90 seconds during detonation
- Best for high-security environments

**Inline (non-blocking) mode:**
- File delivered immediately; WildFire verdict applied retroactively
- If file was malicious: Session terminated, file cached as malicious
- Better user experience; slight risk window

**Best practice:**
- Enable inline blocking for executables and Office documents with macros
- Allow through for known-benign file types (images, plain text)
- Monitor WildFire logs for grayware verdicts (may need manual review)

## ADEM Architecture Detail

### Probe Infrastructure

**Endpoint probes:**
ZCC/GlobalProtect agent runs lightweight probes every 5 minutes:
- HTTP GET to monitored application endpoints
- DNS query to application FQDN
- ICMP traceroute to Prisma Access gateway
- ICMP traceroute to application server

**Probe results:**
Telemetry sent to Cortex Data Lake via Prisma Access control plane.

**ADEM synthetic test infrastructure:**
Beyond endpoint probes, ADEM has synthetic test agents deployed in Prisma Access compute locations. These test the application-side performance independently of user device issues.

**Root cause algorithm:**
```
User Experience Score drops (say from 95 → 55)
        ↓
Compare: Device metrics (CPU/WiFi) — No change
Compare: User-to-PoP latency — Increased by 80ms
Compare: PoP-to-App latency — No change
Compare: App response time — No change
        ↓
Root Cause: ISP/network path between user and Prisma Access PoP
        ↓
ADEM maps the specific ISP (BGP AS) causing the increase
        ↓
Alert: "Users connecting via ISP AS12345 experiencing high latency"
Recommendation: "Consider ADEM path redirection or alternate PoP"
```
