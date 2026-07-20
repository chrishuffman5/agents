# Synapse Pipelines Architecture Deep Dive

## Synapse Workspace

Azure Synapse Analytics is a unified analytics platform that brings together data integration, big data analytics, data warehousing, and machine learning under a single workspace. The workspace is the top-level organizational container providing a unified management boundary for all analytics artifacts.

### Workspace Components

- **Synapse Studio**: Web-based IDE providing a unified experience for data integration, exploration, warehousing, big data analytics, and ML
- **Pipelines (Integrate hub)**: Data integration and orchestration engine based on the ADF codebase
- **SQL pools**: Dedicated (provisioned MPP) and serverless (on-demand, pay-per-query) SQL analytics
- **Apache Spark pools**: Big data processing, ML training, and data engineering
- **Data Explorer pools**: Retired October 2025 (near-real-time log/telemetry analytics -- use Fabric Real-Time Intelligence instead)
- **Linked services and connections**: Centralized connection management for all workspace resources
- **Managed VNET and private endpoints**: Network isolation and security boundary

### Workspace Storage

Every Synapse workspace is associated with an **ADLS Gen2** account as the primary storage:

- Default data lake for Spark pools, serverless SQL, and pipeline staging
- Workspace filesystem container stores Spark libraries, notebooks, and pipeline artifacts
- ADLS Gen2 with hierarchical namespace enabled is recommended for performance

## Synapse Pipelines vs ADF Pipelines

### Shared Foundation

Synapse Pipelines share the same underlying engine as Azure Data Factory:

- Same pipeline execution engine and activity runtime
- Identical activity types: Copy, Data Flow, Lookup, ForEach, If Condition, Execute Pipeline, Web, Stored Procedure, etc.
- Same connector library with 90+ native connectors
- Same Mapping Data Flow engine running on managed Spark clusters
- Same trigger types (schedule, tumbling window, storage event, custom event)
- Same Self-Hosted IR architecture

### Key Differences

| Aspect | Azure Data Factory | Synapse Pipelines |
|---|---|---|
| **Deployment model** | Standalone service, independently provisioned | Embedded within Synapse workspace |
| **SQL pool integration** | External linked service only | Native with dedicated and serverless pools |
| **Spark integration** | HDInsight or Databricks (external) | Native Spark pools, notebook activity |
| **Global parameters** | Supported -- environment-level config | **Not supported** -- significant gap for CI/CD |
| **Azure-SSIS IR** | Fully supported | **Not supported** -- must use standalone ADF |
| **CI/CD tooling** | Standard ARM template deployment task | Synapse workspace deployment task; artifacts are not ARM resources |
| **Workspace DB source** | Not available | Data flows reference workspace databases directly |
| **Pricing** | Per-activity + DIU | Part of workspace cost model; per-activity + pool compute |
| **Managed VNET** | Supported with data exfiltration prevention | Supported with Data Exfiltration Protection (both permanent) |

### When Synapse Pipelines Make Sense

- Already operating within a Synapse workspace with dedicated SQL pools or Spark pools
- Want a unified portal for data integration + warehousing + big data
- Need native Spark notebook orchestration without external Databricks/HDInsight
- Prefer consolidated billing and management under a single workspace

### When Standalone ADF Is Better

- Need Azure-SSIS IR for SSIS package migration
- Require global parameters for multi-environment configuration
- Operate standalone data integration without Synapse SQL/Spark
- Need more mature CI/CD tooling and broader community documentation

## Integration Runtimes

### Azure Integration Runtime (Azure IR)

- Fully managed, serverless compute hosted in Azure
- Supports data movement between cloud stores and data flow transformations
- **Auto-resolve location**: Automatically selects the region closest to the data source
- **Fixed region**: User-specified region for compliance or data residency
- **Managed VNET IR**: Runs inside a managed virtual network with managed private endpoints for secure connectivity
- Scales elastically; charges based on DIU usage (Copy Activity) and vCore-hours (Data Flows)

### Self-Hosted Integration Runtime (SHIR)

