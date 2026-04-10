# Azure Synapse Pipelines Architecture

## Synapse Workspace

Azure Synapse Analytics is a unified analytics platform that brings together data integration, big data analytics, data warehousing, and machine learning under a single workspace. The Synapse workspace is the top-level organizational container that provides a unified management boundary for all analytics artifacts.

### Workspace Components
- **Synapse Studio**: Web-based IDE providing a unified experience for data integration, data exploration, warehousing, big data analytics, and ML -- a single pane of glass for data engineers, scientists, DBAs, and analysts
- **Pipelines (Integrate hub)**: Data integration and orchestration engine (based on ADF codebase)
- **SQL pools (dedicated and serverless)**: Data warehousing and ad-hoc SQL analytics
- **Apache Spark pools**: Big data processing, ML training, and data engineering
- **Data Explorer pools** (retired October 2025): Near-real-time log/telemetry analytics
- **Linked services and connections**: Centralized connection management for all workspace resources
- **Managed VNET and private endpoints**: Network isolation and security boundary

### Workspace Storage
- Every Synapse workspace is associated with an **Azure Data Lake Storage Gen2 (ADLS Gen2)** account as the primary storage
- This is the default "data lake" used by Spark pools, serverless SQL, and pipeline staging
- The workspace filesystem container is used for Spark libraries, notebooks, and pipeline artifacts

---

## Synapse Pipelines vs ADF Pipelines

Synapse Pipelines share the same underlying engine as Azure Data Factory. The core constructs -- pipelines, activities, datasets, linked services, integration runtimes, triggers, and data flows -- are architecturally identical. However, there are important differences in deployment model, feature set, and integration scope.

### Shared Foundation
- Same pipeline execution engine and activity runtime
- Identical activity types: Copy, Data Flow, Lookup, ForEach, If Condition, Execute Pipeline, Web, Stored Procedure, etc.
- Same connector library with 90+ native connectors
- Same data flow (Mapping Data Flow) engine running on Spark clusters
- Same trigger types (schedule, tumbling window, event-based, custom event)

### Key Differences

| Aspect | Azure Data Factory | Synapse Pipelines |
|---|---|---|
| **Deployment model** | Standalone service, independently provisioned | Embedded within Synapse workspace |
| **SQL pool integration** | External linked service only | Native integration with dedicated and serverless SQL pools |
| **Spark integration** | HDInsight or Databricks (external) | Native Spark pool integration, Spark notebook activity |
| **Global parameters** | Supported | **Not supported** -- significant gap for environment-level config |
| **SSIS Integration Runtime** | Fully supported (Azure-SSIS IR) | **Not supported** -- must use standalone ADF for SSIS lift-and-shift |
| **CI/CD maturity** | Well-documented ARM template deployment | Uses Synapse workspace deployment task; artifacts are not ARM resources |
| **Workspace DB source** | Not available | Data flow sources can reference workspace databases directly |
| **Pricing** | Per-pipeline execution, data movement, IR hours | Part of Synapse workspace cost model; pay-per-use for compute |
| **Managed VNET** | Supported | Supported with Data Exfiltration Protection option |
| **Custom activities** | Azure Batch | Azure Batch (same) |

### When Synapse Pipelines Make Sense
- Already operating within a Synapse workspace with dedicated SQL pools or Spark pools
- Want a unified experience for data integration + warehousing + big data in one portal
- Need native Spark notebook orchestration without external Databricks/HDInsight
- Prefer consolidated billing and management under a single workspace

### When Standalone ADF Is Better
- Need SSIS Integration Runtime for legacy SSIS package migration
- Require global parameters for multi-environment configuration
- Operate as a standalone data integration service without Synapse SQL/Spark
- Multi-cloud targets (especially Snowflake) or teams managing many diverse data sources
- More mature CI/CD tooling and broader community documentation

---

## Integration Runtimes

The Integration Runtime (IR) is the compute infrastructure that provides data movement, activity dispatch, and data flow execution capabilities.

