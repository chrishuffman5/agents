# NetApp ONTAP Architecture

## Hardware Platforms

### FAS (Fabric-Attached Storage)
FAS systems are hybrid storage arrays that support a mix of HDDs, SSDs, and Flash Pool configurations. They run the ONTAP operating system and are designed for workloads where capacity efficiency matters more than peak latency. FAS arrays support all ONTAP protocols (NFS, SMB, iSCSI, FC, NVMe-oF, S3) and serve organizations that need cost-effective, high-capacity unified storage with data management capabilities.

- Use cases: general-purpose workloads, backup targets, archival, mixed-protocol environments
- Media: SAS HDDs, SATA HDDs, SSDs (Flash Pool hybrid caching), NL-SAS
- Shelf connectivity: SAS via mini-SAS HD cables, optional NVMe-attached shelves

### AFF A-Series (All Flash FAS - Performance Tier)
The AFF A-Series targets high-performance, latency-sensitive workloads including AI/ML training, databases, VDI, and high-frequency trading. It uses TLC (3-bit) NVMe SSDs which offer higher endurance and lower latency than QLC.

- 2024 model refresh: A400/A800/A900 replaced by A70, A90, A1K (May 2024); A150/A250 replaced by A20, A30, A50 (November 2024)
- Peak sequential read: ~30 GB/s on high-end models
- Use cases: Tier 1 databases (Oracle, SQL Server), AI inference, high-throughput block storage, VDI

### AFF C-Series (Capacity-Optimized All-Flash)
The C-Series uses QLC (4-bit) NVMe SSDs to deliver the lowest $/GB in the all-flash lineup. Designed to replace hybrid HDD arrays with all-flash economics, it targets read-heavy, capacity-dominated workloads.

- Up to 1.5 PB in a two-rack deployment, 95% floor space savings, 97% power savings vs HDD
- Peak sequential read: ~27 GB/s
- Use cases: file servers, backup-to-disk, object storage tiering, media streaming, analytics

### ASA (All-SAN Array)
The ASA product line is purpose-built for block storage (SAN) workloads. It runs ONTAP but exposes only SAN protocols and uses symmetric active/active multipathing (ANA for NVMe, ALUA for SCSI) rather than the asymmetric multipathing used on unified ONTAP systems. This eliminates the path preference overhead inherent in traditional ALUA configurations.

- Same hardware platforms as AFF (A20, A30, A50 as of late 2024)
- All paths are optimized paths — no preferred/non-preferred distinction
- Use cases: enterprise databases, VMware VMFS, Exchange, Oracle RAC

---

## WAFL (Write Anywhere File Layout)

WAFL is NetApp's proprietary filesystem that underpins all ONTAP storage. It sits between RAID and the volume layer, mediating all read and write I/O.

### Core Design Principles

**Write-anywhere semantics**: WAFL does not update data in place. Every write creates new data blocks at a new location on disk. This eliminates overwrite-induced fragmentation and enables instantaneous Snapshot copies.

**Consistency points (CPs)**: WAFL accumulates writes in NVRAM (battery-backed or flash-backed) and flushes them to disk in batches called consistency points, typically every 10 seconds or when NVRAM reaches ~50% full. CPs ensure crash consistency without fsck-like journal replay.

**NVRAM**: All writes are committed to NVRAM on both nodes of an HA pair before acknowledging to the client. On controller failure, the surviving node replays its partner's NVRAM journal, ensuring zero data loss.

**Snapshot mechanism**: Because data is never overwritten, Snapshots are simply pointers to existing blocks at a moment in time. A Snapshot consumes no space at creation — only blocks modified after the Snapshot consume additional space (copy-on-write semantics for the delta).

**WAFL Reserve**: ONTAP reserves a portion of aggregate space for WAFL internal metadata. From ONTAP 9.12.1, the reserve on AFF aggregates > 30 TB was reduced from 10% to 5%. From ONTAP 9.14.1, this same 5% reserve applies to all FAS platforms, delivering 5% more usable space.

---

## Storage Hierarchy

