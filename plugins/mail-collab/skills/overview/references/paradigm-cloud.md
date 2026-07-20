# Cloud Mail & Collaboration Paradigm

## When Cloud Mail Makes Sense

Cloud-managed email and collaboration is appropriate for the vast majority of organizations because:
- **HA/DR is built-in** -- Microsoft and Google manage infrastructure redundancy, patching, and disaster recovery
- **Feature velocity** -- New capabilities ship continuously without CU installations or downtime
- **Compliance certifications** are maintained by the provider (FedRAMP, HIPAA BAA, SOC 2, ISO 27001, GDPR)
- **Reduced operational overhead** -- No server hardware, no storage management, no OS patching
- **Integrated security** -- Defender for Office 365 (M365) or Gmail security (Google) included or add-on

Cloud mail is NOT appropriate when:
- Air-gapped or classified networks prohibit internet connectivity
- Regulatory mandates explicitly require on-premises data custody with no cloud exception
- Custom high-volume transactional mail processing exceeds cloud platform rate limits

## Microsoft 365 / Exchange Online

### Tenant Architecture

A Microsoft 365 tenant is a dedicated, isolated Entra ID instance that underpins all M365 services. One tenant, multiple services: Exchange Online, SharePoint, Teams, OneDrive, Intune, Defender, Purview.

**Key identifiers:**
- Tenant GUID (globally unique)
- Default domain: `tenant.onmicrosoft.com`
- Custom verified domains (e.g., `contoso.com`)

**Data isolation:** Strict tenant isolation at the platform layer. No cross-tenant data access by default.

### Exchange Online Service

- **Mailbox sizes:** 50 GB (E1/Business Basic), 100 GB (E3/E5), unlimited auto-expanding archive (E3/E5)
- **Protocols:** MAPI over HTTPS (primary), EWS (legacy), IMAP/POP3 (disableable), SMTP relay
- **Mailbox types:** User, Shared (no license for basic use), Resource (Room/Equipment), Discovery
- **Microsoft 365 Groups:** Modern collaboration unit with shared mailbox, calendar, SharePoint site, Teams team

### Identity Integration

**Authentication options:**
- **Cloud-only:** All accounts in Entra ID, no on-premises AD
- **Password Hash Sync (PHS):** Hash of password hash synced to cloud. Simplest hybrid option. Recommended default.
- **Pass-through Authentication (PTA):** Auth forwarded to on-prem AD agent in real time
- **Federation (AD FS):** Auth redirected to on-prem AD FS. Most complex, only for hard requirements (smart card/cert)

**Microsoft Entra Connect Sync:** Installed on domain member server, delta sync every 30 minutes.

**Microsoft Entra Cloud Sync:** Lightweight agents, cloud-managed configuration. Microsoft's recommended direction for new deployments.

### M365 Compliance (Microsoft Purview)

| Capability | E3 | E5 |
|---|---|---|
| Retention policies | Yes | Yes |
| Sensitivity labels (basic) | Yes | Yes |
| DLP (basic) | Yes | Yes |
| eDiscovery Standard | Yes | Yes |
| Auto-labeling | No | Yes |
| eDiscovery Premium | No | Yes |
| Insider Risk Management | No | Yes |
| Communication Compliance | No | Yes |
| Audit (Premium, 1-year retention) | No | Yes |

### M365 Security (Defender for Office 365)

**Plan 1** (Business Premium, E3 as of 2026): Safe Attachments, Safe Links, anti-phishing with impersonation protection

**Plan 2** (E5): Plan 1 + Attack Simulation Training, Automated Investigation & Response (AIR), Threat Explorer, Campaign Views

### M365 Admin Centers

| Portal | URL | Primary Scope |
|---|---|---|
| Microsoft 365 Admin Center | `admin.microsoft.com` | Users, groups, licenses, billing, service health |
| Exchange Admin Center | `admin.exchange.microsoft.com` | Mailboxes, mail flow, connectors, migration |
| Security (Defender) | `security.microsoft.com` | Threat protection, email security policies |
| Purview Compliance | `purview.microsoft.com` | Retention, DLP, eDiscovery, audit |
| Entra ID | `entra.microsoft.com` | Identity, Conditional Access, PIM, app registrations |
| SharePoint Admin | `<tenant>-admin.sharepoint.com` | Sites, sharing, storage |
| Teams Admin | `admin.teams.microsoft.com` | Teams policies, voice, devices |

### M365 Management Tools

**PowerShell:**
- `ExchangeOnlineManagement` module for Exchange Online (`Connect-ExchangeOnline`)
- `Microsoft.Graph` module for Entra ID, users, groups, licensing
- `Connect-IPPSSession` for Security & Compliance (labels, DLP, eDiscovery)

**Microsoft Graph API:** Unified REST API surface for all M365 data. Base URL: `https://graph.microsoft.com/v1.0/`. Supports delegated and application permissions.

**Microsoft 365 CLI:** Cross-platform CLI (`npm install -g @pnp/cli-microsoft365`) for M365 admin from any shell.

---

## Google Workspace

### Account Architecture

A Google Workspace account (tenant) is identified by a primary domain and maps 1:1 to a Google Cloud organization resource. Supports up to 600 domains (primary + alias + secondary).