### Azure Integration Runtime (Azure IR)
- Fully managed, serverless compute hosted in Azure
- Supports data movement between cloud data stores and data flow transformations
- **Auto-resolve location**: Automatically selects the region closest to the data source for optimal performance
- **Fixed region**: User-specified region for compliance, latency, or data residency requirements
- **Managed VNET IR**: Runs inside a managed virtual network with managed private endpoints for secure, private connectivity
- Scales elastically; charges based on Data Integration Unit (DIU) usage for Copy Activity and vCore-hours for data flows

### Self-Hosted Integration Runtime (SHIR)
- Installed on-premises or on an Azure VM within a private/corporate network
- Required for accessing on-premises data sources, data stores behind firewalls, or VPN-connected resources
- The SHIR communicates with cloud storage over secure HTTPS channels
- Supports high availability with multi-node active-active configuration
- Logically registered to the Synapse workspace but compute is user-managed
- Runs on Windows only

### Azure-SSIS Integration Runtime
- **Not supported in Synapse Pipelines** -- this is a critical distinction from standalone ADF
- If you need to run SSIS packages, you must use a standalone Azure Data Factory instance
- In ADF, the Azure-SSIS IR is a fully managed cluster of Azure VMs dedicated to executing SSIS packages with SSISDB catalog

---

## Apache Spark Pools

Spark pools provide serverless Apache Spark compute within the Synapse workspace for big data processing, data engineering, and machine learning.

### Node Sizes
| Size | vCores | Memory |
|---|---|---|
| Small | 4 | 32 GB |
| Medium | 8 | 64 GB |
| Large | 16 | 128 GB |
| XLarge | 32 | 256 GB |
| XXLarge | 64 | 432 GB |

### Key Configuration
- **Auto-scale**: Dynamically adds or removes nodes (3 to 200 nodes) based on workload demands; Synapse adds nodes when stages need more executors and removes them when executors are idle
- **Auto-pause**: Shuts down idle clusters after a configurable timeout (5 minutes to 7 days) to save costs; cluster restart takes 2-5 minutes
- **Dynamic executor allocation**: Allows executor count to vary within min/max bounds across different stages of a Spark job
- **Time-to-Live (TTL)**: Keeps clusters warm for a configurable period to avoid cold-start latency on subsequent jobs
- **Spark versions**: Workspace supports multiple Spark runtime versions; pools can be pinned to specific versions
- **Library management**: Custom Python (PyPI), Java/Scala (Maven), and .tar.gz packages can be attached at pool or session level

### Spark Pool in Pipelines
- **Spark notebook activity**: Execute Synapse notebooks as pipeline steps with parameterization
- **Spark job definition activity**: Submit batch Spark jobs (PySpark, Scala, .NET Spark)
- Spark pools are billed per vCore-hour; pool definition creation is free (pay only for execution)

---

## SQL Pools

### Dedicated SQL Pool (formerly SQL DW)
- Provisioned MPP (Massively Parallel Processing) data warehouse
- Capacity measured in Data Warehouse Units (DWUs) -- bundled CPU, memory, and IO
- Data distributed across 60 distributions using hash, round-robin, or replicated strategies
- Supports T-SQL with MPP extensions (CTAS, distribution hints, result set caching)
- Can be paused/resumed to control costs
- Pipeline integration: Copy Activity sink, Stored Procedure activity, Lookup activity, dedicated SQL pool connector for Spark

### Serverless SQL Pool
- On-demand, pay-per-query SQL engine (no provisioning)
- Queries data in-place from ADLS Gen2, Cosmos DB (via Synapse Link), and other external sources using OPENROWSET and external tables
- Ideal for ad-hoc exploration, logical data warehouse views, and data lake querying
- Every workspace gets one built-in serverless SQL pool (cannot be deleted)
- Pipeline integration: Stored Procedure activity, SQL script activity

---

## Data Flows (Mapping Data Flows)

Mapping Data Flows provide a visual, code-free data transformation experience that executes on scaled-out Apache Spark clusters managed by Synapse.

