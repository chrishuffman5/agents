# NetApp ONTAP Best Practices

## Volume Design

### Provisioning Model
- **Thin provisioning is the default and preferred model** for most workloads on AFF. Thin provisioning allows aggregate overcommitment, enabling higher utilization of physical capacity.
- Use thick provisioning (`-space-guarantee volume`) for workloads with unpredictable write patterns that cannot tolerate out-of-space conditions at the volume layer (e.g., some Oracle configurations with strict space guarantees).
- Set fractional reserve to 0% for thin-provisioned volumes (`volume modify -fractional-reserve 0`). Fractional reserve at 100% doubles the space reservation for overwrites inside LUNs — unnecessary for thin workloads.
- Enable volume autogrow: `volume modify -autosize-mode grow -max-autosize <size>`. Prevents volumes from running out of space during sudden data growth events.

### Snapshot Reserve
- Default Snapshot reserve is 5% of volume size.
- For volumes with active Snapshot schedules and high churn, increase to 10–20%.
- For volumes that are SnapMirror destinations (read-only), set Snapshot reserve to 0 — no local Snapshots are needed on the destination.
- Monitor with `df -h` or `volume show -fields snapshot-reserve-percent,snapshot-reserve-available`.

### Volume Naming
- Use a consistent naming convention: `<environment>_<app>_<tier>_<number>` (e.g., `prod_oracle_data_01`).
- Avoid special characters; use underscores. Maximum name length is 203 characters.
- Group related volumes into the same SVM to simplify SnapMirror, QoS, and export policy management.

### Volume Security Style
- NFS workloads: use UNIX security style.
- SMB (Windows) workloads: use NTFS security style.
- Mixed environments: use mixed security style sparingly — it adds complexity to permission troubleshooting.
- Set at volume creation; changing security style after data exists can cause permission disruption.

### Deduplication and Compression
- Enable inline deduplication and compression on all AFF volumes by default — the dedicated offload processor (ODP) handles this with negligible latency impact.
- For FAS HDD volumes, use post-process deduplication scheduled during off-peak hours to avoid I/O contention.
- Compaction (packs multiple small writes into 4 KB storage blocks) is especially effective for database-generated data. Enable with `volume efficiency modify -data-compaction enabled`.
- Cross-volume deduplication: enabled by default on AFF; extends deduplication scope across all volumes in an aggregate for additional savings.
- Check savings: `volume efficiency show -vserver <svm> -volume <vol> -fields savings-percent,total-saved`.

### Volume Quotas
- Use qtrees to implement per-group or per-user disk quotas without separate volumes.
- Set soft and hard limits: `quota policy rule create -policy-name default -vserver <svm> -volume <vol> -type tree -target "/qtree1" -disk-limit 500G -soft-disk-limit 450G`.
- Monitor quotas: `quota report` or `quota show`.

---

## Aggregate (Local Tier) Layout

### Disk Homogeneity
- **Never mix disk types within an aggregate**: Do not mix HDDs and SSDs, or NL-SAS with SAS drives. Mixed disk types produce unpredictable performance.
- **AFF**: All-SSD aggregates by definition. Use identical SSD capacity within each RAID group for optimal RAID-DP/TEC stripe efficiency.
- **FAS Flash Pool**: Separately managed SSD cache pool on top of HDD aggregate. Size SSD cache at 10–15% of active working set for optimal hit ratio.

### RAID Group Sizing
- RAID-DP on SSD: 20–28 drives per RAID group (larger groups increase RAID efficiency but extend rebuild time).
- RAID-DP on HDD (SAS/SAS 10K): 12–20 drives per RAID group.
- RAID-TEC on large HDD (NL-SAS 6+ TB): 20–28 drives per RAID group.
- Larger RAID groups provide better space efficiency (fewer parity drives as a percentage) but increase rebuild window risk. Balance based on drive capacity and rebuild speed.

### Aggregate Sizing and Hot Spare Policy
- Maintain at least 2 hot spare drives per aggregate (same type and capacity as data drives).
- Do not fill an aggregate beyond 85–90% used capacity. WAFL performance degrades as free space diminishes — ONTAP requires free space to write new blocks.
- Use `storage aggregate show -fields percent-used,size,available` to monitor utilization.
- Set an AutoSupport-based alert at 80% usage to provide operational lead time.

