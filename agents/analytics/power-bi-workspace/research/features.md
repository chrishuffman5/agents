# Power BI Features

> Research date: April 2026

## Monthly Release Cadence

Power BI Desktop and Service receive monthly feature updates. Power BI Report Server is updated 3 times per year with a feature lag compared to cloud.

---

## Recent Major Feature Additions (2025-2026)

### March 2026

- **Direct Lake on OneLake**: General availability -- read Delta tables directly from OneLake with Import-like performance
- **Translytical Task Flows**: GA -- end users can take action directly from reports
- **Modern Visual Defaults (Preview)**: Fluent 2 design language applied to default visuals
- **Custom Totals**: More control over total row calculations in tables/matrices
- **Series Label Leader Lines**: Enhanced chart labeling
- **Updated Copilot Experiences**: Smarter AI interactions across Desktop and Service
- **Expanded DAX Capabilities**: New functions and improvements

### February 2026

- Enhanced Copilot and AI experiences
- More flexible report interaction patterns
- Visual polish improvements
- Modeling enhancements

### January 2026

- UX and AI Copilot improvements
- PBIR format enhancements (Power BI Report format for git integration)

### November 2025

- R and Python visuals deprecated in Embed-for-customers scenarios
- Copilot in Power BI mobile apps (Preview)
- Verified Answers improvements for Copilot
- Reporting, modeling, and data connectivity updates

### September 2025

- **Calendar-Based Time Intelligence (Preview)**: Built-in time intelligence without manual date tables
- End-to-end web authoring in Power BI Service (core modeling parity with Desktop)
- Power Query editing in the browser

### Key 2025 Milestones

- **Visual Calculations**: Enhanced robustness; added to Explore feature; parameter pickers for templates
- **Field Parameters**: GA with matrix hierarchy retention when switching selections
- **Composite Models on AAS**: GA with multi-role RLS support
- **Semantic Model Editing in Service**: GA -- create and edit models in the browser
- **Direct Lake Desktop Authoring**: Public preview (March 2025)
- **Dataflows Gen2**: All new innovation; Gen1 moving to legacy
- **Deployment Pipelines for Org Apps**: Continuous deployment capability

---

## Power BI Desktop vs Service Feature Parity

### Desktop-Only Features (as of April 2026)

| Feature | Notes |
|---|---|
| Power Query Advanced Editor (M code) | Full M code editing with IntelliSense |
| Data Model Relationship Diagram View | Visual relationship editor |
| Performance Analyzer | Query optimization tool |
| What-If Parameters | Scenario analysis |
| Advanced DAX Authoring with IntelliSense | Richer editing experience |
| Composite Model Creation | Initial creation still Desktop-preferred |
| Custom Visual Development | Testing and debugging |

### Service Web Authoring (GA Sept 2025)

| Feature | Status |
|---|---|
| Power Query data transformation | Available |
| Relationship management | Available |
| DAX measure creation/editing | Available |
| RLS role definition | Available |
| DAX Query View | Available |
| Report visual creation | Available |
| Semantic model version history | Available |
| Calculation group authoring | Available |
| Auto-save | Built-in |

### Key Parity Milestone

September 2025 unlocked end-to-end Power BI authoring in the browser, achieving core data modeling parity. Mac users can now build models without Desktop. However, Desktop remains the recommended tool for production-quality reports with complex data models.

---

## Licensing Feature Differences

### Power BI Free

- Personal analytics in My Workspace
- Connect to data sources, create reports
- No sharing or collaboration
- Can view content in F64+ backed workspaces (Viewer role)

### Power BI Pro ($14/user/month)

- Publish to shared workspaces
- Share and collaborate with other Pro users
- 8 scheduled refreshes per day
- Q&A natural language queries
- Quick Insights, Smart Narratives
- Basic forecasting
- Row-Level Security
- Email subscriptions
- Power BI apps (publish and consume)

### Power BI Premium Per User / PPU ($24/user/month)

Everything in Pro, plus:

- Paginated reports (author and consume)
- 48 scheduled refreshes per day
- AI visuals (Key Influencers, Decomposition Tree)
- AutoML integration
- Cognitive Services integration
- Copilot in Power BI
- Deployment pipelines
- XMLA read/write endpoints
- Incremental refresh with real-time
- Dataflows and datamarts
- Larger model sizes (up to 400 GB)
- 100 TB tenant storage limit

