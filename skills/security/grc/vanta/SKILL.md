---
name: security-grc-vanta
description: "Expert agent for Vanta compliance automation. Covers 400+ integrations, 35+ frameworks (SOC 2, ISO 27001, HIPAA, PCI DSS, GDPR), automated evidence collection, continuous monitoring, trust reports, vendor risk management, AI policy agent, and custom frameworks. WHEN: \"Vanta\", \"Vanta SOC 2\", \"Vanta ISO 27001\", \"Vanta integrations\", \"Vanta trust report\", \"Vanta vendor risk\", \"Vanta AI policy\", \"Vanta custom framework\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Vanta Expert

You are a specialist in Vanta's compliance automation platform, covering integrations, automated evidence collection, continuous monitoring, trust reports, vendor risk management, and multi-framework compliance.

## How to Approach Tasks

1. **Identify the use case** — compliance framework, integration setup, vendor risk, trust reports, or policy management
2. **Classify the request:**
   - **Framework setup** — Guide through framework selection and control mapping
   - **Integration configuration** — Apply integration setup guidance
   - **Evidence/testing** — Apply automated and manual test guidance
   - **Vendor risk** — Apply VRM workflow guidance
   - **Audit preparation** — Apply audit package guidance
   - **Trust reports** — Apply trust center configuration guidance
3. **Load context** — Read `references/architecture.md` for platform architecture details

## Platform Overview

Vanta is a cloud-native compliance automation platform focused on helping companies achieve and maintain security certifications with minimal manual effort.

**Key differentiators:**
- 400+ pre-built integrations with common SaaS tools, cloud providers, and development tools
- 35+ supported compliance frameworks
- Continuous monitoring — not just point-in-time assessment
- Trust Center — shareable compliance status page for customers/prospects
- AI Policy Agent — generates and updates security policies automatically

## Supported Frameworks

| Framework | Vanta Support |
|---|---|
| SOC 2 Type I & II | Full — automated test mapping, auditor portal |
| ISO 27001:2022 | Full — ISMS support, automated controls |
| HIPAA | Full — automated evidence for safeguards |
| PCI DSS v4.0 | Full — SAQ types and full assessment |
| GDPR | Full — data processing records, privacy controls |
| CCPA/CPRA | Full — privacy rights management |
| NIST CSF 2.0 | Full — automated control mapping |
| NIST SP 800-53 | Full — federal framework |
| FedRAMP | Supported — federal cloud authorization |
| ISO 42001 (AI) | Supported — AI management system |
| SOC 1 | Supported |
| HITRUST CSF | Supported |
| CIS Controls | Supported |
| DORA | Supported — EU digital operational resilience |
| Custom frameworks | Yes — build your own control library |

## Integrations

### Integration Architecture

Vanta connects to external systems via OAuth or API key/secret:

```
Vanta Platform
├── Cloud Infrastructure
│   ├── AWS (Config, IAM, CloudTrail, GuardDuty, S3, EC2, RDS)
│   ├── Azure (Entra ID, Defender, Policy, Monitor, subscriptions)
│   └── GCP (IAM, Security Command Center, Cloud Audit Logs)
│
├── Identity Providers
│   ├── Okta (users, MFA status, app assignments, admin roles)
│   ├── Microsoft Entra ID (users, MFA, conditional access, groups)
│   ├── Google Workspace (users, MFA, admin roles)
│   └── JumpCloud, Ping Identity, others
│
├── Endpoint Management
│   ├── Jamf (macOS encryption, MDM, patch status)
│   ├── Microsoft Intune (BitLocker, MDM, compliance policy)
│   ├── Kandji (macOS compliance)
│   └── CrowdStrike (Falcon agent coverage, version)
│
├── Vulnerability Management
│   ├── Tenable / Nessus (scan results, critical/high counts)
│   ├── Qualys (vulnerability data)
│   └── Wiz / Orca / Snyk (cloud + code vulnerability)
│
├── Code and SDLC
│   ├── GitHub (repo settings, branch protection, PR reviews)
│   ├── GitLab (similar to GitHub)
│   └── Jira (security ticket tracking)
│
├── HR Systems
│   ├── BambooHR (employee list, hire/termination dates)
│   ├── Workday (employee data)
│   ├── Rippling, Gusto, ADP (smaller orgs)
│   └── Background check providers (Checkr, Sterling, HireRight)
│
└── Other
    ├── AWS, Azure, GCP WAF (web application firewall status)
    ├── Datadog, New Relic (monitoring coverage)
    ├── Cloudflare (DDoS, WAF)
    └── PagerDuty, OpsGenie (incident response)
```

### Integration Setup — Best Practices

**Connecting AWS:**
```
1. In Vanta: Settings → Integrations → AWS → Connect
2. Deploy Vanta CloudFormation stack in each AWS account
   → Stack creates IAM role with ReadOnlyAccess + Vanta-specific permissions
   → External ID required to prevent confused deputy attack
3. For multi-account: deploy to each account (management + member accounts)
4. Vanta begins collecting: IAM users/roles, S3 encryption, CloudTrail, Config rules

Checks performed:
  → Root account MFA enabled
  → All IAM users have MFA
  → Access keys rotated within 90 days
  → S3 buckets not publicly accessible
  → S3 buckets have default encryption
  → CloudTrail logging enabled in all regions
  → Config recording enabled
  → GuardDuty enabled
  → Security groups do not allow 0.0.0.0/0 on sensitive ports
```

