# Azure Synapse Pipelines Features

## Current Capabilities

### Unified Analytics Platform
Azure Synapse Analytics combines data integration, enterprise data warehousing, and big data analytics into a single unified workspace. Synapse Pipelines are the data integration component, providing orchestration and ETL/ELT capabilities tightly integrated with the rest of the workspace.

### Pipeline Orchestration
- **90+ native connectors** for data movement across cloud and on-premises sources
- **Copy Activity** for high-throughput data movement with auto-parallelization and format conversion
- **Control flow activities**: ForEach, If Condition, Switch, Until, Wait, Execute Pipeline, Lookup, Get Metadata, Set Variable, Append Variable, Filter, Validation, Webhook, Web, Fail
- **Parameterization**: Pipeline parameters, system variables, expressions, and dynamic content throughout activities
- **Parent-child pipeline pattern**: Execute Pipeline activity for modular, reusable pipeline design
- **Pipeline annotations and folders**: Organizational features for managing large numbers of pipelines

### Spark Integration (Native)
- **Synapse Notebook activity**: Run Synapse notebooks (PySpark, Scala, SparkSQL, .NET Spark, R) as pipeline steps
- **Spark Job Definition activity**: Submit batch Spark applications
- Notebook parameters passed from pipeline expressions for dynamic execution
- Session-level and pool-level library management
- Output capture from notebooks back into pipeline variables

### SQL Pool Integration (Native)
- **Dedicated SQL pool**: Direct Copy Activity sink, Stored Procedure activity, native Spark-to-SQL connector (COPY INTO)
- **Serverless SQL pool**: SQL Script activity, ad-hoc query execution, external table creation
- **Workspace DB data flow source**: Data flows can directly reference SQL pool tables without explicit linked service configuration

### Mapping Data Flows
- Visual, code-free Spark-based transformations
- Schema drift support for handling dynamic schemas
- Debug mode with live data preview and step-by-step execution
- Flowlets for reusable transformation logic
- Parameterization via pipeline expressions
- External Call transformation for REST API integration during data flow execution

### Monitoring and Observability
- **Synapse Studio Monitor hub**: Real-time and historical monitoring of pipeline runs, activity runs, trigger runs, Spark applications, and SQL requests
- **Azure Monitor integration**: Diagnostic logs, metrics, and alerts via Azure Monitor
- **Log Analytics / KQL**: Pipeline run data queryable via Kusto Query Language in Log Analytics workspaces
- **Integration Runtime monitoring**: Health, capacity, and utilization metrics for Azure IR and Self-Hosted IR

### Security Features
- **Managed Virtual Network**: Network isolation for all Synapse compute resources
- **Managed Private Endpoints**: Private Link connections from the managed VNET to Azure services (Azure SQL, Storage, Cosmos DB, Key Vault, etc.)
- **Data Exfiltration Protection (DEP)**: Restricts all outbound traffic to approved Microsoft Entra tenants only; must be enabled at workspace creation and cannot be changed later
- **Azure Key Vault integration**: Centralized secret management for linked service credentials
- **Managed Identity**: System-assigned and user-assigned managed identities for authentication
- **Role-Based Access Control (RBAC)**: Synapse RBAC roles (Synapse Administrator, Synapse SQL Administrator, Synapse Spark Administrator, Synapse Contributor, Synapse Artifact Publisher, Synapse Artifact User, Synapse Compute Operator, Synapse Credential User)
- **Row-level and column-level security** in dedicated SQL pools
- **Dynamic data masking** in dedicated SQL pools

---

## Synapse Pipelines vs ADF: Detailed Differences

### Features Present in ADF but Missing in Synapse Pipelines

| Feature | ADF | Synapse |
|---|---|---|
| **Global parameters** | Supported -- environment-level configuration (connection strings, etc.) | Not supported -- significant gap for multi-environment deployments |
| **Azure-SSIS IR** | Fully supported for SSIS package lift-and-shift | Not supported -- must use standalone ADF |
| **Data flow script editing** | Available | Available (same) |
| **Change Data Capture (CDC)** | Native CDC connector and activity | Available (same as ADF) |
| **CI/CD via ARM templates** | Standard ARM template deployment task | Requires Synapse-specific deployment task; artifacts are not ARM resources |

### Features Unique to Synapse Pipelines (Not in Standalone ADF)

| Feature | Description |
|---|---|
| **Synapse Notebook activity** | Native execution of Synapse Spark notebooks as pipeline steps |
| **Spark Job Definition activity** | Native batch Spark job submission |
| **Workspace DB data flow source** | Direct reference to workspace SQL/Spark databases in data flows |
| **Native dedicated SQL pool integration** | Tighter integration with COPY INTO, PolyBase, and the dedicated SQL pool connector |
| **Unified monitoring** | Single Monitor hub for pipelines, Spark jobs, SQL queries, and triggers |
| **Synapse Link integration** | Native HTAP queries over operational stores from within the same workspace |

