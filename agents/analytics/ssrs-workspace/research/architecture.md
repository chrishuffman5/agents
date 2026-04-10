# SSRS Architecture

> SQL Server Reporting Services (SSRS) architecture reference covering core components,
> report types, data flow, rendering, and deployment topology.

---

## Core Components

### Report Server Engine

The Report Server is the central processing engine of SSRS. It handles:

- **Report processing**: Retrieves report definitions (RDL), executes queries against data sources, combines data with layout, and produces an intermediate format
- **Rendering**: Transforms the intermediate format into the requested output format (HTML, PDF, Excel, etc.) via rendering extensions
- **Scheduling and delivery**: Manages subscriptions, snapshots, and caching
- **Security**: Enforces role-based access control and authentication

The Report Processor ties all components together and manages caching within SSRS. Execution flow: retrieve report definition -> combine with data -> generate intermediate format -> render to output format.

### Report Manager / Web Portal

- **Web Portal** (SSRS 2016+): Modern browser-based interface for viewing, managing, and organizing reports, data sources, datasets, and subscriptions
- **Report Manager** (legacy name, pre-2016): The older ASP.NET-based management interface
- SSRS 2022 rebuilt the portal using Angular for improved performance and modern UI

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

**Key difference from SQL Server tempdb**: Data in ReportServerTempDB survives SQL Server and Report Server restarts. The Report Server periodically cleans expired and orphaned data.

---

## Report Types

### Paginated Reports (RDL)

- The primary and most mature report type in SSRS
- Defined using Report Definition Language (RDL), an XML-based schema
- Pixel-perfect, print-optimized layouts ideal for invoices, financial statements, operational reports
- Support tables, matrices (crosstabs), lists, charts, gauges, maps, images, and subreports
- Interactive features: drillthrough, drilldown (toggle visibility), document maps, bookmarks

### Mobile Reports (Deprecated)

- Introduced in SSRS 2016 via Mobile Report Publisher
- Responsive dashboard-style reports for mobile devices
- **Deprecated in 2020 and removed in SSRS 2022**

### Power BI Reports (Hybrid - Power BI Report Server Only)

- Power BI Report Server (PBIRS) can host interactive Power BI reports (.pbix) on-premises
- Not available in standalone SSRS -- requires Power BI Report Server
- Enables organizations to keep data on-premises while using Power BI visualization capabilities

---

## Report Definition Language (RDL)

RDL is an XML representation of a report definition, validated against an XML Schema Definition (XSD).

### Core RDL Elements

```
Report
  +-- DataSources          (connection definitions)
  +-- DataSets             (query definitions)
  +-- ReportParameters     (user input parameters)
  +-- Body
  |     +-- ReportItems    (tables, matrices, charts, etc.)
  +-- PageHeader
  +-- PageFooter
```

### Data Sources

Define where data comes from:
- **Data provider**: SQL Server, Oracle, OLE DB, ODBC, Analysis Services, etc.
- **Connection string**: Provider-specific connection information
- **Credentials**: Authentication method for connecting

### Datasets

Each dataset references a data source and contains:
- **Command type**: Text (SQL query), StoredProcedure, or TableDirect
- **Command text**: The actual query or procedure name
- **Fields**: Column mappings from query results to report fields
- **Filters**: Optional client-side filtering (post-query)
- **Parameters**: Query parameters mapped from report parameters

### Report Parameters

- **Types**: String, Integer, Float, Boolean, DateTime
- **Capabilities**: Default values, available values lists, multi-select, cascading dependencies
- **Sources**: Static lists, query-based lists, or expression-based defaults

### Expressions

- Written in Visual Basic .NET syntax
- Used throughout RDL for calculated fields, conditional formatting, visibility, etc.
- Built-in collections: `Fields`, `Parameters`, `Globals`, `User`, `ReportItems`
- Aggregate functions: `Sum`, `Count`, `Avg`, `Min`, `Max`, `CountDistinct`, `RunningValue`, etc.
- Common pattern: `=IIF(Fields!Revenue.Value > 1000000, "Green", "Red")`

### File Extensions

- `.rdl` -- Report Definition Language (server reports)
- `.rdlc` -- Client Report Definition (used with ReportViewer control, no server required)

---

## Data Sources

### Embedded vs Shared Data Sources