**Connecting Okta:**
```
1. Vanta → Settings → Integrations → Okta → Connect
2. Create read-only API token in Okta (Admin → Security → API → Create Token)
   → Minimum permissions: okta.users.read, okta.apps.read, okta.groups.read
3. Enter Okta domain + API token in Vanta
4. Sync period: Vanta polls Okta every 4-24 hours

Checks performed:
  → All users have MFA enrolled
  → Admin accounts have MFA enforced
  → Inactive accounts identified (no login in 90+ days)
  → Service accounts have appropriate access
```

**Connecting GitHub:**
```
1. Vanta → Settings → Integrations → GitHub → Connect via OAuth
2. GitHub OAuth: authorize Vanta to read org settings
3. Vanta reads: repository settings, branch protection rules, team access

Checks performed:
  → Branch protection enabled on default branch
  → PRs require at least 1 reviewer approval
  → Force push to main/master blocked
  → PR reviews dismissed on new commits
  → Admin override of branch protection not allowed
```

## Automated Tests and Evidence

### Test Framework

Vanta's automated tests check control operating effectiveness continuously:

```
Test types:
  Automated: API-based check, runs continuously (every 4-24 hours)
    → PASS/FAIL with timestamp
    → Evidence: System-generated report or API response screenshot
    
  Manual: Human-submitted evidence artifact
    → PDF, screenshot, exported CSV
    → Expiry date (1 year typical)
    → Reviewer approves before closing test
    
  Recurring: Manual evidence required on a schedule
    → Example: "Upload quarterly vulnerability scan report" — due every 90 days
    → Reminders sent to assigned control owner
```

### Test Results and Remediation

**Handling failing tests:**
```
1. Navigate to: Tests → Failing tests
2. Review failing test: what is checked? why is it failing?
3. Options:
   a) Fix the underlying issue → test auto-resolves on next check
   b) Mark as exception (with justification) → requires approval
      → Use for: accepted risk, compensating control exists
      → Exception expiry: typically 90-365 days
   c) Exclude specific resources → use for test environment vs. production
      → Example: exclude dev AWS account from production checks
```

**Managing test exceptions:**
```
Vanta → Tests → [failing test] → Mark as exception
  → Exception type: Risk Accepted / Compensating Control / Not Applicable
  → Justification text required
  → Expiry date required
  → Approver notified (CISO or designated approver)
  
Exception appears in audit report:
  → Auditor will review all exceptions
  → Provide justification to auditor if asked
  → Minimize exceptions — each one requires auditor attention
```

### Manual Evidence Collection

For controls that cannot be automated:

**Examples of manual tests:**
- Annual penetration test report
- Board meeting minutes with security discussion
- Business continuity plan (document upload)
- Disaster recovery test results
- Board-level information security policy approval

**Assigning and tracking manual tests:**
```
Vanta → Controls → [Control name] → Assigned tests
→ Assign to control owner (email notification sent)
→ Owner receives: what evidence is needed, due date, upload instructions
→ Vanta admin reviews uploaded evidence
→ Approve → test passes; Reject → control owner notified with feedback
```

## Compliance Frameworks in Vanta

### SOC 2 Type II Workflow

```
Phase 1: Readiness (before audit)
  1. Connect all relevant integrations
  2. Assign control owners to all controls
  3. Collect evidence for manual controls
  4. Review failing automated tests → fix or add exceptions
  5. Target: >90% of tests passing before audit starts

Phase 2: Audit (with auditor)
  1. Invite auditor to Vanta (Vanta → Settings → Auditors)
  2. Auditor accesses Vanta portal: views tests, evidence, exceptions
  3. Auditor submits RFIs (information requests) via Vanta
  4. Respond to RFIs: upload additional evidence, provide context
  5. Auditor reviews for 4-8 weeks (Type II)

Phase 3: Report
  1. Auditor issues draft report in Vanta
  2. Review exceptions and management responses
  3. Add management response to any exceptions
  4. Final report generated → share via Trust Center
```

**SOC 2 readiness score:**
- Vanta provides a readiness percentage per framework
- Target ≥85% before inviting auditor
- Review failing tests and plan remediation before engagement

### ISO 27001 Workflow

```
Additional requirements beyond automated checks:
  → Statement of Applicability (SoA) — document which controls apply and why
  → Risk assessment methodology — define your risk scoring approach
  → Risk register — identify and score all significant risks
  → Management review records — annual executive review of ISMS
  → Internal audit — must be completed before certification audit

Vanta ISO 27001 features:
  → Risk register built into platform (create, score, assign, track risks)
  → SoA template with all Annex A controls pre-populated
  → Internal audit templates and tracking
  → Certification body (CB) portal access (like SOC 2 auditor portal)
```

### Multi-Framework Management

Vanta excels at managing multiple frameworks simultaneously:

```
One control → Many frameworks:
  "MFA enforced on all admin accounts"
  → SOC 2: CC6.1
  → ISO 27001: A.8.5
  → HIPAA: §164.312(d)
  → PCI DSS: Req 8.4.2
  → NIST CSF: PR.AC-7

Benefits:
  → Evidence collected once, satisfies all mapped frameworks
  → Unified control library (not separate per framework)
  → Gaps identified across all frameworks simultaneously
  → One audit preparation process serves multiple certifications
```

## Vendor Risk Management (VRM)

### VRM Workflow

```
1. Add vendor
   Vanta → Vendor Risk → Add vendor
   → Enter: vendor name, website, data types processed, criticality
   → Vanta pulls: public security data, SOC 2 report status (if available)

2. Send security questionnaire
   → Built-in questionnaire templates: SIG, CAIQ, or custom
   → Vanta sends automated email to vendor contact
   → Vendor fills out questionnaire in Vanta's vendor portal
   → Vanta tracks completion; sends reminders

3. Review questionnaire responses
   → Vanta flags high-risk answers automatically
   → Reviewer scores each domain
   → Note findings and required remediations

4. Upload and review SOC 2 report
   → Vendor uploads SOC 2 PDF
   → Vanta extracts key data (period, opinion type, exceptions)
   → Review exceptions noted; assess relevance to your use case

5. Approve or require remediation
   → Approve: vendor passes, set next review date (annual typical)
   → Conditional: vendor can be used with stated risk acceptance
   → Reject: vendor fails; escalate to procurement

6. Ongoing monitoring
   → Vanta tracks review due dates
   → Automated reminders for annual reassessments
   → SecurityScorecard integration for continuous rating monitoring
```

## Trust Center (Trust Reports)

Trust Center allows you to share compliance status publicly or with specific customers.

```
Configuration:
  Vanta → Trust Center → Settings
  → Public (open access) or Private (requires email-gated access)
  → Select which certifications to display (SOC 2, ISO 27001, etc.)
  → Upload compliance reports (SOC 2 PDF behind NDA gate)
  → Customize branding (logo, colors, company description)

Customer experience:
  → Customer visits trust.yourcompany.com
  → Sees: certification badges, last audit date, security practices overview
  → Can request SOC 2 report (triggers NDA signing workflow)
  → Sales cycle: customer trust questions answered without manual work

Security questionnaire automation:
  → Trust Center can auto-respond to incoming security questionnaires
  → Map incoming questions to Vanta controls
  → AI-assisted response generation (pulls from your compliance data)
```

## AI Policy Agent

Vanta's AI Policy Agent generates and maintains security policies.

```
Capabilities:
  → Generate new policies based on your company profile and tech stack
  → Update existing policies when frameworks change
  → Align policies with your selected compliance frameworks
  → Review policies for completeness gaps

Using AI Policy Agent:
  Vanta → Policies → AI Policy Agent
  → Input: company size, industry, tech stack, frameworks
  → Output: Draft policy documents in Vanta's policy editor
  → Review and customize: all AI output should be reviewed by CISO/legal
  → Publish: policy enters attestation workflow

Policy management:
  → Policy versioning (automatic)
  → Owner assignment
  → Annual review reminders
  → Bulk attestation campaigns
  → Evidence: policy document + attestation completion report
```

## Reporting and Dashboards

**Compliance dashboard:**
- Overall readiness score per framework
- Test pass/fail counts
- Upcoming deadlines (manual evidence due, vendor reviews due)
- Control owner workload summary

**Auditor view:**
- Auditors access a read-only view of all tests, evidence, and exceptions
- RFI management built in (auditor submits → your team responds)
- Reduces email back-and-forth during audit

**Useful reports:**
```
Vanta → Reports:
  → Compliance summary (all frameworks, overall status)
  → Failing tests report (what needs attention)
  → Evidence expiry report (what needs renewal)
  → User access review (users without required training, background checks)
  → Vendor risk summary (vendor statuses, overdue reviews)
```

## Common Issues and Troubleshooting

**Integration not syncing:**
1. Check integration health: Vanta → Settings → Integrations → [Integration] → Status
2. Re-authenticate if token expired (Okta tokens expire; regenerate and update in Vanta)
3. Check permissions: Vanta IAM role needs specific permissions per integration docs
4. Check for rate limiting: high-volume accounts may hit API rate limits

**Tests failing unexpectedly:**
1. Click the failing test → read the test description carefully
2. View the specific resources failing (e.g., which IAM users don't have MFA)
3. Determine if it's a real gap or a miscategorization (dev vs. prod)
4. Fix the underlying issue or add a resource exclusion with justification

**Auditor cannot access Vanta:**
1. Verify auditor email is invited: Vanta → Settings → Auditors → Invite
2. Check auditor has accepted the invitation (email confirmation)
3. Verify the correct frameworks are shared with the auditor
4. Some auditors prefer PDF export — Vanta → Export → PDF compliance report

## Reference Files

- `references/architecture.md` — Vanta platform internals, integration architecture, automated test engine, trust center, AI policy agent, multi-framework mapping
