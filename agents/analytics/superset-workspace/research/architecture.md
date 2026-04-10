# Apache Superset Architecture

## Overview

Apache Superset is a modern, open-source data exploration and visualization platform built on a Python (Flask) backend with a React frontend. It provides an intuitive interface for exploring data, building charts, and assembling interactive dashboards without requiring code.

## Core Architecture Components

### Backend: Flask Application

Superset's backend is a Python application built on **Flask** and **Flask-AppBuilder (FAB)**. FAB provides the foundational application framework including authentication, user management, permissions, and roles.

Key backend components:

- **Flask Application Server**: Serves the API layer and handles business logic
- **SQLAlchemy ORM**: Provides database abstraction for both the metadata store and connected analytical databases
- **Marshmallow**: Handles serialization/deserialization of API data
- **Flask-Caching**: Manages multi-tier caching for queries, charts, and metadata
- **Flask-Migrate (Alembic)**: Manages metadata database schema migrations

The backend exposes a comprehensive REST API that the React frontend consumes.

### Frontend: React Application

The frontend is a single-page application (SPA) built with:

- **React**: Core UI framework
- **Redux**: State management
- **Ant Design (v5 as of 6.0)**: UI component library
- **Apache ECharts**: Primary charting library (replaced NVD3 and deck.gl as the default)
- **Webpack**: Module bundling and build system

The frontend is compiled as static assets and served by the Flask backend or a reverse proxy (Nginx).

### Metadata Database

Superset requires a metadata database to store:

- Dashboard and chart definitions
- Database connection configurations
- User accounts, roles, and permissions
- Saved queries and query history
- Annotation layers and CSS templates

Supported metadata databases: **PostgreSQL** (recommended for production), **MySQL**, and **SQLite** (development only).

## SQL Lab

SQL Lab is Superset's integrated SQL IDE providing:

- **Multi-tab query editor** with syntax highlighting and autocompletion
- **Query execution** against any connected database
- **Query history** with saved queries and sharing
- **Result preview** with inline data exploration
- **Async query execution** via Celery for long-running queries
- **Query cost estimation** (supported databases)
- **Virtual dataset creation** from SQL queries
- **Parameter support** via Jinja templating

SQL Lab supports both synchronous and asynchronous query modes. When async is enabled, queries are dispatched to Celery workers and results are stored in a configurable results backend.

## Chart Types and Visualization

Superset ships with **40+ pre-installed visualization types** via a plugin architecture. The primary charting engine is **Apache ECharts**.

### Chart Categories

| Category | Chart Types |
|----------|-------------|
| **Time Series** | Line, Area, Bar, Scatter, Smooth Line, Step Line |
| **Categorical** | Bar Chart, Pie, Donut, Sunburst, Treemap |
| **Distribution** | Histogram, Box Plot, Violin Plot |
| **Correlation** | Scatter Plot, Bubble Chart, Heatmap |
| **Geospatial** | World Map, Country Map, deck.gl layers (Arc, Hex, Path, Polygon, Scatter, Grid, Heatmap, Contour) |
| **Table** | Table, Pivot Table, Time-series Table |
| **Flow** | Sankey, Chord Diagram |
| **Composition** | Treemap, Sunburst, Partition |
| **Statistical** | Big Number, Big Number with Trendline |
| **Text/Markup** | Handlebars, Markdown |
| **Other** | Calendar Heatmap, Word Cloud, Funnel, Gauge, Radar, Waterfall, Mixed Timeseries |

### Plugin Architecture

Charts are implemented as **npm packages** following a plugin interface, allowing:

- Custom chart development and registration
- Third-party visualization plugins
- Per-chart ECharts theme customization (as of 6.0)

## Dashboards

Dashboards are composed of:

- **Charts/Slices**: Individual visualizations arranged in a grid layout
- **Filters**: Native filter bar with cross-filtering support
- **Tabs**: Organize content into tabbed sections
- **Markdown**: Embedded text, images, and HTML
- **Dividers and Headers**: Layout organization elements

Dashboard features:

- **Drag-and-drop layout builder** with responsive grid
- **Native filters** with cascading, dependent, and time-range filters
- **Cross-filtering**: Click on a chart element to filter the entire dashboard
- **Periodic refresh**: Auto-refresh at configurable intervals
- **Dashboard-level caching** with warm-up support
- **Embedding**: Embed dashboards in external applications via iframe with guest tokens
- **Export/Import**: JSON-based dashboard export for version control and migration
- **Dark mode support** (6.0): Full dark theme across all visualizations

## Database Connectivity

Superset connects to analytical databases via **SQLAlchemy** and database-specific drivers. It does not ship bundled with drivers -- they must be installed separately.

### Supported Databases (50+)

**Cloud Data Warehouses**: Snowflake, BigQuery, Redshift, Databricks, Azure Synapse

**OLAP/Analytical**: ClickHouse, Apache Druid, Apache Pinot, StarRocks, Doris, Apache Kylin, Firebolt

