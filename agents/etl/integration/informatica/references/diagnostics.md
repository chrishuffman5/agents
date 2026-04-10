# Informatica IDMC Diagnostics

## Secure Agent Connectivity

### Agent Not Starting or Connecting

**Symptoms**: Agent shows as unavailable in IDMC Administrator. Tasks fail with "no available runtime environment."

**Diagnostic Steps**:
1. Verify network connectivity between agent host and IDMC cloud endpoints
2. Check firewall rules for required outbound ports (HTTPS 443)
3. Validate proxy configuration if agent is behind a corporate proxy
4. Ensure DNS resolution works for IDMC PoD URLs
5. Check that the agent token/registration is valid and not expired
6. Review agent logs in the Secure Agent installation directory

**Common Resolutions**:

| Problem | Fix |
|---|---|
| Firewall blocking outbound HTTPS | Open port 443 to IDMC cloud endpoints |
| DNS resolution failure | Configure DNS on agent host or add hosts file entries |
| Proxy misconfiguration | Update proxy settings in agent configuration |
| Expired registration token | Re-register the agent with a new token from IDMC Administrator |
| Java heap insufficient | Increase heap settings for agent services |

### Agent Service Failures

- If a service fails with error status, the error may persist in Agent Service Details even after recovery. This is cosmetic and clears after an internal cleanup job runs.
- Stop the Secure Agent before uninstalling. If uninstalled without stopping, Agent Core and services may continue running for several minutes.
- Restart individual services from the Administrator console rather than restarting the entire agent when possible.
- Check Java heap settings if services crash with OutOfMemoryError.

### Agent Upgrade Issues

- Ensure sufficient disk space before upgrade
- Verify agent host meets minimum system requirements for the new version
- Back up agent configuration before upgrading
- Monitor agent services after upgrade to confirm all services start successfully

## Mapping Errors

### Common Mapping Failures

| Error | Typical Cause | Resolution |
|---|---|---|
| Data type mismatch | Source/target schema change | Review source qualifier and target definitions; update schema |
| Connection failure | Credentials expired or changed | Test connections from Administrator; update credentials |
| Lookup failure | Lookup table missing/renamed/permissions | Verify lookup source exists and agent user has access |
| Expression error | Division by zero, null pointer, invalid date | Add null checks and type validation in expressions |
| Memory error | Large lookup cache or aggregation buffer | Increase heap or reduce cache size; consider database joins |
| Pushdown SQL error | Generated SQL incompatible with DB version | Review pushdown SQL in session logs; adjust transformations |

### Mapplet-Related Issues

- **Cyclic reference errors**: Mapplet A references Mapplet B which references Mapplet A. Restructure to eliminate circular dependencies.
- **Missing Input/Output transformations**: Mapplet must have at least one Input and one Output transformation defined.
- **Parameter propagation failures**: Parameters defined in parent mapping may not propagate to nested mapplets. Verify parameter scope and naming.

### Data Type Mapping Issues

**Symptoms**: Type conversion failures, truncation warnings, null values in unexpected columns.

**Diagnostic Steps**:
1. Compare source and target schemas: check data types, precision, scale, nullable
2. Review column mapping in the mapping definition
3. Check session logs for specific type conversion error messages
4. For pushdown, review generated SQL for unexpected CAST operations

**Common Resolutions**:

| Issue | Fix |
|---|---|
| Decimal precision/scale mismatch | Use explicit type conversion in Expression transformation |
| Datetime format mismatch | Specify format string in source/target definitions |
| Encoding issues (UTF-8 vs extended) | Set encoding explicitly on file connection properties |
| Null in non-nullable target column | Add default value handling in Expression (IIF/DECODE) |
| String truncation | Increase target column size or truncate in Expression |

## Session Failures

### Frequent Session-Level Failures

| Failure | Cause | Resolution |
|---|---|---|
| Timeout | Long-running session exceeds configured timeout | Increase timeout or optimize mapping |
| Lock contention | Concurrent sessions competing for table locks | Stagger execution or use row-level locking |
| Resource exhaustion | Agent host out of CPU/memory/disk | Monitor host resources; scale agent group |
| Network interruption | Transient issues between agent and data sources | Implement retry logic in taskflows |
| Permission error | DB user lacks INSERT/UPDATE/DELETE/CREATE TABLE | Grant required privileges to the database user |

### Taskflow Failures

- **Linear taskflow limitation**: If a task fails in a linear taskflow, the entire workflow must restart. Use standard taskflows for recovery capability.
- **Decision step misconfiguration**: Incorrect field references or condition logic causing unexpected routing. Review Decision step conditions carefully.
- **Parallel path deadlocks**: Dependent tasks placed in parallel paths that should be sequential. Restructure to sequential where dependencies exist.
- **Notification failures**: SMTP configuration errors preventing email delivery. Test SMTP settings independently.

## Performance Diagnostics

### Thread Statistics (Primary Diagnostic Tool)

Session logs contain thread summary information that is the key method for identifying bottlenecks:

