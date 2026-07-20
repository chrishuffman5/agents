# Azure Cosmos DB Diagnostics Reference

## Account Information

### az cosmosdb show -- Account Details

```bash
az cosmosdb show \
  --name mycosmosaccount \
  --resource-group myrg
```

Key output fields:
| Field | Meaning | Concerning Values |
|---|---|---|
| `consistencyPolicy.defaultConsistencyLevel` | Account default consistency | Unexpected level (e.g., Strong when you expected Session) |
| `enableMultipleWriteLocations` | Multi-region writes enabled | `false` when you need multi-region writes |
| `enableAutomaticFailover` | Automatic failover enabled | `false` in production single-write accounts |
| `readLocations` / `writeLocations` | Configured regions | Missing expected regions |
| `backupPolicy.type` | Backup type (Periodic or Continuous) | Periodic when PITR is needed |
| `isVirtualNetworkFilterEnabled` | VNet filtering active | `false` in production (no network restrictions) |
| `ipRules` | IP firewall rules | Empty in production (open to all) |
| `publicNetworkAccess` | Public access status | `Enabled` when private endpoints should be exclusive |
| `disableLocalAuth` | Key-based auth disabled | `false` when Entra-only is desired |
| `enableFreeTier` | Free tier discount applied | Only one per subscription |

### az cosmosdb list -- All Accounts in Subscription

```bash
# List all accounts
az cosmosdb list --output table

# List with specific fields
az cosmosdb list --query "[].{name:name, rg:resourceGroup, location:location, consistency:consistencyPolicy.defaultConsistencyLevel}" --output table
```

### az cosmosdb keys list -- Access Keys

```bash
# List read-write keys
az cosmosdb keys list \
  --name mycosmosaccount \
  --resource-group myrg

# List read-only keys
az cosmosdb keys list \
  --name mycosmosaccount \
  --resource-group myrg \
  --type read-only-keys
```

Output fields: `primaryMasterKey`, `secondaryMasterKey`, `primaryReadonlyMasterKey`, `secondaryReadonlyMasterKey`

**Security concern:** If keys are compromised, regenerate immediately:
```bash
az cosmosdb keys regenerate \
  --name mycosmosaccount \
  --resource-group myrg \
  --key-kind primary
```

### az cosmosdb list-connection-strings -- Connection Strings

```bash
az cosmosdb list-connection-strings \
  --name mycosmosaccount \
  --resource-group myrg
```

Returns connection strings for all APIs (SQL, MongoDB, Cassandra, Gremlin, Table).

### Account Capabilities

```bash
# Check enabled capabilities
az cosmosdb show \
  --name mycosmosaccount \
  --resource-group myrg \
  --query "capabilities[].name" --output tsv
```

Common capabilities: `EnableServerless`, `EnableMongo`, `EnableCassandra`, `EnableGremlin`, `EnableTable`, `EnableNoSQLVectorSearch`

## Database and Container Diagnostics

### az cosmosdb sql database list -- List Databases

```bash
az cosmosdb sql database list \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --output table
```

### az cosmosdb sql database show -- Database Details

```bash
az cosmosdb sql database show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --name mydatabase
```

### az cosmosdb sql container list -- List Containers

```bash
az cosmosdb sql container list \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --output table

# With detailed info
az cosmosdb sql container list \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --query "[].{name:name, partitionKey:resource.partitionKey.paths[0], indexingPolicy:resource.indexingPolicy.indexingMode, defaultTtl:resource.defaultTtl}"
```

### az cosmosdb sql container show -- Container Details

```bash
az cosmosdb sql container show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --name mycontainer
```

Key output fields:
| Field | Meaning | Concerning Values |
|---|---|---|
| `resource.partitionKey.paths` | Partition key path(s) | Verify correct key design |
| `resource.partitionKey.kind` | `Hash` or `MultiHash` | `MultiHash` = hierarchical partition keys |
| `resource.indexingPolicy` | Full indexing policy | Default `/*` may be over-indexing |
| `resource.defaultTtl` | TTL setting | -1 = disabled, 0 = no default expiry |
| `resource.uniqueKeyPolicy` | Unique constraints | Verify expected constraints |
| `resource.conflictResolutionPolicy` | Conflict resolution mode | Unexpected mode in multi-region writes |
| `resource.analyticalStorageTtl` | Analytical store TTL | -1 = disabled, null = not configured |

### Container Indexing Policy

```bash
# View indexing policy
az cosmosdb sql container show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --name mycontainer \
  --query "resource.indexingPolicy"

# Update indexing policy (pass JSON file)
az cosmosdb sql container update \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --name mycontainer \
  --idx @indexing-policy.json
```

### MongoDB API -- Database and Collection Info

```bash
# List MongoDB databases
az cosmosdb mongodb database list \
  --account-name mycosmosaccount \
  --resource-group myrg

# List collections
az cosmosdb mongodb collection list \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydb

# Show collection details
az cosmosdb mongodb collection show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydb \
  --name mycollection
```

### Cassandra API -- Keyspace and Table Info

```bash
# List keyspaces
az cosmosdb cassandra keyspace list \
  --account-name mycosmosaccount \
  --resource-group myrg

# List tables
az cosmosdb cassandra table list \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --keyspace-name mykeyspace

# Show table details
az cosmosdb cassandra table show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --keyspace-name mykeyspace \
  --name mytable
```

### Gremlin API -- Database and Graph Info

```bash
# List Gremlin databases
az cosmosdb gremlin database list \
  --account-name mycosmosaccount \
  --resource-group myrg

# List graphs
az cosmosdb gremlin graph list \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydb

# Show graph details
az cosmosdb gremlin graph show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydb \
  --name mygraph
```

### Table API -- Table Info

```bash
# List tables
az cosmosdb table list \
  --account-name mycosmosaccount \
  --resource-group myrg

# Show table details
az cosmosdb table show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --name mytable
```

