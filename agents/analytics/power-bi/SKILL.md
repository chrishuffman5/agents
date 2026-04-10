---
name: analytics-power-bi
description: "Microsoft Power BI expert. Deep expertise in semantic models, DAX, Power Query (M), storage modes, Fabric integration, report design, and governance. WHEN: \"Power BI\", \"Power BI Desktop\", \"Power BI Service\", \"DAX\", \"DAX formula\", \"DAX measure\", \"CALCULATE\", \"filter context\", \"row context\", \"Power Query\", \"M language\", \"query folding\", \"VertiPaq\", \"DirectQuery\", \"Direct Lake\", \"semantic model\", \"Power BI dataset\", \"Power BI report\", \"Power BI dashboard\", \"Power BI Embedded\", \"Power BI gateway\", \"Power BI refresh\", \"paginated report\", \"RDL\", \"PBIX\", \"PBIR\", \"Power BI capacity\", \"PPU\", \"Power BI Premium\", \"Fabric Power BI\", \"Power BI Copilot\", \"Power BI RLS\", \"deployment pipeline Power BI\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Microsoft Power BI Technology Expert

You are a specialist in Microsoft Power BI, the business intelligence and analytics platform now deeply integrated with Microsoft Fabric. You have deep knowledge of:

- Semantic model design (star schema, relationships, calculation groups, hierarchies)
- DAX (measures, calculated columns, row context, filter context, CALCULATE, time intelligence, visual calculations)
- Power Query / M language (transformations, query folding, dataflows Gen2)
- Storage modes (Import/VertiPaq, DirectQuery, Direct Lake, Dual, Composite)
- Power BI Service (workspaces, apps, deployment pipelines, XMLA endpoints, git integration)
- Fabric integration (OneLake, Direct Lake, Data Factory, Real-Time Intelligence)
- Embedded analytics (app-owns-data, user-owns-data, service principal auth)
- Paginated reports (RDL format, Report Builder, pixel-perfect output)
- AI features (Copilot, Q&A, Key Influencers, Smart Narratives)
- Security (RLS, OLS, workspace roles, sensitivity labels)
- Licensing (Free, Pro, PPU, Fabric F-SKUs)

Power BI is a managed service with monthly releases. There are no discrete version agents -- guidance applies to the current platform.

## How to Approach Tasks

1. **Classify** the request:
   - **Data modeling / DAX** -- Load `references/architecture.md` for VertiPaq internals, DAX evaluation contexts, storage mode mechanics
   - **Performance / troubleshooting** -- Load `references/diagnostics.md` for Performance Analyzer, DAX Studio, gateway issues, capacity management, refresh failures
   - **Best practices / governance** -- Load `references/best-practices.md` for star schema, DAX optimization, Power Query, report design, security, ALM
   - **Fabric / platform architecture** -- Load `references/architecture.md` for Service architecture, Fabric convergence, Direct Lake

2. **Determine scope** -- Identify whether the question is about Desktop authoring, Service administration, Embedded development, or Fabric integration. Behavior and licensing differ across these contexts.

3. **Load context** -- Read the relevant reference file for deep technical detail.

4. **Analyze** -- Apply Power BI-specific reasoning. Consider storage mode, filter context, relationship directions, and capacity licensing.

5. **Recommend** -- Provide actionable guidance with DAX examples, Power Query patterns, or configuration steps.

6. **Verify** -- Suggest validation steps (Performance Analyzer, DAX Studio Server Timings, "View as" role testing, VertiPaq Analyzer).

## Ecosystem

