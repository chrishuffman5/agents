# Azure Cost Optimization Reference

> Prices are US East, pay-as-you-go unless noted. Verify at https://azure.microsoft.com/pricing/.

## 1. Cost Management Tools

### Cost Analysis
Break down costs by resource group, tag, service, or region. Daily/monthly granularity, up to 13 months history. Export to CSV or Power BI.

### Budgets
Set spending thresholds with alerts at 50%, 75%, 90%, 100%. Action groups trigger emails, SMS, webhooks, Functions, Logic Apps. **Budgets do not enforce limits** -- they only alert.

### Azure Advisor
Automated recommendations:
- Right-sizing underutilized VMs (avg CPU <5%).
- Reserved Instance purchase recommendations.
- Idle resource identification (unattached disks, unused public IPs, empty App Service plans).
- Savings estimates with each recommendation.

---

## 2. Reserved Instances and Savings Plans

| Mechanism | Commitment | Discount | Flexibility |
|---|---|---|---|
| Reserved Instances (RI) | 1 or 3 years | 20-72% | Specific VM size + region, can exchange |
| Savings Plans | 1 or 3 years | 15-65% | $/hr across VM sizes, regions, services |
| Spot VMs | None | Up to 90% | Eviction with 30s notice |

**RIs** for known exact VM size and region. Deepest discounts.
**Savings Plans** for dynamic environments. Commit $/hr, applies to any eligible compute (VMs, App Service, Container Apps, Functions Premium).
**Spot** for batch, CI/CD, fault-tolerant workloads.

---

## 3. Azure Hybrid Benefit (AHB)

Use existing on-premises licenses on Azure:

- **Windows Server:** 2-proc/16-core license covers 1 VM (up to 8 vCores) or 2 VMs (up to 4 each). Savings: 40-80%.
- **SQL Server Enterprise:** Unlimited vCores of Azure SQL GP or 4 vCores BC. Savings: up to 85%.
- **SQL Server Standard:** 1 vCore of GP.
- **Linux:** SUSE and Red Hat subscriptions portable to Azure.

**AHB stacks with RIs.** Example: D4sv5 at $140/mo PAYG -> $84/mo with RI -> ~$50/mo with RI + AHB.

---

## 4. Dev/Test Pricing

Azure Dev/Test subscriptions provide:
- No Windows Server license charges (free Windows VMs).
- Reduced rates on Azure SQL, App Service, VMs.
- No production SLA.
- Requires Visual Studio subscription or Enterprise Agreement.

---

## 5. Common Cost Traps

### Infrastructure

**Premium SSD on dev/test VMs:**
P30 (1 TiB) = $123/mo vs E30 Standard SSD = $77/mo per disk. Across 20 dev VMs = ~$920/year wasted.
Fix: Script Standard SSD for all non-production.

**Forgotten Azure Firewall:**
$1.25/hr = $912/month even with zero traffic.
Fix: Use NSGs (free) for basic filtering. Firewall only for advanced features.

**App Service plans not scaled down:**
P3v3 (8 vCores) = $672/mo when P1v3 suffices. $480/mo wasted.
Fix: Monitor CPU/memory after deployment.

**Unattached Managed Disks:**
Persist and bill after VM deletion. Forgotten P50 (4 TiB) = $491/mo.
Fix: Azure Advisor flags these. Automate cleanup.

**Unused Public IPs:**
$3.65/mo each (static). Small per-IP but accumulates.

### Database

**Cosmos DB over-provisioned RU/s:**
50,000 RU/s "just in case" = $2,920/mo. Actual peak 5,000 = $2,628/mo wasted.
Fix: Use Autoscale. Monitor actual consumption.

**Azure SQL always-on for dev:**
GP 4-vCore 24/7 = $732/mo. Serverless with auto-pause (30% active) = ~$220/mo.
Fix: Serverless for all non-production.

**Synapse Dedicated pools not paused:**
DW1000c 24/7 = $8,640/mo. Business hours only = $3,168/mo. Savings: $5,472/mo.
Fix: Automate pause/resume with Azure Automation.

### Monitoring and Networking

**Log Analytics ingestion:**
$2.76/GB/day after 5 GB free. Chatty AKS: 50-100 GB/day = $124-262/mo.
Fix: Send only necessary logs. Use Basic Logs tier ($0.65/GB). Set daily caps.

**Application Insights over-sampling:**
High-traffic app without sampling: $500-1,000/mo.
Fix: Enable adaptive sampling. Set daily cap.

**AKS dev clusters running 24/7:**
3-node D4sv5 = $438/mo.
Fix: AKS cluster start/stop. Scale node pools to 0 after hours.

**Private Endpoints accumulating:**
$7.30/mo each. 20 endpoints = $146/mo.
Fix: Audit quarterly. Remove for decommissioned services.

**Cross-region bandwidth:**
10 TB/mo between US regions = $200-870.
Fix: Co-locate dependent services. Use CDN. Cache aggressively.

---

## 6. Monthly Optimization Checklist

1. **Azure Advisor:** Review and action all cost recommendations.
2. **Idle resources:** Unattached disks, unused public IPs, empty App Service plans, stopped-but-not-deallocated VMs.
3. **Reserved capacity:** Review Advisor RI recommendations. Start with 1-year.
4. **Right-sizing:** VM CPU/memory over 14 days. Downsize if avg CPU <20%, peak <50%.
5. **Dev/test subscriptions:** All non-production in Dev/Test subscriptions.
6. **Auto-pause:** Serverless databases, Spark pools, AKS dev clusters.
7. **Storage lifecycle:** Policies moving cold data to cheaper tiers.
8. **Log Analytics:** Review daily ingestion. Set caps. Basic tier for verbose logs.
9. **Tagging:** Enforce cost-center tags via Policy. Untagged = unattributable.
10. **Anomaly alerts:** Budget alerts at 75% and 100%. Enable anomaly detection.

---

## 7. Tagging Strategy

Enforce via Azure Policy (Deny effect):

| Tag | Purpose | Example |
|-----|---------|---------|
| CostCenter | Financial attribution | CC-12345 |
| Environment | Environment classification | Production, Development |
| Owner | Responsible team | team-platform@contoso.com |
| Application | Service name | order-service |
| DataClassification | Security classification | Confidential, Internal |

Without consistent tagging, cost attribution in multi-team environments is impossible. Enforce early.

---

## 8. Pricing Quick Reference

| Service | Dev/Test | Monthly | Production | Monthly |
|---------|----------|---------|------------|---------|
| Blob Storage | 100 GB LRS Hot | $1.80 | 10 TB ZRS Hot + lifecycle | $208 |
| Azure Files | 100 GB Hot | $2.55 | 1 TiB Premium | $164 |
| Managed Disk | 256 GB Standard SSD | $19 | 512 GB Premium SSD v2 | $42+ |
| Azure SQL | GP Serverless 2 vCore | $15-50 | Hyperscale 8 vCore RI | $1,400 |
| Cosmos DB | Serverless <500K RU/mo | $5-15 | Autoscale 10K max RU/s | $525 |
| Redis | Basic C0 (250 MB) | $16 | Standard C3 (13 GB) | $263 |
| Data Factory | 10 pipelines, Copy only | $5-20 | 100 pipelines + Flows | $200-500 |
| Synapse | Serverless SQL 1 TB/mo | $5 | DW1000c 12hr/22 days | $3,168 |
| Event Hubs | Basic 1 TU | $11 | Standard 5 TU | $110 |
| Service Bus | Standard light | $10 | Premium 1 MU | $740 |

Excludes data transfer, support plans, and monitoring.
