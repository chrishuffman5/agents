---
name: overview
description: "Cross-platform data analytics, business intelligence, and reporting guidance: data visualization, OLAP, semantic modeling, dashboard design, technology selection, and reporting theory. Use for technology-agnostic questions (which BI tool, star schema design, chart selection); route to a specific tool's skill for tool-specific syntax or config. WHEN: \"analytics\", \"BI\", \"business intelligence\", \"dashboard\", \"reporting\", \"data visualization\", \"OLAP\", \"which BI tool\", \"star schema\", \"measures\", \"KPI\", \"semantic layer\", \"embedded analytics architecture\". Do NOT use for tool-specific questions (DAX syntax, LookML, Tableau LOD expressions) -- use that tool's own skill in this plugin."
license: MIT
---

# Analytics & BI Overview

This skill covers cross-platform data analytics, business intelligence, and reporting: dimensional modeling, OLAP, semantic layers, data visualization, dashboard design, and technology selection. For tool-specific implementation, read the matching tool's skill in this plugin.

## When to Use This Skill vs. a Technology Skill

**Use this skill when the question is technology-agnostic:**
- "Which BI tool should I use for X?"
- "Power BI vs Tableau for our team?"
- "How should I design a star schema for sales analytics?"
- "What's the right chart type for showing trends over time?"
- "Explain OLAP operations and when to use them"
- "Compare semantic layer approaches across platforms"
- "Self-service BI vs governed analytics -- how do we balance?"
- "Embedded analytics architecture patterns"
- "How do I set up a metrics store?"

**Route to a technology skill when the question is technology-specific:**
- "My DAX measure is returning blank" --> `power-bi` skill
- "Tableau calculated field with LOD expression" --> `tableau` skill
- "SSAS tabular model partition processing" --> `ssas` skill
- "SSRS subscription failing" --> `ssrs` skill
- "LookML view definition" --> `looker` skill
- "Superset SQL Lab query timeout" --> `superset` skill
- "Metabase embedding token config" --> `metabase` skill
- "Grafana dashboard alerting rules" --> `grafana` skill
- "Qlik Sense set analysis expression" --> `qlik-sense` skill
- "ThoughtSpot SpotIQ anomaly detection" --> `thoughtspot` skill
- "DuckDB Parquet analytics" --> `duckdb` skill (cross-ref: `duckdb` skill in the database plugin for core engine questions)

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Technology selection** -- Load `references/paradigm-*.md` for the relevant paradigms
   - **Platform comparison** -- Use the comparison table below, then load references as needed
   - **Data modeling for analytics** -- Load `references/concepts.md` for dimensional modeling, star schemas, semantic layers
   - **Visualization / dashboard design** -- Load `references/concepts.md` for chart selection, Tufte principles, dashboard patterns
   - **Technology-specific** -- Route to the appropriate technology agent

2. **Gather context** -- What is the use case? Who are the consumers (executives, analysts, ops engineers)? What's the data source ecosystem? What's the budget? What does the team already know?

3. **Analyze** -- Apply analytics theory to the specific use case. Never recommend a tool without understanding the audience, data sources, and governance requirements.

4. **Recommend** -- Provide a ranked recommendation with trade-offs, not a single answer.

5. **Qualify** -- State assumptions and conditions under which the recommendation changes.

## Analytics Fundamentals

### Dimensional Modeling

The foundation of analytical data structures (Kimball methodology):

- **Fact tables** contain measurements (revenue, quantity, duration) at a specific grain. Rows are events or transactions. Keep them narrow -- foreign keys to dimensions plus numeric measures.
- **Dimension tables** contain descriptive context (customer name, product category, date attributes). Rows are entities. Keep them wide with denormalized hierarchies.
- **Grain** is the most critical decision -- it defines what one row in a fact table represents. "One row per order line item per day" is a grain. Mixing grains in a single fact table is the number-one dimensional modeling mistake.
- **Conformed dimensions** are shared across fact tables (a single `dim_date`, `dim_customer` used by both `fact_sales` and `fact_returns`). This is what enables consistent cross-process analysis.
- **Star schema** -- fact table surrounded by denormalized dimension tables. Simplest, fastest for queries, preferred by every BI tool's optimizer.
- **Snowflake schema** -- normalized dimension tables (e.g., `dim_product` -> `dim_category` -> `dim_department`). Saves storage, adds JOIN complexity. Use only when dimension tables are enormous.
- **Galaxy schema** (fact constellation) -- multiple fact tables sharing conformed dimensions. Standard in enterprise data warehouses.

### OLAP Operations

Operations that define how users interact with multidimensional data:

- **Slice** -- Filter to a single value on one dimension (show only Q1 2026)
- **Dice** -- Filter on multiple dimensions simultaneously (Q1 2026 + North America + Electronics)
- **Drill-down** -- Move from summary to detail (Year -> Quarter -> Month -> Day)
- **Roll-up** -- Aggregate from detail to summary (City -> State -> Region -> Country)
- **Pivot** -- Rotate dimensions (swap rows and columns to change perspective)

### Semantic Layers and Metrics Stores

A semantic layer sits between raw data and BI consumers, providing a single source of truth for metric definitions:

- **Why it matters:** Without a semantic layer, every team writes their own SQL for "revenue" and gets different numbers. The semantic layer defines "revenue" once and every tool reads the same definition.
- **Implementations:** Power BI datasets (DAX model), SSAS tabular models, Looker's LookML, dbt metrics layer, Tableau data models, AtScale, Cube.
- **Key components:** Metric definitions (measures + dimensions + filters), entity relationships, access controls, caching policies.

### Data Visualization Best Practices

Chart type selection is not aesthetic -- it's functional:

| Data Relationship | Best Chart Types | Avoid |
|---|---|---|
| Change over time | Line chart, area chart | Pie chart, donut chart |
| Part-to-whole (few categories) | Stacked bar, pie chart (< 6 slices) | Line chart |
| Comparison across categories | Bar chart (horizontal for many), grouped bar | Line chart, area chart |
| Distribution | Histogram, box plot, violin plot | Bar chart |
| Correlation | Scatter plot, bubble chart | Line chart, bar chart |
| Ranking | Horizontal bar (sorted) | Pie chart, unsorted bar |
| Geospatial | Choropleth map, bubble map | Bar chart by region |
| Composition over time | Stacked area, 100% stacked bar | Multiple pie charts |
| KPI / single value | Card / big number with sparkline | Full chart |

**Tufte's data-ink ratio:** Maximize the proportion of ink used to present data vs. non-data ink. Remove gridlines, borders, backgrounds, 3D effects, and redundant labels. Every pixel should earn its place.

**Dashboard design principles:**
- Information hierarchy: The most important KPI is top-left (reading order). Detail follows below.
- Progressive disclosure: Summary first, click to drill. Do not dump 30 charts on one screen.
- Responsiveness: Design for the actual consumption device (laptop, wall monitor, mobile).
- Consistent color encoding: If blue means "Sales" on one chart, it means "Sales" on all charts.

### Self-Service vs. Governed Analytics

| Maturity Level | User Type | Tool Needs | Governance |
|---|---|---|---|
| Report consumer | Business user | Pre-built dashboards, scheduled reports | High -- IT controls everything |
| Explorer | Power user | Drag-and-drop, filter/drill, basic calculated fields | Medium -- curated datasets, governed metrics |
| Analyst | Data analyst | Custom queries, blended data sources, advanced calculations | Low -- trusted users with guardrails |
| Data scientist | Technical | SQL/Python/R, raw data access, notebooks | Minimal -- sandbox environments |

The right balance: governed metrics layer (semantic layer) + self-service exploration on top. Users can explore freely but always start from blessed metrics.

### Embedded Analytics Patterns

| Pattern | Description | Best For |
|---|---|---|
| iFrame embed | Embed BI tool's dashboard URL in an application | Quick integration, existing dashboards |
| SDK / JavaScript API | Native integration with filtering, events, theming | Custom UX, interactive applications |
| White-label | Remove BI vendor branding, full visual customization | SaaS products, customer-facing analytics |
| Headless / API | Query the semantic layer via API, render with custom charts | Full control, D3.js/custom visualizations |
| Static export | Scheduled PDF/image generation | Email reports, regulatory filings |

## Technology Comparison

