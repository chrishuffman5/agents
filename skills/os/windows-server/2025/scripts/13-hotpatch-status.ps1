<#
.SYNOPSIS
    Windows Server 2025 - Hotpatch Status (All Editions)
.DESCRIPTION
    Checks Hotpatch eligibility, Azure Arc enrollment, subscription
    status, hotpatch update history, and baseline compliance.
.NOTES
    Version : 2025.1.0
    Targets : Windows Server 2025+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Edition and Hotpatch Eligibility
        2. Azure Arc Agent Status
        3. Hotpatch Update History
        4. Baseline vs Hotpatch Cycle
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n Hotpatch Status (Server 2025)`n$sep"

Write-Host "`n--- Section 1: Edition and Eligibility ---"
$edition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue).EditionID
$isAzure = $edition -match 'Azure'
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "Edition: $edition | Build: $($os.BuildNumber)"
Write-Host "Hotpatch support: $(if($isAzure){'Built-in (Azure Edition)'}else{'Requires Azure Arc + subscription ($1.50/core/month)'})"

Write-Host "`n--- Section 2: Azure Arc Agent ---"
$arcExe = 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe'
if (Test-Path $arcExe) {
    & $arcExe show 2>&1 | Select-String 'Agent Status|Agent Version|Resource Name|Subscription' | ForEach-Object { Write-Host "  $_" }
    $ver = & $arcExe version 2>&1
    Write-Host "  Arc agent version: $ver"
    if ($ver -match '(\d+\.\d+)' -and [double]$Matches[1] -lt 1.41) {
        Write-Warning "Arc agent version < 1.41 -- upgrade required for hotpatch."
    }
} else {
    if (-not $isAzure) { Write-Warning "Azure Arc agent not installed. Required for Hotpatch on non-Azure Edition." }
    else { Write-Host "Azure Edition: Arc not required for Hotpatch." }
}

Write-Host "`n--- Section 3: Hotpatch History ---"
try {
    $hotpatchStatus = Get-HotpatchStatus -EA Stop
    $hotpatchStatus | Format-List
} catch {
    Write-Host "Get-HotpatchStatus not available. Checking update history..."
    Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 15 HotFixID, Description, InstalledOn | Format-Table -AutoSize
}

Write-Host "--- Section 4: Patch Cycle ---"
$ubr = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA SilentlyContinue).UBR
Write-Host "Current UBR: $ubr"
Write-Host "Hotpatch cycle: Quarterly baseline (reboot) + monthly hotpatch (no reboot)"
Write-Host "Expected annual reboots: ~4 (vs 12 with traditional patching)"
Write-Host "`n$sep`n Hotpatch Check Complete`n$sep"
