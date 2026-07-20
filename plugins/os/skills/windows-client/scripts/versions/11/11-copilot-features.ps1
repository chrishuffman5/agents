<#
.SYNOPSIS
    Windows 11 - Copilot+ PC Feature Readiness Assessment
.DESCRIPTION
    Detects NPU presence and capability, checks Copilot+ hardware
    eligibility (40+ TOPS NPU, 16 GB RAM), Windows Studio Effects
    availability, Windows Recall status, and AI platform configuration.
.NOTES
    Version : 1.0.0
    Targets : Windows 11 24H2+ (build 26100+)
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. OS Version
        2. RAM (Copilot+ Requirement)
        3. NPU Detection
        4. Copilot+ Eligibility Assessment
        5. Windows Studio Effects
        6. Windows Recall
        7. Summary
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

# ── 1. OS Version ───────────────────────────────────────────────────────────
Write-Section "OS Version"
$osInfo  = Get-CimInstance -ClassName Win32_OperatingSystem
$osBuild = [System.Environment]::OSVersion.Version.Build
$results['OS_Build']   = $osBuild
$results['OS_Caption'] = $osInfo.Caption

Write-Host "  OS          : $($osInfo.Caption)"
Write-Host "  Build       : $osBuild"

if ($osBuild -lt 26100) {
    Write-Host "  NOTE: Copilot+ features fully available on 24H2 (build 26100+)" -ForegroundColor Yellow
}

# ── 2. RAM (Copilot+ Requirement: 16 GB) ────────────────────────────────────
Write-Section "RAM (Copilot+ Requirement: 16 GB)"
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$results['RAM_GB']          = $ramGB
$results['RAM_CopilotPlus'] = $ramGB -ge 16
Write-Host "  Total RAM   : $ramGB GB" -ForegroundColor $(if ($results['RAM_CopilotPlus']) { 'Green' } else { 'Red' })

# ── 3. NPU Detection ───────────────────────────────────────────────────────
Write-Section "NPU Detection"

# Method 1: PnP device class
$npuDevices = Get-PnpDevice -ErrorAction SilentlyContinue |
    Where-Object { $_.Class -match 'NPU|NeuralProcessor|ComputeAccelerator|AIProcessor' -or
                   $_.FriendlyName -match 'NPU|Neural|Hexagon|AI Boost|AI Engine' }

$results['NPU_Devices'] = @($npuDevices)

if ($npuDevices) {
    Write-Host "  NPU devices found:" -ForegroundColor Green
    foreach ($npu in $npuDevices) {
        Write-Host "    - $($npu.FriendlyName) [$($npu.Status)]"
    }
} else {
    Write-Host "  No dedicated NPU device found via PnP" -ForegroundColor Yellow
}

# Method 2: CPU name heuristic for NPU-capable silicon
$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$cpuName = $cpu.Name
$results['CPU_NPU_Capable'] = $cpuName -match 'Snapdragon X|Ryzen AI|Core Ultra [2-9]00[VH]|Apple'

Write-Host "  CPU Model   : $cpuName"
Write-Host "  CPU NPU-capable hint: $($results['CPU_NPU_Capable'])" -ForegroundColor $(
    if ($results['CPU_NPU_Capable']) { 'Green' } else { 'Yellow' }
)

# Method 3: Windows AI Platform registry keys
$aiPlatformKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI'
$results['AI_Platform_Present'] = Test-Path $aiPlatformKey

if ($results['AI_Platform_Present']) {
    Write-Host "  Windows AI Platform key: Present" -ForegroundColor Green
    $aiProps = Get-ItemProperty -Path $aiPlatformKey -ErrorAction SilentlyContinue
    if ($aiProps) {
        $aiProps | Select-Object -ExcludeProperty PSPath, PSParentPath, PSChildName, PSDrive, PSProvider |
            Format-List | Out-String | ForEach-Object { Write-Host "    $_" }
    }
} else {
    Write-Host "  Windows AI Platform key: Not present" -ForegroundColor Yellow
}

# ── 4. Copilot+ Eligibility Assessment ──────────────────────────────────────
Write-Section "Copilot+ Eligibility Assessment"
$copilotPlusEligible = ($results['CPU_NPU_Capable'] -or $results['NPU_Devices'].Count -gt 0) -and
                       $results['RAM_CopilotPlus']
