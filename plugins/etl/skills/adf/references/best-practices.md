# ADF Best Practices

## Pipeline Design Patterns

### Metadata-Driven Pipelines

The most scalable ADF pattern. A single parameterized pipeline handles hundreds of sources:

1. **Control table** (Azure SQL or Azure Table Storage): stores source object name, target path/table, load type (full/incremental), key columns, watermark column, active flag, linked service name
2. **Lookup activity** reads the control table at runtime, filtered by active flag
3. **ForEach activity** iterates over results with configurable parallelism (batch count)
4. **Child pipeline** (Execute Pipeline) performs the actual copy/transform for each source
5. **Parameterized datasets**: table name, folder path, and schema resolved from pipeline parameters
6. **Parameterized linked services**: server name and database resolved from metadata

Adding a new source is a row insert, not a pipeline change. Consistent patterns across all sources simplify auditing, monitoring, and governance.

### Parent-Child Pattern

Separate orchestration from execution:

- **Parent pipeline**: reads metadata, determines scope, fans out to child pipelines via ForEach + Execute Pipeline
- **Child pipeline**: handles one unit of work (copy a table, transform a file, validate a dataset)
- Use `waitOnCompletion: true` for synchronous execution when the parent must know the child outcome
- Use `waitOnCompletion: false` for async fan-out of independent workstreams
- Pass context from parent to child via parameters (source table name, load type, watermark value)

### Dynamic Pipeline Construction

Use expressions to avoid hardcoding:
- Source queries: `@concat('SELECT * FROM ', pipeline().parameters.schemaName, '.', pipeline().parameters.tableName, ' WHERE ModifiedDate > ''', pipeline().parameters.watermark, '''')`
- File paths: `@concat(pipeline().parameters.container, '/', formatDateTime(utcNow(), 'yyyy/MM/dd'), '/')`
- Linked service connections: parameterize server name and database name in the linked service definition

### Incremental Load Patterns

| Pattern | Mechanism | Best For |
|---|---|---|
| **Watermark** | Track last-loaded timestamp/ID in control table; query for newer records | Tables with reliable modified-date or auto-increment columns |
| **Change Tracking** | SQL Server Change Tracking or CDC for precise deltas | SQL Server sources with CT/CDC enabled |
| **Storage Event** | Trigger pipeline on file arrival | File-based ingestion (landing zone pattern) |
| **Tumbling Window** | Window start/end times partition the time range | Time-series data with predictable arrival patterns |

For watermark: after successful copy, update the watermark in the control table using a Stored Procedure activity.

## Copy Activity Optimization

### DIU Tuning

DIU (Data Integration Units) represent CPU + memory + network allocation for Copy Activity:

- Default: 4 DIU. Range: 2-256.
- Increase incrementally and measure: 4 -> 8 -> 16 -> 32 -> 64
- Diminishing returns depend on source/sink throughput limits
- Some sources (small databases, throttled APIs) cannot feed data fast enough for high DIU
- Use Auto DIU to let ADF dynamically allocate; monitor actual usage in copy output
- Review `usedDataIntegrationUnits` in activity output to right-size

### Parallel Copy

`parallelCopies` controls thread count reading from source and writing to sink:
- Default: automatic (ADF determines)
- For partitioned SQL sources: set explicit parallel copy + partition options (physical or dynamic range)
- For file sources: parallel copy processes multiple files concurrently via wildcards
- Too many parallel copies can overwhelm the source. Test incrementally.

### Staging

Enable staging via Azure Blob or ADLS for:
- **PolyBase/COPY into Synapse**: Required for best performance. ADF stages data in blob, then uses PolyBase/COPY to bulk load.
- **Cross-region transfers**: staging in a nearby region reduces latency
- **Format conversion**: stage on-premises data as Parquet in blob before loading to cloud sinks

Use compression (gzip) on staging data for network-bound scenarios.

### Partitioned Reads

For large source tables, configure partitioned reads:
- **Physical partitions**: ADF reads each table partition in parallel
- **Dynamic range**: ADF auto-partitions by a numeric or date column (specify lower/upper bounds and partition count)
- Combine with parallel copy for maximum throughput

### Format Best Practices

- Use Parquet or Delta for cloud-to-cloud transfers (columnar, compressed, Spark-native)
- Avoid ingesting many small files (each file has scheduling overhead). Batch files or use wildcard paths.
- For CSV, specify column delimiters, quote characters, and escape characters explicitly to avoid parsing errors
- Enable binary copy for format-preserving transfers where no transformation is needed

## Data Flow Performance

### Cluster Sizing

