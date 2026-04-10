# Storage Spaces Direct Diagnostics and Troubleshooting

## Overview

S2D diagnostics use a layered approach: start with the cluster-level health view, then drill into storage subsystem, pools, virtual disks, and physical disks. The Health Service provides automated fault detection and continuous monitoring; PowerShell cmdlets provide deep diagnostic access.

---

## Diagnostic Toolkit

### Primary PowerShell Modules Required

```powershell
# Storage cmdlets (built-in)
Import-Module Storage
Import-Module FailoverClusters

# SDDC Diagnostic module (install from PowerShell Gallery)
Install-Module -Name PrivateCloud.DiagnosticInfo
```

### SDDC Diagnostic Info Module

The `PrivateCloud.DiagnosticInfo` module is the primary tool for comprehensive S2D health collection:

```powershell
# Collect complete S2D diagnostic bundle
Get-SDDCDiagnosticInfo -WriteToPath C:\Temp\S2DDiag

# View an HTML report
Show-SDDCDiagnosticReport -Path C:\Temp\S2DDiag

# Quick health check
Get-SDDCDiagnosticInfo
```

The report includes: physical disks, enclosures, virtual disks, storage pools, cluster nodes, network adapters, event logs, and performance counters.

---

## Cluster Health Assessment

### Overall Cluster Health

```powershell
# Get cluster health faults (any active alerts)
Get-HealthFault

# Get storage subsystem (the S2D subsystem)
Get-StorageSubSystem -FriendlyName "Clustered Windows Storage on *"

# Shorthand: get the S2D subsystem
Get-StorageSubSystem Cluster*

# Get storage health report (actionable health issues)
Get-StorageSubSystem Cluster* | Get-StorageHealthReport
```

### Cluster Node Status

```powershell
# View all cluster nodes and their state
Get-ClusterNode

# View node details
Get-ClusterNode | Select-Object Name, State, NodeWeight

# Check cluster resource ownership
Get-ClusterGroup | Select-Object Name, OwnerNode, State

# View Health Service owner node
Get-ClusterResource Health | Select-Object Name, OwnerNode, State
```

### Active Storage Jobs

```powershell
# List all active storage repair/rebuild jobs
Get-StorageJob

# Monitor repair progress in detail
Get-StorageJob | Format-List *

# Watch jobs continuously (refresh every 5 seconds)
while ($true) { Get-StorageJob; Start-Sleep 5; Clear-Host }

# Get jobs by type
Get-StorageJob | Where-Object { $_.JobState -eq "Running" }
Get-StorageJob | Where-Object { $_.Name -like "*Repair*" }
```

---

## Get-StorageSubSystem

`Get-StorageSubSystem` returns the S2D storage subsystem object, which is the entry point for the entire storage hierarchy.

```powershell
# Get the S2D subsystem
Get-StorageSubSystem -FriendlyName "Clustered Windows Storage on *"

# Equivalent shorthand
Get-StorageSubSystem Cluster*

# Example output properties
Get-StorageSubSystem Cluster* | Select-Object FriendlyName, HealthStatus, OperationalStatus, CurrentCacheState

# Navigate from subsystem to pools
Get-StorageSubSystem Cluster* | Get-StoragePool | Select-Object FriendlyName, HealthStatus, OperationalStatus

# Navigate from subsystem to all physical disks
Get-StorageSubSystem Cluster* | Get-PhysicalDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, Usage

# Navigate from subsystem to all virtual disks
Get-StorageSubSystem Cluster* | Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus
```

**HealthStatus values**: Healthy, Warning, Unhealthy, Unknown

---

## Get-PhysicalDisk

`Get-PhysicalDisk` is the primary command for inspecting individual drives.

### Basic Drive Inventory

