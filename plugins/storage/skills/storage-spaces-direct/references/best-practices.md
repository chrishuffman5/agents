# Storage Spaces Direct Best Practices

## Hardware Selection

### Servers
2-16 servers. Same manufacturer and model. Windows Server Catalog certified (SDDC Premium). 4+ nodes for production. 4 GB RAM per TB of cache drive capacity (in addition to OS/VM needs).

### Drives
- NVMe: lowest latency, recommended for cache. Use Microsoft `stornvme.sys` driver only.
- SSDs: must have power-loss protection (PLP). Cache: 3+ DWPD or 4+ TBW/day. Min 32 GB.
- Drive symmetry: same number/type in every server. Capacity drives = whole multiple of cache drives.
- RAID controllers: HBA pass-through mode only (no RAID sets).
- All-flash (NVMe or SSD only): cache disabled, max performance. NVMe+SSD: NVMe write cache. Hybrid (SSD+HDD): SSD read/write cache.

## Network Design

| Cluster Size | Minimum | Recommended |
|---|---|---|
| 2-3 nodes | 10 Gbps | 25 Gbps + RDMA |
| 4+ nodes | 25 Gbps + RDMA | 100 Gbps + RDMA |

2+ network connections per node. RDMA: ~15% performance improvement, reduced CPU. iWARP recommended (simpler). RoCE for max performance (requires PFC/QoS on switches). Switch Embedded Teaming (SET) for NIC teaming (standard NIC teaming unsupported with RDMA). Traffic segregation via VLANs: storage highest priority, then live migration, then management.

Switchless: supported for 2-node (direct-connect, eliminates switch failure domain).

## Cache Configuration

1 cache drive per 4 capacity drives (1:4 ratio). Minimum 2 cache drives per server. Cache size: 10% of capacity tier minimum.

Nested resiliency write cache control:
```powershell
Get-StorageSubSystem Cluster* | Set-StorageHealthSetting `
    -Name "System.Storage.NestedResiliency.DisableWriteCacheOnNodeDown.Enabled" -Value "True"
```

## Volume Design

- One volume per workload type for targeted monitoring
- Individual volumes: no larger than 10 TB recommended for manageability
- Fixed provisioning: predictable capacity. Thin (WS2025/Azure Local 22H2+): overcommit, monitor pool free space carefully
- Interleave: 256 KB default. 64 KB for SQL Server.
- Always use ReFS (mandatory for CSV volumes with S2D)
- WS2025: ReFS deduplication for additional space savings

```powershell
# Three-way mirror
New-VirtualDisk -StoragePoolFriendlyName "S2D*" -FriendlyName "Vol01" `
    -ResiliencySettingName Mirror -NumberOfDataCopies 3 -Size 2TB

# SQL Server with 64KB interleave
New-VirtualDisk -StoragePoolFriendlyName "S2D*" -FriendlyName "SQLData" `
    -ResiliencySettingName Mirror -NumberOfDataCopies 3 -Size 2TB -Interleave 65536
```

## Cluster Validation

Run before enabling S2D and after hardware changes:
```powershell
Test-Cluster -Node "Server01","Server02","Server03","Server04" `
    -Include "Storage Spaces Direct","Inventory","Network","System Configuration"
```
All tests must pass before production.

## Fault Domain Planning

Define BEFORE enabling S2D. Rack-aware parity: min 4 racks, equal node counts. Map physical locations carefully.

```powershell
New-ClusterFaultDomain -Type Rack -Name "Rack-01"
Set-ClusterFaultDomain -Name "Server01","Server02" -Parent "Rack-01"
Enable-ClusterStorageSpacesDirect
```

## Monitoring (Windows Admin Center)

Install WAC on management server (not cluster nodes). Key dashboards: Cluster (health, capacity, performance), Storage (pool, drives, volumes), Alerts (Health Service faults).

```powershell
# Performance history
Get-Cluster | Get-ClusterPerf -ClusterSeriesName "PhysicalDisk.Iops.Total" -TimeFrame LastDay
Get-Volume -FriendlyName "Vol01" | Get-ClusterPerf -VolumeSeriesName "Volume.Latency.Average" -TimeFrame LastWeek

# Health faults
Get-HealthFault

# Storage jobs
Get-StorageJob
```

## Performance Tuning

### Storage QoS
```powershell
New-StorageQosPolicy -Name "Gold" -MinimumIops 1000 -MaximumIops 10000
Get-VM "CriticalVM" | Set-VMHardDiskDrive -StorageQoSPolicyID (Get-StorageQosPolicy -Name "Gold").PolicyId
```

### Pool Optimization
Run after adding drives or nodes: `Optimize-StoragePool -FriendlyName "S2D on ClusterName"`.

### CSV In-Memory Read Cache
For VDI/Hyper-V read-heavy workloads: `(Get-Cluster).BlockCacheSize = 1024` (1 GB per node).

### Benchmarking
Use VMFleet and DiskSpd for baselines before production.

## Maintenance

### Node Patching
```powershell
Suspend-ClusterNode -Name "Server01" -Drain
Get-StorageFaultDomain -Type StorageScaleUnit | Where-Object { $_.FriendlyName -eq "Server01" } | Enable-StorageMaintenanceMode
# Patch and reboot
Disable-StorageMaintenanceMode ...
Resume-ClusterNode -Name "Server01"
Get-StorageJob  # Monitor resync
```

### Capacity Planning
Alert at 80% pool. Critical at 90%. Thin-provisioned volumes go read-only at pool exhaustion.

```powershell
Get-StoragePool -IsPrimordial $False | Select-Object FriendlyName,
    @{N="FreeGB";E={[math]::Round($_.RemainingCapacityBytes/1GB,1)}},
    @{N="TotalGB";E={[math]::Round($_.Size/1GB,1)}},
    @{N="UsedPct";E={[math]::Round((1 - $_.RemainingCapacityBytes/$_.Size)*100,1)}}
```
