# Windows 11 — Version-Specific Research

**Scope:** Features NEW or CHANGED in Windows 11 only. Cross-version content lives in references/.
**Supported Versions:** 23H2 (Enterprise/Education), 24H2, 25H2, 26H1, LTSC 2024
**Build baseline:** 10.0.22000 (21H2 GA, October 5, 2021) through 10.0.26100 (24H2)
**LTSC 2024:** Based on 24H2, security updates only, mainstream until October 2029

---

## 1. Hardware Requirements

### Minimum Requirements (New vs Windows 10)

Windows 11 introduced the most significant hardware floor increase in Windows history. All requirements are enforced at install time and cannot be bypassed on unsupported hardware via normal channels.

| Requirement       | Windows 10        | Windows 11            |
|-------------------|-------------------|-----------------------|
| TPM               | 1.2 recommended   | 2.0 required          |
| Secure Boot       | Optional          | UEFI + Secure Boot required |
| CPU               | No approved list  | Approved list enforced |
| RAM               | 1 GB (32-bit)     | 4 GB minimum          |
| Storage           | 16 GB             | 64 GB minimum         |
| Display           | 800x600           | 720p, 9-inch+ diagonal |
| DirectX           | 9                 | DirectX 12 / WDDM 2.0 |
| Firmware          | BIOS or UEFI      | UEFI (no legacy BIOS) |
| Internet          | Optional          | Required for Home edition setup |
| Microsoft Account | Optional          | Required for Home edition |

### Approved CPU Families

**Intel:** 8th generation Core (Coffee Lake) and newer. Intel Celeron/Pentium requires 10th gen or newer. Intel Core X-series (Skylake-X based) is excluded despite being newer than 8th gen for marketing reasons — only specific 10th gen X-series are supported.

**AMD:** Zen 2 (Ryzen 3000 series) and newer. First-gen Ryzen (Zen/Zen+) and Ryzen 2000 (Zen+) are excluded.

**Qualcomm:** Snapdragon 7c and newer (ARM64). Snapdragon 850 and earlier excluded.

**VM CPUs:** Any CPU that exposes the above features to the guest. For Hyper-V: Generation 2 VM, vTPM enabled, Secure Boot enabled.

### Why These Requirements Exist

The hardware floor is directly tied to **Virtualization Based Security (VBS)** and **Hypervisor-Protected Code Integrity (HVCI)** being enabled by default on new Windows 11 installs. These require:
- **TPM 2.0** — stores VBS secrets, provides measured boot attestation
- **UEFI Secure Boot** — ensures the bootloader is Microsoft-signed before VBS can initialize
- **CPU virtualization extensions** — VT-x/AMD-V for the Hyper-V hypervisor that hosts VSM (Virtual Secure Mode)
- **SLAT (Second Level Address Translation)** — EPT (Intel) or RVI (AMD) required for HVCI memory isolation

HVCI default-on is the core reason older CPUs are excluded: pre-8th-gen Intel and pre-Zen2 AMD have performance regressions with HVCI enabled due to microarchitectural differences in how they handle the additional page table walks required by the hypervisor.

### VM-Specific Requirements

```powershell
# Hyper-V: Create Windows 11-compatible VM
New-VM -Name "Win11" -Generation 2 -MemoryStartupBytes 4GB -NewVHDPath "C:\VMs\Win11.vhdx" -NewVHDSizeBytes 64GB

# Enable vTPM (required for Windows 11 guest)
Enable-VMTPM -VMName "Win11"

# Verify Secure Boot is enabled (default on Gen2, verify anyway)
Get-VMFirmware -VMName "Win11" | Select-Object SecureBoot, SecureBootTemplate

# Set Secure Boot template for Windows 11 (use MicrosoftWindows or MicrosoftUEFICertificateAuthority)
Set-VMFirmware -VMName "Win11" -SecureBootTemplate MicrosoftWindows

# Check vTPM is present and enabled
Get-VMSecurity -VMName "Win11" | Select-Object TpmEnabled, Shielded
```

---

## 2. New UX Features

### Centered Taskbar and Redesigned Start Menu

The taskbar is center-aligned by default (can be moved to left via Settings → Personalization → Taskbar → Taskbar behaviors → Taskbar alignment). The Start menu is no longer a full-screen overlay and does not support live tiles. It shows a Pinned section and a Recommended section (recent files/apps, driven by AI ranking). No folder groups in the pinned area (added back in later versions). Start menu does not support resizing.

**Group Policy:** `Computer Configuration > Administrative Templates > Start Menu and Taskbar` — many Windows 10 policies carry over but several Start/Taskbar policies are new for Windows 11.

### Snap Layouts and Snap Groups

Snap Layouts appear on hover over the maximize button (Win+Z keyboard shortcut). Layouts vary by screen resolution and aspect ratio — wider screens get more layouts. Snap Groups persist in the taskbar when snapped windows are minimized; re-clicking restores all windows in the snap group.

```powershell
# Check/enforce Snap Layouts via registry
$snapKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
# EnableSnapAssistFlyout: 1 = show layout flyout on hover (default), 0 = disable
Set-ItemProperty -Path $snapKey -Name 'EnableSnapAssistFlyout' -Value 1 -Type DWord

# Disable Snap completely (removes all snap functionality)
Set-ItemProperty -Path $snapKey -Name 'SnapEnabled' -Value 0 -Type DWord
```

**Group Policy (24H2+):** `User Configuration > Administrative Templates > Windows Components > Snap` — new policies added in 24H2 for more granular Snap control in enterprise environments.

### Virtual Desktops

Windows 11 adds per-desktop wallpaper (each virtual desktop can have a unique background). Desktop names persist across reboots. Task View (Win+Tab) shows desktop previews with the ability to drag windows between desktops directly.

### Widgets Board

Widgets is a new full-height sidebar (Win+W) powered by Microsoft Start. It shows news, weather, calendar, stocks, and third-party widgets. Widgets requires a Microsoft Account for personalization. In enterprise environments, Widgets can be disabled via policy.

```powershell
# Disable Widgets via registry (applies to current user)
$widgetKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty -Path $widgetKey -Name 'TaskbarDa' -Value 0 -Type DWord

# Disable Widgets via Group Policy (Computer scope)
# HKLM:\SOFTWARE\Policies\Microsoft\Dsh -> AllowNewsAndInterests = 0
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' `
    -Name 'AllowNewsAndInterests' -Value 0 -Type DWord -Force
