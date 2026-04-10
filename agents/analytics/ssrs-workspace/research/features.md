# SSRS Version Features

> Feature comparison across SSRS versions (2019, 2022) and the strategic shift
> to Power BI Report Server in SQL Server 2025.

---

## SSRS 2019 (SQL Server 2019)

SSRS 2019 was a maintenance-focused release with incremental improvements:

### Features

- **Accessibility improvements**: Enhanced screen reader support, tooltips for report elements recognized by assistive technology
- **Browser support updates**: Updated browser compatibility matrix, improved rendering in modern browsers
- **Azure AD support (indirect)**: Azure Active Directory Application Proxy can be configured to provide Azure AD-based access to SSRS 2016+. Note: SSRS does not natively authenticate against Azure AD/Entra ID -- the proxy approach provides SSO without direct integration
- **Security updates**: Continued patching and security hardening
- **SQL Server 2019 engine support**: Full compatibility with SQL Server 2019 database engine as a data source and for the ReportServer catalog database

### Limitations

- No major architectural changes from SSRS 2017
- No native Azure AD/Entra ID authentication integration
- Mobile reports still present but deprecated (removed in 2022)
- SharePoint integrated mode already deprecated

### Support Lifecycle

- Mainstream support ended October 2024
- Extended support ends January 2030

---

## SSRS 2022 (SQL Server 2022)

SSRS 2022 was the most significant recent release with UI modernization and security improvements.

### New Features

- **Redesigned Web Portal**: Rebuilt using Angular framework for improved performance, modern look, and better responsiveness
- **Full-screen view for RDL reports**: Reports can be viewed in full-screen mode in the portal
- **Responsive navigation**: Portal navigation adapted for small viewport / mobile browser sizes
- **TLS 1.3 support**: Enhanced transport security for connections to the Report Server
- **Windows Server 2022 support**: Certified for deployment on Windows Server 2022
- **SQL Server 2022 catalog support**: ReportServer database can be hosted on SQL Server 2022
- **Accessibility enhancements**: Improved Windows Narrator support on newer Windows OS and Windows Server versions, accessibility bug fixes throughout the portal

### Breaking Changes

- **Mobile Reports and Mobile Report Publisher removed**: Deprecated in 2020, fully removed in SSRS 2022. Organizations using mobile reports must migrate to Power BI mobile or alternative solutions
- **Comments on reports disabled by default**: New advanced server property `EnableCommentsOnReports` added with default value of `false`. On upgrade, comments are disabled and must be explicitly re-enabled
- **Pin to Power BI feature removed**: The ability to pin SSRS report items to Power BI dashboards was removed

### Deprecated Features (as of SSRS 2022)

- HTML Viewer and web part toolbar customization via URL parameter `rc:Toolbar=false` (still functional but deprecated)
- Rendering to legacy formats (HTML 4.0 renderer deprecated in favor of HTML5)

### Support Lifecycle

- Extended support ends **January 11, 2033**
- This is the **final release** of standalone SSRS

---

## SQL Server 2025: SSRS Consolidation into Power BI Report Server

### The Strategic Shift

**There is no SSRS version for SQL Server 2025.** Microsoft has consolidated all on-premises reporting services under Power BI Report Server (PBIRS).

Key announcements:
- SSRS 2022 is the **last standalone SSRS release**
- Power BI Report Server becomes the default on-premises reporting solution for SQL Server 2025
- SSRS 2022 continues to receive security updates through January 2033
- No new features will be added to standalone SSRS

### Licensing Changes with SQL Server 2025

| Aspect | Before SQL Server 2025 | SQL Server 2025 |
|--------|----------------------|-----------------|
| **PBIRS access** | Enterprise Edition with Software Assurance only | **Any paid SQL Server edition** |
| **SSRS access** | Included with SQL Server license | No new SSRS version; use SSRS 2022 or migrate |
| **Cost impact** | PBIRS was premium-only | PBIRS now broadly available |

This is a significant licensing democratization -- Standard Edition customers can now use Power BI Report Server.

---

## Power BI Report Server vs SSRS

### Feature Comparison

| Feature | SSRS | Power BI Report Server |
|---------|------|----------------------|
| **Paginated reports (RDL)** | Yes | Yes (full compatibility) |
| **Interactive Power BI reports (.pbix)** | No | Yes |
| **KPIs** | Yes (SSRS 2016+) | Yes |
| **Web portal** | Yes | Yes (enhanced) |
| **Subscriptions** | Yes | Yes |
| **Data-driven subscriptions** | Enterprise only | Yes |
| **REST API** | v2.0 | v2.0 (enhanced) |
| **Custom authentication** | Yes | Yes |
| **Mobile reports** | Removed in 2022 | Not supported |
| **Row-level security** | Via query/parameters | Via query/parameters + Power BI RLS |
| **Report Builder** | Yes | Yes (Power BI Report Builder) |
| **Scheduled refresh** | Snapshots/cache | Snapshots/cache + Power BI refresh |
| **Excel/PDF/Word export** | Yes | Yes |
| **Scale-out** | Enterprise only | Enterprise only |

### Key Differences

