# Storage Spaces Direct Diagnostics and Troubleshooting

## Diagnostic Toolkit

### Required Modules
```powershell
Import-Module Storage
Import-Module FailoverClusters
Install-Module -Name PrivateCloud.DiagnosticInfo  # From PowerShell Gallery
```

### SDDC Diagnostic Bundle
```powershell
Get-SDDCDiagnosticInfo -WriteToPath C:\Temp\S2DDiag
Show-SDDCDiagnosticReport -Path C:\Temp\S2DDiag
```

## Cluster Health

```powershell
# Health faults (any active alerts)
Get-HealthFault

# Storage subsystem
Get-StorageSubSystem Cluster* | Select-Object FriendlyName, HealthStatus, OperationalStatus

# Health report
Get-StorageSubSystem Cluster* | Get-StorageHealthReport

# Cluster nodes
Get-ClusterNode | Select-Object Name, State, NodeWeight

# Active storage jobs
Get-StorageJob | Format-List *
```

## Physical Disk Diagnostics

```powershell
# Full inventory
Get-PhysicalDisk | Select-Object FriendlyName, SerialNumber, MediaType, BusType, Size, HealthStatus, OperationalStatus, Usage, CanPool, CannotPoolReason

# Unhealthy drives
Get-PhysicalDisk | Where-Object { $_.HealthStatus -ne "Healthy" }

# Poolable drives
Get-PhysicalDisk | Where-Object { $_.CanPool -eq $true }

# Reliability counters (SMART-like)
Get-PhysicalDisk | Get-StorageReliabilityCounter | Select-Object DeviceId, ReadErrorsCorrected, ReadErrorsUncorrected, WriteErrorsUncorrected, Temperature, Wear, PowerOnHours
```

### Drive Health States

| Health | Operational | Meaning |
|---|---|---|
| Healthy | OK | Normal |
| Warning | Lost Communication | Drive/server unreachable |
| Warning | Predictive Failure | SMART indicates imminent failure |
| Warning | Abnormal Latency | Slow response |
| Warning | In Maintenance Mode | Admin-placed |
| Unhealthy | Failed Media | Replace immediately |
| Unhealthy | Stale Metadata | Reset + Repair |
| Unhealthy | Unrecognized Metadata | From different pool — reset |

### Drive Repair
```powershell
# Reset drive (wipes data, removes from pool metadata)
Reset-PhysicalDisk -FriendlyName "PhysicalDisk4"
Repair-VirtualDisk -FriendlyName "Volume01"

# Maintenance mode
Enable-StorageMaintenanceMode -PhysicalDisk (Get-PhysicalDisk -SerialNumber "SN12345")
Disable-StorageMaintenanceMode -PhysicalDisk (Get-PhysicalDisk -SerialNumber "SN12345")
```

## Virtual Disk Diagnostics

```powershell
# Status
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, DetachedReason, ResiliencySettingName

# Unhealthy
Get-VirtualDisk | Where-Object { $_.HealthStatus -ne "Healthy" }

# Detached
Get-VirtualDisk | Where-Object { $_.OperationalStatus -eq "Detached" }
```

### Virtual Disk Health States

| Health | Operational | Meaning |
|---|---|---|
| Healthy | OK | Fully healthy |
| Healthy | Suboptimal | Uneven data — run Optimize-StoragePool |
| Warning | In Service | Repair/rebuild in progress |
| Warning | Incomplete | Resilience reduced, data accessible |
| Warning | Degraded | Outdated copies on failed drives |
| Unhealthy | No Redundancy | Data at risk |
| Unknown | Detached | Offline (policy, majority unhealthy, incomplete, timeout) |

### Virtual Disk Repair
```powershell
Repair-VirtualDisk -FriendlyName "Volume01"
Get-VirtualDisk | Where-Object { $_.OperationalStatus -eq "Detached" } | Connect-VirtualDisk
```

### No Redundancy Recovery
```powershell
Remove-ClusterSharedVolume -Name "CSV Name"
Get-ClusterResource "Disk Resource" | Set-ClusterParameter -Name DiskRecoveryAction -Value 1
Start-ClusterResource -Name "Disk Resource"
Get-StorageJob  # Monitor repair
# After repair:
Get-ClusterResource "Disk Resource" | Set-ClusterParameter -Name DiskRecoveryAction -Value 0
Stop-ClusterResource "Disk Resource"
Start-ClusterResource "Disk Resource"
Add-ClusterSharedVolume -Name "Disk Resource"
```

### DRT Log Full Recovery (Event 311)
```powershell
Remove-ClusterSharedVolume -Name "CSV Name"
Get-ClusterResource "Disk Resource" | Set-ClusterParameter DiskRunChkDsk 7
Start-ClusterResource "Disk Resource"
Get-ScheduledTask -TaskName "Data Integrity Scan for Crash Recovery" | Start-ScheduledTask
# After scan:
Get-ClusterResource "Disk Resource" | Set-ClusterParameter DiskRunChkDsk 0
Stop-ClusterResource "Disk Resource"
Start-ClusterResource "Disk Resource"
Add-ClusterSharedVolume -Name "Disk Resource"
```

## Storage Pool Diagnostics

