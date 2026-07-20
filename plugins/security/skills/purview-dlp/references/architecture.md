# Microsoft Purview DLP Architecture Reference

Deep architecture reference for Microsoft Purview DLP. Load this for "how does it work" questions, integration design, or advanced troubleshooting.

---

## Platform Architecture Overview

```
Microsoft Purview Compliance Portal (compliance.microsoft.com)
│
├── Data Classification Engine
│   ├── Sensitive Information Types (SIT) — Regex + keyword + validation
│   ├── Trainable Classifiers — ML-based document classification
│   ├── Exact Data Match (EDM) — Hashed record fingerprinting
│   └── Named Entity Recognition — Neural models (Full Names, Medical Terms, Addresses)
│
├── DLP Policy Engine
│   ├── Policy definitions stored in Compliance backend
│   ├── Policies distributed to each workload's enforcement point
│   └── Priority ordering for conflict resolution
│
├── Enforcement Points (per workload)
│   ├── Exchange Online Protection (EOP) — Email inspection pipeline
│   ├── SharePoint / OneDrive — File upload/share event hooks
│   ├── Microsoft Teams — Message/file event hooks
│   ├── Endpoint DLP Agent — Windows/macOS kernel-mode agent
│   ├── Power BI / Fabric — Report/dataset access hooks
│   └── Microsoft Defender for Cloud Apps — Third-party SaaS via CASB
│
├── Reporting & Investigation
│   ├── Activity Explorer — DLP events, label changes, endpoint activities
│   ├── Content Explorer — Sensitive content inventory
│   ├── DLP Alerts Dashboard — Alert queue for security team
│   └── Microsoft 365 Defender Integration — Incident correlation
│
└── Integration Layer
    ├── Insider Risk Management (IRM) — Adaptive Protection signals
    ├── Microsoft Sentinel — SIEM integration via connector
    ├── Microsoft Defender for Endpoint — Endpoint onboarding + signals
    └── AI Hub / Copilot — Prompt inspection pipeline
```

---

## Classification Engine

### SIT Detection Pipeline

When content is inspected by a DLP policy, it goes through a multi-stage pipeline:

```
Stage 1: Content Extraction
  → Text extracted from document (Word, Excel, PDF, email body/attachments)
  → For images/PDFs: OCR engine extracts embedded text (if OCR enabled)
  → File metadata extracted (filename, extension, size)

Stage 2: Tokenization
  → Content split into tokens (words, phrases, n-grams)
  → Proximity windows calculated for booster evidence

Stage 3: Pattern Matching
  → Regex patterns applied to token stream
  → Checksum validators run (Luhn for credit cards, etc.)
  → Results: candidate matches with position and raw text

Stage 4: Confidence Scoring
  → Base confidence assigned by primary pattern match quality
  → Evidence boosters applied:
      + Keyword within X characters: confidence boost
      + Corroborating SIT nearby: confidence boost
      - Keywords indicating false positive context: confidence reduction
  → Final confidence bucketed: Low / Medium / High

Stage 5: Policy Evaluation
  → Matches with sufficient confidence sent to policy engine
  → Policy conditions evaluated (SIT present? count threshold met? sharing context?)
  → Actions determined based on matched rules

Stage 6: Action Execution
  → Enforcement point receives action instructions
  → Action applied (block, notify, encrypt, log)
  → Event recorded to Activity Explorer
```

### Named Entity SITs — Neural Model Architecture

Named Entity SITs (All Full Names, All Physical Addresses, All Medical Terms) use:
- Transformer-based NER (Named Entity Recognition) models
- Context-aware extraction — understands document structure
- Multi-language support
- Higher accuracy than regex for complex entities

**Requirements for Named Entity SITs:**
- Enhanced classification must be enabled in Compliance settings
- Higher latency than regex SITs — factor into policy design
- Supported locations: Exchange, SharePoint, OneDrive, Teams, Endpoints (Windows)
- Not yet available for all third-party app inspections

---

## Exact Data Match (EDM) Architecture

### EDM Data Flow