- **PBIRS is a superset of SSRS**: It includes all SSRS paginated report capabilities plus Power BI interactive report hosting
- **RDL compatibility**: Most RDL report assets created in SSRS are fully compatible with PBIRS with minimal or no modifications
- **Update cadence**: PBIRS receives updates more frequently (roughly every 4 months) vs. SSRS tied to SQL Server release cycle
- **Licensing model**: PBIRS requires either SQL Server Enterprise with SA, Power BI Premium, or (starting SQL Server 2025) any paid SQL Server license
- **Data model**: PBIRS supports Power BI data models (DAX, DirectQuery) in addition to traditional RDL datasets

### When to Choose Each

| Scenario | Recommendation |
|----------|---------------|
| New deployments | Power BI Report Server |
| Existing SSRS with no migration budget | Continue SSRS 2022 (supported until 2033) |
| Need interactive dashboards on-premises | Power BI Report Server |
| Need only paginated/operational reports | Either works; PBIRS preferred for future-proofing |
| SQL Server 2025 license | Power BI Report Server (included) |

---

## Migration Paths

### Path 1: SSRS to Power BI Report Server (On-Premises)

**Complexity: Low to Medium**

- PBIRS is backward-compatible with SSRS RDL reports
- Migration steps:
  1. Install Power BI Report Server
  2. Back up SSRS encryption key and ReportServer database
  3. Restore/attach ReportServer database to PBIRS instance
  4. Restore encryption key
  5. Verify report rendering and data source connections
  6. Update client bookmarks and application integrations
- Most reports work without modification
- Shared data sources and datasets transfer directly
- Subscriptions and schedules are preserved

### Path 2: SSRS to Power BI Service (Cloud)

**Complexity: Medium to High**

- For organizations moving to cloud-based reporting
- Tools:
  - **RDL Migration Tool** (Microsoft, open-source on GitHub): Automates conversion and publishing of RDL reports to Power BI Service workspaces
  - **Publish .rdl files** directly from PBIRS or SSRS to Power BI Service (Power BI Premium/PPU required)
- Considerations:
  - Shared datasets/data sources must be converted to embedded (the migration tool handles this)
  - Power BI gateway required for on-premises data sources
  - Some RDL features may not render identically in Power BI paginated reports
  - Custom code assemblies in RDL are not supported in Power BI Service
  - Licensing: Requires Power BI Premium, Premium Per User, or Fabric capacity

### Path 3: SSRS to Power BI Interactive Reports (Rebuild)

**Complexity: High**

- Complete redesign of reports as Power BI interactive reports (.pbix)
- Not a migration but a rebuild -- different paradigm (interactive vs. paginated)
- Best for dashboards and ad-hoc analysis scenarios
- Paginated operational reports should remain as RDL (either in PBIRS or Power BI Service)

### Migration Tool Details

**Microsoft RDL Migration Tool** (GitHub: `microsoft/RdlMigration`):
- Converts shared datasets and data sources to embedded
- Publishes passing reports as paginated reports to Power BI workspaces
- Does not modify or remove existing reports on the source server
- Reports that fail validation are logged with details for manual remediation

---

## Version Support Timeline

| Version | Mainstream Support | Extended Support |
|---------|-------------------|-----------------|
| SSRS 2016 | July 2021 | July 2026 |
| SSRS 2017 | October 2022 | October 2027 |
| SSRS 2019 | October 2024 | January 2030 |
| SSRS 2022 | -- | **January 2033** |
| PBIRS | Updated quarterly | Aligned with SQL Server |

---

## Sources

- [Microsoft Learn: What's New in SSRS](https://learn.microsoft.com/en-us/sql/reporting-services/what-s-new-in-sql-server-reporting-services-ssrs)
- [Microsoft Learn: Reporting Services Consolidation FAQ](https://learn.microsoft.com/en-us/sql/reporting-services/reporting-services-consolidation-faq)
- [Microsoft SQL Server Blog: Enhancing Reporting and Analytics with SQL Server 2025](https://www.microsoft.com/en-us/sql-server/blog/2025/06/19/enhancing-reporting-and-analytics-with-sql-server-2025-tools-and-services/)
- [Microsoft Learn: Deprecated Features in SSRS](https://learn.microsoft.com/en-us/sql/reporting-services/deprecated-features-in-sql-server-reporting-services-ssrs)
- [Microsoft Learn: Plan to Migrate .rdl Reports to Power BI](https://learn.microsoft.com/en-us/power-bi/guidance/migrate-ssrs-reports-to-power-bi)
- [Microsoft SQL Server Blog: Get More Out of SSRS 2022](https://www.microsoft.com/en-us/sql-server/blog/2022/09/01/get-more-out-of-sql-server-reporting-services-2022-with-an-improved-user-experience/)
- [GitHub: Microsoft RDL Migration Tool](https://github.com/microsoft/RdlMigration)
- [Gethyn Ellis: SQL Server 2025 SSRS Replaced by Power BI Report Server](https://www.gethynellis.com/2026/02/sql-server-2025-reporting-services-ssrs-replaced-by-power-bi-report-server.html)
- [Red9: SQL Server 2025 Has No SSRS](https://red9.com/blog/sql-server-2025-ssrs/)
- [dbi services: SQL Server 2025 Retirement of SSRS](https://www.dbi-services.com/blog/sql-server-2025-retirement-of-sql-server-reporting-services-ssrs/)
