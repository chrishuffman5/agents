# Metabase Best Practices

## Question Design

### When to Use Each Question Type

**Query Builder (Graphical) - Use When:**
- Business users need self-service analytics without SQL knowledge
- Drill-through functionality is required (SQL questions do not support drill-through)
- Questions need to be easily modified by non-technical users
- Building on top of models for consistent data access
- Exploratory analysis where the schema is well-modeled

**Custom Questions (Advanced Query Builder) - Use When:**
- Complex aggregations, custom expressions, or calculated columns are needed
- Joins across multiple tables are required
- Users are comfortable with expression syntax but not SQL
- Drill-through is still desired

**Native/SQL Queries - Use When:**
- Complex logic that exceeds query builder capabilities (CTEs, window functions, subqueries)
- Database-specific syntax or functions are needed
- Performance-critical queries requiring hand-optimized SQL
- Integrating with parameterizable SQL snippets for reusable logic
- Using Metabot AI for SQL generation assistance

### Performance Considerations for Questions
- Prefer the query builder when possible; it generates optimized queries
- Use filters to limit data volume before aggregation
- Add database indexes on columns frequently used in WHERE, JOIN, and ORDER BY clauses
- Avoid SELECT * patterns in SQL; select only needed columns
- Use models as starting points to ensure consistent, well-indexed data paths
- For complex queries, consider creating summary tables or materialized views
- Test query performance directly against the database before saving

## Model Design

### When to Use Models
- When multiple questions query the same base data with the same joins/filters
- To create business-concept representations (e.g., "Active Customers", "Monthly Revenue")
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
- Set display names for every column (human-readable, business-friendly)
- Add descriptions explaining what each field represents and how it's calculated
- Assign correct semantic types (Currency, Category, FK, etc.) for proper filtering and visualization
- Map SQL columns to database columns to enable query builder exploration
- Configure visibility settings to hide internal/technical columns from end users
- Index string fields for search (up to 25,000 unique values) for entity lookups
- Use segments to define reusable filters (e.g., "Active Users", "Last 30 Days")
- Use measures to define reusable aggregations (e.g., "Total Revenue", "Average Order Value")

### Model Organization
- Place models in dedicated collections organized by business domain
- Use consistent naming conventions (e.g., prefix with domain: "Sales - Monthly Revenue")
- Document model purpose and intended audience in the description
- Review and update model metadata when underlying schemas change
- Use dependency checks (Pro/Enterprise) to monitor downstream impacts

## Dashboard Design

### Layout Best Practices
- **Card limit**: Keep dashboards to 20-25 cards maximum; more will slow load times
- **Use tabs**: Split content across tabs to reduce initial load and improve organization
- **Group related cards**: Cluster related visualizations together with logical flow
- **Color-code**: Use consistent color schemes for related metrics
- **Include context**: Add text cards with explanations, definitions, and guidance
- **Heading cards**: Use headings to create clear visual sections
- **Progressive disclosure**: Put high-level summaries at top, details in lower sections or tabs

### Filter Best Practices
- Set default filter values to limit initial data load
- Limit data to recent time periods for faster loading
- Use linked filters for cascading relationships (e.g., Country > State > City)
- Wire filters to text cards for dynamic context
- Enable cross-filtering so chart clicks update other cards
- Keep filter count manageable (5-7 max per dashboard)
- Use locked parameters in embedded dashboards for security

### Interactivity Best Practices
- Configure click behavior to navigate between dashboards for drill-down workflows
- Use click actions to pass filter values between dashboards
- Include trend lines and goal lines for context
- Set up action buttons for common workflows (with write permissions)
- Design clear navigation paths through dashboard hierarchies

### Performance Best Practices
- Limit cards per tab/dashboard to 20-25
- Use default filters to reduce initial query load
- Avoid redundant queries; combine series on single charts where possible
- Use models as data sources for consistency and potential caching benefits
- Consider splitting heavy dashboards into multiple focused dashboards
- Test dashboard load times during development

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
- Set appropriate session duration via MAX_SESSION_AGE
- Use Entity IDs for stable references across environments
- Configure authorized origin URLs for security
- Use PostMessage for frame sizing and location tracking

**Modular Embedding SDK (Custom Integration):**
- Best for: React applications requiring component-level control
- Match SDK version to Metabase version exactly
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

