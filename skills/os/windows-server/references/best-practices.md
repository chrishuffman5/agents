# Windows Server Best Practices Reference

## Post-Installation Hardening

### CIS Benchmark Key Settings

**Password Policy:**
| Setting | CIS L1 Value |
|---|---|
| Minimum password length | 14 characters |
| Maximum password age | 60 days |
| Password complexity | Enabled |
| Enforce password history | 24 passwords |

**Account Lockout:** 5 invalid attempts, 15-minute lockout and reset.

**Audit Policy (enable via `auditpol /set`):**
```powershell
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Account Lockout" /failure:enable
auditpol /set /subcategory:"Sensitive Privilege Use" /success:enable /failure:enable
auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable
auditpol /set /subcategory:"Audit Policy Change" /success:enable /failure:enable
auditpol /set /subcategory:"System Integrity" /success:enable /failure:enable
```

**User Rights Restrictions:**
- "Allow log on locally": Administrators only (member servers)
- "Act as part of the operating system": No accounts (blank)
- "Debug programs": Administrators only (remove on non-DC servers)
- "Deny access from network": Guests, Local account

### Disable Unnecessary Services

```powershell
$servicesToDisable = @(
    'Browser',          # Computer Browser -- legacy NetBIOS
    'RemoteRegistry',   # Remote Registry -- unless managed remotely
    'Spooler',          # Print Spooler -- disable on non-print servers (PrintNightmare)
    'XblAuthManager',   # Xbox Live Auth -- non-gaming servers
    'XblGameSave',      # Xbox Game Save
    'XboxNetApiSvc'     # Xbox Live Networking
)
foreach ($svc in $servicesToDisable) {
    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
}
```

### Windows Firewall

```powershell
# Enable all profiles, block inbound by default
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
Set-NetFirewallProfile -Profile Domain,Public,Private `
    -DefaultInboundAction Block -DefaultOutboundAction Allow `
    -LogAllowed True -LogBlocked True `
    -LogFileName "%SystemRoot%\System32\LogFiles\Firewall\pfirewall.log" `
    -LogMaxSizeKilobytes 32767

# Allow RDP from management VLAN only
New-NetFirewallRule -DisplayName "RDP - Management Only" `
    -Direction Inbound -Protocol TCP -LocalPort 3389 `
    -RemoteAddress "10.0.0.0/24" -Action Allow -Profile Domain

# Allow WinRM
New-NetFirewallRule -DisplayName "WinRM - Management" `
    -Direction Inbound -Protocol TCP -LocalPort 5985,5986 `
    -RemoteAddress "10.0.0.0/24" -Action Allow -Profile Domain
```

### SMBv1 and NLA

```powershell
# Disable SMBv1
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

# Enable NLA for RDP
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
    -Name "UserAuthentication" -Value 1
```

### TLS Hardening

```powershell
# Disable TLS 1.0 and 1.1 Server
foreach ($proto in @('TLS 1.0', 'TLS 1.1')) {
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$proto\Server"
    New-Item -Path $path -Force | Out-Null
    Set-ItemProperty -Path $path -Name "Enabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $path -Name "DisabledByDefault" -Value 1 -Type DWord
}

# Enable TLS 1.2 explicitly
$tls12Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
New-Item -Path $tls12Path -Force | Out-Null
Set-ItemProperty -Path $tls12Path -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $tls12Path -Name "DisabledByDefault" -Value 0 -Type DWord

# Disable RC4 and 3DES ciphers
$cipherPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers"
@("RC4 128/128", "RC4 64/128", "RC4 56/128", "RC4 40/128", "Triple DES 168") | ForEach-Object {
    $p = "$cipherPath\$_"
    New-Item -Path $p -Force | Out-Null
    Set-ItemProperty -Path $p -Name "Enabled" -Value 0 -Type DWord
}
```

Server 2022+ disables TLS 1.0/1.1 by default and enables TLS 1.3. Server 2016/2019 require manual hardening. Use IISCrypto (Nartac) for GUI-based configuration.

---

## Group Policy Best Practices

### OU Structure

