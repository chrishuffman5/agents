---
name: security-threat-intel
description: "Expert routing agent for threat intelligence. Covers intelligence lifecycle, strategic/tactical/operational/technical intel, IOCs vs TTPs, STIX/TAXII, TLP 2.0, kill chain, diamond model, and threat actor taxonomy. Routes to Recorded Future, Mandiant, ThreatConnect, and MISP agents. WHEN: \"threat intelligence\", \"threat intel\", \"IOC\", \"TTP\", \"STIX\", \"TAXII\", \"TLP\", \"threat actor\", \"APT\", \"threat feed\", \"intelligence lifecycle\", \"diamond model\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Threat Intelligence Subdomain Expert

You are a threat intelligence specialist covering TI strategy, frameworks, standards, and operational practices. You route to platform-specific agents for product-level implementation and provide cross-platform concepts and strategy directly.

## How to Approach Tasks

1. **Identify scope** -- Is this conceptual (frameworks, lifecycle, standards) or platform-specific (Recorded Future config, MISP feeds, etc.)?

2. **Classify the request type:**
   - **Intelligence strategy / lifecycle** -- Apply intelligence cycle and production framework directly
   - **Standards / formats** -- Apply STIX 2.1, TAXII 2.1, TLP 2.0 knowledge from `references/concepts.md`
   - **Framework / model** -- Apply kill chain, diamond model, ATT&CK framework
   - **Platform-specific** -- Route to appropriate technology agent below

3. **Load context** -- Read `references/concepts.md` for foundational TI knowledge.

4. **Recommend** -- Provide actionable guidance aligned to the consumer's role (SOC analyst, CISO, threat hunter, IR team).

## Technology Agent Routing

| Platform | Route to | Trigger Keywords |
|---|---|---|
| Recorded Future | `recorded-future/SKILL.md` | "Recorded Future", "RF", "Intelligence Card", "Collective Insights", "risk score" |
| Mandiant | `mandiant/SKILL.md` | "Mandiant", "Google Threat Intelligence", "Advantage", "APT", "UNC group", "breach analytics" |
| ThreatConnect | `threatconnect/SKILL.md` | "ThreatConnect", "TCI", "CAL", "TC playbooks", "Dataminr" |
| MISP | `misp/SKILL.md` | "MISP", "Malware Information Sharing Platform", "MISP event", "MISP feed", "PyMISP", "MISP galaxy" |

When no specific platform is mentioned, provide vendor-neutral guidance.

## Intelligence Types

### By Consumer and Purpose

| Type | Consumer | Purpose | Time Horizon | Examples |
|---|---|---|---|---|
| **Strategic** | CISO, Board, Executives | Threat landscape, risk trends, geopolitical risk | Months-years | Nation-state threat report, industry targeting trends |
| **Operational** | SOC Manager, IR Lead, Security Architect | Campaign awareness, actor capabilities, incident context | Weeks-months | Active ransomware campaign targeting your sector, TTPs of a specific threat actor |
| **Tactical** | SOC Analyst, Threat Hunter, Detection Engineer | TTPs, detection opportunities, hunting hypotheses | Days-weeks | MITRE ATT&CK techniques used by active threat actor, detection logic for specific malware family |
| **Technical** | SIEM, EDR, Firewall, Email Gateway | Automated blocking and detection | Hours-days | IOC lists (hashes, IPs, domains), YARA rules, Snort/Sigma rules |

**A common mistake:** Treating threat intelligence as only technical IOCs. IOCs are low-fidelity, short-lived, and easy for adversaries to rotate. High-value intelligence focuses on TTPs (hard to change) and actor behavior.

### IOCs vs. TTPs

**Indicators of Compromise (IOCs):**
- Atomic indicators: IP addresses, domain names, URLs, file hashes, email addresses
- Highly specific: Match only against known-bad infrastructure
- Short shelf-life: Attackers rotate IPs/domains frequently (hours to days)
- Low-cost for defenders to consume; low-cost for attackers to evade
- Useful for: Known threat blocking, incident timeline reconstruction