```powershell
# List all physical disks
Get-PhysicalDisk

# Summary with key properties
Get-PhysicalDisk | Select-Object FriendlyName, SerialNumber, MediaType, BusType,
    Size, HealthStatus, OperationalStatus, Usage, CanPool, CannotPoolReason

# Find unhealthy drives
Get-PhysicalDisk | Where-Object { $_.HealthStatus -ne "Healthy" }

# Find drives not in pool
Get-PhysicalDisk | Where-Object { $_.CanPool -eq $true }

# Find drives with CannotPoolReason
Get-PhysicalDisk | Format-Table FriendlyName, MediaType, Size, CanPool, CannotPoolReason

# Get drives by media type
Get-PhysicalDisk | Where-Object { $_.MediaType -eq "NVMe" }
Get-PhysicalDisk | Where-Object { $_.MediaType -eq "SSD" }
Get-PhysicalDisk | Where-Object { $_.MediaType -eq "HDD" }
```

### Drive Health States

| HealthStatus | OperationalStatus | Meaning |
|-------------|-------------------|---------|
| Healthy | OK | Drive is functioning normally |
| Healthy | In Service | Drive performing internal maintenance |
| Warning | Lost Communication | Drive/server unreachable |
| Warning | Predictive Failure | SMART data indicates imminent failure — replace soon |
| Warning | IO Error | Transient I/O errors — monitor or replace |
| Warning | Abnormal Latency | Drive responding slowly — investigate |
| Warning | In Maintenance Mode | Admin-placed maintenance mode |
| Unhealthy | Failed Media | Drive failed — replace immediately |
| Unhealthy | Split | Drive separated from pool — reset and re-add |
| Unhealthy | Stale Metadata | Old metadata on drive — run Repair-VirtualDisk or Reset-PhysicalDisk |
| Unhealthy | Unrecognized Metadata | Drive from different pool — reset to add to current pool |
| Unhealthy | Not Usable | Unsupported hardware — check hardware requirements |

### Drive Diagnostics

```powershell
# Get extended SMART-like reliability data
Get-PhysicalDisk | Get-StorageReliabilityCounter | Select-Object DeviceId,
    ReadErrorsCorrected, ReadErrorsUncorrected, WriteErrorsUncorrected,
    Temperature, Wear, PowerOnHours

# Get physical disk slot and location
Get-PhysicalDisk | Select-Object FriendlyName, SerialNumber, SlotNumber,
    PhysicalLocation, EnclosureNumber

# Check if disk is in maintenance mode
Get-PhysicalDisk | Where-Object { $_.OperationalStatus -eq "In Maintenance Mode" }

# Find drives removing from pool
Get-PhysicalDisk | Where-Object { $_.OperationalStatus -like "*Removing*" }
```

### Drive Repair Operations

```powershell
# Reset a drive (wipes all data on the drive, removes from pool metadata)
# Use when: stale metadata, unrecognized metadata, split drive
Reset-PhysicalDisk -FriendlyName "PhysicalDisk4"
# Then repair affected virtual disks:
Repair-VirtualDisk -FriendlyName "Volume01"

# Place drive in maintenance mode (pause reads/writes for firmware update)
Enable-StorageMaintenanceMode -PhysicalDisk (Get-PhysicalDisk -SerialNumber "SN12345")

# Exit maintenance mode
Disable-StorageMaintenanceMode -PhysicalDisk (Get-PhysicalDisk -SerialNumber "SN12345")

# Clear stale HealthStatus intent from a drive
# (Use when OperationalStatus shows "Removing from Pool" but Remove-PhysicalDisk was not actually called)
Clear-PhysicalDiskHealthData -SerialNumber "000000000000000" -Intent -Policy -Verbose -Force
```

---

## Get-VirtualDisk

`Get-VirtualDisk` inspects the status of virtual disks (storage spaces) carved from the pool.

### Basic Virtual Disk Queries

```powershell
# List all virtual disks
Get-VirtualDisk

# Key status properties
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus,
    DetachedReason, ResiliencySettingName, Size, AllocatedSize

# Find unhealthy virtual disks
Get-VirtualDisk | Where-Object { $_.HealthStatus -ne "Healthy" }

# Find detached virtual disks
Get-VirtualDisk | Where-Object { $_.OperationalStatus -eq "Detached" }

# Find degraded virtual disks (resiliency reduced but data accessible)
Get-VirtualDisk | Where-Object { $_.OperationalStatus -like "*Degraded*" }

# Find virtual disks in No Redundancy state
Get-VirtualDisk | Where-Object { $_.OperationalStatus -like "*No Redundancy*" }
```

