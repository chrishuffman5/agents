# Azure Data Factory Diagnostics

## Common Issues

### Connectivity Failures
- **Symptoms**: "Cannot connect to data source", "Remote name could not be resolved", timeout errors
- **Root causes**:
  - Incorrect linked service credentials (expired password, wrong connection string)
  - Firewall blocking ADF IP ranges or IR access
  - DNS resolution failure (especially with Self-hosted IR or VNET-joined Azure-SSIS IR)
  - Missing private endpoints when using Managed VNET
  - Network Security Group (NSG) rules blocking required ports
- **Resolution**:
  - Test connectivity from the IR node (Self-hosted IR diagnostic tool)
  - Verify linked service credentials are current
  - Whitelist ADF IP ranges or use managed private endpoints
  - Check DNS resolution from the IR machine
  - Verify NSG and firewall rules allow traffic on required ports (1433 for SQL, 443 for HTTPS)

### Integration Runtime Issues
- **Self-hosted IR offline**: Node lost connectivity to ADF service
  - Check Windows service `DIAHostService` is running
  - Verify outbound HTTPS (443) to `*.servicebus.windows.net` and `*.frontend.clouddatahub.net`
  - Check proxy settings if behind a corporate proxy
  - Review IR node event logs for detailed error messages
- **Self-hosted IR high CPU/memory**: Processing too many concurrent activities
  - Scale out by adding additional IR nodes (active-active mode)
  - Reduce concurrent activity count on the IR
  - Monitor IR node metrics in ADF Monitor Hub
- **Azure IR timeout**: Activities exceeding default or configured timeout
  - Increase timeout on activity settings
  - Investigate source/sink performance bottlenecks
  - Consider using Self-hosted IR for network-sensitive scenarios

### Data Type Mapping Issues
- **Symptoms**: "Type conversion failure", "Cannot cast value", truncation warnings
- **Root causes**:
  - Source data types incompatible with sink schema
  - Precision/scale mismatch (decimal, datetime)
  - Encoding issues (UTF-8 vs. extended characters)
  - Null values in non-nullable columns
- **Resolution**:
  - Use explicit column mapping in Copy Activity with type conversion
  - Enable fault tolerance to skip incompatible rows (and log them)
  - Add schema validation in Data Flows using Assert transformation
  - Use Derived Column transformation for explicit type casting before sink

### Copy Activity Performance Issues
- **Symptoms**: Slow throughput, long copy duration, high DIU usage with low data volume
- **Root causes**:
  - Under-provisioned DIU for the data volume
  - No parallel copy for partitioned sources
  - Small file overhead (many small files rather than fewer large files)
  - Source or sink throttling
  - Network bandwidth limitations (cross-region, on-premises)
- **Resolution**:
  - Increase DIU and monitor throughput improvement
  - Enable partitioned read with parallel copy
  - Consolidate small files or use wildcard paths
  - Use staging via Blob Storage for PolyBase/COPY into Synapse
  - Use compression for network-bound transfers

### Trigger Issues
- **Schedule trigger not firing**: Verify trigger is in "Started" state; check trigger run history
- **Storage event trigger missing events**: Verify Event Grid subscription is active; check blob path filters match file patterns; latency of up to 1-2 minutes is normal
- **Tumbling window backlog**: Check for failed previous windows (dependencies block downstream windows); clear or rerun failed windows

---

## Performance Tuning

### Copy Activity Throughput
- **Baseline**: Measure initial throughput with default settings (4 DIU, auto parallel copy)
- **DIU tuning**: Increase DIU incrementally (4 -> 8 -> 16 -> 32 -> 64) and measure throughput gain
  - Diminishing returns above a certain DIU count depend on source/sink capabilities
  - Some sources (e.g., small databases) cannot feed enough data to utilize high DIU
- **Parallel copy**: Set explicitly when source supports partitioned reads
  - SQL sources: partition by integer column or physical partitions
  - File sources: per-file parallelism via wildcards
- **Staging**: Enable for PolyBase/COPY scenarios; use SSD-backed storage accounts
- **Network**: Ensure IR and data stores are in the same region to minimize latency
- **Format**: Use Parquet or Delta for large datasets (columnar compression)

