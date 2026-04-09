# Windows Server Best Practices — Research Notes
# Cross-Version: 2016 / 2019 / 2022 / 2025
# Prepared for Opus writer agent

---

## 1. Post-Installation Hardening

### 1.1 CIS Benchmark Key Settings

**Password Policy (Computer Configuration > Windows Settings > Security Settings > Account Policies)**

| Setting | CIS L1 Recommended Value |
|---|---|
| Minimum password length | 14 characters |
| Maximum password age | 60 days (or shorter) |
| Minimum password age | 1 day |
| Password complexity | Enabled |
| Enforce password history | 24 passwords remembered |
| Store passwords using reversible encryption | Disabled |

**Account Lockout Policy**

| Setting | Recommended Value |
|---|---|
| Account lockout threshold | 5 invalid attempts |
| Account lockout duration | 15 minutes |
| Reset account lockout counter after | 15 minutes |

**Audit Policy (Advanced Audit Policy Configuration)**

Enable via `auditpol /set`:
```powershell
# Logon/Logoff
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Logoff" /success:enable
auditpol /set /subcategory:"Account Lockout" /failure:enable

# Object Access
auditpol /set /subcategory:"File System" /success:enable /failure:enable
auditpol /set /subcategory:"Registry" /success:enable /failure:enable

# Privilege Use
auditpol /set /subcategory:"Sensitive Privilege Use" /success:enable /failure:enable

# Account Management
auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable
auditpol /set /subcategory:"Security Group Management" /success:enable /failure:enable

# Policy Change
auditpol /set /subcategory:"Audit Policy Change" /success:enable /failure:enable

# System
auditpol /set /subcategory:"Security System Extension" /success:enable /failure:enable
auditpol /set /subcategory:"System Integrity" /success:enable /failure:enable
```

**User Rights Assignments (key restrictions)**
- "Access this computer from network": Administrators, Authenticated Users (remove Everyone)
- "Allow log on locally": Administrators only (member servers)
- "Allow log on through Remote Desktop Services": Administrators, specific RDP group
- "Act as part of the operating system": No accounts (blank)
- "Debug programs": Administrators only (remove from non-DC servers entirely)
- "Deny access to this computer from the network": Guests, Local account (built-in)

### 1.2 STIG Baseline Recommendations

Key Windows Server STIG controls (DISA STIG V-series):
- V-93141: Configure Event Log sizes (Security: 196608 KB minimum, System/Application: 32768 KB)
- V-93363: Enable DEP (Data Execution Prevention) — OptOut mode minimum
- V-93369: Disable autoplay for all drives
- V-93373: Disable Windows Installer Always install with elevated privileges
- V-93291: Configure legal notice (logon banner — Interagency Advisory on Notice and Consent)
- V-93285: Disable Anonymous SID/Name Translation

```powershell
# Set Event Log sizes
wevtutil sl Security /ms:196608000
wevtutil sl System /ms:32768000
wevtutil sl Application /ms:32768000

# Enable DEP OptOut (BCDEdit)
bcdedit /set nx OptOut

# Disable autoplay
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
  -Name "NoDriveTypeAutoRun" -Value 255 -Type DWord
```

### 1.3 Disable Unnecessary Services

Services to disable on member servers (not all apply to every role):

```powershell
$servicesToDisable = @(
    'Browser',          # Computer Browser — legacy NetBIOS
    'IISADMIN',         # IIS Admin — if not running IIS
    'RemoteRegistry',   # Remote Registry — disable unless managed remotely
    'Spooler',          # Print Spooler — disable on non-print servers (PrintNightmare)
    'WinHttpAutoProxySvc', # WinHTTP Web Proxy Auto-Discovery — if no proxy
    'XblAuthManager',   # Xbox Live Auth — non-gaming servers
    'XblGameSave',      # Xbox Game Save — non-gaming servers
    'XboxNetApiSvc',    # Xbox Live Networking — non-gaming servers
    'WerSvc',           # Windows Error Reporting — if WSUS/MECM handles this
    'lltdsvc'           # Link-Layer Topology Discovery — if not needed
)

foreach ($svc in $servicesToDisable) {
    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
}
```

### 1.4 Windows Firewall with Advanced Security

```powershell
# Enable all profiles
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Set default inbound to block, outbound to allow
Set-NetFirewallProfile -Profile Domain,Public,Private `
    -DefaultInboundAction Block `
    -DefaultOutboundAction Allow `
    -LogAllowed True `
    -LogBlocked True `
    -LogFileName "%SystemRoot%\System32\LogFiles\Firewall\pfirewall.log" `
    -LogMaxSizeKilobytes 32767

# Allow RDP only from management VLAN (example: 10.0.0.0/24)
New-NetFirewallRule -DisplayName "RDP - Management Only" `
    -Direction Inbound -Protocol TCP -LocalPort 3389 `
    -RemoteAddress "10.0.0.0/24" -Action Allow -Profile Domain

# Allow WinRM for remote management
New-NetFirewallRule -DisplayName "WinRM - Management" `
    -Direction Inbound -Protocol TCP -LocalPort 5985,5986 `
    -RemoteAddress "10.0.0.0/24" -Action Allow -Profile Domain
```

### 1.5 Enable NLA for RDP, Disable SMBv1

```powershell
# Enable Network Level Authentication for RDP
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
    -Name "UserAuthentication" -Value 1

# Disable SMBv1 (Server and Client)
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

# Verify SMB configuration
Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol, EnableSMB2Protocol, RequireSecuritySignature
```

### 1.6 TLS Configuration

