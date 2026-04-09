# Windows Client (Win10/Win11) — Core Research

> **Scope note:** The Windows Server agent covers NT kernel internals, registry architecture,
> boot process, LSASS, service control manager, NTFS/ReFS, SMB, NDIS, WMI/CIM, and VBS/Credential
> Guard. This document covers **desktop-specific** architecture, management, and diagnostics only.

---

## Architecture Differences from Windows Server

### App Model

**Win32 Desktop Applications**
The classic Win32 API remains the dominant desktop programming model. Win32 apps communicate
with the OS through `kernel32.dll`, `user32.dll`, `gdi32.dll`, and `ntdll.dll`. They have no
store delivery, no automatic update infrastructure, and no sandboxing by default. Installation
typically modifies `HKLM\SOFTWARE`, `%ProgramFiles%`, and creates COM registrations.

**Universal Windows Platform (UWP)**
UWP provides a sandboxed, containerized app model with a unified API surface across device
families. Key characteristics:
- Runs in an AppContainer (`SECURITY_CAPABILITY_*` SIDs, strongly restricted token)
- Installed per-user or per-machine to `C:\Program Files\WindowsApps\` (ACL-locked)
- Declarative capabilities in `AppxManifest.xml` control resource access
- Lifecycle managed by PLM (Process Lifetime Manager): Suspend/Resume/Terminate
- Filesystem access confined to app package folder and brokered locations (Music, Pictures, etc.)

**MSIX Packaging**
MSIX is the modern Windows installer format, unifying the capabilities of MSI and App-V:
- Container format: ZIP-based `.msix` or `.msixbundle`
- Signed with a code-signing certificate (Windows validates at install and execution)
- Installs via copy-on-write virtual registry and virtual filesystem layers — no shared DLL hell
- Clean uninstall: no orphaned registry or file artifacts
- `AppxManifest.xml` declares identity, capabilities, entry points, and extensions
- Supports app packages for Win32 apps (Desktop Bridge / Centennial) without UWP sandboxing

**Desktop Bridge (Project Centennial)**
Allows repackaging legacy Win32 apps as MSIX without full UWP porting:
- Win32 process runs unmodified; MSIX container provides clean install/uninstall
- Can progressively add UWP extensions (live tiles, push notifications, background tasks)
- Registry writes to `HKCU\Software` and `HKLM\Software` are redirected to package private hive
- File writes outside allowed locations are virtualized

**WinUI 3 / Windows App SDK**
Microsoft's current recommended UI framework for new desktop apps:
- Decoupled from OS shipping cadence (ships via NuGet/Windows App SDK)
- Provides Fluent Design controls, XAML Islands for embedding in Win32 hosts
- Supports both packaged (MSIX) and unpackaged deployment
- Replaces WPF/WinForms for new development; WPF/WinForms still supported and receive updates

**App-V (Application Virtualization)**
Streaming virtual application packages for enterprise scenarios:
- App runs in an isolated virtual environment with virtualized registry, filesystem, COM
- Delivered via App-V Management/Publishing Server or ConfigMgr
- Package format: `.appv` (superseded by MSIX for new scenarios; App-V in extended support)
- Key registry paths: `HKLM\SOFTWARE\Microsoft\AppV\`

**Windows Package Manager (winget)**
CLI package manager included in Windows 10 1709+ and all Win11:
- Architecture: `winget.exe` → Windows Package Manager COM server → Sources (WinGet Community
  Repository, Microsoft Store, configured private feeds)
- Manifest format: YAML, published to `microsoft/winget-pkgs` GitHub repo
- Installer types supported: MSI, MSIX, EXE (silent), Burn, Inno Setup, NSIS, Portable
- DSC (Desired State Configuration) integration via `winget configure` using YAML config files
- Enterprise: supports private repo sources, REST-based source servers, group policy for source management

```
winget search <app>                          # Search community repo
winget install <id> --silent --accept-*      # Unattended install
winget upgrade --all --silent                # Upgrade everything
winget list                                  # Installed app inventory
winget configure --file config.dsc.yaml      # DSC-style configuration
```

---

### Driver Model — Desktop-Specific Stack

**WDDM (Windows Display Driver Model)**
GPU drivers on desktop use WDDM, not the server-oriented compute-only path:
- Introduced with Vista; current WDDM 3.x (Win11)
- Split into User-Mode Driver (UMD: `*_UMD.dll`) and Kernel-Mode Driver (KMD: `*.sys`)
- GPU scheduler (`dxgkrnl.sys`) preempts GPU workloads, preventing GPU hangs from killing the desktop
- TDR (Timeout Detection and Recovery): if GPU becomes unresponsive for >2 seconds, Windows
  resets the GPU without a BSOD — Event ID 4101 (display) or 4101 in System log

**Audio Stack**
Desktop-specific layered audio architecture:
```
App (WASAPI / DirectSound / Media Foundation)
  -> Audio Engine (audiodg.exe, user mode, isolated process)
     -> Audio Session API (ASIO bypass possible for pro audio)
     -> WaveRT miniport driver (kernel mode)
        -> Audio bus enumerator (PortCls.sys / HDAudio.sys)
```
- `audiodg.exe` runs as a low-privilege isolated process to protect the audio pipeline
- WASAPI Exclusive Mode bypasses mixing for low-latency professional audio

**Driver Signing Requirements**
- All kernel-mode drivers must be cross-signed by a trusted CA + signed by Microsoft via WHQL
  or Attestation signing (Dev Portal)
- Secure Boot + HVCI (Hypervisor-Protected Code Integrity) enforces this at runtime: unsigned
  or modified driver code cannot execute
- Test signing (self-signed): requires `bcdedit /set testsigning on` — disables Secure Boot
- Driver update sources priority: Windows Update WHQL → OEM OTA → Manual INF install

**Driver Rollback**
Device Manager → Driver tab → Roll Back Driver: restores previous driver version from
`C:\Windows\System32\DriverStore\FileRepository\` (driver store cache). `pnputil /enum-drivers`
lists all driver packages in the store.

---

### Desktop Window Manager (DWM)

`dwm.exe` is the composition engine that renders all on-screen windows:
- Runs in Session 1 (interactive desktop) as a protected process
- Each window's content is rendered off-screen to a DirectX surface (texture), then DWM
  composites all surfaces to the screen using GPU hardware
- Enables effects: transparency (Mica, Acrylic), blur, shadows, rounded corners (Win11)
- Hardware acceleration: DWM uses WDDM GPU scheduler; falling back to CPU composition is
  not possible — DWM crash triggers session restart

**Fluent Design System (Win11)**
- Mica: samples desktop wallpaper to tint app backgrounds
- Acrylic: blurred transparency effect for surfaces
- Rounded corners at 8px radius on Win11
- Snap Layouts: DWM + Shell coordinate to offer grid templates when hovering the maximize button
- Snap Groups: Shell tracks groups of snapped windows, restoring layout when taskbar thumbnail clicked

**DWM Diagnostics**
```powershell
# Check DWM process health
Get-Process dwm | Select-Object CPU, WorkingSet64, HandleCount

# GPU memory usage (requires WMI GPU performance counters)
Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction SilentlyContinue

# DWM event log
Get-WinEvent -LogName 'Microsoft-Windows-Dwm-Core/Operational' -MaxEvents 50
```

---

### Modern Standby / Connected Standby

Desktop differs fundamentally from Server in power management. Servers use S3 (Suspend to RAM)
or S4 (Hibernate); modern client devices use **S0 Low Power Idle** (Modern Standby):

| Aspect | S3 Sleep (legacy) | S0 Modern Standby |
|---|---|---|
| CPU state | Powered off | Low-power idle C-states |
| Network | Disconnected | Maintained (Wi-Fi/LTE connected) |
| Background tasks | None | Limited (email sync, notifications) |
| Wake latency | ~2 seconds | Instant (screen on = resumed) |
| Platform requirement | Any | Intel/AMD low-power platform, NVMe/eMMC |

**Check standby type:**
```powershell
powercfg /a                              # Lists available sleep states
powercfg /sleepstudy                     # 72-hour standby drain report (HTML)
powercfg /energy                         # 60-second power efficiency trace
powercfg /batteryreport                  # Battery capacity history
```

**Connected Standby concerns:**
- Devices with Modern Standby that cannot enter true S3 may drain faster
- Network Connected Standby (NCS) allows WNS (Windows Notification Service) wake
- `powercfg /sleepstudy` HTML report identifies apps with excessive standby drain

---

### Windows Store / App Installer

**Microsoft Store Architecture**
- Store client: `WinStore.App.exe` (UWP app)
- Backend: StorePurchaseApp service, `InstallService`
- App packages delivered as MSIX/AppX bundles to `C:\Program Files\WindowsApps\`
- App updates applied atomically — old version stays until new version fully staged

**App Installer (appinstaller)**
- `AppInstaller.exe` handles MSIX sideloading and `.appinstaller` manifest-based deployment
- `.appinstaller` XML file defines package source URL, version, update checking policy
- Used by winget for MSIX-based packages; also used for enterprise internal app distribution
- Sideloading requires: Developer Mode OR device in enterprise environment with sideload policy

**Sideloading Policy:**
```powershell
# Check if developer mode is enabled
(Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock).AllowDevelopmentWithoutDevLicense

