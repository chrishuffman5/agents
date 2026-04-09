<#
.SYNOPSIS
    Windows Server 2019 - System Insights Status
.DESCRIPTION
    Checks System Insights feature installation, capability status,
    prediction results, and schedule configuration.
.NOTES
    Version : 2019.1.0
    Targets : Windows Server 2019+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Feature Installation Status
        2. Capability List and Status
        3. Prediction Results
        4. Schedule Configuration
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n System Insights Status - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep"

$feature = Get-WindowsFeature -Name System-Insights -ErrorAction SilentlyContinue
if (-not $feature -or -not $feature.Installed) {
    Write-Warning "System Insights not installed. Install: Install-WindowsFeature System-Insights -IncludeManagementTools"
    return
}
Write-Host "System Insights: Installed"

Write-Host "`n--- Capabilities ---"
$caps = Get-InsightsCapability -ErrorAction SilentlyContinue
$caps | Select-Object Name, Status, LastRun | Format-Table -AutoSize

Write-Host "--- Prediction Results ---"
foreach ($cap in $caps) {
    Write-Host "`n  $($cap.Name):"
    $result = Get-InsightsCapabilityResult -Name $cap.Name -ErrorAction SilentlyContinue
    if ($result) { $result | Select-Object Status, Description | Format-List }
    else { Write-Host "    No results yet (may need 30+ days of data)." }
}

Write-Host "--- Schedules ---"
foreach ($cap in $caps) {
    $sched = Get-InsightsCapabilitySchedule -Name $cap.Name -ErrorAction SilentlyContinue
    Write-Host "  $($cap.Name): $($sched.ScheduleType) $(if($sched.Enabled){'(Enabled)'}else{'(Disabled)'})"
}
Write-Host "`n$sep`n System Insights Check Complete`n$sep"
