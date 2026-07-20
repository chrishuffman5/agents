<#
.SYNOPSIS
    Windows Server 2019 - Storage Migration Service Status
.DESCRIPTION
    Checks SMS feature installation, active migration jobs, transfer
    status, and cutover readiness. Identifies stalled or failed migrations.
.NOTES
    Version : 2019.1.0
    Targets : Windows Server 2019+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. SMS Feature and Service Status
        2. Active Migration Jobs
        3. Job Details and Transfer Progress
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n Storage Migration Service Status - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep"

$feature = Get-WindowsFeature -Name SMS -ErrorAction SilentlyContinue
if (-not $feature -or -not $feature.Installed) {
    Write-Warning "Storage Migration Service not installed. Install: Install-WindowsFeature SMS -IncludeManagementTools"
    return
}

$svc = Get-Service -Name SMS -ErrorAction SilentlyContinue
[PSCustomObject]@{
    Feature = 'SMS'; Installed = $feature.Installed; ServiceStatus = $svc.Status; StartType = $svc.StartType
} | Format-List

Write-Host "--- Migration Jobs ---"
try {
    Import-Module StorageMigrationService -ErrorAction Stop
    $jobs = Get-SmsJob -ErrorAction SilentlyContinue
    if ($jobs) {
        $jobs | Select-Object Name, State, InventoryStatus, TransferStatus, CutoverStatus | Format-Table -AutoSize
        foreach ($job in $jobs) {
            Write-Host "`n  Job: $($job.Name)"
            Write-Host "  State: $($job.State)"
            $progress = Get-SmsTransferProgress -JobName $job.Name -ErrorAction SilentlyContinue
            if ($progress) { $progress | Select-Object SourceComputerName, PercentComplete, BytesTransferred | Format-Table -AutoSize }
        }
    } else { Write-Host "No migration jobs configured." }
} catch { Write-Host "SMS module not available or no jobs present." }

Write-Host "`n$sep`n SMS Check Complete`n$sep"
