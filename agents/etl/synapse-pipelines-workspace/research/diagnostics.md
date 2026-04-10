# Azure Synapse Pipelines Diagnostics

## Pipeline Failures

### Common Pipeline Failure Patterns

**Activity Timeout Failures**
- **Symptom**: Activity fails with timeout error after the default 7-day or configured timeout period
- **Causes**: Downstream system unresponsive, network connectivity issues, long-running queries, insufficient compute
- **Resolution**: Check downstream system health; increase timeout if the operation is legitimately long-running; optimize the underlying query or data movement; verify integration runtime connectivity

**Copy Activity Failures**
- **Symptom**: Copy Activity fails with data type conversion errors, authentication failures, or throttling
- **Common causes**:
  - Schema mismatch between source and sink (column type incompatibility)
  - Authentication token expired or managed identity not granted access
  - Source or sink throttling (storage IOPS limits, SQL DTU limits)
  - File split issues when loading CSV into dedicated SQL pool via ADF (known issue -- disable file split as workaround)
- **Resolution**: Validate schema mapping; check managed identity permissions on source/sink; review source system throttling limits; check Copy Activity detailed output for row-level error logs

**Execute Pipeline Activity Failures**
- **Symptom**: Child pipeline fails, causing parent pipeline to fail
- **Resolution**: Check the child pipeline run independently in Monitor hub; errors propagate up -- the root cause is in the innermost failed activity

**Data Flow Failures**
- **Symptom**: Data flow activity fails with Spark exceptions (OutOfMemoryError, task failures)
- **Common causes**:
  - Insufficient cluster resources for data volume
  - Data skew causing a single partition to be oversized
  - Schema drift not handled (unexpected columns or types)
  - Network connectivity to source/sink from managed VNET
- **Resolution**: Increase data flow compute size; add repartition transformations to address skew; enable schema drift handling; verify managed private endpoints for sources/sinks

**Trigger Failures**
- **Symptom**: Pipeline does not execute at expected time; trigger runs show failures
- **Common causes**:
  - Trigger not published or not started (triggers must be explicitly published and activated)
  - Storage event trigger filter mismatch (folder path or file extension regex not matching actual files)
  - Tumbling window trigger dependency chain failure (upstream window failed)
- **Resolution**: Verify trigger is in "Started" state; check trigger run history in Monitor hub; for storage events, validate the blob path pattern and event subscription; for tumbling windows, rerun failed upstream windows

### Pipeline Debugging Approach
1. **Monitor hub**: Start in the Pipeline runs view; filter by status "Failed"
2. **Activity run details**: Click into the failed pipeline run to see individual activity statuses
3. **Error message**: Click the failed activity's error icon for the detailed error message and error code
4. **Input/Output**: Review the activity's input and output JSON for runtime parameter values and returned data
5. **Diagnostic logs**: If Monitor hub detail is insufficient, check Log Analytics for SynapseIntegrationPipelineRuns and SynapseIntegrationActivityRuns tables
6. **Rerun**: Use "Rerun from failed activity" to retry without re-executing successful upstream activities

---

## Spark Job Errors

### Common Spark Failures

**OutOfMemoryError (Driver or Executor)**
- **Symptom**: Job fails with `java.lang.OutOfMemoryError: Java heap space` or `GC overhead limit exceeded`
- **Causes**: Driver collecting too much data (collect(), toPandas() on large datasets), insufficient executor memory, data skew
- **Resolution**:
  - Avoid collecting large datasets to the driver; use write operations instead
  - Increase node size (Medium to Large) for more memory per executor
  - Enable auto-scale to add more executors
  - Repartition skewed data with `.repartition()` before expensive operations

**Storage API Limit / Throttling**
- **Symptom**: Tasks fail with HTTP 429 or 503 errors when reading/writing to ADLS Gen2
- **Causes**: Exceeding storage account IOPS or bandwidth limits; too many parallel tasks hitting the same storage account
- **Resolution**: Reduce parallelism (`spark.sql.shuffle.partitions`); spread data across multiple storage accounts; use hierarchical namespace-enabled storage; implement exponential backoff retry

**Spark-SQL Pool Connector Errors**
- **Symptom**: `COPY statement input file schema discovery failed: Cannot bulk load. The file does not exist or you don't have file access rights`
- **Causes**: Permission issues on the staging storage account; incompatible file format; transient staging file cleanup
- **Resolution**: Verify the Spark pool's managed identity has Storage Blob Data Contributor on the staging ADLS Gen2 account; ensure the staging directory exists and is accessible; retry the operation

**Library Conflicts**
- **Symptom**: `ImportError`, `ClassNotFoundException`, or unexpected behavior after installing custom packages
- **Causes**: Version conflicts between pool-level and session-level libraries; incompatible transitive dependencies
- **Resolution**: Review pool-level vs. session-level library configurations; use `%%configure` magic to specify exact versions; test library combinations in an isolated session before adding to pool

