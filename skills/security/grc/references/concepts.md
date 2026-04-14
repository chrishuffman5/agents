# GRC Concepts Reference

Deep reference for Governance, Risk, and Compliance fundamentals. Load this when answering architecture, design, or platform-neutral GRC questions.

---

## Risk Management

### Risk Methodology

**Risk = Likelihood × Impact**

Standard qualitative scale (5×5 matrix):

```
Likelihood:
  1 — Rare:       <5% probability in next 12 months
  2 — Unlikely:   5-20% probability
  3 — Possible:   20-50% probability
  4 — Likely:     50-75% probability
  5 — Almost:     >75% probability

Impact:
  1 — Negligible:    Minimal operational or financial impact (<$10K)
  2 — Minor:         Limited impact, resolved without escalation (<$100K)
  3 — Moderate:      Significant disruption, manageable (<$1M)
  4 — Major:         Significant financial/reputational impact (<$10M)
  5 — Catastrophic:  Existential or regulatory/legal consequences (>$10M)

Risk Score Matrix:
        1       2       3       4       5      (Impact)
  5  [  5  ] [ 10  ] [ 15  ] [ 20  ] [ 25  ]
  4  [  4  ] [  8  ] [ 12  ] [ 16  ] [ 20  ]
  3  [  3  ] [  6  ] [  9  ] [ 12  ] [ 15  ]
  2  [  2  ] [  4  ] [  6  ] [  8  ] [ 10  ]
  1  [  1  ] [  2  ] [  3  ] [  4  ] [  5  ]
(Likelihood)

Score ranges:
  1-4:  Low      → Accept or monitor
  5-9:  Medium   → Mitigate or accept with compensating controls
  10-19: High    → Mitigate; requires treatment plan
  20-25: Critical → Immediate remediation; escalate to executive
```

### Risk Treatment Options

**Mitigate** — Implement controls to reduce likelihood or impact
- Lower likelihood: MFA, vulnerability patching, security training
- Lower impact: backups, incident response plan, cyber insurance
- Most common treatment for technical risks

**Accept** — Acknowledge the risk and consciously choose not to address it
- Appropriate when: cost of mitigation > expected loss; residual risk is low
- Must be formally approved by risk owner and documented
- Time-bounded: reassess annually; don't let accepted risks become forgotten risks

**Transfer** — Shift financial consequence to a third party
- Cyber insurance: covers breach response costs, regulatory fines, litigation
- Contractual transfer: vendor assumes liability for their systems
- Doesn't eliminate the risk — just shares financial consequence

**Avoid** — Eliminate the activity or asset that creates the risk
- Stop using a vulnerable system; don't enter a particular market
- Most complete but often not feasible for core business functions

### Quantitative Risk Assessment (FAIR Methodology)

Factor Analysis of Information Risk (FAIR) — industry standard for quantitative risk:

```
FAIR Risk Model:
  Risk = Frequency of Loss Events × Magnitude of Loss

Loss Event Frequency (LEF):
  = Threat Event Frequency × Vulnerability
  
  Threat Event Frequency: How often does a threat actor attempt to exploit this?
    → Threat intelligence data, industry incident rates
  
  Vulnerability: Given an attempt, what is the probability of success?
    → Control effectiveness, patch levels, configuration state

Loss Magnitude:
  = Primary Loss + Secondary Loss
  
  Primary Loss (direct costs):
    → Productivity loss (downtime × hourly cost)
    → Response costs (IR team, forensics, notification)
    → Replacement costs (rebuild systems, restore data)
  
  Secondary Loss (downstream costs):
    → Regulatory fines and penalties
    → Legal liability
    → Competitive advantage loss (trade secret theft)
    → Reputational damage (customer churn × LTV)
```

**Example FAIR analysis — ransomware on production:**
```
Threat frequency: ~3 attempts/year (phishing + RDP brute force)
Vulnerability: 35% (MFA deployed, but EDR gap on some systems)
LEF: 3 × 0.35 = ~1 event/year probability

Primary loss: $500K (IR costs $150K + downtime 3 days × $100K/day + recovery $50K)
Secondary loss: $300K (regulatory notification, potential fine, customer notification)
Total loss magnitude: $800K

Annualized Loss Expectancy (ALE): 1 × $800K = $800K/year

Control investment decision:
  → EDR on remaining systems: $50K/year
  → Reduces vulnerability from 35% → 10%
  → New ALE: 1 × 0.10 × $800K = $80K/year
  → Return on control: ($800K - $80K) - $50K = $670K/year
  → Clear economic case for investment
```