**SQL Engines**: Trino, Presto, Apache Hive, Apache Spark SQL, Apache Impala, Dremio

**Traditional RDBMS**: PostgreSQL, MySQL, Microsoft SQL Server, Oracle, IBM DB2, MariaDB

**Others**: DuckDB, Elasticsearch, Apache Drill, CockroachDB, Vertica, Teradata, Netezza, SingleStore, SAP HANA, Exasol, YDB, OceanBase, RisingWave

**File-based**: Google Sheets, Excel (via Shillelagh)

### Connection Configuration

Each database connection is configured with:

- SQLAlchemy URI (connection string)
- Optional SSH tunnel parameters
- Schema-level permissions
- Query cost estimation settings
- Async query support toggle
- Connection pool settings
- Impersonation configuration

## Caching Layer

Superset implements a **multi-tier caching architecture** using Flask-Caching.

### Cache Types

| Cache | Purpose | Configuration Key |
|-------|---------|-------------------|
| **Metadata Cache** | Database metadata, table lists, schema info | `CACHE_CONFIG` |
| **Data/Chart Cache** | Query results for chart rendering | `DATA_CACHE_CONFIG` |
| **Dashboard Filter State** | Active filter selections | `FILTER_STATE_CACHE_CONFIG` |
| **Explore Form Data** | Chart explore form state | `EXPLORE_FORM_DATA_CACHE_CONFIG` |
| **SQL Lab Results** | Async query result storage | `RESULTS_BACKEND` |
| **Thumbnail Cache** | Dashboard/chart preview thumbnails | `THUMBNAIL_CACHE_CONFIG` |

### Cache Backends

- **Redis** (recommended for production): Most common, supports distributed deployments
- **Memcached**: Alternative in-memory cache
- **FileSystem**: Local file-based caching
- **SimpleCache**: In-memory, single-process only (development)
- **S3**: For SQL Lab result storage at scale

### Cache Warm-Up

Superset supports scheduled cache warm-up to pre-populate dashboard caches, typically run via Celery beat schedules to ensure dashboards load instantly during peak hours.

## Async Queries with Celery

Superset uses **Celery** for asynchronous task processing, critical for production deployments.

### Components

```
+-------------------+     +-------------+     +------------------+
| Superset Web App  |---->|  Redis/     |---->| Celery Worker(s) |
| (Flask)           |     |  RabbitMQ   |     | (Task Execution) |
+-------------------+     |  (Broker)   |     +------------------+
                          +-------------+
                                |
                          +-------------+
                          | Celery Beat |
                          | (Scheduler) |
                          +-------------+
```

### Task Types

- **Async SQL Lab queries**: Long-running queries dispatched to workers
- **Report scheduling**: Scheduled dashboard/chart snapshots via email or Slack
- **Alert monitoring**: Data-driven alerts based on SQL conditions
- **Cache warm-up**: Periodic cache pre-population
- **Thumbnail generation**: Dashboard and chart preview images
- **Log pruning**: Cleanup of query and access logs

### Configuration

```python
class CeleryConfig:
    broker_url = "redis://redis:6379/0"
    result_backend = "redis://redis:6379/1"
    imports = ("superset.sql_lab", "superset.tasks.scheduler")
    task_annotations = {
        "sql_lab.get_sql_results": {"rate_limit": "100/s"},
    }
    beat_schedule = {
        "reports.scheduler": {
            "task": "reports.scheduler",
            "schedule": crontab(minute="*", hour="*"),
        },
        "reports.prune_log": {
            "task": "reports.prune_log",
            "schedule": crontab(minute=0, hour=0),
        },
    }

CELERY_CONFIG = CeleryConfig
```

### Global Async Queries (GAQ)

GAQ enables async chart rendering on dashboards (not just SQL Lab):

- Requires Redis, Celery, and a WebSocket server
- Uses JWT tokens for secure async result delivery
- Charts poll for completion or receive WebSocket notifications
- Prevents UI blocking on slow queries

## Jinja Templating

Superset supports **Jinja2 templating** in SQL queries, enabling dynamic and parameterized SQL. Must be enabled via the `ENABLE_TEMPLATE_PROCESSING` feature flag.

### Built-in Macros

| Macro | Description |
|-------|-------------|
| `{{ current_username() }}` | Currently logged-in username |
| `{{ current_user_id() }}` | Currently logged-in user ID |
| `{{ current_user_email() }}` | Currently logged-in user email |
| `{{ url_param('key') }}` | URL parameter value |
| `{{ cache_key_wrapper('value') }}` | Cache key generation helper |
| `{{ filter_values('column') }}` | Active filter values for a column |
| `{{ from_dttm }}` | Start of time range filter |
| `{{ to_dttm }}` | End of time range filter |
| `{{ columns }}` | List of requested columns |
| `{{ groupby }}` | List of group-by columns |
| `{{ metrics }}` | List of requested metrics |

### Parameter Support

