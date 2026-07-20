# SIEM & SOAR Foundational Concepts

## Log Management Lifecycle

### Collection

Log collection is the foundation of SIEM. Methods include:

| Method | Description | Use Case |
|---|---|---|
| **Agent-based** | Software agent on endpoint pushes logs | Endpoints, servers (Splunk UF, Elastic Agent, WEF) |
| **Agentless** | Pull via API, syslog, or WMI/WinRM | Network devices, cloud APIs, SaaS platforms |
| **Syslog** | RFC 5424/3164, UDP/TCP/TLS | Firewalls, routers, Linux systems, appliances |
| **API polling** | REST API calls on a schedule | Cloud services (AWS CloudTrail, O365, Okta) |
| **Event streaming** | Kafka, Event Hubs, Pub/Sub, Kinesis | High-volume, low-latency ingestion pipelines |
| **File monitoring** | Watch directories for log file changes | Legacy applications, flat file logs |

### Parsing

Parsing extracts structured fields from raw log data:

- **Regex extraction** -- Pattern matching against raw text (most flexible, highest maintenance)
- **JSON/XML/CSV parsing** -- Structured formats parsed natively (lowest effort)
- **Key-value extraction** -- `field=value` patterns common in syslog
- **Grok patterns** -- Named regex patterns (Elastic, LogScale) for common log formats
- **LEEF/CEF** -- Structured syslog formats used by security products (QRadar LEEF, ArcSight CEF)

### Normalization

Normalization maps vendor-specific field names to a common schema:

```
Raw: src_ip=10.0.0.1, dest_ip=192.168.1.1, action=allow
CIM: src_ip=10.0.0.1, dest_ip=192.168.1.1, action=allowed
ECS: source.ip=10.0.0.1, destination.ip=192.168.1.1, event.outcome=success
ASIM: SrcIpAddr=10.0.0.1, DstIpAddr=192.168.1.1, EventResult=Success
UDM: principal.ip=10.0.0.1, target.ip=192.168.1.1, security_result.action=ALLOW
```

Without normalization, cross-source correlation is impossible. Every vendor names fields differently.

### Enrichment

Add context to events after normalization:

- **GeoIP** -- Map IP addresses to geographic location
- **ASN lookup** -- Identify the organization owning an IP
- **Threat intelligence** -- Match IOCs (IPs, domains, hashes) against TI feeds
- **Asset inventory** -- Add asset criticality, owner, business unit
- **Identity context** -- Map usernames to employees, roles, departments
- **WHOIS / DNS** -- Domain age, registrar, resolution history

### Indexing and Storage

How SIEM platforms store data:

| Approach | Platforms | Trade-offs |
|---|---|---|
| **Inverted index** | Splunk, Elastic | Fast full-text search; storage overhead for index structures |
| **Columnar storage** | QRadar (Ariel), Sentinel (Log Analytics) | Efficient aggregations; slower for full-text search |
| **Index-free (compressed raw + bloom filters)** | LogScale | Minimal storage overhead; streaming search; cold data is slower |
| **Hybrid** | Chronicle (UDM + raw) | Structured search on UDM, raw available for forensics |

### Retention

Retention requirements vary by compliance and operational needs:

| Requirement | Typical Retention | Driver |
|---|---|---|
| **Real-time detection** | 0-90 days (hot) | SOC operations, active investigations |
| **Investigation / Hunt** | 90-365 days (warm) | Incident response, threat hunting |
| **Compliance (PCI DSS)** | 1 year online, 1 year archive | PCI DSS Requirement 10.7 |
| **Compliance (HIPAA)** | 6 years | HIPAA audit trail requirements |
| **Compliance (SOX)** | 7 years | Financial audit trail |
| **Legal hold** | Indefinite | Litigation preservation |

## Event Correlation

### Correlation Rule Types

| Type | Description | Example |
|---|---|---|
| **Single-event** | One event matches a condition | Failed login from a blocked country |
| **Threshold** | Count exceeds a limit in a time window | > 10 failed logins in 5 minutes |
| **Sequence** | Events occur in a specific order | Login -> privilege escalation -> data access (within 1 hour) |
| **Aggregation** | Statistical anomaly in grouped events | User accessing 10x more files than their peer group |
| **Absence** | Expected event does NOT occur | No heartbeat from critical server in 10 minutes |
| **Temporal proximity** | Related events across sources within a time window | VPN login from country A + badge swipe in country B within 2 hours |