```

### Fluent Design and WinUI 3

Windows 11 ships the first system-wide Fluent Design refresh since Windows 10 launched. Changes:
- **Rounded corners** on all windows (8px radius), dialogs, and context menus — cannot be disabled via UI
- **Mica material** — translucent system-tinted backgrounds on title bars and app chrome (acrylic replaced by Mica for inbox apps)
- **New system sounds** — redesigned sound set (softer, higher frequency); spatial audio improvements
- **WinUI 3** — XAML Islands evolution; inbox apps (Settings, File Explorer shell) rebuilt on WinUI 3 framework

### Focus Sessions

Integrated in Clock app. Focus sessions integrate with Spotify and Microsoft To Do. Do Not Disturb mode activates automatically during focus sessions. Focus session history shown in Widgets.

### Notification Center Redesign

Notification Center (Win+N) is separated from the Calendar flyout. Notifications and Calendar are now two distinct panels. Notification grouping by app. Quick Settings (Win+A) is a separate panel from notifications — previously combined in Action Center.

---

## 3. Dev Drive

### Overview

Dev Drive is a **ReFS-formatted storage volume** optimized for developer workloads, introduced in Windows 11 23H2 (September 2023 update). It is not available on Windows 10. Dev Drive uses ReFS (Resilient File System) with performance mode enabled, which relaxes certain real-time antivirus scanning behaviors in Microsoft Defender.

### Key Characteristics

- **File system:** ReFS (not NTFS). Implications: no native BitLocker encryption, no disk quotas, no file compression, no symbolic link support from legacy apps that require NTFS-specific APIs.
- **Performance mode:** Defender scans are deferred (async post-write scan instead of synchronous pre-write scan). Package manager caches (npm, pip, NuGet, cargo, Maven) benefit most.
- **Minimum size:** 50 GB recommended. No enforced minimum but Microsoft documents 50 GB as practical floor.
- **Location:** Can be a new volume on an existing disk (requires unallocated space) or a VHD/VHDX.

### Configuration

**Via Settings:** Settings → System → Storage → Advanced storage settings → Disks & volumes → Create Dev Drive

**Via PowerShell:**

```powershell
# Create a Dev Drive on unallocated space (requires existing unallocated partition)
# First, identify the disk with unallocated space
Get-Disk | Select-Object Number, FriendlyName, Size, AllocatedSize,
    @{N='FreeSpace'; E={ $_.Size - $_.AllocatedSize }}

# Create a new partition on unallocated space
$disk = Get-Disk -Number 1   # adjust disk number
$partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter

# Format as ReFS with Dev Drive performance mode
Format-Volume -DriveLetter $partition.DriveLetter `
    -FileSystem ReFS `
    -DevDrive `
    -NewFileSystemLabel "DevDrive" `
    -Confirm:$false

# Verify the volume is formatted as Dev Drive
Get-Volume -DriveLetter $partition.DriveLetter |
    Select-Object DriveLetter, FileSystem, FileSystemLabel, Size, SizeRemaining
```

### Verify Dev Drive Status and Performance Mode

```powershell
# List all ReFS volumes (potential Dev Drives)
Get-Volume | Where-Object FileSystem -eq 'ReFS' |
    Select-Object DriveLetter, FileSystemLabel, Size, SizeRemaining, HealthStatus

# Check Defender performance mode trust for Dev Drive paths
# Defender trusts Dev Drive volumes automatically; verify via:
Get-MpPreference | Select-Object PerformanceModeStatus

# Check if a specific volume is designated as Dev Drive
# (Dev Drive volumes have a specific flag in the volume metadata)
$vol = Get-Volume -DriveLetter D
$vol | Select-Object DriveLetter, FileSystem, @{N='IsDevDrive'; E={ $_.FileSystem -eq 'ReFS' }}
```

### Defender Integration

In performance mode, Defender uses **asynchronous scanning** rather than blocking file I/O. The volume is trusted at the volume level, not per-directory. Third-party AV products must explicitly support Dev Drive performance mode — they do not inherit it automatically. If a third-party AV is installed and does not declare Dev Drive support, Defender's performance mode is disabled for that volume.

### Pitfalls

- BitLocker is not supported on ReFS volumes. If encryption is required, use a VHD/VHDX on a BitLocker-protected NTFS volume and format the VHD as ReFS Dev Drive.
- Some build tools (older MSBuild, Makefiles) may have issues with ReFS on first use; test before migrating entire repos.
- Dev Drive is not supported in Windows Sandbox or WSL directly — map a folder into WSL from the Dev Drive path.

---

## 4. Copilot+ PC Features

### NPU Requirements

Copilot+ PC is a hardware tier, not a software edition. Requirements:
- **NPU (Neural Processing Unit):** 40+ TOPS (Tera Operations Per Second) of dedicated AI compute
- **RAM:** 16 GB minimum
- **Storage:** 256 GB minimum SSD
- Qualcomm Snapdragon X Elite/Plus, AMD Ryzen AI 300 series, Intel Core Ultra 200V series

Standard Windows 11 installs on non-Copilot+ hardware do not surface Copilot+ features even after feature updates.

### Windows Recall

**Availability:** Copilot+ PCs only. Preview launched June 2024, made generally available in late 2024 after security review.

Recall takes periodic screenshots of the active screen and uses local AI (on-device NPU) to index content for natural language search. All processing is local — screenshots are stored encrypted on-device, accessible only to the signed-in user.

**Security model:**
- Recall snapshots stored in `%LocalAppData%\CoreAIPlatform.00\UKP\{GUID}\`
- Database is encrypted with DPAPI (Data Protection API), user-scope
- Recall can be disabled from Settings → Privacy & Security → Recall & snapshots
- Sensitive content filtering (credit cards, passwords) is on by default

**Enterprise control:**

```powershell
# Disable Recall via policy (HKLM scope — requires admin)
$recallKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
if (-not (Test-Path $recallKey)) { New-Item -Path $recallKey -Force | Out-Null }
Set-ItemProperty -Path $recallKey -Name 'DisableAIDataAnalysis' -Value 1 -Type DWord

# Verify Recall is disabled
Get-ItemProperty -Path $recallKey -Name 'DisableAIDataAnalysis' -ErrorAction SilentlyContinue
```

### Windows Studio Effects

Camera AI enhancements running on the NPU. Available on Copilot+ PCs and some Surface devices with dedicated NPU support (earlier than 40 TOPS requirement).

- **Background blur / replacement** — processed by NPU, no CPU overhead
- **Eye contact correction** — AI adjusts gaze to appear to look at camera when reading screen
- **Auto framing** — keeps face centered as person moves; crops/pans the camera feed
- **Voice focus** — microphone noise suppression via NPU

Configured in Settings → Bluetooth & devices → Cameras → [Camera name] → Studio Effects, or via the Camera app settings. No PowerShell API — controlled via DMFT (Device Media Foundation Transform) at the driver level.

### Copilot App Model Changes

| Version | Copilot Implementation |
|---------|------------------------|
| 23H2    | Copilot sidebar (Win+C), embedded browser-based, Microsoft Account required |
| 24H2    | Copilot promoted to standalone installable app from Microsoft Store; sidebar removed |
| 24H2+   | Copilot app can be uninstalled like any Store app; not present in LTSC 2024 |

---

## 5. Security Improvements

### VBS and HVCI Default-On

On **new installs** of Windows 11 (not upgrades from Windows 10), VBS and HVCI are enabled by default on supported hardware. This is the primary security differentiator from Windows 10.

```powershell
# Check VBS and HVCI status
$dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard
[PSCustomObject]@{
    VBSStatus              = switch ($dg.VirtualizationBasedSecurityStatus) {
                                 0 { 'Disabled' }; 1 { 'Enabled, not running' }; 2 { 'Running' }
                             }
    HVCIRunning            = ($dg.SecurityServicesRunning -band 2) -ne 0
    CredentialGuardRunning = ($dg.SecurityServicesRunning -band 1) -ne 0
    SecureBootState        = (Confirm-SecureBootUEFI) ? 'Enabled' : 'Disabled'
}
```

### Smart App Control

Smart App Control (SAC) is a Windows 11-only feature (not available on Windows 10). It is a cloud-powered app reputation service that blocks untrusted applications before they launch.

**States:** Off, Evaluation (learns from usage), Enforcement (blocks untrusted apps). SAC switches from Evaluation to Enforcement or Off after a learning period. Once set to Off, it cannot be re-enabled without reinstalling Windows.

**Interaction with third-party AV:** SAC is independent of Defender and third-party AV. It operates at the AppID policy layer (below antivirus).

```powershell
# Check Smart App Control state
$sacKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'
$verifiedAndReputablePolicyState = Get-ItemProperty -Path $sacKey `
    -Name 'VerifiedAndReputablePolicyState' -ErrorAction SilentlyContinue
# 0 = Off, 1 = Enforcement, 2 = Evaluation
$verifiedAndReputablePolicyState.VerifiedAndReputablePolicyState
```

