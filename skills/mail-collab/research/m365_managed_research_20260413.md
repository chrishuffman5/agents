# Microsoft 365 Administration — Comprehensive Research Document

**Prepared for:** Writer Agent (Technology Skill File Generation)
**Research Date:** April 2026
**Coverage:** Architecture, Licensing, Admin Centers, Identity, Core Services, Security & Compliance, Management, Best Practices, Diagnostics

---

## 1. ARCHITECTURE

### 1.1 Tenant Model

A Microsoft 365 tenant is a dedicated, isolated instance of Microsoft Entra ID (formerly Azure Active Directory) that an organization receives when it subscribes to any Microsoft cloud service. Key characteristics:

- **Single tenant, multiple services**: One Entra ID tenant underpins all M365 services — Exchange Online, SharePoint, Teams, OneDrive, Intune, Defender, Purview, and Power Platform.
- **Tenant identity**: Each tenant has a globally unique identifier (GUID) and one or more domain names (e.g., `contoso.onmicrosoft.com` plus verified custom domains like `contoso.com`).
- **Directory objects**: The tenant directory stores users, groups, devices, service principals, applications, and managed identities.
- **Data isolation**: Microsoft ensures strict data isolation between tenants at the platform layer. No cross-tenant data leakage is possible by default.
- **Two tenant configurations**: *Workforce* (default, for employees and internal apps) vs. *External* (for External ID / B2C scenarios with external consumers or partners).

### 1.2 Entra ID Integration

Microsoft Entra ID is the identity backbone for Microsoft 365. Every authentication and authorization event in M365 flows through Entra ID.

- **Authentication endpoints**: Global Azure workforce tenants use `https://login.microsoftonline.com/<tenant-id>/v2.0` as the OpenID Connect / OAuth 2.0 endpoint.
- **Token issuance**: Entra ID issues access tokens (JWT format) scoped to specific Microsoft 365 resource APIs (e.g., `https://graph.microsoft.com`, `https://outlook.office365.com`).
- **Conditional Access integration**: Every service checks token claims against Conditional Access policies before granting access.
- **App registrations**: First-party Microsoft services (Teams, SharePoint, Exchange) are represented as Enterprise Applications in the tenant. Admins can review and restrict consent via Enterprise Application policies.

### 1.3 Service Endpoints

| Service | Primary Endpoint |
|---|---|
| Microsoft Graph API | `https://graph.microsoft.com/v1.0/` (stable) / `/beta/` |
| Exchange Online (EWS) | `https://outlook.office365.com/EWS/Exchange.asmx` |
| Exchange Online (REST/MAPI) | `https://outlook.office365.com` |
| SharePoint Online | `https://<tenant>.sharepoint.com` |
| Teams | `https://teams.microsoft.com` (client), Graph API for backend |
| Microsoft 365 Admin Center | `https://admin.microsoft.com` |
| Security portal (XDR) | `https://security.microsoft.com` |
| Purview compliance portal | `https://purview.microsoft.com` |
| Entra ID portal | `https://entra.microsoft.com` |
| Power Platform admin | `https://admin.powerplatform.microsoft.com` |

Microsoft publishes the full list of required M365 URLs and IP ranges at `https://endpoints.office.com/endpoints/worldwide` (JSON feed, updated monthly). Network teams should use this feed — not manually maintained lists — to configure firewalls and proxies.

### 1.4 Data Residency and Multi-Geo

**Single-Geo (default)**: All tenant data is stored in the geography selected at provisioning time (e.g., North America, Europe, Asia Pacific). Admins can view committed data locations in the Admin Center under **Settings > Org settings > Organization profile > Data location**.

**Microsoft 365 Multi-Geo**: For multinational enterprises with data residency requirements, Multi-Geo allows storing data in multiple geographic locations within a single tenant.

- **Requirement**: Purchase Multi-Geo licenses for at least 5% of total eligible users.
- **Structure**: One *primary geo* (original provisioning location) plus one or more *satellite geos*.
- **Per-user PDL (Preferred Data Location)**: Admins set the `PreferredDataLocation` attribute on each user object to control where their Exchange mailbox, Teams chat data, and OneDrive are stored.
- **Exchange Online**: Automatic mailbox migration when PDL is changed — no manual move required.
- **OneDrive/SharePoint**: OneDrive migrates automatically when PDL is changed. SharePoint site collections do not auto-migrate; new sites provision in the correct geo.
- **Administration**: Satellite locations are added via SharePoint Admin Center under **Geo locations**. Provisioning can take up to 72 hours for large tenants.
- **PowerShell**: Use `Set-MgUser` with `-PreferredDataLocation` via Microsoft Graph PowerShell, or `Set-MsolUser -PreferredDataLocation` (legacy MSOL, deprecated).

### 1.5 Microsoft Graph API

Microsoft Graph is the unified REST API surface for all Microsoft 365 data and intelligence. It consolidates what were previously dozens of disparate service APIs (EWS, legacy SharePoint CSOM, etc.).

**Base URL**: `https://graph.microsoft.com/v1.0/` (production) or `/beta/` (preview features)

**Key resource categories**:
- `/users` — User accounts, profiles, photos, mail, calendar, files
- `/groups` — Microsoft 365 Groups, security groups, distribution lists
- `/devices` — Entra ID registered and joined devices
- `/directoryRoles` — Role assignments
- `/applications` — App registrations
- `/sites` — SharePoint sites and content
- `/teams` — Teams and channels
- `/security` — Alerts, incidents, secure scores
- `/compliance` — Purview data

**Authentication**: OAuth 2.0 with delegated (user context) or application (service context) permissions. Scopes are declared at app registration and consented by an admin for tenant-wide use.

**Graph Explorer**: Interactive tool at `https://developer.microsoft.com/en-us/graph/graph-explorer` for testing Graph queries without writing code.

---

## 2. LICENSING

### 2.1 Plan Comparison

#### Business Plans (max 300 users)

| Feature | Business Basic | Business Standard | Business Premium |
|---|---|---|---|
| **Price/user/month** | ~$6 | ~$12.50 | ~$22 |
| Desktop Office apps | No | Yes | Yes |
| Web/mobile Office apps | Yes | Yes | Yes |
| Exchange Online mailbox | 50 GB | 50 GB | 50 GB |
| SharePoint + OneDrive | 1 TB/user | 1 TB/user | 1 TB/user |
| Microsoft Teams | Yes | Yes | Yes |
| Entra ID tier | Free | Free | P1 |
| Intune | No | No | Plan 1 |
| Defender for Business | No | No | Yes |
| Defender for Office 365 | No | No | Plan 1 |
| Conditional Access | No | No | Yes (P1) |

#### Enterprise Plans (unlimited users)

