# Netskope One — Architecture Reference

## NewEdge Network Architecture

### Infrastructure Design Principles

NewEdge was designed from the ground up as a private, purpose-built network for security processing — not a repurposed CDN or transit network.

**Design goals:**
1. Low latency to SaaS providers (direct peering, not public internet routing)
2. Compute-rich PoPs (full security processing at every PoP, not a hub-and-spoke)
3. Carrier-neutral data centers (choose best connectivity per region)
4. Elastic scaling (SaaS-native, not hardware-constrained)

**PoP architecture:**
```
NewEdge PoP (e.g., Amsterdam)
├── Network Layer
│   ├── Carrier-neutral data center (Equinix AM3/AM5)
│   ├── Direct peering: Microsoft (Express Route), Google (Cloud Interconnect)
│   ├── IXP peering: AMS-IX, NL-IX (for SaaS traffic)
│   └── Upstream: Multiple Tier-1 carriers (redundant)
│
├── Security Processing Layer
│   ├── SSL/TLS inspection engine (custom hardware acceleration)
│   ├── DLP processing cluster (ML inference, EDM matching)
│   ├── CASB inspection engine
│   ├── Threat protection engine
│   ├── UEBA telemetry collection
│   └── ZTNA broker
│
└── Control Plane
    ├── Policy engine (tenant-specific policy evaluation)
    ├── Telemetry aggregation (feeds Advanced Analytics)
    └── Health monitoring
```

### NewEdge vs. Competitors

| Dimension | Netskope NewEdge | Zscaler | Cloudflare |
|---|---|---|---|
| PoPs | 75+ | 150+ | 300+ |
| Peering model | Direct SaaS peering, private backbone | Direct SaaS peering | Anycast CDN/network |
| Processing | Full security stack at each PoP | Full security stack at each ZEN | Full security stack at edge |
| Heritage | CASB-first | SWG/proxy-first | CDN/network-first |

**Netskope's peering advantage for M365:**
Netskope routes M365 traffic via NewEdge's direct interconnect to Microsoft, typically resulting in latency comparable to (or better than) connecting directly to M365 from a corporate office without optimization.

## DTLS Tunnel Architecture

### Netskope Client Tunnel

Netskope Client uses DTLS (Datagram TLS) over UDP for tunneling, with TCP/443 fallback.

```
Netskope Client
├── Kernel Extension (macOS) or NDIS Driver (Windows)
│   - Intercepts all IP traffic
│   - Applies steering policy (tunnel vs. bypass)
│
├── DTLS Tunnel to NewEdge PoP
│   - UDP/4500 primary
│   - TCP/443 fallback (for restricted networks)
│   - Mutual TLS authentication (client cert + server cert)
│
└── Split Tunnel Logic
    - Corporate traffic → tunnel
    - Bypass list → direct
    - M365 Optimize → direct (optional)
```

**Traffic classification engine:**
Before sending traffic to the tunnel, the Netskope Client classifies each connection:
1. Destination matches bypass list → Send direct
2. Destination is private app (ZTNA) → Route via ZTNA path within NewEdge
3. All other traffic → Route via SSL inspection path

**Multi-homed endpoints:**
When a device has both WiFi and wired connections, Netskope Client chooses the primary path and routes all tunnel traffic through it (avoids asymmetric routing).

## Netskope Publisher (ZTNA Connector) — Internals

### Publisher Architecture

```
Netskope Publisher VM
├── Outbound-only connections
│   ├── Control channel: TCP 443 to Netskope cloud control plane
│   │   - Registration, configuration, health reporting
│   └── Data plane: DTLS tunnel to NewEdge PoP(s)
│       - Pre-established for low session setup latency
│
├── DNS resolution
│   - Publisher resolves private app FQDNs using local DNS servers
│   - Required: Publisher must be in same DNS domain as private apps
│   - Or: Configure private DNS servers in Publisher config
│
└── Application proxy
    - TCP/UDP proxy to backend applications
    - Handles connection multiplexing from multiple user sessions
```

**Publisher health monitoring:**
Publishers report health every 30 seconds:
- CPU utilization
- Memory utilization
- Active session count
- Connection pool status
- Last heartbeat to Netskope cloud