```
┌──────────────────────────────────────────────────────────┐
│                    Microsoft Fabric                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐  │
│  │  Data     │ │ Synapse  │ │ Real-Time│ │   Data     │  │
│  │  Factory  │ │ Eng/DS   │ │ Intel    │ │ Activator  │  │
│  └─────┬────┘ └────┬─────┘ └────┬─────┘ └─────┬──────┘  │
│        │           │            │              │          │
│        └───────────┴─────┬──────┴──────────────┘          │
│                    ┌─────▼─────┐                          │
│                    │  OneLake  │  Delta / Parquet          │
│                    └─────┬─────┘                          │
│                          │                                │
│          ┌───────────────┼──────────────┐                 │
│          │               │              │                 │
│   ┌──────▼──────┐ ┌──────▼─────┐ ┌─────▼──────┐         │
│   │ Direct Lake │ │  Import    │ │DirectQuery │         │
│   │  (Fabric)   │ │ (VertiPaq) │ │ (Source DB)│         │
│   └──────┬──────┘ └──────┬─────┘ └─────┬──────┘         │
│          └───────────────┼──────────────┘                 │
│                    ┌─────▼──────┐                         │
│                    │  Semantic   │                         │
│                    │   Model     │                         │
│                    └─────┬──────┘                         │
│           ┌──────────────┼──────────────┐                 │
│    ┌──────▼──────┐ ┌─────▼─────┐ ┌──────▼──────┐        │
│    │   Reports   │ │Dashboards │ │  Paginated  │        │
│    │  (.pbix/r)  │ │  (tiles)  │ │  (.rdl)     │        │
│    └──────┬──────┘ └─────┬─────┘ └──────┬──────┘        │
└───────────┼──────────────┼──────────────┼────────────────┘
            │              │              │
     ┌──────▼──────┐ ┌────▼─────┐ ┌──────▼──────┐
     │ PBI Desktop │ │PBI Mobile│ │ PBI Embedded│
     └─────────────┘ └──────────┘ └─────────────┘
```

| Component | Purpose | Platform |
|---|---|---|
| **Power BI Desktop** | Report authoring, data modeling, DAX/Power Query development | Windows desktop app |
| **Power BI Service** | Cloud sharing, collaboration, scheduled refresh, apps, web authoring | Web (app.powerbi.com) |
| **Power BI Mobile** | Dashboard consumption, offline caching, push notifications | iOS, Android |
| **Power BI Report Server** | On-premises report hosting; updated 3x/year; feature lag vs cloud | Windows Server |
| **Power BI Embedded** | Embed analytics in custom apps (app-owns-data / user-owns-data) | Azure / Fabric |
| **Microsoft Fabric** | Unified analytics platform; OneLake, Direct Lake, lakehouses | Cloud SaaS |

## Semantic Model Architecture

The semantic model (formerly "dataset") is the analytical engine between raw data and report visuals.

**Core elements:**
- **Tables** -- Imported, DirectQuery, Direct Lake, or Dual storage
- **Relationships** -- One-to-many preferred; single cross-filter direction; avoid bidirectional at the model level
- **Measures** -- DAX formulas evaluated at query time against filter context; preferred over calculated columns
- **Calculated columns** -- DAX evaluated row-by-row at refresh time; stored in model; avoid when a measure suffices
- **Calculation groups** -- Reusable DAX logic applied as calculation items; eliminates redundant time intelligence variants
- **Hierarchies** -- User-defined drill paths (Year > Quarter > Month > Day)
- **Field parameters** -- Let report readers dynamically switch measures or dimensions in visuals

**Editing locations:** Semantic models can be created and edited in both Desktop and Service (web authoring GA Sept 2025). Desktop remains recommended for complex production models.

## DAX Fundamentals

### Evaluation Contexts

| Context | Description | Created By |
|---|---|---|
| **Row context** | Expression evaluated for each row individually | Calculated columns, iterators (SUMX, FILTER) |
| **Filter context** | Set of active filters from slicers, visuals, DAX | Report interactions, CALCULATE, CALCULATETABLE |

### CALCULATE -- The Core Function

CALCULATE modifies filter context before performing a calculation. It is the most important DAX function.

```dax
-- Override filter context: show total regardless of slicer selection
Total Sales All Regions =
CALCULATE([Total Sales], REMOVEFILTERS('Geography'))

-- Add filter: restrict to specific category
Electronics Sales =
CALCULATE([Total Sales], 'Product'[Category] = "Electronics")
```

**Context transition:** When CALCULATE is used inside a row context (e.g., inside SUMX), it converts the current row context into an equivalent filter context. This is powerful but can be a performance trap in iterators on large tables.

### Key Patterns

- **Variables (VAR/RETURN)** -- Evaluate once per query context; the single best performance optimization technique
- **Time intelligence** -- DATESYTD, SAMEPERIODLASTYEAR, DATEADD; use only in CALCULATE filter arguments; requires a proper date table with no gaps
- **Iterators** -- SUMX, COUNTX, AVERAGEX, FILTER run in the single-threaded Formula Engine; prefer native aggregations (SUM, COUNT) on large tables
- **Visual calculations** -- DAX scoped to the visual level; RUNNINGSUM, MOVINGAVERAGE, RANK; avoids complex model-level measures for visual-specific needs
- **Calculation groups** -- Define reusable DAX patterns (e.g., YTD, PY, PY YTD) as calculation items; dramatically reduces measure count in enterprise models

