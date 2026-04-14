# Citrix Hypervisor / XenServer Architecture Reference

## Xen Hypervisor -- Type-1 Bare-Metal

Xen runs directly on hardware below all operating systems. It is intentionally minimal -- manages CPU scheduling and memory partitioning but delegates all I/O to the privileged dom0 domain.

### CPU Scheduling

The Credit2 scheduler (default since XenServer 7.1) is work-conserving and proportional-share. Each vCPU receives a weight and optional cap. Credit2 replaced Credit1 for better fairness under contention and NUMA awareness.

vCPU-to-pCPU pinning is possible via `xe vm-param-set VCPUs-params:mask` but rarely needed -- the scheduler handles placement automatically.

### Memory Management

Memory is statically allocated per VM at start. Dynamic Memory Control (DMC) uses balloon drivers in guests to allow the hypervisor to reclaim memory within defined min/max bounds, enabling soft over-commitment.

Memory hierarchy per VM:
- `memory-static-min` -- Absolute floor
- `memory-dynamic-min` -- Balloon target lower bound
- `memory-dynamic-max` -- Balloon target upper bound
- `memory-static-max` -- Maximum allocation at boot

DMC is transparent to guests with Citrix VM Tools installed.

---

## dom0 -- The Control Domain

dom0 is a privileged Linux VM (CentOS 7-based in XenServer 8.x) that boots automatically alongside the hypervisor. It has direct hardware access and is not a normal guest.

### Responsibilities

- Runs the xapi daemon and the full XAPI management stack
- Hosts all physical device drivers (NIC, HBA, disk controllers)
- Provides I/O backends for guest VMs via the split-driver model
- Exposes the HTTP/JSON-RPC API consumed by XenCenter and the xe CLI
- Runs RRDD (metrics daemon) for performance data collection

### dom0 Sizing

dom0 is a single point of failure per host. Default RAM allocation is 2-4 GB. For hosts running more than 20 VMs, increase to 4-8 GB. dom0 CPU allocation defaults to all pCPUs but runs at low priority relative to domU vCPUs.

Monitor dom0 with `top`, `free -m`, and `iostat` from within dom0 itself.

---

## domU -- Guest Virtual Machines

### Paravirtualization (PV)

The guest OS is aware it runs on Xen and uses Xen-optimized split drivers (frontend in guest, backend in dom0) for disk and network via shared-memory rings. Very low overhead; requires a PV-aware kernel. Pure PV mode is deprecated in favor of HVM with PV drivers.

### Hardware Virtual Machine (HVM)

Full hardware emulation via Intel VT-x or AMD-V extensions. Supports unmodified guest operating systems (Windows, legacy Linux). When combined with Citrix VM Tools (PV NIC and disk drivers), performance is near-native. All Windows VMs use HVM mode.

### PVH (Paravirtualized Hardware)

Hybrid mode introduced in XenServer 7.0. Uses hardware virtualization for privileged instructions, paravirtualization for I/O. Recommended for modern Linux guests -- provides the best combination of security and performance.

---

## XAPI Toolstack

XAPI is the management plane -- an OCaml-based daemon running in dom0 that exposes a stable XML-RPC and JSON-RPC API over HTTPS (port 443).

### Key Components

| Component | Role |
|-----------|------|
| xapi | Main API daemon; owns the pool database; handles all management requests |
| xenopsd | VM lifecycle daemon; talks to the Xen hypervisor for start/stop/migrate |
| xcp-networkd | Network configuration daemon; manages OVS bridges and bonds |
| SM (Storage Manager) | Plugin-based storage driver framework for SR operations |
| RRDD | Round-robin metrics daemon; collects host, VM, and SR performance data |

### Pool Database

The pool database is a distributed store replicated across all pool members and mastered by the pool master host. It contains all VM definitions, SR metadata, network configuration, and pool settings. Backup regularly with `xe pool-dump-database`.

### API Access

All management operations route through XAPI:
- **XenCenter** -- Windows GUI; connects via HTTPS to XAPI
- **xe CLI** -- Shell client that communicates with the local XAPI daemon (or remote with `-s`, `-u`, `-pw`)
- **Web console** -- Browser-based (newer releases)
- **Terraform** -- via the XenServer provider
- **OpenStack** -- via Nova compute driver

---

## Storage Architecture

### Storage Repositories (SRs) and VDIs

XenServer abstracts storage through Storage Repositories (SRs) containing Virtual Disk Images (VDIs). VDIs attach to VMs as Virtual Block Devices (VBDs).

### SR Types

