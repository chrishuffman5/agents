# Metabase Architecture Reference

## Application Server

Metabase is a Java application built in Clojure running on the JVM.

### Runtime

- **Language**: Clojure (JVM-based)
- **JDK requirement**: JDK 21 or higher (as of 2025+)
- **Deployment artifacts**: Single JAR file or Docker container (`metabase/metabase`)
- **Configuration**: Environment variables, `metabase.db` settings, Admin UI settings

### Deployment Methods

| Method | Image/Artifact | Notes |
|---|---|---|
| **Docker** | `metabase/metabase` (OSS), `metabase/metabase-enterprise` (Pro/Enterprise) | Recommended for self-hosted production |
| **JAR** | `metabase.jar` | Requires JDK 21+; `java -jar metabase.jar` |
| **Metabase Cloud** | Managed by Metabase | Zero DevOps; automatic upgrades |

### Scaling

- Single instance for small deployments
- Cluster mode: multiple nodes sharing a PostgreSQL application database
- **Important**: Reduce to single node during upgrades (migrations must run on one node only)
- Load balancer distributes requests across cluster nodes

---

## Application Database

The application database stores all Metabase configuration, NOT business data:
- Questions (saved queries), dashboards, collections
- User accounts, groups, permissions
- Settings, caching configuration, audit logs
- Version history for models and questions

### Supported Application Databases

| Database | Use Case | Critical Notes |
|---|---|---|
| **H2** | Development/demo only | Default, embedded, file-based. NOT for production -- corruption risk, file-level locking, no concurrent access |
| **PostgreSQL** | Production (recommended) | Best performance and reliability; required for cluster deployments |
| **MySQL/MariaDB** | Production (alternative) | Fully supported; PostgreSQL still preferred |

### Migration Path

H2 to PostgreSQL/MySQL migration is supported via built-in migration commands:
```bash
# Environment variables for target database
export MB_DB_TYPE=postgres
export MB_DB_DBNAME=metabase
export MB_DB_PORT=5432
export MB_DB_USER=metabase
export MB_DB_PASS=<password>
export MB_DB_HOST=localhost

# Run migration
java -jar metabase.jar load-from-h2 /path/to/metabase.db
```

---

## Question Types

### Query Builder (Graphical)

- Visual, drag-and-drop interface for building queries without SQL knowledge
- Supports filters, summarization, custom columns, joins, and sorting
- Produces structured queries that enable **drill-through** functionality
- Best for business users and self-service analytics
- Generates optimized SQL behind the scenes

### Custom Questions (Advanced Query Builder)

- Advanced mode within the query builder
- Supports custom expressions, calculated columns, and complex aggregations
- Maintains drill-through support
- Bridge between no-code and full SQL

### Native/SQL Query Editor

- Full SQL (or database-native language) editor with syntax highlighting
- **Variables**: `{{variable_name}}` for parameterized queries
- **Field filters**: `{{filter_column}}` for smart filter widgets tied to database columns
- **Template tags**: Control query structure based on user input
- **SQL snippets**: Reusable query fragments; parameterizable as of v57 (snippet variables, snippet-to-snippet references)
- **Metabot AI** (v59+): Single-prompt natural language to SQL conversion

**Important**: Native SQL questions do NOT support drill-through. Use the query builder when drill-through is required.

---

## Models

Models are curated datasets that serve as the semantic layer.

### Purpose

- Derived tables combining data from multiple sources
- Clean, well-documented starting points for exploration
- Display prominently in search results for discoverability
- Provide metadata enrichment for better user experience
- Establish a single source of truth for key business entities

### Metadata Management

| Metadata | Purpose | Example |
|---|---|---|
| **Display names** | Human-readable column headings | "Order Date" instead of "created_at" |
| **Descriptions** | Context and documentation per field | "Total after discounts and returns" |
| **Semantic types** | Data classification driving UI behavior | Currency, FK, Category, Email, URL |
| **Column type mapping** | Links SQL columns to database columns | Enables query builder exploration on SQL-based models |
| **Visibility** | Control which columns appear | Hide internal/technical columns |
| **Display format** | Text or clickable URL | Make URL columns clickable |

### Segments and Measures (v59+)

- **Segments**: Reusable predefined filters ("Active Users", "Enterprise Customers", "Last 30 Days")
- **Measures**: Reusable aggregation definitions ("Total Revenue", "Average Order Value", "Customer Count")
- Both are defined in the model metadata and available in the query builder

### Transforms (v59+, replacing Model Persistence)

- SQL or Python transformations of raw data into analytics-ready tables
- Built-in Metabot AI assistance for code generation
- Dependency graph visualization showing entity relationships
- Intended to replace model persistence (which stores model results in the data warehouse)
- Require writable database connections

