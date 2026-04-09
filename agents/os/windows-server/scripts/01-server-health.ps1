<#
.SYNOPSIS
    Windows Server - Server Health Dashboard
.DESCRIPTION
    Comprehensive server health overview including OS version, edition,
    uptime, installed roles and features, recent hotfixes, and boot time.
    Provides a single-pane snapshot of server identity and state.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. OS Identity and Version
        2. Uptime and Boot Time
        3. Hardware Summary
        4. Installed Roles and Features
        5. Recent Hotfixes
        6. Pending Reboot Check
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: OS Identity and Version
Write-Host "`n$sep"
Write-Host " SECTION 1 - OS Identity and Version"
Write-Host $sep

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$edition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).EditionID

[PSCustomObject]@{
    ComputerName   = $cs.Name
    Domain         = $cs.Domain
    OSCaption      = $os.Caption
    Version        = $os.Version
    BuildNumber    = $os.BuildNumber
    EditionID      = $edition
    InstallDate    = $os.InstallDate
    Architecture   = $os.OSArchitecture
    WindowsDir     = $os.WindowsDirectory
    SystemDrive    = $os.SystemDrive
    ProductType    = switch ($os.ProductType) { 1 {'Workstation'} 2 {'Domain Controller'} 3 {'Server'} }
} | Format-List
#endregion

#region Section 2: Uptime and Boot Time
Write-Host "$sep"
Write-Host " SECTION 2 - Uptime and Boot Time"
Write-Host $sep

$uptime = (Get-Date) - $os.LastBootUpTime
[PSCustomObject]@{
    LastBootUpTime = $os.LastBootUpTime
    UptimeDays     = [math]::Round($uptime.TotalDays, 2)
    UptimeHours    = [math]::Round($uptime.TotalHours, 1)
    Assessment     = if ($uptime.TotalDays -gt 90) { 'WARNING: Server has not rebooted in 90+ days -- check patch compliance' }
                     elseif ($uptime.TotalDays -gt 30) { 'INFO: 30+ days uptime -- verify patching cadence' }
                     else { 'OK' }
} | Format-List
#endregion

#region Section 3: Hardware Summary
Write-Host "$sep"
Write-Host " SECTION 3 - Hardware Summary"
Write-Host $sep

$proc = Get-CimInstance Win32_Processor | Select-Object -First 1
[PSCustomObject]@{
    Manufacturer     = $cs.Manufacturer
    Model            = $cs.Model
    ProcessorName    = $proc.Name
    Sockets          = @(Get-CimInstance Win32_Processor).Count
    CoresPerSocket   = $proc.NumberOfCores
    LogicalProcessors = $cs.NumberOfLogicalProcessors
    TotalRAM_GB      = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    HyperVPresent    = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
} | Format-List
#endregion

#region Section 4: Installed Roles and Features
Write-Host "$sep"
Write-Host " SECTION 4 - Installed Roles and Features"
Write-Host $sep

try {
    $features = Get-WindowsFeature | Where-Object Installed
    Write-Host "Installed roles/features: $($features.Count)"
    $features | Where-Object { $_.FeatureType -eq 'Role' } |
        Select-Object Name, DisplayName | Format-Table -AutoSize

    Write-Host "Key features:"
    $features | Where-Object { $_.FeatureType -eq 'Feature' -and $_.Depth -le 1 } |
        Select-Object Name, DisplayName | Format-Table -AutoSize
} catch {
    Write-Warning "Get-WindowsFeature not available (may require ServerManager module)."
}
#endregion

#region Section 5: Recent Hotfixes
Write-Host "$sep"
Write-Host " SECTION 5 - Recent Hotfixes (Last 10)"
Write-Host $sep

Get-HotFix | Sort-Object InstalledOn -Descending -ErrorAction SilentlyContinue |
    Select-Object -First 10 HotFixID, Description, InstalledOn, InstalledBy |
    Format-Table -AutoSize

$lastPatch = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
if ($lastPatch -and $lastPatch.InstalledOn) {
    $daysSincePatch = ((Get-Date) - $lastPatch.InstalledOn).Days
    if ($daysSincePatch -gt 45) {
        Write-Warning "Last patch installed $daysSincePatch days ago -- review patch compliance."
    } else {
        Write-Host "Last patch: $($lastPatch.HotFixID) installed $daysSincePatch days ago. OK."
    }
}
#endregion

#region Section 6: Pending Reboot Check
Write-Host "$sep"
Write-Host " SECTION 6 - Pending Reboot Check"
Write-Host $sep

$rebootPending = $false
$reasons = @()

if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
    $rebootPending = $true; $reasons += 'CBS RebootPending'
}
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
    $rebootPending = $true; $reasons += 'Windows Update RebootRequired'
}
$pfro = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
if ($pfro.PendingFileRenameOperations) {
    $rebootPending = $true; $reasons += 'PendingFileRenameOperations'
}

[PSCustomObject]@{
    RebootPending = $rebootPending
    Reasons       = if ($reasons) { $reasons -join ', ' } else { 'None' }
    Assessment    = if ($rebootPending) { 'WARNING: Server has a pending reboot' } else { 'OK: No pending reboot' }
} | Format-List
#endregion

Write-Host "`n$sep"
Write-Host " Server Health Check Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "$sep`n"
