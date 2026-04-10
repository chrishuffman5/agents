# Dell Unity XT Architecture

## Overview

Dell Unity XT is a midrange unified storage platform that supports block (SAN), file (NAS), and VMware vVols from a single system and a single storage pool. Introduced in 2019 as the successor to the original Unity family, Unity XT added faster Intel Skylake processors, increased memory, and NVMe-ready internals while retaining the same unified architecture and Unisphere management interface.

Unity XT positions in Dell's portfolio between the entry-level PowerVault and the high-end PowerMax/PowerScale families. As of 2025, the AFA (all-flash) models have reached end-of-sale, with hybrid models continuing to ship. PowerStore is Dell's strategic replacement.

---

## Hardware Models

| Model | Drive Slots (max) | Target Workload |
|-------|------------------|-----------------|
| Unity XT 380 / 380F | Up to 500 drives | SMB / ROBO |
| Unity XT 480 / 480F | Up to 500 drives | Midrange general purpose |
| Unity XT 680 / 680F | Up to 1,000 drives | Performance-intensive |
| Unity XT 880 / 880F | Up to 1,500 drives | Large enterprise |

- **F suffix** = All-Flash Array (AFA); non-F = Hybrid (SSD + SAS HDD tiers)
- All models use Intel Xeon Skylake-class processors per SP
- 480/F, 680/F, and 880/F models contain two M.2 SSD devices per SP: one SATA (system boot), one NVMe (internal cache/metadata)
- 380/F is a 2U chassis; larger models use a 2U Disk Processor Enclosure (DPE) with additional Drive Array Enclosures (DAEs)

---

## Dual Storage Processor (SP) Controllers

Unity XT uses an **active-active dual SP architecture**. Both SPs process I/O simultaneously, providing both high availability and increased aggregate throughput.

### SP Design
- Each SP is an independent compute node with dedicated CPU, RAM, and network adapters
- SPs are connected via a high-speed internal midplane
- Front-end ports (iSCSI, FC, FCoE, 10/25 GbE for NAS) are distributed symmetrically across both SPs
- Back-end ports connect SPs to DAE drive shelves via 12Gb SAS

### Ownership and Failover
- Each LUN, file system, and NAS server has an **owning SP** (home SP) and a **secondary SP** (failover target)
- On SP failure, the surviving SP takes over all resources automatically within seconds
- Resources return to their home SP when it recovers (automatic trespass back)
- Unity uses ALUA (Asymmetric Logical Unit Access) for block: paths through the owning SP are optimized, secondary paths are non-optimized but usable

### System Cache
- Each SP has its own write cache (NVRAM-backed for write-back safety)
- System cache is separate from FAST Cache; it operates transparently below the host layer
- In the event of SP failure, cached dirty data is destaged using the peer SP and the internal NVMe M.2 device

---

## Storage Pools

A **storage pool** is the fundamental capacity container in Unity XT. All storage objects (LUNs, file systems, VMware VMFS/NFS datastores, vVols) are provisioned from pools.

### Pool Types

**Dynamic Pools (Mapped RAID)**
- Default and recommended pool type for Unity XT
- RAID protection is applied at the extent level across all drives in the pool rather than to fixed drive groups
- No dedicated hot spare drives required; spare capacity is distributed automatically (approximately 1 drive equivalent per 32 drives)
- Supports RAID 5, RAID 6, and RAID 1/0
- Maximum RAID widths: RAID 5 up to 12+1, RAID 6 up to 14+2, RAID 1/0 up to 4+4
- Drives can be added one at a time or in groups; the pool rebalances automatically

**Traditional Pools**
- Drive groups with fixed RAID sets (similar to legacy EMC VNX behavior)
- Dedicated hot spares required
- Still supported for compatibility but dynamic pools are preferred for new deployments

### Key Pool Characteristics
- A single pool can contain multiple drive tiers (Extreme Performance Flash, Performance Flash, Capacity HDD)
- All pool storage objects share a common capacity reserve
- Thin provisioning is the default and recommended allocation method
- Pools track subscribed capacity (total provisioned) separately from consumed capacity (actually written)
- Inline data reduction (compression + deduplication) is applied at the pool level on AFA configurations

