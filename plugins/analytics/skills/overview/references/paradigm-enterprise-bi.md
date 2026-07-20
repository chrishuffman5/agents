# Paradigm: Enterprise BI Platforms

When and why to choose a full-featured enterprise BI suite. Covers Power BI, Tableau, Qlik Sense, and SSAS.

## What Defines Enterprise BI

Enterprise BI platforms provide the complete analytics stack: data connectivity, semantic modeling, visualization, collaboration, security, and governed distribution. They are designed for organizations where hundreds or thousands of users consume analytics, metrics must be consistent across departments, and IT/governance teams control the data pipeline.

Key characteristics:
- **Semantic layer** -- Business-friendly abstraction over physical data (DAX models, VizQL data models, associative models, tabular models)
- **Self-service authoring** -- Business analysts create their own reports without writing SQL
- **Governed distribution** -- Publish dashboards to workspaces/sites with role-based access, row-level security, and certification workflows
- **Scheduling and refresh** -- Automated data refresh on configurable schedules, subscription-based report delivery
- **Mobile and embedded** -- Native mobile apps, embedding APIs for custom applications
- **Enterprise security** -- SSO/SAML/OAuth integration, Active Directory groups, object-level and row-level permissions

## Choose Enterprise BI When

- **The audience is broad** -- Executives, managers, and business users across multiple departments need dashboards. Self-service capability matters more than raw SQL power.
- **Metrics governance is critical** -- "Revenue" must mean the same thing in every report. A semantic layer enforces this centrally.
- **The organization has IT governance** -- Someone manages workspaces, certifies datasets, controls who publishes what. Enterprise BI provides the admin controls for this.
- **Integration with enterprise systems is required** -- SSO, Active Directory, SharePoint, Teams, Slack, email subscriptions, embedded in portals.
- **Scale exceeds what a SQL tool can serve** -- Hundreds of concurrent dashboard viewers. Enterprise BI tools handle caching, query optimization, and concurrent access at scale.

## Avoid Enterprise BI When

- **The team is 5 data engineers who write SQL** -- Enterprise BI adds overhead (modeling, publishing, licensing) that SQL-native tools (Superset, Metabase, DuckDB) avoid.
- **Budget is zero** -- Enterprise BI licensing costs $10-$70/user/month. Open-source alternatives exist for smaller teams.
- **The use case is operational monitoring** -- Grafana is better for time-series dashboards with alerting against Prometheus/InfluxDB/Loki.
- **The data model is simple and the audience is technical** -- A shared SQL query in a notebook or Superset dashboard may be sufficient.

## Technology Comparison Within This Paradigm

| Feature | Power BI | Tableau | Qlik Sense | SSAS (Tabular) |
|---|---|---|---|---|
| **Semantic model** | DAX (VertiPaq engine) | VizQL data model + calculations | Associative engine (QIX) | DAX (VertiPaq / DirectQuery) |
| **Query language** | DAX + M (Power Query) | Tableau calculations + LOD expressions | Set analysis + expressions | DAX + MDX (multidimensional) |
| **Data prep** | Power Query (built-in) | Tableau Prep Builder (separate) | Qlik data load script | SSIS or external ETL |
| **Deployment** | Power BI Service (cloud), Report Server (on-prem) | Tableau Cloud, Tableau Server | Qlik Cloud, Qlik Sense Enterprise | SQL Server instance (on-prem or Azure) |
| **Embedding** | Power BI Embedded (Azure) | Tableau Embedded Analytics | Qlik Sense mashups, Nebula.js | XMLA endpoint, ADOMD.NET |
| **Mobile** | Native iOS/Android app | Native iOS/Android app | Native iOS/Android app | Via Power BI or custom apps |
| **Row-Level Security** | DAX-based RLS in model | User filters + row-level security | Section access (load script) | DAX-based RLS, dynamic security |
| **AI/ML integration** | AutoML, AI visuals, Copilot | Ask Data, Explain Data, Einstein (via Salesforce) | Cognitive engine, AutoML | None native (Power BI layer adds AI) |
| **Licensing cost** | Pro: $10/user/mo; Premium: capacity-based; Fabric: consumption | Creator: $75/user/mo; Explorer: $42/user/mo; Viewer: $15/user/mo | Subscription per user or capacity | Included with SQL Server Enterprise or Standard |
| **Best for** | Microsoft shops, self-service, cost-effective at scale | Data storytelling, visual exploration, mixed environments | Associative exploration, complex data discovery | Enterprise semantic layer, large-scale OLAP |

## Common Patterns

### Development Workflow

Enterprise BI teams follow a development lifecycle similar to software engineering:

1. **Development** -- Author in desktop tool (Power BI Desktop, Tableau Desktop, Qlik Sense Hub)
2. **Version control** -- Power BI: TMDL/PBIP format + Git; Tableau: `.twbx` files or Tableau Content Migration Tool; Qlik: multi-cloud management; SSAS: Visual Studio + SSDT + Git
3. **Testing/UAT** -- Deploy to a staging workspace/site. Validate data accuracy, visual correctness, RLS rules.
4. **Production deployment** -- Promote to production workspace. Power BI: deployment pipelines; Tableau: publish to server/cloud; SSAS: deploy project via SSDT or Tabular Editor.
5. **Monitoring** -- Track refresh failures, usage metrics, query performance. Power BI: monitoring hub + Azure Log Analytics; Tableau: Admin views + tabcmd; SSAS: SQL Server Profiler + Extended Events.

### Governance Model

| Governance Element | Implementation |
|---|---|
| **Certified datasets** | Mark approved datasets. Users see a badge. Power BI: endorsement; Tableau: certified data sources. |
| **Row-level security** | Filter data per user/group. Defined in the semantic model, enforced at query time. |
| **Workspace/site structure** | Organize by department or domain. Separate dev/test/prod. |
| **Naming conventions** | Prefix datasets, reports, and workspaces with department codes. Enforce via governance documentation. |
| **Stale content cleanup** | Monitor dashboard usage. Archive reports unused for 90+ days. Power BI: usage metrics; Tableau: admin views. |
| **Sensitive data** | Classify columns (Power BI sensitivity labels), mask PII in semantic models, restrict export to PDF/PPT. |

### When to Pick Which Enterprise BI Tool

**Choose Power BI when:**
- The organization runs on Microsoft 365, Azure, SQL Server
- Cost per user matters (Power BI Pro at $10/user/mo is the cheapest enterprise BI)
- DAX modeling capability exists or can be built on the team
- Microsoft Fabric's unified data platform (lakehouse + warehouse + BI) is the strategic direction

**Choose Tableau when:**
- Visual data exploration and storytelling are the primary use case
- The data ecosystem is heterogeneous (many different source systems, databases, cloud platforms)
- The organization values Tableau's visual grammar (VizQL) and its drag-and-drop authoring experience
- Data literacy programs and a Tableau user community already exist

**Choose Qlik Sense when:**
- The use case requires unconstrained data exploration (Qlik's associative model shows what's related and what's not)
- Complex data integration is needed at the BI layer (Qlik's load script handles multi-source blending natively)
- The organization already has Qlik expertise from QlikView era

**Choose SSAS when:**
- A centralized, high-performance semantic layer is needed for multiple consumption tools (Power BI, Excel, Reporting Services, third-party tools via XMLA)
- The dataset is too large for Power BI Desktop's in-memory limits (SSAS scales to hundreds of GB with partitioned processing)
- Complex security models with dynamic RLS and object-level security are required
- The organization is standardized on SQL Server and wants to leverage existing licensing
