# Microsoft Exchange Server 2019 & Exchange Online — Comprehensive Research Document

**Research compiled:** April 2026  
**Scope:** Exchange Server 2019, Exchange Server SE (Subscription Edition), Exchange Online, Hybrid Deployment, Migration, Compliance, and Management

---

## 1. ARCHITECTURE OVERVIEW

### 1.1 Server Role Consolidation

Exchange Server 2019 (and 2016) use a two-role model that eliminated the separate Client Access Server (CAS) role from Exchange 2013 and earlier:

- **Mailbox Server** — The single on-premises role. Contains:
  - Transport services (Front End Transport, Transport, Mailbox Transport)
  - Mailbox databases (via Managed Store)
  - Client Access services (frontend proxy layer for MAPI, HTTPS, IMAP, POP, SMTP)
  - The Exchange Admin Center (EAC) web interface
- **Edge Transport Server** — Deployed in the perimeter/DMZ. Optional. Handles all inbound/outbound SMTP with antispam agents. Not a member of Active Directory; subscribes via EdgeSync.

The philosophy is "every server is an island" — communication between Exchange servers happens at the protocol layer only, preventing cross-layer contamination and isolating failures.

### 1.2 Client Access Protocol Architecture

Clients never connect directly to backend mailbox services. The Client Access (frontend) layer on each Mailbox server acts as a stateless proxy:

1. Client connects to Client Access service (e.g., `mail.contoso.com` via HTTPS/MAPI over HTTP)
2. Client Access service proxies the request to the backend service on the Mailbox server holding the active database copy
3. Backend service accesses the mailbox database via RPC

**Protocol-to-backend mapping:**
- HTTP clients → HTTP proxy (SSL-encrypted with self-signed cert between frontend/backend)
- IMAP/POP clients → IMAP/POP proxy
- SMTP (client submission) → SMTP on port 587

**MAPI over HTTP** is the default connection protocol for Outlook in Exchange 2019, replacing the legacy Outlook Anywhere (RPC over HTTP). MAPI over HTTP provides better connection resilience and per-user control.

### 1.3 Transport Pipeline

The transport pipeline is a collection of services and queues that route all messages through the categorizer. Three services exist on each Mailbox server:

#### Front End Transport Service
- Listens on port 25 for inbound external SMTP
- Stateless proxy — inspects no message content, queues nothing
- Default Receive connector: `Default Frontend <ServerName>` (port 25)
- Outbound proxy connector: `Outbound Proxy Frontend <ServerName>`
- Routes to Transport service on the same or another Mailbox server

