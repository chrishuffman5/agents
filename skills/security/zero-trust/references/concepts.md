# Zero Trust / SASE Fundamentals

## NIST SP 800-207 Deep Dive

### Policy Enforcement in Practice

The NIST logical model maps to real product deployments:

| NIST Component | Zscaler Implementation | Prisma Access Implementation | Cloudflare ZT Implementation |
|---|---|---|---|
| Policy Enforcement Point | ZPA App Connector + Client | GlobalProtect Agent | Cloudflare Tunnel + WARP Client |
| Policy Administrator | ZPA Cloud | Panorama / Strata Cloud Manager | Cloudflare Zero Trust Dashboard |
| Policy Engine | ZPA Access Policies | Prisma Access Policies | Cloudflare Access Rules |
| Data Sources | ZIA + ISDB + Identity | Cortex Data Lake | Cloudflare Radar |

### Zero Trust vs. Traditional Perimeter

**Traditional perimeter model:**
```
Internet ──[Firewall]── Internal Network (TRUSTED)
                              │
                    All internal systems trust each other
                    VPN = extend the trusted perimeter
                    Breach = attacker has free rein
```

**Zero Trust model:**
```
Internet        Private Network         Cloud
    │                  │                   │
    └──────────────────┴───────────────────┘
              No implicit trust anywhere
              Every request verified: Identity + Device + Context
              Micro-segmented access: user → specific app only
              Continuous monitoring and re-evaluation
```

### Micro-Segmentation

Micro-segmentation is a core ZT technique that divides the network into small zones, each requiring authentication to access.

**Levels of micro-segmentation:**
1. **Network-based:** VLANs, firewall rules between segments. Coarse-grained.
2. **Host-based:** Agent on each workload enforces policy (e.g., Illumio, Guardicore). Application-level.
3. **Application/identity-based:** Access granted to specific application, not network segment (ZTNA approach). Finest grain.

**East-West traffic control:**
Traditional security focused on North-South (perimeter) traffic. ZT addresses East-West (lateral movement):
- Service mesh (Istio, Consul Connect) for microservice-to-microservice mTLS
- ZTNA application connectors that only allow authorized user-to-application connections
- Workload segmentation agents (Illumio ASP, Akamai Guardicore)

## Software-Defined Perimeter (SDP) Protocol

SDP (CSA specification) is the protocol underpinning many ZTNA products.

### Single Packet Authorization (SPA)

SPA is the mechanism by which the Initiating Host proves identity before the Accepting Host's address is revealed.

```
Initiating Host (Client)          SDP Controller          Accepting Host (Server)
        |                              |                          |
        |-- 1. Authenticate user/device → IdP -----------------→|
        |← 2. Receive short-lived token ←---SDP Controller ------|
        |                              |                          |
        |-- 3. Send encrypted SPA packet (token + HMAC) --------→|
        |   [SPA packet sent to Accepting Host IP via UDP]        |
        |                              |                          |
        |                             AH validates SPA with controller
        |                             AH firewall opens ephemeral rule:
        |                             "Allow IH_IP:any → AH_IP:port for 30s"
        |                                                         |
        |-- 4. Establish mTLS connection -----------------------→ |
        |   [Normal HTTPS/TLS with client certificate]           |
        |← 5. Application response ←------------------------------|
```

**SPA properties:**
- Accepting Host has no open ports before SPA — not discoverable by port scanners
- SPA packet: Encrypted with controller-issued key; contains timestamp (prevents replay), client IP, requested service
- Firewall opens for seconds only — connection must be established quickly
- No traditional firewall rule management — rules are ephemeral

## SASE Architecture Details

### Network of PoPs (Points of Presence)

SASE relies on a global network of PoPs that serve as distributed PEPs.

