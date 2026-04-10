# Qlik Sense Best Practices

## Data Modeling for the Associative Engine

### Target Data Model

Aim for a normalized **star schema** or **snowflake schema** as the primary data model structure. The star schema places a central fact table (containing keys and measures) surrounded by dimension tables (containing descriptive attributes). This is the most efficient and understandable structure for the Qlik associative engine.

### Schema Design Guidelines

| Guideline | Rationale |
|-----------|-----------|
| Use a star schema whenever possible | Optimizes memory, reduces synthetic keys, and provides best calculation performance |
| Consolidate small dimension tables | Snowflake branches with few records add overhead; consider denormalizing small lookups into parent dimensions |
| Use link tables for many-to-many relationships | Prevents synthetic keys and maintains clean associations |
| Avoid circular references | Creates ambiguity in the associative model; the engine will break them with loosely coupled tables, degrading performance |
| Resolve synthetic keys proactively | Qlik auto-creates synthetic keys when two tables share multiple fields; these are often unintended and cause performance issues |

### Synthetic Key Resolution Strategies

- **Concatenate composite keys**: Create a single key field from multiple shared fields (e.g., `Year & '-' & Month as YearMonth`)
- **Rename non-key fields**: When two tables share field names that are not intended as join keys, rename them to make them unique
- **Use link tables**: For complex relationships, create an explicit link/bridge table
- **Drop unneeded fields**: Remove fields from one table if they should not participate in the association

### Data Type Optimization

- Use `AutoNumber()` for key fields when optimal QVD loading is not required -- converts string keys to integers for faster lookups
- Separate date and time components (store `Date` and `Time` as distinct fields rather than `DateTime`) to reduce the symbol table size
- Use `Dual()` for fields that need both numeric and text representation
- Use flags (1/0) instead of string fields for conditional logic in expressions

### QVD Best Practices

- **QVD (Qlik Data) files** are Qlik's optimized binary format; reads are 10-100x faster than other sources
- Structure data pipelines as: Source -> QVD layer -> Application load
- Use **optimized QVD loads** (no transformations in the LOAD statement) for maximum speed
- Implement incremental QVD loading for large datasets: load only new/changed records, concatenate with existing QVD, then store back

### Memory and Compression

- The associative engine stores each unique value only once per field; minimize field cardinality where possible
- Remove unused fields early in the script (use `DROP FIELD` or exclude in `LOAD`)
- Avoid loading raw timestamps if only date granularity is needed
- Use `ApplyMap()` for lookups instead of joining large reference tables
- Profile your data model using the Data Model Viewer to identify memory-heavy fields

## Set Analysis Patterns

### Fundamental Patterns

**Ignore a selection on a specific field:**
```
Sum({$<Year=>} Sales)
```

**Force a specific field value:**
```
Sum({$<Year={2024}>} Sales)

// Multiple values
Sum({$<Year={2023,2024}>} Sales)
```

**All records, ignoring all selections:**
```
Sum({1} Sales)
```

**Comparative analysis (Year-over-Year):**
```
Sum({$<Year={$(=Max(Year)-1)}>} Sales)
```

### Intermediate Patterns

**Element set functions (P and E):**
```
// Customers who had purchases in 2024
Sum({$<Customer=P({1<Year={2024}>} Customer)>} Sales)

// Customers who did NOT purchase in 2024
Sum({$<Customer=E({1<Year={2024}>} Customer)>} Sales)
```

**Set operators (intersection, union, exclusion):**
```
// Intersection: both conditions
Sum({$<Year={2024}> * $<Region={'North'}>} Sales)

// Union: either condition
Sum({$<Year={2024}> + $<Year={2023}>} Sales)

// Exclusion
Sum({$<Year={2024}> - $<Region={'North'}>} Sales)
```

**Search expressions in modifiers:**
```
// Products with sales > 1000
Sum({$<Product={"=Sum(Sales)>1000"}>} Sales)

// Wildcard search
Sum({$<Product={"*Widget*"}>} Sales)
```

### Advanced Patterns

**Alternate states for parallel selection:**
```
// Compare two independent selections
Sum({State1} Sales) - Sum({State2} Sales)
```

**Dynamic field references with variables:**
```
SET vField = Year;
Sum({$<$(vField)={2024}>} Sales)
```

### Set Analysis Performance Tips

- Set analysis is evaluated before the aggregation, making it faster than equivalent `If()` conditions inside aggregations
- Use set analysis instead of `If(Condition, Value)` patterns in measures whenever possible
- Avoid nested `Aggr()` with set analysis when a simpler expression exists
- Cache frequently used set expressions in master items

## App Design Best Practices

### Structure and Navigation

- **Plan before building**: Sketch empty sheets first, with each sheet representing a specific analytical question or workflow step
- **Follow the DAR pattern**: Organize sheets into Dashboard (overview), Analysis (exploration), and Reporting (detail/export) categories
- **Maintain consistency**: Place navigation elements and common filters in the same position across all sheets
- **Limit objects per sheet**: Target 5-8 objects on dashboard sheets, up to 12 on analysis sheets; more objects means more recalculation on every selection

### Visualization Guidelines

