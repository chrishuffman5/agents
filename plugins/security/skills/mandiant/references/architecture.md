# Mandiant Platform Architecture Reference

## Mandiant Advantage Platform

### Architecture Overview

Mandiant Advantage is a SaaS platform built on Google Cloud infrastructure (post-2022 acquisition).

```
Mandiant Intelligence Production
  ├── IR Engagements (front-line data)
  ├── Research Team (APT/UNC/FIN analysis)
  ├── Malware Reverse Engineering
  ├── Vulnerability Research
  └── Open Source Collection
         ↓
Mandiant Intelligence Database
  ├── Actor Profiles (APT/UNC/FIN)
  ├── Campaign Records
  ├── Malware Families
  ├── IOC Library
  ├── Vulnerability Intelligence
  └── Event Records (news, advisories, etc.)
         ↓
Advantage API (REST + GraphQL)
         ↓
Advantage Modules:
  ├── Threat Intelligence (portal + API)
  ├── Breach Analytics (SIEM connector)
  ├── Attack Surface Management
  ├── Digital Threat Monitoring
  └── Security Validation
```

### Intelligence Database Scale

- Actor profiles: 2,000+ threat actors (APT, UNC, FIN, ransomware groups, hacktivists)
- Malware families: 4,000+ tracked families
- IOCs: Tens of millions (curated; not raw community IOC dumps)
- Reports: Thousands of finished intelligence reports
- Vulnerabilities: All CVEs with exploitation evidence overlay

### API Architecture

**Base URL:** `https://api.intelligence.mandiant.com`

**Authentication:** API key via HTTP header
```
X-App-Name: my-integration
Authorization: Bearer {api_key}
```

**Key endpoints:**

```
# Threat actors
GET /v4/actor  -- List all actors
GET /v4/actor/{actor_id}  -- Actor profile
GET /v4/actor/{actor_id}/indicators  -- IOCs associated with actor

# Malware
GET /v4/malware  -- List malware families
GET /v4/malware/{malware_id}  -- Malware profile
GET /v4/malware/{malware_id}/indicators  -- IOCs for malware family

# Indicators
GET /v4/indicator  -- Search indicators
GET /v4/indicator/{indicator_id}  -- Single indicator

# Reports
GET /v4/report  -- List intelligence reports
GET /v4/report/{report_id}  -- Full report
GET /v4/report/{report_id}/indicators  -- IOCs extracted from report

# Vulnerabilities
GET /v4/vulnerability  -- List vulnerabilities
GET /v4/vulnerability/{cve_id}  -- CVE details with Mandiant context

# Campaigns
GET /v4/campaign  -- List campaigns
GET /v4/campaign/{campaign_id}  -- Campaign details
```

**STIX Export:**
Mandiant provides STIX 2.1 output via API:
```
GET /v4/actor/{id}?format=stix2.1
GET /v4/indicator?format=stix2.1&updated_since=2024-11-01T00:00:00Z
```

**TAXII Server:**
Mandiant exposes a TAXII 2.1 server for bulk indicator consumption:
- Discovery: `https://advantage.mandiant.com/taxii2/`
- Collections: `indicators`, `actor`, `malware`, `vulnerability`

---

## Breach Analytics Architecture

### Connector Architecture

**Splunk connector:**
1. Install Mandiant Breach Analytics app from Splunkbase
2. Configure Mandiant API credentials
3. Connector creates scheduled searches that compare log data against Mandiant IOC lookup tables
4. Lookup tables refreshed every few hours with latest Mandiant IOCs
5. Matches create Notable Events in Splunk with Mandiant context

**Microsoft Sentinel connector:**
1. Deploy Mandiant-Sentinel Logic App (Azure Marketplace)
2. Logic App polls Mandiant API for new IOCs
3. IOCs ingested into Sentinel Threat Intelligence Indicators table
4. Sentinel built-in Threat Intelligence Matching Analytics rules alert on indicator matches
5. Matching incidents enriched with Mandiant context via Logic App enrichment step

