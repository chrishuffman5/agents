# Azure Synapse Pipelines Best Practices

## Pipeline Design

### Modular Pipeline Architecture
- **Use parent-child pipeline patterns**: Break large workflows into modular sub-pipelines using Execute Pipeline activities; this improves readability, testability, and reusability
- **Organize pipelines in folders**: Group pipelines by domain, data source, or business function using the folder structure in Synapse Studio
- **Use annotations**: Tag pipelines with metadata annotations for filtering and organizational clarity in the Monitor hub
- **Parameterize everything**: Use pipeline parameters for connection strings, file paths, table names, date ranges, and environment-specific values to avoid hard-coding
- **Minimize parallel pipeline executions**: Scheduling too many pipelines to run concurrently increases system load and degrades data platform performance; stagger execution windows or use sequential dependencies

### Activity Design
- **Prefer Lookup + ForEach over hardcoded iteration**: Use Lookup activities to retrieve metadata (table lists, file paths) dynamically, then iterate with ForEach
- **Use Set Variable and Append Variable** for accumulating results across loop iterations
- **Implement error handling**: Use If Condition activities to check activity output status; use the Fail activity to surface meaningful error messages
- **Limit ForEach batch count**: The default batch count is 20 (max 50); tune based on the nature of inner activities and downstream system capacity
- **Use Web activities for REST API calls**: Authenticate with managed identity or Key Vault-backed service principals

### Data Movement Patterns
- **ELT over ETL**: Load raw data into ADLS Gen2 or dedicated SQL pool first, then transform in-place using Spark notebooks, stored procedures, or data flows
- **Stage in ADLS Gen2**: Use the data lake as a landing zone for all ingested data before loading into SQL pools
- **Use COPY INTO for dedicated SQL pool loads**: Faster and more efficient than PolyBase for most scenarios; supports Parquet, CSV, and ORC formats
- **Enable parallel copy**: Configure DIU (Data Integration Units) and parallelism settings on Copy Activity for large data volumes
- **Partition source data**: When reading from partitioned sources, leverage partition-aware copy for parallel reads

### Data Flow Best Practices
- **Use TTL on Azure IR**: Set Time-to-Live to keep Spark clusters warm between data flow executions, reducing cold-start latency from minutes to seconds
- **Minimize transformations per data flow**: Break complex logic into multiple data flows or use Flowlets for reusable sub-logic
- **Use the Workspace DB source** when transforming data already in Synapse SQL or Spark databases -- avoids unnecessary linked service overhead
- **Test with Debug mode**: Use data flow debug with small sample datasets to validate transformation logic before running full pipelines
- **Broadcast small datasets in joins**: For small-to-large joins, enable broadcast on the smaller side to avoid shuffle

---

## Spark Pool Sizing

### Node Size Selection
- **Small (4 vCore, 32 GB)**: Development, prototyping, small datasets (<10 GB); lowest cost per hour
- **Medium (8 vCore, 64 GB)**: General-purpose workloads, moderate transformations, recommended starting point for most production pipelines
- **Large (16 vCore, 128 GB)**: Memory-intensive operations (large joins, wide datasets, ML training with medium models)
- **XLarge (32 vCore, 256 GB)**: Heavy ML training, very large shuffle operations
- **XXLarge (64 vCore, 432 GB)**: Extreme memory requirements; rarely needed for typical ETL

### Auto-Scale Configuration
- **Set minimum nodes to 3**: The minimum allowed; keeps a baseline cluster ready
- **Set maximum nodes based on peak workload**: Analyze Spark UI metrics from representative jobs to determine peak executor needs; cap at a reasonable upper bound to control costs
- **Enable dynamic executor allocation**: Allows Spark to scale executors within a job based on stage requirements, which is more granular than node-level autoscale
- **Monitor executor utilization**: If executors are consistently underutilized, reduce max nodes or switch to a smaller node size

### Auto-Pause and TTL
- **Development pools**: Set auto-pause to 15-30 minutes; developers will tolerate the 2-5 minute restart time
- **Scheduled batch pools**: Set auto-pause to 5-10 minutes; jobs complete and the cluster shuts down quickly
- **High-frequency interactive pools**: Use TTL settings on the Azure IR or consider disabling auto-pause if cost-effective for the usage pattern
- **Do not disable auto-pause in development**: Idle clusters burning vCore-hours is the most common source of unexpected Spark costs

