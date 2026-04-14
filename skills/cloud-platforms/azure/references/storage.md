# Azure Storage Reference

> Prices are US East, pay-as-you-go unless noted. Verify at https://azure.microsoft.com/pricing/.

## 1. Blob Storage

Azure's foundational object storage. Data Lake Storage, static websites, and backup targets all build on it.

### Access Tiers

| Tier | Storage $/GB/mo | Read $/10K | Write $/10K | Min Retention | Retrieval $/GB |
|------|----------------|------------|-------------|---------------|----------------|
| Hot | $0.018 | $0.004 | $0.05 | None | None |
| Cool | $0.01 | $0.01 | $0.10 | 30 days | $0.01 |
| Cold | $0.0036 | $0.01 | $0.18 | 90 days | $0.02 |
| Archive | $0.00099 | $5.00 | $0.10 | 180 days | $0.022 |

Early deletion penalty: Deleting before minimum retention charges for remaining days.

### Archive Rehydration

Archive blobs are offline. To read, you must rehydrate:
- **Standard:** Up to 15 hours. No priority fee.
- **High-priority:** Under 1 hour for objects <10 GB. ~$0.10/GB premium.
- Rehydrate by changing tier (in-place) or copying to Hot/Cool blob.

### Tier Strategy

- **Account default:** Set to Cool if most data is infrequently accessed. Override individual blobs to Hot as needed.
- **Blob level:** Only way to set Cold or Archive tiers.

### Lifecycle Management

Automate tier transitions with JSON rules:
- Rules run once/day (24-48 hour delay).
- Transitions only go downward: Hot > Cool > Cold > Archive.
- Block blobs only (not append or page blobs).
- Filter by prefix, blob index tags, or blob type.

### Redundancy Options

| Type | Copies | Regions | Storage $/GB/mo (Hot) | Use Case |
|------|--------|---------|----------------------|----------|
| LRS | 3, 1 DC | 1 | $0.018 | Dev/test, reproducible data |
| ZRS | 3, 3 AZs | 1 | $0.021 | Production single-region HA |
| GRS | 6 | 2 | $0.036 | DR (secondary not readable) |
| RA-GRS | 6, readable secondary | 2 | $0.047 | DR with read failover |
| GZRS | 6 (3 zones + 3 secondary) | 2 | $0.044 | Maximum durability + zone HA |
| RA-GZRS | GZRS + readable secondary | 2 | $0.050 | Maximum protection |

**Strategic guidance:** LRS for dev/test. ZRS for production. GRS/RA-GRS for compliance and DR. GZRS/RA-GZRS for mission-critical (2-3x LRS cost).

### Immutable Storage (WORM)

For compliance (SEC 17a-4, HIPAA, FINRA):
- **Time-based retention:** Lock blobs for specified interval. Once locked, cannot be shortened.
- **Legal hold:** Indefinite hold, apply/remove independently.
- Immutable blobs can still be tiered to save costs.

### Data Lake Storage Gen2

Hierarchical namespace (HNS) enabled on Blob Storage:
- POSIX-like directory operations, ACLs at directory level.
- Required for Synapse, Databricks, and big data workloads.
- ~5-10% storage premium over standard Blob.
- HNS cannot be disabled once enabled -- plan at account creation.
- Enable for analytics/Spark workloads. Standard Blob for pure application storage.

### Blob Cost Optimization

**Right-sizing redundancy by data class:**
- Application logs: LRS + lifecycle to Archive after 30 days (~$0.001/GB/mo after archival).
- User uploads: ZRS Hot, lifecycle to Cool after 60 days (~$0.02/GB/mo initially).
- Compliance archives: GRS Archive + immutable policy (~$0.002/GB/mo with geo-redundancy).

**Reserved capacity:**
- 1-year: ~20-38% savings. 3-year: ~30-48% savings.
- Minimum 100 TiB/month (Hot/Cool). Applies only to storage capacity, not transactions.

