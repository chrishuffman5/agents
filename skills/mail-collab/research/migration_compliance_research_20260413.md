# Mail & Collaboration Platform: Migration Patterns and Compliance Research

**Research Date:** April 2026  
**Scope:** Exchange Online migration paths, cross-platform migration, coexistence patterns, M365 Purview compliance, Google Vault, regulatory frameworks, and backup strategies.

---

## PART 1: MIGRATION PATTERNS

---

### 1.1 Exchange to Exchange Online — Migration Type Selection

Microsoft provides four primary migration paths from on-premises Exchange to Exchange Online. The correct path depends on mailbox count, timeline, and ongoing coexistence requirements.

#### Decision Matrix

| Method | Mailbox Count | Exchange Version | Timeline | Directory Sync After? |
|---|---|---|---|---|
| Cutover | < 2,000 (recommended < 150) | 2003+ | Days | No |
| Staged | 2,000+ | 2003 or 2007 only | Weeks–months | Yes (temporary) |
| Minimal Hybrid (Express) | Any | 2010, 2013, 2016, 2019 | Weeks or less | No (one-time sync) |
| Full Hybrid | Any | 2010+ | Months–indefinite | Yes (ongoing) |

---

### 1.2 Cutover Migration (< 150 Mailboxes Practical Limit)

Cutover migration moves all mailboxes at once. Microsoft supports up to 2,000 mailboxes, but recommends fewer than 150 due to time constraints.

#### Pre-Migration Assessment

Before starting, verify:
- On-premises Exchange version (2003 or later required)
- Autodiscover DNS record resolves correctly
- Outlook Anywhere (RPC/HTTP) is enabled and accessible
- SSL certificate is valid on the on-premises Exchange server
- Admin credentials with appropriate Exchange permissions

Run connectivity test before creating endpoints:

```powershell
# Test migration server availability
$credentials = Get-Credential
$TSMA = Test-MigrationServerAvailability `
    -ExchangeOutlookAnywhere `
    -Autodiscover `
    -EmailAddress administrator@contoso.com `
    -Credentials $credentials

# View test results
$TSMA.ConnectionSettings
```

#### Step-by-Step: Cutover Migration via PowerShell

```powershell
# Step 1: Connect to Exchange Online PowerShell
Connect-ExchangeOnline -UserPrincipalName admin@contoso.onmicrosoft.com

# Step 2: Create migration endpoint using autodiscover results
New-MigrationEndpoint `
    -ExchangeOutlookAnywhere `
    -Name CutoverEndpoint `
    -ConnectionSettings $TSMA.ConnectionSettings

# Verify endpoint
Get-MigrationEndpoint CutoverEndpoint | Format-List EndpointType,ExchangeServer,UseAutoDiscover,Max*

# Step 3: Create and start the cutover migration batch
$SourceCredential = Get-Credential
New-MigrationBatch `
    -Name CutoverBatch `
    -SourceEndpoint CutoverEndpoint `
    -AutoStart `
    -AutoComplete

# Step 4: Monitor migration progress
Get-MigrationBatch CutoverBatch | Format-List Status,TotalCount,SyncedCount,FinalizedCount,FailedCount

# Step 5: Get per-mailbox status
Get-MigrationUser | Format-List Identity,Status,Error

# Step 6: Complete the batch after verifying mailboxes
Complete-MigrationBatch -Identity CutoverBatch

# Step 7: Update MX and Autodiscover DNS records (manual step)
# MX record: contoso-com.mail.protection.outlook.com
# Autodiscover CNAME: autodiscover.outlook.com

# Step 8: Delete migration batch after DNS TTL expires
Remove-MigrationBatch -Identity CutoverBatch
```

---

### 1.3 Staged Migration (Exchange 2003 / 2007)

Staged migration moves mailboxes in batches while maintaining coexistence. Requires Entra ID Connect for directory sync and is only supported for Exchange 2003 and 2007 source environments.

#### CSV File Format for Staged Migration

The CSV file requires an `EmailAddress` header column. Each row is one mailbox:

```
EmailAddress
user1@contoso.com
user2@contoso.com
user3@contoso.com
```

#### PowerShell Steps

```powershell
# Step 1: Create migration endpoint
New-MigrationEndpoint `
    -ExchangeOutlookAnywhere `
    -Name StagedEndpoint `
    -Autodiscover `
    -EmailAddress administrator@contoso.com `
    -Credentials (Get-Credential)

# Step 2: Create migration batch from CSV
New-MigrationBatch `
    -Name "Batch1-Finance" `
    -SourceEndpoint StagedEndpoint `
    -CSVData ([System.IO.File]::ReadAllBytes("C:\migration\batch1.csv")) `
    -TargetDeliveryDomain contoso.mail.onmicrosoft.com

# Step 3: Start the batch
Start-MigrationBatch -Identity "Batch1-Finance"

# Step 4: Monitor
Get-MigrationBatch "Batch1-Finance" | FL Status,*Count*

# Step 5: After verification, complete the batch
Complete-MigrationBatch -Identity "Batch1-Finance"

# Step 6: Convert on-premises mailboxes to mail-enabled users
# (Required after staged migration so mail routes to Exchange Online)
```

---

### 1.4 Minimal Hybrid Migration (Express Migration)

The minimal hybrid option (also called "express migration") is best for organizations that want to complete migration within a few weeks without maintaining long-term hybrid coexistence. Directory sync runs once, then is disabled.

**Limitations of Minimal Hybrid:**
- Does not support cross-premises Free/Busy sharing
- Does not support ongoing directory synchronization post-migration
- Best for Exchange 2010, 2013, 2016, or 2019 sources

#### Step-by-Step Process

1. **Verify domain** in Microsoft 365 admin center (Settings > Domains > Add domain)
2. **Download and run Exchange Hybrid Configuration Wizard** from M365 admin center (Setup > Migrations > Email > Get started)
3. In Hybrid Configuration Wizard, select **Minimal Hybrid Configuration**
4. Click **Update** to prepare on-premises mailboxes
5. **Run Microsoft Entra Connect** with Express Settings for one-time sync
6. **Assign licenses** to synchronized users in M365 admin center
7. **Start migration** from Setup > Data migration > Exchange
8. Monitor migration progress on the Data migration page
9. After migration completes, **update MX and Autodiscover DNS records**
10. Complete domain setup in M365 admin center

---

### 1.5 Full Hybrid Migration

Full hybrid supports ongoing coexistence with Free/Busy sharing, unified global address list, cross-premises mail routing, and long-term split-domain operation. Required for large enterprises or phased multi-year migrations.

**Full Hybrid Capabilities:**
- Cross-premises Free/Busy calendar sharing
- MailTips between on-premises and cloud users
- Cross-premises message tracking
- Shared namespace (both environments use @contoso.com)
- Move mailboxes in either direction (onboarding and offboarding)
- Online archive with on-premises primary mailbox

