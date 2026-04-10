# Storage Spaces Direct Best Practices

## Hardware Selection

### Server Requirements

- Use **2 to 16 servers** per cluster. For production workloads, 4+ nodes provide better resiliency and performance distribution.
- All servers should be the **same manufacturer and model** with identical hardware configurations. Mixed hardware causes performance inconsistencies and complicates support.
- Servers must be **Windows Server Catalog certified** with SDDC Standard or SDDC Premium qualification (AQ). This ensures compatibility and enables Microsoft support.
- Use servers validated by Microsoft hardware partners for S2D or Azure Local solutions. These come with tested configurations, deployment tooling, and firmware validation.
- Minimum **4 GB of RAM per TB of cache drive capacity** per server for S2D metadata (in addition to OS and VM memory requirements).

### CPU Selection

- Intel Nehalem or later, or AMD EPYC or later
- Provide sufficient cores for Hyper-V VMs plus S2D overhead (storage processing, compression, encryption)
- For NVMe-heavy workloads, CPU core count and speed directly affects storage throughput. High core counts benefit erasure coding calculations.

### Drive Selection

#### NVMe (Highest Priority — Recommended for Cache)

- NVMe drives mounted directly on the PCIe bus provide the lowest latency of any drive type
- Use NVMe as cache tier when deploying NVMe + SSD or NVMe + HDD configurations
- Use only the Microsoft-provided NVMe driver (`stornvme.sys`) — third-party NVMe drivers are not supported
- NVMe devices are approximately 30% more expensive but deliver 300%+ more performance than comparable SSDs

#### SSD Requirements

- All SSDs must include **power-loss protection (PLP)** to protect write cache data during power failures. Consumer-grade SSDs without PLP are not supported and can cause data corruption.
- Cache SSDs require high write endurance:
  - Minimum: **3 DWPD** (Drive Writes Per Day) or **4 TBW/day** (Terabytes Written per day)
  - Enterprise read-intensive SSDs (typically 1 DWPD) are insufficient for cache use
- Cache devices must be **32 GB or larger**

#### Drive Symmetry

- Use the **same number and type of drives** in every server. Asymmetric drive configurations cause uneven pool utilization and are not officially supported for production.
- The number of capacity drives should be a **whole multiple of the number of cache drives** per server (e.g., 2 NVMe cache + 4 SSD capacity = 2:4 ratio = 2x multiple).
- Replace failed drives with **identical model and capacity** drives.

#### Drive Interface Support

| Supported | Not Supported |
|-----------|--------------|
| Direct-attached SATA | RAID controllers (unless in HBA pass-through mode) |
| Direct-attached NVMe | Shared SAS enclosures (multi-path to multiple servers) |
| SAS HBA with SAS drives | Fibre Channel, iSCSI, FCoE |
| SAS HBA with SATA drives | Multi-path I/O (MPIO) for S2D drives |
| Single-server JBOD with SES | — |

RAID controllers used for S2D drives must operate in **simple pass-through (HBA) mode only**. No RAID controller should manage RAID sets for S2D drives.

#### All-Flash vs. Hybrid

- **All-Flash (NVMe only or SSD only)**: Cache is disabled. Maximum performance. Best for latency-sensitive workloads (databases, VDI).
- **All-Flash NVMe + SSD**: NVMe acts as write cache for SSD capacity. Excellent performance and endurance balance.
- **Hybrid (SSD/NVMe + HDD)**: Best cost/TB. Read/write cache dramatically reduces HDD latency. Suitable for general file server and archival workloads.

---

## Network Design

### Bandwidth Requirements

| Cluster Size | Minimum NIC Speed | Recommended |
|-------------|-------------------|-------------|
| 2–3 nodes   | 10 Gbps           | 25 Gbps with RDMA |
| 4+ nodes    | 25 Gbps with RDMA | 100 Gbps with RDMA |

- Two or more network connections per node recommended for redundancy and throughput
- Ensure total network bandwidth is sufficient for:
  - East-west storage traffic (Software Storage Bus replication)
  - VM live migration traffic
  - Management traffic
  - External client access (for Scale-Out File Server / SoFS)

### RDMA Configuration

RDMA is not mandatory but strongly recommended. It increases S2D performance by approximately 15% on average and reduces CPU utilization for storage I/O.

