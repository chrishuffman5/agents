# Windows 10 — Version-Specific Research

**Support Status:** Home/Pro 22H2 reached EOL October 14, 2025. Enterprise, Education, and LTSC editions remain supported. Enterprise/Education 22H2 supported until October 14, 2027.
**Final GA Version:** 22H2 (Build 19045). No further feature updates will be released.
**Baseline:** This file covers Windows 10 end-of-life posture — LTSC management, ESU enrollment, and migration to Windows 11.
**Consumed by:** Opus writer agent producing the version-specific agent file

---

## 1. LTSC vs GA Channel

### What LTSC Is

Long-Term Servicing Channel (LTSC) releases are isolated, fixed-feature builds of Windows 10 designed for environments that cannot tolerate feature disruption. LTSC is not a "stripped" version — it ships with all enterprise security and management capabilities — but it excludes consumer-oriented inbox apps and the GA channel's semi-annual feature update cadence.

### What LTSC Excludes (vs GA Channel)

- **Microsoft Store** — Not included by default (can be added as an optional component in LTSC 2021, but Store access is blocked by policy in locked-down deployments)
- **Edge (Chromium)** — Not included in LTSC 2019; included in LTSC 2021
- **Microsoft Teams** — Not preinstalled on LTSC; must be deployed via MSI
- **Cortana** — Present in LTSC 2019 (legacy), removed as a standalone app in LTSC 2021
- **Consumer apps** — No preinstalled Mail, Calendar, Photos, Xbox, Spotify, etc.
- **Feature updates** — LTSC does not receive semi-annual feature updates; the build stays fixed for the servicing lifecycle
- **Windows Subsystem for Android (WSA)** — Not available on LTSC

### LTSC 2019 vs LTSC 2021

| Attribute                    | LTSC 2019 (1809 / Build 17763)         | LTSC 2021 (21H2 / Build 19044)          |
|------------------------------|----------------------------------------|-----------------------------------------|
| Release date                 | November 2018                          | November 2021                           |
| Support lifecycle            | 10 years — ends January 9, 2029        | 5 years — ends January 12, 2027         |
| Microsoft Edge               | Legacy Edge (IE-based)                 | Chromium Edge included                  |
| Chromium Edge inbox          | No — must deploy separately            | Yes                                     |
| DirectX 12 Ultimate          | No                                     | Yes                                     |
| WSL 2                        | Available via update                   | Built-in                                |
| Windows Sandbox              | No (not supported on LTSC 2019)        | Supported                               |
| WPA3 Wi-Fi                   | Limited                                | Full support                            |
| Recommended upgrade path     | LTSC 2021 or Windows 11                | Windows 11 LTSC 2024 when hardware-ready|

### LTSC Servicing Model

LTSC receives **security updates only** — no feature updates, no reliability-only updates outside the monthly rollup.

- Updates release on **Patch Tuesday** (second Tuesday of each month)
- Update type is **Monthly Security Rollup** (cumulative)
- WSUS, Configuration Manager, Intune, and Windows Update all support LTSC servicing
- LTSC builds are never moved to a new Windows version via Windows Update; in-place upgrades require media or feature update packages delivered out-of-band

### LTSC Use Cases

| Scenario                    | Reason LTSC Is Appropriate                                              |
|-----------------------------|-------------------------------------------------------------------------|
| Medical / healthcare devices | FDA-cleared software cannot change; fixed OS build is a compliance req  |
| Industrial control systems   | Validated configurations for PLCs, SCADA, HMI stations                  |
| Kiosks and ATMs             | Single-purpose devices; no need for Store, Teams, or semi-annual updates |
| Air-gapped environments     | Security classification prevents internet connectivity; no WU access     |
| Point-of-sale terminals     | PCI-DSS controlled environments; change-controlled update cycles         |
| Embedded hardware           | Long hardware lifecycles (10+ years) align with LTSC 2019 support end   |

---

## 2. Extended Security Updates (ESU)

### ESU Program Overview

Microsoft's ESU program extends security update coverage beyond the standard end-of-support date for eligible editions. For Windows 10:
- **Eligible editions:** Enterprise, Education, IoT Enterprise LTSC, Pro (consumer ESU only)
- **Coverage:** Security updates only (Critical and Important rated); no feature or reliability updates
- **Maximum duration:** 3 years (Year 1, Year 2, Year 3 — must be enrolled in sequence)
- **Year 1 start:** October 14, 2025 for Home/Pro; October 14, 2027 for Enterprise/Education

### Pricing

| Year       | Enterprise/Education (per device) | Consumer (Home/Pro)         |
|------------|-----------------------------------|-----------------------------|
| Year 1     | $61                               | $30                         |
| Year 2     | $122 (doubles)                    | Not publicly offered at scale|
| Year 3     | $244 (doubles again)              | Not publicly offered at scale|

Pricing is based on per-device licensing. Volume licensing customers can acquire through EA/CSP.

### ESU Enrollment Methods

