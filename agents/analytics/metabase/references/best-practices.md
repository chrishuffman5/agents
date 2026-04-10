# Metabase Best Practices Reference

## Question Design

### When to Use Each Question Type

**Query Builder (Graphical) -- Use When:**
- Business users need self-service analytics without SQL knowledge
- Drill-through functionality is required (SQL questions do NOT support drill-through)
- Questions need to be easily modified by non-technical users
- Building on top of models for consistent data access
- Exploratory analysis where the schema is well-modeled

**Custom Questions (Advanced Query Builder) -- Use When:**
- Complex aggregations, custom expressions, or calculated columns are needed
- Joins across multiple tables are required
- Users are comfortable with expression syntax but not SQL
- Drill-through is still desired

**Native/SQL Queries -- Use When:**
- Complex logic exceeding query builder capabilities (CTEs, window functions, subqueries)
- Database-specific syntax or functions are needed
- Performance-critical queries requiring hand-optimized SQL
- Integrating with parameterizable SQL snippets for reusable logic
- Using Metabot AI for SQL generation assistance

### Performance Considerations for Questions

- Prefer the query builder when possible; it generates optimized queries
- Use filters to limit data volume before aggregation
- Add database indexes on columns frequently used in WHERE, JOIN, and ORDER BY
- Avoid `SELECT *` patterns in SQL; select only needed columns
- Use models as starting points for consistent, well-indexed data paths
- For complex queries, consider creating summary tables or materialized views
- Test query performance directly against the database before saving

---

## Model Design

### When to Use Models

- When multiple questions query the same base data with the same joins/filters
- To create business-concept representations ("Active Customers", "Monthly Revenue")
- When SQL query results need to be explorable via the query builder
- To clean datasets by removing unnecessary columns or applying standard filters
- When metadata enrichment (display names, descriptions, semantic types) adds value
- To establish a single source of truth for key business entities

### When to Use Transforms Instead (v59+)

- When data needs SQL or Python transformation before analysis
- For ETL-like operations directly within Metabase
- When model persistence is needed (Transforms are replacing model persistence)
- For complex data preparation that benefits from dependency tracking

### Metadata Enrichment Best Practices

| Metadata | Action | Why It Matters |
|---|---|---|
| **Display names** | Set for every column | Users see "Order Date" not "created_at" |
| **Descriptions** | Add for every field | Documents calculation logic and business meaning |
| **Semantic types** | Assign correctly | Currency, Category, FK, Email, URL drive filter behavior and formatting |
| **Column type mapping** | Map SQL to database columns | Enables query builder exploration on SQL-based models |
| **Visibility** | Configure per column | Hide internal/technical columns from end users |
| **Segments** (v59+) | Define reusable filters | "Active Users", "Enterprise Customers", "Last 30 Days" |
| **Measures** (v59+) | Define reusable aggregations | "Total Revenue", "Average Order Value" |

### Model Organization

- Place models in dedicated collections organized by business domain
- Use consistent naming conventions (e.g., prefix with domain: "Sales - Monthly Revenue")
- Document model purpose and intended audience in the description
- Review and update model metadata when underlying schemas change
- Use dependency checks (Pro/Enterprise) to monitor downstream impacts

---

## Dashboard Design

### Layout Best Practices

- **Card limit**: Keep dashboards to 20-25 cards maximum per tab
- **Use tabs**: Split content across tabs to reduce initial load and improve organization
- **Group related cards**: Cluster related visualizations with logical flow
- **Color-code**: Use consistent color schemes for related metrics
- **Include context**: Add text cards with explanations, definitions, and guidance
- **Heading cards**: Use headings to create clear visual sections
- **Progressive disclosure**: High-level summaries at top; details in lower sections or tabs

### Filter Best Practices

- Set default filter values to limit initial data load (especially time ranges)
- Use linked/cascading filters for hierarchical relationships (Country > State > City)
- Wire filters to text cards for dynamic context
- Enable cross-filtering so chart clicks update other cards
- Keep filter count manageable: 5-7 maximum per dashboard
- Use locked parameters in embedded dashboards for security

### Interactivity Best Practices

- Configure click behavior to navigate between dashboards for drill-down workflows
- Use click actions to pass filter values between dashboards
- Include trend lines and goal lines for context
- Set up action buttons for common workflows (with write permissions, v57+)
- Design clear navigation paths through dashboard hierarchies

### Performance Best Practices

- Limit cards per tab to 20-25
- Use default filters to reduce initial query load
- Avoid redundant queries; combine series on single charts where possible
- Use models as data sources for consistency and caching benefits
- Split heavy dashboards into multiple focused dashboards
- Test dashboard load times during development

---

## Embedding Best Practices

### Architecture Patterns

**Static Embedding / Guest Embeds (Simple Use Cases):**
- Best for: read-only charts/dashboards in marketing sites, customer portals
- Secure with JWT-signed tokens using a server-side secret
- Use locked parameters to restrict data per user/tenant
- Regenerate embedding secret key if compromised
- Guest Embeds (v58+) are the recommended successor to static embedding

