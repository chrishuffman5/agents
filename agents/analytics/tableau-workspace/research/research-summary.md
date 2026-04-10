# Tableau Research Summary

## Research Overview
- **Platform**: Tableau (Salesforce) - Data Analytics and Visualization
- **Current Version**: Tableau 2026.1 (March 2026)
- **Research Date**: April 2026
- **Scope**: Architecture, version features, best practices, diagnostics

---

## Key Findings

### Architecture
- Tableau operates on a multi-tier architecture: Gateway > Application Server (VizPortal) > VizQL Server > Data Server > Backgrounder, backed by a PostgreSQL Repository
- VizQL is the proprietary engine translating visual interactions into optimized database queries; the newer VizQL Data Service (2025+) provides programmatic API access
- The two-layer data model (logical/physical) introduced in 2020.2 remains the foundation; relationships (logical layer) are the recommended default over traditional joins (physical layer)
- Tableau Cloud is fully hosted SaaS with Tableau Bridge providing secure connectivity to private network data
- Tableau Pulse (AI-driven metrics) and Tableau Semantics (semantic layer) represent the platform's AI-first direction

### Version Features (2026.1)
- Notable additions: REST API Connector, Google Looker Connector, AI-assisted color palettes, mixed geometry maps, Pulse on Dashboards
- Breaking changes: Marketo, Oracle Eloqua, and WDC connectors deprecated/removed
- Security: SCIM with OIDC, IP Filtering self-service, continued UAT improvements
- AI theme continues: auto-generate semantic models, Q&A calibration, enhanced Q&A

### Best Practices
- Performance: Extract optimization (filter, hide fields, aggregate) and incremental refresh are the primary levers
- Data modeling: Relationships preferred over joins for multi-table models; dimensional modeling (star schema) optimizes Tableau query performance
- LOD expressions: FIXED for cohort analysis and cross-granularity calculations; INCLUDE/EXCLUDE for in-view granularity adjustments
- Governance: Project-based permissions, group-based access, closed model, data source certification, sandbox-to-production promotion workflow

### Diagnostics
- Performance Recording is the primary tool for identifying slow dashboard components
- Workbook Optimizer (2022.1+) provides automated best-practice recommendations
- TSM (Tableau Services Manager) replaces legacy tabadmin for server administration
- Log hierarchy: httpd > vizqlserver > backgrounder > dataserver > vizportal > tabprotosrv
- Common extract refresh failures: credential expiration, missing drivers, network issues, timeouts

---

## Confidence Levels

| Topic | Confidence | Notes |
|-------|------------|-------|
| Server architecture (components, processes) | High | Well-documented in official sources; stable across versions |
| VizQL engine fundamentals | High | Core technology with extensive official documentation |
| Data model (relationships vs joins) | High | Introduced in 2020.2; well-established with official FAQ |
| Tableau 2026.1 features | High | Confirmed via official Tableau release pages and blog posts |
| Tableau 2025.x features | High | Multiple official sources confirm Einstein, Pulse, VizQL Data Service |
| Version lifecycle/support policy | High | Official KB article documents 24-month full + 12-month limited support |
| LOD expressions and calculations | High | Extensive official documentation and community resources |
| Dashboard performance best practices | High | Well-established practices confirmed across multiple sources |
| Governance and permissions | High | Documented in Tableau Blueprint and official help |
| Tableau Prep flow design | High | Official documentation covers all step types |
| Embedding API v3 and Connected Apps | High | Official docs and playbook; UATs confirmed for 2025.3+ |
| Tableau Pulse capabilities | Medium-High | Active development with bi-weekly releases; features may evolve rapidly |
| Salesforce integration details | Medium | Post-acquisition integration ongoing; some features in preview/beta |
| Tableau Semantics | Medium | GA since Feb 2025 but evolving; marketplace launched mid-2025 |
| TSM command reference | High | Official documentation; commands stable across recent versions |
| Embedding troubleshooting | Medium-High | Common patterns well-documented; specific issues vary by deployment |
| Breaking changes between versions | Medium | Documented for 2026.1; historical breaking changes less centralized |

---

## Research Gaps

### Areas Needing Further Investigation
1. **Tableau 2026.1 detailed release notes**: The official release notes page uses an interactive dashboard that cannot be scraped; full feature list may have additional items not captured in blog posts
2. **Tableau+ vs Enterprise license differences**: Specific feature availability per license tier could be more precisely documented
3. **Tableau Semantics deep dive**: As a relatively new feature (GA Feb 2025), best practices and patterns are still emerging
4. **VizQL Data Service patterns**: New API with limited community documentation; use cases and limitations need more exploration
5. **Tableau Agent capabilities**: AI assistant features are evolving rapidly; current capabilities vs roadmap unclear
6. **Data Connect (replacing Bridge)**: Tableau has been previewing Data Connect as an evolution of Bridge; transition timeline and feature parity need monitoring
7. **Exact support end dates**: Version-specific support dates are published on a rolling basis; some dates in the features file are approximate

