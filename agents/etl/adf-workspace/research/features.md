# Azure Data Factory Features

## Connectors

### Breadth of Connectivity
- 90+ built-in connectors spanning cloud, on-premises, and SaaS platforms
- No per-connector licensing fees -- all connectors included with ADF
- Connector categories:
  - **Azure services**: SQL Database, ADLS Gen2, Blob Storage, Cosmos DB, Synapse, Databricks, Azure Table, Azure Files, Azure Search
  - **Databases**: SQL Server, Oracle, MySQL, PostgreSQL, MongoDB, Cassandra, Couchbase, MariaDB, Db2, Informix, Teradata, Netezza, SAP HANA, SAP BW, SAP Table
  - **Cloud storage**: Amazon S3, Google Cloud Storage, HDFS, FTP, SFTP, HTTP
  - **Cloud databases**: Amazon Redshift, Google BigQuery, Snowflake
  - **SaaS**: Salesforce, Dynamics 365, ServiceNow, SAP ECC, SAP Cloud, SharePoint, HubSpot, Marketo, QuickBooks, Xero, Concur, Google Ads, Facebook
  - **File formats**: CSV, JSON, Parquet, Avro, ORC, Delta, Excel, XML, Binary
  - **NoSQL**: Cosmos DB (SQL, MongoDB, Gremlin, Cassandra APIs), MongoDB, Couchbase
  - **Analytics**: Azure Data Explorer, Power BI datasets
  - **Messaging**: Azure Event Hubs (via custom activities)

### Connector Lifecycle
- Connectors follow release stages: Preview -> GA -> Deprecated -> Retired
- Deprecated connectors receive upgrade guidance and migration paths
- Microsoft publishes connector release timelines for planning

---

## Change Data Capture (CDC)

### Native CDC Resource
- Top-level CDC resource in ADF Studio provides a guided setup experience
- Select sources and destinations, apply optional transformations, and start capture
- Runs **continuously** (unlike pipelines which are batch-only)
- Tracks changes at the source and incrementally processes only modified data
- Supports multiple source types: SQL Server, Azure SQL, Oracle, PostgreSQL

### CDC Architecture
- CDC resources use a polling or log-based mechanism depending on the source
- Changes are captured and applied to the target in near-real-time
- Supports initial snapshot load followed by continuous incremental capture
- Schema drift handling for dynamic source schemas

### SAP CDC
- Dedicated SAP Change Data Capture capabilities
- Supports SAP extractors and ODP (Operational Data Provisioning) framework
- Advanced topics include delta extraction, hierarchy handling, and full/incremental loads

### Metadata-Driven CDC Patterns
- Combine CDC with metadata-driven pipelines for scalable, table-level CDC configurations
- Configuration stored in control tables (database or JSON)
- ForEach activity iterates over tables with watermark tracking
- Parquet staging for efficient intermediate data storage

---

## Data Flow Transformations

### Source and Sink
- **Source**: Read from any supported data store; supports projection, optimization, sampling
- **Sink**: Write to any supported data store; supports pre/post SQL scripts, mapping, partitioning

### Row Modification
- **Filter**: Filter rows based on a condition expression
- **Select**: Choose, rename, reorder, or drop columns
- **Derived Column**: Create new columns or modify existing ones using expressions
- **Alter Row**: Set insert/update/delete/upsert policies for database sinks
- **Assert**: Validate data quality rules and raise errors on violations

### Multiple Inputs/Outputs
- **Join**: Inner, outer (left, right, full), cross join with custom conditions
- **Lookup**: Reference lookup from another stream (like a left outer join returning first match)
- **Exists**: Semi-join that checks if rows exist in another stream
- **Union**: Combine multiple streams vertically (column matching by name or position)
- **Conditional Split**: Route rows to different output streams based on conditions

### Schema Modifier
- **Aggregate**: Group by columns and compute aggregate functions (sum, count, avg, min, max, etc.)
- **Pivot**: Transform rows to columns
- **Unpivot**: Transform columns to rows
- **Window**: Window functions (rank, dense_rank, row_number, lag, lead, running totals)
- **Rank**: Generate rank values across the entire dataset
- **Surrogate Key**: Generate auto-incrementing integer keys
- **Flatten**: Expand arrays or complex structures into individual rows

### Formatters
- **Parse**: Parse string columns into structured types (JSON, XML, delimited text)
- **Stringify**: Convert complex types to string representation

### Flowlets
- Reusable data flow components (sub-flows)
- Parameterized for flexibility
- Promote consistency and reduce duplication across data flows

### External Call
- Call external REST APIs within a data flow transformation
- Pass row data as request payload and capture response in new columns

