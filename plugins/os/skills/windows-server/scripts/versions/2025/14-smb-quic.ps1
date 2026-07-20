<#
.SYNOPSIS
    Windows Server 2025 - SMB over QUIC Status
.DESCRIPTION
    Checks SMB over QUIC configuration, certificate mappings, firewall
    rules, and active QUIC connections. All editions in 2025.
.NOTES
    Version : 2025.1.0
    Targets : Windows Server 2025+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. SMB QUIC Server Configuration
        2. Certificate Mappings
        3. Firewall Rules for UDP 443
        4. Active SMB Connections (QUIC)
        5. SMB Server Network Interfaces
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n SMB over QUIC Status (Server 2025)`n$sep"

Write-Host "`n--- Section 1: SMB QUIC Configuration ---"
$cfg = Get-SmbServerConfiguration -EA SilentlyContinue
if ($cfg) {
    Write-Host "EnableSMBQUIC: $($cfg.EnableSMBQUIC)"
    Write-Host "RequireSecuritySignature: $($cfg.RequireSecuritySignature)"
    Write-Host "EncryptData: $($cfg.EncryptData)"
} else { Write-Warning "Cannot read SMB configuration." }

Write-Host "`n--- Section 2: Certificate Mappings ---"
$mappings = Get-SmbServerCertificateMapping -EA SilentlyContinue
if ($mappings) {
    $mappings | Select-Object Name, Subject, Thumbprint, StoreName, DisplayName | Format-Table -AutoSize
} else {
    Write-Warning "No SMB over QUIC certificate mappings found."
    Write-Host "Configure: New-SmbServerCertificateMapping -Name 'QuicCert' -Thumbprint '<thumb>' -StoreName 'My' -Subject '<FQDN>'"
}

Write-Host "--- Section 3: Firewall Rules (UDP 443) ---"
$quicRules = Get-NetFirewallRule -EA SilentlyContinue | Where-Object {
    $_.Enabled -eq $true -and $_.Direction -eq 'Inbound'
} | Get-NetFirewallPortFilter -EA SilentlyContinue | Where-Object {
    $_.Protocol -eq 'UDP' -and $_.LocalPort -eq 443
}
if ($quicRules) { Write-Host "UDP 443 inbound rule found. OK." }
else { Write-Warning "No UDP 443 inbound rule -- SMB over QUIC connections will be blocked." }

Write-Host "`n--- Section 4: Active SMB Connections ---"
$connections = Get-SmbConnection -EA SilentlyContinue
if ($connections) {
    $connections | Select-Object ServerName, ShareName, Dialect, UserName | Format-Table -AutoSize
    $quicConns = $connections | Where-Object { $_.TransportType -eq 'QUIC' }
    Write-Host "QUIC connections: $($quicConns.Count)"
} else { Write-Host "No active SMB connections." }

Write-Host "--- Section 5: SMB Network Interfaces ---"
Get-SmbServerNetworkInterface -EA SilentlyContinue |
    Select-Object InterfaceIndex, IpAddress, FriendlyName | Format-Table -AutoSize
Write-Host "`n$sep`n SMB over QUIC Check Complete`n$sep"
