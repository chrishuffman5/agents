<#
.SYNOPSIS
    Windows Client - Windows Update Compliance Check
.DESCRIPTION
    Checks current OS version, scans for pending updates, lists recently
    installed patches, reports WUfB deferral policies, Delivery Optimization
    status, and update service configuration. Identifies compliance gaps.
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Current OS Version vs Latest
        2. Pending Updates
        3. Last Installed Updates
        4. WUfB Deferral Policies
        5. Delivery Optimization Status
        6. Update Service Configuration
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: Current OS Version
Write-Host "`n$sep`n SECTION 1 - OS Version and Feature Update Status`n$sep"

$regCV = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$os    = Get-CimInstance Win32_OperatingSystem

[PSCustomObject]@{
    Caption          = $os.Caption
    DisplayVersion   = $regCV.DisplayVersion        # e.g., 23H2
    BuildNumber      = $os.BuildNumber
    UBR              = $regCV.UBR
    FullBuild        = "$($os.BuildNumber).$($regCV.UBR)"
    ReleaseId        = $regCV.ReleaseId
} | Format-List
#endregion

#region Section 2: Pending Updates
Write-Host "$sep`n SECTION 2 - Pending Windows Updates`n$sep"

try {
    $updateSession   = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher  = $updateSession.CreateUpdateSearcher()
    Write-Host "Searching for pending updates (may take 30-60 seconds)..."
    $searchResult    = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
    $updates         = $searchResult.Updates

    if ($updates.Count -eq 0) {
        Write-Host "OK: No pending updates found."
    } else {
        Write-Warning "$($updates.Count) pending update(s) found:"
        for ($i = 0; $i -lt $updates.Count; $i++) {
            $u = $updates.Item($i)
            [PSCustomObject]@{
                Title       = $u.Title.Substring(0, [Math]::Min(80, $u.Title.Length))
                KB          = ($u.KBArticleIDs | ForEach-Object { "KB$_" }) -join ', '
                Severity    = $u.MsrcSeverity
                SizeMB      = [math]::Round($u.MaxDownloadSize / 1MB, 1)
                IsDownloaded = $u.IsDownloaded
            }
        } | Format-Table -AutoSize
    }
} catch {
    Write-Warning "Windows Update COM not available: $($_.Exception.Message)"
}
#endregion

#region Section 3: Last Installed Updates
Write-Host "$sep`n SECTION 3 - Recently Installed Updates (Last 15)`n$sep"

Get-HotFix | Sort-Object InstalledOn -Descending -ErrorAction SilentlyContinue |
    Select-Object -First 15 HotFixID, Description, InstalledOn, InstalledBy |
    Format-Table -AutoSize

$lastPatch = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
if ($lastPatch.InstalledOn) {
    $age = ((Get-Date) - $lastPatch.InstalledOn).Days
    $msg = "Last patch ($($lastPatch.HotFixID)) installed $age days ago"
    if ($age -gt 45) { Write-Warning "$msg -- REVIEW: May be out of compliance." }
    else { Write-Host "$msg -- OK." }
}
#endregion

#region Section 4: WUfB Deferral Policies
Write-Host "$sep`n SECTION 4 - Windows Update for Business Deferral Settings`n$sep"

$wufb = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -ErrorAction SilentlyContinue
$au   = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -ErrorAction SilentlyContinue

if ($wufb) {
    [PSCustomObject]@{
        QualityUpdateDeferred       = [bool]$wufb.DeferQualityUpdates
        QualityDeferral_Days        = $wufb.DeferQualityUpdatesPeriodInDays
        FeatureUpdateDeferred       = [bool]$wufb.DeferFeatureUpdates
        FeatureDeferral_Days        = $wufb.DeferFeatureUpdatesPeriodInDays
        TargetVersion               = $wufb.TargetReleaseVersionInfo
        BranchReadinessLevel        = $wufb.BranchReadinessLevel
        PauseQualityUpdatesEndDate  = $wufb.PauseQualityUpdatesEndTime
        PauseFeatureUpdatesEndDate  = $wufb.PauseFeatureUpdatesEndTime
        WUServer                    = $wufb.WUServer
    } | Format-List
} else {
    Write-Host "No WUfB policy configured. Device uses default Windows Update settings."
}

if ($au) {
    Write-Host "AU Policy:"
    $au | Select-Object AUOptions, AutoInstallMinorUpdates, NoAutoUpdate,
        ScheduledInstallDay, ScheduledInstallTime | Format-List
}
#endregion

#region Section 5: Delivery Optimization
Write-Host "$sep`n SECTION 5 - Delivery Optimization Status`n$sep"

try {
    $doStatus = Get-DeliveryOptimizationStatus -ErrorAction Stop
    $doStatus | Select-Object FileId, Status, DownloadMode, BytesFromPeers,
        BytesFromGroupPeers, BytesFromCacheServer, BytesFromHttp,
        TotalBytesDownloaded | Format-Table -AutoSize -ErrorAction SilentlyContinue

    $doPerfMonth = Get-DeliveryOptimizationPerfSnapThisMonth -ErrorAction SilentlyContinue
    if ($doPerfMonth) {
        Write-Host "DO Monthly Summary:"
        $doPerfMonth | Format-List
    }
} catch {
    $doMode = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -ErrorAction SilentlyContinue).DODownloadMode
    Write-Host "DO Download Mode (policy): $doMode"
    Write-Host "  0=Off, 1=LAN peers, 2=Group, 3=Internet peers, 99=Bypass, 100=Simple"
}
#endregion

#region Section 6: Update Service Configuration
Write-Host "$sep`n SECTION 6 - Windows Update Service Configuration`n$sep"

$wuService = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
Write-Host "Windows Update Service: Status=$($wuService.Status), StartType=$($wuService.StartType)"

$doService = Get-Service -Name DoSvc -ErrorAction SilentlyContinue
Write-Host "Delivery Optimization Service: Status=$($doService.Status)"

# Check if managed by WSUS
$wsusServer = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -ErrorAction SilentlyContinue).WUServer
if ($wsusServer) {
    Write-Host "Managed by WSUS: $wsusServer"
} else {
    Write-Host "Update source: Windows Update (cloud) or not policy-configured"
}
#endregion

Write-Host "`n$sep`n Update Compliance Check Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
