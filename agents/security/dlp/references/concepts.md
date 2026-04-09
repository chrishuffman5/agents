# DLP Concepts Reference

Deep reference for Data Loss Prevention fundamentals. Load this when answering architecture, design, or vendor-neutral DLP questions.

---

## Data Classification Framework

### Classification Tiers

A four-tier model is the industry standard. Map regulatory requirements to tiers, not individual policies.

```
Tier 1 — PUBLIC
  Definition: Information approved for public distribution
  Examples: Press releases, published research, job postings, public-facing marketing
  Controls: None required; no DLP enforcement
  Labeling: Optional; sometimes labeled for completeness

Tier 2 — INTERNAL
  Definition: General business information not intended for external sharing
  Examples: Internal memos, org charts, non-sensitive emails, meeting notes
  Controls: Block bulk exfiltration; log anomalous sharing
  Labeling: Default label for unlabeled documents

Tier 3 — CONFIDENTIAL
  Definition: Sensitive business data requiring protection from unauthorized disclosure
  Examples: Customer lists, contracts, strategic plans, financial projections, personnel data
  Controls:
    - Encrypt at rest and in transit
    - Block sharing to personal email/cloud without justification
    - Require authentication for external access
    - Audit all downloads
  Labeling: Required; applied manually or by auto-classification

Tier 4 — RESTRICTED / HIGHLY CONFIDENTIAL
  Definition: Highest-sensitivity data — regulatory exposure or critical business risk if disclosed
  Examples: PII/PHI, PAN/cardholder data, trade secrets, source code, M&A documents,
            HR terminations, executive compensation, ITAR-controlled technical data
  Controls:
    - Encrypt end-to-end with customer-managed keys where possible
    - Block all external sharing except via approved secure channels
    - Block USB, print, screen capture (where technically feasible)
    - Alert security team on any exfiltration attempt
    - Mandatory review before any external transfer
  Labeling: Required; auto-classification enforced + human review recommended
```

### Auto-Classification Approaches

**Rule-based auto-classification**
- Applies labels based on regex + keyword detection
- Fast, deterministic, easy to audit
- Risk: false positives if rules are too broad

**ML-based auto-classification**
- Uses trainable classifiers on document content
- Better at unstructured content (email bodies, Word docs)
- Requires training data; periodic retraining as content evolves

**Recommended auto-classification (advisory)**
- Suggests a label to the user without forcing it
- Reduces friction; increases adoption
- Risk: users may ignore or downgrade suggestions

**Mandatory classification**
- Requires user to select a label before saving/sending
- Highest assurance; maximum friction
- Typically reserved for Tier 3 and Tier 4 data

---

## Sensitive Information Types

### Structured PII (Regex-detectable)

| Data Type | Detection Method | Key Validation |
|---|---|---|
| US SSN | Regex `\d{3}-\d{2}-\d{4}` | Luhn-like checks, exclude invalid ranges (000, 666, 900+) |
| Credit Card (PAN) | Regex + Luhn algorithm | 13-19 digit, passes Luhn checksum |
| US Passport | Regex `[A-Z][0-9]{8}` | Less reliable without context |
| EU IBAN | Regex + checksum | Country-specific format + mod-97 validation |
| UK NI Number | Regex `[A-Z]{2}[0-9]{6}[A-D]` | Keyword context required |
| ABA Routing Number | Regex 9-digit + checksum | Paired with account number |
| DEA Number | Regex `[AB][A-Z0-9][0-9]{7}` | Checksum validation available |
| NPI (healthcare) | Regex 10-digit | Context: "NPI", "provider number" |
| AHV (Swiss SSN) | Regex `756\.\d{4}\.\d{4}\.\d{2}` | Checksum validation |

### Unstructured / Document Types (Classifier-detectable)

| Category | Content Signals | Classifier Approach |
|---|---|---|
| Financial statements | Balance sheet, income statement, EPS, GAAP | ML trainable classifier |
| HR / Personnel | Performance review, compensation, termination | ML trainable classifier |
| Legal / Contracts | Whereas, indemnification, governing law, signatures | ML trainable classifier |
| Source code | Import statements, function declarations, code syntax | ML + keyword |
| Medical records | Diagnosis codes, medication names, PHI fields | ML trainable classifier |
| M&A documents | Project codenames, "strictly confidential", board | ML + keyword |

---

## Detection Methods (Deep Reference)

### 1. Regular Expressions (Pattern Matching)

The foundation of DLP. Fast and low-cost, but requires careful tuning.

**Confidence scoring with context boosters:**
```
Base match: Regex fires alone → Low confidence (30%)
+ Proximity keyword ("social security", "SSN") within 50 chars → Medium (60%)
+ Multiple instances in same document (3+) → High (85%)
+ Document type consistent with data (HR form) → Very High (95%)
```

