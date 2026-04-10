# SSRS Diagnostics

> Troubleshooting guide for SSRS covering common issues, performance analysis,
> configuration problems, log sources, and migration diagnostics.

---

## Log Sources and Locations

### Execution Log (ReportServer Database)

The primary diagnostic tool for report performance and execution analysis.

**Views** (in the ReportServer database):

| View | Purpose |
|------|---------|
| `dbo.ExecutionLog3` | Most current and detailed view (recommended) |
| `dbo.ExecutionLog2` | Legacy view with less detail |
| `dbo.ExecutionLog` | Original view, basic information |

**Key columns in ExecutionLog3**:

| Column | Description |
|--------|-------------|
| `InstanceName` | Report Server instance |
| `ItemPath` | Report path on the server |
| `UserName` | User who executed the report |
| `RequestType` | Interactive or Subscription |
| `Format` | Rendering format (HTML, PDF, Excel, etc.) |
| `TimeStart` / `TimeEnd` | Execution timestamps |
| `TimeDataRetrieval` | Milliseconds spent retrieving data |
| `TimeProcessing` | Milliseconds spent processing the report |
| `TimeRendering` | Milliseconds spent rendering output |
| `Status` | rsSuccess, rsProcessingAborted, rrRenderingError, etc. |
| `ByteCount` | Size of the rendered report |
| `RowCount` | Number of rows returned from queries |
| `Parameters` | Parameter values used |
| `Source` | How the report was served: Live, Cache, Snapshot, History |

**Diagnostic queries**:

```sql
-- Find slowest reports (last 7 days)
SELECT TOP 20
    ItemPath,
    UserName,
    Format,
    TimeDataRetrieval,
    TimeProcessing,
    TimeRendering,
    (TimeDataRetrieval + TimeProcessing + TimeRendering) AS TotalTimeMs,
    TimeStart,
    Status
FROM ExecutionLog3
WHERE TimeStart > DATEADD(day, -7, GETDATE())
ORDER BY (TimeDataRetrieval + TimeProcessing + TimeRendering) DESC;

-- Find failed executions
SELECT ItemPath, UserName, Status, TimeStart, Parameters
FROM ExecutionLog3
WHERE Status <> 'rsSuccess'
  AND TimeStart > DATEADD(day, -7, GETDATE())
ORDER BY TimeStart DESC;

-- Report execution frequency
SELECT ItemPath, COUNT(*) AS ExecutionCount,
    AVG(TimeDataRetrieval + TimeProcessing + TimeRendering) AS AvgTotalMs,
    MAX(TimeDataRetrieval + TimeProcessing + TimeRendering) AS MaxTotalMs
FROM ExecutionLog3
WHERE TimeStart > DATEADD(day, -30, GETDATE())
GROUP BY ItemPath
ORDER BY ExecutionCount DESC;

-- Identify cache effectiveness
SELECT ItemPath, Source, COUNT(*) AS ExecutionCount
FROM ExecutionLog3
WHERE TimeStart > DATEADD(day, -7, GETDATE())
GROUP BY ItemPath, Source
ORDER BY ItemPath, Source;
```

**Configuration** (in `rsreportserver.config`):

```xml
<Add Key="ExecutionLogLevel" Value="verbose" />  <!-- verbose or normal -->
<Add Key="ExecutionLogDaysKept" Value="60" />     <!-- days to retain; 0 = unlimited -->
```

Entries exceeding the retention period are removed daily at 2:00 AM.

### Report Server Trace Logs

Located at:
```
%ProgramFiles%\Microsoft SQL Server\MSRS<version>.<instance>\Reporting Services\LogFiles\
```

Files:
- `ReportServerService_<timestamp>.log` -- Main service trace log
- `ReportServerWebApp_<timestamp>.log` -- Web portal/API trace log (SSRS 2016+)

**Configuration** (in `ReportingServicesService.exe.config`):

```xml
<system.diagnostics>
  <switches>
    <add name="DefaultTraceSwitch" value="3" />
    <!-- 0=Off, 1=Error, 2=Warning, 3=Info, 4=Verbose -->
  </switches>
</system.diagnostics>
```

### HTTP Logs

Located in the same LogFiles directory:
- `ReportServerService_HTTP_<timestamp>.log`

Captures HTTP request/response information including URLs, status codes, and timing.

### Windows Event Logs

- **Application log**: SSRS errors and warnings from the Report Server service
- **System log**: Service start/stop events, permission issues

