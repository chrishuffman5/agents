<#
.SYNOPSIS
    Windows Server - Network Diagnostics
.DESCRIPTION
    Audits network adapter configuration, IP settings, DNS resolution,
    firewall profile status, active connections, and listening ports.
    Identifies misconfigured adapters and connectivity issues.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Network Adapter Status
        2. IP Configuration
        3. DNS Client Configuration
        4. Firewall Profile Status
        5. Active TCP Connections Summary
        6. Listening Ports with Owning Process
        7. SMB Configuration
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

Write-Host "`n$sep"
Write-Host " Network Diagnostics - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host $sep

#region Section 1: Network Adapter Status
Write-Host "`n$sep"
Write-Host " SECTION 1 - Network Adapter Status"
Write-Host $sep

Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed,
    MacAddress, MediaType, DriverVersion | Format-Table -AutoSize

$downAdapters = Get-NetAdapter | Where-Object Status -ne 'Up'
if ($downAdapters) {
    Write-Warning "Adapters not in 'Up' state:"
    $downAdapters | Select-Object Name, Status | Format-Table -AutoSize
}
#endregion

#region Section 2: IP Configuration
Write-Host "$sep"
Write-Host " SECTION 2 - IP Configuration"
Write-Host $sep

Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike 'Loopback*' } |
    Select-Object InterfaceAlias, IPAddress, PrefixLength, AddressState | Format-Table -AutoSize

Get-NetRoute -AddressFamily IPv4 | Where-Object DestinationPrefix -eq '0.0.0.0/0' |
    Select-Object InterfaceAlias, NextHop, RouteMetric | Format-Table -AutoSize
#endregion

#region Section 3: DNS Client Configuration
Write-Host "$sep"
Write-Host " SECTION 3 - DNS Client Configuration"
Write-Host $sep

Get-DnsClientServerAddress -AddressFamily IPv4 |
    Where-Object { $_.ServerAddresses.Count -gt 0 } |
    Select-Object InterfaceAlias, @{N='DNSServers';E={$_.ServerAddresses -join ', '}} | Format-Table -AutoSize

# Test DNS resolution
$testNames = @('localhost')
foreach ($name in $testNames) {
    try {
        $result = Resolve-DnsName $name -ErrorAction Stop | Select-Object -First 1
        Write-Host "DNS test '$name': Resolved to $($result.IPAddress) -- OK"
    } catch {
        Write-Warning "DNS test '$name': FAILED -- $($_.Exception.Message)"
    }
}
#endregion

#region Section 4: Firewall Profile Status
Write-Host "`n$sep"
Write-Host " SECTION 4 - Firewall Profile Status"
Write-Host $sep

Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction,
    DefaultOutboundAction, LogFileName, @{N='LogMaxKB';E={$_.LogMaxSizeKilobytes}} | Format-Table -AutoSize

$disabledProfiles = Get-NetFirewallProfile | Where-Object Enabled -eq $false
if ($disabledProfiles) {
    Write-Warning "Firewall profiles DISABLED: $($disabledProfiles.Name -join ', '). Enable for security."
}
#endregion

#region Section 5: Active TCP Connections Summary
Write-Host "$sep"
Write-Host " SECTION 5 - Active TCP Connections Summary"
Write-Host $sep

$connections = Get-NetTCPConnection -ErrorAction SilentlyContinue
$connections | Group-Object State | Sort-Object Count -Descending |
    Select-Object Count, Name | Format-Table -AutoSize

$established = ($connections | Where-Object State -eq 'Established').Count
Write-Host "Total established connections: $established"
#endregion

#region Section 6: Listening Ports
Write-Host "`n$sep"
Write-Host " SECTION 6 - Listening Ports with Owning Process (Top 25)"
Write-Host $sep

Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Select-Object LocalPort, OwningProcess,
        @{N='ProcessName';E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name}} |
    Sort-Object LocalPort | Select-Object -First 25 | Format-Table -AutoSize
#endregion

#region Section 7: SMB Configuration
Write-Host "$sep"
Write-Host " SECTION 7 - SMB Configuration"
Write-Host $sep

$smbConfig = Get-SmbServerConfiguration -ErrorAction SilentlyContinue
if ($smbConfig) {
    [PSCustomObject]@{
        SMBv1Enabled      = $smbConfig.EnableSMB1Protocol
        SMBv2Enabled      = $smbConfig.EnableSMB2Protocol
        RequireSigning    = $smbConfig.RequireSecuritySignature
        EncryptData       = $smbConfig.EncryptData
        SMBv1Assessment   = if ($smbConfig.EnableSMB1Protocol) { 'CRITICAL: SMBv1 is enabled -- disable immediately' } else { 'OK: SMBv1 disabled' }
        SigningAssessment = if (-not $smbConfig.RequireSecuritySignature) { 'WARNING: SMB signing not required' } else { 'OK' }
    } | Format-List
} else {
    Write-Host "SMB Server configuration not available."
}
#endregion

Write-Host "`n$sep"
Write-Host " Network Diagnostics Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "$sep`n"
