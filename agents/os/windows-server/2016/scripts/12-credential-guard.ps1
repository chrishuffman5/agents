<#
.SYNOPSIS
    Windows Server 2016 - Credential Guard and VBS Status
.DESCRIPTION
    Checks Virtualization-Based Security, Credential Guard, HVCI,
    Secure Boot, and TPM status. Identifies configuration gaps for
    hardware-backed security features introduced in Server 2016.
.NOTES
    Version : 2016.1.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. VBS and Credential Guard Status
        2. Secure Boot Status
        3. TPM Status
        4. HVCI Configuration
        5. Credential Guard Registry Settings
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

Write-Host "`n$sep"
Write-Host " Credential Guard and VBS Status - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host $sep

#region Section 1: VBS Status
Write-Host "`n--- Section 1: VBS and Credential Guard ---"
try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
    [PSCustomObject]@{
        VBSStatus          = switch ($dg.VirtualizationBasedSecurityStatus) { 0 {'Off'} 1 {'Configured'} 2 {'Running'} }
        CredentialGuard    = if ($dg.SecurityServicesRunning -band 1) { 'Running' } else { 'Not running' }
        HVCI               = if ($dg.SecurityServicesRunning -band 2) { 'Running' } else { 'Not running' }
        ConfiguredServices = $dg.SecurityServicesConfigured -join ', '
    } | Format-List
} catch { Write-Warning "DeviceGuard WMI class not available." }
#endregion

#region Section 2: Secure Boot
Write-Host "--- Section 2: Secure Boot ---"
try {
    $sb = Confirm-SecureBootUEFI -ErrorAction Stop
    Write-Host "Secure Boot: $(if ($sb) {'Enabled'} else {'Disabled'})"
} catch { Write-Host "Secure Boot: Cannot determine (may be BIOS, not UEFI)." }
#endregion

#region Section 3: TPM
Write-Host "`n--- Section 3: TPM Status ---"
try {
    $tpm = Get-Tpm -ErrorAction Stop
    [PSCustomObject]@{
        TpmPresent = $tpm.TpmPresent; TpmReady = $tpm.TpmReady; TpmEnabled = $tpm.TpmEnabled
    } | Format-List
    $tpmVer = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftTpm -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    if ($tpmVer) { Write-Host "TPM Spec Version: $($tpmVer.SpecVersion)" }
} catch { Write-Host "TPM not available or not accessible." }
#endregion

#region Section 4: HVCI
Write-Host "--- Section 4: HVCI Configuration ---"
$hvciPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
if (Test-Path $hvciPath) {
    $hvci = Get-ItemProperty -Path $hvciPath -ErrorAction SilentlyContinue
    Write-Host "HVCI Enabled (registry): $($hvci.Enabled)"
} else { Write-Host "HVCI registry key not present (not configured)." }
#endregion

#region Section 5: Registry Settings
Write-Host "`n--- Section 5: Credential Guard Registry ---"
$dgPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
if (Test-Path $dgPath) {
    $dgReg = Get-ItemProperty -Path $dgPath -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        EnableVBS = $dgReg.EnableVirtualizationBasedSecurity
        RequirePlatformSecurityFeatures = $dgReg.RequirePlatformSecurityFeatures
        LsaCfgFlags = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name LsaCfgFlags -ErrorAction SilentlyContinue).LsaCfgFlags
    } | Format-List
} else { Write-Host "DeviceGuard registry not configured." }
#endregion

Write-Host "`n$sep"
Write-Host " Credential Guard Check Complete"
Write-Host "$sep`n"
