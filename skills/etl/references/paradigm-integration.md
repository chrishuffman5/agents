# Paradigm: Data Integration / EL (Extract-Load)

When and why to choose integration and data movement tools. This file covers the paradigm itself, not specific engines -- see technology agents for engine-specific guidance.

## Choose Managed EL (Fivetran, Airbyte) When

- **Replicating SaaS sources.** Salesforce, HubSpot, Stripe, Google Analytics -- managed connectors handle API pagination, rate limiting, schema changes, and authentication. Building this yourself is expensive to maintain.
- **Team wants zero connector maintenance.** Managed EL tools update connectors when APIs change. Self-built connectors break on every upstream API change.
- **Speed to value matters.** A Fivetran connector can replicate a SaaS source to Snowflake in minutes. Building the equivalent with ADF or NiFi takes days to weeks.

## Choose Visual Pipeline Tools (ADF, NiFi, Informatica, Talend) When

- **Complex data movement with conditional logic.** Routing records based on content, splitting flows, handling errors per record, enriching during movement.
- **Enterprise governance and audit are required.** NiFi's data provenance tracks every byte. Informatica provides metadata management and lineage. ADF integrates with Purview.
- **Hybrid environments.** On-premises sources (mainframe, file shares, legacy databases) connecting to cloud targets. ADF Integration Runtime and NiFi site-to-site handle hybrid connectivity.
- **Non-developer users need to build pipelines.** Visual tools lower the barrier for analysts and data stewards to create data movement workflows.

## Choose Code-First Integration (AWS Glue, Custom Spark/Python) When

- **Maximum flexibility and control.** Custom extraction logic, complex API interactions, non-standard data formats.
- **Deep cloud-native integration is needed.** AWS Glue integrates natively with S3, Redshift, Athena, Lake Formation. ADF integrates natively with the Azure ecosystem.
- **Cost optimization at scale.** Managed EL tools charge per row or per connector. At high volumes, code-first may be cheaper despite development cost.

## Avoid Each When

| Tool | Avoid When |
|---|---|
| **Fivetran / managed EL** | Custom sources with no pre-built connector, complex transformation needed during movement, cost per row is prohibitive at scale |
| **ADF / visual pipelines** | Simple source-to-warehouse replication (managed EL is faster), team prefers code over visual, non-Azure environment (ADF is Azure-specific) |
| **NiFi** | Small team without Java/JVM operational expertise, simple batch loads (NiFi's strength is flow-based routing, not batch ETL) |
| **Informatica** | Greenfield cloud-native project (cost and complexity are enterprise-grade), small to mid-sized data volumes |
| **Talend** | New projects (Qlik acquisition creates platform uncertainty), team without Java skills for custom components |
| **AWS Glue** | Non-AWS environment, need for real-time processing (Glue is batch-oriented), small datasets (cold start latency is 1-2 minutes) |

## Technology Comparison

| Dimension | Fivetran | ADF | NiFi | Informatica | AWS Glue | Synapse Pipelines |
|---|---|---|---|---|---|---|
| **Model** | Managed EL | Visual pipelines | Flow-based routing | Visual mapping | Spark-based serverless | ADF-based + Spark pools |
| **Hosting** | Fully managed | Azure-managed | Self-hosted | Cloud/on-prem | AWS-managed | Azure-managed |
| **Connectors** | 500+ pre-built | 100+ linked services | 300+ processors | 500+ | AWS ecosystem + JDBC | ADF connectors |
| **Customization** | Low (pre-built only) | Medium (expressions, data flows) | High (custom processors) | High (custom mappings) | High (PySpark/Scala) | Medium (ADF subset) |
| **Cost model** | Per-row MAR | Per-activity run + DIU | Infrastructure only | Per-compute hour | Per-DPU hour | Per-activity + pool |
| **Best For** | SaaS-to-warehouse | Azure ecosystem | Regulated industries | Enterprise MDM | AWS-native ETL | Synapse unified analytics |

## Common Patterns

1. **EL + T**: Use a managed EL tool (Fivetran) for extraction and loading, paired with dbt for transformation. The dominant modern data stack pattern.
2. **Hybrid integration runtime**: ADF's self-hosted IR or NiFi's site-to-site protocol for connecting on-premises sources to cloud destinations without VPN complexity.
3. **Schema drift handling**: ADF mapping data flows and Fivetran handle new columns automatically. NiFi's schema-less FlowFile model absorbs changes. Informatica uses schema-on-read.
4. **Connector multiplexing**: Use a specialized EL tool for SaaS sources, a visual pipeline tool for database-to-database movement, and custom code for niche sources. Don't force one tool to do everything.

## Anti-Patterns

1. **Building custom connectors for SaaS sources** -- Maintaining API integrations for Salesforce, HubSpot, or Stripe in-house. Managed EL tools amortize this maintenance across thousands of customers.
2. **Using ADF for transformation** -- ADF data flows are limited and expensive compared to dbt or Spark. Use ADF for movement, dbt for transformation.
3. **NiFi for batch-only workloads** -- NiFi excels at flow-based, record-by-record routing with provenance. For simple batch file copies, a scheduled ADF pipeline or cron + rclone is simpler.
4. **Ignoring connector costs at scale** -- Fivetran's per-row pricing is economical for low volumes but expensive at hundreds of millions of rows per month. Model costs before committing.

## Integration Architecture Patterns

### Hub-and-Spoke

A central integration platform (ADF, Informatica) connects all sources to all targets through a central hub. All data passes through the hub.

- **Pros**: Centralized monitoring, single point of governance, consistent error handling
- **Cons**: Hub is a bottleneck and single point of failure, all traffic routes through one platform
- **Best for**: Enterprise data warehousing, centralized data teams

### Point-to-Point (Specialized Tools)

Each source-target pair uses the best tool for that specific integration. Fivetran for SaaS sources, ADF for Azure databases, custom Python for APIs.

- **Pros**: Best tool for each job, no forced compromise, teams choose their own tools
- **Cons**: Tool sprawl, inconsistent monitoring, fragmented governance
- **Best for**: Decentralized data teams, modern data stack, domain-oriented architectures

### Event-Driven (Kafka-Centric)

All sources publish to Kafka topics. Consumers read from Kafka independently. No direct source-to-target coupling.

- **Pros**: Decoupled producers and consumers, replay capability, multiple consumers per source
- **Cons**: Kafka operational complexity, not suited for batch-oriented sources, requires event modeling
- **Best for**: Microservice architectures, real-time analytics, CDC-centric pipelines

## Cost Modeling Considerations

| Tool | Cost Driver | Watch Out For |
|---|---|---|
| **Fivetran** | Monthly Active Rows (MAR) | High-churn tables (every row updated monthly = full table MAR) |
| **ADF** | Activity runs + DIUs + data flow cluster hours | Data flows are 10-50x more expensive than copy activities |
| **AWS Glue** | DPU-hours (1 DPU = 4 vCPU, 16 GB) | Minimum 2 DPUs, 1-2 minute cold start even for small jobs |
| **NiFi** | Infrastructure (VMs, storage) | JVM heap sizing, NiFi Content Repository disk I/O |
| **Informatica** | IPU (Informatica Processing Units) per hour | IPU consumption varies by task type (mapping vs MDM vs quality) |