### Known Limitations
- Tableau's release notes are delivered via interactive Tableau dashboard, making automated extraction difficult
- AI features (Pulse, Agent, Enhanced Q&A) are on rapid release cycles; documentation may lag current state
- Post-Salesforce acquisition, some features are available only on Tableau Cloud (not Server)
- Pricing and exact license entitlements change; not captured in this research

---

## Sources

### Official Tableau Sources
- [Tableau Release Notes](https://help.tableau.com/current/tableau/en-us/whatsnew_all.htm)
- [Tableau March 2026 New Features](https://www.tableau.com/products/new-features)
- [Tableau Desktop 2026.1 Release](https://www.tableau.com/support/releases/desktop/2026.1)
- [What is VizQL?](https://www.tableau.com/drive/what-is-vizql)
- [VizQL Data Service](https://www.tableau.com/blog/vizql-data-service-beyond-visualizations)
- [Data Model FAQ](https://help.tableau.com/current/pro/desktop/en-us/datasource_datamodel_faq.htm)
- [LOD Expressions Overview](https://help.tableau.com/current/pro/desktop/en-us/calculations_calculatedfields_lod_overview.htm)
- [Governance in Tableau](https://help.tableau.com/current/blueprint/en-us/bp_governance_in_tableau.htm)
- [Visual Best Practices](https://help.tableau.com/current/blueprint/en-us/bp_visual_best_practices.htm)
- [Performance Checklist](https://help.tableau.com/current/pro/desktop/en-us/perf_checklist.htm)
- [Optimize for Extracts](https://help.tableau.com/current/server/en-us/perf_optimize_extracts.htm)
- [Performance Recording](https://help.tableau.com/current/server/en-us/perf_record_interpret_server.htm)
- [Tableau Platform Architecture](https://help.tableau.com/current/blueprint/en-us/bp_server_architecture.htm)
- [Server Deployment Reference](https://help.tableau.com/current/guides/enterprise-deployment/en-us/edg_part2.htm)
- [Tableau Server Repository](https://help.tableau.com/current/server/en-us/server_process_repository.htm)
- [Embedding API Authentication](https://help.tableau.com/current/api/embedding_api/en-us/docs/embedding_api_auth.html)
- [Embedding Troubleshooting](https://help.tableau.com/current/api/embedding_api/en-us/docs/embedding_api_troubleshoot.html)
- [Connected Apps](https://help.tableau.com/current/online/en-us/connected_apps.htm)
- [Tableau Pulse](https://www.tableau.com/products/tableau-pulse)
- [Tableau Bridge Guide](https://www.tableau.com/blog/tableau-bridge-data-connectivity-guide)
- [Bridge Deployment Planning](https://help.tableau.com/current/online/en-us/to_bridge_scale.htm)
- [Tableau Prep](https://help.tableau.com/current/prep/en-us/prep_build_flow.htm)
- [Certification for Data Discovery](https://www.tableau.com/blog/certification-and-data-source-recommendations-boost-data-discovery-and-governance)
- [Data Management Overview](https://help.tableau.com/current/server/en-us/dm_overview.htm)
- [TSM Configuration Options](https://help.tableau.com/current/server/en-us/cli_configuration-set_tsm.htm)
- [Working with Log Files](https://help.tableau.com/current/server/en-us/logs_working_with.htm)
- [Version Support Policy](https://kb.tableau.com/articles/howto/tableau-moving-to-24-month-support-policy)
- [Tableau Products Overview](https://help.tableau.com/current/online/en-us/tableau_next_tableau_product_overview.htm)
- [Tableau Migration SDK](https://help.tableau.com/current/api/migration_sdk/en-us/index.html)

### Community and Third-Party Sources
- [Rigord Data Solutions - 2026.1 Features](https://www.rigordatasolutions.com/post/tableau-desktop-2026-1-new-features)
- [DataFlair - Tableau Architecture](https://data-flair.training/blogs/tableau-architecture/)
- [DataCamp - LOD Expressions Tutorial](https://www.datacamp.com/tutorial/lod-expressions-in-tableau-a-tutorial-with-examples)
- [Flerlage Twins - INCLUDE/EXCLUDE LODs](https://www.flerlagetwins.com/2024/08/includeexclude.html)
- [InterWorks - Tableau Deep Dive](https://interworks.com/blog/rcurtis/2017/06/20/tableau-deep-dive-dashboard-design-visual-best-practices/)
- [DarwinApps - Dashboard Performance 2025](https://www.blog.darwinapps.com/blog/8-proven-ways-to-speed-up-your-tableau-dashboard-performance-in-2025)
- [Salesforce - Tableau Einstein Announcement](https://www.salesforce.com/news/stories/tableau-ai-dreamforce-24/)
- [Salesforce Engineering - Einstein Copilot for Tableau](https://engineering.salesforce.com/einstein-copilot-for-tableau-building-the-next-generation-of-ai-driven-analytics/)
- [Nerd Level Tech - Tableau AI 2026](https://nerdleveltech.com/tableau-ai-analytics-in-2026-the-smart-data-revolution)
- [Tableau Embedding Playbook](https://tableau.github.io/embedding-playbook/)
