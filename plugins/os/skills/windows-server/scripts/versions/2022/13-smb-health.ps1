<#
.SYNOPSIS
    Windows Server 2022 - SMB Health and Security Assessment
.DESCRIPTION
    Audits SMB compression, encryption (AES-256), signing, QUIC status,
    active sessions, and protocol configuration introduced in Server 2022.
.NOTES
    Version : 2022.1.0
    Targets : Windows Server 2022+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. SMB Server Configuration
        2. SMB Encryption Settings
        3. SMB Compression Status
        4. SMB over QUIC Status
        5. Active SMB Sessions
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n SMB Health Assessment (Server 2022)`n$sep"

Write-Host "`n--- Section 1: SMB Server Configuration ---"
$cfg = Get-SmbServerConfiguration -EA SilentlyContinue
if ($cfg) {
    [PSCustomObject]@{
        SMBv1 = $cfg.EnableSMB1Protocol; SMBv2 = $cfg.EnableSMB2Protocol
        RequireSigning = $cfg.RequireSecuritySignature; EncryptData = $cfg.EncryptData
        RejectUnencrypted = $cfg.RejectUnencryptedAccess
    } | Format-List
    if ($cfg.EnableSMB1Protocol) { Write-Warning "SMBv1 is ENABLED -- disable immediately." }
}

Write-Host "--- Section 2: Encryption Settings ---"
if ($cfg) {
    Write-Host "Encryption ciphers: $($cfg.EncryptionCiphers)"
    Write-Host "Recommendation: 'AES_256_GCM,AES_128_GCM' for strongest encryption."
}

Write-Host "`n--- Section 3: Compression Status ---"
if ($cfg) {
    Write-Host "Server compression: $(if($cfg.EnableSmbCompression){'Enabled'}else{'Disabled'})"
    $clientCfg = Get-SmbClientConfiguration -EA SilentlyContinue
    Write-Host "Client compression: $(if($clientCfg.EnableSmbCompression){'Enabled'}else{'Disabled'})"
}

Write-Host "`n--- Section 4: SMB over QUIC ---"
$quicMappings = Get-SmbServerCertificateMapping -EA SilentlyContinue
if ($quicMappings) {
    Write-Host "SMB over QUIC certificate mappings:"
    $quicMappings | Select-Object Name, Subject, Thumbprint, StoreName | Format-Table -AutoSize
} else {
    $edition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue).EditionID
    if ($edition -match 'Azure') { Write-Host "Azure Edition detected but no QUIC mapping configured." }
    else { Write-Host "SMB over QUIC: Not available (Azure Edition only in 2022)." }
}

Write-Host "--- Section 5: Active SMB Sessions ---"
$sessions = Get-SmbSession -EA SilentlyContinue
Write-Host "Active sessions: $($sessions.Count)"
if ($sessions) {
    $sessions | Select-Object -First 10 ClientComputerName, ClientUserName, Dialect, NumOpens | Format-Table -AutoSize
}
Write-Host "`n$sep`n SMB Health Complete`n$sep"
