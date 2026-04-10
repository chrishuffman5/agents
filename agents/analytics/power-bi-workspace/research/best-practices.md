# Power BI Best Practices

> Research date: April 2026

## Data Modeling

### Star Schema Design

Star schema is the foundation of performant Power BI data models. The VertiPaq engine is specifically optimized for star schema patterns -- proper dimension/fact separation can reduce model size by 60% and improve query speed by 10x or more.

**Core Principles:**

1. **Separate dimensions from facts**: Dimension tables describe business entities (Customer, Product, Date); fact tables record business events (Sales, Orders)
2. **One-to-many relationships**: Always aim for one-to-many from dimension to fact, with single cross-filter direction
3. **Integer surrogate keys**: Use integer surrogate keys as primary keys rather than natural business keys -- smaller, compress better in VertiPaq
4. **Dedicated date table**: Mark as date table; include all needed date attributes; never rely on auto date/time
5. **Narrow fact tables**: Remove descriptive columns from fact tables; keep only foreign keys and measures

### Relationships

- **Prefer single-direction cross-filtering**: Dimension filters flow to fact table
- **Avoid bidirectional relationships**: They produce ambiguous results with multiple paths, degrade query performance, and make DAX behavior unpredictable
- **Use DAX for bidirectional when needed**: CROSSFILTER or TREATAS on a per-measure basis instead of model-level bidirectional
- **Many-to-many**: Resolve with a bridge table containing only foreign keys from both dimensions, creating two one-to-many relationships
- **One-to-one**: Rare; usually indicates tables should be merged or redesigned

### Validation Checklist

- No bidirectional relationships except for bridge tables
- All relationships are one-to-many with single cross-filter direction
- No circular dependency paths
- All dimension tables have a unique key column
- Date table is marked and complete (no gaps)

---

## DAX Performance

### Use Native Aggregation Functions

Native functions (SUM, COUNT, AVERAGE, MIN, MAX) run in the multithreaded Storage Engine. Iterator functions (SUMX, COUNTX, AVERAGEX) run in the single-threaded Formula Engine.

```dax
-- SLOW: Iterator on large table
Bad_Total_Sales = SUMX(Sales, Sales[Quantity] * Sales[UnitPrice])

-- FAST: Pre-computed column or measure with native SUM
Good_Total_Sales = SUM(Sales[SalesAmount])
```

On a 2M-row fact table, the iterator version runs noticeably slower while the native version completes in milliseconds.

### Leverage Variables (VAR/RETURN)

Variables evaluate once per query context and reuse the result. Avoids repeated execution and reduces Formula Engine overhead.

```dax
-- WITHOUT variables: Revenue calculated twice
Bad Margin % =
DIVIDE(
    SUM(Sales[Revenue]) - SUM(Sales[Cost]),
    SUM(Sales[Revenue])
)

-- WITH variables: Revenue calculated once
Good Margin % =
VAR Revenue = SUM(Sales[Revenue])
VAR Cost = SUM(Sales[Cost])
RETURN DIVIDE(Revenue - Cost, Revenue)
```

### Use SUMMARIZECOLUMNS Over SUMMARIZE

SUMMARIZECOLUMNS generates better query plans and is optimized for large datasets. It is the function the Power BI engine itself generates for visual queries.

### CALCULATE Best Practices

- Always understand current filter context before modifying it
- Use REMOVEFILTERS (not ALL) to explicitly clear filters when intent is removal
- Avoid nested CALCULATE when possible -- restructure with variables
- Be careful with context transition in iterators

### Time Intelligence

- Use time intelligence functions (DATESYTD, SAMEPERIODLASTYEAR) only in CALCULATE filter arguments
- Dangerous in iterators due to implicit context transition
- Always have a proper date table with no gaps

### General DAX Guidelines

