# GCP Cost Optimization Reference

> Verify at https://cloud.google.com/pricing.

## 1. GCP's Unique Cost Advantages

### Sustained Use Discounts (SUDs)

Automatic 30% discount for running instances all month. No commitment, no reservation, no upfront payment.

- Usage tracked per vCPU-hour and memory-GB-hour per region.
- Tiers: 0-25% = full price; 25-50% = 20% off; 50-75% = 40% off; 75-100% = 60% off.
- Effective 100% monthly usage discount: ~30%.
- Applies to: N1, N2, N2D, C2 families.
- NOT: E2, Tau, A2, A3 (already optimized pricing).
- SUDs + CUDs do not stack. CUDs replace SUDs.

### Custom Machine Types

Specify exact vCPU (1-96) and memory (0.9-6.5 GB/vCPU). Extended memory up to 12 GB/vCPU. Available for N1, N2, N2D, E2. AWS/Azure force fixed sizes.

### Per-Second Billing

All compute bills per second (1-minute minimum for VMs). Some AWS/Azure services have hourly minimums.

### Free Tier

| Service | Free Amount | Monthly Value |
|---------|-------------|---------------|
| e2-micro VM | 1 per month (US regions) | ~$4-5 |
| Cloud Functions | 2M invocations | Significant |
| BigQuery | 1 TB queries + 10 GB storage | ~$6.25 |
| Cloud Storage | 5 GB Standard | ~$0.10 |
| Firestore | 50K reads, 20K writes/day | Significant |
| Cloud Run | 2M requests | Significant |
| Cloud Build | 120 build-min/day | ~$11 |
| Pub/Sub | 10 GB | ~$0.40 |

### CUD Flexibility

Resource-based CUDs commit to vCPU/memory quantities, applying across any matching instance in the project/region. Simpler than AWS RIs.

### Billing Export to BigQuery

Export detailed billing to BigQuery and analyze with SQL. Build custom dashboards, anomaly detection, allocation reports. Far more powerful than console-only tools.

---

## 2. Committed Use Discounts (CUDs)

| Term | Discount |
|------|----------|
| 1-year | Up to 57% |
| 3-year | Up to 70% |

- **Resource-based:** Commit vCPU + memory quantities. Apply across project/region.
- **Spend-based:** Commit hourly spend for GPUs and local SSDs.
- CUD sharing across projects within billing account (enable explicitly).
- Start with 1-year, move to 3-year once confident.

---

## 3. Cost Analysis and Allocation

### Labels

Key-value pairs on resources (e.g., `team:data-platform`, `env:production`):
- Appear in billing export. Essential for cost allocation.
- Up to 64 labels per resource. Automate with Organization Policies or Terraform.

### Billing Export

- Standard usage cost -> BigQuery (per-resource detail).
- Detailed usage cost (resource-level pricing data).
- Pricing export (SKU-level data).
- Query: cost by label, service, trends, anomaly detection.

### Recommender (Active Assist)

- Idle resource detection: VMs, IPs, disks, Cloud SQL with low usage.
- Rightsizing: VM type recommendations based on utilization.
- CUD recommendations.
- Unattended project detection.
- IAM: remove unused permissions.
- All include estimated savings.

---

## 4. Strategic Cost Playbook

### Compute

1. Verify SUDs are applying (check billing reports).
2. Right-size with Recommender (check weekly).
3. Use custom machine types to eliminate waste.
4. Convert predictable workloads to CUDs (1yr first, then 3yr).
5. Spot/preemptible for fault-tolerant work.
6. Cloud Run / Cloud Functions for intermittent workloads (scale to zero).
7. Schedule non-production VMs to stop outside business hours.

### Storage

1. Enable Autoclass on Cloud Storage (automatic tier optimization).
2. Set lifecycle policies: delete old objects, abort incomplete multipart.
3. Use Nearline/Coldline/Archive for infrequent data.
4. Delete orphaned disks and unused snapshots.
5. Regional storage when multi-region not required.

### Data/Analytics

1. Partition and cluster BigQuery tables (biggest lever).
2. Set `maximum_bytes_billed` on all queries.
3. Use BigQuery editions with autoscaling for heavy users.
4. Batch-load into BigQuery (free) instead of streaming ($0.05/GB).
5. Monitor INFORMATION_SCHEMA for expensive queries.
6. Use materialized views for common aggregations.

### Networking

1. Evaluate Standard Tier for latency-tolerant workloads.
2. Cloud Interconnect for high-volume transfers (60-75% lower egress).
3. Same-zone traffic when possible (free).
4. Cloud CDN for static content.

### GKE

1. Autopilot for most workloads (pay per pod, not node waste).
2. Spot pods for fault-tolerant workloads (60-91% savings).
3. Standard: right-size nodes, cluster autoscaler, VPA.
4. GKE cost allocation per namespace/team.
5. Consolidate into fewer clusters (save $73/mo mgmt fee per cluster).

---

## 5. Cost Comparison vs AWS/Azure

### Where GCP Is Typically Cheaper

- **BigQuery** vs Redshift/Synapse: serverless model wins for variable analytics.
- **GKE Autopilot** vs EKS/AKS: per-pod billing avoids overprovisioning.
- **Cloud Run** vs Fargate: concurrency model means fewer billable instances.
- **SUDs:** 30% automatic discount with no action required.
- **Custom machine types:** Avoid paying for unused resources.
- **Sustained workloads without commitment:** SUDs = built-in advantage.

### Where GCP Is Typically More Expensive

- **Network egress:** Premium Tier $0.08-0.23/GB vs AWS $0.05-0.09 vs Azure $0.05-0.08.
- **GKE Standard management fee:** $73/mo (same as EKS, vs AKS free control plane).
- **Spanner:** No equivalent at this price point in AWS/Azure.
- **Object storage cold retrieval:** Fees can add up.

### Roughly Equivalent

- Compute Engine vs EC2 vs Azure VMs (on-demand): within 5-10%.
- Cloud Storage vs S3 vs Blob: similar Standard pricing.
- Cloud Functions vs Lambda vs Azure Functions: similar models.
- Cloud SQL vs RDS vs Azure SQL: within 10-15%.

---

## 6. Budget and Alerts

GCP does not stop resources when budget is exceeded. Set alerts:
- Thresholds at 50%, 90%, 100%+ of budget.
- Notifications via email or Pub/Sub.
- Quotas: API rate limits and resource caps (request increases as needed).
- Budgets are per billing account, per project, or per label filter.