**Method 1 — Intune (Microsoft Entra ID-joined devices)**
```powershell
# ESU enrollment via Intune is configured through a Settings Catalog profile
# Navigate to: Devices > Configuration > Create Policy
# Platform: Windows 10 and later
# Profile type: Settings catalog
# Setting: "Enable Extended Security Updates" under Windows Update for Business
# Value: Enabled

# Verify enrollment status via registry after policy applies
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\WindowsUpdateForBusiness" |
    Select-Object -Property ESUEnabled, ESUActivationStatus
```

**Method 2 — WSUS (on-premises managed)**
```powershell
# ESU requires a MAK (Multiple Activation Key) product key deployed to managed devices
# Deploy ESU MAK key via slmgr or Configuration Manager

# Install ESU MAK key on the device
$esuKey = 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX'  # Replace with actual MAK
& slmgr.vbs /ipk $esuKey

# Activate the key
& slmgr.vbs /ato

# Verify activation
& slmgr.vbs /dlv | Select-String 'License Status'
```

**Method 3 — Azure Arc (hybrid devices)**
```powershell
# Devices enrolled in Azure Arc receive ESU at no additional cost for the first year
# Arc enrollment
$tenantId   = '<your-tenant-id>'
$appId      = '<service-principal-app-id>'
$appSecret  = '<service-principal-secret>'

# Download and install the Arc agent
Invoke-WebRequest -Uri 'https://aka.ms/AzureConnectedMachineAgent' -OutFile "$env:TEMP\AzureConnectedMachineAgent.msi"
msiexec /i "$env:TEMP\AzureConnectedMachineAgent.msi" /qn

# Connect to Azure Arc
& 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' connect `
    --tenant-id    $tenantId `
    --service-principal-id     $appId `
    --service-principal-secret $appSecret `
    --resource-group '<rg-name>' `
    --location '<azure-region>'

# Verify Arc connection
& 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' show
```

### ESU Coverage Scope

ESU covers:
- **Critical** and **Important** CVEs as rated by Microsoft Security Response Center (MSRC)
- Does NOT cover Moderate or Low severity updates
- Does NOT include .NET Framework updates (separate ESU available)
- Does NOT include new features, cumulative non-security improvements, or out-of-band optional updates

---

## 3. Servicing Channels and End-of-Life Posture

### Final GA Release

Windows 10 version **22H2** is the final feature release for the GA channel. Microsoft released it October 18, 2022. All subsequent updates are quality (security/cumulative) updates only.

| Edition                      | Version | EOL Date             |
|------------------------------|---------|----------------------|
| Home, Pro                    | 22H2    | October 14, 2025     |
| Enterprise, Education        | 22H2    | October 14, 2027     |
| Enterprise LTSC 2019         | 1809    | January 9, 2029      |
| Enterprise LTSC 2021         | 21H2    | January 12, 2027     |
| IoT Enterprise LTSC 2021     | 21H2    | January 13, 2032     |

### End of Servicing vs End of Support

- **End of Servicing** — A specific version's update eligibility ends; the device should upgrade to the next supported version within the same OS (e.g., 21H1 end-of-servicing means upgrade to 22H2)
- **End of Support** — The entire OS product line receives no further updates; ESU becomes the only option for continued security coverage

Windows 10 reached **end of product support** for Home/Pro on October 14, 2025. Enterprise/Education 22H2 is in mainstream support until October 2027 with quality updates still flowing.

### Quality Update Cadence (22H2 and LTSC)

- Monthly Security Rollup — Released every Patch Tuesday
- Optional non-security preview updates — Released late in the month (C/D week) — **not applicable for LTSC**
- Out-of-band emergency patches — Released as needed for critical zero-day CVEs
- Safeguard holds — Microsoft may block updates on hardware/driver combinations with known incompatibilities

---

## 4. Windows 10 to Windows 11 Migration

### Hardware Compatibility Requirements for Windows 11

| Requirement         | Windows 11 Minimum         | Notes                                                   |
|---------------------|----------------------------|---------------------------------------------------------|
| TPM                 | TPM 2.0                    | TPM 1.2 supported on Windows 10; not on Windows 11      |
| Secure Boot         | Must be capable (UEFI)     | Must be enabled in firmware                              |
| CPU                 | Intel 8th gen+ / AMD Zen 2+| Full supported CPU list at aka.ms/CPUlist               |
| RAM                 | 4 GB                       | 64-bit only                                             |
| Storage             | 64 GB                      |                                                         |
| Display             | 720p, 9" diagonal          |                                                         |
| UEFI firmware       | Required                   | Legacy BIOS (MBR) boot not supported                    |
| Internet connection | Required for Home edition setup | Enterprise/Education can bypass with Autopilot/OOBE|

### PC Health Check Tool

Microsoft provides the **PC Health Check** app (`WhyNotWin11` is a popular third-party alternative with more detail):
```powershell
# Check if PC Health Check is installed
Get-AppxPackage -Name 'MicrosoftCorporationII.WindowsPCHealthCheck' -AllUsers

