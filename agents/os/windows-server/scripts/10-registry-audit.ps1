<#
.SYNOPSIS
    Windows Server - Registry Security Settings Audit
.DESCRIPTION
    Audits key security-related registry settings including RDP configuration,
    SMB settings, TLS protocol status, LSA protection, and common hardening
    indicators. Compares against CIS/STIG recommended values.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. RDP Configuration
        2. SMB Protocol Settings
        3. TLS Protocol Status
        4. LSA Security Settings
        5. Windows Firewall Logging
        6. Miscellaneous Security Settings
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

function Get-RegValue {
    param([string]$Path, [string]$Name, [string]$Default = 'Not set')
    try {
        $val = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $val.$Name
    } catch {
        return $Default
    }
}

Write-Host "`n$sep"
Write-Host " Registry Security Audit - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host $sep

#region Section 1: RDP Configuration
Write-Host "`n$sep"
Write-Host " SECTION 1 - RDP Configuration"
Write-Host $sep

$rdpBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$rdpWin = "$rdpBase\WinStations\RDP-Tcp"

$rdpEnabled = Get-RegValue $rdpBase 'fDenyTSConnections' 'Not set'
$nla = Get-RegValue $rdpWin 'UserAuthentication' 'Not set'
$secLayer = Get-RegValue $rdpWin 'SecurityLayer' 'Not set'
$minEncrypt = Get-RegValue $rdpWin 'MinEncryptionLevel' 'Not set'

[PSCustomObject]@{
    Setting           = 'RDP Enabled'
    Value             = if ($rdpEnabled -eq 0) { 'Yes (fDenyTSConnections=0)' } elseif ($rdpEnabled -eq 1) { 'No (Disabled)' } else { $rdpEnabled }
    Recommended       = 'Disable if not needed'
},
[PSCustomObject]@{
    Setting           = 'NLA Required'
    Value             = if ($nla -eq 1) { 'Yes' } elseif ($nla -eq 0) { 'No' } else { $nla }
    Recommended       = 'Yes (1)'
},
[PSCustomObject]@{
    Setting           = 'Security Layer'
    Value             = switch ($secLayer) { 0 {'RDP (native)'} 1 {'Negotiate'} 2 {'TLS (SSL)'} default { $secLayer } }
    Recommended       = 'TLS (2)'
},
[PSCustomObject]@{
    Setting           = 'Min Encryption Level'
    Value             = switch ($minEncrypt) { 1 {'Low'} 2 {'Client Compatible'} 3 {'High'} 4 {'FIPS'} default { $minEncrypt } }
    Recommended       = 'High (3) or FIPS (4)'
} | Format-Table -AutoSize
#endregion

#region Section 2: SMB Protocol Settings
Write-Host "$sep"
Write-Host " SECTION 2 - SMB Protocol Settings"
Write-Host $sep

$smbServerPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
$smb1 = Get-RegValue $smbServerPath 'SMB1' 'Not set (default enabled on 2016/2019)'
$requireSigning = Get-RegValue $smbServerPath 'RequireSecuritySignature' 'Not set'
$encryptData = Get-RegValue $smbServerPath 'EncryptData' 'Not set'

[PSCustomObject]@{
    Setting      = 'SMBv1 (Server)'
    Value        = $smb1
    Recommended  = '0 (Disabled)'
    Assessment   = if ($smb1 -eq 0) { 'OK' } else { 'WARNING: SMBv1 may be enabled' }
},
[PSCustomObject]@{
    Setting      = 'Require Signing'
    Value        = $requireSigning
    Recommended  = '1 (Required)'
    Assessment   = if ($requireSigning -eq 1) { 'OK' } else { 'WARNING: Signing not required' }
},
[PSCustomObject]@{
    Setting      = 'Encrypt Data'
    Value        = $encryptData
    Recommended  = '1 (Enabled) for sensitive shares'
    Assessment   = 'INFO'
} | Format-Table -AutoSize
#endregion

#region Section 3: TLS Protocol Status
Write-Host "$sep"
Write-Host " SECTION 3 - TLS Protocol Status"
Write-Host $sep

$protocols = @('SSL 2.0', 'SSL 3.0', 'TLS 1.0', 'TLS 1.1', 'TLS 1.2', 'TLS 1.3')
$schannelBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

