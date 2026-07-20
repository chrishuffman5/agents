# NetApp ONTAP Best Practices

## Volume Design

### Provisioning
- Thin provisioning is the default and preferred model for AFF. Set fractional reserve to 0% for thin volumes.
- Use thick provisioning (`-space-guarantee volume`) only for workloads that cannot tolerate out-of-space conditions.
- Enable volume autogrow: `volume modify -autosize-mode grow -max-autosize <size>`.

### Snapshot Reserve
- Default: 5%. Increase to 10-20% for high-churn volumes with active Snapshot schedules.
- Set to 0 on SnapMirror destinations (no local Snapshots needed).

### Naming and Security Style
- Convention: `<environment>_<app>_<tier>_<number>` (e.g., `prod_oracle_data_01`).
- NFS: UNIX security style. SMB: NTFS. Mixed: use sparingly.

### Deduplication and Compression
- Enable inline dedup and compression on all AFF volumes — dedicated ODP handles with negligible latency impact.
- FAS HDD: post-process dedup during off-peak hours. Compaction effective for database-generated data.
- Cross-volume dedup enabled by default on AFF for additional savings.

### Volume Quotas
- Use qtrees for per-group or per-user quotas without separate volumes.
- Set soft and hard limits: `quota policy rule create -type tree -target "/qtree1" -disk-limit 500G -soft-disk-limit 450G`.

## Aggregate (Local Tier) Layout

### Disk Homogeneity
- Never mix disk types within an aggregate. AFF: identical SSD capacity within RAID groups.
- FAS Flash Pool: SSD cache at 10-15% of active working set.

### RAID Group Sizing
- RAID-DP SSD: 20-28 drives. RAID-DP HDD: 12-20 drives. RAID-TEC large HDD: 20-28 drives.
- Larger groups = better space efficiency but longer rebuild window.

### Sizing and Spares
- Maintain 2+ hot spare drives per aggregate (same type/capacity as data drives).
- Do not exceed 85-90% used capacity. WAFL performance degrades as free space diminishes.
- Set AutoSupport alert at 80% usage.

### Placement
- Spread volumes across aggregates to distribute I/O. For FlexGroup: use aggregates on different nodes.
- Separate OLTP (random) from backup (sequential) onto different aggregates.

## Data Protection Strategy

### Snapshot Schedule Design
- 3-2-1 strategy: hourly (24), daily (7), weekly (4).
- Coordinate database volume Snapshots with application quiesce or use SnapCenter.

### SnapMirror Topology
- **Fan-out**: One source to two destinations (local DR + remote DR).
- **Cascade**: Source to intermediate to final destination.
- **Mirror-Vault**: Combines mirroring with extended retention in a single relationship.
- Set throttle to prevent replication from saturating production links.
- Initialize during maintenance windows.

### SnapMirror Active Sync
- For SAN workloads requiring near-zero RTO and RPO=0.
- Requires Mediator on a third independent site/cloud (Cloud Mediator from 9.17.1).
- Create consistency groups for related LUNs. Test planned switchover regularly.

### SnapLock for Immutable Backups
- SnapLock Compliance: strictest — cannot delete before retention expires, even by admin.
- SnapLock Enterprise: retention enforced but privileged user can delete.
- Tamperproof Snapshots (9.12.1+): lightweight alternative to full SnapLock volume.

### SnapCenter
- Central orchestration for application-consistent Snapshots (Oracle, SQL Server, SAP HANA, Exchange, VMware).
- Quiesces application, triggers ONTAP Snapshots atomically, resumes application. Restores in seconds.

## Performance Tuning

### QoS
- **Throughput ceiling** (max): `qos policy-group create -max-throughput 10000iops` — prevents noisy-neighbor.
- **Throughput floor** (min): `qos policy-group create -min-throughput 5000iops` — guarantees minimum.
- **Adaptive QoS**: scales IOPS per TB. Use `expected-iops` and `peak-iops` parameters.

### Latency Optimization
- AFF A-Series with NVMe/TCP or NVMe/FC for lowest latency.
- Enable jumbo frames (MTU 9000) on NFS and iSCSI data networks end-to-end.
- SMB multichannel for Windows workloads. pNFS with FlexGroup for parallel throughput.
- Compression block size 8 KB default; may yield low ratio for 8 KB database blocks — consider disabling on database data files.

### Network Performance
- Dedicated storage VLANs. Dedicated VLAN per iSCSI/NVMe-TCP host-storage path.
- Enable flow control (IEEE 802.3x) on iSCSI and NVMe/TCP networks.

## Trident for Kubernetes

### Deployment
- Install via Helm or Trident Operator. Pin version to ONTAP support matrix.
- Deploy in dedicated `trident` namespace with RBAC.

### Backend Configuration
- Use SVM-scoped credentials (not cluster admin). Create custom least-privilege ONTAP role.
- Specify `managementLIF` and `dataLIF` separately. Set `autoExportPolicy: true`.
- Use `limitAggregateUsage` (e.g., 80%) to prevent provisioning into full aggregates.

### StorageClass Design
- Create tiers: performance (AFF A-Series, NVMe/FC), standard (AFF C-Series, NFS), bulk (FAS with tiering).
- Set `snapshotPolicy`, `snapshotReserve`, `tieringPolicy`, `qosPolicy` in parameters.

### SAN Considerations
- `find_multipaths: no` required in host `/etc/multipath.conf`. Trident enforces multipath.
- Use node labels for CSI Topology to control backend access.

## FlexGroup Design

| Criterion | FlexVol | FlexGroup |
|---|---|---|
| Dataset size | Up to ~100 TB | Petabyte scale |
| File count | Up to ~2 billion | Billions+ |
| Feature parity | Full ONTAP | Most features, some limitations |

- Spread constituents across all nodes. Use identical aggregates. `-aggr-list-multiplier 4` for 4-8 constituents per aggregate.
- SnapMirror async supported (same constituent count/layout). No synchronous SnapMirror.

## FlexClone
- Instant, space-efficient copy (< 1 second regardless of size). ~2% metadata overhead.
- Database refresh: Snapshot production, clone Snapshot, mount to dev/test. Re-clone from new Snapshot to refresh.
- Split clone from parent (`volume clone split start`) when clone will diverge significantly.

## FabricPool Tiering Best Practices

| Workload | Policy | Reasoning |
|---|---|---|
| Active production DB | `none` | All data hot |
| General file server | `auto` (31-day cooling) | Inactive files tier naturally |
| Backup/vault volume | `all` | All data cold |
| VMware datastore | `snapshot-only` | Keep VMDK active, tier old Snapshots |

- Use all-SSD aggregates as local tier. Attach object store before volumes are fully in production.
- Do not use FabricPool on SnapLock Compliance aggregates.
- Dedicated S3 bucket per aggregate on StorageGRID. Use `read-after-new-write` consistency.