---

## Control Frameworks Deep Reference

### SOC 2 Trust Service Criteria

**Trust Service Criteria (TSC) mapping:**

CC6 — Logical and Physical Access Controls (most commonly tested):

```
CC6.1 — Logical access security software, infrastructure, and architectures are implemented
  Required evidence:
    → MFA enrollment report (100% on production systems)
    → Access control policy document
    → Network segmentation diagram
    → Firewall configuration review
    
CC6.2 — Prior to issuing credentials and granting access, users are registered and authorized
  Required evidence:
    → Access provisioning tickets / workflow screenshots
    → HR new hire → IT provisioning process documentation
    → Access request approval records (manager approval)

CC6.3 — Access is removed when no longer required
  Required evidence:
    → HR offboarding → IT deprovisioning process
    → Offboarding checklist with access revocation steps
    → Automated deprovisioning evidence (SCIM provisioning logs)
    → Periodic access reviews showing removal of inappropriate access

CC6.6 — Logical access security measures prevent unauthorized access from outside the system
  Required evidence:
    → Penetration test report (annual)
    → Vulnerability scan results
    → WAF/DDoS protection evidence
    → VPN/ZTNA for remote access
```

**SOC 2 Type I vs. Type II:**
```
Type I: Point-in-time assessment
  → Controls are suitably designed (as of a specific date)
  → Typically used for new compliance programs
  → Less trusted by sophisticated buyers
  → Can be completed in 2-3 months

Type II: Period assessment (typically 6-12 months)
  → Controls are suitably designed AND operating effectively over the period
  → Industry standard for B2B SaaS
  → First Type II is hardest — requires 6-12 months of documented evidence
  → Annual renewal typically 6-12 months
```

### ISO 27001:2022 Control Structure

ISO 27001:2022 reorganized controls into 4 themes and 93 controls:

**Theme: Organizational (37 controls)**
- Policies, roles, threat intelligence, information security in project management
- Supplier security, incident management, business continuity, legal compliance

**Theme: People (8 controls)**
- Screening, terms of employment, awareness, training, disciplinary process
- Remote working, reporting events

**Theme: Physical (14 controls)**
- Physical security perimeters, physical entry, securing offices
- Clear desk/screen, physical media disposal, monitoring activities

**Theme: Technological (34 controls)**
- User endpoint devices, privileged access, access control, authentication
- Encryption, secure development, configuration management, backup
- Logging, monitoring, network filtering, web filtering, SIEM

**New controls in ISO 27001:2022 (not in 2013):**
- Threat intelligence (5.7)
- Information security for use of cloud services (5.23)
- ICT readiness for business continuity (5.30)
- Physical security monitoring (7.4)
- Configuration management (8.9)
- Information deletion (8.10)
- Data masking (8.11)
- Data leakage prevention (8.12)
- Monitoring activities (8.16)
- Web filtering (8.23)
- Secure coding (8.28)

### PCI DSS v4.0 Key Requirements

```
Req 1-2: Network Security Controls
  → Firewalls, network segmentation, secure system configurations
  → No default vendor passwords

Req 3-4: Protect Account Data
  → Cardholder data storage minimization
  → Encryption of stored PAN
  → Encryption in transit

Req 5-6: Vulnerability Management
  → Anti-malware on all systems
  → Develop and maintain secure systems (secure coding, patching)

Req 7-8: Access Control
  → Restrict access by business need-to-know
  → Identify and authenticate access (MFA required everywhere in v4.0)

Req 9: Physical Security
  → Restrict physical access to cardholder data

Req 10-11: Logging and Monitoring
  → Log all access to system components
  → Test security systems and processes (quarterly scans, annual pen test)

Req 12: Information Security Policies
  → Security policy, risk assessment, awareness training, vendor management
```

---

## Compliance Automation Architecture

### Integration Patterns

**Pull model (most common):**
```
GRC Platform ─── API call ──► Cloud Provider/SaaS
                              Returns: current configuration state
                              GRC evaluates: PASS or FAIL against control requirement
                              Updates: evidence artifact + control status
```

**Push model (webhook/event-driven):**
```
Cloud Provider/SaaS ─── webhook ──► GRC Platform
Event: "S3 bucket ACL changed to public"
GRC Platform: Evaluates → control FAIL → create alert → notify owner
```

**Agent model (endpoint/on-prem):**
```
Agent on endpoint/server ──► GRC Platform
Reports: encryption status, patch level, MDM enrollment, AV status
GRC Platform: Aggregates → calculates % compliance → flags gaps
```