---

## FAST VP (Fully Automated Storage Tiering for Virtual Pools)

FAST VP is the automated tiering engine that moves data within a pool to the most appropriate drive tier based on I/O activity.

### Tier Structure (Hybrid Pools)
| Tier | Drive Type | Purpose |
|------|-----------|---------|
| Extreme Performance | SAS Flash SSD | Hottest data |
| Performance | NL-SAS or SAS HDD | Warm data |
| Capacity | NL-SAS HDD | Cold/archive data |

AFA pools have only one tier (Extreme Performance) so FAST VP tiering is not applicable, though data reduction and FAST Cache still operate.

### How FAST VP Works
1. The system monitors I/O patterns at 256 MB data chunk granularity
2. Every hour, FAST VP analyzes collected statistics and ranks data slices from hottest to coldest
3. During the configured relocation window, data chunks are physically moved between tiers
4. Movement is non-disruptive; I/O continues during relocation

### Tiering Policies (per storage object)
| Policy | Behavior |
|--------|---------|
| Start High then Auto-tier | Places new allocations on the highest tier; ages data down based on activity. **Default and recommended.** |
| Auto-tier | Places data on any tier immediately based on current activity |
| Highest Available Tier | Always keeps data on the highest tier; no downward movement |
| Lowest Available Tier | Always keeps data on the lowest tier; no upward movement |

### Relocation Schedule
- Default window: daily 22:00–06:00 UTC
- Can be changed to run continuously for always-active workloads
- Each pool can be configured to follow the system schedule or run independently
- Minimum 10% free pool capacity is required for relocation to operate efficiently
- Relocation windows should be multiples of 60 minutes to minimize incomplete cycle overhead

---

## FAST Cache

FAST Cache is a **secondary cache layer** using SAS flash drives that sits logically between the system RAM cache and the spinning disk drives (or slower flash tiers).