### Core Capabilities
- Visual drag-and-drop transformation designer in Synapse Studio
- Executes on Spark under the covers -- no Spark coding required
- Supports 90+ native connectors as sources and sinks
- **Workspace DB source**: Unique to Synapse -- data flow sources can directly reference workspace databases without additional linked services
- Schema drift handling for dynamically changing source schemas
- Debug mode for interactive testing with live data preview

### Transformation Types
- **Schema modifiers**: Derived Column, Select, Aggregate, Surrogate Key, Pivot, Unpivot, Window, Rank, Stringify, Parse
- **Row modifiers**: Filter, Sort, Alter Row, Assert
- **Multiple inputs/outputs**: Join, Conditional Split, Exists, Union, Lookup
- **Flowlets**: Reusable transformation logic (similar to functions/subroutines)
- **External Call**: Invoke external REST endpoints during transformation

### Data Flow in Pipelines
- Executed as a Data Flow activity within a pipeline
- Parameterizable with pipeline expressions for dynamic runtime behavior
- TTL (Time-to-Live) on the Azure IR keeps Spark clusters warm between executions for faster startup

---

## Triggers

Triggers determine when a pipeline execution is initiated. Synapse Pipelines support the same trigger types as ADF.

### Trigger Types

| Type | Behavior | Key Characteristics |
|---|---|---|
| **Schedule** | Fires at wall-clock time intervals (hourly, daily, weekly, etc.) | Fire-and-forget; does not wait for pipeline completion; many-to-many relationship with pipelines |
| **Tumbling Window** | Fires at periodic intervals from a specified start time, retaining state | One-to-one with a single pipeline; supports dependencies on other tumbling window triggers; supports retry and rerun of failed windows; heavier-weight than schedule triggers |
| **Storage Event** | Fires when a blob is created or deleted in Azure Blob Storage | Reacts to file arrival/deletion patterns; filters by folder path and file extension |
| **Custom Event** | Fires on events published to Azure Event Grid topics | Flexible event-driven architecture; filters by event type and subject pattern |
| **Manual / On-demand** | Triggered programmatically via REST API, SDK, or Synapse Studio | Used for ad-hoc runs, testing, and external orchestration |

### Trigger Behavior Notes
- Schedule triggers are "fire and forget" -- the trigger does not track whether the pipeline succeeded
- Tumbling window triggers wait for the pipeline to finish and reflect its status; if the pipeline is cancelled, the trigger window is marked cancelled
- Triggers must be explicitly published and started; they are not active in draft/unpublished state

---

## Linked Services

Linked services define the connection information for external data sources and compute environments, functioning as the "connection strings" of the Synapse workspace.

### Scope
- Linked services in Synapse are **workspace-scoped** -- available to all pipelines, data flows, notebooks, and SQL scripts within the workspace
- Support numerous authentication methods: SQL authentication, managed identity, service principal, Key Vault-referenced secrets, SAS tokens, account keys

### Common Linked Service Types
- **Storage**: Azure Blob Storage, ADLS Gen2, Amazon S3, Google Cloud Storage, SFTP, FTP
- **Databases**: Azure SQL Database, Azure SQL Managed Instance, Azure Cosmos DB, Azure Database for PostgreSQL/MySQL, on-premises SQL Server (via SHIR)
- **Data warehouses**: Azure Synapse dedicated SQL pool, Azure SQL DW, Snowflake, Google BigQuery, Amazon Redshift
- **SaaS / Applications**: Salesforce, Dynamics 365, SAP (HANA, BW, Table), ServiceNow, SharePoint Online
- **Compute**: Azure Databricks, Azure HDInsight, Azure ML, Azure Batch, Azure Functions
- **Messaging / Streaming**: Azure Event Hubs, Azure Service Bus
- **Key Vault**: Azure Key Vault for centralized secret management

### Linked Service vs. Workspace Database
- For data within the Synapse workspace (dedicated SQL pool, serverless SQL pool, Spark databases), data flows can use the **Workspace DB** source type, which bypasses the need for a linked service and directly accesses workspace-internal databases
