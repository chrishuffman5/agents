# Azure Data Factory Best Practices

## Pipeline Design Patterns

### Metadata-Driven Pipelines
- Store source/target configuration in a control table (Azure SQL, Azure Table Storage, or JSON)
- Use Lookup activity to read configuration, ForEach to iterate
- Parameterize datasets and linked services for dynamic resolution
- Adding a new source becomes a configuration change, not a pipeline change
- Keep configuration-as-code in a Git repository for version control

### Parent-Child Pattern
- Parent pipeline handles orchestration: reads metadata, fans out to child pipelines
- Child pipeline handles the actual work: copy, transform, validate
- Benefits: reusability, isolation of concerns, cleaner monitoring
- Use Execute Pipeline activity with `waitOnCompletion: true` for synchronous execution
- Pass parameters from parent to child for context (source table, load type, watermark)

### Dynamic Pipelines
- Use expressions and parameters to dynamically construct:
  - Source queries: `@concat('SELECT * FROM ', pipeline().parameters.tableName)`
  - File paths: `@concat(pipeline().parameters.container, '/', formatDateTime(utcnow(), 'yyyy/MM/dd'))`
  - Linked service connections: parameterized server names, database names
- Avoid hard-coding values; externalize all configuration
- Group tables/files by common patterns and process them in a single parameterized pipeline

### Incremental Load Patterns
- **Watermark pattern**: Track last-loaded timestamp or ID in a control table; query source for records newer than watermark
- **Change Tracking**: Use SQL Server Change Tracking or Change Data Capture for precise delta detection
- **File-based**: Use storage event triggers to process only newly arrived files
- **Tumbling Window**: Use window start/end times for time-partitioned incremental processing

---

## Copy Activity Optimization

### Data Integration Units (DIU)
- DIU represents a combination of CPU, memory, and network allocation
- Default is 4 DIU; range is 2-256
- Higher DIU increases parallelism for large data volumes
- Auto DIU lets ADF dynamically allocate based on source/sink characteristics
- Monitor actual DIU usage in copy activity output to right-size

### Parallel Copy
- `parallelCopies` setting controls the number of threads reading from source and writing to sink
- Default is automatic (ADF determines optimal value)
- For partitioned sources, increase parallel copy to exploit partition-level parallelism
- Too many parallel copies can overwhelm the source -- test and tune gradually

### Staging
- Enable staging via Azure Blob Storage or ADLS for:
  - PolyBase/COPY command loading into Synapse (required for best performance)
  - Cross-region data movement
  - Format conversion (e.g., on-premises to Parquet via staging)
- Staging adds a hop but often dramatically improves throughput for supported sinks
- Use compression (gzip) on staging for network-bound scenarios

### Partitioning
- Physical partitioning: leverage source table partitions for parallel reads
- Dynamic range partitioning: ADF auto-partitions by a numeric or date column
- Partition settings significantly improve throughput for large tables
- Combine with parallel copy for maximum parallelism

### General Copy Performance
- Test with representative data samples (at least 10 minutes of copy duration)
- Use Parquet or Delta format for cloud-to-cloud transfers (columnar, compressed)
- Avoid small file ingestion (many small files create overhead) -- batch files or use wildcards
- Monitor throughput in copy activity details: rows/sec, MB/sec, duration per stage

---

## Data Flow Performance

### Spark Cluster Sizing
- Minimum cluster size is 8 vCores (for general purpose compute)
- Choose compute type based on workload:
  - **General Purpose**: Balanced CPU/memory, suitable for most workloads
  - **Compute Optimized**: Higher CPU ratio, good for compute-heavy transformations
  - **Memory Optimized**: Higher memory ratio, good for caching and large joins
- Core count directly affects parallelism and memory available for transformations

### Time-to-Live (TTL)
- TTL keeps Spark clusters warm between data flow executions
- Eliminates cold start delay (3-5 minutes) for subsequent runs
- Set TTL based on pipeline scheduling frequency:
  - Frequent runs (every 5-15 min): TTL of 15-30 min
  - Hourly runs: TTL of 10-15 min
  - Infrequent runs: No TTL (pay for startup each time)
- TTL charges apply for idle cluster time -- balance cost vs. latency

### Partition Settings
- Default: Let the Spark optimizer handle partitioning (recommended in most cases)
- Manual partitioning overrides can offset optimizer benefits
- Only manually set partitions when you have specific knowledge of data distribution
- Round Robin for even distribution; Hash for join/group key alignment

### Broadcasting
- For joins, lookups, and exists where one side is small (fits in worker memory)
- Broadcasting sends the small dataset to all nodes, avoiding expensive shuffle
- Options: Auto (Spark decides), Fixed (force broadcast left/right), Off
- Auto broadcasting is recommended; force broadcast only when you know one side is small

