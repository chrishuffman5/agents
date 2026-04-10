# Qlik Sense Platform Architecture

## The QIX Associative Engine

### Core Concept

The QIX (Qlik Indexing) Engine is the computational heart of Qlik Sense. Unlike SQL-based BI tools that rely on predefined queries, drill paths, and pre-built cubes, the QIX engine dynamically indexes all data associations in memory. When a user makes a selection, the engine instantly calculates which values are associated (white), selected (green), and excluded (gray) across all fields in the data model.

### Internal Data Structures

| Structure | Purpose |
|---|---|
| **Symbol Tables** | Store unique values for each field; shared across all tables referencing that field |
| **Data Tables** | Row-level pointers mapping records to symbol table entries |
| **State Space** | Tracks selection states across all fields for the associative experience |
| **Calculation Engine** | Evaluates expressions, aggregations, and set analysis in real time |

### Key Characteristics

- **In-memory processing**: The entire data model is held in RAM. The engine is a 64-bit, multi-threaded process optimized to exploit all available processor cores.
- **Columnar storage**: Data is stored in columnar format where unique values are stored only once (symbol tables) and relationships are represented as pointers. Compression ratios are often 10:1 or better.
- **Logical inference engine**: Dynamically computes associations at runtime rather than relying on pre-built cubes or aggregation tables.
- **No pre-aggregation required**: All calculations happen at query time.
- **Automatic data association**: Tables are associated automatically based on matching field names.
- **Expression result caching**: Built-in caching of expression results for repeated calculations.

### Memory and Compression

- Each unique value is stored only once per field in the symbol table
- Rows reference symbols via integer pointers, not raw values
- High-cardinality fields (raw timestamps, transaction IDs) consume disproportionate memory because they have many unique symbol table entries
- `AutoNumber()` converts string keys to integers for faster lookups and smaller footprint
- Separating date from timestamp reduces the symbol table size significantly

## Deployment Models

### Qlik Cloud (SaaS)

Fully managed SaaS deployment hosted and operated by Qlik.

**Cloud-Native Architecture:**

- **Microservices**: Container-based architecture built on CNCF standards (Kubernetes, Docker)
- **NGINX Ingress Controller**: Handles web interface routing and load balancing
- **MongoDB**: Serves as the metadata repository for Qlik Cloud Analytics
- **Horizontal Auto-Scaling**: Workloads scale up and down dynamically based on demand; Kubernetes auto-scaling manages cognitive engine resources
- **Zero-Downtime Deployments**: Platform updates roll out without affecting active user sessions
- **Infrastructure**: Primarily runs on Amazon Web Services (AWS) with multiple global regions, including a UAE region added in early 2025

**Tenant Model:**

- Each customer receives a dedicated tenant instance
- Multi-tenant configurations are supported for OEM and complex organizational structures
- Roles: User, Developer, Tenant Admin, Service Account Owner
- Performance-tested for 10,000+ users/hour accessing 100+ apps with sub-second response times

**SaaS vs Client-Managed Key Differences:**

| Aspect | SaaS | Client-Managed |
|---|---|---|
| Updates | Continuous (~every 5 days) | Quarterly releases |
| Scaling | Automatic | Manual node provisioning |
| AI Features | Full (Qlik Answers, Insight Advisor, Qlik Predict) | Limited subset |
| Collaboration | Shared/managed spaces | Streams with publish workflow |
| App Memory | 5 GB default (expandable) | Limited by server RAM |
| Infrastructure | Managed by Qlik | Managed by customer |

### Qlik Sense Enterprise on Windows (Client-Managed)

Traditional on-premises deployment where the customer manages all infrastructure.

**Architecture Components:**

| Component | Role |
|---|---|
| **Engine Service** | Hosts the QIX engine; loads apps into memory and serves user sessions |
| **Repository Service** | Central metadata store using PostgreSQL; manages apps, users, security rules |
| **Proxy Service** | Handles authentication, session management, and load balancing |
| **Scheduler Service** | Manages reload tasks and triggers |
| **Printing Service** | Generates PDF exports and Qlik NPrinting integration |

**Multi-Node Deployment:**

- **Shared Persistence**: All nodes share a single repository database and a central file share for apps/content. Only supported persistence model since 2017.
- **Central Node**: Runs all services; manages the site.
- **RIM Nodes** (Resource in More): Additional engine/proxy/scheduler nodes for horizontal scaling.
- **Failover**: One or more RIM nodes can be designated as failover candidates for the central node.
- **Network Requirements**: All nodes must have sub-4ms latency to the file share; 10 Gbps networking is recommended for multi-node sites.

