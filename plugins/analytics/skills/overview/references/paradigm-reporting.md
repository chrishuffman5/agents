# Paradigm: Reporting Platforms

When and why to choose reporting and governed analytics platforms. Covers SSRS and Looker.

## What Defines Reporting Platforms

Reporting platforms produce structured, formatted output -- paginated reports for print/PDF, parameterized reports for operational use, and embedded analytics with strong governance. Unlike self-service BI (where users explore data freely), reporting platforms deliver pre-defined views of data with precise formatting, scheduling, and distribution.

Key characteristics:
- **Pixel-perfect output** -- Reports render to exact layouts for print, PDF, and email delivery
- **Parameterized queries** -- Users select parameters (date range, region, account) and receive filtered results
- **Subscription-based delivery** -- Scheduled report delivery via email, file share, or webhook
- **Governed data access** -- Strong semantic layers or data source controls that prevent ad-hoc exploration of raw data
- **Embedded distribution** -- Reports render inside portals, applications, and intranets

## Choose Reporting Platforms When

- **Paginated output is required** -- Financial statements, invoices, regulatory filings, shipping labels, packing slips. Any output that must look the same whether on screen, paper, or PDF.
- **Regulatory or compliance reporting** -- SOX, HIPAA, FDA, or industry-specific formats where layout, content, and distribution are audited.
- **Operational reports with parameters** -- "Show me all open orders for warehouse X between dates Y and Z." The user does not explore -- they fill in parameters and get a formatted result.
- **High-volume scheduled delivery** -- Thousands of reports generated nightly and distributed to subscribers via email or file drops.
- **Governed semantic layer is non-negotiable** -- Looker's LookML enforces that all users query through a centrally defined model. No one writes raw SQL against production databases.

## Avoid Reporting Platforms When

- **Users need self-service exploration** -- Reporting tools produce fixed-format output. For drag-and-drop visual exploration, use enterprise BI (Power BI, Tableau).
- **The audience is primarily executives** -- Executives want interactive dashboards with KPI cards and drill-down, not 50-page paginated reports.
- **The data model is simple and the team is small** -- Superset or Metabase provides dashboards and basic reports without the overhead of SSRS infrastructure or LookML development.
- **Real-time monitoring is the goal** -- Grafana handles time-series alerting and live dashboards. Reporting platforms are batch-oriented.

## Technology Comparison Within This Paradigm

| Feature | SSRS | Looker |
|---|---|---|
| **Output format** | Paginated reports (PDF, Excel, Word, HTML, CSV, XML) | Dashboards, Looks, scheduled deliveries (PDF, CSV, PNG) |
| **Semantic layer** | Shared data sources + shared datasets (limited) | LookML (full semantic layer, Git-versioned) |
| **Query interface** | Report Builder (drag-and-drop), SSDT report designer | Explore interface (dimension/measure picker), SQL Runner |
| **Deployment** | SQL Server Reporting Services (on-prem), Power BI Report Server | Looker Cloud (Google-managed), Looker Core (self-hosted, deprecated) |
| **Scheduling** | Subscriptions (email, file share, SharePoint) | Schedules (email, S3, SFTP, webhooks, Google Sheets) |
| **Embedding** | URL access, ReportViewer control (.NET), REST API | Looker Embed SDK (SSO + iframe), Looker API, Looker Actions |
| **Security** | Windows/Active Directory authentication, item-level roles | Model-level access grants, user attributes for row-level filtering |
| **Data sources** | SQL Server (primary), ODBC, OLE DB, Oracle, Analysis Services | BigQuery (primary), Snowflake, Redshift, PostgreSQL, MySQL, 50+ dialects |
| **Licensing** | Included with SQL Server (Standard or Enterprise) | Google Cloud subscription (per user) |
| **Best for** | Microsoft shops needing paginated/operational reports | Google Cloud shops needing governed, code-defined analytics |

## Common Patterns

### SSRS: Paginated Reporting for the Microsoft Stack

**Report development workflow:**
1. Define shared data sources (connection strings to SQL Server, SSAS, or ODBC)
2. Define shared datasets (parameterized SQL queries or stored procedures)
3. Design report layout in Report Builder or Visual Studio (SSDT) using the RDL format
4. Add tables, matrices (crosstab), charts, gauges, and subreports
5. Configure parameters with cascading defaults (select Region -> available Cities filter)
6. Deploy to Report Server (SSRS web portal or Power BI Report Server)
7. Configure subscriptions for automated delivery