| Feature | E1 | E3 | E5 |
|---|---|---|---|
| **Price/user/month** | ~$8 | ~$36 | ~$60 (from July 2026) |
| Desktop Office apps | No | Yes | Yes |
| Exchange Online mailbox | 50 GB | 100 GB | Unlimited archive |
| Entra ID tier | Free | P1 | P2 |
| Intune | No | Plan 1 | Plan 2 |
| Defender for Office 365 | No | Plan 1 (as of 2026) | Plan 2 |
| Defender for Identity | No | No | Yes |
| Microsoft Defender XDR | No | No | Yes |
| Purview compliance | Basic | E3 level | Advanced (E5) |
| eDiscovery | Standard | Standard | Premium |
| Audit | Standard | Standard | Premium |
| Phone System / Calling | No | No | Add-on required |

#### Frontline Worker Plans

| Feature | F1 | F3 |
|---|---|---|
| **Price/user/month** | ~$2.25 | ~$8 |
| Office apps | Web only | Web + mobile |
| Exchange | 2 GB (Kiosk) | 50 GB |
| Teams | Yes | Yes |
| SharePoint | Read-only (F1) | Full |
| Intune | No | Plan 1 |

### 2.2 Add-On Licenses (2025-2026)

| Add-On | Description | Monthly Price (approx.) |
|---|---|---|
| Microsoft 365 Copilot | AI assistant; requires E3/E5 or Business Standard/Premium | $30/user |
| Microsoft Copilot Business | SMB version (<300 users) | Lower than $30/user |
| Agent 365 | Autonomous AI agents (from May 2026) | $15/user |
| Defender for Office 365 P1 | Safe Links, Safe Attachments, anti-phishing | Bundled in E3+ now |
| Defender for Office 365 P2 | P1 + Attack Simulation, AIR, Threat Explorer | Add-on for E3 |
| Defender for Identity | On-premises AD threat detection | Part of E5 |
| Microsoft Purview E5 Compliance | Advanced eDiscovery, Insider Risk, Communication Compliance | Add-on for E3 |
| Microsoft Purview E5 Info Protection | Advanced sensitivity labels, MIP scanner | Add-on for E3 |
| Entra ID P1 | Conditional Access, SSPR, group-based licensing | Add-on for lower tiers |
| Entra ID P2 | P1 + PIM, Identity Protection, Access Reviews | Add-on for P1 |
| Intune Plan 2 | Advanced endpoint management, Tunnel, specialised devices | Add-on |
| Microsoft 365 E7 | New bundle (E5 + Copilot + Agent 365) | ~$99/user (from May 2026) |
| Security Copilot | Included in E5 (400 SCU/1,000 E5 users); standalone available | Variable |

### 2.3 License Assignment

#### Via Admin Center
Navigate to **Admin Center > Users > Active users** and select a user to assign licenses directly. For bulk assignment, use **Billing > Licenses** to assign to multiple users.

#### Group-Based Licensing (Entra ID P1 required)
Group-based licensing is the recommended at-scale approach. Assign license plans to a security group; all members automatically receive those licenses.

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.ReadWrite.All", "Directory.ReadWrite.All"

# Get the group
$group = Get-MgGroup -Filter "displayName eq 'M365-E3-Licensed-Users'"

# Get the SKU ID for M365 E3
$sku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq "ENTERPRISEPACK" }

# Assign license to group
$addLicenses = @(@{ SkuId = $sku.SkuId })
Set-MgGroupLicense -GroupId $group.Id -AddLicenses $addLicenses -RemoveLicenses @()
```

To add a user to the licensed group:
```powershell
New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $userId
```

#### Direct License Assignment via Graph PowerShell
```powershell
# Assign license directly to a user
$userId = "user@contoso.com"
$skuId = (Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq "ENTERPRISEPACK" }).SkuId

Set-MgUserLicense -UserId $userId `
  -AddLicenses @(@{ SkuId = $skuId }) `
  -RemoveLicenses @()
```

#### Graph API License Assignment (REST)
```http
POST https://graph.microsoft.com/v1.0/users/{userId}/assignLicense
Content-Type: application/json

{
  "addLicenses": [
    {
      "skuId": "6fd2c87f-b296-42f0-b197-1e91e994b900",
      "disabledPlans": []
    }
  ],
  "removeLicenses": []
}
```

---

## 3. ADMIN CENTERS

Microsoft 365 has a hub-and-spoke model: the main **Microsoft 365 Admin Center** (`admin.microsoft.com`) links to workload-specific portals.

### 3.1 Microsoft 365 Admin Center (MAC)
URL: `https://admin.microsoft.com`

Primary functions:
- User and group management (create, edit, license, delete)
- Domain management (add, verify, set primary)
- Billing and subscriptions
- Service health dashboard (real-time status + 30-day history)
- Message Center (planned changes, deprecations, new features)
- Org settings (profile, security, privacy)
- Reports (usage, adoption)
- Support request creation

Key admin roles: Global Administrator, User Administrator, License Administrator, Billing Administrator, Service Support Administrator.

### 3.2 Exchange Admin Center (EAC)
URL: `https://admin.exchange.microsoft.com`

Primary functions:
- Mailbox management (user, shared, resource, room)
- Distribution groups, mail-enabled security groups, dynamic distribution groups
- Mail flow rules (transport rules) and connectors
- Anti-spam and anti-malware policies (also in Defender portal)
- Message trace (up to 90 days)
- Public folders
- Migration batches (IMAP, cutover, staged, hybrid)
- Mail-enabled public folders

PowerShell access:
```powershell
# Connect to Exchange Online PowerShell
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com

# Or for MFA
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com -ShowBanner:$false
```

### 3.3 SharePoint Admin Center
URL: `https://admin.microsoft.com/sharepoint` or `https://<tenant>-admin.sharepoint.com`

Primary functions:
- Site collection management (create, delete, storage quota, external sharing)
- Sharing policies (anonymous links, external sharing, domain restrictions)
- Access control (legacy authentication, unmanaged device policies)
- Term store (managed metadata)
- Content type hub
- Migration (via SharePoint Migration Tool)
- Geo locations (Multi-Geo configuration)

PowerShell:
```powershell
Connect-SPOService -Url https://contoso-admin.sharepoint.com

# Get all site collections
Get-SPOSite -Limit All | Select-Object Url, StorageUsageCurrent, SharingCapability

# Set external sharing for a site
Set-SPOSite -Identity "https://contoso.sharepoint.com/sites/Project" -SharingCapability ExternalUserSharingOnly
```

### 3.4 Teams Admin Center
URL: `https://admin.teams.microsoft.com`

Primary functions:
- Teams and channel management
- Teams policies (messaging, meeting, calling, app policies)
- User policy assignment
- Devices (IP phones, Teams Rooms, Surface Hub)
- App management (Teams Store, custom apps)
- Voice (calling plans, direct routing, emergency policies)
- Analytics and reports (usage, PSTN)
- External access and guest access configuration

### 3.5 Microsoft Defender Portal (Security)
URL: `https://security.microsoft.com`

Consolidates: Defender for Office 365, Defender for Endpoint, Defender for Identity, Defender XDR.

Primary functions:
- Incidents and alerts management
- Threat hunting (Advanced Hunting, KQL queries)
- Threat Explorer / Email & collaboration reports
- Safe Attachments and Safe Links policy management
- Anti-phishing, anti-spam policies
- Attack Simulation Training
- Secure Score
- Microsoft Sentinel integration
- Threat intelligence

