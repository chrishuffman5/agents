# Google Cloud Storage Architecture

## Buckets

Global namespace (unique across all GCP). Immutable creation location. No nesting. Every bucket belongs to one GCP project. Create/delete rate: ~1 per 2 seconds per project.

**Hierarchical Namespace (HNS):** True directory semantics (atomic rename/move). Up to 8x higher initial QPS vs flat namespace. Autoclass supported on HNS buckets.

## Objects

Object data (up to 5 TiB) + metadata (system + custom, up to 8 KiB) + name (up to 1,024 bytes). Objects are immutable; updates create new versions.

**Object Contexts (GA April 2026):** Key-value pairs for categorization, search, batch operations.

**Compose Objects:** Combine up to 32 objects server-side in one API call. No re-upload. Chain up to 1,024 parts.

## Storage Classes

### Rapid (GA March 2026)

Zonal buckets only. AI/ML, analytics. 99.9% availability. Subject to zonal storage quotas. Up to 1 Tbps egress to Google services.

### Standard

Default class. 99.95% (multi/dual-region), 99.9% (regional). No minimum duration. No retrieval fees.

### Nearline

~1 access/month. 30-day minimum. Per-GB retrieval fee.

### Coldline

Quarterly access. 90-day minimum. Higher retrieval fee.

### Archive

< 1 access/year. 365-day minimum. Highest retrieval fee. Millisecond access (no thaw delay).

All classes: 99.999999999% (11 nines) durability.

## Autoclass

Per-object automatic tiering. Objects start Standard. 30d inactivity -> Nearline. Optional: 90d -> Coldline, 365d -> Archive. Any GET -> back to Standard. Objects < 128 KiB always Standard. No retrieval/early deletion fees within Autoclass.

Terminal class options: NEARLINE (default) or ARCHIVE (Standard -> Nearline -> Coldline -> Archive).

## Bucket Locations

**Regional:** Single region, data redundant across zones within region.

**Dual-region:** Two paired regions. Default RPO: 1h for 99.9%. Turbo Replication: 15-min RPO SLA (`--rpo=ASYNC_TURBO`).

**Multi-region:** US/EU/ASIA. Automatic geo-redundancy. 99.95% availability.

## Lifecycle Management

Rules with one action + conditions. Actions: Delete, SetStorageClass, AbortIncompleteMultipartUpload.

Conditions: `age`, `createdBefore`, `isLive`, `numNewerVersions`, `matchesStorageClass`, `matchesPrefix`/`matchesSuffix` (up to 1,000 combined).

Age 0 = satisfied at midnight UTC after creation (since Oct 31, 2025). Actions execute asynchronously.

## Object Versioning

Each write preserves previous version as noncurrent with unique generation number. Deleting live object inserts noncurrent version. Use lifecycle rules with `numNewerVersions` or `isLive: false` to manage accumulation.

## Retention Policies

Prevents deletion/replacement until retention period expires. Locked policy: cannot be removed or shortened. Object holds: event-based and temporary for individual objects.

## Soft Delete

Deleted objects retained for configurable period (default 7 days). Enhanced restoration by creation time (January 2026). Reduce window on high-churn buckets.

## Signed URLs

V4 signing (HMAC-SHA256, max 7 days). Sign via service account key or IAM `signBlob` API. Supports GET, PUT, DELETE. Never include Authorization header with signed URLs.

## IAM and ACLs

**Uniform bucket-level access (recommended):** IAM-only, disables ACLs. Enables managed folders, IAM Conditions, VPC Service Controls. Irreversible after 90 days.

Key roles: `storage.admin`, `storage.objectAdmin`, `storage.objectCreator`, `storage.objectViewer`.

IAM Conditions for attribute-based access (prefix, time, IP). Max 1,500 principals per bucket.

**Public Access Prevention:** Org policy blocks allUsers/allAuthenticatedUsers.

## HMAC Keys

S3-compatible auth for XML API. Associate with service accounts. Access ID (public) + Secret (shown once). States: ACTIVE/INACTIVE. Restrict via `constraints/storage.restrictAuthTypes`.

## Pub/Sub Notifications

Events: OBJECT_FINALIZE, OBJECT_METADATA_UPDATE, OBJECT_DELETE, OBJECT_ARCHIVE. Up to 100 configs per bucket. Filter by prefix. Object change notification (legacy) deprecated Jan 30, 2026.

## JSON and XML APIs

**JSON API:** RESTful, full feature support, preferred. Resumable/multipart/single-part uploads.

**XML API:** S3-compatible. Multi-object Delete (up to 1,000) GA April 8, 2026.

**Regional endpoints:** `https://storage.{region}.rep.googleapis.com/` for data locality.

## Storage Transfer Service

Managed transfers from S3, Azure Blob, HTTP/HTTPS, on-premises (agents), between GCS buckets. Scheduled/one-time, prefix/time filters, bandwidth throttling, integrity verification.

## Batch Operations

Server-side bulk processing: delete, copy, rewrite class, replace ACL/metadata, restore soft-deleted, invoke Cloud Function. Dry run mode (GA Jan 2026). Object Contexts support (GA April 2026).

## Storage Insights

BigQuery-queryable inventory snapshots. New fields (March 2026): encryption, retentionPeriod, encryptionType.
