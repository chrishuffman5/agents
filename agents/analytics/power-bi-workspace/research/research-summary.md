# Power BI Research Summary

> Research date: April 2026
> Researcher: Claude Opus 4.6 via web search

---

## Key Findings

### 1. Power BI + Fabric Convergence Is Real and Accelerating

Power BI is no longer a standalone BI tool. It is now the visualization and analytics layer within the broader Microsoft Fabric platform. Key convergence milestones:

- **Direct Lake GA (March 2026)**: Import-like performance directly against OneLake Delta tables without data duplication
- **P-SKU Retirement (Late 2025)**: All Premium customers migrated to Fabric F-SKUs
- **Streaming Datasets Deprecation (Oct 2027)**: Push/streaming/PubNub datasets being replaced by Fabric Real-Time Intelligence
- **Q&A Retiring (Late 2026)**: Being replaced by Copilot as the primary natural language interface
- **Dataflows Gen1 to Legacy**: All new investment in Gen2 (Fabric-native)

**Confidence: HIGH** -- Based on official Microsoft announcements and GA releases.

### 2. Web Authoring Has Reached Core Parity

September 2025 was a major milestone: end-to-end Power BI authoring (Power Query, data modeling, DAX, report creation) became available in the browser. Mac users can now build complete models without Desktop. However, Desktop retains advantages for advanced scenarios (Performance Analyzer, composite model creation, advanced M editing).

**Confidence: HIGH** -- Microsoft Learn documentation and feature summaries confirm GA status.

### 3. Licensing Has Simplified but Gotten More Complex

The license tiers are clearer (Free, Pro at $14, PPU at $24, F-SKU capacity), but the F-SKU threshold matters enormously: F2-F32 do NOT include full Power BI Premium features (no paginated reports, no XMLA endpoints, no unlimited viewers). Only F64+ provides the full Premium experience with unlimited content distribution.

**Confidence: HIGH** -- Pricing confirmed across multiple sources including Microsoft Learn.

### 4. AI Integration Is Substantial but Licensing-Gated

Copilot in Power BI is available across Desktop, Service, and Mobile, but requires PPU ($24/user) or Fabric capacity. The traditional Q&A feature is being phased out in favor of Copilot. AI visuals (Key Influencers, Decomposition Tree) are Premium/PPU-only. Admins now have granular control over which AI features Copilot can access.

**Confidence: HIGH** -- Multiple 2026 sources confirm Copilot rollout and Q&A deprecation timeline.

### 5. Development Tooling Ecosystem Is Mature

The external tools ecosystem (DAX Studio, Tabular Editor, ALM Toolkit) is well-established and actively maintained. PBIR format (JSON-based reports for git integration) is becoming the default in April 2026, enabling proper CI/CD workflows. XMLA endpoints provide programmatic access for enterprise ALM.

**Confidence: HIGH** -- Tools are actively maintained with recent 2025-2026 releases.

### 6. Performance Optimization Has Clear Patterns

Well-documented optimization patterns with high community consensus:
- Star schema with single-direction relationships
- Native aggregation functions over iterators
- Variables for intermediate results
- Query folding in Power Query
- 8 visuals max per report page
- Incremental refresh for large datasets

**Confidence: HIGH** -- Consistent across Microsoft guidance, SQLBI, and community best practices.

---

## Confidence Levels by Topic

| Topic | Confidence | Notes |
|---|---|---|
| Architecture & ecosystem | HIGH | Well-documented by Microsoft and third parties |
| Semantic model / DAX fundamentals | HIGH | Stable, mature concepts with extensive documentation |
| Storage modes (Import, DirectQuery) | HIGH | Long-established with clear documentation |
| Direct Lake mode | HIGH | GA as of March 2026 with comprehensive docs |
| Fabric integration | HIGH | Active convergence with frequent official updates |
| Licensing & pricing | HIGH | Confirmed across multiple 2026 sources |
| AI / Copilot features | MEDIUM-HIGH | Rapidly evolving; some features still in preview |
| Streaming/real-time | MEDIUM | Deprecation announced; migration path to Fabric RTI still maturing |
| Report Server on-premises | MEDIUM | Limited recent coverage; strategic deemphasis by Microsoft |
| Datamarts | MEDIUM | Less community coverage; unclear long-term investment |
| PBIR format details | MEDIUM | Transitioning to default April 2026; still evolving |