**Parameterized report example:**
```xml
<!-- RDL dataset query with parameters -->
<Query>
  <DataSourceName>SalesDB</DataSourceName>
  <CommandText>
    SELECT o.OrderDate, c.CustomerName, SUM(od.LineTotal) AS Revenue
    FROM Sales.Orders o
    JOIN Sales.Customers c ON o.CustomerID = c.CustomerID
    JOIN Sales.OrderDetails od ON o.OrderID = od.OrderID
    WHERE o.OrderDate BETWEEN @StartDate AND @EndDate
      AND (@Region IS NULL OR c.Region = @Region)
    GROUP BY o.OrderDate, c.CustomerName
    ORDER BY Revenue DESC
  </CommandText>
</Query>
```

**SSRS deployment considerations:**
- SSRS is tied to SQL Server licensing -- no separate purchase needed if SQL Server is already licensed
- Power BI Report Server can host both Power BI reports (.pbix) and SSRS paginated reports (.rdl) on the same server
- SSRS 2022+ supports modern authentication (Azure AD) but on-prem remains Active Directory-centric
- For new implementations, consider Power BI paginated reports (cloud-hosted, same RDL format) instead of on-prem SSRS

### Looker: Code-Defined Governed Analytics

**LookML development workflow:**
1. Define database connection (BigQuery, Snowflake, PostgreSQL, etc.)
2. Write LookML views mapping to database tables (define dimensions, measures, derived tables)
3. Write LookML models defining relationships between views (explores)
4. Commit LookML to Git repository (code review, branching, CI/CD)
5. Deploy to Looker instance (production mode reads from the production branch)
6. Business users build Looks and dashboards from Explores (constrained by the LookML model)

**LookML view example:**
```lookml
view: orders {
  sql_table_name: analytics.fact_orders ;;

  dimension: order_id {
    primary_key: yes
    type: number
    sql: ${TABLE}.order_id ;;
  }

  dimension_group: created {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.created_at ;;
  }

  dimension: status {
    type: string
    sql: ${TABLE}.status ;;
  }

  measure: total_revenue {
    type: sum
    sql: ${TABLE}.revenue ;;
    value_format_name: usd
    description: "Sum of revenue from completed orders (excludes cancelled and refunded)"
    filters: [status: "-cancelled, -refunded"]
  }

  measure: order_count {
    type: count_distinct
    sql: ${TABLE}.order_id ;;
  }

  measure: average_order_value {
    type: number
    sql: ${total_revenue} / NULLIF(${order_count}, 0) ;;
    value_format_name: usd
  }
}
```

**Looker governance strengths:**
- Every metric is defined in LookML, version-controlled in Git, and reviewed via pull request
- Business users can explore data but only through the dimensions and measures defined in LookML
- User attributes enable row-level security: `sql_always_where: ${region} = '{{ _user_attributes["allowed_region"] }}'`
- Derived tables (PDTs) materialize complex queries on schedule, acting as a lightweight transformation layer

**Looker limitations:**
- LookML has a learning curve -- it requires developer-type skills, not business analyst skills
- Tight coupling to Google Cloud (Looker is a Google product; BigQuery integration is deepest)
- Self-hosted Looker Core is deprecated in favor of Looker Cloud
- Visualization capabilities are functional but less polished than Tableau or Power BI

### Report Subscription and Distribution Patterns

| Pattern | SSRS | Looker |
|---|---|---|
| **Scheduled email** | Data-driven subscriptions (one report per recipient with filtered data) | Schedule a Look/dashboard delivery to email recipients |
| **File delivery** | Render to file share (PDF, Excel, CSV) on schedule | Deliver to S3, SFTP, Google Cloud Storage, Google Sheets |
| **Event-driven** | Not built-in (use SQL Agent jobs + SSRS API) | Looker Actions (trigger workflows on data conditions) |
| **Burst reporting** | Data-driven subscriptions: iterate over a query, render one report per row | PDFs per-user via scheduled plans with user attribute filters |
| **Embedded in portal** | ReportViewer control or iframe + URL parameters | Signed SSO embed URL with user-specific filters |