```
Physical Disks
    └── RAID Groups (RAID-DP or RAID-TEC)
            └── Local Tier (Aggregate)
                    └── FlexVol Volumes / FlexGroup Volumes
                            ├── Qtrees (optional namespace partitioning)
                            ├── LUNs (block storage)
                            ├── NFS exports / SMB shares
                            └── S3 buckets
```

### Aggregates (Local Tiers)
An aggregate is the physical storage container — a collection of RAID groups presented as a single pool. All volumes are created within an aggregate. Key characteristics:

- Aggregates are node-local; volumes within an aggregate serve data from that node (though SVMs span the cluster)
- FabricPool can attach a cloud tier to an aggregate, enabling automated data tiering
- Flash Pool aggregates combine SSD caching with HDD capacity within a single aggregate
- Best practice: do not mix disk types or speeds within an aggregate
- Maximum aggregate size varies by platform; large AFF aggregates can exceed 1 PB

### FlexVol Volumes
The primary storage container visible to clients. FlexVol volumes are flexible: they can be grown/shrunk online, have independent Snapshot schedules, QoS policies, efficiency settings, and tiering policies.

- Thin provisioning: volumes can be larger than current physical space if aggregate has room to grow
- Thick provisioning: space is reserved at volume creation, preventing out-of-space conditions from other volumes
- Space guarantee options: `volume` (thick), `none` (thin)
- Volume efficiency: deduplication, compression, and compaction operate at the volume level

### FlexGroup Volumes
A scale-out volume that distributes data across multiple member volumes (constituents) spread across multiple aggregates and nodes. ONTAP automatically load-balances traffic across constituents.

- Supports billions of files in a single namespace, petabyte-scale capacity
- Ideal for AI/ML datasets, media repositories, home directories, software repositories
- Minimum recommendation: 8 constituent volumes across at least 2 aggregates
- All aggregates should use identical hardware (same disk type, RAID group size, drive count)
- Not all ONTAP features work identically on FlexGroup as on FlexVol (e.g., some SnapMirror features)

### LUNs
A LUN (Logical Unit Number) is a block storage object within a volume, presented to SAN hosts via FC, iSCSI, or FCoE. LUNs exist inside FlexVol volumes and inherit the volume's efficiency and data protection capabilities.

- Mapped to hosts via igroups (initiator groups)
- igroups contain WWPNs (FC) or IQNs (iSCSI) of host initiator ports
- LUN types: vmware, linux, windows, aix, solaris, etc. — controls SCSI reservation behavior
- Thin vs thick: LUNs can be thin (space reserved = none on parent volume) or thick

### NVMe Namespaces
NVMe namespaces are the NVMe-oF equivalent of LUNs. They are provisioned within volumes and mapped to NVMe subsystems (equivalent of igroups for NVMe hosts).

- Subsystem contains the host NQN (NVMe Qualified Name)
- Namespace mapped to subsystem with a namespace ID (NSID)
- Supports NVMe/FC and NVMe/TCP transports

### Qtrees
Qtrees provide a partition within a FlexVol volume, similar to a subdirectory but with independent quota tracking, security style (UNIX, NTFS, mixed), and oplocks settings. They do not add a full namespace isolation layer like volumes.

- Primarily used for quota management and security style boundaries within a single volume
- Each qtree can have its own quota limits (user, group, tree quotas)
- Max 4994 qtrees per volume

---

## RAID Levels

### RAID-DP (Double Parity)
The default RAID level for most ONTAP configurations. RAID-DP adds a second "diagonal" parity disk to RAID-4, providing protection against any two simultaneous disk failures.

- Two dedicated parity disks per RAID group
- Recommended RAID group size: 12–20 HDDs, 20–28 SSDs
- Rebuild I/O impact is significant for large HDD groups — size RAID groups appropriately
- Default for AFF (SSD) and most FAS configurations

### RAID-TEC (Triple Erasure Coding)
RAID-TEC adds a third "anti-diagonal" parity disk to RAID-DP, protecting against three simultaneous disk failures. Introduced in ONTAP 9.0, it is the default for capacity HDDs >= 6 TB.

