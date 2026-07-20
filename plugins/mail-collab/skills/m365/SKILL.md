---
name: m365
description: "Expert skill for Microsoft 365 tenant administration — mail, collaboration, and compliance surfaces. Covers licensing, Conditional Access policy assignment, Microsoft Purview compliance, DLP, sensitivity labels, eDiscovery, admin centers, Microsoft Graph, Intune, and Teams/SharePoint governance. WHEN: \"Microsoft 365\", \"M365\", \"Office 365\", \"O365\", \"Conditional Access\", \"Purview\", \"sensitivity labels\", \"DLP\", \"eDiscovery\", \"M365 licensing\", \"E3\", \"E5\", \"Business Premium\", \"Intune\", \"Microsoft Graph\", \"Connect-MgGraph\", \"Teams admin\", \"SharePoint admin\", \"tenant setup\", \"Secure Score\", \"PIM\". Do NOT use for Entra ID conditional access policy internals, identity architecture, or hybrid identity sync depth — that's the `entra-id` skill in the `security` plugin."
license: MIT
---

# Microsoft 365 Administration

This skill covers Microsoft 365 tenant administration across the platform: licensing, security (Defender, Conditional Access), compliance (Purview), collaboration (Teams, SharePoint), endpoint management (Intune), and automation (Graph API, PowerShell). Read the reference files below for architecture, setup, and troubleshooting detail.

## How to Approach Tasks

1. **Classify** the request:
   - **Architecture** -- Load `references/architecture.md` for tenant model, service endpoints, identity integration, admin center map
   - **Best practices** -- Load `references/best-practices.md` for tenant setup, security hardening, compliance configuration, backup strategy
   - **Troubleshooting** -- Load `references/diagnostics.md` for sign-in failures, license errors, sync issues, service health
   - **Exchange-specific** -- Use the `exchange` skill for mailbox management, transport rules, hybrid, migration
   - **Email security** -- Use the `email-security` skill (`security` plugin) for SPF/DKIM/DMARC, Defender for O365 deep dive
   - **Entra ID identity depth** -- Use the `entra-id` skill (`security` plugin) for Conditional Access policy design, hybrid identity sync internals

2. **Identify the license tier** -- Many features depend on license level (E1/E3/E5, Business Basic/Standard/Premium). Check with `Get-MgSubscribedSku`.

3. **Load context** -- Read the relevant reference file before answering.

4. **Analyze** -- Apply M365-specific reasoning: license prerequisites, admin role requirements, Conditional Access policy interactions, compliance retention priority rules.

5. **Recommend** -- Provide concrete PowerShell commands (Graph SDK or Exchange Online module) and Admin Center navigation paths.

6. **Verify** -- Suggest validation steps: test sign-in, check Secure Score, verify policy application, audit log search.

## Core Architecture

### Tenant Model

A Microsoft 365 tenant is a dedicated Entra ID instance underpinning all M365 services. One tenant, multiple services.

**Key identifiers:**
- Tenant GUID (globally unique)
- Default domain: `tenant.onmicrosoft.com`
- Custom verified domains

### Identity Options

| Method | Infrastructure | SSO | Recommendation |
|---|---|---|---|
| Cloud-only | None | Entra ID native | New cloud-first orgs |
| Password Hash Sync | Entra Connect | Seamless SSO | Default for hybrid |
| Pass-through Auth | Entra Connect + PTA agents | Seamless SSO | Real-time on-prem auth validation |
| Federation (AD FS) | AD FS + WAP servers | Full AD FS SSO | Only if smart card/cert required |

### Admin Centers

| Portal | URL | Scope |
|---|---|---|
| M365 Admin Center | `admin.microsoft.com` | Users, groups, licenses, billing, health |
| Exchange Admin Center | `admin.exchange.microsoft.com` | Mailboxes, mail flow, migration |
| Security (Defender) | `security.microsoft.com` | Threat protection, email security |
| Purview Compliance | `purview.microsoft.com` | Retention, DLP, eDiscovery, audit |
| Entra ID | `entra.microsoft.com` | Identity, Conditional Access, PIM |
| SharePoint Admin | `<tenant>-admin.sharepoint.com` | Sites, sharing, storage |
| Teams Admin | `admin.teams.microsoft.com` | Teams policies, voice, devices |

## Licensing

### Enterprise Plans

| Feature | E1 | E3 | E5 |
|---|---|---|---|
| Desktop Office apps | No | Yes | Yes |
| Exchange mailbox | 50 GB | 100 GB | Unlimited archive |
| Entra ID tier | Free | P1 | P2 |
| Defender for O365 | No | Plan 1 (2026) | Plan 2 |
| Purview compliance | Basic | E3 level | Advanced (E5) |
| eDiscovery | Standard | Standard | Premium |

### License Management

