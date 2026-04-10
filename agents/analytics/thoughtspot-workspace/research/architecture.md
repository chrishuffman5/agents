# ThoughtSpot Architecture

## Platform Overview

ThoughtSpot is an AI-driven analytics platform built around search-based data exploration. Originally founded in 2012, the platform has evolved from a search-driven BI tool into an agentic analytics platform that combines natural language search, AI-powered insights, and embedded analytics capabilities.

## Search-Based Analytics Engine

ThoughtSpot's core innovation is its **search-driven analytics** paradigm. Users type natural language questions into a search bar to generate visualizations and insights without requiring knowledge of SQL, query languages, or drag-and-drop interfaces.

### Search Token Architecture

- ThoughtSpot uses a **patented search-token architecture** that parses natural language queries into structured tokens
- Tokens map to data objects (columns, tables, measures, attributes) defined in the semantic layer
- The system translates tokenized queries into deterministic SQL rather than relying solely on LLM-based text-to-SQL generation
- This hybrid approach provides accuracy guardrails while supporting conversational interaction

### Sage Search Engine

- **ThoughtSpot Sage** integrates generative AI (GPT-based models) with the search-token architecture
- Sage supplements LLM algorithms with metadata including attribute columns, synonyms, indexed values, formulas, join paths, and analytical keywords
- When questions are typed into the search bar, ThoughtSpot's data model provides guardrails, security controls, and physical table knowledge to the LLM
- The result is an accurate, business-ready SQL statement executed against the relational schema

## Falcon In-Memory Calculation Engine

### Core Architecture

- **Falcon** is ThoughtSpot's proprietary in-memory database and calculation engine, purpose-built for speed at scale
- Automatically performs integration, sorting, filtering, and aggregation across datasets from the full network stack
- Joins relevant datasets across different sources and runs calculations in-memory for sub-second search performance
- Materializes datasets in memory to enable fast joins, additional searches, and answer generation

### Column Indexing

- ThoughtSpot indexes columns for fast search experiences
- Indexed values are used by the search engine to provide auto-suggestions and validate query tokens
- Indexing strategy affects both search performance and memory consumption

## SpotIQ AI Engine

### Augmented Analytics

SpotIQ is ThoughtSpot's augmented analytics engine that automatically delivers personalized insights using machine learning and generative AI.

### Algorithm Suite

SpotIQ executes dozens of insight-detection algorithms in parallel, including:

- **Outlier/Anomaly Detection**: z-scores, median z-scores, Seasonal Hybrid ESD, Linear Regression
- **Trend Analysis**: identifies trends, seasonality, and change points in time-series data
- **Comparative Analysis**: cross-dimensional comparisons to surface interesting patterns
- **Clustering**: groups data points based on similarity
- **Correlation Detection**: identifies relationships between measures

### Machine Learning Integration

- Uses ThoughtSpot's parallel in-memory calculation engine to analyze billions of rows
- Employs a **usage-based ranking ML algorithm** and reinforcement learning to find related data
- Supervised learning understands what types of insights and algorithms a user prefers
- User feedback (thumbs-up/thumbs-down) on insights is factored into subsequent analyses

### Customization Parameters

- **Outlier parameters**: minimum rows, detection multiplier, maximum P-Value
- **Insight counts**: max outlier, seasonality, and linear regression insights
- **General settings**: exclude nulls/zeros, restrict to current result set, auto-tune date boundaries
- **Column limits**: maximum number of measure and attribute columns to analyze

## Worksheets and Models

### Worksheets (Legacy)

- Worksheets are the traditional semantic layer abstraction in ThoughtSpot
- Define logical views over physical tables with business-friendly column names, descriptions, and formulas
- Support joins between multiple tables with defined relationships
- Being migrated toward the newer **Models** construct

### Models

- **Models** are the next-generation semantic layer replacing Worksheets
- Define dimensions, measures, relationships, and business logic in a governed, reusable structure
- Best practice: connect Answers and Liveboards only to Models (not directly to Tables or Views)
- Simplifies TML management since a single Model reference is easier to update than multiple table references
- Best practice: use one Model per Liveboard for all visualizations

### Spotter Optimization

- When editing a Worksheet or Model with Spotter enabled, a **Spotter optimization tab** appears
- Enables indexing, ensures date format correctness, and optimizes column types
- Requires edit access to the Worksheet or Model

## ThoughtSpot Everywhere (Embedding)

### Visual Embed SDK

ThoughtSpot Everywhere is the embedded analytics platform, powered by the **Visual Embed SDK** (JavaScript/TypeScript library):

- **LiveboardEmbed**: embed a single visualization or full Liveboard
- **SpotterEmbed**: embed Spotter AI search and analytics
- **SearchEmbed**: embed the ThoughtSpot Search page
- **SearchBarEmbed**: embed only the search bar component
- **AppEmbed**: embed the full ThoughtSpot application experience