### Enhanced Phishing Protection

Built into Windows Security (SmartScreen extension). Warns users when they type passwords into:
- Non-HTTPS websites
- Notepad, WordPad (password reuse in plaintext)
- Microsoft 365 apps if password matches Windows sign-in credentials

Configured via Windows Security → App & browser control → Reputation-based protection → Phishing protection.

```powershell
# Check Enhanced Phishing Protection state via registry
$phishKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WTDS\Components' `
    -ErrorAction SilentlyContinue | Select-Object ServiceEnabled, NotifyMalicious, NotifyPasswordReuse, NotifyUnsafeApp
```

### Passkeys (Windows Hello)

Native passkey support added in 23H2. Windows Hello (PIN, fingerprint, face) acts as the FIDO2 authenticator for passkey ceremonies. Passkeys are stored in the Windows Hello credential container, protected by the TPM.

- WebAuthn API in browsers (Chrome, Edge, Firefox) uses the Windows Hello platform authenticator
- Passkeys sync via Microsoft Account on consumer devices (enterprise: no sync by default)
- Manage passkeys: Settings → Accounts → Passkeys

### Personal Data Encryption (Enterprise)

Encrypts known folders (Desktop, Documents, Pictures) using DPAPI-NG keys bound to Windows Hello sign-in. Files are inaccessible when the user is not signed in (even to admin accounts). Requires Azure AD join and Windows 11 Enterprise.

### Config Lock

Prevents configuration drift on MDM-managed devices. When a managed setting is changed locally (by a local admin or user), Config Lock detects the change and reverts it automatically within seconds. Uses the MDM bridge WMI provider to enforce this.

### Microsoft Pluton

Microsoft Pluton is a security processor design integrated into the CPU die (not a discrete TPM chip). Available on Qualcomm Snapdragon X, AMD Ryzen 6000+, and select Intel 12th gen+ platforms. Pluton acts as the TPM 2.0 when present, eliminating the CPU-to-TPM bus that is vulnerable to physical interception attacks (LPC bus sniffing).

### LAPS (Local Administrator Password Solution) — Built-in

Windows LAPS is natively built into Windows 11 22H2+ (April 2023 cumulative update). Replaces the separate LAPS MSI agent. Supports Azure AD, Hybrid AAD, and on-premises Active Directory as backup targets. Adds support for storing LAPS history (multiple previous passwords), passphrase generation mode, and post-authentication action (account disable or password rotation after use).

```powershell
# Check Windows LAPS status (built-in, no MSI required on Windows 11 22H2+)
Get-LapsAADPassword -DeviceId (Get-AzureADDevice -Filter "displayName eq '$env:COMPUTERNAME'").ObjectId

# Check LAPS policy configuration
Get-LapsClientConfiguration

# Invoke immediate password rotation
Invoke-LapsPolicyProcessing
Reset-LapsPassword
```

---

## 6. Enterprise Features

### Hotpatch (24H2+ Enterprise via Azure Arc)

Hotpatch allows installing monthly security updates **without rebooting** for the majority of months. Based on the same technology as Windows Server Azure Edition hotpatch. Released for Windows 11 Enterprise 24H2 enrolled in Azure Arc.

**Hotpatch cycle:** Quarterly baseline updates (require reboot, full cumulative update), hotpatch months (security-only, no reboot, ~8-10 months per year). Not all months qualify for hotpatch — some updates require kernel changes that cannot be live-patched.

**Requirements:**
- Windows 11 Enterprise 24H2 or later
- Azure Arc enrollment (`azcmagent connect`)
- Windows Autopatch or Microsoft Intune assigned hotpatch policy
- Machine joined to Azure AD or Hybrid AAD

### Windows Autopatch

Managed service for automating Windows Update rings (Quality, Feature, Driver updates). Autopatch manages update rings automatically, monitors for update failures, and can pause rings if error rates spike. Requires Windows 11 Enterprise + Microsoft Intune.

### Cloud PC / Windows 365

Windows 365 delivers a full Windows 11 desktop as a Cloud PC, streamed via Remote Desktop or browser. The Cloud PC runs Windows 11 Enterprise in Azure. Windows 365 Boot (24H2+) allows a physical device to boot directly into its Cloud PC — the physical device acts as a thin client.

### Declared Configuration (MDM Protocol)

New MDM protocol introduced in Windows 11. Unlike traditional MDM (which uses OMA-DM command/response), Declared Configuration sends the entire desired state to the device, and the client enforces it locally. Benefits: faster convergence, offline enforcement, reduced MDM server round-trips. Supported in Intune with the `declarativeDeviceManagementConfiguration` CSP.

---

## 7. Feature Update Progression

### 22H2 (October 2022) — Baseline improvements post-launch
- Windows LAPS built-in integration
- Suggested Actions (phone number/date detection in clipboard)
- File Explorer tabs
- Task Manager redesign (new sidebar nav, efficiency mode)
- Microsoft Defender for Endpoint onboarding improvements

### 23H2 (October 2023)
- **Copilot sidebar** (Win+C) — first Copilot integration, browser-based
- **Passkeys** — native FIDO2 passkey management in Windows Hello
- **Dev Home** — developer dashboard app (GitHub integration, machine configuration)
- **Dynamic Lighting** — unified RGB lighting control across USB/HID devices (no third-party software needed)
- **Dev Drive** — ReFS performance volume for developers
- **Windows Backup app** — simplified backup/restore UI
- **File Explorer** — Gallery view, home page redesign, address bar improvements

### 24H2 (October 2024) — Copilot+ PC foundation
- **Copilot+ PC feature set** — Recall, Studio Effects, Cocreator, Live Captions (real-time translation)
- **Hotpatch** — Enterprise no-reboot security updates via Azure Arc
- **Sudo for Windows** — `sudo` command for elevated commands without a new window
- **Wi-Fi 7** — 802.11be support (requires Wi-Fi 7 adapter)
- **Bluetooth LE Audio** — LC3 codec, hearing aid support, Auracast broadcast
- **Energy Saver** — unified power saving mode replacing battery saver + power mode
- **LTSC 2024 baseline** — 24H2 is the LTSC 2024 code base
- **Windows Subsystem for Android** — removed (deprecated March 2024, removed from Store March 2025)
- **Application Guard** — removed (MDAG for Office and Edge)
- **Copilot app model change** — sidebar replaced with installable Store app

### 25H2 (September 2025)
- Incremental security and AI feature refinements on Copilot+ platform
- Further NPU-accelerated features across inbox apps
- Expanded hotpatch eligibility to additional Enterprise SKUs
- Windows Hello improvements (passkey UI refinements, cross-device flows)
- Additional Declared Configuration CSPs for Intune management

### 26H1 (February 2026) — New-device scoped initial rollout
- Available initially only on new devices purchased with 26H1 pre-installed
- Existing device rollout follows standard servicing cadence (typically 4-6 months post-NSD release)
- Enhanced Copilot+ agentic features — multi-step task orchestration in Copilot app
- ARM64 application compatibility improvements (x64 emulation performance gains)
- Refinements to Energy Saver and thermal management for AI workloads

---

## 8. LTSC 2024

### Overview

Windows 11 LTSC 2024 is based on the **24H2 code base** (build 10.0.26100). It follows the Long Term Servicing Channel model: feature set is frozen at release, only cumulative security and reliability updates are delivered.

**Support lifecycle:**
- **Mainstream support:** October 2024 — October 2029 (5 years)
- **Extended support:** October 2029 — October 2034 (10 years total)

### What Is Included vs Excluded

| Feature            | LTSC 2024  | Standard 24H2 |
|--------------------|------------|---------------|
| Microsoft Store    | No         | Yes           |
| Copilot app        | No         | Yes           |
| Widgets            | No         | Yes           |
| Dev Home           | No         | Yes           |
| Windows Backup     | No         | Yes           |
| Feature updates    | No         | Yes (annual)  |
| Security updates   | Yes        | Yes           |
| WSL (manual)       | Yes        | Yes           |
| Copilot+ features  | Yes (HW)   | Yes (HW)      |

### Target Use Cases

- Medical devices, industrial control systems, point-of-sale, ATMs, kiosks — scenarios requiring a stable, unchanging OS environment
- Regulated environments (FDA, FAA, DoD) where any software change requires re-certification
- Air-gapped networks where Store and Copilot connectivity is not desirable

### Licensing

Available through Volume Licensing only. Not available for retail or OEM purchase. Requires Software Assurance or subscription (Windows 11 Enterprise E3/E5, Microsoft 365).

---

## 9. Removed Features (vs Windows 10)

| Feature                          | Status                   | Notes |
|----------------------------------|--------------------------|-------|
| Internet Explorer                | Fully removed in 23H2    | IE mode in Edge remains supported |
| Windows Subsystem for Android    | Removed March 2025       | Deprecated with 24H2; Store listing removed March 5, 2025 |
| Cortana app                      | Removed in 23H2          | Cortana in Teams/Microsoft 365 unaffected |
| Windows Timeline                 | Removed at Windows 11 launch | Activity history still exists but Timeline UI gone |
| Windows To Go                    | Not supported            | Was deprecated in 2019; no Windows 11 support |
| S Mode                           | Evolved                  | Windows 11 S Mode exists but limited device availability |
| Application Guard (MDAG)         | Removed in 24H2          | Office and Edge MDAG removed; Defender Application Control continues |
| WordPad                          | Removed in 23H2          | Microsoft recommends Word or Notepad |
| Steps Recorder                   | Removed in 24H2          | Replaced by Snipping Tool recording feature |
| VBScript                         | Disabled by default 24H2 | Scheduled for full removal in future release |
| Control Panel (legacy applets)   | Progressive removal      | Settings app replacement ongoing; not all applets removed yet |

---

## 10. PowerShell Scripts

### Script 09 — Hardware Compatibility Check

```powershell
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 11 hardware compatibility assessment.
.DESCRIPTION
    Checks TPM 2.0, Secure Boot, CPU approval, UEFI firmware, RAM, storage,
    DirectX/WDDM, and VM environment detection.
