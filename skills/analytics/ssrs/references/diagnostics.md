# SSRS Diagnostics Reference

Troubleshooting guide covering log sources, ExecutionLog3 analysis, common errors, performance diagnostics, configuration problems, and migration troubleshooting.

## Log Sources and Locations

### Execution Log (ReportServer Database)

The primary diagnostic tool for report performance and execution analysis.

**Views** (in the ReportServer database):

| View | Purpose |
|------|---------|
| `dbo.ExecutionLog3` | Most detailed view (recommended) |
| `dbo.ExecutionLog2` | Legacy view with less detail |
| `dbo.ExecutionLog` | Original view, basic information |

**Key columns in ExecutionLog3**:

| Column | Description |
|--------|-------------|
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
| `Source` | How served: Live, Cache, Snapshot, History |

**Configuration** (in `rsreportserver.config`):

```xml
<Add Key="ExecutionLogLevel" Value="verbose" />  <!-- verbose or normal -->
<Add Key="ExecutionLogDaysKept" Value="60" />     <!-- days to retain; 0 = unlimited -->
```

Entries exceeding the retention period are removed daily at 2:00 AM.

### Diagnostic Queries

Find slowest reports (last 7 days):

```sql
SELECT TOP 20
    ItemPath, UserName, Format,
    TimeDataRetrieval, TimeProcessing, TimeRendering,
    (TimeDataRetrieval + TimeProcessing + TimeRendering) AS TotalTimeMs,
    TimeStart, Status
FROM ExecutionLog3
WHERE TimeStart > DATEADD(day, -7, GETDATE())
ORDER BY (TimeDataRetrieval + TimeProcessing + TimeRendering) DESC;
```

Find failed executions:

```sql
SELECT ItemPath, UserName, Status, TimeStart, Parameters
FROM ExecutionLog3
WHERE Status <> 'rsSuccess'
  AND TimeStart > DATEADD(day, -7, GETDATE())
ORDER BY TimeStart DESC;
```

Report execution frequency and average time:

```sql
SELECT ItemPath, COUNT(*) AS ExecutionCount,
    AVG(TimeDataRetrieval + TimeProcessing + TimeRendering) AS AvgTotalMs,
    MAX(TimeDataRetrieval + TimeProcessing + TimeRendering) AS MaxTotalMs
FROM ExecutionLog3
WHERE TimeStart > DATEADD(day, -30, GETDATE())
GROUP BY ItemPath
ORDER BY ExecutionCount DESC;
```

Cache effectiveness:

```sql
SELECT ItemPath, Source, COUNT(*) AS ExecutionCount
FROM ExecutionLog3
WHERE TimeStart > DATEADD(day, -7, GETDATE())
GROUP BY ItemPath, Source
ORDER BY ItemPath, Source;
```

Performance breakdown by report:

```sql
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

### Report Server Trace Logs

Location:
```
%ProgramFiles%\Microsoft SQL Server\MSRS<version>.<instance>\Reporting Services\LogFiles\
```

Files:
- `ReportServerService_<timestamp>.log` -- Main service trace log
- `ReportServerWebApp_<timestamp>.log` -- Web portal/API trace log (SSRS 2016+)

Configuration (in `ReportingServicesService.exe.config`):

```xml
<system.diagnostics>
  <switches>
    <add name="DefaultTraceSwitch" value="3" />
    <!-- 0=Off, 1=Error, 2=Warning, 3=Info, 4=Verbose -->
  </switches>