## Permissions Best Practices

### Group Management
- Create groups aligned with business roles (e.g., "Sales Analysts", "Marketing Team")
- Restrict the "All Users" group first; it's the baseline for all users
- Remember permissions are additive: most permissive group wins
- Use separate groups for internal users vs embedded/external users
- Document group purposes and membership criteria

### Data Sandboxing (Row/Column Security)
- Use user attributes to filter data dynamically per group
- Test sandboxing thoroughly; verify no data leakage across tenants
- Note: sandboxed tables disable native SQL access for the entire database
- Use connection impersonation for database-role-based access
- Apply sandboxing consistently across all relevant tables

### Collection Organization
- Create a clear collection hierarchy reflecting business domains
- Use "Official" collections for vetted, approved content
- Restrict curate access; grant view access broadly
- Separate internal analytics from embedded/customer-facing content
- Archive unused questions and dashboards regularly

### Common Pitfalls
- Forgetting to restrict "All Users" group before setting granular permissions
- Granting native query access to sandboxed databases (won't work)
- Not testing permissions from the end-user perspective
- Overlooking download permissions (can bypass row-level security)
- Not accounting for collection permission additivity

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

**Cache Hierarchy:**
- Question > Dashboard > Database > Site-wide (highest to lowest priority)
- Use this hierarchy to set conservative defaults and aggressive overrides

### Database Optimization
- **Indexes**: Add indexes on columns used in WHERE, JOIN, ORDER BY
- **Replica databases**: Point Metabase at a read replica to avoid impacting production
- **Materialized views**: Pre-compute complex aggregations during off-hours
- **Summary tables**: Create denormalized tables for common query patterns
- **JSON extraction**: Extract JSON keys into dedicated columns instead of querying JSON blobs
- **Column types**: Ensure correct data types at the schema level to avoid runtime conversion

### Query Performance
- Ask for less data: use default filters, limit time ranges
- Avoid over-aggregation: summarize at the right granularity
- Use models to standardize and optimize common data paths
- Monitor query performance via Metabase's usage analytics
- Identify and refactor slow queries using database tools (e.g., pg_stat_statements)

### Infrastructure
- Use PostgreSQL (not H2) for the application database in production
- Scale Metabase horizontally with clustered deployment for high concurrency
- Consider OLAP databases (BigQuery, Redshift, Snowflake, Druid) for heavy analytics workloads
- Monitor JVM memory and thread usage via JMX/VisualVM
- Configure appropriate JVM heap size for your workload

### Housekeeping
- Use usage analytics to identify unused questions and dashboards
- Archive or delete stale content to reduce sync and scan overhead
- Review and optimize database sync and scan schedules
- Clean up unused database connections

## Sources

- [Making Dashboards Faster](https://www.metabase.com/learn/metabase-basics/administration/administration-and-operation/making-dashboards-faster)
- [BI Dashboard Best Practices](https://www.metabase.com/learn/metabase-basics/querying-and-dashboards/dashboards/bi-dashboard-best-practices)
- [SQL Best Practices](https://www.metabase.com/learn/sql/working-with-sql/sql-best-practices)
- [SQL Performance Tuning](https://www.metabase.com/learn/grow-your-data-skills/data-landscape/sql-performance-tuning)
- [Metabase at Scale](https://www.metabase.com/learn/metabase-basics/administration/administration-and-operation/metabase-at-scale)
- [Metabase in Production](https://www.metabase.com/learn/metabase-basics/administration/administration-and-operation/metabase-in-production)
- [Metabase and Your Database](https://www.metabase.com/learn/metabase-basics/administration/administration-and-operation/metabase-and-your-db)
- [Data Permissions Tutorial](https://www.metabase.com/learn/metabase-basics/administration/permissions/data-permissions)
- [Row Permissions Tutorial](https://www.metabase.com/learn/metabase-basics/administration/permissions/row-permissions)
- [Caching Documentation](https://www.metabase.com/docs/latest/configuring-metabase/caching)
- [Embedding Documentation](https://www.metabase.com/docs/latest/embedding/static-embedding)
- [Metabase Housekeeping](https://www.metabase.com/blog/metabase-housekeeping-with-usage-analytics)
