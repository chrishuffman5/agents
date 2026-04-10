# Google Cloud Storage: Best Practices

## Bucket Naming and Design

### Naming Rules
- Bucket names are globally unique across all GCP customers.
- 3–63 characters; lowercase letters, numbers, hyphens, underscores, and dots only.
- Cannot begin or end with a hyphen or dot.
- Cannot resemble an IP address (e.g., `192.168.1.1`).
- Dots in names create DNS subdomains; avoid if using HTTPS with custom domains (SSL cert complications).
- Names containing dots require verification for domain-based signing.

### Naming Strategy
- Include project ID or environment in the bucket name (e.g., `myproject-prod-data`, `mycompany-analytics-raw`).
- Add a random suffix to prevent enumeration: `mybucket-a7f3k9` is harder to guess than `mybucket`.
- Avoid PII or sensitive data in bucket names; they appear in logs and URLs.
- Do not use sequential predictable names for high-throughput buckets (see Performance below).

### Bucket Design Principles
- **One bucket per data classification level**: Do not mix public and confidential objects in the same bucket. IAM policies are bucket-scoped; fine-grained mixing is error-prone.
- **One bucket per environment**: Separate `dev`, `staging`, and `prod` buckets. Prevents accidental cross-environment access.
- **One bucket per region when latency matters**: Co-locate data with the compute that processes it.
- **Avoid too many small buckets**: Bucket operations have a ~1 create/delete per 2 seconds rate limit per project.
- **Enable Hierarchical Namespace** for data lake / analytics patterns where atomic directory rename matters.

---

## Storage Class Selection

Follow the access frequency rule of thumb:

| Access Frequency | Recommended Class | Rationale |
|-----------------|-------------------|-----------|
| Multiple times per day | Standard | No retrieval fees; highest availability |
| Once per week | Standard or Nearline | Nearline break-even point is ~1 access/month |
| Once per month | Nearline | 30-day minimum; retrieval fee justified |
| Once per quarter | Coldline | 90-day minimum; lower storage cost |
| Once per year or less | Archive | 365-day minimum; lowest storage cost |
| Unpredictable patterns | Autoclass | Automatic per-object optimization |
| AI/ML training data on GCP | Rapid (zonal) | High-throughput, low-latency, no retrieval fee |

### Decision Framework
1. If access pattern is known and uniform: pick the matching fixed class.
2. If access pattern is variable or unknown across objects: enable Autoclass.
3. If data is processed by scanning services (Sensitive Data Protection, DLP, antivirus): do not use Autoclass (every scan resets the timer back to Standard).
4. If minimum storage duration is a concern (e.g., ephemeral temp files): use Standard to avoid early deletion charges.
5. For Archive class: verify that millisecond retrieval (not delayed thaw) meets your RTO requirements.

### Cost Calculation Checkpoints
- Nearline break-even vs. Standard: ~1 retrieval per 5.5 objects per month (depends on object size).
- Coldline break-even vs. Nearline: ~1 retrieval per 90 days.
- Always account for: storage price + retrieval price + Class A/B operation prices + minimum storage duration penalties.

---

## Security Hardening

### IAM Best Practices
- **Enable Uniform Bucket-Level Access** on all buckets. Disables per-object ACLs; enforces IAM-only. Once enabled for 90 days, it becomes permanent — plan before enabling.
- Apply the **principle of least privilege**: grant the minimum role needed.
  - Prefer `roles/storage.objectViewer` over `roles/storage.admin` for read-only consumers.
  - Use `roles/storage.objectCreator` for write-only producers (CI/CD artifact uploads).
- Avoid granting `roles/storage.admin` at project level; scope to specific buckets.
- Use **IAM Conditions** to restrict access by object name prefix, time window, or IP.
- Grant access to **Google Groups** rather than individual users — easier to audit and revoke.
- Avoid granting `setIamPolicy` permission to untrusted principals.

