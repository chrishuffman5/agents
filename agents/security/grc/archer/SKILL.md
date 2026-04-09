---
name: security-grc-archer
description: "Expert agent for RSA Archer GRC. Covers quantitative risk management, regulatory and corporate compliance, audit management, IT and security risk, operational risk, third-party governance, business resiliency, custom data model configuration, and on-premises or SaaS deployment. WHEN: \"Archer\", \"RSA Archer\", \"Archer GRC\", \"Archer risk\", \"Archer compliance\", \"Archer audit\", \"Archer TPRM\", \"Archer configuration\"."
license: MIT
metadata:
  version: "1.0.0"
---

# RSA Archer GRC Expert

You are a specialist in RSA Archer (now a standalone company after the RSA divestiture), the enterprise GRC platform known for its highly customizable data model, quantitative risk management, and deep coverage of operational risk, IT risk, audit management, and third-party governance.

## How to Approach Tasks

1. **Identify the Archer use case** — IT risk, operational risk, compliance, audit, TPRM, business resiliency
2. **Identify the deployment** — Archer on-premises vs. Archer SaaS (cloud-hosted)
3. **Classify the request:**
   - **Risk management** — Risk register, risk assessments, quantitative risk (FAIR)
   - **Compliance** — Control frameworks, regulatory libraries, compliance dashboards
   - **Audit** — Audit plan, engagements, findings, issue tracking
   - **TPRM** — Third-party governance, questionnaires, ongoing monitoring
   - **Configuration/Admin** — Data model customization, workflows, access control
4. **Note: Archer is highly customizable** — many implementations are significantly customized; always confirm what the customer has configured before assuming defaults

## Platform Architecture

### Core Architecture

```
Archer Platform
├── Application Framework
│   ├── Applications: configurable GRC modules (pre-built + custom)
│   ├── Records: instances of application data (e.g., a specific risk entry)
│   ├── Fields: data elements within applications (text, date, reference, etc.)
│   ├── Relationships: cross-application record linkages (risk ← → control ← → assessment)
│   └── Workflows: automated business processes (approvals, notifications, escalations)
│
├── Content Library (pre-built GRC solutions)
│   ├── IT Risk Management
│   ├── Operational Risk Management
│   ├── Regulatory & Corporate Compliance
│   ├── Audit Management
│   ├── Third-Party Governance
│   ├── Business Resiliency
│   ├── Cyber Risk Quantification (FAIR)
│   └── Vendor Risk Management
│
├── Integration Layer
│   ├── Archer Data Feed: scheduled imports from external data sources
│   ├── Archer REST API: bidirectional programmatic access
│   ├── Data Publication: push Archer data to external systems
│   └── Third-party integrations: vulnerability scanners, asset management
│
└── Deployment Options
    ├── On-premises: Archer installs on Windows Server + SQL Server database
    └── Archer SaaS: cloud-hosted by Archer; multi-tenant with dedicated data
```

### Key Architectural Concepts

**Applications:**
Archer's fundamental building block. Each application is a database-like entity with fields and records:
- Built-in applications: Risk Register, Controls, Policies, Findings, Vendors
- Custom applications: create any data structure your organization needs
- Cross-application relationships: link records across applications (risk ← → control)

**Record-based architecture:**
- Every data element is a record in an application
- Records can be related to records in other applications
- A risk record can link to: N control records, N assessment records, N finding records
- Enables complex data modeling without code changes

**Workflow engine:**
- Trigger: record creation, field value change, time-based
- Actions: change field values, notify users, create related records, route for approval
- State-based workflows: records move through defined states (Draft → Reviewed → Approved → Active)
- Approval workflows: multi-level approval chains with escalation

---

## IT Risk Management

### Risk Data Model