#### Transport Service (Hub Transport)
- Equivalent to the Hub Transport role in Exchange 2010
- Performs all message categorization, routing resolution, content conversion
- Applies mail flow rules (transport rules) via the Transport Rule agent
- Implements shadow redundancy and Safety Net
- Never communicates directly with mailbox databases (that is Mailbox Transport's job)
- Default Receive connectors: `Default <ServerName>` (port 2525 from Frontend) and `Client Frontend <ServerName>` (port 587 for authenticated client submission)

#### Mailbox Transport Service
Two sub-services:
- **Mailbox Transport Submission** — Retrieves messages from mailbox DB via Exchange RPC, submits to Transport service via SMTP
- **Mailbox Transport Delivery** — Receives messages from Transport service via SMTP, delivers to mailbox DB via RPC

**Message flow (inbound, no Edge Transport):**
```
Internet → Frontend Receive connector (port 25)
         → Transport service (categorizer, transport rules)
         → Mailbox Transport Delivery
         → Mailbox database (via RPC)
```

**Message flow (outbound, no Edge Transport):**
```
Mailbox database (via RPC) → Mailbox Transport Submission
                           → Transport service
                           → Send connector → Internet
                           (or via Frontend outbound proxy)
```

#### Transport High Availability
- **Shadow Redundancy** — The Transport service keeps redundant copies of in-transit messages. If the next-hop server fails before acknowledging delivery, the shadow copy is resubmitted.
- **Safety Net** — After delivery, the Transport service retains copies of successfully delivered messages in a Safety Net queue for a configurable period (default: 2 days). If a database failover occurs and replay is needed, Safety Net can resubmit recently delivered messages.

Shadow redundancy and Safety Net together mean Exchange "guarantees" message redundancy regardless of the capabilities of the sending server.

### 1.4 Managed Store and MCDB

The **Managed Store** is the Exchange storage engine that replaced the legacy ESE-based store in Exchange 2013+. In Exchange 2019, the Managed Store introduced the **MetaCache Database (MCDB)**:

- MCDB stores frequently accessed metadata and items on solid-state storage (SSD/NVMe)
- Acts as a read/write cache layer in front of the traditional HDD-based ESE database
- Reduces disk I/O latency significantly for active mailbox operations
- 5–10% of total database storage capacity should be allocated as SSD for MCDB
- Traditional HDD to SSD ratio recommendation: **3:1** (three traditional disks per one SSD)
- If an SSD fails, Exchange HA automatically moves affected database copies to DAG nodes with healthy MCDB resources; if no healthy MCDB exists, the database continues running without MCDB benefits

**Search improvements in Exchange 2019:** The local search instance reads from the local mailbox database copy directly, eliminating coordination with active copies. Bandwidth requirements between active and passive copies reduced by ~40% compared to Exchange 2016.

---

## 2. DATABASE AVAILABILITY GROUPS (DAG)

### 2.1 DAG Fundamentals

A **Database Availability Group (DAG)** is the core high-availability mechanism in Exchange Server. Key characteristics:

- Up to **16 Mailbox servers** per DAG
- Provides automatic database-level failover (database, server, network failures)
- Built on Windows Failover Clustering; the cluster is dedicated to the DAG (no other workloads)
- **Active Manager** runs on every DAG member; manages switchovers and failovers
- A DAG is also a **transport high availability boundary**

### 2.2 Creating a DAG

```powershell
# DAG with cluster administrative access point
New-DatabaseAvailabilityGroup -Name DAG1 -WitnessServer EX-WITNESS `
    -WitnessDirectory C:\DAGWitness\DAG1 `
    -DatabaseAvailabilityGroupIPAddresses 10.0.0.5,192.168.0.5

# DAG without cluster administrative access point (recommended for Exchange 2019)
New-DatabaseAvailabilityGroup -Name DAG1 -WitnessServer EX-WITNESS `
    -DatabaseAvailabilityGroupIPAddresses ([System.Net.IPAddress]::None)

# Add members
Add-DatabaseAvailabilityGroupServer -Identity DAG1 -MailboxServer EX01
Add-DatabaseAvailabilityGroupServer -Identity DAG1 -MailboxServer EX02
Add-DatabaseAvailabilityGroupServer -Identity DAG1 -MailboxServer EX03
Add-DatabaseAvailabilityGroupServer -Identity DAG1 -MailboxServer EX04

# Configure filesystem (ReFS recommended)
Set-DatabaseAvailabilityGroup -Identity DAG1 -FileSystem ReFS
```

**DAGs without an administrative access point** (no IP, no CNO in AD, not registered in DNS) are recommended for Exchange 2016/2019. They simplify configuration and reduce attack surface. Must be managed via PowerShell against individual cluster members.

### 2.3 Quorum Models

| DAG Size | Quorum Mode | Description |
|----------|-------------|-------------|
| Even number of members | Node and File Share Majority | Uses witness server as tie-breaker vote |
| Odd number of members | Node Majority | No witness needed; each member votes |

For a 4-member DAG with witness server: 5 total voters; at least 3 must communicate to maintain quorum. Maximum of 2 simultaneous voter failures tolerated.

**Witness server placement:**
- Best: Third location isolated from both primary datacenters (enables automatic datacenter failover)
- Acceptable: Azure VM as witness server
- Minimum: One of the two datacenters (disables automatic failover for that datacenter's failure)

Exchange Server does **not** support Windows Server 2016's Cloud Witness feature.

### 2.4 Database Copies and Lagged Copies

**Preferred Architecture database copy layout:**
- 4 copies per database (2 in each datacenter of a site-resilient pair)
- 3 copies configured as highly available (ActivationPreference 1–3)
- 1 copy configured as a **lagged database copy** (highest ActivationPreference)

```powershell
# Add a database copy
Add-MailboxDatabaseCopy -Identity DB01 -MailboxServer EX02 -ActivationPreference 2

# Add a lagged copy (7-day replay lag)
Add-MailboxDatabaseCopy -Identity DB01 -MailboxServer EX04 `
    -ReplayLagTime 7.0:0:0 -TruncationLagTime 0.0:0:0 -ActivationPreference 4

# Check database copy status
Get-MailboxDatabaseCopyStatus -Identity DB01\* | Select Name, Status, CopyQueueLength, ReplayQueueLength

# Check replication health
Test-ReplicationHealth -Server EX01
```

**Lagged copy purpose:** Protects against catastrophic logical corruption (e.g., accidental bulk deletion). Not intended for individual mailbox item recovery. The Replay Lag Manager dynamically plays down logs when HA availability is compromised.

### 2.5 AutoReseed

AutoReseed automatically restores database redundancy after a disk failure:

```powershell
# Configure AutoReseed
Set-DatabaseAvailabilityGroup -Identity DAG1 -AutoDagAutoReseedEnabled $true `
    -AutoDagDiskReclaimerEnabled $true `
    -AutoDagTotalNumberOfServers 8 `
    -AutoDagTotalNumberOfDatabases 48

# Disk layout: reserve at least 1 HDD as hot spare per server
# AutoReseed activates spare, initiates reseed of affected database copies
```

### 2.6 Preferred Architecture Storage Design

| Disk Role | Type | Format | Notes |
|-----------|------|--------|-------|
| OS + Exchange Binaries | RAID1 pair | NTFS | Transport DB also here |
| Mailbox Databases + Logs | HDD (7.2K SAS), JBOD | ReFS (integrity disabled) | Up to 4 DB copies per disk |
| MCDB | SSD (SAS or M.2 NVMe) | ReFS | 5–10% of total DB storage; 3:1 HDD:SSD ratio |
| Hot Spare | HDD | — | At least 1 per server for AutoReseed |

**Example 20-drive server layout:**
- 2 HDDs: OS mirror
- 12 HDDs: Exchange database storage (10 TB each = 120 TB total)
- 1 HDD: AutoReseed spare
- 4 SSDs: MCDB (7.68 TB ≈ 6.4% of 120 TB, within 5–10% target)
- 1 optional spare SSD

**BitLocker** encryption is used on all data disks for data-at-rest protection.

### 2.7 Network Design

The Preferred Architecture uses a **single non-teamed network interface** for both client traffic and DAG replication. This simplifies the network stack and produces a standard recovery model: whether a network or server failure occurs, the outcome is the same — another database copy activates.

DAG network latency requirements: Round-trip latency between DAG members must not exceed **250 ms**.

---

## 3. EXCHANGE SERVER 2019 — DEPLOYMENT AND LIFECYCLE

### 3.1 End of Support Timeline

| Version | End of Support | Status (as of April 2026) |
|---------|----------------|--------------------------|
| Exchange 2019 | October 14, 2025 | End of Support reached |
| Exchange 2016 | October 14, 2025 | End of Support reached |
| Exchange SE (Subscription Edition) | Ongoing (subscription) | Current supported version |

Microsoft stopped issuing security patches, bug fixes, time zone updates, and technical support for Exchange 2019 after October 14, 2025.

**Extended Security Updates (ESU):** Microsoft announced an ESU program for customers running Exchange 2019 CU14 or CU15 who cannot complete migration before end of support. ESU provides continued security patches for a limited period at additional cost.

### 3.2 Cumulative Update Requirements

- Exchange 2019 must be on **CU14 or CU15** to be eligible for ESU
- Exchange 2019 **CU15** is essentially the same codebase as **Exchange Server SE RTM**
- **Windows Server 2019** is the minimum supported OS; **Windows Server 2022** is recommended; **Windows Server 2025** is supported starting with Exchange 2019 CU15 / Exchange SE
- .NET Framework 4.8.x required
- Exchange setup requires Schema extensions and AD preparation (`Setup.exe /PrepareSchema`, `/PrepareAD`, `/PrepareDomain`)

```powershell
# Check Exchange build version
Get-ExchangeServer | Select Name, AdminDisplayVersion, Edition

# Check installed CU
(Get-ExchangeServer).AdminDisplayVersion
# Example output: Version 15.2 (Build 1118.40) = Exchange 2019 CU15
```

### 3.3 Exchange Server Subscription Edition (SE)

Released Q3 2025, Exchange Server SE is the successor to Exchange 2019. Key points:

- **Licensing:** Annual subscription model replaces perpetual licensing
- **Codebase:** RTM is functionally identical to Exchange 2019 CU15 (same build, different EULA and build number)
- **OS Support:** Windows Server 2019, 2022, 2025
- **TLS:** TLS 1.2 and 1.3 only by default; TLS 1.0/1.1 and legacy ciphers (DES, 3DES, RC2, RC4, MD5) disabled
- **Removed:** Unified Messaging was removed in Exchange 2019 (not in SE). Coexistence with Exchange 2013 removed in SE.
- **Future CU1+ features:** Kerberos authentication for server-to-server, new admin API, removal of Outlook Anywhere (RPC over HTTP)

Upgrade path from Exchange 2019 to SE: In-place upgrade supported from Exchange 2019 CU14/CU15.

---

## 4. EDGE TRANSPORT SERVER

### 4.1 Architecture and Role

The Edge Transport server is deployed in the **perimeter network (DMZ)**, isolated from the internal Active Directory. It provides:

- SMTP relay and smart host services for all internet-bound/inbound mail
- Antispam filtering (Connection Filtering, Sender ID, Content Filtering, Recipient Filtering, Sender Reputation)
- Antimalware scanning (basic; not the full Malware Filter Agent from Mailbox servers)
- Mail flow rules (edge-specific subset of transport rule conditions)
- Attachment filtering

**EdgeSync** synchronizes recipient data and configuration from internal AD to the Edge Transport AD LDS (Active Directory Lightweight Directory Services) instance. Once the Edge Subscription is created, objects like accepted domains, remote domains, and Send connectors are managed internally and pushed via EdgeSync.

```powershell
# Subscribe an Edge Transport server
New-EdgeSubscription -FileName "C:\EdgeSubscription.xml"
# (Run on Edge server, copy XML to Mailbox server, then:)
New-EdgeSubscription -FileData ([byte[]]$(Get-Content -Path "C:\EdgeSubscription.xml" -Encoding Byte -ReadCount 0)) `
    -Site "Default-First-Site-Name"

# Force EdgeSync
Start-EdgeSynchronization

# Verify EdgeSync status
Test-EdgeSynchronization -Server EX-EDGE01
```

### 4.2 Antispam Agents on Edge Transport

| Agent | Function |
|-------|----------|
| Connection Filtering | IP block/allow lists, real-time block lists (RBLs) |
| Sender ID | Validates sending domain's SPF record |
| Content Filtering | SCL (Spam Confidence Level) rating based on content analysis |
| Recipient Filtering | Rejects mail to non-existent recipients, blocked recipients |
| Sender Filtering | Blocks specific senders/domains |
| Sender Reputation | Assigns SRL (Sender Reputation Level); auto-blocks high-SRL senders |
| Attachment Filtering | Filters by attachment name, MIME type, or file size |

---

## 5. EXCHANGE ONLINE ARCHITECTURE

### 5.1 Tenant and Mailbox Architecture

Exchange Online operates as a multi-tenant service distributed across Microsoft's global datacenter network. Key characteristics:

- Each tenant has a dedicated **Exchange Online organization** with isolated mailbox databases
- Mailboxes are hosted on highly available infrastructure with multiple copies (Microsoft manages HA transparently)
- **Autodiscover** uses DNS to direct clients to their mailbox server via `https://autodiscover.outlook.com/autodiscover/autodiscover.xml`
- **Primary SMTP namespace** is `tenant.onmicrosoft.com`; custom domains are added as accepted domains

**Mailbox types in Exchange Online:**

| Mailbox Type | Description | License Required |
|--------------|-------------|-----------------|
| User Mailbox | Standard mailbox for a licensed user | Yes |
| Shared Mailbox | Up to 50 GB without license; no login required | No (up to 50 GB) |
| Resource Mailbox | Room or Equipment mailbox for scheduling | No |
| Room Mailbox | Conference room with auto-accept/decline | No |
| Equipment Mailbox | Non-location resource (projector, vehicle) | No |
| Discovery Mailbox | Target for eDiscovery searches | No |

**Mailbox Plans (Exchange Online Plans):**

| Plan | Included In | Mailbox Size | Archive |
|------|-------------|-------------|---------|
| Exchange Online Plan 1 | M365 Business Basic/Standard | 50 GB | Add-on |
| Exchange Online Plan 2 | M365 E3/E5 | 100 GB | Unlimited auto-expanding |
| Exchange Online Kiosk | F1/F3 | 2 GB | No |

### 5.2 Microsoft 365 Groups vs. Distribution Groups

- **Distribution Groups:** Traditional SMTP-only groups; no shared mailbox, calendar, or files
- **Mail-Enabled Security Groups:** Distribution group with AD security group capabilities
- **Microsoft 365 Groups:** Modern collaboration unit. Each group gets a shared mailbox, calendar, SharePoint site, Teams team (if connected), and Planner. Managed in AAD/Entra ID.

```powershell
# Connect to Exchange Online PowerShell (modern auth)
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com

# Create a shared mailbox
New-Mailbox -Shared -Name "Help Desk" -DisplayName "Help Desk" `
    -Alias helpdesk -PrimarySmtpAddress helpdesk@contoso.com

# Convert user mailbox to shared
Set-Mailbox -Identity user@contoso.com -Type Shared

# Create a room mailbox
New-Mailbox -Room -Name "Conference Room A" `
    -PrimarySmtpAddress confrooma@contoso.com

# Set room auto-accept
Set-CalendarProcessing -Identity confrooma@contoso.com `
    -AutomateProcessing AutoAccept -AddOrganizerToSubject $true
```

---

## 6. EXCHANGE ONLINE PROTECTION (EOP) AND DEFENDER FOR OFFICE 365

### 6.1 Exchange Online Protection (EOP)

EOP is the cloud-based filtering service included with **all** Exchange Online subscriptions. It processes every message flowing into the organization:

**EOP filtering pipeline (inbound):**
1. **Connection filtering** — Checks sender IP against IP Allow List, IP Block List, and safe list (Microsoft intelligence). Most spam stopped here.
2. **Anti-malware** — Multi-engine malware scanning. Infected attachments quarantined or stripped.
3. **Mail flow rules (transport rules)** — Evaluated before anti-spam
4. **Anti-spam filtering** — Assigns SCL (Spam Confidence Level) -1 to 9; applies bulk complaint level (BCL) for newsletters
5. **Anti-phishing** — Impersonation detection, spoof intelligence, mailbox intelligence

**EOP policy components:**

| Policy Type | Key Settings |
|-------------|-------------|
| Anti-spam (inbound) | SCL thresholds, quarantine vs. Junk, allow/block lists |
| Anti-spam (outbound) | Outbound limits, automatic forwarding restrictions |
| Anti-malware | Safe Attachments behavior, admin notifications |
| Anti-phishing | Impersonation protection, spoof intelligence threshold |
| Quarantine policies | User quarantine access, notifications |

```powershell
# View anti-spam policies
Get-HostedContentFilterPolicy | Select Name, SpamAction, HighConfidenceSpamAction

# View anti-phishing policies
Get-AntiPhishPolicy | Select Name, EnableMailboxIntelligence, EnableSpoofIntelligence

# Check quarantine
Get-QuarantineMessage -RecipientAddress user@contoso.com | Select Subject, SenderAddress, QuarantineTypes

# Release from quarantine
Release-QuarantineMessage -Identity <MessageIdentity> -ReleaseToAll
```

### 6.2 Email Authentication (SPF, DKIM, DMARC)

**SPF (Sender Policy Framework):**
- DNS TXT record listing authorized sending IPs for a domain
- Exchange Online automatically adds Microsoft's SPF include: `include:spf.protection.outlook.com`
- Example: `v=spf1 include:spf.protection.outlook.com -all`

**DKIM (DomainKeys Identified Mail):**
- Exchange Online signs outbound messages with a 2048-bit RSA key per domain
- Requires two CNAME records published in DNS:
  - `selector1._domainkey.contoso.com → selector1-contoso-com._domainkey.contoso.onmicrosoft.com`
  - `selector2._domainkey.contoso.com → selector2-contoso-com._domainkey.contoso.onmicrosoft.com`

```powershell
# Enable DKIM for a domain
Set-DkimSigningConfig -Identity contoso.com -Enabled $true

# Check DKIM status
Get-DkimSigningConfig -Identity contoso.com | Select Domain, Status, Selector1CNAME, Selector2CNAME
```

**DMARC (Domain-based Message Authentication, Reporting & Conformance):**
- DNS TXT record at `_dmarc.contoso.com`
- Example: `v=DMARC1; p=reject; rua=mailto:dmarc-reports@contoso.com; ruf=mailto:dmarc-forensics@contoso.com; pct=100`
- Best practice: Start with `p=none` (monitor), move to `p=quarantine`, then `p=reject`
- EOP evaluates DMARC and honors `p=reject` for inbound messages

**Important:** Do not use allowlists/safelists that bypass SPF, DKIM, DMARC protections.

### 6.3 Microsoft Defender for Office 365

Defender for Office 365 adds advanced threat protection on top of EOP:

| Feature | Plan 1 | Plan 2 |
|---------|--------|--------|
| Safe Attachments | Yes | Yes |
| Safe Links | Yes | Yes |
| Anti-phishing (advanced) | Yes | Yes |
| Real-time detections | Yes | — |
| Threat Explorer | — | Yes |
| Automated Investigation & Response (AIR) | — | Yes |
| Attack Simulation Training | — | Yes |
| Threat Trackers | — | Yes |
| Campaign Views | — | Yes |

**Included in:** MDO Plan 1 in M365 Business Premium; MDO Plan 2 in M365 E5/A5/GCC G5.

**Safe Attachments:** Detonates suspicious attachments in a sandbox before delivering to the user. Policies can be set to Block, Replace, or Dynamic Delivery (delivers email body immediately, replaces attachment with placeholder while scanning).

**Safe Links:** Rewrites URLs at click-time; re-evaluates destination URL against threat intelligence at the moment of click, not delivery time.

---

## 7. HYBRID DEPLOYMENT

### 7.1 Hybrid Configuration Wizard (HCW)

The **Hybrid Configuration Wizard** is the primary tool for establishing Exchange hybrid deployments. It configures:

- TLS-encrypted **Send and Receive connectors** for secure cross-premises mail flow
- **OAuth** (Open Authorization) for cross-premises features (eDiscovery, In-Place Archive, MRM)
- **Organization relationships** for free/busy calendar sharing
- **Migration endpoints** for mailbox moves
- **Accepted domain sharing** between on-premises and Exchange Online

Download: `https://aka.ms/hybridwizard`

**HCW Topology Options:**

| Mode | Description |
|------|-------------|
| Classic Hybrid | Full feature set; requires published AutoDiscover, EWS, ActiveSync, MAPI, OAB endpoints |
| Minimal Hybrid | Subset of features; faster to deploy; uses Hybrid Agent |
| Hybrid Agent | Microsoft-managed cloud agent; no firewall inbound rules required; does NOT support Hybrid Modern Authentication |

**Prerequisites:**
- Exchange 2016 CU8+ or Exchange 2019 (any CU) on-premises
- Azure AD Connect (Entra ID Connect) configured for directory synchronization
- Microsoft 365/Exchange Online tenant
- Valid third-party TLS certificate (not self-signed) on the Exchange server
- Autodiscover, EWS, and MAPI endpoints externally accessible (Classic Hybrid)

**What HCW configures:**

```powershell
# Verify hybrid configuration after HCW
Get-HybridConfiguration

# Check send connectors created by HCW
Get-SendConnector | Where {$_.Name -like "*Hybrid*"} | Select Name, AddressSpaces, SmartHosts

# Check organization relationship (free/busy)
Get-OrganizationRelationship | Select Name, Enabled, FreeBusyAccessEnabled, MailTipsAccessEnabled
```

**HCW log location:** `%ExchangeInstallPath%Logging\Update-HybridConfiguration`

### 7.2 Free/Busy and Calendar Sharing

In hybrid deployments, free/busy data is shared via the federation trust or OAuth:

- On-premises users can see Exchange Online users' calendar availability
- Exchange Online users can see on-premises users' availability
- **Availability Address Space** is configured automatically by HCW

```powershell
# Test free/busy from on-premises
Test-OrganizationRelationship -UserIdentity onpremuser@contoso.com `
    -Identity "Exchange Online" -Verbose

# Get availability address space
Get-AvailabilityAddressSpace | Select ForestName, AccessMethod, ProxyUrl
```

### 7.3 Cross-Premises Mail Routing

**Centralized Mail Transport:** All outbound internet email from Exchange Online routes back through on-premises servers. Preferred when on-premises compliance appliances or journaling is required.

**Decentralized (Direct):** Exchange Online sends internet mail directly. Simpler; recommended unless compliance requirements dictate otherwise.

Cross-premises mail is treated as internal (no antispam applied, secure TLS connector).

### 7.4 Hybrid Modern Authentication (HMA)

HMA enables on-premises Exchange users to authenticate using Azure AD (Entra ID) tokens:

- Requires Classic Hybrid topology (not Hybrid Agent)
- Requires Azure AD Connect (not pass-through only)
- Requires published Autodiscover, EWS, and MAPI endpoints
- Must be configured via PowerShell (`Set-OrganizationConfig -OAuth2ClientProfileEnabled $true`)
- Enables multi-factor authentication and Conditional Access for on-premises mailboxes

---

## 8. MIGRATION

### 8.1 Migration Methods Comparison

| Method | Source | Max Mailboxes | Downtime | Notes |
|--------|--------|--------------|----------|-------|
| Cutover | Exchange on-prem | ~2,000 | High (DNS cutover) | Single batch; all mailboxes at once |
| Staged | Exchange 2003/2007 | Unlimited | Low | Requires DirSync; deprecated for newer versions |
| Hybrid (Full) | Exchange on-prem | Unlimited | Minimal | Requires hybrid deployment; best for large orgs |
| Minimal Hybrid | Exchange on-prem | Any | Minimal | Simplified; no full hybrid features |
| IMAP | Any IMAP source | Unlimited | None | Email only; no calendar/contacts |
| PST Import | Any | Unlimited | None | Network upload or drive shipping |
| Google Workspace | Google | Unlimited | Low | Native EAC wizard or manual PowerShell |
| Cross-Tenant | M365 tenant | Unlimited | Low | M365 to M365; requires consent on both tenants |

### 8.2 Hybrid Migration (Full)

The most common enterprise migration path. Mailboxes move online via **New-MoveRequest** (on-prem PowerShell) or **New-MigrationBatch** (Exchange Online PowerShell):

```powershell
# On-premises: Move single mailbox to Exchange Online
New-MoveRequest -Identity user@contoso.com -Remote -RemoteHostName mail.contoso.com `
    -TargetDeliveryDomain contoso.mail.onmicrosoft.com `
    -RemoteCredential (Get-Credential) -BadItemLimit 50

# Check move request status
Get-MoveRequest -Identity user@contoso.com | Select Status, PercentComplete, BytesTransferred

# Exchange Online: Create migration batch for multiple mailboxes
New-MigrationBatch -Name "Wave1-Migration" `
    -SourceEndpoint (Get-MigrationEndpoint -Identity "HybridMigrationEndpoint") `
    -CSVData ([System.IO.File]::ReadAllBytes("C:\Wave1.csv")) `
    -AutoStart -AutoComplete -BadItemLimit 50 -LargeItemLimit 10

# Start migration batch
Start-MigrationBatch -Identity "Wave1-Migration"

# Monitor migration batch
Get-MigrationBatch -Identity "Wave1-Migration" | Select Status, TotalCount, SyncedCount, FailedCount

# Get per-user migration status
Get-MigrationUser -BatchId "Wave1-Migration" | Select EmailAddress, Status, PercentComplete, Error

# Complete migration batch (triggers final sync + DNS cutover ready)
Complete-MigrationBatch -Identity "Wave1-Migration"
```

**Migration endpoint setup:**
```powershell
# Create migration endpoint for hybrid
New-MigrationEndpoint -ExchangeRemoteMove -Name "HybridMigrationEndpoint" `
    -RemoteServer mail.contoso.com `
    -Credentials (Get-Credential)

# Test migration endpoint
Test-MigrationServerAvailability -ExchangeRemoteMove `
    -RemoteServer mail.contoso.com -Credentials (Get-Credential)
```

### 8.3 Cutover Migration

Used for small organizations (< 2,000 mailboxes) migrating directly from Exchange to Exchange Online. All mailboxes move in a single batch:

```powershell
# Create migration endpoint for cutover
New-MigrationEndpoint -ExchangeOutlookAnywhere -Name "CutoverEndpoint" `
    -ExchangeServer mail.contoso.com -Credentials (Get-Credential) -EmailAddress admin@contoso.com

# Create cutover migration batch
New-MigrationBatch -Name "CutoverBatch" -SourceEndpoint "CutoverEndpoint" `
    -AutoStart

# After migration, update MX records to point to Exchange Online
# Complete and remove batch
Complete-MigrationBatch -Identity "CutoverBatch"
Remove-MigrationBatch -Identity "CutoverBatch" -Confirm:$false
```

### 8.4 IMAP Migration

Migrates email only from any IMAP-compatible source to Exchange Online:

```powershell
# Create IMAP migration endpoint
New-MigrationEndpoint -IMAP -Name "IMAPEndpoint" `
    -RemoteServer imap.sourcedomain.com -Port 993 -Security Ssl

# Create IMAP migration batch (CSV: EmailAddress, UserName, Password)
New-MigrationBatch -Name "IMAPBatch" -SourceEndpoint "IMAPEndpoint" `
    -CSVData ([System.IO.File]::ReadAllBytes("C:\IMAPUsers.csv")) `
    -AutoStart
```

### 8.5 Google Workspace to Exchange Online

Native migration is supported directly from the Exchange Admin Center:

**Prerequisites:**
1. Add a subdomain in Google Workspace Admin as a routing domain (e.g., `o365.contoso.com`)
2. Create a Google Service Account with domain-wide delegation
3. Grant the service account `https://mail.google.com/` scope
4. In Exchange Online, create a migration endpoint pointing to Gmail

**Limitations:**
- Gmail labels migrate as folders
- Rules migrate but are disabled by default (users must review before enabling)
- Use `-ExcludeFolder` parameter to skip large or unwanted labels

```powershell
# Create Google Workspace migration endpoint
New-MigrationEndpoint -Gmail -Name "GoogleEndpoint" `
    -ServiceAccountKeyFileData ([System.IO.File]::ReadAllBytes("C:\GoogleServiceAccount.json")) `
    -EmailAddress admin@contoso.com

# Create migration batch
New-MigrationBatch -Name "GoogleBatch" -SourceEndpoint "GoogleEndpoint" `
    -CSVData ([System.IO.File]::ReadAllBytes("C:\GoogleUsers.csv")) `
    -TargetDeliveryDomain contoso.mail.onmicrosoft.com -AutoStart
```

### 8.6 Cross-Tenant Migration (M365 to M365)

Used in mergers, acquisitions, or tenant consolidations:

```powershell
# Source tenant: Create application and grant consent
# Target tenant: Configure organization relationship

# Establish cross-tenant relationship (Target tenant)
New-OrganizationRelationship -Name "CrossTenantRelationship" `
    -DomainNames "sourcetenant.onmicrosoft.com" `
    -MailboxMoveEnabled $true -MailboxMoveCapability Inbound

# Create migration batch (Target tenant)
New-MigrationBatch -Name "CrossTenantBatch" -SourceEndpoint "CrossTenantEndpoint" `
    -CSVData ([System.IO.File]::ReadAllBytes("C:\CrossTenantUsers.csv")) -AutoStart
```

**Note:** As of February 2025, Microsoft deprecated the Application Impersonation RBAC role in Exchange Online. Third-party migration tools (BitTitan, Quest) must use the new Microsoft Graph API permissions model instead.

### 8.7 Third-Party Migration Tools

| Tool | Vendor | Key Features |
|------|--------|-------------|
| MigrationWiz | BitTitan | Cloud-based; supports Exchange, IMAP, Google; project-based UI |
| On Demand Migration (ODM) | Quest Software | M365-to-M365 cross-tenant; public folders; OneDrive |
| Binary Tree (now Quest) | Quest | Enterprise Exchange migrations; Active Directory migration |
| AvePoint Fly | AvePoint | Teams, SharePoint, Exchange; M365 to M365 |
| CodeTwo Office 365 Migration | CodeTwo | Exchange-to-Exchange; lightweight; calendar/contacts |
| SkyKick | SkyKick | MSP-focused; automated migration projects |

**Important for BitTitan (2025):** MigrationWiz suspended the Hybrid Exchange Management license purchase as of June 2025. Hybrid migration support via MigrationWiz ended September 30, 2025.

---

## 9. MAIL FLOW FEATURES AND COMPLIANCE

### 9.1 Mail Flow Rules (Transport Rules)

Transport rules evaluate messages in transit and apply actions. Available in both on-premises (EMS/EAC) and Exchange Online (EAC/PowerShell):

**Rule components:**
- **Conditions** — What triggers the rule (sender, recipient, subject, attachment, SCL, message size, etc.)
- **Exceptions** — Exclusions from the condition
- **Actions** — What to do (redirect, reject, add disclaimer, set SCL, apply rights protection, etc.)
- **Priority** — Lower number = higher priority; rules processed in order

```powershell
# Create a transport rule to add a disclaimer
New-TransportRule -Name "External Disclaimer" `
    -SentToScope NotInOrganization `
    -ApplyHtmlDisclaimerText "<p><b>DISCLAIMER:</b> This email is confidential.</p>" `
    -ApplyHtmlDisclaimerLocation Append `
    -ApplyHtmlDisclaimerFallbackAction Wrap

# Create a rule to reject oversized attachments
New-TransportRule -Name "Block Large Attachments" `
    -AttachmentSizeOver 25MB `
    -RejectMessageReasonText "Attachments exceeding 25MB are not permitted."

# Create a rule to bypass spam filtering for a trusted IP range
New-TransportRule -Name "Bypass Spam - Trusted Relay" `
    -SenderIPRanges 203.0.113.0/24 `
    -SetSCL -1

# View all transport rules
Get-TransportRule | Select Name, Priority, State | Sort Priority
```

### 9.2 Retention Policies and Labels

**Exchange Retention Policies** (on-premises and Exchange Online):
- Applied at the mailbox level
- Contains **Retention Tags** that define actions (delete, archive, move to archive)
- Tag types: Default Policy Tag (DPT), Retention Policy Tag (RPT), Personal Tag

```powershell
# Create a retention tag
New-RetentionPolicyTag -Name "Delete after 3 years" -Type All `
    -RetentionEnabled $true -AgeLimitForRetention 1095 `
    -RetentionAction DeleteAndAllowRecovery

# Create a retention policy
New-RetentionPolicy -Name "Corporate Retention Policy" `
    -RetentionPolicyTagLinks "Delete after 3 years","Move to Archive after 2 years"

# Apply policy to mailboxes
Set-Mailbox -Identity user@contoso.com -RetentionPolicy "Corporate Retention Policy"

# Force MRM (Managed Folder Assistant) to process mailbox immediately
Start-ManagedFolderAssistant -Identity user@contoso.com
```

**Microsoft Purview Retention Policies** (Exchange Online) are the modern approach:
- Configured in Microsoft Purview compliance portal
- Support adaptive scopes (dynamic group membership)
- Support immutable (locked) policies for regulatory compliance
- Can be applied to mailboxes, Teams, SharePoint, OneDrive, Viva Engage

### 9.3 Litigation Hold and In-Place Hold

**Litigation Hold** preserves all mailbox content from deletion or modification:

```powershell
# Enable litigation hold on a mailbox (indefinite)
Set-Mailbox -Identity user@contoso.com -LitigationHoldEnabled $true

# Enable litigation hold with duration (90 days)
Set-Mailbox -Identity user@contoso.com -LitigationHoldEnabled $true `
    -LitigationHoldDuration 90

# Enable litigation hold with comment and URL
Set-Mailbox -Identity user@contoso.com -LitigationHoldEnabled $true `
    -LitigationHoldDuration Unlimited `
    -RetainDeletedItemsFor 30 `
    -LitigationHoldOwner "Legal Department"

# Check litigation hold status
Get-Mailbox -Identity user@contoso.com | Select LitigationHoldEnabled, LitigationHoldDuration

# Check how much data is in Recoverable Items (holds increase this quota)
Get-MailboxStatistics -Identity user@contoso.com | Select DisplayName, TotalItemSize, TotalDeletedItemSize
```

**Key differences:**

| Feature | Litigation Hold | Microsoft Purview Hold |
|---------|-----------------|----------------------|
| Scope | Single mailbox | Multiple locations incl. Teams, SharePoint |
| Administration | EAC / Exchange PowerShell | Microsoft Purview portal |
| Query-based | No (all content) | Yes (via eDiscovery case) |
| Recommended for | Exchange-specific legacy | Modern compliance (preferred) |

### 9.4 Journaling

Journaling captures copies of email messages for compliance archiving:

```powershell
# Create a journal rule (Standard - single mailbox)
New-JournalRule -Name "Legal Journal - CFO" `
    -Recipient cfo@contoso.com `
    -JournalEmailAddress journal@externalarchive.com `
    -Scope Internal -Enabled $true

# Create a global journal rule (Premium - all messages)
New-JournalRule -Name "Global Journal" `
    -JournalEmailAddress journal@externalarchive.com `
    -Scope Global -Enabled $true

# View journal rules
Get-JournalRule | Select Name, Recipient, JournalEmailAddress, Scope, Enabled
```

**Note:** Microsoft recommends using Purview retention policies and holds over journaling for new deployments. Journaling is often used for integration with third-party compliance archiving systems (Mimecast, Veritas, Proofpoint Archive).

### 9.5 eDiscovery

**Exchange Online eDiscovery** is managed in the Microsoft Purview compliance portal:

1. **Content Search** — Search across Exchange, SharePoint, Teams, Viva Engage
2. **Core eDiscovery** — Case management, hold, export; included in M365 E3
3. **Microsoft Purview eDiscovery (Premium)** — Advanced analytics, custodian management, review sets, predictive coding; requires M365 E5 or add-on

```powershell
# Exchange Online: Search mailbox content
New-ComplianceSearch -Name "Legal Case 2025-01" `
    -ExchangeLocation user@contoso.com `
    -ContentMatchQuery "from:vendor@external.com AND received:2024-01-01..2024-12-31"

Start-ComplianceSearch -Identity "Legal Case 2025-01"

Get-ComplianceSearch -Identity "Legal Case 2025-01" | Select Status, Items, Size

# Export search results
New-ComplianceSearchAction -SearchName "Legal Case 2025-01" -Export -Format FxStream
```

### 9.6 Public Folders

Public folders provide shared repository accessible by multiple users. Available in both Exchange Server 2019 and Exchange Online:

```powershell
# Create a public folder hierarchy mailbox
New-Mailbox -PublicFolder -Name "PrimaryHierarchy"

# Create a public folder
New-PublicFolder -Name "Shared Documents" -Path "\"

# Set permissions
Add-PublicFolderClientPermission -Identity "\Shared Documents" `
    -User user@contoso.com -AccessRights PublishingEditor

# Mail-enable a public folder
Enable-MailPublicFolder -Identity "\Shared Documents"
Set-MailPublicFolder -Identity "\Shared Documents" `
    -PrimarySmtpAddress shareddocs@contoso.com

# Get public folder statistics
Get-PublicFolderStatistics -Server EX01 | Select Name, TotalItemSize, ItemCount | Sort TotalItemSize -Descending
```

**Migration of public folders to Exchange Online:**
```powershell
# Export public folder structure
Get-PublicFolder -Recurse | Export-Clixml C:\PFStructure.xml

# Modern public folders in Exchange Online use mailbox-based architecture
# Each public folder mailbox holds up to 100 GB of content
```

### 9.7 Address Book Policies (ABP)

ABPs allow segmentation of the global address list, enabling different user populations to see different views of the directory (useful for multi-tenant hosted Exchange or privacy separation):

```powershell
# Create address lists, GAL, and offline address book first, then:
New-AddressBookPolicy -Name "Contoso ABP" `
    -AddressLists "\Contoso Users","\Contoso DLs" `
    -GlobalAddressList "\Contoso GAL" `
    -OfflineAddressBook "\Contoso OAB" `
    -RoomList "\Contoso Rooms"

# Assign ABP to users
Set-Mailbox -Identity user@contoso.com -AddressBookPolicy "Contoso ABP"

# View ABP assignments
Get-Mailbox | Where {$_.AddressBookPolicy -ne $null} | Select Name, AddressBookPolicy
```

---

## 10. MANAGEMENT

### 10.1 Exchange Management Shell (EMS)

The EMS is PowerShell with Exchange snap-ins loaded. For on-premises Exchange, launch from the Exchange server or remotely:

```powershell
# Load Exchange snap-in remotely
$ExSession = New-PSSession -ConfigurationName Microsoft.Exchange `
    -ConnectionUri http://EX01.contoso.com/PowerShell/ `
    -Authentication Kerberos
Import-PSSession $ExSession -DisableNameChecking

# Common Get-Mailbox queries
Get-Mailbox -ResultSize Unlimited | Measure-Object  # Count all mailboxes
Get-Mailbox -RecipientTypeDetails SharedMailbox | Select Name, PrimarySmtpAddress
Get-Mailbox -Filter {WhenCreated -gt "01/01/2025"} | Select Name, WhenCreated
Get-Mailbox user@contoso.com | Select *Archive*, *Hold*, *Quota*

# Mailbox statistics
Get-MailboxStatistics -Identity user@contoso.com | Select DisplayName, TotalItemSize, ItemCount, LastLogonTime

# All mailbox sizes
Get-Mailbox -ResultSize Unlimited | Get-MailboxStatistics | 
    Select DisplayName, @{N="Size(MB)";E={[math]::Round($_.TotalItemSize.Value.ToMB(),2)}} |
    Sort "Size(MB)" -Descending | Select -First 20

# Set mailbox quotas
Set-Mailbox -Identity user@contoso.com `
    -IssueWarningQuota 45GB `
    -ProhibitSendQuota 49GB `
    -ProhibitSendReceiveQuota 50GB
```

### 10.2 Exchange Admin Center (EAC)

The EAC is the web-based management interface:
- **On-premises:** `https://servername/ecp` or `https://mail.contoso.com/ecp`
- **Exchange Online:** `https://admin.exchange.microsoft.com`

**EAC sections:**
- Recipients (mailboxes, groups, resources, shared, contacts, migration)
- Permissions (admin roles, user roles, Outlook Web App policies)
- Compliance management (eDiscovery, holds, audit log, data loss prevention, retention)
- Organization (federation, organization relationships, sharing)
- Protection (malware filter, connection filter, spam filter, DKIM)
- Mail flow (rules, delivery reports, accepted domains, email address policies, send/receive connectors)
- Mobile (mobile device access, mobile device mailbox policies)
- Public folders

### 10.3 Key Administrative PowerShell Cmdlets

**Mailbox Management:**
```powershell
New-Mailbox -UserPrincipalName user@contoso.com -Alias user -Name "User Name" -Password (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force)
Set-Mailbox -Identity user@contoso.com -EmailAddresses @{Add="alias@contoso.com"}
Remove-Mailbox -Identity user@contoso.com
Enable-Mailbox -Identity "Disabled User" -Database DB01
Disable-Mailbox -Identity user@contoso.com

# Mailbox permissions
Add-MailboxPermission -Identity shared@contoso.com -User delegate@contoso.com -AccessRights FullAccess -InheritanceType All
Add-RecipientPermission -Identity shared@contoso.com -Trustee delegate@contoso.com -AccessRights SendAs
```

**Database Management:**
```powershell
Get-MailboxDatabase -Server EX01 -Status | Select Name, Mounted, DatabaseSize, AvailableNewMailboxSpace
New-MailboxDatabase -Name DB02 -Server EX01 -EdbFilePath D:\DB02\DB02.edb -LogFolderPath E:\DB02\Logs
Mount-Database -Identity DB02
Move-DatabasePath -Identity DB01 -EdbFilePath F:\DB01\DB01.edb -LogFolderPath G:\DB01\Logs
```

**Server Health:**
```powershell
# Test mail flow
Test-Mailflow -TargetMailboxServer EX02

# Test MAPI connectivity
Test-MAPIConnectivity -Server EX01

# Test OWA
Test-OwaConnectivity -URL https://mail.contoso.com/owa -MailboxCredential (Get-Credential)

# Server health (managed availability)
Get-ServerHealth -Server EX01 | Where {$_.AlertValue -ne "Healthy"}

# Service status
Test-ServiceHealth -Server EX01
```

### 10.4 Exchange Online Management Cmdlets

```powershell
# Connect (requires ExchangeOnlineManagement module v3+)
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com

# Recipient management
Get-EXOMailbox -ResultSize Unlimited | Select DisplayName, UserPrincipalName, RecipientTypeDetails
Get-EXOMailboxStatistics -Identity user@contoso.com | Select DisplayName, TotalItemSize, ItemCount
Get-EXORecipient -ResultSize Unlimited -RecipientTypeDetails MailContact | Select Name, PrimarySmtpAddress

# Message trace (Exchange Online equivalent of Get-MessageTrackingLog)
Get-MessageTrace -SenderAddress sender@external.com -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) | 
    Select Received, SenderAddress, RecipientAddress, Subject, Status

# Message trace detail
Get-MessageTraceDetail -MessageTraceId <TraceId> -RecipientAddress user@contoso.com

# Disconnect
Disconnect-ExchangeOnline -Confirm:$false
```

---

## 11. DIAGNOSTICS AND TROUBLESHOOTING

### 11.1 Message Tracking (On-Premises)

```powershell
# Track a message by subject
Get-MessageTrackingLog -Server EX01 -Start (Get-Date).AddHours(-24) `
    -EventId RECEIVE -MessageSubject "Invoice Q4"

# Track messages from a sender
Get-MessageTrackingLog -Server EX01 -Start (Get-Date).AddDays(-2) `
    -Sender user@external.com | Select Timestamp, EventId, Source, MessageSubject, Recipients

# Track messages to a recipient
Get-MessageTrackingLog -Server EX01 -Start (Get-Date).AddHours(-8) `
    -Recipients user@contoso.com | Select Timestamp, EventId, Source, MessageSubject, Sender

# Track failed deliveries
Get-MessageTrackingLog -Server EX01 -Start (Get-Date).AddHours(-4) `
    -EventId FAIL | Select Timestamp, Sender, Recipients, MessageSubject, Source

# Track all servers in the org
Get-ExchangeServer | ForEach {
    Get-MessageTrackingLog -Server $_.Name -Start (Get-Date).AddHours(-1) `
        -MessageSubject "Urgent Report" 2>$null
}
```

**Key Event IDs in message tracking:**
| Event ID | Description |
|----------|-------------|
| RECEIVE | Message received by transport service |
| SEND | Message sent to next hop |
| DELIVER | Message delivered to mailbox |
| FAIL | Delivery failure |
| DEFER | Delivery deferred (temporary failure) |
| RESOLVE | Recipient resolved to email address |
| EXPAND | Distribution group expanded |
| REDIRECT | Message redirected by transport rule |
| DROP | Message dropped (not delivered, no NDR) |

### 11.2 Queue Management

```powershell
# View all queues
Get-Queue | Select Identity, DeliveryType, Status, MessageCount, NextHopDomain | Sort MessageCount -Descending