# Check sideloading policy (enterprise)
(Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx -ErrorAction SilentlyContinue).AllowAllTrustedApps
```

---

## Best Practices

### Desktop Hardening

**CIS Benchmark for Windows Desktop (Level 1 highlights)**

| Setting | CIS L1 Value | Path |
|---|---|---|
| Interactive logon: Don't display last user name | Enabled | Security Options |
| Require CTRL+ALT+DEL | Enabled | Security Options |
| UAC: Behavior for admins | Prompt for consent on secure desktop | Security Options |
| UAC: Virtualize file/registry writes | Enabled | Security Options |
| Windows Firewall: All profiles | On, inbound block | Firewall settings |
| AutoPlay: Disable for all drives | Enabled | Computer Config |
| Bluetooth: Block discovery | Enabled | Computer Config |

**Microsoft Security Baselines (SCT)**
Download from Microsoft Security Compliance Toolkit; apply with LGPO.exe:
```powershell
# Apply Windows 11 security baseline
LGPO.exe /g ".\Windows 11 v23H2 Security Baseline\GPOs"

# Verify with Policy Analyzer
PolicyAnalyzer.exe /l ".\Baselines\Win11-v23H2.PolicyRules"
```

**Attack Surface Reduction (ASR) Rules**
ASR rules are Defender-based rules that block specific behaviors associated with malware:
```powershell
# Enable key ASR rules via Intune or PowerShell
Set-MpPreference -AttackSurfaceReductionRules_Ids @(
    'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550',  # Block executable content from email
    'D4F940AB-401B-4EFC-AADC-AD5F3C50688A',  # Block Office child processes
    '3B576869-A4EC-4529-8536-B80A7769E899',  # Block Office from creating executable content
    '75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84',  # Block Office from injecting into processes
    'D3E037E1-3EB8-44C8-A917-57927947596D',  # Block JS/VBS from launching downloaded content
    '5BEB7EFE-FD9A-4556-801D-275E5FFC04CC',  # Block execution of obfuscated scripts
    '92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B',  # Block Win32 API calls from Office macros
    '01443614-CD74-433A-B99E-2ECDC07BFCA'    # Block untrusted/unsigned process from USB
) -AttackSurfaceReductionRules_Actions @(1,1,1,1,1,1,1,1)  # 1=Block, 2=Audit
```

**Exploit Protection**
```powershell
# View current exploit protection settings
Get-ProcessMitigation -System
Get-ProcessMitigation -Name explorer.exe

# Enable CFG (Control Flow Guard) system-wide
Set-ProcessMitigation -System -Enable CFG

# Export/import for GPO distribution
Get-ProcessMitigation -RegistryConfigFilePath C:\EP_Config.xml
Set-ProcessMitigation -PolicyFilePath C:\EP_Config.xml
```

**Controlled Folder Access**
```powershell
# Enable (protects Documents, Desktop, Pictures, etc. from ransomware-like writes)
Set-MpPreference -EnableControlledFolderAccess Enabled

# Add protected folders
Add-MpPreference -ControlledFolderAccessProtectedFolders 'D:\FinancialData'

# Allow specific apps to write to protected folders
Add-MpPreference -ControlledFolderAccessAllowedApplications 'C:\Program Files\Backup\backup.exe'
```

---

### Intune / MDM Management

**Enrollment Methods**

| Method | Scenario | Join Type |
|---|---|---|
| Windows Autopilot | New device OOB provisioning | Entra ID join or Hybrid join |
| Bulk enrollment (provisioning package) | Kiosk / shared device | Entra ID join |
| Auto-enrollment via Group Policy | Existing AD-joined → co-management | Hybrid Entra ID join |
| BYOD (user-initiated) | Personal devices | Workplace registration |
| Entra ID join at OOBE | Cloud-first organizations | Entra ID join |

**Autopilot Flow**
```
OEM ships device with pre-registered Hardware ID
  -> Device powers on, connects to internet
  -> Windows OOBE contacts Autopilot service (AutopilotDeploymentProfile)
  -> Profile applied: skip pages, apply ESP (Enrollment Status Page)
  -> User authenticates with Entra ID
  -> Device enrolls in Intune automatically
  -> Intune pushes compliance policies, configuration profiles, apps
  -> ESP shows progress; user lands on desktop when complete
```

**Compliance Policies**
Compliance policies define the minimum security bar; non-compliant devices get Conditional Access blocked:
- Require BitLocker: OS drive encrypted
- Require Secure Boot: Secure Boot state = Enabled
- Minimum OS version: e.g., 10.0.19045 (Win10 22H2)
- Defender real-time protection: On
- Firewall: On

**Configuration Profiles (Intune)**
Replace GPO for cloud-managed devices. Key profile types:
- Settings Catalog: granular CSP-backed settings (mirrors GPO settings)
- Security Baselines: pre-built baseline profiles aligned with Microsoft recommendations
- Endpoint Security: Defender AV, firewall, ASR, Disk Encryption (BitLocker) from one blade
- Administrative Templates: ADMX-based settings (same as GPO ADMX)
- Custom OMA-URI: direct CSP paths for settings not yet surfaced in UI

**Co-Management with SCCM**
When both Intune and SCCM are active, workloads are split:
```
Co-management workloads (can slide to Intune):
  - Compliance policies
  - Resource access (Wi-Fi, VPN, cert profiles)
  - Endpoint Protection (Defender)
  - Device configuration
  - Windows Update policies
  - Office 365 client apps
  - Client apps (Win32 via Intune vs SCCM)
```

---

### Update Management

**Windows Update for Business (WUfB)**
WUfB is a policy-based update management approach using Windows Update service directly
(no on-premises WSUS required for cloud-managed):

| Update Type | Typical Deferral Range | Notes |
|---|---|---|
| Quality Update (monthly CU) | 0–30 days | Security + non-security fixes |
| Feature Update (annual) | 0–365 days | Major OS version upgrade |
| Driver updates | 0–30 days | Optional via WUfB |
| Microsoft product updates | Via WUfB setting | Office, .NET, etc. |

```powershell
# Check current WUfB deferral settings (registry)
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -ErrorAction SilentlyContinue |
    Select-Object DeferQualityUpdates, DeferQualityUpdatesPeriodInDays,
                  DeferFeatureUpdates, DeferFeatureUpdatesPeriodInDays,
                  TargetReleaseVersion, TargetReleaseVersionInfo
```

**Intune Update Rings**
Intune Update Rings map directly to WUfB registry policies:
- Ring 0 (Pilot): Quality defer 0d, Feature defer 0d — ~5% of fleet
- Ring 1 (Early): Quality defer 7d, Feature defer 30d — ~15% of fleet
- Ring 2 (Broad): Quality defer 14d, Feature defer 90d — remaining fleet
- Pause updates: Temporarily halt for up to 35 days when a bad update ships

**Delivery Optimization**
DO reduces WAN bandwidth by enabling peer-to-peer download within the same subnet or across
the organization via the DO cloud service:
```powershell
# Check DO mode
Get-DeliveryOptimizationStatus | Select-Object DownloadMode, DownloadModeSrc
# Mode 0=Off, 1=LAN, 2=Group, 3=Internet, 99=Bypass, 100=Simple

# DO statistics
Get-DeliveryOptimizationPerfSnapThisMonth

# DO cache location and size
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -ErrorAction SilentlyContinue
```

**Feature Update Targeting**
```powershell
# Pin to specific Windows 11 version (e.g., 23H2)
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' `
    -Name 'TargetReleaseVersion' -Value 1
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' `
    -Name 'TargetReleaseVersionInfo' -Value '23H2'
```

---

### BitLocker Management

**Enabling BitLocker — Requirements and Methods**

| Method | TPM | PIN | Scenario |
|---|---|---|---|
| TPM-only (Device Encryption) | Required | None | Consumer, simplified |
| TPM + PIN | Required | Yes (6+ digit) | Enterprise recommended |
| TPM + Network Unlock | Required | Network-based | Domain-joined, always unlocked on corp network |
| Password-only | Not required | Password | USB/removable (BitLocker To Go) |

```powershell
# Enable BitLocker on OS drive with TPM+PIN
$pin = ConvertTo-SecureString "123456" -AsPlainText -Force
Enable-BitLocker -MountPoint C: -EncryptionMethod XtsAes256 `
    -TPMandPINProtector -Pin $pin

# Add recovery key protector and back up to AD
Add-BitLockerKeyProtector -MountPoint C: -RecoveryPasswordProtector
$keyID = (Get-BitLockerVolume C:).KeyProtector | Where-Object KeyProtectorType -eq RecoveryPassword
Backup-BitLockerKeyProtector -MountPoint C: -KeyProtectorId $keyID.KeyProtectorId

# Back up to Entra ID (Intune)
BackupToAAD-BitLockerKeyProtector -MountPoint C: -KeyProtectorId $keyID.KeyProtectorId
```

**BitLocker Status**
```powershell
Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, EncryptionMethod,
    EncryptionPercentage, ProtectionStatus, LockStatus, KeyProtector
# ProtectionStatus: On=Protected, Off=Suspended
```

**Device Encryption (simplified BitLocker)**
Consumer-grade automatic encryption on InstantGo/Modern Standby devices:
- Enabled automatically on Entra ID join or Microsoft account sign-in
- Uses XTS-AES 128-bit; recovery key backed to Microsoft account or Entra ID
- Check: `manage-bde -status C:`
- No PIN required; transparent to user

**BitLocker To Go**
Encrypts removable drives (USB):
```powershell
Enable-BitLocker -MountPoint E: -EncryptionMethod XtsAes256 -PasswordProtector
```

**GPO/Intune Policies**
- `Computer Config\Admin Templates\Windows Components\BitLocker Drive Encryption`
- Key settings: Require additional auth at startup, encryption method (XTS-AES 256 recommended),
  recovery key backup (required for AD or Entra ID), startup PIN length

---

### Application Management

**winget Operations**
```powershell
# Install (silent, no prompts)
winget install --id Microsoft.VisualStudioCode --silent --accept-package-agreements --accept-source-agreements

# Upgrade all installed packages
winget upgrade --all --silent --include-unknown

# Export installed app list
winget export -o apps.json

# Import / restore from list
winget import -i apps.json --accept-package-agreements

# Configure with DSC YAML
winget configure --file .\dev-machine.dsc.yaml
```

