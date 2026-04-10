# Qlik Sense Diagnostics Guide

## Diagnostic Tools and Resources

### Built-In Monitoring Apps (Client-Managed)

| App | Purpose |
|-----|---------|
| **Operations Monitor** | Hardware utilization (memory, CPU), active users, reload task activity, errors/warnings, log analysis |
| **License Monitor** | License usage, token allocation, access pass consumption |
| **Log Monitor** | Centralized log viewing across all Qlik services |
| **Sessions Monitor** | Active user sessions, session duration, concurrent usage patterns |
| **Reloads Monitor** | Reload history, success/failure rates, duration trends |

### Qlik Cloud Monitoring

- **Management Console**: Tenant-level resource usage, user activity, reload schedules
- **Qlik Automate**: Build custom monitoring workflows with alerts
- **Usage Metrics**: Built-in analytics on app usage, user engagement, and data consumption
- **Audit Logs**: Authentication events, admin actions, data access records

### External Monitoring Tools

- **Windows Performance Monitor (PerfMon)**: Track memory, CPU, disk I/O at the OS level during engine load
- **Task Manager / Resource Monitor**: Real-time process monitoring for engine memory consumption
- **Database monitoring**: PostgreSQL metrics for the repository database (client-managed)

## Slow App Diagnostics

### Symptoms

- Long initial app open times
- Slow response to selections (visible spinner or delay)
- Charts take seconds to render after selection changes
- Sheets hang or become unresponsive during exploration

### Diagnostic Steps

**1. Measure App Baseline Metrics**

| Metric | How to Check | Concern Threshold |
|--------|-------------|-------------------|
| Disk size | QMC > Apps > File size column | > 500 MB warrants investigation |
| RAM footprint | Restart engine, note RAM before/after opening app | > 4 GB on SaaS (5 GB limit); proportional to server RAM on-prem |
| Total rows | `Sum($Rows)` in a KPI | > 100M rows; performance depends on hardware |
| Total fields | `Sum($Fields)` in a KPI | > 200 fields suggests cleanup needed |
| Total tables | `Count(DISTINCT $Table)` | > 20 tables; check for unnecessary complexity |

**2. Data Model Analysis**

Open the **Data Model Viewer** and check for:

- **Synthetic keys**: Tables linked by auto-generated `$Syn` tables indicate unresolved multi-field joins. These force the engine to maintain additional cross-reference tables.
- **Circular references**: Look for loosely coupled tables (shown as dotted lines). These degrade calculation accuracy and performance.
- **Data islands**: Unconnected tables that cannot participate in associative filtering. Consume memory without analytical value.
- **High-cardinality fields**: Click on tables and review field cardinality. Fields with millions of unique values (e.g., raw timestamps, transaction IDs) consume disproportionate memory.
- **Wide tables**: Tables with many fields increase per-row memory overhead.

**3. Expression Profiling**

- Enable the **Performance Profiler** (available in developer tools) to measure calculation time per object.
- Identify objects with the longest calculation times.
- Look for `If()` conditions inside aggregations that should be converted to set analysis.
- Check for nested `Aggr()` functions, especially with multiple dimensions.
- Look for `WildMatch()`, `Match()`, and string operations in measures that could use pre-calculated flags.

**4. Selection State Impact**

- Test app performance with no selections vs. restrictive selections.
- If performance is acceptable with selections but poor with none, add calculation conditions to heavy objects (e.g., "Select a Region to view this chart").

### Common Fixes

| Issue | Fix |
|-------|-----|
| Synthetic keys | Create explicit composite keys; rename non-key shared fields |
| Circular references | Restructure model or use a link table |
| Excessive fields | Drop unused fields in the load script |
| High cardinality timestamps | Separate date and time; drop seconds/milliseconds if unused |
| Slow expressions | Convert `If()` to set analysis; pre-calculate in script; add calculation conditions |
| Too many objects per sheet | Reduce to 5-10 per sheet; use container/tab objects |
| Large straight tables | Limit columns to < 15; add calculation conditions |

## Memory Issues

### Symptoms

- Engine service consumes excessive server RAM
- Multiple apps cannot be opened simultaneously
- Out-of-memory errors during reload or user sessions
- Server becomes unresponsive under concurrent load

### Diagnostic Steps

**1. Determine Memory Usage Baseline**

- **Server total RAM**: Check system properties
- **Engine process memory**: Monitor the `engine.exe` process (client-managed) or check Management Console metrics (SaaS)
- **Per-app memory**: Open apps one at a time, measuring RAM delta for each
- **Concurrent user impact**: Monitor memory growth as users connect and make selections

**2. Memory Usage Guidelines**

