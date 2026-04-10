# Apache Superset Platform Architecture

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

Superset requires a metadata database to store dashboard/chart definitions, database connection configurations, user accounts/roles/permissions, saved queries, annotation layers, and CSS templates.

Supported: **PostgreSQL** (recommended for production), **MySQL**, and **SQLite** (development only -- no concurrent writes).

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

### Jinja Templating

Superset supports **Jinja2 templating** in SQL queries, enabling dynamic and parameterized SQL. Must be enabled via the `ENABLE_TEMPLATE_PROCESSING` feature flag.

**Built-in Macros:**

| Macro | Description |
|---|---|
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

**Parameter Support:**

```sql
-- Parameters: {"schema": "public", "limit": 100}
SELECT * FROM {{ schema }}.my_table LIMIT {{ limit }}
```

**Custom Jinja Context:**

```python
JINJA_CONTEXT_ADDONS = {
    "my_custom_macro": lambda: "custom_value",
}
```

## Chart Types and Visualization

Superset ships with **40+ pre-installed visualization types** via a plugin architecture. The primary charting engine is **Apache ECharts**.

### Chart Categories

| Category | Chart Types |
|---|---|
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

Charts are implemented as **npm packages** following a plugin interface:
- Custom chart development and registration
- Third-party visualization plugins
- Per-chart ECharts theme customization (as of 6.0)

## Dashboards

Dashboards are composed of charts/slices, filters, tabs, markdown, dividers, and headers.

### Features

- **Drag-and-drop layout builder** with responsive grid
- **Native filters** with cascading, dependent, and time-range filters
- **Cross-filtering**: Click on a chart element to filter the entire dashboard
- **Periodic refresh**: Auto-refresh at configurable intervals
- **Dashboard-level caching** with warm-up support
- **Embedding**: Embed in external applications via iframe with guest tokens
- **Export/Import**: JSON-based dashboard export for version control and migration
- **Dark mode support** (6.0): Full dark theme across all visualizations
- **Tabs and nested tabs** for content organization
- **Markdown components** for text, images, and HTML
- **Dashboard-level CSS overrides**

### Native Filters

- Dashboard-level filter bar with persistent state
- Filter types: value, time range, time column, time grain, numerical range
- Cascading/dependent filters (filter B depends on filter A selection)
- Cross-filtering: click on chart elements to filter the entire dashboard
- Pre-filter data with SQL expressions
- Scope control: apply filters to specific charts or tabs

## Database Connectivity

Superset connects to analytical databases via **SQLAlchemy** and database-specific drivers. It does not ship bundled with drivers -- they must be installed separately.

### Supported Databases (50+)

| Category | Databases |
|---|---|
| **Cloud Warehouses** | Snowflake, BigQuery, Redshift, Databricks, Azure Synapse |
| **OLAP/Analytical** | ClickHouse, Apache Druid, Apache Pinot, StarRocks, Doris, Firebolt |
| **SQL Engines** | Trino, Presto, Apache Hive, Spark SQL, Dremio |
| **RDBMS** | PostgreSQL, MySQL, SQL Server, Oracle, DB2, MariaDB, CockroachDB |
| **Embedded** | DuckDB, SQLite |
| **Search/NoSQL** | Elasticsearch, Apache Kylin |
| **File-based** | Google Sheets, Excel (via Shillelagh) |

### Connection Configuration

Each database connection is configured with:
- SQLAlchemy URI (connection string): `dialect+driver://user:password@host:port/database`
- Optional SSH tunnel parameters
- Schema-level permissions
- Query cost estimation settings
- Async query support toggle
- Connection pool settings (`pool_size`, `max_overflow`, `pool_timeout`, `pool_recycle`)
- Impersonation configuration

### Common Driver Packages

| Database | PyPI Package |
|---|---|
| PostgreSQL | `psycopg2-binary` or `psycopg2` |
| MySQL | `mysqlclient` or `PyMySQL` |
| Snowflake | `snowflake-sqlalchemy` |
| BigQuery | `sqlalchemy-bigquery` |
| ClickHouse | `clickhouse-connect` |
| Trino | `trino` |
| Presto | `pyhive` |
| Redshift | `sqlalchemy-redshift` |
| Databricks | `databricks-sql-connector` |
| SQL Server | `pymssql` |
| Oracle | `cx_Oracle` |
| DuckDB | `duckdb-engine` |

## Caching Layer

Superset implements a **multi-tier caching architecture** using Flask-Caching.

### Cache Types

| Cache | Purpose | Configuration Key |
|---|---|---|
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

Superset supports scheduled cache warm-up to pre-populate dashboard caches, typically run via Celery beat:

```python
beat_schedule = {
    "cache-warmup": {
        "task": "cache-warmup",
        "schedule": crontab(minute=0, hour=6),
        "kwargs": {
            "strategy_name": "top_n_dashboards",
            "top_n": 10,
        },
    },
}
```

## Async Queries with Celery

Superset uses **Celery** for asynchronous task processing.

### Components