# View stuck queues
Get-Queue | Where {$_.Status -eq "Retry" -or $_.MessageCount -gt 100}

# View messages in a specific queue
Get-Message -Queue "EX01\Submission" | Select Subject, FromAddress, ToAddresses, Size, DateReceived

# Retry a queue
Retry-Queue -Identity "EX01\contoso.com" -Resubmit $true

# Suspend a queue
Suspend-Queue -Identity "EX01\contoso.com"

# Resume a queue
Resume-Queue -Identity "EX01\contoso.com"

# Remove messages from a queue
Remove-Message -Identity "EX01\contoso.com\1234" -WithNDR $false
```

**Common queue issues:**
- `SmtpConnectFailure` — Cannot connect to destination; check DNS, firewall, TLS
- `DnsConnectFailure` — DNS resolution failure; check DNS server connectivity
- `ConnectionReset` — Remote server closed connection; check TLS version mismatch
- `TLSCertificateMismatch` — Certificate validation failed on connector with TLS required

### 11.3 DAG and Replication Diagnostics

```powershell
# Full replication health check
Test-ReplicationHealth -Server EX01 | Format-Table CheckFailed, IsValid, Error

# Database copy status - look for issues
Get-MailboxDatabaseCopyStatus * | Where {$_.Status -notlike "Mounted" -and $_.Status -notlike "Healthy"} |
    Select DatabaseName, Status, CopyQueueLength, ReplayQueueLength, ContentIndexState

