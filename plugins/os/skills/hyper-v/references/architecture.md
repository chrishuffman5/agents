# Hyper-V Architecture Reference

## Type-1 Hypervisor Model

When the Hyper-V role is installed and the system reboots, the Windows hypervisor (`hvax64.exe` / `hvloader.exe`) takes control of the hardware ring-0 layer. The Windows Server OS becomes the **parent partition** -- a privileged virtual machine that retains direct driver access through a pass-through model. All other VMs are **child partitions** that access hardware only through synthetic or emulated paths.

### Key Layers

- **Hypervisor layer**: Manages CPU virtualization (Intel VT-x / AMD-V), memory isolation (EPT/NPT), and APIC virtualization
- **Parent partition**: Runs the Windows Server management OS; owns physical device drivers; exposes Virtualization Service Providers (VSPs)
- **Child partitions**: Run guest OSes; consume virtual resources through Virtualization Service Clients (VSCs)

---

## VMBus

VMBus is a high-speed inter-partition communication channel. It serves as the transport for all synthetic devices.

Key characteristics:
- Lives in kernel memory shared between parent and child partitions
- Uses ring buffers for producer/consumer I/O
- Dramatically lower latency than emulated device I/O (no hardware emulation overhead)
- Requires Integration Services on the guest side (the VSC driver stack)

I/O path for a synthetic disk request: Guest VSC -> hypervisor -> VMBus ring buffer -> parent partition VSP -> physical driver -> disk.

---

## Hypercall Interface

The hypervisor exposes a hypercall ABI (analogous to a syscall ABI). Guest OSes use hypercalls for privileged operations:
- `HvCallNotifyLongSpinWait` -- Notify the hypervisor the guest is spin-waiting (yields CPU)
- `HvCallFlushVirtualAddressSpace` -- TLB flush across virtual processors
- `HvCallSignalEvent` -- Inter-partition signaling
- Memory management hypercalls (GPA/SPA translations)

Hypercalls are used heavily by enlightened guests. Unenlightened guests use standard virtualized hardware paths at a performance penalty.

---

## Synthetic vs Emulated Devices

| Type | Description | Performance |
|---|---|---|
| **Synthetic** | VMBus-connected; VSC/VSP model; requires Integration Services | High (near-native) |
| **Emulated** | Hardware emulation (IDE, legacy NIC); available before IS loaded | Low (emulation overhead) |
| **Paravirtualized** | Direct hypercall interface (enlightened timers, TLB shootdowns) | Highest (direct calls) |

Gen1 VMs expose emulated hardware for boot (IDE, emulated BIOS, legacy NIC) then switch to synthetic devices after Integration Services load. Gen2 VMs skip emulation entirely -- even the boot path is synthetic.

---

## Enlightenments

Enlightenments are guest OS modifications that allow the OS to cooperate with the hypervisor directly instead of relying on hardware emulation:

- **Synthetic MSRs**: Read/write hypervisor registers without emulated hardware
- **Relaxed timer**: Guest backs off on timer interrupts under low load (reduces VMEXIT overhead)
- **Enlightened spinlock**: Spin loops yield to the hypervisor instead of burning CPU cycles
- **Direct flip**: Memory map changes without full TLB shootdown
- **APIC enlightenment**: Eliminates emulated APIC MSR exits

Windows Server 2016+ guests are deeply enlightened. Linux guests (RHEL, Ubuntu, SUSE) have mature LIS/upstream drivers since kernel 3.4+.

---

## Virtual Machine Generations

### Gen1 VMs

- **Firmware**: BIOS (legacy, emulated)
- **Boot devices**: IDE (positions 0 and 1), legacy network boot via emulated NIC
- **Hardware**: Emulated IDE controller, emulated NIC (synthetic available after IS), COM ports, floppy controller
- **Max boot VHDX**: 2 TB (MBR limitation)
- **Secure Boot**: Not supported
- **Use cases**: Legacy OS (Windows Server 2003/2008 without UEFI), 32-bit guests, VMs requiring emulated hardware

### Gen2 VMs

- **Firmware**: UEFI (Unified Extensible Firmware Interface)
- **Boot devices**: SCSI (synthetic, VMBus-connected; faster than emulated IDE)
- **Secure Boot**: Supported and enabled by default (templates: Windows, MicrosoftUEFI, OpenSourceShielded)
- **vTPM**: Supported (software TPM 2.0 backed by Host Guardian Service)
- **Network boot**: PXE via synthetic NIC (no legacy NIC required)
- **Hot-add**: vNIC and VHDX hot-add supported (2016+)
- **Use cases**: All new VMs on supported guest OS (Windows Server 2012+, Windows 8+, modern Linux)