foreach ($proto in $protocols) {
    $serverEnabled = Get-RegValue "$schannelBase\$proto\Server" 'Enabled' 'Not set (OS default)'
    $serverDisabledByDefault = Get-RegValue "$schannelBase\$proto\Server" 'DisabledByDefault' 'Not set'

    $recommended = switch ($proto) {
        'SSL 2.0'  { 'Disabled (0)' }
        'SSL 3.0'  { 'Disabled (0)' }
        'TLS 1.0'  { 'Disabled (0)' }
        'TLS 1.1'  { 'Disabled (0)' }
        'TLS 1.2'  { 'Enabled (1)' }
        'TLS 1.3'  { 'Enabled (1) on 2022+' }
    }

    $assessment = if ($proto -in @('SSL 2.0','SSL 3.0','TLS 1.0','TLS 1.1') -and $serverEnabled -eq 1) { 'WARNING: Should be disabled' }
                  elseif ($proto -eq 'TLS 1.2' -and $serverEnabled -eq 0) { 'WARNING: TLS 1.2 disabled' }
                  else { 'OK / Default' }

    [PSCustomObject]@{
        Protocol     = $proto
        ServerEnabled = $serverEnabled
        DisabledByDefault = $serverDisabledByDefault
        Recommended  = $recommended
        Assessment   = $assessment
    }
} | Format-Table -AutoSize
#endregion

#region Section 4: LSA Security Settings
Write-Host "$sep"
Write-Host " SECTION 4 - LSA Security Settings"
Write-Host $sep

$lsaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'

$runAsPPL = Get-RegValue $lsaPath 'RunAsPPL' 'Not set'
$lmCompat = Get-RegValue $lsaPath 'LmCompatibilityLevel' 'Not set'
$noLMHash = Get-RegValue $lsaPath 'NoLMHash' 'Not set'
$restrictAnon = Get-RegValue $lsaPath 'RestrictAnonymous' 'Not set'
$restrictAnonSAM = Get-RegValue $lsaPath 'RestrictAnonymousSAM' 'Not set'

[PSCustomObject]@{
    Setting      = 'LSASS RunAsPPL (Protected Process)'
    Value        = $runAsPPL
    Recommended  = '1 (Enabled)'
    Assessment   = if ($runAsPPL -eq 1) { 'OK' } else { 'WARNING: LSASS not running as PPL' }
},
[PSCustomObject]@{
    Setting      = 'LM Compatibility Level'
    Value        = $lmCompat
    Recommended  = '5 (Send NTLMv2 only, refuse LM/NTLM)'
    Assessment   = if ($lmCompat -ge 3) { 'OK' } else { 'WARNING: Weak NTLM auth may be allowed' }
},
[PSCustomObject]@{
    Setting      = 'NoLMHash'
    Value        = $noLMHash
    Recommended  = '1 (Do not store LM hash)'
    Assessment   = if ($noLMHash -eq 1) { 'OK' } else { 'WARNING' }
},
[PSCustomObject]@{
    Setting      = 'RestrictAnonymous'
    Value        = $restrictAnon
    Recommended  = '1 or 2'
    Assessment   = if ($restrictAnon -ge 1) { 'OK' } else { 'WARNING' }
},
[PSCustomObject]@{
    Setting      = 'RestrictAnonymousSAM'
    Value        = $restrictAnonSAM
    Recommended  = '1'
    Assessment   = if ($restrictAnonSAM -eq 1) { 'OK' } else { 'WARNING' }
} | Format-Table -AutoSize
#endregion

#region Section 5: Firewall Logging
Write-Host "$sep"
Write-Host " SECTION 5 - Windows Firewall Logging"
Write-Host $sep

Get-NetFirewallProfile | ForEach-Object {
    [PSCustomObject]@{
        Profile          = $_.Name
        LogAllowed       = $_.LogAllowed
        LogBlocked       = $_.LogBlocked
        LogFileName      = $_.LogFileName
        LogMaxSizeKB     = $_.LogMaxSizeKilobytes
        Assessment       = if (-not $_.LogBlocked) { 'WARNING: Blocked traffic not logged' } else { 'OK' }
    }
} | Format-Table -AutoSize
#endregion

#region Section 6: Miscellaneous Security Settings
Write-Host "$sep"
Write-Host " SECTION 6 - Miscellaneous Security Settings"
Write-Host $sep

$autoRun = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun' 'Not set'
$wDigest = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' 'UseLogonCredential' 'Not set'
$dep = (bcdedit /enum | Select-String 'nx').ToString().Trim() -replace '.*\s+', ''

[PSCustomObject]@{
    Setting      = 'AutoRun Disabled'
    Value        = $autoRun
    Recommended  = '255 (All drives)'
    Assessment   = if ($autoRun -eq 255) { 'OK' } else { 'WARNING: AutoRun may be enabled' }
},
[PSCustomObject]@{
    Setting      = 'WDigest UseLogonCredential'
    Value        = $wDigest
    Recommended  = '0 or Not set (plaintext passwords not cached)'
    Assessment   = if ($wDigest -eq 1) { 'CRITICAL: Plaintext creds cached in LSASS' } else { 'OK' }
},
[PSCustomObject]@{
    Setting      = 'DEP/NX Policy'
    Value        = $dep
    Recommended  = 'OptOut or AlwaysOn'
    Assessment   = if ($dep -in @('OptOut', 'AlwaysOn')) { 'OK' } else { 'WARNING' }
} | Format-Table -AutoSize
#endregion

Write-Host "`n$sep"
Write-Host " Registry Security Audit Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "$sep`n"
