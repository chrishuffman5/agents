# Power BI Architecture

> Research date: April 2026

## Ecosystem Overview

Power BI is Microsoft's business intelligence and analytics platform, now deeply integrated with Microsoft Fabric as the visualization and experience layer for the entire Fabric ecosystem.

### Core Components

| Component | Purpose | Platform |
|---|---|---|
| **Power BI Desktop** | Report authoring, data modeling, DAX/Power Query development | Windows desktop app |
| **Power BI Service** | Cloud-based sharing, collaboration, scheduled refresh, apps | Web (app.powerbi.com) |
| **Power BI Mobile** | Dashboard consumption on iOS, Android; offline caching, notifications | Mobile apps |
| **Power BI Report Server** | On-premises report hosting; updated 3x/year; feature lag vs cloud | Windows Server |
| **Power BI Embedded** | Embed analytics in custom apps (app-owns-data / user-owns-data) | Azure / Fabric |
| **Microsoft Fabric** | Unified analytics platform; OneLake, lakehouses, Direct Lake mode | Cloud SaaS |

### Delivery Layers

- **Workspaces**: Organizational containers for reports, semantic models, dataflows
- **Apps**: Curated collections of dashboards/reports published to consumers
- **Embedded**: iframes or JavaScript SDK for embedding in custom applications
- **Mobile**: Responsive layouts, KPI surfacing, push notifications

---

## Semantic Model (Dataset)

The semantic model is the analytical engine that sits between raw data and report visuals. Renamed from "dataset" to "semantic model" in late 2023.

### Core Elements

- **Tables**: Imported, DirectQuery, or Direct Lake storage
- **Relationships**: One-to-many (preferred), many-to-many (via bridge tables), one-to-one
- **Measures**: DAX formulas evaluated at query time against filter context
- **Calculated Columns**: DAX formulas evaluated row-by-row at refresh time; stored in model
- **Calculated Tables**: Entire tables generated via DAX at refresh time
- **Calculation Groups**: Reusable DAX logic applied as calculation items to existing measures; dramatically reduces redundant measures (e.g., time intelligence variants)
- **Hierarchies**: User-defined drill paths (Year > Quarter > Month > Day)
- **Perspectives**: Subsets of the model exposed to simplify user experience

### Editing Capabilities (2025-2026)

- Semantic models can now be created and edited directly in the Power BI Service (GA as of 2025)
- Power Query editing, relationship management, DAX measures, and RLS definition all available in the browser
- DAX Query View available in both Desktop and web for ad-hoc DAX exploration

---

## DAX (Data Analysis Expressions)

DAX is the formula language for defining measures, calculated columns, calculated tables, and calculation groups within semantic models.

### Evaluation Contexts

| Context | Description | Created By |
|---|---|---|
| **Row Context** | Expression evaluated for each row individually | Calculated columns, iterator functions (SUMX, FILTER) |
| **Filter Context** | Set of active filters from slicers, visuals, and DAX formulas | Report interactions, CALCULATE, CALCULATETABLE |

### Key Concepts

- **CALCULATE**: The most important DAX function; modifies filter context before performing a calculation. Allows overriding, adding, or removing filters.
- **Context Transition**: When CALCULATE is used inside a row context, it converts the row context into an equivalent filter context.
- **Iterators**: Functions like SUMX, COUNTX, AVERAGEX, FILTER that create a row context and aggregate results. Run in the single-threaded Formula Engine -- avoid on large tables when possible.
- **Time Intelligence**: Functions like DATESYTD, SAMEPERIODLASTYEAR, DATEADD. Use only in CALCULATE filter arguments -- dangerous in iterators due to implicit context transition.
- **Variables (VAR/RETURN)**: Evaluate once per query context, avoiding repeated calculation. One of the most effective performance optimization techniques.
- **Visual Calculations** (2024-2026): DAX calculations scoped to the visual level, operating on aggregated data. Support functions like RUNNINGSUM, MOVINGAVERAGE, RANK.

### Calendar-Based Time Intelligence (Preview, Sept 2025)

New built-in calendar-based time intelligence feature that simplifies common time comparisons without manual date table setup.

---

## Power Query (M Language)

Power Query is the data transformation engine behind Power BI, using the M functional programming language.

### Core Capabilities

- **Visual Editor**: Covers ~90% of use cases; generates M code behind the scenes
- **M Language**: Functional programming language for advanced patterns (dynamic sources, parameterized queries, custom functions)
- **Query Folding**: Translates transformation steps into native source queries (SQL, etc.) for server-side processing. Critical for performance.
- **Custom Connectors**: User-built connectors using Power Query SDK for proprietary data sources
- **Modern Evaluator**: High-performance execution engine for ADLS Gen2, SharePoint, consolidated Parquet files

