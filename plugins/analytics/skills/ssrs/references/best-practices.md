# SSRS Best Practices Reference

Comprehensive best practices for report design, parameter patterns, performance optimization, subscription management, security hardening, and CI/CD deployment.

## Report Design

### Layout and Structure

- **Use a common report template** -- Create a standard template with consistent headers, footers, branding, and page settings for all reports
- **Page size planning** -- Design for the target output format early. PDF/print needs different layout considerations than HTML
- **White space management** -- Minimize gaps between report items. SSRS renders white space literally, causing unwanted blank pages
- **Body width rule** -- Ensure `Body Width + Left Margin + Right Margin <= Page Width` to prevent blank pages in PDF/print
- **Display parameter values** -- Show selected parameter values in the header/footer so users know what filters are active

### Grouping and Sorting

- Group at the data level using dataset grouping rather than multiple report-item sorting operations
- Use row groups for detail-to-summary hierarchies; column groups (matrix) for pivot/crosstab layouts
- Use `KeepTogether` and `KeepWithGroup` properties to prevent awkward page breaks within groups
- Prefer simple field references over complex expressions in sort definitions

### Interactive Features

- **Drillthrough** -- Link summary reports to detail reports via drillthrough actions, passing parameters to filter
- **Drilldown** -- Use toggle items to show/hide detail rows within a single report
- **Document maps** -- Add document map labels to groups for a clickable table of contents (especially useful in long reports)
- **Bookmarks and links** -- Bookmark actions for intra-report navigation; hyperlink actions for external URLs
- **Tooltips** -- Add tooltips for additional context and improved accessibility (screen readers read tooltips)

## Parameter Design

### General Guidelines

- Use descriptive names (`StartDate`, `RegionID`) not auto-generated names (`Parameter1`)
- Write clear, user-friendly prompt text
- Order parameters logically (Year > Quarter > Month, or Region > State > City)
- Provide default values so reports render immediately (critical for subscriptions and caching)
- Use `Allow null value` or `Allow blank value` to enable "all" selections without a specific "All" option

### Cascading Parameters

- Parent parameter selection filters child parameter available values
- Implementation: child parameter's dataset query references the parent parameter
- Keep chains to 2-3 levels. Deep chains create multiple round-trips to the data source
- Set defaults on all parameters in a cascade to enable automatic rendering

### Multi-Select Parameters

- Use `IN` clause: `WHERE Region IN (@Region)`
- SSRS auto-provides "Select All" for multi-value parameters
- Display selections: `=JOIN(Parameters!Region.Label, ", ")`
- For large value lists (hundreds), use temp tables or table-valued parameters instead of long `IN` clauses

## Performance Optimization

### Query Optimization

- **Filter at the database** -- `WHERE` clauses in queries, not report-level filters
- **Use stored procedures** -- Execution plan caching, easier tuning, parameterized by default
- **Avoid `SELECT *`** -- Return only columns needed by the report
- **Aggregate in SQL** -- `SUM`/`COUNT`/`AVG` in the query, not SSRS aggregate functions
- **Index optimization** -- Ensure proper indexes on `WHERE`, `JOIN`, `ORDER BY`, `GROUP BY` columns
- **Parameterize date ranges** -- Always require date range parameters to limit data volume

### Dataset and Caching

- Use shared datasets for data accessed by multiple reports (centralized caching and management)
- Pre-execute reports on a schedule and serve from snapshot for expensive queries
- Configure cache expiration based on data freshness requirements
- Use null delivery subscriptions to pre-populate cache for high-traffic reports
- Always set `Report Execution Timeout` -- default is no timeout

### Report Rendering

- **Minimize subreports** -- Subreports in detail rows execute one query per row (N+1 problem). Replace with JOINs, lookups, or shared datasets
- **Reduce expression complexity** -- Complex expressions in table cells evaluated per row create cumulative overhead
- **Limit embedded images** -- Inflates RDL size and memory. Use external/URL-based images
- **Strategic page breaks** -- Reduce memory usage for very large reports by enabling incremental rendering
- **Avoid large HTML datasets** -- Reports with tens of thousands of rows perform poorly in HTML. Use pagination, parameter scoping, or PDF

### Server Configuration

- Configure `WorkingSetMaximum` and `WorkingSetMinimum` in `rsreportserver.config`
- Configure application domain recycling to reclaim memory from long-running processes
- Run SSRS on a dedicated server separate from the SQL Server database engine for production
- Scale-out with multiple Report Server instances behind a load balancer (Enterprise Edition)

## Subscription Management