---

## Research Gaps

### Areas Needing Deeper Investigation

1. **Fabric Real-Time Intelligence**: The replacement for streaming datasets is still maturing. Detailed migration patterns from push/streaming datasets to RTI are not yet widely documented.

2. **Direct Lake Limitations**: While GA, edge cases around Direct Lake (fallback to DirectQuery behavior, partition limits, V-order requirements) need more real-world documentation.

3. **Copilot Accuracy and Limitations**: While widely available, the accuracy of Copilot-generated DAX and natural language answers varies. Enterprise-grade accuracy benchmarks are not publicly available.

4. **Datamart Future**: Microsoft's long-term investment in datamarts vs Fabric lakehouses is unclear. Datamarts may be subsumed by Fabric workloads.

5. **PBIR Format Ecosystem**: As this becomes default in April 2026, tooling ecosystem compatibility (Tabular Editor, ALM Toolkit, CI/CD pipelines) documentation is still emerging.

6. **Multi-Cloud / Non-Microsoft Integration**: Power BI's integration with non-Microsoft data platforms (Databricks, Snowflake, Google BigQuery) via DirectQuery and composite models -- performance characteristics and best practices are less documented than Microsoft-native scenarios.

7. **Power BI Report Server Roadmap**: With SSRS being replaced by PBIRS starting SQL Server 2025, the long-term roadmap for on-premises BI is unclear beyond basic maintenance.

---

## Source Categories

### Primary Sources (Official)

- [Microsoft Learn - Power BI Documentation](https://learn.microsoft.com/en-us/power-bi/)
- [Microsoft Power BI Blog](https://powerbi.microsoft.com/en-us/blog/) -- Monthly feature summaries
- [Microsoft Fabric Documentation](https://learn.microsoft.com/en-us/fabric/)

### Authoritative Community Sources

- [SQLBI (sqlbi.com)](https://www.sqlbi.com/) -- Marco Russo and Alberto Ferrari; definitive DAX and modeling guidance
- [DAX Guide (dax.guide)](https://dax.guide/) -- Comprehensive DAX function reference
- [DAX Patterns (daxpatterns.com)](https://www.daxpatterns.com/) -- Common DAX pattern library
- [Tabular Editor Blog](https://tabulareditor.com/blog/) -- Modeling best practices and tool guidance

### Tools

- [DAX Studio](https://daxstudio.org/) -- Free, open-source DAX query tool
- [Tabular Editor](https://tabulareditor.com/) -- Semantic model development IDE
- [ALM Toolkit](https://www.integritivellc.com/alm-toolkit) -- Schema comparison and deployment
- [VertiPaq Analyzer](https://www.sqlbi.com/tools/vertipaq-analyzer/) -- Model analysis library

### Consulting and Analysis Sources

- [Power BI Consulting Blog](https://powerbiconsulting.com/blog/) -- Enterprise-focused guides
- [Metrica Software](https://metricasoftware.com/) -- Fabric and Power BI comparison articles
- [B EYE](https://b-eye.com/blog/) -- Performance optimization guides
- [EPC Group](https://www.epcgroup.net/) -- Enterprise implementation guides

---

## Files Produced

| File | Content |
|---|---|
| `architecture.md` | Ecosystem components, semantic model, DAX, Power Query, storage modes, service architecture, Fabric integration, paginated reports, real-time, AI features |
| `features.md` | Monthly releases, Desktop vs Service parity, licensing differences, Fabric vs standalone, Embedded, Report Server, recent enhancements |
| `best-practices.md` | Data modeling, DAX performance, Power Query optimization, report design, deployment/ALM, security, governance, large datasets, development tools |
| `diagnostics.md` | Performance Analyzer, DAX Studio, VertiPaq Analyzer, common issues, gateway troubleshooting, capacity management, DAX debugging, data refresh |
| `research-summary.md` | This file -- key findings, confidence levels, gaps, sources |
