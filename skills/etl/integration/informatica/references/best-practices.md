# Informatica IDMC Best Practices

## Mapping Design

### Transformation Selection

- **Use the simplest transformation** that achieves the goal. Avoid over-engineering with unnecessary complexity.
- **Filter early**: Place Filter transformations as close to the source as possible with simple conditions to reduce data volume flowing through the pipeline.
- **Minimize transformation count**: Each additional transformation adds processing overhead. Consolidate logic where possible.
- **Choose Expression over Java Transformation** for simple logic. Java transformations have higher startup costs and initialization overhead.
- **Use Lookup wisely**: Connected lookups for row-by-row enrichment; unconnected lookups for conditional lookups; cache lookups for reference data.
- **Aggregator optimization**: Use sorted input option when source data is pre-sorted. Group by integer columns rather than strings for better performance.
- **Avoid unnecessary data type conversions**: Each CAST operation adds overhead, especially in pushdown scenarios where extra CAST statements are generated in SQL.

### Pushdown Optimization (ELT)

- **Maintain consistent data types**: Keep the same data type, precision, and scale from source through transformations to target. Avoids additional CAST statements in pushdown SQL.
- **Prefer Full Pushdown** when source and target are in the same database or on the same platform.
- **Enable Source-Side Pushdown** for transformations that reduce data volume (Filter, Aggregator) to minimize data movement to the agent.
- **Target-Side Pushdown** is ideal when complex transformations can be expressed in target-native SQL.
- **Disable Null Comparison** on Lookup transformations when using pushdown. Enabling it with multiple lookups degrades performance.
- **Test pushdown SQL**: Review generated SQL in session logs to verify correctness and optimization.
- **Use $$PushdownConfig parameter** for environment-specific pushdown configuration.
- **Enable Cross-Schema PDO** when source and target reside in different schemas within the same database.

### Reusable Mapplets

- **Encapsulate common logic** in mapplets for reuse across multiple mappings.
- **Design Input/Output transformations carefully**: Define clear interfaces with documented port descriptions.
- **Avoid circular references**: Mapplet A can use Mapplet B, but B cannot reference A.
- **Use nested mapplets** for complex multi-stage transformations; keep nesting depth manageable (3 levels max recommended).
- **Parameterize mapplets** to maximize reusability across different source/target configurations.
- **Version mapplets independently**: Test changes in isolation before deploying to dependent mappings.

### Parameterization

- **Parameterize connections**: Enable the same mapping to run against different environments (dev/test/prod).
- **Parameterize source/target objects**: Use Dynamic Mapping Tasks for multi-source/target patterns to reduce asset proliferation.
- **Parameterize filter conditions**: Enable runtime data selection without mapping changes.
- **Use parameter files**: Centralize parameter management for batch execution.
- **Document parameters**: Include descriptions for every parameter to aid maintainability.

## Performance Tuning

### Session and Mapping Optimization

- **Identify bottlenecks systematically**: Check in order: source, target, transformations, mapping, session.
- **Read thread statistics**: Session logs contain thread summary information. The thread with the **highest busy percentage** is the bottleneck:
  - **Reader Thread**: High busy % = source bottleneck
  - **Transformation Thread**: High busy % = transformation bottleneck
  - **Writer Thread**: High busy % = target bottleneck
  - A busy percentage of 100% means that thread was never idle (definitive bottleneck).

### Bottleneck Isolation Techniques

| Suspected Bottleneck | Diagnostic Approach |
|---|---|
| Source | Add Filter with FALSE condition after Source Qualifier; if session completes quickly, source is the bottleneck |
| Target | Replace relational target with flat file; if execution time drops significantly, target is the bottleneck |
| Transformation | Review per-transformation busy percentages in thread work time breakdown |
| Network | Compare execution time with source/target on same network vs remote |

### Source Optimization

