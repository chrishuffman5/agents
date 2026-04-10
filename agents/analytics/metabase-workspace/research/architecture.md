# Metabase Architecture

## Overview

Metabase is an open-source business intelligence and embedded analytics platform. It is deployed as a Java application (JAR file or Docker container) backed by an application database that stores all configuration, questions, dashboards, and metadata.

## Application Server

- **Runtime**: Java (requires JDK 21 or higher as of 2025+)
- **Deployment**: Single JAR file or Docker container
- **Framework**: Clojure-based application running on the JVM
- **Scaling**: Can run in a cluster with multiple nodes (single node required during upgrades)

## Application Database

The application database stores all Metabase configuration: questions, dashboards, collections, user accounts, permissions, and settings. It does NOT store actual business data.

### Supported Application Databases

| Database | Use Case | Notes |
|----------|----------|-------|
| H2 | Development/demo only | Default, embedded, file-based. NOT for production |
| PostgreSQL | Production (recommended) | Best performance and reliability |
| MySQL/MariaDB | Production (alternative) | Fully supported |

### Migration Path
- H2 to PostgreSQL/MySQL migration is supported via built-in migration commands
- Migration should be done before production deployment
- H2 is unsuitable for production due to data corruption risks and performance limitations

## Question Types

### Query Builder (Graphical)
- Visual, drag-and-drop interface for building queries without SQL
- Supports filters, summarization, custom columns, joins, and sorting
- Produces structured queries that enable drill-through functionality
- Best for business users and self-service analytics

### Native/SQL Query Editor
- Full SQL (or database-native language) editor
- Supports variables, field filters, and template tags for parameterized queries
- SQL snippets for reusable query fragments (parameterizable as of v57)
- Results can be saved, added to dashboards, and converted to models
- AI-assisted SQL generation via Metabot (Anthropic-powered, available in OSS as of v59)

### Custom Questions
- Advanced mode within the query builder
- Supports custom expressions, calculated columns, and complex aggregations

## Models

Models are curated datasets that serve as the semantic layer for analytics.

### Purpose
- Derived tables combining data from multiple sources
- Anticipate common questions users will ask
- Provide clean, well-documented starting points for exploration
- Display prominently in search results for discoverability

### Metadata Management
- **Display names**: Custom column headings
- **Descriptions**: Context and documentation per field
- **Semantic types**: Data classification (Currency, FK, Category, etc.)
- **Column type mapping**: Links SQL columns to database columns for query builder compatibility
- **Visibility settings**: Control which columns appear in table vs detail views
- **Display format**: Text or clickable URL options

### Model Persistence (being replaced by Transforms)
- Persists model results as tables in a bespoke schema in your data warehouse
- Refreshed on a configurable cron schedule
- Improves query performance for models with complex queries
- Being phased out in favor of Transforms (v59+)

### Version History
- Retains previous 15 versions with change tracking
- Supports reversion to earlier versions

### Transforms (v59+, new)
- SQL or Python transformations of raw data into analytics-ready tables
- Built-in Metabot AI assistance for code generation
- Dependency graph visualization
- Intended to replace model persistence

## Dashboards

### Components
- **Question cards**: Charts, tables, and visualizations from saved questions
- **Text cards**: Markdown-formatted text blocks; can include variables wired to filters
- **Link cards**: Navigation links
- **Heading cards**: Section headers
- **Action cards**: Buttons that trigger database write operations (v57+)

### Filters
- Dashboard-level filters that update multiple cards simultaneously
- Filter types: Time, Location, ID, Text, Number, custom
- Linked filters: Cascading filter relationships
- Cross-filtering: Click on a chart element to filter other cards
- Filters can be wired to text cards (via variables)

### Click Behavior
- Customizable actions when users click chart elements
- Navigate to other dashboards, saved questions, or external URLs
- Pass clicked values as filter parameters to destination
- Update dashboard filters from click actions
- Open modals, new tabs, or custom routes (v57+ SDK)