### Data Flow Optimization
- **Cluster warm-up**: Use TTL to avoid 3-5 minute cold start on every execution
- **Partition strategy**:
  - Default (Round Robin) works for most scenarios
  - Hash partitioning beneficial before join/group operations on large datasets
  - Avoid manually setting partitions unless you have specific distribution knowledge
- **Broadcasting**: Enable for small-to-large joins to avoid shuffle
  - Auto mode lets Spark decide (recommended default)
  - Force broadcast when one side is consistently small (< 100MB)
- **Transformation optimization**:
  - Use Surrogate Key instead of Aggregate for generating unique keys
  - Use Rank instead of Window when only rank is needed
  - Minimize the number of transformations -- combine logic where possible
  - Avoid unnecessary Select transformations (Spark optimizer handles projection pushdown)
- **Logging**: Set to Basic in production; Verbose logging per partition is expensive
- **Source optimization**: Push down filters to the source query; avoid reading unnecessary columns
- **Sink optimization**: Use batch inserts; set appropriate batch size for database sinks

### Pipeline-Level Optimization
- Minimize activity count per pipeline (each activity has scheduling overhead)
- Use ForEach with parallel execution (batch count) instead of sequential For loops
- Use Execute Pipeline (async) for independent workstreams
- Avoid unnecessary Lookup or Get Metadata calls -- cache results in variables
- Design for idempotency to enable safe reruns without side effects

---

## Debugging

### Pipeline Debug Mode
- Run pipelines interactively in ADF Studio without triggering or publishing
- Set breakpoints on activities to pause execution at specific points
- View activity input, output, and duration in real-time
- Test with sample data or full data
- Debug runs are free for the first 12 months (limited)

### Data Flow Debug
- Activate debug cluster (Spark cluster) for interactive data flow testing
- Data Preview: inspect data at each transformation step
- Row-by-row inspection of transformation logic
- Expression evaluation in real-time
- Schema drift detection and handling verification
- Debug cluster charges apply (vCore-hours) -- use TTL to keep cluster warm during development
- Debug session timeout: configurable (default 60 minutes, max 480 minutes)

### Activity Output Inspection
- Every activity produces output accessible via `@activity('ActivityName').output`
- Copy Activity output includes:
  - `rowsRead`, `rowsCopied`, `rowsSkipped`
  - `dataRead`, `dataWritten` (bytes)
  - `throughput` (KBps)
  - `copyDuration` (seconds)
  - `usedDataIntegrationUnits`
  - `effectiveIntegrationRuntime`
  - `errors` (array of error details)
- Lookup Activity output: `value` (array of records), `count`, `firstRow`
- Web Activity output: `statusCode`, `headers`, `body`
- Use Set Variable to capture and log activity outputs for analysis

### Expression Debugging
- Use the expression builder in ADF Studio to test expressions
- Preview expression results with sample data
- Common expression issues:
  - Missing `@` prefix for dynamic expressions
  - Incorrect function syntax or parameter types
  - Null handling: use `coalesce()` or `if(isNull(...), default, value)`
  - Date format mismatches: verify format strings match source data patterns

---

## Integration Runtime Troubleshooting

### Self-Hosted IR Connectivity
- **Diagnostic tool**: Built-in tool on the SHIR node runs connectivity tests
  - Tests connection to ADF service backend
  - Tests DNS resolution for configured data sources
  - Tests network path to source/sink endpoints
  - Generates HTML report with findings and suggested fixes
- **Common connectivity issues**:
  - Proxy misconfiguration: verify proxy settings in `diahostservice.exe.config`
  - TLS version mismatch: ensure TLS 1.2 is enabled on the SHIR machine
  - Certificate issues: expired or untrusted SSL certificates on data sources
  - Firewall: outbound traffic to `*.servicebus.windows.net` (443, 9354) must be allowed
- **Performance issues**:
  - CPU/memory exhaustion: monitor via Windows Performance Monitor or ADF Monitor Hub
  - Too many concurrent activities: reduce concurrency limit on the SHIR
  - Network bandwidth saturation: check NIC utilization; consider multiple SHIR nodes