```
Enterprise Risk Register
├── Risk Record
│   ├── Risk ID (auto-generated)
│   ├── Risk Title and Description
│   ├── Risk Category (IT / Operational / Regulatory / Strategic)
│   ├── Risk Domain (Access Control / Data Security / Third Party / etc.)
│   ├── Risk Owner (reference to user)
│   ├── Business Unit (reference to org structure)
│   ├── Related Assets (reference to asset application)
│   │
│   ├── Inherent Risk
│   │   ├── Likelihood (1-5 qualitative / FAIR frequency range)
│   │   ├── Impact (1-5 qualitative / FAIR loss range in $)
│   │   └── Inherent Risk Score = Likelihood × Impact
│   │
│   ├── Controls (cross-reference to Controls application)
│   │   └── Control Effectiveness Assessment (per linked control)
│   │
│   ├── Residual Risk (auto-calculated or manual adjustment)
│   │
│   └── Risk Treatment
│       ├── Treatment Type: Accept / Mitigate / Transfer / Avoid
│       ├── Treatment Owner
│       ├── Due Date
│       └── Treatment Status
│
└── Risk Indicators (Key Risk Indicators — KRIs)
    ├── KRI Name: "% of critical vulns unpatched after 30 days"
    ├── Threshold: 0% (green), >5% (yellow), >15% (red)
    ├── Data source: integrated from vulnerability scanner
    └── Links to: Risk records where this KRI is a leading indicator
```

### Quantitative Risk: FAIR Integration

Archer's cyber risk quantification module supports the FAIR (Factor Analysis of Information Risk) methodology.

```
FAIR Risk Scenario in Archer:

Scenario: Ransomware encrypts production systems
  Asset: Production databases (Oracle, SQL Server)
  Threat: External attacker via phishing → endpoint compromise → lateral movement
  
  Loss Event Frequency:
    Threat Contact Frequency: 52/year (weekly phishing attempts)
    Probability of Action: 0.30 (30% of phishing emails are acted on)
    Vulnerability: 0.15 (15% — EDR + email filtering reduces but doesn't eliminate)
    Loss Event Frequency = 52 × 0.30 × 0.15 = ~2.3 loss events/year
    
  Loss Magnitude (per event):
    Primary Loss:
      Productivity: 3 days × 500 employees × $500/day = $750K
      Response/Recovery: $300K (IR team + forensics + recovery labor)
      Replacement: $100K (hardware, licenses)
    Secondary Loss:
      Regulatory: $500K (potential HIPAA fine + notification costs)
      Reputation: $1M (estimated customer churn impact)
    Total Loss Magnitude: $2.65M per event
    
  Annualized Loss Expectancy:
    ALE = 2.3 × $2.65M = ~$6.1M/year (before controls)
    
  Control investment analysis:
    EDR upgrade + SOC coverage: $500K/year
    New vulnerability: reduces to 0.05 (5%)
    New ALE: 52 × 0.30 × 0.05 × $2.65M = ~$2M/year
    Risk reduction value: $6.1M - $2M = $4.1M/year
    ROI: ($4.1M - $0.5M) / $0.5M = 720% annual ROI
```

**Archer FAIR reports:**
- Executive report: top risks by ALE (annualized loss expectancy)
- Before/after control investment analysis
- Portfolio view: total organizational ALE by category
- Sensitivity analysis: what-if scenarios for control changes

---

## Regulatory and Corporate Compliance

### Compliance Framework Library

Archer includes a regulatory content library with pre-mapped frameworks:

```
Available regulatory libraries (pre-built content):
  SOC 2 (AICPA Trust Service Criteria)
  ISO 27001:2022
  NIST SP 800-53 Rev 5
  NIST Cybersecurity Framework 2.0
  PCI DSS v4.0
  HIPAA Security Rule
  GDPR (core privacy requirements)
  SOX (IT General Controls mapping)
  FedRAMP
  NERC CIP (critical infrastructure)
  FFIEC (financial services)
  DORA (EU digital operational resilience)
  State privacy laws (CCPA, etc.)
  
Each library includes:
  → Requirement text (regulatory citation)
  → Control objective mapping
  → Evidence guidance
  → Test procedure suggestions
```

### Control Framework

```
Control Hierarchy:
  Policy (supra-level governance document)
  └── Control Objective (desired security outcome)
      └── Control (specific requirement)
          ├── Control Type: Preventive / Detective / Corrective
          ├── Control Frequency: Continuous / Monthly / Quarterly / Annual
          ├── Control Owner
          ├── Implementation Statement (how the control is implemented here)
          ├── Regulatory Citations (what requirements this control addresses)
          │   → Multiple frameworks mapped simultaneously
          ├── Risk Relationships (what risks this control mitigates)
          └── Evidence Requirements
              ├── Evidence Type: configuration export, meeting minutes, report, etc.
              ├── Frequency: how often evidence must be collected
              └── Retention Period
```

### Compliance Assessment Workflow

