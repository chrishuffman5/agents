# AWS S3 Best Practices

## Bucket Naming

### Rules and Conventions

- 3–63 characters; lowercase letters, numbers, hyphens only
- Must start and end with a letter or number (not a hyphen)
- Cannot be formatted as an IP address (e.g., `192.168.1.1`)
- Cannot begin with `xn--`, `sthree-`, or end with `-s3alias` or `--ol-s3` (reserved patterns)
- Globally unique across all AWS accounts and all regions

### Naming Strategy

- Use a consistent naming scheme: `<org>-<env>-<purpose>-<region>` (e.g., `acme-prod-logs-us-east-1`)
- Avoid embedding sensitive information in bucket names (names appear in URLs and logs)
- Do not use dots (`.`) in bucket names if you intend to use virtual-hosted-style URLs and SSL — wildcard certificates do not cover dot-separated names
- Use account-regional namespace buckets (available in newer accounts) to protect against name reuse after bucket deletion

### Account Regional Namespace

- Newer AWS accounts default to regional namespace for new buckets
- Prevents other accounts from recreating a bucket with the same name after you delete it
- Recommendation: Avoid deleting global namespace buckets; prefer emptying and retaining them

---

## Security Hardening

### 1. Enable Block Public Access Everywhere

Enable all four Block Public Access settings at the **account level** in addition to each bucket:

```
BlockPublicAcls: true
IgnorePublicAcls: true
BlockPublicPolicy: true
RestrictPublicBuckets: true
```

Enforce at the organization level via Service Control Policies (SCPs) and AWS Config rules:
- `s3-bucket-public-read-prohibited`
- `s3-bucket-public-write-prohibited`

### 2. Disable ACLs (Bucket Owner Enforced)

Set Object Ownership to **Bucket Owner Enforced** on all buckets:
- Disables ACLs entirely; all access controlled via IAM and bucket policies
- Default for new buckets created after April 2023
- Simplifies permission auditing and removes the risk of object-level ACL misconfigurations

### 3. Apply Least-Privilege IAM Policies

- Grant the minimum set of S3 actions required per role or user
- Avoid wildcard actions (`s3:*`) in production policies
- Use IAM policy conditions to scope by prefix, tag, or VPC:

```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject"],
  "Resource": "arn:aws:s3:::my-bucket/dept-a/*",
  "Condition": {
    "StringEquals": {
      "aws:PrincipalTag/Department": "dept-a"
    }
  }
}
```

- Use IAM Roles (not IAM Users with long-term keys) for applications, EC2 instances, Lambda functions

### 4. Enforce HTTPS (TLS) in Transit

Add a Deny policy for non-TLS requests to every bucket:

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::bucket-name",
    "arn:aws:s3:::bucket-name/*"
  ],
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```

- Do not pin S3 TLS certificates (AWS rotates them automatically)
- AWS Config rule: `s3-bucket-ssl-requests-only`
- Set CloudWatch alarms on requests missing `tlsDetails.tlsVersion`

### 5. Encryption Strategy

**At Rest — Choose the right encryption mode:**

| Mode | Key Management | Use Case |
|---|---|---|
| SSE-S3 (default) | S3 manages keys | General workloads; simplest |
| SSE-KMS | AWS KMS CMK | Audit key usage, cross-account access, FIPS compliance |
| DSSE-KMS | Dual-layer KMS | Highest compliance requirements (DoD, IC) |
| SSE-C | Customer provides key | Avoid — disabled by default for new buckets as of April 2026 |

**SSE-KMS Best Practices:**
- Use a dedicated KMS key per bucket or per data classification tier (not the AWS-managed default `aws/s3` key)
- Enable KMS key rotation (annual automatic rotation)
- Restrict key policy: only specific roles/accounts can use `kms:GenerateDataKey` and `kms:Decrypt`
- Monitor KMS API calls via CloudTrail — high call volumes may indicate unexpected access or runaway processes
- Be aware of KMS request rate limits (default 5,500–30,000 RPS depending on region) — can throttle high-throughput S3 workloads

**Deny SSE-C via bucket policy (for existing buckets not yet updated to new defaults):**

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:PutObject",
  "Resource": "arn:aws:s3:::bucket-name/*",
  "Condition": {
    "Null": {
      "s3:x-amz-server-side-encryption-customer-algorithm": "false"
    }
  }
}
```

### 6. Enable MFA Delete

- Requires MFA for permanent object deletion and suspending versioning
- Must be enabled by the bucket owner using the root account credentials via CLI
- Protects against credential compromise leading to mass deletion

### 7. Use VPC Endpoints

