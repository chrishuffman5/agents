# SSIS Diagnostics

## Common Errors

### Data Type Conversion Failures
- **Symptom**: "Data conversion failed" or "The value could not be converted because of a potential loss of data"
- **Cause**: Mismatch between source column data type and destination/transformation expected type; implicit narrowing conversions (e.g., DT_WSTR to DT_STR, Unicode to non-Unicode, wider numeric to narrower)
- **Fix**: Add explicit Data Conversion or Derived Column transformation before the failing component; use explicit CAST expressions; match data types between source and destination
- **Prevention**: Define metadata correctly in source components; use explicit type casts

### Truncation Errors
- **Symptom**: "Text was truncated or one or more characters had no match in the target code page"
- **Cause**: Source data exceeds the defined column width in a flat file source, OLE DB destination, or transformation
- **Fix**: Increase column length in metadata; use Derived Column to SUBSTRING/trim long values; configure error output to redirect truncated rows
- **Prevention**: Profile source data lengths before designing data flow; set generous column widths

### Connection Timeouts
- **Symptom**: "Timeout expired" or "Login timeout expired" on connection managers
- **Cause**: Network latency, database server overload, firewall blocking, DNS resolution issues
- **Fix**: Increase `ConnectionTimeout` property on the connection manager; increase `CommandTimeout` on Execute SQL Task or source component; verify network connectivity
- **Prevention**: Set appropriate timeouts (60-300 seconds); use retry logic via For Loop or Script Task

### Lookup Failures
- **Symptom**: "Row yielded no match during lookup" (error output) or "No matching row found" (fail component)
- **Cause**: Reference data missing for the lookup key; data quality issues in source or reference table
- **Fix**: Configure lookup to redirect no-match rows to error output; handle no-match rows in a separate path (e.g., insert to staging for review, or use default values)
- **Prevention**: Ensure referential integrity; load dimension/reference data before fact data

### Package Validation Errors
- **Symptom**: Validation errors on package open or execution start; "Failed to acquire connection" during validation
- **Cause**: Connection manager cannot reach the data source at validation time; metadata changes in source/destination tables; missing environment variable mappings
- **Fix**: Set `DelayValidation = true` on tasks that connect to unavailable sources; update metadata in source/destination components; verify environment references
- **Prevention**: Use DelayValidation judiciously; keep metadata synchronized with schema changes

### Deployment Errors
- **Symptom**: "Deployment failed" when deploying .ispac to SSISDB; permission denied errors
- **Cause**: Insufficient permissions on SSISDB; version mismatch between SSIS project target version and server version; protection level conflicts
- **Fix**: Grant `ssis_admin` or appropriate permissions; match project TargetServerVersion to destination server; ensure password is provided for EncryptSensitiveWithPassword
- **Prevention**: Deploy using service accounts with appropriate SSISDB roles; use DontSaveSensitive + environment variables

### 32-bit / 64-bit Issues
- **Symptom**: "The requested OLE DB provider is not registered" or provider not found errors
- **Cause**: SSIS running in 64-bit mode but data provider only available in 32-bit (common with Excel/Access via Jet/ACE)
- **Fix**: In SSIS 2019 and earlier, set `Run64BitRuntime = false` in project properties; in SSIS 2025, 32-bit mode is deprecated -- install 64-bit providers or use alternative connection methods
- **Prevention**: Use 64-bit data providers; avoid Excel/Access connections in production (use CSV or database staging instead)

### Expression Evaluation Errors
- **Symptom**: "Expression evaluation failed" with cryptic error codes
- **Cause**: Type mismatch in expression (e.g., concatenating integer with string without cast); null values in expressions; division by zero
- **Fix**: Use explicit type casts ((DT_WSTR,50)ColumnName); handle nulls with ISNULL() or conditional (?:) operator; check for zero before division
- **Prevention**: Test expressions in the Expression Builder; handle null cases explicitly

---