### Data Flow Expressions
- Rich expression language for derived columns, filters, aggregates, and joins
- Functions: string (concat, substring, trim, upper, lower, regex), math (round, floor, ceiling, abs), date/time (currentTimestamp, addDays, dayOfWeek, year), conversion (toString, toInteger, toDecimal, toDate), logical (iif, case, isNull, coalesce), aggregate (sum, count, avg, min, max, collect, first, last)
- Supports complex expressions, nested functions, and column pattern matching
- Expression builder with IntelliSense in ADF Studio

---

## Metadata-Driven Pipelines

### Concept
- Design a single parameterized pipeline that handles integration of hundreds or thousands of sources
- Configuration stored externally (database control tables, JSON files, Azure Table Storage)
- Pipeline reads configuration at runtime and dynamically adjusts behavior

### Key Patterns
- **Control table**: Stores source object name, target, load type (full/incremental), key columns, watermark column, active flag
- **Lookup + ForEach**: Lookup activity reads the control table, ForEach iterates over results
- **Dynamic linked services**: Parameterized linked services with connection strings resolved at runtime
- **Dynamic datasets**: Parameterized datasets with table/file names resolved from pipeline parameters
- **Dynamic Copy Activity**: Source query, sink table, column mapping all driven by metadata

### Benefits
- Dramatically reduces the number of pipelines to build and maintain
- Adding a new source is a configuration change, not a code change
- Consistent patterns across all data sources
- Easier to audit and govern

---

## Global Parameters and Pipeline Parameters

### Pipeline Parameters
- Defined at the pipeline level with name, type, and default value
- Types: String, Int, Float, Bool, Array, Object, SecureString
- Passed by triggers, parent pipelines (Execute Pipeline), or manual runs
- Accessed in expressions via `@pipeline().parameters.paramName`
- Enable reusable, parameterized pipeline designs

### Global Parameters
- Defined at the factory level and accessible by all pipelines in the factory
- Useful for environment-level configuration (environment name, base URLs, default settings)
- Accessed via `@pipeline().globalParameters.paramName`
- Included in ARM template deployments; can be overridden per environment
- Support CI/CD parameter files for environment-specific values

### Variables
- Pipeline-scoped variables for storing intermediate results
- Set Variable and Append Variable activities modify variables during execution
- Types: String, Boolean, Array
- Useful in loops (ForEach, Until) for accumulating results

---

## Integration with Azure Services

### Azure Databricks
- Native Databricks activities: Notebook, JAR, Python
- Pass parameters to Databricks jobs and capture output
- Use Databricks for complex transformations that exceed Data Flow capabilities
- Linked service supports Azure Key Vault for token management

### Azure Synapse Analytics
- Copy Activity supports Synapse dedicated SQL pool with PolyBase/COPY staging
- Stored Procedure activity for executing Synapse SQL procedures
- Synapse Pipelines share the same engine as ADF
- Synapse Link provides near-real-time analytics bridge

### Azure Key Vault
- Store connection strings, passwords, SAS tokens, and secrets securely
- Linked services reference Key Vault secrets instead of hardcoding credentials
- Managed identity authentication to Key Vault (no additional credentials needed)
- Key Vault references in pipeline parameters and global parameters

### Azure Monitor
- Diagnostic settings push ADF metrics and logs to Log Analytics
- Built-in metrics: pipeline/activity/trigger run counts, success/failure rates, IR utilization
- Custom KQL queries for operational dashboards
- Alert rules on pipeline failures, long-running activities, IR health
- Integration with Azure Monitor Workbooks for visual monitoring

### Microsoft Purview
- Automatic data lineage capture: when ADF pipelines run, lineage metadata is pushed to Purview
- Tracks data movement from source to destination through transformations
- Managed identity used for authentication between ADF and Purview
- Supports governance, compliance, and impact analysis scenarios
- Lineage captured for Copy Activity, Data Flow, and Execute SSIS Package activities

### Azure DevOps
- Git integration for source control (Azure Repos)
- CI/CD pipelines for automated validation, build (ARM template generation), and deployment
- Release pipelines with staged approvals and environment-specific parameter files
- Integration with Azure DevOps work items for change tracking

---

## Sources

- [Connector Overview - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/connector-overview)
- [Change Data Capture - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/concepts-change-data-capture)
- [CDC Resource - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/concepts-change-data-capture-resource)
- [SAP CDC Advanced Topics - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/sap-change-data-capture-advanced-topics)
- [Mapping Data Flows - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/concepts-data-flow-overview)
- [Managed Identity - Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/data-factory-service-identity)
- [Connect ADF to Purview - Microsoft Learn](https://learn.microsoft.com/en-us/purview/data-map-lineage-azure-data-factory)
- [Metadata-Driven Ingestion Blueprint - Bix Tech](https://bix-tech.com/metadata-driven-ingestion-in-azure-data-factory-a-practical-blueprint-for-scalable-lowmaintenance-pipelines/)
- [Azure Data Factory Review 2026 - Integrate.io](https://www.integrate.io/blog/azure-data-factory-review/)