- **Gateway endpoint**: Free; configure in VPC route table; works for S3 traffic from within VPC
- **Interface endpoint (PrivateLink)**: Paid; enables access from on-premises via Direct Connect or VPN; supports DNS
- Enforce VPC-only access via bucket policy condition:

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": ["arn:aws:s3:::bucket-name", "arn:aws:s3:::bucket-name/*"],
  "Condition": {
    "StringNotEquals": {
      "aws:SourceVpc": "vpc-xxxxxxxx"
    }
  }
}
```

### 8. Enable GuardDuty S3 Protection

- Continuously monitors CloudTrail data events for anomalous S3 access
- Detects: unusual access patterns, known malicious IPs, exfiltration indicators
- Free tier covers management events; data events require paid tier

### 9. Enable Amazon Macie

- Automatically discovers PII, credentials, and financial data in S3
- Run periodic discovery scans on new data landing buckets
- Set up findings integration with Security Hub for centralized alerting

### 10. Enable IAM Access Analyzer for S3

- Continuously evaluates bucket policies, ACLs, and access points for unintended external sharing
- Archive findings for confirmed intentional sharing; act on unexpected external access findings

---

## Lifecycle Policies

### Key Lifecycle Design Principles

1. **Always add an incomplete multipart upload expiration rule** to every bucket:
   ```
   Days after initiation: 7
   ```
   Abandoned multipart uploads consume storage and generate charges without being visible in normal object listings.

2. **Match transition timing to actual access patterns** — use S3 Storage Lens access frequency metrics or S3 Analytics (per-prefix access analysis) before setting transition thresholds.

3. **Set noncurrent version expiration** on versioning-enabled buckets to prevent unbounded version accumulation:
   - Transition noncurrent versions to Glacier Flexible after 30 days
   - Expire noncurrent versions after 365 days

4. **Minimum storage duration costs**: Objects transitioned or deleted before minimum duration are still charged the full minimum. Plan transitions to avoid unintended early-deletion charges:
   - Standard-IA / One Zone-IA: 30 days
   - Glacier Instant / Flexible: 90 days
   - Glacier Deep Archive: 180 days

5. **Use S3 Intelligent-Tiering** instead of manual lifecycle for data with unpredictable access patterns — eliminates retrieval fees and automates tiering.

### Example Lifecycle Policy Pattern (Log Data)

```
Rule: raw-logs-lifecycle
Filter: Prefix = "logs/raw/"
Transitions:
  - 30 days -> S3 Standard-IA
  - 90 days -> S3 Glacier Flexible Retrieval
  - 365 days -> S3 Glacier Deep Archive
Expiration:
  - 2555 days (7 years) -> Delete
Noncurrent versions:
  - 30 days -> S3 Glacier Flexible Retrieval
  - 90 days -> Expire

Rule: incomplete-mpu-cleanup
Filter: (entire bucket)
AbortIncompleteMultipartUpload: 7 days
```

---

## Cost Optimization

### 1. Right-Size Storage Classes

- Analyze access patterns with **S3 Storage Lens** (free tier shows request metrics) and **S3 Analytics** (per-prefix storage class analysis)
- Move infrequently accessed data (less than once per month) to Standard-IA
- Archive data accessed once per quarter or less to Glacier Instant Retrieval
- Use Deep Archive for regulatory data you expect to never retrieve

### 2. Control Data Transfer Costs

- Data transfer **within the same AWS Region** between S3 and EC2/Lambda is free
- Data transfer **across regions** incurs per-GB charges — replicate data regionally if access patterns justify it
- Use **VPC Gateway Endpoints** (free) to eliminate NAT Gateway data processing charges for S3 traffic
- Avoid unnecessary `GetObject` calls — use S3 Select to retrieve only needed data

### 3. Clean Up Waste

- **Incomplete multipart uploads**: Enable lifecycle expiration rule for AbortIncompleteMultipartUpload (7 days recommended)
- **Old versions**: Set noncurrent version expiration on all versioning-enabled buckets
- **Expired delete markers**: Enable delete marker expiration in lifecycle rules
- Use S3 Storage Lens cost optimization recommendations to identify buckets lacking these rules

### 4. Use S3 Intelligent-Tiering for Uncertain Access

- No retrieval fee; small per-object monitoring fee (free for objects < 128 KB)
- Automatically moves objects to lower-cost tiers after inactivity
- Enables optional Archive and Deep Archive tiers for maximum savings

### 5. Analyze with S3 Storage Lens and Cost Explorer

- S3 Storage Lens: identify top buckets by storage size, request activity, and cost-optimization gaps
- AWS Cost Explorer with S3 cost dimension: break down charges by bucket, storage class, operation type
- S3 Tables export (2025): export Storage Lens metrics to Iceberg tables for SQL-based cost analysis

### 6. Reduce Request Costs for High-Throughput Workloads

- Use **S3 Express One Zone** for latency-sensitive, high-request-rate workloads (85% lower PUT costs vs Standard)
- Batch small objects and upload with multipart for large files
- Use **byte-range fetches** to read only required portions of large objects

---

## Performance Patterns

### Request Rate Scaling

- S3 automatically scales to handle high request rates per prefix
- Baseline: **3,500 PUT/COPY/POST/DELETE** and **5,500 GET/HEAD** requests per second per prefix
- No limit on number of prefixes — distribute load across many prefixes to multiply effective throughput

### Prefix Design for High Throughput

- Avoid sequential prefixes for high-throughput workloads (e.g., date-based keys like `2026/01/01/...` concentrate requests)
- Use hash-prefixed keys: `a3f2/2026-01-01-logfile.gz` spreads load across partitions
- For read-heavy workloads with random reads, randomized or UUID-based prefixes improve partition distribution

### Multipart Upload

- Use multipart upload for objects **larger than 100 MB**
- AWS recommends part size of **8–128 MB** for optimal performance
- Enables parallel upload of parts, resumable uploads, and single-object atomic completion
- Clean up failed multipart uploads via lifecycle `AbortIncompleteMultipartUpload` rule
- S3 SDKs (AWS CRT-based: CLI v2, Boto3, Java SDK 2.x) automatically use multipart for large objects

### Byte-Range Fetches

- Download large objects in parallel by requesting multiple byte ranges concurrently
- Typical range size: 8–16 MB per concurrent request
- Aligning ranges to original multipart upload part boundaries improves performance
- Enables resumable downloads and parallel streaming pipelines

### AWS Common Runtime (CRT) SDKs

- AWS CLI v2, Boto3, and Java SDK 2.x include CRT support
- CRT provides: parallel connections, intelligent retry with backoff, multipart upload/download, efficient memory management
- Significantly higher throughput than legacy SDK implementations for large file transfers

### S3 Transfer Acceleration

- Use for large file uploads from clients far from the S3 region
- Measure improvement with the AWS Transfer Acceleration Speed Comparison tool before enabling
- Beneficial for uploads from Europe, Asia-Pacific to US regions (or vice versa)

### Caching

- Use **CloudFront** in front of S3 for read-heavy, globally distributed workloads
- Origin Access Control (OAC) restricts S3 bucket to CloudFront-only access (preferred over legacy OAI)
- S3 Express One Zone can serve as a high-speed origin cache layer for ML/HPC workloads

---

## Encryption Strategy (Summary)

| Scenario | Recommended Approach |
|---|---|
| General workloads | SSE-S3 (default, zero overhead) |
| Audit key usage or cross-account sharing | SSE-KMS with dedicated CMK |
| Highest compliance requirements | DSSE-KMS |
| Data already encrypted before upload | Client-side encryption (manage your own keys) |
| Avoid | SSE-C (disabled by default as of April 2026) |

Always combine encryption at rest with:
- Enforce TLS in transit via bucket policy
- KMS key rotation enabled
- CloudTrail logging of KMS API calls

---

## Logging and Monitoring

### Server Access Logging

- Enable on all buckets containing sensitive or production data
- Write logs to a **separate dedicated logging bucket** (not the same bucket being logged — avoids log loops)
- Set a lifecycle rule on the logging bucket to expire old logs (e.g., 90 days)
- Note: Delivery is best-effort, not guaranteed real-time

### CloudTrail Data Events

- S3 server access logs capture HTTP-level request details; CloudTrail captures API-level events with IAM identity
- Enable CloudTrail data events for S3 to capture `GetObject`, `PutObject`, `DeleteObject` with requester identity
- Store CloudTrail logs in a separate, locked S3 bucket with Object Lock (compliance mode) to prevent tampering
- AWS Config rule: `cloudtrail-s3-dataevents-enabled`

### CloudWatch Request Metrics

- Enable S3 request metrics for production buckets to get 1-minute granularity
- Key metrics: `4xxErrors`, `5xxErrors`, `FirstByteLatency`, `TotalRequestLatency`, `BytesDownloaded`, `BytesUploaded`
- Set alarms on `4xxErrors` spike (permission issues), `5xxErrors` spike (throttling), and `FirstByteLatency` threshold

### S3 Storage Lens

- Enable organization-level dashboard for cost, activity, and data protection visibility
- Upgrade to advanced metrics for prefix-level insights and CloudWatch integration
- Review weekly: identify top cost buckets, buckets without lifecycle rules, replication gaps

### AWS Config

- Enable S3-related Config rules for continuous compliance monitoring:
  - `s3-bucket-public-read-prohibited`
  - `s3-bucket-public-write-prohibited`
  - `s3-bucket-ssl-requests-only`
  - `s3-bucket-versioning-enabled`
  - `s3-bucket-replication-enabled`
  - `s3-bucket-logging-enabled`
  - `s3-default-encryption-kms`
- Config does not support directory buckets (S3 Express One Zone)
