# Exchange Best Practices

## Deployment Patterns

### Preferred Architecture (On-Premises)

Microsoft's Preferred Architecture (PA) for Exchange 2019/SE:
- **DAG:** 4 database copies (2 per datacenter), 3 HA + 1 lagged
- **Storage:** JBOD, ReFS, no RAID (database redundancy replaces disk RAID)
- **Network:** Single non-teamed NIC for both client and replication traffic
- **OS:** Windows Server 2022 or 2025 (for Exchange SE)
- **Filesystem:** ReFS with integrity streams disabled for database volumes
- **MCDB:** SSD tier at 5-10% of total database capacity

### Server Sizing

```powershell
# Check Exchange build version
Get-ExchangeServer | Select Name, AdminDisplayVersion, Edition

# Verify .NET Framework version
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').Release
# 528040 = .NET 4.8, 533320 = .NET 4.8.1
```

**Minimum hardware per Mailbox server:**
- CPU: 2 physical processors (16+ cores total)
- RAM: 128 GB minimum for production (48 GB for edge/small deployments)
- System disk: 60 GB SAS/SSD (RAID1)
- Page file: RAM + 10 MB on system disk

### Exchange Server SE Upgrade

In-place upgrade from Exchange 2019 CU14/CU15:

```powershell
# Pre-upgrade: verify CU level
(Get-ExchangeServer).AdminDisplayVersion
# Must be 15.2.1118.x (CU14) or 15.2.1258.x (CU15)

# Pre-upgrade: prepare AD schema
Setup.exe /PrepareSchema /IAcceptExchangeServerLicenseTerms_DiagnosticDataON
Setup.exe /PrepareAD /IAcceptExchangeServerLicenseTerms_DiagnosticDataON

# Run setup
Setup.exe /Mode:Upgrade /IAcceptExchangeServerLicenseTerms_DiagnosticDataON
```

---

## Hybrid Configuration

### HCW Pre-Requisites

- Exchange 2016 CU8+ or Exchange 2019 (any CU) on-premises
- Entra ID Connect configured and syncing
- Valid third-party TLS certificate (not self-signed)
- Autodiscover, EWS, and MAPI endpoints externally accessible (Classic Hybrid)
- DNS: Autodiscover CNAME or SRV record resolving correctly

### HCW Execution

Download from `https://aka.ms/hybridwizard`. HCW configures:
- TLS-encrypted Send/Receive connectors
- OAuth authentication for cross-premises features
- Organization relationships for free/busy
- Migration endpoints for mailbox moves
- Accepted domain sharing

```powershell
# Post-HCW validation
Get-HybridConfiguration

# Check hybrid connectors
Get-SendConnector | Where {$_.Name -like "*Hybrid*"} | Select Name, AddressSpaces, SmartHosts
Get-ReceiveConnector | Where {$_.Name -like "*Hybrid*"} | Select Name, Bindings, RemoteIPRanges

# Test free/busy
Test-OrganizationRelationship -UserIdentity onpremuser@contoso.com -Identity "Exchange Online" -Verbose

# HCW logs
# %ExchangeInstallPath%Logging\Update-HybridConfiguration
```

### Hybrid Modern Authentication (HMA)

Enables Entra ID authentication for on-prem mailboxes (MFA, Conditional Access):

```powershell
# Enable OAuth on on-premises
Set-OrganizationConfig -OAuth2ClientProfileEnabled $true

# Verify OAuth
Test-OAuthConnectivity -Service EWS -TargetUri https://outlook.office365.com/ews/exchange.asmx -Mailbox user@contoso.com
```

Requires Classic Hybrid topology (not Hybrid Agent).

### Cross-Premises Mail Routing

**Centralized Transport:** All Exchange Online outbound routes through on-premises. Use when compliance appliances or journaling require on-prem egress.

**Decentralized (Direct):** Exchange Online sends directly to the internet. Simpler, recommended unless compliance dictates otherwise.

---

## Migration Strategies

### Migration Method Selection

| Method | Source | Max Mailboxes | Best For |
|--------|--------|---------------|----------|
| Cutover | Exchange on-prem | <150 practical | Small orgs, fast timeline |
| Staged | Exchange 2003/2007 | Unlimited | Legacy Exchange, batched |
| Full Hybrid | Exchange 2010+ | Unlimited | Enterprise, ongoing coexistence |
| Minimal Hybrid | Exchange 2010+ | Any | Quick migration, no coexistence |
| IMAP | Any IMAP source | Unlimited | Non-Exchange sources (email only) |
| Google Workspace | Google | Unlimited | Google to Exchange Online |
| Cross-Tenant | M365 to M365 | Unlimited | Mergers, acquisitions |

### Migration Execution Checklist

**Pre-migration:**
- [ ] Inventory all mailboxes, sizes, and special types (shared, resource, linked)
- [ ] Verify Entra ID Connect sync health (no sync errors)
- [ ] Test migration endpoint connectivity
- [ ] Assign licenses in M365 for target mailboxes
- [ ] Communicate to users with timeline and expectations
- [ ] Lower MX/Autodiscover DNS TTL to 300 seconds (48 hours before cutover)
- [ ] Disable MRM/archival policies during migration (prevents "missing items")

**During migration:**
- [ ] Monitor batch progress: `Get-MigrationBatch | Select Status, *Count*`
- [ ] Investigate per-user failures: `Get-MigrationUser | Where {$_.Status -eq "Failed"}`
- [ ] Suspend and resume problematic moves as needed