# Download PC Health Check
Invoke-WebRequest -Uri 'https://aka.ms/GetPCHealthCheckApp' -OutFile "$env:TEMP\WindowsPCHealthCheckSetup.exe"
Start-Process "$env:TEMP\WindowsPCHealthCheckSetup.exe" -ArgumentList '/quiet' -Wait

# Query compatibility result programmatically via registry (after running the app)
Get-ItemProperty "HKLM:\SYSTEM\HardwareConfig\Current" |
    Select-Object SystemFamily, BaseBoardProduct, BIOSVendor
```

### In-Place Upgrade Process

**Via Windows Update (Intune Feature Update policy)**
```powershell
# Intune Feature Update deployment profile targets Windows 10 devices
# Configured at: Devices > Windows 10 and later updates > Feature updates
# Set "Feature update to deploy" = Windows 11, version 23H2 (or current)
# Assign to device groups with compatible hardware

# Check Windows Update assignment category on device
(New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search('IsInstalled=0 and Type="Software"').Updates |
    Where-Object { $_.Title -like '*Windows 11*' } |
    Select-Object Title, IsDownloaded, IsHidden
```

**Via SCCM / Configuration Manager**
```powershell
# SCCM Upgrade Task Sequence uses the Windows 11 media as the upgrade source
# Pre-requisite: Import Windows 11 OS Upgrade Package into SCCM
# Task Sequence steps:
#   1. Check Readiness (TPM, Secure Boot, CPU, disk space)
#   2. Download Package Content
#   3. Upgrade Operating System
#   4. Apply Windows Settings / Apply Network Settings
#   5. Restart Computer

# View SCCM client assignment state from device
Get-WmiObject -Namespace root\ccm\clientsdk -Class CCM_SoftwareUpdate |
    Where-Object { $_.Name -like '*Windows 11*' }
```

### Application Compatibility Testing

- **Microsoft Endpoint Analytics / Upgrade Readiness** — Collects app inventory from enrolled devices; flags apps with known compatibility signals
- **App Assure** — Microsoft's free service for Enterprise customers to remediate app compatibility issues found during Windows 11 upgrade
- **MSIX packaging** — Packaging legacy Win32 apps as MSIX can resolve many compatibility issues prior to upgrade
- Key compatibility risks: 32-bit kernel drivers, apps using removed APIs (WMI deprecated calls), apps requiring IE mode via iexplore.exe directly

### Driver Readiness

Windows 11 requires WHQL-signed drivers. Common issues:
- Older biometric sensors (fingerprint readers) without Windows 11 WHQL drivers
- Legacy chipset drivers (pre-2018 Intel platforms)
- Audio/video drivers from OEM portals that haven't been updated

```powershell
# Check for unsigned or incompatible drivers
$unsigned = Get-WmiObject Win32_PnPSignedDriver |
    Where-Object { $_.IsSigned -eq $false -or $_.DriverVersion -eq $null }
$unsigned | Select-Object DeviceName, DriverVersion, IsSigned | Format-Table -AutoSize
```

---

## 5. Windows 10 Unique Features (Not in Windows 11)

### Timeline (Activity History)

Windows 10 Timeline, accessible via Windows+Tab, displayed a chronological history of user activities (documents opened, websites visited, apps used) synced across devices via Microsoft account. **Removed in Windows 11.** Activity history still collects locally but the visual timeline UI is absent.

### Internet Explorer

Windows 10 ships with both Internet Explorer 11 (the standalone browser) and IE Mode within Edge. IE 11 as a standalone application was retired June 15, 2022, but the binary remains on Windows 10 for compatibility. **Windows 11 never shipped IE 11** — only Edge's IE Mode is available.

### Cortana Integration Differences

- Windows 10: Cortana was integrated into the taskbar search box; could not be fully disabled via UI without Group Policy in earlier builds
- Windows 11: Cortana is a separate optional app; no taskbar integration; disabled by default in commercial editions

### Taskbar

- Windows 10 taskbar: Fully customizable position (top, left, right, bottom); supports toolbars (custom, Address, Links, Desktop); right-click provides full customization menu
- Windows 11 taskbar: Locked to bottom; no toolbar support; simplified right-click context menu; center-aligned Start by default (left-align option available)

### Start Menu

- Windows 10 Start: Live Tiles supported; fully resizable; two-column layout (app list + tile board); supports folder tiles
- Windows 11 Start: No Live Tiles; static icon grid; Pinned + Recommended sections; no resizing; separate full app list via "All apps" button

### News and Interests (Windows 10 21H1+)

Taskbar weather/news widget introduced in Windows 10 21H1; replaced in Windows 11 by the separate Widgets panel (different implementation, different scope).

---

## 6. Enterprise Features Still Relevant in Windows 10

### AppLocker

AppLocker provides application whitelisting through Group Policy or Intune. Rule types: Executable, Windows Installer, Script, Packaged App (MSIX/AppX).

```powershell
# View current AppLocker policy
Get-AppLockerPolicy -Effective | Select-Object -ExpandProperty RuleCollections

# Test a file against the effective policy
Test-AppLockerPolicy -Path 'C:\Program Files\Vendor\app.exe' -User 'DOMAIN\StandardUser'

# Export effective policy to XML
Get-AppLockerPolicy -Effective -Xml | Out-File 'C:\Temp\applocker-policy.xml'
```

AppLocker requires Enterprise or Education edition. Windows Defender Application Control (WDAC) is the modern successor and works on Pro/Enterprise.

### Credential Guard

Credential Guard uses VBS to isolate LSASS secrets (NTLM hashes, Kerberos TGTs) in a hypervisor-protected container.

```powershell
# Check Credential Guard status
$dg = Get-CimInstance -ClassName Win32_DeviceGuard `
    -Namespace root\Microsoft\Windows\DeviceGuard
$cgStatus = switch ($dg.SecurityServicesRunning -band 1) {
    1 { 'Running' }
    0 { 'Configured but not running' }
    default { 'Not configured' }
}
Write-Host "Credential Guard: $cgStatus"

# Enable via registry (requires reboot; firmware VT-x/AMD-V required)
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'EnableVirtualizationBasedSecurity' -Value 1 -Type DWord
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'RequirePlatformSecurityFeatures' -Value 1 -Type DWord
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LsaCfgFlags' -Value 1 -Type DWord
```

### Device Guard / WDAC

Windows Defender Application Control (WDAC) enforces code integrity policy — only signed or explicitly trusted binaries execute. Unlike AppLocker, WDAC is enforced at the kernel level and cannot be bypassed by admin-level processes.

```powershell
# Check current WDAC enforcement mode
$cipolicy = Get-CimInstance -ClassName Win32_DeviceGuard `
    -Namespace root\Microsoft\Windows\DeviceGuard
Write-Host "Code Integrity Policy Enforcement: $($cipolicy.CodeIntegrityPolicyEnforcementStatus)"
# 0 = Off, 1 = Audit mode, 2 = Enforced

# Generate an audit-mode policy from a reference machine
New-CIPolicy -ScanPath 'C:\' -Level Publisher -Fallback Hash -FilePath 'C:\Temp\AuditPolicy.xml' -UserPEs
```

### BitLocker Management

```powershell
# Check BitLocker status on all volumes
Get-BitLockerVolume | Select-Object MountPoint, EncryptionMethod, VolumeStatus, ProtectionStatus

# Enable BitLocker on C: with TPM and recovery key
Enable-BitLocker -MountPoint 'C:' -EncryptionMethod XtsAes256 `
    -TpmProtector -RecoveryPasswordProtector

# Back up recovery key to Active Directory
$keyId = (Get-BitLockerVolume -MountPoint 'C:').KeyProtector |
    Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } |
    Select-Object -ExpandProperty KeyProtectorId
Backup-BitLockerKeyProtector -MountPoint 'C:' -KeyProtectorId $keyId
```

### Group Policy vs Intune

| Capability                         | Group Policy (ADMX)          | Intune (MDM/Settings Catalog)        |
|------------------------------------|------------------------------|--------------------------------------|
| Scope                              | Domain-joined devices        | Entra ID-joined / hybrid-joined      |
| Delivery                           | GPO, SYSVOL replication      | HTTPS push from Microsoft Graph      |
| LTSC support                       | Full                         | Full (Intune supports LTSC)          |
| Conflict resolution                | OU hierarchy / WMI filter    | Assignment groups / filters          |
| Reporting                          | RSOP, GPRESULT               | Intune compliance reports            |
| Offline enforcement                | Yes (cached GPO)             | Delayed (requires connectivity)      |

---

## 7. PowerShell Scripts

### Script 09 — ESU Status

```powershell
<#
.SYNOPSIS
    Windows 10 - ESU Enrollment and Coverage Status
.DESCRIPTION
    Checks ESU enrollment status, validates ESU license key activation,
    determines ESU eligibility by edition, calculates remaining coverage
    time, and identifies the active update source (WSUS, WU, or Intune).
.NOTES
    Version : 10.1.0
    Targets : Windows 10 Enterprise / LTSC
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Edition and EOL Eligibility
        2. ESU Key and Activation Status
        3. Azure Arc ESU Enrollment
        4. Intune ESU Policy Status
        5. Update Source Detection
        6. Remaining Coverage Summary
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n ESU Enrollment and Coverage Status`n$sep"

# --- Section 1: Edition and EOL Eligibility ---
Write-Host "`n--- Section 1: Edition and EOL Eligibility ---"
$osInfo = Get-CimInstance Win32_OperatingSystem
$buildStr = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild
$ubr     = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR
$edition = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
$displayVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA SilentlyContinue).DisplayVersion