**Session Startup Failures**
- **Symptom**: Notebook or Spark job fails to start; `Session is in DEAD state` or `Failed to start Spark session`
- **Causes**: Pool capacity exhausted (all nodes in use); misconfigured pool settings; managed VNET connectivity issues
- **Resolution**: Check pool utilization in Monitor hub; wait for running sessions to complete or scale the pool; verify VNET/private endpoint configuration

### Spark Diagnostic Tools
- **Spark UI**: Access from Synapse Studio Monitor hub > Apache Spark applications > click the application > Spark UI; shows stages, tasks, executors, DAG, SQL plan
- **Spark History Server**: Retained logs for completed applications; accessible even after the pool auto-pauses
- **Diagnostic logs in Log Analytics**: `SynapseBigDataPoolApplicationsEnded` table contains job completion data, duration, and status
- **Executor logs**: Available in the Spark UI under the Executors tab; check stderr for stack traces
- **Driver logs**: Available under the driver's stdout/stderr; the primary location for application-level errors

### Spark Performance Investigation
1. Check the **Spark UI Jobs tab** for failed or slow stages
2. Examine the **Stages tab** for task distribution -- look for skew (one task taking much longer than others)
3. Review **Executor tab** for memory usage, GC time, and shuffle read/write volumes
4. Check **SQL tab** (if using Spark SQL) for physical plan and scan statistics
5. Review the **Environment tab** for Spark configuration values that may be suboptimal

---

## SQL Pool Issues

### Dedicated SQL Pool Common Issues

**TempDB Exhaustion**
- **Symptom**: Queries fail with errors related to TempDB space or memory allocation
- **Causes**: Large CTAS (CREATE TABLE AS SELECT) operations; data skew causing shuffle-heavy operations (ShuffleMove); incompatible join distributions
- **Root cause identification**: Check the distributed query plan for ShuffleMove operations; query `sys.dm_pdw_nodes_db_file_space_usage` for TempDB consumption
- **Resolution**: Fix data distribution skew (use Distribution Advisor); eliminate incompatible joins by co-locating tables on the same distribution key; scale up DWUs (every DW100c adds 399 GB of TempDB); break large CTAS into smaller batches

**Data Skew**
- **Symptom**: Queries are slow; one distribution processes disproportionately more data
- **Detection**: `DBCC PDW_SHOWSPACEUSED('table_name')` shows row counts per distribution; large variance indicates skew
- **Common cause**: Distributing on a column with many NULL values (all NULLs land in the same distribution) or a low-cardinality column
- **Resolution**: Use the Distribution Advisor to find a better distribution key; consider round-robin for staging tables; use REPLICATE for small dimension tables

**DWU Scaling Issues**
- **Symptom**: Queries are slow or timing out; pool shows high resource utilization
- **Scaling behavior**: When you scale, the pool enters "Scaling" mode temporarily, during which active queries may be affected
- **Resolution**: Scale during low-usage windows; use automated scaling via Azure Automation; monitor DWU percentage via Azure Portal metrics

**Concurrency and Workload Management**
- **Symptom**: Queries are queued for extended periods; "Queued" status in Monitor hub
- **Causes**: Exceeding concurrency limits (varies by DWU level); large resource class assignments consuming too many concurrency slots
- **Resolution**: Review `sys.dm_pdw_exec_requests` for queued queries; reduce resource class for less critical queries; scale up DWUs for more concurrency slots; implement workload groups and classifiers for priority-based scheduling

**Statistics Issues**
- **Symptom**: Poor query plans; suboptimal data movement patterns
- **Known issue**: In serverless SQL pool, statistics may fail to be created for certain columns, resulting in NULL stats_name or stats_date
- **Detection**: Query statistics DMVs; check for NULL stats_name or stats_date
- **Resolution**: Manually create statistics on frequently filtered and joined columns; enable AUTO_CREATE_STATISTICS

### Serverless SQL Pool Issues

**Cost Overruns**
- **Symptom**: Unexpected charges on serverless SQL pool
- **Causes**: Scanning CSV files (non-columnar = full scan); missing partition pruning; queries without WHERE clauses on partitioned data
- **Resolution**: Convert data to Parquet or Delta; use Hive-style partitioning; add partition filters to all queries; set `sp_set_query_limits` to cap data processed per query

**OPENROWSET Errors**
- **Symptom**: `OPENROWSET bulk load failed` or `External table not found`
- **Causes**: Incorrect file path; missing storage permissions; unsupported file format; credential misconfiguration
- **Resolution**: Verify the ADLS Gen2 path; grant the workspace managed identity Storage Blob Data Reader on the storage account; validate the file format specification

---

## Integration Runtime Connectivity

### Azure IR Issues

**Managed VNET Connectivity Failures**
- **Symptom**: Pipeline activities fail with "unable to connect" errors when Managed VNET is enabled
- **Causes**: Missing managed private endpoints for target resources; private endpoint not approved on the target resource; DNS resolution failures
- **Resolution**: Create managed private endpoints for all target Azure services; approve pending private endpoint connections on target resources; verify DNS resolution from within the managed VNET

