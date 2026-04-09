# Hyper-V on Windows Server — Deep-Dive Research

## Overview

Hyper-V is Microsoft's Type-1 (bare-metal) hypervisor, integrated into Windows Server since 2008 R2. It runs directly on the hardware, inserting itself below the management OS (called the parent partition). All other OS instances, including what users perceive as the "host OS," are actually child partitions. This distinction is critical: the Windows Server installation from which an admin manages Hyper-V is itself virtualized by the hypervisor.

Supported host versions: Windows Server 2016, 2019, 2022, 2025 (also available as Hyper-V Server, a free standalone SKU, through 2022).

---

## Part 1: Architecture

### 1. Hypervisor Architecture

#### Type-1 Bare-Metal Model

When the Hyper-V role is installed and the system reboots, the Windows hypervisor (`hvax64.exe` / `hvloader.exe`) takes control of the hardware ring-0 layer. The Windows Server OS (formerly "the host") becomes the **parent partition** — a privileged virtual machine that retains direct driver access through a pass-through model. All other VMs are **child partitions** that access hardware only through synthetic or emulated paths.

Key layers:
- **Hypervisor layer** — manages CPU virtualization (VT-x/AMD-V), memory isolation (EPT/NPT), and APIC virtualization
- **Parent partition** — runs the Windows Server management OS; owns physical device drivers; exposes VSPs (Virtualization Service Providers)
- **Child partitions** — run guest OSes; consume virtual resources through VSCs (Virtualization Service Clients)

#### VMBus

VMBus is a high-speed inter-partition communication channel. It is the transport for all synthetic devices:
- Lives in kernel memory shared between parent and child partitions
- Uses ring buffers for producer/consumer I/O
- Dramatically lower latency than emulated device I/O (no hardware emulation overhead)
- Requires Integration Services on the guest side (the VSC driver stack)

When a guest OS driver issues a disk I/O through the VMBus synthetic SCSI controller, the request traverses: guest VSC → hypervisor → VMBus ring buffer → parent partition VSP → physical driver → disk.

#### Hypercall Interface

The hypervisor exposes a hypercall ABI (analogous to a syscall ABI). Guest OSes use hypercalls to request privileged operations:
- `HvCallNotifyLongSpinWait` — notify the hypervisor the guest is spin-waiting (yields CPU)
- `HvCallFlushVirtualAddressSpace` — TLB flush across virtual processors
- `HvCallSignalEvent` — inter-partition signaling
- Memory management hypercalls (GPA/SPA translations)

Hypercalls are used heavily by enlightened guests. Unenlightened guests use standard virtualized hardware paths.

#### Synthetic vs. Emulated Devices

| Type | Description | Performance |
|---|---|---|
| **Synthetic** | VMBus-connected; VSC/VSP model; requires Integration Services | High (near-native) |
| **Emulated** | Hardware emulation (e.g., IDE, legacy NIC); available before IS loaded | Low (emulation overhead) |
| **Paravirtualized** | Direct hypercall interface (e.g., enlightened timers, TLB shootdowns) | Highest (direct calls) |

Gen1 VMs expose emulated hardware for boot (IDE, emulated BIOS, legacy NIC) then synthetic devices after Integration Services load. Gen2 VMs skip emulation entirely; even the boot path is synthetic.

#### Enlightenments

Enlightenments are guest OS modifications that allow the OS to cooperate with the hypervisor directly instead of being tricked by hardware emulation:
- **Synthetic MSRs** — read/write hypervisor registers without emulated hardware
- **Relaxed timer** — guest backs off on timer interrupts under low load (reduces VMEXIT overhead)
- **Enlightened spinlock** — spin loops yield to hypervisor instead of burning CPU cycles
- **Direct flip** — memory map changes without full TLB shootdown
- **APIC enlightenment** — eliminates emulated APIC MSR exits
- **Linux** — full enlightenment support via `hv_*` kernel drivers since Linux kernel 3.4+

Windows Server 2016+ guests are deeply enlightened. Linux guests (RHEL, Ubuntu, SUSE) have mature LIS/upstream drivers.

---

### 2. Virtual Machine Generations

#### Gen1 VMs

- **Firmware:** BIOS (legacy, emulated)
- **Boot devices:** IDE (positions 0 and 1), legacy network boot via emulated NIC
- **Hardware:** Emulated IDE controller, emulated NIC (synthetic available after IS), COM ports, LPT ports, floppy controller, emulated video
- **Max VHDX size:** 64 TB (but boot disk limited to 2 TB due to MBR)
- **Secure Boot:** Not supported
- **Use cases:** Legacy OS (Windows Server 2003, 2008 without UEFI support), 32-bit guests, guests that require emulated hardware, VMs migrated from VMware/vSphere where conversion is not practical

#### Gen2 VMs

- **Firmware:** UEFI (Unified Extensible Firmware Interface)
- **Boot devices:** SCSI (synthetic, VMBus-connected; faster than emulated IDE)
- **Hardware:** No emulated IDE, no legacy NIC, no floppy, no COM/LPT by default
- **Secure Boot:** Supported and enabled by default (configurable templates: Windows, MicrosoftUEFI, OpenSourceShielded)
- **vTPM:** Supported (software TPM 2.0 backed by Host Guardian Service key)
- **Network boot:** PXE via synthetic NIC (no legacy NIC required)
- **Hot-add:** vNIC and VHDX hot-add supported (2016+)
- **Use cases:** All new VMs on supported guest OS (Windows Server 2012+, Windows 8+, modern Linux distros)

#### Generation Selection Decision Table

| Condition | Use Gen1 | Use Gen2 |
|---|---|---|
| Guest: Windows Server 2008 R2 or older | Yes | No |
| Guest: 32-bit OS | Yes | No |
| Requires COM port (serial console) | Yes | No |
| Migrating from VMware with IDE disk | Yes | — |
| Guest: Windows Server 2012+ | — | Yes |
| Guest: Modern Linux (RHEL 6.5+, Ubuntu 12.04+) | — | Yes |
| Need Secure Boot / vTPM | — | Yes |
| Need UEFI diagnostics | — | Yes |
| Default for all new deployments | — | Yes |

#### VM Configuration Versions

Configuration version is separate from generation. It controls the format of the VM config files and determines which features are available.

| Windows Server Version | Default Config Version | New Features |
|---|---|---|
| 2016 | 8.0 | Production checkpoints, hot-add NIC, nested virt |
| 2019 | 9.0 | Hot-resize memory/CPU (Gen2), RDMA improvements |
| 2022 | 10.0 | vTPM for Linux, AMD nested virt, enhanced networking |
| 2025 | 12.0 | GPU-P live migration, 2048 vCPU, 240 TB RAM |

Upgrade configuration version after host upgrades:

```powershell
# Check current version
Get-VM | Select-Object Name, Version

# Upgrade (irreversible — VM cannot be moved back to older host)
Update-VMVersion -VMName "MyVM" -Force
```

**Warning:** Upgrading config version is irreversible. Confirm the VM will never need to run on an older host before upgrading.

---

### 3. Memory Architecture

#### Static vs. Dynamic Memory

**Static Memory** — A fixed amount of RAM is allocated to the VM at startup and never changes. Simple and predictable. Best for:
- VMs with known, constant memory requirements
- Production database servers (SQL Server, Oracle) where you do not want the memory balancer competing
- VMs that need all allocated memory to be pre-faulted

**Dynamic Memory (DM)** — Hyper-V balances memory among VMs using a balloon driver mechanism.

Dynamic Memory parameters:
- **Startup RAM** — Memory allocated at VM boot (before balancer engages). Must be >= Minimum RAM.
- **Minimum RAM** — Floor. The VM is guaranteed at least this much even under host memory pressure. Set low enough to allow reclamation, but high enough to prevent thrashing.
- **Maximum RAM** — Ceiling. The VM can never exceed this regardless of demand.
- **Memory Buffer** — Percentage of additional memory to keep available above current demand (e.g., 20% means if VM uses 4 GB, target assigned is 4.8 GB). Acts as headroom for sudden demand spikes.
- **Memory Weight** — Priority (0–10000) when host memory is scarce. Higher weight = preferential allocation. Default 5000.

Dynamic Memory algorithm:
1. Monitor `Current Demand` (what the guest actually needs, reported by balloon driver)
2. Calculate `Target Assigned` = Current Demand + (Buffer%)
3. If `Target Assigned` > `Assigned RAM`: add memory (balloon driver contracts inside guest, exposing physical pages to hypervisor; or hot-add if guest supports it)
4. If `Target Assigned` < `Assigned RAM`: reclaim memory (balloon driver inflates inside guest, consuming pages so hypervisor can reclaim)

#### NUMA Topology

Non-Uniform Memory Access (NUMA) affects performance when a VM's virtual CPUs span multiple physical NUMA nodes:
- **NUMA-aligned placement** (default, recommended): Hyper-V schedules all vCPUs and memory for a VM within a single NUMA node. Eliminates remote memory access latency.
- **NUMA spanning** (can be enabled): Allows VMs larger than a single NUMA node. Accepted for very large VMs, but incurs cross-NUMA latency.

Check NUMA topology:

```powershell
# Physical NUMA topology on host
Get-VMHostNumaNode

# VM NUMA topology (how the guest sees NUMA)
Get-VMNumaTopology -VMName "MyVM"

# NUMA spanning setting
(Get-VMHost).NumaSpanningEnabled
```

VM NUMA nodes: Hyper-V can expose multiple NUMA nodes to a guest. By default, the virtual NUMA topology mirrors the physical topology. Large VMs (e.g., 64 vCPU, 512 GB RAM) benefit from NUMA-aware guest configuration.

#### Memory Hot-Add

- Gen2 VMs with Dynamic Memory can receive memory additions without restart (hot-add). The guest OS must support memory hot-add.
- Windows Server 2016+ as guest: full hot-add support
- Linux: depends on kernel and ACPI configuration (generally supported in modern kernels)
- Static memory VMs: no hot-add; must restart to change allocation

#### Smart Paging

Smart Paging is a fallback mechanism used only during VM restart (not steady-state operation). If the host does not have enough physical memory to satisfy a VM's Startup RAM requirement during restart (but has minimum RAM available), Hyper-V uses a page file on the host to back the difference.

- Smart paging file location: configurable per VM (default: VM config directory)
- Performance: significantly slower than physical RAM — treat as emergency mechanism only
- Only active during restart; once the guest is running, DM can reclaim the paging-backed memory
- Set Smart Paging file path: `Set-VM -VMName "VM1" -SmartPagingFilePath "D:\SmartPaging"`

---

### 4. Virtual Networking

#### Virtual Switch Types

| Type | Host-to-VM | VM-to-VM | VM-to-External | Isolation |
|---|---|---|---|---|
| **External** | Yes | Yes | Yes (via physical NIC) | None by default |
| **Internal** | Yes | Yes | No | Host-only boundary |
| **Private** | No | Yes | No | Complete (no host access) |

Creating virtual switches:

```powershell
# External switch bound to a physical NIC
New-VMSwitch -Name "External-Switch" -NetAdapterName "Ethernet 1" -AllowManagementOS $true

# Internal switch (host can communicate, but not external network)
New-VMSwitch -Name "Internal-Switch" -SwitchType Internal

# Private switch (VM-to-VM only)
New-VMSwitch -Name "Private-Switch" -SwitchType Private
```

#### Switch Embedded Teaming (SET)

SET replaces legacy NIC teaming (LBFO) for Hyper-V environments. LBFO cannot be used with RDMA or SR-IOV in Hyper-V scenarios.

SET characteristics:
- Integrated into the Hyper-V virtual switch (no separate team NIC)
- Supports 1-8 physical NICs in the team
- Load balancing: Hyper-V port (default, hashes by VM source MAC/IP)
- Failover: Active/Active — all adapters carry traffic; one fails transparently
- Supports RDMA on team members (unlike LBFO + vSwitch)
- Supports SR-IOV on team members
- **Limitation:** Only supports Hyper-V port load distribution mode (no dynamic/LACP)

