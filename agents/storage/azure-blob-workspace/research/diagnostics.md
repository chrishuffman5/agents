# Azure Blob Storage — Diagnostics

## Monitoring Architecture

Azure Blob Storage integrates natively with Azure Monitor. Monitoring data flows to three stores:

| Data Type | Store | Retention |
|---|---|---|
| Platform metrics | Azure Monitor metrics database | 93 days (default) |
| Resource logs (diagnostic logs) | Log Analytics / Storage / Event Hubs (configured) | Configurable per destination |
| Activity log | Azure Monitor activity log store | 90 days (default) |

**Key principle:** Platform metrics are collected automatically with no configuration. Resource (diagnostic) logs require a diagnostic setting to be created before data is collected.

---

## Azure Monitor Metrics

### Metric Namespaces
- `Microsoft.Storage/storageAccounts` — account-level aggregate metrics.
- `Microsoft.Storage/storageAccounts/blobServices` — blob-service-specific metrics.

### Core Metrics

| Metric | Description | Dimension Examples |
|---|---|---|
| `Availability` | Percentage of successful requests | GeoType, ApiName, Authentication |
| `Transactions` | Total number of requests | ResponseType, GeoType, ApiName, Authentication |
| `Ingress` | Amount of ingress data (bytes) | GeoType, ApiName, Authentication |
| `Egress` | Amount of egress data (bytes) | GeoType, ApiName, Authentication |
| `SuccessServerLatency` | Server-side latency for successful requests (ms) | GeoType, ApiName, Authentication |
| `SuccessE2ELatency` | End-to-end latency including client round trip (ms) | GeoType, ApiName, Authentication |
| `UsedCapacity` | Storage capacity used by the account (bytes) | None |
| `BlobCapacity` | Blob storage capacity by tier and blob type | BlobType, Tier |
| `BlobCount` | Number of blobs in the account | BlobType, Tier |
| `ContainerCount` | Number of containers in the account | None |
| `IndexCapacity` | Storage used for blob index | None |

### Accessing Metrics

**Azure Portal — Metrics Explorer:**
1. Navigate to the storage account → Monitoring → Metrics.
2. Select scope: storage account or blob service.
3. Add metric, select aggregation (Total, Average, Maximum), and apply dimension filters.

**PowerShell:**
```powershell
$resourceId = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>/blobServices/default"
Get-AzMetric -ResourceId $resourceId -MetricName "Transactions" -TimeGrain 01:00:00
```

**Azure CLI:**
```bash
az monitor metrics list \
  --resource /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>/blobServices/default \
  --metric "Availability" \
  --interval PT1H
```

---

## Diagnostic Logging (Resource Logs)

Resource logs capture detailed request-level data: operation type, status code, latency, authenticated user identity, and resource URI.

### Log Categories
- **StorageRead:** All read operations (GetBlob, GetBlobMetadata, ListBlobs, etc.)
- **StorageWrite:** All write/modify operations (PutBlob, PutBlock, DeleteBlob, etc.)
- **StorageDelete:** Delete-specific operations.

### Enabling Diagnostic Settings

**Azure Portal:**
1. Storage account → Monitoring → Diagnostic settings.
2. Select `blob` sub-resource.
3. Add diagnostic setting → select log categories and destination.

**Azure CLI:**
```bash
az monitor diagnostic-settings create \
  --resource /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>/blobServices/default \
  --name "blob-diag" \
  --workspace /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<workspace> \
  --logs '[{"category":"StorageRead","enabled":true},{"category":"StorageWrite","enabled":true},{"category":"StorageDelete","enabled":true}]'
```

**Important restrictions:**
- Cannot route logs to the same storage account being monitored (creates recursive log loop).
- Cannot set retention policies directly on diagnostic settings; manage retention via Log Analytics workspace retention settings or lifecycle management policies on the destination storage account.

### Log Schema Fields (Key Fields)
| Field | Description |
|---|---|
| `TimeGenerated` | UTC timestamp of the operation |
| `OperationName` | API operation (e.g., `GetBlob`, `PutBlob`) |
| `StatusCode` | HTTP status code |
| `StatusText` | HTTP status text (e.g., `Success`, `ServerBusy`) |
| `DurationMs` | Total end-to-end latency in milliseconds |
| `ServerLatencyMs` | Server-side processing latency |
| `AuthenticationType` | `Anonymous`, `SAS`, `OAuth`, `SharedKey` |
| `Uri` | Full resource URI |
| `UserAgentHeader` | Client user agent string |
| `ObjectKey` | Blob path within the container |
| `CallerIpAddress` | Source IP address of the request |