#### New-MoveRequest (Hybrid Remote Move)

In a full hybrid, use `New-MoveRequest` against the on-premises Exchange for remote moves:

```powershell
# Connect to on-premises Exchange PowerShell
# Then initiate remote move to Exchange Online

New-MoveRequest `
    -Identity "user@contoso.com" `
    -Remote `
    -RemoteHostName outlook.office365.com `
    -TargetDeliveryDomain contoso.mail.onmicrosoft.com `
    -RemoteCredential (Get-Credential) `
    -BadItemLimit 50 `
    -LargeItemLimit 10

# Check move request status
Get-MoveRequest -Identity "user@contoso.com" | Get-MoveRequestStatistics

# Move multiple mailboxes from CSV
$users = Import-Csv "C:\migration\users.csv"
foreach ($user in $users) {
    New-MoveRequest `
        -Identity $user.EmailAddress `
        -Remote `
        -RemoteHostName outlook.office365.com `
        -TargetDeliveryDomain contoso.mail.onmicrosoft.com `
        -RemoteCredential $cred `
        -BadItemLimit 50
}

# Monitor all move requests
Get-MoveRequest | Get-MoveRequestStatistics | Select DisplayName,Status,PercentComplete,BytesTransferred

# Suspend a move request
Suspend-MoveRequest -Identity "user@contoso.com"

# Resume a move request
Resume-MoveRequest -Identity "user@contoso.com"

# Remove completed move requests
Get-MoveRequest -MoveStatus Completed | Remove-MoveRequest
```

---

### 1.6 Exchange to Exchange Online with Entra ID Connect

#### Directory Synchronization Setup

Entra ID Connect (formerly Azure AD Connect) synchronizes on-premises Active Directory users to Entra ID (Azure AD), enabling hybrid identity for Exchange migration.

**Authentication Options Comparison:**

| Method | Description | Infrastructure Needed | SSO |
|---|---|---|---|
| Password Hash Sync (PHS) | Password hashes synced to cloud | Entra Connect only | Seamless SSO via Kerberos |
| Pass-Through Authentication (PTA) | Auth validated on-premises in real time | Entra Connect + PTA agents | Seamless SSO via Kerberos |
| Federation (AD FS) | Auth delegated to on-premises AD FS | AD FS + WAP servers | Full SSO via AD FS |

**Recommendation:** Password Hash Sync is the recommended option for most organizations. It is the simplest to implement, requires no additional servers beyond Entra Connect, and provides cloud-based authentication resilience. Federation (AD FS) is only recommended when hard authentication requirements (smart card, certificate) mandate it.

#### Key Entra ID Connect Configuration Commands

```powershell
# Install Entra ID Connect (Express Settings installs PHS by default)
# Run the installer and select "Express Settings" for small organizations
# or "Customize" for specific OU filtering, attribute mapping, etc.

# Verify sync status after installation
Get-ADSyncScheduler

# Force a delta sync cycle
Start-ADSyncSyncCycle -PolicyType Delta

# Force a full sync
Start-ADSyncSyncCycle -PolicyType Initial

# Check sync errors
Get-ADSyncToolsSourceAnchorDetails

# View connector space to see synchronized objects
Get-ADSyncConnectorRunStatus
```

#### Seamless SSO Configuration

Seamless SSO works with both PHS and PTA. It uses Kerberos to silently authenticate domain-joined machines without prompting for credentials.

```powershell
# Enable Seamless SSO through Entra Connect wizard
# Or enable via PowerShell after installation

Import-Module "C:\Program Files\Microsoft Azure Active Directory Connect\AzureADSSO.psd1"
New-AzureADSSOAuthenticationContext
Enable-AzureADSSO -Enable $true
```

---

### 1.7 Google Workspace to Microsoft 365 Migration

#### Pre-Migration Steps

1. **In Google Workspace Admin Console:**
   - Enable IMAP access for all users: Apps > Google Workspace > Gmail > End User Access > Enable IMAP
   - Set "Allow any mail client" (changes can take up to 24 hours)
   - Create a Google service account with domain-wide delegation for calendar/contacts migration
   - Generate app passwords if 2FA is enforced on admin accounts

2. **In Microsoft 365 Admin Center:**
   - Verify and add the custom domain
   - Create licensed mailboxes for all users (or use mail-enabled users)
   - Disable MRM/archival policies in Exchange Online before migration starts (prevents "missing items" errors)

3. **DNS Pre-Stage:**
   - Add Microsoft 365 TXT verification record
   - Create subdomain for mail routing to M365 (e.g., m365.contoso.com)
   - Create subdomain for mail routing back to Google (e.g., google.contoso.com)
   - Lower MX TTL to 300–600 seconds at least 24 hours before cutover

#### Google Workspace Migration via Exchange Admin Center (Automated)

The Migration Manager in the M365 admin center provides an automated path for mail, calendar, and contacts:

1. Go to Exchange Admin Center > Migration > Add migration batch
2. Select **Migration to Exchange Online** > **Google Workspace (Gmail) migration**
3. Enter Google service account credentials and project ID
4. Upload CSV file with user mappings (GoogleEmailAddress, ExchangeEmailAddress)
5. Configure pre-migration sync (recommended: start days before cutover)
6. Monitor migration batches in Exchange Admin Center

#### PowerShell-Based Google Workspace Migration

```powershell
# Connect to Exchange Online
Connect-ExchangeOnline -UserPrincipalName admin@contoso.onmicrosoft.com

# Create Google Workspace migration endpoint
New-MigrationEndpoint `
    -Gmail `
    -Name GWorkspaceMigEndpoint `
    -ServiceAccountKeyFileData ([System.IO.File]::ReadAllBytes("C:\migration\service-account-key.json")) `
    -EmailAddress admin@contoso.com

# Create migration batch from CSV
# CSV format: EmailAddress (Google), TargetEmailAddress (M365)
New-MigrationBatch `
    -Name "GWorkspace-Batch1" `
    -SourceEndpoint GWorkspaceMigEndpoint `
    -CSVData ([System.IO.File]::ReadAllBytes("C:\migration\gworkspace-batch1.csv")) `
    -TargetDeliveryDomain contoso.mail.onmicrosoft.com `
    -AutoStart

# Skip specific folders to reduce migration size
New-MigrationBatch `
    -Name "GWorkspace-Batch1" `
    -SourceEndpoint GWorkspaceMigEndpoint `
    -CSVData ([System.IO.File]::ReadAllBytes("C:\migration\gworkspace-batch1.csv")) `
    -ExcludeFolder "Spam","Trash" `
    -SkipRules `
    -AutoStart

# Monitor migration
Get-MigrationBatch "GWorkspace-Batch1" | FL Status,*Count*
Get-MigrationUser -BatchId "GWorkspace-Batch1" | FL Identity,Status,Error

# Complete batch after DNS cutover
Complete-MigrationBatch -Identity "GWorkspace-Batch1"
```