Write-Host "OS:             $($osInfo.Caption)"
Write-Host "Edition ID:     $edition"
Write-Host "Version:        $displayVersion"
Write-Host "Build:          $buildStr.$ubr"

# EOL date lookup by edition and build
$today = Get-Date
$eolTable = @{
    'Enterprise'          = [datetime]'2027-10-14'
    'Education'           = [datetime]'2027-10-14'
    'EnterpriseS'         = [datetime]'2027-01-12'   # LTSC 2021
    'EnterpriseSN'        = [datetime]'2027-01-12'
    'EnterpriseG'         = [datetime]'2029-01-09'   # LTSC 2019 (17763)
    'Professional'        = [datetime]'2025-10-14'
    'Core'                = [datetime]'2025-10-14'
}

# LTSC 2019 detection by build number
if ($buildStr -eq '17763') {
    $eolDate = [datetime]'2029-01-09'
    Write-Host "LTSC Detection: LTSC 2019 (Build 17763) — EOL January 9, 2029"
} elseif ($buildStr -eq '19044' -and $edition -match 'Enterprise') {
    $eolDate = [datetime]'2027-01-12'
    Write-Host "LTSC Detection: LTSC 2021 (Build 19044) — EOL January 12, 2027"
} else {
    $eolDate = $eolTable[$edition]
    if (-not $eolDate) { $eolDate = [datetime]'2025-10-14' }
    Write-Host "EOL Date:       $($eolDate.ToString('MMMM d, yyyy'))"
}