### Version History

- Retains previous 15 versions with change tracking
- Supports reversion to earlier versions
- Tracks who made changes and when

---

## Dashboards

### Components

| Component | Purpose |
|---|---|
| **Question cards** | Charts, tables, and visualizations from saved questions |
| **Text cards** | Markdown-formatted text; support variables wired to dashboard filters |
| **Link cards** | Navigation links to other dashboards, questions, or external URLs |
| **Heading cards** | Section headers for visual organization |
| **Action cards** | Buttons triggering database write operations (v57+) |

### Filters

- **Dashboard-level filters**: Update multiple cards simultaneously
- **Filter types**: Time, Location, ID, Text, Number, custom
- **Linked filters**: Cascading relationships (Country -> State -> City)
- **Cross-filtering**: Click on a chart element to filter other cards
- **Filter-to-text**: Wire filter values into text cards via `{{variable}}` syntax
- **Default values**: Pre-set filter values to limit initial data load

### Click Behavior

- Navigate to other dashboards, saved questions, or external URLs
- Pass clicked values as filter parameters to the destination
- Update dashboard filters from click actions
- Open modals, new tabs, or custom routes (v57+ SDK)

### Tabs

- Split dashboard content across tabs for organization and performance
- Each tab loads independently, reducing initial query load
- Particularly important for dashboards exceeding 20-25 cards

### Subscriptions

- Schedule dashboard delivery via email or Slack
- Frequency: hourly, daily, weekly, monthly
- Formats: inline visualizations, CSV/XLSX attachments
- Conditional delivery based on filter results
- Available in Modular Embedding (Pro/Enterprise, v58+)

### Auto-Refresh

- Configurable automatic refresh intervals
- Available in embedded dashboards (v59+)

---

## Embedding Architecture

### Static Embedding / Guest Embeds

```
Your App                          Metabase
  │                                  │
  ├── User requests dashboard ──────►│
  │                                  │
  ├── Server generates JWT ─────────►│
  │   (signed with shared secret)    │
  │   (locked params for security)   │
  │                                  │
  ├── Signed iframe URL ◄───────────│
  │                                  │
  └── User sees embedded content ◄──│
```

- JWT token signed with a shared secret between your app and Metabase
- **Locked parameters**: Restrict data per user/tenant (e.g., `customer_id=123`)
- **Editable parameters**: Interactive filters requiring server-side URL re-signing
- Limitations: no drill-through, no user sessions, no row/column security
- Shows "Powered by Metabase" badge on OSS/Starter plans
- **Guest Embeds** (v58+): Successor to static embedding with enhanced theming (Pro/Enterprise)

### Full-App Embedding (Pro/Enterprise)

Embeds entire Metabase application in an iframe:
- SSO integration: JWT (recommended), SAML, LDAP
- Full permissions and data sandboxing support
- Customizable UI: show/hide navigation, headers, action bars
- PostMessage communication for location tracking and frame sizing
- Multi-tenant support with per-tenant group permissions (Tenants feature, v58+)
- Session management with configurable duration (default: 2 weeks, via MAX_SESSION_AGE)

### Modular Embedding SDK (Pro/Enterprise)

React SDK for embedding individual Metabase components:

**Available components:** Charts, dashboards, query builder, AI chat, collections

**Requirements:**
- React 18/19
- Node.js 20.x+
- Metabase 1.52+
- **SDK version must match Metabase instance version exactly** (e.g., `@metabase/embedding-sdk-react@56-stable`)

**Configuration:**
- CORS origins must be configured in Metabase admin
- SSR not supported (auto-skipped as of v57)
- Next.js compatible
- Hosted SDK bundles available for automatic version compatibility (v57+)

**Theming:**
- Advanced appearance customization (colors, fonts, spacing)
- White-labeling support (Pro/Enterprise)
- Component-level interactivity management

---

## Permissions Model

### Groups

- Users are organized into groups
- Permissions assigned at the group level
- All users belong to the "All Users" group
- **Permissions are additive: most permissive group setting wins**
- Must restrict "All Users" before granular permissions work correctly

### Data Permissions

| Level | Description | Plan |
|---|---|---|
| **Can view** | Full access to all data | All |
| **Granular** | Per-table or per-schema configuration | Pro/Enterprise |
| **Sandboxed** (row/column security) | Row/column restrictions based on user attributes | Pro/Enterprise |
| **Impersonated** | Uses database roles for access control | Pro/Enterprise |
| **Blocked** | No access regardless of collection permissions | Pro/Enterprise |

### Create Queries Permissions

