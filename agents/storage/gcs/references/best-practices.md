# Google Cloud Storage Best Practices

## Bucket Design

- Include project ID or environment in name (e.g., `myproject-prod-data`)
- Add random suffix to prevent enumeration
- Avoid dots in names (SSL cert complications with HTTPS)
- One bucket per data classification level (don't mix public and confidential)
- One bucket per environment (dev/staging/prod)
- Enable HNS for data lake/analytics with atomic directory rename needs
- Avoid too many small buckets (1 create/delete per 2s rate limit)

## Storage Class Selection

| Access Frequency | Class | Rationale |
|---|---|---|
| Multiple times/day | Standard | No retrieval fees |
| Once/week | Standard or Nearline | Nearline break-even ~1 access/month |
| Once/month | Nearline | 30-day minimum |
| Once/quarter | Coldline | 90-day minimum |
| Once/year or less | Archive | 365-day minimum, ms retrieval |
| Unpredictable | Autoclass | Automatic optimization |
| AI/ML on GCP | Rapid (zonal) | High-throughput, low-latency |

Do not use Autoclass if: bucket is scanned regularly by services (resets timer), or access patterns are known and uniform.

Always account for: storage price + retrieval price + operation prices + minimum duration penalties.

## Security Hardening

### IAM

- Enable Uniform Bucket-Level Access on all buckets (irreversible after 90 days)
- Least privilege: prefer `objectViewer`/`objectCreator` over `storage.admin`
- Use IAM Conditions (prefix, time, IP restrictions)
- Grant to Google Groups, not individuals
- Avoid granting `setIamPolicy` to untrusted principals

### Preventing Public Exposure

- Enable Public Access Prevention org policy
- Audit for allUsers/allAuthenticatedUsers via Security Command Center
- Use VPC Service Controls for sensitive data

### Signed URLs

- Shortest viable expiration (minutes, not days)
- Sign with IAM `signBlob` API (no key download)
- Restrict HTTP method to needed operations only
- Use V4 signing (V2 deprecated)

### HMAC Keys

- Associate with service accounts, not user accounts
- Rotate on 90-day schedule
- Set INACTIVE before deletion to audit usage
- Restrict via `constraints/storage.restrictAuthTypes`

### Encryption

- CMEK (Cloud KMS) for regulated data; 90-day key rotation
- Encryption type enforcement (GA April 2026) prevents incorrect encryption
- Never store CSEK keys in source code

### Audit Logging

- Enable Data Access audit logs for sensitive buckets (chargeable)
- Export to dedicated log sink (BigQuery for analysis, GCS for retention)
- Use Storage Insights for inventory + encryption/retention metadata

## Cost Optimization

### Storage

- Use lifecycle rules to auto-transition: Standard -> Nearline (30d) -> Coldline (90d) -> Delete (365d)
- Enable Autoclass for mixed-temperature datasets
- Compress data before upload (50-90% for text/JSON)
- Manage versions: lifecycle with `numNewerVersions: 3` + `isLive: false, age: 30`

### Requests

- Batch small objects into larger archives
- Use `gcloud storage cp -r` or gsutil `-m` for parallel transfers
- Add AbortIncompleteMultipartUpload lifecycle rule (7 days)
- Narrow list operations with prefixes

### Egress

- Co-locate compute and storage in same region (intra-region free)
- Use Cloud CDN for frequently accessed public content
- Cross-region: $0.08-0.23/GB -- design pipelines to stay in one region

### Soft Delete

- Reduce window on high-churn buckets: `gcloud storage buckets update gs://bucket --soft-delete-duration=1d`
- Disable entirely for ephemeral temp buckets

## Performance Patterns

### Naming

- Avoid sequential/timestamp object names at scale (hot spots)
- Add hash prefix: `md5(name)[:4]/original-name`
- HNS buckets start with 8x higher QPS baseline

### Uploads

- Resumable uploads for objects > 5 MB
- Parallel composite uploads for large files (gsutil: `parallel_composite_upload_threshold=150M`)
- XML API multipart for S3 compatibility

### Downloads

- Byte-range requests for parallel download
- Regional endpoints for lowest latency
- Transfer compression (Accept-Encoding: gzip) for compressible content

### Rate Ramping

- Start below baseline (1,000 writes / 5,000 reads per second)
- Ramp no faster than doubling every 20 minutes
- Exponential backoff with jitter for 408, 429, 5xx
- Max 1 write per second per object

## Data Lifecycle

- Test lifecycle rules with Batch Operations dry run before production
- Combine conditions: `age: 90` AND `matchesStorageClass: STANDARD`
- Lock retention policies only after thorough review (permanent)
- Use object holds for individual exceptions
- Add AbortIncompleteMultipartUpload rule to every bucket