```powershell
# Disable TLS 1.0 Server
$tls10Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"
New-Item -Path $tls10Path -Force | Out-Null
Set-ItemProperty -Path $tls10Path -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $tls10Path -Name "DisabledByDefault" -Value 1 -Type DWord

# Disable TLS 1.1 Server
$tls11Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"
New-Item -Path $tls11Path -Force | Out-Null
Set-ItemProperty -Path $tls11Path -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $tls11Path -Name "DisabledByDefault" -Value 1 -Type DWord

# Enable TLS 1.2 explicitly
$tls12Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
New-Item -Path $tls12Path -Force | Out-Null
Set-ItemProperty -Path $tls12Path -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $tls12Path -Name "DisabledByDefault" -Value 0 -Type DWord

# Enable TLS 1.3 (Server 2022 and 2025)
$tls13Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server"
New-Item -Path $tls13Path -Force | Out-Null
Set-ItemProperty -Path $tls13Path -Name "Enabled" -Value 1 -Type DWord

# Cipher suite ordering via GPO preferred; manual example:
# Disable RC4 and 3DES
$cipherPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers"
@("RC4 128/128", "RC4 64/128", "RC4 56/128", "RC4 40/128", "Triple DES 168") | ForEach-Object {
    $p = "$cipherPath\$_"
    New-Item -Path $p -Force | Out-Null
    Set-ItemProperty -Path $p -Name "Enabled" -Value 0 -Type DWord
}
```

IISCrypto (Nartac) tool recommended for GUI-based configuration in production environments.

---

## 2. Group Policy Best Practices

### 2.1 GPO Design: OU Structure and Inheritance

Recommended OU hierarchy for member servers:
```
Domain
├── _Admin (block GPO inheritance — admin workstations)
├── Servers
│   ├── MemberServers        ← Base Server GPO linked here
│   │   ├── AppServers
│   │   ├── FileServers
│   │   ├── WebServers
│   │   └── DatabaseServers
│   └── DomainControllers    ← DC-specific GPO (separate from Default DC Policy)
└── Workstations
```

Key design principles:
- Link the **fewest GPOs possible** at each level; prefer a single well-structured GPO per tier
- Use **Enforced (No Override)** only for non-negotiable security settings (avoids runaway inheritance blocking)
- Use **Block Inheritance** sparingly — typically only for _Admin or isolated test OUs
- Scope computer settings at computer OUs, user settings at user OUs (link loopback processing for server roles where user settings matter)
- Name GPOs with prefixes: `SEC-`, `APP-`, `BASE-` for clarity

### 2.2 Security Baselines — Microsoft Security Compliance Toolkit

Download from: https://www.microsoft.com/en-us/download/details.aspx?id=55319

```powershell
# Import baseline using LGPO.exe (part of SCT)
LGPO.exe /g ".\GPOs\{GUID-of-baseline}"

# PolicyAnalyzer.exe — compare current policy to baseline
# Compare baseline to current effective policy
PolicyAnalyzer.exe /l ".\Baselines\WS2022-Member-Server-Baseline.PolicyRules"
```

Available baselines (SCT):
- Windows Server 2025 Security Baseline
- Windows Server 2022 Security Baseline
- Windows Server 2019 Security Baseline
- Windows Server 2016 Security Baseline
- Microsoft 365 Apps for Enterprise Security Baseline

### 2.3 Administrative Template Management

```powershell
# Update Central Store with latest ADMX templates
# Copy from C:\Windows\PolicyDefinitions on a reference machine
$admxSource = "C:\Windows\PolicyDefinitions"
$centralStore = "\\domain.local\SYSVOL\domain.local\Policies\PolicyDefinitions"
Copy-Item -Path "$admxSource\*" -Destination $centralStore -Recurse -Force

# Best practice: maintain a versioned ADMX pack from Microsoft Download Center
# Download from: https://www.microsoft.com/en-us/download/details.aspx?id=105667 (WS2025)
```

### 2.4 GPO Performance

```powershell
# Check GPO processing time on a client
Get-WinEvent -LogName "Microsoft-Windows-GroupPolicy/Operational" |
    Where-Object {$_.Id -eq 8004} |
    Select-Object TimeCreated, Message -First 20

# WMI Filter best practice: keep WMI queries simple, test with wbemtest
# Example WMI filter for Server 2022 only:
# SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "10.0.20348%"

# Slow link detection threshold (default 500 Kbps)
# GPO: Computer Config > Admin Templates > System > Group Policy
# "Configure Group Policy slow link detection" — set to 0 to always process all settings

# Disable Group Policy Loopback Processing unless required (adds ~30% processing overhead)
```

Item-Level Targeting (ILT) vs. WMI Filters:
- Use ILT for Preferences items (CPU-efficient, evaluated client-side per item)
- Use WMI filters only when ILT is insufficient (WMI filters apply to entire GPO)
- Avoid complex nested WMI queries — benchmark with 10+ clients before deploying

### 2.5 Recommended Baseline GPOs

**Member Servers:**
- `BASE-MemberServer-Security` — password/audit/user rights from CIS/SCT
- `BASE-MemberServer-WinFW` — firewall profile configuration
- `BASE-MemberServer-TLS` — TLS registry settings via GP Preferences
- `BASE-MemberServer-EventLog` — event log size and retention

**Domain Controllers:**
- `BASE-DC-Security` — separate from Default Domain Controllers Policy
- `BASE-DC-Auditing` — enhanced auditing (DS Access, Account Management)
- `BASE-DC-SysvolReplication` — DFS-R health settings

---

## 3. Patching and Update Management

### 3.1 WSUS Architecture

Recommended topology for enterprise:
```
WSUS Upstream (Autonomous/Replica)
├── WSUS Downstream — Site A
├── WSUS Downstream — Site B
└── WSUS Downstream — Site C
```

WSUS database on SQL Server (not WID) for environments >500 clients:

```powershell
# Check WSUS sync status
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()
$wsus.GetSubscription().GetLastSynchronizationInfo()

# Decline superseded updates (run monthly)
Get-WsusUpdate -Classification All -Approval AnyExceptDeclined -Status Any |
    Where-Object {$_.Update.IsSuperseded -eq $true} |
    Deny-WsusUpdate

# WSUS maintenance — run spDeleteObsoleteUpdates (SQL stored procedure)
# Schedule weekly via SQL Agent or script:
Invoke-Sqlcmd -ServerInstance "WSUSDB" -Database "SUSDB" `
    -Query "EXEC spDeleteObsoleteUpdates" -QueryTimeout 7200