**PoP requirements for SASE:**
- Close to users (< 20ms latency) — rule of thumb: PoP within same metro area
- Direct peering with major cloud providers (AWS, Azure, GCP)
- Direct peering with SaaS providers (Microsoft 365, Salesforce, Workday)
- High availability (N+2 redundancy within each PoP, failover between PoPs)
- Full security stack processing in each PoP (SSL inspection, malware scanning, DLP, CASB)

**PoP count comparison (approximate, 2024):**
- Zscaler: 150+ data centers globally
- Cloudflare: 300+ cities globally
- Netskope: 75+ PoPs
- Palo Alto Prisma Access: 110+ PoPs
- Cato Networks: 80+ PoPs

### Traffic Steering Methods

**Client-based (endpoint agent):**
Agent (ZPA Client/WARP/GlobalProtect) on endpoint intercepts traffic and tunnels to nearest PoP.
- Advantage: Strongest security, device posture assessment, works for all apps
- Disadvantage: Requires MDM/software distribution, doesn't cover IoT/unmanaged devices

**GRE/IPsec tunnel (office/branch):**
SD-WAN or existing router establishes GRE/IPsec tunnel from office to PoP.
- Advantage: Covers all office traffic including IoT, no agents needed
- Disadvantage: Fixed bandwidth per tunnel, less granular user-level policy

**PAC file / explicit proxy:**
Browser configured with PAC file to forward traffic to proxy.
- Advantage: No agent needed; quick deployment
- Disadvantage: Only works for HTTP/HTTPS browser traffic; users can bypass

**DNS redirect:**
DNS resolver pointed to SASE provider's DNS — only provides DNS-layer protection.
- Advantage: Instant deployment, no agents
- Disadvantage: Cannot inspect TLS traffic; easy to bypass (hardcoded DNS)

### Single-Pass Architecture

Many SASE vendors market "single-pass" or "single-scan" architecture:

**Traditional appliance chain:**
```
Traffic → Firewall → IPS → AV → DLP → Proxy → Traffic
         (each appliance re-reads and re-processes)
```

**Single-pass processing:**
```
Traffic → SASE PoP → (TLS decrypt once → route through all engines simultaneously) → Traffic
```

Benefits: Reduced latency (no re-encryption between stages), consistent policy application, simpler troubleshooting.

## SSL/TLS Inspection

SSL inspection is required for full SASE/SWG effectiveness since ~95% of web traffic is now HTTPS.

### How SSL Inspection Works

```
Client                   SASE Proxy                     Server
  |                           |                            |
  |--- ClientHello ----------→|                            |
  |                           |--- ClientHello ----------→|
  |                           |←-- ServerHello + Cert ----|
  |                           |    (real server cert)      |
  |                           |                            |
  |                    SASE verifies server cert against CA store
  |                    SASE generates new cert for client:
  |                    Subject: CN=server.com
  |                    Issuer: SASE Inspection CA (customer's CA)
  |                           |                            |
  |←-- ServerHello + Cert ----|                            |
  |    (SASE-generated cert,   |                            |
  |     signed by SASE CA)     |                            |
  |                           |                            |
  |--- Client data (decrypted by SASE, inspected, re-encrypted) ---→|
```

**Certificate requirements:**
- SASE inspection CA certificate must be installed as a trusted root CA on all managed devices
- Distribution: MDM (Intune, Jamf), Group Policy (Windows), or device enrollment
- If CA not trusted: Users see certificate errors for all HTTPS sites

**SSL inspection bypass rules:**
Some traffic should not be decrypted:
- **Financial/banking sites:** Legal compliance (e.g., PCI DSS), user privacy
- **Government sites:** Compliance requirements
- **Personal email/medical:** Privacy laws (HIPAA for medical patient portals)
- **Client-certificate mutual TLS apps:** SASE cannot present user's client cert to server
- **Certificate pinning apps:** Mobile apps that pin their cert will break
- **Antivirus updates:** May cause false positives in malware scanning

### TLS 1.3 and Forward Secrecy

