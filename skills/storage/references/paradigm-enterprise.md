# Enterprise SAN/NAS Storage Patterns

## When to Choose Enterprise Storage

Enterprise storage arrays (NetApp ONTAP, Dell PowerStore, Dell Unity, Pure Storage FlashArray, HPE Alletra) are the right choice when:

- **Mission-critical workloads** require guaranteed performance, sub-millisecond latency, and vendor support SLAs
- **Data management features** are needed: snapshots, clones, replication, tiering, deduplication, encryption at rest
- **Multi-protocol access** is required: simultaneous block (FC/iSCSI) + file (NFS/SMB) from the same platform
- **Regulatory compliance** mandates certified hardware, audit trails, and vendor-backed data integrity
- **VMware/Hyper-V integration** needs native VAAI/VASA, Storage Policy-Based Management, or CSV support

## When to Avoid Enterprise Storage

- **Budget-constrained** environments where commodity hardware + SDS is viable
- **Cloud-first** strategy with no on-premises requirement
- **Object-only** workloads (backups, archives, data lakes) — use object storage instead
- **Massive scale-out** beyond a few PB — SDS or cloud is more cost-effective

## Technology Comparison

| Feature | NetApp ONTAP | Dell PowerStore | Dell Unity | Pure FlashArray | HPE Alletra |
|---|---|---|---|---|---|
| **Protocols** | FC, iSCSI, NVMe-oF, NFS, SMB, S3 | FC, iSCSI, NVMe-oF, NFS, SMB | FC, iSCSI, NFS, SMB | FC, iSCSI, NVMe-oF | FC, iSCSI, NVMe-oF, NFS, SMB |
| **Architecture** | Scale-out (HA pairs, clusters up to 24 nodes) | Scale-up (appliance pairs, federation) | Scale-up (dual controller) | Scale-up (dual controller, ActiveCluster) | Scale-up/out (depending on model) |
| **Data Reduction** | Inline dedup + compression + compaction | Inline dedup + compression | Inline/post-process | Always-on inline (cannot disable) | Adaptive (inline + post) |
| **Flash Type** | AFF (all-flash), FAS (hybrid), C-Series (capacity) | All-flash (NVMe) | All-flash or hybrid | All-flash only (NVMe) | All-flash (NVMe) |
| **Replication** | SnapMirror (async/sync), MetroCluster | Metro volume (sync), async replication | Sync/async replication | ActiveCluster (sync), async | Peer Persistence (sync), async |
| **Kubernetes** | Trident CSI driver | CSI driver (CSM) | No native CSI | Pure CSI driver | HPE CSI driver |
| **Cloud Integration** | Cloud Volumes ONTAP (AWS/Azure/GCP) | PowerStore with APEX | Limited | Pure Cloud Block Store, Pure Fusion | HPE GreenLake |
| **Licensing** | Complex (per-TB, bundles, ONTAP One) | Capacity-based | Capacity-based | Evergreen subscription | GreenLake consumption or CapEx |

## Common Patterns

### Data Protection Architecture

```
Production Array ──sync replication──> Metro DR Array (RPO=0, same city)
       │
       └──async replication──> Remote DR Array (RPO=minutes, different region)
       │
       └──snapshots──> Local recovery (logical corruption, accidental delete)
       │
       └──backup to object──> Long-term retention (S3, Azure Blob, tape)
```

### Tiered Storage Architecture

```
Tier 0: All-flash (Pure/PowerStore) ── Hot data, databases, VMs
   │ auto-tier
Tier 1: Hybrid/capacity flash ── Warm data, file shares
   │ policy-based
Tier 2: Object storage (S3/MinIO) ── Cold data, backups, archives
   │ lifecycle
Tier 3: Tape/deep archive ── Compliance, legal hold
```

## Anti-Patterns

1. **"Buy the biggest array and grow into it"** — Overprovisioning wastes capital. Right-size and scale. Modern arrays support non-disruptive expansion.
2. **"Disable data reduction to improve performance"** — On modern all-flash arrays, inline dedup+compression improves effective performance by reducing write amplification and increasing effective cache size.
3. **"Synchronous replication across continents"** — Sync replication requires < 5ms RTT. Cross-continent links have 50-150ms RTT. Use async with appropriate RPO instead.
4. **"No storage tiering"** — Paying all-flash prices for cold data is wasteful. Implement automatic tiering or lifecycle policies.
