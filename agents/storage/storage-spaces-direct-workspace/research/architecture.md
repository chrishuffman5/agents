# Storage Spaces Direct (S2D) Architecture

## Overview

Storage Spaces Direct (S2D) is a software-defined storage (SDS) feature of Windows Server and Azure Local (formerly Azure Stack HCI). It clusters 2 to 16 industry-standard servers with internal direct-attached storage into a single software-defined pool of virtually shared storage — eliminating the need for external SANs, Fibre Channel, or shared SAS fabrics.

S2D supports both **hyperconverged** and **converged** deployment topologies:

- **Hyperconverged**: Compute and storage on the same nodes. Hyper-V VMs run directly on the S2D cluster nodes, storing files on local CSV volumes. This is the only topology supported by Azure Local.
- **Converged (disaggregated)**: A dedicated S2D storage cluster exposes storage over SMB3 file shares to a separate compute cluster running Hyper-V. Allows independent scaling of compute and storage.

---

## Full Stack Layers

The S2D stack consists of the following layers from bottom to top:

```
[Networking Hardware]  - Physical NICs, switches
[Storage Hardware]     - NVMe, SSD, HDD, PMem drives
[Failover Clustering]  - Windows Server Failover Cluster
[Software Storage Bus] - Software-defined storage fabric
[Storage Bus Cache]    - Server-side read/write cache tier
[Storage Pool]         - Single unified pool from all drives
[Storage Spaces]       - Virtual disks with resiliency (mirror/parity)
[ReFS]                 - Resilient File System on each virtual disk
[CSV]                  - Cluster Shared Volumes namespace
[Scale-Out File Server]- (Converged only) SMB3 NAS layer
```

---

## Software Storage Bus

The Software Storage Bus is the foundational technology that makes S2D possible. It spans the entire cluster and establishes a software-defined storage fabric in which every server can see and use every other server's local drives. It replaces the physical shared storage fabric (Fibre Channel cables, shared SAS enclosures) with a software layer running over Ethernet.

Key characteristics:
- Operates over the same Ethernet network used for cluster traffic (via SMB3)
- Enables any-to-any drive visibility across all nodes
- The bus uses SMB Direct (RDMA) for low-latency, high-throughput inter-node drive access
- Does not require specialized storage networking hardware

---

## Storage Bus Layer (SBL) Cache

The Storage Bus Layer cache is a server-side caching mechanism that operates at the Software Storage Bus level, below the storage pool. It automatically designates the fastest drives present as cache devices and binds them to slower capacity drives.

### Cache Assignment Logic

S2D automatically determines cache vs. capacity based on media type priority:

| Media Types Present | Cache Tier | Capacity Tier |
|---------------------|-----------|---------------|
| NVMe + SSD          | NVMe      | SSD           |
| NVMe + HDD          | NVMe      | HDD           |
| SSD + HDD           | SSD       | HDD           |
| All NVMe (same)     | None (disabled) | NVMe    |
| All SSD (same)      | None (disabled) | SSD     |
| All HDD             | Not supported   | -       |

When all drives are of the same type, the SBL cache is disabled because the performance benefit is minimal.

### Cache Behavior

- **Writes**: All writes go to cache first (write-back cache), then are destaged to capacity drives asynchronously. This absorbs write bursts and improves write latency.
- **Reads**: In hybrid (SSD+HDD) configurations, frequently read data is promoted to cache. In NVMe+SSD configurations, read caching is disabled by default because SSD reads are already fast; NVMe absorbs writes only.
- **Cache device requirement**: Cache drives must be 32 GB or larger; high write endurance recommended (3+ DWPD or 4+ TBW/day).

### Storage Bus Cache State Indicators (Cluster Log)

- `CacheDiskStateInitializedAndBound` — Cache active and bound to capacity drive
- `CacheDiskStateNonHybrid` — All drives same type; cache disabled
- `CacheDiskStateIneligibleDataPartition` — Drive ineligible for cache

---

## Storage Pool

The storage pool is the single unified collection of all eligible drives across all cluster nodes. S2D creates exactly one storage pool per cluster by default.

