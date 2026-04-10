# AWS S3 Architecture

## Bucket / Object Model

### Fundamental Concepts

Amazon S3 is a distributed object storage service. Data is stored as **objects** inside **buckets**. There is no true filesystem hierarchy — what appears as folder paths are simply key prefixes embedded in the object key name.

- **Bucket**: Top-level container. Bucket names are globally unique across all AWS accounts and regions. A bucket exists in a single AWS Region.
- **Object**: The unit of storage. Composed of the object data (value), metadata (key-value pairs), a unique key, and a version ID (if versioning is enabled).
- **Key**: The full identifier of an object within a bucket (e.g., `logs/2026/03/access.log`). The `/` delimiter creates the illusion of directories but is part of the key string.
- **Object URL**: `https://<bucket>.s3.<region>.amazonaws.com/<key>`

### Durability and Redundancy

- S3 Standard and most storage classes store data across a **minimum of 3 Availability Zones** within the selected region.
- Designed for **99.999999999% (11 nines)** durability.
- S3 Express One Zone and S3 One Zone-IA store data in a **single AZ** — lower durability risk profile.

### Bucket Limits

- Default quota: **100 buckets per account** (general purpose); up to **10 directory buckets** for Express One Zone. Quota increases available via Service Quotas.
- Modern accounts may support up to **10,000 general purpose buckets** with quota increase.
- Account regional namespace (introduced for new accounts) prevents bucket name squatting after deletion.

---

## Storage Classes

| Storage Class | Durability | Availability | Min Storage | Retrieval | AZs | Use Case |
|---|---|---|---|---|---|---|
| S3 Standard | 11 nines | 99.99% | None | Milliseconds | ≥3 | Frequently accessed data |
| S3 Express One Zone | 11 nines | 99.95% | None | Single-digit ms | 1 | Latency-sensitive, ML/AI workloads |
| S3 Standard-IA | 11 nines | 99.9% | 30 days | Milliseconds | ≥3 | Infrequent access, long-lived |
| S3 One Zone-IA | 11 nines | 99.5% | 30 days | Milliseconds | 1 | Recreatable infrequent-access data |
| S3 Intelligent-Tiering | 11 nines | 99.9% | None | Varies by tier | ≥3 | Unknown/changing access patterns |
| S3 Glacier Instant Retrieval | 11 nines | 99.9% | 90 days | Milliseconds | ≥3 | Quarterly-accessed archives |
| S3 Glacier Flexible Retrieval | 11 nines | 99.99%* | 90 days | Minutes–hours | ≥3 | Annual-access archives |
| S3 Glacier Deep Archive | 11 nines | 99.99%* | 180 days | 12–48 hours | ≥3 | Long-term regulatory archives |

*After restoration. Objects must be restored before access.

### S3 Intelligent-Tiering Tiers

Automatically moves objects between access tiers with no retrieval fees:

1. **Frequent Access** — default, immediate access
2. **Infrequent Access** — after 30 consecutive days without access
3. **Archive Instant Access** — after 90 days (millisecond retrieval)
4. **Archive Access** (optional) — after 90+ days (minutes to hours)
5. **Deep Archive Access** (optional) — after 180+ days (hours)

Objects smaller than 128 KB are never monitored and always remain in Frequent Access.

### S3 Glacier Variants Detail

**S3 Glacier Instant Retrieval**
- Millisecond access (same latency as S3 Standard-IA)
- Minimum object size: 128 KB
- Minimum storage duration: 90 days
- Per-GB retrieval fee applies
- Ideal for medical records, image hosting, and quarterly-accessed archives

**S3 Glacier Flexible Retrieval** (formerly S3 Glacier)
- Objects are archived and unavailable for real-time access
- Restore options:
  - **Expedited**: 1–5 minutes (highest cost)
  - **Standard**: 3–5 hours
  - **Bulk**: 5–12 hours (lowest cost)
- Minimum storage duration: 90 days
- Restored copy available for a configurable number of days (billed at S3 Standard rate)

**S3 Glacier Deep Archive**
- Lowest cost storage in AWS (~$0.00099/GB-month, ~96% cheaper than Standard)
- Restore options:
  - **Standard**: within 12 hours
  - **Bulk**: within 48 hours