```powershell
# Create SET team with external switch
New-VMSwitch -Name "SET-Switch" -NetAdapterName "NIC1","NIC2" -EnableEmbeddedTeaming $true -AllowManagementOS $true

# Verify SET configuration
Get-VMSwitch -Name "SET-Switch" | Select-Object Name, EmbeddedTeamingEnabled, NetAdapterInterfaceDescriptions
```

#### VLAN Configuration

Hyper-V supports IEEE 802.1Q VLAN tagging at the vNIC or port level.

**Access mode (single VLAN):**

```powershell
# Assign vNIC to VLAN 100 (access port — frames arrive untagged to guest)
Set-VMNetworkAdapterVlan -VMName "VM1" -VMNetworkAdapterName "Network Adapter" -Access -VlanId 100
```

**Trunk mode (multiple VLANs to guest):**

```powershell
# Allow VLANs 100, 200, 300 as trunk to a guest (e.g., guest is a router/firewall)
Set-VMNetworkAdapterVlan -VMName "Router-VM" -Trunk -AllowedVlanIdList "100,200,300" -NativeVlanId 0
```

**Management OS VLAN (host NIC isolation):**

```powershell
# Isolate host management traffic on VLAN 10
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "Management" -Access -VlanId 10
```

#### SR-IOV (Single Root I/O Virtualization)

SR-IOV provides hardware-level virtualization for network adapters. Physical NICs that support SR-IOV expose Virtual Functions (VFs) — lightweight PCIe functions — that are assigned directly to VMs, bypassing the virtual switch software path.

Benefits:
- Near line-rate throughput with very low CPU overhead
- Minimal hypervisor involvement in the data path

Requirements:
- Physical NIC with SR-IOV support
- BIOS with SR-IOV / ACS (Access Control Services) enabled
- Windows Server 2016+ host
- VM must be Gen2 or Gen1 with synthetic NIC

```powershell
# Enable SR-IOV on the virtual switch
New-VMSwitch -Name "SRIOV-Switch" -NetAdapterName "SR-IOV NIC" -EnableIov $true

# Enable SR-IOV on a vNIC
Set-VMNetworkAdapter -VMName "VM1" -Name "Network Adapter" -IovWeight 100

# Verify SR-IOV assignment
Get-VMNetworkAdapter -VMName "VM1" | Select-Object Name, IovWeight, IovQueuePairsAssigned, IovUsage
```

SR-IOV limitations: Cannot use with live migration (VF is released and traffic falls back to synthetic NIC during migration). Not compatible with some port ACLs or network policies.

#### Bandwidth Management

```powershell
# Set minimum guaranteed bandwidth (10 Mbps) and maximum (1000 Mbps)
Set-VMNetworkAdapter -VMName "VM1" -Name "Network Adapter" `
    -MinimumBandwidthAbsolute 10000000 `
    -MaximumBandwidth 1000000000

# Using weight-based (relative allocation among all VMs on switch)
Set-VMNetworkAdapter -VMName "VM1" -MinimumBandwidthWeight 50
```

#### MAC Address Management

- **Dynamic MAC** (default): Hyper-V assigns from a pool (per-host range). Regenerated if VM is cloned/exported without resetting.
- **Static MAC**: Admin-assigned. Required for some clustering scenarios or when MAC stability across host migration is needed.
- **MAC spoofing**: Allow the guest to change its own MAC address. Required for: NAT inside the VM, nested Hyper-V, some NLB configurations.

```powershell
# Set static MAC
Set-VMNetworkAdapter -VMName "VM1" -StaticMacAddress "00-15-5D-01-02-03"

# Enable MAC spoofing
Set-VMNetworkAdapter -VMName "VM1" -MacAddressSpoofing On
```

---

### 5. Virtual Storage

#### VHD vs. VHDX

| Property | VHD | VHDX |
|---|---|---|
| Max size | 2 TB | 64 TB |
| Block size | 512 bytes (sector) | 4 KB (4096) |
| Metadata | Vulnerable to corruption on power loss | Journaled (transaction-safe) |
| Alignment | 512-byte aligned (causes overhead on 4K drives) | 4 KB aligned (optimal for modern drives) |
| Online resize | No | Yes |
| Trim/Unmap | No | Yes (enables VHDX to return space to thin-provision storage) |
| Maximum recommended | Legacy only | Default for all new VMs |

#### Disk Types

| Type | Description | Performance | Space Efficiency |
|---|---|---|---|
| **Fixed** | Pre-allocates full disk size at creation | Best (no metadata lookups) | Poor (max size allocated immediately) |
| **Dynamically Expanding** | Allocates blocks on write | Good (slight overhead vs fixed) | Best (only used space on host) |
| **Differencing** | Stores only changes relative to parent VHDX | Variable (parent I/O path) | Depends on change rate |

For production:
- Fixed-size VHDX for latency-sensitive workloads (databases, high-transaction apps)
- Dynamic VHDX acceptable for most workloads on fast storage (all-flash arrays)
- Differencing disks: used by checkpoints; avoid stacking deep chains

#### VHDX Online Resize

```powershell
# Expand VHDX (VM must be running, SCSI-attached on Gen2)
Resize-VHD -Path "D:\VMs\VM1\OSDisk.vhdx" -SizeBytes 200GB

# After expansion, extend the partition inside the guest OS:
# (In guest) Resize-Partition -DriveLetter C -Size (Get-PartitionSupportedSize -DriveLetter C).SizeMax
```

#### Shared VHDX and VHD Sets

For Windows Server Failover Clustering guest clusters (multiple VMs sharing a disk as a cluster disk):

- **Shared VHDX (.vhdx)** — Windows Server 2012 R2+. Multiple VMs attach to same VHDX as SCSI disk. Limited to single SCSI controller attachment. No hot-add/remove. No host-side backup through VSS.
- **VHD Sets (.vhds)** — Windows Server 2016+. Preferred format. Supports host-side VSS backup, online checkpoints, and resize. Each .vhds file has an accompanying .avhdx checkpoint-based structure.

```powershell
# Create a VHD Set (shared disk for guest cluster)
New-VHD -Path "D:\Shared\ClusterDisk.vhds" -SizeBytes 500GB -Fixed

# Attach to multiple VMs as shared
Add-VMScsiController -VMName "ClusterNode1"
Add-VMHardDiskDrive -VMName "ClusterNode1" -ControllerType SCSI -Path "D:\Shared\ClusterDisk.vhds" -ShareVirtualDisk

Add-VMScsiController -VMName "ClusterNode2"
Add-VMHardDiskDrive -VMName "ClusterNode2" -ControllerType SCSI -Path "D:\Shared\ClusterDisk.vhds" -ShareVirtualDisk
```

#### Storage QoS

Storage QoS controls IOPS flow per VHD to prevent noisy neighbor issues.

```powershell
# Set minimum 500 IOPS and maximum 5000 IOPS for a virtual disk
Set-VMHardDiskDrive -VMName "VM1" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0 `
    -MinimumIOPS 500 -MaximumIOPS 5000

# Get current QoS metrics
Get-StorageQosFlow | Select-Object InitiatorName, InitiatorId, MinimumIops, MaximumIops, Status, IOPS
```

#### Virtual Fibre Channel (vFC)

Allows VMs to connect directly to Fibre Channel SANs through host HBAs. Each vFC NIC presents as an N_Port ID Virtualization (NPIV) port on the fabric.

Requirements:
- Physical HBA that supports NPIV
- Hyper-V host with HBA configured for NPIV
- SAN zoning for the VM's virtual WWN pair

```powershell
# Add a virtual FC adapter to a VM (uses WWPN/WWNN pair from host HBA)
Add-VMFibreChannelHba -VMName "VM1" -SanName "FC-SAN-01"

# View virtual FC adapters
Get-VMFibreChannelHba -VMName "VM1"
```

---

### 6. Integration Services

Integration Services (IS) are a suite of drivers and services that enable the synthetic device stack (VMBus) and cooperative hypervisor features.

| Component | Function | Guest OS Required |
|---|---|---|
| **Operating System Shutdown** | Clean shutdown from Hyper-V Manager/PowerShell | All Windows |
| **Time Synchronization** | Sync guest clock to host; configurable per-VM | All |
| **Data Exchange (KVP)** | Key-Value Pair exchange between host and guest (registry-based metadata) | Windows/Linux |
| **Heartbeat** | Periodic liveness signal from guest to host | All |
| **Volume Shadow Copy (VSS)** | Coordinate VSS backups from host; quiesce guest I/O | Windows (VSS-aware) |
| **Guest Services** | PowerShell Direct file copy; Copy-VMFile cmdlet | Windows |
| **Dynamic Memory** | Balloon driver for DM operations | Windows/Linux |

#### Windows IS Delivery (2016+)

Starting with Windows Server 2016, Integration Services for Windows guests are delivered via Windows Update, not through a separate IS installer. This means:
- IS updates no longer require VM downtime for driver installation
- IS version tracks Windows Update on the guest, not the host build
- Verify IS update level: `Get-VMIntegrationService -VMName "VM1"`

#### Linux Integration Services (LIS)

For Linux guests, enlightenments are provided through:
1. **Upstream Linux kernel** — Since kernel 3.4+, most LIS drivers are built into mainline. RHEL 7+, Ubuntu 16.04+, SUSE 12+ include them out of the box.
2. **LIS download package** — For older RHEL/CentOS (6.x): download from Microsoft, installs as DKMS modules.
3. **KVP daemon** — `hypervkvpd` for host-guest data exchange (set guest hostname visible from host)
4. **VSS daemon** — `hypervvssd` for online backup support

Critical Linux IS components:
- `hv_vmbus` — VMBus transport driver
- `hv_storvsc` — Synthetic SCSI storage controller
- `hv_netvsc` — Synthetic network adapter
- `hv_utils` — Heartbeat, time sync, KVP, OS shutdown

---

## Part 2: Best Practices

### 7. VM Configuration Best Practices

#### CPU Right-Sizing

- **vCPU-to-pCore ratio:** Keep total vCPU allocation across all VMs below 4:1 per physical core for most workloads (OLTP, web); up to 8:1 for dev/test or light workloads.
- **Virtual NUMA alignment:** Assign vCPUs that fit within a single NUMA node's logical processor count. A host with two 16-core sockets (32 pCores, 64 HT threads) has 32 logical processors per NUMA node. VMs with <= 32 vCPUs can be NUMA-aligned.
- **Hyper-threading:** Hyper-V exposes logical processors (HT threads). Avoid allocating more vCPUs than physical cores for latency-sensitive workloads; HT sharing can cause execution interference.
- **NUMA topology exposure:** For large VMs, set virtual NUMA nodes explicitly: `Set-VMProcessor -VMName "BigVM" -MaximumCountPerNumaNode 16 -MaximumCountPerNumaSocket 32`
- **CPU compatibility:** When using live migration between hosts with different CPU models, enable "Processor Compatibility Mode" (`Set-VMProcessor -CompatibilityForMigrationEnabled $true`). This limits exposed CPU features to a common baseline.

#### Memory Allocation

- **Dynamic Memory for variable workloads:** Web servers, app servers, batch processors benefit from DM. Set Minimum RAM to what the OS needs at idle, Maximum to what the workload peaks at.
- **Static Memory for databases:** SQL Server, Oracle, and other systems that manage their own memory caches should use static memory. DM's balloon driver competes with the application's internal memory management.
- **Avoid overcommit in production:** Never configure total Maximum RAM across all VMs to exceed physical RAM minus OS reservation (typically 1-4 GB). Overcommit causes Smart Paging, which severely degrades performance.
- **Memory weight for critical VMs:** Set weight 9000-10000 for production VMs, 5000 for standard, 1000-2000 for dev/test.
- **Buffer percentage:** 20% is standard. For bursty workloads (task schedulers, batch), increase to 30-40%.

#### Disk Configuration

- **Use VHDX (not VHD)** for all new disks. VHD is legacy.
- **SCSI over IDE:** Gen2 VMs always use SCSI. Gen1 boot disks use IDE controller slot 0; additional data disks should use SCSI controller.
- **Fixed vs. Dynamic on SSD/NVMe:** On all-flash storage, dynamic VHDX overhead is negligible. On spinning disk or mixed HDD/SSD, fixed VHDX avoids fragmentation and guarantees sequential layout.
- **CSV placement:** In clustered environments, place VHDX files on Cluster Shared Volumes (CSVs) to enable live migration and quick failover.
- **Separate volumes:** Do not co-locate VHDX files and the host OS on the same volume. Use dedicated volumes for VM storage.
- **VHDX block size:** Default 32 MB for dynamic, can be set to 2 MB for smaller VMs. Rarely needs tuning.

#### Anti-Virus Exclusions for Hyper-V Hosts

Configure AV exclusions on the Hyper-V host for:

| Exclusion | Path Pattern |
|---|---|
| VHDX files | `*.vhdx`, `*.vhd`, `*.avhdx`, `*.vhds`, `*.avhd` |
| VM config files | `*.vmcx`, `*.vmrs`, `*.vmgs` |
| Snapshot/checkpoint files | `*.vsv`, `*.bin` |
| VM directories | Entire VM directory tree |
| VMM library share | If SCVMM in use |
| Hyper-V process | `vmwp.exe` (VM Worker Process per VM) |

Do NOT exclude these from AV scanning inside VMs — only the host-side file paths.

#### Server Core for Hyper-V Hosts

Microsoft recommends Hyper-V hosts run Server Core (no Desktop Experience):
- Reduced attack surface (fewer binaries, fewer patches)
- Lower memory overhead (~1-2 GB less than Desktop Experience)
- Fewer reboots required for updates (core components only)
- Hyper-V is fully manageable via PowerShell, RSAT, and Windows Admin Center from remote workstations

---

### 8. Host Configuration

#### Dedicated NICs and Network Segmentation

Best practice: separate physical NICs (or SET-team groups) for each traffic type:

| Traffic Type | Recommended Bandwidth | Notes |
|---|---|---|
| VM (VM network traffic) | 10 GbE+ (or 25/40/100 GbE) | Can share with management if necessary |
| Management (host management, RDP) | 1 GbE minimum | Dedicated recommended |
| Live Migration | 10 GbE+ | Can use RDMA (SMB Direct) for speed |
| CSV/Storage (SMB/iSCSI) | 10 GbE+ with RDMA preferred | Separate from VM traffic |
| Cluster heartbeat | 1 GbE | Dedicated crossover or separate switch |

Use Live Migration network binding to specify which NIC/IP is used:

```powershell
# Restrict live migration to specific network
Set-VMMigrationNetwork -ComputerName "HV-HOST01" -Subnet "192.168.10.0/24" -Priority 1
```

#### NUMA-Aware VM Placement

```powershell
# View physical NUMA topology
Get-VMHostNumaNode | Select-Object NodeId, MemoryAvailable, MemoryTotal, ProcessorsAvailable