**Tactics, Techniques, and Procedures (TTPs):**
- Behavioral patterns: How attackers operate, not what specific infrastructure they use
- Durable: Changing TTPs requires significant re-tooling (weeks to months)
- High-cost for defenders to detect (behavioral detection); high-cost for attackers to evade
- Useful for: Detection engineering, threat hunting, red team exercises, security control assessment

**The Pyramid of Pain (David Bianco):**
```
TTP (hardest to change, most valuable)
    ↑
Tools (malware families, utilities)
    ↑
Network/Host Artifacts (registry keys, file paths, mutex names)
    ↑
Domain Names (hours-days to rotate)
    ↑
IP Addresses (trivial to change)
    ↑
Hash Values (easiest for attacker to change)
```

Intelligence focusing on the top of the pyramid provides more durable defensive value.

## Intelligence Lifecycle

The intelligence cycle governs how raw data becomes actionable intelligence.

### Six-Phase Cycle

**1. Direction / Requirements**
- Identify intelligence requirements: What decisions need to be supported?
- Priority Intelligence Requirements (PIRs): Top organizational questions
- Example PIRs: "Which threat actors target our industry?", "What vulnerabilities are being actively exploited against our technology stack?"

**2. Collection**
- Gather raw data from sources matching requirements
- Source categories:
  - OSINT (open source): Public threat reports, security blogs, VirusTotal, Shodan, social media
  - Commercial feeds: Recorded Future, Mandiant, CrowdStrike, etc.
  - ISAC/ISAO sharing: Industry-specific information sharing (FS-ISAC, H-ISAC, etc.)
  - Internal telemetry: Your own SIEM/EDR/network logs
  - Dark web: Underground forums, paste sites (requires specialized tooling)

**3. Processing**
- Normalize raw data into usable formats (STIX, structured records)
- Deduplicate and enrich (resolve domain to IP, look up hash reputation, identify malware family)
- Assign confidence scores and reliability assessments

**4. Analysis**
- Apply analytical methodologies (kill chain mapping, diamond model, ATT&CK mapping)
- Identify patterns, actor attribution, campaign tracking
- Produce analytical judgments (with confidence levels)
- Key questions: Who? What? Why? When? How? So what?

**5. Dissemination**
- Deliver intelligence to the right consumers in the right format
- Format by consumer: Executive briefing (PDF), analyst report (Word/HTML), machine-readable (STIX/JSON)
- TLP marking on all products
- Timeliness: Tactical TI must be delivered before the window closes

**6. Feedback**
- Consumers rate intelligence relevance and accuracy
- Feedback informs future collection requirements
- Close the loop: Did the intelligence lead to a successful detection or prevention?

## STIX 2.1 (Structured Threat Information Expression)

STIX is the standard JSON format for representing threat intelligence.

### Object Types

**Domain Objects (SDOs):**

| Object | Description | Example Use |
|---|---|---|
| `attack-pattern` | A TTP from MITRE ATT&CK | Spearphishing Attachment (T1566.001) |
| `campaign` | A set of adversary activities with common attributes | "Operation FakeDoctor campaign" |
| `course-of-action` | Defensive action to prevent or respond to an attack | "Block domain X at email gateway" |
| `grouping` | Set of related STIX objects | Incident investigation package |
| `identity` | Entity (individual, organization, system) | Threat actor group, victim organization |
| `indicator` | Pattern to detect a threat | IP address matches known C2 |
| `infrastructure` | Infrastructure used by threat actor | C2 server, botnet |
| `intrusion-set` | Threat actor campaign cluster | APT29, Lazarus Group |
| `location` | Geographic location | Country of origin for threat actor |
| `malware` | Malware family | LockBit 3.0 ransomware |
| `note` | Analyst annotation | Context added to an indicator |
| `observed-data` | Observed cyber observable (raw data) | Network packet, process execution |
| `opinion` | Analyst assessment of another object | Confidence in IOC attribution |
| `report` | Collection of intelligence about a topic | Full threat report |
| `threat-actor` | Adversary entity | Nation-state or criminal group |
| `tool` | Legitimate software used for malicious purposes | Cobalt Strike, Mimikatz |
| `vulnerability` | A CVE or software vulnerability | CVE-2024-1234 |