## Throughput Diagnostics

### az cosmosdb sql container throughput show -- Current Throughput

```bash
# Container-level throughput
az cosmosdb sql container throughput show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --name mycontainer
```

Key output fields:
| Field | Meaning | Concerning Values |
|---|---|---|
| `resource.throughput` | Current provisioned RU/s | Very high or very low for the workload |
| `resource.autoscaleSettings.maxThroughput` | Autoscale max RU/s | Too low for peak traffic |
| `resource.minimumThroughput` | Minimum allowed RU/s | High minimum prevents scaling down |
| `resource.offerReplacePending` | Throughput change in progress | `true` means scaling is not yet complete |

### Database-Level Throughput

```bash
az cosmosdb sql database throughput show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --name mydatabase
```

### Update Throughput

```bash
# Set manual throughput
az cosmosdb sql container throughput update \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --name mycontainer \
  --throughput 10000

# Set autoscale max throughput
az cosmosdb sql container throughput update \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --name mycontainer \
  --max-throughput 10000
```

### Migrate Between Throughput Modes

```bash
# Migrate from manual to autoscale
az cosmosdb sql container throughput migrate \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --name mycontainer \
  --throughput-type autoscale

# Migrate from autoscale to manual
az cosmosdb sql container throughput migrate \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --name mycontainer \
  --throughput-type manual
```

### MongoDB Throughput

```bash
az cosmosdb mongodb collection throughput show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydb \
  --name mycollection

az cosmosdb mongodb collection throughput update \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydb \
  --name mycollection \
  --throughput 5000
```

### Cassandra Throughput

```bash
az cosmosdb cassandra table throughput show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --keyspace-name mykeyspace \
  --name mytable

az cosmosdb cassandra table throughput update \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --keyspace-name mykeyspace \
  --name mytable \
  --throughput 5000
```

### Gremlin Throughput

```bash
az cosmosdb gremlin graph throughput show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydb \
  --name mygraph

az cosmosdb gremlin graph throughput update \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydb \
  --name mygraph \
  --throughput 5000
```

### Table API Throughput

```bash
az cosmosdb table throughput show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --name mytable

az cosmosdb table throughput update \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --name mytable \
  --throughput 5000
```

## Partition Diagnostics

### Partition Key Statistics via REST API

```bash
# Get partition key ranges (physical partitions)
# REST API call
curl -s -H "Authorization: type%3Dmaster%26ver%3D1.0%26sig%3D{token}" \
  -H "x-ms-version: 2020-07-15" \
  -H "x-ms-date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')" \
  "https://{account}.documents.azure.com/dbs/{db}/colls/{collection}/pkranges" | jq '.PartitionKeyRanges[] | {id, minInclusive, maxExclusive}'
```

### Physical Partition Throughput via Azure Monitor (Kusto)

```kql
// Top partition keys by RU consumption (last 1 hour)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "PartitionKeyRUConsumption"
| where TimeGenerated > ago(1h)
| summarize TotalRU = sum(todouble(requestCharge_s)) by partitionKey_s, bin(TimeGenerated, 5m)
| order by TotalRU desc
| take 20
```

### Physical Partition Storage via Azure Monitor (Kusto)

```kql
// Top partition keys by storage
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "PartitionKeyStatistics"
| where TimeGenerated > ago(24h)
| project TimeGenerated, partitionKey_s, sizeKb_d
| order by sizeKb_d desc
| take 20
```

### Hot Partition Detection

```kql
// Detect hot partitions: partitions consuming > 2x average RU
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "PartitionKeyRUConsumption"
| where TimeGenerated > ago(1h)
| summarize TotalRU = sum(todouble(requestCharge_s)) by partitionKey_s
| extend AvgRU = toscalar(
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.DOCUMENTDB"
    | where Category == "PartitionKeyRUConsumption"
    | where TimeGenerated > ago(1h)
    | summarize avg(todouble(requestCharge_s))
  )
| where TotalRU > AvgRU * 2
| order by TotalRU desc
```

### Partition Count via Azure Monitor Metric

```bash
# Physical partition count (Azure Monitor REST API)
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "PhysicalPartitionCount" \
  --interval PT1H \
  --start-time "2026-04-07T00:00:00Z" \
  --end-time "2026-04-07T12:00:00Z"
```

## Query Metrics and Performance

### x-ms-request-charge Header -- RU Cost Per Request

Every Cosmos DB response includes the RU cost:

**.NET SDK:**
```csharp
ItemResponse<MyItem> response = await container.ReadItemAsync<MyItem>("id", new PartitionKey("pk"));
Console.WriteLine($"RU charge: {response.RequestCharge}");

// For queries
FeedIterator<MyItem> iterator = container.GetItemQueryIterator<MyItem>("SELECT * FROM c WHERE c.status = 'active'");
double totalRU = 0;
while (iterator.HasMoreResults)
{
    FeedResponse<MyItem> page = await iterator.ReadNextAsync();
    totalRU += page.RequestCharge;
    Console.WriteLine($"Page RU: {page.RequestCharge}, Items: {page.Count}");
}
Console.WriteLine($"Total RU: {totalRU}");
```

**Java SDK:**
```java
CosmosItemResponse<MyItem> response = container.readItem("id", new PartitionKey("pk"), MyItem.class);
System.out.println("RU charge: " + response.getRequestCharge());
```

**REST API:**
Check the `x-ms-request-charge` response header on every response.

### Query Metrics via Response Headers

The `x-ms-documentdb-query-metrics` header provides detailed query execution metrics:

| Metric | Meaning | Concerning Values |
|---|---|---|
| `totalExecutionTimeInMs` | Total query time | > 100ms for simple queries |
| `queryCompilationTimeInMs` | Time to compile query | > 10ms (complex query or missing index) |
| `logicalPlanBuildTimeInMs` | Time to build logical plan | > 5ms |
| `physicalPlanBuildTimeInMs` | Time to build physical plan | > 5ms |
| `queryOptimizationTimeInMs` | Time to optimize query | > 5ms |
| `indexLookupTimeInMs` | Time spent in index lookup | High = large index scan |
| `documentLoadTimeInMs` | Time loading documents | High = large documents or many results |
| `systemFunctionExecuteTimeInMs` | Time in system functions | High = heavy CONTAINS, ARRAY_CONTAINS use |
| `userFunctionExecuteTimeInMs` | Time in UDFs | High = expensive UDF; consider removing |
| `retrievedDocumentCount` | Docs retrieved from index | Much higher than outputDocumentCount = inefficient filter |
| `retrievedDocumentSize` | Bytes retrieved | High = large documents or missing projection |
| `outputDocumentCount` | Docs returned to client | Compare with retrievedDocumentCount |
| `writeOutputTimeInMs` | Time serializing output | High = large output |

### Index Utilization via Response Headers

The `x-ms-documentdb-index-utilization` header shows which indexes were used:

```
Index Utilization:
  Utilized Single Indexes:
    /status/?  (filter: c.status = 'active')
  Potential Single Indexes:
    /priority/?  (filter: c.priority > 5)
  Utilized Composite Indexes: none
  Potential Composite Indexes:
    (/status ASC, /createdAt DESC)  (order by: ORDER BY c.status, c.createdAt DESC)
```

**Key insight:** "Potential" indexes are recommended but not present. Adding them will significantly reduce RU cost for those queries.

### Enable Query Metrics in SDK

**.NET SDK:**
```csharp
QueryRequestOptions options = new QueryRequestOptions
{
    PopulateIndexMetrics = true  // Enables x-ms-documentdb-index-utilization header
};
FeedIterator<MyItem> iterator = container.GetItemQueryIterator<MyItem>(
    "SELECT * FROM c WHERE c.status = 'active'",
    requestOptions: options
);
while (iterator.HasMoreResults)
{
    FeedResponse<MyItem> page = await iterator.ReadNextAsync();
    Console.WriteLine($"Index metrics: {page.IndexMetrics}");
}
```

**Java SDK:**
```java
CosmosQueryRequestOptions options = new CosmosQueryRequestOptions();
options.setIndexMetricsEnabled(true);
CosmosPagedIterable<MyItem> items = container.queryItems(
    "SELECT * FROM c WHERE c.status = 'active'", options, MyItem.class);
```

## Consistency Diagnostics

### Check Account Default Consistency

```bash
az cosmosdb show \
  --name mycosmosaccount \
  --resource-group myrg \
  --query "consistencyPolicy"
```

Output:
```json
{
  "defaultConsistencyLevel": "Session",
  "maxIntervalInSeconds": 5,
  "maxStalenessPrefix": 100
}
```

For Bounded Staleness, `maxIntervalInSeconds` and `maxStalenessPrefix` define the staleness window.

### Session Token Tracking

```csharp
// Capture session token from a write
ItemResponse<MyItem> writeResponse = await container.CreateItemAsync(item, new PartitionKey("pk"));
string sessionToken = writeResponse.Headers.Session;

// Pass session token to a read on a different client instance
ItemRequestOptions readOptions = new ItemRequestOptions
{
    SessionToken = sessionToken
};
ItemResponse<MyItem> readResponse = await container.ReadItemAsync<MyItem>("id", new PartitionKey("pk"), readOptions);
```

### Consistency Level per Request

```csharp
// Check effective consistency level in response headers
ItemResponse<MyItem> response = await container.ReadItemAsync<MyItem>("id", new PartitionKey("pk"));
// x-ms-session-token in response headers confirms the session vector
Console.WriteLine($"Session token: {response.Headers.Session}");
```

### Replication Lag Monitoring

```bash
# Check replication latency metric
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "ReplicationLatency" \
  --interval PT5M \
  --start-time "2026-04-07T00:00:00Z" \
  --end-time "2026-04-07T12:00:00Z" \
  --dimension "SourceRegion" "TargetRegion"
```

Concerning threshold: > 1000ms sustained replication latency indicates cross-region issues.

## Global Distribution Diagnostics

### List Regions

```bash
az cosmosdb show \
  --name mycosmosaccount \
  --resource-group myrg \
  --query "{writeLocations:writeLocations[].{region:locationName, priority:failoverPriority}, readLocations:readLocations[].{region:locationName, priority:failoverPriority}}"
```

### Failover Priority

```bash
# View current failover priority
az cosmosdb show \
  --name mycosmosaccount \
  --resource-group myrg \
  --query "failoverPolicies[].{region:locationName, priority:failoverPriority}" --output table

# Change failover priority (promote westus to primary)
az cosmosdb failover-priority-change \
  --name mycosmosaccount \
  --resource-group myrg \
  --failover-policies "westus=0" "eastus=1"
```

### Add/Remove Regions

```bash
# Add a region
az cosmosdb update \
  --name mycosmosaccount \
  --resource-group myrg \
  --locations regionName="eastus" failoverPriority=0 isZoneRedundant=true \
  --locations regionName="westus" failoverPriority=1 isZoneRedundant=true \
  --locations regionName="westeurope" failoverPriority=2 isZoneRedundant=true

# Remove a region (omit it from the locations list)
az cosmosdb update \
  --name mycosmosaccount \
  --resource-group myrg \
  --locations regionName="eastus" failoverPriority=0 isZoneRedundant=true \
  --locations regionName="westus" failoverPriority=1 isZoneRedundant=true
```

### Service-Level Availability Check

```bash
# Check Azure service health for Cosmos DB
az monitor activity-log list \
  --resource-group myrg \
  --offset 24h \
  --query "[?contains(resourceType, 'Microsoft.DocumentDB')].{time:eventTimestamp, status:status.value, operation:operationName.value}" \
  --output table
```