### VM Configuration Versions

Configuration version controls the format of VM config files and determines which features are available. It is separate from generation.

| Windows Server | Config Version | Key New Features |
|---|---|---|
| 2016 | 8.0 | Production checkpoints, hot-add NIC, nested virt |
| 2019 | 9.0 | Hot-resize memory/CPU (Gen2), RDMA improvements |
| 2022 | 10.0 | vTPM for Linux, AMD nested virt, enhanced networking |
| 2025 | 12.0 | GPU-P live migration, 2048 vCPU, 240 TB RAM |

Upgrading configuration version is **irreversible** -- the VM cannot be moved back to an older host after upgrade:
```powershell
Get-VM | Select-Object Name, Version
Update-VMVersion -VMName "MyVM" -Force   # cannot revert
```

---

## Memory Architecture

### Static vs Dynamic Memory

**Static Memory**: A fixed amount of RAM allocated at startup. Simple and predictable. Best for database servers where the application manages its own memory caches.

**Dynamic Memory**: Hyper-V balances memory using a balloon driver mechanism.

Parameters:
- **Startup RAM**: Memory at boot (before balancer engages). Must be >= Minimum RAM.
- **Minimum RAM**: Floor. Guaranteed even under host pressure.
- **Maximum RAM**: Ceiling. VM can never exceed this.
- **Memory Buffer**: Percentage of headroom above current demand (default: 20%).
- **Memory Weight**: Priority (0-10000) when host memory is scarce (default: 5000).

Dynamic Memory algorithm:
1. Monitor `Current Demand` (reported by balloon driver)
2. Calculate `Target Assigned` = Current Demand + Buffer%
3. If Target > Assigned: add memory (balloon contracts, exposing pages)
4. If Target < Assigned: reclaim memory (balloon inflates, consuming pages)

### NUMA Topology

Non-Uniform Memory Access affects performance when a VM's vCPUs span multiple physical NUMA nodes.

- **NUMA-aligned placement** (default): All vCPUs and memory for a VM within a single NUMA node. Eliminates remote memory access latency.
- **NUMA spanning**: Allows VMs larger than a single NUMA node. Accepted for very large VMs but incurs cross-NUMA latency.

```powershell
Get-VMHostNumaNode
Get-VMNumaTopology -VMName "MyVM"
(Get-VMHost).NumaSpanningEnabled
Set-VMProcessor -VMName "BigVM" -MaximumCountPerNumaNode 16 -MaximumCountPerNumaSocket 32
```

### Memory Hot-Add

Gen2 VMs with Dynamic Memory can receive memory additions without restart. The guest OS must support memory hot-add (Windows Server 2016+, modern Linux kernels).

Static memory VMs require a restart to change allocation.

### Smart Paging

A fallback mechanism used only during VM restart. If the host does not have enough physical RAM to satisfy a VM's Startup RAM requirement (but has Minimum RAM available), Hyper-V uses a page file on the host to back the difference. Significantly slower than physical RAM -- treat as an emergency mechanism.

---

## Virtual Networking

### Virtual Switch Types

| Type | Host-to-VM | VM-to-VM | VM-to-External | Notes |
|---|---|---|---|---|
| **External** | Yes | Yes | Yes (via physical NIC) | Requires a physical NIC binding |
| **Internal** | Yes | Yes | No | Host can communicate, no external |
| **Private** | No | Yes | No | Complete isolation |

```powershell
New-VMSwitch -Name "External-Switch" -NetAdapterName "Ethernet 1" -AllowManagementOS $true
New-VMSwitch -Name "Internal-Switch" -SwitchType Internal
New-VMSwitch -Name "Private-Switch" -SwitchType Private
```

### Switch Embedded Teaming (SET)

SET replaces legacy NIC teaming (LBFO) for Hyper-V environments. LBFO cannot be used with RDMA or SR-IOV.

- Integrated into the Hyper-V virtual switch (no separate team NIC)
- Supports 1-8 physical NICs in the team
- Supports RDMA on team members (unlike LBFO + vSwitch)
- Supports SR-IOV on team members
- Load balancing: Hyper-V port mode (hashes by VM source MAC/IP)
- **Limitation**: Only Hyper-V port load distribution mode (no dynamic/LACP)