## Performance Bottlenecks

### Slow Lookups
- **Symptom**: Data flow runs slowly at lookup transformation; high memory consumption
- **Diagnosis**: Check lookup cache mode; monitor memory usage; check execution tree timing in SSISDB reports
- **Cause**: No-cache or partial-cache mode issuing per-row queries; reference table too large for full cache; unindexed lookup columns in source database
- **Fix**:
  - Switch to full cache mode (if memory allows)
  - Add indexes on lookup source columns
  - Reduce columns selected in lookup reference query
  - Use Cache connection manager to pre-load and share lookup data
  - For very large references, replace Lookup with Merge Join (requires sorted inputs)

### Blocking Transformations
- **Symptom**: Data flow stalls at Sort or Aggregate transformation; high memory usage; potential disk spills
- **Diagnosis**: Check `execution_component_phases` for time spent in blocking components; monitor tempdb usage
- **Cause**: Sort/Aggregate must read all input before producing output; large datasets exhaust available memory
- **Fix**:
  - Move Sort to source query (ORDER BY)
  - Move Aggregate to source query (GROUP BY)
  - If sort is needed for Merge Join, sort at the source and set `IsSorted = true` on the source output
  - If aggregation in SSIS is required, consider staging data and using T-SQL

### Buffer Spills
- **Symptom**: Dramatic slowdown during data flow; high disk I/O; tempdb growth
- **Diagnosis**: Check for `BufferSizeTuning` warnings in logs; monitor disk I/O on SSIS server
- **Cause**: Insufficient memory for buffers; too many concurrent data flows; blocking transformations holding data
- **Fix**:
  - Increase server memory
  - Reduce concurrent data flows (decrease MaxConcurrentExecutables)
  - Increase buffer size (DefaultBufferSize) to reduce buffer count
  - Optimize data flow to reduce memory pressure (remove unnecessary columns, avoid blocking transforms)

### Slow Source Queries
- **Symptom**: Source extraction takes disproportionately long time; data flow appears idle while waiting for source
- **Diagnosis**: Run the source query directly in SSMS and check execution plan; check for blocking/deadlocks
- **Cause**: Unoptimized queries, missing indexes, parameter sniffing, locking contention
- **Fix**:
  - Optimize source queries with appropriate indexes and query hints
  - Use NOLOCK/READ UNCOMMITTED for read-only extraction (when acceptable)
  - Increase network packet size on the connection manager
  - Use query hints (OPTION (RECOMPILE)) for parameter sniffing issues

### Slow Destination Writes
- **Symptom**: Data flow slows at destination; transaction log growth; blocking on destination table
- **Diagnosis**: Monitor destination database I/O, transaction log usage, and lock waits
- **Cause**: Row-by-row inserts (not using fast load); non-clustered indexes being maintained during insert; full transaction logging
- **Fix**:
  - Enable fast load on OLE DB Destination (uses BULK INSERT)
  - Drop and rebuild indexes for large loads
  - Use TABLOCK hint
  - Tune MaxInsertCommitSize
  - Use bulk-logged recovery model during load

### Memory Pressure from Concurrent Execution
- **Symptom**: Multiple packages/data flows running simultaneously cause memory exhaustion
- **Diagnosis**: Monitor server memory; check for Windows paging; review MaxConcurrentExecutables setting
- **Fix**:
  - Reduce MaxConcurrentExecutables
  - Stagger package execution schedules
  - Increase server memory
  - Split large packages into smaller ones with controlled parallelism

---

## SSISDB Catalog Reports and Monitoring

### Built-in SSMS Reports
| Report | Description | Access Path |
|---|---|---|
| Integration Services Dashboard | High-level overview of all executions in last 24 hours; pass/fail counts | SSMS > Integration Services Catalogs > SSISDB > right-click > Reports > Standard Reports |
| All Executions | Complete execution history with status, duration, start/end times | Same path as above |
| All Validations | Summary of all package validations | Same path |
| All Operations | All administrative operations (deploy, configure, validate, execute) | Same path |
| All Connections | Connection usage across executions | Same path |