### Pool Strategy
- **Create multiple pool definitions**: Pool definitions are free -- create separate pools for dev, test, and prod with different sizing
- **Use the same pool names across environments**: Critical for ARM template-based CI/CD deployment to work correctly
- **Pin Spark versions**: Use a specific Spark runtime version per pool to avoid unexpected behavior from runtime upgrades
- **Manage libraries at pool level for shared dependencies**: Session-level for experimental or ad-hoc packages

---

## SQL Pool Integration

### Dedicated SQL Pool
- **Choose the right distribution strategy**: Hash-distribute large fact tables on the most common join key; replicate small dimension tables; use round-robin for staging tables
- **Use the Distribution Advisor**: Identifies optimal distribution keys based on query patterns and data characteristics
- **Right-size DWUs**: Start with DW100c for development; scale to DW500c-DW1000c for moderate production workloads; scale higher only when query performance demands it
- **Pause when not in use**: Dedicated SQL pools incur charges when online even if no queries are running; automate pause/resume with Azure Automation or Logic Apps
- **Use result set caching**: Enable for repeated dashboard queries to reduce compute costs
- **Monitor with DMVs**: Use sys.dm_pdw_exec_requests, sys.dm_pdw_request_steps, and sys.dm_pdw_sql_requests to identify slow queries and data movement operations
- **Watch TempDB pressure**: Large CTAS operations, data skew, and incompatible joins fill TempDB; 399 GB of TempDB per DW100c is allocated

### Serverless SQL Pool
- **Use external tables and OPENROWSET** for data lake querying
- **Partition data in ADLS Gen2**: Serverless SQL benefits significantly from Hive-style partitioning (year/month/day folder structure) for partition pruning
- **Use Parquet or Delta format**: Columnar formats dramatically reduce scan costs compared to CSV
- **Control costs with query limits**: Set sp_set_query_limits to cap query duration and data processed
- **Create views over external data**: Build a logical data warehouse layer with views for downstream consumers

### Pipeline-to-SQL Integration
- **Use Stored Procedure activity** for complex transformations in dedicated SQL pool -- leverage T-SQL MPP optimizations
- **Use COPY INTO via Spark connector**: When loading from Spark notebooks into dedicated SQL pool, the dedicated SQL pool connector uses COPY INTO under the hood
- **Avoid small frequent loads**: Batch inserts into dedicated SQL pool to minimize transaction overhead and distribution movement

---

## Security

### Network Security
- **Enable Managed Virtual Network at workspace creation**: This decision is permanent and cannot be changed later
- **Enable Data Exfiltration Protection (DEP)** for sensitive workloads: Restricts all egress to approved Microsoft Entra tenants; also permanent once enabled
- **Create Managed Private Endpoints** for all Azure resources the workspace connects to (Azure SQL, Storage, Key Vault, Cosmos DB)
- **Use Private Link for Synapse Studio access**: Configure private endpoints for the Synapse workspace itself for management plane security
- **Restrict public network access**: Disable public network access unless required for specific use cases

### Identity and Access
- **Use Managed Identity for linked services**: Prefer system-assigned or user-assigned managed identity over stored credentials
- **Store secrets in Azure Key Vault**: Never embed passwords, connection strings, or keys directly in linked service definitions
- **Use Synapse RBAC roles**: Assign the least-privilege Synapse role (Artifact User, Compute Operator, etc.) rather than Synapse Administrator for most users
- **Separate dev and prod identities**: Use different managed identities and service principals per environment
- **Enable Microsoft Entra-only authentication** on dedicated SQL pools where possible

### Data Protection
- **Enable Transparent Data Encryption (TDE)** on dedicated SQL pools
- **Use column-level encryption** for sensitive fields
- **Apply Dynamic Data Masking** for non-privileged users
- **Implement row-level security (RLS)** for multi-tenant or role-based data access patterns
- **Audit access**: Enable Azure SQL Auditing on dedicated SQL pools to track data access

---

## Cost Management

### Cost Components
- **Dedicated SQL pools**: DWU-hours (charged even when idle if not paused)
- **Serverless SQL pool**: Per-TB of data processed
- **Spark pools**: vCore-hours (charged only during execution)
- **Data flows**: vCore-hours on Spark clusters
- **Pipeline orchestration**: Activity runs and data movement DIU-hours
- **Integration Runtime**: Self-Hosted IR node hours (Azure IR included in activity costs)
- **Storage**: ADLS Gen2 storage and transactions

