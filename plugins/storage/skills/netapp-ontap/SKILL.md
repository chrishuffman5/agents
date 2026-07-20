---
name: netapp-ontap
description: "NetApp ONTAP unified storage across all supported versions (9.14-9.18): WAFL, aggregates, FlexVol/FlexGroup, SnapMirror, MetroCluster, FabricPool, Trident CSI, and ONTAP One licensing. Use for \"NetApp\", \"ONTAP\", \"FAS\", \"AFF\", \"ASA\", \"WAFL\", \"SnapMirror\", \"SnapVault\", \"FlexClone\", \"FlexGroup\", \"FabricPool\", \"Trident\", \"StorageGRID\", \"ONTAP aggregate\", \"ONTAP volume\", \"ONTAP snapshot\", \"MetroCluster\", \"ONTAP S3\", \"ONTAP One\", \"ARP/AI\"."
license: MIT
---

# NetApp ONTAP

This skill covers NetApp ONTAP unified storage across all supported versions (9.14 through 9.18). For version-specific detail, see the matching file under `references/versions/`. Core knowledge areas:

- WAFL filesystem internals, consistency points, NVRAM, and Snapshot mechanics
- Hardware platforms: FAS (hybrid), AFF A-Series (TLC NVMe performance), AFF C-Series (QLC capacity), ASA (SAN-only symmetric active/active)
- Storage hierarchy: aggregates (local tiers), FlexVol volumes, FlexGroup volumes, LUNs, NVMe namespaces, qtrees
- RAID levels: RAID-DP (double parity), RAID-TEC (triple erasure coding)
- Cluster architecture: HA pairs, SVMs, LIFs, cluster interconnect, storage failover
- Multi-protocol: NFS v3/v4.1/pNFS, SMB 2.x/3.x, iSCSI, FC, NVMe/FC, NVMe/TCP, S3
- Data protection: Snapshots, SnapMirror (async/sync/active sync), SnapVault, MetroCluster (FC/IP), SnapLock, SnapCenter
- FabricPool tiering: policies (none/snapshot-only/auto/all), cloud tier connectivity, StorageGRID
- Trident CSI: ontap-nas, ontap-san, ontap-nas-flexgroup drivers, StorageClass design, FlexClone-backed PVC cloning
- ONTAP One licensing: single NLF replacing all prior bundle licenses
- Autonomous Ransomware Protection with AI (ARP/AI)

When a question is version-specific, see the matching `references/versions/<v>.md` file. When the version is unknown, provide general guidance and note where behavior differs across versions.

For cross-platform storage questions (technology selection, SAN vs NAS, comparison with other vendors), see the `overview` skill.

## How to Approach Tasks

1. **Classify** the request:
   - **Troubleshooting** -- Load `references/diagnostics.md` for CLI commands, performance counters, latency analysis, disk failures, SnapMirror lag, and network issues
   - **Architecture / design** -- Load `references/architecture.md` for WAFL internals, storage hierarchy, cluster architecture, data protection, FabricPool, Trident CSI
   - **Best practices** -- Load `references/best-practices.md` for volume design, aggregate layout, data protection strategy, performance tuning, Trident configuration, FlexGroup design
   - **Version-specific features** -- See the matching `references/versions/<v>.md` file (9.14–9.18)

2. **Identify version** -- Determine which ONTAP version the user runs. Key version-gated features:
   - SnapMirror active sync symmetric active/active (9.15.1+)
   - FlexCache write-back (9.15.1+)
   - ARP/AI with no learning period (9.16.1+)
   - JIT privilege elevation, ONTAP Cloud Mediator (9.17.1+)
   - mTLS for cluster back-end, post-quantum crypto (9.18.1+)

3. **Load context** -- Read the relevant reference file for deep technical detail.

4. **Analyze** -- Apply ONTAP-specific reasoning. Consider platform type (FAS/AFF/ASA), aggregate configuration, protocol, and version.

5. **Recommend** -- Provide actionable guidance with CLI commands and configuration examples.

6. **Verify** -- Suggest validation steps using ONTAP CLI commands.

## Core Architecture

### How ONTAP Works

```
Physical Disks
    +-- RAID Groups (RAID-DP or RAID-TEC)
            +-- Local Tier (Aggregate)
                    +-- FlexVol / FlexGroup Volumes
                            +-- LUNs, NVMe Namespaces, NFS/SMB exports, S3 buckets
```

**WAFL (Write Anywhere File Layout)**: Never overwrites data in place. Writes go to new locations, enabling instant Snapshots (zero-cost block-pointer operations). Consistency points flush NVRAM to disk every ~10 seconds.

