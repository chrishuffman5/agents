# AWS Storage Reference

> S3, S3 Tables, EBS, EFS, FSx. Prices are US East (N. Virginia) and are PRICE-VOLATILE; capacity ceilings and mechanics are structural facts.

---

## S3 Storage Classes

> Source: https://aws.amazon.com/s3/storage-classes/ (official)

Current class list, all confirmed as named: S3 Standard, S3 Standard-IA, S3 One Zone-IA, S3 Intelligent-Tiering, S3 Glacier Instant Retrieval, S3 Glacier Flexible Retrieval (the former plain "S3 Glacier"), S3 Glacier Deep Archive, and S3 Express One Zone.

### Decision Tree

```
Access pattern known?
  Frequent ------------------------- S3 Standard (~$0.023/GB-mo)
  Infrequent (< 1x/month) --+-- Multi-AZ needed?  -- Standard-IA (~$0.0125/GB-mo)
                            +-- Reproducible?     -- One Zone-IA (~$0.01/GB-mo)
  Rare archive -------+-- ms retrieval?      -- Glacier Instant (~$0.004/GB-mo)
                      +-- hours acceptable?  -- Glacier Flexible (~$0.0036/GB-mo)
                      +-- 12-48 hr OK?       -- Glacier Deep Archive (~$0.00099/GB-mo)
  Unknown/unpredictable ------------ Intelligent-Tiering (+ per-object monitoring charge)
```

### Key Constraints

> Source: https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html (official)

**Minimum storage duration and minimum billable object size, per class:**

| Storage class | Min storage duration | Min billable object size |
|---|---|---|
| S3 Standard-IA | **30 days** | **128 KB** |
| S3 One Zone-IA | **30 days** | **128 KB** |
| S3 Glacier Instant Retrieval | **90 days** | **128 KB** |

Verbatim: "The S3 Standard-IA and S3 One Zone-IA storage classes are suitable for objects larger than 128 KB that you plan to store for at least 30 days. **If an object is less than 128 KB, Amazon S3 charges you for 128 KB.** If you delete an object before the end of the 30-day minimum storage duration period, you are charged for 30 days."

Two consequences worth stating in any lifecycle design: **millions of small objects cost more in IA than in Standard**, because each one bills as 128 KB regardless of its real size; and a transition to **Glacier Instant Retrieval commits you to 90 days, not 30** — delete earlier and you are billed for the full period anyway.

- Glacier Flexible retrieval tiers: Expedited (1-5 min), Standard (3-5 hr), Bulk (5-12 hr). Deep Archive: Standard (12 hr), Bulk (48 hr). Retrieval charges can dwarf the storage savings on a restore-heavy workload.
- Intelligent-Tiering charges per-object monitoring and has no retrieval fee. Its sub-128 KB behavior is a **different mechanism** from the IA classes' billing floor: small objects are simply excluded from auto-tiering and remain in the Frequent Access tier, with no forced 128 KB charge.

### Lifecycle Pattern and Cost Components

```
Day 0-29    Standard
Day 30-89   Standard-IA        (~45% below Standard)
Day 90-364  Glacier Flexible   (~84% below Standard)
Day 365+    Glacier Deep       (~96% below Standard)
Day 2555+   Expire (7-year retention met)
```

Estimate every S3 workload across all four cost components, not just storage:

| Component | Trap |
|---|---|
| Storage | Versioning multiplies it — every noncurrent version is stored and billed |
| PUT/COPY/POST/LIST requests | LIST over large prefixes accumulates quietly |
| GET/SELECT requests | Frequent small-object reads can dominate total cost |
| Data transfer out | Often the largest line — use CloudFront for public content |
| Glacier retrieval | Expedited retrieval can exceed the annual storage saving in one incident |

A 100 GB bucket serving 10M GETs and 500 GB egress per month is dominated by transfer, not storage. Always show the split.

### Performance Features

- **S3 Express One Zone** — single-digit-millisecond latency, single-AZ, for ML training data and interactive analytics. Higher per-GB rate, much lower per-request latency.
- **Transfer Acceleration** — CloudFront edge ingress for distant uploads, at a per-GB surcharge.
- **S3 Select** — query CSV/JSON/Parquet in place; worthwhile when you need well under the whole object.
- **Multipart upload** — required above 5 GB, recommended above 100 MB. Always add a lifecycle rule to abort incomplete multipart uploads.

### S3 Tables (analytics-native storage)

> Source: https://docs.aws.amazon.com/decision-guides/latest/analytics-on-aws-how-to-choose/analytics-on-aws-how-to-choose.html (official)

"Amazon S3 Tables provide S3 storage that's optimized for analytics workloads. Using standard SQL statements, you can query your tables with query engines that support Iceberg, such as Athena, Amazon Redshift, and Apache Spark."

Selection rule: raw objects plus a Glue crawler and Data Catalog remain correct for heterogeneous, schema-drifting data lakes. **Reach for S3 Tables when the data is genuinely tabular and you want Apache Iceberg semantics** (ACID table operations, schema evolution, time travel) without bolting a table format onto plain objects yourself. Data Firehose can deliver directly to Apache Iceberg Tables, so streaming and batch ingestion land in the same table layer. Composition detail in `references/analytics.md`.

### S3 Optimization Checklist

1. Intelligent-Tiering for unknown access patterns on objects above ~128 KB
2. A lifecycle rule on every bucket — at minimum, abort incomplete multipart uploads after 7 days
3. `NoncurrentVersionExpiration` on every version-enabled bucket
4. S3 Storage Lens for bucket-level visibility (see `references/cost.md`)
5. S3 Inventory weekly to find version bloat
6. VPC Gateway Endpoint for S3 in every VPC (free)
7. CloudFront in front of public content