$results['CopilotPlus_Eligible'] = $copilotPlusEligible

Write-Host "  Copilot+ Eligible: $copilotPlusEligible" -ForegroundColor $(
    if ($copilotPlusEligible) { 'Green' } else { 'Yellow' }
)
if (-not $copilotPlusEligible) {
    Write-Host "  NOTE: Copilot+ requires 40+ TOPS NPU and 16 GB RAM. This is a heuristic check." -ForegroundColor Yellow
    Write-Host "        Use PC Health Check or Microsoft's Copilot+ PC checker for official validation." -ForegroundColor Yellow
}

# ── 5. Windows Studio Effects ───────────────────────────────────────────────
Write-Section "Windows Studio Effects"

$cameras = Get-PnpDevice -Class Camera -ErrorAction SilentlyContinue
if ($cameras) {
    Write-Host "  Camera devices:"
    foreach ($cam in $cameras) {
        Write-Host "    - $($cam.FriendlyName) [$($cam.Status)]"
    }
}

$wseKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\VideoEffects'
if (Test-Path $wseKey) {
    Write-Host "  Studio Effects user settings key: Present" -ForegroundColor Green
    $results['StudioEffects_Present'] = $true
    Get-ItemProperty -Path $wseKey -ErrorAction SilentlyContinue |
        Select-Object -ExcludeProperty PSPath, PSParentPath, PSChildName, PSDrive, PSProvider |
        Format-List | Out-String | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "  Studio Effects user settings key: Not present" -ForegroundColor Yellow
    $results['StudioEffects_Present'] = $false
}

# ── 6. Windows Recall ───────────────────────────────────────────────────────
Write-Section "Windows Recall"

$recallService = Get-Service -Name 'CoreAIPlatform' -ErrorAction SilentlyContinue
$results['Recall_Service_Present'] = $null -ne $recallService

if ($recallService) {
    Write-Host "  Recall service (CoreAIPlatform): $($recallService.Status)" -ForegroundColor Green
} else {
    Write-Host "  Recall service (CoreAIPlatform): Not found" -ForegroundColor Yellow
    Write-Host "  NOTE: Recall requires Copilot+ PC hardware" -ForegroundColor Yellow
}

# Check policy
$recallPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
if (Test-Path $recallPolicyKey) {
    $recallPolicy = Get-ItemProperty -Path $recallPolicyKey -ErrorAction SilentlyContinue
    $disabledByPolicy = $recallPolicy.DisableAIDataAnalysis -eq 1
    $results['Recall_Disabled_Policy'] = $disabledByPolicy
    Write-Host "  Recall policy: $(if ($disabledByPolicy) { 'DISABLED by policy' } else { 'Not disabled by policy' })" -ForegroundColor $(
        if ($disabledByPolicy) { 'Yellow' } else { 'Green' }
    )
} else {
    Write-Host "  No Recall policy configured"
}

# Check snapshot storage
$recallPath = "$env:LOCALAPPDATA\CoreAIPlatform.00"
if (Test-Path $recallPath) {
    Write-Host "  Recall snapshot path: Exists" -ForegroundColor Green
    $size = (Get-ChildItem -Path $recallPath -Recurse -ErrorAction SilentlyContinue |
             Measure-Object -Property Length -Sum).Sum
    Write-Host "  Snapshot storage used: $([math]::Round($size / 1MB, 2)) MB"
} else {
    Write-Host "  Recall snapshot path: Not found"
}

# ── 7. Summary ──────────────────────────────────────────────────────────────
Write-Section "Copilot+ Summary"
$summary = @{
    'Copilot+ Eligible'     = $results['CopilotPlus_Eligible']
    'NPU Found'             = $results['NPU_Devices'].Count -gt 0 -or $results['CPU_NPU_Capable']
    'RAM 16 GB+'            = $results['RAM_CopilotPlus']
    'Recall Service'        = $results['Recall_Service_Present']
    'AI Platform Present'   = $results['AI_Platform_Present']
    'Studio Effects'        = $results['StudioEffects_Present']
}

foreach ($item in $summary.GetEnumerator()) {
    $color = if ($item.Value) { 'Green' } else { 'Yellow' }
    Write-Host "  $($item.Key.PadRight(22)) : $($item.Value)" -ForegroundColor $color
}

Write-Host "`nCopilot+ readiness assessment complete." -ForegroundColor Green