### Dataflows

| Generation | Description | Status |
|---|---|---|
| **Gen1** | Original Power BI dataflows for self-service data prep | Legacy; moving to end of active innovation |
| **Gen2** | Fabric-native dataflows with separated ETL/destination, Copilot-assisted authoring, improved scale | Active investment; all new innovation here |

### Datamarts

- Self-service BI solution combining data preparation (ETL) with a semantic model
- Include a managed SQL database for T-SQL querying
- Not a replacement for dataflows; complementary for self-service scenarios
- Available with PPU or Premium/Fabric capacity

### Programmatic Power Query (Preview)

- REST API for executing Power Query transformations programmatically in Fabric
- Turns Power Query into a programmable data transformation engine

---

## Storage Modes

| Mode | Engine | Data Location | Freshness | Best For |
|---|---|---|---|---|
| **Import** | VertiPaq (in-memory) | Compressed in model | Refresh schedule | Most scenarios; best performance |
| **DirectQuery** | Source database | Lives at source | Real-time | Large datasets, real-time needs |
| **Dual** | Both Import + DirectQuery | Cached + source | Depends on query | Aggregation tables |
| **Direct Lake** | VertiPaq from Delta | OneLake (Delta/Parquet) | Near real-time | Fabric scenarios; large data |
| **Composite** | Mix of modes per table | Multiple locations | Varies | Flexibility across sources |

### Import Mode

- Default and preferred for most scenarios
- Data compressed in VertiPaq columnar store
- Fastest query performance
- Limited by model size (1 GB shared, 10 GB+ Premium)
- Requires scheduled refresh

### DirectQuery Mode

- Queries translated to source native syntax (SQL) at runtime
- No data copied into model
- Real-time data freshness
- Performance depends on source database optimization
- Higher query latency than Import

### Direct Lake Mode (GA March 2026)

- Reads Delta tables directly from OneLake without import
- Combines Import-like performance with DirectQuery-like freshness
- No data duplication; massive datasets supported
- Available only in Microsoft Fabric
- Desktop authoring support added March 2025
- Supports composite models: mix Direct Lake + Import tables from hundreds of connectors

### Composite Models

- Tables within one semantic model use different storage modes
- Composite models on Analysis Services (AAS) now GA
- Multi-role RLS support in composite models introduced
- Can add import tables from any data source to Direct Lake models

---

## Power BI Service Architecture

### Workspaces

- Organizational containers for reports, semantic models, dataflows, datamarts
- Backed by Premium capacity, PPU, or shared (Pro) capacity
- Roles: Admin, Member, Contributor, Viewer
- Best practice: Use Azure AD/Entra ID groups for role assignment, not individual users

### Apps

- Curated, read-only packages of dashboards and reports
- Published from workspaces to broader audiences
- Support audience targeting for different user groups
- Continuous deployment via deployment pipelines (2025)

### Deployment Pipelines

- Built-in ALM tool with 2-10 configurable stages (default: Dev, Test, Prod)
- Compare content between stages and deploy selectively
- Requires Premium capacity or PPU
- Supports deployment rules for parameterized connections
- Can be combined with XMLA endpoint and git integration for full CI/CD

### Premium / PPU / Fabric Capacities

- **P-SKUs**: Being retired; customers transitioning to Fabric F-SKUs
- **PPU**: $24/user/month; adds paginated reports, 48 daily refreshes, AI features, deployment pipelines
- **F-SKUs**: Fabric capacity units; Azure metered billing; can be paused
- **F64+**: Minimum for unlimited viewer access (no Pro license needed for viewers)
- **F2-F32**: Fabric workloads but NOT full Power BI Premium features

---

## Fabric Integration

### OneLake

- Single unified data lake for all analytics data in Fabric
- Delta/Parquet format for interoperability
- Semantic models can write imported data to OneLake Delta tables automatically
- Foundation for Direct Lake mode

### Key Fabric Workloads Integrated with Power BI

- **Data Factory**: Data integration and orchestration
- **Synapse Data Engineering**: Spark-based data processing
- **Synapse Data Science**: ML model building and deployment
- **Real-Time Intelligence**: Replacing Power BI streaming datasets (streaming/push/PubNub deprecated by Oct 2027)
- **Data Activator**: Event-driven triggers from data changes

---

## Paginated Reports