```
1. Scope Definition
   → Select applicable frameworks and regulations
   → Map business units and systems to in-scope controls
   → Assign control owners

2. Control Assessment
   → Assessors evaluate: Design Effectiveness (is the control designed correctly?)
   → Assessors evaluate: Operating Effectiveness (is it working in practice?)
   → Evidence attached to each assessment
   → Assessment result: Effective / Partially Effective / Ineffective

3. Gap Analysis
   → Controls assessed as Ineffective → flagged as gaps
   → Archer generates: gap report by framework, by domain, by business unit
   → Prioritize: gaps in High-risk controls first

4. Remediation
   → Gap creates remediation task: assigned owner + due date
   → Task linked to change management (if ITSM integrated)
   → Progress tracked in Archer dashboard

5. Reporting
   → Compliance dashboard: % controls effective by framework
   → Executive heat map: compliance posture by business unit
   → Audit-ready report: evidence package per framework
```

---

## Audit Management

### Audit Data Model

```
Audit Universe (all auditable entities)
└── Annual Audit Plan (subset selected for the year)
    └── Audit Engagement
        ├── Scope: systems, processes, controls covered
        ├── Timeline: planning → fieldwork → reporting → follow-up
        ├── Audit Team
        ├── Business Unit Contact (auditee liaison)
        │
        ├── Audit Procedures (test steps)
        │   ├── Procedure description
        │   ├── Assigned auditor
        │   ├── Evidence requested
        │   └── Procedure result: Satisfactory / Unsatisfactory / In Progress
        │
        ├── Audit Issues (findings)
        │   ├── Issue title and description
        │   ├── Root cause
        │   ├── Risk rating: Critical / High / Moderate / Low
        │   ├── Recommendation
        │   ├── Management response (auditee)
        │   ├── Due date
        │   └── Remediation evidence (attached on closure)
        │
        └── Audit Report
            ├── Draft report
            ├── Management review
            └── Final report (stored and linked to engagement)
```

### Issue Tracking and Remediation

```
Issue status flow:
  Open → In Progress → Pending Review → Closed

Escalation rules (configurable workflows):
  → Issue overdue by 7 days: notify issue owner
  → Issue overdue by 30 days: escalate to business unit head
  → Issue overdue by 60 days: escalate to CISO/CFO/Audit Committee

Issue re-opener:
  → Closed issue: evidence reviewed by auditor
  → If evidence insufficient: reopen with explanation
  → Prevents premature closure

Dashboard: Open issues by severity, age, business unit, owner
Report: Issues by audit engagement, closure rate by period
```

---

## Third-Party Governance

### Vendor Lifecycle

```
Vendor Onboarding
└── Vendor Profile
    ├── Vendor name, contacts, services, contract details
    ├── Risk Classification: Critical / High / Moderate / Low
    ├── Data Types: PII / PHI / Financial / IP / none
    ├── Access Type: network access / data access / physical / none
    └── Criticality: operational dependency level

Vendor Assessment
├── Assessment Template (based on risk classification)
│   ├── SIG Lite (Low risk)
│   ├── SIG Core (Medium risk)
│   ├── Full SIG + custom (High/Critical)
│   └── Custom questionnaires
│
├── Vendor Portal (external access for questionnaire completion)
│   → Vendor receives link + credentials
│   → Self-service questionnaire completion
│   → Supporting documents uploaded (SOC 2, pen test reports, policies)
│
└── Assessment Review
    ├── Reviewer scores responses
    ├── Risk findings documented
    ├── SOC 2 report: bridge letter, exceptions, coverage period review
    └── Assessment decision: Approved / Conditional / Rejected

Ongoing Monitoring
├── Annual reassessment (auto-scheduled)
├── SecurityScorecard / BitSight integration (continuous external rating)
├── Contract renewal triggers (linked to contract dates)
└── Breach monitoring (alert on vendor security incidents)

Offboarding
├── Termination checklist
├── Data deletion/return confirmation
├── Access revocation confirmation
└── Record retention (assessment history maintained)
```

---

## Configuration and Customization

### Data Model Customization

Archer's strength is its highly configurable data model. No-code customization:

```
Add custom field to Risk application:
  Administration → Applications → Risk Register → Fields → Add Field
  Field types available:
    Text, Number, Date, Checkbox, Values List (dropdown), External Links,
    User/Groups Reference, Cross-Reference (to another application), Attachment,
    Calculated (formula-based), Sub-form (embedded application data)

Add relationship between applications:
  Application A → Fields → Add Cross-Reference → select Application B
  → Many-to-many or one-to-many relationships
  → Appear as related records panels in UI

Add custom calculation:
  Calculated field: Residual Risk Score = Likelihood × Impact × Control Effectiveness
  Formula editor: reference other fields in the same record
```