**Chocolatey**
Community-maintained package manager, pre-dates winget:
- Admin-required install; packages install to `C:\ProgramData\chocolatey\`
- Enterprise: Chocolatey for Business with private repos, license management
- `choco install <pkg> -y`, `choco upgrade all -y`, `choco list --local-only`

**MSIX Deployment via PowerShell**
```powershell
# Add MSIX package
Add-AppxPackage -Path .\App.msix

# Provision for all users (requires admin)
Add-AppxProvisionedPackage -Online -PackagePath .\App.msix -SkipLicense

# Remove Store app for all users
Get-AppxPackage -Name Microsoft.ZuneMusic -AllUsers | Remove-AppxPackage -AllUsers
```

**Application Compatibility (Program Compatibility Assistant)**
- PCA monitors app crashes and failed installs; offers compatibility mode suggestion
- Compatibility modes available: Windows 7/8/8.1, reduced color, 640x480, DPI scaling
- Registry: `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`
- Application Compatibility Toolkit (ACT) / Compatibility Administrator: create shims for
  legacy apps (redirect file paths, fake API versions, inject DLLs)

---

## Diagnostics

### Desktop-Specific Diagnostic Tools

**Reliability Monitor**
```
perfmon /rel
```
Graphical history of application crashes, Windows errors, and software installs over time.
Reads from `Microsoft-Windows-Application-Experience/Program-Telemetry` event log.
Most useful for finding the first crash event correlating with a symptom onset.

**System File Checker (SFC)**
```powershell
sfc /scannow                     # Scan and repair protected system files
sfc /verifyonly                  # Scan only, no repair
sfc /scanfile=C:\Windows\System32\user32.dll   # Single file

# Results in: C:\Windows\Logs\CBS\CBS.log
# Find SFC output:
Get-Content C:\Windows\Logs\CBS\CBS.log | Select-String 'Windows Resource Protection'
```

**DISM — Component Store Health**
```powershell
# Check component store health
DISM /Online /Cleanup-Image /CheckHealth      # Fast: reads corruption flag
DISM /Online /Cleanup-Image /ScanHealth       # Full scan: 10-15 min
DISM /Online /Cleanup-Image /RestoreHealth    # Repair from Windows Update

# Repair using local source (offline, no WU required)
DISM /Online /Cleanup-Image /RestoreHealth /Source:D:\Sources\SxS /LimitAccess

# Cleanup superseded components (reclaim disk space)
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase

# Log: C:\Windows\Logs\DISM\dism.log
```

**Windows Memory Diagnostic**
```powershell
# Schedule memory test on next reboot
mdsched.exe

# Or via command:
Start-Process mdsched.exe

# Results in Event Log after reboot:
Get-WinEvent -LogName 'System' | Where-Object { $_.Id -eq 1201 -or $_.Id -eq 1101 }
```

**DirectX Diagnostic Tool**
```
dxdiag /t dxdiag_output.txt     # Text output for sharing
dxdiag                          # GUI with display, sound, input tabs
```
Reports GPU driver version, WDDM version, display mode, DirectX feature level, sound device status.

---

### Driver Diagnostics

**Device Manager and pnputil**
```powershell
# List all drivers in driver store
pnputil /enum-drivers

# List problem devices (error codes)
Get-PnpDevice | Where-Object Status -ne 'OK' | Select-Object FriendlyName, Status, Class, DeviceID

# Device problem codes
# Code 10: Device cannot start (driver issue)
# Code 28: Drivers not installed
# Code 43: Device reported a problem (common for USB/GPU)
# Code 45: Device not connected

# Export full device list
Get-PnpDevice | Select-Object FriendlyName, Class, Status, DriverVersion | Export-Csv devices.csv -NoTypeInformation
```

**Driver Verifier**
```
verifier /standard /all                      # Enable for all non-Microsoft drivers (CAUTION: may BSOD)
verifier /standard /driver suspect_driver.sys  # Targeted driver testing
verifier /querysettings                       # Show current verifier config
verifier /reset                              # Disable driver verifier
```
Driver Verifier adds stress checks (deadlock detection, pool tracking, I/O verification) and forces
a BSOD with the bugcheck code `DRIVER_VERIFIER_DETECTED_VIOLATION` when a violation occurs.
Only enable on test machines or to reproduce intermittent driver bugs.

**devcon (Windows Driver Kit tool)**
```
devcon status *               # Status of all devices
devcon disable @"PCI\VEN_*"   # Disable by hardware ID
devcon update driver.inf *PCI\VEN_1234  # Force driver update
devcon rescan                 # Trigger PnP re-enumeration
```

**Driver Rollback**
```powershell
# Via Device Manager GUI: Device Properties > Driver > Roll Back Driver

# Via PowerShell (get driver info before rollback)
Get-WmiObject Win32_PnPSignedDriver | Where-Object DeviceName -like '*Display*' |
    Select-Object DeviceName, DriverVersion, DriverDate, InfName
```

**Checking Driver Signing**
```powershell
# Find unsigned drivers
Get-WmiObject Win32_PnPSignedDriver | Where-Object { -not $_.IsSigned } |
    Select-Object DeviceName, DriverVersion, InfName
```

---

### App Compatibility Diagnostics

**Program Compatibility Troubleshooter**
```
msdt.exe -id PCWDiagnostic     # Launch compatibility troubleshooter
```
Runs the app, monitors failures, suggests compatibility modes (OS version shim, privilege escalation, DPI fixes).

**Compatibility Administrator (ACT)**
Standalone tool from Microsoft for enterprise app compat:
- Create shims: `CorrectFilePaths`, `FakeShellFolder`, `WinXPSP2VersionLie`, etc.
- Shim database (.sdb) deployed via GPO: `sdbinst.exe app_compat.sdb`
- View applied shims: `sdbinst -l` or check `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom`

**Compatibility Mode Registry**
```powershell
# View compatibility flags for an app
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers' -ErrorAction SilentlyContinue
Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers' -ErrorAction SilentlyContinue
# Values like: "WIN8RTM HIGHDPIAWARE RUNASADMIN"
```

---

### Startup and Performance Diagnostics

**Task Manager Startup Tab**
Shows apps enabled to run at user logon and their startup impact (Low/Medium/High).
Impact is based on CPU time + disk I/O during the first 60 seconds of a logon session.

**msconfig**
```
msconfig
```
- Boot tab: safe boot modes, boot logging, no-GUI boot, timeout
- Services tab: disable non-Microsoft services for clean boot testing
- Startup tab: redirects to Task Manager in Win8+

**Autoruns (Sysinternals)**
Most comprehensive startup/persistence location scanner:
```
autoruns.exe -a *                  # All categories
autorunsc.exe -a * -c > ar.csv    # CLI output for scripting
autorunsc.exe -a * -nobanner -h md5,sha256 > ar_with_hashes.txt
```
Covers: Run keys, AppInit DLLs, Browser Helper Objects, Scheduled Tasks, Services,
Drivers, Winlogon, LSA providers, Print monitors, Network providers, etc.
Use "Check VirusTotal" to submit hashes for unknown entries.

**Windows Performance Recorder / Analyzer (WPR/WPA)**
```powershell
# Capture 30-second performance trace
wpr -start GeneralProfile -start CPU -start DiskIO -start FileIO
# ... reproduce the issue ...
wpr -stop C:\Traces\perf_trace.etl

# Open in WPA
wpa C:\Traces\perf_trace.etl
```
WPA visualizes ETW (Event Tracing for Windows) data. Key graphs:
- CPU Usage (Sampled): flame-graph style call stack analysis
- CPU Usage (Precise): context switch analysis, thread readiness
- Disk I/O: latency by process and file
- Generic Events: app-specific ETW providers

---

### Storage Management — Desktop Specific

**Storage Sense**
Automatic cleanup scheduler (Win10 1703+):
- Deletes temp files, empties Recycle Bin after N days, removes Downloads older than N days
- Cleans up previous Windows versions (Windows.old) after set period
- Configuration: Settings > System > Storage > Storage Sense
- GPO: `Computer Config\Admin Templates\System\Storage Sense`

**Disk Cleanup (cleanmgr)**
```powershell
# Launch with all categories pre-selected (sageset token)
cleanmgr /sageset:1     # Configure categories to clean (writes to registry)
cleanmgr /sagerun:1     # Run configured cleanup unattended

# Most impactful categories:
#  - Windows Update Cleanup (can be multi-GB after major updates)
#  - Previous Windows installation(s) — Windows.old (several GB)
#  - Delivery Optimization Files
#  - Temporary Internet Files
```

**WinSxS / Component Store**
```powershell
# Check component store size
DISM /Online /Cleanup-Image /AnalyzeComponentStore

# Cleanup superseded components (irreversible — removes rollback ability)
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase

# Actual disk usage (hard links inflate reported size):
# Real size is much smaller than Explorer shows for C:\Windows\WinSxS
# Use DISM AnalyzeComponentStore for accurate "Actual Size of Component Store"
```

**Compact OS**
```powershell
# Compress OS files to reclaim 1.5-2 GB on low-storage devices
compact /compactos:always   # Enable Compact OS
compact /compactos:never    # Disable
compact /compactos:query    # Check current state

# Check current state via WMI
(Get-CimInstance Win32_OperatingSystem).OperatingSystemSKU
```

**Delivery Optimization Cache**
```powershell
# DO cache location: C:\Windows\SoftwareDistribution\DeliveryOptimization\
# Check cache size
Get-DeliveryOptimizationStatus | Select-Object CacheHost, CacheSizeInBytes, PeersCanDownloadFromMe

