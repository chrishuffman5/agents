# SSIS Research Summary

## Key Findings

### 1. SSIS Is a Mature but Transitioning Platform
SSIS remains a fully supported, production-grade ETL platform as of SQL Server 2025, but Microsoft is clearly steering investment toward Microsoft Fabric and Azure Data Factory. The SSIS 2025 release contained only one new feature (ADO.NET connection manager with Microsoft.Data.SqlClient) alongside multiple deprecations and removals, signaling maintenance mode.

### 2. SSIS 2025 Focuses on Security Modernization
The sole new feature enables Entra ID authentication, TLS 1.3, and TDS 8.0 strict encryption. This aligns existing SSIS packages with modern security requirements, particularly for connecting to Azure SQL and Microsoft Fabric endpoints. The emphasis is on making existing packages compatible with modern infrastructure rather than expanding SSIS capabilities.

### 3. Significant Removals in SSIS 2025
- CDC components by Attunity (removed)
- Microsoft Connector for Oracle (removed)
- Hadoop components (Hive, Pig, File System tasks -- removed)
- Legacy SSIS Service / Package Store (deprecated)
- 32-bit execution mode (deprecated)
- SqlClient Data Provider (SDS) connection type (deprecated)
- Breaking change: Microsoft.SqlServer.Management.IntegrationServices now depends on Microsoft.Data.SqlClient

### 4. Microsoft Fabric Is the Intended Successor
- SSIS 2025 was announced on the Microsoft Fabric Blog (not SQL Server blog)
- Invoke SSIS Package activity in Fabric pipelines (preview) enables lift-and-shift
- Microsoft positions Fabric Data Factory as the modern replacement
- No EOL date has been announced; SQL Server 2022 support runs through January 2033

### 5. Architecture Strengths Remain Relevant
- The two-engine architecture (Control Flow + Data Flow Pipeline) provides clear separation of concerns
- In-memory buffer-based data flow engine delivers high throughput for batch ETL
- SSISDB catalog offers robust deployment, parameterization, and monitoring
- The visual designer remains accessible for teams without deep coding expertise

### 6. Performance Optimization Is Well-Understood
- Buffer sizing (DefaultBufferMaxRows, DefaultBufferSize, AutoAdjustBufferSize) has the biggest single impact
- Avoiding blocking transformations (Sort, Aggregate) in favor of source-query equivalents
- Full-cache Lookup with indexed reference tables
- Fast Load mode for OLE DB destinations
- MaxConcurrentExecutables for parallel task execution

### 7. CI/CD Tooling Has Matured
- Microsoft SSIS DevOps Tools extension for Azure DevOps provides Build, Deploy, and Configure tasks
- PowerShell-based deployment via IntegrationServices managed API
- JSON-based environment configuration for multi-stage deployment

---

## Confidence Levels

| Topic | Confidence | Notes |
|---|---|---|
| Core architecture (engines, buffers, execution trees) | High | Well-documented by Microsoft; stable for 10+ years |
| SSIS 2025 features and deprecations | High | Verified against official Microsoft Learn documentation |
| SSIS 2022 features | High | Confirmed minimal SSIS-specific changes in this release |
| SSIS 2019 features (Flexible File, Parquet) | High | Well-documented; verified across multiple sources |
| Azure-SSIS IR capabilities | High | Comprehensive Microsoft documentation available |
| Microsoft Fabric integration | Medium-High | In preview; details still evolving; official blog posts confirm direction |
| Future direction / deprecation timeline | Medium | Based on observable signals (blog placement, feature removals, Fabric investment); no official EOL announced |
| Best practices (performance, design patterns) | High | Consistent guidance across Microsoft docs, community experts, and third-party sources |
| CI/CD deployment | High | Official Microsoft extension available; well-documented community patterns |
| Testing approaches | Medium | Limited official tooling; ssisUnit is community-maintained; SSISTester is commercial |
| Migration patterns (to ADF, Fabric, Airflow, dbt) | Medium-High | ADF migration is well-documented by Microsoft; Fabric migration is emerging; Airflow/dbt patterns are community-driven |

---

## Research Gaps

1. **SSIS Scale Out**: Limited coverage in this research. Scale Out (introduced in SSIS 2017) allows distributing package execution across multiple worker nodes. Need further investigation of its current status and whether it remains supported in SSIS 2025.

2. **SSIS in Linux/Containers**: SQL Server runs on Linux, but SSIS has historically been Windows-only. Current status of any Linux support or containerization options needs clarification.

3. **SSIS and Copilot/AI Integration**: No information found on whether Microsoft is integrating AI capabilities into SSIS design or execution (as they have with other SQL Server features in 2025).

4. **Detailed SSIS 2025 Breaking Change Impact**: The Microsoft.Data.SqlClient dependency change could break many existing deployment scripts and automation. Real-world impact reports are still emerging.

5. **Fabric Invoke SSIS Package Activity**: This is in preview and rapidly evolving. Specific limitations, performance characteristics, and supported configurations need monitoring.

