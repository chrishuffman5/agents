<#
.SYNOPSIS
    Windows Server - Service Health Assessment
.DESCRIPTION
    Evaluates critical Windows services, identifies auto-start services
    that are stopped, checks service recovery configuration, and flags
    services in degraded states.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Critical Windows Services Status
        2. Auto-Start Services Not Running
        3. Recently Crashed Services (Event 7034)
        4. Service Recovery Configuration Audit
        5. Services with Non-Standard Accounts
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

Write-Host "`n$sep"
Write-Host " Service Health Assessment - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host $sep

#region Section 1: Critical Windows Services
Write-Host "`n$sep"
Write-Host " SECTION 1 - Critical Windows Services Status"
Write-Host $sep

$criticalServices = @(
    @{Name='EventLog';        Display='Windows Event Log'},
    @{Name='Winmgmt';         Display='WMI'},
    @{Name='wuauserv';        Display='Windows Update'},
    @{Name='W32Time';         Display='Windows Time'},
    @{Name='WinRM';           Display='WinRM'},
    @{Name='LanmanServer';    Display='SMB Server'},
    @{Name='LanmanWorkstation'; Display='SMB Client'},
    @{Name='Netlogon';        Display='Net Logon'},
    @{Name='CryptSvc';        Display='Cryptographic Services'},
    @{Name='mpssvc';          Display='Windows Firewall'},
    @{Name='WinDefend';       Display='Windows Defender Antivirus'},
    @{Name='Schedule';        Display='Task Scheduler'}
)

foreach ($svc in $criticalServices) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($service) {
        [PSCustomObject]@{
            Name       = $svc.Display
            ServiceName = $svc.Name
            Status     = $service.Status
            StartType  = $service.StartType
            Assessment = if ($service.Status -ne 'Running' -and $service.StartType -in @('Automatic', 'Manual')) {
                             'WARNING: Not running'
                         } else { 'OK' }
        }
    } else {
        [PSCustomObject]@{
            Name       = $svc.Display
            ServiceName = $svc.Name
            Status     = 'Not found'
            StartType  = 'N/A'
            Assessment = 'INFO: Service not installed'
        }
    }
} | Format-Table -AutoSize
#endregion

#region Section 2: Auto-Start Services Not Running
Write-Host "$sep"
Write-Host " SECTION 2 - Auto-Start Services Not Running"
Write-Host $sep

$stoppedAuto = Get-Service | Where-Object {
    $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running'
}

if ($stoppedAuto) {
    Write-Warning "The following auto-start services are not running:"
    $stoppedAuto | Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize
    Write-Host "Total: $($stoppedAuto.Count) auto-start services stopped."
} else {
    Write-Host "All auto-start services are running. OK."
}
#endregion

#region Section 3: Recently Crashed Services
Write-Host "$sep"
Write-Host " SECTION 3 - Recently Crashed Services (Event 7034, 7031 - Last 7 Days)"
Write-Host $sep

$crashEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Id        = 7034, 7031
    StartTime = (Get-Date).AddDays(-7)
} -ErrorAction SilentlyContinue

if ($crashEvents) {
    Write-Warning "Services that crashed in the last 7 days:"
    $crashEvents | ForEach-Object {
        [PSCustomObject]@{
            TimeCreated = $_.TimeCreated
            EventId     = $_.Id
            Type        = if ($_.Id -eq 7034) { 'Unexpected termination' } else { 'Termination + recovery action' }
            Message     = $_.Message.Substring(0, [Math]::Min(120, $_.Message.Length))
        }
    } | Format-Table -AutoSize
} else {
    Write-Host "No service crash events in the past 7 days. OK."
}
#endregion

#region Section 4: Service Recovery Configuration
Write-Host "$sep"
Write-Host " SECTION 4 - Service Recovery Configuration (Critical Services)"
Write-Host $sep

$checkServices = @('EventLog', 'Winmgmt', 'WinRM', 'LanmanServer', 'Netlogon', 'CryptSvc', 'Schedule')
foreach ($svcName in $checkServices) {
    $scOutput = sc.exe qfailure $svcName 2>&1
    $resetPeriod = ($scOutput | Select-String 'RESET_PERIOD').ToString() -replace '.*:\s*', '' -replace '\s.*', ''
    $actions = ($scOutput | Select-String 'FAILURE_ACTIONS').ToString() -replace '.*:\s*', ''

    [PSCustomObject]@{
        Service       = $svcName
        ResetPeriod   = $resetPeriod
        FailureAction = $actions.Trim()
        Assessment    = if ($actions -match 'NONE') { 'WARNING: No recovery action configured' } else { 'OK' }
    }
} | Format-Table -AutoSize
#endregion

#region Section 5: Services with Non-Standard Accounts
Write-Host "$sep"
Write-Host " SECTION 5 - Running Services with Non-Standard Accounts"
Write-Host $sep

$standardAccounts = @('LocalSystem', 'NT AUTHORITY\LocalService', 'NT AUTHORITY\NetworkService',
                      'NT AUTHORITY\SYSTEM', 'LocalService', 'NetworkService', 'localSystem')

Get-CimInstance Win32_Service | Where-Object {
    $_.State -eq 'Running' -and $_.StartName -and
    $_.StartName -notin $standardAccounts -and
    $_.StartName -notlike 'NT SERVICE\*'
} | Select-Object Name, DisplayName, StartName, ProcessId | Format-Table -AutoSize

Write-Host "Review: Services using domain or local user accounts should use gMSA or dMSA where possible."
#endregion

Write-Host "`n$sep"
Write-Host " Service Health Assessment Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "$sep`n"
