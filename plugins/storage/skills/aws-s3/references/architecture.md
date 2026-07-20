# AWS S3 Architecture

## Bucket / Object Model

- **Bucket**: Globally unique name, single region, up to 10,000 per account (with quota increase)
- **Object**: Data + metadata + key + version ID. Max 5 TB. No filesystem hierarchy.
- **Durability**: 11 nines across >= 3 AZs (Standard). Express One Zone: single AZ.

## Storage Classes

| Class | Availability | Min Storage | Retrieval | AZs |
|---|---|---|---|---|
| Standard | 99.99% | None | ms | >= 3 |
| Express One Zone | 99.95% | None | Sub-ms | 1 |
| Standard-IA | 99.9% | 30 days | ms | >= 3 |
| One Zone-IA | 99.5% | 30 days | ms | 1 |
| Intelligent-Tiering | 99.9% | None | Varies | >= 3 |
| Glacier Instant Retrieval | 99.9% | 90 days | ms | >= 3 |
| Glacier Flexible Retrieval | 99.99%* | 90 days | 1-12 hours | >= 3 |
| Glacier Deep Archive | 99.99%* | 180 days | 12-48 hours | >= 3 |

**Intelligent-Tiering tiers:** Frequent (default) -> Infrequent (30 days) -> Archive Instant (90 days) -> optional Archive (90+ days) -> optional Deep Archive (180+ days). Objects < 128 KB always Frequent.

**Express One Zone:** Directory bucket type, CreateSession API, up to 10x faster than Standard, 80-85% lower request costs (2026).

## Versioning

States: Unversioned (default), Enabled, Suspended. Once enabled, cannot fully disable. Deletion creates delete markers. Permanent deletion requires version ID. Required for replication and MFA Delete.

## Lifecycle Policies

Rule components: Filter (prefix/tag/size), Transition actions, Expiration actions, Noncurrent version actions, Incomplete multipart upload expiration.

Transition waterfall: Standard -> Standard-IA -> Intelligent-Tiering -> One Zone-IA -> Glacier Instant -> Glacier Flexible -> Deep Archive. One-way.

## Replication

**CRR:** Async cross-region. Requires versioning on both buckets. **SRR:** Same-region. **S3 RTC:** 99.99% within 15 minutes. **Batch Replication:** Existing objects. **Bi-directional:** Replica Modification Sync for active-active.

Not replicated by default: pre-existing objects, Glacier objects, SSE-C objects.

## Event Notifications

Events: ObjectCreated, ObjectRemoved, ObjectRestore, Replication, LifecycleExpiration, IntelligentTiering, ObjectTagging.

Destinations: SQS, SNS, Lambda, EventBridge (recommended for new workloads).

## Access Points

Standard access points: per-consumer hostname and policy, VPC-scoped, up to 10,000/region.

Multi-Region Access Points (MRAP): single global hostname routing to lowest-latency replica. Up to 17 regions per MRAP. Supports active-active and failover.

## S3 Express One Zone (Directory Buckets)

Single-digit ms latency, CreateSession API, subset of S3 operations, cannot mix with general purpose bucket classes. Ideal for ML training, HPC, real-time analytics.

## S3 Transfer Acceleration

Uses CloudFront edge locations. Endpoint: `<bucket>.s3-accelerate.amazonaws.com`. Best for large uploads from distant clients.

## S3 Select

SQL-like query filtering on CSV/JSON/Parquet objects. Reduces data transfer. API: `SelectObjectContent`.

## S3 Object Lambda

Transforms objects in-flight during GET/LIST/HEAD via Lambda function. Use cases: PII redaction, format conversion, image watermarking. 60-second timeout.

## S3 Object Lock (WORM)

Governance mode: authorized users can override. Compliance mode: no one can delete/shorten retention. Legal Hold: indefinite. Must be enabled at bucket creation with versioning.

## S3 Tables

Built-in Apache Iceberg support in table buckets. 3x faster queries, 10x higher TPS vs self-managed. Automatic compaction and maintenance. Iceberg REST Catalog API. Cross-region replication. V3 support (row-level deletes, nanosecond timestamps).

## S3 Batch Operations

Bulk operations on billions of objects: Copy, Lambda, Restore, Replace ACL/Tags, Delete, Object Lock. Sources from S3 Inventory or CSV manifest.

## S3 Inventory

Scheduled reports (daily/weekly) of objects and metadata: ETag, size, storage class, encryption, replication, lock status. CSV/ORC/Parquet output.
