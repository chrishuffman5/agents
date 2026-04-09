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
    Write-Host "LTSC Detection: LTSC 2019 (Build 17763) -- EOL January 9, 2029"
} elseif ($buildStr -eq '19044' -and $edition -match 'Enterprise') {
    $eolDate = [datetime]'2027-01-12'
    Write-Host "LTSC Detection: LTSC 2021 (Build 19044) -- EOL January 12, 2027"
} else {
    $eolDate = $eolTable[$edition]
    if (-not $eolDate) { $eolDate = [datetime]'2025-10-14' }
    Write-Host "EOL Date:       $($eolDate.ToString('MMMM d, yyyy'))"
}

$daysToEol = ($eolDate - $today).Days
$esuEligible = $edition -match 'Enterprise|Education|EnterpriseS'

Write-Host "Days to EOL:    $daysToEol"
Write-Host "ESU Eligible Edition: $(if($esuEligible){'Yes'}else{'No -- ESU requires Enterprise, Education, or LTSC'})"

if ($daysToEol -gt 0 -and $today -lt $eolDate) {
    Write-Host "Coverage Status: IN SUPPORT -- Standard updates still applicable"
} else {
    Write-Host "Coverage Status: PAST EOL -- ESU enrollment required for security updates"
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
    Write-Host "ESU Key Detected: $(if($isEsuKey){'Yes'}else{'No -- standard Windows license key active'})"
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
        Write-Host "Arc Connected:  $(if($arcConnected){'Yes -- ESU eligible at no additional cost (Year 1)'}else{'Not connected'})"
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
    Write-Host "Intune WUfB policy key not present -- device may not be Intune-managed"
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
    } elseif (Test-Path $intuneKey) {
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
    Write-Host "Current ESU Year:       PAST maximum ESU coverage -- no further updates available"
}

Write-Host "`n$sep`n ESU Status Assessment Complete`n$sep"
