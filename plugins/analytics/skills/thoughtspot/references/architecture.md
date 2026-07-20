# ThoughtSpot Platform Architecture

## Platform Overview

ThoughtSpot is an AI-driven analytics platform built around search-based data exploration. Founded in 2012, it has evolved from a search-driven BI tool into an agentic analytics platform combining natural language search, AI-powered insights, and embedded analytics capabilities.

## Search-Based Analytics Engine

### Search-Token Architecture

ThoughtSpot's core innovation is its patented search-token architecture that parses natural language queries into structured tokens:

1. User types a question in the search bar (e.g., "revenue by region last quarter")
2. The system parses input into **tokens** mapped to data objects (columns, tables, measures, attributes) defined in the semantic model
3. Tokens are translated into **deterministic SQL** rather than relying solely on LLM text-to-SQL
4. SQL executes against the data warehouse
5. Results render as an automatically selected visualization

This hybrid approach provides accuracy guardrails while supporting conversational interaction. Every query produces traceable, governed SQL tied to the semantic model.

### Sage Search Engine

ThoughtSpot Sage integrates generative AI (GPT-based models) with the search-token architecture:

- Supplements LLM algorithms with metadata: attribute columns, synonyms, indexed values, formulas, join paths, analytical keywords
- When questions are typed, ThoughtSpot's data model provides guardrails, security controls, and physical table knowledge to the LLM
- Produces accurate, business-ready SQL statements executed against the relational schema
- Provides explanations of how queries were interpreted
- Understands complex, multi-step analytical questions

### Search Features

- **Auto-suggestions**: as users type, the system suggests matching data objects, values, and keywords
- **Token-based parsing**: queries parsed into structured tokens mapped to the semantic model
- **Formula support**: search queries can include calculated fields, aggregations, and filters
- **Keyword vocabulary**: "top", "bottom", "growth", "vs", "by", "daily", "monthly", "quarterly", "yearly"
- **Search assist**: guided search experience for unfamiliar users
- **Smart search**: global search across all fields in the semantic model

## Falcon In-Memory Calculation Engine

### Core Architecture

Falcon is ThoughtSpot's proprietary in-memory database and calculation engine, purpose-built for speed at scale:

- Automatically performs integration, sorting, filtering, and aggregation across datasets
- Joins relevant datasets across different sources and runs calculations in-memory for sub-second search performance
- Materializes datasets in memory for fast joins and answer generation
- Column-based storage optimized for analytical queries

### Column Indexing

- ThoughtSpot indexes columns for fast search experiences
- Indexed values are used by the search engine for auto-suggestions and token validation
- Indexing strategy affects both search performance and memory consumption
- Index frequently searched columns (product names, regions, categories)
- Avoid indexing high-cardinality columns (transaction IDs, timestamps) -- wastes memory without improving search quality

## SpotIQ AI Engine

### Augmented Analytics

SpotIQ automatically delivers personalized insights using machine learning and generative AI.

### Algorithm Suite

SpotIQ executes dozens of insight-detection algorithms in parallel:

| Algorithm Type | Methods |
|---|---|
| **Anomaly Detection** | z-scores, median z-scores, Seasonal Hybrid ESD, Linear Regression |
| **Trend Analysis** | trend identification, seasonality detection, change point detection |
| **Comparative Analysis** | cross-dimensional comparisons to surface interesting patterns |
| **Clustering** | groups data points based on similarity |
| **Correlation Detection** | identifies relationships between measures |

### Machine Learning Integration

- Uses ThoughtSpot's parallel in-memory calculation engine to analyze billions of rows
- **Usage-based ranking ML algorithm** and reinforcement learning to find related data
- Supervised learning understands what types of insights a user prefers
- **Thumbs-up/thumbs-down feedback** on insights is factored into subsequent analyses

### Customization Parameters

