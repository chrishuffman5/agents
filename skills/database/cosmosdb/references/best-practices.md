# Azure Cosmos DB Best Practices Reference

## Partition Key Selection

The partition key is the single most important design decision. It cannot be changed after container creation (you must create a new container and migrate data).

### Selection Criteria

1. **High cardinality:** The partition key property should have many distinct values (thousands to millions). Low-cardinality keys (e.g., `status` with 3 values) create hot partitions.
2. **Even distribution of storage:** No single partition key value should store disproportionately more data than others. Each logical partition has a 20 GB limit.
3. **Even distribution of throughput:** Write-heavy workloads should distribute writes across many partition key values. A date-based key funnels all current writes to a single partition.
4. **Present in frequent queries:** The most common queries should include the partition key in their WHERE clause to enable single-partition execution.

### Common Patterns

| Workload | Good Partition Key | Reasoning |
|---|---|---|
| Multi-tenant SaaS | `/tenantId` | Isolates tenant data, even if tenants vary in size use hierarchical keys |
| User profiles | `/userId` | Each user's data is co-located; user-centric queries are single-partition |
| IoT telemetry | `/deviceId` | Per-device queries are efficient; many devices provide cardinality |
| E-commerce orders | `/customerId` | Customer-centric queries dominate; use synthetic key if customers are very uneven |
| Event sourcing | `/aggregateId` | Events for a single aggregate are co-located and ordered |
| Session data | `/sessionId` | High cardinality, short-lived, naturally distributed |
| Logging / time-series | `/deviceId` or synthetic | Never use timestamp alone (write-hot); combine device + time bucket if needed |

### Synthetic Partition Keys

When no single property provides good distribution, create a synthetic key:

```json
{
  "id": "order-12345",
  "partitionKey": "customer-789-2026-Q1",
  "customerId": "customer-789",
  "orderDate": "2026-03-15"
}
```

Or use a hash suffix for write-heavy scenarios:
```json
{
  "id": "event-67890",
  "partitionKey": "device-456-3",
  "deviceId": "device-456",
  "hashSuffix": 3
}
```
Where hashSuffix is `hash(id) % N` for N logical partitions per device.

### Hierarchical Partition Keys

Use hierarchical partition keys when a single key causes partition skew:

```
/tenantId/userId/sessionId
```

Benefits:
- Large tenants are automatically sub-partitioned across multiple physical partitions
- Queries can target any prefix level: all of a tenant, a specific user within a tenant, or a specific session
- Eliminates the 20 GB logical partition limit concern for the top-level key
- No application-side sharding logic needed

When to use:
- Multi-tenant applications where tenant sizes vary dramatically
- Time-series data where you want partition by device + time range
- Any scenario where a single partition key creates hot or oversized partitions

## RU Optimization

### Point Reads Over Queries

The single biggest RU optimization. Always prefer point reads when you have the item's `id` and partition key:

```csharp
// Point read: ~1 RU for 1 KB item
ItemResponse<MyItem> response = await container.ReadItemAsync<MyItem>(
    id: "item-123",
    partitionKey: new PartitionKey("pk-value")
);

// Query: ~3+ RU even for a single item
var query = container.GetItemQueryIterator<MyItem>(
    "SELECT * FROM c WHERE c.id = 'item-123'"
);
```

### Indexing Policy Optimization

Default indexing (all paths) is convenient but expensive for write-heavy workloads:

**Exclude large or unqueried paths:**
```json
{
  "indexingMode": "consistent",
  "includedPaths": [{ "path": "/*" }],
  "excludedPaths": [
    { "path": "/largePayload/*" },
    { "path": "/metadata/internalNotes/*" },
    { "path": "/binaryData/*" },
    { "path": "/_etag/?" }
  ]
}
```

**Include only queried paths (most aggressive optimization):**
```json
{
  "indexingMode": "consistent",
  "includedPaths": [
    { "path": "/tenantId/?" },
    { "path": "/status/?" },
    { "path": "/createdAt/?" },
    { "path": "/category/?" }
  ],
  "excludedPaths": [{ "path": "/*" }]
}
```

