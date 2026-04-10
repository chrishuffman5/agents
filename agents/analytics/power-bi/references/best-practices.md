# Power BI Best Practices Reference

## Data Modeling

### Star Schema Design

Star schema is the foundation of performant Power BI data models. The VertiPaq engine is specifically optimized for star schema patterns -- proper dimension/fact separation can reduce model size by 60% and improve query speed by 10x or more.

**Core principles:**

1. **Separate dimensions from facts**: Dimension tables describe business entities (Customer, Product, Date); fact tables record business events (Sales, Orders)
2. **One-to-many relationships**: Always from dimension to fact, with single cross-filter direction
3. **Integer surrogate keys**: Use integers as primary keys, not natural business keys -- they compress far better in VertiPaq
4. **Dedicated date table**: Mark as date table; include all needed date attributes (Year, Quarter, Month, MonthName, Day, WeekDay, FiscalYear, etc.); no gaps in date range
5. **Narrow fact tables**: Remove descriptive columns from fact tables; keep only foreign keys and measure columns
6. **Disable auto date/time**: Model > Options > Data Load > uncheck "Auto date/time" to prevent hidden date tables that bloat the model

### Relationships

- **Prefer single-direction cross-filtering**: Dimension filters flow to fact table; this is the natural star schema direction
- **Avoid bidirectional relationships**: They produce ambiguous results with multiple filter paths, degrade query performance, and make DAX behavior unpredictable
- **Use DAX for bidirectional when needed**: CROSSFILTER or TREATAS on a per-measure basis instead of model-level bidirectional
- **Many-to-many**: Resolve with a bridge table containing only foreign keys from both dimensions, creating two one-to-many relationships
- **One-to-one**: Rare; usually indicates tables should be merged

### Validation Checklist

- No bidirectional relationships except for bridge tables with documented justification
- All relationships are one-to-many with single cross-filter direction
- No circular dependency paths
- All dimension tables have a unique key column
- Date table is marked and complete (no gaps)
- Auto date/time is disabled
- Referential integrity is clean (no orphan keys in fact tables)

---

## DAX Performance

### Use Native Aggregation Functions

Native functions (SUM, COUNT, AVERAGE, MIN, MAX) run in the multithreaded Storage Engine. Iterator functions (SUMX, COUNTX, AVERAGEX) run in the single-threaded Formula Engine.

```dax
-- SLOW: Iterator on large table (single-threaded FE)
Bad_Total_Sales = SUMX(Sales, Sales[Quantity] * Sales[UnitPrice])

-- FAST: Pre-computed column + native SUM (multithreaded SE)
Good_Total_Sales = SUM(Sales[SalesAmount])
```

If you need the multiplication, add a `SalesAmount` calculated column or (better) compute it in Power Query where query folding can push it to the source.

### Leverage Variables (VAR/RETURN)

Variables evaluate once per query context and reuse the result. They are the single most effective DAX performance optimization.

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

### CALCULATE Best Practices

- Always understand current filter context before modifying it
- Use REMOVEFILTERS (not ALL) to explicitly clear filters when intent is removal -- clearer semantics
- Avoid nested CALCULATE when possible -- restructure with variables
- Be careful with context transition in iterators: CALCULATE inside SUMX converts row context to filter context for every row
- Use column filter predicates directly in CALCULATE arguments instead of FILTER on large tables:

```dax
-- SLOW: FILTER materializes entire table
Bad = CALCULATE([Total Sales], FILTER(ALL('Product'), 'Product'[Category] = "Electronics"))

-- FAST: Column predicate handled by Storage Engine
Good = CALCULATE([Total Sales], 'Product'[Category] = "Electronics")
```

### Time Intelligence

- Use time intelligence functions (DATESYTD, SAMEPERIODLASTYEAR, DATEADD) only in CALCULATE filter arguments
- Always have a proper date table with no gaps, marked as date table
- Never use time intelligence functions inside iterators (they trigger context transition per row)
- Standard time intelligence measure pattern:

```dax
YTD Sales = CALCULATE([Total Sales], DATESYTD('Date'[Date]))

PY Sales = CALCULATE([Total Sales], SAMEPERIODLASTYEAR('Date'[Date]))

YoY % Change =
VAR CurrentSales = [Total Sales]
VAR PriorYearSales = [PY Sales]
RETURN DIVIDE(CurrentSales - PriorYearSales, PriorYearSales)
```