## Change Feed Diagnostics

### Change Feed Processor Monitoring

**.NET SDK -- Estimator for lag:**
```csharp
// Create a change feed estimator to monitor lag
Container leaseContainer = database.GetContainer("leases");
ChangeFeedProcessor estimator = container
    .GetChangeFeedEstimatorBuilder("estimator", HandleEstimation, TimeSpan.FromSeconds(5))
    .WithLeaseContainer(leaseContainer)
    .Build();

await estimator.StartAsync();

static async Task HandleEstimation(
    long estimatedPendingChanges,
    CancellationToken cancellationToken)
{
    Console.WriteLine($"Estimated lag: {estimatedPendingChanges} changes");
    // Alert if lag > threshold
}
```

**Detailed per-partition lag:**
```csharp
ChangeFeedEstimator estimator = container.GetChangeFeedEstimator("processorName", leaseContainer);
using FeedIterator<ChangeFeedProcessorState> iterator = estimator.GetCurrentStateIterator();
while (iterator.HasMoreResults)
{
    FeedResponse<ChangeFeedProcessorState> states = await iterator.ReadNextAsync();
    foreach (ChangeFeedProcessorState state in states)
    {
        Console.WriteLine($"Lease: {state.LeaseToken}, Estimated lag: {state.EstimatedLag}, Owner: {state.InstanceName}");
    }
}
```

### Change Feed via REST API

```bash
# Read change feed from beginning for a partition key range
curl -s \
  -H "Authorization: type%3Dmaster%26ver%3D1.0%26sig%3D{token}" \
  -H "x-ms-version: 2020-07-15" \
  -H "x-ms-date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')" \
  -H "A-IM: Incremental feed" \
  -H "x-ms-documentdb-partitionkeyrangeid: 0" \
  "https://{account}.documents.azure.com/dbs/{db}/colls/{collection}/docs"
```

Response headers:
- `x-ms-continuation`: Pass in next request to get subsequent changes
- `etag`: Current LSN of the partition range
- Empty body with 304 status: no new changes

## Azure Monitor Metrics

### Essential Metrics via CLI

```bash
# Total Request Units consumed
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "TotalRequestUnits" \
  --interval PT5M \
  --start-time "2026-04-07T00:00:00Z" \
  --end-time "2026-04-07T12:00:00Z" \
  --aggregation Total

# Total Requests with status code dimension
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "TotalRequests" \
  --interval PT5M \
  --dimension "StatusCode" \
  --start-time "2026-04-07T00:00:00Z" \
  --end-time "2026-04-07T12:00:00Z"

# Normalized RU Consumption (per partition, 0-100%)
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "NormalizedRUConsumption" \
  --interval PT5M \
  --aggregation Maximum \
  --start-time "2026-04-07T00:00:00Z" \
  --end-time "2026-04-07T12:00:00Z"

# Data Usage (bytes)
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "DataUsage" \
  --interval PT1H \
  --aggregation Total

# Index Usage (bytes)
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "IndexUsage" \
  --interval PT1H \
  --aggregation Total

# Document Count
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "DocumentCount" \
  --interval PT1H \
  --aggregation Total

# Server Side Latency (P99)
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "ServerSideLatency" \
  --interval PT5M \
  --aggregation "P99"

# Provisioned Throughput
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "ProvisionedThroughput" \
  --interval PT1H \
  --aggregation Maximum

# Available Storage per partition
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "AvailableStorage" \
  --interval PT1H \
  --aggregation Total

# Metadata Requests
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "MetadataRequests" \
  --interval PT5M \
  --aggregation Count

# Replication Latency
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "ReplicationLatency" \
  --interval PT5M \
  --aggregation Average \
  --dimension "SourceRegion" "TargetRegion"
```

### Metric Concerning Thresholds

| Metric | Warning | Critical |
|---|---|---|
| `NormalizedRUConsumption` (Max) | > 70% sustained | > 90% sustained (429s imminent) |
| `TotalRequests` status 429 | > 1% of total requests | > 5% of total requests |
| `TotalRequests` status 503 | Any occurrence | Sustained occurrences |
| `ServerSideLatency` P99 | > 10ms (point reads), > 100ms (queries) | > 50ms (point reads), > 500ms (queries) |
| `ReplicationLatency` | > 500ms average | > 2000ms average |
| `DataUsage` | > 80% of provisioned storage | > 90% of provisioned storage |
| `AvailableStorage` | < 10 GB per partition | < 5 GB per partition |
| `DocumentCount` | Unexpected rapid growth | Sudden drop (accidental deletion) |

## Diagnostic Logs (Kusto/KQL)

### Prerequisites

Enable diagnostic settings to send logs to a Log Analytics workspace (see best-practices.md for the CLI command).

### DataPlaneRequests -- All Operations

