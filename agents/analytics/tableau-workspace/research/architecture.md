# Tableau Platform Architecture

## Tableau Product Suite

### Core Authoring & Analysis
- **Tableau Desktop**: Primary authoring tool for creating visualizations and dashboards. Available as part of Tableau Creator license. Connects to data sources, builds visualizations, publishes to Server/Cloud
- **Tableau Server**: Self-hosted analytics platform for sharing, governance, and collaboration. Deployed on-premises, private cloud, or public cloud (AWS EC2, GCP, Azure, Alibaba Cloud)
- **Tableau Cloud**: Fully hosted SaaS analytics platform (formerly Tableau Online). Multi-tenant shared-compute environment supporting thousands of sites with geographically distributed users
- **Tableau Prep Builder**: Visual data preparation tool for combining, cleaning, and shaping data via flow-based interface. Part of Tableau Creator license
- **Tableau Public**: Free platform for creating and sharing data visualizations publicly. Open and ungoverned; not for sensitive/private data
- **Tableau Mobile**: Free companion app (iOS/Android) providing access to Tableau Server or Cloud sites on mobile devices

### AI & Insights
- **Tableau Pulse**: AI-driven insights engine delivering personalized metrics and natural language summaries via Slack, Teams, email, and embedded in Salesforce. Available on Tableau Cloud
- **Tableau Agent**: AI assistant for creating visualizations and understanding dashboards using natural language

### Licensing Editions
- **Tableau Creator**: Full authoring (Desktop + Prep Builder + Server/Cloud seat)
- **Tableau Explorer**: Self-service interaction with published content
- **Tableau Viewer**: View and interact with dashboards
- **Tableau Enterprise**: Extended license edition for Cloud/Server with additional features
- **Tableau+**: Premium tier with enhanced AI capabilities (Enhanced Q&A, advanced Pulse features)

---

## VizQL Engine

VizQL (Visual Query Language) is Tableau's proprietary engine that translates visual interactions into database queries.

### How It Works
1. User creates a visualization by dragging fields to shelves (rows, columns, filters, marks)
2. VizQL translates the visual description into optimized SQL (or native query language for the data source)
3. The query is sent to the data source via the appropriate driver
4. Results return to the VizQL engine, which applies additional calculations (table calcs, formatting)
5. The engine renders the final visualization

### Key Characteristics
- **Declarative language**: Users describe "what" to visualize, not "how" to compute it
- **Query optimization**: VizQL generates efficient queries tailored to each data source's dialect
- **Rendering pipeline**: Handles layout, mark rendering, color encoding, and interactivity
- **VizQL Data Service** (2025+): An API enabling programmatic access to published data sources for custom applications, bypassing visualization rendering entirely

---

## Data Model: Relationships vs Joins

### Two-Layer Data Model (introduced in Tableau 2020.2)

**Logical Layer (top level)**
- Displays relationships between independent tables
- Tables remain separate and normalized
- Default view when working with data sources
- Supports relationships: dynamic, context-aware connections between tables

**Physical Layer (accessed by double-clicking a logical table)**
- Contains joins and unions within a single logical table
- Tables merge into one denormalized structure
- Traditional join types (inner, left, right, full outer)

### Relationships vs Joins

| Aspect | Relationships | Joins |
|--------|---------------|-------|
| Table structure | Tables remain separate and independent | Tables merge into one denormalized table |
| Join type selection | Automatic based on analysis context | User-specified explicitly |
| Granularity | Handles different levels of detail naturally | May duplicate rows at mismatched granularity |
| Deduplication | No LOD expressions needed | May require LOD expressions to avoid duplicates |
| Many-to-many | Supported natively | Causes row duplication |
| Performance | Queries only needed tables | Queries all joined tables |
| Layer | Logical layer (default) | Physical layer (double-click into logical table) |

### When to Use Each
- **Relationships**: Multi-table models, different granularities, many-to-many, normalized data
- **Joins**: Explicit join type needed, single logical table construction, pre-2020.2 compatibility
- **Data blending** (legacy): Cross-database relationships; being replaced by cross-database relationships in the logical layer

---

## Data Connectivity

### Live Connections
- Queries run directly against the source database in real time
- Data is always current; no scheduling needed
- Performance depends on database speed and network latency
- Best for: real-time data needs, fast databases, smaller datasets

### Extracts (.hyper Files)
- Snapshot of data stored in Tableau's columnar .hyper format
- Optimized for fast aggregation and filtering
- Supports incremental refresh (append new rows) and full refresh (rebuild)
- Stored on Tableau Server/Cloud; reduces load on source databases
- Best for: large datasets, slow databases, offline analysis, performance optimization