# View VM NUMA placement
Get-VM | ForEach-Object {
    $vm = $_
    Get-VMNumaNodeStatus -VM $vm | Select-Object @{n="VM";e={$vm.Name}}, NodeId, MemoryAssigned, ProcessorCount
}
```

Strategy:
- Place large VMs first (most NUMA-constrained)
- Group related VMs on same NUMA node to reduce cross-node traffic
- Monitor NUMA hot-plug warnings in event log

---

### 9. Checkpoint Best Practices

#### Standard vs. Production Checkpoints

| Feature | Standard Checkpoint | Production Checkpoint |
|---|---|---|
| Mechanism | Saved state (memory snapshot) | VSS in guest (or file system freeze) |
| Application consistency | No (crash-consistent) | Yes (application-consistent) |
| Guest OS aware | No | Yes |
| Suitable for production | No | Yes (with caveats) |
| Works during heavy I/O | Yes | Yes (VSS may slow) |
| Default (WS 2016+) | No | Yes |

```powershell
# Configure production checkpoints
Set-VM -VMName "VM1" -CheckpointType Production
# Options: Standard, Production, ProductionOnly, Disabled

# Create a checkpoint
Checkpoint-VM -VMName "VM1" -SnapshotName "Before patch $(Get-Date -Format 'yyyy-MM-dd')"
```

#### Performance Impact of Checkpoints

When a checkpoint is created:
1. A new differencing VHDX (.avhdx) is created
2. All writes go to the differencing disk
3. Reads that find no data in the avhdx fall through to the parent VHDX (I/O chain lengthens)
4. Deep checkpoint chains (>3) measurably increase I/O latency

When a checkpoint is deleted:
1. The avhdx must be merged into the parent VHDX
2. Merge happens in the background (auto-merge) and consumes I/O
3. During merge, the chain remains active and may slow the VM

Recommendations:
- **Dev/test:** Checkpoints are excellent for saving state before risky operations
- **Production:** Use Production checkpoints sparingly; delete after use (avoid long-lived chains)
- **Never for production databases (Standard):** Standard checkpoints restore a crash-consistent state, not an application-consistent state; database may require recovery

Checkpoint file locations:
- Default: Same directory as VM VHDX files
- Configurable: `Set-VM -VMName "VM1" -SnapshotFileLocation "E:\Checkpoints\"`

---

### 10. High Availability

#### Hyper-V with Windows Server Failover Clustering (WSFC)

Hyper-V VMs run as Clustered Resource Groups in WSFC. Each VM is a "Virtual Machine" resource that can be owned by any node in the cluster.

Requirements:
- Shared storage: CSV (Cluster Shared Volume) from SAN, SMB 3.x file share, or Storage Spaces Direct (S2D)
- All nodes must have identical Hyper-V feature set (same config version compatibility)
- Cluster validation passed (`Test-Cluster`)

```powershell
# Move a clustered VM to another node (Quick Migration — saves state, moves, restores)
Move-ClusterGroup -Name "VM1" -Node "HV-HOST02"

# Live migrate a clustered VM (no service interruption)
Move-ClusterVirtualMachineRole -Name "VM1" -MigrationType Live -Node "HV-HOST02"
```

#### Live Migration

Live Migration transfers a running VM between Hyper-V hosts with no perceived downtime (< 1 second typically).

Types:
- **Standard Live Migration (shared storage):** VM storage stays in place; only VM state is transferred over the network. Fastest option.
- **Shared-Nothing Live Migration:** Transfers both VM state AND storage simultaneously. Requires no shared storage. Uses SMB or compression/encryption.
- **Storage Live Migration:** Moves only the VHDX files while VM keeps running. No host migration.

Configuration:

```powershell
# Enable live migration
Enable-VMMigration -ComputerName "HV-HOST01"

# Configure authentication (Kerberos recommended, CredSSP for non-domain scenarios)
Set-VMHost -UseAnyNetworkForMigration $false -VirtualMachineMigrationAuthenticationType Kerberos

# Set concurrent live migrations limit
Set-VMHost -MaximumVirtualMachineMigrations 4 -MaximumStorageMigrations 2

# Performance options (Compression: faster for slow networks; SMBTransport: fastest on RDMA/10GbE+)
Set-VMHost -VirtualMachineMigrationPerformanceOption SMBTransport
```

Live Migration Prerequisites:
1. Both hosts in same domain (Kerberos) or CredSSP configured
2. For non-clustered shared-nothing: "Migrate to any authenticated computer" permission in Hyper-V settings
3. Firewall rules: TCP 6600 (live migration), TCP 445 (SMB), TCP 135 (RPC endpoint mapper)
4. Processors compatible or Compatibility Mode enabled on VM

#### Hyper-V Replica

Asynchronous VM replication to a secondary Hyper-V host (can be in a remote site). Designed for DR, not HA (brief RPO window of replication interval).

Key settings:
- **Replication interval:** 30 seconds (default), 5 minutes, 15 minutes
- **Recovery points:** Keep up to 24 additional recovery points (hourly snapshots at replica)
- **Authentication:** Kerberos (same domain) or Certificate (workgroup/DMZ)
- **Compression:** Enabled by default for WAN scenarios

```powershell
# On primary host: enable VM for replication
Enable-VMReplication -VMName "VM1" -ReplicaServerName "DR-HOST01" `
    -ReplicaServerPort 8080 -AuthenticationType Kerberos `
    -ReplicationFrequencySec 300 -CompressionEnabled $true

# Start initial replication
Start-VMInitialReplication -VMName "VM1"

# Check replication health
Measure-VMReplication -VMName "VM1"

# Planned failover (graceful, synchronizes final delta before switching)
Start-VMFailover -VMName "VM1" -Prepare  # on primary
Start-VMFailover -VMName "VM1"           # on replica
Complete-VMFailover -VMName "VM1"        # on replica (makes replica the new primary)

# Unplanned failover (primary is down)
Start-VMFailover -VMName "VM1"           # on replica
Complete-VMFailover -VMName "VM1"
```

Extended Replication: Primary → Replica → Extended Replica (three-site chain). Extended replica is a replica of the replica.

---

## Part 3: Diagnostics

### 11. VM Health Monitoring

#### Core Health Cmdlets

```powershell
# All VMs with basic state
Get-VM | Select-Object Name, State, Status, CPUUsage, MemoryAssigned, Uptime, Version, Generation

# Integration service health
Get-VMIntegrationService -VMName "VM1" | Select-Object Name, Enabled, PrimaryStatusDescription, SecondaryStatusDescription

# Replication health
Get-VMReplication | Select-Object VMName, State, Health, LastReplicationTime, ReplicationFrequency, ReplicationMode

# VM heartbeat (quick health check)
(Get-VMIntegrationService -VMName "VM1" -Name "Heartbeat").PrimaryStatusDescription
# Returns: OK, No Contact, Lost Communication
```

#### Hyper-V Event Logs

Event logs under `Microsoft-Windows-Hyper-V-*`:

| Log | Key Events |
|---|---|
| `Microsoft-Windows-Hyper-V-VMMS-Admin` | VM lifecycle events, errors, configuration changes |
| `Microsoft-Windows-Hyper-V-VMMS-Operational` | VM start/stop/pause operations |
| `Microsoft-Windows-Hyper-V-Worker-Admin` | VM worker process events (per VM) |
| `Microsoft-Windows-Hyper-V-Hypervisor-Admin` | Hypervisor-level events |
| `Microsoft-Windows-Hyper-V-Migration-Admin` | Live migration events and failures |
| `Microsoft-Windows-Hyper-V-VID-Admin` | Virtual Infrastructure Driver events |
| `Microsoft-Windows-Hyper-V-SynthStor-Admin` | Synthetic storage events |
| `Microsoft-Windows-Hyper-V-SynthNic-Admin` | Synthetic NIC events |

```powershell
# Query admin event log for errors in last 24 hours
Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-VMMS-Admin" -MaxEvents 100 |
    Where-Object { $_.LevelDisplayName -in "Error","Warning" -and $_.TimeCreated -gt (Get-Date).AddHours(-24) } |
    Select-Object TimeCreated, LevelDisplayName, Id, Message |
    Format-Table -AutoSize -Wrap
```

#### Key Performance Counters

| Counter Category | Counter Name | Description |
|---|---|---|
| `Hyper-V Hypervisor Logical Processor` | `% Total Run Time` | Total CPU usage per logical processor |
| `Hyper-V Hypervisor Logical Processor` | `% Hypervisor Run Time` | CPU time in hypervisor (overhead) |
| `Hyper-V Hypervisor Logical Processor` | `% Guest Run Time` | CPU time in VMs |
| `Hyper-V Hypervisor Virtual Processor` | `% Total Run Time` | Per-VM vCPU usage |
| `Hyper-V Hypervisor Virtual Processor` | `% Hypervisor Run Time` | Per-VM hypervisor overhead |
| `Hyper-V Dynamic Memory VM` | `Current Pressure` | Memory pressure indicator (>100 = shortage) |
| `Hyper-V Dynamic Memory VM` | `Physical Memory` | Currently assigned physical memory |
| `Hyper-V Virtual Storage Device` | `Read Bytes/sec` | VHDX read throughput |
| `Hyper-V Virtual Storage Device` | `Write Bytes/sec` | VHDX write throughput |
| `Hyper-V Virtual Storage Device` | `Average Read Latency` | Per-request read latency (ms) |
| `Hyper-V Virtual Network Adapter` | `Bytes Received/sec` | VM NIC receive throughput |
| `Hyper-V Virtual Network Adapter` | `Bytes Sent/sec` | VM NIC send throughput |

---

### 12. Performance Diagnostics