**Publisher auto-update:**
Publishers can be configured for automatic updates. Netskope pushes Publisher software updates through the control channel.

### ZTNA Session Flow (Detailed)

```
Step 1: Client authentication
Netskope Client → NewEdge ZTNA broker
Carries: User identity (from IdP), device posture profile, requested app FQDN

Step 2: Policy evaluation
ZTNA broker → Policy engine
Checks: User group membership, device posture (score, compliant/non-compliant), app access policy
Result: Allow / Deny / Allow with conditions

Step 3: Publisher selection
ZTNA broker → select Publisher Group serving the requested app
Selection: Publisher with lowest load + network affinity (prefer Publisher closest to NewEdge PoP)

Step 4: Session establishment
ZTNA broker proxies session:
  Client ↔ NewEdge PoP ↔ Publisher ↔ Private App

Step 5: DLP/Threat inspection (ZTNA Next)
All traffic in the session passes through the NewEdge security stack:
  - DLP policy evaluated on all transfers
  - Threat prevention on all payloads
  - Session activity logged to Advanced Analytics

Step 6: Continuous posture check
Every 60 seconds: Device posture re-evaluated
If posture degrades: Session terminated or step-down to restricted policy
```

## DLP Processing Architecture

### EDM (Exact Data Match) Processing

EDM allows matching against a structured database of sensitive data without storing the raw data in Netskope.

**EDM setup process:**
```
1. Customer prepares CSV with sensitive data (employee SSNs, customer PII)
   Format: header_row + data_rows

2. Customer runs local Netskope EDM client tool
   Tool: Hashes each row using HMAC-SHA256 with a customer-controlled salt
   Output: Hashed index file (no raw PII)
   
3. Customer uploads hashed index to Netskope (not the raw CSV)
   Netskope stores: Hashed index only

4. At inspection time: Netskope DLP engine
   Extracts potential PII from inspected content
   Hashes candidate values with same salt
   Compares against stored hash index
   Match = DLP violation

5. False positive rate: Near-zero (only exact matches from original data set)
```

**EDM data types supported:**
- Single column match (e.g., SSN column: any SSN from the dataset)
- Multi-column AND match (e.g., First Name + Last Name + SSN = higher confidence)
- Record count threshold (e.g., 10+ records in a single file = violation)

### ML DLP Classification

**Model architecture (simplified):**
```
Input: Document text/content
        ↓
Text preprocessing: Tokenization, normalization
        ↓
Feature extraction: TF-IDF, word embeddings, document structure features
        ↓
ML classifier: Multi-class model (trained on millions of labeled samples)
        ↓
Output: Content type (source code / financial / legal / medical / etc.)
        Confidence score (0.0-1.0)
        ↓
Policy decision: If confidence > threshold → apply DLP action
```

**Continuous model improvement:**
Analyst feedback (false positive / true positive confirmation) is fed back to improve models. Tenant-specific fine-tuning is available for large customers.

**Netskope DLP performance:**
- Sub-50ms classification for most document types
- Streaming analysis for large files (no buffering entire file)
- DLP verdict cached for identical file hashes (avoid re-processing identical uploads)

## API CASB Graph Model

### Data Model

Netskope builds a graph model of all API-connected SaaS environments:

```
Tenant (Microsoft 365)
├── Users
│   ├── User A
│   │   ├── Files owned: 1,247 files
│   │   ├── Files shared externally: 23 files (flags for review)
│   │   └── Email sent: 5,432 emails (sampled for DLP)
│   └── User B
│       └── ...
├── Sites (SharePoint)
│   ├── HR-Site
│   │   ├── Members: HR-Group
│   │   ├── Public link: No
│   │   └── Files containing PII: 142 files (DLP finding)
│   └── Marketing-Site
│       ├── Public link: YES ← Misconfiguration finding
│       └── ...
└── Applications
    ├── OAuth app: "Marketing Analytics Tool"
    │   ├── Permissions: Mail.Read, Files.ReadWrite.All (over-privileged)
    │   └── Last used: 180 days ago (orphaned)
    └── ...
```

**Remediation actions from graph:**
- Remove external sharing from specific files
- Revoke OAuth app permissions
- Alert file owner
- Apply sensitivity label

## UEBA Behavioral Engine

### Behavioral Model Construction

