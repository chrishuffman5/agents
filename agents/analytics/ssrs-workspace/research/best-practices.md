# SSRS Best Practices

> Comprehensive best practices for SSRS report design, performance optimization,
> security, deployment, and subscription management.

---

## Report Design

### Layout and Structure

- **Use a common report template**: Create a standard template with consistent headers, footers, branding, and page settings. Apply to all new reports for a uniform experience
- **Page size planning**: Design for the target output format early. A report destined for PDF/print needs different layout considerations than one primarily viewed in HTML
- **White space management**: Minimize gaps between report items. SSRS renders white space literally, which can cause unwanted blank pages in paginated output
- **Body width**: Ensure `Body Width + Left Margin + Right Margin <= Page Width` to prevent blank pages in PDF/print output
- **Display parameter values**: Show the selected parameter values in the report header/footer so users know what filters were applied

### Grouping and Sorting

- **Group at the data level**: Use dataset grouping and sorting rather than adding multiple sorting operations at the report item level
- **Row groups vs column groups**: Use row groups for detail-to-summary hierarchies; use column groups (matrix) for pivot/crosstab layouts
- **Keep-together properties**: Use `KeepTogether` and `KeepWithGroup` properties to prevent awkward page breaks within groups
- **Sort expressions**: Prefer simple field references over complex expressions in sort definitions for better performance

### Interactive Features

- **Drillthrough reports**: Link summary reports to detail reports via drillthrough actions. Pass parameters to filter the detail report. Enables a "big picture to detail" navigation pattern
- **Drilldown (toggle visibility)**: Use toggle items to show/hide detail rows within a single report. Reduces initial visual clutter while keeping all data accessible
- **Document maps**: Add document map labels to groups to create a clickable table of contents in HTML rendering. Especially useful for long reports
- **Bookmarks and links**: Use bookmark actions for intra-report navigation; use hyperlink actions for external URLs
- **Tooltips**: Add tooltips to report items for additional context. Also improves accessibility (screen readers read tooltips)

---

## Parameter Design

### General Guidelines

- **Naming conventions**: Use descriptive names (e.g., `StartDate`, `RegionID`) rather than auto-generated names (`Parameter1`)
- **Prompt text**: Write clear, user-friendly prompt text that tells users what to select
- **Order parameters logically**: Place filtering parameters in the order users think about them (e.g., Year > Quarter > Month, or Region > State > City)
- **Provide default values**: Set sensible defaults so reports render immediately without requiring user input (especially important for subscriptions and cached reports)
- **Allow null/blank where appropriate**: Use `Allow null value` or `Allow blank value` to enable "all" selections without requiring a specific "All" option

### Cascading Parameters

- **Design pattern**: Parent parameter selection filters the available values of child parameters (e.g., selecting Country filters the State/Province list)
- **Implementation**: Child parameter's available values dataset uses a query that references the parent parameter
- **Performance tip**: Keep cascading chains short (2-3 levels). Deep chains create multiple round-trips to the data source
- **Default values**: Set defaults on all parameters in a cascade chain to enable automatic rendering

### Multi-Select Parameters

- **Query integration**: Use `IN` clause with multi-value parameters: `WHERE Region IN (@Region)`
- **"Select All" behavior**: SSRS automatically provides a "Select All" option for multi-value parameters
- **Display selected values**: Use `=JOIN(Parameters!Region.Label, ", ")` expression to show selected values in the report
- **Performance warning**: Multi-select parameters with hundreds of values can generate extremely long SQL `IN` clauses. Consider alternative approaches (temp tables, table-valued parameters) for large value lists

---

## Performance Optimization

### Query Optimization

- **Filter at the database level**: Use `WHERE` clauses in queries rather than report-level filters. The database engine is far more efficient at filtering than the Report Server
- **Use stored procedures**: Prefer stored procedures over inline SQL for complex queries. Benefits: execution plan caching, easier tuning, security (parameterized by default)
- **Avoid `SELECT *`**: Return only the columns needed by the report
- **Aggregate in the query**: Perform `SUM`, `COUNT`, `AVG` in the SQL query rather than relying on SSRS aggregate functions when possible. Database servers handle aggregation more efficiently
- **Index optimization**: Ensure proper indexes exist on columns used in `WHERE`, `JOIN`, `ORDER BY`, and `GROUP BY` clauses of report queries
- **Parameterize date ranges**: Avoid open-ended queries. Always require date range parameters to limit data volume

### Dataset and Caching

