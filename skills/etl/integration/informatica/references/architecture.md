# Informatica IDMC Architecture Deep Dive

## Platform Overview

Informatica Intelligent Data Management Cloud (IDMC) is a comprehensive, AI-powered cloud-native platform for enterprise data management. It provides a unified metadata-driven architecture integrating data integration, quality, governance, and application integration under a single platform with a shared metadata foundation.

IDMC services are hosted across 20+ global Point of Delivery (PoD) locations on AWS, Azure, GCP, and Oracle Cloud. All services share a common metadata layer, enabling cross-service intelligence and lineage.

## Cloud Data Integration (CDI)

CDI is the primary ETL/ELT service within IDMC.

### Mapping Designer

- Visual drag-and-drop interface for designing data integration mappings
- Source and target object configuration with schema discovery
- Transformation palette with 30+ built-in transformations
- Preview data at any transformation step during design
- Parameterization for runtime-configurable mappings

### Transformation Library

| Category | Transformations |
|---|---|
| **Filtering/Routing** | Filter, Router |
| **Joining/Combining** | Joiner, Union |
| **Sorting** | Sorter |
| **Calculation** | Expression, Aggregator, Rank |
| **Normalization** | Normalizer |
| **Lookups** | Lookup (connected and unconnected) |
| **Key Generation** | Sequence Generator |
| **Hierarchical** | Hierarchy Processor (XML, JSON, complex structures) |
| **Custom Code** | Java Transformation, Python Transformation, SQL Transformation |
| **Security** | Data Masking Transformation |
| **Web Services** | Web Services Transformation |

### Execution Modes

| Mode | Runtime | Compute | Best For |
|---|---|---|---|
| **Standard** | Secure Agent | Single server | General ETL, on-prem sources |
| **Elastic** | CDI-Elastic (Spark) | Customer-managed Spark clusters | Large-scale distributed processing |
| **Advanced Serverless** | Informatica-managed | Fully serverless, auto-scaling to zero | Cloud-to-cloud, no infra management |

### Mapplets

Mapplets encapsulate reusable transformation logic:
- Defined with Input and Output transformations for clear interfaces
- Can be nested (non-cyclically) within other mapplets and mappings
- Parameterizable for maximum reusability across configurations
- Versioned independently from consuming mappings
- Shared across multiple mappings within a project

### Dynamic Mapping Tasks

Reduce asset proliferation by defining multiple jobs with different source/target configurations within a single parameterized mapping. Adding a new source becomes a parameter change, not a new mapping.

### Parameterization

- **Input parameters**: Connection objects, source/target objects, filter conditions, join expressions
- **In-out parameters**: Bidirectional values for incremental processing state
- **Parameter files**: Centralized parameter management for batch execution
- **$$PushdownConfig**: Environment-specific pushdown optimization configuration
- **Connection parameterization**: Same mapping runs against different environments (dev/test/prod)

## Pushdown Optimization (ELT)

Pushdown converts transformation logic to SQL and pushes execution to the database engine, avoiding data movement to the Secure Agent.

### Pushdown Modes

| Mode | Behavior | When to Use |
|---|---|---|
| **Source-Side** | Pushes logic to source database; reduces data volume read from source | Filters, aggregations that reduce data before transfer |
| **Target-Side** | Pushes logic to target database via INSERT/DELETE/UPDATE | Complex transforms expressible in target SQL |
| **Full Pushdown** | All logic pushed to target; falls back to source-side if partial | Source and target on same database platform |

### Supported Transformations

Filter, Aggregator, Expression, Joiner, Sorter, Union, Lookup (with restrictions on multiple match policies), Sequence Generator (requires temporary sequence creation).

### Advanced Configuration

- **Create Temporary View**: Enables SQL override queries in source/lookup transformations
- **Cross-Schema PDO**: Optimization across different schemas in the same database
- **User Incompatible Connections**: PDO when credentials differ but databases are compatible
- **Cross-Database PDO**: Optimization across separate database systems

### Limitations

- Variable ports in Expression transformations not supported for pushdown
- Database-specific functions may lack SQL equivalents (falls back to in-memory)
- Lookup transformations must use "Report Error" for multiple match policies
- SQL override queries require "Create Temporary View" enabled
- Null Comparison on Lookups degrades pushdown performance with multiple lookups

## Secure Agent Architecture

### Core Design

The Secure Agent is a lightweight program installed on customer infrastructure (Windows or Linux) that bridges IDMC cloud services with local data sources.

**Communication model**: Outbound HTTPS only (port 443) from agent to IDMC cloud endpoints. No inbound ports required. Data encryption via 128-bit SSL.

### Agent Microservices

| Service | Purpose |
|---|---|
| **Data Integration Server** | Executes mapping tasks |
| **Common Integration Components** | Shared runtime libraries |
| **Metadata Agent Service** | Collects and sends metadata to cloud |
| **Process Server** | Executes application integration processes |
| **Mass Ingestion Service** | Handles bulk data movement and CDC |
| **API Gateway Agent** | Local API management proxy |

### Secure Agent Groups

Groups provide workload distribution and isolation:
- **Department isolation**: Separate groups prevent cross-department performance impact
- **Environment separation**: Distinct groups for test vs production
- **HA**: Multiple agents in a group provide failover capability
- **Service management**: Enable/disable specific services and connectors per group
- **Limitation**: Mapping tasks in advanced mode require single-agent groups

### High Availability and Disaster Recovery

- **HA via Agent Groups**: Multiple agents in a group. If one agent fails, work is routed to healthy agents.
- **DR Pattern**: Replicate full data center structure to DR site; create agent groups spanning primary and backup sites
- **Failover**: When primary site fails, backup VMs activate in DR data center
- **Configuration sync**: Non-cloud-managed configurations must be manually synchronized between primary and secondary sites