### Tableau Bridge
- Client application bridging private network data to Tableau Cloud
- Runs behind the customer's firewall with secure outbound-only connections
- Supports both live queries and scheduled extract refreshes
- Shared responsibility model: customer provides compute/network, Tableau manages the client software
- Supports: file data (Excel, CSV, statistical files), relational databases, private cloud sources (Redshift, Teradata, Snowflake behind VPC)

---

## Tableau Server Architecture

### Core Processes (Services)

**Gateway**
- Entry point for all client requests (HTTP/HTTPS)
- Routes requests to appropriate internal processes
- Provides load balancing across clustered nodes
- Typically uses Apache HTTP Server

**Application Server (VizPortal)**
- Handles web application UI, REST API requests, authentication
- Manages content browsing, permissions, site administration
- Connects to the Repository for metadata

**VizQL Server**
- Core rendering engine
- Translates visual queries to database queries
- Processes query results and renders visualizations
- Manages session state and caching

**Data Server**
- Central data management and metadata system
- Manages shared/published data sources
- Handles data source security, connection pooling, driver management
- Provides metadata management and data storage

**Backgrounder**
- Multi-process component for scheduled operations
- Handles: extract refreshes, subscriptions, data-driven alerts, Prep flow execution
- Runs administrative tasks and maintenance operations
- Can be scaled horizontally across multiple nodes

**Repository (PostgreSQL)**
- PostgreSQL database storing all server metadata
- Contents: users, groups, permissions, projects, workbooks, data sources, extract metadata, refresh history
- Can be installed locally or as an external PostgreSQL instance
- Queryable for monitoring and administration

**Data Engine (Hyper)**
- Manages .hyper extract files
- Handles extract creation, refresh, and query execution
- Optimized columnar storage for analytics workloads

**Cache Server**
- Caches query results and rendered tiles
- Reduces redundant database queries
- Improves response time for repeated views

**File Store**
- Stores extract files (.hyper) across server nodes
- Handles replication for high availability

### Multi-Node Architecture
- Processes can be distributed across multiple nodes
- Nodes 1-2 typically serve client requests (Application Server, VizQL Server, Data Server)
- Additional nodes can be dedicated to backgrounder processes
- Repository can have active/passive failover configuration

---

## Tableau Cloud Architecture

### Site Structure
- Each organization has one or more **sites** (isolated environments)
- Sites contain **projects** (hierarchical containers for organizing content)
- Projects hold workbooks, data sources, flows, and nested sub-projects
- Projects map to organizational structure (departments, teams)

### Data Management
- **Prep Conductor**: Schedules and automates Prep flow execution on Cloud (included with Enterprise/Tableau+ licenses)
- **Data Management Add-on**: Provides Catalog (data lineage, impact analysis), Prep Conductor, and virtual connections
- **Virtual Connections**: Centralized, governed connection points shared across content

### Cloud-Specific Features
- Automatic software updates managed by Tableau
- Built-in high availability and disaster recovery
- Tableau Bridge integration for private network data
- IP Filtering for access control (self-service in 2026.1)
- SCIM support for user provisioning (SAML and OIDC)

---

## Calculations

### Basic Calculations
- Row-level or aggregate expressions applied at query time
- Computed by the database engine
- Examples: `[Sales] * [Quantity]`, `IF [Region] = "West" THEN "Pacific" END`

### Table Calculations
- Computed locally by Tableau on the aggregated data already in the view
- Applied last, just before rendering
- Can output multiple values per partition
- Types: running totals, moving averages, percent of total, rank, difference, percentile
- Configured via partitioning (scope) and addressing (direction)
- Best for: recursive calculations, inter-row comparisons, period-over-period

### LOD Expressions (Level of Detail)
- Computed by the database at a specified granularity
- Three types:
  - **FIXED**: Computes at exactly the specified dimensions, regardless of view context. Applied before dimension filters (unless context filters used). Example: `{FIXED [Customer ID] : MIN([Order Date])}`
  - **INCLUDE**: Adds a dimension to the view's granularity. Applied after dimension filters. Example: `{INCLUDE [Customer ID] : SUM([Sales])}`
  - **EXCLUDE**: Removes a dimension from the view's granularity. Applied after dimension filters. Example: `{EXCLUDE [Region] : SUM([Sales])}`

