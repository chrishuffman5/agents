<#
.SYNOPSIS
    Windows Server 2022 - Hotpatch Status (Azure Edition)
.DESCRIPTION
    Checks Hotpatch eligibility, Azure Arc enrollment, hotpatch update
    history, and baseline/hotpatch cycle compliance.
.NOTES
    Version : 2022.1.0
    Targets : Windows Server 2022 Datacenter: Azure Edition
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Azure Edition Detection
        2. Azure Arc Agent Status
        3. Hotpatch Update History
        4. Baseline vs Hotpatch Assessment
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n Hotpatch Status Assessment`n$sep"

Write-Host "`n--- Section 1: Azure Edition Detection ---"
$edition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue).EditionID
$isAzureEdition = $edition -match 'Azure'
Write-Host "Edition ID: $edition"
Write-Host "Azure Edition: $(if($isAzureEdition){'Yes'}else{'No -- Hotpatch requires Azure Edition in 2022'})"

if (-not $isAzureEdition) {
    Write-Warning "Hotpatch is only available on Datacenter: Azure Edition in Windows Server 2022."
    Write-Host "Consider Windows Server 2025 for Hotpatch on Standard/Datacenter editions."
    Write-Host "`n$sep`n Hotpatch Check Complete`n$sep"
    return
}

Write-Host "`n--- Section 2: Azure Arc Agent ---"
$arcAgent = 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe'
if (Test-Path $arcAgent) {
    & $arcAgent show 2>&1 | Select-String -Pattern 'Agent Status|Resource Name|Subscription' | Write-Host
    $arcServices = Get-Service -Name 'himds','ExtensionService','GCArcService' -EA SilentlyContinue
    $arcServices | Select-Object Name, Status | Format-Table -AutoSize
} else { Write-Warning "Azure Arc agent not found. Install from aka.ms/AzureConnectedMachineAgent" }

Write-Host "--- Section 3: Hotpatch Update History ---"
$hotpatches = Get-HotFix | Where-Object { $_.Description -eq 'Hotfix' } |
    Sort-Object InstalledOn -Descending | Select-Object -First 10
if ($hotpatches) {
    $hotpatches | Select-Object HotFixID, Description, InstalledOn | Format-Table -AutoSize
} else { Write-Host "No hotpatch-specific updates found in history." }

Write-Host "--- Section 4: Baseline Assessment ---"
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "Current build: $($os.Version) (UBR: $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR))"
Write-Host "Hotpatch cycle: Quarterly baseline (reboot) + monthly hotpatch (no reboot)"
Write-Host "`n$sep`n Hotpatch Check Complete`n$sep"