### Common Integration Categories

**Cloud infrastructure:**
```
AWS:
  Services polled: IAM, Config, GuardDuty, SecurityHub, CloudTrail, S3, EC2
  Key checks: S3 encryption, root MFA, Config rules enabled, CloudTrail logging
  Auth: IAM role with ReadOnlyAccess (least privilege — no write permissions to GRC tool)

Azure:
  Services polled: Microsoft Entra ID, Defender for Cloud, Policy, Monitor
  Key checks: MFA status, Defender coverage, Policy compliance, RBAC assignments
  Auth: Service principal with Reader role + specific API permissions

GCP:
  Services polled: IAM, Security Command Center, Cloud Asset Inventory, Logging
  Key checks: Service account key rotation, org policy constraints, logging enabled
  Auth: Service account with Viewer role
```

**Identity:**
```
Okta:
  Checks: MFA enrollment (per user, overall %), inactive accounts, admin MFA
  Evidence: MFA enrollment report, user list with MFA status
  API: Okta API read access (SSWS token or OAuth)

Microsoft Entra ID:
  Checks: MFA status, conditional access policies, privileged role assignments
  Evidence: Sign-in logs, user list with MFA status, CA policy export
  API: Microsoft Graph API (User.Read.All, Policy.Read.All)
```

**Endpoint:**
```
Jamf:
  Checks: FileVault encryption, MDM enrollment, macOS version, app inventory
  Evidence: Device compliance report, encryption status per device

Intune:
  Checks: BitLocker encryption, MDM enrollment, compliance policy status, patch level
  Evidence: Device compliance report, per-device status

CrowdStrike:
  Checks: Falcon agent deployment coverage, sensor version, containment capability
  Evidence: Coverage report, unprotected endpoint list
```

---

## Audit Management

### Audit Lifecycle

```
1. Audit Planning
   → Define scope (which systems, which period, which frameworks)
   → Select auditor (external CPA firm for SOC 2, accredited CB for ISO 27001)
   → Review engagement letter and audit plan
   → Internal readiness assessment (gap analysis before audit starts)

2. Evidence Collection (ongoing or pre-audit)
   → Assign evidence to control owners
   → Collect and upload evidence artifacts
   → Review for completeness and accuracy
   → Ensure evidence period coverage matches audit period

3. Auditor Fieldwork
   → Auditor submits information requests (RFIs)
   → Provide evidence via GRC platform or secure portal
   → Walkthroughs: auditor interviews control owners
   → Testing: auditor selects samples; you provide population and samples

4. Review and Response
   → Auditor issues preliminary findings (Potential Exceptions)
   → Respond to each finding: accept or provide clarifying evidence
   → Remediate actual exceptions before report finalized if possible

5. Report Issuance
   → Draft report review (management letter review period)
   → Final report signed
   → Type II report: share with customers via trust center / NDA
   → ISO 27001: Certificate issued by certification body

6. Continuous Monitoring (post-audit)
   → Maintain evidence collection continuously
   → Address any exceptions from prior audit
   → Prepare for next audit cycle
```

### Evidence Quality Standards

```
What makes good evidence:
  Complete: Covers the full audit period (not just a point in time)
  Accurate: Reflects the actual state of controls (no cherry-picking)
  Timely: Generated when control was operating (not retroactively)
  Traceable: Clearly shows what was tested, by whom, when
  Authoritative: Comes from the system of record (not a manual spreadsheet)

Evidence red flags auditors flag:
  → Screenshots with no timestamp
  → Spreadsheets instead of system-generated reports
  → Evidence from outside the audit period
  → Access reviews not signed off by reviewer
  → Training completions without completion timestamps
  → Policies without approval signatures and dates
```

---

## Third-Party Risk Management (TPRM)

### Vendor Classification

```
Critical (Tier 1):
  → Processes or stores most sensitive data (PII, PHI, financial)
  → Material operational dependency (system down = business down)
  → Assessment: Full SIG questionnaire + SOC 2 review + annual onsite/call
  → Monitoring: Continuous security rating monitoring

High (Tier 2):
  → Accesses corporate network or systems
  → Processes business-sensitive data
  → Assessment: Abbreviated questionnaire + SOC 2 review
  → Monitoring: Annual reassessment + security rating alerts

Medium (Tier 3):
  → Limited data access; no sensitive data
  → Non-critical operational dependency
  → Assessment: Self-attestation questionnaire
  → Monitoring: Annual self-assessment renewal

Low (Tier 4):
  → No data access; commodity service
  → Examples: office supplies vendors, building maintenance
  → Assessment: Attestation to security policy acceptance
  → Monitoring: None required
```