**Google SecOps (Chronicle):**
- Native integration (both Google products)
- GTI indicators automatically available in SecOps without separate connector
- SecOps YARA-L rules reference GTI lookups directly

### IOC Curation (Quality Differentiation)

Mandiant's IOC curation process:
1. IOC discovered (from IR, research, open sources)
2. Analyst review: Confirm this is genuinely malicious; assess attribution confidence
3. Confidence rating assigned (Confirmed, Likely, Possible)
4. Expiry date set (based on how long this IOC is expected to remain malicious)
5. IOC enters Breach Analytics database with full context chain (actor → malware → IOC)

**False positive mitigation:**
- Mandiant explicitly marks widely-used infrastructure as "benign" (CDNs, Tor exit nodes, hosting providers commonly used by legitimate services)
- Before adding a suspicious IP, check: Is this a shared hosting IP serving millions of legitimate sites?
- IOC confidence levels prevent auto-blocking of low-confidence indicators

---

## Attack Surface Management Architecture

### Discovery Engine

**Seed data:** Customer provides seed data to initiate discovery:
- IP ranges
- Domain names
- ASN numbers
- Organization name (used for certificate transparency search)

**Discovery techniques:**
1. **DNS enumeration**: Brute-force subdomain discovery, zone transfers (if misconfigured), certificate transparency logs
2. **Reverse IP lookups**: Which domains share your IP? (shared hosting detection)
3. **Passive DNS**: Historical DNS records to find assets that have changed or been forgotten
4. **Certificate transparency**: Any TLS certificate issued for *.yourdomain.com reveals subdomains
5. **Port scanning**: Light scan of discovered IPs for open ports and service fingerprinting
6. **Web crawling**: Index discovered web properties for technology fingerprinting
7. **Search engine dorking**: Passive discovery via Google, Bing indexed results

**Technology fingerprinting:**
- HTTP response headers (`Server:`, `X-Powered-By:`, etc.)
- HTML meta tags and comments
- JavaScript library detection
- Cookie names (CMS/framework-specific)
- Response patterns (error page format, login page structure)

### Vulnerability Mapping

After discovery, ASM maps vulnerabilities:
1. Fingerprinted technology (e.g., Apache 2.4.49)
2. CVE lookup against fingerprinted versions
3. Mandiant exploitation intelligence overlay (is this CVE being actively exploited?)
4. Risk score: Critical (actively exploited in wild) > High (PoC available) > Medium (theoretical)

### Integration with Threat Intelligence

ASM surfaces when discovered assets are specifically targeted:
- "Your Citrix Netscaler version (discovered on vpn.example.com) is being actively exploited by APT41 via CVE-2023-4966"
- "New subdomain discovered: staging.example.com -- running outdated WordPress (5.8) with known exploitation activity"

---

## Digital Threat Monitoring Architecture

### Collection Infrastructure

**Dark web access:**
- Mandiant maintains authenticated access to closed dark web forums and markets
- Analyst-operated accounts (not automated scraping) for access to invite-only communities
- Human OSINT analysts monitor high-value channels in real time

**Automated collection:**
- Web crawlers for paste sites, code repositories, social media (public)
- API integrations for accessible platforms
- RSS/feed monitoring for threat actor publications (blogs, Telegram channels)

### Alert Processing

1. Raw content collected
2. NLP entity extraction (company names, email domains, credential patterns)
3. Pattern matching against customer-defined monitoring terms
4. Priority scoring: Dark web forum post about your company > blog post about your industry
5. Alert delivered to customer portal + notification channels

### Monitoring Configuration

**Monitoring terms (customer-defined):**
- Company name and variations
- Domain names
- Executive names (optional)
- Product names
- Key IP ranges (monitoring for discussion of attacking your IPs)
- Keyword patterns specific to your industry

---

## Security Validation Architecture

### Validation Execution Environment

**Network validation:**
- Customer deploys network sensor in monitored network segment
- Mandiant sends malicious traffic patterns to/from sensor
- Sensor records whether traffic was blocked, alerted, or passed silently
- Results compared to expected detection behavior for the simulated threat actor TTP

