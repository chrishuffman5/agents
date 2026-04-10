# Looker Architecture

## Platform Overview

Looker is an enterprise business intelligence and analytics platform, now part of Google Cloud. It differentiates itself through a code-first approach to data modeling via LookML, a declarative semantic layer that sits between databases and end users. Google was recognized as a Leader in the 2025 Gartner Magic Quadrant for Analytics and Business Intelligence Platforms.

---

## LookML Semantic Layer

LookML (Looker Modeling Language) is a declarative, dependency-based language for creating semantic data models. It defines how data should be queried, aggregated, and presented without requiring end users to write SQL.

### How It Works

1. Data analysts define models, views, and explores in LookML
2. Business users interact with Looker's Explore query builder
3. Looker's SQL generator translates LookML definitions into database-specific SQL
4. Results return formatted to users with visualizations

### Core Principle

LookML follows DRY (Don't Repeat Yourself) methodology. SQL expressions are written once in LookML and reused by Looker across all queries, dashboards, and embedded contexts. This ensures consistent metric definitions organization-wide.

### Universal Semantic Layer

Looker's semantic layer has evolved into a Universal Semantic Layer, accessible beyond the Looker UI:

- **Open SQL Interface**: Exposes LookML models via JDBC, allowing any JDBC-compatible tool to query Looker's semantic layer
- **BI Connectors**: Native connectors for Tableau, Power BI, and Google Sheets
- **Conversational Analytics API**: Enables partner tools to leverage the semantic layer for AI/NL queries
- **Gemini Integration**: LookML provides context for AI-powered natural language querying

---

## Core LookML Constructs

### Views

Views are the foundational building blocks that represent tables or subsets of data from a database. Each view defines:

- **Dimensions**: Individual fields or attributes (columns) from the data
- **Measures**: Aggregated calculations (COUNT, SUM, AVG, MIN, MAX, etc.)
- **Dimension Groups**: Time-based field collections generating multiple timeframes (date, week, month, quarter, year) from a single definition
- **Parameters**: User-input values that can dynamically alter queries
- **Filters**: Template filter fields for user input
- **Sets**: Named groupings of fields for reuse

```lookml
view: orders {
  sql_table_name: schema.orders ;;

  dimension: id {
    primary_key: yes
    type: number
    sql: ${TABLE}.id ;;
  }

  dimension_group: created {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.created_at ;;
  }

  measure: total_revenue {
    type: sum
    sql: ${TABLE}.revenue ;;
    value_format_name: usd
  }

  measure: count {
    type: count
    drill_fields: [id, created_date, total_revenue]
  }
}
```

### Models

Model files define the entry point for data exploration. They specify:

- **Database connection**: Which connection to use for queries
- **Includes**: Which view and explore files are part of the model
- **Explores**: The user-facing query interfaces
- **Caching policies**: Datagroup definitions for cache management
- **Access grants**: Permission-based field visibility

```lookml
connection: "my_database"
include: "/views/**/*.view.lkml"
include: "/explores/**/*.explore.lkml"

datagroup: etl_datagroup {
  sql_trigger: SELECT MAX(etl_timestamp) FROM etl_log ;;
  max_cache_age: "24 hours"
}

persist_with: etl_datagroup
```

### Explores

Explores are the primary interface for business users to query data. An Explore combines one or more views through join relationships:

- **Base view**: The primary table driving the Explore
- **Joins**: Relationships to other views with specified join types and conditions
- **Always filters**: Required filters ensuring performant queries
- **Access filters**: Row-level security based on user attributes
- **Aggregate tables**: Pre-aggregated data for query acceleration

```lookml
explore: orders {
  join: customers {
    type: left_outer
    relationship: many_to_one
    sql_on: ${orders.customer_id} = ${customers.id} ;;
  }

  join: products {
    type: left_outer
    relationship: many_to_one
    sql_on: ${orders.product_id} = ${products.id} ;;
  }

  always_filter: {
    filters: [orders.created_date: "last 90 days"]
  }
}
```

### Derived Tables

Derived tables are virtual tables defined in LookML, either as SQL-based or native (LookML-based):

- **SQL Derived Tables**: Raw SQL queries defining a virtual table
- **Native Derived Tables**: Defined using LookML Explore query syntax
- **Persistent Derived Tables (PDTs)**: Materialized to the database on a schedule for performance
- **Incremental PDTs**: Append new data rather than full rebuilds

### Extends and Refinements

**Extends** create new copies of existing views or explores with modifications:

```lookml
view: orders_extended {
  extends: [orders]
  # Add or override fields
}
```

**Refinements** modify existing objects in-place without editing original files (uses `+` prefix):

```lookml
view: +orders {
  dimension: new_field {
    type: string
    sql: ${TABLE}.new_column ;;
  }
}
```

Key differences:
- Extends create new objects; refinements modify existing ones
- Refinements are ideal for Looker Blocks, imported files, and generated models
- Most parameters in refinements override originals; some (joins, links, access_filters) are additive
- Refinement order is determined by file include order; later refinements take precedence
- Use `final: yes` to prevent further refinements

---

## Looker Instance Architecture

### Deployment Options

#### Looker (Google Cloud Core) — Hosted by Google

- Provisioned and managed through the Google Cloud console
- Available in multiple editions (Standard, Enterprise, Embed)
- Integrated with Google Cloud IAM, VPC, and networking
- Simplified management with Google handling infrastructure
- Not available for customer-hosted or multicloud environments

#### Customer-Hosted (Looker Original)

Available deployment patterns:

1. **Single Instance**: Single VM deployment, vertically scalable, suitable for smaller workloads
2. **Multi-VM Cluster**: Multiple VMs with failover, redundancy, and horizontal scalability
3. **Kubernetes (Recommended)**: Google strongly recommends Kubernetes-based architecture using Helm charts for self-hosted deployments

Customer-hosted deployments provide full access to file system, metadata database, and JVM configurations.

### Internal Components

- **Application Server**: Java-based server handling web requests, API calls, and query orchestration
- **In-Memory Database**: Internal metadata store for configuration, users, and system state
- **Query Runner**: Generates and dispatches SQL to connected databases
- **Scheduler**: Manages scheduled deliveries, PDT builds, and alerts
- **Git Integration**: Built-in version control for LookML projects

---

## Database Connections

### Connection Model

Looker uses a direct-query architecture. It does not extract or store source data. Instead, it generates optimized SQL and sends it to the connected database, returning results in real time.

### Supported Databases

Looker supports 50+ SQL-compliant databases including:

- **Google Cloud**: BigQuery, Cloud SQL, AlloyDB, Spanner
- **Cloud Warehouses**: Snowflake, Amazon Redshift, Azure Synapse, Databricks
- **Traditional RDBMS**: PostgreSQL, MySQL, SQL Server, Oracle
- **Analytical Databases**: ClickHouse, Vertica, Teradata, Exasol

### Connection Configuration

Each connection specifies:

- Host, port, database, schema
- Authentication credentials
- SSL/TLS settings
- Connection pool size and query timeout
- PDT scratch schema for materialization
- Cost estimation and query limiting

### Per-User Connections

Looker supports per-user database credentials and OAuth-based connections (e.g., BigQuery with OAuth), enabling database-level audit trails and access control.

---

## Caching and Persistent Derived Tables (PDTs)

### Query Caching

Looker automatically caches SQL query results to reduce database load:

- Default cache retention: 1 hour
- Cache matching considers all query aspects (fields, filters, parameters, row limits)
- Per-user connection caching is user-specific (e.g., BigQuery OAuth)
- Cache is stored on the Looker instance, not the database

### Datagroups

Datagroups synchronize caching with ETL schedules:

```lookml
datagroup: etl_datagroup {
  sql_trigger: SELECT MAX(updated_at) FROM etl_log ;;
  max_cache_age: "24 hours"
}
```

- **sql_trigger**: SQL query returning one row; when value changes, cache invalidates
- **interval_trigger**: Time-based trigger (e.g., "24 hours")
- **max_cache_age**: Fallback expiration if trigger check fails
- Cannot use both sql_trigger and interval_trigger (interval_trigger takes precedence)
- Applied via `persist_with` at model or Explore level

### Persistent Derived Tables (PDTs)

PDTs materialize derived table results to the database for faster queries:

- Built in a scratch schema on the connected database
- Rebuilt based on datagroup triggers or `persist_for` duration
- Support incremental builds (append-only)
- Cascading rebuilds when dependent PDTs change
- Managed via the PDT Admin panel

---

## Looker Studio vs. Looker

| Aspect | Looker | Looker Studio |
|--------|--------|---------------|
| **Type** | Enterprise BI platform | Free visualization tool |
| **Data Modeling** | LookML semantic layer | Basic calculated fields, data blending |
| **Data Access** | Direct query to 50+ SQL databases | 1,300+ connectors (often extracts data) |
| **Governance** | Row-level security, field-level access, centralized metrics | Share-based access control |
| **Target Users** | Data teams, analysts, enterprises | Marketers, business users, SMBs |
| **Pricing** | Premium subscription (custom pricing) | Free; optional Pro tier |
| **Scalability** | Petabyte-scale datasets | Small-to-medium data |
| **Learning Curve** | Steep (SQL/LookML required) | Low (drag-and-drop) |
| **Embedded Analytics** | Full API/SDK support | Limited embedding |

### Unification Efforts (2025-2026)

Google is unifying Looker and Looker Studio:

- **Looker Studio in Looker**: Preview feature allowing Looker Studio reports to connect to LookML models
- **Complementary Licensing**: Each Looker user license includes one Looker Studio Pro license
- **Shared Semantic Layer**: Looker Studio can leverage LookML-defined metrics and governance

---

## Embedded Analytics

### Embedding Methods

1. **SSO Embed (Signed URL)**: Server generates signed URLs for authenticated access to Looks, dashboards, and Explores without separate Looker login
2. **Embed SDK**: JavaScript SDK for programmatic iframe embedding with event handling
3. **Public Embed**: Publicly accessible embedded content (no authentication required)
4. **Extension Framework**: Full custom applications running within Looker's environment

### Embed SDK Capabilities

- Bi-directional communication between host page and embedded Looker content
- Event listeners for user interactions (filter changes, drill events, tile loads)
- Programmatic control of filters, navigation, and dashboard state
- Row-level segmentation based on user attributes

### Security Model

- SSO embedding maintains all LookML-defined governance (access filters, field-level grants)
- User attributes passed through embed URLs drive row-level security
- Content access policies enforced regardless of embedding method
- Private networking support for Google Cloud core instances

### Extension Framework

The Extension Framework enables custom JavaScript/React applications within Looker:

- Built-in authentication (password, LDAP, SAML, OpenID Connect)
- Access to Looker API via Extension SDK
- Pre-built UI components via Looker Components Library
- Dashboard tile extensions (Looker 24.0+)
- Marketplace distribution for shared extensions
- Spartan mode for full-screen, navigation-free embedded experiences

---

## Google Cloud Integration

### Native Integrations

- **BigQuery**: Primary warehouse integration with optimized query generation
- **Cloud IAM**: Identity and access management for Looker Core instances
- **VPC / Private Networking**: Secure connectivity to data sources
- **Vertex AI**: Powers Gemini-based AI features (natural language queries, LookML assistant)
- **Cloud Monitoring**: Instance health and performance monitoring
- **Pub/Sub**: Event-driven data pipeline integration

### AI and Gemini Features

- **Conversational Analytics**: Natural language querying grounded in the LookML semantic layer
- **LookML Assistant**: AI-generated LookML code from natural language descriptions
- **Visualization Assistant**: Natural language chart customization
- **Code Interpreter**: Python code generation for advanced analytics (forecasting, anomaly detection)

Sources:
- [Introduction to LookML](https://docs.cloud.google.com/looker/docs/what-is-lookml)
- [Looker (Google Cloud core) overview](https://docs.cloud.google.com/looker/docs/looker-core-overview)
- [Opening up the Looker semantic layer](https://cloud.google.com/blog/products/business-intelligence/opening-up-the-looker-semantic-layer)
- [Customer-hosted architecture solutions](https://cloud.google.com/looker/docs/best-practices/customer-hosted-overview)
- [Caching queries](https://docs.cloud.google.com/looker/docs/caching-and-datagroups)
- [Looker Extension Framework](https://docs.cloud.google.com/looker/docs/intro-to-extension-framework)
- [LookML refinements](https://docs.cloud.google.com/looker/docs/lookml-refinements)
- [Looker vs Looker Studio 2026 Comparison](https://improvado.io/blog/looker-vs-looker-studio-comparison)
- [Looker Embedded Analytics 2026](https://qrvey.com/blog/looker-embedded-analytics/)
