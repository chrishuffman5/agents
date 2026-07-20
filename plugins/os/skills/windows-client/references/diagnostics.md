# Windows Client Diagnostics Reference

---

## System File Repair

### System File Checker (SFC)

```powershell
sfc /scannow                                      # Scan and repair protected system files
sfc /verifyonly                                    # Scan only, no repair
sfc /scanfile=C:\Windows\System32\user32.dll       # Single file check

# Results log
Get-Content C:\Windows\Logs\CBS\CBS.log |
    Select-String 'Windows Resource Protection'
```

SFC validates all protected system files against the component store. If files are corrupted and SFC cannot repair them, run DISM first to fix the component store, then re-run SFC.

### DISM -- Component Store Health

```powershell
# Check component store health
DISM /Online /Cleanup-Image /CheckHealth        # Fast: reads corruption flag
DISM /Online /Cleanup-Image /ScanHealth         # Full scan: 10-15 min
DISM /Online /Cleanup-Image /RestoreHealth      # Repair from Windows Update

# Repair using local source (offline, no WU required)
DISM /Online /Cleanup-Image /RestoreHealth /Source:D:\Sources\SxS /LimitAccess

# Cleanup superseded components (reclaim disk space)
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase

# Log: C:\Windows\Logs\DISM\dism.log
```

### Repair Sequence

The correct order for system file repair is:
1. Run `DISM /Online /Cleanup-Image /RestoreHealth` to fix the component store
2. Run `sfc /scannow` to repair system files from the (now-healthy) component store
3. Reboot and verify

---

## Reliability Monitor

```
perfmon /rel
```

Graphical history of application crashes, Windows errors, and software installs over time. Reads from `Microsoft-Windows-Application-Experience/Program-Telemetry` event log. Most useful for finding the first crash event correlating with a symptom onset.

Use Reliability Monitor as the first stop when investigating user-reported issues. It correlates application failures, Windows failures, miscellaneous failures, warnings, and information events on a daily timeline.

---

## Windows Memory Diagnostic

```powershell
# Schedule memory test on next reboot
mdsched.exe

# Results in Event Log after reboot
Get-WinEvent -LogName 'System' | Where-Object { $_.Id -eq 1201 -or $_.Id -eq 1101 }
```

---

## DirectX Diagnostic Tool

```
dxdiag /t dxdiag_output.txt     # Text output for sharing
dxdiag                          # GUI with display, sound, input tabs
```

Reports GPU driver version, WDDM version, display mode, DirectX feature level, and sound device status.

---

## Driver Diagnostics

### Device Manager and pnputil

```powershell
# List all drivers in driver store
pnputil /enum-drivers

# List problem devices (error codes)
Get-PnpDevice | Where-Object Status -ne 'OK' |
    Select-Object FriendlyName, Status, Class, DeviceID

# Common device problem codes:
# Code 1  : Device not configured correctly
# Code 10 : Device cannot start (driver issue)
# Code 28 : Drivers not installed
# Code 43 : Device reported a problem (common for USB/GPU)
# Code 45 : Device not connected

# Export full device list
Get-PnpDevice | Select-Object FriendlyName, Class, Status, DriverVersion |
    Export-Csv devices.csv -NoTypeInformation
```

### Driver Verifier

```
verifier /standard /all                          # All non-Microsoft drivers (CAUTION: may BSOD)
verifier /standard /driver suspect_driver.sys    # Targeted driver testing
verifier /querysettings                          # Show current config
verifier /reset                                  # Disable driver verifier
```

Driver Verifier adds stress checks (deadlock detection, pool tracking, I/O verification) and forces a BSOD with `DRIVER_VERIFIER_DETECTED_VIOLATION` when a violation occurs. Only enable on test machines or to reproduce intermittent driver bugs.

### Driver Rollback

```powershell
# Via Device Manager GUI: Device Properties > Driver > Roll Back Driver

# Via PowerShell (get driver info before rollback)
Get-WmiObject Win32_PnPSignedDriver | Where-Object DeviceName -like '*Display*' |
    Select-Object DeviceName, DriverVersion, DriverDate, InfName
```

### Driver Signing Check

```powershell
# Find unsigned drivers
Get-WmiObject Win32_PnPSignedDriver | Where-Object { -not $_.IsSigned } |
    Select-Object DeviceName, DriverVersion, InfName
```

### GPU TDR Events

GPU Timeout Detection and Recovery events indicate the display driver became unresponsive and was reset:

```powershell
Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Id        = 4101
    StartTime = (Get-Date).AddDays(-7)
} -ErrorAction SilentlyContinue | Select-Object TimeCreated, Message
```

---

## App Compatibility Diagnostics

### Program Compatibility Troubleshooter

```
msdt.exe -id PCWDiagnostic     # Launch compatibility troubleshooter
```

Runs the app, monitors failures, suggests compatibility modes (OS version shim, privilege escalation, DPI fixes).

### Compatibility Administrator (ACT)

Standalone tool from Microsoft for enterprise app compat:
- Create shims: `CorrectFilePaths`, `FakeShellFolder`, `WinXPSP2VersionLie`, etc.
- Shim database (.sdb) deployed via GPO: `sdbinst.exe app_compat.sdb`
- View applied shims: `sdbinst -l`

### Compatibility Mode Registry

