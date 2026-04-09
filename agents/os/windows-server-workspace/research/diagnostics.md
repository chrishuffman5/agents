# Windows Server Diagnostics and Troubleshooting — Research Notes
# Cross-version: 2016 / 2019 / 2022 / 2025

---

## 1. Event Log Analysis

### Key Event Logs

| Log Name | Path | Purpose |
|---|---|---|
| System | `Windows Logs\System` | OS components, drivers, services |
| Application | `Windows Logs\Application` | User-mode apps, .NET runtime |
| Security | `Windows Logs\Security` | Audit events (logon, object access, policy) |
| Setup | `Windows Logs\Setup` | Windows Update, feature install |
| Microsoft-Windows-DNS-Server/Analytical | `Applications and Services Logs\...` | DNS operational data |
| Microsoft-Windows-NTFS/Operational | `Applications and Services Logs\...` | NTFS errors |
| Microsoft-Windows-SMBServer/Operational | `Applications and Services Logs\...` | SMB connection issues |
| Microsoft-Windows-StorageSpaces-Driver/Operational | `Applications and Services Logs\...` | Storage Spaces health |
| Microsoft-Windows-WMI-Activity/Operational | `Applications and Services Logs\...` | WMI query activity |
| Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational | `Applications and Services Logs\...` | RDP session events |
| Microsoft-Windows-TaskScheduler/Operational | `Applications and Services Logs\...` | Scheduled task execution |
| Microsoft-Windows-PowerShell/Operational | `Applications and Services Logs\...` | PowerShell script block logging |

### Critical Event IDs

| Event ID | Source | Log | Meaning |
|---|---|---|---|
| 41 | Kernel-Power | System | Unexpected reboot (no clean shutdown before power loss) |
| 6008 | EventLog | System | Unexpected shutdown — prior boot ended abnormally |
| 1074 | USER32 | System | Planned shutdown or restart (records who/why) |
| 1076 | USER32 | System | Reason code provided for unexpected shutdown |
| 7036 | Service Control Manager | System | Service entered running/stopped state |
| 7045 | Service Control Manager | System | New service installed (watch for malware) |
| 7034 | Service Control Manager | System | Service terminated unexpectedly |
| 7031 | Service Control Manager | System | Service terminated unexpectedly — recovery action triggered |
| 1001 | BugCheck (WER) | Application | BSOD/stop error occurred; includes stop code |
| 1000 | Application Error | Application | Application crash (includes faulting module) |
| 1026 | .NET Runtime | Application | .NET unhandled exception |
| 4625 | Security | Security | Failed logon (check SubStatus for reason) |
| 4648 | Security | Security | Logon with explicit credentials |
| 4672 | Security | Security | Special privilege logon (admin) |
| 4740 | Security | Security | Account lockout |
| 4776 | Security | Security | NTLM authentication attempt |
| 4624 | Security | Security | Successful logon |
| 104 | EventLog | System | Event log cleared (potential tampering) |
| 4719 | Security | Security | System audit policy changed |

### PowerShell Event Log Queries

```powershell
# Get-WinEvent with LogName
Get-WinEvent -LogName System -MaxEvents 100

# Filter by Event ID
Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Id        = 41, 6008, 1074
    StartTime = (Get-Date).AddDays(-7)
}

# Get-WinEvent with XML query (most flexible)
$xml = @'
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">
      *[System[(EventID=41 or EventID=6008) and
        TimeCreated[timediff(@SystemTime) &lt;= 604800000]]]
    </Select>
  </Query>
</QueryList>
'@
Get-WinEvent -FilterXml $xml

# Parse structured event data
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} |
    ForEach-Object {
        $xml = [xml]$_.ToXml()
        [PSCustomObject]@{
            TimeCreated  = $_.TimeCreated
            Account      = $xml.Event.EventData.Data |
                           Where-Object Name -eq 'TargetUserName' | Select-Object -Exp '#text'
            WorkStation  = $xml.Event.EventData.Data |
                           Where-Object Name -eq 'WorkstationName' | Select-Object -Exp '#text'
            FailureReason = $xml.Event.EventData.Data |
                           Where-Object Name -eq 'SubStatus' | Select-Object -Exp '#text'
        }
    }

# Legacy Get-EventLog (System/Application/Security only, 32-bit limit)
Get-EventLog -LogName System -EntryType Error -Newest 50

# Forwarded events
Get-WinEvent -LogName 'ForwardedEvents' -MaxEvents 200
```