- **Celery Workers**: Execute async tasks (queries, reports, alerts, thumbnails)
- **Celery Beat**: Cron-based task scheduler
- **Message Broker**: Redis or RabbitMQ
- **Results Backend**: Redis or S3 for task results

### Task Types

- Async SQL Lab queries (long-running queries dispatched to workers)
- Report scheduling (dashboard/chart snapshots via email or Slack)
- Alert monitoring (SQL-based data alerts)
- Cache warm-up (periodic cache pre-population)
- Thumbnail generation (preview images)
- Log pruning (cleanup of query and access logs)

### Celery Configuration

```python
class CeleryConfig:
    broker_url = "redis://redis:6379/0"
    result_backend = "redis://redis:6379/1"
    imports = (
        "superset.sql_lab",
        "superset.tasks.scheduler",
        "superset.tasks.thumbnails",
        "superset.tasks.async_queries",
    )
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
- Enable via `GLOBAL_ASYNC_QUERIES` feature flag

## Security Model

### Authentication Methods

| Method | Config Key | Description |
|---|---|---|
| Database | `AUTH_DB` | Built-in username/password (default) |
| LDAP | `AUTH_LDAP` | LDAP/Active Directory integration |
| OAuth 2.0 | `AUTH_OAUTH` | OAuth providers (Google, GitHub, Azure AD, Okta, Keycloak) |
| OpenID Connect | `AUTH_OID` | OIDC protocol |
| Remote User | `AUTH_REMOTE_USER` | Header-based SSO (behind a proxy) |

### RBAC

| Role | Access Level |
|---|---|
| **Admin** | Full system access, user management, all data sources |
| **Alpha** | All data sources, create charts/dashboards, no admin |
| **Gamma** | Only explicitly granted data sources |
| **sql_lab** | SQL Lab access (combinable with other roles) |
| **Public** | Unauthenticated users (disabled by default) |

**Group-Based Access Control** (6.0): Assign roles to user groups; group-based access for databases, datasources, and schemas.

### Row-Level Security (RLS)

SQL filter clauses applied per role or user to restrict data visibility:
```python
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

## Embedding

### Embedded SDK

- JavaScript SDK (`@superset-ui/embedded-sdk`) for iframe-based embedding
- Guest tokens with configurable permissions and Row-Level Security
- Custom styling via CSS overrides
- Domain whitelisting for security

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

### REST API

- Comprehensive REST API for programmatic access
- CRUD operations for dashboards, charts, datasets, databases
- Query execution API
- Thumbnail generation API
- Export/import via API

## Deployment Architecture (Production)

### Kubernetes Deployment

The official **Helm chart** deploys a minimum of 5 workloads:

1. **Superset Web Server** (Gunicorn/uWSGI): Serves the Flask app and API
2. **Celery Worker(s)**: Execute async tasks
3. **Celery Beat**: Task scheduler
4. **WebSocket Server** (Node.js): Real-time async query notifications
5. **Init Job**: Database migration and initialization

Each component can scale independently via Kubernetes HPA.

### Distributed Coordination (6.0)

- **Distributed locking via Redis**: Moves lock operations from metadata database to Redis
- **Real-time event notifications**: Pub/sub messaging for task abort and completion
- **WebSocket Server**: Real-time communication for async query completion

## Semantic Layer

### Current Approach (Thin)

Two dataset types:
- **Physical Datasets**: Direct mapping to a database table or view
- **Virtual Datasets**: Defined by a SQL query (from SQL Lab)

Each dataset defines metrics (aggregation expressions), calculated columns (SQL-derived), column metadata (types, descriptions, groupability, filterability), and certification status.

### SIP-182 (Proposed Enhancement)

- "Explorable" Python protocol for external semantic layer integration
- New connection class for semantic layers and data modeling systems
- Integration with Cube, dbt Semantic Layer, Metricflow

## Superset 6.0 Key Features

### Design System Overhaul (Ant Design v5)
- Modern UI component refresh across the entire application
- Consistent design language and interaction patterns
- Improved accessibility and responsiveness

### Theming Architecture and Dark Mode
- Semantic token system replacing hardcoded colors
- Theme management UI: create, edit, import, export, apply
- System-wide or per-dashboard themes
- Full dark theme across all 80+ chart types

### URL Prefix Deployment
- Deploy at paths like `/analytics` or `/superset`
- Critical for reverse proxy deployments and multi-tenant setups

### Hierarchical Folder System for Datasets
- Organize metrics and columns into logical groups within Explore view
- Addresses the previous 50-item display limitation

### Group-Based Access Control
- Assign roles to user groups
- Group-based access for databases, datasources, and schemas
- Integrates with external identity providers (LDAP/OAuth group mappings)

## Alerting and Reporting

### Scheduled Reports
- Schedule dashboard or chart snapshots via email or Slack
- Cron-based scheduling via Celery Beat
- PDF, PNG, or CSV attachment formats
- Owner and recipient management

### Data Alerts
- SQL-based alert conditions
- Threshold monitoring with configurable operators
- Notification channels: email, Slack
- Alert history and log tracking
