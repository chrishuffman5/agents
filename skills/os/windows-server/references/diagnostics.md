# Windows Server Diagnostics Reference

## Event Log Analysis

### Key Event Logs

| Log | Purpose |
|---|---|
| System | OS components, drivers, services |
| Application | User-mode apps, .NET runtime |
| Security | Audit events (logon, object access, policy changes) |
| Setup | Windows Update, feature installs |
| Microsoft-Windows-SMBServer/Operational | SMB connection issues |
| Microsoft-Windows-NTFS/Operational | NTFS errors |
| Microsoft-Windows-PowerShell/Operational | Script block logging |
| Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational | RDP sessions |

### Critical Event IDs

| Event ID | Source | Log | Meaning |
|---|---|---|---|
| 41 | Kernel-Power | System | Unexpected reboot (no clean shutdown) |
| 6008 | EventLog | System | Unexpected shutdown -- prior boot ended abnormally |
| 1074 | USER32 | System | Planned shutdown/restart (records who/why) |
| 7036 | SCM | System | Service entered running/stopped state |
| 7045 | SCM | System | New service installed (watch for malware) |
| 7034 | SCM | System | Service terminated unexpectedly |
| 1000 | Application Error | Application | Application crash (includes faulting module) |
| 1026 | .NET Runtime | Application | .NET unhandled exception |
| 4625 | Security | Security | Failed logon (check SubStatus for reason) |
| 4672 | Security | Security | Special privilege logon (admin) |
| 4740 | Security | Security | Account lockout |
| 104 | EventLog | System | Event log cleared (potential tampering) |

### PowerShell Event Log Queries

```powershell
# Recent critical events from System log
Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Id        = 41, 6008, 1074
    StartTime = (Get-Date).AddDays(-7)
}

# Parse failed logon events with details
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} |
    ForEach-Object {
        $xml = [xml]$_.ToXml()
        [PSCustomObject]@{
            TimeCreated  = $_.TimeCreated
            Account      = ($xml.Event.EventData.Data | Where-Object Name -eq 'TargetUserName').'#text'
            WorkStation  = ($xml.Event.EventData.Data | Where-Object Name -eq 'WorkstationName').'#text'
            FailureCode  = ($xml.Event.EventData.Data | Where-Object Name -eq 'SubStatus').'#text'
        }
    }

# Set event log sizes (CIS/STIG baseline)
wevtutil sl Security /ms:196608000    # 196 MB
wevtutil sl System /ms:32768000       # 32 MB
wevtutil sl Application /ms:32768000  # 32 MB
```

---

## Performance Counters

### Key Counters by Category

**CPU:**
| Counter | Warning | Critical |
|---|---|---|
| `\Processor(_Total)\% Processor Time` | >70% sustained | >90% sustained |
| `\System\Processor Queue Length` | >2 per CPU | >4 per CPU |
| `\Processor(*)\% Privileged Time` | >20% sustained | >35% (driver/kernel issue) |
| `\Processor(*)\% Interrupt Time` | >15% | >25% (hardware interrupt storm) |

**Memory:**
| Counter | Warning | Critical |
|---|---|---|
| `\Memory\Available MBytes` | <10% RAM | <5% RAM |
| `\Memory\Pages/sec` | >100 | >500 (heavy paging) |
| `\Memory\Pool Nonpaged Bytes` | Trending up | Leak pattern (driver leak) |
| `\Memory\Committed Bytes` | >80% of Commit Limit | >95% (crash risk) |

**Disk:**
| Counter | Warning | Critical |
|---|---|---|
| `\PhysicalDisk(*)\Avg. Disk sec/Read` | >20ms (HDD) | >50ms |
| `\PhysicalDisk(*)\Avg. Disk sec/Write` | >20ms | >50ms |
| `\PhysicalDisk(*)\Disk Queue Length` | >2 | >4 sustained |
| `\LogicalDisk(*)\% Free Space` | <20% | <10% |