### Virtual Disk Health States

| HealthStatus | OperationalStatus | Meaning |
|-------------|-------------------|---------|
| Healthy | OK | Virtual disk is fully healthy |
| Healthy | Suboptimal | Data not written evenly — run Optimize-StoragePool |
| Warning | In Service | Active repair/rebuild in progress |
| Warning | Incomplete | Resilience reduced; data accessible; drives missing |
| Warning | Degraded | Resilience reduced; outdated copies on failed drives |
| Unhealthy | No Redundancy | Too many failures; data may be at risk |
| Unknown | Detached (By Policy) | Admin took disk offline manually |
| Unknown | Detached (Majority Disks Unhealthy) | Too many drives failed; attach recovery needed |
| Unknown | Detached (Incomplete) | Not enough drives to read the virtual disk |
| Unknown | Detached (Timeout) | Attach operation timed out |

### Virtual Disk Repair Operations

```powershell
# Trigger repair on a specific virtual disk
Repair-VirtualDisk -FriendlyName "Volume01"

# Repair all degraded virtual disks
Get-VirtualDisk | Where-Object { $_.HealthStatus -ne "Healthy" } | Repair-VirtualDisk

# Connect (bring online) a detached virtual disk
Get-VirtualDisk | Where-Object { $_.OperationalStatus -eq "Detached" } | Connect-VirtualDisk

# Disconnect a virtual disk
Disconnect-VirtualDisk -FriendlyName "Volume01"

# Set virtual disk to not require manual attach (auto-attach on reboot)
Get-VirtualDisk | Set-VirtualDisk -IsManualAttach $false
```

### No Redundancy Recovery Procedure

When a virtual disk enters "No Redundancy" state after a node restart or crash:

```powershell
# Step 1: Remove from CSV
Remove-ClusterSharedVolume -Name "CSV Name"

# Step 2: Find the owning node
Get-ClusterGroup

# Step 3: Set recovery action on the resource (run on owning node)
Get-ClusterResource "Physical Disk Resource Name" | Set-ClusterParameter -Name DiskRecoveryAction -Value 1
Start-ClusterResource -Name "Physical Disk Resource Name"

# Step 4: Monitor repair progress
Get-StorageJob
Get-VirtualDisk -FriendlyName "Volume01" | Select-Object HealthStatus, OperationalStatus

# Step 5: After repair completes, reset recovery action
Get-ClusterResource "Physical Disk Resource Name" | Set-ClusterParameter -Name DiskRecoveryAction -Value 0

# Step 6: Cycle the resource
Stop-ClusterResource "Physical Disk Resource Name"
Start-ClusterResource "Physical Disk Resource Name"

# Step 7: Add back to CSV
Add-ClusterSharedVolume -Name "Physical Disk Resource Name"
```

### Detached (DRT Log Full) Recovery Procedure

When a virtual disk is detached due to a full Dirty Region Tracking (DRT) log:

```powershell
# Step 1: Remove from CSV
Remove-ClusterSharedVolume -Name "CSV Name"

# Step 2: Set DiskRunChkDsk to trigger integrity scan
Get-ClusterResource -Name "Physical Disk Resource Name" | Set-ClusterParameter DiskRunChkDsk 7
Start-ClusterResource -Name "Physical Disk Resource Name"

# Step 3: Start the Data Integrity Scan for Crash Recovery (on all nodes where volume is online)
Get-ScheduledTask -TaskName "Data Integrity Scan for Crash Recovery" | Start-ScheduledTask

# Step 4: Monitor the scan (it does not show as a StorageJob)
Get-ScheduledTask | Where-Object { $_.State -eq "Running" }

# Step 5: After scan completes, reset the parameter
Get-ClusterResource -Name "Physical Disk Resource Name" | Set-ClusterParameter DiskRunChkDsk 0

# Step 6: Cycle and re-add to CSV
Stop-ClusterResource "Physical Disk Resource Name"
Start-ClusterResource "Physical Disk Resource Name"
Add-ClusterSharedVolume -Name "Physical Disk Resource Name"
```