### Correlation Best Practices

1. **Start with high-fidelity, low-volume rules** -- A rule that fires once a week with 90% true-positive rate is more valuable than one that fires 100 times a day at 5%.
2. **Correlate across data sources** -- Single-source detections are easy to evade. Cross-source correlation (e.g., EDR + identity + network) is harder to bypass.
3. **Use risk scoring** -- Assign risk points per event and alert when an entity's cumulative score exceeds a threshold (risk-based alerting).
4. **Include context in alerts** -- An alert should contain: what happened, who/what was involved, when, where (asset, network segment), why it matters (ATT&CK technique), and suggested next steps.
5. **Version-control detection rules** -- Treat detections as code. Use Git for versioning, CI/CD for deployment, and peer review for changes.

## SIGMA Rule Language

### Rule Structure

```yaml
title: Descriptive name of the detection
id: UUID (globally unique, persistent)
related:
    - id: UUID-of-related-rule
      type: derived | obsoletes | merged | renamed | similar
status: test | stable | experimental | deprecated | unsupported
description: What this rule detects and why
references:
    - https://link-to-threat-research
author: Author name
date: YYYY/MM/DD
modified: YYYY/MM/DD
tags:
    - attack.tactic_name        # e.g., attack.execution
    - attack.technique_id       # e.g., attack.t1059.001
    - cve.YYYY.NNNNN           # Optional CVE reference
logsource:
    category: process_creation | network_connection | file_event | ...
    product: windows | linux | macos | ...
    service: sysmon | security | ...
detection:
    selection:
        FieldName|modifier: value
    filter:
        FieldName: value_to_exclude
    condition: selection and not filter
fields:
    - CommandLine
    - ParentImage
falsepositives:
    - Legitimate admin tool usage
level: informational | low | medium | high | critical
```

### SIGMA Modifiers

| Modifier | Meaning | Example |
|---|---|---|
| `contains` | Substring match | `CommandLine\|contains: '-enc'` |
| `startswith` | Prefix match | `Image\|startswith: 'C:\Temp'` |
| `endswith` | Suffix match | `Image\|endswith: '.ps1'` |
| `all` | All values must match | `CommandLine\|contains\|all:` followed by list |
| `base64` | Match base64-encoded value | `CommandLine\|base64: 'malicious string'` |
| `re` | Regular expression | `CommandLine\|re: '.*-e[nc]{0,3}o[de]{0,2}.*'` |
| `cidr` | CIDR range match | `DestinationIp\|cidr: '10.0.0.0/8'` |
| `windash` | Match Windows dash variants (-, /) | `CommandLine\|windash\|contains: '-bypass'` |

### SIGMA Backends

SIGMA rules compile to platform-specific queries using backends (formerly sigmac, now pySigma + sigma-cli):

```bash
# Convert to Splunk SPL
sigma convert -t splunk -p sysmon rule.yml

# Convert to Sentinel KQL
sigma convert -t microsoft365defender rule.yml

# Convert to Elastic (Lucene)
sigma convert -t lucene rule.yml

# Convert to QRadar AQL
sigma convert -t qradar rule.yml
```

## Detection Engineering Methodology

### MITRE ATT&CK Mapping

Map detections to ATT&CK to measure coverage:

1. **Identify relevant techniques** -- Not all 200+ techniques apply to every environment. Filter by platform (Windows, Linux, Cloud, Network) and threat profile.
2. **Map data sources** -- Each technique lists required data sources. Verify you are collecting them.
3. **Write detections per technique** -- Aim for multiple detections per technique (different data sources, different fidelity levels).
4. **Track coverage** -- Use ATT&CK Navigator to visualize detection coverage. Identify gaps.

### Detection Quality Tiers

