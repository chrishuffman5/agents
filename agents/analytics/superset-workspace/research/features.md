# Apache Superset 6.x Features

## Overview

Apache Superset 6.0.0 was released on December 4, 2025, representing the most significant visual and architectural transformation in Superset's history. This release includes contributions from 155 contributors, including 101 first-time contributors.

## Major 6.0 Features

### 1. Complete Design System Overhaul (Ant Design v5)

Superset 6.0 replaced the previous Ant Design v4 component library with **Ant Design v5**, bringing:

- Modern UI component refresh across the entire application
- Consistent design language and interaction patterns
- Improved accessibility and responsiveness
- Foundation for the new theming architecture

### 2. Theming Architecture and Dark Mode

The new theming system is one of the headline features of 6.0:

- **Semantic token system**: Replaces hardcoded colors with semantic design tokens
- **Theme management UI**: Create, edit, import, export, and apply themes through the admin interface
- **System-wide or per-dashboard themes**: Apply themes globally or customize individual dashboards
- **Dark mode**: Full dark theme support across all 80+ chart types with dark-themed thumbnails and examples
- **ECharts theme customization**: Customize ECharts visualizations globally or per chart type through the theme system

### 3. URL Prefix Deployment

Superset can now be deployed under configurable URL prefixes:

- Deploy at paths like `/analytics` or `/superset`
- Critical for organizations running behind reverse proxies
- Enables cleaner multi-tenant deployments
- Better integration with existing application ecosystems

### 4. Hierarchical Folder System for Datasets

A new folder hierarchy for organizing dataset columns and metrics:

- Organize metrics and columns into logical groups within the Explore view
- Addresses the previous 50-item display limitation
- Makes working with complex, wide datasets significantly more manageable
- Drag-and-drop folder organization

### 5. Group-Based Access Control

Simplified permission management at scale:

- Assign roles to user groups rather than individual users
- Group-based access control for databases, datasources, and schemas
- Significantly reduces administrative overhead in large organizations
- Integrates with external identity providers (LDAP/OAuth group mappings)

### 6. Distributed Coordination

Infrastructure improvements for reliability and performance:

- **Distributed locking via Redis**: Moves lock operations from the metadata database to Redis
- **Real-time event notifications**: Pub/sub messaging for task abort signals and completion notifications
- Improved performance and reduced metastore load at scale

## Data Exploration Features

### SQL Lab

- Multi-tab SQL editor with syntax highlighting and autocompletion
- Async query execution via Celery for long-running queries
- Query history, saved queries, and query sharing
- Inline result exploration and visualization
- Query cost estimation (database-dependent)
- Virtual dataset creation from SQL queries
- Jinja templating for dynamic SQL with parameterized queries
- Schema browser with table/column metadata inspection
- Result set download (CSV, Excel)

### Chart Explore View

- No-code chart builder with drag-and-drop metric/dimension selection
- 40+ built-in visualization types via plugin architecture
- Advanced analytics: rolling averages, time comparisons, resampling
- Annotation layers for overlaying events on time series
- Custom SQL metric definitions
- Post-processing operations (pivot, sort, contribution, etc.)

### Native Filters

- Dashboard-level filter bar with persistent state
- Filter types: value, time range, time column, time grain, numerical range
- Cascading/dependent filters (filter B depends on filter A selection)
- Cross-filtering: click on chart elements to filter the entire dashboard
- Pre-filter data with SQL expressions
- Scope control: apply filters to specific charts or tabs

## Dashboard Features

### Layout and Design

- Drag-and-drop grid-based layout builder
- Responsive design with configurable column widths
- Tabs and nested tabs for content organization
- Markdown components for text, images, and HTML
- Dividers and headers for visual organization
- Dashboard-level CSS overrides

### Interactivity

- Cross-filtering between charts
- Drill-down and drill-by capabilities
- Chart-level time range overrides
- Periodic auto-refresh at configurable intervals
- Full-screen mode for presentations
- Dashboard-level annotations

### Sharing and Collaboration

- Short URL sharing with filter state preservation
- Dashboard export/import as JSON for version control
- Favoriting and tagging for organization
- Access control at the dashboard level
- Certification workflow for verified dashboards

## Embedding and Integration

### Embedded SDK

- JavaScript SDK (`@superset-ui/embedded-sdk`) for iframe-based embedding
- Embed dashboards in external applications with your own authentication
- Guest tokens with configurable permissions and Row-Level Security
- Custom styling via CSS overrides
- Domain whitelisting for security

### API Access

- Comprehensive REST API for programmatic access
- CRUD operations for dashboards, charts, datasets, databases
- Query execution API
- Thumbnail generation API
- Export/import via API

### Embedding Architecture