```

Product selections to approve for Windows Server:
- Windows Server 2016 / 2019 / 2022 / 2025
- Microsoft Defender Antivirus
- Office (if applicable)
- SQL Server (if patching via WSUS)

### 3.2 Windows Update for Business (WUfB)

Suitable for Azure AD-joined or hybrid-joined servers without WSUS infrastructure:

```powershell
# Configure via GPO or MDM (Intune)
# Key registry paths:
$wufbPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
Set-ItemProperty -Path $wufbPath -Name "DeferQualityUpdates" -Value 1
Set-ItemProperty -Path $wufbPath -Name "DeferQualityUpdatesPeriodInDays" -Value 7

# Target version control
Set-ItemProperty -Path $wufbPath -Name "TargetReleaseVersion" -Value 1
Set-ItemProperty -Path $wufbPath -Name "TargetReleaseVersionInfo" -Value "Windows Server 2022"
```

### 3.3 SCCM/MECM Patching Workflow

Recommended Software Update Point (SUP) configuration:
1. Synchronize products: Windows Server 2016/2019/2022/2025, Defender, Office
2. Classifications: Critical, Security, Updates, Service Packs, Upgrade (for major upgrades)
3. Create Software Update Groups (SUG) by month: `2026-03 Security Updates`
4. Deployment rings: Pilot (5%) → Production Wave 1 (25%) → Production Wave 2 (70%)
5. Maintenance windows: Define per collection, align with business change windows

```powershell
# MECM: Create monthly ADR (Automatic Deployment Rule)
# Via PowerShell module (ConfigurationManager):
Import-Module $env:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1
Set-Location "$SiteCode`:"
New-CMSoftwareUpdateAutoDeploymentRule -Name "Monthly-Servers-Security" `
    -CollectionName "All Windows Servers" `
    -AddToExistingSoftwareUpdateGroup $false `
    -EnabledAfterCreate $true
```

### 3.4 Monthly Update Cadence

- **B Release (Patch Tuesday):** Second Tuesday of each month — cumulative quality + security
- **C/D Preview (Optional/Out-of-band):** Third/fourth week — non-security preview, validate before next B
- **Out-of-band:** Emergency releases (critical zero-day) — deploy within 24–72 hours per risk

Recommended testing cadence:
1. B+0: Lab/Dev ring receives update immediately
2. B+7: Pilot ring (representative production subset)
3. B+14: Production Wave 1
4. B+21: Production Wave 2

### 3.5 Hotpatch (Windows Server 2025)

Hotpatch enables installation of security updates without a server reboot (for eligible updates):

Requirements:
- Windows Server 2025 Datacenter: Azure Edition
- Azure Arc enrollment (for on-premises)
- Hotpatch subscription activated
- Updates must be Microsoft-produced cumulative updates for eligible months

```powershell
# Check Hotpatch eligibility (on Azure Arc-enrolled WS2025)
Get-WindowsFeature -Name "HotPatch" # Not a feature — verify via Azure portal

# Enable Azure Arc enrollment
azcmagent connect --resource-group "MyRG" --tenant-id "tenant-id" `
    --location "eastus" --subscription-id "sub-id"

# Check hotpatch status
Get-HotFix | Where-Object {$_.Description -like "*Hotpatch*"}
```

Hotpatch release cadence: Every 3 months a "baseline" reboot-required update; intervening 2 months are hotpatched.

### 3.6 Patch Compliance Reporting

```powershell
# WSUS compliance report
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()
$computerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$updateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::LatestRevisionApproved

$wsus.GetSummariesPerComputerTarget($updateScope, $computerScope) |
    Select-Object @{N="Computer";E={$_.ComputerTarget.FullDomainName}},
                  NotInstalledCount, DownloadedCount, InstalledCount, FailedCount

# Azure Update Manager compliance (for Arc-enrolled)
# Query via Azure Resource Graph:
# resources | where type == "microsoft.compute/virtualmachines" | project name, properties.osProfile.windowsConfiguration
```

---

## 4. Server Core vs Desktop Experience Decision Matrix

### 4.1 When to Use Server Core

Advantages:
- ~40% smaller attack surface (fewer installed components)
- Fewer monthly patches required (reduced maintenance window frequency)
- Less frequent restarts — some months receive no reboots on hotpatch-eligible builds
- Smaller disk footprint (~4 GB less)
- Lower memory baseline

Roles well-suited for Server Core:
- Active Directory Domain Services (AD DS)
- Active Directory Lightweight Directory Services (AD LDS)
- DNS Server
- DHCP Server
- File Server (SMB shares, DFS)
- Hyper-V host
- Web Server (IIS — all management via PowerShell)
- Windows Server Update Services (WSUS)
- Failover Clustering (headless)

### 4.2 Roles Requiring Desktop Experience

- Remote Desktop Session Host (RDSH) — full GUI for user sessions
- Remote Desktop Web Access
- Some third-party backup agents (Veeam, Commvault) — verify current version support
- Windows Deployment Services (WDS) — management console not available in Core
- WSFC GUI Cluster Manager — available via RSAT on management machine
- Network Policy Server (NPS) — NPS console requires GUI, management can be remote

### 4.3 Server Core Management

```powershell
# sconfig — interactive text menu for initial setup
sconfig

# Key sconfig tasks:
# Option 2  — Computer name
# Option 1  — Domain join
# Option 5  — Windows Update settings
# Option 8  — Network settings
# Option 9  — Date and Time
# Option 15 — Exit to PowerShell

# Enable PowerShell remoting (usually already enabled)
Enable-PSRemoting -Force

