<#
.SYNOPSIS
    WSL - Health and Status Assessment
.DESCRIPTION
    Collects WSL installation status, version information, installed
    distributions with WSL version and state, Linux kernel version,
    WSLg availability, systemd status per distro, VHD sizes, Windows
    feature status, and .wslconfig configuration summary.
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11 with WSL installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Windows Features
        2. WSL Version Information
        3. Installed Distributions
        4. Default Distribution
        5. Linux Kernel
        6. WSLg (GUI Apps) Status
        7. systemd Status per Distribution
        8. Virtual Hard Disk Sizes
        9. .wslconfig Configuration
#>

#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 70)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 70)" -ForegroundColor Cyan
}

function Write-Item {
    param([string]$Label, [string]$Value, [string]$Color = 'White')
    Write-Host ("  {0,-35} {1}" -f "${Label}:", $Value) -ForegroundColor $Color
}

# ── 1. Windows Features ─────────────────────────────────────────────────────
Write-Section "Windows Features"

$features = @(
    'Microsoft-Windows-Subsystem-Linux',
    'VirtualMachinePlatform',
    'HypervisorPlatform'
)

foreach ($feature in $features) {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue).State
    $color = if ($state -eq 'Enabled') { 'Green' } else { 'Red' }
    Write-Item $feature ($state ?? 'Not found') $color
}

# ── 2. WSL Version Information ──────────────────────────────────────────────
Write-Section "WSL Version Information"

$wslVersion = wsl --version 2>&1
if ($LASTEXITCODE -eq 0 -or $wslVersion) {
    $wslVersion | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
} else {
    Write-Host "  WSL not installed or --version not supported" -ForegroundColor Red
}

# ── 3. Installed Distributions ──────────────────────────────────────────────
Write-Section "Installed Distributions"

$distroList = wsl --list --verbose 2>&1
if ($LASTEXITCODE -eq 0 -or $distroList -match 'NAME') {
    $distroList | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  No distros found or WSL not available" -ForegroundColor Yellow
}

# ── 4. Default Distribution ─────────────────────────────────────────────────
Write-Section "Default Distribution"

$defaultDistro = (wsl --list 2>&1 | Select-String '\(Default\)').ToString().Trim()
if ($defaultDistro) {
    Write-Item "Default distro" ($defaultDistro -replace '\(Default\)', '').Trim()
} else {
    Write-Host "  Unable to determine default distro" -ForegroundColor Yellow
}

# ── 5. Linux Kernel Version ─────────────────────────────────────────────────
Write-Section "Linux Kernel"

$kernelVersion = wsl -- uname -r 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Item "Kernel version" $kernelVersion 'Green'
} else {
    Write-Host "  Could not retrieve kernel version (no running distro?)" -ForegroundColor Yellow
}

# ── 6. WSLg (GUI Apps) Status ───────────────────────────────────────────────
Write-Section "WSLg (GUI Apps) Status"

$wslgCheck = wsl -- ls /mnt/wslg 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Item "WSLg" "Available" 'Green'
    $wayland = wsl -- sh -c 'echo $WAYLAND_DISPLAY' 2>&1
    Write-Item "WAYLAND_DISPLAY" ($wayland ?? '(not set)')
    $display = wsl -- sh -c 'echo $DISPLAY' 2>&1
    Write-Item "DISPLAY" ($display ?? '(not set)')
} else {
    Write-Item "WSLg" "Not available or not enabled" 'Yellow'
}

# ── 7. systemd Status per Distribution ──────────────────────────────────────
Write-Section "systemd Status per Distribution"

$distros = wsl --list --quiet 2>&1 | Where-Object { $_ -match '\S' -and $_ -notmatch '^Windows' }
foreach ($distro in $distros) {
    $distroName = $distro.Trim() -replace '\(Default\)', '' -replace '\s+', ''
    if (-not $distroName) { continue }

    $systemdPid1 = wsl -d $distroName -- sh -c 'cat /proc/1/comm 2>/dev/null' 2>&1
    $systemdStatus = if ($systemdPid1 -match 'systemd') { 'Enabled (PID1=systemd)' } else { "Not enabled (PID1=$systemdPid1)" }
    $color = if ($systemdPid1 -match 'systemd') { 'Green' } else { 'Gray' }
    Write-Item "  $distroName" $systemdStatus $color
}

# ── 8. Virtual Hard Disk Sizes ──────────────────────────────────────────────
Write-Section "Virtual Hard Disk Sizes"

$vhdPaths = @(
    "$env:LOCALAPPDATA\Packages",
    "$env:USERPROFILE"
)

$vhds = Get-ChildItem -Path $vhdPaths -Recurse -Filter 'ext4.vhdx' -ErrorAction SilentlyContinue
if ($vhds) {
    foreach ($vhd in $vhds) {
        $sizeGB = [math]::Round($vhd.Length / 1GB, 2)
        $parent = $vhd.DirectoryName -replace [regex]::Escape($env:LOCALAPPDATA), '%LOCALAPPDATA%'
        Write-Item ($vhd.Name) ("{0} GB — {1}" -f $sizeGB, $parent)
    }
} else {
    Write-Host "  No ext4.vhdx files found in standard locations" -ForegroundColor Yellow
    Write-Host "  (Custom import locations will not be scanned)" -ForegroundColor Gray
}

# ── 9. .wslconfig Configuration ─────────────────────────────────────────────
Write-Section ".wslconfig Configuration"

$wslConfigPath = "$env:USERPROFILE\.wslconfig"
if (Test-Path $wslConfigPath) {
    Write-Item ".wslconfig" "Found at $wslConfigPath" 'Green'
    Get-Content $wslConfigPath | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Item ".wslconfig" "Not present (defaults in use)" 'Yellow'
}

Write-Host "`nWSL health assessment complete." -ForegroundColor Green
