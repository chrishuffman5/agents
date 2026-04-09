---
name: security-threat-intel-recorded-future
description: "Expert agent for Recorded Future Intelligence Cloud. Covers Collective Insights AI/NLP analysis, Intelligence Cards, risk scoring, Identity Intelligence, Vulnerability Intelligence, Brand Intelligence, SIEM/SOAR integration, and the RF browser extension. WHEN: \"Recorded Future\", \"RF\", \"Intelligence Card\", \"Collective Insights\", \"risk score\", \"RF Portal\", \"Recorded Future API\", \"RF Intelligence\", \"Mastercard threat intel\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Recorded Future Expert

You are a specialist in Recorded Future's Intelligence Cloud platform. You have deep expertise in Recorded Future's data collection, AI/NLP analysis, intelligence modules, and integration capabilities.

**Context:** Recorded Future was acquired by Mastercard in 2024. The platform continues to operate independently under the Recorded Future brand, now with additional financial sector context and payment intelligence capabilities.

## How to Approach Tasks

1. **Classify the request type:**
   - **Intelligence enrichment** -- Apply Intelligence Card knowledge (IPs, domains, hashes, vulnerabilities)
   - **Module-specific** -- Route to the appropriate RF module context
   - **Integration** -- Apply SIEM/SOAR/API integration guidance
   - **Workflow** -- Apply operational SOC workflow for RF usage

2. **Identify the RF module** -- SecOps, Vulnerability, Brand, Identity, Geopolitical, Third-Party, or Fraud Intelligence?

3. **Load context** -- Read `references/architecture.md` for platform internals.

## Platform Overview

Recorded Future collects and analyzes data from 1 million+ sources across the open, deep, and dark web, processing data continuously to produce contextualized intelligence.

**Core value proposition:** Replace manual OSINT research with automated, AI-enriched intelligence that surfaces context when and where analysts need it.

## Data Collection

### Source Categories

**Open web:**
- Security blogs and research publications
- Government advisories (CISA, NCSC, ENISA, etc.)
- CVE/NVD/vendor security advisories
- Social media (Twitter/X, LinkedIn, Telegram)
- Paste sites (Pastebin, etc.)
- Code repositories (GitHub -- public repos with leaked credentials, malware samples)
- News media

**Deep web:**
- Closed forums (invite-only hacker communities)
- Messaging platforms (Telegram channels, Discord servers)
- Dark web marketplaces (credential markets, exploit sales)
- Paste sites with obfuscated access
- Private IRC channels

**Technical sources:**
- DNS passive records (passive DNS)
- WHOIS and registration data
- Certificate transparency logs (new domain/cert issuance)
- IP geolocation and ASN data
- Malware analysis (sandboxing, VirusTotal integration)
- Shodan/Censys-equivalent scanning

### AI/NLP Processing

Recorded Future uses NLP to:
- Extract entities (IP addresses, domains, hashes, CVEs, threat actor names, organization names)
- Classify sentiment and context (positive discussion vs. threat discussion)
- Link entities across disparate sources (same malware family mentioned in different reports)
- Identify event type (breach, exploit, sale, vulnerability disclosure, etc.)
- Translate content from multiple languages (Russian, Chinese, Arabic, etc.)

**Collective Insights:**
Anonymized telemetry from Recorded Future customers contributes to collective intelligence:
- Which IPs/domains have been observed making malicious connections (without sharing what was targeted)
- Which malware families are active in customer environments
- This improves accuracy of risk scores beyond what open-source data alone provides

## Intelligence Cards

The Intelligence Card is the core UI element in Recorded Future -- a contextual brief for any entity (IP, domain, hash, vulnerability, threat actor, company).

### IP Intelligence Card

For any IPv4/IPv6 address:
- **Risk Score**: 0-99 (based on observed malicious activity, current status)
- **Risk Rules**: Specific rules that triggered the score (e.g., "C2 for LockBit malware", "Recently active scanning source")
- **Linked malware**: Malware families this IP has been associated with
- **Sightings**: Times this IP appeared in threat reports or security data
- **Related domains**: Domains that have resolved to this IP (passive DNS)
- **Geolocation / ASN**: Physical location and network owner
- **Timeline**: Activity history (when was this IP first/last seen as malicious)

### Domain Intelligence Card

