# VMware vSphere Architecture Reference

Comprehensive architecture reference for VMware vSphere. Covers ESXi hypervisor internals, virtual machine architecture, vMotion, HA/FT/DRS, networking, storage, and vSAN.

---

## ESXi Hypervisor Architecture

### VMkernel

The VMkernel is the core operating system of ESXi. It provides CPU scheduling, memory management, device drivers, and virtual machine execution. ESXi is a Type-1 bare-metal hypervisor -- the VMkernel runs in direct contact with hardware without a host operating system.

**CPU Scheduler:**
- NUMA-aware proportional fair-share scheduler
- Each VM's vCPUs are scheduled on physical CPU cores
- Ready time (%RDY) measures how long a vCPU waited in the run queue -- key contention indicator
- Co-stop (%CSTP) occurs when SMP VMs must synchronize vCPUs -- over-allocation amplifies this
- CPU affinity and NUMA home node placement optimize memory locality

**Memory Manager:**
- Transparent Page Sharing (TPS): deduplicates identical memory pages across VMs (intra-VM only by default since vSphere 6.0 for security)
- Balloon driver (vmmemctl): reclaims memory from guest OS via VMware Tools. Guest OS pages to its own swap, freeing physical pages for host reuse
- Memory swap (.vswp file): host-level swap file per VM. High latency -- indicates severe memory pressure
- Memory compression: compresses pages before swapping to .vswp. Reduces swap I/O
- Large pages (2 MB): used by default for VM memory. Improves TLB efficiency. Shattered under memory pressure

**Pluggable Storage Architecture (PSA):**
- Modular storage I/O stack with three components:
  - Native Multipathing Plugin (NMP): manages path selection and failover
  - Storage Array Type Plugin (SATP): handles array-specific behavior (active-active, active-passive, ALUA)
  - Path Selection Plugin (PSP): chooses which path to use (Fixed, MRU, Round Robin)
- Third-party Multipathing Plugins (MPP) can replace NMP entirely (e.g., Dell PowerPath/VE, Pure FlashArray plugin)

**Network I/O Control (NetIOC):**
- Bandwidth reservation and shares per traffic type on vDS
- Traffic classes: Management, vMotion, vSAN, FT, Virtual Machines, NFS, iSCSI, Replication
- Prevents any single traffic type from starving others during congestion

### Userworld Processes

Userworlds run in a restricted environment on top of the VMkernel:

| Process | Function | Restart Command |
|---|---|---|
| `hostd` | Local VM management, VI API, authentication | `/etc/init.d/hostd restart` |
| `vpxa` | vCenter agent, relays management commands | `/etc/init.d/vpxa restart` |
| `fdm` | HA Fault Domain Manager, heartbeating | Automatic via HA |
| `sfcbd` | CIM broker for hardware health (WBEM) | `/etc/init.d/sfcbd-watchdog restart` |
| `ntpd` | Time synchronization | `/etc/init.d/ntpd restart` |
| `vobd` | vSphere Observability daemon | Automatic |

Restart all management agents: `/sbin/services.sh restart`

### DCUI and Shell Access

**DCUI (Direct Console User Interface):** Text-based console on the local physical monitor. Used for initial network configuration, root password reset, and enabling/disabling SSH and ESXi Shell.

**ESXi Shell:** BusyBox-based environment with VMware-specific tools. Disabled by default in production. Set auto-disable timeout.

**SSH:** Disabled by default. Enable only for troubleshooting; set timeout to auto-disable.

### Lockdown Mode

| Mode | DCUI Access | Direct API Access | Use Case |
|---|---|---|---|
| Normal | Preserved | Requires vCenter | Standard production |
| Strict | Disabled | Requires vCenter | High-security environments |
| Disabled | Full | Full | Lab/troubleshooting only |

Exception Users: break-glass accounts that retain direct access even in lockdown mode.

---

## Virtual Machine Architecture

### VMX Configuration File

Each VM has a `.vmx` file (plain text) storing hardware configuration:
```
numvcpus = "4"
memsize = "8192"
scsi0:0.fileName = "vm-disk1.vmdk"
ethernet0.networkName = "VM Network"
virtualHW.version = "20"
guestOS = "windows2022srv-64"
```

### VMDK Virtual Disks

VMDKs consist of two files:
- **Descriptor** (`.vmdk`): small text file with geometry, parent chain, and provisioning metadata
- **Flat file** (`-flat.vmdk`): binary data containing actual disk contents