# Remote management via Enter-PSSession
Enter-PSSession -ComputerName "SRVCORE01" -Credential (Get-Credential)

# Windows Admin Center — connect to Server Core via WAC gateway
# RSAT tools — manage Server Core roles from a Desktop Experience machine
Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
Add-WindowsCapability -Online -Name "Rsat.Dns.Tools~~~~0.0.1.0"
Add-WindowsCapability -Online -Name "Rsat.DHCP.Tools~~~~0.0.1.0"
Add-WindowsCapability -Online -Name "Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0"
```

---

## 5. Windows Admin Center (WAC)

### 5.1 Deployment Modes

| Mode | Use Case | Port |
|---|---|---|
| Desktop Mode | Single admin workstation, lab | Local only |
| Gateway Server | Shared team access, domain-joined server | 443 (HTTPS) |
| Azure Gateway | Cloud-managed, no VPN required | Azure Portal |

```powershell
# Install WAC in gateway mode (PowerShell)
# Download MSI from https://aka.ms/windowsadmincenter
Start-Process msiexec.exe -ArgumentList '/i WindowsAdminCenter.msi /qn /L*v wac-install.log SME_PORT=443 SSL_CERTIFICATE_OPTION=generate' -Wait

# Verify WAC service
Get-Service -Name "ServerManagementGateway"
```

### 5.2 Extensions and Capabilities

Core built-in tools:
- Overview (CPU, memory, disk, network at a glance)
- Certificates (view, request, export)
- Devices (Device Manager equivalent)
- Events (Event Viewer)
- Files (File Explorer equivalent)
- Firewall rules management
- Installed Apps
- Local Users & Groups
- Networks (NIC configuration)
- Processes (Task Manager equivalent)
- Registry
- Roles & Features
- Scheduled Tasks
- Services
- Storage (disk management)
- PowerShell direct session

Key extensions (install from WAC > Settings > Extensions):
- Azure Hybrid Services (Azure Arc, Azure Backup, Azure Monitor)
- Failover Clustering
- Storage Replica
- Storage Spaces Direct
- Software Defined Networking (SDN)

### 5.3 Managing Server Core, Clusters, and HCI

```powershell
# Add Server Core node to WAC (from WAC interface or PowerShell API)
# Enable WinRM on target (required for WAC connection)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "SRVCORE01,SRVCORE02" -Force

# For Hyper-Converged Infrastructure (HCI / S2D)
# WAC HCI dashboard requires:
# - All nodes WinRM-enabled
# - CredSSP or Kerberos double-hop configured
# - SMB ports open on host firewall (445)

# Configure CredSSP for WAC HCI scenarios
Enable-WSManCredSSP -Role Server -Force
```

### 5.4 Certificate and Authentication Configuration

```powershell
# Replace self-signed WAC certificate with CA-issued cert
# Import PFX:
Import-PfxCertificate -FilePath "C:\Certs\WAC.pfx" `
    -CertStoreLocation Cert:\LocalMachine\My `
    -Password (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force)

# Update WAC to use new certificate thumbprint
# Registry: HKLM:\SOFTWARE\Microsoft\ServerManagementGateway
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManagementGateway" `
    -Name "SslCertificateThumbprint" -Value "<thumbprint>"
Restart-Service ServerManagementGateway
```

---

## 6. Monitoring and Alerting

### 6.1 Performance Monitor — Key Counters

| Category | Counter | Warning Threshold | Critical Threshold |
|---|---|---|---|
| CPU | Processor(_Total)\% Processor Time | >70% sustained | >90% sustained |
| CPU | System\Processor Queue Length | >2 per CPU | >4 per CPU |
| Memory | Memory\Available MBytes | <500 MB | <200 MB |
| Memory | Memory\Pages/sec | >1000 | >5000 |
| Disk (HDD) | PhysicalDisk\Avg. Disk sec/Read | >20ms | >50ms |
| Disk (SSD) | PhysicalDisk\Avg. Disk sec/Read | >5ms | >20ms |
| Disk | PhysicalDisk\% Disk Time | >60% | >85% |
| Network | Network Interface\Bytes Total/sec | >70% capacity | >90% capacity |
| Network | Network Interface\Output Queue Length | >2 | >5 |

```powershell
# Create Data Collector Set for baseline capture
$dcName = "ServerBaseline"
$dcs = New-Object -COM "Pla.DataCollectorSet"
$dcs.DisplayName = $dcName
$dcs.Duration = 86400  # 24 hours
$dcs.SegmentMaxDuration = 3600  # 1-hour segments
$dcs.Commit($dcName, $null, 0x0003) # Create and save

# Preferred: use logman.exe for scripted DCS creation
logman create counter ServerBaseline `
    -cf "C:\PerfLogs\counters.txt" `
    -f bincirc -max 500 -si 60 `
    -o "C:\PerfLogs\ServerBaseline"

logman start ServerBaseline
```

### 6.2 Windows Event Forwarding (WEF) Architecture

```
Collector Server (WEF Collector)
  ↑ WinRM/HTTPS (port 5986 or 5985)
  ├── Source: DC01, DC02
  ├── Source: FileServer01, FileServer02
  └── Source: WebServer01
```

```powershell
# Configure WEF Collector
wecutil qc /q  # Quick Configure — enables Windows Event Collector service

# Create subscription (minimal security events example)
wecutil cs "C:\Subscriptions\SecurityEvents.xml"

# Subscription XML template key elements:
# <SubscriptionType>SourceInitiated</SubscriptionType>
# <Enabled>true</Enabled>
# <Uri>http://schemas.microsoft.com/wbem/wsman/1/windows/EventLog</Uri>
# <ConfigurationMode>MinLatency</ConfigurationMode>
# <TransportName>HTTPS</TransportName>

# On source machines — configure via GPO
# Computer Config > Admin Templates > Windows Components > Event Forwarding
# "Configure target Subscription Manager":
# Server=http://WEFCollector.domain.local:5985/wsman/SubscriptionManager/WEC,Refresh=60
```