### 3.6 Microsoft Purview Compliance Portal
URL: `https://purview.microsoft.com`

Primary functions:
- Sensitivity labels (Information Protection)
- Data Loss Prevention policies
- Retention policies and labels
- Records management
- eDiscovery (Standard and Premium)
- Content Search
- Audit log search
- Communication Compliance
- Insider Risk Management
- Data lifecycle management
- Compliance Manager (regulatory frameworks)

### 3.7 Microsoft Entra Admin Center
URL: `https://entra.microsoft.com`

Primary functions:
- User and group management (also accessible from MAC)
- Conditional Access policies
- Identity Protection (risk policies)
- Privileged Identity Management (PIM)
- Enterprise Applications (service principals, SSO, app proxy)
- App registrations
- External Identities (B2B, B2C)
- Hybrid identity (Entra Connect, Cloud Sync)
- Authentication methods (MFA, SSPR, FIDO2, passwordless)
- Access Reviews
- Entra ID Connect Health monitoring

### 3.8 Power Platform Admin Center
URL: `https://admin.powerplatform.microsoft.com`

Primary functions:
- Environment management (default, sandbox, production)
- Data Loss Prevention (connector policies)
- Capacity and storage management
- CoE Starter Kit integration
- Analytics (usage, adoption)
- Gateway management

---

## 4. IDENTITY

### 4.1 Cloud-Only Identity

All user accounts exist solely in Entra ID with no on-premises Active Directory counterpart. Best for new organizations or cloud-native deployments.

Pros: Simple, no sync infrastructure, fastest to deploy.
Cons: No SSO to on-premises resources without additional configuration (e.g., SSPR must be cloud-side).

### 4.2 Hybrid Identity with Entra ID Connect

**Microsoft Entra Connect Sync** (formerly Azure AD Connect) synchronizes on-premises Active Directory objects to Entra ID.

- Installed on a domain member server (not a domain controller)
- Runs the full synchronization engine locally
- Supports Windows Server 2019, 2022, and 2025
- Sync cycle: delta sync every 30 minutes, full sync as scheduled
- Password Hash Sync (PHS): syncs a hash of the password hash; enables sign-in even if on-prem is unavailable
- Pass-through Authentication (PTA): authentication request is forwarded to on-prem AD agent in real time
- Federation (AD FS): authentication redirected to on-prem AD FS farm; most complex, highest resilience requirement

**Microsoft Entra Cloud Sync** (the future direction):
- Lightweight provisioning agents (multiple for HA) installed on-prem
- Configuration managed entirely in the cloud (Entra portal)
- Simpler than Connect Sync; recommended for new deployments
- Limitation: filtering only at OU or group level (no attribute-level filtering)
- Does support multi-forest to single tenant scenarios now
- Microsoft is directing customers to migrate from Connect Sync to Cloud Sync

```powershell
# Check sync status (on Entra Connect server)
Import-Module ADSync
Get-ADSyncScheduler

# Force a delta sync cycle
Start-ADSyncSyncCycle -PolicyType Delta

# Force a full sync cycle
Start-ADSyncSyncCycle -PolicyType Initial
```

### 4.3 Authentication Methods

| Method | Entra ID Tier | Notes |
|---|---|---|
| Password | Free | Legacy; should be combined with MFA |
| MFA (Authenticator app) | Free | Recommended primary MFA |
| FIDO2 security key | Free | Phishing-resistant; hardware key |
| Windows Hello for Business | Free | Biometric/PIN; device-bound |
| Certificate-based auth (CBA) | Free | Smart card or software certificate |
| Temporary Access Pass (TAP) | Free | Time-limited, for onboarding/recovery |
| SSPR (Self-Service Password Reset) | P1 (hybrid) / Free (cloud) | Reduces helpdesk load |

### 4.4 Conditional Access

Conditional Access is the Zero Trust policy engine in Entra ID. Policies evaluate signals (user, device, location, application, risk) and enforce controls (require MFA, require compliant device, block access, session controls).

**Policy anatomy**:
- **Assignments**: Users/groups, Cloud apps/actions, Conditions (platform, location, client apps, sign-in risk, user risk)
- **Access controls**: Grant (block, require MFA, require compliant device, require hybrid joined device), Session (sign-in frequency, persistent browser, app-enforced restrictions)

**Key recommended policies**:
1. Require MFA for all administrators
2. Require MFA for all users (or risk-based MFA via Identity Protection)
3. Require compliant or hybrid-joined device for corporate app access
4. Block legacy authentication protocols (IMAP, POP3, SMTP AUTH, older MAPI)
5. Block access from high-risk countries/regions (named locations)
6. Require MFA registration from trusted locations (bootstrap policy)

```powershell
# Example: Create a CA policy via Graph PowerShell requiring MFA for all users
$policy = @{
    displayName = "Require MFA for All Users"
    state = "enabled"
    conditions = @{
        users = @{
            includeUsers = @("All")
            excludeUsers = @("break-glass-account-object-id")
        }
        applications = @{
            includeApplications = @("All")
        }
    }
    grantControls = @{
        operator = "OR"
        builtInControls = @("mfa")
    }
}
New-MgIdentityConditionalAccessPolicy -BodyParameter $policy
```

**Security Defaults vs. Conditional Access**:
- Security Defaults: Free, preconfigured, enables MFA for all users/admins, blocks legacy auth. No customization. Best for organizations that cannot use Conditional Access.
- Conditional Access: Requires Entra ID P1+. Fully customizable policies. Disables Security Defaults when first policy is created. Recommended for any organization with P1 licensing.

### 4.5 Privileged Identity Management (PIM)

PIM provides Just-In-Time (JIT) privileged access to Entra ID roles and Azure resource roles. Requires Entra ID P2.

**Key concepts**:
- **Eligible assignment**: User can request activation of a role for a limited time window
- **Active assignment**: Role is always active (should be minimized)
- **Activation**: User requests role, can require MFA, justification, approval, and/or ticket number
- **Time-bound**: Roles expire automatically (configurable max duration)
- **Access Reviews**: Periodic reviews to confirm role assignments are still needed

```powershell
# Get all active Entra ID role assignments
Get-MgRoleManagementDirectoryRoleAssignment | Select-Object -Property RoleDefinitionId, PrincipalId

# Get eligible PIM assignments
Get-MgRoleManagementDirectoryRoleEligibilitySchedule | Select-Object PrincipalId, RoleDefinitionId, Status
```

**PIM best practices**:
- Zero standing privilege for Global Administrator and other sensitive roles
- Require approval for Global Admin activation
- Set maximum activation duration to 1-4 hours for highly privileged roles
- Configure alerts for unusual PIM activity
- Conduct monthly access reviews for Privileged Role Administrator

### 4.6 Entra ID Identity Protection (P2)

- **Sign-in risk**: Real-time risk score on each sign-in (anonymous IP, atypical travel, malware-linked IP, etc.)
- **User risk**: Cumulative risk score based on detected risky behaviors (leaked credentials, etc.)
- **Risk-based Conditional Access**: Require MFA for medium risk, block for high risk
- **Risk remediation**: Users can self-remediate with MFA; admins can manually dismiss or confirm risk
- **Workbooks/reports**: Risky users, risky sign-ins, risk detections available in the portal