**Add composite indexes for multi-field ORDER BY and filters:**
```json
{
  "compositeIndexes": [
    [
      { "path": "/category", "order": "ascending" },
      { "path": "/createdAt", "order": "descending" }
    ],
    [
      { "path": "/status", "order": "ascending" },
      { "path": "/priority", "order": "ascending" },
      { "path": "/createdAt", "order": "descending" }
    ]
  ]
}
```

### Query Optimization

**Always include partition key in WHERE clause:**
```sql
-- Good: single-partition query
SELECT * FROM c WHERE c.tenantId = 'tenant-1' AND c.status = 'active'

-- Bad: cross-partition fan-out
SELECT * FROM c WHERE c.status = 'active'
```

**Project only needed fields:**
```sql
-- Good: reduces response size and RU cost
SELECT c.id, c.name, c.email FROM c WHERE c.tenantId = 'tenant-1'

-- Bad: returns entire document
SELECT * FROM c WHERE c.tenantId = 'tenant-1'
```

**Avoid cross-partition ORDER BY without composite index:**
```sql
-- Requires composite index on (category ASC, createdAt DESC)
SELECT * FROM c WHERE c.tenantId = 'tenant-1'
ORDER BY c.category ASC, c.createdAt DESC
```

**Use OFFSET/LIMIT for pagination (but prefer continuation tokens for large datasets):**
```sql
-- Continuation tokens are more efficient for deep pagination
SELECT * FROM c WHERE c.tenantId = 'tenant-1' ORDER BY c.createdAt DESC
OFFSET 0 LIMIT 50
```

**Avoid high-cost patterns:**
- `SELECT DISTINCT` across large result sets
- `ORDER BY` without a supporting composite index
- User-defined functions (UDFs) in WHERE clauses (prevents index utilization)
- `LIKE '%substring%'` (full scan)
- Cross-partition aggregations on large datasets

### Connection and SDK Optimization

**.NET SDK best practices:**
```csharp
// Use singleton CosmosClient per application lifetime
CosmosClient client = new CosmosClientBuilder(connectionString)
    .WithConnectionModeDirect()                    // Direct mode for lowest latency
    .WithApplicationPreferredRegions(new List<string> { "East US", "West US" })
    .WithContentResponseOnWrite(false)             // Don't return item body on writes (saves bandwidth)
    .WithThrottlingRetryOptions(
        maxRetryWaitTimeOnThrottledRequests: TimeSpan.FromSeconds(30),
        maxRetryAttemptsOnThrottledRequests: 9)
    .WithBulkExecution(true)                       // Enable for bulk import scenarios
    .Build();
```

**Java SDK best practices:**
```java
// Use Direct mode, configure preferred regions, enable content response on write = false
CosmosAsyncClient client = new CosmosClientBuilder()
    .endpoint(endpoint)
    .key(key)
    .directMode()
    .preferredRegions(Arrays.asList("East US", "West US"))
    .contentResponseOnWriteEnabled(false)
    .buildAsyncClient();
```

## Consistency Level Selection

### Decision Framework

| Question | Recommended Level |
|---|---|
| Does the app need read-your-writes within a user session? | **Session** (default) |
| Is the data financial or inventory where stale reads cause real harm? | **Strong** (single-region writes only) |
| Do you need bounded staleness but not immediate consistency? | **Bounded Staleness** (configure K and T) |
| Is ordering important but freshness less critical? | **Consistent Prefix** |
| Is the data tolerant of stale reads (counters, analytics, social likes)? | **Eventual** |

### Per-Request Consistency Relaxation

You can relax consistency per-request (but never strengthen beyond account default):

```csharp
// Account default is Session, relax to Eventual for this read
ItemRequestOptions options = new ItemRequestOptions
{
    ConsistencyLevel = ConsistencyLevel.Eventual
};
var response = await container.ReadItemAsync<MyItem>("id", new PartitionKey("pk"), options);
// This read costs 1 RU instead of potentially 2 RU (if default were Strong)
```

### Multi-Region Consistency Considerations

