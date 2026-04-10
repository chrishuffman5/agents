# Azure Blob Storage — Best Practices

## Storage Account Design

### Account Topology
- Use **Standard GPv2** accounts as the default for all new storage workloads. GPv2 supports all blob types, all access tiers, all redundancy options, lifecycle management, and ADLS Gen2.
- Use **Premium block blob** accounts only when workloads require sub-millisecond latency or very high transaction rates (>10,000 IOPS per container). Premium accounts cannot tier blobs; use Copy Blob to move data to GPv2 if tiering is needed.
- Avoid mixing blob storage with other services (queues, tables, files) in the same storage account when those services have significantly different access, redundancy, or network requirements.
- Do not exceed 250–500 storage accounts per region per subscription without reviewing whether account consolidation is possible. Each account is a separate billing, authentication, and network boundary.

### Account Consolidation vs. Separation
| Separate accounts when | Consolidate accounts when |
|---|---|
| Different compliance or data sovereignty requirements | Same region, same redundancy requirement |
| Different network security boundaries (public vs. private) | Costs benefit from shared access tier |
| Different customer tenants | Workloads do not conflict on scalability limits |
| Different backup/DR requirements | Teams manage the same data domain |
| Different encryption key requirements (CMK per account) | Simplicity is preferred over isolation |

### Naming Conventions
- Storage account names must be globally unique, 3–24 lowercase alphanumeric characters.
- Plan a naming convention that encodes: environment (prod/dev), region (eastus/westeu), workload/application, and optionally redundancy tier.
- Example: `prodeastusappdata01` — concise, deterministic, globally unique.

### Redundancy Selection
- **Hot/interactive workloads:** ZRS or RA-GRS. ZRS protects against zone failure without read latency from secondary; RA-GRS provides a secondary read endpoint for geographic distribution.
- **Analytics/ADLS Gen2:** ZRS (good balance of durability and cost) or RA-GRS for cross-region redundancy.
- **Backup/archive:** GRS or RA-GRS; LRS only acceptable if cost is the primary constraint and regional loss is tolerable.
- **Archive tier blobs** cannot use ZRS, GZRS, or RA-GZRS; plan accounts accordingly or rehydrate before changing redundancy.

---

## Access Tier Optimization

### Tier Selection Strategy
- **Hot:** Data accessed or modified more than once per month on average.
- **Cool:** Data accessed fewer than once per month but must be immediately available; store at least 30 days.
- **Cold:** Rarely accessed but must remain online and retrievable within seconds; store at least 90 days. Good for compliance data, completed projects, infrequently queried logs.
- **Archive:** Data that can tolerate up to 15-hour retrieval latency; store at least 180 days. Use for long-term backup, regulatory archives, raw data preservation.

### Decision Matrix
```
Access frequency per month:
  > 1x/month              → Hot
  < 1x/month, > 1x/year  → Cool or Cold
  < 1x/year              → Archive (if 15h latency acceptable)
                          → Cold (if fast retrieval still needed)
```

### Lifecycle Management Policies
- Implement lifecycle policies for all production accounts to automate tiering.
- Common policy pattern:
  1. Transition to Cool after 30 days of no modification.
  2. Transition to Cold after 90 days of no modification.
  3. Transition to Archive after 180 days of no modification.
  4. Delete after X days (compliance-driven).
- Enable **last access time tracking** when access patterns (not just modification time) should drive tiering. Note: each last-access update is billed at most once per 24 hours per blob.
- Use blob index tags to apply different lifecycle rules to different data classes within the same container (e.g., `environment=production` vs. `environment=test`).
- Test lifecycle policies on a non-production account before applying to production; changes take up to 24 hours to take effect.

### Early Deletion Avoidance
- Track how long blobs have been in Cool (30-day minimum), Cold (90-day minimum), and Archive (180-day minimum) tiers before moving or deleting them.
- If you frequently transition blobs before their minimum period, move them to Hot first or accept the prorated early-deletion fee in your cost model.
- Soft delete does not trigger early-deletion charges; account for this in retention policy designs.

### Reserved Capacity
- For predictable, stable storage volumes (>1 TiB sustained for 1+ years), purchase **reserved capacity** for 1-year or 3-year terms for Hot/Cool/Cold tiers.
- Reserved capacity applies only to the storage capacity component; transactions, egress, and data retrieval remain pay-as-you-go.
- Evaluate reservations after 2–3 months of stable usage using Azure Cost Management data.

---

## Security Hardening

### Identity and Access

**Prefer Microsoft Entra ID over Shared Key:**
- Disable Shared Key authorization (`AllowSharedKeyAccess = false`) on all storage accounts where possible.
- Use managed identities for Azure-hosted applications to obtain Entra ID tokens without credentials in code or configuration.
- Assign the minimum required RBAC role: `Storage Blob Data Reader`, `Storage Blob Data Contributor`, or `Storage Blob Data Owner`. Avoid `Contributor` or `Owner` roles which grant control-plane access.

