<#
.SYNOPSIS
    Windows Client - Security Posture Assessment
.DESCRIPTION
    Evaluates desktop security configuration: Microsoft Defender AV status,
    Windows Firewall profiles, BitLocker encryption on all volumes,
    Credential Guard and VBS status, Exploit Protection settings, and
    Attack Surface Reduction rule configuration.
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Microsoft Defender Antivirus Status
        2. Firewall Profile Status
        3. BitLocker Status (All Volumes)
        4. Credential Guard and VBS
        5. Exploit Protection Settings
        6. ASR Rules Status
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: Microsoft Defender AV Status
Write-Host "`n$sep`n SECTION 1 - Microsoft Defender Antivirus`n$sep"

try {
    $defStatus = Get-MpComputerStatus -ErrorAction Stop
    [PSCustomObject]@{
        AMRunningMode             = $defStatus.AMRunningMode
        RealTimeProtectionEnabled = $defStatus.RealTimeProtectionEnabled
        AntivirusEnabled          = $defStatus.AntivirusEnabled
        AntispywareEnabled        = $defStatus.AntispywareEnabled
        BehaviorMonitorEnabled    = $defStatus.BehaviorMonitorEnabled
        IoavProtectionEnabled     = $defStatus.IoavProtectionEnabled
        NISEnabled                = $defStatus.NISEnabled
        OnAccessProtectionEnabled = $defStatus.OnAccessProtectionEnabled
        AntivirusSignatureVersion = $defStatus.AntivirusSignatureVersion
        AntivirusSigAge_Days      = $defStatus.AntivirusSignatureAge
        LastQuickScanDate         = $defStatus.QuickScanStartTime
        LastFullScanDate          = $defStatus.FullScanStartTime
        TamperProtectionSource    = $defStatus.TamperProtectionSource
        Assessment                = if (-not $defStatus.RealTimeProtectionEnabled) { 'CRITICAL: Real-time protection OFF' }
                                    elseif ($defStatus.AntivirusSignatureAge -gt 7) { 'WARNING: Definitions older than 7 days' }
                                    else { 'OK' }
    } | Format-List
} catch {
    Write-Warning "Defender Get-MpComputerStatus failed: $($_.Exception.Message)"
}

Write-Host "Active Threats:"
Get-MpThreatDetection -ErrorAction SilentlyContinue |
    Select-Object -First 10 ThreatName, ActionSuccess, InitialDetectionTime, RemediationTime |
    Format-Table -AutoSize
#endregion

#region Section 2: Firewall Profile Status
Write-Host "$sep`n SECTION 2 - Windows Firewall Profiles`n$sep"

Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction,
    LogAllowed, LogBlocked, LogFileName | Format-Table -AutoSize

# Count rules per profile
Write-Host "Firewall rule counts:"
foreach ($profile in @('Domain','Private','Public')) {
    $count = (Get-NetFirewallRule -Enabled True -Direction Inbound -ErrorAction SilentlyContinue |
        Where-Object { $_.Profile -match $profile -or $_.Profile -eq 'Any' }).Count
    Write-Host "  $profile inbound enabled: $count"
}
#endregion

#region Section 3: BitLocker Status
Write-Host "$sep`n SECTION 3 - BitLocker Status (All Volumes)`n$sep"

$blVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
if ($blVolumes) {
    $blVolumes | Select-Object MountPoint, VolumeType, VolumeStatus, ProtectionStatus,
        EncryptionMethod, EncryptionPercentage, LockStatus,
        @{N='KeyProtectors';E={($_.KeyProtector | ForEach-Object { $_.KeyProtectorType }) -join ', '}} |
        Format-Table -AutoSize

    foreach ($vol in $blVolumes) {
        if ($vol.VolumeType -eq 'OperatingSystem' -and $vol.ProtectionStatus -ne 'On') {
            Write-Warning "OS drive ($($vol.MountPoint)) is NOT BitLocker protected."
        }
        if ($vol.KeyProtector.Count -eq 0) {
            Write-Warning "Volume $($vol.MountPoint) has no key protectors -- recovery may be impossible."
        }
    }
} else {
    Write-Host "BitLocker cmdlets not available or no volumes to report."
    # Fallback
    manage-bde -status 2>&1 | Select-String -Pattern 'Conversion Status|Protection Status|Key Protectors'
}
#endregion

