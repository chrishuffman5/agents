# Azure Data Factory Research Summary

## Key Findings

### 1. ADF is a Mature, Stable Platform with a Defined Successor
- ADF remains a fully managed, serverless data integration service with 90+ connectors, visual pipeline authoring, and enterprise-grade CI/CD support
- Microsoft named a Leader in Gartner's 2025 Magic Quadrant for Data Integration Tools (fifth consecutive year)
- However, Microsoft shifted primary development focus to **Fabric Data Factory** in mid-2024
- New features (mirroring, copy jobs, Copilot AI) ship exclusively in Fabric, not backported to ADF
- ADF remains fully supported and stable; no deprecation announced, but new investment is in Fabric

### 2. Architecture is Pipeline-Activity-Dataset-LinkedService
- Pipelines contain activities; activities consume datasets; datasets reference linked services
- Integration Runtime provides the compute bridge between ADF and data sources
- Three IR types: Azure IR (cloud, managed VNET), Self-hosted IR (on-premises), Azure-SSIS IR (SSIS lift-and-shift)
- Triggers fire pipelines: schedule, tumbling window (stateful time-slice), storage events, custom events

### 3. Data Flows Provide Visual Spark-Based ETL
- Mapping Data Flows execute on managed Apache Spark clusters
- Rich transformation library: join, aggregate, pivot, window, conditional split, surrogate key, rank, flowlet
- Wrangling Data Flows (Power Query-based) were deprecated in 2024; Mapping Data Flows are the path forward
- Performance tuning centers on cluster sizing, TTL, partition strategy, and broadcast joins

### 4. CDC and Metadata-Driven Patterns are Key Capabilities
- Native CDC resource enables continuous (non-batch) data capture from supported sources
- SAP CDC provides dedicated extract capabilities via ODP framework
- Metadata-driven pipelines dramatically reduce pipeline count by parameterizing a single pipeline for hundreds of sources
- These patterns represent ADF's most scalable design approach

### 5. CI/CD is Well-Supported but Has Specific Constraints
- Git integration (Azure Repos, GitHub) for source control; only dev factory connects to Git
- ARM template-based deployment across environments (dev -> test -> prod)
- Automated publishing via NPM package (`@microsoft/azure-data-factory-utilities`) eliminates manual Publish button
- Pre/post-deployment scripts needed for trigger management during deployments

### 6. Migration to Fabric is the Strategic Direction
- Public preview of ADF/Synapse to Fabric migration assistant launched March 2026
- Assessment-first approach: teams evaluate compatibility before migration
- Fabric Data Factory retains ADF's core engine while adding OneLake, Copilot, and expanded activities
- New projects should evaluate Fabric first; existing ADF investments continue to be supported

---

## Confidence Levels

| Topic | Confidence | Notes |
|-------|-----------|-------|
| Core architecture (pipelines, activities, datasets, linked services) | **High** | Well-documented, stable since ADF v2 launch |
| Integration Runtime types and configuration | **High** | Extensive Microsoft documentation and community content |
| Data Flow transformations and expressions | **High** | Comprehensive Microsoft Learn documentation |
| Triggers (schedule, tumbling window, event-based) | **High** | Well-documented with detailed behavior descriptions |
| CI/CD with ARM templates and Git integration | **High** | Established patterns with Microsoft-provided tooling |
| Copy Activity performance optimization | **High** | Detailed performance guide with specific recommendations |
| Data Flow performance tuning | **High** | Microsoft provides optimization guide with Spark-specific guidance |
| Error handling and retry patterns | **High** | Well-documented with activity path dependencies |
| Self-hosted IR troubleshooting | **High** | Built-in diagnostic tool; extensive troubleshooting docs |
| CDC capabilities | **Medium-High** | Native CDC resource documented; SAP CDC well-covered |
| Metadata-driven pipeline patterns | **Medium-High** | Community and Microsoft patterns available; not a single official template |
| Pricing and cost optimization | **Medium-High** | Published pricing; reserved capacity details confirmed |
| ADF vs Fabric convergence timeline | **Medium** | Migration assistant in preview; no firm deprecation timeline for ADF |
| Wrangling Data Flow deprecation details | **Medium** | Deprecated in favor of Mapping Data Flows and Fabric Dataflow Gen2 |
| Azure-SSIS IR detailed troubleshooting | **Medium** | Documented but fewer community resources than other IR types |
| Managed VNET data exfiltration prevention | **Medium** | Feature documented; limited real-world implementation guidance |

---

## Gaps and Areas for Further Research

