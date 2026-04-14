# NetApp ONTAP Architecture

## Hardware Platforms

### FAS (Fabric-Attached Storage)
Hybrid arrays supporting HDDs, SSDs, and Flash Pool. Designed for capacity-efficient workloads. Supports all ONTAP protocols (NFS, SMB, iSCSI, FC, NVMe-oF, S3). Use cases: general-purpose, backup targets, archival, mixed-protocol.

### AFF A-Series (Performance Tier)
All-flash with TLC (3-bit) NVMe SSDs. Highest endurance and lowest latency. 2024 refresh: A70, A90, A1K (May), A20, A30, A50 (November). Use cases: Tier-1 databases, AI inference, VDI, high-throughput block.

### AFF C-Series (Capacity-Optimized All-Flash)
QLC (4-bit) NVMe SSDs for lowest $/GB in all-flash lineup. Up to 1.5 PB in two racks. Use cases: file servers, backup-to-disk, media streaming, analytics. Replaces hybrid HDD arrays.

### ASA (All-SAN Array)
SAN-only ONTAP with symmetric active/active multipathing (ANA for NVMe, ALUA for SCSI). All paths are optimized — no preferred/non-preferred distinction. Same hardware as AFF. Use cases: enterprise databases, VMware VMFS, Oracle RAC.

## WAFL (Write Anywhere File Layout)

**Write-anywhere semantics**: Every write creates new data blocks at new locations. No in-place overwrites. Eliminates fragmentation and enables instant Snapshots.

**Consistency points (CPs)**: WAFL accumulates writes in NVRAM (battery/flash-backed) and flushes to disk in batches every ~10 seconds or when NVRAM reaches ~50% full. Ensures crash consistency without journal replay.

**NVRAM**: All writes committed to NVRAM on both HA pair nodes before client acknowledgment. On controller failure, surviving node replays partner's NVRAM journal — zero data loss.

**Snapshot mechanism**: Because data is never overwritten, Snapshots are preserved block pointers. Zero space at creation; only delta blocks consume additional space.

**WAFL Reserve**: 5% on AFF aggregates > 30 TB (from 9.12.1), extended to all FAS platforms (from 9.14.1).

## Storage Hierarchy

```
Physical Disks
    +-- RAID Groups (RAID-DP or RAID-TEC)
            +-- Local Tier (Aggregate)
                    +-- FlexVol / FlexGroup Volumes
                            +-- Qtrees, LUNs, NVMe Namespaces
                            +-- NFS exports, SMB shares, S3 buckets
```

### Aggregates (Local Tiers)
Physical storage containers — collections of RAID groups. Node-local. FabricPool attaches a cloud tier. Best practice: do not mix disk types or speeds within an aggregate. Maximum size varies by platform.

### FlexVol Volumes
Primary storage container for clients. Flexible: grow/shrink online, independent Snapshot schedules, QoS, efficiency, tiering policies. Space guarantee: `volume` (thick) or `none` (thin).

### FlexGroup Volumes
Scale-out volume distributing data across multiple constituents on multiple aggregates/nodes. Supports billions of files, petabyte scale. Ideal for AI/ML, media, home directories. Minimum: 8 constituents across 2+ aggregates.

### LUNs and NVMe Namespaces
LUNs: block objects within volumes, presented via FC/iSCSI/FCoE. Mapped to hosts via igroups (WWPNs or IQNs). NVMe namespaces: NVMe-oF equivalent, mapped to NVMe subsystems (host NQNs). Supports NVMe/FC and NVMe/TCP.

### Qtrees
Partitions within FlexVol for quota tracking and security style boundaries. Independent user/group/tree quotas. Max 4994 per volume.

## RAID Levels

**RAID-DP** (Double Parity): Two parity disks per RAID group. Tolerates two simultaneous disk failures. Default for AFF (SSD) and most FAS. Recommended group size: 12–20 HDDs, 20–28 SSDs.

