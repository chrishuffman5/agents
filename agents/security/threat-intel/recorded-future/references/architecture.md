# Recorded Future Architecture Reference

## Intelligence Cloud Architecture

### Data Ingestion Pipeline

```
Raw Sources (1M+)
    ↓
Collectors (web crawlers, API connectors, human analysts)
    ↓
Raw Data Store
    ↓
NLP/AI Processing Pipeline
    ├── Entity Extraction (IPs, domains, hashes, CVEs, actor names)
    ├── Relationship Extraction (actor → uses → malware)
    ├── Sentiment/Context Classification
    ├── Translation (50+ languages)
    └── Deduplication
    ↓
Intelligence Graph (entity + relationship store)
    ↓
Risk Scoring Engine
    ↓
API + Portal + Integrations
```

### Intelligence Graph

The Intelligence Graph is the core data model:
- **Nodes**: Any entity (IP, domain, hash, CVE, threat actor, organization, location, malware family, etc.)
- **Edges**: Typed relationships between nodes (sighted-on, used-by, resolves-to, attributed-to, exploits, etc.)
- **Evidence**: Each edge has supporting evidence (source documents, timestamps, confidence)

**Scale:** Hundreds of billions of entities and relationships.

**Example graph traversal (analyst POV):**
- Start: IP address 198.51.100.42
- Edge: `used-as-c2-by` → Malware family: LockBit 3.0
- Edge: `operated-by` → Intrusion set: LockBit RaaS operation
- Edge: `targets` → Sector: Healthcare
- Edge: `exploits` → CVE: CVE-2023-4966 (Citrix Bleed)
- **Result**: Context chain showing this IP connects to LockBit via Citrix exploitation targeting healthcare

### Collective Insights

Collective Insights is Recorded Future's customer telemetry aggregation:

**Data flow:**
1. Customer deploys RF connector to SIEM or endpoint
2. Connector observes network connections, DNS queries, and file hashes
3. Observed entities (IPs, domains, hashes) are sent to RF (not the content of connections)
4. RF aggregates across all customers: "IP X has been seen making connections in 47 customer environments"
5. High customer-environment prevalence increases IP/domain risk score

**Privacy protections:**
- RF receives entity metadata only (the IP was seen), not connection content
- No PII transmitted
- Customer identity not associated with specific entity observations (anonymized)
- Customer data not shared with other customers

**Value:** Collective Insights surfaces malicious infrastructure that has no public evidence but has been observed maliciously in real customer environments.

## Risk Scoring Algorithm

### Input Signals

| Signal Category | Signal Examples | Weight |
|---|---|---|
| Threat community mentions | Mentioned in hacker forum as target for exploit | High |
| Active exploitation evidence | PoC published, exploitation in the wild | Very High |
| Historical associations | Previously used as C2; previously in breach | Medium |
| Collective Insights data | Seen as malicious in N customer environments | Very High |
| Recency | Recent activity scores higher than old activity | Multiplier |
| Source credibility | High-credibility source (government advisory) vs. unknown forum post | Multiplier |

### Score Decay

Risk scores decay over time without reinforcing signals:
- Very active threat: Maintains high score (new signals continuously)
- Old C2 server (abandoned): Score decays from 85 to 25 over weeks/months
- Goal: Reduce false positives from stale indicators

Analysts can view score history graph on any entity card to understand whether risk is rising, stable, or declining.

### Risk Rule Confidence

Each risk rule has a confidence level:
- `Confirmed`: Multiple high-confidence sources, or direct RF analyst review
- `Likely`: Consistent evidence from credible sources
- `Possible`: Single source or lower-credibility evidence

Rules with `Confirmed` confidence contribute more to the risk score than `Possible` rules.

---

## Portal Architecture

### Authentication

- Username/password with MFA (TOTP)
- SAML 2.0 SSO (Azure AD, Okta, PingFederate)
- API Key authentication for integrations
- Role-based access (admin, analyst, reader, API-only)

### Data Access Controls

- **Module-based licensing**: Access to specific RF modules (SecOps, Vulnerability, Identity, etc.)
- **Field-level access**: Some customers restrict access to dark web data based on compliance needs
- **API access**: Each API key can be scoped to specific entity types and operations

---

## API Reference (Detailed)

### Authentication

All API requests require:
```
Authorization: Token {your_api_key}
```

Rate limits:
- Default: 10 requests/second per API key
- Bulk endpoints: Lower per-request rate; higher throughput per request
- Contact RF for rate limit increases if needed for large integrations

### Entity Enrichment Endpoints

**IP enrichment with fields parameter:**
```
GET /v2/ip/{ip}?fields=risk,relatedEntities,metrics,timestamps
```

Fields available:
- `risk`: Score, rules, criticality
- `relatedEntities`: Related threat actors, malware, vulnerabilities (with relationship type)
- `metrics`: Mention count by source type
- `timestamps`: First seen, last seen
- `location`: Geolocation, ASN, organization

**Domain enrichment:**
```
GET /v2/domain/{domain}?fields=risk,relatedEntities,dnsEntries,whois
```

Extra fields:
- `dnsEntries`: Passive DNS history (IP resolutions over time)
- `whois`: Registration data history

**Hash enrichment:**
```
GET /v2/hash/{hash}?fields=risk,relatedEntities,analysisResults
```

Extra fields:
- `analysisResults`: Sandbox/AV analysis results
- `hashAlgorithm`: MD5, SHA-1, or SHA-256

### Bulk Lookup

For SIEM enrichment (process many indicators at once):