Key pool characteristics:
- All eligible drives are automatically discovered and added
- One pool per cluster is strongly recommended
- Pool metadata is distributed and written to every drive in the pool
- Maximum pool capacity: 4 PB (4,000 TB) on Windows Server 2019+; 1 PB on Windows Server 2016
- Maximum raw capacity per server: 400 TB (WS2019+); 100 TB (WS2016)
- The pool provides the raw material from which virtual disks are carved

Pool health states: **Healthy**, **Warning** (degraded), **Unknown/Unhealthy** (read-only)

```powershell
# View pool status
Get-StoragePool -IsPrimordial $False | Select-Object FriendlyName, HealthStatus, OperationalStatus, ReadOnlyReason
```

---

## Storage Tiers (Cache and Capacity Tiers)

When different media types exist, S2D creates two default storage tiers within the pool:

- **Performance tier**: Fastest media (e.g., NVMe or SSD). Used for hot data or mirror portions of mirror-accelerated parity volumes.
- **Capacity tier**: Slower media (e.g., HDD or SSD when NVMe is cache). Used for bulk storage, cold data, and parity portions of tiered volumes.

ReFS real-time tiering can automatically move data between hot and cold tiers based on access patterns.

---

## Virtual Disks and Resiliency

Virtual disks (storage spaces) are carved from the pool and provide fault tolerance through one of three resiliency types:

### Two-Way Mirror
- Keeps 2 copies of all data across different drives/servers
- Tolerates 1 drive or 1 server failure
- ~50% storage efficiency
- Used in 2-node clusters

### Three-Way Mirror
- Keeps 3 copies across different drives/servers
- Tolerates 2 simultaneous drive or server failures
- ~33% storage efficiency
- Used in 3+ node clusters

### Mirror-Accelerated Parity (MAP)
- Hybrid: mirror portion absorbs new writes; parity portion stores cold data
- Parity uses erasure coding (similar to RAID 5/6)
- Up to 2.4x more storage efficient than mirroring
- Local Reconstruction Codes (LRC) minimize CPU overhead
- Best for general-purpose file servers with mixed hot/cold workloads

### Nested Resiliency (2-node specific)
See the features.md file for full detail. Summary:
- **Nested two-way mirror**: 4 copies (2 per server); 25% efficiency; highest resilience
- **Nested mirror-accelerated parity**: ~35-40% efficiency; tolerates multiple simultaneous failures

### Key Virtual Disk Properties
- Interleave (stripe unit) default: 256 KB; recommended 64 KB for SQL Server workloads
- Resiliency is set per virtual disk at creation time; cannot be changed in-place

```powershell
# Create a 3-way mirror virtual disk
New-VirtualDisk -StoragePoolFriendlyName "S2D*" -FriendlyName "Vol01" `
    -ResiliencySettingName Mirror -NumberOfDataCopies 3 -Size 2TB -ProvisioningType Fixed

# Create a mirror-accelerated parity volume via New-Volume
New-Volume -StoragePoolFriendlyName "S2D*" -FriendlyName "Vol02" `
    -StorageTierFriendlyNames "Performance", "Capacity" `
    -StorageTierSizes 200GB, 2TB -FileSystem CSVFS_ReFS
```

---

## Resilient File System (ReFS)

ReFS is the mandatory filesystem for S2D volumes. It is purpose-built for virtualization workloads and provides:

- **Integrity streams**: Built-in checksums on both data and metadata to detect and correct silent data corruption (bit rot)
- **Accelerated VHDX operations**: Hardware-offloaded creation, expansion, and checkpoint merging of .vhd/.vhdx files (via block cloning)
- **Real-time tiering**: Automatically moves data between hot (Performance) and cold (Capacity) tiers based on access frequency
- **Mirror-accelerated parity**: Native support for MAP volumes with automatic data movement from mirror to parity stripe
- **No defragmentation required**: ReFS does not require or support traditional defragmentation
- **Large volume support**: Supports volumes up to 35 PB
- **ReFS deduplication and compression** (Windows Server 2025+): Inline deduplication and compression support for ReFS volumes, manageable via Windows Admin Center or PowerShell

---

## Cluster Shared Volumes (CSV)

CSV provides a unified shared namespace over all ReFS volumes, accessible simultaneously from every node in the cluster.

Key CSV characteristics:
- All volumes appear under `C:\ClusterStorage\` on every node
- Each volume looks and acts as if locally mounted regardless of which node owns the CSV
- Enables live migration of Hyper-V VMs without storage I/O interruption
- CSV uses a redirected I/O mode as fallback when the owning node is unavailable
- Performance history for S2D is stored in a special `ClusterPerformanceHistory` volume that is a ReFS volume but NOT a CSV

```powershell
# Add a virtual disk to CSV
Add-ClusterSharedVolume -Name "Cluster Virtual Disk (Vol01)"