| SR Type | Backend | Thin Provision | Shared | Best For |
|---------|---------|---------------|--------|----------|
| Local LVM | LVM on local disk | No (thick) | No | Single-host, high IOPS |
| ext | ext3/ext4 on local disk | Yes (VHD) | No | Local with snapshots/cloning |
| NFS | VHD files on NFS export | Yes | Yes | Mid-tier, simple operations |
| lvmoiscsi | LVM over iSCSI LUN | No | Yes | High-throughput block I/O |
| lvmohba | LVM over FC HBA | No | Yes | Lowest-latency block storage |
| GFS2 | Clustered FS over SAN | Yes | Yes | Active-active, vGPU migration |
| SMB | VHD files on SMB share | Yes | Yes | Windows file server integration |

### VHD Chains and Coalescing

NFS and ext SRs use VHD chaining for snapshots and clones. Each snapshot creates a parent-child relationship. Deep chains (more than 10 levels) degrade read performance because reads traverse the chain to find the correct block.

Coalescing merges parent-child VHDs to flatten chains. It runs as a background SM task triggered by `xe sr-scan`. Monitor coalescing via `xe task-list | grep -i coalesce` and SR logs at `/var/log/SMlog`.

### IntelliCache

IntelliCache uses local SSD storage on the host as a read cache for shared SRs. Reduces network I/O for read-heavy workloads (e.g., VDI boot storms). Configured per-host with a local caching SR.

---

## Networking Architecture

### Open vSwitch (OVS)

XenServer uses OVS as its default virtual switch (since version 6.0). OVS provides VLANs (802.1Q), bonding, QoS, and OpenFlow support for SDN integration.

### Network Objects

| Object | Description |
|--------|-------------|
| PIF | Physical Interface -- represents a physical NIC |
| VIF | Virtual Interface -- represents a guest VM NIC |
| Network | Logical switch connecting PIFs and VIFs |
| Bond | Aggregation of two or more PIFs |
| VLAN | 802.1Q tagged network layered on a PIF |

### Bond Modes

| Mode | Behavior | Requirement |
|------|----------|-------------|
| active-backup | Failover only; one NIC active | None |
| balance-slb | OVS source-MAC load balancing | None |
| LACP (802.3ad) | Negotiated bonding, highest throughput | Switch support |

### Network Separation

Best practice dedicates separate physical NICs or VLANs for each traffic class:
- **Management** -- XAPI traffic between hosts and XenCenter
- **Storage** -- NFS/iSCSI/SMB traffic; 10 GbE minimum; jumbo frames (MTU 9000) for iSCSI
- **VM traffic** -- Guest network; trunked VLANs for multi-tenant flexibility
- **Migration** -- XenMotion data transfer; dedicated 10 GbE prevents migration from saturating other networks

---

## High Availability

### Architecture

HA requires shared storage for a heartbeat disk. Hosts exchange UDP heartbeats over the network and write heartbeats to the shared SR. A host that loses both network and disk heartbeats self-fences (reboots) to prevent split-brain.

### Configuration

- Set `ha-restart-priority` per VM: `restart`, `best-effort`, or `do not restart`
- Set `ha-host-failures-to-tolerate` to define how many host failures the pool can absorb
- Reserve N+1 capacity -- HA cannot guarantee restarts if the pool lacks resources

### Pool Master Election

If the pool master fails with HA enabled, surviving hosts elect a new master automatically. Without HA, management operations halt until an administrator manually promotes a slave with `xe pool-emergency-transition-to-master`.

---

## XenMotion and Storage XenMotion

### XenMotion (Live Migration)

Migrates a running VM between pool hosts with near-zero downtime using memory pre-copy. Pages are iteratively copied while the VM runs, then a brief pause (typically under 1 second) completes the transfer.

Requirements: shared SR accessible by both hosts, same pool membership, compatible CPUs.

### Storage XenMotion

Migrates both the VM and its storage simultaneously. Copies disk data over the network, so it is slower than XenMotion. Enables moving VMs between pools or from local to shared storage without downtime.

### CPU Masking

When mixing CPU generations within the same vendor family, use CPU masking to hide advanced CPU flags from VMs. This ensures migration compatibility at the cost of not exposing newer CPU features. Never mix Intel and AMD hosts in the same pool.

### Migration Pre-Checks

- No ISO from a local SR is attached
- Destination host has enough free memory
- Target SR has sufficient free space
- CPU vendor matches (or masking is configured)

---

## Version History

| Release | Key Changes |
|---------|-------------|
| XenServer 6.x | Open vSwitch introduced; XenMotion GA |
| XenServer 7.0 | PVH guest support |
| XenServer 7.1 | Credit2 scheduler default; LTSR designation |
| XenServer 8.0 | CentOS 7-based dom0; improved secure boot |
| XenServer 8.2 | Changed Block Tracking (CBT) API for backup; LTSR |
| XenServer 8.3+ | Citrix Hypervisor rebranding; web console |

### XCP-ng

XCP-ng is the community open-source fork of XenServer. Functionally equivalent for most workloads, uses the same xe CLI and XAPI, and is compatible with Xen Orchestra (web-based management alternative to XenCenter). Citrix Hypervisor requires a commercial license for advanced features (IntelliCache, GPU passthrough, live patching, HA).