---

## Storage Pool Diagnostics

```powershell
# Get pool health
Get-StoragePool -IsPrimordial $False | Select-Object FriendlyName, HealthStatus,
    OperationalStatus, ReadOnlyReason, IsReadOnly

# Get pool capacity details
Get-StoragePool -IsPrimordial $False | Select-Object FriendlyName,
    @{N="TotalGB";E={[math]::Round($_.Size/1GB,1)}},
    @{N="FreeGB";E={[math]::Round($_.RemainingCapacityBytes/1GB,1)}},
    @{N="AllocatedGB";E={[math]::Round(($_.Size - $_.RemainingCapacityBytes)/1GB,1)}}

# List pool drives
Get-StoragePool -IsPrimordial $False | Get-PhysicalDisk

# Check pool metadata drives
Get-StoragePool -IsPrimordial $False | Get-PhysicalDisk | Where-Object { $_.Usage -eq "Journal" }

# Optimize pool drive usage (rebalance data distribution)
Optimize-StoragePool -FriendlyName "S2D on ClusterName"
```

### Pool Read-Only Recovery

When a pool is read-only due to quorum loss or policy:

```powershell
# View read-only reason
Get-StoragePool -IsPrimordial $False | Select-Object FriendlyName, ReadOnlyReason

# Set pool back to read-write (after reconnecting missing drives/nodes)
Get-StoragePool -FriendlyName "S2D*" -IsPrimordial $False | Set-StoragePool -IsReadOnly $false
```

---

## Performance Diagnostics

### Identifying Slow I/O

The cluster log is the primary source for cache state verification:

```powershell
# Get cluster log and search for SBL disk states
Get-ClusterLog -Destination C:\Temp -UseLocalTime
# Then open the log and search for "[=== SBL Disks ===]"
```

Cache disk states in the cluster log:
- `CacheDiskStateInitializedAndBound` — Cache active (healthy)
- `CacheDiskStateNonHybrid` — All drives same type; cache disabled
- `CacheDiskStateIneligibleDataPartition` — Drive ineligible for cache

### Performance Counter Collection

Use Performance Monitor or PowerShell to collect key counters:

```powershell
# Get performance history for volumes
Get-Volume | Get-ClusterPerf -VolumeSeriesName "Volume.Iops.Total" -TimeFrame LastHour
Get-Volume | Get-ClusterPerf -VolumeSeriesName "Volume.Latency.Average" -TimeFrame LastHour
Get-Volume | Get-ClusterPerf -VolumeSeriesName "Volume.Throughput.Total" -TimeFrame LastHour

# Get drive-level IOPS
Get-PhysicalDisk | Get-ClusterPerf -PhysicalDiskSeriesName "PhysicalDisk.Iops.Total" -TimeFrame LastHour
Get-PhysicalDisk | Get-ClusterPerf -PhysicalDiskSeriesName "PhysicalDisk.Latency.Average"

# Get network adapter throughput
Get-NetAdapter | Get-ClusterPerf -NetAdapterSeriesName "NetAdapter.Bandwidth.Total" -TimeFrame LastDay

# Get node CPU utilization
Get-ClusterNode | Get-ClusterPerf -ClusterNodeSeriesName "ClusterNode.Cpu.Usage" -TimeFrame LastDay

# Get VM performance history
Get-VM | Get-ClusterPerf -VMSeriesName "Vm.Cpu.Usage" -TimeFrame LastHour
```

### Key Performance Counters (Windows Performance Monitor)