**Multi-Node Topology:**

```
                    ┌─────────────────┐
  Client Requests → │   Proxy Service │
                    │  (Load Balancer)│
                    └───────┬─────────┘
                            │
               ┌────────────┼────────────┐
               │            │            │
        ┌──────▼──────┐ ┌──▼──────┐ ┌───▼──────┐
        │   Engine    │ │ Engine  │ │ Engine   │
        │  (Central)  │ │ (RIM 1) │ │ (RIM 2)  │
        └─────────────┘ └─────────┘ └──────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
  ┌─────▼─────┐  ┌─────────▼────────┐  ┌───────▼──────┐
  │ Repository │  │   Scheduler      │  │ Central File │
  │ (Postgres) │  │   Service        │  │    Share     │
  └────────────┘  └──────────────────┘  └──────────────┘
```

### Qlik Sense Enterprise on Kubernetes

Containerized deployment for private cloud or hybrid scenarios. Uses the same microservices architecture as Qlik Cloud but deployed within the customer's own Kubernetes cluster. Bridges the gap between fully managed SaaS and fully self-managed on-premises.

## Apps, Sheets, and Objects

### Application Model

- **App (.qvf file)**: The fundamental unit of analytics. Contains the data model, load script, sheets, stories, and bookmarks in a single binary file.
- **Sheets**: Visual canvases within an app that hold visualization objects. Apps typically contain multiple sheets organized by analytical purpose.
- **Objects**: Individual visualizations (charts, tables, KPIs, filters) placed on sheets. Each object is bound to one or more expressions evaluated against the in-memory data model.
- **Master Items**: Reusable, governed definitions of dimensions, measures, and visualizations that ensure consistency across an app. Master items enable expression caching -- the same expression used in multiple places is calculated once.
- **Stories**: Data storytelling canvases that combine snapshots of visualizations with narrative text.
- **Bookmarks**: Saved selection states that users can recall.

### DAR Design Pattern

Qlik recommends the **Dashboard / Analysis / Reporting** (DAR) methodology for organizing sheets:

- **Dashboard sheets**: High-level KPIs and summary views (5-8 objects max). Quick overview for executives and stakeholders.
- **Analysis sheets**: Interactive exploration with filters and detailed charts (up to 12 objects). Power users drill into patterns.
- **Reporting sheets**: Tabular data for export and detailed review. Data analysts extract specific records.

## Data Load Scripting

### Script Language

Qlik uses a proprietary ETL scripting language executed in the Data Load Editor:

- **LOAD / SQL SELECT**: Primary data loading statements. LOAD reads from files and preceding loads; SQL SELECT queries databases via ODBC/OLE DB.
- **Resident loads**: Re-processing already-loaded in-memory tables.
- **Preceding loads**: Stacking transformations in a single pass (the upper LOAD processes results of the lower LOAD/SQL SELECT without materializing an intermediate table).
- **QVD files**: Qlik's optimized binary data format. Reading from QVD is 10-100x faster than other sources when using optimized loads (no transformations, no WHERE clause).
- **Incremental loading**: Strategies for loading only new or changed data using watermark fields (`Max(ModifiedDate)`).
- **Variables**: `SET` (literal assignment) and `LET` (evaluated expression) for parameterization.
- **Subroutines**: `SUB`/`END SUB` for reusable script blocks.
- **Control statements**: `IF`, `FOR`, `DO WHILE` for flow control.
- **Mapping loads**: Lookup tables via `ApplyMap()` for fast field transformations without joins.

### Data Connections

| Connector Type | Examples |
|---|---|
| Relational DB | SQL Server, Oracle, PostgreSQL, MySQL, DB2 |
| Cloud DW | Snowflake, BigQuery, Redshift, Synapse |
| NoSQL | MongoDB, Cassandra |
| SaaS Apps | Salesforce, SAP, ServiceNow, HubSpot |
| Files | CSV, Excel, XML, JSON, Parquet, QVD |
| Cloud Storage | S3, Azure Blob, Google Cloud Storage |
| APIs | REST connector, OData |
| Enterprise | SAP BW, SAP HANA, Teradata |

## Set Analysis

Set analysis defines the scope of an aggregation independently of user selections. It is conceptually equivalent to a WHERE clause but operates within the associative model.

### Syntax Structure

```
Aggregation({SetExpression} Expression)
```

**Components:**

| Element | Symbol | Purpose |
|---|---|---|
| Identifier | `$` (current selections), `1` (all data), `BookmarkId` | Base record set |
| Operators | `+` (union), `*` (intersection), `-` (exclusion), `/` (symmetric diff) | Combine sets |
| Modifiers | `<Field={Value}>` | Filter the set |

