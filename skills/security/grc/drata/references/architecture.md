# Drata Platform Architecture Reference

Deep architecture reference for Drata compliance automation. Load this for "how does it work" questions, integration design, Autopilot configuration, or advanced troubleshooting.

---

## Platform Architecture

```
Drata SaaS Platform (cloud-hosted)
│
├── Integration Pipeline
│   ├── OAuth 2.0 / API key connectors (read access to customer systems)
│   ├── Webhook receivers (push events from integrated systems)
│   ├── Scheduled polling engine (runs integration checks every 4-24 hours)
│   └── Data normalization layer (converts raw API responses to Drata schema)
│
├── Autopilot Engine
│   ├── Automated evidence generator (creates evidence artifacts from integration data)
│   ├── Remediation executor (applies fixes where technically feasible + approved)
│   ├── Remediation queue (pending approval items)
│   └── Audit log (every automated action logged with timestamp)
│
├── Control Testing Engine (1,200+ tests)
│   ├── Test definition library (what to check, how to evaluate, evidence format)
│   ├── Test scheduler (continuous, daily, weekly, monthly, annual)
│   ├── Result aggregator (resource-level results → control-level status)
│   └── Exception management (documented exceptions with expiry tracking)
│
├── Personnel Management Module
│   ├── Employee sync engine (from HR integrations)
│   ├── Onboarding tracker (checklist per employee)
│   ├── Background check orchestration (integration with check providers)
│   ├── Training completion tracker
│   └── Access review engine
│
├── Asset Inventory Module
│   ├── Auto-discovery engine (cloud assets, devices, SaaS apps)
│   ├── Classification engine (applies tags/labels to assets)
│   ├── Compliance status per asset (encryption, MDM, patching)
│   └── Scope management (in-scope vs. out-of-scope per framework)
│
├── Policy Engine
│   ├── Policy editor (WYSIWYG + version control)
│   ├── Approval workflow engine
│   ├── Attestation campaign manager
│   └── Policy → control linker
│
├── Risk Register
│   ├── Risk CRUD with scoring model
│   ├── Risk → control linking (residual risk tracks control effectiveness)
│   ├── Treatment workflow (tasks, owners, due dates)
│   └── Risk review scheduler
│
├── Audit Hub
│   ├── Readiness scoring engine
│   ├── Auditor portal (read-only access scoped to framework)
│   ├── RFI management (auditor requests → team responses)
│   └── Audit package generator (evidence export)
│
└── Trust Center
    ├── Public profile (certifications, security practices)
    ├── NDA-gated content (SOC 2 reports)
    └── Questionnaire automation (AI-assisted response)
```

---

## Integration Pipeline Deep Dive

### Data Collection Architecture

**OAuth-based connectors (cloud providers, SaaS tools):**

```
1. Customer authorizes Drata
   → Drata's OAuth client sends authorization request
   → Customer approves in provider's auth screen
   → Provider issues access token (and refresh token if long-lived)
   → Drata stores tokens encrypted at rest

2. Scheduled collection run (every 4-24 hours, varies by integration):
   Drata scheduler → calls integration collector function
                   → collector calls provider API (paginated)
                   → raw API responses stored in Drata raw data store
                   → normalization function converts to Drata schema
                   → normalized data written to resource store

3. Test evaluation trigger:
   Resource store updated → triggers dependent test re-evaluation
   Test evaluates current state → PASS or FAIL
   Test result written → evidence artifact generated if PASS
```

**IAM-role based connectors (AWS, Azure, GCP):**

```
AWS example:
  Customer deploys CloudFormation stack
  → Creates IAM role: DrataRole
  → Trust policy: arn:aws:iam::DRATA_ACCOUNT_ID:root (Drata's AWS account)
  → External ID: customer-specific UUID (prevents confused deputy)
  → Permissions: ReadOnlyAccess + specific SecurityAudit permissions

Drata collection:
  → STS AssumeRole with external ID → gets temporary credentials
  → Calls AWS APIs with temporary credentials
  → Credentials expire after 1 hour (refreshed per collection cycle)
  → Drata never stores long-lived AWS credentials
```

### Data Model: Resources

```
Each integrated system populates the resource store with typed objects:

AwsIamUser:
  id: "arn:aws:iam::123456789:user/johndoe"
  username: "johndoe"
  has_mfa: false
  access_key_age_days: 47
  last_used: "2025-03-15T14:23:00Z"
  groups: ["Developers", "S3ReadOnly"]
  tags: {}
  account_id: "123456789"
  environment: "production"  # derived from account classification

OktaUser:
  id: "00u1a2b3c4d5e6f7g8h9"
  login: "johndoe@company.com"
  status: "ACTIVE"
  has_mfa: false
  mfa_factors: []
  last_login: "2025-03-20T09:15:00Z"
  groups: ["Engineering", "All-Staff"]
  is_admin: false

DeviceRecord:
  id: "device-abc123"
  name: "Johns-MacBook-Pro"
  assigned_user: "johndoe@company.com"
  platform: "macOS"
  os_version: "14.3"
  encryption_enabled: true
  mdm_enrolled: true
  last_check_in: "2025-03-21T08:00:00Z"
  source: "Jamf"
```

