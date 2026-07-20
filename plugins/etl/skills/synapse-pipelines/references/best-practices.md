# Synapse Pipelines Best Practices

## Pipeline Design

### Modular Pipeline Architecture

- **Use parent-child pipeline patterns**: Break large workflows into modular sub-pipelines using Execute Pipeline activities for readability, testability, and reusability.
- **Organize pipelines in folders**: Group by domain, data source, or business function using the folder structure in Synapse Studio.
- **Use annotations**: Tag pipelines with metadata for filtering and organizational clarity in the Monitor hub.
- **Parameterize everything**: Use pipeline parameters for connection strings, file paths, table names, date ranges, and environment-specific values. This is especially important because Synapse does not support global parameters -- all configuration must flow through pipeline parameters and Key Vault references.
- **Minimize parallel pipeline executions**: Too many concurrent pipelines degrade performance and increase contention. Stagger execution windows or use sequential dependencies.

### Activity Design

- **Lookup + ForEach over hardcoded iteration**: Use Lookup activities to retrieve metadata dynamically (table lists, file paths), then iterate with ForEach.
- **Set Variable and Append Variable** for accumulating results across loop iterations.
- **Error handling with If Condition**: Check activity output status. Use the Fail activity to surface meaningful error messages.
- **Limit ForEach batch count**: Default 20, max 50. Tune based on inner activity complexity and downstream system capacity.
- **Web activities for REST API calls**: Authenticate with managed identity or Key Vault-backed service principals.

### Data Movement Patterns

- **ELT over ETL**: Load raw data into ADLS Gen2 or dedicated SQL pool first, then transform in-place using Spark notebooks, stored procedures, or data flows.
- **Stage in ADLS Gen2**: Use the data lake as a landing zone for all ingested data before loading into SQL pools.
- **Use COPY INTO for dedicated SQL pool loads**: Faster and more efficient than PolyBase for most scenarios. Supports Parquet, CSV, and ORC.
- **Enable parallel copy**: Configure DIU and parallelism settings on Copy Activity for large data volumes.
- **Partition source data**: Leverage partition-aware copy for parallel reads from partitioned sources.

### Data Flow Best Practices

- **Enable TTL on Azure IR**: Set Time-to-Live to keep Spark clusters warm between data flow executions, reducing cold-start latency from minutes to seconds.
- **Minimize transformations per data flow**: Break complex logic into multiple data flows or use Flowlets for reusable sub-logic.
- **Use Workspace DB source**: When transforming data already in Synapse SQL or Spark databases, use the workspace database source type to avoid unnecessary linked service overhead.
- **Test with Debug mode**: Validate transformation logic with small sample datasets before running full pipelines.
- **Broadcast small datasets in joins**: Enable broadcast on the smaller side to avoid expensive shuffle operations.

## Spark Pool Sizing

### Node Size Selection

| Node Size | vCores | Memory | Recommended For |
|---|---|---|---|
| Small (4 vCore, 32 GB) | 4 | 32 GB | Development, prototyping, small datasets (<10 GB) |
| Medium (8 vCore, 64 GB) | 8 | 64 GB | General-purpose; recommended starting point for production |
| Large (16 vCore, 128 GB) | 16 | 128 GB | Memory-intensive operations, large joins, ML training |
| XLarge (32 vCore, 256 GB) | 32 | 256 GB | Heavy ML training, very large shuffle operations |
| XXLarge (64 vCore, 432 GB) | 64 | 432 GB | Extreme memory requirements; rarely needed for typical ETL |

### Auto-Scale Configuration

- **Set minimum nodes to 3**: The minimum allowed; keeps a baseline cluster ready
- **Set maximum nodes based on peak workload**: Analyze Spark UI metrics from representative jobs; cap at a reasonable upper bound
- **Enable dynamic executor allocation**: More granular than node-level auto-scale; Spark adjusts executors within a job based on stage requirements
- **Monitor executor utilization**: If consistently underutilized, reduce max nodes or switch to a smaller node size

### Auto-Pause and TTL

- **Development pools**: Auto-pause at 15-30 minutes; developers tolerate 2-5 minute restart time
- **Scheduled batch pools**: Auto-pause at 5-10 minutes; jobs complete, cluster shuts down quickly
- **High-frequency interactive pools**: Use TTL or consider disabling auto-pause if usage pattern justifies it
- **Never disable auto-pause in development**: Idle clusters burning vCore-hours is the most common source of unexpected Spark costs

