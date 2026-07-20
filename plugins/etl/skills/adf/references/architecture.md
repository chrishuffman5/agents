# ADF Architecture Deep Dive

## Pipeline Execution Model

### Execution Flow

When a pipeline is triggered (manually, by schedule, by event, or by a parent pipeline), ADF orchestrates execution through these steps:

1. **Trigger fires** -- creates a pipeline run with a unique Run ID and passes trigger parameters (window start/end for tumbling window, blob path for storage event)
2. **Activity scheduling** -- ADF evaluates the dependency graph (activity paths: success, failure, completion, skip) and schedules activities in dependency order
3. **IR dispatch** -- each activity is dispatched to its configured Integration Runtime for execution
4. **Activity execution** -- the IR executes the activity against the data source/sink/compute target
5. **Output capture** -- activity output (rows copied, status, errors) is captured and available to downstream activities via `@activity('name').output`
6. **Completion** -- pipeline run completes with status: Succeeded, Failed, or Cancelled

### Activity Dependencies

Activities link through four conditional paths:

- **Upon Success** (default): downstream runs only if upstream succeeds
- **Upon Failure**: downstream runs only if upstream fails (error handling path)
- **Upon Completion**: downstream runs regardless of outcome (cannot coexist with Success/Failure on the same link)
- **Upon Skip**: downstream runs if upstream is skipped (e.g., inside an If Condition where the branch was not taken)

These paths enable try-catch patterns: wrap critical logic in Execute Pipeline, use Upon Failure to log errors and send alerts, use Upon Completion for cleanup.

### Expression Language

ADF expressions use `@` prefix and support a rich function library:

- **System variables**: `@pipeline().RunId`, `@pipeline().TriggerTime`, `@pipeline().GroupId`
- **Pipeline parameters**: `@pipeline().parameters.paramName`
- **Global parameters**: `@pipeline().globalParameters.paramName`
- **Activity output**: `@activity('CopyData').output.rowsCopied`
- **Functions**: `concat()`, `formatDateTime()`, `utcNow()`, `coalesce()`, `if()`, `equals()`, `json()`, `xml()`, `base64()`
- **Dynamic content**: Any property value can be a dynamic expression mixing literals and functions

### Pipeline Parameters and Variables

**Parameters** are immutable inputs set at run time. Types: String, Int, Float, Bool, Array, Object, SecureString. Passed by triggers, parent pipelines, or manual invocation.

**Global parameters** are factory-level constants accessible by all pipelines. Useful for environment-level configuration (environment name, base URLs). Overridden per environment via CI/CD parameter files.

**Variables** are pipeline-scoped mutable storage. Set via Set Variable and Append Variable activities. Types: String, Boolean, Array. Useful in loops for accumulating results.

## Integration Runtime Deep Dive

### Azure IR

**Auto-resolve** (default): ADF selects the Azure region closest to the data source for optimal latency. Suitable for most cloud-to-cloud scenarios where compliance does not require a fixed region.

**Fixed-region**: User specifies the Azure region. Use when data residency or compliance requires execution in a specific geography.

**Managed VNET**: Azure IR runs inside a Microsoft-managed virtual network. All traffic between ADF and data stores flows through managed private endpoints over Azure Private Link. Key characteristics:

- No user-managed VNets, subnets, or NSGs
- Private endpoints require approval from the data store owner
- Supports Azure SQL, ADLS, Blob, Cosmos DB, Synapse, Key Vault, and many more
- **Data exfiltration prevention**: When enabled, outbound traffic is restricted to approved private endpoints only. Prevents unauthorized data copies.
- First execution after a cold start takes longer (private endpoint resolution and Spark cluster provisioning)

**Data Integration Units (DIU)** for Copy Activity: A blended measure of CPU, memory, and network. Range 2-256, default 4. Higher DIU increases parallelism. Auto DIU lets ADF dynamically determine the optimal value. Monitor actual DIU usage in copy activity output to right-size.

**Time-to-Live (TTL)** for Data Flow clusters: Keeps Spark clusters warm between executions. Eliminates 3-5 minute cold start. Set based on scheduling frequency:

| Schedule Frequency | Recommended TTL |
|---|---|
| Every 5-15 minutes | 15-30 minutes |
| Every hour | 10-15 minutes |
| Daily or less | No TTL (accept cold start) |

TTL charges apply for idle cluster time. Balance cost vs latency.

### Self-Hosted Integration Runtime (SHIR)

**Purpose**: Access on-premises data sources, data behind firewalls, or resources in private networks that Azure IR cannot reach.

**Networking**: SHIR communicates outbound to ADF over HTTPS (port 443). Uses Azure Relay (Service Bus) for command channel. Required outbound destinations:
- `*.servicebus.windows.net` (ports 443, 9354)
- `*.frontend.clouddatahub.net` (port 443)
- `download.microsoft.com` (for auto-updates)

No inbound ports are required. This makes SHIR compatible with restrictive firewall environments.

**High availability**: Deploy multiple SHIR nodes in active-active mode. ADF load-balances activities across nodes. Up to 4 nodes per logical IR. All nodes share the same registration key.

**Sharing**: A single SHIR can be shared across multiple data factories. The sharing factory references the SHIR without managing it.

**Capabilities**: Data movement (Copy Activity), dispatch of transformation activities to on-premises compute (Stored Procedure, HDInsight), and SSIS package execution.

**Scaling guidance**:
- Monitor CPU and memory on SHIR nodes via ADF Monitor Hub or Windows Performance Monitor
- If CPU consistently exceeds 80% or concurrent activities queue, add nodes
- Each node handles ~20 concurrent Copy Activity instances by default (configurable)