**Shared Access Signatures (SAS):**
- Prefer **user delegation SAS** (signed with Entra ID credentials) over service SAS (signed with account key).
- Set the shortest practical expiry time. For ad-hoc SAS without a stored access policy, limit to 1 hour or less.
- Always use HTTPS-only SAS (`spr=https`); never allow HTTP.
- Maintain a revocation plan: for user delegation SAS, revoke the user delegation key; for service SAS backed by a stored access policy, modify or delete the policy.
- Do not embed SAS tokens in URLs stored in logs, browser history, or application code repositories.

**Anonymous Access:**
- Disable anonymous (public) blob access at the account level (`allowBlobPublicAccess = false`) unless explicitly required for static website hosting or public CDN scenarios.

### Encryption

**Encryption at Rest:**
- Default Microsoft-managed keys (MMK) are sufficient for most workloads and incur no additional cost.
- Use **customer-managed keys (CMK)** when regulatory requirements mandate key ownership, key rotation control, or auditable key access.
- Store CMKs in **Azure Key Vault** (with soft delete and purge protection enabled) or Azure Key Vault Managed HSM for hardware-backed security.
- Enable **infrastructure encryption** (double encryption) for highest compliance scenarios; incurs additional cost.
- Encryption scopes allow different CMKs per container or per blob for multi-tenant data isolation.

**Encryption in Transit:**
- Set minimum TLS version to `TLS1_2` on all storage accounts; TLS 1.0 and 1.1 are insecure and deprecated.
- Enable "Secure transfer required" on all storage accounts to reject HTTP requests.
- Use HTTPS in all SAS tokens and application connection strings.

### Data Protection Layers
Layer protection in this order:
1. Enable **soft delete** for blobs (7–90 days) and containers before applying any other data protection.
2. Enable **blob versioning** for workloads that need version history and point-in-time recovery.
3. Enable **point-in-time restore** for block blob workloads requiring bulk recovery capability.
4. Apply **immutability policies** (WORM) for compliance and regulatory requirements.
5. Enable **Microsoft Defender for Storage** for threat detection and malware scanning.

### Immutability Policy Best Practices
- Start with **unlocked** time-based retention policies during testing; lock only when configuration is finalized.
- Lock policies within 24 hours of configuration; unlocked policies do not meet SEC 17a-4(f) requirements.
- Use **container-level WORM** for workloads where all data within a container shares the same retention period (simpler, no versioning dependency).
- Use **version-level WORM** when different blobs within the same account need different retention periods or when blob-level granularity is required.
- Enable immutability on accounts not using NFS 3.0 or SFTP (incompatible).
- Do not configure immutability on page blob containers backing VM disks (writes will be blocked).

---

## Networking

### Network Access Model
- For all production workloads: disable public network access and use **private endpoints** exclusively.
- For hybrid workloads (on-premises + cloud): use **ExpressRoute** with private endpoints for deterministic, low-latency connectivity.
- For VNet-only access without the overhead of private endpoints: use **VNet service endpoints** — simpler but traffic still exits to a public endpoint (just via Azure backbone).
- For trusted Azure services (Backup, Monitor, Event Grid): enable the "Allow trusted Microsoft services" firewall exception.

### Private Endpoint Configuration
- Create separate private endpoints for each sub-resource type needed (`blob`, `dfs`, `file`, `queue`, `table`).
- Deploy private DNS zones (`privatelink.blob.core.windows.net`, `privatelink.dfs.core.windows.net`) and link them to all VNets that need access.
- Validate DNS resolution from each client network: `nslookup <account>.blob.core.windows.net` should resolve to a private IP (10.x.x.x range).
- In hub-and-spoke topologies, deploy private endpoints in the hub VNet and share DNS zones across spoke VNets.

### Firewall Rules
- Default behavior: deny all; explicitly allow required IP ranges and VNet subnets.
- Maximum 400 IP rules and 400 VNet rules per account; plan firewall rule capacity.
- Review and audit firewall rules quarterly; remove unused IP ranges.
- Never open storage accounts to `0.0.0.0/0` (all internet traffic) unless serving public static content.

### Network Routing
- Use **Microsoft network routing** (default) for optimal performance across Azure regions.
- Use **Internet routing** only when required to control egress costs through specific internet exchange points.

---

## Cost Management

### Cost Components (ranked by typical impact)
1. **Storage capacity:** GB-months stored per tier — usually 60–80% of total bill.
2. **Transactions:** Read/write/other operations per tier — "silent killer" for high-frequency workloads.
3. **Data egress:** Data transferred out of Azure region — significant for CDN-less internet-facing workloads.
4. **Geo-replication transfer:** Per-GB cost to replicate to secondary region (GRS/RA-GRS/GZRS/RA-GZRS).
5. **Early deletion penalties:** From premature tier transitions.