### Aggregate Placement
- Spread volumes across aggregates when possible to distribute I/O load across spindles/SSDs.
- For FlexGroup: use aggregates on different nodes for maximum parallelism.
- Separate highly random I/O volumes (OLTP databases) from sequential I/O volumes (backups, archival) onto different aggregates to prevent I/O pattern interference.

---

## Data Protection Strategy

### Snapshot Schedule Design
- Implement a 3-2-1 snapshot strategy per volume: hourly (24), daily (7), weekly (4).
- Example schedule: `volume snapshot policy create -policy local-3-2-1 -schedule1 hourly -count1 24 -schedule2 daily -count2 7 -schedule3 weekly -count3 4`.
- Do not keep more Snapshots than needed — each Snapshot retains changed blocks, increasing space consumption on high-churn volumes.
- For database volumes, coordinate Snapshot schedules with application quiesce or use application-consistent tooling (SnapCenter).

### SnapMirror Topology
- **Fan-out**: One source replicates to two destinations (e.g., local DR + remote DR). Supported with async SnapMirror.
- **Cascade**: Source → Intermediate → Final destination. Use for multi-hop replication where direct connectivity is not feasible.
- **Mirror-Vault**: Combines SnapMirror mirroring with extended retention (vault) in a single relationship using the `mirror-vault` policy.
- Set appropriate SnapMirror network throttle to prevent replication from saturating production links: `snapmirror modify -throttle <kbps>`.
- Initialize SnapMirror relationships during maintenance windows or off-peak hours; initial baseline transfers can be large.

### SnapMirror Active Sync
- For SAN workloads requiring near-zero RTO and RPO=0, implement SnapMirror active sync.
- Requires a Mediator (on-premises Linux VM or ONTAP Cloud Mediator as of 9.17.1) on a third independent site/cloud.
- Create consistency groups to group related LUNs that must be snapped atomically: databases where data and log volumes must be consistent with each other.
- Test planned switchover regularly: `snapmirror failover start -destination-path <path>`.

### SnapLock for Immutable Backups
- Use SnapLock Compliance volumes for regulatory retention of backup Snapshots (SEC 17a-4, HIPAA, GDPR).
- SnapLock Enterprise: retention enforced, but volumes can be deleted by privileged user.
- SnapLock Compliance: strictest — volumes cannot be deleted even by ONTAP admin before retention expires.
- Tamperproof Snapshots (ONTAP 9.12.1+): a lightweight alternative to SnapLock — Snapshots can be locked for a defined period without requiring a full SnapLock volume.

### SnapCenter for Application-Consistent Backups
- NetApp SnapCenter is the central backup orchestration tool for application-consistent Snapshots.
- Supports: Oracle, SQL Server, SAP HANA, Exchange, VMware (VADP integration), MySQL, PostgreSQL.
- SnapCenter quiesces the application, triggers ONTAP Snapshots across all relevant volumes atomically, then resumes the application.
- Restores can be performed in seconds regardless of dataset size (WAFL-based instant restore).

---

## Performance Tuning

### Quality of Service (QoS)
- Apply QoS policies to workloads competing for shared storage resources to prevent noisy-neighbor issues.
- **Throughput ceiling (max QoS)**: limits a workload's maximum IOPS or MB/s. Used to protect other workloads from being starved.
  - `qos policy-group create -policy-group <name> -vserver <svm> -max-throughput 10000iops`
  - Apply to volume: `volume modify -vserver <svm> -volume <vol> -qos-policy-group <name>`
- **Throughput floor (min QoS / QoS floors)**: guarantees minimum performance for high-priority workloads. Requires ONTAP 9.2+.
  - `qos policy-group create -policy-group <name> -vserver <svm> -min-throughput 5000iops`
- **Adaptive QoS**: automatically scales IOPS ceiling/floor relative to volume size (per TB/GB). Ideal for environments with variable volume sizes.
  - Parameters: `expected-iops` (minimum per GB allocated), `peak-iops` (maximum per GB used or allocated), `block-size`.
  - Example: `qos adaptive-policy-group create -policy-group adaptive-gold -vserver <svm> -expected-iops 5000iops/TB -peak-iops 10000iops/TB -peak-iops-allocation used-space`
- Group multiple volumes into a shared QoS policy group when aggregate throughput control is needed across related volumes.