Provisioning types:
- **Thin**: grows on demand. Best for general use. Monitor datastore free space.
- **Thick Lazy Zeroed**: full space allocated, zeroed on first write. Default for some operations.
- **Thick Eager Zeroed**: allocated and pre-zeroed at creation. Required for FT. Best I/O performance.

### Snapshots

Snapshots capture point-in-time VM state by creating delta VMDK files. Every write after snapshot goes to the delta file. Performance impact:
- Each read may traverse the delta chain to find the latest version of a block
- Deep chains (3+ snapshots) cause significant I/O amplification
- Consolidation (merging deltas back) is I/O intensive and should be done during low-activity periods

Snapshot files:
- `vmname-000001.vmdk` / `vmname-000001-delta.vmdk`: delta disk
- `vmname-Snapshot1.vmsn`: memory snapshot (if selected)
- `vmname.vmsd`: snapshot metadata/tree

### VM Hardware Versions

| vSphere Version | Hardware Version | Key Capabilities |
|---|---|---|
| vSphere 6.7 | 14 | USB 3.0, NVDIMM |
| vSphere 7.0 | 19 | Precision clock, vTPM |
| vSphere 8.0 | 20 | 4 NVMe controllers, PTP clock, USB 3.2 |
| vSphere 8.0 U2 | 21 | Improved NUMA topology, enhanced encryption |
| vSphere 9.0 | 21+ | Confidential VM support |

VMs are backward-compatible but not forward-compatible. Upgrade requires VM power cycle (not just reboot). Always upgrade VMware Tools before hardware version.

### VMware Tools / open-vm-tools

Functions:
- Paravirtualized drivers: PVSCSI (SCSI controller), VMXNET3 (network adapter)
- Guest OS heartbeat for VM Monitoring
- Quiescing for application-consistent snapshots (VSS on Windows, fsfreeze on Linux)
- Time synchronization with ESXi host
- Guest customization support (hostname, IP, domain join)

`open-vm-tools`: open-source implementation, pre-installed in most Linux distributions. Preferred for Linux guests.

---

## vMotion and Storage vMotion

### vMotion Process

1. Pre-migration checks: CPU compatibility, network labels, shared storage visibility
2. Memory pre-copy: iteratively copy memory pages to destination (multiple rounds, copying dirty pages each round)
3. Stun phase: pause VM, copy remaining dirty pages (typically <1 second)
4. Activate on destination: VM resumes on target host
5. Source cleanup: release resources on original host

**Network requirements:** Dedicated vMotion VMkernel port. 10 GbE minimum, 25 GbE recommended. Multiple vMotion NICs for parallelism (up to 4 active).

### Enhanced vMotion Compatibility (EVC)

EVC masks advanced CPU features at the cluster level, presenting a common CPU feature set to all VMs. This allows vMotion between hosts with different CPU generations within the same vendor.

EVC baselines correspond to CPU microarchitectures:
- Intel: Sandy Bridge, Ivy Bridge, Haswell, Broadwell, Skylake, Cascade Lake, Ice Lake, Sapphire Rapids
- AMD: Barcelona, Istanbul, Abu Dhabi, Seoul, Naples, Rome, Milan, Genoa

EVC is set at the cluster level. Cannot be lowered while VMs are running. Can be raised (more features exposed) at any time.

### Cross-vCenter vMotion

Migrates VMs between different vCenter Server instances. Requirements:
- Enterprise Plus licensing
- Network connectivity between vCenter instances
- Matching port group names or NSX overlay
- vSphere 6.0+ (enhanced in 7.0 and 8.0)

### Storage vMotion

Migrates VM disk files between datastores while running. Uses the VMware Mirror Driver to track dirty blocks. Can be combined with vMotion for simultaneous host + storage migration. No shared storage requirement for Storage vMotion itself.

---

## High Availability (HA)

### vSphere HA

HA provides automated VM restart on surviving hosts after host failure.

**Heartbeating:**
- Network heartbeats: every 1 second between hosts
- Host failure declaration: 12 seconds of missed heartbeats (configurable)
- Datastore heartbeating: secondary check via VMFS on-disk lock. Distinguishes network partition from host failure

**Host Roles:**
- Primary host: elected by FDM. Monitors secondaries, initiates VM restarts. Up to 5 primaries per cluster.
- Secondary hosts: report status to primary, execute restart instructions.

**Admission Control Policies:**
- **Percentage-based** (recommended): reserves X% of cluster CPU and memory for failover
- **Dedicated failover hosts**: specific hosts reserved exclusively for failover
- **Slot-based** (legacy): calculates slot size from largest VM reservation; counts available slots

