# Storage Spaces Direct Features by Version

## Feature Matrix Overview

Storage Spaces Direct (S2D) capabilities have evolved significantly across Windows Server versions and Azure Local releases. This document tracks what was introduced when and what is available in each platform generation.

---

## Windows Server 2016 — Initial Release

Windows Server 2016 introduced S2D as a production-ready feature in the Datacenter edition. Key capabilities at launch:

### Core Capabilities
- Software Storage Bus — software-defined storage fabric over Ethernet
- Automatic drive discovery and pool creation
- Two-way mirror, three-way mirror, and parity (erasure coding) resiliency
- Storage Bus Layer (SBL) cache — server-side NVMe/SSD cache for HDD capacity
- Cluster Shared Volumes (CSV) with ReFS
- Scale-Out File Server (SoFS) for converged deployments
- Hyper-V hyperconverged integration
- Storage QoS (Quality of Service) with per-VM IOPS min/max policies
- Fault domain awareness (site, rack, chassis, node)
- SMB Direct (RDMA) support via iWARP and RoCE
- SMB Multichannel for bandwidth aggregation
- Support for 2–16 nodes per cluster
- Maximum 1 PB pool capacity, 100 TB per server

### Limitations in WS2016
- No performance history collection (added in WS2019)
- No nested resiliency (added in WS2019)
- Maximum 1 PB pool; 100 TB per server
- No thin provisioning
- Limited storage repair throttling control
- No SMB encryption for east-west traffic

---

## Windows Server 2019 — Major Feature Additions

Windows Server 2019 delivered substantial enhancements to S2D with features focused on two-node deployments, observability, and scale.

### Nested Resiliency (New in WS2019)

Nested resiliency is designed exclusively for **two-node clusters** and enables tolerance of multiple simultaneous hardware failures — something traditional two-way mirroring cannot provide.

#### Nested Two-Way Mirror
- Stores 4 copies of all data (2 on each server, on different physical disks per server)
- Tolerates: any drive failure + the other server going offline simultaneously
- Storage efficiency: **25%** (lowest of any S2D option)
- Performance: Full read/write from any copy; highest IOPS

#### Nested Mirror-Accelerated Parity
- Combines server-local two-way mirror with server-local single parity
- Data is mirrored between both servers for cross-server resiliency
- Storage efficiency: **35–40%** (varies by drive count and mirror/parity ratio)
- Typical ratios: 10–30% mirror, 70–90% parity

**Capacity efficiency table for nested mirror-accelerated parity:**

| Capacity drives per server | 10% mirror | 20% mirror | 30% mirror |
|----------------------------|-----------|-----------|-----------|
| 4                          | 35.7%     | 34.1%     | 32.6%     |
| 5                          | 37.7%     | 35.7%     | 33.9%     |
| 6                          | 39.1%     | 36.8%     | 34.7%     |
| 7+                         | 40.0%     | 37.5%     | 35.3%     |

**Requirements for nested resiliency:**
- Exactly 2 server nodes
- Windows Server 2019 or later (or Azure Local 22H2+)
- Cannot convert existing volumes between resiliency types

**Creating nested resiliency volumes (WS2019 — requires tier templates first):**

```powershell
# Step 1: Create tier templates (WS2019 only; skip on WS2022+)
New-StorageTier -StoragePoolFriendlyName S2D* -FriendlyName NestedMirrorOnHDD `
    -ResiliencySettingName Mirror -MediaType HDD -NumberOfDataCopies 4

New-StorageTier -StoragePoolFriendlyName S2D* -FriendlyName NestedParityOnHDD `
    -ResiliencySettingName Parity -MediaType HDD -NumberOfDataCopies 2 `
    -PhysicalDiskRedundancy 1 -NumberOfGroups 1 `
    -FaultDomainAwareness StorageScaleUnit -ColumnIsolation PhysicalDisk

# Step 2: Create nested two-way mirror volume
New-Volume -StoragePoolFriendlyName S2D* -FriendlyName "Vol-Mirror" `
    -StorageTierFriendlyNames NestedMirrorOnHDD -StorageTierSizes 500GB

# Step 2 alt: Create nested mirror-accelerated parity (20% mirror / 80% parity)
New-Volume -StoragePoolFriendlyName S2D* -FriendlyName "Vol-MAP" `
    -StorageTierFriendlyNames NestedMirrorOnHDD, NestedParityOnHDD `
    -StorageTierSizes 100GB, 400GB