### Event Log Forwarding (WEF/WEC)

**Windows Event Collector (WEC) setup:**
```powershell
# On collector: enable service
winrm quickconfig
wecutil qc /q

# Create subscription (pull mode — collector initiates)
wecutil cs subscription.xml

# Verify subscription
wecutil gs "MySubscription"
wecutil gr "MySubscription"   # runtime status per source

# On source computers (GPO or manual)
winrm quickconfig -q
# Add collector to Event Log Readers group or use GPO:
# Computer Configuration > Windows Settings > Security Settings >
#   Restricted Groups — add WEC computer account to Event Log Readers
```

Subscription XML key elements: `<SubscriptionType>CollectorInitiated</SubscriptionType>`, `<DeliveryMode>Push</DeliveryMode>` for source-initiated (requires GPO pointing sources to collector).

### Event Log Sizing and Retention

```powershell
# Set log size (bytes) and retention
wevtutil sl System /ms:524288000   # 500 MB
wevtutil sl System /rt:false       # overwrite old events (not archive)

# Via PowerShell
$log = Get-WinEvent -ListLog System
$log.MaximumSizeInBytes = 524288000
$log.LogMode = [System.Diagnostics.Eventing.Reader.EventLogMode]::Circular
$log.SaveChanges()

# List all logs with sizes
Get-WinEvent -ListLog * | Sort-Object MaximumSizeInBytes -Descending |
    Select-Object LogName, MaximumSizeInBytes, RecordCount, LogMode | Format-Table
```

---

## 2. Performance Monitoring

### Key Performance Counters

**CPU**
| Counter | Warning | Critical | Notes |
|---|---|---|---|
| `\Processor(_Total)\% Processor Time` | >70% sustained | >90% sustained | Per-logical-CPU with `*` wildcard |
| `\System\Processor Queue Length` | >2 per CPU | >4 per CPU | Runnable threads waiting for CPU |
| `\Process(*)\% Processor Time` | — | — | Per-process CPU; divide by CPU count for true % |
| `\Processor(*)\% Privileged Time` | >20% sustained | >35% | High = driver or kernel issue |
| `\Processor(*)\% Interrupt Time` | >15% | >25% | High = hardware interrupt storm |

**Memory**
| Counter | Warning | Critical | Notes |
|---|---|---|---|
| `\Memory\Available MBytes` | <10% RAM | <5% RAM | Absolute floor varies by workload |
| `\Memory\Pages/sec` | >100 | >500 | Hard page faults; indicates paging |
| `\Memory\Page Faults/sec` | — | — | Soft+hard faults; less actionable alone |
| `\Memory\Pool Nonpaged Bytes` | Trending up | Leak pattern | Driver leak indicator |
| `\Memory\Pool Paged Bytes` | Trending up | Leak pattern | User-mode pool usage |
| `\Process(*)\Working Set` | — | — | Per-process physical memory |
| `\Memory\Committed Bytes` | >80% of Commit Limit | >95% | Approaching commit limit = crash risk |

**Disk**
| Counter | Warning | Critical | Notes |
|---|---|---|---|
| `\PhysicalDisk(*)\Avg. Disk sec/Read` | >20ms | >50ms | Latency; SSD should be <1ms |
| `\PhysicalDisk(*)\Avg. Disk sec/Write` | >20ms | >50ms | HDD: <20ms normal |
| `\PhysicalDisk(*)\Disk Queue Length` | >2 | >4 | Sustained queue = disk bottleneck |
| `\PhysicalDisk(*)\Disk Reads/sec` | — | — | Compare to drive rated IOPS |
| `\LogicalDisk(*)\% Free Space` | <20% | <10% | Low space causes fragmentation and errors |
| `\LogicalDisk(*)\% Disk Time` | >80% | >90% | Sustained saturation |