---

## 5. CORE SERVICES

### 5.1 Exchange Online

Managed email and calendaring service. Key features:

- **Mailbox types**: User mailboxes, shared mailboxes (no license required for basic use), resource mailboxes (rooms, equipment), linked mailboxes (hybrid)
- **Mailbox sizes**: 50 GB standard; 100 GB in E3+; unlimited archive with auto-expanding archiving in E3/E5
- **Protocols**: MAPI over HTTPS (primary), EWS (legacy), IMAP/POP3 (can be disabled), SMTP (relay scenarios)
- **Hybrid configuration**: Exchange Hybrid Wizard (HCW) establishes OAuth trust between on-prem Exchange and Exchange Online; enables free/busy sharing, modern hybrid mail flow, centralized transport
- **Message trace**: Admin Center and PowerShell (`Get-MessageTrace`); up to 10-day detailed trace, 90-day summary
- **Mail flow rules**: Applied server-side during transport; can modify messages, add disclaimers, encrypt, route
- **Connectors**: Inbound/outbound connectors for partner routing, smart host relay, third-party security appliances

```powershell
# Get all mailboxes and their sizes
Get-EXOMailbox -ResultSize Unlimited | Get-EXOMailboxStatistics | `
  Select-Object DisplayName, TotalItemSize, ItemCount | Sort-Object TotalItemSize -Descending

# Create a shared mailbox
New-Mailbox -Shared -Name "HR Shared" -DisplayName "HR Team" -Alias "hr" -PrimarySmtpAddress "hr@contoso.com"

# Enable archive mailbox
Enable-Mailbox -Identity user@contoso.com -Archive

# Create transport rule to add disclaimer
New-TransportRule -Name "Add Legal Disclaimer" `
  -ApplyHtmlDisclaimerText "<div style='font-size:8pt'>Confidential</div>" `
  -ApplyHtmlDisclaimerLocation Append `
  -ApplyHtmlDisclaimerFallbackAction Wrap `
  -SentToScope NotInOrganization
```

### 5.2 SharePoint Online

Cloud-based document management and intranet platform.

- **Structure**: Tenant > Site Collections > Sites > Libraries/Lists > Folders > Items
- **Site types**: Communication sites (broadcast content), Team sites (collaboration, connected to M365 Group), Hub sites (navigation aggregation)
- **Storage**: 1 TB base + 10 GB per licensed user; additional storage purchasable
- **Sharing**: Controlled at tenant level (admin center) and site level; options include anyone links (anonymous), authenticated external users, or internal only
- **Versioning**: Major and minor versions; configurable limits; automatic preservation
- **Microsoft 365 Groups integration**: Team sites are backed by an M365 Group; membership controls site access

```powershell
# Connect and create a new site
Connect-SPOService -Url https://contoso-admin.sharepoint.com

New-SPOSite -Url "https://contoso.sharepoint.com/sites/Finance" `
  -Owner "admin@contoso.com" `
  -StorageQuota 1024 `
  -Title "Finance Team" `
  -Template "STS#3"  # Modern team site without group

# Set tenant-wide external sharing
Set-SPOTenant -SharingCapability ExternalUserSharingOnly

# Block download for unmanaged devices at site level
Set-SPOSite -Identity "https://contoso.sharepoint.com/sites/Confidential" `
  -ConditionalAccessPolicy AllowLimitedAccess
```

### 5.3 Microsoft Teams

Unified communications and collaboration platform.

- **Architecture**: Teams clients connect to Microsoft 365 cloud infrastructure; data stored in Exchange Online (chat history), SharePoint/OneDrive (files), and Azure Media Services (meetings)
- **Team types**: Standard (all members can add channels), Private teams, Org-wide teams (up to 10,000 members)
- **Channel types**: Standard, Private (separate SharePoint site), Shared (cross-tenant)
- **Meetings**: Teams meetings use Microsoft's media relay infrastructure; supports up to 1,000 attendees (standard meeting) or 10,000-20,000 (town halls/webinars)
- **Direct Routing**: Bring your own telephony (SBC connection to PSTN) for enterprise voice
- **Calling Plans**: Microsoft-provided PSTN connectivity by country
- **Teams Rooms**: Dedicated hardware + software for conference room experiences

Teams governance considerations:
- Team creation policy (restrict to specific groups)
- Guest access settings (per-org and per-team)
- External access (federation with other Teams tenants)
- Meeting policies (recording, lobby, attendance)
- App permission policies (which apps users can install)

### 5.4 OneDrive for Business

Personal cloud storage for each licensed user.

- **Quota**: 1 TB per user by default; can be increased up to 5 TB or more for eligible plans
- **Sync client**: OneDrive sync app for Windows/macOS; selective sync by folder
- **Known Folder Move (KFM)**: Policy-redirects Desktop, Documents, Pictures to OneDrive; managed via Intune or Group Policy
- **Retention after user deletion**: Deleted user's OneDrive preserved for 30 days (configurable up to 180 days) before permanent deletion
- **Sharing**: Controlled by SharePoint tenant sharing policies; sharing with external users requires SharePoint external sharing to be enabled

### 5.5 Microsoft Planner

Task management integrated with Teams and M365 Groups.

- Each plan is associated with an M365 Group
- Tasks can be assigned, labeled, have due dates, checklists, and file attachments
- **Microsoft Planner and To Do integration**: Planner tasks appear in Microsoft To Do
- **Project for the web / Microsoft Project**: More advanced project management; available as add-on
- **Planner API**: Available via Microsoft Graph at `/planner/plans`, `/planner/tasks`

### 5.6 Power Platform Integration

Power Platform (Power Apps, Power Automate, Power BI, Power Pages, Copilot Studio) is tightly integrated with Microsoft 365.

- **Environments**: Power Platform has its own environment model (Default, Sandbox, Production). M365 license users access the Default environment.
- **Connectors**: 1,400+ connectors; Microsoft 365 connectors (SharePoint, Outlook, Teams, Planner, OneDrive) are Premium-free; others may require Power Automate Premium.
- **DLP policies**: Admins create Data Loss Prevention policies in the Power Platform Admin Center to control which connectors can be used together (Business vs. Non-Business classification).
- **Dataverse**: The data platform underlying model-driven apps; requires appropriate Power Apps license.
- **CoE Starter Kit**: Free governance toolkit from Microsoft providing inventory, compliance, and adoption dashboards.

```powershell
# Connect to Power Platform admin (via PAC CLI or Az module)
# List environments
Get-AdminPowerAppEnvironment | Select-Object DisplayName, EnvironmentType, Location
```

---

## 6. SECURITY & COMPLIANCE

### 6.1 Microsoft Purview Overview

Microsoft Purview is the umbrella for data governance, compliance, and information protection across Microsoft 365. It replaces the former "Microsoft 365 Compliance Center" and "Azure Purview".

### 6.2 Sensitivity Labels

Sensitivity labels classify and protect content (documents, emails, meetings, containers) with persistent metadata.