```
Customer Environment                    Microsoft 365 Service

Sensitive Database                      EDM Token Store
(employee_records.csv)                  (Hash index only — no plaintext)
        │                                       │
        ▼                                       │
EDM Upload Agent                               │
├── Hash source data                            │
│   (SHA-256 per cell value)                   │
├── Build hash index file                      │
└── Upload hashes via HTTPS ──────────────────►│
                                               │
                                               │
Content Being Inspected                        │
(email, file, endpoint activity)               │
        │                                       │
        ▼                                       │
Classification Engine                          │
├── Tokenize inspected content                 │
├── Hash candidate tokens                      │
└── Lookup hashes against index ◄─────────────┘
        │
        ▼
Match: Hash found in index → EDM SIT triggered
No match: No hash collision → Pass through
```

### EDM Schema Design Best Practices

```xml
<!-- Example EDM schema for employee PII -->
<EdmSchema xmlns="http://schemas.microsoft.com/office/2018/edm">
  <DataStore name="EmployeePII" description="Employee PII data" version="1">
    <Field name="LastName" searchable="true" />
    <Field name="FirstName" searchable="true" />
    <Field name="SSN" searchable="true" caseInsensitive="false" ignoredDelimiters="- ." />
    <Field name="DateOfBirth" searchable="true" />
    <Field name="EmployeeID" searchable="false" />
    <Field name="Department" searchable="false" />
  </DataStore>
</EdmSchema>
```

**Schema design rules:**
- Mark as `searchable="true"` only fields that need to be detected
- `ignoredDelimiters` allows "123-45-6789" and "123456789" to match the same hash
- Non-searchable fields provide corroborating context (increase match confidence) but aren't the primary trigger
- Maximum 5 searchable fields per schema recommended for performance

### EDM Match Configuration

```
Single-field match (lower confidence, higher FP risk):
  Match: Any single searchable field (e.g., SSN alone)
  Use for: Very unique identifiers with low false positive risk

Multi-field match (higher confidence, lower FP risk):
  Match: SSN + LastName (2 fields must match from same record)
  Confidence: High — near-impossible to match by coincidence
  Use for: Data types where single field might appear legitimately (names, DOB)
```

**Recommended EDM match configuration for employee PII:**
- Primary element: SSN (searchable)
- Additional match: LastName + FirstName (both must match the same record row)
- Result: Only triggers when full SSN + name combination matches an actual employee record

---

## Endpoint DLP Agent Architecture

### Agent Components (Windows)

```
Microsoft Defender for Endpoint Agent
└── Includes Purview Endpoint DLP component
    ├── Kernel-mode driver (MsSense.sys / MpSsm.sys)
    │   ├── Intercepts I/O operations at kernel level
    │   ├── File reads/writes, process creation, network connections
    │   └── Low latency — operates in kernel space
    │
    ├── User-mode service (MsSense.exe / SenseIR.exe)
    │   ├── Content classification (calls SIT/classifier engine)
    │   ├── Policy evaluation
    │   ├── User notification (toast notifications, policy tips)
    │   └── Event logging and telemetry upload
    │
    ├── Browser extensions (required for web upload blocking)
    │   ├── Microsoft Edge: built-in DLP support
    │   ├── Chrome: Microsoft Compliance Extension
    │   └── Firefox: Microsoft Compliance Extension
    │
    └── Classification service
        ├── Local SIT pattern matching (offline capable)
        └── Cloud classification for advanced classifiers
```

### Endpoint DLP Activity Detection

**How clipboard monitoring works:**
1. Kernel driver intercepts clipboard write operations
2. Content extracted from clipboard buffer
3. SIT classification run against content
4. If sensitive: check destination application against allowed app groups
5. If destination is an unallowed app: block paste / alert

**How USB blocking works:**
1. Kernel driver monitors removable media mount events
2. File write operations to removable media intercepted
3. Source file classified (already classified on write, or re-classified on copy)
4. If sensitive + USB not in allowed device group: block copy / notify user
5. Event logged with file name, destination device, user, timestamp