### When to Use Which
- **Basic calculations**: Simple transforms, row-level logic, standard aggregations
- **Table calculations**: Running totals, rankings, moving averages, period comparisons
- **LOD expressions**: Cohort analysis, customer-level aggregation, percentage of total at different granularity

---

## Dashboard Design

### Layout Containers
- **Tiled containers**: Items snap to grid, fill available space, consistent alignment
- **Floating containers**: Freely positioned, pixel-precise placement, can overlay other objects
- **Horizontal/Vertical layout containers**: Group items in rows or columns with proportional sizing

### Device-Specific Layouts
- Create separate layouts for Desktop, Tablet, and Phone
- Single dashboard URL serves appropriate layout based on device
- Device layouts inherit from Default dashboard; add/remove/resize objects per device
- Views, filters, actions, legends, and parameters must exist in Default before adding to device layouts

### Dashboard Actions
- **Filter actions**: Use selections in one view to filter data in other views
- **Highlight actions**: Emphasize related marks across views while dimming others
- **URL actions**: Create hyperlinks to external resources; supports field value parameters (e.g., `<Country>`)
- **Set actions**: Let users interactively change set membership by selecting marks
- **Parameter actions**: Let users change parameter values through mark interaction
- **Go to Sheet actions**: Navigate to another dashboard or sheet

---

## Tableau Prep

### Flow Design
Flows are built left-to-right with connected steps:

1. **Input Step**: Connect to data sources, configure field types, apply initial filters
2. **Clean Step**: Rename fields, change types, split/merge fields, filter rows, create calculations, group and clean values
3. **Pivot Step**: Columns-to-rows or rows-to-columns transformation
4. **Join Step**: Combine two branches row-by-row based on matching fields (inner, left, right, full outer)
5. **Union Step**: Stack two or more branches vertically; handles mismatched fields
6. **Aggregate Step**: Group by dimensions, aggregate measures; change granularity
7. **Script Step**: Run R or Python scripts for advanced transformations
8. **Output Step**: Write results to file, published data source, or database table

### Prep Conductor
- Available on Server (2019.1+) and Cloud (2019.3+)
- Schedules Prep flows for automated execution
- Monitors flow runs and sends failure notifications
- Included with Enterprise and Tableau+ licenses

---

## Embedding

### Tableau Embedding API v3
- JavaScript library for embedding Tableau views in web applications
- Web component-based: `<tableau-viz>` and `<tableau-authoring-viz>` elements
- CDN-hosted: `https://embedding.tableauusercontent.com/tableau.embedding.3.x.min.js`
- Supports: interactive filtering, event listeners, toolbar customization, responsive sizing

### Authentication for Embedding
- **Connected Apps (Direct Trust)**: JWT-based authentication using shared secret; introduced in 2021.4
- **Connected Apps (OAuth 2.0 Trust)**: External authorization server issues JWTs; for enterprise SSO integration
- **Unified Access Tokens (UATs)**: Introduced in 2025.3 via Tableau Cloud Manager; JWT-based, controls view/project access
- **SAML/OpenID Connect**: Redirect-based SSO for embedded views
- **Trusted Authentication**: Legacy server-to-server token exchange

### Key Considerations
- Browsers must allow third-party cookies for cross-domain embedding
- CDN-hosted library avoids CORS issues (local hosting can cause problems)
- Resize method available for dynamic container sizing
- Connected Apps control which content can be embedded and where

---

## Tableau Pulse

### Overview
AI-driven insights platform delivering personalized metrics and natural language summaries.

### Core Capabilities
- **Metrics Layer**: Statistical service that automatically identifies and ranks insights about defined metrics
- **Natural Language Summaries**: Generative AI translates statistical insights into plain language
- **Proactive Delivery**: Surfaces insights in Slack, Teams, email, and Salesforce applications
- **Personalization**: Tailors insights to individual users based on their roles and interests

### Key Features (2025-2026)
- **Enhanced Q&A** (Tableau+ exclusive): Ask natural language questions across multiple metrics; powered by advanced AI
- **Q&A Discover**: Grouped insights across multiple KPIs without manual exploration
- **Multi-language Support**: Insights delivered in all Tableau-supported languages
- **Pulse on Dashboards**: Embed Pulse insights directly within traditional Tableau dashboards
- **Bi-weekly Release Cadence**: Continuous feature delivery independent of major Tableau releases

### Tableau Semantics
- Semantic layer for consistent metric definitions across the organization
- Pre-built metrics for Salesforce data
- AI-driven tools for semantic layer management
- Generally available since February 2025