- Installed on-premises or on an Azure VM within a private/corporate network
- Required for on-premises data sources, firewalls, or VPN-connected resources
- Communicates outbound only over HTTPS (port 443) -- no inbound ports required
- High availability with multi-node active-active configuration
- Logically registered to the workspace; compute is user-managed
- Runs on Windows only

Key outbound destinations:
- `*.servicebus.windows.net` (ports 443, 9354)
- `*.frontend.clouddatahub.net` (port 443)

### Azure-SSIS Integration Runtime

**Not supported in Synapse Pipelines.** If SSIS package execution is required, use a standalone Azure Data Factory instance with Azure-SSIS IR. The SSIS IR can be referenced from Synapse pipelines via cross-factory invocation if necessary.

## Apache Spark Pools

### Node Sizes

| Size | vCores | Memory |
|---|---|---|
| Small | 4 | 32 GB |
| Medium | 8 | 64 GB |
| Large | 16 | 128 GB |
| XLarge | 32 | 256 GB |
| XXLarge | 64 | 432 GB |

### Key Configuration

- **Auto-scale**: Dynamically adds or removes nodes (3 to 200) based on workload demand. Adds nodes when stages need more executors; removes when idle.
- **Auto-pause**: Shuts down idle clusters after configurable timeout (5 min to 7 days). Restart takes 2-5 minutes.
- **Dynamic executor allocation**: Executor count varies within min/max bounds across Spark job stages.
- **TTL (Time-to-Live)**: Keeps clusters warm to avoid cold-start latency on subsequent jobs.
- **Spark version pinning**: Pools can be pinned to specific runtime versions to avoid unexpected behavior.
- **Library management**: Python (PyPI), Java/Scala (Maven), and .tar.gz packages at pool or session level.

### Spark Pool in Pipelines

- **Synapse Notebook activity**: Execute notebooks (PySpark, Scala, SparkSQL, .NET Spark, R) as pipeline steps with parameter passing
- **Spark Job Definition activity**: Submit batch Spark applications
- Output captured from notebooks back into pipeline variables
- Pool definitions are free -- billing is per vCore-hour during execution only

## SQL Pools

### Dedicated SQL Pool (formerly SQL DW)

- Provisioned MPP data warehouse with capacity measured in DWUs
- Data distributed across 60 distributions using hash, round-robin, or replicated strategies
- T-SQL with MPP extensions: CTAS (CREATE TABLE AS SELECT), distribution hints, result set caching
- Can be paused/resumed to control costs (charges when online, even if idle)
- Pipeline integration: Copy Activity sink, Stored Procedure activity, Lookup activity, dedicated SQL pool connector for Spark (uses COPY INTO)

### Serverless SQL Pool

- On-demand, pay-per-query SQL engine (no provisioning)
- Queries data in-place from ADLS Gen2, Cosmos DB (via Synapse Link) using OPENROWSET and external tables
- Every workspace gets one built-in serverless pool (cannot be deleted)
- Ideal for ad-hoc exploration, logical data warehouse views, data lake querying
- Pipeline integration: SQL Script activity, Stored Procedure activity
- Cost: pay per TB of data processed

## Mapping Data Flows

### Core Capabilities

- Visual drag-and-drop transformation designer in Synapse Studio
- Executes on managed Spark clusters under the covers
- 90+ native connectors as sources and sinks
- **Workspace DB source** (unique to Synapse): Reference workspace databases directly without linked services
- Schema drift handling for dynamic schemas
- Debug mode with live data preview

### Transformation Types

- **Schema modifiers**: Derived Column, Select, Aggregate, Surrogate Key, Pivot, Unpivot, Window, Rank, Stringify, Parse
- **Row modifiers**: Filter, Sort, Alter Row, Assert
- **Multiple inputs/outputs**: Join, Conditional Split, Exists, Union, Lookup
- **Flowlets**: Reusable transformation logic
- **External Call**: Invoke REST endpoints during transformation

### Data Flow Performance

- TTL on Azure IR keeps Spark clusters warm between executions
- Broadcast small datasets in joins for performance
- Set logging to Basic in production (Verbose adds overhead)
- Parameterize with pipeline expressions for dynamic behavior

## Triggers

### Trigger Types