| Tier | Description | Characteristics |
|---|---|---|
| **Tier 1 -- IOC-based** | Match known-bad indicators (IPs, hashes, domains) | Fast to create, trivially evaded, short shelf life |
| **Tier 2 -- Behavioral signatures** | Match specific tool/technique patterns | Medium effort, moderate evasion resistance |
| **Tier 3 -- Behavioral analytics** | Detect anomalous behavior regardless of specific tool | High effort, hard to evade, higher false-positive rate |
| **Tier 4 -- ML-driven** | Statistical models detect deviations from baseline | Highest effort, requires training data, lowest false-negative rate for novel threats |

Mature detection programs invest primarily in Tier 2 and Tier 3 detections.

### Detection-as-Code

Treat detection rules like software:

```
detection-rules/
├── rules/
│   ├── windows/
│   │   ├── process_creation/
│   │   │   ├── powershell_download_cradle.yml
│   │   │   └── suspicious_lolbin.yml
│   │   └── registry/
│   │       └── run_key_persistence.yml
│   └── cloud/
│       ├── aws/
│       │   └── iam_user_created.yml
│       └── azure/
│           └── conditional_access_disabled.yml
├── tests/
│   ├── test_powershell_download_cradle.py
│   └── test_suspicious_lolbin.py
├── pipelines/
│   ├── splunk_pipeline.yml
│   └── sentinel_pipeline.yml
└── CI/
    └── .github/workflows/deploy-detections.yml
```

Workflow: author rule -> peer review -> automated testing (sigma validate, sigma convert) -> deploy to SIEM -> monitor fidelity metrics.

## SOC Maturity Model

| Level | Characteristic | Detection | Response | Metrics |
|---|---|---|---|---|
| **1 -- Initial** | Ad hoc, reactive | Vendor default rules only | Manual, inconsistent | None tracked |
| **2 -- Managed** | Basic processes defined | Tuned vendor rules, some custom | Documented playbooks | MTTD, MTTR tracked |
| **3 -- Defined** | Detection engineering program | SIGMA-based, ATT&CK-mapped, version-controlled | SOAR-assisted automation | Alert fidelity, coverage tracked |
| **4 -- Measured** | Metrics-driven improvement | Continuous testing (purple team), ML enrichment | Automated triage + response for common scenarios | Full SOC KPI dashboard |
| **5 -- Optimized** | Threat-informed defense | Threat intelligence-driven detection priorities, hypothesis-driven hunting | Mostly automated, human review for complex cases | Continuous improvement cycle |

## SOAR Fundamentals

### When to Use SOAR

SOAR adds value when:
- Alert volume exceeds analyst capacity (> 100 alerts/day with < 5 analysts)
- Repetitive triage steps can be codified (IOC lookup, asset enrichment, user context)
- Response actions are well-defined (block IP, disable account, isolate endpoint)
- Multiple tools require orchestration (SIEM + EDR + firewall + ticketing)

SOAR does NOT replace:
- Human judgment for complex incidents
- Good detection engineering (automating bad detections is counterproductive)
- Defined processes (you must have a manual playbook before automating it)

### Playbook Design Patterns

| Pattern | Description | Example |
|---|---|---|
| **Enrichment** | Gather context from multiple sources | Query TI, lookup asset, check user risk score |
| **Triage** | Automated decision on alert validity | If known-false-positive pattern, auto-close; else escalate |
| **Containment** | Execute response actions | Isolate endpoint via EDR API, block hash, disable user |
| **Notification** | Alert humans through appropriate channels | Slack, PagerDuty, email, ticketing system |
| **Full lifecycle** | End-to-end: enrich -> triage -> contain -> notify -> document | Complete incident response for specific alert types |

### SOAR Integration Architecture

```
SIEM Alert
    |
    v
SOAR Ingestion (webhook, API poll, syslog)
    |
    v
Playbook Engine
    |
    ├── Enrichment APIs (TI, CMDB, identity, GeoIP)
    ├── Decision Logic (thresholds, allow/block lists, ML scores)
    ├── Response APIs (EDR, firewall, IAM, email gateway)
    └── Ticketing (ServiceNow, Jira, internal ITSM)
    |
    v
Case Management / War Room
    |
    v
Metrics & Reporting
```
