<#
.SYNOPSIS
    Windows Server - Security Audit
.DESCRIPTION
    Audits local security configuration including user accounts, groups,
    services running as privileged accounts, open ports, certificate
    expiration, and audit policy settings.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Local User Accounts
        2. Local Administrators Group
        3. Services Running as Privileged Accounts
        4. Audit Policy Status
        5. Open Listening Ports (External Interfaces)
        6. Certificate Expiration Check
        7. VBS and Credential Guard Status
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

Write-Host "`n$sep"
Write-Host " Security Audit - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host $sep

#region Section 1: Local User Accounts
Write-Host "`n$sep"
Write-Host " SECTION 1 - Local User Accounts"
Write-Host $sep

Get-CimInstance Win32_UserAccount -Filter "LocalAccount=True" |
    Select-Object Name, Disabled, PasswordRequired, PasswordExpires, Lockout,
        @{N='Assessment';E={
            if (-not $_.Disabled -and -not $_.PasswordRequired) { 'WARNING: Active account without password requirement' }
            elseif (-not $_.Disabled -and $_.Name -eq 'Administrator') { 'INFO: Built-in Administrator is enabled' }
            elseif ($_.Lockout) { 'WARNING: Account is locked out' }
            else { 'OK' }
        }} | Format-Table -AutoSize
#endregion

#region Section 2: Local Administrators Group
Write-Host "$sep"
Write-Host " SECTION 2 - Local Administrators Group Members"
Write-Host $sep

try {
    $adminGroup = Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop
    $adminGroup | Select-Object Name, ObjectClass, PrincipalSource | Format-Table -AutoSize
    if ($adminGroup.Count -gt 5) {
        Write-Warning "More than 5 members in local Administrators group -- review for least-privilege compliance."
    }
} catch {
    Write-Host "Could not enumerate local Administrators group: $($_.Exception.Message)"
}
#endregion

#region Section 3: Services as Privileged Accounts
Write-Host "$sep"
Write-Host " SECTION 3 - Services Running as Privileged Accounts"
Write-Host $sep

Get-CimInstance Win32_Service | Where-Object {
    $_.State -eq 'Running' -and
    $_.StartName -and
    $_.StartName -notin @('LocalSystem', 'NT AUTHORITY\LocalService', 'NT AUTHORITY\NetworkService',
                          'NT AUTHORITY\SYSTEM', 'LocalService', 'NetworkService', 'localSystem') -and
    $_.StartName -notlike 'NT SERVICE\*'
} | Select-Object Name, DisplayName, StartName, State |
    Sort-Object StartName | Format-Table -AutoSize

Write-Host "Services running as LocalSystem (high privilege):"
$sysServices = Get-CimInstance Win32_Service | Where-Object { $_.State -eq 'Running' -and $_.StartName -in @('LocalSystem', 'NT AUTHORITY\SYSTEM') }
Write-Host "  Count: $($sysServices.Count)"
#endregion

#region Section 4: Audit Policy
Write-Host "`n$sep"
Write-Host " SECTION 4 - Audit Policy Status"
Write-Host $sep

$auditOutput = auditpol /get /category:* 2>&1
$criticalPolicies = @('Logon', 'Account Lockout', 'Audit Policy Change', 'User Account Management', 'Sensitive Privilege Use')
foreach ($policy in $criticalPolicies) {
    $line = $auditOutput | Where-Object { $_ -match "^\s+$policy\s" }
    if ($line) {
        $setting = ($line -replace '^\s+\S+.*\s{2,}', '').Trim()
        $assessment = if ($setting -match 'No Auditing') { 'WARNING: Not audited' } else { 'OK' }
        Write-Host "  $policy : $setting [$assessment]"
    }
}
#endregion

#region Section 5: Open Listening Ports
Write-Host "`n$sep"
Write-Host " SECTION 5 - Open Listening Ports (External-Facing)"
Write-Host $sep

Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalAddress -notin @('127.0.0.1', '::1') } |
    Select-Object LocalAddress, LocalPort,
        @{N='Process';E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name}} |
    Sort-Object LocalPort | Format-Table -AutoSize
#endregion

#region Section 6: Certificate Expiration
Write-Host "$sep"
Write-Host " SECTION 6 - Certificate Expiration Check (Local Machine)"
Write-Host $sep

$certs = Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue
if ($certs) {
    $certs | ForEach-Object {
        $daysLeft = ($_.NotAfter - (Get-Date)).Days
        [PSCustomObject]@{
            Subject    = $_.Subject.Substring(0, [Math]::Min(60, $_.Subject.Length))
            Thumbprint = $_.Thumbprint.Substring(0, 16) + '...'
            NotAfter   = $_.NotAfter
            DaysLeft   = $daysLeft
            Assessment = if ($daysLeft -lt 0) { 'EXPIRED' }
                         elseif ($daysLeft -lt 30) { 'WARNING: Expires within 30 days' }
                         elseif ($daysLeft -lt 90) { 'INFO: Expires within 90 days' }
                         else { 'OK' }
        }
    } | Sort-Object DaysLeft | Format-Table -AutoSize
} else {
    Write-Host "No certificates in LocalMachine\My store."
}
#endregion

#region Section 7: VBS and Credential Guard
Write-Host "$sep"
Write-Host " SECTION 7 - Virtualization-Based Security Status"
Write-Host $sep

try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
    [PSCustomObject]@{
        VBSStatus                = switch ($dg.VirtualizationBasedSecurityStatus) { 0 {'Off'} 1 {'Configured'} 2 {'Running'} }
        CredentialGuard          = if ($dg.SecurityServicesRunning -band 1) { 'Running' } else { 'Not running' }
        HVCI                     = if ($dg.SecurityServicesRunning -band 2) { 'Running' } else { 'Not running' }
        SecureBoot               = if ($dg.AvailableSecurityProperties -band 1) { 'Available' } else { 'Not available' }
    } | Format-List
} catch {
    Write-Host "DeviceGuard WMI class not available on this system."
}
#endregion

Write-Host "`n$sep"
Write-Host " Security Audit Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "$sep`n"