| Type | Behavior | Pipeline Relationship | State |
|---|---|---|---|
| **Schedule** | Fires at wall-clock intervals | Many-to-many | Fire-and-forget (no completion tracking) |
| **Tumbling Window** | Fixed intervals from start time | One-to-one | Stateful (retry, dependencies, backfill) |
| **Storage Event** | Blob created/deleted (Event Grid) | Many-to-many | Event-driven |
| **Custom Event** | Event Grid custom topics | Many-to-many | Event-driven |
| **Manual / On-demand** | API/SDK/Studio invocation | -- | Ad-hoc |

**Critical**: Triggers must be **published** and **started** to be active. Unpublished or stopped triggers will not fire. This is the most common cause of "why isn't my pipeline running?"

**Tumbling Window** is the most powerful type: retains state, supports backfill, has built-in retry, and supports trigger-to-trigger dependencies.

## Linked Services

### Scope and Authentication

Linked services are **workspace-scoped** -- available to all pipelines, data flows, notebooks, and SQL scripts. They support:

- SQL authentication, managed identity, service principal
- Key Vault-referenced secrets, SAS tokens, account keys
- Private endpoint connectivity via Managed VNET

### Common Types

- **Storage**: Azure Blob, ADLS Gen2, S3, GCS, SFTP
- **Databases**: Azure SQL, Azure SQL MI, Cosmos DB, PostgreSQL, MySQL, on-prem SQL Server (via SHIR)
- **Data warehouses**: Synapse dedicated SQL pool, Snowflake, BigQuery, Redshift
- **SaaS**: Salesforce, Dynamics 365, SAP, ServiceNow, SharePoint
- **Compute**: Databricks, HDInsight, Azure ML, Azure Batch
- **Key Vault**: Centralized secret management

### Workspace DB vs Linked Service

For data within the Synapse workspace (dedicated SQL pool, serverless SQL pool, Spark databases), data flows can use the **Workspace DB** source type. This bypasses linked service overhead and directly accesses workspace-internal databases.

## Synapse Link

### Synapse Link for Azure Cosmos DB

- Creates a column-oriented analytical store alongside the transactional store
- Queryable via Spark pools and serverless SQL pools
- Supports SQL API and MongoDB API
- Custom partitioning for improved query performance
- **No longer recommended for new projects** -- use Azure Cosmos DB Mirroring for Fabric instead

### Synapse Link for SQL

- Near-real-time replication from Azure SQL Database or SQL Server 2022 to dedicated SQL pool
- Change feed-based incremental sync
- Minimal impact on source OLTP performance
- Known limitations with certain column types and schema changes

### Synapse Link for Dataverse

- Synchronizes Dynamics 365 / Power Apps data into ADLS Gen2 (Delta/CSV)
- Queryable via serverless SQL pools and Spark
- **Transitioning to Fabric Link for Dataverse**

### Common Characteristics

- Zero-ETL: No pipeline authoring required for synchronization
- Near-real-time latency (seconds to minutes)
- No impact on transactional workload performance
- Data lands in analytics-optimized formats

## Security Architecture

### Network Security

- **Managed VNET**: All Synapse compute resources isolated within a managed virtual network. Set at workspace creation (permanent).
- **Data Exfiltration Protection (DEP)**: Restricts outbound to approved Entra tenants only. Set at creation (permanent).
- **Managed Private Endpoints**: Private Link connections from managed VNET to Azure services.
- **Private Link for Synapse Studio**: Private endpoints for the workspace itself (management plane).

### Identity and Access

- **Managed Identity**: System-assigned and user-assigned for linked service authentication
- **Synapse RBAC roles**: Administrator, SQL Administrator, Spark Administrator, Contributor, Artifact Publisher, Artifact User, Compute Operator, Credential User
- **Azure Key Vault**: Centralized secret management for linked service credentials
- **Microsoft Entra authentication**: For dedicated and serverless SQL pools

### Data Protection

- Transparent Data Encryption (TDE) on dedicated SQL pools
- Column-level encryption for sensitive fields
- Dynamic Data Masking for non-privileged users
- Row-level security (RLS) for multi-tenant patterns
- Azure SQL Auditing for access tracking