### Gaps Identified
1. **Fabric migration experience quality**: Migration assistant is in public preview (March 2026); real-world migration success rates and common blockers are not yet well-documented
2. **ADF long-term support timeline**: Microsoft has not published a formal deprecation date or end-of-support timeline for ADF; guidance is "continue using ADF, but new projects should consider Fabric"
3. **Data Flow expression edge cases**: While the expression language is documented, complex scenarios (deeply nested JSON, regex edge cases, unicode handling) have limited examples
4. **Cost comparison ADF vs Fabric**: Direct cost comparison is difficult due to different pricing models (per-activity vs Fabric capacity-based)
5. **Performance benchmarks**: No published, standardized performance benchmarks comparing ADF Copy Activity vs Fabric Copy jobs or Data Flows vs Fabric Dataflow Gen2
6. **Managed VNET egress pricing**: Network egress costs when using managed private endpoints are not clearly documented separately from standard Azure networking charges

### Recommended Follow-Up Research
- Monitor Fabric Data Factory migration assistant GA timeline and migration success stories
- Track any ADF deprecation announcements from Microsoft Build or Ignite conferences
- Investigate Fabric Dataflow Gen2 capabilities as the successor to ADF Mapping Data Flows
- Research ADF integration with Microsoft Purview in Fabric (unified governance story)

---

## Sources

### Microsoft Official Documentation
- [Introduction to Azure Data Factory](https://learn.microsoft.com/en-us/azure/data-factory/introduction)
- [Pipelines and Activities](https://learn.microsoft.com/en-us/azure/data-factory/concepts-pipelines-activities)
- [Integration Runtime](https://learn.microsoft.com/en-us/azure/data-factory/concepts-integration-runtime)
- [Mapping Data Flows](https://learn.microsoft.com/en-us/azure/data-factory/concepts-data-flow-overview)
- [Data Flow Performance Tuning](https://learn.microsoft.com/en-us/azure/data-factory/concepts-data-flow-performance)
- [Copy Activity Performance](https://learn.microsoft.com/en-us/azure/data-factory/copy-activity-performance)
- [Pipeline Execution and Triggers](https://learn.microsoft.com/en-us/azure/data-factory/concepts-pipeline-execution-triggers)
- [CI/CD in ADF](https://learn.microsoft.com/en-us/azure/data-factory/continuous-integration-delivery)
- [Change Data Capture](https://learn.microsoft.com/en-us/azure/data-factory/concepts-change-data-capture)
- [Connector Overview](https://learn.microsoft.com/en-us/azure/data-factory/connector-overview)
- [Plan and Manage Costs](https://learn.microsoft.com/en-us/azure/data-factory/plan-manage-costs)
- [Troubleshooting Guide](https://learn.microsoft.com/en-us/azure/data-factory/data-factory-troubleshoot-guide)
- [Self-Hosted IR Troubleshooting](https://learn.microsoft.com/en-us/azure/data-factory/self-hosted-integration-runtime-troubleshoot-guide)
- [Fabric vs ADF Comparison](https://learn.microsoft.com/en-us/fabric/data-factory/compare-fabric-data-factory-and-azure-data-factory)

### Microsoft Blog and Community
- [Migrating ADF/Synapse to Fabric](https://techcommunity.microsoft.com/blog/microsoftmissioncriticalblog/migrating-azure-data-factory-and-synapse-pipelines-to-fabric-data-factory/4510051)
- [From Synapse and ADF to Fabric](https://blog.fabric.microsoft.com/en-US/blog/from-azure-synapse-and-azure-data-factory-to-microsoft-fabric-the-next-gen-analytics-leap/)
- [Performance Tune ADF Data Flow Transformations](https://techcommunity.microsoft.com/blog/azuredatafactoryblog/performance-tune-adf-data-flow-transformations/1830122)

### Third-Party Analysis
- [Azure Data Factory Review 2026 - Integrate.io](https://www.integrate.io/blog/azure-data-factory-review/)
- [ADF Pricing Guide 2025 - RudderStack](https://www.rudderstack.com/blog/azure-data-factory-pricing/)
- [ADF Pricing 2026 - Integrate.io](https://www.integrate.io/blog/azure-data-factory-pricing/)
- [Metadata-Driven Ingestion Blueprint - Bix Tech](https://bix-tech.com/metadata-driven-ingestion-in-azure-data-factory-a-practical-blueprint-for-scalable-lowmaintenance-pipelines/)
- [Comparison of Fabric, Synapse, ADF, and Databricks - mainri.ca](https://mainri.ca/2025/07/10/comparison-of-microsoft-fabric-azure-synapse-analytics-asa-azure-data-factory-adf-and-azure-databricks-adb/)