# Clear DO cache (requires admin)
Delete-DeliveryOptimizationCache -Force
```

---

## PowerShell Diagnostic Scripts

### 01-system-info.ps1

```powershell
<#
.SYNOPSIS
    Windows Client - System Information Dashboard
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. OS Identity and Build
        2. Hardware Summary (CPU/RAM/Disk/GPU)
        3. TPM and Secure Boot
        4. Activation Status
        5. Domain / Workgroup / Entra ID Status
        6. Intune Enrollment Status
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: OS Identity and Build
Write-Host "`n$sep`n SECTION 1 - OS Identity and Build`n$sep"

$os   = Get-CimInstance Win32_OperatingSystem
$cs   = Get-CimInstance Win32_ComputerSystem
$regCV = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue

[PSCustomObject]@{
    ComputerName     = $env:COMPUTERNAME
    OSCaption        = $os.Caption
    Edition          = $regCV.EditionID
    Version          = $regCV.DisplayVersion     # e.g., 23H2
    BuildNumber      = $os.BuildNumber
    UBR              = $regCV.UBR                # Update Build Revision
    FullBuild        = "$($os.BuildNumber).$($regCV.UBR)"
    OSArchitecture   = $os.OSArchitecture
    InstallDate      = $os.InstallDate
    LastBoot         = $os.LastBootUpTime
    UptimeDays       = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 1)
} | Format-List
#endregion

#region Section 2: Hardware Summary
Write-Host "$sep`n SECTION 2 - Hardware Summary`n$sep"

$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$disk = Get-CimInstance Win32_DiskDrive

[PSCustomObject]@{
    Manufacturer         = $cs.Manufacturer
    Model                = $cs.Model
    CPU                  = $cpu.Name
    Cores                = $cpu.NumberOfCores
    LogicalProcessors    = $cpu.NumberOfLogicalProcessors
    RAM_GB               = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    SystemType           = $cs.SystemType
} | Format-List

Write-Host "Disk Drives:"
$disk | Select-Object Model, @{N='Size_GB';E={[math]::Round($_.Size/1GB,0)}}, MediaType, InterfaceType |
    Format-Table -AutoSize

Write-Host "Logical Volumes:"
Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel,
    FileSystem, @{N='Size_GB';E={[math]::Round($_.Size/1GB,1)}},
    @{N='Free_GB';E={[math]::Round($_.SizeRemaining/1GB,1)}},
    @{N='Free_Pct';E={[math]::Round($_.SizeRemaining/$_.Size*100,0)}} |
    Format-Table -AutoSize

Write-Host "GPU(s):"
Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion,
    @{N='VRAM_MB';E={[math]::Round($_.AdapterRAM/1MB,0)}}, VideoModeDescription |
    Format-Table -AutoSize
#endregion

#region Section 3: TPM and Secure Boot
Write-Host "$sep`n SECTION 3 - TPM and Secure Boot`n$sep"

try {
    $tpm = Get-Tpm -ErrorAction Stop
    [PSCustomObject]@{
        TpmPresent       = $tpm.TpmPresent
        TpmReady         = $tpm.TpmReady
        TpmEnabled       = $tpm.TpmEnabled
        TpmActivated     = $tpm.TpmActivated
        ManufacturerId   = $tpm.ManufacturerId
        TpmVersion       = $tpm.ManufacturerIdTxt
        SpecVersion      = $tpm.SpecVersion
    } | Format-List
} catch {
    Write-Warning "TPM cmdlet not available: $($_.Exception.Message)"
    $tpmReg = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\TPM\WMI' -ErrorAction SilentlyContinue
    Write-Host "TPM registry state: $($tpmReg | Out-String)"
}

$secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
Write-Host "Secure Boot Enabled: $secureBoot"
#endregion

#region Section 4: Activation Status
Write-Host "$sep`n SECTION 4 - Activation Status`n$sep"

$slmgr = cscript //nologo C:\Windows\System32\slmgr.vbs /dli 2>&1
$slmgr | Select-String -Pattern 'License Status|Product Name|Partial Product Key' |
    ForEach-Object { Write-Host $_.Line }
#endregion

#region Section 5: Domain / Workgroup / Entra ID Status
Write-Host "$sep`n SECTION 5 - Domain / Entra ID Status`n$sep"

[PSCustomObject]@{
    Domain           = $cs.Domain
    DomainRole       = switch ($cs.DomainRole) {
                           0 {'Standalone Workstation'}
                           1 {'Member Workstation'}
                           2 {'Standalone Server'}
                           3 {'Member Server'}
                           4 {'Backup DC'} 5 {'Primary DC'}
                       }
    PartOfDomain     = $cs.PartOfDomain
    Workgroup        = if (-not $cs.PartOfDomain) { $cs.Workgroup } else { 'N/A' }
} | Format-List

# Entra ID (Azure AD) join status
$dsreg = dsregcmd /status 2>&1
$dsreg | Select-String -Pattern 'AzureAdJoined|DomainJoined|WorkplaceJoined|TenantName|DeviceAuthStatus' |
    ForEach-Object { Write-Host "  $($_.Line.Trim())" }
#endregion

#region Section 6: Intune Enrollment
Write-Host "$sep`n SECTION 6 - Intune Enrollment Status`n$sep"

$mdmReg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Enrollments\*' -ErrorAction SilentlyContinue
if ($mdmReg) {
    $mdmReg | Where-Object { $_.ProviderID -like '*Intune*' -or $_.EnrollmentType } |
        Select-Object PSChildName, ProviderID, EnrollmentType, UPN |
        Format-Table -AutoSize
} else {
    Write-Host "No MDM enrollment records found."
}

# Check MDM enrollment via dsregcmd
$dsreg | Select-String -Pattern 'MDMUrl|IsEnrolled|MdmDeviceID' |
    ForEach-Object { Write-Host "  $($_.Line.Trim())" }
#endregion

Write-Host "`n$sep`n System Info Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
```

---

### 02-performance-health.ps1

```powershell
<#
.SYNOPSIS
    Windows Client - Performance and Health Snapshot
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. CPU Utilization
        2. Memory Pressure
        3. Disk Usage and Health
        4. Startup Impact Items
        5. Resource-Heavy Processes
        6. Page File Configuration
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: CPU Utilization
Write-Host "`n$sep`n SECTION 1 - CPU Utilization`n$sep"

$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 5).CounterSamples |
    Measure-Object CookedValue -Average
$cpuPriv = (Get-Counter '\Processor(_Total)\% Privileged Time' -SampleInterval 2 -MaxSamples 3).CounterSamples |
    Measure-Object CookedValue -Average
$procQ   = (Get-Counter '\System\Processor Queue Length' -SampleInterval 2 -MaxSamples 3).CounterSamples |
    Measure-Object CookedValue -Average

[PSCustomObject]@{
    CPU_Avg_Pct        = [math]::Round($cpuLoad.Average, 1)
    Privileged_Pct     = [math]::Round($cpuPriv.Average, 1)
    ProcessorQueueLen  = [math]::Round($procQ.Average, 1)
    CPU_Assessment     = if ($cpuLoad.Average -gt 90) { 'CRITICAL: CPU saturated' }
                         elseif ($cpuLoad.Average -gt 70) { 'WARNING: High CPU' }
                         elseif ($cpuPriv.Average -gt 20) { 'INFO: High kernel/privileged time — possible driver issue' }
                         else { 'OK' }
} | Format-List
#endregion

#region Section 2: Memory Pressure
Write-Host "$sep`n SECTION 2 - Memory Pressure`n$sep"

$os        = Get-CimInstance Win32_OperatingSystem
$availMB   = [math]::Round($os.FreePhysicalMemory / 1KB, 0)
$totalGB   = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$usedGB    = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
$freePct   = [math]::Round($os.FreePhysicalMemory / $os.TotalVisibleMemorySize * 100, 1)
$pagesSec  = (Get-Counter '\Memory\Pages/sec' -MaxSamples 5 -SampleInterval 2).CounterSamples |
    Measure-Object CookedValue -Average

[PSCustomObject]@{
    Total_RAM_GB       = $totalGB
    Used_GB            = $usedGB
    Available_MB       = $availMB
    Free_Pct           = $freePct
    Pages_Per_Sec_Avg  = [math]::Round($pagesSec.Average, 1)
    Assessment         = if ($freePct -lt 5) { 'CRITICAL: Very low memory' }
                         elseif ($freePct -lt 10) { 'WARNING: Low memory' }
                         elseif ($pagesSec.Average -gt 100) { 'WARNING: Heavy paging detected' }
                         else { 'OK' }
} | Format-List
#endregion

#region Section 3: Disk Usage and Health
Write-Host "$sep`n SECTION 3 - Disk Usage and Health`n$sep"

Write-Host "Volume Free Space:"
Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel,
    @{N='Size_GB';E={[math]::Round($_.Size/1GB,1)}},
    @{N='Free_GB';E={[math]::Round($_.SizeRemaining/1GB,1)}},
    @{N='Free_Pct';E={[math]::Round($_.SizeRemaining/$_.Size*100,0)}},
    HealthStatus |
    Format-Table -AutoSize

Write-Host "`nDisk Latency (5-sample average):"
$readLat  = (Get-Counter '\PhysicalDisk(_Total)\Avg. Disk sec/Read' -MaxSamples 5 -SampleInterval 2 -ErrorAction SilentlyContinue).CounterSamples |
    Measure-Object CookedValue -Average
$writeLat = (Get-Counter '\PhysicalDisk(_Total)\Avg. Disk sec/Write' -MaxSamples 5 -SampleInterval 2 -ErrorAction SilentlyContinue).CounterSamples |
    Measure-Object CookedValue -Average