### Subscriptions
- Schedule dashboard delivery via email or Slack
- Configurable frequency: hourly, daily, weekly, monthly
- Supports CSV/XLSX attachment-only options
- Conditional delivery based on filter results
- Available in Modular Embedding (Pro/Enterprise, v58+)

### Additional Features
- **Tabs**: Split content across tabs for organization and performance
- **Auto-refresh**: Configurable automatic refresh intervals
- **Fullscreen mode**: Presentation-friendly view
- **Night mode / Dark mode**: Reduced-glare viewing (v57+)
- **Multiple series**: Combine questions on single charts
- **Separate panels**: Split series into separate panels in same visualization (v60)

## Embedding

### Static Embedding (Free/OSS)
- Iframe-based embedding secured with signed JWT tokens
- Shared secret key between application and Metabase
- Locked parameters: restrict data for specific users/groups
- Editable parameters: interactive filters requiring server-side URL re-signing
- Limitations: no drill-through, no row/column security, no user sessions
- Shows "Powered by Metabase" badge on OSS/Starter plans

### Guest Embeds (v58+, replaces Static Embedding)
- New successor to static embedding
- Smoother migration path from static embeds
- Enhanced theming on Pro/Enterprise plans
- View-only charts and dashboards

### Full-App Embedding (Pro/Enterprise)
- Embeds entire Metabase application in an iframe
- SSO integration (JWT recommended, SAML, LDAP supported)
- Full permissions and data sandboxing support
- Customizable UI: show/hide navigation, headers, action bars
- PostMessage communication for location tracking and frame sizing
- Multi-tenant support with per-tenant group permissions
- Session management with configurable duration (default: 2 weeks)

### Modular Embedding SDK (Pro/Enterprise)
- React SDK for embedding individual Metabase components
- Available components: charts, dashboards, query builder, AI chat, collections
- Requirements: React 18/19, Node.js 20.x+, Metabase 1.52+
- Advanced theming and appearance customization
- Component-level interactivity management
- CORS configuration required
- Version-matched npm packages (e.g., `@metabase/embedding-sdk-react@56-stable`)
- SSR not supported (auto-skipped as of v57)
- Next.js compatible

## Permissions

### Groups
- Users are organized into groups
- Permissions are assigned at the group level
- All users belong to the "All Users" group (must restrict before applying granular permissions)
- Permissions are additive: most permissive group setting wins

### Data Permissions
| Level | Description | Plan |
|-------|-------------|------|
| Can view | Full access to all data in the source | All |
| Granular | Per-table or per-schema configuration | Pro/Enterprise |
| Row and column security (Sandboxed) | Row/column restrictions based on user attributes | Pro/Enterprise |
| Impersonated | Uses database roles to determine access | Pro/Enterprise |
| Blocked | No access regardless of collection permissions | Pro/Enterprise |

### Create Queries Permissions
- **Query builder and native**: Full SQL and visual query access
- **Query builder only**: Visual query creation only
- **Granular**: Per-schema or per-table configuration
- Note: If any table is blocked/sandboxed, native query access is disabled for the entire database

### Collection Permissions
- Control viewing and curating existing questions, models, and dashboards
- Permissions are additive across groups
- Does not control data access (requires separate data permissions)

### Download Permissions
- No rows, 10,000 rows, or 1 million rows maximum
- Native query downloads require full-database download permissions

### Additional Permission Types
- **Manage table metadata**: Control data model editing
- **Manage database**: Connection settings and schema syncing
- **Transform**: Control who manages database transforms
- **Application permissions**: Access to Metabase admin features
- **Snippet folder permissions**: Organize and restrict snippet access
- **Notification permissions**: Dashboard subscription and alert access

## Caching