| Compute Type | CPU:Memory Ratio | Best For |
|---|---|---|
| **General Purpose** | Balanced | Most workloads, default choice |
| **Compute Optimized** | Higher CPU | Compute-heavy transforms (regex, complex derivations) |
| **Memory Optimized** | Higher memory | Large joins, caching, wide tables |

Minimum 8 vCores. Increase cores for more parallelism and memory. There is no auto-scaling within a single execution.

### TTL Management

TTL keeps Spark clusters warm, eliminating 3-5 minute cold starts:

- Frequent runs (every 5-15 min): TTL 15-30 min
- Hourly runs: TTL 10-15 min
- Daily or less: No TTL (accept cold start; idle cluster cost exceeds startup cost)
- TTL charges per vCore-hour even when idle. Right-size TTL to scheduling frequency.

### Transformation Optimization

- **Push filters early**: Apply Filter transformations as close to the source as possible. Use source query push-down.
- **Project only needed columns**: Remove unnecessary columns with Select after Source to reduce data volume.
- **Use Surrogate Key** instead of Aggregate for generating unique keys (cheaper operation).
- **Use Rank** instead of Window when only rank values are needed.
- **Minimize transformation count**: Combine logic where possible. Each transformation adds a Spark stage boundary.
- **Flowlets** for reuse: Extract common transformation sequences into flowlets instead of duplicating them.
- **Logging**: Set to Basic in production. Verbose logs per-partition details and significantly increases overhead.

### Join and Lookup Optimization

- **Broadcasting**: For small-to-large joins, let Spark auto-broadcast the small side (< 100 MB). Force broadcast only when you know one side is consistently small.
- **Hash partition before join**: For large-to-large joins, hash partition both sides on the join key before the join transformation.
- **Lookup vs Join**: Lookup returns the first match (like left outer join returning one row). Use Lookup when you need reference data enrichment, Join when you need full relational semantics.

## Error Handling

### Retry Policies

- Configure retry count (1-9) and interval (seconds) on individual activities
- Handles transient errors: network timeouts, throttling, temporary unavailability
- Tumbling Window triggers have built-in retry policies (count + interval)
- Schedule triggers do not have built-in retry. Use pipeline-level error handling.

### Fault Tolerance in Copy Activity

- **Skip incompatible rows**: Continue copy when some rows fail type conversion
- **Log skipped rows**: Write failed rows to a designated storage location for review
- **Maximum skip percentage**: Configurable threshold; pipeline fails if exceeded
- **Data consistency verification**: Enable checksum or row count validation between source and sink

### Error Handling Patterns

**Upon Failure paths**: After any activity, add an Upon Failure dependency to:
1. Log error details to a database table or file (using Copy or Stored Procedure activity)
2. Send alert notifications via Web Activity (email/Slack/Teams webhook)
3. Execute cleanup or compensation logic

**Try-Catch with Execute Pipeline**: Wrap critical logic in a child pipeline. The parent checks child pipeline status via Upon Success/Failure paths and branches accordingly.

**Idempotent design**: Activities must be safely re-executable:
- Use UPSERT (merge) instead of INSERT for database sinks
- Use truncate-and-reload for full load activities
- Overwrite files by path convention (date-partitioned paths)
- ADF may re-execute activities on transient failures. Idempotency prevents duplicates.

## CI/CD Workflow

### Git Integration

- Connect only the development factory to Git (Azure Repos or GitHub)
- Use feature branches for isolated development
- Merge to collaboration branch (`main`) via pull request with review
- ADF Studio loads 10x faster with Git (resources loaded from Git, not ADF service)
- Never make manual changes to test or production factories

### Automated Publishing

Replace the manual Publish button with a CI pipeline:

1. Install `@microsoft/azure-data-factory-utilities` NPM package
2. CI pipeline runs on merge to collaboration branch
3. Package validates all ADF resources (catches errors before deployment)
4. Package generates ARM templates (equivalent to `adf_publish` branch content)
5. ARM templates are artifacts for the CD pipeline

### Deployment Workflow

1. **Pre-deployment**: Run PowerShell script to stop all triggers in the target environment
2. **Deploy**: Deploy ARM template with environment-specific parameter file (connection strings, IR names, global parameters)
3. **Post-deployment**: Run PowerShell script to start triggers, delete resources removed in the update
4. Microsoft provides pre/post-deployment scripts in the ADF documentation

### Environment Configuration

- **Parameter files**: One per environment (dev.parameters.json, test.parameters.json, prod.parameters.json)
- **Global parameters**: Override factory-level settings per environment
- **Linked service parameterization**: Connection strings differ by environment but use the same parameterized linked service
- **Integration Runtime references**: Dev uses a shared SHIR; prod uses dedicated SHIR nodes

