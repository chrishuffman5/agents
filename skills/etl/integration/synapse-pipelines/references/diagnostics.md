# Synapse Pipelines Diagnostics

## Pipeline Failures

### Common Pipeline Failure Patterns

**Activity Timeout Failures**
- **Symptom**: Activity fails with timeout error after the default 7-day or configured timeout period
- **Causes**: Downstream system unresponsive, network connectivity issues, long-running queries, insufficient compute
- **Resolution**: Check downstream system health; increase timeout if legitimately long-running; optimize the underlying query or data movement; verify IR connectivity

**Copy Activity Failures**
- **Symptom**: Copy Activity fails with data type conversion errors, authentication failures, or throttling
- **Common causes**:
  - Schema mismatch between source and sink (column type incompatibility)
  - Authentication token expired or managed identity not granted access
  - Source or sink throttling (storage IOPS limits, SQL DTU limits)
  - File split issues when loading CSV into dedicated SQL pool (known issue)
- **Resolution**: Validate schema mapping; check managed identity permissions on source/sink; review throttling limits; for CSV file split issues, disable file split as workaround. Check Copy Activity detailed output for row-level error logs.

**Execute Pipeline Activity Failures**
- **Symptom**: Child pipeline fails, causing parent pipeline to fail
- **Resolution**: Check the child pipeline run independently in Monitor hub. Errors propagate up -- the root cause is in the innermost failed activity.

**Data Flow Failures**
- **Symptom**: Data flow activity fails with Spark exceptions (OutOfMemoryError, task failures)
- **Common causes**: Insufficient cluster resources, data skew, unhandled schema drift, network connectivity from managed VNET
- **Resolution**: Increase data flow compute size; add repartition transformations; enable schema drift handling; verify managed private endpoints for sources/sinks

**Trigger Failures**
- **Symptom**: Pipeline does not execute at expected time; trigger runs show failures
- **Common causes**:
  - Trigger not published or not started (must be explicitly published and activated)
  - Storage event trigger filter mismatch (folder path or file extension not matching actual files)
  - Tumbling window trigger dependency chain failure (upstream window failed)
- **Resolution**: Verify trigger is in "Started" state; check trigger run history; for storage events, validate blob path pattern and event subscription; for tumbling windows, rerun failed upstream windows

### Pipeline Debugging Approach

1. **Monitor hub**: Start in Pipeline runs view; filter by status "Failed"
2. **Activity run details**: Click into the failed pipeline run for individual activity statuses
3. **Error message**: Click the failed activity's error icon for detailed error message and error code
4. **Input/Output**: Review activity's input and output JSON for runtime parameter values and returned data
5. **Diagnostic logs**: If Monitor hub detail is insufficient, check Log Analytics for `SynapseIntegrationPipelineRuns` and `SynapseIntegrationActivityRuns` tables
6. **Rerun**: Use "Rerun from failed activity" to retry without re-executing successful upstream activities

## Spark Job Errors

### Common Spark Failures

**OutOfMemoryError (Driver or Executor)**
- **Symptom**: `java.lang.OutOfMemoryError: Java heap space` or `GC overhead limit exceeded`
- **Causes**: Driver collecting too much data (`collect()`, `toPandas()`), insufficient executor memory, data skew
- **Resolution**:
  - Avoid collecting large datasets to the driver; use write operations instead
  - Increase node size (Medium to Large) for more memory per executor
  - Enable auto-scale to add executors
  - Repartition skewed data with `.repartition()` before expensive operations

**Storage API Throttling**
- **Symptom**: Tasks fail with HTTP 429 or 503 errors when reading/writing to ADLS Gen2
- **Causes**: Exceeding storage account IOPS or bandwidth limits; too many parallel tasks hitting the same account
- **Resolution**: Reduce parallelism (`spark.sql.shuffle.partitions`); spread data across multiple storage accounts; use hierarchical namespace-enabled storage; implement exponential backoff retry

**Spark-SQL Pool Connector Errors**
- **Symptom**: `COPY statement input file schema discovery failed: Cannot bulk load. The file does not exist or you don't have file access rights`
- **Causes**: Permission issues on the staging storage account; incompatible file format; transient staging file cleanup
- **Resolution**: Verify Spark pool's managed identity has **Storage Blob Data Contributor** on the staging ADLS Gen2 account; ensure the staging directory exists and is accessible; retry the operation

**Library Conflicts**
- **Symptom**: `ImportError`, `ClassNotFoundException`, or unexpected behavior after installing custom packages
- **Causes**: Version conflicts between pool-level and session-level libraries; incompatible transitive dependencies
- **Resolution**: Review pool-level vs session-level library configurations; use `%%configure` magic to specify exact versions; test in an isolated session before adding to pool