---

## EBS Volume Types

> Source: https://aws.amazon.com/ebs/volume-types/ (official)

| Type | IOPS | Throughput | Best for |
|---|---|---|---|
| **gp3** | 3,000 baseline, **up to 80,000** | 125 MBps baseline, **up to 2,000 MBps** | **Default for everything. Always over gp2.** |
| gp2 | 3 IOPS/GB (100 IOPS floor, burst to 3,000) | Up to 250 MBps | Legacy. Migrate to gp3. |
| **io2 Block Express** | Up to 1,000 IOPS/GB, **max 256,000** | **Max 4,000 MBps** | Mission-critical DBs needing sub-ms latency |
| io1 | Max 64,000 | Max 1,000 MBps | Legacy — io2 Block Express is strictly better; migrate off |
| st1 | Throughput-model, not IOPS-capped: **40 MBps/TB baseline, bursts to 250 MBps/TB, max 500 MBps/volume** | -- | Sequential reads: data lakes, log processing |
| sc1 | **12 MBps/TB baseline, bursts to 80 MBps/TB, max 250 MBps/volume** | -- | Cold, infrequent sequential reads |

st1 and sc1 are billed and provisioned on a **per-TB throughput** model. Describing them with a flat IOPS ceiling is wrong and will mislead sizing.

### gp3 vs gp2

gp3 includes 3,000 IOPS and 125 MBps at a lower per-GB rate; gp2 has to be over-provisioned in *size* to reach the same IOPS (3 IOPS/GB). Additional gp3 IOPS and throughput are billed separately above the included baseline (per provisioned IOPS-month and per MBps-month respectively — rates are PRICE-VOLATILE). The **80,000 IOPS / 2,000 MBps ceiling** means gp3 now covers workloads that previously forced io2; re-check before assuming a database needs Provisioned IOPS.

### io2 cost shape

io2 charges per GB **plus** per provisioned IOPS-month. At high IOPS the provisioned-IOPS line dominates the bill by an order of magnitude over the storage line. Only justify it when gp3's 80,000 IOPS / 2,000 MBps ceiling or io2's sub-millisecond latency guarantee is genuinely required.

### Snapshots

Incremental after the first full snapshot, billed on consumed storage. Automate with **Data Lifecycle Manager**. **Snapshot Archive** is materially cheaper with a 24-72 hour restore — right for compliance-retention snapshots. **Fast Snapshot Restore** is billed per AZ-hour and is only worth it for boot volumes or databases that need full performance immediately on restore.

---

## EFS

> Source: https://docs.aws.amazon.com/efs/latest/ug/performance.html and https://aws.amazon.com/efs/pricing/ (official)

### Three storage classes, not two

EFS has **Standard**, **Infrequent Access (IA)**, and **Archive** — Archive is "cost-optimized storage... for long-lived data accessed a few times a year or less," priced below IA. Default EFS Intelligent-Tiering transitions are **Standard -> IA after 30 days of no access** and **IA -> Archive after 90 days of no access**, with promotion back to Standard on access. A lifecycle policy that stops at IA leaves the coldest tier of savings on the table.

### Throughput modes

- **Elastic (default)** — no burst credits; billed on metered data read and written. Best for spiky or unpredictable workloads. (Per-MB read/write figures circulating in older material were not re-confirmed; describe the model, not the digits.)
- **Provisioned** — fixed throughput independent of stored size, billed per MBps-month. AWS recommends it when the average-to-peak throughput ratio exceeds 5%.
- **Bursting** — baseline **50 KiB/s per GiB of Standard-class storage**. Burst ceiling is **not a flat 100 MB/s**: with credits available a filesystem can drive **up to 100 MiBps per TiB of Standard storage, with a 100 MiBps minimum**; without credits it falls to 50 MiBps per TiB with a 1 MiBps floor. A 10 TiB filesystem bursts far above 100 MB/s — the flat-cap framing badly understates large filesystems.

---

## FSx Family

> Source: https://aws.amazon.com/fsx/ (official)

Four variants, unchanged:

| Variant | Protocol | Best for |
|---|---|---|
| FSx for Lustre | Lustre | HPC, ML training, S3-linked data lakes |
| FSx for Windows File Server | SMB | Windows workloads, Active Directory integration |
| FSx for NetApp ONTAP | NFS/SMB/iSCSI | Multi-protocol, enterprise migration, ONTAP features |
| FSx for OpenZFS | NFS | High-performance NFS with snapshots and compression |

### Shared-filesystem selection

```
Need a shared POSIX filesystem?
  Linux   -+-- Elastic, simple, multi-AZ ----- EFS
           +-- HPC / ML throughput ----------- FSx for Lustre
           +-- Enterprise NFS features ------- FSx for OpenZFS or ONTAP
  Windows ----------------------------------- FSx for Windows File Server
  Multi-protocol (NFS + SMB) ---------------- FSx for NetApp ONTAP
```

## Sources

- https://aws.amazon.com/s3/storage-classes/
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html
- https://aws.amazon.com/ebs/volume-types/
- https://docs.aws.amazon.com/efs/latest/ug/performance.html
- https://aws.amazon.com/efs/pricing/
- https://aws.amazon.com/fsx/
- https://docs.aws.amazon.com/decision-guides/latest/analytics-on-aws-how-to-choose/analytics-on-aws-how-to-choose.html

Fetched: 2026-08-08