**Organizational Units (OUs):** Hierarchical containers for users and policy assignment. Users belong to exactly one OU. Settings inherit downward, overridable per child OU.

**Cloud Identity integration:** Google Workspace automatically provisions a Cloud Identity Premium account, enabling GCP console access, IAM policies, and Context-Aware Access.

### Gmail Service

Enterprise Gmail features beyond consumer:
- **Hosted S/MIME:** Admin uploads certificates; auto-encrypt between S/MIME parties
- **Client-side encryption (CSE):** Customer-held keys via external KMS. Enterprise Plus only.
- **Advanced Phishing and Malware Protection:** Pre-delivery scanning, intra-domain auth checks
- **Confidential Mode:** Sender-set expiration, disable forwarding/downloading (not true E2EE)
- **GWSMO:** Syncs Gmail/Calendar/Contacts to Outlook desktop

### Google Vault

Information governance and eDiscovery. Included with Business Plus and Enterprise plans.

| Function | Description |
|---|---|
| Retention rules | Set by OU, service, or search query. Duration: 1-36,500 days |
| Legal holds | Preserve data indefinitely regardless of retention rules |
| Search | Query by user, OU, date, keyword across Gmail, Drive, Chat, Groups, Voice |
| Export | MBOX (mail), PST, or native format |
| Audit trail | All Vault actions logged for chain-of-custody |

**Services covered:** Gmail (including deleted/spam), Google Drive, Chat, Groups, Voice, Meet recordings.

### Google Workspace Licensing

| Plan | Storage/User | Vault | Advanced DLP | Context-Aware Access | Data Regions |
|---|---|---|---|---|---|
| Business Starter | 30 GB | No | No | No | No |
| Business Standard | 2 TB | Add-on | No | No | No |
| Business Plus | 5 TB | Yes | No | No | No |
| Enterprise Standard | 5 TB | Yes | Yes | Yes | Yes |
| Enterprise Plus | 5 TB | Yes | Yes | Yes | Yes |

### Identity Integration

**GCDS (Google Cloud Directory Sync):** Reads from on-prem AD/LDAP and syncs users, groups, OUs to Google Workspace. Does not sync passwords (use SAML SSO).

**Entra ID SCIM Provisioning:** Push users from Entra ID to Google Workspace in near-real-time. Alternative to GCDS for organizations using Entra ID as identity source.

**SSO:** Google Workspace supports SAML SP mode (third-party IdP authenticates). Entra ID, Okta, Ping are common IdPs.

### Admin Console

URL: `admin.google.com`

Key administration areas:
- **Directory:** Users, OUs, groups, devices
- **Apps:** Service-level configuration (Gmail, Drive, Meet, Chat)
- **Security:** 2SV enforcement, API controls, DLP, Context-Aware Access
- **Reporting:** Audit logs, usage reports, email log search, alerts center
- **Account:** Data regions, Vault, billing

### Management Tools

**GAM (Google Workspace Admin Manager):** Open-source CLI for bulk administration.

```bash
# List all users
gam print users

# Create user
gam create user jdoe@example.com firstname Jane lastname Doe password TempPass123 changepassword on

# Bulk update from CSV
gam csv users.csv gam update user ~email suspended off
```

**Admin SDK API:** REST API for programmatic administration (Directory, Reports, License Manager, Groups Settings).

**Apps Script:** JavaScript-based automation within Google Workspace services.

---

## Cloud Platform Comparison

### Migration Path Selection

| Source --> Target | Recommended Tool | Scope |
|---|---|---|
| Exchange on-prem --> M365 | Hybrid migration (HCW + MRS) | Mail, calendar, contacts |
| Google Workspace --> M365 | Native M365 migration endpoint | Mail, calendar, contacts |
| M365 --> Google Workspace | GWMME + GCDS | Mail, calendar, contacts |
| M365 --> M365 (T2T) | Cross-tenant mailbox migration + third-party | Full mailbox |
| IMAP source --> M365 | IMAP migration batch | Email only |
| IMAP source --> Google | GWMME or Google Workspace Migrate | Email only |

### Cloud-to-Cloud Coexistence

During migration between M365 and Google Workspace:
- **DNS split:** MX routes to the target platform; transport rules or connectors forward mail for unmigrated users back to source
- **Calendar interop:** Limited. Free/busy sharing between M365 and Google requires third-party connectors or manual configuration
- **Directory coexistence:** Use GCDS or SCIM to keep both directories in sync during transition
- **Lower MX TTL** to 300 seconds at least 48 hours before cutover

### Data Residency

**M365 Multi-Geo:** Store data in multiple geographies within a single tenant. Set `PreferredDataLocation` per user. Exchange mailbox auto-migrates when PDL changes.

**Google Workspace Data Regions:** Pin covered data to US or EU at the OU level. Business or Enterprise plan required.

### Backup Strategy

Neither Microsoft nor Google provides true backup. Native capabilities (recycle bins, Recoverable Items, Vault) protect against accidental deletion but not ransomware, admin error, or mass deletion.

**Recommendation:** Deploy third-party backup (Veeam, Acronis, Druva, Commvault) for Exchange mailboxes, SharePoint/OneDrive, Teams, and Google Workspace data. Store backup data outside the primary cloud tenant.