**Network:**
| Counter | Warning | Critical |
|---|---|---|
| `\Network Interface(*)\Bytes Total/sec` | >60% link speed | >80% |
| `\Network Interface(*)\Output Queue Length` | >2 | >4 |
| `\Network Interface(*)\Packets Received Errors` | >0 | Any (hardware/driver issue) |

### Get-Counter Usage

```powershell
# Snapshot of multiple counters
Get-Counter '\Processor(_Total)\% Processor Time',
            '\Memory\Available MBytes',
            '\PhysicalDisk(_Total)\Avg. Disk sec/Read' -SampleInterval 5 -MaxSamples 12

# Export to CSV for trending
$counters = '\Processor(_Total)\% Processor Time', '\Memory\Available MBytes'
Get-Counter $counters -SampleInterval 10 -MaxSamples 360 |
    Export-Csv C:\Logs\perf_$(Get-Date -Format yyyyMMdd_HHmm).csv -NoTypeInformation

# Create Data Collector Set via logman
logman create counter "BaselineCapture" `
    -c "\Processor(*)\% Processor Time" "\Memory\Available MBytes" `
       "\PhysicalDisk(*)\Avg. Disk sec/Read" "\PhysicalDisk(*)\Disk Queue Length" `
       "\Network Interface(*)\Bytes Total/sec" `
    -si 00:00:15 -f csv -o C:\PerfLogs\Baseline -rf 01:00:00
```

---

## Diagnostic Workflows

### High CPU Investigation

```powershell
# 1. Identify top CPU consumers
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10

# 2. Per-core utilization
Get-Counter '\Processor(*)\% Processor Time' -MaxSamples 5 -SampleInterval 2

# 3. Check processor queue
Get-Counter '\System\Processor Queue Length' -MaxSamples 10

# 4. Kernel vs user split (high privileged = driver issue)
Get-Counter '\Processor(_Total)\% Privileged Time' -MaxSamples 5 -SampleInterval 2
```

### Memory Pressure Investigation

```powershell
# 1. Available memory trend
Get-Counter '\Memory\Available MBytes', '\Memory\Pages/sec' -MaxSamples 12 -SampleInterval 5

# 2. Top memory consumers
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name,
    @{N='WS_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}},
    @{N='PM_MB';E={[math]::Round($_.PagedMemorySize64/1MB,1)}}

# 3. Pool nonpaged leak check
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

# 2. Check Storage Spaces health
Get-VirtualDisk | Select-Object FriendlyName, OperationalStatus, HealthStatus

# 3. Physical disk SMART data
Get-PhysicalDisk | Get-StorageReliabilityCounter |
    Select-Object DeviceId, ReadErrorsTotal, WriteErrorsTotal, Temperature
```

### Network Connectivity Investigation

```powershell
# 1. Basic connectivity test
Test-NetConnection -ComputerName target -Port 443 -InformationLevel Detailed

# 2. DNS resolution
Resolve-DnsName target.domain.com -Server 10.1.1.10

# 3. Trace route
Test-NetConnection -ComputerName 8.8.8.8 -TraceRoute

# 4. Listening services
Get-NetTCPConnection -State Listen |
    Select-Object LocalPort,
        @{N='Process';E={(Get-Process -Id $_.OwningProcess -EA 0).Name}} |
    Sort-Object LocalPort
```

---

## System Information Commands

```powershell
# Comprehensive system info
Get-ComputerInfo | Select-Object CsName, OsName, OsVersion, OsArchitecture,
    CsProcessors, CsTotalPhysicalMemory, OsLastBootUpTime, OsUptime

# Via CIM
Get-CimInstance Win32_OperatingSystem |
    Select-Object Caption, Version, LastBootUpTime, FreePhysicalMemory, TotalVisibleMemorySize

# Installed hotfixes
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20

# Hardware inventory
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors
Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, @{N='GB';E={[math]::Round($_.Capacity/1GB)}}
Get-CimInstance Win32_DiskDrive | Select-Object Model, Size, MediaType, InterfaceType
```

---

## Network Diagnostics

### Command-Line Tools