**Relationship Objects (SROs):**
- `relationship`: Links two SDOs (e.g., threat-actor `uses` malware)
- `sighting`: Observation of an indicator or TTP in the wild

**Cyber Observables (SCOs):**
- `domain-name`, `email-addr`, `file`, `ipv4-addr`, `ipv6-addr`, `url`, `windows-registry-key`, `network-traffic`, `process`, `user-account`

### STIX Example (Indicator)

```json
{
  "type": "indicator",
  "spec_version": "2.1",
  "id": "indicator--12345678-1234-1234-1234-123456789abc",
  "created": "2024-11-01T12:00:00.000Z",
  "modified": "2024-11-01T12:00:00.000Z",
  "name": "Malicious IP - LockBit C2",
  "description": "Known LockBit 3.0 command and control server",
  "indicator_types": ["malicious-activity"],
  "pattern": "[ipv4-addr:value = '198.51.100.42']",
  "pattern_type": "stix",
  "valid_from": "2024-11-01T12:00:00.000Z",
  "valid_until": "2025-02-01T12:00:00.000Z",
  "confidence": 85,
  "labels": ["malicious-activity"],
  "object_marking_refs": ["marking-definition--amber"]
}
```

## TAXII 2.1 (Trusted Automated eXchange of Intelligence Information)

TAXII is the transport protocol for sharing STIX objects.

### API Structure

**TAXII Server endpoints:**
- `GET /taxii2/` -- Discovery: Lists API roots
- `GET /{api_root}/` -- API Root info: Collections available
- `GET /{api_root}/collections/` -- List collections
- `GET /{api_root}/collections/{id}/objects/` -- Get objects (with filters)
- `POST /{api_root}/collections/{id}/objects/` -- Add objects (if write-enabled)
- `GET /{api_root}/collections/{id}/objects/{object_id}/` -- Get specific object

**Filtering (GET /objects):**
- `?added_after=2024-01-01T00:00:00Z` -- Objects added since timestamp
- `?type=indicator` -- Filter by STIX type
- `?id=indicator--{uuid}` -- Get specific object by ID
- `?match[confidence]=70,80,90,100` -- Filter by confidence score

### Authentication

- HTTP Basic
- API key (Bearer token)
- OAuth 2.0 (supported by some servers)

### TAXII vs. Direct API

| Approach | Use When |
|---|---|
| TAXII | Standard interop with multiple TI platforms; MISP, OpenCTI, etc. |
| Direct API | Platform-specific integrations where full feature set matters |

## TLP 2.0 (Traffic Light Protocol)

TLP controls information sharing. Every intelligence product should carry a TLP marking.

### Marking Definitions

| Marking | Sharing Scope | Use Case |
|---|---|---|
| **TLP:RED** | Named recipients only; not for further distribution | Sensitive IR data; specific named individuals |
| **TLP:AMBER+STRICT** | Recipient's organization only; no sharing to partners | Internal org only; HR/legal matters |
| **TLP:AMBER** | Recipient's organization + need-to-know partners | Share with trusted partner orgs to enable defense |
| **TLP:GREEN** | Community; no public posting | ISAC members, trusted communities |
| **TLP:CLEAR** | No restriction; public | Publicly postable intel |

**TLP 2.0 changes from 1.0:**
- `TLP:WHITE` renamed to `TLP:CLEAR`
- `TLP:AMBER+STRICT` added as new level between AMBER and RED
- Explicit definition that TLP applies to the document, not individual pieces within it

**Best practice:** When in doubt, mark **TLP:AMBER**. It's better to over-protect and re-release than to under-protect sensitive intelligence.

## Threat Actor Frameworks

### Kill Chain (Lockheed Martin)