### Key Characteristics
- Not applicable for AFA pools (all data is already on flash)
- Primarily beneficial for hybrid pools with large spinning disk tiers
- Operates at 64 KB chunk granularity (compared to FAST VP's 256 MB)
- Caches reads and write-behind data for frequently accessed blocks
- Capacity is added in mirrored SSD pairs for redundancy
- Can be used concurrently with FAST VP for layered performance optimization

### FAST Cache vs. FAST VP Comparison
| Attribute | FAST Cache | FAST VP |
|-----------|-----------|---------|
| Granularity | 64 KB | 256 MB |
| Scope | Pool-level cache | Pool-level tier migration |
| Response time | Near-immediate | Hourly analysis + nightly window |
| Drive type required | SAS SSD (FAST Cache drives) | Any supported drive type per tier |
| Best for | Random hot I/O spikes | Long-term workload placement |

---

## Block Storage (SAN)

Unity XT supports block access via:
- **Fibre Channel (FC)**: 8 Gb, 16 Gb, 32 Gb
- **iSCSI**: 10 GbE, 25 GbE
- **FCoE**: 10 GbE

### Block Objects
- **LUNs**: Standard block volumes, thin provisioned by default
- **Consistency Groups (CGs)**: Groups of LUNs that are managed and replicated together, ensuring write-order consistency
- **VMware VMFS Datastores**: LUNs presented to ESXi via FC or iSCSI, managed through Unisphere with VMware awareness
- **vVols**: Per-VM storage objects managed via VASA provider; Unity acts as a vVol storage container

### Snapshot Architecture
- Space-efficient copy-on-write snapshots stored in the same pool
- Snapshots can be taken manually, on schedule, or via VMware integration
- Writable snapshot copies (thin clones) supported
- Snapshot retention policies can be configured per LUN or CG

---

## File Storage (NAS)

Unity XT provides enterprise NAS capabilities through a software-defined NAS server construct.

### NAS Server
- A NAS server is a logical entity that provides file services; each NAS server runs on one SP (home SP) and can fail over to the peer SP
- Up to 12 NAS servers per system (model-dependent)
- Each NAS server has:
  - One or more network interfaces (linked to SP Ethernet ports)
  - Active Directory and/or LDAP/NIS integration for identity
  - DNS configuration
  - Supported protocols: SMB (CIFS), NFSv3, NFSv4.0, NFSv4.1, FTP, SFTP

### File Systems
- Created within a NAS server and provisioned from a storage pool
- Support thin provisioning, quotas (user, tree, and filesystem-level), and access-based enumeration
- Multiprotocol file systems allow simultaneous SMB and NFS access to the same data

### High Availability
- NAS servers fail over to the peer SP automatically on SP failure
- Network interfaces must be configured symmetrically on both SPs for seamless failover
- Fail-Safe Networking (FSN) provides switch-level redundancy beyond port-level link aggregation
- NFSv3 clients reconnect transparently; NFSv4 clients reclaim locks within a grace period

---

## UnityVSA (Virtual Storage Appliance)

UnityVSA is a software-defined version of Unity that runs as a virtual machine on VMware ESXi. It delivers the same Unity OE and Unisphere management experience without dedicated hardware.

### Editions
| Edition | Capacity | Use Case |
|---------|---------|---------|
| Community Edition (CE) | Up to 4 TB | Lab / evaluation (free) |
| Professional Edition (PE) | Up to 50 TB (licensed) | ROBO, dev/test, DR target |

### Architecture
- Deployed as an OVA on VMware ESXi 6.5 or later
- Uses VMware VMDK files as backend storage (datastore-backed)
- Two virtual SPs (SPA and SPB) deploy as separate VMs for HA (Professional Edition)
- Supports same features as physical Unity XT: NFS, SMB, iSCSI, snapshots, FAST VP, replication
- Replication supported between UnityVSA instances and to/from physical Unity XT arrays

### Limitations vs. Physical Unity XT
- No FC front-end support
- No FAST Cache support
- No hardware RAID; relies on VMware datastore RAID
- Performance is bound by ESXi host resources

---

## Unisphere Management

Unisphere is the primary management interface for Unity XT and UnityVSA.

### Interface Characteristics
- HTML5-based web GUI (no Flash or Java required)
- Accessible via HTTPS on the management SP IP
- Single pane of glass for block, file, VMware, and system management
- Role-based access control (RBAC): Administrator, Storage Administrator, Operator, VM Administrator

### Key Management Capabilities
| Area | Capabilities |
|------|-------------|
| Storage | Create/modify pools, LUNs, file systems, NAS servers, CGs, vVols |
| Data Protection | Snapshots, replication sessions, NDMP backup |
| Performance | Real-time and historical charts for IOPS, latency, bandwidth, SP CPU/memory |
| Alerts | Configurable thresholds, email/SNMP notifications, health dashboard |
| System | Firmware upgrades, SP management, drive management, software licensing |
| VMware | vCenter integration, datastore management, vVol support |

### Unisphere CLI (UEMCLI)
- Command-line equivalent of the GUI; SSH-based
- Syntax: `uemcli -d <mgmt-IP> -u <user> -p <password> <object-path> <action>`
- Supports all management operations; required for some advanced configurations
- SSH must be explicitly enabled on the array (System > Service > Enable SSH)

### REST API
- RESTful API available for programmatic management and automation
- Same capabilities as UEMCLI; used by Unisphere GUI itself
- Useful for integration with orchestration tools (Ansible, Terraform, custom scripts)

### CloudIQ / APEX AIOps Integration
- SupportAssist must be enabled and a ProSupport/ProSupport Plus contract required
- Sends telemetry to Dell's cloud for predictive health monitoring, capacity projections, and reclaimable storage identification
- CloudIQ (now branded APEX AIOps Observability) available at no additional cost with qualifying support contracts
- Connection via direct outbound HTTPS from the array or via Secure Connect Gateway VM