$daysToEol = ($eolDate - $today).Days
$esuEligible = $edition -match 'Enterprise|Education|EnterpriseS'

Write-Host "Days to EOL:    $daysToEol"
Write-Host "ESU Eligible Edition: $(if($esuEligible){'Yes'}else{'No — ESU requires Enterprise, Education, or LTSC'})"

if ($daysToEol -gt 0 -and $today -lt $eolDate) {
    Write-Host "Coverage Status: IN SUPPORT — Standard updates still applicable"
} else {
    Write-Host "Coverage Status: PAST EOL — ESU enrollment required for security updates"
}

# --- Section 2: ESU Key and Activation Status ---
Write-Host "`n--- Section 2: ESU Key and Activation Status ---"
try {
    $slmgrOutput = & cscript.exe //Nologo "$env:windir\system32\slmgr.vbs" /dlv 2>&1
    $licenseStatus = $slmgrOutput | Select-String 'License Status'
    $partialKey    = $slmgrOutput | Select-String 'Partial Product Key'
    $description   = $slmgrOutput | Select-String 'Description'

    Write-Host "License Status: $($licenseStatus -replace '.*:\s*','')"
    Write-Host "Partial Key:    $($partialKey -replace '.*:\s*','')"

    # Detect ESU key by description string
    $isEsuKey = ($description -join '') -match 'Extended Security'
    Write-Host "ESU Key Detected: $(if($isEsuKey){'Yes'}else{'No — standard Windows license key active'})"
} catch {
    Write-Warning "Could not query Software Licensing Manager: $_"
}

# --- Section 3: Azure Arc ESU Enrollment ---
Write-Host "`n--- Section 3: Azure Arc ESU Enrollment ---"
$arcAgent = 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe'
if (Test-Path $arcAgent) {
    try {
        $arcStatus = & $arcAgent show 2>&1
        $arcConnected = ($arcStatus | Select-String 'status.*Connected') -ne $null
        Write-Host "Arc Agent:      Installed"
        Write-Host "Arc Connected:  $(if($arcConnected){'Yes — ESU eligible at no additional cost (Year 1)'}else{'Not connected'})"
        $arcStatus | Select-String 'subscriptionId|resourceGroup|location|status' |
            ForEach-Object { Write-Host "  $_" }
    } catch {
        Write-Warning "Arc agent present but query failed: $_"
    }
} else {
    Write-Host "Arc Agent:      Not installed"
}

# --- Section 4: Intune ESU Policy Status ---
Write-Host "`n--- Section 4: Intune ESU Policy Status ---"
$intuneKey = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\WindowsUpdateForBusiness'
if (Test-Path $intuneKey) {
    $intuneProps = Get-ItemProperty $intuneKey -EA SilentlyContinue
    $esuEnabled  = $intuneProps.ESUEnabled
    $esuStatus   = $intuneProps.ESUActivationStatus
    Write-Host "Intune ESU Enabled:           $(if($esuEnabled -eq 1){'Yes'}elseif($null -eq $esuEnabled){'Not configured'}else{'No'})"
    Write-Host "Intune ESU Activation Status: $(if($esuStatus){"$esuStatus"}else{'Not reported'})"
} else {
    Write-Host "Intune WUfB policy key not present — device may not be Intune-managed"
}

# --- Section 5: Update Source Detection ---
Write-Host "`n--- Section 5: Update Source Detection ---"
$wuKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$wuAu  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