**Network**
| Counter | Warning | Critical | Notes |
|---|---|---|---|
| `\Network Interface(*)\Bytes Total/sec` | >60% of link speed | >80% | Calc from adapter speed |
| `\Network Interface(*)\Output Queue Length` | >2 | >4 | Sustained = NIC saturation |
| `\Network Interface(*)\Packets Received Errors` | >0 | Any | Hardware or driver issue |
| `\TCPv4\Connections Established` | — | — | Baseline and trend |
| `\TCPv4\Connection Failures` | >0 sustained | — | Network path issues |

### Get-Counter Usage

```powershell
# Snapshot of multiple counters
Get-Counter '\Processor(_Total)\% Processor Time',
            '\Memory\Available MBytes',
            '\PhysicalDisk(_Total)\Avg. Disk sec/Read' -SampleInterval 5 -MaxSamples 12

# Continuous monitoring with export
Get-Counter '\Processor(*)\% Processor Time' -Continuous |
    ForEach-Object { $_.CounterSamples | Select-Object Path, CookedValue, Timestamp }

# List all available counter sets
Get-Counter -ListSet * | Sort-Object CounterSetName | Select-Object CounterSetName, CounterSetType

# Export to CSV for trending
$counters = '\Processor(_Total)\% Processor Time', '\Memory\Available MBytes'
Get-Counter $counters -SampleInterval 10 -MaxSamples 360 |
    Export-Csv C:\Logs\perf_$(Get-Date -Format yyyyMMdd_HHmm).csv -NoTypeInformation
```

### Data Collector Sets (Baseline and Alerting)

```powershell
# Create DCS via logman (command line)
logman create counter "BaselineCapture" `
    -c "\Processor(*)\% Processor Time" "\Memory\Available MBytes" `
       "\PhysicalDisk(*)\Avg. Disk sec/Read" "\PhysicalDisk(*)\Disk Queue Length" `
       "\Network Interface(*)\Bytes Total/sec" `
    -si 00:00:15 -f csv -o C:\PerfLogs\Baseline -rf 01:00:00

logman start BaselineCapture
logman stop  BaselineCapture

# Create alert DCS
logman create alert "HighCPUAlert" `
    -c "\Processor(_Total)\% Processor Time" -th "\Processor(_Total)\% Processor Time>85" `
    -task "SendAlert"  # task scheduler task name
```

GUI path: Performance Monitor > Data Collector Sets > User Defined > New > Data Collector Set.

---

## 3. Resource Monitor and Task Manager

### Task Manager Key Views

- **CPU tab:** Logical processor utilization graph; right-click > Change graph to > Logical processors for per-core view. Elevated "Kernel" (red) indicates driver activity.
- **Memory tab:** In Use / Standby / Free breakdown. "Committed" vs "Limit" — approaching limit is dangerous.
- **Disk tab:** Active time % per disk; 100% = saturation. Sort by Read/Write MB/s to find top consumer.
- **Network tab:** Bytes sent/received per adapter; watch for unexpected high outbound (exfiltration, broadcast storm).
- **Details tab:** Handle count (>10,000 per process = leak risk), Thread count, GDI objects. Enable columns via right-click.

### Resource Monitor (resmon.exe)

- **CPU:** Per-process CPU%, Handles, Threads; can right-click process > Analyze Wait Chain to identify blocking thread.
- **Memory:** Working Set, Shareable, Private; sort Private to find memory hogs.
- **Disk:** Per-file I/O; reveals which specific files are being read/written (invaluable for AV, database, or backup diagnosis).
- **Network:** Per-process network activity and TCP connections with remote addresses.

**Wait Chain Analysis:** Right-click a hung process in Task Manager Details tab > Analyze Wait Chain. Shows dependency graph of blocking. A thread waiting on another process's lock shows as a chain — the root process is the blocker.

---

## 4. PowerShell Diagnostic Commands

### System Information

```powershell
# Comprehensive system info
Get-ComputerInfo | Select-Object CsName, OsName, OsVersion, OsArchitecture,
    CsProcessors, CsTotalPhysicalMemory, OsLastBootUpTime, OsUptime

# Via CIM
Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version,
    LastBootUpTime, FreePhysicalMemory, TotalVisibleMemorySize

# Legacy
systeminfo.exe
systeminfo /s RemoteServer /u domain\admin

# Installed hotfixes
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20
Get-HotFix -Id KB5034441   # check specific KB

# Windows Update log (2016+)
Get-WindowsUpdateLog -LogPath C:\Temp\WindowsUpdate.log
```