- **Node management**:
  - Health status check: ADF Monitor Hub shows node status (Online, Limited, Offline)
  - Auto-update: SHIR auto-updates by default; can be disabled for controlled updates
  - Log collection: SHIR logs located in `C:\ProgramData\SSISTelemetry` and Windows Event Viewer

### Azure-SSIS IR Startup Failures
- **Common causes**:
  - **SQL Database/Managed Instance**: SSISDB server not accessible; firewall rules blocking; insufficient permissions
  - **Custom setup**: SAS URI expired; container not accessible; setup script errors
  - **Virtual Network**: Misconfigured DNS, NSG, or UDR in the VNet
  - **License**: Invalid or expired SSIS license for Enterprise tier features
- **Diagnostic steps**:
  1. Check IR status in ADF Monitor Hub for detailed error messages
  2. Verify SSISDB server connectivity and permissions
  3. If using custom setup, verify SAS token is valid and container is accessible
  4. If VNet-joined, verify DNS resolution and NSG rules allow required traffic
  5. Review Azure-SSIS IR provisioning logs in ADF Studio
- **Startup time expectations**:
  - Standard provisioning: 20-30 minutes
  - With VNet joining: may take longer (up to 30-40 minutes)
  - With custom setup: additional time depending on setup script duration
- **Common resolutions**:
  - Recreate the SSISDB if it becomes corrupted
  - Update NSG rules to allow traffic on ports 1433 (SQL), 443 (management), 11000-11999 (redirect)
  - Re-provision the Azure-SSIS IR with corrected configuration

---

## Cost Analysis

### Monitoring Pipeline Consumption
- **ADF Monitor Hub**: View pipeline run history with duration and activity counts
- **Azure Cost Management**: Break down ADF costs by meter type:
  - Orchestration (activity runs)
  - Data Movement (DIU-hours)
  - Data Flow (vCore-hours)
  - Pipeline runs
  - SSIS IR (node-hours)
- **Cost allocation**: Use Azure resource tags to allocate costs to business units or projects
- **Consumption patterns**: Identify peak usage periods and optimize scheduling

### Optimizing Runs
- **Eliminate redundant runs**: Review trigger schedules for overlapping or unnecessary executions
- **Consolidate pipelines**: Merge similar pipelines into metadata-driven patterns (fewer activity runs)
- **Right-size compute**:
  - Copy Activity: Match DIU to actual data volume (avoid 256 DIU for small copies)
  - Data Flow: Match cluster size to transformation complexity
  - SSIS IR: Stop the IR when not in use (scheduled start/stop)
- **Data volume optimization**:
  - Use incremental/delta loads instead of full refreshes
  - Apply source-side filtering to reduce data read
  - Use partition pruning for file-based sources
- **Scheduling optimization**:
  - Stagger pipeline schedules to avoid concurrent cluster spin-ups
  - Use tumbling window triggers for time-series data (avoid reprocessing)
  - Align Data Flow schedules to maximize TTL cluster reuse
- **Reserved capacity**: Commit to 1-year or 3-year reserved pricing for consistent workloads
  - General Purpose Data Flow: ~$0.205/vCore-hr (1-year) vs. ~$0.274 (pay-as-you-go)
  - Savings increase with 3-year commitment (~$0.178/vCore-hr)

---

## Sources

- [General Troubleshooting - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/data-factory-troubleshoot-guide)
- [Troubleshoot Connectors - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/connector-troubleshoot-guide)
- [Troubleshoot Copy Activity Performance - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/copy-activity-performance-troubleshooting)
- [Troubleshoot Self-Hosted IR - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/self-hosted-integration-runtime-troubleshoot-guide)
- [SHIR Diagnostic Tool - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/self-hosted-integration-runtime-diagnostic-tool)
- [Troubleshoot SSIS IR Management - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/ssis-integration-runtime-management-troubleshoot)
- [Troubleshoot Pipeline/Triggers - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/pipeline-trigger-troubleshoot-guide)
- [ADF Known Issues - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/known-issues-troubleshoot-guide)
- [Copy Activity Performance Guide - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/copy-activity-performance)
- [Data Flow Performance Tuning - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/concepts-data-flow-performance)
- [Troubleshoot ADF Studio - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/data-factory-ux-troubleshoot-guide)