### Pool Strategy

- **Create multiple pool definitions**: Pool definitions are free -- create separate pools for dev, test, and prod with different sizing
- **Use the same pool names across environments**: Critical for CI/CD deployment; ARM template deployments rely on name matching
- **Pin Spark versions**: Use a specific runtime version per pool to avoid unexpected behavior from upgrades
- **Manage libraries at pool level for shared dependencies**: Use session-level for experimental or ad-hoc packages

## SQL Pool Integration

### Dedicated SQL Pool

- **Choose distribution strategy carefully**: Hash-distribute large fact tables on the most common join key; replicate small dimension tables; round-robin for staging tables
- **Use Distribution Advisor**: Identifies optimal distribution keys based on query patterns and data characteristics
- **Right-size DWUs**: Start with DW100c for dev; DW500c-DW1000c for moderate production; scale higher only when performance demands
- **Pause when not in use**: Dedicated SQL pools charge when online even without queries. Automate pause/resume with Azure Automation or Logic Apps.
- **Enable result set caching**: For repeated dashboard queries to reduce compute costs
- **Monitor with DMVs**: `sys.dm_pdw_exec_requests`, `sys.dm_pdw_request_steps`, `sys.dm_pdw_sql_requests` for query performance investigation
- **Watch TempDB pressure**: Large CTAS operations, data skew, and incompatible joins fill TempDB (399 GB per DW100c)

```sql
-- Check data distribution skew
DBCC PDW_SHOWSPACEUSED('dbo.fact_orders');

-- Identify slow queries
SELECT TOP 20 request_id, status, total_elapsed_time, command
FROM sys.dm_pdw_exec_requests
WHERE status = 'Completed'
ORDER BY total_elapsed_time DESC;
```

### Serverless SQL Pool

- **Use external tables and OPENROWSET** for data lake querying
- **Partition data in ADLS Gen2**: Serverless SQL benefits enormously from Hive-style partitioning for partition pruning
- **Use Parquet or Delta**: Columnar formats dramatically reduce scan costs vs CSV
- **Control costs with query limits**: `sp_set_query_limits` to cap query duration and data processed
- **Create views over external data**: Build a logical data warehouse layer for downstream consumers

### Pipeline-to-SQL Integration

- **Stored Procedure activity**: For complex transformations in dedicated SQL pool leveraging T-SQL MPP optimizations
- **COPY INTO via Spark connector**: Spark-to-dedicated SQL pool uses COPY INTO under the hood
- **Avoid small frequent loads**: Batch inserts to minimize transaction overhead and distribution movement

## Security

### Network Security

- **Enable Managed VNET at workspace creation**: Permanent, irreversible decision. Evaluate requirements carefully before creating the workspace.
- **Enable Data Exfiltration Protection (DEP)** for sensitive workloads: Restricts all egress to approved Microsoft Entra tenants. Also permanent.
- **Create Managed Private Endpoints** for all Azure resources (Azure SQL, Storage, Key Vault, Cosmos DB).
- **Use Private Link for Synapse Studio**: Private endpoints for management plane security.
- **Restrict public network access**: Disable unless required for specific use cases.

### Identity and Access

- **Managed Identity for linked services**: Prefer system-assigned or user-assigned managed identity over stored credentials.
- **Secrets in Azure Key Vault**: Never embed passwords or keys in linked service definitions.
- **Synapse RBAC least privilege**: Assign the minimum required Synapse role (Artifact User, Compute Operator, etc.) rather than Synapse Administrator.
- **Separate dev and prod identities**: Use different managed identities and service principals per environment.
- **Enable Microsoft Entra-only authentication** on dedicated SQL pools where possible.

### Data Protection

- **Transparent Data Encryption (TDE)** on dedicated SQL pools
- **Column-level encryption** for sensitive fields
- **Dynamic Data Masking** for non-privileged users
- **Row-level security (RLS)** for multi-tenant or role-based access patterns
- **Azure SQL Auditing** on dedicated SQL pools

## Cost Management

### Cost Components

