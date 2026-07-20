# Tableau Platform Architecture

## VizQL Engine

VizQL (Visual Query Language) is Tableau's proprietary engine that translates visual interactions into optimized database queries.

### Query Generation Pipeline

1. User creates a visualization by dragging fields to shelves (rows, columns, filters, marks)
2. VizQL translates the visual description into optimized SQL (or native query language for the data source)
3. The query is sent to the data source via the appropriate driver
4. Results return to the VizQL engine, which applies additional calculations (table calcs, formatting)
5. The engine renders the final visualization (layout, marks, color encoding, interactivity)

### Key Characteristics

- **Declarative language**: Users describe "what" to visualize, not "how" to compute it
- **Query optimization**: VizQL generates efficient queries tailored to each data source's dialect (T-SQL, PL/SQL, HiveQL, etc.)
- **Rendering pipeline**: Handles layout computation, mark rendering, color encoding, and interactivity
- **Session management**: VizQL Server maintains session state and caches for interactive exploration
- **VizQL Data Service** (2025+): API enabling programmatic access to published data sources for custom applications, bypassing visualization rendering entirely

## Data Connectivity

### Live Connections

- Queries run directly against the source database in real time
- Data is always current; no scheduling needed
- Performance depends entirely on database speed and network latency
- Best for: real-time data needs, fast databases, smaller datasets
- Drawback: every interaction generates a query, so slow sources make slow dashboards

### Extracts (.hyper Files)

- Snapshot of data stored in Tableau's columnar .hyper format
- Optimized for fast aggregation, filtering, and analytical queries
- Supports incremental refresh (append new rows) and full refresh (rebuild entire extract)
- Stored on Tableau Server/Cloud; reduces load on source databases
- Best for: large datasets, slow databases, offline analysis, performance optimization
- Materialized calculations can be added to the extract to avoid repeated computation

### Tableau Bridge

- Client application bridging private network data to Tableau Cloud
- Runs behind the customer's firewall with secure outbound-only connections (no inbound ports required)
- Supports both live queries and scheduled extract refreshes
- Shared responsibility model: customer provides compute and network; Tableau manages the client software
- Supported sources: file data (Excel, CSV, statistical files), relational databases, private cloud sources (Redshift, Teradata, Snowflake behind VPC)
- Pool multiple Bridge clients for high availability and load distribution

## Tableau Server Architecture

### Core Processes

**Gateway**
- Entry point for all client requests (HTTP/HTTPS)
- Routes requests to appropriate internal processes
- Provides load balancing across clustered nodes
- Typically uses Apache HTTP Server

**Application Server (VizPortal)**
- Handles web application UI, REST API requests, authentication
- Manages content browsing, permissions, site administration
- Connects to the Repository for metadata operations

**VizQL Server**
- Core rendering engine for visualizations
- Translates visual queries to database queries
- Processes query results and renders visualizations
- Manages session state and caching per user

**Data Server**
- Central data management and metadata system
- Manages shared/published data sources and connection pooling
- Handles data source security and driver management
- Provides metadata management and data storage

**Backgrounder**
- Multi-process component for asynchronous and scheduled operations
- Handles: extract refreshes, subscriptions, data-driven alerts, Prep flow execution
- Runs administrative tasks and maintenance operations
- Can be scaled horizontally across multiple nodes (dedicated backgrounder nodes recommended for large deployments)

**Repository (PostgreSQL)**
- PostgreSQL database storing all server metadata
- Contents: users, groups, permissions, projects, workbooks, data sources, extract metadata, refresh history
- Can be installed locally or as an external PostgreSQL instance
- Queryable for monitoring and administration via the `readonly` database user

**Data Engine (Hyper)**
- Manages .hyper extract files
- Handles extract creation, refresh, and query execution
- Optimized columnar storage engine for analytics workloads

**Cache Server**
- Caches query results and rendered tiles
- Reduces redundant database queries for repeated views
- Improves response time for popular dashboards

**File Store**
- Stores extract files (.hyper) across server nodes
- Handles replication for high availability in multi-node deployments

