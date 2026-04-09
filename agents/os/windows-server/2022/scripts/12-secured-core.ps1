<#
.SYNOPSIS
    Windows Server 2022 - Secured-Core Server Assessment
.DESCRIPTION
    Evaluates all Secured-core components: VBS, HVCI, Credential Guard,
    System Guard Secure Launch, TPM 2.0, and Secure Boot status.
.NOTES
    Version : 2022.1.0
    Targets : Windows Server 2022+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. VBS and Security Services
        2. HVCI Status
        3. System Guard Secure Launch (DRTM)
        4. Secure Boot and TPM
        5. Overall Secured-Core Assessment
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n Secured-Core Server Assessment`n$sep"

$score = 0; $maxScore = 5

# Section 1: VBS
Write-Host "`n--- VBS and Security Services ---"
try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -EA Stop
    $vbsRunning = $dg.VirtualizationBasedSecurityStatus -eq 2
    $cgRunning = ($dg.SecurityServicesRunning -band 1) -ne 0
    $hvciRunning = ($dg.SecurityServicesRunning -band 2) -ne 0
    $sgRunning = ($dg.SecurityServicesRunning -band 4) -ne 0
    Write-Host "VBS: $(if($vbsRunning){'Running'}else{'Not running'})"
    Write-Host "Credential Guard: $(if($cgRunning){'Running'}else{'Not running'})"
    Write-Host "HVCI: $(if($hvciRunning){'Running'}else{'Not running'})"
    Write-Host "System Guard Secure Launch: $(if($sgRunning){'Running'}else{'Not running'})"
    if ($vbsRunning) { $score++ }
    if ($cgRunning) { $score++ }
    if ($hvciRunning) { $score++ }
} catch { Write-Warning "DeviceGuard WMI not available." }

# Section 2: Secure Boot
Write-Host "`n--- Secure Boot ---"
try {
    $sb = Confirm-SecureBootUEFI -EA Stop
    Write-Host "Secure Boot: $(if($sb){'Enabled'}else{'Disabled'})"
    if ($sb) { $score++ }
} catch { Write-Host "Secure Boot: Cannot determine" }

# Section 3: TPM
Write-Host "`n--- TPM ---"
try {
    $tpm = Get-Tpm -EA Stop
    Write-Host "TPM Present: $($tpm.TpmPresent) | Ready: $($tpm.TpmReady)"
    $tpmVer = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftTpm -ClassName Win32_Tpm -EA SilentlyContinue
    if ($tpmVer) { Write-Host "TPM Version: $($tpmVer.SpecVersion)" }
    if ($tpm.TpmPresent -and $tpm.TpmReady) { $score++ }
} catch { Write-Host "TPM not accessible." }

# Overall
Write-Host "`n--- Secured-Core Assessment ---"
Write-Host "Score: $score / $maxScore"
$assessment = switch ($score) {
    5 { 'SECURED-CORE COMPLIANT: All components running' }
    {$_ -ge 3} { 'PARTIAL: Some Secured-core components missing' }
    default { 'NOT COMPLIANT: Enable VBS, HVCI, TPM 2.0, and Secure Boot' }
}
Write-Host "Assessment: $assessment"
Write-Host "`n$sep`n Secured-Core Assessment Complete`n$sep"