```

### Performance History (New in WS2019)

S2D automatically collects and stores performance metrics for up to one year, with no configuration required.

#### What is Collected

| Object Type | Example Series |
|-------------|---------------|
| Drives | `PhysicalDisk.Iops.Read`, `PhysicalDisk.Latency.Write`, `PhysicalDisk.Throughput.Total` |
| Network adapters | `NetAdapter.Bandwidth.Inbound`, `NetAdapter.Bandwidth.Outbound` |
| Servers (nodes) | `ClusterNode.Cpu.Usage`, `ClusterNode.Memory.Available` |
| Virtual hard disks | `Vhd.Size.Current`, `Vhd.Iops.Total` |
| Virtual machines | `Vm.Cpu.Usage`, `Vm.Memory.Assigned` |
| Volumes | `Volume.Iops.Total`, `Volume.Latency.Average`, `Volume.Throughput.Total` |
| Clusters | Aggregated metrics across all above object types |

#### Retention Timeframes

| Timeframe | Measurement Interval | Retained For |
|-----------|---------------------|-------------|
| LastHour  | Every 10 seconds    | 1 hour      |
| LastDay   | Every 5 minutes     | 25 hours    |
| LastWeek  | Every 15 minutes    | 8 days      |
| LastMonth | Every 1 hour        | 35 days     |
| LastYear  | Every 1 day         | 400 days    |

Storage: Automatically creates an approximately 10 GB `ClusterPerformanceHistory` volume backed by ReFS (not CSV). Data is stored in an Extensible Storage Engine (JET) database.

```powershell
# Query performance history
Get-ClusterPerformanceHistory
Get-VM "MyVM" | Get-ClusterPerf -VMSeriesName "VM.Cpu.Usage" -TimeFrame LastHour
Get-Volume -FriendlyName "Vol01" | Get-ClusterPerf -VolumeSeriesName "Volume.Latency.Write"
Get-PhysicalDisk -SerialNumber "ABC123" | Get-ClusterPerf

# Enable/disable performance history
Start-ClusterPerformanceHistory
Stop-ClusterPerformanceHistory -DeleteHistory
```

### Scale Improvements in WS2019
- Maximum raw capacity per server increased from 100 TB to **400 TB**
- Maximum pool capacity increased from 1 PB to **4 PB** (4,000 TB)

### Fault Domain Awareness (WS2019)
- Available but disabled by default; must be enabled via registry
- `(Get-Cluster).AutoAssignNodeSite = 1`

---

## Windows Server 2022 — Security and Performance

Windows Server 2022 focused on security, SMB improvements, and storage reliability.

### SMB Encryption for East-West Traffic (New in WS2022)

S2D clusters can now encrypt intra-cluster SMB storage traffic (the Software Storage Bus communications between nodes):

- Supports **AES-128-GCM** and **AES-256-GCM** encryption
- SMB Direct (RDMA) encryption supported — data is encrypted before placement on the wire
- Minimal performance degradation compared to earlier implementations
- Protects against insider threats and compromised network equipment

```powershell
# Enable SMB encryption for S2D east-west traffic
Set-SMBServerConfiguration -EncryptData $true
```

### SMB Compression (New in WS2022)
- SMB3 compression reduces network bandwidth for data transfer between nodes
- Useful for hybrid (HDD-based) clusters where bandwidth is a bottleneck

### Nested Resiliency Improvements (WS2022)
- Windows Server 2022 and Azure Stack HCI 21H2+ no longer require storage tier template creation step
- Volumes can be created directly with nested resiliency parameters

```powershell
# WS2022+ simplified nested volume creation (no tier template needed)
New-Volume -StoragePoolFriendlyName S2D* -FriendlyName "NestedVol" `
    -ResiliencySettingName Mirror -NumberOfDataCopies 4 -Size 500GB
```

### Storage Spaces Direct Reliability
- Improved handling of RoCE congestion and transient network failures
- Enhanced SMB resilient handles behavior

---

## Windows Server 2025 — Major Storage Feature Update

Windows Server 2025 brought the most significant storage enhancements to S2D since its 2016 introduction.

### Thin Provisioning (New in WS2025)

Thin provisioning allows virtual disks to be allocated a logical size larger than the actual physical storage consumed. Space is consumed from the pool only as data is written.

- Allows overcommitting physical storage capacity
- Dynamic utilization of pool storage — volumes grow on demand
- Supported in Azure Local 22H2+; now available natively in Windows Server 2025

```powershell
# Create thin-provisioned volume
New-Volume -StoragePoolFriendlyName S2D* -FriendlyName "ThinVol" `
    -ResiliencySettingName Mirror -Size 10TB -ProvisioningType Thin