**Label taxonomy example**:
```
Public
Internal
  Internal > General
  Internal > HR
Confidential
  Confidential > All Employees
  Confidential > Finance Only
Highly Confidential
  Highly Confidential > C-Suite Only
```

**Actions labels can enforce**:
- Encryption (Azure Information Protection / Office 365 Message Encryption)
- Content marking (headers, footers, watermarks)
- Auto-labeling (client-side via policy, service-side via trainable classifiers)
- Container labeling (Teams, SharePoint sites, M365 Groups)
- Meeting labeling (controls recording, chat, lobby)

**Licensing**: Basic sensitivity labels in E3; auto-labeling and advanced classification (trainable classifiers) require E5 or E5 Information Protection add-on.

```powershell
# Connect to Security & Compliance Center
Connect-IPPSSession -UserPrincipalName admin@contoso.com

# Get all sensitivity labels
Get-Label | Select-Object DisplayName, Priority, ContentType

# Create a label
New-Label -Name "Confidential-Finance" -DisplayName "Confidential - Finance" `
  -Tooltip "For Finance team use only" `
  -EncryptionEnabled $true `
  -EncryptionProtectionType Template
```

### 6.3 Data Loss Prevention (DLP)

DLP policies detect and prevent sharing of sensitive information (credit cards, SSNs, health data, etc.).

**Policy components**:
- **Locations**: Exchange, SharePoint, OneDrive, Teams, Endpoint (Intune-managed devices), Power Platform
- **Conditions**: Sensitive information types (built-in or custom), sensitivity labels, content contains keywords
- **Actions**: Block, restrict sharing, require justification override, notify user, notify admin, generate incident report

**Sensitive information types**: 200+ built-in types (PII, PCI, PHI); custom regex or keyword dictionary types can be created.

**Endpoint DLP**: Monitors and restricts sensitive data on Windows 10/11 devices (copy to USB, print, upload to cloud apps, etc.). Requires Purview compliance license (E5 or add-on).

```powershell
# Create a DLP policy
New-DlpCompliancePolicy -Name "PCI-DSS Protection" `
  -ExchangeLocation All `
  -SharePointLocation All `
  -Mode Enable

New-DlpComplianceRule -Name "Credit Card Number Rule" `
  -Policy "PCI-DSS Protection" `
  -ContentContainsSensitiveInformation @(@{Name="Credit Card Number"; minCount=1}) `
  -BlockAccess $true `
  -NotifyUser "SiteAdmin","LastModifier"
```

### 6.4 Retention Policies and Labels

**Retention policies**: Applied to locations (Exchange, SharePoint, OneDrive, Teams, Yammer); retain and/or delete content based on age or creation/modification date.

**Retention labels**: Applied to individual items; can mark as records (immutable until retention expires); support event-based retention triggers.

**Priority of retention**:
1. Retention that prevents deletion overrides retention that allows deletion
2. Longer retention period wins over shorter
3. Explicit item-level label wins over policy applied to location

```powershell
# Create a retention policy
New-RetentionCompliancePolicy -Name "7-Year Financial Records" `
  -ExchangeLocation All `
  -SharePointLocation All `
  -RetentionDuration 2556  # 7 years in days

New-RetentionComplianceRule -Name "7-Year Financial Records Rule" `
  -Policy "7-Year Financial Records" `
  -RetentionDuration 2556 `
  -RetentionComplianceAction Keep
```

### 6.5 eDiscovery

**Standard eDiscovery** (E3+):
- Content Search across Exchange, SharePoint, OneDrive, Teams, Yammer
- Legal Hold (preserve content in-place)
- Export search results for legal review

**Premium eDiscovery** (E5 or add-on):
- Custodian management and legal hold notifications
- Advanced processing (near-duplicate detection, email threading, OCR)
- Review sets with advanced analytics
- Predictive coding (machine learning relevance)
- Review set exports with load files for legal review tools

```powershell
# Create eDiscovery case
New-ComplianceCase -Name "Litigation-2026-001" -CaseType AdvancedEdiscovery

# Create content search
New-ComplianceSearch -Name "HR Investigation Search" `
  -ExchangeLocation "user@contoso.com" `
  -ContentMatchQuery "keyword1 OR keyword2" `
  -Case "Litigation-2026-001"

Start-ComplianceSearch -Identity "HR Investigation Search"
```

### 6.6 Audit

**Standard Audit** (E1/E3):
- 180-day audit log retention
- User and admin activity across M365 services
- Searchable via Purview compliance portal or PowerShell

**Premium Audit** (E5):
- 1-year default audit log retention (extendable to 10 years with add-on)
- High-value security events (MailItemsAccessed, Send, SearchQueryInitiatedExchange/SharePoint)
- Faster audit log access via API

```powershell
# Search the audit log
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-7) `
  -EndDate (Get-Date) `
  -RecordType ExchangeItem `
  -Operations "MailItemsAccessed" `
  -ResultSize 5000
```

### 6.7 Microsoft Defender for Office 365

**Plan 1** (included in Business Premium, E3 as of 2026):
- Safe Attachments: Detonates attachments in a sandbox before delivery; blocks malicious files
- Safe Links: URL rewriting and time-of-click verification; blocks malicious URLs in email and Office docs
- Anti-phishing with impersonation protection: Detects spoofed domains and user impersonation
- Anti-spam and anti-malware policies

**Plan 2** (E5, or add-on):
- All Plan 1 features plus:
- Attack Simulation Training: Simulated phishing campaigns with automated training assignment
- Automated Investigation and Response (AIR): Automatically investigates alerts and remediates threats
- Threat Explorer: Interactive threat hunting for email threats
- Priority account protection: Enhanced protection for executives

**Configuration best practices**:
```powershell
# Apply Safe Attachments preset security policy (via New-SafeAttachmentPolicy)
New-SafeAttachmentPolicy -Name "Standard Protection" `
  -Action Block `
  -Redirect $false `
  -Enable $true

# Apply Safe Links policy
New-SafeLinksPolicy -Name "Standard Safe Links" `
  -EnableSafeLinksForEmail $true `
  -EnableSafeLinksForTeams $true `
  -ScanUrls $true `
  -EnableForInternalSenders $true `
  -DeliverMessageAfterScan $true `
  -DisableUrlRewrite $false `
  -TrackClicks $true
```

**Attack Simulation Training setup**:
1. Navigate to `security.microsoft.com > Attack simulation training`
2. Create a simulation with a real-world phishing payload
3. Select target users (all or subset)
4. Assign training to users who click the simulated link
5. Review campaign reports for click rates, training completion
- Requires Defender for Office 365 Plan 2 license
- Configure exclusions for the simulation sender domain in anti-spam policies

---

## 7. MANAGEMENT

### 7.1 Microsoft Graph PowerShell SDK

The Microsoft Graph PowerShell SDK (`Microsoft.Graph` module) is the modern replacement for deprecated modules (MSOnline, AzureAD). It surfaces all Graph API capabilities as PowerShell cmdlets.

**Installation**:
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
# Or install only specific sub-modules
Install-Module Microsoft.Graph.Users
Install-Module Microsoft.Graph.Groups
Install-Module Microsoft.Graph.Identity.SignIns
```

