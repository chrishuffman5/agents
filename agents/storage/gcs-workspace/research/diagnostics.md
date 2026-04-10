# Google Cloud Storage: Diagnostics & Troubleshooting

## Access Denied (403 / 401)

### 403 Forbidden — Root Causes and Checks

**Step 1: Identify the denied principal**
The error message includes the principal (user, service account, or group) that was denied. Confirm this is the identity you expected.

**Step 2: Check IAM roles**
```bash
# View bucket IAM policy
gcloud storage buckets get-iam-policy gs://my-bucket

# Check project-level IAM bindings for the principal
gcloud projects get-iam-policy my-project \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:serviceAccount:my-sa@my-project.iam.gserviceaccount.com"
```

**Step 3: Check for IAM Deny policies**
IAM Deny policies can block access even when an Allow policy grants it. Check if any deny policies exist:
```bash
gcloud iam policies list-deny-policies --project=my-project
```

**Step 4: Uniform vs. fine-grained access**
If Uniform Bucket-Level Access is enabled, per-object ACLs are ignored. All access must be granted via IAM.
```bash
gcloud storage buckets describe gs://my-bucket --format="value(uniformBucketLevelAccess)"
```

**Step 5: Missing required permissions for the operation**

| Operation | Required Permission |
|-----------|-------------------|
| Read object | `storage.objects.get` |
| List objects | `storage.objects.list` |
| Write/upload object | `storage.objects.create` |
| Delete object | `storage.objects.delete` |
| Get bucket metadata | `storage.buckets.get` |
| Set bucket IAM policy | `storage.buckets.setIamPolicy` |

**Step 6: Organization policies blocking access**
Check for org-level constraints:
- `constraints/storage.publicAccessPrevention` — blocks allUsers/allAuthenticatedUsers.
- `constraints/storage.restrictAuthTypes` — blocks HMAC-signed requests.
- `constraints/gcp.restrictServiceUsage` — may block GCS API.
- `constraints/storage.uniformBucketLevelAccess` — forces uniform access.

**Step 7: VPC Service Controls**
If the bucket is in a VPC Service Control perimeter, requests from outside the perimeter are denied with a 403. Check the perimeter configuration in the Security → VPC Service Controls console page.

### 401 Unauthorized
- Client is not authenticated.
- Check that application default credentials are configured: `gcloud auth application-default login` or that `GOOGLE_APPLICATION_CREDENTIALS` points to a valid service account key.
- Ensure OAuth scopes include `https://www.googleapis.com/auth/devstorage.read_write` (or appropriate scope).
- If using a signed URL, ensure the URL is not expired and the signing key has not been rotated.
- Do not include an `Authorization` header in requests to signed URLs — even an empty header causes a 401.

### 403 After Re-uploading a Public Object
If a bucket uses fine-grained ACLs and an object is re-uploaded, the new object does not inherit the old ACL. The public read ACL must be re-applied after each upload:
```bash
gcloud storage objects update gs://my-bucket/my-object --predefined-acl=publicRead
```

### 412 Precondition Failed
- A custom org policy is violated (e.g., a policy requiring CMEK, or an allowed location constraint).
- Contact the GCP organization admin to determine which org policy is blocking the operation.

---

## Slow Transfers

### Diagnose Transfer Speed

**Step 1: Establish a baseline**
Test with a bucket in the same region as your transfer origin:
```bash
# Upload speed test (1 GB file)
time gcloud storage cp /dev/urandom gs://my-bucket/test-1gb --size=1073741824

# Download speed test
time gcloud storage cp gs://my-bucket/test-1gb /dev/null
```

If the same-region test is fast but cross-region is slow, geographic distance is the cause. Consider moving the bucket or using a multi-region bucket.

**Step 2: Check for throttling (429 responses)**
```bash
# Monitor request_count metric broken by response_code
gcloud monitoring metrics list --filter="metric.type=storage.googleapis.com/api/request_count"
```
In Cloud Monitoring, filter `storage.googleapis.com/api/request_count` by `response_code=429`. Sustained 429s indicate the bucket is being throttled.