### Use SUMMARIZECOLUMNS Over SUMMARIZE

SUMMARIZECOLUMNS generates better query plans and is the function Power BI itself generates for visual queries. Prefer it in DAX queries and DAX Studio testing.

### General DAX Guidelines

- Remove unused measures and calculated columns (they consume processing time and model space)
- Prefer measures over calculated columns when possible (measures evaluate at query time, don't consume storage)
- Test with DAX Studio Server Timings to understand SE vs FE split
- Target: >90% of query time in Storage Engine for optimal performance
- Use DIVIDE instead of `/` to handle division by zero gracefully
- Use ISBLANK or ISEMPTY for null/empty checks rather than `= BLANK()`

---

## Power Query Optimization

### Query Folding

Query folding is the most critical Power Query optimization. It translates transformation steps into native source queries for server-side processing.

**Rules for maintaining folding:**

1. **Put foldable steps first**: Filtering, column selection, joins, aggregations fold well
2. **Delay non-foldable steps**: Text transformations, custom columns, complex type changes -- put these after foldable steps
3. **Use native connectors**: SQL Server connector over ODBC/OLE DB for better folding support
4. **Check folding status**: Right-click a step > "View Native Query" -- if greyed out, folding has broken at that step
5. **Staging queries**: Create staging queries that fold completely, then apply non-foldable transforms in dependent queries

**Common folding breakers:**
- Adding custom columns with complex M logic
- Using Table.Buffer
- Merging queries from different data sources
- Certain text transformations (depending on source)
- List.Generate or custom functions

### General Power Query Best Practices

- **Filter early**: Reduce row count as early as possible
- **Remove unnecessary columns**: Select only needed columns to reduce data volume
- **Avoid unnecessary type changes**: Don't convert types multiple times
- **Reference vs Duplicate**: Use reference queries to avoid redundant data loads
- **Disable load for intermediate queries**: Staging queries should have "Enable load" unchecked to prevent them from loading into the model
- **Parameterize data sources**: Use parameters for server names, database names, and file paths to support deployment across environments

---

## Report Design

### Performance-Oriented Design

- **Limit visuals per page**: No more than 8 visuals per page; reducing from many visuals to 8 can cut load time by 50%+
- **One table/matrix per page**: Tables and matrices are the most expensive visual types
- **Use report backgrounds**: Static images as backgrounds instead of multiple shape/textbox visuals
- **Minimize slicers**: Use hierarchy slicers or dropdowns instead of dozens of individual slicers; filter pane is more performance-efficient than visible slicers
- **Avoid cascading slicers**: Each change triggers multiple queries
- **Use drillthrough pages**: Separate detail data onto drillthrough pages to reduce initial page load

### Field Parameters

Let users dynamically switch measures/dimensions without requiring multiple visuals or bookmark-based solutions. Reduces visual count and improves both performance and user experience.

### Visual Best Practices

- Prefer simple visuals (card, bar chart) over complex ones (maps, decomposition trees) for landing pages
- Use tooltips for supplementary detail instead of adding more visuals
- Limit data points per visual (e.g., top N filtering)
- Test with Performance Analyzer to identify the slowest visuals on each page
- Hidden visuals (via bookmarks) may still load in the background -- use separate pages instead for performance-critical scenarios

---

## Deployment and ALM

### Deployment Pipelines

- Use 3+ stages: Development, Test, Production (up to 10 stages supported)
- Configure deployment rules for environment-specific parameters (connection strings, data sources)
- Automate with the deployment pipeline REST API
- PPU can back Dev/Test stages; Premium/Fabric for Production
- Supports continuous deployment for Org Apps (2025+)

### XMLA Endpoint

- Read/write access to semantic models via XMLA protocol
- Enables third-party tools: Tabular Editor, ALM Toolkit, DAX Studio
- Supports scripted deployments and incremental refresh via TMSL
- Available in PPU and F64+ capacities
- Use for CI/CD scenarios with Azure DevOps or GitHub Actions

### PBIR Format (Git Integration)

- JSON-based report format for meaningful source control diffs
- Becoming default in April 2026
- Enables branch-based development workflows
- Combine with Fabric git integration for full DevOps
- TMDL for semantic model definitions in source control alongside PBIR reports

### ALM Toolkit

- Open-source schema comparison for semantic models
- Compare development vs production models
- Deploy schema changes while preserving data (including incremental refresh partitions)
- Critical for enterprise ALM workflows where deployment pipelines are insufficient

### Development Tool Ecosystem

| Tool | Purpose | Cost |
|---|---|---|
| **Tabular Editor 2** | Model editing, Best Practice Analyzer | Free (open-source) |
| **Tabular Editor 3** | Full IDE: IntelliSense, VertiPaq Analyzer, scripting, diagram view | Commercial |
| **DAX Studio** | DAX query execution, Server Timings, VertiPaq Analyzer | Free (open-source) |
| **ALM Toolkit** | Schema comparison and deployment | Free (open-source) |
| **pbi-tools** | Extract .pbix into source-controlled files | Open-source |
| **Bravo** | Date table generation, format strings, VertiPaq analysis | Free |

---

## Security and Governance

### Row-Level Security (RLS)

- Restricts data access at the row level based on user identity
- **Static RLS**: Hardcoded values in DAX filter (`[Region] = "West"`)
- **Dynamic RLS**: Uses USERPRINCIPALNAME() or CUSTOMDATA() to filter based on logged-in user
- Defined in Desktop or Service; tested with "View as" role feature
- Always test with DAX Studio or "View as" before production deployment

```dax
-- Dynamic RLS filter expression on the Sales table
[SalesRep_Email] = USERPRINCIPALNAME()
```

### Object-Level Security (OLS)

- Hides entire tables or specific columns from unauthorized users
- Unlike RLS (filters rows), OLS hides schema elements
- Only enforced in Premium/PPU/Fabric capacity (not shared)
- Define via Tabular Editor or XMLA endpoint (not available in Desktop UI)

### Workspace Role Best Practices

- Use Azure AD/Entra ID groups, not individual users
- Apply principle of least privilege
- Viewer role for consumers; Contributor for report authors; Admin only for workspace managers
- Review access quarterly

### Endorsement

| Level | Who Can Apply | Purpose |
|---|---|---|
| **Promoted** | Any workspace member with write access | Signal content is valuable and ready for use |
| **Certified** | Designated certifiers only (admin-configured) | Official quality standard; authoritative and reliable |

### Certification Checklist

Before certifying a semantic model:
1. Data lineage documented with source systems identified
2. All tables and columns described in semantic model metadata
3. Row-level security validated with "View as" testing
4. Sensitivity label applied (Microsoft Purview integration)
5. Refresh schedule configured with failure alerting
6. Performance benchmarked (common queries under 2 seconds)
7. Business sign-off obtained with next review date recorded

### Governance Framework

- Establish a Center of Excellence (CoE) with governance policies
- "Managed self-service": empower business users within a governed framework
- Workspace naming conventions and content organization standards
- Quarterly governance health checks: access review, sensitivity label coverage, endorsement status
- Enable Purview-Power BI integration for automatic scanning and data lineage visualization

---

## Large Dataset Strategies

### Incremental Refresh

- Only refresh changed/new data instead of full reload
- Reduces refresh time dramatically (e.g., 2+ hours down to minutes)
- Configure with RangeStart/RangeEnd parameters in Power Query
- Supports real-time mode: latest time window via DirectQuery, older data stays imported (hybrid tables)
- Combine with XMLA endpoint for programmatic partition management

### Aggregations

- Pre-aggregated tables for common query patterns
- 95% of queries can be served from aggregations without touching detail data
- Use Dual storage mode for aggregation tables
- Automatic aggregations available in Premium/Fabric

### Composite Models

- Mix Import (fast, cached) with DirectQuery (real-time, on-demand)
- Detail queries hit source on demand; aggregate queries served from memory
- Reduced model size: e.g., 4 GB down to 400 MB active memory
- Composite models on Analysis Services: GA with multi-role RLS support

### Capacity Planning

- Stagger refresh schedules across 2-hour windows (not all at midnight)
- Remove unused columns and tables from models
- Limit visuals to 8-12 per page
- Upgrade capacity SKU when sustained CU utilization exceeds 80% during business hours
- Separate dev/test workloads onto different capacities
