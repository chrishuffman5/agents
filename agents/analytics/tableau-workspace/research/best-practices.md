# Tableau Best Practices

## Dashboard Performance

### Extract Optimization
- **Filter early**: Reduce extract size by filtering at the data source level; only include rows needed for analysis
- **Hide unused fields**: Remove columns not used in any visualization to shrink extract size
- **Aggregate extracts**: Use "Aggregate data for visible dimensions" to pre-aggregate; e.g., replacing 50M rows with 50K summaries dramatically reduces refresh time and query load
- **Incremental refresh**: Configure based on timestamp/ID columns; achieves 80-95% reduction in refresh time vs full refresh
- **Materialized calculations**: Add calculated fields to the extract to avoid repeated computation at query time

### Query Performance
- **Use Performance Recording**: Help > Performance Recording > Start/Stop; analyze the resulting workbook to identify slow queries, rendering, and layout
- **Run Workbook Optimizer**: Server > Run Optimizer (2022.1+); examines calculations against best practices and suggests improvements
- **Minimize marks**: Reduce the number of marks rendered; high mark counts slow rendering significantly
- **Reduce filters**: Each quick filter generates a separate query; use action filters or parameters instead where possible
- **Avoid COUNTD on large datasets**: Count distinct is expensive; consider pre-aggregating in the data source
- **Use context filters**: Promote frequently used filters to context to reduce the working dataset for subsequent filters
- **Limit dashboard scope**: Keep dashboards focused; 2-3 views per dashboard is ideal for performance

### Action Design
- **Prefer action filters over quick filters**: Action filters generate fewer queries
- **Limit cross-dashboard actions**: Each action target adds query overhead
- **Use "Exclude All Values" as default**: Prevents unnecessary initial queries on target sheets
- **Set actions for complex filtering**: More performant than cascading filter actions for set-based logic

### Extract Refresh Strategies
- **Schedule off-peak**: Run refreshes between 2-6 AM to avoid impacting interactive users
- **Incremental + periodic full**: Daily/hourly incremental refreshes with weekly full refresh for data integrity
- **Parallel execution**: Enable parallel backgrounder processing for multiple simultaneous refreshes
- **Stagger schedules**: Avoid scheduling all refreshes at the same time to prevent resource contention
- **Monitor refresh duration**: Track trends; increasing duration signals data growth or query issues

---

## Data Modeling

### When to Use Relationships
- Multiple tables at different levels of detail (e.g., orders + order items + customers)
- Many-to-many associations between tables
- Want Tableau to automatically determine appropriate join types per query context
- Building normalized, reusable data sources
- Default choice for new data models (2020.2+)

### When to Use Joins
- Need explicit control over join type (inner, left, right, full outer)
- Combining tables within a single logical table
- Shared dimension tables (star schema within physical layer)
- Upgrading or maintaining pre-2020.2 data sources
- Performance-critical scenarios where you need deterministic query behavior

### Data Blending (Legacy)
- Cross-database linking using a primary and secondary data source
- Being replaced by cross-database relationships in the logical layer
- Still useful when: combining data from incompatible sources, quick ad-hoc analysis
- Limitations: secondary source is always aggregated, limited calculation support
- Best practice: migrate to relationships/cross-database joins when possible

### Dimensional Modeling for Tableau
- Use star schema design: central fact table with dimension tables
- Keep fact tables narrow (keys + measures); put descriptive attributes in dimensions
- Pre-aggregate where appropriate (summary fact tables for common queries)
- Use surrogate keys for joins; avoid joining on text fields

---

## LOD Expression Patterns

### Cohort Analysis
```
// First purchase date per customer
{FIXED [Customer ID] : MIN([Order Date])}

// Assign customers to monthly cohorts
DATETRUNC('month', {FIXED [Customer ID] : MIN([Order Date])})
```

### Customer Counts at Different Granularity
```
// Total customers per region (regardless of view granularity)
{FIXED [Region] : COUNTD([Customer ID])}

// Customers per product including sub-category detail
{INCLUDE [Sub-Category] : COUNTD([Customer ID])}
```

### Percentage of Total
```
// Sales as percentage of category total
SUM([Sales]) / {FIXED [Category] : SUM([Sales])}

// Sales as percentage of grand total (no dimensions = overall)
SUM([Sales]) / {FIXED : SUM([Sales])}

// Using EXCLUDE for percentage within current view context minus one dimension
SUM([Sales]) / {EXCLUDE [Sub-Category] : SUM([Sales])}
```

### Customer Lifetime Value
```
// Total revenue per customer
{FIXED [Customer ID] : SUM([Sales])}

// Average order value per customer
{FIXED [Customer ID] : AVG([Sales])}
```

### Repeat Purchase Analysis
```
// Number of orders per customer
{FIXED [Customer ID] : COUNTD([Order ID])}

// Flag repeat customers
IF {FIXED [Customer ID] : COUNTD([Order ID])} > 1 THEN "Repeat" ELSE "New" END
```

### Filter Interaction Notes
- FIXED expressions ignore dimension filters (applied before them in the pipeline)
- Use **context filters** to make dimension filters apply before FIXED LODs
- INCLUDE/EXCLUDE expressions respect dimension filters
- Data source filters and extract filters always apply before all LOD expressions

---

## Visual Best Practices