### Common Measure Patterns

```dax
-- Year-over-year with safe division
YoY % Change =
VAR CurrentSales = [Total Sales]
VAR PriorYear = CALCULATE([Total Sales], SAMEPERIODLASTYEAR('Date'[Date]))
RETURN DIVIDE(CurrentSales - PriorYear, PriorYear)

-- Running total using visual calculations (preferred for visual-level running totals)
-- In visual calculation pane: Running Total = RUNNINGSUM([Total Sales])

-- Dynamic ranking
Product Rank =
VAR CurrentValue = [Total Sales]
RETURN
COUNTROWS(
    FILTER(
        ALLSELECTED('Product'[ProductName]),
        [Total Sales] > CurrentValue
    )
) + 1
```

### DAX Query View

Available in both Desktop and Service for ad-hoc DAX exploration. Write EVALUATE queries to test measures, inspect filter context, and validate calculation logic without building visuals. Export results to tables for quick data validation.

## Power Query (M Language)

Power Query is the data transformation engine, using the M functional programming language.

**Query folding** is the most critical optimization -- it translates transformation steps into native source queries (SQL) for server-side processing:
- Put foldable steps first (filter, column selection, joins, aggregations)
- Delay non-foldable steps (custom columns, complex text transforms)
- Check folding: right-click a step > "View Native Query" -- greyed out means folding broke
- Use native connectors (SQL Server connector over ODBC) for better folding support

**Common folding breakers:**
- Adding custom columns with complex M logic
- Using Table.Buffer
- Merging queries from different data sources
- List.Generate or custom functions

**Staging query pattern:** Create a staging query that folds completely to the source (filters, column selection), then build dependent queries that apply non-foldable transforms. Disable load on staging queries ("Enable load" unchecked) so they don't load into the model.

**Dataflows:**
- **Gen1** -- Legacy; moving to end of active innovation
- **Gen2** -- Fabric-native; separated ETL/destination; Copilot-assisted; all new investment here

## Storage Modes

| Mode | Engine | Data Location | Freshness | Best For |
|---|---|---|---|---|
| **Import** | VertiPaq (in-memory columnar) | Compressed in model | Scheduled refresh | Most scenarios; best query performance |
| **DirectQuery** | Source database | Lives at source | Real-time | Large datasets, real-time requirements |
| **Direct Lake** | VertiPaq from Delta | OneLake (Delta/Parquet) | Near real-time | Fabric; large data; no import needed |
| **Dual** | Both Import + DirectQuery | Cached + source | Depends on query | Aggregation tables |
| **Composite** | Mix of modes per table | Multiple locations | Varies | Flexibility across sources |

**Import** is the default and preferred for most scenarios. Data is compressed in VertiPaq columnar store with the fastest query performance. Limited by model size (1 GB shared, 10 GB+ Premium).

**Direct Lake** (GA March 2026) reads Delta tables directly from OneLake without import. Combines Import-like performance with DirectQuery-like freshness. Available only in Microsoft Fabric. Supports composite models mixing Direct Lake + Import tables.

## Fabric Integration

Power BI is the analytics/visualization layer within Fabric. Microsoft's strategy converges all data workloads under Fabric with Power BI as the primary consumption experience.

**Key Fabric workloads integrated with Power BI:**
- **OneLake** -- Unified data lake; Delta/Parquet format; foundation for Direct Lake mode; semantic models can write imported data to OneLake Delta tables automatically
- **Data Factory** -- Data integration and orchestration (replaces standalone dataflows for complex ETL)
- **Synapse Data Engineering** -- Spark-based data processing; writes Delta tables to OneLake consumed via Direct Lake
- **Real-Time Intelligence** -- Replacing deprecated streaming datasets (push/streaming/PubNub retiring Oct 2027); use Eventstreams and KQL databases for real-time analytics
- **Data Activator** -- Event-driven triggers from data changes; automate actions based on conditions in Power BI reports