**Post-migration:**
- [ ] Update MX records to Exchange Online
- [ ] Update Autodiscover CNAME to `autodiscover.outlook.com`
- [ ] Wait 72 hours before removing migration batches
- [ ] Re-enable MRM policies
- [ ] Verify mail flow with test messages in both directions

### Google Workspace to Exchange Online

```powershell
# Create migration endpoint
New-MigrationEndpoint -Gmail -Name "GoogleEndpoint" `
    -ServiceAccountKeyFileData ([System.IO.File]::ReadAllBytes("C:\GoogleServiceAccount.json")) `
    -EmailAddress admin@contoso.com

# Create batch
New-MigrationBatch -Name "GoogleBatch" -SourceEndpoint "GoogleEndpoint" `
    -CSVData ([System.IO.File]::ReadAllBytes("C:\GoogleUsers.csv")) `
    -TargetDeliveryDomain contoso.mail.onmicrosoft.com -AutoStart
```

Prerequisites: Google Service Account with domain-wide delegation, `https://mail.google.com/` scope granted.

### Cross-Tenant Migration (M365 to M365)

```powershell
# Target tenant: establish relationship
New-OrganizationRelationship -Name "CrossTenantRelationship" `
    -DomainNames "sourcetenant.onmicrosoft.com" `
    -MailboxMoveEnabled $true -MailboxMoveCapability Inbound

# Create batch in target tenant
New-MigrationBatch -Name "CrossTenantBatch" -SourceEndpoint "CrossTenantEndpoint" `
    -CSVData ([System.IO.File]::ReadAllBytes("C:\CrossTenantUsers.csv")) -AutoStart
```

**Note:** Application Impersonation RBAC role deprecated in Exchange Online (February 2025). Third-party tools must use Graph API permissions.

---

## Security Hardening

### Certificate Management

```powershell
# View Exchange certificates
Get-ExchangeCertificate | Select Thumbprint, Subject, NotAfter, Services

# Import new certificate
Import-ExchangeCertificate -FileData ([System.IO.File]::ReadAllBytes("C:\cert.pfx")) -Password (ConvertTo-SecureString "password" -AsPlainText -Force)

# Enable certificate for services
Enable-ExchangeCertificate -Thumbprint <thumbprint> -Services IIS,SMTP,POP,IMAP
```

### TLS Configuration

Exchange SE defaults to TLS 1.2 and 1.3 only. For Exchange 2019, disable legacy protocols:

```powershell
# Disable TLS 1.0/1.1 via registry (requires reboot)
# HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server
# Enabled = 0, DisabledByDefault = 1
```

### Administrative Access

- Use Role-Based Access Control (RBAC) for all Exchange management
- Split permissions model separates Exchange admin from AD admin
- Enable admin audit logging: `Set-AdminAuditLogConfig -AdminAuditLogEnabled $true`
- Use management role groups, not individual role assignments

---

## Performance Tuning

### Database Maintenance

```powershell
# Check database white space (available space after online maintenance)
Get-MailboxDatabase -Status | Select Name, DatabaseSize, AvailableNewMailboxSpace

# Mailbox move for database rebalancing
New-MoveRequest -Identity user@contoso.com -TargetDatabase DB02
```

### Transport Tuning

```powershell
# Adjust concurrent delivery limits
Set-TransportServer -Identity EX01 `
    -MaxConcurrentMailboxDeliveries 20 `
    -MaxConcurrentMailboxSubmissions 20

# Message size limits
Set-TransportConfig -MaxSendSize 150MB -MaxReceiveSize 150MB
Set-SendConnector -Identity "Internet Mail" -MaxMessageSize 35MB
```

### Monitoring Health

```powershell
# Exchange HealthChecker script (download from GitHub)
.\HealthChecker.ps1 -Server EX01

# Test service health
Test-ServiceHealth -Server EX01

# Test replication health
Test-ReplicationHealth -Server EX01

# Test MAPI connectivity
Test-MAPIConnectivity -Server EX01

# Queue depth (should be near 0)
Get-Queue -Server EX01 | Select Identity, MessageCount, Status
```

---

## Backup and Recovery

### DAG Is Not Backup

DAG provides high availability (protects against hardware failure) but does not protect against:
- Accidental deletion by admin
- Ransomware encrypting databases
- Logical corruption propagating to all copies
- Regulatory requirement for point-in-time recovery

### Backup Strategy

- Use Windows Server Backup (supported) or third-party (Veeam, Commvault)
- Back up databases AND transaction logs
- Lagged copies provide a recovery window for logical corruption
- Test restore regularly (at least quarterly)
- Maintain offline backup copy for ransomware recovery

### Recovery Procedures

```powershell
# Recover deleted mailbox (within 30-day retention)
Connect-Mailbox -Identity "MailboxGuid" -Database DB01 -User "ADUser"

# Recovery database (restore from backup and extract data)
New-MailboxDatabase -Recovery -Name RecoveryDB -Server EX01 -EdbFilePath "E:\Recovery\DB01.edb" -LogFolderPath "E:\Recovery\Logs"
Mount-Database -Identity RecoveryDB
New-MailboxRestoreRequest -SourceDatabase RecoveryDB -SourceStoreMailbox "user@contoso.com" -TargetMailbox "user@contoso.com"
```