# Reseed a database copy
Update-MailboxDatabaseCopy -Identity DB01\EX02 -DeleteExistingFiles

# Check copy queue length (should be < 10 for healthy, < 100 for warning)
Get-MailboxDatabaseCopyStatus * | Select DatabaseName, CopyQueueLength, ReplayQueueLength | Sort CopyQueueLength -Descending

# Force switchover of active database copy
Move-ActiveMailboxDatabase -Identity DB01 -ActivateOnServer EX02 -SkipActiveCopyChecks -MountDialOverride None

# Check DAG health
$DAG = Get-DatabaseAvailabilityGroup DAG1 -Status
$DAG.OperationalServers
$DAG.PrimaryActiveManager
```

**Common replication errors:**
- `CopyQueueLength > 100` — Replication falling behind; check network bandwidth, disk I/O
- `ContentIndexState: Failed` — Search index corrupt; run `Update-MailboxDatabaseCopy -CatalogOnly`
- `Status: Failed` — Database copy failed; check `Get-MailboxDatabaseCopyStatus -ExtendedErrorInfo`
- `Status: SeedingSource/Seeding` — Database being reseeded (normal during initial setup or after reseed command)

### 11.4 Connectivity Tests

```powershell
# Test MAPI connectivity
Test-MAPIConnectivity -Server EX01
Test-MAPIConnectivity -Identity user@contoso.com  # Test specific user