#### CPU Performance Indicators

Normal thresholds:
- `% Hypervisor Run Time` > 10% per logical processor: consider host overloading or excessive VMEXIT rate
- `% Guest Run Time` + `% Hypervisor Run Time` > 90% per LP consistently: host is CPU saturated
- VP dispatch latency (from Hyper-V Hypervisor Root VP) > 1ms: scheduler contention

Causes of high hypervisor overhead:
- Deep emulation (Gen1 VMs with many emulated device accesses)
- Unenlightened guest OSes (older Linux without LIS)
- Excessive timer interrupts from guest
- Nested virtualization overhead

#### Memory Diagnostics

```powershell
# Dynamic Memory pressure per VM
Get-Counter -Counter "\Hyper-V Dynamic Memory VM(*)\Current Pressure" |
    Select-Object -ExpandProperty CounterSamples |
    Where-Object { $_.InstanceName -ne "_total" } |
    Sort-Object CookedValue -Descending |
    Select-Object InstanceName, @{n="Pressure%";e={[math]::Round($_.CookedValue,1)}}
```

Pressure interpretation:
- 0-80: VM has excess memory (balancer may reclaim)
- 80-100: VM is using all assigned memory normally
- 100-150: VM is under memory pressure; DM will try to add memory
- >150: Severe pressure; likely paging in guest OS

#### Disk I/O Diagnostics

```powershell
# VHD/VHDX file health and metadata
Get-VHD -Path "D:\VMs\VM1\OSDisk.vhdx" |
    Select-Object Path, VhdType, FileSize, Size, FragmentationPercentage, Alignment, Attached

# Check VHD fragmentation (high fragmentation on dynamic VHDXs impacts performance)
# Defragment the VHDX offline:
# Optimize-VHD -Path "D:\VMs\VM1\OSDisk.vhdx" -Mode Full
```

Storage latency targets:
- VHDX on SSD: < 1 ms average read/write latency
- VHDX on SAS HDD RAID: < 10 ms
- Latency > 20 ms consistently: storage bottleneck — investigate underlying storage

#### Network Diagnostics

```powershell
# Virtual switch packet drops (indicates bandwidth saturation or misconfiguration)
Get-Counter -Counter "\Hyper-V Virtual Switch(*)\Dropped Packets Outgoing/sec",
                     "\Hyper-V Virtual Switch(*)\Dropped Packets Incoming/sec" |
    Select-Object -ExpandProperty CounterSamples |
    Where-Object { $_.CookedValue -gt 0 }
```

---

### 13. Common Troubleshooting

#### VM Won't Start

```
Error: "The virtual machine could not be started because the hypervisor is not running."
Fix: Enable virtualization in BIOS; run 'bcdedit /set hypervisorlaunchtype auto'

Error: "Not enough memory to start the VM"
Fix: Check host available memory vs VM Startup RAM; enable Smart Paging or reduce startup RAM

Error: "Access denied"
Fix: VM Worker Process runs as NT VIRTUAL MACHINE\<GUID> — check NTFS permissions on VHDX path

Error: "The configuration of the virtual machine is corrupt"
Fix: Restore .vmcx from backup; or rebuild VM and reattach VHDX
```

```powershell
# Check hypervisor launch type
bcdedit /enum | Select-String "hypervisorlaunchtype"

# Verify Hyper-V service status
Get-Service -Name vmms, hvhost, vmcompute | Select-Object Name, Status, StartType
```

#### Live Migration Failures

Common failure causes and resolutions:

| Error | Cause | Resolution |
|---|---|---|
| "Virtual machine migration failed at migration source" | Authentication failure | Verify Kerberos SPN or CredSSP config |
| "The virtual machine cannot be migrated — incompatible processor" | CPU feature mismatch | Enable Processor Compatibility Mode on VM |
| "Insufficient resources on destination" | Not enough RAM/CPU on target | Free resources on destination host |
| "Logon failure: unknown user name or bad password" | CredSSP credential issue | Re-delegate credentials; check WinRM |
| Storage migration fails | VHDX path not accessible on destination | Verify SMB share access; check firewall rules |
| Migration extremely slow | Network: using wrong NIC (management instead of migration) | Configure migration network binding |

```powershell
# Test live migration pre-flight
Test-VMMigration -VMName "VM1" -DestinationHost "HV-HOST02"

# Check migration network configuration on source host
Get-VMMigrationNetwork -ComputerName "HV-HOST01"
```

#### Slow VM Performance — NUMA Misalignment

```powershell
# Detect NUMA misalignment (VM spanning multiple NUMA nodes)
Get-VM | ForEach-Object {
    $vm = $_
    $numaNodes = Get-VMNumaNodeStatus -VM $vm
    if ($numaNodes.Count -gt 1) {
        Write-Warning "VM '$($vm.Name)' spans $($numaNodes.Count) NUMA nodes — potential performance impact"
    }
}
```

NUMA misalignment causes: higher memory latency for ~50% of memory accesses (cross-node), scheduler overhead as vCPUs migrate between nodes.

Remediation:
1. Reduce vCPU count to fit within one NUMA node
2. Enable NUMA spanning only if VM must exceed single-node capacity
3. Set explicit NUMA topology: `Set-VMProcessor -VMName "VM1" -MaximumCountPerNumaNode 16`

#### Replication Lag and RPO Violations

```powershell
# Check replication lag
Get-VMReplication | Select-Object VMName, State, Health, LastReplicationTime, ReplicationFrequency |
    ForEach-Object {
        $lag = (Get-Date) - $_.LastReplicationTime
        [PSCustomObject]@{
            VMName = $_.VMName
            State = $_.State
            Health = $_.Health
            LagMinutes = [math]::Round($lag.TotalMinutes, 1)
            RPO_Sec = $_.ReplicationFrequency
        }
    } | Sort-Object LagMinutes -Descending

# Get extended replication statistics
Measure-VMReplication -VMName "VM1"
```

RPO violation causes:
- WAN link saturation (increase bandwidth or increase replication interval)
- High change rate on VM (increase replication frequency or bandwidth)
- Temporary network outage (replication catches up automatically if within recovery window)
- Replica host disk I/O bottleneck

---

## Part 4: PowerShell Scripts

### 01-hyperv-host-health.ps1

```powershell
<#
.SYNOPSIS
    Hyper-V host health assessment — hardware, configuration, NUMA, overcommit ratios.

.DESCRIPTION
    Collects host-level Hyper-V configuration including NUMA topology, logical processor
    allocation, memory overcommit ratios, virtual switch configuration, and role feature
    installation status. Read-only and production-safe.

.NOTES
    Version:    1.0
    Platform:   Windows Server 2016-2025 with Hyper-V role
    Requires:   Hyper-V PowerShell module; run as Administrator
    Author:     Hyper-V Diagnostic Suite
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$divider = "=" * 70

function Write-Section {
    param([string]$Title)
    Write-Host "`n$divider" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host $divider -ForegroundColor Cyan
}

# ── 1. Host Basic Info ────────────────────────────────────────────────────────
Write-Section "Host Information"
$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$vmHost = Get-VMHost

[PSCustomObject]@{
    Hostname         = $env:COMPUTERNAME
    OS               = $os.Caption
    Build            = $os.BuildNumber
    TotalRAM_GB      = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    LogicalCPUs      = $cs.NumberOfLogicalProcessors
    PhysicalCores    = $cs.NumberOfProcessors
    HyperVEnabled    = (Get-WindowsFeature Hyper-V).Installed
    ServerCore       = ($os.Caption -notmatch 'Desktop Experience')
    VMMigrationAuth  = $vmHost.VirtualMachineMigrationAuthenticationType
    MigrationEnabled = $vmHost.VirtualMachineMigrationEnabled
    MaxLiveMig       = $vmHost.MaximumVirtualMachineMigrations
    MaxStorMig       = $vmHost.MaximumStorageMigrations
} | Format-List

# ── 2. NUMA Topology ──────────────────────────────────────────────────────────
Write-Section "NUMA Topology"
Get-VMHostNumaNode | Select-Object NodeId,
    @{n="MemTotal_GB";e={[math]::Round($_.MemoryTotal / 1GB, 1)}},
    @{n="MemAvail_GB";e={[math]::Round($_.MemoryAvailable / 1GB, 1)}},
    ProcessorsAvailable |
    Format-Table -AutoSize

Write-Host "NUMA Spanning Enabled: $((Get-VMHost).NumaSpanningEnabled)" -ForegroundColor Yellow

# ── 3. Memory Overcommit Analysis ─────────────────────────────────────────────
Write-Section "Memory Overcommit Analysis"
$allVMs = Get-VM
$totalHostRAM_GB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
$totalAssigned_MB = ($allVMs | Measure-Object MemoryAssigned -Sum).Sum
$totalMaxMem_MB   = ($allVMs | ForEach-Object { (Get-VMMemory -VMName $_.Name).Maximum } | Measure-Object -Sum).Sum
$totalAssigned_GB = [math]::Round($totalAssigned_MB / 1GB, 2)
$totalMaxMem_GB   = [math]::Round($totalMaxMem_MB / 1GB, 2)

[PSCustomObject]@{
    HostTotalRAM_GB        = $totalHostRAM_GB
    TotalVMsRunning        = ($allVMs | Where-Object State -eq 'Running').Count
    TotalVMsAll            = $allVMs.Count
    CurrentAssigned_GB     = $totalAssigned_GB
    MaxConfigured_GB       = $totalMaxMem_GB
    AssignedOvercommitPct  = [math]::Round(($totalAssigned_GB / $totalHostRAM_GB) * 100, 1)
    MaxOvercommitPct       = [math]::Round(($totalMaxMem_GB / $totalHostRAM_GB) * 100, 1)
} | Format-List

# ── 4. vCPU Overcommit ────────────────────────────────────────────────────────
Write-Section "vCPU Overcommit Ratio"
$totalVCPUs = ($allVMs | Where-Object State -eq 'Running' |
    ForEach-Object { (Get-VMProcessor -VMName $_.Name).Count } |
    Measure-Object -Sum).Sum
$physLPs = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors

[PSCustomObject]@{
    PhysicalLogicalProcessors = $physLPs
    TotalRunningvCPUs         = $totalVCPUs
    OvercommitRatio           = "$([math]::Round($totalVCPUs / $physLPs, 2)):1"
    Recommendation            = if ($totalVCPUs / $physLPs -gt 4) {"WARNING: >4:1 ratio"} else {"OK"}
} | Format-List

# ── 5. Hyper-V Feature Status ─────────────────────────────────────────────────
Write-Section "Hyper-V Role and Features"
$features = @(
    'Hyper-V', 'Hyper-V-Tools', 'Hyper-V-PowerShell',
    'RSAT-Clustering', 'Failover-Clustering',
    'Hyper-V-Replica', 'FS-SMB1'
)
foreach ($feat in $features) {
    $f = Get-WindowsFeature $feat -ErrorAction SilentlyContinue
    if ($f) {
        [PSCustomObject]@{Feature = $f.Name; DisplayName = $f.DisplayName; Installed = $f.Installed}
    }
} | Format-Table -AutoSize

# ── 6. VMM Agent Status ───────────────────────────────────────────────────────
Write-Section "SCVMM Agent Status"
$scvmmAgent = Get-Service -Name vmmagent -ErrorAction SilentlyContinue
if ($scvmmAgent) {
    $scvmmAgent | Select-Object Name, Status, StartType | Format-Table -AutoSize
} else {
    Write-Host "SCVMM agent not installed (standalone Hyper-V host)" -ForegroundColor Gray
}

Write-Host "`nHost health assessment complete." -ForegroundColor Green
```

---

### 02-vm-inventory.ps1

```powershell
<#
.SYNOPSIS
    Complete VM inventory — state, generation, config version, resources, checkpoints, replication.

.DESCRIPTION
    Enumerates all VMs on the local Hyper-V host with full configuration detail:
    generation, configuration version, vCPU, memory (static/dynamic), disk layout,
    network adapters, checkpoint presence, and replication status.