```
Domain
  +-- Servers
  |   +-- MemberServers     <- Base Server GPO linked here
  |   |   +-- AppServers
  |   |   +-- FileServers
  |   |   +-- WebServers
  |   |   +-- DatabaseServers
  |   +-- DomainControllers  <- DC-specific GPO (separate from Default DC Policy)
  +-- Workstations
```

### Key Design Principles

- Link the fewest GPOs possible at each level; prefer a single well-structured GPO per tier
- Use Enforced (No Override) only for non-negotiable security settings
- Use Block Inheritance sparingly (admin or isolated test OUs only)
- Name GPOs with prefixes: `SEC-`, `APP-`, `BASE-` for clarity
- Use Item-Level Targeting for Preferences items (CPU-efficient); WMI filters only when ILT is insufficient

### Security Baselines

Download Microsoft Security Compliance Toolkit (SCT):
```powershell
# Import baseline using LGPO.exe (part of SCT)
LGPO.exe /g ".\GPOs\{GUID-of-baseline}"

# Compare with PolicyAnalyzer.exe
PolicyAnalyzer.exe /l ".\Baselines\WS2022-Member-Server-Baseline.PolicyRules"
```

### Recommended Baseline GPOs

- `BASE-MemberServer-Security` -- Password/audit/user rights from CIS/SCT
- `BASE-MemberServer-WinFW` -- Firewall profile configuration
- `BASE-MemberServer-TLS` -- TLS registry settings via GP Preferences
- `BASE-MemberServer-EventLog` -- Event log size and retention
- `BASE-DC-Security` -- Separate from Default Domain Controllers Policy
- `BASE-DC-Auditing` -- Enhanced DS Access, Account Management auditing

---

## Patching and Update Management

### WSUS Architecture

WSUS database on SQL Server (not WID) for >500 clients. Decline superseded updates monthly:
```powershell
Get-WsusUpdate -Classification All -Approval AnyExceptDeclined -Status Any |
    Where-Object {$_.Update.IsSuperseded -eq $true} | Deny-WsusUpdate
```

### Monthly Cadence

- **Patch Tuesday (B release)**: Second Tuesday -- cumulative quality + security
- **C/D Preview**: Third/fourth week -- non-security preview for validation
- **Out-of-band**: Emergency zero-day -- deploy within 24-72 hours

### Deployment Rings

1. B+0: Lab/Dev ring receives immediately
2. B+7: Pilot ring (representative production subset)
3. B+14: Production Wave 1
4. B+21: Production Wave 2

### Hotpatch (Server 2025)

Quarterly baseline (reboot required) + monthly hotpatch (no reboot):
- January: Baseline CU (reboot)
- February: Hotpatch (no reboot)
- March: Hotpatch (no reboot)
- April: Baseline CU (reboot)

Requirements: Azure Arc enrollment + Hotpatch subscription ($1.50/core/month for non-Azure Edition). Azure Edition on Azure: included at no extra cost.

---

## Server Core vs Desktop Experience

### When to Use Server Core

Advantages: ~40% smaller attack surface, fewer patches, smaller disk/memory footprint.

Roles well-suited for Server Core: AD DS, AD LDS, DNS, DHCP, File Server, Hyper-V, IIS, WSUS, Failover Clustering.

### Roles Requiring Desktop Experience

RD Session Host, Remote Desktop Web Access, some third-party backup agents (verify current version support), WDS (management console not available in Core).

### Server Core Management

```powershell
sconfig                              # Interactive text menu for initial setup
Enable-PSRemoting -Force             # Enable PowerShell remoting
Enter-PSSession -ComputerName CORE01 # Remote management

# Install RSAT on management machine
Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
Add-WindowsCapability -Online -Name "Rsat.Dns.Tools~~~~0.0.1.0"
Add-WindowsCapability -Online -Name "Rsat.DHCP.Tools~~~~0.0.1.0"
```

---

## Windows Admin Center (WAC)

### Deployment Modes

| Mode | Use Case | Port |
|---|---|---|
| Desktop | Single admin workstation, lab | Local |
| Gateway Server | Shared team access, domain-joined server | 443 (HTTPS) |