#### DNS Cutover Sequence

1. Change MX records to point to Microsoft 365 (`contoso-com.mail.protection.outlook.com`)
2. Update Autodiscover CNAME to `autodiscover.outlook.com`
3. Immediately run a delta/incremental sync to capture any messages that arrived during the DNS TTL period
4. Wait at least 72 hours before removing migration batches
5. Keep Google Workspace licenses active for 30 days post-cutover as a safety net

#### Drive to OneDrive Migration

Google Drive migration (files) uses Microsoft's SharePoint Migration Tool or Migration Manager in the M365 admin center:

1. In M365 Admin Center: Setup > Migration > Google Workspace
2. Connect to Google Workspace with service account credentials
3. Scan Google Drive for content (produces pre-migration report)
4. Map source (Google Drive users) to destination (OneDrive users)
5. Run migration; Shared Drives map to SharePoint Team Sites

**IMAP-Only Limitation:** IMAP migration migrates email only. For calendar and contacts, use the full Google Workspace migration tool (not IMAP) or export/import via CSV.

---

### 1.8 Microsoft 365 to Google Workspace Migration

#### Tools Available

- **Google Workspace Migration for Microsoft Exchange (GWMME):** Migrates mail, calendar, and contacts from Exchange/M365 to Google Workspace. Installed on a Windows server in the source environment.
- **Google Workspace Migrate:** Migrates files (SharePoint/OneDrive to Google Drive/Shared Drives). Requires a dedicated migration server.
- **Google Cloud Directory Sync (GCDS):** Syncs users, groups, and OUs from on-premises Active Directory to Google Workspace. Runs on a Windows server.

#### Directory Sync with GCDS

GCDS syncs from AD to Google Workspace (one-way). For cloud-only M365 with no on-premises AD, export users from M365 and create in Google Workspace via CSV or APIs.

```
# GCDS is configured via GUI tool, not PowerShell
# Key sync options:
#   - Organizational Units mapping
#   - User attribute mapping (displayName, email, manager)
#   - Group membership sync
#   - Deletion policy (suspend vs. delete users removed from AD)
```

#### Coexistence Period Configuration

During the migration, configure dual or split delivery:

- **Mail Routing:** Set up MX records to route mail to Google while configuring Google to relay mail destined for users still on M365 to the M365 tenant
- **Calendar Interoperability:** Google Calendar Interop allows free/busy visibility between Google Calendar and Exchange Online during coexistence
- **Global Address List Sync:** Use a third-party tool (e.g., Cloudiway) or GCDS with attribute mapping to maintain a consistent GAL during coexistence

#### GWMME Migration Process

1. Download and install GWMME on a Windows server with access to M365
2. Configure M365 app credentials (service account or OAuth)
3. Create a user mapping CSV file (M365 UPN → Google email)
4. Run a test migration for 2–3 users to validate
5. Execute migration in batches by department or OU
6. Validate calendar events, contacts, and mail in Google Workspace
7. Perform DNS cutover (MX to Google)

---

### 1.9 Tenant-to-Tenant Migration (M365)

Cross-tenant mailbox migration is used during mergers, acquisitions, or divestitures where two separate M365 tenants must be consolidated.

#### Licensing Requirement

A **Cross-Tenant User Data Migration** license (per-user, one-time fee) must be purchased and assigned before migration begins. Without this license, all migration attempts fail with a `CrossTenantMigrationWithoutLicensePermanentException` error.

Eligible plans: Microsoft 365 Business Basic/Standard/Premium, F1/F3/E3/E5, Office 365 F3/E1/E3/E5, Exchange Online, SharePoint, OneDrive, EDU.

#### Cross-Tenant Migration Setup

**Target Tenant Configuration (configure first):**

```powershell
# Step 1: Register migration app in Entra admin center (target tenant)
# - Navigate to entra.microsoft.com
# - App registrations > New registration
# - Set Supported account types: "Accounts in any organizational directory (Multi-tenant)"
# - Redirect URI: https://office.com
# - Add API permission: Office 365 Exchange Online > Application permissions > Mailbox.Migration
# - Grant admin consent
# - Create client secret and save the value

# Step 2: Connect to Exchange Online (target tenant)
Connect-ExchangeOnline -UserPrincipalName admin@targetcontoso.com

# Step 3: Create cross-tenant migration endpoint in target tenant
$AppId = "your-app-registration-client-id"
$AppSecret = "your-client-secret"
$SourceTenantId = "source-tenant-id"

New-MigrationEndpoint `
    -RemoteServer outlook.office.com `
    -RemoteTenant "sourcecontoso.onmicrosoft.com" `
    -ApplicationId $AppId `
    -AppSecretKeyVaultUrl $AppSecret `
    -Name CrossTenantEndpoint `
    -ExchangeRemoteMove

# Step 4: Create organization relationship in target tenant
New-OrganizationRelationship `
    -Name "CrossTenantRelationship" `
    -DomainNames "sourcecontoso.onmicrosoft.com" `
    -MailboxMoveEnabled $true `
    -MailboxMoveCapability Inbound
```

**Source Tenant Configuration:**

```powershell
# Connect to source tenant Exchange Online
Connect-ExchangeOnline -UserPrincipalName admin@sourcecontoso.com

# Step 1: Accept the migration application consent URL sent from target tenant
# URL format: https://login.microsoftonline.com/sourcecontoso.onmicrosoft.com/adminconsent
#             ?client_id=[target-app-id]&redirect_uri=https://office.com

# Step 2: Create organization relationship in source tenant
New-OrganizationRelationship `
    -Name "CrossTenantRelationship" `
    -DomainNames "targetcontoso.onmicrosoft.com" `
    -MailboxMoveEnabled $true `
    -MailboxMoveCapability RemoteOutbound

# Step 3: Create mail-enabled security group to scope migration
New-DistributionGroup `
    -Name "CrossTenantMigrationScope" `
    -GroupType Security `
    -Members "user1@sourcecontoso.com","user2@sourcecontoso.com"

# Step 4: Prepare source mailbox user attributes
# Get source mailbox ExchangeGuid and LegacyExchangeDN
Get-Mailbox "user1@sourcecontoso.com" | FL Name,ExchangeGuid,LegacyExchangeDN

# Step 5: In target tenant, create MailUser with required attributes
New-MailUser `
    -Name "User1" `
    -ExternalEmailAddress "user1@sourcecontoso.com" `
    -MicrosoftOnlineServicesID "user1@targetcontoso.onmicrosoft.com"

Set-MailUser "user1@targetcontoso.onmicrosoft.com" `
    -ExchangeGuid "[source-ExchangeGuid]" `
    -LegacyExchangeDN "[source-LegacyExchangeDN]"
```

**Executing the Cross-Tenant Migration:**