```powershell
New-VMSwitch -Name "SET-Switch" -NetAdapterName "NIC1","NIC2" `
    -EnableEmbeddedTeaming $true -AllowManagementOS $true
```

### SR-IOV (Single Root I/O Virtualization)

Hardware-level NIC virtualization. Physical NICs expose Virtual Functions (VFs) assigned directly to VMs, bypassing the software vSwitch path.

- Near line-rate throughput with minimal CPU overhead
- Requires: Physical NIC with SR-IOV support, BIOS with SR-IOV/ACS enabled
- VF is released during live migration (falls back to synthetic NIC)
- Not compatible with some port ACLs or network policies

```powershell
New-VMSwitch -Name "SRIOV-Switch" -NetAdapterName "SR-IOV NIC" -EnableIov $true
Set-VMNetworkAdapter -VMName "VM1" -Name "Network Adapter" -IovWeight 100
```

### VLAN Configuration

```powershell
# Access mode (single VLAN -- frames arrive untagged to guest)
Set-VMNetworkAdapterVlan -VMName "VM1" -Access -VlanId 100

# Trunk mode (multiple VLANs -- guest is a router/firewall)
Set-VMNetworkAdapterVlan -VMName "Router-VM" -Trunk -AllowedVlanIdList "100,200,300" -NativeVlanId 0

# Management OS VLAN isolation
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "Management" -Access -VlanId 10
```

---

## Virtual Storage

### VHD vs VHDX

| Property | VHD | VHDX |
|---|---|---|
| Max size | 2 TB | 64 TB |
| Block size | 512 bytes | 4 KB (aligned to modern drives) |
| Metadata | Vulnerable to corruption on power loss | Journaled (transaction-safe) |
| Online resize | No | Yes |
| Trim/Unmap | No | Yes |

Use VHDX for all new disks.

### Disk Types

| Type | Performance | Space Efficiency | Use Case |
|---|---|---|---|
| **Fixed** | Best (no metadata lookups) | Poor (full pre-allocation) | Databases, latency-sensitive |
| **Dynamic** | Good (slight overhead) | Best (only used space) | General workloads on fast storage |
| **Differencing** | Variable (parent chain) | Depends on change rate | Checkpoints (avoid deep chains) |

### Shared VHDX and VHD Sets

For guest clustering (multiple VMs sharing a disk):
- **Shared VHDX** (2012 R2+): Limited -- no host-side VSS backup, no hot-add/remove
- **VHD Sets (.vhds)** (2016+): Preferred. Supports host-side VSS backup, online checkpoints, resize.

### Storage QoS

```powershell
Set-VMHardDiskDrive -VMName "VM1" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0 `
    -MinimumIOPS 500 -MaximumIOPS 5000
Get-StorageQosFlow | Select-Object InitiatorName, IOPS, Bandwidth, MinimumIops, MaximumIops
```

### Virtual Fibre Channel

Allows VMs to connect directly to FC SANs through host HBAs using N_Port ID Virtualization (NPIV). Requires a physical HBA that supports NPIV and SAN zoning for the VM's virtual WWN pair.

---

## Integration Services

| Component | Function |
|---|---|
| **Operating System Shutdown** | Clean shutdown from Hyper-V Manager/PowerShell |
| **Time Synchronization** | Sync guest clock to host (configurable per VM) |
| **Data Exchange (KVP)** | Key-Value Pair exchange between host and guest |
| **Heartbeat** | Periodic liveness signal from guest to host |
| **VSS** | Coordinate VSS backups from host; quiesce guest I/O |
| **Guest Services** | PowerShell Direct file copy; Copy-VMFile cmdlet |
| **Dynamic Memory** | Balloon driver for DM operations |

### Windows IS Delivery (2016+)

Integration Services for Windows guests are delivered via Windows Update. IS updates no longer require VM downtime. Verify IS level: `Get-VMIntegrationService -VMName "VM1"`

### Linux Integration Services

Enlightenment drivers in the mainline Linux kernel since 3.4+:
- `hv_vmbus` -- VMBus transport driver
- `hv_storvsc` -- Synthetic SCSI storage controller
- `hv_netvsc` -- Synthetic network adapter
- `hv_utils` -- Heartbeat, time sync, KVP, OS shutdown

RHEL 7+, Ubuntu 16.04+, SUSE 12+ include them out of the box. For older distributions, install the LIS download package from Microsoft.
