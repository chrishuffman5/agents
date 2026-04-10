# Informatica IDMC Diagnostics

## Common Issues

### Secure Agent Connectivity

**Agent Not Starting or Connecting:**
- Verify network connectivity between agent host and IDMC cloud endpoints
- Check firewall rules for required outbound ports (HTTPS 443)
- Validate proxy configuration if agent is behind a corporate proxy
- Ensure DNS resolution works for IDMC PoD URLs
- Check that the agent token/registration is valid and not expired
- Review agent logs in the Secure Agent installation directory

**Agent Service Failures:**
- If a service fails with error status, the error may persist in Agent Service Details even after recovery; this is cosmetic and clears after an internal cleanup job runs
- Stop the Secure Agent before uninstalling; if uninstalled without stopping, Agent Core and services may continue running for several minutes
- Restart individual services from the Administrator console rather than restarting the entire agent when possible
- Check Java heap settings if services crash with OutOfMemory errors

**Agent Upgrade Issues:**
- Ensure sufficient disk space before upgrade
- Verify agent host meets minimum system requirements for the new version
- Back up agent configuration before upgrading
- Monitor agent services after upgrade to confirm all services start successfully

### Mapping Errors

**Common Mapping Failures:**
- **Data type mismatches**: Source/target schema changes cause type conversion failures; review source qualifier and target definitions
- **Connection failures**: Database credentials expired or connection parameters changed; test connections from Administrator
- **Lookup failures**: Lookup source table missing, renamed, or permissions changed
- **Expression errors**: Division by zero, null pointer in string operations, invalid date formats
- **Memory errors**: Large lookup caches or aggregation buffers exceed available memory; increase heap or reduce cache size
- **Pushdown SQL errors**: Generated SQL incompatible with database version; review pushdown SQL in session logs

**Mapplet-Related Issues:**
- Cyclic reference errors when mapplets reference each other
- Missing Input/Output transformations in mapplet definition
- Parameter propagation failures between parent mapping and nested mapplets

### Session Failures

**Frequent Session-Level Failures:**
- **Timeout errors**: Long-running sessions exceed configured timeout; increase timeout or optimize mapping
- **Lock contention**: Concurrent sessions competing for target table locks; stagger execution or use row-level locking
- **Resource exhaustion**: Agent host running out of CPU, memory, or disk; monitor host resources
- **Network interruption**: Transient network issues between agent and data sources; implement retry logic in taskflows
- **Permission errors**: Database user lacks required privileges (INSERT, UPDATE, DELETE, CREATE TABLE)

### Taskflow Failures

- **Linear taskflow limitation**: If a task fails in a linear taskflow, the entire workflow must restart; use standard taskflows for recovery capability
- **Decision step misconfiguration**: Incorrect field references or condition logic causing unexpected routing
- **Parallel path deadlocks**: Dependent tasks placed in parallel paths that should be sequential
- **Notification failures**: SMTP configuration errors preventing email delivery

---

## Performance Diagnostics

### Session Log Analysis

**Thread Statistics (Key Diagnostic Tool):**

Session logs contain thread summary information that is the primary method for identifying bottlenecks:

- **Reader Thread**: Reads data from source; high busy percentage indicates source bottleneck
- **Transformation Thread**: Processes transformation logic; high busy percentage indicates transformation bottleneck
- **Writer Thread**: Writes data to target; high busy percentage indicates target bottleneck

**Interpreting Thread Statistics:**
- The thread with the **highest busy percentage** is the bottleneck
- A busy percentage of 100% means that thread was never idle (definitive bottleneck)
- Example: If transformation thread shows 99.7% busy, reader 9.6%, writer 24%, transformations are the bottleneck

**Bottleneck Identification Techniques:**

| Suspected Bottleneck | Diagnostic Approach |
|---------------------|-------------------|
| Source | Add Filter with FALSE condition after Source Qualifier; if session completes quickly, source is the bottleneck |
| Target | Replace relational target with flat file; if execution time drops significantly, target is the bottleneck |
| Transformation | Review per-transformation busy percentages in thread work time breakdown |
| Network | Compare execution time with source/target on same network vs. remote |

### Pushdown Analysis

**Verifying Pushdown Execution:**
- Review session logs for generated SQL statements
- Check if transformations were successfully pushed down or fell back to in-memory processing
- Verify that pushdown SQL is syntactically correct for the target database version
- Look for warning messages about unsupported pushdown transformations

**Pushdown Failures:**
- Variable ports in Expression transformations prevent pushdown
- Database-specific functions without SQL equivalents fall back to in-memory
- Null Comparison enabled on Lookup transformations degrades pushdown performance
- Cross-database PDO requires compatible database connections