| Counter | Object | Description |
|---------|--------|-------------|
| Disk Reads/sec | PhysicalDisk | IOPS read per physical disk |
| Disk Writes/sec | PhysicalDisk | IOPS write per physical disk |
| Avg. Disk sec/Read | PhysicalDisk | Average read latency |
| Avg. Disk sec/Write | PhysicalDisk | Average write latency |
| Disk Bytes/sec | PhysicalDisk | Throughput per physical disk |
| Bytes Total/sec | SMB Direct Connection | RDMA throughput |
| Read Bytes/sec | SMB Server Shares | CSV read throughput |
| Write Bytes/sec | SMB Server Shares | CSV write throughput |
| Cache Pages Paged | Hyper-V Dynamic Memory | VM memory pressure |

### SMB Direct RDMA Verification

```powershell
# Verify RDMA is active on network adapters
Get-NetAdapterRdma | Select-Object Name, Enabled, Operational

# Check RDMA traffic statistics
Get-SmbClientNetworkInterface | Select-Object InterfaceIndex, FriendlyName, RdmaCapable, Speed

# Verify SMB Direct connections
Get-SmbConnection | Select-Object ServerName, Dialect, NumOpens

# SMB Direct diagnostic events
Get-WinEvent -LogName "Microsoft-Windows-SMBDirect/Debug" -MaxEvents 50
```

---

## Event Log Analysis

### Key Event Logs for S2D Diagnostics

| Event Log | Contains |
|-----------|---------|
| `System` | General cluster events, disk events, network events |
| `Microsoft-Windows-StorageSpaces-Driver/Operational` | S2D driver events, virtual disk state changes |
| `Microsoft-Windows-StorageSpaces-Driver/Diagnostic` | Detailed SBL/cache events |
| `Microsoft-Windows-FailoverClustering/Operational` | Cluster resource state changes, node membership |
| `Microsoft-Windows-FailoverClustering/Diagnostic` | Detailed cluster heartbeat and quorum events |
| `Microsoft-Windows-StorageManagement/Operational` | Pool, virtual disk, and drive management events |
| `Microsoft-Windows-ReFS/Operational` | ReFS volume events, mount failures |
| `Microsoft-Windows-SMBDirect/Debug` | RDMA diagnostic events |

### Critical Event IDs

| Event ID | Source | Meaning |
|----------|--------|---------|
| 311 | StorageSpaces-Driver | Virtual disk requires data integrity scan (DRT full) |
| 5120 | FailoverClustering | CSV entered paused state (IO_TIMEOUT / disconnected) |
| 1135 | FailoverClustering | Cluster node removed from active membership |
| 5 | ReFS | ReFS failed to mount the volume |
| 134 | ReFS | ReFS write failed — volume going offline |
| 203/205 | Disk | Communication lost with physical disk (can be expected during node reboot) |

### Querying Event Logs with PowerShell

```powershell
# Get recent StorageSpaces driver events
Get-WinEvent -LogName "Microsoft-Windows-StorageSpaces-Driver/Operational" -MaxEvents 100

# Get recent failover clustering events
Get-WinEvent -LogName "Microsoft-Windows-FailoverClustering/Operational" -MaxEvents 100

# Filter for critical storage events
Get-WinEvent -LogName "System" | Where-Object { $_.LevelDisplayName -in "Error","Critical" `
    -and $_.ProviderName -like "*storage*" } | Select-Object TimeCreated, Message

# Get all events in the last hour with error level
Get-WinEvent -FilterHashtable @{
    LogName = "System","Microsoft-Windows-FailoverClustering/Operational"
    Level = 1,2  # Critical=1, Error=2
    StartTime = (Get-Date).AddHours(-1)
} | Select-Object TimeCreated, ProviderName, Id, Message

# Get cluster log (comprehensive cluster event collection)
Get-ClusterLog -Destination "C:\Temp\Logs" -UseLocalTime -TimeSpan 60
# -TimeSpan is in minutes (60 = last hour)
```

---

## Storage Repair Operations

### Monitoring Repair Jobs

```powershell
# Get all repair jobs
Get-StorageJob

