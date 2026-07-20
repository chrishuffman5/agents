# AWS Storage Reference

> S3, EBS, EFS, FSx. Prices are US East (N. Virginia) on-demand.

---

## S3 Storage Classes

### Decision Tree

```
Access pattern known?
  Frequent access ────────────────── S3 Standard ($0.023/GB-mo)
  Infrequent (< 1x/month) ─┬── Multi-AZ? ── Standard-IA ($0.0125/GB-mo)
                            └── Reproducible? ── One Zone-IA ($0.01/GB-mo)
  Rare archive ──────┬── ms retrieval? ── Glacier Instant ($0.004/GB-mo)
                     ├── Hours OK? ────── Glacier Flexible ($0.0036/GB-mo)
                     └── 12-48hr OK? ──── Glacier Deep Archive ($0.00099/GB-mo)
  Unknown/unpredictable ───────────── Intelligent-Tiering ($0.023/GB-mo peak
                                       + $0.0025/1000 objects monitoring)
```

### Key Constraints

- Standard-IA / One Zone-IA: **minimum 128 KB** charge per object, **minimum 30-day** storage charge. Millions of tiny files in IA costs more than Standard.
- Glacier Flexible retrieval: Expedited (1-5 min, $0.03/GB), Standard (3-5 hr, $0.01/GB), Bulk (5-12 hr, $0.0025/GB).
- Glacier Deep Archive: Standard (12 hr, $0.02/GB), Bulk (48 hr, $0.0025/GB).
- Intelligent-Tiering: zero retrieval fees, automatic tiering, but $0.0025/1000 objects/month monitoring. Cost-effective for >128 KB objects with unpredictable access.

### Lifecycle Policy Pattern

```
Day 0-29:    Standard           $0.023/GB-mo
Day 30-89:   Standard-IA        $0.0125/GB-mo  (45% savings)
Day 90-364:  Glacier Flexible   $0.0036/GB-mo  (84% savings)
Day 365+:    Glacier Deep       $0.00099/GB-mo (96% savings)
Day 2555+:   Delete (7-year retention met)
```

**1 TB stored for 3 years:** All Standard = $828. With lifecycle = ~$105 (87% savings).

### Cost Components

For every S3 cost estimate, account for all four components:

| Component | Standard Pricing | Trap to Watch |
|-----------|-----------------|---------------|
| Storage | $0.023/GB-mo | Versioning multiplies storage (every version stored) |
| PUT/COPY/POST/LIST | $0.005/1000 requests | LIST at $0.005/1000 adds up with large prefixes |
| GET/SELECT | $0.0004/1000 requests | Frequent small-object reads can dominate cost |
| Data transfer out | $0.09/GB (first 10 TB/mo) | Use CloudFront for public content (cheaper at scale) |
| Retrieval (Glacier) | $0.01-$0.03/GB | Expedited retrieval can dwarf storage savings |

**High-request example:** 100 GB stored, 10M GETs/mo, 500 GB transfer out: Storage $2.30 + GETs $4.00 + Transfer $45.00 = **$51.30/mo** (88% is transfer, not storage!)

### Performance Features

- **S3 Express One Zone:** Single-digit ms latency, 10x faster than Standard. $0.16/GB-mo + $0.008/10K requests. For ML training data, interactive analytics.
- **Transfer Acceleration:** CloudFront edges for faster uploads. $0.04-$0.08/GB extra. For distant-region uploads.
- **S3 Select:** Query CSV/JSON/Parquet in place. $0.002/GB scanned. Use when you need <20% of the object.
- **Multipart upload:** Required for >5 GB, recommended for >100 MB. Parallel parts improve throughput.

### S3 Optimization Checklist

1. Enable Intelligent-Tiering for unknown access patterns (objects >128 KB)
2. Implement lifecycle rules on all buckets (at minimum, expire incomplete multipart uploads)
3. Use S3 Storage Lens for bucket-level cost analysis
4. Enable S3 Inventory (weekly) to find versioning bloat and incomplete uploads
5. Use VPC Gateway Endpoints for S3 access from EC2/Lambda (free, avoids NAT charges)
6. Use CloudFront for public content delivery (cheaper transfer, better performance)
7. Abort incomplete multipart uploads via lifecycle rule (7 days)
8. Add `NoncurrentVersionExpiration` lifecycle rule to version-enabled buckets

---

## EBS Volume Types

### Decision Matrix