### Key Catalog Views for Custom Queries
```sql
-- Recent failed executions
SELECT execution_id, folder_name, project_name, package_name, 
       status, start_time, end_time,
       DATEDIFF(SECOND, start_time, end_time) AS duration_seconds
FROM catalog.executions
WHERE status = 4 -- Failed
ORDER BY start_time DESC;

-- Error messages for a specific execution
SELECT event_message_id, message_time, message_type, message, 
       package_name, event_name, subcomponent_name
FROM catalog.event_messages
WHERE operation_id = @execution_id
  AND event_name = 'OnError'
ORDER BY event_message_id;

-- Data flow performance statistics
SELECT execution_id, package_name, task_name, 
       dataflow_path_name, rows_sent,
       DATEDIFF(MILLISECOND, created_time, created_time) AS duration_ms
FROM catalog.execution_data_statistics
WHERE execution_id = @execution_id
ORDER BY rows_sent DESC;

-- Component phase timing (data flow bottleneck identification)
SELECT package_name, task_name, subcomponent_name,
       execution_path, phase, 
       SUM(DATEDIFF(MILLISECOND, start_time, end_time)) AS total_ms
FROM catalog.execution_component_phases
WHERE execution_id = @execution_id
GROUP BY package_name, task_name, subcomponent_name, execution_path, phase
ORDER BY total_ms DESC;
```

### Custom Dashboards
- **Power BI**: Connect to SSISDB catalog views for interactive dashboards (community project: SSIS-DB-Dashboard on GitHub)
- **SSRS**: Build custom SSRS reports against SSISDB views and embed in SSMS as custom reports
- **Custom alerts**: Set up SQL Server Agent alerts based on SSISDB execution status queries

---

## Debugging Techniques

### Visual Studio / SSDT Debugging
- **Breakpoints**: Set breakpoints on control flow tasks to pause execution
  - Break conditions: OnPreExecute, OnPostExecute, OnError, OnWarning, OnTaskFailed
  - Hit count conditions: Break after N hits
  - Expression conditions: Break only when expression evaluates to true
- **Data viewers**: Attach to data flow paths to see data in real-time during debug execution
  - Grid view: Tabular display of rows
  - Chart view: Histogram of column values
  - Column chart and scatter plot views
- **Locals window**: Inspect current variable values at breakpoints
- **Immediate window**: Evaluate expressions and variable values during debugging
- **Watch window**: Monitor specific variables across execution
- **Progress tab**: Real-time execution progress showing task status and timing

### Logging-Based Debugging
- **SSISDB logging levels**:
  - **Basic**: Errors and warnings only (production default)
  - **Performance**: Adds data flow statistics and component phases (recommended for troubleshooting)
  - **Verbose**: All events including custom messages (use only for targeted debugging -- generates large volumes)
  - **RuntimeLineage**: Data lineage tracking
- **Custom log entries**: Use `Dts.Events.FireInformation()` or `Dts.Events.FireError()` in Script Tasks/Components
- **OnPipelineRowsSent event**: Logs row counts through data flow paths (enable in logging configuration)

### Production Debugging
- Enable **Performance** logging level for specific problem packages
- Query `catalog.execution_component_phases` to identify which components take the longest
- Query `catalog.event_messages` filtered by OnError events for failure analysis
- Use **catalog.execution_data_statistics** to verify row counts at each data flow stage
- Compare execution durations across runs to identify degradation trends

---

## Azure-SSIS IR Troubleshooting

### Provisioning / Startup Failures
- **Common causes**: Azure SQL Database/Managed Instance connectivity issues; VNet configuration errors; custom setup script failures; insufficient Azure subscription quota
- **Diagnosis**: Check Azure Data Factory monitoring portal; review IR node diagnostics; check activity run output
- **Fixes**:
  - Verify firewall rules allow ADF to connect to Azure SQL
  - Ensure VNet has correct NSG rules and DNS configuration
  - Test custom setup scripts manually before applying
  - Check Azure subscription quotas for VM sizes