.NOTES
    Version:    1.0
    Platform:   Windows Server 2016-2025 with Hyper-V role
    Requires:   Hyper-V PowerShell module; run as Administrator
    Author:     Hyper-V Diagnostic Suite
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$allVMs = Get-VM
Write-Host "Inventorying $($allVMs.Count) VMs on $env:COMPUTERNAME..." -ForegroundColor Cyan

$inventory = foreach ($vm in $allVMs) {
    $processor   = Get-VMProcessor -VMName $vm.Name
    $memory      = Get-VMMemory    -VMName $vm.Name
    $nics        = Get-VMNetworkAdapter -VMName $vm.Name
    $disks       = Get-VMHardDiskDrive  -VMName $vm.Name
    $checkpoints = Get-VMSnapshot -VMName $vm.Name -ErrorAction SilentlyContinue
    $replication = Get-VMReplication -VMName $vm.Name -ErrorAction SilentlyContinue

    # Aggregate disk info
    $diskSummary = $disks | ForEach-Object {
        $path = $_.Path
        $vhd = if ($path) { Get-VHD -Path $path -ErrorAction SilentlyContinue } else { $null }
        "$($_.ControllerType)[$($_.ControllerNumber),$($_.ControllerLocation)] " +
        "$(if($vhd){"$([math]::Round($vhd.Size/1GB,0))GB/$($vhd.VhdType)"} else {'<passthrough>'})"
    }

    # NIC summary
    $nicSummary = $nics | ForEach-Object {
        $vlan = Get-VMNetworkAdapterVlan -VMNetworkAdapter $_ -ErrorAction SilentlyContinue
        "$($_.Name):$($_.SwitchName):$(if($vlan.OperationMode -eq 'Access'){"VLAN$($vlan.AccessVlanId)"}else{$vlan.OperationMode})"
    }

    [PSCustomObject]@{
        Name             = $vm.Name
        State            = $vm.State
        Status           = $vm.Status
        Generation       = $vm.Generation
        ConfigVersion    = $vm.Version
        vCPUs            = $processor.Count
        NumaNodes        = $processor.MaximumCountPerNumaNode
        MemType          = if ($memory.DynamicMemoryEnabled) { "Dynamic" } else { "Static" }
        StartupMem_GB    = [math]::Round($memory.Startup / 1GB, 2)
        MinMem_GB        = [math]::Round($memory.Minimum / 1GB, 2)
        MaxMem_GB        = [math]::Round($memory.Maximum / 1GB, 2)
        AssignedMem_GB   = [math]::Round($vm.MemoryAssigned / 1GB, 2)
        Uptime           = $vm.Uptime
        CheckpointType   = $vm.CheckpointType
        Checkpoints      = $checkpoints.Count
        Disks            = ($diskSummary -join "; ")
        NICs             = ($nicSummary -join "; ")
        ReplicationState = if ($replication) { $replication.State } else { "NotReplicated" }
        ReplicationHealth= if ($replication) { $replication.Health } else { "N/A" }
        LastReplicated   = if ($replication) { $replication.LastReplicationTime } else { "N/A" }
        IntegrationServices = ($vm.IntegrationServicesVersion)
    }
}

# Output full inventory
$inventory | Format-Table Name, State, Generation, ConfigVersion, vCPUs, MemType, AssignedMem_GB, Checkpoints, ReplicationState -AutoSize

Write-Host "`nDetailed report:" -ForegroundColor Cyan
$inventory | Format-List

# Summary statistics
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total VMs: $($inventory.Count)"
Write-Host "Running: $(($inventory | Where-Object State -eq 'Running').Count)"
Write-Host "Gen1: $(($inventory | Where-Object Generation -eq 1).Count)"
Write-Host "Gen2: $(($inventory | Where-Object Generation -eq 2).Count)"
Write-Host "Dynamic Memory: $(($inventory | Where-Object MemType -eq 'Dynamic').Count)"
Write-Host "With Checkpoints: $(($inventory | Where-Object Checkpoints -gt 0).Count)"
Write-Host "Replicated: $(($inventory | Where-Object ReplicationState -ne 'NotReplicated').Count)"
```

---

### 03-vm-performance.ps1

```powershell
<#
.SYNOPSIS
    Per-VM performance metrics — CPU, memory, disk, and network via Get-Counter.

.DESCRIPTION
    Collects real-time performance counters for all running VMs using Hyper-V-specific
    performance counter categories. Samples counters and reports VM-level utilization.
    Use for quick host-wide performance triage.

.PARAMETER SampleCount
    Number of counter samples to collect (default: 3, interval: 2 seconds).

.NOTES
    Version:    1.0
    Platform:   Windows Server 2016-2025 with Hyper-V role
    Requires:   Hyper-V PowerShell module; run as Administrator
    Author:     Hyper-V Diagnostic Suite
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

param(
    [int]$SampleCount = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$counters = @(
    '\Hyper-V Hypervisor Virtual Processor(*)\% Total Run Time',
    '\Hyper-V Dynamic Memory VM(*)\Current Pressure',
    '\Hyper-V Dynamic Memory VM(*)\Physical Memory',
    '\Hyper-V Virtual Storage Device(*)\Read Bytes/sec',
    '\Hyper-V Virtual Storage Device(*)\Write Bytes/sec',
    '\Hyper-V Virtual Storage Device(*)\Average Read Latency',
    '\Hyper-V Virtual Storage Device(*)\Average Write Latency',
    '\Hyper-V Virtual Network Adapter(*)\Bytes Received/sec',
    '\Hyper-V Virtual Network Adapter(*)\Bytes Sent/sec'
)

Write-Host "Collecting $SampleCount samples (2-second interval)..." -ForegroundColor Cyan

try {
    $samples = Get-Counter -Counter $counters -SampleInterval 2 -MaxSamples $SampleCount -ErrorAction SilentlyContinue
}
catch {
    Write-Warning "Counter collection error: $_"
    exit 1
}

# Average samples across all collection intervals
$avgSamples = $samples.CounterSamples | Group-Object Path | ForEach-Object {
    [PSCustomObject]@{
        Path     = $_.Name
        Instance = ($_.Group[0].InstanceName)
        AvgValue = ($_.Group | Measure-Object CookedValue -Average).Average
    }
}

Write-Host "`n=== CPU Utilization (% Total Run Time per vCPU) ===" -ForegroundColor Yellow
$avgSamples | Where-Object { $_.Path -match 'Virtual Processor' -and $_.Instance -ne '_total' } |
    Group-Object { $_.Instance -replace ':.*$' } |  # Group by VM name (prefix before colon)
    ForEach-Object {
        [PSCustomObject]@{
            VM      = $_.Name
            AvgCPU  = [math]::Round(($_.Group | Measure-Object AvgValue -Average).Average, 1)
            MaxvCPU = [math]::Round(($_.Group | Measure-Object AvgValue -Maximum).Maximum, 1)
        }
    } | Sort-Object AvgCPU -Descending | Format-Table -AutoSize

Write-Host "`n=== Memory Pressure ===" -ForegroundColor Yellow
$avgSamples | Where-Object { $_.Path -match 'Current Pressure' -and $_.Instance -ne '_total' } |
    ForEach-Object {
        $status = switch ([int]$_.AvgValue) {
            {$_ -le 80}  { "Excess"    }
            {$_ -le 100} { "Normal"    }
            {$_ -le 150} { "Pressure"  }
            default       { "CRITICAL" }
        }
        [PSCustomObject]@{
            VM       = $_.Instance
            Pressure = [math]::Round($_.AvgValue, 1)
            Status   = $status
        }
    } | Sort-Object Pressure -Descending | Format-Table -AutoSize

Write-Host "`n=== Disk I/O ===" -ForegroundColor Yellow
$readLatency  = $avgSamples | Where-Object { $_.Path -match 'Average Read Latency'  -and $_.Instance -ne '_total' }
$writeLatency = $avgSamples | Where-Object { $_.Path -match 'Average Write Latency' -and $_.Instance -ne '_total' }
$readBytes    = $avgSamples | Where-Object { $_.Path -match 'Read Bytes/sec'         -and $_.Instance -ne '_total' }
$writeBytes   = $avgSamples | Where-Object { $_.Path -match 'Write Bytes/sec'        -and $_.Instance -ne '_total' }

$readLatency | ForEach-Object {
    $inst = $_.Instance
    [PSCustomObject]@{
        Disk           = $inst
        ReadLatency_ms = [math]::Round($_.AvgValue, 2)
        WriteLatency_ms= [math]::Round(($writeLatency | Where-Object Instance -eq $inst | Select-Object -First 1).AvgValue, 2)
        ReadMBs        = [math]::Round(($readBytes    | Where-Object Instance -eq $inst | Select-Object -First 1).AvgValue / 1MB, 2)
        WriteMBs       = [math]::Round(($writeBytes   | Where-Object Instance -eq $inst | Select-Object -First 1).AvgValue / 1MB, 2)
    }
} | Sort-Object ReadLatency_ms -Descending | Format-Table -AutoSize

Write-Host "`n=== Network I/O ===" -ForegroundColor Yellow
$rxBytes = $avgSamples | Where-Object { $_.Path -match 'Bytes Received' -and $_.Instance -ne '_total' }
$txBytes = $avgSamples | Where-Object { $_.Path -match 'Bytes Sent'     -and $_.Instance -ne '_total' }

$rxBytes | ForEach-Object {
    $inst = $_.Instance
    [PSCustomObject]@{
        Adapter    = $inst
        RxMBps     = [math]::Round($_.AvgValue / 1MB, 3)
        TxMBps     = [math]::Round(($txBytes | Where-Object Instance -eq $inst | Select-Object -First 1).AvgValue / 1MB, 3)
    }
} | Sort-Object RxMBps -Descending | Format-Table -AutoSize
```

---

### 04-virtual-switch.ps1

```powershell
<#
.SYNOPSIS
    Virtual switch configuration audit — switch type, SET teaming, VLAN, SR-IOV, bandwidth.

.DESCRIPTION
    Enumerates all virtual switches and their configuration including Switch Embedded
    Teaming (SET), SR-IOV capabilities, VLAN policies, and bandwidth management settings.
    Also reports per-VM network adapter configuration.

.NOTES
    Version:    1.0
    Platform:   Windows Server 2016-2025 with Hyper-V role
    Requires:   Hyper-V PowerShell module; run as Administrator
    Author:     Hyper-V Diagnostic Suite
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Virtual Switch Configuration ===" -ForegroundColor Cyan

Get-VMSwitch | ForEach-Object {
    $sw = $_
    $ext = Get-VMSwitchExtension -VMSwitch $sw -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        Name                  = $sw.Name
        SwitchType            = $sw.SwitchType
        EmbeddedTeaming       = $sw.EmbeddedTeamingEnabled
        AllowMgmtOS           = $sw.AllowManagementOS
        PhysicalAdapters      = ($sw.NetAdapterInterfaceDescriptions -join ", ")
        IOV_Enabled           = $sw.IovEnabled
        IOV_Support           = $sw.IovSupport
        IOV_SupportReasons    = $sw.IovSupportReasons
        PacketDirect          = $sw.PacketDirectEnabled
        DefaultQoS_MinBW      = $sw.DefaultFlowMinimumBandwidthAbsolute
        DefaultQoS_MaxBW      = $sw.DefaultFlowMinimumBandwidthWeight
        Extensions            = ($ext | Where-Object Enabled -eq $true | Select-Object -ExpandProperty Name) -join ", "
    } | Format-List
    Write-Host ("-" * 60)
} 

# ── Management OS NICs ────────────────────────────────────────────────────────
Write-Host "`n=== Management OS Virtual Adapters ===" -ForegroundColor Cyan
Get-VMNetworkAdapter -ManagementOS | Select-Object Name, SwitchName, MacAddress,
    @{n="IPAddresses";e={($_.IPAddresses -join ", ")}} |
    Format-Table -AutoSize