# Get detailed repair job info
Get-StorageJob | Format-List FriendlyName, JobState, PercentComplete,
    BytesProcessed, BytesTotal, StartTime

# Wait for all repair jobs to complete
while (Get-StorageJob | Where-Object { $_.JobState -eq "Running" }) {
    Get-StorageJob | Select-Object FriendlyName, JobState, PercentComplete
    Start-Sleep -Seconds 30
}
```

### Controlling Repair Speed

S2D automatically throttles repair jobs to minimize impact on running workloads. Repair throttling can be adjusted:

```powershell
# View current storage subsystem settings
Get-StorageSubSystem Cluster* | Get-StorageHealthSetting

# Increase repair speed (use during maintenance windows)
Get-StorageSubSystem Cluster* | Set-StorageHealthSetting `
    -Name "System.Storage.PhysicalDisk.AutoReplace.Enabled" -Value "True"

# Control repair I/O priority
# (Adjust StorageSubSystem repair throttle settings)
Set-StorageSubSystem -FriendlyName "Clustered Windows Storage*" `
    -AutoWriteCacheSize $true
```

### Post-Failure Recovery Workflow

After replacing a failed drive:

```powershell
# Step 1: Verify the new drive is detected
Get-PhysicalDisk | Where-Object { $_.CanPool -eq $true }

# Step 2: If drive needs to be cleaned first (from old metadata):
Reset-PhysicalDisk -FriendlyName "PhysicalDiskX"

# Step 3: Add drive to pool (S2D does this automatically, but manual if needed)
Add-PhysicalDisk -StoragePoolFriendlyName "S2D*" `
    -PhysicalDisks (Get-PhysicalDisk -CanPool $true)

# Step 4: Trigger repair on all affected virtual disks
Get-VirtualDisk | Where-Object { $_.HealthStatus -ne "Healthy" } | Repair-VirtualDisk

# Step 5: Monitor repair progress
Get-StorageJob
```

---

## Common Troubleshooting Scenarios

### Scenario: Drive Won't Join Pool (CanPool = False)

```powershell
# Check why drive cannot be pooled
Get-PhysicalDisk | Format-Table FriendlyName, MediaType, Size, CanPool, CannotPoolReason
```

**Common CannotPoolReason values and remedies:**

| Reason | Remedy |
|--------|--------|
| In a Pool | Remove from current pool first |
| Insufficient Capacity | Drive too small (cache drives must be 32 GB+) |
| Not Healthy | Drive has errors; investigate or replace |
| In Use by Cluster | Drive is a cluster resource; remove cluster resource first |
| Offline | Bring drive online: `Set-Disk -IsOffline $false` |
| Unrecognized Metadata | Run `Reset-PhysicalDisk` to wipe old pool metadata |
| Removable Media | Drive classified as removable; not supported |
| Verification Failed | Health Service cannot verify drive; check components document |

### Scenario: S2D Hangs at "Waiting until SBL disks are surfaced" or 27%

```powershell
# Check hardware compatibility
# Likely cause: SAS expander creating duplicate IDs, or HBA in RAID mode
# Verify HBA is in HBA pass-through mode (not RAID mode)
# Check for SCSI Enclosure Services (SES) support
```

### Scenario: Event 5120 (CSV I/O Timeout) After Node Restart

```powershell
# Check if specific Windows Server 2016 patch is installed:
# Install KB 4462928 (October 2018 cumulative update) or later
# Disable live dump generation if system is under high memory pressure:
(Get-Cluster).DumpPolicy = ((Get-Cluster).DumpPolicy -Band 0xFFFFFFFFFFFFFFFE)
```

### Scenario: Slow Performance — Check Cache Status

```powershell
# Method 1: Check cluster log for cache disk states
Get-ClusterLog -Destination C:\Temp -UseLocalTime
# Search log for "[=== SBL Disks ===]" and check CacheDiskState values

# Method 2: Check via SDDC diagnostic info XML export
Get-SDDCDiagnosticInfo -WriteToPath C:\Temp
$d = Import-Clixml "C:\Temp\GetPhysicalDisk.XML"
$d | Select-Object FriendlyName, SerialNumber, MediaType, CanPool, OperationalStatus, HealthStatus, Usage
# Usage should show "Journal" for cache drives, not "Auto-Select"
```