```

### NVMe over Fabrics (NVMe-OF) Initiator (New in WS2025)
- Built-in NVMe-OF initiator for connecting to external NVMe storage arrays
- Delivers up to **90% more IOPS** over NVMe storage compared to previous protocols
- Complements S2D's internal NVMe support with external NVMe connectivity

### ReFS Deduplication and Compression (New in WS2025)
- Inline deduplication and compression now supported on ReFS volumes
- Previously, deduplication was only available on NTFS volumes in Windows Server
- Two compression algorithms available:
  - **Compression-ratio optimized**: Higher compression at the cost of more CPU
  - **Speed optimized**: Faster operation with moderate compression ratio
- Manageable via Windows Admin Center or PowerShell

```powershell
# Enable ReFS deduplication on a volume (WS2025+)
Enable-DedupVolume -Volume "C:\ClusterStorage\Volume1" -UsageType HyperV
```

### Rack-Local Reads (New in WS2025)
- S2D uses cluster topology information during read operation scheduling
- Reads are served from the closest healthy copy (within the same rack when possible)
- Reduces cross-rack network traffic and latency in rack-aware clusters
- Automatically applied when rack fault domains are configured

### Storage Repair Speed Improvements
- Enhanced storage job prioritization and throttling controls
- Improved resync performance after node maintenance
- Better handling of storage repair during active workloads

---

## Azure Stack HCI / Azure Local Features

Azure Stack HCI (renamed Azure Local in version 23H2) extends S2D with cloud-connected capabilities.

### Azure Stack HCI 20H2 (Initial Release)
- S2D as core storage engine
- Azure-registered cluster management
- Azure Monitor integration
- Azure Kubernetes Service (AKS) on HCI preview

### Azure Stack HCI 21H2
- AKS on HCI general availability
- Improved cluster deployment experience
- Windows Admin Center integration improvements
- Azure Arc integration for VMs

### Azure Stack HCI 22H2
- **Thin provisioning** for S2D volumes (before WS2025 desktop)
- **Volume resiliency modification**: Convert existing volumes from two-way to three-way mirror without data loss
- **Fixed-to-thin conversion**: Change in-place from fixed to thin provisioning
- **Storage Replica compression**: Compresses replication traffic between source and destination, reducing bandwidth consumption
- Improved storage pool management

```powershell
# Convert volume resiliency (22H2+)
Set-VirtualDisk -FriendlyName "Vol01" -ResiliencySettingName "Mirror" -NumberOfDataCopies 3

# Convert to thin provisioning (22H2+)
Set-VirtualDisk -FriendlyName "Vol01" -ProvisioningType Thin
```

### Azure Stack HCI 23H2 / Azure Local 23H2
- Rebranded to **Azure Local**
- Azure Arc-enabled operating system (mandatory cloud connectivity)
- Azure-managed deployment workflow (replaces manual cluster setup)
- **Azure Lifecycle Manager (LCM)**: Cloud-based update orchestration for the entire stack (OS, drivers, firmware, agents)
- Cloud-based monitoring via Azure Monitor and Azure Stack HCI Insights
- Simplified Arc VM management (create, manage, and monitor VMs from Azure portal)
- Enhanced security posture with Secured-Core Server requirements
- Network ATC (Automatic TCP/IP Configuration) for simplified network configuration

---

## Feature Comparison Table

| Feature | WS2016 | WS2019 | WS2022 | WS2025 | Azure Local 22H2 | Azure Local 23H2 |
|---------|--------|--------|--------|--------|-----------------|-----------------|
| S2D Core | Yes | Yes | Yes | Yes | Yes | Yes |
| Nested resiliency | No | Yes | Yes | Yes | Yes | Yes |
| Performance history | No | Yes | Yes | Yes | Yes | Yes |
| Thin provisioning | No | No | No | Yes | Yes | Yes |
| SMB east-west encryption | No | No | Yes | Yes | Yes | Yes |
| ReFS deduplication | No | No | No | Yes | No | No |
| NVMe-OF initiator | No | No | No | Yes | No | Yes |
| Rack-local reads | No | No | No | Yes | No | Yes |
| Volume resiliency change | No | No | No | No | Yes | Yes |
| Storage Replica compression | No | No | No | No | Yes | Yes |
| Azure Arc integration | No | No | No | No | Optional | Mandatory |
| Max pool capacity | 1 PB | 4 PB | 4 PB | 4 PB | 4 PB | 4 PB |
| Max per-server capacity | 100 TB | 400 TB | 400 TB | 400 TB | 400 TB | 400 TB |
| Max nodes | 16 | 16 | 16 | 16 | 16 | 16 |

---

## References

- [Storage Spaces Direct overview - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-direct-overview)
- [Nested resiliency for Storage Spaces Direct - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/nested-resiliency)
- [Performance history for Storage Spaces Direct - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/performance-history)
- [What's new in Azure Stack HCI 23H2 - Microsoft Learn](https://learn.microsoft.com/en-us/azure-stack/hci/whats-new)
- [New storage features in Windows Server 2025 - 4sysops](https://4sysops.com/archives/new-storage-features-in-windows-server-2025-nvme-of-initiator-update-for-s2d-deduplication-for-refs/)
- [What's new in Azure Local 23H2 - Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-local/whats-new)