# Test ActiveSync connectivity
Test-ActiveSyncConnectivity -URL https://mail.contoso.com/Microsoft-Server-ActiveSync `
    -MailboxCredential (Get-Credential)

# Test OWA
Test-OwaConnectivity -URL https://mail.contoso.com/owa `
    -MailboxCredential (Get-Credential) -TrustAnySSLCertificate

# Test internal mail flow
Test-Mailflow -TargetMailboxServer EX02
Test-Mailflow -TargetEmailAddress user@contoso.com

# Test EWS connectivity
Test-WebServicesConnectivity -ClientAccessServer EX01 `
    -MailboxCredential (Get-Credential) -TrustAnySSLCertificate

# Remote Connectivity Analyzer (web-based for external testing)
# https://testconnectivity.microsoft.com
```

### 11.5 Performance Counters and Monitoring

**Key Exchange performance counters:**

| Counter | Object | Warning Threshold |
|---------|--------|------------------|
| RPC Averaged Latency | MSExchange RPC Client Access | > 250ms |
| Active Mailbox Database | MSExchange Active Manager | Monitor for unexpected changes |
| Messages Queued for Submission | MSExchange Transport | > 100 sustained |
| Database reads/writes avg latency | MSExchange Database | > 20ms (reads), > 100ms (writes) |
| Poison Message Counter | MSExchange Transport | > 0 |