| Level | Access |
|---|---|
| **Query builder and native** | Full SQL and visual query access |
| **Query builder only** | Visual query creation only (no SQL) |
| **Granular** | Per-schema or per-table configuration |

**Critical**: If any table is blocked or sandboxed, native query access is automatically disabled for the entire database. This prevents SQL queries from bypassing row/column security.

### Collection Permissions

- Control viewing and curating existing questions, models, and dashboards
- Separate from data permissions (a user can see a dashboard but be blocked from its underlying data)
- Permissions are additive across groups

### Download Permissions

| Level | Max Rows |
|---|---|
| No downloads | 0 |
| Limited | 10,000 rows |
| Full | 1,000,000 rows |

Native query downloads require full-database download permissions.

### Additional Permission Types

- **Manage table metadata**: Control data model editing
- **Manage database**: Connection settings and schema syncing
- **Transform**: Control who manages database transforms (v59+)
- **Application permissions**: Access to Metabase admin features
- **Snippet folder permissions**: Organize and restrict SQL snippet access
- **Notification permissions**: Dashboard subscription and alert access

---

## Caching Mechanics

### Cache Invalidation Policies

| Policy | How It Works | Plan |
|---|---|---|
| **Duration** | Cache for N hours | Pro/Enterprise |
| **Schedule** | Invalidate hourly, daily, weekly, or monthly | Pro/Enterprise |
| **Adaptive** | Duration = avg query execution time x configurable multiplier | All |
| **Don't cache** | Disable caching | All |

### Configuration Hierarchy

Priority (highest to lowest):
1. **Question-level** policy
2. **Dashboard-level** policy
3. **Database-level** policy
4. **Default site-wide** policy

### Automatic Cache Refresh (Pro/Enterprise)

- Reruns queries immediately upon cache invalidation
- Ensures users always see cached results, never raw query execution
- **Incompatible with**: row/column security, connection impersonation, database routing

### Parameter Caching

Caches results for up to 10 most frequently used parameter value combinations during the caching period.

### Cache Storage

- **Self-hosted**: Stored in the application database
- **Metabase Cloud**: Stored on Metabase servers (US region)

### Model Persistence (being replaced by Transforms)

- Stores model results as tables in the data warehouse
- Configured via cron schedule in Admin > Settings > Caching > Models
- Reduces query load on source databases
- Being phased out in favor of Transforms (v59+)

---

## Database Connectivity

### Officially Supported Databases

Athena, BigQuery, ClickHouse, Databricks, Druid, MariaDB, MongoDB, MySQL, Oracle, PostgreSQL, Presto, Redshift, Snowflake, SparkSQL, SQL Server, SQLite, Starburst, Vertica

### Community Drivers

Additional databases supported via community-maintained drivers (not officially supported by the Metabase team). Community drivers are available for self-hosted deployments only.

### Connection Security

| Feature | Description |
|---|---|
| **SSH Tunneling** | Connect through SSH bastion hosts for databases behind firewalls |
| **SSL/TLS** | Automatic SSL-first connection attempts; manual configuration available |
| **Truststores/Keystores** | Supported for PostgreSQL, Oracle, and other databases |
| **AWS IAM Authentication** | Supported for Aurora PostgreSQL and MySQL (v58+) |

### Connection Features

- **Writable connections**: Required for Transforms and inline data editing
- **Sync scheduling**: Configurable database schema synchronization
- **Scan scheduling**: Configurable field value scanning for filter suggestions
- **JSON unfolding**: Automatically extracts JSON keys into columns (can slow sync; disable if not needed)

---

## REST API

### Authentication

| Method | Header | Notes |
|---|---|---|
| **API Keys** | `x-api-key` | Preferred for programmatic access; introduced v0.47 |
| **Session Tokens** | `X-Metabase-Session` | From `POST /api/session`; expires; requires re-auth |

### Key Endpoint Categories

| Endpoint | Purpose |
|---|---|
| `/api/card` | Question/card CRUD (create, read, update, delete) |
| `/api/dashboard` | Dashboard management (create, update, add cards) |
| `/api/database` | Database connections (add, validate, sync) |
| `/api/user` | User management (CRUD, enable/disable) |
| `/api/permissions` | Group and permission management |
| `/api/collection` | Collection management |
| `/api/session` | Authentication and session management |

### API Characteristics

- Not versioned; endpoints rarely change and almost never removed
- Complete REST interface for all major Metabase features
- **Agent API** (v59+): Programmatic semantic layer access for automation and integration

### Pre-warming Caches

Use the API to pre-warm caches before peak usage:
```bash
# Execute a question to populate its cache
curl -X POST https://metabase.example.com/api/card/123/query \
  -H "x-api-key: YOUR_API_KEY"
```