### Scenario: Intel SSD DC P4600 Non-Unique NGUID

```powershell
# Symptom: Multiple NVMe namespaces with identical NGUIDs
# Fix: Update Intel SSD firmware to version QDV101B1 (May 2018) or later
# Use Intel SSD Data Center Tool for firmware updates
```

### Scenario: HPE SAS Expander "Surfacing" Issue

```powershell
# Symptom: Enable-ClusterStorageSpacesDirect hangs at 27%
# Cause: HPE SAS expander firmware duplicate ID bug
# Fix: Update HPE Smart Array Controllers SAS Expander to firmware 4.02+
```

---

## Cluster Validation for Diagnostics

```powershell
# Run targeted S2D validation tests
Test-Cluster -Node "Server01","Server02","Server03","Server04" `
    -Include "Storage Spaces Direct","Inventory","Network","System Configuration"

# Validate specific test categories
Test-Cluster -Node "Server01","Server02" -Include "Storage Spaces Direct"

# Run full validation (all tests)
Test-Cluster -Node "Server01","Server02","Server03","Server04"
```

---

## Proactive Health Monitoring Script

```powershell
# Comprehensive S2D health check script
function Get-S2DHealthSummary {
    Write-Host "=== Storage Subsystem ===" -ForegroundColor Cyan
    Get-StorageSubSystem Cluster* | Select-Object FriendlyName, HealthStatus, OperationalStatus

    Write-Host "`n=== Storage Pool ===" -ForegroundColor Cyan
    Get-StoragePool -IsPrimordial $False | Select-Object FriendlyName, HealthStatus, OperationalStatus,
        @{N="FreeGB";E={[math]::Round($_.RemainingCapacityBytes/1GB,1)}},
        @{N="TotalGB";E={[math]::Round($_.Size/1GB,1)}}

    Write-Host "`n=== Virtual Disks ===" -ForegroundColor Cyan
    Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, DetachedReason

    Write-Host "`n=== Physical Disks (unhealthy) ===" -ForegroundColor Cyan
    $badDisks = Get-PhysicalDisk | Where-Object { $_.HealthStatus -ne "Healthy" }
    if ($badDisks) { $badDisks | Select-Object FriendlyName, SerialNumber, HealthStatus, OperationalStatus }
    else { Write-Host "All physical disks healthy." -ForegroundColor Green }

    Write-Host "`n=== Active Storage Jobs ===" -ForegroundColor Cyan
    $jobs = Get-StorageJob
    if ($jobs) { $jobs | Select-Object FriendlyName, JobState, PercentComplete }
    else { Write-Host "No active storage jobs." -ForegroundColor Green }

    Write-Host "`n=== Health Faults ===" -ForegroundColor Cyan
    $faults = Get-HealthFault
    if ($faults) { $faults | Select-Object FaultType, Severity, Reason, FaultingObjectDescription }
    else { Write-Host "No active health faults." -ForegroundColor Green }
}

Get-S2DHealthSummary
```

---

## References

- [Storage Spaces Direct troubleshooting - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/troubleshooting-storage-spaces)
- [Storage Spaces and Storage Spaces Direct health and operational states - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-states)
- [Troubleshoot performance issues in Storage Spaces Direct - Microsoft Learn](https://learn.microsoft.com/en-us/troubleshoot/windows-server/backup-and-storage/troubleshoot-performance-issues-storage-spaces-direct)
- [Performance history for Storage Spaces Direct - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/performance-history)
- [PrivateCloud.DiagnosticInfo GitHub - PowerShell](https://github.com/PowerShell/PrivateCloud.DiagnosticInfo)
- [Storage Spaces Direct health diagnostics - ITPro Today](https://www.itprotoday.com/business-continuity/how-diagnose-storage-pool-health-problems-storage-spaces-direct)
