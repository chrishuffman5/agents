# SSIS Version Features

## Version Timeline

| Version | SQL Server | Visual Studio Tooling | Key Theme |
|---|---|---|---|
| SSIS 2014 | SQL Server 2014 | SSDT 2013 | Incremental improvements |
| SSIS 2016 | SQL Server 2016 | SSDT 2015 | Always Encrypted support, SSIS Scale Out (preview) |
| SSIS 2017 | SQL Server 2017 | SSDT 2017 | Scale Out GA, Linux catalog support |
| SSIS 2019 | SQL Server 2019 | SSDT 2019 / VS 2019 | Flexible File (Parquet/Avro), Azure improvements |
| SSIS 2022 | SQL Server 2022 | SSIS Projects extension for VS 2019/2022 | Minimal SSIS changes; SQL Server focus elsewhere |
| SSIS 2025 | SQL Server 2025 | SSIS Projects extension for VS 2022/2026 | Security modernization, deprecations, Fabric bridge |

---

## SSIS 2019 (SQL Server 2019)

### New Features
- **Flexible File Task**: New task for file operations against Azure Blob Storage and Azure Data Lake Storage Gen2
- **Flexible File Source/Destination**: Read from and write to Azure Blob and ADLS Gen2 with support for:
  - **Parquet** file format (requires Java Runtime Environment)
  - **Avro** file format
  - **ORC** file format (requires Java Runtime Environment)
  - **Delimited text** format
- **Wildcard support**: Copy and delete operations support wildcard patterns in Flexible File Task
- **Recursive file operations**: Enable/disable recursive searching for delete operations
- **Azure Feature Pack updates**: Updated Azure connectors for Blob Storage, ADLS Gen2
- **Data Flow improvements**: Performance enhancements for large-scale data movement

### Java Runtime Requirement
- Parquet and ORC file formats require Java to be installed on the SSIS runtime machine
- Java architecture (32-bit or 64-bit) must match the SSIS execution mode
- This dependency was notable and somewhat controversial in the SSIS community

### Supported Data Sources
- All prior SQL Server, Oracle, Flat File, Excel, XML sources
- Azure Blob Storage (via Azure Feature Pack)
- Azure Data Lake Storage Gen2
- HDFS (Hadoop Distributed File System) -- still supported in 2019
- OData feeds
- SAP BW (via Microsoft Connector)
- Oracle (via Microsoft Connector for Oracle)
- Teradata (via Microsoft Connector for Teradata)

---

## SSIS 2022 (SQL Server 2022)

### Changes
SQL Server 2022 focused heavily on database engine improvements (Intelligent Query Processing, ledger, managed disaster recovery with Azure) but introduced **minimal changes to SSIS itself**.

### Key Points
- **No new SSIS-specific features** were introduced in the SSIS engine or data flow
- **Tooling update**: SSIS Projects extension updated for Visual Studio 2022 compatibility
- **Always Encrypted**: Supported via ADO.NET connection manager with `Column Encryption Setting=Enabled` connection string property (this capability existed since SSIS 2016 but improved in tooling)
- **Azure-SSIS IR**: Continued improvements in Azure Data Factory for hosting SSIS packages
- **Managed Identity**: Third-party SSIS tools (e.g., KingswaySoft SSIS Productivity Pack) added managed identity authentication for Azure Key Vault; native SSIS support was limited
- **Parquet support**: Continued from SSIS 2019 via Flexible File components (still requires Java)

### Why Minimal Changes
Microsoft's investment was shifting toward Azure Data Factory and what would become Microsoft Fabric. SSIS 2022 was essentially a maintenance release for SSIS -- keeping it compatible with SQL Server 2022 without significant new development.

---

## SSIS 2025 (SQL Server 2025)

### New Features
- **ADO.NET Connection Manager with Microsoft.Data.SqlClient**: The ADO.NET connection manager now supports the Microsoft SqlClient Data Provider (Microsoft.Data.SqlClient), replacing the legacy System.Data.SqlClient. This enables:
  - **Microsoft Entra ID authentication** (formerly Azure AD) for centralized identity-based auth
  - **TLS 1.3** support for enhanced transport security
  - **TDS 8.0 Strict Encryption** via SQL Server strict connection encryption

### Deprecated Features
| Feature | Impact | Migration Path |
|---|---|---|
| Legacy Integration Services Service | Can no longer use SSMS to manage SSIS Package Store; affects package deployment model users | Migrate to SSISDB catalog (project deployment model) |
| 32-bit execution mode | All packages must run in 64-bit; SSMS 21 and SSIS Projects 2022 only support 64-bit | Ensure all data providers and custom components have 64-bit versions |
| SqlClient Data Provider (SDS) connection type | SDS connection type in maintenance tasks and Foreach SMO enumerator | Migrate to ADO.NET connection type |

### Removed Features
| Feature | Replacement |
|---|---|
| CDC components by Attunity | Third-party alternatives (COZYROC, KingswaySoft); native SQL Server CDC; Debezium |
| CDC Service for Oracle by Attunity | Oracle GoldenGate; Debezium for Oracle |
| Microsoft Connector for Oracle | Third-party Oracle connectors (Devart, CData, KingswaySoft); ODBC connection |
| Hadoop Hive Task | Azure HDInsight, Databricks, Spark via ADF |
| Hadoop Pig Task | Azure HDInsight, Databricks |
| Hadoop File System Task | Azure Blob/ADLS connectors |

### Breaking Changes
- **Microsoft.SqlServer.Management.IntegrationServices** assembly now depends on **Microsoft.Data.SqlClient** instead of System.Data.SqlClient -- potentially breaks existing deployment scripts and automation
- .NET API `Microsoft.SqlServer.Dts.Runtime` namespace: Projects using Execute SQL Task or SMO-dependent tasks must update references and rebuild
- Packages relying on 32-bit providers will fail at runtime