- Minimum storage duration: 180 days
- Designed for data retained 7–10+ years with near-zero retrieval probability
- WORM-compliant archives, financial records, healthcare data

### S3 Express One Zone

- High-performance, single-AZ storage class (directory bucket type)
- Single-digit millisecond latency — up to 10x faster than S3 Standard
- Request costs up to 80–85% lower than S3 Standard (after 2026 price cuts)
- Storage price reduced 31% in early 2026
- Optimized for ML training, real-time analytics, HPC, and game asset serving
- Uses **directory buckets** (not general purpose buckets)
- Accessed via `CreateSession` API with session-based credentials

---

## Versioning

- Preserves, retrieves, and restores every version of every object in a bucket
- States: **Unversioned** (default), **Versioning-enabled**, **Versioning-suspended**
- Once enabled, versioning cannot be fully disabled — only suspended
- Concurrent writes to the same key result in multiple versions being stored
- Deletion creates a **delete marker** (a version with no data); the object is hidden but not erased
- Permanent deletion requires specifying the version ID
- Versioning is required for S3 Replication and MFA Delete

---

## Lifecycle Policies

S3 Lifecycle automates transitioning objects between storage classes or expiring objects after defined rules.

### Rule Components

- **Filter**: Target by prefix, object tag, object size, or a combination
- **Transition actions**: Move to a cheaper storage class after N days
- **Expiration actions**: Permanently delete objects after N days
- **Noncurrent version actions**: Apply transitions/expiration to older versions in versioning-enabled buckets
- **Incomplete multipart upload expiration**: Clean up abandoned multipart uploads

### Transition Waterfall (Valid Transitions Only)

```
S3 Standard
  -> S3 Standard-IA (min 30 days in Standard)
  -> S3 Intelligent-Tiering
  -> S3 One Zone-IA
  -> S3 Glacier Instant Retrieval
  -> S3 Glacier Flexible Retrieval
  -> S3 Glacier Deep Archive
```

Transitions to lower tiers are one-way within a lifecycle rule. Objects cannot be transitioned upward via lifecycle (only manually).

### Common Lifecycle Patterns

- **Log retention**: Expire raw logs after 90 days, archive summaries to Glacier Flexible after 1 year
- **Noncurrent version cleanup**: Transition noncurrent versions to Glacier after 30 days; expire after 365 days
- **Abort incomplete multipart uploads**: Expire incomplete uploads after 7 days to avoid storage charges

---

## Replication

### Cross-Region Replication (CRR)

Asynchronously copies objects to a bucket in a **different AWS Region**.

Use cases:
- Geographic redundancy and compliance (data at distance)
- Minimize read latency for globally distributed users
- Compute cluster data locality across regions

Requirements:
- Versioning must be enabled on both source and destination buckets
- IAM role with `s3:ReplicateObject`, `s3:ReplicateDelete`, `s3:ReplicateTags` permissions

### Same-Region Replication (SRR)

Asynchronously copies objects to a bucket in the **same AWS Region**.

Use cases:
- Aggregate logs from multiple source buckets into one
- Separate production and test environments
- Data sovereignty requirements (copies must stay in region)

### S3 Replication Time Control (RTC)

- SLA-backed replication: 99.99% of objects replicated within **15 minutes**
- Applies to both CRR and SRR
- Does NOT apply to Batch Replication
- Emits CloudWatch metrics: `ReplicationLatency`, `BytesPendingReplication`, `OperationsPendingReplication`

### Batch Replication

- On-demand replication of **existing objects** (created before replication rules were configured)
- Use cases: backfill historical objects, retry failed replications, replicate to new destinations
- Executed via S3 Batch Operations job
- Only method to replicate objects that are themselves replicas

### Two-Way (Bi-directional) Replication

- Replica Modification Sync replicates metadata changes (ACLs, tags, locks) back to source
- Supports multi-region active-active architectures
- Used with Multi-Region Access Points for failover

### What Is and Is Not Replicated

**Replicated:**
- Object data, user metadata, version IDs, ACLs, object tags, object locks

**Not replicated by default:**
- Objects created before replication was enabled (use Batch Replication)
- Objects in Glacier (must be restored first)
- Objects in replicas (use Batch Replication)
- Objects encrypted with SSE-C (customer-provided keys)

---

## Event Notifications

S3 can emit events when specific object operations occur.

### Supported Event Types

