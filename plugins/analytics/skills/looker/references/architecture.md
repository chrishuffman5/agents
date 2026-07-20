# Looker Architecture Reference

## LookML Semantic Layer

LookML (Looker Modeling Language) is a declarative, dependency-based language for creating semantic data models. It defines how data should be queried, aggregated, and presented without requiring end users to write SQL.

### How LookML Works

1. Data analysts define models, views, and Explores in LookML code
2. Business users interact with Looker's Explore query builder
3. Looker's SQL generator translates LookML definitions + user selections into database-specific SQL
4. SQL is sent to the connected database; results return formatted with visualizations

### Core Principle: DRY (Don't Repeat Yourself)

SQL expressions are written once in LookML and reused across all queries, dashboards, and embedded contexts. This ensures consistent metric definitions organization-wide. When a business rule changes (e.g., revenue calculation), updating one LookML definition propagates everywhere.

---

## Core LookML Constructs

### Views

Views are the foundational building blocks representing tables or subsets of data:

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

**Key elements within views:**

| Element | Purpose | Notes |
|---|---|---|
| **Dimensions** | Individual fields/attributes (columns) | Set `hidden: yes` on implementation fields (PKs, FKs) |
| **Measures** | Aggregated calculations (COUNT, SUM, AVG, etc.) | Type `number` for measures referencing other measures |
| **Dimension Groups** | Time-based fields generating multiple timeframes | Do not include "date" in name to avoid redundant suffixes |
| **Parameters** | User-input values that dynamically alter queries | Enables dynamic field selection |
| **Filters** | Template filter fields for user input | Used with `{% condition %}` Liquid syntax |
| **Sets** | Named groupings of fields for reuse | Control `drill_fields` and `fields` parameters |

### Models

Model files define the entry point for data exploration:

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

Models specify:
- **Database connection**: Which connection to use for queries
- **Includes**: Which view and Explore files are part of the model
- **Datagroups**: Cache management policies
- **Access grants**: Permission-based field visibility

### Explores