**Common false positive sources:**
- Phone numbers matching SSN patterns → Add hyphen/space format requirements
- Invoice numbers matching PAN → Require Luhn validation
- ZIP codes matching partial SSN → Require full 9-digit format
- European dates (DD-MM-YYYY) matching US date patterns → Localize patterns

**Tuning approach:**
1. Enable in audit mode for 2-4 weeks
2. Sample 100+ events; categorize as TP, FP, FN
3. Add exclusion keywords for systematic FP sources
4. Adjust minimum occurrence thresholds
5. A/B test before production enforcement

### 2. Exact Data Matching (EDM) — Structured Fingerprinting

Creates a hashed index of actual sensitive records. Detects when those exact values appear in data being inspected.

**How EDM works:**
```
1. Source: Export sensitive database (employee records, customer PII)
2. Hashing: Each cell value hashed (SHA-256 or similar) 
3. Index: Hashes stored in detection engine (not plaintext — source data never leaves)
4. Detection: Inspected content tokenized and hashed; compared to index
5. Match: Only fires when actual data values match — not patterns
```

**EDM strengths:**
- Near-zero false positives for exact matches
- Works for any structured data type (not limited to known formats)
- PII never exposed in detection engine (only hashes stored)

**EDM limitations:**
- Doesn't catch modified data (changed SSN digit, added spaces)
- Requires database refresh when source records change
- Compute-intensive for large datasets
- Doesn't work for unstructured/narrative content

**EDM best practices:**
- Re-index on a schedule (weekly for active databases, daily for high-value targets)
- Tune match threshold: require 3+ fields to match (not just one SSN)
- Protect the source database used for indexing (it contains the sensitive data)

### 3. Document Fingerprinting (Template Matching)

Creates a fingerprint of a template document. Detects variations of that template in the wild.

**Use cases:**
- W-9 / W-2 tax forms (detect when employees submit these internally or externally)
- NDAs (detect when signed NDAs are shared without authorization)
- Contract templates (detect when confidential contract text is being exfiltrated)
- Healthcare intake forms (detect PHI embedded in filled-out forms)

**How it works:**
- Template document converted to a word-frequency fingerprint
- DLP engine shingles (overlapping word sequences) the template
- Inspected content compared for shingle overlap
- Match threshold (typically 50-85% similarity) is tunable

### 4. ML / Trainable Classifiers

Statistical models trained on labeled document corpora. Classify documents by semantic content rather than specific patterns.

**Training data requirements:**
- Positive examples: 50+ representative documents of the sensitive type
- Negative examples: 50+ documents of similar but non-sensitive content
- Quality matters more than quantity
- Must reflect real-world distribution (include edge cases)

**Built-in classifiers (common across platforms):**

| Classifier | Trained On |
|---|---|
| Financial documents | Annual reports, financial statements, audit reports |
| HR documents | Resumes, performance reviews, offer letters |
| Source code | Code files across major programming languages |
| Medical records | Clinical notes, discharge summaries, lab reports |
| Legal documents | Contracts, agreements, court filings |
| Tax forms | W-2, 1099, Schedule C, corporate returns |

**Classifier lifecycle:**
1. Initial training with labeled corpus
2. Deploy in simulation mode → review precision/recall
3. Tune confidence threshold (higher = fewer FP, more FN)
4. Retrain periodically as content evolves (quarterly recommended)
5. Monitor for concept drift (classifier accuracy degrades over time)

### 5. OCR (Image and Screenshot Detection)

Applies text extraction to images before passing to other detection methods.

**When to use OCR:**
- Protect against screenshot-based exfiltration
- Detect sensitive data in scanned PDFs
- Monitor image uploads containing document photos

**Performance considerations:**
- OCR is CPU/GPU-intensive — 10-100x cost of text inspection
- Apply OCR selectively: only to file types that may contain sensitive text
- Exclude file types where OCR adds no value (audio, video, binary executables)
- Consider async inspection for non-real-time channels (cloud storage vs. email)

**Accuracy limitations:**
- Handwritten text: ~60-80% accuracy depending on clarity
- Low-resolution images: significant accuracy degradation
- Mixed-language documents: requires multi-language OCR support
- Stylized fonts or rotated text may not extract correctly

---

## DLP Policy Architecture

### Policy Components

Every DLP policy has these logical components:

```yaml
DLP Policy:
  scope:
    locations: [Exchange, SharePoint, OneDrive, Endpoints, Teams, ...]
    users_groups: [All, specific groups, exclusions for admins]
    
  conditions:
    content_contains:
      - sensitive_info_type: "Credit Card Number"
        min_count: 1
        confidence: High
      - sensitive_info_type: "US SSN"
        min_count: 3
        confidence: Medium
    content_shared: externally  # or: internally, with specific domains
    
  actions:
    user_notification: true    # Show policy tip to user
    alert_admins: true         # Send alert to security team
    block: true                # Prevent the action
    encrypt: false             # Apply encryption instead of blocking
    require_justification: true # Allow override with business reason
    
  severity: high
  mode: enforce  # or: simulate (audit only)
```

