# SSRS Research Summary

> Key findings, confidence assessments, gaps, and source quality from SSRS domain research.

---

## Key Findings

### 1. SSRS Is Being Retired in Favor of Power BI Report Server

**Confidence: HIGH** (confirmed by Microsoft official blog and documentation)

- SSRS 2022 is the **final standalone SSRS release**
- SQL Server 2025 does **not include a new SSRS version**
- Power BI Report Server (PBIRS) replaces SSRS as the on-premises reporting platform
- SSRS 2022 will receive security updates through **January 2033**
- Starting with SQL Server 2025, **any paid SQL Server edition** grants access to PBIRS (previously Enterprise + SA only)
- PBIRS is a superset of SSRS -- all RDL capabilities are preserved

### 2. Architecture Is Mature and Well-Documented

**Confidence: HIGH**

- Core components (Report Server engine, ReportServer database, ReportServerTempDB, Web Portal) are stable and unchanged since SSRS 2016
- RDL (Report Definition Language) is a well-defined XML schema supporting data sources, datasets, parameters, expressions, and layout
- Dual database architecture: ReportServer (catalog, metadata, security) and ReportServerTempDB (cache, sessions)
- Rendering pipeline: report definition + data -> intermediate format -> rendered output via extensible rendering extensions

### 3. SSRS 2022 Introduced Meaningful Modernization

**Confidence: HIGH**

- Web portal rebuilt with Angular for improved performance
- TLS 1.3 support added
- Mobile reports and Pin to Power BI removed (breaking changes)
- Comments on reports disabled by default on upgrade (behavioral change)
- Full-screen view and responsive navigation added
- Accessibility improvements for Windows Narrator

### 4. Multiple Migration Paths Exist

**Confidence: HIGH**

- **SSRS to PBIRS (on-premises)**: Low complexity, database backup/restore approach, most reports work without modification
- **SSRS to Power BI Service (cloud)**: Medium complexity, Microsoft provides RDL Migration Tool on GitHub, requires Premium/PPU/Fabric capacity
- **SSRS to Power BI interactive reports**: High complexity, requires report redesign (different paradigm)
- Custom code assemblies in RDL are not supported in Power BI Service (key migration blocker)

### 5. Performance Diagnostics Are Built-In and Powerful

**Confidence: HIGH**

- `ExecutionLog3` view provides detailed per-execution metrics: data retrieval time, processing time, rendering time
- Trace logs offer error-level diagnostics
- HTTP logs capture request/response patterns
- Performance counters available via Windows Performance Monitor
- Common bottleneck identification: check which phase (data, processing, rendering) consumes the most time

### 6. Security Model Is Role-Based with Two Levels

**Confidence: HIGH**

- System-level roles (site-wide) and item-level roles (folders/reports)
- No built-in row-level security -- must be implemented via query filtering using `User!UserID`
- SSL/TLS must be configured in two separate locations (Report Server URL and Web Portal URL)
- Kerberos delegation (double-hop) is a persistent challenge for Windows Integrated Security

### 7. CI/CD and Automation Are Well-Supported

**Confidence: HIGH**

- RS.exe utility (VB.NET scripts) for deployment automation
- ReportingServicesTools PowerShell module (40+ commands)
- REST API v2.0 for programmatic management
- Reports are XML files (.rdl) that work well with source control

---

## Confidence Levels

| Topic | Confidence | Notes |
|-------|------------|-------|
| Architecture and components | HIGH | Stable, well-documented, consistent across sources |
| SSRS 2022 features | HIGH | Confirmed by Microsoft official blog and docs |
| SQL Server 2025 / SSRS retirement | HIGH | Confirmed by multiple Microsoft sources and third-party analysis |
| Power BI Report Server comparison | HIGH | Well-documented by Microsoft and community |
| Migration paths and tools | HIGH | Microsoft provides official guidance and tools |
| Security model | HIGH | Documented in Microsoft Learn with practical guides |
| Performance diagnostics | HIGH | ExecutionLog3 and trace logs are thoroughly documented |
| Deployment and CI/CD | HIGH | RS.exe, PowerShell module, and REST API are well-documented |
| SSRS 2019 specific features | MEDIUM | Limited feature differentiation from 2017; mostly maintenance release |
| Custom extensions development | MEDIUM | Documented but less community coverage; API surface is stable but niche |
| Azure AD/Entra ID integration | MEDIUM | Not natively supported in SSRS; workarounds via Azure AD Application Proxy documented but not deeply tested |

