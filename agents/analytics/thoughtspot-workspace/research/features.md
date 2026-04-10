# ThoughtSpot Features and Capabilities

## Spotter AI Assistant

### Spotter 3 (Current Generation)

Spotter is ThoughtSpot's primary AI-powered analytics interface, used by over 64% of customers as their primary analyst tool (as of end of fiscal 2025, with 133% year-over-year platform growth).

- **Conversational analytics**: users interact with data through natural language questions
- **Context-aware responses**: Spotter maintains conversation context across follow-up questions
- **Visualization generation**: automatically selects appropriate chart types based on query intent
- **Drill-down capability**: supports iterative exploration through follow-up queries
- **Guided insights**: proactively surfaces related insights and follow-up questions

### Spotter Agents Suite (GA Early 2026)

ThoughtSpot expanded into **agentic analytics** with four specialized agents:

#### SpotterModel

- Data modeling assistant that interprets natural language to generate governed, reusable semantic models
- Maps relationships, dimensions, and measures with human-in-the-loop validation
- Transforms raw data into AI-ready models in minutes rather than days
- Ensures business logic consistency across the semantic layer

#### SpotterViz

- Dashboarding agent that converts data into complete Liveboards from a single prompt
- Plans the data story, generates the right answers, and builds the Liveboard automatically
- Handles structure, layout, and styling end-to-end
- Reduces Liveboard creation from hours to minutes

#### SpotterCode

- AI-assisted coding agent integrated directly into developer IDEs
- Generates ThoughtSpot embedding code, TML definitions, and API integrations from natural language prompts
- Accelerates developer workflows for ThoughtSpot Everywhere implementations

## Natural Language Search

### Core Search Capabilities

- **Search bar**: type questions in natural language to generate instant visualizations
- **Auto-suggestions**: as users type, the system suggests matching data objects, values, and analytical keywords
- **Token-based parsing**: queries are parsed into structured tokens mapped to the semantic model
- **Formula support**: search queries can include calculated fields, aggregations, and filters
- **Keyword vocabulary**: supports analytical keywords like "top", "bottom", "growth", "vs", "by", "daily", "monthly"
- **Search assist**: guided search experience for users unfamiliar with available data

### Sage-Enhanced Search

- Integrates generative AI with the deterministic search-token architecture
- Understands complex, multi-step analytical questions
- Generates SQL that respects security controls and business logic from the semantic model
- Provides explanations of how queries were interpreted

## SpotIQ Anomaly Detection and Automated Insights

### Automated Analysis

- **One-click insights**: SpotIQ Analyze runs dozens of algorithms on any answer or visualization
- **Anomaly detection**: identifies statistical outliers using z-scores, Seasonal Hybrid ESD, and Linear Regression
- **Trend detection**: surfaces trends, seasonality patterns, and change points
- **Comparative analysis**: finds interesting cross-dimensional comparisons
- **Correlation analysis**: identifies relationships between different measures

### Personalization and Learning

- Usage-based ranking algorithm prioritizes insights relevant to each user
- Reinforcement learning improves insight quality over time
- Thumbs-up/thumbs-down feedback mechanism for training the system
- Customizable algorithm parameters per analysis

### SpotIQ Custom Analysis

- Configure which algorithms to run and their parameters
- Set outlier detection sensitivity (multiplier, P-value thresholds)
- Control insight counts per algorithm type
- Include/exclude null and zero values
- Restrict analysis to current result set or expand scope
- Auto-tune date boundaries for temporal analysis

## ThoughtSpot Everywhere (Embedded Analytics)

### Embedding Components

| Component | Description |
|-----------|-------------|
| **LiveboardEmbed** | Embed a single visualization or a full Liveboard |
| **SpotterEmbed** | Embed the Spotter AI search and analytics experience |
| **SearchEmbed** | Embed the full ThoughtSpot Search page |
| **SearchBarEmbed** | Embed only the ThoughtSpot Search bar |
| **AppEmbed** | Embed the complete ThoughtSpot application |

### Visual Embed SDK

- JavaScript/TypeScript library for embedding ThoughtSpot components
- Available via npm: `@thoughtspot/visual-embed-sdk`
- Event-driven architecture with callbacks for host app integration
- Customizable styling (CSS overrides) to match host application branding
- Responsive design support for various viewport sizes

### REST API v2.0