### Cost Optimization Strategies

**Tier Automation:**
- Implement lifecycle management policies (first step, zero additional cost).
- Use last access time tracking to shift from modification-based to access-based tiering for read-only archives.
- Evaluate Smart Tier for workloads with variable access patterns.

**Data Transfer Optimization:**
- Co-locate compute (VMs, AKS, Functions, Databricks) in the same Azure region as storage accounts to avoid inter-region egress charges.
- Use **Azure CDN** to cache frequently accessed blobs at edge locations; reduces storage transactions and inter-region egress.
- Compress data before storing (Gzip, Snappy, Zstandard) to reduce capacity costs.
- Use columnar formats (Parquet, ORC) for analytics data to reduce both storage size and query egress.

**Reserved Capacity:**
- Purchase 1-year or 3-year reserved capacity for Hot/Cool tiers when usage is predictable.
- Model savings using the Azure Pricing Calculator before committing.

**Account Hygiene:**
- Use Azure Monitor Storage Insights to identify storage accounts with zero or minimal activity.
- Set budget alerts in Azure Cost Management for per-account monthly spend thresholds.
- Delete orphaned containers, blobs, and snapshots regularly.
- Review soft-delete retention periods — excessively long periods retain deleted data (billed at cool rates).

**Version Management:**
- When blob versioning is enabled, lifecycle policies should include rules to delete old versions after a configurable period.
- Uncontrolled versioning on frequently modified blobs can rapidly inflate storage costs.

**Object Replication Costs:**
- Object replication incurs: read transactions on source, write transactions on destination, and data egress from source to destination.
- Enable replication on test accounts first to measure cost impact before enabling on production.

---

## Data Lifecycle Design Patterns

### Medallion / Lakehouse Architecture (ADLS Gen2)
```
Bronze (raw)     → Hot tier, HNS enabled, restricted write access
Silver (curated) → Hot or Cool tier, partitioned by date/entity
Gold (aggregated)→ Hot tier, consumed by BI/reporting tools
Archive (cold)   → Cold or Archive tier, lifecycle-managed from Bronze
```

### Backup Architecture
- Separate backup storage account from production to prevent privilege escalation or ransomware from affecting both simultaneously.
- Use WORM (immutable) containers for backup destinations.
- Apply GRS redundancy to backup accounts for cross-region protection.
- Set appropriate soft delete retention (minimum 30 days).
- Use Azure Backup or Azure Site Recovery for structured backup of Azure resources; use Blob Storage directly for application-level backups.

### Log/Telemetry Architecture
- Use **append blobs** for streaming log data from applications and services.
- Partition logs into daily or hourly containers (`logs/2026/04/09/`) for efficient lifecycle policy filtering.
- Transition log containers to Cool after 7–14 days, Cold after 90 days, Archive after 180+ days.
- Use Azure Monitor diagnostic logging (routing to storage) or Azure Event Hubs for high-volume log ingestion.

---

## Operational Best Practices

### Access Key Management
- Rotate storage account access keys on a defined schedule (e.g., every 90 days).
- Store access keys in **Azure Key Vault** — never hardcode keys in application code or configuration files.
- When disabling Shared Key authorization is not immediately feasible, enable Defender for Storage to detect unexpected key usage.

### Resource Locking
- Apply **Azure Resource Manager delete locks** to production storage accounts to prevent accidental account deletion.
- Resource locks do not prevent data within the account from being deleted; use immutability for data-level protection.

### Tagging
- Tag all storage accounts with: `environment`, `workload`, `owner`, `cost-center`, `data-classification`.
- Use Azure Policy to enforce mandatory tags on all new storage accounts.
- Tags enable cost allocation reporting in Azure Cost Management.

### Monitoring and Alerting
- Configure metric alerts for: Availability < 99%, Transactions with ResponseType = ServerBusy (throttling), and Egress anomalies.
- Enable diagnostic logging and route to Log Analytics for retention and KQL-based analysis.
- Review Azure Advisor recommendations for storage accounts monthly.

---

## References
- [Architecture Best Practices for Azure Blob Storage (Well-Architected)](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-blob-storage)
- [Security Recommendations for Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/security-recommendations)
- [Access Tiers Best Practices](https://learn.microsoft.com/en-us/azure/storage/blobs/access-tiers-best-practices)
- [Lifecycle Management Overview](https://learn.microsoft.com/en-us/azure/storage/blobs/lifecycle-management-overview)
- [Immutable Storage Overview](https://learn.microsoft.com/en-us/azure/storage/blobs/immutable-storage-overview)
- [Private Endpoints for Azure Storage](https://learn.microsoft.com/en-us/azure/storage/common/storage-private-endpoints)
- [Best Practices to Optimize Azure Blob Storage](https://sedai.io/blog/how-to-optimize-azure-blob-storage-in-2025)
- [Azure Storage Security Baseline](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/storage-security-baseline)
