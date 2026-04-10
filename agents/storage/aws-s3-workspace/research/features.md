# AWS S3 Features

## Core Capabilities

### Storage and Object Management

**S3 Versioning**
- Preserves all versions of every object in a bucket
- Enables recovery from accidental deletions and overwrites
- Delete markers allow soft-delete semantics
- MFA Delete can require multi-factor authentication for permanent deletions

**S3 Object Lock (WORM)**
- Write-once-read-many enforcement at the object level
- Governance mode: Authorized users can override with special permission
- Compliance mode: Immutable — no one can delete during retention period
- Legal Hold: Independent, indefinite protection
- Required for SEC 17a-4, CFTC, FINRA, and HIPAA compliance scenarios

**S3 Batch Operations**
- Perform actions on billions of objects with a single API request
- Supported operations: Copy, Invoke Lambda, Restore (Glacier), Replace ACL, Replace Tags, Delete, Object Lock
- Tracks progress, generates completion reports, sends event notifications
- Used in conjunction with S3 Inventory for large-scale management tasks

**S3 Inventory**
- Scheduled reports (daily or weekly) listing objects and their metadata
- Metadata fields: ETag, size, last modified, storage class, encryption status, replication status, Object Lock status
- Output formats: CSV, ORC, Parquet
- Can be queried with S3 Select or Amazon Athena

**S3 Lifecycle**
- Automated transition between storage classes based on age, prefix, or tags
- Expiration actions to delete objects or delete markers
- Incomplete multipart upload cleanup rules

---

## Recent and Notable Features

### S3 Express One Zone (GA: November 2023, Price Reductions: 2026)

- High-performance **directory bucket** type with single-digit millisecond latency
- Up to 10x faster access than S3 Standard
- Request costs 80–85% lower than S3 Standard (POST: 85% lower, GET: major reduction)
- Storage price cut 31% in early 2026
- Uses `CreateSession` for session-based authentication (reduces per-request signing overhead)
- Supports: PutObject, GetObject, DeleteObject, ListObjectsV2, HeadObject, CopyObject (within same AZ)
- Does not support: Object Lock, WORM, lifecycle transitions, S3 Replication (standard), most encryption modes except SSE-S3 and SSE-KMS
- Mountpoint for S3 supports Express One Zone

### S3 Tables (GA: December 2024, Updates through 2025)

- First cloud object store with **built-in Apache Iceberg support**
- Uses a new bucket type: **table buckets** (distinct from general purpose and directory buckets)
- Up to 3x faster query throughput and 10x higher transactions per second vs self-managed Iceberg tables
- Automatic table maintenance: compaction, snapshot management, unreferenced file removal
- Supports standard SQL via Athena, Amazon Redshift, EMR, and SageMaker Lakehouse
- **Apache Iceberg REST Catalog API support** (added March 2025): any Iceberg-compatible tool can create, update, list, and delete tables
- **Automatic cross-region/cross-account replication** (added December 2025): replicates complete table structure including all snapshots and metadata
- **Apache Iceberg V3 support**: row-level deletes, binary type, nanosecond timestamps
- Available in: US East (N. Virginia), US East (Ohio), US West (Oregon), expanding to more regions
- Integrates with S3 Storage Lens for table-level cost attribution (mid-2025)

### Mountpoint for S3

- Open-source, high-performance file client that mounts an S3 bucket as a local filesystem
- Translates POSIX file operations (open, read, write, stat, readdir) into S3 API calls
- Written in Rust; available on Linux (via FUSE) and in Amazon EKS
- Optimized for sequential read-heavy workloads (ML training, analytics, media streaming)
- Write support: sequential writes from a single client; no random writes or appends
- Supports S3 Standard, S3 Express One Zone (directory buckets), S3 Intelligent-Tiering
- Does not support: random writes, file locking, append, extended attributes (xattr)
- AWS-maintained with regular performance improvements

### S3 Access Grants

- Maps corporate identities (Active Directory, IAM principals, SSO users) to specific S3 datasets
- Enables fine-grained, identity-aware access control without managing complex bucket policies
- Logs end-user identity and application in AWS CloudTrail for full audit trail to the individual user
- Supports prefix-level grants: grant access to `s3://my-bucket/dept-a/` for group A
- Works with AWS IAM Identity Center (SSO), Active Directory, and IAM
- Scales to millions of grants across thousands of users
- Enables data mesh architectures with clear data ownership boundaries

### S3 Metadata (Preview/New)

- Queryable object metadata in near real-time
- Enables data organization and discovery without scanning bucket contents
- Supports custom metadata attributes alongside system metadata
- Query via SQL-compatible interface

---

## Access and Network Features

### Standard Access Points

- Dedicated hostnames with scoped policies for shared bucket access
- VPC-restricted access points: limit to internal network traffic only
- Up to 10,000 access points per account per region
- Simplify bucket policies for multi-team, multi-application access patterns

### Multi-Region Access Points (MRAP)

- Single global hostname that routes to the lowest-latency bucket replica
- Uses AWS global network backbone (PrivateLink) — up to 60% performance improvement vs public internet
- Active-active and active-passive failover configurations
- Failover routing with health-check-based traffic shifting
- Maximum 100 MRAPs per account; up to 17 regions per MRAP

### S3 Transfer Acceleration

- Accelerates uploads via CloudFront edge locations → AWS global network → S3
- Benefits users uploading from distant geographic locations
- Endpoint: `<bucket>.s3-accelerate.amazonaws.com`
- Speed Comparison tool available to verify improvement before enabling
- Per-GB surcharge on accelerated transfers

### VPC Endpoints for S3

