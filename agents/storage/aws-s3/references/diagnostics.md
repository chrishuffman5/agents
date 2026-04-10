# AWS S3 Diagnostics

## Access Denied (403) Troubleshooting

### Policy Evaluation Order

1. Explicit Deny wins everywhere
2. Bucket policy + IAM policy must both allow (cross-account: bucket policy suffices)
3. Block Public Access overrides public grants
4. ACLs evaluated if enabled
5. VPC endpoint policy must allow

### Step-by-Step

1. **Identify requester** via CloudTrail (`AccessDenied` events)
2. **Simulate policy**: `aws iam simulate-principal-policy --action-names s3:GetObject`
3. **Check bucket policy**: `aws s3api get-bucket-policy --bucket my-bucket`
4. **Check Block Public Access**: account and bucket level
5. **Check Object Ownership**: `aws s3api get-bucket-ownership-controls`
6. **Check KMS key access**: `kms:Decrypt` / `kms:GenerateDataKey`
7. **Check Access Points**: bucket policy must delegate, access point policy must allow

### Common Causes

| Symptom | Cause | Fix |
|---|---|---|
| 403 cross-account | Missing bucket policy grant | Add cross-account Allow |
| 403 despite IAM Allow | Explicit Deny in bucket policy/SCP | Review deny statements |
| 403 with KMS | Key policy missing requester | Grant KMS permissions |
| 403 from VPC | Endpoint policy restricts | Update endpoint policy |
| 403 on SSE-C | Disabled by default April 2026 | Re-encrypt with SSE-S3/KMS |

## Slow Transfer Troubleshooting

1. **Check FirstByteLatency** (CloudWatch) -- high = S3-side issue
2. **Verify multipart upload** for objects > 100 MB
3. **Check prefix distribution** -- sequential prefixes cause hot spots
4. **Test Transfer Acceleration** for distant uploads
5. **Check network path** -- same-region EC2 should get near line rate

| Symptom | Fix |
|---|---|
| Slow large uploads from on-prem | Multipart upload with CRT SDK |
| Slow large downloads | Byte-range fetch with parallel threads |
| Specific prefix slowness | Randomize prefixes |
| 503 Slow Down | Add prefixes + exponential backoff |
| High latency from VPC | Use S3 Gateway VPC Endpoint (free) |

## Replication Lag

### Key Metrics (CloudWatch)

`ReplicationLatency`, `BytesPendingReplication`, `OperationsPendingReplication`, `OperationsFailedReplication`, `OperationsMissedThreshold`.

### Diagnosis

1. Check object status: `aws s3api head-object --query ReplicationStatus` (PENDING/COMPLETED/FAILED/REPLICA)
2. Check config: `aws s3api get-bucket-replication`
3. Find FAILED objects via S3 Inventory or retry with Batch Replication

### Common Issues

| Symptom | Fix |
|---|---|
| PENDING stuck | Fix IAM role permissions |
| FAILED (no versioning) | Enable versioning on destination |
| FAILED (KMS) | Grant kms:ReplicateKey on destination |
| Pre-existing not replicated | Use S3 Batch Replication |
| Delete markers not replicating | Enable DeleteMarkerReplication |

## Cost Analysis

1. **Cost Explorer**: Filter by S3, group by Usage Type (DataTransfer, Requests, TimedStorage)
2. **Storage Lens (free)**: Top buckets, incomplete multipart bytes, noncurrent version bytes
3. **Identify waste**: Buckets without lifecycle rules, large noncurrent storage, abandoned uploads
4. **Retrieval cost spikes**: Glacier retrievals in Cost Explorer (prefer Bulk over Expedited)
5. **Data transfer**: NAT Gateway S3 traffic -> switch to Gateway VPC endpoint

### Cost Checklist

- [ ] All buckets have AbortIncompleteMultipartUpload (7 days)
- [ ] Versioned buckets have noncurrent version expiration
- [ ] Storage class matches access patterns (verify with Storage Lens)
- [ ] VPC Gateway endpoints deployed
- [ ] CloudFront for read-heavy public data
- [ ] Intelligent-Tiering evaluated for variable access

## CloudWatch Metrics

### Storage (Free, Daily)

`BucketSizeBytes`, `NumberOfObjects`. Dimensions: BucketName, StorageType.

### Request (Paid, 1-Minute)

`AllRequests`, `GetRequests`, `PutRequests`, `4xxErrors`, `5xxErrors`, `FirstByteLatency`, `TotalRequestLatency`, `BytesDownloaded`, `BytesUploaded`.

### Recommended Alarms

- `4xxErrors` > 100/min -> investigate access denied
- `5xxErrors` > 10/min -> investigate throttling
- `ReplicationLatency` > 900s -> check replication config
- `FirstByteLatency` > 500ms p99 -> investigate prefix hot spots

## Diagnostic Toolkit

| Tool | Best For |
|---|---|
| CloudTrail | WHO accessed/modified with IAM context |
| Server Access Logs | HTTP-level request details |
| IAM Policy Simulator | Diagnose 403 without real request |
| Storage Lens | Org-wide cost/usage/protection visibility |
| CloudWatch Metrics | Real-time health and alerting |
| S3 Inventory | Bulk audit encryption/replication/lock status |
| AWS Config | Continuous compliance checking |
| Cost Explorer | Cost breakdown by type/bucket/region |
| IAM Access Analyzer | Unintended external access |
| Amazon Macie | Sensitive data discovery |
| GuardDuty S3 | Threat detection |