- Comprehensive API covering all ThoughtSpot operations
- Interactive Playground for testing endpoints
- SDKs available in multiple programming languages
- Supports automation of content management, user provisioning, and deployments

### Custom Actions

- **Callback actions**: trigger events to the host application with data payloads
- **URL actions**: invoke external URLs with ThoughtSpot data parameters
- Create workflow integrations with external applications
- Available on visualizations, answers, and Liveboards

### Developer Portal

- Explore and test Visual Embed SDK and REST API SDK
- Interactive Playground for API experimentation
- Customize and rebrand UI elements
- Configure security settings and authentication
- Preview embedding experiences before deployment

## Monitor (Alerts and KPI Tracking)

### Alert Types

- **Anomaly alerts**: triggered when KPI data is statistically anomalous (powered by SpotIQ)
- **Threshold alerts**: triggered when KPIs cross defined conditions (above, below, equals)
- **Scheduled notifications**: recurring alerts on hourly, daily, weekly, or monthly schedules

### Configuration

- Time zone support for alert delivery scheduling
- Email and in-app notification delivery
- Configurable alert conditions and thresholds
- TML support for Monitor alerts (exportable/importable as code)

### Use Cases

- Track revenue, conversion rates, and operational KPIs
- Receive proactive notifications of data anomalies
- Schedule regular business metric summaries
- Create alert-driven workflows with external systems

## Liveboards (Interactive Dashboards)

### Core Capabilities

- **Interactive visualizations**: charts, tables, pivot tables, KPI cards
- **Cross-filtering**: clicking on one visualization filters others on the same Liveboard
- **Drill-down**: explore data hierarchies by clicking into chart elements
- **Filters**: global Liveboard-level filters and per-visualization filters
- **Layout management**: arrange and resize visualizations in a grid layout
- **Scheduling**: schedule Liveboard snapshots for email distribution (PDF/CSV)

### Liveboard Types

- **Standard Liveboards**: curated dashboards with multiple visualizations
- **System Liveboards**: pre-built dashboards for cluster health and usage monitoring
- **Performance Tracking Liveboard**: built-in dashboard for understanding cluster performance

### SpotterViz Integration

- Generate complete Liveboards from natural language prompts
- AI plans the data story, selects visualizations, and builds the layout
- Human review and refinement after AI generation

## Analyst Studio (2026)

### Next-Generation Data Preparation

- **Native spreadsheet interface**: governed, scalable data preparation in a familiar format
- **Data mashups**: combine data from multiple sources within ThoughtSpot
- **Data prep agent**: AI-assisted data preparation workflows
- **SpotCache**: caching layer for controlling cloud data warehouse costs

### SpotCache

- Built on DuckDB for high-performance columnar storage
- Caches frequently queried datasets to reduce warehouse compute costs
- Fixed-cost analytics for AI workloads regardless of query volume
- Role-based access controls and row/column-level security on cached data
- Tiered dataset size limits based on subscription

### AI and BI Stats Data Model

- System data model capturing product usage and query performance metrics
- Enables customers to create custom Answers and Liveboards on usage data
- Tracks query execution metrics for every query against external databases

## Spotter Semantics (March 2026)

### Enterprise Semantic Layer

- AI-native semantic layer that transforms raw data into governed business context
- Ensures consistent, contextual, and trustworthy insights across AI agents
- Built on ThoughtSpot's patented search-token architecture and TML

### MCP Server

- **Model Context Protocol (MCP) server** connects external AI agents to ThoughtSpot's semantic layer
- Bridges disparate data sources and tools with a single version of truth
- Allows enterprises to use preferred AI stacks while maintaining governed data access

### Trust and Governance

- Every natural language query produces an accurate, explainable, and actionable answer
- Audit trails for AI-generated insights
- Security controls enforced across all agent interactions

## Security and Governance Features

### Data Security

- **Row-Level Security (RLS)**: restrict data access at the row level based on user or group context
- **Column-Level Security (CLS)**: control visibility of specific columns per user/group
- **Object-level sharing**: content is only accessible when explicitly shared
- **Group-based access**: hierarchical group structures for managing permissions

### Authentication

- SAML SSO
- OIDC SSO
- Trusted authentication (token-based)
- OAuth for data warehouse connections
- Multi-factor authentication support

### Compliance

- SOC 2 Type II certified
- GDPR compliant
- AWS PrivateLink for secure network connectivity
- Data residency options via deployment region selection