```
POST /v2/ip/lookup
Content-Type: application/json
{
  "ips": ["1.1.1.1", "2.2.2.2", "3.3.3.3"],
  "fields": ["risk"]
}
```

Response:
```json
{
  "data": {
    "results": [
      {"ip": "1.1.1.1", "risk": {"score": 92, "criticality": 4, "criticalityLabel": "Very Malicious"}},
      ...
    ]
  }
}
```

Bulk limits: Up to 1,000 entities per request.

### Alert API

```
GET /v2/alert/search?triggered=datetimeRange:[2024-11-01T00:00:00Z,2024-11-02T00:00:00Z]&limit=100

POST /v2/alert/{alert_id}/update
{
  "assignee": "analyst@example.com",
  "status": "Actioned"
}
```

### STIX/TAXII Endpoint

RF provides a TAXII 2.1 server for SIEM/TIP integration:

Discovery URL: `https://api.recordedfuture.com/taxii2/`

Collections available (varies by module subscription):
- `indicators`: IOC feed (IP, domain, hash, URL indicators)
- `threat-actors`: Threat actor intelligence
- `malware`: Malware family intelligence
- `vulnerabilities`: CVE intelligence

Polling for new indicators:
```
GET /taxii2/{api_root}/collections/indicators/objects/?added_after=2024-11-01T00:00:00Z&type=indicator
```

---

## Integration Architecture

### SIEM Integration Patterns

**Pattern 1: Automated IOC ingestion**
- Purpose: Block known-malicious IPs/domains/hashes at firewall, proxy, EDR
- Mechanism: Daily TAXII poll → ingest STIX indicators → push to blocklist/SIEM watchlist
- Considerations: Use RF risk score threshold (e.g., score ≥ 65) to limit false positives; set expiry on IOCs

**Pattern 2: Alert enrichment**
- Purpose: Add context to SIEM alerts when they fire on an IP/domain/hash
- Mechanism: SIEM alert trigger → lookup entity in RF API → add RF context to alert
- Implementation: SIEM alert action (Splunk alert action, Sentinel playbook, etc.)
- Result: Analyst sees RF context (risk score, malware family, threat actor) immediately when alert fires

**Pattern 3: Proactive monitoring**
- Purpose: Alert before attackers reach your perimeter
- Mechanism: RF keyword alerts → SIEM webhook → SOC ticket creation
- Triggers: Company mention in hacker forum, credential exposure, typosquat domain registration

### SOAR Integration Architecture

SOAR playbook integration for typical triage flow:

```
SIEM Alert
  ↓
SOAR Playbook: Triage
  ├── Extract: source IP, destination domain, file hash from alert
  ├── Enrich: RF API lookup for each entity
  │   ├── RF returns: risk score, risk rules, related threat actor
  │   └── Playbook adds enrichment to case
  ├── Decision:
  │   ├── RF risk score ≥ 90: Auto-escalate to T2, add to blocklist
  │   ├── RF risk score 65-89: Assign to T1 for review
  │   └── RF risk score < 65: Suppress (low priority)
  └── Update SIEM: Case updated with enrichment and priority
```

### Splunk App Architecture

The RF Splunk app provides:
- `rfetch` command: Fetch RF intelligence for IPs, domains, hashes from within SPL queries
- Lookup tables: Pre-cached RF risk scores (refreshed daily)
- Dashboard: RF intelligence overview panel
- Alert action: Automatic RF lookup when alert fires

SPL usage:
```spl
| lookup rf_ip_threat_intel ip AS src_ip OUTPUTNEW risk_score, risk_rules, related_malware
| where risk_score >= 65
| table src_ip, risk_score, risk_rules, related_malware, _time, _raw
```

### Microsoft Sentinel Architecture

RF integrates with Sentinel via:
1. Threat Intelligence data connector (TAXII-based): Pulls STIX indicators from RF
2. Sentinel Threat Intelligence Matching Analytics: Auto-creates incidents when matching IOCs appear in logs
3. Workbook: RF-enriched visualizations

Configuration:
- Add RF TAXII server URL to Sentinel Threat Intelligence connector
- Set polling interval (hourly recommended)
- Configure TI matching analytics to alert on RF indicators with score ≥ 65

---

## Browser Extension Architecture

### Extension Function

The browser extension injects into all web pages to:
1. Scan visible text for RF-recognizable entities (IPs, domains, hashes, CVEs, threat actor names)
2. Highlight recognized entities with a color indicator
3. On hover: Fetch risk score from RF API and display inline tooltip

**Color coding:**
- Red: Score 65+ (Malicious/Very Malicious)
- Yellow: Score 25-64 (Unusual)
- Blue/Gray: Score < 25 or informational entity

### Privacy Considerations

The extension sends recognized entities to RF API for lookup:
- Any IP, domain, or hash visible on screen is looked up in RF
- In sensitive environments, this may create disclosure issues (e.g., internal IPs, pending investigation details)
- Mitigation: Configure extension to run only on specific domains (security tool UIs, not general browsing)

---

## Mastercard Integration (Post-Acquisition)

Following Mastercard's 2024 acquisition of Recorded Future:

**Enhanced capabilities being developed:**
- Financial transaction fraud intelligence feeding into RF risk scores
- Payment network telemetry for financial sector threat actors
- Integration with Mastercard CyberSecure and RiskRecon (third-party risk) products
- Enhanced coverage of financially-motivated threat actor infrastructure

**Operational continuity:**
- RF platform continues as independent product
- Existing API contracts and integrations unchanged
- Pricing/licensing administered through RF and Mastercard
