# SSRS Architecture Reference

Deep reference for SSRS server components, Report Definition Language (RDL), data sources, rendering pipeline, subscriptions, deployment topology, and configuration.

## Report Server Engine

The Report Server is the central processing engine. It handles:

- **Report processing** -- Retrieves RDL definitions, executes queries against data sources, combines data with layout, produces an intermediate format
- **Rendering** -- Transforms the intermediate format into requested output (HTML, PDF, Excel, etc.) via rendering extensions
- **Scheduling and delivery** -- Manages subscriptions, snapshots, and caching
- **Security** -- Enforces role-based access control and authentication

Execution flow: retrieve report definition -> combine with data -> generate intermediate format -> render to output format.

## Web Portal

- **Web Portal** (SSRS 2016+) -- Modern browser-based interface for viewing, managing, and organizing reports, data sources, datasets, and subscriptions
- **Report Manager** (legacy name, pre-2016) -- Older ASP.NET-based management interface
- SSRS 2022 rebuilt the portal using Angular for improved performance and modern UI

## Catalog Databases

### ReportServer Database

The primary catalog database (default name: `ReportServer`) stores:

- Report definitions (RDL XML)
- Report metadata and folder hierarchy
- Report history and snapshots
- Security settings and role assignments
- Scheduling and subscription data
- Shared data sources and shared datasets
- Cache policies
- Encrypted credentials and connection strings
- Extension configuration

### ReportServerTempDB Database

The temporary database (default name: `ReportServerTempDB`) stores:

- Cached reports and intermediate processing products
- Session data and execution data
- Temporary snapshots during rendering

Data in ReportServerTempDB survives SQL Server and Report Server restarts. The Report Server periodically cleans expired and orphaned data.

## Report Definition Language (RDL)

RDL is an XML representation of a report definition, validated against an XML Schema Definition (XSD).

### Core RDL Elements

```
Report
  +-- DataSources          (connection definitions)
  +-- DataSets             (query definitions + field mappings)
  +-- ReportParameters     (user input parameters)
  +-- Body
  |     +-- ReportItems    (tables, matrices, charts, gauges, maps, images, subreports)
  +-- PageHeader
  +-- PageFooter
```

### Data Regions

- **Tablix** -- Unified data region combining table, matrix, and list layouts. The core building block for most SSRS reports
- **Chart** -- Bar, column, line, area, pie, scatter, bubble, stock, range, polar, shape maps
- **Gauge** -- Radial and linear gauges for KPI-style displays
- **Map** -- Spatial data visualization using shape files or SQL Server spatial data
- **Image** -- Static or dynamic images (embedded, external URL, database-stored)
- **Subreport** -- Embedded report within a parent report (caution: separate query per instance)

### Expressions

Written in Visual Basic .NET syntax, used throughout RDL:

- **Calculated fields** -- `=Fields!Quantity.Value * Fields!UnitPrice.Value`
- **Conditional formatting** -- `=IIF(Fields!Revenue.Value > 1000000, "Green", "Red")`
- **Visibility toggle** -- `=IIF(Parameters!ShowDetail.Value = True, False, True)`
- **Built-in collections** -- `Fields`, `Parameters`, `Globals`, `User`, `ReportItems`
- **Aggregate functions** -- `Sum`, `Count`, `Avg`, `Min`, `Max`, `CountDistinct`, `RunningValue`, `First`, `Last`, `Previous`
- **Scope-aware aggregation** -- `=Sum(Fields!Sales.Value, "RegionGroup")` aggregates within a named group

### Report Parameters

| Property | Description |
|----------|-------------|
| **Data type** | String, Integer, Float, Boolean, DateTime |
| **Default values** | Static, query-based, or expression-based |
| **Available values** | Static list, dataset query, or none (free-form) |
| **Multi-select** | Allows selecting multiple values; generates comma-separated list |
| **Cascading** | Child parameter query references parent parameter value |
| **Hidden/Internal** | Parameters can be hidden from the user or marked internal |

### File Extensions

| Extension | Purpose |
|-----------|---------|
| `.rdl` | Report Definition Language -- server reports deployed to SSRS |
| `.rdlc` | Client Report Definition -- used with ReportViewer control, processed locally without Report Server |
| `.rds` | Shared Data Source definition file |
| `.rsd` | Shared Dataset definition file |

## Data Sources

### Supported Data Providers

SQL Server, Oracle, OLE DB, ODBC, Analysis Services, Azure SQL Database, SharePoint lists, XML, SAP BW, Hyperion Essbase, Teradata, and custom data extensions.

### Embedded vs Shared Data Sources

| Aspect | Embedded | Shared |
|--------|----------|--------|
| **Scope** | Available only within the containing report | Available to any report on the server |
| **Management** | Must update each report individually | Update once, all referencing reports pick up changes |
| **Credentials** | Stored per-report | Stored centrally |
| **Expression support** | Supports expression-based connection strings | Static connection strings only |

### Credential Management

1. **Prompt for credentials** -- User enters credentials at execution time
2. **Stored credentials** -- Saved encrypted in the ReportServer database; can optionally impersonate a Windows user
3. **Windows Integrated Security** -- Uses executing user's Windows identity (subject to Kerberos double-hop)
4. **No credentials** -- For sources that do not require authentication

Encryption keys protect stored credentials. Always back up encryption keys before service account changes or migration.

### Kerberos Double-Hop Problem

When SSRS uses Windows Integrated Security to connect to a remote SQL Server, the user's credentials must traverse two network hops (browser -> SSRS -> SQL Server). Kerberos constrained delegation must be configured for this to work. Alternatives:

- Use stored credentials with a dedicated service account (recommended)
- Configure Kerberos constrained delegation on the SSRS service account
- Use Azure AD Application Proxy (SSRS 2019+) to avoid the delegation chain

## Rendering Pipeline

### Rendering Extensions

| Format | Extension | Notes |
|--------|-----------|-------|
| HTML 5 | HTML | Default for web portal; HTML 4.0 renderer deprecated in 2022 |
| PDF | PDF | Print-ready, archival |
| Excel | XLSX | Data analysis; preserves tablix structure as worksheets |
| Word | DOCX | Editable documents |
| PowerPoint | PPTX | Added in SSRS 2016 |
| CSV | CSV | Flat data export, no formatting |
| XML | XML | Structured data interchange |
| TIFF | TIFF | Image archival, faxing |
| MHTML | Web Archive | Single-file web archive for email embedding |
| Data Feed | Atom | Data feed consumers |

Rendering extensions are configurable in `RSReportServer.config`. Custom rendering extensions can be developed using the SSRS extensibility framework.

### Format-Specific Behavior

- **PDF/Print** -- Enforces page size, margins, and page breaks strictly. Body width + margins must not exceed page width or blank pages appear
- **HTML** -- Interactive features work (drilldown, document maps, bookmarks). Pagination is approximate
- **Excel** -- Each page becomes a worksheet. Merged cells can cause unexpected layout. Tablix maps to Excel table structure
- **CSV** -- Strips all formatting, headers, footers. Exports raw dataset data only

## Subscriptions and Delivery

### Standard Subscriptions

- Created by individual users for specific reports
- Fixed parameter values and delivery settings
- Delivery methods: email (SMTP) and file share (UNC path)
- Scheduled execution via SQL Server Agent jobs

### Data-Driven Subscriptions

- Enterprise Edition feature
- Dynamic delivery based on query results at execution time
- Each row generates a separate delivery with varying recipients, parameters, format
- Use case: sending personalized reports to hundreds of recipients from a subscriber table

### Report Snapshots

- Pre-executed report stored in the ReportServer database
- Captures data at a point in time for historical reporting
- Can be scheduled or created on-demand
- Report history maintains multiple snapshots over time

### Caching

- Temporary cached copies stored in ReportServerTempDB
- Expiration: time-based or schedule-based
- Null delivery provider can preload cache via data-driven subscriptions for high-traffic reports

## URL Access

Reports can be accessed and controlled via URL parameters:

```
http://<server>/ReportServer?/<folder>/<report>&<parameters>
```

Parameter prefixes:
- `rs:` -- Report Server parameters (e.g., `rs:Format=PDF`, `rs:Command=Render`)
- `rc:` -- HTML Viewer parameters (e.g., `rc:Toolbar=false`, `rc:Parameters=Collapsed`)
- No prefix -- Report parameters (e.g., `&Year=2024&Region=West`)

### ReportViewer Control

- ASP.NET server control for embedding SSRS reports in web applications
- **Remote mode** -- Connects to SSRS Report Server for processing
- **Local mode** -- Processes `.rdlc` files client-side without a Report Server
- Available as NuGet package for ASP.NET Web Forms
- No official ReportViewer for ASP.NET Core / Blazor (third-party alternatives exist)

## Deployment Topology

### Single-Server Deployment

Report Server, ReportServer databases, and web portal on one machine. Most common model, suitable for small to medium workloads.

### Scale-Out Deployment

- Multiple Report Server instances sharing a single ReportServer database
- Enterprise Edition feature
- Requirements: same database, same encryption key, Network Load Balancing (NLB) or hardware load balancer, ViewState validation for interactive HTML
- SSRS does not provide built-in load balancing

### High Availability

- ReportServer database on SQL Server Always On Availability Group
- Report Server instances behind a load balancer
- Encryption key backup is critical for disaster recovery

### Native Mode vs SharePoint Integrated Mode

| Aspect | Native Mode | SharePoint Integrated Mode |
|--------|-------------|---------------------------|
| **Status** | Active (current) | Deprecated after SQL Server 2016 |
| **Storage** | ReportServer database | SharePoint Content Database |
| **Portal** | Web Portal | SharePoint document libraries |
| **Security** | SSRS role-based | SharePoint permissions |
| **Switching** | Cannot switch -- requires reinstall | Cannot switch -- requires reinstall |

## Configuration Files

### RSReportServer.config

Primary configuration file. Key sections:

- Authentication types and settings
- Service endpoints and URLs
- Rendering extension configuration
- Delivery extension configuration (SMTP, file share)
- Data extension configuration
- Execution log settings (`ExecutionLogLevel`, `ExecutionLogDaysKept`)
- Memory management (`WorkingSetMaximum`, `WorkingSetMinimum`)

Location:
```
%ProgramFiles%\Microsoft SQL Server\MSRS<version>.<instance>\Reporting Services\ReportServer\rsreportserver.config
```

### RSReportDesigner.config

Configuration for Report Designer in Visual Studio.

### ReportingServicesService.exe.config

.NET application configuration for the Report Server Windows service. Controls trace logging level via `DefaultTraceSwitch`.

## Report Authoring Tools

| Tool | Audience | Capabilities |
|------|----------|-------------|
| **Report Builder** | Power users, analysts | ClickOnce app from web portal; wizard-driven; shared datasets from server |
| **SSDT / Visual Studio** | Developers | Full IDE; project-based; source control; build/deploy pipelines; local preview |
| **Power BI Report Builder** | Modern authoring | Standalone tool for creating paginated reports for PBIRS or Power BI Service |
