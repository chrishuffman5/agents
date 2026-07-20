---
name: overview
description: "Cross-platform storage expertise for architecture selection, capacity planning, data protection design, and technology comparison across enterprise arrays, software-defined storage, and cloud object storage. Use when the question is cross-platform or strategic: \"storage\", \"SAN\", \"NAS\", \"object storage\", \"block storage\", \"file storage\", \"which storage platform\", \"RAID\", \"erasure coding\", \"deduplication\", \"snapshots\", \"replication\", \"tiering\", \"storage comparison\". Do NOT use for platform-specific operations (NetApp, Dell PowerStore/Unity, Pure Storage, HPE Alletra, Ceph, MinIO, GlusterFS, S3, Azure Blob, GCS, Storage Spaces Direct) — use that platform's own skill instead."
license: MIT
---

# Storage Overview

This skill covers cross-platform storage fundamentals: access types (block/file/object), data protection concepts, technology comparison, and platform-selection decision frameworks. For platform-specific operations and diagnostics, use that platform's own skill instead.

## When to Use This Skill vs. a Platform Skill

**Use this skill when the question is cross-platform or strategic:**
- "Which storage platform for our workload?"
- "SAN vs NAS vs object storage?"
- "Compare NetApp vs Pure Storage vs Dell"
- "Block vs file vs object — when to use which?"
- "On-prem vs cloud storage strategy?"
- "Storage architecture for Kubernetes"
- "Backup and disaster recovery strategy"
- "Storage tiering approach"

**Use the matching platform skill when the question is technology-specific:**
- "ONTAP volume management" --> the `netapp-ontap` skill
- "PowerStore performance tuning" --> the `dell-powerstore` skill
- "Unity pool configuration" --> the `dell-unity` skill
- "Pure Storage FlashArray replication" --> the `pure-storage` skill
- "HPE Alletra data reduction" --> the `hpe-alletra` skill
- "Ceph CRUSH map issue" --> the `ceph` skill
- "MinIO bucket policy" --> the `minio` skill
- "GlusterFS volume heal" --> the `glusterfs` skill
- "S3 lifecycle policy" --> the `aws-s3` skill
- "Azure Blob access tiers" --> the `azure-blob` skill
- "GCS signed URLs" --> the `gcs` skill
- "Storage Spaces Direct cluster" --> the `storage-spaces-direct` skill

## How to Approach Tasks

1. **Classify** the request:
   - **Technology selection** -- Use comparison tables below, load `references/paradigm-*.md`
   - **Architecture design** -- Load `references/concepts.md` for storage fundamentals
   - **Data protection** -- Load `references/concepts.md` for replication, snapshots, backup patterns
   - **Performance** -- Consider workload profile (IOPS, throughput, latency requirements)
   - **Technology-specific** -- Use the matching platform skill

2. **Gather context** -- Workload type (block/file/object), performance requirements, capacity, budget, existing infrastructure, cloud strategy, compliance

3. **Analyze** -- Apply storage engineering principles to the specific use case

4. **Recommend** -- Ranked recommendation with trade-offs, not a single answer

## Storage Fundamentals

### Storage Access Types

| Type | Protocol | Best For | Examples |
|---|---|---|---|
| **Block** | iSCSI, FC, NVMe-oF | Databases, VMs, low-latency apps | NetApp ONTAP, Dell PowerStore, Pure FlashArray |
| **File** | NFS, SMB/CIFS | Shared files, home dirs, media | NetApp ONTAP, Dell Unity, GlusterFS |
| **Object** | S3, Swift | Unstructured data, backups, archives, cloud-native | AWS S3, Azure Blob, MinIO, Ceph RGW |

### Data Protection Concepts