if (Test-Path $wuKey) {
    $wuServer     = (Get-ItemProperty $wuKey -EA SilentlyContinue).WUServer
    $wuStatusSrv  = (Get-ItemProperty $wuKey -EA SilentlyContinue).WUStatusServer
    $useWuServer  = (Get-ItemProperty $wuAu  -EA SilentlyContinue).UseWUServer

    if ($useWuServer -eq 1 -and $wuServer) {
        Write-Host "Update Source:  WSUS"
        Write-Host "WSUS Server:    $wuServer"
        Write-Host "Status Server:  $wuStatusSrv"
    } elseif ($intuneProps) {
        Write-Host "Update Source:  Intune (Windows Update for Business)"
    } else {
        Write-Host "Update Source:  Windows Update (Microsoft CDN)"
    }
} else {
    Write-Host "Update Source:  Windows Update (no WSUS policy found)"
}

# --- Section 6: Remaining Coverage Summary ---
Write-Host "`n--- Section 6: Remaining Coverage Summary ---"
$esuMaxEnd = $eolDate.AddYears(3)
$remainingEsuDays = ($esuMaxEnd - $today).Days

Write-Host "Standard EOL Date:      $($eolDate.ToString('MMMM d, yyyy'))"
Write-Host "ESU Max Coverage End:   $($esuMaxEnd.ToString('MMMM d, yyyy')) (3-year ESU maximum)"
Write-Host "Days of ESU Coverage Remaining (if enrolled through max): $([Math]::Max(0, $remainingEsuDays))"

if ($today -ge $eolDate -and $today -le $esuMaxEnd) {
    $esuYear = [Math]::Ceiling(($today - $eolDate).Days / 365.25)
    Write-Host "Current ESU Year:       Year $esuYear of 3"
} elseif ($today -gt $esuMaxEnd) {
    Write-Host "Current ESU Year:       PAST maximum ESU coverage — no further updates available"
}

Write-Host "`n$sep`n ESU Status Assessment Complete`n$sep"
```

---

### Script 10 — Upgrade Readiness

```powershell
<#
.SYNOPSIS
    Windows 10 - Windows 11 Upgrade Readiness Assessment
.DESCRIPTION
    Checks hardware compatibility for Windows 11: TPM version, Secure Boot,
    CPU model against Microsoft approved list, RAM, disk space, and UEFI
    boot mode. Also scans for driver compatibility issues and BitLocker
    recovery key backup status.
.NOTES
    Version : 10.1.0
    Targets : Windows 10 Enterprise / LTSC
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. UEFI and Secure Boot
        2. TPM Version Check
        3. CPU Compatibility
        4. RAM and Disk Space
        5. Driver Compatibility
        6. BitLocker Recovery Key Backup Status
        7. Overall Readiness Summary
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n Windows 11 Upgrade Readiness Assessment`n$sep"

$score = 0; $maxScore = 6
$issues = [System.Collections.Generic.List[string]]::new()

# --- Section 1: UEFI and Secure Boot ---
Write-Host "`n--- Section 1: UEFI and Secure Boot ---"
try {
    $secureBoot = Confirm-SecureBootUEFI -EA Stop
    Write-Host "Secure Boot: $(if($secureBoot){'Enabled (PASS)'}else{'Disabled (FAIL)'})"
    if ($secureBoot) { $score++ } else { $issues.Add('Secure Boot is disabled — enable in UEFI firmware settings') }
} catch {
    Write-Host "Secure Boot: Cannot determine (likely Legacy BIOS / MBR boot)"
    $issues.Add('Secure Boot unavailable — system may be using Legacy BIOS; UEFI required for Windows 11')
}

# Check UEFI boot mode via firmware environment
try {
    $firmware = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -EA Stop).PEFirmwareType
    $isUEFI = $firmware -eq 2
    Write-Host "Firmware Mode: $(if($isUEFI){'UEFI (PASS)'}else{'Legacy BIOS (FAIL)'})"
    if (-not $isUEFI) { $issues.Add('Legacy BIOS detected — convert disk to GPT and enable UEFI for Windows 11') }
} catch {
    Write-Host "Firmware Mode: Cannot determine"
}

# --- Section 2: TPM Version Check ---
Write-Host "`n--- Section 2: TPM Version Check ---"
try {
    $tpm = Get-Tpm -EA Stop
    Write-Host "TPM Present:  $($tpm.TpmPresent)"
    Write-Host "TPM Ready:    $($tpm.TpmReady)"
    Write-Host "TPM Enabled:  $($tpm.TpmEnabled)"

    $tpmWmi = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftTpm -ClassName Win32_Tpm -EA SilentlyContinue
    if ($tpmWmi) {
        $specVer = $tpmWmi.SpecVersion
        Write-Host "TPM Spec:     $specVer"
        $isTpm2 = $specVer -match '^2\.'
        Write-Host "TPM 2.0:      $(if($isTpm2){'Yes (PASS)'}else{'No (FAIL) — Windows 11 requires TPM 2.0'})"
        if ($isTpm2 -and $tpm.TpmPresent -and $tpm.TpmReady) {
            $score++
        } else {
            $issues.Add("TPM 2.0 required. Current: $specVer. Check BIOS to enable TPM 2.0 (may be listed as PTT for Intel or fTPM for AMD)")
        }
    } else {
        Write-Host "TPM WMI:      Not accessible"
        $issues.Add('TPM WMI class unavailable — verify TPM is enabled in BIOS')
    }
} catch {
    Write-Host "TPM:          Not present or inaccessible"
    $issues.Add('No TPM detected — Windows 11 requires TPM 2.0')
}