Filter by source: `Report Server`, `Report Server (MSSQLSERVER)`, or the instance-specific source name.

---

## Common Issues and Resolution

### Report Rendering Failures

**Symptom**: Report displays error instead of data, or renders blank.

| Issue | Cause | Resolution |
|-------|-------|------------|
| `rsProcessingAborted` | Query timeout or processing error | Check `TimeDataRetrieval` in ExecutionLog3; increase timeout or optimize query |
| `rrRenderingError` | Rendering extension failure | Check trace logs for specific error; verify report layout for the target format |
| Blank report | Query returns no data for given parameters | Verify parameter values; test query directly against database |
| `rsErrorOpeningConnection` | Cannot connect to data source | Verify connection string, credentials, and network connectivity |
| `rsAccessDenied` | Insufficient permissions | Check user's role assignments on the report and data source |
| Subreport errors | Subreport cannot be found or fails | Verify subreport path, parameters, and permissions |
| Image rendering failures | External image URLs unreachable | Verify image URLs from Report Server's network perspective; consider embedded images |

### Subscription Delivery Failures

**Symptom**: Subscriptions show "Error" status in the portal or no delivery occurs.

| Issue | Cause | Resolution |
|-------|-------|------------|
| Email not delivered | SMTP configuration error | Verify `<SMTPServer>` in rsreportserver.config; test SMTP connectivity from server |
| File share delivery fails | Permission or path issue | Ensure SSRS service account has write access to UNC path |
| "The report server has encountered a configuration error" | Missing or invalid subscription settings | Check subscription configuration; verify SQL Server Agent is running |
| Data-driven subscription fails | Subscriber query error | Test the subscriber query independently; check for NULL values in required fields |
| Subscription stuck in "New Subscription" | SQL Server Agent job not created | Restart SSRS service; verify SQL Server Agent service is running |

**Monitoring subscriptions**:

```sql
-- Check subscription status
SELECT s.SubscriptionID, c.Name AS ReportName, c.Path,
    s.LastStatus, s.LastRunTime, s.Description,
    s.DeliveryExtension
FROM dbo.Subscriptions s
JOIN dbo.Catalog c ON s.Report_OID = c.ItemID
ORDER BY s.LastRunTime DESC;
```

### Timeout Errors

**Types of timeouts**:

1. **Report Execution Timeout**: How long the report server waits for report processing
   - Site-wide: Site Settings > Report Execution Timeout
   - Per-report: Report Properties > Execution > Override site-level timeout
   - Default: No timeout (dangerous for production)

2. **Query Timeout**: How long the data source waits for query completion
   - Set in dataset properties > Query timeout
   - Default: 0 (no timeout)

3. **Session Timeout**: How long an interactive session remains active
   - Default: 600 seconds (10 minutes)
   - Configured in rsreportserver.config: `<SessionTimeout>600</SessionTimeout>`

**Resolution approach**:
1. Check `ExecutionLog3` to identify which phase is slow (data retrieval, processing, rendering)
2. If `TimeDataRetrieval` is high: Optimize the query, add indexes, or use stored procedures
3. If `TimeProcessing` is high: Simplify report expressions, reduce subreports, minimize grouping complexity
4. If `TimeRendering` is high: Reduce report size, minimize images, consider different output format

---

## Performance Diagnostics

### Identifying Bottlenecks

Use `ExecutionLog3` to categorize execution time:

```sql
-- Performance breakdown by report
SELECT ItemPath,
    COUNT(*) AS Executions,
    AVG(TimeDataRetrieval) AS AvgDataMs,
    AVG(TimeProcessing) AS AvgProcessMs,
    AVG(TimeRendering) AS AvgRenderMs,
    AVG(TimeDataRetrieval + TimeProcessing + TimeRendering) AS AvgTotalMs
FROM ExecutionLog3
WHERE TimeStart > DATEADD(day, -30, GETDATE())
  AND Status = 'rsSuccess'
GROUP BY ItemPath
HAVING COUNT(*) > 10
ORDER BY AVG(TimeDataRetrieval + TimeProcessing + TimeRendering) DESC;
```

### ReportServer Database Queries

Monitor the health of the ReportServer database itself:

