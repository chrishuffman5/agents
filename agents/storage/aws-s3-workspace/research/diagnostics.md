# AWS S3 Diagnostics

## Access Denied Troubleshooting

Access denied errors (`403 Forbidden`) in S3 are among the most common issues operators encounter. The root cause is almost always a policy evaluation failure. S3 uses a layered policy evaluation model.

### S3 Policy Evaluation Order

1. **Explicit Deny** — Any explicit `Deny` in any policy wins, regardless of any `Allow`
2. **Bucket policy + IAM policy** — Both must allow the action (for cross-account access, only bucket policy suffices)
3. **Block Public Access** — Overrides bucket policy/ACL if the request would grant public access
4. **ACLs** — Evaluated if Object Ownership allows ACLs (disabled by default for new buckets)
5. **VPC endpoint policy** — If accessing via VPC endpoint, the endpoint policy must also allow the action

### Step-by-Step Diagnosis

**Step 1: Identify the requester identity**
```bash
# Look up the requester in CloudTrail (filter on AccessDenied events)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetObject \
  --query 'Events[?contains(CloudTrailEvent, `AccessDenied`)]'
```

**Step 2: Check IAM permissions for the requester**
```bash
# Simulate the policy evaluation
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/MyRole \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::my-bucket/my-key
```

**Step 3: Check bucket policy**
```bash
aws s3api get-bucket-policy --bucket my-bucket
```
Look for explicit `Deny` statements that might be matching the requester. Common culprits:
- `aws:SecureTransport: false` deny (non-TLS request)
- `aws:SourceVpc` or `aws:SourceVpce` condition excluding the requester
- Principal ARN mismatch (account ID typo, deleted role)
- `s3:x-amz-server-side-encryption` condition requiring KMS when client sends SSE-S3

**Step 4: Check Block Public Access settings**
```bash
# Account level
aws s3control get-public-access-block --account-id 123456789012

# Bucket level
aws s3api get-public-access-block --bucket my-bucket
```
If `BlockPublicPolicy` or `RestrictPublicBuckets` is enabled, any bucket policy granting public access is blocked.

**Step 5: Check Object Ownership and ACLs**
```bash
aws s3api get-bucket-ownership-controls --bucket my-bucket
```
If `BucketOwnerEnforced`, ACLs are disabled. Requests relying on ACL grants will fail.

**Step 6: Check encryption key access**
If the object is encrypted with SSE-KMS, the requester must have `kms:Decrypt` (for GetObject) or `kms:GenerateDataKey` (for PutObject) on the specific KMS key. Check the KMS key policy separately from IAM:
```bash
aws kms get-key-policy --key-id <key-id> --policy-name default
```

**Step 7: Check S3 Access Points**
If using an access point, the bucket policy must also delegate access to the access point, and the access point policy must allow the action.

### Common Access Denied Root Causes

| Symptom | Likely Cause | Fix |
|---|---|---|
| 403 from different AWS account | IAM policy allows but bucket policy missing cross-account grant | Add explicit `Allow` in bucket policy for cross-account principal |
| 403 despite correct IAM policy | Explicit `Deny` in bucket policy or SCP | Review bucket policy and SCPs for deny statements |
| 403 on HTTPS request | KMS key policy does not allow requester | Grant `kms:Decrypt`/`kms:GenerateDataKey` in KMS key policy |
| 403 from EC2 in VPC | VPC endpoint policy restricts access | Update endpoint policy or check `aws:SourceVpc` condition |
| 403 after deleting and recreating role | Role ARN not updated in bucket policy | Update bucket policy with new role ARN |
| 403 on SSE-C request | SSE-C disabled by default (April 2026) | Re-encrypt objects with SSE-S3 or SSE-KMS |
| 403 from on-premises | Interface VPC endpoint not configured | Set up PrivateLink interface endpoint for S3 |

### Useful CloudWatch Metric for Access Denied Diagnosis

- `4xxErrors` metric spike indicates access control or request issues
- Filter CloudTrail by `errorCode=AccessDenied` and `eventSource=s3.amazonaws.com`
- S3 Storage Lens advanced metrics include `403ForbiddenErrors` per bucket

---

## Slow Transfer Troubleshooting

### Diagnosing Upload Performance

**Step 1: Check FirstByteLatency**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name FirstByteLatency \
  --dimensions Name=BucketName,Value=my-bucket Name=FilterId,Value=EntireBucket \
  --start-time 2026-04-08T00:00:00Z \
  --end-time 2026-04-09T00:00:00Z \
  --period 3600 \
  --statistics Average,Maximum
