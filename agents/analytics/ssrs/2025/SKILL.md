---
name: analytics-ssrs-2025
description: "Version-specific expert for SQL Server 2025 reporting, where SSRS is replaced by Power BI Report Server (PBIRS). Covers migration guidance, licensing changes, and the SSRS-to-PBIRS transition. WHEN: \"SSRS 2025\", \"SQL Server 2025 reporting\", \"SSRS replacement\", \"SSRS end of life\", \"SSRS to PBIRS\", \"SSRS migration to Power BI Report Server\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# SQL Server 2025 Reporting — SSRS Replaced by PBIRS

You are a specialist in the reporting transition for SQL Server 2025. **There is no SSRS version for SQL Server 2025.** Microsoft has consolidated all on-premises reporting under Power BI Report Server (PBIRS).

For foundational SSRS knowledge, refer to the parent technology agent. This agent focuses on the strategic shift, licensing changes, and migration guidance.

## The Strategic Shift

- SSRS 2022 is the **last standalone SSRS release**
- Power BI Report Server is the default on-premises reporting solution for SQL Server 2025
- SSRS 2022 continues receiving security patches through January 2033
- No new SSRS features will be developed

## Licensing Changes

| Aspect | Before SQL Server 2025 | SQL Server 2025 |
|--------|----------------------|-----------------|
| **PBIRS access** | Enterprise Edition with Software Assurance only | **Any paid SQL Server edition** |
| **SSRS access** | Included with SQL Server license | No new version; use SSRS 2022 or migrate |
| **Impact** | PBIRS was premium-only | PBIRS now broadly available |

This is a significant licensing democratization. Standard Edition customers can now use Power BI Report Server.

## Migration Paths

### Path 1: SSRS to PBIRS (On-Premises) — Low to Medium Complexity

PBIRS is backward-compatible with SSRS RDL reports. Migration steps:

1. Install Power BI Report Server
2. Back up SSRS encryption key and ReportServer database
3. Restore/attach ReportServer database to PBIRS instance
4. Restore encryption key
5. Verify report rendering and data source connections
6. Update client bookmarks and application integrations

Most reports work without modification. Shared data sources, datasets, subscriptions, and schedules are preserved.

### Path 2: SSRS to Power BI Service (Cloud) — Medium to High Complexity

For organizations moving to cloud-based reporting:

- **RDL Migration Tool** (`microsoft/RdlMigration` on GitHub) automates conversion and publishing of RDL reports to Power BI Service workspaces
- Shared datasets/data sources must be converted to embedded (the tool handles this)
- Power BI gateway required for on-premises data sources
- Custom code assemblies in RDL are **not supported** in Power BI Service (key migration blocker)
- Requires Power BI Premium, Premium Per User, or Fabric capacity

### Path 3: Rebuild as Power BI Interactive Reports — High Complexity

Complete redesign from paginated (RDL) to interactive (PBIX) reports. Different paradigm -- only appropriate for dashboards and ad-hoc analysis. Paginated operational reports should remain as RDL.

## When to Choose Each Path

| Scenario | Recommendation |
|----------|---------------|
| New deployments | Power BI Report Server |
| Existing SSRS, no migration budget | Continue SSRS 2022 (supported until 2033) |
| Need interactive dashboards on-premises | Power BI Report Server |
| Need only paginated/operational reports | Either works; PBIRS preferred for future-proofing |
| SQL Server 2025 license | Power BI Report Server (included) |
| Moving to cloud | Power BI Service with RDL Migration Tool |

## PBIRS Feature Additions Over SSRS

- Host interactive Power BI reports (.pbix) on-premises
- Power BI data models (DAX, DirectQuery)
- Scheduled data refresh for Power BI reports
- More frequent update cadence (roughly every 4 months)
- Row-level security via Power BI RLS (in addition to query-based filtering)

## Support Timeline

| Version | Extended Support Ends |
|---------|----------------------|
| SSRS 2016 | July 2026 |
| SSRS 2017 | October 2027 |
| SSRS 2019 | January 2030 |
| SSRS 2022 | **January 2033** |
| PBIRS | Updated quarterly, aligned with SQL Server |
