<#
.SYNOPSIS
    Windows 11 - Hardware Compatibility Assessment
.DESCRIPTION
    Checks TPM 2.0, Secure Boot, CPU approval heuristic, UEFI firmware,
    RAM, storage, DirectX/WDDM, and VM environment detection against
    Windows 11 minimum requirements.
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11 (pre-upgrade assessment or post-install verification)
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. TPM Check
        2. Secure Boot
        3. UEFI Firmware
        4. CPU Approval Heuristic
        5. RAM
        6. Storage
        7. DirectX / WDDM
        8. VM Detection
        9. Compatibility Summary
#>

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 70)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 70)" -ForegroundColor Cyan
}

$results = [ordered]@{}

# ── 1. TPM Check ────────────────────────────────────────────────────────────
Write-Section "TPM Check"
try {
    $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' `
        -ClassName 'Win32_Tpm' -ErrorAction Stop
    $specVersion = $tpm.SpecVersion
    $tpmMajor    = [int]($specVersion -split ',')[0].Trim()

    $results['TPM_Present']  = $true
    $results['TPM_Version']  = $specVersion
    $results['TPM_Ready']    = $tpm.IsEnabled_InitialValue -and $tpm.IsActivated_InitialValue
    $results['TPM_2_0']      = $tpmMajor -ge 2

    Write-Host "  Version     : $specVersion"
    Write-Host "  Enabled     : $($tpm.IsEnabled_InitialValue)"
    Write-Host "  Activated   : $($tpm.IsActivated_InitialValue)"
    Write-Host "  TPM 2.0     : $($results['TPM_2_0'])" -ForegroundColor $(if ($results['TPM_2_0']) { 'Green' } else { 'Red' })
} catch {
    $results['TPM_Present'] = $false
    $results['TPM_2_0']     = $false
    Write-Host "  TPM not found or inaccessible" -ForegroundColor Red
}

# ── 2. Secure Boot ──────────────────────────────────────────────────────────
Write-Section "Secure Boot"
try {
    $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
    $results['SecureBoot'] = $secureBoot
    Write-Host "  Secure Boot : $secureBoot" -ForegroundColor $(if ($secureBoot) { 'Green' } else { 'Red' })
} catch {
    $results['SecureBoot'] = $false
    Write-Host "  Secure Boot check failed (may be legacy BIOS)" -ForegroundColor Red
}

# ── 3. UEFI Firmware ────────────────────────────────────────────────────────
Write-Section "UEFI Firmware"
$bcdFirmware = (bcdedit /enum firmware 2>&1) -join ' '
$isUEFI = $bcdFirmware -notmatch 'not supported' -and $bcdFirmware -notmatch 'The requested system device cannot be found'
$results['UEFI'] = $isUEFI
Write-Host "  UEFI Firmware: $isUEFI" -ForegroundColor $(if ($isUEFI) { 'Green' } else { 'Red' })

# ── 4. CPU Approval Heuristic ───────────────────────────────────────────────
Write-Section "CPU Approval Heuristic"
$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$cpuName  = $cpu.Name
$cpuCores = $cpu.NumberOfCores
$cpuSpeed = [math]::Round($cpu.MaxClockSpeed / 1000, 2)

Write-Host "  Model       : $cpuName"
Write-Host "  Cores       : $cpuCores"
Write-Host "  Speed       : $($cpuSpeed) GHz"
$results['CPU_Model'] = $cpuName

$cpuApproved = $false
if ($cpuName -match 'Intel') {
    if ($cpuName -match 'Core.*(i[3579]|i\d)-([89]\d{3}|[12]\d{4})') { $cpuApproved = $true }
    if ($cpuName -match 'Core.*(Ultra|i[3579])-\d+') { $cpuApproved = $true }
    if ($cpuName -match 'Xeon') { $cpuApproved = $true }
} elseif ($cpuName -match 'AMD') {
    if ($cpuName -match 'Ryzen [3579] [3-9]\d{3}') { $cpuApproved = $true }
    if ($cpuName -match 'Ryzen (Threadripper|AI)') { $cpuApproved = $true }
    if ($cpuName -match 'EPYC') { $cpuApproved = $true }
} elseif ($cpuName -match 'Snapdragon') {
    if ($cpuName -match 'Snapdragon (7c|8c|8cx|X)') { $cpuApproved = $true }
}