</system.diagnostics>
```

### HTTP Logs

Located in the same LogFiles directory: `ReportServerService_HTTP_<timestamp>.log`. Captures HTTP request/response information including URLs, status codes, and timing.

### Windows Event Logs

- **Application log** -- SSRS errors and warnings from the Report Server service
- **System log** -- Service start/stop events, permission issues

Filter by source: `Report Server`, `Report Server (MSSQLSERVER)`, or the instance-specific source name.

## Common Issues and Resolution

### Report Rendering Failures

| Issue | Cause | Resolution |
|-------|-------|------------|
| `rsProcessingAborted` | Query timeout or processing error | Check `TimeDataRetrieval` in ExecutionLog3; increase timeout or optimize query |
| `rrRenderingError` | Rendering extension failure | Check trace logs; verify report layout for the target format |
| Blank report | Query returns no data for given parameters | Verify parameter values; test query directly against database |
| `rsErrorOpeningConnection` | Cannot connect to data source | Verify connection string, credentials, network connectivity |
| `rsAccessDenied` | Insufficient permissions | Check user's role assignments on report and data source |
| Subreport errors | Subreport not found or fails | Verify subreport path, parameters, and permissions |
| Image rendering failures | External image URLs unreachable | Verify URLs from Report Server network; consider embedded images |
| Blank pages in PDF | Body + margins exceed page width | Ensure `Body Width + Left Margin + Right Margin <= Page Width` |

### Subscription Delivery Failures

| Issue | Cause | Resolution |
|-------|-------|------------|
| Email not delivered | SMTP configuration error | Verify `<SMTPServer>` in rsreportserver.config; test SMTP connectivity |
| File share delivery fails | Permission or path issue | Ensure SSRS service account has write access to UNC path |
| Configuration error message | Invalid subscription settings | Check subscription config; verify SQL Server Agent is running |
| Data-driven subscription fails | Subscriber query error | Test subscriber query independently; check for NULL values |
| Stuck in "New Subscription" | SQL Server Agent job not created | Restart SSRS service; verify SQL Server Agent is running |

Monitoring subscriptions:

```sql
SELECT s.SubscriptionID, c.Name AS ReportName, c.Path,
    s.LastStatus, s.LastRunTime, s.Description,
    s.DeliveryExtension
FROM dbo.Subscriptions s
JOIN dbo.Catalog c ON s.Report_OID = c.ItemID
ORDER BY s.LastRunTime DESC;
```

### Timeout Errors

**Types of timeouts**:

1. **Report Execution Timeout** -- How long Report Server waits for processing
   - Site-wide: Site Settings > Report Execution Timeout
   - Per-report: Report Properties > Execution > Override site-level timeout
   - Default: No timeout (dangerous for production)

2. **Query Timeout** -- How long data source waits for query completion
   - Set in dataset properties > Query timeout
   - Default: 0 (no timeout)

3. **Session Timeout** -- How long an interactive session remains active
   - Default: 600 seconds (10 minutes)
   - Configured in rsreportserver.config: `<SessionTimeout>600</SessionTimeout>`

**Resolution approach**:

1. Check ExecutionLog3 to identify which phase is slow (data retrieval, processing, rendering)
2. If `TimeDataRetrieval` is high -- optimize the query, add indexes, use stored procedures
3. If `TimeProcessing` is high -- simplify expressions, reduce subreports, minimize grouping complexity
4. If `TimeRendering` is high -- reduce report size, minimize images, consider a different output format

## ReportServer Database Health

Database size and growth:

```sql
SELECT DB_NAME() AS DatabaseName,
    name AS FileName,
    size * 8 / 1024 AS SizeMB,
    FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024 AS UsedMB
FROM sys.database_files;
```

Catalog item inventory:

```sql
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
```

Snapshot storage:

```sql
SELECT c.Name, c.Path,
    COUNT(h.SnapshotDataID) AS SnapshotCount,
    SUM(DATALENGTH(sd.Content)) / 1024 / 1024 AS TotalSizeMB