### Caching
- Cache sink writes data flow output to a temporary in-memory cache
- Useful for lookup-style operations within the same data flow
- Reduces repeated reads from external sources
- Memory-bound: ensure cluster has sufficient memory

### General Data Flow Optimization
- Use Parquet or Delta as source/sink format (Spark-native, best performance)
- Reduce logging level from Verbose to Basic in production (Verbose logs per-partition details)
- Minimize the number of transformations in a single data flow where possible
- Use Flowlets for reusable components instead of duplicating logic
- Data flow debug mode allows iterative tuning with live data preview

---

## Error Handling

### Retry Policies
- Configure retry count (1-9) and interval (seconds) on individual activities
- Handles transient errors: network timeouts, throttling, temporary resource unavailability
- Tumbling Window triggers have built-in retry policies (count + interval)
- Scheduled triggers do not have built-in retry -- use pipeline-level error handling

### Fault Tolerance (Copy Activity)
- Skip incompatible rows: continue copy even when some rows fail type conversion
- Log skipped rows to a designated storage location for review
- Configure maximum allowed percentage of skipped rows
- Data consistency verification: enable checksum or row count validation

### Upon Failure Paths
- ADF supports four conditional dependency paths between activities:
  - **Upon Success**: Execute if the upstream activity succeeds (default)
  - **Upon Failure**: Execute if the upstream activity fails
  - **Upon Completion**: Execute regardless of success or failure (cannot coexist with Success/Failure)
  - **Upon Skip**: Execute if the upstream activity is skipped
- Use Upon Failure paths to:
  - Log error details to a database or file
  - Send alert notifications (Web activity to email/Slack/Teams webhook)
  - Execute cleanup or compensation logic

### Try-Catch Patterns
- Wrap critical activities in an Execute Pipeline activity
- The parent pipeline can check the child pipeline status and branch accordingly
- Use Set Variable to capture error messages from activity outputs
- Combine with Web Activity to send alerts on failure

### Idempotent Design
- Design activities to be safely re-executable without side effects
- Use UPSERT (merge) instead of INSERT to handle duplicate processing
- Use truncate-and-reload for full load activities
- ADF may re-execute activities on transient failures -- idempotency is critical

---

## CI/CD Best Practices

### Git Integration
- Connect only the development ADF instance to Git (Azure Repos or GitHub)
- Use feature branches for development; merge to collaboration branch (typically `main`)
- Never make manual changes to test or production ADF instances
- ADF Studio loads 10x faster with Git integration

### Branch Strategy
- **Collaboration branch** (`main`): Stable code ready for deployment
- **Feature branches**: Developer workspaces for isolated changes
- **Publish branch** (`adf_publish`): Auto-generated ARM templates after publish (manual flow)
- For automated publishing, skip the publish button entirely -- use CI pipeline

### ARM Template Deployment
- Generate ARM templates via the `@microsoft/azure-data-factory-utilities` NPM package in CI
- Validate ADF resources before generating templates (catches errors early)
- Use parameter files for environment-specific values (connection strings, IRs, global parameters)
- Deploy using Azure DevOps release pipelines or GitHub Actions

### Deployment Workflow
1. **Pre-deployment**: Stop triggers in the target environment
2. **Deploy**: Deploy ARM template with environment-specific parameters
3. **Post-deployment**: Start triggers, clean up removed resources
4. Microsoft provides pre/post-deployment PowerShell scripts for trigger management

### Testing Strategy
- Validate ARM templates in CI pipeline before deployment
- Use debug mode in development for interactive pipeline testing
- Implement integration tests in test environment after deployment
- Monitor test pipeline runs for success before promoting to production

---

## Security Best Practices

### Managed Identity
- Use system-assigned or user-assigned managed identity for authentication wherever possible
- Eliminates credential management: no passwords, keys, or connection strings to rotate
- Supported for: Azure SQL, ADLS, Blob Storage, Key Vault, Synapse, Cosmos DB, Databricks
- Grant least-privilege RBAC roles to the managed identity

### Key Vault Integration
- Store all secrets (connection strings, passwords, SAS tokens) in Azure Key Vault
- Linked services reference Key Vault secrets, not hardcoded values
- ADF accesses Key Vault via managed identity (no additional credentials needed)
- Centralized secret management with audit logging and access policies

### Private Endpoints
- Use Managed VNET with managed private endpoints for secure data access
- Data never traverses the public internet
- Enable data exfiltration prevention to restrict outbound traffic to approved endpoints only
- Combine with Azure Private Link for end-to-end private connectivity

