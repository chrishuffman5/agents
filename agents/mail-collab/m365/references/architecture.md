# Microsoft 365 Architecture Deep Reference

## Tenant Model

A Microsoft 365 tenant is a dedicated, isolated instance of Microsoft Entra ID. One tenant underpins all M365 services: Exchange Online, SharePoint, Teams, OneDrive, Intune, Defender, Purview, and Power Platform.

**Key properties:**
- Globally unique GUID
- One or more verified domain names (default: `tenant.onmicrosoft.com`)
- Directory stores users, groups, devices, service principals, applications
- Strict data isolation between tenants at the platform layer
- Workforce tenant (default) vs. External tenant (B2C scenarios)

## Entra ID Integration

Entra ID is the identity backbone for M365. Every authentication and authorization event flows through Entra ID.

**Authentication endpoints:** `https://login.microsoftonline.com/<tenant-id>/v2.0` (OpenID Connect / OAuth 2.0)

**Token issuance:** JWT access tokens scoped to M365 resource APIs (`https://graph.microsoft.com`, `https://outlook.office365.com`)

**Conditional Access:** Every service checks token claims against CA policies before granting access.

## Service Endpoints

| Service | Primary Endpoint |
|---|---|
| Microsoft Graph API | `https://graph.microsoft.com/v1.0/` (stable) / `/beta/` |
| Exchange Online (EWS) | `https://outlook.office365.com/EWS/Exchange.asmx` |
| SharePoint Online | `https://<tenant>.sharepoint.com` |
| Teams | `https://teams.microsoft.com` (client), Graph API (backend) |
| M365 Admin Center | `https://admin.microsoft.com` |
| Security portal | `https://security.microsoft.com` |
| Purview portal | `https://purview.microsoft.com` |
| Entra ID portal | `https://entra.microsoft.com` |
| Power Platform admin | `https://admin.powerplatform.microsoft.com` |

Microsoft publishes required URLs/IP ranges at `https://endpoints.office.com/endpoints/worldwide` (JSON feed, updated monthly).

## Microsoft Graph API

Unified REST API for all M365 data. Consolidates EWS, SharePoint CSOM, and other legacy APIs.

**Base URL:** `https://graph.microsoft.com/v1.0/` (production) or `/beta/` (preview)

**Key resources:**
- `/users` -- Accounts, profiles, mail, calendar, files
- `/groups` -- M365 Groups, security groups, distribution lists
- `/devices` -- Entra ID registered/joined devices
- `/sites` -- SharePoint sites and content
- `/teams` -- Teams and channels
- `/security` -- Alerts, incidents, secure scores
- `/compliance` -- Purview data

**Authentication:** OAuth 2.0 with delegated (user context) or application (service context) permissions.

**Graph PowerShell SDK:**
```powershell
# Interactive
Connect-MgGraph -Scopes "User.Read.All", "Group.ReadWrite.All"

# Device code (headless)
Connect-MgGraph -Scopes "User.Read.All" -UseDeviceAuthentication

# App-only with certificate (recommended for automation)
Connect-MgGraph -ClientId $appId -TenantId $tenantId -CertificateThumbprint $thumbprint
```

---

## Identity Architecture

### Cloud-Only Identity

All accounts exist solely in Entra ID. Best for new cloud-first organizations.

### Hybrid Identity with Entra Connect Sync

Synchronizes on-premises AD objects to Entra ID:
- Installed on domain member server (not DC)
- Delta sync every 30 minutes, full sync as scheduled
- **Password Hash Sync (PHS):** Hash of password hash synced to cloud. Sign-in works even if on-prem unavailable.
- **Pass-through Authentication (PTA):** Auth request forwarded to on-prem agent in real time
- **Federation (AD FS):** Auth redirected to on-prem AD FS. Most complex.

```powershell
# Check sync status (on Entra Connect server)
Import-Module ADSync
Get-ADSyncScheduler

# Force delta sync
Start-ADSyncSyncCycle -PolicyType Delta

# Force full sync
Start-ADSyncSyncCycle -PolicyType Initial
```

### Entra Cloud Sync (Future Direction)

Lightweight provisioning agents (multiple for HA) installed on-prem. Configuration managed entirely in cloud. Microsoft recommends for new deployments.

### Conditional Access

Zero Trust policy engine evaluating signals (user, device, location, app, risk) and enforcing controls (MFA, device compliance, session restrictions).

