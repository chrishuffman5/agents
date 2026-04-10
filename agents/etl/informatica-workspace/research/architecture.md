# Informatica IDMC Architecture

## Platform Overview

Informatica Intelligent Data Management Cloud (IDMC) is a comprehensive, AI-powered cloud-native platform for enterprise data management. It provides a unified metadata-driven architecture that integrates data integration, quality, governance, and application integration services under a single platform with a shared metadata foundation.

IDMC services are hosted across 20+ global Point of Delivery (PoD) locations on AWS, Azure, GCP, and Oracle Cloud.

---

## Core Services

### Cloud Data Integration (CDI)

CDI is the primary ETL/ELT service within IDMC. It provides:

- **Mapping Designer**: Visual drag-and-drop interface for building data integration mappings
- **Sources and Targets**: Connect to databases, files, applications, cloud storage, streaming endpoints
- **Transformations**: Built-in transformation library (Filter, Joiner, Aggregator, Expression, Lookup, Router, Sorter, Union, Normalizer, Hierarchy, Sequence Generator, etc.)
- **Mapplets**: Reusable transformation logic encapsulated with Input/Output transformations; can be nested (non-cyclically) and used across multiple mappings
- **Parameterization**: Runtime-configurable placeholders for connections, objects, join conditions, filter expressions, and other mapping logic; supports input parameters and in-out parameters
- **Dynamic Mapping Tasks**: Reduce asset proliferation by defining multiple jobs with different source/target configurations within a single parameterized mapping
- **Pushdown Optimization (ELT)**: Converts transformation logic to SQL and pushes execution to source, target, or both database engines
- **CDI-Elastic**: Customer-managed auto-scaling Spark clusters for large-scale processing
- **Advanced Serverless**: Fully Informatica-managed serverless compute with auto-scaling and auto-tuning

### Cloud Data Quality (CDQ)

CDQ provides integrated data quality capabilities:

- **Data Profiling**: Iterative analysis to understand data health, patterns, distributions, and anomalies
- **Data Cleansing**: Remove spaces, standardize cases, replace values using dictionaries and prebuilt rules
- **Standardization**: Normalize data formats, addresses, names, and business terms
- **Matching and Deduplication**: Fuzzy matching algorithms to identify and group duplicate records into clusters even when records are not exactly alike
- **Data Quality Scorecards**: Measure quality across dimensions (validity, completeness, consistency, accuracy)
- **Data Quality Rules as API**: Real-time quality checks via REST APIs for inline data assessment, cleansing, and enrichment

### Cloud Application Integration (CAI)

CAI provides iPaaS capabilities for application and process integration:

- **Process Designer**: Visual process orchestration with BPMN-style workflows
- **Service Connectors**: Pre-built connectors for SaaS applications and on-premises systems
- **Event-Driven Architecture**: Trigger integrations based on application events, file arrival, or scheduled triggers
- **B2B/B2C Integration**: Partner onboarding, EDI processing, and supply chain integration
- **Microservices Orchestration**: Coordinate distributed services and business processes

### API Manager

Full API lifecycle management within IDMC:

- **API Development**: Create, version, and publish APIs
- **API Gateway**: Secure API exposure with authentication, throttling, and access control
- **API Monitoring**: Usage analytics, performance metrics, and health monitoring
- **API Deprecation**: Managed lifecycle from creation through retirement
- **Multi-cloud Access**: APIs span across cloud and on-premises systems

### Data Governance and Catalog (CDGC)

- **Data Catalog**: Centralized repository of all data assets with AI-powered search and discovery
- **Metadata Management**: Augments technical metadata with business context, human knowledge, and AI-generated insights
- **Data Lineage**: Automated end-to-end lineage tracking from source to target using knowledge graphs (Amazon Neptune)
- **Data Marketplace**: Self-service data product discovery with governed access request workflows
- **Data Access Management**: Policy-based access control and compliance enforcement

### Mass Ingestion (Cloud Data Ingestion and Replication)

- **Bulk Data Movement**: Ingest and replicate petabytes of data from databases, files, applications, and streaming sources
- **CDC (Change Data Capture)**: Log-based capture with exactly-once database replication
- **Streaming Ingestion**: Collect, filter, combine, and ingest from streaming and IoT endpoints
- **Schema Drift Handling**: Automatic detection and handling of source schema changes
- **Wizard-Driven Configuration**: Simplified ingestion job creation
- **Supported Sources**: Oracle, SQL Server, MySQL, Salesforce, SAP ECC, Dynamics 365, files, streaming/IoT
- **Supported Targets**: Cloud warehouses (Snowflake, Redshift, BigQuery, Synapse), data lakes, messaging hubs

---

## CLAIRE AI Engine

CLAIRE (Cloud-scale AI for Real-time Execution) is Informatica's proprietary AI engine embedded across IDMC. It operates on deep metadata insights to drive intelligent automation.

### Three AI Tiers

1. **CLAIRE AI Engine**: Core machine learning layer that applies metadata intelligence for automation, recommendations, and anomaly detection
2. **CLAIRE Copilot**: Assistive AI integrated directly into developer workflows providing proactive guidance, auto-mapping suggestions, and data quality recommendations
3. **CLAIRE GPT**: Conversational AI enabling natural language interaction with data management tasks; integrated with Azure OpenAI and Anthropic Claude LLMs

### CLAIRE Agents (Fall 2025+)

