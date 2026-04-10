# AWS S3 Best Practices

## Security Hardening (10-Point Checklist)

1. **Block Public Access** at account and bucket level (all four settings). Enforce via SCPs.
2. **Disable ACLs** (Bucket Owner Enforced). Default for new buckets since April 2023.
3. **Least-privilege IAM** -- no wildcard `s3:*`, use conditions (prefix, tag, VPC). Use IAM Roles, not Users.
4. **Enforce HTTPS** via Deny policy on `aws:SecureTransport: false`.
5. **Encryption** -- SSE-S3 default, SSE-KMS for audit/compliance, DSSE-KMS for highest compliance. SSE-C disabled by default April 2026.
6. **MFA Delete** -- requires MFA for permanent deletion and versioning suspension.
7. **VPC Endpoints** -- Gateway (free) for EC2/Lambda, Interface (PrivateLink) for on-premises.
8. **GuardDuty S3 Protection** for anomalous access detection.
9. **Amazon Macie** for PII/credential discovery in S3.
10. **IAM Access Analyzer** for unintended external sharing detection.

## Lifecycle Design

- Always add AbortIncompleteMultipartUpload rule (7 days) to every bucket
- Match transitions to access patterns using Storage Lens or S3 Analytics
- Set noncurrent version expiration on versioning-enabled buckets
- Account for minimum storage duration costs (30d IA, 90d Glacier, 180d Deep Archive)
- Use Intelligent-Tiering for unpredictable access patterns

### Example Pattern (Log Data)

```
Transitions: 30d -> Standard-IA, 90d -> Glacier Flexible, 365d -> Deep Archive
Expiration: 2555d (7 years)
Noncurrent: 30d -> Glacier, 90d -> Expire
Incomplete multipart: 7 days
```

## Cost Optimization

1. **Right-size storage classes** using Storage Lens and S3 Analytics
2. **Control data transfer** -- same-region compute, VPC Gateway endpoints (free), S3 Select
3. **Clean up waste** -- incomplete multipart uploads, old versions, expired delete markers
4. **Intelligent-Tiering** for uncertain access (no retrieval fee, small monitoring fee)
5. **Storage Lens + Cost Explorer** for visibility
6. **Express One Zone** for high-request-rate workloads (85% lower PUT costs)

## Performance Patterns

- **Request rate**: 3,500 PUT + 5,500 GET per second per prefix. Distribute across prefixes.
- **Prefix design**: Hash-prefix sequential keys to spread partitions. Avoid date-based hot spots.
- **Multipart upload**: Objects > 100 MB. Part size 8-128 MB. Use AWS CRT-based SDKs.
- **Byte-range fetch**: Parallel download of large objects (8-16 MB ranges).
- **Transfer Acceleration**: For distant geographic uploads via CloudFront edges.
- **Caching**: CloudFront with Origin Access Control (OAC) for read-heavy global workloads.

## Encryption Strategy

| Scenario | Approach |
|---|---|
| General | SSE-S3 (default, zero overhead) |
| Audit/cross-account | SSE-KMS with dedicated CMK |
| Highest compliance | DSSE-KMS |
| Pre-encrypted data | Client-side encryption |

Always combine with: TLS enforcement, KMS key rotation, CloudTrail logging.

## Monitoring

- **Server Access Logging**: Separate dedicated logging bucket, lifecycle to expire.
- **CloudTrail Data Events**: GetObject/PutObject with IAM identity. Store in locked bucket.
- **CloudWatch Request Metrics**: 1-minute granularity. Alert on 4xx/5xx spikes, FirstByteLatency.
- **S3 Storage Lens**: Organization-wide cost, activity, data protection visibility.
- **AWS Config**: Continuous compliance (public access, versioning, encryption, replication rules).