**Step 3: Identify hot-spots**
Sequential object name patterns (timestamps, incrementing IDs) cause server-side hot-spotting. GCS autoscales by distributing load, but this takes minutes. Symptoms: bursty 429 errors at the start of a high-volume job.

Fix: add a hash prefix to object names:
```python
import hashlib
def gcs_key(original_name):
    prefix = hashlib.md5(original_name.encode()).hexdigest()[:4]
    return f"{prefix}/{original_name}"
```

**Step 4: Rate ramping**
New buckets start at ~1,000 writes/5,000 reads per second. Ramp up gradually — no faster than doubling every 20 minutes to avoid temporary degradation.

**Step 5: Storage Transfer Service QPS limit**
If using Storage Transfer Service with many small files, the per-job QPS cap limits throughput. Solution: split the transfer into multiple parallel jobs covering different prefixes.

**Step 6: CPU/Memory/Disk constraints on client**
- `gcloud storage` is significantly faster than gsutil for parallel uploads (Go vs. Python).
- For gsutil, tune `GSUtil:parallel_thread_count` and `GSUtil:parallel_process_count`.
- Check client CPU is not saturated during transfers (compression/decompression overhead).
- For on-premises transfers, check network bandwidth and latency to the GCS endpoint.

**Step 7: Use parallel/composite upload for large files**
```bash
# gsutil parallel composite upload (splits files > threshold into shards)
gsutil -o GSUtil:parallel_composite_upload_threshold=150M cp large-file.bin gs://my-bucket/

# gcloud storage (parallel by default)
gcloud storage cp large-file.bin gs://my-bucket/
```

**Step 8: Use resumable uploads**
For objects > 5 MB, always use resumable uploads. If the connection drops, the upload resumes from the last committed chunk rather than restarting.

---

## Billing Analysis

### Understanding GCS Cost Components

| Component | Billed When |
|-----------|------------|
| Storage | Per GB stored per month (prorated) |
| Class A operations | PUT, POST, LIST, PATCH |
| Class B operations | GET, HEAD |
| Retrieval fee | Applies to Nearline, Coldline, Archive reads |
| Early deletion | Object deleted before minimum storage duration |
| Egress (internet) | Data sent outside Google network |
| Egress (cross-region) | Data transferred between GCP regions |
| Egress (multi-region to region) | Same continent is free; different continent charged |
| Replication fee (dual-region Turbo) | Per-GB replicated |

### Finding Cost Drivers

**1. Use Cloud Billing reports**
Navigate to: Billing → Reports → Filter by service "Cloud Storage". Break down by SKU to see which cost component is largest.

**2. BigQuery Billing Export**
Enable billing export to BigQuery for fine-grained analysis:
```sql
-- Top GCS SKUs by cost (last 30 days)
SELECT
  sku.description,
  SUM(cost) AS total_cost,
  SUM(usage.amount) AS total_usage,
  usage.unit
FROM `billing_dataset.gcp_billing_export_v1_*`
WHERE service.description = 'Cloud Storage'
  AND DATE(_PARTITIONTIME) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY sku.description, usage.unit
ORDER BY total_cost DESC;
```

**3. Unexpected Egress Costs**
- Check if compute and storage are in the same region.
- Look for cross-region traffic in BigQuery billing export.
- Check if Cloud CDN is configured for frequently accessed public content (CDN egress is cheaper than direct GCS egress).

**4. Storage Insights for Inventory Analysis**
Enable Storage Insights to get BigQuery-queryable inventory snapshots:
```sql
-- Objects by storage class and size (from Storage Insights report)
SELECT
  storage_class,
  COUNT(*) as object_count,
  SUM(size) / POW(1024, 3) AS total_gb
FROM `my_project.storage_insights_dataset.my_inventory_*`
GROUP BY storage_class
ORDER BY total_gb DESC;
```

Identify objects that have not transitioned to cheaper storage classes despite infrequent access.

