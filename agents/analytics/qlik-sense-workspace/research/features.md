# Qlik Sense Features and Capabilities

## Core Analytics Capabilities

### Associative Exploration

The defining feature of Qlik Sense is its associative model. Users can click any data point in any visualization, and the entire app instantly recalculates to show related (white), selected (green), and excluded (gray) values across all fields. There are no predefined drill paths, hierarchies, or query boundaries.

### Visualization Library

Qlik Sense ships with a comprehensive set of native chart types:

| Category | Chart Types |
|----------|-------------|
| **Comparison** | Bar chart, combo chart, bullet chart, Mekko chart |
| **Trend** | Line chart, area chart, sparkline |
| **Composition** | Pie chart, treemap, stacked bar |
| **Relationship** | Scatter plot, network chart, Sankey diagram |
| **Distribution** | Histogram, box plot, distribution plot |
| **Geo** | Map (point, area, line, density, drill-down layers) |
| **Tabular** | Table, pivot table, straight table |
| **KPI** | KPI object, gauge, text & image |
| **Filter** | Filter pane, list box, slider |
| **Container** | Container, trellis container, tabs container |

### Smart Search

Global search across all fields in the data model using natural language. The search engine evaluates input against every loaded field and returns associated results, enabling users to find patterns without knowing the data structure.

### Bookmarks and Selections

Users can save selection states as bookmarks, apply alternate states for comparative analysis, and use the selection bar to review and modify current selections at any time.

### Responsive Design

Sheets use a responsive grid layout that automatically adapts to different screen sizes. A dedicated mobile view mode allows authors to define custom layouts for phone and tablet consumption.

## AI and Augmented Analytics

### Insight Advisor

Insight Advisor is Qlik's AI-powered analytics assistant with three modes:

- **Search-Based Visual Discovery**: Users type natural language questions and Insight Advisor auto-generates the most relevant visualizations using NLP and the precedents learning model.
- **Insight Advisor Chat**: Conversational analytics interface where users interact with data through natural language dialogue. Supports follow-up questions, context retention, and interactive chart exploration.
- **Associative Insights**: Automated analysis that identifies statistically significant patterns, outliers, and correlations in the data model without user prompting.

Insight Advisor learns from user behavior and a business logic layer, which allows administrators to define field classifications (dimensions, measures, dates), preferred aggregations, default calendar periods, and field relationships to improve suggestion quality.

### Qlik Answers (Agentic AI)

Qlik Answers is the newest AI capability (generally available 2025-2026), representing Qlik's move into agentic analytics:

- **Agentic Reasoning**: Breaks down complex, multi-step questions and executes them using AI reasoning paired with the Qlik analytics engine.
- **Structured + Unstructured Data**: Combines insights from Qlik analytics apps with unstructured content (documents, knowledge bases) in a single conversational interface.
- **Discovery Agent**: Generally available as of March 2026, enabling autonomous data exploration and pattern identification.
- **Governed Responses**: All answers include citations and trace back to source data, maintaining trust and explainability.
- **Embeddable**: Available within the Qlik platform and as embeddable customer-built assistants.
- **MCP Integration**: Qlik Answers supports Model Context Protocol (MCP), opening Qlik to third-party AI assistants.

### Qlik Predict (Formerly AutoML)

Qlik Predict provides automated machine learning for analytics teams:

- **Automated Model Training**: Supports classification and regression models with automated feature engineering, model selection, and hyperparameter tuning.
- **Experiment Management**: Track and compare model runs, evaluate feature importance, and select the best-performing model.
- **Predictive Analytics**: Apply trained models to new data directly within Qlik apps for scoring and scenario analysis.
- **No-Code Interface**: Designed for business analysts rather than data scientists; point-and-click model building workflow.
- **Integration with Analytics**: Prediction results flow directly into Qlik visualizations and can be used in set analysis expressions.

## Data Integration and Movement

### Qlik Talend Cloud

Following Qlik's acquisition of Talend, the combined platform provides end-to-end data integration:

- **ELT/ETL Pipelines**: Visual pipeline designer for data transformation and loading across cloud and on-premise sources.
- **Change Data Capture (CDC)**: Real-time data replication from source databases (Oracle, SQL Server, SAP, etc.) to cloud targets with minimal source impact.
- **Data Quality**: Profiling, cleansing, matching, and enrichment capabilities inherited from Talend.
- **Data Catalog and Governance**: Metadata management, data lineage, and trust scoring for data assets.
- **Open Lakehouse**: Fully managed Apache Iceberg solution built into Qlik Talend Cloud for real-time ingestion, automated optimization, and multi-engine interoperability (announced 2025).