| Usage Level | Recommendation |
|-------------|----------------|
| < 70% server RAM | Normal operating range |
| 70-85% | Monitor closely; plan capacity expansion |
| 85-90% | Reduce app sizes or add engine nodes |
| > 90% | Critical; immediate action required -- engine may refuse new app opens or crash |

**3. Identify Memory-Heavy Apps**

- Sort apps by file size in the QMC; large disk size often correlates with high RAM usage (though compression ratios vary)
- Use the Operations Monitor to identify apps consuming the most resources
- Check for apps with unnecessary data loaded (e.g., full transaction history when only aggregates are needed)

**4. Qlik Cloud Memory Limits**

- Default per-app memory limit: 5 GB
- Apps exceeding the limit fail to open or reload
- Additional capacity can be purchased
- Use ODAG or segmentation to break large datasets into manageable apps

### Common Fixes

| Issue | Fix |
|-------|-----|
| App too large for available RAM | Segment data by time period/region; implement ODAG |
| Unused fields consuming memory | Audit and drop fields not referenced in any visualization |
| High cardinality fields | Reduce granularity (remove seconds from timestamps, bucket continuous values) |
| Data islands | Remove unconnected tables or connect them to the model |
| Memory not released after failed reload | Engine should release memory after failure; if not, restart the engine service during off-hours |
| Too many concurrent apps | Implement load balancing across multiple engine nodes; schedule staggered reload times |

## Reload Failures

### Symptoms

- Reload tasks show "Failed" status in QMC or Management Console
- Partial data loads (some tables loaded, others missing)
- Reload completes but with incorrect data or unexpected row counts
- Reload runs indefinitely without completing

### Diagnostic Steps

**1. Check Reload Logs**

- **QMC > Tasks > Last execution**: View the execution log for error details
- **Script Log**: The reload log shows the exact script line where failure occurred
- **Data Load Editor**: Run the script in debug mode to step through execution
- **Qlik Cloud**: Check reload history in the app details panel

**2. Common Error Categories**

| Error Type | Typical Causes |
|------------|---------------|
| **Connection errors** | Database down, credentials expired, network timeout, firewall changes |
| **Syntax errors** | Typos in script, missing semicolons, unmatched quotes |
| **Data errors** | Unexpected NULL values, data type mismatches, changed source schema |
| **Memory errors** | Insufficient RAM for the data volume being loaded |
| **Permission errors** | Service account lacks read access to source data or file shares |
| **Timeout errors** | Long-running SQL queries exceed connection timeout; network interruptions |

**3. Connection Troubleshooting**

For ODBC/OLE DB connection failures:

1. **Isolate the layer**: Test the connection outside of Qlik using a tool like DBeaver, Excel, or `sqlcmd` to determine if the issue is the driver, the network, or Qlik itself.
2. **Check DSN configuration**: Verify the System DSN (not User DSN) is configured correctly on the server running the Engine Service.
3. **Multi-node environments**: Ensure ODBC drivers and DSNs are installed on ALL nodes that may execute the reload, not just the central node.
4. **Credential rotation**: If credentials were recently changed, update the data connection in the QMC or Data Load Editor.
5. **Proxy/firewall**: For REST connectors in proxy environments, configure the forward proxy settings for the connector.

**4. Data Integrity Checks**

- Compare expected vs. actual row counts after reload using `NoOfRows()` or `$Rows` system field
- Check for synthetic keys that appeared after a source schema change
- Validate that incremental load watermarks are advancing correctly
- Look for duplicate key values causing unintended associations

### Common Fixes

| Issue | Fix |
|-------|-----|
| Expired credentials | Update data connection credentials in QMC/Management Console |
| Source schema changed | Update LOAD/SQL SELECT statements to match new schema |
| Memory exceeded during reload | Optimize the load script; use incremental loading; add RAM |
| Long-running SQL queries | Add WHERE clauses to limit data at source; use incremental extraction |
| File path issues | Verify UNC paths are accessible from the service account; check drive mappings |
| Encoding issues | Specify `UTF8` or appropriate code page in the LOAD statement |
| Script timeout | Increase timeout settings; break large loads into staged QVD extractions |

### Error Handling in Scripts

Implement proactive error handling in reload scripts:

```
// Set error mode to continue on error
SET ErrorMode=0;

// Load data
SQL SELECT * FROM Orders;

// Check for errors
IF ScriptError > 0 THEN
    LET vErrorMsg = ScriptErrorDetails;
    // Log the error or take corrective action
    TRACE Error loading Orders: $(vErrorMsg);
END IF

// Reset error mode
SET ErrorMode=1;
```

## Engine Performance

### Symptoms

- High CPU utilization sustained above 80% during user sessions
- Slow calculation engine response across multiple apps
- Session timeouts under concurrent load
- Reload queue backing up

### Diagnostic Steps

**1. Hardware Assessment**