| Concept | What It Does | Trade-off |
|---|---|---|
| **RAID** | Disk-level redundancy (RAID 1/5/6/10, RAID-DP, RAID-TEC) | Capacity vs protection vs performance |
| **Erasure Coding** | Data + parity fragments across nodes | Space-efficient, higher CPU, higher latency than replication |
| **Replication** | Copies data to another system/site | Simple, doubles capacity, RPO depends on sync/async |
| **Snapshots** | Point-in-time copy (copy-on-write or redirect-on-write) | Fast, space-efficient, not a backup |
| **Deduplication** | Eliminate duplicate blocks/chunks | Saves space, CPU-intensive, memory-hungry |
| **Compression** | Reduce data size (inline or post-process) | Saves space, CPU cost, varies by data type |
| **Tiering** | Move data between performance tiers automatically | Cost optimization, complexity |

## Technology Comparison

| Technology | Type | Paradigm | Best For | Trade-offs |
|---|---|---|---|---|
| **NetApp ONTAP** | Block + File + Object | Enterprise | Unified storage, multi-protocol, data management | Expensive, complex licensing, vendor lock-in |
| **Dell PowerStore** | Block + File | Enterprise | Modern all-flash, VMware integration, AppsON | Newer platform, smaller ecosystem than NetApp |
| **Dell Unity** | Block + File | Enterprise | Midrange unified, simple management | EOL approaching, migrate to PowerStore |
| **Pure Storage FlashArray** | Block | Enterprise | All-flash simplicity, Evergreen subscriptions | Block-only (FlashBlade for file), premium pricing |
| **HPE Alletra** | Block + File | Enterprise | Cloud-native management, AI-driven ops | Product line consolidation ongoing |
| **Ceph** | Block + File + Object | SDS | Unified open-source, scale-out, commodity HW | Operational complexity, expertise required |
| **MinIO** | Object | SDS | S3-compatible, high-performance, Kubernetes-native | Object-only, commercial licensing since Feb 2026 |
| **GlusterFS** | File | SDS | Distributed file, scale-out NAS, Red Hat ecosystem | Declining community, metadata performance |
| **AWS S3** | Object | Cloud | Unlimited scale, 11 nines durability, ecosystem | Egress costs, vendor lock-in, eventual consistency for overwrites |
| **Azure Blob** | Object | Cloud | Microsoft ecosystem, access tiers, Data Lake Gen2 | Complex pricing, tier transition costs |
| **Google Cloud Storage** | Object | Cloud | Unified API, auto-class tiering, analytics integration | Smaller market share, fewer regions |
| **Storage Spaces Direct** | Block + File | Windows | Windows-native HCI, Hyper-V integration | Windows-only, hardware requirements, limited scale |

## Decision Framework

### Step 1: What type of storage access?

| Access Pattern | Strong Candidates | Avoid |
|---|---|---|
| Database / VM storage (block) | NetApp ONTAP, Pure FlashArray, Dell PowerStore, Ceph RBD | Object storage (S3, MinIO) |
| Shared file access (NFS/SMB) | NetApp ONTAP, Dell Unity, GlusterFS, Storage Spaces Direct | Object storage |
| Unstructured data / backups (object) | S3, Azure Blob, MinIO, Ceph RGW | Enterprise SAN (overkill) |
| Kubernetes persistent volumes | Ceph RBD, Pure Storage, NetApp Trident, cloud CSI drivers | Legacy SAN without CSI |
| Archive / cold data | S3 Glacier, Azure Archive, GCS Archive | All-flash arrays (waste) |

### Step 2: On-premises or cloud?

| Strategy | When | Technologies |
|---|---|---|
| **On-prem enterprise** | Regulated industries, data sovereignty, predictable workloads | NetApp, Dell, Pure, HPE |
| **On-prem SDS** | Cost-sensitive, commodity hardware, open-source preference | Ceph, MinIO, GlusterFS |
| **Cloud-native** | Variable workloads, global distribution, minimal ops | S3, Azure Blob, GCS |
| **Hybrid** | Burst to cloud, tiered storage, DR to cloud | NetApp Cloud Volumes, Pure Cloud Block Store + cloud |
| **HCI** | Converged compute + storage, small footprint | Storage Spaces Direct, vSAN |