**Supported Targets:**
- Cloud data warehouses: Snowflake, Google BigQuery, Azure Synapse, Databricks
- Cloud storage: Amazon S3, Azure Data Lake, Google Cloud Storage
- Open table formats: Apache Iceberg
- Qlik Cloud Analytics apps

### Data Connectivity

Qlik Sense supports a broad connector ecosystem:

| Connector Type | Examples |
|----------------|----------|
| **Relational DB** | SQL Server, Oracle, PostgreSQL, MySQL, DB2 |
| **Cloud DW** | Snowflake, BigQuery, Redshift, Synapse |
| **NoSQL** | MongoDB, Cassandra |
| **SaaS Apps** | Salesforce, SAP, ServiceNow, HubSpot |
| **Files** | CSV, Excel, XML, JSON, Parquet, QVD |
| **Cloud Storage** | S3, Azure Blob, Google Cloud Storage |
| **APIs** | REST connector, OData, GraphQL (via custom) |
| **Enterprise** | SAP BW, SAP HANA, Teradata, Informatica |

## Automation and Workflow

### Qlik Automate (Formerly Application Automation)

A visual, no-code workflow automation platform:

- **Trigger-Based Flows**: Initiate workflows based on data conditions, schedules, or external events.
- **400+ Connectors**: Pre-built blocks for Qlik services, Slack, Microsoft Teams, Jira, ServiceNow, Salesforce, email, and more.
- **Data-Driven Actions**: Combine Qlik analytics with automated actions -- for example, send an alert when a KPI threshold is breached, create a Jira ticket from anomaly detection, or trigger a data pipeline reload.
- **Template Library**: Pre-built automation templates for common scenarios.
- **API Integration**: Custom HTTP blocks for calling any REST API.

### Qlik Alerting

- **Data-Driven Alerts**: Define conditions on measures and dimensions; receive notifications via email, mobile push, or webhook when thresholds are crossed.
- **Composite Alerts**: Combine multiple conditions across different apps.
- **Alert Actions**: Trigger Qlik Automate workflows from alert events.

## Reporting and Distribution

### Qlik Reporting Service

- **Pixel-Perfect Reports**: Generate templated PDF/PowerPoint reports from Qlik apps.
- **Scheduled Distribution**: Automated report generation and delivery via email on defined schedules.
- **Burst Reporting**: Generate personalized reports for different recipients based on section access or data filters.
- **On-Demand**: Users can generate reports ad hoc from within an app.

### Qlik NPrinting (Client-Managed)

For on-premise deployments, Qlik NPrinting provides scheduled report generation and distribution with support for Word, Excel, PowerPoint, PDF, and HTML output formats.

## Embedded Analytics

### Embedding Options

| Method | Best For |
|--------|----------|
| **qlik-embed (web components)** | Modern web apps; React, Svelte, plain HTML; recommended primary approach |
| **nebula.js** | Custom visualization development and integration |
| **iframe / Single Integration API** | Quick embedding of full apps/sheets/objects with minimal code |
| **Capability APIs** | Legacy; full programmatic control of Qlik Sense objects in web pages |
| **enigma.js** | Low-level engine communication for custom applications |

### OEM and White-Label

Qlik supports OEM embedding with:
- Custom branding and theming
- Multi-tenant architecture for ISV solutions
- Per-user and capacity-based licensing for embedded scenarios
- Web integration security through allowed origins configuration

## Governance and Security

### Section Access

Row-level and field-level data security defined within the load script. Controls which users can see which data subsets, enabling a single app to serve multiple audiences with different data visibility.

### Spaces

Qlik Cloud organizes content into governed collaboration areas:

| Space Type | Purpose |
|------------|---------|
| **Personal** | Individual development workspace |
| **Shared** | Team collaboration with role-based access |
| **Managed** | Governed publishing with separated development and consumption |
| **Data** | Centralized data assets and connections |

### Content Security

- Security rules engine (client-managed) for fine-grained access control
- SAML, OIDC, and JWT authentication
- Encryption at rest and in transit
- Audit logging and compliance reporting
- Data lineage tracking through Qlik Talend Cloud