.VERSION
    11.1.0
.TARGETS
    Windows 11
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$results = [ordered]@{}

Write-Host "`n=== Windows 11 Hardware Compatibility Check ===" -ForegroundColor Cyan

# --- TPM Check ---
Write-Host "`n[TPM]" -ForegroundColor Yellow
try {
    $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' `
        -ClassName 'Win32_Tpm' -ErrorAction Stop
    $specVersion = $tpm.SpecVersion
    $tpmMajor    = [int]($specVersion -split ',')[0].Trim()

    $results['TPM_Present']  = $true
    $results['TPM_Version']  = $specVersion
    $results['TPM_Ready']    = $tpm.IsEnabled_InitialValue -and $tpm.IsActivated_InitialValue
    $results['TPM_2_0']      = $tpmMajor -ge 2

    Write-Host "  Version     : $specVersion"
    Write-Host "  Enabled     : $($tpm.IsEnabled_InitialValue)"
    Write-Host "  Activated   : $($tpm.IsActivated_InitialValue)"
    Write-Host "  TPM 2.0     : $($results['TPM_2_0'])" -ForegroundColor $(if ($results['TPM_2_0']) { 'Green' } else { 'Red' })
} catch {
    $results['TPM_Present'] = $false
    $results['TPM_2_0']     = $false
    Write-Host "  TPM not found or inaccessible" -ForegroundColor Red
}

# --- Secure Boot ---
Write-Host "`n[Secure Boot]" -ForegroundColor Yellow
try {
    $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
    $results['SecureBoot'] = $secureBoot
    Write-Host "  Secure Boot : $secureBoot" -ForegroundColor $(if ($secureBoot) { 'Green' } else { 'Red' })
} catch {
    $results['SecureBoot'] = $false
    Write-Host "  Secure Boot check failed (may be legacy BIOS or not UEFI)" -ForegroundColor Red
}

# --- UEFI Firmware ---
Write-Host "`n[Firmware / UEFI]" -ForegroundColor Yellow
$firmware = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty PCSystemType
$bcdFirmware = (bcdedit /enum firmware 2>&1) -join ' '
$isUEFI = $bcdFirmware -notmatch 'not supported' -and $bcdFirmware -notmatch 'The requested system device cannot be found'
$results['UEFI'] = $isUEFI
Write-Host "  UEFI Firmware: $isUEFI" -ForegroundColor $(if ($isUEFI) { 'Green' } else { 'Red' })

# --- CPU ---
Write-Host "`n[CPU]" -ForegroundColor Yellow
$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$cpuName    = $cpu.Name
$cpuCores   = $cpu.NumberOfCores
$cpuSpeed   = [math]::Round($cpu.MaxClockSpeed / 1000, 2)

Write-Host "  Model       : $cpuName"
Write-Host "  Cores       : $cpuCores"
Write-Host "  Speed       : $($cpuSpeed) GHz"
$results['CPU_Model'] = $cpuName

# Detect CPU generation/family for approval heuristic
$cpuApproved = $false
if ($cpuName -match 'Intel') {
    # 8th gen Core = i[3579]-8xxx; 10th gen Celeron/Pentium = G6xxx/J6xxx
    if ($cpuName -match 'Core.*(i[3579]|i\d)-([89]\d{3}|[12]\d{4})') { $cpuApproved = $true }
    if ($cpuName -match 'Core.*(Ultra|i[3579])-\d+') { $cpuApproved = $true }
    if ($cpuName -match 'Xeon') { $cpuApproved = $true }  # Most Xeon W-2xxx/3xxx
} elseif ($cpuName -match 'AMD') {
    # Ryzen 3000+ = Zen2+; Ryzen 5000/7000/9000 all approved
    if ($cpuName -match 'Ryzen [3579] [3-9]\d{3}') { $cpuApproved = $true }
    if ($cpuName -match 'Ryzen (Threadripper|AI)') { $cpuApproved = $true }
    if ($cpuName -match 'EPYC') { $cpuApproved = $true }
} elseif ($cpuName -match 'Snapdragon') {
    if ($cpuName -match 'Snapdragon (7c|8c|8cx|X)') { $cpuApproved = $true }
}