**Session Startup Failures**
- **Symptom**: `Session is in DEAD state` or `Failed to start Spark session`
- **Causes**: Pool capacity exhausted, misconfigured settings, managed VNET connectivity issues
- **Resolution**: Check pool utilization in Monitor hub; wait for running sessions to complete or scale the pool; verify VNET/private endpoint configuration

### Spark Diagnostic Tools

- **Spark UI**: Synapse Studio Monitor hub > Apache Spark applications > click application > Spark UI. Shows stages, tasks, executors, DAG, SQL plan.
- **Spark History Server**: Retained logs for completed applications; accessible after pool auto-pauses.
- **Log Analytics**: `SynapseBigDataPoolApplicationsEnded` table for job completion data and duration.
- **Executor logs**: Under Executors tab in Spark UI; check stderr for stack traces.
- **Driver logs**: Under driver stdout/stderr; primary location for application-level errors.

### Spark Performance Investigation

1. Check **Spark UI Jobs tab** for failed or slow stages
2. Examine **Stages tab** for task distribution (look for skew -- one task much longer than others)
3. Review **Executor tab** for memory usage, GC time, and shuffle volumes
4. Check **SQL tab** (if using Spark SQL) for physical plan and scan statistics
5. Review **Environment tab** for suboptimal Spark configuration

## SQL Pool Issues

### Dedicated SQL Pool Common Issues

**TempDB Exhaustion**
- **Symptom**: Queries fail with TempDB space or memory allocation errors
- **Causes**: Large CTAS operations; data skew causing shuffle-heavy ShuffleMove operations; incompatible join distributions
- **Root cause identification**: Check distributed query plan for ShuffleMove operations; query `sys.dm_pdw_nodes_db_file_space_usage` for TempDB consumption
- **Resolution**: Fix distribution skew (use Distribution Advisor); eliminate incompatible joins by co-locating tables on the same distribution key; scale up DWUs (every DW100c adds 399 GB TempDB); break large CTAS into smaller batches

**Data Skew**
- **Symptom**: Queries slow; one distribution processes disproportionately more data
- **Detection**: `DBCC PDW_SHOWSPACEUSED('table_name')` shows row counts per distribution; large variance indicates skew
- **Common cause**: Distributing on a column with many NULLs (all NULLs land in the same distribution) or low-cardinality columns
- **Resolution**: Use Distribution Advisor for a better key; round-robin for staging tables; REPLICATE for small dimension tables

```sql
-- Detect distribution skew
DBCC PDW_SHOWSPACEUSED('dbo.fact_orders');

-- Check TempDB usage across distributions
SELECT node_id, SUM(internal_object_reserved_page_count) * 8 / 1024 AS tempdb_used_mb
FROM sys.dm_pdw_nodes_db_file_space_usage
GROUP BY node_id
ORDER BY tempdb_used_mb DESC;
```

**DWU Scaling Issues**
- **Symptom**: Queries slow or timing out; high resource utilization
- **Scaling behavior**: During scaling, pool enters "Scaling" mode; active queries may be affected
- **Resolution**: Scale during low-usage windows; automate with Azure Automation; monitor DWU percentage via Azure Portal

**Concurrency and Workload Management**
- **Symptom**: Queries queued for extended periods
- **Causes**: Exceeding concurrency limits (varies by DWU); large resource class assignments consuming too many slots
- **Resolution**: Review `sys.dm_pdw_exec_requests` for queued queries; reduce resource class for less critical queries; scale up DWUs; implement workload groups and classifiers for priority-based scheduling

```sql
-- Check queued queries
SELECT request_id, status, submit_time, start_time, total_elapsed_time,
       resource_class, importance
FROM sys.dm_pdw_exec_requests
WHERE status = 'Running' OR status = 'Suspended'
ORDER BY submit_time;
```

**Statistics Issues**
- **Symptom**: Poor query plans; suboptimal data movement patterns
- **Detection**: Query statistics DMVs for NULL stats_name or stats_date
- **Resolution**: Manually create statistics on frequently filtered and joined columns; enable AUTO_CREATE_STATISTICS

### Serverless SQL Pool Issues

**Cost Overruns**
- **Symptom**: Unexpected charges
- **Causes**: Scanning CSV files (full scan); missing partition pruning; queries without WHERE clauses on partitioned data
- **Resolution**: Convert to Parquet or Delta; use Hive-style partitioning; add partition filters; set `sp_set_query_limits`

**OPENROWSET Errors**
- **Symptom**: `OPENROWSET bulk load failed` or `External table not found`
- **Causes**: Incorrect file path; missing storage permissions; unsupported format; credential misconfiguration
- **Resolution**: Verify ADLS Gen2 path; grant workspace managed identity Storage Blob Data Reader on the storage account; validate format specification

## Integration Runtime Connectivity

### Azure IR Issues

**Managed VNET Connectivity Failures**
- **Symptom**: Activities fail with "unable to connect" when Managed VNET is enabled
- **Causes**: Missing managed private endpoints; private endpoint not approved on target; DNS resolution failures
- **Resolution**: Create managed private endpoints for all target Azure services; approve pending connections on target resources; verify DNS resolution