```sql
-- Database size and growth
SELECT DB_NAME() AS DatabaseName,
    name AS FileName,
    size * 8 / 1024 AS SizeMB,
    FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024 AS UsedMB
FROM sys.database_files;

-- Catalog item count
SELECT Type, TypeName = CASE Type
    WHEN 1 THEN 'Folder'
    WHEN 2 THEN 'Report'
    WHEN 3 THEN 'Resource'
    WHEN 4 THEN 'Linked Report'
    WHEN 5 THEN 'Data Source'
    WHEN 6 THEN 'Report Model'
    WHEN 8 THEN 'Shared Dataset'
    WHEN 13 THEN 'KPI'
    END,
    COUNT(*) AS ItemCount
FROM dbo.Catalog
GROUP BY Type
ORDER BY ItemCount DESC;

-- Report history snapshot sizes
SELECT c.Name, c.Path,
    COUNT(h.SnapshotDataID) AS SnapshotCount,
    SUM(DATALENGTH(sd.Content)) / 1024 / 1024 AS TotalSizeMB
FROM dbo.History h
JOIN dbo.Catalog c ON h.ReportID = c.ItemID
JOIN dbo.SnapshotData sd ON h.SnapshotDataID = sd.SnapshotDataID
GROUP BY c.Name, c.Path
ORDER BY TotalSizeMB DESC;
```

### Memory and Resource Issues

- **Symptom**: Report Server becomes unresponsive or returns 503 errors
- **Check**: Windows Task Manager / Performance Monitor for memory consumption
- **Resolution**: Configure memory limits in rsreportserver.config:

```xml
<WorkingSetMaximum>3000000</WorkingSetMaximum>  <!-- KB -->
<WorkingSetMinimum>1500000</WorkingSetMinimum>   <!-- KB -->
<MemorySafetyMargin>80</MemorySafetyMargin>       <!-- percentage -->
<MemoryThreshold>90</MemoryThreshold>               <!-- percentage -->
```

---

## Configuration Diagnostics

### rsreportserver.config Issues

**Location**:
```
%ProgramFiles%\Microsoft SQL Server\MSRS<version>.<instance>\Reporting Services\ReportServer\rsreportserver.config
```

**Common configuration problems**:

| Problem | Symptom | Resolution |
|---------|---------|------------|
| Invalid XML | Service fails to start | Validate XML; restore from backup |
| Wrong authentication type | Login failures | Verify `<AuthenticationTypes>` section matches environment |
| SMTP misconfiguration | Email subscriptions fail | Check `<RSEmailDPConfiguration>` section |
| URL reservation conflict | HTTP 503 errors | Use `netsh http show urlacl` to check for conflicts |
| Missing rendering extension | Export format unavailable | Verify `<Render>` section has required extensions |

### Service Account Issues

- **Symptom**: Report Server cannot connect to data sources or file shares
- **Check**: Verify the service account has:
  - Login rights to the SQL Server hosting ReportServer databases
  - Read access to report data sources
  - Write access to file share delivery destinations
  - Network access for SMTP delivery
- **Resolution**: Use Reporting Services Configuration Manager to change the service account. Always back up the encryption key before changing the service account

### Encryption Key Management

**When encryption key restoration is required**:
- Service account name change (not password-only changes)
- Computer or instance rename
- Migration to different hardware
- Restoring ReportServer database to a new instance
- Scale-out deployment (new instances need the same key)

**Backup process**:
1. Open Reporting Services Configuration Manager
2. Select "Encryption Keys"
3. Click "Backup"
4. Specify file path and strong password
5. File saved with `.snk` extension

**Restore process**:
```bash
# Command line alternative
rskeymgmt -a -f <backup_file.snk> -p <password>
```

**If encryption key is lost**:
- All encrypted data (stored credentials, connection strings) is irrecoverable
- Must delete encrypted content: `rskeymgmt -d`
- Re-enter all stored credentials and connection strings manually

---

## Migration and Upgrade Diagnostics

### SharePoint Integrated Mode to Native Mode

**Background**: SharePoint integrated mode was deprecated after SQL Server 2016. Organizations on integrated mode must migrate to native mode.

**Challenges**:
- No automated migration tool from SharePoint integrated mode to native mode
- Reports must be exported from SharePoint document libraries
- Security model is completely different (SharePoint permissions vs. SSRS roles)
- Report URLs change entirely
- Subscriptions must be recreated

**Approach**:
1. Export all .rdl files from SharePoint document libraries
2. Install SSRS in native mode
3. Deploy reports using rs.exe, PowerShell, or the web portal
4. Recreate data sources and datasets
5. Reassign security roles
6. Recreate subscriptions
7. Update all application integrations and bookmarks