### Hardware Inventory

```powershell
# CPU
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores,
    NumberOfLogicalProcessors, MaxClockSpeed, LoadPercentage

# Memory DIMMs
Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, Capacity,
    Speed, Manufacturer, PartNumber |
    ForEach-Object { $_.Capacity = [math]::Round($_.Capacity/1GB,0); $_ }

# Disks
Get-CimInstance Win32_DiskDrive | Select-Object Model, Size, MediaType,
    InterfaceType, Status

# BIOS / Firmware
Get-CimInstance Win32_BIOS | Select-Object Manufacturer, SMBIOSBIOSVersion,
    ReleaseDate, SerialNumber
```

### Network Diagnostics

```powershell
# Adapter status
Get-NetAdapter | Select-Object Name, InterfaceDescription, Status,
    LinkSpeed, MacAddress | Format-Table

# IP configuration
Get-NetIPConfiguration -Detailed

# Active TCP connections
Get-NetTCPConnection -State Established |
    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess |
    Sort-Object RemoteAddress

# Listening ports with owning process
Get-NetTCPConnection -State Listen |
    Select-Object LocalPort, OwningProcess,
        @{N='ProcessName';E={(Get-Process -Id $_.OwningProcess -EA 0).Name}} |
    Sort-Object LocalPort

# Port connectivity test
Test-NetConnection -ComputerName sql01 -Port 1433
Test-NetConnection -ComputerName dc01 -CommonTCPPort WINRM

# DNS
Resolve-DnsName www.example.com -Server 8.8.8.8 -Type A
Clear-DnsClientCache
Get-DnsClientCache | Select-Object Entry, Data, TimeToLive

# Traceroute equivalent
Test-NetConnection -ComputerName 10.1.1.1 -TraceRoute
```

### Services and Processes

```powershell
# Services not running that should be
Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' }

# Process memory and CPU snapshot
Get-Process | Sort-Object WorkingSet64 -Descending |
    Select-Object -First 20 Name, Id, CPU, WorkingSet64,
        @{N='WS_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}}, Handles

# Find process holding a port (combine with netstat)
$port = 443
$pid  = (Get-NetTCPConnection -LocalPort $port -EA 0).OwningProcess | Select-Object -First 1
Get-Process -Id $pid
```

### Storage

```powershell
# Volume info
Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystem,
    Size, SizeRemaining, HealthStatus, DriveType |
    ForEach-Object { $_.Size = [math]::Round($_.Size/1GB,1);
                     $_.SizeRemaining = [math]::Round($_.SizeRemaining/1GB,1); $_ }

# Physical disk health
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, Size,
    HealthStatus, OperationalStatus, BusType

# SMART data
Get-PhysicalDisk | Get-StorageReliabilityCounter |
    Select-Object DeviceId, ReadErrorsTotal, WriteErrorsTotal,
        Temperature, Wear, StartStopCycleCount

# Storage pools (Storage Spaces)
Get-StoragePool | Select-Object FriendlyName, OperationalStatus,
    HealthStatus, Size, AllocatedSize

# Virtual disks
Get-VirtualDisk | Select-Object FriendlyName, OperationalStatus,
    HealthStatus, ResiliencySettingName, Size

# Running storage jobs (repair, rebuild)
Get-StorageJob | Select-Object Name, OperationalStatus, PercentComplete,
    ElapsedTime, EstimatedRemainingTime
```

---

## 5. Reliability Monitor and Problem Reports

```powershell
# Reliability Monitor UI
perfmon /rel

# WER reports via filesystem
Get-ChildItem C:\ProgramData\Microsoft\Windows\WER\ReportArchive -Recurse |
    Sort-Object LastWriteTime -Descending | Select-Object -First 20

# Application crashes from event log
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000,1001,1026} |
    Select-Object TimeCreated, Id, Message | Format-List

# Windows Error Reporting service
Get-Service WerSvc | Select-Object Name, Status, StartType

# Problem reports summary
Get-WinEvent -LogName 'Application' -FilterXPath `
    "*[System[EventID=1001] and EventData[Data[@Name='EventType']='APPCRASH']]" |
    Select-Object TimeCreated, Message -First 20