TLS 1.3 challenges traditional SSL inspection:
- Ephemeral key exchange (ECDHE) means each session has unique keys
- Network-tap based inspection (middle-box passive) is mathematically impossible with forward secrecy
- Active man-in-the-middle proxy (SASE approach) still works, but requires CA cert on endpoint

## CASB Deep Dive

### Inline CASB Traffic Flow

```
User (browser/app)
        ↓
SASE Agent or Proxy PAC file
        ↓
SASE PoP (forward proxy)
        ↓
SSL Inspect → Identify app (App-ID / deep packet inspection)
        ↓
Apply CASB policy for this app:
- Sanctioned app: Full access
- Unsanctioned: Block or allow in read-only
- Partial control: Block upload, allow download
        ↓
Forward to SaaS app
```

**Granular inline CASB controls (examples):**

| Control | Example Implementation |
|---|---|
| Block personal SaaS instance | Allow `corporate.sharepoint.com`, block `personal.sharepoint.com`; use tenant restrictions headers |
| Block upload to unsanctioned apps | Allow `box.company.com`, block all other cloud storage upload |
| Watermark downloads | Auto-watermark downloaded documents with username/date |
| Block share externally | Intercept Google Drive share dialog, block if recipient is external |
| Enforce DRM on download | Apply Azure Information Protection label on SaaS downloads |

**Microsoft Tenant Restrictions v2:**
For M365, SASE can inject `Restrict-Access-To-Tenants` header in HTTP requests, forcing the client to only authenticate to the corporate tenant — preventing access to personal Microsoft accounts or other tenants through the corporate connection.

### API CASB Integration

API CASB accesses SaaS platforms via OAuth/API to scan stored content.

**Common integrations:**
- **Microsoft 365:** Graph API — OneDrive, SharePoint, Exchange, Teams files
- **Google Workspace:** Drive API, Gmail API
- **Salesforce:** Salesforce API (data export scans)
- **Box/Dropbox:** File APIs
- **GitHub/GitLab:** Repository scanning for secrets, PII

**What API CASB can detect:**
- PII in files (SSN, credit cards, PHI)
- Overly permissive sharing (files shared with "Anyone with link")
- Sensitive data in non-compliant cloud storage
- Malware in file repositories (hash-based or sandbox scanning)
- Misconfigured SaaS security settings (e.g., MFA disabled, weak password policies)

**Remediation options:**
- Remove sharing link
- Move file to quarantine folder
- Apply encryption
- Alert file owner and security team
- Delete file (destructive — require confirmation workflow)

## DLP in SASE Context

### DLP Deployment Points

In a SASE architecture, DLP can run at multiple points:

```
Email ──────────────────────────────── Email DLP (MDO, Proofpoint, Mimecast)
Web/Cloud ─────── SWG → CASB DLP ───── Inline DLP for SaaS uploads
Endpoint ──────── DLP Agent ─────────── Endpoint DLP (Purview, Symantec DLP)
API Scanning ───── CASB API ──────────── Stored data DLP
```

### DLP Detection Techniques

**Pattern matching:**
- Regular expressions for structured data (credit cards, SSN, IBAN)
- Dictionary matching (keyword lists)
- Luhn algorithm for credit card validation (reduces false positives)

**Document fingerprinting:**
- Hash fingerprints of sensitive document templates
- Detects partial matches (document sections copied to new file)
- Used for: Tax forms, contracts, HR templates

**Exact data matching (EDM):**
- Index a structured data source (CSV of employee SSNs, customer PII database)
- Match against exact values in that index
- Very low false positive rate for structured PII

**Machine learning classification:**
- Classify document type and sensitivity without explicit patterns
- Effective for: Source code, financial models, M&A documents
- Higher false positive rate than pattern-based; use for discovery, not blocking

**UEBA integration:**
DLP + UEBA: User behavioral signals combined with DLP detections to prioritize alerts.
Example: A user who is resigning + transfers 10GB to Google Drive = highest priority DLP alert, regardless of content classification.

