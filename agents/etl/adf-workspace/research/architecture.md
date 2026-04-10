# Azure Data Factory Architecture

## Core Concepts

Azure Data Factory (ADF) is a fully managed, serverless cloud-based data integration service for building ETL and ELT pipelines. It uses a visual, low-code/no-code authoring experience and orchestrates data movement and transformation at scale.

### Pipelines
- The top-level container in ADF -- a logical grouping of **activities** that together perform a data integration task
- Pipelines define a sequence of steps: ingesting raw data, transforming it, and storing results
- Pipelines can be parameterized with pipeline parameters and receive input from triggers
- Pipelines can invoke other pipelines (parent-child pattern) via the Execute Pipeline activity
- Each pipeline execution is called a **pipeline run** and gets a unique Run ID

### Activities
- The individual processing steps within a pipeline
- Three categories:
  - **Data Movement**: Copy Activity (the primary data movement mechanism)
  - **Data Transformation**: Data Flow, HDInsight (Hive, Pig, Spark), Databricks Notebook/JAR/Python, Stored Procedure, Azure ML, Custom (.NET)
  - **Control Flow**: If Condition, ForEach, Until, Switch, Wait, Web, Lookup, Get Metadata, Set Variable, Append Variable, Filter, Execute Pipeline, Validation, Webhook, Fail

### Datasets
- Named views of data that describe the schema/structure of data used by activities
- Point to data within a linked service (e.g., a specific table in SQL Database, a folder in Blob Storage)
- Defined by type, linked service, schema, folder path, and format properties
- Can be parameterized for dynamic data access patterns

### Linked Services
- Connection definitions that specify how ADF connects to external data sources and compute environments
- Act as the "connection string" equivalent -- define the target endpoint, authentication method, and connection properties
- Support many authentication types: SQL auth, managed identity, service principal, Key Vault references, SAS tokens
- Examples: Azure SQL Database, Azure Blob Storage, Azure Data Lake Storage, on-premises SQL Server, Salesforce, SAP

### Data Flows
- Visually designed data transformations executed on scaled-out Apache Spark clusters
- Two types (historical -- wrangling deprecated):
  - **Mapping Data Flows**: Spark-based visual ETL with a rich set of transformations (join, aggregate, pivot, unpivot, window, conditional split, derived column, exists, lookup, rank, surrogate key, union, alter row, assert, flowlet, stringify, parse, external call)
  - **Wrangling Data Flows**: Power Query Online-based (deprecated in 2024, use Mapping Data Flows or Fabric)
- Data Flow debug mode allows interactive testing with live data preview using a warm Spark cluster
- Support schema drift for handling dynamically changing schemas

---

## Integration Runtime (IR)

The Integration Runtime is the compute infrastructure used by ADF to provide data integration capabilities. It bridges ADF to the data source/destination.

### Azure Integration Runtime (Azure IR)
- Fully managed, serverless compute in Azure
- Supports data movement between cloud data stores and data flow transformations
- **Auto-resolve**: Default IR that auto-selects the Azure region closest to the data source
- **Fixed-region**: User-specified region for compliance or latency requirements
- **Managed VNET**: Runs inside a managed virtual network with private endpoints for secure connectivity to private data stores
- Scales automatically; charges based on DIU (Data Integration Units) usage
- Time-to-Live (TTL) setting keeps Spark clusters warm for faster subsequent Data Flow executions

### Self-Hosted Integration Runtime (SHIR)
- Installed on an on-premises machine or Azure VM within a private network
- Required for accessing on-premises data sources or data stores behind firewalls
- Supported only on Windows operating system
- Supports high availability via active-active mode with multiple nodes
- Handles data movement, dispatch of transformation activities to on-premises compute, and SSIS package execution
- Communicates outbound to ADF service over HTTPS (ports 443) -- no inbound ports required
- Can be shared across multiple data factories

### Azure-SSIS Integration Runtime
- Fully managed cluster of Azure VMs dedicated to running SSIS packages natively in the cloud
- Lift-and-shift existing SSIS workloads without code changes
- Supports SSISDB hosted on Azure SQL Database or Azure SQL Managed Instance
- Can join a VNet for accessing on-premises data
- Supports custom setup scripts for installing additional components (drivers, licenses)
- Charged per node (Standard or Enterprise tier) based on uptime

---

## Pipeline Activities Detail