```powershell
# View compatibility flags for an app
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers' -EA SilentlyContinue
Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers' -EA SilentlyContinue
# Values like: "WIN8RTM HIGHDPIAWARE RUNASADMIN"
```

---

## Startup and Performance Diagnostics

### Task Manager Startup Tab

Shows apps enabled to run at user logon and their startup impact (Low/Medium/High). Impact is based on CPU time + disk I/O during the first 60 seconds of a logon session.

### msconfig

```
msconfig
```
- Boot tab: safe boot modes, boot logging, no-GUI boot, timeout
- Services tab: disable non-Microsoft services for clean boot testing
- Startup tab: redirects to Task Manager in Win8+

### Autoruns (Sysinternals)

Most comprehensive startup/persistence location scanner:
```
autoruns.exe -a *                  # All categories
autorunsc.exe -a * -c > ar.csv    # CLI output for scripting
autorunsc.exe -a * -nobanner -h md5,sha256 > ar_with_hashes.txt
```

Covers: Run keys, AppInit DLLs, Browser Helper Objects, Scheduled Tasks, Services, Drivers, Winlogon, LSA providers, Print monitors, Network providers, etc.

### Windows Performance Recorder / Analyzer (WPR/WPA)

```powershell
# Capture 30-second performance trace
wpr -start GeneralProfile -start CPU -start DiskIO -start FileIO
# ... reproduce the issue ...
wpr -stop C:\Traces\perf_trace.etl

# Open in WPA
wpa C:\Traces\perf_trace.etl
```

WPA visualizes ETW (Event Tracing for Windows) data. Key graphs:
- **CPU Usage (Sampled):** Flame-graph style call stack analysis
- **CPU Usage (Precise):** Context switch analysis, thread readiness
- **Disk I/O:** Latency by process and file
- **Generic Events:** App-specific ETW providers

### Performance Counters

Desktop-relevant counters:

**CPU:**
- `\Processor(_Total)\% Processor Time` -- Sustained >70% = warning, >90% = critical
- `\Processor(_Total)\% Privileged Time` -- >20% = possible driver issue
- `\System\Processor Queue Length` -- >2 per logical CPU = CPU bottleneck

**Memory:**
- `\Memory\Available MBytes` -- <10% of total RAM = warning
- `\Memory\Pages/sec` -- >100 = heavy paging

**Disk:**
- `\PhysicalDisk(_Total)\Avg. Disk sec/Read` -- >20ms (HDD) or >5ms (SSD) = concern
- `\PhysicalDisk(_Total)\Avg. Disk sec/Write` -- same thresholds

**GPU (desktop-specific):**
- `\GPU Engine(*)\Utilization Percentage` -- monitor per-engine utilization

```powershell
# Quick performance snapshot
Get-Counter '\Processor(_Total)\% Processor Time',
            '\Memory\Available MBytes',
            '\PhysicalDisk(_Total)\Avg. Disk sec/Read' -SampleInterval 5 -MaxSamples 6
```

---

## Storage Management -- Desktop Specific

### Storage Sense

Automatic cleanup scheduler (Win10 1703+):
- Deletes temp files, empties Recycle Bin after N days, removes Downloads older than N days
- Cleans up previous Windows versions (Windows.old) after set period
- Configuration: Settings > System > Storage > Storage Sense
- GPO: `Computer Config\Admin Templates\System\Storage Sense`

### Disk Cleanup (cleanmgr)

```powershell
cleanmgr /sageset:1     # Configure categories to clean
cleanmgr /sagerun:1     # Run configured cleanup unattended

# Most impactful categories:
#  - Windows Update Cleanup (multi-GB after major updates)
#  - Previous Windows installation(s) -- Windows.old (several GB)
#  - Delivery Optimization Files
#  - Temporary Internet Files
```

### WinSxS / Component Store

```powershell
# Check component store size
DISM /Online /Cleanup-Image /AnalyzeComponentStore

# Cleanup superseded components (irreversible -- removes rollback ability)
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase

# NOTE: Raw WinSxS folder size is inflated by hard links
# Use DISM AnalyzeComponentStore for accurate "Actual Size"
```

### Compact OS

```powershell
# Compress OS files to reclaim 1.5-2 GB on low-storage devices
compact /compactos:always    # Enable
compact /compactos:never     # Disable
compact /compactos:query     # Check current state
```

### Delivery Optimization Cache

```powershell
# Check cache size
Get-DeliveryOptimizationStatus |
    Select-Object CacheHost, CacheSizeInBytes, PeersCanDownloadFromMe

# Clear DO cache (requires admin)
Delete-DeliveryOptimizationCache -Force
```

---

## Power and Battery Diagnostics

```powershell
powercfg /a                  # Available sleep states
powercfg /sleepstudy         # 72-hour standby drain report (HTML)
powercfg /energy             # 60-second power efficiency trace
powercfg /batteryreport      # Battery capacity history (HTML)
powercfg /devicequery wake_armed    # Devices that can wake the system
```

### Common Power Issues

- **Unexpected wake from sleep:** Check `powercfg /lastwake` and `powercfg /devicequery wake_armed`
- **Battery drain in Modern Standby:** Use `powercfg /sleepstudy` to identify top drainers
- **Slow boot:** Enable boot logging with `msconfig` or capture with WPR boot trace
