# Drata Integration Coverage (170+)

**Cloud Infrastructure:**
```
AWS:
  → Services: IAM, Config, CloudTrail, GuardDuty, S3, EC2, RDS, Lambda, SecurityHub
  → Auth: IAM role (external ID, ReadOnlyAccess + SecurityAudit)
  → Tests: MFA, encryption, logging, security groups, root account protection

Azure:
  → Services: Entra ID, Defender for Cloud, Azure Policy, Monitor, subscriptions
  → Auth: Service principal (Reader + specific API permissions)
  → Tests: MFA, conditional access, Defender coverage, storage encryption

GCP:
  → Services: IAM, Security Command Center, Cloud Asset Inventory, Logging
  → Auth: Service account (Viewer role)
  → Tests: IAM policies, logging, encryption, security command center findings
```

**Identity Providers:**
```
Okta:
  → Tests: MFA enrollment (all users), inactive accounts, admin MFA, app access
  → Auth: Read-only API token

Microsoft Entra ID:
  → Tests: MFA, conditional access policies, privileged role assignments
  → Auth: Service principal (Microsoft Graph read permissions)

Google Workspace:
  → Tests: 2-step verification, admin accounts, external sharing settings
  → Auth: Service account with domain-wide delegation

JumpCloud, OneLogin, Ping Identity: also supported
```

**Endpoint Management:**
```
Jamf:
  → Tests: FileVault encryption, MDM enrollment, OS version compliance, screen lock
  → Auth: Jamf API credentials (read-only role)

Microsoft Intune:
  → Tests: BitLocker, compliance policy, MDM enrollment, patch level
  → Auth: Service principal (Intune read permissions)

Kandji, Mosyle: also supported for macOS

CrowdStrike:
  → Tests: Falcon agent coverage, sensor version
  → Auth: API credentials (Detections + Hosts read)
```

**Code and SDLC:**
```
GitHub:
  → Tests: branch protection, PR review requirements, force push protection, admin access
  → Auth: GitHub OAuth (org read access)

GitLab:
  → Tests: similar to GitHub
  → Auth: Personal access token or OAuth

Jira:
  → Tests: security vulnerability ticket aging, open critical findings
  → Auth: API token (read-only)
```

**HR and Personnel:**
```
BambooHR, Workday, Rippling, Gusto, ADP:
  → Sync: employee list, hire dates, termination dates, role
  → Tests: onboarding completeness, offboarding access revocation timing

Background check providers:
  → Checkr, Sterling, HireRight, Certn
  → Sync: completion status per employee
  → Tests: all employees with system access have completed background check

Security awareness training:
  → KnowBe4, Proofpoint Security Awareness, Curricula, Wizer
  → Sync: training completion per employee
  → Tests: annual training completion rate (target 100%)
```
