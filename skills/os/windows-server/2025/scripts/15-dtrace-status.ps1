<#
.SYNOPSIS
    Windows Server 2025 - DTrace Availability and Status
.DESCRIPTION
    Checks DTrace installation, available probe providers, and runs
    a safe diagnostic one-liner to verify DTrace functionality.
.NOTES
    Version : 2025.1.0
    Targets : Windows Server 2025+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. DTrace Feature Status
        2. DTrace Version
        3. Available Probe Providers
        4. Syscall Probe Count
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n DTrace Status (Server 2025)`n$sep"

Write-Host "`n--- Section 1: DTrace Feature ---"
$feature = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-DTrace' -EA SilentlyContinue
if ($feature) {
    Write-Host "Feature: $($feature.FeatureName)"
    Write-Host "State: $($feature.State)"
    if ($feature.State -ne 'Enabled') {
        Write-Warning "DTrace not enabled. Install: Enable-WindowsOptionalFeature -FeatureName 'Microsoft-Windows-Subsystem-DTrace' -Online"
        return
    }
} else { Write-Warning "DTrace feature not found on this system." ; return }

Write-Host "`n--- Section 2: DTrace Version ---"
try { dtrace -V 2>&1 | Write-Host } catch { Write-Host "dtrace binary not accessible." ; return }

Write-Host "`n--- Section 3: Probe Providers ---"
try {
    $providers = dtrace -l 2>&1 | Select-Object -Skip 1 | ForEach-Object {
        ($_ -split '\s+')[2]
    } | Sort-Object -Unique
    Write-Host "Available providers: $($providers.Count)"
    $providers | ForEach-Object { Write-Host "  $_" }
} catch { Write-Host "Could not enumerate probes." }

Write-Host "`n--- Section 4: Syscall Probe Count ---"
try {
    $syscallCount = (dtrace -l -n 'syscall:::' 2>&1 | Measure-Object -Line).Lines - 1
    Write-Host "Syscall probes available: $syscallCount"
} catch { Write-Host "Could not count syscall probes." }
Write-Host "`n$sep`n DTrace Check Complete`n$sep"