- Three dedicated parity disks per RAID group
- Recommended RAID group size: 20–28 HDDs
- Higher protection overhead (3 parity disks) justified by rebuild risk window on large SATA/NL-SAS drives
- Can be converted from RAID-DP to RAID-TEC non-disruptively

---

## Cluster Architecture

### Node and HA Pair
ONTAP clusters consist of 2 to 24 nodes (platform-dependent), organized as HA pairs. Each HA pair shares disk shelf access and uses an HA interconnect for heartbeat and NVRAM mirroring.

- HA interconnect: internal backplane (single-chassis) or dedicated HA interconnect cables (dual-chassis)
- Heartbeat via interconnect cards; mailbox disks provide persistent state
- Storage failover (SFO): when a node fails, its partner takes over all disk shelves, volumes, and LIFs automatically
- Giveback: manual or automatic return of resources after the failed node recovers

### Cluster Interconnect
Nodes communicate via a dedicated cluster interconnect network, typically 10 GbE or 100 GbE (Cluster High Speed [CHS] ports). Data never travels over the management network; all inter-node communication uses cluster ports.

- Dedicated switches (Cisco Nexus or Broadcom BES-53248) for clusters > 2 nodes
- Switchless cluster: 2-node clusters can use direct-connect cluster interconnect without switches

### SVMs (Storage Virtual Machines)
An SVM is the logical storage tenant within an ONTAP cluster. Each SVM has its own:

- Namespace: volumes, qtrees, LUNs, namespaces
- Network interfaces (LIFs): IP or FC LIFs for client connectivity
- Protocols: each SVM independently enables NFS, SMB, iSCSI, FC, NVMe, S3
- Security: separate RBAC, audit, LDAP, AD, and Kerberos configuration
- SnapMirror relationships: SVMs can be replicated at the SVM level (SVM DR)

SVMs are node-independent — their LIFs can migrate across nodes within the cluster. This provides nondisruptive operations (NDO) during node maintenance, failover, and load balancing.

### LIFs (Logical Interfaces)
LIFs are virtual network endpoints within an SVM. They have a home node/port and can failover to other nodes/ports (for IP LIFs).

- Data LIF: serves NFS, SMB, iSCSI, S3 client traffic
- Cluster LIF: internal cluster communication (never exposed to clients)
- Management LIF: administrative access
- Intercluster LIF: SnapMirror and SnapVault replication across clusters
- FC LIF: Fibre Channel target port (no failover — tied to physical FC port and zone)

---

## Multi-Protocol Support

ONTAP is a unified storage platform supporting all major client protocols simultaneously from the same hardware and software stack.

### NAS Protocols

**NFS (v3, v4.0, v4.1, pNFS)**
- NFSv3: most widely deployed, stateless, UDP and TCP
- NFSv4.1: session-based, supports pNFS (parallel NFS for striped access), Kerberos security
- pNFS: allows clients to read/write directly to storage nodes for parallel throughput (used with FlexGroup)

**SMB/CIFS (v2.1, v3.0, v3.1.1)**
- Kerberos and NTLM authentication via Active Directory integration
- SMB 3.x supports multichannel (multiple TCP streams), encryption, ODX offload
- Continuous availability (CA) shares for Hyper-V and SQL Server with Witness protocol

**S3 Object Protocol**
- Native S3 endpoint in an ONTAP SVM (introduced ONTAP 9.8 for basic, enhanced in subsequent releases)
- S3 multiprotocol (ONTAP 9.12.1+): access the same data via NFS/SMB and S3 simultaneously
- Supports bucket versioning, object lifecycle policies, multipart uploads
- FabricPool uses S3 to communicate with cloud and StorageGRID object tiers
- StorageGRID is NetApp's enterprise object storage system purpose-built as an S3-compatible tiering target

### SAN Protocols

**Fibre Channel (FC / FCP)**
- 8, 16, 32 Gb FC supported (platform dependent)
- Zoning enforced in the FC fabric; ONTAP creates target ports on FC adapters within the SVM
- FC LIFs are pinned to physical adapter ports

**iSCSI**
- Block storage over Ethernet — compatible with any IP network
- Supports CHAP authentication, iSCSI boot, multipathing via MPIO (Windows) or dm-multipath (Linux)
- Often used where FC infrastructure is not available