#region Section 4: Credential Guard and VBS
Write-Host "$sep`n SECTION 4 - Credential Guard and Virtualization-Based Security`n$sep"

try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
    [PSCustomObject]@{
        VBSStatus              = switch ($dg.VirtualizationBasedSecurityStatus) { 0{'Off'} 1{'Configured, not running'} 2{'Running'} }
        CredentialGuard        = if ($dg.SecurityServicesRunning -band 1) { 'Running' } else { 'Not Running' }
        HVCI                   = if ($dg.SecurityServicesRunning -band 2) { 'Running' } else { 'Not Running' }
        SecureBootAvailable    = if ($dg.AvailableSecurityProperties -band 2) { 'Yes' } else { 'No' }
        TPMAvailable           = if ($dg.AvailableSecurityProperties -band 4) { 'Yes' } else { 'No' }
        Assessment             = if ($dg.VirtualizationBasedSecurityStatus -eq 0) { 'WARNING: VBS is off -- Credential Guard disabled' }
                                 elseif ($dg.SecurityServicesRunning -band 1) { 'OK: Credential Guard running' }
                                 else { 'INFO: VBS configured but Credential Guard not running' }
    } | Format-List
} catch {
    Write-Warning "DeviceGuard WMI unavailable: $($_.Exception.Message)"
}
#endregion

#region Section 5: Exploit Protection
Write-Host "$sep`n SECTION 5 - Exploit Protection (System-Level)`n$sep"

try {
    $ep = Get-ProcessMitigation -System -ErrorAction Stop
    [PSCustomObject]@{
        CFG         = $ep.CFG.Enable
        SEHOP       = $ep.SEHOP.Enable
        DEP         = $ep.DEP.Enable
        ForceRelocate = $ep.ASLR.ForceRelocateImages
        BottomUpASLR  = $ep.ASLR.BottomUp
    } | Format-List
} catch {
    Write-Warning "Get-ProcessMitigation not available: $($_.Exception.Message)"
}
#endregion

#region Section 6: ASR Rules Status
Write-Host "$sep`n SECTION 6 - Attack Surface Reduction Rules`n$sep"

try {
    $pref = Get-MpPreference -ErrorAction Stop
    $ids    = $pref.AttackSurfaceReductionRules_Ids
    $actions = $pref.AttackSurfaceReductionRules_Actions

    $asrNames = @{
        'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550' = 'Block executable content from email'
        'D4F940AB-401B-4EFC-AADC-AD5F3C50688A' = 'Block Office child processes'
        '3B576869-A4EC-4529-8536-B80A7769E899' = 'Block Office executable content'
        '75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84' = 'Block Office code injection'
        '5BEB7EFE-FD9A-4556-801D-275E5FFC04CC' = 'Block obfuscated script execution'
        '92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B' = 'Block Win32 API from Office macros'
    }

    if ($ids) {
        for ($i = 0; $i -lt $ids.Count; $i++) {
            [PSCustomObject]@{
                RuleName = if ($asrNames.ContainsKey($ids[$i])) { $asrNames[$ids[$i]] } else { $ids[$i] }
                Action   = switch ($actions[$i]) { 0{'Off'} 1{'Block'} 2{'Audit'} 6{'Warn'} }
            }
        } | Format-Table -AutoSize
    } else {
        Write-Host "No ASR rules configured via policy."
    }
} catch {
    Write-Warning "ASR rule query failed: $($_.Exception.Message)"
}
#endregion

Write-Host "`n$sep`n Security Posture Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