### Version Upgrade Issues

**Common upgrade problems**:

| Issue | Versions Affected | Resolution |
|-------|------------------|------------|
| Mobile reports removed | Upgrading to 2022 | Migrate to Power BI mobile reports before upgrade |
| Comments disabled | Upgrading to 2022 | Set `EnableCommentsOnReports=true` after upgrade |
| Pin to Power BI removed | Upgrading to 2022 | Use Power BI Service direct integration instead |
| Custom extensions incompatible | Any major upgrade | Recompile extensions against new SSRS assemblies |
| Encryption key mismatch | Any migration | Back up encryption key before migration; restore on new server |
| ReportServer database schema | Any upgrade | Run SSRS setup to upgrade database schema; always back up first |

### SSRS to Power BI Report Server Migration

**Pre-migration checklist**:
1. Back up ReportServer and ReportServerTempDB databases
2. Back up encryption key
3. Document all custom extensions (authentication, delivery, rendering)
4. Inventory reports using deprecated features (mobile reports, Pin to Power BI)
5. Verify RDL compatibility -- most reports work without modification
6. Test custom code assemblies (may need recompilation)

**Post-migration verification**:
1. Verify all reports render correctly in each required format
2. Test all shared data sources and datasets
3. Verify subscription delivery (email, file share)
4. Test security -- role assignments should transfer with the database
5. Validate URL access integrations
6. Check REST API consumers for any endpoint changes

---

## Diagnostic Tools Summary

| Tool | Purpose | Location |
|------|---------|----------|
| `ExecutionLog3` view | Report execution performance and errors | ReportServer database |
| Trace logs | Detailed error diagnostics | SSRS LogFiles directory |
| HTTP logs | HTTP request/response tracking | SSRS LogFiles directory |
| Windows Event Logs | Service-level errors | Event Viewer > Application |
| Reporting Services Configuration Manager | Configuration and connectivity testing | Start Menu > SQL Server tools |
| `rskeymgmt` utility | Encryption key management | SSRS install bin directory |
| `rs.exe` utility | Scripted administration and deployment | SSRS install bin directory |
| REST API | Programmatic health checks | `http://<server>/Reports/api/v2.0/System` |
| SQL Server Profiler | Trace queries from Report Server to database | SQL Server Management Studio |
| Performance Monitor (perfmon) | SSRS performance counters | Windows |

### Key Performance Counters (perfmon)

- `MSRS 2017 Web Service: Active Sessions`
- `MSRS 2017 Web Service: Memory Cache Hits/Sec`
- `MSRS 2017 Web Service: Memory Cache Misses/Sec`
- `MSRS 2017 Web Service: Total Requests`
- `MSRS 2017 Web Service: Errors Total`

(Counter names vary by SSRS version.)

---

## Sources

- [Microsoft Learn: Troubleshoot Reporting Services Report Issues](https://learn.microsoft.com/en-us/sql/reporting-services/troubleshooting/troubleshoot-reporting-services-report-issues)
- [Microsoft Learn: ExecutionLog and ExecutionLog3 View](https://learn.microsoft.com/en-us/sql/reporting-services/report-server/report-server-executionlog-and-the-executionlog3-view)
- [Microsoft Learn: Reporting Services Log Files and Sources](https://learn.microsoft.com/en-us/sql/reporting-services/report-server/reporting-services-log-files-and-sources)
- [Microsoft Learn: Troubleshoot Reporting Services Subscriptions and Delivery](https://learn.microsoft.com/en-us/sql/reporting-services/troubleshooting/troubleshoot-reporting-services-subscriptions-and-delivery)
- [Microsoft Learn: Back Up and Restore SSRS Encryption Keys](https://learn.microsoft.com/en-us/sql/reporting-services/install-windows/ssrs-encryption-keys-back-up-and-restore-encryption-keys)
- [Microsoft Learn: Configure and Manage Encryption Keys](https://learn.microsoft.com/en-us/sql/reporting-services/install-windows/ssrs-encryption-keys-manage-encryption-keys)
- [MSSQLTips: SSRS Log Files for Troubleshooting](https://www.mssqltips.com/sqlservertip/3348/sql-server-reporting-services-ssrs-log-files-for-troubleshooting/)
- [Red-Gate Simple Talk: SSRS ReportServer Database Tables and Queries](https://www.red-gate.com/simple-talk/databases/sql-server/bi-sql-server/insights-from-the-ssrs-database/)
