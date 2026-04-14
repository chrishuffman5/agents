# Exchange Diagnostics

## Database and DAG Issues

### Database Copy Failures

| Status | Meaning | Fix |
|---|---|---|
| `Failed` | Replication failed, copy diverged | Check event logs, reseed the copy |
| `FailedAndSuspended` | Failed and auto-suspended by system | Fix underlying issue, then resume |
| `Suspended` | Manually or automatically suspended | Resume after maintenance: `Resume-MailboxDatabaseCopy` |
| `Seeding` | Initial or reseed copy in progress | Wait for completion; monitor with `Get-MailboxDatabaseCopyStatus` |
| `Disconnected` | Cannot reach source server | Check network, cluster health, DAG membership |
| `Initializing` | Copy starting up | Normal during server start; if persistent, check cluster |

```powershell
# Check all database copy status
Get-MailboxDatabaseCopyStatus * | Where {$_.Status -ne "Mounted" -and $_.Status -ne "Healthy"} | Select Identity, Status, CopyQueueLength, ReplayQueueLength, ContentIndexState

# Reseed a failed copy
Suspend-MailboxDatabaseCopy -Identity DB01\EX02
Update-MailboxDatabaseCopy -Identity DB01\EX02 -DeleteExistingFiles

# Check for diverged copies
Get-MailboxDatabaseCopyStatus DB01\* | Select Identity, Status, LastLogGenerated, LastLogCopied, LastLogReplayed
```

### High CopyQueueLength

CopyQueueLength > 10 indicates replication lag:

1. Check network between DAG members: `Test-ReplicationHealth -Server EX01`
2. Check disk I/O on target server: Performance Monitor > PhysicalDisk > Avg. Disk sec/Write
3. Check for stuck content indexing: `Get-MailboxDatabaseCopyStatus | Select Identity, ContentIndexState`
4. If ContentIndexState is `FailedAndSuspended`, rebuild: `Update-MailboxDatabaseCopy -Identity DB01\EX02 -CatalogOnly`

### Database Won't Mount

```powershell
# Check database state
Get-MailboxDatabase -Status | Select Name, Mounted, DatabaseSize, EdbFilePath

# Check event logs
Get-WinEvent -LogName "MSExchange Replication" -MaxEvents 20

# Force mount (skip health checks -- use only in emergencies)
Mount-Database -Identity DB01 -Force

# Check for dirty shutdown
eseutil /mh "E:\Databases\DB01\DB01.edb" | findstr "State"
# If "Dirty Shutdown", replay logs:
eseutil /r E00 /l "E:\Databases\DB01\Logs" /d "E:\Databases\DB01"
```

### Quorum Loss

If the DAG loses quorum (majority of voters unavailable):
- All databases dismount
- No automatic failover possible

```powershell
# Check cluster quorum
Get-DatabaseAvailabilityGroup DAG1 -Status | Select Name, WitnessServer, WitnessShareInUse, OperationalServers

# Force quorum with surviving nodes (datacenter switchover)
Stop-DatabaseAvailabilityGroup -Identity DAG1 -ActiveDirectorySite "PrimarySite"
Restore-DatabaseAvailabilityGroup -Identity DAG1 -ActiveDirectorySite "DRSite"
```

---

## Transport and Mail Flow Issues

### Mail Stuck in Queue

```powershell
# Check queue status
Get-Queue -Server EX01 | Select Identity, Status, MessageCount, NextHopDomain, LastError

# Common queue errors:
# "451 4.7.0 Temporary server error" -- downstream server unavailable
# "452 4.3.1 Insufficient system resources" -- backpressure
# "421 4.4.1 Connection timed out" -- network/DNS issue

# Retry all queued messages
Retry-Queue -Server EX01 -Filter {Status -eq "Retry"}

# Delete poison messages (last resort)
Get-Message -Queue EX01\Unreachable | Remove-Message -WithNDR $true
```

### Transport Rule Not Applying