---

## Kusto Query Language (KQL) Queries

Log Analytics table: `StorageBlobLogs`

### Common Diagnostic Queries

**Top 10 errors (last 3 days):**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(3d) and StatusText !contains "Success"
| summarize count() by StatusText
| top 10 by count_ desc
```

**Top 10 operations causing errors:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(3d) and StatusText !contains "Success"
| summarize count() by OperationName
| top 10 by count_ desc
```

**Top 10 slowest operations (E2E latency):**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(3d)
| top 10 by DurationMs desc
| project TimeGenerated, OperationName, DurationMs, ServerLatencyMs,
    ClientLatencyMs = DurationMs - ServerLatencyMs
```

**Throttling events (503 Server Busy):**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(3d) and StatusText contains "ServerBusy"
| project TimeGenerated, OperationName, StatusCode, StatusText, CallerIpAddress
```

**Anonymous access audit:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(7d) and AuthenticationType == "Anonymous"
| project TimeGenerated, OperationName, AuthenticationType, Uri, CallerIpAddress
```

**Shared Key usage (detect non-Entra access):**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(7d) and AuthenticationType == "SharedKey"
| summarize count() by CallerIpAddress, OperationName
| order by count_ desc
```

**High latency blobs:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(24h) and DurationMs > 5000
| project TimeGenerated, OperationName, ObjectKey, DurationMs, ServerLatencyMs, StatusCode
| order by DurationMs desc
```

**Operation distribution (pie chart):**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(3d)
| summarize count() by OperationName
| sort by count_ desc
| render piechart
```

---

## Connectivity Issues

### Symptom: HTTP 403 Forbidden

**Possible causes and diagnostics:**
- Shared Key authorization is disabled: check `AllowSharedKeyAccess` property on the account.
- Firewall rule blocking the client IP: check storage account networking rules.
- SAS token expired or malformed: verify SAS expiry and permissions in the token string.
- Missing RBAC role: verify the identity has at least `Storage Blob Data Reader` for read or `Storage Blob Data Contributor` for write.
- Anonymous access disabled: verify container access level and account-level `AllowBlobPublicAccess` setting.

**Diagnostic steps:**
```bash
# Check public access setting
az storage account show --name <account> --query "allowBlobPublicAccess"

# Check shared key authorization
az storage account show --name <account> --query "allowSharedKeyAccess"

# Check network rules
az storage account show --name <account> --query "networkRuleSet"
```

### Symptom: HTTP 404 Not Found

**Possible causes:**
- Container or blob does not exist at the specified path.
- Blob is in soft-deleted state (not visible in standard list).
- Blob path is case-sensitive; verify exact casing.
- Container was recently deleted (up to 30 seconds propagation delay).

**Diagnostic steps:**
```bash
# List soft-deleted blobs
az storage blob list --container-name <container> --account-name <account> --include d

# List soft-deleted containers
az storage container list --account-name <account> --include-metadata
```

### Symptom: DNS Resolution Failure / Connection Timeout to Storage Endpoint

**Possible causes:**
- Private endpoint DNS not configured; storage account resolves to public IP from within VNet.
- Private DNS Zone not linked to the VNet.
- NFS or SFTP requires VNet-only access but public endpoint is being used.

**Diagnostic steps:**
```bash
# Test DNS resolution (from inside VNet)
nslookup <account>.blob.core.windows.net
# Expected: returns 10.x.x.x (private IP) for private endpoint setup

# Test connectivity
curl -I https://<account>.blob.core.windows.net/<container>?restype=container
```

### Symptom: TLS/SSL Errors

- Verify minimum TLS version: `az storage account show --name <account> --query "minimumTlsVersion"`.
- Ensure client supports TLS 1.2+; TLS 1.0 and 1.1 are rejected.

---

## Throttling Diagnostics

Azure Storage throttles requests at three levels:
1. **Account level:** Total request rate exceeds account scalability target (40,000 req/s for major regions).
2. **Partition level:** A single blob or set of blobs receives too many requests for its partition (per-blob target: ~500 req/s for page blobs).
3. **Blob level:** Individual blob throughput limits exceeded.