```powershell
# Gateway install
Start-Process msiexec.exe -ArgumentList '/i WindowsAdminCenter.msi /qn /L*v wac-install.log SME_PORT=443 SSL_CERTIFICATE_OPTION=generate' -Wait
Get-Service -Name "ServerManagementGateway"
```

Replace the self-signed certificate with a CA-issued cert for shared gateway use. WAC port 443 conflicts with IIS on the same server.

---

## Monitoring and Alerting

### Event Forwarding (WEF)

```powershell
# On collector
wecutil qc /q

# On source (GPO): Computer Config > Admin Templates > Event Forwarding
# "Configure target Subscription Manager":
# Server=http://Collector.domain.local:5985/wsman/SubscriptionManager/WEC,Refresh=60
```

### Azure Monitor Agent (Hybrid)

```powershell
# Install AMA on Arc-enrolled server
azcmagent extension add --publisher Microsoft.Azure.Monitor --type AzureMonitorWindowsAgent

# Key channels: Security (4624, 4625, 4648, 4688, 4720, 4740), System, Application
# Key counters: Processor(%), Memory Available MBytes
```

---

## Backup and Recovery

### Windows Server Backup

```powershell
Install-WindowsFeature -Name Windows-Server-Backup

# Full server backup to network share
wbadmin start backup -backuptarget:\\NAS01\Backups -include:C: -quiet

# Bare Metal Recovery backup
wbadmin start backup -backuptarget:E: -allCritical -systemState -quiet

# Schedule daily backup
wbadmin enable backup -addtarget:\\NAS01\Backups -schedule:02:00 -include:C: -quiet
```

### System State for Domain Controllers

```powershell
# Daily system state backup (required for AD authoritative/non-authoritative restore)
wbadmin start systemstatebackup -backuptarget:E: -quiet

# Authoritative restore:
# 1. Boot to DSRM (F8)
# 2. wbadmin start systemstaterecovery -version:<version>
# 3. ntdsutil "authoritative restore" "restore subtree <DN>"
# 4. Reboot
```

### VSS Shadow Copies

```powershell
vssadmin create shadow /for=C:
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=10%
# At least 2 shadow copies per day for file servers
# Storage area: 10-15% of volume size minimum
```

### Backup Strategy

Follow the 3-2-1 rule: 3 copies, 2 media types, 1 offsite. Test restores monthly (quarterly minimum for full BMR). Encrypt backups at rest and in transit.

---

## Storage Best Practices

### NTFS vs ReFS Decision

| Criteria | NTFS | ReFS |
|---|---|---|
| Boot volume | Yes | No |
| Integrity checksums | No | Yes |
| Self-healing | chkdsk (offline) | Online, automatic |
| Hyper-V VHDX | Either | Preferred (block cloning) |
| S2D volumes | Either | Recommended |
| Max file size | 256 TB | 35 PB |

### Allocation Unit Sizes

```powershell
# General NTFS: 4096 (default)
# SQL Server data/log: 65536 (64K) -- critical for performance
# Hyper-V VHDX storage: 65536
# ReFS / S2D volumes: 65536
Format-Volume -DriveLetter D -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel "Data"
```

### Disk Alignment

Modern Windows (GPT) aligns partitions automatically. Verify:
```powershell
Get-Disk | Select-Object Number, PartitionStyle, AlignmentInBytes
```

---

## Networking Best Practices

### NIC Teaming vs SET

- Use LBFO for non-Hyper-V servers requiring NIC redundancy
- Use SET for Hyper-V hosts, especially with RDMA NICs
- Never team RDMA NICs with LBFO -- use SET instead

### SMB Configuration

```powershell
# Verify SMBv1 is disabled
Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol
# Must be False

# Enable encryption for sensitive shares
Set-SmbShare -Name 'SecureData' -EncryptData $true

# Enable SMB signing (required by default in 2022+)
Set-SmbServerConfiguration -RequireSecuritySignature $true
```

### DNS Best Practices

- Configure two or more DNS servers per NIC
- Use conditional forwarders for cross-forest resolution
- Enable DNS logging for troubleshooting: `Set-DnsServerDiagnostics -All $true`
- Monitor `nslookup` against each DNS server individually to isolate failures
