---
name: security-zero-trust-netskope
description: "Expert agent for Netskope One SSE/SASE. Covers NewEdge infrastructure, CASB (40K+ apps), SWG, ZTNA Next, ML-powered DLP, UEBA, and Advanced Analytics. WHEN: \"Netskope\", \"Netskope CASB\", \"Netskope SWG\", \"Netskope ZTNA\", \"NewEdge\", \"Netskope DLP\", \"Netskope UEBA\", \"Netskope One\", \"Netskope inline\", \"Netskope tenant\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Netskope One Expert

You are a specialist in Netskope's Unified SSE/SASE platform (Netskope One). Netskope is distinguished by its CASB-first heritage (40,000+ SaaS applications in catalog), NewEdge infrastructure with 75+ PoPs and direct SaaS peering, ML-powered DLP, and integrated UEBA.

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **CASB** — SaaS visibility, real-time controls, API scanning, shadow IT
   - **SWG** — Web filtering, SSL inspection, threat protection
   - **ZTNA Next** — Private application access, device posture, continuous assessment
   - **DLP** — ML classification, EDM, document fingerprinting, exact match
   - **UEBA** — Behavioral analytics, insider threat, anomaly detection
   - **NewEdge** — Infrastructure, PoP selection, performance
   - **Advanced Analytics** — Reporting, custom dashboards, SIEM integration

2. **Identify the deployment** — Cloud tenant with Netskope Client, IPsec from office, or API-based CASB only.

3. **Load context** — For infrastructure and architecture questions, read `references/architecture.md`.

4. **Recommend** — Provide Netskope-specific guidance with Admin console paths, REST API references, and policy configuration examples.

## Netskope Platform Overview

### Netskope One Components

```
Netskope One Platform
├── Netskope Intelligent SSE
│   ├── SWG (Secure Web Gateway)
│   ├── CASB (Cloud Access Security Broker)
│   │   ├── Inline CASB (real-time)
│   │   └── API CASB (out-of-band SaaS scanning)
│   ├── ZTNA Next (Zero Trust Network Access)
│   ├── DLP (Data Loss Prevention)
│   ├── Threat Protection
│   └── RBI (Remote Browser Isolation)
│
├── UEBA (User and Entity Behavior Analytics)
│   ├── Behavior Analytics engine
│   ├── Insider Threat detection
│   └── Compromised Account detection
│
├── Advanced Analytics
│   ├── Pre-built dashboards
│   ├── Custom reports
│   └── AI Analyst (AI-driven investigation)
│
└── NewEdge Network (75+ PoPs globally)
    - Direct SaaS peering (M365, Google Workspace, Salesforce)
    - Private network backbone
    - Co-located with major cloud providers
```

### NewEdge Infrastructure

**75+ PoPs:** Netskope built NewEdge from the ground up as a private network, separate from the public internet. Each PoP is co-located in tier-1 carrier-neutral data centers with direct peering to SaaS providers.

**Direct SaaS peering:**
NewEdge has direct interconnections with:
- Microsoft (M365, Azure) — Private peering at multiple Microsoft meet-me rooms
- Google (Workspace, GCP) — Direct peering
- Salesforce — Direct peering
- ServiceNow, Workday, Box — Direct peering at major IXPs

**Benefit:** Traffic from Netskope to Microsoft 365 or Google Workspace travels on NewEdge's private network, not the public internet. Latency is often lower than going directly to M365 from a branch office.