- Use SQL overrides to filter at the database level
- Add database indexes on join and filter columns
- Avoid SELECT * patterns; select only needed columns
- Push WHERE clauses to the source database via SQL override

### Target Optimization

- Use bulk loading where available
- Drop indexes before load, rebuild after
- Minimize constraint checking during load
- Use target-side commits with appropriate batch sizes
- Tune commit intervals: too frequent = overhead; too infrequent = lock escalation

### Transformation Optimization

- Cache lookup tables that are frequently accessed
- Index lookup source tables
- Use sorted input for Aggregator transformations
- Minimize use of variable ports in Expressions
- Reduce string manipulation operations

### Partitioning

- Use partitioning for large data volumes to enable parallel processing
- **Hash partitioning**: Even distribution when no natural key exists
- **Key-range partitioning**: When data has natural distribution boundaries
- **Round-robin partitioning**: Simple parallel reads
- Match partition types between transformations to avoid repartitioning overhead

### Serverless Performance

- **Leverage auto-tuning**: CLAIRE ML engine automatically optimizes serverless job configurations.
- **Right-size compute**: Start with defaults and monitor IPU consumption; adjust based on actual workload patterns.
- **Minimize data movement**: Use pushdown optimization to process data in-place.
- **Batch similar workloads**: Group jobs with similar resource profiles for efficient cluster utilization.

## Error Handling

### Error Row Management

- **Configure error logging**: Enable row error logging at session level to capture rejected rows.
- **Error log destinations**: Write error rows to flat files or relational tables for downstream review.
- **Error thresholds**: Set maximum error counts to fail sessions early rather than processing bad data.
- **Error row isolation**: Separate error records from successfully processed records for triage.

### Recovery and Restart

- **Use standard taskflows for recovery**: Standard taskflows support resume-from-failure (linear taskflows require full restart).
- **Enable recovery checkpoints**: Configure checkpoints for long-running sessions.
- **Design idempotent mappings**: Mappings that can safely re-execute without duplicating data. Use UPSERT/MERGE patterns.
- **Implement retry logic**: Use Decision steps in taskflows for retry patterns with configurable attempt counts.

### Logging Best Practices

- **Use INFO level** for routine production monitoring.
- **Use DEBUG level** for troubleshooting and performance analysis (higher overhead).
- **Rotate logs**: Configure log retention to prevent storage issues.
- **Centralize logs**: Forward session logs to enterprise monitoring tools (Splunk, Datadog, Dynatrace).
- **Monitor session statistics**: Track row counts, throughput, and timing across runs to detect degradation trends.

### Taskflow Error Handling

- **Use Throw steps** to catch faults and terminate gracefully.
- **Configure fault suspension** with email notifications for operator alerting.
- **Implement Notification steps** to send proactive status emails with execution metrics.
- **Use Decision steps** for conditional error routing based on error type or severity.
- **Design compensation logic** for multi-step workflows that need rollback capability.

## Deployment

### Environment Management

- **Maintain separate environments**: Development, Test/QA, Staging, Production.
- **Use distinct Secure Agent groups** per environment to isolate workloads.
- **Separate connections per environment** with parameterized connection references.
- **Control promotions**: Use formal promotion workflows from lower to higher environments.
- **Document environment differences**: Track configuration variations between environments.

### CI/CD Approaches

- **Git integration**: Connect IDMC to GitHub, Azure DevOps, BitBucket, or GitLab.
- **Source Control REST APIs**: Automate asset check-in/checkout and deployment.
- **Automated testing**: Validate mappings after promotion using test data sets.
- **Version control all assets**: Mappings, mapplets, taskflows, connections, parameter files.
- **Branch strategy**: Use feature branches for development; merge to main for promotion.
- **Rollback procedures**: Maintain ability to revert to prior versions quickly.

### Migration (PowerCenter to IDMC)