### Step 3: Scale and performance?

- **< 100 TB, < 100K IOPS**: Any enterprise array handles this. Choose by features and ecosystem.
- **100 TB - 1 PB**: Enterprise arrays or Ceph. Consider tiering strategy.
- **> 1 PB**: Scale-out (Ceph, cloud object storage). Enterprise arrays can do it but cost is prohibitive.
- **Latency < 200µs**: All-flash enterprise (Pure, PowerStore, ONTAP AFF). Not SDS or cloud.

### Step 4: What does the team know?

| Team Background | Natural Fit |
|---|---|
| Windows / Hyper-V | Storage Spaces Direct, Dell, NetApp |
| VMware | Dell PowerStore, NetApp ONTAP, Pure |
| Linux / open-source | Ceph, MinIO, GlusterFS |
| AWS | S3, EBS, EFS, FSx |
| Azure | Azure Blob, Azure Files, Azure NetApp Files |
| Kubernetes | Ceph CSI, Pure CSI, cloud CSI drivers, MinIO |

## Technology Routing

| Request Pattern | Skill |
|---|---|
| NetApp, ONTAP, FAS, AFF, StorageGRID, SnapMirror, SnapVault, Trident | `netapp-ontap` |
| Dell PowerStore, PowerStore T/X, AppsON, metro cluster | `dell-powerstore` |
| Dell Unity, Unity XT, UnityVSA, pool, FAST VP | `dell-unity` |
| Pure Storage, FlashArray, Purity, ActiveCluster, Pure1, Evergreen | `pure-storage` |
| HPE, Alletra, Nimble, dHCI, InfoSight, StoreOnce | `hpe-alletra` |
| Ceph, RADOS, CRUSH, RBD, CephFS, RGW, BlueStore, OSD | `ceph` |
| MinIO, S3-compatible, erasure coding, mc client, KES | `minio` |
| GlusterFS, Gluster, brick, volume, geo-replication, heal | `glusterfs` |
| AWS S3, bucket, lifecycle, Glacier, S3 Express, storage class | `aws-s3` |
| Azure Blob, storage account, access tier, ADLS Gen2, container | `azure-blob` |
| GCS, Google Cloud Storage, gsutil, auto-class, signed URL | `gcs` |
| Storage Spaces Direct, S2D, HCI, ReFS, Hyper-V storage | `storage-spaces-direct` |

## Anti-Patterns

1. **"All-flash for archive data"** -- All-flash arrays are for hot data. Archival workloads belong on object storage or tiered platforms.
2. **"Object storage for databases"** -- Object storage has high latency and no random write support. Use block storage for databases.
3. **"No data protection testing"** -- Snapshots and replicas that are never tested for recovery are not protection. Test restores regularly.
4. **"SDS without expertise"** -- Ceph and GlusterFS require deep operational knowledge. Complexity cost exceeds hardware savings without skilled staff.
5. **"Cloud storage without egress budgeting"** -- Egress costs from S3/Azure Blob/GCS can dwarf storage costs. Model data movement patterns before committing.
6. **"Single vendor for everything"** -- Different workloads may need different storage. A best-of-breed approach often outperforms a single-vendor strategy.

## Reference Files

Load these for deep foundational knowledge:

- `references/concepts.md` -- Storage fundamentals (block/file/object, RAID, erasure coding, replication, snapshots, dedup, compression, tiering, performance metrics). Read for "how does X work" or architecture questions.
- `references/paradigm-enterprise.md` -- Enterprise SAN/NAS patterns (NetApp, Dell, Pure, HPE). Read when evaluating enterprise storage.
- `references/paradigm-sds.md` -- Software-defined storage patterns (Ceph, MinIO, GlusterFS). Read when evaluating open-source or SDS options.
- `references/paradigm-cloud.md` -- Cloud object storage patterns (S3, Azure Blob, GCS). Read when evaluating cloud storage.
