<#
.SYNOPSIS
    Windows Client - Network Diagnostics
.DESCRIPTION
    Comprehensive network assessment: adapter inventory (Wi-Fi and Ethernet),
    IP/DNS configuration, connected network profiles, VPN connections,
    proxy settings, and active external TCP connections with owning process.
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Network Adapters (Wi-Fi and Ethernet)
        2. IP and DNS Configuration
        3. Connected Networks and Profiles
        4. VPN Connections
        5. Proxy Settings
        6. Active Connections and Firewall Rules
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: Network Adapters
Write-Host "`n$sep`n SECTION 1 - Network Adapters`n$sep"

Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, MediaType,
    LinkSpeed, MacAddress, DriverVersion,
    @{N='Assessment';E={
        if ($_.Status -eq 'Up') { 'Connected' }
        elseif ($_.Status -eq 'Disconnected') { 'Not connected' }
        else { $_.Status }
    }} | Format-Table -AutoSize

# Wi-Fi specific info
$wifi = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wi-Fi|Wireless|802.11|WLAN' }
if ($wifi) {
    Write-Host "`nWi-Fi Details:"
    netsh wlan show interfaces 2>&1 | Where-Object { $_ -match 'SSID|Signal|Radio|Channel|State|Authentication' } |
        ForEach-Object { Write-Host "  $_" }
}
#endregion

#region Section 2: IP and DNS Configuration
Write-Host "$sep`n SECTION 2 - IP and DNS Configuration`n$sep"

Get-NetIPConfiguration | ForEach-Object {
    [PSCustomObject]@{
        Interface    = $_.InterfaceAlias
        IPv4         = $_.IPv4Address.IPAddress -join ', '
        IPv4Prefix   = $_.IPv4Address.PrefixLength -join ', '
        Gateway      = $_.IPv4DefaultGateway.NextHop -join ', '
        DNS          = $_.DNSServer.ServerAddresses -join ', '
        IPv6         = $_.IPv6Address.IPAddress -join ', '
    }
} | Format-Table -AutoSize

Write-Host "`nDNS suffix search list:"
(Get-DnsClientGlobalSetting).SuffixSearchList | ForEach-Object { Write-Host "  $_" }

Write-Host "`nDNS connectivity test:"
try {
    $dnsTest = Resolve-DnsName -Name "www.microsoft.com" -Type A -ErrorAction Stop | Select-Object -First 1
    Write-Host "  DNS resolution OK: www.microsoft.com -> $($dnsTest.IPAddress)"
} catch {
    Write-Warning "DNS resolution failed: $($_.Exception.Message)"
}
#endregion

#region Section 3: Connected Networks and Profiles
Write-Host "$sep`n SECTION 3 - Connected Networks and Profiles`n$sep"

Get-NetConnectionProfile | Select-Object Name, NetworkCategory, IPv4Connectivity,
    IPv6Connectivity, InterfaceAlias | Format-Table -AutoSize

Write-Host "`nNetwork Adapter Statistics:"
Get-NetAdapterStatistics | Select-Object Name,
    @{N='ReceivedMB';E={[math]::Round($_.ReceivedBytes/1MB,1)}},
    @{N='SentMB';E={[math]::Round($_.SentBytes/1MB,1)}},
    ReceivedUnicastPackets, SentUnicastPackets,
    @{N='RecvErrors';E={$_.ReceivedDiscardedPackets + $_.ReceivedPacketErrors}} |
    Where-Object { $_.ReceivedMB -gt 0 } | Format-Table -AutoSize
#endregion

#region Section 4: VPN Connections
Write-Host "$sep`n SECTION 4 - VPN Connections`n$sep"

$vpnConns = Get-VpnConnection -ErrorAction SilentlyContinue
if ($vpnConns) {
    $vpnConns | Select-Object Name, ServerAddress, TunnelType, AuthenticationMethod,
        EncryptionLevel, ConnectionStatus, SplitTunneling | Format-Table -AutoSize
} else {
    Write-Host "No VPN connections configured."
}

# Also check for Always On VPN (device tunnel)
$vpnDevice = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue
if ($vpnDevice) {
    Write-Host "All-user VPN connections:"
    $vpnDevice | Select-Object Name, ServerAddress, ConnectionStatus | Format-Table -AutoSize
}
#endregion

#region Section 5: Proxy Settings
Write-Host "$sep`n SECTION 5 - Proxy Settings`n$sep"

$proxyReg = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
[PSCustomObject]@{
    ProxyEnabled   = [bool]$proxyReg.ProxyEnable
    ProxyServer    = $proxyReg.ProxyServer
    ProxyOverride  = $proxyReg.ProxyOverride
    AutoConfigURL  = $proxyReg.AutoConfigURL
} | Format-List

# WINHTTP proxy (used by system/services)
Write-Host "WinHTTP system proxy:"
netsh winhttp show proxy 2>&1 | ForEach-Object { Write-Host "  $_" }
#endregion

#region Section 6: Active Connections
Write-Host "$sep`n SECTION 6 - Active External TCP Connections`n$sep"

Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
    Where-Object { $_.RemoteAddress -ne '127.0.0.1' -and $_.RemoteAddress -ne '::1' } |
    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort,
        @{N='Process';E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name}},
        @{N='PID';E={$_.OwningProcess}} |
    Sort-Object Process | Format-Table -AutoSize
#endregion

Write-Host "`n$sep`n Network Diagnostics Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