| Aspect | Embedded | Shared |
|--------|----------|--------|
| **Scope** | Available only within the report that contains it | Available to any report on the server |
| **Management** | Must update each report individually | Update once, all referencing reports pick up changes |
| **Credentials** | Stored per-report | Stored centrally |
| **Use case** | Report-specific connections | Enterprise-wide standard connections |
| **Expression support** | Supports expression-based connection strings | Static connection strings only |

### Credential Management Options

1. **Prompt for credentials**: User enters credentials at report execution time
2. **Stored credentials**: Saved (encrypted) in the ReportServer database; can optionally "impersonate" a Windows user
3. **Windows Integrated Security**: Uses the executing user's Windows identity (subject to Kerberos delegation / double-hop issues)
4. **No credentials**: For data sources that don't require authentication

Credentials are stored separately from connection information and managed independently. Encryption keys protect stored credentials in the ReportServer database.

---

## Rendering Extensions

SSRS includes built-in rendering extensions:

| Format | Extension | Use Case |
|--------|-----------|----------|
| **HTML** | HTML 4.0/5 | Web browser viewing (default for portal) |
| **PDF** | PDF | Print-ready documents, archival |
| **Excel** | XLSX | Data analysis, spreadsheet users |
| **Word** | DOCX | Editable documents |
| **PowerPoint** | PPTX | Presentations (SSRS 2016+) |
| **CSV** | CSV | Data exchange, plain text |
| **XML** | XML | Data interchange |
| **TIFF** | TIFF | Image archival, faxing |
| **MHTML** | MHTML (Web Archive) | Email embedding |
| **Image** | BMP, EMF, GIF, JPEG, PNG, TIFF, WMF | Image output |
| **Data Feed** | Atom | Data feed consumers |

Rendering extensions are configurable in `RSReportServer.config`. Custom rendering extensions can be developed using the SSRS extensibility framework.

---

## Subscriptions and Delivery

### Standard Subscriptions

- Created by individual users for specific reports
- Fixed parameter values and delivery settings
- Delivery methods: **Email** (SMTP) and **File Share** (UNC path)
- Scheduled execution via SQL Server Agent jobs

### Data-Driven Subscriptions

- Enterprise Edition feature
- Dynamic delivery based on query results at subscription execution time
- Each row in the query result generates a separate delivery
- Can vary: recipients, parameters, rendering format, delivery method per row
- Use case: Sending personalized reports to hundreds of recipients from a subscriber table

### Report Snapshots

- Pre-executed report stored in the ReportServer database
- Captures data at a point in time -- useful for historical reporting
- Can be scheduled or created on-demand
- Report history maintains multiple snapshots over time

### Caching

- Temporary cached copies stored in ReportServerTempDB (in memory)
- Cache expiration: time-based or schedule-based
- Reduces query load for frequently accessed reports
- Null delivery provider can preload cache via data-driven subscriptions

---

## Report Authoring Tools

### Report Builder

- **Audience**: Power users, business analysts, IT professionals
- Standalone ClickOnce application launched from the web portal
- Simplified wizard-driven interface for creating paginated reports
- Same designer surface as Visual Studio but without project/solution overhead
- Cannot manage deployment lifecycle or version control natively
- Can open published shared data sources and datasets directly from the server

### SQL Server Data Tools (SSDT) / Visual Studio

- **Audience**: Report developers, BI professionals
- Full Visual Studio IDE with Report Designer
- Project-based development with solution files
- Source control integration (Git, TFVC)
- Build and deployment pipeline support
- Preview reports locally without deploying to server
- **Microsoft Reporting Services Projects** extension for Visual Studio 2022

### Power BI Report Builder

- Standalone tool for creating paginated reports (.rdl) for Power BI Service or Power BI Report Server
- Modern interface, similar to classic Report Builder
- Relevant for organizations migrating to Power BI

---

## URL Access and ReportViewer Integration

### URL Access

Reports can be accessed and controlled via URL parameters:

```
http://<server>/ReportServer?/<folder>/<report>&<parameters>
```

**Parameter prefixes**:
- `rs:` -- Report Server parameters (e.g., `rs:Format=PDF`, `rs:Command=Render`)
- `rc:` -- HTML Viewer parameters (e.g., `rc:Toolbar=false`, `rc:Parameters=Collapsed`)
- `rv:` -- ReportViewer web part parameters (SharePoint)
- No prefix -- Report parameters (e.g., `&Year=2024&Region=West`)