#### iWARP (Recommended for Most Deployments)
- Works over standard TCP/IP on any Ethernet switch
- No special switch configuration required beyond standard network setup
- Easier to deploy and troubleshoot
- Supported vendors: Intel, Chelsio, Broadcom

#### RoCE (Higher Performance, More Complex)
- Requires **Priority Flow Control (PFC)** on switches to prevent packet drops
- Requires careful switch configuration (QoS, DSCP marking, ECN)
- Higher potential throughput than iWARP
- Supported vendors: Mellanox/NVIDIA, Broadcom, Marvell
- In scenarios where RoCE network device and switch configuration is imperfect, use iWARP to avoid storage disruptions

### Network Adapter Teaming

- Use **Switch Embedded Teaming (SET)** for NIC teaming on S2D hosts (standard NIC teaming is not supported with RDMA)
- SET requires all NIC adapters in the team to use identical drivers and firmware versions
- Configure at least 2 physical NICs per SET team for redundancy

### Network Segregation

Consider separating traffic types using VLANs or dedicated NICs:

| Traffic Type | Priority |
|-------------|---------|
| Storage (Software Storage Bus, SMB) | Highest (QoS 802.1p priority 6–7) |
| Live Migration | High (QoS 802.1p priority 5) |
| Cluster Heartbeat | High |
| Management | Medium |
| VM External Traffic | Normal |

### Switchless Configurations

For 2-node clusters, a switchless (direct-connect) network is supported:
- Each node directly connects to the other via crossover or direct-attach cables
- Eliminates switch as a failure domain
- Not practical for 3+ node clusters

---

## Cache Configuration Best Practices

### Ratio of Cache to Capacity

- Recommended: **1 cache drive per 4 capacity drives** (1:4 ratio)
- Minimum: 2 cache drives per server (for any configuration using SBL cache)
- The cache acts as a buffer — undersizing it reduces effectiveness during write bursts

### Cache Drive Sizing

Cache drives should be sized based on the "working set" of data — the amount of data actively read/written at any given time. A common guideline:
- Start with cache drives totaling **10% of capacity tier size** as a minimum
- For write-intensive workloads (databases), larger cache improves write absorption
- For read-intensive workloads, cache hit rate depends on working set fitting in cache

### Write Cache Behavior in Nested Resiliency (2-Node)

Enable automatic write cache disabling when one server is down (for hybrid clusters with HDD capacity):

```powershell
Get-StorageSubSystem Cluster* | Set-StorageHealthSetting `
    -Name "System.Storage.NestedResiliency.DisableWriteCacheOnNodeDown.Enabled" `
    -Value "True"
```

This protects against a cache drive failure when the other server is already offline. After 30 minutes of a server being down, write caching is disabled and data is flushed to capacity drives.

---

## Volume Sizing and Design

### Volume Count and Sizing Guidelines

- Create **one volume per workload type** to allow targeted performance monitoring and separate resiliency settings
- Individual volume maximum size: limited by pool capacity and resiliency overhead
- Dell recommends individual storage spaces **no larger than 10 TB** for manageability
- For Hyper-V, keep VM files organized in separate volumes by workload tier (e.g., Gold/Silver/Bronze)

### Thin vs. Fixed Provisioning

- **Fixed provisioning**: Allocates full physical space at creation. Predictable capacity consumption. No risk of over-commitment.
- **Thin provisioning** (WS2025 / Azure Local 22H2+): Allocates space on demand. Enables over-commitment. Monitor pool free space carefully to avoid pool exhaustion, which causes all volumes to go read-only.

### Interleave (Stripe Unit) Size

The default interleave size is **256 KB**. This is appropriate for most workloads. For specific workload types:

| Workload | Recommended Interleave |
|----------|----------------------|
| General purpose / VMs | 256 KB (default) |
| SQL Server (databases) | 64 KB |
| SQL Server (logs) | 64 KB |
| Archive / large sequential | 256 KB or larger |

```powershell
# Create virtual disk with custom interleave
New-VirtualDisk -StoragePoolFriendlyName "S2D*" -FriendlyName "SQLData" `
    -ResiliencySettingName Mirror -NumberOfDataCopies 3 `
    -Size 2TB -Interleave 65536
```

### ReFS vs. NTFS

- Always use **ReFS** for Hyper-V VM storage on S2D (mandatory for CSV volumes with S2D)
- NTFS is only appropriate for non-virtualization workloads that specifically require NTFS features
- ReFS deduplication (WS2025+) now extends dedup benefits to ReFS volumes