# List all CSV volumes
Get-ClusterSharedVolume
```

---

## Fault Domains

Fault domains define the physical topology of the cluster hardware to ensure S2D places data copies in separate failure zones.

### Fault Domain Hierarchy

```
Site  >  Rack  >  Chassis  >  Node
```

- **Node**: Automatically discovered. The default fault domain level.
- **Chassis**: Used for blade server deployments where multiple nodes share a chassis power supply.
- **Rack**: Used when nodes are distributed across multiple physical racks.
- **Site**: Used for stretch cluster/campus cluster deployments across buildings or datacenters.

### Critical Planning Rule

Fault domains must be defined **before** enabling S2D. Once the pool and volumes are created, data does not retroactively redistribute when fault domain topology changes. To move a node between chassis/racks post-deployment, evict it with `Remove-ClusterNode -CleanUpDisks` first.

### Configuration via PowerShell

```powershell
# Create rack fault domains
New-ClusterFaultDomain -Type Rack -Name "Rack-A"
New-ClusterFaultDomain -Type Rack -Name "Rack-B"

# Assign nodes to racks
Set-ClusterFaultDomain -Name "Server01" -Parent "Rack-A"
Set-ClusterFaultDomain -Name "Server02" -Parent "Rack-A"
Set-ClusterFaultDomain -Name "Server03" -Parent "Rack-B"
Set-ClusterFaultDomain -Name "Server04" -Parent "Rack-B"
```

### Configuration via XML

```xml
<Topology>
  <Site Name="SEA" Location="Seattle HQ">
    <Rack Name="Rack-A" Location="Row 1">
      <Node Name="Server01" Location="U33" />
      <Node Name="Server02" Location="U35" />
    </Rack>
    <Rack Name="Rack-B" Location="Row 2">
      <Node Name="Server03" Location="U20" />
      <Node Name="Server04" Location="U22" />
    </Rack>
  </Site>