**RAID-TEC** (Triple Erasure Coding): Three parity disks. Default for HDDs >= 6 TB. Recommended group size: 20–28 HDDs. Can convert from RAID-DP non-disruptively.

## Cluster Architecture

**HA Pairs**: 2–24 nodes, organized as HA pairs. HA interconnect for heartbeat and NVRAM mirroring. Storage failover (SFO): automatic takeover on failure, manual or automatic giveback.

**Cluster Interconnect**: Dedicated 10/100 GbE network. Cisco Nexus or Broadcom BES-53248 switches (3+ nodes). 2-node clusters support switchless direct-connect.

**SVMs**: Logical storage tenants with independent namespace, LIFs, protocols, security, RBAC, and SnapMirror. Node-independent — LIFs migrate across nodes for NDO.

**LIFs**: Data LIF (client traffic), Cluster LIF (internal), Management LIF (admin), Intercluster LIF (replication), FC LIF (pinned to physical port).

## Multi-Protocol Support

**NAS**: NFS v3/v4.0/v4.1/pNFS, SMB 2.1/3.0/3.1.1 (multichannel, encryption, CA shares), S3 (multiprotocol from 9.12.1+).

**SAN**: FC (8/16/32 Gb), iSCSI (CHAP, MPIO, iSCSI boot), FCoE (DCB/lossless Ethernet), NVMe/FC, NVMe/TCP (9.10.1+, standard Ethernet, no special hardware).

## Data Protection Architecture

### Snapshots
Near-instantaneous, read-only images. Up to 1023 per volume. Accessible via `.snapshot` (NFS) or `~snapshot` (SMB). SnapRestore: seconds regardless of volume size.

### SnapMirror
**Async**: Scheduled replication, read-only destination, incremental block-level transfers.
**Synchronous**: Zero-RPO, strict sync or sync with async fallback.
**Active Sync** (formerly SMBC): Transparent SAN failover. Symmetric active/active from 9.15.1+. External Mediator required. ONTAP Cloud Mediator from 9.17.1.

### SnapVault
Disk-to-disk backup via SnapMirror vault/mirror-vault policy. Longer retention on destination. Immutable with SnapLock Compliance.

### MetroCluster
Zero-RPO synchronous mirroring between two sites. Configurations: Stretch (SAS, <100m), Fabric (FC, 7km), IP (Ethernet, 700km). SyncMirror + NVRAM mirroring. AUSO < 120 seconds RTO.

## FabricPool Tiering

Local tier (SSD aggregate) + cloud tier (S3 object store). Policies per volume: `none`, `snapshot-only` (2-day default cooling), `auto` (31-day default), `all`. Cloud tiers: AWS S3, Azure Blob, GCP, StorageGRID, ONTAP S3. No license for StorageGRID/ONTAP S3 targets.

## Trident CSI

NetApp's official Kubernetes CSI driver. Deployed via Helm or Operator. Communicates with ONTAP via REST API.

| Driver | Protocol | Storage Object | Use Case |
|---|---|---|---|
| `ontap-nas` | NFS | FlexVol | General file storage, RWX |
| `ontap-nas-economy` | NFS | Qtree in shared FlexVol | High PV count |
| `ontap-nas-flexgroup` | NFS | FlexGroup | AI/ML, large datasets |
| `ontap-san` | iSCSI | LUN in FlexVol | Block storage, databases |
| `ontap-san-economy` | iSCSI | LUN in shared FlexVol | High LUN count |

Key capabilities: dynamic provisioning, FlexClone-backed PVC cloning, CSI Volume Snapshots, topology support, SVM-scoped least-privilege credentials.

## StorageGRID Integration

Enterprise S3-compatible object storage. FabricPool cloud tier target (no additional license). Erasure coding across sites. S3 Object Lock for WORM. ILM policies for object lifecycle. Use `read-after-new-write` consistency for FabricPool buckets.