# ── Per-VM Network Adapter Config ─────────────────────────────────────────────
Write-Host "`n=== VM Network Adapter Configuration ===" -ForegroundColor Cyan
Get-VM | ForEach-Object {
    $vm = $_
    Get-VMNetworkAdapter -VMName $vm.Name | ForEach-Object {
        $nic  = $_
        $vlan = Get-VMNetworkAdapterVlan -VMNetworkAdapter $nic -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            VM              = $vm.Name
            Adapter         = $nic.Name
            Switch          = $nic.SwitchName
            MAC             = $nic.MacAddress
            MACType         = if ($nic.DynamicMacAddressEnabled) {"Dynamic"} else {"Static"}
            MACSpoof        = $nic.MacAddressSpoofing
            VlanMode        = $vlan.OperationMode
            VlanId          = if ($vlan.OperationMode -eq 'Access') {$vlan.AccessVlanId} else {"N/A"}
            AllowedVlans    = if ($vlan.OperationMode -eq 'Trunk') {$vlan.AllowedVlanIdList} else {"N/A"}
            MinBW_Mbps      = [math]::Round($nic.BandwidthSetting.MinimumBandwidthAbsolute / 1MB, 0)
            MaxBW_Mbps      = [math]::Round($nic.BandwidthSetting.MaximumBandwidth / 1MB, 0)
            IOV_Weight      = $nic.IovWeight
            IOV_Usage       = $nic.IovUsage
            RDMAEnabled     = $nic.RdmaWeight
        }
    }
} | Format-Table VM, Adapter, Switch, MACType, MACSpoof, VlanMode, VlanId, MinBW_Mbps, MaxBW_Mbps -AutoSize

# ── Dropped Packets ───────────────────────────────────────────────────────────
Write-Host "`n=== Virtual Switch Packet Drop Counters ===" -ForegroundColor Cyan
$dropCounters = @(
    '\Hyper-V Virtual Switch(*)\Dropped Packets Outgoing/sec',
    '\Hyper-V Virtual Switch(*)\Dropped Packets Incoming/sec'
)
Get-Counter -Counter $dropCounters -SampleInterval 1 -MaxSamples 3 |
    Select-Object -ExpandProperty CounterSamples |
    Where-Object { $_.InstanceName -ne '_total' } |
    Group-Object InstanceName |
    ForEach-Object {
        [PSCustomObject]@{
            Switch   = $_.Name
            DroppedIn  = [math]::Round(($_.Group | Where-Object {$_.Path -match 'Incoming'} | Measure-Object CookedValue -Average).Average, 2)
            DroppedOut = [math]::Round(($_.Group | Where-Object {$_.Path -match 'Outgoing'} | Measure-Object CookedValue -Average).Average, 2)
        }
    } | Format-Table -AutoSize
```

---

### 05-storage-health.ps1

```powershell
<#
.SYNOPSIS
    Virtual disk health audit — VHD/VHDX metadata, fragmentation, Storage QoS, shared disks.

.DESCRIPTION
    Enumerates all virtual hard disks attached to VMs. Reports VHD type, size, fragmentation,
    sector alignment, Storage QoS policy, and identifies shared VHDX (.vhds) files.
    Flags potential issues like high fragmentation, unaligned VHDs, and deep checkpoint chains.

.NOTES
    Version:    1.0
    Platform:   Windows Server 2016-2025 with Hyper-V role
    Requires:   Hyper-V PowerShell module; run as Administrator
    Author:     Hyper-V Diagnostic Suite
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Virtual Disk Health Inventory ===" -ForegroundColor Cyan

$diskReport = Get-VM | ForEach-Object {
    $vm = $_
    $drives = Get-VMHardDiskDrive -VMName $vm.Name
    foreach ($drive in $drives) {
        if (-not $drive.Path) { continue }
        $vhd = Get-VHD -Path $drive.Path -ErrorAction SilentlyContinue
        if (-not $vhd) { continue }

        $qos = Get-VMHardDiskDrive -VMName $vm.Name `
            -ControllerType $drive.ControllerType `
            -ControllerNumber $drive.ControllerNumber `
            -ControllerLocation $drive.ControllerLocation -ErrorAction SilentlyContinue

        $issues = @()
        if ($vhd.FragmentationPercentage -gt 20) { $issues += "HIGH_FRAG($($vhd.FragmentationPercentage)%)" }
        if ($vhd.Alignment -eq 0)                { $issues += "UNALIGNED" }
        if ($drive.Path -match '\.vhd$')          { $issues += "LEGACY_VHD" }
        if ($vhd.VhdType -eq 'Differencing')      { $issues += "DIFFERENCING_CHAIN" }

        [PSCustomObject]@{
            VM               = $vm.Name
            Controller       = "$($drive.ControllerType)[$($drive.ControllerNumber),$($drive.ControllerLocation)]"
            Path             = $drive.Path
            Format           = if ($drive.Path -match '\.vhds$') {"VHD Set"} elseif ($drive.Path -match '\.vhdx$') {"VHDX"} else {"VHD"}
            VHDType          = $vhd.VhdType
            AllocatedSize_GB = [math]::Round($vhd.FileSize / 1GB, 2)
            MaxSize_GB       = [math]::Round($vhd.Size / 1GB, 2)
            Fragmentation    = "$($vhd.FragmentationPercentage)%"
            Alignment        = $vhd.Alignment
            Attached         = $vhd.Attached
            MinIOPS          = $qos.MinimumIOPS
            MaxIOPS          = $qos.MaximumIOPS
            Issues           = ($issues -join ", ")
        }
    }
}

$diskReport | Format-Table VM, Format, VHDType, AllocatedSize_GB, MaxSize_GB, Fragmentation, MinIOPS, MaxIOPS, Issues -AutoSize

# ── Summary flags ─────────────────────────────────────────────────────────────
Write-Host "`n=== Issues Summary ===" -ForegroundColor Yellow
$issueDisks = $diskReport | Where-Object { $_.Issues -ne "" }
if ($issueDisks) {
    $issueDisks | Select-Object VM, Path, Issues | Format-Table -AutoSize
} else {
    Write-Host "No issues detected." -ForegroundColor Green
}

# ── Checkpoint (differencing) chain depth analysis ────────────────────────────
Write-Host "`n=== Checkpoint Chain Depth ===" -ForegroundColor Cyan
Get-VM | ForEach-Object {
    $vm = $_
    $snaps = Get-VMSnapshot -VMName $vm.Name -ErrorAction SilentlyContinue
    if ($snaps.Count -gt 0) {
        [PSCustomObject]@{
            VM          = $vm.Name
            Snapshots   = $snaps.Count
            OldestSnap  = ($snaps | Sort-Object CreationTime | Select-Object -First 1).CreationTime
            Warning     = if ($snaps.Count -gt 3) {"DEEP CHAIN — performance impact"} else {"OK"}
        }
    }
} | Format-Table -AutoSize

# ── Storage QoS active flows ──────────────────────────────────────────────────
Write-Host "`n=== Storage QoS Active Flows ===" -ForegroundColor Cyan
try {
    Get-StorageQosFlow -ErrorAction Stop |
        Select-Object InitiatorName, FilePath, Status, IOPS, Bandwidth, MinimumIops, MaximumIops, Policy |
        Format-Table -AutoSize
} catch {
    Write-Host "Storage QoS cmdlets not available on this system (requires Scale-Out File Server or S2D)." -ForegroundColor Gray
}
```

---

### 06-replication-health.ps1

```powershell
<#
.SYNOPSIS
    Hyper-V Replica health report — status, RPO compliance, failover readiness.

.DESCRIPTION
    Audits all replicated VMs on the local host. Reports replication state, health,
    last successful replication time, RPO compliance, and pending replication lag.
    Suitable for daily DR readiness checks.

.NOTES
    Version:    1.0
    Platform:   Windows Server 2016-2025 with Hyper-V role
    Requires:   Hyper-V PowerShell module; run as Administrator
    Author:     Hyper-V Diagnostic Suite
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Hyper-V Replication Health Report ===" -ForegroundColor Cyan
Write-Host "Host: $env:COMPUTERNAME  |  Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$replVMs = Get-VMReplication -ErrorAction SilentlyContinue

if (-not $replVMs) {
    Write-Host "No replication relationships found on this host." -ForegroundColor Yellow
    exit 0
}

$report = $replVMs | ForEach-Object {
    $r = $_
    $lag = $null
    $rpoViolation = $false

    if ($r.LastReplicationTime) {
        $lag = (Get-Date) - $r.LastReplicationTime
        # RPO violation if lag exceeds 2x the replication frequency
        $rpoViolation = ($lag.TotalSeconds -gt ($r.ReplicationFrequency * 2))
    }

    # Get extended statistics from Measure-VMReplication
    $stats = Measure-VMReplication -VMName $r.VMName -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        VMName              = $r.VMName
        Mode                = $r.Mode           # Primary or Replica
        State               = $r.State
        Health              = $r.Health
        ReplicaServer       = $r.ReplicaServerName
        FrequencySec        = $r.ReplicationFrequency
        LastReplication     = if ($r.LastReplicationTime) {$r.LastReplicationTime.ToString('yyyy-MM-dd HH:mm:ss')} else {"Never"}
        LagMinutes          = if ($lag) {[math]::Round($lag.TotalMinutes, 1)} else {"N/A"}
        RPO_Violation       = $rpoViolation
        RecoveryPoints      = $r.RecoveryHistory
        AutoResync          = $r.AutoResynchronizeEnabled
        Compression         = $r.CompressionEnabled
        AvgLatency_ms       = if ($stats) {$stats.AverageReplicationLatency} else {"N/A"}
        PendingSize_MB      = if ($stats) {[math]::Round($stats.PendingReplicationSize / 1MB, 1)} else {"N/A"}
    }
}

# Full table
$report | Format-Table VMName, Mode, State, Health, LagMinutes, RPO_Violation, RecoveryPoints -AutoSize

# ── Critical items ────────────────────────────────────────────────────────────
Write-Host "`n=== Critical / Warning Items ===" -ForegroundColor Yellow
$critical = $report | Where-Object { $_.Health -ne 'Normal' -or $_.RPO_Violation -eq $true -or $_.State -notin 'Replicating','Enabled' }

if ($critical) {
    $critical | Format-Table VMName, Mode, State, Health, LagMinutes, RPO_Violation -AutoSize
} else {
    Write-Host "All replication relationships are healthy." -ForegroundColor Green
}

# ── Detailed stats ────────────────────────────────────────────────────────────
Write-Host "`n=== Detailed Replication Statistics ===" -ForegroundColor Cyan
$report | Format-List VMName, Mode, State, Health, FrequencySec, LastReplication, LagMinutes, AvgLatency_ms, PendingSize_MB, RecoveryPoints, Compression, AutoResync

# ── Replica server config (if this host is a replica server) ──────────────────
Write-Host "`n=== Replica Server Configuration ===" -ForegroundColor Cyan
$replicaConfig = Get-VMReplicationServer -ErrorAction SilentlyContinue
if ($replicaConfig -and $replicaConfig.ReplicationEnabled) {
    $replicaConfig | Select-Object ReplicationEnabled, AllowedAuthenticationType,
        KerberosAuthorizationPort, CertificateAuthorizationPort, MonitoringInterval, MonitoringStartTime |
        Format-List
} else {
    Write-Host "This host is not configured as a replica server (or replication server is disabled)." -ForegroundColor Gray
}
```

---

### 07-live-migration.ps1

```powershell
<#
.SYNOPSIS
    Live migration configuration and network binding audit.

.DESCRIPTION
    Reports live migration host configuration, concurrent migration limits, authentication
    method, performance options (Compression vs SMB Transport), and network binding for
    migration traffic. Also shows recent migration events from the event log.

.NOTES
    Version:    1.0
    Platform:   Windows Server 2016-2025 with Hyper-V role
    Requires:   Hyper-V PowerShell module; run as Administrator
    Author:     Hyper-V Diagnostic Suite
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Live Migration Configuration ===" -ForegroundColor Cyan
Write-Host "Host: $env:COMPUTERNAME`n"

# ── Host-level migration settings ─────────────────────────────────────────────
$vmHost = Get-VMHost
[PSCustomObject]@{
    MigrationEnabled            = $vmHost.VirtualMachineMigrationEnabled
    MaxConcurrentMigrations     = $vmHost.MaximumVirtualMachineMigrations
    MaxConcurrentStorageMig     = $vmHost.MaximumStorageMigrations
    AuthenticationType          = $vmHost.VirtualMachineMigrationAuthenticationType
    PerformanceOption           = $vmHost.VirtualMachineMigrationPerformanceOption
    UseAnyNetwork               = $vmHost.UseAnyNetworkForMigration
} | Format-List

# ── Migration network bindings ─────────────────────────────────────────────────
Write-Host "`n=== Migration Network Bindings ===" -ForegroundColor Cyan
try {
    Get-VMMigrationNetwork -ComputerName $env:COMPUTERNAME |
        Select-Object Subnet, Priority |
        Format-Table -AutoSize
} catch {
    Write-Warning "Could not retrieve migration network bindings: $_"
}

# ── RDMA adapters (for SMB Direct live migration) ─────────────────────────────
Write-Host "`n=== RDMA-Capable Adapters ===" -ForegroundColor Cyan
try {
    Get-NetAdapterRdma | Where-Object Enabled -eq $true |
        Select-Object Name, InterfaceDescription, Enabled, MaxQueuePairCount, MaxMemoryRegionCount |
        Format-Table -AutoSize
} catch {
    Write-Host "RDMA adapter query not available." -ForegroundColor Gray
}

# ── Current migration operations (if any active) ──────────────────────────────
Write-Host "`n=== Currently Running VMs (migration candidates) ===" -ForegroundColor Cyan
Get-VM | Where-Object State -eq 'Running' |
    Select-Object Name, State, @{n="CPU%";e={$_.CPUUsage}},
        @{n="Mem_GB";e={[math]::Round($_.MemoryAssigned/1GB,1)}},
        @{n="DiskCount";e={@(Get-VMHardDiskDrive -VMName $_.Name).Count}} |
    Format-Table -AutoSize

# ── Processor compatibility mode status ───────────────────────────────────────
Write-Host "`n=== Processor Compatibility Mode (Live Migration) ===" -ForegroundColor Cyan
Get-VM | ForEach-Object {
    $proc = Get-VMProcessor -VMName $_.Name
    [PSCustomObject]@{
        VM                    = $_.Name
        CompatibilityEnabled  = $proc.CompatibilityForMigrationEnabled
        MigrationExtensions   = $proc.CompatibilityForOlderOperatingSystemsEnabled
    }
} | Format-Table -AutoSize

# ── Recent migration events ───────────────────────────────────────────────────
Write-Host "`n=== Recent Live Migration Events (last 24 hours) ===" -ForegroundColor Cyan
$cutoff = (Get-Date).AddHours(-24)
Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-Migration-Admin" -MaxEvents 50 -ErrorAction SilentlyContinue |
    Where-Object { $_.TimeCreated -gt $cutoff } |
    Select-Object TimeCreated, LevelDisplayName, Id, Message |
    Format-Table TimeCreated, LevelDisplayName, Id, @{n="Message";e={$_.Message.Substring(0,[Math]::Min(120,$_.Message.Length))}} -AutoSize -Wrap
```

---

### 08-checkpoint-audit.ps1

```powershell
<#
.SYNOPSIS
    Checkpoint inventory — age, type, disk space impact, and differencing chain analysis.

.DESCRIPTION
    Enumerates all VM checkpoints (snapshots) across all VMs. Reports checkpoint type,
    creation time, age in days, and estimates disk space consumed by differencing
    VHDX files (.avhdx) associated with each checkpoint chain.

.NOTES
    Version:    1.0
    Platform:   Windows Server 2016-2025 with Hyper-V role
    Requires:   Hyper-V PowerShell module; run as Administrator
    Author:     Hyper-V Diagnostic Suite
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Checkpoint Audit ===" -ForegroundColor Cyan
Write-Host "Host: $env:COMPUTERNAME  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$allCheckpoints = Get-VM | ForEach-Object {
    $vm = $_
    $snaps = Get-VMSnapshot -VMName $vm.Name -ErrorAction SilentlyContinue
    foreach ($snap in $snaps) {
        # Find associated differencing disks (.avhdx files)
        $avhdxFiles = @()
        $avhdxSize_GB = 0
        $vmDir = Split-Path -Parent (Get-VMHardDiskDrive -VMName $vm.Name |
            Where-Object Path -ne $null | Select-Object -First 1 -ExpandProperty Path) -ErrorAction SilentlyContinue

        if ($vmDir) {
            $avhdxFiles = Get-ChildItem -Path $vmDir -Filter "*.avhdx" -ErrorAction SilentlyContinue
            $avhdxSize_GB = [math]::Round(($avhdxFiles | Measure-Object Length -Sum).Sum / 1GB, 2)
        }

        $ageDays = [math]::Round(((Get-Date) - $snap.CreationTime).TotalDays, 1)

        [PSCustomObject]@{
            VM              = $vm.Name
            SnapshotName    = $snap.Name
            Type            = $snap.SnapshotType
            CreationTime    = $snap.CreationTime.ToString('yyyy-MM-dd HH:mm')
            AgeDays         = $ageDays
            ParentCheckpoint= $snap.ParentSnapshotName
            avhdx_Count     = $avhdxFiles.Count
            avhdx_Size_GB   = $avhdxSize_GB
            AgeWarning      = if ($ageDays -gt 30) {"STALE >30d"} elseif ($ageDays -gt 7) {"OLD >7d"} else {"OK"}
        }
    }
}