For each user, Netskope builds a multi-dimensional behavioral model:

**Baseline period:** 30 days (configurable). Netskope establishes "normal" for each behavioral dimension.

**Behavioral dimensions:**

```
User behavioral profile:
├── Temporal patterns
│   ├── Active hours: Mon-Fri, 8am-7pm EST (high confidence after 30 days)
│   ├── Peak upload: Tuesdays 10am-12pm
│   └── Weekend access: Rare (< 5% of sessions)
│
├── Application profile
│   ├── Regular apps: M365, Salesforce, Workday, Zoom, Slack
│   ├── Cloud storage: OneDrive corporate (daily), Box corporate (weekly)
│   └── Personal apps: Zero (no personal cloud storage use)
│
├── Data movement profile
│   ├── Average daily upload: 45MB
│   ├── Average daily download: 250MB
│   └── External sharing: 2-3 files/week to known domains
│
├── Geographic profile
│   ├── Primary: New York, NY (US-East-1 VPN zone)
│   ├── Travel: Quarterly (London, San Francisco)
│   └── Always via managed device
│
└── Collaboration profile
    ├── Regular recipients: {list of known contacts}
    ├── Internal sharing: Primarily to same department
    └── External sharing: Primarily to {known customer domains}
```

**Anomaly scoring:**
Each event is scored against the behavioral model. Deviations increase the anomaly score:
- 10GB upload to personal Dropbox: +40 anomaly points (vs. normal 0)
- 3am login from China: +60 anomaly points (vs. normal < 1)
- Access to 50 unusual files: +30 anomaly points

**Aggregate risk score:** Weighted sum of recent anomaly events with time decay.

### Insider Threat Playbooks

Netskope UEBA has pre-built playbooks for common insider threat scenarios:

**Departing employee playbook:**
```
Trigger: HRIS integration reports resignation or termination date
Monitoring profile:
  - Elevate DLP sensitivity (alert → block for sensitive data)
  - Watch for mass download or upload events
  - Track any new external sharing
  - Monitor for credential sharing or access delegation
Timeline: 30 days before departure through last day
```

**Privilege escalation playbook:**
```
Trigger: User granted elevated privileges (admin role in SaaS, file access expansion)
Monitoring:
  - Watch for access to data outside normal work scope
  - Monitor bulk access to sensitive files
  - Alert if new privilege used within 24h of granting
```

**Data staging playbook:**
```
Signals:
  - Large download volume from corporate sources (OneDrive, SharePoint, Salesforce)
  - Small uploads to cloud destinations shortly after
  - Access at unusual hours preceding departure
Correlation: UEBA + DLP events + access time anomaly
Action: Alert SOC + elevate to Departing Employee playbook if applicable
```

## Cloud Exchange (CEX) Integration Platform

Netskope Cloud Exchange is a purpose-built integration hub connecting Netskope with the security ecosystem.

**Cloud Threat Exchange (CTE):**
Bi-directional threat intelligence sharing:
- Import IOCs (IPs, domains, URLs, hashes) from threat intel feeds → Netskope blocks these
- Export Netskope-detected threats to SIEM, SOAR, firewall feeds

**Cloud Risk Exchange (CRE):**
Share risk scores between Netskope and identity/endpoint platforms:
- Netskope user risk score → Okta / Entra ID (trigger step-up MFA for high-risk users)
- CrowdStrike device risk score → Netskope (apply stricter DLP for compromised devices)

**Cloud Log Shipper (CLS):**
Stream Netskope logs to SIEM/SOAR:
- Pre-built plugins: Splunk, Microsoft Sentinel, IBM QRadar, Google Chronicle
- Format: CEF, JSON, raw syslog

**Cloud Ticket Orchestrator (CTO):**
Create tickets in ITSM systems from Netskope alerts:
- ServiceNow
- Jira
- PagerDuty

**Cloud Exchange deployment:**
Cloud Exchange is deployed as a Docker container (on-premises or cloud VM).

```yaml
# docker-compose.yml excerpt
services:
  netskope-ce:
    image: netskopetechnologies/cloud-exchange:latest
    ports:
      - "8080:8080"
    environment:
      - CE_SECRET_KEY=your_secret_key
    volumes:
      - /opt/netskope-ce/data:/data
```
