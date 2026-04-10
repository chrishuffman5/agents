# Analytics / BI Foundational Concepts

Deep reference for cross-platform analytics theory. This file covers concepts that apply across all BI tools and reporting platforms, with implementation-specific callouts where platforms diverge.

## Dimensional Modeling (Kimball Methodology)

The standard approach for structuring analytical data. Ralph Kimball's methodology has been the dominant data warehouse design pattern for three decades because it optimizes for query performance and user comprehension.

### Facts, Dimensions, and Grain

**Fact tables** store measurements at a specific grain:
- Narrow tables: foreign keys to dimensions + numeric measures
- Each row represents a business event (a sale, a shipment, a click)
- Grain must be declared explicitly before designing the table
- Example: `fact_sales` at the grain of "one row per order line item per transaction"

**Dimension tables** store descriptive context:
- Wide tables: denormalized hierarchies, text descriptions, attributes
- Each row represents a business entity (a customer, a product, a date)
- Slowly Changing Dimensions (SCD) handle changes over time:
  - **Type 1:** Overwrite the old value. Simple but loses history.
  - **Type 2:** Add a new row with effective dates (`valid_from`, `valid_to`). Preserves full history. Most common for analytical warehouses.
  - **Type 3:** Add a "previous" column. Tracks one prior value only. Rarely used.

**Grain** is the most important design decision:
- Defines what one row represents in a fact table
- Must be stated as a business-readable sentence: "one row per order line item per day"
- Mixing grains in a single fact table causes incorrect aggregations (double-counting, fan-out)
- When in doubt, go to the most atomic grain -- you can always aggregate up, never down

### Conformed Dimensions

Dimensions shared across multiple fact tables. This is what enables consistent cross-process analysis:

```
dim_date (conformed)
  |                    |
fact_sales           fact_returns
  |                    |
dim_customer (conformed)
```

- `dim_date` used by both `fact_sales` and `fact_returns` ensures "Q1 2026" means the same thing in both contexts
- `dim_customer` shared across processes means customer segments are consistent
- Conformed dimensions require organizational agreement, not just technical design

### Star Schema vs. Snowflake Schema vs. Data Vault

| Aspect | Star Schema | Snowflake Schema | Data Vault |
|---|---|---|---|
| **Dimension structure** | Denormalized (flat) | Normalized (hierarchical) | Hub-Link-Satellite |
| **Query complexity** | Fewest JOINs | More JOINs for dimension hierarchies | Most JOINs, requires business vault for reporting |
| **BI tool optimization** | Best -- every BI tool optimizes for star | Acceptable but slower | Not directly consumable -- needs mart layer |
| **Storage efficiency** | More redundancy in dimensions | Less redundancy | Least redundancy, full auditability |
| **ETL complexity** | Moderate | Moderate | High -- but very resilient to source changes |
| **Best for** | Self-service BI, direct query | Large dimensions where storage matters | Auditable enterprise warehouses, multiple source integration |

**Practical guidance:** Start with star schemas for BI consumption. Use data vault as the raw/integration layer if you need full auditability and source-system resilience, then build star-schema marts on top for BI tools.

## OLAP Cube Concepts

### Measures and Dimensions

An OLAP cube organizes data along dimensions with measures at the intersections:

- **Measures** are the numeric values being analyzed (Revenue, Quantity, Duration)
- **Dimensions** are the axes of analysis (Time, Product, Geography, Customer)
- **Hierarchies** define drill paths within a dimension: `Year > Quarter > Month > Day`
- **Levels** are the positions within a hierarchy: Year is the top level, Day is the leaf

### Measure Types

| Type | Definition | Example | Aggregation Behavior |
|---|---|---|---|
| **Additive** | Can be summed across all dimensions | Revenue, Quantity Sold | SUM across time, product, geography |
| **Semi-additive** | Can be summed across some dimensions, not time | Account Balance, Inventory On-Hand | SUM across geography/product; AVG or last-value across time |
| **Non-additive** | Cannot be summed across any dimension | Unit Price, Ratio, Percentage | Must recompute from underlying additive measures |

Semi-additive measures are the most common source of incorrect dashboard numbers. A bank account balance cannot be summed across months -- the correct aggregation is last-value-per-period or average-balance.

### Calculated Members and Named Sets

In MDX/DAX, calculated members define virtual members of a dimension or measure:

```
-- MDX: Year-over-year growth
WITH MEMBER [Measures].[YoY Growth] AS
  ([Measures].[Revenue] - ([Measures].[Revenue], [Date].[Year].CurrentMember.PrevMember))
  / ([Measures].[Revenue], [Date].[Year].CurrentMember.PrevMember)
FORMAT_STRING = "Percent"
```

```
-- DAX: Year-over-year growth
YoY Growth = 
VAR CurrentRevenue = [Total Revenue]
VAR PriorYearRevenue = CALCULATE([Total Revenue], SAMEPERIODLASTYEAR('Date'[Date]))
RETURN DIVIDE(CurrentRevenue - PriorYearRevenue, PriorYearRevenue)
```

## Aggregation Strategies

### Pre-Aggregation

Compute aggregates at load time and store them in summary tables:

- **Materialized views:** Database-level pre-aggregation (PostgreSQL, Oracle, SQL Server Indexed Views, BigQuery). Automatically refreshed (or manually). Best for repeated expensive queries.
- **Summary tables:** ETL-built aggregate tables at a coarser grain. `fact_sales_daily` aggregates from `fact_sales` (per-transaction). BI tools query the summary table for dashboard-level views.
- **OLAP cube aggregations:** SSAS pre-computes aggregations at multiple levels of each hierarchy. The storage/processing trade-off is configurable per partition.

### When to Pre-Aggregate

Pre-aggregate when:
- The same aggregation query runs repeatedly (dashboard refresh every 15 minutes)
- The base table has billions of rows but the aggregate has thousands
- Query latency requirements are sub-second on large datasets

Do not pre-aggregate when:
- Users need ad-hoc, unpredictable slicing (pre-aggregation covers fixed hierarchies)
- Data changes frequently and refresh latency matters (materialized views add refresh delay)
- Storage costs outweigh compute savings (cloud pricing model dependent)

## Semantic Layers

### What They Are

A semantic layer translates physical database schemas into business-friendly concepts:

| Physical | Semantic Layer | Business User Sees |
|---|---|---|
| `SUM(f.line_total)` with currency conversion join | Revenue measure | "Revenue" |
| `dim_date.fiscal_year` | Fiscal Year dimension | "Fiscal Year" filter |
| `CASE WHEN d.days_since_last_order > 90 THEN 'Inactive'...` | Customer Status calculated dimension | "Customer Status" dropdown |

### Why They Matter

Without a semantic layer:
- Every analyst writes their own "revenue" definition -- different filters, different joins, different numbers
- Business users cannot self-serve -- they depend on analysts for every new question
- Changes to the physical schema break every downstream report individually

With a semantic layer:
- "Revenue" is defined once, governed centrally, and consumed everywhere
- Business users drag and drop business concepts, not table columns
- Physical schema changes are absorbed by the semantic layer; downstream reports are unaffected

### Platform Implementations

| Platform | Semantic Layer | Language | Strengths |
|---|---|---|---|
| Power BI | Dataset (tabular model) | DAX + M | Tight integration, auto-relationships, composite models |
| SSAS | Tabular or Multidimensional model | DAX or MDX | Enterprise-grade, partitioned processing, row-level security |
| Looker | LookML | LookML (YAML-like) | Version-controlled, Git-native, strong for developer teams |
| Tableau | Data Model + calculated fields | Tableau calculations | Visual relationship editor, live + extract modes |
| dbt | Metrics layer (dbt Semantic Layer) | YAML + SQL | Open-source, warehouse-native, tool-agnostic consumption |
| Qlik Sense | Associative data model | Qlik script | In-memory, associative exploration (green/white/gray) |

## Data Visualization Theory

### Chart Type Selection Matrix

| Question Type | Primary Chart | Secondary Options | Anti-Pattern |
|---|---|---|---|
| How has X changed over time? | Line chart | Area chart, sparkline | Pie chart, bar chart without time axis |
| How does X break down into parts? | Stacked bar, treemap | Pie (< 6 slices), 100% stacked bar | Multiple separate charts for parts |
| How does X compare across categories? | Bar chart (horizontal if > 7 categories) | Dot plot, lollipop chart | 3D bar chart, radar chart |
| What is the distribution of X? | Histogram | Box plot, violin plot, density curve | Bar chart of raw values |
| Is there a relationship between X and Y? | Scatter plot | Bubble chart (add Z), heatmap | Connected scatter without time context |
| What is the geographic distribution? | Choropleth, bubble map | Hex bin map, cartogram | Pie charts on a map |
| What is the current state of X? | KPI card + sparkline | Gauge (use sparingly), bullet chart | Full dashboard for a single number |
| How does X rank? | Horizontal bar (sorted) | Bump chart (rank over time) | Pie chart, unsorted bar |

