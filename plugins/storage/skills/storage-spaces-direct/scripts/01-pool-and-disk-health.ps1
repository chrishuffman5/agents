# Purpose:        Storage Spaces Direct health triage - pool, virtual disk, and physical disk state in one pass
# Applies to:     Storage Spaces Direct on Windows Server 2019/2022/2025 (run on any cluster node, elevated)
# Read-only:      yes
# Inputs:         none (run locally on a cluster node)
# Interpretation: VirtualDisk HealthStatus 'Warning' with OperationalStatus 'Degraded' = a copy is missing but data is
#                 served - find the failed PhysicalDisk below. PhysicalDisk 'Lost Communication' = node/cabling/HBA;
#                 'Unhealthy'/'IO Error' = the drive itself. Usage 'Retired' disks no longer receive new allocations -
#                 replace them. Do NOT remove more disks than the resiliency tolerates while anything is Degraded.
# Next step:      02-repair-jobs-status.ps1 - never pull hardware while repair jobs are running

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "== Storage subsystem health"
Get-StorageSubSystem Cluster* | Select-Object FriendlyName, HealthStatus, OperationalStatus | Format-Table -AutoSize

Write-Host "== Storage pool"
Get-StoragePool | Where-Object IsPrimordial -eq $false |
    Select-Object FriendlyName, HealthStatus, OperationalStatus, @{n='SizeTB';e={[math]::Round($_.Size/1TB,1)}}, @{n='AllocatedTB';e={[math]::Round($_.AllocatedSize/1TB,1)}} |
    Format-Table -AutoSize

Write-Host "== Virtual disks"
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, ResiliencySettingName, @{n='SizeTB';e={[math]::Round($_.Size/1TB,1)}} | Format-Table -AutoSize

Write-Host "== Physical disks with problems"
Get-PhysicalDisk | Where-Object { $_.HealthStatus -ne 'Healthy' -or $_.OperationalStatus -ne 'OK' } |
    Select-Object FriendlyName, SerialNumber, MediaType, HealthStatus, OperationalStatus, Usage | Format-Table -AutoSize

Write-Host "== Cluster health faults"
Get-HealthFault 2>$null | Select-Object FaultingObjectDescription, Severity, Reason | Format-Table -Wrap