### Fabric F-SKU Capacity

Everything in PPU (at F64+), plus:

- **Unlimited viewers** (F64+ -- no Pro license needed for consumers)
- All Fabric workloads (Data Factory, Synapse, Data Science, Real-Time Intelligence)
- OneLake unified data lake
- Direct Lake storage mode
- Azure metered billing (per-second, pausable)
- Autoscale capability
- Multi-geo support

### F-SKU Tiers

| SKU | Approx Monthly Cost | Power BI Premium Features |
|---|---|---|
| F2 | $263 | Fabric workloads only; NO Premium BI features |
| F4 | $526 | Fabric workloads only; NO Premium BI features |
| F8 | $1,051 | Fabric workloads only; NO Premium BI features |
| F16 | $2,102 | Fabric workloads only; NO Premium BI features |
| F32 | $4,205 | Fabric workloads only; NO Premium BI features |
| F64 | $5,069 | Full Premium BI + unlimited viewers |
| F128+ | Higher | Full Premium BI + larger capacity |

**Important**: F2 through F32 do NOT include paginated reports, XMLA endpoints, deployment pipelines, or unlimited content distribution.

### P-SKU Retirement

Legacy P-SKUs (P1, P2, P3, P4, P5) are fully retired as of late 2025. All customers transitioned to Fabric F-SKUs.

---

## Fabric vs Standalone Power BI

### What Fabric Adds

| Capability | Standalone Power BI | With Fabric |
|---|---|---|
| **OneLake** | Not available | Unified data lake for all analytics |
| **Direct Lake** | Not available | In-memory performance without import |
| **Data Factory** | Limited (dataflows only) | Full ETL/ELT orchestration |
| **Synapse Data Engineering** | Not available | Spark notebooks, lakehouses |
| **Synapse Data Science** | Not available | ML model training and deployment |
| **Real-Time Intelligence** | Streaming datasets (deprecating) | Full real-time analytics engine |
| **Data Activator** | Not available | Event-driven triggers from data |
| **Unified Security** | Workspace + RLS | OneLake-level access control |
| **Capacity Billing** | P-SKU (retired) or PPU | F-SKU with Azure metering, pause/resume |

### Strategic Direction

Power BI is the analytics/visualization layer within Fabric. Microsoft's strategy is converging all data workloads under Fabric, with Power BI as the primary consumption experience. Standalone Power BI Pro/PPU licensing remains available but the platform investment is increasingly Fabric-centric.

---

## Power BI Embedded

### Embedding Scenarios

| Scenario | Also Called | Authentication | Licensing | Best For |
|---|---|---|---|---|
| **Embed for Customers** | App-Owns-Data | Service principal (recommended) | F-SKU or A-SKU capacity | ISVs, customer-facing apps |
| **Embed for Your Org** | User-Owns-Data | User's Azure AD token | Pro license per user | Internal portals, intranets |

### App-Owns-Data Details

- Application authenticates on behalf of users via service principal
- Users do not need Power BI licenses
- Pay by capacity (F-SKU), not per user
- Best practice: Always use service principal (certificate-based auth, no MFA, no password expiry) over master user accounts
- Supports DirectQuery, Import, and Direct Lake models

### A-SKU vs F-SKU for Embedding

- **A-SKUs**: Azure-billed; Microsoft reversed planned retirement; still available but not strategic
- **F-SKUs**: Fabric-billed; unified capacity model; strategic direction
- **F64**: Minimum for Power BI content viewing rights for unlimited users

---

## Power BI Report Server (On-Premises)

### Overview

- On-premises reporting solution for organizations that cannot use cloud
- Updated 3 times per year (vs monthly for cloud)
- Starting with SQL Server 2025, PBIRS replaces SSRS as the default on-premises reporting solution
- Free download; requires SQL Server Enterprise license with Software Assurance

### Feature Lag vs Cloud

| Available in Report Server | NOT Available in Report Server |
|---|---|
| Power BI reports (.pbix) | Copilot / AI features |
| Paginated reports (.rdl) | Real-time streaming dashboards |
| KPIs | Dataflows and datamarts |
| Mobile report viewing | Deployment pipelines |
| On-premises data connectivity | Apps |
| Row-Level Security | Direct Lake mode |
| Scheduled refresh | Q&A natural language |
| | Fabric integration |
| | Sensitivity labels |
| | Monthly feature updates |