### Policy Precedence and Priority

When multiple policies match a single event, the most restrictive action wins:
- Block overrides Encrypt overrides Notify overrides Log
- Policy with higher priority number evaluated first
- First matching policy's actions apply (depends on platform — some are additive)

### Graduated Response Model

```
Confidence 0-40%:   Log only — don't alert the user; review in dashboards
Confidence 40-70%:  Policy tip — show user-facing warning; they can proceed
Confidence 70-85%:  Justify or block — require business justification to override
Confidence 85%+:    Block + alert — prevent action; create security incident
```

### Exception and Override Workflow

**User override (justification)**
- User sees policy tip explaining the restriction
- User can override by entering a business justification
- All overrides logged; high-risk overrides trigger security review
- Overrides should not be permanent — set expiry (24-72 hours)

**Admin exception**
- Security team grants time-limited exception for specific user + action
- Exception logged and audited
- Reviewed quarterly to remove stale exceptions

**Exclusion groups**
- Certain roles legitimately work with sensitive data (legal, HR, finance, IT security)
- Exclude from blocking rules but maintain audit/logging
- Never exclude from logging — principle: "trust but verify"

---

## CASB Integration

Cloud Access Security Broker (CASB) extends DLP coverage to cloud applications.

### CASB Deployment Modes

**API Mode (out-of-band)**
- CASB connects directly to cloud app APIs (Box, Dropbox, Google Drive, Salesforce)
- Scans existing content + new uploads/shares asynchronously
- No impact on user experience
- Can't block in real-time (discovers and remediates after the fact)
- Best for: data discovery in cloud storage, compliance scanning

**Inline Proxy Mode (forward proxy)**
- User traffic routed through CASB proxy
- Inline inspection of uploads, downloads, shares
- Can block in real-time
- Requires endpoint agent or PAC file for off-network users
- SSL inspection required for HTTPS traffic

**Reverse Proxy Mode**
- CASB sits in front of sanctioned SaaS (via IdP redirect)
- User authenticates through CASB → redirected to SaaS
- Inline inspection without endpoint agent
- Session-level controls (download, print, copy restrictions)
- Best for: unmanaged devices, BYOD scenarios

### CASB DLP Capabilities

- **Shadow IT discovery** — Identify unsanctioned cloud apps (block, coach, or allow)
- **Data-at-rest scanning** — Scan cloud storage for existing sensitive data
- **Inline DLP** — Block uploads of sensitive content to personal/unsanctioned apps
- **Collaboration control** — Prevent external sharing of sensitive cloud files
- **DRM integration** — Apply rights management to cloud-stored documents

---

## DLP Architecture Patterns

### Pattern 1: Unified DLP (Single Vendor)

Pros: Single policy engine, unified console, no policy gaps  
Cons: Vendor lock-in, may not be best-in-class for each channel  
Best for: Organizations heavily committed to one vendor ecosystem (Microsoft 365 → Purview)

### Pattern 2: Best-of-Breed (Multi-Vendor)

Pros: Best capability per channel  
Cons: Policy consistency challenges, separate consoles, integration complexity  
Best for: Large enterprises with diverse infrastructure and dedicated DLP team

### Pattern 3: SIEM-Integrated DLP

```
DLP Platforms → Alert/Event Streams → SIEM (Splunk/Sentinel/QRadar)
                                    → Correlation with other signals
                                    → SOAR playbooks for response
                                    → Unified incident management
```
Best for: Mature security operations centers; correlating DLP events with identity and endpoint signals

### Pattern 4: Zero Trust DLP

Data access granted based on:
- Identity (who is the user, is this a high-risk session?)
- Device posture (managed device? compliance status?)
- Data sensitivity (classification label, content inspection result)
- Context (location, time, behavior anomaly score)

DLP enforcement becomes conditional rather than absolute — clean device + normal behavior + known user = less restrictive; unknown device + anomalous behavior + sensitive data = maximum restriction.

---

## DLP Maturity Model

| Level | Characteristics |
|---|---|
| 1 — Reactive | No DLP; incidents discovered after-the-fact via breach notification |
| 2 — Basic | Email DLP only; basic regex for credit cards/SSN; audit mode |
| 3 — Defined | Multi-channel (endpoint + email + web); enforced policies; formal classification |
| 4 — Managed | EDM fingerprinting; trainable classifiers; CASB integration; regular tuning |
| 5 — Optimized | Behavioral analytics; risk-adaptive enforcement; AI/ML classification; Zero Trust DLP; automated response |

Target maturity level based on regulatory requirements and risk appetite:
- PCI DSS / HIPAA: Minimum Level 3; recommended Level 4
- General enterprise: Level 3 provides significant risk reduction
- High-value targets (defense, finance): Level 4-5
