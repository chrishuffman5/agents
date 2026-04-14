# Azure Blob Storage Best Practices

## Account Design

- Use Standard GPv2 as default. Premium block blob only for sub-ms latency / > 10K IOPS.
- Separate accounts for different compliance, network, or encryption requirements.
- Naming: 3-24 lowercase alphanumeric. Pattern: `prodeastusappdata01`.
- Redundancy: ZRS or RA-GRS for hot workloads, GRS/RA-GRS for backup/archive, LRS only for non-critical.

## Tier Optimization

- Hot: accessed > 1x/month. Cool: < 1x/month, > 1x/year (30d min). Cold: rarely accessed, fast retrieval needed (90d min). Archive: < 1x/year, 15h latency acceptable (180d min).
- Implement lifecycle policies for all production accounts (zero cost to configure).
- Enable last access time tracking for access-based (not just modification-based) tiering.
- Use blob index tags for per-class lifecycle rules within the same container.
- Test policies on non-production first (24h delay to take effect).
- Purchase reserved capacity (1yr/3yr) for stable Hot/Cool/Cold volumes > 1 TiB.

## Security Hardening

### Identity and Access

- Disable Shared Key authorization (`AllowSharedKeyAccess = false`) where possible
- Use managed identities for Azure-hosted apps
- Assign minimum RBAC: `Storage Blob Data Reader/Contributor/Owner` (not Contributor/Owner)
- Prefer user delegation SAS over service SAS; set shortest expiry (< 1 hour for ad-hoc)
- Disable anonymous access (`allowBlobPublicAccess = false`) unless required

### Encryption

- Default MMK sufficient for most workloads. CMK (Azure Key Vault) for compliance.
- Enable infrastructure encryption (double encryption) for highest compliance.
- Set minimum TLS to 1.2. Enable "Secure transfer required."

### Data Protection Layers

1. Soft delete (blobs 7-90d, containers)
2. Blob versioning for version history
3. Point-in-time restore for bulk recovery
4. Immutability policies (WORM) for compliance
5. Microsoft Defender for Storage for threat detection

### Immutability

- Start unlocked during testing, lock within 24h when finalized (SEC 17a-4 requires locked)
- Container-level for uniform retention; version-level for per-blob granularity
- Incompatible with NFS 3.0 and SFTP

## Networking

- Production: disable public access, use private endpoints exclusively
- Hybrid: ExpressRoute with private endpoints
- VNet-only without private endpoint overhead: VNet service endpoints
- Enable "Allow trusted Microsoft services" for Azure Backup, Monitor, Event Grid
- Deploy Private DNS Zones for resolution; validate with `nslookup`
- Audit firewall rules quarterly; never open to `0.0.0.0/0`

## Cost Management

1. **Storage capacity** (60-80% of bill): lifecycle policies, tier optimization, reserved capacity
2. **Transactions**: monitor high-frequency operations; consider Premium for consistent low latency
3. **Data egress**: co-locate compute in same region, use Azure CDN, compress data
4. **Geo-replication transfer**: per-GB cost for GRS/RA-GRS/GZRS
5. **Early deletion penalties**: track tier duration before moving/deleting
6. **Version management**: lifecycle rules to delete old versions
7. **Object replication costs**: read transactions (source) + write (destination) + egress

### Hygiene

- Azure Monitor Storage Insights to identify zero-activity accounts
- Budget alerts in Cost Management per account
- Delete orphaned containers/blobs/snapshots regularly
- Review soft-delete retention periods (billed at cool rates)

## Data Lifecycle Patterns

### Medallion / Lakehouse (ADLS Gen2)

Bronze (raw, Hot, HNS) -> Silver (curated, Hot/Cool, partitioned) -> Gold (aggregated, Hot) -> Archive (Cold/Archive, lifecycle-managed).

### Backup Architecture

Separate backup account, WORM containers, GRS redundancy, soft delete >= 30d. Use Azure Backup for structured backups.

### Log/Telemetry

Append blobs for streaming, date-partitioned containers, transition to Cool after 7-14d, Cold after 90d, Archive after 180d.

## Operational Practices

- Rotate access keys every 90 days, store in Key Vault
- Apply Resource Manager delete locks on production accounts
- Tag all accounts: environment, workload, owner, cost-center, data-classification
- Configure alerts: Availability < 99%, ServerBusy transactions, Egress anomalies
- Enable diagnostic logging to Log Analytics
- Review Azure Advisor recommendations monthly