SQL Lab supports defining parameters as JSON and referencing them in queries:

```sql
-- Parameters: {"schema": "public", "limit": 100}
SELECT * FROM {{ schema }}.my_table LIMIT {{ limit }}
```

### Custom Jinja Context

Administrators can register custom Jinja context processors:

```python
JINJA_CONTEXT_ADDONS = {
    "my_custom_macro": lambda: "custom_value",
}
```

## Security Model

Superset's security is built on Flask-AppBuilder (FAB) with a comprehensive RBAC system.

### Authentication Methods

| Method | Config Key | Description |
|--------|-----------|-------------|
| **Database** | `AUTH_DB` | Built-in username/password (default) |
| **LDAP** | `AUTH_LDAP` | LDAP/Active Directory integration |
| **OAuth 2.0** | `AUTH_OAUTH` | OAuth providers (Google, GitHub, Azure AD, Okta, Keycloak) |
| **OpenID Connect** | `AUTH_OID` | OpenID Connect protocol |
| **Remote User** | `AUTH_REMOTE_USER` | Header-based SSO (e.g., behind a proxy) |

### Role-Based Access Control (RBAC)

**Built-in Roles**:

| Role | Access Level |
|------|-------------|
| **Admin** | Full system access, user management, all data sources |
| **Alpha** | Access all data sources, create charts/dashboards, no admin functions |
| **Gamma** | Access only explicitly granted data sources |
| **sql_lab** | Access to SQL Lab (combinable with other roles) |
| **Public** | Access for unauthenticated users (disabled by default) |

**Custom Roles**: Administrators can create custom roles with granular permissions at the database, schema, dataset, and dashboard level.

**Group-Based Access Control** (6.0): Assign roles to user groups rather than individual users, with group-based access for databases, datasources, and schemas.

### Row-Level Security (RLS)

Define SQL filter clauses applied per role or user to restrict data visibility:

```python
# Example: Users only see their department's data
# RLS Rule: department_id = {{ current_user_id() }}
```

### OAuth Role Mapping

```python
AUTH_ROLES_MAPPING = {
    "superset_users": ["Gamma", "sql_lab"],
    "superset_admins": ["Admin"],
    "data_analysts": ["Alpha", "sql_lab"],
}
AUTH_ROLES_SYNC_AT_LOGIN = True
```

## Distributed Coordination

Superset 6.0 introduced distributed coordination capabilities:

- **Distributed Locking**: Moves lock operations from metadata database to Redis, reducing metastore load
- **Real-time Event Notifications**: Pub/sub messaging for task abort signals and completion notifications
- **WebSocket Server**: Enables real-time communication for async query completion

## Deployment Architecture (Production)

```
                    +------------------+
                    |  Load Balancer   |
                    |  (Nginx/ALB)     |
                    +--------+---------+
                             |
              +--------------+--------------+
              |              |              |
     +--------v---+  +------v-----+  +-----v------+
     | Web Server |  | Web Server |  | Web Server |
     | (Gunicorn) |  | (Gunicorn) |  | (Gunicorn) |
     +--------+---+  +------+-----+  +-----+------+
              |              |              |
              +--------------+--------------+
                             |
         +-------------------+-------------------+
         |                   |                   |
  +------v------+    +------v------+    +-------v-------+
  | Metadata DB |    |    Redis    |    | Celery Workers |
  | (PostgreSQL)|    | (Cache +   |    | + Beat         |
  |             |    |  Broker)   |    |                |
  +-------------+    +------------+    +----------------+
                                              |
                                    +---------v---------+
                                    | Analytical DBs    |
                                    | (Snowflake, BQ,   |
                                    |  ClickHouse, etc.)|
                                    +-------------------+
```

### Kubernetes Deployment

The official **Helm chart** deploys a minimum of 5 workloads:

1. **Superset Web Server** (Gunicorn/uWSGI): Serves the Flask app and API
2. **Celery Worker(s)**: Execute async tasks
3. **Celery Beat**: Task scheduler
4. **WebSocket Server** (Node.js): Real-time async query notifications
5. **Init Job**: Database migration and initialization

Each component can scale independently via Kubernetes HPA (Horizontal Pod Autoscaler).

## Sources

- [Superset Architecture Documentation](https://superset.apache.org/admin-docs/installation/architecture/)
- [Apache Superset 6.0 Release](https://preset.io/blog/apache-superset-6-0-release/)
- [Caching Configuration](https://superset.apache.org/admin-docs/configuration/cache/)
- [Async Queries via Celery](https://superset.apache.org/docs/configuration/async-queries-celery/)
- [SQL Templating](https://superset.apache.org/user-docs/using-superset/sql-templating/)
- [Security Configurations](https://superset.apache.org/docs/security/)
- [Kubernetes Deployment](https://superset.apache.org/admin-docs/installation/kubernetes/)
- [Connecting to Databases](https://superset.apache.org/user-docs/6.0.0/configuration/databases/)