**SVMs (Storage Virtual Machines)**: Logical tenants within a cluster. Each SVM has its own namespace, LIFs, protocols, security, and SnapMirror relationships. SVMs are node-independent and provide NDO during maintenance.

**HA Pairs**: 2–24 nodes organized as HA pairs. NVRAM mirrored across pair. Storage failover (SFO) provides automatic takeover on node failure.

### Platform Selection

| Platform | Media | Use Case |
|---|---|---|
| AFF A-Series | TLC NVMe SSDs | Tier-1 databases, AI, VDI, low-latency block |
| AFF C-Series | QLC NVMe SSDs | File servers, backup-to-disk, capacity-optimized all-flash |
| FAS | HDDs + optional Flash Pool | General purpose, backup targets, archival |
| ASA | Same as AFF, SAN-only | Enterprise databases, VMware VMFS, symmetric active/active multipath |

### Data Protection Stack

| Method | RPO | RTO | Use Case |
|---|---|---|---|
| Snapshots | Seconds (schedule) | Seconds (SnapRestore) | Local point-in-time recovery |
| SnapMirror async | Minutes (schedule) | Minutes | Long-distance DR |
| SnapMirror sync | Zero | Seconds | Same-metro zero-loss |
| SnapMirror active sync | Zero | Zero (transparent) | Stretched SAN cluster |
| MetroCluster | Zero | < 120 seconds (AUSO) | Cross-site synchronous mirroring |
| SnapVault | Hours (schedule) | Minutes | Disk-to-disk backup with long retention |

### ONTAP One Licensing

All new AFF/FAS/ASA systems ship with ONTAP One — a single NLF enabling SnapMirror, FlexClone, SnapLock, encryption, FabricPool, QoS, all protocols, and ARP/AI. No per-feature license negotiation required.

## Key Operational Metrics

| Metric | Warning | Critical | Command |
|---|---|---|---|
| Volume utilization | 80% | 90% | `volume show -fields percent-used` |
| Aggregate utilization | 80% | 90% | `storage aggregate show -fields percent-used` |
| Node CPU busy | 70% | 85% | `statistics show -object system -counter cpu_busy` |
| SnapMirror lag | > 2x schedule | Unhealthy | `snapmirror show -fields lag-time` |
| Spare disk count | < 2 per node | 0 spares | `storage aggregate show-spare-disks` |

## Version-specific guidance

| Version | Reference | What's version-specific |
|---|---|---|
| ONTAP 9.14.1 | `references/versions/9.14.md` | WAFL reserve reduction for FAS, ONTAP Select KVM reinstatement, multi-admin verification enhancements |
| ONTAP 9.15.1 | `references/versions/9.15.md` | SnapMirror active sync symmetric active/active, FlexCache write-back, ONTAP Select cluster expansion |
| ONTAP 9.16.1 | `references/versions/9.16.md` | ARP/AI ransomware detection with no learning period, NVMe namespace space deallocation, IPsec hardware offload |
| ONTAP 9.17.1 | `references/versions/9.17.md` | JIT privilege elevation, Microsoft Entra as SAML IdP, ONTAP Cloud Mediator, ARP/AI for SAN volumes |
| ONTAP 9.18.1 | `references/versions/9.18.md` | mTLS for cluster back-end network, post-quantum algorithm support, expanded encryption scalability |

## Reference Files

- `references/architecture.md` -- WAFL internals, storage hierarchy, RAID, cluster architecture, multi-protocol, data protection, FabricPool, Trident CSI, StorageGRID
- `references/best-practices.md` -- Volume design, aggregate layout, data protection strategy, performance tuning, Trident for Kubernetes, FlexGroup, FlexClone, FabricPool tiering
- `references/diagnostics.md` -- Performance counters, latency analysis, disk failures, SnapMirror lag, network troubleshooting, key CLI command reference, investigation workflow

## Diagnostic Scripts

Ready-made SSH command bundles (readonly-role admin) in `scripts/`, numbered by investigation order. All read-only.

- `scripts/01-cluster-health.sh` -- Node state, failover readiness, aggregate capacity, health alerts
- `scripts/02-volume-capacity.sh` -- Volume fill levels, snapshot-reserve spill detection
- `scripts/03-network-lif-status.sh` -- LIF placement/home status, port health, failover coverage
- `scripts/04-performance-snapshot.sh` -- 30-second latency/IOPS sample per volume + QoS view