### Security Questionnaire Frameworks

**SIG (Standardized Information Gathering):**
- Maintained by Shared Assessments
- SIG Core: ~270 questions across 20 domains
- SIG Lite: ~70 questions — faster review
- Industry standard for financial services, healthcare, enterprise

**CSA CAIQ (Cloud Security Alliance):**
- Focused on cloud service providers
- Maps to CSA Cloud Controls Matrix (CCM)
- Widely used for SaaS vendor assessments
- CAIQ answers self-submitted to CSA STAR registry

**Custom questionnaires:**
- Tailored to your specific risk concerns
- Include: data handling, access controls, incident response, business continuity
- Risk: vendors receiving many custom questionnaires face fatigue — prefer SIG

### Continuous Vendor Monitoring

```
Security rating services (SecurityScorecard, BitSight, Bitsight):
  → Passive external scan of vendor's internet presence
  → Score: 0-100 (or letter grade A-F)
  → Factors: patch frequency, SSL/TLS configuration, DNS health, 
             email security (SPF/DKIM/DMARC), reputation, web application security
  → Alert on score drops > 10 points
  → Not a replacement for questionnaire assessment — a continuous signal layer

Dark web monitoring:
  → Monitor for vendor breach indicators
  → Credential exposure from vendor domains
  → Alert on indicators to prompt accelerated reassessment

SOC 2 bridge letters:
  → When vendor's latest SOC 2 doesn't cover current period
  → Vendor provides signed letter attesting controls unchanged since report
  → Acceptable gap bridge: typically up to 6 months
```

---

## Policy Management

### Policy Hierarchy

```
Tier 1: Executive/Board Policies
  → Information Security Policy (top-level commitment)
  → Acceptable Use Policy
  → Risk Management Policy
  Review: Annual; approved by board or executive committee

Tier 2: Domain Policies (CISO-owned)
  → Access Control Policy
  → Encryption Policy
  → Incident Response Policy
  → Change Management Policy
  → Vendor Management Policy
  → Business Continuity Policy
  Review: Annual; approved by CISO

Tier 3: Standards and Procedures (Technical Team)
  → Password Standards (minimum length, complexity, rotation)
  → Network Security Standards
  → Secure Coding Standards
  → Vulnerability Management Procedures
  Review: Annual or as technology changes; approved by security team lead

Tier 4: Guidelines and Baselines
  → Cloud Security Baseline (AWS, Azure, GCP)
  → Endpoint Security Baseline
  → Application Security Baseline
  Review: As technology changes; technical owner
```

### Policy Attestation

Annual employee attestation is required for SOC 2 (CC2.2) and ISO 27001 (7.3, 7.4):

```
Attestation workflow:
  1. Policy manager sends attestation campaign to all employees
  2. Employee receives email: "Please review and acknowledge the following policies"
  3. Employee clicks link → reads policy → clicks "I acknowledge"
  4. Completion tracked with: employee name, date/time, policy version
  
Compliance thresholds:
  → Target: 100% completion
  → Acceptable for audit: 95%+ (with escalation process for non-completers)
  → Escalation: 2 reminder emails → manager notification → HR escalation
  
Evidence stored:
  → Completion report: employee list, completion date, policy version
  → Download as CSV or PDF for audit evidence
```

---

## GRC Maturity Model

| Level | Characteristics | Typical Tools |
|---|---|---|
| 1 — Ad Hoc | No formal GRC program; compliance is reactive | Spreadsheets, email |
| 2 — Developing | Basic policies exist; manual evidence collection; annual audits | GRC spreadsheets, shared drive |
| 3 — Defined | Formal GRC framework; documented controls; manual but structured | Basic GRC tool or project mgmt |
| 4 — Managed | Automated evidence collection; continuous monitoring; integrated TPRM | Vanta / Drata / Archer |
| 5 — Optimized | Real-time risk dashboard; predictive analytics; zero-friction compliance | Enterprise GRC + SIEM integration |

**Getting from Level 2 to Level 4 (most common journey):**
1. Select compliance framework (SOC 2 Type II most common for SaaS)
2. Deploy GRC automation platform (Vanta, Drata, or similar)
3. Connect cloud infrastructure integrations (AWS, GCP, Azure)
4. Connect identity and endpoint integrations (Okta, Intune/Jamf)
5. Assign control owners for manual controls
6. Run first audit after 6-12 months of evidence collection
7. Address audit findings and mature continuous monitoring
8. Expand to additional frameworks as business requires
