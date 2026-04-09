<#
.SYNOPSIS
    Windows 10 - Windows 11 Upgrade Readiness Assessment
.DESCRIPTION
    Checks hardware compatibility for Windows 11: TPM version, Secure Boot,
    CPU model against Microsoft approved list, RAM, disk space, and UEFI
    boot mode. Also scans for driver compatibility issues and BitLocker
    recovery key backup status.
.NOTES
    Version : 10.1.0
    Targets : Windows 10 Enterprise / LTSC
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. UEFI and Secure Boot
        2. TPM Version Check
        3. CPU Compatibility
        4. RAM and Disk Space
        5. Driver Compatibility
        6. BitLocker Recovery Key Backup Status
        7. Overall Readiness Summary
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n Windows 11 Upgrade Readiness Assessment`n$sep"

$score = 0; $maxScore = 6
$issues = [System.Collections.Generic.List[string]]::new()

# --- Section 1: UEFI and Secure Boot ---
Write-Host "`n--- Section 1: UEFI and Secure Boot ---"
try {
    $secureBoot = Confirm-SecureBootUEFI -EA Stop
    Write-Host "Secure Boot: $(if($secureBoot){'Enabled (PASS)'}else{'Disabled (FAIL)'})"
    if ($secureBoot) { $score++ } else { $issues.Add('Secure Boot is disabled -- enable in UEFI firmware settings') }
} catch {
    Write-Host "Secure Boot: Cannot determine (likely Legacy BIOS / MBR boot)"
    $issues.Add('Secure Boot unavailable -- system may be using Legacy BIOS; UEFI required for Windows 11')
}

# Check UEFI boot mode via firmware environment
try {
    $firmware = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -EA Stop).PEFirmwareType
    $isUEFI = $firmware -eq 2
    Write-Host "Firmware Mode: $(if($isUEFI){'UEFI (PASS)'}else{'Legacy BIOS (FAIL)'})"
    if (-not $isUEFI) { $issues.Add('Legacy BIOS detected -- convert disk to GPT and enable UEFI for Windows 11') }
} catch {
    Write-Host "Firmware Mode: Cannot determine"
}

# --- Section 2: TPM Version Check ---
Write-Host "`n--- Section 2: TPM Version Check ---"
try {
    $tpm = Get-Tpm -EA Stop
    Write-Host "TPM Present:  $($tpm.TpmPresent)"
    Write-Host "TPM Ready:    $($tpm.TpmReady)"
    Write-Host "TPM Enabled:  $($tpm.TpmEnabled)"

    $tpmWmi = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftTpm -ClassName Win32_Tpm -EA SilentlyContinue
    if ($tpmWmi) {
        $specVer = $tpmWmi.SpecVersion
        Write-Host "TPM Spec:     $specVer"
        $isTpm2 = $specVer -match '^2\.'
        Write-Host "TPM 2.0:      $(if($isTpm2){'Yes (PASS)'}else{'No (FAIL) -- Windows 11 requires TPM 2.0'})"
        if ($isTpm2 -and $tpm.TpmPresent -and $tpm.TpmReady) {
            $score++
        } else {
            $issues.Add("TPM 2.0 required. Current: $specVer. Check BIOS to enable TPM 2.0 (may be listed as PTT for Intel or fTPM for AMD)")
        }
    } else {
        Write-Host "TPM WMI:      Not accessible"
        $issues.Add('TPM WMI class unavailable -- verify TPM is enabled in BIOS')
    }
} catch {
    Write-Host "TPM:          Not present or inaccessible"
    $issues.Add('No TPM detected -- Windows 11 requires TPM 2.0')
}

# --- Section 3: CPU Compatibility ---
Write-Host "`n--- Section 3: CPU Compatibility ---"
$cpu = Get-CimInstance Win32_Processor
Write-Host "CPU Name:     $($cpu.Name)"
Write-Host "Architecture: $($cpu.Architecture) (9=ARM64, 0=x86)"
Write-Host "Cores:        $($cpu.NumberOfCores)"
Write-Host "Speed:        $($cpu.MaxClockSpeed) MHz"

# Heuristic compatibility check based on generation markers
$cpuName = $cpu.Name
$cpuPass = $false
$cpuNote = ''