- **Strong:** Only available with single-region writes. Reads are served from the write region (higher latency from remote read regions). Use only when absolutely necessary.
- **Bounded Staleness:** Good compromise for multi-region. Set staleness bounds based on your replication lag tolerance (e.g., K=100000, T=300 seconds).
- **Session:** Best default for multi-region. Ensure session tokens are propagated if the same user's requests hit different app instances.

## Capacity Planning

### Estimating RU Requirements

1. **Profile your operations:** Measure RU cost of each operation type using `x-ms-request-charge` response header
2. **Estimate operation volumes:** reads/sec, writes/sec, queries/sec per operation type
3. **Calculate total:** Sum of (operation_count * RU_per_operation) for all operation types
4. **Add headroom:** Provision 20-30% above calculated needs for spikes
5. **Account for partition distribution:** If you have hot partitions, the hottest partition must stay under ~10,000 RU/s

**Example calculation:**
```
Point reads: 1,000/sec * 1 RU = 1,000 RU/s
Writes: 200/sec * 6 RU = 1,200 RU/s
Queries: 100/sec * 15 RU = 1,500 RU/s
Total: 3,700 RU/s
With 25% headroom: 4,625 RU/s → provision 5,000 RU/s
```

### Choosing Capacity Mode

| Criteria | Provisioned | Autoscale | Serverless |
|---|---|---|---|
| Traffic pattern | Steady, predictable | Variable with known peaks | Sporadic, low volume |
| Cost optimization | Reserved capacity discounts | Pay for actual usage (min 10% of max) | Pay per operation |
| Max throughput | Unlimited (scale out partitions) | Unlimited (configure max) | 5,000 RU/s burst |
| Multi-region | Yes | Yes | No (single region) |
| SLA | 99.999% (multi-region) | 99.999% (multi-region) | No SLA |
| Best for | Production workloads | Production with variable traffic | Dev/test, prototyping |

### Database vs Container Throughput

**Database-level (shared) throughput:**
- Use when you have many small containers with similar access patterns
- Throughput is dynamically allocated to containers based on demand
- Maximum 25 containers per shared-throughput database (extendable via support)
- Minimum throughput: 100 RU/s per container
- Good for: microservices with many collections, multi-tenant with container-per-tenant

**Container-level (dedicated) throughput:**
- Use when containers have vastly different throughput needs
- Guarantees throughput isolation between containers
- Required for containers needing > total database throughput / container count
- Good for: high-throughput containers, containers with strict latency requirements

## Cost Management

### Reserved Capacity

Purchase reserved RU/s for significant discounts:
- **1-year reservation:** ~20% discount
- **3-year reservation:** ~30-65% discount (varies by region and commitment size)
- Reservations apply automatically to provisioned throughput across all accounts in the enrollment
- Does not apply to serverless consumption
- Calculate your steady-state baseline and reserve that amount; use autoscale for peaks above the reservation

### TTL for Automatic Data Expiry

Set Time-to-Live to automatically delete old data without consuming write RUs:

```json
// Container-level default TTL (seconds): -1 = off, 0 = never expire, N = expire after N seconds
// Set on container:
{ "defaultTtl": 2592000 }  // 30 days

// Per-item override:
{ "id": "temp-data", "ttl": 3600, ... }  // Expires in 1 hour

// Disable TTL for specific item in a TTL-enabled container:
{ "id": "permanent-data", "ttl": -1, ... }  // Never expires
```

### Right-Sizing Throughput

1. Monitor `NormalizedRUConsumption` metric -- if consistently below 30%, you are over-provisioned
2. Use autoscale to automatically scale down during low-traffic periods
3. Move dev/test workloads to serverless
4. Review per-container throughput -- consolidate low-usage containers into shared-throughput databases
5. Use Azure Advisor recommendations for Cosmos DB cost optimization

### Reducing Index Storage

Index storage counts toward your billable storage. Optimizing indexing policy reduces costs:
- Monitor `IndexUsage` metric (bytes used by indexes)
- Exclude paths not used in queries
- The default (index everything) can cause index storage to be 2-3x the raw data size
- For write-heavy workloads, aggressive exclusion can reduce write RU cost by 30-50%

## Monitoring Setup

### Essential Azure Monitor Metrics

