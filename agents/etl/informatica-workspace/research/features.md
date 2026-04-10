# Informatica IDMC Features

## Core Platform Services

### Cloud Data Integration (CDI)

**Mapping Designer:**
- Visual drag-and-drop interface for designing data integration mappings
- Source and target object configuration with schema discovery
- Transformation palette with 30+ built-in transformations
- Mapplet support for reusable transformation logic
- Parameterization for runtime-configurable mappings
- Dynamic mapping tasks for multi-source/target reuse from a single mapping asset
- Preview data at any transformation step during design

**Transformation Library:**
- Filter, Router, Joiner, Union, Sorter
- Expression, Aggregator, Normalizer
- Lookup (connected and unconnected)
- Sequence Generator
- Hierarchy Processor (XML, JSON, complex structures)
- Java Transformation (custom code)
- Python Transformation
- SQL Transformation
- Data Masking Transformation
- Web Services Transformation
- Rank Transformation

**Execution Modes:**
- Standard (Secure Agent-based)
- Elastic (Spark-based distributed processing)
- Advanced Serverless (fully managed)

### Cloud Data Quality (CDQ)

- Data profiling with pattern discovery and statistical analysis
- Rule-based cleansing with dictionaries and reference data
- Address standardization and validation
- Fuzzy matching and deduplication with configurable match strategies
- Data quality scorecards (validity, completeness, consistency, accuracy)
- Exception management for quality review workflows
- Data Quality Rules as API for real-time inline quality checks

### Cloud Application Integration (CAI)

- Process automation with visual process designer
- Service connector framework for application events
- Guided integration templates for common patterns
- Event-driven triggers (file arrival, schedule, API call, application event)
- Human task integration for approval workflows
- Error handling with fault suspension and notification

### API Manager

- Full API lifecycle management (create, publish, manage, monitor, deprecate)
- API gateway with authentication and throttling
- API versioning and backward compatibility management
- Usage analytics and performance monitoring
- Developer portal for API documentation and discovery

### Data Governance and Catalog (CDGC)

- AI-powered data catalog with natural language search
- Business glossary for standardized terminology
- Automated end-to-end data lineage via knowledge graphs
- Data marketplace for self-service data product access
- Data access management with policy-based controls
- Compliance and regulatory support (GDPR, CCPA, HIPAA)

### Master Data Management (MDM)

- Cloud-native MDM with golden record management
- Match and merge with configurable survivorship rules
- Hierarchy management for organizational structures
- Business entity services for master data APIs
- Stewardship workflows for data review and approval

---

## CLAIRE AI Features

### CLAIRE AI Engine (Core)

- **Metadata Intelligence**: Analyzes metadata patterns across the entire platform to drive automation
- **Auto-Mapping**: Suggests source-to-target field mappings based on metadata similarity, naming conventions, and usage patterns
- **Data Quality Suggestions**: Recommends cleansing rules, quality checks, and standardization approaches based on data profiling results
- **Anomaly Detection**: Identifies unusual patterns in data pipelines, quality metrics, and processing behavior
- **Auto-Tuning**: ML-based optimization of serverless job configurations for optimal performance
- **Intelligent Recommendations**: Cross-platform suggestions for transformations, connectors, and design patterns

### CLAIRE Copilot

- Proactive guidance embedded within developer workflows
- Context-aware suggestions during mapping design
- Best practice recommendations without switching tools
- Data quality rule suggestions based on profiling analysis
- Performance optimization hints during mapping configuration

### CLAIRE GPT

- Conversational AI for natural language data management
- Integrated with Azure OpenAI and Anthropic Claude LLMs
- Agentic data management with planning, reasoning, and natural language understanding
- Complex natural language queries on enterprise data
- Human oversight capabilities for validated AI responses
- Available to eligible IDMC customers at no additional cost through January 2027

### CLAIRE Agents (Fall 2025+)