**Connection methods**:
```powershell
# Interactive (browser pop-up)
Connect-MgGraph -Scopes "User.Read.All", "Group.ReadWrite.All", "Directory.ReadWrite.All"

# Device code flow (headless/remote sessions)
Connect-MgGraph -Scopes "User.Read.All" -UseDeviceAuthentication

# App-only (service principal with certificate - recommended for automation)
Connect-MgGraph -ClientId $appId -TenantId $tenantId -CertificateThumbprint $thumbprint

# App-only (client secret - less secure, avoid in production)
$secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($clientId, $secureSecret)
Connect-MgGraph -ClientId $clientId -TenantId $tenantId -ClientSecretCredential $credential
```

**Common user management commands**:
```powershell
# Get all users with specific properties
Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,AssignedLicenses |
  Select-Object DisplayName,UserPrincipalName,AccountEnabled

# Create a new user
$passwordProfile = @{ Password = "TempP@ssw0rd!"; ForceChangePasswordNextSignIn = $true }
New-MgUser -DisplayName "Jane Smith" `
  -UserPrincipalName "jsmith@contoso.com" `
  -MailNickname "jsmith" `
  -AccountEnabled $true `
  -PasswordProfile $passwordProfile `
  -UsageLocation "US"

# Disable a user account
Update-MgUser -UserId "user@contoso.com" -AccountEnabled $false

# Get sign-in logs for a user
Get-MgAuditLogSignIn -Filter "userPrincipalName eq 'user@contoso.com'" -Top 50
```

**Group management**:
```powershell
# Get all M365 Groups
Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All

# Create an M365 Group (with Teams provisioning)
New-MgGroup -DisplayName "Project Alpha" `
  -MailNickname "projectalpha" `
  -MailEnabled $true `
  -SecurityEnabled $false `
  -GroupTypes @("Unified")

# Add member to group
New-MgGroupMember -GroupId $groupId -DirectoryObjectId $userId
```

### 7.2 Microsoft 365 CLI

The Microsoft 365 CLI (`m365`) is a cross-platform CLI tool for M365 administration, usable from any shell (bash, zsh, PowerShell).

```bash
# Install
npm install -g @pnp/cli-microsoft365

# Login
m365 login

# Get tenant information
m365 tenant report activeusercounts --period D7

# List SharePoint sites
m365 spo site list

# Create Teams team
m365 teams team add --name "Project Beta" --description "Project Beta Team"

# Get all users
m365 aad user list --output json
```

### 7.3 Microsoft Intune (Endpoint Management)

Intune provides mobile device management (MDM) and mobile application management (MAM) for corporate and BYOD devices.

**Device enrollment methods**:
- Windows Autopilot (zero-touch provisioning for new Windows devices)
- Entra ID join + automatic MDM enrollment (policy-driven for domain-joined or cloud-joined)
- Apple Business Manager / School Manager (for iOS/macOS)
- Android Enterprise (work profile, fully managed, dedicated)
- Manual enrollment (user-initiated via Company Portal app)

**Compliance policies**: Define the minimum security bar a device must meet to be considered "compliant":
- BitLocker enabled
- Minimum OS version
- No jailbreak/root
- PIN/passcode required
- Require Microsoft Defender (Windows)

**Conditional Access + Intune**: Entra ID Conditional Access checks Intune compliance status as a signal. Non-compliant devices can be blocked from M365 resources. Enrollment itself is not blocked by compliance CA policies — compliance is evaluated after enrollment.

**Configuration profiles**: Deploy settings (Wi-Fi, VPN, email, certificates, restrictions) to enrolled devices.

**Key PowerShell / Graph API for Intune**:
```powershell
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All"

# Get all managed devices
Get-MgDeviceManagementManagedDevice -All | Select-Object DeviceName, OperatingSystem, ComplianceState, LastSyncDateTime

# Get non-compliant devices
Get-MgDeviceManagementManagedDevice -Filter "complianceState eq 'noncompliant'" -All
```

### 7.4 Azure AD Connect Health

Microsoft Entra Connect Health is a cloud-based monitoring service for hybrid identity infrastructure.

- **For Entra Connect Sync**: Monitors sync health, sync errors, latency alerts, export/import statistics
- **For AD FS**: Monitors AD FS servers and WAP (Web Application Proxy) servers, token requests, failed logins
- **For AD DS (Domain Services)**: Monitors domain controllers, replication health, NTLM/Kerberos performance

**Requirements**: Entra ID P1 license; Health agent installed on each server being monitored.

```powershell
# View sync errors from Entra Connect
Get-ADSyncCSObject -ConnectorName "contoso.com" -DistinguishedName "CN=..."

