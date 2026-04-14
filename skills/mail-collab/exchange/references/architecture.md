# Exchange Architecture Deep Reference

## Transport Pipeline Internals

### Front End Transport Service

The Front End Transport listens on port 25 for inbound external SMTP. It is a stateless proxy -- no content inspection, no queuing. It routes to the Transport Service on the same or another Mailbox server.

**Default Receive connectors:**
- `Default Frontend <ServerName>` (port 25) -- Accepts inbound SMTP from all
- `Outbound Proxy Frontend <ServerName>` -- Proxies outbound if configured
- `Client Frontend <ServerName>` (port 587) -- Authenticated client submission

### Transport Service (Hub Transport)

The core message processing engine:
- **Categorizer:** Resolves recipients, expands distribution groups, determines routing
- **Transport Rule Agent:** Evaluates mail flow rules against conditions/exceptions/actions
- **Content conversion:** Handles TNEF, MIME, HTML/plain text conversion
- **Shadow Redundancy:** Maintains shadow copies until next-hop acknowledges
- **Safety Net:** Retains delivered messages (default 2 days) for resubmission after failover

Default Receive connectors:
- `Default <ServerName>` (port 2525) -- From Frontend Transport
- `Client Frontend <ServerName>` (port 587) -- Authenticated submission via Frontend proxy

### Mailbox Transport Service

Two sub-services:
- **Mailbox Transport Submission** -- Retrieves messages from mailbox DB via RPC, submits to Transport via SMTP
- **Mailbox Transport Delivery** -- Receives from Transport via SMTP, delivers to mailbox DB via RPC

### Message Flow Diagrams

**Inbound (no Edge Transport):**
```
Internet --> Frontend Receive (port 25)
         --> Transport Service (categorizer, transport rules, shadow redundancy)
         --> Mailbox Transport Delivery
         --> Mailbox Database (via RPC)
```

**Outbound (no Edge Transport):**
```
Mailbox Database (via RPC) --> Mailbox Transport Submission
                            --> Transport Service
                            --> Send Connector --> Internet
```

### Send and Receive Connectors

**Send connectors** define how Exchange routes outbound mail:
```powershell
# Create internet Send connector
New-SendConnector -Name "Internet Mail" -Usage Internet `
    -AddressSpaces "SMTP:*;1" -SourceTransportServers EX01,EX02 `
    -DNSRoutingEnabled $true

# Create partner Send connector (specific domain, smart host)
New-SendConnector -Name "Partner Relay" -Usage Partner `
    -AddressSpaces "SMTP:partner.com;1" `
    -SmartHosts "smtp.partner.com" -SmartHostAuthMechanism None `
    -RequireTLS $true -TlsDomain partner.com
```

**Receive connectors** define how Exchange accepts inbound SMTP:
```powershell
# Create custom Receive connector for application relay
New-ReceiveConnector -Name "Application Relay" `
    -TransportRole FrontendTransport -Usage Custom `
    -Bindings 0.0.0.0:25 -RemoteIPRanges 10.0.0.0/24 `
    -PermissionGroups AnonymousUsers
```

---

## Database Availability Groups

### DAG Architecture

A DAG is a group of up to 16 Mailbox servers providing automatic database-level failover. Built on Windows Failover Clustering.

**Active Manager:** Runs on every DAG member. The Primary Active Manager (PAM) makes mounting decisions. Other members run as Standby Active Managers (SAM).

**Quorum models:**

| DAG Size | Quorum Mode | Notes |
|----------|-------------|-------|
| Even members | Node and File Share Majority | Witness server as tie-breaker |
| Odd members | Node Majority | No witness needed |

**Witness server placement:** Best in a third location for automatic datacenter failover. Azure VM is acceptable.

### Database Copies

```powershell
# View all copies of a database
Get-MailboxDatabaseCopyStatus -Identity DB01\*

# Key status fields:
# Status: Mounted, Healthy, Suspended, Failed, Seeding
# CopyQueueLength: Logs waiting to be copied (should be < 10)
# ReplayQueueLength: Logs waiting to be replayed (should be < 10)
# ContentIndexState: Healthy, FailedAndSuspended

# Suspend replication for maintenance
Suspend-MailboxDatabaseCopy -Identity DB01\EX02 -ActivationOnly

# Resume
Resume-MailboxDatabaseCopy -Identity DB01\EX02

# Perform manual switchover
Move-ActiveMailboxDatabase DB01 -ActivateOnServer EX02 -Confirm:$false

# Reseed a failed copy
Remove-MailboxDatabaseCopy -Identity DB01\EX02 -Confirm:$false
Add-MailboxDatabaseCopy -Identity DB01 -MailboxServer EX02 -ActivationPreference 2 -SeedingPostponed
Update-MailboxDatabaseCopy -Identity DB01\EX02
```

### Lagged Database Copies

Lagged copies delay transaction log replay to protect against logical corruption:

```powershell
# Add 7-day lagged copy
Add-MailboxDatabaseCopy -Identity DB01 -MailboxServer EX04 `
    -ReplayLagTime 7.0:0:0 -TruncationLagTime 0.0:0:0 `
    -ActivationPreference 4

# Replay Lag Manager dynamically plays down logs when HA is compromised
# To recover from lagged copy:
Suspend-MailboxDatabaseCopy -Identity DB01\EX04 -SuspendComment "Point-in-time recovery"
# Use eseutil to replay logs to desired point-in-time
```

### AutoReseed

Automatically restores database redundancy after disk failure:

```powershell
Set-DatabaseAvailabilityGroup -Identity DAG1 `
    -AutoDagAutoReseedEnabled $true `
    -AutoDagDiskReclaimerEnabled $true
```

Requires at least one hot spare disk per server. AutoReseed activates the spare and initiates database reseed.