```
High `FirstByteLatency` (>200ms for Standard) indicates S3-side processing time, not network.
High `TotalRequestLatency` minus `FirstByteLatency` indicates network transfer time.

**Step 2: Verify multipart upload is being used for large objects**
- Objects > 100 MB should use multipart upload
- AWS CRT-based SDKs (CLI v2, Boto3 with CRT, Java SDK 2.x) do this automatically
- Verify with S3 access logs: look for `REST.COMPLETE.MULTIPART.UPLOAD` events

**Step 3: Check prefix distribution**
- Sequential date-based prefixes (e.g., `2026/01/01/`) concentrate requests on few S3 partitions
- Monitor `AllRequests` and `BytesUploaded` per prefix via Storage Lens
- Solution: add random hash prefix (first 4–6 chars of SHA-256 of key)

**Step 4: Test Transfer Acceleration**
```bash
# Use the speed comparison tool endpoint
curl -o /dev/null -s -w "%{speed_upload}" \
  https://s3-accelerate.amazonaws.com/<bucket>/test-file \
  --upload-file test-file
```

**Step 5: Check network path**
- From EC2 in same region: should achieve near line rate (10+ Gbps for large instances)
- From on-premises: consider Direct Connect with S3 VPC interface endpoint
- From distant geographic location: enable Transfer Acceleration

### Common Slow Transfer Causes

| Symptom | Likely Cause | Fix |
|---|---|---|
| Slow large uploads from on-premises | Single-stream upload, high latency | Use multipart upload with CRT SDK |
| Slow downloads of large objects | Single connection | Use byte-range fetch with parallel threads |
| Slowness only on specific prefixes | S3 partition hot spot | Randomize prefixes |
| Slow cross-region transfer | Public internet routing | Use Transfer Acceleration or Direct Connect |
| Throttling errors (503 Slow Down) | Request rate exceeds S3 partition limit | Add prefixes, add exponential backoff |
| High latency from VPC | Routing through NAT Gateway | Use S3 Gateway VPC Endpoint (free) |
| SDK slow despite good network | Legacy SDK without CRT | Upgrade to AWS CLI v2, Boto3 with CRT |

### Transfer Rate Benchmarks (Approximate)

| Scenario | Expected Throughput |
|---|---|
| EC2 in same region, single thread | 500 MB/s – 2 GB/s (varies by instance) |
| EC2 in same region, multipart parallel | Near instance network limit |
| S3 Express One Zone, same AZ | Sub-millisecond latency; very high throughput |
| Transfer Acceleration, US to EU | 20–50% improvement vs direct upload |
| Byte-range fetch, 8 parallel threads | Scales near-linearly with concurrency |

---

## Replication Lag Diagnostics

### Monitoring Replication Metrics

S3 Replication metrics are emitted to CloudWatch when S3 RTC or replication metrics are enabled on a replication rule.

Key metrics in namespace `AWS/S3`:

| Metric | Description |
|---|---|
| `ReplicationLatency` | Maximum seconds between object upload and replica creation in destination |
| `BytesPendingReplication` | Total bytes of objects pending replication |
| `OperationsPendingReplication` | Count of operations pending replication |
| `OperationsFailedReplication` | Count of operations that failed replication |
| `OperationsMissedThreshold` | Operations that exceeded the S3 RTC 15-minute threshold |

```bash
# Check current replication backlog
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BytesPendingReplication \
  --dimensions Name=BucketName,Value=source-bucket Name=RuleId,Value=my-rule \
  --start-time 2026-04-08T00:00:00Z \
  --end-time 2026-04-09T00:00:00Z \
  --period 300 \
  --statistics Maximum
```

### Diagnosing Replication Failures

**Step 1: Check replication status on individual objects**
```bash
aws s3api head-object --bucket source-bucket --key my-key \
  --query 'ReplicationStatus'
# Returns: PENDING, COMPLETED, FAILED, REPLICA
```

**Step 2: Check replication configuration**
```bash
aws s3api get-bucket-replication --bucket source-bucket
```
Verify:
- IAM role has correct permissions (`s3:ReplicateObject`, `s3:ReplicateDelete`, `s3:GetObjectVersionForReplication`)
- Destination bucket has versioning enabled
- KMS permissions included if source uses SSE-KMS

**Step 3: Identify FAILED objects**
```bash
# Use S3 Inventory to find objects with ReplicationStatus=FAILED
# Or use S3 Batch Replication to retry failed objects
aws s3control create-job \
  --account-id 123456789012 \
  --operation '{"S3ReplicateObject":{}}' \
  --manifest '{"Spec":{"Format":"S3BatchOperations_CSV_20180820","Fields":["Bucket","Key","VersionId"]},"Location":{"ObjectArn":"arn:aws:s3:::manifest-bucket/manifest.csv","ETag":"abc123"}}' \
  --report '{"Bucket":"arn:aws:s3:::report-bucket","Format":"Report_CSV_20180820","Enabled":true,"Prefix":"batch-reports","ReportScope":"AllTasks"}' \
  --priority 10 \
  --role-arn arn:aws:iam::123456789012:role/BatchOperationsRole \
  --no-confirmation-required