- **Reader Thread**: Reads data from source. High busy percentage = source bottleneck.
- **Transformation Thread**: Processes transformation logic. High busy percentage = transformation bottleneck.
- **Writer Thread**: Writes data to target. High busy percentage = target bottleneck.

**Interpreting Results**:
- The thread with the **highest busy percentage** is the bottleneck
- 100% busy = that thread was never idle (definitive bottleneck)
- Example: If transformation thread shows 99.7% busy, reader 9.6%, writer 24%, transformations are the bottleneck

### Bottleneck Identification Checklist

**Source Bottlenecks**:
- [ ] Check source query execution plan for full table scans
- [ ] Verify indexes exist on filter and join columns
- [ ] Review SQL override for optimization opportunities
- [ ] Check source database load and concurrent sessions
- [ ] Evaluate network bandwidth between agent and source

**Target Bottlenecks**:
- [ ] Check target table indexes (drop before load, rebuild after)
- [ ] Review commit interval (too frequent = overhead; too infrequent = lock escalation)
- [ ] Verify bulk loading is enabled where supported
- [ ] Check target database redo log sizing
- [ ] Evaluate constraint checking overhead

**Transformation Bottlenecks**:
- [ ] Review lookup cache sizes and hit ratios
- [ ] Check for unnecessary data type conversions
- [ ] Evaluate complex expression logic for simplification
- [ ] Consider pushdown optimization for heavy transformations
- [ ] Review Aggregator sorted input configuration

**Memory Bottlenecks**:
- [ ] Monitor agent host memory utilization during execution
- [ ] Review Java heap settings for agent services
- [ ] Check lookup cache memory allocation
- [ ] Evaluate Aggregator and Sorter memory requirements
- [ ] Consider partitioning to distribute memory load

### Pushdown Analysis

**Verifying Pushdown Execution**:
1. Review session logs for generated SQL statements
2. Check if transformations were successfully pushed down or fell back to in-memory processing
3. Verify that pushdown SQL is syntactically correct for the target database version
4. Look for warning messages about unsupported pushdown transformations

**Common Pushdown Failures**:
- Variable ports in Expression transformations prevent pushdown
- Database-specific functions without SQL equivalents fall back to in-memory
- Null Comparison enabled on Lookup transformations degrades pushdown performance
- Cross-database PDO requires compatible database connections

## Monitoring

### Activity Monitor

The Activity Monitor is the primary IDMC interface for tracking job execution:

- **Real-time job tracking**: View running, completed, failed, and queued jobs
- **Filtering**: Filter by date range, task type, status, runtime environment, and user
- **Job details**: Drill into individual job execution for row counts, timing, and error details
- **Log access**: Download session logs and error logs directly from the monitor
- **Retry capability**: Re-execute failed jobs directly from the Activity Monitor

### IDMC Log Analyzer

- Specialized utility for searching and analyzing activity logs and taskflow logs
- Captures metering usage data (IPU consumption tracking)
- Identifies bottlenecks, operational trends, and incidents
- Audit trail analysis for compliance
- Critical point identification for proactive issue resolution

### Built-in Alerting

- Taskflow Notification steps for email-based alerting
- Fault suspension with email notification on taskflow failures
- Agent service health status monitoring in Administrator console

### External Integration

- Informatica monitoring extension for Dynatrace
- Forward logs to Splunk, Datadog, or other enterprise monitoring platforms
- REST API-based integration with custom monitoring solutions
- Webhook triggers for real-time alerting systems

### Secure Agent Health Check

Informatica provides a Secure Agent Health Check accelerator:
- Reviews agent configuration, service status, and connectivity
- Identifies potential issues before they impact production
- Recommended as part of regular operational maintenance

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

## Cost Analysis

### Identifying Cost Drivers

Use IPU monitoring to break down consumption by service:

| Driver | What It Measures | How to Reduce |
|---|---|---|
| CDI compute | Mapping task execution | Pushdown optimization, incremental loads, batch consolidation |
| Elastic compute | Spark cluster usage | Right-size clusters, batch similar workloads |
| Serverless compute | Auto-scaled execution | Leverage auto-tuning, minimize data movement |
| CDC replication | Continuous change capture | Optimize source log configuration, filter unnecessary tables |
| Data Quality | Profiling and cleansing | Target profiling to specific datasets, schedule off-peak |
| API calls | REST/SOAP API invocations | Cache responses, reduce polling frequency |

### Cost Investigation Workflow

1. **IPU dashboard**: Review consumption by service, environment, and time period
2. **Activity Monitor**: Identify jobs with highest execution time and frequency
3. **Session logs**: Check data volumes processed -- excessive full loads waste IPU
4. **Pushdown analysis**: Verify pushdown is active for eligible mappings (in-memory processing consumes more IPU than pushdown)
5. **Schedule review**: Check for overlapping or unnecessary job schedules
6. **Agent utilization**: Verify agents are right-sized -- over-provisioned agents have idle costs, under-provisioned ones have queuing delays