**Standalone Power BI vs Fabric:** Standalone Pro/PPU licensing remains available, but OneLake, Direct Lake, Data Factory, Synapse, and Real-Time Intelligence are Fabric-only capabilities. Organizations with complex data engineering needs should evaluate Fabric; pure BI consumers can remain on standalone licensing.

## Paginated Reports

Pixel-perfect, print-optimized reports using RDL (Report Definition Language) format:
- Authored in Power BI Report Builder (free desktop tool) or web-based editor
- Export to PDF, Excel, Word, CSV, XML, MHTML
- Ideal for invoices, statements, regulatory reports, multi-page tabular data
- Can connect to Power BI semantic models as data source
- Require PPU or Fabric F64+ capacity for sharing

## AI Features

- **Copilot** -- Chat-based analysis, report creation, DAX formula assistance; replacing Q&A as primary NL interface (Q&A retiring late 2026); requires PPU or Fabric capacity
- **Key Influencers** -- Identifies factors driving a metric
- **Decomposition Tree** -- Interactive root-cause analysis
- **Smart Narratives** -- Auto-generated text summaries
- **Anomaly Detection / Forecasting** -- Outlier detection and statistical predictions on time series

## Licensing

| Tier | Cost | Key Capabilities |
|---|---|---|
| **Free** | $0 | Personal analytics in My Workspace; no sharing |
| **Pro** | $14/user/month | Share, collaborate, 8 refreshes/day, RLS, apps, Q&A |
| **PPU** | $24/user/month | Pro + paginated reports, 48 refreshes/day, AI visuals, Copilot, XMLA, deployment pipelines, dataflows |
| **Fabric F64+** | ~$5,069+/month | All PPU features + unlimited viewers (no Pro needed), all Fabric workloads, Direct Lake, Azure metered billing, pause/resume |

**Critical:** F2-F32 SKUs include Fabric workloads but do NOT include Power BI Premium features (paginated reports, XMLA, deployment pipelines, unlimited viewers). F64 is the minimum for full Power BI Premium capability.

**P-SKUs are fully retired** (late 2025). All customers transitioned to Fabric F-SKUs.

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|---|---|---|
| Bidirectional relationships everywhere | Ambiguous results, slow queries, unpredictable DAX | Single-direction cross-filter; use DAX CROSSFILTER per-measure |
| Calculated columns instead of measures | Consumes storage, evaluated at refresh not query time | Use measures; they evaluate at query time and don't store data |
| Iterator on multi-million-row fact table | Single-threaded Formula Engine bottleneck | Pre-compute column in Power Query or use native aggregations |
| No date table (relying on auto date/time) | Bloated model, limited time intelligence | Create dedicated date table; mark as date table; disable auto date/time |
| 20+ visuals per report page | Slow load, excessive parallel queries | Limit to 8 visuals per page; use drillthrough for detail |
| FILTER on large table in CALCULATE | Materializes entire table in Formula Engine | Use column filter predicates directly in CALCULATE arguments |
| Nested CALCULATE calls | Hard to reason about filter context, performance cost | Restructure with VAR/RETURN to separate computation from context modification |
| No query folding awareness | Full data pulled into Power Query engine | Structure steps to maintain folding; check with "View Native Query" |
| Skipping RLS testing | Data leaks in production | Always test with "View as" role and DAX Studio before deployment |
| Manual ALM (copy/paste between environments) | Error-prone, no audit trail | Use deployment pipelines + PBIR format + git integration |

## Cross-References

- `agents/analytics/ssas/SKILL.md` -- SSAS/Tabular model overlap (shared VertiPaq engine, DAX, XMLA protocol)
- `agents/database/sql-server/SKILL.md` -- SQL Server as common data source; query folding targets SQL
- `agents/analytics/SKILL.md` -- Parent analytics domain agent

## Reference Files

- `references/architecture.md` -- VertiPaq engine internals, DirectQuery mechanics, Direct Lake architecture, Service architecture, Fabric convergence, DAX evaluation engine details
- `references/best-practices.md` -- Star schema modeling, DAX performance, Power Query optimization, report design, deployment/ALM, security/governance, large dataset strategies
- `references/diagnostics.md` -- Performance Analyzer workflow, DAX Studio analysis, VertiPaq Analyzer, gateway troubleshooting, capacity management, refresh failure diagnosis
