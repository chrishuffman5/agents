# AD DS Diagnostics and Troubleshooting

Troubleshooting playbooks, diagnostic commands, and event ID reference for Active Directory Domain Services.

---

## Essential Diagnostic Tools

### dcdiag (Domain Controller Diagnostics)

```powershell
# Run all tests on local DC
dcdiag /v

# Run all tests on all DCs in the domain
dcdiag /v /a

# Run all tests on all DCs in the forest
dcdiag /v /e

# Run specific test
dcdiag /test:replications
dcdiag /test:dns /v
dcdiag /test:fsmocheck
dcdiag /test:ridmanager

# Test specific DC
dcdiag /s:DC01.example.com /v
```

**Key dcdiag tests:**

| Test | What It Checks | Common Failures |
|---|---|---|
| `Connectivity` | LDAP and RPC connectivity to DC | Firewall blocking, DC offline, DNS failure |
| `Replications` | Replication status and errors | Replication failures, lingering objects |
| `Advertising` | DC is properly advertising via DNS | Missing SRV records, NetLogon service issue |
| `FrsEvent` / `DFSREvent` | SYSVOL replication health | DFS-R conflicts, journal wrap |
| `KccEvent` | KCC topology generation errors | Topology generation failures |
| `MachineAccount` | DC machine account health | Machine account password mismatch |
| `NCSecDesc` | Naming context security descriptors | Permissions issues on NC heads |
| `NetLogons` | Secure channel health | Trust relationship failures |
| `RidManager` | RID pool availability | RID pool depletion |
| `DNS` | DNS infrastructure for AD | Missing DNS records, delegation issues |
| `SystemLog` | Critical system event log errors | Hardware, service, or driver failures |

### repadmin (Replication Diagnostics)

```powershell
# Show replication status summary
repadmin /replsummary

# Show replication partners and status for all DCs
repadmin /showrepl *

# Show replication status for specific DC
repadmin /showrepl DC01.example.com

# Show replication queue
repadmin /queue *

# Force replication from all partners
repadmin /syncall DC01 /A /e /d /P

# Force replication of specific partition from specific partner
repadmin /replicate DC02.example.com DC01.example.com "DC=example,DC=com"

# Show metadata for specific object (useful for conflict resolution)
repadmin /showobjmeta DC01.example.com "CN=User1,OU=Users,DC=example,DC=com"

# Show up-to-dateness vector
repadmin /showutdvec DC01.example.com "DC=example,DC=com"

# Check for lingering objects
repadmin /removelingeringobjects DC02.example.com DC01_GUID "DC=example,DC=com" /advisory_mode
```

### nltest (Secure Channel and Trust Diagnostics)

```powershell
# Verify secure channel to domain
nltest /sc_verify:example.com

# Reset secure channel
nltest /sc_reset:example.com

# Query FSMO role holders
nltest /dclist:example.com

# Query trust status
nltest /domain_trusts /all_trusts /v

# Force DC discovery
nltest /dsgetdc:example.com /force
```

---

## Replication Troubleshooting

### Common Replication Errors

| Error Code | Description | Root Cause | Resolution |
|---|---|---|---|
| 8606 | Insufficient attributes to create object | Lingering objects | `repadmin /removelingeringobjects` |
| 8453 | Replication access denied | Permission issue | Check DC machine account, reset secure channel |
| 8524 | DSA operation unable to proceed | DNS failure | Verify DNS resolution, _msdcs zone delegation |
| 1256 | Remote system not available | Network connectivity | Firewall rules, DC offline, NIC issues |
| 1722 | RPC server unavailable | RPC connectivity failure | Check RPC endpoint mapper (135), dynamic ports |
| 1908 | Could not find DC for domain | DNS cannot resolve DC | Fix DNS records, check forwarders/root hints |
| 8451 | Replication operation failed due to database error | NTDS.dit corruption | Check disk, run `ntdsutil "semantic database analysis"` |
| 8614 | Replication disabled (tombstone violation) | DC exceeded tombstone lifetime | Remove DC metadata, rebuild from scratch |

### Replication Failure Workflow

```
1. Run: repadmin /replsummary
   - Identify which DCs have failures and error counts
   
2. Run: repadmin /showrepl <failing_DC>
   - Get specific error codes and last success times
   
3. Based on error:
   - DNS errors (8524, 1908) --> Check DNS resolution
     - nslookup <DC_FQDN>
     - nslookup -type=SRV _ldap._tcp.dc._msdcs.<domain>
   
   - RPC errors (1722, 1256) --> Check network/firewall
     - Test-NetConnection <DC_IP> -Port 135
     - portqry -n <DC_IP> -e 135
     
   - Permission errors (8453) --> Check machine account
     - nltest /sc_verify:<domain>
     - Reset-ComputerMachinePassword (PowerShell)
     
   - Lingering objects (8606) --> Remove lingering objects
     - repadmin /removelingeringobjects <dest_DC> <source_DC_GUID> <partition_DN> /advisory_mode
     - Review results, then run without /advisory_mode

4. After fixing: Force replication
   - repadmin /syncall /A /e /d /P
   
5. Verify: repadmin /replsummary (should show 0 failures)
```