if (-not $allCheckpoints) {
    Write-Host "No checkpoints found on any VM." -ForegroundColor Green
    exit 0
}

$allCheckpoints | Format-Table VM, SnapshotName, Type, CreationTime, AgeDays, avhdx_Size_GB, AgeWarning -AutoSize

# ── Stale checkpoints ─────────────────────────────────────────────────────────
Write-Host "`n=== Checkpoints Older Than 7 Days ===" -ForegroundColor Yellow
$stale = $allCheckpoints | Where-Object AgeDays -gt 7 | Sort-Object AgeDays -Descending
if ($stale) {
    $stale | Select-Object VM, SnapshotName, AgeDays, avhdx_Size_GB, AgeWarning | Format-Table -AutoSize
} else {
    Write-Host "None found." -ForegroundColor Green
}

# ── Total checkpoint disk impact per VM ───────────────────────────────────────
Write-Host "`n=== Checkpoint Disk Space Impact per VM ===" -ForegroundColor Cyan
$allCheckpoints | Group-Object VM | ForEach-Object {
    [PSCustomObject]@{
        VM              = $_.Name
        TotalCheckpoints = $_.Count
        TotalavhdxGB    = ($_.Group | Measure-Object avhdx_Size_GB -Maximum).Maximum  # avhdx is shared per VM dir
        OldestDays      = ($_.Group | Measure-Object AgeDays -Maximum).Maximum
    }
} | Sort-Object OldestDays -Descending | Format-Table -AutoSize
```

---

### 09-integration-services.ps1

```powershell
<#
.SYNOPSIS
    Integration Services health and version audit — all VMs including Linux guests.

.DESCRIPTION
    Reports the status of all Integration Services components for each VM.
    Flags disabled or degraded services. For Linux VMs, attempts to identify
    the LIS component version via KVP (Key-Value Pair) data exchange.

.NOTES
    Version:    1.0
    Platform:   Windows Server 2016-2025 with Hyper-V role
    Requires:   Hyper-V PowerShell module; run as Administrator
    Author:     Hyper-V Diagnostic Suite
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Integration Services Audit ===" -ForegroundColor Cyan
Write-Host "Host: $env:COMPUTERNAME  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# ── Per-VM IS component status ────────────────────────────────────────────────
$isReport = Get-VM | ForEach-Object {
    $vm = $_
    $services = Get-VMIntegrationService -VMName $vm.Name -ErrorAction SilentlyContinue

    $heartbeat  = $services | Where-Object Name -eq 'Heartbeat'
    $shutdown   = $services | Where-Object Name -eq 'Operating System Shutdown'
    $timeSync   = $services | Where-Object Name -eq 'Time Synchronization'
    $dataEx     = $services | Where-Object Name -eq 'Data Exchange'
    $vss        = $services | Where-Object Name -eq 'Volume Shadow Copy'
    $guestSvc   = $services | Where-Object Name -eq 'Guest Service Interface'

    [PSCustomObject]@{
        VM              = $vm.Name
        State           = $vm.State
        ISVersion       = $vm.IntegrationServicesVersion
        Heartbeat       = if ($heartbeat) { $heartbeat.PrimaryStatusDescription } else { "N/A" }
        Shutdown        = if ($shutdown)  { if ($shutdown.Enabled)  {"OK"}  else {"Disabled"} } else { "N/A" }
        TimeSync        = if ($timeSync)  { if ($timeSync.Enabled)  {"OK"}  else {"Disabled"} } else { "N/A" }
        DataExchange    = if ($dataEx)    { if ($dataEx.Enabled)    {"OK"}  else {"Disabled"} } else { "N/A" }
        VSS             = if ($vss)       { $vss.PrimaryStatusDescription } else { "N/A" }
        GuestServices   = if ($guestSvc)  { if ($guestSvc.Enabled)  {"OK"}  else {"Disabled"} } else { "N/A" }
        IssueCount      = ($services | Where-Object { -not $_.Enabled -or $_.PrimaryStatusDescription -notin 'OK','No Contact' }).Count
    }
}

$isReport | Format-Table VM, State, ISVersion, Heartbeat, Shutdown, TimeSync, DataExchange, VSS, GuestServices -AutoSize

# ── VMs with IS issues ────────────────────────────────────────────────────────
Write-Host "`n=== VMs with Integration Service Issues ===" -ForegroundColor Yellow
$issues = $isReport | Where-Object { $_.IssueCount -gt 0 -or $_.Heartbeat -notin 'OK','No Contact','Not Applicable' }
if ($issues) {
    $issues | Select-Object VM, ISVersion, Heartbeat, Shutdown, TimeSync, DataExchange, VSS | Format-Table -AutoSize
} else {
    Write-Host "All VMs have no Integration Services issues." -ForegroundColor Green
}

# ── KVP data for Linux guests ─────────────────────────────────────────────────
Write-Host "`n=== KVP Data Exchange (Guest Information) ===" -ForegroundColor Cyan
Get-VM | Where-Object State -eq 'Running' | ForEach-Object {
    $vm = $_
    try {
        $kvpData = (Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_KvpExchangeComponent -ErrorAction Stop |
            Where-Object { $_.SystemName -eq $vm.Id -or $_.Caption -match $vm.Name })

        if ($kvpData) {
            $guestProps = [xml]("<root>" + ($kvpData.GuestIntrinsicExchangeItems -join "") + "</root>")
            $osName = ($guestProps.root.INSTANCE | Where-Object { ($_.PROPERTY | Where-Object Name -eq 'Name' | Select-Object -ExpandProperty VALUE) -eq 'OSName' } |
                ForEach-Object { $_.PROPERTY | Where-Object Name -eq 'Data' | Select-Object -ExpandProperty VALUE })

            Write-Host "  $($vm.Name): OS=$($osName | Select-Object -First 1)"
        }
    } catch {
        # KVP query failure is non-critical
    }
}
```

---

### 10-nested-virt.ps1

```powershell
<#
.SYNOPSIS
    Nested virtualization configuration audit and validation.

.DESCRIPTION
    Validates nested virtualization prerequisites and reports which VMs have
    ExposeVirtualizationExtensions enabled. Checks host CPU support, VM generation,
    MAC spoofing, and Dynamic Memory compatibility with nested Hyper-V.

.NOTES
    Version:    1.0
    Platform:   Windows Server 2016+ (Intel VT-x nested); Windows Server 2022+ (AMD nested)
    Requires:   Hyper-V PowerShell module; run as Administrator
    Author:     Hyper-V Diagnostic Suite

    Nested Virtualization Requirements:
    - Host: Intel VT-x (2016+) or AMD-V (2022+)
    - VM: Generation 2 (recommended) or Generation 1 with specific config
    - VM RAM: 4 GB minimum recommended
    - vCPUs: 2 minimum
    - Dynamic Memory: Must be disabled in the nested VM guest for reliable operation
    - MAC Spoofing: Must be enabled on the VM's vNIC if guest VMs need networking
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Nested Virtualization Audit ===" -ForegroundColor Cyan
Write-Host "Host: $env:COMPUTERNAME  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# ── Host CPU nested virt support ──────────────────────────────────────────────
Write-Host "=== Host CPU Capabilities ===" -ForegroundColor Cyan
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuName = $cpu.Name
$isIntel = $cpuName -match 'Intel'
$isAMD   = $cpuName -match 'AMD'
$osVer   = [System.Environment]::OSVersion.Version