### Testing Strategy

- **Debug mode**: Interactive testing in development with breakpoints and data preview
- **Validation**: CI pipeline validates ADF resource definitions before ARM template generation
- **Integration tests**: After deployment to test environment, trigger representative pipelines and verify outputs
- **Monitor test runs**: Check success, row counts, and data quality before promoting to production

## Security Best Practices

### Authentication Hierarchy (Prefer Top to Bottom)

1. **Managed Identity** (system-assigned or user-assigned): No credentials to manage, no rotation needed. Supported for most Azure services.
2. **Service Principal with Key Vault**: For services that don't support managed identity. Store client secret in Key Vault.
3. **Key Vault secret reference**: Store connection strings, passwords, SAS tokens in Key Vault. Linked services reference secrets, not hardcoded values.
4. **Hardcoded credentials**: Avoid. Only as last resort for legacy connectors.

### Network Security

- **Managed VNET + private endpoints**: Default for new production factories. Data never traverses public internet.
- **Data exfiltration prevention**: Enable for regulated environments to restrict outbound traffic to approved endpoints.
- **SHIR outbound-only**: No inbound ports. Communicates over HTTPS (443) to ADF service.
- **Customer-managed keys (CMK)**: Encrypt ADF metadata at rest with keys in Azure Key Vault.
- **Azure AD conditional access**: Restrict ADF Studio access by IP, device, or risk level.

### RBAC

- **Data Factory Contributor**: Full access to author and manage ADF resources
- **Data Factory Operator**: Run and monitor pipelines; no authoring permissions
- **Custom roles**: Granular permissions (e.g., allow trigger start/stop but not pipeline editing)
- Separate roles for development, operations, and monitoring teams

## Cost Optimization

### Pricing Model

| Meter | Rate (Approximate) | Optimization Lever |
|---|---|---|
| **Orchestration** | $1.00/1,000 activity runs (cloud), $1.50 (on-prem) | Consolidate activities, metadata-driven patterns |
| **Data Movement** | Based on DIU-hours | Right-size DIU, use Auto |
| **Data Flow** | ~$0.274/vCore-hr (GP, pay-as-you-go) | TTL management, cluster sizing, reserved capacity |
| **Pipeline Activities** | Per activity execution | Minimize unnecessary Lookup/Get Metadata calls |
| **SSIS IR** | ~$0.844/hr per node (Standard) | Stop when not running packages |

### Cost Reduction Strategies

1. **Right-size DIU**: Start with Auto, monitor actual usage, reduce if throughput plateaus at lower DIU
2. **TTL discipline**: Match TTL to actual pipeline frequency. No TTL for daily jobs.
3. **Metadata-driven consolidation**: Fewer pipelines = fewer activity runs = lower orchestration cost
4. **Incremental loads**: Delta processing moves less data than full refreshes (lower DIU-hours)
5. **Event-driven triggers**: Replace frequent polling schedules with storage event triggers
6. **Azure-SSIS IR scheduling**: Start the IR before SSIS execution windows, stop after
7. **Reserved capacity**: 1-year (~25% savings) or 3-year (~35% savings) for steady Data Flow workloads
8. **Azure Cost Management**: Track ADF spending by resource, meter, and tag. Set budget alerts.
9. **Stagger Data Flow schedules**: Align executions to maximize TTL cluster reuse across pipelines

## Monitoring and Alerting

### Diagnostic Settings Configuration

Enable diagnostic settings on every ADF factory:
- **Destination**: Log Analytics workspace (enables KQL queries and dashboards)
- **Log categories**: PipelineRuns, ActivityRuns, TriggerRuns
- **Retention**: 30-90 days based on compliance requirements

### Recommended Alerts

| Alert | Condition | Action |
|---|---|---|
| Pipeline failure | Any pipeline run status = Failed | Email + Teams webhook |
| Long-running pipeline | Pipeline duration exceeds threshold | Investigate for performance regression |
| SHIR offline | IR node status = Offline | Page on-call team |
| High pipeline cost | Daily activity runs exceed budget | Review scheduling and consolidation |

### Operational Cadence

- **Daily**: Review pipeline failures in Monitor Hub, acknowledge and triage
- **Weekly**: Review run history for patterns (slow runs, increasing failures, cost trends)
- **Monthly**: Analyze Azure Cost Management data, review reserved capacity utilization, audit RBAC
- **Per deployment**: Verify all pipelines run successfully in test before promoting to production