| Do | Avoid |
|----|-------|
| Use bar charts for comparison across categories | Using pie charts for more than 5-7 segments |
| Use line charts for trends over time | Overloading line charts with more than 4-5 measures |
| Use KPIs for headline metrics with context | Showing KPIs without comparative context (vs. prior period, target) |
| Use consistent color coding across sheets | Using more than 7-9 colors; accessibility issues with red/green only |
| Use filter panes for guided selection | Relying solely on click-to-select without visible filter controls |
| Provide titles and labels on all objects | Using chart types that do not match the analytical intent |

### Color and Accessibility

- Limit the color palette; use color purposefully to encode meaning
- Avoid relying solely on red/green distinctions (color blindness consideration)
- Use shapes, patterns, or size in addition to color for critical indicators
- Test apps on the devices and screen sizes where they will be consumed

### Master Items

- Define all reusable dimensions and measures as master items
- Master items ensure expression caching and calculation consistency
- Use descriptive names and add descriptions/tags for discoverability
- Group related master items with consistent naming conventions

### Responsive Layout

- Design for the primary consumption device first
- Use Qlik Sense's responsive grid and test at different breakpoints
- Create a dedicated mobile-optimized sheet view when mobile usage is significant

## Performance Optimization

### Data Model Optimization

| Action | Impact |
|--------|--------|
| Remove synthetic keys | Eliminates unintended cross-table calculations |
| Remove circular references | Prevents ambiguous associations and loosely coupled tables |
| Reduce field count | Drop fields not used in visualizations or calculations |
| Use QVD files for data pipeline | 10-100x faster reads; reduces reload time significantly |
| Implement incremental loading | Only process new/changed records; critical for large datasets |
| Consolidate snowflake tables | Join small dim tables to reduce table count and association overhead |
| Use AutoNumber for keys | Converts string keys to integers for faster lookups |
| Decouple date from timestamp | Reduces unique value count in date fields |

### Expression Optimization

| Action | Impact |
|--------|--------|
| Use set analysis over `If()` | Set filters apply before aggregation (faster) |
| Minimize `Aggr()` usage | Nested `Aggr()` forces row-level recalculation |
| Avoid string functions in expressions | `Match()`, `WildMatch()` are slower than numeric flag comparisons |
| Pre-calculate in script | Move complex calculations to load script when they operate at base granularity |
| Use master items | Enables expression caching; same expression used multiple times is calculated once |
| Add calculation conditions | Prevent charts from calculating over unrestricted data sets |

### Object and Sheet Optimization

- Limit straight tables to fewer than 15 columns
- Add calculation conditions to expensive objects (e.g., "Select a Region to display data")
- Use container objects to show one visualization at a time while keeping others in tabs
- Minimize the use of `Always one selected value` on large-cardinality fields

### Architecture Strategies for Large Data

| Strategy | When to Use |
|----------|-------------|
| **QVD Segmentation** | Partition QVDs by time period, region, or aggregation level to reduce per-app memory |
| **On-Demand App Generation (ODAG)** | Users select criteria in an aggregated app, triggering generation of a detail app with only relevant data |
| **Application Chaining** | Pass selections between aggregated overview apps and detailed drill-down apps |
| **Binary Load** | Load the data model from another app to share data across related apps |
| **Section Access** | Apply row-level security to serve multiple user groups from a single app |

### Reload Optimization

- Use optimized QVD loads (no field transformations, no WHERE clause)
- Implement incremental loading with `Max()` watermark fields
- Break large scripts into modular subroutines (`SUB`/`END SUB`)
- Use `STORE` statements strategically to create reusable QVD checkpoints
- Add error handling with `ErrorMode`, `ScriptError`, and logging
- Schedule heavy reloads during off-peak hours to avoid engine contention

## Governance Best Practices

### Development Lifecycle

1. **Personal Space**: Individual development and prototyping
2. **Shared Space**: Team collaboration and peer review
3. **Managed Space**: Published production apps with controlled access
4. **Promotion Process**: Formalize app promotion from development to production with review gates

### Naming Conventions

- Standardize app, sheet, and object naming across the organization
- Use prefixes for environment (DEV_, UAT_, PROD_)
- Name master items with business-friendly terms, not technical field names
- Document load script sections with comments and consistent section headers

### Data Governance

- Centralize data connections; avoid ad-hoc connections per app
- Use managed spaces for production data assets
- Implement section access for row-level security rather than duplicating apps
- Catalog data sources with Qlik Talend Cloud for lineage and quality tracking
- Define data ownership and stewardship roles

### Change Management

- Use version control for load scripts (export and track in Git)
- Document data model changes and their business rationale
- Maintain a testing/staging environment for validating changes before production deployment
- Communicate updates to users when app structures change

## Deployment Best Practices

### Client-Managed (On-Premise)

- Deploy the repository database on a separate dedicated server for multi-node setups
- Place all nodes within the same data center with sub-4ms latency to the file share
- Use 10 Gbps networking between nodes and the file share
- Configure load balancing rules to distribute engine load across RIM nodes
- Designate at least one failover candidate node
- Monitor with the Operations Monitor and License Monitor apps
- Plan server RAM to accommodate the largest apps fully loaded plus overhead for concurrent user sessions

### Qlik Cloud (SaaS)

- Use managed spaces for governed content distribution
- Configure identity provider integration (SAML/OIDC) before user onboarding
- Set up Qlik Automate workflows for operational tasks (reload monitoring, alerts)
- Use Qlik Data Integration for centralized data pipeline management
- Implement content tagging and organization for discoverability
- Plan for the 5 GB per-app memory limit; use ODAG or segmentation for larger datasets
