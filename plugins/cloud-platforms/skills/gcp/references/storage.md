# GCP Storage Reference

> Prices are us-central1 unless noted. Verify at https://cloud.google.com/pricing.

## 1. Cloud Storage (Object Storage)

### Storage Classes

| Class | Min Duration | Storage $/GB/mo | Retrieval $/GB | Use Case |
|-------|-------------|-----------------|----------------|----------|
| Standard | None | $0.020-0.026 | $0.00 | Frequently accessed |
| Nearline | 30 days | $0.010-0.016 | $0.01 | Monthly access |
| Coldline | 90 days | $0.004-0.006 | $0.02 | Quarterly access |
| Archive | 365 days | $0.0012-0.0025 | $0.05 | Annual access, compliance |

### Autoclass (Unique to GCP)

Automatically transitions objects between classes based on access patterns:
- No lifecycle policy configuration needed. GCP monitors and moves objects to optimal class.
- Objects start in Standard, move to Nearline -> Coldline -> Archive as access decreases.
- Moves back to hotter tiers when accessed again.
- Eliminates lifecycle policy guesswork. Valuable for unpredictable access patterns.
- $0.0025/1000 transitions (minimal cost).

### Location Types

| Type | Coverage | Availability | Use Case |
|------|----------|-------------|----------|
| Region | Single region | 99.9% | Lowest latency for that region |
| Dual-region | Two specific regions | 99.95% | Automatic replication |
| Multi-region | Continental (US/EU/Asia) | 99.95% | Broadest coverage |

Turbo Replication (dual-region only): 15-minute RPO. Premium pricing.

### Operations Pricing

- Class A (writes, list): $0.005/10K (Standard) to $0.05/10K (Archive)
- Class B (reads): $0.0004/10K (Standard) to $0.005/10K (Archive)
- Deletes and bucket metadata reads: free

### Key Features

- **Object Versioning:** Retain previous versions (storage cost per version).
- **Lifecycle Management:** Rules to delete, transition class, abort multipart by age/conditions.
- **Retention policies + bucket locks:** Compliance/WORM support.
- **Signed URLs:** Time-limited access without authentication.
- **Parallel composite uploads** for large objects.

### Transfer Services

- **Transfer Service:** Managed bulk transfer from S3, Azure Blob, on-prem, HTTP.
- **Transfer Appliance:** Physical appliance for offline migration (100TB, 480TB).
- **gsutil / gcloud storage:** CLI for object management.

---

## 2. Persistent Disks and Hyperdisk

### Disk Types

| Type | IOPS (max) | Throughput (max) | $/GB/mo | Use Case |
|------|-----------|-----------------|---------|----------|
| pd-standard (HDD) | 7,500 R / 15K W | 240/400 MB/s | $0.040 | Bulk storage, logs |
| pd-balanced | 80,000 | 1,200 MB/s | $0.100 | General purpose (default) |
| pd-ssd | 100,000 | 1,200 MB/s | $0.170 | Databases, high IOPS |
| pd-extreme | 120,000 | 2,400 MB/s | $0.125 + IOPS | Ultra-high performance |
| Hyperdisk Extreme | 350,000 | 5,000 MB/s | Provisioned | Maximum IOPS |
| Hyperdisk Throughput | 3,000 | 2,400 MB/s | Provisioned | Streaming, analytics |
| Hyperdisk Balanced | 160,000 | 2,400 MB/s | Provisioned | General, dynamic resize |

### Regional Persistent Disks (Unique to GCP)

Synchronous replication between two zones in same region:
- HA for stateful workloads without app-level replication.
- Automatic failover if one zone fails.
- 2x cost of zonal disks (paying for two copies).
- Supported: pd-standard, pd-balanced, pd-ssd.
- Use for databases and stateful apps needing transparent zone failover.

### Snapshots

- Incremental (only changed blocks after first full snapshot).
- Regional: $0.026/GB/month. Multi-regional: $0.052/GB/month.
- Snapshot schedules: automated periodic snapshots with retention policies.

---

## 3. Filestore (Managed NFS)

| Tier | $/GB/mo | HA | Use Case |
|------|---------|-------|----------|
| Basic HDD | $0.176 | No | Dev/test file shares |
| Basic SSD | $0.340 | No | Performance file shares |
| Zonal | $0.200 | Zonal | Cost-effective SSD |
| Enterprise | $0.300 | Regional (99.99%) | Production, snapshots, backup |

NFSv3 for GCE and GKE workloads. Basic: 1-63.9 TB. Enterprise: 1-10 TB (scales higher on request).

Use for: shared filesystems, media rendering, EDA workflows, legacy app migration.