1. Check rule is enabled and priority is correct:
```powershell
Get-TransportRule | Select Name, Priority, State | Sort Priority
```
2. Check rule conditions match the message scenario
3. Check for exceptions that exclude the message
4. Use message trace to verify rule evaluation:
```powershell
Get-MessageTrace -SenderAddress sender@contoso.com -StartDate (Get-Date).AddHours(-4) -EndDate (Get-Date) | Get-MessageTraceDetail | Where {$_.Event -eq "Transport rule"}
```

### Back Pressure (Insufficient Resources)

Exchange throttles message submission when resources are low:

| Resource | Medium threshold | High threshold |
|----------|-----------------|----------------|
| Database used space | 180 GB | 200 GB |
| Transport queue DB | 2 GB | 4 GB |
| Available memory | < 94% used | < 96% used |
| Commit memory | -- | > 95% used |

```powershell
# Check back pressure
Get-ServerComponentState -Identity EX01 -Component HubTransport
Get-EventLog -LogName Application -Source "MSExchange Back Pressure" -Newest 10

# Immediate relief: increase transport database size limit
Set-TransportServer -Identity EX01 -MessageTrackingLogMaxDirectorySize 2GB
```

### NDR / Bounce Troubleshooting

| DSN Code | Meaning | Common Fix |
|---|---|---|
| `5.1.1` | Mailbox not found | Verify recipient address, check accepted domains |
| `5.1.3` | Invalid address format | Check address syntax |
| `5.2.2` | Mailbox full | Increase quota or clean mailbox |
| `5.4.1` | No MX or A record | Check DNS for recipient domain |
| `5.7.1` | Relay denied | Check relay restrictions, auth status |
| `5.7.54` | SMTP AUTH disabled | Enable via security defaults or connector config |
| `4.4.1` | Connection timed out | Check DNS, firewall, target server availability |
| `4.7.0` | Temporary TLS failure | Check certificates, TLS configuration |

---

## Hybrid Troubleshooting

### HCW Failures

```powershell
# HCW log location
Get-ChildItem "$env:APPDATA\Microsoft\Exchange Hybrid Configuration\*.log" | Sort LastWriteTime -Descending | Select -First 1

# Common HCW errors:
# "Subtask Configure failed" -- Check OAuth certificate, federation trust
# "Unable to resolve Autodiscover" -- Verify external DNS resolution
# "Certificate validation failed" -- Ensure third-party cert (not self-signed) on Exchange
```

### Free/Busy Not Working

```powershell
# Test from on-premises
Test-OrganizationRelationship -UserIdentity onpremuser@contoso.com -Identity "Exchange Online" -Verbose

# Check OAuth
Test-OAuthConnectivity -Service EWS -TargetUri https://outlook.office365.com/ews/exchange.asmx -Mailbox user@contoso.com

# Common causes:
# - OAuth certificate expired (recreate with New-AuthServer/Set-AuthServer)
# - Availability address space misconfigured
# - Firewall blocking EWS traffic to outlook.office365.com
```

### Hybrid Mail Flow Issues

```powershell
# Check hybrid connectors
Get-SendConnector | Where {$_.AddressSpaces -like "*office365*"} | Select Name, SmartHosts, TlsAuthLevel
Get-ReceiveConnector | Where {$_.Name -like "*Hybrid*"} | Select Name, TlsCertificateName, RemoteIPRanges

# Common issues:
# - Certificate mismatch between on-prem and cloud connector
# - Firewall blocking port 25 between on-prem and EOP
# - DNS resolution failure for on-prem MX from cloud
```

---

## Migration Troubleshooting

### Move Request Failures

```powershell
# Check failed move requests
Get-MoveRequest -MoveStatus Failed | Get-MoveRequestStatistics | Select DisplayName, FailureCode, Message

# Common failure codes:
# MapiExceptionCorruptData -- Corrupt item in source mailbox. Increase BadItemLimit.
# MapiExceptionLockViolation -- Source mailbox locked. Retry during off-hours.
# OverQuota -- Target mailbox quota exceeded. Increase quota or archive.
# CommunicationError -- Network timeout. Check MRS Proxy connectivity.

# Increase bad item limit and resume
Set-MoveRequest -Identity user@contoso.com -BadItemLimit 100 -AcceptLargeDataLoss
Resume-MoveRequest -Identity user@contoso.com
```

