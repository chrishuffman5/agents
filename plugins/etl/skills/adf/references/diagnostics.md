# ADF Diagnostics

## Connectivity Failures

### Symptoms

- "Cannot connect to data source"
- "The remote name could not be resolved"
- Timeout errors on Copy Activity or Lookup Activity
- "Login failed" or "Access denied"

### Diagnostic Steps

1. **Verify linked service credentials**: Test Connection in ADF Studio. Check for expired passwords, rotated keys, or changed SAS tokens.
2. **Check IR type**: Is the activity using the correct IR? On-premises sources require SHIR. Private endpoints require Managed VNET Azure IR.
3. **Firewall rules**: Verify ADF IP ranges are whitelisted on the data source, or use managed private endpoints to bypass firewall restrictions entirely.
4. **DNS resolution**: If using SHIR, test DNS resolution from the SHIR machine. If using Managed VNET, verify the managed private endpoint is approved and DNS resolves to a private IP.
5. **NSG rules**: If the data source is in a VNet, verify NSG allows inbound traffic on the required port (1433 for SQL, 443 for HTTPS, etc.).
6. **Key Vault access**: If the linked service references Key Vault, verify the ADF managed identity has Get/List permissions on the Key Vault access policy.

### Common Resolutions

| Problem | Fix |
|---|---|
| Expired credentials | Rotate password/key in Key Vault; linked service picks up new value automatically |
| Firewall blocking ADF | Add ADF IP ranges or switch to managed private endpoints |
| DNS failure on SHIR | Configure DNS on the SHIR machine or add hosts file entries |
| Private endpoint not approved | Approve the managed private endpoint in the target resource's networking settings |
| NSG blocking traffic | Add inbound allow rule for the required port from the ADF subnet |
| Managed Identity not authorized | Grant the ADF managed identity the required role on the target resource (e.g., Storage Blob Data Contributor) |

## Integration Runtime Issues

### Self-Hosted IR Offline

**Symptoms**: Activities fail with "IR is offline" or "Cannot reach the integration runtime".

**Diagnostic steps**:
1. Check Windows service `DIAHostService` is running on the SHIR machine
2. Verify outbound HTTPS connectivity to `*.servicebus.windows.net` and `*.frontend.clouddatahub.net` on port 443
3. Check proxy configuration in `diahostservice.exe.config` if behind a corporate proxy
4. Verify TLS 1.2 is enabled on the SHIR machine (older TLS versions are rejected)
5. Review Windows Event Viewer (Application log) for SHIR-related errors
6. Run the built-in SHIR diagnostic tool: it tests ADF backend connectivity, DNS resolution for configured sources, and network paths to endpoints. Generates an HTML report.

**Common fixes**:
- Restart `DIAHostService` Windows service
- Update proxy settings to include ADF service endpoints
- Enable TLS 1.2 in Windows registry
- Update expired SSL certificates on data sources
- If auto-update failed, manually install the latest SHIR version

### Self-Hosted IR High Resource Usage

**Symptoms**: Activities slow or fail, SHIR machine CPU > 80%, memory exhaustion.

**Diagnostic steps**:
1. Check ADF Monitor Hub for SHIR node metrics (CPU, memory, concurrent activities)
2. Review concurrent activity count vs node capacity (~20 concurrent Copy instances per node by default)
3. Check if large data volumes are being processed through the SHIR