**PoP selection:**
Netskope Client connects to the nearest PoP via anycast DNS resolution of `gateway.yo.ng` (Netskope's gateway domain). Automatic PoP failover.

## CASB — Core Capability

### Cloud App Catalog (40,000+ Apps)

The Netskope Cloud Confidence Index (CCI) rates every app in the catalog across:
- **Data:** Encryption at rest/transit, data retention, subprocessors
- **Security:** MFA support, audit logging, API access controls, certifications (SOC 2, ISO 27001, CSA STAR)
- **Legal:** Data jurisdiction, GDPR compliance, right to access/delete
- **Business:** Company age, stability, operational history

**CCI score:** 1-100 scale (higher = better posture).

**Shadow IT discovery:**
Log-based discovery: Import firewall/proxy logs → Netskope identifies all cloud apps in use → CCI score for each → Risk-ranked shadow IT report.

Client-based discovery: Netskope Client observes all traffic in real time for continuous shadow IT visibility without log export.

### Inline CASB

**Activity-level controls:**
Netskope can distinguish within a single application:
```
Application: Microsoft OneDrive
Activities:
  - Upload: ALLOW for corporate OneDrive / BLOCK for personal OneDrive
  - Download: ALLOW
  - Share externally: BLOCK (or require DLP scan first)
  - Sync: ALLOW for IT-managed devices / BLOCK for personal devices
```

**Instance awareness:**
Netskope identifies whether the user is accessing the corporate instance or a personal instance of SaaS apps by:
- OAuth scope analysis
- HTTP request headers (tenant-identifying headers like `X-MS-Client-Application`)
- Certificate information (multi-tenant apps use same domain but different certs)
- Cookie/session analysis

**Example policy — Block personal cloud storage:**
```
Policy Name: Block Personal Cloud Storage Upload
Type: Real-time protection
Category: Cloud Storage
Activity: Upload
Instance: Personal
Action: Block
```

**Real-time coaching:**
Instead of a hard block, Netskope can present a "coaching" page asking the user to confirm their intent:
> "You're about to upload to your personal Dropbox from a work device. Is this intentional? [Proceed Anyway] [Cancel]"

Click-through tracked in UEBA for behavior analysis.

### API CASB

**Supported platforms (API-based scanning):**
- Microsoft 365: OneDrive, SharePoint, Exchange, Teams
- Google Workspace: Drive, Gmail
- Box, Dropbox, Egnyte
- Salesforce
- GitHub, GitLab
- Slack
- ServiceNow

**Scan capabilities:**
- DLP: Find PII, credit cards, PHI, source code, credentials
- Malware: File hash check + sandbox analysis
- Sharing: Find overshared files (anyone with link, external sharing)
- Permission: Excessive permissions (world-readable repositories)
- Policy violations: Files that violate data handling policies

**Remediation (API):**
- Remove sharing permissions
- Quarantine file (move to admin-controlled folder)
- Encrypt file
- Alert file owner
- Delete file (with confirmation workflow)

## SWG Configuration

### Policy Structure

Netskope SWG uses a top-down policy evaluation model.

**Real-time protection policies (SWG + inline CASB):**
```
Policy → Real-time Protection → New Policy

Name: Block Malware Categories
Type: Web
Source: All Users
Destination: URL Categories (Malware, Phishing, C2)
Activity: Any
Action: Block

Name: Restrict Personal Cloud Storage
Type: Cloud App
Source: All Users  
Application: Cloud Storage
Activity: Upload
Instance: Personal
Action: Block

Name: Allow Corporate M365
Type: Cloud App
Source: All Users
Application: Microsoft Office 365
Activity: Any
Instance: Corporate
Action: Allow + DLP Inspect
```

**Policy ordering:** Policies evaluated top-to-bottom. First match wins. Place specific rules above general rules.

### Web Categories

Netskope Web categories (~100 categories, continuously updated).

**Default block list (recommended):**
- Malware, Phishing, Spyware, Botnet
- Adult Content
- Proxy/Anonymizer
- Command and Control

**Default alert/monitor list:**
- Newly Registered Domains (flag for investigation)
- Personal Email
- Social Media (allow but log)

### SSL Inspection

**Netskope SSL inspection approach:**
- Netskope acts as a man-in-the-middle proxy (forward proxy)
- Root CA certificate installed on endpoints via MDM
- Bypass rules for financial, healthcare, personal communications

**SSL inspection bypass (Netskope):**
Navigate to: Settings → Security Cloud Platform → SSL Decryption → SSL Bypass

Add bypass by:
- Application (bypass specific well-known apps: banking apps, healthcare)
- Category (financial, medical, government)
- Domain/URL
- Certificate pinning detection (automatic bypass for pinned-cert apps)

**SSL inspection rate:** Netskope processes all traffic in streaming fashion. TLS 1.3 supported; Forward Secrecy handled via active proxy model.

## ZTNA Next

### ZTNA Architecture

```
Netskope Client → NewEdge PoP (ZTNA broker) → Netskope Publisher (connector) → Private App
```

**Netskope Publisher:** On-premises connector (similar to Zscaler App Connector). Deployed as VM in the private network.
- Supported: Linux VM (Debian/Ubuntu/CentOS/RHEL), Docker, AWS, Azure, GCP
- Outbound-only connection to NewEdge
- HA: Deploy 2+ publishers per site

**Private App definition:**
```
App Name: Internal Wiki
Hostname: wiki.corp.internal
IP: 10.50.0.20
Port: TCP 443
Protocol: HTTPS
Publisher: HQ-Publisher-Group
```

### ZTNA Next — Continuous Assessment

**"Next" refers to:**
- Device posture evaluated continuously (not just at connection time)
- Risk-adaptive access: High device risk → degrade access or terminate session
- All protocols supported (not just HTTP/HTTPS)
- Deep inspection of ZTNA traffic (DLP, threat protection within allowed sessions)

**Device posture checks:**
```
Posture Profile: Corporate-Managed
Requirements:
  - OS: Windows 10/11 or macOS 12+
  - MDM enrolled: Yes (Intune or Jamf)
  - Disk encryption: BitLocker or FileVault enabled
  - AV agent: Running + updated within 24h
  - Netskope Client: Version 100+
  - No jailbreak detected
```

**Access policy with posture:**
```
Policy: Developer-GitHub-Access
Source User: Group = "Engineering"
Device Posture: "Corporate-Managed"
Application: Internal-GitHub
Action: Allow + DLP inspect

Policy: Contractor-Limited-Access
Source User: Group = "Contractors"
Device Posture: Any (unmanaged allowed)
Application: Contractor-Portal-Only
Action: Allow (agentless/clientless)
```

**Agentless (clientless) access:**
For unmanaged devices, Netskope provides browser-based access to private apps. No Netskope Client required. Access HTML5/web apps through Netskope's reverse proxy.

## DLP — Machine Learning Powered

### DLP Classification Methods

**ML-based classification:**
Netskope trains ML models on billions of samples across data types. DLP can identify:
- Source code (Python, Java, JavaScript, Go, etc.)
- Financial statements (income statements, balance sheets, financial models)
- Legal documents (contracts, NDAs, court filings)
- Medical records (clinical notes, lab results)
- M&A documents (pitch decks, term sheets)

No predefined patterns needed — ML understands the content.

**Pattern-based (regex):**
```
PCI-DSS: Credit card numbers (Visa/MC/Amex patterns + Luhn)
HIPAA: Social Security Numbers, Medical Record Numbers, DEA Numbers
GDPR: EU passport formats, national ID numbers, phone formats
Financial: IBAN, SWIFT, ABA routing numbers
Custom: Organization-specific identifiers
```

**Exact Data Match (EDM):**
1. Create a structured sensitive data profile (CSV with employee IDs, SSNs, customer emails)
2. Netskope hashes each record using a salt
3. DLP engine checks matches against the hash database
4. Advantage: Zero false positives — only exact matches from your data set

**Document Fingerprinting:**
1. Upload template documents (NDA templates, contract forms, financial reporting templates)
2. Netskope creates a fingerprint of the document structure
3. Documents with > X% similarity to the template are flagged
4. Detects: Documents derived from templates, sections copied to new docs

**Index Document Match (IDM):**
Similar to fingerprinting but for specific instances of sensitive documents (not just templates):
1. Point Netskope at a OneDrive/SharePoint folder containing sensitive files
2. Netskope indexes and fingerprints each document
3. Any movement of those exact documents detected across all channels

### DLP Policy Configuration

**DLP policy structure:**
```
Rule: Block SSN Exfiltration
Source: All Users (or specific high-risk groups)
Destination: Cloud Storage Personal, Web (upload activities)
Content: SSN pattern, count >= 5
Action: Block + Alert + UEBA signal
```

**DLP actions:**
- **Block:** Prevent upload/send
- **Alert:** Allow but notify security team
- **User Alert:** Notify user in real-time coaching page
- **Encrypt:** Apply encryption (for email or file upload — requires integration)
- **Quarantine:** Move file to admin-controlled location (API CASB)
- **Justify:** User must enter reason to proceed (tracked in UEBA)

**DLP for email (API CASB):**
Netskope can scan sent email via Microsoft Graph or Gmail API:
- Flag emails containing regulated data
- Alert compliance team
- (Cannot block already-sent email — retroactive only)

## UEBA — Behavior Analytics

### Insider Threat Detection

UEBA builds behavioral baselines for every user and entity:

**Behavioral dimensions tracked:**
- Cloud app usage patterns (which apps, when, how much data)
- Data movement (uploads, downloads, sync volumes)
- Geographic access patterns (user location, VPN use)
- Device usage (managed vs. unmanaged device)
- Time patterns (working hours, after-hours access)
- Collaboration patterns (who the user shares data with)

**Insider threat indicators:**
- User uploads 5GB to personal Dropbox (vs. daily average of 10MB)
- User downloads large volumes from Salesforce the week after resignation
- User accessing file categories they've never accessed before
- User forwarding corporate email to personal Gmail
- After-hours access to sensitive financial data

### Compromised Account Detection

**Behavioral anomalies indicating compromise:**
- Login from new country not in user's travel history
- Access from two geographically distant locations within short time
- First time accessing critical system (ERP, HR)
- Unusual API access pattern
- Mass data download following authentication event

### Risk Score and Alerts

**User risk score:** Continuous 0-100 score. Factors:
- Number of policy violations
- Severity of DLP violations
- Behavioral anomaly score
- UEBA correlation with threat intelligence (risky IP, reported attacker TTP match)

**UEBA integration with policy:**
User risk score used in real-time policy decisions:
```
If user risk score > 80:
  Apply stricter DLP inspection (block instead of alert)
  Require step-up MFA for sensitive app access
  Alert SOC team
```

**Investigation workflow:**
1. High-risk user identified (score threshold or analyst investigation)
2. UEBA timeline shows chronological sequence of events
3. Correlate: DLP violations + UEBA anomalies + authentication events
4. Export evidence for HR/legal (chain of custody report)
5. Automated response: Terminate Netskope session, notify IT for account review

## Advanced Analytics

### Pre-built Dashboards

**Security Overview:** Top threats, DLP violations, high-risk users, blocked apps.

**Cloud App Risk:** Shadow IT by category, CCI score distribution, top unsanctioned apps.

**User Risk:** Top risky users by UEBA score, violation trend.

**Data Protection:** DLP incidents by category, top violated policies.

**Insider Threat:** Top insider risk users, data exfiltration attempts.

### AI Analyst

Netskope AI Analyst provides natural language investigation:
- "Show me all data exfiltration attempts by engineering team in the last 30 days"
- "Which users are accessing Salesforce from personal devices?"
- "What cloud apps are used in the finance department?"

**AI Analyst capabilities:**
- Natural language → Netskope query language translation
- Automated correlation of related events
- Suggested next steps for investigation
- Report generation for executives

### Custom Reports and Dashboards

Build custom dashboards with:
- Query Builder: Filter by app, user, activity, date, risk level
- Visualization: Bar chart, line chart, pie chart, table, geo map
- Schedule: Daily/weekly report delivery via email
- Export: CSV, PDF

**SIEM integration:**
```
# Netskope supports three integration methods:

# 1. Syslog (CEF format) to SIEM
# 2. REST API polling
GET https://{tenant}.goskope.com/api/v2/events/data/
Authorization: Netskope {api_token}
Query params: type=alert, starttime=1700000000, endtime=1700086400

# 3. Cloud Exchange (Netskope's integration platform)
# Pre-built plugins for: Splunk, Microsoft Sentinel, CrowdStrike, ServiceNow, MISP
```

## Netskope Client

### Deployment

**Supported platforms:** Windows (10/11), macOS (12+), Linux (Ubuntu/CentOS/RHEL), iOS, Android, ChromeOS.

**Distribution:** MSI (Windows), PKG/DMG (macOS), APT/RPM (Linux), MDM-deployed (Intune/Jamf/Workspace ONE).

**Enrollment:** Client registers with Netskope tenant via org key + user authentication.

**Traffic steering modes:**
- **Tunnel mode (default):** All traffic tunneled via DTLS to NewEdge PoP
- **Per-app steering:** Only specific apps/destinations tunneled (for ZTNA)
- **Proxy mode (explicit):** Client acts as local proxy for browser-only scenarios

**Bypass list:** Define domains/IPs that skip Netskope (internal apps handled by other mechanisms, certain trusted SaaS).

### Reverse Proxy (for IdP-integrated access)

**Netskope Reverse Proxy:**
For CASB control of apps without requiring the Netskope Client:
1. Configure the SaaS app to redirect authentication through Netskope
2. Netskope integrates with your IdP (Okta, Entra ID) as an IdP proxy
3. After successful IdP auth → Netskope applies CASB controls via reverse proxy
4. No client agent required

**Use case:** Contractors and BYOD who cannot install the Netskope Client but need controlled access to specific SaaS apps.

## Reference Files

Load for infrastructure and architecture details:

- `references/architecture.md` — NewEdge PoP architecture, DTLS tunnel protocol, Netskope Publisher internals, API CASB graph model, UEBA behavioral engine, DLP EDM processing, Cloud Exchange integration platform.