### Symptoms
- HTTP 503 (Server Busy) — partition or account throttled.
- HTTP 500 (Operation Timeout) — request timed out due to overload.

### Detection

**Metric alert for throttling:**
- Metric: `Transactions` with dimension `ResponseType = ServerBusy`.
- Set alert threshold based on baseline; alert when count exceeds 0 or a defined rate.

**KQL query for throttling trend:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(24h)
| where StatusCode == 503
| summarize ThrottledRequests = count() by bin(TimeGenerated, 5m)
| render timechart
```

**Identify hot blobs:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(1h) and StatusCode == 503
| summarize count() by ObjectKey
| top 20 by count_ desc
```

### Remediation Strategies

| Strategy | When to Apply |
|---|---|
| Exponential backoff retry | Always implement in application code as baseline |
| Spread data across multiple blobs | When a single blob is hot (e.g., shared config blob) |
| Use multiple storage accounts | When approaching account-level limits; distribute workloads |
| Enable Azure CDN | For read-heavy blobs accessed globally; CDN serves cached content, reducing storage requests |
| Premium block blob account | For high-transaction workloads needing consistent low latency |
| Partition key design | Ensure blob names are distributed (avoid common prefix patterns) to spread across storage partitions |

**Exponential backoff pattern (pseudocode):**
```
maxRetries = 5
baseDelay = 1 second
for attempt in 1..maxRetries:
    try operation
    if success: break
    if 503 or 500: wait(baseDelay * 2^attempt + random jitter)
    else: raise
```

---

## Replication Status Diagnostics

### Object Replication Monitoring

**Metrics (on source account):**
- `OperationsPendingReplication`: number of operations queued for replication.
- `BytesPendingReplication`: bytes queued for replication.
- Both metrics support time-bucket dimension (0–5 min, 5–10 min, ..., >24 hrs).

**Enabling replication metrics:**
```bash
az monitor diagnostic-settings create \
  --resource <source-account-resource-id>/blobServices/default \
  --name "replication-metrics" \
  --metrics '[{"category":"Transaction","enabled":true}]' \
  --workspace <log-analytics-workspace-id>
```

**Check replication status on a specific blob:**
```bash
az storage blob show \
  --account-name <source-account> \
  --container-name <container> \
  --name <blob-name> \
  --query "replicationStatus"
```

### Replication Failure Investigation

When blob replication status shows `Failed`, check:
1. Destination account still exists and is accessible.
2. Destination container exists and is not being deleted.
3. Source blob is not archived (archive-tiered blobs cannot be replicated).
4. Destination container does not have an immutability policy blocking writes.
5. Source blob is not encrypted with a customer-provided key (per-request key, not CMK in Key Vault).
6. Cross-tenant replication is allowed if source and destination are in different Entra tenants.
7. Object replication policy is still active on destination account.

**KQL query for replication lag analysis (if replication logs are enabled):**
```kusto
StorageBlobLogs
| where OperationName == "ReplicateBlob"
| where TimeGenerated > ago(1h)
| summarize avg(DurationMs), max(DurationMs), count() by bin(TimeGenerated, 5m)
| render timechart
```

---

## Cost Analysis

### Using Azure Cost Management

1. Navigate to Azure Cost Management + Billing → Cost Analysis.
2. Filter by resource type: `Microsoft.Storage/storageAccounts`.
3. Group by: Resource, Meter, or Tags to attribute costs.
4. Use "Daily costs" view to identify cost spikes from unexpected tier transitions or data egress events.

### Identifying Cost Anomalies

**Storage Insights:**
- Azure Monitor → Storage Insights provides a unified view of capacity and transaction metrics across all storage accounts.
- Identifies accounts with high unused capacity, excessive transaction rates, or unexpected egress.

**KQL: High-egress operations:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(7d)
| where OperationName in ("GetBlob", "CopyBlobDestination")
| summarize TotalEgressBytes = sum(tolong(ResponseBodySize)) by CallerIpAddress
| top 20 by TotalEgressBytes desc
```

**KQL: Transaction volume by operation type:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(7d)
| summarize TransactionCount = count() by OperationName, bin(TimeGenerated, 1d)
| render columnchart
```