---

## Autopilot Engine

### Remediation Decision Tree

```
Test fails
    │
    ▼
Is auto-remediation available for this test?
    │
    ├── No → Create alert; notify control owner; require manual fix
    │
    └── Yes
           │
           ▼
        Is auto-remediation enabled in Autopilot settings?
           │
           ├── No → Alert only (remediation available but disabled)
           │
           └── Yes
                  │
                  ▼
               Does this remediation require approval?
                  │
                  ├── Yes → Add to approval queue; notify approver
                  │          → Approver clicks Approve → remediation executes
                  │
                  └── No → Execute remediation automatically
                             → Log: what was changed, when, by Autopilot
                             → Notify: configured recipients
                             → Re-run test → should PASS
                             → Auto-generate evidence with remediation context
```

### Remediations Available

```
GitHub:
  Action: Enable branch protection on default branch
  What it does: Creates branch protection rule via GitHub API
    → Requires PR reviews: 1
    → Dismisses stale reviews on new commits
    → Prevents force push to default branch
  Requires approval: Yes (modifies repo settings)
  Permission needed: GitHub OAuth with repo admin scope

AWS:
  Action: Enable CloudTrail in region
  What it does: Creates CloudTrail trail via AWS CloudTrail API
  Requires approval: Yes (creates new resource, may incur cost)
  Permission needed: IAM role with cloudtrail:CreateTrail

  Action: Enable S3 bucket versioning
  What it does: Enables versioning on non-compliant buckets
  Requires approval: Yes
  Permission needed: IAM role with s3:PutBucketVersioning

  Note: Most AWS remediations require approval; few run fully automated
  Note: Drata IAM role needs write permissions for specific remediations
        (default setup uses read-only; write must be explicitly added)
```

### Evidence Generation

```
Automated evidence format:
  For each passing automated test, Drata generates:
  
  Evidence artifact:
    type: "automated_check"
    test_id: "okta-mfa-all-users"
    check_timestamp: "2025-03-21T10:15:23Z"
    result: "PASS"
    resources_checked: 47  # total users checked
    resources_passing: 47  # users with MFA
    resources_failing: 0
    integration: "Okta"
    integration_tenant: "company.okta.com"
    
  Human-readable summary:
    "Drata checked Okta for MFA enrollment on 2025-03-21 at 10:15 UTC.
     All 47 active users have MFA enrolled. 0 users are without MFA."
     
  Attached evidence file:
    CSV export: username, mfa_status, mfa_factor_type, enrollment_date
    
  Audit context:
    → Auditor can see: what was checked, when, by what system
    → Links to: integration configuration, Okta tenant
    → Verifiable: auditor can confirm integration is live and active
```

---

## Personnel Management Architecture

### Employee State Machine

```
Employee states in Drata:

PENDING ONBOARD
  Trigger: HR integration detects hire_date = future date
  Actions: Prepare onboarding checklist; pre-send training invitation
  
ONBOARDING
  Trigger: hire_date reached
  Actions:
    → Send welcome email to employee
    → Initiate background check (if provider connected)
    → Send policy attestation request
    → Notify IT: device enrollment required
  SLA: checklist complete within 30 days of start

ACTIVE
  Trigger: All onboarding items complete (or 30-day grace expires)
  Ongoing checks:
    → Annual training renewal
    → Annual policy re-attestation
    → Quarterly access review participation
    → Device compliance monitoring

OFFBOARDING
  Trigger: HR integration detects termination_date = future or today
  Actions:
    → Alert IT: revoke access immediately (for immediate terminations)
    → Track: access revocation completion across all systems
    → Verify: accounts disabled in Okta, GitHub, AWS, etc.

OFFBOARDED
  Trigger: All access confirmed revoked; post-departure period elapsed
  Retention: employee record retained per policy (typically 7 years)
```

### Access Review Data Flow

```
Access review trigger (Drata initiates):
  Drata → collects current access data from all integrations
        → Okta: list of users + apps
        → GitHub: org members + repo access + team membership
        → AWS: IAM users + role assignments
        
Review assignment:
  Drata → determines reviewer per resource:
        → Use system owner mapping (admin configures which systems → which reviewer)
        → Or: send to manager (pulled from HR integration)
        → Or: send to all admins for systems without owner mapping

Reviewer action:
  Reviewer → Drata employee portal
           → Sees: user name, access level, last login, tenure with company
           → Action: Approve or Revoke (with optional note)
           → Batch actions available for efficiency

Remediation:
  → Revoked access: Drata creates revocation task for IT
  → If Autopilot enabled with write access: Drata directly deactivates in system
  → Completion confirmed: IT marks task done or Drata auto-confirms via integration check

Evidence:
  → Complete access review report: reviewer, users reviewed, decisions, timestamps
  → Per-system reports available
  → Exported as PDF or CSV for audit
```