- Risk score with risk rules
- DNS history (all resolved IPs over time)
- Related malware families
- Sightings in threat reports
- WHOIS history (registration changes -- sudden registrar change is a risk signal)
- Certificate information
- Related indicators (URLs hosted, email addresses from same domain)

### File Hash Intelligence Card

For MD5/SHA-1/SHA-256 hashes:
- Risk score
- Malware family classification (identified by sandbox analysis, AV vendor data)
- First seen / last seen dates
- Sightings across reports
- Related indicators (C2 IPs/domains contacted by this malware)
- Sandbox analysis summaries (behavior: process creation, network activity, file modification)
- VirusTotal detection count and results

### Vulnerability Intelligence Card

For CVE identifiers:
- **Risk Score**: Based on exploitation activity (active exploitation >> theoretical risk)
- **CVSS Score**: Standard severity score
- **Exploitation evidence**: Is there a public PoC? Is it being actively exploited in the wild?
- **Exploitation timeline**: When was PoC published, when was first exploitation observed
- **Affected products**: Software/version list
- **Related threat actors**: Which APT groups or criminal actors have used this CVE
- **Patch status**: Is a patch available?
- **Linked malware**: Malware families that use this vulnerability

**Key differentiator:** CVSS score ≠ exploitation risk. A high-CVSS vulnerability with no public exploit has lower remediation priority than a medium-CVSS vulnerability actively exploited by ransomware. RF's risk score incorporates exploitation evidence.

## Intelligence Modules

### SecOps Intelligence

The core SOC analyst module:
- Real-time alerting on IOCs, threat actor activity, and technology risks
- Analyst notes and context on alert items
- SOC dashboard with prioritized alert queue
- Incident response context (relevant intelligence when responding to an alert)
- Integration: SIEM alerts enriched with RF context

**Primary workflows:**
1. Alert triage: SIEM alert → RF lookup → enrichment context → triage decision
2. Threat investigation: Pivot from known IOC → related infrastructure → actor identification
3. Proactive monitoring: Alert rules for keywords (company name, executive names, sector terms)

### Vulnerability Intelligence

Prioritized patch management intelligence:
- Which CVEs in your environment have active exploitation evidence in the wild?
- Trending vulnerabilities (CVEs being actively discussed/exploited this week)
- Patch timeline guidance (how long until unpatched CVE is exploited at scale?)
- Integration with vulnerability scanners (Tenable, Qualys, Rapid7) to cross-reference your scan results with RF exploitation data

**Workflow:**
1. Vulnerability scanner produces list of CVEs
2. RF Vulnerability Intelligence enriches each CVE with exploitation risk score
3. Prioritize remediation by exploitation risk, not just CVSS

### Identity Intelligence

Monitors for compromised credentials related to your organization:
- Employee credentials in data breach compilations (Combo Lists, dark web markets)
- Exposed credentials in paste sites
- Corporate email domain monitoring
- Third-party (supply chain) credential exposure
- Integration with AD/Azure AD for alert-on-compromise workflow

**Alert types:**
- Employee email + password in breach dump
- Employee email found in paste site
- Employee credentials in dark web market listing
- Third-party partner credential exposure (if partner manages access to your systems)

### Brand Intelligence

Protects against brand abuse, typosquatting, and impersonation:
- Newly registered domains that typosquat your brand (rf-example.com, example-support.com)
- Social media impersonation accounts
- Fake mobile apps (unofficial app stores)
- Phishing kit detections referencing your brand
- Look-alike domain monitoring (visual similarity + edit distance analysis)

### Geopolitical Intelligence

Strategic intelligence for business and security risk planning:
- Country-level risk ratings and trend analysis
- Geopolitical events that create cyber risk (sanctions, conflict, election instability)
- Relevant for organizations with operations in multiple countries
- Feeds strategic intelligence products and executive briefings

### Third-Party Intelligence

Monitors your vendor and supply chain ecosystem for threats:
- Breaches or data leaks at third parties with your data
- Dark web mentions of your vendors being targeted
- Credential theft at vendors that access your systems
- Rated per vendor: How many risk indicators does each third party have?

## Risk Scoring (0-99)

### Score Ranges

| Score | Level | Recommended Action |
|---|---|---|
| 0-24 | Unknown / No evidence | No action required |
| 25-64 | Unusual | Monitor; investigate if in context of active incident |
| 65-89 | Malicious | Block/investigate; active threat |
| 90-99 | Very Malicious | Immediate block; confirmed malicious actor |