**Common URL parameters**:
- `rs:Format=PDF|EXCEL|WORD|CSV|XML|IMAGE` -- Render in specific format
- `rs:Command=Render|ListChildren` -- Action to perform
- `rc:Toolbar=true|false` -- Show/hide toolbar
- `rc:Parameters=true|false|Collapsed` -- Parameter area visibility

### ReportViewer Control

- ASP.NET server control for embedding SSRS reports in web applications
- Two processing modes:
  - **Remote mode**: Connects to SSRS Report Server for processing
  - **Local mode**: Processes .rdlc files client-side without a Report Server
- Available as NuGet package for ASP.NET Web Forms
- Note: No official Microsoft ReportViewer for ASP.NET Core / Blazor (third-party alternatives exist)

---

## Deployment Topology

### Single-Server Deployment

- Report Server, ReportServer databases, and web portal on one machine
- Suitable for small to medium workloads
- Most common deployment model

### Scale-Out Deployment

- Multiple Report Server instances sharing a single ReportServer database
- **Enterprise Edition** feature
- Requirements:
  - All instances must use the same ReportServer database
  - Network Load Balancing (NLB) or hardware load balancer distributes requests
  - Same encryption key must be deployed to all instances
  - ViewState validation must be configured for interactive HTML reports
- SSRS does not provide built-in load balancing -- requires external NLB solution
- Use case: High concurrency, large report execution loads

### High Availability

- ReportServer database can be placed on a SQL Server Always On Availability Group
- Report Server instances behind a load balancer
- Encryption key backup is critical for disaster recovery

### SSRS Modes

| Aspect | Native Mode | SharePoint Integrated Mode |
|--------|-------------|---------------------------|
| **Status** | Active (current) | **Deprecated after SQL Server 2016** |
| **Storage** | ReportServer database | SharePoint Content Database |
| **Portal** | Web Portal (Report Manager) | SharePoint document libraries |
| **Security** | SSRS role-based security | SharePoint permissions |
| **Configuration** | Reporting Services Configuration Manager | PowerShell / SharePoint Central Admin |
| **Performance** | Better (fewer hops) | Slightly slower (more communication layers) |
| **Mode switching** | Cannot switch -- requires reinstall | Cannot switch -- requires reinstall |

---

## Configuration Files

### RSReportServer.config

Primary configuration file located at:
```
%ProgramFiles%\Microsoft SQL Server\MSRS<version>.<instance>\Reporting Services\ReportServer\rsreportserver.config
```

Key sections:
- Authentication types and settings
- Service endpoints and URLs
- Rendering extension configuration
- Delivery extension configuration
- Data extension configuration
- Execution log settings
- Memory management and recycling

### RSReportDesigner.config

Configuration for the Report Designer in Visual Studio.

### ReportingServicesService.exe.config

.NET application configuration for the Report Server Windows service.

---

## Sources

- [Microsoft Learn: What Is SQL Server Reporting Services?](https://learn.microsoft.com/en-us/sql/reporting-services/create-deploy-and-manage-mobile-and-paginated-reports)
- [Microsoft Learn: Report Definition Language (SSRS)](https://learn.microsoft.com/en-us/sql/reporting-services/reports/report-definition-language-ssrs)
- [Microsoft Learn: Rendering Extensions Overview](https://learn.microsoft.com/en-us/sql/reporting-services/extensions/rendering-extension/rendering-extensions-overview)
- [Microsoft Learn: URL Access Parameter Reference](https://learn.microsoft.com/en-us/sql/reporting-services/url-access-parameter-reference)
- [Microsoft Learn: Subscriptions and Delivery](https://learn.microsoft.com/en-us/sql/reporting-services/subscriptions/subscriptions-and-delivery-reporting-services)
- [Microsoft Learn: Configure a Native Mode Report Server Scale-Out Deployment](https://learn.microsoft.com/en-us/sql/reporting-services/install-windows/configure-a-native-mode-report-server-scale-out-deployment)
- [Microsoft Learn: Data Connections, Data Sources, and Connection Strings](https://learn.microsoft.com/en-us/sql/reporting-services/report-data/data-connections-data-sources-and-connection-strings-report-builder-and-ssrs)
- [SQLShack: SQL Server Reporting Services Architecture and Component Topology](https://www.sqlshack.com/sql-server-reporting-services-architecture-and-component-topology/)