### 6.3 Azure Monitor Agent for Hybrid

```powershell
# Deploy Azure Monitor Agent via Arc (on-premises servers enrolled in Azure Arc)
# Via Azure Policy: "Deploy Azure Monitor Agent for Windows Arc machines"

# Manual AMA installation on Arc-enrolled server:
azcmagent extension add --publisher Microsoft.Azure.Monitor `
    --type AzureMonitorWindowsAgent

# Configure Data Collection Rule (DCR) via Azure portal or ARM template
# Key event channels to forward to Log Analytics:
# - Security (EventID filters: 4624, 4625, 4648, 4688, 4720, 4728, 4740)
# - System
# - Application
# Performance counters: \Processor(_Total)\% Processor Time, \Memory\Available MBytes
```

---

## 7. Backup and Recovery

### 7.1 Windows Server Backup (wbadmin)

```powershell
# Install Windows Server Backup feature
Install-WindowsFeature -Name Windows-Server-Backup

# Full server backup to network share
wbadmin start backup -backuptarget:\\NAS01\Backups -include:C: -quiet

# Bare Metal Recovery backup
wbadmin start backup -backuptarget:E: -allCritical -systemState -quiet

# Schedule daily backup at 2 AM
wbadmin enable backup -addtarget:\\NAS01\Backups `
    -schedule:02:00 -include:C: -quiet

# List backup versions
wbadmin get versions -backuptarget:\\NAS01\Backups
```

### 7.2 System State Backup for Domain Controllers

```powershell
# System State backup — required for AD DS authoritative/non-authoritative restore
wbadmin start systemstatebackup -backuptarget:E: -quiet

# CRITICAL: Schedule system state backups at minimum daily
# Backup must complete within AD tombstone lifetime (default 180 days, best practice: daily)

# Authoritative restore procedure (when AD objects must be recovered):
# 1. Boot DC to DSRM (F8 at boot)
# 2. Restore system state: wbadmin start systemstaterecovery -version:<version>
# 3. Mark objects authoritative: ntdsutil "activate instance ntds" "authoritative restore" "restore subtree <DN>"
# 4. Reboot to normal mode

# Test restore process quarterly — never assume backups are valid without testing
```

### 7.3 Azure Backup Integration

```powershell
# Install MARS (Microsoft Azure Recovery Services) Agent
# Download from Azure portal > Recovery Services Vault > Backup

# Register server to vault (requires credentials file from Azure portal)
MARSAgentInstaller.exe /q /nu

# Configure backup schedule via MARS console or PowerShell
# Supported backup items: Files/Folders, System State
# Retention: Up to 9999 recovery points (daily/weekly/monthly/yearly)

# Azure VM backup — enable via Azure policy or per-VM:
# Backup Center > Configure Backup > Select vault and policy
```

### 7.4 Volume Shadow Copy (VSS) Configuration

```powershell
# Enable VSS on a volume (GUI: right-click volume > Properties > Shadow Copies)
# PowerShell — configure shadow copies:
$volume = "C:"
$schedule = "0 7 * * *"  # 7 AM daily (vssadmin uses task scheduler)

# Create shadow copy immediately
vssadmin create shadow /for=C:

# List shadow copies
vssadmin list shadows

# Configure storage area (prevent VSS from consuming too much space)
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=10%

# Recommended: At least 2 shadow copies per day for file servers
# Storage area: 10–15% of volume size minimum
```

### 7.5 BMR (Bare Metal Recovery) Procedures

Key requirements:
- WinPE boot media (Windows Server installation media or custom WinPE)
- External backup location accessible during recovery
- Network drivers available in WinPE for NAS/SAN-based backups

```powershell
# BMR restore steps (from Windows Recovery Environment):
# 1. Boot from Windows Server DVD/USB
# 2. Select "Repair your computer"
# 3. Select "System Image Recovery"
# 4. Point to backup location
# 5. Follow wizard to restore

# Verify BMR capability pre-failure:
wbadmin get disks  # Confirm backup disk visibility
wbadmin get items -backuptarget:\\NAS01\Backups  # Confirm backup items readable
```

### 7.6 Third-Party Backup Considerations

| Solution | Key Strength | Server Core Support |
|---|---|---|
| Veeam Backup & Replication | Hyper-V/VMware, instant recovery | Yes (agentless for VMs) |
| Commvault | Enterprise scale, tape integration | Yes |
| Acronis Cyber Protect | Integrated AV + backup | Yes |
| Cohesity | Data management platform | Yes (agent-based) |

Best practices:
- Test restores monthly (at minimum quarterly for full BMR)
- Store backups offsite or in cloud (3-2-1 rule: 3 copies, 2 media types, 1 offsite)
- Encrypt backups at rest and in transit
- Verify backup job alerts are sent to monitored mailbox/SIEM

---

## 8. Storage Best Practices

### 8.1 NTFS vs ReFS Decision Matrix

| Criteria | NTFS | ReFS |
|---|---|---|
| Boot volume | Yes | No (WS2016+: no; WS2022: yes with caveats) |
| General file storage | Yes | Yes |
| Deduplication | Yes | Yes (WS2019+) |
| Integrity checksums | No | Yes (automatic block-level) |
| Self-healing | Limited (chkdsk) | Yes (online, automatic) |
| Large volumes (>1 PB) | Technically yes | Better optimized |
| Hyper-V VHDX storage | Either | Preferred (mirror) |
| S2D (Storage Spaces Direct) | Either | Preferred |
| Maximum file size | 256 TB | 35 PB |
| Encryption (BitLocker) | Yes | Yes |

Recommendation: Use ReFS for Hyper-V VHDX storage, S2D, and large file server volumes with integrity requirements. Use NTFS for boot volumes, application volumes with specific NTFS feature dependencies, and environments requiring Offline dedup on older OS versions.