### Cost Allocation
- Use cost management budgets with per-account alerts to catch over-spend early.
- Tag storage accounts and use tag-based cost allocation in Azure Cost Management.
- For chargeback: export cost data to Azure Storage and analyze with Power BI or Synapse Analytics.

---

## Azure Monitor Alerts

### Recommended Alert Rules for Blob Storage

| Alert | Metric / Condition | Recommended Threshold |
|---|---|---|
| Availability degradation | `Availability` < threshold | < 99% (Hot), < 98% (Cool) |
| Throttling detected | `Transactions` where `ResponseType = ServerBusy` | > 0 (immediate) or > 100/min for sustained |
| High egress | `Egress` > threshold | 500 GiB/day (adjust per workload) |
| High latency | `SuccessE2ELatency` > threshold | > 1,000ms average (workload-dependent) |
| Capacity near limit | `UsedCapacity` > threshold | 80% of planned maximum |

**Create a metric alert (Azure CLI):**
```bash
az monitor metrics alert create \
  --name "blob-throttling-alert" \
  --resource-group <rg> \
  --scopes /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>/blobServices/default \
  --condition "count Transactions where ResponseType includes ServerBusy > 10" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action /subscriptions/<sub>/resourceGroups/<rg>/providers/microsoft.insights/actionGroups/<action-group>
```

---

## Azure Monitor Storage Insights

Azure Monitor Storage Insights provides a pre-built dashboard covering:

- **Overview:** availability, transactions, latency, and capacity for all storage accounts in scope.
- **Capacity:** used capacity by account and blob type.
- **Availability:** availability percentages with drill-down by API name.
- **Transactions:** volume, errors, and latency breakdowns.
- **Failures:** error categories and trends.

Access via: Azure Monitor → Insights Hub → Storage.

Storage Insights diagnoses:
- Hot partition throttling (spikes in 503 errors).
- Latency degradation (SuccessE2ELatency vs SuccessServerLatency divergence — large gap indicates client/network issue).
- Availability drops (SLA breach candidates).
- Accounts with zero or minimal activity (cost optimization candidates).

---

## Lifecycle Management Policy Monitoring

Monitor lifecycle policy executions via:

**Event Grid subscription to `LifecyclePolicyCompleted` event:**
- Subscribe at the storage account level.
- Event payload includes: account name, policy name, number of blobs processed, errors encountered.

**KQL query for lifecycle-triggered tier changes:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(24h)
| where OperationName == "SetBlobTier"
| where UserAgentHeader contains "lifecycle"
| summarize count() by bin(TimeGenerated, 1h), StatusCode
| render columnchart
```

**KQL query for lifecycle-triggered deletions:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(24h)
| where OperationName == "DeleteBlob"
| where UserAgentHeader contains "lifecycle"
| summarize count() by bin(TimeGenerated, 1h)
| render timechart
```

---

## Microsoft Defender for Storage

Microsoft Defender for Storage provides:
- **Threat detection:** unusual access patterns, access from suspicious IPs, brute-force key attacks, potential data exfiltration.
- **Malware scanning:** on-upload content scanning for uploaded blobs (per-blob cost).
- **Sensitive data discovery:** integrates with Microsoft Purview to identify accounts containing sensitive data.

Alerts appear in:
- Microsoft Defender for Cloud portal.
- Email notifications to subscription admins.
- Azure Monitor alerts (routable to action groups).

Enable per storage account or via Azure Policy for all accounts at scale:
```bash
az security pricing create \
  --name StorageAccounts \
  --tier Standard
```

---

## References
- [Monitor Azure Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/monitor-blob-storage)
- [Monitoring Data Reference for Azure Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/monitor-blob-storage-reference)
- [Azure Monitor Storage Insights](https://learn.microsoft.com/en-us/azure/storage/common/storage-insights-overview)
- [Scalability and Performance Targets for Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/scalability-targets)
- [Performance Checklist for Azure Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-performance-checklist)
- [Monitor and Troubleshoot Azure Storage](https://learn.microsoft.com/en-us/troubleshoot/azure/azure-storage/blobs/alerts/storage-monitoring-diagnosing-troubleshooting)
- [Object Replication Overview](https://learn.microsoft.com/en-us/azure/storage/blobs/object-replication-overview)
- [How to Troubleshoot Azure Storage Throttling and 503 Errors](https://oneuptime.com/blog/post/2026-02-16-how-to-troubleshoot-azure-storage-throttling-and-503-errors/view)