```

### Common Replication Issues

| Symptom | Cause | Fix |
|---|---|---|
| Objects stuck in PENDING | IAM role lacks permissions | Check and fix IAM role trust policy and permissions |
| Objects stuck in FAILED | Destination bucket lacks versioning | Enable versioning on destination |
| Objects stuck in FAILED (KMS) | Destination account lacks KMS access | Grant `kms:ReplicateKey` and `kms:CreateGrant` in KMS key policy |
| Pre-existing objects not replicated | Live replication only covers new objects | Use S3 Batch Replication to backfill existing objects |
| Replication latency exceeds 15 min | S3 RTC not enabled, or backlog | Enable S3 RTC, check BytesPendingReplication metric |
| Objects not replicating after delete | DeleteMarker replication not enabled | Enable `DeleteMarkerReplication` in rule config |

### S3 Storage Lens for Replication Monitoring

- Storage Lens advanced metrics include replication rule counts per bucket
- Monitor `ReplicatedObjectCount` and `ReplicatedBytes` for source bucket trends
- Export Storage Lens data to S3 Tables for SQL analysis of replication health over time

---

## Cost Analysis

### Finding Unexpected Cost Drivers

**Step 1: Use AWS Cost Explorer**
- Service: S3
- Group by: Usage Type
- Look for: `DataTransfer-Out-Bytes` (inter-region or internet egress), `Requests-Tier1` (PUT), `Requests-Tier2` (GET), `TimedStorage-ByteHrs` (by storage class)

**Step 2: Enable S3 Storage Lens (Free Tier)**
Free metrics available without configuration:
- Total storage by bucket
- Object count by bucket
- Noncurrent version storage
- Incomplete multipart upload bytes
- Request count by operation type

```bash
# Get Storage Lens dashboard summary via CLI
aws s3control get-storage-lens-dashboard \
  --account-id 123456789012 \
  --config-id default-account-dashboard
```

**Step 3: Identify Waste**
- Buckets with large noncurrent version storage → add noncurrent version expiration lifecycle rule
- Buckets with incomplete multipart upload bytes → add AbortIncompleteMultipartUpload lifecycle rule
- Buckets without lifecycle rules but large Standard-IA or Standard storage → review access patterns

**Step 4: Identify Retrieval Cost Spikes**
- Glacier retrievals appear as `Retrieval-Bytes` in Cost Explorer
- Expedited retrievals are significantly more expensive than Standard or Bulk
- If workload requires frequent Glacier retrievals, consider moving to Glacier Instant Retrieval

**Step 5: Data Transfer Cost Analysis**
- S3-to-internet egress: check by reviewing `DataTransfer-Out-Bytes` usage type
- Cross-region replication: adds data transfer charges for every replicated byte
- NAT Gateway S3 traffic: use Gateway VPC endpoint to eliminate NAT costs

### S3 Cost Optimization Checklist

- [ ] All buckets have AbortIncompleteMultipartUpload lifecycle rule (7-day threshold)
- [ ] Versioning-enabled buckets have noncurrent version expiration rules
- [ ] S3 Analytics or Storage Lens confirms data access patterns match storage class
- [ ] VPC Gateway endpoints deployed (eliminates NAT Gateway S3 charges)
- [ ] CloudFront used for read-heavy, publicly accessed data (reduces S3 GET requests)
- [ ] S3 Intelligent-Tiering evaluated for data with variable access patterns
- [ ] Cost Explorer S3 drill-down reviewed monthly

---

## CloudWatch Metrics Reference

### Metric Namespaces

- `AWS/S3` — Bucket-level request metrics and storage metrics
- `AWS/S3/Storage-Lens` — Storage Lens metrics published to CloudWatch (advanced tier)

### Storage Metrics (Free, Daily)

| Metric | Description |
|---|---|
| `BucketSizeBytes` | Total size of all objects per storage class |
| `NumberOfObjects` | Total object count including all versions and delete markers |

Dimensions: `BucketName`, `StorageType`

### Request Metrics (Paid, 1-Minute)

| Metric | Description |
|---|---|
| `AllRequests` | Total HTTP requests |
| `GetRequests` | GET and SELECT requests |
| `PutRequests` | PUT, COPY, POST, multipart upload requests |
| `DeleteRequests` | DELETE requests |
| `HeadRequests` | HEAD requests |
| `ListRequests` | LIST requests |
| `BytesDownloaded` | Bytes returned in GET responses |
| `BytesUploaded` | Bytes received in PUT requests |
| `4xxErrors` | Client-side errors (403, 404, 400) |
| `5xxErrors` | Server-side errors (500, 503) |
| `FirstByteLatency` | Per-request latency from S3 receiving request to sending first byte |
| `TotalRequestLatency` | End-to-end request time including data transfer |

Dimensions: `BucketName`, `FilterId` (can filter by prefix, tag, or access point)

### Replication Metrics (Enabled per replication rule)

| Metric | Description |
|---|---|
| `ReplicationLatency` | Maximum seconds for object to replicate to destination |
| `BytesPendingReplication` | Bytes not yet replicated |
| `OperationsPendingReplication` | Operations not yet replicated |
| `OperationsFailedReplication` | Operations that failed replication |
| `OperationsMissedThreshold` | Operations exceeding 15-minute S3 RTC threshold |

### Recommended CloudWatch Alarms

```
Alarm: S3-4xxErrors-Spike
Metric: 4xxErrors
Threshold: > 100 per minute (5-minute period)
Action: Investigate access denied errors or malformed requests