---

## Critical Event IDs

### Authentication Events

| Event ID | Log | Description | Significance |
|---|---|---|---|
| 4624 | Security | Successful logon | Track logon types (2=interactive, 3=network, 10=RDP) |
| 4625 | Security | Failed logon | Brute force detection, account lockout investigation |
| 4648 | Security | Logon with explicit credentials | RunAs, scheduled tasks, potential lateral movement |
| 4768 | Security | Kerberos TGT requested (AS-REQ) | Authentication attempt; check encryption type for AS-REP roasting |
| 4769 | Security | Kerberos service ticket requested (TGS-REQ) | Service access; RC4 encryption type indicates Kerberoasting |
| 4771 | Security | Kerberos pre-authentication failed | Failed logon at Kerberos level |
| 4776 | Security | NTLM authentication (credential validation) | NTLM usage tracking (should be decreasing) |

### Account Management Events

| Event ID | Log | Description | Significance |
|---|---|---|---|
| 4720 | Security | User account created | New account monitoring |
| 4722 | Security | User account enabled | Re-enabled accounts |
| 4723/4724 | Security | Password change/reset | Password operations |
| 4728 | Security | Member added to security-enabled global group | Group membership changes |
| 4732 | Security | Member added to security-enabled local group | Local group changes |
| 4756 | Security | Member added to universal security group | Universal group changes |
| 4780 | Security | ACL set on admin account (AdminSDHolder) | AdminSDHolder propagation; unexpected triggers indicate attack |

### Privileged Operations

| Event ID | Log | Description | Significance |
|---|---|---|---|
| 4672 | Security | Special privileges assigned (admin logon) | Privileged session tracking |
| 4673 | Security | Privileged service called | Sensitive privilege use |
| 4688 | Security | New process created | With command-line logging enabled: detect malicious commands |
| 4698 | Security | Scheduled task created | Persistence mechanism detection |
| 4964 | Security | Special group logon (custom tracking) | Track logons by specific groups |

### Directory Service Events

| Event ID | Log | Description | Significance |
|---|---|---|---|
| 1083 | Directory Service | Replication error on naming context | Replication failure details |
| 1388/1988 | Directory Service | Lingering object detected | Lingering object in incoming/local partition |
| 2042 | Directory Service | Tombstone lifetime exceeded | DC has been offline too long |
| 2887 | Directory Service | LDAP unsigned binds | Security: unsigned LDAP binds should be disabled |
| 2889 | Directory Service | LDAP unsigned bind by specific client | Identify clients using unsigned LDAP |

### Group Policy Events

| Event ID | Log | Description | Significance |
|---|---|---|---|
| 1058 | System | Cannot access GPO (SYSVOL) | SYSVOL replication issue, DFS-R problem |
| 1030 | System | Cannot query for GPOs | DC connectivity issue |
| 7016 | Group Policy | GPO processing completed | Track GP application timing |
| 7017 | Group Policy | System call failed during GP processing | Specific extension failure |
| 4004 | Group Policy | Manual GP refresh started | gpupdate initiated |

---

## DNS Troubleshooting for AD

AD DS is critically dependent on DNS. Most AD issues are actually DNS issues.

### Required DNS Records

```powershell
# Verify all required SRV records exist
# These should be registered by the Netlogon service on each DC

# Domain controller SRV records
nslookup -type=SRV _ldap._tcp.dc._msdcs.example.com
nslookup -type=SRV _kerberos._tcp.dc._msdcs.example.com

# Site-specific SRV records
nslookup -type=SRV _ldap._tcp.SiteName._sites.dc._msdcs.example.com

# GC SRV records
nslookup -type=SRV _ldap._tcp.gc._msdcs.example.com

# PDC SRV record
nslookup -type=SRV _ldap._tcp.pdc._msdcs.example.com

# CNAME record for DC GUID
nslookup -type=CNAME <DC-GUID>._msdcs.example.com
```

### Common DNS Issues

| Issue | Symptom | Resolution |
|---|---|---|
| Missing SRV records | Clients cannot find DCs | Restart Netlogon service, check DNS zone permissions |
| Stale DNS records | Clients connect to decommissioned DCs | Enable DNS scavenging (7/7 day aging/scavenging) |
| Wrong DNS server on DC | Replication failures | DC should point to itself or another DC for DNS, never external |
| Missing _msdcs zone | Forest-wide service location fails | Re-create delegated _msdcs zone |
| DNS zone not AD-integrated | Zone replication independent of AD replication | Convert to AD-integrated for unified replication |