---

## Cluster Validation

Run cluster validation **before** enabling S2D and after any significant hardware changes:

```powershell
# Full cluster validation
Test-Cluster -Node "Server01","Server02","Server03","Server04" `
    -Include "Storage Spaces Direct","Inventory","Network","System Configuration"
```

Validation tests critical for S2D:
- Drive compatibility and identification
- Network configuration (bandwidth, RDMA, SMB)
- Drive firmware versions
- SES (SCSI Enclosure Services) for JBOD enclosures
- Drive symmetry across nodes

**Important**: All validation tests must pass before production deployment. Do not ignore failed tests.

---

## Fault Domain Planning

- Define fault domains **before** enabling S2D. Fault domain data affects pool and volume configuration at creation time.
- For rack-aware clusters with erasure coding (parity): requires **minimum 4 racks** with equal node counts
- For chassis-aware blade deployments: define chassis boundaries before pool creation
- Map physical hardware locations carefully — S2D does not validate that fault domains match physical reality

```powershell
# Pre-deployment fault domain setup
New-ClusterFaultDomain -Type Rack -Name "Rack-01"
New-ClusterFaultDomain -Type Rack -Name "Rack-02"
Set-ClusterFaultDomain -Name "Server01","Server02" -Parent "Rack-01"
Set-ClusterFaultDomain -Name "Server03","Server04" -Parent "Rack-02"

# Then enable S2D
Enable-ClusterStorageSpacesDirect
```

---

## Monitoring with Windows Admin Center

Windows Admin Center (WAC) is the primary graphical management tool for S2D clusters.

### Key Monitoring Dashboards

- **Cluster Dashboard**: Overall cluster health, capacity usage, performance trends
- **Storage Dashboard**: Pool health, drive status, volume capacity
- **Drive Inventory**: Per-drive health, media type, capacity, usage
- **Volume Management**: Create, resize, and monitor individual volumes
- **Performance Charts**: Historical IOPS, throughput, and latency with selectable timeframes (Hour/Day/Week/Month/Year)
- **Alerts**: Health Service alerts for drive failures, low capacity, performance anomalies

### Setting Up Windows Admin Center Monitoring

1. Install Windows Admin Center on a management server (not on S2D cluster nodes)
2. Add the cluster connection using the cluster name or IP
3. Enable the Performance History collection: enabled by default on WS2019+
4. Configure alert notifications via email or integration with monitoring tools

### Performance History via PowerShell

```powershell
# Get cluster-wide IOPS for the last day
Get-Cluster | Get-ClusterPerf -ClusterSeriesName "PhysicalDisk.Iops.Total" -TimeFrame LastDay

# Get volume latency over last week
Get-Volume -FriendlyName "Vol01" | Get-ClusterPerf `
    -VolumeSeriesName "Volume.Latency.Average" -TimeFrame LastWeek

# Get all series for a specific drive
Get-PhysicalDisk -SerialNumber "SN12345" | Get-ClusterPerf -TimeFrame LastHour
```

### Health Service Monitoring

The Health Service provides continuous automated monitoring and alerting:

```powershell
# View all current health faults
Get-HealthFault

# View Health Service reports
Get-StorageSubSystem Cluster* | Get-StorageHealthReport

# View storage jobs (repair, rebuild operations)
Get-StorageJob

# Monitor repair progress
Get-StorageJob | Where-Object { $_.JobState -eq "Running" }
```

---

## Performance Tuning

### Storage QoS

Use Storage QoS to prevent noisy-neighbor VMs from consuming all IOPS:

```powershell
# Create QoS policies
New-StorageQosPolicy -Name "Gold"   -MinimumIops 1000 -MaximumIops 10000
New-StorageQosPolicy -Name "Silver" -MinimumIops  500 -MaximumIops  5000
New-StorageQosPolicy -Name "Bronze" -MinimumIops  100 -MaximumIops  2000

# Apply policy to a VM's storage
Get-VM "CriticalVM" | Set-VMHardDiskDrive -StorageQoSPolicyID `
    (Get-StorageQosPolicy -Name "Gold").PolicyId
```

### Storage Pool Optimization

Run pool optimization after adding drives or nodes:

```powershell
# Optimize drive usage in the storage pool
Optimize-StoragePool -FriendlyName "S2D on ClusterName"