### Bottleneck Identification Checklist

**Source Bottlenecks:**
- [ ] Check source query execution plan for full table scans
- [ ] Verify indexes exist on filter and join columns
- [ ] Review SQL override for optimization opportunities
- [ ] Check source database load and concurrent sessions
- [ ] Evaluate network bandwidth between agent and source

**Target Bottlenecks:**
- [ ] Check target table indexes (drop before load, rebuild after)
- [ ] Review commit interval (too frequent = overhead; too infrequent = lock escalation)
- [ ] Verify bulk loading is enabled where supported
- [ ] Check target database redo log sizing
- [ ] Evaluate constraint checking overhead

**Transformation Bottlenecks:**
- [ ] Review lookup cache sizes and hit ratios
- [ ] Check for unnecessary data type conversions
- [ ] Evaluate complex expression logic for simplification
- [ ] Consider pushdown optimization for heavy transformations
- [ ] Review Aggregator sorted input configuration

**Memory Bottlenecks:**
- [ ] Monitor agent host memory utilization during execution
- [ ] Review Java heap settings for agent services
- [ ] Check lookup cache memory allocation
- [ ] Evaluate Aggregator and Sorter memory requirements
- [ ] Consider partitioning to distribute memory load

---

## Monitoring

### Activity Monitor

The Activity Monitor is the primary IDMC interface for tracking job execution:

- **Real-time job tracking**: View running, completed, failed, and queued jobs
- **Filtering**: Filter by date range, task type, status, runtime environment, and user
- **Job details**: Drill into individual job execution for row counts, timing, and error details
- **Log access**: Download session logs and error logs directly from the monitor
- **Retry capability**: Re-execute failed jobs directly from the Activity Monitor

### Operations Dashboards

**Built-in Monitoring:**
- IDMC Platform Monitoring and Operational Insights dashboard
- Job execution history and trend analysis
- Resource utilization tracking
- Service health status across agents and services

**Log Configuration:**
- Configure log levels through Administrator Console or task properties
- **INFO level**: Standard production monitoring (sufficient for routine operations)
- **DEBUG level**: Detailed troubleshooting and performance analysis (higher overhead)
- **WARNING/ERROR level**: Minimal logging for high-performance production scenarios
- Log retention configuration to manage storage

### IDMC Log Analyzer

- Specialized utility for searching and analyzing activity logs and taskflow logs
- Captures metering usage data (IPU consumption tracking)
- Identifies bottlenecks, operational trends, and incidents
- Audit trail analysis for compliance
- Critical point identification for proactive issue resolution

### Alerting

**Built-in Alerting:**
- Taskflow Notification steps for email-based alerting
- Fault suspension with email notification on taskflow failures
- Agent service health status monitoring

**External Integration:**
- Informatica monitoring extension for Dynatrace
- Forward logs to Splunk, Datadog, or other enterprise monitoring platforms
- REST API-based integration with custom monitoring solutions
- Webhook triggers for real-time alerting systems

### Secure Agent Health Check

- Informatica provides a Secure Agent Health Check accelerator
- Reviews agent configuration, service status, and connectivity
- Identifies potential issues before they impact production
- Recommended as part of regular operational maintenance

---

## Diagnostic Workflow

### Standard Troubleshooting Process

1. **Check Activity Monitor**: Identify failed job, review status and error summary
2. **Download session logs**: Get detailed execution logs for the failed session
3. **Review error messages**: Identify error codes and descriptive messages
4. **Check thread statistics**: Identify if failure is source, transformation, or target related
5. **Review Secure Agent logs**: Check for agent-level issues (connectivity, service failures)
6. **Check host resources**: Verify CPU, memory, disk, and network on the agent host
7. **Test connections**: Validate source and target connectivity from Administrator
8. **Review recent changes**: Check if any mapping, connection, or infrastructure changes preceded the failure
9. **Retry the job**: For transient failures, retry from the Activity Monitor
10. **Escalate**: If unresolved, engage Informatica Global Customer Support with logs and error details

### Preventive Diagnostics

- **Regular health checks**: Run Secure Agent Health Check periodically
- **Monitor trends**: Track job execution times over time to detect gradual degradation
- **Review IPU consumption**: Identify unexpectedly high consumption patterns
- **Agent updates**: Keep agents on supported versions with latest patches
- **Capacity planning**: Monitor agent host resources and plan for growth
- **Test environment validation**: Validate changes in lower environments before production deployment