[PSCustomObject]@{
    ReadLatency_ms  = [math]::Round($readLat.Average * 1000, 2)
    WriteLatency_ms = [math]::Round($writeLat.Average * 1000, 2)
    Assessment      = if ($readLat.Average * 1000 -gt 50 -or $writeLat.Average * 1000 -gt 50) {
                          'WARNING: High disk latency (>50ms)' }
                      elseif ($readLat.Average * 1000 -gt 20) { 'INFO: Elevated read latency' }
                      else { 'OK' }
} | Format-List
#endregion

#region Section 4: Startup Impact Items
Write-Host "$sep`n SECTION 4 - Startup Impact Items`n$sep"

$startupItems = Get-CimInstance Win32_StartupCommand |
    Select-Object Name, Command, Location, User
$startupItems | Format-Table -AutoSize

Write-Host "Startup count: $($startupItems.Count)"
if ($startupItems.Count -gt 15) {
    Write-Warning "Large number of startup items ($($startupItems.Count)) — may impact boot/logon time."
}
#endregion

#region Section 5: Resource-Heavy Processes
Write-Host "$sep`n SECTION 5 - Top Resource-Heavy Processes`n$sep"

Write-Host "Top 10 by CPU:"
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, Id,
    @{N='CPU_s';E={[math]::Round($_.CPU,1)}},
    @{N='WS_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}},
    @{N='Handles';E={$_.HandleCount}} | Format-Table -AutoSize

Write-Host "`nTop 10 by Working Set (RAM):"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, Id,
    @{N='WS_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}},
    @{N='PM_MB';E={[math]::Round($_.PagedMemorySize64/1MB,1)}} | Format-Table -AutoSize
#endregion

#region Section 6: Page File Configuration
Write-Host "$sep`n SECTION 6 - Page File Configuration`n$sep"

Get-CimInstance Win32_PageFileUsage | Select-Object Name,
    @{N='AllocatedBase_MB';E={$_.AllocatedBaseSize}},
    @{N='CurrentUsage_MB';E={$_.CurrentUsage}},
    @{N='PeakUsage_MB';E={$_.PeakUsage}} | Format-Table -AutoSize

$autoMgd = (Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile
Write-Host "System-managed page file: $autoMgd"
if ($autoMgd) { Write-Host "INFO: Windows manages page file size automatically." }
#endregion

Write-Host "`n$sep`n Performance Health Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
```

---

### 03-update-compliance.ps1

```powershell
<#
.SYNOPSIS
    Windows Client - Windows Update Compliance Check
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Current OS Version vs Latest
        2. Pending Updates
        3. Last Installed Updates
        4. WUfB Deferral Policies
        5. Delivery Optimization Status
        6. Update Service Configuration
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: Current OS Version
Write-Host "`n$sep`n SECTION 1 - OS Version and Feature Update Status`n$sep"

$regCV = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$os    = Get-CimInstance Win32_OperatingSystem

[PSCustomObject]@{
    Caption          = $os.Caption
    DisplayVersion   = $regCV.DisplayVersion        # e.g., 23H2
    BuildNumber      = $os.BuildNumber
    UBR              = $regCV.UBR
    FullBuild        = "$($os.BuildNumber).$($regCV.UBR)"
    ReleaseId        = $regCV.ReleaseId
} | Format-List
#endregion

#region Section 2: Pending Updates
Write-Host "$sep`n SECTION 2 - Pending Windows Updates`n$sep"

try {
    $updateSession   = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher  = $updateSession.CreateUpdateSearcher()
    Write-Host "Searching for pending updates (may take 30-60 seconds)..."
    $searchResult    = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
    $updates         = $searchResult.Updates

    if ($updates.Count -eq 0) {
        Write-Host "OK: No pending updates found."
    } else {
        Write-Warning "$($updates.Count) pending update(s) found:"
        for ($i = 0; $i -lt $updates.Count; $i++) {
            $u = $updates.Item($i)
            [PSCustomObject]@{
                Title       = $u.Title.Substring(0, [Math]::Min(80, $u.Title.Length))
                KB          = ($u.KBArticleIDs | ForEach-Object { "KB$_" }) -join ', '
                Severity    = $u.MsrcSeverity
                SizeMB      = [math]::Round($u.MaxDownloadSize / 1MB, 1)
                IsDownloaded = $u.IsDownloaded
            }
        } | Format-Table -AutoSize
    }
} catch {
    Write-Warning "Windows Update COM not available: $($_.Exception.Message)"
}
#endregion

#region Section 3: Last Installed Updates
Write-Host "$sep`n SECTION 3 - Recently Installed Updates (Last 15)`n$sep"

Get-HotFix | Sort-Object InstalledOn -Descending -ErrorAction SilentlyContinue |
    Select-Object -First 15 HotFixID, Description, InstalledOn, InstalledBy |
    Format-Table -AutoSize

$lastPatch = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
if ($lastPatch.InstalledOn) {
    $age = ((Get-Date) - $lastPatch.InstalledOn).Days
    $msg = "Last patch ($($lastPatch.HotFixID)) installed $age days ago"
    if ($age -gt 45) { Write-Warning "$msg — REVIEW: May be out of compliance." }
    else { Write-Host "$msg — OK." }
}
#endregion

#region Section 4: WUfB Deferral Policies
Write-Host "$sep`n SECTION 4 - Windows Update for Business Deferral Settings`n$sep"

$wufb = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -ErrorAction SilentlyContinue
$au   = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -ErrorAction SilentlyContinue

if ($wufb) {
    [PSCustomObject]@{
        QualityUpdateDeferred       = [bool]$wufb.DeferQualityUpdates
        QualityDeferral_Days        = $wufb.DeferQualityUpdatesPeriodInDays
        FeatureUpdateDeferred       = [bool]$wufb.DeferFeatureUpdates
        FeatureDeferral_Days        = $wufb.DeferFeatureUpdatesPeriodInDays
        TargetVersion               = $wufb.TargetReleaseVersionInfo
        BranchReadinessLevel        = $wufb.BranchReadinessLevel
        PauseQualityUpdatesEndDate  = $wufb.PauseQualityUpdatesEndTime
        PauseFeatureUpdatesEndDate  = $wufb.PauseFeatureUpdatesEndTime
        WUServer                    = $wufb.WUServer
    } | Format-List
} else {
    Write-Host "No WUfB policy configured. Device uses default Windows Update settings."
}

if ($au) {
    Write-Host "AU Policy:"
    $au | Select-Object AUOptions, AutoInstallMinorUpdates, NoAutoUpdate,
        ScheduledInstallDay, ScheduledInstallTime | Format-List
}
#endregion

#region Section 5: Delivery Optimization
Write-Host "$sep`n SECTION 5 - Delivery Optimization Status`n$sep"

try {
    $doStatus = Get-DeliveryOptimizationStatus -ErrorAction Stop
    $doStatus | Select-Object FileId, Status, DownloadMode, BytesFromPeers,
        BytesFromGroupPeers, BytesFromCacheServer, BytesFromHttp,
        TotalBytesDownloaded | Format-Table -AutoSize -ErrorAction SilentlyContinue

    $doPerfMonth = Get-DeliveryOptimizationPerfSnapThisMonth -ErrorAction SilentlyContinue
    if ($doPerfMonth) {
        Write-Host "DO Monthly Summary:"
        $doPerfMonth | Format-List
    }
} catch {
    $doMode = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -ErrorAction SilentlyContinue).DODownloadMode
    Write-Host "DO Download Mode (policy): $doMode"
    Write-Host "  0=Off, 1=LAN peers, 2=Group, 3=Internet peers, 99=Bypass, 100=Simple"
}
#endregion

#region Section 6: Update Service Configuration
Write-Host "$sep`n SECTION 6 - Windows Update Service Configuration`n$sep"

$wuService = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
Write-Host "Windows Update Service: Status=$($wuService.Status), StartType=$($wuService.StartType)"

$doService = Get-Service -Name DoSvc -ErrorAction SilentlyContinue
Write-Host "Delivery Optimization Service: Status=$($doService.Status)"

# Check if managed by WSUS
$wsusServer = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -ErrorAction SilentlyContinue).WUServer
if ($wsusServer) {
    Write-Host "Managed by WSUS: $wsusServer"
} else {
    Write-Host "Update source: Windows Update (cloud) or not policy-configured"
}
#endregion

Write-Host "`n$sep`n Update Compliance Check Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
```

---

### 04-security-posture.ps1

```powershell
<#
.SYNOPSIS
    Windows Client - Security Posture Assessment
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Microsoft Defender Antivirus Status
        2. Firewall Profile Status
        3. BitLocker Status (All Volumes)
        4. Credential Guard and VBS
        5. Exploit Protection Settings
        6. ASR Rules Status
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: Microsoft Defender AV Status
Write-Host "`n$sep`n SECTION 1 - Microsoft Defender Antivirus`n$sep"

try {
    $defStatus = Get-MpComputerStatus -ErrorAction Stop
    [PSCustomObject]@{
        AMRunningMode             = $defStatus.AMRunningMode
        RealTimeProtectionEnabled = $defStatus.RealTimeProtectionEnabled
        AntivirusEnabled          = $defStatus.AntivirusEnabled
        AntispywareEnabled        = $defStatus.AntispywareEnabled
        BehaviorMonitorEnabled    = $defStatus.BehaviorMonitorEnabled
        IoavProtectionEnabled     = $defStatus.IoavProtectionEnabled
        NISEnabled                = $defStatus.NISEnabled
        OnAccessProtectionEnabled = $defStatus.OnAccessProtectionEnabled
        AntivirusSignatureVersion = $defStatus.AntivirusSignatureVersion
        AntivirusSigAge_Days      = $defStatus.AntivirusSignatureAge
        LastQuickScanDate         = $defStatus.QuickScanStartTime
        LastFullScanDate          = $defStatus.FullScanStartTime
        TamperProtectionSource    = $defStatus.TamperProtectionSource
        Assessment                = if (-not $defStatus.RealTimeProtectionEnabled) { 'CRITICAL: Real-time protection OFF' }
                                    elseif ($defStatus.AntivirusSignatureAge -gt 7) { 'WARNING: Definitions older than 7 days' }
                                    else { 'OK' }
    } | Format-List
} catch {
    Write-Warning "Defender Get-MpComputerStatus failed: $($_.Exception.Message)"
}

Write-Host "Active Threats:"
Get-MpThreatDetection -ErrorAction SilentlyContinue |
    Select-Object -First 10 ThreatName, ActionSuccess, InitialDetectionTime, RemediationTime |
    Format-Table -AutoSize
#endregion

#region Section 2: Firewall Profile Status
Write-Host "$sep`n SECTION 2 - Windows Firewall Profiles`n$sep"

Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction,
    LogAllowed, LogBlocked, LogFileName | Format-Table -AutoSize

# Count rules per profile
Write-Host "Firewall rule counts:"
foreach ($profile in @('Domain','Private','Public')) {
    $count = (Get-NetFirewallRule -Enabled True -Direction Inbound -ErrorAction SilentlyContinue |
        Where-Object { $_.Profile -match $profile -or $_.Profile -eq 'Any' }).Count
    Write-Host "  $profile inbound enabled: $count"
}
#endregion

#region Section 3: BitLocker Status
Write-Host "$sep`n SECTION 3 - BitLocker Status (All Volumes)`n$sep"

$blVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
if ($blVolumes) {
    $blVolumes | Select-Object MountPoint, VolumeType, VolumeStatus, ProtectionStatus,
        EncryptionMethod, EncryptionPercentage, LockStatus,
        @{N='KeyProtectors';E={($_.KeyProtector | ForEach-Object { $_.KeyProtectorType }) -join ', '}} |
        Format-Table -AutoSize

    foreach ($vol in $blVolumes) {
        if ($vol.VolumeType -eq 'OperatingSystem' -and $vol.ProtectionStatus -ne 'On') {
            Write-Warning "OS drive ($($vol.MountPoint)) is NOT BitLocker protected."
        }
        if ($vol.KeyProtector.Count -eq 0) {
            Write-Warning "Volume $($vol.MountPoint) has no key protectors — recovery may be impossible."
        }
    }
} else {
    Write-Host "BitLocker cmdlets not available or no volumes to report."
    # Fallback
    manage-bde -status 2>&1 | Select-String -Pattern 'Conversion Status|Protection Status|Key Protectors'
}
#endregion

#region Section 4: Credential Guard and VBS
Write-Host "$sep`n SECTION 4 - Credential Guard and Virtualization-Based Security`n$sep"

try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
    [PSCustomObject]@{
        VBSStatus              = switch ($dg.VirtualizationBasedSecurityStatus) { 0{'Off'} 1{'Configured, not running'} 2{'Running'} }
        CredentialGuard        = if ($dg.SecurityServicesRunning -band 1) { 'Running' } else { 'Not Running' }
        HVCI                   = if ($dg.SecurityServicesRunning -band 2) { 'Running' } else { 'Not Running' }
        SecureBootAvailable    = if ($dg.AvailableSecurityProperties -band 2) { 'Yes' } else { 'No' }
        TPMAvailable           = if ($dg.AvailableSecurityProperties -band 4) { 'Yes' } else { 'No' }
        Assessment             = if ($dg.VirtualizationBasedSecurityStatus -eq 0) { 'WARNING: VBS is off — Credential Guard disabled' }
                                 elseif ($dg.SecurityServicesRunning -band 1) { 'OK: Credential Guard running' }
                                 else { 'INFO: VBS configured but Credential Guard not running' }
    } | Format-List
} catch {
    Write-Warning "DeviceGuard WMI unavailable: $($_.Exception.Message)"
}
#endregion

