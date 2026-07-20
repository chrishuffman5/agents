# Threat Intelligence Fundamentals

## Intelligence Lifecycle (Detailed)

### Direction Phase: Writing Intelligence Requirements

Intelligence requirements should be specific, measurable, and tied to decisions.

**Bad requirement:** "Tell us about threats"
**Good requirement:** "Identify ransomware groups currently targeting manufacturing companies with $100M-$1B revenue, with details on initial access vectors in use Q4 2024"

**Priority Intelligence Requirements (PIRs) framework:**
- Limit to 5-10 PIRs per quarter (too many = no focus)
- Each PIR should support a specific decision
- Review and update quarterly

**Standing Intelligence Requirements (SIRs):**
- Continuous monitoring requirements that don't change with quarters
- Example: "Alert immediately on any threat intelligence involving company name, executive names, or IP ranges"

### Collection Discipline

**Source reliability vs. information credibility:**

Admiralty Reliability Scale (NATO standard):
- A: Completely reliable (trusted partner with proven track record)
- B: Usually reliable
- C: Fairly reliable
- D: Not usually reliable
- E: Unreliable
- F: Cannot be judged

Information credibility:
- 1: Confirmed by other independent sources
- 2: Probably true
- 3: Possibly true
- 4: Doubtful
- 5: Improbable
- 6: Cannot be judged

**Expressing confidence:** An indicator from "A1" source (reliable + confirmed) warrants high-confidence action. "F6" should not trigger automated blocking.

### Analytical Tradecraft

**Structured Analytical Techniques (SATs):**
- **Analysis of Competing Hypotheses (ACH)**: List hypotheses, evaluate evidence against each, eliminate least supported
- **Key Assumptions Check**: Explicitly document assumptions underlying the analysis; test them
- **Red Team Analysis**: Take the adversary's perspective; would they do what you're predicting?
- **Cone of Plausibility**: Range of possible outcomes with probability estimates

**Analytical pitfalls to avoid:**
- **Mirror imaging**: Assuming adversary thinks like you do
- **Anchoring bias**: Overweighting first piece of information received
- **Confirmation bias**: Seeking evidence that supports existing hypothesis
- **Layering**: Building subsequent analysis on a weakly-supported base

### Dissemination Formats by Consumer

**Executive / Board:**
- 1-2 page PDF
- Plain language (no jargon)
- Risk framing (business impact, probability)
- Recommendations in plain terms
- No IOCs, no technical detail