```powershell
# Check managed availability health sets (Exchange's self-monitoring system)
Get-ServerHealth EX01 | Where {$_.AlertValue -ne "Healthy"} | 
    Select HealthSetName, AlertValue, LastTransitionTime

# View managed availability monitors
Get-MonitoringItemIdentity -Server EX01 -Identity OutlookMapiHttp*

# View recent managed availability recovery actions
Get-EventLog -LogName Application -Source MSExchangeHMRecovery -Newest 20 | 
    Select TimeGenerated, Message
```

### 11.6 Certificate Management

**Exchange 2019 certificate requirements:**
- Third-party certificate required for hybrid deployments and external client access
- SAN certificate recommended (covers multiple hostnames in one cert)
- Required SANs (minimum): `mail.contoso.com`, `autodiscover.contoso.com`
- For Edge Transport: `smtp.contoso.com` or the FQDN used for outbound SMTP

```powershell
# View installed certificates
Get-ExchangeCertificate -Server EX01 | Select Thumbprint, Status, Services, NotAfter, Subject | 
    Sort NotAfter

# Generate a new CSR
New-ExchangeCertificate -GenerateRequest `
    -SubjectName "c=US,o=Contoso,cn=mail.contoso.com" `
    -DomainName mail.contoso.com, autodiscover.contoso.com, smtp.contoso.com `
    -RequestFile C:\CertRequest.req `
    -KeySize 2048 `
    -PrivateKeyExportable $true