$results['CPU_Approved'] = $cpuApproved
Write-Host "  Approved CPU : $cpuApproved" -ForegroundColor $(if ($cpuApproved) { 'Green' } else { 'Yellow' })
if (-not $cpuApproved) {
    Write-Host "  NOTE: CPU approval heuristic; verify against Microsoft's official CPU list" -ForegroundColor Yellow
}

# --- RAM ---
Write-Host "`n[RAM]" -ForegroundColor Yellow
$ramBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
$ramGB    = [math]::Round($ramBytes / 1GB, 2)
$results['RAM_GB']     = $ramGB
$results['RAM_OK']     = $ramGB -ge 4
Write-Host "  Total RAM   : $ramGB GB" -ForegroundColor $(if ($results['RAM_OK']) { 'Green' } else { 'Red' })

# --- Storage ---
Write-Host "`n[Storage]" -ForegroundColor Yellow
$systemDrive  = $env:SystemDrive.TrimEnd(':')
$disk         = Get-PSDrive -Name $systemDrive | Select-Object Used, Free
$totalGB      = [math]::Round(($disk.Used + $disk.Free) / 1GB, 2)
$results['Storage_GB'] = $totalGB
$results['Storage_OK'] = $totalGB -ge 64
Write-Host "  System Drive : $($totalGB) GB total" -ForegroundColor $(if ($results['Storage_OK']) { 'Green' } else { 'Red' })

# --- DirectX and WDDM ---
Write-Host "`n[DirectX / WDDM]" -ForegroundColor Yellow
$gpus = Get-CimInstance -ClassName Win32_VideoController
foreach ($gpu in $gpus) {
    Write-Host "  GPU         : $($gpu.Name)"
    Write-Host "  Driver Ver  : $($gpu.DriverVersion)"
    # WDDM version embedded in driver date/version; check registry for accurate WDDM version
}

$wddmKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
$wddmVer = Get-ItemProperty -Path $wddmKey -ErrorAction SilentlyContinue
if ($wddmVer) {
    Write-Host "  WDDM Config key found"
}

# DirectX 12 support — check via DXGI capabilities (approximated via GPU driver)
$dx12Capable = $gpus | Where-Object { $_.DriverVersion -and [version]$_.DriverVersion -ge [version]'10.0' }
$results['DX12_Likely'] = ($dx12Capable.Count -gt 0)
Write-Host "  DX12 Capable : $($results['DX12_Likely'])" -ForegroundColor $(if ($results['DX12_Likely']) { 'Green' } else { 'Yellow' })

# --- VM Detection ---
Write-Host "`n[VM Detection]" -ForegroundColor Yellow
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
$isVM = $computerSystem.Model -match 'Virtual|VMware|VirtualBox|KVM|Hyper-V|QEMU' -or
        $computerSystem.Manufacturer -match 'VMware|Xen|innotek|QEMU|Microsoft Corporation' -and
        $computerSystem.Model -match 'Virtual Machine'
$results['Is_VM'] = $isVM
Write-Host "  Is VM        : $isVM"
if ($isVM) {
    Write-Host "  Model        : $($computerSystem.Model)"
    Write-Host "  Manufacturer : $($computerSystem.Manufacturer)"

    # Check for Hyper-V Gen2 (UEFI) if in Hyper-V
    if ($computerSystem.Model -match 'Virtual Machine' -and $computerSystem.Manufacturer -match 'Microsoft') {
        Write-Host "  Hyper-V VM   : Check vTPM and Secure Boot are enabled on the VM object (host-side)" -ForegroundColor Cyan
    }
}

# --- Summary ---
Write-Host "`n=== Compatibility Summary ===" -ForegroundColor Cyan
$checks = @{
    'TPM 2.0'       = $results['TPM_2_0']
    'Secure Boot'   = $results['SecureBoot']
    'UEFI Firmware' = $results['UEFI']
    'CPU Approved'  = $results['CPU_Approved']
    'RAM >= 4 GB'   = $results['RAM_OK']
    'Storage >= 64 GB' = $results['Storage_OK']
    'DX12 / WDDM'  = $results['DX12_Likely']
}

$allPass = $true
foreach ($check in $checks.GetEnumerator()) {
    $status = if ($check.Value) { 'PASS' } else { 'FAIL'; $allPass = $false }
    $color  = if ($check.Value) { 'Green' } else { 'Red' }
    Write-Host "  $($check.Key.PadRight(20)) : $status" -ForegroundColor $color
}

Write-Host ""
if ($allPass) {
    Write-Host "  Overall: COMPATIBLE with Windows 11" -ForegroundColor Green
} else {
    Write-Host "  Overall: NOT COMPATIBLE — review failed checks" -ForegroundColor Red
}

return $results
```

---

### Script 10 — Dev Drive Health and Status

```powershell
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 11 Dev Drive health and configuration report.
.DESCRIPTION
    Enumerates Dev Drive (ReFS) volumes, checks performance mode status,
    Defender integration, and space utilization.
.VERSION
    11.1.0
.TARGETS
    Windows 11
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

Write-Host "`n=== Dev Drive Health and Status ===" -ForegroundColor Cyan

# --- OS Version Check ---
$build = [System.Environment]::OSVersion.Version.Build
if ($build -lt 22621) {
    Write-Warning "Dev Drive requires Windows 11 22H2 (build 22621) or later. Current build: $build"
}

# --- Enumerate ReFS Volumes ---
Write-Host "`n[ReFS Volumes (Dev Drive Candidates)]" -ForegroundColor Yellow
$refsVolumes = Get-Volume | Where-Object { $_.FileSystem -eq 'ReFS' }

if (-not $refsVolumes) {
    Write-Host "  No ReFS volumes found. No Dev Drives configured." -ForegroundColor Yellow
} else {
    foreach ($vol in $refsVolumes) {
        $usedGB  = [math]::Round(($vol.Size - $vol.SizeRemaining) / 1GB, 2)
        $totalGB = [math]::Round($vol.Size / 1GB, 2)
        $freeGB  = [math]::Round($vol.SizeRemaining / 1GB, 2)
        $usePct  = if ($vol.Size -gt 0) { [math]::Round((($vol.Size - $vol.SizeRemaining) / $vol.Size) * 100, 1) } else { 0 }

        Write-Host ""
        Write-Host "  Drive Letter : $($vol.DriveLetter):"
        Write-Host "  Label        : $($vol.FileSystemLabel)"
        Write-Host "  FileSystem   : $($vol.FileSystem)"
        Write-Host "  Health       : $($vol.HealthStatus)"
        Write-Host "  Total        : $totalGB GB"
        Write-Host "  Used         : $usedGB GB ($usePct%)"
        Write-Host "  Free         : $freeGB GB"
        Write-Host "  Operational  : $($vol.OperationalStatus)"

        # Warn if below recommended minimum
        if ($totalGB -lt 50) {
            Write-Host "  WARNING: Volume is below recommended 50 GB minimum for Dev Drive" -ForegroundColor Yellow
        }

        # Check if this volume is assigned to a disk (not a VHD)
        if ($vol.DriveLetter) {
            $partition = Get-Partition -DriveLetter $vol.DriveLetter -ErrorAction SilentlyContinue
            if ($partition) {
                $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction SilentlyContinue
                if ($disk) {
                    Write-Host "  Disk         : Disk $($disk.Number) — $($disk.FriendlyName) ($($disk.BusType))"
                    Write-Host "  Disk Health  : $($disk.HealthStatus)"
                }
            }
        }
    }
}