---

## Managed Store and MCDB

### MetaCache Database (MCDB)

MCDB caches frequently accessed metadata on SSD/NVMe:
- 5-10% of total database storage should be SSD for MCDB
- HDD:SSD ratio recommendation: 3:1
- If SSD fails, HA moves affected copies to nodes with healthy MCDB
- Reduces disk I/O latency for active mailbox operations

### Storage Design (Preferred Architecture)

| Disk Role | Type | Format |
|-----------|------|--------|
| OS + Exchange binaries | RAID1 pair | NTFS |
| Mailbox databases + logs | HDD (7.2K SAS), JBOD | ReFS (integrity disabled) |
| MCDB | SSD (SAS or NVMe) | ReFS |
| Hot spare | HDD | Unformatted (for AutoReseed) |

**BitLocker** on all data disks for data-at-rest encryption.

---

## Client Access Architecture

Clients never connect directly to backend mailbox services. The frontend Client Access layer on each Mailbox server acts as a stateless proxy:

1. Client connects to frontend (e.g., `mail.contoso.com` via HTTPS)
2. Frontend proxies to backend service on the server holding the active database copy
3. Backend accesses mailbox database via RPC

**Protocol mapping:**
- HTTP clients --> HTTP proxy (self-signed cert between frontend/backend)
- IMAP/POP --> IMAP/POP proxy
- SMTP submission --> Port 587

**MAPI over HTTP** is the default Outlook connection protocol (replaced RPC over HTTP/Outlook Anywhere).

### Autodiscover

Autodiscover provides client auto-configuration:

```powershell
# Test Autodiscover
Test-OutlookWebServices -Identity user@contoso.com | Select-Object Scenario, Result, Message

# Get Autodiscover virtual directory
Get-AutodiscoverVirtualDirectory | Select Server, InternalUrl, ExternalUrl

# Outlook connectivity test
Test-OutlookConnectivity -Protocol HTTP -GetDefaultsFromAutodiscover
```

---

## Edge Transport Server

### Architecture

Deployed in the perimeter (DMZ), not domain-joined. Uses AD LDS (Lightweight Directory Services) for recipient data. EdgeSync synchronizes from internal AD.

### Antispam Agents

| Agent | Function |
|-------|----------|
| Connection Filtering | IP block/allow lists, RBLs |
| Sender ID | SPF record validation |
| Content Filtering | SCL scoring |
| Recipient Filtering | Rejects non-existent/blocked recipients |
| Sender Filtering | Blocks specific senders/domains |
| Sender Reputation | SRL scoring, auto-blocks |
| Attachment Filtering | Filters by name, MIME type, size |

```powershell
# Subscribe Edge Transport
New-EdgeSubscription -FileName "C:\EdgeSubscription.xml"
# Copy XML to internal Mailbox server, then:
New-EdgeSubscription -FileData ([byte[]]$(Get-Content "C:\EdgeSubscription.xml" -Encoding Byte -ReadCount 0)) `
    -Site "Default-First-Site-Name"

# Force EdgeSync
Start-EdgeSynchronization

# Verify EdgeSync
Test-EdgeSynchronization -Server EX-EDGE01
```

---

## Exchange Online Protection (EOP)

### Filtering Pipeline (Inbound)

1. **Connection filtering** -- Sender IP vs. allow/block lists, Microsoft intelligence
2. **Anti-malware** -- Multi-engine scanning, infected attachments quarantined
3. **Mail flow rules** -- Transport rules evaluated before anti-spam
4. **Anti-spam** -- SCL -1 to 9, BCL for newsletters
5. **Anti-phishing** -- Impersonation detection, spoof intelligence

```powershell
# View anti-spam policies
Get-HostedContentFilterPolicy | Select Name, SpamAction, HighConfidenceSpamAction

# View anti-phishing policies
Get-AntiPhishPolicy | Select Name, EnableMailboxIntelligence, EnableSpoofIntelligence

# Check quarantine
Get-QuarantineMessage -RecipientAddress user@contoso.com

# Release from quarantine
Release-QuarantineMessage -Identity <MessageIdentity> -ReleaseToAll
```

### Email Authentication in Exchange Online

```powershell
# Enable DKIM
Set-DkimSigningConfig -Identity contoso.com -Enabled $true

# Check DKIM status
Get-DkimSigningConfig -Identity contoso.com | Select Domain, Status, Selector1CNAME
```

DKIM requires two CNAME records in DNS:
```
selector1._domainkey.contoso.com --> selector1-contoso-com._domainkey.contoso.onmicrosoft.com
selector2._domainkey.contoso.com --> selector2-contoso-com._domainkey.contoso.onmicrosoft.com
```

For full SPF/DKIM/DMARC guidance, see `skills/security/email-security/SKILL.md`.

---

## Exchange Online Architecture

### Tenant and Mailbox Model

- Dedicated Exchange Online organization per tenant with isolated databases
- Microsoft manages HA transparently (multiple database copies)
- Primary SMTP namespace: `tenant.onmicrosoft.com`; custom domains added as accepted domains

### Mailbox Types and Plans

| Plan | Included In | Mailbox Size | Archive |
|------|-------------|-------------|---------|
| Exchange Online Plan 1 | M365 Business Basic/Standard | 50 GB | Add-on |
| Exchange Online Plan 2 | M365 E3/E5 | 100 GB | Unlimited auto-expanding |
| Exchange Online Kiosk | F1/F3 | 2 GB | No |

### Microsoft 365 Groups vs. Distribution Groups

- **Distribution Groups:** SMTP-only, no shared resources
- **Mail-Enabled Security Groups:** Distribution + AD security capabilities
- **Microsoft 365 Groups:** Shared mailbox, calendar, SharePoint site, Teams team