# Import certificate after CA signs it
Import-ExchangeCertificate -Server EX01 -FileData ([System.IO.File]::ReadAllBytes("C:\contoso.cer")) `
    -FriendlyName "Exchange 2019 Certificate 2025"

# Assign certificate to services
Enable-ExchangeCertificate -Server EX01 `
    -Thumbprint "AABBCC..." `
    -Services SMTP, IIS, IMAP, POP

# Check certificate expiration (warning: < 30 days)
Get-ExchangeCertificate -Server EX01 | Where {$_.NotAfter -lt (Get-Date).AddDays(30)} |
    Select Subject, NotAfter, Services
```

---

## 12. SEND/RECEIVE CONNECTORS AND ACCEPTED DOMAINS

### 12.1 Receive Connectors

```powershell
# View all receive connectors
Get-ReceiveConnector | Select Name, Server, Bindings, RemoteIPRanges, AuthMechanism, PermissionGroups

# Create a receive connector for a relay device (e.g., scanner, application)
New-ReceiveConnector -Name "Relay - Copiers" -Server EX01 `
    -TransportRole FrontendTransport `
    -Bindings 0.0.0.0:25 `
    -RemoteIPRanges 10.0.1.50,10.0.1.51 `
    -AuthMechanism None `
    -PermissionGroups AnonymousUsers