### Chart Selection
| Data Question | Recommended Chart |
|---------------|-------------------|
| Compare quantities | Bar chart (horizontal for many categories) |
| Trends over time | Line chart |
| Part-to-whole | Stacked bar, treemap (not pie chart) |
| Distribution | Histogram, box plot |
| Correlation | Scatter plot |
| Geographic | Map (filled or symbol) |
| Detailed comparison | Highlight table, heat map |
| KPI summary | Big number (BAN), bullet chart |

### Color Principles
- Start with a neutral base; add color sparingly to emphasize key data
- Limit palette to 4 primary colors maximum
- Use gradients/saturation for intensity within the same measure
- Avoid red-green scales (color blindness); use orange-blue or icons instead
- AI-assisted palettes (2026.1) can generate accessible themes from text prompts
- Use consistent color encoding across dashboard views (same color = same meaning)

### Layout Principles
- Place important content (KPIs, summaries) at top-left (users scan left-to-right, top-to-bottom)
- Use negative space and padding to delineate sections (avoid heavy grid lines)
- Make important visualizations larger than secondary ones
- Group related charts together for cohesive narrative
- Limit to 2-3 primary views per dashboard for clarity and performance
- Use dashboard titles and section headers for navigation

### Typography & Labels
- Consistent font family throughout dashboard
- Descriptive axis labels and titles (not field names)
- Format numbers appropriately (currency, percentage, abbreviations for large numbers)
- Tooltips should provide context, not just repeat visible data

---

## Governance

### Permission Model
- **Manage permissions on projects**, not individual content items
- **Assign permissions to groups**, not individual users
- Use a **closed/restrictive model**: users get only the access needed for their role
- Lock permissions to project to prevent content-level overrides when needed

### Project Organization
- **Top-level projects** map to organizational structure (departments, business units)
- **Sub-projects** for teams within departments, with delegated project leaders
- **Personal Sandbox**: Single project where individuals save in-progress work; restricted so only owners see their own items
- **Department Sandbox**: Validation/staging area before content moves to certified/production projects
- **Production/Certified projects**: Governed content ready for broad consumption

### Data Source Certification
- Certify data sources that are trusted, validated, and ready for broad use
- Certified sources get preferential placement in search results and recommendations
- Clearly communicate certification criteria to content authors
- Assign data stewards responsible for certifying and maintaining data sources
- Use data quality warnings for sources with known issues

### Content Lifecycle
1. Author creates content in Personal Sandbox
2. Content moves to Department Sandbox for peer review and validation
3. After validation, content promoted to Production/Certified project
4. Apply certification badge for discoverability
5. Schedule regular content audits; archive or remove stale content

---

## Extract Refresh Strategies

### Full Refresh
- Rebuilds the entire extract from scratch
- Use for: initial loads, data corrections, schema changes, periodic integrity checks
- Schedule: weekly or as needed based on data volatility

### Incremental Refresh
- Appends only new rows based on a timestamp or auto-incrementing ID column
- 80-95% faster than full refresh
- Schedule: daily, hourly, or more frequently as needed
- Requires a reliable incremental key in the source data
- Pair with periodic full refresh (e.g., weekly) to catch updates/deletes

### Prep Flows
- Automate complex data preparation via Tableau Prep Conductor
- Schedule flows to run before extract refreshes in the pipeline
- Monitor flow execution and set up failure alerts
- Use for: multi-source blending, complex transformations, data quality rules

### Scheduling Best Practices
- Off-peak hours (2-6 AM) for non-time-sensitive refreshes
- Stagger start times to avoid backgrounder contention
- Monitor backgrounder queue depth; add backgrounder processes if queue grows
- Set reasonable timeouts; default 7200 seconds (2 hours)
- Use subscriptions to notify users when refreshes complete

---

## Content Management

### Projects
- Hierarchical organization mirroring business structure
- Lock permissions to project for consistent governance
- Use naming conventions: `[Department] - [Purpose]` (e.g., "Sales - Production", "Sales - Sandbox")

### Favorites, Subscriptions, Collections
- **Favorites**: Personal bookmarks for frequently accessed content
- **Subscriptions**: Scheduled email delivery of dashboard snapshots; useful for stakeholders who don't log in regularly
- **Collections**: Curated groups of related content items (workbooks, views, data sources) for sharing thematic sets
- **Data-driven alerts**: Automated notifications when data meets specified conditions

### Development Workflow

#### Version Control with .twb Files
- **.twb files** are XML; suitable for Git version control with meaningful diffs
- **.twbx files** are packaged (binary + data); Git tracks but cannot diff effectively
- Best practice: store .twb separately from data; use published data sources
- Avoid .twbx in version control for collaboration; use .twb + published data source

#### Dev-Test-Prod Promotion
- **Project-based**: Separate projects on same Server/Cloud site (simplest)
- **Site-based**: Separate sites for dev, test, production (stronger isolation)
- **Server-based**: Separate Server instances (strongest isolation, highest cost)
- Use Tableau REST API or `tabcmd` for automated content promotion between environments

#### Tableau Migration SDK
- Official SDK for building migration applications
- Primary use: migrating from Server to Cloud
- Supports: workbooks, data sources, projects, users, groups
- Available for Python and .NET developers
- Handles content transformation during migration (e.g., connection remapping)