### Migration Batch Stuck at Syncing

```powershell
# Check individual user status
Get-MigrationUser -BatchId "Wave1" | Where {$_.Status -eq "Syncing"} | Select EmailAddress, ItemsSkipped, Error

# If stuck > 24 hours:
# 1. Check migration endpoint connectivity
Test-MigrationServerAvailability -ExchangeRemoteMove -RemoteServer mail.contoso.com -Credentials (Get-Credential)

# 2. Restart MRS on on-premises Exchange
Restart-Service MSExchangeMailboxReplication

# 3. Remove and recreate stuck user in batch
Remove-MigrationUser -Identity user@contoso.com
```

### IMAP Migration Issues

| Issue | Cause | Fix |
|---|---|---|
| Only inbox migrated | IMAP source requires LIST command for subfolders | Use `IncludeSubFolders` parameter |
| Calendar/contacts missing | IMAP is email-only | Use platform-specific migration (not IMAP) |
| Authentication failed | Source requires app password with 2FA | Generate app-specific password |
| Throttled by source | Too many concurrent connections | Reduce `MaxConcurrentMigrations` |

---

## EOP and Defender Issues

### Legitimate Email Going to Junk

```powershell
# Check message trace for filtering verdict
Get-MessageTrace -RecipientAddress user@contoso.com -StartDate (Get-Date).AddDays(-1) | Get-MessageTraceDetail | Where {$_.Event -like "*spam*" -or $_.Event -like "*filter*"}

# Check anti-spam policy SCL thresholds
Get-HostedContentFilterPolicy | Select Name, SpamAction, HighConfidenceSpamAction, BulkThreshold

# Add to tenant allow list (temporary, 30 days max)
New-TenantAllowBlockListItems -ListType Sender -Entries "trusted@partner.com" -Allow
```

### Safe Attachments Blocking Legitimate Files

```powershell
# Check Safe Attachments policy
Get-SafeAttachmentPolicy | Select Name, Action, Enable

# Common fix: Use Dynamic Delivery action instead of Block
# Dynamic Delivery delivers email body immediately, scans attachment in background
Set-SafeAttachmentPolicy -Identity "Standard Protection" -Action DynamicDelivery
```

### Quarantine Management

```powershell
# View quarantined messages
Get-QuarantineMessage -StartReceivedDate (Get-Date).AddDays(-7) | Select Subject, SenderAddress, RecipientAddress, QuarantineTypes

# Release specific message
Release-QuarantineMessage -Identity <MessageIdentity> -ReleaseToAll

# Preview quarantined message
Preview-QuarantineMessage -Identity <MessageIdentity>

# Bulk release
Get-QuarantineMessage -SenderAddress trusted@partner.com | Release-QuarantineMessage -ReleaseToAll
```

---

## Connectivity and Certificate Issues

### Certificate Errors

| Symptom | Likely Cause | Fix |
|---|---|---|
| `449 4.7.0 STARTTLS failed` | Certificate expired or wrong cert bound to SMTP | Renew and re-enable: `Enable-ExchangeCertificate -Services SMTP` |
| Outlook "certificate name mismatch" | External hostname not in cert SAN | Get new cert with all required SANs |
| OWA certificate warning | IIS binding pointing to wrong cert | Rebind in IIS Manager or `Set-OwaVirtualDirectory` |
| Hybrid connector TLS failure | Certificate thumbprint mismatch | Re-run HCW to update connector certificates |

### Outlook Connectivity

```powershell
# Test MAPI connectivity
Test-MAPIConnectivity -Server EX01

# Test Outlook connectivity (Autodiscover + MAPI)
Test-OutlookConnectivity -Protocol HTTP -GetDefaultsFromAutodiscover

# If Outlook cannot connect:
# 1. Verify Autodiscover: nslookup -type=cname autodiscover.contoso.com
# 2. Check virtual directory URLs:
Get-OutlookAnywhere | Select Server, ExternalHostname, InternalHostname
Get-OwaVirtualDirectory | Select Server, InternalUrl, ExternalUrl
Get-EcpVirtualDirectory | Select Server, InternalUrl, ExternalUrl
```