### 8.2 Disk Alignment and Allocation Unit Size

```powershell
# Format with recommended allocation unit sizes:
# General purpose NTFS: 4096 bytes (default)
# SQL Server data/log: 65536 bytes (64K) — critical for performance
# Hyper-V VHDX storage: 65536 bytes
# ReFS volumes: 65536 bytes (recommended for S2D)

Format-Volume -DriveLetter D -FileSystem NTFS -AllocationUnitSize 65536 `
    -NewFileSystemLabel "SQLData" -Confirm:$false

# Verify allocation unit size
Get-Volume D | Select-Object AllocationUnitSize
fsutil fsinfo ntfsinfo D: | findstr "Bytes Per Cluster"

# Disk alignment (modern disks 4Kn or 512e — Windows handles automatically for GPT)
# Verify with: Get-Disk | Select-Object Number, PartitionStyle, AlignmentInBytes
```

### 8.3 Storage Spaces Configuration

```powershell
# Create Storage Pool
$disks = Get-PhysicalDisk -CanPool $true
New-StoragePool -FriendlyName "DataPool" `
    -StorageSubSystemFriendlyName "Windows Storage*" `
    -PhysicalDisks $disks

# Create Mirror Virtual Disk (recommended for performance + redundancy)
New-VirtualDisk -StoragePoolFriendlyName "DataPool" `
    -FriendlyName "MirrorVDisk" `
    -Size 500GB `
    -ResiliencySettingName Mirror `
    -NumberOfDataCopies 2

# Create Parity Virtual Disk (capacity-optimized, less write performance)
New-VirtualDisk -StoragePoolFriendlyName "DataPool" `
    -FriendlyName "ParityVDisk" `
    -Size 2TB `
    -ResiliencySettingName Parity

# Initialize and format
Initialize-Disk -Number (Get-VirtualDisk -FriendlyName "MirrorVDisk" | Get-Disk).Number
New-Partition -DiskNumber <n> -UseMaximumSize -AssignDriveLetter |
    Format-Volume -FileSystem ReFS -AllocationUnitSize 65536
```

### 8.4 Storage Spaces Direct (S2D) Requirements and Tuning

Minimum requirements:
- 2 nodes minimum (4 recommended for production)
- Windows Server 2016 Datacenter edition or higher
- 10 Gbps network minimum (25 Gbps recommended for production)
- RDMA-capable NICs for high performance (RoCE v2 or iWARP)
- NVMe or SSD cache tier; HDD capacity tier (or all-flash)

```powershell
# Enable S2D
Enable-ClusterStorageSpacesDirect -CacheMode Enabled -AutoConfig:0

# Configure cache (NVMe as cache, SSD/HDD as capacity)
Set-ClusterStorageSpacesDirect -CacheDeviceModel "Samsung*" # Set cache devices

# Create S2D volume
New-Volume -StoragePoolFriendlyName "S2D on *" `
    -FriendlyName "CSV01" `
    -FileSystem CSVFS_ReFS `
    -Size 5TB `
    -ResiliencySettingName Mirror

# S2D health check
Get-StorageSubSystem -FriendlyName "Clustered*" | Get-StorageHealthReport

# Network configuration for S2D — SET teaming (Switch Embedded Teaming) preferred over LBFO
New-VMSwitch -Name "SETSwitch" -NetAdapterName "RDMA1","RDMA2" `
    -EnableEmbeddedTeaming $true -AllowManagementOS $true
```

### 8.5 Deduplication Configuration and Monitoring

```powershell
# Install Dedup feature
Install-WindowsFeature -Name FS-Data-Deduplication

# Enable dedup on volume (General Purpose mode)
Enable-DedupVolume -Volume D: -UsageType Default

# File Server mode (higher savings, longer optimization window)
Enable-DedupVolume -Volume E: -UsageType HyperV  # For Hyper-V VHD storage
Enable-DedupVolume -Volume F: -UsageType Backup   # For backup repositories

# Configure dedup policy
Set-DedupVolume -Volume D: -MinimumFileAgeDays 3 -MinimumFileSize 32768

# Monitor dedup savings
Get-DedupStatus -Volume D: | Select-Object Volume, SavedSpace, SavingsRate, OptimizedFilesCount

# Manual optimization job
Start-DedupJob -Volume D: -Type Optimization -Priority High

# Garbage collection (reclaim space from deleted/modified files)
Start-DedupJob -Volume D: -Type GarbageCollection
```

---

## 9. Networking Best Practices

### 9.1 NIC Teaming: LBFO vs SET

| Feature | LBFO (Legacy) | SET (Switch Embedded Teaming) |
|---|---|---|
| Hyper-V required | No | Yes |
| RDMA support | No | Yes |
| SR-IOV support | No | Yes |
| Team modes | Multiple | Active/Standby or Dynamic |
| Recommended for S2D | No | Yes |
| Deprecated in WS2022+ | Not officially, but discouraged | Preferred |

```powershell
# LBFO Teaming (legacy — avoid for new Hyper-V deployments)
New-NetLbfoTeam -Name "Team1" -TeamMembers "Ethernet1","Ethernet2" `
    -TeamingMode SwitchIndependent -LoadBalancingAlgorithm Dynamic

# SET (Switch Embedded Teaming) — for Hyper-V hosts
New-VMSwitch -Name "SETSwitch" -NetAdapterName "NIC1","NIC2" `
    -EnableEmbeddedTeaming $true -AllowManagementOS $true

# Add dedicated management vNIC
Add-VMNetworkAdapter -ManagementOS -SwitchName "SETSwitch" -Name "Management"
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "Management" `
    -Access -VlanId 10
```

### 9.2 DNS Server Configuration

