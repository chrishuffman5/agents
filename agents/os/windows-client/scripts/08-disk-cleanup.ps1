<#
.SYNOPSIS
    Windows Client - Disk Cleanup Analysis and Recommendations
.DESCRIPTION
    Analyzes disk space consumption across temporary files, WinSxS
    component store, Windows.old, Delivery Optimization cache, and
    user profiles. Reports Storage Sense configuration and provides
    prioritized reclaim recommendations with safe cleanup commands.
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
    $recommendations += "Windows.old: ~$([math]::Round($windowsOld/1024,1)) GB -- Safe to remove if upgrade is stable"
}

$wuDownloadMB = Get-FolderSizeMB 'C:\Windows\SoftwareDistribution\Download'
if ($wuDownloadMB -gt 500) {
    $totalReclaimMB += $wuDownloadMB
    $recommendations += "WU Download cache: ~$([math]::Round($wuDownloadMB/1024,1)) GB -- Stop wuauserv, delete, restart"
}

if ($doCacheMB -gt 1000) {
    $totalReclaimMB += $doCacheMB * 0.5  # DO manages its own cache; partial
    $recommendations += "Delivery Optimization cache: ~$([math]::Round($doCacheMB/1024,1)) GB -- Run: Delete-DeliveryOptimizationCache -Force"
}

$userTempMB = Get-FolderSizeMB $env:TEMP
if ($userTempMB -gt 200) {
    $totalReclaimMB += $userTempMB
    $recommendations += "User TEMP (%TEMP%): ~$([math]::Round($userTempMB/1024,1)) GB -- Safe to delete contents"
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