**Policy anatomy:**
- **Assignments:** Users/groups, cloud apps, conditions (platform, location, sign-in risk)
- **Access controls:** Grant (block, require MFA, require compliant device), Session (sign-in frequency, app-enforced restrictions)

### Privileged Identity Management (PIM)

Just-In-Time privileged access. Requires Entra ID P2.

- **Eligible assignment:** User requests activation for limited time
- **Active assignment:** Always active (minimize these)
- **Activation:** Can require MFA, justification, approval, ticket number
- **Time-bound:** Roles expire automatically

```powershell
# Get active role assignments
Get-MgRoleManagementDirectoryRoleAssignment | Select RoleDefinitionId, PrincipalId

# Get eligible PIM assignments
Get-MgRoleManagementDirectoryRoleEligibilitySchedule | Select PrincipalId, RoleDefinitionId, Status
```

### Identity Protection (P2)

- **Sign-in risk:** Real-time risk score (anonymous IP, atypical travel, malware-linked IP)
- **User risk:** Cumulative risk (leaked credentials, etc.)
- **Risk-based CA:** Require MFA for medium risk, block for high risk

---

## Core Services

### Exchange Online

- Mailbox types: User (licensed), Shared (no license up to 50 GB), Resource (Room/Equipment)
- Sizes: 50 GB (E1), 100 GB (E3+), unlimited archive (E3/E5)
- Protocols: MAPI over HTTPS (primary), EWS (legacy), IMAP/POP3 (disableable)
- Message trace: Up to 10-day detailed, 90-day summary
- Connectors: Inbound/outbound for partner routing, smart host, third-party appliances

### SharePoint Online

- Structure: Tenant > Site Collections > Sites > Libraries/Lists
- Site types: Communication (broadcast), Team (collaboration, M365 Group-backed), Hub (navigation)
- Storage: 1 TB base + 10 GB per licensed user
- Sharing: Tenant-level and site-level controls (anonymous, external authenticated, internal only)

### Microsoft Teams

- Data storage: Chat in Exchange Online, files in SharePoint/OneDrive, meetings in Azure Media Services
- Channel types: Standard, Private (separate SharePoint site), Shared (cross-tenant)
- Direct Routing: Bring your own telephony (SBC to PSTN)
- Calling Plans: Microsoft-provided PSTN by country

### OneDrive for Business

- Quota: 1 TB per user (expandable to 5 TB+)
- Known Folder Move (KFM): Policy-redirect Desktop/Documents/Pictures to OneDrive
- Retention after deletion: 30 days default (configurable to 180 days)

---

## Data Residency

### Single-Geo (Default)

All data stored in geography selected at provisioning. View in Admin Center: Settings > Org settings > Data location.

### Multi-Geo

Store data in multiple geographies within a single tenant:
- Requires Multi-Geo licenses (5% of eligible users minimum)
- One primary geo + satellite geos
- Per-user `PreferredDataLocation` controls Exchange mailbox, Teams chat, OneDrive location
- Exchange mailbox auto-migrates when PDL changes

```powershell
# Set preferred data location
Set-MgUser -UserId "user@contoso.com" -PreferredDataLocation "EUR"
```

---

## Admin Center Map

### Microsoft 365 Admin Center (`admin.microsoft.com`)

- User and group management
- Domain management (add, verify, set primary)
- Billing and subscriptions
- Service health dashboard
- Message Center (planned changes, deprecations)
- Reports (usage, adoption)

### Exchange Admin Center (`admin.exchange.microsoft.com`)

- Mailbox management, distribution groups
- Mail flow rules, connectors
- Anti-spam/anti-malware policies
- Message trace
- Public folders, migration batches

### Microsoft Defender Portal (`security.microsoft.com`)

- Incidents and alerts
- Threat hunting (Advanced Hunting, KQL)
- Threat Explorer, email reports
- Safe Attachments/Links policies
- Attack Simulation Training
- Secure Score

### Microsoft Purview (`purview.microsoft.com`)

- Sensitivity labels (Information Protection)
- DLP policies
- Retention policies and labels
- Records management
- eDiscovery (Standard and Premium)
- Audit log search
- Communication Compliance
- Insider Risk Management

### Entra Admin Center (`entra.microsoft.com`)

- Conditional Access policies
- Identity Protection
- PIM
- Enterprise Applications, SSO
- App registrations
- Hybrid identity (Connect, Cloud Sync)
- Authentication methods (MFA, FIDO2, passwordless)