if ($cpuName -match 'Intel') {
    # Intel 8th gen (Coffee Lake) and later
    if ($cpuName -match 'Core i\d-[89]\d{3}|Core i\d-1[0-9]\d{3}|Core i\d-[2-9][0-9]{4}|Xeon (Gold|Platinum|Silver|Bronze) [23][0-9]{3}') {
        $cpuPass = $true; $cpuNote = 'Intel 8th gen or later detected (PASS)'
    } elseif ($cpuName -match 'Core i\d-[0-7]\d{3}') {
        $cpuNote = 'Intel 7th gen or earlier detected (FAIL) -- not on Windows 11 supported CPU list'
    } else {
        $cpuNote = 'Intel CPU detected -- verify against aka.ms/CPUlist'
    }
} elseif ($cpuName -match 'AMD') {
    # AMD Zen 2 and later: Ryzen 3xxx+
    if ($cpuName -match 'Ryzen [3-9] [3-9][0-9]{3}|Ryzen [3-9] [1-9][0-9]{4}|EPYC 7[0-9]{2}[2-9]|EPYC [89][0-9]{3}') {
        $cpuPass = $true; $cpuNote = 'AMD Zen 2 or later detected (PASS)'
    } elseif ($cpuName -match 'Ryzen [3-9] [12][0-9]{3}') {
        $cpuNote = 'AMD Zen 1 (Ryzen 1xxx/2xxx) detected (FAIL) -- not on Windows 11 supported CPU list'
    } else {
        $cpuNote = 'AMD CPU detected -- verify against aka.ms/CPUlist'
    }
} elseif ($cpuName -match 'Snapdragon|Qualcomm') {
    $cpuPass = $true; $cpuNote = 'Qualcomm Snapdragon detected -- verify specific model at aka.ms/CPUlist'
} else {
    $cpuNote = 'CPU vendor not recognized -- manually verify at https://aka.ms/CPUlist'
}

Write-Host "CPU Compat:   $cpuNote"
if ($cpuPass) { $score++ } else { $issues.Add("CPU may not be on Windows 11 supported list. Check: https://aka.ms/CPUlist") }

# --- Section 4: RAM and Disk Space ---
Write-Host "`n--- Section 4: RAM and Disk Space ---"
$osObj = Get-CimInstance Win32_OperatingSystem
$ramGB = [Math]::Round($osObj.TotalVisibleMemorySize / 1MB, 1)
Write-Host "RAM:          $ramGB GB (minimum 4 GB required)"
$ramPass = $ramGB -ge 4
if ($ramPass) { $score++ } else { $issues.Add("Insufficient RAM: $ramGB GB. Windows 11 requires at least 4 GB") }