| Resource | Check | Target |
|----------|-------|--------|
| CPU | PerfMon: % Processor Time for engine process | < 80% sustained; spikes during reload are normal |
| RAM | PerfMon: Available MBytes; Engine memory working set | > 15-20% free after all apps loaded |
| Disk I/O | PerfMon: Disk Queue Length, Disk Bytes/sec | Queue length < 2; SSD strongly recommended |
| Network | PerfMon: Network Interface throughput | < 70% of link capacity |

**2. Engine Configuration Review**

- **Working set limits**: On client-managed, check if engine memory limits are configured too low
- **Thread allocation**: Verify the engine has access to all CPU cores
- **Virtual memory**: Ensure page file is adequately sized (though reliance on paging indicates insufficient RAM)
- **Reload concurrency**: Check how many simultaneous reloads are permitted; too many competing for memory causes contention

**3. Session Analysis**

- Use the Sessions Monitor to identify peak usage times
- Correlate performance degradation with specific times or user activity spikes
- Check for "heavy" users running complex selections across large apps during peak hours

**4. Qlik Cloud Engine Diagnostics**

- Monitor reload duration trends in the Management Console
- Check for apps approaching the 5 GB memory limit
- Review the auto-scaling behavior: if engines are scaling frequently, workloads may be uneven
- Use Qlik Automate to build alerting workflows for engine health metrics

### Common Fixes

| Issue | Fix |
|-------|-----|
| CPU saturated | Add engine nodes; optimize expressions; reduce object count per sheet |
| RAM exhausted | Add RAM; optimize data models; segment large apps |
| Disk bottleneck | Move to SSD/NVMe; ensure QVD storage is on fast disks |
| Reload contention | Stagger reload schedules; dedicate nodes for reload vs. user-facing workloads |
| Session overload | Implement load balancing across engine nodes; add capacity for peak times |

## Connectivity Issues

### Symptoms

- "Connection failed" errors when testing data connections
- Reloads fail at SQL SELECT statements
- REST connector returns HTTP errors or timeouts
- New data connections cannot be created

### Diagnostic Approach

**1. Layer Isolation**

Test connectivity at each layer independently:

```
Application Layer    →  Qlik Engine Service
         ↓
Connector Layer      →  ODBC Driver / OLE DB Provider / REST Connector
         ↓
Network Layer        →  DNS, firewall, proxy, TLS/SSL
         ↓
Source Layer          →  Database server, API endpoint, file share
```

**2. ODBC/OLE DB Checklist**

- [ ] Driver installed on ALL engine nodes (not just central node)
- [ ] System DSN (not User DSN) configured under 64-bit ODBC Administrator
- [ ] Service account has database permissions (SELECT at minimum)
- [ ] Database server is reachable from the Qlik server (test with `telnet hostname port`)
- [ ] TLS/SSL certificates are valid and trusted by the Qlik server
- [ ] Connection string parameters match the database configuration

**3. REST Connector Checklist**

- [ ] Endpoint URL is correct and accessible from the Qlik server
- [ ] Authentication tokens/keys are valid and not expired
- [ ] Request headers are correctly configured
- [ ] Forward proxy settings are configured if required
- [ ] Response pagination is handled correctly for large datasets
- [ ] SSL certificate chain is valid

**4. File Source Checklist**

- [ ] UNC paths used (not mapped drive letters) for multi-node environments
- [ ] Service account has read access to the file share
- [ ] File is not locked by another process
- [ ] File encoding matches the LOAD statement specification
- [ ] File path exists and is spelled correctly (case-sensitive on Linux)

### Cloud-Specific Connectivity

For Qlik Cloud deployments:

- **Qlik Data Gateway - Direct Access**: Required for connecting to on-premise data sources from Qlik Cloud without opening inbound firewall ports
- **Qlik Data Gateway - Data Movement**: Required for CDC and data replication from on-premise sources
- **IP Whitelisting**: Qlik Cloud outbound IPs may need to be whitelisted on source firewalls

## Performance Monitoring Checklist

### Daily Checks

- [ ] Review failed reload tasks in QMC/Management Console
- [ ] Check engine memory utilization (should be below 85%)
- [ ] Verify critical app reloads completed successfully with expected row counts

### Weekly Checks

- [ ] Review Operations Monitor for performance trends
- [ ] Check for apps with growing disk/memory size
- [ ] Audit user session patterns for capacity planning
- [ ] Review error logs for recurring warnings

### Monthly Checks

- [ ] Audit data model health across production apps (synthetic keys, circular references)
- [ ] Review expression performance in top-usage apps
- [ ] Validate backup and disaster recovery procedures
- [ ] Assess whether current hardware meets demand trends
- [ ] Review and clean up unused apps, data connections, and user accounts
