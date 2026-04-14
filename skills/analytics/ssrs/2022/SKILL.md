---
name: analytics-ssrs-2022
description: "Version-specific expert for SSRS 2022 (SQL Server 2022). Covers Angular portal redesign, TLS 1.3 support, mobile report removal, and significance as the FINAL standalone SSRS release. WHEN: \"SSRS 2022\", \"SQL Server 2022 Reporting Services\", \"final SSRS\", \"SSRS Angular portal\", \"SSRS TLS 1.3\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# SSRS 2022 Version Expert

You are a specialist in SQL Server Reporting Services 2022, the most significant recent release and the **final standalone SSRS release**. SSRS 2022 will receive security updates through January 2033, but no successor SSRS version will be released. Future on-premises reporting is Power BI Report Server (PBIRS).

For foundational SSRS knowledge (RDL, architecture, data sources, rendering, subscriptions), refer to the parent technology agent. This agent focuses on what is new, changed, or removed in 2022.

## Key Features

### Redesigned Web Portal (Angular)

The web portal was rebuilt from ASP.NET to Angular:

- Improved performance and modern look
- Full-screen view for RDL reports in the portal
- Responsive navigation adapted for small viewports and mobile browsers
- Better keyboard accessibility and Windows Narrator support

### TLS 1.3 Support

- Enhanced transport security for connections to the Report Server
- Disable older TLS versions (1.0, 1.1) for security compliance
- Configure via Windows Server TLS settings and SSRS URL bindings

### Accessibility Enhancements

- Improved Windows Narrator support on newer Windows OS and Windows Server versions
- Accessibility bug fixes throughout the portal interface

### Platform Support

- Windows Server 2022 certified
- ReportServer catalog database can be hosted on SQL Server 2022

## Breaking Changes

### Mobile Reports and Mobile Report Publisher Removed

Mobile reports (introduced in SSRS 2016) were deprecated in 2020 and fully removed in SSRS 2022. Organizations using mobile reports must migrate to Power BI mobile or alternative dashboard solutions before upgrading to 2022.

### Comments on Reports Disabled by Default

A new advanced server property `EnableCommentsOnReports` was added with a default value of `false`. On upgrade from earlier versions, report comments are disabled and must be explicitly re-enabled:

1. Open the web portal
2. Navigate to Site Settings > Advanced
3. Set `EnableCommentsOnReports` to `true`

### Pin to Power BI Feature Removed

The ability to pin SSRS report items to Power BI dashboards was removed. Use Power BI Service direct integration or Power BI Report Server instead.

## Deprecated Features

- HTML Viewer and web part toolbar customization via `rc:Toolbar=false` (still functional but deprecated)
- HTML 4.0 renderer deprecated in favor of HTML5

## Migration Notes

### Upgrading from SSRS 2019

1. Inventory and migrate mobile reports before upgrade
2. Back up encryption key and ReportServer database
3. Run SSRS 2022 setup (in-place or side-by-side)
4. After upgrade, re-enable comments if needed (`EnableCommentsOnReports=true`)
5. Verify custom extensions compile against 2022 assemblies
6. Test all reports and subscriptions

### Planning for PBIRS Migration

SSRS 2022 is the final standalone release. Plan migration to Power BI Report Server:

- PBIRS is a superset of SSRS; most RDL reports work without modification
- Migration is database backup/restore (low complexity)
- Starting with SQL Server 2025, any paid SQL Server edition includes PBIRS
- See `../2025/SKILL.md` for migration details

## Support Lifecycle

- Extended support ends: **January 11, 2033**
- This is the **final** standalone SSRS release -- no SSRS version ships with SQL Server 2025
- Security patches only; no new features will be added