**Endpoint validation:**
- Customer deploys agent on Windows endpoint (with admin privileges)
- Agent receives TTP execution instructions from Mandiant platform
- TTP executed locally (e.g., Mimikatz credential dump, registry persistence, LSASS access)
- EDR behavior recorded: Blocked, Alerted (unblocked), or Silent
- Safe execution: Payloads are simulated or sanitized to avoid real damage; focus is on detection behavior

**Email validation:**
- Mandiant delivers simulated phishing via configured email gateway
- Tests: Attachment-based (malicious macro simulation), link-based (simulated malicious URL)
- Email gateway and endpoint results captured

### ATT&CK Coverage Mapping

Results are mapped to ATT&CK matrix:
```
Initial Access > Phishing > Spearphishing Attachment [T1566.001]
  - Email gateway: BLOCKED ✓
  - Endpoint (file opened): ALERTED ✓

Execution > Command and Scripting Interpreter > PowerShell [T1059.001]
  - EDR: SILENT ✗ (coverage gap)
```

**Prioritization by actor relevance:**
- For each coverage gap, Mandiant shows: "Which tracked threat actors use this technique?"
- If APT29 uses T1059.001 and you have no detection: High priority to fix
- If an obscure actor you don't track uses it: Lower priority

---

## Google SecOps Integration

### Unified Console Architecture

In the Google SecOps (Chronicle) console, GTI is embedded:

**Entity overview panel:**
- Analyst clicks any IP, domain, or hash in a SIEM event
- Right panel shows GTI Intelligence Card inline
- No separate login; same Google Cloud SSO

**YARA-L rule integration:**
- Mandiant publishes YARA-L rules for actor TTPs
- Import via SecOps Rules Editor
- Rules reference GTI threat intelligence lookups as enrichment sources

**Example YARA-L rule referencing GTI:**
```
rule mandiant_apt29_lolbas_execution {
  meta:
    author = "Mandiant"
    description = "APT29 Living-off-the-land binary execution pattern"
    
  events:
    $e.metadata.event_type = "PROCESS_LAUNCH"
    $e.principal.process.file.full_path = /certutil\.exe|mshta\.exe|wscript\.exe/ nocase
    $e.target.process.command_line = /urlcache|encode|http/ nocase
    
  condition:
    $e
}
```

### Mandiant Managed Defense

Mandiant Managed Defense is an MDR (Managed Detection and Response) service delivered on top of Google SecOps:
- Mandiant analysts monitor customer Google SecOps environment 24/7
- Threat hunting using Mandiant actor intelligence
- Incident response coordination (Mandiant IR team engaged on confirmed incidents)
- This is where IR-derived intelligence creates the most direct feedback loop

---

## APT Intelligence Production Process

### How APTs Get Designated

1. **UNC Cluster Created**: Mandiant IR encounters new actor; creates UNC tracking record
2. **Activity Clustering**: Multiple incidents linked to same UNC via shared TTPs, infrastructure, or code
3. **Attribution Evidence Gathering**: 
   - Technical evidence (malware source code overlaps, infrastructure reuse)
   - HUMINT context (when available via government partnerships)
   - OSINT (language artifacts, operational security patterns, geolocation signals)
4. **Attribution Assessment**: Internal peer review; confidence assessment
5. **APT Designation**: When attribution confidence meets threshold, UNC → APT
6. **Public Disclosure Decision**: Strategic timing; coordinate with law enforcement when appropriate

### Intelligence Report Types

| Report Type | Audience | Frequency | Content |
|---|---|---|---|
| Malware Profile | Analyst | Ad hoc | Technical malware analysis (static + dynamic) |
| Actor Profile Update | Analyst | Ongoing | New TTP observations, infrastructure additions |
| Campaign Report | Analyst + Manager | Ad hoc (campaign-driven) | Full campaign description, targets, TTPs, IOCs |
| Threat Briefing | Executive | Weekly/monthly | Plain-language threat landscape summary |
| Special Report | All | Ad hoc (major events) | SolarWinds-level major disclosure |
| Vulnerability Advisory | Analyst | Ad hoc (on CVE) | Exploitation evidence, affected products, risk |