```kql
// All requests in the last hour with their RU cost and status
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| where TimeGenerated > ago(1h)
| project TimeGenerated, operationType_s, statusCode_s, requestCharge_s, durationMs_d,
          databaseName_s, collectionName_s, partitionKey_s, userAgent_s, requestResourceType_s
| order by TimeGenerated desc
| take 100

// 429 (throttled) requests
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| where statusCode_s == "429"
| where TimeGenerated > ago(1h)
| summarize ThrottledCount = count() by bin(TimeGenerated, 5m), databaseName_s, collectionName_s
| order by ThrottledCount desc

// High-RU operations (> 100 RU)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| where todouble(requestCharge_s) > 100
| where TimeGenerated > ago(1h)
| project TimeGenerated, operationType_s, requestCharge_s, durationMs_d,
          databaseName_s, collectionName_s, partitionKey_s
| order by todouble(requestCharge_s) desc
| take 50

// Slow operations (> 50ms)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| where durationMs_d > 50
| where TimeGenerated > ago(1h)
| project TimeGenerated, operationType_s, durationMs_d, requestCharge_s,
          databaseName_s, collectionName_s, statusCode_s
| order by durationMs_d desc
| take 50

// Operation type breakdown with average RU and latency
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| where TimeGenerated > ago(1h)
| summarize
    Count = count(),
    AvgRU = avg(todouble(requestCharge_s)),
    P99Latency = percentile(durationMs_d, 99),
    AvgLatency = avg(durationMs_d),
    ErrorCount = countif(statusCode_s !in ("200", "201", "204"))
  by operationType_s
| order by Count desc

// RU consumption per container
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| where TimeGenerated > ago(1h)
| summarize TotalRU = sum(todouble(requestCharge_s)), RequestCount = count()
  by databaseName_s, collectionName_s
| order by TotalRU desc

// Client user agent breakdown (identify which apps are consuming resources)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| where TimeGenerated > ago(1h)
| summarize TotalRU = sum(todouble(requestCharge_s)), RequestCount = count()
  by userAgent_s
| order by TotalRU desc
| take 20
```

### QueryRuntimeStatistics -- Query Performance

```kql
// Most expensive queries by RU
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "QueryRuntimeStatistics"
| where TimeGenerated > ago(24h)
| project TimeGenerated, querytext_s, requestCharge_s, durationMs_d,
          databaseName_s, collectionName_s
| order by todouble(requestCharge_s) desc
| take 20

// Queries that run frequently with high total RU
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "QueryRuntimeStatistics"
| where TimeGenerated > ago(24h)
| summarize
    ExecutionCount = count(),
    TotalRU = sum(todouble(requestCharge_s)),
    AvgRU = avg(todouble(requestCharge_s)),
    MaxRU = max(todouble(requestCharge_s)),
    AvgDuration = avg(durationMs_d)
  by querytext_s
| order by TotalRU desc
| take 20

// Cross-partition queries (fan-out indicator)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "QueryRuntimeStatistics"
| where todouble(requestCharge_s) > 50
| where TimeGenerated > ago(24h)
| project TimeGenerated, querytext_s, requestCharge_s, durationMs_d
| order by todouble(requestCharge_s) desc
| take 20
```

### PartitionKeyStatistics -- Storage Distribution

```kql
// Top partition keys by storage (identify storage skew)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "PartitionKeyStatistics"
| where TimeGenerated > ago(24h)
| project TimeGenerated, partitionKey_s, sizeKb_d, databaseName_s, collectionName_s
| order by sizeKb_d desc
| take 50
```

### PartitionKeyRUConsumption -- Throughput Distribution

```kql
// Top partition keys by RU consumption (identify hot partitions)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "PartitionKeyRUConsumption"
| where TimeGenerated > ago(1h)
| summarize TotalRU = sum(todouble(requestCharge_s))
  by partitionKey_s, databaseName_s, collectionName_s
| order by TotalRU desc
| take 20

// RU consumption trend per partition key over time
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "PartitionKeyRUConsumption"
| where TimeGenerated > ago(6h)
| summarize RU = sum(todouble(requestCharge_s))
  by partitionKey_s, bin(TimeGenerated, 15m)
| render timechart
```

### ControlPlaneRequests -- Management Operations Audit

```kql
// Recent control plane operations (create, delete, update)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "ControlPlaneRequests"
| where TimeGenerated > ago(7d)
| project TimeGenerated, operationType_s, httpStatusCode_d, resourceDetails_s,
          callerIdentity_s
| order by TimeGenerated desc
| take 50
```

## Backup and Restore Diagnostics

### Restorable Database Accounts

```bash
# List all restorable accounts (continuous backup enabled)
az cosmosdb restorable-database-account list \
  --location "eastus"

# Show specific restorable account
az cosmosdb restorable-database-account show \
  --location "eastus" \
  --instance-id "{instance-id}"
```

### Restorable Databases and Containers

```bash
# List restorable SQL databases
az cosmosdb sql restorable-database list \
  --location "eastus" \
  --instance-id "{instance-id}"

# List restorable SQL containers
az cosmosdb sql restorable-container list \
  --location "eastus" \
  --instance-id "{instance-id}" \
  --database-rid "{database-rid}"

# List restorable SQL resources (databases + containers) at a specific timestamp
az cosmosdb sql restorable-resource list \
  --location "eastus" \
  --instance-id "{instance-id}" \
  --restore-location "eastus" \
  --restore-timestamp "2026-04-07T10:00:00Z"
```

### Restore Operations

```bash
# Restore to a new account (SQL API)
az cosmosdb restore \
  --target-database-account-name mycosmosaccount-restored \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --restore-timestamp "2026-04-07T10:00:00Z" \
  --location "eastus" \
  --databases-to-restore name="mydb" collections="container1" "container2"

# Check periodic backup info
az cosmosdb show \
  --name mycosmosaccount \
  --resource-group myrg \
  --query "backupPolicy"
```

### Restorable Resources for MongoDB API

```bash
az cosmosdb mongodb restorable-database list \
  --location "eastus" \
  --instance-id "{instance-id}"

az cosmosdb mongodb restorable-collection list \
  --location "eastus" \
  --instance-id "{instance-id}" \
  --database-rid "{database-rid}"

az cosmosdb mongodb restorable-resource list \
  --location "eastus" \
  --instance-id "{instance-id}" \
  --restore-location "eastus" \
  --restore-timestamp "2026-04-07T10:00:00Z"
```

## Networking Diagnostics

### Network Rules

```bash
# List IP firewall rules
az cosmosdb show \
  --name mycosmosaccount \
  --resource-group myrg \
  --query "ipRules[].ipAddressOrRange"

# List VNet rules
az cosmosdb network-rule list \
  --name mycosmosaccount \
  --resource-group myrg

# Check public network access setting
az cosmosdb show \
  --name mycosmosaccount \
  --resource-group myrg \
  --query "publicNetworkAccess"
```