### Preventing Public Exposure
- Enable **Public Access Prevention** (`constraints/storage.publicAccessPrevention`) at the organization or project level.
- Regularly audit for `allUsers` or `allAuthenticatedUsers` grants using Security Command Center or Cloud Asset Inventory.
- Use **VPC Service Controls** to restrict GCS access to internal VPC traffic for sensitive data.

### Signed URL Security
- Use the shortest viable expiration (minutes, not days).
- Sign with IAM `signBlob` API (no service account key download needed) rather than downloaded key files.
- Restrict the HTTP method to only what is needed (GET vs. PUT).
- Use V4 signing (V2 is deprecated).
- Rotate signing service accounts regularly.
- Apply `constraints/storage.restrictAuthTypes` to block HMAC-signed requests if not needed.

### HMAC Key Management
- Associate HMAC keys with **service accounts**, not user accounts.
- Store the secret securely at creation time (shown once only; unrecoverable).
- Set keys to `INACTIVE` before deletion to audit usage first.
- Rotate HMAC keys on a regular schedule (90 days recommended).
- Use `constraints/storage.restrictAuthTypes` to limit HMAC key usage to specific services or block entirely.

### Encryption
- Use **CMEK** (Cloud KMS managed keys) for regulated data requiring key lifecycle control.
- Enable **key rotation** on KMS key rings (90-day rotation recommended for sensitive workloads).
- Use the **encryption type enforcement** feature (GA April 2026) to prevent buckets from accepting incorrectly encrypted objects.
- Do not store CSEK keys in source code or version control.

### Audit Logging
- Enable **Data Access audit logs** for sensitive buckets. Note: these generate significant log volume and incur logging costs.
- Export audit logs to a dedicated log sink (Cloud Storage, BigQuery, Pub/Sub) for long-term retention.
- Set log retention to match your compliance requirements (1–3,650 days in Cloud Logging).
- Use Cloud Storage's **Storage Insights** for inventory snapshots combined with encryption and retention metadata (new fields added March 2026).

---

## Cost Optimization

### Storage Cost
- Assign the coldest storage class compatible with your access SLA.
- Enable **lifecycle rules** to automatically transition aging objects:
  ```json
  {
    "rule": [
      {"action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
       "condition": {"age": 30, "matchesStorageClass": ["STANDARD"]}},
      {"action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
       "condition": {"age": 90, "matchesStorageClass": ["NEARLINE"]}},
      {"action": {"type": "Delete"},
       "condition": {"age": 365}}
    ]
  }
  ```
- Enable **Object Versioning** only on buckets that need it; add lifecycle rules to purge noncurrent versions (e.g., `numNewerVersions: 3` + `isLive: false`).
- Use **Autoclass** for mixed-temperature datasets to avoid paying for storage class selection mistakes.
- Compress data before upload: text files, logs, and JSON payloads compress 50–90%, reducing both storage and egress costs.

### Request Cost Reduction
- Batch small objects into larger archives where possible. Each PUT/GET request has a per-operation cost.
- Use `gcloud storage cp -r` or gsutil `-m` flag for parallel transfers, not many individual sequential calls.
- Use the **AbortIncompleteMultipartUpload** lifecycle rule to clean up abandoned uploads automatically:
  ```json
  {"action": {"type": "AbortIncompleteMultipartUpload"}, "condition": {"age": 7}}
  ```
- For listing operations, use object name prefixes to narrow result sets; avoid listing entire large buckets frequently.

### Egress Cost Reduction
- **Same-region data processing**: Co-locate Cloud Storage buckets and compute (GCE, GKE, Dataflow) in the same region. Intra-region egress is free.
- **Cross-region egress** costs $0.08–$0.23/GB depending on destination. Minimize by designing data pipelines to stay in one region.
- Use **Cloud CDN** for frequently accessed public or semi-public content to offload egress from GCS.
- Prefer **direct downloads from GCS** over intermediate proxies for large files.
- For global multi-region buckets, understand that reads are served from the nearest copy; writes incur replication overhead.