```

Reliability Monitor shows a 1-10 stability index chart. Drill into specific failure dates. Application failures show as red X marks; Windows failures (BSOD) show as stop icons. Export via `perfmon /report` for a full system diagnostics report (takes ~60 seconds).

---

## 6. Network Diagnostics

### Command-Line Tools

```cmd
:: Active connections and listening ports
netstat -ano
netstat -b -n 5          :: refresh every 5s, show process names

:: Route table
netstat -r
route print

:: Network config
netsh interface ip show config
netsh interface ip show addresses
netsh interface ip show dns

:: Reset TCP/IP stack (escalation step)
netsh int ip reset C:\Logs\ip_reset.log
netsh winsock reset

:: Pathping (combines ping + tracert with statistics per hop)
pathping -n 10.1.1.1

:: nslookup
nslookup -type=SRV _ldap._tcp.dc._msdcs.domain.com
nslookup -type=MX domain.com dc01.domain.com
```

### Packet Capture

```cmd
:: netsh trace (built-in, no driver install required)
netsh trace start capture=yes tracefile=C:\Logs\capture.etl maxsize=512
netsh trace stop
:: Convert .etl to .cap for Wireshark:
:: Microsoft Message Analyzer (legacy) or etl2pcapng tool

:: pktmon (Windows Server 2019+) — kernel-level packet capture
pktmon start --capture --pkt-size 0 -f C:\Logs\pktmon.etl
pktmon stop
pktmon etl2txt C:\Logs\pktmon.etl          :: human-readable
pktmon etl2pcap C:\Logs\pktmon.etl         :: Wireshark-compatible

:: pktmon filter for targeted capture
pktmon filter add -p 445   :: SMB only
pktmon filter list
pktmon filter remove
```

### SMB Diagnostics

```powershell
# Active SMB connections from this server
Get-SmbConnection | Select-Object ServerName, ShareName, UserName, Dialect, NumOpens

# Sessions to this server (server-side)
Get-SmbSession | Select-Object ClientComputerName, ClientUserName, NumOpens, SecondsActive

# Open files on this server
Get-SmbOpenFile | Select-Object ClientComputerName, ClientUserName, Path, ShareRelativePath

# SMB server configuration
Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol, EnableSMB2Protocol,
    RequireSecuritySignature, EncryptData

# Close stuck session
Get-SmbSession | Where-Object ClientComputerName -eq '10.1.1.50' | Close-SmbSession -Force

# SMB share permissions
Get-SmbShareAccess -Name "Data"
```

**Symptom → Investigation → Resolution: SMB connectivity failure**
1. Symptom: Users cannot access \\server\share; access denied or network path not found.
2. Investigation: `Test-NetConnection server -Port 445`; `Get-SmbServerConfiguration | Select EnableSMB1Protocol, EnableSMB2Protocol`; check firewall (`Get-NetFirewallRule -DisplayName "*SMB*"`); review Security log for 4625.
3. Resolution: Ensure SMB2 enabled; verify firewall allows TCP 445; check share permissions with `Get-SmbShareAccess`; verify NTFS permissions with `Get-Acl`.

---

## 7. Storage Diagnostics

### Disk Health and SMART

```powershell
# Physical disk status overview
Get-PhysicalDisk | Select-Object DeviceId, FriendlyName, MediaType,
    OperationalStatus, HealthStatus, Size | Format-Table

# SMART reliability counters (requires Storage Spaces or direct-attached)
Get-PhysicalDisk | Get-StorageReliabilityCounter | Select-Object *

# Reallocated sectors (non-zero = failing drive)
# Wear (SSDs) — above 90 = approaching end of life
```

### NTFS and ReFS Integrity

```cmd
:: CHKDSK — read-only scan
chkdsk C: /scan /forceofflinefix

:: Schedule offline fix at next boot
chkdsk C: /f /r /x

:: ReFS integrity streams check
repair-volume -DriveLetter D -Scan
repair-volume -DriveLetter D -SpotFix
```

```powershell
# Online scan (Server 2012+)
Repair-Volume -DriveLetter C -Scan
Repair-Volume -DriveLetter C -SpotFix   # fix without dismount