## Serverless Runtime

### Standard Serverless

- Informatica-managed compute for lightweight tasks
- No Secure Agent installation required
- Suitable for simple cloud-to-cloud integrations

### Advanced Serverless

- Fully managed serverless deployment on customer's cloud infrastructure
- **Architecture**: Informatica provisions an INFA DMZ adjacent to customer VPC in the same availability zone; connected via tenant-controlled Elastic Network Interfaces (ENIs)
- **Auto-scaling**: Resources scale up for new jobs and down to zero during idle
- **Auto-tuning**: CLAIRE ML engine optimizes job performance automatically
- **Consumption-based pricing**: Pay only for compute consumed; no idle costs

**Prerequisites** (AWS):
- VPC with default tenancy
- IAM role with cross-account trust to Informatica
- Security groups for traffic management
- Private subnet for ENI placement
- Optional S3 bucket for supplementary files

**Azure support**: Added recently, expanding parity with AWS deployment.

## CLAIRE AI Engine

CLAIRE (Cloud-scale AI for Real-time Execution) is Informatica's proprietary AI engine embedded across all IDMC services.

### Three AI Tiers

1. **CLAIRE AI Engine** (Core ML): Metadata intelligence, auto-mapping, data quality suggestions, anomaly detection, auto-tuning for serverless optimization
2. **CLAIRE Copilot**: Proactive guidance in developer workflows, context-aware mapping suggestions, best practice recommendations, performance hints
3. **CLAIRE GPT**: Conversational AI for natural language data management, integrated with Azure OpenAI and Anthropic Claude LLMs, agentic data management with planning and reasoning

### CLAIRE Agents (Fall 2025+)

- **Data Exploration Agents**: Complex natural language queries on MDM and enterprise data
- **Enterprise Discovery Agents**: Contextual, personalized data discovery across organizational data sources
- **ELT Agents**: Business users build pipelines collaboratively with data engineers
- **AI Agent Engineering** (Private Preview): No-code interface for building custom Informatica agents with test consoles, monitoring, SDLC support

### Model Context Protocol (MCP) Support (Summer 2025+)

- Build and manage MCP servers connecting to IDMC assets
- Enable external AI agents and LLMs to leverage IDMC tools and data
- Standards-based AI integration point

## Taskflow Orchestration

### Taskflow Types

| Type | Parallel Execution | Decision Logic | Recovery from Failure | Use Case |
|---|---|---|---|---|
| **Standard** | Yes | Yes | Resume from failure point | Production workflows |
| **Linear** | No | No | Full restart required | Simple sequential flows |

### Step Types (13 Total)

| Step | Purpose |
|---|---|
| **Assignment** | Set field values (like Expression transformation) |
| **Data Task** | Run mapping, sync, or PowerCenter tasks |
| **Notification Task** | Send email with execution metrics |
| **Command Task** | Execute shell scripts/batch commands on agent |
| **File Watch Task** | Monitor file events in specified locations |
| **Ingestion Task** | Trigger file ingestion operations |
| **Subtaskflow** | Embed and reuse existing taskflows |
| **Decision** | Route execution based on conditions |
| **Parallel Paths** | Execute multiple items simultaneously |
| **Jump** | Redirect execution flow (looping) |
| **Wait** | Pause execution for specified duration |
| **Throw** | Catch faults and terminate execution |
| **End** | Define HTTP status codes for completion |

### Publishing Options

- **REST/SOAP Binding**: Publish taskflows as APIs with access controls
- **Event Binding**: Trigger on file arrival events
- **Schedule Binding**: Automated periodic execution

## Additional Platform Services

### Cloud Data Quality (CDQ)

Data profiling, cleansing, standardization, fuzzy matching and deduplication, quality scorecards (validity, completeness, consistency, accuracy), exception management, and Data Quality Rules as API for real-time inline checks.

### Cloud Data Governance and Catalog (CDGC)

AI-powered data catalog, business glossary, automated end-to-end lineage via knowledge graphs (Amazon Neptune), data marketplace, data access management, compliance support (GDPR, CCPA, HIPAA).

### Master Data Management (MDM)

Cloud-native MDM with golden record management, match and merge with survivorship rules, hierarchy management, business entity services, and stewardship workflows.

### Mass Ingestion and CDC

- **Bulk data movement**: Petabyte-scale ingestion and replication
- **CDC**: Log-based capture with exactly-once database replication guarantees
- **Streaming ingestion**: Real-time from Kafka, Kinesis, Event Hubs
- **Schema drift handling**: Automatic detection and adaptation to source schema changes
- **SuperPipe**: Optimized streaming into Snowflake via Snowpipe Streaming

### Cloud Application Integration (CAI)

Process automation with visual designer, service connector framework, event-driven triggers, human task integration, fault handling, B2B integration with EDI processing.

## Deployment and Pricing

### Informatica Processing Units (IPU)

- Unified consumption-based pricing metric across all IDMC services
- 100% usage-based pricing
- Flexibility to reallocate compute across services as needs evolve

### Environment Patterns

- **Development/Test/Production**: Separate environments with distinct runtime configurations
- **CI/CD**: Integration with Git (GitHub, Azure DevOps, BitBucket, GitLab) via Source Control REST APIs
- **Migration**: Informatica Migration Factory for automated PowerCenter-to-IDMC conversion

### Global Infrastructure

- 20+ global PoD locations
- Multi-cloud: AWS, Azure, GCP, Oracle Cloud
- Regional data residency compliance