---

## Research Gaps

### Known Gaps

1. **SSRS 2025 / SQL Server 2025 GA details**: SQL Server 2025 may not yet be GA as of this research date. Some details about the exact PBIRS licensing terms and feature parity may change at GA
2. **Power BI Report Server versioning**: PBIRS update cadence and specific version-to-version feature deltas were not deeply researched
3. **Custom extension development**: Detailed API reference for building custom rendering, delivery, and authentication extensions was not covered in depth
4. **SSRS on Linux/containers**: Not researched -- SSRS is Windows-only (unlike the SQL Server database engine which supports Linux)
5. **ReportViewer control for modern web frameworks**: The official ReportViewer only supports ASP.NET Web Forms. Solutions for ASP.NET Core, Blazor, and other modern frameworks rely on third-party components or iframe embedding
6. **Exact RDL feature parity between SSRS and PBIRS**: While PBIRS is described as a superset, specific edge cases (custom assemblies, certain expression functions) may differ

### Recommended Follow-Up Research

- Deep dive into PBIRS-specific features not in SSRS (Power BI report hosting, data model refresh)
- Custom extension development guide (IAuthenticationExtension2, IDeliveryExtension, IRenderingExtension)
- Azure integration patterns (Azure SQL as data source, Azure AD Application Proxy, Azure VM hosting)
- Comparison of third-party SSRS alternatives (Telerik Reporting, Crystal Reports, JasperReports)

---

## Source Quality Assessment

### Primary Sources (High Quality)

| Source | Type | Reliability |
|--------|------|-------------|
| [Microsoft Learn SSRS Documentation](https://learn.microsoft.com/en-us/sql/reporting-services/) | Official docs | Authoritative, current |
| [Microsoft SQL Server Blog](https://www.microsoft.com/en-us/sql-server/blog/) | Official blog | Authoritative for announcements |
| [Microsoft Learn: Reporting Services Consolidation FAQ](https://learn.microsoft.com/en-us/sql/reporting-services/reporting-services-consolidation-faq) | Official FAQ | Authoritative for SSRS retirement details |
| [GitHub: Microsoft Reporting Services](https://github.com/microsoft/Reporting-Services) | Official repo | Samples, migration tools, issue tracking |

### Secondary Sources (Good Quality)

| Source | Type | Reliability |
|--------|------|-------------|
| [MSSQLTips](https://www.mssqltips.com/) | Community tutorials | Well-regarded, practical, experienced authors |
| [SQLShack](https://www.sqlshack.com/) | Community articles | Good technical depth, verified examples |
| [Red-Gate Simple Talk](https://www.red-gate.com/simple-talk/) | Community articles | High editorial standards |
| [SQLServerCentral](https://www.sqlservercentral.com/) | Community forum/articles | Large community, varied quality |
| [SQLPerformance](https://sqlperformance.com/) | Expert blog | Performance-focused, expert authors |

### Tertiary Sources (Used for Corroboration)

| Source | Type | Notes |
|--------|------|-------|
| [dbi services blog](https://www.dbi-services.com/blog/) | Consulting firm blog | Good SSRS 2025 analysis |
| [Gethyn Ellis blog](https://www.gethynellis.com/) | Individual expert blog | Detailed SSRS retirement analysis |
| [Red9 blog](https://red9.com/blog/) | Consulting firm blog | Practical SSRS 2025 implications |
| [Schneider IT Management](https://www.schneider.im/) | Tech news | SSRS/PBIRS licensing analysis |

---

## File Manifest

| File | Content | Size |
|------|---------|------|
| `architecture.md` | Core components, RDL, data sources, rendering, subscriptions, deployment topology | Comprehensive |
| `features.md` | Version features (2019, 2022, 2025), PBIRS comparison, migration paths | Comprehensive |
| `best-practices.md` | Report design, parameters, performance, subscriptions, security, CI/CD | Comprehensive |
| `diagnostics.md` | Common issues, performance diagnostics, configuration, logs, migration issues | Comprehensive |
| `research-summary.md` | This file -- findings, confidence, gaps, sources | Summary |
