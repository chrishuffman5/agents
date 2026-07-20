# Google Cloud Storage Diagnostics

## Access Denied (403 / 401)

### 403 Forbidden Diagnosis

1. **Identify denied principal** from error message
2. **Check IAM roles:**
   ```bash
   gcloud storage buckets get-iam-policy gs://my-bucket
   gcloud projects get-iam-policy my-project --flatten="bindings[].members" \
     --filter="bindings.members:serviceAccount:my-sa@..."
   ```
3. **Check IAM Deny policies:** `gcloud iam policies list-deny-policies --project=my-project`
4. **Uniform vs fine-grained access:** `gcloud storage buckets describe gs://my-bucket --format="value(uniformBucketLevelAccess)"`
5. **Check required permissions:** get=`storage.objects.get`, list=`storage.objects.list`, create=`storage.objects.create`, delete=`storage.objects.delete`
6. **Organization policies:** publicAccessPrevention, restrictAuthTypes, restrictServiceUsage, uniformBucketLevelAccess
7. **VPC Service Controls:** Requests from outside perimeter are denied with 403

### 401 Unauthorized

Missing/expired credentials. Check: `gcloud auth application-default login`, `GOOGLE_APPLICATION_CREDENTIALS` env var, OAuth scopes include `devstorage.read_write`. Do not include Authorization header with signed URLs.

### 412 Precondition Failed

Custom org policy violated (CMEK required, location constraint). Contact org admin.

## Slow Transfers

1. **Baseline test:** Same-region bucket. If fast same-region but slow cross-region, geographic distance is cause.
2. **Check throttling (429):** Monitor `storage.googleapis.com/api/request_count` by `response_code=429`.
3. **Identify hot spots:** Sequential names cause server-side hot-spotting. Add hash prefix.
4. **Rate ramping:** New buckets start at ~1K writes/5K reads per second. Double every 20 minutes.
5. **Storage Transfer Service QPS:** Split into multiple parallel jobs for small files.
6. **Client constraints:** `gcloud storage` is faster than gsutil (Go vs Python). Tune parallel thread/process counts.
7. **Use parallel/composite upload:** `gsutil -o GSUtil:parallel_composite_upload_threshold=150M cp file gs://bucket/`
8. **Resumable uploads:** Always for objects > 5 MB.

## Billing Analysis

### Cost Components

Storage (GB/month), Class A ops (PUT/POST/LIST), Class B ops (GET/HEAD), retrieval fees (Nearline/Coldline/Archive), early deletion, egress (internet, cross-region), Turbo Replication.

### Finding Drivers

1. **Cloud Billing reports:** Filter by "Cloud Storage", break down by SKU
2. **BigQuery Billing Export:**
   ```sql
   SELECT sku.description, SUM(cost) AS total_cost
   FROM billing_dataset.gcp_billing_export_v1_*
   WHERE service.description = 'Cloud Storage'
     AND DATE(_PARTITIONTIME) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
   GROUP BY sku.description ORDER BY total_cost DESC;
   ```
3. **Unexpected egress:** Check compute/storage co-location, use Cloud CDN
4. **Storage Insights:** BigQuery-queryable inventory for class distribution analysis
5. **Soft delete + version costs:** `gcloud storage ls gs://bucket --all-versions | grep -c "#"`

## Cloud Monitoring Metrics

| Metric | Alert On |
|--------|----------|
| `api/request_count` | Spike in 4xx or 5xx |
| `network/received_bytes_count` | Baseline deviation |
| `network/sent_bytes_count` | Budget threshold |
| `storage/object_count` | Unexpected growth |
| `storage/total_bytes` | Budget threshold |
| `replication/meeting_rpo` | `false` = alert |

Monitor `request_count` filtered by `response_code=429` to detect throttling masked by client retries.

## Audit Logs

| Log Type | Captures | Cost |
|----------|---------|------|
| Admin Activity | Bucket create/delete, IAM changes | Free |
| Data Access (ADMIN_READ) | Reading bucket metadata | Chargeable |
| Data Access (DATA_READ) | Object reads | Chargeable |
| Data Access (DATA_WRITE) | Object writes/deletes | Chargeable |

### Query Examples (Cloud Logging)

```
# Denied requests (403)
resource.type="gcs_bucket" protoPayload.status.code=7

# Object deletions in specific bucket
resource.type="gcs_bucket" resource.labels.bucket_name="my-bucket"
protoPayload.methodName="storage.objects.delete"

# IAM policy changes
resource.type="gcs_bucket" protoPayload.methodName="storage.setIamPermissions"
```

Export to BigQuery for long-term analysis: `gcloud logging sinks create gcs-audit-sink bigquery.googleapis.com/... --log-filter='resource.type="gcs_bucket"'`

## Quota Issues

| Quota | Default | Symptom |
|-------|---------|---------|
| IAM principals per bucket | 1,500 | Cannot add IAM bindings |
| Pub/Sub configs per bucket | 100 | Cannot add notifications |
| Bucket create/delete rate | ~1 per 2s | Creation failures |
| Rapid storage per zone | 1 TB | Upload failures |
| Internet egress bandwidth | 200 Gbps/region | Throttled downloads |

Check quotas: Console -> IAM & Admin -> Quotas. Request increases via console or support.

## Common Error Codes

| Code | Error | Resolution |
|------|-------|-----------|
| 400 | Bad Request | Fix request format (Content-Range header) |
| 401 | Unauthorized | Re-authenticate; remove auth header from signed URLs |
| 403 | Forbidden | Check IAM, org policies, VPC SC perimeter |
| 404 | Not Found | Verify bucket/object name and region endpoint |
| 409 | Conflict | Choose unique bucket name |
| 412 | Precondition Failed | Contact org admin for policy |
| 429 | Too Many Requests | Exponential backoff; reduce rate |
| 500/503 | Server Error | Retry with exponential backoff |

### Exponential Backoff

```python
import time, random
def retry_with_backoff(func, max_retries=5):
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1: raise
            time.sleep((2 ** attempt) + random.uniform(0, 1))
```

## Debugging Tools

```bash
# Verbose HTTP logging
gcloud storage ls gs://my-bucket --log-http --verbosity=debug

# Connectivity test
curl -I https://storage.googleapis.com/storage/v1/b/my-bucket \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"

# Storage Transfer Service status
gcloud transfer jobs describe JOB_ID
gcloud transfer operations list --job-name=JOB_ID
```