### Data Movement
- **Copy Activity**: The primary mechanism for moving data between 90+ supported data stores
  - Supports file format conversion (CSV, JSON, Parquet, Avro, ORC, Delta, Excel, XML, binary)
  - Configurable parallelism via Data Integration Units (DIU: 2-256, default 4)
  - Staging via Azure Blob or ADLS for cross-region or hybrid scenarios
  - Fault tolerance: skip incompatible rows, log skipped rows
  - Column mapping, schema mapping, type conversion
  - Incremental copy via watermark or change tracking

### Data Transformation
- **Data Flow Activity**: Executes mapping data flows on managed Spark clusters
- **HDInsight Activities**: Hive, Pig, MapReduce, Spark, Streaming on HDInsight clusters
- **Databricks Activities**: Notebook, JAR, Python script execution on Databricks clusters
- **Stored Procedure Activity**: Execute stored procedures on Azure SQL, SQL Server, Synapse
- **Azure ML Activities**: Batch execution and update resource for ML models
- **Custom Activity**: Run custom .NET code on Azure Batch pools

### Control Flow
- **If Condition**: Boolean branching (if-true and if-false activity chains)
- **ForEach**: Iterate over a collection, executing activities for each item (sequential or parallel, max parallelism configurable)
- **Until**: Loop until a condition evaluates to true (with timeout)
- **Switch**: Multi-branch conditional based on expression evaluation
- **Wait**: Pause pipeline execution for a specified duration
- **Web Activity**: Call REST endpoints, pass headers/body, capture response
- **Lookup**: Query a data store and return results for use in downstream activities
- **Get Metadata**: Retrieve metadata (file list, schema, row count) from data stores
- **Set Variable / Append Variable**: Manage pipeline-scoped variables
- **Filter**: Filter arrays based on conditions
- **Execute Pipeline**: Invoke child pipelines (sync or async)
- **Validation**: Validate file existence or size before proceeding
- **Webhook**: Call a webhook and wait for callback
- **Fail**: Intentionally fail a pipeline with a custom error message and code

---

## Triggers

Triggers determine when a pipeline execution is kicked off.

### Schedule Trigger
- Runs pipelines on a wall-clock schedule (cron-like)
- Supports recurrence: minute, hour, day, week, month
- Many-to-many relationship with pipelines (one trigger can start multiple pipelines)
- Does not have built-in retry for failed pipeline runs

### Tumbling Window Trigger
- Fires at periodic, fixed-size, non-overlapping time intervals
- Retains state and supports backfill for historical periods
- Built-in retry policies (retry count and interval)
- Supports trigger dependencies (chain tumbling window triggers together)
- One-to-one relationship with a single pipeline
- Passes window start/end times to the pipeline for time-slice processing

### Storage Event Trigger
- Fires when files are created or deleted in Azure Blob Storage or ADLS Gen2
- Can filter on blob path prefix and suffix patterns
- Uses Azure Event Grid subscription under the hood
- Commonly used for event-driven data ingestion (file arrival patterns)

### Custom Event Trigger
- Fires in response to custom events published to Azure Event Grid topics
- Supports filtering on event type and subject patterns
- Enables integration with external systems and microservices

---

## Monitoring

### Pipeline Run Monitoring
- **Monitor Hub** in ADF Studio: central view of all pipeline runs, activity runs, trigger runs
- Each activity run shows: status, duration, input/output, error details, resource consumption
- Filter and search by pipeline name, status, time range
- Rerun failed pipelines from the point of failure or from the beginning

### Azure Monitor Integration
- Diagnostic settings to send logs to Log Analytics, Storage Account, or Event Hub
- Metrics: pipeline runs succeeded/failed, activity runs, trigger runs, IR node status
- Log Analytics queries (KQL) for custom dashboards and alerting
- Alerts: configure alert rules on pipeline failure, long-running pipelines, IR issues

### Activity-Level Monitoring
- Copy Activity provides detailed statistics: rows read/written, data volume, throughput, DIU usage, duration per stage
- Data Flow monitoring shows Spark execution details, partition counts, stage times, cluster utilization

---

## Source Control and CI/CD

### Git Integration
- Native integration with Azure Repos Git and GitHub
- Each developer works on feature branches; merges to a collaboration branch (typically `main`)
- Only the development ADF instance connects to Git; test/production use CI/CD deployment
- ADF Studio loads 10x faster with Git integration (resources loaded from Git, not service)
- Live mode vs Git mode: Git mode allows saving without validation, collaboration branching