### Scheduling

- Schedule data-driven subscriptions and snapshots during off-peak hours
- Stagger subscriptions by 5-15 minutes to distribute load (avoid scheduling many at the same time)
- Monitor SQL Server Agent (SSRS subscriptions depend on it)
- Use shared schedules for common patterns (daily, weekly, monthly)

### Delivery Channels

- **Email** -- Requires SMTP configuration in `rsreportserver.config` (sender address, SMTP server, authentication)
- **File share** -- UNC paths; ensure SSRS service account has write permissions; plan archiving strategy for accumulating files
- **Custom delivery extensions** -- SSRS supports custom extensions for FTP, database storage, or web service delivery

### Data-Driven Subscriptions

- Design a well-structured subscriber table with columns for email, format preference, parameters, active flag
- Monitor execution status -- failures logged in ReportServer database and visible in web portal
- Test with a small subscriber set before deploying to full distribution
- Query `dbo.Subscriptions` and `dbo.ExecutionLog3` for subscription history and failure analysis

## Security

### Role-Based Access Control

**System-level roles** (site-wide):

| Role | Permissions |
|------|------------|
| System Administrator | Site settings, security, shared schedules, Report Builder access |
| System User | View system properties and shared schedules |

**Item-level roles** (folders, reports, data sources):

| Role | Permissions |
|------|------------|
| Content Manager | Full control: reports, folders, data sources, subscriptions |
| Publisher | Publish reports and linked reports |
| Browser | View reports and folders; manage personal subscriptions |
| Report Builder | Open reports in Report Builder |
| My Reports | Manage personal folder and reports |

### Security Best Practices

- **Principle of least privilege** -- Start with Browser role, escalate only as needed
- **Use Windows groups** -- Assign roles to AD groups, not individual users
- **Folder-based security** -- Organize reports by department/function; apply security at the folder level
- **Break inheritance sparingly** -- Document why inheritance was broken on specific items
- **Secure data sources** -- Use stored credentials with a dedicated service account (avoids Kerberos double-hop)
- **Disable My Reports if unused** -- Reduces management overhead

### Row-Level Filtering

- Use `User!UserID` built-in field in dataset queries: `WHERE ManagerID = @UserID`
- Auto-populate parameters based on user identity to restrict data scope
- SSRS does not have built-in row-level security like Power BI; implement via query/parameter filtering

### SSL/TLS Configuration

- Always use HTTPS for both Report Server web service and web portal
- SSL must be configured in two places: Report Server URL and Web Portal URL (via Reporting Services Configuration Manager)
- TLS 1.3 supported in SSRS 2022; disable older TLS versions (1.0, 1.1) for compliance
- Enforce HTTPS by removing HTTP bindings in production

## Deployment and CI/CD

### Deployment Tools

**rs.exe utility** -- Command-line scripting for deployment automation:

```bash
rs.exe -i DeployScript.rss -s http://server/ReportServer -e Mgmt2010 \
  -v sourcePATH="C:\Reports" -v targetFolder="/Production"
```

**ReportingServicesTools PowerShell module** (40+ cmdlets):

```powershell
Install-Module -Name ReportingServicesTools

# Deploy a single report
Write-RsCatalogItem -Path "C:\Reports\Sales.rdl" -RsFolder "/Production" -ReportServerUri http://server/ReportServer

# Deploy all reports in a folder
Write-RsFolderContent -Path "C:\Reports\" -RsFolder "/Production" -ReportServerUri http://server/ReportServer
```

**REST API v2.0**:

```
GET    /api/v2.0/Reports              -- List reports
POST   /api/v2.0/CatalogItems         -- Upload items
DELETE /api/v2.0/Reports({id})        -- Delete a report
PATCH  /api/v2.0/Reports({id})        -- Update properties
```

### CI/CD Pipeline Pattern

1. **Source control** -- Store `.rdl`, `.rds`, `.rsd` files in Git
2. **Build/validate** -- XML schema validation of RDL files in CI pipeline
3. **Deploy** -- PowerShell `ReportingServicesTools` or REST API calls in CD pipeline
4. **Environment promotion** -- Parameterized scripts with environment-specific server URLs and data source connections (Dev > Test > Production)
5. **Data source override** -- Override connection strings per environment during deployment

### Branding and Customization

- **Themes** -- SSRS 2016+ supports JSON-based color palette themes for the web portal
- **Custom branding** -- Upload logos and brand colors via web portal settings
- **Custom authentication** -- Replace Windows Authentication with forms-based authentication by implementing `IAuthenticationExtension2`