</Topology>
```

```powershell
# Apply XML fault domain topology
$xml = Get-Content "topology.xml" | Out-String
Set-ClusterFaultDomainXML -XML $xml
```

### Erasure Coding and Rack Fault Tolerance

For rack-fault-tolerant parity volumes (erasure coding), S2D requires at least 4 racks with equal node counts (4, 8, 12, or 16 nodes total). Each rack must have the same number of nodes.

### Windows Server 2025: Rack-Local Reads

Windows Server 2025 introduces Rack-Local Reads — an optimization where S2D uses cluster topology during read selection, preferring the closest healthy copy of data within the same rack, reducing cross-rack network traffic.

---

## SMB Direct and RDMA

S2D uses SMB3 for inter-node communication (storage traffic between nodes over the Software Storage Bus). SMB Direct leverages RDMA (Remote Direct Memory Access) for significant performance improvements.

### RDMA Protocols Supported

| Protocol | Description |
|----------|-------------|
| **iWARP** | RDMA over TCP/IP; works on standard Ethernet switches; recommended for most deployments |
| **RoCE** | RDMA over Converged Ethernet; requires Priority Flow Control (PFC) on switches; higher performance but more complex configuration |

### RDMA Benefits

- Reduces CPU overhead for storage I/O (kernel bypass)
- Provides consistent low latency
- Increases throughput by approximately 15% on average versus non-RDMA
- Required for optimal performance in 4+ node clusters and all high-performance deployments

### SMB Multichannel

SMB Multichannel aggregates multiple network connections per node for:
- Increased aggregate bandwidth
- NIC fault tolerance
- Load balancing across multiple paths

### SMB Encryption (Windows Server 2022+)

Windows Server 2022 added SMB Direct encryption, protecting east-west cluster storage traffic with AES-128 or AES-256 encryption with minimal performance degradation.

---

## Hyper-V Integration

In hyperconverged mode, Hyper-V runs directly on the S2D cluster nodes:

- VM files (.vhd, .vhdx, .avhd) are stored on CSV volumes under `C:\ClusterStorage\`
- Live migration moves VMs between nodes while storage remains on CSV (no data movement required)
- ReFS block cloning accelerates VM checkpoint creation and merging
- Storage QoS (Quality of Service) enforces minimum and maximum IOPS per VM
- Hyper-V benefits from hypervisor-embedded access to storage — I/O does not traverse the network when accessing local volumes

### Storage QoS

```powershell
# Set storage QoS policy on a VM
New-StorageQosPolicy -Name "Gold" -MinimumIops 500 -MaximumIops 5000
Get-VM "VM01" | Set-VMStorageQos -StorageQosPolicyId (Get-StorageQosPolicy "Gold").Id
```

---

## Azure Stack HCI / Azure Local Integration

Azure Stack HCI (rebranded to **Azure Local** as of version 23H2) is the premier deployment platform for S2D. It is a purpose-built hyperconverged operating system that uses S2D as its core storage technology.

Key differences from plain Windows Server S2D:

| Feature | Windows Server S2D | Azure Local (Azure Stack HCI) |
|---------|--------------------|-------------------------------|
| Deployment topology | Hyperconverged or Converged | Hyperconverged only |
| Max nodes per cluster | 16 | 16 |
| Azure Arc integration | No | Yes (mandatory as of 23H2) |
| Cloud-based monitoring | Optional | Native (Azure Monitor) |
| Deployment method | Manual / SCVMM | Azure-managed deployment (23H2+) |
| Update management | Windows Update / WSUS | Azure Lifecycle Manager (LCM) |
| Thin provisioning | WS2025+ | 22H2+ |
| Azure Arc VM management | No | Yes (23H2+) |

### Azure Local Versions

| Version | Key Features |
|---------|-------------|
| 20H2    | Initial Azure Stack HCI release with S2D as core |
| 21H2    | Improved cluster deployment, Azure Kubernetes Service (AKS) support |
| 22H2    | Thin provisioning, volume resiliency changes, Storage Replica compression |
| 23H2    | Azure Arc-enabled OS, Azure-based deployment, Lifecycle Manager, renamed to Azure Local |

---

## Cluster Architecture Summary

### Minimum Hardware Configuration (2-Node)

```
Node 1                          Node 2
+------------------+            +------------------+
| 2x NVMe (cache)  |  <10GbE+> | 2x NVMe (cache)  |
| 4x SSD (capacity)|  RDMA     | 4x SSD (capacity)|
+------------------+            +------------------+
         \                              /
          +-----------------------------+
          |   Software Storage Bus      |
          |   (SMB3 over Ethernet)      |
          +-----------------------------+
                      |
          +-----------------------------+
          |   Single Storage Pool       |
          |   (All drives unified)      |
          +-----------------------------+
                      |
          +-----------------------------+
          |   Virtual Disks (ReFS)      |
          |   CSV: C:\ClusterStorage\   |
          +-----------------------------+
                      |
          +-----------------------------+
          |   Hyper-V VMs               |
          +-----------------------------+
```

### Scale-Out Cluster (16-Node Maximum)

- Up to 16 nodes per S2D cluster
- Up to 400 TB raw capacity per server
- Up to 4 PB total pool capacity
- Over 400 drives per cluster
- Performance scales near-linearly with node count

---

## References

- [Storage Spaces Direct overview - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-direct-overview)
- [Storage Spaces Direct Hardware Requirements - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-direct-hardware-requirements)
- [Fault domain awareness - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/failover-clustering/fault-domains)
- [Nested resiliency for Storage Spaces Direct - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/nested-resiliency)
- [Performance history for Storage Spaces Direct - Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/performance-history)