**Data Exfiltration Protection Blocks**
- **Symptom**: Outbound connections to external APIs or third-party services fail
- **Cause**: DEP restricts outbound to approved Microsoft Entra tenants only; external APIs outside approved tenants are blocked
- **Resolution**: Add target service's Entra tenant to approved list (if possible). If target is not an Azure service, DEP may fundamentally prevent the connection. **DEP cannot be disabled once enabled** -- evaluate appropriateness before enabling.

**Data Flow Cluster Startup Timeout**
- **Symptom**: Data flow activity runs for several minutes then fails with startup timeout
- **Causes**: Cold start on Azure IR without TTL; insufficient capacity in the region
- **Resolution**: Enable TTL on Azure IR to keep clusters warm; try a different region; retry

### Self-Hosted IR Issues

**SHIR Offline**
- **Symptom**: Activities using SHIR fail; IR shows "Offline" or "Limited" in Monitor hub
- **Causes**: SHIR service stopped; network connectivity lost; expired registration key; firewall blocking outbound HTTPS (443)
- **Resolution**: Check Integration Runtime Configuration Manager on SHIR host; verify Windows service is running; test outbound connectivity to `*.servicebus.windows.net` and `*.frontend.clouddatahub.net`; re-register if key expired

**SHIR Performance Degradation**
- **Symptom**: Copy activities via SHIR are slow; high CPU or memory on SHIR machine
- **Causes**: Machine undersized; too many concurrent jobs; network bandwidth constraints
- **Resolution**: Monitor CPU/memory/network; increase machine resources; add SHIR nodes for HA and load distribution; limit concurrent jobs per node

**SHIR Version Mismatch**
- **Symptom**: Unexpected failures or unsupported feature errors
- **Resolution**: Enable auto-update on SHIR; or manually update to latest version from the Microsoft Download Center

## Monitoring and Alerting

### Synapse Studio Monitor Hub

- **Pipeline runs**: Status, duration, trigger info, drill into activity-level details
- **Trigger runs**: Verify fire times, associated pipeline runs, trigger status
- **Apache Spark applications**: Running and completed jobs with Spark UI links
- **SQL requests**: Active and recent queries on dedicated and serverless pools
- **Integration Runtimes**: IR status, version, node count, resource utilization

### Azure Monitor and Log Analytics

**Enable diagnostic settings**:
1. Synapse workspace in Azure Portal > Monitoring > Diagnostic settings
2. Select log categories: IntegrationPipelineRuns, IntegrationActivityRuns, IntegrationTriggerRuns, BigDataPoolAppsEnded, SQLSecurityAuditEvents, SynapseSQLPoolExecRequests
3. Send to a Log Analytics workspace

**Key Log Analytics tables**:

| Table | Contents |
|---|---|
| `SynapseIntegrationPipelineRuns` | Pipeline run ID, name, status, start/end, duration, trigger info |
| `SynapseIntegrationActivityRuns` | Activity details, input/output, errors, duration |
| `SynapseIntegrationTriggerRuns` | Trigger fire events, status, associated pipeline |
| `SynapseBigDataPoolApplicationsEnded` | Spark job completion, duration, status |
| `SynapseSqlPoolExecRequests` | Dedicated SQL pool query execution details |
| `SynapseSqlPoolDmsWorkers` | Data movement service worker activity |

### KQL Queries

**Failed pipelines (last 24 hours)**:
```kql
SynapseIntegrationPipelineRuns
| where Status == "Failed"
| where TimeGenerated > ago(24h)
| project PipelineName, RunId, TriggerName, TriggerType, ErrorMessage
| order by TimeGenerated desc
```

**Long-running activities**:
```kql
SynapseIntegrationActivityRuns
| where TimeGenerated > ago(24h)
| extend DurationMinutes = datetime_diff('minute', End, Start)
| where DurationMinutes > 30
| project PipelineName, ActivityName, ActivityType, DurationMinutes, Status
| order by DurationMinutes desc
```

**Spark job durations**:
```kql
SynapseBigDataPoolApplicationsEnded
| where TimeGenerated > ago(7d)
| extend DurationMinutes = DurationMs / 60000.0
| project SparkPoolName, ApplicationName, DurationMinutes, State
| order by DurationMinutes desc
```

### Alerting Configuration

- **Azure Monitor alerts** on pipeline failure counts, long-running activities, and Spark job failures
- **Action groups**: Email, SMS, Azure Function, Logic App, or webhook notifications
- **Metric alerts**: Threshold alerts on dedicated SQL pool DWU percentage, active queries, TempDB utilization
- **Log alerts**: KQL-based alert rules for custom conditions (specific pipelines failing, error patterns)
- **Azure Service Health**: Subscribe to Synapse Analytics service health events for platform-level incidents