Configure alerts on these metrics (all available in Azure Monitor with Cosmos DB resource provider):

| Metric | Alert Threshold | Meaning |
|---|---|---|
| `NormalizedRUConsumption` | > 70% sustained | Approaching throughput limit; scale up or optimize |
| `TotalRequestUnits` | Baseline deviation | Unexpected spike in RU consumption |
| `TotalRequests` (status 429) | > 0 sustained | Throttling occurring; increase throughput or fix hot partitions |
| `TotalRequests` (status 503) | > 0 | Service unavailability; check Azure status |
| `ServerSideLatency` (P99) | > 10ms (point reads) | Higher than expected latency |
| `DataUsage` | > 80% of limit | Approaching storage limits |
| `IndexUsage` | Increasing unexpectedly | Index bloat from unoptimized policy |
| `ProvisionedThroughput` | Sudden changes | Unexpected scaling events |
| `DocumentCount` | Baseline deviation | Unexpected data growth or deletion |
| `ReplicationLatency` | > 1000ms | Cross-region replication lag |
| `AvailableStorage` | < 20% remaining | Physical partition nearing 50 GB limit |

### Diagnostic Settings

Enable diagnostic logs and route to Log Analytics:

```bash
az monitor diagnostic-settings create \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --name "cosmos-diagnostics" \
  --workspace "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspace}" \
  --logs '[
    {"category": "DataPlaneRequests", "enabled": true},
    {"category": "QueryRuntimeStatistics", "enabled": true},
    {"category": "PartitionKeyStatistics", "enabled": true},
    {"category": "PartitionKeyRUConsumption", "enabled": true},
    {"category": "ControlPlaneRequests", "enabled": true}
  ]' \
  --metrics '[{"category": "Requests", "enabled": true}]'
```

### Key Diagnostic Log Categories

| Category | What It Captures | Use Case |
|---|---|---|
| `DataPlaneRequests` | Every data operation (reads, writes, queries) with RU cost, latency, status | Performance analysis, error investigation |
| `QueryRuntimeStatistics` | Query text, RU cost, execution time, document count | Query optimization |
| `PartitionKeyStatistics` | Top partition keys by storage | Identify storage skew |
| `PartitionKeyRUConsumption` | Top partition keys by RU consumption | Identify hot partitions |
| `ControlPlaneRequests` | Management operations (create/delete container, modify throughput) | Audit trail |

## Security Hardening

### Prefer Entra ID (AAD) Over Master Keys

```bash
# Assign built-in data contributor role
az cosmosdb sql role assignment create \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --role-definition-name "Cosmos DB Built-in Data Contributor" \
  --scope "/" \
  --principal-id "aad-principal-object-id"

# Assign built-in data reader role
az cosmosdb sql role assignment create \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --role-definition-name "Cosmos DB Built-in Data Reader" \
  --scope "/" \
  --principal-id "aad-principal-object-id"
```

### Disable Key-Based Authentication (When Ready)

```bash
az cosmosdb update \
  --name mycosmosaccount \
  --resource-group myrg \
  --disable-key-based-metadata-write-access true
```

### Enable Private Endpoints

```bash
az network private-endpoint create \
  --name cosmos-pe \
  --resource-group myrg \
  --vnet-name myVnet \
  --subnet mySubnet \
  --private-connection-resource-id "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --group-id Sql \
  --connection-name cosmos-pe-connection
```

### Network Restrictions

```bash
# Enable IP firewall
az cosmosdb update \
  --name mycosmosaccount \
  --resource-group myrg \
  --ip-range-filter "13.91.6.132,13.91.6.1/24"

# Add VNet rule
az cosmosdb network-rule add \
  --name mycosmosaccount \
  --resource-group myrg \
  --virtual-network myVnet \
  --subnet mySubnet
```

### Customer-Managed Keys

```bash
az cosmosdb create \
  --name mycosmosaccount \
  --resource-group myrg \
  --key-uri "https://mykeyvault.vault.azure.net/keys/mykey" \
  --assign-identity "[system]"
```

## Multi-Region Deployment Patterns

### Active-Passive (Single-Region Writes)