**How browser upload blocking works:**
1. Browser extension monitors HTTP POST/multipart form submissions
2. File being uploaded identified before transmission
3. Classification check: is this file tagged as sensitive?
4. If destination domain not in allowed domain list AND file is sensitive: block upload
5. User sees notification: "This file is sensitive and cannot be uploaded to this site"

### macOS Endpoint DLP

**Architecture differences from Windows:**
- System Extension model (replaces kernel extensions in macOS 11+)
- Full Disk Access permission required (user must grant via System Preferences)
- Browser support: Safari (native), Chrome, Firefox (extension required)
- Monitored activities: file copies, clipboard, printer, cloud sync, browser upload
- Screen capture restriction: advisory only (cannot technically block all methods)

---

## DLP Policy Distribution and Evaluation

### Policy Propagation

```
Policy Change in Compliance Portal
        │
        ▼ (15-30 minutes)
Compliance Backend → Distributes to workload services
        │
        ├──► Exchange Online Protection (near-real-time for email)
        ├──► SharePoint / OneDrive (24-48 hours for full consistency)
        ├──► Teams service (near-real-time)
        └──► Endpoint Devices (up to 24 hours for policy refresh)
```

**Important timing notes:**
- Email (Exchange): Policy changes propagate in 15-30 minutes
- SharePoint/OneDrive: Content scans may take up to 24-48 hours for existing files
- Endpoints: Devices poll for policy updates periodically (up to 24 hours)
- New policy changes: Allow 24 hours before concluding policy is not working

### Policy Priority and Conflict Resolution

```
When multiple policies match the same content event:

1. All matching policies are evaluated
2. Actions are aggregated:
   → Block from any policy wins over Notify-only from another
   → Most restrictive action applied
3. Most severe notification shown to user (one policy tip, not multiple)
4. All matching policies logged in Activity Explorer

Priority ordering:
→ Higher-numbered priority = lower priority (evaluated after lower numbers)
→ Explicit block rules override allow rules
→ Auto-labeled sensitivity labels can trigger additional policies
```

---

## Adaptive Protection Architecture

### Integration with Insider Risk Management

```
Insider Risk Management
├── Data theft policies (detect unusual data access + exfiltration)
├── Data leaks policies (detect oversharing + policy violations)
├── Security policy violations
└── Risky browser usage

IRM Risk Scoring Engine
├── Exfiltration volume signals (file counts, size, velocity)
├── Anomaly signals (access to unusual files, unusual hours)
├── Cumulative risk score → Risk level: None / Minor / Moderate / Elevated / Severe

Adaptive Protection Bridge
├── Maps IRM risk levels to DLP user risk levels
└── Feeds risk level into DLP policy evaluation context

DLP Policy Engine
├── Standard policies: Apply to all users regardless of risk level
└── Adaptive policies: Apply based on user's current IRM risk level
    → Elevated risk: Add "require justification" to file copy
    → High risk: Block USB + cloud upload for this user
    → Severe risk: Block all external sharing + alert security team
```

**Key characteristics:**
- Risk-level assignment is dynamic — resets when IRM clears the user
- No explicit block list — enforcement changes automatically with risk score
- Principle of least friction: low-risk users have minimal friction; risk increases enforcement
- Users are not notified of their risk level — reduces "gaming" behaviors

---

## AI Hub and Copilot DLP

### M365 Copilot Data Flow

```
User Prompt → M365 Copilot Service
                    │
                    ├── Retrieves context from M365 content
                    │   (SharePoint, OneDrive, email, Teams)
                    │   └── Only content user has access to
                    │
                    ├── Prompt + context → LLM (GPT-4 class model)
                    │
                    └── Response generated → returned to user

AI Hub DLP Inspection Point:
  → Before context is passed to LLM, DLP inspects the referenced content
  → If sensitive content (SIT match or label): block Copilot from using it
  → User sees: "Copilot cannot access this content due to sensitivity restrictions"
```

### What AI Hub Controls vs. Does Not Control

