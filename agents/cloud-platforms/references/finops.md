# FinOps Practice

> Financial accountability for cloud spend -- bridging engineering, finance, and business teams. Covers tagging strategy, chargeback/showback models, unit economics, commitment management, anomaly detection, and cost optimization by category.

---

## FinOps Foundation Framework

FinOps has three iterative phases (not sequential -- you cycle through continuously):

### Phase 1: Inform (Visibility and Allocation)

- Accurate tagging and cost allocation
- Dashboards showing spend by team, project, environment, service
- Showback reports (show teams their costs) or chargeback (bill teams internally)
- Unit economics: cost per transaction, cost per user, cost per API call

### Phase 2: Optimize (Rate and Usage)

- Right-sizing (overprovisioned resources are the #1 waste category)
- Reserved capacity for steady-state workloads
- Spot/preemptible for fault-tolerant workloads
- Storage tiering and lifecycle policies
- Eliminate idle and orphaned resources
- Architecture optimization (serverless where appropriate, data transfer reduction)

### Phase 3: Operate (Continuous Governance)

- Budget policies and automated enforcement
- Anomaly detection and alerting
- Regular optimization reviews (monthly minimum)
- FinOps team or cloud center of excellence
- Executive reporting tied to business metrics

---

## Tagging Strategy

Tags are the foundation of cloud cost management. Without consistent tagging, cost allocation is impossible.

### Mandatory Tags (Enforce via Policy)

| Tag | Purpose | Example Values |
|-----|---------|---------------|
| `owner` | Team or individual responsible | platform-team, data-eng, john.smith |
| `environment` | Deployment environment | production, staging, development, sandbox |
| `cost-center` | Finance cost center code | CC-1234, engineering-platform |
| `project` | Project or product name | checkout-service, data-pipeline, mobile-app |
| `managed-by` | How the resource is managed | terraform, manual, cdk, pulumi |

### Recommended Tags

| Tag | Purpose | Example Values |
|-----|---------|---------------|
| `data-classification` | Data sensitivity level | public, internal, confidential, restricted |
| `compliance` | Regulatory framework | hipaa, pci-dss, sox, gdpr |
| `auto-shutdown` | Can be stopped off-hours | true, false |
| `expiration-date` | Temporary resource cleanup | 2026-06-30 |
| `criticality` | Business criticality | critical, high, medium, low |

### Enforcement by Cloud

- **AWS:** Service Control Policies + AWS Config rules + tag policies in Organizations
- **Azure:** Azure Policy (deny resources without required tags)
- **GCP:** Organization Policies + labels (GCP uses "labels" for billing; "tags" are for firewall rules)

### GCP Labeling Note

GCP distinguishes between "labels" (key-value metadata for billing and organization) and "tags" (used for firewall rule targeting). For cost allocation purposes, use labels.

---

## Chargeback vs. Showback

**Showback:** Show teams their cloud costs without actually billing them internally. Lower friction, good starting point. Risk: teams may ignore costs they don't pay.

**Chargeback:** Actually deduct cloud costs from team budgets. Higher accountability, but requires accurate allocation. Can create perverse incentives (teams avoid cloud features to save budget).

**Recommendation:** Start with showback. Move to chargeback only when tagging is mature and shared cost allocation is fair.

### Shared Cost Allocation

Shared infrastructure (networking, monitoring, security tools, K8s clusters) is hard to allocate fairly.

| Strategy | Description | Best For |
|----------|-------------|----------|
| **Proportional** | Allocate proportionally to each team's direct spend | Simple but imprecise |
| **Usage-based** | Instrument shared services to track per-team usage | Most accurate, requires tooling |
| **Fixed allocation** | Each team pays a flat platform fee | Predictable but disconnected from usage |
| **Hybrid** | Fixed base fee + variable usage-based component | Balances predictability with fairness |

### Kubernetes Cost Allocation

- Use labels consistently on all pods/deployments (team, project, environment)
- Tools: Kubecost (open-source), CloudHealth, Apptio Cloudability, native cloud tools
- Track: CPU requests/usage, memory requests/usage, PVCs, load balancer costs, egress per service
- Challenge: shared cluster overhead (control plane, system pods, monitoring) must be distributed

---

## Anomaly Detection and Cost Alerts

| Capability | AWS | Azure | GCP |
|-----------|-----|-------|-----|
| Budget alerts | AWS Budgets | Cost Management Budgets | Budget alerts |
| Anomaly detection | Cost Anomaly Detection (ML-based) | Anomaly alerts in Cost Management | Budget alerts (threshold-based) |
| Automated response | Budgets + Lambda/SNS actions | Action groups (email, webhook, Logic Apps) | Pub/Sub + Cloud Functions |
| Recommendations | Cost Explorer + Compute Optimizer | Azure Advisor (cost pillar) | Active Assist Recommender |
| Cost analysis | Cost Explorer | Cost Analysis | Billing Reports / Looker Studio |

### Alert Setup Best Practice

1. Set budget at expected monthly spend
2. Configure alerts at 50%, 80%, 100%, and 120% (forecast)
3. Route to Slack/Teams/PagerDuty for team visibility
4. Add automated actions at 100% (restrict new resource creation, notify leadership)
5. Review and adjust budgets quarterly

---

## Commitment Management

### Buying Reserved Capacity

1. Analyze 30-90 days of usage data for stable baseline
2. Start with 1-year commitments (lower discount, lower risk)
3. Cover only steady-state workload (70-80% of baseline)
4. Leave headroom for Spot/on-demand for peaks
5. Review utilization monthly -- unused reservations are waste

### Exchange and Modification

- **AWS:** Convertible RIs can be exchanged; Savings Plans cannot be modified but are inherently flexible
- **Azure:** RIs can be exchanged or refunded (with limitations); scope can be changed
- **GCP:** CUDs cannot be canceled; resource-based CUDs can be shared across projects

### Monitoring Utilization

- Target: >80% utilization of reserved capacity
- **AWS:** Cost Explorer RI/SP utilization reports
- **Azure:** Reservations blade in Cost Management
- **GCP:** CUD utilization in Billing console

---

## Unit Economics

The most important FinOps metric: tie cloud spend to business outcomes.

| Metric | Formula | Why It Matters |
|--------|---------|---------------|
| Cost per transaction | Monthly cloud cost / monthly transactions | Tracks efficiency as you scale |
| Cost per active user | Monthly cloud cost / monthly active users | Ties spend to user growth |
| Cost per API call | API infrastructure cost / total API calls | Identifies expensive endpoints |
| Cost per GB processed | Data pipeline cost / GB processed | Tracks data processing efficiency |
| Cloud cost as % of revenue | Total cloud spend / total revenue | Executive-level efficiency metric |
| Marginal cost of growth | Incremental cloud cost / incremental revenue | Shows if costs scale linearly |

**Target:** Cloud cost as % of revenue should decrease over time as you optimize and benefit from scale. If it's increasing, either revenue is declining or cloud waste is growing.

---

## Cost Optimization Wins by Category

### Quick Wins (Days, 10-30% Savings)

- Delete unattached volumes / orphaned disks / unused persistent disks
- Stop or terminate idle development instances (schedule auto-stop after hours)
- Downsize over-provisioned instances (most VMs use <30% CPU)
- Delete unused static IPs (they incur hourly charges when unattached)
- Clean up old snapshots beyond retention policy
- Move infrequently accessed storage to cheaper tiers

### Medium-Term (Weeks, 20-50% Savings)

- Purchase Reserved Instances / Savings Plans / CUDs for steady-state workloads
- Implement auto-scaling for variable workloads (scale down at night, weekends)
- Use Spot/preemptible instances for batch, CI/CD, and fault-tolerant workloads
- Consolidate underutilized databases
- Right-size containers (many pods request 4x what they actually use)
- Review and optimize data transfer patterns (cross-AZ, cross-region, egress)

### Strategic (Months, 30-60% Savings)

- Refactor to serverless where appropriate (eliminate idle compute entirely)
- Implement caching layers to reduce database and API costs
- Use ARM-based instances (Graviton, Ampere) for 20-40% better price-performance
- Re-architect data pipelines for efficiency (batch vs streaming, compression, partitioning)
- Negotiate Enterprise Discount Programs (AWS EDP, Azure MACC, GCP committed spend)
- Implement FinOps culture: engineers own their costs, regular optimization reviews

---

## Cloud Cost Estimation Checklist

When estimating cloud costs for a new workload, account for all categories:

```
[ ] Compute -- VMs, containers, functions (include dev/staging environments)
[ ] Storage -- Object, block, file (include backups and snapshots)
[ ] Database -- Managed instances, replicas, storage, IOPS, backups
[ ] Networking -- Load balancers, NAT gateways, VPN/interconnect, static IPs
[ ] Data transfer -- Egress to internet, cross-region, cross-AZ, to other clouds
[ ] DNS -- Hosted zones, query volume
[ ] CDN -- Data transfer, requests, SSL certificates
[ ] Monitoring -- Metrics ingestion, log storage, custom metrics, APM, traces
[ ] Security -- WAF rules, DDoS protection, vulnerability scanning, KMS key usage
[ ] CI/CD -- Build minutes, artifact storage, container registry storage
[ ] Support plan -- Required tier for production SLA
[ ] Reserved capacity -- Discount commitments (subtract from on-demand estimates)
[ ] Licensing -- BYOL vs. included (Windows, SQL Server, Oracle)
[ ] Third-party tools -- Monitoring (Datadog), security (Prisma Cloud), backup (Veeam)
[ ] Tax -- Cloud services are subject to sales tax in many jurisdictions
[ ] Growth buffer -- Add 20-30% for unexpected growth
```