$results['CPU_Approved'] = $cpuApproved
Write-Host "  Approved CPU : $cpuApproved" -ForegroundColor $(if ($cpuApproved) { 'Green' } else { 'Yellow' })
if (-not $cpuApproved) {
    Write-Host "  NOTE: Heuristic check. Verify against Microsoft's official CPU list." -ForegroundColor Yellow
}

# ── 5. RAM ──────────────────────────────────────────────────────────────────
Write-Section "RAM"
$ramBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
$ramGB    = [math]::Round($ramBytes / 1GB, 2)
$results['RAM_GB']  = $ramGB
$results['RAM_OK']  = $ramGB -ge 4
Write-Host "  Total RAM   : $ramGB GB" -ForegroundColor $(if ($results['RAM_OK']) { 'Green' } else { 'Red' })

# ── 6. Storage ──────────────────────────────────────────────────────────────
Write-Section "Storage"
$systemDrive = $env:SystemDrive.TrimEnd(':')
$disk        = Get-PSDrive -Name $systemDrive | Select-Object Used, Free
$totalGB     = [math]::Round(($disk.Used + $disk.Free) / 1GB, 2)
$results['Storage_GB'] = $totalGB
$results['Storage_OK'] = $totalGB -ge 64
Write-Host "  System Drive : $($totalGB) GB total" -ForegroundColor $(if ($results['Storage_OK']) { 'Green' } else { 'Red' })

# ── 7. DirectX / WDDM ──────────────────────────────────────────────────────
Write-Section "DirectX / WDDM"
$gpus = Get-CimInstance -ClassName Win32_VideoController
foreach ($gpu in $gpus) {
    Write-Host "  GPU         : $($gpu.Name)"
    Write-Host "  Driver Ver  : $($gpu.DriverVersion)"
}

$dx12Capable = $gpus | Where-Object { $_.DriverVersion -and [version]$_.DriverVersion -ge [version]'10.0' }
$results['DX12_Likely'] = ($dx12Capable.Count -gt 0)
Write-Host "  DX12 Capable : $($results['DX12_Likely'])" -ForegroundColor $(if ($results['DX12_Likely']) { 'Green' } else { 'Yellow' })

# ── 8. VM Detection ─────────────────────────────────────────────────────────
Write-Section "VM Detection"
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
$isVM = $computerSystem.Model -match 'Virtual|VMware|VirtualBox|KVM|Hyper-V|QEMU' -or
        ($computerSystem.Manufacturer -match 'VMware|Xen|innotek|QEMU|Microsoft Corporation' -and
         $computerSystem.Model -match 'Virtual Machine')
$results['Is_VM'] = $isVM
Write-Host "  Is VM        : $isVM"

if ($isVM) {
    Write-Host "  Model        : $($computerSystem.Model)"
    Write-Host "  Manufacturer : $($computerSystem.Manufacturer)"

    if ($computerSystem.Model -match 'Virtual Machine' -and $computerSystem.Manufacturer -match 'Microsoft') {
        Write-Host "  Hyper-V VM   : Ensure vTPM and Secure Boot are enabled on the VM object (host-side)" -ForegroundColor Cyan
    }
}

# ── 9. Compatibility Summary ────────────────────────────────────────────────
Write-Section "Compatibility Summary"
$checks = @{
    'TPM 2.0'          = $results['TPM_2_0']
    'Secure Boot'      = $results['SecureBoot']
    'UEFI Firmware'    = $results['UEFI']
    'CPU Approved'     = $results['CPU_Approved']
    'RAM >= 4 GB'      = $results['RAM_OK']
    'Storage >= 64 GB' = $results['Storage_OK']
    'DX12 / WDDM'     = $results['DX12_Likely']
}

$allPass = $true
foreach ($check in $checks.GetEnumerator()) {
    $status = if ($check.Value) { 'PASS' } else { 'FAIL'; $allPass = $false }
    $color  = if ($check.Value) { 'Green' } else { 'Red' }
    Write-Host "  $($check.Key.PadRight(20)) : $status" -ForegroundColor $color
}

Write-Host ""
if ($allPass) {
    Write-Host "  Overall: COMPATIBLE with Windows 11" -ForegroundColor Green
} else {
    Write-Host "  Overall: NOT COMPATIBLE — review failed checks" -ForegroundColor Red
}

Write-Host "`nHardware compatibility assessment complete." -ForegroundColor Green