Best for most applications:
- One write region (e.g., East US)
- One or more read regions (e.g., West US, West Europe)
- Automatic failover enabled with explicit priority ordering
- Session consistency maintains read-your-writes within each region

```bash
# Create account with multiple regions
az cosmosdb create \
  --name mycosmosaccount \
  --resource-group myrg \
  --locations regionName="eastus" failoverPriority=0 isZoneRedundant=true \
  --locations regionName="westus" failoverPriority=1 isZoneRedundant=true \
  --default-consistency-level Session \
  --enable-automatic-failover true
```

### Active-Active (Multi-Region Writes)

For lowest write latency globally:
- All regions accept writes
- Requires conflict resolution policy
- Strong consistency is NOT available
- Higher cost (multi-region writes RU multiplier applies)

```bash
az cosmosdb create \
  --name mycosmosaccount \
  --resource-group myrg \
  --locations regionName="eastus" failoverPriority=0 isZoneRedundant=true \
  --locations regionName="westeurope" failoverPriority=1 isZoneRedundant=true \
  --locations regionName="southeastasia" failoverPriority=2 isZoneRedundant=true \
  --default-consistency-level Session \
  --enable-multiple-write-locations true
```

### Disaster Recovery Testing

Regularly test failover:
```bash
# Manual failover (single-region writes)
az cosmosdb failover-priority-change \
  --name mycosmosaccount \
  --resource-group myrg \
  --failover-policies "westus=0" "eastus=1"

# Note: this promotes West US to the write region
```

## Data Modeling

### Embed vs Reference

**Embed (denormalize)** when:
- The related data is always read together with the parent
- The related data has a bounded, small size
- The related data changes infrequently
- 1:1 or 1:few relationships

**Reference (normalize)** when:
- The related data is large or unbounded
- The related data is frequently updated independently
- The related data is shared across many parent items
- Many:many relationships

### Denormalization Example

```json
// Embedded (good for read-heavy, bounded relationships)
{
  "id": "order-123",
  "partitionKey": "customer-456",
  "customer": {
    "name": "Jane Doe",
    "email": "jane@example.com"
  },
  "items": [
    { "productId": "prod-1", "name": "Widget", "price": 9.99, "qty": 2 },
    { "productId": "prod-2", "name": "Gadget", "price": 24.99, "qty": 1 }
  ],
  "total": 44.97
}

// Referenced (good for large, unbounded, or shared data)
{
  "id": "order-123",
  "partitionKey": "customer-456",
  "customerId": "customer-456",
  "itemIds": ["item-1", "item-2"],
  "total": 44.97
}
```

### Change Feed for Materialized Views

Use change feed to maintain denormalized views:
1. Write normalized data to the source container
2. Change feed processor reads changes and writes denormalized views to a target container with a different partition key
3. This gives you efficient single-partition reads from the materialized view container
4. The change feed processor guarantees at-least-once delivery

## Stored Procedures Best Practices

- Execute within a single logical partition only
- Use for transactional operations that need atomicity across multiple items
- Bounded execution time -- long-running procedures will be terminated
- Implement continuation patterns for operations that might exceed time limits
- Pre-compile and test thoroughly -- JavaScript errors are hard to debug in production
- Prefer transactional batch API over stored procedures for simple multi-item transactions

## Backup and Restore Strategy

### Continuous Backup (Recommended)

```bash
# Enable continuous backup with 30-day retention
az cosmosdb create \
  --name mycosmosaccount \
  --resource-group myrg \
  --backup-policy-type Continuous \
  --continuous-tier Continuous30Days \
  --locations regionName="eastus" failoverPriority=0

# Migrate existing account from periodic to continuous
az cosmosdb update \
  --name mycosmosaccount \
  --resource-group myrg \
  --backup-policy-type Continuous \
  --continuous-tier Continuous30Days
```

### Point-in-Time Restore

```bash
# List restorable accounts
az cosmosdb restorable-database-account list \
  --location "eastus"

# Restore to a new account
az cosmosdb restore \
  --target-database-account-name mycosmosaccount-restored \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --restore-timestamp "2026-04-07T10:00:00Z" \
  --location "eastus"
```