**5. Soft Delete and Version Costs**
Soft-deleted objects and noncurrent versions incur storage charges. Quantify:
```bash
# Count noncurrent versions
gcloud storage ls gs://my-bucket --all-versions | grep -c "#"
```

---

## Cloud Monitoring Metrics

### Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `storage.googleapis.com/api/request_count` | Requests by method and response code | Spike in 4xx or 5xx |
| `storage.googleapis.com/network/received_bytes_count` | Bytes received (uploads) | Baseline deviation |
| `storage.googleapis.com/network/sent_bytes_count` | Bytes sent (downloads/egress) | Budget threshold |
| `storage.googleapis.com/storage/object_count` | Number of live objects | Unexpected growth |
| `storage.googleapis.com/storage/total_bytes` | Total storage bytes | Budget threshold |
| `storage.googleapis.com/replication/meeting_rpo` | RPO met (dual/multi-region) | `false` = alert |

### Setting Up Monitoring

**Create an uptime/error rate alert:**
```bash
# Via gcloud: create alert policy for 5xx error rate
gcloud alpha monitoring policies create \
  --policy-from-file=gcs-alert-policy.json
```

**Alert policy JSON example:**
```json
{
  "displayName": "GCS 5xx Error Rate High",
  "conditions": [{
    "displayName": "GCS server errors",
    "conditionThreshold": {
      "filter": "metric.type=\"storage.googleapis.com/api/request_count\" AND metric.labels.response_code_class=\"5xx\"",
      "comparison": "COMPARISON_GT",
      "thresholdValue": 10,
      "duration": "60s",
      "aggregations": [{
        "alignmentPeriod": "60s",
        "perSeriesAligner": "ALIGN_RATE"
      }]
    }
  }],
  "alertStrategy": {"notificationRateLimit": {"period": "300s"}}
}
```

**View metrics in Cloud Console:**
- GCS Bucket → Observability tab: per-bucket dashboard.
- Cloud Monitoring → Metrics Explorer: custom queries.
- Cloud Monitoring → Dashboards: create combined dashboards across buckets.

### Retry Detection
Monitor `storage.googleapis.com/api/request_count` filtered by `response_code=429` to detect client-library retries masking throttling. High retry rates indicate sustained throttling that degrades effective throughput.

---

## Audit Logs

### Log Types

| Log Type | What It Captures | Cost |
|----------|-----------------|------|
| Admin Activity | Bucket create/delete, IAM changes, metadata changes | Free |
| Data Access - ADMIN_READ | Reading bucket metadata, IAM policies | Chargeable |
| Data Access - DATA_READ | Object reads (GET, LIST) | Chargeable |
| Data Access - DATA_WRITE | Object writes and deletes | Chargeable |

### Enabling Audit Logs
```bash
# Enable Data Access audit logs for GCS (project level)
gcloud projects get-iam-policy my-project --format=json > policy.json
# Add auditConfigs for storage.googleapis.com with DATA_READ, DATA_WRITE, ADMIN_READ
gcloud projects set-iam-policy my-project policy.json
```

### Querying Audit Logs in Cloud Logging
```
# Find all denied GCS requests (403) in the last 24 hours
resource.type="gcs_bucket"
protoPayload.status.code=7
timestamp >= "2026-04-08T00:00:00Z"

# Find who deleted objects in a specific bucket
resource.type="gcs_bucket"
resource.labels.bucket_name="my-sensitive-bucket"
protoPayload.methodName="storage.objects.delete"

# Find IAM policy changes on buckets
resource.type="gcs_bucket"
protoPayload.methodName="storage.setIamPermissions"
```

### Exporting Audit Logs
Create a log sink to export GCS audit logs to a GCS bucket for long-term retention or BigQuery for analysis:
```bash
gcloud logging sinks create gcs-audit-sink \
  bigquery.googleapis.com/projects/my-project/datasets/gcs_audit_logs \
  --log-filter='resource.type="gcs_bucket"'
```

---

## Quota Issues

### Quota vs. Limits