# Storage Spaces repair
Get-VirtualDisk | Where-Object HealthStatus -ne 'Healthy' | Repair-VirtualDisk

# Check for detached/degraded disks
Get-StoragePool | Get-VirtualDisk | Select-Object FriendlyName,
    OperationalStatus, HealthStatus, ResiliencySettingName
```

### Disk I/O Symptom Patterns

| Symptom | Counter to Check | Likely Cause |
|---|---|---|
| Slow writes | `Avg. Disk sec/Write > 50ms` | Disk saturation, RAID rebuild, AV scanning |
| High queue | `Disk Queue Length > 4` sustained | Under-provisioned storage, failing drive |
| 100% disk time | `% Disk Time = 100%` | Single bottleneck disk; investigate with Resource Monitor |
| Sudden I/O spike | `Disk Reads/sec` spike | AV scan, defrag, backup job, Windows Update |

---

## 8. Blue Screen / Stop Error Analysis

### Dump File Locations and Types

| Type | Path | Size | When to Use |
|---|---|---|---|
| Small Memory (Mini) | `%SystemRoot%\Minidump\` | 64–256 KB | Quick analysis; limited data |
| Kernel | `%SystemRoot%\MEMORY.DMP` | RAM-dependent | Most common; kernel + crash context |
| Complete | `%SystemRoot%\MEMORY.DMP` | = Physical RAM | Full memory; very large |
| Automatic | `%SystemRoot%\MEMORY.DMP` | Variable | Default since Server 2008 |

Configure via: `System Properties > Advanced > Startup and Recovery > System Failure`.

```powershell
# Check current dump settings
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl |
    Select-Object CrashDumpEnabled, DumpFile, MiniDumpDir, AutoReboot

# CrashDumpEnabled values: 0=None, 1=Complete, 2=Kernel, 3=Small, 7=Automatic
```

### Common Stop Codes

| Stop Code | Hex | Common Causes |
|---|---|---|
| IRQL_NOT_LESS_OR_EQUAL | 0xA | Driver accessing memory at wrong IRQL; bad driver or hardware |
| PAGE_FAULT_IN_NONPAGED_AREA | 0x50 | Driver bug; bad RAM; corrupted system file |
| SYSTEM_SERVICE_EXCEPTION | 0x3B | Driver or system service exception; often graphics or storage driver |
| KERNEL_DATA_INPAGE_ERROR | 0x7A | Disk read failure; bad disk, memory, or virtual memory |
| KERNEL_SECURITY_CHECK_FAILURE | 0x139 | Kernel data structure corruption; driver bug or hardware |
| DRIVER_IRQL_NOT_LESS_OR_EQUAL | 0xD1 | Network or storage driver bug; common after updates |
| BAD_POOL_CALLER | 0xC2 | Driver bad pool allocation; pool corruption |
| UNEXPECTED_KERNEL_MODE_TRAP | 0x7F | Hardware failure (CPU, RAM, overheating) |
| CRITICAL_PROCESS_DIED | 0xEF | Critical Windows process terminated unexpectedly |

### WinDbg Analysis

```windbg
:: Open kernel dump
windbg -z C:\Windows\MEMORY.DMP

:: Automated analysis
!analyze -v

:: Check loaded modules (identify third-party drivers)
lm o m *   :: list only third-party (non-Microsoft)

:: Stack trace of crashing thread
kp

:: Memory pool tags (identify pool leak source)
!poolused 2   :: show paged pool by tag
!poolused 4   :: show nonpaged pool by tag

:: Check IRPs
!irpfind

:: Driver verifier — enable for suspect driver (causes BSOD on violation)
verifier /standard /driver suspect_driver.sys
verifier /query   :: check status
verifier /reset   :: disable
```

**Symptom → Investigation → Resolution: Recurring BSOD**
1. Symptom: Server reboots unexpectedly; Event ID 41 (Kernel-Power) in System log; minidump files in `C:\Windows\Minidump`.
2. Investigation: Check Event ID 1001 in Application log for BugCheck data. Run `!analyze -v` in WinDbg. Look for third-party driver in stack. Run `verifier /standard` on suspect driver. Check RAM with Windows Memory Diagnostic.
3. Resolution: Update or roll back flagged driver. If hardware: run extended memory test, check hardware event log (iDRAC/iLO). Enable Driver Verifier only in test/staging first.

---

## 9. Windows Remote Management (WinRM)

### WinRM Configuration

```powershell
# Enable WinRM (listener on HTTP 5985)
Enable-PSRemoting -Force
# Or:
winrm quickconfig -q