- **Data Exploration Agents**: Natural language queries on MDM and enterprise data sources
- **Enterprise Discovery Agents**: Contextual, personalized data discovery across organizational data sources
- **ELT Agents**: Business users build pipelines collaboratively with data engineers
- **AI Agent Engineering** (Private Preview): No-code agent builder with test consoles, monitoring, full SDLC support, logging and observability

### Model Context Protocol (MCP) Support

- Build and manage MCP servers connecting to IDMC assets
- Enable external AI agents and LLMs to leverage IDMC tools and data
- Standards-based AI integration point

---

## Pushdown Optimization (ELT)

### Types

1. **Source-Side Pushdown**: Pushes transformation logic to source database, reducing data volume read
2. **Target-Side Pushdown**: Pushes logic to target database via INSERT/DELETE/UPDATE statements
3. **Full Pushdown**: Pushes all logic to target database; falls back to source-side if not fully possible; requires compatible source and target connections

### Supported Transformations for Pushdown

- Filter, Aggregator, Expression, Joiner, Sorter, Union
- Lookup (with restrictions on multiple match policies)
- Sequence Generator (requires temporary sequence creation)

### Advanced Configuration

- **Create Temporary View**: Enables SQL override queries in source/lookup transformations
- **Cross-Schema PDO**: Optimization across different schemas in the same database
- **User Incompatible Connections**: PDO when credentials differ but databases are compatible
- **Cross-Database PDO**: Optimization across separate database systems
- **Parameterized PDO**: Use $$PushdownConfig variable in parameter files

### Limitations

- Variable ports in Expression transformations not supported
- Database-specific functions may lack SQL equivalents
- Lookup transformations must use "Report Error" for multiple match policies
- SQL override queries require "Create Temporary View" enabled

---

## Real-Time and Streaming

### Change Data Capture (CDC)

- Log-based CDC for minimal source system impact
- Exactly-once database replication guarantees
- Support for initial load + incremental CDC patterns
- Automatic handling of schema drift (additions, modifications, deletions)
- Supported for major databases: Oracle, SQL Server, MySQL, PostgreSQL, DB2

### Streaming Ingestion

- Real-time ingestion from streaming and IoT endpoints
- Integration with Apache Kafka, Amazon Kinesis, Azure Event Hubs
- Format-agnostic data movement
- Kappa messaging architecture support
- SuperPipe technology for optimized streaming into Snowflake via Snowpipe Streaming

### Mass Ingestion

- Petabyte-scale bulk data movement
- Wizard-driven job creation for rapid deployment
- Batch, real-time, and CDC processing modes
- Multi-source ingestion (databases, applications, files, streaming)
- Multi-target delivery (warehouses, lakes, messaging hubs)

---

## iPaaS Capabilities

### B2B Integration

- Cloud-based partner onboarding
- EDI document processing and transformation
- Supply chain integration patterns
- B2B/B2C process automation

### Event-Driven Architecture

- File listener events for automated trigger
- Application event subscriptions
- Schedule-based execution
- REST/SOAP API triggers

### Process Automation

- BPMN-style process orchestration
- Human-in-the-loop task management
- Fault handling with suspension and notification
- Cross-application workflow coordination

### Microservices Orchestration

- Service connector framework
- API-first integration design
- Distributed process coordination
- Error propagation and compensation patterns

---

## Hierarchy Processing

- Parse and generate hierarchical data formats (XML, JSON, COBOL copybook, Avro, Parquet)
- Hierarchical schema definitions for complex nested structures
- Relational-to-hierarchical and hierarchical-to-relational transformations
- Business services for hierarchical data access patterns

---

## Enrichment and Validation (Summer 2025+)

- **Enrichment and Validation Orchestrator**: AI-powered framework automating validation and enrichment
- Orchestrates processing across Informatica services, third-party data sources, and LLMs
- Automated record validation workflows
- Multi-source enrichment pipeline coordination

---

## GenAI Connectors (Summer 2025+)

- NVIDIA NIM connector for GPU-accelerated AI inference
- Databricks Mosaic AI connector for enterprise ML models
- Snowflake Cortex AI connector for in-warehouse AI capabilities
- Standards-based MCP support for broad AI agent connectivity