| Parameter | Controls |
|---|---|
| Outlier multiplier | Sensitivity of outlier detection (higher = fewer flagged) |
| Maximum P-Value | Statistical significance threshold (lower = stricter) |
| Min rows for analysis | Minimum data points required for valid analysis |
| Max insight count | Number of insights per algorithm type |
| Exclude nulls/zeros | Whether to include empty/zero values |
| Column limits | Maximum measure and attribute columns to analyze |
| Restrict to current result | Analyze current view vs. full dataset |
| Auto-tune date boundaries | Automatic temporal scope adjustment |

## Worksheets and Models

### Worksheets (Legacy)

- Traditional semantic layer abstraction in ThoughtSpot
- Define logical views over physical tables with business-friendly column names, descriptions, and formulas
- Support joins between multiple tables with defined relationships
- Being migrated toward the newer Models construct

### Models (Current)

- Next-generation semantic layer replacing Worksheets
- Define dimensions, measures, relationships, and business logic in a governed, reusable structure
- Best practice: connect Answers and Liveboards only to Models (not directly to Tables or Views)
- Simplifies TML management since a single Model reference is easier to update than multiple table references
- Best practice: use one Model per Liveboard for all visualizations

### Spotter Optimization

When editing a Worksheet or Model with Spotter enabled, a Spotter optimization tab appears:
- Enable indexing on frequently searched columns
- Validate date format correctness
- Optimize column types (measure vs. attribute classification)
- Requires edit access to the Worksheet or Model

## ThoughtSpot Everywhere (Embedding)

### Visual Embed SDK

JavaScript/TypeScript library (`@thoughtspot/visual-embed-sdk`) for embedding ThoughtSpot components:

| Component | Description |
|---|---|
| **LiveboardEmbed** | Embed a single visualization or full Liveboard |
| **SpotterEmbed** | Embed Spotter AI search and analytics |
| **SearchEmbed** | Embed the full ThoughtSpot Search page |
| **SearchBarEmbed** | Embed only the search bar component |
| **AppEmbed** | Embed the complete ThoughtSpot application |

### Authentication for Embedding

| Method | Description | Use Case |
|---|---|---|
| **Trusted Authentication** | Host app authenticates, passes details to token service; cookie-based and cookieless modes | Production SSO (recommended) |
| **SAML SSO** | IdP integration via SAML; `inPopup: true` for popup-based auth in iframes | Enterprise SSO |
| **OIDC SSO** | OpenID Connect authentication flow | Modern IdP integration |
| **Embedded SSO** | Leverages existing IdP with seamless redirect within iframe | Existing SSO setups |
| **Basic Auth** | Username/password | Development only |

### Performance Optimization for Embedding

- Use the **prefetch** method in the SDK to preload static resources before rendering embedded components
- Call `prefetch` before `init` to cache static assets as early as possible
- Reduces initial render time significantly

### Multi-Tenancy with Orgs

- Each Org provides isolated content, users, groups, and data access
- Essential for SaaS vendors embedding ThoughtSpot in their products
- Automate Org provisioning via REST API v2.0

### REST API v2.0

- Comprehensive API covering all ThoughtSpot operations
- Interactive Playground for testing endpoints
- SDKs available in multiple programming languages
- Supports automation of content management, user provisioning, and deployments

### Custom Actions

- **Callback actions**: trigger events to the host application with data payloads
- **URL actions**: invoke external URLs with ThoughtSpot data parameters
- Available on visualizations, answers, and Liveboards
- Register and test via the Developer Portal

### Developer Portal

- Explore Visual Embed SDK and REST API SDK
- Interactive Playground for API experimentation
- Customize and rebrand UI elements
- Configure security and authentication settings
- Preview embedding experiences before deployment

## Connections to Cloud Data Warehouses

### Live Query Architecture

ThoughtSpot uses a cloud-native live query architecture that queries the data warehouse directly without moving or copying data:

| Warehouse | Features |
|---|---|
| **Snowflake** | Full support, OAuth, AWS PrivateLink, multiple configurations per connection |
| **Google BigQuery** | Native connector, multiple configuration support |
| **Databricks** | Native connector, PrivateLink, multiple configurations |
| **Amazon Redshift** | Supported connection |