---

## 2. Azure Files

Managed file shares via SMB 3.x and NFS 4.1.

### Tiers

| Tier | Media | Protocol | Storage $/GB/mo | Billing Model |
|------|-------|----------|----------------|---------------|
| Premium | SSD | SMB + NFS | $0.16 (provisioned) | Provisioned capacity |
| Transaction Optimized | HDD | SMB only | $0.06 | Pay-as-you-go |
| Hot | HDD | SMB only | $0.026 | Pay-as-you-go |
| Cool | HDD | SMB only | $0.015 | Pay-as-you-go |

Premium is provisioned: you pay for allocated capacity whether used or not. IOPS scale with provisioned size. NFS is Premium-only and requires a VNet.

### Azure File Sync

Extends Azure Files to on-premises Windows Servers:
- **Cloud tiering:** Replace infrequently accessed files with stubs. Recall transparently on access.
- **Multi-site sync:** Multiple servers sync to same share. Last-writer-wins conflict resolution.
- Sync service itself is free. Pay for Azure Files storage and transactions.

### Files vs Blob Decision

| Requirement | Azure Files | Blob Storage |
|---|---|---|
| SMB/NFS protocol | Yes | No (REST/SDK only) |
| POSIX semantics | NFS tier only | No |
| Object storage | No | Yes |
| Lifecycle tiering | No | Yes |
| Cost per GB (standard) | $0.015-$0.06 | $0.001-$0.018 |

Use Azure Files for file system semantics (legacy apps, config, shared logs). Use Blob for everything else.

---

## 3. Managed Disks

### Disk Types

| Type | IOPS (max) | Throughput | $/GB/mo (256 GiB) | Use Case |
|------|-----------|------------|-------------------|----------|
| Standard HDD | 500 | 60 MiB/s | ~$0.04 | Dev/test, non-critical |
| Standard SSD | 6,000 | 750 MiB/s | ~$0.075 | Web servers, light workloads |
| Premium SSD (P-series) | 20,000 | 900 MiB/s | ~$0.14 | Production databases |
| Premium SSD v2 | 80,000 | 1,200 MiB/s | ~$0.082 + IOPS | Flexible production (sweet spot) |
| Ultra Disk | 400,000 | 4,000 MiB/s | ~$0.12 + IOPS | SAP HANA, top-tier databases |

### Premium SSD v2 vs P-series

- **P-series:** IOPS/throughput fixed by disk size. P30 (1 TiB) = 5,000 IOPS, 200 MiB/s.
- **Premium SSD v2:** Set IOPS (3K-80K) and throughput (125-1,200 MiB/s) independently.
- v2 is typically 30-50% cheaper for high-IOPS workloads.
- v2 does not support host caching -- use P-series for OS disks.

### Bursting

- **Credit-based (free):** P20/E30 and smaller. Accumulate credits when idle, burst to 30K IOPS.
- **On-demand:** P30+ only. Burst any time. Charged $0.00005/IOPS-hour. Enable explicitly.

### Encryption

All managed disks encrypted at rest (256-bit AES) by default:
- **Platform-managed keys (PMK):** Default. Zero effort.
- **Customer-managed keys (CMK):** Via Key Vault. Required for FedRAMP High, PCI-DSS.
- **Encryption at host:** Covers temp disks and caches. Must be enabled per VM.

### Disk Cost Optimization by Environment

| Environment | Recommended Disk | Rationale |
|---|---|---|
| Dev/test | Standard SSD | 50% cheaper than Premium |
| Web/app tier | Standard SSD or Premium SSD v2 | Balance cost and latency |
| Production databases | Premium SSD v2 or Ultra | Decouple IOPS from capacity |
| SAP HANA | Ultra Disk | Sub-ms latency, highest IOPS |

**Snapshots:** Incremental, $0.05/GB/month. 1 TiB disk with 10% daily change ~$5/mo.