# --- Section 3: CPU Compatibility ---
Write-Host "`n--- Section 3: CPU Compatibility ---"
$cpu = Get-CimInstance Win32_Processor
Write-Host "CPU Name:     $($cpu.Name)"
Write-Host "Architecture: $($cpu.Architecture) (9=ARM64, 0=x86)"
Write-Host "Cores:        $($cpu.NumberOfCores)"
Write-Host "Speed:        $($cpu.MaxClockSpeed) MHz"

# Heuristic compatibility check based on generation markers
$cpuName = $cpu.Name
$cpuPass = $false
$cpuNote = ''

if ($cpuName -match 'Intel') {
    # Intel 8th gen (Coffee Lake) and later — look for "Core i[x]-[89]\d{3}" or 10th+ gen patterns
    if ($cpuName -match 'Core i\d-[89]\d{3}|Core i\d-1[0-9]\d{3}|Core i\d-[2-9][0-9]{4}|Xeon (Gold|Platinum|Silver|Bronze) [23][0-9]{3}') {
        $cpuPass = $true; $cpuNote = 'Intel 8th gen or later detected (PASS)'
    } elseif ($cpuName -match 'Core i\d-[0-7]\d{3}') {
        $cpuNote = 'Intel 7th gen or earlier detected (FAIL) — not on Windows 11 supported CPU list'
    } else {
        $cpuNote = 'Intel CPU detected — verify against aka.ms/CPUlist'
    }
} elseif ($cpuName -match 'AMD') {
    # AMD Zen 2 and later: Ryzen 3xxx / 4xxx / 5xxx / 7xxx, EPYC 7xx2+
    if ($cpuName -match 'Ryzen [3-9] [3-9][0-9]{3}|Ryzen [3-9] [1-9][0-9]{4}|EPYC 7[0-9]{2}[2-9]|EPYC [89][0-9]{3}') {
        $cpuPass = $true; $cpuNote = 'AMD Zen 2 or later detected (PASS)'
    } elseif ($cpuName -match 'Ryzen [3-9] [12][0-9]{3}') {
        $cpuNote = 'AMD Zen 1 (Ryzen 1xxx/2xxx) detected (FAIL) — not on Windows 11 supported CPU list'
    } else {
        $cpuNote = 'AMD CPU detected — verify against aka.ms/CPUlist'
    }
} elseif ($cpuName -match 'Snapdragon|Qualcomm') {
    $cpuPass = $true; $cpuNote = 'Qualcomm Snapdragon detected — verify specific model at aka.ms/CPUlist'
} else {
    $cpuNote = 'CPU vendor not recognized — manually verify at https://aka.ms/CPUlist'
}

Write-Host "CPU Compat:   $cpuNote"
if ($cpuPass) { $score++ } else { $issues.Add("CPU may not be on Windows 11 supported list. Check: https://aka.ms/CPUlist") }

# --- Section 4: RAM and Disk Space ---
Write-Host "`n--- Section 4: RAM and Disk Space ---"
$ramGB = [Math]::Round($cpu.TotalPhysicalMemory / 1GB, 1)
# Get RAM from CIM OS object (more reliable)
$osObj = Get-CimInstance Win32_OperatingSystem
$ramGB = [Math]::Round($osObj.TotalVisibleMemorySize / 1MB, 1)
Write-Host "RAM:          $ramGB GB (minimum 4 GB required)"
$ramPass = $ramGB -ge 4
if ($ramPass) { $score++ } else { $issues.Add("Insufficient RAM: $ramGB GB. Windows 11 requires at least 4 GB") }

