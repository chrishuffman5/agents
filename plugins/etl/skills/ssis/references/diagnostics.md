# SSIS Diagnostics

## Common Errors

### Data Type Conversion Failures

- **Symptom**: "Data conversion failed" or "The value could not be converted because of a potential loss of data"
- **Cause**: Mismatch between source and destination data types; implicit narrowing (DT_WSTR to DT_STR, Unicode to non-Unicode, wider to narrower numeric)
- **Fix**: Add explicit Data Conversion or Derived Column transformation with explicit CAST; match data types between source and destination
- **Prevention**: Define metadata correctly in source components; use explicit type casts in expressions

### Truncation Errors

- **Symptom**: "Text was truncated or one or more characters had no match in the target code page"
- **Cause**: Source data exceeds defined column width in flat file source, OLE DB destination, or transformation
- **Fix**: Increase column length in metadata; use Derived Column with SUBSTRING to trim; configure error output to redirect truncated rows
- **Prevention**: Profile source data lengths before designing the data flow; set generous column widths

### Connection Timeouts

- **Symptom**: "Timeout expired" or "Login timeout expired"
- **Cause**: Network latency, database overload, firewall blocking, DNS resolution failure
- **Fix**: Increase `ConnectionTimeout` on connection manager; increase `CommandTimeout` on Execute SQL Task or source component; verify network connectivity
- **Prevention**: Set timeouts to 60-300 seconds; implement retry logic via For Loop Container or Script Task

### Lookup Failures

- **Symptom**: "Row yielded no match during lookup" or "No matching row found"
- **Cause**: Reference data missing for lookup key; data quality issues in source or reference
- **Fix**: Configure lookup to redirect no-match rows to error output; handle no-match rows separately (staging table, default values)
- **Prevention**: Ensure referential integrity; load dimension/reference data before fact data

### Package Validation Errors

- **Symptom**: Validation errors on package open or execution start; "Failed to acquire connection" during validation
- **Cause**: Data source unreachable at validation time; metadata changes in source/destination; missing environment variable mappings
- **Fix**: Set `DelayValidation = true` on tasks connecting to unavailable sources; update metadata; verify environment references
- **Prevention**: Use DelayValidation judiciously; keep metadata synchronized with schema changes

### Deployment Errors

- **Symptom**: "Deployment failed" when deploying .ispac; permission denied
- **Cause**: Insufficient SSISDB permissions; version mismatch between project TargetServerVersion and server; protection level conflicts
- **Fix**: Grant `ssis_admin` or appropriate permissions; match TargetServerVersion to destination server; provide password for EncryptSensitiveWithPassword
- **Prevention**: Deploy using service accounts with SSISDB roles; use DontSaveSensitive + environment variables

### 32-bit / 64-bit Provider Issues

- **Symptom**: "The requested OLE DB provider is not registered" or provider not found
- **Cause**: SSIS running 64-bit but provider only available in 32-bit (common with Excel/Access via Jet/ACE)
- **Fix**: In 2019 and earlier, set `Run64BitRuntime = false`; in 2025, 32-bit is deprecated -- install 64-bit providers or use alternative connections (CSV instead of Excel, database staging instead of Access)
- **Prevention**: Use 64-bit providers; avoid Excel/Access connections in production

### Expression Evaluation Errors

- **Symptom**: "Expression evaluation failed" with cryptic error codes
- **Cause**: Type mismatch (concatenating integer with string without cast); null values; division by zero
- **Fix**: Use explicit type casts (`(DT_WSTR,50)ColumnName`); handle nulls with `ISNULL()` or conditional `?:` operator; guard division by zero
- **Prevention**: Test expressions in Expression Builder; handle null cases explicitly

### Memory Errors

- **Symptom**: "System.OutOfMemoryException" or "The buffer manager failed a memory allocation"
- **Cause**: Buffers exceeding available memory; too many concurrent data flows; large blocking transformations
- **Fix**: Reduce `DefaultBufferSize` or `DefaultBufferMaxRows`; reduce `MaxConcurrentExecutables`; eliminate blocking transformations; add server memory
- **Prevention**: Monitor memory during development with representative data volumes; avoid Sort/Aggregate on large datasets

## Performance Bottlenecks

### Slow Lookups

- **Diagnosis**: Data flow stalls at lookup; high memory consumption; check execution tree timing in SSISDB `catalog.execution_component_phases`
- **Cause**: No-cache or partial-cache mode issuing per-row queries; unindexed lookup columns; too many columns in reference
- **Fix**:
  - Switch to full cache mode (if memory allows)
  - Add indexes on lookup source columns
  - Reduce columns in lookup reference query
  - Use Cache connection manager to share lookup data
  - For very large references, replace Lookup with Merge Join

### Blocking Transformations

- **Diagnosis**: Data flow stalls at Sort/Aggregate; high memory usage; check `execution_component_phases` and tempdb usage
- **Cause**: Sort/Aggregate must consume all input before producing output; large datasets exhaust memory
- **Fix**:
  - Move Sort to source query (ORDER BY); set `IsSorted = true` on source output
  - Move Aggregate to source query (GROUP BY)
  - Stage data and use T-SQL for aggregation