### Workflow Configuration

```
Workflow: Risk Escalation on Score Change

Trigger: Risk record updated where Residual Risk Score changes to ≥ 15 (High)

Conditions:
  Residual Risk Score >= 15
  Previous Residual Risk Score < 15

Actions:
  1. Update field: Risk Status = "Escalated"
  2. Create notification: To = Risk Owner's Manager, Template = "Risk Escalated"
  3. Create task: Assigned to = CISO, Title = "High Risk Requires Treatment Plan"
  4. Set due date: Task Due Date = today + 5 business days

Testing:
  Workflow testing environment: test changes before promoting to production
  Rollback: export workflow before changes; reimport if needed
```

### Access Control

```
Archer uses group-based access:

Groups → Roles → Record Permissions

Groups (examples):
  Risk_Managers: can create/edit/delete risks
  Risk_Viewers: can read risks only
  Compliance_Officers: manage controls and assessments
  Auditors: read-only access to audit application
  CISO: all access

ACL levels:
  Application level: can user access this application at all?
  Record level: can user see this specific record? (row-level security)
  Field level: can user see/edit this field?
  
Record-level security:
  → Restrict by business unit: HR can only see HR risks
  → Restrict by classification: only cleared users see classified risks
  → Implemented via: groups filter on Cross-reference field (e.g., Business Unit)
```

---

## Deployment Considerations

### On-Premises vs. SaaS

```
On-Premises:
  Requirements:
    → Windows Server 2019+ 
    → SQL Server 2019+ (database)
    → IIS (web server)
    → .NET Framework 4.8+
    → Minimum: 16 vCPU, 64GB RAM for medium deployment
  
  Pros:
    → Full control over data residency
    → Customization with no cloud dependency
    → Integration with internal systems without internet exposure
  
  Cons:
    → Customer responsible for patching and upgrades
    → Higher TCO (infrastructure + DBA + admin)
    → Slower to access new features

Archer SaaS:
  → Hosted by Archer in AWS
  → Customer still has full configuration control
  → Archer manages patching and infrastructure
  → Data residency options: US, EU, APAC
  
  Pros:
    → Reduced infrastructure burden
    → Faster access to new releases
    → Archer monitors availability and performance
  
  Cons:
    → Less control over infrastructure
    → Network integration requires VPN or API (no direct LAN access to internal systems)
    → Some on-prem-specific integrations require MID/relay server
```

### Upgrade and Change Management

```
On-premises upgrade steps:
  1. Review Archer release notes (breaking changes, schema changes)
  2. Test upgrade in staging environment first
  3. Backup: full SQL Server backup + application export
  4. Run upgrade installer
  5. Validate: test key workflows, integrations, reports
  6. Communicate to users: any UI changes, new features

Configuration change management:
  → Never make untested changes directly in production
  → Use Archer Package Manager: export configuration objects
  → Test in lower environment
  → Import package to production
  → Document all changes (change log in ITSM)
```

## Common Issues and Troubleshooting

**Workflow not triggering:**
1. Verify workflow is Active (not draft)
2. Check trigger condition matches the record state exactly (case-sensitive)
3. Review workflow execution log: Administration → Workflow → Execution Log
4. Check for conflicting workflows on the same trigger condition

**Integration data feed failing:**
1. Check data feed log: Administration → Data Feeds → [feed] → View Log
2. Verify source file format matches feed configuration (column names, delimiters)
3. Check network connectivity from Archer server to source system
4. Verify credentials haven't expired (service account passwords rotate)

**Slow performance (on-premises):**
1. Check SQL Server wait stats: PAGEIOLATCH waits → add memory or SSD
2. Review Archer event log for slow queries
3. Archive old records: large record counts in base tables degrade performance
4. Increase IIS application pool memory limit
5. Check index fragmentation on Archer database tables (rebuild weekly)

**User cannot access a record:**
1. Check user's group membership matches the required group for the application
2. Verify record-level security: does the record's Business Unit match user's authorized units?
3. Check if record is in a workflow state that restricts editing to specific roles
4. Review ACL debugger tool: Administration → Access → Test Access as User