### Latency Optimization
- For latency-sensitive workloads (OLTP databases), place volumes on AFF A-Series (TLC NVMe SSDs) with NVMe/TCP or NVMe/FC as the host protocol.
- Avoid placing Snapshot schedules on high-churn OLTP volumes during peak hours — Snapshot creation can cause brief latency spikes on heavily fragmented WAFL filesystems.
- Enable jumbo frames (MTU 9000) on NFS and iSCSI data networks. Ensure consistent MTU across the entire path (switches, host NICs, ONTAP LIFs).
- For NFS v3/v4.1: tune `nfs.tcp.recvwindowsize` and send window on the client for high-bandwidth workloads.
- Use SMB multichannel for Windows workloads to saturate multiple NICs.

### Storage Efficiency Impact on Performance
- AFF ODP (offload processor): offloads inline deduplication and compression from main CPU. No measurable latency impact on all-flash systems.
- FAS HDD: post-process deduplication/compression is I/O intensive — schedule during low-utilization windows.
- Compression block size default is 8 KB. For databases writing in 8 KB blocks (Oracle, SQL), compression ratio may be low — consider disabling compression for database data files and enabling on log/archive volumes instead.
- Compaction is most effective for mixed-size records and log files — typically does not benefit database data files with fixed block sizes.

### Network Performance
- Use dedicated storage VLANs with no other traffic type.
- iSCSI/NVMe-TCP: use a dedicated VLAN per host-storage path; no routing required in same broadcast domain.
- NFS for VMware: use dedicated NFS VMkernel port groups with static IP binding.
- Enable Flow Control (pause frames, IEEE 802.3x) on iSCSI and NVMe/TCP networks to prevent buffer overflows.
- For high-throughput NFS: use pNFS (NFSv4.1 parallel access) with FlexGroup volumes to stripe reads/writes across all nodes.

---

## Trident for Kubernetes

### Deployment
- Install via Helm chart or Trident Operator (recommended): `helm install trident netapp-trident/trident-operator --namespace trident --create-namespace`.
- Pin Trident to a specific version matching your ONTAP version support matrix.
- Deploy Trident in a dedicated `trident` namespace with appropriate RBAC.

### Backend Configuration Best Practices
- **Use SVM-scoped credentials** (vsadmin or a custom role with minimum privileges) rather than cluster admin credentials. Limits blast radius if credentials are compromised.
- **Custom ONTAP role for Trident** (minimum permissions):
  ```
  security login role create -role trident-role -cmddirname DEFAULT -access none
  security login role create -role trident-role -cmddirname "volume" -access all
  security login role create -role trident-role -cmddirname "lun" -access all
  security login role create -role trident-role -cmddirname "snapshot" -access all
  security login role create -role trident-role -cmddirname "export-policy" -access all
  ```
- Specify `managementLIF` (SVM management IP) and `dataLIF` (NFS or iSCSI data IP) separately in the backend config.
- Set `autoExportPolicy: true` in the backend to allow Trident to manage NFS export policies dynamically based on Kubernetes node IPs.
- Use `limitAggregateUsage` to prevent Trident from provisioning into aggregates above a specified utilization threshold (e.g., 80%).

### StorageClass Design
- Create StorageClasses for each tier: performance (AFF A-Series, NVMe/FC), standard (AFF C-Series, NFS), bulk (FAS with tiering).
- Use annotations in StorageClass to set Snapshot policies, QoS policy groups, and tiering policies.
- Example StorageClass parameters for gold tier NAS:
  ```yaml
  parameters:
    backendType: "ontap-nas"
    storagePool: "aggr_ssd_a90"
    snapshotPolicy: "default"
    snapshotReserve: "10"
    tieringPolicy: "none"
    qosPolicy: "gold-qos"
  ```

### Volume Snapshots and Clones
- Enable the CSI external-snapshotter (part of Kubernetes sig-storage) to support `VolumeSnapshot` objects.
- Trident maps `VolumeSnapshot` to ONTAP Snapshot (instant, no performance impact).
- `VolumeSnapshotContent` for pre-existing Snapshots can be imported for static binding.
- Cloning from a Snapshot uses ONTAP FlexClone — the clone is instantaneous and space-efficient (shares blocks with parent until written).

### SAN (iSCSI / NVMe-TCP) Trident Considerations
- For iSCSI backends: `find_multipaths: no` is required in the host's `/etc/multipath.conf` (`DM-Multipath`). Using `yes` causes mount failures.
- Trident strictly enforces multipath for SAN; single-path SAN PVCs are not supported.
- Use node labels to control which Kubernetes nodes can access specific SAN backends (CSI Topology).

---

## FlexGroup Design