```powershell
# Adapter status
Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress

# IP configuration
Get-NetIPConfiguration -Detailed

# Active TCP connections
Get-NetTCPConnection -State Established |
    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess

# SMB diagnostics
Get-SmbConnection | Select-Object ServerName, ShareName, UserName, Dialect
Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol, EnableSMB2Protocol, RequireSecuritySignature
```

### Packet Capture

```powershell
# netsh trace (built-in, no driver install)
netsh trace start capture=yes tracefile=C:\Logs\capture.etl maxsize=512
netsh trace stop

# pktmon (Server 2019+) -- kernel-level packet capture
pktmon start --capture --pkt-size 0 -f C:\Logs\pktmon.etl
pktmon stop
pktmon etl2pcap C:\Logs\pktmon.etl    # Wireshark-compatible

# pktmon filter
pktmon filter add -p 445   # SMB only
```

---

## Blue Screen / Stop Error Analysis

### Dump File Locations

| Type | Path | When to Use |
|---|---|---|
| Small (Mini) | `%SystemRoot%\Minidump\` | Quick analysis |
| Kernel | `%SystemRoot%\MEMORY.DMP` | Most common; kernel + crash context |
| Complete | `%SystemRoot%\MEMORY.DMP` | Full memory; very large |

```powershell
# Check current dump settings
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl |
    Select-Object CrashDumpEnabled, DumpFile, MiniDumpDir, AutoReboot
# CrashDumpEnabled: 0=None, 1=Complete, 2=Kernel, 3=Small, 7=Automatic
```

### Common Stop Codes

| Stop Code | Hex | Common Causes |
|---|---|---|
| IRQL_NOT_LESS_OR_EQUAL | 0xA | Driver accessing memory at wrong IRQL |
| PAGE_FAULT_IN_NONPAGED_AREA | 0x50 | Driver bug, bad RAM, corrupted system file |
| SYSTEM_SERVICE_EXCEPTION | 0x3B | Driver or system service exception |
| KERNEL_DATA_INPAGE_ERROR | 0x7A | Disk read failure |
| CRITICAL_PROCESS_DIED | 0xEF | Critical Windows process terminated |

### WinDbg Analysis

```
windbg -z C:\Windows\MEMORY.DMP
!analyze -v                 # Automated analysis
lm o m *                    # List third-party modules
kp                          # Stack trace
!poolused 2                 # Paged pool by tag
verifier /standard /driver suspect_driver.sys    # Enable Driver Verifier
```

---

## WinRM and PowerShell Remoting

```powershell
# Enable WinRM
Enable-PSRemoting -Force

# Check listeners
winrm enumerate winrm/config/listener

# Configure HTTPS listener
$thumb = (Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -like "*$(hostname)*").Thumbprint
winrm create winrm/config/Listener?Address=*+Transport=HTTPS `
    @{Hostname="$env:COMPUTERNAME"; CertificateThumbprint="$thumb"}

# Remote session
Enter-PSSession -ComputerName server01 -Credential domain\admin

# Batch execution
Invoke-Command -ComputerName srv1,srv2,srv3 -ScriptBlock { Get-Service WinRM }

# Troubleshooting
Test-WSMan -ComputerName server01 -Authentication Kerberos
# Firewall: TCP 5985 (HTTP), TCP 5986 (HTTPS)
# TrustedHosts for workgroup: Set-Item WSMan:\localhost\Client\TrustedHosts -Value "10.1.1.*"
```

---

## DTrace (Windows Server 2025)

```powershell
# Enable DTrace
Enable-WindowsOptionalFeature -FeatureName 'Microsoft-Windows-Subsystem-DTrace' -Online

# Count syscalls by process (10-second sample)
dtrace -n 'syscall:::entry { @[execname] = count(); }' -c "sleep 10"

# Trace file opens
dtrace -n 'syscall::NtCreateFile:entry { printf("%s opened file\n", execname); }'

# I/O latency histogram
dtrace -n 'io:::start { ts[arg0] = timestamp; }
           io:::done  { @[args[1]->dev_statname] = quantize(timestamp - ts[arg0]); }'
```

DTrace complements ETW for lower-level kernel probes. Requires `SeSystemProfilePrivilege` and `SeDebugPrivilege`.