```powershell
# In target tenant: create and start migration batch
New-MigrationBatch `
    -Name "CrossTenantBatch1" `
    -SourceEndpoint CrossTenantEndpoint `
    -CSVData ([System.IO.File]::ReadAllBytes("C:\migration\cross-tenant-users.csv")) `
    -TargetDeliveryDomain "targetcontoso.mail.onmicrosoft.com" `
    -AutoStart

# Monitor migration
Get-MigrationBatch "CrossTenantBatch1" | FL Status,TotalCount,SyncedCount,FailedCount
Get-MigrationUser -BatchId "CrossTenantBatch1" | FL Identity,Status,Error

# After move: source mailbox becomes MailUser with targetAddress pointing to destination
```

**Important Note:** Mailboxes on any hold (Litigation Hold, eDiscovery hold, retention policy) cannot be migrated. All holds must be removed or handled before cross-tenant migration.

#### Cross-Tenant OneDrive Migration

OneDrive content can be migrated cross-tenant using the same Cross-Tenant User Data Migration license. The Microsoft Migration Orchestrator (preview as of December 2025) can orchestrate mailboxes, OneDrive, and Teams chat migrations together.

#### Domain Move

Moving an accepted domain from one tenant to another requires:
1. Removing the domain from the source tenant (requires removing all user UPNs and email addresses that use the domain)
2. Adding and verifying the domain in the target tenant
3. Updating all user objects in the target tenant to use the moved domain

---

### 1.10 Third-Party Migration Tools

#### When to Use Native Tools

Native Microsoft migration tools are appropriate when:
- Single platform-to-platform migration (Exchange on-premises to Exchange Online)
- Mailbox-only migration without complex SharePoint/Teams requirements
- Organization has adequate IT staff and migration experience
- Budget constraints favor free native tooling

#### When to Use Third-Party Tools

Use third-party tools for:
- Complex tenant-to-tenant migrations with overlapping domains
- Multi-platform migrations (Exchange + SharePoint + Teams + OneDrive in one orchestrated workflow)
- GAL sync and coexistence requirements
- Large-scale migrations requiring project management dashboards
- Migrations with strict SLA reporting requirements
- Organizations lacking dedicated Exchange/PowerShell expertise

#### Tool Comparison

**BitTitan MigrationWiz**
- Cloud-native SaaS tool; no on-premises infrastructure required
- Supports: Exchange, IMAP, Gmail, Office 365, OneDrive, Google Drive, Teams
- Best for: Email-focused migrations, Google Workspace to M365, and straightforward tenant-to-tenant
- Pricing: Per-mailbox license model
- Limitation: Less robust for complex AD identity scenarios and SharePoint migrations

**Quest On Demand Migration**
- Best for: Complex migrations with overlapping domains, GAL sync, AD identity migration
- Supports: Mailboxes, SharePoint, Teams, OneDrive, Active Directory, and hybrid coexistence
- Key capability: Domain move with mail coexistence; free/busy sharing during migration
- Pricing: Per-user subscription
- Ideal scenario: Mergers/acquisitions with AD consolidation requirements

**AvePoint**
- Best for: Large enterprises with strict governance and compliance requirements
- Supports: Exchange, SharePoint, Teams, OneDrive, Groups; also provides data management and governance post-migration
- Key capability: Automated migration policies, compliance reporting, multi-phase project orchestration
- Pricing: Subscription-based; add-on modules for governance/backup

**ShareGate**
- Best for: SharePoint and Microsoft 365 content migrations; permissions management
- Supports: SharePoint Online, OneDrive, Microsoft Teams, Microsoft 365 Groups
- Key capability: Granular permissions migration, content structure preservation, pre-migration scanning
- Limitation: Primarily SharePoint/Teams focused; not an email migration tool
- Pricing: Annual subscription per tenant

---

### 1.11 Coexistence Patterns

#### Split-Domain / Shared Namespace Routing

In a split-domain scenario, both on-premises Exchange and Exchange Online use the same SMTP domain (e.g., @contoso.com). Mail routing requires:

1. **Internal relay domain:** Exchange Online must be configured to relay messages for on-premises recipients through an on-premises Exchange server
2. **MX record:** During migration, MX can point to either on-premises (traditional approach) or Exchange Online (with on-premises servers relaying internally destined mail back to Exchange Online)
3. **Accepted domain type:** In Exchange Online, the shared domain must be configured as "Internal Relay" type, not "Authoritative"

```powershell
# Set shared namespace domain as Internal Relay in Exchange Online
Set-AcceptedDomain -Identity contoso.com -DomainType InternalRelay

# Configure send connector to route mail to on-premises for unresolved recipients
# (configured in Exchange Admin Center or via PowerShell)
New-SendConnector `
    -Name "To On-Premises" `
    -AddressSpaces "contoso.com" `
    -SmartHosts "mail.contoso.com" `
    -SmartHostAuthMechanism None `
    -RequireTLS $true
```

#### Free/Busy Sharing (Cross-Platform)

**Exchange On-Premises to Exchange Online (Full Hybrid):**
Free/busy is configured automatically by the Hybrid Configuration Wizard via an organization relationship. Requires OAuth authentication and the Availability service.

```powershell
# Verify organization relationship for free/busy
Get-OrganizationRelationship | FL Name,FreeBusyAccessEnabled,FreeBusyAccessLevel,DomainNames

# If needed, enable free/busy on existing relationship
Set-OrganizationRelationship `
    -Identity "On-premises to Office 365" `
    -FreeBusyAccessEnabled $true `
    -FreeBusyAccessLevel LimitedDetails
```

**Exchange Online to Google Workspace (Cross-Platform):**
Requires a third-party coexistence solution (e.g., Quest Coexistence Manager, Cloudiway) or Google Calendar Interop (for M365 to Google migrations). Native cross-platform free/busy is not available without third-party tools.

#### Global Address List Synchronization

During migration, maintaining a consistent GAL requires:
- **GCDS or Entra Connect:** For on-premises AD-based scenarios, syncing contact objects in both directions
- **Third-party tools:** Quest GalSync, Cloudiway Enterprise Coexistence for M365-to-Google migrations
- **Manual contact creation:** For smaller migrations, creating mail contacts in each system representing the other system's users

```powershell
# Create mail contact in Exchange Online to represent on-premises user during migration
New-MailContact `
    -Name "Jane Smith (On-Premises)" `
    -ExternalEmailAddress "jsmith@contoso.com" `
    -FirstName "Jane" `
    -LastName "Smith"

