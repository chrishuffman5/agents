# Azure Synapse Pipelines Research Summary

## Platform Overview

Azure Synapse Analytics is Microsoft's unified analytics platform that combines data integration (Synapse Pipelines), enterprise data warehousing (dedicated SQL pools), serverless SQL analytics, Apache Spark, and formerly Data Explorer under a single workspace managed through Synapse Studio. Synapse Pipelines share the same execution engine as Azure Data Factory but are embedded within the workspace, providing native integration with Spark pools, SQL pools, and Synapse Link.

## Current Status (as of April 2026)

- **Not retired**: Azure Synapse Analytics continues to be fully supported with no announced end-of-life date
- **Reduced new investment**: Most new R&D and feature development has shifted to Microsoft Fabric
- **Component retirement**: Synapse Data Explorer (Preview) was retired on October 7, 2025; all other components (pipelines, Spark, SQL pools) remain active
- **Migration path available**: Microsoft provides migration assistants for pipelines, Spark artifacts, and dedicated SQL pool schemas/data to Fabric equivalents
- **Synapse Link deprecation**: Synapse Link for Cosmos DB is no longer recommended for new projects; Azure Cosmos DB Mirroring for Fabric is the recommended replacement
- **Fabric trajectory**: Microsoft Fabric surpassed $2 billion ARR with 31,000+ customers, growing at 60% YoY -- it is the strategic analytics platform going forward

## Architecture Key Points

- Workspace-centric model with ADLS Gen2 as the primary storage layer
- Three integration runtime types: Azure IR (managed), Self-Hosted IR (on-premises), Azure-SSIS IR (not supported in Synapse -- ADF only)
- Managed Virtual Network with optional Data Exfiltration Protection (DEP) -- both permanent decisions set at workspace creation
- Pipeline orchestration supports 90+ connectors, all standard control flow activities, Mapping Data Flows, and native Spark/SQL pool activities
- No global parameters (unlike ADF) -- a significant gap for multi-environment deployments

## Key Differentiators from ADF

| Advantage | Detail |
|---|---|
| Native Spark | Synapse Notebook and Spark Job Definition activities without external compute |
| Native SQL pools | Direct integration with dedicated and serverless SQL pools within the workspace |
| Workspace DB source | Data flows can reference workspace databases directly |
| Unified monitoring | Single Monitor hub for all compute types |
| Synapse Link | Built-in HTAP for Cosmos DB, SQL, and Dataverse |

| Limitation | Detail |
|---|---|
| No global parameters | Cannot define workspace-level configuration variables |
| No Azure-SSIS IR | Must use standalone ADF for SSIS package execution |
| CI/CD complexity | Artifacts are not ARM resources; requires Synapse-specific deployment tooling |
| Fabric migration pressure | New features increasingly Fabric-only |

## Best Practices Summary

- **Pipeline design**: Modular parent-child patterns, parameterize everything, ELT over ETL, stage in ADLS Gen2
- **Spark pools**: Start with Medium nodes, enable auto-scale and auto-pause, create multiple pool definitions (free), pin Spark versions
- **SQL pools**: Choose distribution strategy carefully, use Distribution Advisor, pause when idle, monitor TempDB and data skew
- **Security**: Enable Managed VNET and DEP at creation, use managed identity and Key Vault, apply Synapse RBAC least privilege
- **Cost**: Pause dedicated SQL pools after hours, auto-pause Spark pools, use serverless SQL for ad-hoc, set budget alerts, consider reserved capacity
- **CI/CD**: Git-integrate dev workspace only, use Synapse workspace deployment task (not ARM deployment), maintain identical pool names across environments, keep templates under 20 MB

## Common Diagnostic Scenarios

| Category | Top Issues |
|---|---|
| Pipeline failures | Copy Activity schema mismatches, trigger not published/started, data flow OOM errors, Execute Pipeline child failures |
| Spark errors | OutOfMemoryError from driver collect(), storage API throttling (HTTP 429), Spark-SQL connector staging permission errors, library version conflicts |
| SQL pool issues | TempDB exhaustion from data skew/CTAS, distribution skew on NULL-heavy columns, concurrency slot saturation, missing statistics |
| IR connectivity | Managed VNET missing private endpoints, DEP blocking external APIs, SHIR offline or outdated, firewall blocking SHIR outbound ports |

## Monitoring Stack

- **Synapse Studio Monitor hub**: Real-time pipeline, Spark, SQL, and trigger monitoring
- **Azure Monitor + Log Analytics**: Diagnostic logs with KQL queries over SynapseIntegrationPipelineRuns, SynapseIntegrationActivityRuns, SynapseBigDataPoolApplicationsEnded tables
- **Dedicated SQL pool DMVs**: sys.dm_pdw_exec_requests, sys.dm_pdw_request_steps for query-level performance investigation
- **Spark UI / History Server**: Stage-level task analysis, executor metrics, DAG visualization

## Fabric Migration Readiness

Organizations currently on Synapse Pipelines should:
1. **Assess**: Run the pipeline migration assistant to understand compatibility and identify unsupported activities
2. **Plan**: Map Synapse components to Fabric equivalents (Pipelines to Fabric Data Factory, SQL pools to Fabric Warehouse, Spark to Fabric Data Engineering, Data Explorer to Real-Time Intelligence)
3. **Pilot**: Migrate non-critical workloads first using the migration assistants
4. **Validate**: Triggers are disabled post-migration by default -- validate pipeline behavior before re-enabling
5. **Evaluate cost model**: Fabric uses capacity units (CU) vs. Synapse pay-per-use; model costs before committing
6. **No urgency**: Synapse is not being retired -- migration can be planned strategically rather than reactively

## Research Sources

- Microsoft Learn: Synapse Analytics documentation, Data Factory documentation, Fabric migration guides
- Microsoft Fabric Blog: Migration assistant announcements, Fabric vs Synapse positioning
- Microsoft Tech Community: CI/CD patterns, performance tuning, troubleshooting guides
- Microsoft Q&A: Synapse retirement/continuity discussions
- Azure lifecycle pages: Component retirement announcements