- `s3:ObjectCreated:*` (Put, Post, Copy, CompleteMultipartUpload)
- `s3:ObjectRemoved:*` (Delete, DeleteMarkerCreated)
- `s3:ObjectRestore:*` (Post, Completed)
- `s3:Replication:*` (OperationFailedReplication, OperationMissedThreshold, etc.)
- `s3:LifecycleExpiration:*`
- `s3:IntelligentTiering`
- `s3:ObjectTagging:*`

### Notification Destinations

- **Amazon SQS** — queue for decoupled processing
- **Amazon SNS** — fan-out to multiple subscribers
- **AWS Lambda** — serverless processing triggered directly
- **Amazon EventBridge** — full event routing with filtering, archival, replay, and cross-account delivery (recommended for new workloads)

EventBridge is the preferred destination for complex event routing, as it supports more event types and richer filtering than native S3 notifications.

---

## Access Points

Access Points simplify managing access to shared datasets in a large S3 bucket by providing a dedicated hostname and policy per consumer.

### Standard Access Points

- Each access point has its own IAM-like policy (up to 20 KB)
- Scope access to a specific prefix or set of object tags
- Can be network-scoped to a specific VPC (restricting access to internal traffic)
- Up to 10,000 access points per account per region
- Hostname: `<name>-<account>.s3-accesspoint.<region>.amazonaws.com`

### Multi-Region Access Points (MRAP)

- Single global hostname routes requests to the lowest-latency replica across multiple regions
- Uses AWS global network (PrivateLink backbone) — up to 60% performance improvement over public internet
- Supports failover routing (active-passive) and active-active patterns
- Maximum 100 MRAPs per account; up to 17 regions per MRAP
- Does not support S3 Batch Operations or gateway VPC endpoints
- Hostname format: `<alias>.mrap.accesspoint.s3-global.amazonaws.com`

---

## S3 Express One Zone (Directory Buckets)

A distinct bucket type optimized for ultra-low latency access:

- **Single-digit millisecond** PUT and GET latency
- Uses **CreateSession** API for session credentials (reduces auth overhead)
- Supports a subset of S3 API operations
- Cannot mix with general purpose bucket storage classes
- Available in select Availability Zones (not all AZs in a region)
- Ideal for: ML training data loading, HPC scratch, real-time analytics, ad tech

---

## S3 Transfer Acceleration

- Uses CloudFront's globally distributed edge locations to accelerate uploads over long geographic distances
- Traffic enters the AWS global network at the nearest edge location, then travels on optimized internal routes to S3
- Endpoint: `<bucket>.s3-accelerate.amazonaws.com`
- Use the Transfer Acceleration Speed Comparison tool to verify improvement before enabling
- Best for: large file uploads from geographically distant clients
- Additional per-GB data transfer charge applies

---

## S3 Select

- SQL-like query engine that filters and retrieves a subset of data from a single object
- Supported formats: CSV, JSON, Parquet (with optional GZIP/BZIP2 compression for CSV and JSON)
- Reduces data transferred from S3 to the application — lower latency and cost
- API: `SelectObjectContent`
- Useful for log analysis, ETL pre-filtering, and ad hoc queries on large objects

---

## S3 Object Lambda

- Intercepts GET, LIST, and HEAD requests and transforms the response in-flight using an AWS Lambda function
- Enables use cases such as: redacting PII, converting data formats, filtering rows/columns, watermarking images
- Architecture: S3 Object Lambda Access Point → Lambda function → standard S3 Access Point → S3 bucket
- Lambda function must be in the same account and region as the Object Lambda Access Point
- 60-second response streaming window
- Maximum 1,000 Object Lambda Access Points per account per region
- As of November 2025, available to existing customers and select APN partners (restricted new enrollment)

---

## S3 Glacier Vault Lock and Object Lock

### S3 Object Lock (General Purpose Buckets)

WORM (Write Once Read Many) model:

- **Governance mode**: Authorized users with `s3:BypassGovernanceRetention` can override; protects against accidental deletion
- **Compliance mode**: No user (including root) can delete or shorten retention period; satisfies strict regulatory requirements
- **Legal Hold**: Indefinite hold independent of retention period; removed only with `s3:PutObjectLegalHold`

Object Lock must be enabled at bucket creation and requires versioning to be enabled.