# Or, bulk-create contacts from CSV
Import-Csv "C:\migration\contacts.csv" | ForEach-Object {
    New-MailContact `
        -Name $_.Name `
        -ExternalEmailAddress $_.ExternalEmail `
        -DisplayName $_.DisplayName
}
```

---

## PART 2: COMPLIANCE AND GOVERNANCE

---

### 2.1 Microsoft Purview Compliance Solutions

Microsoft Purview (formerly Microsoft 365 Compliance) is the central compliance platform for Microsoft 365. Key components and their licensing requirements:

| Feature | E3 | E5 | Add-on Available? |
|---|---|---|---|
| Retention Policies (basic) | Yes | Yes | No |
| Sensitivity Labels | Yes | Yes | No |
| DLP (basic) | Yes | Yes | No |
| eDiscovery Standard | Yes | Yes | No |
| eDiscovery Premium | No | Yes | Yes (E5 add-on) |
| Audit Standard (90 days) | Yes | Yes | No |
| Audit Premium (1 year) | No | Yes | Yes |
| Communication Compliance | No | Yes | Yes |
| Information Barriers | No | Yes | Yes |
| Insider Risk Management | No | Yes | Yes |

---

### 2.2 Retention Policies and Labels

Retention policies apply to locations (mailboxes, SharePoint sites, Teams channels) and enforce "retain then delete," "retain only," or "delete only" behavior.

#### Create Retention Policy via PowerShell (Security & Compliance)

```powershell
# Connect to Security & Compliance PowerShell
Connect-IPPSSession -UserPrincipalName admin@contoso.com

# Create a retention policy for Exchange mailboxes (7-year retention for SOX)
New-RetentionCompliancePolicy `
    -Name "SOX-Email-7Year" `
    -ExchangeLocation All `
    -RetentionAction Keep `
    -RetentionDuration 2555 `
    -Comment "SOX compliance: retain all email for 7 years"

# Create the associated retention rule
New-RetentionComplianceRule `
    -Policy "SOX-Email-7Year" `
    -RetentionDuration 2555 `
    -RetentionComplianceAction Keep

# Create retention label for individual item-level control
New-ComplianceTag `
    -Name "HIPAA-PHI-7Year" `
    -RetentionAction Keep `
    -RetentionDuration 2555 `
    -RetentionType ModificationAgeInDays `
    -Comment "HIPAA PHI: retain 7 years from last modification"

# Auto-apply retention label based on sensitive info type
New-RetentionCompliancePolicy `
    -Name "AutoApply-HIPAA-PHI" `
    -ExchangeLocation All `
    -SharePointLocation All `
    -OneDriveLocation All

New-RetentionComplianceRule `
    -Policy "AutoApply-HIPAA-PHI" `
    -ApplyComplianceTag "HIPAA-PHI-7Year" `
    -ContentContainsSensitiveInformation @{Name="U.S. / U.K. Passport Number"; minCount="1"}
```

---

### 2.3 Sensitivity Labels

Sensitivity labels classify and protect content. Labels can apply encryption, content marking (headers/footers/watermarks), and access restrictions.

```powershell
# Create a sensitivity label
New-Label `
    -Name "Confidential-PHI" `
    -DisplayName "Confidential - PHI" `
    -Tooltip "Contains Protected Health Information" `
    -EncryptionEnabled $true `
    -EncryptionProtectionType Template `
    -EncryptionRightsDefinitions "admin@contoso.com:DONOTFORWARD"

# Create label policy to publish labels to users
New-LabelPolicy `
    -Name "HIPAA-Label-Policy" `
    -Labels "Confidential-PHI","Internal","Public" `
    -ExchangeLocation All `
    -Comment "Publish HIPAA-related sensitivity labels"
```

---

### 2.4 Data Loss Prevention (DLP)

DLP policies detect and protect sensitive information across M365 workloads.

```powershell
# Create DLP policy for credit card numbers
New-DlpCompliancePolicy `
    -Name "PCI-DSS-Credit-Card" `
    -ExchangeLocation All `
    -SharePointLocation All `
    -OneDriveLocation All `
    -TeamsLocation All `
    -Mode Enable

# Create DLP rule: block email with credit card numbers outside the org
New-DlpComplianceRule `
    -Policy "PCI-DSS-Credit-Card" `
    -Name "Block External Credit Card Sharing" `
    -ContentContainsSensitiveInformation @{Name="Credit Card Number"; minCount="1"} `
    -SentToScope NotInOrganization `
    -BlockAccess $true `
    -NotifyUser Owner `
    -GenerateIncidentReport SiteAdmin `
    -Priority 0

# Create DLP rule: warn for internal sharing of SSNs
New-DlpComplianceRule `
    -Policy "PCI-DSS-Credit-Card" `
    -Name "Warn Internal SSN Sharing" `
    -ContentContainsSensitiveInformation @{Name="U.S. Social Security Number (SSN)"; minCount="1"} `
    -NotifyUser Owner,LastModifier `
    -NotifyPolicyTipCustomText "This message contains a Social Security Number. Please verify before sending." `
    -Priority 1
```

---

### 2.5 eDiscovery (Post-August 2025 Unified Experience)

**Important:** As of August 31, 2025, Microsoft retired the classic eDiscovery experiences including classic Content Search, classic eDiscovery Standard, and classic eDiscovery Premium. All eDiscovery is now managed through the unified Microsoft Purview portal.

#### Key Supported PowerShell Cmdlets (Post-May 2025)

```powershell
# Connect to Security & Compliance PowerShell
Connect-IPPSSession -UserPrincipalName admin@contoso.com

# Create a compliance case (eDiscovery investigation)
New-ComplianceCase -Name "HR Investigation 2026-001" -CaseType eDiscovery

# Create a case hold policy
New-CaseHoldPolicy `
    -Name "HR-Case-Hold" `
    -Case "HR Investigation 2026-001" `
    -ExchangeLocation "user1@contoso.com","user2@contoso.com"

# Create the hold rule (what to preserve)
New-CaseHoldRule `
    -Name "HR-Case-Hold-Rule" `
    -Policy "HR-Case-Hold" `
    -ContentMatchQuery "From:manager@contoso.com AND subject:termination"

# Create a compliance search
New-ComplianceSearch `
    -Name "HR-Search-001" `
    -Case "HR Investigation 2026-001" `
    -ExchangeLocation "user1@contoso.com","user2@contoso.com" `
    -ContentMatchQuery "termination OR severance OR wrongful"

# Start the search
Start-ComplianceSearch -Identity "HR-Search-001"

# Check search status
Get-ComplianceSearch -Identity "HR-Search-001" | FL Status,Items,Size

# Export results
New-ComplianceSearchAction `
    -SearchName "HR-Search-001" `
    -Export `
    -Format FxStream `
    -Scope IndexedItemsOnly

# Search the audit log
Search-UnifiedAuditLog `
    -StartDate "2026-01-01" `
    -EndDate "2026-04-01" `
    -RecordType ExchangeItem `
    -UserIds "user1@contoso.com" `
    -ResultSize 5000
```

---

### 2.6 Audit Logging

**Audit Standard (E3):** 90-day audit log retention for most workloads.  
**Audit Premium (E5 or add-on):** 1-year retention, higher-value events (MailItemsAccessed, Send, SearchQueryInitiatedExchange), and 10-year retention with additional add-on license.

```powershell
# Check audit log retention policy
Get-AuditLogRetentionPolicy

# Create custom audit log retention policy (Audit Premium required)
New-AuditLogRetentionPolicy `
    -Name "Exchange-1Year-Retention" `
    -RecordTypes ExchangeItem,ExchangeAdmin `
    -RetentionDuration ThreeMonths `
    -Priority 1

# Search audit log for admin activities
Search-UnifiedAuditLog `
    -StartDate "2026-03-01" `
    -EndDate "2026-04-01" `
    -Operations "Set-Mailbox","New-InboxRule","Add-MailboxPermission" `
    -ResultSize 5000 | Export-Csv "C:\audit\admin-actions.csv"
```

---

### 2.7 Communication Compliance

Communication Compliance monitors internal and external communications for policy violations (harassment, regulatory compliance, inappropriate content). Requires E5 or add-on license.

**Configuration Steps:**

1. Assign Communication Compliance role in Microsoft Purview compliance portal
2. Create a policy: Purview > Communication Compliance > Policies > Create policy
3. Select policy template: Inappropriate text, Regulatory compliance, Conflict of interest, Custom
4. Define scope: All users, specific groups, or specific communication channels (Exchange, Teams, Viva Engage)
5. Set review percentage (sample size) and reviewers
6. Monitor alerts in the Communication Compliance dashboard

---

### 2.8 Information Barriers

Information Barriers prevent communication between defined segments (e.g., investment banking cannot communicate with research). Required for financial services regulatory compliance.

```powershell
# Connect to Security & Compliance PowerShell

# Step 1: Define organization segments
New-OrganizationSegment `
    -Name "InvestmentBanking" `
    -UserGroupFilter "Department -eq 'Investment Banking'"

New-OrganizationSegment `
    -Name "Research" `
    -UserGroupFilter "Department -eq 'Research'"

# Step 2: Create information barrier policies
New-InformationBarrierPolicy `
    -Name "IB-InvestmentBanking-Research" `
    -AssignedSegment "InvestmentBanking" `
    -SegmentsBlocked "Research" `
    -State Active

# Step 3: Apply all policies (processes ~5,000 users/hour)
Start-InformationBarrierPoliciesApplication

# Step 4: Check application status
Get-InformationBarrierPoliciesApplicationStatus
```

---

### 2.9 Insider Risk Management

Insider Risk Management detects potential data leakage, IP theft, and security violations. Requires E5 or add-on. Integrates with HR connector, DLP, and Communication Compliance.

**Policy Templates Available:**
- Data theft by departing users (requires HR connector with resignation/termination dates)
- Data leaks (requires at least one DLP policy configured)
- Data leaks by risky users
- Security policy violations
- Security policy violations by departing users
- Offensive language (integrates with Communication Compliance)

**Setup Steps:**

1. Configure Microsoft 365 HR connector (for departing user signals)
2. Enable Insider Risk Management in Purview compliance portal
3. Configure policy indicators (Settings > Policy indicators)
4. Create a policy (Policies > Create policy)
5. Select template, define users in scope, set indicator thresholds
6. Monitor alerts and conduct investigations in the Insider Risk dashboard

---

### 2.10 Exchange Compliance Features

#### Litigation Hold

Litigation Hold preserves all mailbox content (including deleted items and original versions of modified items) indefinitely or for a specified duration.

```powershell
# Enable Litigation Hold on a mailbox (indefinite)
Set-Mailbox -Identity "user@contoso.com" `
    -LitigationHoldEnabled $true `
    -LitigationHoldDuration Unlimited

# Enable with specific duration (e.g., 7 years = 2555 days)
Set-Mailbox -Identity "user@contoso.com" `
    -LitigationHoldEnabled $true `
    -LitigationHoldDuration 2555 `
    -LitigationHoldOwner "Legal Department" `
    -LitigationHoldDate (Get-Date)

# Check hold status for a mailbox
Get-Mailbox -Identity "user@contoso.com" | FL LitigationHoldEnabled,LitigationHoldDuration,InPlaceHolds

# Enable Litigation Hold for all mailboxes
Get-Mailbox -ResultSize Unlimited | Set-Mailbox -LitigationHoldEnabled $true

# Report: all mailboxes with any type of hold
Get-Mailbox -ResultSize Unlimited | Where-Object {$_.LitigationHoldEnabled -eq $true -or $_.InPlaceHolds -ne $null}
```

#### Retention Tags and Policies (Message Records Management)

Exchange MRM retention policies apply to mailbox items. Note: MRM coexists with Purview retention policies, but Purview policies take precedence for compliance holds.

```powershell
# Create retention tag - delete items after 3 years
New-RetentionPolicyTag `
    -Name "3-Year-Delete" `
    -Type All `
    -AgeLimitForRetention 1095 `
    -RetentionAction DeleteAndAllowRecovery

# Create retention tag - move to archive after 1 year
New-RetentionPolicyTag `
    -Name "1-Year-Archive" `
    -Type All `
    -AgeLimitForRetention 365 `
    -RetentionAction MoveToArchive

# Create retention policy and assign tags
New-RetentionPolicy `
    -Name "Standard-Email-Policy" `
    -RetentionPolicyTagLinks "3-Year-Delete","1-Year-Archive"

# Apply retention policy to all mailboxes
Get-Mailbox -ResultSize Unlimited | Set-Mailbox -RetentionPolicy "Standard-Email-Policy"
```

#### Journaling

Journaling captures copies of email messages to a dedicated journal mailbox or external archiving system. Required for certain regulatory frameworks (e.g., FINRA, SEC 17a-4).

```powershell
# Create journal rule for all messages (global journaling)
New-JournalRule `
    -Name "GlobalJournal" `
    -JournalEmailAddress "journal@contoso.com" `
    -Scope Global `
    -Enabled $true

# Create journal rule for specific recipients
New-JournalRule `
    -Name "FinanceJournal" `
    -JournalEmailAddress "journal@contoso.com" `
    -Recipient "finance-team@contoso.com" `
    -Scope Global `
    -Enabled $true

# View journal rules
Get-JournalRule
```

#### Transport Rules for Compliance

```powershell
# Add disclaimer to all outgoing messages
New-TransportRule `
    -Name "Legal-Disclaimer" `
    -SentToScope NotInOrganization `
    -ApplyHtmlDisclaimerText "<p>This email is confidential...</p>" `
    -ApplyHtmlDisclaimerLocation Append `
    -ApplyHtmlDisclaimerFallbackAction Wrap

# Block email with credit card numbers going external
New-TransportRule `
    -Name "Block-External-CC" `
    -MessageContainsDataClassifications @{Name="Credit Card Number"; minCount="1"} `
    -SentToScope NotInOrganization `
    -RejectMessageReasonText "Message blocked: potential credit card data detected"

# Encrypt messages sent to external recipients with sensitivity label
New-TransportRule `
    -Name "Encrypt-Confidential-External" `
    -HasClassification "Confidential" `
    -SentToScope NotInOrganization `
    -ApplyOME $true
```

---

### 2.11 Google Vault

Google Vault is Google Workspace's information governance and eDiscovery tool. It covers Gmail, Google Drive, Google Chat, Google Meet recordings, and Google Groups.

**Licensing (Updated November 2025):** Vault requires a dedicated Vault license for all admins performing compliance operations. Without a license, admins cannot search, hold, export data, or manage retention policies.

#### Retention Rules

Vault retention rules define how long data is kept before it is purged. Rules apply at the organizational unit level, not individual user level.

**Gmail Retention Rules:**
- Set by organizational unit
- Can filter by date range
- Can use search terms/queries (e.g., `label:^deleted` to target deleted mail)
- Expiration can be set in days from received/sent date

**Google Drive Retention Rules:**
- Set by organizational unit
- Expiration based on: last modified date, created date, trashed date, or Drive label date field
- Applies to My Drive, Shared Drives, and Shared-with-me content

**Configuration:** Vault admin console > Retention > Create rule (per service)

#### Holds (Matter-Based)

Holds preserve data for specific users indefinitely, overriding retention rules. Holds are created within "matters" (legal cases or investigations).

**Creating a Matter and Hold:**

1. In Google Vault admin console, navigate to Matters
2. Select Create new matter; enter name and description
3. Open the matter; select Holds > Create hold
4. Select service: Gmail, Drive, Groups, Chat, or Meet
5. Specify accounts or organizational units to hold
6. Set optional conditions (date ranges, search terms for Gmail/Chat holds)
7. Save the hold

**Hold Behavior:**
- Gmail: Holds all messages in the mailbox matching conditions; held messages cannot be permanently deleted even if the user deletes them
- Drive: Holds files owned by or shared with the held account; file versions are preserved
- Chat: Holds messages in spaces/DMs; preserved even after space deletion

#### eDiscovery: Search and Export

```
# All Vault eDiscovery is performed through the GUI at vault.google.com
# There is no PowerShell/CLI for Vault; operations use the Vault API or GUI

# Search process:
# 1. Create a matter (or use existing)
# 2. Create a search within the matter
# 3. Select service (Gmail, Drive, Chat, Meet, Groups)
# 4. Specify accounts, date ranges, and search terms
# 5. Run search; view estimated results
# 6. Export results to Google Drive or download as .zip

# Export format:
# Gmail: PST or MBOX format with metadata CSV
# Drive: Native file formats with metadata CSV
# Chat: JSON format
```

#### Vault Audit Trail

Vault automatically maintains an audit log of all admin actions (searches, holds, exports). Audit logs can be searched within Vault (Reports > Audit) and are also available in Google Workspace Admin Reports.

---

### 2.12 Regulatory Framework Compliance

#### GDPR (General Data Protection Regulation)

**Key Requirements for Email/Collaboration:**

1. **Data Subject Requests (DSR):** Organizations must respond within 30 days to requests for access, correction, portability, or erasure of personal data.
2. **Right to Erasure ("Right to be Forgotten"):** Must delete personal data from email systems, backups, and archives where no legal basis for retention exists.
3. **Data Minimization:** Only collect and retain email data that is necessary for the stated purpose.
4. **Cross-Border Data Transfers:** Ensure email data stored in M365 or Google Workspace complies with transfer mechanism requirements (Standard Contractual Clauses, adequacy decisions).

**GDPR DSR in Microsoft 365:**

```powershell
# Search for a data subject's content (Content Search - unified Purview portal)
New-ComplianceSearch `
    -Name "GDPR-DSR-JohnSmith" `
    -ExchangeLocation All `
    -SharePointLocation All `
    -OneDriveLocation All `
    -ContentMatchQuery "(From:john.smith@contoso.com) OR (To:john.smith@contoso.com) OR (Subject:'John Smith')"

Start-ComplianceSearch -Identity "GDPR-DSR-JohnSmith"

# For erasure: use Content Search + Purge action (requires Search And Purge role)
New-ComplianceSearchAction `
    -SearchName "GDPR-DSR-JohnSmith" `
    -Purge `
    -PurgeType SoftDelete
```

**Important GDPR Limitation:** Purge removes items from user-visible mailbox folders. Items held by Litigation Hold or eDiscovery hold cannot be purged. Organizations must determine whether a legal basis for retention overrides the erasure request.

#### HIPAA (Health Insurance Portability and Accountability Act)

**Requirements for Email Containing PHI:**

1. **Business Associate Agreement (BAA):** Must be signed with Microsoft before storing any PHI in M365. The BAA covers Exchange Online, SharePoint Online, OneDrive for Business, Teams, and other covered services under E3/E5 plans. Available through the Microsoft Products and Services Data Protection Addendum (DPA).

2. **Minimum Necessary:** Only send/store PHI that is necessary for the stated purpose.

3. **Encryption in Transit:** Exchange Online enforces TLS 1.2+ on all message transport. Verify Opportunistic TLS is configured and, for high-sensitivity routes, enforce TLS.

4. **Encryption at Rest:** Exchange Online encrypts mailbox data at rest using BitLocker. Organizations can add a second layer via Microsoft Purview Customer Key.

5. **Access Controls:** Implement RBAC, MFA, and conditional access to restrict access to PHI-containing mailboxes.

6. **Audit Logging:** Enable Audit Premium to maintain 1-year audit logs of mailbox access events (MailItemsAccessed event).

```powershell
# Configure TLS enforcement for a partner domain (HIPAA partner)
New-TransportRule `
    -Name "Enforce-TLS-HealthPartner" `
    -FromScope InOrganization `
    -SentTo "*@healthpartner.com" `
    -RouteMessageOutboundRequireTls $true

# Enable MailItemsAccessed audit (E5 or Audit Premium required)
Set-Mailbox -Identity "physician@hospital.org" -AuditEnabled $true
Set-Mailbox -Identity "physician@hospital.org" -AuditOwner @{Add="MailItemsAccessed"}
```

#### SOX (Sarbanes-Oxley Act)

**Email Retention Requirements:**
- Section 802 requires retention of all business records including electronic communications (email) for **7 years** minimum
- Records must be tamper-proof and accessible; immutable storage or journaling to a WORM-compliant archive is recommended
- First 2 years: records must be immediately accessible for audit purposes

**Implementation in M365:**
- Set Exchange retention policies to retain email for 7+ years (2,555+ days)
- Use Purview Compliance retention policies with "Retain and then delete" behavior (retain 7 years, then delete)
- Enable Preservation Lock on retention policies to make them immutable (prevents modification or deletion before expiry)
- Configure journaling to an external WORM-compliant archive (e.g., Proofpoint, Mimecast, Veritas Enterprise Vault)

```powershell
# Create 7-year SOX retention policy with Preservation Lock
New-RetentionCompliancePolicy `
    -Name "SOX-7Year-Immutable" `
    -ExchangeLocation All `
    -Enabled $true

New-RetentionComplianceRule `
    -Policy "SOX-7Year-Immutable" `
    -RetentionDuration 2555 `
    -RetentionComplianceAction Keep

# Apply Preservation Lock (IRREVERSIBLE — cannot be turned off once enabled)
Set-RetentionCompliancePolicy `
    -Identity "SOX-7Year-Immutable" `
    -RestrictiveRetention $true
```

#### PCI DSS (Payment Card Industry Data Security Standard)

**Email and Cardholder Data:**
- PCI DSS 4.0 (effective March 31, 2025) prohibits storing unprotected cardholder data (PAN) in email systems
- Organizations must have a policy prohibiting sending full card numbers via email
- Audit logs for cardholder data environment access: **12 months retention, 3 months immediately available**
- Implement DLP policies to detect and block emails containing credit card numbers

**Implementation:**
- Deploy DLP policy to detect and block outbound email containing Credit Card Number sensitive information type (see DLP section above)
- Configure DLP to notify senders and generate incident reports
- Implement email encryption for any legitimate payment-related communications
- Document email usage policies for cardholder data environments

---

### 2.13 Backup: Native Retention vs. Third-Party Solutions

#### Native Microsoft 365 Retention Windows

| Item Type | Default Retention | Maximum Native Retention |
|---|---|---|
| Exchange deleted items (Deleted Items folder) | 14 days | 30 days |
| Exchange soft-deleted items (Recoverable Items) | 14 days | 30 days |
| Exchange mailbox (after mailbox deletion) | 30 days | 30 days |
| SharePoint/OneDrive Recycle Bin (stage 1) | 93 days | 93 days |
| SharePoint/OneDrive Recycle Bin (stage 2) | 93 days total | 93 days total |
| Teams chat (without retention policy) | Indefinite | Indefinite |

**Key Gap:** Microsoft's native tools are not designed as backup solutions. They provide short-term recoverability but do not protect against:
- Accidental or malicious bulk deletion beyond the recovery window
- Ransomware that has encrypted/corrupted cloud data
- Misconfigured retention policies that delete data prematurely
- Insider threats that permanently delete data within the recovery window

#### Third-Party Backup Solutions

**Veeam Backup for Microsoft 365 / Veeam Data Cloud:**
- RPO: Backup every 5 minutes (lowest in industry for M365)
- Recovery options: 40+ granular recovery options including item-level, folder-level, and mailbox-level restore
- Default retention: 1 year (customizable to unlimited)
- Covers: Exchange Online, SharePoint Online, OneDrive for Business, Microsoft Teams
- Deployment: On-premises Veeam server with local/cloud repository, or fully managed Veeam Data Cloud SaaS

**Commvault Cloud Backup for Microsoft 365:**
- RPO: Configurable backup schedules; granular point-in-time recovery
- Recovery options: Item-level, in-place, out-of-place, self-service restore portal
- Multiple retention policies configurable at the mailbox level
- Covers: Exchange Online, SharePoint, OneDrive, Teams
- Feature: Automated backup with built-in extended storage

**Acronis Cyber Protect Cloud:**
- Combined backup and cybersecurity platform
- M365 backup with anti-malware scanning of backed-up data
- Granular restore for Exchange items, SharePoint documents, OneDrive files, Teams data
- Covers: Exchange Online, SharePoint Online, OneDrive, Teams

#### When to Use Third-Party Backup

Third-party backup is strongly recommended when:
- Regulatory requirements mandate point-in-time recovery beyond native retention windows
- Organization has experienced accidental bulk deletion previously
- Cyber insurance requires documented backup and recovery capabilities
- SLAs require RTO/RPO that native tools cannot meet (e.g., sub-hour recovery)
- Data sovereignty requirements mandate storing backups in a specific geography or on-premises

#### Recovery Point Objectives (RPO) Reference

| Solution | RPO | RTO (Item) | RTO (Mailbox) |
|---|---|---|---|
| Native Exchange Online (Deleted Items) | Real-time | Minutes | N/A |
| Native Exchange Online (soft-delete) | Real-time | Minutes | 30 days |
| Purview Retention Policy | Real-time | Hours (eDiscovery search) | Hours |
| Veeam Data Cloud | 5 minutes | Minutes | Minutes |
| Commvault Cloud | Configurable | Minutes | Minutes |
| Acronis Cyber Protect | Hourly typical | Minutes | Minutes |

---

## KEY REFERENCES

- [Exchange to Exchange Online migration paths](https://techcommunity.microsoft.com/blog/exchange/choosing-and-troubleshooting-exchange-online-mailbox-migrations/3977302)
- [Minimal Hybrid migration guide](https://learn.microsoft.com/en-us/exchange/mailbox-migration/use-minimal-hybrid-to-quickly-migrate)
- [New-MoveRequest cmdlet reference](https://learn.microsoft.com/en-us/powershell/module/exchange/new-moverequest?view=exchange-ps)
- [Google Workspace migration to Microsoft 365](https://learn.microsoft.com/en-us/exchange/mailbox-migration/perform-g-suite-migration)
- [Cross-tenant mailbox migration](https://learn.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide)
- [Microsoft Purview eDiscovery changes (May/August 2025)](https://techcommunity.microsoft.com/blog/microsoft-security-blog/upcoming-changes-to-microsoft-purview-ediscovery/4405084)
- [Microsoft Purview audit solutions overview](https://learn.microsoft.com/en-us/purview/audit-solutions-overview)
- [Information Barriers configuration](https://learn.microsoft.com/en-us/purview/information-barriers-policies)
- [Insider Risk Management setup](https://learn.microsoft.com/en-us/purview/insider-risk-management-configure)
- [Google Vault retention rules](https://support.google.com/vault/answer/2990828)
- [Google Vault holds management](https://support.google.com/vault/answer/3374023)
- [Microsoft GDPR DSR guidance](https://learn.microsoft.com/en-us/compliance/regulatory/gdpr-data-subject-requests)
- [HIPAA compliance for Microsoft 365](https://www.hipaajournal.com/microsoft-office-365-hipaa-compliant/)
- [SOX data retention requirements](https://pathlock.com/learn/sox-data-retention-requirements/)
- [PCI DSS 4.0 requirements overview](https://optro.ai/blog/pci-dss-requirements)
- [Veeam Backup for Microsoft 365](https://www.veeam.com/products/saas/backup-microsoft-office-365.html)
- [BitTitan vs Quest vs AvePoint comparison](https://nri-na.com/choosing-the-right-tenant-to-tenant-migration-tool/)