# Check if optimization is needed
Get-VirtualDisk | Where-Object { $_.OperationalStatus -eq "Suboptimal" }
```

### CSV In-Memory Read Cache

For Hyper-V hyperconverged deployments, configure the CSV in-memory read cache to absorb frequently accessed VM reads:

```powershell
# Set CSV cache size to 1 GB per node
(Get-Cluster).BlockCacheSize = 1024

# Verify current CSV cache setting
(Get-Cluster).BlockCacheSize
```

The CSV cache caches unbuffered I/O reads in server RAM. This is especially beneficial for:
- VDI deployments with high read demand for common OS blocks
- Frequently accessed read-only datasets

### Drive Write Cache

For HDDs, ensure write caching is enabled at the disk controller level (with battery-backed or supercapacitor protection). HDD write cache improves write performance significantly.

### CPU and NUMA Considerations

- Enable NUMA topology awareness in Hyper-V VM settings for large VM deployments
- Avoid oversubscribing CPU when storage QoS policies create queuing; storage I/O processing competes with VM execution

### Recommended Baseline Performance Targets

Use VMFleet and DiskSpd to establish performance baselines before production deployment:

```powershell
# Install VMFleet from PowerShell Gallery
Install-Module -Name VMFleet

# Run DiskSpd directly for storage benchmarking
diskspd.exe -c10G -d30 -r -w30 -t4 -o32 -b4K -L C:\ClusterStorage\Volume1\testfile.dat
```

---

## Maintenance Best Practices

### Node Maintenance (Patching)

Always use storage maintenance mode when patching or rebooting a node to prevent unnecessary repair jobs:

```powershell
# Step 1: Suspend node and drain VMs
Suspend-ClusterNode -Name "Server01" -Drain

# Step 2: Put disks into storage maintenance mode
Get-StorageFaultDomain -Type StorageScaleUnit | `
    Where-Object { $_.FriendlyName -eq "Server01" } | `
    Enable-StorageMaintenanceMode

# Step 3: Verify maintenance mode is active
Get-PhysicalDisk | Where-Object { $_.OperationalStatus -eq "In Maintenance Mode" }

# Step 4: Patch and reboot the node
Restart-Computer -ComputerName "Server01" -Force

# Step 5: After reboot, exit maintenance mode
Get-StorageFaultDomain -Type StorageScaleUnit | `
    Where-Object { $_.FriendlyName -eq "Server01" } | `
    Disable-StorageMaintenanceMode

# Step 6: Resume node
Resume-ClusterNode -Name "Server01"

# Step 7: Monitor resync
Get-StorageJob
```

### Firmware Updates

- Update drive firmware during maintenance windows using the storage maintenance mode procedure
- Keep NIC firmware and drivers current (RDMA behavior depends on firmware)
- Validate post-update with `Test-Cluster` before returning to production

### Capacity Planning

Monitor pool free space continuously:
- Alert when pool is **80% full** to allow time for remediation
- Alert critically at **90% full** — thin-provisioned volumes become read-only at pool exhaustion
- Scale out (add nodes or drives) before reaching capacity limits

```powershell
# Check pool capacity
Get-StoragePool -IsPrimordial $False | Select-Object FriendlyName,
    @{N="FreeGB";E={[math]::Round($_.RemainingCapacityBytes/1GB,1)}},
    @{N="TotalGB";E={[math]::Round($_.Size/1GB,1)}},
    @{N="UsedPct";E={[math]::Round((1 - $_.RemainingCapacityBytes/$_.Size)*100,1)}}
```

---

## References

- [Storage Spaces Direct Hardware Requirements - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-direct-hardware-requirements)
- [Storage Spaces Direct overview - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-direct-overview)
- [Fault domain awareness - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/failover-clustering/fault-domains)
- [Nested resiliency for Storage Spaces Direct - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/nested-resiliency)
- [Performance history for Storage Spaces Direct - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/performance-history)
- [Storage Spaces Direct best practices - Source One Technology](https://www.sourceonetechnology.com/storage-spaces-direct/)
- [Best practices for Storage Spaces Direct in Windows Server 2019 - BDRShield](https://www.bdrshield.com/blog/windows-server-2019-storage-spaces-direct-best-practices/)
- [Design the network for a Storage Spaces Direct cluster - Tech-Coffee](https://www.tech-coffee.net/design-the-network-for-a-storage-spaces-direct-cluster/)