---

## SSIS in Azure Data Factory (Azure-SSIS IR)

### Capabilities
- **Lift-and-shift**: Run on-premises SSIS packages in Azure without rewriting
- **SSISDB in Azure**: Host catalog in Azure SQL Database or Azure SQL Managed Instance
- **Scalable compute**: Choose node size (Standard_D2_v3 up to Standard_E64_v3) and node count (1-10+)
- **Custom setup**: Install custom components, drivers, licenses on IR nodes via custom setup scripts
- **VNet integration**: Access on-premises data sources via Azure VNet, VPN Gateway, or ExpressRoute
- **Managed identity authentication**: Supported for Azure-SSIS IR connections to Azure SQL
- **Package execution**: Execute via ADF pipeline activities (Execute SSIS Package activity), scheduled triggers, or on-demand
- **Third-party components**: Install third-party SSIS components (KingswaySoft, COZYROC, CData) on the IR
- **Cost optimization**: Start/stop the IR on schedule to avoid costs during idle periods

### Limitations
- Cold start time: Provisioning/starting the IR takes approximately 20-30 minutes
- No support for SSIS Scale Out architecture in Azure-SSIS IR
- Custom setup script execution adds to startup time
- Cost: Running a multi-node IR 24/7 can be expensive vs. serverless ADF activities

---

## SSIS vs. Modern Alternatives

### Where SSIS Still Makes Sense
- **Existing investment**: Organizations with hundreds/thousands of existing SSIS packages and institutional knowledge
- **On-premises SQL Server**: When data must stay on-premises and SQL Server is the primary platform
- **Complex transformations**: SSIS's visual data flow designer handles complex, multi-step transformations well
- **Windows-centric environments**: Deep integration with Windows security, file system, and SQL Server
- **Compliance requirements**: Industries requiring on-premises data processing (financial, healthcare, government)
- **Batch ETL**: Traditional batch-oriented ETL workloads with scheduled execution

### Where to Consider Migration
- **Cloud-first or cloud-native architectures**: ADF, Fabric, or Airflow are better fits
- **Real-time/streaming data**: SSIS is batch-oriented; consider Kafka, Spark Streaming, ADF with Event Grid
- **Modern data stack**: dbt + Fivetran/Airbyte for ELT; Airflow/Dagster for orchestration
- **Cross-platform/multi-cloud**: SSIS is Windows/SQL Server only; Airflow, dbt, Spark are platform-agnostic
- **Cost optimization**: Serverless options (ADF Mapping Data Flows, Fabric Dataflows) avoid fixed infrastructure
- **Team skills**: If team is Python/SQL-centric rather than .NET/Visual Studio-centric

### Comparison Matrix

| Capability | SSIS | Azure Data Factory | Apache Airflow | dbt |
|---|---|---|---|---|
| Deployment | On-premises / Azure-SSIS IR | Cloud-native (Azure) | Self-hosted / managed (Astronomer, MWAA) | Cloud (dbt Cloud) or CLI |
| Design paradigm | Visual GUI (drag-and-drop) | Visual GUI (browser-based) | Code-first (Python DAGs) | SQL-first (models) |
| Transformation | In-memory pipeline engine | Mapping Data Flows (Spark) | External (delegates to engines) | SQL-based (in-database) |
| Orchestration | Control flow + SQL Agent | Pipelines + triggers | DAGs + scheduler | Jobs + scheduler |
| Scalability | Vertical (bigger server) + Scale Out | Horizontal (auto-scale Spark) | Horizontal (worker pools) | Database-dependent |
| Real-time | No (batch only) | Yes (event triggers, streaming) | Yes (sensors, event-driven) | No (batch only) |
| Cost model | SQL Server license | Pay-per-use | Open source + infrastructure | Free (Core) / SaaS (Cloud) |
| Ecosystem | Microsoft/.NET | Azure ecosystem | Python ecosystem | SQL ecosystem / Fivetran |

---

## Deprecation Signals and Future Direction

### What Microsoft Is Signaling
1. **SSIS 2025 announcement was on the Microsoft Fabric Blog**, not the SQL Server blog -- widely noted as intentional
2. **Minimal new features**: SSIS 2025 added only one new feature (ADO.NET with Microsoft.Data.SqlClient); the rest was deprecations and removals
3. **Fabric positioning**: Microsoft explicitly positions Fabric as the next-generation unified analytics platform
4. **Invoke SSIS Package in Fabric**: Bridge activity allowing SSIS packages to run from Fabric pipelines (preview)
5. **No EOL date announced**: SQL Server 2022 extended support runs through January 2033; SQL Server 2025 will have similar lifecycle
6. **Ecosystem adaptation**: Third-party vendors (COZYROC, KingswaySoft) building replacement components for removed SSIS functionality

### Practical Timeline
- **Now - 2028**: SSIS remains fully supported; new projects can still use SSIS but should consider alternatives
- **2028 - 2033**: Maintenance mode increasingly likely; migration planning should be active
- **2033+**: SQL Server 2022 end of extended support; organizations should have migration plans in place
- **Key risk**: If Microsoft does not include SSIS in a future SQL Server version, the migration window narrows significantly

### Recommendation
- **New projects**: Prefer Azure Data Factory, Microsoft Fabric, or open-source alternatives unless there is a compelling on-premises requirement
- **Existing projects**: No immediate action needed; begin planning migration on a package-by-package basis, prioritizing packages with deprecated components
- **Hybrid approach**: Use Azure-SSIS IR or Fabric's Invoke SSIS Package activity to run existing packages while building new workloads on modern platforms