| Type | IOPS | Throughput | $/GB-mo | Best For |
|------|------|-----------|---------|----------|
| **gp3** | 3,000 base (up to 16,000) | 125 MBps base (up to 1,000) | $0.08 | **Default for everything. Always over gp2.** |
| gp2 | 3 IOPS/GB (burst to 3,000) | 250 MBps max | $0.10 | Legacy. Migrate to gp3. |
| **io2 Block Express** | Up to 256,000 | Up to 4,000 MBps | $0.125 + $0.065/IOPS | Mission-critical DBs needing sub-ms latency |
| st1 | 500 IOPS max | 500 MBps (burst) | $0.045 | Sequential reads: data lakes, log processing |
| sc1 | 250 IOPS max | 250 MBps (burst) | $0.015 | Cold storage, infrequent sequential reads |

### gp3 vs gp2 -- Always Choose gp3

- gp3: 3,000 IOPS + 125 MBps **included at $0.08/GB**
- gp2: need 1,000 GB just to get 3,000 IOPS (3 IOPS/GB), costing $100/mo
- gp3 at 100 GB: $8/mo with 3,000 IOPS. gp2 at 100 GB: $10/mo with 300 sustained IOPS.
- Additional gp3 IOPS: $0.005/IOPS-mo. Additional throughput: $0.04/MBps-mo.

### io2 Cost Example (50,000 IOPS Database Volume)

- Storage (500 GB): 500 x $0.125 = $62.50
- IOPS: 50,000 x $0.065 = $3,250.00
- Total: **$3,312.50/mo** -- 10x+ the cost of gp3. Only use when you genuinely need >16,000 guaranteed IOPS.

### EBS Snapshots

- Incremental: only changed blocks stored after first full snapshot
- Cost: $0.05/GB-month (based on consumed storage)
- **Snapshot Lifecycle Manager:** automate creation/deletion with retention policies
- **Snapshot Archive:** $0.0125/GB-mo (75% cheaper), 24-72 hr restore. For compliance snapshots.
- **Fast Snapshot Restore (FSR):** $0.75/AZ-hour. Only for boot volumes or DBs needing immediate full performance.

### EBS Optimization Checklist

1. Migrate all gp2 volumes to gp3
2. Delete unattached volumes: `aws ec2 describe-volumes --filters Name=status,Values=available`
3. Right-size: check CloudWatch `VolumeReadOps`, `VolumeWriteOps`
4. Use Snapshot Lifecycle Manager on all volumes
5. Archive old compliance-only snapshots
6. Consider io2 only when gp3 at 16,000 IOPS is insufficient

---

## EFS vs FSx

### EFS (Elastic File System)

Managed NFS (POSIX-compliant), multi-AZ, auto-scaling capacity.

| Feature | Standard | Infrequent Access (IA) |
|---------|----------|----------------------|
| Storage | $0.30/GB-mo | $0.016/GB-mo |
| Read | Included | $0.01/GB |
| Write | Included | $0.06/GB |

**Throughput modes:**
- **Elastic (default):** Auto-scales. $0.04/MB read, $0.08/MB write. Best for spiky workloads.
- **Bursting:** Baseline 50 KB/s per GB stored, burst to 100 MB/s. Free but limited.
- **Provisioned:** Fixed throughput. $6.00/MBps-mo. For consistent throughput with small storage.

**EFS lifecycle policy:** Transition to IA after 7/14/30/60/90 days. Typical savings: 60-80%.

**Cost example (500 GB, 80% cold):** All Standard: $150/mo. With lifecycle: $36.40/mo (76% savings).

### FSx Family

| Variant | Protocol | Starting Cost | Best For |
|---------|----------|--------------|----------|
| **Lustre** | Lustre | $0.14/GB-mo (persistent), $0.058/GB-mo (scratch) | HPC, ML training, S3 data lake integration |
| **Windows** | SMB | $0.13/GB-mo (SSD) | Windows workloads, AD integration |
| **NetApp ONTAP** | NFS/SMB/iSCSI | $0.09/GB-mo (capacity pool) | Multi-protocol, enterprise migration |
| **OpenZFS** | NFS | $0.09/GB-mo (SSD) | High-performance NFS, snapshots, compression |

### When to Use What

```
Need shared POSIX filesystem?
  Linux workloads ─┬── Auto-scaling, simplicity ── EFS
                   ├── HPC / ML throughput ──── FSx Lustre
                   └── Enterprise NFS features ── FSx OpenZFS or ONTAP
  Windows workloads ── FSx Windows
  Multi-protocol (NFS+SMB) ── FSx ONTAP
```