# Check system drive free space
$sysDrive = $env:SystemDrive
$disk = Get-PSDrive -Name ($sysDrive -replace ':','') -EA SilentlyContinue
if (-not $disk) { $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysDrive'" }
$freeGB  = if ($disk.Free) { [Math]::Round($disk.Free / 1GB, 1) } else { [Math]::Round($disk.FreeSpace / 1GB, 1) }
$totalGB = if ($disk.Used) { [Math]::Round(($disk.Free + $disk.Used) / 1GB, 1) } else { [Math]::Round($disk.Size / 1GB, 1) }
Write-Host "System Drive: $sysDrive — $freeGB GB free of $totalGB GB total"
$diskPass = $freeGB -ge 64
Write-Host "Disk Space:   $(if($diskPass){'Sufficient (PASS)'}else{'Insufficient (FAIL) — 64 GB free required for upgrade'})"
if ($diskPass) { $score++ } else { $issues.Add("Insufficient free disk space: $freeGB GB free. Need at least 64 GB free on $sysDrive") }

# --- Section 5: Driver Compatibility ---
Write-Host "`n--- Section 5: Driver Compatibility ---"
try {
    $allDrivers   = Get-WmiObject Win32_PnPSignedDriver -EA SilentlyContinue
    $unsignedList = $allDrivers | Where-Object { $_.IsSigned -eq $false }
    $noVersionList = $allDrivers | Where-Object { -not $_.DriverVersion -and $_.IsSigned -ne $false }

    Write-Host "Total Drivers:    $($allDrivers.Count)"
    Write-Host "Unsigned Drivers: $($unsignedList.Count)"

    if ($unsignedList.Count -gt 0) {
        Write-Host "Unsigned Driver Details:"
        $unsignedList | Select-Object DeviceName, Manufacturer, DriverVersion |
            Format-Table -AutoSize | Out-String | Write-Host
        $issues.Add("$($unsignedList.Count) unsigned driver(s) found — these may not load on Windows 11 (requires WHQL signature)")
    }

    # Flag likely problem devices
    $problemDevices = Get-CimInstance Win32_PnPEntity |
        Where-Object { $_.ConfigManagerErrorCode -ne 0 }
    Write-Host "Devices with errors: $($problemDevices.Count)"
    if ($problemDevices.Count -gt 0) {
        $problemDevices | Select-Object Name, ConfigManagerErrorCode |
            Format-Table -AutoSize | Out-String | Write-Host
    }

    $driverPass = ($unsignedList.Count -eq 0 -and $problemDevices.Count -eq 0)
    if ($driverPass) { $score++ } else {
        if ($unsignedList.Count -eq 0 -and $problemDevices.Count -gt 0) { $score++ }  # Partial credit — errors may be pre-existing
    }
} catch {
    Write-Warning "Driver compatibility check failed: $_"
}

# --- Section 6: BitLocker Recovery Key Backup Status ---
Write-Host "`n--- Section 6: BitLocker Recovery Key Backup Status ---"
try {
    $blVolumes = Get-BitLockerVolume -EA Stop
    foreach ($vol in $blVolumes) {
        Write-Host "Volume:        $($vol.MountPoint)"
        Write-Host "  Status:      $($vol.VolumeStatus)"
        Write-Host "  Protection:  $($vol.ProtectionStatus)"
        Write-Host "  Encryption:  $($vol.EncryptionMethod)"

        $recoveryProtectors = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
        if ($recoveryProtectors) {
            foreach ($prot in $recoveryProtectors) {
                # Check if backed up to AD DS
                try {
                    $adBackup = Get-ADObject -Filter "objectClass -eq 'msFVE-RecoveryInformation' and msFVE-RecoveryGuid -eq '$($prot.KeyProtectorId)'" `
                        -Properties msFVE-RecoveryPassword -EA SilentlyContinue
                    Write-Host "  AD Backup:   $(if($adBackup){'Yes (PASS)'}else{'Not found in AD'})"
                } catch {
                    Write-Host "  AD Backup:   Cannot verify (AD cmdlets not available or not domain-joined)"
                }

                # Check Azure AD / Entra ID backup via registry heuristic
                $aadBitlocker = Get-ItemProperty `
                    'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\BitLocker' -EA SilentlyContinue
                Write-Host "  Intune BL Policy: $(if($aadBitlocker){'Policy present'}else{'No Intune BitLocker policy detected'})"
            }
        } else {
            Write-Host "  Recovery Key: No RecoveryPassword protector found"
            if ($vol.ProtectionStatus -eq 'On') {
                $issues.Add("$($vol.MountPoint) is BitLocker-protected but has no RecoveryPassword protector — key cannot be backed up")
            }
        }
    }
} catch {
    Write-Host "BitLocker: Not enabled or cmdlets unavailable"
}

# --- Section 7: Overall Readiness Summary ---
Write-Host "`n--- Section 7: Overall Readiness Summary ---"
Write-Host "Readiness Score: $score / $maxScore"

$assessment = if ($score -eq $maxScore) {
    'READY: Device meets all Windows 11 hardware requirements'
} elseif ($score -ge 4) {
    'LIKELY READY: Minor issues detected — review and remediate before upgrading'
} elseif ($score -ge 2) {
    'NOT READY: Multiple hardware or driver issues — hardware upgrade or replacement may be required'
} else {
    'INCOMPATIBLE: Device does not meet Windows 11 requirements — plan hardware refresh'
}

Write-Host "Assessment:      $assessment"

if ($issues.Count -gt 0) {
    Write-Host "`nIssues to Remediate:"
    foreach ($issue in $issues) {
        Write-Host "  [!] $issue"
    }
} else {
    Write-Host "`nNo blocking issues found."
}

Write-Host "`nResources:"
Write-Host "  Windows 11 CPU list:    https://aka.ms/CPUlist"
Write-Host "  PC Health Check:        https://aka.ms/GetPCHealthCheckApp"
Write-Host "  App Assure:             https://aka.ms/AppAssure"
Write-Host "  ESU enrollment:         https://aka.ms/Win10ESU"

Write-Host "`n$sep`n Upgrade Readiness Assessment Complete`n$sep"
```