**Full-App Embedding (Interactive Analytics):**
- Best for: customer-facing analytics platforms requiring exploration
- Use JWT SSO (recommended over SAML for embedding)
- Configure per-tenant groups with row/column security
- Set appropriate session duration via `MAX_SESSION_AGE`
- Use Entity IDs for stable references across environments
- Configure authorized origin URLs for security
- Use PostMessage for frame sizing and location tracking

**Modular Embedding SDK (Custom React Integration):**
- Best for: React applications requiring component-level control
- **Match SDK version to Metabase version exactly**
- Configure CORS origins in Metabase admin
- Use hosted SDK bundles for automatic version compatibility (v57+)
- Leverage advanced theming for seamless brand integration
- Handle SSR limitations (components auto-skip SSR as of v57)

### Authentication Best Practices

- JWT is recommended for most embedding scenarios
- Never expose the embedding secret key in client-side code
- Implement token refresh logic for long-lived sessions
- Use SCIM for automated user provisioning in multi-tenant setups
- Implement tenant isolation at both the permission and data level

### Customization

- White-label with custom colors, fonts, and logo (Pro/Enterprise)
- Hide navigation elements not relevant to embedded context
- Use URL parameters to control UI component visibility
- Apply consistent theming across all embedded components

---

## Permissions Best Practices

### Group Management

- Create groups aligned with business roles (e.g., "Sales Analysts", "Marketing Team", "External - Acme Corp")
- **Restrict the "All Users" group first** -- it is the baseline for all users
- Remember permissions are **additive**: most permissive group wins
- Use separate groups for internal users vs embedded/external users
- Document group purposes and membership criteria

### Data Sandboxing (Row/Column Security)

- Use user attributes to filter data dynamically per group
- Test sandboxing thoroughly; verify no data leakage across tenants
- **Important**: Sandboxed tables disable native SQL access for the entire database
- Use connection impersonation for database-role-based access
- Apply sandboxing consistently across all relevant tables

### Collection Organization

- Create a clear collection hierarchy reflecting business domains
- Use "Official" collections for vetted, approved content
- Restrict curate access; grant view access broadly
- Separate internal analytics from embedded/customer-facing content
- Archive unused questions and dashboards regularly

### Common Permission Pitfalls

| Pitfall | Problem | Prevention |
|---|---|---|
| "All Users" unrestricted | Granular permissions have no effect | Always restrict "All Users" first |
| Native SQL on sandboxed DB | Bypasses row/column security | Restrict sandboxed users to query builder only |
| Untested permissions | Data leakage to wrong users | Always test from the end-user perspective |
| Download permissions overlooked | Users download full datasets, bypassing RLS | Align download permissions with data access |
| Collection vs data confusion | User sees dashboard but gets empty results | Configure both collection AND data permissions |

---

## Performance Best Practices

### Caching Strategy

**Site-Wide Defaults:**
- Set a reasonable default caching policy (e.g., adaptive with 10x multiplier)
- Use duration-based caching for data that updates on a known schedule
- Use adaptive caching for ad-hoc queries with variable execution times

**Targeted Caching (Pro/Enterprise):**
- Set dashboard-specific policies for popular dashboards
- Configure question-specific policies for expensive queries
- Enable automatic cache refresh for critical dashboards
- Pre-warm caches via API before peak usage times

**Cache Hierarchy (use strategically):**
```
Question policy (highest priority)
  > Dashboard policy
    > Database policy
      > Site-wide default (lowest priority)
```

Set conservative defaults site-wide; apply aggressive overrides on hot dashboards and expensive questions.

### Database Optimization

| Technique | When | Example |
|---|---|---|
| **Indexes** | Columns in WHERE, JOIN, ORDER BY | `CREATE INDEX idx_orders_date ON orders(created_at)` |
| **Read replica** | Separate analytics from production | Point Metabase at replica to avoid production impact |
| **Materialized views** | Complex aggregations | Pre-compute during off-hours; query materialized view |
| **Summary tables** | Common dashboard query patterns | Denormalized tables for frequent aggregations |
| **JSON extraction** | Queries on JSON blobs | Extract keys into dedicated columns |
| **Column types** | Runtime conversion overhead | Ensure correct types at schema level |

### Query Performance

- Ask for less data: use default filters, limit time ranges
- Avoid over-aggregation: summarize at the right granularity
- Use models to standardize and optimize common data paths
- Monitor query performance via Metabase's usage analytics (Pro/Enterprise)
- Identify and refactor slow queries using database tools (e.g., `pg_stat_statements`)

### Infrastructure

- Use PostgreSQL (not H2) for the application database in production
- Scale Metabase horizontally with clustered deployment for high concurrency
- Consider OLAP databases (BigQuery, Redshift, Snowflake, Druid) for heavy analytics
- Monitor JVM memory and thread usage via JMX/VisualVM
- Configure appropriate JVM heap size: `-Xmx` based on workload (1-4 GB typical)

### Housekeeping

- Use usage analytics to identify unused questions and dashboards
- Archive or delete stale content to reduce sync and scan overhead
- Review and optimize database sync and scan schedules
- Clean up unused database connections
- Disable JSON unfolding on tables where it is not needed (significantly reduces sync time)