6. **Third-Party Ecosystem Health**: Vendors like KingswaySoft, COZYROC, CData, and Devart fill gaps left by Microsoft removals, but their long-term viability depends on SSIS's continued relevance.

---

## Sources

### Microsoft Official
- [What's New in SSIS 2025 -- Microsoft Learn](https://learn.microsoft.com/en-us/sql/integration-services/what-s-new-in-integration-services-in-sql-server-2025?view=sql-server-ver17)
- [SSIS Connections -- Microsoft Learn](https://learn.microsoft.com/en-us/sql/integration-services/connection-manager/integration-services-ssis-connections?view=sql-server-ver17)
- [Deploy SSIS Projects and Packages -- Microsoft Learn](https://learn.microsoft.com/en-us/sql/integration-services/packages/deploy-integration-services-ssis-projects-and-packages?view=sql-server-ver17)
- [SSIS DevOps Overview -- Microsoft Learn](https://learn.microsoft.com/en-us/sql/integration-services/devops/ssis-devops-overview?view=sql-server-ver16)
- [Error Handling in Data -- Microsoft Learn](https://learn.microsoft.com/en-us/sql/integration-services/data-flow/error-handling-in-data?view=sql-server-ver17)
- [SSIS Event Handlers -- Microsoft Learn](https://learn.microsoft.com/en-us/sql/integration-services/integration-services-ssis-event-handlers?view=sql-server-ver17)
- [SSIS Variables -- Microsoft Learn](https://learn.microsoft.com/en-us/sql/integration-services/integration-services-ssis-variables?view=sql-server-ver17)
- [SSIS Expressions -- Microsoft Learn](https://learn.microsoft.com/en-us/sql/integration-services/expressions/integration-services-ssis-expressions?view=sql-server-ver17)
- [Comparing Script Task and Script Component -- Microsoft Learn](https://learn.microsoft.com/en-us/sql/integration-services/extending-packages-scripting/comparing-the-script-task-and-the-script-component?view=sql-server-ver16)
- [Monitor Running Packages -- Microsoft Learn](https://learn.microsoft.com/en-us/sql/integration-services/performance/monitor-running-packages-and-other-operations?view=sql-server-ver17)
- [Azure-SSIS IR Troubleshooting -- Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/ssis-integration-runtime-management-troubleshoot)
- [Migrate SSIS to ADF -- Microsoft Learn](https://learn.microsoft.com/en-us/azure/data-factory/scenario-ssis-migration-overview)
- [Invoke SSIS Package in Fabric (Preview) -- Microsoft Fabric Blog](https://blog.fabric.microsoft.com/en/blog/invoke-ssis-package-activity-in-microsoft-fabric-preview)
- [SSIS 2025 GA -- Microsoft Fabric Blog](https://blog.fabric.microsoft.com/en-US/blog/the-evolution-of-sql-server-integration-services-ssis-ssis-2025-generally-available/)

### Community / Third-Party
- [SSIS Is Not Dead. Yet. -- sqlfingers.com (March 2026)](https://www.sqlfingers.com/2026/03/ssis-is-not-dead-yet.html)
- [SSIS 2025 -- KingswaySoft](https://www.kingswaysoft.com/resources/industry-trends/ssis-2025)
- [SSIS Performance Best Practices -- MSSQLTips](https://www.mssqltips.com/sqlservertip/1867/sql-server-integration-services-ssis-performance-best-practices/)
- [SSIS Design Best Practices -- MSSQLTips](https://www.mssqltips.com/sqlservertip/1893/sql-server-integration-services-ssis-design-best-practices/)
- [Data Flow Optimization -- SQLShack](https://www.sqlshack.com/integration-services-performance-best-practices-data-flow-optimization/)
- [Script Task vs Script Component -- SQLShack](https://www.sqlshack.com/ssis-script-task-vs-script-component/)
- [SSIS Catalog Dashboard -- Tim Mitchell](https://www.timmitchell.net/post/2019/03/05/ssis-catalog-dashboard/)
- [SSIS Catalog Logging and Reports -- RADACAD](https://radacad.com/ssis-catalog-part-5-logging-and-execution-reports/)
- [ssisUnit -- GitHub (johnwelch)](https://github.com/johnwelch/ssisUnit)
- [SSISTester -- bytesoftwo.com](https://bytesoftwo.com/)
- [10 Best SSIS Alternatives -- Hevo Data](https://hevodata.com/learn/ssis-alternatives/)
- [SSIS Alternatives -- Seattle Data Guy](https://www.theseattledataguy.com/alternatives-to-ssissql-server-integration-services-how-to-migrate-away-from-ssis/)
- [SSIS Connection Managers Comparison -- SQLShack](https://www.sqlshack.com/ssis-connection-managers-ole-db-vs-odbc-vs-ado-net/)
- [SSIS Protection Levels -- MSSQLTips](https://www.mssqltips.com/sqlservertip/2091/securing-your-ssis-packages-using-package-protection-level/)