### DNS Health Check

```powershell
# Full DNS test via dcdiag
dcdiag /test:dns /v /e

# Check DNS registration
ipconfig /registerdns

# Verify zone contents
Get-DnsServerResourceRecord -ZoneName "example.com" -RRType SRV | Where-Object {$_.HostName -like "_ldap*"}

# Check forwarders
Get-DnsServerForwarder
```

---

## Authentication Failure Troubleshooting

### Account Lockout Investigation

```powershell
# Find lockout source (run on PDC Emulator)
Get-WinEvent -FilterHashtable @{LogName='Security';Id=4740} |
    Select-Object TimeCreated, @{N='User';E={$_.Properties[0].Value}},
    @{N='Source';E={$_.Properties[1].Value}}

# Or use the Account Lockout Status tool (LockoutStatus.exe)

# Check lockout status
Get-ADUser -Identity jdoe -Properties LockedOut,AccountLockoutTime,BadLogonCount,BadPasswordTime,LastBadPasswordAttempt

# Unlock account
Unlock-ADAccount -Identity jdoe

# Check lockout policy
Get-ADDefaultDomainPasswordPolicy
```

### Kerberos Troubleshooting

```powershell
# View cached Kerberos tickets
klist

# Purge Kerberos tickets (force re-authentication)
klist purge

# Check for duplicate SPNs
setspn -X

# Trace Kerberos events (enable on DC)
# Enable Kerberos operational log:
wevtutil set-log "Microsoft-Windows-Kerberos-Key-Distribution-Center/Operational" /enabled:true

# Check for NTLM fallback
# Event 4776 on DC indicates NTLM authentication (should investigate why not Kerberos)
```

### Trust Relationship Failures

```powershell
# Verify trust
Get-ADTrust -Filter * | Select-Object Name,Direction,TrustType,IntraForest

# Test trust
Test-ComputerSecureChannel -Server DC01.trusted.com -Verbose

# Verify trust authentication
nltest /sc_verify:trusted.com

# Repair trust
netdom trust example.com /domain:trusted.com /reset /passwordt:* /usero:admin /passwordo:*
```

---

## Performance Diagnostics

### NTDS Performance Counters

| Counter | Healthy Value | Investigation if Exceeded |
|---|---|---|
| `NTDS\LDAP Searches/sec` | Varies (baseline first) | Identify expensive queries via Field Engineering logging |
| `NTDS\LDAP Successful Binds/sec` | Varies | High values may indicate brute force |
| `Database\Database Cache % Hit` | >95% | Add RAM, investigate cache pressure |
| `Database\Database Cache Size (MB)` | Varies | Monitor for unexpected drops |
| `NTDS\DRA Inbound Bytes Total/sec` | Varies | Baseline and alert on spikes (large replication) |
| `NTDS\ATQ Threads LDAP` | <Max threads | Thread exhaustion indicates overloaded DC |

### Expensive LDAP Query Detection

```powershell
# Enable Field Engineering diagnostics (registry)
# HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics
# Set "15 Field Engineering" = 5
# Set "Expensive Search Results Threshold" = 10000  (DWORD)
# Set "Inefficient Search Results Threshold" = 1000  (DWORD)
# Set "Search Time Threshold (msecs)" = 100         (DWORD)

# Events will appear in Directory Service log:
# Event 1644 -- Expensive/inefficient LDAP query details
```

---

## Backup and Recovery

### AD DS Backup Requirements

- **System State backup** -- Includes AD DS database, SYSVOL, registry, boot files, COM+ class registration, certificate services (if installed)
- **Backup frequency** -- Must be more frequent than tombstone lifetime (default 180 days). Recommended: daily.
- **Authoritative restore** -- Overrides replication by incrementing version numbers on restored objects. Required when recovering accidentally deleted OUs/objects (if AD Recycle Bin is not enabled).

### Recovery Scenarios

| Scenario | Approach | Commands |
|---|---|---|
| Deleted user/OU (Recycle Bin enabled) | Restore from Recycle Bin | `Get-ADObject -Filter {isDeleted -eq $true} -IncludeDeletedObjects \| Restore-ADObject` |
| Deleted user/OU (no Recycle Bin) | Authoritative restore from backup | Boot to DSRM, restore System State, `ntdsutil "authoritative restore"` |
| Corrupted DC | Non-authoritative restore or rebuild | Restore System State or demote/re-promote |
| Total AD loss | Forest recovery | Microsoft forest recovery procedure (isolate, restore DCs per domain, verify, reconnect) |
| FSMO role holder failed | Seize role | `Move-ADDirectoryServerOperationMasterRole -Identity DC02 -OperationMasterRole PDCEmulator -Force` |