---

## Asset Inventory Architecture

### Discovery Process

```
Cloud Asset Discovery (AWS example):

Collection:
  AWS Config → Drata polls all resource types:
    AWS::EC2::Instance
    AWS::RDS::DBInstance
    AWS::S3::Bucket
    AWS::Lambda::Function
    AWS::ElasticLoadBalancingV2::LoadBalancer
    ...

Classification:
  Drata reads resource tags:
    environment = "production" → Asset class: Production
    environment = "staging"    → Asset class: Staging
    environment = "dev"        → Asset class: Development
    No tag                     → Asset class: Unclassified (flagged for review)

Compliance assessment per asset:
  EC2 Instance "prod-web-01":
    → EBS volumes encrypted: YES ✓
    → Security groups open to 0.0.0.0: NO ✓ (FAIL if YES)
    → SSM agent installed: YES ✓
    → IMDSv2 enforced: NO ✗ (failing test)
    → Overall: 3/4 tests passing → compliance score: 75%
```

### Scope Management

```
In-scope vs. out-of-scope assets:
  
  In scope: Included in compliance calculations and audit evidence
    → Production systems handling customer data
    → Systems supporting security controls (Okta, GitHub, MDM)
    
  Out of scope: Excluded from compliance calculations
    → Development environments
    → Test/staging environments (often)
    → Specific legacy systems with documented exception

Configuring scope:
  Drata → Asset Inventory → [asset] → Scope: In / Out
  Or bulk: filter by tag → set scope for all matching
  
  Scoping affects:
    → Which test failures count against compliance score
    → Which assets appear in audit evidence
    → Exception handling (out-of-scope assets don't need exceptions)
```

---

## Control Testing Engine

### Test Aggregation

Individual resource tests roll up to control-level status:

```
Control: "MFA enabled for all user accounts"
  Tests:
    → AWS: all IAM users have MFA (0 failing: PASS)
    → Okta: all users have MFA (2 failing: FAIL)
    → GitHub: all org members have 2FA (0 failing: PASS)
    
  Control aggregation: ANY test failing = control failing
  
  Failing users (from Okta test):
    → user1@company.com: no MFA enrolled
    → user2@company.com: no MFA enrolled
  
  Control owner notified: "MFA control failing — 2 Okta users need MFA"
  Evidence: not generated until control fully PASSING
```

### Test Frequency Tiers

```
Continuous (polling interval, typically 4-24 hours):
  → Cloud configuration checks (AWS security groups, S3 encryption)
  → Identity checks (Okta MFA, GitHub 2FA)
  → Endpoint compliance (device encryption, MDM enrollment)
  → Code repository settings (branch protection)

Monthly:
  → Vulnerability scan results (new scan results expected monthly)
  → Pending critical vulnerabilities age

Quarterly:
  → Access review completion (manually triggered campaign)
  → Vulnerability scan coverage

Annual:
  → Penetration test report
  → Security training completion (annual window)
  → DR/BCP test completion
  → Policy review and re-attestation
```

---

## Audit Hub Architecture

### Readiness Score Calculation

```
Readiness score = (passing tests / total applicable tests) × 100

Weighted factors:
  → Critical controls: higher weight (failure has larger score impact)
  → Framework-specific: some controls are framework-required vs. recommended
  → Exception handling: exceptions don't count as passing (they're neutral/excluded)
  → Not applicable: excluded from denominator

Score thresholds:
  < 70%: Not ready — significant gaps need addressing
  70-84%: Getting there — most gaps are smaller controls; close key ones
  85-94%: Audit ready — can invite auditor; remaining gaps manageable
  ≥ 95%: Excellent — minimal risk; exceptions documented
```

### Auditor Portal Capabilities

```
Auditor read-only view includes:

Controls & Tests:
  → All controls with framework mappings
  → Each test: description, result, evidence (with timestamp)
  → Evidence artifacts: downloadable
  → Exception details: justification, approver, expiry date

RFI Management:
  → Submit: "Please provide evidence of last DR test"
  → Track: open/answered RFIs
  → Comment thread on each RFI

Risk Register:
  → All risks: scoring, treatment status, linked controls

Policies:
  → All published policies with version and approval date
  → Attestation completion rates

Personnel:
  → Aggregate stats (% with completed training, background checks)
  → Not individual employee details (PII protected)
```