Alarm: S3-5xxErrors-Spike
Metric: 5xxErrors
Threshold: > 10 per minute
Action: Investigate throttling or S3 service issues

Alarm: S3-ReplicationLag
Metric: ReplicationLatency
Threshold: > 900 seconds (15 minutes, matches S3 RTC SLA)
Action: Check replication configuration and IAM permissions

Alarm: S3-HighFirstByteLatency
Metric: FirstByteLatency
Threshold: > 500ms (p99)
Action: Investigate S3-side processing or prefix hotspots

Alarm: S3-BytesPendingReplication-High
Metric: BytesPendingReplication
Threshold: > 1 GB
Action: Check OperationsFailedReplication for errors
```

---

## S3 Storage Lens — Diagnostic Use Cases

### Diagnosing Cost Anomalies

1. Open S3 Storage Lens console → default account-level dashboard
2. Review **Top buckets by storage** to identify largest cost contributors
3. Check **Incomplete multipart upload bytes** to find cleanup opportunities
4. Check **Noncurrent version bytes** to identify versioning waste
5. Review **Requests by operation** to find unexpected GET or PUT spikes

### Diagnosing Data Protection Gaps

Storage Lens free metrics show:
- Buckets without versioning enabled
- Buckets without replication configured
- Buckets without lifecycle rules

Storage Lens advanced metrics add:
- Replication rule count per bucket
- Object Lock status
- Per-prefix request latency and error rates

### Diagnosing Performance Issues

Advanced performance metrics (2025 addition):
- Request latency breakdown by prefix
- Object and request size distribution
- Error rate by status code per bucket and prefix

### Exporting Storage Lens Data for Analysis

```bash
# Configure Storage Lens export to S3 (or S3 Tables with advanced tier)
aws s3control put-storage-lens-configuration \
  --account-id 123456789012 \
  --config-id my-lens \
  --storage-lens-configuration '{
    "Id": "my-lens",
    "IsEnabled": true,
    "AccountLevel": {
      "ActivityMetrics": {"IsEnabled": true},
      "BucketLevel": {"ActivityMetrics": {"IsEnabled": true}}
    },
    "DataExport": {
      "S3BucketDestination": {
        "Format": "Parquet",
        "OutputSchemaVersion": "V_1",
        "AccountId": "123456789012",
        "Arn": "arn:aws:s3:::my-lens-export-bucket",
        "Prefix": "lens-exports"
      }
    }
  }'
```

Query exported data with Athena:
```sql
SELECT bucket_name, storage_class, SUM(storage_bytes) / POW(1024, 3) as gb
FROM "s3_storage_lens"."metrics"
WHERE report_date >= DATE_ADD('day', -7, CURRENT_DATE)
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;
```

---

## Diagnostic Toolkit Summary

| Tool | Best For |
|---|---|
| CloudTrail (S3 data events) | Identify WHO accessed/modified an object with full IAM context |
| S3 Server Access Logs | HTTP-level request details (status codes, bytes, latency) |
| IAM Policy Simulator | Diagnose access denied without making a real request |
| S3 Storage Lens | Organization-wide cost, usage, and data protection visibility |
| CloudWatch Request Metrics | Real-time operational health and performance alerting |
| CloudWatch Replication Metrics | Replication lag and failure rate monitoring |
| S3 Inventory | Bulk audit of encryption, replication, version, and lock status |
| AWS Config | Continuous compliance checking against S3 security rules |
| AWS Cost Explorer | S3 cost breakdown by usage type, bucket, and region |
| `s3api head-object` | Check replication status, encryption type, metadata on a specific object |
| IAM Access Analyzer | Identify unintended external access to S3 resources |
| Amazon Macie | Discover sensitive data in S3 buckets |
| GuardDuty S3 Protection | Threat detection for anomalous or malicious S3 access |