### CI/CD with ARM Templates
- On merge to the collaboration branch, ADF publishes ARM templates to an `adf_publish` branch
- ARM templates contain the full ADF resource definitions (pipelines, datasets, linked services, triggers, IRs)
- Azure DevOps release pipelines deploy ARM templates across environments (dev -> test -> prod)
- Pre/post-deployment scripts handle trigger stop/start and environment-specific parameters

### Automated Publishing
- Microsoft provides the `@microsoft/azure-data-factory-utilities` NPM package
- Validates ADF resources and generates ARM templates in a CI pipeline (no manual Publish button)
- Can be triggered on PR merge to the collaboration branch
- Enables fully automated validation, build, and release pipelines

### Bicep Deployment
- ADF infrastructure (factory, IRs, managed VNET) can be defined in Bicep
- Bicep templates integrate with Azure DevOps or GitHub Actions for IaC deployment
- Separate infrastructure deployment from ADF artifact (pipeline) deployment

---

## Managed Virtual Network

### Architecture
- ADF Managed VNET provides a fully managed, isolated network for Azure IR
- All data flow and pipeline activities run inside this managed network
- No need to manage VNets, subnets, or NSGs -- Microsoft manages the network infrastructure

### Private Endpoints
- Managed Private Endpoints connect to data stores via Azure Private Link
- Traffic never leaves the Microsoft backbone network
- Supports Azure SQL, ADLS, Blob Storage, Cosmos DB, Synapse, Key Vault, and many more
- Requires approval from the data store owner

### Data Exfiltration Prevention
- When enabled, outbound traffic is restricted to approved private endpoints only
- Prevents data from being copied to unauthorized destinations
- Addresses enterprise compliance and data governance requirements

---

## ADF vs Synapse Pipelines vs Fabric Data Factory

### ADF vs Synapse Pipelines
- Synapse Pipelines use the **same engine** as ADF -- nearly identical UI, activities, and capabilities
- Synapse Pipelines are embedded within Azure Synapse Analytics workspace
- Key differences:
  - Synapse Pipelines integrate tightly with Synapse SQL pools, Spark pools, and dedicated resources
  - ADF is a standalone service with broader connector support and longer feature history
  - Some connectors and features are available in ADF first before Synapse
  - Synapse has native integration with Synapse Link for near-real-time analytics

### ADF vs Fabric Data Factory
- Fabric Data Factory is Microsoft's **next-generation** data integration platform
- Retains ADF's core pipeline engine with major improvements:
  - Native OneLake integration (unified data lake)
  - Copilot AI assistance for pipeline authoring
  - Expanded activity types (Notebook, Lakehouse, KQL, Dataflow Gen2)
  - Simplified licensing (Fabric capacity-based, not per-activity billing)
  - Tighter integration with Power BI, Real-Time Analytics, Data Warehouse
- **Migration**: Public preview of ADF/Synapse to Fabric migration assistant launched March 2026
- **Development focus**: Since mid-2024, new features (mirroring, copy jobs) ship exclusively in Fabric
- **Guidance**: ADF remains fully supported and stable; Fabric is the strategic direction for new projects

### When to Use Which
- **ADF**: Existing investments, standalone ETL needs, on-premises heavy, SSIS lift-and-shift, mature CI/CD requirements
- **Synapse Pipelines**: Already using Synapse Analytics, need tight SQL/Spark pool integration
- **Fabric Data Factory**: Greenfield projects, unified analytics platform, Power BI-centric organizations, organizations adopting Microsoft Fabric

---

## Sources

- [Introduction to Azure Data Factory - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/introduction)
- [Pipelines and Activities - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/concepts-pipelines-activities)
- [Integration Runtime - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/concepts-integration-runtime)
- [Choose the Right IR Configuration - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/choose-the-right-integration-runtime-configuration)
- [Mapping Data Flows - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/concepts-data-flow-overview)
- [Pipeline Execution and Triggers - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/concepts-pipeline-execution-triggers)
- [Differences between Fabric and ADF - Microsoft Learn](https://learn.microsoft.com/en-us/fabric/data-factory/compare-fabric-data-factory-and-azure-data-factory)
- [Migrating ADF/Synapse to Fabric - Microsoft TechCommunity](https://techcommunity.microsoft.com/blog/microsoftmissioncriticalblog/migrating-azure-data-factory-and-synapse-pipelines-to-fabric-data-factory/4510051)
- [From Synapse and ADF to Fabric - Fabric Blog](https://blog.fabric.microsoft.com/en-US/blog/from-azure-synapse-and-azure-data-factory-to-microsoft-fabric-the-next-gen-analytics-leap/)
- [Linked Services - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/concepts-linked-services)