Explores are the primary interface for business users to query data:

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

  access_filter: {
    field: orders.region
    user_attribute: allowed_region
  }
}
```

**Explore elements:**
- **Base view**: The primary table driving the Explore
- **Joins**: Relationships to other views with specified types, conditions, and cardinality
- **always_filter**: Required filters ensuring performant queries
- **conditionally_filter**: Suggested default filters that users can modify
- **access_filter**: Row-level security based on user attributes
- **aggregate_table**: Pre-aggregated data for query acceleration
- **sql_always_where**: Permanent, invisible filters applied to every query

### Derived Tables

Virtual tables defined in LookML:

**SQL Derived Tables:**
```lookml
view: daily_revenue {
  derived_table: {
    sql:
      SELECT
        DATE(created_at) AS revenue_date,
        SUM(revenue) AS total_revenue,
        COUNT(DISTINCT customer_id) AS unique_customers
      FROM orders
      GROUP BY 1 ;;
  }

  dimension: revenue_date { type: date }
  measure: total_revenue { type: sum sql: ${TABLE}.total_revenue ;; }
}
```

**Native Derived Tables:** Defined using LookML Explore query syntax instead of raw SQL.

**Persistent Derived Tables (PDTs):**
- Materialized to the database scratch schema on a schedule
- Rebuilt based on datagroup triggers or `persist_for` duration
- Support incremental builds (append-only)
- Cascading rebuilds when dependent PDTs change
- Managed via the PDT Admin panel

**Incremental PDTs:**
- Append new data rather than full rebuilds
- Use `increment_key` and `increment_offset` parameters
- Ideal for large append-only datasets

### Extends and Refinements

**Extends** create new copies with modifications:
```lookml
view: orders_extended {
  extends: [orders]
  dimension: priority_label {
    type: string
    sql: CASE WHEN ${priority} > 5 THEN 'High' ELSE 'Standard' END ;;
  }
}
```

**Refinements** modify existing objects in-place using `+` prefix:
```lookml
view: +orders {
  dimension: new_field {
    type: string
    sql: ${TABLE}.new_column ;;
  }
}
```

**Key differences:**

| Aspect | Refinements | Extends |
|---|---|---|
| Creates new object | No (modifies in place) | Yes (new copy) |
| Requires new name | No (`+existing_name`) | Yes |
| Best for | Read-only sources, Looker Blocks, layering | Multiple variants of a base |
| Additive params | joins, links, actions, access_filters, aggregate_tables | Same as refinements |
| Order | Applied in file include order; later wins | Explicit inheritance chain |

Use `final: yes` to prevent further refinements and catch conflicts at validation time.

---

## Instance Architecture

### Deployment Options

| Option | Managed By | Features | Limitations |
|---|---|---|---|
| **Looker (Google Cloud Core)** | Google | GCP IAM, VPC, Vertex AI, simplified management | No customer filesystem access |
| **Customer-Hosted (single VM)** | Customer | Full filesystem and JVM access | Manual scaling, backups |
| **Customer-Hosted (Kubernetes)** | Customer | Helm-based, horizontal scaling, HA | Operational overhead |

Google strongly recommends Kubernetes-based architecture for customer-hosted deployments.

### Internal Components

- **Application Server**: Java-based; handles web requests, API calls, query orchestration
- **In-Memory Database**: Internal metadata store for configuration, users, system state
- **Query Runner**: Generates and dispatches SQL to connected databases
- **Scheduler**: Manages scheduled deliveries, PDT builds, alerts
- **Git Integration**: Built-in version control for LookML projects

---

## Database Connections

### Direct Query Architecture

Looker does NOT extract or store source data. It generates optimized SQL and sends it to the connected database, returning results in real time. This means:
- No data warehouse within Looker
- Source database must be performant enough to handle Looker-generated queries
- Query performance depends on source database optimization (indexes, partitions, clustering)

### Supported Databases (50+)

| Category | Databases |
|---|---|
| **Google Cloud** | BigQuery, Cloud SQL, AlloyDB, Spanner |
| **Cloud Warehouses** | Snowflake, Amazon Redshift, Azure Synapse, Databricks |
| **Traditional RDBMS** | PostgreSQL, MySQL, SQL Server, Oracle |
| **Analytical** | ClickHouse, Vertica, Teradata, Exasol |

### Connection Configuration

Each connection specifies:
- Host, port, database, schema
- Authentication credentials (username/password, OAuth for BigQuery)
- SSL/TLS settings
- Connection pool size and query timeout
- PDT scratch schema for materialization
- Cost estimation and query limiting

### Per-User Connections

Looker supports per-user database credentials and OAuth-based connections (e.g., BigQuery with OAuth), enabling database-level audit trails and access control. Per-user connections create per-user caches, reducing cache reuse.

---

## Caching and PDT Mechanics

### Query Caching

Looker automatically caches SQL query results:
- Default cache retention: 1 hour
- Cache matching considers all query aspects (fields, filters, parameters, row limits)
- Cache stored on the Looker instance, not the database
- Per-user connection caching is user-specific (reduces reuse)

### Datagroups

Datagroups synchronize caching with ETL schedules:

```lookml
datagroup: etl_datagroup {
  sql_trigger: SELECT MAX(updated_at) FROM etl_log ;;
  max_cache_age: "24 hours"
}
```

- **sql_trigger**: SQL returning one row; when value changes, cache invalidates, PDTs rebuild, scheduled deliveries fire
- **interval_trigger**: Time-based trigger (e.g., "24 hours")
- **max_cache_age**: Fallback expiration if trigger check fails
- Cannot use both `sql_trigger` and `interval_trigger` (interval takes precedence)
- Applied via `persist_with` at model or Explore level

### PDT Build Process

1. Datagroup trigger detects new data
2. Looker generates CREATE TABLE statement for the PDT
3. PDT is built in the scratch schema on the connected database
4. Old PDT table is swapped out for the new one
5. Dependent PDTs cascade their rebuilds

**Scratch schema requirements:**
- Designated schema on the connected database
- Database user needs CREATE TABLE, DROP TABLE, INSERT permissions
- Separate scratch schemas for different Looker instances (prod vs QA)

---

## Embedded Analytics Architecture

### SSO Embed (Signed URL)

1. User authenticates with your application
2. Server generates a signed Looker embed URL with user-specific parameters (user attributes, permissions, model access)
3. Embed URL is loaded in an iframe in your application
4. Looker validates the signature and creates/updates a temporary embed user
5. Row-level security applied automatically via user attributes in the signed URL

### Embed SDK

JavaScript SDK for programmatic iframe embedding:
- Bi-directional communication via events
- Event listeners: filter changes, drill events, tile loads, page changes
- Programmatic control of filters, navigation, dashboard state
- Consistent user experience across embedded contexts

### Extension Framework

Custom JavaScript/React/TypeScript applications running within Looker:
- Leverages Looker's existing auth (password, LDAP, SAML, OpenID Connect)
- Full Looker API access via Extension SDK
- Pre-built UI components via Looker Components Library
- Dashboard tile extensions (Looker 24.0+)
- Spartan mode for navigation-free embedded experiences
- Marketplace distribution for shared extensions

### Security Model

All embedding methods enforce LookML-defined governance:
- Access filters applied regardless of embedding method
- User attributes drive row-level security
- Content access policies enforced universally
- Private networking support for Google Cloud Core instances

---

## Universal Semantic Layer

### Open SQL Interface

- Exposes LookML Explores as virtual database tables via JDBC
- Any JDBC-compatible tool can query the semantic layer directly
- Based on BigQuery with automatic SQL translation
- Supported by Tableau, Python, R, and custom applications

### BI Connectors

- **Tableau Connector**: GA custom-built connector for querying LookML models
- **Power BI Connector**: Direct connectivity from Power BI
- **Google Sheets Connector**: Native integration for spreadsheet-based analysis
- **Looker Studio Connector**: Connect Looker Studio reports to LookML models

### Conversational Analytics API

- Enables partner tools and custom applications to leverage the semantic layer for natural language querying
- Grounded in LookML definitions to reduce hallucination and ensure metric consistency
- Powered by Gemini with retrieval-augmented generation

---

## Looker Studio vs Looker

| Aspect | Looker | Looker Studio |
|---|---|---|
| **Type** | Enterprise BI platform | Free visualization tool |
| **Data modeling** | LookML semantic layer | Basic calculated fields, data blending |
| **Data access** | Direct query to 50+ SQL databases | 1,300+ connectors (often extracts data) |
| **Governance** | Row-level security, field-level access, centralized metrics | Share-based access control |
| **Target users** | Data teams, analysts, enterprises | Marketers, business users, SMBs |
| **Pricing** | Premium subscription (custom) | Free; optional Pro tier |
| **Scalability** | Petabyte-scale | Small-to-medium data |
| **Learning curve** | Steep (SQL/LookML required) | Low (drag-and-drop) |
| **Embedded analytics** | Full API/SDK support | Limited embedding |

### Unification (2025-2026)

- **Looker Studio in Looker**: Preview -- create Looker Studio reports within the Looker interface
- **Complementary licensing**: Each Looker license includes one Looker Studio Pro license
- **Shared governance**: Looker Studio Pro reports can inherit LookML governance

---

## Google Cloud Integration

### Native Integrations

| Service | Integration |
|---|---|
| **BigQuery** | Primary warehouse integration; optimized SQL generation, OAuth per-user, BI Engine |
| **Cloud IAM** | Identity and access management for Looker Core instances |
| **VPC / Private Networking** | Secure connectivity to data sources |
| **Vertex AI** | Powers Gemini AI features (Conversational Analytics, LookML Assistant) |
| **Cloud Monitoring** | Instance health and performance monitoring |
| **Pub/Sub** | Event-driven data pipeline integration |

### AI Features (Gemini-Powered)

| Feature | Capability | Version |
|---|---|---|
| **Conversational Analytics** | Multi-turn NL querying grounded in LookML | 25.0+ |
| **LookML Assistant** | Generate LookML code from natural language | 25.2+ |
| **Visualization Assistant** | NL chart customization | 25.2+ |
| **Code Interpreter** | Python generation for forecasting/anomaly detection | Experimental |

**Requirement:** All AI features require Looker-hosted instances (Google Cloud Core) and Vertex AI API activation.