**SOC Manager / Security Architect:**
- 3-5 page brief
- Campaign context, actor motivation
- TTPs mapped to ATT&CK
- Detection coverage assessment (what you have vs. what's needed)
- Recommended defensive actions with priority and estimated effort

**SOC Analyst / Threat Hunter:**
- Technical report with TTPs
- Detection logic (Sigma rules, KQL, SPL)
- Hunting hypotheses
- Relevant IOCs with context (not just raw lists)
- ATT&CK navigator layer

**Security Tools (automated consumption):**
- STIX 2.1 JSON bundles via TAXII
- Bulk IOC CSV (hash, type, confidence, expiry)
- YARA rules
- Snort/Suricata rules
- Sigma rules
- MISP events

---

## Intelligence Types (Extended)

### Technical Intelligence Deep Dive

Technical intelligence feeds directly into security controls for automated detection and blocking.

**IOC Types and Characteristics:**

| IOC Type | TTL | False Positive Risk | Automation Suitable? |
|---|---|---|---|
| SHA-256 file hash | Hours-days (known-good hash can be in multiple versions) | Low for malicious; high for legitimate file hashes | Yes (high confidence sources) |
| SHA-1 file hash | Days-weeks | Low-moderate | Yes |
| MD5 file hash | Days-weeks (collision risk) | Moderate | Caution (MD5 collisions possible) |
| IPv4 address | Hours-days (shared hosting, Tor exit) | High (CDNs, Tor, shared hosting) | Caution |
| IPv6 address | Similar to IPv4 | Similar to IPv4 | Caution |
| Domain name | Days-weeks (domain fronting, DGA) | Moderate | Caution |
| URL | Days-weeks | Low (full path is specific) | Yes with decay |
| Email address | Weeks-months | Low | Yes |
| Mutex | Months-years | Very low | Yes |
| Registry key | Months-years | Low | Yes |
| YARA rule | Months-years (until malware update) | Low-moderate | Yes (test first) |
| Sigma/Snort rule | Months | Low | Yes (test first) |

**IOC confidence decay:**
All IOCs should have a `valid_until` / `expiry` field. Automatically retire expired IOCs from active blocking lists. Old IOCs without expiry dates should be treated as unverified.

### Tactical Intelligence: TTPs to Detection

Converting TTP intelligence into detection logic follows this path:

```
Actor Report
  ↓ (identify TTPs)
ATT&CK Mapping (T1566.001 - Spearphishing Attachment)
  ↓ (identify data sources)
Data Source (Email logs + Endpoint telemetry)
  ↓ (write detection)
Sigma Rule → Convert to platform-specific query
  ↓ (test and tune)
SIEM/EDR Detection Rule
  ↓ (validate)
Threat Hunting exercise
```

**Example TTP-to-detection pipeline:**
- TTP: Threat actor uses `certutil.exe` to download payloads (T1140)
- Data source: Windows process creation events
- Sigma rule: Process name = certutil.exe AND command line contains `-urlcache` OR `-decode`
- Convert to Splunk SPL: `index=windows EventCode=4688 New_Process_Name="*certutil.exe" AND (CommandLine="*urlcache*" OR CommandLine="*decode*")`

---

## STIX 2.1 In-Depth

### Confidence Scoring

STIX uses a 0-100 confidence score:

| Score | Meaning |
|---|---|
| 0 | No confidence (placeholder) |
| 15 | Low confidence |
| 50 | Moderate confidence |
| 85 | High confidence |
| 100 | Confirmed/certain |

Recommendation: Use 25/50/75/85 levels rather than arbitrary values for consistency.

### STIX Relationships

STIX relationships connect objects with typed relationships:

```json
{
  "type": "relationship",
  "id": "relationship--...",
  "relationship_type": "uses",
  "source_ref": "intrusion-set--...",
  "target_ref": "malware--...",
  "description": "APT29 uses SUNBURST malware in supply chain attacks"
}
```

Common relationship types:
- `uses`: Actor/campaign uses tool, malware, infrastructure, or technique
- `indicates`: Indicator pattern indicates malicious activity
- `attributed-to`: Campaign or intrusion set attributed to threat actor
- `targets`: Actor or campaign targets identity or vulnerability
- `mitigates`: Course of action mitigates attack pattern
- `delivers`: Attack pattern delivers malware
- `exploits`: Malware exploits vulnerability

### STIX Marking Definitions

TLP markings are implemented as STIX marking-definition objects:

```json
{
  "type": "marking-definition",
  "spec_version": "2.1",
  "id": "marking-definition--34098fce-860f-4bae-9964-2c366d181bfe",
  "created": "2022-10-01T00:00:00.000Z",
  "definition_type": "tlp",
  "name": "TLP:AMBER",
  "definition": {
    "tlp": "AMBER"
  }
}
```

Apply marking to any STIX object via `object_marking_refs` field.

### STIX Bundle

A STIX bundle groups related objects for transfer:

```json
{
  "type": "bundle",
  "id": "bundle--...",
  "objects": [
    { "type": "report", ... },
    { "type": "threat-actor", ... },
    { "type": "malware", ... },
    { "type": "indicator", ... },
    { "type": "relationship", ... }
  ]
}
```

---

## TAXII 2.1 Operations

### Consuming a TAXII Feed

**Step 1: Discovery**
```
GET https://taxii.example.com/taxii2/
Authorization: Bearer <token>
Accept: application/taxii+json;version=2.1
```

Response:
```json
{
  "title": "Example TAXII Server",
  "api_roots": ["https://taxii.example.com/api1/"]
}
```

**Step 2: List collections**
```
GET https://taxii.example.com/api1/collections/
```

Response: List of collection objects with IDs and human-readable names

**Step 3: Poll for new objects (incremental)**
```
GET https://taxii.example.com/api1/collections/{id}/objects/?added_after=2024-11-01T00:00:00Z&type=indicator
```

**Step 4: Parse STIX bundle**
Process returned objects, extract indicators, import to SIEM/TIP/EDR

### Publishing via TAXII

```
POST https://taxii.example.com/api1/collections/{id}/objects/
Content-Type: application/taxii+json;version=2.1
Authorization: Bearer <token>

{
  "type": "bundle",
  "objects": [ ... ]
}
```

### TAXII Client Libraries

- **Python**: `cabby` (TAXII 1.x), `taxii2-client` (TAXII 2.x)
- **Node.js**: `node-taxii2`
- **Java**: `stix4j`
- Platforms: Recorded Future, ThreatConnect, MISP all support TAXII 2.1 natively

---

## TLP 2.0 Operational Guide

### Applying TLP in Practice

**Every intelligence product must have:**
1. A TLP marking visible in the header
2. A handling statement describing what recipients should do (or not do) with the information

**TLP Handling Statement Templates:**

```
TLP:CLEAR — This document may be shared without restriction.

TLP:GREEN — This document may be shared with community members. 
Do not post publicly.

TLP:AMBER — Recipients may share this with individuals in their organization 
who need it to protect against or respond to the described threat. Do not share 
with other organizations without the originator's permission.

TLP:AMBER+STRICT — Recipients may only share this within their organization 
and only on a need-to-know basis. Not for disclosure beyond the receiving organization.

TLP:RED — This document may be shared only with named recipients. 
Not for distribution beyond the named recipients listed.
```

### Downgrading TLP

Only the **originator** can downgrade a TLP marking. Recipients cannot downgrade without permission.

To request downgrading: Contact the originating organization with justification for broader sharing.

### TLP in ISAC/ISAO Context

When participating in ISACs (Information Sharing and Analysis Centers):
- ISAC-shared intelligence defaults to TLP:GREEN (share within community, not publicly)
- Member-contributed intel may be TLP:AMBER (members only, not to other sectors)
- Critical incident intel may be temporarily TLP:RED (named org contacts only)

---

## Kill Chain and Diamond Model (Operational Use)

### Kill Chain for Detection Engineering

Map your detection capabilities to kill chain stages:

| Stage | Example Detections |
|---|---|
| Reconnaissance | Shodan scans of your IP range, LinkedIn scraping alerts |
| Weaponization | (Hard to detect; monitor dark web/threat feeds for custom exploits) |
| Delivery | Email gateway malicious attachment detection, WAF alerts |
| Exploitation | EDR exploit detection, vulnerability scanner correlation |
| Installation | EDR persistence detection (run keys, scheduled tasks, services) |
| C2 | DNS/proxy anomaly detection, beacon detection, JA3/JA3S signatures |
| Actions | DLP alerts, AD privilege escalation, lateral movement detection |

**Coverage analysis:** For each kill chain stage, rate your detection maturity (None / Partial / Strong). Prioritize gaps that appear in active threat actor TTPs.

### Diamond Model for Threat Tracking

Use the diamond model to track threat actors over time:

**Pivoting examples:**
- Identified C2 IP (infrastructure) → Passive DNS lookup → Other domains on same IP (more infrastructure)
- Identified domain → Registration pattern → Other domains with same registrar/WHOIS pattern
- Malware hash → Sandbox detonation → C2 callback domain
- C2 domain → Other victims who queried it (shared from threat intel community)

**Campaign clustering:**
- When multiple incidents share 2+ diamond model features, cluster into a campaign
- Campaign tracking enables: predicting next targets, proactive blocking, sharing within industry

---

## Threat Actor Taxonomy (Extended)

### APT Actor Profiles (Representative Examples)

**APT29 (Cozy Bear) — Russia (SVR)**
- Motivation: Espionage (government, think tanks, research, diplomatic)
- Dwell time: Months to years (extremely patient)
- TTPs: Supply chain attacks (SolarWinds), spearphishing, living-off-the-land
- Notable: SolarWinds/SUNBURST (2020), Microsoft/HPE (2024)
- ATT&CK Groups page: https://attack.mitre.org/groups/G0016/

**Lazarus Group — North Korea (RGB)**
- Motivation: Financial (cryptocurrency theft, bank heists), espionage
- TTPs: LinkedIn lures, weaponized job applications, macOS cross-platform malware
- Notable: Bangladesh Bank SWIFT heist, WannaCry, Axie Infinity ($625M crypto theft)

**APT41 — China (MSS)**
- Motivation: Espionage + financial (state-sponsored + moonlighting criminal activity)
- TTPs: Supply chain compromise, zero-day exploitation, multi-stage loaders
- Notable: ShadowPad malware, NetSarang supply chain

### Ransomware Actor Tracking

| Group | Status | Notable Attacks | TTPs |
|---|---|---|---|
| LockBit | Disrupted (Feb 2024) but active | Royal Mail, Ion Group, Boeing | Affiliate model, double extortion, self-spreading |
| ALPHV/BlackCat | Disrupted (Dec 2023) | MGM Resorts, Change Healthcare | Rust-based ransomware, triple extortion |
| Cl0p | Active | MOVEit (500+ orgs), GoAnywhere | Zero-day exploitation, no encryption (data theft only) |
| RansomHub | Active (2024-) | Formed by former BlackCat affiliates | Affiliate model |
| Play | Active | City of Oakland, Arnold Clark | No public leak site (unusual) |

**Tracking resources:**
- ransomware.live: Real-time victim tracking
- ID Ransomware: Identify ransomware variant by ransom note/encrypted file extension
- CISA Known Ransomware Advisories: Authoritative TTPs for major groups

### Threat Actor Motivation and Targeting

| Sector | Primary Threats | Primary Motivation |
|---|---|---|
| Financial Services | APT38 (DPRK), criminal ransomware, BEC | Financial theft, ransomware |
| Healthcare | Criminal ransomware (BlackCat, LockBit) | Ransomware (critical service = high ransom) |
| Government | Nation-state (APT29, APT41, Volt Typhoon) | Espionage, pre-positioning |
| Critical Infrastructure | Volt Typhoon (China), Sandworm (Russia) | Pre-positioning for disruption |
| Technology | Multiple nation-states + criminal | IP theft, supply chain, ransomware |
| Energy | Sandworm, Dragonfly (Russia) | Disruption, espionage |

---

## Intelligence Sharing Communities

### ISACs (Information Sharing and Analysis Centers)

US sector-specific ISACs:
- **FS-ISAC** (Financial Services): fs-isac.com
- **H-ISAC** (Healthcare): h-isac.org
- **E-ISAC** (Electricity): eisac.com
- **WaterISAC**: waterisac.com
- **MS-ISAC** (Multi-State, for government): cisecurity.org/ms-isac

**ISAC sharing norms:**
- TLP:GREEN default for shared indicators
- Real-time alerting during active campaigns
- Community threat reports (anonymized attribution)

### Open Source / Community Sharing

| Platform | URL | Content Type |
|---|---|---|
| VirusTotal | virustotal.com | Hash/URL/domain reputation, YARA matches |
| AbuseIPDB | abuseipdb.com | IP reputation, abuse reports |
| Shodan | shodan.io | Internet-exposed host intelligence |
| AlienVault OTX | otx.alienvault.com | Community IOC pulses (STIX/TAXII) |
| CIRCL.lu | circl.lu | MISP instance, OSINT feeds |
| URLhaus | urlhaus.abuse.ch | Malware distribution URLs |
| MalwareBazaar | bazaar.abuse.ch | Malware samples + metadata |
| Feodo Tracker | feodotracker.abuse.ch | Botnet C2 tracking |
| Threatfox | threatfox.abuse.ch | IOC sharing (MISP-compatible) |