- **Gateway endpoints**: Free; route S3 traffic within the AWS network, configured in route tables
- **Interface endpoints (PrivateLink)**: Hourly cost; private IP in VPC, supports DNS resolution from on-premises
- Prevent data from traversing the public internet
- Enforce via bucket policies with `aws:SourceVpc` or `aws:SourceVpce` condition keys

---

## Data Processing Features

### S3 Select

- Filter and retrieve a subset of data from a CSV, JSON, or Parquet object using SQL expressions
- Reduces data transfer from S3 to application — only matching rows/columns returned
- Supports GZIP and BZIP2 compression for CSV and JSON
- API: `SelectObjectContent`
- Use case: Log analysis, pre-filtering before ETL, ad hoc queries on large objects

### S3 Object Lambda

- Transforms objects in-flight during GET, LIST, or HEAD requests using Lambda functions
- No need to store transformed copies — transformation happens at read time
- Architecture: Object Lambda Access Point → Lambda function → Standard Access Point → S3
- Common use cases:
  - Redact PII (SSNs, emails) before returning to downstream services
  - Convert file formats (XML → JSON, CSV → Parquet) on the fly
  - Resize or watermark images dynamically
  - Filter rows/columns for different audience segments
- Lambda function timeout: 60 seconds for response streaming
- Available to existing customers and select APN partners (new enrollment restricted as of Nov 2025)

### S3 Batch Operations

- Run bulk operations against billions of S3 objects
- Supports: Copy, Lambda invocation, Restore from Glacier, Tag modification, ACL modification, Object Lock changes
- Can source object list from S3 Inventory report or custom CSV manifest
- Tracks progress, sends CloudWatch metrics, generates completion report to S3
- Invoke Lambda: process each object through a custom function (redact, transform, validate)

---

## Security and Compliance Features

### Block Public Access

- Account-level and bucket-level controls
- Four independent settings that can be combined:
  - BlockPublicAcls
  - IgnorePublicAcls
  - BlockPublicPolicy
  - RestrictPublicBuckets
- Enabled by default for all new buckets and new accounts
- Organization-level enforcement via SCP

### Default Encryption

- All new objects uploaded to any bucket are automatically encrypted at rest
- Default: SSE-S3 (AES-256, S3-managed keys)
- Can be changed to SSE-KMS or DSSE-KMS per bucket
- SSE-C (customer-provided keys) **disabled by default** for all new general purpose buckets as of April 6, 2026 (response to Codefinger ransomware campaign in January 2025)

### S3 Object Lock

- WORM enforcement (see Architecture section for detail)
- Governance and Compliance modes
- Legal Hold for indefinite protection

### IAM Access Analyzer for S3

- Identifies buckets exposed to external entities
- Generates access findings for bucket policies, ACLs, and access points
- Validates IAM policies against best practices
- Can generate policies from CloudTrail activity

### Amazon Macie

- Discovers sensitive data (PII, financial data, credentials) in S3 using ML and pattern matching
- Generates findings with details about affected objects
- Supports custom regular expression patterns for domain-specific sensitive data

### Amazon GuardDuty S3 Protection

- Continuous threat detection using CloudTrail data events and management events
- Detects anomalous access patterns, credential misuse, and policy violations
- Generates security findings for investigation and remediation

---

## Observability and Analytics Features

### S3 Storage Lens

- Organization-wide visibility across thousands of accounts and regions
- Free tier: 28 usage and activity metrics, 14-day data retention
- Advanced tier: 35+ additional metrics (activity, cost optimization, data protection, performance, status codes), 15-month retention, CloudWatch integration, prefix-level insights
- Exports metrics to S3 (CSV or Parquet) or CloudWatch
- Provides actionable recommendations (e.g., buckets without lifecycle rules, missing replication)
- **Performance metrics added in 2025**: request latency, error rates per prefix
- **S3 Tables export support (2025)**: export Storage Lens metrics directly to S3 table buckets for advanced analytics
- **Prefix-level support for billions of prefixes (2025)**

### S3 Inventory

- Scheduled object listing with metadata export
- Useful for auditing encryption status, replication status, versioning, and Object Lock retention dates
- Output to S3 for querying with Athena or S3 Select

### Server Access Logging

- Detailed log of all requests to a bucket
- Fields: requester, bucket, request time, request action, response status, error code
- Delivered to a target bucket (best-effort; not real-time)
- Used for security audits, billing analysis, and understanding access patterns

---

## Data Durability and Availability Features

### S3 Replication

- CRR, SRR, Batch Replication, Two-Way Replication, S3 RTC (see Architecture for full detail)

### S3 Intelligent-Tiering

- Automatic cost optimization for data with unknown or changing access patterns
- No retrieval fees; small monthly monitoring fee per object (free for objects < 128 KB)
- Optional Archive and Deep Archive tiers for additional savings

### Multi-Region Access Points with Failover

- Active-passive failover: designate a primary and failover bucket; MRAP routes all traffic to primary, fails over on health check failure
- Active-active: route traffic to closest copy for reads; writes replicated via CRR

---

## Pricing Model Summary (2026)

| Component | Notes |
|---|---|
| Storage | Per GB-month, varies by storage class |
| Requests | PUT/COPY/POST/LIST vs GET/SELECT/HEAD rates differ |
| Data Transfer Out | Free within same region; charges for internet and cross-region |
| Transfer Acceleration | Additional per-GB charge on accelerated transfers |
| Lifecycle Transitions | Per 1,000 transition requests |
| Glacier Retrievals | Per GB for Flexible Retrieval and Deep Archive |
| Replication | Data transfer charges apply for cross-region replication |
| S3 Storage Lens Advanced | Per-object monitoring charge |
| Intelligent-Tiering Monitoring | Per 1,000 objects monitored per month |