#region Section 5: Exploit Protection
Write-Host "$sep`n SECTION 5 - Exploit Protection (System-Level)`n$sep"

try {
    $ep = Get-ProcessMitigation -System -ErrorAction Stop
    [PSCustomObject]@{
        CFG         = $ep.CFG.Enable
        SEHOP       = $ep.SEHOP.Enable
        DEP         = $ep.DEP.Enable
        ForceRelocate = $ep.ASLR.ForceRelocateImages
        BottomUpASLR  = $ep.ASLR.BottomUp
    } | Format-List
} catch {
    Write-Warning "Get-ProcessMitigation not available: $($_.Exception.Message)"
}
#endregion

#region Section 6: ASR Rules Status
Write-Host "$sep`n SECTION 6 - Attack Surface Reduction Rules`n$sep"

try {
    $pref = Get-MpPreference -ErrorAction Stop
    $ids    = $pref.AttackSurfaceReductionRules_Ids
    $actions = $pref.AttackSurfaceReductionRules_Actions

    $asrNames = @{
        'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550' = 'Block executable content from email'
        'D4F940AB-401B-4EFC-AADC-AD5F3C50688A' = 'Block Office child processes'
        '3B576869-A4EC-4529-8536-B80A7769E899' = 'Block Office executable content'
        '75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84' = 'Block Office code injection'
        '5BEB7EFE-FD9A-4556-801D-275E5FFC04CC' = 'Block obfuscated script execution'
        '92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B' = 'Block Win32 API from Office macros'
    }

    if ($ids) {
        for ($i = 0; $i -lt $ids.Count; $i++) {
            [PSCustomObject]@{
                RuleName = $asrNames[$ids[$i]] ?? $ids[$i]
                Action   = switch ($actions[$i]) { 0{'Off'} 1{'Block'} 2{'Audit'} 6{'Warn'} }
            }
        } | Format-Table -AutoSize
    } else {
        Write-Host "No ASR rules configured via policy."
    }
} catch {
    Write-Warning "ASR rule query failed: $($_.Exception.Message)"
}
#endregion

Write-Host "`n$sep`n Security Posture Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
```

---

### 05-network-diagnostics.ps1

```powershell
<#
.SYNOPSIS
    Windows Client - Network Diagnostics
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Network Adapters (Wi-Fi and Ethernet)
        2. IP and DNS Configuration
        3. Connected Networks and Profiles
        4. VPN Connections
        5. Proxy Settings
        6. Active Connections and Firewall Rules
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: Network Adapters
Write-Host "`n$sep`n SECTION 1 - Network Adapters`n$sep"

Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, MediaType,
    LinkSpeed, MacAddress, DriverVersion,
    @{N='Assessment';E={
        if ($_.Status -eq 'Up') { 'Connected' }
        elseif ($_.Status -eq 'Disconnected') { 'Not connected' }
        else { $_.Status }
    }} | Format-Table -AutoSize

# Wi-Fi specific info
$wifi = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wi-Fi|Wireless|802.11|WLAN' }
if ($wifi) {
    Write-Host "`nWi-Fi Details:"
    netsh wlan show interfaces 2>&1 | Where-Object { $_ -match 'SSID|Signal|Radio|Channel|State|Authentication' } |
        ForEach-Object { Write-Host "  $_" }
}
#endregion

#region Section 2: IP and DNS Configuration
Write-Host "$sep`n SECTION 2 - IP and DNS Configuration`n$sep"

Get-NetIPConfiguration | ForEach-Object {
    [PSCustomObject]@{
        Interface    = $_.InterfaceAlias
        IPv4         = $_.IPv4Address.IPAddress -join ', '
        IPv4Prefix   = $_.IPv4Address.PrefixLength -join ', '
        Gateway      = $_.IPv4DefaultGateway.NextHop -join ', '
        DNS          = $_.DNSServer.ServerAddresses -join ', '
        IPv6         = $_.IPv6Address.IPAddress -join ', '
    }
} | Format-Table -AutoSize

Write-Host "`nDNS suffix search list:"
(Get-DnsClientGlobalSetting).SuffixSearchList | ForEach-Object { Write-Host "  $_" }

Write-Host "`nDNS connectivity test:"
try {
    $dnsTest = Resolve-DnsName -Name "www.microsoft.com" -Type A -ErrorAction Stop | Select-Object -First 1
    Write-Host "  DNS resolution OK: www.microsoft.com -> $($dnsTest.IPAddress)"
} catch {
    Write-Warning "DNS resolution failed: $($_.Exception.Message)"
}
#endregion

#region Section 3: Connected Networks and Profiles
Write-Host "$sep`n SECTION 3 - Connected Networks and Profiles`n$sep"

Get-NetConnectionProfile | Select-Object Name, NetworkCategory, IPv4Connectivity,
    IPv6Connectivity, InterfaceAlias | Format-Table -AutoSize

Write-Host "`nNetwork Adapter Statistics:"
Get-NetAdapterStatistics | Select-Object Name,
    @{N='ReceivedMB';E={[math]::Round($_.ReceivedBytes/1MB,1)}},
    @{N='SentMB';E={[math]::Round($_.SentBytes/1MB,1)}},
    ReceivedUnicastPackets, SentUnicastPackets,
    @{N='RecvErrors';E={$_.ReceivedDiscardedPackets + $_.ReceivedPacketErrors}} |
    Where-Object { $_.ReceivedMB -gt 0 } | Format-Table -AutoSize
#endregion

#region Section 4: VPN Connections
Write-Host "$sep`n SECTION 4 - VPN Connections`n$sep"

$vpnConns = Get-VpnConnection -ErrorAction SilentlyContinue
if ($vpnConns) {
    $vpnConns | Select-Object Name, ServerAddress, TunnelType, AuthenticationMethod,
        EncryptionLevel, ConnectionStatus, SplitTunneling | Format-Table -AutoSize
} else {
    Write-Host "No VPN connections configured."
}