## UEBA (User and Entity Behavior Analytics)

### UEBA in SSE/SASE

UEBA is increasingly integrated into SASE platforms to provide behavioral context for policy decisions.

**Behavioral signals tracked:**
- Time-of-day access patterns (user normally works 8am-6pm EST; 2am access is anomalous)
- Application usage patterns (user never accessed HR system; sudden bulk HR data download)
- Data volume (user uploads 500MB/day normally; today uploaded 20GB)
- Geographic patterns (user in London; impossible to be in Sydney simultaneously)
- Device patterns (first time using unmanaged device)
- Privilege usage (admin logged in from personal laptop on weekend)

**UEBA risk scores:**
Each user has a dynamic risk score. Risk score feeds:
- Step-up authentication triggers (high risk → require MFA re-auth)
- Session termination (very high risk → disconnect and alert)
- Investigation queue prioritization
- CASB policy enforcement (high-risk user gets tighter DLP rules)

**UEBA data sources:**
- SSE/SASE proxy logs (all web traffic)
- IdP logs (authentication events)
- Endpoint telemetry (if integrated with EDR)
- Cloud platform logs (AWS CloudTrail, Azure Activity Log)
- SIEM correlation

## SD-WAN Integration

### SD-WAN as the On-Ramp to SASE

SD-WAN provides optimized WAN connectivity that feeds into the SASE security stack.

**Functions:**
- **Path selection:** Automatically route traffic over best available link (MPLS, broadband, 4G/5G) based on link quality (latency, jitter, packet loss)
- **Traffic steering:** Send cloud-destined traffic directly to internet (breakout at branch), not through data center
- **WAN optimization:** TCP optimization, compression, deduplication
- **Overlay:** Encrypted overlay tunnels between sites and to cloud

**SASE integration:**
```
Branch ─── SD-WAN ─── Direct internet breakout ─── SASE PoP ─── Internet/SaaS
       └─── SD-WAN ─── MPLS/VPN ─── Data center ─── SASE PoP ─── Internet/SaaS
Remote User ─── SASE Agent ─── SASE PoP ─── Internet/Private Apps
```

**Single-vendor SASE (Cato model):**
Cato Networks built SD-WAN and SSE as a single platform from the ground up. Single agent, single policy, single console.

**Multi-vendor SASE:**
Most enterprises combine a separate SD-WAN vendor (Cisco Meraki, Aruba, Velocloud) with a security vendor (Zscaler, Netskope). Requires integration work and dual management planes.

## Identity Integration

Zero Trust depends entirely on strong identity as the primary trust signal.

### Identity Providers (IdP)

**Enterprise IdPs:**
- Microsoft Entra ID (formerly Azure AD) — dominant in M365 environments
- Okta — IDaaS leader, SASE integration partner for all major vendors
- Ping Identity — Enterprise, government
- CyberArk Identity
- Google Identity — Google Workspace environments

**SAML vs. OIDC/OAuth:**
- **SAML 2.0:** XML-based, older, used by most enterprise SaaS apps. SSO only.
- **OIDC (OpenID Connect):** JSON/JWT based, built on OAuth 2.0. Used by modern apps. Also supports authorization (API access tokens).
- SASE platforms support both; OIDC preferred for API authorization to app connectors

### Conditional Access Integration

SASE platforms integrate with IdP Conditional Access (Entra ID CA, Okta Adaptive MFA) to enforce device posture and risk signals at authentication time.

**Entra ID Conditional Access + SASE:**
- Entra ID CA checks device compliance status (via Intune) before granting token
- SASE validates the token and applies additional session-level policies
- Hybrid approach: IdP handles authentication-time policy; SASE handles continuous session policy

**Device posture assessment signals:**
- OS version and patch level
- Disk encryption (BitLocker, FileVault)
- EDR agent presence and health
- MDM enrollment status
- Screen lock enabled
- Jailbreak/root detection
- Certificate-based device identity