# Check Entra Connect Health via Graph (preview)
GET https://graph.microsoft.com/beta/directory/onPremisesSynchronization
```

---

## 8. BEST PRACTICES

### 8.1 Tenant Setup Checklist

**Day 1 — Foundation**:
- [ ] Verify and add all custom domains
- [ ] Configure SPF, DKIM, and DMARC DNS records for each mail domain
- [ ] Set up at least two break-glass (emergency access) Global Admin accounts — cloud-only, long random passwords, no MFA (or hardware FIDO2 key), excluded from all CA policies
- [ ] Enable Microsoft Authenticator (or FIDO2) as authentication methods; disable SMS OTP as primary method
- [ ] Disable or configure Security Defaults vs. deploy Conditional Access policies
- [ ] Block legacy authentication (IMAP, POP3, SMTP AUTH where not needed) via CA policy
- [ ] Configure admin roles with least-privilege principle; use PIM for Global Admin

**Day 1 — Email Security**:
- [ ] Enable DKIM signing for all custom domains (Exchange Admin Center > Email Authentication)
- [ ] Configure DMARC policy (`p=quarantine` initially, then `p=reject`)
- [ ] Configure anti-spam, anti-phishing, and anti-malware policies (or apply Standard/Strict preset security policies)
- [ ] Enable Safe Attachments and Safe Links (if licensed)

**Day 30 — Governance**:
- [ ] Configure M365 Group creation policy (restrict to IT or designated groups)
- [ ] Configure Teams external access and guest access policies
- [ ] Configure SharePoint external sharing policy (align to business risk appetite)
- [ ] Set up sensitivity labels hierarchy and publish to users
- [ ] Create baseline DLP policy for common sensitive information types
- [ ] Configure retention policies for regulatory compliance

**Day 90 — Monitoring**:
- [ ] Subscribe Message Center to email digest for admins
- [ ] Configure Service Health alerts to email/Teams webhook
- [ ] Set up Secure Score baseline and improvement action tracking
- [ ] Enable Unified Audit Log (verify it is on: `Get-AdminAuditLogConfig | Select-Object UnifiedAuditLogIngestionEnabled`)
- [ ] Configure Entra ID Connect Health if hybrid

### 8.2 Security Defaults vs. Conditional Access

| Aspect | Security Defaults | Conditional Access |
|---|---|---|
| License required | None (Free) | Entra ID P1 minimum |
| MFA | All users and admins | Configurable per user/group/app |
| Legacy auth | Blocked | Configurable |
| Admin MFA | All admin actions | All admin actions (recommended) |
| Customization | None | Fully customizable |
| Break-glass exclusions | No | Yes |
| Risk-based policies | No | Yes (P2) |
| Named locations | No | Yes |

**Recommendation**: Use Conditional Access for any organization with Entra ID P1 (Business Premium or E3+). Security Defaults is appropriate for small organizations without P1.

### 8.3 Backup Strategy

Microsoft 365 has a 30-day recycle bin and deleted item retention, but it is NOT a backup solution. Microsoft's responsibility is infrastructure availability, not data backup against admin error, ransomware, or accidental mass deletion.

**Native capabilities**:
- SharePoint/OneDrive: 93-day recycle bin (30-day first stage + 30-day second stage + additional buffer)
- Exchange: Deleted items 14-30 days; Recoverable Items folder 14-30 days; Litigation Hold extends indefinitely
- Teams: Deleted channel posts not always recoverable

**Microsoft 365 Backup (native, preview/GA)**: Microsoft introduced a native backup solution (via Syntex/Microsoft 365 Backup). Supports SharePoint, OneDrive, and Exchange. Point-in-time restore for 30-day recovery window. Purchased per GB/month.

**Third-party backup solutions** (recommended for comprehensive coverage):
- Veeam Backup for Microsoft 365
- Acronis Cyber Protect Cloud
- Druva inSync
- Commvault Cloud

**Best practice**:
- Use third-party backup for Exchange mailboxes, SharePoint sites, OneDrive, and Teams
- Backup runs daily minimum; test restore monthly
- Store backup data outside the M365 tenant
- Include Entra ID configuration export in backup scope (use `Microsoft365DSC` for configuration drift monitoring)

### 8.4 Monitoring: Service Health and Message Center

**Service Health** (`admin.microsoft.com > Health > Service health`):
- Real-time status of all M365 services
- Incident vs. Advisory distinction
- Recommended action: Subscribe to email alerts for critical services

```powershell
# Get current service health via Graph
Connect-MgGraph -Scopes "ServiceHealth.Read.All"
Get-MgServiceAnnouncementHealthOverview | Select-Object Service, Status
Get-MgServiceAnnouncementIssue -Filter "status ne 'resolved'" | Select-Object Title, Service, Status
```

**Message Center** (`admin.microsoft.com > Health > Message center`):
- Planned changes, new features, deprecations
- Messages tagged by category: Plan for change, Stay informed, Prevent or fix issues
- Recommended action: Configure weekly digest to IT team email
- API: Use `Get-MgServiceAnnouncementMessage` to programmatically retrieve and route to Teams/Slack

**Microsoft 365 Network Connectivity dashboard**: Found under `admin.microsoft.com > Health > Network connectivity`. Shows network path analysis and recommends optimizations (e.g., direct egress to Microsoft network, avoiding proxy hairpin).

### 8.5 Change Management

- Monitor Message Center actively; assign ownership of change items
- Use Preview tenants (tenant-level feature rollout controls) to test changes before general rollout
- Use Microsoft 365 Roadmap (`https://www.microsoft.com/en-us/microsoft-365/roadmap`) for future planning
- Communicate user-impacting changes 2+ weeks in advance via internal comms
- Use **Microsoft Adoption Hub** resources for user training material
- Track configuration state with `Microsoft365DSC` (PowerShell module for desired-state configuration and drift detection)

---

## 9. DIAGNOSTICS AND TROUBLESHOOTING

### 9.1 Service Health Issues

**First response protocol**:
1. Check `admin.microsoft.com > Health > Service health` for active incidents
2. Check `https://status.cloud.microsoft` for public status page
3. Check Microsoft's `@MSFT365Status` on X/Twitter for real-time updates
4. If no known issue, proceed with tenant-specific troubleshooting

### 9.2 User Sign-In Failures

**Tools and approach**:
```powershell
# Get sign-in logs for a specific user (last 7 days)
Connect-MgGraph -Scopes "AuditLog.Read.All"
$logs = Get-MgAuditLogSignIn -Filter "userPrincipalName eq 'user@contoso.com' and createdDateTime ge $(Get-Date (Get-Date).AddDays(-7) -Format 'yyyy-MM-ddTHH:mm:ssZ')" -Top 100
$logs | Select-Object CreatedDateTime, AppDisplayName, Status, ConditionalAccessStatus, ErrorCode | Format-Table
```

**Common error codes**:
| Code | Meaning | Resolution |
|---|---|---|
| 50053 | Account locked (too many bad passwords) | Unlock in Entra ID or wait for lockout duration |
| 50126 | Invalid credentials | Reset password |
| 50058 | Session timeout | User must re-authenticate |
| 70008 | Refresh token expired | User must re-authenticate |
| 53003 | Blocked by Conditional Access | Review CA policy; check user/device compliance |
| 50097 | Device authentication required | Check hybrid join or Intune enrollment |
| 50055 | Password expired | User must change password |

**Entra ID Sign-in diagnostic**: Available in Entra portal under `Diagnose and solve problems`. Analyzes specific sign-in events automatically.

### 9.3 Mail Flow Issues

```powershell
# Message trace for a specific email
Get-MessageTrace -SenderAddress sender@external.com `
  -RecipientAddress user@contoso.com `
  -StartDate (Get-Date).AddDays(-3) `
  -EndDate (Get-Date) |
  Select-Object Received, SenderAddress, RecipientAddress, Subject, Status, MessageId

# Detailed trace for a specific message
Get-MessageTraceDetail -MessageId "<message-id@domain.com>" `
  -SenderAddress sender@external.com `
  -RecipientAddress user@contoso.com `
  -StartDate (Get-Date).AddDays(-3) `
  -EndDate (Get-Date)
```

**Microsoft Remote Connectivity Analyzer** (`https://testconnectivity.microsoft.com`):
- Free web-based tool for testing M365/Exchange connectivity without installing software
- Tests: Inbound SMTP, Outlook Anywhere, ActiveSync, Autodiscover, Exchange Web Services, SSO/federation
- Returns detailed diagnostic output with specific error codes and remediation steps
- Also available as CLI tool for offline use

**Common mail flow issues**:
- NDR 550 5.1.x: Recipient address doesn't exist; check mailbox exists and is licensed
- NDR 550 5.7.x: Delivery blocked; check connector configuration, SPF/DKIM/DMARC, anti-spam policy
- Queued mail: Check connector health; check MX record propagation
- Delayed delivery: Check if Safe Attachments detonation sandbox is causing delay (expected 1-5 min)

**Check DKIM and DMARC configuration**:
```powershell
# Check DKIM signing configuration
Get-DkimSigningConfig | Select-Object Domain, Enabled, Status

# Enable DKIM for a domain
Set-DkimSigningConfig -Identity contoso.com -Enabled $true

# Verify DMARC DNS record (external tool or nslookup)
# nslookup -type=TXT _dmarc.contoso.com
```

### 9.4 License Conflicts