### Tufte's Data-Ink Ratio

Edward Tufte's principle: maximize the ratio of data-ink to total ink. Every visual element should either present data or aid comprehension.

**Remove:** Chartjunk, 3D effects, gradient fills, decorative gridlines, redundant legends (when chart labels suffice), background colors, borders around every element.

**Keep:** Axis labels (minimal), data labels (when precision matters), reference lines (targets, thresholds), annotations (explain anomalies directly on the chart).

### Color Theory for Data

- **Sequential palette** (light to dark) for ordered numeric data: revenue intensity, temperature
- **Diverging palette** (two colors from a neutral midpoint) for data with a meaningful center: profit/loss, above/below target
- **Categorical palette** (distinct hues) for nominal categories: product lines, regions
- **Accessibility:** 8% of men have color vision deficiency. Never encode meaning with red/green alone. Use ColorBrewer palettes. Add pattern fills or direct labels as redundant encoding.

## Self-Service Analytics Maturity Model

| Level | Role | Capability | Tools/Access |
|---|---|---|---|
| 1 - Consumer | Report reader | View pre-built dashboards, apply basic filters | Published dashboards, email subscriptions |
| 2 - Explorer | Power user | Drill down, cross-filter, create personal bookmarks/views | BI tool with governed datasets |
| 3 - Analyst | Business analyst | Build new reports, blend data sources, write calculations | BI tool authoring + semantic layer access |
| 4 - Data analyst | Analyst/Engineer | Write SQL, build data models, create reusable datasets | SQL access + BI tool + semantic layer authoring |
| 5 - Data scientist | Technical | Statistical modeling, ML, Python/R notebooks | Raw data access + notebook environments |

**Governance principle:** Move users to the highest level their skills support, with guardrails at each level. Level 1-2 users work within governed datasets. Level 3+ users get progressively more freedom but more responsibility.

## Embedded Analytics Patterns

### Architecture Options

| Pattern | Integration Effort | User Experience | Vendor Visibility |
|---|---|---|---|
| **iFrame** | Low (embed URL) | Separated (login redirects, style mismatch) | Visible (BI tool branding) |
| **JavaScript SDK** | Medium (API calls, events) | Integrated (in-app filters, events, theming) | Configurable (can hide branding) |
| **White-label** | High (custom CSS, API, auth) | Seamless (looks native to your product) | Hidden (your branding only) |
| **Headless / API** | Highest (build your own UI) | Fully custom (D3, ECharts, custom components) | None (raw data, your rendering) |

### Authentication in Embedded Scenarios

- **SSO pass-through:** User authenticates to the host app; a signed token is passed to the BI tool
- **Service account + RLS:** A single service account connects to the BI backend; Row-Level Security filters data per user based on claims in the embed token
- **Pre-signed URLs:** Generate time-limited, user-specific dashboard URLs server-side

## Dashboard Design Principles

### Information Hierarchy

Design dashboards like a newspaper: headline at the top, detail below.

1. **Top row:** 3-5 KPI cards (big numbers with trend indicators)
2. **Middle section:** Primary visualization answering the main question
3. **Bottom section:** Supporting detail, tables, drill-through targets
4. **Filters:** Top or left sidebar, not scattered across the page

### Progressive Disclosure

- **Level 1 (Overview):** KPIs and summary charts. Answers "How are we doing?"
- **Level 2 (Analysis):** Drill into a specific KPI. Answers "Why did it change?"
- **Level 3 (Detail):** Row-level data, transaction lists. Answers "Show me the specific records."

Each level should be a separate dashboard page or drill-through target, not a scrolling mega-dashboard.

### Common Metrics Patterns

**Additive measures** (SUM): Revenue, units sold, hours worked. Safe to aggregate across all dimensions.

**Semi-additive measures** (last/average across time): Account balance, headcount, inventory level. Require `LASTNONBLANK` (DAX), `LAST_VALUE` (SQL), or snapshot-based fact tables.

**Non-additive measures** (ratios, percentages): Average order value, conversion rate, margin percentage. Must be computed from underlying additive components at the correct grain, then divided. Never average an average.

**Time intelligence:** Period-over-period comparisons (YoY, MoM, QoQ), year-to-date, rolling averages, moving sums. Every BI tool provides built-in time intelligence functions, but they require a properly constructed date dimension with a contiguous, no-gaps date spine.
