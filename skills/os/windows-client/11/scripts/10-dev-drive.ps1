<#
.SYNOPSIS
    Windows 11 - Dev Drive Health and Configuration Report
.DESCRIPTION
    Enumerates Dev Drive (ReFS) volumes, checks Defender performance mode
    status, third-party AV interaction, volume integrity, policy state,
    and common package cache locations on Dev Drives.
.NOTES
    Version : 1.0.0
    Targets : Windows 11 23H2+ (build 22621+)
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. OS Version Check
        2. ReFS Volumes (Dev Drive Candidates)
        3. Defender Performance Mode
        4. Dev Drive Policy
        5. ReFS Volume Integrity
        6. Package Manager Cache Locations
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

# ── 1. OS Version Check ─────────────────────────────────────────────────────
Write-Section "OS Version Check"
$build = [System.Environment]::OSVersion.Version.Build
Write-Host "  Current build: $build"
if ($build -lt 22621) {
    Write-Warning "Dev Drive requires Windows 11 22H2 (build 22621) or later. Current build: $build"
}

# ── 2. ReFS Volumes (Dev Drive Candidates) ──────────────────────────────────
Write-Section "ReFS Volumes (Dev Drive Candidates)"
$refsVolumes = Get-Volume | Where-Object { $_.FileSystem -eq 'ReFS' }

if (-not $refsVolumes) {
    Write-Host "  No ReFS volumes found. No Dev Drives configured." -ForegroundColor Yellow
} else {
    foreach ($vol in $refsVolumes) {
        $usedGB  = [math]::Round(($vol.Size - $vol.SizeRemaining) / 1GB, 2)
        $totalGB = [math]::Round($vol.Size / 1GB, 2)
        $freeGB  = [math]::Round($vol.SizeRemaining / 1GB, 2)
        $usePct  = if ($vol.Size -gt 0) { [math]::Round((($vol.Size - $vol.SizeRemaining) / $vol.Size) * 100, 1) } else { 0 }

        Write-Host ""
        Write-Host "  Drive Letter : $($vol.DriveLetter):"
        Write-Host "  Label        : $($vol.FileSystemLabel)"
        Write-Host "  FileSystem   : $($vol.FileSystem)"
        Write-Host "  Health       : $($vol.HealthStatus)"
        Write-Host "  Total        : $totalGB GB"
        Write-Host "  Used         : $usedGB GB ($usePct%)"
        Write-Host "  Free         : $freeGB GB"
        Write-Host "  Operational  : $($vol.OperationalStatus)"

        if ($totalGB -lt 50) {
            Write-Host "  WARNING: Volume is below recommended 50 GB minimum for Dev Drive" -ForegroundColor Yellow
        }

        if ($vol.DriveLetter) {
            $partition = Get-Partition -DriveLetter $vol.DriveLetter -ErrorAction SilentlyContinue
            if ($partition) {
                $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction SilentlyContinue
                if ($disk) {
                    Write-Host "  Disk         : Disk $($disk.Number) — $($disk.FriendlyName) ($($disk.BusType))"
                    Write-Host "  Disk Health  : $($disk.HealthStatus)"
                }
            }
        }
    }
}

# ── 3. Defender Performance Mode ────────────────────────────────────────────
Write-Section "Defender Performance Mode"
try {
    $mpPref = Get-MpPreference -ErrorAction Stop
    $perfMode = $mpPref.PerformanceModeStatus
    Write-Host "  Performance Mode Status : $perfMode"

    if ($perfMode -eq 1) {
        Write-Host "  Dev Drive async scanning : Enabled" -ForegroundColor Green
    } elseif ($perfMode -eq 0) {
        Write-Host "  Dev Drive async scanning : Disabled" -ForegroundColor Yellow
        Write-Host "  NOTE: May be disabled due to third-party AV or policy" -ForegroundColor Yellow
    } else {
        Write-Host "  Status: $perfMode" -ForegroundColor Yellow
    }

    $avProducts = Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName 'AntiVirusProduct' -ErrorAction SilentlyContinue
    if ($avProducts) {
        foreach ($av in $avProducts) {
            $isDefender = $av.displayName -match 'Windows Defender|Microsoft Defender'
            Write-Host "  AV Product   : $($av.displayName)" -ForegroundColor $(if ($isDefender) { 'White' } else { 'Yellow' })
            if (-not $isDefender) {
                Write-Host "  NOTE: Third-party AV detected. Dev Drive performance mode requires AV to declare support." -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "  Unable to query Defender preferences: $_" -ForegroundColor Red
}

# ── 4. Dev Drive Policy ─────────────────────────────────────────────────────
Write-Section "Dev Drive Policy"
$devDrivePolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DevDrive'
if (Test-Path $devDrivePolicyKey) {
    $policy = Get-ItemProperty -Path $devDrivePolicyKey -ErrorAction SilentlyContinue
    Write-Host "  Policy key found:"
    $policy | Select-Object -ExcludeProperty PSPath, PSParentPath, PSChildName, PSDrive, PSProvider | Format-List
} else {
    Write-Host "  No Dev Drive policy configured (using defaults)" -ForegroundColor Green
}

# ── 5. ReFS Volume Integrity ────────────────────────────────────────────────
Write-Section "ReFS Volume Integrity"
foreach ($vol in $refsVolumes) {
    if ($vol.DriveLetter) {
        Write-Host "  Checking $($vol.DriveLetter): ..." -NoNewline
        $repair = Repair-Volume -DriveLetter $vol.DriveLetter -Scan -ErrorAction SilentlyContinue 2>&1
        if ($repair -match 'No further action') {
            Write-Host " Clean" -ForegroundColor Green
        } elseif ($repair) {
            Write-Host " $repair" -ForegroundColor Yellow
        } else {
            Write-Host " Scan complete (check Event Log for details)"
        }
    }
}

# ── 6. Package Manager Cache Locations ──────────────────────────────────────
Write-Section "Package Manager Cache Locations on Dev Drives"
$devDriveLetters = $refsVolumes | Where-Object DriveLetter | Select-Object -ExpandProperty DriveLetter

foreach ($letter in $devDriveLetters) {
    $npmCache   = "$($letter):\npm-cache"
    $pipCache   = "$($letter):\pip-cache"
    $nugetCache = "$($letter):\nuget-cache"
    $cargoCache = "$($letter):\cargo"

    Write-Host "  $($letter): — npm cache   : $(if (Test-Path $npmCache) { 'Configured' } else { 'Not configured' })"
    Write-Host "  $($letter): — pip cache   : $(if (Test-Path $pipCache) { 'Configured' } else { 'Not configured' })"
    Write-Host "  $($letter): — NuGet cache : $(if (Test-Path $nugetCache) { 'Configured' } else { 'Not configured' })"
    Write-Host "  $($letter): — Cargo home  : $(if (Test-Path $cargoCache) { 'Configured' } else { 'Not configured' })"
}

Write-Host "`nDev Drive assessment complete." -ForegroundColor Green