### Features Identical in Both
- Pipeline execution engine and activity runtime
- Copy Activity with auto-parallelization and format support
- All control flow activities
- Mapping Data Flow engine and transformation set
- Trigger types (schedule, tumbling window, storage event, custom event)
- Self-Hosted Integration Runtime
- Azure IR with managed VNET

---

## Microsoft Fabric Migration Path

### Strategic Context
- Microsoft Fabric is Microsoft's unified SaaS analytics platform, consolidating Power BI, Data Factory, Synapse, and more
- Fabric reached GA in November 2023 and has surpassed $2 billion annual revenue run rate with 31,000+ customers
- Most new R&D investment from Microsoft is focused on Fabric rather than Synapse
- **Azure Synapse Analytics is NOT being retired** -- it continues to be supported with no announced end-of-life date
- However, new feature development is increasingly Fabric-focused
- **Synapse Data Explorer (Preview) was retired on October 7, 2025** -- the only Synapse component formally discontinued

### Migration Assistants

Microsoft provides guided migration tools built into both Synapse and Fabric:

**Pipeline Migration Assistant (Preview)**
- Accessible from the Integrate hub in Synapse: "Migrate to Fabric" menu option
- Three-stage flow: Assessment, Review, Migration
- Assessment stage analyzes pipeline compatibility, supported activities, and readiness
- Automatically converts linked services into Fabric connections
- Disables triggers by default after migration for safe validation
- Preserves existing pipeline logic during conversion

**Spark Migration Assistant (Preview)**
- Built into the Fabric Data Engineering experience
- Automatically migrates core Spark artifacts (notebooks, Spark job definitions, configurations) from Synapse into Fabric Data Engineering
- Handles library references and session configuration translation

**Data Warehouse Migration Assistant**
- Migrates from Synapse dedicated SQL pools to Fabric Data Warehouse
- Handles tables, views, stored procedures, and functions
- AI-powered assistance via Copilot for schema translation and T-SQL compatibility adjustments
- Automates metadata, schema, and data migration

### Fabric Equivalents of Synapse Components

| Synapse Component | Fabric Equivalent |
|---|---|
| Synapse Pipelines | Fabric Data Factory pipelines |
| Dedicated SQL pool | Fabric Data Warehouse |
| Serverless SQL pool | Fabric SQL Analytics Endpoint (via Lakehouse) |
| Spark pools | Fabric Data Engineering (Spark) |
| Data Explorer pools | Fabric Real-Time Intelligence (KQL) |
| Mapping Data Flows | Fabric Dataflows Gen2 (Power Query based) |
| Synapse Link | Fabric Mirroring |
| Synapse Studio | Fabric workspace experience |

### Migration Considerations
- Not all Synapse pipeline activities have 1:1 Fabric equivalents -- run the assessment first
- Linked services become Fabric connections; some connector types may differ
- Triggers are disabled post-migration -- re-enable after validation
- Spark runtime versions and library compatibility should be verified
- T-SQL syntax differences between dedicated SQL pool and Fabric Data Warehouse (Fabric uses a subset of T-SQL)
- Cost model changes: Synapse is pay-per-use; Fabric uses capacity units (CU) with reserved or pay-as-you-go pricing

---

## Synapse Link

Synapse Link enables Hybrid Transactional and Analytical Processing (HTAP) by creating near-real-time, zero-ETL data synchronization from operational stores into the Synapse workspace analytical store.

### Synapse Link for Azure Cosmos DB
- Creates a cloud-native HTAP integration between Cosmos DB and Synapse
- Enables an **analytical store** (column-oriented) on Cosmos DB containers alongside the row-oriented transactional store
- Queryable via Synapse Spark pools and serverless SQL pools
- Supports Cosmos DB SQL API and MongoDB API (Gremlin API in preview)
- **Custom partitioning**: Partition the analytical store by frequently-used filter keys for improved query performance
- **Important**: Synapse Link for Cosmos DB is no longer recommended for new projects as of 2025 -- Microsoft recommends **Azure Cosmos DB Mirroring for Microsoft Fabric** (GA) instead, which provides the same zero-ETL benefits with full Fabric integration

### Synapse Link for SQL
- Near-real-time data replication from Azure SQL Database or SQL Server 2022 to Synapse dedicated SQL pool
- Change feed-based incremental sync
- Minimal impact on source OLTP performance
- Known limitations with certain column types and schema changes

### Synapse Link for Dataverse
- Synchronizes Microsoft Dataverse data (Power Apps, Dynamics 365) into the Synapse workspace
- Data lands in ADLS Gen2 in Delta or CSV format
- Queryable via serverless SQL pools and Spark pools
- Enables analytics over Dynamics 365 operational data (Sales, Finance, Supply Chain, etc.)
- **Note**: Microsoft is transitioning Dataverse Link to **Fabric Link for Dataverse** as the recommended path forward

### Synapse Link Common Characteristics
- Zero-ETL: No pipeline authoring required for data synchronization
- Near-real-time latency (typically seconds to minutes)
- No impact on transactional workload performance (reads from change feed / analytical store)
- Data lands in analytics-optimized formats (columnar for Cosmos DB, Delta for Dataverse)