| Type | Adjustable | Examples |
|------|-----------|---------|
| Quota | Yes (via console or support) | Egress bandwidth, zonal storage (Rapid) |
| Limit | No | 5 TiB per object, 100 Pub/Sub configs per bucket, 1 write/sec per object |

### Diagnosing Quota Errors

**429 Too Many Requests** when it is not a rate issue:
- Check Cloud Quotas dashboard: Console → IAM & Admin → Quotas.
- Look for quotas near 100% utilization in the affected region.

**Quota error in API response:**
```json
{"error": {"code": 429, "message": "Quota exceeded for quota metric 'storage.googleapis.com/iam_assignments' ..."}}
```

### Common Quotas to Monitor

| Quota | Default | Symptom of Exhaustion |
|-------|---------|----------------------|
| IAM principals per bucket | 1,500 | Cannot add more IAM bindings to bucket |
| Pub/Sub notification configs per bucket | 100 | Cannot add notification rules |
| Bucket create/delete rate | ~1 per 2 seconds | Bucket creation failures in automation |
| Rapid storage per zone | 1 TB (project default) | Cannot upload to Rapid bucket |
| Internet egress bandwidth | 200 Gbps/region | Throttled downloads |

### Requesting Quota Increases
```bash
# View current quota usage
gcloud alpha quotas quota list --service=storage.googleapis.com --project=my-project

# Request increase via console: Quota → Edit Quota
# Or contact Cloud support for large increases
```

---

## Common Error Codes Reference

| HTTP Code | Error | Common Causes | Resolution |
|-----------|-------|--------------|------------|
| 400 | Bad Request | Invalid Content-Range header (use `bytes */[size]`, not `*/*`), malformed request | Fix request format |
| 401 | Unauthorized | Missing/expired credentials, Authorization header on signed URL | Re-authenticate; remove auth header |
| 403 | Forbidden | IAM permission missing, org policy, VPC SC perimeter, Uniform access mode | Check IAM, org policies, perimeter rules |
| 404 | Not Found | Bucket/object does not exist, typo in name, wrong region endpoint | Verify name; check object exists |
| 409 | Conflict | Bucket name already taken globally | Choose a unique bucket name |
| 412 | Precondition Failed | Org policy violation (location, CMEK, etc.) | Contact org admin |
| 429 | Too Many Requests | Rate limit / throttling | Exponential backoff; reduce request rate |
| 500 | Internal Error | Transient Google infrastructure issue | Retry with exponential backoff |
| 503 | Service Unavailable | Transient overload | Retry with exponential backoff |

### Exponential Backoff Implementation
```python
import time
import random

def retry_with_backoff(func, max_retries=5):
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            wait = (2 ** attempt) + random.uniform(0, 1)
            time.sleep(wait)
```

---

## Debugging Tools

### gcloud Verbose Logging
```bash
# Verbose HTTP logging for any gcloud storage command
gcloud storage ls gs://my-bucket --log-http --verbosity=debug

# Add custom headers for tracing
gcloud storage cp file.txt gs://my-bucket/ --additional-headers=X-Request-ID=my-trace-id
```

### CORS Debugging
If browser-based uploads or downloads fail with CORS errors:
1. Use Chrome DevTools → Network tab → Inspect the preflight OPTIONS request and response headers.
2. Verify `Origin` header exactly matches the CORS configuration (case-sensitive, no trailing slash).
3. Check that the HTTP method is listed in `Methods`.
4. Lower `MaxAgeSec` to 0 while debugging to disable preflight caching.
5. Use regional endpoints for CORS (not `storage.cloud.google.com`).

### Connectivity Test
```bash
# Test connectivity to GCS JSON API
curl -I https://storage.googleapis.com/storage/v1/b/my-bucket \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"

# Test regional endpoint
curl -I https://storage.us-central1.rep.googleapis.com/storage/v1/b/my-bucket \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"
```

### Storage Transfer Service Debugging
```bash
# View transfer job status
gcloud transfer jobs describe JOB_ID

# List recent operations for a job
gcloud transfer operations list --job-name=JOB_ID

# View operation details including error counts
gcloud transfer operations describe OPERATION_NAME
```