### Buffer Spills

- **Diagnosis**: Dramatic slowdown; high disk I/O; tempdb growth; `BufferSizeTuning` warnings in logs
- **Cause**: Insufficient memory for buffers; too many concurrent data flows; blocking transformations
- **Fix**:
  - Increase server memory
  - Reduce concurrent data flows (decrease MaxConcurrentExecutables)
  - Increase buffer size to reduce buffer count
  - Remove unnecessary columns; avoid blocking transforms

### Slow Source Queries

- **Diagnosis**: Source extraction takes disproportionately long; data flow idle while waiting for source; run query in SSMS to check execution plan
- **Cause**: Unoptimized queries, missing indexes, parameter sniffing, locking contention
- **Fix**:
  - Optimize queries with indexes and query hints
  - Use `WITH (NOLOCK)` for read-only extraction
  - Increase network packet size on connection manager
  - Use `OPTION (RECOMPILE)` for parameter sniffing issues

### Slow Destination Writes

- **Diagnosis**: Data flow slows at destination; transaction log growth; blocking on destination table
- **Cause**: Row-by-row inserts (not fast load); indexes maintained during insert; full logging
- **Fix**:
  - Enable fast load on OLE DB Destination (BULK INSERT)
  - Drop and rebuild non-clustered indexes
  - Use TABLOCK hint
  - Tune MaxInsertCommitSize
  - Use bulk-logged recovery model during load

### Memory Pressure from Concurrency

- **Diagnosis**: Multiple packages/data flows cause memory exhaustion; Windows paging; check MaxConcurrentExecutables
- **Fix**:
  - Reduce MaxConcurrentExecutables
  - Stagger execution schedules
  - Increase server memory
  - Split large packages into smaller ones

## SSISDB Catalog Reports and Monitoring

### Built-in SSMS Reports

| Report | Description |
|---|---|
| Integration Services Dashboard | Overview of all executions in last 24 hours; pass/fail counts |
| All Executions | Complete execution history with status and duration |
| All Validations | Package validation summary |
| All Operations | All operations (deploy, configure, validate, execute) |
| All Connections | Connection usage across executions |

Access: SSMS > Integration Services Catalogs > SSISDB > right-click > Reports > Standard Reports

### Key Monitoring Queries

```sql
-- Recent failed executions
SELECT execution_id, folder_name, project_name, package_name,
       status, start_time, end_time,
       DATEDIFF(SECOND, start_time, end_time) AS duration_seconds
FROM catalog.executions
WHERE status = 4 -- 1=Created, 2=Running, 3=Canceled, 4=Failed, 5=Pending, 6=Ended unexpectedly, 7=Succeeded, 9=Completing
ORDER BY start_time DESC;

-- Error messages for a specific execution
SELECT event_message_id, message_time, message_type, message,
       package_name, event_name, subcomponent_name
FROM catalog.event_messages
WHERE operation_id = @execution_id
  AND event_name = 'OnError'
ORDER BY event_message_id;

-- Data flow row counts per path
SELECT execution_id, package_name, task_name,
       dataflow_path_name, rows_sent
FROM catalog.execution_data_statistics
WHERE execution_id = @execution_id
ORDER BY rows_sent DESC;

-- Component phase timing (identify bottlenecks)
SELECT package_name, task_name, subcomponent_name,
       execution_path, phase,
       SUM(DATEDIFF(MILLISECOND, start_time, end_time)) AS total_ms
FROM catalog.execution_component_phases
WHERE execution_id = @execution_id
GROUP BY package_name, task_name, subcomponent_name, execution_path, phase
ORDER BY total_ms DESC;

-- Stale running executions (stuck packages)
SELECT execution_id, folder_name, project_name, package_name,
       status, start_time,
       DATEDIFF(HOUR, start_time, GETDATE()) AS hours_running
FROM catalog.executions
WHERE status = 2
  AND DATEDIFF(HOUR, start_time, GETDATE()) > 4
ORDER BY start_time;

-- SSISDB size and retention settings
SELECT property_name, property_value
FROM catalog.catalog_properties
WHERE property_name IN ('RETENTION_WINDOW', 'MAX_PROJECT_VERSIONS',
                         'OPERATION_CLEANUP_ENABLED');
```

### Custom Dashboards

- **Power BI**: Connect to SSISDB catalog views for interactive dashboards
- **SSRS**: Build custom reports against SSISDB views; embed in SSMS
- **SQL Server Agent alerts**: Set up alerts based on SSISDB execution status queries

## Debugging Techniques

### Visual Studio / SSDT Debugging

- **Breakpoints**: Set on control flow tasks to pause execution
  - Conditions: OnPreExecute, OnPostExecute, OnError, OnWarning, OnTaskFailed
  - Hit count: Break after N hits
  - Expression: Break only when expression is true