**VM Restart Priority:** Highest > High > Medium > Low > Disabled. VMs restart in priority order. Dependent VM groups can define restart ordering (e.g., start DB before app server).

**VM Monitoring:** Uses VMware Tools heartbeat to detect guest OS or application failure. Restarts unresponsive VMs on the same host.

### vSphere Fault Tolerance (FT)

FT provides zero-downtime protection by maintaining a live shadow VM in lockstep on a separate host. If the primary host fails, the secondary VM takes over instantly with no data loss.

Requirements:
- FT Logging VMkernel port (10 GbE minimum, dedicated NIC recommended)
- Thick eager zeroed disks
- Up to 8 vCPUs (SMP-FT, vSphere 7+)
- Shared storage
- No snapshots, linked clones, or Storage vMotion for FT VMs

### DRS (Distributed Resource Scheduler)

DRS continuously monitors CPU and memory utilization across cluster hosts and uses vMotion to rebalance workloads.

**Modes:**
- Fully Automated: applies migrations automatically
- Partially Automated: auto-places VMs at power-on; recommends ongoing migrations
- Manual: only provides recommendations

**Migration Threshold:** 1 (conservative, fewest migrations) to 5 (aggressive, most balanced). Level 3 recommended for most environments.

**DRS Rules:**
| Rule Type | Effect |
|---|---|
| VM-VM Affinity | Keep VMs together on same host |
| VM-VM Anti-Affinity | Separate VMs across hosts |
| VM-Host Affinity (must) | VM must run on specified host group |
| VM-Host Affinity (should) | VM prefers specified host group |
| VM-Host Anti-Affinity | VM must/should NOT run on specified host group |

**DRS Groups:** Organize VMs and hosts into named groups. Rules reference groups, not individual VMs/hosts.

**Predictive DRS:** Uses vRealize/Aria Operations forecasting to preemptively migrate VMs before predicted contention.

---

## Networking

### vSphere Standard Switch (vSS)

Per-host Layer 2 virtual switch. Not synchronized across hosts. Uplinks connect to physical NICs (vmnic). Port groups define network segments.

NIC teaming policies:
- Route based on originating port ID (default)
- Route based on source MAC hash
- Route based on IP hash (requires EtherChannel/LACP on physical switch)
- Explicit failover order

### vSphere Distributed Switch (vDS)

Cluster-level virtual switch managed through vCenter. Configuration pushed to all member hosts simultaneously.

Advanced features:
- **NetIOC**: bandwidth reservation and shares per traffic type
- **LACP**: 802.3ad link aggregation (not available on vSS)
- **Port mirroring**: RSPAN, ERSPAN for traffic monitoring
- **Network health check**: detects MTU and VLAN mismatches
- **Per-port policies**: override default policies on individual ports
- **Rollback/recovery**: prevents lockout from misconfiguration

### VMkernel Ports

| Traffic Type | Best Practice |
|---|---|
| Management | Dedicated VLAN, redundant NICs |
| vMotion | Dedicated VLAN, 10+ GbE, up to 4 active NICs |
| vSAN | Dedicated VLAN, 10+ GbE, separate from vMotion |
| FT Logging | Dedicated VLAN, 10 GbE minimum |
| NFS/iSCSI | Dedicated VLAN, jumbo frames (MTU 9000) |
| vSphere Replication | Separate from production traffic |

### VLAN Tagging Modes

- **VST (Virtual Switch Tagging)**: port group tags frames with VLAN ID. VMs are VLAN-unaware. Most common.
- **EST (External Switch Tagging)**: physical switch tags frames. Port group VLAN = 0.
- **VGT (Virtual Guest Tagging)**: VLAN trunk to guest (port group VLAN = 4095). Guest handles VLAN tagging.

### NSX Integration

NSX provides overlay networking (GENEVE encapsulation), distributed firewall (DFW), micro-segmentation, and L4-L7 services. NSX integrates with vDS. NSX-T/NSX4+ replaced NSX-V (legacy). NSX Manager provides centralized policy management.

---

## Storage

### VMFS 6

VMware cluster filesystem for block storage. Features:
- 64-bit addressing, volumes up to 64 TB
- Automatic Space Reclamation (UNMAP) for thin-provisioned arrays
- Atomic test-and-set (ATS) locking (replaces legacy SCSI reservations)
- Sub-block allocation for small files (1 KB granularity)
- Multiple hosts read/write simultaneously using distributed locking

### NFS Datastores

- NFS v3: UDP or TCP, simple setup, no Kerberos
- NFS v4.1: TCP only, session trunking for multipathing, Kerberos authentication
- Dedicated 10+ GbE NIC on separate NFS VLAN
- Jumbo frames recommended for NFS traffic