FROM dbo.History h
JOIN dbo.Catalog c ON h.ReportID = c.ItemID
JOIN dbo.SnapshotData sd ON h.SnapshotDataID = sd.SnapshotDataID
GROUP BY c.Name, c.Path
ORDER BY TotalSizeMB DESC;
```

## Memory and Resource Issues

Symptom: Report Server unresponsive or returning 503 errors.

Check Windows Task Manager / Performance Monitor for memory consumption. Configure memory limits in `rsreportserver.config`:

```xml
<WorkingSetMaximum>3000000</WorkingSetMaximum>  <!-- KB -->
<WorkingSetMinimum>1500000</WorkingSetMinimum>   <!-- KB -->
<MemorySafetyMargin>80</MemorySafetyMargin>       <!-- percentage -->
<MemoryThreshold>90</MemoryThreshold>               <!-- percentage -->
```

## Configuration Diagnostics

### rsreportserver.config Issues

| Problem | Symptom | Resolution |
|---------|---------|------------|
| Invalid XML | Service fails to start | Validate XML; restore from backup |
| Wrong authentication type | Login failures | Verify `<AuthenticationTypes>` section |
| SMTP misconfiguration | Email subscriptions fail | Check `<RSEmailDPConfiguration>` section |
| URL reservation conflict | HTTP 503 errors | Use `netsh http show urlacl` to check conflicts |
| Missing rendering extension | Export format unavailable | Verify `<Render>` section has required extensions |

### Service Account Issues

If Report Server cannot connect to data sources or file shares, verify the service account has:
- Login rights to the SQL Server hosting ReportServer databases
- Read access to report data sources
- Write access to file share delivery destinations
- Network access for SMTP delivery

Always back up the encryption key before changing the service account.

### Encryption Key Management

**When restoration is required**:
- Service account name change
- Computer or instance rename
- Migration to different hardware
- Restoring ReportServer database to a new instance
- Scale-out deployment (new instances need the same key)

**Backup process**:
1. Open Reporting Services Configuration Manager
2. Select Encryption Keys > Backup
3. Specify file path and strong password (saved as `.snk`)

**Command-line restore**:
```bash
rskeymgmt -a -f <backup_file.snk> -p <password>
```

**If encryption key is lost**: All encrypted data (stored credentials, connection strings) is irrecoverable. Must delete encrypted content (`rskeymgmt -d`) and re-enter all credentials manually.

## Migration and Upgrade Diagnostics

### Version Upgrade Issues

| Issue | Versions Affected | Resolution |
|-------|------------------|------------|
| Mobile reports removed | Upgrading to 2022 | Migrate to Power BI mobile reports before upgrade |
| Comments disabled | Upgrading to 2022 | Set `EnableCommentsOnReports=true` after upgrade |
| Pin to Power BI removed | Upgrading to 2022 | Use Power BI Service direct integration |
| Custom extensions incompatible | Any major upgrade | Recompile against new SSRS assemblies |
| Encryption key mismatch | Any migration | Back up key before migration; restore on new server |
| ReportServer database schema | Any upgrade | Run SSRS setup to upgrade schema; always back up first |

### SharePoint Integrated Mode to Native Mode

No automated migration tool exists. Manual process:

1. Export all `.rdl` files from SharePoint document libraries
2. Install SSRS in native mode
3. Deploy reports using rs.exe, PowerShell, or web portal
4. Recreate data sources and datasets
5. Reassign security roles
6. Recreate subscriptions
7. Update all application integrations and bookmarks

### SSRS to Power BI Report Server Migration

**Pre-migration checklist**:
1. Back up ReportServer and ReportServerTempDB databases
2. Back up encryption key
3. Document custom extensions (authentication, delivery, rendering)
4. Inventory reports using deprecated features (mobile reports, Pin to Power BI)
5. Verify RDL compatibility (most reports work without modification)
6. Test custom code assemblies (may need recompilation)

**Post-migration verification**:
1. Verify all reports render correctly in each required format
2. Test all shared data sources and datasets
3. Verify subscription delivery (email, file share)
4. Test security (role assignments should transfer with the database)
5. Validate URL access integrations
6. Check REST API consumers for endpoint changes

## Diagnostic Tools Summary

| Tool | Purpose |
|------|---------|
| `ExecutionLog3` view | Report execution performance and errors |
| Trace logs | Detailed error diagnostics (LogFiles directory) |
| HTTP logs | HTTP request/response tracking (LogFiles directory) |
| Windows Event Logs | Service-level errors (Event Viewer > Application) |
| Reporting Services Configuration Manager | Configuration and connectivity testing |
| `rskeymgmt` utility | Encryption key management |
| `rs.exe` utility | Scripted administration and deployment |
| REST API `/api/v2.0/System` | Programmatic health checks |
| SQL Server Profiler | Trace queries from Report Server to database |
| Performance Monitor (perfmon) | SSRS performance counters |

### Key Performance Counters

- `MSRS <version> Web Service: Active Sessions`
- `MSRS <version> Web Service: Memory Cache Hits/Sec`
- `MSRS <version> Web Service: Memory Cache Misses/Sec`
- `MSRS <version> Web Service: Total Requests`
- `MSRS <version> Web Service: Errors Total`

Counter names vary by SSRS version.