### Node Health Issues
- **Symptom**: IR nodes in unhealthy state; intermittent package failures
- **Diagnosis**: ADF monitoring > Integration Runtimes > node status
- **Fixes**:
  - Stop and restart the IR (recycles all nodes)
  - Check custom setup for compatibility issues
  - Verify network connectivity from IR nodes to data sources
  - Review Azure SQL Database DTU/vCore usage (SSISDB may be undersized)

### Package Execution Failures on IR
- **Common errors**:
  - "Cannot access database under current security context" -- check managed identity or SQL auth credentials
  - "Requested operation requires a OLE DB Session object" -- connection string issues
  - "Package execution returned DTSER_FAILURE" -- check package-level error in SSISDB execution reports
- **Diagnosis**: Check SSISDB execution reports (same catalog views as on-premises); review ADF activity run error output
- **Fixes**:
  - Verify all connection managers point to accessible endpoints from Azure
  - Ensure custom components are properly installed via custom setup
  - Check for 32-bit dependency issues (Azure-SSIS IR runs 64-bit)

### Performance on Azure-SSIS IR
- **Scale up**: Choose larger node size for CPU/memory-intensive packages
- **Scale out**: Add more nodes for parallel package execution
- **Colocation**: Place IR in same region as Azure SQL and data sources
- **SSISDB tier**: Ensure Azure SQL Database hosting SSISDB has sufficient DTUs/vCores (S3 minimum recommended for production)
- **Start/stop scheduling**: Use ADF triggers or Azure Automation to stop IR during off-hours

---

## Package Validation and Deployment Diagnostics

### Common Validation Errors
| Error | Cause | Fix |
|---|---|---|
| "Failed to acquire connection" | Target server unreachable during validation | Set DelayValidation=true; verify connectivity |
| "The metadata of column does not match" | Source/destination schema changed | Refresh metadata in the affected component |
| "VS_NEEDSNEWMETADATA" | Column added/removed/renamed in source | Open component editor and refresh columns |
| "Package migration required" | Opening older package in newer SSDT | Allow upgrade; test thoroughly after migration |
| "Execution result: DTSER_FAILURE (1)" | General execution failure | Check OnError event messages for root cause |

### Deployment Troubleshooting
- **"Access denied" on deployment**: User needs `CREATE_OBJECTS` permission on SSISDB folder, or `ssis_admin` role
- **Version mismatch**: Project TargetServerVersion must match (or be lower than) target SQL Server version
- **Missing references**: Environment references must exist before execution; create environments before deploying
- **Protection level conflicts**: If package uses EncryptSensitiveWithPassword, password must be provided during deployment; recommend switching to DontSaveSensitive + parameters

### Health Check Queries
```sql
-- SSISDB catalog health: check for stale running executions
SELECT execution_id, folder_name, project_name, package_name,
       status, start_time,
       DATEDIFF(HOUR, start_time, GETDATE()) AS hours_running
FROM catalog.executions
WHERE status = 2 -- Running
  AND DATEDIFF(HOUR, start_time, GETDATE()) > 4 -- Running more than 4 hours
ORDER BY start_time;

-- SSISDB size check (cleanup may be needed)
SELECT 
    DB_NAME() AS database_name,
    SUM(size * 8.0 / 1024) AS size_mb
FROM sys.database_files
WHERE DB_NAME() = 'SSISDB';

-- Check SSISDB retention settings
SELECT property_name, property_value
FROM catalog.catalog_properties
WHERE property_name IN ('RETENTION_WINDOW', 'MAX_PROJECT_VERSIONS', 
                         'OPERATION_CLEANUP_ENABLED');
```