- Remove unused measures and calculated columns
- Prefer measures over calculated columns when possible (measures evaluate at query time, don't consume storage)
- Avoid FILTER with large tables as the first argument -- use column filters in CALCULATE instead
- Test with DAX Studio to understand Storage Engine vs Formula Engine split

---

## Power Query Optimization

### Query Folding

Query folding is the most critical Power Query optimization. It translates transformation steps into native source queries (SQL, etc.) for server-side processing.

**Rules for Maintaining Folding:**

1. **Put foldable steps first**: Filtering, column selection, joins, aggregations fold well
2. **Delay non-foldable steps**: Text transformations, custom columns, complex type changes -- put these after foldable steps
3. **Use native connectors**: SQL Server connector over ODBC/OLE DB for better folding support
4. **Check folding status**: Right-click a step > "View Native Query" -- if greyed out, folding has broken at that step

**Common Folding Breakers:**

- Adding custom columns with complex M logic
- Using Table.Buffer
- Merging queries from different data sources
- Certain text transformations (depending on source)
- Using List.Generate or custom functions

### General Power Query Best Practices

- **Filter early**: Reduce row count as early as possible in the query
- **Remove unnecessary columns**: Select only needed columns to reduce data volume
- **Avoid unnecessary type changes**: Don't convert types multiple times
- **Reference vs Duplicate**: Use reference queries to avoid redundant data loads
- **Staging queries**: Create staging queries that fold, then apply non-foldable transforms in dependent queries
- **Disable load for intermediate queries**: Intermediate/staging queries should have "Enable load" unchecked

---

## Report Design

### Performance-Oriented Design

- **Limit visuals per page**: Microsoft recommends no more than 8 visuals per page; reducing from many visuals to 8 can cut load time by 50%+
- **One table/matrix per page**: Tables and matrices are expensive visuals
- **Use report backgrounds**: Static images as backgrounds instead of multiple shape/textbox visuals
- **Minimize slicers**: Use hierarchy slicers or dropdowns instead of dozens of individual slicers
- **Filter pane over slicers**: The filter pane is more performance-efficient than visible slicers
- **Avoid cascading slicers**: Each change triggers multiple queries

### Bookmarks and Navigation

- Use bookmarks for toggle states, show/hide panels, and navigation
- **Caution**: Hidden visuals via bookmarks may still load in background
- For performance-critical pages, use separate pages rather than bookmark-hidden content
- Drillthrough pages reduce initial page load by separating detail data

### Field Parameters

- Let users dynamically switch measures/dimensions without multiple visuals
- Reduces visual count and bookmark complexity
- Improves both performance and user experience

### Visual Best Practices

- Prefer simple visuals (card, bar chart) over complex ones (maps, decomposition trees) for landing pages
- Use tooltips for supplementary detail instead of adding more visuals
- Limit number of data points per visual (e.g., top N filtering)
- Test with Performance Analyzer to identify slow visuals

---

## Deployment (ALM)

### Deployment Pipelines

- Use 3+ stages: Development, Test, Production (up to 10 stages supported)
- Configure deployment rules for environment-specific parameters (connection strings, data sources)
- Automate with deployment pipeline REST API
- PPU can back Dev/Test stages; Premium/Fabric for Production
- As of 2025: supports continuous deployment for Org Apps

### XMLA Endpoint

- Read/write access to semantic models via XMLA protocol
- Enables third-party tools (Tabular Editor, ALM Toolkit, DAX Studio)
- Supports scripted deployments, incremental refresh via TMSL
- Available in PPU and F64+ capacities
- Use for CI/CD scenarios with Azure DevOps or GitHub Actions

### PBIR Format (Git Integration)

- JSON-based report format for meaningful source control diffs
- Moving to default in April 2026
- Enables branch-based development workflows
- Combine with Fabric git integration for full DevOps

### ALM Toolkit

- Open-source schema comparison for semantic models
- Compare development vs production models
- Deploy schema changes while preserving data (including incremental refresh partitions)
- Critical for enterprise ALM workflows

---

## Security

### Row-Level Security (RLS)

- Restricts data access at the row level based on user identity
- **Static RLS**: Hardcoded values in DAX filter (e.g., `[Region] = "West"`)
- **Dynamic RLS**: Uses USERPRINCIPALNAME() or CUSTOMDATA() to filter based on logged-in user
- Defined in Desktop or Service, tested with "View as" role feature
- Always test RLS with DAX Studio or "View as" before production deployment

### Object-Level Security (OLS)

- Hides entire tables or specific columns from unauthorized users
- Unlike RLS (filters rows), OLS hides schema elements
- **Only enforced in Premium/PPU/Fabric capacity** -- not in shared capacity
- Define via Tabular Editor or XMLA endpoint (not available in Desktop UI)

### Layered Security Model

1. **Workspace roles** (Admin, Member, Contributor, Viewer): Control who can access the workspace
2. **RLS**: Control which rows users see within a semantic model
3. **OLS**: Control which columns/tables are visible
4. **Sensitivity labels**: Microsoft Purview integration for data classification

### Workspace Role Best Practices

- Use Azure AD/Entra ID groups, not individual users
- Apply principle of least privilege
- Viewer role for consumers; Contributor for report authors
- Admin role only for workspace managers
- Review access quarterly

---

## Governance

### Endorsement

| Level | Who Can Apply | Purpose |
|---|---|---|
| **Promoted** | Any workspace member with write permissions | Signal that content is valuable and ready for use |
| **Certified** | Designated certifiers only (admin-configured) | Official quality standard; authoritative and reliable |

### Certification Checklist

- Data lineage documented with source systems identified
- Transformation logic reviewed
- All tables and columns described in semantic model
- Row-level security validated
- Sensitivity label applied
- Refresh schedule configured with failure alerting
- Performance benchmarked (under 2 seconds for common queries)
- Business sign-off obtained
- Certification record with date and next review date

### Sensitivity Labels (Microsoft Purview)

- Extend to workspaces, semantic models, reports, and dashboards
- Classification tiers: Highly Confidential, Confidential, Internal, Public
- Enable encryption, access restrictions, and audit logging
- Carry through when data is exported

### Data Lineage

- Enable Purview-Power BI integration to automatically scan and catalog all artifacts
- Visualize lineage from data source through semantic model to report
- Use Purview Business Glossary for authoritative data vocabulary
- Lineage view available in Power BI Service workspace settings

### Governance Framework

- Establish a Center of Excellence (CoE) with governance policies
- "Managed self-service": Empower business within governed framework
- Architecture review boards for new semantic models
- Quarterly governance health checks: workspace access review, sensitivity label coverage, endorsement status
- Workspace naming conventions and content organization standards

---

## Large Dataset Strategies

### Incremental Refresh

- Only refresh changed/new data instead of full reload
- Reduces refresh time dramatically (e.g., 2+ hours to 5 minutes)
- Configure with RangeStart/RangeEnd parameters in Power Query
- Supports real-time mode: latest time window via DirectQuery, older data stays imported (hybrid tables)
- Combine with XMLA endpoint for programmatic partition management

### Aggregations

- Pre-aggregated tables for common query patterns
- 95% of queries can be served from aggregations, never touching detail data
- Use Dual storage mode for aggregation tables
- Automatic aggregations available in Premium/Fabric

### Composite Models

- Mix Import (fast, cached) with DirectQuery (real-time, on-demand)
- Detail queries hit source on demand; aggregate queries served from memory
- Reduced model size: e.g., 4 GB down to 400 MB active memory

### Capacity Planning

- Stagger refresh schedules across 2-hour windows
- Remove unused columns and tables from models
- Limit visuals to 8-12 per page
- Upgrade capacity SKU when sustained CU utilization exceeds 80% during business hours

---

## Development Tools

### Tabular Editor (TE2 / TE3)

- **TE2** (open-source): Free; model editing, Best Practice Analyzer
- **TE3** (commercial): Full IDE for semantic model development; IntelliSense, VertiPaq Analyzer, scripting, Best Practice Analyzer, diagram view
- Edit measures, tables, relationships, calculation groups, perspectives
- Connect via XMLA endpoint to Premium/PPU models
- Best Practice Analyzer: automated checks for modeling standards

### DAX Studio

- Write, execute, and analyze DAX queries
- **Performance tracing**: Storage Engine vs Formula Engine breakdown
- **VertiPaq Analyzer** (View Metrics): Table/column sizes, cardinality, compression ratios
- Import Power BI Performance Analyzer data for deeper analysis
- Server Timings: detailed query execution metrics
- Free and open-source

### ALM Toolkit

- Schema comparison between semantic model versions
- Deploy changes from dev to production preserving data
- Critical for incremental refresh scenarios (preserves historical partitions)
- Open-source

### VPAX Files

- Portable VertiPaq Analyzer exports
- Generated by Tabular Editor 3 or DAX Studio
- Shareable snapshots of model metadata for review
- Analyze column cardinality, sizes, referential integrity without access to actual data

### Additional Tools

- **Power BI Helper**: Documentation generation for models
- **Bravo**: Desktop tool for date table generation, format strings, VertiPaq analysis
- **pbi-tools**: Command-line tool for extracting .pbix into source-controlled files

---

## Sources

- [Star Schema Importance - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/guidance/star-schema)
- [Star Schema Data Modeling 2026](https://powerbiconsulting.com/blog/data-modeling-star-schema-best-practices-2026)
- [Data Model Types - Tabular Editor](https://tabulareditor.com/blog/data-model-types-examples-and-tips-for-power-bi-part-2)
- [DAX Query Optimization - B EYE](https://b-eye.com/blog/dax-query-optimization-power-bi/)
- [DAX Best Practices - MAQ Software](https://maqsoftware.com/insights/dax-best-practices)
- [Improve DAX Performance](https://thedatacommunity.org/2025/12/28/improve-dax-performance/)
- [SUMMARIZECOLUMNS - DAX Guide](https://dax.guide/summarizecolumns/)
- [Query Folding Guidance - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/guidance/power-query-folding)
- [Query Folding in Power BI - phData](https://www.phdata.io/blog/query-folding-in-power-bi-the-secret-to-faster-data-refresh-performance/)
- [Power BI Performance Optimization - B EYE](https://b-eye.com/blog/power-bi-performance-optimization-best-practices/)
- [Power BI Best Practices - MAQ Software](https://maqsoftware.com/insights/power-bi-best-practices)
- [Report Rendering Optimization](https://b-eye.com/blog/power-bi-report-rendering-visual-performance-optimization/)
- [RLS Guidance - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/guidance/rls-guidance)
- [Power BI Data Governance - Dataedo](https://dataedo.com/blog/power-bi-data-governance-from-chaos-to-trusted-insights-practical-guide)
- [Endorsement - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/collaborate-share/service-endorsement-overview)
- [Fabric Governance 2026](https://powerbiconsulting.com/blog/microsoft-fabric-data-governance-compliance-2026)
- [Workspace Governance 2026](https://powerbiconsulting.com/blog/power-bi-workspace-governance-tenant-settings-guide-2026)
- [Incremental Refresh - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/connect-data/incremental-refresh-overview)
- [Large Dataset Optimization - B EYE](https://b-eye.com/blog/optimize-power-bi-data-models-large-datasets/)
- [Deployment Pipelines - Microsoft Learn](https://learn.microsoft.com/en-us/fabric/cicd/deployment-pipelines/get-started-with-deployment-pipelines)
- [XMLA Endpoint - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/enterprise/service-premium-connect-tools)
- [External Tools - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-external-tools)
- [Tabular Editor Guide 2026](https://powerbiconsulting.com/blog/power-bi-tabular-editor-model-development-guide-2026)
- [DAX Studio - SQLBI](https://www.sqlbi.com/tools/dax-studio/)