# Grant relay permission to anonymous sender
Get-ReceiveConnector "Relay - Copiers" | Add-ADPermission `
    -User "NT AUTHORITY\ANONYMOUS LOGON" `
    -ExtendedRights "Ms-Exch-SMTP-Accept-Any-Recipient"
```

### 12.2 Send Connectors

```powershell
# Create a send connector to the internet
New-SendConnector -Name "Internet" -AddressSpaces * `
    -DNSRoutingEnabled $true -SourceTransportServers EX01,EX02

# Create a send connector through a smart host
New-SendConnector -Name "Outbound via SmartHost" -AddressSpaces * `
    -DNSRoutingEnabled $false `
    -SmartHosts smtp.provider.com `
    -SmartHostAuthMechanism BasicAuthRequireTLS `
    -AuthenticationCredential (Get-Credential) `
    -SourceTransportServers EX01

# Verify send connector
Get-SendConnector | Select Name, AddressSpaces, DNSRoutingEnabled, SmartHosts, TlsAuthLevel
```

### 12.3 Accepted Domains

```powershell
# View accepted domains
Get-AcceptedDomain | Select Name, DomainName, DomainType, Default

# Add an authoritative domain
New-AcceptedDomain -Name "contoso.com" -DomainName contoso.com -DomainType Authoritative

# Add an internal relay domain (for on-premises mailboxes during hybrid)
New-AcceptedDomain -Name "contoso-onprem.com" -DomainName contoso-onprem.com -DomainType InternalRelay

# Add an external relay domain
New-AcceptedDomain -Name "partner.com" -DomainName partner.com -DomainType ExternalRelay

# Set default accepted domain
Set-AcceptedDomain -Identity "contoso.com" -MakeDefault $true
```

---

## 13. BEST PRACTICES SUMMARY

### 13.1 DAG Design
- Use the Preferred Architecture (PA): physical servers, JBOD storage, single NIC, 4 DB copies per DB
- Minimum 4-member DAG for site resiliency (2 per datacenter)
- Target 8-member DAGs for larger organizations
- Use ReFS (integrity stream disabled) for all Exchange data volumes
- Enable AutoReseed with at least 1 hot spare disk per server
- Maximum recommended database size: 2 TB per database in a PA deployment
- Witness server in a third location or Azure for automatic datacenter failover
- Network latency between DAG members must not exceed 250ms round-trip

### 13.2 Certificate Lifecycle
- Use third-party certificates (not self-signed) for client-facing and hybrid services
- Use SAN certificates covering: `mail.contoso.com`, `autodiscover.contoso.com`
- Monitor certificate expiration; alert at 60 days, renew at 30 days
- Generate a new CSR (don't renew from existing) for best key hygiene
- Assign to services: SMTP, IIS, IMAP, POP as needed
- For hybrid, certificate must be trusted by Microsoft 365 (commercial CA required)

### 13.3 Anti-Spam and Security
- Deploy Edge Transport server in DMZ for perimeter filtering
- Configure SPF, DKIM, DMARC for all sending domains (target: `p=reject`)
- Use EOP preset security policies (Standard or Strict) as baseline
- Enable Safe Attachments and Safe Links (Defender for Office 365)
- Enable outbound spam policies to restrict compromised accounts
- Never use IP allowlists that bypass authentication checks
- Configure DKIM key rotation (Microsoft rotates automatically in Exchange Online)

### 13.4 Migration
- Always test migration with a pilot group before full deployment
- Set `BadItemLimit` based on environment (50 is common; increase for older mailboxes)
- Schedule final sync/cutover during off-hours
- Update Autodiscover DNS after cutover to point to Exchange Online
- Keep on-premises Exchange for hybrid management even after full migration
- Decommission on-premises Exchange only after confirming all mail flow and features work

### 13.5 Monitoring
- Use managed availability health sets (`Get-ServerHealth`) as primary health indicator
- Alert on: database copy queue length > 100, RPC latency > 250ms, disk latency > 20ms
- Monitor certificate expiration dates
- Review Exchange setup and application event logs regularly
- Use Microsoft Remote Connectivity Analyzer for external endpoint testing: `https://testconnectivity.microsoft.com`
- Enable diagnostic logging selectively (avoid high logging on production — significant performance impact)

---

## 14. COMMON ERROR MESSAGES AND RESOLUTIONS

| Error | Likely Cause | Resolution |
|-------|-------------|------------|
| `451 4.4.0 DNS query failed` | DNS resolution failure | Check DNS server connectivity, MX record, stub zones |
| `550 5.7.1 Unable to relay` | Anonymous relay not permitted | Configure receive connector with proper permissions |
| `421 4.3.2 Service not available` | Transport service overloaded | Check CPU, memory, disk I/O; review queue depths |
| `530 5.7.0 Must issue a STARTTLS command first` | TLS required but not initiated | Configure sending system to use STARTTLS |
| `Database is in Disconnected (Dismounted) state` | Database not mounted | Check disk health, run `Mount-Database` |
| `The term 'Get-Mailbox' is not recognized` | Exchange snap-in not loaded | Launch Exchange Management Shell or import PSSession |
| `Mailbox database 'DB01' is approaching its maximum size` | DB size limit (EE: 1 TB; SE: 2 TB | Add/move mailboxes to another database |
| `Could not connect to the remote server` | RPC/network connectivity | Check firewall, WinRM, Exchange services |
| `ErrorMailboxMoveInProgress` | Mailbox already in a move | Wait for existing move or cancel with `Remove-MoveRequest` |
| `TooManyBadItemsPermanentException` | BadItemLimit exceeded during migration | Increase `-BadItemLimit` on migration batch |

---

*Sources: Microsoft Learn Exchange documentation, Microsoft Tech Community Exchange blog, Practical365, office365itpros.com, alitajran.com, informaticar.net — April 2026*