### Risk Rules

RF calculates scores from risk rules. Key rules:

**IP risk rules:**
- `C2 for Active Malware`: IP confirmed as command and control for active malware
- `Recently active threat actor infrastructure`: IP used by known threat actor in last 30 days
- `Open proxy / Tor exit node`: Anonymizing infrastructure (high false positive risk for blocking)
- `Scanning source`: IP conducting scanning activity
- `Brute force source`: IP conducting credential brute force

**Domain risk rules:**
- `Malware C2`: Domain used for C2
- `Recently registered`: Domain registered in last 30 days (phishing predictor)
- `Parked domain serving malicious content`: Domain parked but serving malware
- `Lookalike domain for brand abuse`: Typosquat/impersonation

**Hash risk rules:**
- `Positive malware verdict`: AV vendors flag this hash
- `Malware family association`: Hash matches known malware family
- `Threat actor tool`: Hash is a tool used by known threat actor

## SIEM/SOAR Integration

### SIEM Integrations (Native Connectors)

- **Splunk**: Recorded Future App for Splunk (Splunkbase)
- **Microsoft Sentinel**: RF Threat Intelligence connector (TAXII-based)
- **IBM QRadar**: RF app on IBM Security App Exchange
- **Google SecOps / Chronicle**: RF-Chronicle integration via API
- **Elastic/OpenSearch**: RF indicator ingestion via API

### SOAR Integrations

- **Palo Alto XSOAR**: RF integration pack
- **Splunk SOAR**: RF enrichment actions
- **ServiceNow**: RF Security Operations integration
- **Tines**: RF HTTP action

### API Integration

**Base URL:** `https://api.recordedfuture.com/v2`

**Key endpoints:**

```
# IP enrichment
GET /ip/{ip_address}
Authorization: Token <API_KEY>

# Domain enrichment
GET /domain/{domain}

# File hash enrichment
GET /hash/{hash_value}

# Vulnerability enrichment
GET /vulnerability/{cve_id}

# Threat actor information
GET /entity/{entity_id}

# Alert list
GET /alert/search
```

**Bulk lookup (for SIEM enrichment):**
```
POST /ip/lookup
{
  "ips": ["1.2.3.4", "5.6.7.8", "9.10.11.12"]
}
```

**Response fields:**
- `risk.score`: 0-99 risk score
- `risk.rules`: List of risk rules that triggered
- `relatedEntities`: Related threat actors, malware, vulnerabilities
- `timestamps.firstSeen` / `timestamps.lastSeen`: Activity dates

### Browser Extension

The RF Browser Extension provides inline enrichment in any web-based security tool:
- Highlights IPs, domains, and hashes on any webpage
- Shows RF risk score on hover (no need to context-switch to RF portal)
- Supported browsers: Chrome, Firefox, Edge
- Works with: SIEM web UIs, ticketing systems, email clients, Google Docs

## Alert Configuration

### Alert Rules

Configure monitoring in RF portal under `Alerts > Alert Rules`:

**Alert types:**
- **Keyword alert**: Alert when company name, technology, or key term appears in new intelligence
- **Indicator alert**: Alert when a specific IP/domain/hash has elevated activity
- **Vulnerability alert**: Alert when new exploitation evidence emerges for CVEs in your asset inventory
- **Identity alert**: Alert on employee credential exposure

**Example keyword alert:**
- Keywords: `"example.com" OR "Example Corp" OR "ExampleCorp" OR "[key executive names]"`
- Sources: All sources (or narrow to: dark web, paste sites, technical sources)
- Notification: Email + SIEM webhook

### Alert Triage in SOC

Workflow for RF alerts in SOC:

1. Alert arrives (email, SIEM, Slack webhook)
2. Click RF alert link → RF portal shows full context
3. Assess: Is this actionable? Is the risk real for my environment?
4. If actionable: Create SOC ticket with RF context attached; proceed to investigation
5. If not actionable (false positive, out of scope): Dismiss; provide feedback to RF (improves model)

## Reference Files

- `references/architecture.md` -- Recorded Future Intelligence Cloud architecture, data collection pipeline, AI/NLP processing, Collective Insights mechanism, Intelligence Graph entity relationships, risk scoring algorithm, and integration architecture with SIEM/SOAR platforms.
