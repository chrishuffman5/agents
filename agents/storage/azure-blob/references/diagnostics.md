# Azure Blob Storage Diagnostics

## Monitoring Architecture

| Data Type | Store | Retention |
|---|---|---|
| Platform metrics | Azure Monitor metrics DB | 93 days |
| Resource logs | Log Analytics / Storage / Event Hubs | Configurable |
| Activity log | Activity log store | 90 days |

Platform metrics collected automatically. Resource logs require diagnostic settings.

## Key Metrics

| Metric | Description |
|---|---|
| `Availability` | % successful requests |
| `Transactions` | Total requests (filter by ResponseType, ApiName) |
| `Ingress` / `Egress` | Data transfer bytes |
| `SuccessServerLatency` | Server-side latency |
| `SuccessE2ELatency` | End-to-end latency |
| `UsedCapacity` | Total storage used |
| `BlobCapacity` | Capacity by tier and blob type |

## Diagnostic Logging

Enable via diagnostic settings on blob sub-resource. Categories: StorageRead, StorageWrite, StorageDelete. Route to Log Analytics, Event Hubs, or separate storage account (not the same account).

## KQL Queries (StorageBlobLogs)

**Top errors:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(3d) and StatusText !contains "Success"
| summarize count() by StatusText
| top 10 by count_ desc
```

**Throttling events:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(3d) and StatusText contains "ServerBusy"
| project TimeGenerated, OperationName, CallerIpAddress
```

**Slowest operations:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(3d)
| top 10 by DurationMs desc
| project TimeGenerated, OperationName, DurationMs, ServerLatencyMs
```

**Anonymous access audit:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(7d) and AuthenticationType == "Anonymous"
| project TimeGenerated, OperationName, Uri, CallerIpAddress
```

**Shared Key usage:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(7d) and AuthenticationType == "SharedKey"
| summarize count() by CallerIpAddress, OperationName
```

## Connectivity Issues

### HTTP 403 Forbidden

Check: Shared Key authorization disabled? Firewall blocking client IP? SAS expired? Missing RBAC role? Anonymous access disabled?

```bash
az storage account show --name <acct> --query "allowSharedKeyAccess"
az storage account show --name <acct> --query "networkRuleSet"
```

### HTTP 404 Not Found

Check: blob exists? Soft-deleted? Case-sensitive path? Container recently deleted (30s propagation)?

```bash
az storage blob list --container-name <c> --account-name <a> --include d  # soft-deleted
```

### DNS / Connection Timeout

Private endpoint DNS not configured. Check: `nslookup <account>.blob.core.windows.net` should return 10.x.x.x.

### TLS Errors

Verify minimum TLS version: `az storage account show --name <acct> --query "minimumTlsVersion"`.

## Throttling

Three levels: account (40K req/s), partition, blob (500 req/s for page blobs). Returns 503 (Server Busy) or 500 (Operation Timeout).

**Detection:** Metric alert on `Transactions` where `ResponseType = ServerBusy`.

**Hot blob identification:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(1h) and StatusCode == 503
| summarize count() by ObjectKey
| top 20 by count_ desc
```

**Remediation:** Exponential backoff (always), spread data across blobs, multiple accounts, Azure CDN for reads, Premium for high-transaction workloads, distribute blob names.

## Replication Status

Metrics: `OperationsPendingReplication`, `BytesPendingReplication` (with time-bucket dimensions).

```bash
az storage blob show --account-name <src> --container-name <c> --name <blob> --query "replicationStatus"
```

Failure checks: destination exists? Not archived? No immutability blocking? Cross-tenant allowed?

## Cost Analysis

Use Azure Cost Management -> Filter by `Microsoft.Storage/storageAccounts`. Group by Resource, Meter, or Tags. Daily costs view for spike identification.

**High-egress identification:**
```kusto
StorageBlobLogs
| where TimeGenerated > ago(7d) and OperationName in ("GetBlob", "CopyBlobDestination")
| summarize TotalEgressBytes = sum(tolong(ResponseBodySize)) by CallerIpAddress
| top 20 by TotalEgressBytes desc
```

## Recommended Alerts

| Alert | Condition | Threshold |
|---|---|---|
| Availability | < threshold | < 99% (Hot) |
| Throttling | ServerBusy transactions | > 0 or > 100/min sustained |
| High egress | Egress > threshold | 500 GiB/day |
| High latency | SuccessE2ELatency | > 1,000ms average |
| Capacity | UsedCapacity | 80% of planned max |

## Storage Insights

Azure Monitor -> Insights Hub -> Storage. Pre-built dashboard: availability, transactions, latency, capacity. Diagnoses hot partition throttling, latency degradation, availability drops, idle accounts.

## Defender for Storage

Threat detection (anomalous access, suspicious IPs), malware scanning (per-blob on upload), sensitive data discovery (Purview integration). Enable per account or via Azure Policy.