# Check listener status
winrm enumerate winrm/config/listener
Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate

# Configure HTTPS listener (requires certificate)
$thumb = (Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -like "*$(hostname)*").Thumbprint
winrm create winrm/config/Listener?Address=*+Transport=HTTPS `
    @{Hostname="$env:COMPUTERNAME"; CertificateThumbprint="$thumb"}

# WinRM service config
winrm get winrm/config/service
Set-Item WSMan:\localhost\Service\MaxConcurrentOperationsPerUser 1500
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 2048
```

### PowerShell Remoting

```powershell
# Interactive remote session
Enter-PSSession -ComputerName server01 -Credential domain\admin

# Run commands on multiple servers
Invoke-Command -ComputerName srv1, srv2, srv3 -ScriptBlock {
    Get-Service -Name WinRM | Select-Object Name, Status
}

# Persistent session
$s = New-PSSession -ComputerName server01
Invoke-Command -Session $s -ScriptBlock { $result = Get-Process }
Invoke-Command -Session $s -ScriptBlock { $result | Sort-Object CPU -Descending }
Remove-PSSession $s

# Copy files over PSRemoting
Copy-Item C:\Scripts\fix.ps1 -Destination C:\Scripts\ -ToSession $s
```

### Authentication Troubleshooting

```powershell
# CredSSP (allows credential delegation for double-hop)
# Enable on client
Enable-WSManCredSSP -Role Client -DelegateComputer "*.domain.com"
# Enable on server
Enable-WSManCredSSP -Role Server

# Check Kerberos tickets
klist
klist purge   :: clear ticket cache

# Test WinRM connectivity
Test-WSMan -ComputerName server01 -Authentication Kerberos

# Common issues:
# - "Access denied" with NTLM: add to TrustedHosts (workgroup) or fix SPN
# - Double-hop failure: use CredSSP or resource-based Kerberos delegation
# - Firewall: TCP 5985 (HTTP), TCP 5986 (HTTPS)

# TrustedHosts (workgroup/cross-domain — less secure)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "10.1.1.*" -Concatenate -Force

# WinRM firewall rules
Get-NetFirewallRule -DisplayName "*Windows Remote Management*" |
    Select-Object DisplayName, Enabled, Direction, Action
```

**Symptom → Investigation → Resolution: Invoke-Command fails with "Access Denied"**
1. Symptom: `Invoke-Command -ComputerName server01` returns "Access is denied."
2. Investigation: `Test-WSMan server01`; check if WinRM is running on target; verify user is in Remote Management Users or Administrators group; check if firewall blocks 5985; try `-Authentication Negotiate`.
3. Resolution: `Enable-PSRemoting -Force` on target; add user to Remote Management Users group; open firewall rule; if cross-domain, configure TrustedHosts or fix Kerberos SPN.

---

## 10. DTrace (Windows Server 2025)

### Availability and Setup

DTrace became available on Windows starting with Windows 10 1903 and is included in Windows Server 2025. It is a dynamic tracing framework ported from BSD/Solaris.

```cmd
:: Enable DTrace (requires reboot, sets boot option)
bcdedit /set dtrace on

:: Verify availability
dtrace -l | head -20   :: list available probes
dtrace -l -n 'syscall:::'   :: list syscall probes
```

### Basic Tracing Scenarios

```dtrace
/* Trace all system calls by process name */
dtrace -n 'syscall:::entry { @[execname] = count(); } tick-10s { printa(@); exit(0); }'

/* I/O tracing — files being opened */
dtrace -n 'syscall::NtCreateFile:entry { printf("%s opened %*ws\n", execname,
    arg2, ((OBJECT_ATTRIBUTES *)arg2)->ObjectName->Buffer); }'

/* Process creation */
dtrace -n 'proc:::exec-success { printf("PID %d: %s\n", pid, curpsinfo->pr_psargs); }'

/* CPU profiling — sample stack at 997Hz */
dtrace -n 'profile-997 /arg0/ { @[stack()] = count(); } END { trunc(@,10); printa(@); }'

/* Network send/receive bytes by process */
dtrace -n 'fbt::TcpSendData:entry { @bytes[execname] = sum(arg2); }
           tick-5s { printa("%-20s %@d bytes\n", @bytes); clear(@bytes); }'
```