# Also check for Always On VPN (device tunnel)
$vpnDevice = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue
if ($vpnDevice) {
    Write-Host "All-user VPN connections:"
    $vpnDevice | Select-Object Name, ServerAddress, ConnectionStatus | Format-Table -AutoSize
}
#endregion

#region Section 5: Proxy Settings
Write-Host "$sep`n SECTION 5 - Proxy Settings`n$sep"

$proxyReg = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
[PSCustomObject]@{
    ProxyEnabled   = [bool]$proxyReg.ProxyEnable
    ProxyServer    = $proxyReg.ProxyServer
    ProxyOverride  = $proxyReg.ProxyOverride
    AutoConfigURL  = $proxyReg.AutoConfigURL
} | Format-List

# WINHTTP proxy (used by system/services)
Write-Host "WinHTTP system proxy:"
netsh winhttp show proxy 2>&1 | ForEach-Object { Write-Host "  $_" }
#endregion

#region Section 6: Active Connections
Write-Host "$sep`n SECTION 6 - Active External TCP Connections`n$sep"

Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
    Where-Object { $_.RemoteAddress -ne '127.0.0.1' -and $_.RemoteAddress -ne '::1' } |
    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort,
        @{N='Process';E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name}},
        @{N='PID';E={$_.OwningProcess}} |
    Sort-Object Process | Format-Table -AutoSize
#endregion

Write-Host "`n$sep`n Network Diagnostics Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
```

---

### 06-driver-health.ps1

```powershell
<#
.SYNOPSIS
    Windows Client - Driver Health and Inventory
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Problem Devices (Non-OK Status)
        2. Driver Inventory (Sorted by Date)
        3. Unsigned Drivers
        4. Recently Installed Drivers (Last 30 Days)
        5. Display Driver (WDDM) Status
        6. Driver Error Events (Last 7 Days)
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: Problem Devices
Write-Host "`n$sep`n SECTION 1 - Problem Devices (Non-OK Status)`n$sep"

$problemDevices = Get-PnpDevice | Where-Object { $_.Status -ne 'OK' }
if ($problemDevices) {
    $problemDevices | Select-Object FriendlyName, Class, Status, Problem, DeviceID |
        Format-Table -AutoSize

    # Decode common problem codes
    $problemDevices | ForEach-Object {
        $code = $_.Problem
        $meaning = switch ($code) {
            10 { 'Device cannot start (driver issue or resource conflict)' }
            28 { 'Drivers not installed' }
            43 { 'Device reported a problem (common for USB/GPU after crash)' }
            45 { 'Device not connected' }
            1  { 'Device not configured correctly' }
            default { "Problem code $code" }
        }
        Write-Host "  $($_.FriendlyName): Code $code — $meaning"
    }
} else {
    Write-Host "OK: All devices report status OK."
}
#endregion

#region Section 2: Driver Inventory
Write-Host "$sep`n SECTION 2 - Driver Inventory (All Third-Party Signed Drivers)`n$sep"

$drivers = Get-WmiObject Win32_PnPSignedDriver | Where-Object { $_.DriverName } |
    Sort-Object DriverDate -Descending

Write-Host "Total signed drivers: $($drivers.Count)"
$drivers | Select-Object -First 30 DeviceName,
    @{N='DriverVersion';E={$_.DriverVersion}},
    @{N='DriverDate';E={if ($_.DriverDate) { [Management.ManagementDateTimeConverter]::ToDateTime($_.DriverDate).ToString('yyyy-MM-dd') } else { 'N/A' }}},
    @{N='Manufacturer';E={$_.Manufacturer}},
    InfName | Format-Table -AutoSize
#endregion

#region Section 3: Unsigned Drivers
Write-Host "$sep`n SECTION 3 - Unsigned Drivers`n$sep"

$unsigned = Get-WmiObject Win32_PnPSignedDriver | Where-Object { -not $_.IsSigned -and $_.DeviceName }
if ($unsigned) {
    Write-Warning "$($unsigned.Count) unsigned driver(s) found:"
    $unsigned | Select-Object DeviceName, DriverVersion, InfName | Format-Table -AutoSize
} else {
    Write-Host "OK: No unsigned drivers found."
}
#endregion

#region Section 4: Recently Installed Drivers
Write-Host "$sep`n SECTION 4 - Recently Installed/Updated Drivers (Last 30 Days)`n$sep"

$cutoff = (Get-Date).AddDays(-30)
$recentDrivers = Get-WmiObject Win32_PnPSignedDriver | Where-Object {
    $_.DriverDate -and
    [Management.ManagementDateTimeConverter]::ToDateTime($_.DriverDate) -gt $cutoff
} | Sort-Object DriverDate -Descending

if ($recentDrivers) {
    $recentDrivers | Select-Object DeviceName,
        @{N='DriverDate';E={[Management.ManagementDateTimeConverter]::ToDateTime($_.DriverDate).ToString('yyyy-MM-dd')}},
        DriverVersion, Manufacturer | Format-Table -AutoSize
} else {
    Write-Host "No drivers installed or updated in the last 30 days."
}
#endregion

#region Section 5: Display Driver (WDDM)
Write-Host "$sep`n SECTION 5 - Display Driver and WDDM Status`n$sep"

Get-CimInstance Win32_VideoController | ForEach-Object {
    [PSCustomObject]@{
        Name             = $_.Name
        DriverVersion    = $_.DriverVersion
        DriverDate       = $_.DriverDate
        Status           = $_.Status
        VRAM_MB          = [math]::Round($_.AdapterRAM/1MB, 0)
        CurrentRefreshHz = $_.CurrentRefreshRate
        VideoProcessor   = $_.VideoProcessor
        VideoMode        = $_.VideoModeDescription
    }
} | Format-List

# Check for TDR events (GPU timeout/reset)
Write-Host "Recent GPU TDR Events (Event ID 4101):"
Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Id        = 4101
    StartTime = (Get-Date).AddDays(-7)
} -ErrorAction SilentlyContinue | Select-Object -First 10 TimeCreated, Message |
    Format-Table -AutoSize
#endregion

#region Section 6: Driver Error Events
Write-Host "$sep`n SECTION 6 - Driver Error Events (Last 7 Days)`n$sep"

$driverErrors = Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Level     = 2  # Error
    StartTime = (Get-Date).AddDays(-7)
} -ErrorAction SilentlyContinue | Where-Object { $_.ProviderName -match 'disk|driver|pnp|ACPI|volmgr|storahci|nvlddmkm' }

if ($driverErrors) {
    $driverErrors | Select-Object -First 20 TimeCreated, ProviderName, Id,
        @{N='Message';E={$_.Message.Substring(0,[Math]::Min(100,$_.Message.Length))}} |
        Format-Table -AutoSize
} else {
    Write-Host "No driver-related errors in System log in the last 7 days."
}

# pnputil driver store summary
Write-Host "`nDriver Store Package Count:"
$pnpOutput = pnputil /enum-drivers 2>&1
$pkgCount  = ($pnpOutput | Select-String 'Published Name').Count
Write-Host "  Total packages in driver store: $pkgCount"
#endregion

Write-Host "`n$sep`n Driver Health Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
```

---

### 07-app-inventory.ps1

```powershell
<#
.SYNOPSIS
    Windows Client - Application Inventory
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Win32 Apps (Registry-Based)
        2. Store / UWP Apps (AppxPackage)
        3. winget List (if available)
        4. Startup Programs
        5. Scheduled Tasks (User-Visible)
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: Win32 Apps
Write-Host "`n$sep`n SECTION 1 - Win32 Installed Applications (Registry)`n$sep"

$regPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$win32Apps = $regPaths | ForEach-Object {
    Get-ItemProperty $_ -ErrorAction SilentlyContinue
} | Where-Object { $_.DisplayName } | Select-Object DisplayName,
    DisplayVersion, Publisher, InstallDate,
    @{N='Architecture';E={if ($_.PSPath -match 'WOW6432') {'x86'} else {'x64/Other'}}} |
    Sort-Object DisplayName

Write-Host "Total Win32 apps: $($win32Apps.Count)"
$win32Apps | Format-Table -AutoSize
#endregion

#region Section 2: Store / UWP Apps
Write-Host "$sep`n SECTION 2 - Microsoft Store / UWP Apps`n$sep"

$storeApps = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
    Where-Object { $_.SignatureKind -ne 'System' } |
    Select-Object Name, Version, Publisher,
        @{N='Architecture';E={$_.Architecture}},
        @{N='InstallLocation';E={$_.InstallLocation.Substring(0,[Math]::Min(60,$_.InstallLocation.Length))}},
        PackageUserInformation |
    Sort-Object Name

Write-Host "Total Store/UWP apps: $($storeApps.Count)"
$storeApps | Select-Object Name, Version, Architecture | Format-Table -AutoSize
#endregion

#region Section 3: winget List
Write-Host "$sep`n SECTION 3 - winget Installed Packages`n$sep"

$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    Write-Host "winget version: $(winget --version)"
    Write-Host "winget list output:"
    winget list --accept-source-agreements 2>&1 | Select-Object -First 60 | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "winget not found or not in PATH."
}
#endregion

#region Section 4: Startup Programs
Write-Host "$sep`n SECTION 4 - Startup Programs (All Sources)`n$sep"

$startupSources = @()

# Registry Run keys
$runKeys = @(
    @{Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Scope='Machine'},
    @{Path='HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Scope='Machine-x86'},
    @{Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Scope='User'}
)
foreach ($key in $runKeys) {
    $props = Get-ItemProperty $key.Path -ErrorAction SilentlyContinue
    if ($props) {
        $props.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
            $startupSources += [PSCustomObject]@{
                Source  = $key.Scope
                Name    = $_.Name
                Command = $_.Value.Substring(0, [Math]::Min(80, $_.Value.ToString().Length))
            }
        }
    }
}

