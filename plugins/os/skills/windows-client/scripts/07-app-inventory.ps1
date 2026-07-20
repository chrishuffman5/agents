<#
.SYNOPSIS
    Windows Client - Application Inventory
.DESCRIPTION
    Comprehensive application audit: Win32 apps from registry (both
    x64 and x86), Microsoft Store / UWP apps, winget package list,
    startup programs from all sources (Run keys, startup folders),
    and user-visible scheduled tasks.
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Win32 Apps (Registry-Based)
        2. Store / UWP Apps (AppxPackage)
        3. winget List (if available)
        4. Startup Programs
        5. Scheduled Tasks (User-Visible)
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: Win32 Apps
Write-Host "`n$sep`n SECTION 1 - Win32 Installed Applications (Registry)`n$sep"

$regPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$win32Apps = $regPaths | ForEach-Object {
    Get-ItemProperty $_ -ErrorAction SilentlyContinue
} | Where-Object { $_.DisplayName } | Select-Object DisplayName,
    DisplayVersion, Publisher, InstallDate,
    @{N='Architecture';E={if ($_.PSPath -match 'WOW6432') {'x86'} else {'x64/Other'}}} |
    Sort-Object DisplayName

Write-Host "Total Win32 apps: $($win32Apps.Count)"
$win32Apps | Format-Table -AutoSize
#endregion

#region Section 2: Store / UWP Apps
Write-Host "$sep`n SECTION 2 - Microsoft Store / UWP Apps`n$sep"

$storeApps = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
    Where-Object { $_.SignatureKind -ne 'System' } |
    Select-Object Name, Version, Publisher,
        @{N='Architecture';E={$_.Architecture}},
        @{N='InstallLocation';E={$_.InstallLocation.Substring(0,[Math]::Min(60,$_.InstallLocation.Length))}},
        PackageUserInformation |
    Sort-Object Name

Write-Host "Total Store/UWP apps: $($storeApps.Count)"
$storeApps | Select-Object Name, Version, Architecture | Format-Table -AutoSize
#endregion

#region Section 3: winget List
Write-Host "$sep`n SECTION 3 - winget Installed Packages`n$sep"

$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    Write-Host "winget version: $(winget --version)"
    Write-Host "winget list output:"
    winget list --accept-source-agreements 2>&1 | Select-Object -First 60 |
        ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "winget not found or not in PATH."
}
#endregion

#region Section 4: Startup Programs
Write-Host "$sep`n SECTION 4 - Startup Programs (All Sources)`n$sep"

$startupSources = @()

# Registry Run keys
$runKeys = @(
    @{Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Scope='Machine'},
    @{Path='HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Scope='Machine-x86'},
    @{Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Scope='User'}
)
foreach ($key in $runKeys) {
    $props = Get-ItemProperty $key.Path -ErrorAction SilentlyContinue
    if ($props) {
        $props.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
            $startupSources += [PSCustomObject]@{
                Source  = $key.Scope
                Name    = $_.Name
                Command = $_.Value.Substring(0, [Math]::Min(80, $_.Value.ToString().Length))
            }
        }
    }
}

# Startup folders
$startupFolders = @(
    @{Path="$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"; Scope='AllUsers'},
    @{Path="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; Scope='CurrentUser'}
)
foreach ($folder in $startupFolders) {
    if (Test-Path $folder.Path) {
        Get-ChildItem $folder.Path -ErrorAction SilentlyContinue | ForEach-Object {
            $startupSources += [PSCustomObject]@{
                Source  = $folder.Scope
                Name    = $_.Name
                Command = $_.FullName
            }
        }
    }
}

Write-Host "Total startup entries: $($startupSources.Count)"
$startupSources | Format-Table -AutoSize
#endregion

#region Section 5: Scheduled Tasks
Write-Host "$sep`n SECTION 5 - User-Visible Scheduled Tasks (Enabled)`n$sep"

Get-ScheduledTask | Where-Object {
    $_.State -eq 'Ready' -and
    $_.TaskPath -notlike '\Microsoft\*'
} | Select-Object TaskName, TaskPath, State,
    @{N='Author';E={$_.Author}},
    @{N='LastRun';E={(Get-ScheduledTaskInfo $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue).LastRunTime}} |
    Sort-Object TaskPath, TaskName | Format-Table -AutoSize
#endregion

Write-Host "`n$sep`n App Inventory Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
