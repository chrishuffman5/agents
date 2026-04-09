<#
.SYNOPSIS
    Windows Server - Windows Update and Patch Compliance
.DESCRIPTION
    Checks patch compliance status, pending updates, last install date,
    WSUS configuration, and update source settings. Identifies servers
    that are behind on patching or have failed updates.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Last Installed Updates
        2. Pending Reboot for Updates
        3. Windows Update Service Configuration
        4. WSUS Client Configuration
        5. Update History (Last 20)
        6. Patch Gap Assessment
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

Write-Host "`n$sep"
Write-Host " Windows Update and Patch Compliance - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host $sep

#region Section 1: Last Installed Updates
Write-Host "`n$sep"
Write-Host " SECTION 1 - Last 15 Installed Updates"
Write-Host $sep

$hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending -ErrorAction SilentlyContinue | Select-Object -First 15
$hotfixes | Select-Object HotFixID, Description, InstalledOn, InstalledBy | Format-Table -AutoSize

$lastPatch = $hotfixes | Select-Object -First 1
if ($lastPatch -and $lastPatch.InstalledOn) {
    $daysSince = ((Get-Date) - $lastPatch.InstalledOn).Days
    Write-Host "Days since last patch: $daysSince"
    if ($daysSince -gt 45) {
        Write-Warning "Server is $daysSince days behind on patching (>45 day threshold)."
    }
}
#endregion

#region Section 2: Pending Reboot for Updates
Write-Host "`n$sep"
Write-Host " SECTION 2 - Pending Reboot for Updates"
Write-Host $sep

$rebootRequired = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
$cbsPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'

[PSCustomObject]@{
    WURebootRequired = $rebootRequired
    CBSRebootPending = $cbsPending
    Assessment       = if ($rebootRequired -or $cbsPending) { 'WARNING: Reboot pending for updates' } else { 'OK: No pending reboot' }
} | Format-List
#endregion

#region Section 3: Windows Update Service Configuration
Write-Host "$sep"
Write-Host " SECTION 3 - Windows Update Service Configuration"
Write-Host $sep

$wuService = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
[PSCustomObject]@{
    ServiceName = 'wuauserv (Windows Update)'
    Status      = $wuService.Status
    StartType   = $wuService.StartType
} | Format-List

# Check AU settings from registry
$auPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
if (Test-Path $auPath) {
    $au = Get-ItemProperty -Path $auPath -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        AUOptions          = switch ($au.AUOptions) { 2 {'Notify'} 3 {'Auto download, notify install'} 4 {'Auto download and install'} 5 {'Managed by admin'} default { $au.AUOptions } }
        UseWUServer        = [bool]$au.UseWUServer
        ScheduledInstallDay = $au.ScheduledInstallDay
        ScheduledInstallTime = $au.ScheduledInstallTime
    } | Format-List
} else {
    Write-Host "No Windows Update AU policy configured (using defaults or managed externally)."
}
#endregion

#region Section 4: WSUS Client Configuration
Write-Host "$sep"
Write-Host " SECTION 4 - WSUS Client Configuration"
Write-Host $sep

$wuPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
if (Test-Path $wuPath) {
    $wu = Get-ItemProperty -Path $wuPath -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        WUServer       = $wu.WUServer
        WUStatusServer = $wu.WUStatusServer
        TargetGroup    = $wu.TargetGroup
        TargetEnabled  = [bool]$wu.TargetGroupEnabled
    } | Format-List
} else {
    Write-Host "No WSUS configuration found (server may use Windows Update directly or SCCM/Intune)."
}
#endregion

#region Section 5: Update History
Write-Host "$sep"
Write-Host " SECTION 5 - Update History (Last 20)"
Write-Host $sep

try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $histCount = $searcher.GetTotalHistoryCount()
    $history = $searcher.QueryHistory(0, [Math]::Min($histCount, 20))
    $history | Where-Object Title | ForEach-Object {
        [PSCustomObject]@{
            Date       = $_.Date
            Title      = $_.Title.Substring(0, [Math]::Min(80, $_.Title.Length))
            Result     = switch ($_.ResultCode) { 0 {'Not started'} 1 {'In progress'} 2 {'Succeeded'} 3 {'Succeeded with errors'} 4 {'Failed'} 5 {'Aborted'} }
        }
    } | Format-Table -AutoSize
} catch {
    Write-Host "Could not retrieve update history via COM object."
}
#endregion

#region Section 6: Patch Gap Assessment
Write-Host "$sep"
Write-Host " SECTION 6 - Patch Gap Assessment"
Write-Host $sep

$os = Get-CimInstance Win32_OperatingSystem
$buildNumber = $os.BuildNumber
$version = $os.Version

Write-Host "Current OS build: $version (Build $buildNumber)"
Write-Host "OS Caption: $($os.Caption)"

# Check for pending updates
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $results = $searcher.Search('IsInstalled=0 and Type=''Software''')
    $pending = $results.Updates.Count
    Write-Host "Pending updates available: $pending"
    if ($pending -gt 0) {
        Write-Warning "$pending update(s) available but not installed."
        $results.Updates | Select-Object -First 10 | ForEach-Object {
            Write-Host "  - $($_.Title.Substring(0, [Math]::Min(90, $_.Title.Length)))"
        }
    } else {
        Write-Host "All available updates are installed. OK."
    }
} catch {
    Write-Host "Could not query pending updates (WSUS may be managing this)."
}
#endregion

Write-Host "`n$sep"
Write-Host " Patch Compliance Check Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "$sep`n"