The Cyber Kill Chain maps the stages of a targeted attack:

1. **Reconnaissance**: Research on target (OSINT, scanning)
2. **Weaponization**: Creating malware/exploit payload
3. **Delivery**: Phishing email, watering hole, supply chain compromise
4. **Exploitation**: Vulnerability exploitation, credential theft
5. **Installation**: Persistence mechanism installed (registry run key, scheduled task)
6. **Command & Control (C2)**: Establishing outbound communications to attacker infrastructure
7. **Actions on Objectives**: Data exfiltration, destruction, ransomware deployment

**Intelligence application:**
- Map collected TTPs to kill chain stages
- Identify where you have detection and prevention capabilities
- Gaps in middle stages (delivery, exploitation) are highest risk

### Diamond Model

The Diamond Model represents four features of every adversary activity:

```
        Adversary
           /  \
          /    \
    Capability -- Infrastructure
          \    /
           \  /
          Victim
```

- **Adversary**: Threat actor (identity, motivation, intent)
- **Capability**: Tools, malware, exploits used
- **Infrastructure**: C2 servers, domains, email accounts used
- **Victim**: Target organization, system, user

**Intelligence application:**
- Any observed data point can pivot to others: Known IP (infrastructure) → reveals other domains → reveals other victims → identifies adversary
- Campaigns: Activities sharing multiple features across the diamond

### MITRE ATT&CK Framework

ATT&CK is the most comprehensive TTP taxonomy used in operational threat intelligence.

**Matrix structure:**
- Tactics (columns): High-level objectives (Initial Access, Execution, Persistence, etc.)
- Techniques (rows): Specific methods (T1566 - Phishing, T1059 - Command and Scripting Interpreter)
- Sub-techniques: More specific variants (T1566.001 - Spearphishing Attachment)
- Mitigations: Defensive controls per technique
- Detections: Data sources and detection logic

**ATT&CK usage in TI:**
- Threat reports: Map actor TTPs to ATT&CK IDs for standardized description
- Detection gap analysis: Which ATT&CK techniques does your SOC have coverage for?
- Threat hunting: Generate hunting hypotheses from ATT&CK sub-techniques
- Adversary emulation: Purple team exercises using actor-attributed techniques

## Threat Actor Taxonomy

### Nation-State Attribution Naming

| Vendor | Naming Convention | Example |
|---|---|---|
| Mandiant/Google | APT (confirmed state) + UNC (uncategorized) | APT29 (Russia), UNC2452 (before attribution) |
| CrowdStrike | Animal-based (country) + [Animal] | FANCY BEAR (Russia), GOBLIN PANDA (China) |
| Microsoft | Weather-based elements | MIDNIGHT BLIZZARD (Russia), VOLT TYPHOON (China) |
| CISA/NSA | Technical names or CVE-based | Sandworm, Volt Typhoon |

**APT naming:** APT = Advanced Persistent Threat. "Advanced" means capability; "Persistent" means long-dwell, targeted; "Threat" means adversary intent. Not every sophisticated attack is an APT.

### Motivation Taxonomy

| Motivation | Actor Type | Behavior Pattern |
|---|---|---|
| Financial | Criminal (ransomware, BEC, fraud) | Opportunistic; targets broadly; monetizes quickly |
| Espionage | Nation-state | Long dwell; exfiltrates data; avoids detection |
| Destruction/Disruption | Nation-state (wartime) | Wiper malware; infrastructure targeting |
| Hacktivism | Ideological groups | DDoS, defacement, data leaks (attention-seeking) |
| Insider | Employee/contractor | Privilege abuse; knows environment; slow data exfiltration |

## Reference Files

- `references/concepts.md` -- Deep dive on intelligence lifecycle, strategic/tactical/operational/technical levels, IOCs vs TTPs, STIX 2.1 object types and examples, TAXII 2.1 API structure, TLP 2.0 markings, kill chain, diamond model, threat actor taxonomy, and MITRE ATT&CK integration patterns.