### Authentication for Embedding

- **Trusted Authentication**: most seamless SSO method; host app authenticates users and passes details to a token request service; supports cookie-based and cookieless modes
- **SAML SSO**: integrates with existing IdP via SAML; supports popup-based auth flow via `inPopup` setting
- **OIDC SSO**: OpenID Connect authentication flow
- **Embedded SSO**: leverages existing IdP setup with seamless redirect within the ThoughtSpot iframe
- **Basic Authentication**: username/password (development only)

### Multi-Tenancy with Orgs

- ThoughtSpot supports multi-tenant deployments through the **Orgs** feature
- Each Org provides isolated content, users, groups, and data access
- Essential for SaaS vendors embedding ThoughtSpot in their products

### Developer Tools

- **Developer Portal**: explore Visual Embed SDK, REST API SDK, and interactive Playground
- **REST API v2.0**: comprehensive API with Playground for testing endpoints
- **REST API SDKs**: available in multiple languages
- **Custom Actions**: trigger callbacks to host applications or invoke URLs to send ThoughtSpot data externally

### Performance Optimization for Embedding

- Use the **prefetch** method in the SDK to preload static resources before rendering embedded components
- Call prefetch before `init` to cache static assets as early as possible

## Connections to Cloud Data Warehouses

### Live Query Architecture

ThoughtSpot uses a **cloud-native live query architecture** that queries the data warehouse directly without moving or copying data:

- **Snowflake**: full support including OAuth, AWS PrivateLink, multiple configurations per connection
- **Google BigQuery**: native connector with multiple configuration support
- **Databricks**: native connector with PrivateLink and multiple configuration support
- **Amazon Redshift**: supported connection
- **Additional connectors**: various JDBC/ODBC-based connections

### Connection Benefits

- No ETL pipelines needed for analysis
- Centralized data management and governance in the source warehouse
- Service account or OAuth credentials for authentication
- External OAuth support (Microsoft Azure AD, Okta) for Snowflake

### dbt Integration

- Certified for Amazon Redshift, Databricks, Google BigQuery, and Snowflake connections
- Allows leveraging dbt models as ThoughtSpot data sources

## TML (ThoughtSpot Modeling Language)

### Configuration as Code

TML is ThoughtSpot's YAML-based language for defining and managing analytics objects as code:

- All ThoughtSpot objects (Tables, Models, Worksheets, Answers, Liveboards, Monitor alerts) can be exported/imported as TML
- Enables version control, CI/CD pipelines, and programmatic management
- **Python library** (`thoughtspot-tml` on PyPI) for programmatic TML manipulation

### FQN References

- The `fqn` (Fully Qualified Name) parameter disambiguates objects with the same name
- Required when multiple connections or tables share names; import fails without it
- Best practice: always add FQN before importing TML objects

### Package Management

- Deploy related objects as "packages" uploaded together
- Give data objects unique names within a package
- Changing TML elements (column/table names) automatically updates dependents on import

### TML API Deployment

- REST APIs support TML export, import, and validation
- Enables automated deployment pipelines across environments (dev, staging, production)

## ThoughtSpot Cloud vs. On-Premises

### ThoughtSpot Cloud (SaaS)

- Fully managed cloud service hosted by ThoughtSpot
- Live query connections to cloud data warehouses (no data movement)
- Automatic updates and patches
- SpotCache for controlled caching with fixed cloud costs
- Continuous release cycle with monthly feature updates

### ThoughtSpot Software (On-Premises)

- Self-managed deployment on customer infrastructure
- Includes the **Falcon in-memory database** for local data storage
- Requires cluster management, hardware provisioning, and manual upgrades
- Network connectivity options include direct connections and PrivateLink
- Suitable for organizations with strict data residency or compliance requirements

### SpotCache (Cloud)

- Caching layer built on **DuckDB** (open-source columnar database) running in ThoughtSpot's cloud
- Reduces cost impact of repeated AI-driven queries against cloud data warehouses
- Maintains prepared datasets queryable without additional warehouse consumption charges
- Dataset size limited to specified tiers; customers choose which datasets to cache
- Supports role-based access controls, row-level security, and column-level security on cached data
- Security controls must be applied manually (not inherited from source warehouse)

## Spotter Semantics (2026)

### AI-Native Semantic Layer

- **Spotter Semantics** is an enterprise semantic layer acting as a governed translation engine between raw data and AI agents
- Built on ThoughtSpot's patented search-token architecture and TML
- Transforms raw, fragmented data into governed business context that AI agents can reliably understand

### MCP Server

- ThoughtSpot provides a **Model Context Protocol (MCP) server** for connecting external AI agents to ThoughtSpot's semantic layer
- Serves as a bridge between disparate data sources and external tools
- Enables customers to use their preferred AI technology stack while maintaining a single version of truth