| Technology | Paradigm | Best For | Licensing | Trade-offs |
|---|---|---|---|---|
| **Power BI** | Enterprise BI | Microsoft ecosystem, DAX/M, self-service | Commercial (Pro/Premium/Fabric) | Microsoft lock-in, row limits in free tier, DAX complexity |
| **Tableau** | Enterprise BI | Visual exploration, VizQL, storytelling | Commercial (Creator/Explorer/Viewer) | Expensive at scale, server infrastructure, Prep Builder separate |
| **SSAS** | Enterprise BI / OLAP | Tabular/multidimensional models, DAX, MDX | Tied to SQL Server licensing | SQL Server dependency, legacy multidimensional declining |
| **SSRS** | Reporting | Paginated reports, subscriptions, print-ready | Tied to SQL Server licensing | Legacy feel, limited interactivity, Power BI replacing |
| **Looker** | Reporting / Governed | LookML semantic layer, embedded, Google Cloud | Google Cloud managed | LookML learning curve, Google Cloud dependency, developer-oriented |
| **Apache Superset** | SQL Analytics | Open-source BI, SQL Lab, dashboards | Apache 2.0 | Operational overhead, visualization limitations, no semantic layer |
| **Metabase** | SQL Analytics | Simple BI, question-based, embedding | AGPL / Commercial | Limited for complex analytics, weaker governance |
| **Grafana** | Operational | Time-series dashboards, alerting, observability | AGPL / Commercial | Not for business BI, limited data modeling, query-heavy |
| **Qlik Sense** | Enterprise BI | Associative engine, in-memory, explore-based | Commercial | Expensive, niche skills market, associative model unfamiliar |
| **ThoughtSpot** | Operational / AI | AI-driven search analytics, SpotIQ, natural language | Commercial | Expensive, search paradigm not for all use cases |
| **DuckDB** | SQL Analytics | In-process analytics, file-based, embedded | MIT | Not a BI tool -- query engine; see the `duckdb` skill (this plugin's BI-integration angle) or the database plugin's `duckdb` skill (core engine) |

## Decision Framework

### Step 1: What kind of analytics?

| Analytics Type | Description | Strong Candidates |
|---|---|---|
| Self-service BI | Business users explore data, build own visualizations | Power BI, Tableau, Qlik Sense |
| Paginated reporting | Pixel-perfect, print-ready, regulatory reports | SSRS, Looker, Power BI paginated |
| Operational dashboards | Real-time monitoring, alerting, time-series | Grafana, ThoughtSpot |
| Embedded analytics | Analytics inside a SaaS product or internal app | Metabase, Looker, Power BI Embedded, Superset |
| Ad-hoc SQL | Data team querying warehouses directly | DuckDB, Superset, Metabase |

### Step 2: What's the data source ecosystem?

| Data Source Ecosystem | Natural Fit | Rationale |
|---|---|---|
| SQL Server / Azure | SSAS + SSRS + Power BI | Native integration, DirectQuery, shared licensing |
| Google Cloud / BigQuery | Looker | Built-in BigQuery optimization, LookML on top of BigQuery |
| AWS / Redshift / Athena | Superset, Metabase, QuickSight | Open-source tools connect via JDBC/ODBC; QuickSight is AWS-native |
| Any JDBC/ODBC source | Tableau, Superset | Broadest connector libraries |
| Parquet / CSV / local files | DuckDB | In-process, no server needed, zero-copy reads |

### Step 3: Who are the users?

| User Persona | Best Tools | Why |
|---|---|---|
| Business executives | Power BI, Tableau | Polished dashboards, storytelling, mobile apps |
| Business analysts | Power BI, Tableau, Qlik Sense | Self-service with governed datasets |
| Data engineers / analysts | Superset, Metabase, DuckDB | SQL-native, lightweight, open-source |
| Operations / SRE | Grafana | Time-series native, alerting, integrates with Prometheus/Loki |
| Non-technical explorers | ThoughtSpot | Natural-language search, AI-driven insights |

### Step 4: Budget and licensing?

| Budget Tier | Options |
|---|---|
| Zero / open-source only | Superset, Metabase (AGPL), Grafana (AGPL), DuckDB |
| Per-user commercial | Power BI Pro ($10/user/mo), Tableau Explorer |
| Enterprise capacity | Power BI Premium/Fabric, Tableau Server/Cloud, Qlik, ThoughtSpot |
| Tied to existing licenses | SSAS/SSRS (SQL Server license), Looker (Google Cloud) |

### Step 5: Team expertise?

This matters most. A team fluent in DAX will deliver faster with Power BI than a team learning Tableau from scratch, regardless of which tool benchmarks better. Factor in:
- Existing tool proficiency across the analytics team
- SQL fluency of the target user base
- Developer availability for LookML / custom embedding
- Willingness to invest in training and enablement

## Technology Routing

Route to these technology skills for deep implementation guidance:

| Request Pattern | Route To |
|---|---|
| **Enterprise BI** | |
| Power BI questions (DAX, M/Power Query, dataflows, Fabric, DirectQuery) | `power-bi` skill |
| Tableau questions (VizQL, LOD expressions, Prep Builder, Tableau Server/Cloud) | `tableau` skill (version nuance in its `references/versions/`) |
| Qlik Sense questions (set analysis, associative engine, Qlik Cloud, NPrinting) | `qlik-sense` skill |
| SSAS questions (tabular models, DAX, MDX, multidimensional, processing) | `ssas` skill (version nuance in its `references/versions/`) |
| **Reporting** | |
| SSRS questions (RDL, subscriptions, parameters, report builder) | `ssrs` skill (version nuance in its `references/versions/`) |
| Looker questions (LookML, Explores, derived tables, embedding, Looker Studio) | `looker` skill |
| **SQL Analytics** | |
| Apache Superset questions (SQL Lab, charts, dashboards, Jinja templating) | `superset` skill |
| Metabase questions (questions, collections, embedding, permissions) | `metabase` skill |
| DuckDB analytics questions (Parquet analysis, in-process OLAP, file queries) | `duckdb` skill |
| **Operational** | |
| Grafana questions (dashboards, alerting, data sources, Loki, Tempo) | `grafana` skill |
| ThoughtSpot questions (search analytics, SpotIQ, Liveboards, ThoughtSpot Everywhere) | `thoughtspot` skill |

### Cross-Plugin References

| Scenario | Route To | Rationale |
|---|---|---|
| DuckDB as a database engine (not analytics) | `duckdb` skill, database plugin | Core DuckDB expertise lives in the database plugin |
| SQL Server platform context for SSAS/SSRS | `sql-server` skill, database plugin | Licensing, installation, platform-level config |
| Grafana for infrastructure monitoring | `grafana` skill, monitoring plugin | Monitoring use cases beyond dashboarding |
| Power BI connecting to specific databases | database plugin | Database-specific connection, optimization, DirectQuery tuning |
| Data pipeline feeding analytics | etl plugin | ETL/ELT, data warehouse loading, transformation |

### Version-Specific References

| Technology | Where | Notes |
|---|---|---|
| Tableau | `tableau` skill's `references/versions/2025.x.md`, `2026.1.md` | Major UI and Prep changes between versions |
| SSAS | `ssas` skill's `references/versions/2019.md`, `2022.md`, `2025.md` | Tied to SQL Server release cycle |
| SSRS | `ssrs` skill's `references/versions/2019.md`, `2022.md`, `2025.md` | Tied to SQL Server release cycle |
| Power BI | Managed service -- no version references | Rolling monthly updates |
| Grafana | Single skill, rolling 12.x | Continuous release model |
| Metabase, Superset, Looker, Qlik, ThoughtSpot | Managed / rolling -- no version references | Cloud-managed or continuous release |

## Anti-Patterns

1. **"Grafana for business BI."** Grafana is purpose-built for operational monitoring and time-series data (Prometheus, InfluxDB, Loki). It lacks a semantic layer, dimensional modeling support, and the self-service features business users expect. Use Grafana for ops dashboards; use Power BI, Tableau, or Superset for business analytics.

2. **"Raw database access instead of a semantic layer."** Without a governed metrics layer, every team writes their own SQL for "revenue." Marketing counts revenue at booking. Finance counts at invoice. Support counts at payment. The CEO sees three different numbers. Define metrics once in a semantic layer (Power BI dataset, SSAS model, LookML, dbt metrics).

3. **"One dashboard to rule them all."** A dashboard designed for the CEO, the regional manager, and the warehouse supervisor simultaneously serves none of them well. Different audiences need different levels of detail, different KPIs, and different interaction patterns. Design per-persona dashboards with shared underlying metrics.

4. **"Reporting on transactional tables."** Running BI queries against OLTP tables degrades application performance and produces slow reports. Build a data warehouse or mart with dimensional models. Even a simple nightly ETL into a star schema will outperform direct OLTP queries by 10-100x.

5. **"No data governance."** Self-service analytics without governance produces conflicting numbers, sensitive data exposure, and dashboard sprawl. Implement data certification, row-level security, and a content management strategy (archive stale dashboards, promote certified ones).

6. **"Choosing tools before defining requirements."** "We need Tableau" is not a requirement. "Our 200 regional managers need weekly sales performance dashboards with drill-to-store detail, accessible on tablets, refreshed by 6 AM" is a requirement. Start with the question, the audience, and the data -- then pick the platform.

## Reference Files

Load these for deep foundational knowledge:

- `references/concepts.md` -- Dimensional modeling, OLAP theory, semantic layers, visualization theory, dashboard design. Read for "how does X work" or "what's the right approach for Y" questions.
- `references/paradigm-enterprise-bi.md` -- Enterprise BI platforms (Power BI, Tableau, Qlik, SSAS). Read when evaluating full-featured BI suites for large organizations.
- `references/paradigm-sql-analytics.md` -- SQL-native analytics (DuckDB, Superset, Metabase). Read when evaluating lightweight, SQL-first tools for data teams.
- `references/paradigm-reporting.md` -- Reporting platforms (SSRS, Looker). Read when evaluating paginated reporting, embedded analytics, or governed semantic layers.
- `references/paradigm-operational.md` -- Operational analytics (Grafana, ThoughtSpot). Read when evaluating real-time dashboards, alerting, or AI-driven analytics.