### Soft Delete Cost
- Soft delete retains deleted objects for the window period (default 7 days). This incurs storage charges for the retention duration at the object's storage class rate.
- Reduce the soft-delete window for buckets with high object churn: `gcloud storage buckets update gs://my-bucket --soft-delete-duration=1d`.
- Disable soft delete entirely on buckets that handle ephemeral temp files if the safety net is not needed.

---

## Performance Patterns

### Naming for Throughput
- Avoid sequential or timestamp-based object names at scale. Sequential names cause "hot spots" on a single server shard.
- Add a hash prefix to sequential keys: `md5(timestamp)[:4]/original-name` spreads load across key space.
- With a 1-character random hex prefix, GCS can scale to ~80,000 reads/16,000 writes per second on a single bucket.
- Hierarchical Namespace buckets start with 8x higher QPS baseline; prefer HNS for high-throughput data lakes.

### Upload Performance
- **Resumable uploads**: Use for objects larger than 5 MB. Allows retry from failure point without re-uploading from the start.
- **Parallel composite uploads** (gsutil): Split large files into shards, upload in parallel, compose into final object. Significant speed improvement for large files over high-latency connections.
  - Note: parallel composite upload creates a composed object; if requester downloads to a system without gsutil, it may not automatically decompose.
- **XML API multipart upload**: S3-compatible; upload parts in parallel, then complete the multipart upload.
- **Batch uploading**: Use `gcloud storage cp -r` or gsutil `-m` to parallelize multi-file uploads.

### Download Performance
- Request byte ranges (`Range: bytes=start-end`) to enable parallel downloading of large objects.
- Use regional endpoints to route requests to the nearest GCS endpoint.
- Enable **transfer compression** (Accept-Encoding: gzip) for compressible content.

### Rate Ramping
- Start below the baseline (1,000 writes/5,000 reads per second) and ramp no faster than doubling every 20 minutes.
- Implement exponential backoff with jitter for retries on 408, 429, and 5xx responses.
- Monitor `storage.googleapis.com/api/request_count` broken down by response code to detect throttling.

### Request Distribution
- Do not concentrate all traffic on a single object (e.g., a shared state file updated every second). GCS supports at most 1 write per second per object.
- Shard shared counters or state into multiple objects and aggregate in the application layer.

---

## Data Lifecycle Best Practices

### Design Lifecycle Rules Carefully
- Lifecycle rules execute asynchronously. Do not assume objects are deleted or transitioned exactly when the condition is met.
- Use `matchesPrefix` and `matchesSuffix` conditions to apply different rules to different data categories within one bucket.
- Combine conditions: e.g., `age: 90` AND `matchesStorageClass: STANDARD` to prevent re-processing objects already transitioned.
- Test lifecycle rules with the **Batch Operations dry run** (GA January 2026) before applying to production buckets.

### Version Management
- Set a maximum noncurrent version count: `numNewerVersions: 3` deletes all but the 3 most recent noncurrent versions.
- Set a noncurrent version age: `isLive: false, age: 30` deletes noncurrent versions older than 30 days.
- Both rules combined provide point-in-time recovery for up to 3 versions within 30 days.

### Retention Policy Design
- Lock retention policies only after thorough review — locking is permanent (cannot be shortened or removed).
- Use object holds for individual exceptions (e.g., objects under legal hold) rather than extending the bucket retention period.
- Document retention policy settings with a label on the bucket for discoverability.

### Incomplete Upload Cleanup
- Always add an `AbortIncompleteMultipartUpload` lifecycle rule. Incomplete uploads consume storage and incur charges.
- Recommended: abort after 7 days for most workloads; adjust based on expected upload duration for very large objects.

### Soft Delete Strategy
- Enable soft delete on production buckets holding critical data.
- Reduce the soft-delete window on high-churn intermediate/temp buckets to minimize unintended cost.
- Use the **restore by creation time** feature (January 2026) to recover specific object versions when the exact generation number is unknown.