```
+-------------------+     +------------------+     +------------------+
| Host Application  |---->| Superset Backend |---->| Guest Token      |
| (Your App)        |     | (Flask API)      |     | (JWT + RLS)      |
+-------------------+     +------------------+     +------------------+
        |                                                   |
        v                                                   v
+-------------------+                              +------------------+
| Embedded iframe   |<-----------------------------|  Superset        |
| (Superset SDK)    |                              |  Dashboard       |
+-------------------+                              +------------------+
```

## Semantic Layer

### Current Approach (Thin Semantic Layer)

Superset's semantic layer is intentionally thin, built around two dataset types:

- **Physical Datasets**: Direct mapping to a database table or view
- **Virtual Datasets**: Defined by a SQL query (created from SQL Lab)

Each dataset defines:

- **Metrics**: Aggregation expressions (SUM, COUNT, AVG, custom SQL)
- **Calculated Columns**: SQL-derived columns
- **Column metadata**: Types, descriptions, groupability, filterability
- **Certification**: Mark datasets as verified/trusted

### Semantic Layer Enhancements (SIP-182)

An active proposal (SIP-182, September 2025) introduces:

- **"Explorable" interface**: A Python protocol for external semantic layer integration
- **New connection class**: Dedicated connections for semantic layers and data modeling systems
- **Integration with external tools**: Better support for Cube, dbt Semantic Layer, Metricflow, and similar systems
- Moves beyond the current dataset-centric model

### Integration with External Semantic Layers

Superset integrates with external semantic layers through:

- **Cube**: SQL API integration as a pseudo-database connection
- **dbt Metrics**: Via dbt's semantic layer and Metricflow
- **LookML**: Through Looker's SQL generation

## Alerting and Reporting

### Scheduled Reports

- Schedule dashboard or chart snapshots via email or Slack
- Cron-based scheduling via Celery Beat
- PDF, PNG, or CSV attachment formats
- Owner and recipient management
- Configurable grace periods and retry logic

### Data Alerts

- SQL-based alert conditions
- Threshold monitoring with configurable operators
- Notification channels: email, Slack
- Alert history and log tracking

## Database Connectivity (50+ Databases)

Superset connects to databases via SQLAlchemy and database-specific drivers:

| Category | Databases |
|----------|-----------|
| **Cloud Warehouses** | Snowflake, BigQuery, Redshift, Databricks, Azure Synapse |
| **OLAP Engines** | ClickHouse, Apache Druid, Apache Pinot, StarRocks, Doris, Firebolt |
| **Query Engines** | Trino, Presto, Apache Hive, Apache Spark SQL, Dremio |
| **RDBMS** | PostgreSQL, MySQL, SQL Server, Oracle, DB2, MariaDB, CockroachDB |
| **Embedded** | DuckDB, SQLite |
| **Search/NoSQL** | Elasticsearch, Apache Kylin |
| **File-based** | Google Sheets, Excel |

## Recent Quality-of-Life Improvements (2025)

- Customizable tooltips for deck.gl visualizations using Handlebars templates
- Area and bar sparkline types in Time Series Table
- Alphabetical legend sorting across seven chart types
- Redux selector memoization for 50+ chart dashboards (PR #36119)
- Improved dashboard responsiveness and reduced re-renders
- Enhanced chart gallery with dark-themed thumbnails

## Feature Flags

Superset uses feature flags to control experimental and optional features:

```python
FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,       # Jinja templating
    "DASHBOARD_CROSS_FILTERS": True,          # Cross-filtering
    "DASHBOARD_NATIVE_FILTERS": True,         # Native filter bar
    "EMBEDDED_SUPERSET": True,                # Dashboard embedding
    "ALERT_REPORTS": True,                    # Alerts and reports
    "GLOBAL_ASYNC_QUERIES": True,             # Async chart rendering
    "ENABLE_EXPLORE_DRAG_AND_DROP": True,     # Drag-and-drop explore
    "DASHBOARD_VIRTUALIZATION": True,         # Virtual scroll for large dashboards
    "DRILL_BY": True,                         # Drill-by functionality
    "DRILL_TO_DETAIL": True,                  # Drill-to-detail
}
```

## Sources

- [Apache Superset 6.0 Release](https://preset.io/blog/apache-superset-6-0-release/)
- [Apache Superset Community Update: December 2025](https://preset.io/blog/apache-superset-community-update-december-2025/)
- [Superset 6.0 Introduction](https://superset.apache.org/docs/6.0.0/intro/)
- [Superset Embedded SDK](https://github.com/apache/superset/blob/master/superset-embedded-sdk/README.md)
- [Understanding the Superset Semantic Layer](https://preset.io/blog/understanding-superset-semantic-layer/)
- [SIP-182: Semantic Layer Support](https://github.com/apache/superset/issues/35003)
- [Connecting to Databases](https://superset.apache.org/user-docs/6.0.0/configuration/databases/)