- **Data viewers**: Attach to data flow paths for real-time row inspection
  - Grid view (tabular), chart view (histogram), column chart, scatter plot
- **Locals/Watch windows**: Inspect variable values at breakpoints
- **Immediate window**: Evaluate expressions during paused execution
- **Progress tab**: Real-time task status and timing

### Logging-Based Debugging

- **Performance logging level**: Captures data flow statistics and component phases without excessive volume
- **Verbose level**: All events including custom messages (use only for targeted debugging)
- **Custom log entries**: Use `Dts.Events.FireInformation()` or `Dts.Events.FireError()` in Script Tasks/Components
- **OnPipelineRowsSent event**: Logs row counts through data flow paths (enable in logging configuration)

### Production Debugging

1. Enable **Performance** logging level for the specific problem package
2. Query `catalog.execution_component_phases` to identify slowest components
3. Query `catalog.event_messages` filtered by OnError for failure analysis
4. Use `catalog.execution_data_statistics` to verify row counts at each stage
5. Compare execution durations across runs to identify degradation trends
6. Check Windows Event Log for system-level errors (memory, disk, network)

## Azure-SSIS IR Troubleshooting

### Provisioning / Startup Failures

- **Common causes**: Azure SQL connectivity issues; VNet/NSG misconfiguration; custom setup script failures; subscription quota exceeded
- **Diagnosis**: ADF monitoring portal; IR node diagnostics; activity run output
- **Fixes**:
  - Verify firewall rules allow ADF to connect to Azure SQL
  - Ensure VNet has correct NSG rules and DNS configuration
  - Test custom setup scripts manually before applying
  - Check subscription quotas for the chosen VM size

### Node Health Issues

- **Symptom**: IR nodes in unhealthy state; intermittent package failures
- **Diagnosis**: ADF monitoring > Integration Runtimes > node status
- **Fixes**:
  - Stop and restart the IR (recycles all nodes)
  - Check custom setup for compatibility issues
  - Verify network connectivity from IR to data sources
  - Review Azure SQL DTU/vCore usage (SSISDB may be undersized; recommend S3+ for production)

### Package Execution Failures on IR

- **Common errors**:
  - "Cannot access database under current security context" -- check managed identity or SQL auth credentials
  - "Requested operation requires a OLE DB Session object" -- connection string issues
  - "DTSER_FAILURE" -- check SSISDB execution reports for root cause
- **Diagnosis**: SSISDB catalog views (same as on-premises); ADF activity error output
- **Fixes**:
  - Verify all connection managers point to accessible endpoints from Azure
  - Ensure custom components are installed via custom setup
  - Check for 32-bit dependency issues (Azure-SSIS IR is 64-bit only)

### Azure-SSIS IR Performance

- **Scale up**: Larger node size for CPU/memory-intensive packages
- **Scale out**: More nodes for parallel package execution
- **Colocation**: Place IR in same region as Azure SQL and data sources
- **SSISDB tier**: S3 minimum for production; P1+ for heavy workloads
- **Cost optimization**: Use ADF triggers or Azure Automation to stop IR during off-hours

## Validation and Deployment Diagnostics

### Common Validation Errors

| Error | Cause | Fix |
|---|---|---|
| "Failed to acquire connection" | Server unreachable during validation | Set DelayValidation=true; verify connectivity |
| "Metadata of column does not match" | Source/destination schema changed | Refresh metadata in affected component |
| "VS_NEEDSNEWMETADATA" | Column added/removed/renamed | Open component editor and refresh columns |
| "Package migration required" | Older package in newer SSDT | Allow upgrade; test thoroughly |
| "DTSER_FAILURE (1)" | General execution failure | Check OnError event messages for root cause |

### Deployment Troubleshooting

- **"Access denied"**: User needs `CREATE_OBJECTS` permission on SSISDB folder, or `ssis_admin` role
- **Version mismatch**: Project TargetServerVersion must match (or be lower than) target SQL Server version
- **Missing references**: Environment references must exist before execution; create environments before deploying
- **Protection level conflicts**: If EncryptSensitiveWithPassword, password required during deployment; switch to DontSaveSensitive + parameters

### SSISDB Health Check

```sql
-- SSISDB database size
SELECT DB_NAME() AS database_name,
       SUM(size * 8.0 / 1024) AS size_mb
FROM sys.database_files;

-- Retention and cleanup settings
SELECT property_name, property_value
FROM catalog.catalog_properties
WHERE property_name IN ('RETENTION_WINDOW', 'MAX_PROJECT_VERSIONS',
                         'OPERATION_CLEANUP_ENABLED');

-- If SSISDB is growing excessively:
-- 1. Reduce RETENTION_WINDOW (default 365 days)
-- 2. Reduce MAX_PROJECT_VERSIONS (default 10)
-- 3. Ensure OPERATION_CLEANUP_ENABLED = TRUE
-- 4. Run the SSISDB cleanup stored procedure manually:
--    EXEC catalog.cleanup_server_retention_window
```