### iSCSI

- Software initiator built into VMkernel
- Port binding: map multiple VMkernel ports to one iSCSI adapter for multipathing
- Jumbo frames (MTU 9000) recommended
- CHAP authentication supported

### Fibre Channel

- FC HBAs connect to FC fabric switches
- FCoE (Fibre Channel over Ethernet) supported
- Multipathing via PSA with Round Robin or Fixed PSP
- Lowest latency storage protocol

### Storage Policy-Based Management (SPBM)

SPBM decouples storage requirements from physical storage. Define VM storage policies specifying capabilities (tier, RAID, encryption, replication). Apply per VMDK. Used with vSAN, vVols, and compatible arrays. Compliance checking validates VMs meet their policy.

### Storage DRS (SDRS)

Balances I/O load and space across datastores in a Datastore Cluster. Uses Storage vMotion to migrate VMDKs. Thresholds: space utilization (default 80%), I/O latency (default 15 ms).

### vVols (Virtual Volumes)

Maps individual VM objects directly to array objects. VASA provider communicates capabilities from array to vCenter. SPBM policies enforced natively by the array. Per-VM snapshots, replication, and encryption without VMFS overhead.

---

## vSAN

### Hyper-Converged Architecture

vSAN pools local storage from ESXi hosts into a shared distributed datastore. Minimum 3 hosts. Dedicated VMkernel port on 10 GbE+ network. Fully managed through vCenter.

### Original Storage Architecture (OSA)

Each host contributes disk groups:
- 1 cache device (NVMe/SSD): read cache + write buffer
- 1-7 capacity devices (HDD/SSD): persistent storage
- Cache device failure = disk group failure

All writes flow through cache tier before destaging to capacity.

### Express Storage Architecture (ESA, vSAN 8+)

- Single flat pool -- no disk groups, no cache/capacity distinction
- All NVMe drives contribute equally
- Always-on compression and deduplication
- ~4x IOPS improvement over OSA
- Improved snapshot performance (no traditional delta chains)
- All-NVMe storage required; separate ESA HCL

### Storage Policies

| Policy | Values | Effect |
|---|---|---|
| FTT | 0, 1, 2, 3 | Failures to Tolerate (hosts for RAID-1, drives for RAID-5/6) |
| RAID Method | RAID-1, RAID-5, RAID-6 | Mirror vs erasure coding |
| Stripe Width | 1-12 | Capacity devices per stripe |
| Object Space Reservation | 0-100% | Thick provisioning percentage |
| Force Provisioning | Yes/No | Provision even if policy cannot be satisfied (dangerous) |

### Stretched Clusters

vSAN stretched cluster spans two sites with a witness at a third site. FTT=1 with RAID-1 mirrors data synchronously between sites. Requirements:
- <5 ms RTT between data sites
- <200 ms RTT to witness
- Witness appliance (VM or physical) at third site
- Symmetrical storage capacity at both data sites

### vSAN Health

Monitor via Cluster > Monitor > vSAN > Health in vSphere Client. Key checks:
- Network health: multicast connectivity, MTU consistency
- Data health: object health, rebuild status
- Physical disk health: disk failures, endurance
- Cluster health: host status, time sync
- Performance: IOPS, latency, throughput

---

## Backup and Data Protection

### VADP (vStorage APIs for Data Protection)

VMware's backup API framework. Backup applications use VADP for agentless image-level backups.

**Changed Block Tracking (CBT):**
- Tracks which VMDK blocks changed since last backup
- Enables fast incremental backups
- Enable per VM: `ctkEnabled = "TRUE"` in VMX
- Reset after Storage vMotion or snapshot consolidation

**Transport Modes:**
| Mode | Path | Performance | Use Case |
|---|---|---|---|
| Hot-Add | Proxy VM mounts VMDK via SCSI | High | Default for large VMDKs |
| NBD/NBDSSL | Network (TCP) | Moderate | When hot-add unavailable |
| SAN | Direct FC/iSCSI from LUN | Highest | FC environments |

**Quiescing:** Invokes VSS (Windows) or fsfreeze (Linux) for application-consistent snapshots. Requires VMware Tools.

### Snapshot Management for Backups

1. Backup tool creates VM snapshot via VADP
2. Backup tool reads base VMDK + CBT for changed blocks
3. Backup tool deletes snapshot after backup completes
4. VMkernel consolidates delta VMDK back into base

Monitor for orphaned snapshots. Consolidation warnings appear in vCenter if automated merge fails.