### Cost Optimization Strategies
- **Pause dedicated SQL pools** during non-business hours; automate with Azure Automation runbooks or Logic Apps on a schedule
- **Use auto-pause on Spark pools**: Ensure all dev/test pools have auto-pause enabled with short timeouts
- **Right-size DWUs**: Monitor DWU utilization via Azure Portal metrics; if consistently under 50%, scale down
- **Use serverless SQL pool for ad-hoc queries**: Avoid provisioning dedicated SQL pool capacity for occasional queries
- **Set Azure cost budgets and alerts**: Create budgets for the resource group containing Synapse resources; configure alerts at 50%, 75%, 90% thresholds
- **Use reserved capacity**: For predictable production workloads, Azure Reserved Instances for dedicated SQL pool can save up to 65% vs. pay-as-you-go
- **Monitor pipeline activity run costs**: Review the Monitor hub for high-frequency, high-DIU activities that may be optimizable
- **Create small Spark pools for development**: Use Small node pools for dev/test; pool definitions are free -- you only pay for execution
- **Optimize data flow cluster sizing**: Use auto-resolve IR with appropriate core counts; avoid over-provisioning data flow compute

### Cost Monitoring
- **Azure Cost Management**: Tag Synapse resources and use cost analysis by tag/resource group
- **Synapse Monitor hub**: Review pipeline run durations, activity counts, and Spark job durations
- **Azure Advisor**: Review cost recommendations specific to Synapse workloads
- **Log Analytics**: Query pipeline and Spark execution data for cost attribution

---

## CI/CD with Git

### Git Integration Architecture
- **Only the development workspace should be connected to Git** (Azure DevOps or GitHub)
- Test and production workspaces are deployed via CI/CD pipelines -- they do not have direct Git integration
- Git integration stores all pipeline, notebook, data flow, dataset, linked service, and trigger definitions as JSON artifacts in the repository

### Repository Structure
- Synapse artifacts are stored in the **collaboration branch** (typically `main` or `develop`)
- Publishing from Synapse Studio generates ARM templates in the **workspace_publish** branch
- Two files are generated: `TemplateForWorkspace.json` and `TemplateParametersForWorkspace.json`

### CI/CD Pipeline Design

**Key Distinction from ADF**: Synapse artifacts are NOT standard ARM resources. You cannot use the generic ARM template deployment task for Synapse artifacts. You must use the **Synapse workspace deployment task** (`Synapse workspace deployment@2` in Azure DevOps).

**Deployment Flow:**
1. Developer creates/modifies pipelines in the dev workspace connected to Git
2. Changes are committed and merged to the collaboration branch via pull request
3. Developer publishes from Synapse Studio, generating templates in `workspace_publish`
4. CI/CD pipeline picks up templates from `workspace_publish`
5. Synapse workspace deployment task deploys artifacts to test/prod workspaces
6. ARM deployment task deploys ARM resources (pools, workspace config) separately

### CI/CD Best Practices
- **Use separate parameter files per environment**: Maintain dev, test, and prod parameter files with environment-specific linked service connection strings, pool names, and configurations
- **Create identical pool names across environments**: Spark pools and SQL pools should use the same names in dev, test, and prod -- ARM template deployment relies on name matching
- **Avoid exceeding the 20 MB ARM template size limit**: Very large workspaces can hit this limit, causing deployment failures; split into multiple deployments if needed
- **Disable triggers before deployment**: Stop all triggers in the target workspace before deploying, then re-enable after deployment completes
- **Validate deployments**: Run smoke-test pipelines in test environments before promoting to production
- **Use branch policies**: Require pull request reviews, build validation, and linked work items for the collaboration branch
- **Version control parameter files**: Commit TemplateParametersForWorkspace.json overrides into version control for auditability
- **Automate with YAML pipelines**: Define CI/CD pipelines as code (Azure DevOps YAML or GitHub Actions) for repeatability and review

### Limitations
- **No global parameters in Synapse**: Unlike ADF, you cannot define workspace-level global parameters; use pipeline parameters and Key Vault references as workarounds
- **Linked service credential management**: Use Key Vault references in linked services so that connection strings can be environment-specific without modifying the artifact JSON
- **Notebook output cells**: Notebook output cells are not version-controlled; clear outputs before committing to keep diffs clean