- **Shared datasets**: Use shared datasets for data accessed by multiple reports to enable centralized caching and management
- **Report snapshots**: Pre-execute reports on a schedule and serve from snapshot. Ideal for reports with expensive queries that don't need real-time data
- **Cache expiration**: Configure cache expiration based on data freshness requirements. Balance between performance and data currency
- **Null delivery subscriptions**: Use data-driven subscriptions with the null delivery provider to pre-populate the cache for high-traffic reports
- **Execution timeout**: Set `Report Execution Timeout` to prevent runaway queries from consuming all server resources. Default is no timeout -- always set an appropriate value

### Report Rendering

- **Minimize subreports**: Subreports execute a separate query per instance. A subreport in a detail row executes once per row -- this is a common performance killer. Replace with lookups, joins, or embedded datasets where possible
- **Reduce expression complexity**: Complex expressions in table cells evaluated thousands of times (once per row) create cumulative overhead
- **Limit images**: Embedded images increase report definition size and memory consumption. Use external images (URL-based) when possible
- **Page break optimization**: Strategic page breaks can reduce memory usage for very large reports by enabling incremental rendering
- **Avoid large datasets in HTML**: Reports with tens of thousands of rows perform poorly in HTML rendering. Consider pagination, parameters to limit scope, or PDF rendering for large outputs

### Server Configuration

- **Memory management**: Configure `WorkingSetMaximum` and `WorkingSetMinimum` in `rsreportserver.config` to control Report Server memory usage
- **Recycling**: Configure application domain recycling to reclaim memory from long-running Report Server processes
- **Dedicated server**: For production workloads, run SSRS on a dedicated server separate from the SQL Server database engine
- **Scale-out**: For high concurrency, deploy multiple Report Server instances behind a load balancer sharing the same ReportServer database (Enterprise Edition)

---

## Subscription Management

### Scheduling

- **Off-peak scheduling**: Schedule data-driven subscriptions and snapshot generation during off-peak hours to reduce load on both the Report Server and data sources
- **Stagger subscriptions**: Avoid scheduling many subscriptions at the same time. Stagger by 5-15 minutes to distribute load
- **SQL Server Agent dependency**: SSRS subscriptions rely on SQL Server Agent. Ensure Agent is running and monitored
- **Shared schedules**: Use shared schedules for common patterns (daily, weekly, monthly) to simplify management and enable bulk rescheduling

### Delivery Channels

- **Email delivery**: Requires SMTP server configuration in `rsreportserver.config`. Configure sender address, SMTP server, and authentication
- **File share delivery**: Specify UNC paths. Ensure the SSRS service account has write permissions to the target share. Consider archiving strategies for accumulating files
- **Custom delivery extensions**: SSRS supports custom delivery extensions for scenarios like FTP, database storage, or web service calls

### Data-Driven Subscriptions

- **Subscriber table design**: Create a well-structured subscriber table with columns for email, format preference, parameters, and active flag
- **Error handling**: Monitor subscription execution status. Failed deliveries are logged in the ReportServer database and visible in the web portal
- **Testing**: Test with a small subscriber set before deploying to full distribution. Use a separate "test" delivery configuration
- **Audit trail**: Query the `dbo.Subscriptions` and `dbo.ExecutionLog3` views for subscription execution history and failure analysis

---

## Security

### Role-Based Access Control

SSRS uses a two-level role system:

**System-Level Roles** (site-wide operations):
| Role | Permissions |
|------|------------|
| System Administrator | Manage site settings, security, shared schedules, Report Builder access |
| System User | View system properties and shared schedules |

**Item-Level Roles** (folders, reports, data sources):
| Role | Permissions |
|------|------------|
| Content Manager | Full control over content: manage reports, folders, data sources, subscriptions |
| Publisher | Publish reports and linked reports to the server |
| Browser | View reports, folders; manage personal subscriptions |
| Report Builder | Open reports in Report Builder |
| My Reports | Manage personal folder and reports within it |

### Security Best Practices

- **Principle of least privilege**: Grant the minimum role required for each user/group. Start with Browser and escalate only as needed
- **Use Windows groups**: Assign roles to Active Directory groups rather than individual users for easier management
- **Folder-based security**: Organize reports into folders by department/function and apply security at the folder level. Reports inherit parent folder permissions by default
- **Break inheritance sparingly**: Only break permission inheritance on specific items when necessary. Document why inheritance was broken
- **Secure data sources**: Use stored credentials with a dedicated service account rather than relying on user impersonation (avoids Kerberos double-hop issues)
- **Disable My Reports if unused**: The My Reports feature creates personal folders for each user. Disable if not needed to reduce management overhead

### Row-Level Filtering

- **Query-based filtering**: Use the `User!UserID` built-in field in dataset queries to filter data by the executing user: `WHERE ManagerID = @UserID`
- **Parameter-based filtering**: Auto-populate parameters based on user identity to restrict data scope
- **Note**: SSRS does not have built-in row-level security like Power BI. Row-level filtering must be implemented in the query or data model