### Cache Invalidation Policies
1. **Duration**: Cache for a specified number of hours (Pro/Enterprise)
2. **Schedule**: Invalidate hourly, daily, weekly, or monthly (Pro/Enterprise)
3. **Adaptive**: Duration = avg query time x configurable multiplier (e.g., 10s avg x 100 = 1000s cache)
4. **Don't cache**: Disable caching entirely

### Configuration Hierarchy (highest priority first)
1. Question-level policy
2. Dashboard-level policy
3. Database-level policy
4. Default site-wide policy

### Automatic Cache Refresh (Pro/Enterprise)
- Reruns queries immediately upon cache invalidation
- Ensures users always see cached results
- Incompatible with: row/column security, connection impersonation, database routing

### Parameter Caching
- Caches results for up to 10 most frequently used parameter value combinations
- Applied during the last caching period

### Cache Storage
- Self-hosted: stored in application database
- Metabase Cloud: stored on Metabase servers (US)

### Model Persistence (being replaced by Transforms)
- Stores model results as tables in the data warehouse
- Configured via cron schedule in Admin > Settings > Caching > Models
- Reduces query load on source databases

## Database Connectivity

### Officially Supported Databases
Athena, BigQuery, ClickHouse, Databricks, Druid, MariaDB, MongoDB, MySQL, Oracle, PostgreSQL, Presto, Redshift, Snowflake, SparkSQL, SQL Server, SQLite, Starburst, Vertica

### Community Drivers
Additional databases supported via community-maintained drivers (not officially supported by Metabase team)

### Connection Security
- **SSH Tunneling**: Connect through SSH bastion hosts for databases behind firewalls
- **SSL/TLS**: Automatic SSL-first connection attempts; manual configuration available
- **Truststores/Keystores**: Supported for PostgreSQL, Oracle, and other databases
- **AWS IAM Authentication**: Supported for Aurora PostgreSQL and MySQL (v58+)

### Connection Features
- Writable connections for specific features (Transforms, inline editing)
- Sync scheduling: configurable database schema synchronization
- Scan scheduling: configurable field value scanning for filter suggestions

## REST API

### Authentication
- **API Keys**: `x-api-key` header (introduced v0.47, preferred for programmatic access)
- **Session Tokens**: `X-Metabase-Session` header from `POST /api/session` (expires, requires re-auth)

### Key Endpoint Categories
- `/api/user` - User management (CRUD, enable/disable)
- `/api/dashboard` - Dashboard management (create, update, add cards)
- `/api/card` - Question/card management
- `/api/database` - Database connections (add, validate, sync)
- `/api/permissions` - Group and permission management
- `/api/collection` - Collection management
- `/api/session` - Authentication and session management

### API Characteristics
- Not versioned; endpoints rarely change and almost never removed
- Complete REST interface for all major Metabase features
- Agent API for programmatic semantic layer access (v59+)

## Sources

- [Metabase Application Database Configuration](https://www.metabase.com/docs/latest/installation-and-operation/configuring-application-database)
- [Metabase Models Documentation](https://www.metabase.com/docs/latest/data-modeling/models)
- [Metabase Permissions Overview](https://www.metabase.com/docs/latest/permissions/start)
- [Metabase Data Permissions](https://www.metabase.com/docs/latest/permissions/data)
- [Metabase Caching](https://www.metabase.com/docs/latest/configuring-metabase/caching)
- [Metabase Embedding - Static](https://www.metabase.com/docs/latest/embedding/static-embedding)
- [Metabase Embedding - Full App](https://www.metabase.com/docs/latest/embedding/full-app-embedding)
- [Metabase Embedding - SDK](https://www.metabase.com/docs/latest/embedding/sdk/introduction)
- [Metabase Database Connectivity](https://www.metabase.com/docs/latest/databases/connecting)
- [Metabase API Documentation](https://www.metabase.com/docs/latest/api)
- [Metabase SSH Tunneling](https://www.metabase.com/docs/latest/databases/ssh-tunnel)
- [Metabase SSL Certificates](https://www.metabase.com/docs/latest/databases/ssl-certificates)