- **CLAIRE Data Exploration Agents**: Complex natural language queries on MDM and enterprise data
- **CLAIRE Enterprise Discovery Agents**: Contextual search across organizational data sources for personalized data discovery
- **CLAIRE ELT Agents**: Enable business users to build data pipelines collaboratively with data engineers
- **AI Agent Engineering**: No-code interface for building custom Informatica agents with test consoles, monitoring, SDLC support, and observability

### Key CLAIRE Capabilities

- **Auto-Mapping**: AI-suggested field mappings based on metadata analysis
- **Data Quality Suggestions**: Automated recommendations for cleansing rules and quality improvements
- **Anomaly Detection**: Proactive identification of data quality issues and pipeline anomalies
- **Match Analysis and Explainability**: Transparent matching with self-service tuning
- **Auto-Tuning**: ML-based optimization of serverless job performance
- **Model Context Protocol (MCP)**: Connect AI agents and LLMs to IDMC assets as tools

### Business Impact (Informatica-reported)

- 70% faster decision-making
- 50% lower data security risk
- 51,870+ user hours saved annually

---

## Secure Agent Architecture

The Secure Agent is a lightweight program installed on-premises or in customer-managed cloud VMs that bridges IDMC cloud services with local data sources.

### Core Functions

- Runs data integration tasks locally
- Collects metadata for IDMC cloud services
- Enables secure, encrypted communication between IDMC and on-premises/cloud data sources
- Supports both Linux and Windows operating systems

### Agent Services

The Secure Agent runs multiple microservices:

- **Data Integration Server**: Executes mapping tasks
- **Common Integration Components**: Shared runtime libraries
- **Metadata Agent Service**: Collects and sends metadata to cloud
- **Process Server**: Executes application integration processes
- **Mass Ingestion Service**: Handles bulk data movement
- **API Gateway Agent**: Local API management proxy

### Secure Agent Groups

- Groups contain multiple agents for workload distribution
- **Department Isolation**: Separate groups prevent cross-department performance impact
- **Environment Separation**: Distinct groups for test vs. production
- **Permissions**: Groups can be shared with sub-organizations; all org users can select groups as runtime environments
- **Service Management**: Enable/disable specific services and connectors per group
- **Limitation**: Mapping tasks in advanced mode require single-agent groups

### High Availability and Disaster Recovery

- **HA via Agent Groups**: Multiple agents in a group provide failover capability
- **DR Pattern**: Replicate full data center structure to DR site; create agent groups spanning primary and backup sites
- **Failover**: When primary site fails, backup VMs activate in DR data center
- **Configuration Sync**: Non-cloud-managed configurations must be manually synchronized between primary and secondary sites

---

## Serverless Runtime

### Standard Serverless

- Informatica-managed compute for lightweight tasks
- No Secure Agent installation required
- Suitable for cloud-to-cloud integrations

### Advanced Serverless

- Fully managed serverless deployment on customer's cloud infrastructure
- **Architecture**: Informatica provisions an INFA DMZ adjacent to customer VPC in the same availability zone; connected via tenant-controlled Elastic Network Interfaces (ENIs)
- **Auto-Scaling**: Resources scale up for new jobs and down to zero during idle time
- **Auto-Tuning**: CLAIRE ML engine optimizes job performance automatically
- **Consumption-Based Pricing**: Pay only for compute consumed; no idle costs

**Prerequisites:**
- AWS VPC with default tenancy (Azure support added recently)
- IAM role with cross-account trust to Informatica
- Security groups for traffic management
- Private subnet for ENI placement
- Optional S3 bucket for supplementary files

**Comparison:**

| Aspect | CDI (Secure Agent) | CDI-Elastic | Advanced Serverless |
|--------|-------------------|-------------|-------------------|
| Infrastructure | Customer-managed | Customer-managed clusters | Informatica-managed |
| Agent Management | Manual install/config | Manual | Eliminated |
| Compute Model | Single server | Auto-scaling Spark clusters | Fully serverless |
| Scaling | Manual | Auto-scaling | Auto-scaling to zero |
| Maintenance | Customer responsibility | Customer responsibility | Informatica responsibility |

---

## Connectivity

### Connector Ecosystem

- **300+ native connectors** with built-in governance
- **10,000+ metadata-aware connectors** across cloud ecosystems (AWS, Azure, GCP)
- **Informatica Marketplace**: Community and partner-built connectors and templates
- **GenAI Connectors**: NVIDIA NIM, Databricks Mosaic AI, Snowflake Cortex AI

### Connection Categories

- Relational databases (Oracle, SQL Server, PostgreSQL, MySQL, DB2, etc.)
- Cloud data warehouses (Snowflake, Redshift, BigQuery, Azure Synapse)
- Cloud storage (S3, Azure Blob, GCS)
- SaaS applications (Salesforce, SAP, Workday, ServiceNow, NetSuite)
- Messaging/streaming (Kafka, Amazon Kinesis, Azure Event Hubs)
- Files (flat files, XML, JSON, Parquet, Avro, ORC)
- APIs (REST, SOAP, OData)

---

## Deployment Model

### Informatica Processing Units (IPU)

- Unified consumption-based pricing metric across all IDMC services
- 100% usage-based pricing
- Provides flexibility to reallocate compute across services as needs evolve

### Environment Patterns

- **Development/Test/Production**: Separate environments with distinct runtime configurations
- **CI/CD**: Integration with Git tools (GitHub, Azure DevOps, BitBucket, GitLab) via Source Control REST APIs
- **Migration**: Informatica Migration Factory for automated PowerCenter-to-IDMC conversion

### Global Infrastructure

- 20+ global PoD locations
- Multi-cloud support (AWS, Azure, GCP, Oracle Cloud)
- Regional data residency compliance