| Component | Billing Basis | Optimization Lever |
|---|---|---|
| Dedicated SQL pool | DWU-hours (charged even when idle) | Pause when not in use |
| Serverless SQL pool | Per-TB data processed | Parquet format, partition pruning |
| Spark pools | vCore-hours (execution only) | Auto-pause, right-size nodes |
| Data flows | vCore-hours (Spark clusters) | TTL management, cluster sizing |
| Pipeline orchestration | Activity runs + DIU-hours | Metadata-driven patterns |
| Integration Runtime | SHIR node-hours | (Azure IR included in activity costs) |
| Storage | ADLS Gen2 storage + transactions | Lifecycle policies, compression |

### Cost Optimization Strategies

1. **Pause dedicated SQL pools** during non-business hours. Automate with Azure Automation runbooks.
2. **Auto-pause all dev/test Spark pools** with short timeouts.
3. **Right-size DWUs**: Monitor utilization via Azure Portal; if consistently under 50%, scale down.
4. **Use serverless SQL for ad-hoc queries**: Avoid dedicated pool capacity for occasional queries.
5. **Set Azure cost budgets and alerts**: 50%, 75%, 90% threshold alerts on the Synapse resource group.
6. **Reserved capacity**: For predictable production workloads, reserved instances for dedicated SQL pool save up to 65%.
7. **Monitor pipeline activity costs**: Review Monitor hub for high-frequency, high-DIU activities.
8. **Small Spark pools for development**: Pool definitions are free; pay only for execution.
9. **Optimize data flow cluster sizing**: Auto-resolve IR with appropriate core counts; avoid over-provisioning.

### Cost Monitoring

- **Azure Cost Management**: Tag resources and use cost analysis by tag/resource group
- **Synapse Monitor hub**: Review run durations, activity counts, Spark job durations
- **Azure Advisor**: Review cost recommendations for Synapse workloads
- **Log Analytics**: Query execution data for cost attribution

## CI/CD with Git

### Git Integration Architecture

- **Only the development workspace connects to Git** (Azure DevOps or GitHub)
- Test and production workspaces are deployed via CI/CD pipelines -- no direct Git integration
- Git stores all pipeline, notebook, data flow, dataset, linked service, and trigger definitions as JSON

### Repository Structure

- Artifacts stored in the **collaboration branch** (typically `main` or `develop`)
- Publishing from Synapse Studio generates ARM templates in the **workspace_publish** branch
- Two files generated: `TemplateForWorkspace.json` and `TemplateParametersForWorkspace.json`

### CI/CD Pipeline Design

**Key distinction from ADF**: Synapse artifacts are NOT standard ARM resources. You **cannot** use the generic ARM template deployment task. You must use the **Synapse workspace deployment task** (`Synapse workspace deployment@2` in Azure DevOps).

**Deployment flow**:
1. Developer creates/modifies pipelines in dev workspace connected to Git
2. Changes committed and merged to collaboration branch via pull request
3. Developer publishes from Synapse Studio (generates templates in `workspace_publish`)
4. CI/CD pipeline picks up templates from `workspace_publish`
5. Synapse workspace deployment task deploys artifacts to test/prod
6. ARM deployment task deploys ARM resources (pools, workspace config) separately

### CI/CD Best Practices

- **Separate parameter files per environment**: Maintain dev, test, prod parameter files with environment-specific linked service connection strings, pool names, and configurations.
- **Identical pool names across environments**: Spark and SQL pools must use the same names in dev, test, and prod -- deployment relies on name matching.
- **Avoid exceeding 20 MB template size limit**: Very large workspaces can hit this; split into multiple deployments if needed.
- **Disable triggers before deployment**: Stop all triggers in target workspace before deploying; re-enable after completion.
- **Validate deployments**: Run smoke-test pipelines in test before promoting to production.
- **Branch policies**: Require pull request reviews, build validation, and linked work items.
- **Version control parameter files**: Commit override files for auditability.
- **YAML pipelines**: Define CI/CD as code (Azure DevOps YAML or GitHub Actions).

### Workarounds for Missing Global Parameters

Since Synapse does not support global parameters:

1. **Key Vault references in linked services**: Store environment-specific connection strings in Key Vault; linked services reference Key Vault secrets.
2. **Pipeline parameters**: Pass environment-specific values at the pipeline level.
3. **Lookup activity + configuration table**: Store environment configuration in an Azure SQL or Azure Table Storage table; read at pipeline start.
4. **Parameter override files in CI/CD**: Override linked service parameters per environment during deployment.