# --- Defender Performance Mode ---
Write-Host "`n[Defender Performance Mode]" -ForegroundColor Yellow
try {
    $mpPref = Get-MpPreference -ErrorAction Stop
    $perfMode = $mpPref.PerformanceModeStatus
    Write-Host "  Performance Mode Status : $perfMode"

    # 0 = Disabled, 1 = Enabled (Dev Drive performance mode active)
    if ($perfMode -eq 1) {
        Write-Host "  Dev Drive async scanning : Enabled" -ForegroundColor Green
    } elseif ($perfMode -eq 0) {
        Write-Host "  Dev Drive async scanning : Disabled" -ForegroundColor Yellow
        Write-Host "  NOTE: May be disabled due to third-party AV or policy" -ForegroundColor Yellow
    } else {
        Write-Host "  Status unknown: $perfMode" -ForegroundColor Yellow
    }

    # Check if any third-party AV is registered (would disable Defender performance mode)
    $avProducts = Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName 'AntiVirusProduct' -ErrorAction SilentlyContinue
    if ($avProducts) {
        foreach ($av in $avProducts) {
            $isDefender = $av.displayName -match 'Windows Defender|Microsoft Defender'
            Write-Host "  AV Product   : $($av.displayName)" -ForegroundColor $(if ($isDefender) { 'White' } else { 'Yellow' })
            if (-not $isDefender) {
                Write-Host "  NOTE: Third-party AV detected. Dev Drive performance mode requires AV to declare Dev Drive support." -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "  Unable to query Defender preferences: $_" -ForegroundColor Red
}

# --- Dev Drive Policy Check ---
Write-Host "`n[Dev Drive Policy]" -ForegroundColor Yellow
$devDrivePolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DevDrive'
if (Test-Path $devDrivePolicyKey) {
    $policy = Get-ItemProperty -Path $devDrivePolicyKey -ErrorAction SilentlyContinue
    Write-Host "  Policy key found:"
    $policy | Select-Object -ExcludeProperty PSPath, PSParentPath, PSChildName, PSDrive, PSProvider | Format-List
} else {
    Write-Host "  No Dev Drive policy configured (using defaults)" -ForegroundColor Green
}

# --- ReFS Integrity Check ---
Write-Host "`n[ReFS Volume Integrity]" -ForegroundColor Yellow
foreach ($vol in $refsVolumes) {
    if ($vol.DriveLetter) {
        Write-Host "  Checking $($vol.DriveLetter): ..." -NoNewline
        $repair = Repair-Volume -DriveLetter $vol.DriveLetter -Scan -ErrorAction SilentlyContinue 2>&1
        if ($repair -match 'No further action') {
            Write-Host " Clean" -ForegroundColor Green
        } elseif ($repair) {
            Write-Host " $repair" -ForegroundColor Yellow
        } else {
            Write-Host " Scan complete (check Event Log for details)"
        }
    }
}

# --- Package Manager Cache Locations ---
Write-Host "`n[Common Dev Workload Cache Locations on Dev Drives]" -ForegroundColor Yellow
$devDriveLetters = $refsVolumes | Where-Object DriveLetter | Select-Object -ExpandProperty DriveLetter

foreach ($letter in $devDriveLetters) {
    $npmCache   = "$($letter):\npm-cache"
    $pipCache   = "$($letter):\pip-cache"
    $nugetCache = "$($letter):\nuget-cache"
    $cargoCache = "$($letter):\cargo"

    Write-Host "  $($letter): — npm cache   : $(if (Test-Path $npmCache) { 'Configured' } else { 'Not configured' })"
    Write-Host "  $($letter): — pip cache   : $(if (Test-Path $pipCache) { 'Configured' } else { 'Not configured' })"
    Write-Host "  $($letter): — NuGet cache : $(if (Test-Path $nugetCache) { 'Configured' } else { 'Not configured' })"
    Write-Host "  $($letter): — Cargo home  : $(if (Test-Path $cargoCache) { 'Configured' } else { 'Not configured' })"
}

Write-Host "`n=== Dev Drive Check Complete ===" -ForegroundColor Cyan
```

---

### Script 11 — Copilot+ Feature Readiness

```powershell
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Copilot+ PC feature readiness assessment for Windows 11.
.DESCRIPTION
    Detects NPU presence, checks Copilot+ hardware eligibility,
    Windows Studio Effects availability, and Recall eligibility.
.VERSION
    11.1.0
.TARGETS
    Windows 11
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$results = [ordered]@{}

Write-Host "`n=== Copilot+ PC Feature Readiness ===" -ForegroundColor Cyan

# --- OS Version ---
Write-Host "`n[OS Version]" -ForegroundColor Yellow
$osInfo  = Get-CimInstance -ClassName Win32_OperatingSystem
$osBuild = [System.Environment]::OSVersion.Version.Build
$results['OS_Build']   = $osBuild
$results['OS_Caption'] = $osInfo.Caption

Write-Host "  OS          : $($osInfo.Caption)"
Write-Host "  Build       : $osBuild"

if ($osBuild -lt 26100) {
    Write-Host "  NOTE: Copilot+ features fully available on 24H2 (build 26100+)" -ForegroundColor Yellow
}

# --- RAM Check (16 GB required for Copilot+) ---
Write-Host "`n[RAM — Copilot+ Requirement: 16 GB]" -ForegroundColor Yellow
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$results['RAM_GB']      = $ramGB
$results['RAM_CopilotPlus'] = $ramGB -ge 16
Write-Host "  Total RAM   : $ramGB GB" -ForegroundColor $(if ($results['RAM_CopilotPlus']) { 'Green' } else { 'Red' })

# --- NPU Detection ---
Write-Host "`n[NPU Detection]" -ForegroundColor Yellow

# Method 1: Check for dedicated NPU via PnP device class
$npuDevices = Get-PnpDevice -ErrorAction SilentlyContinue |
    Where-Object { $_.Class -match 'NPU|NeuralProcessor|ComputeAccelerator|AIProcessor' -or
                   $_.FriendlyName -match 'NPU|Neural|Hexagon|AI Boost|AI Engine' }

$results['NPU_Devices'] = @($npuDevices)

if ($npuDevices) {
    Write-Host "  NPU devices found:" -ForegroundColor Green
    foreach ($npu in $npuDevices) {
        Write-Host "    - $($npu.FriendlyName) [$($npu.Status)]"
    }
} else {
    Write-Host "  No dedicated NPU device found via PnP" -ForegroundColor Yellow
}

# Method 2: Check processor name for NPU-capable silicon
$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$cpuName = $cpu.Name
$results['CPU_NPU_Capable'] = $cpuName -match 'Snapdragon X|Ryzen AI|Core Ultra [2-9]00[VH]|Apple'

Write-Host "  CPU Model   : $cpuName"
Write-Host "  CPU NPU-capable hint: $($results['CPU_NPU_Capable'])" -ForegroundColor $(
    if ($results['CPU_NPU_Capable']) { 'Green' } else { 'Yellow' }
)

# Method 3: Check Windows AI Platform registry keys (present on Copilot+ configured devices)
$aiPlatformKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI'
$results['AI_Platform_Present'] = Test-Path $aiPlatformKey

if ($results['AI_Platform_Present']) {
    Write-Host "  Windows AI Platform key: Present" -ForegroundColor Green
    $aiProps = Get-ItemProperty -Path $aiPlatformKey -ErrorAction SilentlyContinue
    if ($aiProps) {
        $aiProps | Select-Object -ExcludeProperty PSPath, PSParentPath, PSChildName, PSDrive, PSProvider |
            Format-List | Out-String | ForEach-Object { Write-Host "    $_" }
    }
} else {
    Write-Host "  Windows AI Platform key: Not present" -ForegroundColor Yellow
}

# --- Copilot+ Eligibility ---
Write-Host "`n[Copilot+ Eligibility Assessment]" -ForegroundColor Yellow
$copilotPlusEligible = $results['CPU_NPU_Capable'] -or $results['NPU_Devices'].Count -gt 0
$copilotPlusEligible = $copilotPlusEligible -and $results['RAM_CopilotPlus']
$results['CopilotPlus_Eligible'] = $copilotPlusEligible

Write-Host "  Copilot+ Eligible: $copilotPlusEligible" -ForegroundColor $(
    if ($copilotPlusEligible) { 'Green' } else { 'Yellow' }
)
if (-not $copilotPlusEligible) {
    Write-Host "  NOTE: Copilot+ requires 40+ TOPS NPU and 16 GB RAM. This is a heuristic check." -ForegroundColor Yellow
    Write-Host "        Use PC Health Check app or Microsoft's Copilot+ PC checker for official validation." -ForegroundColor Yellow
}

# --- Windows Studio Effects ---
Write-Host "`n[Windows Studio Effects]" -ForegroundColor Yellow
$studioEffectsKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\VideoEffects'
$studioEffectsPresent = Test-Path $studioEffectsKey
$results['StudioEffects_Present'] = $studioEffectsPresent

# Check for camera with Studio Effects DMFT
$cameras = Get-PnpDevice -Class Camera -ErrorAction SilentlyContinue
if ($cameras) {
    Write-Host "  Camera devices:"
    foreach ($cam in $cameras) {
        Write-Host "    - $($cam.FriendlyName) [$($cam.Status)]"
    }
}

# Check if Studio Effects feature is enabled (surfaced in Settings)
$wseKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\VideoEffects'
if (Test-Path $wseKey) {
    Write-Host "  Studio Effects user settings key: Present" -ForegroundColor Green
    Get-ItemProperty -Path $wseKey -ErrorAction SilentlyContinue |
        Select-Object -ExcludeProperty PSPath, PSParentPath, PSChildName, PSDrive, PSProvider |
        Format-List | Out-String | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "  Studio Effects user settings key: Not present" -ForegroundColor Yellow
}

# --- Windows Recall ---
Write-Host "`n[Windows Recall]" -ForegroundColor Yellow

# Check if Recall service is present
$recallService = Get-Service -Name 'CoreAIPlatform' -ErrorAction SilentlyContinue
$results['Recall_Service_Present'] = $null -ne $recallService

if ($recallService) {
    Write-Host "  Recall service (CoreAIPlatform): $($recallService.Status)" -ForegroundColor Green
} else {
    Write-Host "  Recall service (CoreAIPlatform): Not found" -ForegroundColor Yellow
    Write-Host "  NOTE: Recall requires Copilot+ PC hardware" -ForegroundColor Yellow
}

# Check if Recall is enabled or disabled via policy
$recallPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
if (Test-Path $recallPolicyKey) {
    $recallPolicy = Get-ItemProperty -Path $recallPolicyKey -ErrorAction SilentlyContinue
    $disabledByPolicy = $recallPolicy.DisableAIDataAnalysis -eq 1
    $results['Recall_Disabled_Policy'] = $disabledByPolicy
    Write-Host "  Recall policy: $(if ($disabledByPolicy) { 'DISABLED by policy' } else { 'Not disabled by policy' })" -ForegroundColor $(
        if ($disabledByPolicy) { 'Yellow' } else { 'Green' }
    )
} else {
    Write-Host "  No Recall policy configured"
}

# Check Recall snapshot storage path
$recallPath = "$env:LOCALAPPDATA\CoreAIPlatform.00"
if (Test-Path $recallPath) {
    Write-Host "  Recall snapshot path: Exists ($recallPath)" -ForegroundColor Green
    $size = (Get-ChildItem -Path $recallPath -Recurse -ErrorAction SilentlyContinue |
             Measure-Object -Property Length -Sum).Sum
    Write-Host "  Snapshot storage used: $([math]::Round($size / 1MB, 2)) MB"
} else {
    Write-Host "  Recall snapshot path: Not found"
}

# --- Summary ---
Write-Host "`n=== Copilot+ Summary ===" -ForegroundColor Cyan
$summary = @{
    'Copilot+ Eligible'     = $results['CopilotPlus_Eligible']
    'NPU Found'             = $results['NPU_Devices'].Count -gt 0 -or $results['CPU_NPU_Capable']
    'RAM 16 GB+'            = $results['RAM_CopilotPlus']
    'Recall Service'        = $results['Recall_Service_Present']
    'AI Platform Present'   = $results['AI_Platform_Present']
}

foreach ($item in $summary.GetEnumerator()) {
    $color = if ($item.Value) { 'Green' } else { 'Yellow' }
    Write-Host "  $($item.Key.PadRight(22)) : $($item.Value)" -ForegroundColor $color
}

return $results
```

---

### Script 12 — Hotpatch Status

```powershell
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 11 Enterprise hotpatch enrollment and compliance status.
.DESCRIPTION
    Checks Azure Arc enrollment, hotpatch policy assignment, baseline vs
    hotpatch update history, and compliance state for Enterprise 24H2+ devices.
.VERSION
    11.1.0
.TARGETS
    Windows 11
#>

[CmdletBinding()]
param(
    [switch]$IncludeUpdateHistory
)

$ErrorActionPreference = 'Continue'
$results = [ordered]@{}

Write-Host "`n=== Windows 11 Hotpatch Status ===" -ForegroundColor Cyan

# --- OS and Edition Check ---
Write-Host "`n[OS Version and Edition]" -ForegroundColor Yellow
$os    = Get-CimInstance -ClassName Win32_OperatingSystem
$build = [System.Environment]::OSVersion.Version.Build
$sku   = $os.OperatingSystemSKU  # 4 = Enterprise, 48 = Enterprise Eval, etc.

$results['OS_Caption'] = $os.Caption
$results['OS_Build']   = $build
$results['OS_SKU']     = $sku

Write-Host "  OS Caption  : $($os.Caption)"
Write-Host "  Build       : $build"
Write-Host "  SKU         : $sku"

# Hotpatch requires Windows 11 Enterprise 24H2 (build 26100+)
$hotpatchOSEligible = $build -ge 26100 -and $sku -in @(4, 27, 125)
$results['OS_Hotpatch_Eligible'] = $hotpatchOSEligible
Write-Host "  OS eligible for hotpatch: $hotpatchOSEligible" -ForegroundColor $(
    if ($hotpatchOSEligible) { 'Green' } else { 'Red' }
)

if (-not $hotpatchOSEligible) {
    if ($build -lt 26100) {
        Write-Host "  Hotpatch requires Windows 11 24H2 (build 26100+). Current: $build" -ForegroundColor Red
    }
    if ($sku -notin @(4, 27, 125)) {
        Write-Host "  Hotpatch requires Windows 11 Enterprise edition (SKU 4/27/125). Current SKU: $sku" -ForegroundColor Red
    }
}

# --- Azure Arc Enrollment ---
Write-Host "`n[Azure Arc Enrollment]" -ForegroundColor Yellow

$arcService = Get-Service -Name 'himds' -ErrorAction SilentlyContinue  # Azure Arc agent service
$results['AzureArc_Service_Present'] = $null -ne $arcService

if ($arcService) {
    Write-Host "  Azure Arc agent (himds): $($arcService.Status)" -ForegroundColor $(
        if ($arcService.Status -eq 'Running') { 'Green' } else { 'Red' }
    )
    $results['AzureArc_Running'] = $arcService.Status -eq 'Running'
} else {
    Write-Host "  Azure Arc agent: NOT INSTALLED" -ForegroundColor Red
    Write-Host "  Hotpatch requires Azure Arc enrollment." -ForegroundColor Yellow
    Write-Host "  Install: https://aka.ms/AzureConnectedMachineAgent" -ForegroundColor Yellow
    $results['AzureArc_Running'] = $false
}

# Check Azure Arc configuration
$arcConfigPath = "$env:ProgramData\AzureConnectedMachineAgent\Config"
if (Test-Path $arcConfigPath) {
    Write-Host "  Arc config path: $arcConfigPath"
    $arcConfig = Get-ChildItem -Path $arcConfigPath -Filter '*.json' -ErrorAction SilentlyContinue
    foreach ($cfg in $arcConfig) {
        Write-Host "    Config file: $($cfg.Name) ($(($cfg.LastWriteTime).ToString('yyyy-MM-dd')))"
    }
}

# --- Hotpatch Policy (MDM/Intune) ---
Write-Host "`n[Hotpatch Policy (MDM/Intune)]" -ForegroundColor Yellow
$hotpatchPolicyKey = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update'
if (Test-Path $hotpatchPolicyKey) {
    $policy = Get-ItemProperty -Path $hotpatchPolicyKey -ErrorAction SilentlyContinue
    Write-Host "  MDM Update policy key: Present"

    # HotPatchEnabled: 1 = hotpatch enabled
    $hotpatchEnabled = $policy.HotPatchEnabled
    $results['Hotpatch_Policy_Enabled'] = $hotpatchEnabled -eq 1
    Write-Host "  HotPatchEnabled: $hotpatchEnabled" -ForegroundColor $(
        if ($hotpatchEnabled -eq 1) { 'Green' } else { 'Yellow' }
    )
} else {
    Write-Host "  No MDM Update policy key found" -ForegroundColor Yellow
    $results['Hotpatch_Policy_Enabled'] = $false
}

# Check Windows Update for Business (WUfB) hotpatch CSP
$wufbKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
if (Test-Path $wufbKey) {
    $wufb = Get-ItemProperty -Path $wufbKey -ErrorAction SilentlyContinue
    Write-Host "  WUfB policy key present"
    if ($null -ne $wufb.SetHotpatch) {
        Write-Host "  SetHotpatch (WUfB): $($wufb.SetHotpatch)" -ForegroundColor $(
            if ($wufb.SetHotpatch -eq 1) { 'Green' } else { 'Yellow' }
        )
        $results['WUfB_Hotpatch_Set'] = $wufb.SetHotpatch -eq 1
    }
}

# --- Current Hotpatch State ---
Write-Host "`n[Current Hotpatch State]" -ForegroundColor Yellow

# Query Windows Update orchestrator for hotpatch status
$hotpatchStateKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\HotPatch'
if (Test-Path $hotpatchStateKey) {
    $hotpatchState = Get-ItemProperty -Path $hotpatchStateKey -ErrorAction SilentlyContinue
    Write-Host "  Hotpatch orchestrator key: Present" -ForegroundColor Green
    $hotpatchState | Select-Object -ExcludeProperty PSPath, PSParentPath, PSChildName, PSDrive, PSProvider |
        Format-List | Out-String | ForEach-Object { Write-Host "  $_" }
    $results['Hotpatch_State'] = $hotpatchState
} else {
    Write-Host "  Hotpatch orchestrator state: Not configured/not enrolled" -ForegroundColor Yellow
}

# --- Update History (Baseline vs Hotpatch) ---
if ($IncludeUpdateHistory) {
    Write-Host "`n[Windows Update History — Baseline vs Hotpatch]" -ForegroundColor Yellow

    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $historyCount   = $updateSearcher.GetTotalHistoryCount()
    $history        = $updateSearcher.QueryHistory(0, [Math]::Min($historyCount, 50))

    $hotpatchUpdates  = @()
    $baselineUpdates  = @()

    foreach ($update in $history) {
        # Hotpatch updates typically have "Hotpatch" in the title or KB notes
        if ($update.Title -match 'Hotpatch' -or $update.Description -match 'Hotpatch') {
            $hotpatchUpdates += $update
        } elseif ($update.Title -match 'Cumulative Update|Quality Update') {
            $baselineUpdates += $update
        }
    }

    Write-Host "  Hotpatch updates in last 50: $($hotpatchUpdates.Count)" -ForegroundColor $(
        if ($hotpatchUpdates.Count -gt 0) { 'Green' } else { 'Yellow' }
    )
    foreach ($u in $hotpatchUpdates | Select-Object -First 5) {
        Write-Host "    [Hotpatch] $($u.Date.ToString('yyyy-MM-dd')) — $($u.Title)"
    }

    Write-Host "  Baseline (reboot) updates in last 50: $($baselineUpdates.Count)"
    foreach ($u in $baselineUpdates | Select-Object -First 5) {
        Write-Host "    [Baseline] $($u.Date.ToString('yyyy-MM-dd')) — $($u.Title)"
    }

    $results['Hotpatch_Count_Last50']  = $hotpatchUpdates.Count
    $results['Baseline_Count_Last50']  = $baselineUpdates.Count
} else {
    Write-Host "`n  TIP: Run with -IncludeUpdateHistory to analyze baseline vs hotpatch update cadence" -ForegroundColor Cyan
}

# --- Compliance Summary ---
Write-Host "`n=== Hotpatch Compliance Summary ===" -ForegroundColor Cyan
$complianceItems = [ordered]@{
    'OS Build 24H2+ (26100+)'   = $results['OS_Hotpatch_Eligible']
    'Azure Arc Agent Running'   = $results['AzureArc_Running']
    'Hotpatch Policy Enabled'   = $results['Hotpatch_Policy_Enabled']
}

$allCompliant = $true
foreach ($item in $complianceItems.GetEnumerator()) {
    $status = if ($item.Value) { 'OK   ' } else { 'ISSUE'; $allCompliant = $false }
    $color  = if ($item.Value) { 'Green' } else { 'Red' }
    Write-Host "  $($item.Key.PadRight(28)) : $status" -ForegroundColor $color
}

Write-Host ""
if ($allCompliant) {
    Write-Host "  Hotpatch: FULLY ENROLLED — device should receive hotpatch updates" -ForegroundColor Green
} else {
    Write-Host "  Hotpatch: NOT FULLY ENROLLED — resolve issues above" -ForegroundColor Red
}

return $results
```
