# Qlik Sense Architecture

## Platform Overview

Qlik Sense is an enterprise analytics platform built around a unique in-memory associative data indexing engine. Unlike traditional query-based BI tools that rely on predefined drill paths and SQL joins, Qlik Sense dynamically infers associations between all data points, enabling unrestricted exploration across the entire data model.

## The Qlik Associative Engine (QIX Engine)

### Core Concept

The QIX (Qlik Indexing) Engine is the computational heart of Qlik Sense. The terms "QIX Engine" and "Qlik Associative Engine" refer to the same technology -- Qlik has used both names over the years, with "Associative Engine" being the current preferred branding.

### How It Works

- **Associative Model**: Every data point is associated with every other data point. When a user makes a selection, the engine instantly calculates which values are associated (white), selected (green), and excluded (gray) across all fields in the data model.
- **In-Memory Processing**: The entire data model is held in RAM. The engine is a 64-bit, multi-threaded process optimized to exploit all available processor cores.
- **Columnar Storage**: Data is stored in a columnar format where unique values are stored only once (symbol tables) and relationships are represented as pointers, enabling significant compression ratios (often 10:1 or better).
- **Logical Inference Engine**: The QIX engine contains a logical inference engine that dynamically computes associations at runtime, rather than relying on pre-built cubes or aggregation tables.

### Internal Data Structures

| Structure | Purpose |
|-----------|---------|
| **Symbol Tables** | Store unique values for each field; shared across all tables referencing that field |
| **Data Tables** | Row-level pointers mapping records to symbol table entries |
| **State Space** | Tracks selection states across all fields for the associative experience |
| **Calculation Engine** | Evaluates expressions, aggregations, and set analysis in real time |

### Key Engine Characteristics

- No pre-aggregation required -- all calculations happen at query time
- Handles billions of rows in memory with proper optimization
- Automatic data association based on matching field names
- Supports calculated dimensions and dynamic grouping
- Built-in caching of expression results for repeated calculations

## Deployment Models

### Qlik Sense Enterprise on Windows (Client-Managed)

The traditional on-premise deployment where the customer manages all infrastructure.

**Architecture Components:**

| Component | Role |
|-----------|------|
| **Engine Service** | Hosts the QIX engine; loads apps into memory and serves user sessions |
| **Repository Service** | Central metadata store using PostgreSQL; manages apps, users, security rules |
| **Proxy Service** | Handles authentication, session management, and load balancing |
| **Scheduler Service** | Manages reload tasks and triggers |
| **Printing Service** | Generates PDF exports and Qlik NPrinting integration |

**Multi-Node Deployment:**

- **Shared Persistence**: All nodes share a single repository database and a central file share for apps/content. This is the only supported persistence model since 2017.
- **Central Node**: Runs all services; manages the site.
- **RIM Nodes** (Resource in More): Additional engine/proxy/scheduler nodes for horizontal scaling.
- **Failover**: One or more RIM nodes can be designated as failover candidates for the central node.
- **Network Requirements**: All nodes must have sub-4ms latency to the file share; 10 Gbps networking is recommended for multi-node sites.

### Qlik Cloud (SaaS)

Fully managed SaaS deployment hosted and operated by Qlik.

**Cloud-Native Architecture:**

- **Microservices**: Container-based architecture built on CNCF standards (Kubernetes, Docker).
- **NGINX Ingress Controller**: Handles web interface routing and load balancing.
- **MongoDB**: Serves as the metadata repository for Qlik Cloud Analytics.
- **Horizontal Auto-Scaling**: Workloads scale up and down dynamically based on demand; Kubernetes auto-scaling manages cognitive engine resources.
- **Zero-Downtime Deployments**: Platform updates roll out without affecting active user sessions.
- **Infrastructure**: Primarily runs on Amazon Web Services (AWS) with multiple global regions, including a UAE region added in early 2025.

**Tenant Model:**

- Each customer receives a dedicated tenant instance.
- Multi-tenant configurations are supported for OEM and complex organizational structures.
- Roles include: User, Developer, Tenant Admin, and Service Account Owner.
- Performance-tested for 10,000+ users/hour accessing 100+ apps with sub-second response times.

**SaaS vs Client-Managed Key Differences:**

| Aspect | SaaS | Client-Managed |
|--------|------|-----------------|
| Updates | Continuous (~every 5 days) | Quarterly releases |
| Scaling | Automatic | Manual node provisioning |
| AI Features | Full (AutoML, Insight Advisor, Qlik Answers) | Limited subset |
| Collaboration | Shared/managed spaces | Streams with publish workflow |
| App Memory | 5 GB default (expandable) | Limited by server RAM |
| Infrastructure | Managed by Qlik | Managed by customer |

### Qlik Sense Enterprise on Kubernetes