**Controls:**
- Copilot referencing sensitive labeled/classified content in prompts
- Copilot summarizing documents tagged as Highly Confidential
- Copilot drafting emails that reference sensitive SharePoint content

**Does NOT control:**
- User manually copying sensitive content into a Copilot chat (covered by Endpoint DLP)
- Content the user legitimately has access to — Copilot respects existing permissions
- Access controls — AI Hub adds a DLP inspection layer, not a permission layer

---

## Activity Explorer Deep Reference

### Event Schema

Each Activity Explorer event contains:

```
event_time: ISO 8601 timestamp
workload: Exchange / SharePoint / OneDrive / Teams / Endpoint
activity_type: PolicyMatched / PolicyTipDisplayed / LabelApplied / FileCopied / etc.
user: UPN of the acting user
item_name: File name or email subject
item_path: Full URL or file path
sensitive_info_types: [array of SIT names matched]
sensitivity_label: Current label on the item (if any)
dlp_policy: Policy name that triggered
dlp_rule: Rule name within the policy
action_taken: Blocked / Override / NotificationShown / Audit
override_justification: Text if user overrode (if applicable)
location: Geographic location (for endpoint)
device_name: Endpoint device name (for endpoint events)
```

### Retention and Querying

- Activity Explorer data retained: 30 days by default (180 days with appropriate retention settings)
- Export limit: 50,000 events per export operation
- For longer-term retention: stream to Microsoft Sentinel or SIEM via connector

**Useful filters:**
```
Filter by policy: Shows all events matching a specific DLP policy
Filter by activity: PolicyMatched (all DLP events), FileOverrideByUser (all user overrides)
Filter by location: Endpoint (for USB/clipboard events), Exchange (email)
Date range: Up to 180 days
User filter: Investigate specific user behavior
```

---

## Microsoft Sentinel Integration

### DLP Events in Sentinel

```
Connector: Microsoft 365 Defender / Purview connector
Tables populated:
  CloudAppEvents — DLP events from Exchange, SharePoint, OneDrive, Teams
  DeviceFileEvents — Endpoint DLP file activities
  DeviceEvents — Clipboard, USB events on endpoints
  AlertInfo / AlertEvidence — DLP alerts surfaced as Defender incidents
```

**Sample KQL for DLP investigation:**
```kql
// DLP policy matches in last 7 days
CloudAppEvents
| where Timestamp > ago(7d)
| where ActionType == "DlpPolicyMatch"
| summarize MatchCount = count() by PolicyName = tostring(RawEventData.PolicyName), 
    UserPrincipalName, bin(Timestamp, 1d)
| order by MatchCount desc

// Users with high override rates (potential risk indicators)
CloudAppEvents
| where Timestamp > ago(30d)
| where ActionType == "DlpRuleOverrideByUser"
| summarize Overrides = count() by UserPrincipalName
| where Overrides > 5
| order by Overrides desc

// Endpoint USB copy events of sensitive files
DeviceEvents
| where Timestamp > ago(7d)
| where ActionType == "UsbDriveMounted"
| join kind=inner (
    DeviceFileEvents
    | where ActionType == "FileCreated"
    | where FolderPath startswith "E:\\" or FolderPath startswith "F:\\"  // removable drive letters
) on DeviceId, Timestamp
```

---

## Licensing and Feature Matrix

| Feature | E3 | E5 | E5 Compliance | Note |
|---|---|---|---|---|
| DLP for Exchange/SPO/OD | Yes | Yes | Yes | Basic SITs only for E3 |
| Teams DLP | No | Yes | Yes | |
| Endpoint DLP | No | Yes | Yes | |
| EDM | No | No | Yes | |
| Custom trainable classifiers | No | No | Yes | |
| Named entity SITs | No | No | Yes | |
| Adaptive Protection | No | No | Yes | + IRM add-on |
| AI Hub / Copilot DLP | No | No | Yes | + M365 Copilot license |
| Content Explorer | Limited | Yes | Yes | Content viewer role needed |
| Activity Explorer | Read-only | Full | Full | |
| On-premises DLP (Scanner) | No | No | Yes | |