- Pixel-perfect, print-optimized reports using RDL (Report Definition Language) format
- Authored in Power BI Report Builder (free desktop tool) or web-based editor
- RDL is an XML specification defining data retrieval and layout
- Export to PDF, Excel, Word, CSV, XML, MHTML
- Ideal for invoices, statements, regulatory reports, multi-page tabular data
- Require PPU or Premium/Fabric capacity (F64+) for sharing
- Can connect to Power BI semantic models as data source

---

## Real-Time Dashboards

### Streaming Types (Deprecating)

| Type | Storage | Use Case | Status |
|---|---|---|---|
| **Push** | Historical + live | REST API ingestion | Deprecating Oct 2027 |
| **Streaming** | Live only (no history) | REST API endpoint | Deprecating Oct 2027 |
| **PubNub** | Live only | High-frequency IoT/trading | Deprecating Oct 2027 |

**Migration path**: Microsoft recommends Real-Time Intelligence in Fabric as the replacement for all streaming dataset types.

---

## AI Features

### Copilot in Power BI

- Chat-based analysis and report creation
- Assists with DAX formulas and semantic model exploration
- Available in Power BI Desktop, Service, and Mobile (preview)
- Replacing Q&A as primary natural language interface (Q&A retiring late 2026)
- Requires PPU ($24/user/month) or Fabric capacity

### Built-In AI Visuals

- **Key Influencers**: Identifies factors driving a metric
- **Decomposition Tree**: Interactive root-cause analysis
- **Smart Narratives**: Auto-generated text summaries of data
- **Anomaly Detection**: Identifies outliers in time series
- **Forecasting**: Statistical predictions on time series data

### AI Governance

- Admins can mark AI visuals/settings as "Approved for Copilot" in tenant settings
- Granular control over which AI features Copilot can leverage
- Compliance-aware AI adoption across the organization

### Licensing for AI

- **Pro** ($14/user/month): Q&A, Quick Insights, Smart Narratives, basic forecasting
- **PPU** ($24/user/month): AI visuals, AutoML integration, Cognitive Services, Copilot

---

## Sources

- [Power BI Architecture Explained 2026](https://www.techment.com/blogs/power-bi-architecture-explained/)
- [Microsoft Fabric vs Power BI 2026](https://www.hso.com/blog/microsoft-fabric-vs-power-bi)
- [Direct Lake Overview - Microsoft Learn](https://learn.microsoft.com/en-us/fabric/fundamentals/direct-lake-overview)
- [Deep Dive: Direct Lake on OneLake](https://powerbi.microsoft.com/en-us/blog/deep-dive-into-direct-lake-on-onelake-and-creating-direct-lake-semantic-models-in-power-bi-desktop/)
- [OneLake Integration Overview](https://learn.microsoft.com/en-us/fabric/enterprise/powerbi/onelake-integration-overview)
- [Composite Models with Direct Lake](https://powerbi.microsoft.com/en-us/blog/deep-dive-into-composite-semantic-models-with-direct-lake-and-import-tables/)
- [Storage Modes - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-storage-mode)
- [DAX Basics in Semantic Model](https://tabulareditor.com/blog/dax-basics-in-a-semantic-model)
- [Calculation Groups - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/transform-model/calculation-groups)
- [Edit Semantic Models in Service](https://learn.microsoft.com/en-us/power-bi/transform-model/service-edit-data-models)
- [Row Context and Filter Context - SQLBI](https://www.sqlbi.com/articles/row-context-and-filter-context-in-dax/)
- [Time Intelligence - DAX Guide](https://dax.guide/functions/time-intelligence/)
- [Power Query Complete Guide 2026](https://powerbiconsulting.com/blog/power-query-complete-guide-data-transformation-2026)
- [Dataflows Gen1 to Gen2](https://powerbi.microsoft.com/en-us/blog/dataflows-thank-you-for-eight-years-of-gen1-and-why-gen2-is-the-future/)
- [Self-Service Data Prep - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/transform-model/dataflows/dataflows-introduction-self-service)
- [PPU FAQ - Microsoft Learn](https://learn.microsoft.com/en-us/fabric/enterprise/powerbi/service-premium-per-user-faq)
- [Deployment Pipelines - Microsoft Learn](https://learn.microsoft.com/en-us/fabric/cicd/deployment-pipelines/get-started-with-deployment-pipelines)
- [Paginated Reports - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/paginated-reports/paginated-reports-report-builder-power-bi)
- [RDL Format - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/paginated-reports/report-definition-language)
- [Real-Time Streaming - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/connect-data/service-real-time-streaming)
- [AI in Power BI 2026](https://metricasoftware.com/ai-in-power-bi-features-tools-copilot-and-real-capabilities-in-2026/)
- [Power BI Embedded Analytics Guide 2026](https://www.epcgroup.net/blog/power-bi-embedded-analytics-guide)