### Connection Benefits

- No ETL pipelines needed for analysis
- Centralized data management and governance in the source warehouse
- Service account or OAuth credentials for authentication
- External OAuth support (Azure AD, Okta) for Snowflake

### Multiple Configuration Management

- Route different queries to different warehouse configurations (e.g., different compute sizes)
- Supported for Snowflake, Databricks, BigQuery
- Enables cost optimization by matching compute to query complexity

### dbt Integration

Certified for Amazon Redshift, Databricks, Google BigQuery, and Snowflake connections. Allows leveraging dbt models as ThoughtSpot data sources.

## TML (ThoughtSpot Modeling Language)

### Configuration as Code

YAML-based language for defining and managing all ThoughtSpot analytics objects:

- All objects (Tables, Models, Worksheets, Answers, Liveboards, Monitor alerts) can be exported/imported as TML
- Enables version control, CI/CD pipelines, and programmatic management
- Python library: `thoughtspot-tml` (PyPI) for programmatic TML manipulation

### FQN References

- The `fqn` (Fully Qualified Name) parameter disambiguates objects with the same name
- Required when multiple connections or tables share names; import fails without it
- Best practice: always add FQN before importing TML objects

### Package Management

- Deploy related objects as packages uploaded together
- Give data objects unique names within a package
- Changing TML elements (column/table names) automatically updates dependents on import

### TML API Deployment

- REST APIs support TML export, import, and validation
- Enables automated deployment pipelines across environments (dev, staging, production)

## SpotCache

### Overview

- Caching layer built on **DuckDB** (open-source columnar database) running in ThoughtSpot's cloud
- Reduces cost impact of repeated AI-driven queries against cloud data warehouses
- Maintains prepared datasets queryable without additional warehouse consumption charges
- Fixed-cost analytics for AI workloads regardless of query volume

### Configuration

- Dataset size limited to specified tiers; customers choose which datasets to cache
- Supports role-based access controls, row-level security, and column-level security
- **Security controls must be applied manually** -- not inherited from source warehouse
- Configurable refresh schedules for cache freshness

## Spotter Semantics (March 2026)

### AI-Native Semantic Layer

- Enterprise semantic layer acting as a governed translation engine between raw data and AI agents
- Built on ThoughtSpot's patented search-token architecture and TML
- Transforms raw, fragmented data into governed business context

### MCP Server

- Model Context Protocol (MCP) server connects external AI agents to ThoughtSpot's semantic layer
- Bridges disparate data sources and external tools with a single version of truth
- Enables enterprises to use preferred AI technology stacks while maintaining governed data access

## Spotter Agents (GA Early 2026)

### SpotterModel

- Data modeling assistant interpreting natural language to generate governed semantic models
- Maps relationships, dimensions, and measures with human-in-the-loop validation
- Transforms raw data into AI-ready models in minutes rather than days

### SpotterViz

- Dashboarding agent converting data into complete Liveboards from a single prompt
- Plans the data story, generates the right answers, builds the Liveboard automatically
- Handles structure, layout, and styling end-to-end

### SpotterCode

- AI-assisted coding agent integrated into developer IDEs
- Generates ThoughtSpot embedding code, TML definitions, and API integrations from natural language
- Accelerates ThoughtSpot Everywhere implementations

## Analyst Studio (February 2026)

- Native spreadsheet interface: governed, scalable data preparation
- Data mashups: combine data from multiple sources within ThoughtSpot
- Data prep agent: AI-assisted data preparation workflows
- SpotCache integration for cost-controlled analytics

## Monitor (Alerts)

### Alert Types

| Type | Trigger |
|---|---|
| **Anomaly alerts** | KPI data is statistically anomalous (SpotIQ-powered) |
| **Threshold alerts** | KPIs cross defined conditions (above, below, equals) |
| **Scheduled notifications** | Recurring on hourly/daily/weekly/monthly schedules |

- Email and in-app notification delivery
- Time zone support for scheduling
- TML support for export/import as code