```powershell
# Find users with license assignment errors
Get-MgUser -Filter "assignedPlans/any(p:p/capabilityStatus ne 'Enabled')" -All -Property DisplayName,UserPrincipalName,LicenseAssignmentStates |
  Where-Object { $_.LicenseAssignmentStates | Where-Object { $_.State -eq "Error" } } |
  Select-Object DisplayName, UserPrincipalName

# Check if user has UsageLocation set (required for license assignment)
Get-MgUser -UserId user@contoso.com -Property UsageLocation,DisplayName

# Set UsageLocation
Update-MgUser -UserId user@contoso.com -UsageLocation "US"
```

**Common license issues**:
- Missing `UsageLocation` attribute: User cannot be licensed without a usage location set
- Group-based licensing error: User is in a group assigned a license plan, but the plan has no available seats
- Conflicting service plans: Some service plans are mutually exclusive (e.g., Exchange Online Plan 1 and Plan 2)
- Orphaned group-based licenses: User removed from group but license-consuming objects persist

### 9.5 Entra ID Connect Sync Errors

**View sync errors in portal**: Entra admin center > Identity > Hybrid management > Entra Connect > Sync errors

**Common error types**:
| Error | Cause | Resolution |
|---|---|---|
| `AttributeValueMustBeUnique` | Duplicate `proxyAddresses` or `userPrincipalName` | Fix duplicate in on-prem AD |
| `ObjectTypeMismatch` | Object class changed (e.g., user became contact) | Delete cloud object or fix type |
| `InvalidSoftMatch` | Soft match failed due to conflicting attributes | Manually hard-match or reconcile |
| `LargeObject` | Attribute value exceeds size limit | Truncate attribute in on-prem AD |
| `DataValidationFailed` | UPN contains invalid characters | Fix UPN in on-prem AD |

```powershell
# On the Entra Connect server - view sync error objects
Import-Module ADSync
$syncErrors = Get-ADSyncCSObject -ConnectorName "contoso.com" | Where-Object { $_.ExportError -ne $null }
$syncErrors | Select-Object AnchorValue, ExportError

# Run a sync cycle and capture output
$result = Start-ADSyncSyncCycle -PolicyType Delta
$result | Select-Object Result

# Check Entra Connect version
Get-ADSyncScheduler | Select-Object SyncCycleEnabled, NextSyncCyclePolicyType, NextSyncCycleStartedTime
```

**Entra Connect Health errors**: View in Entra portal under `Diagnose & solve` > `Sync errors`. Alerts fire automatically to the tenant's technical contact email.

### 9.6 Tenant-Level Diagnostic Tools

**Microsoft Support and Recovery Assistant (SARA)**:
- Desktop tool for diagnosing Outlook, Teams, OneDrive, Exchange connectivity issues from the user machine perspective
- Download from `https://aka.ms/SaRA`

**Microsoft 365 network test**: `https://connectivity.office.com` — tests network performance and routing to M365 endpoints from the client machine.

**Secure Score**: `security.microsoft.com > Secure score` — measures tenant security posture; provides prioritized improvement actions.

**Compliance Manager**: `purview.microsoft.com > Compliance manager` — assesses compliance posture against regulatory frameworks (GDPR, ISO 27001, NIST, etc.); generates improvement actions and risk score.

---

## 10. QUICK REFERENCE — KEY POWERSHELL MODULES

| Module | Purpose | Install Command |
|---|---|---|
| `Microsoft.Graph` | Graph API (all M365) | `Install-Module Microsoft.Graph` |
| `ExchangeOnlineManagement` | Exchange Online | `Install-Module ExchangeOnlineManagement` |
| `Microsoft.Online.SharePoint.PowerShell` | SharePoint Online | `Install-Module Microsoft.Online.SharePoint.PowerShell` |
| `MicrosoftTeams` | Teams admin | `Install-Module MicrosoftTeams` |
| `Microsoft.PowerApps.Administration.PowerShell` | Power Platform admin | `Install-Module Microsoft.PowerApps.Administration.PowerShell` |
| `MSCommerce` | M365 licensing/commerce | `Install-Module MSCommerce` |
| `ADSync` | Entra Connect (local) | Pre-installed on Connect server |

---

## 11. KEY GRAPH API ENDPOINTS FOR ADMINS

```http
# List all users
GET https://graph.microsoft.com/v1.0/users?$select=displayName,userPrincipalName,accountEnabled,assignedLicenses&$top=999

# Get all groups
GET https://graph.microsoft.com/v1.0/groups?$filter=groupTypes/any(c:c eq 'Unified')

# Get subscribed SKUs (available licenses)
GET https://graph.microsoft.com/v1.0/subscribedSkus

# Assign license to user
POST https://graph.microsoft.com/v1.0/users/{userId}/assignLicense

# Get conditional access policies
GET https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies

# Get sign-in logs
GET https://graph.microsoft.com/v1.0/auditLogs/signIns?$filter=createdDateTime ge 2026-04-01T00:00:00Z&$top=100

# Get service health
GET https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews

# Get message center messages
GET https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/messages

# Get Intune managed devices
GET https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select=deviceName,operatingSystem,complianceState,lastSyncDateTime

# Get PIM eligible role assignments
GET https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilitySchedules

# Get risky users (Identity Protection)
GET https://graph.microsoft.com/v1.0/identityProtection/riskyUsers?$filter=riskState eq 'atRisk'
```

---

## 12. 2025-2026 NOTABLE CHANGES

- **Defender for Office 365 P1 now bundled in E3**: Previously a separate add-on.
- **Teams unbundled in EU**: "No Teams" SKU variants available in EU/EEA/Switzerland markets to comply with DSA.
- **Microsoft 365 E7 bundle**: New top-tier bundle at ~$99/user/month combining E5 + Copilot + Agent 365 (from May 2026).
- **Agent 365**: Autonomous agent platform; standalone at $15/user/month from May 2026.
- **Security Copilot in E5**: All E5 customers receive Security Copilot SCUs at no additional cost (400 SCU/1,000 E5 licenses, max 10,000 SCU/month).
- **Microsoft 365 Copilot Business**: New lower-cost SMB Copilot offering launched December 2025 for tenants under 300 users.
- **Entra Connect hard-match security hardening (June 2026)**: Block hard-matching to privileged cloud-only accounts.
- **Azure ACS retirement (April 2026)**: Apps using Azure Access Control Service stop working.
- **EA volume discount elimination (November 2025)**: Microsoft removed Level B-D EA discounts; all pay Level A list price.
- **Entra Cloud Sync**: Microsoft's stated future for hybrid sync; customers should plan migration from Entra Connect Sync.
- **Power Platform integration mandatory for F&O (May 2025)**: All Finance & Operations environments require Power Platform integration enabled.
- **Audit log retention add-on**: 10-year audit log retention available as a purchasable add-on for E5 customers.
- **Microsoft 365 Backup GA**: Native backup for SharePoint, OneDrive, Exchange (billed per GB/month via Syntex).

---

*Research compiled from Microsoft Learn documentation, Microsoft Tech Community, and specialist M365 publications. Current as of April 2026.*