**FCoE (Fibre Channel over Ethernet)**
- FC encapsulated in Ethernet frames via CNAs (Converged Network Adapters)
- Requires DCB/lossless Ethernet switches (802.1Qbb PFC)
- Declining in new deployments in favor of iSCSI or NVMe/TCP

**NVMe/FC**
- NVMe command set over Fibre Channel fabric
- Dramatically reduces I/O queue depth limitations (64K queues, 64K commands/queue vs SCSI's 1 queue, 254 commands)
- 80%+ of the NVMe performance advantage comes from replacing SCSI on the front end

**NVMe/TCP (ONTAP 9.10.1+)**
- NVMe command set over standard TCP/IP Ethernet
- No special hardware required — runs on existing Ethernet infrastructure
- Enables NVMe economics without FC fabric investment
- Supported on Linux, VMware ESXi 7.0U3+, Windows Server 2022

---

## Data Protection Architecture

### Snapshots
ONTAP Snapshots are point-in-time, read-only images of a volume created almost instantaneously with no performance impact. Because WAFL never overwrites data, a Snapshot is simply a preserved set of block pointers.

- Creation time: near-instantaneous (microseconds)
- Space consumption: only blocks changed after the Snapshot consume additional space
- Up to 1023 Snapshots per volume
- Accessible via `.snapshot` directory (NFS) or `~snapshot` (SMB) within the volume
- SnapRestore restores from a Snapshot in seconds regardless of volume size

### SnapMirror
SnapMirror replicates volumes or SVMs between ONTAP systems (FAS, AFF, ONTAP Select, Cloud Volumes ONTAP) asynchronously, synchronously, or in active sync mode.

**Async SnapMirror**: Replicates on a schedule (e.g., hourly). The destination is a read-only mirror updated with incremental block-level transfers. Used for DR with RPO defined by replication frequency.

**SnapMirror Synchronous**: Synchronous replication with zero data loss (RPO=0). Two modes:
- Strict sync: I/O is never written until it is committed at both sites — client writes fail if the link goes down
- Sync: in-sync mode uses zero-RPO replication; falls back to async if link drops (write ordering preserved)

**SnapMirror Active Sync (formerly SMBC)**: Introduced as SnapMirror Business Continuity. Provides transparent, host-transparent failover for SAN workloads. Both sites actively serve I/O with symmetric active/active behavior (ONTAP 9.15.1+). Uses an external Mediator to avoid split-brain; ONTAP Cloud Mediator introduced in 9.17.1 as a cloud-hosted Mediator option.

### SnapVault (SnapMirror Vault)
SnapVault is a disk-to-disk backup using SnapMirror's block-level replication engine. The destination retains many more Snapshots (backup copies) than the source, following a longer retention schedule. In ONTAP 9.3+, SnapVault is implemented as a SnapMirror relationship with a `vault` or `mirror-vault` policy.

- Source: production volume with short Snapshot retention (e.g., 7 daily)
- Destination: vault volume retaining 30 daily, 12 monthly, 7 yearly copies
- Immutable Snapshots (SnapLock Compliance) prevent deletion by ransomware or malicious actors

### MetroCluster
MetroCluster is a hardware + software solution providing zero-RPO synchronous mirroring between two geographically separated sites, with automatic switchover on site failure.

**Configurations:**
- Stretch MetroCluster: direct SAS cable connectivity, short distances (< 100m)
- Fabric MetroCluster (FC): FC fabric between sites, up to 7 km
- MetroCluster IP: Ethernet-based back-end, up to 700 km between sites (with appropriate WAN links)

**Architecture:**
- 2 or 4 nodes per site (2-node or 4-node MetroCluster)
- SyncMirror maintains a mirrored copy of every aggregate using a plex on each site
- NVRAM is mirrored over the back-end MetroCluster fabric
- Mediator (third site for IP) prevents split-brain scenarios
- Automatic unplanned switchover (AUSO): < 120 seconds RTO
- RPO = 0 under normal operations; any committed write is at both sites

---

## FabricPool Tiering

FabricPool automatically moves cold (inactive) data from the high-performance local tier (aggregate) to a lower-cost object storage cloud tier, while keeping hot data on flash.

### Architecture
- A FabricPool consists of a local tier (SSD aggregate) + attached cloud tier (object store)
- Object store attachment is one-to-one with an aggregate
- Cloud tiers: AWS S3, Azure Blob, GCP, StorageGRID (on-prem S3), ONTAP S3 (on-prem)
- No additional license required when using StorageGRID or ONTAP S3 as the cloud tier

### Tiering Policies (per volume)
| Policy | Behavior |
|--------|----------|
| `none` | No data tiered (default for new volumes) |
| `snapshot-only` | Tier blocks in Snapshot copies not in the active file system. Cooling period: 2 days default |
| `auto` | Tier cold blocks in active file system AND Snapshots. Cooling period: 31 days default |
| `all` | Tier all data immediately regardless of access pattern |

### Retrieval Behavior
- Random reads from the cloud tier: data is fetched and promoted back to the local tier (on-demand recall)
- Sequential reads (antivirus scans, index scans): data is read from cloud tier but not promoted, keeping the local tier clean
- `tiering-minimum-cooling-days`: configurable cooling period (2–183 days for `auto`/`snapshot-only`)

### Best Practices
- Use all-SSD aggregates as the local tier for optimal performance
- Use `auto` policy for general workloads, `snapshot-only` for backup/DR volumes
- Monitor tiering with `volume show-footprint` and `storage aggregate object-store show`
- Do not use FabricPool on aggregates containing SnapLock Compliance volumes
- FabricPool is supported in MetroCluster configurations

---

## Trident CSI (Container Storage Interface)

NetApp Trident is the official CSI driver for Kubernetes and OpenShift, providing dynamic persistent volume provisioning from ONTAP backends.

### Architecture
- Deployed as a Kubernetes DaemonSet + Deployment via Helm or Trident Operator
- Communicates with ONTAP via REST API (preferred) or ONTAP CLI/ZAPI (legacy)
- Backend: defines the ONTAP connection (cluster or SVM admin credentials, data LIF)
- StorageClass: maps to a Trident backend with driver and parameters
- PVC → PV → Trident dynamically provisions FlexVol, FlexGroup, or LUN

### ONTAP Backend Drivers
| Driver | Protocol | Storage Object | Use Case |
|--------|----------|----------------|----------|
| `ontap-nas` | NFS | FlexVol | General file storage, RWX |
| `ontap-nas-economy` | NFS | Qtree in shared FlexVol | High PV count (thousands) |
| `ontap-nas-flexgroup` | NFS | FlexGroup | AI/ML, large datasets, billions of files |
| `ontap-san` | iSCSI | LUN in FlexVol | Block storage, databases |
| `ontap-san-economy` | iSCSI | LUN in shared FlexVol | High LUN count |

### Key Capabilities
- Dynamic provisioning with Snapshot-based clone support (instant FlexClone)
- CSI Volume Snapshots: maps to ONTAP Snapshots or FlexClone
- Storage Class parameters control: media type, IOPS, export policy, Snapshot policy, tiering policy
- SVM-scoped or cluster-scoped admin credentials (principle of least privilege recommended)
- CSI Topology support: place PVs on specific nodes/aggregates using topology keys

---

## StorageGRID Integration

NetApp StorageGRID is an enterprise S3-compatible object storage system used as a FabricPool cloud tier target, a primary object store, or a backup repository.

- Deployed on commodity servers or NetApp appliances as a distributed object storage grid
- Provides erasure coding across sites for geographic data protection
- S3-compatible API: fully compatible with FabricPool attachment, Trident S3 backends, and direct application access
- Immutable object storage via S3 Object Lock (WORM compliance)
- ILM (Information Lifecycle Management) policies manage object replication, erasure coding, and retention across grid nodes
- FabricPool to StorageGRID: no additional NetApp tiering license required; preferred on-premises cloud tier
- StorageGRID read-after-new-write consistency: recommended consistency for FabricPool bucket configurations