### Azure-SSIS Integration Runtime

**Purpose**: Lift-and-shift existing SSIS packages to Azure with zero code changes.

**Architecture**: A managed cluster of Azure VMs running the SSIS runtime. Packages execute natively on these VMs.

**SSISDB options**:
- Azure SQL Database: Managed database for SSIS catalog (projects, packages, execution logs)
- Azure SQL Managed Instance: Full SQL Server compatibility, VNet integration
- File system (package store): Alternative to SSISDB for simple package deployment

**Custom setup**: Run a PowerShell script at node provisioning time to install additional drivers (Oracle, SAP), licenses, or components. Setup files stored in Azure Blob with SAS URI.

**Provisioning time**: 20-30 minutes standard, up to 40 minutes with VNet join. Plan for this in operational workflows.

**Cost**: Billed per node based on uptime. Standard tier ~$0.844/hr per node. Enterprise tier higher. Stop the IR when not executing packages to control cost.

## Data Flow Spark Backend

Mapping Data Flows compile the visual transformation graph into Spark code and execute it on managed Spark clusters within ADF.

### Cluster Configuration

- **Compute types**: General Purpose (balanced), Compute Optimized (CPU-heavy transforms), Memory Optimized (large joins, caching)
- **Core count**: Minimum 8 vCores. More cores = more parallelism and available memory.
- **Auto-scaling**: Not supported within a single data flow execution. Cluster size is fixed at the configured core count.

### Spark Execution Details

- ADF generates Scala code from the visual data flow graph
- Spark plan is optimized: predicate pushdown, projection pruning, broadcast join selection
- Partitioning defaults to Round Robin; can be overridden to Hash or specific partition count
- Data is read from source in parallel partitions, transformed through the Spark DAG, and written to sink

### Partition Strategy

| Strategy | When to Use |
|---|---|
| **Default (Round Robin)** | Most scenarios. Let Spark optimizer handle distribution. |
| **Hash** | Before join or group operations on large datasets. Aligns data on the join/group key. |
| **Fixed partition count** | When you know the target parallelism (e.g., match sink partitions). |
| **Source partitioning** | Preserve source physical partitions through the flow. |

Avoid manually overriding partitions unless you have specific knowledge of data distribution. Manual settings can offset optimizer benefits.

### Broadcasting

For joins, lookups, and exists where one side is small enough to fit in worker memory:
- **Auto** (default): Spark decides based on data statistics. Recommended.
- **Fixed (Left/Right)**: Force broadcast of the specified side. Use when one side is consistently small (< 100 MB).
- **Off**: Force shuffle join. Use only for large-to-large joins.

Broadcasting sends the small dataset to all worker nodes, avoiding expensive shuffle operations.

## Connector Ecosystem

ADF provides 90+ built-in connectors with no per-connector licensing:

**Azure services**: SQL Database, ADLS Gen2, Blob Storage, Cosmos DB, Synapse, Databricks, Azure Table, Azure Files, Azure Search

**Databases**: SQL Server, Oracle, MySQL, PostgreSQL, MongoDB, Cassandra, MariaDB, Db2, Informix, Teradata, Netezza, SAP HANA, SAP BW, SAP Table

**Cloud storage**: Amazon S3, Google Cloud Storage, HDFS, FTP, SFTP, HTTP

**Cloud databases**: Amazon Redshift, Google BigQuery, Snowflake

**SaaS**: Salesforce, Dynamics 365, ServiceNow, SAP ECC, SAP Cloud, SharePoint, HubSpot, Marketo, QuickBooks

**File formats**: CSV, JSON, Parquet, Avro, ORC, Delta, Excel, XML, Binary

Connectors follow lifecycle stages: Preview, GA, Deprecated, Retired. Deprecated connectors receive migration guidance.

## Managed Virtual Network Architecture

When Managed VNET is enabled on the Azure IR:

1. ADF creates a managed virtual network in the same region as the IR
2. Managed private endpoints are created for each approved data store
3. All data flow and pipeline activities execute inside this managed network
4. DNS resolution routes traffic to private IP addresses via Private Link
5. No public internet traversal for data movement

**Data exfiltration prevention** restricts outbound traffic exclusively to approved managed private endpoints. When enabled:
- Copy Activity cannot write to unapproved destinations
- Data Flow sinks are restricted to approved endpoints
- Web Activity outbound calls are blocked unless the endpoint has a private endpoint

This addresses enterprise compliance requirements for data sovereignty and preventing unauthorized data transfers.

## Azure Service Integration

### Key Vault

Store all secrets in Azure Key Vault. Linked services reference Key Vault secrets instead of hardcoded credentials. ADF accesses Key Vault via managed identity with no additional credential management.

### Azure Monitor

Diagnostic settings push ADF logs and metrics to Log Analytics:
- Log categories: PipelineRuns, ActivityRuns, TriggerRuns, SandboxPipelineRuns, SandboxActivityRuns
- Metrics: pipeline run counts, activity run counts, trigger run counts, IR node status
- KQL queries power custom dashboards and alerting rules

### Microsoft Purview

ADF automatically pushes data lineage metadata to Purview when pipelines run. Lineage tracks data movement from source through transformations to destination. Captured for Copy Activity, Data Flow, and Execute SSIS Package activities.

### Databricks

Native activities (Notebook, JAR, Python) execute on Databricks clusters. Parameters are passed to Databricks jobs and output is captured. Use Databricks for complex transformations that exceed Data Flow capabilities. Linked service supports Key Vault for token management.