**Resolutions**:
- Scale out: add additional SHIR nodes (active-active, up to 4 per logical IR)
- Reduce concurrent activity limit on the SHIR
- Stagger pipeline schedules to reduce concurrent load
- Move large cloud-to-cloud copies to Azure IR (they don't need SHIR)

### Azure-SSIS IR Startup Failures

**Symptoms**: IR status shows "Starting" indefinitely or transitions to "Error".

**Common causes and fixes**:

| Cause | Diagnostic | Fix |
|---|---|---|
| SSISDB server unreachable | Check firewall rules on Azure SQL/MI | Add ADF subnet or Azure-SSIS IR public IPs to firewall |
| Insufficient permissions | Check SSISDB login permissions | Grant db_owner on SSISDB to the configured account |
| Custom setup script failure | Check provisioning logs in ADF Studio | Fix the setup script; verify SAS URI is valid and container is accessible |
| VNet misconfiguration | Check DNS, NSG, UDR in the target VNet | Allow ports 1433, 443, 11000-11999; configure DNS to resolve SSISDB hostname |
| License issues | Check IR provisioning error message | Use Standard tier unless Enterprise features are required |

**Expected provisioning times**:
- Standard: 20-30 minutes
- With VNet join: up to 40 minutes
- With custom setup: additional time depending on script duration

## Data Type Mapping Issues

### Symptoms

- "Type conversion failure"
- "Cannot cast value"
- Truncation warnings in copy output
- Null values in unexpected columns

### Diagnostic Steps

1. Compare source and sink schemas: check data types, precision, scale, and nullable settings
2. Review column mapping in Copy Activity: verify explicit mappings are correct
3. Check copy activity output for `rowsSkipped` count and skipped row log location
4. For Data Flows, check the Assert transformation output for data quality violations

### Common Resolutions

| Issue | Fix |
|---|---|
| Decimal precision/scale mismatch | Use explicit type conversion in column mapping or Derived Column |
| Datetime format mismatch | Specify format string in source/sink dataset properties |
| Encoding issues (UTF-8 vs extended) | Set encoding explicitly on CSV/text dataset properties |
| Null in non-nullable sink column | Add default value handling in Data Flow (coalesce) or Copy Activity column mapping |
| String truncation | Increase target column size or truncate in source query |

**Fault tolerance**: Enable "Skip incompatible rows" in Copy Activity to continue processing and log problem rows for later review. Set maximum skip percentage to fail the pipeline if data quality degrades.

## Copy Activity Performance Issues

### Symptoms

- Low throughput (MB/s below expectations)
- Long copy duration relative to data volume
- High DIU allocation with low actual utilization

### Diagnostic Framework

Check these metrics in Copy Activity output:

| Metric | What It Tells You |
|---|---|
| `throughput` (KBps) | Actual data transfer rate |
| `usedDataIntegrationUnits` | DIU actually used (may be less than allocated) |
| `copyDuration` (seconds) | Total execution time |
| `rowsRead` / `rowsCopied` | Row counts (difference = skipped rows) |
| `dataRead` / `dataWritten` (bytes) | Data volume |

### Tuning Checklist

1. **DIU**: Increase incrementally (4 -> 8 -> 16 -> 32 -> 64). If throughput does not increase with more DIU, the bottleneck is elsewhere.
2. **Parallel copy**: Enable for partitioned sources. Configure partition options (physical or dynamic range).
3. **Staging**: Enable for PolyBase/COPY into Synapse. Use SSD-backed storage accounts for staging.
4. **Network**: Ensure IR and data stores are in the same Azure region. Cross-region adds latency.
5. **Source bottleneck**: Check source query execution time independently. Add indexes or optimize the query.
6. **Sink bottleneck**: For database sinks, check for lock contention, insufficient DTUs, or missing indexes. For file sinks, check storage throttling.
7. **Format**: Use Parquet or Delta for large datasets (columnar compression reduces data volume).
8. **Small files**: Many small files create scheduling overhead. Consolidate or use wildcard paths.

### Common Bottleneck Patterns

| Symptom | Likely Cause | Fix |
|---|---|---|
| High DIU but low throughput | Source cannot feed data fast enough | Optimize source query, add indexes, use partitioned reads |
| Throughput drops during copy | Sink throttling (DTU limits, storage IOPS) | Scale up sink, use staging, reduce parallel copy |
| Long "queue" time in copy details | IR busy with other activities | Scale out SHIR nodes or increase Azure IR compute |
| Copy succeeds but takes hours | No parallelism on large table | Enable partitioned reads + parallel copy |

## Data Flow Performance Issues

### Symptoms

- Data flow execution takes much longer than expected
- Spark stages show high shuffle or spill metrics
- Cluster utilization is low despite large data volume

### Diagnostic Steps

1. Open Data Flow monitoring in ADF Monitor Hub
2. Review Spark execution details: stage times, partition counts, data volume per stage
3. Check for data skew: one partition processes significantly more data than others
4. Check for shuffle-heavy operations: large joins without broadcast, group-by on high-cardinality keys

### Tuning Actions

| Issue | Action |
|---|---|
| Cold start adds 3-5 minutes | Enable TTL on the Azure IR |
| Data skew on joins | Hash partition both sides on the join key before the join |
| Large reference data in Lookup | Enable broadcast on the small side |
| Too many transformations | Combine Derived Column logic; remove unnecessary Selects |
| Verbose logging | Switch to Basic logging in production |
| Cluster too small | Increase core count; try Memory Optimized for join-heavy flows |
| Source reads too much data | Push filters to source query; project only needed columns early |

## Trigger Issues

### Schedule Trigger Not Firing

1. Verify trigger is in "Started" state (not Stopped or runtime-failed)
2. Check trigger run history in Monitor Hub for error details
3. Verify schedule cron expression matches expected pattern
4. Check timezone setting on the trigger

### Storage Event Trigger Missing Events

1. Verify Event Grid subscription is active (check Event Grid resource in Azure portal)
2. Verify blob path prefix and suffix filters match the actual file names and paths
3. Expected latency: 1-2 minutes from file arrival to pipeline start
4. Check if the storage account has Event Grid resource provider registered
5. For ADLS Gen2: verify hierarchical namespace is enabled (required for some event trigger configurations)

### Tumbling Window Backlog

1. Check for failed previous windows: dependencies block downstream windows
2. Clear or rerun failed windows to unblock the chain
3. Verify trigger dependency configuration if triggers are chained
4. Check concurrency setting: how many windows can run simultaneously
5. For backfill: set the start time to the desired historical date; ADF will process all windows from start to current

## Debugging Workflows

### Pipeline Debug Mode

1. Open pipeline in ADF Studio
2. Click "Debug" to start an interactive run (no trigger or publish needed)
3. Set breakpoints on activities to pause execution at specific points
4. Inspect activity input, output, and duration in real time
5. Use "Add trigger" -> "Trigger now" with test parameters for trigger simulation

### Data Flow Debug

1. Enable debug cluster (toggle in ADF Studio Data Flow editor)
2. Cluster takes 3-5 minutes to start (or instant if TTL is active)
3. Use Data Preview at each transformation step to inspect intermediate data
4. Evaluate expressions in real time with the expression builder
5. Test schema drift handling with sample data
6. Debug session timeout: default 60 minutes, configurable up to 480 minutes
7. Debug cluster charges vCore-hours. Use TTL during active development sessions.

### Expression Debugging

Common expression issues:
- Missing `@` prefix: `pipeline().parameters.x` should be `@pipeline().parameters.x`
- Function syntax errors: verify function names and parameter types in the expression builder
- Null handling: use `@coalesce(value, default)` or `@if(equals(value, null), default, value)`
- Date formatting: verify format strings match source data patterns (`yyyy-MM-dd'T'HH:mm:ss`)
- String concatenation: `@concat(string1, string2)` not `string1 + string2`

### Activity Output Inspection

Key output fields by activity type:

**Copy Activity**:
- `@activity('Copy').output.rowsRead` / `rowsCopied` / `rowsSkipped`
- `@activity('Copy').output.dataRead` / `dataWritten`
- `@activity('Copy').output.throughput`
- `@activity('Copy').output.copyDuration`
- `@activity('Copy').output.usedDataIntegrationUnits`
- `@activity('Copy').output.errors` (array)

**Lookup Activity**:
- `@activity('Lookup').output.value` (array of records)
- `@activity('Lookup').output.count`
- `@activity('Lookup').output.firstRow.columnName`

**Web Activity**:
- `@activity('Web').output.statusCode`
- `@activity('Web').output.headers`
- `@activity('Web').output.body` (parsed JSON)

**Get Metadata Activity**:
- `@activity('GetMeta').output.exists`
- `@activity('GetMeta').output.itemName`
- `@activity('GetMeta').output.childItems` (for folder listing)
- `@activity('GetMeta').output.columnCount` / `structure`

## Cost Analysis

### Identifying Cost Drivers

Use Azure Cost Management to break down ADF costs by meter:

| Meter | What It Measures | How to Reduce |
|---|---|---|
| Orchestration | Activity execution count | Metadata-driven patterns, consolidate activities |
| Data Movement | DIU-hours for Copy Activity | Right-size DIU, incremental loads |
| Data Flow Execution | vCore-hours | TTL management, cluster right-sizing, reserved capacity |
| Data Flow Debug | vCore-hours for debug clusters | Limit debug session duration, use TTL |
| Pipeline Runs | Pipeline execution count | Consolidate triggers, event-driven instead of polling |
| SSIS Standard/Enterprise | Node-hours | Stop IR when idle, schedule start/stop |

### Cost Investigation Workflow

1. **Azure Cost Management**: Filter by ADF resource, group by meter. Identify which meter dominates.
2. **Monitor Hub**: Review pipeline run history. Identify pipelines with highest activity counts or longest durations.
3. **Copy Activity output**: Check `usedDataIntegrationUnits` and `copyDuration`. Over-provisioned DIU wastes money.
4. **Data Flow monitoring**: Check cluster utilization. Low utilization suggests over-provisioned clusters.
5. **Trigger analysis**: Check for overlapping or unnecessary trigger schedules. Replace polling with event-driven triggers.
6. **SSIS IR uptime**: Verify the Azure-SSIS IR is stopped when not executing packages.

### Reserved Capacity

For steady Data Flow workloads, reserved capacity provides significant savings:

| Term | Rate (GP) | Savings vs Pay-As-You-Go |
|---|---|---|
| Pay-as-you-go | ~$0.274/vCore-hr | Baseline |
| 1-year reserved | ~$0.205/vCore-hr | ~25% |
| 3-year reserved | ~$0.178/vCore-hr | ~35% |

Evaluate reserved capacity when Data Flow vCore-hours are consistent month-over-month.

## KQL Queries for Log Analytics

### Failed Pipeline Runs (Last 24 Hours)

```kql
ADFPipelineRun
| where Status == "Failed"
| where TimeGenerated > ago(24h)
| project TimeGenerated, PipelineName, RunId, FailureType, ErrorMessage = tostring(parse_json(ErrorMessage))
| order by TimeGenerated desc
```

### Long-Running Activities

```kql
ADFActivityRun
| where TimeGenerated > ago(7d)
| where Status == "Succeeded"
| extend DurationMinutes = datetime_diff('minute', End, Start)
| where DurationMinutes > 30
| project TimeGenerated, PipelineName, ActivityName, ActivityType, DurationMinutes
| order by DurationMinutes desc
```

### Copy Activity Throughput Analysis

```kql
ADFActivityRun
| where ActivityType == "Copy"
| where Status == "Succeeded"
| where TimeGenerated > ago(7d)
| extend Output = parse_json(Output)
| extend RowsCopied = tolong(Output.rowsCopied), DataWrittenMB = toreal(Output.dataWritten) / 1048576, ThroughputKBps = toreal(Output.throughput), DIU = tolong(Output.usedDataIntegrationUnits)
| project TimeGenerated, PipelineName, ActivityName, RowsCopied, DataWrittenMB, ThroughputKBps, DIU
| order by TimeGenerated desc
```

### IR Node Health

```kql
ADFIntegrationRuntimeLog
| where TimeGenerated > ago(24h)
| where Level == "Error" or Level == "Warning"
| project TimeGenerated, IntegrationRuntimeName, NodeName, Level, Message
| order by TimeGenerated desc
```
