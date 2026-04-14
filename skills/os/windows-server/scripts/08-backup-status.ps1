<#
.SYNOPSIS
    Windows Server - Backup Status Assessment
.DESCRIPTION
    Checks Windows Server Backup status, shadow copy configuration,
    system state backup history, and backup volume health. Identifies
    servers with missing or stale backups.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Windows Server Backup Feature Status
        2. Last Backup Summary
        3. Backup Schedule
        4. Volume Shadow Copy Status
        5. Shadow Copy Storage Allocation
        6. System State Backup Check (Domain Controllers)
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

Write-Host "`n$sep"
Write-Host " Backup Status Assessment - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host $sep

#region Section 1: WSB Feature Status
Write-Host "`n$sep"
Write-Host " SECTION 1 - Windows Server Backup Feature Status"
Write-Host $sep

$wsbFeature = Get-WindowsFeature -Name Windows-Server-Backup -ErrorAction SilentlyContinue
if ($wsbFeature) {
    [PSCustomObject]@{
        Feature    = 'Windows-Server-Backup'
        Installed  = $wsbFeature.Installed
        Assessment = if ($wsbFeature.Installed) { 'OK: Installed' } else { 'INFO: Not installed -- install with Install-WindowsFeature Windows-Server-Backup' }
    } | Format-List
} else {
    Write-Host "Cannot check Windows Server Backup feature status."
}
#endregion

#region Section 2: Last Backup Summary
Write-Host "$sep"
Write-Host " SECTION 2 - Last Backup Summary"
Write-Host $sep

try {
    $wbSummary = Get-WBSummary -ErrorAction Stop
    $daysSinceSuccess = if ($wbSummary.LastSuccessfulBackupTime) {
        ((Get-Date) - $wbSummary.LastSuccessfulBackupTime).Days
    } else { -1 }

    [PSCustomObject]@{
        LastSuccessfulBackup = $wbSummary.LastSuccessfulBackupTime
        LastBackupResult     = $wbSummary.LastBackupResultHR
        LastBackupTarget     = $wbSummary.LastBackupTarget
        NumberOfVersions     = $wbSummary.NumberOfVersions
        DaysSinceSuccess     = $daysSinceSuccess
        Assessment           = if ($daysSinceSuccess -lt 0) { 'CRITICAL: No successful backup recorded' }
                               elseif ($daysSinceSuccess -gt 7) { "WARNING: Last successful backup was $daysSinceSuccess days ago" }
                               else { 'OK' }
    } | Format-List
} catch {
    Write-Host "Windows Server Backup not configured or wbadmin not available."
    Write-Host "Install: Install-WindowsFeature -Name Windows-Server-Backup"
}
#endregion

#region Section 3: Backup Schedule
Write-Host "$sep"
Write-Host " SECTION 3 - Backup Schedule"
Write-Host $sep

try {
    $policy = Get-WBPolicy -ErrorAction Stop
    if ($policy) {
        [PSCustomObject]@{
            Schedule      = ($policy.Schedule | ForEach-Object { $_.ToString('HH:mm') }) -join ', '
            BackupTargets = ($policy.BackupTarget | ForEach-Object { $_.Label }) -join ', '
            VolumesInBackup = ($policy.VolumesToBackup | ForEach-Object { $_.MountPath }) -join ', '
            BMRIncluded   = $policy.BMR
            SystemState   = $policy.SystemState
        } | Format-List
    }
} catch {
    Write-Host "No backup policy configured (or Windows Server Backup not installed)."
}
#endregion

#region Section 4: Volume Shadow Copy Status
Write-Host "$sep"
Write-Host " SECTION 4 - Volume Shadow Copies"
Write-Host $sep

$vssOutput = vssadmin list shadows 2>&1
if ($vssOutput -match 'No items found') {
    Write-Warning "No shadow copies found on any volume. Configure VSS for file recovery."
} else {
    $shadowCount = ($vssOutput | Select-String 'Shadow Copy ID').Count
    Write-Host "Total shadow copies across all volumes: $shadowCount"

    # Get shadow copies per volume
    $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.FileSystem }
    foreach ($vol in $volumes) {
        $volShadows = vssadmin list shadows /for=$($vol.DriveLetter): 2>&1
        $count = ($volShadows | Select-String 'Shadow Copy ID').Count
        if ($count -gt 0) {
            Write-Host "  $($vol.DriveLetter): -- $count shadow copies"
        }
    }
}
#endregion

#region Section 5: Shadow Copy Storage Allocation
Write-Host "`n$sep"
Write-Host " SECTION 5 - Shadow Copy Storage Allocation"
Write-Host $sep

$storageOutput = vssadmin list shadowstorage 2>&1
if ($storageOutput -match 'No items found') {
    Write-Host "No shadow copy storage associations configured."
} else {
    Write-Host $storageOutput
}
#endregion

#region Section 6: System State Backup (DC Check)
Write-Host "`n$sep"
Write-Host " SECTION 6 - System State Backup Check"
Write-Host $sep

$os = Get-CimInstance Win32_OperatingSystem
$isDC = $os.ProductType -eq 2

if ($isDC) {
    Write-Host "This server is a Domain Controller -- system state backups are critical."
    try {
        $versions = wbadmin get versions -backupTarget:$null 2>&1
        if ($versions -match 'There are no backup versions') {
            Write-Warning "CRITICAL: No backup versions found for this Domain Controller."
            Write-Warning "Schedule daily system state backups: wbadmin start systemstatebackup -backuptarget:E: -quiet"
        } else {
            Write-Host "Backup versions found:"
            $versions | Select-String 'Version identifier' | Select-Object -Last 5 | ForEach-Object {
                Write-Host "  $_"
            }
        }
    } catch {
        Write-Warning "Could not query backup versions."
    }
} else {
    Write-Host "Server is not a Domain Controller -- system state backup is recommended but not critical."
}
#endregion

Write-Host "`n$sep"
Write-Host " Backup Status Assessment Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "$sep`n"