# Startup folders
$startupFolders = @(
    @{Path="$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"; Scope='AllUsers'},
    @{Path="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; Scope='CurrentUser'}
)
foreach ($folder in $startupFolders) {
    if (Test-Path $folder.Path) {
        Get-ChildItem $folder.Path -ErrorAction SilentlyContinue | ForEach-Object {
            $startupSources += [PSCustomObject]@{
                Source  = $folder.Scope
                Name    = $_.Name
                Command = $_.FullName
            }
        }
    }
}

Write-Host "Total startup entries: $($startupSources.Count)"
$startupSources | Format-Table -AutoSize
#endregion

#region Section 5: Scheduled Tasks
Write-Host "$sep`n SECTION 5 - User-Visible Scheduled Tasks (Enabled)`n$sep"

Get-ScheduledTask | Where-Object {
    $_.State -eq 'Ready' -and
    $_.TaskPath -notlike '\Microsoft\*'
} | Select-Object TaskName, TaskPath, State,
    @{N='Author';E={$_.Author}},
    @{N='LastRun';E={(Get-ScheduledTaskInfo $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue).LastRunTime}} |
    Sort-Object TaskPath, TaskName | Format-Table -AutoSize
#endregion

Write-Host "`n$sep`n App Inventory Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
```

---

### 08-disk-cleanup.ps1

```powershell
<#
.SYNOPSIS
    Windows Client - Disk Cleanup Analysis and Recommendations
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Volume Free Space Summary
        2. Temporary Files
        3. WinSxS Component Store Analysis
        4. Windows.old / Previous OS
        5. Delivery Optimization Cache
        6. User Profile Sizes
        7. Storage Sense Configuration
        8. Reclaim Recommendations
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

# Helper: Get folder size in MB
function Get-FolderSizeMB {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $size = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object Length -Sum).Sum
        return [math]::Round($size / 1MB, 1)
    } catch { return 0 }
}

#region Section 1: Volume Free Space
Write-Host "`n$sep`n SECTION 1 - Volume Free Space`n$sep"

Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel,
    @{N='Size_GB';E={[math]::Round($_.Size/1GB,1)}},
    @{N='Free_GB';E={[math]::Round($_.SizeRemaining/1GB,1)}},
    @{N='Free_Pct';E={[math]::Round($_.SizeRemaining/$_.Size*100,0)}},
    @{N='Assessment';E={
        $pct = [math]::Round($_.SizeRemaining/$_.Size*100,0)
        if ($pct -lt 5) { 'CRITICAL: Very low disk space' }
        elseif ($pct -lt 10) { 'WARNING: Low disk space' }
        else { 'OK' }
    }} | Format-Table -AutoSize
#endregion

#region Section 2: Temporary Files
Write-Host "$sep`n SECTION 2 - Temporary Files`n$sep"

$tempPaths = @(
    @{Path=$env:TEMP; Label='User TEMP'},
    @{Path='C:\Windows\Temp'; Label='Windows TEMP'},
    @{Path='C:\Windows\SoftwareDistribution\Download'; Label='WU Download Cache'}
)

foreach ($t in $tempPaths) {
    $sizeMB = Get-FolderSizeMB $t.Path
    [PSCustomObject]@{
        Location = $t.Label
        Path     = $t.Path
        Size_MB  = $sizeMB
        Size_GB  = [math]::Round($sizeMB/1024,2)
    }
} | Format-Table -AutoSize
#endregion

#region Section 3: WinSxS Component Store
Write-Host "$sep`n SECTION 3 - WinSxS Component Store Analysis`n$sep"

Write-Host "Running DISM component store analysis (may take 1-3 minutes)..."
$dismOutput = DISM /Online /Cleanup-Image /AnalyzeComponentStore 2>&1
$dismOutput | ForEach-Object { Write-Host "  $_" }

# Also report raw folder size (misleading due to hard links, but useful as upper bound)
$winSxsRaw = Get-FolderSizeMB 'C:\Windows\WinSxS'
Write-Host "`nRaw WinSxS folder size (inflated by hard links): $winSxsRaw MB"
Write-Host "NOTE: Use DISM AnalyzeComponentStore 'Actual Size' for accurate figure."
#endregion

#region Section 4: Windows.old / Previous OS
Write-Host "$sep`n SECTION 4 - Windows.old and Previous Installation Files`n$sep"

$windowsOld = Get-FolderSizeMB 'C:\Windows.old'
if ($windowsOld -gt 0) {
    Write-Warning "Windows.old folder found: $windowsOld MB ($([math]::Round($windowsOld/1024,1)) GB)"
    Write-Host "  To remove: DISM /Online /Cleanup-Image /StartComponentCleanup"
    Write-Host "  Or: Disk Cleanup (cleanmgr) > Previous Windows installation(s)"
} else {
    Write-Host "OK: No Windows.old folder found."
}

# Check for other previous version artifacts
$prevDirs = @('C:\$Windows.~BT', 'C:\$Windows.~WS', 'C:\$WinREAgent')
foreach ($d in $prevDirs) {
    if (Test-Path $d) {
        $sizeMB = Get-FolderSizeMB $d
        Write-Host "  Found $d : $sizeMB MB"
    }
}
#endregion

#region Section 5: Delivery Optimization Cache
Write-Host "$sep`n SECTION 5 - Delivery Optimization Cache`n$sep"

$doCachePath = 'C:\Windows\SoftwareDistribution\DeliveryOptimization'
$doCacheMB   = Get-FolderSizeMB $doCachePath

[PSCustomObject]@{
    CachePath = $doCachePath
    CacheMB   = $doCacheMB
    CacheGB   = [math]::Round($doCacheMB / 1024, 2)
    Note      = 'Cleared automatically; or: Delete-DeliveryOptimizationCache -Force'
} | Format-List

try {
    $doPerf = Get-DeliveryOptimizationPerfSnapThisMonth -ErrorAction Stop
    $doPerf | Select-Object DownloadBytesFromPeers, DownloadBytesFromCacheServer,
        DownloadBytesFromHttp, UploadBytesToPeers | Format-List
} catch {
    Write-Host "DO performance counters not available."
}
#endregion

#region Section 6: User Profile Sizes
Write-Host "$sep`n SECTION 6 - User Profile Sizes`n$sep"

$profiles = Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special } |
    Sort-Object LocalPath

foreach ($profile in $profiles) {
    $sizeMB = Get-FolderSizeMB $profile.LocalPath
    [PSCustomObject]@{
        UserProfile  = $profile.LocalPath
        SID          = $profile.SID.Substring(0, [Math]::Min(30, $profile.SID.Length)) + '...'
        Size_MB      = $sizeMB
        Size_GB      = [math]::Round($sizeMB / 1024, 2)
        LastUseTime  = $profile.LastUseTime
    }
} | Format-Table -AutoSize
#endregion

#region Section 7: Storage Sense Configuration
Write-Host "$sep`n SECTION 7 - Storage Sense Configuration`n$sep"

$ssReg = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense' -ErrorAction SilentlyContinue
$ssUser = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' -ErrorAction SilentlyContinue

[PSCustomObject]@{
    PolicyEnabled          = $ssReg.AllowStorageSenseGlobal
    UserStorageSenseOn     = $ssUser.'01'
    RunFrequency           = switch ($ssUser.'2048') { 1{'Every day'} 7{'Every week'} 30{'Every month'} default{'When low on space'} }
    DeleteTempFilesOnClean = $ssUser.'04'
    RecycleBinDays         = $ssUser.'08'
    DownloadsDays          = $ssUser.'32'
} | Format-List
#endregion

#region Section 8: Reclaim Recommendations
Write-Host "$sep`n SECTION 8 - Reclaim Recommendations`n$sep"

$totalReclaimMB = 0
$recommendations = @()

if ($windowsOld -gt 500) {
    $totalReclaimMB += $windowsOld
    $recommendations += "Windows.old: ~$([math]::Round($windowsOld/1024,1)) GB — Safe to remove if upgrade is stable"
}

$wuDownloadMB = Get-FolderSizeMB 'C:\Windows\SoftwareDistribution\Download'
if ($wuDownloadMB -gt 500) {
    $totalReclaimMB += $wuDownloadMB
    $recommendations += "WU Download cache: ~$([math]::Round($wuDownloadMB/1024,1)) GB — Stop wuauserv, delete, restart"
}

if ($doCacheMB -gt 1000) {
    $totalReclaimMB += $doCacheMB * 0.5  # DO manages its own cache; partial
    $recommendations += "Delivery Optimization cache: ~$([math]::Round($doCacheMB/1024,1)) GB — Run: Delete-DeliveryOptimizationCache -Force"
}

$userTempMB = Get-FolderSizeMB $env:TEMP
if ($userTempMB -gt 200) {
    $totalReclaimMB += $userTempMB
    $recommendations += "User TEMP (%TEMP%): ~$([math]::Round($userTempMB/1024,1)) GB — Safe to delete contents"
}

if ($recommendations) {
    Write-Host "Cleanup opportunities:"
    $recommendations | ForEach-Object { Write-Host "  * $_" }
    Write-Host "`nEstimated total reclaimable: ~$([math]::Round($totalReclaimMB/1024,1)) GB"
    Write-Host "`nQuick cleanup commands (run as admin):"
    Write-Host "  cleanmgr /sageset:99 && cleanmgr /sagerun:99    # GUI cleanup all categories"
    Write-Host "  DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase    # WinSxS"
} else {
    Write-Host "OK: No major cleanup opportunities identified."
}
#endregion

Write-Host "`n$sep`n Disk Cleanup Analysis Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
```