Containerized deployment for private cloud or hybrid scenarios, using the same microservices architecture as Qlik Cloud but deployed within the customer's own Kubernetes cluster.

## Apps, Sheets, and Objects

### Application Model

- **App (.qvf file)**: The fundamental unit of analytics. Contains the data model, load script, sheets, stories, and bookmarks in a single binary file.
- **Sheets**: Visual canvases within an app that hold visualization objects. Apps typically contain multiple sheets organized by analytical purpose.
- **Objects**: Individual visualizations (charts, tables, KPIs, filters) placed on sheets. Each object is bound to one or more expressions evaluated against the in-memory data model.
- **Master Items**: Reusable, governed definitions of dimensions, measures, and visualizations that ensure consistency across an app.
- **Stories**: Data storytelling canvases that combine snapshots of visualizations with narrative text.
- **Bookmarks**: Saved selection states that users can recall.

### DAR Design Pattern

Qlik recommends the **Dashboard / Analysis / Reporting** (DAR) methodology:
- **Dashboard sheets**: High-level KPIs and summary views (5-8 objects max)
- **Analysis sheets**: Interactive exploration with filters and detailed charts
- **Reporting sheets**: Tabular data for export and detailed review

## Data Load Scripting

### Script Language

Qlik uses a proprietary ETL scripting language executed in the Data Load Editor. Key constructs include:

- **LOAD / SQL SELECT**: Primary data loading statements
- **Resident loads**: Re-processing already-loaded tables
- **Preceding loads**: Stacking transformations in a single pass
- **QVD files**: Qlik's optimized binary data format; reading from QVD is 10-100x faster than other sources
- **Incremental loading**: Strategies for loading only new/changed data
- **Variables**: `SET` and `LET` for parameterization
- **Subroutines**: `SUB`/`END SUB` for reusable script blocks
- **Control statements**: `IF`, `FOR`, `DO WHILE` for flow control
- **Mapping loads**: Lookup tables via `ApplyMap()` for field transformations

### Data Connections

Supports ODBC, OLE DB, REST, file-based (CSV, Excel, XML, JSON), web connectors, SAP, Salesforce, and custom connectors via the Qlik Connector SDK.

## Set Analysis

Set analysis is Qlik's mechanism for defining the scope of an aggregation independently of user selections. It is conceptually equivalent to a WHERE clause but operates within the associative model.

### Syntax Structure

```
Aggregation({SetExpression} Expression)
```

**Components:**

| Element | Symbol | Purpose |
|---------|--------|---------|
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

// Exclude a field from selections
Sum({$<Region=>} Sales)

// Element functions for indirect selection
Sum({<Customer=P({1<Year={2024}>} Customer)>} Amount)
```

## Mashup API and Embedding

### Embedding Frameworks (Current)

| Framework | Use Case |
|-----------|----------|
| **qlik-embed** | Primary recommended framework; web components for HTML, React, Svelte; handles auth and rendering |
| **nebula.js** | JavaScript library for building and integrating custom visualizations on the Associative Engine |
| **iframe / Single Integration API** | Simple embedding via URL-based iframe; minimal code required |
| **Capability APIs** | Legacy JavaScript APIs for full programmatic control of embedded Qlik Sense content |
| **enigma.js** | Low-level WebSocket communication library for direct QIX engine interaction |

### qlik-embed (Recommended)

qlik-embed is Qlik's current primary embedding framework. It wraps the capabilities of iframe, Capability APIs, and nebula/enigma embedding into a single package, handling modern authentication flows and supporting frameworks like React and Svelte. It uses nebula.js internally for chart rendering.

## Extensions

Qlik Sense supports custom visualization extensions built with web technologies (HTML, CSS, JavaScript). Extensions are packaged as ZIP files containing a QEXT manifest and JavaScript modules, and they are deployed through the QMC or Qlik Cloud management console.

The Extension API provides methods and properties for:
- Custom rendering of visualization objects
- Property panel definition for user configuration
- Integration with the selection model
- Responsive layout handling
- Data binding via HyperCube and ListObject definitions

## Qlik Cloud Architecture -- Additional Services

| Service | Description |
|---------|-------------|
| **Qlik Alerting** | Threshold-based alerts on data conditions |
| **Qlik Reporting Service** | Scheduled and on-demand report generation |
| **Qlik Application Automation (Automate)** | No-code workflow automation across Qlik and third-party services |
| **Qlik Data Integration** | Data pipeline management, CDC, and ELT/ETL |
| **Qlik Answers** | Agentic AI assistant combining structured and unstructured data |
| **Qlik Predict** | Automated ML model creation and predictive analytics |
| **Identity Providers** | SAML, OIDC, and JWT-based authentication |
| **Spaces** | Governed collaboration areas (shared, managed, personal, data) |