```powershell
# Connect to Graph
Connect-MgGraph -Scopes "User.Read.All", "Directory.ReadWrite.All"

# View available licenses
Get-MgSubscribedSku | Select SkuPartNumber, ConsumedUnits, @{N='Available';E={$_.PrepaidUnits.Enabled - $_.ConsumedUnits}}

# Assign license to user
$skuId = (Get-MgSubscribedSku | Where {$_.SkuPartNumber -eq "ENTERPRISEPACK"}).SkuId
Set-MgUserLicense -UserId "user@contoso.com" -AddLicenses @(@{SkuId=$skuId}) -RemoveLicenses @()

# Group-based licensing (Entra P1 required)
$group = Get-MgGroup -Filter "displayName eq 'M365-E3-Users'"
Set-MgGroupLicense -GroupId $group.Id -AddLicenses @(@{SkuId=$skuId}) -RemoveLicenses @()
```

## Key Operations

### Conditional Access

```powershell
# Create MFA policy for all users
$policy = @{
    displayName = "Require MFA for All Users"
    state = "enabled"
    conditions = @{
        users = @{
            includeUsers = @("All")
            excludeUsers = @("break-glass-account-id")
        }
        applications = @{ includeApplications = @("All") }
    }
    grantControls = @{
        operator = "OR"
        builtInControls = @("mfa")
    }
}
New-MgIdentityConditionalAccessPolicy -BodyParameter $policy
```

**Essential policies:**
1. Require MFA for all administrators
2. Require MFA for all users (or risk-based with P2)
3. Block legacy authentication (IMAP, POP3, SMTP AUTH)
4. Require compliant device for corporate apps
5. Block high-risk countries/regions

### Purview Compliance

```powershell
# Connect to Security & Compliance
Connect-IPPSSession -UserPrincipalName admin@contoso.com

# Create retention policy
New-RetentionCompliancePolicy -Name "7-Year Financial Records" -ExchangeLocation All -SharePointLocation All
New-RetentionComplianceRule -Name "7-Year Rule" -Policy "7-Year Financial Records" -RetentionDuration 2556 -RetentionComplianceAction Keep

# Create DLP policy
New-DlpCompliancePolicy -Name "PCI-DSS Protection" -ExchangeLocation All -SharePointLocation All -Mode Enable
New-DlpComplianceRule -Name "Credit Card Rule" -Policy "PCI-DSS Protection" `
    -ContentContainsSensitiveInformation @(@{Name="Credit Card Number"; minCount=1}) `
    -BlockAccess $true -NotifyUser "SiteAdmin"

# Create eDiscovery case
New-ComplianceCase -Name "Litigation-2026-001" -CaseType AdvancedEdiscovery
```

### User Management

```powershell
# Create user
$passwordProfile = @{Password="TempP@ss!"; ForceChangePasswordNextSignIn=$true}
New-MgUser -DisplayName "Jane Smith" -UserPrincipalName "jsmith@contoso.com" `
    -MailNickname "jsmith" -AccountEnabled $true -PasswordProfile $passwordProfile -UsageLocation "US"

# Disable account
Update-MgUser -UserId "user@contoso.com" -AccountEnabled $false

# Check sign-in logs
Get-MgAuditLogSignIn -Filter "userPrincipalName eq 'user@contoso.com'" -Top 50
```

### Service Health Monitoring

```powershell
Connect-MgGraph -Scopes "ServiceHealth.Read.All"
Get-MgServiceAnnouncementHealthOverview | Select Service, Status
Get-MgServiceAnnouncementIssue -Filter "status ne 'resolved'" | Select Title, Service, Status
```

## Cross-References

| Topic | Skill | When |
|---|---|---|
| Exchange mailboxes | `exchange` | Mailbox management, transport rules, hybrid, migration |
| Email security | `email-security` (`security` plugin) | SPF/DKIM/DMARC, Defender policies, phishing |
| Entra ID identity | `entra-id` (`security` plugin) | Conditional Access policy design, hybrid identity sync internals |
| Google Workspace | `google-workspace` | M365-to-Google migration, platform comparison |
| Postfix relay | `postfix` | On-prem relay for M365 application mail |

## Reference Files

- `references/architecture.md` -- Tenant model, Entra ID integration, service endpoints, Microsoft Graph API, data residency, admin center map, core services (Exchange Online, SharePoint, Teams, OneDrive). **Load when:** architecture questions, tenant planning, Graph API usage.
- `references/best-practices.md` -- Tenant setup checklist, security hardening (CA policies, PIM, break-glass accounts), compliance configuration, backup strategy, monitoring, change management. **Load when:** new tenant setup, security review, compliance planning.
- `references/diagnostics.md` -- Sign-in failures, license assignment errors, sync issues, service health troubleshooting, Conditional Access debugging, audit log search. **Load when:** troubleshooting user issues, diagnosing policy problems, investigating incidents.

## Diagnostic Scripts

Ready-made Exchange Online PowerShell audit (read-only Get-* cmdlets) in `scripts/`.

- `scripts/01-mailflow-and-auth-audit.ps1` -- Connectors, risky transport rules, DKIM/domain posture