### Multi-Node Architecture

```
                    ┌─────────────────┐
  Client Requests → │    Gateway      │
                    │  (Load Balancer)│
                    └───────┬─────────┘
                            │
               ┌────────────┼────────────┐
               │            │            │
        ┌──────▼──────┐ ┌──▼──────┐ ┌───▼─────┐
        │ Application │ │ VizQL   │ │  Data   │  Node 1-2
        │   Server    │ │ Server  │ │ Server  │  (client-facing)
        └─────────────┘ └─────────┘ └─────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
  ┌─────▼─────┐  ┌─────────▼────────┐  ┌───────▼──────┐
  │ Repository │  │  Backgrounder(s) │  │  Data Engine  │  Node 3+
  │ (Postgres) │  │  (extract/subs)  │  │    (Hyper)    │  (background)
  └────────────┘  └──────────────────┘  └──────────────┘
```

- Processes can be distributed across multiple nodes
- Nodes 1-2 typically serve client requests (Application Server, VizQL Server, Data Server)
- Additional nodes dedicated to backgrounder processes for extract refreshes and subscriptions
- Repository supports active/passive failover configuration

## Tableau Cloud Architecture

### Site Structure

- Each organization has one or more **sites** (isolated environments)
- Sites contain **projects** (hierarchical containers for organizing content)
- Projects hold workbooks, data sources, flows, and nested sub-projects
- Projects map to organizational structure (departments, teams)

### Data Management

- **Prep Conductor**: Schedules and automates Prep flow execution on Cloud (included with Enterprise/Tableau+ licenses)
- **Data Management Add-on**: Provides Catalog (data lineage, impact analysis), Prep Conductor, and virtual connections
- **Virtual Connections**: Centralized, governed connection points shared across content; define once, use everywhere

### Cloud-Specific Features

- Automatic software updates managed by Tableau (no maintenance windows)
- Built-in high availability and disaster recovery
- Tableau Bridge integration for private network data
- IP Filtering for access control (self-service in 2026.1)
- SCIM support for user provisioning (SAML and OIDC)

## Data Model: Relationships vs Joins

### Two-Layer Data Model (2020.2+)

**Logical layer (top level)**
- Displays relationships between independent tables
- Tables remain separate and normalized
- Default view when working with data sources
- Relationships: dynamic, context-aware connections between tables

**Physical layer (accessed by double-clicking a logical table)**
- Contains joins and unions within a single logical table
- Tables merge into one denormalized structure
- Traditional join types: inner, left, right, full outer

### Comparison

| Aspect | Relationships | Joins |
|---|---|---|
| Table structure | Tables remain separate and independent | Tables merge into one denormalized table |
| Join type selection | Automatic based on analysis context | User-specified explicitly |
| Granularity | Handles different levels of detail naturally | May duplicate rows at mismatched granularity |
| Deduplication | No LOD expressions needed | May require LOD expressions to avoid duplicates |
| Many-to-many | Supported natively | Causes row duplication |
| Performance | Queries only needed tables | Queries all joined tables |
| Layer | Logical layer (default) | Physical layer (double-click into logical table) |

### When to Use Each

- **Relationships**: Multi-table models, different granularities, many-to-many, normalized data. Default for new models.
- **Joins**: Explicit join type needed, single logical table construction, pre-2020.2 compatibility, deterministic queries.
- **Data blending** (legacy): Cross-database relationships; being replaced by cross-database relationships in the logical layer.

## Calculations

### Basic Calculations

Row-level or aggregate expressions applied at query time, computed by the database engine:
- `[Sales] * [Quantity]`
- `IF [Region] = "West" THEN "Pacific" END`

### Table Calculations

Computed locally by Tableau on the aggregated data already in the view. Applied last, just before rendering.
- Can output multiple values per partition
- Types: running totals, moving averages, percent of total, rank, difference, percentile
- Configured via partitioning (scope) and addressing (direction)
- Best for: recursive calculations, inter-row comparisons, period-over-period analysis

### LOD Expressions (Level of Detail)