### When to Use Report Server

- Regulatory or compliance requirements mandate on-premises data
- No cloud connectivity available
- Organization needs pixel-perfect paginated reports on-premises
- Expect ongoing feature gaps compared to cloud, especially for AI and advanced analytics

---

## Recent Enhancements Deep Dive

### Visual Calculations (2024-2026)

- DAX calculations scoped to the visual, operating on aggregated data
- Functions: RUNNINGSUM, MOVINGAVERAGE, RANK, FIRST, LAST, PREVIOUS, NEXT
- Enhanced robustness when visual type changes
- Parameter pickers for template functions
- Added to the Explore feature for ad-hoc analysis
- Avoids need for complex model-level measures for visual-specific calculations

### Composite Models (2025-2026)

- Mix Import + DirectQuery + Direct Lake tables in one model
- Composite models on Analysis Services: GA
- Multi-role RLS in composite models
- Can add local model tables (field parameters) when using DirectQuery for Power BI semantic models
- Direct Lake + Import composite models in public preview

### Calculation Groups (2024-2025)

- Reduce redundant measures by defining reusable DAX patterns
- Standard in enterprise models by 2025
- Authoring available in Desktop Model Explorer and Power BI Service
- Common use: time intelligence variants (YTD, QTD, MTD, PY, etc.)

### Field Parameters (GA 2025)

- Let report readers dynamically change measures or dimensions in visuals
- Matrix retains hierarchy expansion state when switching selections
- Accessible from model view in both Desktop and Service
- Reduces need for multiple similar visuals or bookmark-based solutions

### PBIR Format

- Power BI Report format designed for git integration
- JSON-based report definition (vs binary .pbix)
- Enables meaningful diffs and source control
- Moving out of preview April 2026 as default experience

---

## Sources

- [Power BI March 2026 Feature Summary](https://powerbi.microsoft.com/en-us/blog/power-bi-march-2026-feature-summary/)
- [Power BI January 2026 Feature Summary](https://powerbi.microsoft.com/en-us/blog/power-bi-january-2026-feature-summary/)
- [Power BI November 2025 Feature Summary](https://powerbi.microsoft.com/en-us/blog/power-bi-november-2025-feature-summary/)
- [Power BI June 2025 Feature Summary](https://powerbi.microsoft.com/en-us/blog/power-bi-june-2025-feature-summary/)
- [Power BI May 2025 Feature Summary](https://powerbi.microsoft.com/en-us/blog/power-bi-may-2025-feature-summary/)
- [Visual Calculations Overview - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-visual-calculations-overview)
- [Field Parameters - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/create-reports/power-bi-field-parameters)
- [Power BI Licenses Guide 2026](https://sranalytics.io/blog/power-bi-licenses/)
- [Power BI Pricing 2026](https://powerbiconsulting.com/blog/power-bi-pricing-licensing-guide-2026)
- [Power BI Service Features by License - Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/fundamentals/service-features-license-type)
- [Power BI Embedded Analytics Guide 2026](https://www.epcgroup.net/blog/power-bi-embedded-analytics-guide)
- [Power BI Embedded Enterprise Guide 2026](https://www.epcgroup.net/power-bi-embedded-analytics-enterprise-guide)
- [Power BI Report Server Features](https://scaleupally.io/blog/power-bi-report-server/)
- [Power BI Report Server Sept 2025](https://powerbi.microsoft.com/en-us/blog/power-bi-report-server-september-2025-feature-summary/)
- [Power BI Desktop vs Service 2026](https://powerbiconsulting.com/blog/power-bi-desktop-vs-service-differences-2026)
- [AI in Power BI 2026](https://metricasoftware.com/ai-in-power-bi-features-tools-copilot-and-real-capabilities-in-2026/)
- [Power BI Updates 2025-2026](https://medium.com/@singhria.0829/power-bi-updates-2025-2026-practical-overview-with-examples-67bf6c4ae0d1)
- [Microsoft Fabric vs Power BI 2026](https://www.hso.com/blog/microsoft-fabric-vs-power-bi)