```powershell
Get-StoragePool -IsPrimordial $False | Select-Object FriendlyName, HealthStatus, OperationalStatus, ReadOnlyReason, IsReadOnly

# Capacity
Get-StoragePool -IsPrimordial $False | Select-Object FriendlyName,
    @{N="TotalGB";E={[math]::Round($_.Size/1GB,1)}},
    @{N="FreeGB";E={[math]::Round($_.RemainingCapacityBytes/1GB,1)}}

# Pool read-only recovery
Get-StoragePool -FriendlyName "S2D*" -IsPrimordial $False | Set-StoragePool -IsReadOnly $false

# Optimize pool
Optimize-StoragePool -FriendlyName "S2D on ClusterName"
```

## Performance Diagnostics

### Cache Status (Cluster Log)
```powershell
Get-ClusterLog -Destination C:\Temp -UseLocalTime
# Search for "[=== SBL Disks ===]" — check CacheDiskState values
```

### Performance History
```powershell
Get-Volume | Get-ClusterPerf -VolumeSeriesName "Volume.Iops.Total" -TimeFrame LastHour
Get-Volume | Get-ClusterPerf -VolumeSeriesName "Volume.Latency.Average" -TimeFrame LastHour
Get-PhysicalDisk | Get-ClusterPerf -PhysicalDiskSeriesName "PhysicalDisk.Iops.Total" -TimeFrame LastHour
Get-NetAdapter | Get-ClusterPerf -NetAdapterSeriesName "NetAdapter.Bandwidth.Total" -TimeFrame LastDay
Get-ClusterNode | Get-ClusterPerf -ClusterNodeSeriesName "ClusterNode.Cpu.Usage" -TimeFrame LastDay
```

### RDMA Verification
```powershell
Get-NetAdapterRdma | Select-Object Name, Enabled, Operational
Get-SmbClientNetworkInterface | Select-Object InterfaceIndex, FriendlyName, RdmaCapable, Speed
```

## Event Log Analysis

### Critical Event IDs

| Event ID | Source | Meaning |
|---|---|---|
| 311 | StorageSpaces-Driver | DRT log full — integrity scan required |
| 5120 | FailoverClustering | CSV I/O timeout |
| 1135 | FailoverClustering | Node removed from membership |
| 5 | ReFS | Volume mount failure |
| 134 | ReFS | Write failure — volume going offline |

```powershell
Get-WinEvent -LogName "Microsoft-Windows-StorageSpaces-Driver/Operational" -MaxEvents 100
Get-WinEvent -LogName "Microsoft-Windows-FailoverClustering/Operational" -MaxEvents 100
Get-WinEvent -FilterHashtable @{
    LogName = "System","Microsoft-Windows-FailoverClustering/Operational"
    Level = 1,2  # Critical, Error
    StartTime = (Get-Date).AddHours(-1)
} | Select-Object TimeCreated, ProviderName, Id, Message
```

## Common Scenarios

### Drive Won't Join Pool (CanPool = False)
```powershell
Get-PhysicalDisk | Format-Table FriendlyName, MediaType, Size, CanPool, CannotPoolReason
```
Common reasons: In a Pool, Insufficient Capacity, Not Healthy, Offline (`Set-Disk -IsOffline $false`), Unrecognized Metadata (`Reset-PhysicalDisk`), Removable Media.

### S2D Hangs at 27%
SAS expander duplicate IDs or HBA in RAID mode. Verify HBA pass-through. Check SES support.

### Event 5120 (CSV Timeout) After Restart
Install KB 4462928 or later. Disable live dump if high memory pressure: `(Get-Cluster).DumpPolicy = ((Get-Cluster).DumpPolicy -Band 0xFFFFFFFFFFFFFFFE)`.

### Proactive Health Check Script
```powershell
function Get-S2DHealthSummary {
    Write-Host "=== Storage Subsystem ===" -ForegroundColor Cyan
    Get-StorageSubSystem Cluster* | Select-Object FriendlyName, HealthStatus, OperationalStatus
    Write-Host "`n=== Storage Pool ===" -ForegroundColor Cyan
    Get-StoragePool -IsPrimordial $False | Select-Object FriendlyName, HealthStatus,
        @{N="FreeGB";E={[math]::Round($_.RemainingCapacityBytes/1GB,1)}},
        @{N="TotalGB";E={[math]::Round($_.Size/1GB,1)}}
    Write-Host "`n=== Virtual Disks ===" -ForegroundColor Cyan
    Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus
    Write-Host "`n=== Unhealthy Physical Disks ===" -ForegroundColor Cyan
    $bad = Get-PhysicalDisk | Where-Object { $_.HealthStatus -ne "Healthy" }
    if ($bad) { $bad | Select-Object FriendlyName, SerialNumber, HealthStatus, OperationalStatus }
    else { Write-Host "All healthy." -ForegroundColor Green }
    Write-Host "`n=== Active Jobs ===" -ForegroundColor Cyan
    $jobs = Get-StorageJob
    if ($jobs) { $jobs | Select-Object FriendlyName, JobState, PercentComplete }
    else { Write-Host "None." -ForegroundColor Green }
    Write-Host "`n=== Health Faults ===" -ForegroundColor Cyan
    $faults = Get-HealthFault
    if ($faults) { $faults | Select-Object FaultType, Severity, Reason }
    else { Write-Host "None." -ForegroundColor Green }
}
Get-S2DHealthSummary
```
