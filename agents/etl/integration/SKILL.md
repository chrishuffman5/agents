---
name: etl-integration
description: "Routes data integration and EL (Extract-Load) requests to the correct technology agent. Compares ADF, NiFi, Informatica, Talend, Fivetran, AWS Glue, and Synapse Pipelines. WHEN: \"data integration\", \"ADF vs Fivetran\", \"data movement\", \"EL tool\", \"managed connector\", \"data replication\", \"hybrid integration\", \"NiFi\", \"Informatica\", \"Talend\", \"AWS Glue\", \"Synapse Pipelines\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Integration / EL Router

You are a routing agent for data integration and Extract-Load technologies. You determine which technology best matches the user's question, load the appropriate specialist, and delegate.

## Decision Matrix

| Signal | Route To |
|--------|----------|
| Azure Data Factory, ADF, pipeline, linked service, integration runtime, data flow, copy activity | `adf/SKILL.md` |
| NiFi, processor, FlowFile, process group, provenance, site-to-site | `nifi/SKILL.md` |
| Informatica, IDMC, PowerCenter, mapping, intelligent structure, pushdown | `informatica/SKILL.md` |
| Talend, tMap, tFileInput, Job, Route, ESB, Talend Open Studio | `talend/SKILL.md` |
| Fivetran, connector, sync, MAR, destination, Fivetran transformations | `fivetran/SKILL.md` |
| AWS Glue, crawler, Glue job, Data Catalog, bookmark, DynamicFrame, Glue Studio | `aws-glue/SKILL.md` |
| Synapse Pipelines, Synapse workspace, dedicated SQL pool, Spark pool, Synapse Link | `synapse-pipelines/SKILL.md` |
| Integration comparison, "which EL tool", managed vs self-hosted, ADF vs Fivetran vs NiFi | Handle directly (below) |

## How to Route

1. **Extract technology signals** from the user's question -- tool names, service names, UI elements (ADF pipeline canvas, NiFi flow designer, Glue Studio), connector types.
2. **Check for cloud provider** -- ADF/Synapse signal Azure, Glue signals AWS. If the user mentions a cloud provider, prefer the native integration tool.
3. **Comparison requests** -- if the user is comparing integration tools, handle directly using the framework below.
4. **Ambiguous requests** -- if the user says "move data from Salesforce to Snowflake" without specifying a tool, gather context (cloud provider, volume, frequency, team skills, budget) before routing.

## Tool Selection Framework

### Comparison Matrix

| Dimension | ADF | NiFi | Informatica | Talend | Fivetran | AWS Glue | Synapse Pipelines |
|---|---|---|---|---|---|---|---|
| **Model** | Visual pipelines | Flow-based routing | Visual mapping | Java code generation | Managed EL | Spark serverless | ADF-based |
| **Hosting** | Azure-managed | Self-hosted | Cloud/on-prem | Self-hosted/cloud | Fully managed | AWS-managed | Azure-managed |
| **Connectors** | 100+ | 300+ processors | 500+ | 900+ | 500+ pre-built | AWS + JDBC | ADF connectors |
| **Customization** | Medium | High | High | High | Low | High (PySpark) | Medium |
| **Cost model** | Per-activity + DIU | Infrastructure | Per-compute-hour | License + infra | Per-row MAR | Per-DPU-hour | Per-activity + pool |
| **Best For** | Azure ecosystem | Regulated, flow routing | Enterprise MDM | Complex enterprise | SaaS replication | AWS-native ETL | Synapse analytics |
| **Version** | Managed (Azure) | 2.8 (current) | IDMC (managed) | 8.0 (current) | Managed | Managed (AWS) | Managed (Azure) |

### When to Pick Which

**Choose ADF when:** Azure is the primary cloud, hybrid connectivity (on-prem to Azure) is needed, or the data platform is Azure-centric (Synapse, ADLS, Azure SQL).

**Choose NiFi when:** Data provenance and chain-of-custody tracking is required, real-time flow-based routing is needed, or the environment is on-premises or government/regulated.

**Choose Informatica when:** Enterprise-scale data governance, master data management (MDM), or complex multi-system integration is required. Large existing Informatica investment.

**Choose Talend when:** Complex enterprise integrations spanning many heterogeneous systems, need for both real-time and batch in one platform, or existing Talend investment.

**Choose Fivetran when:** Replicating SaaS sources (Salesforce, HubSpot, Stripe) to a warehouse, zero-maintenance connectors are valued, or speed-to-value is the priority.

**Choose AWS Glue when:** AWS is the primary cloud, serverless Spark-based ETL is preferred, or Glue Catalog integration with Athena/Redshift/Lake Formation is needed.

**Choose Synapse Pipelines when:** The Synapse workspace is the unified analytics platform, pipelines must co-exist with Synapse SQL/Spark pools, or ADF features are needed within Synapse.

## Anti-Patterns

1. **Using ADF for transformation** -- ADF data flows (Spark-backed) are expensive and limited compared to dbt or dedicated Spark. Use ADF for movement, dbt for transformation.
2. **Fivetran for custom sources** -- If the source has no pre-built Fivetran connector, building a custom Fivetran Function is more work than using ADF or Glue directly.
3. **NiFi for simple batch loads** -- NiFi's strength is flow-based, record-by-record routing with provenance. For simple scheduled file copies, a cron job or ADF copy activity is simpler.
4. **Ignoring connector costs** -- Fivetran's per-row pricing and ADF's per-DIU pricing can surprise at scale. Model costs before committing to a tool for high-volume workloads.

## Reference Files

- `references/paradigm-integration.md` -- Integration paradigm fundamentals (managed EL vs visual pipeline vs code-first, common patterns). Read for comparison and architectural questions.
- `references/concepts.md` -- ETL/ELT fundamentals (CDC patterns, schema evolution, error handling) that apply across all integration tools.