### Private Endpoint Status

```bash
# List private endpoint connections
az cosmosdb private-endpoint-connection list \
  --account-name mycosmosaccount \
  --resource-group myrg

# Show specific private endpoint connection
az cosmosdb private-endpoint-connection show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --name "{connection-name}"

# Check private endpoint connection status
az cosmosdb private-endpoint-connection list \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --query "[].{name:name, status:privateLinkServiceConnectionState.status, description:privateLinkServiceConnectionState.description}"
```

### DNS Resolution Check

```bash
# Verify private DNS resolution
nslookup mycosmosaccount.documents.azure.com

# Expected for private endpoint: resolves to private IP (10.x.x.x)
# If resolves to public IP: private DNS zone not configured correctly
```

## Indexing Diagnostics

### View Current Indexing Policy

```bash
az cosmosdb sql container show \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --name mycontainer \
  --query "resource.indexingPolicy" --output json
```

### Index Transformation Progress

After updating an indexing policy, track transformation progress:

**.NET SDK:**
```csharp
ContainerResponse response = await container.ReadContainerAsync(new ContainerRequestOptions
{
    PopulateQuotaInfo = true
});
// Check x-ms-documentdb-collection-index-transformation-progress header
Console.WriteLine($"Index transform progress: {response.Headers["x-ms-documentdb-collection-index-transformation-progress"]}%");
```

**REST API:**
```bash
# The response header x-ms-documentdb-collection-index-transformation-progress
# shows 0-100% progress of an ongoing index transformation
curl -s -D - \
  -H "Authorization: type%3Dmaster%26ver%3D1.0%26sig%3D{token}" \
  -H "x-ms-version: 2020-07-15" \
  -H "x-ms-date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')" \
  "https://{account}.documents.azure.com/dbs/{db}/colls/{collection}" \
  | grep "x-ms-documentdb-collection-index-transformation-progress"
```

### Index Usage vs Data Usage

```bash
# Compare index storage to data storage
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "DataUsage" "IndexUsage" \
  --interval PT1H \
  --aggregation Total
```

**Concerning:** If IndexUsage > 2x DataUsage, the indexing policy is likely too broad.

## SDK Diagnostics

### .NET SDK -- CosmosDiagnostics

Every SDK response includes `CosmosDiagnostics` with detailed timing breakdown:

```csharp
ItemResponse<MyItem> response = await container.ReadItemAsync<MyItem>("id", new PartitionKey("pk"));
CosmosDiagnostics diagnostics = response.Diagnostics;

// Summary string with latency breakdown
Console.WriteLine(diagnostics.ToString());

// Key information in the diagnostics string:
// - "ClientSideRequestStatistics": total request time, retries, regions contacted
// - "StoreResponseStatistics": per-replica timing
// - "AddressResolutionStatistics": DNS/address resolution timing
// - "PointOperationStatistics": point read specific metrics
// - "CosmosException diagnostics": error details with retry info
```

**What to look for in CosmosDiagnostics:**
| Component | Healthy | Concerning |
|---|---|---|
| Request latency | < 10ms point reads | > 50ms point reads |
| Number of retries | 0 | > 0 (indicates transient failures or 429s) |
| Regions contacted | 1 (preferred region) | > 1 (failover or cross-region reads) |
| Address resolution | < 1ms (cached) | > 100ms (stale cache, DNS issue) |
| Transport latency | < 5ms | > 20ms (network issues) |
| Backend latency | < 5ms | > 20ms (server-side bottleneck) |

### Java SDK -- CosmosDiagnostics

```java
CosmosItemResponse<MyItem> response = container.readItem("id", new PartitionKey("pk"), MyItem.class);
CosmosDiagnostics diagnostics = response.getDiagnostics();

// Full diagnostics string
System.out.println(diagnostics.toString());

// Duration
System.out.println("Duration: " + diagnostics.getDuration());

// Contact regions
System.out.println("Contacted regions: " + diagnostics.getContactedRegionNames());
```

### .NET SDK -- Enable Detailed Diagnostics for Slow/Failed Requests

```csharp
CosmosClient client = new CosmosClientBuilder(connectionString)
    .WithConnectionModeDirect()
    .WithCosmosClientTelemetryOptions(new CosmosClientTelemetryOptions
    {
        CosmosThresholdOptions = new CosmosThresholdOptions
        {
            PointOperationLatencyThreshold = TimeSpan.FromMilliseconds(50),
            NonPointOperationLatencyThreshold = TimeSpan.FromMilliseconds(500),
            RequestChargeThreshold = 100
        }
    })
    .Build();
```

### Python SDK Diagnostics

```python
from azure.cosmos import CosmosClient

client = CosmosClient(url, credential)
database = client.get_database_client("mydb")
container = database.get_container_client("mycontainer")

response = container.read_item(item="id", partition_key="pk")
# Access request charge
print(f"RU charge: {container.client_connection.last_response_headers['x-ms-request-charge']}")
```

## Cost Analysis

### RU Consumption Analysis via Azure Monitor

```bash
# Total RU consumption over 24 hours
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "TotalRequestUnits" \
  --interval PT1H \
  --aggregation Total \
  --start-time "2026-04-06T00:00:00Z" \
  --end-time "2026-04-07T00:00:00Z"
```

### RU Consumption by Operation Type (KQL)

```kql
// RU cost breakdown by operation type (last 24h)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| where TimeGenerated > ago(24h)
| summarize
    TotalRU = sum(todouble(requestCharge_s)),
    OperationCount = count(),
    AvgRU = avg(todouble(requestCharge_s))
  by operationType_s
| extend CostPct = round(TotalRU * 100.0 / toscalar(
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.DOCUMENTDB"
    | where Category == "DataPlaneRequests"
    | where TimeGenerated > ago(24h)
    | summarize sum(todouble(requestCharge_s))
  ), 1)
| order by TotalRU desc
```