Computed by the database at a specified granularity. Three types:

- **FIXED**: Computes at exactly the specified dimensions, regardless of view context. Applied before dimension filters (unless context filters used). Example: `{FIXED [Customer ID] : MIN([Order Date])}`
- **INCLUDE**: Adds a dimension to the view's granularity. Applied after dimension filters. Example: `{INCLUDE [Customer ID] : SUM([Sales])}`
- **EXCLUDE**: Removes a dimension from the view's granularity. Applied after dimension filters. Example: `{EXCLUDE [Region] : SUM([Sales])}`

### When to Use Which

- **Basic calculations**: Simple transforms, row-level logic, standard aggregations
- **Table calculations**: Running totals, rankings, moving averages, period comparisons
- **LOD expressions**: Cohort analysis, customer-level aggregation, percentage of total at different granularity

## Tableau Prep

### Flow Design

Flows are built left-to-right with connected steps:

1. **Input Step**: Connect to data sources, configure field types, apply initial filters
2. **Clean Step**: Rename fields, change types, split/merge fields, filter rows, create calculations, group and clean values
3. **Pivot Step**: Columns-to-rows or rows-to-columns transformation
4. **Join Step**: Combine two branches based on matching fields (inner, left, right, full outer)
5. **Union Step**: Stack two or more branches vertically; handles mismatched fields
6. **Aggregate Step**: Group by dimensions, aggregate measures; change granularity
7. **Script Step**: Run R or Python scripts for advanced transformations
8. **Output Step**: Write results to file, published data source, or database table

### Prep Conductor

- Available on Server (2019.1+) and Cloud (2019.3+)
- Schedules Prep flows for automated execution
- Monitors flow runs and sends failure notifications
- Included with Enterprise and Tableau+ licenses

## Embedding

### Embedding API v3

- JavaScript library for embedding Tableau views in web applications
- Web component-based: `<tableau-viz>` and `<tableau-authoring-viz>` elements
- CDN-hosted: `https://embedding.tableauusercontent.com/tableau.embedding.3.x.min.js`
- Supports: interactive filtering, event listeners, toolbar customization, responsive sizing

### Authentication for Embedding

| Method | How It Works | Introduced |
|---|---|---|
| Connected Apps (Direct Trust) | JWT-based authentication using shared secret | 2021.4 |
| Connected Apps (OAuth 2.0 Trust) | External authorization server issues JWTs | Enterprise SSO |
| Unified Access Tokens (UATs) | JWT-based via Tableau Cloud Manager; controls view/project access | 2025.3 |
| SAML / OpenID Connect | Redirect-based SSO for embedded views | All versions |
| Trusted Authentication | Legacy server-to-server token exchange | Legacy |

### Key Embedding Considerations

- Browsers must allow third-party cookies for cross-domain embedding
- CDN-hosted library avoids CORS issues (local hosting can cause problems)
- Use `resize()` method on Viz/AuthoringViz objects after container size changes
- Connected Apps control which content can be embedded and where

## Tableau Pulse

### Overview

AI-driven insights platform delivering personalized metrics and natural language summaries.

### Core Capabilities

- **Metrics Layer**: Statistical service that automatically identifies and ranks insights about defined metrics
- **Natural Language Summaries**: Generative AI translates statistical insights into plain language
- **Proactive Delivery**: Surfaces insights in Slack, Teams, email, and Salesforce applications
- **Personalization**: Tailors insights to individual users based on their roles and interests

### Key Features (2025-2026)

- Enhanced Q&A (Tableau+ exclusive): Ask natural language questions across multiple metrics
- Q&A Discover: Grouped insights across multiple KPIs without manual exploration
- Multi-language support: Insights delivered in all Tableau-supported languages
- Pulse on Dashboards (2026.1): Embed Pulse insights directly within traditional Tableau dashboards
- Bi-weekly release cadence independent of major Tableau releases

### Tableau Semantics

- Semantic layer for consistent metric definitions across the organization
- Pre-built metrics for Salesforce data
- AI-driven tools for semantic layer management
- Generally available since February 2025