```powershell
# Configure DNS server forwarders
Set-DnsServerForwarder -IPAddress "8.8.8.8","8.8.4.4" -PassThru
# For internal environments — use ISP or corporate DNS upstream

# Enable DNS debug logging (temporarily for troubleshooting)
Set-DnsServerDiagnostics -All $true

# Configure DNS scavenging (prevent stale records)
Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval 7.00:00:00
Set-DnsServerZoneAging -Name "domain.local" -Aging $true `
    -NoRefreshInterval 7.00:00:00 -RefreshInterval 7.00:00:00

# DNS socket pool (protect against cache poisoning)
# Default: 2500 sockets — increase for high-traffic DNS
dnscmd /config /socketpoolsize 10000

# DNS cache locking (default 100% — do not reduce)
dnscmd /config /cachelockingpercent 100
```

### 9.3 DHCP Failover and Split-Scope

```powershell
# Configure DHCP failover (Active/Passive — Hot Standby)
Add-DhcpServerv4Failover -Name "DHCP-Failover" `
    -PartnerServer "DHCP02.domain.local" `
    -ScopeId "192.168.1.0" `
    -Mode HotStandby `
    -ReservePercent 5 `
    -SharedSecret "SuperSecretKey123"

# Load balance mode (both servers active)
Add-DhcpServerv4Failover -Name "DHCP-LB-Failover" `
    -PartnerServer "DHCP02.domain.local" `
    -ScopeId "192.168.2.0" `
    -Mode LoadBalance `
    -LoadBalancePercent 50 `
    -SharedSecret "SuperSecretKey123"

# Verify failover status
Get-DhcpServerv4Failover
```

### 9.4 SMB Configuration

```powershell
# Enable SMB signing (required — prevents MITM attacks)
Set-SmbServerConfiguration -RequireSecuritySignature $true -Force
Set-SmbClientConfiguration -RequireSecuritySignature $true -Force

# Enable SMB encryption (WS2022+ supports AES-256)
Set-SmbServerConfiguration -EncryptData $true -Force
# Per-share encryption:
Set-SmbShare -Name "SecureShare" -EncryptData $true

# SMB over QUIC (Windows Server 2022 Azure Edition, 2025)
# Allows SMB without VPN — configure via WAC or:
New-SmbServerCertificateMapping -Name "SMBoverQUIC" `
    -Thumbprint "<cert-thumbprint>" `
    -StoreName My `
    -Flags 0x0

# Disable SMBv1 (already covered in hardening — reiterate here)
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force

# Check current SMB configuration
Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol, EnableSMB2Protocol, `
    RequireSecuritySignature, EncryptData
```

### 9.5 IPv6 Considerations

Best practice: Do NOT disable IPv6 on Windows Server — many OS components depend on it.
Instead, manage IPv6 correctly:

```powershell
# Prefer IPv4 over IPv6 (if IPv6 routing not configured)
# Modify prefix policy table — prefer IPv4
netsh interface ipv6 set prefixpolicy ::ffff:0:0/96 50 4   # IPv4-mapped — highest priority
netsh interface ipv6 set prefixpolicy ::/0 40 1             # IPv6 global

# Or via registry:
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" `
    -Name "DisabledComponents" -Value 0x20 -Type DWord
# 0x20 = prefer IPv4; 0xFF = disable IPv6 completely (NOT recommended)

# Ensure AAAA records registered for servers that have IPv6 addresses
# Suppress AAAA registration if no IPv6 routing available:
Set-DnsClient -InterfaceAlias "Ethernet" -RegisterThisConnectionsAddress $false # Only if no v6 routing
```

---

## 10. Security Best Practices

### 10.1 Least Privilege Administration

**Tiered Administration Model (Microsoft):**
- Tier 0: Domain Controllers, PKI, AD Connect — highest privilege
- Tier 1: Member Servers, applications — elevated but not domain admin
- Tier 2: Workstations, end-user devices — standard admin rights

**Privileged Access Workstations (PAW):**
- Dedicated hardened workstation for Tier 0/1 administration
- No internet access, no email, locked down browser
- Jump server model for datacenter access

**Just Enough Administration (JEA):**
```powershell
# Create JEA Role Capability file
New-PSRoleCapabilityFile -Path "C:\JEA\RoleCapabilities\HelpDesk.psrc" `
    -VisibleCmdlets @{Name='Restart-Service'; Parameters=@{Name='Name'; ValidateSet='DNS','DHCP'}} `
    -VisibleFunctions 'Get-EventLog' `
    -VisibleExternalCommands 'C:\Windows\System32\ipconfig.exe'

# Create JEA Session Configuration file
New-PSSessionConfigurationFile -Path "C:\JEA\HelpDesk.pssc" `
    -SessionType RestrictedRemoteServer `
    -RoleDefinitions @{'DOMAIN\HelpDesk' = @{RoleCapabilities = 'HelpDesk'}} `
    -RunAsVirtualAccount

# Register JEA endpoint
Register-PSSessionConfiguration -Path "C:\JEA\HelpDesk.pssc" -Name "HelpDesk" -Force
```

### 10.2 Service Account Management

**Group Managed Service Accounts (gMSA):**
```powershell
# Create KDS Root Key (one-time per forest)
Add-KdsRootKey -EffectiveImmediately  # Lab only; production use -EffectiveTime (10+ hours delay)

# Create gMSA
New-ADServiceAccount -Name "svc-WebApp" `
    -DNSHostName "svc-webapp.domain.local" `
    -PrincipalsAllowedToRetrieveManagedPassword "WebServer-Group"

# Install gMSA on target server
Install-ADServiceAccount -Identity "svc-WebApp"
Test-ADServiceAccount -Identity "svc-WebApp"

# Use gMSA in IIS Application Pool or Windows Service
# Password managed automatically by AD — no password rotation needed
```

**Delegated Managed Service Accounts (dMSA) — Windows Server 2025:**
```powershell
# dMSA (new in WS2025) — linked to a specific computer object, no group required
New-ADDelegatedServiceAccount -Name "dmsvc-App1" `
    -LinkedComputerAccount "AppServer01$" `
    -DNSHostName "dmsvc-app1.domain.local"