**Data Exfiltration Protection Blocks**
- **Symptom**: Outbound connections to external APIs or third-party services fail
- **Cause**: DEP restricts all outbound traffic to approved Microsoft Entra tenants only; external APIs outside approved tenants are blocked
- **Resolution**: Add the target service's Microsoft Entra tenant to the approved list (if possible); if the target is not an Azure service, DEP may fundamentally prevent the connection -- evaluate whether DEP is appropriate for your use case before enabling (it cannot be disabled once set)

**Data Flow Cluster Startup Timeout**
- **Symptom**: Data flow activity runs for several minutes before failing with startup timeout
- **Causes**: Cold start on Azure IR without TTL; insufficient cluster capacity in the region
- **Resolution**: Enable TTL on the Azure IR to keep clusters warm; try a different Azure region if capacity is constrained; retry the operation

### Self-Hosted IR Issues

**SHIR Offline**
- **Symptom**: Activities using SHIR fail; IR shows "Offline" or "Limited" status in Monitor hub
- **Causes**: SHIR service stopped; network connectivity lost between SHIR machine and Azure; expired registration key; firewall blocking outbound HTTPS on port 443
- **Resolution**: Check the Integration Runtime Configuration Manager on the SHIR host machine; verify the SHIR Windows service is running; test outbound connectivity to `*.servicebus.windows.net` and `*.frontend.clouddatahub.net`; re-register if key expired

**SHIR Performance Degradation**
- **Symptom**: Copy activities via SHIR are slow; high CPU or memory on the SHIR machine
- **Causes**: SHIR machine undersized for concurrent activities; too many concurrent jobs sharing a single SHIR node; network bandwidth constraints
- **Resolution**: Monitor SHIR machine CPU, memory, and network utilization; increase machine resources; add SHIR nodes for high-availability and load distribution; limit concurrent jobs per node

**SHIR Version Mismatch**
- **Symptom**: Unexpected activity failures or unsupported feature errors
- **Cause**: SHIR version is outdated and missing patches or feature support
- **Resolution**: Enable auto-update on the SHIR; or manually update to the latest version from the Microsoft Download Center

---

## Monitoring and Alerting

### Synapse Studio Monitor Hub
- **Pipeline runs**: View status, duration, trigger info, and drill into activity-level details
- **Trigger runs**: Verify trigger fire times, associated pipeline runs, and trigger status
- **Apache Spark applications**: View running and completed Spark jobs with links to Spark UI
- **SQL requests**: Monitor active and recent queries on dedicated and serverless SQL pools
- **Integration Runtimes**: Check IR status, version, node count, and resource utilization

### Azure Monitor and Log Analytics

**Enabling Diagnostic Settings**
1. Navigate to the Synapse workspace in Azure Portal
2. Under Monitoring > Diagnostic settings, add a diagnostic setting
3. Select log categories: IntegrationPipelineRuns, IntegrationActivityRuns, IntegrationTriggerRuns, BigDataPoolAppsEnded, SQLSecurityAuditEvents, SynapseSQLPoolExecRequests
4. Send to a Log Analytics workspace

**Key Log Analytics Tables**
| Table | Contents |
|---|---|
| `SynapseIntegrationPipelineRuns` | Pipeline run ID, name, status, start/end time, duration, trigger info |
| `SynapseIntegrationActivityRuns` | Activity run details, input/output, error messages, duration |
| `SynapseIntegrationTriggerRuns` | Trigger fire events, status, associated pipeline |
| `SynapseBigDataPoolApplicationsEnded` | Spark application completion data, duration, status |
| `SynapseSqlPoolExecRequests` | Dedicated SQL pool query execution details |
| `SynapseSqlPoolDmsWorkers` | Data movement service worker activity |

**Example KQL Queries**

Failed pipelines in last 24 hours:
```kql
SynapseIntegrationPipelineRuns
| where Status == "Failed"
| where TimeGenerated > ago(24h)
| project PipelineName, RunId, TriggerName, TriggerType, ErrorMessage
| order by TimeGenerated desc
```

Long-running activities:
```kql
SynapseIntegrationActivityRuns
| where TimeGenerated > ago(24h)
| extend DurationMinutes = datetime_diff('minute', End, Start)
| where DurationMinutes > 30
| project PipelineName, ActivityName, ActivityType, DurationMinutes, Status
| order by DurationMinutes desc
```

Spark job durations:
```kql
SynapseBigDataPoolApplicationsEnded
| where TimeGenerated > ago(7d)
| extend DurationMinutes = DurationMs / 60000.0
| project SparkPoolName, ApplicationName, DurationMinutes, State
| order by DurationMinutes desc
```

### Alerting Configuration
- **Create Azure Monitor alerts** on pipeline failure counts, long-running activities, and Spark job failures
- **Action groups**: Configure email, SMS, Azure Function, Logic App, or webhook notifications
- **Metric alerts**: Set threshold alerts on dedicated SQL pool DWU percentage, active queries, and TempDB utilization
- **Log alerts**: Use KQL-based alert rules for custom conditions (e.g., specific pipeline names failing, specific error patterns)
- **Azure Service Health**: Subscribe to Synapse Analytics service health events for platform-level incidents