### Azure Cost Management Queries

```bash
# Get Cosmos DB costs for current billing period
az consumption usage list \
  --subscription "{sub-id}" \
  --start-date "2026-04-01" \
  --end-date "2026-04-07" \
  --query "[?contains(instanceId, 'Microsoft.DocumentDB')].{resource:instanceName, cost:pretaxCost, usage:usageQuantity, unit:unitOfMeasure}" \
  --output table
```

### Identify Over-Provisioned Containers

```kql
// Containers with NormalizedRUConsumption consistently < 30% (over-provisioned)
AzureMetrics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where MetricName == "NormalizedRUConsumption"
| where TimeGenerated > ago(7d)
| summarize AvgNormalizedRU = avg(Maximum), MaxNormalizedRU = max(Maximum) by Resource
| where MaxNormalizedRU < 30
| order by AvgNormalizedRU asc
```

## Troubleshooting Playbooks

### Playbook: 429 (Request Rate Too Large) Throttling

**Symptoms:** HTTP 429 responses, increased latency, retries in SDK diagnostics.

**Step 1 -- Confirm throttling scope:**
```bash
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "TotalRequests" \
  --dimension "StatusCode" \
  --interval PT5M
```

**Step 2 -- Check if it's a hot partition:**
```kql
AzureDiagnostics
| where Category == "PartitionKeyRUConsumption"
| where TimeGenerated > ago(1h)
| summarize TotalRU = sum(todouble(requestCharge_s)) by partitionKey_s
| order by TotalRU desc
| take 10
```

**Step 3 -- Check NormalizedRUConsumption per partition:**
```bash
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "NormalizedRUConsumption" \
  --dimension "CollectionName" "PartitionKeyRangeId" \
  --interval PT5M \
  --aggregation Maximum
```

**Step 4 -- Resolution options:**
1. Increase throughput (manual or switch to autoscale)
2. Fix hot partition (change partition key or use hierarchical keys)
3. Optimize expensive queries (add composite indexes, reduce cross-partition queries)
4. Enable SDK retry with exponential backoff
5. Implement client-side rate limiting

### Playbook: High Server-Side Latency

**Step 1 -- Identify latency distribution:**
```bash
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "ServerSideLatency" \
  --interval PT5M \
  --aggregation "Average" "P99"
```

**Step 2 -- Identify slow operations:**
```kql
AzureDiagnostics
| where Category == "DataPlaneRequests"
| where durationMs_d > 100
| where TimeGenerated > ago(1h)
| project TimeGenerated, operationType_s, durationMs_d, requestCharge_s,
          databaseName_s, collectionName_s, partitionKey_s, statusCode_s
| order by durationMs_d desc
| take 50
```

**Step 3 -- Check if caused by throttling (429s cause queuing):**
```kql
AzureDiagnostics
| where Category == "DataPlaneRequests"
| where TimeGenerated > ago(1h)
| summarize AvgLatency = avg(durationMs_d), ThrottleCount = countif(statusCode_s == "429")
  by bin(TimeGenerated, 5m)
| render timechart
```

**Step 4 -- Check SDK connection mode:**
Ensure Direct mode (not Gateway) for lowest latency. Gateway mode adds a hop.

**Step 5 -- Check cross-region latency:**
If reads are being served from a remote region, add the client's closest region to the account.

### Playbook: Cross-Partition Query Optimization

**Step 1 -- Identify cross-partition queries:**
```kql
AzureDiagnostics
| where Category == "QueryRuntimeStatistics"
| where todouble(requestCharge_s) > 50
| where TimeGenerated > ago(24h)
| project querytext_s, requestCharge_s, durationMs_d
| order by todouble(requestCharge_s) desc
| take 20
```

**Step 2 -- Check for missing indexes:**
Enable `PopulateIndexMetrics` in the query and check the `x-ms-documentdb-index-utilization` header for "Potential" indexes.

**Step 3 -- Resolution:**
1. Add the partition key to the WHERE clause
2. Redesign the data model to co-locate related data
3. Use a materialized view pattern (change feed to a container with a different partition key)
4. Add composite indexes for ORDER BY queries
5. If the query aggregates data across all partitions, consider a separate analytics container

### Playbook: Partition Split Impact

**Step 1 -- Detect partition splits:**
```bash
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "PhysicalPartitionCount" \
  --interval PT1H
```

**Step 2 -- Correlate with 429 spike:**
Partition splits can cause transient 429 errors as throughput is redistributed. Check if 429 spikes align with partition count changes.

**Step 3 -- Monitor storage distribution:**
```kql
AzureDiagnostics
| where Category == "PartitionKeyStatistics"
| where TimeGenerated > ago(7d)
| summarize MaxSize = max(sizeKb_d) by partitionKey_s
| order by MaxSize desc
| take 20
```

### Playbook: Consistency-Related Issues

**Step 1 -- Verify account consistency level:**
```bash
az cosmosdb show --name mycosmosaccount --resource-group myrg --query "consistencyPolicy"
```

**Step 2 -- Check if per-request consistency override is being used:**
Review application code for `ConsistencyLevel` in request options.

**Step 3 -- For stale reads with Session consistency:**
- Verify session tokens are being propagated between client instances
- Check if requests are going to different SDK instances without session token sharing
- Ensure the SDK is using the same `CosmosClient` instance within a session

**Step 4 -- Check replication lag (multi-region):**
```bash
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "ReplicationLatency" \
  --interval PT5M \
  --dimension "SourceRegion" "TargetRegion"
```

### Playbook: Unexpected Cost Increase