```

### 10.3 Local Administrator Password Solution (LAPS)

```powershell
# Microsoft LAPS (built-in, WS2022/Win11 era) — preferred over legacy LAPS
# Update AD Schema for new LAPS:
Update-LapsADSchema

# Configure LAPS via GPO:
# Computer Config > Admin Templates > System > LAPS
# "Configure password backup directory": Active Directory
# "Password settings": Length 15+, complexity, age 30 days

# Check LAPS password (requires Read permission on ms-LAPS-Password attribute)
Get-LapsADPassword -Identity "SERVER01" -AsPlainText

# Legacy LAPS (still supported):
Find-AdmPwdExtendedRights -OrgUnit "OU=Servers,DC=domain,DC=local"
Get-AdmPwdPassword -ComputerName "SERVER01"
```

### 10.4 Credential Guard and Device Guard

```powershell
# Enable Credential Guard (protects LSASS secrets via Hyper-V isolation)
# Requirements: UEFI, Secure Boot, VT-x/VT-d, TPM 2.0

# Via Group Policy:
# Computer Config > Admin Templates > System > Device Guard
# "Turn On Virtualization Based Security" = Enabled
# "Credential Guard Configuration" = Enabled with UEFI lock

# Via registry (for testing — UEFI lock not applied):
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" `
    -Name "EnableVirtualizationBasedSecurity" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
    -Name "LsaCfgFlags" -Value 1 -Type DWord  # 1=enabled, 2=enabled with UEFI lock

# Verify Credential Guard status
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
    Select-Object VirtualizationBasedSecurityStatus, SecurityServicesRunning
```

### 10.5 BitLocker for Server Volumes

```powershell
# Enable BitLocker on OS drive (requires TPM or startup key)
Enable-BitLocker -MountPoint "C:" -TpmProtector -EncryptionMethod XtsAes256

# Data volume — auto-unlock based on OS drive
Enable-BitLocker -MountPoint "D:" -PasswordProtector -Password (Read-Host -AsSecureString)
Enable-BitLockerAutoUnlock -MountPoint "D:"

# Backup recovery key to AD (requires BitLocker AD schema extension)
Backup-BitLockerKeyProtector -MountPoint "C:" `
    -KeyProtectorId (Get-BitLockerVolume C:).KeyProtector[0].KeyProtectorId

# Check BitLocker status across all volumes
Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, EncryptionMethod, ProtectionStatus

# Server BitLocker considerations:
# - Data drives: encrypt with AES-256-XTS (WS2016+)
# - Recovery keys must be escrowed to AD DS or Azure AD
# - Test recovery procedure before enabling in production
```

### 10.6 Certificate Management (PKI and Auto-Enrollment)

```powershell
# Configure certificate auto-enrollment via GPO:
# Computer Config > Windows Settings > Security Settings > Public Key Policies
# "Certificate Services Client – Auto-Enrollment" = Enabled
# ✓ Renew expired certificates
# ✓ Update certificates that use certificate templates
# ✓ Remove revoked certificates

# Request certificate manually (for testing):
Get-Certificate -Template "WebServer" -DnsName "server01.domain.local" `
    -CertStoreLocation Cert:\LocalMachine\My

# Check certificate expiry (alert at 30 days):
Get-ChildItem -Path Cert:\LocalMachine\My |
    Where-Object {$_.NotAfter -lt (Get-Date).AddDays(30)} |
    Select-Object Subject, Thumbprint, NotAfter |
    Export-Csv "C:\Logs\ExpiringCerts.csv" -NoTypeInformation

# Online Responder (OCSP) — configure for CRL availability without CDP downloads
# CDP and AIA URLs should be accessible without authentication (HTTP, not LDAP for external)
```

---

## Key Reference Values Summary

| Setting | Recommended Value |
|---|---|
| Minimum password length | 14 characters |
| Account lockout threshold | 5 attempts |
| Security event log size | 196,608 KB (192 MB) |
| VSS storage maximum | 10–15% of volume |
| Patch deployment B+N | Pilot: B+7, Prod Wave 1: B+14, Wave 2: B+21 |
| LAPS password rotation | 30 days |
| LAPS password length | 15+ characters |
| TLS minimum version | TLS 1.2 (1.3 preferred for WS2022+) |
| NIC teaming method | SET (for Hyper-V), LBFO (legacy bare-metal only) |
| S2D network minimum | 10 Gbps (25 Gbps recommended) |
| Disk alignment unit (SQL) | 65,536 bytes (64K) |
| DNS scavenging interval | 7 days |
| WEF transport | HTTPS (port 5986) |
| Dedup min file age | 3 days (general), 0 days (backup target) |

---

## Source References

- Microsoft Learn: Windows Server documentation (https://learn.microsoft.com/windows-server/)
- CIS Benchmarks: Windows Server 2016/2019/2022 (https://www.cisecurity.org/cis-benchmarks)
- DISA STIG: Windows Server STIGs (https://public.cyber.mil/stigs/)
- Microsoft Security Compliance Toolkit (https://www.microsoft.com/en-us/download/details.aspx?id=55319)
- Hotpatch documentation (https://learn.microsoft.com/windows-server/get-started/hotpatch)
- Windows Admin Center (https://aka.ms/windowsadmincenter)
- Storage Spaces Direct (https://learn.microsoft.com/windows-server/storage/storage-spaces/storage-spaces-direct-overview)
- JEA documentation (https://learn.microsoft.com/powershell/scripting/learn/remoting/jea/overview)
- Microsoft LAPS (https://learn.microsoft.com/windows-server/identity/laps/laps-overview)
- gMSA documentation (https://learn.microsoft.com/windows-server/security/group-managed-service-accounts/group-managed-service-accounts-overview)
