# Cloud Object Storage Patterns

## When to Choose Cloud Object Storage

Cloud object storage (AWS S3, Azure Blob, Google Cloud Storage) is the right choice when:

- **Unlimited scale** is needed — no capacity planning, pay for what you use
- **Durability** is paramount — 99.999999999% (11 nines) designed durability
- **Global distribution** required — multi-region replication, edge caching
- **Cloud-native applications** store unstructured data (media, logs, backups, data lakes)
- **Serverless / event-driven** architectures need storage triggers (S3 Events, Azure Event Grid, GCS Notifications)
- **Data lake / analytics** workloads access data via compute engines (Spark, Athena, BigQuery)

## When to Avoid Cloud Object Storage

- **Low-latency block access** needed (databases, VMs) — use cloud block storage (EBS, Azure Disk, Persistent Disk) instead
- **POSIX filesystem** semantics required — use cloud file storage (EFS, Azure Files, Filestore) instead
- **Heavy egress** workloads — egress costs can exceed storage costs. Model data movement.
- **Data sovereignty** prevents data leaving specific jurisdictions
- **Predictable, high-volume** workloads — on-premises may be cheaper at scale

## Technology Comparison

| Feature | AWS S3 | Azure Blob Storage | Google Cloud Storage |
|---|---|---|---|
| **Storage Classes** | Standard, IA, One Zone-IA, Glacier IR, Glacier Flexible, Glacier Deep Archive, Express One Zone | Hot, Cool, Cold, Archive | Standard, Nearline, Coldline, Archive |
| **Consistency** | Strong read-after-write (since Dec 2020) | Strong (within region) | Strong (global) |
| **Max Object Size** | 5 TB (multipart upload) | 4.75 TB (block blob) | 5 TB (composite object) |
| **Versioning** | Per-bucket | Per-container | Per-bucket |
| **Lifecycle** | Transition + expiration rules | Lifecycle management policies | Lifecycle rules + Autoclass |
| **Encryption** | SSE-S3, SSE-KMS, SSE-C | Microsoft-managed, customer-managed, customer-provided | Google-managed, CMEK, CSEK |
| **Replication** | Cross-Region Replication (CRR), Same-Region (SRR) | Object Replication, GRS, GZRS | Dual-region, multi-region (automatic) |
| **Event Triggers** | S3 Event Notifications, EventBridge | Event Grid, Functions triggers | Pub/Sub notifications, Functions |
| **Data Lake** | S3 + Athena + Glue + Lake Formation | ADLS Gen2 (hierarchical namespace) | GCS + BigQuery + Dataproc |
| **Pricing Model** | Per-GB stored + per-request + egress | Per-GB stored + per-operation + egress | Per-GB stored + per-operation + egress |
| **Free Tier** | 5 GB (12 months) | 5 GB (12 months) | 5 GB (always free) |

## Storage Class Strategy

### AWS S3 Storage Classes

| Class | Access Pattern | Min Duration | Retrieval Cost | Use Case |
|---|---|---|---|---|
| **S3 Standard** | Frequent | None | None | Active data, websites, apps |
| **S3 Intelligent-Tiering** | Unknown/changing | None | None (monitoring fee) | Unpredictable access patterns |
| **S3 Standard-IA** | Infrequent | 30 days | Per-GB retrieval | Backups, DR copies |
| **S3 One Zone-IA** | Infrequent, reproducible | 30 days | Per-GB retrieval | Re-creatable data, secondary backups |
| **S3 Glacier Instant** | Rare, millisecond access | 90 days | Per-GB retrieval | Medical images, news archives |
| **S3 Glacier Flexible** | Rare, minutes-hours | 90 days | Per-GB + per-request | Compliance archives |
| **S3 Glacier Deep Archive** | Very rare, 12-48 hours | 180 days | Per-GB + per-request | Long-term compliance, legal hold |
| **S3 Express One Zone** | Ultra-frequent, single-AZ | None | Higher per-GB | ML training, analytics scratch |

### Cost Optimization Pattern

```
Upload ──> S3 Standard (0-30 days, active use)
              │
              └── Lifecycle rule: 30 days ──> S3 Standard-IA
                                                │
                                                └── 90 days ──> Glacier Instant Retrieval
                                                                  │
                                                                  └── 365 days ──> Glacier Deep Archive
                                                                                    │
                                                                                    └── 7 years ──> Delete (compliance met)
```

## Security Patterns

### Access Control Layers

| Layer | S3 | Azure Blob | GCS |
|---|---|---|---|
| **Identity** | IAM policies, STS | Azure AD/Entra ID, RBAC | IAM policies, service accounts |
| **Resource** | Bucket policies | Container-level access policies | Bucket IAM, ACLs |
| **Network** | VPC endpoints, access points | Private endpoints, service endpoints | VPC Service Controls |
| **Encryption** | SSE (S3/KMS/C), client-side | SSE (Microsoft/customer/provided) | SSE (Google/CMEK/CSEK) |
| **Audit** | CloudTrail, S3 access logs | Azure Monitor, Storage Analytics | Cloud Audit Logs |
| **Public Access** | Block Public Access (account/bucket) | Storage account public access setting | Public access prevention |

### Data Lake Security Pattern

```
IAM Role (who) ──> Bucket Policy (what bucket) ──> Prefix-based access (what data)
                                                         │
                                                    Lake Formation / Unity Catalog (column/row level)
```

## Performance Optimization

| Technique | What It Does | When to Use |
|---|---|---|
| **Multipart upload** | Upload large objects in parallel parts | Objects > 100 MB |
| **Transfer Acceleration** | Route through CloudFront/CDN edge | Cross-region uploads |
| **Byte-range fetches** | Download specific byte ranges | Large files, partial reads |
| **Request parallelism** | Multiple concurrent requests | High-throughput workloads |
| **Prefix distribution** | Spread keys across prefixes | > 5,500 GET/s or 3,500 PUT/s per prefix (S3) |
| **S3 Express One Zone** | Single-digit ms latency, single AZ | ML training, analytics |
| **CDN integration** | Cache objects at edge | Static content, media delivery |

## Anti-Patterns

1. **"Store everything in Standard tier"** — Use lifecycle policies. Most data becomes cold quickly. Tiering can reduce costs 60-90%.
2. **"Public buckets for convenience"** — Data breaches from misconfigured public buckets are a leading cause of cloud security incidents. Always enable Block Public Access.
3. **"Ignoring egress costs"** — Egress from cloud storage is $0.05-0.12/GB. A 100 TB monthly egress = $5,000-12,000/month. Model this before architecting.
4. **"Single-region without replication"** — Cloud regions can have outages. For critical data, enable cross-region replication or use multi-region storage classes.
5. **"No versioning on critical buckets"** — Without versioning, a delete or overwrite is permanent. Enable versioning and lifecycle policies for version expiration.