### When to Use FlexGroup vs FlexVol
| Criterion | FlexVol | FlexGroup |
|-----------|---------|-----------|
| Dataset size | Up to ~100 TB | Petabyte scale |
| File count | Up to ~2 billion | Billions+ |
| Metadata throughput | Single namespace server | Distributed across nodes |
| Feature parity | Full ONTAP feature set | Most features; some limitations |
| Simplicity | Simpler | More complex to troubleshoot |

Use FlexGroup for: AI/ML training datasets, media asset repositories, genomics data, software build systems, large home directory trees.

### FlexGroup Creation Best Practices
- Spread constituents across all nodes in the cluster for maximum parallelism.
- Use identical aggregates (same disk type, same RAID group size, same drive count): `volume create -vserver <svm> -volume <fg_vol> -size 100TB -type RW -aggr-list aggr0_node1,aggr0_node2,aggr1_node1,aggr1_node2 -aggr-list-multiplier 4`.
- The `-aggr-list-multiplier` creates multiple constituents per aggregate — use 4–8 constituents per aggregate for better load distribution.
- Minimum: 8 constituents; recommended: 16–32 for large deployments.
- Reserve ~3% of free space per aggregate for constituent metadata.

### FlexGroup Replication
- SnapMirror for FlexGroup (async) is supported but has constraints: the destination FlexGroup must have the same constituent count and layout as the source.
- Not all SnapMirror policies apply to FlexGroup — use `MirrorAllSnapshots` or `MirrorLatest` policies.
- FlexGroup does not support synchronous SnapMirror.

---

## FlexClone

### What FlexClone Provides
FlexClone creates an instant, space-efficient copy of a volume (or LUN) by sharing the parent's data blocks. Only delta blocks written after clone creation consume new space.

- Clone creation time: typically < 1 second regardless of parent size.
- Initial space consumption: metadata only (~2% overhead for the clone pointer map).
- Use cases: dev/test environments, CI/CD pipelines, database test refreshes, VM template deployment.

### FlexClone Best Practices
- Split the clone from the parent (`volume clone split start`) when the clone is expected to diverge significantly or when the parent volume needs to be deleted. Splitting is non-disruptive but temporarily increases storage consumption as blocks are de-shared.
- For database refresh workflows: Snapshot the production volume → clone the Snapshot → mount the clone to the dev/test database server. Refresh = delete clone → re-clone from new Snapshot.
- Trident automates FlexClone for Kubernetes `VolumeSnapshot`-based PVC cloning.
- FlexClone is included in ONTAP One; no separate license required.

---

## Tiering Best Practices (FabricPool)

### Aggregate Preparation
- Use all-SSD aggregates as the FabricPool local tier for maximum performance on active data.
- Attach the object store before volumes are fully in production: `storage aggregate object-store attach -aggregate <aggr> -object-store-name <store>`.
- Verify connectivity: `storage aggregate object-store show-space` and `storage aggregate object-store check`.

### Policy Selection
| Workload Type | Recommended Policy | Reasoning |
|--------------|-------------------|-----------|
| Active production database | `none` | No tiering; all data hot |
| General file server | `auto` (31-day cooling) | Inactive files naturally tier |
| Backup/vault volume | `all` | All data is cold; tier immediately |
| VMware datastore (mixed) | `snapshot-only` | Keep VMDK active; tier old Snapshots |
| Archive/compliance | `all` | Data is cold by definition |

### Cooling Period Tuning
- Default `tiering-minimum-cooling-days` for `auto`: 31 days. Increase to 60–90 for workloads with monthly or quarterly access patterns.
- Decrease for rapidly aging data (e.g., log files after 7 days): `volume modify -tiering-minimum-cooling-days 7`.
- Monitor tiered vs. local data: `volume show-footprint` and `storage aggregate object-store show-space`.

### Retrieval Optimization
- For workloads that routinely re-read tiered data (e.g., seasonal reporting), consider setting tiering policy to `none` before the access window to prevent repeated retrieval overhead.
- Use `volume object-store tiering unreclaimed-space-threshold` to control when tiered blocks are reclaimed.

### StorageGRID as Cloud Tier
- Use `read-after-new-write` consistency for the FabricPool bucket on StorageGRID (default; do not change).
- Ensure StorageGRID grid nodes have sufficient network bandwidth to the ONTAP cluster for tiering throughput.
- StorageGRID ILM policies should not expire objects in the FabricPool bucket — only ONTAP manages object lifecycle.
- Use a dedicated S3 bucket per aggregate; do not share FabricPool buckets across aggregates.
