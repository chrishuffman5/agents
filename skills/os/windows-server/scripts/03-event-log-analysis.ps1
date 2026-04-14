<#
.SYNOPSIS
    Windows Server - Event Log Analysis
.DESCRIPTION
    Analyzes System, Application, and Security event logs for critical
    and error events. Identifies patterns, counts by source, and flags
    key security events (failed logons, account lockouts, service installs).
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. System Log - Critical and Error Events (7 days)
        2. Application Log - Critical and Error Events (7 days)
        3. Unexpected Shutdown / Reboot Events
        4. Service Installation Events (Security Watch)
        5. Failed Logon Summary
        6. Account Lockout Events
        7. Event Log Size and Retention Status
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
$lookback = (Get-Date).AddDays(-7)

Write-Host "`n$sep"
Write-Host " Event Log Analysis - Past 7 Days - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host $sep

#region Section 1: System Log Errors
Write-Host "`n$sep"
Write-Host " SECTION 1 - System Log: Critical and Error Events"
Write-Host $sep

$sysErrors = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$lookback} -ErrorAction SilentlyContinue
Write-Host "Total critical/error events: $($sysErrors.Count)"

if ($sysErrors) {
    Write-Host "`nTop sources:"
    $sysErrors | Group-Object ProviderName | Sort-Object Count -Descending |
        Select-Object -First 10 Count, Name | Format-Table -AutoSize

    Write-Host "Most recent 10:"
    $sysErrors | Select-Object -First 10 TimeCreated, Id, ProviderName,
        @{N='Message';E={$_.Message.Substring(0,[Math]::Min(120,$_.Message.Length))}} | Format-Table -AutoSize
}
#endregion

#region Section 2: Application Log Errors
Write-Host "$sep"
Write-Host " SECTION 2 - Application Log: Critical and Error Events"
Write-Host $sep

$appErrors = Get-WinEvent -FilterHashtable @{LogName='Application'; Level=1,2; StartTime=$lookback} -ErrorAction SilentlyContinue
Write-Host "Total critical/error events: $($appErrors.Count)"

if ($appErrors) {
    Write-Host "`nTop sources:"
    $appErrors | Group-Object ProviderName | Sort-Object Count -Descending |
        Select-Object -First 10 Count, Name | Format-Table -AutoSize
}
#endregion

#region Section 3: Unexpected Shutdowns
Write-Host "$sep"
Write-Host " SECTION 3 - Unexpected Shutdown / Reboot Events"
Write-Host $sep

$shutdownIds = @(41, 6008, 1074, 1076)
$shutdownEvents = Get-WinEvent -FilterHashtable @{LogName='System'; Id=$shutdownIds; StartTime=$lookback} -ErrorAction SilentlyContinue

if ($shutdownEvents) {
    $shutdownEvents | Select-Object TimeCreated, Id,
        @{N='Type';E={switch($_.Id){41{'Unexpected reboot (Kernel-Power)'}6008{'Unexpected shutdown'}1074{'Planned shutdown'}1076{'Shutdown reason code'}}}},
        @{N='Message';E={$_.Message.Substring(0,[Math]::Min(100,$_.Message.Length))}} | Format-Table -AutoSize
} else {
    Write-Host "No unexpected shutdown events in the past 7 days. OK."
}
#endregion

#region Section 4: Service Installation Events
Write-Host "$sep"
Write-Host " SECTION 4 - New Service Installations (Event 7045)"
Write-Host $sep

$svcInstalls = Get-WinEvent -FilterHashtable @{LogName='System'; Id=7045; StartTime=$lookback} -ErrorAction SilentlyContinue
if ($svcInstalls) {
    Write-Warning "New services installed in past 7 days (review for unauthorized installs):"
    $svcInstalls | ForEach-Object {
        $xml = [xml]$_.ToXml()
        [PSCustomObject]@{
            TimeCreated = $_.TimeCreated
            ServiceName = ($xml.Event.EventData.Data | Where-Object Name -eq 'ServiceName').'#text'
            ImagePath   = ($xml.Event.EventData.Data | Where-Object Name -eq 'ImagePath').'#text'
            AccountName = ($xml.Event.EventData.Data | Where-Object Name -eq 'AccountName').'#text'
        }
    } | Format-Table -AutoSize
} else {
    Write-Host "No new service installations in the past 7 days."
}
#endregion

#region Section 5: Failed Logon Summary
Write-Host "$sep"
Write-Host " SECTION 5 - Failed Logon Summary (Event 4625)"
Write-Host $sep

$failedLogons = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625; StartTime=$lookback} -MaxEvents 500 -ErrorAction SilentlyContinue
if ($failedLogons) {
    Write-Host "Total failed logons (up to 500 shown): $($failedLogons.Count)"
    $failedLogons | ForEach-Object {
        $xml = [xml]$_.ToXml()
        ($xml.Event.EventData.Data | Where-Object Name -eq 'TargetUserName').'#text'
    } | Group-Object | Sort-Object Count -Descending |
        Select-Object -First 10 Count, @{N='Account';E={$_.Name}} | Format-Table -AutoSize
} else {
    Write-Host "No failed logon events in the past 7 days."
}
#endregion

#region Section 6: Account Lockouts
Write-Host "$sep"
Write-Host " SECTION 6 - Account Lockout Events (Event 4740)"
Write-Host $sep

$lockouts = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4740; StartTime=$lookback} -ErrorAction SilentlyContinue
if ($lockouts) {
    Write-Warning "Account lockouts detected:"
    $lockouts | ForEach-Object {
        $xml = [xml]$_.ToXml()
        [PSCustomObject]@{
            TimeCreated = $_.TimeCreated
            Account     = ($xml.Event.EventData.Data | Where-Object Name -eq 'TargetUserName').'#text'
            CallerPC    = ($xml.Event.EventData.Data | Where-Object Name -eq 'TargetDomainName').'#text'
        }
    } | Format-Table -AutoSize
} else {
    Write-Host "No account lockout events in the past 7 days."
}
#endregion

#region Section 7: Log Size and Retention
Write-Host "$sep"
Write-Host " SECTION 7 - Event Log Size and Retention"
Write-Host $sep

@('Security', 'System', 'Application') | ForEach-Object {
    $log = Get-WinEvent -ListLog $_ -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        LogName     = $_
        MaxSizeMB   = [math]::Round($log.MaximumSizeInBytes / 1MB)
        RecordCount = $log.RecordCount
        LogMode     = $log.LogMode
        Assessment  = if ($_ -eq 'Security' -and $log.MaximumSizeInBytes -lt 196608000) { 'WARNING: Security log < 196 MB (CIS recommends 196 MB+)' }
                      elseif ($log.MaximumSizeInBytes -lt 32768000) { 'WARNING: Log < 32 MB (increase recommended)' }
                      else { 'OK' }
    }
} | Format-Table -AutoSize
#endregion

Write-Host "`n$sep"
Write-Host " Event Log Analysis Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "$sep`n"