### SSL/TLS Configuration

- **Always use HTTPS**: Configure SSL/TLS for both the Report Server web service and the web portal
- **Certificate requirements**: Install a certificate in the machine store's personal certificate node
- **Configuration locations**: SSL must be configured in two places -- the Report Server URL and the Web Portal URL (via Reporting Services Configuration Manager)
- **TLS 1.3**: Supported in SSRS 2022. Disable older TLS versions (1.0, 1.1) for security compliance
- **Enforce HTTPS**: Configure URL reservations to use HTTPS only; remove HTTP bindings in production

---

## Deployment and CI/CD

### Deployment Tools

#### RS.exe Utility

Command-line scripting utility for automating deployment and administration:

```bash
rs.exe -i DeployScript.rss -s http://server/ReportServer -e Mgmt2010 \
  -v sourcePATH="C:\Reports" -v targetFolder="/Production"
```

- Uses VB.NET scripts (.rss files)
- Can deploy reports, data sources, datasets, and folders
- Supports batch operations
- Available in every SSRS installation

#### PowerShell: ReportingServicesTools

Microsoft's PowerShell module (40+ commands) for SSRS management:

```powershell
Install-Module -Name ReportingServicesTools

# Deploy a report
Write-RsCatalogItem -Path "C:\Reports\Sales.rdl" -RsFolder "/Production" -ReportServerUri http://server/ReportServer

# Deploy all reports in a folder
Write-RsFolderContent -Path "C:\Reports\" -RsFolder "/Production" -ReportServerUri http://server/ReportServer
```

#### REST API v2.0

Programmatic management via HTTP:

```
GET    /api/v2.0/Reports              -- List reports
GET    /api/v2.0/Reports({id})        -- Get report details
POST   /api/v2.0/CatalogItems         -- Create/upload items
DELETE /api/v2.0/Reports({id})        -- Delete a report
PATCH  /api/v2.0/Reports({id})        -- Update report properties
```

Supports: folders, reports, KPIs, data sources, datasets, subscriptions, refresh plans.

#### SSDT/Visual Studio Deployment

- Right-click project > Deploy in Visual Studio
- Configure target server URL, folder, and overwrite settings in project properties
- Suitable for development/testing but not ideal for production CI/CD

### CI/CD Pipeline Approaches

1. **Source control**: Store .rdl, .rds (shared data source), and .rsd (shared dataset) files in Git
2. **Build step**: Validate RDL files (XML schema validation) as part of the CI pipeline
3. **Deploy step**: Use PowerShell `ReportingServicesTools` or REST API calls in the CD pipeline
4. **Environment promotion**: Deploy to Dev > Test > Production using parameterized scripts with environment-specific server URLs and data source connections
5. **Data source management**: Override data source connection strings per environment during deployment

### Branding and Customization

- **Report themes**: SSRS 2016+ supports themes (JSON-based color palettes) applied to the web portal
- **Custom branding**: Upload custom logos and brand colors via the web portal branding settings
- **Custom authentication**: Replace default Windows Authentication with forms-based or custom authentication by implementing the `IAuthenticationExtension2` interface
- **Custom rendering extensions**: Develop extensions for output formats not included by default

---

## Sources

- [MSSQLTips: SSRS General Best Practices](https://www.mssqltips.com/sqlservertip/4020/sql-server-reporting-services-general-best-practices/)
- [MSSQLTips: SSRS Best Practices for Report Design](https://www.mssqltips.com/sqlservertip/4006/sql-server-reporting-services-best-practices-for-report-design/)
- [MSSQLTips: SSRS Best Practices for Performance and Maintenance](https://www.mssqltips.com/sqlservertip/3659/sql-server-reporting-services-best-practices-for-performance-and-maintenance/)
- [SQLShack: SQL Server Reporting Services Best Practices](https://www.sqlshack.com/sql-server-reporting-services-best-practices/)
- [MSSQLTips: SQL Server Reporting Services Security](https://www.mssqltips.com/sqlservertip/8089/sql-server-reporting-services-security/)
- [Microsoft Learn: Grant Users Access to a Report Server](https://learn.microsoft.com/en-us/sql/reporting-services/security/grant-user-access-to-a-report-server)
- [Microsoft Learn: RS.exe Utility](https://learn.microsoft.com/en-us/sql/reporting-services/tools/rs-exe-utility-ssrs)
- [Microsoft Learn: REST APIs for Reporting Services](https://learn.microsoft.com/en-us/sql/reporting-services/developer/rest-api)
- [SQLPerformance: Tuning SQL Server Reporting Services](https://sqlperformance.com/2019/09/reporting-services/tuning-sql-server-reporting-services)