### Common Patterns

```
// Ignore current Year selection
Sum({$<Year=>} Sales)

// Force specific year
Sum({$<Year={2024}>} Sales)

// All data, no selections
Sum({1} Sales)

// Year-over-year
Sum({$<Year={$(=Max(Year)-1)}>} Sales)

// Element functions for indirect selection
// Customers who purchased in 2024
Sum({<Customer=P({1<Year={2024}>} Customer)>} Amount)

// Customers who did NOT purchase in 2024
Sum({<Customer=E({1<Year={2024}>} Customer)>} Amount)

// Intersection: both conditions
Sum({$<Year={2024}> * $<Region={'North'}>} Sales)

// Search expression: products with sales > 1000
Sum({$<Product={"=Sum(Sales)>1000"}>} Sales)

// Alternate states for parallel selection
Sum({State1} Sales) - Sum({State2} Sales)
```

## Embedding Frameworks

### qlik-embed (Recommended)

qlik-embed is Qlik's current primary embedding framework. It wraps iframe, Capability API, and nebula/enigma embedding into a single package, handling modern authentication flows and supporting frameworks like React and Svelte. Uses nebula.js internally for chart rendering.

### nebula.js

JavaScript library for building and integrating custom visualizations on the Associative Engine. Used for custom chart development and deep integration scenarios.

### iframe / Single Integration API

Simple embedding of full apps, sheets, or individual objects via URL-based iframe. Minimal code required. Good for quick integrations.

### Capability APIs (Legacy)

Legacy JavaScript APIs for full programmatic control of embedded Qlik Sense content. Being superseded by qlik-embed but still functional.

### enigma.js

Low-level WebSocket communication library for direct QIX engine interaction. Used for building custom applications that need raw engine access without the visualization layer.

### Authentication for Embedding

| Deployment | Auth Methods |
|---|---|
| Qlik Cloud | OAuth 2.0, JWT, API keys |
| Client-Managed | Virtual proxy with SAML, OIDC, JWT, header-based auth |
| OEM | Multi-tenant config with allowed origins, custom branding |

## Extensions

Qlik Sense supports custom visualization extensions built with web technologies (HTML, CSS, JavaScript). Extensions are packaged as ZIP files containing a QEXT manifest and JavaScript modules.

The Extension API provides:
- Custom rendering of visualization objects
- Property panel definition for user configuration
- Integration with the selection model
- Responsive layout handling
- Data binding via HyperCube and ListObject definitions

## AI and Augmented Analytics

### Insight Advisor

Three modes:
- **Search-Based Visual Discovery**: Natural language questions auto-generate visualizations using NLP and the precedents learning model
- **Insight Advisor Chat**: Conversational analytics with follow-up questions, context retention, and interactive chart exploration
- **Associative Insights**: Automated analysis identifying statistically significant patterns, outliers, and correlations without user prompting

Insight Advisor learns from user behavior and a **business logic layer** where administrators define field classifications, preferred aggregations, default calendar periods, and field relationships.

### Qlik Answers (Agentic AI)

- Agentic reasoning: breaks down complex, multi-step questions using AI paired with the Qlik analytics engine
- Combines structured analytics data with unstructured content (documents, knowledge bases) in a single conversational interface
- Discovery Agent (GA March 2026): autonomous data exploration and pattern identification
- Governed responses with citations and source data traceability
- MCP integration for connecting third-party AI assistants
- Embeddable within the platform and as custom-built assistants

### Qlik Predict (Formerly AutoML)

- Automated classification and regression model training with feature engineering, model selection, and hyperparameter tuning
- Experiment management: track and compare model runs, evaluate feature importance
- Prediction results flow directly into Qlik visualizations and set analysis expressions
- No-code interface designed for business analysts

## Qlik Cloud Additional Services

| Service | Description |
|---|---|
| Qlik Alerting | Threshold-based and composite data alerts with webhook/email notifications |
| Qlik Reporting Service | Scheduled and on-demand PDF/PowerPoint report generation with burst delivery |
| Qlik Automate | No-code workflow automation with 400+ connectors (Slack, Teams, Jira, Salesforce) |
| Qlik Data Integration (Talend) | ELT/ETL pipelines, CDC, data quality, data catalog |
| Qlik Answers | Agentic AI assistant combining structured and unstructured data |
| Qlik Predict | Automated ML model creation and predictive analytics |
| Identity Providers | SAML, OIDC, and JWT-based authentication |
| Spaces | Governed collaboration areas (shared, managed, personal, data) |