### Integration with Existing Diagnostics

- DTrace complements ETW (Event Tracing for Windows) for lower-level kernel probe points.
- Use DTrace for dynamic investigation without rebooting or driver installation.
- Combine with `pktmon` (network), Performance Monitor (counters), and Event Log for full observability.
- D scripts (`.d` files) can be run with `dtrace -s script.d`.
- Output can be piped or redirected for offline analysis.

```powershell
# Run DTrace from PowerShell for integration
$trace = dtrace -qn 'syscall:::entry { @[execname] = count(); } tick-30s { printa(@); exit(0); }'
$trace | ConvertFrom-String | Sort-Object P2 -Descending
```

---

## Diagnostic Workflows — Quick Reference

### High CPU Investigation
```powershell
# 1. Identify top CPU consumers
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10

# 2. Per-core utilization
Get-Counter '\Processor(*)\% Processor Time' -MaxSamples 5 -SampleInterval 2

# 3. Check processor queue
Get-Counter '\System\Processor Queue Length' -MaxSamples 10

# 4. If specific process: check its threads in Process Explorer or WMI
Get-WmiObject Win32_Thread | Where-Object ProcessHandle -eq <PID> |
    Measure-Object -Property KernelModeTime, UserModeTime -Sum
```

### Memory Pressure Investigation
```powershell
# 1. Available memory trend
Get-Counter '\Memory\Available MBytes', '\Memory\Pages/sec' -MaxSamples 12 -SampleInterval 5

# 2. Top memory consumers
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name,
    @{N='WS_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}},
    @{N='PM_MB';E={[math]::Round($_.PagedMemorySize64/1MB,1)}}

# 3. Pool nonpaged leak check (trending up = driver leak)
Get-Counter '\Memory\Pool Nonpaged Bytes' -MaxSamples 20 -SampleInterval 30

# 4. Committed vs limit
Get-CimInstance Win32_OperatingSystem |
    Select-Object @{N='CommitGB';E={[math]::Round($_.TotalVirtualMemorySize/1MB,1)}},
                  @{N='FreeGB';E={[math]::Round($_.FreeVirtualMemory/1MB,1)}}
```

### Disk Latency Investigation
```powershell
# 1. Confirm latency
Get-Counter '\PhysicalDisk(*)\Avg. Disk sec/Read',
            '\PhysicalDisk(*)\Avg. Disk sec/Write',
            '\PhysicalDisk(*)\Disk Queue Length' -MaxSamples 6 -SampleInterval 10

# 2. Open Resource Monitor disk tab to identify files
# Or use Sysinternals Process Monitor with filter on disk activity

# 3. Check Storage Spaces health
Get-VirtualDisk | Select-Object FriendlyName, OperationalStatus, HealthStatus

# 4. Check physical disk health
Get-PhysicalDisk | Get-StorageReliabilityCounter | Select-Object DeviceId,
    ReadErrorsTotal, WriteErrorsTotal, Temperature
```

### Network Connectivity Investigation
```powershell
# 1. Basic connectivity
Test-NetConnection -ComputerName target -Port 443 -InformationLevel Detailed

# 2. DNS resolution
Resolve-DnsName target.domain.com -Server 10.1.1.10

# 3. Routing
Test-NetConnection -ComputerName 8.8.8.8 -TraceRoute

# 4. Listening services
Get-NetTCPConnection -State Listen |
    Select-Object LocalPort,
        @{N='Process';E={(Get-Process -Id $_.OwningProcess -EA 0).Name}} |
    Sort-Object LocalPort

# 5. Active established connections count
(Get-NetTCPConnection -State Established).Count
```

---

*Research compiled: 2026-04-08 | Scope: Windows Server 2016, 2019, 2022, 2025*