### Network Security
- Self-hosted IR communicates outbound only (HTTPS/443) -- no inbound ports
- Use network isolation for sensitive data flows
- Restrict ADF Studio access via Azure AD conditional access policies
- Enable customer-managed keys (CMK) for encryption at rest

### RBAC
- Use Azure RBAC for fine-grained access control to ADF resources
- Built-in roles: Data Factory Contributor, Data Factory Operator (monitoring only)
- Custom roles for granular permissions (e.g., allow pipeline execution but not authoring)
- Separate roles for development, operations, and monitoring teams

---

## Cost Optimization

### IR Sizing
- Right-size DIU for Copy Activity: start with Auto and monitor actual usage
- Avoid over-provisioning Self-hosted IR nodes -- scale based on actual concurrency
- Use reserved capacity (1-year or 3-year) for predictable, steady workloads
- Reserved capacity applies to Azure IR and Data Flow compute

### Pipeline Scheduling
- Minimize unnecessary pipeline runs: consolidate schedules where possible
- Use event-based triggers instead of frequent polling schedules
- Tumbling window triggers avoid duplicate processing (built-in state management)
- Pipeline runs are billed per 1,000 activity runs -- consolidate activities where practical

### Data Flow Cluster TTL
- Set TTL based on actual pipeline frequency to avoid paying for idle clusters
- Short TTL (5-10 min) for hourly or less frequent pipelines
- Longer TTL (15-30 min) only when pipelines run frequently (every 5-15 min)
- No TTL for daily or weekly pipelines -- accept the cold start cost

### Pricing Model Awareness
- **Orchestration**: $1.00 per 1,000 activity runs (cloud), $1.50 per 1,000 (on-premises via SHIR)
- **Data movement**: Based on DIU-hours consumed by Copy Activity
- **Data flow**: Based on vCore-hours (General Purpose: ~$0.274/vCore-hr pay-as-you-go)
- **Pipeline activities**: Each activity execution counts as a run
- **SSIS**: Based on Azure-SSIS IR node count and uptime (Standard ~$0.844/hr per node)

### Cost Monitoring
- Use Azure Cost Management to track ADF spending by resource, meter, and tag
- Monitor pipeline consumption patterns in ADF Monitor Hub
- Set up budget alerts for unexpected cost spikes
- Review Data Flow cluster utilization -- low utilization may indicate over-provisioned clusters

---

## Monitoring and Alerting

### Diagnostic Settings
- Enable diagnostic settings to send ADF logs to Log Analytics workspace
- Log categories: PipelineRuns, ActivityRuns, TriggerRuns, SandboxPipelineRuns, SandboxActivityRuns
- Retain logs based on compliance requirements (30, 60, 90 days)

### Azure Monitor Alerts
- **Pipeline failure alerts**: Alert when any pipeline run fails
- **Long-running pipeline alerts**: Alert when pipeline exceeds expected duration
- **IR health alerts**: Alert when Self-hosted IR nodes go offline
- **Custom metric alerts**: Build KQL queries for complex alerting scenarios

### Dashboards
- Azure Monitor Workbooks for visual dashboards
- Pin KQL query results to Azure dashboards
- Track key metrics: success rates, average duration, data volume trends, cost trends
- Share dashboards with operations and management teams

### Operational Best Practices
- Review pipeline run history weekly for patterns (slow runs, frequent failures)
- Set up automated reports for pipeline SLA compliance
- Use annotations and tags to organize pipelines by business domain or team
- Document runbooks for common failure scenarios and remediation steps

---

## Sources

- [Copy Activity Performance Guide - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/copy-activity-performance)
- [Data Flow Performance Tuning - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/concepts-data-flow-performance)
- [Optimizing Data Flow Transformations - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/concepts-data-flow-performance-transformations)
- [CI/CD in ADF - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/continuous-integration-delivery)
- [Automated Publishing - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/continuous-integration-delivery-improvements)
- [Pipeline Failure and Error Handling - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/tutorial-pipeline-failure-error-handling)
- [Plan and Manage Costs - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/plan-manage-costs)
- [ADF Pricing Examples - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/pricing-concepts)
- [ADF Pricing - Microsoft Azure](https://azure.microsoft.com/en-us/pricing/details/data-factory/data-pipeline/)
- [Managed Identity - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/data-factory-service-identity)
- [ADF Best Practices - Amit Damle, Medium](https://damle-amit075.medium.com/azure-data-factory-best-practices-f5c368d2e45d)
- [Reliability in ADF - Microsoft Learn](https://learn.microsoft.com/en-us/azure/reliability/reliability-data-factory)