- **Use Informatica Migration Factory**: Automated analysis and conversion of PowerCenter assets.
- **Assess before migrating**: Analyze complexity of mappings, sessions, and workflows.
- **Migrate incrementally**: Start with simple mappings; progress to complex workflows.
- **Validate equivalence**: Compare row counts, data values, and performance between PowerCenter and IDMC.
- **Retire legacy gradually**: Maintain parallel operation until IDMC is fully validated.

## Security

### Secure Agent Configuration

- **Network isolation**: Place Secure Agents in DMZ or private subnets with controlled access.
- **Firewall rules**: Open only required outbound ports to IDMC cloud endpoints (HTTPS 443).
- **Agent updates**: Keep agents current with latest patches and service updates.
- **Service management**: Disable unused services and connectors on each agent.
- **Separate agent groups**: Use dedicated groups for different security zones or compliance requirements.

### Connection Security

- **Use SSL/TLS** for all database and application connections.
- **Credential management**: Store credentials in IDMC vault; never hardcode in mappings.
- **Connection parameterization**: Use environment-specific connection parameters.
- **Least privilege**: Configure database accounts with minimum required permissions.
- **Connection testing**: Validate connectivity before deploying mappings to production.

### Access Control

- **Role-based access**: Define roles aligned to job functions (developer, operator, admin).
- **Principle of least privilege**: Grant minimum permissions required for each role.
- **Sub-organization isolation**: Use IDMC sub-organizations for multi-tenant or multi-team governance.
- **Audit logging**: Enable and review audit trails for access and configuration changes.
- **SSO integration**: Connect IDMC to enterprise identity providers (SAML, OAuth).

## Cost Optimization

### IPU Management

- **Monitor IPU consumption**: Track usage patterns across services and environments.
- **Right-size environments**: Match runtime capacity to actual workload requirements.
- **Consolidate development**: Use shared development environments to reduce IPU consumption.
- **Schedule off-peak**: Run non-critical workloads during off-peak hours.

### Design-Level Optimization

- **Pushdown optimization**: Reduce compute consumption by pushing logic to the database engine.
- **Incremental processing**: Process only changed data to minimize compute and I/O.
- **Efficient transformations**: Avoid unnecessary transformations that increase processing time and IPU consumption.
- **Reuse mapplets**: Shared logic reduces development time and testing effort.
- **Dynamic mapping tasks**: Reduce asset count and management overhead vs creating separate mappings.
- **Archive and cleanup**: Remove unused assets, logs, and temporary data to reduce storage costs.

### Serverless Sizing

- **Start with defaults**: Advanced Serverless auto-scales; begin with default configurations.
- **Monitor and adjust**: Review job execution metrics to identify over-provisioned or under-provisioned patterns.
- **Leverage auto-tuning**: CLAIRE automatically optimizes serverless job configurations over time.
- **Scale to zero**: Serverless environments consume no resources during idle periods.

## Monitoring and Alerting

### Diagnostic Settings

Enable monitoring across all environments:
- **Activity Monitor**: Real-time job tracking, filtering by date/type/status/environment/user
- **Job details**: Drill into execution for row counts, timing, and error details
- **Log access**: Download session logs and error logs directly
- **Retry capability**: Re-execute failed jobs from the Activity Monitor

### Recommended Alerts

| Alert | Condition | Action |
|---|---|---|
| Session failure | Any mapping task fails | Email + incident notification |
| Long-running session | Duration exceeds historical threshold | Investigate performance regression |
| Secure Agent offline | Agent heartbeat lost | Page on-call team |
| High IPU consumption | Daily IPU exceeds budget | Review workload and optimization |

### Operational Cadence

- **Daily**: Review failed jobs in Activity Monitor, triage errors
- **Weekly**: Review execution history for patterns (slow runs, increasing failures, IPU trends)
- **Monthly**: Analyze IPU consumption, review Secure Agent health, audit RBAC
- **Per deployment**: Validate all mappings run successfully in test before promoting to production
