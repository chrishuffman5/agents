<#
.SYNOPSIS
    Windows 11 - Enterprise Hotpatch Enrollment and Compliance Status
.DESCRIPTION
    Checks Azure Arc enrollment, hotpatch policy assignment via MDM/Intune,
    hotpatch orchestrator state, baseline vs hotpatch update history, and
    overall compliance for Enterprise 24H2+ devices.
.NOTES
    Version : 1.0.0
    Targets : Windows 11 Enterprise 24H2+ (build 26100+)
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. OS Version and Edition
        2. Azure Arc Enrollment
        3. Hotpatch Policy (MDM/Intune)
        4. Current Hotpatch State
        5. Update History (Baseline vs Hotpatch)
        6. Compliance Summary
#>

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

[CmdletBinding()]
param(
    [switch]$IncludeUpdateHistory
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 70)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 70)" -ForegroundColor Cyan
}

$results = [ordered]@{}

# ── 1. OS Version and Edition ───────────────────────────────────────────────
Write-Section "OS Version and Edition"
$os    = Get-CimInstance -ClassName Win32_OperatingSystem
$build = [System.Environment]::OSVersion.Version.Build
$sku   = $os.OperatingSystemSKU

$results['OS_Caption'] = $os.Caption
$results['OS_Build']   = $build
$results['OS_SKU']     = $sku

Write-Host "  OS Caption  : $($os.Caption)"
Write-Host "  Build       : $build"
Write-Host "  SKU         : $sku"

# Hotpatch requires Enterprise 24H2 (build 26100+)
# SKU 4 = Enterprise, SKU 27 = Enterprise N, SKU 125 = Enterprise LTSC
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
        Write-Host "  Hotpatch requires Enterprise edition (SKU 4/27/125). Current: $sku" -ForegroundColor Red
    }
}

# ── 2. Azure Arc Enrollment ─────────────────────────────────────────────────
Write-Section "Azure Arc Enrollment"

$arcService = Get-Service -Name 'himds' -ErrorAction SilentlyContinue
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

# Check Azure Arc configuration directory
$arcConfigPath = "$env:ProgramData\AzureConnectedMachineAgent\Config"
if (Test-Path $arcConfigPath) {
    Write-Host "  Arc config path: $arcConfigPath"
    $arcConfig = Get-ChildItem -Path $arcConfigPath -Filter '*.json' -ErrorAction SilentlyContinue
    foreach ($cfg in $arcConfig) {
        Write-Host "    Config file: $($cfg.Name) ($(($cfg.LastWriteTime).ToString('yyyy-MM-dd')))"
    }
}

# ── 3. Hotpatch Policy (MDM/Intune) ─────────────────────────────────────────
Write-Section "Hotpatch Policy (MDM/Intune)"

$hotpatchPolicyKey = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update'
if (Test-Path $hotpatchPolicyKey) {
    $policy = Get-ItemProperty -Path $hotpatchPolicyKey -ErrorAction SilentlyContinue
    Write-Host "  MDM Update policy key: Present"

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

# ── 4. Current Hotpatch State ───────────────────────────────────────────────
Write-Section "Current Hotpatch State"

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

# ── 5. Update History (Baseline vs Hotpatch) ────────────────────────────────
if ($IncludeUpdateHistory) {
    Write-Section "Windows Update History (Baseline vs Hotpatch)"

    $updateSession  = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $historyCount   = $updateSearcher.GetTotalHistoryCount()
    $history        = $updateSearcher.QueryHistory(0, [Math]::Min($historyCount, 50))

    $hotpatchUpdates = @()
    $baselineUpdates = @()

    foreach ($update in $history) {
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
        Write-Host "    [Hotpatch]  $($u.Date.ToString('yyyy-MM-dd')) — $($u.Title)"
    }

    Write-Host "  Baseline (reboot) updates in last 50: $($baselineUpdates.Count)"
    foreach ($u in $baselineUpdates | Select-Object -First 5) {
        Write-Host "    [Baseline]  $($u.Date.ToString('yyyy-MM-dd')) — $($u.Title)"
    }

    $results['Hotpatch_Count_Last50']  = $hotpatchUpdates.Count
    $results['Baseline_Count_Last50']  = $baselineUpdates.Count
} else {
    Write-Host "`n  TIP: Run with -IncludeUpdateHistory to analyze baseline vs hotpatch update cadence" -ForegroundColor Cyan
}

# ── 6. Compliance Summary ───────────────────────────────────────────────────
Write-Section "Hotpatch Compliance Summary"
$complianceItems = [ordered]@{
    'OS Build 24H2+ (26100+)' = $results['OS_Hotpatch_Eligible']
    'Azure Arc Agent Running' = $results['AzureArc_Running']
    'Hotpatch Policy Enabled' = $results['Hotpatch_Policy_Enabled']
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

Write-Host "`nHotpatch compliance assessment complete." -ForegroundColor Green