# Check system drive free space
$sysDrive = $env:SystemDrive
$disk = Get-PSDrive -Name ($sysDrive -replace ':','') -EA SilentlyContinue
if (-not $disk) { $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysDrive'" }
$freeGB  = if ($disk.Free) { [Math]::Round($disk.Free / 1GB, 1) } else { [Math]::Round($disk.FreeSpace / 1GB, 1) }
$totalGB = if ($disk.Used) { [Math]::Round(($disk.Free + $disk.Used) / 1GB, 1) } else { [Math]::Round($disk.Size / 1GB, 1) }
Write-Host "System Drive: $sysDrive -- $freeGB GB free of $totalGB GB total"
$diskPass = $freeGB -ge 64
Write-Host "Disk Space:   $(if($diskPass){'Sufficient (PASS)'}else{'Insufficient (FAIL) -- 64 GB free required for upgrade'})"
if ($diskPass) { $score++ } else { $issues.Add("Insufficient free disk space: $freeGB GB free. Need at least 64 GB free on $sysDrive") }

# --- Section 5: Driver Compatibility ---
Write-Host "`n--- Section 5: Driver Compatibility ---"
try {
    $allDrivers   = Get-WmiObject Win32_PnPSignedDriver -EA SilentlyContinue
    $unsignedList = $allDrivers | Where-Object { $_.IsSigned -eq $false }
    $noVersionList = $allDrivers | Where-Object { -not $_.DriverVersion -and $_.IsSigned -ne $false }

    Write-Host "Total Drivers:    $($allDrivers.Count)"
    Write-Host "Unsigned Drivers: $($unsignedList.Count)"

    if ($unsignedList.Count -gt 0) {
        Write-Host "Unsigned Driver Details:"
        $unsignedList | Select-Object DeviceName, Manufacturer, DriverVersion |
            Format-Table -AutoSize | Out-String | Write-Host
        $issues.Add("$($unsignedList.Count) unsigned driver(s) found -- these may not load on Windows 11 (requires WHQL signature)")
    }

    # Flag likely problem devices
    $problemDevices = Get-CimInstance Win32_PnPEntity |
        Where-Object { $_.ConfigManagerErrorCode -ne 0 }
    Write-Host "Devices with errors: $($problemDevices.Count)"
    if ($problemDevices.Count -gt 0) {
        $problemDevices | Select-Object Name, ConfigManagerErrorCode |
            Format-Table -AutoSize | Out-String | Write-Host
    }

    $driverPass = ($unsignedList.Count -eq 0 -and $problemDevices.Count -eq 0)
    if ($driverPass) { $score++ } else {
        if ($unsignedList.Count -eq 0 -and $problemDevices.Count -gt 0) { $score++ }  # Partial credit
    }
} catch {
    Write-Warning "Driver compatibility check failed: $_"
}

# --- Section 6: BitLocker Recovery Key Backup Status ---
Write-Host "`n--- Section 6: BitLocker Recovery Key Backup Status ---"
try {
    $blVolumes = Get-BitLockerVolume -EA Stop
    foreach ($vol in $blVolumes) {
        Write-Host "Volume:        $($vol.MountPoint)"
        Write-Host "  Status:      $($vol.VolumeStatus)"
        Write-Host "  Protection:  $($vol.ProtectionStatus)"
        Write-Host "  Encryption:  $($vol.EncryptionMethod)"

        $recoveryProtectors = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
        if ($recoveryProtectors) {
            foreach ($prot in $recoveryProtectors) {
                try {
                    $adBackup = Get-ADObject -Filter "objectClass -eq 'msFVE-RecoveryInformation' and msFVE-RecoveryGuid -eq '$($prot.KeyProtectorId)'" `
                        -Properties msFVE-RecoveryPassword -EA SilentlyContinue
                    Write-Host "  AD Backup:   $(if($adBackup){'Yes (PASS)'}else{'Not found in AD'})"
                } catch {
                    Write-Host "  AD Backup:   Cannot verify (AD cmdlets not available or not domain-joined)"
                }

                $aadBitlocker = Get-ItemProperty `
                    'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\BitLocker' -EA SilentlyContinue
                Write-Host "  Intune BL Policy: $(if($aadBitlocker){'Policy present'}else{'No Intune BitLocker policy detected'})"
            }
        } else {
            Write-Host "  Recovery Key: No RecoveryPassword protector found"
            if ($vol.ProtectionStatus -eq 'On') {
                $issues.Add("$($vol.MountPoint) is BitLocker-protected but has no RecoveryPassword protector -- key cannot be backed up")
            }
        }
    }
} catch {
    Write-Host "BitLocker: Not enabled or cmdlets unavailable"
}

# --- Section 7: Overall Readiness Summary ---
Write-Host "`n--- Section 7: Overall Readiness Summary ---"
Write-Host "Readiness Score: $score / $maxScore"

$assessment = if ($score -eq $maxScore) {
    'READY: Device meets all Windows 11 hardware requirements'
} elseif ($score -ge 4) {
    'LIKELY READY: Minor issues detected -- review and remediate before upgrading'
} elseif ($score -ge 2) {
    'NOT READY: Multiple hardware or driver issues -- hardware upgrade or replacement may be required'
} else {
    'INCOMPATIBLE: Device does not meet Windows 11 requirements -- plan hardware refresh'
}

Write-Host "Assessment:      $assessment"

if ($issues.Count -gt 0) {
    Write-Host "`nIssues to Remediate:"
    foreach ($issue in $issues) {
        Write-Host "  [!] $issue"
    }
} else {
    Write-Host "`nNo blocking issues found."
}

Write-Host "`nResources:"
Write-Host "  Windows 11 CPU list:    https://aka.ms/CPUlist"
Write-Host "  PC Health Check:        https://aka.ms/GetPCHealthCheckApp"
Write-Host "  App Assure:             https://aka.ms/AppAssure"
Write-Host "  ESU enrollment:         https://aka.ms/Win10ESU"

Write-Host "`n$sep`n Upgrade Readiness Assessment Complete`n$sep"