Write-Host "CPU: $cpuName"
Write-Host "Architecture: $(if($isIntel){'Intel (nested virt: WS2016+)'} elseif($isAMD){'AMD (nested virt: WS2022+)'} else {'Unknown'})"
Write-Host "Host OS Build: $($osVer.Build)"

if ($isAMD -and $osVer.Build -lt 20348) {
    Write-Warning "AMD nested virtualization requires Windows Server 2022 (build 20348+). Current build: $($osVer.Build)"
}

# ── Check virtualization extensions exposed to this host ──────────────────────
$vmssEnabled = (Get-WmiObject Win32_ComputerSystem).HypervisorPresent
Write-Host "Running as guest (nested already): $vmssEnabled"

# ── Per-VM nested virt configuration ─────────────────────────────────────────
Write-Host "`n=== VM Nested Virtualization Status ===" -ForegroundColor Cyan
$nestedReport = Get-VM | ForEach-Object {
    $vm = $_
    $proc   = Get-VMProcessor -VMName $vm.Name
    $mem    = Get-VMMemory -VMName $vm.Name
    $nics   = Get-VMNetworkAdapter -VMName $vm.Name

    $issues = @()
    if ($vm.Generation -ne 2)              { $issues += "Gen1 (Gen2 preferred)" }
    if ($mem.DynamicMemoryEnabled)         { $issues += "DynamicMem=ON (disable for nested Hyper-V)" }
    if ($mem.Startup -lt 4GB)             { $issues += "RAM<4GB" }
    if ($proc.Count -lt 2)                { $issues += "vCPU<2" }
    if ($proc.ExposeVirtualizationExtensions) {
        # If nested virt ON, check MAC spoofing
        $noSpoofNics = $nics | Where-Object MacAddressSpoofing -ne 'On'
        if ($noSpoofNics) { $issues += "MACSpoof=OFF on $($noSpoofNics.Count) NIC(s)" }
    }

    [PSCustomObject]@{
        VM                    = $vm.Name
        State                 = $vm.State
        Generation            = $vm.Generation
        NestedVirtEnabled     = $proc.ExposeVirtualizationExtensions
        vCPUs                 = $proc.Count
        AssignedMem_GB        = [math]::Round($vm.MemoryAssigned / 1GB, 1)
        DynamicMemory         = $mem.DynamicMemoryEnabled
        MacSpoofing           = ($nics | Select-Object -First 1 -ExpandProperty MacAddressSpoofing)
        ConfigurationIssues   = ($issues -join "; ")
        Prerequisites         = if ($issues.Count -eq 0 -or ($issues.Count -eq 1 -and $issues[0] -match 'Gen1')) {"READY"} else {"ISSUES"}
    }
}

$nestedReport | Format-Table VM, State, Generation, NestedVirtEnabled, vCPUs, AssignedMem_GB, DynamicMemory, MacSpoofing, Prerequisites -AutoSize

# ── VMs with nested virt enabled ─────────────────────────────────────────────
Write-Host "`n=== VMs with Nested Virtualization Enabled ===" -ForegroundColor Cyan
$enabledVMs = $nestedReport | Where-Object NestedVirtEnabled -eq $true
if ($enabledVMs) {
    $enabledVMs | Select-Object VM, State, Generation, vCPUs, AssignedMem_GB, DynamicMemory, MacSpoofing, ConfigurationIssues |
        Format-Table -AutoSize
} else {
    Write-Host "No VMs currently have nested virtualization enabled." -ForegroundColor Gray
}

# ── Configuration issues ──────────────────────────────────────────────────────
Write-Host "`n=== Configuration Issues for Nested Virt ===" -ForegroundColor Yellow
$withIssues = $nestedReport | Where-Object { $_.NestedVirtEnabled -and $_.ConfigurationIssues -ne "" }
if ($withIssues) {
    $withIssues | Select-Object VM, ConfigurationIssues | Format-Table -AutoSize -Wrap
} else {
    Write-Host "No configuration issues on nested-virt-enabled VMs." -ForegroundColor Green
}

Write-Host "`nTo enable nested virtualization on a stopped VM:"
Write-Host '  Set-VMProcessor -VMName "NestedHost-VM" -ExposeVirtualizationExtensions $true' -ForegroundColor DarkGray
Write-Host "To enable MAC spoofing (required if nested VMs need network access):"
Write-Host '  Set-VMNetworkAdapter -VMName "NestedHost-VM" -MacAddressSpoofing On' -ForegroundColor DarkGray
```

---

## Part 5: Version-Specific Changes

### Windows Server 2016 (Config Version 8.0)

**Major Hyper-V additions:**

- **Nested Virtualization (Intel VT-x only):** Run Hyper-V inside a Hyper-V VM. Enables running Hyper-V lab environments, testing containerization, and Windows Insider builds in VMs. Enable with `Set-VMProcessor -ExposeVirtualizationExtensions $true`.
- **Production Checkpoints (default):** VSS-based checkpoints replace standard (saved-state) checkpoints as default. Application-consistent, suitable for production backup workflows.
- **VM Configuration Version 8.0:** New binary config format (.vmcx/.vmrs) replaces XML. Faster parse times, atomic writes, reduced corruption risk.
- **Hot-add vNIC and Memory (Gen2):** Add vNICs and increase memory on running Gen2 VMs without shutdown.
- **Shielded VMs:** Encrypted VMs protected by HGS (Host Guardian Service). Prevents host admin from inspecting or tampering with VM contents. Uses vTPM + BitLocker inside the guest. Critical for multi-tenant or hostile-host scenarios.
- **Discrete Device Assignment (DDA):** Pass a PCIe device (GPU, NVMe, FPGA) directly to a VM. Not live-migratable; designed for workloads needing direct hardware access.
- **PowerShell Direct:** Run PowerShell commands inside a VM via VMBus without network connectivity. Uses `Enter-PSSession -VMName "VM1"` or `Invoke-Command -VMName "VM1"`. Invaluable for network-misconfigured VMs.
- **Container integration:** Hyper-V containers (each container in isolated VM partition) introduced. Foundation for Windows container isolation.
- **Hot resize:** vNIC and RAM hot-add for running Gen2 VMs.

### Windows Server 2019 (Config Version 9.0)

**Hyper-V changes:**

- **Improved RDMA performance:** Enhanced SMB Direct support for live migration and CSV access. Consistent 25/40/100 GbE RDMA throughput.
- **VM CPU/Memory hot-resize (Gen2, broader):** More scenarios for online vCPU and memory addition.
- **Shielded VMs for Linux:** Extended Shielded VM support to Linux guests (Ubuntu 16.04+, RHEL 7.3+). Linux VMs can be protected by HGS with vTPM.
- **Storage Spaces Direct (S2D) improvements:** Better resync performance, mixed media (NVMe + SSD + HDD) tiers, deduplication on ReFS.
- **Network performance:** Default MTU increased for HNV workloads; improved VXLAN gateway performance.
- **VM configuration version 9.0:** Incremental internal improvements (no major user-facing changes).
- **Windows Admin Center integration:** Hyper-V management fully available through WAC browser-based interface.

### Windows Server 2022 (Config Version 10.0)

**Hyper-V changes:**

- **Nested Virtualization on AMD (EPYC/Ryzen):** Nested Hyper-V now works on AMD processors (not just Intel). Enables cloud providers using AMD CPUs to support nested scenarios.
- **vTPM for Linux VMs:** Linux guests can use a virtual TPM 2.0 (backed by HGS). Enables dm-crypt/LUKS full disk encryption with TPM binding inside Linux VMs.
- **Processor compatibility mode improvements:** Better cross-version live migration with broader CPU feature baseline.
- **SMB over QUIC:** SMB file shares accessible over QUIC (UDP-based transport). Enables file-based storage access over internet-facing paths without VPN. Relevant for WAC and branch office Hyper-V connectivity.
- **Azure Arc integration:** Hyper-V hosts can register with Azure Arc for hybrid management, Azure Policy compliance, and update management.
- **Secured-core Server:** Hardware-based security features (Secure Boot, DRTM, VBS, HVCI) required by default on Secured-core certified hardware. Hyper-V leverages HVCI (Hypervisor-Protected Code Integrity).
- **ARM64 guest support (preview):** Early support for running ARM64 VMs on ARM64 Hyper-V hosts.

### Windows Server 2025 (Config Version 12.0)

**Hyper-V changes:**

- **GPU Partitioning (GPU-P) with Live Migration:** GPU partitions can now be live-migrated between hosts (requires compatible GPU hardware across cluster nodes). This enables VDI and AI/ML workloads to benefit from HA without GPU downtime.
- **GPU-P with Failover Clustering:** GPU-enabled VMs participate fully in cluster failover scenarios.
- **2048 vCPUs per VM:** Maximum vCPU count per VM doubled from 1024 to 2048. Enables extremely large in-memory computing workloads.
- **240 TB RAM per VM:** Maximum VM memory increased to 240 TB (up from 12 TB in 2022). Targets in-memory databases (SAP HANA, Oracle TimesTen) at extreme scale.
- **Improved Nested Virtualization:** Better performance isolation and support for nested containers with Hyper-V isolation.
- **Network improvements:** Enhanced SR-IOV pipeline, improved HNV gateway throughput.
- **Storage:** VHDX format improvements for very large disks (approaching 64 TB with better metadata performance).
- **NUMA performance:** Improved automatic NUMA-aware VM placement algorithms.
- **Windows Admin Center (built-in):** WAC management plane is integrated into Windows Server 2025 without separate download.

---

## Configuration Version Upgrade Path

```powershell
# After upgrading Windows Server version on a host, upgrade VM config versions
# CAUTION: Cannot revert after upgrade — VM cannot be moved to older host version

# Check all VM versions
Get-VM | Select-Object Name, Version | Sort-Object Version

# Upgrade a single VM (VM should be off or saved state)
Update-VMVersion -VMName "VM1"

# Upgrade all VMs on host (batch — verify each is not needed on old hosts first)
Get-VM | Where-Object Version -lt "10.0" | Stop-VM -Force -Passthru |
    Update-VMVersion -Force
```

---

## Quick Reference Tables

### Hyper-V Firewall Ports

| Port | Protocol | Purpose |
|---|---|---|
| 2179 | TCP | Hyper-V Remote Management (vmms) |
| 6600 | TCP | Live Migration |
| 445 | TCP | SMB (storage live migration, CSV) |
| 135 | TCP | RPC Endpoint Mapper |
| 8080 | TCP | Hyper-V Replica (Kerberos, default) |
| 443 | TCP | Hyper-V Replica (Certificate) |
| 3343 | UDP | Cluster Heartbeat |

### Key PowerShell Module Commands

| Task | Cmdlet |
|---|---|
| List all VMs | `Get-VM` |
| Start/Stop VM | `Start-VM`, `Stop-VM` |
| Create VM | `New-VM` |
| Create virtual switch | `New-VMSwitch` |
| Live migrate VM | `Move-VM` |
| Storage migrate | `Move-VMStorage` |
| Create checkpoint | `Checkpoint-VM` |
| Restore checkpoint | `Restore-VMSnapshot` |
| Delete checkpoint | `Remove-VMSnapshot` |
| Enable replication | `Enable-VMReplication` |
| Get VHD metadata | `Get-VHD` |
| Resize VHD | `Resize-VHD` |
| Compact VHD | `Optimize-VHD` |
| Mount VHD | `Mount-VHD` |
| Test live migration | `Test-VMMigration` |
| Remote PS to VM | `Enter-PSSession -VMName` |

### Memory Pressure Thresholds

| Pressure % | Meaning | Action |
|---|---|---|
| 0–80 | VM has excess RAM; DM may reclaim | Normal |
| 80–100 | All assigned RAM in use | Normal, monitor |
| 100–150 | VM needs more RAM; DM attempting to add | Monitor, may need tuning |
| >150 | VM is starved; likely paging to disk | Immediate action: increase min/max RAM or add host RAM |