**Step 1 -- Check RU consumption trend:**
```kql
AzureDiagnostics
| where Category == "DataPlaneRequests"
| where TimeGenerated > ago(7d)
| summarize TotalRU = sum(todouble(requestCharge_s)) by bin(TimeGenerated, 1h)
| render timechart
```

**Step 2 -- Identify what changed:**
```kql
// Compare operation breakdown this week vs last week
let thisWeek = AzureDiagnostics
| where Category == "DataPlaneRequests"
| where TimeGenerated > ago(7d) and TimeGenerated <= ago(0d)
| summarize RU_ThisWeek = sum(todouble(requestCharge_s)) by operationType_s;
let lastWeek = AzureDiagnostics
| where Category == "DataPlaneRequests"
| where TimeGenerated > ago(14d) and TimeGenerated <= ago(7d)
| summarize RU_LastWeek = sum(todouble(requestCharge_s)) by operationType_s;
thisWeek
| join kind=fullouter lastWeek on operationType_s
| extend Change_Pct = round((RU_ThisWeek - RU_LastWeek) * 100.0 / RU_LastWeek, 1)
| order by Change_Pct desc
```

**Step 3 -- Check for new expensive queries:**
```kql
AzureDiagnostics
| where Category == "QueryRuntimeStatistics"
| where TimeGenerated > ago(24h)
| summarize TotalRU = sum(todouble(requestCharge_s)), Count = count() by querytext_s
| order by TotalRU desc
| take 10
```

**Step 4 -- Check for throughput changes (control plane):**
```kql
AzureDiagnostics
| where Category == "ControlPlaneRequests"
| where TimeGenerated > ago(7d)
| where operationType_s contains "throughput" or operationType_s contains "Offer"
| project TimeGenerated, operationType_s, resourceDetails_s
| order by TimeGenerated desc
```

**Step 5 -- Check storage growth:**
```bash
az monitor metrics list \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}" \
  --metric "DataUsage" \
  --interval PT1D \
  --start-time "2026-03-07T00:00:00Z" \
  --end-time "2026-04-07T00:00:00Z"
```

## RBAC Diagnostics

### List Role Definitions

```bash
# List built-in roles
az cosmosdb sql role definition list \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --query "[].{id:name, roleName:roleName, type:type}" --output table
```

### List Role Assignments

```bash
az cosmosdb sql role assignment list \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --query "[].{id:name, principalId:principalId, roleDefinitionId:roleDefinitionId, scope:scope}" --output table
```

### Create Custom Role Definition

```bash
az cosmosdb sql role definition create \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --body '{
    "RoleName": "ReadOnlyAccess",
    "Type": "CustomRole",
    "AssignableScopes": ["/dbs/mydb/colls/mycontainer"],
    "Permissions": [{
      "DataActions": [
        "Microsoft.DocumentDB/databaseAccounts/readMetadata",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery"
      ]
    }]
  }'
```

## Container Throughput Redistribution

### Redistribute Throughput Across Physical Partitions

For advanced scenarios where you need to allocate more throughput to specific physical partitions:

```bash
# List physical partitions and their throughput
az cosmosdb sql container retrieve-partition-throughput \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --name mycontainer

# Redistribute throughput to a specific physical partition
az cosmosdb sql container redistribute-partition-throughput \
  --account-name mycosmosaccount \
  --resource-group myrg \
  --database-name mydatabase \
  --name mycontainer \
  --target-partition-info '[ {"partitionKeyRangeId":"0","throughputFraction":0.6}, {"partitionKeyRangeId":"1","throughputFraction":0.4} ]' \
  --source-partition-info '[]'
```

This is useful when you know a specific partition is hotter than others and you want to manually allocate more RU/s to it rather than scaling the entire container.

## Health and Availability Checks

### Quick Health Check Script

```bash
#!/bin/bash
ACCOUNT="mycosmosaccount"
RG="myrg"
SUB_ID="your-subscription-id"
RESOURCE="/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.DocumentDB/databaseAccounts/${ACCOUNT}"

echo "=== Account Status ==="
az cosmosdb show --name $ACCOUNT --resource-group $RG --query "{status:provisioningState, consistency:consistencyPolicy.defaultConsistencyLevel, multiWrite:enableMultipleWriteLocations, autoFailover:enableAutomaticFailover}" --output table

echo ""
echo "=== Regions ==="
az cosmosdb show --name $ACCOUNT --resource-group $RG --query "writeLocations[].{region:locationName, priority:failoverPriority, status:provisioningState}" --output table

echo ""
echo "=== Databases ==="
az cosmosdb sql database list --account-name $ACCOUNT --resource-group $RG --output table

echo ""
echo "=== 429 Errors (last 1 hour) ==="
az monitor metrics list --resource $RESOURCE --metric "TotalRequests" --dimension "StatusCode" --interval PT5M --aggregation Count --start-time "$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ')" --end-time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --query "value[0].timeseries[?metadatavalues[0].value=='429'].data[].total" --output tsv

echo ""
echo "=== NormalizedRU (last 1 hour) ==="
az monitor metrics list --resource $RESOURCE --metric "NormalizedRUConsumption" --interval PT5M --aggregation Maximum --start-time "$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ')" --end-time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --query "value[0].timeseries[0].data[].maximum" --output tsv

echo ""
echo "=== Server-Side Latency P99 (last 1 hour) ==="
az monitor metrics list --resource $RESOURCE --metric "ServerSideLatency" --interval PT5M --aggregation "P99" --start-time "$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ')" --end-time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --query "value[0].timeseries[0].data[].p99" --output tsv
```

### Connectivity Test

```bash
# Test connectivity to Cosmos DB endpoint
curl -s -o /dev/null -w "%{http_code} %{time_total}s" \
  "https://mycosmosaccount.documents.azure.com:443/"

# Expected: 401 (unauthorized but reachable) in < 0.5s
# If timeout: network/firewall issue
# If DNS failure: private endpoint DNS misconfiguration
```
